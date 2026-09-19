// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IComptroller} from "./interfaces/IComptroller.sol";
import {IVToken} from "./interfaces/IVToken.sol";

/**
 * @title Venus
 * @notice A contract for depositing underlying tokens to Venus for yield
 * @dev This contract is meant to be inherited by other contracts that need to deposit underlying tokens to Venus for yield.
 *      Some functions need to be access controlled by the child contract.
 * @author predict.fun protocol team
 */
contract Venus {
    using SafeERC20 for IERC20;

    /**
     * @notice Enable or disable Venus for an underlying token. When enabled, the contract will deposit underlying tokens to Venus for yield.
     *         When disabled, the contract will stop depositing underlying tokens to Venus for yield and withdraw all underlying tokens from Venus.
     *         This is useful for emergency cases where Venus is exploited or when there is a liquidity crunch and we need to remain operational and solvent.
     */
    mapping(address underlying => bool isEnabled) public underlyingIsEnabled;

    /**
     * @notice Maps underlying tokens to their corresponding vTokens
     */
    mapping(address underlying => address vToken) public underlyingToVToken;

    /**
     * @notice Maps underlying tokens to the amount deposited to Venus
     */
    mapping(address underlying => uint256 amount) public depositedAmount;

    /**
     * @notice Emitted when an underlying token is connected to a vToken
     * @param underlying The underlying token
     * @param vToken The vToken
     */
    event UnderlyingTokenConnectedToVToken(address underlying, address vToken);

    /**
     * @notice Emitted when vTokens are minted
     * @param underlying The underlying token
     * @param vToken The vToken
     * @param underlyingAmount The amount of underlying tokens deposited
     */
    event VTokenMinted(address indexed underlying, address indexed vToken, uint256 underlyingAmount);

    /**
     * @notice Emitted when underlying tokens are redeemed
     * @param underlying The underlying token
     * @param vToken The vToken
     * @param amountRedeemed The amount of underlying tokens redeemed
     * @param amountReceived The amount of underlying tokens received. It can be less than the amount redeemed if there is a withdrawal fee.
     */
    event UnderlyingTokenRedeemed(
        address indexed underlying,
        address indexed vToken,
        uint256 amountRedeemed,
        uint256 amountReceived
    );

    /**
     * @notice Emitted when an underlying token is disabled
     * @param underlying The underlying token
     * @param amountRedeemed The amount of underlying tokens redeemed
     * @param yieldRecipient The address of the yield recipient
     * @param yieldClaimed The amount of yield claimed
     */
    event UnderlyingTokenDisabled(
        address indexed underlying,
        uint256 amountRedeemed,
        address yieldRecipient,
        uint256 yieldClaimed
    );

    /**
     * @notice Emitted when an underlying token is enabled
     * @param underlying The underlying token
     * @param amount The amount of underlying tokens deposited
     */
    event UnderlyingTokenEnabled(address indexed underlying, uint256 amount);

    /**
     * @notice Emitted when yield is claimed
     * @param underlying The underlying token
     * @param vToken The vToken
     * @param vTokenAmount The amount of vTokens claimed
     * @param underlyingAmount The amount of underlying tokens received
     */
    event YieldClaimed(
        address indexed underlying,
        address indexed vToken,
        uint256 vTokenAmount,
        uint256 underlyingAmount
    );

    error Insolvent();
    error NotYieldBearingToken();
    error NoUnderlyingToken();
    error NoYield();
    error NoYieldBearingToken();
    error UnderlyingTokenAlreadyConnected();
    error UnderlyingTokenAlreadyDisabled();
    error UnderlyingTokenAlreadyEnabled();
    error VTokenCallFailed(uint256 err);
    error VTokenTreasuryPercentMustBeZero();

    /**
     * @notice Splits contract vToken balance into principal and yield
     * @param underlying The underlying token
     * @return principal The principal amount
     * @return yield The yield amount
     */
    function splitPrincipalAndYield(address underlying) public returns (uint256 principal, uint256 yield) {
        address vToken = _getVToken(underlying);
        uint256 exchangeRateCurrent = IVToken(vToken).exchangeRateCurrent();
        (, principal) = divScalarByExpTruncate(depositedAmount[underlying], Exp({mantissa: exchangeRateCurrent}));
        yield = IVToken(vToken).balanceOf(address(this)) - principal;
    }

    /**
     * @notice Mints vTokens
     * @param underlying The underlying token
     * @param amount The amount of underlying tokens to mint
     */
    function _mintVToken(address underlying, uint256 amount) internal {
        address vToken = _getVToken(underlying);

        IComptroller comptroller = IComptroller(IVToken(vToken).comptroller());
        if (comptroller.treasuryPercent() > 0) {
            revert VTokenTreasuryPercentMustBeZero();
        }

        depositedAmount[underlying] += amount;

        IERC20(underlying).forceApprove(vToken, amount);
        uint256 err = IVToken(vToken).mint(amount);
        if (err != 0) {
            revert VTokenCallFailed(err);
        }

        emit VTokenMinted(underlying, vToken, amount);
    }

    /**
     * @notice Redeems underlying tokens from Venus
     * @param underlying The underlying token
     * @param amount The amount of underlying tokens to redeem
     * @return amountRedeemed The actual amount of underlying tokens redeemed
     */
    function _redeemUnderlying(address underlying, uint256 amount) internal returns (uint256 amountRedeemed) {
        address vToken = _getVToken(underlying);

        uint256 underlyingBalanceBefore = IERC20(underlying).balanceOf(address(this));

        uint256 err = IVToken(vToken).redeemUnderlying(amount);
        if (err != 0) {
            revert VTokenCallFailed(err);
        }

        amountRedeemed = IERC20(underlying).balanceOf(address(this)) - underlyingBalanceBefore;

        depositedAmount[underlying] -= amount;

        emit UnderlyingTokenRedeemed(underlying, vToken, amount, amountRedeemed);
    }

    /**
     * @notice Claims yield from Venus
     * @dev We should never claim 100% of the yield because Venus' balanceOfUnderlying carries precision loss
     * @param underlying The underlying token
     * @param vTokenAmount The amount of vTokens to claim
     */
    function _claimYield(address underlying, uint256 vTokenAmount, address recipient) internal {
        address vToken = _getVToken(underlying);
        (, uint256 yield) = splitPrincipalAndYield(underlying);

        if (vTokenAmount == 0) {
            vTokenAmount = (yield * 9_999) / 10_000;
        }

        uint256 underlyingBalanceBefore = IERC20(underlying).balanceOf(address(this));

        uint256 err = IVToken(vToken).redeem(vTokenAmount);
        if (err != 0) {
            revert VTokenCallFailed(err);
        }

        uint256 underlyingBalanceAfter = IERC20(underlying).balanceOf(address(this));

        uint256 yieldClaimed = underlyingBalanceAfter - underlyingBalanceBefore;

        if (yieldClaimed == 0) {
            revert NoYield();
        }

        IERC20(underlying).safeTransfer(recipient, yieldClaimed);

        // We should never claim 100% of the yield because balanceOfUnderlying carries precision loss
        // even though our own calculation is precise
        if (IVToken(vToken).balanceOfUnderlying(address(this)) < depositedAmount[underlying]) {
            revert Insolvent();
        }

        emit YieldClaimed(underlying, vToken, vTokenAmount, yieldClaimed);
    }

    /**
     * @notice Connects an underlying token to a vToken
     * @param vToken The vToken to connect
     * @return underlying The underlying token
     */
    function _connectVTokenToUnderlying(address vToken) internal returns (address underlying) {
        if (!IVToken(vToken).isVToken()) {
            revert NotYieldBearingToken();
        }

        underlying = IVToken(vToken).underlying();

        if (underlying == address(0)) {
            revert NoUnderlyingToken();
        }

        if (underlyingToVToken[underlying] != address(0)) {
            revert UnderlyingTokenAlreadyConnected();
        }

        underlyingToVToken[underlying] = vToken;
        underlyingIsEnabled[underlying] = true;

        emit UnderlyingTokenConnectedToVToken(underlying, vToken);
    }

    /**
     * @notice Disables Venus for an underlying token. Withdraws all underlying tokens from Venus.
     * @param underlying The underlying token
     * @param yieldRecipient The address of the yield recipient
     */
    function _disableUnderlying(address underlying, address yieldRecipient) internal {
        if (!underlyingIsEnabled[underlying]) {
            revert UnderlyingTokenAlreadyDisabled();
        }

        underlyingIsEnabled[underlying] = false;

        uint256 balanceOfUnderlying = IERC20(underlying).balanceOf(address(this));

        address vToken = _getVToken(underlying);
        uint256 redeemAmount = IVToken(vToken).balanceOfUnderlying(address(this));
        uint256 originalDepositedAmount = depositedAmount[underlying];
        if (redeemAmount < originalDepositedAmount) {
            redeemAmount = originalDepositedAmount;
        }

        if (redeemAmount > 0) {
            uint256 err = IVToken(vToken).redeemUnderlying(redeemAmount);
            if (err != 0) {
                revert VTokenCallFailed(err);
            }
        }

        depositedAmount[underlying] = 0;

        uint256 amountRedeemed = IERC20(underlying).balanceOf(address(this)) - balanceOfUnderlying;

        uint256 yieldClaimed = amountRedeemed - originalDepositedAmount;

        if (yieldClaimed > 0) {
            IERC20(underlying).safeTransfer(yieldRecipient, yieldClaimed);
        }

        emit UnderlyingTokenDisabled(underlying, amountRedeemed, yieldRecipient, yieldClaimed);
    }

    /**
     * @notice Enable Venus for an underlying token. Deposits underlying tokens to Venus for yield.
     * @param underlying The underlying token
     */
    function _enableUnderlying(address underlying) internal {
        if (underlyingIsEnabled[underlying]) {
            revert UnderlyingTokenAlreadyEnabled();
        }

        underlyingIsEnabled[underlying] = true;

        uint256 amount = IERC20(underlying).balanceOf(address(this));
        if (amount > 0) {
            _mintVToken(underlying, amount);
        }

        emit UnderlyingTokenEnabled(underlying, amount);
    }

    /**
     * @notice Gets the vToken for an underlying token
     * @param underlying The underlying token
     * @return vToken The vToken
     */
    function _getVToken(address underlying) internal view returns (address vToken) {
        vToken = underlyingToVToken[underlying];

        if (vToken == address(0)) {
            revert NoYieldBearingToken();
        }

        return vToken;
    }

    // NOTE: Code **directly** copied from Venus **without modifications** for splitting principal and yield

    enum MathError {
        NO_ERROR,
        DIVISION_BY_ZERO,
        INTEGER_OVERFLOW,
        INTEGER_UNDERFLOW
    }

    struct Exp {
        uint mantissa;
    }

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    uint256 public constant expScale = 1e18;

    /**
     * @dev Divide a scalar by an Exp, returning a new Exp.
     */
    function divScalarByExp(uint scalar, Exp memory divisor) internal pure returns (MathError, Exp memory) {
        /*
          We are doing this as:
          getExp(mulUInt(expScale, scalar), divisor.mantissa)

          How it works:
          Exp = a / b;
          Scalar = s;
          `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
        */
        (MathError err0, uint numerator) = mulUInt(expScale, scalar);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }
        return getExp(numerator, divisor.mantissa);
    }

    /**
     * @dev Divide a scalar by an Exp, then truncate to return an unsigned integer.
     */
    function divScalarByExpTruncate(uint scalar, Exp memory divisor) internal pure returns (MathError, uint) {
        (MathError err, Exp memory fraction) = divScalarByExp(scalar, divisor);
        if (err != MathError.NO_ERROR) {
            return (err, 0);
        }

        return (MathError.NO_ERROR, truncate(fraction));
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) internal pure returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Multiplies two numbers, returns an error on overflow.
     */
    function mulUInt(uint a, uint b) internal pure returns (MathError, uint) {
        if (a == 0) {
            return (MathError.NO_ERROR, 0);
        }

        uint c;
        unchecked {
            c = a * b;
        }

        if (c / a != b) {
            return (MathError.INTEGER_OVERFLOW, 0);
        } else {
            return (MathError.NO_ERROR, c);
        }
    }

    /**
     * @dev Creates an exponential from numerator and denominator values.
     *      Note: Returns an error if (`num` * 10e18) > MAX_INT,
     *            or if `denom` is zero.
     */
    function getExp(uint num, uint denom) internal pure returns (MathError, Exp memory) {
        (MathError err0, uint scaledNumerator) = mulUInt(num, expScale);
        if (err0 != MathError.NO_ERROR) {
            return (err0, Exp({mantissa: 0}));
        }

        (MathError err1, uint rational) = divUInt(scaledNumerator, denom);
        if (err1 != MathError.NO_ERROR) {
            return (err1, Exp({mantissa: 0}));
        }

        return (MathError.NO_ERROR, Exp({mantissa: rational}));
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function divUInt(uint a, uint b) internal pure returns (MathError, uint) {
        if (b == 0) {
            return (MathError.DIVISION_BY_ZERO, 0);
        }

        return (MathError.NO_ERROR, a / b);
    }
}
