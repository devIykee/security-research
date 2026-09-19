# Coverage Tracking: BasedAlpha Bug Hunt

- **Target**: BasedAlpha (https://basedalpha.fun)
- **Researcher**: deviykee
- **Date**: 2026-08-21
- **Skill Playbook**: `iykes-web3-bughunt-skill` / `iykes-solana-bughunt-skill`

## Files & Bundles Inspected

| File / Component | Path / Origin | Status | Logic Traced |
|---|---|---|---|
| `index.html` | `https://basedalpha.fun/` | Completed (100%) | DOM hierarchy, views, modal, drawer, scripts |
| `script_1.js` | Embedded app bundle (242 KB) | Completed (90%) | Routing, trading, orders, authPost, bridge, livekit, webpush |
| `script_2.js` | Embedded bootstrap script | Completed (100%) | URL query param handling, auto-coin load |
| `bugs.html` | `https://devbasedsolana.com/bugs` | Completed (100%) | Bug bounty policy, scope, API endpoints |
| `earn.html` | `https://devbasedsolana.com/earn-035eaace4c` | Completed (100%) | Referral program fee split, reward structure |

## Paths & Value-Moving Mechanisms Traced

1. **Trade Execution & Bridge**:
   - `_ensureBridge()`, `authPost()`, `instaBuy()`, `cardBuy()`, `qbuy()`, `qsell()`
   - `postMessage` protocol between main app and embedded `/wallet` iframe
   - Service worker `notif-trade` message handler
2. **Launchpad & Token Submission**:
   - `lpSubmit()`, `startDropCountdown()`, `api/launches`, `/launch/submit`
   - Creator terms, metadata validation, wallet binding
3. **Limit Orders & Alerts**:
   - `/order/create`, `/order/list`, `/order/cancel`, `/alert/create`
   - Web push key retrieval and subscription (`/api/push/key`, `/api/push/subscribe`)
4. **Live Streaming & Host Key Auth**:
   - `basedGoLive()`, `basedWatch()`, `basedEndLive()`, `/api/live/token`
   - Host key token storage in `localStorage.bug_tok`

## Estimated Coverage
- **Client Application & Routing Surface**: ~92%
- **Backend API Contract Surface**: Scoped from client interactions (backend source proprietary/closed-source)
- **On-chain Programs**: Client calls routed via `/wallet` custody bridge

