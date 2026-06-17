"""Live MetaTrader 5 client (official ``MetaTrader5`` package).

Design notes
------------
The ``MetaTrader5`` package is a *process-wide singleton*: a single Python
process can only be attached to one terminal at a time. The copy engine runs
its cycle on one thread, so we serialise access with a global lock and switch
the attachment to whichever terminal the current operation needs ("separate
terminal per account" setup — each terminal is already logged in).

This works well for a handful of accounts on a 1-2s poll. To scale to many
accounts with lower latency, the upgrade path is one worker *process* per
terminal (see README). The ``BrokerClient`` interface stays the same.

Importing this module never fails: if ``MetaTrader5`` isn't installed (e.g.
on non-Windows dev machines) ``HAVE_MT5`` is False and clients report
disconnected instead of raising.
"""
from __future__ import annotations

import threading

from .clients import BrokerClient
from .types import AccountInfo, CloseResult, OpenResult, OrderRequest, Position, Side

try:  # only importable on Windows with the package installed
    import MetaTrader5 as mt5  # type: ignore
    HAVE_MT5 = True
except Exception:  # pragma: no cover - depends on host
    mt5 = None
    HAVE_MT5 = False

_LOCK = threading.RLock()
_ACTIVE = {"key": None}  # which terminal the singleton is currently attached to


class Mt5Client(BrokerClient):
    def __init__(self, account):
        self.account = account
        self.path = account.terminal_path or ""
        self.login = getattr(account, "login", "")
        self.password = getattr(account, "password", "")
        self.server = getattr(account, "server", "")
        self._ok = False

    # -- attachment --------------------------------------------------------- #
    @property
    def _key(self) -> str:
        return self.path or str(self.login)

    def _activate(self) -> bool:
        """Make the MT5 singleton point at this account's terminal."""
        if _ACTIVE["key"] == self._key and mt5.terminal_info() is not None:
            return True
        mt5.shutdown()
        kwargs = {}
        if self.path:
            kwargs["path"] = self.path
        if not mt5.initialize(**kwargs):
            _ACTIVE["key"] = None
            return False
        # if credentials are supplied, log in (otherwise use the terminal's
        # already-logged-in account)
        if self.password and self.server:
            try:
                if not mt5.login(int(self.login), password=self.password,
                                 server=self.server):
                    _ACTIVE["key"] = None
                    return False
            except (ValueError, TypeError):
                _ACTIVE["key"] = None
                return False
        _ACTIVE["key"] = self._key
        return True

    # -- BrokerClient ------------------------------------------------------- #
    def connect(self) -> bool:
        if not HAVE_MT5:
            return False
        with _LOCK:
            self._ok = self._activate()
            return self._ok

    def disconnect(self) -> None:
        # leave the singleton; engine shutdown calls mt5.shutdown() once
        self._ok = False

    def is_connected(self) -> bool:
        return self._ok and HAVE_MT5

    def account_info(self) -> AccountInfo:
        with _LOCK:
            if not self._activate():
                return AccountInfo(login=str(self.login), balance=0.0, equity=0.0)
            info = mt5.account_info()
            if info is None:
                return AccountInfo(login=str(self.login), balance=0.0, equity=0.0)
            return AccountInfo(
                login=str(info.login), balance=info.balance, equity=info.equity,
                currency=info.currency, leverage=info.leverage,
            )

    def positions(self) -> list[Position]:
        with _LOCK:
            if not self._activate():
                return []
            raw = mt5.positions_get() or []
            out = []
            for p in raw:
                side = Side.BUY if p.type == mt5.POSITION_TYPE_BUY else Side.SELL
                out.append(Position(
                    ticket=int(p.ticket), symbol=p.symbol, side=side,
                    volume=float(p.volume), price_open=float(p.price_open),
                    sl=float(p.sl), tp=float(p.tp), comment=p.comment,
                ))
            return out

    def symbols(self) -> list[str]:
        with _LOCK:
            if not self._activate():
                return []
            return [s.name for s in (mt5.symbols_get() or [])]

    def volume_step(self, symbol: str) -> float:
        with _LOCK:
            if not self._activate():
                return 0.01
            info = mt5.symbol_info(symbol)
            return float(info.volume_step) if info else 0.01

    def open_market(self, req: OrderRequest) -> OpenResult:
        with _LOCK:
            if not self._activate():
                return OpenResult(ok=False, error="not connected")
            if not mt5.symbol_select(req.symbol, True):
                return OpenResult(ok=False, error=f"symbol {req.symbol} unavailable")
            tick = mt5.symbol_info_tick(req.symbol)
            if tick is None:
                return OpenResult(ok=False, error="no price")
            is_buy = req.side is Side.BUY
            price = tick.ask if is_buy else tick.bid
            order = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": req.symbol,
                "volume": float(req.volume),
                "type": mt5.ORDER_TYPE_BUY if is_buy else mt5.ORDER_TYPE_SELL,
                "price": price,
                "deviation": 30,
                "magic": 770077,
                "comment": req.comment[:31],
                "type_time": mt5.ORDER_TIME_GTC,
            }
            if req.sl:
                order["sl"] = req.sl
            if req.tp:
                order["tp"] = req.tp
            return self._send_with_filling(order)

    def close(self, ticket: int, volume: float = 0.0) -> CloseResult:
        with _LOCK:
            if not self._activate():
                return CloseResult(ok=False, error="not connected")
            positions = mt5.positions_get(ticket=ticket) or []
            if not positions:
                return CloseResult(ok=False, error="position not found")
            p = positions[0]
            is_buy = p.type == mt5.POSITION_TYPE_BUY
            tick = mt5.symbol_info_tick(p.symbol)
            if tick is None:
                return CloseResult(ok=False, error="no price")
            price = tick.bid if is_buy else tick.ask
            order = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": p.symbol,
                "volume": float(volume or p.volume),
                "type": mt5.ORDER_TYPE_SELL if is_buy else mt5.ORDER_TYPE_BUY,
                "position": int(ticket),
                "price": price,
                "deviation": 30,
                "magic": 770077,
                "comment": "copy-close",
                "type_time": mt5.ORDER_TIME_GTC,
            }
            res = self._send_with_filling(order)
            return CloseResult(ok=res.ok, error=res.error)

    # -- helpers ------------------------------------------------------------ #
    def _send_with_filling(self, order: dict) -> OpenResult:
        """Try the broker's accepted filling modes (varies by broker)."""
        for filling in (mt5.ORDER_FILLING_IOC, mt5.ORDER_FILLING_FOK,
                        mt5.ORDER_FILLING_RETURN):
            order["type_filling"] = filling
            result = mt5.order_send(order)
            if result is None:
                continue
            if result.retcode == mt5.TRADE_RETCODE_DONE:
                return OpenResult(ok=True, ticket=int(result.order))
            # if it's specifically an unsupported-filling error, try the next
            if result.retcode != mt5.TRADE_RETCODE_INVALID_FILL:
                return OpenResult(ok=False,
                                  error=f"retcode {result.retcode}: {result.comment}")
        return OpenResult(ok=False, error="all filling modes rejected")
