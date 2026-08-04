// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {HoodTechToken} from "./HoodTechToken.sol";
import {HoodTechConfig, HoodTechConstants} from "./HoodTechConfig.sol";
import {PriceMath} from "../libraries/PriceMath.sol";
import {IUniswapV3Factory, IUniswapV3Pool, ISwapRouter02, IWETH9} from "../interfaces/IUniswapV3.sol";

interface IHoodTechPositionsMinter {
    function mintPosition(address token) external;
}

/**
 * @title HoodTechFactory
 * @notice One-transaction token launcher on Uniswap V3, mirroring the launch
 *         pattern proven live on Robinhood Chain:
 *         1. deploy a fixed-supply 1B token,
 *         2. create + initialize its token/WETH 1% pool at a 1 ETH market cap,
 *         3. put the ENTIRE supply into one single-sided V3 position held forever
 *            by the HoodTechPositions locker (no ETH seeded),
 *         4. optionally dev-buy for the creator with any ETH sent beyond the
 *            launch fee — all in the same transaction.
 *         The token is tradeable the moment createLaunch returns.
 */
contract HoodTechFactory is Ownable, ReentrancyGuard {
    struct LaunchInfo {
        address token;
        address pool;
        address creator;
        address beneficiary;
        bool tokenIsToken0;
        uint256 createdAt;
        uint256 createdBlock;
        string name;
        string symbol;
    }

    HoodTechConfig public immutable config;
    IUniswapV3Factory public immutable v3Factory;
    ISwapRouter02 public immutable swapRouter;
    IWETH9 public immutable weth;
    address public positions;

    uint256 public totalLaunches;
    mapping(address => LaunchInfo) internal _launches;
    address[] public allTokens;

    event TokenLaunched(
        address indexed token,
        address indexed pool,
        address indexed creator,
        address beneficiary,
        string name,
        string symbol
    );
    event DevBuy(address indexed token, address indexed creator, uint256 ethIn, uint256 tokensOut);

    constructor(
        HoodTechConfig _config,
        IUniswapV3Factory _v3Factory,
        ISwapRouter02 _swapRouter,
        IWETH9 _weth,
        address _owner
    ) Ownable(_owner) {
        config = _config;
        v3Factory = _v3Factory;
        swapRouter = _swapRouter;
        weth = _weth;
        // Guard against non-canonical forks: the 1% tier must use spacing 200.
        require(
            _v3Factory.feeAmountTickSpacing(HoodTechConstants.POOL_FEE) == HoodTechConstants.TICK_SPACING,
            "Unexpected tick spacing"
        );
    }

    /// @notice One-time wiring of the positions locker.
    function setPositions(address _positions) external onlyOwner {
        require(positions == address(0), "Positions already set");
        require(_positions != address(0), "Zero positions");
        positions = _positions;
    }

    /**
     * @notice Launch a token. msg.value must cover the launch fee; every wei
     *         above it is spent on a same-transaction dev buy for the caller.
     * @param name Token name (1-32 chars)
     * @param symbol Token symbol (1-10 chars)
     * @param beneficiary Wallet that receives the creator half of trading fees
     * @param salt Optional CREATE2 salt for a vanity token address (0 = plain deploy)
     */
    function createLaunch(
        string calldata name,
        string calldata symbol,
        address beneficiary,
        bytes32 salt
    ) external payable nonReentrant returns (address token, address pool) {
        require(!config.paused(), "Paused");
        require(positions != address(0), "Positions unset");
        require(bytes(name).length > 0 && bytes(name).length <= 32, "Invalid name");
        require(bytes(symbol).length > 0 && bytes(symbol).length <= 10, "Invalid symbol");
        require(beneficiary != address(0), "Zero beneficiary");

        uint256 launchFee = config.launchFee();
        require(msg.value >= launchFee, "Insufficient launch fee");

        token = _deployToken(name, symbol, beneficiary, salt);
        pool = _createPool(token);

        _launches[token] = LaunchInfo({
            token: token,
            pool: pool,
            creator: msg.sender,
            beneficiary: beneficiary,
            tokenIsToken0: token < address(weth),
            createdAt: block.timestamp,
            createdBlock: block.number,
            name: name,
            symbol: symbol
        });
        allTokens.push(token);
        totalLaunches++;

        emit TokenLaunched(token, pool, msg.sender, beneficiary, name, symbol);

        // Atomic liquidity bootstrap: entire supply into the locked single-sided
        // position. Zero ETH seeded — first buy moves price into the range.
        HoodTechToken(token).transfer(positions, HoodTechConstants.TOTAL_SUPPLY);
        IHoodTechPositionsMinter(positions).mintPosition(token);

        if (launchFee > 0) {
            (bool ok,) = config.treasury().call{value: launchFee}("");
            require(ok, "Fee transfer failed");
        }

        uint256 devBuyEth = msg.value - launchFee;
        if (devBuyEth > 0) {
            _devBuy(token, devBuyEth);
        }
    }

    function _deployToken(
        string calldata name,
        string calldata symbol,
        address beneficiary,
        bytes32 salt
    ) internal returns (address token) {
        if (salt != bytes32(0)) {
            token = address(new HoodTechToken{salt: salt}(name, symbol, address(this), beneficiary));
        } else {
            token = address(new HoodTechToken(name, symbol, address(this), beneficiary));
        }
    }

    function _createPool(address token) internal returns (address pool) {
        // A V3 pool can be created for any address pair by anyone. If someone
        // front-ran this predicted token address with a pool at a hostile price,
        // abort rather than launch into it (re-initialization is impossible).
        require(
            v3Factory.getPool(token, address(weth), HoodTechConstants.POOL_FEE) == address(0),
            "Pool pre-exists"
        );
        pool = v3Factory.createPool(token, address(weth), HoodTechConstants.POOL_FEE);

        uint160 sqrtPriceX96 = PriceMath.initialSqrtPrice(
            HoodTechConstants.STARTING_MCAP_ETH,
            HoodTechConstants.TOTAL_SUPPLY,
            token < address(weth),
            HoodTechConstants.TICK_SPACING
        );
        IUniswapV3Pool(pool).initialize(sqrtPriceX96);
    }

    /// @dev Swap the creator's extra ETH for tokens, output straight to the caller.
    ///      Atomic with pool creation, so no sandwich surface; minOut 0 is safe.
    function _devBuy(address token, uint256 ethAmount) internal {
        weth.deposit{value: ethAmount}();
        weth.approve(address(swapRouter), ethAmount);
        uint256 out = swapRouter.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(weth),
                tokenOut: token,
                fee: HoodTechConstants.POOL_FEE,
                recipient: msg.sender,
                amountIn: ethAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        emit DevBuy(token, msg.sender, ethAmount, out);
    }

    function getLaunchBasics(address token)
        external
        view
        returns (address pool, address beneficiary, bool tokenIsToken0)
    {
        LaunchInfo storage info = _launches[token];
        return (info.pool, info.beneficiary, info.tokenIsToken0);
    }

    function launchByToken(address token) external view returns (LaunchInfo memory) {
        return _launches[token];
    }

    function allTokensLength() external view returns (uint256) {
        return allTokens.length;
    }
}
