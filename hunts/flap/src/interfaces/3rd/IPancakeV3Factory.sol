// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IUniswapV3Factory} from "uni-v3-core/interfaces/IUniswapV3Factory.sol";

interface IPancakeV3Factory is IUniswapV3Factory {
    /// @dev returns the deployer
    /// In pancakeswap, the deployer is not the same as the factory
    /// https://github.com/pancakeswap/pancake-v3-contracts/blob/5cc479f0c5a98966c74d94700057b8c3ca629afd/projects/v3-core/contracts/PancakeV3Factory.sol#L14C30-L14C42
    function poolDeployer() external view returns (address);
}
