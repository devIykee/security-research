# Argus Hunt - Analysis Plan

## Current Status
✅ Step 1: Ground truth - RPC confirmed
✅ Step 2: Located ARGUS token (ecosystem token, not factory itself)  
✅ Step 3: Surface map - found key functions
✅ Step 4: Auth triage - all critical functions guarded

## Challenge: No Source Code
- Implementation contract 0x122c82cfca7a3a2227285cc21f4522e8f551db3a is NOT verified
- Must analyze bytecode or find unverified vulnerabilities
- Cannot perform deep code review without source

## Available Approaches

### A. Bytecode Analysis (Limited)
- Can map functions and storage layout
- Cannot see complex logic without decompilation
- Risk: Miss subtle bugs in implementation

### B. Black-box Fuzzing
- Test graduation mechanism with different states
- Look for economic exploits via transaction simulation
- Check pool squat via pre-creating pool before graduate()

### C. Pattern Recognition
- Apply known launchpad vulnerabilities from skill
- Check for common mistakes even without source
- Document trust assumptions

## Decision: Hybrid Approach
1. Document known attack surfaces from bytecode analysis
2. Test pool squat vulnerability (can test without source)
3. Write report on *what we can verify* vs *what needs source audit*
4. Be honest about coverage limitations

## Next: Test Pool Squat Vulnerability
This is testable without source code - we can pre-create a Uniswap V3 pool
and see if graduate() checks the price or blindly uses the existing pool.
