// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Multi-DEX Router Interface
/// @notice Interface for a router that can swap tokens across multiple DEX protocols using a unified interface
/// @dev This router provides a wrapper for swapping on different DEX platforms (Uniswap, PancakeSwap, etc.)
/// using the same interface. It does NOT support smart router special addresses like ADDRESS_THIS (address(2))
/// and does NOT support multicall functionality for simplified implementation and reduced complexity.
interface IMultiDexRouter {
    /// @notice Enum for V3 LP fee profiles
    enum V3LPFeeProfile {
        LP_FEE_PROFILE_STANDARD, // Standard fee tier:  0.25% on PancakeSwap, 0.3% on Uniswap
        LP_FEE_PROFILE_LOW, // Low fee tier: typically, 0.01% on PancakeSwap, 0.05% on Uniswap
        LP_FEE_PROFILE_HIGH // High fee tier (1% for exotic pairs)
    }
    /// @notice Struct containing all DEX-related parameters for a specific DEX
    /// @dev This struct provides complete configuration for interacting with a DEX protocol

    struct DEXInfo {
        bytes32 v2InitCodeHash; // Init code hash for V2 factory
        bytes32 v3InitCodeHash; // Init code hash for V3 factory
        address v2Factory; // V2 factory contract address
        address v3Factory; // V3 factory contract address
        address v3Deployer; // V3 pool deployer contract address
        address v4Vault; // V4 settlement singleton (UniV4 PoolManager or PCS Infinity Vault, if applicable)
        uint24[] v3SupportedFees; // Array of supported fee tiers for V3 pools
        address smartRouter; // Smart router address for swapping
        address v3Quoter; // V3 quoter contract for price quotes
        address v2SwapRouter; // V2 swap router contract address
        address nonfungiblePositionManager; // Non-fungible position manager for V3 liquidity positions
    }

    /// @notice Parameters for exact input single swap on V3
    /// @dev Similar to ISwapRouter.ExactInputSingleParams
    struct ExactInputSingleParams {
        address tokenIn; // Input token address
        address tokenOut; // Output token address
        uint24 fee; // Fee tier for the V3 pool
        address recipient; // Address to receive output tokens
        uint256 amountIn; // Amount of input tokens to swap
        uint256 amountOutMinimum; // Minimum amount of output tokens expected
        uint160 sqrtPriceLimitX96; // Price limit (0 = no limit)
    }

    /// @notice Parameters for quoting exact input single swap on V3
    /// @dev Similar to IV3Quoter.QuoteExactInputSingleParams
    struct QuoteExactInputSingleParams {
        address tokenIn; // Input token address
        address tokenOut; // Output token address
        uint256 amountIn; // Amount of input tokens
        uint24 fee; // Fee tier for the V3 pool
        uint160 sqrtPriceLimitX96; // Price limit (0 = no limit)
    }

    /// @notice Get DEX configuration information
    /// @param dexId The identifier of the DEX to query
    /// @return dexInfo Struct containing all DEX-related parameters
    function getDEXInfo(uint8 dexId) external view returns (DEXInfo memory dexInfo);

    /// @notice Swaps exact amount of tokens for tokens using V2 pools
    /// @dev Similar to ISwapRouter.swapExactTokensForTokens but with dexId parameter
    /// Does NOT support ADDRESS_THIS special addresses
    /// But we support CONTRACT_BALANCE (i.e, when amountIn is 0, we use the contract's balance), in
    /// such case, you have transferred the tokens to the router contract before calling this method.
    /// @param dexId The identifier of the DEX to use for swapping
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens expected
    /// @param path The ordered list of token addresses to swap through
    /// @param to The recipient address for output tokens
    /// @return amountOut The actual amount of output tokens received
    function swapExactTokensForTokens(
        uint8 dexId,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256 amountOut);

    /// @notice Swaps exact amount of input token for output token using V3 pools
    /// @dev Similar to ISwapRouter.exactInputSingle but with dexId as separate parameter
    /// Does NOT support ADDRESS_THIS special addresses
    /// But we support CONTRACT_BALANCE (i.e, when amountIn is 0, we use the contract's balance), in
    /// such case, you have transferred the tokens to the router contract before calling this method.
    /// @param dexId The identifier of the DEX to use for swapping
    /// @param params The parameters necessary for the swap
    /// @return amountOut The actual amount of output tokens received
    function exactInputSingle(uint8 dexId, ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    /// @notice Quote the amount out for exact input single swap on V3 pools
    /// @dev Similar to IV3Quoter.quoteExactInputSingle but with dexId as separate parameter
    /// @param dexId The identifier of the DEX to use for the quote
    /// @param params The parameters for the quote
    /// @return amountOut The amount of output tokens that would be received
    /// @return sqrtPriceX96After The sqrt price of the pool after the swap
    /// @return initializedTicksCrossed The number of initialized ticks crossed
    /// @return gasEstimate The estimated gas consumption for the swap
    function quoteExactInputSingle(uint8 dexId, QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate);

    /// @notice Get amounts out for exact input swap on V2 pools
    /// @dev Similar to IV2Quoter.getAmountsOut but with dexId parameter
    /// This method assumes swapping on V2 pools of the specified DEX
    /// @param dexId The identifier of the DEX to use for the quote
    /// @param amountIn The amount of input tokens
    /// @param path The ordered list of token addresses to swap through
    /// @return amounts The amounts of tokens at each step of the swap path
    function getAmountsOut(uint8 dexId, uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Compute the V2 pool address for a given token pair
    /// @param dexId The identifier of the DEX to compute the pool address for
    /// @param tokenA The first token in the pair
    /// @param tokenB The second token in the pair
    /// @return pool The computed pool address for the token pair
    function computeV2PoolAddress(uint8 dexId, address tokenA, address tokenB) external view returns (address pool);

    /// @notice Compute the V3 pool address for a given token pair and fee tier
    /// @param dexId The identifier of the DEX to compute the pool address for
    /// @param tokenA The first token in the pair
    /// @param tokenB The second token in the pair
    /// @param fee The fee tier for the V3 pool
    /// @return pool The computed pool address for the token pair and fee tier
    function computeV3PoolAddress(uint8 dexId, address tokenA, address tokenB, uint24 fee)
        external
        view
        returns (address pool);

    /// @notice Get the V2 factory address for a specific DEX
    /// @param dexId The identifier of the DEX to get the factory address for
    /// @return factory The V2 factory address
    function getV2FactoryAddress(uint8 dexId) external view returns (address factory);

    /// @notice Get the V3 factory address for a specific DEX
    /// @param dexId The identifier of the DEX to get the factory address for
    /// @return factory The V3 factory address
    function getV3FactoryAddress(uint8 dexId) external view returns (address factory);

    /// @notice Get the non-fungible position manager address for a specific DEX
    /// @param dexId The identifier of the DEX to get the position manager address for
    /// @return positionManager The non-fungible position manager address
    function getNonfungiblePositionManager(uint8 dexId) external view returns (address positionManager);

    /// @notice Get the V2 pool fee tier for a specific DEX
    /// @param dexId The identifier of the DEX to get the fee tier for
    /// @return fee The V2 pool fee tier (2500 for PancakeSwap, 3000 for others)
    function getV2PoolFeeTier(uint8 dexId) external view returns (uint24 fee);

    /// @notice Get ALL pools (every V2/V3 fee tier + every configured V4 settlement singleton) for anti-farmer whitelisting.
    /// @dev Unlike getMajorPools, this function guarantees complete coverage:
    ///        • All 4 V3 fee tiers for every DEX (never omits low/high tiers)
    ///        • All configured V4 settlement singletons (UniV4 PoolManagers / PCS Vaults)
    ///        • Same WETH-bridged pool logic as getMajorPools
    ///      Use this when initialising the anti-farmer pool whitelist in Token contracts.
    /// @param preferredDexId Determines pool ordering only; does NOT affect coverage.
    /// @param baseToken The base (meme) token address
    /// @param quoteToken The quote token address
    /// @return pools Complete array of pool addresses to block during the anti-farmer window
    function getAllTradingPools(uint8 preferredDexId, address baseToken, address quoteToken)
        external
        view
        returns (address[] memory pools);

    // ─────────────────────────────────────────────────────────────────────────
    // V4 / PCS Infinity CL / PCS Infinity Bin
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Common params for quoting a single-hop exact-input swap on V4/PCS-Infinity pools
    struct V4QuoteExactInputSingleParams {
        address tokenIn; // Input token address (address(0) for native)
        address tokenOut; // Output token address (address(0) for native)
        uint24 fee; // Pool fee in pips (e.g. 3000 = 0.3%). For BIN pools this is ignored (use tickSpacingOrBinStep)
        int24 tickSpacing; // Tick spacing for V4/CL pools; 0 for BIN pools
        address hooks; // Hook contract address; address(0) for pools without hooks
        uint128 amountIn; // Exact input amount
    }

    /// @notice Common params for executing a single-hop exact-input swap on V4/PCS-Infinity pools
    struct V4SwapExactInputSingleParams {
        address tokenIn; // Input token address (address(0) for native)
        address tokenOut; // Output token address (address(0) for native)
        uint24 fee; // Pool fee in pips
        int24 tickSpacing; // Tick spacing for V4/CL; 0 for BIN
        address hooks; // Hook contract address; address(0) for no hooks
        uint128 amountIn; // Exact input amount (0 = use contract balance)
        uint128 amountOutMinimum; // Minimum output amount (slippage guard)
        address recipient; // Address to receive output tokens
    }

    /// @notice Quote a single-hop exact-input swap on a Uniswap V4 pool
    /// @param dexId The DEX identifier
    /// @param params The quote parameters
    /// @return amountOut The estimated output amount
    /// @return gasEstimate The estimated gas cost
    function quoteExactInputSingleV4(uint8 dexId, V4QuoteExactInputSingleParams calldata params)
        external
        returns (uint256 amountOut, uint256 gasEstimate);

    /// @notice Execute a single-hop exact-input swap on a Uniswap V4 pool
    /// @dev Caller must have transferred `params.amountIn` tokens to this contract first (or
    ///      use amountIn=0 to use this contract's existing balance).
    /// @param dexId The DEX identifier
    /// @param params The swap parameters
    /// @return amountOut The actual output amount received
    function exactInputSingleV4(uint8 dexId, V4SwapExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    /// @notice Quote a single-hop exact-input swap on a PancakeSwap Infinity CL pool
    /// @param dexId The DEX identifier
    /// @param params The quote parameters (tickSpacing used; binStep ignored)
    /// @return amountOut The estimated output amount
    /// @return gasEstimate The estimated gas cost
    function quoteExactInputSinglePCSInfinityCL(uint8 dexId, V4QuoteExactInputSingleParams calldata params)
        external
        returns (uint256 amountOut, uint256 gasEstimate);

    /// @notice Execute a single-hop exact-input swap on a PancakeSwap Infinity CL pool
    /// @param dexId The DEX identifier
    /// @param params The swap parameters (tickSpacing used; binStep ignored)
    /// @return amountOut The actual output amount received
    function exactInputSinglePCSInfinityCL(uint8 dexId, V4SwapExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}
