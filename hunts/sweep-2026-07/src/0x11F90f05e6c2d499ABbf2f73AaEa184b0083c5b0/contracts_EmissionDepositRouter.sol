// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IForwarder} from "@opengsn/contracts/src/forwarder/IForwarder.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IEmissionDepositVoter {
    function forwarder() external view returns (address);

    function isGauge(address gauge) external view returns (bool);

    function isAlive(address gauge) external view returns (bool);

    function poolForGauge(address gauge) external view returns (address);

    function claimRewards(address[] calldata gauges) external;
}

/// @notice Claims one gauge's UP emissions and atomically sends the exact balance
///         increase to an immutable custody Safe while recording principal only.
/// @dev Rebate rates, boosts, caps, eligibility, and payout state are intentionally
///      offchain. One base unit of claimed UP is always recorded as one base unit.
contract EmissionDepositRouter is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant ROUTER_VERSION = 1;
    uint256 public constant MIN_FORWARD_GAS = 100_000;
    uint256 public constant MAX_FORWARD_GAS = 10_000_000;
    uint256 public constant MAX_VALIDITY_BLOCKS = 50_000;
    uint256 public constant EPOCH_DURATION = 1 weeks;

    string public constant FORWARD_DOMAIN_NAME = "UP Emission Deposit Router";
    string public constant FORWARD_DOMAIN_VERSION = "1";
    string public constant FORWARD_REQUEST_TYPE_NAME = "EmissionDeposit";
    string public constant FORWARD_REQUEST_TYPE_SUFFIX =
        "address router,address gauge,address pool,uint40 claimEpoch,address custodySafe)";

    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant FORWARD_REQUEST_TYPEHASH =
        keccak256(
            "EmissionDeposit(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntil,address router,address gauge,address pool,uint40 claimEpoch,address custodySafe)"
        );

    struct EpochAccounting {
        uint192 depositedUp;
        uint64 depositCount;
    }

    struct DepositRecord {
        address claimant;
        address gauge;
        address pool;
        uint128 amount;
        uint40 epoch;
        uint40 timestamp;
        bool gaugeAliveAtClaim;
        uint40 blockNumber;
    }

    IERC20 public immutable up;
    IEmissionDepositVoter public immutable voter;
    IForwarder public immutable forwarder;
    address public immutable custodySafe;
    bytes32 public immutable FORWARD_DOMAIN_SEPARATOR;

    uint256 public nextDepositId = 1;
    uint256 public totalDeposited;

    mapping(uint256 => DepositRecord) public deposits;
    mapping(address => uint256) public totalDepositedByClaimant;
    mapping(address => uint256) public totalDepositedByPool;
    mapping(address => uint256) public totalDepositedByGauge;
    mapping(uint256 => uint256) public totalDepositedByEpoch;
    mapping(address => mapping(uint256 => uint256)) public totalDepositedByPoolEpoch;
    mapping(address => mapping(uint256 => EpochAccounting)) public claimantEpochAccounting;
    mapping(address => mapping(address => mapping(uint256 => EpochAccounting))) public claimantPoolEpochAccounting;

    uint40[] private _depositEpochs;
    mapping(uint256 => bool) private _depositEpochSeen;
    mapping(uint256 => address[]) private _epochClaimants;
    mapping(uint256 => mapping(address => bool)) private _epochClaimantSeen;
    mapping(address => mapping(uint256 => address[])) private _claimantEpochPools;
    mapping(address => mapping(uint256 => mapping(address => bool))) private _claimantEpochPoolSeen;
    mapping(address => mapping(uint256 => uint256[])) private _claimantEpochDepositIds;

    error AmountTooLarge();
    error ClaimProducedNoUP();
    error CustodyBalanceMismatch();
    error CustodyMustBeContract();
    error ForwardedClaimFailed();
    error GaugeNotRecognized();
    error InvalidClaimData();
    error InvalidClaimEpoch();
    error InvalidForwardGas();
    error InvalidForwardNonce();
    error InvalidForwardRequest();
    error NativeTokenRejected();
    error NoTokensToSweep();
    error OwnershipRenunciationDisabled();
    error UntrustedForwarder();
    error ZeroAddress();

    event EpochClaimantRegistered(uint256 indexed epoch, address indexed claimant);
    event ClaimantEpochPoolRegistered(uint256 indexed epoch, address indexed claimant, address indexed pool);
    event EmissionDeposited(
        uint256 indexed depositId,
        address indexed claimant,
        address indexed pool,
        address gauge,
        uint256 amount,
        uint256 epoch,
        bool gaugeAliveAtClaim
    );
    event TokenSweptToCustody(address indexed token, uint256 amount);
    event NativeSweptToCustody(uint256 amount);

    constructor(address _up, address _voter, address _forwarder, address _custodySafe, address _owner) {
        if (
            _up == address(0) ||
            _voter == address(0) ||
            _forwarder == address(0) ||
            _custodySafe == address(0) ||
            _owner == address(0)
        ) revert ZeroAddress();
        if (_custodySafe.code.length == 0) revert CustodyMustBeContract();
        if (_custodySafe == _owner) revert InvalidForwardRequest();
        if (IEmissionDepositVoter(_voter).forwarder() != _forwarder) revert UntrustedForwarder();

        up = IERC20(_up);
        voter = IEmissionDepositVoter(_voter);
        forwarder = IForwarder(_forwarder);
        custodySafe = _custodySafe;

        FORWARD_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(FORWARD_DOMAIN_NAME)),
                keccak256(bytes(FORWARD_DOMAIN_VERSION)),
                block.chainid,
                _forwarder
            )
        );
        IForwarder(_forwarder).registerRequestType(FORWARD_REQUEST_TYPE_NAME, FORWARD_REQUEST_TYPE_SUFFIX);
        IForwarder(_forwarder).registerDomainSeparator(FORWARD_DOMAIN_NAME, FORWARD_DOMAIN_VERSION);

        _transferOwnership(_owner);
        _pause();
    }

    function claimAndDeposit(
        address gauge,
        address expectedPool,
        uint40 claimEpoch,
        IForwarder.ForwardRequest calldata request,
        bytes calldata signature
    ) external whenNotPaused nonReentrant returns (uint256 depositId) {
        return _claimAndDeposit(gauge, expectedPool, claimEpoch, request, signature);
    }

    /// @notice A copied permit that was mined first is accepted when its allowance remains sufficient.
    function claimAndDepositWithPermit(
        address gauge,
        address expectedPool,
        uint40 claimEpoch,
        IForwarder.ForwardRequest calldata request,
        bytes calldata signature,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused nonReentrant returns (uint256 depositId) {
        try
            IERC20Permit(address(up)).permit(request.from, address(this), permitValue, permitDeadline, v, r, s)
        {} catch {
            if (up.allowance(request.from, address(this)) < permitValue) revert InvalidForwardRequest();
        }
        return _claimAndDeposit(gauge, expectedPool, claimEpoch, request, signature);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function forwardSuffix(address gauge, address pool, uint40 claimEpoch) public view returns (bytes memory) {
        return abi.encode(address(this), gauge, pool, claimEpoch, custodySafe);
    }

    function currentEpoch() public view returns (uint40) {
        return uint40((block.timestamp / EPOCH_DURATION) * EPOCH_DURATION);
    }

    function depositEpochCount() external view returns (uint256) {
        return _depositEpochs.length;
    }

    function depositEpochAt(uint256 index) external view returns (uint40) {
        return _depositEpochs[index];
    }

    function epochClaimantCount(uint256 epoch) external view returns (uint256) {
        return _epochClaimants[epoch].length;
    }

    function epochClaimantAt(uint256 epoch, uint256 index) external view returns (address) {
        return _epochClaimants[epoch][index];
    }

    function claimantEpochPoolCount(address claimant, uint256 epoch) external view returns (uint256) {
        return _claimantEpochPools[claimant][epoch].length;
    }

    function claimantEpochPoolAt(address claimant, uint256 epoch, uint256 index) external view returns (address) {
        return _claimantEpochPools[claimant][epoch][index];
    }

    function claimantEpochDepositCount(address claimant, uint256 epoch) external view returns (uint256) {
        return _claimantEpochDepositIds[claimant][epoch].length;
    }

    function claimantEpochDepositIdAt(address claimant, uint256 epoch, uint256 index) external view returns (uint256) {
        return _claimantEpochDepositIds[claimant][epoch][index];
    }

    function custodyBalance() external view returns (uint256) {
        return up.balanceOf(custodySafe);
    }

    /// @notice Recovers accidental ERC-20 transfers only to the immutable custody Safe.
    function sweepTokenToCustody(address token) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) revert NoTokensToSweep();
        IERC20(token).safeTransfer(custodySafe, amount);
        emit TokenSweptToCustody(token, amount);
    }

    /// @notice Recovers forcibly sent native currency only to the immutable custody Safe.
    function sweepNativeToCustody() external nonReentrant {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoTokensToSweep();
        (bool success, ) = payable(custodySafe).call{value: amount}("");
        if (!success) revert NativeTokenRejected();
        emit NativeSweptToCustody(amount);
    }

    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenunciationDisabled();
    }

    receive() external payable {
        revert NativeTokenRejected();
    }

    function _claimAndDeposit(
        address gauge,
        address expectedPool,
        uint40 claimEpoch,
        IForwarder.ForwardRequest calldata request,
        bytes calldata signature
    ) private returns (uint256 depositId) {
        (address pool, bool gaugeAlive) = _validateClaim(gauge, expectedPool, claimEpoch, request);
        uint256 amount = _executeClaim(request, signature, forwardSuffix(gauge, pool, claimEpoch));
        _transferClaimToCustody(request.from, amount);
        return _recordDeposit(request.from, gauge, pool, amount, claimEpoch, gaugeAlive);
    }

    function _validateClaim(
        address gauge,
        address expectedPool,
        uint40 claimEpoch,
        IForwarder.ForwardRequest calldata request
    ) private view returns (address pool, bool gaugeAlive) {
        if (request.from == address(0) || request.to != address(voter) || request.value != 0) {
            revert InvalidForwardRequest();
        }
        if (request.nonce != forwarder.getNonce(request.from)) revert InvalidForwardNonce();
        if (
            request.validUntil == 0 ||
            request.validUntil <= block.number ||
            request.validUntil > block.number + MAX_VALIDITY_BLOCKS
        ) revert InvalidForwardRequest();
        if (request.gas < MIN_FORWARD_GAS || request.gas > MAX_FORWARD_GAS) revert InvalidForwardGas();
        if (claimEpoch != currentEpoch()) revert InvalidClaimEpoch();
        if (!voter.isGauge(gauge)) revert GaugeNotRecognized();

        pool = voter.poolForGauge(gauge);
        if (pool == address(0) || pool != expectedPool) revert GaugeNotRecognized();
        gaugeAlive = voter.isAlive(gauge);

        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        bytes memory expectedData = abi.encodeWithSelector(IEmissionDepositVoter.claimRewards.selector, gauges);
        if (keccak256(request.data) != keccak256(expectedData)) revert InvalidClaimData();
    }

    function _executeClaim(
        IForwarder.ForwardRequest calldata request,
        bytes calldata signature,
        bytes memory suffix
    ) private returns (uint256 amount) {
        uint256 balanceBefore = up.balanceOf(request.from);
        (bool success, bytes memory returnData) = forwarder.execute(
            request,
            FORWARD_DOMAIN_SEPARATOR,
            FORWARD_REQUEST_TYPEHASH,
            suffix,
            signature
        );
        if (!success) _revertForwardedCall(returnData);
        uint256 balanceAfter = up.balanceOf(request.from);
        if (balanceAfter <= balanceBefore) revert ClaimProducedNoUP();
        amount = balanceAfter - balanceBefore;
    }

    function _transferClaimToCustody(address claimant, uint256 amount) private {
        uint256 balanceBefore = up.balanceOf(custodySafe);
        up.safeTransferFrom(claimant, custodySafe, amount);
        uint256 balanceAfter = up.balanceOf(custodySafe);
        if (balanceAfter != balanceBefore + amount) revert CustodyBalanceMismatch();
    }

    function _recordDeposit(
        address claimant,
        address gauge,
        address pool,
        uint256 amount,
        uint40 epoch,
        bool gaugeAlive
    ) private returns (uint256 depositId) {
        if (amount > type(uint128).max) revert AmountTooLarge();
        depositId = nextDepositId++;
        deposits[depositId] = DepositRecord({
            claimant: claimant,
            gauge: gauge,
            pool: pool,
            amount: uint128(amount),
            epoch: epoch,
            timestamp: uint40(block.timestamp),
            gaugeAliveAtClaim: gaugeAlive,
            blockNumber: uint40(block.number)
        });

        totalDeposited += amount;
        totalDepositedByClaimant[claimant] += amount;
        totalDepositedByPool[pool] += amount;
        totalDepositedByGauge[gauge] += amount;
        totalDepositedByEpoch[epoch] += amount;
        totalDepositedByPoolEpoch[pool][epoch] += amount;
        _recordEpochDeposit(depositId, claimant, pool, epoch, amount);

        emit EmissionDeposited(depositId, claimant, pool, gauge, amount, epoch, gaugeAlive);
    }

    function _recordEpochDeposit(
        uint256 depositId,
        address claimant,
        address pool,
        uint256 epoch,
        uint256 amount
    ) private {
        if (!_depositEpochSeen[epoch]) {
            _depositEpochSeen[epoch] = true;
            _depositEpochs.push(uint40(epoch));
        }
        if (!_epochClaimantSeen[epoch][claimant]) {
            _epochClaimantSeen[epoch][claimant] = true;
            _epochClaimants[epoch].push(claimant);
            emit EpochClaimantRegistered(epoch, claimant);
        }
        if (!_claimantEpochPoolSeen[claimant][epoch][pool]) {
            _claimantEpochPoolSeen[claimant][epoch][pool] = true;
            _claimantEpochPools[claimant][epoch].push(pool);
            emit ClaimantEpochPoolRegistered(epoch, claimant, pool);
        }
        _claimantEpochDepositIds[claimant][epoch].push(depositId);

        EpochAccounting storage claimantAccount = claimantEpochAccounting[claimant][epoch];
        claimantAccount.depositedUp += uint192(amount);
        ++claimantAccount.depositCount;

        EpochAccounting storage poolAccount = claimantPoolEpochAccounting[claimant][pool][epoch];
        poolAccount.depositedUp += uint192(amount);
        ++poolAccount.depositCount;
    }

    function _revertForwardedCall(bytes memory returnData) private pure {
        if (returnData.length == 0) revert ForwardedClaimFailed();
        assembly {
            revert(add(returnData, 32), mload(returnData))
        }
    }
}
