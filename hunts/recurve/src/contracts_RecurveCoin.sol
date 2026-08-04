// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "./lib/UniV3.sol";

/// @notice Minimal ERC-20, deployed fresh per launch by Recurve.
///
/// Deployed in full rather than cloned. A clone costs ~$0.04 less in gas, but
/// explorers stamp "Proxy" on an EIP-1167 forwarder, and a buyer who doesn't
/// know the pattern reads that as "upgradeable, can rug". It isn't — the
/// implementation is welded into the forwarder's bytecode — but the label is
/// what people act on. Four cents is not worth arguing with that.
///
/// Fixed supply, minted once to the launchpad. No mint, no owner, no pause, no
/// blacklist, no upgrade. Nothing here can take a holder's tokens.
///
/// The ONE thing this contract can do to a transfer is reject an oversized buy
/// during the first RESTRICTION_BLOCKS. That is a real cost, stated plainly:
/// for ~36 seconds this is not a plain ERC-20. After that the guard is dead
/// code forever — there is no switch to revive it.
contract RecurveCoin {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public immutable launchpad;
    address public immutable creator;
    /// @dev Off-chain metadata (image / description / socials) pinned at launch.
    string public metadataURI;

    // ── launch guards ───────────────────────────────────────────────────────
    /// Caps apply only to buys FROM the pool, and only for this many blocks.
    /// Blocks are ~0.1s here, so this is ~36.6s — the same window Pons uses.
    /// Values match Pons on-chain (verified): 5% wallet / 5.5% tx. Constants,
    /// not settings: nobody can widen or extend them.
    uint256 public constant RESTRICTION_BLOCKS = 366;
    uint256 public constant MAX_WALLET_BPS = 500; // 5% of supply
    uint256 public constant MAX_TX_BPS = 550; // 5.5% of supply
    uint256 private constant BPS = 10_000;

    address public immutable pairToken;
    IUniswapV3Factory public immutable dexFactory;
    uint24 public immutable poolFee;
    uint256 public immutable launchBlock;
    uint256 public immutable restrictionEndBlock;
    uint256 public immutable maxWalletAmount;
    uint256 public immutable maxTxAmount;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// Cumulative tokens each address has bought FROM a pair pool during the
    /// restriction window. Caps are cumulative, so splitting a buy across many
    /// txs can't dodge the max-tx limit. Irrelevant (and unread) once the window
    /// closes, so it's never cleared.
    mapping(address => uint256) private _windowBuys;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();
    error MaxWalletExceeded(address to, uint256 balanceAfter, uint256 limit);
    error MaxTxExceeded(address to, uint256 cumulative, uint256 limit);

    /// @notice Deployed by Recurve inside the launch transaction.
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadataURI,
        address _creator,
        uint256 _supply,
        address _pairToken,
        address _dexFactory,
        uint24 _poolFee
    ) {
        launchpad = msg.sender;
        name = _name;
        symbol = _symbol;
        metadataURI = _metadataURI;
        creator = _creator;
        totalSupply = _supply;

        pairToken = _pairToken;
        dexFactory = IUniswapV3Factory(_dexFactory);
        poolFee = _poolFee;
        launchBlock = block.number;
        restrictionEndBlock = block.number + RESTRICTION_BLOCKS;
        maxWalletAmount = (_supply * MAX_WALLET_BPS) / BPS;
        maxTxAmount = (_supply * MAX_TX_BPS) / BPS;

        // Entire supply goes to the launchpad, which puts all of it into the pool.
        balanceOf[msg.sender] = _supply;
        emit Transfer(address(0), msg.sender, _supply);
    }

    /// @notice The canonical pool. Derived, not stored: the pool cannot exist yet
    ///         when this constructor runs, since creating it needs our address.
    function liquidityPool() public view returns (address) {
        return dexFactory.getPool(address(this), pairToken, poolFee);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        // Dead-standard ERC20: check the allowance, always decrement it, transfer.
        // No infinite-approval "skip decrement when allowance == max" shortcut —
        // it saves a little gas, but it's the exact pattern bytecode auditors
        // misread as "transferFrom silently does nothing", and a coin looking
        // unsafe at launch costs far more than the gas. Starting from 2^256-1 the
        // allowance still never runs out in any realistic life of a token.
        uint256 a = allowance[from][msg.sender];
        if (a < value) revert InsufficientAllowance();
        unchecked { allowance[from][msg.sender] = a - value; }
        _transfer(from, to, value);
        return true;
    }

    /// @dev Caps oversized buys during the opening window. Deliberately mild:
    ///
    ///  • Only BUYS are capped — a transfer whose `from` is a Uniswap V3 pool for
    ///    this token/pair, at ANY fee tier (so a sniper can't route around it via
    ///    an alt-fee pool). Sells and plain wallet-to-wallet transfers are NEVER
    ///    restricted, in any block.
    ///  • A cumulative per-wallet limit (splitting one buy into twenty small ones
    ///    doesn't dodge it) plus a max-wallet ceiling on the resulting balance.
    ///  • No creator exemption, and limits key off the recipient's balance, not
    ///    tx.origin (wrong for smart-contract wallets, trivially sidestepped with
    ///    fresh EOAs). The creator is capped like everyone.
    ///
    /// The only exemption is `to == launchpad`: the atomic dev buy routed through
    /// Recurve inside create(). The launchpad is immutable and only receives
    /// tokens during that call, so it can't be reused after.
    ///
    /// There is NO hard block on the launch block itself. That "all buys revert"
    /// pattern reads as a honeypot to bytecode scanners, and it only delays a
    /// sniper by one ~0.1s block anyway — the caps still bound them. After
    /// restrictionEndBlock the guard is dead code forever; nothing revives it.
    ///
    /// Honest limit: caps are per address. A bot with 20 wallets clears a 5% cap
    /// for pennies at this chain's gas. This raises effort; it does not stop a
    /// determined sniper. Nothing here does, including every competitor.
    function _guard(address from, address to, uint256 value) internal {
        if (block.number > restrictionEndBlock) return; // window over, forever
        if (to == launchpad) return; // atomic dev buy inside create()
        if (!_isPairPool(from)) return; // only buys from a pair pool are capped

        // Cumulative across the window, then the wallet ceiling.
        uint256 cumulative = _windowBuys[to] + value;
        if (cumulative > maxTxAmount) revert MaxTxExceeded(to, cumulative, maxTxAmount);
        _windowBuys[to] = cumulative;

        uint256 balanceAfter = balanceOf[to] + value;
        if (balanceAfter > maxWalletAmount) revert MaxWalletExceeded(to, balanceAfter, maxWalletAmount);
    }

    /// @dev True if `candidate` is a Uniswap V3 pool for (this token, pairToken)
    ///      at ANY fee tier. The canonical pool is the fast path; otherwise, ask
    ///      the pool its own fee and confirm the factory maps that pair+fee back
    ///      to exactly this address (so a look-alike can't spoof it).
    function _isPairPool(address candidate) private view returns (bool) {
        if (candidate == address(0)) return false;
        address canonical = liquidityPool();
        if (canonical != address(0) && candidate == canonical) return true;
        if (candidate.code.length == 0) return false;
        (bool ok, bytes memory data) = candidate.staticcall(abi.encodeWithSignature("fee()"));
        if (!ok || data.length < 32) return false;
        uint24 candidateFee = abi.decode(data, (uint24));
        return dexFactory.getPool(address(this), pairToken, candidateFee) == candidate;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        _guard(from, to, value);

        uint256 bal = balanceOf[from];
        if (bal < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}
