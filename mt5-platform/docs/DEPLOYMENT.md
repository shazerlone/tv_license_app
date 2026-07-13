# Phase 9 — Deployment & Operations

Two deployables: the **Laravel control plane** (one box, anywhere) and the
**Windows Agent** (one per VPS).

## A. Control plane (Laravel + MySQL)

```bash
# 1. Fresh Laravel app
composer create-project laravel/laravel mt5-panel
cd mt5-panel
composer require laravel/sanctum

# 2. Drop in the provided code
#    copy backend-laravel/app/*        -> app/
#    copy backend-laravel/database/*   -> database/
#    copy backend-laravel/routes/api.php -> routes/api.php

# 3. Configure .env (MySQL, then generate the encryption key)
php artisan key:generate          # sets APP_KEY — this key decrypts MT5 passwords. BACK IT UP.
#   DB_CONNECTION=mysql ; DB_DATABASE=mt5 ; ...

# 4. Migrate
php artisan migrate
```

### Register the agent middleware alias
Laravel 11+ — in `bootstrap/app.php`:
```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias(['agent.auth' => \App\Http\Middleware\AuthenticateAgent::class]);
})
```
Laravel 10 — add to `$middlewareAliases` in `app/Http/Kernel.php`.

### Schedule the background jobs
`routes/console.php` (or `Kernel::schedule`):
```php
use Illuminate\Support\Facades\Schedule;

Schedule::command('mt5:mark-stale')->everyMinute();                 // offline detection
Schedule::command('model:prune')->daily();                          // if you add Prunable
// Optional: rebalance pending accounts every few minutes
Schedule::call(fn () => app(\App\Services\SchedulerService::class)->placePending())
        ->everyFiveMinutes();
```
Run the scheduler: a cron entry `* * * * * php artisan schedule:run` (Linux) or a
Task Scheduler task (Windows). Also run a queue worker if you move ingest to jobs:
`php artisan queue:work`.

### Data retention (tables grow fast)
Prune `health_metrics` > 14 days and `terminal_status_logs` > 30 days with a daily
job, e.g.:
```php
Schedule::call(function () {
    \App\Models\HealthMetric::where('sampled_at', '<', now()->subDays(14))->delete();
    \App\Models\TerminalStatusLog::where('created_at', '<', now()->subDays(30))->delete();
})->dailyAt('03:00');
```

### Serve behind HTTPS
Nginx/Apache + Let's Encrypt (or your CA). The agent **requires** a valid cert.

---

## B. Windows Agent (per VPS)

### Prereqs on the VPS
- MetaTrader 5 installed at `C:\Program Files\MetaTrader 5\terminal64.exe`
  (or point `mt5.terminal_exe` at wherever it lives).
- Python 3.11+ (`python.exe`).
- NSSM (https://nssm.cc) for the service wrapper.
- Enough disk for one MT5 copy per account (~few hundred MB each; budget ~10 GB for
  ~25 accounts). If disk is tight, share one install via junctions instead of copies.

### Register the server, then install
```powershell
# 1. On the panel: POST /api/servers  -> copy the returned agent_token
#    (e.g. via curl / the dashboard "Add server" modal)

# 2. On the VPS: copy the agent-python folder over, then
cd agent-python
copy config.example.yaml config.yaml
notepad config.yaml         # set api.base_url + api.token + mt5.terminal_exe

# 3. Install as an auto-start, auto-restart service
.\install-service.ps1 -InstallDir "C:\mt5agent"
```
The installer copies sources, installs deps, **locks `config.yaml` ACLs**, and
registers `MT5Agent` under NSSM with crash auto-restart.

### Verify
```powershell
nssm status MT5Agent
Get-Content C:\mt5agent\logs\agent.log -Wait
```
Within ~20 s the panel's server should flip to **online** and start reporting CPU/RAM.
Assign an account (`POST /accounts`) and watch a `terminal64.exe` spawn.

---

## C. End-to-end smoke test
1. `POST /servers` → get token → configure + start agent → server shows **online**.
2. `POST /accounts` with a demo MT5 login → `placed:true`.
3. Agent's next reconcile launches the terminal; heartbeat reports it `running`,
   then `mt5_connected:true` once the broker link is up → account **connected**.
4. Kill `terminal64.exe` in Task Manager → within one heartbeat the watchdog restarts
   it; a `restarted` event appears in the dashboard feed.
5. `POST /accounts/{id}/stop` → terminal is torn down, slot freed.

## D. Scaling out (Phase 7 in practice)
- Add VPS #2: repeat section B. The scheduler automatically sends new accounts to the
  least-loaded online server.
- To retire a box: `POST /servers/{id}/status {status:"draining"}` (no new
  assignments), move its accounts (stop → they re-place elsewhere), then `disabled`.

## E. Operational runbook
| Symptom | Check | Fix |
|---|---|---|
| Server stuck **offline** | agent log, outbound 443, token | restart service / rotate token |
| Account stuck **connecting** | terminal log in its data_dir, broker server name | fix `broker_server`, restart |
| Terminal **errored** (breaker open) | `terminal_events` message | usually bad password — update + start |
| Accounts **unassigned** | fleet at capacity | add a VPS or raise `max_terminals` cautiously |
| RAM near limit | server card | lower `max_terminals`, spread load |
