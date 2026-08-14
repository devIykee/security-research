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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Query struct containing adapter and swap amount information for a single hop
 * @param adapter Address of the adapter contract to use for the swap
 * @param recipient Address that will receive tokens from the swap
 * @param tokenIn Address of the input token
 * @param tokenOut Address of the output token
 * @param amount Amount of tokens (input or output depending on swap type)
 */
struct Query {
    address adapter;
    address recipient;
    address tokenIn;
    address tokenOut;
    uint256 amount;
}

/**
 * @notice Compressed offer data using bytes encoding for gas efficiency
 * @param amounts Encoded swap amounts for each hop
 * @param adapters Encoded adapter addresses for each hop
 * @param path Encoded token path for the swap route
 * @param recipients Encoded recipient addresses for each hop
 * @param deployers Encoded deployer addresses for AlgebraV2 custom pools (address(0) for other
 * adapters)
 */
struct Offer {
    bytes amounts;
    bytes adapters;
    bytes path;
    bytes recipients;
    bytes deployers;
}

/**
 * @notice Formatted offer with decoded arrays for easier consumption
 * @param amounts Array of swap amounts for each hop
 * @param adapters Array of adapter addresses for each hop
 * @param path Array of token addresses defining the swap route
 * @param recipients Array of recipient addresses for each hop
 * @param deployers Array of deployer addresses for AlgebraV2 custom pools (address(0) for other
 * adapters)
 */
struct FormattedOffer {
    uint256[] amounts;
    address[] adapters;
    address[] path;
    address[] recipients;
    address[] deployers;
}

/**
 * @notice Trade parameters for executing a swap
 * @param amountIn Amount of input tokens to swap
 * @param amountOut Minimum amount of output tokens expected
 * @param path Array of token addresses defining the swap route
 * @param adapters Array of adapter addresses for each hop
 * @param recipients Array of recipient addresses for each hop
 * @param deployers Array of deployer addresses for AlgebraV2 custom pools (address(0) for other
 * adapters)
 */
struct Trade {
    uint256 amountIn;
    uint256 amountOut;
    address[] path;
    address[] adapters;
    address[] recipients;
    address[] deployers;
}

/**
 * @title IYakRouter
 * @author Yak Exchange
 * @notice Interface for the YakRouter contract that finds optimal swap paths and executes trades
 * @dev Supports multi-hop swaps across different DEX adapters with minimal slippage
 */
interface IYakRouter {
    /**
     * @notice Thrown when a zero address is provided where it's not allowed
     */
    error AddressZero();

    /**
     * @notice Thrown when the transaction deadline has passed
     * @param _deadline The deadline timestamp that was set
     * @param _currentTime The current block timestamp
     */
    error DeadlinePassed(uint256 _deadline, uint256 _currentTime);

    /**
     * @notice Thrown when the ETH amount sent does not match the expected amount
     * @param _sentAmount The amount of ETH sent with the transaction
     * @param _expectedAmount The expected amount of ETH for the swap
     */
    error IncorrectETHAmount(uint256 _sentAmount, uint256 _expectedAmount);

    /**
     * @notice Thrown when the provided fee is above the maximum allowed fee
     * @param _fee The fee amount provided
     * @param _maxFee The maximum fee amount allowed
     */
    error FeeAboveMaximum(uint256 _fee, uint256 _maxFee);

    /**
     * @notice Thrown when the provided fee is less than the minimum required fee
     * @param _fee The fee amount provided
     * @param _minFee The minimum fee amount required
     */
    error InsufficientFee(uint256 _fee, uint256 _minFee);

    /**
     * @notice Thrown when max steps is invalid (must be between 1 and 4)
     * @param _maxSteps The invalid max steps value provided
     */
    error InvalidMaxSteps(uint256 _maxSteps);

    /**
     * @notice Thrown when the actual output amount is less than the minimum expected
     * @param _amountOut The actual output amount received
     * @param _minAmountOut The minimum output amount expected
     */
    error InsufficientOutputAmount(uint256 _amountOut, uint256 _minAmountOut);

    /**
     * @notice Thrown when swapping from ETH but the path doesn't start with WETH
     * @param _tokenIn The first token in the path that should be WETH
     */
    error PathDoesNotBeginWithWETH(address _tokenIn);

    /**
     * @notice Thrown when swapping to ETH but the path doesn't end with WETH
     * @param _tokenOut The last token in the path that should be WETH
     */
    error PathDoesNotEndWithWETH(address _tokenOut);

    /**
     * @notice Thrown when trade parameters length does not match
     */
    error TradeLengthDoesNotMatch();

    /**
     * @notice Emitted when trusted tokens list is updated
     * @param _newTrustedTokens The new array of trusted token addresses
     */
    event UpdatedTrustedTokens(address[] _newTrustedTokens);

    /**
     * @notice Emitted when adapters list is updated
     * @param _newAdapters The new array of adapter addresses
     */
    event UpdatedAdapters(address[] _newAdapters);

    /**
     * @notice Emitted when minimum fee is updated
     * @param _oldMinFee The previous minimum fee value
     * @param _newMinFee The new minimum fee value
     */
    event UpdatedMinFee(uint256 _oldMinFee, uint256 _newMinFee);

    /**
     * @notice Emitted when fee claimer address is updated
     * @param _oldFeeClaimer The previous fee claimer address
     * @param _newFeeClaimer The new fee claimer address
     */
    event UpdatedFeeClaimer(address _oldFeeClaimer, address _newFeeClaimer);

    /**
     * @notice Emitted when a swap is executed
     * @param _tokenIn The input token address
     * @param _tokenOut The output token address
     * @param _amountIn The input amount swapped
     * @param _amountOut The output amount received
     */
    event YakSwap(
        address indexed _tokenIn, address indexed _tokenOut, uint256 _amountIn, uint256 _amountOut
    );

    // ========== Admin Functions ==========

    /**
     * @notice Updates the list of trusted tokens used for finding swap paths
     * @param _trustedTokens Array of token addresses to use as intermediate tokens
     * @dev Only callable by maintainer
     */
    function setTrustedTokens(address[] memory _trustedTokens) external;

    /**
     * @notice Updates the list of DEX adapters
     * @param _adapters Array of adapter contract addresses
     * @dev Only callable by maintainer
     */
    function setAdapters(address[] memory _adapters) external;

    /**
     * @notice Sets the address that receives swap fees
     * @param _claimer Address to receive fees
     * @dev Only callable by maintainer, cannot be zero address
     */
    function setFeeClaimer(address _claimer) external;

    /**
     * @notice Sets the minimum fee in basis points (1/10000)
     * @param _fee Minimum fee amount (e.g., 30 = 0.3%)
     * @dev Only callable by maintainer
     */
    function setMinFee(uint256 _fee) external;

    // ========== View Functions ==========

    /**
     * @notice Returns the number of trusted tokens
     * @return count The total number of trusted tokens configured
     */
    function trustedTokensCount() external view returns (uint256);

    /**
     * @notice Returns the number of adapters
     * @return count The total number of adapter contracts configured
     */
    function adaptersCount() external view returns (uint256);

    // ========== Query Functions ==========

    /**
     * @notice Queries a specific adapter for swap quote
     * @param _amount Input amount (if exactIn) or output amount (if !exactIn)
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _index Index of the adapter in the adapters array
     * @param _exactIn True for exact input, false for exact output
     * @return quoteAmount The output amount (if exactIn) or input amount (if !exactIn)
     * @return recipient The recipient address for this adapter
     */
    function queryAdapter(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        uint8 _index,
        bool _exactIn
    ) external returns (uint256, address);

    /**
     * @notice Finds the best adapter from specified options for a direct swap
     * @param _amount Input amount (if exactIn) or output amount (if !exactIn)
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _options Array of adapter indices to check
     * @param _exactIn True for exact input, false for exact output
     * @return query The best query result with adapter and amount information
     */
    function queryNoSplit(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        uint8[] calldata _options,
        bool _exactIn
    ) external view returns (Query memory);

    /**
     * @notice Finds the best adapter from all available adapters for a direct swap
     * @param _amount Input amount (if exactIn) or output amount (if !exactIn)
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _exactIn True for exact input, false for exact output
     * @return query The best query result with adapter and amount information
     */
    function queryNoSplit(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        external
        view
        returns (Query memory);

    /**
     * @notice Finds the optimal swap path between two tokens
     * @param _amount Input amount (if exactIn) or output amount (if !exactIn)
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _trustedTokens Additional trusted tokens to consider for routing
     * @param _maxSteps Maximum number of hops allowed (1-4)
     * @param _exactIn True for exact input, false for exact output
     * @return offer The optimal swap path with amounts and adapters for each hop
     * @dev Combines default trusted tokens with provided ones for path finding
     */
    function findBestPath(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        address[] memory _trustedTokens,
        uint256 _maxSteps,
        bool _exactIn
    ) external view returns (FormattedOffer memory);

    // ========== Swap Functions ==========

    /**
     * @notice Executes a token-to-token swap
     * @param _trade Trade parameters including path and amounts
     * @param _fee Fee amount in basis points to charge (e.g., 30 = 0.3%)
     * @param _deadline Unix timestamp after which the transaction reverts
     * @param _to Address to receive the output tokens
     * @dev Requires token approval from caller
     */
    function swapNoSplit(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        external;

    /**
     * @notice Executes a swap starting from ETH
     * @param _trade Trade parameters (path must start with WETH)
     * @param _fee Fee amount in basis points to charge
     * @param _deadline Unix timestamp after which the transaction reverts
     * @param _to Address to receive the output tokens
     * @dev Accepts ETH and wraps to WETH internally
     */
    function swapNoSplitFromETH(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        external
        payable;

    /**
     * @notice Executes a swap ending in ETH
     * @param _trade Trade parameters (path must end with WETH)
     * @param _fee Fee amount in basis points to charge
     * @param _deadline Unix timestamp after which the transaction reverts
     * @param _to Address to receive the ETH
     * @dev Unwraps WETH to ETH before sending to recipient
     */
    function swapNoSplitToETH(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        external;

    /**
     * @notice Executes a token-to-token swap using EIP-2612 permit
     * @param _trade Trade parameters including path and amounts
     * @param _fee Fee amount in basis points to charge
     * @param _deadline Unix timestamp after which the transaction reverts
     * @param _to Address to receive the output tokens
     * @param _v Permit signature v value
     * @param _r Permit signature r value
     * @param _s Permit signature s value
     * @dev Uses permit to avoid separate approval transaction
     */
    function swapNoSplitWithPermit(
        Trade calldata _trade,
        uint256 _fee,
        uint256 _deadline,
        address _to,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /**
     * @notice Executes a swap to ETH using EIP-2612 permit
     * @param _trade Trade parameters (path must end with WETH)
     * @param _fee Fee amount in basis points to charge
     * @param _deadline Unix timestamp after which the transaction reverts
     * @param _to Address to receive the ETH
     * @param _v Permit signature v value
     * @param _r Permit signature r value
     * @param _s Permit signature s value
     * @dev Uses permit and unwraps WETH to ETH
     */
    function swapNoSplitToETHWithPermit(
        Trade calldata _trade,
        uint256 _fee,
        uint256 _deadline,
        address _to,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;
}
