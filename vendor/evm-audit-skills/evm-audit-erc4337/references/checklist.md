# ERC4337 Account Abstraction Security Checklist

## Wallet Account Factory

- [ ] **Factory must use CREATE2**: Factories using CREATE have nonce-dependent deployment. Reorgs change the nonce, deploying the wallet at a different address. Users who sent funds to the pre-computed address lose them. Look for: factory using `new Wallet()` without `salt`. [ERC4337 checklist]

- [ ] **Factory must return address even if already deployed**: If `createAccount()` reverts when the wallet exists, it breaks bundler workflows. The factory must return the deterministic address whether the wallet exists or not. Look for: factory createAccount that reverts on existing accounts. [ERC4337 checklist]

- [ ] **Attacker deploys wallet with different credentials**: If the generated wallet address doesn't depend on the initial owner/signature, an attacker can deploy the wallet first with their own keys and control it. The initial signature MUST be part of the CREATE2 salt. Look for: CREATE2 salt that doesn't include owner address or initial signer. [Code4rena/Biconomy H-03]

- [ ] **Factory stake unstakeDelay griefing**: If anyone can add stake to the factory's entrypoint, they can set `unstakeDelay` to `type(uint256).max`, permanently preventing unstaking. Look for: factory stake functions without access control on delay parameter. [ERC4337 checklist]

## Wallet Account

- [ ] **Implementation contract initializable by attacker**: If the implementation contract's `initialize()` isn't called or protected, an attacker can front-run initialization and gain ownership. On UUPS implementations, this can lead to `selfdestruct` of the implementation, bricking all proxies. Look for: implementation contracts without `_disableInitializers()` in constructor. [Code4rena/Biconomy H-01, Ambire M-05]

- [ ] **Direct execution bypasses EntryPoint**: If the wallet can execute transactions directly (not through EntryPoint), it must re-implement all validation (signature, nonce, gas). Missing any check enables arbitrary execution. Look for: `execute()` functions callable without going through EntryPoint that lack full signature validation. [Code4rena/Biconomy H-04]

- [ ] **`validateUserOp` must return SIG_VALIDATION_FAILED, not revert**: Per spec, signature mismatches should return the sentinel value `SIG_VALIDATION_FAILED`. Reverting breaks bundler behavior and wastes gas. Look for: `revert` in `validateUserOp` for invalid signatures. [ERC4337 checklist]

- [ ] **ERC-1271 cross-account signature replay**: If `isValidSignature()` checks that "any owner has signed the hash" without binding to the specific account (via EIP-712 with `verifyingContract = address(this)`), signatures can be replayed across accounts that share owners. Look for: `isValidSignature` that doesn't alter the hash with the account address. [ERC4337 checklist]

- [ ] **`tx.origin` breaks for smart wallets**: Applications that use `require(tx.origin == msg.sender)` to block contracts will block all smart wallets. Applications must not rely on this pattern. Look for: `tx.origin == msg.sender` checks. [ERC4337 checklist]

- [ ] **Fixed gas assumptions (21000 for transfer)**: Smart wallet transactions cost more than 21000 gas. Applications relying on exact gas costs will underestimate for AA wallets. Look for: hardcoded gas estimates like 21000. [ERC4337 checklist]

## Paymaster

- [ ] **VerifyingPaymaster signature replay**: If the paymaster's signed approval doesn't include nonce, chain ID, and sender, the signature can be replayed to drain the paymaster's deposit. Look for: paymaster validation hash that omits any of: sender, nonce, chainid, validUntil, validAfter. [Code4rena/Biconomy H-05]

- [ ] **Cross-chain paymaster replay**: If the paymaster signature doesn't include chain ID, it can be used on any chain where the paymaster is deployed. Look for: missing `block.chainid` in paymaster signature hash. [Code4rena/Biconomy M-03]

- [ ] **EntryPoint v0.6 postOp bug**: A bug in v0.6 causes short revert messages in `postOp()` to revert the entire bundle instead of calling the second `postOp()`. Look for: v0.6 entrypoint integration with custom postOp logic. [ERC4337 checklist]

- [ ] **DoS via free transactions**: Paymasters enable gas-free transactions. An attacker can spam transactions through the paymaster to drain its deposit. Look for: paymasters without rate limiting or sender validation. [beirao AA-01]

## Session Keys & Modules

- [ ] **Session key exposure on frontend**: Session signer wallet private keys exposed in frontend JavaScript allow account takeover (Cardex compromise). Look for: session key generation or storage in client-side code. [ERC4337 checklist]

- [ ] **Module storage overlap with delegatecall**: If the wallet uses `delegatecall`-based modules, module storage must not overlap with wallet storage. Look for: modules using storage slots that conflict with ERC1967 proxy slots or wallet state. [ERC4337 checklist]

- [ ] **Fallback handler set to `address(this)`**: If the wallet's fallback handler can be set to the wallet itself, it creates a self-referencing loop that can be exploited. Look for: fallback handler setter without `handler != address(this)` check. [Code4rena/Ambire L-02]

## ERC-6492 & Predeploy Signatures

- [ ] **Predeploy contract signature validation**: Applications verifying signatures from smart wallets should support ERC-6492 for wallets not yet deployed. Without it, counterfactual wallet signatures fail verification. Look for: `isValidSignature` callers that don't handle ERC-6492 wrapper format. [ERC4337 checklist]
