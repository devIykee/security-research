Hey Leavehood.

I'm Iyke, a security researcher. (http://x.com/deviykee)

I mapped your RH stack from leavehood.com/docs: factory proxy 0x2C81Cd8a…, core proxy 0x5090C9cd…, and verified LeavehoodLockLP 0x8F1C1205….

I did **not** claim a permissionless High. Factory/core implementations are still **unverified** (UUPS), so I could not fully audit the launch path. The lock contract is a time-lock with post-unlock `withdraw` (max 100y), not a permanent no-exit locker.

If you verify factory + core source on Blockscout/Sourcify, I can re-check quickly for pool/price issues. Who's the right person for security mail?
