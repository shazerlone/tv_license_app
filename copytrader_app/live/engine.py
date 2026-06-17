"""The copy engine.

Polls each master account, detects newly opened and newly closed positions,
and replicates them to every enabled slave using the per-slave lot rules and
symbol mapping. Platform-agnostic: it talks to ``BrokerClient`` instances
produced by a factory, so the same logic drives MT5, MT4 or the fake client.

Safety: when ``state.dry_run`` is True the engine reads live positions but
NEVER sends orders — it only logs what it *would* do.
"""
from __future__ import annotations

import threading
from datetime import datetime

from ..models import TradeEvent
from .clients import BrokerClient
from .sizing import compute_slave_volume
from .types import OrderRequest


class CopyEngine:
    def __init__(self, state, client_factory):
        self.state = state
        self.client_factory = client_factory          # (Account) -> BrokerClient
        self.clients: dict[str, BrokerClient] = {}
        # (master_login, master_ticket) -> {slave_login: slave_ticket}
        self.mapping: dict[tuple[str, int], dict[str, int]] = {}
        self.known: dict[str, set[int]] = {}          # master_login -> seen tickets
        self.initialized: set[str] = set()            # masters we've baselined
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()

    # ------------------------------------------------------------------ #
    # lifecycle
    # ------------------------------------------------------------------ #
    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self.state.copying = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self.state.copying = False

    def is_running(self) -> bool:
        return bool(self._thread and self._thread.is_alive())

    def _run(self) -> None:
        mode = "DRY-RUN" if self.state.dry_run else "LIVE"
        self.state.log(f"Copy engine started ({mode}, poll {self.state.poll_seconds}s)")
        while not self._stop.is_set():
            try:
                self.run_cycle()
            except Exception as exc:                    # never let the loop die
                self.state.log(f"Engine error: {exc}")
            self._stop.wait(self.state.poll_seconds)
        for client in self.clients.values():
            try:
                client.disconnect()
            except Exception:
                pass
        self.clients.clear()
        self.state.log("Copy engine stopped")

    # ------------------------------------------------------------------ #
    # core cycle
    # ------------------------------------------------------------------ #
    def _client(self, account) -> BrokerClient:
        client = self.clients.get(account.login)
        if client is None:
            client = self.client_factory(account)
            ok = client.connect()
            account.connected = bool(ok)
            self.clients[account.login] = client
            self.state.log(
                f"{'Connected to' if ok else 'FAILED to connect'} "
                f"{account.platform.value} account {account.login} "
                f"({account.broker})"
            )
        return client

    def run_cycle(self) -> None:
        for group in self.state.groups:
            if group.enabled:
                self.sync_group(group)

    def sync_group(self, group) -> None:
        master = self.state.account(group.master_login)
        if not master:
            return
        mclient = self._client(master)
        if not mclient.is_connected():
            return

        positions = {p.ticket: p for p in mclient.positions()}
        current = set(positions)
        seen = self.known.setdefault(master.login, set())

        info = mclient.account_info()
        master.balance, master.equity = info.balance, info.equity

        if master.login not in self.initialized:
            # first sync: baseline the master's current book so we don't
            # blindly copy positions that were already open before we started.
            self.known[master.login] = current
            self.initialized.add(master.login)
            if current:
                self.state.log(
                    f"Master {master.login}: {len(current)} existing "
                    f"position(s) adopted (not copied)"
                )
            return

        for ticket in current - seen:
            self.on_master_open(group, master, positions[ticket])
        for ticket in seen - current:
            self.on_master_close(master, ticket)
        self.known[master.login] = current

    # ------------------------------------------------------------------ #
    # open / close replication
    # ------------------------------------------------------------------ #
    def on_master_open(self, group, master, pos) -> None:
        for sc in group.slaves:
            if not sc.enabled:
                continue
            slave = self.state.account(sc.account_login)
            if slave:
                self.replicate_open(master, slave, sc, pos)

    def replicate_open(self, master, slave, sc, pos) -> None:
        symbol, _kind = self.state.resolve_for_slave(pos.symbol, slave.login)
        if not symbol:
            self._record(master, slave, pos, 0.0, pos.side.value, "Skipped (unmapped)")
            return

        sclient = self._client(slave)
        if not sclient.is_connected():
            self._record(master, slave, pos, 0.0, pos.side.value, "Skipped (offline)")
            return

        sinfo = sclient.account_info()
        volume = compute_slave_volume(
            lot_mode=sc.lot_mode, lot_value=sc.lot_value,
            master_volume=pos.volume,
            master_balance=master.balance, slave_balance=sinfo.balance,
            master_equity=master.equity, slave_equity=sinfo.equity,
            max_lot=sc.max_lot, volume_step=sclient.volume_step(symbol),
        )
        side = pos.side.opposite if sc.reverse else pos.side

        if self.state.dry_run:
            self._record(master, slave, pos, volume, side.value, "DRY-RUN open")
            return

        req = OrderRequest(
            symbol=symbol, side=side, volume=volume,
            sl=pos.sl if sc.copy_sl_tp else 0.0,
            tp=pos.tp if sc.copy_sl_tp else 0.0,
            comment=f"copy:{master.login}:{pos.ticket}",
        )
        res = sclient.open_market(req)
        if res.ok:
            self.mapping.setdefault((master.login, pos.ticket), {})[slave.login] = res.ticket
            self._record(master, slave, pos, volume, side.value, "Copied")
        else:
            self._record(master, slave, pos, volume, side.value, f"Failed: {res.error}")

    def on_master_close(self, master, master_ticket) -> None:
        slave_map = self.mapping.pop((master.login, master_ticket), {})
        for slave_login, slave_ticket in slave_map.items():
            slave = self.state.account(slave_login)
            if not slave:
                continue
            if self.state.dry_run:
                self.state.log(
                    f"DRY-RUN close: slave {slave_login} ticket #{slave_ticket}"
                )
                continue
            res = self._client(slave).close(slave_ticket)
            self.state.log(
                f"Close slave {slave_login} #{slave_ticket}: "
                f"{'ok' if res.ok else res.error}"
            )

    # ------------------------------------------------------------------ #
    def _record(self, master, slave, pos, slave_vol, side, status) -> None:
        self.state.events.append(TradeEvent(
            time=datetime.now(),
            master_login=master.login, slave_login=slave.login,
            symbol=pos.symbol, side=side,
            master_lots=pos.volume, slave_lots=slave_vol, status=status,
        ))
        self.state.events = self.state.events[-200:]
        self.state.log(
            f"{status}: {master.login} {pos.symbol} {side} {pos.volume} "
            f"-> {slave.login} {slave_vol}"
        )
