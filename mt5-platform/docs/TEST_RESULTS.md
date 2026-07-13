# Test Results

What was actually executed (not just linted). Run on Linux: PHP 8.4 + Laravel 13.19
on SQLite for the control plane, Python 3.11 for the agent logic.

> Windows-only pieces — real `terminal64.exe` launch, MT5 silent install, and psutil
> sampling of live terminals — cannot run in a Linux sandbox and must be verified on
> the VPS (`docs/DEPLOYMENT.md §F`). Everything else below ran for real.

## Control plane — full API flow (real HTTP against `php artisan serve`)

| # | Scenario | Result |
|---|----------|--------|
| 1 | Operator registers a bare VPS → one-time agent token issued | ✅ server id=1, token shown once |
| 2 | Agent heartbeat (0 terminals) flips server **offline → online** | ✅ status=online |
| 3 | Operator adds account ("meta details") → scheduler auto-assigns | ✅ placed=True, "Assigned to vps-test-01" |
| 4 | Agent pulls desired state; **password decrypted** for the agent | ✅ action=run, pass round-tripped correctly |
| 5 | Agent reports terminal running+connected → account **connected** | ✅ status=connected, cpu=1.4 ram=232MB |
| 6 | Operator list view **omits the password** | ✅ no `password`/`password_encrypted` key |
| 7 | Operator restart → agent's next poll sees **action=restart** | ✅ |
| 8 | Event ingest **idempotent** (same `event_uid` twice) | ✅ 1 row in DB, both calls ACK the uid |
| 9 | **Capacity guard**: box max=2, 3rd account not placed | ✅ acct#3 placed=False, "fleet at capacity" |
| 10| **Auth**: bad agent token / no operator token | ✅ both 401 (with `Accept: application/json`) |

Encryption: the MT5 password stored via the `encrypted` cast (AES-256-GCM, `APP_KEY`)
decrypts back to the exact input only on the agent endpoint — confirmed in test 4.

## Agent watchdog — deterministic tests (`test_watchdog.py`)

| Check | Result |
|-------|--------|
| First crash → restart allowed | ✅ `(True, ok)` |
| Blocked immediately after (backoff gate) | ✅ `(False, backoff)` |
| Backoff is exponential | ✅ observed delays **2, 4, 8, 16s** |
| Circuit breaker trips after max restarts/hour | ✅ `(False, circuit_breaker_open)`, tripped=True |
| Recovery (`record_healthy`) resets state | ✅ allowed again, tripped=False |

## Agent warm pool — real filesystem test (`test_agent_logic.py`)

| Check | Result |
|-------|--------|
| Pool pre-provisions `warm_count` spare(s) | ✅ 1 slot ready |
| New account **claims warm slot instantly** (rename, no copy) | ✅ provisioned in **0.4 ms** |
| Pool refills back to target after a claim | ✅ back to 1 |
| Empty pool → falls back to full copy | ✅ still provisions |

## Not yet tested (needs the Windows VPS)
- `mt5setup.exe /auto` silent install + `terminal64.exe` resolution.
- Real terminal launch with generated `start.ini` auto-login.
- psutil CPU/RAM sampling of live MT5 processes.
- NSSM service install + auto-restart.

These are exercised by the live walkthrough in `docs/DEPLOYMENT.md §F`.
