# CopyTrader Pro (prototype)

A Windows desktop **copy-trading controller** for MetaTrader 4 & 5 — in the
spirit of TraderConnects. This is the **UI prototype**: the full interface is
built and interactive, running against a stub data layer so it can be demoed
on any machine before the live trading engine is wired in.

![dashboard](docs/dashboard.png)

## Features in this prototype

- **Dashboard** — engine start/stop, live stat cards, recent copied-trades table.
- **Terminals & Accounts** — "Scan" button that detects running MT4/MT5
  terminals and their logged-in accounts (stubbed with demo data for now).
- **Master / Slave** — pick **one master**, attach **multiple slaves**, and
  tune each slave independently:
  - Enable / disable
  - Lot mode: Multiplier · Fixed lot · Balance ratio · Equity ratio
  - Lot value, Reverse (mirror direction), Copy SL/TP
- **Symbol Mapping** — **auto-maps** symbols across brokers by matching the
  base instrument and ignoring common suffixes/prefixes
  (`XAUUSD` ↔ `XAUUSDz` / `XAUUSD.m` / `XAUUSD.r`, `EURUSD` ↔ `EUR/USD`).
  Names that can't be matched (e.g. `XAUUSD` vs `GOLD_CASH`) show as
  **Unmapped** and get a per-slave **manual** map. See `auto_match_symbol()`
  in `models.py`.
- **Logs** — rolling activity log.

## Run from source

```bash
pip install -r copytrader_app/requirements.txt
python run_copytrader.py
```

> On Linux you also need Tk: `sudo apt install python3-tk`.
> On Windows, Tk ships with the standard Python installer.

## Build the Windows .exe

Run **on Windows** (PyInstaller builds for the OS it runs on):

```bash
pip install -r copytrader_app/requirements.txt
python build_exe.py
```

Produces `dist/CopyTraderPro.exe` — a single-file, windowed executable.
Drop an `app.ico` next to `build_exe.py` to set a custom icon.

## Project layout

```
run_copytrader.py          # launcher / PyInstaller entry point
build_exe.py               # one-command .exe builder
copytrader_app/
  models.py                # data models + AppState (stub seed data lives here)
  connectors.py            # terminal scanner + MT4/MT5 connectors (STUBBED)
  main.py                  # window shell + sidebar navigation
  ui/                      # one module per page
    widgets.py             # theme + shared widgets (cards, tables, buttons)
    dashboard.py terminals.py masterslave.py mapping.py settings.py logs.py
  live/                    # LIVE TRADING ENGINE
    types.py               # broker-neutral Position / OrderRequest / etc.
    sizing.py              # pure lot-sizing maths (unit tested)
    clients.py             # BrokerClient interface + FakeClient (demo)
    engine.py              # the copy engine (detect -> size -> replicate)
    mt5_client.py          # live MetaTrader 5 (official API)
    mt4_client.py          # live MetaTrader 4 (file bridge)
    ea/CopyTraderBridge.mq4# Expert Advisor installed in each MT4 terminal
  tests/test_engine.py     # engine + sizing tests (run on any OS)
```

## How live trading works

The engine (`live/engine.py`) polls each **master**, detects newly opened /
closed positions, and replicates them to every enabled **slave**:
auto/manual symbol mapping → per-slave lot rule (multiplier / fixed / balance
ratio / equity ratio) → reverse & SL/TP options → order. It talks to a
`BrokerClient`, so MT5, MT4 and the demo `FakeClient` are interchangeable.

Run the tests (no MetaTrader needed):

```bash
python -m unittest copytrader_app.tests.test_engine
```

### Demo mode (default)
Settings → **Live mode OFF**. Simulated brokers generate master trades so you
can watch the whole pipeline on the Dashboard. Nothing real trades.

### Going live — MT5
1. Install each account in its **own** MT5 terminal and log it in.
2. **Settings → Live mode ON**, keep **Dry-run ON** for the first runs.
3. **Terminals → Add account**: set platform MT5 and the terminal path
   (e.g. `C:\Program Files\IC Markets MT5`). Login/password/server are
   optional if the terminal is already logged in.
4. Assign master/slaves, check Symbol Mapping, press **Start copying**.
5. Watch the Dashboard/Logs. When the dry-run trades look correct, turn
   **Dry-run OFF** to place real orders.

### Going live — MT4
MT4 has no API, so each MT4 terminal needs the bridge EA:
1. In MT4: **File → Open Data Folder**, copy
   `live/ea/CopyTraderBridge.mq4` into `MQL4/Experts/`.
2. MetaEditor → **Compile (F7)**, then drag the EA onto any chart and tick
   **Allow live trading**.
3. **Terminals → Add account**: platform MT4, and set **MT4 Files folder** to
   that data folder's `MQL4/Files` path.
4. Proceed as with MT5 (dry-run first).

> ⚠️ **Safety:** dry-run is ON by default and the app starts in demo mode.
> Always validate on **demo accounts** before going live. Copy-trade only
> accounts you own or are authorized to operate.

### Scaling note
The MT5 client switches the (process-global) connection between terminals
each cycle — fine for a handful of accounts at a 1–2s poll. For many accounts
/ lower latency, the upgrade path is one worker **process** per terminal
behind the same `BrokerClient` interface.
