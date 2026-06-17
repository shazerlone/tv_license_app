"""Shared types for the live trading layer.

These are the *broker-neutral* shapes the copy engine works with. The MT5 and
MT4 clients translate their platform's native data into these.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class Side(str, Enum):
    BUY = "BUY"
    SELL = "SELL"

    @property
    def opposite(self) -> "Side":
        return Side.SELL if self is Side.BUY else Side.BUY


@dataclass(frozen=True)
class AccountInfo:
    login: str
    balance: float
    equity: float
    currency: str = "USD"
    leverage: int = 0


@dataclass(frozen=True)
class Position:
    """One open position on an account."""
    ticket: int
    symbol: str
    side: Side
    volume: float
    price_open: float = 0.0
    sl: float = 0.0
    tp: float = 0.0
    comment: str = ""


@dataclass
class OrderRequest:
    symbol: str
    side: Side
    volume: float
    sl: float = 0.0
    tp: float = 0.0
    comment: str = "copytrader"


@dataclass
class OpenResult:
    ok: bool
    ticket: int = 0
    error: str = ""


@dataclass
class CloseResult:
    ok: bool
    error: str = ""
