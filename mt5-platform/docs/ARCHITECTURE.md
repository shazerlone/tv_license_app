# Phase 1 — System Architecture

## 1.1 Goal

Operators enter **MT5 account "meta details"** (login, password, broker server) in a
web/app UI. The platform then:

1. Persists the account and encrypts the password.
2. Picks the **least-loaded VPS** that has spare CPU/RAM headroom.
3. Assigns the account to that VPS.
4. A **Windows Agent** running on the VPS notices the assignment, generates a
   per-account MT5 config, and launches a dedicated `terminal64.exe` in portable
   mode that auto-connects to the broker's MT5 server.
5. The agent **monitors** each terminal (alive/connected, CPU, RAM), **restarts**
   crashed terminals (watchdog), and **reports** everything back to Laravel.
6. A Laravel **dashboard** shows online/offline terminals, per-server CPU/RAM, and
   account status in near real time.

This is standard self-hosted trading infrastructure. Every account is owned by /
consented to by the operator, and all credentials stay inside the operator's own
systems.

## 1.2 High-level diagram

```
                        ┌──────────────────────────────────────────────┐
                        │                  OPERATOR                      │
                        │        (Flutter app / web dashboard)           │
                        └───────────────────────┬──────────────────────┘
                                                 │ HTTPS (session/JWT)
                                                 ▼
        ┌────────────────────────────────────────────────────────────────────┐
        │                         LARAVEL CONTROL PLANE                         │
        │                                                                      │
        │  Web/Dashboard routes ── Admin UI, charts, account CRUD             │
        │  API routes (/api/...)                                              │
        │    • Operator API  (auth: sanctum/jwt)  → assign, view, restart     │
        │    • Agent API     (auth: per-VPS token)→ poll, heartbeat, events   │
        │                                                                      │
        │  Services                                                           │
        │    • SchedulerService  → least-loaded placement + capacity guard    │
        │    • HealthService     → rolls up heartbeats → server/terminal state│
        │  Jobs / Scheduler (cron)                                            │
        │    • MarkStaleTerminalsOffline (missed heartbeats)                  │
        │    • RebalanceAccounts (optional)                                   │
        │                                                                      │
        │                    MySQL 8  (source of truth)                       │
        │   vps_servers · trading_accounts · terminal_instances ·            │
        │   terminal_status_logs · health_metrics · terminal_events          │
        │                                                                      │
        │            Redis (cache + queue + heartbeat rate limiting)          │
        └───────────▲───────────────────────────────────────────▲───────────┘
                    │ HTTPS  Bearer <vps_token>                  │
       poll assignments / push heartbeat & events               │
                    │                                            │
      ┌─────────────┴───────────────┐              ┌────────────┴───────────────┐
      │        VPS #1 (Windows)      │              │        VPS #2 (Windows)     │
      │  ┌───────────────────────┐  │              │  ┌───────────────────────┐  │
      │  │   Windows Agent svc    │  │   ...        │  │   Windows Agent svc    │  │
      │  │  (Python, via NSSM)    │  │              │  │                        │  │
      │  │  ┌─────────────────┐   │  │              │  │                        │  │
      │  │  │ Poller          │   │  │              │  │        (same)          │  │
      │  │  │ MT5Manager      │   │  │              │  │                        │  │
      │  │  │ Watchdog        │   │  │              │  │                        │  │
      │  │  │ MetricsCollector│   │  │              │  │                        │  │
      │  │  │ Reporter        │   │  │              │  │                        │  │
      │  │  └────────┬────────┘   │  │              │  └───────────────────────┘  │
      │  └───────────┼────────────┘  │              └─────────────────────────────┘
      │              ▼               │
      │   terminal64.exe  × N        │   Each terminal = 1 account, portable mode,
      │   (one per account,          │   own data dir, own config.ini, auto-login
      │    /portable /config)        │
      └──────────────────────────────┘
```

## 1.3 Control-plane / data-plane split

- **Control plane = Laravel + MySQL.** Single source of truth for *desired state*
  (which account should run where) and *observed state* (last heartbeat, metrics).
  The control plane never SSHes into a VPS or launches processes itself — it only
  records intent.
- **Data plane = Windows Agents.** Each agent is a **reconciliation loop**: it reads
  desired state for *its own* VPS and makes the local machine match it (start /
  stop / restart terminals), then reports observed state back. This is the same
  desired-vs-observed model Kubernetes uses, and it's what makes the system
  resilient: if a VPS reboots, the agent restarts and re-converges automatically
  with zero operator action.

**Why pull, not push:** agents *poll* Laravel rather than Laravel pushing to agents.
VPS boxes sit behind NAT/firewalls with no fixed inbound port; outbound HTTPS always
works. Polling also means a briefly-down control plane never loses commands — the
agent just retries.

## 1.4 Capacity model (important)

| Resource            | Per idle terminal | 30 terminals | Box (4 vCPU / 8 GB) |
|---------------------|-------------------|--------------|---------------------|
| RAM                 | ~150–250 MB       | 4.5–7.5 GB   | 8 GB total          |
| CPU (idle/connected)| ~0.5–2 % of a core| ~15–60 %     | 400 % (4 cores)     |

RAM is the binding constraint, **not** CPU. 30 terminals leaves almost no headroom
for Windows (~1.5–2 GB) + the agent. Recommended **safe cap ≈ 22–25 terminals per
8 GB box**, and let the scheduler (Phase 6) spill the rest onto additional VPS
servers (Phase 7). The `max_terminals`, `ram_soft_limit_mb`, and `cpu_soft_limit_pct`
columns on `vps_servers` enforce this. Treat 30/box as a burst ceiling, not a target.

## 1.5 Folder structure

```
mt5-platform/
├── docs/
│   ├── ARCHITECTURE.md          # this file (Phase 1)
│   ├── DATABASE.md              # Phase 2 — ERD + schema notes
│   ├── API.md                  # Phase 3 — endpoint reference
│   ├── DASHBOARD_SPEC.md       # Phase 8 — dashboard spec
│   ├── DEPLOYMENT.md           # Phase 9 — install & operate
│   └── SECURITY.md             # credential handling, threat model
│
├── backend-laravel/            # drop these into a fresh `laravel new` app
│   ├── database/migrations/    # Phase 2
│   ├── app/Models/             # Eloquent models
│   ├── app/Http/Controllers/Api/
│   ├── app/Http/Middleware/    # AuthenticateAgent
│   ├── app/Http/Requests/      # validation
│   ├── app/Services/           # SchedulerService, HealthService
│   └── routes/api.php          # Phase 3 endpoints
│
└── agent-python/               # Windows Agent (Phase 4 & 5)
    ├── agent.py                # entry point / supervisor loop + bootstrap
    ├── api_client.py           # talks to Laravel Agent API
    ├── mt5_installer.py        # auto-download + silent-install MT5 on bare VPS
    ├── mt5_manager.py          # launch/stop terminal64.exe, warm pool, config.ini
    ├── watchdog.py             # crash detection + restart policy
    ├── metrics.py              # psutil CPU/RAM per PID + host rollup
    ├── config.example.yaml     # per-VPS config
    ├── requirements.txt
    └── install-service.ps1     # register as Windows service via NSSM
```

## 1.6 Reliability model

- **Idempotent reconciliation.** The agent computes the diff between "accounts that
  should run here" and "terminals actually running", then applies only the delta.
  Running the loop twice is a no-op — safe to restart the agent any time.
- **Heartbeat + staleness.** Every terminal has `last_heartbeat_at`. A Laravel cron
  job (`MarkStaleTerminalsOffline`) flips anything with no heartbeat in `N × interval`
  to `offline`, so a dead *agent* (not just a dead terminal) is also visible.
- **Watchdog restart policy.** Exponential backoff with a cap and a
  `max_restarts_per_hour` circuit breaker, so a terminal that crash-loops (bad
  credentials, broker outage) stops thrashing the box and is surfaced as `errored`
  for a human.
- **At-least-once events.** Terminal events (crash, restart, login-failed) are queued
  locally on the agent and re-sent until Laravel ACKs, so a control-plane blip never
  loses an audit record.
- **Zero-touch MT5 provisioning.** A bare VPS needs no MetaTrader pre-install: on first
  boot the agent downloads and silent-installs MT5 (`mt5setup.exe /auto`), resolves the
  real `terminal64.exe` path, and keeps `warm_count` spare terminal folders
  pre-copied. Adding an account on the web is all it takes — the terminal is
  provisioned (instantly from the warm pool) and launched with no manual VPS work.

## 1.7 Security posture (summary — see SECURITY.md)

- MT5 passwords stored **encrypted at rest** (Laravel `encrypted` cast → AES-256-GCM
  via `APP_KEY`), never logged, never returned in list endpoints.
- Each VPS authenticates with a **unique bearer token** (hashed in DB, shown once).
  A compromised VPS token only exposes accounts assigned to *that* VPS.
- All agent↔control-plane traffic is **HTTPS only**; agent pins the CA.
- Agent API is **rate-limited** and scoped: an agent can only read/write rows for its
  own `vps_server_id` (enforced in middleware, not just by convention).
- MT5 config.ini files on the VPS (which contain the password in plaintext for the
  terminal to read) are written to a **per-account folder with locked-down ACLs** and
  deleted on unassignment.
