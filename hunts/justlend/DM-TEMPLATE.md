# Private DM - JustLend Security Contact

**Platform:** X/Twitter DM  
**To:** JustLend Official Account (@JustLendDAO or similar)  
**From:** @deviykee  
**Subject:** Private Security Disclosure  

---

## Initial DM (Short Version)

```
Hi JustLend team,

I'm a security researcher (deviykee) and I've identified a vulnerability in JustLend's lending protocol that could lead to significant MEV extraction through liquidation front-running.

Impact: Estimated $50-150M annual value leakage
Status: Verified via source code analysis (no exploitation)
Disclosure: Private, coordinated approach

I have a detailed technical report ready to share privately. Do you have a preferred channel for security disclosures? (Email, Discord, or I can share a private document link)

This is responsible disclosure - no public posting, no exploitation, no threats.

Best,
Iyke (@deviykee)
```

---

## Alternative (If They Have Security Email)

**Subject:** Private Security Vulnerability Disclosure - JustLend Liquidation Mechanism

```
Hello JustLend Security Team,

My name is Iyke (deviykee), and I am a security researcher focused on DeFi protocol security.

I have identified a high-severity vulnerability in JustLend DAO's liquidation mechanism that enables MEV extraction through front-running. The issue affects all jToken markets.

SUMMARY:
- Vulnerability: Liquidation front-running via public mempool exposure
- Severity: HIGH
- Estimated Impact: $50-150M annual MEV extraction
- Verification: Confirmed via source code analysis
- Exploitation: None attempted (read-only analysis only)

I have prepared a detailed technical report with:
• Source code evidence (file paths and line numbers)
• Attack mechanism documentation  
• Economic impact analysis
• Recommended fixes with implementation examples
• Coordinated disclosure timeline proposal

I am reaching out privately before any public disclosure and am willing to work with your team on a coordinated fix and disclosure timeline.

Please let me know:
1. How you would like to receive the full report (email, encrypted channel, etc.)
2. Your preferred disclosure timeline
3. If you have a bug bounty program

I can be reached at:
- X/Twitter: @deviykee
- GitHub: github.com/devIykee

Looking forward to working with you on this.

Best regards,
Iyke (deviykee)
Security Researcher

---
This is a private security disclosure. Please do not forward without permission.
```

---

## Follow-up Template (If No Response in 7 Days)

```
Hi JustLend team,

Following up on my security disclosure from [DATE]. 

I've identified a high-severity vulnerability in your liquidation mechanism. I'd like to share the details privately and work on a coordinated fix.

Could you please confirm:
1. You received my initial message
2. Who the best security contact is
3. Your preferred disclosure process

Happy to provide proof of concept or technical details to help validate the issue.

Thanks,
Iyke
```

---

## Escalation Path (If No Response in 14 Days)

1. **Day 14:** Try alternative contact (LinkedIn, Discord, Telegram)
2. **Day 21:** Contact TRON Foundation security team
3. **Day 30:** Consider limited public disclosure with:
   - High-level description only
   - No exploit code
   - No specific vulnerable lines
   - Statement that team was notified

---

## Contact Search Checklist

- [ ] Find official X/Twitter: @JustLendDAO or @JUST_DeFi
- [ ] Check website for security email: security@just.network
- [ ] Look for Discord/Telegram with admins
- [ ] Check GitHub for security policy: github.com/justlend/justlend-protocol/SECURITY.md
- [ ] TRON Foundation contact as backup

---

## Communication Guidelines

### DO ✅
- Be professional and respectful
- Provide clear severity assessment
- Offer coordinated timeline
- Share technical details privately
- Offer to help with fix validation

### DON'T ❌
- Make threats or demands
- Set arbitrary deadlines
- Publicly disclose before fix
- Request excessive bounty
- Release exploit code publicly

---

## Disclosure Package Contents

When they respond, share:

1. **Full Technical Report** - `hunts/justlend/DISCLOSURE-REPORT.md`
2. **Code Evidence** - `hunts/justlend/CONFIRMED-LIQUIDATION-FRONTRUN.md`
3. **Recommended Fixes** - Implementation examples included
4. **Timeline Proposal** - 90-day coordinated disclosure

---

**Status:** Ready to send upon locating official contact  
**Researcher:** deviykee / Iyke  
**Date Prepared:** 2026-08-28
