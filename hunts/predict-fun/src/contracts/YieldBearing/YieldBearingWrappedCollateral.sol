// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {Venus} from "./Venus.sol";

/// @title IWrappedCollateralEE
/// @notice WrappedCollateral Errors and Events
interface IYieldBearingWrappedCollateralEE {
    error OnlyOwner();
}

string constant NAME = "Wrapped Collateral";
string constant SYMBOL = "WCOL";

/// @title YieldBearingWrappedCollateral
/// @notice Wraps an ERC20 token to be used as collateral in the CTF, and generates yield using Venus
/// @author predict.fun protocol team
contract YieldBearingWrappedCollateral is IYieldBearingWrappedCollateralEE, ERC20, Venus {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    address public immutable owner;
    address public immutable underlying;

    address public yieldManager;

    event YieldBearingWrappedCollateral__YieldManagerUpdated(address indexed yieldManager);

    error OnlyYieldManager();
    error UnderlyingTokenMismatch();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyYieldManager() {
        if (msg.sender != yieldManager) revert OnlyYieldManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice The owner is YieldBearingNegRiskAdapter
    /// @param _underlying The address of the underlying ERC20 token
    /// @param _decimals The number of decimals of the underlying ERC20 token
    /// @param _yieldManager The address of the yield manager
    constructor(address _underlying, uint8 _decimals, address _yieldManager) ERC20(NAME, SYMBOL, _decimals) {
        owner = msg.sender;
        underlying = _underlying;
        yieldManager = _yieldManager;
    }

    /*//////////////////////////////////////////////////////////////
                          YIELD OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function updateYieldManager(address _yieldManager) external onlyYieldManager {
        yieldManager = _yieldManager;
        emit YieldBearingWrappedCollateral__YieldManagerUpdated(_yieldManager);
    }

    /**
     * @notice Connects a vToken to an underlying token. Only callable by the owner.
     * @param vToken The vToken to connect
     */
    function connectVTokenToUnderlying(address vToken) external onlyYieldManager {
        address _underlying = _connectVTokenToUnderlying(vToken);
        if (_underlying != underlying) {
            revert UnderlyingTokenMismatch();
        }
    }

    /**
     * @notice Claims yield from Venus. Only callable by the owner.
     * @param vTokenAmount The amount of vTokens to claim
     * @param recipient The address to receive the yield
     */
    function claimYield(uint256 vTokenAmount, address recipient) external onlyYieldManager {
        _claimYield(underlying, vTokenAmount, recipient);
    }

    /**
     * @notice Enables Venus for an underlying token. Only callable by the yield manager.
     */
    function enableUnderlying() external onlyYieldManager {
        _enableUnderlying(underlying);
    }

    /**
     * @notice Disables Venus for the underlying token. Only callable by the yield manager.
     * @param yieldRecipient The address to receive the yield
     */
    function disableUnderlying(address yieldRecipient) external onlyYieldManager {
        _disableUnderlying(underlying, yieldRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                                 UNWRAP
    //////////////////////////////////////////////////////////////*/

    /// @notice Unwraps the specified amount of tokens
    /// @param _to The address to send the unwrapped tokens to
    /// @param _amount The amount of tokens to unwrap
    function unwrap(address _to, uint256 _amount) external {
        _burn(msg.sender, _amount);
        _release(_to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Wraps the specified amount of tokens
    /// @notice Can only be called by the owner
    /// @param _to     - the address to send the wrapped tokens to
    /// @param _amount - the amount of tokens to wrap
    function wrap(address _to, uint256 _amount) external onlyOwner {
        address _underlying = underlying;
        ERC20(_underlying).safeTransferFrom(msg.sender, address(this), _amount);
        if (underlyingIsEnabled[_underlying]) {
            _mintVToken(_underlying, _amount);
        }
        _mint(_to, _amount);
    }

    /// @notice Burns the specified amount of tokens
    /// @notice Can only be called by the owner
    /// @param _amount - the amount of tokens to burn
    function burn(uint256 _amount) external onlyOwner {
        _burn(msg.sender, _amount);
    }

    /// @notice Mints the specified amount of tokens
    /// @notice Can only be called by the owner
    /// @param _amount - the amount of tokens to mint
    function mint(uint256 _amount) external onlyOwner {
        _mint(msg.sender, _amount);
    }

    /// @notice Releases the specified amount of the underlying token
    /// @notice Can only be called by the owner
    /// @param _to     - the address to send the released tokens to
    /// @param _amount - the amount of tokens to release
    function release(address _to, uint256 _amount) external onlyOwner {
        _release(_to, _amount);
    }

    /// @notice Releases the specified amount of the underlying token
    /// @param _to     - the address to send the released tokens to
    /// @param _amount - the amount of tokens to release
    function _release(address _to, uint256 _amount) private {
        address _underlying = underlying;
        if (underlyingIsEnabled[_underlying]) {
            _amount = _redeemUnderlying(_underlying, _amount);
        }
        ERC20(_underlying).safeTransfer(_to, _amount);
    }
}
