# evm-audit-assembly — PARTIAL (Opus Knows Concept, Not Specifics)

*Generated: 2026-02-28 | Items: 5*

⚠️  Opus knows the general class but not the specific protocol/version/formula detail.

- [ ] **`extcodecopy` from self-destructed contract returns empty**: After `selfdestruct` in the same transaction, `extcodesize` still returns the old size, but in the next transaction, it returns 0. Look for: code that copies/checks code from contracts that might self-destruct. [mixbytes CREATE2]

- [ ] **`signextend` misunderstanding**: `signextend(b, x)` extends the sign bit from byte `b` of `x`. Off-by-one on `b` (0-indexed from the least significant byte) produces wildly wrong results. Look for: `signextend` usage, verify `b` parameter is correct for the intended type width. [SWC-101]

- [ ] **Memory corruption from external call overwriting assembly-stored variables**: Manual assembly stores values at NFMA (0x80, 0xa0...) but doesn't update the free memory pointer (0x40). When a subsequent external call occurs, Solidity reads stale FMPA, overwrites stored variables with call setup data and return values. Fix: `mstore(0x40, dataPtr)` after assembly allocations before any external call. [Source: Dacian — Inline Assembly Vulnerabilities, OpenZeppelin Scroll Phase 1]

- [ ] **Memory corruption from insufficient allocation (off-by-32)**: If `init()` allocates `capacity` bytes but `write()` expects `capacity + 32` (for length prefix), writes overflow into adjacent memory variables. The ENS Buffer library had this: writing "A" corrupted `foo.length` stored immediately after the buffer. [Source: Dacian — Inline Assembly Vulnerabilities, ConsenSys ENS Audit]

- [ ] **uint128 overflow evades detection because assembly uses 256-bit words**: For `uint128` parameters, `add(type(uint128).max, 1)` in assembly returns a 256-bit value that's > input (passing the `lt` check), but when returned as `uint128` it silently overflows to 0. Fix: use `addmod` with N=type(uint128).max, or add Solidity-level `require()` after the assembly block. [Source: Dacian — Inline Assembly Vulnerabilities, Trail of Bits Primitive Hyper]

