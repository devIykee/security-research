> For the complete documentation index, see [llms.txt](https://docs.syntetika.io/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.syntetika.io/protocol-operations/the-end-to-end-operational-workflow.md).

# The End-to-End Operational Workflow

Our financial operations run on a twice-monthly cadence, with NAV struck on the 15th and at month-end. Every step follows one rule: the finalized NAV publishes as soon as it is verified, and everyone transacts at the latest finalized NAV.

<figure><picture><source srcset="/files/hrNqKLf0biqYoOdUUFW5" media="(prefers-color-scheme: dark)"><img src="/files/0ftEoRhEQ8OxciVxeFIF" alt=""></picture><figcaption></figcaption></figure>

***

### 1 — Accumulation

Participants deposit cbBTC into the vault at any time. Deposits accumulate as pending, unminted balances, and redemption requests queue alongside them. Both remain cancellable until the cutoff.

***

### 2 — Cutoff and Mint

The cohort closes two business days before each strike, typically the 13th and the 28th, and mints at the published price. Dates falling on a weekend or holiday roll back to the preceding business day. Exact cutoffs for each cycle are shown in the app.

Every request parked at the cutoff joins the cohort and transacts at the most recent finalized NAV, already live on-chain before the cutoff. Later requests simply roll into the next cohort.

The curator then nets the cohort. Minted deposit capital is compared against what is owed to the redemption queue, and the balance between the two determines the cycle:

<figure><picture><source srcset="/files/8xfMNXKQO3vQingNH5ay" media="(prefers-color-scheme: dark)"><img src="/files/xqnMXYF9JESGFYUWCiWq" alt=""></picture><figcaption></figcaption></figure>

For participants, the cycle type changes only timing, never price. Deposits mint identically in both cases, and redeemers are paid at the same published price either way.

***

### 3 — Routing and Strike

The SPV routes only the net. Net subscriptions are subscribed into Hilbert Basis+ ahead of the strike; net redemptions are submitted as a withdrawal request.&#x20;

Capital is routed, not warehoused; the SPV holds nothing but a small operational float.

On the 15th and at month-end, the fund takes its NAV snapshot and the cohort's flows become effective. This is the valuation that will price the next cohort.

The cbBTC/BTC conversion is performed fund-side. Hilbert converts cbBTC to BTC, deploys into the delta-neutral basis strategy, and converts back on the way out. cbBTC is valued at par with BTC throughout.

***

### 4 — Payout and Settlement

On subscription cycles settlement is immediate, the redemption queue is paid in full the same evening as the mint, at the published price.

On redemption cycles, cash returns from the fund roughly three to five days after the strike, and the queue is then paid in order, at the published price at the moment of payout.

In the exceptional case where a single cycle's net redemption approaches a full wind-down of the vault, settlement waits for full NAV finalization.

Deposits mint and redemptions pay at the most recent finalized NAV. NAVs strike on the 15th and last day of each month and finalize 5–15 days later, so the live price is always one strike behind the fund. Redemptions do not earn the period in which they exit.

***

### 5 — Finalization and Publish

Five to fifteen days after the strike, NAV Consulting (NAVC) finalizes the official NAV. The attested figure is published on-chain promptly after verification, through a joint multisig in which each operating party is a required signer.&#x20;

No single party can publish alone. Only attested, finalized figures are ever published.

The published figure prices the next cohort, not its own. Until a new figure is finalized, the live price remains the previous finalized NAV, one strike behind by design.

Two cycles can be in flight at once, since a strike's NAV may finalize after the next cutoff. Each cohort mints at a price already on-chain, so no cohort ever waits on a previous cycle's finalization.
