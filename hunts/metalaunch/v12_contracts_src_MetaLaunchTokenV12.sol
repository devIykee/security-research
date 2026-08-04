// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3.sol";

/// @title MetaLaunchTokenV12
/// @notice Fixed-supply ERC-20 deployed by MetaLaunchFactoryV12. Ownerless: no
///         owner, no mint, no tax, no blacklist, no pause, no proxy, no upgrade,
///         no metadata admin, no ability to remove liquidity. The entire supply
///         is minted once, to the factory, at construction.
///
///         V12 removes the V11 launch protections BY DESIGN: there is no
///         max-wallet cap, no cumulative-buy cap, no restriction window, no
///         launch-block gate, and no transfer hook of any kind. `_update` is
///         untouched OpenZeppelin ERC20. The token is a plain ERC-20 from its
///         first block, permanently. The only remaining launch-fairness
///         control is the FACTORY-side allocation cap on the creator's own
///         atomic first buy, which never touches this contract's code.
contract MetaLaunchTokenV12 is ERC20 {
    struct Socials {
        string twitter;
        string telegram;
        string discord;
        string website;
        string farcaster;
    }

    error ZeroAddress();

    /// @notice The human creator who launched this token (NOT the factory).
    address public immutable creator;
    /// @notice The factory that deployed this token. Provenance only: V12
    ///         grants the factory no privileges over the token whatsoever.
    address public immutable launchFactory;
    address public immutable dexFactory;
    address public immutable positionManager;
    address public immutable pairToken;
    uint24 public immutable poolFee;

    /// @notice Off-chain metadata bundle (data-URI / IPFS) — the aggregate the
    ///         wizard writes. Immutable after launch.
    string public metadataURI;
    string public logo;
    string public description;

    Socials private _socials;

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
}
