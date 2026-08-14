# DM First Contact — Sheriff.money

**Platform:** X / Telegram / Discord  
**Handle:** @sheriffexchange  
**Subject:** Security finding regarding SecurityPlugin / LP exit safety

---

Hey Sheriff team,

I'm an independent security researcher (deviykee) reviewing smart contracts on Robinhood Chain.

During my audit of Sheriff's pool plugins, I identified an edge-case code defect in `SecurityPlugin.sol` (`_checkStatusOnBurn`) where unsetting or zeroing the `securityRegistry` address causes liquidity withdrawals (`burn` / `decreaseLiquidity`) to revert while swaps and deposits remain permitted.

I've prepared a detailed report with a reproducible Foundry unit PoC demonstrating the behavior and recommended remediation.

Where is the best private channel (e.g. Immunefi, security email, or private TG/Discord) to share the full technical advisory?

Best regards,  
deviykee
