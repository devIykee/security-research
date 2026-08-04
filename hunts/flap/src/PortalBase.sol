// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IPortal, IPortalCore, IPortalTypes} from "src/interfaces/IPortal.sol";
import {ITokenV2} from "src/interfaces/ITokenV2.sol";
import {IToken} from "src/interfaces/IToken.sol";
import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {LibCurve} from "src/libraries/Curve.sol";
import {IUniswapV3Factory} from "uni-v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV2Factory} from "uni-v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV3Pool} from "uni-v3-core/interfaces/IUniswapV3Pool.sol";
import {IUniswapV2Pair} from "uni-v2-core/interfaces/IUniswapV2Pair.sol";
import {IPancakeV3Factory} from "src/interfaces/3rd/IPancakeV3Factory.sol";
import {IMultiDexRouter} from "src/interfaces/IMultiDexRouter.sol";
import {PoolAddress} from "src/libraries/PoolAddress.sol";
import {PortalCommon} from "src/PortalCommon.sol";
import {EnumerableSetUpgradeable} from "@openzeppelin-contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import {ITokenV3} from "src/interfaces/ITokenV3.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title  The Portal Base contract
/// @notice Including Storage Definitions and Shared Functions
contract PortalBase is IPortalTypes, PortalCommon, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using SafeERC20 for IERC20;

    /// internal states
    /// @dev packed token state (@custom:deprecated)

    struct PackedTokenStateLegacy {
        IPortalTypes.TokenStatus status; // 8bit: the status of the token
        CurveType curveType; // 8bit: The curve type of the token
        DexThreshType dexThreshType; // 8bit: The dex threshold type of the token
        uint32 id; // 32bit: the id of the token
        uint96 reserve; // 96bit: the current reserve of the token
        uint96 dirtyOrCirculatingSupply; // 96bit: this is the circulating supply of the token, if the token version is at least V2
        // or this may be legacy dirty data.
        IPortalTypes.TokenVersion tokenVersion; // 8bit: the implementation this token is using
    }

    /// @dev The magic header to distinguish between the legacy packed token state and the new packed token state
    uint8 internal constant PACKED_TOKEN_STATE_HEADER = 0xff;

    /// @dev Extension information struct
    struct ExtensionInfo {
        /// @notice The address of the extension contract
        address addr;
        /// @notice The version of the extension, starting from 1
        uint8 version;
    }

    /// @dev pacake token state v2
    struct PackedTokenStateV2 {
        //
        // slot0: header + status + immutable data
        //
        uint8 header;
        // 8bit: The header is always 0xff or it is the legacy PackedTokenState
        IPortalTypes.TokenStatus status; // 8bit: the status of the token
        CurveType curveType; // 8bit: The curve type of the token
        DexThreshType dexThreshType; // 8bit: The dex threshold type of the token
        uint32 id; // 32bit: the id of the token
        IPortalTypes.TokenVersion tokenVersion; // 8bit: the implementation this token is using
        IPortalTypes.QuoteTokenType quoteToken; // 8bit: the quote token type of the token
        IPortalTypes.MigratorType migratorType; // 8bit: the migrator type of the token
        uint8 usingExtension; // 8bit: If non-zero, indicates this token uses an extension
        uint8 dexId; // 8bit: DEX ID for multiple DEXes support
        IPortalTypes.V3LPFeeProfile lpFeeProfile; // 8bit: V3 LP fee profile for the token
        FlapFeeProfile feeProfile; // 8bit: Fee profile for the token
        uint16 maxBuyBpsPerOrigin; // 16bit: per-tx.origin cumulative buy cap, in bps of maxSupply. 0 = disabled (unlimited)
        uint120 unused; // 120bit: Unused space for future use, should be set to zero
        //
        // slot1: reserve + circulating supply
        //
        uint128 reserve;
        // 128bit: the current reserve of the token
        uint128 circulatingSupply; // 128bit: the current circulating supply of the token
        //
        // slot2: the quote token address of the token
        uint96 unused2; // 96bit: reserved for future use
        address quoteTokenAddress;
        //
        // slot3: extension ID (only if usingExtension is non-zero)
        //
        bytes32 extensionID;
    }

    // 256bit: The ID of the extension used by the token, if any or zero if no extension is used

    // bit mask for bit flags

    /// @dev Parsed representation of a NewTokenV7Params.feeConfigs[4] array.
    ///      Avoids stack-too-deep by grouping all derived fee values in one struct.
    struct V7ParsedFees {
        // ── Other fee types ──────────────────────────────────────────
        uint16 deflationBps;
        uint16 lpBps;
        uint16 dividendBps;
        uint256 minimumShareBalance;
        address dividendToken;
        // ── Marketing / vault wallets (up to 4 MARKETING_OR_VAULT slots) ─
        address mktAddr1;
        uint16 mktBps1;
        address mktAddr2;
        uint16 mktBps2;
        address mktAddr3;
        uint16 mktBps3;
        address mktAddr4;
        uint16 mktBps4;
        /// @dev Sum of all MARKETING_OR_VAULT bps.
        ///      Used as mktOrVaultBps1 in TaxProcessorV2 initialize() so that
        ///      setWalletConfig() can later distribute the remainder among addr2/3/4.
        uint16 totalMktBps;
    }

    /// @dev Global switch bit.
    ///      Common combinations after the V7 split:
    ///      - 0: fully halted
    ///      - 1: global features on, but `newTokenV7` paused
    ///      - 3: global features on and `newTokenV7` enabled
    uint256 internal constant CB_BIT_MASK_GLOBAL_SWITCH = 1;

    /// @dev Dedicated switch for V7 launches.
    ///      If this bit is off while CB_BIT_MASK_GLOBAL_SWITCH stays on,
    ///      only `newTokenV7` is paused and other entrypoints keep working.
    ///      This bit must be combined with CB_BIT_MASK_GLOBAL_SWITCH, so the
    ///      normal "V7 enabled" setting is `1 | 2 == 3`.
    uint256 internal constant CB_BIT_MASK_NEW_TOKEN_V7_SWITCH = 1 << 1;

    uint256 internal constant DEFAULT_BIT_FLAGS = CB_BIT_MASK_GLOBAL_SWITCH | CB_BIT_MASK_NEW_TOKEN_V7_SWITCH;

    /// guardian role
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// tax manager role - can update tax token addresses
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    /// tax guardian role - can change market wallet on V2/V3 tax tokens and update V1 tax splitter addresses
    bytes32 public constant TAX_GUARDIAN_ROLE = keccak256("TAX_GUARDIAN_ROLE");

    /// token flap fee setter role - can set fee profile for tokens
    bytes32 public constant TOKEN_FLAP_FEE_SETTER_ROLE = keccak256("TOKEN_FLAP_FEE_SETTER_ROLE");

    /// moderator role - can manage blocked spammers
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    // max supply of the token
    uint256 internal constant maxSupply = 1e9 ether;

    /// @dev Default per-tx.origin cumulative buy cap (bps of maxSupply) applied to
    ///      TOKEN_V3_PERMIT tokens launched via newTokenV7 on BSC mainnet (56) and testnet (97).
    ///      200 bps = 2%.
    uint16 internal constant DEFAULT_MAX_BUY_BPS = 200;

    // V4/Infinity constants

    /// @notice Uniswap V4 LP fee for 1.25% feeTier.
    /// Uniswap charges zero protocol fee, so swapFee = lpFee directly.
    /// swapFee = 12_500 ppm = 1.25%
    uint24 public constant DEFAULT_V4_NORMAL_FEE_PIPS = 12_500;

    /// @notice PCS Infinity CL LP fee for 1.25% feeTier.
    /// PCS charges protocol fee (default 33% split, capped at 4000 ppm), so lpFee must be
    /// set lower than the target swapFee. Derived via getLPFeeFromTotalFee(12_500):
    ///   oneDirectionProtocolFee = min(12500 * 33% , 4000) = 4000 ppm (hits MAX_PROTOCOL_FEE cap)
    ///   lpFee = (12500 - 4000) * 1e6 / (1e6 - 4000) = 8534 ppm
    ///   verify: swapFee = 4000 + 8534 - (4000 * 8534 / 1e6) = 12534 - 34 = 12500 ppm = 1.25% ✓
    uint24 public constant DEFAULT_PCS_INFINITY_NORMAL_FEE_PIPS = 8_534;

    /// @notice Fixed tick spacing for DEFAULT_V4_NORMAL_FEE_PIPS (12_500 / 50 = 250).
    int24 public constant DEFAULT_V4_TICK_SPACING = 250;

    /// @notice Tax processor fee rate during the bonding curve phase (60% of collected fee → protocol).
    ///         Applied to TOKEN_V3_PERMIT tokens launched via V4 / PCS Infinity migrators.
    uint16 internal constant TAX_PROC_BONDING_CURVE_FEE_RATE = 6000;

    /// @notice Tax processor fee rate after DEX graduation (41% of collected fee → protocol).
    ///         Set automatically by the V4 / PCS Infinity migrator on luanchToDEX().
    uint16 internal constant TAX_PROC_DEX_FEE_RATE = 4100;

    /// @notice Bonding-curve fee rate (bps) for non-tax TOKEN_V3_PERMIT tokens (1.25%).
    ///         Applied symmetrically on buy and sell during bonding curve trading.
    ///         Collected fee is sent to the token beneficiary.
    uint16 internal constant DEFAULT_V4_NON_TAX_FEE_RATE_BPS = 125;

    // Immutables

    //
    // The token implementations
    //

    /// @dev The implementation for
    ///      TOKEN_LEGACY_MINT_NO_PERMIT & TOKEN_LEGACY_MINT_NO_PERMIT_DUPLICATE
    IToken internal immutable tokenImplLegacy;

    /// @dev The implementation for TOKEN_V2_PERMIT
    ITokenV2 internal immutable tokenImplV2;

    /// @dev The PortalTokenV2Deployer for CREATE2-based deployment
    address internal immutable portalTokenV2Deployer;

    /// @dev The implementation for TOKEN_GOPLUS (pending)
    address internal immutable tokenImplGoPlus = address(0);

    /// @dev The implementation for TOKEN_TAXED
    address internal immutable tokenImplTaxed;

    /// @dev The implementation for TaxSplitter
    address internal immutable taxSplitterImpl;

    /// @dev The implementation for TOKEN_TAXED_V2 (FlapTaxTokenV2)
    address internal immutable tokenImplTaxedV2;

    /// @dev The implementation for TaxProcessorV2 (V1)
    address internal immutable taxProcessorImplUniV2;

    /// @dev The implementation for TaxProcessorV2 (pluggable modules, V4/PCS Infinity LP fee support).
    ///      Named "UniV4" for historical reasons; shared between Uniswap V4 (Base/XLayer)
    ///      and PCS Infinity CL (BSC) token launches.
    address internal immutable taxProcessorImplUniV4;

    /// @dev The implementation for Dividend contract
    address internal immutable dividendImpl;

    /// @dev The implementation for TOKEN_TAXED_V3 (FlapTaxTokenV3)
    address internal immutable tokenImplTaxedV3;

    /// @dev The default converter address for MEV-protected dividend token swaps in V3 tax tokens
    address internal immutable converter;

    /// @dev The SwapRegistry address for validating quote→dividend swap support at launch time
    address internal immutable SWAP_REGISTRY;

    /// Fee receiver
    address internal immutable FEE_RECEIVER;

    //
    // Facets
    //

    /// @dev Migrator: The address of the migrator contract
    /// The migrator contract is used to migrate the tokens from bonding curve to Uniswap V3 DEX
    address internal immutable PORTAL_UNIV3_MIGRATOR;

    /// @dev TaxTokenMigrator: The address of the migrator contract
    /// This migrator contract is used to migrate the tax tokens from bonding curve to Uniswap V2 DEX
    address internal immutable PORTAL_UNIV2_MIGRATOR;

    /// @dev The Token Launcher contract address
    address internal immutable PORTAL_LAUNCHER;

    /// @dev The Token Launcher Two Step contract address
    address internal immutable PORTAL_LAUNCHER_TWO_STEP;

    /// @dev The Token Trade V2 contract address
    address internal immutable PORTAL_TRADE_V2;

    /// @dev The Portal Roller Contract Address
    address internal immutable PORTAL_ROLLER;

    /// @dev The Portal DEX Router contract address
    address internal immutable PORTAL_DEX_ROUTER;

    /// @dev The Portal Tweak Module
    address internal immutable PORTAL_TWEAK;

    /// @dev The Portal Lens Module
    address internal immutable PORTAL_LENS;

    /// @dev The Portal Lens V2 Module (getTokenV9Safe and future lens methods)
    address internal immutable PORTAL_LENS_V2;

    /// @dev The Multi-DEX Router contract address
    IMultiDexRouter internal immutable MULTI_DEX_ROUTER;

    //
    // V4 / PCS Infinity Related
    //

    /// @dev PortalUniV4Migrator implementation address (delegatecall target)
    address internal immutable PORTAL_UNI_V4_MIGRATOR;

    /// @dev Uniswap V4 PoolManager singleton address.
    ///      Used for transfer-constraint whitelisting and slot0 queries on UniV4 chains (Base, XLayer).
    ///      On PCS Infinity chains this is unused (address(0)); use PCS_INFINITY_VAULT instead.
    address internal immutable V4_SINGLETON;

    /// @dev The hook contract for Uniswap V4 or PCS InfinityCL (FlapV4Hook, delegatecall target for PM hooks)
    address internal immutable V4_CL_HOOK;

    /// @dev Uniswap V4 PositionManager address
    address internal immutable V4_POSITION_MANAGER;

    /// @dev GoPlus Uniswap V4 LP Locker address
    address internal immutable GOPLUS_UNI_V4_LOCKER;

    /// @dev PortalPCSInfinityCLMigrator implementation address
    address internal immutable PORTAL_PCS_INFINITY_CL_MIGRATOR;

    /// @dev PCS Infinity CL PositionManager address
    address internal immutable PCS_INFINITY_CL_POSITION_MANAGER;

    /// @dev PCS Infinity CLPoolManager address (handles swaps & liquidity; distinct from Vault)
    address internal immutable PCS_INFINITY_CL_POOL_MANAGER;

    /// @dev PCS Infinity Vault address (settles token balances; distinct from CLPoolManager).
    ///      Used for transfer-constraint whitelisting and as mainPool_ sentinel on PCS chains (BSC).
    ///      On UniV4 chains this is unused (address(0)); use V4_SINGLETON instead.
    address internal immutable PCS_INFINITY_VAULT;

    /// @dev PCS Infinity BIN PositionManager address (reserved)
    address internal immutable PCS_INFINITY_BIN_POSITION_MANAGER;

    /// @dev GoPlus PCS Infinity CL LP Locker address
    address internal immutable GOPLUS_PCS_INFINITY_LOCKER;

    /// @dev Portal V4 CL Locker — delegatecall target for LP locking, fee collection & liquidity management.
    ///      shared between Uniswap V4 (Base/XLayer) and PCS Infinity CL (BSC).  See PortalUniV4Locker.sol.
    address internal immutable PORTAL_V4_CL_LOCKER;

    /// @dev The implementation for TOKEN_V3_LP_REWARD (TokenV3 — non-tax with V4 LP fee distribution)
    /// @notice Set at deploy time.  address(0) disables TOKEN_V3_LP_REWARD launches.
    ITokenV3 internal immutable tokenImplV3;

    //
    // DEX Related immutables
    //

    /// @dev The address of WETH
    address internal immutable WETH_ADDRESS;

    /// @dev The profile for deployment-specific parameters or behaviors
    IPortalTypes.Profile internal immutable PROFILE;

    /// @dev Whether to enable tax on bonding curve
    bool internal immutable ENABLE_TAX_ON_BONDING_CURVE;

    /// @dev Whether to enable next features
    bool internal immutable ENABLE_NEXT_FEATURES;

    /// @dev Whether to enable spammer blocker
    bool internal immutable ENABLE_SPAMMER_BLOCKER;

    /// @dev Address of the AntiScamModule (IAntiScamModule) proxy.
    ///      address(0) disables the anti-scam check (module not deployed).
    address internal immutable ANTI_SCAM_MODULE;

    /// @dev The SaleForge contract address (if deployed)
    address internal immutable SALE_FORGE;

    /// @dev Fee (in native gas token) required to lock a salt via lockSalt()
    uint256 public immutable SALT_LOCK_FEE;

    /// @dev Trusted caller address (VaultPortal) that can provide a salt owner via ISaltOwnerProvider.getSaltOwner()
    address public immutable VAULT_PORTAL;

    //
    // misc
    //

    //
    // internal states
    //

    /// A _nonce used as the seed for creating new token
    /// @dev slot 151
    uint256 internal _nonce;

    /// @dev mapping from tokenAddress To PackedTokenState or PackedTokenStateV2
    /// This could be either mapping(address => PackedTokenStateLegacy) or mapping(address => PackedTokenStateV2)
    /// check _getTokenState for more details.
    /// slot: 152
    mapping(address => uint256) internal _packedTokenStates;

    /// @dev previously slots for the game feature:
    ///      slots: [153,158]
    uint256[6] private _gap00000;

    /// @dev @obsolete redeem rates in WAD for killed tokens, src token => dst Token => rate
    /// slot: 159
    mapping(address srcToken => mapping(address dstToken => uint256)) internal redeemRates;

    /// @dev bit flags
    /// slot: 160
    uint256 internal bitFlags;

    /// @dev obsolete slots:
    ///   - 2 slots: the game.GameConfig
    ///   - 1 slot: whitelist feature
    ///   - 1 slot: obsolete check-in data (mapping(address => uint256))
    uint256[4] private _gap00001;

    struct PackedLPLocks {
        uint64[2] locks;
    }
    // the remaining 128 bits are reserved for future use

    /// @dev mapping from token to locks
    /// slot: 165
    mapping(address => PackedLPLocks) internal lpLocks;

    /// @dev
    /// obsolete slots:
    ///   - 1 slot: obsolete existingMetas (mapping(bytes32 => bool))
    ///   - 1 slot: obsolete number of tokens created by each user (mapping(address => uint256))
    ///   - 1 slot: obsolete mapping to track users exempted from creation fee (mapping(address => bool))
    uint256[3] private _gap00002;

    /// @dev mapping from token to beneficiary, slot: 169
    mapping(address => address) internal _tokenBeneficiaries;

    /// @dev mapping from allowed quote token address to the configuration
    mapping(address => IPortalTypes.QuoteTokenConfiguration) internal _quoteTokenConfigurations;

    /// @dev mapping from extensionID to ExtensionInfo
    mapping(bytes32 => ExtensionInfo) internal extensions;

    /// @dev mapping from quote token address to its favored fee for Uniswap V3 pools
    /// deprecated: This is a legacy value for tokens created through legacy newTokenV2/V3 Methods
    mapping(address => uint24) internal _v3FavoredFees;

    /// @dev mapping from token address to packed DEX pool information
    mapping(address => IPortalTypes.PackedDexPool) internal _dexPools;

    /// @dev @obsolete mapping from trader address to fee exemption status (invalidated)
    /// This slot is now a gap to invalidate all existing fee exempted traders
    uint256 private _gap00003;

    /// @dev mapping from staged token address to the stager (who staged the token)
    /// Used to verify that only the stager can commit the token
    mapping(address => address) internal _stagedTokenStagers;

    /// @dev Spammer information for rate limiting
    struct SpammerInfo {
        bool blocked; // 8 bits: whether the user is blocked from creating tokens
        uint64 lastSuccessfulCreation; // 64 bits: timestamp of last successful token creation
        uint184 reserved; // 184 bits: reserved for future use
    }

    /// @dev mapping from user address to spammer information
    mapping(address => SpammerInfo) internal _blockedSpammers;

    /// @dev mapping from trader address to fee exemption status
    /// These users may have paid a subscription fee or have special agreements with the platform
    mapping(address => bool) internal _feeExemptedTraders;

    /// @dev mapping from CREATE2 salt to its lock entry (zero locker = unlocked)
    mapping(bytes32 => IPortalTypes.SaltLockEntry) internal _saltLocks;

    /// @dev per-user, per-tokenVersion enumerable set of salts locked by that user (on-chain index; populated from v5.11.0 onwards)
    /// @notice Pre-upgrade locks are not present here; use getSaltLock(bytes32) for point-lookups.
    /// Key: user address → TokenVersion (as uint8) → salt set.
    mapping(address => mapping(uint8 => EnumerableSetUpgradeable.Bytes32Set)) internal _userSaltsByVersion;

    /// @dev Per-token, per-tx.origin cumulative bonding-curve buy amount (absolute token units).
    ///      Used to enforce PackedTokenStateV2.maxBuyBpsPerOrigin on the internal market.
    mapping(address token => mapping(address origin => uint256 bought)) internal _boughtByOrigin;

    /// @dev Generic, reusable global feature switch. Off by default; toggled via setNewFeatureSwitch
    ///      (DEFAULT_ADMIN_ROLE) and read via newFeatureSwitch. It gates whatever the current release
    ///      wires it to — once that feature is retired, a later release can repurpose this same bool
    ///      for the next feature (no new storage slot needed).
    ///      Currently gates the default per-origin buy cap on newTokenV7: when true AND the chain is
    ///      eligible (56/97/4663), newTokenV7 applies DEFAULT_MAX_BUY_BPS; otherwise no default cap.
    bool internal _newFeatureSwitch;

    // Note: new offset based storage can only be appended here
    // Never add any offset-based storage in other files except PortalBase.sol

    /// @dev The init params for the portal
    struct PortalInitParams {
        //
        // Internal Facets
        //

        /// The Token Launcher implementation
        address tokenLauncher_;
        /// The Token Launcher Two Step implementation
        address tokenLauncherTwoStep_;
        /// The Token Trade V2 implementation
        address tokenTradeV2_;
        /// The Roller implementation
        address roller_;
        /// The Portal DEX Router implementation
        address portalDexRouter_;
        /// migrator for uniswap v3
        address uniV3Migrator_;
        /// migrator for uniswap v2
        address uniV2Migrator_;
        /// The PortalTokenV2Deployer implementation
        address portalTokenV2Deployer_;
        /// portal uni v3 locker
        address _portalUniV3Locker;
        /// portal tweak
        address _portalTweak;
        /// portal lens
        address _portalLens;
        /// portal lens v2 (getTokenV9Safe and future lens methods)
        address portalLensV2_;
        //
        // Templates
        //

        /// TaxSplitter implementation address
        address taxSplitterImpl_;
        /// The legacy token implementation
        address tokenImpl_;
        /// The V2 token implementation
        address tokenImplV2_;
        /// The V3 LP reward token implementation (TOKEN_V3_LP_REWARD, optional)
        address tokenImplV3_;
        /// The tax token implementation (V1)
        address tokenImplTaxed_;
        /// The tax token V2 implementation (FlapTaxTokenV2)
        address tokenImplTaxedV2_;
        /// The tax processor implementation
        address taxProcessorImplUniV2_;
        /// The TaxProcessorV2 implementation (V4/PCS Infinity LP fee support; named "UniV4" for historical reasons)
        address taxProcessorImplUniV4_;
        /// The dividend contract implementation
        address dividendImpl_;
        /// The tax token V3 implementation (FlapTaxTokenV3)
        address tokenImplTaxedV3_;
        /// The default converter address for MEV-protected dividend token swaps in V3 tax tokens
        address converter_;
        /// The SwapRegistry address for validating quote→dividend swap support at launch time (optional)
        address swapRegistry_;
        /// The PortalLauncherV5 implementation for delegatecall dispatch of V5 non-tax tokens
        address launcherV5Impl_;
        /// The PortalLauncherTaxV3 implementation for delegatecall dispatch of newTokenV6
        address launcherV6Impl_;
        /// The PortalLauncherV5Tax implementation for delegatecall dispatch of V5 tax tokens
        address launcherV5TaxImpl_;
        /// Portal Launcher V7 implementation
        address launcherV7Impl_;
        /// The PortalLauncherUniV4Tax implementation for delegatecall dispatch of V7 TOKEN_TAXED_V3
        ///   via V4/PCS-Infinity migration.  Pre-deployed for the same size reason.
        address launcherV7TaxImpl_;
        /// The Multi-DEX Router implementation
        address multiDexRouter_;
        /// The fee receiver
        address feeReceiver_;
        //
        // Fee
        //

        /// The buy fee rate
        uint256 buyFeeRate_;
        /// The sell fee rate
        uint256 sellFeeRate_;
        /// Liquidity fee in basis points (0-10000, where 100 = 1%)
        uint256 liquidityFee_;
        /// Reserve fee in basis points (0-10000, where 100 = 1%)
        uint256 reserveFee_;
        //
        // Migrator Related
        //

        /// The WETH address
        address weth_;
        /// uncx locker  (p3, if not zero address)
        address _uncxLiquidityLocker;
        /// goplus locker  (p2, if not zero address)
        address _goplusLocker;
        /// Suffix for non-tax token vanity address (if 0, defaults to 0x8888)
        uint16 nonTaxTokenSuffix_;
        /// Suffix for tax token vanity address (if 0, defaults to 0x7777)
        uint16 taxTokenSuffix_;
        //
        // (optional) Deployment Profile
        //

        /// The profile for deployment-specific parameters or behaviors
        IPortalTypes.Profile profile_;
        /// Whether to enable tax on bonding curve
        /// @deprecated, this will always be true
        bool enableTaxOnBondingCurve_;
        /// Whether to enable next features
        bool enableNextFeatures_;
        /// Whether to enable spammer blocker
        bool enableSpammerBlocker_;
        /// Address of the AntiScamModule (IAntiScamModule) proxy (address(0) to disable)
        address antiScamModule_;
        /// The SaleForge contract address (optional)
        address saleForge_;
        /// Fee (in native gas token) required to lock a salt (0 = feature disabled)
        uint256 saltLockFee_;
        /// VaultPortal address — trusted caller for ISaltOwnerProvider.getSaltOwner() callback (optional)
        address vaultPortal_;

        //
        // V4 / PCS Infinity Related
        //

        /// Uniswap V4 migrator
        address uniV4Migrator_;
        /// Uniswap V4 PoolManager
        address v4PoolManager_;
        /// Uniswap V4 PositionManager
        address v4PositionManager_;
        /// GoPlus V4 Locker
        address goplusUniV4Locker_;
        /// PCS Infinity CL migrator
        address pcsInfinityCLMigrator_;
        /// PCS Infinity CL PositionManager
        address pcsInfinityCLPositionManager_;
        /// PCS Infinity CLPoolManager (swaps & liquidity)
        address pcsInfinityCLPoolManager_;
        /// PCS Infinity Vault (settlement contract; handles accounting, distinct from CLPoolManager)
        address pcsInfinityVault_;
        /// PCS Infinity BIN PositionManager (reserved)
        address pcsInfinityBINPositionManager_;
        /// GoPlus PCS Infinity CL Locker
        address goplusPcsInfinityLocker_;
        /// Portal V4 CL Locker (shared between UniV4 and PCS Infinity; contract file: PortalUniV4Locker.sol)
        address portalV4CLLocker_;
        /// V4 Hook (FlapV4Hook or FlapInfinityCLHook) — shared for all Uniswap V4 pools
        address v4CLHook_;
    }

    constructor(PortalInitParams memory params)
        PortalCommon(params.buyFeeRate_, params.sellFeeRate_, params.liquidityFee_, params.reserveFee_)
    {
        // internal Facets
        PORTAL_UNIV3_MIGRATOR = params.uniV3Migrator_;
        PORTAL_UNIV2_MIGRATOR = params.uniV2Migrator_;
        PORTAL_LAUNCHER = params.tokenLauncher_;
        PORTAL_LAUNCHER_TWO_STEP = params.tokenLauncherTwoStep_;
        PORTAL_TRADE_V2 = params.tokenTradeV2_;
        PORTAL_ROLLER = params.roller_;
        PORTAL_DEX_ROUTER = params.portalDexRouter_;
        PORTAL_TWEAK = params._portalTweak;
        PORTAL_LENS = params._portalLens;
        PORTAL_LENS_V2 = params.portalLensV2_;

        ENABLE_TAX_ON_BONDING_CURVE = true; // always true regardless of the constructor parameter
        ENABLE_NEXT_FEATURES = params.enableNextFeatures_;
        ENABLE_SPAMMER_BLOCKER = params.enableSpammerBlocker_;
        ANTI_SCAM_MODULE = params.antiScamModule_;
        SALE_FORGE = params.saleForge_;
        SALT_LOCK_FEE = params.saltLockFee_;
        VAULT_PORTAL = params.vaultPortal_;

        // optional facet:
        portalTokenV2Deployer = params.portalTokenV2Deployer_;

        // Critical External
        if (params.multiDexRouter_ == address(0)) {
            revert MultiDexRouterCannotBeZero();
        }
        MULTI_DEX_ROUTER = IMultiDexRouter(params.multiDexRouter_);
        WETH_ADDRESS = params.weth_;

        // Factory implementations
        tokenImplLegacy = IToken(params.tokenImpl_);
        tokenImplV2 = ITokenV2(params.tokenImplV2_);
        tokenImplV3 = ITokenV3(params.tokenImplV3_);
        tokenImplTaxed = params.tokenImplTaxed_;
        taxSplitterImpl = params.taxSplitterImpl_;

        // New V2 factory implementations
        tokenImplTaxedV2 = params.tokenImplTaxedV2_;

        taxProcessorImplUniV2 = params.taxProcessorImplUniV2_;
        taxProcessorImplUniV4 = params.taxProcessorImplUniV4_;
        dividendImpl = params.dividendImpl_;

        // New V3 factory implementations
        tokenImplTaxedV3 = params.tokenImplTaxedV3_;
        converter = params.converter_;
        SWAP_REGISTRY = params.swapRegistry_;

        // critical constant address
        FEE_RECEIVER = params.feeReceiver_;

        // Any chain specific parameters or behaviors
        PROFILE = params.profile_;

        // V4 / PCS Infinity immutables
        PORTAL_UNI_V4_MIGRATOR = params.uniV4Migrator_;
        V4_SINGLETON = params.v4PoolManager_;
        V4_POSITION_MANAGER = params.v4PositionManager_;
        GOPLUS_UNI_V4_LOCKER = params.goplusUniV4Locker_;
        PORTAL_PCS_INFINITY_CL_MIGRATOR = params.pcsInfinityCLMigrator_;
        PCS_INFINITY_CL_POSITION_MANAGER = params.pcsInfinityCLPositionManager_;
        PCS_INFINITY_CL_POOL_MANAGER = params.pcsInfinityCLPoolManager_;
        PCS_INFINITY_VAULT = params.pcsInfinityVault_;
        PCS_INFINITY_BIN_POSITION_MANAGER = params.pcsInfinityBINPositionManager_;
        GOPLUS_PCS_INFINITY_LOCKER = params.goplusPcsInfinityLocker_;
        PORTAL_V4_CL_LOCKER = params.portalV4CLLocker_;
        V4_CL_HOOK = params.v4CLHook_;
    }

    /// @notice Modifier to check if the given bit mask is enabled in bitFlags
    modifier onlyIfBitFlagsSet(uint256 mask) {
        if (!_checkBitFlags(mask)) revert FeatureDisabled();
        _;
    }

    /// @dev check bit flags
    /// If a bit is off, means the feature is disabled
    function _checkBitFlags(uint256 mask) internal view returns (bool) {
        // We only check the bits in the mask are set
        // And ignore the bits that are not in the mask
        //
        //  -  mask => with only checking bits set
        //  -  mask ^ bitFlags =>
        //          XOR: all checking bits should be unset, if
        //          they are set in the bitFlags.
        //  - _ & mask, ignore the bits that are not in the mask
        //
        return (mask ^ bitFlags) & mask == 0;
    }

    /// @dev _revert with returnData
    function _revert(bytes memory returndata) internal pure {
        if (returndata.length > 0) {
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert CallReverted();
        }
    }

    //
    // token related
    // for different version of token, the behavior is different
    //

    /// @dev get the circulating supply of a token
    /// @param state the current state of a token
    /// @param token the address of the token
    /// @return the circulating supply of the token
    function _circulatingSupply(PackedTokenStateV2 memory state, address token) internal view returns (uint256) {
        if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT_DUPLICATE
        ) {
            return IToken(token).totalSupply();
        } else if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V2_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V2
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V3
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V3_PERMIT
        ) {
            return uint256(state.circulatingSupply);
        } else {
            revert NotImplemented();
        }
    }

    /// @dev mint token:
    ///    for tokenVersion < V2, we mint the token through the token contract
    ///    for tokenVersion >= V2, we transfer token from this contract to the recipient
    /// @dev Note! this function changes the state of the token
    function _mintToken(address token, uint256 amount, address recipient) internal {
        PackedTokenStateV2 memory state = _getTokenState(token);

        if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT_DUPLICATE
        ) {
            IToken(token).mint(recipient, amount);
            state.circulatingSupply = uint128(IToken(token).totalSupply());
        } else if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V2_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V2
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V3
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V3_PERMIT
        ) {
            IERC20(token).safeTransfer(recipient, amount);
            state.circulatingSupply += uint128(amount);
        } else {
            revert NotImplemented();
        }

        // flush state
        _setTokenCirculatingSupply(token, state.circulatingSupply);

        // emit circulation update
        emit FlapTokenCirculatingSupplyChanged(token, uint256(state.circulatingSupply));
    }

    /// @dev "burn" token
    ///    for tokenVersion < V2, we burn the token through the token contract
    ///    for tokenVersion >= V2, we transfer token from the payer to this contract
    function _burnToken(address token, uint256 amount, address payer) internal {
        PackedTokenStateV2 memory state = _getTokenState(token);

        if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_LEGACY_MINT_NO_PERMIT_DUPLICATE
        ) {
            IToken(token).burn(payer, amount);
            state.circulatingSupply = uint128(IToken(token).totalSupply());
        } else if (
            state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V2_PERMIT
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V2
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_TAXED_V3
                || state.tokenVersion == IPortalTypes.TokenVersion.TOKEN_V3_PERMIT
        ) {
            // gas saving if the token has already been transferred to this contract before calling _burnToken
            // we don't need to do a self transfer in this case.
            if (payer != address(this)) {
                IERC20(token).safeTransferFrom(payer, address(this), amount);
            }
            state.circulatingSupply -= uint128(amount);
        } else {
            revert NotImplemented();
        }

        // flush state
        _setTokenCirculatingSupply(token, state.circulatingSupply);
        // emit circulation update
        emit FlapTokenCirculatingSupplyChanged(token, uint256(state.circulatingSupply));
    }

    /// @dev erase token: erase unused token that is more than the expected circulating supply
    ///   The amount of token erased cannot be minted again.
    ///   for tokenVersion < V2, we do nothing, because they are never minted
    ///   for tokenVersion >= V2, we transfer token from this contract to dead address
    function _eraseToken(address token, uint256 amount) internal {
        PackedTokenStateV2 memory state = _getTokenState(token);

        // Note! this does not change the circulating supply

        if (state.tokenVersion >= IPortalTypes.TokenVersion.TOKEN_V2_PERMIT) {
            IERC20(token).safeTransfer(address(0x000000000000000000000000000000000000dEaD), amount);
        }
    }

    /**
     * @dev Delegates the current call to the specified implementation contract.
     * Uses `delegatecall` to forward the call, preserving the caller's context.
     * Reverts if the delegatecall fails.
     * @param impl The address of the implementation contract to delegate the call to.
     */
    function _delegateToImpl(address impl) internal {
        if (impl == address(0)) {
            revert FeatureDisabled();
        }
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @dev Returns the PackedTokenStateV2 for a given token address.
    /// If the stored state is legacy, it converts it to V2 struct.
    function _getTokenState(address token) internal view returns (PackedTokenStateV2 memory state) {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 packed;
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
            packed := sload(slot)
        }

        uint8 header = uint8(packed);
        if (header != PACKED_TOKEN_STATE_HEADER) {
            // Legacy: manually parse fields from packed uint256 (lower-order aligned)
            state.header = PACKED_TOKEN_STATE_HEADER;
            state.status = IPortalTypes.TokenStatus(uint8(packed));
            state.curveType = CurveType(uint8(packed >> 8));
            state.dexThreshType = DexThreshType(uint8(packed >> 16));
            state.id = uint32(packed >> 24);
            state.reserve = uint128(uint96(packed >> 56));
            state.circulatingSupply = uint128(uint96(packed >> 152));
            state.tokenVersion = IPortalTypes.TokenVersion(uint8(packed >> 248));
            state.quoteToken = IPortalTypes.QuoteTokenType.NATIVE_GAS_TOKEN;
            state.dexId = 0; // Default DEX ID for legacy tokens
            state.lpFeeProfile = IPortalTypes.V3LPFeeProfile.LP_FEE_PROFILE_LOW; // Default LP fee profile for legacy tokens
            state.feeProfile = FlapFeeProfile.FEE_GLOBAL_DEFAULT; // Default fee profile for legacy tokens
        } else {
            // parse slot0
            state.header = uint8(packed);
            state.status = IPortalTypes.TokenStatus(uint8(packed >> 8));
            state.curveType = CurveType(uint8(packed >> 16));
            state.dexThreshType = DexThreshType(uint8(packed >> 24));
            state.id = uint32(packed >> 32);
            state.tokenVersion = IPortalTypes.TokenVersion(uint8(packed >> 64));
            state.quoteToken = IPortalTypes.QuoteTokenType(uint8(packed >> 72));
            state.migratorType = IPortalTypes.MigratorType(uint8(packed >> 80));
            state.usingExtension = uint8(packed >> 88);
            state.dexId = uint8(packed >> 96);
            state.lpFeeProfile = IPortalTypes.V3LPFeeProfile(uint8(packed >> 104));
            state.feeProfile = FlapFeeProfile(uint8(packed >> 112));
            state.maxBuyBpsPerOrigin = uint16(packed >> 120);
            state.unused = uint120(packed >> 136);

            // read slot1
            uint256 slotValue;
            assembly ("memory-safe") {
                slotValue := sload(add(slot, 1))
            }
            state.reserve = uint128(slotValue);
            state.circulatingSupply = uint128(slotValue >> 128);

            // gas saving: only read slot2 if state.tokenVersion is not NATIVE_GAS_TOKEN
            if (state.quoteToken != IPortalTypes.QuoteTokenType.NATIVE_GAS_TOKEN) {
                // read slot2
                uint256 slot2Value;
                assembly ("memory-safe") {
                    slot2Value := sload(add(slot, 2))
                }
                state.quoteTokenAddress = address(uint160(slot2Value));
            }

            // read slot3 (extensionID) if token is using extension
            if (state.usingExtension != 0) {
                uint256 slot3Value;
                assembly ("memory-safe") {
                    slot3Value := sload(add(slot, 3))
                }
                state.extensionID = bytes32(slot3Value);
            }
        }
    }

    /// @dev set the token status
    function _setTokenStatus(address token, IPortalTypes.TokenStatus status) internal {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
        }
        uint256 packed;
        assembly ("memory-safe") {
            packed := sload(slot)
        }
        uint8 header = uint8(packed);
        if (header != PACKED_TOKEN_STATE_HEADER) {
            packed = (packed & ~uint256(0xff)) | uint8(status);
            assembly ("memory-safe") {
                sstore(slot, packed)
            }
        } else {
            packed = (packed & ~(uint256(0xff) << 8)) | (uint256(uint8(status)) << 8);
            assembly ("memory-safe") {
                sstore(slot, packed)
            }
        }
    }

    /// @dev set the token reserve
    function _setTokenReserve(address token, uint128 reserve) internal {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
        }
        uint256 packed;
        assembly ("memory-safe") {
            packed := sload(slot)
        }
        uint8 header = uint8(packed);
        if (header != PACKED_TOKEN_STATE_HEADER) {
            packed = (packed & ~(uint256(type(uint96).max) << 56)) | (uint256(uint96(reserve)) << 56);
            assembly ("memory-safe") {
                sstore(slot, packed)
            }
        } else {
            uint256 slot1 = slot + 1;
            uint256 slot1val;
            assembly ("memory-safe") {
                slot1val := sload(slot1)
            }
            slot1val = (slot1val & ~uint256(type(uint128).max)) | uint256(reserve);
            assembly ("memory-safe") {
                sstore(slot1, slot1val)
            }
        }
    }

    /// @dev set the token circulating supply
    function _setTokenCirculatingSupply(address token, uint128 circulatingSupply) internal {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
        }
        uint256 packed;
        assembly ("memory-safe") {
            packed := sload(slot)
        }
        uint8 header = uint8(packed);
        if (header != PACKED_TOKEN_STATE_HEADER) {
            packed = (packed & ~(uint256(type(uint96).max) << 152)) | (uint256(uint96(circulatingSupply)) << 152);
            assembly ("memory-safe") {
                sstore(slot, packed)
            }
        } else {
            uint256 slot1 = slot + 1;
            uint256 slot1val;
            assembly ("memory-safe") {
                slot1val := sload(slot1)
            }
            slot1val = (slot1val & ~(uint256(type(uint128).max) << 128)) | (uint256(circulatingSupply) << 128);
            assembly ("memory-safe") {
                sstore(slot1, slot1val)
            }
        }
    }

    /// @dev set the token fee profile
    function _setTokenFeeProfile(address token, FlapFeeProfile feeProfile) internal {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
        }
        uint256 packed;
        assembly ("memory-safe") {
            packed := sload(slot)
        }
        uint8 header = uint8(packed);
        if (header != PACKED_TOKEN_STATE_HEADER) {
            // Legacy tokens don't have fee profile field, do nothing
            return;
        } else {
            // Update the feeProfile field at bit position 112 (8 bits)
            packed = (packed & ~(uint256(0xff) << 112)) | (uint256(uint8(feeProfile)) << 112);
            assembly ("memory-safe") {
                sstore(slot, packed)
            }
        }
    }

    /// @dev set the per-tx.origin cumulative buy cap (bps of maxSupply) at bit position 120 (16 bits)
    function _setTokenMaxBuyBps(address token, uint16 maxBuyBps) internal {
        if (token != address(uint160(uint256(uint160(token))))) revert DirtyBits();
        uint256 slot;
        assembly ("memory-safe") {
            mstore(0x0, token)
            mstore(0x20, _packedTokenStates.slot)
            slot := keccak256(0x0, 0x40)
        }
        uint256 packed;
        assembly ("memory-safe") {
            packed := sload(slot)
        }
        uint8 header = uint8(packed);
        // Legacy tokens don't have this field; only V2-packed state supports it.
        if (header != PACKED_TOKEN_STATE_HEADER) {
            return;
        }
        packed = (packed & ~(uint256(0xffff) << 120)) | (uint256(maxBuyBps) << 120);
        assembly ("memory-safe") {
            sstore(slot, packed)
        }
    }

    /// @dev Convert a per-origin cap in bps to an absolute token amount.
    ///      bps == 0 returns 0 (interpreted as "no limit" by callers).
    function _maxBuyAmountFromBps(uint16 bps) internal pure returns (uint256) {
        return (maxSupply * uint256(bps)) / 10_000;
    }

    /// @dev Resolve the effective per-origin cap (bps) for a token.
    ///      This is simply the token's own maxBuyBpsPerOrigin. 0 means unlimited.
    function _effectiveMaxBuyBps(PackedTokenStateV2 memory state) internal pure returns (uint16) {
        return state.maxBuyBpsPerOrigin;
    }

    /// @dev Absolute per-origin cap for a token; 0 means unlimited.
    function _effectiveMaxBuyAmount(PackedTokenStateV2 memory state) internal pure returns (uint256) {
        return _maxBuyAmountFromBps(_effectiveMaxBuyBps(state));
    }

    /// @dev Transient-storage slot flagging "the current buy is the dev's launch buy on creation".
    ///      When set, the per-origin buy cap is NOT enforced (the launch buy may exceed the cap
    ///      without being refunded), but the buy is STILL counted toward the origin's cumulative
    ///      buy total, so buyQuotaOf reflects the dev's real holdings. If the launch buy already
    ///      exceeds the cap, the dev cannot buy again (cumulative total never decreases on sell).
    ///      EIP-1153: auto-clears at tx end.
    ///      Value = uint256(keccak256("flap.transient.skipMaxBuyCap")) - 1
    ///      (inline assembly requires a literal; verified via `cast keccak`).
    uint256 private constant SKIP_MAX_BUY_CAP_SLOT = 0xedb7567bf3a8a696a10ac76ec79d84d268eab3906e543b6a77beb0eea8caf66b;

    /// @dev Set/clear the "skip max-buy cap" transient flag around a launch-time creation buy.
    function _setSkipMaxBuyCap(bool skip) internal {
        uint256 v = skip ? 1 : 0;
        assembly ("memory-safe") {
            tstore(SKIP_MAX_BUY_CAP_SLOT, v)
        }
    }

    /// @dev Read the "skip max-buy cap" transient flag.
    function _skipMaxBuyCap() internal view returns (bool skip) {
        assembly ("memory-safe") {
            skip := tload(SKIP_MAX_BUY_CAP_SLOT)
        }
    }

    /// @dev Returns the settlement singleton address for a V4-style migrator.
    ///      V4_UNI_MIGRATOR          → V4_SINGLETON     (UniV4 PoolManager)
    ///      PCS_INFINITY_CL_MIGRATOR → PCS_INFINITY_VAULT (PCS Infinity Vault)
    ///      Any other type           → address(0)
    function _resolveV4MainPool(MigratorType migratorType) internal view returns (address) {
        if (migratorType == MigratorType.V4_UNI_MIGRATOR) return V4_SINGLETON;
        if (migratorType == MigratorType.PCS_INFINITY_CL_MIGRATOR) return PCS_INFINITY_VAULT;
        return address(0);
    }

    /// @dev Returns the position manager address for a V4-style migrator.
    ///      V4_UNI_MIGRATOR           → V4_POSITION_MANAGER
    ///      PCS_INFINITY_CL_MIGRATOR  → PCS_INFINITY_CL_POSITION_MANAGER
    ///      Any other type            → address(0)
    function _resolveV4PositionManager(MigratorType migratorType) internal view returns (address) {
        if (migratorType == MigratorType.V4_UNI_MIGRATOR) return V4_POSITION_MANAGER;
        if (migratorType == MigratorType.PCS_INFINITY_CL_MIGRATOR) return PCS_INFINITY_CL_POSITION_MANAGER;
        return address(0);
    }

    /// @dev Returns the locker address for a V4-style migrator.
    ///      V4_UNI_MIGRATOR           → GOPLUS_UNI_V4_LOCKER
    ///      PCS_INFINITY_CL_MIGRATOR  → GOPLUS_PCS_INFINITY_LOCKER
    ///      Any other type            → address(0)
    function _resolveV4Locker(MigratorType migratorType) internal view returns (address) {
        if (migratorType == MigratorType.V4_UNI_MIGRATOR) return GOPLUS_UNI_V4_LOCKER;
        if (migratorType == MigratorType.PCS_INFINITY_CL_MIGRATOR) return GOPLUS_PCS_INFINITY_LOCKER;
        return address(0);
    }

    /// @dev Returns true when mainPool_ is one of the V4-style settlement singletons
    ///      (V4_SINGLETON or PCS_INFINITY_VAULT).  Used as a sentinel check in launcher
    ///      helpers to detect "this token uses a V4-style migrator".
    function _isV4StyleMainPool(address mainPool_) internal view returns (bool) {
        return mainPool_ == V4_SINGLETON || mainPool_ == PCS_INFINITY_VAULT;
    }
}
