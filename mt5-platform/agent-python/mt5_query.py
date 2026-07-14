"""Read REAL account data (balance, equity, open trades) from a running MT5
terminal via the official MetaTrader5 package. This is what makes "connected"
trustworthy — it only returns data when the account genuinely logged in.

Windows-only (MetaTrader5 wheel). Import is guarded so the agent still runs
(without balances) if the package is missing.
"""
from __future__ import annotations

import logging

log = logging.getLogger("agent.mt5query")

try:
    import MetaTrader5 as mt5   # noqa: N813
    HAVE_MT5 = True
except Exception:               # noqa: BLE001 - not installed / not Windows
    HAVE_MT5 = False


def query(terminal_exe: str, login: str | int, password: str, server: str,
          timeout_ms: int = 15000) -> dict | None:
    """Attach to the terminal, confirm login, return account data.

    Returns:
      {logged_in: True, balance, equity, profit, open_trades, currency, leverage, name}
      {logged_in: False, error: "..."}                      on failure
      None                                                  if MetaTrader5 unavailable
    """
    if not HAVE_MT5:
        return None

    try:
        ok = mt5.initialize(
            path=terminal_exe,
            login=int(login),
            password=password,
            server=server,
            timeout=timeout_ms,
            portable=True,
        )
        if not ok:
            code, msg = mt5.last_error()
            return {"logged_in": False, "error": f"{code}: {msg}"}

        info = mt5.account_info()
        if info is None:
            code, msg = mt5.last_error()
            return {"logged_in": False, "error": f"account_info: {code}: {msg}"}

        # Guard against attaching to the wrong terminal instance.
        if int(info.login) != int(login):
            return {"logged_in": False, "error": f"login mismatch (got {info.login})"}

        positions = mt5.positions_total()
        return {
            "logged_in": True,
            "balance": round(float(info.balance), 2),
            "equity": round(float(info.equity), 2),
            "profit": round(float(info.profit), 2),
            "open_trades": int(positions) if positions is not None else 0,
            "currency": info.currency,
            "leverage": int(info.leverage),
            "name": info.name,
            "server": info.server,
        }
    except Exception as exc:     # noqa: BLE001 - never let a query crash the agent
        log.warning("MT5 query failed for %s: %s", login, exc)
        return {"logged_in": False, "error": str(exc)}
    finally:
        try:
            mt5.shutdown()
        except Exception:        # noqa: BLE001
            pass
