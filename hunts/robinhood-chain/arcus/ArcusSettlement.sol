// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IArcusExecutor} from "./interfaces/IArcusExecutor.sol";
import {IPermit2} from "./interfaces/IPermit2.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {WrappedTokenEscrow} from "./wrapped/WrappedTokenEscrow.sol";
import {WrappedTokenFactory} from "./wrapped/WrappedTokenFactory.sol";

/**
 * @title ArcusSettlement
 * @notice Executes a taker-signed `TakerIntent` through an Arcus-built route of
 *         allowlisted executors. The transaction is broadcast by a whitelisted
 *         Arcus operator.
 *
 * @dev v1 design (see ArcusSettlementSpec.md):
 *      - The taker order is signed as a Permit2 witness. There is no settlement-
 *        native EIP-712 domain and no settlement-owned replay state.
 *      - Settlement never emits arbitrary calldata. Every liquidity source is
 *        driven through the pinned IArcusExecutor.execute interface.
 *      - Accounting is by balance delta, never executor-reported amounts.
 *      - No standing allowances (Permit2 signature transfer).
 *      - Partial fills are supported: the taker signs a max `sellAmount` and a
 *        `minBuyAmount` floor, and a route may spend less than `sellAmount`
 *        (unspent sell token is refunded) so long as the measured output still
 *        clears the floor.
 *      - Native ETH exists only at the taker edges: `executeNativeInput` wraps
 *        msg.value into the configured WETH before the pipeline runs and
 *        `executeUnwrapNative` unwraps the measured output at delivery. Hops
 *        remain ERC20-only throughout.
 */
contract ArcusSettlement is OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── Types ────────────────────────────────────────────────────────────────

    /// @notice The economic terms the taker signs as a Permit2 witness.
    struct TakerIntent {
        address taker;
        address takerSellToken;
        address takerBuyToken;
        uint256 sellAmount;
        uint256 minBuyAmount;
        bool allowWrapped; // taker opts in to settling in the wrapped representation of takerBuyToken
        uint256 nonce; // Permit2 nonce
        uint256 deadline; // Permit2 deadline
    }

    /// @notice A single route hop driven through the pinned executor interface.
    /// @dev    `inputAmount == 0` means drain settlement's full balance of `inputToken`
    ///         (pipe/merge mode).
    ///
    ///         Constraints:
    ///         - takerSellToken: Drain is forbidden.
    ///         - non-takerSellToken: Drain is required.
    ///
    ///         Hops must follow batch-then-pipe order: continue a homogeneous
    ///         split batch (same input+output as previous) or consume the previous output.
    struct ExecutorHop {
        address executor;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 minOutputAmount;
        bytes executorData;
    }

    // ── Constants ──────────────────────────────────────────────────────────────

    /// @notice Canonical Permit2 (Uniswap) singleton — same address on every chain.
    IPermit2 public constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    bytes32 public constant TAKER_INTENT_TYPEHASH = keccak256(
        "TakerIntent(address taker,address takerSellToken,address takerBuyToken,uint256 sellAmount,uint256 minBuyAmount,bool allowWrapped,uint256 nonce,uint256 deadline)"
    );

    /// @notice Permit2 witness type string for the taker `TakerIntent` witness.
    ///         `TokenPermissions` is appended last per EIP-712 alphabetical ordering.
    string public constant TAKER_INTENT_WITNESS_TYPE_STRING =
        "TakerIntent witness)TakerIntent(address taker,address takerSellToken,address takerBuyToken,uint256 sellAmount,uint256 minBuyAmount,bool allowWrapped,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)";

    // ── Storage ──────────────────────────────────────────────────────────────

    /// @notice Whitelisted operators allowed to call `execute`.
    mapping(address => bool) public approvedOperators;

    /// @notice Allowlisted executors Settlement may drive through IArcusExecutor.
    mapping(address => bool) public approvedExecutors;

    /// @notice Canonical wrapped-token factory used to resolve the wrapped
    ///         representation of a taker's buy token when `allowWrapped` is set.
    ///         Security-critical: this address defines what counts as "wrapped".
    ///         `setWrappedTokenFactory` cross-checks the factory/escrow wiring.
    WrappedTokenFactory public wrappedTokenFactory;

    // Reserved storage slots for future upgrades; consume from the end by
    // reducing the array length. Ownable/UUPS/ReentrancyGuard use namespaced
    // storage and do not occupy sequential slots.
    // Was uint256[47]; the tail slot was consumed by `weth` (declared below the
    // gap so it occupies the exact slot the removed gap entry used to).
    uint256[46] private _gap;

    /// @notice Canonical wrapped-native (WETH9) token used by the native-ETH
    ///         entrypoints (`executeNativeInput` / `executeUnwrapNative`).
    ///         Security-critical: this address defines what "native ETH" means
    ///         to settlement — it is the only contract allowed to send ETH here
    ///         and the only bridge between msg.value and the ERC20 hop pipeline.
    IWETH public weth;

    /// @notice Trusted SwapShell that relays native-ETH BUYS: it wraps the taker's
    ///         ETH to WETH, approves this contract for `sellAmount`, and calls
    ///         `executeNativeInput`, which pulls that WETH. Only this address may
    ///         call `executeNativeInput` — the shell has already verified
    ///         `msg.sender == taker`, so it stands in for the taker's authorization.
    /// @dev    Appended after `weth` (which sits after `_gap`), so it takes a fresh
    ///         trailing slot; the gap stays [46] and no existing slot moves.
    address public nativeInputShell;

    // ── Events ───────────────────────────────────────────────────────────────

    event TakerIntentExecuted(
        address indexed taker,
        address indexed submitter,
        address takerSellToken,
        address takerBuyToken,
        uint256 sellAmount,
        uint256 buyAmount,
        bool wrappedToken
    );
    event OperatorApproval(address indexed operator, bool allowed);
    event ExecutorApproval(address indexed executor, bool allowed);
    event WrappedTokenFactorySet(address indexed factory);
    event WethSet(address indexed weth);
    event NativeInputShellSet(address indexed shell);
    event ExecutorBalanceClaimed(
        address indexed executor,
        address indexed strandedToken,
        address indexed recipient,
        address outputToken,
        uint256 strandedAmount,
        uint256 claimed
    );
    event TokensSwept(address indexed token, address indexed recipient, uint256 amount);

    // ── Errors ───────────────────────────────────────────────────────────────

    error OperatorNotApproved(address operator);
    error ExecutorNotApproved(address executor);
    error InvalidExecutor(address executor);
    error InvalidWrappedTokenFactory(address factory);
    error WrappedTokenFactoryNotSet();
    error OrderExpired();
    error InvalidTaker();
    error InvalidToken();
    error InvalidSellAmount();
    error InvalidMinBuyAmount();
    error SameToken();
    error InvalidRouteShape();
    error InsufficientHopOutput(uint256 received, uint256 minRequired);
    error InsufficientOutput(uint256 received, uint256 minRequired);
    error InvalidWeth(address weth);
    error WethNotSet();
    error CallerNotShell();
    error NativeInputShellNotSet();
    error SellTokenNotWeth();
    error BuyTokenNotWeth();
    error WrappedOutputNotAllowed();
    error NativeSendFailed();
    error EthNotFromWeth();
    error NothingToClaim();

    // ── Initialization ─────────────────────────────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ── Admin ────────────────────────────────────────────────────────────────

    /// @notice Grant or revoke an operator allowed to call `execute`.
    function setOperator(address operator, bool allowed) external onlyOwner {
        approvedOperators[operator] = allowed;
        emit OperatorApproval(operator, allowed);
    }

    /// @notice Grant or revoke an executor allowed to be driven by settlement.
    function setExecutor(address executor, bool allowed) external onlyOwner {
        if (allowed && (executor == address(0) || executor.code.length == 0)) revert InvalidExecutor(executor);
        approvedExecutors[executor] = allowed;
        emit ExecutorApproval(executor, allowed);
    }

    /// @notice Set the canonical wrapped-token factory used to resolve the wrapped
    ///         representation of a taker's buy token for `allowWrapped` intents.
    /// @dev    Reverts unless the factory/escrow/settlement wiring is consistent.
    ///         `WrappedTokenRfqExecutor.initialize` enforces the executor side.
    function setWrappedTokenFactory(address factory) external onlyOwner {
        if (factory == address(0) || factory.code.length == 0) revert InvalidWrappedTokenFactory(factory);
        WrappedTokenFactory wrappedFactory = WrappedTokenFactory(factory);
        // Wrapped tokens only honor `transfer` from their delivery authority, so
        // settlement must be that authority or delivery to the taker reverts.
        if (wrappedFactory.deliveryAuthority() != address(this)) revert InvalidWrappedTokenFactory(factory);
        // The authorized escrow is the sole minter of the factory's tokens; it must
        // mint via this same factory and pay out to this settlement.
        WrappedTokenEscrow escrow = WrappedTokenEscrow(wrappedFactory.authorizedEscrow());
        if (
            address(escrow) == address(0) || address(escrow.factory()) != factory
                || escrow.settlement() != address(this)
        ) revert InvalidWrappedTokenFactory(factory);
        wrappedTokenFactory = wrappedFactory;
        emit WrappedTokenFactorySet(factory);
    }

    /// @notice Set the canonical wrapped-native (WETH9) token used by the
    ///         native-ETH entrypoints. Until set, `executeNativeInput` and
    ///         `executeUnwrapNative` revert with `WethNotSet`.
    /// @dev    Rejects zero/codeless addresses. No deeper wiring check is
    ///         possible (WETH9 exposes no self-identifying view), so the owner
    ///         action itself is the trust anchor — same model as `setExecutor`.
    function setWeth(address weth_) external onlyOwner {
        if (weth_ == address(0) || weth_.code.length == 0) revert InvalidWeth(weth_);
        weth = IWETH(weth_);
        emit WethSet(weth_);
    }

    /// @notice Set the trusted SwapShell allowed to relay native-ETH buys via
    ///         `executeNativeInput`. Same owner-action-is-the-trust-anchor model
    ///         as `setWeth`/`setExecutor`.
    function setNativeInputShell(address shell) external onlyOwner {
        if (shell == address(0) || shell.code.length == 0) revert InvalidExecutor(shell);
        nativeInputShell = shell;
        emit NativeInputShellSet(shell);
    }

    /// @notice Claim stranded input tokens from an executor's balance
    /// @param executor The approved executor holding stranded tokens.
    /// @param strandedToken The token stranded in the executor.
    /// @param outputToken The token to route to (should be from a deep/liquid pool).
    /// @param minOutputAmount Slippage floor. Must be non-zero, and re-checked here
    ///        against the measured balance delta rather than trusting the executor.
    /// @param executorData Encoded protocol/fee, abi.encode(uint8 protocol, uint24 fee).
    /// @param recipient Where to send the claimed output; `address(0)` means `owner()`.
    /// @return claimed The amount of output tokens received and forwarded.
    function claimExecutorBalance(
        address executor,
        address strandedToken,
        address outputToken,
        uint256 minOutputAmount,
        bytes calldata executorData,
        address recipient
    ) external onlyOwner nonReentrant returns (uint256 claimed) {
        if (!approvedExecutors[executor]) revert ExecutorNotApproved(executor);
        if (strandedToken == address(0) || outputToken == address(0)) revert InvalidToken();
        if (strandedToken == outputToken) revert SameToken();
        if (minOutputAmount == 0) revert InvalidMinBuyAmount();

        address to = recipient == address(0) ? owner() : recipient;

        uint256 strandedBalance = IERC20(strandedToken).balanceOf(executor);
        if (strandedBalance == 0) revert NothingToClaim();

        uint256 outputBefore = IERC20(outputToken).balanceOf(address(this));

        // Call the executor with the full stranded balance
        IArcusExecutor(executor).execute(
            address(this), strandedToken, strandedBalance, outputToken, minOutputAmount, executorData
        );

        // Measure output by balance delta and re-enforce the floor independently
        // of what the executor reported, matching the accounting in `execute`.
        claimed = IERC20(outputToken).balanceOf(address(this)) - outputBefore;
        if (claimed < minOutputAmount) revert InsufficientOutput(claimed, minOutputAmount);

        IERC20(outputToken).safeTransfer(to, claimed);

        emit ExecutorBalanceClaimed(executor, strandedToken, to, outputToken, strandedBalance, claimed);
    }

    /// @notice Sweep tokens sitting on Settlement itself to a recipient.
    /// @param token The token to sweep.
    /// @param amount Amount to sweep; `0` means the full balance.
    /// @param recipient Where to send it; `address(0)` means `owner()` (the multisig).
    /// @return swept The amount transferred.
    function sweepTokens(address token, uint256 amount, address recipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 swept)
    {
        if (token == address(0)) revert InvalidToken();

        address to = recipient == address(0) ? owner() : recipient;

        uint256 balance = IERC20(token).balanceOf(address(this));
        swept = amount == 0 ? balance : amount;
        if (swept == 0 || swept > balance) revert NothingToClaim();

        IERC20(token).safeTransfer(to, swept);

        emit TokensSwept(token, to, swept);
    }

    // ── Settlement ───────────────────────────────────────────────────────────

    /**
     * @notice Execute a taker intent through an Arcus-built route.
     * @param intent The taker's signed economic terms (the taker Permit2 witness).
     * @param takerPermit2Sig The taker's Permit2 `permitWitnessTransferFrom` signature.
     * @param hops One-or-more executor hops. Each hop spends its declared
     *        `inputAmount` from settlement inventory, or — when `inputAmount == 0` —
     *        drains the full settlement balance of `inputToken` (pipe/merge). Sell-
     *        token spends must be declared and sum to at most `intent.sellAmount`.
     * @return boughtAmount The total settled buy token received, by balance delta.
     *         The settled token is `takerBuyToken`, or possibly the wrapped
     *         representation when the taker signed `allowWrapped == true`.
     */
    function execute(TakerIntent calldata intent, bytes calldata takerPermit2Sig, ExecutorHop[] calldata hops)
        external
        nonReentrant
        returns (uint256 boughtAmount)
    {
        if (!approvedOperators[msg.sender]) revert OperatorNotApproved(msg.sender);
        return _settleRoute(intent, takerPermit2Sig, hops, false, false);
    }

    /**
     * @notice Execute a taker intent funded with native ETH. The taker can't hand
     *         msg.value to a relayer, so they broadcast `SwapShell.swapNativeInput`
     *         themselves; that shell verifies `msg.sender == taker`, wraps the ETH
     *         into the configured WETH, approves this contract for `sellAmount`,
     *         and relays here. This runs the exact same hop pipeline as `execute`;
     *         any unspent sell-side WETH is refunded to the taker UNWRAPPED, as
     *         native ETH.
     * @param intent The taker's economic terms. Not signed and not pulled via
     *        Permit2: the funds arrive as the shell's pre-approved WETH, gated on
     *        the taker's own `swapNativeInput` broadcast, so that broadcast IS the
     *        authorization. Both `intent.nonce` and `intent.deadline` are unused
     *        here — the value is attached to the taker's own call, so there is
     *        neither a replay surface nor a stale-signature surface, and the TTL
     *        check is skipped for this path. `intent.takerSellToken` must be the
     *        configured WETH.
     * @param hops One-or-more executor hops, exactly as in `execute`.
     * @return boughtAmount The settled buy token received, by balance delta.
     *
     * @dev Gated on `msg.sender == nativeInputShell` (the trusted SwapShell), NOT
     *      operator-gated: the shell has already verified `msg.sender == taker`, so
     *      it stands in for the taker's authorization. Safe for the same reason
     *      `execute` is: every protection is route-structural, not submitter-based —
     *      the per-hop executor allowlist still gates which contracts can be driven,
     *      RFQ maker quotes bind `quote.taker` (a hostile third party cannot consume
     *      someone else's quote), and all accounting is by settlement balance delta
     *      with the taker's own `minBuyAmount` as the floor. The worst outcome of a
     *      malformed route is the taker losing their own msg.value to slippage they
     *      themselves accepted.
     */
    function executeNativeInput(TakerIntent calldata intent, ExecutorHop[] calldata hops)
        external
        nonReentrant
        returns (uint256 boughtAmount)
    {
        if (address(weth) == address(0)) revert WethNotSet();
        if (nativeInputShell == address(0)) revert NativeInputShellNotSet();
        if (msg.sender != nativeInputShell) revert CallerNotShell();
        if (intent.takerSellToken != address(weth)) revert SellTokenNotWeth();
        // The shell wrapped the taker's ETH to WETH and approved this contract for
        // `sellAmount`; _settleRoute pulls it via transferFrom. No Permit2 pull, so
        // the signature slot is irrelevant; pass an empty calldata slice.
        return _settleRoute(intent, msg.data[0:0], hops, true, false);
    }

    /**
     * @notice Execute a taker intent whose signed buy token is WETH, delivering
     *         the measured output as native ETH instead. Identical to `execute`
     *         (operator-gated, Permit2 pull, same pipeline) except delivery:
     *         `weth.withdraw(boughtAmount)` then a native send to the taker.
     * @dev    Requires `intent.takerBuyToken == weth` and `!intent.allowWrapped`.
     *         Delivery form is value-equivalent to the signed WETH, so it is
     *         operator-controlled and NOT part of the signed intent — the
     *         `TakerIntent` typehash is unchanged. The ERC20 taker-delta
     *         re-check is skipped for native delivery: ETH has no
     *         fee-on-transfer, so the measured `boughtAmount` is exactly what
     *         the taker receives (the send reverts atomically on failure).
     */
    function executeUnwrapNative(
        TakerIntent calldata intent,
        bytes calldata takerPermit2Sig,
        ExecutorHop[] calldata hops
    ) external nonReentrant returns (uint256 boughtAmount) {
        if (!approvedOperators[msg.sender]) revert OperatorNotApproved(msg.sender);
        if (address(weth) == address(0)) revert WethNotSet();
        if (intent.takerBuyToken != address(weth)) revert BuyTokenNotWeth();
        if (intent.allowWrapped) revert WrappedOutputNotAllowed();
        return _settleRoute(intent, takerPermit2Sig, hops, false, true);
    }

    /// @notice Accept ETH only from the configured WETH contract. Settlement
    ///         receives ETH exclusively as `weth.withdraw` proceeds during
    ///         native delivery/refund; every other sender is a mistake (stray
    ///         funds would be stuck) and is rejected.
    receive() external payable {
        if (msg.sender != address(weth)) revert EthNotFromWeth();
    }

    // ── Internal: shared settlement pipeline ───────────────────────────────────

    /**
     * @dev The single settlement pipeline behind `execute`,
     *      `executeNativeInput`, and `executeUnwrapNative`. Callers perform
     *      their own authorization (operator gate / msg.sender ==
     *      nativeInputShell) and native-shape checks before delegating here.
     *
     *      `nativeInput` funds the route by pulling pre-wrapped WETH from the
     *      shell via transferFrom (the shell already wrapped the taker's
     *      msg.value and approved this contract); the sell-side snapshot is taken
     *      BEFORE that pull, so any unspent WETH counts as sell-side leftover and
     *      is refunded to the taker UNWRAPPED. `nativeOutput` delivers the
     *      measured buy-side output unwrapped. With both flags false this is
     *      byte-for-byte the historical `execute` behavior.
     */
    function _settleRoute(
        TakerIntent calldata intent,
        bytes calldata takerPermit2Sig,
        ExecutorHop[] calldata hops,
        bool nativeInput,
        bool nativeOutput
    ) internal returns (uint256 boughtAmount) {
        _validateIntent(intent, nativeInput);
        _validateRouteShape(intent, hops);

        // The settled output token is the validated final hop output: either the
        // signed buy token, or (for allowWrapped intents) its wrapped representation.
        address settledToken = hops[hops.length - 1].outputToken;
        bool wrappedToken = settledToken != intent.takerBuyToken;

        IERC20 sellToken = IERC20(intent.takerSellToken);
        uint256 buyBefore = _outputBalanceOfMaybeUndeployed(settledToken, address(this));
        uint256 sellBefore = sellToken.balanceOf(address(this));

        if (nativeInput) {
            // The nativeInputShell wrapped the taker's ETH to WETH and approved this
            // contract for `sellAmount`; pull it (the snapshot above excludes it).
            // No Permit2 pull and no signature — the shell verified msg.sender ==
            // taker before relaying, so it stands in for the taker's authorization.
            sellToken.safeTransferFrom(nativeInputShell, address(this), intent.sellAmount);
        } else {
            _pullTaker(intent, takerPermit2Sig);
        }

        _executeHops(intent, hops);

        // ── Final output accounting (balance delta, not route-reported) ──────
        boughtAmount = _outputBalanceOfMaybeUndeployed(settledToken, address(this)) - buyBefore;
        if (boughtAmount < intent.minBuyAmount) revert InsufficientOutput(boughtAmount, intent.minBuyAmount);

        if (nativeOutput) {
            // Deliver unwrapped. Native ETH has no fee-on-transfer, so the
            // ERC20 taker-delta re-check is unnecessary; a failing send reverts.
            weth.withdraw(boughtAmount);
            _sendNative(intent.taker, boughtAmount);
        } else {
            // Send all measured output to the taker while enforcing the signed floor.
            IERC20 buyToken = IERC20(settledToken);
            uint256 takerBefore = buyToken.balanceOf(intent.taker);
            buyToken.safeTransfer(intent.taker, boughtAmount);
            uint256 takerDelta = buyToken.balanceOf(intent.taker) - takerBefore;
            if (takerDelta < intent.minBuyAmount) revert InsufficientOutput(takerDelta, intent.minBuyAmount);
        }

        // ── Refund unspent takerSellToken to the payer (the taker) ───────────
        uint256 sellLeftover = sellToken.balanceOf(address(this)) - sellBefore;
        if (sellLeftover != 0) {
            if (nativeInput) {
                // The taker paid native ETH, so leftovers go back unwrapped.
                weth.withdraw(sellLeftover);
                _sendNative(intent.taker, sellLeftover);
            } else {
                sellToken.safeTransfer(intent.taker, sellLeftover);
            }
        }

        emit TakerIntentExecuted(
            intent.taker,
            msg.sender,
            intent.takerSellToken,
            intent.takerBuyToken,
            intent.sellAmount,
            boughtAmount,
            wrappedToken
        );
    }

    /// @dev Send native ETH, reverting the whole settlement on failure so no
    ///      value can be silently stranded. Reentrancy through the recipient is
    ///      blocked by the entrypoints' shared `nonReentrant` guard.
    function _sendNative(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert NativeSendFailed();
    }

    // ── Internal: validation ───────────────────────────────────────────────────

    /// @dev The TTL exists to bound how long a *signed* intent stays valid — it
    ///      guards the Permit2 pull and stops a maker/relayer from holding a stale
    ///      signed message. The `nativeInput` path carries no signature — it is
    ///      gated on the taker's own `swapNativeInput` broadcast (relayed by the
    ///      shell), which is the authorization — so there is no stale-signature
    ///      surface to guard: the deadline is skipped there.
    ///      Signed paths (`execute`/`executeUnwrapNative`) still enforce it, in
    ///      lockstep with the Permit2 deadline that bounds the signature.
    function _validateIntent(TakerIntent calldata intent, bool nativeInput) internal view {
        if (!nativeInput && block.timestamp > intent.deadline) revert OrderExpired();
        if (intent.taker == address(0)) revert InvalidTaker();
        if (intent.takerSellToken == address(0) || intent.takerBuyToken == address(0)) revert InvalidToken();
        if (intent.takerSellToken == intent.takerBuyToken) revert SameToken();
        if (intent.sellAmount == 0) revert InvalidSellAmount();
        if (intent.minBuyAmount == 0) revert InvalidMinBuyAmount();
    }

    function _validateRouteShape(TakerIntent calldata intent, ExecutorHop[] calldata hops) internal view {
        uint256 len = hops.length;
        if (len == 0) revert InvalidRouteShape();

        // Settled token is the final hop output: signed buy token, or — when the
        // taker opts into wrapped settlement — its wrapped representation.
        address settledToken = hops[len - 1].outputToken;
        address wrappedBuy;
        if (intent.allowWrapped) {
            WrappedTokenFactory factory = wrappedTokenFactory;
            if (address(factory) == address(0)) revert WrappedTokenFactoryNotSet();
            wrappedBuy = factory.predictWrappedToken(intent.takerBuyToken);
            if (settledToken != intent.takerBuyToken && settledToken != wrappedBuy) revert InvalidRouteShape();
        } else if (settledToken != intent.takerBuyToken) {
            revert InvalidRouteShape();
        }

        uint256 sellSpent;
        for (uint256 i; i < len; ++i) {
            ExecutorHop calldata hop = hops[i];
            if (hop.executor == address(0) || hop.inputToken == address(0) || hop.outputToken == address(0)) {
                revert InvalidRouteShape();
            }
            if (!approvedExecutors[hop.executor]) revert ExecutorNotApproved(hop.executor);

            // Buy-family outputs (native buy or its wrapped form) must be the same as
            // the settled token — mixing B and W(B) strands one asset off accounting.
            if (hop.outputToken == intent.takerBuyToken || (wrappedBuy != address(0) && hop.outputToken == wrappedBuy))
            {
                if (hop.outputToken != settledToken) revert InvalidRouteShape();
            }

            // Batch-then-pipe grammar: a hop either continues a homogeneous split
            // batch (same input + same output as the previous hop) or pipes the
            // previous hop's output. This blocks stranded intermediates like
            // A→X, A→B and non-local jumps like A→X, Y→B.
            if (i != 0) {
                ExecutorHop calldata prev = hops[i - 1];
                if (hop.inputToken == prev.inputToken) {
                    if (hop.outputToken != prev.outputToken) revert InvalidRouteShape();
                } else if (hop.inputToken != prev.outputToken) {
                    revert InvalidRouteShape();
                }
            }

            if (hop.inputAmount == 0) {
                // Drain/pipe: only for non-sell tokens so sell spend stays countable.
                if (hop.inputToken == intent.takerSellToken) revert InvalidRouteShape();
            } else if (hop.inputToken == intent.takerSellToken) {
                sellSpent += hop.inputAmount;
            } else {
                // Exact intermediate spends can leave mid dust; require drain.
                revert InvalidRouteShape();
            }
        }
        if (sellSpent == 0 || sellSpent > intent.sellAmount) revert InvalidRouteShape();
    }

    // ── Internal: Permit2 pulls ────────────────────────────────────────────────

    function _pullTaker(TakerIntent calldata intent, bytes calldata signature) internal {
        PERMIT2.permitWitnessTransferFrom(
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({token: intent.takerSellToken, amount: intent.sellAmount}),
                nonce: intent.nonce,
                deadline: intent.deadline
            }),
            IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: intent.sellAmount}),
            intent.taker,
            _hashTakerIntent(intent),
            TAKER_INTENT_WITNESS_TYPE_STRING,
            signature
        );
    }

    function _executeHops(TakerIntent calldata intent, ExecutorHop[] calldata hops) internal {
        uint256 len = hops.length;
        for (uint256 i; i < len; ++i) {
            ExecutorHop calldata hop = hops[i];

            // Declared spend from inventory, or drain full balance for pipe/merge.
            uint256 amount = hop.inputAmount == 0 ? IERC20(hop.inputToken).balanceOf(address(this)) : hop.inputAmount;
            if (amount == 0) revert InvalidRouteShape();

            IERC20(hop.inputToken).safeTransfer(hop.executor, amount);

            uint256 outputBefore = _outputBalanceOfMaybeUndeployed(hop.outputToken, address(this));

            IArcusExecutor(hop.executor)
                .execute(intent.taker, hop.inputToken, amount, hop.outputToken, hop.minOutputAmount, hop.executorData);

            uint256 received = _outputBalanceOfMaybeUndeployed(hop.outputToken, address(this)) - outputBefore;
            if (received < hop.minOutputAmount) revert InsufficientHopOutput(received, hop.minOutputAmount);
        }
    }

    // @notice this is a helper function to get the balance of a token, it will return 0 if the token is not deployed.
    function _outputBalanceOfMaybeUndeployed(address token, address account) internal view returns (uint256) {
        if (token.code.length == 0) return 0;
        return IERC20(token).balanceOf(account);
    }

    // ── Witness hashing (domainless struct hashes; Permit2 wraps the domain) ───

    /// @notice The `TakerIntent` witness struct hash an off-chain taker commits to.
    function hashTakerIntent(TakerIntent calldata intent) external pure returns (bytes32) {
        return _hashTakerIntent(intent);
    }

    function _hashTakerIntent(TakerIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TAKER_INTENT_TYPEHASH,
                intent.taker,
                intent.takerSellToken,
                intent.takerBuyToken,
                intent.sellAmount,
                intent.minBuyAmount,
                intent.allowWrapped,
                intent.nonce,
                intent.deadline
            )
        );
    }
}
