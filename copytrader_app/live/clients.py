"""Broker client interface + a fake client for development/testing.

Every concrete connector (MT5, MT4) implements ``BrokerClient`` so the copy
engine never depends on a specific platform. ``FakeClient`` simulates an
account so the engine and UI can run on any OS (no MetaTrader required).
"""
from __future__ import annotations

import itertools
import random
from abc import ABC, abstractmethod

from .types import AccountInfo, CloseResult, OpenResult, OrderRequest, Position, Side


class BrokerClient(ABC):
    """Minimal surface the copy engine needs from any trading platform."""

    @abstractmethod
    def connect(self) -> bool: ...

    @abstractmethod
    def disconnect(self) -> None: ...

    @abstractmethod
    def is_connected(self) -> bool: ...

    @abstractmethod
    def account_info(self) -> AccountInfo: ...

    @abstractmethod
    def positions(self) -> list[Position]: ...

    @abstractmethod
    def symbols(self) -> list[str]: ...

    @abstractmethod
    def open_market(self, req: OrderRequest) -> OpenResult: ...

    @abstractmethod
    def close(self, ticket: int, volume: float = 0.0) -> CloseResult: ...

    def volume_step(self, symbol: str) -> float:  # overridable
        return 0.01


class FakeClient(BrokerClient):
    """In-memory simulated account.

    Masters can be made to randomly open/close trades so the engine and
    dashboard show live-looking activity without a broker. Slaves simply
    accept orders and track them.
    """

    _ticket_seq = itertools.count(1000)

    def __init__(self, account, *, simulate_master: bool = False):
        self.account = account
        self.simulate_master = simulate_master
        self._connected = False
        self._positions: dict[int, Position] = {}
        self._symbols = list(account.symbols) or ["EURUSD", "XAUUSD", "GBPUSD", "US30"]
        self._tick = 0

    def connect(self) -> bool:
        self._connected = True
        return True

    def disconnect(self) -> None:
        self._connected = False

    def is_connected(self) -> bool:
        return self._connected

    def account_info(self) -> AccountInfo:
        return AccountInfo(
            login=self.account.login,
            balance=self.account.balance,
            equity=self.account.equity,
            currency=self.account.currency,
        )

    def positions(self) -> list[Position]:
        if self.simulate_master:
            self._maybe_mutate()
        return list(self._positions.values())

    def symbols(self) -> list[str]:
        return list(self._symbols)

    def open_market(self, req: OrderRequest) -> OpenResult:
        ticket = next(self._ticket_seq)
        self._positions[ticket] = Position(
            ticket=ticket, symbol=req.symbol, side=req.side, volume=req.volume,
            sl=req.sl, tp=req.tp, comment=req.comment,
        )
        return OpenResult(ok=True, ticket=ticket)

    def close(self, ticket: int, volume: float = 0.0) -> CloseResult:
        if ticket in self._positions:
            del self._positions[ticket]
            return CloseResult(ok=True)
        return CloseResult(ok=False, error="position not found")

    # -- master simulation -------------------------------------------------- #
    def _maybe_mutate(self) -> None:
        self._tick += 1
        # roughly every few polls, open or close a random trade
        if self._tick % 3 != 0:
            return
        if self._positions and random.random() < 0.4:
            self.close(random.choice(list(self._positions)))
        elif len(self._positions) < 3:
            self.open_market(OrderRequest(
                symbol=random.choice(self._symbols),
                side=random.choice([Side.BUY, Side.SELL]),
                volume=round(random.choice([0.5, 1.0, 1.5, 2.0]), 2),
                comment="sim",
            ))
