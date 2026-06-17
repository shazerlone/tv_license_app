"""Core data models and in-memory application state.

This is the prototype data layer. It holds everything the UI needs and is
seeded with realistic stub data so the interface can be demoed without any
live MetaTrader connection. When the real connectors are wired in
(see ``connectors.py``), they populate / mutate these same objects, so the
UI does not need to change.
"""
from __future__ import annotations

import itertools
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class Platform(str, Enum):
    MT4 = "MT4"
    MT5 = "MT5"


class Role(str, Enum):
    UNASSIGNED = "Unassigned"
    MASTER = "Master"
    SLAVE = "Slave"


class LotMode(str, Enum):
    """How a slave sizes its copied trade relative to the master."""
    MULTIPLIER = "Multiplier"          # slave_lots = master_lots * value
    FIXED = "Fixed lot"                # slave_lots = value
    BALANCE_RATIO = "Balance ratio"    # scale by slave_balance / master_balance
    EQUITY_RATIO = "Equity ratio"      # scale by slave_equity / master_equity


@dataclass
class Account:
    """A single trading account discovered inside a running terminal."""
    login: str
    name: str
    broker: str
    server: str
    platform: Platform
    balance: float
    equity: float
    currency: str = "USD"
    terminal_path: str = ""
    connected: bool = True
    role: Role = Role.UNASSIGNED

    @property
    def display(self) -> str:
        return f"{self.login} — {self.name} ({self.platform.value} · {self.broker})"


@dataclass
class SlaveConfig:
    """Per-slave copy settings under a given master."""
    account_login: str
    enabled: bool = True
    lot_mode: LotMode = LotMode.MULTIPLIER
    lot_value: float = 1.0
    reverse: bool = False            # copy buy as sell, etc.
    max_lot: float = 0.0             # 0 = no cap
    copy_sl_tp: bool = True


@dataclass
class MasterGroup:
    """One master account fanning out to many slave accounts."""
    master_login: str
    slaves: list[SlaveConfig] = field(default_factory=list)
    enabled: bool = True

    def slave(self, login: str) -> Optional[SlaveConfig]:
        return next((s for s in self.slaves if s.account_login == login), None)


@dataclass
class SymbolMap:
    """Translate a symbol name from master to a slave broker.

    Example: master trades ``EURUSD`` but the slave broker lists it as
    ``EURUSD.m`` — so master ``EURUSD`` maps to slave ``EURUSD.m``.
    A prefix/suffix rule can cover many symbols at once.
    """
    master_symbol: str
    slave_symbol: str
    enabled: bool = True


@dataclass
class TradeEvent:
    """A copied trade shown on the dashboard / logs (stubbed for now)."""
    time: datetime
    master_login: str
    slave_login: str
    symbol: str
    side: str          # BUY / SELL
    master_lots: float
    slave_lots: float
    status: str        # Copied / Failed / Skipped


class AppState:
    """Single source of truth for the whole UI."""

    def __init__(self) -> None:
        self.accounts: list[Account] = []
        self.groups: list[MasterGroup] = []
        self.symbol_maps: list[SymbolMap] = []
        self.events: list[TradeEvent] = []
        self.logs: list[str] = []
        self.copying: bool = False
        # default global suffix rule applied when no explicit map matches
        self.global_slave_suffix: str = ""
        self.global_slave_prefix: str = ""
        self._seed_stub_data()

    # ------------------------------------------------------------------ #
    # logging
    # ------------------------------------------------------------------ #
    def log(self, message: str) -> None:
        stamp = datetime.now().strftime("%H:%M:%S")
        self.logs.append(f"[{stamp}] {message}")
        self.logs = self.logs[-500:]

    # ------------------------------------------------------------------ #
    # account / role helpers
    # ------------------------------------------------------------------ #
    def account(self, login: str) -> Optional[Account]:
        return next((a for a in self.accounts if a.login == login), None)

    def masters(self) -> list[Account]:
        return [a for a in self.accounts if a.role == Role.MASTER]

    def slaves(self) -> list[Account]:
        return [a for a in self.accounts if a.role == Role.SLAVE]

    def unassigned(self) -> list[Account]:
        return [a for a in self.accounts if a.role == Role.UNASSIGNED]

    def group_for(self, master_login: str) -> Optional[MasterGroup]:
        return next((g for g in self.groups if g.master_login == master_login), None)

    def set_master(self, login: str) -> None:
        acc = self.account(login)
        if not acc:
            return
        acc.role = Role.MASTER
        if not self.group_for(login):
            self.groups.append(MasterGroup(master_login=login))
        self.log(f"Account {login} set as MASTER")

    def add_slave(self, master_login: str, slave_login: str) -> None:
        group = self.group_for(master_login)
        acc = self.account(slave_login)
        if not group or not acc or slave_login == master_login:
            return
        acc.role = Role.SLAVE
        if not group.slave(slave_login):
            group.slaves.append(SlaveConfig(account_login=slave_login))
        self.log(f"Slave {slave_login} attached to master {master_login}")

    def remove_slave(self, master_login: str, slave_login: str) -> None:
        group = self.group_for(master_login)
        if not group:
            return
        group.slaves = [s for s in group.slaves if s.account_login != slave_login]
        acc = self.account(slave_login)
        if acc:
            acc.role = Role.UNASSIGNED
        self.log(f"Slave {slave_login} detached from master {master_login}")

    # ------------------------------------------------------------------ #
    # symbol mapping
    # ------------------------------------------------------------------ #
    def resolve_symbol(self, master_symbol: str) -> str:
        for m in self.symbol_maps:
            if m.enabled and m.master_symbol.upper() == master_symbol.upper():
                return m.slave_symbol
        return f"{self.global_slave_prefix}{master_symbol}{self.global_slave_suffix}"

    # ------------------------------------------------------------------ #
    # stub seed data (replace with live scanner output)
    # ------------------------------------------------------------------ #
    def _seed_stub_data(self) -> None:
        self.accounts = [
            Account("8125660", "Majid Lone", "Exness", "Exness-MT5Real8",
                    Platform.MT5, 25430.55, 25890.12, terminal_path=r"C:\Program Files\MetaTrader 5"),
            Account("5510233", "Strategy A", "IC Markets", "ICMarketsSC-MT5",
                    Platform.MT5, 102300.00, 101980.40, terminal_path=r"C:\Program Files\ICMarkets MT5"),
            Account("400917", "Client - Khan", "XM", "XMGlobal-Real 12",
                    Platform.MT4, 5120.20, 5044.90, terminal_path=r"C:\Program Files\XM MT4"),
            Account("733019", "Client - Sara", "FBS", "FBS-Real-15",
                    Platform.MT4, 1990.00, 2012.75, terminal_path=r"C:\Program Files\FBS MT4"),
            Account("9920481", "Client - Omar", "Pepperstone", "Pepperstone-MT5",
                    Platform.MT5, 7800.00, 7795.10, terminal_path=r"C:\Program Files\Pepperstone MT5"),
        ]
        # a default master group: first MT5 account masters two slaves
        self.set_master("5510233")
        self.add_slave("5510233", "8125660")
        self.add_slave("5510233", "9920481")
        # tune one slave to show non-default settings
        grp = self.group_for("5510233")
        if grp and grp.slave("8125660"):
            grp.slave("8125660").lot_mode = LotMode.BALANCE_RATIO
            grp.slave("8125660").lot_value = 1.0

        self.symbol_maps = [
            SymbolMap("EURUSD", "EURUSD.m"),
            SymbolMap("XAUUSD", "GOLD"),
            SymbolMap("US30", "US30.cash"),
        ]
        self.global_slave_suffix = ""

        now = datetime.now()
        self.events = [
            TradeEvent(now, "5510233", "8125660", "EURUSD", "BUY", 1.00, 0.25, "Copied"),
            TradeEvent(now, "5510233", "9920481", "EURUSD", "BUY", 1.00, 0.08, "Copied"),
            TradeEvent(now, "5510233", "8125660", "XAUUSD", "SELL", 0.50, 0.12, "Copied"),
            TradeEvent(now, "5510233", "9920481", "US30", "BUY", 2.00, 0.15, "Skipped"),
        ]
        self.log("Application started")
        self.log("Loaded 5 stub accounts (2 MT4, 3 MT5)")


# id generator kept around for future use when creating ad-hoc rows
_counter = itertools.count(1)


def next_id() -> int:
    return next(_counter)
