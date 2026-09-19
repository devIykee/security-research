# Bytecode Analysis - 0x143d72d4bD0F0e1a6C6FD4f2f671A45d9e003a88

**Generated:** Sat Sep 19 09:44:10 WAT 2026
**Bytecode size:** 15611 bytes
**Disassembly lines:** 4530
**Functions found:** 44

## Functions

```
0x01578013 UNKNOWN
0x02669b52 launchpad()
0x05b2aea7 UNKNOWN
0x05ba1177 UNKNOWN
0x08ffe32a UNKNOWN
0x0a12f521 UNKNOWN
0x0ab714fb UNKNOWN
0x0b0d9c09 take(address,address,uint256)
0x1006bae0 UNKNOWN
0x13fca387 UNKNOWN
0x15d7892d UNKNOWN
0x1fed19c1 UNKNOWN
0x21d0ee70 beforeRemoveLiquidity(address,(address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)
0x2529c997 UNKNOWN
0x259982e5 beforeAddLiquidity(address,(address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)
0x2df99c5b UNKNOWN
0x3eae365f UNKNOWN
0x481c6a75 manager()
0x48c89491 unlock(bytes)
0x4e487b71 Panic(uint256)
0x4e993daf UNKNOWN
0x5274afe7 SafeERC20FailedOperation(address)
0x575e24b4 beforeSwap(address,(address,address,uint24,int24,address),(bool,int256,uint160),bytes)
0x5db234c9 UNKNOWN
0x6e4c1aa7 UNKNOWN
0x6fe7e6eb afterInitialize(address,(address,address,uint24,int24,address),uint160,int24)
0x70a08231 balanceOf(address)
0x7a94c565 UNKNOWN
0x8a5746b0 UNKNOWN
0x91dd7346 unlockCallback(bytes)
0x9996b315 AddressEmptyCode(address)
0x9c748f84 UNKNOWN
0xa79513d7 UNKNOWN
0xa9059cbb transfer(address,uint256)
0xb3d281c1 UNKNOWN
0xdc98354e beforeInitialize(address,(address,address,uint24,int24,address),uint160)
0xdd76e50a UNKNOWN
0xe7b0ae41 UNKNOWN
0xe933dc54 tesoreria()
0xefd7f8a1 UNKNOWN
0xf206fcc3 UNKNOWN
0xf28df7f6 UNKNOWN
0xfbfa77cf vault()
0xffffffff LOCK8605463013()
```

## Critical Patterns

```
=== Uniswap v3 Factory Calls ===

=== Pool Initialize Calls ===

=== External Calls ===
6:00000008: CALLDATASIZE
18:00000016: CALLDATALOAD
136:00000111: CALLVALUE
142:0000011a: CALLDATASIZE
166:00000159: CALLVALUE
170:00000160: CALLDATASIZE
181:00000176: CALLDATALOAD
203:00000192: CALLVALUE
209:0000019b: CALLDATASIZE
225:000001d2: CALLVALUE
231:000001db: CALLDATASIZE
252:00000217: CALLVALUE
258:00000220: CALLDATASIZE
274:00000257: CALLVALUE
277:0000025c: CALLDATASIZE
441:00000332: STATICCALL
523:000003bd: CALL
548:000003dd: STATICCALL
798:000005a6: CALL
1127:00000793: CALLVALUE

=== Storage Writes ===
10
```

## Files Generated

- `bytecode.bin` - Raw bytecode
- `disasm.txt` - Full disassembly
- `selectors.txt` - Function selectors
- `functions.txt` - Decoded functions
- `patterns.txt` - Critical pattern search
