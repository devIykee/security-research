# Coverage — RadarDEX

Coverage: 1/5 files (20%).

Last updated: Step 7 - PoC verification complete

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| LaunchFactory V3 | yes | launch() → createPool() → initialize() → mint() → lockPosition() | Full bytecode decompilation, critical vulnerability found |
| FeeSplitLocker V3 | no | - | Target: 0x4a893FD3c527eDbAB8F8580fd92B0EDe9C19DC7E (not required for Critical finding) |
| Reflection Launch Factory | no | - | Target: 0x2d933Ce4bDe6F3d99540b5D7886b383E59b2b2F8 (separate finding area) |
| Reflection Locker | no | - | Target: 0x8Ce980d8357E404bfd86456c464Dd046E7c517F8 (separate finding area) |
| RadarLocker | no | - | Target: 0x533486837A04A8Ca83BE1e6852044436c9ba677e (not required for Critical finding) |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| Legacy V1/V2 contracts | Focusing on current V3 production |
| Swap routers | Standard Uniswap integration, lower priority |
| Token implementations | Standard ERC20, verified in testing |

## Notes on Coverage
This audit focused on the LaunchFactory V3 contract launch flow, which is the critical path for token creation and liquidity provisioning. A **CRITICAL** pool squat vulnerability was confirmed through bytecode decompilation and fork-based testing. Additional contract analysis (FeeSplitLocker, Reflection mechanisms) was deprioritized after discovering this high-severity issue that requires immediate remediation.
