# HINKAL PROTOCOL - BUG HUNT SESSION

## INTAKE

PROJECT_NAME   : Hinkal Protocol
X_HANDLE       : @hinkal_protocol
WEBSITE        : https://hinkal.io/
DOCS           : https://hinkal-team.gitbook.io/hinkal
DISCLOSURE     : HackenProof (https://hackenproof.com/programs/hinkal-bug-bounty)
CHAIN          : Ethereum (primary target)
RPC            : https://eth.llamarpc.com
CHAIN_ID       : 1
EXPLORER       : https://etherscan.io
KNOWN_ADDRS    : Hinkal.sol=0x7cb60446d7635C68EDf1c568cac74A1f98c1Cfa4, HinkalWallet.sol=0xB24043ebDC72ddC1923ec749cFBDFbEfF3FC82f6, HinkalHelper.sol=0x62Af1392aF5376c76d4437598C3E925E66fB03F5
PRODUCT_TYPE   : privacy-protocol (ZK-proof based private transactions/UTXOs)
BOUNTY/CONTEST : HackenProof ongoing bug bounty (severity-based rewards)
RESEARCHER     : deviykee

## NOTES
- Privacy protocol using zero-knowledge proofs (Circom/Groth16)
- UTXO-based shielded balance system
- Multi-chain deployment (Ethereum, Arbitrum, Polygon, Base, BNB, Solana, Tron)
- 6 security audits completed (zkSecurity, Zokyo, Quantstamp, Secure3, Hexens, Neodyme)
- $500M+ transaction volume processed
- Source: https://github.com/ThankGodontt/Hinkal-Contracts-Circuits--004
- 61 total Solidity files (16 core contracts, 45 interfaces/types/verifiers)

## HUNT PROGRESS

### Step 1 - Ground Truth
- [ ] Verify RPC and contracts are live on Ethereum mainnet
- [ ] Check code verification status on Etherscan

### Step 2 - Locate Core Contracts
- [x] Found core contracts addresses from docs
- [x] Found source code repository

### Step 3 - Verification Gate + Surface Map
- [ ] Pull verified source from Etherscan/Sourcify
- [ ] Map contract architecture
- [ ] Set Y denominator in coverage.md

### Step 4 - Auth Triage
- [ ] Test access controls on privileged functions

### Step 5 - Foundation Map
- [ ] State who-writes analysis
- [ ] External call order (CEI)
- [ ] Token paths (entry → exit)
- [ ] Access control gates table

### Step 5.5 - Multi-angle Adversarial Pass
- [ ] Malicious actor (payout paths)
- [ ] Economic and math (ZK proof verification, UTXO accounting)
- [ ] State and access control
- [ ] Edges and gas limits
- [ ] External integrations

### Step 6 - Product-Specific Attack Questions
Privacy protocol specific:
- [ ] Can attacker forge ZK proofs?
- [ ] Can attacker spend others' UTXOs?
- [ ] Double-spend vulnerabilities?
- [ ] Merkle tree manipulation?
- [ ] Front-running shielded transactions?
- [ ] Privacy leakage (linking deposits/withdrawals)?
- [ ] Relay/fee manipulation?
- [ ] External action adapter vulnerabilities?

### Steps 7-10
- [ ] Fork PoC for any findings
- [ ] Severity assessment
- [ ] Report generation
- [ ] Disclosure via HackenProof

## KILLED PATHS
(Track false positives here)

## FINDINGS
(Track confirmed vulnerabilities here)
