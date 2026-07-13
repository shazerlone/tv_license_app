# Phase 2 — Database Design

MySQL 8. Six tables. `vps_servers` and `trading_accounts` hold *desired* state
(operator intent); `terminal_instances`, `health_metrics`, `terminal_status_logs`,
and `terminal_events` hold *observed* state (what the agents report).

## ER diagram

```
vps_servers 1───∞ trading_accounts 1───1 terminal_instances
     │                    │                     │
     │ 1                  │ 1                    │ 1
     ├──────────────∞ health_metrics            │
     │                                           │
     ├──────────────∞ terminal_status_logs ∞────┤
     │                                           │
     └──────────────∞ terminal_events ∞─────────┘
```

## Tables

### `vps_servers`  — the fleet
Desired capacity + last observed host health (denormalised for fast dashboard reads).
Key columns: `agent_token_hash` (SHA-256 of the bearer token — raw never stored),
`max_terminals`, `ram_soft_limit_mb`, `cpu_soft_limit_pct` (scheduler ceilings),
`active_terminals`, `last_cpu_pct`, `last_ram_used_mb`, `status`
(`online|offline|draining|disabled`), `last_heartbeat_at`.

### `trading_accounts`  — the operator's "meta details"
`login` + `broker_server` (unique together), `password_encrypted`
(**AES-256-GCM at rest** via Laravel `encrypted` cast), `password_type`,
`desired_state` (`running|stopped`), `vps_server_id` (placement, null = unassigned),
`status` (`unassigned|assigned|connecting|connected|disconnected|errored|stopped`).
Soft-deletable.

### `terminal_instances`  — one live terminal per account
`os_pid`, `data_dir`, `instance_key`, `status`
(`starting|running|connected|crashed|restarting|stopped|errored`),
`cpu_pct`, `ram_mb`, `mt5_connected`, `restart_count`, `last_error`,
`last_heartbeat_at`. Unique on `trading_account_id`.

### `health_metrics`  — host time series
One row per heartbeat: `cpu_pct`, `ram_used_mb`, `ram_total_mb`,
`active_terminals`, `disk_free_mb`, `load_avg`, `sampled_at`. Drives the charts.
Prune > N days (see DEPLOYMENT.md).

### `terminal_status_logs`  — transition audit
Append-only. Records only *changes* in terminal status (keeps it lean). Powers the
per-account timeline.

### `terminal_events`  — discrete incidents
`event_uid` (UUID, **unique** → idempotent at-least-once ingest), `type`
(`crashed|restarted|login_failed|disconnected|resource_limit|…`), `severity`,
`message`, `context` (JSON), `occurred_at`.

## Why denormalise `last_*` onto `vps_servers`/`terminal_instances`?
The dashboard's "current state" view must be O(1) per row. Rather than aggregating
`health_metrics`/`terminal_status_logs` on every page load, the heartbeat controller
writes the latest values straight onto the parent row. The time-series tables remain
the source for charts and history.

## Indexing highlights
- `vps_servers (status, active_terminals)` — scheduler's least-loaded lookup.
- `trading_accounts (desired_state, vps_server_id)` — find pending placements.
- `terminal_instances (last_heartbeat_at)` — stale sweep.
- `health_metrics (vps_server_id, sampled_at)` — chart range scans.

## Migrations
All six live in `backend-laravel/database/migrations/`. Run with `php artisan migrate`.
