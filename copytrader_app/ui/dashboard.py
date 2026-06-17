"""Dashboard page: live status, start/stop copying, recent copied trades."""
from __future__ import annotations

import customtkinter as ctk

from . import widgets as w


class DashboardPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        w.title(self, "Dashboard").pack(anchor="w", padx=24, pady=(20, 0))
        w.subtitle(self, "Live copy-trading overview").pack(anchor="w", padx=24)

        # control bar
        bar = ctk.CTkFrame(self, fg_color="transparent")
        bar.pack(fill="x", padx=24, pady=14)
        self.status_dot = ctk.CTkLabel(bar, text="● STOPPED", font=(w.FONT, 14, "bold"),
                                       text_color=w.RED)
        self.status_dot.pack(side="left")
        self.toggle_btn = w.primary_button(bar, "Start copying", self.toggle)
        self.toggle_btn.pack(side="right")

        # stat cards
        stats = ctk.CTkFrame(self, fg_color="transparent")
        stats.pack(fill="x", padx=24)
        for i in range(4):
            stats.grid_columnconfigure(i, weight=1)
        self.card_master = w.stat_card(stats, "Active masters", "0", w.ACCENT)
        self.card_slaves = w.stat_card(stats, "Connected slaves", "0", w.GREEN)
        self.card_maps = w.stat_card(stats, "Symbol maps", "0")
        self.card_copied = w.stat_card(stats, "Trades copied", "0", w.AMBER)
        for i, c in enumerate(
            (self.card_master, self.card_slaves, self.card_maps, self.card_copied)
        ):
            c.grid(row=0, column=i, sticky="ew", padx=(0 if i == 0 else 8, 0))

        # recent trades table
        tcard = w.card(self)
        tcard.pack(fill="both", expand=True, padx=24, pady=18)
        ctk.CTkLabel(tcard, text="Recent copied trades", font=(w.FONT, 15, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=16, pady=(14, 6))
        self.tree = w.make_table(tcard, [
            ("Time", 90), ("Master", 90), ("Slave", 90), ("Symbol", 90),
            ("Side", 70), ("Master lots", 100), ("Slave lots", 100), ("Status", 90),
        ])
        self.tree.pack(fill="both", expand=True, padx=16, pady=(0, 16))

        self.refresh()

    def toggle(self):
        self.state.copying = not self.state.copying
        self.state.log(f"Copy engine {'STARTED' if self.state.copying else 'STOPPED'}")
        self.refresh()

    def refresh(self):
        s = self.state
        self.card_master.value_label.configure(text=str(len(s.masters())))
        self.card_slaves.value_label.configure(text=str(len(s.slaves())))
        self.card_maps.value_label.configure(
            text=str(len([m for m in s.symbol_maps if m.enabled]))
        )
        self.card_copied.value_label.configure(
            text=str(len([e for e in s.events if e.status == "Copied"]))
        )
        if s.copying:
            self.status_dot.configure(text="● RUNNING", text_color=w.GREEN)
            self.toggle_btn.configure(text="Stop copying", fg_color=w.RED,
                                      hover_color="#c0392b")
        else:
            self.status_dot.configure(text="● STOPPED", text_color=w.RED)
            self.toggle_btn.configure(text="Start copying", fg_color=w.ACCENT,
                                      hover_color=w.ACCENT_HOVER)
        self.tree.delete(*self.tree.get_children())
        for e in reversed(s.events):
            self.tree.insert("", "end", values=(
                e.time.strftime("%H:%M:%S"), e.master_login, e.slave_login,
                e.symbol, e.side, f"{e.master_lots:.2f}", f"{e.slave_lots:.2f}",
                e.status,
            ))
