# Auto-sweep (consolidation) — setup & go-live guide

**What it does:** when a user's USDT deposit is credited, the backend automatically
moves ("sweeps") that USDT off the user's personal deposit address into your
**master wallet**, so your funds are consolidated and liquid for withdrawals.

**How it stays safe (non-custodial):** the sweep transaction is signed by a
separate **Tatum KMS** process that *you* run and that holds the wallet mnemonic
**encrypted**. The API server never sees a private key — it only tells Tatum
"sweep address N" and references a `signatureId`; KMS signs and broadcasts. This is
the same guardrail we've had from day one: **the mnemonic never touches the server.**

> **Status: built, shipped, gated OFF.** Nothing sweeps until every switch below is
> set. Because this environment can't reach Tatum, the live signing path is verified
> on **testnet first** via `/v1/setup/sweep` (returns raw responses), exactly like we
> did for deposit webhooks. Expect 1–2 iterations to lock the field shapes.

---

## The moving parts

| Piece | Who runs it | Holds keys? |
|---|---|---|
| API server (this repo) | AWS (ECS) | ❌ never |
| **Tatum KMS** signer | you (small always-on container) | ✅ mnemonic, encrypted |
| **Master (Gas Pump) wallet** | on-chain; owned by the KMS key | — |
| **Gas** | paid from the master by Tatum at sweep time | — |

Deposit addresses must be **Gas Pump** addresses (owned by the master) — plain HD
addresses can't be swept by the master. So enabling sweep switches address issuance
to Gas Pump mode (`CRYPTO_ADDRESS_MODE=gaspump`). Existing test addresses are
regenerated; pre-launch this is fine.

---

## One-time setup

### 1. Run Tatum KMS (the signer)
KMS is Tatum's open-source signing daemon. Run it where it can stay online (a small
ECS/Fargate task or a separate container):

```bash
# store the mnemonic encrypted; you set a password. Do this OFFLINE / in a secure shell.
tatum-kms generatemanagedwallet TRON     # -> prints a signatureId (wallet id). SAVE it.
# (repeat per chain, or import your existing mnemonic with `tatum-kms storemanagedwallet`)
tatum-kms daemon --api-key=<YOUR_TATUM_KEY>   # keeps running, signs pending txns
```

- The **`signatureId`** it prints is what the API references — put it in
  `TATUM_KMS_SIGNATURE_ID`.
- The KMS wallet file + password are the crown jewels. Back them up offline. If you
  already generated the master mnemonic earlier, import that one so the xpub matches.

### 2. Note your master address
The Gas Pump **master** is the address that owns the per-user deposit addresses and
pays gas. Put it in `TATUM_GP_MASTER` (or per-network `TATUM_GP_MASTER_TRON`, etc.).

### 3. Fund gas
Keep a little native coin on the master for fees: **TRX** (TRON), **ETH** (Ethereum),
**BNB** (BSC). Sweeps fail if the master can't pay gas.

### 4. Set the env (all required — sweep stays off until every one is present)
```
SWEEP_ENABLED=true
CRYPTO_ADDRESS_MODE=gaspump
TATUM_GP_MASTER=<master address>
TATUM_KMS_SIGNATURE_ID=<from step 1>
SWEEP_MIN_USDT=1
# testnet: set the testnet USDT contract you actually receive, e.g. Nile:
TATUM_USDT_CONTRACT_TRON=TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf
```

---

## Verify on testnet (before mainnet)

1. `GET /v1/health` → confirm `"sweep": { "active": true, ... }`. If `active:false`,
   the readout shows which switch is missing.
2. Regenerate the test user's addresses (now Gas Pump) and send testnet USDT (same
   flow we used for deposits).
3. It should sweep automatically right after crediting. To force/inspect it:
   ```
   /v1/setup/sweep?token=<WALLET_SETUP_TOKEN>
   ```
   The response includes each address's `status`, `txRef`, and the **raw** Tatum
   response. If a sweep fails, the raw shows exactly why (wrong endpoint, gas, contract
   type) — send it over and it's a one-line fix, no guessing.
4. Confirm the USDT arrives at the master address on-chain.

---

## How it behaves in code (for reference)

- **Trigger:** fires right after a chain deposit credits (`triggerAfterDeposit`),
  fire-and-forget — a sweep failure never fails the deposit.
- **Idempotent:** a per-address in-flight guard (`Sweep` table) + an on-chain balance
  check mean a double trigger or retry can't double-send.
- **Audit:** every attempt is a `Sweep` row (`pending → broadcast → confirmed/failed`)
  with `txRef` and `error`.
- **Gated:** `SweepService.enabled` is false unless `SWEEP_ENABLED=true` **and** the
  provider reports `canSweep` (Gas Pump + KMS). Off = the deposit pipeline is exactly
  as it is today.

---

## Go-live checklist (mainnet)

- [ ] Rotate the Tatum API key (the testnet one was shared in chat).
- [ ] Generate the **mainnet** master wallet; mnemonic into KMS only, xpub into env.
- [ ] `TATUM_NETWORK=mainnet`, mainnet USDT contracts (defaults are already mainnet).
- [ ] Fund mainnet gas (TRX/ETH/BNB) on the master.
- [ ] Small real-money end-to-end test (a few USDT) before opening deposits.
- [ ] Remove `WALLET_SETUP_TOKEN` so the `/setup/*` endpoints turn off.
