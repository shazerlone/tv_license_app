"""Terminal discovery + platform connectors.

PROTOTYPE STATUS
----------------
Everything in this module is a STUB that returns demo data so the UI runs
on any OS (including this Linux dev box). The real implementation notes are
written inline as TODOs so wiring live trading later is mechanical.

Live design (for reference):

  * MT5  -> the official ``MetaTrader5`` pip package. ``mt5.initialize(path=...)``
           attaches to a specific running terminal; ``account_info()``,
           ``positions_get()`` read state and ``order_send()`` places trades.
           One terminal per process, so multiple terminals = multiple worker
           processes keyed by ``terminal_path``.
  * MT4  -> no official API. Ship a small Expert Advisor (EA) "bridge" that
           runs inside each MT4 terminal and exchanges JSON over files or a
           local socket. This module would talk to that bridge.

Terminal detection is done by scanning running processes for
``terminal64.exe`` / ``terminal.exe`` and reading each terminal's config to
find the logged-in account.
"""
from __future__ import annotations

from .models import Account, AppState, Platform


def scan_terminals() -> list[Account]:
    """Discover running MT4/MT5 terminals and their accounts.

    Returns demo accounts in the prototype. Replace the body with the real
    process scan (see ``_real_scan`` sketch below).
    """
    state = AppState()           # reuse the seeded stub accounts
    return state.accounts


def _real_scan() -> list[Account]:  # pragma: no cover - reference only
    """Sketch of the real implementation (Windows).

    Not called in the prototype. Kept so the intended approach is explicit.
    """
    import psutil  # noqa: F401  (only available/needed at runtime on the host)

    found: list[Account] = []
    # for proc in psutil.process_iter(["name", "exe", "pid"]):
    #     name = (proc.info.get("name") or "").lower()
    #     if name in ("terminal64.exe", "terminal.exe"):
    #         platform = Platform.MT5 if name == "terminal64.exe" else Platform.MT4
    #         path = proc.info.get("exe") or ""
    #         acct = read_logged_in_account(path, platform)  # TODO parse config
    #         if acct:
    #             found.append(acct)
    return found


class MT5Connector:
    """Live MT5 bridge — stubbed. Methods mirror the eventual real API."""

    def __init__(self, terminal_path: str) -> None:
        self.terminal_path = terminal_path
        self.connected = False

    def connect(self) -> bool:
        # TODO: import MetaTrader5 as mt5; return mt5.initialize(path=self.terminal_path)
        self.connected = True
        return True

    def positions(self) -> list[dict]:
        # TODO: return [p._asdict() for p in mt5.positions_get()]
        return []

    def place_order(self, order: dict) -> dict:
        # TODO: build mt5.order_send request from `order`
        return {"status": "stub", "order": order}


class MT4Connector:
    """Live MT4 bridge over an EA — stubbed."""

    def __init__(self, terminal_path: str) -> None:
        self.terminal_path = terminal_path
        self.connected = False

    def connect(self) -> bool:
        # TODO: open file/socket channel to the EA bridge running in this terminal
        self.connected = True
        return True

    def positions(self) -> list[dict]:
        return []

    def place_order(self, order: dict) -> dict:
        return {"status": "stub", "order": order}


def make_connector(account: Account):
    return (MT5Connector if account.platform == Platform.MT5 else MT4Connector)(
        account.terminal_path
    )
