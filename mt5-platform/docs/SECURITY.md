# Security & Credential Handling

MT5 credentials are the crown jewels here. This documents how they're protected
and the threat model.

## Credential lifecycle
1. Operator enters login / password / server over **HTTPS** into the dashboard.
2. Laravel stores the password via the `encrypted` cast → **AES-256-GCM**, keyed by
   `APP_KEY`. Ciphertext at rest in `trading_accounts.password_encrypted`.
3. Password is in the model's `$hidden` array → never serialised into any JSON
   response **except** `GET /agent/assignments`.
4. That endpoint returns the decrypted password to the owning agent over HTTPS only,
   authenticated by the per-VPS token, rate-limited, and scoped to that VPS.
5. On the VPS the agent writes a UTF-16 `start.ini` (MT5's format) with the password,
   launches the terminal, then **deletes the ini after ~3 s** so plaintext does not
   persist. The ini is created mode `0600`.

## Agent authentication
- Each VPS has a **unique bearer token**; only its **SHA-256 hash** is stored
  (`agent_token_hash`). The raw token is displayed **once** at registration.
- `AuthenticateAgent` middleware resolves the token to a `VpsServer` and binds it to
  the request. Every agent controller reads/writes **only** rows where
  `vps_server_id` = that server. A stolen VPS token exposes at most the accounts on
  that one box — blast radius is contained.
- Rotate with `POST /servers/{id}/rotate-token`; update `config.yaml` and restart.

## Transport
- HTTPS everywhere. Agent verifies the control-plane TLS cert (`verify_tls: true`,
  or pin a private CA via `ca_bundle`). Never disable verification.

## On-VPS hardening
- `config.yaml` (holds the agent token) ACL-locked to SYSTEM + Administrators
  (see `install-service.ps1`).
- Per-account MT5 data dirs live under `data_root`; restrict to the service account.
- Run the agent + terminals under a **dedicated low-privilege service account**, not
  a domain admin.
- Windows Firewall: only outbound 443 to the control plane is required; no inbound.

## Logging discipline
- Passwords are **never** logged at any level (including `DEBUG`). The agent logs
  account ids / logins / PIDs only.
- Laravel: keep `password` out of request logs; `StoreAccountRequest` doesn't dump.

## What this system is / isn't
- It manages **your own** MT5 terminals for accounts you or your consenting users
  own. Standard prop-desk / signal-distribution infrastructure.
- It does **not** bypass broker auth, scrape third-party accounts, or hide activity
  from brokers. Credentials are supplied by the account owner and used only to log
  that owner's own terminal in.

## Recommended extras (not shipped, worth adding)
- Envelope-encrypt passwords with a KMS/HSM key instead of `APP_KEY` for key rotation
  without re-encrypting via a rekey job.
- Per-operator RBAC + audit log on the operator API (who created/stopped what).
- IP allow-list on `/api/agent/*` if your VPS IPs are static.
- Alert on repeated `login_failed` events (could indicate a wrong/rotated password).
