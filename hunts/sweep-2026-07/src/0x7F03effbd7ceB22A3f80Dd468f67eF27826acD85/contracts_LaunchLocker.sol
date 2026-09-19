// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

library LauncherTypes {
    struct LaunchedToken {
        address token;
        address deployer;
        address pairedToken;
        address positionManager;
        uint256 positionId;
        uint256 dexId;
        uint256 launchConfigId;
        uint256 restrictionsEndBlock;
        uint256 supply;
        bool isToken0;
        uint24 poolFee;
        bool exists;
        uint256 initialBuyAmount;
    }
}

interface ILaunchFactory {
    function getLaunchedToken(address token) external view returns (LauncherTypes.LaunchedToken memory);
}

interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function ownerOf(uint256 tokenId) external view returns (address);

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

    function collect(CollectParams calldata params) external returns (uint256 amount0, uint256 amount1);
}

contract LaunchLocker is Ownable, ReentrancyGuard, IERC721Receiver {
    error AlreadyInitialized();
    error InvalidProtocolFee();
    error NoFeesToCollect();
    error NotAuthorized();
    error NotDeployer();
    error NotFactory();
    error PositionNotHeld();
    error TokenNotFound();
    error ZeroAddress();

    event FactoryUpdated(address indexed newFactory);
    event FeeCollectorUpdated(address indexed collector, bool status);
    event FeeRedirectUpdated(address indexed token, address indexed recipient);
    event FeesClaimed(
        address indexed token,
        address indexed caller,
        address token0,
        address token1,
        uint256 recipientAmount0,
        uint256 recipientAmount1,
        uint256 protocolAmount0,
        uint256 protocolAmount1
    );
    event PositionLocked(
        address indexed token,
        address indexed deployer,
        uint256 positionId,
        address pairedToken,
        uint256 indexed dexId,
        address positionManager
    );
    event ProtocolFeeRecipientUpdated(address newRecipient);
    event ProtocolFeeUpdated(uint256 newFee);

    uint256 public protocolFeeShare;
    address public protocolFeeRecipient;
    address public factory;

    mapping(address => address[]) public deployerTokens;
    mapping(address => bool) public feeCollectors;
    mapping(address => address) public feeRedirects;

    constructor(address _protocolFeeRecipient, uint256 _protocolFeeShare) Ownable(msg.sender) {
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();
        if (_protocolFeeShare > 100) revert InvalidProtocolFee();

        protocolFeeRecipient = _protocolFeeRecipient;
        protocolFeeShare = _protocolFeeShare;
    }

    function initialize(address _factory) external onlyOwner {
        if (_factory == address(0)) revert ZeroAddress();
        if (factory != address(0)) revert AlreadyInitialized();

        factory = _factory;
        emit FactoryUpdated(_factory);
    }

    function getLaunchedToken(address token) public view returns (LauncherTypes.LaunchedToken memory) {
        return ILaunchFactory(factory).getLaunchedToken(token);
    }

    function onERC721Received(address, address from, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (from != factory) revert NotFactory();
        return IERC721Receiver.onERC721Received.selector;
    }

    function lockPosition(address token) external {
        if (msg.sender != factory) revert NotFactory();

        LauncherTypes.LaunchedToken memory launched = ILaunchFactory(factory).getLaunchedToken(token);
        if (!launched.exists || launched.token == address(0)) revert TokenNotFound();
        if (
            launched.deployer == address(0) || launched.pairedToken == address(0)
                || launched.positionManager == address(0) || launched.token != token
        ) revert TokenNotFound();

        if (INonfungiblePositionManager(launched.positionManager).ownerOf(launched.positionId) != address(this)) {
            revert PositionNotHeld();
        }

        deployerTokens[launched.deployer].push(token);
        emit PositionLocked(
            token,
            launched.deployer,
            launched.positionId,
            launched.pairedToken,
            launched.dexId,
            launched.positionManager
        );
    }

    function collectFees(address token) external nonReentrant {
        LauncherTypes.LaunchedToken memory launched = ILaunchFactory(factory).getLaunchedToken(token);
        if (!launched.exists) revert TokenNotFound();
        if (msg.sender != owner() && msg.sender != launched.deployer && !feeCollectors[msg.sender]) {
            revert NotAuthorized();
        }

        INonfungiblePositionManager manager = INonfungiblePositionManager(launched.positionManager);
        (uint256 amount0, uint256 amount1) = manager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: launched.positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (amount0 == 0 && amount1 == 0) revert NoFeesToCollect();

        (,, address token0, address token1,,,,,,,,) = manager.positions(launched.positionId);

        uint256 protocolAmount0 = (amount0 * protocolFeeShare) / 100;
        uint256 protocolAmount1 = (amount1 * protocolFeeShare) / 100;
        uint256 recipientAmount0 = amount0 - protocolAmount0;
        uint256 recipientAmount1 = amount1 - protocolAmount1;

        address recipient = feeRedirects[token] != address(0) ? feeRedirects[token] : launched.deployer;

        if (amount0 != 0) {
            IERC20(token0).transfer(protocolFeeRecipient, protocolAmount0);
            IERC20(token0).transfer(recipient, recipientAmount0);
        }
        if (amount1 != 0) {
            IERC20(token1).transfer(protocolFeeRecipient, protocolAmount1);
            IERC20(token1).transfer(recipient, recipientAmount1);
        }

        emit FeesClaimed(
            token,
            msg.sender,
            token0,
            token1,
            recipientAmount0,
            recipientAmount1,
            protocolAmount0,
            protocolAmount1
        );
    }

    function setFeeRedirect(address token, address recipient) external {
        LauncherTypes.LaunchedToken memory launched = ILaunchFactory(factory).getLaunchedToken(token);
        if (!launched.exists) revert TokenNotFound();
        if (msg.sender != launched.deployer) revert NotDeployer();

        feeRedirects[token] = recipient;
        emit FeeRedirectUpdated(token, recipient);
    }

    function setFeeCollector(address collector, bool status) external onlyOwner {
        if (collector == address(0)) revert ZeroAddress();
        feeCollectors[collector] = status;
        emit FeeCollectorUpdated(collector, status);
    }

    function setProtocolFeeShare(uint256 _protocolFeeShare) external onlyOwner {
        if (_protocolFeeShare > 100) revert InvalidProtocolFee();
        protocolFeeShare = _protocolFeeShare;
        emit ProtocolFeeUpdated(_protocolFeeShare);
    }

    function setProtocolFeeRecipient(address _protocolFeeRecipient) external onlyOwner {
        if (_protocolFeeRecipient == address(0)) revert ZeroAddress();
        protocolFeeRecipient = _protocolFeeRecipient;
        emit ProtocolFeeRecipientUpdated(_protocolFeeRecipient);
    }
}
