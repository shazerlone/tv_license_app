# MT4 → MT5 Lightning Trade Copier

Two EAs that mirror trades from MetaTrader 4 (master) to MetaTrader 5 (slave) in ~10ms locally via a shared file in the MT Common folder.

## Files

| File | Platform | Role |
|------|----------|------|
| `Master_Sender.mq4` | MetaTrader 4 | Watches trades, writes signals |
| `Slave_Receiver.mq5` | MetaTrader 5 | Reads signals, executes trades |

---

## Installation

### Master (MT4)
1. Copy `Master_Sender.mq4` → `[MT4 data folder]/MQL4/Experts/`
2. Compile in MetaEditor (F7)
3. Attach to any chart (e.g. XAUUSD M1)
4. Configure inputs (see below)

### Slave (MT5)
1. Copy `Slave_Receiver.mq5` → `[MT5 data folder]/MQL5/Experts/`
2. Compile in MetaEditor (F7)
3. Attach to any chart (e.g. XAU_CASH M1)
4. Configure inputs (see below)
5. Enable **"Allow algorithmic trading"** in MT5 EA settings

> Both terminals must be running on the **same machine** for the Common folder to be shared.

---

## Settings

### Master_Sender.mq4

| Input | Default | Description |
|-------|---------|-------------|
| `MasterSymbol` | `XAUUSD` | Symbol to watch on MT4 |
| `SlaveSymbol` | `XAU_CASH` | Symbol name on MT5 slave |
| `LotMultiplier` | `100.0` | Multiply MT4 lots by this value (0.1 lot × 100 = 10 lots on slave) |
| `MagicNumber` | `99001` | Only copy trades with this magic (set 0 to copy all) |
| `SignalFile` | `mt_copier_signal.csv` | Shared file name — **must match slave setting** |
| `TimerMs` | `10` | Polling interval in milliseconds |
| `CopyAllSymbols` | `false` | Copy every symbol, not just MasterSymbol |
| `EnableLogging` | `true` | Print log to Experts tab |

### Slave_Receiver.mq5

| Input | Default | Description |
|-------|---------|-------------|
| `SlaveSymbol` | `XAU_CASH` | Symbol to trade on MT5 |
| `MasterSymbol` | `XAUUSD` | Reference only (for symbol mapping) |
| `LotMultiplier` | `100.0` | Set to `1.0` if master EA already multiplied; set higher to stack |
| `SlaveMagic` | `99002` | Magic number stamped on slave trades |
| `SignalFile` | `mt_copier_signal.csv` | Must match master setting |
| `TimerMs` | `10` | Polling interval in milliseconds |
| `MaxSlippage` | `30` | Max execution slippage in points |
| `EnableLogging` | `true` | Print log to Experts tab |

---

## How lot sizing works

```
MT4 opens 0.1 lot XAUUSD
  → Master EA × LotMultiplier (100) = 10.0 lots
  → Slave EA opens 10.0 lots XAU_CASH
```

The `LotMultiplier` in **Master_Sender** is what does the conversion. Leave `LotMultiplier` in **Slave_Receiver** at `1.0` unless you want to stack a second multiplier.

---

## How it works (architecture)

```
MT4 (OnTick + 10ms timer)
  → detects new/closed/modified position
  → writes one-line CSV to Common folder (atomic tmp→rename)

MT5 (10ms timer)
  → reads CSV if file exists and line is new
  → parses: ACTION, MASTER_TICKET, SYMBOL, TYPE, LOTS, PRICE, SL, TP
  → executes Buy/Sell/Close/Modify
  → maintains master_ticket ↔ slave_ticket map in memory
```

Latency is dominated by the OS file flush cycle — typically **< 20ms** on a local machine.

---

## Troubleshooting

- **Slave not receiving signals**: Check both EAs use the same `SignalFile` name and that both have access to the Common folder (`FILE_COMMON` flag is used internally).
- **Wrong lot size**: Confirm `LotMultiplier` in Master_Sender and set Slave_Receiver `LotMultiplier = 1.0`.
- **Symbol not found**: Ensure `SlaveSymbol` exactly matches the symbol name in MT5 Market Watch (case-sensitive).
- **ORDER_FILLING_IOC rejected**: Change filling mode in Slave_Receiver `trade.SetTypeFilling()` to `ORDER_FILLING_FOK` or `ORDER_FILLING_RETURN` depending on your broker.
