# Bytecode Analysis - 0x8366a39CC670B4001A1121B8F6A443A643e40951

**Generated:** Sat Sep 19 09:48:25 WAT 2026
**Bytecode size:** 48021 bytes
**Disassembly lines:** 10419
**Functions found:** 39

## Functions

```
0x01ffc9a7 supportsInterface(bytes4)
0x095bcdb6 transfer(address,uint256,uint256)
0x0b0d9c09 take(address,address,uint256)
0x11da60b4 settle()
0x156e29f6 mint(address,uint256,uint256)
0x1e2eaeaf extsload(bytes32)
0x234266d7 donate((address,address,uint24,int24,address),uint256,uint256,bytes)
0x2d771389 setProtocolFeeController(address)
0x35fd631a extsload(bytes32,uint256)
0x3dd45adb settleFor(address)
0x426a8493 approve(address,uint256,uint256)
0x4323a555 NotEnoughLiquidity()
0x48c89491 unlock(bytes)
0x4f2461b8 InvalidPriceOrLiquidity()
0x52759651 updateDynamicLPFee((address,address,uint24,int24,address),uint24)
0x558a7297 setOperator(address,bool)
0x598af9e7 allowance(address,address,uint256)
0x5a6bcfda modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)
0x6276cbbe initialize((address,address,uint24,int24,address),uint160)
0x7e87ce7d setProtocolFee((address,address,uint24,int24,address),uint24)
0x80f0b44c clear(address,uint256)
0x8161b874 collectProtocolFees(address,address,uint256)
0x8da5cb5b owner()
0x93dafdf1 SafeCastOverflow()
0x97e8cd4e protocolFeesAccrued(address)
0x9bf6645f exttload(bytes32[])
0xa5841194 sync(address)
0xb6363cf2 isOperator(address,address)
0xd4d8f3e6 TickMisaligned(int24,int24)
0xd76453e0 UNKNOWN
0xdbd035ff extsload(bytes32[])
0xf02de3b2 protocolFeeController()
0xf135baaa exttload(bytes32)
0xf2fde38b transferOwnership(address)
0xf3cd914c swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)
0xf5298aca burn(address,uint256,uint256)
0xf5c787f1 PriceOverflow()
0xfe99049a transferFrom(address,address,uint256,uint256)
0xffffffff LOCK8605463013()
```

## Critical Patterns

```
=== Uniswap v3 Factory Calls ===

=== Pool Initialize Calls ===

=== External Calls ===
6:00000008: CALLDATASIZE
16:00000014: CALLDATALOAD
189:00000187: CALLVALUE
194:000001af: CALLDATASIZE
209:000001c9: CALLDATALOAD
216:00000207: CALLDATALOAD
221:0000020c: CALLER
288:00000266: CALLER
328:00000295: CALLER
373:000002f1: CALLER
407:0000031c: CALLER
427:00000335: CALLVALUE
431:0000033d: CALLDATASIZE
454:000003b4: CALLER
462:000003be: CALLER
512:00000414: CALLER
557:00000484: CALLER
591:000004c3: CALLER
614:00000500: CALLVALUE
619:00000529: CALLDATASIZE

=== Storage Writes ===
40
```

## Files Generated

- `bytecode.bin` - Raw bytecode
- `disasm.txt` - Full disassembly
- `selectors.txt` - Function selectors
- `functions.txt` - Decoded functions
- `patterns.txt` - Critical pattern search
