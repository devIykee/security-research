// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HoodTechConfig, HoodTechConstants} from "./HoodTechConfig.sol";
import {PriceMath} from "../libraries/PriceMath.sol";
import {IHoodTechFactory} from "../interfaces/IHoodTechFactory.sol";
import {INonfungiblePositionManager, IWETH9} from "../interfaces/IUniswapV3.sol";

/**
 * @title HoodTechPositions
 * @notice Permanent locker for every launch's Uniswap V3 liquidity.
 *         Each launch's single-sided position NFT is minted to this contract and
 *         can never leave it — liquidity is locked for good. The only extractable
 *         value is the 1% trading fee, which anyone can poke via collectFees();
 *         each collection is split 50/50 between the token's creator wallet and
 *         the protocol treasury, claimable pull-style by each side independently.
 */
contract HoodTechPositions is ReentrancyGuard {
    IHoodTechFactory public immutable factory;
    HoodTechConfig public immutable config;
    INonfungiblePositionManager public immutable positionManager;
    IWETH9 public immutable weth;

    /// @notice V3 position NFT id per launched token (0 = not minted).
    mapping(address => uint256) public positionIdByToken;

    /// @notice Unclaimed native-ETH fee share per (token, recipient).
    mapping(address => mapping(address => uint256)) public pendingETH;
    /// @notice Unclaimed token fee share per (token, recipient).
    mapping(address => mapping(address => uint256)) public pendingToken;

    event PositionMinted(address indexed token, uint256 indexed positionId, uint128 liquidity);
    event FeesCollected(address indexed token, uint256 ethGained, uint256 tokenGained);
    event FeesAccrued(address indexed token, address indexed recipient, uint256 ethAmount, uint256 tokenAmount);
    event FeesClaimed(address indexed token, address indexed recipient, uint256 ethAmount, uint256 tokenAmount);

    constructor(
        IHoodTechFactory _factory,
        HoodTechConfig _config,
        INonfungiblePositionManager _positionManager,
        IWETH9 _weth
    ) {
        factory = _factory;
        config = _config;
        positionManager = _positionManager;
        weth = _weth;
    }

    /**
     * @notice Mint the single-sided launch position holding the entire token
     *         supply. Factory-only, called atomically inside createLaunch after
     *         the supply arrives. Zero WETH goes in.
     */
    function mintPosition(address token) external nonReentrant {
        require(msg.sender == address(factory), "Only factory");
        require(positionIdByToken[token] == 0, "Position already minted");

        (address pool, , bool tokenIsToken0) = factory.getLaunchBasics(token);
        require(pool != address(0), "Unknown token");

        (int24 tickLower, int24 tickUpper) = PriceMath.positionRange(
            HoodTechConstants.STARTING_MCAP_ETH,
            HoodTechConstants.TOTAL_SUPPLY,
            tokenIsToken0,
            HoodTechConstants.TICK_SPACING
        );

        uint256 supply = IERC20(token).balanceOf(address(this));
        IERC20(token).approve(address(positionManager), supply);

        (uint256 tokenId, uint128 liquidity,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: tokenIsToken0 ? token : address(weth),
                token1: tokenIsToken0 ? address(weth) : token,
                fee: HoodTechConstants.POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: tokenIsToken0 ? supply : 0,
                amount1Desired: tokenIsToken0 ? 0 : supply,
                amount0Min: 0, // pool created+initialized this same tx; price cannot have moved
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
        positionIdByToken[token] = tokenId;

        emit PositionMinted(token, tokenId, liquidity);
    }

    /**
     * @notice Harvest accrued 1% trading fees for a launch. Callable by anyone
     *         (the TG bot pokes it); proceeds are accrued 50% to the creator
     *         wallet, 50% to the protocol treasury.
     */
    function collectFees(address token) external nonReentrant {
        (address pool, address beneficiary, bool tokenIsToken0) = factory.getLaunchBasics(token);
        require(pool != address(0), "Unknown token");
        uint256 tokenId = positionIdByToken[token];
        require(tokenId != 0, "No position");

        (uint256 amount0, uint256 amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        (uint256 ethGained, uint256 tokenGained) = tokenIsToken0 ? (amount1, amount0) : (amount0, amount1);

        if (ethGained > 0) {
            weth.withdraw(ethGained);
            _accrue(token, beneficiary, ethGained, true);
        }
        if (tokenGained > 0) {
            _accrue(token, beneficiary, tokenGained, false);
        }

        emit FeesCollected(token, ethGained, tokenGained);
    }

    /// @notice Claim the caller's accrued creator-fee share for a token. The
    ///         protocol share is auto-sent to the treasury at collect time, so
    ///         only creators (and, as a fallback, the treasury if a push ever
    ///         failed) ever have a balance here.
    function claim(address token) external nonReentrant returns (uint256 ethAmount, uint256 tokenAmount) {
        ethAmount = pendingETH[token][msg.sender];
        tokenAmount = pendingToken[token][msg.sender];
        require(ethAmount > 0 || tokenAmount > 0, "Nothing to claim");

        if (ethAmount > 0) {
            pendingETH[token][msg.sender] = 0;
            (bool ok,) = msg.sender.call{value: ethAmount}("");
            require(ok, "Claim ETH transfer failed");
        }
        if (tokenAmount > 0) {
            pendingToken[token][msg.sender] = 0;
            IERC20(token).transfer(msg.sender, tokenAmount);
        }

        emit FeesClaimed(token, msg.sender, ethAmount, tokenAmount);
    }

    /// @dev Fixed 50/50: protocol treasury takes PROTOCOL_SHARE_BPS, creator the rest.
    ///      The treasury share is pushed straight to the treasury (passive multisig).
    ///      If the ETH push ever fails, it falls back to a claimable balance so a
    ///      misconfigured treasury can never brick collection for the creator.
    ///      The creator share is always pull-based (creators may be arbitrary addresses).
    function _accrue(address token, address beneficiary, uint256 amount, bool isEth) internal {
        uint256 protocolShare = (amount * HoodTechConstants.PROTOCOL_SHARE_BPS) / HoodTechConstants.BPS;
        uint256 creatorShare = amount - protocolShare;
        address treasury = config.treasury();

        if (isEth) {
            if (protocolShare > 0) {
                (bool ok,) = treasury.call{value: protocolShare}("");
                if (!ok) pendingETH[token][treasury] += protocolShare; // fallback to pull
            }
            if (creatorShare > 0) pendingETH[token][beneficiary] += creatorShare;
            emit FeesAccrued(token, treasury, protocolShare, 0);
            emit FeesAccrued(token, beneficiary, creatorShare, 0);
        } else {
            if (protocolShare > 0) IERC20(token).transfer(treasury, protocolShare); // push tokens
            if (creatorShare > 0) pendingToken[token][beneficiary] += creatorShare;
            emit FeesAccrued(token, treasury, 0, protocolShare);
            emit FeesAccrued(token, beneficiary, 0, creatorShare);
        }
    }

    function claimable(address token, address recipient)
        external
        view
        returns (uint256 ethAmount, uint256 tokenAmount)
    {
        return (pendingETH[token][recipient], pendingToken[token][recipient]);
    }

    /// @dev Accepts ETH from WETH.withdraw only.
    receive() external payable {
        require(msg.sender == address(weth), "Direct ETH not accepted");
    }
}
