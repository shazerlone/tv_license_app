# Millimore back-office — market benchmark

How our admin/back-office compares to standard forex/crypto broker platforms
(B2Core/B2Broker, Syntellicore, Brokeret, and typical crypto-exchange admin
panels). Goal: know exactly where we're strong and what's still missing, so we're
not "technically backward."

## Industry-standard back-office capabilities (the checklist)

| Capability | Industry standard | Millimore status |
| --- | --- | --- |
| Client list + search + filters | ✅ | ✅ |
| **Client 360 detail** (profile, balance, KYC, activity) | ✅ | ✅ **(M8)** |
| **Check balance** per client | ✅ | ✅ **(M8)** |
| **Manual balance credit/debit** (audited) | ✅ | ✅ **(M8)** |
| **Freeze / suspend** account (vs full ban) | ✅ | ✅ **(M8)** |
| **Internal ops notes** on a client | ✅ | ✅ **(M8)** |
| Transaction history (all money in/out) | ✅ | ✅ (M6/M7) |
| Deposit/withdrawal approval workflow | ✅ | ✅ (M7) |
| Verify / flag transactions (AML review) | ✅ | ✅ (M7) |
| Configurable fees & limits (no redeploy) | ✅ | ✅ (M7) |
| KYC/AML workflow (3rd-party) | ✅ | ✅ Sumsub-ready (M7) |
| Audit trail of admin actions | ✅ | ✅ (M7) |
| Wallet + ledger (double-entry style) | ✅ | ✅ (M6) |
| Analytics / reporting dashboards | ✅ | ✅ (M8) |
| Leverage / margin controls | ✅ | ✅ (M7) |
| Multi-currency wallets | ✅ | ⚠️ USD only (single-currency ledger; extendable) |
| **IB / affiliate / referral module** | ✅ | ✅ **(M9)** — codes, revenue share + signup bonus, admin leaderboard (single-level; multi-level is a later add) |
| Support tickets / in-app messaging | common | ❌ not yet |
| Document management (uploaded IDs/statements) | ✅ | ⚠️ partial (uploads exist; no doc console) |
| Bonus / promo engine | common | ❌ not yet |
| Role-based admin permissions (granular) | ✅ | ⚠️ single admin role today |

## Summary
On the **core back-office** (client management, balances, transactions, KYC/AML,
approvals, audit, fees, analytics) Millimore is now at parity with mainstream
broker back-offices. The main **remaining gaps** — none of them blockers for
launch — are:

1. **IB / affiliate / referral module** — the biggest commercial gap; brokers
   grow through partners. Good next milestone.
2. **Support tickets / announcements** — customer-ops nicety.
3. **Multi-currency wallets** — only when we add non-USD funding.
4. **Granular admin roles** — when the ops team grows beyond a few trusted admins.

We are **not technically backward** on the fundamentals; we're missing growth/ops
add-ons that are natural follow-on milestones.

## Update (M10)
- **Support tickets / helpdesk** — ✅ (threaded, internal notes, status/priority,
  realtime reply push).
- **Announcements / notification center** — ✅ (audience targeting, required-read
  acknowledgement, bell feed).
