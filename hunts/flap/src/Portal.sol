// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {
    IPortal,
    IPortalCore,
    IPortalCommonTypes,
    IPortalTypes,
    IPortalMigrator,
    IPortalLauncher,
    IPortalLauncherTwoStep,
    IPortalLens,
    IPortalLensV2,
    IPortalTweak,
    IPortalTrade,
    IV4Locker,
    IRoller,
    IPortalTradeV2,
    IPortalDexRouter
} from "./interfaces/IPortal.sol";
import {IToken} from "./interfaces/IToken.sol";
import {PortalBase} from "./PortalBase.sol";
import {IUniswapV3MintCallback} from "uni-v3-core/interfaces/callback/IUniswapV3MintCallback.sol";
import {IPancakeV3MintCallback} from "pancake-v3-core/interfaces/callback/IPancakeV3MintCallback.sol";
import {IERC721Receiver} from "@openzeppelin/interfaces/IERC721Receiver.sol";
import {LibCurve} from "src/libraries/Curve.sol";

/// @title  The Portal is the entrypoint for the LaunchPad Protocol
/// @author The Flap Team
/// @dev The portal is mainly for dispatching calls to other modules.
contract Portal is IPortal, PortalBase {
    /// @dev Local-only auditor role check for setNewFeatureSwitch. Deliberately NOT declared in
    ///      PortalBase (would add a public getter + selector to every PortalBase-inheriting
    ///      contract, e.g. PortalLens/PortalLensV2/PortalPCSInfinityCLMigrator, which are already
    ///      close to the EIP-170 24576-byte runtime size limit). The canonical public constant
    ///      lives in PortalTweak, which is the only other place AUDITOR_ROLE is used.
    bytes32 internal constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    constructor(PortalInitParams memory params) PortalBase(params) {
        // Portal lens must not be zero address
        if (params._portalLens == address(0)) {
            revert PortalLensCannotBeZero();
        }
        if (params.portalLensV2_ == address(0)) {
            revert PortalLensV2CannotBeZero();
        }
    }

    function initialize(address admin) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // receive function to receive ether
    receive() external payable {}

    /// @notice Helper function to determine which implementation to use for swaps
    /// @param inputToken Input token address
    /// @param outputToken Output token address
    /// @return implementation Address of the implementation contract to use
    function _getSwapImplementation(address inputToken, address outputToken)
        internal
        view
        returns (address implementation)
    {
        // Determine if this is a buy or sell
        bool isBuy = _quoteTokenConfigurations[inputToken].enabled == 1;
        address baseToken = isBuy ? outputToken : inputToken;

        // Get token state to check status
        PackedTokenStateV2 memory state = _getTokenState(baseToken);

        if (state.status == TokenStatus.DEX) {
            // Token is listed on DEX, use PortalDexRouter
            return PORTAL_DEX_ROUTER;
        } else if (state.status == TokenStatus.Tradable) {
            // Token is still in bonding curve, use PortalTradeV2
            return PORTAL_TRADE_V2;
        } else {
            // Invalid or other status, will fail in implementation
            return PORTAL_TRADE_V2; // Let PortalTradeV2 handle the error
        }
    }

    /// @inheritdoc IPortalTrade
    function buy(
        address,
        /*token*/
        address,
        /*recipient*/
        uint256 /*minAmount*/
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256 /*amount*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IPortalTrade
    function sell(
        address,
        /*token*/
        uint256,
        /*amount*/
        uint256 /*minEth*/
    )
        external
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256 /*eth*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IPortalTrade
    function redeem(
        address,
        /*arg1*/
        address,
        /*arg2*/
        uint256 /*arg3*/
    )
        external
        pure
        override
        returns (
            uint256 /*amount*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IRoller
    function rollv2(
        bytes calldata /*packedParams*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_ROLLER);
    }

    /// @inheritdoc IRoller
    function claim(
        address /*token*/
    )
        external
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256, /*tokenAmount*/
            uint256 /*ethAmount*/
        )
    {
        _delegateToImpl(PORTAL_ROLLER);
    }

    /// @inheritdoc IRoller
    function delegateClaim(
        address /*token*/
    )
        external
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256, /*tokenAmount*/
            uint256 /*ethAmount*/
        )
    {
        _delegateToImpl(PORTAL_ROLLER);
    }

    /// @inheritdoc IPortalTradeV2
    function swapExactInput(ExactInputParams calldata params)
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256 /* outputAmount */
        )
    {
        address implementation = _getSwapImplementation(params.inputToken, params.outputToken);
        _delegateToImpl(implementation);
    }

    /// @inheritdoc IPortalTradeV2
    function swapExactInputV3(ExactInputV3Params calldata params)
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256 /* outputAmount */
        )
    {
        address implementation = _getSwapImplementation(params.inputToken, params.outputToken);
        _delegateToImpl(implementation);
    }

    /// @inheritdoc IPortalTradeV2
    function quoteExactInput(QuoteExactInputParams calldata params)
        external
        override
        returns (
            uint256 /* outputAmount */
        )
    {
        address implementation = _getSwapImplementation(params.inputToken, params.outputToken);
        _delegateToImpl(implementation);
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV2(
        NewTokenV2Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV3(
        NewTokenV3Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV4(
        NewTokenV4Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV5(
        NewTokenV5Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV6(
        NewTokenV6Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncher
    function lockSalt(
        bytes32,
        /* salt */
        TokenVersion /* tokenVersion */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
    {
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IPortalLauncherTwoStep
    function stageNewTokenV5(
        StageNewTokenV5Params calldata /* params */
    )
        external
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            address /* token */
        )
    {
        // TODO: open to public after SaleForge Launch
        if (msg.sender != SALE_FORGE) {
            revert OnlySaleForge();
        }
        _delegateToImpl(PORTAL_LAUNCHER_TWO_STEP);
    }

    /// @inheritdoc IPortalLauncherTwoStep
    function commitNewTokenV5(
        CommitNewTokenV5Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
    {
        // TODO: open to public after SaleForge Launch
        if (msg.sender != SALE_FORGE) {
            revert OnlySaleForge();
        }
        _delegateToImpl(PORTAL_LAUNCHER_TWO_STEP);
    }

    /// @inheritdoc IPortalTweak
    function registerExtension(
        bytes32,
        /* extensionId */
        address,
        /* extensionAddress */
        uint8 /* version */
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IRoller
    function setTokenBeneficiary(
        address,
        /*token*/
        address /* newBeneficiary */
    )
        external
        override
    {
        _delegateToImpl(PORTAL_ROLLER);
    }

    /// @inheritdoc IPortalTweak
    function setQuoteTokenConfiguration(
        address, /*quoteToken*/
        IPortalTypes.QuoteTokenConfiguration calldata /*config*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function setFeeExemption(
        address[] memory,
        /*traders*/
        bool /*isExempted*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function updateTaxTokenAddresses(
        TaxTokenAddressUpdate[] calldata /*updates*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function setFlapFeeProfile(
        address,
        /*token*/
        FlapFeeProfile /*feeProfile*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function setTokenMaxBuyBps(
        address,
        /*token*/
        uint16 /*bps*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function setSpammerBlockedBatch(
        address[] calldata,
        /*spammers*/
        bool /*blocked*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function excludeAddressFromDividends(
        address, /*taxToken*/
        address /*account*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function recoverStuckTaxToken(
        address /*taxToken*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function burnStuckTaxToken(
        address /*taxToken*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function changeMarketWallet(
        address,
        /*token*/
        address /*newMarketWallet*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function recoverStuckDividend(
        RecoverStuckDividendParams[] calldata /*params*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function setTokenDividendToken(
        address, /*taxToken*/
        address /*newDividendToken*/
    )
        external
        override
    {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function auditorRunIdempotent() external override {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortalTweak
    function getFeeRate() external view override returns (uint256 buyFeeRate, uint256 sellFeeRate) {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            // result is the return value of the inspect function.
            //
            // The inspect function returns a bytes, which will be encoded as the abi encoding of a bytes:
            // |uin256(0x20)|length of the return_bytes|return_bytes|
            // However, `return_bytes` itself is the abi encoding of the return value of the corresponding view function.
            //
            // The memory layout of the result is as follows:
            // |uint256(result length)|uin256(0x20)|length of the return_bytes|return_bytes|
            //
            // here, we return the "return_bytes".

            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalDexRouter
    function updateTokenPoolInfo(
        address,
        /*token*/
        PackedDexPool calldata /*poolInfo*/
    )
        external
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
    {
        _delegateToImpl(PORTAL_DEX_ROUTER);
    }

    /// @inheritdoc IPortal
    /// @dev Bit flag examples when only the global bit and V7 bit are in use:
    ///      - 0: fully halt all `onlyIfBitFlagsSet` entrypoints
    ///      - 1: keep global features enabled but pause only `newTokenV7`
    ///      - 3: keep global features enabled and allow `newTokenV7`
    ///      Additional feature bits may also be present; `haltNewTokenV7()` only clears the V7 bit.
    function setBitFlags(uint256 flags) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 old = bitFlags;
        bitFlags = flags;

        emit BitFlagsChanged(old, flags);
    }

    /// @inheritdoc IPortal
    function setNewFeatureSwitch(bool enabled) external override {
        if (hasRole(AUDITOR_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            _newFeatureSwitch = enabled;
        } else {
            revert("CannotSetNewFeatureSwitch");
        }
    }

    /// @inheritdoc IPortal
    function newFeatureSwitch() external view override returns (bool) {
        return _newFeatureSwitch;
    }

    /// @inheritdoc IPortalTweak
    function haltNewTokenV7() external override {
        _delegateToImpl(PORTAL_TWEAK);
    }

    /// @inheritdoc IPortal
    function halt() external override {
        // only guardian can halt the portal
        if (!(hasRole(GUARDIAN_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender))) {
            revert NotGuardian(msg.sender);
        }
        uint256 old = bitFlags;
        bitFlags = 0;
        emit BitFlagsChanged(old, 0);
    }

    /// @notice Check if an address is blocked from creating tokens
    /// @param spammer The address to check
    /// @return True if the address is blocked
    /// @dev This function returns the blocked status regardless of whether ENABLE_SPAMMER_BLOCKER is enabled.
    /// When the feature is disabled, addresses may still be marked as blocked in storage, but the
    /// blocking check in _newTokenV5 will not be performed.
    function isSpammerBlocked(address spammer) external view returns (bool) {
        return _blockedSpammers[spammer].blocked;
    }

    //
    // View functions
    /// @inheritdoc IPortal
    function nonce()
        external
        view
        override
        returns (
            uint256 /*nonce*/
        )
    {
        return _nonce;
    }

    /// @inheritdoc IPortalLens
    function getTokenV2(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV2 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            // result is the return value of the inspect function.
            //
            // The inspect function returns a bytes, which will be encoded as the abi encoding of a bytes:
            // |uin256(0x20)|length of the return_bytes|return_bytes|
            // However, `return_bytes` itself is the abi encoding of the return value of the corresponding view function.
            //
            // The memory layout of the result is as follows:
            // |uint256(result length)|uin256(0x20)|length of the return_bytes|return_bytes|
            //
            // here, we return the "return_bytes".

            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV3(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV3 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV4(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV4 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV5(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV5 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV6(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV6 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV7(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV7 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV8(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV8 memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getTokenV8Safe(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV8Safe memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLauncher
    function newTokenV7(
        NewTokenV7Params calldata /* params */
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH | CB_BIT_MASK_NEW_TOKEN_V7_SWITCH)
        returns (
            address /* token */
        )
    {
        // Dispatch via PORTAL_LAUNCHER (PortalTokenLauncher), which in turn delegates to
        // LAUNCHER_V7_IMPL via _delegateLaunchUniV4AndTaxProcessorV2.
        // This is consistent with the V2-V6 dispatch pattern (all token launches pass
        // through PORTAL_LAUNCHER for a uniform call chain).
        _delegateToImpl(PORTAL_LAUNCHER);
    }

    /// @inheritdoc IV4Locker
    function collectV4Fees(
        address /* token */
    )
        external
        override
    {
        _delegateToImpl(PORTAL_V4_CL_LOCKER);
    }

    /// @inheritdoc IV4Locker
    function addV4LPLiquidity(address, uint256, uint256) external override returns (uint256, uint256) {
        _delegateToImpl(PORTAL_V4_CL_LOCKER);
    }

    /// @inheritdoc IPortalLensV2
    function getTokenV9Safe(
        address /*token*/
    )
        external
        view
        override
        returns (
            TokenStateV9Safe memory /*state*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLens
    function getQuoteTokenConfiguration(
        address /*quoteToken*/
    )
        external
        view
        override
        returns (
            QuoteTokenConfiguration memory /*config*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLensV2
    function maxBuyPerOrigin(
        address /*token*/
    )
        external
        view
        override
        returns (
            uint16, /*bps*/
            uint256 /*maxBuyAmount*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLensV2
    function buyQuotaOf(
        address, /*token*/
        address /*origin*/
    )
        external
        view
        override
        returns (
            uint256, /*bought*/
            uint256 /*remaining*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLensV2
    function getSaltLock(
        bytes32 /*salt*/
    )
        external
        view
        override
        returns (
            SaltLockEntry memory /*entry*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLensV2
    function getLockedSaltsCountByUserAndVersion(
        address,
        /*user*/
        uint8 /*tokenVersion*/
    )
        external
        view
        override
        returns (
            uint256 /*count*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalLensV2
    function getLockedSaltsByUserAndVersion(
        address, /*user*/
        uint8, /*tokenVersion*/
        uint256, /*offset*/
        uint256 /*limit*/
    )
        external
        view
        override
        returns (
            bytes32[] memory, /*salts*/
            SaltLockEntry[] memory, /*entries*/
            uint256 /*total*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// @inheritdoc IPortalTrade
    function previewBuy(
        address,
        /*token*/
        uint256 /*eth*/
    )
        external
        view
        override
        returns (
            uint256 /*amount*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IPortalTrade
    function previewSell(
        address,
        /*token*/
        uint256 /*amount*/
    )
        external
        view
        override
        returns (
            uint256 /*eth*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IPortalTrade
    function previewRedeem(
        address,
        /*arg1*/
        address,
        /*arg2*/
        uint256 /*arg3*/
    )
        external
        pure
        override
        returns (
            uint256 /*amount*/
        )
    {
        revert FeatureDisabled();
    }

    /// @inheritdoc IRoller
    function getLocks(
        address /*token*/
    )
        external
        view
        override
        returns (
            uint256[] memory /*locks*/
        )
    {
        (bool success, bytes memory result) =
            address(this).staticcall(abi.encodeWithSelector(this.inspect.selector, msg.data));
        if (!success) {
            _revert(result);
        }
        assembly ("memory-safe") {
            // result is the return value of the inspect function.
            //
            // The inspect function returns a bytes, which will be encoded as the abi encoding of a bytes:
            // |uin256(0x20)|length of the return_bytes|return_bytes|
            // However, `return_bytes` itself is the abi encoding of the return value of the corresponding view function.
            //
            // The memory layout of the result is as follows:
            // |uint256(result length)|uin256(0x20)|length of the return_bytes|return_bytes|
            //
            // here, we return the "return_bytes".

            return(add(result, 0x60), mload(add(result, 0x40)))
        }
    }

    /// inspector for delegating the view calls
    /// @dev As we cannot delegatecall the view calls, we need to staticcall this function to forward the delegatecalls.
    /// emm, why not use the fallback function to handle the view calls?
    ///
    /// There are two reasons:
    /// - We want to include the view functions in our ABI, so they will be interactable on etherscan.
    /// - In the future, we may have some special dispatch logic for each function:
    ///    e.g: dispatch to different implementations based on the token's PackedState.
    function inspect(bytes memory data) external returns (bytes memory result) {
        bytes4 selector;
        assembly ("memory-safe") {
            selector := shl(224, shr(224, mload(add(data, 32)))) // Extract and clean the first 4 bytes (function selector)
        }

        address target;
        if (
            selector == this.getTokenV2.selector || selector == this.getTokenV3.selector
                || selector == this.getTokenV4.selector || selector == this.getTokenV5.selector
                || selector == this.getTokenV6.selector || selector == this.getTokenV7.selector
                || selector == this.getTokenV8.selector || selector == this.getTokenV8Safe.selector
                || selector == this.getQuoteTokenConfiguration.selector
        ) {
            target = PORTAL_LENS;
        } else if (
            selector == this.getSaltLock.selector || selector == this.getLockedSaltsCountByUserAndVersion.selector
                || selector == this.getLockedSaltsByUserAndVersion.selector || selector == this.getTokenV9Safe.selector
                || selector == this.maxBuyPerOrigin.selector || selector == this.buyQuotaOf.selector
        ) {
            target = PORTAL_LENS_V2;
        } else if (selector == this.getLocks.selector) {
            target = PORTAL_ROLLER;
        } else if (selector == this.getFeeRate.selector) {
            target = PORTAL_TWEAK;
        } else {
            revert FeatureDisabled();
        }

        (bool success, bytes memory response) = target.delegatecall(data);
        if (!success) {
            _revert(response);
        }
        return response;
    }

    /// @inheritdoc IPortal
    function version() external pure override returns (string memory) {
        return "v5.14.16";

        // v5.14.16 - feat: per-tx.origin cumulative buy cap on internal market (global switch + per-token bps, auto-refund on over-cap)
        // v5.14.15 - enhance: use latest antispam homoglyph table
        // v5.14.14 - feat: CURVE_RH_BNB_1X5_32BNB (1.5x price ratio, 32 BNB net graduation)
        // v5.14.12 - refactor: make ANTI_SCAM_MODULE an immutable in PortalBase (remove setter/getter)
        // v5.14.11 - feat: AntiScamModule v3 — transparent proxy, complete isolation, homoglyph normalization
        // v5.14.10 - feat: add token name/symbol blacklist to prevent scam impersonation (addBlacklistedWords, isBlacklistedWord)
        // v5.14.9 - fix: resolve the issue in PR#274
        // v5.14.8 - feat: add auditorRunIdempotent for one-time idempotent hotfixes by auditors
        // v5.14.7 - fix: prevent permanent dividend lock due to early state clear
        // v5.14.6 - feat: add auditor-only excludeAddressFromDividends with non-EOA and EIP-7702 address guards
        // v5.14.5 - fix: switch salt locking for non-tax launches from TOKEN_V2_PERMIT to TOKEN_V3_PERMIT and enforce it in newTokenV7
        // v5.14.4 -
        // v5.14.3 - feat: full Uniswap V4 & PancakeSwap Infinity CL support
        // v5.14.2 - fix: allow zero anti-farmer duration for launcher validations
        // v5.14.1 - fix: minor fixes for PortalTweak
        // v5.14.0 - feat: support any ERC-20 token as dividend token for tax tokens (full release with SwapRegistry, upgradeable TaxHelper, MEV-aware dispatch)
        // v5.13.2 - feat: add burnStuckTaxToken for admins to burn stuck V1 tax tokens to the dead address
        // v5.13.1 - fix: only call taxRate() for V1 and V2 tax tokens in PortalDexRouter
        // v5.13.0 - feat: light dividend release — always deploy Dividend tracker for V3 tax tokens; allow custom dividend token only when dividendBps == 0; enforce dividendToken == quoteToken when dividendBps > 0; balance-diff deposit accounting
        // v5.12.0 - feat: add TAX_GUARDIAN_ROLE and changeMarketWallet for V2/V3 tax tokens
        // v5.11.1 - fix: split salt-locking lens reads into PortalLensV2 to stay under deployment size limit
        // v5.11.0 - feat: on-chain enumerable salt index per token version (getLockedSaltsByUserAndVersion, getLockedSaltsCountByUserAndVersion)
        // v5.10.1 - fix: lockSalt() now reverts if the token has already been deployed
        // v5.10.0 - feat: sunset SaleForge createSale(), stub two-step launch, add lockSalt() to Portal
        // v5.9.3 - fix: prevent quote-token dust accumulation in TaxProcessor
        // v5.9.2 - feat: add recoverStuckTaxToken for auditors to recover stuck V1 tax tokens from tax splitter
        // v5.9.1 - feat: getTokenV2-V7 fallback TOKEN_TAXED_V3→TOKEN_TAXED_V2 for backward compat; add getTokenV8Safe with uint8 enum fields
        // v5.9.0 - feat: supports FlapTaxTokenV3
        // v5.8.9 - refactor: replace PancakeSwap Infinity BinPool hop with pure V3 multi-hop route for uUSD swaps (BNB↔USDT↔uUSD via V3 fee=100)
        // v5.8.8 - feat: support uUSD as a quote token via PancakeSwap Infinity multi-hop routing
        // v5.8.7 - fix: TaxProcessor buyback refund detection
        // v5.8.6 - chore: invalidate all legacy fee exemptions
        // v5.8.5 - feat: TaxProcessor: preBond burn & Liquidity For Tax tokens
        // v5.8.3 - feat: add RateLimitExceeded custom error
        // v5.8.2 - feat: apply rate limiting to all addresses
        // v5.8.1 - feat: rate limitter for token creation
        // v5.8.0 - feat: Enable Two-Step Token Launching via SaleForge
        // v5.7.6 - feat: add new curve for KGST token
        // v5.7.5 - fix: incorrect dex quote for tax tokens
        // v5.7.4 - fix: incorrect fee receiver address in tax processor
        // v5.7.3 - chore: newTokenV5 is now included in the standard version
        // v5.7.2 - fix: exclude portal from dividend eligibility
        // v5.7.1 - fix: support new Advanced Tax Token's Tax processor
        // v5.7.0 - fix minor issues from recent audit report;
        // v5.6.0 - add spammer blocker;
        // v5.5.0 - Does not allow price jump when fallback to V2 migrator
        // v5.4.3 - fix: broken events
        // v5.4.2 - only enable next features when the flag is set
        // v5.4.1 - minor refactoring for Two-Step Token Launching; disable non-80% dex threshold.
        // v5.4.0 - support tax on bonding curve for TAX_TOKEN and TAX_TOKEN_V2
        // v5.3.0 - Change the behavior of legacy curves (i.e h=0): cannot buy more than dexThreshold
        // v5.2.0 - merge minor changes from v4 branch
        // v5.1.3 - Add Monad Curve V2 (not activated)
        // v5.1.2 - add curve-dependent lower price ratio for Monad
        // v5.1.1 - profile based LIQUIDATION_EXPECTED_OUTPUT_AMOUNT_NATIVE
        // v5.1.0  - disable all new v5 features and it is effectively v4
        // v5.0.0  - remove legacy PortalTrade; Support Multiple Dexes through MultiDexRouter
        // v4.14.1 - remove legacy launcher related code
        // v4.14.0 - support Non 18 decimal quote tokens for Tax tokens
        // v4.13.2 - tweak: adjust default V3 lower tick
        // v4.13.1 - Add CURVE_RH_MONAD curve type (r = 50000, h = 107036752, k = 55351837600000)
        // v4.13.0 - Move getTokenV* to PortalLens, add getTokenV6
        // v4.12.2 - Update Tax Related Admin Tweaks
        // v4.12.1 - enhance: emit an event when the progress of a token changes; optimize v3 migrator precision
        // v4.12.0 - add fee exemption for traders and getFeeRate method
        // v4.11.1 - make tax token's duration configurable
        // v4.11.0 - add sendMsg method that emits MsgSent event
        // v4.10.1 - update xlayer profile to allow non-native gas quote token
        // v4.10.0 - Support IZumi Swap + GoPlus Izumi Locker
        // v4.9.3 - add new curve types: TOSHI/MORPH 2ETH, TOSHI, BGB, BNB, USD curves
        // v4.9.2 - add CURVE_500 (r = 500) curve type
        // v4.9.1 - enable legacy launcher for Morph
        // v4.9.0 - remove toshi locker support, improve lock type auto-detection in PortalRoller
        // v4.8.0 - split locker utilities from PortalUniV3Migrator to a separate module, add new goplus locker, gas optimizations for PortalUniV3Migrator
        // v4.7.2 - support deploying token without using minimum proxy
        // v4.7.1 - fix backward compatibility issue in getTokenV4 (now returns only r param), add getTokenV5 to return all curve parameters (r, h, k)
        // v4.7.0 - support Flap bonding Curve V2
        // v4.6.3 - fix price discrepancy on PortalUniV2Migrator when applying liquidity fee
        // v4.6.2 - add CURVE_21_25 (r = 21.25) curve type
        // v4.6.1 - fix: do not try to migrate legacy tokens
        // v4.6.0 - implement LIQUIDITY_FEE feature in PortalUniV2Migrator (similar to existing V3 implementation)
        // v4.5.2 - add CURVE_28 (r = 28) curve type; add X_LAYER profile with validation for quote token, migrator, and tax token restrictions
        // v4.5.1 - rev share: try to trigger the recipient's fallback method when the quote token is not the native gas
        // v4.5.0 - implement PortalDexRouter for DEX token swaps with smart dispatch, pool storage, and multi-protocol support
        // v4.4.2 - update chain-specific custom fees for TOSHI
        // v4.4.1 - enable revshare on TOSHI PROFILE
        // v4.4.0 - add configurable FALLBACK_UNIV3_FEE in PortalUniV3Migrator with validation
        // v4.3.0 - add quote-token-specific V3 favored fees with setV3FavoredFee method
        // v4.2.5 - add chain-specific locker behaviors for Base chain (WETH/TOSHI custom fees)
        // v4.2.4 - remove Toshi LP locker support from PortalUniV3Migrator
        // v4.2.3 - add optional liquidity fee (by default, this is 0)
        // v4.2.2 - add TOSHI_MART specific logic to the roller
        // v4.2.1 - fixed minor issues from the recent audit report
        // v4.2.0 - add profile feature for deployment-specific parameters and behaviors
        // v4.1.3 - _handleExtensionOnTokenCreation after the token is created
        // v4.1.2 - add getTokenV4
        // v4.1.1 - emit event when extension is enabled
        // v4.1.0 - add extension support with newTokenV3, swapExactInputV3, and registerExtension methods
        // v4.0.0 - remove legacy creation methods
        // v3.5.2 - asymmetric fees
        // v3.5.1 - tax dependent split ratio
        // v3.5.0 - enable rev share for tokens whose quote is not native token
        // v3.4.0 - support quote to native swap
        // v3.3.0 - support native to quote swap
        // v3.2.2 - change tax token suffix to 7777
        // v3.2.1 -  tax event
        // v3.2.0 -  Add support for Tax token
        // v3.1.0 -  New Packed Token State for new tokens
        // v3.0.0 -  Refactor the code to make Portal a pure dispatcher
        // v2.11.0 - remove unused codes, remove obsolete features
        // v2.10.0 - deprecate all rolls and support rev share for Vanity Tokens
        // v2.9.10 - add r=2 curve
        // v2.9.8 - support v2 only mode for monad testnet
        // v2.9.7 - deprecate the staking feature
        // v2.9.6 - change izumi default fee rate
        // v2.9.5 - support optional creation fee
        // v2.9.4 - support Izumi locker
        // v2.9.3 - support Izumi Swap
        // v2.9.2 - optional feature: save the number of token that each user has created
        // v2.9.1 - split camelot related implementations to a separate module
        // v2.9.0 - support camelot v3
        // v2.8.0 - add forceUniqueMeta
        // v2.7.3 - add checkedIn method
        // v2.7.2 - add new curve (20000) type
        // v2.7.1 - add more threshold types
        // v2.7.0 - support toshi's locker
        // v2.6.0 - supoort goplus locker
        // v2.5.4 - support customized dex threshold type
        // v2.5.3 - deprecate the burner contract
        // v2.5.2 - supports r=0.5 curve
        // v2.5.1 - split the roller into a separate module
        // v2.5.0 - enable staking feature
        // v2.4.0 - support multiple implementations of token
        // v2.3.1 - make default dex Thresh as a constructor parameter
        // v2.3.0 - using curve as an inline lib to save gas
        // v2.2.0 - v3 default fee tier is 2500
        // v2.1.1 - enable rolling
        // v2.1.0 - support multipe curves and dex thresholds
        // v2.0.1 - disable all game features
        // v2.0.0 - game v1 is discontinued
        // v1.0.0 - The Initial version of the Flap Portal Contract (with duel feature)
    }

    function buyOnCreation(
        address,
        /*token*/
        address,
        /*recipient*/
        uint256 /*inputAmount*/
    )
        external
        payable
        override
        onlyIfBitFlagsSet(CB_BIT_MASK_GLOBAL_SWITCH)
        returns (
            uint256 /*amount*/
        )
    {
        // this is an internal function, not intended to be called by external contracts
        revert FeatureDisabled();
    }

    /// @inheritdoc IPortal
    function sendMsg(address token, string memory message) external override {
        emit MsgSent(msg.sender, token, message);
    }

    /// @inheritdoc IPortal
    function enableTaxOnBondingCurve() public view override(IPortal) returns (bool enabled) {
        return ENABLE_TAX_ON_BONDING_CURVE;
    }
}
