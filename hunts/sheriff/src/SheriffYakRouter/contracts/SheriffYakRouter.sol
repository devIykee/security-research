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
pragma experimental ABIEncoderV2;

import {IYakRouter, Offer, Query, FormattedOffer, Trade} from "contracts/interface/IYakRouter.sol";
import {IAdapter} from "contracts/interface/IAdapter.sol";
import {IAlgebraV2Adapter} from "contracts/interface/IAlgebraV2Adapter.sol";
import {IERC20} from "contracts/interface/IERC20.sol";
import {IWETH} from "contracts/interface/IWETH.sol";
import {SafeERC20} from "contracts/lib/SafeERC20.sol";
import {OfferUtils} from "contracts/lib/YakViewUtils.sol";
import {Recoverable} from "contracts/lib/Recoverable.sol";
import {SafeERC20} from "contracts/lib/SafeERC20.sol";

/**
 * @title SheriffYakRouter
 * @notice Main router contract for finding optimal swap paths and executing trades
 * @dev Inherits from Maintainable for access control and Recoverable for token recovery
 */
contract SheriffYakRouter is Recoverable, IYakRouter {
    using SafeERC20 for IERC20;
    using OfferUtils for Offer;

    /// @notice Fee denominator for basis point calculations (10000 = 100%)
    uint256 public constant FEE_DENOMINATOR = 1e4;
    /// @notice Storage slot length in bytes
    uint256 public constant SLOT_LENGTH = 32;
    /// @notice Address representing native currency (ETH)
    address public constant NATIVE = address(0);
    /// @notice Name of this router implementation
    string public constant NAME = "SheriffYakRouter";
    /// @notice Wrapped native token address (WETH)
    address public immutable WNATIVE;
    /// @notice Minimum fee in basis points
    uint256 public MIN_FEE = 0;
    /// @notice Address that receives protocol fees
    address public FEE_CLAIMER;
    /// @notice Array of trusted intermediate tokens for multi-hop swaps
    address[] public TRUSTED_TOKENS;
    /// @notice Array of DEX adapter contracts
    address[] public ADAPTERS;

    /**
     * @notice Ensures transaction is executed before deadline
     * @param _deadline Unix timestamp deadline
     */
    modifier withDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert DeadlinePassed(_deadline, block.timestamp);
        _;
    }

    /**
     * @notice Initializes the router with adapters and configuration
     * @param _adapters Initial array of adapter addresses
     * @param _trustedTokens Initial array of trusted token addresses
     * @param _feeClaimer Address to receive fees
     * @param _wrapped_native Address of wrapped native token (WETH)
     */
    constructor(
        address[] memory _adapters,
        address[] memory _trustedTokens,
        address _feeClaimer,
        address _wrapped_native
    ) {
        if (_feeClaimer == address(0) || _wrapped_native == address(0)) revert AddressZero();
        setTrustedTokens(_trustedTokens);
        setFeeClaimer(_feeClaimer);
        setAdapters(_adapters);
        WNATIVE = _wrapped_native;
    }

    // -- SETTERS --

    /// @inheritdoc IYakRouter
    function setTrustedTokens(address[] memory _trustedTokens) public override onlyMaintainer {
        TRUSTED_TOKENS = _trustedTokens;
        emit UpdatedTrustedTokens(_trustedTokens);
    }

    /// @inheritdoc IYakRouter
    function setAdapters(address[] memory _adapters) public override onlyMaintainer {
        ADAPTERS = _adapters;
        emit UpdatedAdapters(_adapters);
    }

    /// @inheritdoc IYakRouter
    function setMinFee(uint256 _fee) external override onlyMaintainer {
        if (_fee > FEE_DENOMINATOR / 10) revert FeeAboveMaximum(_fee, FEE_DENOMINATOR / 10);
        uint256 oldMinFee = MIN_FEE;
        MIN_FEE = _fee;
        emit UpdatedMinFee(oldMinFee, _fee);
    }

    /// @inheritdoc IYakRouter
    function setFeeClaimer(address _claimer) public override onlyMaintainer {
        if (_claimer == address(0)) revert AddressZero();
        address oldClaimer = FEE_CLAIMER;
        FEE_CLAIMER = _claimer;
        emit UpdatedFeeClaimer(oldClaimer, FEE_CLAIMER);
    }

    //  -- GENERAL --

    /// @inheritdoc IYakRouter
    function trustedTokensCount() external view override returns (uint256) {
        return TRUSTED_TOKENS.length;
    }

    /// @inheritdoc IYakRouter
    function adaptersCount() external view override returns (uint256) {
        return ADAPTERS.length;
    }

    /**
     * @notice Fallback function to receive ETH
     */
    receive() external payable {}

    // -- HELPERS --

    /**
     * @notice Applies fee deduction to input amount
     * @param _amountIn Input amount before fees
     * @param _fee Fee in basis points
     * @return Amount after fee deduction
     */
    function _applyFee(uint256 _amountIn, uint256 _fee) internal view returns (uint256) {
        if (_fee < MIN_FEE) revert InsufficientFee(_fee, MIN_FEE);
        return (_amountIn * (FEE_DENOMINATOR - _fee)) / FEE_DENOMINATOR;
    }

    /**
     * @notice Wraps native currency to WETH
     * @param _amount Amount of native currency to wrap
     */
    function _wrap(uint256 _amount) internal {
        IWETH(WNATIVE).deposit{value: _amount}();
    }

    /**
     * @notice Unwraps WETH to native currency
     * @param _amount Amount of WETH to unwrap
     */
    function _unwrap(uint256 _amount) internal {
        IWETH(WNATIVE).withdraw(_amount);
    }

    /**
     * @notice Returns tokens to specified address
     * @param _token Token address (use address(0) for ETH)
     * @param _amount Amount to transfer
     * @param _to Recipient address
     * @dev Handles both ERC20 tokens and native ETH transfers
     */
    function _returnTokensTo(address _token, uint256 _amount, address _to) internal {
        if (address(this) != _to) {
            if (_token == NATIVE) {
                (bool success,) = payable(_to).call{value: _amount}("");
                if (!success) revert ETHTransferFailed();
            } else {
                IERC20(_token).safeTransfer(_to, _amount);
            }
        }
    }

    /**
     * @notice Transfers tokens from source to destination
     * @param token Token address to transfer
     * @param _from Source address
     * @param _to Destination address
     * @param _amount Amount to transfer
     * @dev Uses transferFrom if source is not this contract
     */
    function _transferFrom(address token, address _from, address _to, uint256 _amount) internal {
        if (_from != address(this)) IERC20(token).safeTransferFrom(_from, _to, _amount);
        else IERC20(token).safeTransfer(_to, _amount);
    }

    // -- QUERIES --

    /// @inheritdoc IYakRouter
    function queryAdapter(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        uint8 _index,
        bool _exactIn
    ) external view override returns (uint256, address) {
        IAdapter _adapter = IAdapter(ADAPTERS[_index]);
        try IAdapter(_adapter).query(_amount, _tokenIn, _tokenOut, _exactIn) returns (
            uint256 quoteAmount, address _recipient
        ) {
            return (quoteAmount, _recipient);
        } catch {
            return (0, address(0));
        }
    }

    /// @inheritdoc IYakRouter
    function queryNoSplit(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        uint8[] calldata _options,
        bool _exactIn
    ) public view override returns (Query memory) {
        Query memory bestQuery;
        for (uint8 i; i < _options.length; ++i) {
            address _adapter = ADAPTERS[_options[i]];
            try IAdapter(_adapter).query(_amount, _tokenIn, _tokenOut, _exactIn) returns (
                uint256 quoteAmount, address _recipient
            ) {
                if (
                    i == 0 || _exactIn
                        ? quoteAmount > bestQuery.amount
                        : (
                            quoteAmount != 0
                                && (bestQuery.amount == 0 || quoteAmount < bestQuery.amount)
                        )
                ) bestQuery = Query(_adapter, _recipient, _tokenIn, _tokenOut, quoteAmount);
            } catch {
                continue;
            }
        }
        return bestQuery;
    }

    /// @inheritdoc IYakRouter
    function queryNoSplit(uint256 _amount, address _tokenIn, address _tokenOut, bool _exactIn)
        public
        view
        override
        returns (Query memory)
    {
        (Query memory bestQuery,) =
            _queryNoSplitWithDeployer(_amount, _tokenIn, _tokenOut, _exactIn);
        return bestQuery;
    }

    /**
     * @notice Internal function to query adapters and return deployer info
     * @param _amount Amount to swap
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _exactIn True for exact input, false for exact output
     * @return bestQuery Best query result
     * @return bestDeployer Deployer address for AlgebraV2 custom pools
     */
    function _queryNoSplitWithDeployer(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        bool _exactIn
    ) internal view returns (Query memory bestQuery, address bestDeployer) {
        uint256 length = ADAPTERS.length;
        for (uint8 i; i < length; ++i) {
            address _adapter = ADAPTERS[i];

            // Try to get quote with deployer info from AlgebraV2Adapter
            try IAlgebraV2Adapter(_adapter).queryWithDeployer(
                _amount, _tokenIn, _tokenOut, _exactIn
            ) returns (uint256 quoteAmount, address _recipient, address deployer) {
                if (
                    i == 0 || _exactIn
                        ? quoteAmount > bestQuery.amount
                        : (
                            quoteAmount != 0
                                && (bestQuery.amount == 0 || quoteAmount < bestQuery.amount)
                        )
                ) {
                    bestQuery = Query(_adapter, _recipient, _tokenIn, _tokenOut, quoteAmount);
                    bestDeployer = deployer;
                }
                continue;
            } catch {}

            // Fallback to regular query for other adapters
            try IAdapter(_adapter).query(_amount, _tokenIn, _tokenOut, _exactIn) returns (
                uint256 quoteAmount, address _recipient
            ) {
                if (
                    i == 0 || _exactIn
                        ? quoteAmount > bestQuery.amount
                        : (
                            quoteAmount != 0
                                && (bestQuery.amount == 0 || quoteAmount < bestQuery.amount)
                        )
                ) {
                    bestQuery = Query(_adapter, _recipient, _tokenIn, _tokenOut, quoteAmount);
                    bestDeployer = address(0);
                }
            } catch {
                continue;
            }
        }
        return (bestQuery, bestDeployer);
    }

    /// @inheritdoc IYakRouter
    function findBestPath(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        address[] memory _trustedTokens,
        uint256 _maxSteps,
        bool _exactIn
    ) external view override returns (FormattedOffer memory) {
        if (_maxSteps == 0 || _maxSteps >= 5) revert InvalidMaxSteps(_maxSteps);
        Offer memory queries = OfferUtils.newOffer(_amount, _exactIn ? _tokenIn : _tokenOut);

        uint256 ttLength = TRUSTED_TOKENS.length;
        // Concatenate default and additional trusted tokens
        address[] memory _allTrustedTokens = new address[](ttLength + _trustedTokens.length);
        for (uint256 i; i < ttLength; ++i) {
            _allTrustedTokens[i] = TRUSTED_TOKENS[i];
        }
        for (uint256 i; i < _trustedTokens.length; ++i) {
            _allTrustedTokens[ttLength + i] = _trustedTokens[i];
        }

        // Initialize empty array to track used pools
        bytes32[] memory usedPools = new bytes32[](0);
        queries = _findBestPath(
            _amount, _tokenIn, _tokenOut, _allTrustedTokens, _maxSteps, queries, _exactIn, usedPools
        );
        // If no paths are found return empty struct
        if (queries.adapters.length == 0) {
            queries.amounts = "";
            queries.path = "";
        }
        return queries.format();
    }

    /**
     * @notice Internal recursive function to find optimal swap path
     * @param _amount Amount to swap
     * @param _tokenIn Input token address
     * @param _tokenOut Output token address
     * @param _trustedTokens Array of intermediate tokens to consider
     * @param _maxSteps Maximum hops allowed
     * @param _queries Current path being built
     * @param _exactIn True for exact input, false for exact output
     * @param _usedPools Array of pool hashes already used in the path
     * @return Optimal swap path offer
     * @dev Recursively explores paths through trusted tokens, avoiding duplicate pools
     */
    function _findBestPath(
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        address[] memory _trustedTokens,
        uint256 _maxSteps,
        Offer memory _queries,
        bool _exactIn,
        bytes32[] memory _usedPools
    ) internal view returns (Offer memory) {
        Offer memory bestOption = _queries.clone();
        uint256 bestAmount;

        // First check if there is a path directly from tokenIn to tokenOut
        (Query memory queryDirect, address deployer) =
            _queryNoSplitWithDeployer(_amount, _tokenIn, _tokenOut, _exactIn);

        if (queryDirect.amount > 0) {
            // Check if this pool has already been used
            bytes32 poolHash = _getPoolHash(queryDirect.adapter, _tokenIn, _tokenOut, deployer);
            if (!_isPoolUsed(poolHash, _usedPools)) {
                if (_exactIn) {
                    bestOption.addToTail(
                        queryDirect.amount,
                        queryDirect.adapter,
                        queryDirect.recipient,
                        queryDirect.tokenOut,
                        deployer
                    );
                } else {
                    // For exactOut: when adding to head, we add the input token since path goes
                    // tokenIn
                    // -> tokenOut
                    bestOption.addToHead(
                        queryDirect.amount,
                        queryDirect.adapter,
                        queryDirect.recipient,
                        queryDirect.tokenIn,
                        deployer
                    );
                }
                bestAmount = queryDirect.amount;
            }
        }

        // Only check the rest if they would go beyond step limit (Need at least 2 more steps)
        if (_maxSteps > 1 && _queries.adapters.length / SLOT_LENGTH <= _maxSteps - 2) {
            // Check for paths that pass through trusted tokens
            for (uint256 i; i < _trustedTokens.length; ++i) {
                if (_exactIn ? (_tokenIn == _trustedTokens[i]) : (_tokenOut == _trustedTokens[i])) {
                    continue;
                }

                Query memory bestSwap;
                uint256 swapAmount;

                address swapDeployer;
                if (_exactIn) {
                    // For exactIn: find swap from tokenIn to trusted token
                    (bestSwap, swapDeployer) =
                        _queryNoSplitWithDeployer(_amount, _tokenIn, _trustedTokens[i], _exactIn);
                    swapAmount = bestSwap.amount;
                } else {
                    // For exactOut: find swap from trusted token to tokenOut
                    (bestSwap, swapDeployer) =
                        _queryNoSplitWithDeployer(_amount, _trustedTokens[i], _tokenOut, _exactIn);
                    swapAmount = bestSwap.amount;
                }

                if (swapAmount == 0) continue;

                // Check if this pool has already been used
                bytes32 poolHash;
                if (_exactIn) {
                    poolHash =
                        _getPoolHash(bestSwap.adapter, _tokenIn, _trustedTokens[i], swapDeployer);
                } else {
                    poolHash =
                        _getPoolHash(bestSwap.adapter, _trustedTokens[i], _tokenOut, swapDeployer);
                }

                if (_isPoolUsed(poolHash, _usedPools)) continue;

                // Explore options that connect the current path
                Offer memory newOffer = _queries.clone();

                // Add this pool to the used pools for the recursive call
                bytes32[] memory newUsedPools = _addUsedPool(poolHash, _usedPools);

                if (_exactIn) {
                    // For exactIn: add first hop to tail, then recurse forward
                    newOffer.addToTail(
                        swapAmount,
                        bestSwap.adapter,
                        bestSwap.recipient,
                        bestSwap.tokenOut,
                        swapDeployer
                    );
                    newOffer = _findBestPath(
                        swapAmount,
                        _trustedTokens[i],
                        _tokenOut,
                        _trustedTokens,
                        _maxSteps,
                        newOffer,
                        _exactIn,
                        newUsedPools
                    );
                } else {
                    // For exactOut: add last hop to head, then recurse backward
                    // When building exactOut path, we need to add the tokenIn from the perspective
                    // of the swap direction (trustedToken -> tokenOut means trustedToken is
                    // tokenIn)
                    newOffer.addToHead(
                        swapAmount,
                        bestSwap.adapter,
                        bestSwap.recipient,
                        bestSwap.tokenIn,
                        swapDeployer
                    );
                    newOffer = _findBestPath(
                        swapAmount,
                        _tokenIn,
                        _trustedTokens[i],
                        _trustedTokens,
                        _maxSteps,
                        newOffer,
                        _exactIn,
                        newUsedPools
                    );
                }

                bool validPath = _exactIn
                    ? (_tokenOut == newOffer.getTokenOut())
                    : (_tokenIn == newOffer.getTokenIn());

                if (validPath) {
                    uint256 pathAmount = _exactIn
                        ? newOffer.getAmountOut() // Final output amount
                        : newOffer.getAmountIn(); // First input amount

                    bool isBetter = (bestAmount == 0)
                        || (_exactIn ? pathAmount > bestAmount : pathAmount < bestAmount);

                    if (isBetter) {
                        bestAmount = pathAmount;
                        bestOption = newOffer;
                    }
                }
            }
        }
        return bestOption;
    }

    /**
     * @notice Generates a unique hash for a pool based on adapter, tokens, and deployer
     * @param _adapter Address of the adapter
     * @param _tokenA First token in the pair
     * @param _tokenB Second token in the pair
     * @param _deployer Deployer address (address(0) for default pools)
     * @return Hash identifying the pool uniquely
     */
    function _getPoolHash(address _adapter, address _tokenA, address _tokenB, address _deployer)
        internal
        pure
        returns (bytes32)
    {
        // Sort tokens to ensure consistent hashing regardless of order
        (address token0, address token1) =
            _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        return keccak256(abi.encodePacked(_adapter, token0, token1, _deployer));
    }

    /**
     * @notice Checks if a pool hash exists in the used pools array
     * @param _poolHash Hash of the pool to check
     * @param _usedPools Array of already used pool hashes
     * @return True if the pool has been used, false otherwise
     */
    function _isPoolUsed(bytes32 _poolHash, bytes32[] memory _usedPools)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < _usedPools.length; i++) {
            if (_usedPools[i] == _poolHash) return true;
        }
        return false;
    }

    /**
     * @notice Adds a pool hash to the used pools array
     * @param _poolHash Hash of the pool to add
     * @param _usedPools Current array of used pools
     * @return New array with the pool hash added
     */
    function _addUsedPool(bytes32 _poolHash, bytes32[] memory _usedPools)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory newUsedPools = new bytes32[](_usedPools.length + 1);
        for (uint256 i = 0; i < _usedPools.length; i++) {
            newUsedPools[i] = _usedPools[i];
        }
        newUsedPools[_usedPools.length] = _poolHash;
        return newUsedPools;
    }

    // -- SWAPPERS --

    /**
     * @notice Internal function that executes the swap
     * @param _trade Trade parameters
     * @param _from Address tokens are swapped from
     * @param _fee Fee amount in basis points
     * @param _to Address to receive output tokens
     * @return amountOut Final output amount
     * @dev Handles fee collection and multi-hop execution
     */
    function _swapNoSplit(Trade calldata _trade, address _from, uint256 _fee, address _to)
        internal
        returns (uint256)
    {
        if (
            (_trade.path.length - 1 != _trade.adapters.length)
                || (_trade.recipients.length != _trade.adapters.length)
                || (_trade.deployers.length > 0 && _trade.deployers.length != _trade.adapters.length)
        ) revert TradeLengthDoesNotMatch();

        uint256 amountIn = _trade.amountIn;
        if (_fee > 0 || MIN_FEE > 0) {
            // Transfer fees to the claimer account and decrease initial amount
            amountIn = _applyFee(_trade.amountIn, _fee);
            _transferFrom(_trade.path[0], _from, FEE_CLAIMER, _trade.amountIn - amountIn);
        }
        uint256 recipientBalanceBefore = IERC20(_trade.path[0]).balanceOf(_trade.recipients[0]);
        _transferFrom(_trade.path[0], _from, _trade.recipients[0], amountIn);
        amountIn = IERC20(_trade.path[0]).balanceOf(_trade.recipients[0]) - recipientBalanceBefore;

        address tokenOut = _trade.path[_trade.path.length - 1];

        uint256 length = _trade.adapters.length;
        for (uint256 i; i < length; ++i) {
            // All adapters should transfer output token to the following target
            // All targets are the adapters, expect for the last swap where tokens are sent out
            address targetAddress = i < length - 1 ? _trade.recipients[i + 1] : _to;

            recipientBalanceBefore = IERC20(_trade.path[i + 1]).balanceOf(targetAddress);

            // Check if we have a deployer for this step (for AlgebraV2Adapter custom pools)
            if (_trade.deployers.length > 0 && _trade.deployers[i] != address(0)) {
                // Try to call the overloaded swap function with deployer parameter
                // (AlgebraV2Adapter)
                try IAlgebraV2Adapter(_trade.adapters[i]).swap(
                    amountIn,
                    0,
                    _trade.path[i],
                    _trade.path[i + 1],
                    targetAddress,
                    _trade.deployers[i]
                ) {} catch {
                    // If the adapter doesn't support the deployer parameter, fall back to regular
                    // swap
                    IAdapter(_trade.adapters[i]).swap(
                        amountIn, 0, _trade.path[i], _trade.path[i + 1], targetAddress
                    );
                }
            } else {
                // Regular swap without deployer
                IAdapter(_trade.adapters[i]).swap(
                    amountIn, 0, _trade.path[i], _trade.path[i + 1], targetAddress
                );
            }
            amountIn = IERC20(_trade.path[i + 1]).balanceOf(targetAddress) - recipientBalanceBefore;
        }
        uint256 amountOut = amountIn;
        if (amountOut < _trade.amountOut) {
            revert InsufficientOutputAmount(amountOut, _trade.amountOut);
        }
        emit YakSwap(_trade.path[0], tokenOut, _trade.amountIn, amountOut);
        return amountOut;
    }

    /// @inheritdoc IYakRouter
    function swapNoSplit(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        public
        override
        withDeadline(_deadline)
    {
        _swapNoSplit(_trade, msg.sender, _fee, _to);
    }

    /// @inheritdoc IYakRouter
    function swapNoSplitFromETH(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        external
        payable
        override
        withDeadline(_deadline)
    {
        if (msg.value != _trade.amountIn) revert IncorrectETHAmount(msg.value, _trade.amountIn);
        if (_trade.path[0] != WNATIVE) revert PathDoesNotBeginWithWETH(_trade.path[0]);
        _wrap(_trade.amountIn);
        _swapNoSplit(_trade, address(this), _fee, _to);
    }

    /// @inheritdoc IYakRouter
    function swapNoSplitToETH(Trade calldata _trade, uint256 _fee, uint256 _deadline, address _to)
        public
        override
        withDeadline(_deadline)
    {
        if (_trade.path[_trade.path.length - 1] != WNATIVE) {
            revert PathDoesNotEndWithWETH(_trade.path[_trade.path.length - 1]);
        }
        uint256 returnAmount = _swapNoSplit(_trade, msg.sender, _fee, address(this));
        _unwrap(returnAmount);
        _returnTokensTo(NATIVE, returnAmount, _to);
    }

    /// @inheritdoc IYakRouter
    function swapNoSplitWithPermit(
        Trade calldata _trade,
        uint256 _fee,
        uint256 _deadline,
        address _to,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override {
        try IERC20(_trade.path[0]).permit(
            msg.sender, address(this), _trade.amountIn, _deadline, _v, _r, _s
        ) {
            swapNoSplit(_trade, _fee, _deadline, _to);
        } catch {
            swapNoSplit(_trade, _fee, _deadline, _to);
        }
    }

    /// @inheritdoc IYakRouter
    function swapNoSplitToETHWithPermit(
        Trade calldata _trade,
        uint256 _fee,
        uint256 _deadline,
        address _to,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override {
        try IERC20(_trade.path[0]).permit(
            msg.sender, address(this), _trade.amountIn, _deadline, _v, _r, _s
        ) {
            swapNoSplitToETH(_trade, _fee, _deadline, _to);
        } catch {
            swapNoSplitToETH(_trade, _fee, _deadline, _to);
        }
    }
}
