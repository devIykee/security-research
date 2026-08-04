// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {RevShareHolderRewardToken} from "./RevShareHolderRewardToken.sol";

interface IRevShareGraduationSource {
    function graduationNativeLiquidity() external view returns (uint256);
}

abstract contract RevShareGraduationToken is RevShareHolderRewardToken {
    uint256 public constant DEFAULT_GRADUATION_THRESHOLD = 4 ether;
    address public immutable graduationSource;
    uint256 public immutable graduationThreshold;
    bool public isGraduate;

    event Graduated(address indexed source, uint256 nativeLiquidity, uint256 threshold);

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 tokenSupply,
        string memory tokenMetadataURI,
        string memory tokenLogo,
        string memory tokenDescription,
        Socials memory tokenSocials,
        address initialHolder,
        address initialOwner,
        address positionGraduationSource,
        uint256 configuredGraduationThreshold
    )
        RevShareHolderRewardToken(
            tokenName, tokenSymbol, tokenDecimals, tokenSupply, tokenMetadataURI, tokenLogo, tokenDescription, tokenSocials, initialHolder, initialOwner
        )
    {
        require(positionGraduationSource != address(0), "Graduation source zero");
        graduationSource = positionGraduationSource;
        graduationThreshold =
            configuredGraduationThreshold == 0 ? DEFAULT_GRADUATION_THRESHOLD : configuredGraduationThreshold;
    }

    function checkGraduation() external returns (bool) {
        if (isGraduate) return true;
        uint256 nativeLiquidity = getCurve();
        if (nativeLiquidity >= graduationThreshold) {
            isGraduate = true;
            emit Graduated(graduationSource, nativeLiquidity, graduationThreshold);
        }
        return isGraduate;
    }

    /// @notice Current native-side ETH value reported for this token's specific V3/V4 position.
    function getCurve() public view returns (uint256) {
        return IRevShareGraduationSource(graduationSource).graduationNativeLiquidity();
    }

    /// @notice Whole-number graduation progress from 0 to 100, permanently capped at 100 after graduation.
    function checkCurveProgress() public view returns (uint256) {
        if (isGraduate) return 100;
        uint256 nativeLiquidity = getCurve();
        if (nativeLiquidity >= graduationThreshold) return 100;

        // Find floor(nativeLiquidity * 100 / graduationThreshold) without overflowing for very large thresholds.
        uint256 low;
        uint256 high = 100;
        while (low + 1 < high) {
            uint256 middle = (low + high) / 2;
            if (nativeLiquidity >= _liquidityRequiredForPercent(middle)) low = middle;
            else high = middle;
        }
        return low;
    }

    function graduationStatus() external view returns (bool graduated, uint256 nativeLiquidity, uint256 threshold) {
        threshold = graduationThreshold;
        if (isGraduate) return (true, threshold, threshold);
        nativeLiquidity = getCurve();
        graduated = nativeLiquidity >= threshold;
    }

    function _liquidityRequiredForPercent(uint256 percent) private view returns (uint256) {
        uint256 whole = (graduationThreshold / 100) * percent;
        uint256 remainder = (graduationThreshold % 100) * percent;
        return whole + ((remainder + 99) / 100);
    }
}
