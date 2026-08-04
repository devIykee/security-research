// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Token.sol";
import "./BondingCurve.sol";
import "./interfaces/ILpFeeCollector.sol";

/**
 * @title Factory
 * @notice One-call fair-launch launchpad for the Robinhood Chain.
 *
 * Usage:
 *   factory.createToken("My Meme", "MEME", "ipfs://Qm...")
 *   → deploys Token + BondingCurve, seeds the curve with the full token supply.
 *
 * Revenue:
 *   • Creation fee (msg.value ≥ createFee) collected on every token launch.
 *   • All 1 % protocol fees from BondingCurve trades arrive here as native ETH.
 *   The owner calls withdrawFees() to collect everything.
 *   • Post-graduation: if `lpFeeCollector` is set, each deployed BondingCurve is
 *     automatically onboarded as a minter, so its graduation LP NFT goes to the
 *     collector instead of 0xdead — Uniswap V3 swap fees keep flowing 50/50 to the
 *     creator and the protocol forever after. See LpFeeCollector.sol.
 */
contract Factory is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // ─── Immutables ───────────────────────────────────────────────────────────

    address public immutable positionManager;
    address public immutable weth;
    /// address(0) preserves the legacy behaviour (graduation LP NFT burned to 0xdead).
    address public immutable lpFeeCollector;

    // ─── State ────────────────────────────────────────────────────────────────

    /// All deployed bonding curves
    address[] public allCurves;

    /// token address → bonding curve address
    mapping(address => address) public getCurve;

    /// Accumulated protocol fees (ETH) waiting to be withdrawn
    uint256 public pendingFees;

    /// Fee required to call createToken() — adjustable by owner (default 0.002 ETH)
    uint256 public createFee = 0.002 ether;

    // ─── Events ───────────────────────────────────────────────────────────────

    event TokenCreated(
        address indexed creator,
        address indexed token,
        address indexed curve,
        string  name,
        string  symbol,
        string  metadataURI,
        uint256 index
    );
    event FeesWithdrawn(address indexed to, uint256 amount);
    event CreateFeeUpdated(uint256 oldFee, uint256 newFee);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _positionManager Uniswap V3 NonfungiblePositionManager address
     * @param _weth            WETH9 address on this chain
     * @param _lpFeeCollector  Shared LpFeeCollector address, or address(0) to keep the
     *                         legacy "burn LP NFT to 0xdead" behaviour on graduation.
     *                         This Factory must be allow-listed via
     *                         `LpFeeCollector.setFactory(address(this), true)` for the
     *                         onboarding call in createToken() to succeed.
     */
    constructor(address _positionManager, address _weth, address _lpFeeCollector) Ownable(msg.sender) {
        require(_positionManager != address(0), "Factory: zero positionManager");
        require(_weth            != address(0), "Factory: zero weth");
        positionManager = _positionManager;
        weth            = _weth;
        lpFeeCollector  = _lpFeeCollector;
    }

    // ─── Owner controls ──────────────────────────────────────────────────────

    /**
     * @notice Update the creation fee. Set to 0 to make launches free.
     * @param newFee New fee in wei (e.g. 0.002 ether)
     */
    function setCreateFee(uint256 newFee) external onlyOwner {
        emit CreateFeeUpdated(createFee, newFee);
        createFee = newFee;
    }

    // ─── Launch ───────────────────────────────────────────────────────────────

    /**
     * @notice Deploy a new fair-launch token and its bonding curve.
     * @dev msg.value must be >= createFee.
     *      Any ETH above createFee is used as an instant initial buy for the creator.
     *      Bought tokens are forwarded to msg.sender in the same transaction.
     * @param name        ERC20 name
     * @param symbol      ERC20 symbol (ticker)
     * @param metadataURI IPFS or HTTPS URI for logo/description JSON
     * @return tokenAddr  Address of the deployed Token
     * @return curveAddr  Address of the deployed BondingCurve
     */
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata metadataURI
    ) external payable returns (address tokenAddr, address curveAddr) {
        require(msg.value >= createFee, "Factory: insufficient creation fee");
        // Only the fixed creation fee enters the fee pool; the rest goes to the initial buy
        pendingFees += createFee;
        uint256 initialBuyEth = msg.value - createFee;

        // 1. Deploy Token — mints 1 B tokens to this Factory
        Token  t = new Token(name, symbol, metadataURI);
        tokenAddr = address(t);

        // 2. Deploy BondingCurve (factory = msg.sender of the curve constructor)
        BondingCurve curve = new BondingCurve(
            tokenAddr,
            msg.sender,      // creator
            positionManager,
            weth,
            lpFeeCollector
        );
        curveAddr = address(curve);

        // Onboard the new curve as a minter so it can register its own graduation
        // position later on — atomic with deployment, no per-token owner action needed.
        if (lpFeeCollector != address(0)) {
            ILpFeeCollector(lpFeeCollector).onboardMinter(curveAddr);
        }

        // 3. Transfer entire supply to the BondingCurve
        IERC20(tokenAddr).safeTransfer(curveAddr, t.MAX_SUPPLY());

        // 4. Register
        getCurve[tokenAddr] = curveAddr;
        allCurves.push(curveAddr);

        emit TokenCreated(
            msg.sender,
            tokenAddr,
            curveAddr,
            name,
            symbol,
            metadataURI,
            allCurves.length - 1
        );

        // 5. Optional initial buy — excess ETH buys tokens for the creator instantly
        if (initialBuyEth > 0) {
            curve.buy{value: initialBuyEth}(0);
            // curve.buy sends tokens to address(this); forward them to the creator
            uint256 received = IERC20(tokenAddr).balanceOf(address(this));
            if (received > 0) {
                IERC20(tokenAddr).safeTransfer(msg.sender, received);
            }
        }
    }

    // ─── Fee management ───────────────────────────────────────────────────────

    /**
     * @notice Withdraw all accumulated protocol fees to `to`.
     * @param to Recipient address
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Factory: zero recipient");
        uint256 amount = pendingFees;
        require(amount > 0, "Factory: no fees");
        pendingFees = 0;
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Factory: ETH transfer failed");
        emit FeesWithdrawn(to, amount);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function totalTokens() external view returns (uint256) {
        return allCurves.length;
    }

    // ─── Receive ETH fees from BondingCurves ─────────────────────────────────

    receive() external payable {
        pendingFees += msg.value;
    }
}
