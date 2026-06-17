"""Symbol Mapping page.

Symbols auto-map across brokers by matching the base instrument and ignoring
common suffixes/prefixes (XAUUSD -> XAUUSDz / XAUUSD.m / XAUUSD.r ...).
Anything that can't be matched automatically (e.g. master XAUUSD vs slave
GOLD_CASH) shows as **Unmapped** and needs a manual map.
"""
from __future__ import annotations

import customtkinter as ctk

from ..models import SymbolMap
from . import widgets as w


class MappingPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=28, pady=(22, 0))
        box = ctk.CTkFrame(head, fg_color="transparent")
        box.pack(side="left")
        w.title(box, "Symbol Mapping").pack(anchor="w")
        w.subtitle(box, "Auto-matches common broker suffixes · add manual maps for the rest").pack(anchor="w")
        w.primary_button(head, "⟲  Auto-map symbols", self.auto_map).pack(side="right")

        # legend
        legend = ctk.CTkFrame(self, fg_color="transparent")
        legend.pack(fill="x", padx=28, pady=(12, 0))
        w.pill(legend, "Auto", w.GREEN, w.GREEN_SOFT).pack(side="left", padx=(0, 6))
        ctk.CTkLabel(legend, text="matched by suffix/prefix", text_color=w.MUTED,
                     font=(w.FONT, 11)).pack(side="left", padx=(0, 16))
        w.pill(legend, "Manual", w.ACCENT, w.BLUE_SOFT).pack(side="left", padx=(0, 6))
        ctk.CTkLabel(legend, text="mapped by you", text_color=w.MUTED,
                     font=(w.FONT, 11)).pack(side="left", padx=(0, 16))
        w.pill(legend, "Unmapped", w.AMBER, w.AMBER_SOFT).pack(side="left", padx=(0, 6))
        ctk.CTkLabel(legend, text="needs a manual map", text_color=w.MUTED,
                     font=(w.FONT, 11)).pack(side="left")

        # results table
        tcard = w.card(self)
        tcard.pack(fill="both", expand=True, padx=28, pady=16)
        self.tree = w.make_table(tcard, [
            ("Slave account", 230), ("Master symbol", 140),
            ("Slave symbol", 180), ("Type", 120),
        ])
        self.tree.tag_configure("Auto", foreground=w.GREEN)
        self.tree.tag_configure("Manual", foreground=w.ACCENT)
        self.tree.tag_configure("Unmapped", foreground=w.AMBER)
        self.tree.pack(fill="both", expand=True, padx=16, pady=16)
        self.tree.bind("<<TreeviewSelect>>", self._prefill_from_selection)

        # manual mapping form
        form = w.card(self)
        form.pack(fill="x", padx=28, pady=(0, 18))
        ctk.CTkLabel(form, text="Add / update a manual map",
                     font=(w.FONT, 14, "bold"), text_color=w.TEXT).pack(
            anchor="w", padx=16, pady=(14, 8))
        row = ctk.CTkFrame(form, fg_color="transparent")
        row.pack(fill="x", padx=16, pady=(0, 16))

        ctk.CTkLabel(row, text="Slave", text_color=w.MUTED).pack(side="left", padx=(0, 6))
        self.slave_menu = ctk.CTkOptionMenu(
            row, values=["—"], width=240, fg_color=w.HOVER, text_color=w.TEXT,
            button_color=w.ACCENT, button_hover_color=w.ACCENT_HOVER,
        )
        self.slave_menu.pack(side="left", padx=(0, 14))

        self.m_in = ctk.CTkEntry(row, placeholder_text="Master symbol e.g. XAUUSD", width=200)
        self.m_in.pack(side="left")
        ctk.CTkLabel(row, text="→", font=(w.FONT, 18), text_color=w.MUTED).pack(side="left", padx=10)
        self.s_in = ctk.CTkEntry(row, placeholder_text="Slave symbol e.g. GOLD_CASH", width=200)
        self.s_in.pack(side="left")
        w.primary_button(row, "Save map", self.add_map).pack(side="left", padx=14)
        w.ghost_button(row, "Delete map", self.delete_map).pack(side="left")

        self.refresh()

    # ------------------------------------------------------------------ #
    def _slave_options(self):
        return {s.display: s.login for s in self.state.slaves()}

    def auto_map(self):
        auto, unmapped = self.state.auto_map_scan()
        self.refresh()
        self.app.refresh_all()

    def _prefill_from_selection(self, _event=None):
        sel = self.tree.selection()
        if not sel:
            return
        vals = self.tree.item(sel[0], "values")
        if not vals:
            return
        slave_disp, master_sym, slave_sym, _kind = vals
        # match the slave account display in the dropdown
        for disp in self._slave_options():
            if disp.startswith(slave_disp.split(" ")[0]):
                self.slave_menu.set(disp)
                break
        self.m_in.delete(0, "end"); self.m_in.insert(0, master_sym)
        self.s_in.delete(0, "end")
        if slave_sym not in ("—", ""):
            self.s_in.insert(0, slave_sym)

    def _selected_slave_login(self):
        return self._slave_options().get(self.slave_menu.get())

    def add_map(self):
        login = self._selected_slave_login()
        ms, ss = self.m_in.get().strip(), self.s_in.get().strip()
        if not (login and ms and ss):
            return
        # replace an existing manual map for this (slave, symbol)
        self.state.symbol_maps = [
            m for m in self.state.symbol_maps
            if not (m.slave_login == login and m.master_symbol.upper() == ms.upper())
        ]
        self.state.symbol_maps.append(SymbolMap(ms, ss, slave_login=login))
        self.state.log(f"Manual map saved for {login}: {ms} → {ss}")
        self.m_in.delete(0, "end"); self.s_in.delete(0, "end")
        self.refresh()
        self.app.refresh_all()

    def delete_map(self):
        login = self._selected_slave_login()
        ms = self.m_in.get().strip()
        before = len(self.state.symbol_maps)
        self.state.symbol_maps = [
            m for m in self.state.symbol_maps
            if not (m.slave_login == login and m.master_symbol.upper() == ms.upper())
        ]
        if len(self.state.symbol_maps) < before:
            self.state.log(f"Manual map removed for {login}: {ms}")
        self.refresh()
        self.app.refresh_all()

    # ------------------------------------------------------------------ #
    def refresh(self):
        opts = list(self._slave_options().keys()) or ["—"]
        self.slave_menu.configure(values=opts)
        if self.slave_menu.get() not in opts:
            self.slave_menu.set(opts[0])

        self.tree.delete(*self.tree.get_children())
        for r in self.state.mapping_rows():
            slave_label = f"{r['slave_login']} · {r['slave_name']}"
            self.tree.insert("", "end", tags=(r["kind"],), values=(
                slave_label, r["master_symbol"], r["slave_symbol"], r["kind"],
            ))
