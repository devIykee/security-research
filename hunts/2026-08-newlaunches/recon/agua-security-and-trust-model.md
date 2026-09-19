> For the complete documentation index, see [llms.txt](https://docs.tropicalwater.xyz/llms.txt). Markdown versions of documentation pages are available by appending `.md` to page URLs; this page is available as [Markdown](https://docs.tropicalwater.xyz/architecture/security-and-trust-model.md).

# Security and Trust Model

{% hint style="info" %}
**The `ADMIN_ROLE` holder withdraws and allocates funds from the Vault**

```solidity
adminWithdraw(ASSET, IERC20(ASSET).balanceOf(vault), anyAddress);
```

Users of this vault unconditionally trust the `ADMIN_ROLE` key holder. The NatSpec on the function explicitly documents this. The address with `ADMIN_ROLE` permission is a MPC wallet with a 3/5 requirement on all transactions.
{% endhint %}

## Known Items Summary

| Item                                                          | Notes                                                                                         |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `adminWithdraw` — -vault withdraw                             | By design; NatSpec warning present.                                                           |
| ERC-4626 non-compliance — `mint`, `withdraw`, `redeem` revert | Intentional; use vault-specific redemption flow.                                              |
| `_lzReceive` dispatch by length heuristic (`≤ 64 bytes`)      | Fragile if OFT message format changes.                                                        |
| `_internalBroadcast` flag open for entire send loop           | Reentrancy window bypasses `_payNative` check; requires malicious LZ endpoint.                |
| Out-of-order LZ delivery permanently drops state updates      | No gap-fill or re-send mechanism.                                                             |
| Yield frozen at redemption request time                       | Users forfeit yield earned during lockup — by design.                                         |
| `earlyRedemptionFee` permitted at 100% (10000 bps)            | User receives 0 assets. Combine with `minAssetsOut = 0` for full loss.                        |
| `minAssetsOut = 0` in `redeemEarly` provides no protection    | `uint256 < 0` is always false. Pass a non-zero value for real slippage protection.            |
| Unbounded `peerEndpoints` array                               | Enough peers → broadcast exceeds block gas limit → admin setters permanently DOS'd on source. |
| `StateSyncFailed` event declared but never emitted            | Dead code; monitoring on this event will never fire.                                          |

## Trust Assumptions

1. **`DEFAULT_ADMIN_ROLE`** is trusted to manage roles correctly. Compromise → attacker grants themselves `ADMIN_ROLE` → full drain.
2. **`ADMIN_ROLE`** is trusted with all user funds unconditionally.
3. **LayerZero infrastructure** is trusted for message delivery and peer validation.
4. **`ASSET` token** is well-behaved — no transfer callbacks, no rebasing, no fee-on-transfer.
