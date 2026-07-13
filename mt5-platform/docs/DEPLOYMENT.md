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

### Register the agent middleware alias + JSON 401s
Laravel 11+ — in `bootstrap/app.php`:
```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias(['agent.auth' => \App\Http\Middleware\AuthenticateAgent::class]);
})
->withExceptions(function (Exceptions $exceptions) {
    // Return 401 JSON for unauthenticated API calls even without an Accept header
    // (otherwise guests get a 500 from the missing web 'login' route).
    $exceptions->render(function (\Illuminate\Auth\AuthenticationException $e, $request) {
        if ($request->is('api/*')) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }
    });
})
```
Laravel 10 — add the alias to `$middlewareAliases` in `app/Http/Kernel.php`.

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
- **MetaTrader 5 does NOT need to be pre-installed.** With `mt5.auto_install: true`
  (default) the agent downloads `mt5setup.exe` and silent-installs it (`/auto`) on
  first boot, then keeps `warm_count` spare terminals pre-provisioned so new accounts
  launch instantly. A bare Windows VPS is enough. (For a broker that requires its own
  branded build, set `mt5.installer_urls["<Broker-Server>"]`.)
- Python 3.11+ (`python.exe`).
- NSSM (https://nssm.cc) for the service wrapper.
- Enough disk for one MT5 copy per account (~few hundred MB each; budget ~10 GB for
  ~25 accounts) plus the warm spare(s). If disk is tight, lower `warm_count` to 0.

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

## F. Everything on ONE Windows VPS (simplest test setup)

Run the control plane **and** the agent on the same bare VPS. Fastest way to a real
end-to-end test; MT5 installs itself.

```powershell
# 1. Install runtimes (Chocolatey makes this one-liner-ish)
Set-ExecutionPolicy Bypass -Scope Process -Force
iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex
choco install -y php composer python nssm

# 2. Control plane (SQLite = no MySQL to configure for a test)
composer create-project laravel/laravel C:\mt5-panel
cd C:\mt5-panel
composer require laravel/sanctum
#  copy backend-laravel\app\*, database\*, routes\api.php into C:\mt5-panel
#  edit bootstrap\app.php (alias + 401 render, see above)
#  add HasApiTokens to app\Models\User.php
New-Item database\database.sqlite -ItemType File -Force
#  in .env set: DB_CONNECTION=sqlite   (comment out the other DB_* lines)
php artisan install:api --no-interaction
php artisan key:generate           # APP_KEY — decrypts MT5 passwords. BACK IT UP.
php artisan migrate
#  serve it (behind IIS/Apache for prod; for a test:)
Start-Process php -ArgumentList 'artisan','serve','--host=0.0.0.0','--port=8000'

# 3. Register this VPS, grab the token
#    POST http://127.0.0.1:8000/api/servers  (with a Sanctum token) → copy agent_token

# 4. Agent — points at the local panel; auto-installs MT5 on first run
cd path\to\agent-python
copy config.example.yaml config.yaml
#  set api.base_url = http://127.0.0.1:8000/api  and api.token = <agent_token>
#  set api.verify_tls = false ONLY for this localhost test (use HTTPS in prod)
.\install-service.ps1 -InstallDir "C:\mt5agent"
```
Then add an account via `POST /api/accounts` and watch the agent auto-install MT5,
provision the terminal, and report it back. Move MySQL + HTTPS in once the flow works.

> Getting a **Sanctum token** for the operator calls in a test: `php artisan tinker`
> then `\App\Models\User::factory()->create()->createToken('t')->plainTextToken;`

## E. Operational runbook
| Symptom | Check | Fix |
|---|---|---|
| Server stuck **offline** | agent log, outbound 443, token | restart service / rotate token |
| Account stuck **connecting** | terminal log in its data_dir, broker server name | fix `broker_server`, restart |
| Terminal **errored** (breaker open) | `terminal_events` message | usually bad password — update + start |
| Accounts **unassigned** | fleet at capacity | add a VPS or raise `max_terminals` cautiously |
| RAM near limit | server card | lower `max_terminals`, spread load |
