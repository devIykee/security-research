//       ╟╗                                                                      ╔╬
//       ╞╬╬                                                                    ╬╠╬
//      ╔╣╬╬╬                                                                  ╠╠╠╠╦
//     ╬╬╬╬╬╩                                                                  ╘╠╠╠╠╬
//    ║╬╬╬╬╬                                                                    ╘╠╠╠╠╬
//    ╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬      ╒╬╬╬╬╬╬╬╜   ╠╠╬╬╬╬╬╬╬         ╠╬╬╬╬╬╬╬    ╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╠
//    ╙╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╕    ╬╬╬╬╬╬╬╜   ╣╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬   ╬╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╩
//     ╙╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬  ╔╬╬╬╬╬╬╬    ╔╠╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬╬╬╬╬╠╠╠╠╝╙
//               ╘╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬    ╒╠╠╠╬╠╬╩╬╬╬╬╬╬       ╠╬╬╬╬╬╬╬╣╬╬╬╬╬╬╬╙
//                 ╣╬╬╬╬╬╬╬╬╬╬╠╣     ╣╬╠╠╠╬╩ ╚╬╬╬╬╬╬      ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                  ╣╬╬╬╬╬╬╬╬╬╣     ╣╬╠╠╠╬╬   ╣╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                   ╟╬╬╬╬╬╬╬╩      ╬╬╠╠╠╠╬╬╬╬╬╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╠╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╒╬╬╠╠╬╠╠╬╬╬╬╬╬╬╬╬╬╬╬    ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╬╬╬╠╠╠╠╝╝╝╝╝╝╝╠╬╬╬╬╬╬   ╠╬╬╬╬╬╬╬  ╚╬╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬    ╣╬╬╬╬╠╠╩       ╘╬╬╬╬╬╬╬  ╠╬╬╬╬╬╬╬   ╙╬╬╬╬╬╬╬╬
//

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {IERC20} from "contracts/interface/IERC20.sol";
import {SafeERC20} from "contracts/lib/SafeERC20.sol";
import {YakAdapter} from "contracts/YakAdapter.sol";
import {IAlgebraV2Adapter} from "contracts/interface/IAlgebraV2Adapter.sol";
import {IAlgebraV2Factory} from "contracts/interface/IAlgebraV2Factory.sol";
import {IAlgebraV2Pool} from "contracts/interface/IAlgebraV2Pool.sol";

contract AlgebraV2Adapter is YakAdapter, IAlgebraV2Adapter {
    using SafeERC20 for IERC20;

    uint160 internal constant MAX_SQRT_RATIO =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;
    uint160 internal constant MIN_SQRT_RATIO = 4_295_128_739;

    address public immutable FACTORY;
    address public immutable ROUTER;

    address public quoter;
    address public tempPoolAddress;
    uint256 public quoterGasLimit;

    address[] public deployers;
    mapping(address => bool) public isDeployer;

    constructor(
        string memory _name,
        uint256 _quoterGasLimit,
        address _router,
        address _quoter,
        address _factory
    ) YakAdapter(_name) {
        if (_factory == address(0) || _router == address(0)) revert AddressZero();
        FACTORY = _factory;
        ROUTER = _router;

        setQuoterGasLimit(_quoterGasLimit);
        setQuoter(_quoter);
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata)
        external
    {
        if (msg.sender != tempPoolAddress) revert NotPoolAddress();

        if (amount0Delta > 0) {
            IERC20(IAlgebraV2Pool(msg.sender).token0()).safeTransfer(msg.sender, uint256(amount0Delta));
        } else {
            IERC20(IAlgebraV2Pool(msg.sender).token1()).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    function setQuoter(address newQuoter) public onlyMaintainer {
        if (newQuoter == address(0)) revert AddressZero();
        quoter = newQuoter;
        emit QuoterSet(newQuoter);
    }

    function setQuoterGasLimit(uint256 newGasLimit) public onlyMaintainer {
        if (newGasLimit == 0) revert InvalidGasLimit();

        quoterGasLimit = newGasLimit;
        emit QuoterGasLimitSet(newGasLimit);
    }

    /// @inheritdoc IAlgebraV2Adapter
    function addCustomDeployer(address deployer) external onlyMaintainer {
        if (isDeployer[deployer]) revert DeployerAlreadyAdded();
        deployers.push(deployer);
        isDeployer[deployer] = true;
        emit DeployerAdded(deployer);
    }

    /// @inheritdoc IAlgebraV2Adapter
    function removeCustomDeployer(uint256 index) external onlyMaintainer {
        address deployer = deployers[index];
        isDeployer[deployer] = false;
        deployers[index] = deployers[deployers.length - 1];
        deployers.pop();
        emit DeployerRemoved(deployer);
    }

    function getQuoteForPool(
        address pool,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) external view returns (uint256) {
        QParams memory params;
        params.amount = exactIn ? int256(amount) : -int256(amount);
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.exactIn = exactIn;
        return getQuoteForPool(pool, params);
    }

    /// @inheritdoc IAlgebraV2Adapter
    function getDeployers() external view override returns (address[] memory) {
        return deployers;
    }

    function _query(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        internal
        view
        override
        returns (uint256, address)
    {
        QParams memory params = getQParams(_amount, _tokenIn, _tokenOut, _exactIn);
        (uint256 quote,) = getQuoteForBestPool(params);
        address recipient = address(this);

        return (quote, recipient);
    }

    function queryWithDeployer(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        external
        view
        returns (uint256, address, address)
    {
        QParams memory params = getQParams(_amount, _tokenIn, _tokenOut, _exactIn);
        (uint256 quote, address deployer) = getQuoteForBestPool(params);
        address recipient = address(this);

        return (quote, recipient, deployer);
    }

    function _swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal override {
        QParams memory params = getQParams(_amountIn, _tokenIn, _tokenOut, true);

        uint256 amountOutBefore = IERC20(_tokenOut).balanceOf(address(this));
        // Use address(0) as deployer for default pool
        uint256 amountOutAfter = _underlyingSwap(params, new bytes(0), address(0));
        uint256 amountOut = amountOutAfter - amountOutBefore;

        if (amountOut < _amountOut) revert InsufficientAmount();
        tempPoolAddress = address(0);

        uint256 remainingBalance = IERC20(_tokenIn).balanceOf(address(this));
        if (remainingBalance > 0) IERC20(_tokenIn).safeTransfer(ROUTER, remainingBalance);

        _returnTo(_tokenOut, amountOut, _to);
    }

    /**
     * @notice External swap function that accepts a deployer address for custom pools
     * @param _amountIn Amount of input tokens
     * @param _amountOut Minimum amount of output tokens expected
     * @param _tokenIn Address of input token
     * @param _tokenOut Address of output token
     * @param _to Address to receive output tokens
     * @param _deployer Address of the deployer for custom pool (address(0) for factory pool)
     */
    function swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to,
        address _deployer
    ) external {
        QParams memory params = getQParams(_amountIn, _tokenIn, _tokenOut, true);

        uint256 amountOutBefore = IERC20(_tokenOut).balanceOf(address(this));
        uint256 amountOutAfter = _underlyingSwap(params, new bytes(0), _deployer);
        uint256 amountOut = amountOutAfter - amountOutBefore;

        if (amountOut < _amountOut) revert InsufficientAmount();
        tempPoolAddress = address(0);

        _returnTo(_tokenOut, amountOut, _to);
        emit YakAdapterSwap(_tokenIn, _tokenOut, _amountIn, amountOut);
    }

    function getQParams(uint256 amount, address tokenIn, address tokenOut, bool exactIn)
        internal
        pure
        returns (QParams memory)
    {
        return QParams({
            amount: exactIn ? int256(amount) : -int256(amount),
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            exactIn: exactIn
        });
    }

    function _underlyingSwap(QParams memory params, bytes memory callbackData, address deployer)
        internal
        virtual
        returns (uint256)
    {
        // Use deployer if provided, otherwise use the factory pool
        if (deployer == address(0)) tempPoolAddress = getBestPool(params.tokenIn, params.tokenOut);
        else tempPoolAddress = getCustomPool(deployer, params.tokenIn, params.tokenOut);

        (bool zeroForOne, uint160 priceLimit) =
            getZeroOneAndSqrtPriceLimitX96(params.tokenIn, params.tokenOut);
        (int256 amount0, int256 amount1) = IAlgebraV2Pool(tempPoolAddress).swap(
            address(this), zeroForOne, int256(params.amount), priceLimit, callbackData
        );
        return zeroForOne ? uint256(-amount1) : uint256(-amount0);
    }

    function _underlyingSwap(QParams memory params, bytes memory callbackData)
        internal
        virtual
        returns (uint256)
    {
        return _underlyingSwap(params, callbackData, address(0));
    }

    function getQuoteForBestPool(QParams memory params) internal view returns (uint256, address) {
        uint256 quote;
        address bestDeployer = address(0); // Default for factory pool
        address bestPool = getBestPool(params.tokenIn, params.tokenOut);
        if (bestPool != address(0)) quote = getQuoteForPool(bestPool, params);

        uint256 deployersLength = deployers.length;

        for (uint256 i; i < deployersLength; ++i) {
            address customPool = getCustomPool(deployers[i], params.tokenIn, params.tokenOut);
            if (customPool != address(0)) {
                uint256 tempQuote = getQuoteForPool(customPool, params);
                bool isBetter = params.exactIn
                    ? tempQuote > quote
                    : (tempQuote != 0 && (quote == 0 || tempQuote < quote));
                if (isBetter) {
                    quote = tempQuote;
                    bestDeployer = deployers[i];
                }
            }
        }

        return (quote, bestDeployer);
    }

    /// @dev Returns the default pool address for a given token0 and token1 combination
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    function getBestPool(address token0, address token1) internal view returns (address) {
        return IAlgebraV2Factory(FACTORY).poolByPair(token0, token1);
    }

    /// @dev Returns a custom pool's address for a given deployer, token0 and token1 combination
    /// @param deployer Address of the deployer of the pool
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    function getCustomPool(address deployer, address token0, address token1)
        internal
        view
        returns (address)
    {
        return IAlgebraV2Factory(FACTORY).customPoolByPair(deployer, token0, token1);
    }

    function getQuoteForPool(address pool, QParams memory params) internal view returns (uint256) {
        (bool zeroForOne, uint160 priceLimit) =
            getZeroOneAndSqrtPriceLimitX96(params.tokenIn, params.tokenOut);
        (int256 amount0, int256 amount1) = getQuoteSafe(pool, zeroForOne, params.amount, priceLimit);
        return params.exactIn
            ? (zeroForOne ? uint256(-amount1) : uint256(-amount0))
            : (zeroForOne ? uint256(amount0) : uint256(amount1));
    }

    function getQuoteSafe(address pool, bool zeroForOne, int256 amount, uint160 priceLimit)
        internal
        view
        returns (int256, int256)
    {
        bytes memory calldata_ = abi.encodeWithSignature(
            "quote(address,bool,int256,uint160)", pool, zeroForOne, amount, priceLimit
        );
        (bool success, bytes memory data) = staticCallQuoterRaw(calldata_);

        int256 amount0;
        int256 amount1;
        if (success) (amount0, amount1) = abi.decode(data, (int256, int256));

        return (amount0, amount1);
    }

    function staticCallQuoterRaw(bytes memory calldata_)
        internal
        view
        returns (bool, bytes memory)
    {
        (bool success, bytes memory data) = quoter.staticcall{gas: quoterGasLimit}(calldata_);
        return (success, data);
    }

    function getZeroOneAndSqrtPriceLimitX96(address tokenIn, address tokenOut)
        internal
        pure
        returns (bool, uint160)
    {
        bool zeroForOne = tokenIn < tokenOut;
        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;

        return (zeroForOne, sqrtPriceLimitX96);
    }
}
