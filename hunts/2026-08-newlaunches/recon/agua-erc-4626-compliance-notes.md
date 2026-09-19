> For the complete documentation index, see [llms.txt](https://docs.tropicalwater.xyz/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.tropicalwater.xyz/architecture/erc-4626-compliance-notes.md).

# ERC 4626 Compliance Notes

The contract declares `IERC4626` to expose standard view functions, but intentionally deviates on the withdrawal side to enforce the two-path redemption system.

| Function                                           |     Status    | Behaviour                                                     |
| -------------------------------------------------- | :-----------: | ------------------------------------------------------------- |
| `asset()`                                          |       ✅       | Returns `ASSET` address.                                      |
| `totalAssets()`                                    |       ✅       | Virtual accounting via rate factor — not actual USDC balance. |
| `convertToAssets` / `convertToShares`              |       ✅       | Correct with yield.                                           |
| `deposit(assets, receiver)`                        |       ✅       | Primary entry point.                                          |
| `maxDeposit` / `maxMint`                           |       ✅       | Respect cap.                                                  |
| `previewDeposit` / `previewMint` / `previewRedeem` |       ✅       | Accurate previews.                                            |
| `mint(shares, receiver)`                           | ❌ **REVERTS** | Use `deposit` instead.                                        |
| `withdraw(assets, receiver, owner)`                | ❌ **REVERTS** | Use redemption request flow.                                  |
| `redeem(shares, receiver, owner)`                  | ❌ **REVERTS** | Use redemption request flow.                                  |
| `previewWithdraw(assets)`                          | ❌ **REVERTS** | Use `previewCompleteRedemption`.                              |
| `maxWithdraw(owner)`                               |  Returns `0`  | Use redemption request flow.                                  |
| `maxRedeem(owner)`                                 |  Returns `0`  | Use redemption request flow.                                  |

{% hint style="warning" %}
**Integrator warning.** Any aggregator, yield router, or DeFi protocol that integrates this vault using the standard IERC4626 `redeem()` or `withdraw()` interface will revert. Integrators must use `requestRedemption` / `completeRedemption` / `redeemEarly`.
{% endhint %}
