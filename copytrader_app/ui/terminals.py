"""Terminals page: scan for running MT4/MT5 terminals & their accounts."""
from __future__ import annotations

import customtkinter as ctk

from .. import connectors
from ..models import Role
from . import widgets as w


class TerminalsPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=24, pady=(20, 0))
        box = ctk.CTkFrame(head, fg_color="transparent")
        box.pack(side="left")
        w.title(box, "Terminals & Accounts").pack(anchor="w")
        w.subtitle(box, "Detected running MetaTrader terminals on this machine").pack(anchor="w")
        w.primary_button(head, "⟳  Scan terminals", self.scan).pack(side="right")

        tcard = w.card(self)
        tcard.pack(fill="both", expand=True, padx=24, pady=18)
        self.tree = w.make_table(tcard, [
            ("Login", 90), ("Name", 140), ("Platform", 80), ("Broker", 120),
            ("Server", 150), ("Balance", 100), ("Equity", 100),
            ("Role", 90), ("Status", 90),
        ])
        self.tree.tag_configure("master", foreground=w.ACCENT)
        self.tree.tag_configure("slave", foreground=w.GREEN)
        self.tree.pack(fill="both", expand=True, padx=16, pady=16)

        self.refresh()

    def scan(self):
        found = connectors.scan_terminals()
        known = {a.login for a in self.state.accounts}
        added = 0
        for acc in found:
            if acc.login not in known:
                self.state.accounts.append(acc)
                added += 1
        self.state.log(f"Scan complete — {len(found)} terminal(s) detected, {added} new")
        self.refresh()
        self.app.refresh_all()

    def refresh(self):
        self.tree.delete(*self.tree.get_children())
        for a in self.state.accounts:
            tag = ("master",) if a.role == Role.MASTER else (
                ("slave",) if a.role == Role.SLAVE else ()
            )
            self.tree.insert("", "end", tags=tag, values=(
                a.login, a.name, a.platform.value, a.broker, a.server,
                f"{a.balance:,.2f}", f"{a.equity:,.2f}", a.role.value,
                "Connected" if a.connected else "Offline",
            ))
