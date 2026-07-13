# Phase 8 — Monitoring Dashboard Specification (Laravel)

Stack suggestion: **Laravel + Livewire** (or Inertia/Vue) with **Chart.js** for
graphs and a 5–10 s poll (or Laravel Echo/WebSockets if you want push). Everything
below reads from the denormalised columns + time-series tables — no heavy joins.

## Layout

```
┌───────────────────────────────────────────────────────────────────────┐
│  MT5 Fleet                                    ● 3/3 servers online      │
├──────────────┬──────────────┬──────────────┬─────────────┬────────────┤
│ Terminals    │ Online       │ Offline      │ Errored     │ Fleet RAM  │  ← KPI tiles
│   58         │   54  ▲       │   3   ▼      │   1  ⚠      │ 71%        │
├──────────────┴──────────────┴──────────────┴─────────────┴────────────┤
│  SERVERS                                                               │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │ vps-lon-01  ● online   18/22 term   CPU 34%  RAM 5.1/8.0 GB    │   │
│  │  [────────── CPU sparkline ──────────]  [──── RAM sparkline ──] │   │
│  ├───────────────────────────────────────────────────────────────┤   │
│  │ vps-fra-02  ● online   22/22 term   CPU 61%  RAM 6.4/8.0 GB ⚠  │   │
│  └───────────────────────────────────────────────────────────────┘   │
├───────────────────────────────────────────────────────────────────────┤
│  TERMINALS (filter: all ▾  server ▾  status ▾  search)               │
│  Login     Label          Server      Status     CPU   RAM    Uptime  │
│  8125660   Client A       vps-lon-01  ●connected 1.4%  232MB  3d 2h   │
│  8130221   Client B       vps-fra-02  ⟳restart.. 0%    —      —       │
│  8140904   Client C       vps-lon-01  ✕crashed   —     —      —    [↻] │
└───────────────────────────────────────────────────────────────────────┘
```

## Widgets & data sources

| Widget | Source | Query |
|---|---|---|
| **KPI: total / online / offline / errored terminals** | `terminal_instances.status` | `GROUP BY status` |
| **KPI: fleet RAM %** | `vps_servers` | `SUM(last_ram_used_mb)/SUM(total_ram_mb)` |
| **Server card: CPU/RAM now** | `vps_servers.last_cpu_pct`, `last_ram_used_mb` | direct read |
| **Server card: N/max terminals** | `vps_servers.active_terminals`, `max_terminals` | direct read |
| **Server sparklines** | `GET /servers/{id}/health?hours=6` | `health_metrics` range |
| **Server status dot** | `vps_servers.status` + `last_heartbeat_at` | online/offline/draining |
| **Terminal table** | `GET /accounts` (joins terminal) | paginated, filterable |
| **Account status pill** | `trading_accounts.status` | connected/connecting/errored/… |
| **Per-account timeline** | `terminal_status_logs` | `WHERE trading_account_id` |
| **Events / alerts feed** | `terminal_events` | `severity IN (error,critical)` recent |

## Status colour key
`connected` green · `connecting/starting/restarting` amber (pulsing) ·
`crashed/errored` red · `stopped` grey · `disconnected` orange.

## Actions in the UI (wire to Operator API)
- **Restart** button on a terminal row → `POST /accounts/{id}/restart`.
- **Stop / Start** toggle → `POST /accounts/{id}/stop|start`.
- **Drain server** (stop new assignments) → `POST /servers/{id}/status {status:"draining"}`.
- **Add account** modal (login / server / password / label) → `POST /accounts`.
- **Add server** → `POST /servers`, show the returned token once in a copy-box.

## Alerting rules (surface as banners / optional email/Telegram)
- Server `offline` (missed heartbeats) → critical.
- Terminal `errored` / circuit-breaker open → critical.
- Server RAM ≥ soft limit or CPU ≥ soft limit → warning.
- Fleet has `unassigned` accounts (capacity exhausted) → warning + "add VPS" CTA.

## Refresh
Poll KPIs + server cards every 5 s; the terminal table every 10 s; charts pull a
6 h window on card expand. Prefer WebSockets only if you outgrow polling.
