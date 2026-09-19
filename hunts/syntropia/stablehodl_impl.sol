//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract stake_pool is AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable  {
    using SafeERC20 for IERC20;


    struct StakedInfo {
        address user;
        address token;
        uint256 amount;
        uint256 time;
    }

    address public masterAddress;
    mapping(address => mapping(address => uint256)) public userStakedTokenAmounts;
    mapping(address => StakedInfo[]) public stakedInfos;
    mapping(address => uint256) public userAmounts;
    mapping(address => uint256) public poolTokenAmounts;
    uint256 public poolCount;
    uint256 public poolAmount;
    mapping(address => bool) public whitelistTokens;

    bytes32 public constant MOD_ROLE = keccak256("MOD_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");


    event Deposit(
        address indexed sender,
        address indexed token,
        uint256 indexed amount,
        uint256 stakedAmounts,
        uint256 time
    );

    event Withdraw(
        address indexed sender,
        address indexed token,
        uint256 indexed amount,
        uint256 time
    );

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}


    function initialize(address _masterAddress, address _tetherToken, address _circleToken) public initializer {

        require(_masterAddress != address(0), '_masterAddress is zero address');
        require(_tetherToken != address(0), '_tetherToken is zero address');
        require(_circleToken != address(0), '_circleToken is zero address');

        masterAddress = _masterAddress;
        whitelistTokens[_tetherToken] = true;
        whitelistTokens[_circleToken] = true;

        address admin = address(0x3669baBd47438aC32621cBD83f13E8d0c8052660);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MOD_ROLE, admin);
        _grantRole(SUPER_ADMIN_ROLE, admin);

        _setRoleAdmin(MOD_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, SUPER_ADMIN_ROLE);
        __UUPSUpgradeable_init();
    }

    receive() external payable {}


    function setMasterAddress(address _masterAddress) external onlyRole(MOD_ROLE) {
        require(_masterAddress != address(0), '_masterAddress is zero address');
        masterAddress = _masterAddress;
    }


    function setWhitelistToken(address _token, bool status) external onlyRole(MOD_ROLE) {
        require(_token != address(0), '_wallet is zero address');
        whitelistTokens[_token] = status;
    }


    function emergencyWithdraw(address _token, address _to, uint256 _amount) external onlyRole(ADMIN_ROLE) {
        if (address(this).balance > 0) {
            payable(_to).transfer(address(this).balance);
        }
        if (_token != address(0)) {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }


    function deposit(address _token, uint256 _amount) external whenNotPaused {
        require(masterAddress != address(0), 'Invalid masterAddress');
        require(whitelistTokens[_token], 'Invalid Deposit Token');
        require(_amount > 0, 'Invalid _Amount');

        if (userAmounts[msg.sender] == 0) {
            poolCount += 1;
        }


        userAmounts[msg.sender] += _amount;
        userStakedTokenAmounts[msg.sender][_token] += _amount;

        StakedInfo memory stakedInfo;
        stakedInfo.user = msg.sender;
        stakedInfo.token = _token;
        stakedInfo.amount = _amount;
        stakedInfo.time = block.timestamp;
        stakedInfos[msg.sender].push(stakedInfo);


        poolAmount += _amount;
        poolTokenAmounts[_token] += _amount;

        IERC20(_token).safeTransferFrom(msg.sender, masterAddress, _amount);


        emit Deposit(
            msg.sender,
            _token,
            _amount,
            userStakedTokenAmounts[msg.sender][_token],
            block.timestamp
        );
    }

    function getPoolBalance(address _token) external view returns (uint256) {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        return balance;
    }

    function getUserStakedNumber(address _user) external view returns (uint256) {
        return stakedInfos[_user].length;
    }
}
