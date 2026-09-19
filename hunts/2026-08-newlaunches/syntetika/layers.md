> For the complete documentation index, see [llms.txt](https://docs.syntetika.io/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.syntetika.io/protocol-operations/the-four-layer-infrastructure.md).

# The Four-Layer Infrastructure

Our architecture divides operational responsibilities across four layers, each holding one function and none holding another's authority. Capital moves along a single chain, Base, in both directions, with no bridges.

<figure><picture><source srcset="/files/FQtDWpBjIwMwguQWyQd4" media="(prefers-color-scheme: dark)"><img src="/files/lW34ZAVmztQTbLN5Td3z" alt=""></picture><figcaption></figcaption></figure>

***

### 1 — The Vault Layer

Built on Base using Ember Protocol's infrastructure, the user-facing vault is accessible via Syntetika's official interface, the entry point for participant deposits and redemptions.

A participant deposits cbBTC and receives hBTC, a vault share token representing a pro-rata claim on the vault's position.&#x20;

Deposits are accepted but not minted on arrival. Issuance is gated to the NAV cadence, not to the deposit timestamp. Pending deposits remain cancellable until the cutoff, and a deposit can wait up to roughly 15–17 days before hBTC mints at the published price. Shares mint at the most recent finalized NAV and reprice at each subsequent publish.

***

### 2 — The Curator Layer

Tulipa is the external curator that runs the vault end to end. It manages the deposit and redemption queues, nets the two every cycle, executes the mint at each cutoff, and co-signs on-chain price updates.

The curator holds capital only in transit, at its own institutional custodian. It never holds the deployed investment, and cannot move the vault price alone.

***

### 3 — The SPV Layer

SYNT (BVI) Ltd is the special-purpose vehicle that holds legal title to the fund investment and stands as investor of record in Hilbert Basis+.

It receives the net from the curator, subscribes it into the fund or submits the redemption, processes the fund's subscription and redemption forms, and maintains the master ledger.

The SPV exercises no discretion over the strategy and warehouses no capital beyond a small operational float for rounding and fees. Assets are held at Utila in segregated sub-accounts.

***

### 4 — The Strategy Layer

Hilbert Basis+ is where the strategy executes. It runs a delta-neutral BTC basis strategy inside a CIMA-registered fund, and strikes NAV twice monthly.

While the vault and the SPV hold only cbBTC on Base, the BTC leg lives entirely inside the fund. Hilbert converts cbBTC to BTC on the way in, and back on the way out.&#x20;

cbBTC is valued at par with BTC throughout; conversion is an internal mechanic of the fund, and participants transact only in cbBTC at the published price.

All discretionary management sits here; no Syntetika entity directs the strategy.
