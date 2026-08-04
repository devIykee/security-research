// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC20 interface (inlined, no external imports).
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Price oracle interface returning a USD price scaled to 1e18.
interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}

/// @notice Optional "support the builder" base contract.
abstract contract Supportable {
    address public immutable builder;

    event Support(address indexed from, uint256 amount, string note);

    constructor() {
        builder = msg.sender;
    }

    function support(string calldata note) external payable {
        require(msg.value > 0, "empty");
        (bool ok, ) = builder.call{value: msg.value}("");
        require(ok, "fwd");
        emit Support(msg.sender, msg.value, note);
    }
}

/// @notice SPHYNX USD — minimal ERC20 stablecoin. Only the minter (the CdpEngine) can mint/burn.
contract Stablecoin is IERC20 {
    string public constant name = "xStocks USD";
    string public constant symbol = "xUSD";
    uint8 public constant decimals = 18;

    address public immutable minter;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyMinter() {
        require(msg.sender == minter, "not minter");
        _;
    }

    constructor() {
        minter = msg.sender;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        require(spender != address(0), "approve to zero");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "insufficient allowance");
        if (allowed != type(uint256).max) {
            _allowances[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "transfer to zero");
        uint256 bal = _balances[from];
        require(bal >= amount, "insufficient balance");
        unchecked {
            _balances[from] = bal - amount;
        }
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "mint to zero");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        uint256 bal = _balances[from];
        require(bal >= amount, "burn exceeds balance");
        unchecked {
            _balances[from] = bal - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}

/// @notice Single-collateral CDP stablecoin engine (MakerDAO/Liquity-style).
/// @dev Assumes collateral token has 18 decimals and oracle prices are 1e18-scaled USD.
contract CdpEngine is Supportable {
    struct Vault {
        uint256 collateral; // amount of collateral token deposited (18 decimals)
        uint256 debt;       // sphUSD debt (18 decimals)
    }

    uint256 private constant BPS = 10000;
    uint256 private constant WAD = 1e18;

    address public immutable owner;
    IERC20 public immutable collateralToken;
    IPriceOracle public immutable oracle;
    Stablecoin public immutable stableToken;

    uint256 public minCollateralRatioBps; // e.g. 15000 = 150%
    uint256 public liquidationBonusBps;    // e.g. 1000 = 10%
    uint256 public borrowFeeBps;           // fixed borrow fee in bps (optional, may be 0)

    mapping(address => Vault) private vaults;

    // Reentrancy guard
    uint256 private _locked = 1;

    event ParamsUpdated(uint256 minCollateralRatioBps, uint256 liquidationBonusBps, uint256 borrowFeeBps);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Mint(address indexed user, uint256 amount, uint256 fee);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

    modifier nonReentrant() {
        require(_locked == 1, "reentrant");
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address collateralToken_, address oracle_) {
        require(collateralToken_ != address(0), "collateral zero");
        require(oracle_ != address(0), "oracle zero");
        owner = msg.sender;
        collateralToken = IERC20(collateralToken_);
        oracle = IPriceOracle(oracle_);
        // Engine deploys its own Stablecoin so that this engine is the sole minter.
        stableToken = new Stablecoin();

        minCollateralRatioBps = 15000; // 150%
        liquidationBonusBps = 1000;    // 10%
        borrowFeeBps = 0;
        emit ParamsUpdated(minCollateralRatioBps, liquidationBonusBps, borrowFeeBps);
    }

    /// @notice Address of the sphUSD stablecoin minted by this engine.
    function stable() external view returns (address) {
        return address(stableToken);
    }

    // --- Owner configuration ---

    function setParams(
        uint256 minCollateralRatioBps_,
        uint256 liquidationBonusBps_,
        uint256 borrowFeeBps_
    ) external onlyOwner {
        require(minCollateralRatioBps_ >= BPS, "min ratio < 100%");
        require(liquidationBonusBps_ <= BPS, "bonus too high");
        require(borrowFeeBps_ <= BPS, "fee too high");
        minCollateralRatioBps = minCollateralRatioBps_;
        liquidationBonusBps = liquidationBonusBps_;
        borrowFeeBps = borrowFeeBps_;
        emit ParamsUpdated(minCollateralRatioBps_, liquidationBonusBps_, borrowFeeBps_);
    }

    // --- Views ---

    function vault(address user) external view returns (uint256 collateral, uint256 debt) {
        Vault storage v = vaults[user];
        return (v.collateral, v.debt);
    }

    /// @notice Collateral ratio in bps. Returns max uint if debt == 0.
    function collateralRatio(address user) public view returns (uint256) {
        Vault storage v = vaults[user];
        if (v.debt == 0) return type(uint256).max;
        return _ratioBps(v.collateral, v.debt);
    }

    /// @dev ratioBps = collateral * price * BPS / (debt * WAD).
    /// price is 1e18 USD per collateral unit; collateral & debt are 18 decimals.
    function _ratioBps(uint256 collateral, uint256 debt) internal view returns (uint256) {
        if (debt == 0) return type(uint256).max;
        uint256 price = oracle.getPrice(address(collateralToken));
        require(price > 0, "bad price");
        // collateral (1e18) * price (1e18) = value scaled 1e36; divide by WAD -> USD value 1e18.
        uint256 collateralValue = (collateral * price) / WAD; // 1e18 USD
        return (collateralValue * BPS) / debt;
    }

    // --- User actions ---

    /// @notice Deposit collateral into the caller's vault (open or add).
    function deposit(uint256 collateralAmount) external nonReentrant {
        require(collateralAmount > 0, "zero amount");
        vaults[msg.sender].collateral += collateralAmount;
        _pullCollateral(msg.sender, collateralAmount);
        emit Deposit(msg.sender, collateralAmount);
    }

    /// @notice Alias for deposit — opens or tops up a vault.
    function openVault(uint256 collateralAmount) external nonReentrant {
        require(collateralAmount > 0, "zero amount");
        vaults[msg.sender].collateral += collateralAmount;
        _pullCollateral(msg.sender, collateralAmount);
        emit Deposit(msg.sender, collateralAmount);
    }

    /// @notice Mint sphUSD against deposited collateral if resulting ratio >= min.
    function mint(uint256 stableAmount) external nonReentrant {
        require(stableAmount > 0, "zero amount");
        Vault storage v = vaults[msg.sender];

        uint256 fee = (stableAmount * borrowFeeBps) / BPS;
        uint256 newDebt = v.debt + stableAmount + fee;

        require(_ratioBps(v.collateral, newDebt) >= minCollateralRatioBps, "undercollateralized");

        v.debt = newDebt;
        // Mint requested amount to the user; fee accrues as extra debt only.
        stableToken.mint(msg.sender, stableAmount);
        emit Mint(msg.sender, stableAmount, fee);
    }

    /// @notice Repay (burn) sphUSD debt from the caller's vault.
    function repay(uint256 stableAmount) external nonReentrant {
        require(stableAmount > 0, "zero amount");
        Vault storage v = vaults[msg.sender];
        require(v.debt > 0, "no debt");

        uint256 amount = stableAmount > v.debt ? v.debt : stableAmount;
        v.debt -= amount;
        stableToken.burn(msg.sender, amount);
        emit Repay(msg.sender, amount);
    }

    /// @notice Withdraw collateral if the vault stays >= min ratio (or debt is zero).
    function withdraw(uint256 collateralAmount) external nonReentrant {
        require(collateralAmount > 0, "zero amount");
        Vault storage v = vaults[msg.sender];
        require(v.collateral >= collateralAmount, "insufficient collateral");

        uint256 newCollateral = v.collateral - collateralAmount;
        if (v.debt > 0) {
            require(_ratioBps(newCollateral, v.debt) >= minCollateralRatioBps, "would undercollateralize");
        }

        v.collateral = newCollateral;
        _pushCollateral(msg.sender, collateralAmount);
        emit Withdraw(msg.sender, collateralAmount);
    }

    /// @notice Liquidate an unsafe vault: liquidator burns sphUSD to cover debt and seizes
    ///         collateral plus a bonus. Repays as much debt as the collateral (incl. bonus) allows.
    function liquidate(address user) external nonReentrant {
        Vault storage v = vaults[user];
        require(v.debt > 0, "no debt");
        require(_ratioBps(v.collateral, v.debt) < minCollateralRatioBps, "vault healthy");

        uint256 price = oracle.getPrice(address(collateralToken));
        require(price > 0, "bad price");

        uint256 debt = v.debt;
        uint256 collateral = v.collateral;

        // Collateral (18d) required to cover `debt` USD plus bonus, at current price.
        // collateralForDebt = debt * WAD / price  (USD 1e18 -> collateral 1e18)
        uint256 collateralForDebt = (debt * WAD) / price;
        uint256 seizeWithBonus = collateralForDebt + (collateralForDebt * liquidationBonusBps) / BPS;

        uint256 debtRepaid;
        uint256 collateralSeized;

        if (seizeWithBonus >= collateral) {
            // Not enough collateral to fully cover debt + bonus: seize all, repay proportional debt.
            collateralSeized = collateral;
            // Debt coverable by all collateral net of the bonus markup.
            // collateralForCoverable = collateral / (1 + bonus); debtCovered = collateralForCoverable * price / WAD
            uint256 coverableCollateral = (collateral * BPS) / (BPS + liquidationBonusBps);
            debtRepaid = (coverableCollateral * price) / WAD;
            if (debtRepaid > debt) debtRepaid = debt;
        } else {
            collateralSeized = seizeWithBonus;
            debtRepaid = debt;
        }

        require(debtRepaid > 0, "nothing to repay");

        // Effects
        v.debt = debt - debtRepaid;
        v.collateral = collateral - collateralSeized;

        // Interactions
        stableToken.burn(msg.sender, debtRepaid);
        _pushCollateral(msg.sender, collateralSeized);

        emit Liquidate(msg.sender, user, debtRepaid, collateralSeized);
    }

    // --- Internal token movement (checks-effects-interactions honored by callers) ---

    function _pullCollateral(address from, uint256 amount) internal {
        bool ok = collateralToken.transferFrom(from, address(this), amount);
        require(ok, "collateral pull failed");
    }

    function _pushCollateral(address to, uint256 amount) internal {
        bool ok = collateralToken.transfer(to, amount);
        require(ok, "collateral push failed");
    }
}
