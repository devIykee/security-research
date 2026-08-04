// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {LaunchToken} from "./LaunchToken.sol";

/// @title PumpLaunchpad
/// @notice A pump.fun-style fair-launch memecoin launchpad. Anyone creates a
///         token (name/symbol/metadata) that instantly trades on a bonding
///         curve. After `CURVE_SUPPLY` tokens are sold the token GRADUATES: the
///         curve's virtual reserves are dropped and the remaining tokens plus
///         all raised ETH become a permanently-locked constant-product pool
///         (no admin can ever withdraw it — the liquidity is locked forever).
contract PumpLaunchpad is Ownable, ReentrancyGuard {
    // ---- token economics (18-decimal fixed point) ----
    uint256 public constant SUPPLY = 1_000_000_000 ether; // total, all minted to this contract
    uint256 public constant CURVE_SUPPLY = 800_000_000 ether; // sold on the curve before graduation
    // Remaining SUPPLY - CURVE_SUPPLY (200M) stays here and becomes the locked pool.

    // Virtual reserves shape the pre-graduation curve (constant product).
    uint256 public constant VIRT_ETH = 1 ether;
    uint256 public constant VIRT_TOKEN = 1_100_000_000 ether;

    uint256 public constant BPS = 10_000;
    uint96 public constant MAX_FEE_BPS = 1000;

    uint96 public feeBps; // 690 = 6.9% total trade fee
    uint96 public creatorFeeBps; // creator's cut of the trade, out of feeBps (e.g. 100 = 1%)
    address public feeRecipient;

    // Anti-whale: the most a single wallet may HOLD while a token is on the bonding
    // curve, in bps of SUPPLY (200 = 2% = 20M). Each launched token enforces this on
    // EVERY transfer (see LaunchToken._update), so it can't be dodged by buying from
    // many wallets and consolidating; the cap lifts automatically at graduation. This
    // is the default stamped onto NEW launches — the owner can retune it for future
    // launches without touching already-live tokens. 0 = disabled.
    uint96 public maxWalletBps;

    /// @dev The LaunchToken implementation cloned for every launch (deployed once).
    address public immutable tokenImplementation;

    // Pull-payment ETH owed to token creators (accrued from every trade of their
    // coins). Pull, not push, so a creator that can't receive ETH can never brick
    // trading for everyone else.
    mapping(address => uint256) public creatorRewards;

    struct Curve {
        address token;
        address creator;
        uint256 ethReserveReal; // real ETH held for this token
        uint256 tokensSold; // tokens handed out (circulating)
        bool graduated;
        bool exists;
        string metadataUri; // image / description / socials (data: or url)
    }

    mapping(address => Curve) public curves;
    address[] public tokens;

    event TokenCreated(address indexed token, address indexed creator, string name, string symbol, string metadataUri);
    event Buy(address indexed token, address indexed buyer, uint256 ethIn, uint256 tokensOut, uint256 fee);
    event Sell(address indexed token, address indexed seller, uint256 tokensIn, uint256 ethOut, uint256 fee);
    event Graduated(address indexed token, uint256 ethLiquidity, uint256 tokenLiquidity);
    event FeeUpdated(uint96 feeBps, uint96 creatorFeeBps, address recipient);
    event CreatorFeeAccrued(address indexed token, address indexed creator, uint256 amount);
    event CreatorRewardClaimed(address indexed creator, uint256 amount);
    event MaxWalletUpdated(uint96 maxWalletBps);

    constructor(uint96 feeBps_, uint96 creatorFeeBps_, address feeRecipient_, address owner_) Ownable(owner_) {
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        require(creatorFeeBps_ <= feeBps_, "creator fee too high");
        require(feeRecipient_ != address(0), "recipient zero");
        feeBps = feeBps_;
        creatorFeeBps = creatorFeeBps_;
        feeRecipient = feeRecipient_;
        maxWalletBps = 200; // 2% of supply per wallet during bonding (anti-whale)
        // Deploy the token implementation once; every launch clones it (EIP-1167).
        tokenImplementation = address(new LaunchToken());
    }

    // ---- creation ----

    function createToken(string calldata name, string calldata symbol, string calldata metadataUri)
        public
        returns (address token)
    {
        // Cheap EIP-1167 clone instead of deploying a full ERC-20 each time. Cloned +
        // initialized in the same tx, so no one can front-run the one-time initialize().
        token = Clones.clone(tokenImplementation);
        // The token enforces the per-wallet cap itself (on every transfer), so it's set
        // once at launch from the current maxWalletBps. Existing tokens keep their cap.
        LaunchToken(token).initialize(name, symbol, SUPPLY, maxWalletTokens());
        Curve storage c = curves[token];
        c.token = token;
        c.creator = msg.sender;
        c.exists = true;
        c.metadataUri = metadataUri;
        tokens.push(token);
        emit TokenCreated(token, msg.sender, name, symbol, metadataUri);
    }

    /// @notice Fair-launch create + optional immediate dev buy in one tx.
    function createAndBuy(
        string calldata name,
        string calldata symbol,
        string calldata metadataUri,
        uint256 minTokensOut
    ) external payable nonReentrant returns (address token) {
        token = createToken(name, symbol, metadataUri);
        if (msg.value > 0) _buy(token, minTokensOut);
    }

    // ---- reserves / pricing ----

    /// @dev Effective (rEth, rTok) reserves — virtual pre-graduation, real after.
    function _reserves(Curve storage c) internal view returns (uint256 rEth, uint256 rTok) {
        if (c.graduated) {
            rEth = c.ethReserveReal;
            rTok = SUPPLY - c.tokensSold; // real tokens still held = the locked pool
        } else {
            rEth = VIRT_ETH + c.ethReserveReal;
            rTok = VIRT_TOKEN - c.tokensSold;
        }
    }

    function _tokensOutForEth(uint256 rEth, uint256 rTok, uint256 ethNet) internal pure returns (uint256) {
        uint256 newREth = rEth + ethNet;
        // ceil the new token reserve so the buyer never receives more than the
        // invariant allows — rounding always favors the pool (prevents a
        // round-trip from draining the real reserve).
        uint256 newRTok = (rEth * rTok + newREth - 1) / newREth;
        return rTok - newRTok;
    }

    function _ethInForExactTokens(uint256 rEth, uint256 rTok, uint256 tokensOut) internal pure returns (uint256) {
        uint256 newRTok = rTok - tokensOut;
        // ceil-div so the pool never receives less than the invariant requires
        uint256 newREth = (rEth * rTok + newRTok - 1) / newRTok;
        return newREth - rEth;
    }

    function _ethOutForTokens(uint256 rEth, uint256 rTok, uint256 tokensIn) internal pure returns (uint256) {
        uint256 newRTok = rTok + tokensIn;
        // ceil the new ETH reserve so the seller never receives more than the
        // invariant allows — rounding always favors the pool.
        uint256 newREth = (rEth * rTok + newRTok - 1) / newRTok;
        return rEth - newREth;
    }

    // ---- quotes (view) ----

    function quoteBuy(address token, uint256 ethIn) external view returns (uint256 tokensOut, uint256 fee) {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        fee = (ethIn * feeBps) / BPS;
        (uint256 rEth, uint256 rTok) = _reserves(c);
        uint256 out = _tokensOutForEth(rEth, rTok, ethIn - fee);
        if (!c.graduated) {
            uint256 remaining = CURVE_SUPPLY - c.tokensSold;
            if (out > remaining) out = remaining; // clamped at graduation
        }
        tokensOut = out;
    }

    function quoteSell(address token, uint256 tokensIn) external view returns (uint256 ethOut, uint256 fee) {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        (uint256 rEth, uint256 rTok) = _reserves(c);
        uint256 gross = _ethOutForTokens(rEth, rTok, tokensIn);
        fee = (gross * feeBps) / BPS;
        ethOut = gross - fee;
    }

    // ---- trading ----

    function buy(address token, uint256 minTokensOut) external payable nonReentrant {
        _buy(token, minTokensOut);
    }

    function _buy(address token, uint256 minTokensOut) internal {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        require(msg.value > 0, "no eth");

        uint256 fee = (msg.value * feeBps) / BPS;
        uint256 ethNet = msg.value - fee;
        (uint256 rEth, uint256 rTok) = _reserves(c);
        uint256 tokensOut = _tokensOutForEth(rEth, rTok, ethNet);

        // Pre-graduation buys are capped at the curve allocation; the buy that
        // crosses the cap graduates the token and refunds any unused ETH. The
        // per-wallet holding cap is enforced by the token itself on the payout
        // transfer below (and on the graduating transfer), so no whale can end up
        // over the cap — including by buying from many wallets and consolidating.
        if (!c.graduated) {
            uint256 remaining = CURVE_SUPPLY - c.tokensSold;
            if (tokensOut >= remaining) {
                _buyAndGraduate(c, remaining, minTokensOut);
                return;
            }
        }

        require(tokensOut > 0, "zero out");
        require(tokensOut >= minTokensOut, "slippage");

        c.ethReserveReal += ethNet;
        c.tokensSold += tokensOut;

        _routeFee(token, c.creator, fee);
        require(IERC20(token).transfer(msg.sender, tokensOut), "token transfer failed");
        emit Buy(token, msg.sender, msg.value, tokensOut, fee);
    }

    function _buyAndGraduate(Curve storage c, uint256 tokensOut, uint256 minTokensOut) internal {
        require(tokensOut >= minTokensOut, "slippage");
        (uint256 rEth, uint256 rTok) = _reserves(c); // still virtual here
        uint256 ethNeededNet = _ethInForExactTokens(rEth, rTok, tokensOut);
        // Gross-up the fee onto the actually-used ETH so the buyer pays fee only
        // on what they spend; refund the remainder of msg.value.
        uint256 ethUsedGross = (ethNeededNet * BPS + (BPS - feeBps) - 1) / (BPS - feeBps);
        // Clamp instead of reverting: on a razor-exact graduating buy the ceil'd
        // gross-up can exceed msg.value by ~1 wei. The buyer sent enough net ETH
        // for the tokens (ethNeededNet < msg.value), so keep the pool solvent and
        // charge at most ~1 wei of extra fee rather than reverting a valid buy.
        if (ethUsedGross > msg.value) ethUsedGross = msg.value;
        uint256 feeUsed = ethUsedGross - ethNeededNet;
        uint256 refund = msg.value - ethUsedGross;

        c.ethReserveReal += ethNeededNet;
        c.tokensSold += tokensOut; // == CURVE_SUPPLY
        c.graduated = true;

        _routeFee(c.token, c.creator, feeUsed);
        // The token still enforces the wallet cap on THIS transfer (graduating buyer
        // can't exceed the cap either), then we lift it so the graduated token trades
        // freely from here on.
        require(IERC20(c.token).transfer(msg.sender, tokensOut), "token transfer failed");
        LaunchToken(c.token).setGraduated();
        if (refund > 0) _pay(msg.sender, refund);

        emit Buy(c.token, msg.sender, ethUsedGross, tokensOut, feeUsed);
        emit Graduated(c.token, c.ethReserveReal, SUPPLY - c.tokensSold);
    }

    function sell(address token, uint256 tokensIn, uint256 minEthOut) external nonReentrant {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        require(tokensIn > 0, "no tokens");
        require(tokensIn <= c.tokensSold, "exceeds circulating");

        (uint256 rEth, uint256 rTok) = _reserves(c);
        uint256 gross = _ethOutForTokens(rEth, rTok, tokensIn);
        require(gross <= c.ethReserveReal, "insufficient reserve");
        uint256 fee = (gross * feeBps) / BPS;
        uint256 ethOut = gross - fee;
        require(ethOut >= minEthOut, "slippage");

        c.ethReserveReal -= gross;
        c.tokensSold -= tokensIn;

        require(IERC20(token).transferFrom(msg.sender, address(this), tokensIn), "token pull failed");
        _routeFee(token, c.creator, fee);
        (bool ok, ) = payable(msg.sender).call{value: ethOut}("");
        require(ok, "eth payout failed");
        emit Sell(token, msg.sender, tokensIn, ethOut, fee);
    }

    function _pay(address to, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "payout failed");
    }

    /// @dev Split a trade fee: the creator's cut is accrued for later claim
    ///      (pull), the platform's cut is pushed to the (trusted) feeRecipient.
    function _routeFee(address token, address creator, uint256 fee) internal {
        if (fee == 0) return;
        uint256 creatorCut = feeBps == 0 ? 0 : (fee * creatorFeeBps) / feeBps;
        if (creatorCut > 0) {
            creatorRewards[creator] += creatorCut;
            emit CreatorFeeAccrued(token, creator, creatorCut);
        }
        _pay(feeRecipient, fee - creatorCut);
    }

    /// @notice Token creators withdraw the ETH fees earned from trades of their coins.
    function claimCreatorRewards() external nonReentrant {
        uint256 amt = creatorRewards[msg.sender];
        require(amt > 0, "nothing to claim");
        creatorRewards[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "claim failed");
        emit CreatorRewardClaimed(msg.sender, amt);
    }

    // ---- anti-whale wallet cap ----

    /// @notice Per-wallet holding cap in tokens (18-dec) stamped onto NEW launches.
    ///         0 when disabled (maxWalletBps == 0). Each token stores + enforces its own
    ///         cap from launch; retuning maxWalletBps only affects future launches.
    function maxWalletTokens() public view returns (uint256) {
        return maxWalletBps == 0 ? 0 : (SUPPLY * maxWalletBps) / BPS;
    }

    /// @notice Owner-tunable per-wallet holding cap for future launches (bps of SUPPLY; 0 disables).
    function setMaxWalletBps(uint96 bps) external onlyOwner {
        require(bps <= BPS, "bps too high");
        maxWalletBps = bps;
        emit MaxWalletUpdated(bps);
    }

    // ---- admin / views ----

    function setFee(uint96 feeBps_, uint96 creatorFeeBps_, address feeRecipient_) external onlyOwner {
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        require(creatorFeeBps_ <= feeBps_, "creator fee too high");
        require(feeRecipient_ != address(0), "recipient zero");
        feeBps = feeBps_;
        creatorFeeBps = creatorFeeBps_;
        feeRecipient = feeRecipient_;
        emit FeeUpdated(feeBps_, creatorFeeBps_, feeRecipient_);
    }

    function totalTokens() external view returns (uint256) {
        return tokens.length;
    }

    /// @notice Current price: wei of ETH per 1e18 token.
    function priceOf(address token) public view returns (uint256) {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        (uint256 rEth, uint256 rTok) = _reserves(c);
        return (rEth * 1e18) / rTok;
    }

    /// @notice Fully-diluted market cap in wei (price * total supply).
    function marketCap(address token) external view returns (uint256) {
        return (priceOf(token) * SUPPLY) / 1e18;
    }

    /// @notice One-call snapshot for the UI / indexer.
    function tokenInfo(address token)
        external
        view
        returns (
            address creator,
            uint256 ethReserveReal,
            uint256 tokensSold,
            bool graduated,
            uint256 price,
            string memory metadataUri
        )
    {
        Curve storage c = curves[token];
        require(c.exists, "no token");
        return (c.creator, c.ethReserveReal, c.tokensSold, c.graduated, priceOf(token), c.metadataUri);
    }
}
