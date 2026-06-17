"""Terminals page: scan for running MT4/MT5 terminals & their accounts."""
from __future__ import annotations

import customtkinter as ctk

from .. import connectors
from ..models import Account, Platform, Role
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
        w.ghost_button(head, "＋ Add account", self.open_add_dialog).pack(side="right", padx=10)

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

    # ------------------------------------------------------------------ #
    # add-account dialog (for live connection details)
    # ------------------------------------------------------------------ #
    def open_add_dialog(self):
        dlg = ctk.CTkToplevel(self)
        dlg.title("Add account")
        dlg.geometry("460x520")
        dlg.configure(fg_color=w.BG)
        dlg.grab_set()

        ctk.CTkLabel(dlg, text="Add account", font=(w.FONT, 18, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=20, pady=(18, 2))
        ctk.CTkLabel(dlg, text="MT5: terminal path (+ optional login/password/server).\n"
                               "MT4: also set the MQL4/Files folder for the EA bridge.",
                     text_color=w.MUTED, font=(w.FONT, 11), justify="left").pack(
            anchor="w", padx=20)

        body = ctk.CTkFrame(dlg, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=20, pady=12)

        plat = ctk.CTkOptionMenu(body, values=[p.value for p in Platform],
                                 fg_color=w.CARD, button_color=w.ACCENT)
        fields = {}

        def row(label, key, placeholder=""):
            ctk.CTkLabel(body, text=label, text_color=w.MUTED,
                         font=(w.FONT, 12)).pack(anchor="w", pady=(8, 2))
            e = ctk.CTkEntry(body, placeholder_text=placeholder, width=420)
            e.pack(anchor="w")
            fields[key] = e

        ctk.CTkLabel(body, text="Platform", text_color=w.MUTED,
                     font=(w.FONT, 12)).pack(anchor="w", pady=(4, 2))
        plat.pack(anchor="w")
        row("Login", "login", "e.g. 5510233")
        row("Name", "name", "e.g. Client - Khan")
        row("Broker", "broker", "e.g. IC Markets")
        row("Server", "server", "e.g. ICMarketsSC-MT5")
        row("Terminal path", "terminal_path", r"C:\Program Files\...")
        row("Password (MT5, optional)", "password", "leave blank if terminal already logged in")
        row("MT4 Files folder", "mt4_files_path", r"...\MQL4\Files (MT4 only)")

        def save():
            login = fields["login"].get().strip()
            if not login:
                return
            acc = Account(
                login=login, name=fields["name"].get().strip() or login,
                broker=fields["broker"].get().strip(),
                server=fields["server"].get().strip(),
                platform=Platform(plat.get()), balance=0.0, equity=0.0,
                terminal_path=fields["terminal_path"].get().strip(),
                password=fields["password"].get().strip(),
                mt4_files_path=fields["mt4_files_path"].get().strip(),
                connected=False,
            )
            self.state.accounts = [a for a in self.state.accounts if a.login != login]
            self.state.accounts.append(acc)
            self.state.log(f"Account {login} ({acc.platform.value}) added")
            dlg.destroy()
            self.refresh()
            self.app.refresh_all()

        btns = ctk.CTkFrame(dlg, fg_color="transparent")
        btns.pack(fill="x", padx=20, pady=(0, 16))
        w.primary_button(btns, "Save account", save).pack(side="right")
        w.ghost_button(btns, "Cancel", dlg.destroy).pack(side="right", padx=10)

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
