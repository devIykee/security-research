// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "./interfaces/IUniswapV3.sol";

/// @title MetaLaunchTokenV11
/// @notice Fixed-supply ERC-20 deployed by MetaLaunchFactoryV11. Ownerless: no
///         owner, no mint, no tax, no blacklist, no pause, no proxy, no upgrade,
///         no metadata admin, no ability to remove liquidity. The entire supply
///         is minted once, to the factory, at construction.
///
///         Temporary launch protections (identical model to V10) apply ONLY to
///         buys out of the canonical pool while `block.number <= restrictionEndBlock`:
///         - same-block (launch-block) public buys revert outright;
///         - the factory's atomic initial buy is exempt via a one-shot
///           `setInitialBuyRecipient`, cleared before launchToken() returns;
///         - per-recipient max-wallet and cumulative max-tx caps apply during
///           the window. Wallet→wallet transfers and sells into the pool are
///           never restricted. All restrictions expire permanently.
contract MetaLaunchTokenV11 is ERC20 {
    struct Socials {
        string twitter;
        string telegram;
        string discord;
        string website;
        string farcaster;
    }

    error LaunchBlockBuyBlocked(address recipient);
    error MaxWalletExceeded(address account, uint256 balance, uint256 limit);
    error MaxTxExceeded(address recipient, uint256 attempted, uint256 limit);
    error NotLaunchFactory();
    error ZeroAddress();

    /// @notice The human creator who launched this token (NOT the factory).
    address public immutable creator;
    /// @notice The factory that deployed this token — the only address allowed
    ///         to open the atomic-initial-buy exemption.
    address public immutable launchFactory;
    address public immutable dexFactory;
    address public immutable positionManager;
    address public immutable pairToken;
    uint24 public immutable poolFee;

    uint256 public immutable launchBlock;
    uint256 public immutable restrictionBlocks;
    uint256 public immutable restrictionEndBlock;
    uint16 public immutable maxWalletBps;
    uint16 public immutable maxTxBps;

    /// @notice Off-chain metadata bundle (data-URI / IPFS) — the aggregate the
    ///         wizard writes. Immutable after launch.
    string public metadataURI;
    string public logo;
    string public description;

    Socials private _socials;
    address private _initialBuyRecipient;
    mapping(address recipient => uint256 amount) private _restrictedPoolBuys;

    struct InitParams {
        string name;
        string symbol;
        string metadataURI;
        string logo;
        string description;
        Socials socials;
        address creator;
        address factory;
        address dexFactory;
        address positionManager;
        address pairToken;
        uint24 poolFee;
        uint256 supply;
        uint16 maxWalletBps;
        uint16 maxTxBps;
        uint32 restrictionBlocks;
    }

    /// @notice Mints the full fixed supply once, to the factory. Deployed via a
    ///         thin deployer helper (to keep the factory under EIP-170), so the
    ///         trusted factory is passed explicitly rather than read from
    ///         msg.sender. The full supply is minted to that factory.
    constructor(InitParams memory p) ERC20(p.name, p.symbol) {
        if (
            p.creator == address(0) || p.factory == address(0) || p.dexFactory == address(0)
                || p.positionManager == address(0) || p.pairToken == address(0)
        ) revert ZeroAddress();

        creator = p.creator;
        launchFactory = p.factory;
        dexFactory = p.dexFactory;
        positionManager = p.positionManager;
        pairToken = p.pairToken;
        poolFee = p.poolFee;
        launchBlock = block.number;
        restrictionBlocks = p.restrictionBlocks;
        restrictionEndBlock = block.number + p.restrictionBlocks;
        maxWalletBps = p.maxWalletBps;
        maxTxBps = p.maxTxBps;
        metadataURI = p.metadataURI;
        logo = p.logo;
        description = p.description;
        _socials = p.socials;

        _mint(p.factory, p.supply);
    }

    /// @notice The canonical launch pool once the factory has created it.
    function liquidityPool() public view returns (address) {
        return IUniswapV3Factory(dexFactory).getPool(address(this), pairToken, poolFee);
    }

    function socials()
        external
        view
        returns (
            string memory twitter,
            string memory telegram,
            string memory discord,
            string memory website,
            string memory farcaster
        )
    {
        Socials memory v = _socials;
        return (v.twitter, v.telegram, v.discord, v.website, v.farcaster);
    }

    /// @notice Aggregate metadata accessor for indexers (launcher-token shape).
    function getTokenInfo()
        external
        view
        returns (address tokenCreator, string memory tokenLogo, string memory tokenDescription, Socials memory s)
    {
        return (creator, logo, description, _socials);
    }

    function maxWalletLimit() public view returns (uint256) {
        return (totalSupply() * maxWalletBps) / 10_000;
    }

    function maxTxLimit() public view returns (uint256) {
        return (totalSupply() * maxTxBps) / 10_000;
    }

    /// @notice Factory-only, one-shot exemption for the atomic initial buy. The
    ///         factory sets it to the buyer before the swap and clears it to
    ///         address(0) immediately after — no persistent exemption exists.
    function setInitialBuyRecipient(address recipient) external {
        if (msg.sender != launchFactory) revert NotLaunchFactory();
        _initialBuyRecipient = recipient;
    }

    /// @dev Launch protections apply ONLY to pool→user buys during the window.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && block.number <= restrictionEndBlock) {
            if (!_isPairPool(from)) {
                super._update(from, to, value);
                return;
            }

            bool isAtomicLaunchBuy =
                block.number == launchBlock && _initialBuyRecipient != address(0) && to == _initialBuyRecipient;

            if (!isAtomicLaunchBuy) {
                if (block.number == launchBlock) revert LaunchBlockBuyBlocked(to);

                uint256 walletLimit = maxWalletLimit();
                uint256 resulting = balanceOf(to) + value;
                if (resulting > walletLimit) revert MaxWalletExceeded(to, resulting, walletLimit);

                uint256 cumulative = _restrictedPoolBuys[to] + value;
                uint256 cumulativeLimit = maxTxLimit();
                if (cumulative > cumulativeLimit) revert MaxTxExceeded(to, cumulative, cumulativeLimit);
                _restrictedPoolBuys[to] = cumulative;
            }
        }
        super._update(from, to, value);
    }

    /// @notice Recognises any pool the configured dex factory registered for
    ///         this token + pair asset, across fee tiers.
    function _isPairPool(address candidate) private view returns (bool) {
        address canonical = liquidityPool();
        if (candidate == canonical && canonical != address(0)) return true;
        if (candidate.code.length == 0) return false;

        (bool ok, bytes memory data) = candidate.staticcall(abi.encodeCall(IUniswapV3Pool.fee, ()));
        if (!ok || data.length < 32) return false;
        uint24 candidateFee = abi.decode(data, (uint24));
        return IUniswapV3Factory(dexFactory).getPool(address(this), pairToken, candidateFee) == candidate;
    }
}
