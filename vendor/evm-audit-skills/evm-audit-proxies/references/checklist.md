# Proxy & Upgrade Security Checklist

## UUPS Proxy
- [ ] **`_authorizeUpgrade()` MUST have access control**: If `authorizeUpgrade()` has no `onlyOwner` or equivalent check, anyone can upgrade the implementation to a malicious contract. This is the #1 UUPS bug. Look for: `_authorizeUpgrade` function body that's empty or lacks access checks. [beirao P-04]
- [ ] **`disableInitializers()` in implementation constructor**: Without this, an attacker calls `initialize()` on the implementation contract directly, gaining ownership. On UUPS, they can then upgrade to a contract with `selfdestruct`, destroying the implementation and bricking all proxies. Look for: implementation contracts without `constructor() { _disableInitializers(); }`. [beirao P-06]
- [ ] **No `selfdestruct` or `delegatecall` in implementation**: `selfdestruct` in the implementation runs in the proxy's context, destroying the proxy permanently. `delegatecall` to untrusted targets from the implementation is equally dangerous. Look for: `selfdestruct` or `delegatecall` in any implementation contract code path. [beirao P-07]
- [ ] **Immutable variables lost on upgrade**: `immutable` values are stored in bytecode, not storage. A new implementation = new bytecode = new immutable values. The old values are lost. Look for: `immutable` declarations in upgradeable contracts that should persist across upgrades. [beirao P-08]
- [ ] **Storage variable order/type CANNOT change**: Adding, removing, reordering, or changing the type of storage variables between implementations corrupts existing data. Only append at the end. Look for: diff between old and new implementation's storage layout. [beirao P-09]
- [ ] **Storage gaps for inheritance hierarchies**: Parent contracts in upgradeable systems MUST declare `uint256[50] private __gap` to reserve slots. Without gaps, adding a variable to a parent shifts all child storage. Look for: inherited contracts without `__gap` declarations. [beirao P-05]

## Initialization
- [ ] **No constructor in proxy implementations**: Constructors run in the implementation's context, not the proxy's. State set in a constructor is invisible to the proxy. Use `initializer` modifier instead. Look for: `constructor()` in proxy implementation contracts that sets state. [beirao P-01]
- [ ] **Use upgradeable versions of inherited contracts**: `ReentrancyGuard`, `Pausable`, `ERC20`, `Ownable` all have constructors. In upgradeable contexts, use `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, etc. which use `__init()` functions. Look for: non-upgradeable OZ imports in upgradeable contracts. [beirao P-03]
- [ ] **Deployer must call initialize**: If `initialize()` isn't called in the deployment transaction, anyone can front-run and initialize with attacker-controlled parameters. Check deployment scripts for initialization calls. Look for: deployment scripts that separate deploy and initialize into different transactions. [beirao P-02]
- [ ] **Initializable storage slot reuse**: When converting an account to a different type via proxy (e.g., switching smart wallet implementations), the `_initialized` slot can be reused, allowing re-initialization. Look for: proxy upgrades that change the base contract type. [ERC4337 checklist, OZ issue #4782]

## Transparent Proxy
- [ ] **Function selector clashing**: If a function in the proxy has the same 4-byte selector as a function in the implementation, the proxy function takes precedence for admin calls. This can lock admin out of upgrade capability or expose unintended admin functions. Look for: proxy admin functions with common selector patterns. [beirao P-10]

## Metamorphic Contracts (CREATE2 + selfdestruct)
- [ ] **CREATE2 + selfdestruct = redeployment with different bytecode**: After Constantinople, a contract at a CREATE2 address can be self-destructed and redeployed with completely different code. This is a rug pull vector: deploy a safe contract, get audited, then redeploy malicious code at the same address. Look for: contracts with `selfdestruct` deployed via CREATE2. [mixbytes CREATE2]
- [ ] **4 contract states**: Not-yet-deployed → deployed → self-destructed → redeployed. The redeployed contract has fresh storage and can have different logic. Look for: systems that trust contract addresses as identity without verifying code hash. [mixbytes CREATE2]
- [ ] **EXTCODESIZE bypass via pre-deployment address**: Before CREATE2 deployment, the address exists but has no code (`extcodesize == 0`). An `isContract()` check marks it as EOA. Later, code is deployed there, bypassing the "no contracts" restriction. Look for: `isContract()` or `extcodesize` checks on addresses that could receive CREATE2 deployments. [mixbytes CREATE2]
- [ ] **`isContract()` bypass via constructor execution**: During constructor execution, `extcodesize(address(this)) == 0`. An attacker deploys a contract whose constructor calls the target, passing the `isContract` check. Look for: `extcodesize`-based access control as the sole defense against contract callers. [mixbytes CREATE2, beirao G-14]

## Storage Collision Patterns
- [ ] **Cross-slot boundary off-by-one**: When packing multiple values into 32-byte storage slots, off-by-one at the slot boundary (e.g., `tokenIndex > 4` should be `>= 4` for second slot) causes reading from the wrong slot. Look for: index-based access to packed storage with boundary checks. [ERC4626 primer pattern #64]
- [ ] **Multiplier/weight index misalignment**: When weights and their multipliers are packed in sequence across slots, the index offset for multipliers must exactly match. Misalignment means wrong multipliers for tokens at boundary positions. Look for: packed storage with paired data (weight + multiplier) across slots. [ERC4626 primer pattern #65]
- [ ] **Variable name collisions in FunC/Solidity**: In FunC (TON) variables can be redeclared. In Solidity, shadowing inherited state variables creates distinct storage slots while appearing to reference the same variable. Look for: state variable declarations that shadow parent contract variables. [SWC-119]

## Proxy Patterns (Expanded from Beirao/Multichain-Auditor)

- [ ] **Storage collision between old and new implementations**: If a new implementation adds storage variables in different positions or changes variable types, it corrupts existing storage. When parent contracts are inherited, use storage gaps (`uint256[50] __gap`). Look for: upgraded implementations without gap variables or with reordered storage. [beirao P-05, P-09]

- [ ] **Immutable variables not preserved across upgrades**: Values set in `immutable` variables are compiled into the bytecode, not stored in storage. When the implementation is upgraded, all immutable values from the old implementation are lost. Look for: `immutable` variables in upgradeable contracts. [beirao P-08]

- [ ] **`selfdestruct` and `delegatecall` in implementation contracts**: If the implementation calls `selfdestruct`, it destroys the implementation, bricking ALL proxies that point to it. `delegatecall` in implementations can be used to call `selfdestruct` indirectly. Post-Dencun, `selfdestruct` only sends ETH without destroying the contract, but on pre-Dencun chains/L2s it still destroys. Look for: `selfdestruct` or unprotected `delegatecall` in implementation contracts. [beirao P-07]

- [ ] **No constructor in implementation contracts**: Constructors don't run in the proxy's context. Any initialization logic in a constructor only affects the implementation's storage, not the proxy's. Look for: constructors that set state variables in upgradeable contracts (should use `initialize()` instead). [beirao P-01]

- [ ] **Forgot to call `initialize()` after deployment**: If the deployer doesn't call `initialize()` on the proxy, an attacker can call it first and gain ownership. Check deployment scripts. Look for: deployment flows where `initialize()` isn't called atomically with proxy deployment. [beirao P-02]

- [ ] **Using non-upgradeable base contracts**: If an upgradeable contract inherits from `ReentrancyGuard`, `Pausable`, `ERC20` etc. (non-upgradeable versions), their constructors run in the wrong context. Must use `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, etc. Look for: non-upgradeable OZ imports in upgradeable contracts. [beirao P-03]

- [ ] **Function clashing in transparent proxies**: If the implementation has a function with the same selector as a proxy admin function, the proxy intercepts it. On transparent proxies, this is mitigated by the admin/non-admin routing, but on minimal proxies or UUPS it can cause issues. Look for: function selectors that collide with proxy management functions. [beirao P-10]

- [ ] **Metamorphic contract rug via CREATE2**: A contract deployed via CREATE2 can be destroyed (pre-Dencun) and redeployed with different bytecode at the same address. An attacker can get a contract audited, deployed, then re-deploy malicious code at the same address. Look for: any trust placed in a CREATE2-deployed contract without ongoing bytecode verification. [beirao P-10, MixBytes CREATE2]

- [ ] **Proxy contract upgradability differs across chains**: A contract may be upgradeable on one chain (e.g., USDT on Polygon) but immutable on another (USDT on Ethereum). Cross-chain protocols must account for this asymmetry. Look for: multichain systems that assume consistent upgradability. [multichain-auditor]

---

## RareSkills — UUPS Proxy Deep Dive (Phase 3)

- [ ] **Uninitialized implementation contract — anyone becomes owner**: If `initialize()` is a public function on the implementation (intended to be called through proxy), anyone can call it directly on the implementation contract to become its "owner". Both the proxy-set owner and the implementation-set owner then pass `onlyOwner` checks. Fix: always call `_disableInitializers()` in constructor. [Source: RareSkills — UUPS Proxy]

- [ ] **Delegatecall to selfdestruct in UUPS implementation**: If implementation contains or can be tricked into delegatecalling to a contract with `selfdestruct`, the proxy is destroyed. OpenZeppelin UUPS v4.1.0-v4.3.1 was vulnerable to this combination: uninitialized implementation + upgradeToAndCall with delegatecall to selfdestruct target. [Source: RareSkills — UUPS Proxy, OpenZeppelin Advisory]

- [ ] **Breaking the upgrade chain by deploying non-UUPS implementation**: Since UUPS upgrade logic lives in the implementation, upgrading to a contract without `upgradeToAndCall()` or `proxiableUUID()` permanently bricks the proxy — no further upgrades possible. The `proxiableUUID()` check in `_upgradeToAndCallUUPS` exists specifically to prevent this. [Source: RareSkills — UUPS Proxy]

- [ ] **Overriding upgradeToAndCall breaks upgrade functionality**: If a developer overrides `upgradeToAndCall()` in a new implementation and introduces bugs (wrong access control, missing UUPS check), the upgrade mechanism itself is compromised. Be extremely careful with any override. [Source: RareSkills — UUPS Proxy]

- [ ] **Authorization schema change loses access during upgrade**: Switching from simple owner to multi-sig/voting in new implementation, but the multi-sig hasn't been properly initialized or the previous admin already renounced privileges → permanent lock. Verify authorization continuity across upgrades. [Source: RareSkills — UUPS Proxy]
