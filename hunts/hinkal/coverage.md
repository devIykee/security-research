# Coverage — Hinkal Protocol

Coverage: 11/16 core contracts (69%).  

Last updated: adversarial analysis complete (Step 5.5 + 6)

| File | Read? | Paths traced | Notes |
|------|-------|--------------|-------|
| contracts/HinkalBase.sol | yes | commitment creation → nullifier insertion → merkle tree → access control | Core UTXO/nullifier logic |
| contracts/Hinkal.sol | yes | transact() → proof verify → token transfers → balance equation → _internalTransact/_externalTransact → prooflessDeposit() | Main entry point, full flow |
| contracts/Merkle.sol | yes | insert() → insertMany() → tree update paths → rootHashExists() | Merkle tree implementation |
| contracts/MerkleBase.sol | yes | hash2/hash4 → rootHashExists() validation | Merkle base logic |
| contracts/HinkalHelper.sol | yes | performHinkalChecks() → dimensions/relay validation → onChainCreation checks | Validation layer |
| contracts/Transferer.sol | yes | transferERC20TokenOrETH → transferERC20TokenFromOrCheckETH → balance checks | Token transfer logic |
| contracts/VerifierFacade.sol | yes | verifyProof() → verifier dispatch | Proof verification |
| contracts/CircomDataBuilder.sol | partial | getHashedCalldata() → input construction | Calldata hashing |
| contracts/external-actions/ExternalActionBaseV2.sol | yes | runAction() interface → allowedRecipient checks | External action base |
| contracts/external-actions/swaps/ExternalActionSwap.sol | yes | swap() → callRouter() → UTXO creation | Swap implementation |
| contracts/types/CircomData.sol | yes | struct definitions | Data structures |
| circuits/NullifierCalculator.circom | yes | nullifier = Poseidon(commitment, signature) | Nullifier derivation |
| circuits/MainEVMCircuit.circom | yes | full circuit flow → balance equation → merkle proof → signature verification | ZK circuit logic |

## Explicitly excluded

| Path / area | Reason |
|-------------|--------|
| lib/** or node_modules/** | vendored |
| test/** or **/*_test* | tests (exclude unless in scope) |
