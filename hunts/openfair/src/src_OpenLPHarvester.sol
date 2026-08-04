// SPDX-License-Identifier: MIT
// Launched via openfair.app - create your own token on Robinhood Chain: https://openfair.app
pragma solidity ^0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Minimal Uniswap V3 NonfungiblePositionManager interface – declared
 * locally with only the needed functions, to avoid pulling in the whole
 * periphery package (and dodge compiler version conflicts).
 */
interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Collects the position's accrued fees. Does NOT touch liquidity.
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Position data: token0/token1 are needed to validate the pair.
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

/// @dev Minimal WETH9 interface: unwrap only.
interface IWETH9 is IERC20 {
    function withdraw(uint256 amount) external;
}

/// @dev Minimal interface of the project token: burn only (from ERC20Burnable).
interface IBurnableToken {
    function burn(uint256 amount) external;
}

/**
 * @title OpenLPHarvester
 * @notice A vault contract for a Uniswap V3 LP position of the token/WETH pair.
 *
 * What it does:
 *  - Receives the LP position NFT from the NonfungiblePositionManager and locks
 *    it FOREVER.
 *  - Exposes a single state-changing function `harvest()`, callable by ANY
 *    address: it collects accrued trading fees, burns the token portion, and
 *    sends the ETH portion (WETH -> unwrap -> native ETH) to the immutable
 *    treasury wallet.
 *
 * Why liquidity can never be withdrawn (the contract's core property):
 *  - There are NO calls to decreaseLiquidity() or the position burn() – the only
 *    state-changing call to the PositionManager is collect(), which by Uniswap
 *    V3's design pays out only ACCRUED FEES and physically cannot reduce the
 *    position's liquidity.
 *  - There are NO transferFrom/safeTransferFrom/approve calls for the NFT – the
 *    position can never leave this contract under any circumstances.
 *  - There is NO owner/admin: no function is restricted by caller address, and
 *    there is no "crisis" function. No proxy, no delegatecall, no selfdestruct –
 *    the code's guarantees are permanent.
 *  - The only paths funds can move: token -> burn (destruction), ETH -> treasury
 *    (an immutable address set at deployment). No other path to withdraw
 *    anything from the contract's balance exists.
 */
contract OpenLPHarvester is IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice An NFT may only be accepted directly from the NonfungiblePositionManager.
    error NotPositionManager();
    /// @notice The position is already locked – a second NFT is not accepted.
    error PositionAlreadyLocked();
    /// @notice harvest() cannot be called until a position has been transferred to the contract.
    error NoPositionYet();
    /// @notice The received position must be the token/WETH pair.
    error WrongPair();
    /// @notice Sending ETH to the treasury failed.
    error EthTransferFailed();
    /// @notice Native ETH is accepted only from the WETH contract (during unwrap).
    error DirectEthNotAccepted();
    /// @notice The zero address is not allowed.
    error ZeroAddress();

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice The LP position has been received and locked forever.
    event PositionLocked(uint256 indexed tokenId);

    /// @notice Fees collected: ETH sent to the treasury, token portion burned.
    event Harvested(address indexed caller, uint256 ethAmount, uint256 tokenBurned, uint256 timestamp);
    event ReferralPaid(address indexed referrer, uint256 amount);

    // ---------------------------------------------------------------
    // Immutable parameters (set once at deployment)
    // ---------------------------------------------------------------

    /// @notice Uniswap V3 NonfungiblePositionManager of the target chain.
    INonfungiblePositionManager public immutable positionManager;

    /// @notice The project token (implements ERC20Burnable).
    address public immutable token;

    /// @notice WETH of the target chain.
    IWETH9 public immutable weth;

    /// @notice The project wallet: the ETH portion of fees goes here. Cannot be changed.
    address public immutable treasury;

    /// @notice Referrer of the launch (address(0) = none). Receives half of the
    /// platform's ETH cut of every harvest – the LP-fee analog of the curve's
    /// trade-fee referral split. Immutable, set by the factory at creation.
    address public immutable referrer;

    /// @notice openfair platform treasury – receives `platformShareBps` of the
    /// ETH portion (supporter economics). Zero share = 100% to the project.
    address public immutable platformTreasury;
    uint16 public immutable platformShareBps;

    // ---------------------------------------------------------------
    // Position state (set once when the NFT is received)
    // ---------------------------------------------------------------

    /// @notice true after the LP position is received; a second NFT cannot be accepted.
    bool public positionLocked;

    /// @notice tokenId of the locked LP position (set automatically in onERC721Received).
    uint256 public positionTokenId;

    /// @notice true if WETH is the pool's token0 (Uniswap V3 token order is
    /// determined by sorting addresses ascending; cached when the NFT is received).
    bool public wethIsToken0;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /**
     * @param positionManager_ NonfungiblePositionManager address on the target
     *        Chain (take it from the official Uniswap Deployments docs!).
     * @param token_ Address of the project token.
     * @param weth_ WETH address on Robinhood Chain.
     * @param treasury_ Project wallet for the ETH portion of fees. Must be able
     *        to receive native ETH (a plain EOA or a Safe multisig – both fine).
     */
    constructor(
        address positionManager_,
        address token_,
        address weth_,
        address treasury_,
        address platformTreasury_,
        uint16 platformShareBps_,
        address referrer_
    ) {
        if (positionManager_ == address(0) || token_ == address(0) || weth_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (platformShareBps_ > 10_000 || (platformShareBps_ > 0 && platformTreasury_ == address(0))) {
            revert ZeroAddress();
        }
        positionManager = INonfungiblePositionManager(positionManager_);
        token = token_;
        weth = IWETH9(weth_);
        treasury = treasury_;
        platformTreasury = platformTreasury_;
        platformShareBps = platformShareBps_;
        referrer = referrer_;
    }

    // ---------------------------------------------------------------
    // Receiving the LP position
    // ---------------------------------------------------------------

    /**
     * @notice Called by the NonfungiblePositionManager when the position NFT is
     * safeTransferFrom'd to this contract. The tokenId is captured automatically
     * – no separate setup function is needed, and the deployer has no role.
     *
     * Protection:
     *  - accept the NFT only directly from the PositionManager (msg.sender);
     *  - accept exactly one position over the contract's entire lifetime;
     *  - verify the position is the token/WETH pair (so the wrong NFT can't be
     *    locked in by accident).
     *
     * After this function runs the position is locked forever: the contract has
     * no function capable of transferring the NFT onward or reducing liquidity.
     */
    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external override returns (bytes4) {
        if (msg.sender != address(positionManager)) revert NotPositionManager();
        if (positionLocked) revert PositionAlreadyLocked();

        (,, address token0, address token1,,,,,,,,) = positionManager.positions(tokenId);
        bool wethFirst = (token0 == address(weth) && token1 == token);
        bool tokenFirst = (token0 == token && token1 == address(weth));
        if (!wethFirst && !tokenFirst) revert WrongPair();

        positionLocked = true;
        positionTokenId = tokenId;
        wethIsToken0 = wethFirst;

        emit PositionLocked(tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

    // ---------------------------------------------------------------
    // Fee collection – the contract's only state-changing function
    // ---------------------------------------------------------------

    /**
     * @notice Permissionless collection of accrued trading fees. Anyone can call.
     *
     * Steps:
     *  1. collect() on the PositionManager with maximal amount0Max/amount1Max –
     *     both fee portions arrive on this contract's balance. collect() touches
     *     ONLY accrued fees; the position's liquidity is not changed.
     *  2. The token portion is burned via burn() (the token inherits ERC20Burnable).
     *  3. The WETH portion is unwrapped to native ETH (weth.withdraw) and sent to
     *     the treasury via a low-level call (not transfer/send – so as not to hit
     *     the 2300-gas stipend if the treasury is a contract), with a success check.
     *
     * Safety:
     *  - nonReentrant: re-entry (e.g. from a malicious contract's receive() on the
     *    ETH path) is impossible;
     *  - the external ETH call is last, after all state changes
     *    (checks-effects-interactions);
     *  - with zero fees on one or both tokens the function completes without
     *    reverting (steps with zero amounts are skipped).
     */
    function harvest() external nonReentrant {
        if (!positionLocked) revert NoPositionYet();

        // 1. Collect everything accrued. The return values are the amounts of
        // both pool tokens actually transferred.
        (uint256 amount0, uint256 amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // token0/token1 order was fixed when the position was received.
        (uint256 wethAmount, uint256 tokenAmount) = wethIsToken0 ? (amount0, amount1) : (amount1, amount0);

        // 2. Burn the token portion. burn() reduces totalSupply – the tokens are
        // destroyed, not parked on a dead address.
        if (tokenAmount > 0) {
            IBurnableToken(token).burn(tokenAmount);
        }

        // 3. Unwrap WETH -> ETH; split between the platform (its immutable
        // share) and the project treasury. Last step – no state changes after.
        if (wethAmount > 0) {
            weth.withdraw(wethAmount);
            uint256 platformCut = wethAmount * platformShareBps / 10_000;
            uint256 creatorCut = wethAmount - platformCut;
            // Referral: half of the platform cut goes to the launch referrer
            // (the LP-fee analog of the curve's trade-fee split). Best-effort
            // send – a reverting referrer must never brick harvesting, so on
            // failure its share simply stays with the platform.
            if (referrer != address(0) && platformCut > 1) {
                uint256 referrerCut = platformCut / 2;
                (bool okR,) = referrer.call{value: referrerCut}("");
                if (okR) {
                    platformCut -= referrerCut;
                    emit ReferralPaid(referrer, referrerCut);
                }
            }
            if (platformCut > 0) {
                (bool okP,) = platformTreasury.call{value: platformCut}("");
                if (!okP) revert EthTransferFailed();
            }
            (bool ok,) = treasury.call{value: creatorCut}("");
            if (!ok) revert EthTransferFailed();
        }

        emit Harvested(msg.sender, wethAmount, tokenAmount, block.timestamp);
    }

    // ---------------------------------------------------------------
    // Receiving native ETH
    // ---------------------------------------------------------------

    /**
     * @notice Native ETH is accepted only from the WETH contract – it arrives at
     * the moment of weth.withdraw() inside harvest(). Any other ETH transfer is
     * rejected, so that no third-party funds can get stuck in the contract (there
     * is no path to withdraw arbitrary ETH here by design).
     */
    receive() external payable {
        if (msg.sender != address(weth)) revert DirectEthNotAccepted();
    }
}
