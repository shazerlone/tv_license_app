"""A tiny, long-lived process that owns ONE MT5 IPC connection to an already-
running terminal and speaks line-delimited JSON on stdin/stdout.

The MetaTrader5 package allows a single terminal connection per OS process, so
the copier runs one of these per participating terminal (reader for masters,
writer for slaves) instead of spawning terminals or attaching EAs. ~30 MB each.

Commands (one JSON object per stdin line), each answered with one stdout line:
  {"id":1,"cmd":"positions"}                      -> {"id":1,"ok":true,"positions":[...]}
  {"id":2,"cmd":"account"}                         -> {"id":2,"ok":true,"account":{...}}
  {"id":3,"cmd":"open","symbol":..,"side":"buy",
          "volume":0.2,"sl":..,"tp":..,"deviation":20}
                                                  -> {"id":3,"ok":true,"ticket":123}
  {"id":4,"cmd":"close","ticket":123}             -> {"id":4,"ok":true}
"""
from __future__ import annotations

import argparse
import json
import math
import sys

try:
    import MetaTrader5 as mt5   # noqa: N813  (Windows only)
except Exception as exc:        # pragma: no cover
    sys.stdout.write(json.dumps({"ok": False, "fatal": f"MetaTrader5 import failed: {exc}"}) + "\n")
    sys.stdout.flush()
    sys.exit(1)

_FILLINGS = None   # resolved lazily per symbol


def _reply(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def _normalize_volume(symbol: str, volume: float) -> float:
    info = mt5.symbol_info(symbol)
    if not info:
        return round(volume, 2)
    step = info.volume_step or 0.01
    vmin = info.volume_min or step
    vmax = info.volume_max or 1e9
    v = math.floor(volume / step + 1e-9) * step
    v = max(vmin, min(vmax, v))
    return round(v, 3)


def _filling_modes():
    return [mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_FOK, mt5.ORDER_FILLING_RETURN]


def cmd_positions():
    ps = mt5.positions_get() or []
    return {"ok": True, "positions": [{
        "ticket": int(p.ticket),
        "symbol": p.symbol,
        "side": "buy" if p.type == mt5.POSITION_TYPE_BUY else "sell",
        "volume": float(p.volume),
        "sl": float(p.sl), "tp": float(p.tp),
        "price_open": float(p.price_open),
    } for p in ps]}


def cmd_account():
    a = mt5.account_info()
    if not a:
        return {"ok": False, "error": "no account_info"}
    return {"ok": True, "account": {
        "login": int(a.login), "balance": round(float(a.balance), 2),
        "equity": round(float(a.equity), 2), "profit": round(float(a.profit), 2),
        "currency": a.currency, "leverage": int(a.leverage),
        "open_trades": mt5.positions_total() or 0,
    }}


def cmd_open(c):
    symbol = c["symbol"]
    if not mt5.symbol_select(symbol, True):
        return {"ok": False, "error": f"symbol_select failed: {symbol}"}
    tick = mt5.symbol_info_tick(symbol)
    if not tick:
        return {"ok": False, "error": f"no tick for {symbol}"}
    side = c["side"]
    order_type = mt5.ORDER_TYPE_BUY if side == "buy" else mt5.ORDER_TYPE_SELL
    price = tick.ask if side == "buy" else tick.bid
    volume = _normalize_volume(symbol, float(c["volume"]))

    base = {
        "action": mt5.TRADE_ACTION_DEAL, "symbol": symbol, "volume": volume,
        "type": order_type, "price": price,
        "deviation": int(c.get("deviation", 20)),
        "type_time": mt5.ORDER_TIME_GTC, "comment": "copier",
    }
    if c.get("sl"):
        base["sl"] = float(c["sl"])
    if c.get("tp"):
        base["tp"] = float(c["tp"])

    last = None
    for fill in _filling_modes():          # brokers differ on allowed filling
        req = dict(base, type_filling=fill)
        r = mt5.order_send(req)
        if r and r.retcode == mt5.TRADE_RETCODE_DONE:
            return {"ok": True, "ticket": int(r.order), "volume": volume}
        last = r
        if r and r.retcode not in (mt5.TRADE_RETCODE_INVALID_FILL,):
            break
    code = getattr(last, "retcode", None)
    return {"ok": False, "error": f"order_send failed retcode={code}", "volume": volume}


def cmd_close(c):
    ticket = int(c["ticket"])
    positions = mt5.positions_get(ticket=ticket)
    if not positions:
        return {"ok": True, "already_closed": True}
    p = positions[0]
    close_type = mt5.ORDER_TYPE_SELL if p.type == mt5.POSITION_TYPE_BUY else mt5.ORDER_TYPE_BUY
    tick = mt5.symbol_info_tick(p.symbol)
    price = tick.bid if p.type == mt5.POSITION_TYPE_BUY else tick.ask
    base = {
        "action": mt5.TRADE_ACTION_DEAL, "symbol": p.symbol, "volume": float(p.volume),
        "type": close_type, "position": ticket, "price": price,
        "deviation": int(c.get("deviation", 50)), "comment": "copier close",
    }
    for fill in _filling_modes():
        r = mt5.order_send(dict(base, type_filling=fill))
        if r and r.retcode == mt5.TRADE_RETCODE_DONE:
            return {"ok": True}
        if r and r.retcode not in (mt5.TRADE_RETCODE_INVALID_FILL,):
            break
    return {"ok": False, "error": f"close failed retcode={getattr(r,'retcode',None)}"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True)
    ap.add_argument("--login", type=int, required=True)
    ap.add_argument("--password", default="")
    ap.add_argument("--server", default="")
    args = ap.parse_args()

    ok = mt5.initialize(path=args.exe, login=args.login,
                        password=args.password, server=args.server,
                        portable=True, timeout=20000)
    if not ok:
        _reply({"ok": False, "fatal": f"initialize failed: {mt5.last_error()}"})
        return
    _reply({"ok": True, "ready": True, "login": args.login})

    handlers = {
        "positions": lambda c: cmd_positions(),
        "account": lambda c: cmd_account(),
        "open": cmd_open,
        "close": cmd_close,
    }
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            c = json.loads(line)
            fn = handlers.get(c.get("cmd"))
            resp = fn(c) if fn else {"ok": False, "error": "unknown cmd"}
        except Exception as exc:            # never die on a bad command
            resp = {"ok": False, "error": str(exc)}
        resp["id"] = c.get("id") if isinstance(c, dict) else None
        _reply(resp)

    mt5.shutdown()


if __name__ == "__main__":
    main()
