"""Live trading layer: brokers clients + copy engine.

The UI talks only to :class:`engine.CopyEngine`. Which concrete broker client
gets used is decided by :func:`make_client`, based on the app's live/demo mode
and what's installed on the host.
"""
from __future__ import annotations

from ..models import Platform
from .clients import FakeClient
from .engine import CopyEngine

__all__ = ["CopyEngine", "make_client", "client_factory_for"]


def make_client(account, state):
    """Return the right BrokerClient for an account given the app mode.

    * Demo mode (``state.live_mode`` False) -> FakeClient (works everywhere).
      Masters get simulated trades so the dashboard shows live activity.
    * Live mode -> the real MT5 / MT4 client. If the platform isn't available
      on this host (e.g. MetaTrader5 not installed), falls back to FakeClient
      so nothing crashes — the engine just reports it as disconnected.
    """
    from ..models import Role

    if not state.live_mode:
        return FakeClient(account, simulate_master=(account.role == Role.MASTER))

    if account.platform == Platform.MT5:
        from .mt5_client import HAVE_MT5, Mt5Client
        if HAVE_MT5:
            return Mt5Client(account)
        state.log(f"MetaTrader5 package not available — {account.login} stays offline")
        return FakeClient(account)

    # MT4
    from .mt4_client import Mt4Client
    return Mt4Client(account)


def client_factory_for(state):
    """Bind the app state into a single-argument factory the engine expects."""
    return lambda account: make_client(account, state)
