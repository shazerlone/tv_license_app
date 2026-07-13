# Phase 3 — REST API Reference

Two audiences, two auth schemes:

- **Operator API** — the dashboard / Flutter app. Auth: `Bearer <sanctum token>`.
- **Agent API** (`/api/agent/*`) — the Windows agents. Auth: `Bearer <per-VPS token>`,
  resolved and scoped by the `AuthenticateAgent` middleware. An agent can only ever
  touch rows for its own VPS.

Base URL: `https://panel.example.com/api`

---

## Operator API

### Accounts

| Method & path | Purpose |
|---|---|
| `GET  /accounts` | List accounts (paginated). Filters: `status`, `vps_server_id`. Password never returned. |
| `POST /accounts` | Create from meta details, auto-assign to least-loaded VPS. |
| `GET  /accounts/{id}` | Show one account + its server + terminal. |
| `POST /accounts/{id}/restart` | Ask the owning agent to restart this terminal. |
| `POST /accounts/{id}/stop` | Set `desired_state=stopped`; agent tears it down. |
| `POST /accounts/{id}/start` | Resume; re-assign if unplaced. |
| `DELETE /accounts/{id}` | Release slot + soft-delete. |

**`POST /accounts` body**
```json
{
  "login": "8125660",
  "broker_server": "ICMarketsSC-Demo",
  "password": "••••••••",
  "password_type": "master",
  "label": "Client A – EURUSD",
  "owner": "Majid Lone",
  "license_id": 8125660627151
}
```
**201 response**
```json
{
  "account": { "id": 42, "login": "8125660", "status": "assigned",
               "server": { "id": 2, "name": "vps-lon-01" } },
  "placed": true,
  "message": "Assigned to vps-lon-01"
}
```
If the fleet is full, `placed:false` and the account waits `unassigned` until a
slot frees (the rebalance job re-tries it).

### Servers

| Method & path | Purpose |
|---|---|
| `GET  /servers` | Fleet list + running-terminal counts. |
| `POST /servers` | Register a VPS. **Returns the agent token once.** |
| `GET  /servers/{id}` | Server detail + its terminals. |
| `GET  /servers/{id}/health?hours=6` | Time-series CPU/RAM for charts. |
| `POST /servers/{id}/status` | `online` / `draining` / `disabled`. |
| `POST /servers/{id}/rotate-token` | New agent token; old one invalidated. |

**`POST /servers` → 201** returns `agent_token` (paste into the agent's
`config.yaml`). It is never retrievable again — rotate if lost.

---

## Agent API  (`/api/agent`, per-VPS token)

### `GET /agent/assignments`
Desired state for *this* VPS. **Only endpoint that returns decrypted passwords** —
HTTPS-only, rate-limited, token-scoped.
```json
{
  "server": { "id": 2, "name": "vps-lon-01", "max_terminals": 22,
              "ram_soft_limit_mb": 6500, "cpu_soft_limit_pct": 85, "status": "online" },
  "assignments": [
    { "account_id": 42, "login": "8125660", "broker_server": "ICMarketsSC-Demo",
      "password": "••••••••", "password_type": "master",
      "action": "run", "instance_key": "8125660" }
  ],
  "server_time": "2026-07-13T10:00:00Z"
}
```
`action` ∈ `run | restart | stop`.

### `POST /agent/heartbeat`
Host + per-terminal snapshot. Upserts terminals, records a health sample, refreshes
denormalised dashboard fields, logs status transitions.
```json
{
  "host": { "cpu_pct": 34.2, "ram_used_mb": 5210, "ram_total_mb": 8072,
            "cpu_cores": 4, "disk_free_mb": 41220, "load_avg": 1.3 },
  "agent_version": "1.0.0",
  "terminals": [
    { "account_id": 42, "status": "running", "os_pid": 6120,
      "cpu_pct": 1.4, "ram_mb": 232, "mt5_connected": true,
      "restart_count": 0, "instance_key": "8125660", "data_dir": "C:\\mt5data\\8125660" }
  ]
}
```
→ `{ "ok": true, "server_time": "…" }`

### `POST /agent/events`
Idempotent batch (dedup by `event_uid`).
```json
{ "events": [
  { "event_uid": "8f1c…-uuid", "trading_account_id": 42, "type": "restarted",
    "severity": "warning", "message": "watchdog restart", "context": {"pid": 6120},
    "occurred_at": "2026-07-13T09:59:50Z" }
]}
```
→ `{ "accepted": ["8f1c…-uuid"] }`

---

## Status codes
`200` ok · `201` created · `401` bad/missing token · `403` server disabled ·
`409` invalid action (e.g. restart with no live terminal) · `422` validation ·
`429` rate-limited.

## Rate limits
Operator: `120/min`. Agent: `600/min` per VPS (≈10 rps headroom for heartbeat +
poll + events).
