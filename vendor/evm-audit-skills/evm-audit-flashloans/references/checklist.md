# Flash Loan Attack Patterns Checklist

Non-obvious flash loan attack vectors. Flash loans give unlimited capital for one transaction.

## Governance Attacks

- [ ] **Flash-loan voting**: Attacker flash-borrows governance tokens, votes or creates a proposal, returns tokens. Beanstalk lost $182M to this. Mitigation: snapshot-based voting at a past block. Look for: governance using current-block balanceOf or getVotes. [beirao GOV, Dacian governance]

- [ ] **Flash-loan quorum manipulation**: Even if voting uses snapshots, an attacker can accumulate tokens before the snapshot block, then dump after. If proposal creation doesn't require a minimum holding period, this is viable. Look for: proposal creation without minimum token holding duration. [Dacian governance]

## Oracle Manipulation

- [ ] **Flash loan + AMM spot price manipulation**: Attacker flash-borrows to massively skew AMM reserves, then uses the manipulated spot price in a protocol (lending, options). This works because AMM spot price = f(reserves), and reserves are manipulable. Look for: any price derivation from `getReserves()` or `slot0.sqrtPriceX96`. [beirao G-05, Tamjid D3]

- [ ] **Flash loan + TWAP manipulation**: TWAPs are resistant to single-block manipulation but vulnerable to multi-block attacks. On L2s with cheap gas, an attacker can manipulate the price at block boundaries across multiple blocks. Look for: short TWAP windows (<30 minutes) on L2s. [Decurity AMM]

## Vault / Yield Attacks

- [ ] **Flash deposit-harvest-withdraw in yield vaults**: Attacker flash-deposits into a vault, triggers reward harvest (claiming accumulated yield), then withdraws — capturing yield earned by long-term depositors. Look for: vaults where depositing + harvesting + withdrawing can happen in the same transaction without penalty. [beirao V-07]

- [ ] **Share price manipulation via flash loan**: Flash-borrow to inflate vault deposits, skewing the share-to-asset ratio. In the same tx, withdraw more assets than deposited. Look for: vaults where share price depends on balance ratios that can be manipulated intra-tx. [beirao V-08]

- [ ] **Flash mint inflating totalSupply**: DAI and other flash-mintable tokens can temporarily have totalSupply = type(uint256).max during a flash mint. Any formula using `totalSupply()` is manipulable. Look for: pricing or share calculations referencing `totalSupply()` of flash-mintable tokens. [weird-erc20]

## Auction Attacks

- [ ] **Flash loan to win auctions**: An attacker flash-borrows to outbid legitimate participants in auction liquidations. After winning and receiving discounted collateral, they repay the flash loan at profit. Look for: auction mechanisms where the full bid amount is only needed temporarily. [Decurity CDP]

- [ ] **Flash loan to prematurely close auctions**: If a borrower can repay their debt to prematurely end a liquidation auction, they can flash-borrow to repay, close the auction, and then take a new undercollateralized position. Look for: auction systems where the debtor can terminate the auction by proving solvency. [Decurity CDP]

## DeFi Protocol Attacks

- [ ] **Flash loan + self-liquidation**: Attacker borrows via flash loan, uses those tokens to open a position, lets it become instantly underwater (by manipulating the oracle in the same tx), then liquidates their own position to collect the liquidation bonus. Look for: protocols where position creation + liquidation can happen in the same block. [beirao LEN-02]

- [ ] **AAVE flash loans inflate pool index**: On AAVE, each flash loan inflates the pool interest rate index. A maximum of ~180 flash loans per block can compound this effect. Look for: protocols built on AAVE that assume stable index growth. [beirao AC-05]

## Cross-Protocol Flash Loans

- [ ] **Cross-protocol reentrancy via flash loan callbacks**: Flash loan callbacks execute arbitrary code. An attacker can use the callback to interact with other protocols that reference the flash-loaned asset's balance. Look for: protocols that use `balanceOf` for accounting where the token supports flash loans. [Tamjid D10]

- [ ] **Flash loan to bypass rate limits**: Some protocols have per-transaction or per-block limits on actions. Flash loans can bypass these by executing all actions atomically. Look for: rate-limiting mechanisms that check per-tx rather than cumulative. [general]
