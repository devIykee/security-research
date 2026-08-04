# Assembly & Opcode Security Checklist

## CREATE / CREATE2

### CREATE2 Metamorphic Contracts
- [ ] **CREATE2 + selfdestruct = arbitrary code replacement**: A contract deployed via CREATE2 can be `selfdestruct`-ed and redeployed with COMPLETELY DIFFERENT code at the same address. This is the fundamental rug-pull/audit-bypass vector. The new contract has FRESH storage. Look for: any contract with `selfdestruct` deployed via CREATE2, or factories that use CREATE2 with deployable bytecode. [mixbytes CREATE2]

- [ ] **Four states of a CREATE2 address**: (1) Pre-deployment: no code, no storage. (2) Deployed: has code + storage. (3) Self-destructed (same tx): code/storage still accessible until tx ends. (4) Self-destructed (next tx): no code, no storage — re-deployable. Look for: code that assumes contract addresses are permanent identities. [mixbytes CREATE2]

- [ ] **CREATE2 address collision attack**: With ~2^80 work (birthday attack), an attacker can find a CREATE2 salt that produces the same address as an existing contract. At current compute costs, this is expensive but feasible for high-value targets (~$10B+). Look for: high-value contracts that don't verify code hash. [mixbytes CREATE2]

- [ ] **Factory deploying via CREATE inside CREATE2**: A CREATE2-deployed factory uses CREATE internally. The factory's nonce resets on redeployment, so the CREATE-deployed child also gets the same address with potentially different code. This is an indirect metamorphic pattern. Look for: CREATE2-deployed contracts that themselves deploy other contracts. [mixbytes CREATE2]

- [ ] **Bytecode verification not sufficient**: Verifying `extcodehash` at one point doesn't prevent future redeployment with different code. Must verify at time of use, not at time of registration. Look for: one-time code hash checks used for ongoing trust. [mixbytes CREATE2]

### EXTCODESIZE / isContract Bypass
- [ ] **`extcodesize == 0` during constructor**: While a contract's constructor is executing, `extcodesize(address(this)) == 0`. Any check like `require(!isContract(msg.sender))` is bypassed by calling from a constructor. Look for: `isContract()`, `Address.isContract()`, or direct `extcodesize` checks as access control. [mixbytes CREATE2, SWC-112]

- [ ] **Pre-deployed CREATE2 address has no code**: Before deployment, a CREATE2 address is just a number — no code exists there. `extcodesize == 0`, `codehash == 0`. If you whitelist this address and later check `isContract()`, it fails until deployed. Look for: address whitelisting before actual deployment. [mixbytes CREATE2]

- [ ] **`extcodecopy` from self-destructed contract returns empty**: After `selfdestruct` in the same transaction, `extcodesize` still returns the old size, but in the next transaction, it returns 0. Look for: code that copies/checks code from contracts that might self-destruct. [mixbytes CREATE2]

## Inline Assembly Math

- [ ] **Division by zero returns 0 in Yul**: `div(x, 0)`, `sdiv(x, 0)`, and `mod(x, 0)` all return 0 in assembly, instead of reverting like Solidity. This silently produces wrong results. Look for: any `div`, `sdiv`, `mod`, `smod` in assembly without prior zero-check on denominator. [beirao M-12, SWC-101]

- [ ] **No overflow/underflow protection in assembly**: Assembly `add`, `sub`, `mul` silently wrap on overflow/underflow. Unlike Solidity ≥0.8 checked math, assembly never reverts. Look for: arithmetic in `assembly { }` blocks with user-influenced values. [beirao M-10]

- [ ] **`shr` and `shl` with shift ≥ 256 returns 0**: Unlike some languages where shifting by >= bit-width is undefined, EVM returns 0. This is usually correct but can be surprising. Look for: shift amounts derived from user input. [SWC-101]

- [ ] **`signextend` misunderstanding**: `signextend(b, x)` extends the sign bit from byte `b` of `x`. Off-by-one on `b` (0-indexed from the least significant byte) produces wildly wrong results. Look for: `signextend` usage, verify `b` parameter is correct for the intended type width. [SWC-101]

## Memory & Calldata in Assembly

- [ ] **Memory expansion gas cost is quadratic**: Memory cost = `3 * words + words² / 512`. A single `mstore` at offset `2^32` costs ~32 billion gas. Any user-controlled memory offset is a gas bomb. Look for: `mstore(userOffset, ...)` or `mload(userOffset)` where offset isn't bounded. [SWC-101]

- [ ] **Free memory pointer manipulation**: If assembly code overwrites `mload(0x40)` (free memory pointer) incorrectly, subsequent Solidity code writes to wrong memory locations. Look for: assembly blocks that modify memory at `0x40` or below `mload(0x40)` without restoring. [SWC-101]

- [ ] **Returndata buffer reuse**: After an external call, `returndatasize` and `returndatacopy` reflect the LAST call's return data. A subsequent assembly block may read stale returndata from a previous call. Look for: `returndatacopy` without checking which call's data it references. [SWC-101]

- [ ] **`calldataload` beyond calldata returns 0**: Reading past `calldatasize()` returns zero-padded data. This can mask missing parameters. Look for: `calldataload` without bounds checking against `calldatasize`. [SWC-101]

## Low-Level Calls

- [ ] **`call()` to non-existent contract returns success**: A low-level `call` to an address with no code returns `success = true` with empty returndata. Solmate's `SafeTransferLib` has this vulnerability (doesn't check code existence). Look for: `.call()` without checking target has code, or Solmate SafeTransferLib with potentially-empty addresses. [beirao G-08, SWC-101]

- [ ] **`delegatecall` preserves `msg.sender` and `msg.value`**: Inside a `delegatecall`, `msg.sender` is the ORIGINAL caller, not the calling contract. `msg.value` is also preserved (the same ETH can be "spent" multiple times via delegatecall loops). Look for: `delegatecall` in functions that check `msg.value` for payment. [SWC-112]

- [ ] **Return bomb attack**: A malicious contract can return enormous data (e.g., 1MB). If the caller copies all return data to memory (`returndatacopy(0, 0, returndatasize())`), the memory expansion cost can DoS the caller. Fix: limit returndata copy size. Look for: unbounded `returndatacopy` or Solidity `abi.decode` on untrusted external call returns. [beirao G-13]

- [ ] **Gas forwarding with 63/64 rule (EIP-150)**: A `call` forwards at most 63/64 of remaining gas. With ~350K gas remaining, a nested call gets ~344K, leaving ~6K for the caller to finish execution. This can cause the outer call to succeed but the inner call to fail. Look for: nested calls where gas remaining after the inner call is critical. [SWC-126]

## Compiler & EVM Version Quirks

- [ ] **`PUSH0` not supported pre-Shanghai**: Solidity ≥0.8.20 uses `PUSH0` by default (Paris EVM target). Deploying this bytecode on chains without Shanghai (some L2s, BSC before upgrade) causes deployment failure. Look for: Solidity ≥0.8.20 compiled with default EVM target deployed to non-Shanghai chains. [multichain-auditor]

- [ ] **`address.code.length` returns 0 during constructor**: Same as `extcodesize` — during construction, the contract has no code. But unlike assembly, `address(this).code.length == 0` in Solidity looks like a Solidity-level check that should work. Look for: `address(this).code.length` in constructors or `isContract` library calls. [beirao G-14]

- [ ] **`type(uint8).max` = 255, not 256**: Off-by-one when using type max values. `type(uint8).max + 1` overflows. Look for: loop counters or array indices using `type(uintN).max` as upper bound without careful comparison. [SWC-101]

- [ ] **Dirty upper bits in assembly**: When loading from storage or calldata in assembly, upper bits may contain garbage from previous operations. Always mask with `and(value, 0xff)` for uint8, `and(value, 0xffff)` for uint16, etc. Look for: assembly reads that assume clean upper bits without masking. [SWC-101]

## Precompile Interactions

- [ ] **ecrecover (0x01) gas cost varies by input**: Invalid inputs cause full gas consumption. If ecrecover is called in a loop with potentially-invalid data, gas exhaustion occurs. Look for: ecrecover calls with unbounded loop over user data. [SWC-113]

- [ ] **modexp (0x05) gas cost can be enormous**: Modular exponentiation precompile gas depends on exponent size. User-supplied exponents can cause massive gas consumption. Look for: modexp calls with user-controlled exponent length. [SWC-113]

- [ ] **Precompile address range differs by chain**: Addresses 0x01-0x09 are precompiles on mainnet. Other chains add custom precompiles at different addresses. Calling a non-existent precompile returns success with empty data. Look for: hardcoded precompile addresses in multi-chain deployments. [multichain-auditor]

## CREATE/CREATE2 Deep Dive (Expanded from MixBytes)

- [ ] **CREATE2 + selfdestruct enables metamorphic contracts**: A contract deployed via CREATE2 can call `selfdestruct`, then be redeployed at the same address with DIFFERENT bytecode (same salt, but different init_code via a factory that reads code from storage). This allows "upgrading" contracts that appear immutable. Pre-Dencun only (EIP-6780 limits selfdestruct in same-tx). Look for: CREATE2-deployed contracts with `selfdestruct` capability where the factory's init code is mutable. [MixBytes CREATE2]

- [ ] **EXTCODESIZE returns 0 during construction**: A contract's code size is 0 while its constructor is executing. This means `isContract()` checks based on `extcodesize` return false during construction — an attacker can call protected functions from their constructor. Look for: `extcodesize(account) > 0` used as an EOA-vs-contract check. [MixBytes CREATE2, beirao G-14]

- [ ] **CREATE2 address prediction with different bytecode**: The CREATE2 address depends on the init_code hash. If a factory stores the implementation address and the init code reads it dynamically, the salt can remain the same while deploying completely different logic. Look for: CREATE2 factories where the initialization code references mutable state. [MixBytes CREATE2]

- [ ] **CREATE nonce dependency — reorg vulnerability**: With CREATE, the deployed address depends on the sender's nonce. A chain reorg can change the nonce, causing the contract to deploy at a different address. Users who sent funds to the pre-computed address lose them. Look for: address precomputation using CREATE (nonce-dependent) without reorg protection. [beirao G-19, MixBytes CREATE2]

## Inline Assembly Pitfalls (Expanded)

- [ ] **Assembly `div(x, 0)` returns 0 (no revert)**: Unlike Solidity, Yul's `div(x, 0)` silently returns 0 instead of reverting. Unchecked division by zero in assembly produces incorrect results without any error. Look for: `div()` in assembly blocks where the divisor could be zero. [beirao M-12]

- [ ] **Assembly arithmetic silently overflows/underflows**: In inline assembly, there are no overflow checks. `add(type(uint256).max, 1)` wraps to 0. Look for: arithmetic operations in assembly blocks without explicit overflow checks. [beirao M-12]

- [ ] **Memory operations in assembly can corrupt Solidity's free memory pointer**: If assembly writes to memory without updating the free memory pointer (`mload(0x40)`), subsequent Solidity operations may overwrite the assembly data. Look for: assembly blocks that use `mstore` without being "memory-safe" annotated. [Tamjid C13]

- [ ] **`chainid()` and `extcodesize()` available without assembly since Solidity 0.8**: Using assembly for `chainid` or `extcodesize` is unnecessary in modern Solidity and adds audit complexity. `block.chainid` and `address.code.length` work natively. Look for: assembly blocks used for operations available as Solidity builtins. [Tamjid C37]

---

## Dacian — Solidity Inline Assembly Vulnerabilities (Phase 3)

- [ ] **Memory corruption from external call overwriting assembly-stored variables**: Manual assembly stores values at NFMA (0x80, 0xa0...) but doesn't update the free memory pointer (0x40). When a subsequent external call occurs, Solidity reads stale FMPA, overwrites stored variables with call setup data and return values. Fix: `mstore(0x40, dataPtr)` after assembly allocations before any external call. [Source: Dacian — Inline Assembly Vulnerabilities, OpenZeppelin Scroll Phase 1]

- [ ] **Assuming unchanged free memory pointer between assembly blocks**: Normal Solidity code between assembly blocks updates FMPA. If the final assembly block reads FMPA assuming it still points to where inputs were stored, it will hash wrong memory regions (possibly empty). Fix: save start pointer in a variable, don't rely on FMPA in later blocks. [Source: Dacian — Inline Assembly Vulnerabilities]

- [ ] **Memory corruption from insufficient allocation (off-by-32)**: If `init()` allocates `capacity` bytes but `write()` expects `capacity + 32` (for length prefix), writes overflow into adjacent memory variables. The ENS Buffer library had this: writing "A" corrupted `foo.length` stored immediately after the buffer. [Source: Dacian — Inline Assembly Vulnerabilities, ConsenSys ENS Audit]

- [ ] **External call to non-existent contract always succeeds in assembly**: Low-level `staticcall`/`call` to an address without code (EOA) returns success=1 with no output. If the code reads previous memory as the "return value", it can interpret stale valid data as a successful response. Fix: check `extcodesize(target) > 0` before call, and verify `returndatasize() == expected`. [Source: Dacian — Inline Assembly Vulnerabilities, samczsun 0x vulnerability]

- [ ] **Overflow/underflow in inline assembly — no automatic checks**: Assembly `add`, `sub`, `mul` have no overflow protection. `add(type(uint256).max, 1)` silently returns 0. Manual overflow check: `if lt(result, input) { revert(0,0) }`. [Source: Dacian — Inline Assembly Vulnerabilities]

- [ ] **uint128 overflow evades detection because assembly uses 256-bit words**: For `uint128` parameters, `add(type(uint128).max, 1)` in assembly returns a 256-bit value that's > input (passing the `lt` check), but when returned as `uint128` it silently overflows to 0. Fix: use `addmod` with N=type(uint128).max, or add Solidity-level `require()` after the assembly block. [Source: Dacian — Inline Assembly Vulnerabilities, Trail of Bits Primitive Hyper]
