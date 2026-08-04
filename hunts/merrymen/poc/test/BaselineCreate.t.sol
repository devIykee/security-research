// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
interface IPumpClawFactory {
    function createToken(string calldata,string calldata,string calldata,string calldata,uint256,uint256,address) external returns (address,uint256);
}
contract BaselineCreateTest is Test {
    address constant FACTORY = 0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE;
    function test_baseline_create() public {
        vm.deal(address(this), 1 ether);
        (address t, uint256 p) = IPumpClawFactory(FACTORY).createToken("A","B","i","w",1e24,20e18,address(this));
        console.log(t, p);
    }
}
