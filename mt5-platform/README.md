# MT5 Manager

Self-hosted **MetaTrader 5 terminal fleet manager**. Operators enter MT5 account
"meta details" (login / password / broker server) in a web or app UI; the platform
auto-deploys a dedicated MT5 terminal for each account across one or more Windows
VPS servers, then monitors, restarts, and scales them automatically.

```
Operator UI ──HTTPS──▶ Laravel control plane (MySQL) ◀──HTTPS── Windows Agents ──▶ terminal64.exe ×N
                       desired + observed state              reconcile / heartbeat
```

## What's here

| Path | What |
|---|---|
| `docs/ARCHITECTURE.md` | **Phase 1** — architecture, diagram, capacity model, folder layout, reliability & security posture |
| `docs/DATABASE.md` + `backend-laravel/database/migrations/` | **Phase 2** — 6-table schema + migrations |
| `docs/API.md` + `backend-laravel/app/Http/Controllers/` + `routes/api.php` | **Phase 3** — operator + agent REST APIs |
| `agent-python/` | **Phase 4** — Windows Agent: reconcile loop, MT5 launcher, watchdog, metrics |
| `agent-python/watchdog.py` | **Phase 5** — crash detection, backoff, circuit breaker |
| `app/Services/SchedulerService.php` | **Phase 6 & 7** — resource-aware placement + least-loaded horizontal scaling |
| `docs/DASHBOARD_SPEC.md` | **Phase 8** — Laravel monitoring dashboard spec |
| `docs/DEPLOYMENT.md` | **Phase 9** — install & operate both halves |
| `docs/SECURITY.md` | Credential handling & threat model |

## Core design

- **Control plane / data plane split.** Laravel + MySQL own *desired* state; each
  Windows Agent is a reconciliation loop that makes its VPS match desired state and
  reports *observed* state back. Same model as Kubernetes.
- **Pull, not push.** Agents poll over outbound HTTPS — no inbound ports on the VPS,
  survives brief control-plane outages, works behind NAT.
- **Idempotent + self-healing.** Reconcile is a no-op when already converged; a VPS
  reboot re-adopts running terminals; a dead agent is caught by heartbeat staleness.
- **Resource-aware.** The scheduler won't over-pack a box, and the agent refuses to
  launch a terminal when CPU/RAM headroom is gone.

## Capacity note (read this)

30 MT5 terminals on **4 vCPU / 8 GB** is at the ceiling — RAM is the limit
(~150–250 MB per idle terminal). Recommended safe cap **≈ 22–25 per box**; scale out
with more VPS servers for the rest. Configurable per server via `max_terminals`,
`ram_soft_limit_mb`, `cpu_soft_limit_pct`. Details in `docs/ARCHITECTURE.md §1.4`.

## Quick start

1. **Control plane:** `docs/DEPLOYMENT.md §A` — spin up Laravel + MySQL, drop in the
   provided `app/`, `database/`, `routes/`, migrate, serve over HTTPS.
2. **Register a VPS:** `POST /api/servers` → copy the one-time agent token.
3. **Agent:** `docs/DEPLOYMENT.md §B` — configure `config.yaml`, run
   `install-service.ps1`. Server goes **online** within ~20 s.
4. **Add an account:** `POST /api/accounts` with the MT5 meta details → the least-loaded
   VPS launches its terminal automatically.

## Status

Reference implementation. The Laravel PHP lints clean and the Python agent
byte-compiles; wire it into a real Laravel app + a Windows VPS per
`docs/DEPLOYMENT.md`. The `backend-laravel/` tree contains the app-specific files you
drop into a stock `laravel new` project — not a full standalone Laravel install.
