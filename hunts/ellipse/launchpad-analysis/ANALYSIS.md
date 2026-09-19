# Bytecode Analysis - 0x66bDC0803807f8a62763943Fb2dd584eD9Fb9C16

**Generated:** Sat Sep 19 09:27:37 WAT 2026
**Bytecode size:** 39087 bytes
**Disassembly lines:** 12419
**Functions found:** 85

## Functions

```
0x022c7ab2 UNKNOWN
0x0442f3ef UNKNOWN
0x0476982d UNKNOWN
0x06fdde03 name()
0x095ea7b3 approve(address,uint256)
0x0a12f521 UNKNOWN
0x0b0d9c09 take(address,address,uint256)
0x0bae8e55 UNKNOWN
0x18160ddd totalSupply()
0x195093b9 UNKNOWN
0x19e4e914 UNKNOWN
0x1fa38694 UNKNOWN
0x23b872dd transferFrom(address,address,uint256)
0x23e1ad83 UNKNOWN
0x29610465 UNKNOWN
0x2b336583 UNKNOWN
0x2d35e7ed UNKNOWN
0x313b65df UNKNOWN
0x313ce567 decimals()
0x391434e3 UNKNOWN
0x392f37e9 metadata()
0x3cf36453 UNKNOWN
0x3f6dc5bb UNKNOWN
0x420ce04e UNKNOWN
0x452a9320 guardian()
0x46ca626b TICK_SPACING()
0x47ecb665 telegram()
0x481c6a75 manager()
0x48c89491 unlock(bytes)
0x4a1406b1 UNKNOWN
0x4b637e8f UNKNOWN
0x4bc31534 FINESTRA()
0x4e487b71 Panic(uint256)
0x4e4f67f1 UNKNOWN
0x5274afe7 SafeERC20FailedOperation(address)
0x5ac4d27e UNKNOWN
0x5db234c9 UNKNOWN
0x5e2d7433 decimalsOf(address)
0x60e80bd3 UNKNOWN
0x673a884a UNKNOWN
0x68a79157 UNKNOWN
0x6ee3f652 UNKNOWN
0x6f2d361d UNKNOWN
0x6f2d3a21 UNKNOWN
0x704b6c02 setAdmin(address)
0x70a08231 balanceOf(address)
0x7284e416 description()
0x73567ec6 TICK_MAX()
0x7b591174 UNKNOWN
0x7dc7a0d9 UNKNOWN
0x7f5a7c7b hook()
0x87b13034 UNKNOWN
0x89ac4147 UPDATE_INTERVAL()
0x89c67a5b UNKNOWN
0x8a0dac4a setGuardian(address)
0x91dd7346 unlockCallback(bytes)
0x9525f07b UNKNOWN
0x95d89b41 symbol()
0x97d00426 UNKNOWN
0x9996b315 AddressEmptyCode(address)
0x9d54f419 setUpdater(address)
0x9f9dd9da UNKNOWN
0xa00c25c4 UNKNOWN
0xa1d0abd6 UNKNOWN
0xa9059cbb transfer(address,uint256)
0xabfaeee0 twitter()
0xad8e95d9 UNKNOWN
0xbeb0a416 website()
0xbebb7177 UNKNOWN
0xc50497ae SUPPLY()
0xc57981b5 FEE()
0xd238826b UNKNOWN
0xdd62ed3e allowance(address,address)
0xdf034cd0 updater()
0xe223759b UNKNOWN
0xe602df05 ERC20InvalidApprover(address)
0xe933dc54 tesoreria()
0xec442f05 ERC20InvalidReceiver(address)
0xefe506c0 UNKNOWN
0xf66f57ee UNKNOWN
0xf851a440 admin()
0xfb44d0e5 UNKNOWN
0xfb7f21eb logo()
0xfbfa77cf vault()
0xffffffff LOCK8605463013()
```

## Critical Patterns

```
=== Uniswap v3 Factory Calls ===

=== Pool Initialize Calls ===

=== External Calls ===
5:00000007: CALLDATASIZE
15:00000014: CALLDATALOAD
329:000002cf: CALLVALUE
333:000002d7: CALLDATASIZE
342:000002e5: CALLDATALOAD
551:000003e2: CALLDATALOAD
558:000003ef: CALLVALUE
562:000003f7: CALLDATASIZE
570:00000404: CALLDATALOAD
599:0000042e: CALLVALUE
603:00000436: CALLDATASIZE
611:00000443: CALLDATALOAD
626:0000045b: CALLER
641:00000474: CALLDATALOAD
674:000004a5: CALLVALUE
678:000004ac: CALLDATASIZE
693:000004c3: CALLVALUE
697:000004ca: CALLDATASIZE
722:000004ed: CALLVALUE
726:000004f4: CALLDATASIZE

=== Storage Writes ===
68
```

## Files Generated

- `bytecode.bin` - Raw bytecode
- `disasm.txt` - Full disassembly
- `selectors.txt` - Function selectors
- `functions.txt` - Decoded functions
- `patterns.txt` - Critical pattern search
