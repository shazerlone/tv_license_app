"""Tests for the copy engine's brain — runs without any MetaTrader.

Verifies trade detection, lot sizing, symbol resolution, reverse and closes
using FakeClient brokers, plus the pure sizing maths.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

from copytrader_app.live.clients import FakeClient
from copytrader_app.live.engine import CopyEngine
from copytrader_app.live.sizing import compute_slave_volume
from copytrader_app.live.types import OrderRequest, Side
from copytrader_app.models import (Account, AppState, LotMode, MasterGroup,
                                   Platform, Role, SlaveConfig)


def fresh_state():
    """A clean state with one master + one slave, no stub seed groups."""
    s = AppState()
    s.accounts = [
        Account("M", "Master", "BrokerA", "SrvA", Platform.MT5, 10000.0, 10000.0,
                role=Role.MASTER, symbols=["EURUSD", "XAUUSD"]),
        Account("S", "Slave", "BrokerB", "SrvB", Platform.MT5, 5000.0, 5000.0,
                role=Role.SLAVE, symbols=["EURUSDz", "XAUUSDz"]),
    ]
    s.groups = [MasterGroup("M", slaves=[SlaveConfig("S")])]
    s.symbol_maps = []
    s.events = []
    s.dry_run = False
    return s


class SizingTests(unittest.TestCase):
    def test_multiplier(self):
        v = compute_slave_volume(lot_mode=LotMode.MULTIPLIER, lot_value=2.0,
                                 master_volume=1.0)
        self.assertEqual(v, 2.0)

    def test_fixed(self):
        v = compute_slave_volume(lot_mode=LotMode.FIXED, lot_value=0.3,
                                 master_volume=5.0)
        self.assertEqual(v, 0.3)

    def test_balance_ratio(self):
        v = compute_slave_volume(lot_mode=LotMode.BALANCE_RATIO, lot_value=1.0,
                                 master_volume=1.0, master_balance=10000,
                                 slave_balance=5000)
        self.assertEqual(v, 0.5)

    def test_step_and_min(self):
        v = compute_slave_volume(lot_mode=LotMode.MULTIPLIER, lot_value=0.333,
                                 master_volume=1.0, volume_step=0.01)
        self.assertEqual(v, 0.33)
        v0 = compute_slave_volume(lot_mode=LotMode.MULTIPLIER, lot_value=0.0001,
                                  master_volume=1.0, min_lot=0.01)
        self.assertEqual(v0, 0.01)

    def test_max_cap(self):
        v = compute_slave_volume(lot_mode=LotMode.MULTIPLIER, lot_value=100,
                                 master_volume=1.0, max_lot=5.0)
        self.assertEqual(v, 5.0)


class EngineTests(unittest.TestCase):
    def setUp(self):
        self.state = fresh_state()
        self.clients = {a.login: FakeClient(a) for a in self.state.accounts}
        self.engine = CopyEngine(self.state, lambda a: self.clients[a.login])
        for c in self.clients.values():
            c.connect()

    def m(self):
        return self.clients["M"]

    def s(self):
        return self.clients["S"]

    def test_open_is_copied_with_balance_ratio_and_symbol_map(self):
        self.state.groups[0].slaves[0].lot_mode = LotMode.BALANCE_RATIO
        self.engine.run_cycle()                      # baseline (empty)
        self.m().open_market(OrderRequest("EURUSD", Side.BUY, 1.0))
        self.engine.run_cycle()                      # detect + copy
        sp = self.s().positions()
        self.assertEqual(len(sp), 1)
        self.assertEqual(sp[0].symbol, "EURUSDz")    # auto-mapped suffix
        self.assertEqual(sp[0].side, Side.BUY)
        self.assertEqual(sp[0].volume, 0.5)          # 1.0 * 5000/10000

    def test_reverse(self):
        self.state.groups[0].slaves[0].reverse = True
        self.engine.run_cycle()
        self.m().open_market(OrderRequest("EURUSD", Side.BUY, 1.0))
        self.engine.run_cycle()
        self.assertEqual(self.s().positions()[0].side, Side.SELL)

    def test_close_propagates(self):
        self.engine.run_cycle()
        r = self.m().open_market(OrderRequest("EURUSD", Side.BUY, 1.0))
        self.engine.run_cycle()
        self.assertEqual(len(self.s().positions()), 1)
        self.m().close(r.ticket)                     # master closes
        self.engine.run_cycle()                      # should close the slave
        self.assertEqual(len(self.s().positions()), 0)

    def test_unmapped_is_skipped(self):
        self.state.accounts[1].symbols = ["EURUSDz"]  # no gold on slave
        self.engine.run_cycle()
        self.m().open_market(OrderRequest("XAUUSD", Side.BUY, 1.0))
        self.engine.run_cycle()
        self.assertEqual(len(self.s().positions()), 0)
        self.assertTrue(any("Skipped" in e.status for e in self.state.events))

    def test_dry_run_sends_nothing(self):
        self.state.dry_run = True
        self.engine.run_cycle()
        self.m().open_market(OrderRequest("EURUSD", Side.BUY, 1.0))
        self.engine.run_cycle()
        self.assertEqual(len(self.s().positions()), 0)
        self.assertTrue(any("DRY-RUN" in e.status for e in self.state.events))

    def test_preexisting_master_trades_not_copied(self):
        self.m().open_market(OrderRequest("EURUSD", Side.BUY, 1.0))  # before start
        self.engine.run_cycle()                      # baseline adopts it
        self.assertEqual(len(self.s().positions()), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
