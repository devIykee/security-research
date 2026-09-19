// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IPrimaryMarketConfig} from "../interfaces/IPrimaryMarketConfig.sol";
import {IUSDx} from "../interfaces/IUSDx.sol";
import {IUSDxMarket} from "../interfaces/IUSDxMarket.sol";

/// @notice Primary mint/redeem settlement contract for signed USDx market orders.
/// @dev Order validation, nonce use, cap checks, and asset movement are sequenced so failed settlements do not consume nonces or capacity.
contract USDxMarket is Initializable, IUSDxMarket, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant override MINT_OPERATOR_ROLE = keccak256("MINT_OPERATOR_ROLE");
    bytes32 public constant override REDEEM_OPERATOR_ROLE = keccak256("REDEEM_OPERATOR_ROLE");
    bytes32 public constant override SETTLEMENT_MANAGER_ROLE = keccak256("SETTLEMENT_MANAGER_ROLE");

    bytes32 public constant override ORDER_TYPEHASH = keccak256(
        "Order(bytes32 accountId,bytes32 routeId,bytes32 channelId,address signer,uint8 side,address inputAsset,address outputAsset,uint256 inputAmount,uint256 minOutputAmount,address receiver,uint256 deadline,uint256 nonce,bytes32 termsHash)"
    );

    bytes32 internal constant CHECK_OK = "OK";
    bytes32 internal constant CHECK_INVALID_ORDER = "INVALID_ORDER";
    bytes32 internal constant CHECK_INVALID_SIGNATURE = "INVALID_SIGNATURE";
    bytes32 internal constant CHECK_SIGNATURE_EXPIRED = "SIGNATURE_EXPIRED";
    bytes32 internal constant CHECK_INVALID_NONCE = "INVALID_NONCE";
    bytes32 internal constant CHECK_NONCE_USED = "NONCE_USED";
    bytes32 internal constant CHECK_ORDER_SETTLED = "ORDER_SETTLED";
    bytes32 internal constant CHECK_ORDER_CANCELLED = "ORDER_CANCELLED";
    bytes32 internal constant CHECK_NOT_WHITELISTED = "NOT_WHITELISTED";
    bytes32 internal constant CHECK_MINT_DISABLED = "MINT_DISABLED";
    bytes32 internal constant CHECK_REDEEM_DISABLED = "REDEEM_DISABLED";
    bytes32 internal constant CHECK_USDX_PAUSED = "USDX_PAUSED";
    bytes32 internal constant CHECK_SIGNER_RESTRICTED = "SIGNER_RESTRICTED";
    bytes32 internal constant CHECK_RECEIVER_RESTRICTED = "RECEIVER_RESTRICTED";
    bytes32 internal constant CHECK_MINT_CAP_EXCEEDED = "MINT_CAP_EXCEEDED";
    bytes32 internal constant CHECK_REDEEM_CAP_EXCEEDED = "REDEEM_CAP_EXCEEDED";
    bytes32 internal constant CHECK_ROUTE_DISABLED = "ROUTE_DISABLED";
    bytes32 internal constant CHECK_SIDE_MISMATCH = "SIDE_MISMATCH";
    bytes32 internal constant CHECK_INPUT_ASSET_UNSUPPORTED = "INPUT_ASSET_UNSUPPORTED";
    bytes32 internal constant CHECK_OUTPUT_ASSET_UNSUPPORTED = "OUTPUT_ASSET_UNSUPPORTED";
    bytes32 internal constant CHECK_INPUT_AMOUNT_TOO_SMALL = "INPUT_AMOUNT_TOO_SMALL";
    bytes32 internal constant CHECK_OUTPUT_AMOUNT_TOO_SMALL = "OUTPUT_AMOUNT_TOO_SMALL";
    bytes32 internal constant CHECK_CHANNEL_DISABLED = "CHANNEL_DISABLED";
    bytes32 internal constant CHECK_CHANNEL_ROUTE_MISMATCH = "CHANNEL_ROUTE_MISMATCH";
    bytes32 internal constant CHECK_CUSTODIAN_NOT_APPROVED = "CUSTODIAN_NOT_APPROVED";
    bytes32 internal constant CHECK_RECEIVER_NOT_ALLOWED = "RECEIVER_NOT_ALLOWED";
    bytes32 internal constant CHECK_GLOBAL_CAP_EXCEEDED = "GLOBAL_CAP_EXCEEDED";
    bytes32 internal constant CHECK_ASSET_CAP_EXCEEDED = "ASSET_CAP_EXCEEDED";
    bytes32 internal constant CHECK_ROUTE_CAP_EXCEEDED = "ROUTE_CAP_EXCEEDED";
    bytes32 internal constant CHECK_ACCOUNT_CAP_EXCEEDED = "ACCOUNT_CAP_EXCEEDED";
    bytes32 internal constant CHECK_CHANNEL_CAP_EXCEEDED = "CHANNEL_CAP_EXCEEDED";
    bytes32 internal constant CHECK_CAPACITY_UNAVAILABLE = "CAPACITY_UNAVAILABLE";
    bytes32 internal constant CHECK_ACCOUNT_MISMATCH = "ACCOUNT_MISMATCH";

    IUSDx public usdx;
    IPrimaryMarketConfig public marketConfig;

    mapping(bytes32 => OrderRecord) private _orders;
    mapping(bytes32 => mapping(uint256 => uint256)) private _nonceBitmaps;
    mapping(address => mapping(address => SignerStatus)) private _delegatedSigners;

    struct OrderRecord {
        bool settled;
        bool cancelled;
        bytes32 proofId;
    }

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant EIP712_NAME_HASH = keccak256("USDxMarket");
    bytes32 internal constant EIP712_VERSION_HASH = keccak256("1");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the market with token, policy registry, and governance admin.
    function initialize(IUSDx usdx_, IPrimaryMarketConfig marketConfig_, address admin) external initializer {
        if (address(usdx_) == address(0)) revert InvalidUSDxAddress();
        if (address(marketConfig_) == address(0) || admin == address(0)) revert InvalidAddress();

        usdx = usdx_;
        marketConfig = marketConfig_;

        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, EIP712_NAME_HASH, EIP712_VERSION_HASH, block.chainid, address(this))
        );
    }

    function eip712Domain()
        external
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        extensions = new uint256[](0);
        return (0x0f, "USDxMarket", "1", block.chainid, address(this), bytes32(0), extensions);
    }

    function hashOrder(Order calldata order) public view override returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), _structHash(order)));
    }

    function orderState(bytes32 orderHash)
        external
        view
        override
        returns (bool settled, bool cancelled, bytes32 proofId)
    {
        OrderRecord memory record = _orders[orderHash];
        return (record.settled, record.cancelled, record.proofId);
    }

    /// @notice Returns the EIP-712 order hash if the order and signature are currently valid.
    function verifyOrder(Order calldata order, Signature calldata signature) public view override returns (bytes32) {
        bytes32 orderHash = hashOrder(order);
        bytes32 code = _checkOrder(order, signature, orderHash);
        if (code == CHECK_OK) return orderHash;
        _revertForReason(code, order.side);
    }

    /// @notice Checks that a nonce is non-zero and unused in the account namespace.
    function verifyNonce(bytes32 accountId, uint256 nonce) public view override returns (uint256, uint256, uint256) {
        if (nonce == 0) revert InvalidNonce();
        (uint256 slot, uint256 bit) = _nonceBitmapSlot(nonce);
        uint256 bitmap = _nonceBitmaps[accountId][slot];
        if (bitmap & bit != 0) revert InvalidNonce();
        return (slot, bitmap, bit);
    }

    function route(bytes32 routeId) external view override returns (RouteState memory) {
        return marketConfig.route(routeId);
    }

    function channel(bytes32 channelId) external view override returns (ChannelState memory) {
        return marketConfig.channel(channelId);
    }

    function isRouteEnabled(bytes32 routeId) external view override returns (bool) {
        return marketConfig.isRouteEnabled(routeId);
    }

    function isChannelEnabled(bytes32 channelId) external view override returns (bool) {
        return marketConfig.isChannelEnabled(channelId);
    }

    function isSupportedAsset(address asset) external view override returns (bool) {
        return marketConfig.isSupportedAsset(asset);
    }

    function getMintingState() external view override returns (MintingState memory) {
        BlockCapacity memory capacity = marketConfig.getCurrentBlockCapacity();
        return MintingState({
            usdx: address(usdx),
            chainId: block.chainid,
            domainSeparator: DOMAIN_SEPARATOR(),
            maxMintPerBlock: marketConfig.maxMintPerBlock(),
            maxRedeemPerBlock: marketConfig.maxRedeemPerBlock(),
            mintedThisBlock: capacity.mintUsed,
            redeemedThisBlock: capacity.redeemUsed,
            mintEnabled: marketConfig.mintEnabled(),
            redeemEnabled: marketConfig.redeemEnabled()
        });
    }

    function getCurrentBlockCapacity() external view override returns (BlockCapacity memory) {
        return marketConfig.getCurrentBlockCapacity();
    }

    function getUserLimit(address account) external view override returns (UserLimit memory) {
        return marketConfig.getUserLimit(account);
    }

    function getUserBlockCapacity(address account) external view override returns (UserBlockCapacity memory) {
        return marketConfig.getUserBlockCapacity(account);
    }

    function getSupportedAssets() external view override returns (address[] memory) {
        return marketConfig.getSupportedAssets();
    }

    function getCustodians() external view override returns (address[] memory) {
        return marketConfig.getCustodians();
    }

    function isCustodian(address account) external view override returns (bool) {
        return marketConfig.isCustodian(account);
    }

    function isWhitelisted(address account) external view override returns (bool) {
        return marketConfig.isWhitelisted(account);
    }

    function signerAccount(address signer) external view override returns (bytes32) {
        return marketConfig.signerAccount(signer);
    }

    function delegatedSigner(address signer, address source) external view override returns (SignerStatus) {
        return _delegatedSigners[signer][source];
    }

    function isNonceUsed(bytes32 accountId, uint256 nonce) public view override returns (bool) {
        if (nonce == 0) return false;
        (uint256 slot, uint256 bit) = _nonceBitmapSlot(nonce);
        return _nonceBitmaps[accountId][slot] & bit != 0;
    }

    function checkChannel(ChannelCheck calldata channelCheck) public view override returns (ChannelDecision memory) {
        return marketConfig.checkChannel(channelCheck);
    }

    function cap(CapKey calldata key) external view override returns (CapConfig memory) {
        return marketConfig.cap(key);
    }

    function capUsage(CapKey calldata key) external view override returns (CapUsage memory) {
        return marketConfig.capUsage(key);
    }

    function checkCapacity(CapacityRequest calldata request) public view override returns (CapacityCheck memory) {
        return marketConfig.checkCapacity(request);
    }

    function maxCapacity(CapacityRequest calldata request) external view override returns (uint256) {
        return marketConfig.maxCapacity(request);
    }

    /// @notice Performs a non-mutating settlement precheck and returns the first blocking reason code.
    function checkSettlement(Order calldata order, Signature calldata signature, bytes calldata)
        public
        view
        override
        returns (SettlementCheck memory)
    {
        bytes32 orderHash = hashOrder(order);
        bytes32 code = _checkSettlement(order, signature, orderHash);
        CapacityRequest memory request = _capacityRequest(order);
        CapacityCheck memory capacity = marketConfig.checkCapacity(request);

        return SettlementCheck({
            allowed: code == CHECK_OK,
            reasonCode: code,
            orderHash: orderHash,
            routeId: order.routeId,
            channelId: order.channelId,
            availableNotionalAmount: capacity.effectiveAvailable,
            requiredNotionalAmount: capacity.requiredAmount
        });
    }

    /// @notice Settles a valid mint or redeem order and emits the reconstructable settlement proof.
    /// @dev Nonce marking happens before external token movement; any later revert rolls all state back.
    function settle(Order calldata order, Signature calldata signature, bytes calldata settlementData)
        public
        override
        returns (bytes32 proofId)
    {
        bytes32 orderHash = hashOrder(order);
        bytes32 code = _checkSettlement(order, signature, orderHash);
        if (code != CHECK_OK) _revertForReason(code, order.side);

        if (order.side == OrderSide.MINT) {
            if (!hasRole(MINT_OPERATOR_ROLE, msg.sender)) {
                revert AccessControlUnauthorizedAccount(msg.sender, MINT_OPERATOR_ROLE);
            }
        } else {
            if (!hasRole(REDEEM_OPERATOR_ROLE, msg.sender)) {
                revert AccessControlUnauthorizedAccount(msg.sender, REDEEM_OPERATOR_ROLE);
            }
        }

        _markNonceUsed(order.accountId, order.nonce);

        ChannelState memory channelState = marketConfig.channel(order.channelId);
        uint256 outputAmount = _outputAmount(order);
        proofId = _recordSettlementProof(
            order, orderHash, keccak256(abi.encode(orderHash, settlementData, channelState.channelHash)), channelState
        );

        marketConfig.consumeCapacity(_capacityRequest(order));
        marketConfig.consumeBlockCapacity(order.side, _requiredAmount(order));
        _executeMovement(order, channelState.destination, outputAmount);
    }

    function proofOfOrder(bytes32 orderHash) external view override returns (bytes32 proofId) {
        return _orders[orderHash].proofId;
    }

    function checkMint(Order calldata order, Signature calldata signature)
        external
        view
        override
        returns (OrderCheck memory)
    {
        bytes32 orderHash = hashOrder(order);
        bytes32 code =
            order.side == OrderSide.MINT ? _checkSettlement(order, signature, orderHash) : CHECK_INVALID_ORDER;
        CapacityCheck memory capacity = marketConfig.checkCapacity(_capacityRequest(order));
        return OrderCheck({
            valid: code == CHECK_OK,
            code: code,
            orderHash: orderHash,
            signer: order.signer,
            nonceUsed: isNonceUsed(order.accountId, order.nonce),
            availableBlockCapacity: capacity.effectiveAvailable
        });
    }

    function checkRedeem(Order calldata order, Signature calldata signature)
        external
        view
        override
        returns (OrderCheck memory)
    {
        bytes32 orderHash = hashOrder(order);
        bytes32 code =
            order.side == OrderSide.REDEEM ? _checkSettlement(order, signature, orderHash) : CHECK_INVALID_ORDER;
        CapacityCheck memory capacity = marketConfig.checkCapacity(_capacityRequest(order));
        return OrderCheck({
            valid: code == CHECK_OK,
            code: code,
            orderHash: orderHash,
            signer: order.signer,
            nonceUsed: isNonceUsed(order.accountId, order.nonce),
            availableBlockCapacity: capacity.effectiveAvailable
        });
    }

    /// @notice Cancels an unsettled order so its hash cannot be settled later.
    function cancelOrder(Order calldata order) external override onlyRole(SETTLEMENT_MANAGER_ROLE) {
        bytes32 orderHash = hashOrder(order);
        OrderRecord storage record = _orders[orderHash];
        if (record.settled || record.cancelled) revert InvalidNonce();
        record.cancelled = true;
        emit OrderCancelled(orderHash, order.accountId);
    }

    /// @notice Starts delegated signer enrollment for the caller's source account.
    function setDelegatedSigner(address signer) external override {
        if (signer == address(0)) revert InvalidAddress();
        _delegatedSigners[signer][msg.sender] = SignerStatus.PENDING;
        emit DelegatedSignerInitiated(signer, msg.sender);
    }

    /// @notice Accepts a pending delegated signer relationship from `source`.
    function confirmDelegatedSigner(address source) external override {
        if (_delegatedSigners[msg.sender][source] != SignerStatus.PENDING) revert SignerNotInitiated();
        _delegatedSigners[msg.sender][source] = SignerStatus.ACCEPTED;
        emit DelegatedSignerAdded(msg.sender, source);
    }

    /// @notice Rejects or removes a delegated signer relationship for the caller's source account.
    function removeDelegatedSigner(address signer) external override {
        if (signer == address(0)) revert InvalidAddress();
        _delegatedSigners[signer][msg.sender] = SignerStatus.REJECTED;
        emit DelegatedSignerRemoved(signer, msg.sender);
    }

    /// @notice Settles a mint order through the shared settlement pipeline.
    function mint(Order calldata order, Signature calldata signature, bytes calldata settlementData) external override {
        if (order.side != OrderSide.MINT) revert InvalidOrder();
        settle(order, signature, settlementData);
    }

    /// @notice Settles a redeem order through the shared settlement pipeline.
    function redeem(Order calldata order, Signature calldata signature, bytes calldata settlementData)
        external
        override
    {
        if (order.side != OrderSide.REDEEM) revert InvalidOrder();
        settle(order, signature, settlementData);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IUSDxMarket).interfaceId || super.supportsInterface(interfaceId);
    }

    function _structHash(Order calldata order) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.accountId,
                order.routeId,
                order.channelId,
                order.signer,
                order.side,
                order.inputAsset,
                order.outputAsset,
                order.inputAmount,
                order.minOutputAmount,
                order.receiver,
                order.deadline,
                order.nonce,
                order.termsHash
            )
        );
    }

    /// @dev Performs the final token movements after validation, nonce marking, and proof recording.
    function _executeMovement(Order calldata order, address destination, uint256 outputAmount) private {
        if (order.side == OrderSide.MINT) {
            _transferFrom(order.inputAsset, order.signer, destination, order.inputAmount);
            usdx.mint(order.receiver, outputAmount);
            emit Mint(msg.sender, order.signer, order.receiver, order.inputAsset, order.inputAmount, outputAmount);
        } else {
            usdx.burnFrom(order.signer, order.inputAmount);
            _transfer(order.outputAsset, order.receiver, outputAmount);
            emit Redeem(msg.sender, order.signer, order.receiver, order.outputAsset, outputAmount, order.inputAmount);
        }
    }

    function _recordSettlementProof(
        Order calldata order,
        bytes32 orderHash,
        bytes32 settlementHash,
        ChannelState memory channelState
    ) private returns (bytes32 proofId) {
        proofId = keccak256(abi.encode(orderHash, address(this), block.chainid, block.number));
        // The order record is the load-bearing state: the `settled` flag is the
        // reentrancy/double-settle guard, and `proofId` backs `proofOfOrder()`.
        // The full receipt is emitted via `OrderSettled` and reconstructed off-chain;
        // it is no longer persisted in storage (see `PrimaryMarketProof`).
        _orders[orderHash] = OrderRecord({settled: true, cancelled: false, proofId: proofId});

        emit OrderSettled(
            proofId,
            orderHash,
            order.accountId,
            order.routeId,
            order.channelId,
            channelState.destination,
            channelState.channelHash,
            settlementHash
        );
    }

    /// @dev Chains order, whitelist, route/channel, block-limit, and capacity checks into one reason code.
    function _checkSettlement(Order calldata order, Signature calldata signature, bytes32 orderHash)
        private
        view
        returns (bytes32)
    {
        bytes32 orderCode = _checkOrder(order, signature, orderHash);
        if (orderCode != CHECK_OK) return orderCode;
        if (!marketConfig.isWhitelisted(order.signer)) return CHECK_NOT_WHITELISTED;
        if (marketConfig.signerAccount(order.signer) != order.accountId) return CHECK_ACCOUNT_MISMATCH;
        bytes32 tokenRestrictionCode = _checkTokenRestrictions(order.signer, order.receiver);
        if (tokenRestrictionCode != CHECK_OK) return tokenRestrictionCode;
        if (order.side == OrderSide.MINT && !marketConfig.mintEnabled()) return CHECK_MINT_DISABLED;
        if (order.side == OrderSide.REDEEM && !marketConfig.redeemEnabled()) return CHECK_REDEEM_DISABLED;

        ChannelDecision memory channelDecision = marketConfig.checkChannel(
            ChannelCheck({
                accountId: order.accountId,
                channelId: order.channelId,
                side: order.side,
                inputAsset: order.inputAsset,
                outputAsset: order.outputAsset,
                receiver: order.receiver,
                amount: _requiredAmount(order)
            })
        );
        if (!channelDecision.allowed) return channelDecision.reasonCode;
        if (channelDecision.routeId != order.routeId) return CHECK_CHANNEL_ROUTE_MISMATCH;

        bytes32 capacityCode = _checkBlockCapacity(order);
        if (capacityCode != CHECK_OK) return capacityCode;

        CapacityCheck memory capacity = marketConfig.checkCapacity(_capacityRequest(order));
        if (!capacity.allowed) return capacity.reasonCode;

        return CHECK_OK;
    }

    function _checkTokenRestrictions(address signer, address receiver) private view returns (bytes32) {
        if (usdx.paused()) return CHECK_USDX_PAUSED;
        if (usdx.isBlacklisted(signer)) return CHECK_SIGNER_RESTRICTED;
        if (usdx.isBlacklisted(receiver)) return CHECK_RECEIVER_RESTRICTED;
        return CHECK_OK;
    }

    /// @dev Validates order shape, status, nonce, and signer authorization before policy checks run.
    function _checkOrder(Order calldata order, Signature calldata signature, bytes32 orderHash)
        private
        view
        returns (bytes32)
    {
        if (
            order.signer == address(0) || order.receiver == address(0) || order.inputAsset == address(0)
                || order.outputAsset == address(0)
        ) {
            return CHECK_INVALID_ORDER;
        }
        if (order.accountId == bytes32(0) || order.routeId == bytes32(0) || order.channelId == bytes32(0)) {
            return CHECK_INVALID_ORDER;
        }
        if (order.inputAmount == 0 || order.minOutputAmount == 0 || order.nonce == 0) return CHECK_INVALID_ORDER;
        if (order.inputAmount > uint256(type(int256).max) || order.minOutputAmount > uint256(type(int256).max)) {
            return CHECK_INVALID_ORDER;
        }
        if (block.timestamp > order.deadline) return CHECK_SIGNATURE_EXPIRED;

        OrderRecord memory record = _orders[orderHash];
        if (record.settled) return CHECK_ORDER_SETTLED;
        if (record.cancelled) return CHECK_ORDER_CANCELLED;
        if (isNonceUsed(order.accountId, order.nonce)) return CHECK_NONCE_USED;
        if (signature.signatureType != SignatureType.EIP712) return CHECK_INVALID_SIGNATURE;

        if (!_isValidOrderSignature(order.signer, orderHash, signature.signatureBytes)) return CHECK_INVALID_SIGNATURE;

        return CHECK_OK;
    }

    /// @dev Accepts source signatures, accepted ECDSA delegates, or encoded smart-account delegate signatures.
    function _isValidOrderSignature(address source, bytes32 orderHash, bytes calldata signature)
        private
        view
        returns (bool)
    {
        if (SignatureChecker.isValidSignatureNow(source, orderHash, signature)) return true;

        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(orderHash, signature);
        if (error == ECDSA.RecoverError.NoError && _delegatedSigners[recovered][source] == SignerStatus.ACCEPTED) {
            return true;
        }

        (address delegate, bytes calldata innerSignature, bool decoded) = _decodeDelegatedSignature(signature);
        return decoded && _delegatedSigners[delegate][source] == SignerStatus.ACCEPTED
            && SignatureChecker.isValidSignatureNow(delegate, orderHash, innerSignature);
    }

    /// @dev Decodes the delegated-signature envelope without reverting on malformed calldata.
    function _decodeDelegatedSignature(bytes calldata signature)
        private
        pure
        returns (address delegate, bytes calldata innerSignature, bool ok)
    {
        if (signature.length < 96) return (address(0), signature[:0], false);

        uint256 delegateWord;
        uint256 offset;
        uint256 innerLength;
        assembly ("memory-safe") {
            delegateWord := calldataload(signature.offset)
            offset := calldataload(add(signature.offset, 0x20))
            innerLength := calldataload(add(signature.offset, 0x40))
        }

        if (delegateWord > type(uint160).max || offset != 64 || innerLength == 0) {
            return (address(0), signature[:0], false);
        }
        if (innerLength > signature.length - 96) return (address(0), signature[:0], false);

        uint256 paddedInnerLength = (innerLength + 31) & ~uint256(31);
        if (signature.length != 96 + paddedInnerLength) return (address(0), signature[:0], false);

        delegate = address(uint160(delegateWord));
        if (delegate == address(0)) return (address(0), signature[:0], false);

        return (delegate, signature[96:96 + innerLength], true);
    }

    /// @dev Applies same-block mint/redeem circuit breakers before durable cap consumption.
    function _checkBlockCapacity(Order calldata order) private view returns (bytes32) {
        uint256 amount = _requiredAmount(order);
        BlockCapacity memory capacity = marketConfig.getCurrentBlockCapacity();

        if (order.side == OrderSide.MINT) {
            if (amount > capacity.mintAvailable) return CHECK_MINT_CAP_EXCEEDED;
        } else {
            if (amount > capacity.redeemAvailable) return CHECK_REDEEM_CAP_EXCEEDED;
        }
        return CHECK_OK;
    }

    /// @dev Marks the nonce bit in the account-specific bitmap.
    function _markNonceUsed(bytes32 accountId, uint256 nonce) private {
        (uint256 slot, uint256 bitmap, uint256 bit) = verifyNonce(accountId, nonce);
        _nonceBitmaps[accountId][slot] = bitmap | bit;
    }

    function _transfer(address token, address to, uint256 amount) private {
        IERC20(token).safeTransfer(to, amount);
    }

    function _transferFrom(address token, address from, address to, uint256 amount) private {
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    /// @dev Maps machine-readable check codes to the public custom errors used by callers.
    function _revertForReason(bytes32 code, OrderSide side) private pure {
        if (code == CHECK_INVALID_SIGNATURE) revert InvalidSignature();
        if (code == CHECK_SIGNATURE_EXPIRED) revert SignatureExpired();
        if (
            code == CHECK_INVALID_NONCE || code == CHECK_NONCE_USED || code == CHECK_ORDER_SETTLED
                || code == CHECK_ORDER_CANCELLED
        ) revert InvalidNonce();
        if (
            code == CHECK_NOT_WHITELISTED || code == CHECK_RECEIVER_NOT_ALLOWED || code == CHECK_ACCOUNT_MISMATCH
                || code == CHECK_SIGNER_RESTRICTED || code == CHECK_RECEIVER_RESTRICTED
        ) revert NotWhitelisted();
        if (
            code == CHECK_ROUTE_DISABLED || code == CHECK_SIDE_MISMATCH || code == CHECK_INPUT_ASSET_UNSUPPORTED
                || code == CHECK_OUTPUT_ASSET_UNSUPPORTED || code == CHECK_INPUT_AMOUNT_TOO_SMALL
                || code == CHECK_OUTPUT_AMOUNT_TOO_SMALL
        ) revert InvalidRoute();
        if (
            code == CHECK_CHANNEL_DISABLED || code == CHECK_CHANNEL_ROUTE_MISMATCH
                || code == CHECK_CUSTODIAN_NOT_APPROVED
        ) revert InvalidChannel();
        if (
            code == CHECK_GLOBAL_CAP_EXCEEDED || code == CHECK_ASSET_CAP_EXCEEDED || code == CHECK_ROUTE_CAP_EXCEEDED
                || code == CHECK_ACCOUNT_CAP_EXCEEDED || code == CHECK_CHANNEL_CAP_EXCEEDED
        ) revert CapacityExceeded(code);
        if (code == CHECK_CAPACITY_UNAVAILABLE || code == CHECK_MINT_CAP_EXCEEDED || code == CHECK_REDEEM_CAP_EXCEEDED)
        {
            if (side == OrderSide.MINT) revert MaxMintPerBlockExceeded();
            revert MaxRedeemPerBlockExceeded();
        }
        revert InvalidOrder();
    }

    function _capacityRequest(Order calldata order) private pure returns (CapacityRequest memory) {
        return CapacityRequest({
            routeId: order.routeId,
            accountId: order.accountId,
            channelId: order.channelId,
            side: order.side,
            inputAsset: order.inputAsset,
            outputAsset: order.outputAsset,
            inputAmount: order.inputAmount,
            minOutputAmount: order.minOutputAmount
        });
    }

    function _requiredAmount(Order calldata order) private pure returns (uint256) {
        return order.side == OrderSide.MINT ? order.minOutputAmount : order.inputAmount;
    }

    function _outputAmount(Order calldata order) private pure returns (uint256) {
        return order.minOutputAmount;
    }

    function _nonceBitmapSlot(uint256 nonce) private pure returns (uint256 slot, uint256 bit) {
        slot = nonce >> 8;
        bit = uint256(1) << (nonce & 0xff);
    }

    uint256[45] private __gap;
}

