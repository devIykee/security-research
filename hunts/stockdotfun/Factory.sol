// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPlatformControls} from "../interfaces/IPlatformControls.sol";
import {StockRouteRegistry} from "./StockRouteRegistry.sol";
import {MemeTokenV2} from "./MemeTokenV2.sol";
import {RewardVaultV2} from "./RewardVaultV2.sol";
import {BondingCurvePoolV2} from "./BondingCurvePoolV2.sol";

interface ITreasuryRegister {
    function registerPool(address pool, address stock, address holderVault, address creator) external;
}

interface IGradManagerRegister {
    function registerPool(address pool) external;
}

/// @title StockDotFunFactoryV2
/// @notice Assembles a full V2 launch (MemeTokenV2 + RewardVaultV2 +
///         BondingCurvePoolV2), wires it to the shared StockRewardTreasury and
///         GraduationManager, and exposes the platform pause switches. Only
///         VERIFIED stock routes may be launched, and a non-empty metadata URI
///         is mandatory (permanent metadata is uploaded before this call).
contract StockDotFunFactoryV2 is Ownable2Step, IPlatformControls {
    struct CurveConfig {
        uint16 totalFeeBps;
        uint16 holderShareBps;
        uint16 creatorShareBps;
        uint16 protocolShareBps;
        uint256 virtualQuote;
        uint256 virtualToken;
        uint256 graduationTarget;
        uint24 gradFee;
        int24 gradTickSpacing;
    }

    address public constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;

    StockRouteRegistry public immutable registry;

    address public treasury;
    address public graduationManager;
    address public graduationAdapter;
    bool private _wired;

    CurveConfig public curve;
    bool public creationPaused;
    bool public tradingPausedFlag;
    bool public claimsPausedFlag;

    address[] public allTokens;
    mapping(address token => address) public poolOf;
    mapping(address token => address) public vaultOf;

    error NotWired();
    error AlreadyWired();
    error ZeroAddress();
    error CreationPaused();
    error StockNotVerified();
    error EmptyMetadata();

    event Wired(address treasury, address graduationManager, address graduationAdapter);
    event TokenCreated(
        address indexed token,
        address indexed pool,
        address indexed creator,
        address stock,
        address holderVault,
        string name,
        string symbol,
        string metadataURI
    );
    event CurveConfigUpdated(CurveConfig config);
    event CreationPausedSet(bool paused);
    event TradingPausedSet(bool paused);
    event ClaimsPausedSet(bool paused);

    constructor(address owner_, address registry_, CurveConfig memory curve_) Ownable(owner_) {
        if (registry_ == address(0)) revert ZeroAddress();
        registry = StockRouteRegistry(registry_);
        _validateCurve(curve_);
        curve = curve_;
    }

    function wire(address treasury_, address graduationManager_, address graduationAdapter_) external onlyOwner {
        if (_wired) revert AlreadyWired();
        if (treasury_ == address(0) || graduationManager_ == address(0) || graduationAdapter_ == address(0)) {
            revert ZeroAddress();
        }
        treasury = treasury_;
        graduationManager = graduationManager_;
        graduationAdapter = graduationAdapter_;
        _wired = true;
        emit Wired(treasury_, graduationManager_, graduationAdapter_);
    }

    // ---- launch ----

    function createToken(string calldata name, string calldata symbol, string calldata metadataURI, address stock)
        external
        returns (address token, address pool)
    {
        if (!_wired) revert NotWired();
        if (creationPaused) revert CreationPaused();
        if (bytes(metadataURI).length == 0) revert EmptyMetadata();
        // Only VERIFIED (and non-stale) routes may launch in production.
        if (!registry.isConvertible(stock)) revert StockNotVerified();

        MemeTokenV2 meme = new MemeTokenV2(name, symbol, metadataURI);
        RewardVaultV2 vault = new RewardVaultV2(address(meme), address(this));

        BondingCurvePoolV2.InitParams memory ip = BondingCurvePoolV2.InitParams({
            memeToken: address(meme),
            weth: WETH,
            treasury: treasury,
            creator: msg.sender,
            graduationManager: graduationManager,
            graduationAdapter: graduationAdapter,
            gradFee: curve.gradFee,
            gradTickSpacing: curve.gradTickSpacing,
            feeConfig: BondingCurvePoolV2.FeeConfig({
                totalFeeBps: curve.totalFeeBps,
                holderShareBps: curve.holderShareBps,
                creatorShareBps: curve.creatorShareBps,
                protocolShareBps: curve.protocolShareBps
            }),
            virtualQuote: curve.virtualQuote,
            virtualToken: curve.virtualToken,
            graduationTarget: curve.graduationTarget
        });
        BondingCurvePoolV2 curvePool = new BondingCurvePoolV2(ip);

        meme.setPool(address(curvePool));
        meme.setRewardVault(address(vault));
        vault.initialize(address(curvePool), treasury, stock, WETH);
        IERC20(address(meme)).transfer(address(curvePool), meme.TOTAL_SUPPLY());

        ITreasuryRegister(treasury).registerPool(address(curvePool), stock, address(vault), msg.sender);
        IGradManagerRegister(graduationManager).registerPool(address(curvePool));

        poolOf[address(meme)] = address(curvePool);
        vaultOf[address(meme)] = address(vault);
        allTokens.push(address(meme));

        emit TokenCreated(
            address(meme), address(curvePool), msg.sender, stock, address(vault), name, symbol, metadataURI
        );
        return (address(meme), address(curvePool));
    }

    // ---- IPlatformControls ----

    function tradingPaused() external view returns (bool) {
        return tradingPausedFlag;
    }

    function claimsPaused() external view returns (bool) {
        return claimsPausedFlag;
    }

    // ---- admin ----

    function setCurveConfig(CurveConfig calldata c) external onlyOwner {
        _validateCurve(c);
        curve = c;
        emit CurveConfigUpdated(c);
    }

    function setCreationPaused(bool p) external onlyOwner {
        creationPaused = p;
        emit CreationPausedSet(p);
    }

    function setTradingPaused(bool p) external onlyOwner {
        tradingPausedFlag = p;
        emit TradingPausedSet(p);
    }

    function setClaimsPaused(bool p) external onlyOwner {
        claimsPausedFlag = p;
        emit ClaimsPausedSet(p);
    }

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }

    function _validateCurve(CurveConfig memory c) internal pure {
        require(c.totalFeeBps <= 1000, "fee>10%");
        require(uint256(c.holderShareBps) + c.creatorShareBps + c.protocolShareBps == 10000, "shares!=100%");
        require(c.virtualQuote > 0 && c.virtualToken > 0 && c.graduationTarget > 0, "curve=0");
        require(c.gradTickSpacing > 0, "ts=0");
    }
}
