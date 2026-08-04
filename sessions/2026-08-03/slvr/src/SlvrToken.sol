// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniV2RouterLike} from "./interfaces/IUniV2RouterLike.sol";
import {ISlvrTaxHandler} from "./interfaces/ISlvrTaxHandler.sol";

/// @title SlvrToken
/// @notice ERC20 token with configurable buy/sell tax for the Slvr ecosystem.
/// @notice Maximum supply of 500,000 SLVR tokens (MAX_SUPPLY cap).
/// @notice Implements separate buy and sell taxes (2%/2% at launch, DECREASE-ONLY) that go to jackpot.
/// @notice Automatically swaps collected tax to ETH and deposits into jackpot during transfers.
/// @notice Total supply tracking:
/// @notice - Initial mint: 10,000 SLVR (one-time, via initialMint)
/// @notice - Lottery mints: Base amount + 10% to team vesting + 4% to growth fund (via mint)
/// @notice - All mints increase total supply and are counted toward MAX_SUPPLY
/// @notice - Burns decrease total supply (via ERC20Burnable), freeing up space for more mints
/// @notice - MAX_SUPPLY is a cap: minting allowed as long as totalSupply() + newMint <= MAX_SUPPLY
/// @notice - Because burns reduce totalSupply(), we can continue minting up to MAX_SUPPLY even after burns
/// @notice - Tokens in vesting contracts are part of total supply but not circulating until claimed
contract SlvrToken is ERC20, ERC20Burnable, AccessControl, Ownable2Step, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_SUPPLY = 500_000e18; // 500,000 SLVR

    /// @notice The conventional "dead" address. Transfers here (or to the zero address) are
    ///         redirected to a real burn so they reduce totalSupply and reopen mint headroom for
    ///         the circular emission model — rather than parking supply at 0xdead forever.
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // Initial mint tracking
    bool public initialMintDone; // Tracks if initial mint has been completed
    uint256 public constant INITIAL_SUPPLY = 10_000e18; // Default genesis seed (used by initialMint(to)); initialMint(to, amount) can start smaller

    // Tax parameters. The token launches at LAUNCH_TAX_BPS (2%/2%) and the tax is
    // DECREASE-ONLY: setBuyTax/setSellTax revert on any increase, so no owner action
    // can ever raise the tax above its launch value. (Deliberate: keeps token
    // scanners like GoPlus from flagging high/raisable tax, and removes the old
    // 25%->2% first-hour decay, which read as a 25% tax to anyone scanning at launch.)
    uint16 public constant LAUNCH_TAX_BPS = 200; // 2% buy / 2% sell at deploy — the all-time maximum
    uint16 public buyTaxBps; // Buy tax in basis points; starts at LAUNCH_TAX_BPS, only decreasable
    uint16 public sellTaxBps; // Sell tax in basis points; starts at LAUNCH_TAX_BPS, only decreasable
    address public jackpotRecipient; // Address that receives tax (lottery contract)
    address public teamVesting; // Team vesting contract address (for 8% of mint allocations)
    address public growthFund; // Growth fund contract address (for 4% of supply inflation)

    // Swapback parameters
    IUniV2RouterLike public swapRouter; // Uniswap V2 router for swaps
    address public pairToken; // ETH (WETH) address for the swap pair
    address public uniswapV2Pair; // Legacy single V2 pair (kept working; also treated as a taxed pool)

    // DEX-agnostic tax detection: any address flagged here counts as an AMM pool, so transfers TO it
    // are taxed as sells and transfers FROM it as buys. Lets the token tax trades across multiple
    // venues (additional V2 pairs, V3 pools, a V4 PoolManager, etc.) without a code change — the
    // owner just registers each pool via setTaxedPool. The legacy `uniswapV2Pair` is always treated
    // as taxed too, for backwards compatibility.
    mapping(address => bool) public isTaxedPool;
    uint256 public swapbackThreshold; // Minimum SLVR amount before triggering swapback
    uint256 public swapbackInterval; // Minimum time between swapbacks (configurable, but >= MIN_SWAPBACK_INTERVAL)
    uint256 public lastSwapbackTime; // Last time swapback was executed (or threshold first exceeded, if no swapback yet)
    uint256 public constant MIN_SWAPBACK_INTERVAL = 30 seconds; // Hard limit: minimum time between swapbacks (cannot be bypassed)
    uint256 public constant MAX_SWAPBACK_THRESHOLD = 10e18; // Maximum swapback threshold: 10 SLVR (common sense limit)

    // Minimum ETH out required by the AUTOMATIC swapback (the one fired inside a user's sell in
    // _update). Defaults to 0 (accept any) to preserve existing behavior. Owners who want a floor on
    // the sandwich-exposed auto path can set an absolute minimum here; the manual executeSwapback /
    // ownerExecuteSwapback entrypoints already take a caller-supplied amountOutMin. The per-swap size
    // is hard-capped at MAX_SWAPBACK_THRESHOLD, which bounds any residual MEV leak.
    uint256 public swapbackMinOut;

    // Pluggable tax handler (ISlvrTaxHandler). When set, collected SLVR tax is routed here for
    // processing instead of the built-in V2 swapback — so the swap venue and destinations are fully
    // swappable (V2/V3/V4/splitters/…) with no token redeploy. 0 = use the built-in V2 swapback.
    address public taxHandler;

    // Accumulated tax and rewards
    uint256 public accumulatedTax; // Accumulated SLVR tax waiting to be swapped
    uint256 public accumulatedEthRewards; // Accumulated ETH rewards waiting to be deposited

    // Reentrancy guard for swapback
    bool private inSwapback;

    // Exempt addresses from tax (lottery, staking contracts, etc.)
    mapping(address => bool) public isTaxExempt;
    // Exempt addresses from sell tax only (for liquidity operations)
    // These addresses can still pay buy tax on swaps, but won't pay sell tax when adding liquidity
    mapping(address => bool) public isSellTaxExempt;
    
    // Pending accruals tracking (for failed accrue() calls)
    // Maps contract address to pending accrual amount
    mapping(address => uint256) public pendingAccruals;
    
    // Failed accruals tracking
    // Maps contract address => block number => amount
    mapping(address => mapping(uint256 => uint256)) public failedAccrualsByBlock;

    event BuyTaxUpdated(uint16 oldTaxBps, uint16 newTaxBps);
    event SellTaxUpdated(uint16 oldTaxBps, uint16 newTaxBps);
    event JackpotRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event TaxExemptUpdated(address indexed account, bool exempt);
    event SellTaxExemptUpdated(address indexed account, bool exempt);
    event TaxCollected(address indexed from, uint256 amount, uint16 taxRateBps, bool isBuy);
    event SwapbackExecuted(uint256 slvrSwapped, uint256 ethReceived);
    event EthDepositedToJackpot(uint256 amount);
    event SwapbackConfigUpdated(address router, address pairToken, uint256 threshold, uint256 interval);
    event SwapbackMinOutUpdated(uint256 oldMinOut, uint256 newMinOut);
    event TaxHandlerUpdated(address indexed oldHandler, address indexed newHandler);
    event TaxRoutedToHandler(address indexed handler, uint256 amount);
    // reason is the handler's RAW revert data (Error(string) or a custom-error selector), not a
    // string cast — casting mangles it (selector bytes become garbage). Decode off-chain.
    event TaxHandlerFailed(address indexed handler, uint256 amount, bytes reason);
    event UniswapV2PairUpdated(address indexed oldPair, address indexed newPair);
    event TaxedPoolUpdated(address indexed pool, bool taxed);
    event TeamVestingUpdated(address indexed oldVesting, address indexed newVesting);
    event GrowthFundUpdated(address indexed oldFund, address indexed newFund);
    event TokensBurned(address indexed account, uint256 amount, uint256 newTotalSupply);
    event AccrueFailed(address indexed contractAddress, uint256 amount, uint256 blockNumber, uint256 timestamp, string reason);
    event AccrueRetried(address indexed contractAddress, uint256 amount, bool success);
    event SwapbackFailed(uint256 amount, string reason);
    event SwapbackAttempted(uint256 accumulatedTax, uint256 threshold, uint256 timeSinceFirstExceeded, bool intervalMet);

    constructor(address admin) ERC20("Slvr", "SLVR") Ownable(admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        // Exempt admin and this contract from tax
        isTaxExempt[admin] = true;
        isTaxExempt[address(this)] = true;
        // Launch taxes: 2%/2%, decrease-only from here (see LAUNCH_TAX_BPS).
        buyTaxBps = LAUNCH_TAX_BPS;
        sellTaxBps = LAUNCH_TAX_BPS;
        swapbackThreshold = 1e18;
        swapbackInterval = 55 seconds;
    }

    /// @notice Initial mint of the default seed supply (INITIAL_SUPPLY) - once, owner-only.
    /// @dev Convenience wrapper kept for backwards compatibility. Prefer initialMint(to, amount) to
    ///      launch with a smaller circulating seed and let the rest emit naturally via the hub.
    /// @param to Address to receive the remaining seed supply (after 8%/4% team+growth allocations)
    function initialMint(address to) external onlyOwner {
        _initialMint(to, INITIAL_SUPPLY);
    }

    /// @notice Initial mint with a caller-chosen seed supply - once, owner-only.
    /// @dev Lets a launch start with a small circulating supply (e.g. just enough to seed the first
    ///      liquidity pool) instead of a large fixed amount; ongoing supply is emitted over time by
    ///      the hub up to MAX_SUPPLY. 8% is allocated to team vesting and 4% to growth fund (carved
    ///      out of `initialSupply`, not added on top), if those addresses are set.
    /// @param to Address to receive the remaining seed supply (after allocations)
    /// @param initialSupply Total tokens to mint at genesis (0 < initialSupply <= MAX_SUPPLY)
    function initialMint(address to, uint256 initialSupply) external onlyOwner {
        _initialMint(to, initialSupply);
    }

    /// @dev Shared one-time genesis mint. Total supply increases by exactly `initialSupply`.
    function _initialMint(address to, uint256 initialSupply) private {
        require(!initialMintDone, "initial mint already done");
        require(to != address(0), "invalid address");
        require(initialSupply > 0, "initialSupply=0");
        require(initialSupply <= MAX_SUPPLY, "exceeds max supply");
        initialMintDone = true;

        // If team vesting and growth fund are set, allocate 8% and 4% respectively
        // Otherwise, mint everything to deployer (backward compatible)
        if (teamVesting != address(0) && growthFund != address(0)) {
            // Calculate allocations: 8% to team vesting, 4% to growth fund
            uint256 teamAmount = (initialSupply * 800) / 10000; // 8% = 800 basis points
            uint256 growthAmount = (initialSupply * 400) / 10000; // 4% = 400 basis points
            uint256 deployerAmount = initialSupply - teamAmount - growthAmount; // Remainder to deployer

            // Mint to deployer
            _mint(to, deployerAmount);

            // Mint to team vesting
            if (teamAmount > 0) {
                _mint(teamVesting, teamAmount);
                // Call accrue on team vesting contract - record pending if it fails
                (bool success,) = teamVesting.call(
                    abi.encodeWithSignature("accrue(uint256)", teamAmount)
                );
                if (!success) {
                    pendingAccruals[teamVesting] += teamAmount;
                    uint256 blockNum = block.number;
                    failedAccrualsByBlock[teamVesting][blockNum] += teamAmount;
                    emit AccrueFailed(teamVesting, teamAmount, blockNum, block.timestamp, "accrue call failed");
                }
            }

            // Mint to growth fund
            if (growthAmount > 0) {
                _mint(growthFund, growthAmount);
                // Call accrue on growth fund contract - record pending if it fails
                (bool success,) = growthFund.call(
                    abi.encodeWithSignature("accrue(uint256)", growthAmount)
                );
                if (!success) {
                    pendingAccruals[growthFund] += growthAmount;
                    uint256 blockNum = block.number;
                    failedAccrualsByBlock[growthFund][blockNum] += growthAmount;
                    emit AccrueFailed(growthFund, growthAmount, blockNum, block.timestamp, "accrue call failed");
                }
            }
        } else {
            // Backward compatible: mint everything to deployer if addresses not set
            _mint(to, initialSupply);
        }

        // Total supply is now exactly initialSupply
        require(totalSupply() == initialSupply, "initial mint supply mismatch");
    }

    /// @notice Mint tokens - only for lottery rewards (capped by MAX_SUPPLY)
    /// @dev Can only be called by addresses with MINTER_ROLE (e.g., lottery contract)
    /// @dev Mints amount to recipient, plus additional 8% to team vesting and 4% to growth fund
    /// @dev Total mint = amount * 1.12 (amount + 8% + 4%)
    /// @dev Total supply increases by totalMint (all mints are counted in total supply)
    /// @dev MAX_SUPPLY is a cap: minting allowed as long as totalSupply() + totalMint <= MAX_SUPPLY
    /// @dev Because burns decrease totalSupply(), we can continue minting up to MAX_SUPPLY after burns
    /// @param to Address to receive the minted tokens (100% of amount)
    /// @param amount Amount of tokens to mint to recipient (before additional allocations)
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(initialMintDone, "initial mint not done");

        // Calculate additional allocations: 8% to team vesting, 4% to growth fund
        uint256 teamAmount = (amount * 800) / 10000; // 8% = 800 basis points
        uint256 growthAmount = (amount * 400) / 10000; // 4% = 400 basis points
        uint256 totalMint = amount + teamAmount + growthAmount; // Total = 112% of amount

        // Store current total supply for verification
        uint256 supplyBefore = totalSupply();

        // Check max supply with total mint amount
        require(supplyBefore + totalMint <= MAX_SUPPLY, "exceeds max supply");

        // Mint full amount to recipient
        _mint(to, amount);

        // Mint additional 8% to team vesting contract - ALWAYS required
        require(teamVesting != address(0), "team vesting not set");
        if (teamAmount > 0) {
            _mint(teamVesting, teamAmount);
            // Call accrue on team vesting contract - record pending if it fails
            (bool success,) = teamVesting.call(
                abi.encodeWithSignature("accrue(uint256)", teamAmount)
            );
            if (!success) {
                pendingAccruals[teamVesting] += teamAmount;
                uint256 blockNum = block.number;
                failedAccrualsByBlock[teamVesting][blockNum] += teamAmount;
                emit AccrueFailed(teamVesting, teamAmount, blockNum, block.timestamp, "accrue call failed");
            }
        }

        // Mint additional 4% to growth fund contract and accrue
        if (growthAmount > 0 && growthFund != address(0)) {
            _mint(growthFund, growthAmount);
            // Call accrue on growth fund contract - record pending if it fails
            (bool success,) = growthFund.call(
                abi.encodeWithSignature("accrue(uint256)", growthAmount)
            );
            if (!success) {
                pendingAccruals[growthFund] += growthAmount;
                uint256 blockNum = block.number;
                failedAccrualsByBlock[growthFund][blockNum] += growthAmount;
                emit AccrueFailed(growthFund, growthAmount, blockNum, block.timestamp, "accrue call failed");
            }
        } else if (growthAmount > 0) {
            // If growth fund not set, mint to recipient (backward compatibility)
            _mint(to, growthAmount);
        }

        // Verify total supply increased by exactly totalMint
        assert(totalSupply() == supplyBefore + totalMint);
    }

    /// @notice Burn tokens - decreases total supply
    /// @dev Override to emit event and verify total supply decreases
    /// @param value Amount of tokens to burn
    function burn(uint256 value) public override {
        uint256 supplyBefore = totalSupply();
        super.burn(value);
        // Verify total supply decreased by exactly value
        require(totalSupply() == supplyBefore - value, "burn supply mismatch");
        emit TokensBurned(msg.sender, value, totalSupply());
    }

    /// @notice Burn tokens from account - decreases total supply
    /// @dev Override to emit event and verify total supply decreases
    /// @param account Account to burn tokens from
    /// @param value Amount of tokens to burn
    function burnFrom(address account, uint256 value) public override {
        uint256 supplyBefore = totalSupply();
        super.burnFrom(account, value);
        // Verify total supply decreased by exactly value
        require(totalSupply() == supplyBefore - value, "burnFrom supply mismatch");
        emit TokensBurned(account, value, totalSupply());
    }

    /// @notice Transfers to the zero address or 0xdead are treated as burns.
    /// @dev Standard ERC20 reverts on transfer-to-zero, and a transfer to 0xdead would otherwise
    ///      just park supply there without reducing totalSupply. We redirect both to a real burn so
    ///      "sending to dead" reopens mint headroom (circular emission), consistent with burn().
    function transfer(address to, uint256 value) public override returns (bool) {
        if (to == address(0) || to == DEAD) {
            _burnToDead(_msgSender(), value);
            return true;
        }
        return super.transfer(to, value);
    }

    /// @notice transferFrom to the zero address or 0xdead is treated as a burn (allowance spent).
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (to == address(0) || to == DEAD) {
            _spendAllowance(from, _msgSender(), value);
            _burnToDead(from, value);
            return true;
        }
        return super.transferFrom(from, to, value);
    }

    /// @dev Shared burn path for dead/zero-address transfers; reduces totalSupply and emits the
    ///      same TokensBurned event as burn()/burnFrom() so all burns look identical off-chain.
    function _burnToDead(address from, uint256 value) private {
        uint256 supplyBefore = totalSupply();
        _burn(from, value);
        require(totalSupply() == supplyBefore - value, "burn supply mismatch");
        emit TokensBurned(from, value, totalSupply());
    }

    /// @notice Get circulating supply (total supply minus tokens in vesting contracts)
    /// @dev Tokens in team vesting and growth fund are not considered circulating until claimed
    /// @return circulating The amount of tokens in circulation (excluding vesting contracts)
    function getCirculatingSupply() external view returns (uint256 circulating) {
        circulating = totalSupply();
        
        // Subtract tokens held by team vesting contract (not yet claimed)
        if (teamVesting != address(0)) {
            uint256 teamBalance = balanceOf(teamVesting);
            if (teamBalance > circulating) {
                // Safety check to prevent underflow
                circulating = 0;
            } else {
                circulating -= teamBalance;
            }
        }
        
        // Subtract tokens held by growth fund contract (not yet claimed)
        if (growthFund != address(0)) {
            uint256 growthBalance = balanceOf(growthFund);
            if (growthBalance > circulating) {
                // Safety check to prevent underflow
                circulating = 0;
            } else {
                circulating -= growthBalance;
            }
        }
    }

    /// @notice Lower the buy tax. DECREASE-ONLY: any attempt to raise it reverts,
    ///         so the launch rate (LAUNCH_TAX_BPS = 2%) is the all-time maximum.
    /// @param taxBps New buy tax in basis points (must be <= current buyTaxBps)
    function setBuyTax(uint16 taxBps) external onlyOwner {
        require(taxBps <= buyTaxBps, "tax can only decrease");
        uint16 oldTax = buyTaxBps;
        buyTaxBps = taxBps;
        emit BuyTaxUpdated(oldTax, taxBps);
    }

    /// @notice Lower the sell tax. DECREASE-ONLY: any attempt to raise it reverts,
    ///         so the launch rate (LAUNCH_TAX_BPS = 2%) is the all-time maximum.
    /// @param taxBps New sell tax in basis points (must be <= current sellTaxBps)
    function setSellTax(uint16 taxBps) external onlyOwner {
        require(taxBps <= sellTaxBps, "tax can only decrease");
        uint16 oldTax = sellTaxBps;
        sellTaxBps = taxBps;
        emit SellTaxUpdated(oldTax, taxBps);
    }

    /// @notice Effective tax rate. Kept for ABI compatibility with earlier versions
    ///         that applied a launch decay on top of the base rate; the tax is now
    ///         simply the stored base rate (2% at launch, decrease-only).
    /// @param baseTaxBps Base tax rate in basis points (buyTaxBps or sellTaxBps)
    /// @return Effective tax rate in basis points
    function getEffectiveTaxRate(uint16 baseTaxBps) public pure returns (uint16) {
        return baseTaxBps;
    }

    /// @notice Set jackpot recipient (lottery contract)
    function setJackpotRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "recipient=0");
        address oldRecipient = jackpotRecipient;
        jackpotRecipient = recipient;
        emit JackpotRecipientUpdated(oldRecipient, recipient);
    }

    /// @notice Set team vesting contract address
    function setTeamVesting(address vesting) external onlyOwner {
        address oldVesting = teamVesting;
        teamVesting = vesting;
        emit TeamVestingUpdated(oldVesting, vesting);
    }

    /// @notice Set growth fund contract address
    function setGrowthFund(address fund) external onlyOwner {
        address oldFund = growthFund;
        growthFund = fund;
        emit GrowthFundUpdated(oldFund, fund);
    }

    /// @notice Set tax exemption for an address
    /// @dev Use this to exempt liquidity zap contracts and other protocol contracts from tax
    function setTaxExempt(address account, bool exempt) external onlyOwner {
        isTaxExempt[account] = exempt;
        emit TaxExemptUpdated(account, exempt);
    }

    /// @notice Set sell tax exemption for an address (buy tax still applies)
    /// @dev Use this for liquidity zap contracts - they pay buy tax on swaps but not sell tax on liquidity adds
    /// @param account Address to exempt from sell tax
    /// @param exempt Whether to exempt from sell tax
    function setSellTaxExempt(address account, bool exempt) external onlyOwner {
        isSellTaxExempt[account] = exempt;
        emit SellTaxExemptUpdated(account, exempt);
    }

    /// @notice Set Uniswap V2 pair address (for detecting buy/sell trades)
    /// @dev Tax only applies to transfers involving a taxed pool. The legacy pair remains a taxed
    ///      pool automatically; for additional venues (more V2 pairs, V3/V4 pools) use setTaxedPool.
    /// @param pair The Uniswap V2 pair address
    function setUniswapV2Pair(address pair) external onlyOwner {
        require(pair != address(0), "pair=0");
        address oldPair = uniswapV2Pair;
        uniswapV2Pair = pair;
        emit UniswapV2PairUpdated(oldPair, pair);
    }

    /// @notice Register (or unregister) an AMM pool for buy/sell tax detection.
    /// @dev Any registered pool taxes trades to/from it, so the token is not tied to a single V2
    ///      pair — the owner can add other V2 pairs, V3 pools, a V4 PoolManager, etc. Detection here
    ///      is independent of the swapback venue (swapback still uses the configured V2 router).
    /// @param pool The pool/pair address to flag
    /// @param taxed Whether transfers to/from `pool` should be taxed
    function setTaxedPool(address pool, bool taxed) external onlyOwner {
        require(pool != address(0), "pool=0");
        isTaxedPool[pool] = taxed;
        emit TaxedPoolUpdated(pool, taxed);
    }

    /// @notice True if `addr` is treated as an AMM pool for tax purposes (legacy pair or registered).
    function _isTaxedPool(address addr) private view returns (bool) {
        return isTaxedPool[addr] || (addr != address(0) && addr == uniswapV2Pair);
    }

    /// @notice Configure swapback parameters
    /// @dev Interval must be >= MIN_SWAPBACK_INTERVAL (hard limit)
    /// @dev Threshold must be <= MAX_SWAPBACK_THRESHOLD (10 SLVR)
    function setSwapbackConfig(address router, address pairToken_, uint256 threshold, uint256 interval)
        external
        onlyOwner
    {
        require(router != address(0), "router=0");
        require(pairToken_ != address(0), "pairToken=0");
        require(interval >= MIN_SWAPBACK_INTERVAL, "interval below hard limit");
        require(threshold <= MAX_SWAPBACK_THRESHOLD, "threshold above max");

        // Exempt old router and pair if they were set
        if (address(swapRouter) != address(0)) {
            isTaxExempt[address(swapRouter)] = false;
        }
        if (pairToken != address(0)) {
            isTaxExempt[pairToken] = false;
        }

        swapRouter = IUniV2RouterLike(router);
        pairToken = pairToken_;
        swapbackThreshold = threshold;
        swapbackInterval = interval;

        isTaxExempt[address(swapRouter)] = true;

        emit SwapbackConfigUpdated(router, pairToken_, threshold, interval);
    }

    /// @notice Set swapback threshold + interval without configuring a V2 router.
    /// @dev For handler-based setups (setTaxHandler) that don't use the built-in V2 swapback. Same
    ///      bounds as setSwapbackConfig: threshold <= MAX_SWAPBACK_THRESHOLD, interval >= MIN_SWAPBACK_INTERVAL.
    function setSwapbackTiming(uint256 threshold, uint256 interval) external onlyOwner {
        require(interval >= MIN_SWAPBACK_INTERVAL, "interval below hard limit");
        require(threshold <= MAX_SWAPBACK_THRESHOLD, "threshold above max");
        swapbackThreshold = threshold;
        swapbackInterval = interval;
        emit SwapbackConfigUpdated(address(swapRouter), pairToken, threshold, interval);
    }

    /// @notice Set the minimum ETH out enforced by the automatic (sell-triggered) swapback.
    /// @dev 0 = accept any amount (default). Set a floor to reduce the auto path's sandwich exposure.
    function setSwapbackMinOut(uint256 minOut) external onlyOwner {
        uint256 old = swapbackMinOut;
        swapbackMinOut = minOut;
        emit SwapbackMinOutUpdated(old, minOut);
    }

    /// @notice Set (or clear) the pluggable tax handler.
    /// @dev When set (!= 0), collected SLVR tax is routed to the handler for processing instead of
    ///      the built-in V2 swapback. Set to 0 to revert to the built-in behavior. The handler is
    ///      auto tax-exempted so it can move SLVR (pull + swap) without being re-taxed. Swap this to
    ///      a new handler at any time to change swap venue / destinations — no token redeploy.
    /// @param handler The handler contract (must implement ISlvrTaxHandler), or 0 to disable.
    function setTaxHandler(address handler) external onlyOwner {
        address old = taxHandler;
        // Drop the old handler's tax exemption (best-effort; owner can re-exempt if reused elsewhere).
        if (old != address(0)) {
            isTaxExempt[old] = false;
        }
        taxHandler = handler;
        if (handler != address(0)) {
            isTaxExempt[handler] = true;
        }
        emit TaxHandlerUpdated(old, handler);
    }

    /// @notice Permissionlessly flush accumulated tax to the configured handler (keeper entrypoint).
    /// @dev Requires a handler set and the same threshold + hard interval as the automatic path, so
    ///      it can't be used to grief. Processes one `swapbackThreshold` chunk per call.
    function processTax() external nonReentrant {
        require(taxHandler != address(0), "no handler");
        require(accumulatedTax >= swapbackThreshold, "below threshold");
        require(block.timestamp >= lastSwapbackTime + MIN_SWAPBACK_INTERVAL, "hard limit: too soon");
        require(block.timestamp >= lastSwapbackTime + swapbackInterval, "too soon");
        require(!inSwapback, "swapback in progress");

        inSwapback = true;
        uint256 amount = swapbackThreshold;
        accumulatedTax -= amount;
        lastSwapbackTime = block.timestamp;
        _routeToHandler(amount);
        inSwapback = false;
    }

    /// @notice Route `amount` of SLVR tax to the pluggable handler via the PULL model.
    /// @dev Grants the handler an allowance and lets it pull + process. On failure the pull is rolled
    ///      back (nothing moved), so we restore accumulatedTax and clear the approval — no tax lost.
    ///      Caller must have set inSwapback=true so the handler's SLVR moves are not re-taxed.
    function _routeToHandler(uint256 amount) private {
        address handler = taxHandler;
        _approve(address(this), handler, amount);
        try ISlvrTaxHandler(handler).handleTax(amount) {
            // Handler pulled and processed; clear any residual approval defensively.
            if (allowance(address(this), handler) != 0) {
                _approve(address(this), handler, 0);
            }
            emit TaxRoutedToHandler(handler, amount);
        } catch (bytes memory reason) {
            _approve(address(this), handler, 0);
            accumulatedTax += amount; // atomic pull rolled back; nothing left the contract
            emit TaxHandlerFailed(handler, amount, reason);
        }
    }

    /// @notice Internal function to try swapback: checks conditions and executes if met
    /// @dev Called during transfers when selling to pair
    /// @dev Follows the pattern: check threshold, swap if conditions met, then continue with transfer
    function _trySwapback() private {
        // Check if swapback should be triggered
        // Only trigger when accumulatedTax exceeds threshold
        // Enforce hard limit: must wait at least MIN_SWAPBACK_INTERVAL since last swapback
        // Also enforce swapbackInterval: must wait at least swapbackInterval since last swapback
        if (inSwapback) {
            return;
        }

        // Need somewhere to send the tax: either a pluggable handler, or the built-in V2 route.
        if (taxHandler == address(0) && (address(swapRouter) == address(0) || pairToken == address(0))) {
            return;
        }

        if (accumulatedTax < swapbackThreshold) {
            return;
        }

        if (lastSwapbackTime == 0) {
            lastSwapbackTime = block.timestamp;
        }

        // Check interval requirements - must wait swapbackInterval since lastSwapbackTime
        // (which is either the last swapback time, or when threshold was first exceeded)
        uint256 timeSince = block.timestamp - lastSwapbackTime;
        if (block.timestamp < lastSwapbackTime + MIN_SWAPBACK_INTERVAL ||
            block.timestamp < lastSwapbackTime + swapbackInterval) {
            emit SwapbackAttempted(accumulatedTax, swapbackThreshold, timeSince, false);
            return;
        }

        // All conditions met - execute swapback
        emit SwapbackAttempted(accumulatedTax, swapbackThreshold, timeSince, true);
        _executeSwapback();
    }

    /// @notice Internal function to execute swapback: swap accumulated SLVR tax to ETH
    /// @dev Called by _trySwapback when conditions are met
    /// @dev Enforces hard limit: MIN_SWAPBACK_INTERVAL cannot be bypassed
    /// @dev Only swaps swapbackThreshold amount, not all accumulated tax
    function _executeSwapback() private {
        inSwapback = true;

        // Only swap the threshold amount, not all accumulated tax
        uint256 amountToSwap = swapbackThreshold;
        accumulatedTax -= amountToSwap;
        lastSwapbackTime = block.timestamp; // Update to actual swapback time

        // Preferred path: route to the pluggable handler (venue/destination-agnostic).
        if (taxHandler != address(0)) {
            _routeToHandler(amountToSwap);
            inSwapback = false;
            return;
        }

        // Built-in fallback: V2 swapback SLVR -> ETH -> jackpot.
        // Approve router to spend SLVR (safe approve: set to 0 first if needed)
        uint256 currentAllowance = allowance(address(this), address(swapRouter));
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance != 0) {
                _approve(address(this), address(swapRouter), 0);
            }
            _approve(address(this), address(swapRouter), type(uint256).max);
        }

        // Prepare swap path: SLVR -> ETH (WETH)
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pairToken;

        // Execute swap: SLVR -> ETH. Enforce the owner-configured floor (swapbackMinOut); 0 = any.
        uint256 balanceBefore = address(this).balance;
        try swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            swapbackMinOut,
            path,
            address(this),
            block.timestamp
        ) {
            uint256 ethReceived = address(this).balance - balanceBefore;
            // Always emit event and accumulate rewards, even if ethReceived is 0 (shouldn't happen but handle gracefully)
            if (ethReceived > 0) {
                accumulatedEthRewards += ethReceived;
            }
            emit SwapbackExecuted(amountToSwap, ethReceived);
        } catch (bytes memory reason) {
            // If swap fails, restore accumulated tax
            // Don't reset lastSwapbackTime - keep it so we still respect the interval
            accumulatedTax += amountToSwap;
            emit SwapbackFailed(amountToSwap, string(reason));
        }

        inSwapback = false;

        // Deposit ETH to jackpot after successful swapback
        _depositEthToJackpot();
    }

    /// @notice Internal function to deposit ETH to jackpot
    /// @dev Called automatically after swapback
    /// @dev Calls addEthToJackpot() on jackpotRecipient (lottery contract, which redirects to jackpot)
    function _depositEthToJackpot() private {
        if (jackpotRecipient == address(0) || accumulatedEthRewards == 0) {
            return;
        }

        uint256 amount = accumulatedEthRewards;
        accumulatedEthRewards = 0;

        // Call addEthToJackpot() on the lottery contract with ETH
        // The lottery contract redirects this to the jackpot contract
        (bool success,) =
            payable(jackpotRecipient).call{value: amount}(abi.encodeWithSignature("addEthToJackpot()"));

        if (success) {
            emit EthDepositedToJackpot(amount);
        } else {
            // If deposit fails, restore accumulated ETH
            accumulatedEthRewards += amount;
        }
    }

    /// @notice Manual execute swapback (for edge cases or manual triggers)
    /// @dev Enforces hard limit: MIN_SWAPBACK_INTERVAL cannot be bypassed
    /// @dev Only swaps swapbackThreshold amount, not all accumulated tax
    /// @param amountOutMin Minimum ETH amount expected from swap
    /// @param deadline Swap deadline
    function executeSwapback(uint256 amountOutMin, uint256 deadline) external nonReentrant {
        require(accumulatedTax >= swapbackThreshold, "below threshold");
        require(block.timestamp >= lastSwapbackTime + MIN_SWAPBACK_INTERVAL, "hard limit: too soon");
        require(block.timestamp >= lastSwapbackTime + swapbackInterval, "too soon");
        require(!inSwapback, "swapback in progress");

        inSwapback = true;

        // Only swap the threshold amount, not all accumulated tax
        uint256 amountToSwap = swapbackThreshold;
        accumulatedTax -= amountToSwap;
        lastSwapbackTime = block.timestamp;

        // When a handler is configured it is the sole tax path — route to it so this permissionless
        // entrypoint can't bypass the handler through the still-configured legacy V2 router. The
        // handler owns venue and slippage, so the caller's amountOutMin/deadline don't apply here.
        if (taxHandler != address(0)) {
            _routeToHandler(amountToSwap);
            inSwapback = false;
            return;
        }

        require(address(swapRouter) != address(0), "router not set");
        require(pairToken != address(0), "pairToken not set");

        // Approve router to spend SLVR (safe approve: set to 0 first if needed)
        uint256 currentAllowance = allowance(address(this), address(swapRouter));
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance != 0) {
                _approve(address(this), address(swapRouter), 0);
            }
            _approve(address(this), address(swapRouter), type(uint256).max);
        }

        // Prepare swap path: SLVR -> ETH (WETH)
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pairToken;

        // Execute swap: SLVR -> ETH
        uint256 balanceBefore = address(this).balance;
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap, amountOutMin, path, address(this), deadline
        );
        uint256 ethReceived = address(this).balance - balanceBefore;

        accumulatedEthRewards += ethReceived;
        emit SwapbackExecuted(amountToSwap, ethReceived);

        inSwapback = false;

        // Auto-deposit ETH to jackpot
        _depositEthToJackpot();
    }

    /// @notice Owner-only manual swapback that bypasses time interval restrictions
    /// @dev Only swaps swapbackThreshold amount, not all accumulated tax
    /// @param amountOutMin Minimum ETH amount expected from swap
    /// @param deadline Swap deadline
    function ownerExecuteSwapback(uint256 amountOutMin, uint256 deadline) external onlyOwner nonReentrant {
        require(accumulatedTax >= swapbackThreshold, "below threshold");
        require(!inSwapback, "swapback in progress");

        inSwapback = true;

        // Only swap the threshold amount, not all accumulated tax
        uint256 amountToSwap = swapbackThreshold;
        accumulatedTax -= amountToSwap;
        lastSwapbackTime = block.timestamp;

        // Prefer the pluggable handler when set (see executeSwapback).
        if (taxHandler != address(0)) {
            _routeToHandler(amountToSwap);
            inSwapback = false;
            return;
        }

        require(address(swapRouter) != address(0), "router not set");
        require(pairToken != address(0), "pairToken not set");

        // Approve router to spend SLVR (safe approve: set to 0 first if needed)
        uint256 currentAllowance = allowance(address(this), address(swapRouter));
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance != 0) {
                _approve(address(this), address(swapRouter), 0);
            }
            _approve(address(this), address(swapRouter), type(uint256).max);
        }

        // Prepare swap path: SLVR -> ETH (WETH)
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pairToken;

        // Execute swap: SLVR -> ETH
        uint256 balanceBefore = address(this).balance;
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap, amountOutMin, path, address(this), deadline
        );
        uint256 ethReceived = address(this).balance - balanceBefore;

        accumulatedEthRewards += ethReceived;
        emit SwapbackExecuted(amountToSwap, ethReceived);

        inSwapback = false;

        // Auto-deposit ETH to jackpot
        _depositEthToJackpot();
    }

    /// @notice Retry failed accrue() calls for a given contract
    /// @dev Can be called by anyone to retry failed accruals
    /// @dev This helps fix accounting drift when accrue() calls fail during minting
    /// @param contractAddress The contract address to retry accrual for (teamVesting or growthFund)
    /// @return success Whether the retry was successful
    function retryAccrue(address contractAddress) external nonReentrant returns (bool success) {
        uint256 pendingAmount = pendingAccruals[contractAddress];
        require(pendingAmount > 0, "no pending accrual");
        
        // Only allow retrying for team vesting or growth fund
        require(
            contractAddress == teamVesting || contractAddress == growthFund,
            "invalid contract"
        );
        
        // Reset pending amount before retry (will restore if retry fails)
        pendingAccruals[contractAddress] = 0;
        
        // Retry accrue call
        (success,) = contractAddress.call(
            abi.encodeWithSignature("accrue(uint256)", pendingAmount)
        );
        
        if (success) {
            emit AccrueRetried(contractAddress, pendingAmount, true);
        } else {
            // Restore pending amount if retry failed
            pendingAccruals[contractAddress] = pendingAmount;
            emit AccrueRetried(contractAddress, pendingAmount, false);
        }
    }

    /// @notice Manual deposit of accumulated ETH rewards into jackpot
    /// @dev Usually called automatically, but can be called manually if needed
    function depositEthToJackpot() external nonReentrant {
        require(jackpotRecipient != address(0), "jackpot not set");
        require(accumulatedEthRewards > 0, "no rewards");
        require(!inSwapback, "swapback in progress");

        uint256 amount = accumulatedEthRewards;
        accumulatedEthRewards = 0;

        // Call addEthToJackpot() on the lottery contract with ETH
        (bool success,) =
            payable(jackpotRecipient).call{value: amount}(abi.encodeWithSignature("addEthToJackpot()"));
        require(success, "deposit failed");

        emit EthDepositedToJackpot(amount);
    }

    /// @notice Override _update to apply the flat (decrease-only) tax on taxed-pool trades only
    /// @dev Tax only applies to transfers involving the Uniswap V2 pair (buy/sell)
    /// @dev Automatically triggers swapback and deposit when threshold is met
    function _update(address from, address to, uint256 value) internal override {
        if (inSwapback) {
            super._update(from, to, value);
            return;
        }
        
        // Tax only applies to trades against a taxed pool (any registered venue, plus the legacy pair)
        // Buy:  from is a taxed pool (pool sends SLVR to user)
        // Sell: to   is a taxed pool (user sends SLVR to pool)
        bool isBuy = _isTaxedPool(from);
        bool isSell = _isTaxedPool(to);
        bool isUniswapV2Trade = isBuy || isSell;

        // On a sell, try to process accumulated tax — via the pluggable handler if set, else the
        // built-in V2 route. _trySwapback re-checks all conditions (threshold, interval).
        if (
            !inSwapback &&
            isSell &&
            (taxHandler != address(0) || (address(swapRouter) != address(0) && pairToken != address(0)))
        ) {
            _trySwapback();
        }
        
        // Skip tax for minting, burning, or exempt addresses
        if (from == address(0) || to == address(0) || isTaxExempt[from] || isTaxExempt[to]) {
            super._update(from, to, value);
            return;
        }
        
        if (!isUniswapV2Trade) {
            // Not a UniswapV2 trade, no tax
            super._update(from, to, value);
            return;
        }

        // Check if sender is exempt from sell tax (for liquidity operations)
        // This allows liquidity zaps to pay buy tax on swaps but skip sell tax on liquidity adds
        if (!isBuy && isSellTaxExempt[from]) {
            // This is a sell, but sender is exempt from sell tax - skip tax
            super._update(from, to, value);
            return;
        }
        
        // Get base tax rate (manual setting)
        uint16 baseTaxBps = isBuy ? buyTaxBps : sellTaxBps;
        
        // Effective tax rate (flat base rate; decrease-only)
        uint16 taxRateBps = getEffectiveTaxRate(baseTaxBps);

        // If tax is 0, skip tax calculation
        if (taxRateBps == 0) {
            super._update(from, to, value);
            return;
        }

        uint256 tax = (value * taxRateBps) / 10000;
        uint256 transferAmount = value - tax;
        
        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= value, "ERC20: insufficient balance for transfer with tax");

        // Transfer amount minus tax to recipient
        super._update(from, to, transferAmount);

        if (tax > 0) {
            super._update(from, address(this), tax);
            emit TaxCollected(from, tax, taxRateBps, isBuy);

            accumulatedTax += tax;
            
            if (lastSwapbackTime == 0 && accumulatedTax >= swapbackThreshold) {
                lastSwapbackTime = block.timestamp;
            }
        }
    }

    /// @notice Allow contract to receive native tokens (ETH)
    receive() external payable {}
}
