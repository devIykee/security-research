# Security Assessment & Disposition — Pixels

**Researcher:** deviykee  
**Target:** Pixels (Ronin / Ethereum & Web/App)  
**Date:** 2026-10-28  

---

## 1. Scope Evaluation

| Component | Target Address / URL | Status | Disposition |
|---|---|---|---|
| **Ethereum Farm Land** | `0x5c1a0cc6dadf4d0fb31425461df35ba80fcbc110` | 5000/5000 minted out | **Clean / Inactive Attack Surface** |
| **Ronin Farm Land** | `0xf083289535052e8449d69e6dc41c0ae064d8e3f6` | 3,826 tokens; ACL enforced | **Clean** |
| **Ronin Pet** | `0xb806028b6ebc35926442770a8a8a7aeab6e2ce5c` | `publicSaleActive == false` | **Clean** |
| **Ronin $PIXEL Token** | `0x7eae20d11ef8c779433eb24503def900b9d28ad7` | OZ AccessControl ERC20 | **Clean** |
| **Web / App** | `pixels.xyz` / `play.pixels.xyz` | Colyseus server `pixels-server.pixels.xyz` | **No client-side secret leakage** |

---

## 2. Smart Contract Findings & Analysis

### 2.1 Ethereum Farm Land Contract (`PixelsFarmland.sol`)
* **Excess ETH Retention:** The `_purchase(count, price)` function verifies `require(price * count <= msg.value)` but does not refund `msg.value - (price * count)`. Any excess sent is forwarded to the `PaymentSplitter`.
  * *Exploitability / Impact:* Minting is permanently closed (`totalSupply() == 5000 == _maxSupply()`). No caller can trigger this function. Current ETH balance in the contract is 0.00000718 ETH (~$0.02).
  * *Verdict:* **Informational / No Active Risk**.

### 2.2 Ronin Contracts Access Control & State
* **Farm Land (`0xf083289535052e8449d69e6dc41c0ae064d8e3f6`):**
  * Bytecode reverse-engineering resolved 65 function selectors.
  * `DEFAULT_ADMIN_ROLE` is held by a single admin account (`0x915A5b3A9a7Bf9B5f68835117509D9dA311Ae419`).
  * `MINTER_ROLE` is held by 2 operational addresses (`0x0CF8...`, `0xab5F...`).
  * No unauthenticated mint or token drain functions exist.
* **Pet (`0xb806028b6ebc35926442770a8a8a7aeab6e2ce5c`):**
  * Reverse-engineered 92 function selectors.
  * Verified state: `publicSaleActive() == false`, `publicSalePrice() == 0`, `burnAllowed() == false`.
  * All privileged functions (`setBaseURI`, `bulkMint`, `withdraw`, `setTokenContract`) require admin or minter roles.
* **$PIXEL Token (`0x7eae20d11ef8c779433eb24503def900b9d28ad7`):**
  * Standard OZ AccessControl ERC-20 implementation. Total supply is 2,682,427,950 PIXEL.
  * No abnormal transfer hooks, reentrancy vectors, or unprotected mint/burn functions exist in the bytecode.

---

## 3. Web & Frontend Security Surface

* **Frontend Artifacts:** Analyzed Next.js build chunks (`pn0fAhb-b19E-zUbhuhfS`).
* **Environment & Keys:**
  * Public keys examined: `NEXT_PUBLIC_OTTER_PUBLISHABLE_KEY`, Stytch telemetry, and Google reCAPTCHA keys. All are client-side public identifiers as intended.
  * No private keys, AWS access secrets, or unauthorized API tokens are hardcoded or leaked in the static bundles.
* **Server Communication:**
  * Transport layer utilizes Colyseus WebSocket protocol at `wss://pixels-server.pixels.xyz/`.
  * Policy restriction: Active fuzzing or penetration testing against the production game server without explicit authorization violates the program brief.

---

## 4. Conclusion & Disposition

The in-scope smart contracts on Ethereum and Ronin adhere to standard access-control patterns and have reached full mint / closed public sale states, with no permissionless drain or critical logic flaws present in the contract code. No exploitable vulnerabilities meeting the bounty program threshold were identified.
