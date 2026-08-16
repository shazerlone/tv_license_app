# Millimore — Wallet & Money System (app build guide)

**Who this is for:** the Flutter app session. This is the spec for a **premium,
crypto-exchange-grade** wallet: balance, transaction history, a real **deposit
funnel** (network → address → QR → live confirmation) and **withdrawals** with
the AML same-source rule. Backend is live; endpoints below are the source of
truth (see `BACKEND_CONTRACT.md`).

**Design bar:** this must feel like Binance/Revolut/Robinhood, not a form. Follow
`DESIGN.md` — light canvas, Inter, accent `#2563EB` used sparingly, 14px cards,
soft shadows, generous spacing, tasteful motion. No cramped rows, no neon.

---

## 1. The money model (explain to the user in-app)
- The wallet holds a **USD balance**. Users **deposit crypto (USDT)** → it credits
  the USD balance → they copy-trade with it → they **withdraw** back out.
- **AML same-source rule:** money can only leave the way it came in. Deposited via
  **crypto → withdraw to crypto only**. (Bank/card are future; same rule applies.)
  The app must reflect this so users never hit a dead end (see §5).

---

## 2. Wallet home screen
Pull from `GET /wallet` (balance/currency) and `GET /portfolio/summary` (equity,
used/free margin, open P/L). Show:
- **Balance** big and clean; below it a subtle row: *Free margin · Used margin · Equity*.
- Primary actions: **Deposit** (accent button), **Withdraw** (secondary).
- **Transactions** list from `GET /wallet/ledger` (or `GET /wallet/transactions`):
  each row = icon by type (deposit ↓ green, withdrawal ↑, trade P/L, commission,
  fee), amount signed, running balance, timestamp. Group by day.

---

## 3. Deposit funnel (the important one)
A 3-step flow. Never dump an address on a bare screen.

### Step 0 — Gate
Call `GET /deposits/addresses`. Handle the response:
- **`kyc_required`** → route to the KYC flow with a friendly explainer ("Verify
  your identity to unlock deposits"). Don't show addresses.
- **`deposits_unavailable`** → show "Crypto deposits are being set up — check back
  soon" (the backend has no processor connected yet). No address.
- **200 `[ { network, asset, address } ]`** → proceed. Each user has one permanent
  address per network; safe to cache locally and reuse.

### Step 1 — Network selection
Show a clean chooser of the networks returned (order: **TRON (TRC-20)**,
**Ethereum (ERC-20)**, **BSC (BEP-20)**). For each: network name, the **USDT**
badge, and a one-line hint ("Lowest fees" on TRON). Big tappable cards, single
select. ⚠️ Copy: *"Only send USDT on the selected network. Sending any other coin
or network will lose the funds."*

### Step 2 — Address + QR screen
For the chosen network show:
- A **QR code** generated on-device from the `address` string (use `qr_flutter`).
  Center it, quiet zone, rounded container, Millimore mark in the middle optional.
- The **address** in monospace, truncated middle (`TXyz…8f2a`) with a **Copy**
  button (haptic + "Copied" toast).
- **Save/Download QR** button — render the QR to an image and save to gallery /
  share sheet (`share_plus` / save to file).
- The **network + asset** clearly ("USDT · TRON (TRC-20)").
- A **"How to deposit"** expandable: 1) copy address 2) send USDT on this network
  from your wallet/exchange 3) wait for confirmations.
- Optional **amount helper**: let the user type an intended amount purely to show
  "≈ credited to your balance" — do NOT require it (address is reusable).

### Step 3 — Waiting for confirmation
After the user says "I've sent it" (or immediately), show a **live pending state**:
- A calm animated "Waiting for your deposit…" card with the network + address.
- **Two signals, use both:**
  1. **Realtime (preferred):** on the WS `user` channel, listen for
     `{ ch:"user", type:"wallet.deposit", data:{ amount, asset, txRef } }` — emitted
     the instant the deposit is credited. On receive → success animation, refresh
     balance.
  2. **Poll fallback:** while on this screen, poll `GET /deposits` every ~10s;
     when a matching deposit shows `status:"confirmed"`, show success.
- Success: check-mark animation, "+$X.XX added to your balance", CTA back to wallet.
- Let the user leave — the push notification (`wallet.deposit`) will tell them when
  it lands, so they don't have to sit on the screen.

> Deposits auto-forward to Millimore's master wallet and the user's balance is
> credited automatically once the payment confirms on-chain — the app never needs
> a tx hash from the user. Just show address → wait → confirmed.

---

## 4. Deposit history
`GET /deposits` → list with `status` (pending / confirmed / failed), `amount`,
`asset`, `payCurrency` (network), `createdAt`, `confirmedAt`. Pending rows get a
subtle spinner; confirmed = green; failed = muted with a reason.

---

## 5. Withdrawal funnel + AML
### Saved payout methods
- `GET /wallet/payout-methods` → list (masked, e.g. "USDT ••••a1b2").
- `POST /wallet/payout-methods { type:"crypto", label, asset, address }` (crypto)
  or `{ type:"bank", label, bankName, accountNumber, … }`.
- `DELETE /wallet/payout-methods/{id}`.

### The AML rule — surface it, don't let users hit a wall
The backend rejects a withdrawal whose method type ≠ a method the user deposited
from (`withdrawal_method_mismatch`). So in the app:
- Determine the user's funded source(s) — simplest: from `GET /deposits` (are there
  confirmed crypto deposits?). 
- **Only offer withdrawal methods that match.** If they only deposited crypto, show
  crypto payout methods; grey out bank with a tooltip: *"You can withdraw only to
  the method you deposited from (crypto)."*
- Still handle the server error defensively: if `POST /creator/payouts` returns
  `withdrawal_method_mismatch`, show that message inline.

### Request a withdrawal
`POST /creator/payouts { amount, methodId, note? }`. Handle these error codes with
friendly copy:
| code | message to show |
|---|---|
| `kyc_required` | Verify your identity to withdraw. |
| `below_min_withdrawal` / `above_max_withdrawal` | Show the limit from the message. |
| `daily_limit_exceeded` | You've hit today's withdrawal limit. |
| `invalid_payout_method` | Pick a saved withdrawal method. |
| `withdrawal_method_mismatch` | Withdraw to the method you deposited from. |
| `account_restricted` | Withdrawals are paused — contact support. |

Funds are **held immediately** on request (balance drops), then an admin/webhook
finalizes. Track status via `GET /creator/payouts` and the WS `user` event
`type:"payout.status"` (`approved` / `rejected` with reason → refunded).

---

## 6. Realtime events (WS `user` channel)
Subscribe once after login: `{ "op":"subscribe", "channels":["user"] }`.
- `wallet.deposit` — deposit credited → refresh balance, dismiss waiting screen.
- `payout.status` — withdrawal approved/rejected → update history + toast.
- (also `price.alert`, `trade.opened/closed`, `trader.live.started` — other screens.)

---

## 7. States to design (don't skip)
- KYC-not-verified (deposit + withdraw both gated).
- Deposits unavailable (no processor yet).
- Empty wallet / first deposit nudge.
- Pending deposit / pending withdrawal.
- Failed deposit, rejected withdrawal (with reason).
- Copy-success and error toasts.

---

## 8. Build order
1. Wallet home (balance + transactions) — read-only, ship first.
2. Deposit funnel (network → QR → waiting) — the flagship screen.
3. Deposit history.
4. Payout methods + withdrawal with AML-aware method filtering.
5. Wire the WS `user` events for live deposit/withdrawal updates.

_Backend endpoints are stable and live. Anything unclear → check
`BACKEND_CONTRACT.md` or ask the backend session._
