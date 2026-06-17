"""Symbol mapping page: translate master symbols to slave-broker symbols."""
from __future__ import annotations

import customtkinter as ctk

from ..models import SymbolMap
from . import widgets as w


class MappingPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        w.title(self, "Symbol Mapping").pack(anchor="w", padx=24, pady=(20, 0))
        w.subtitle(self, "Map master symbols to each slave broker's naming (suffix/prefix or explicit)").pack(anchor="w", padx=24)

        # global prefix/suffix rule
        glob = w.card(self)
        glob.pack(fill="x", padx=24, pady=14)
        ctk.CTkLabel(glob, text="Global rule (applied when no explicit map matches)",
                     font=(w.FONT, 13, "bold"), text_color=w.TEXT).pack(anchor="w", padx=16, pady=(12, 6))
        grow = ctk.CTkFrame(glob, fg_color="transparent")
        grow.pack(fill="x", padx=16, pady=(0, 12))
        ctk.CTkLabel(grow, text="Slave prefix", text_color=w.MUTED).pack(side="left")
        self.prefix = ctk.CTkEntry(grow, width=100)
        self.prefix.insert(0, self.state.global_slave_prefix)
        self.prefix.pack(side="left", padx=(6, 18))
        ctk.CTkLabel(grow, text="Slave suffix", text_color=w.MUTED).pack(side="left")
        self.suffix = ctk.CTkEntry(grow, width=100)
        self.suffix.insert(0, self.state.global_slave_suffix)
        self.suffix.pack(side="left", padx=6)
        w.ghost_button(grow, "Save rule", self.save_global).pack(side="left", padx=18)
        self.preview = ctk.CTkLabel(grow, text="", text_color=w.MUTED, font=(w.FONT, 12))
        self.preview.pack(side="left", padx=12)

        # add explicit map
        addrow = ctk.CTkFrame(self, fg_color="transparent")
        addrow.pack(fill="x", padx=24)
        self.m_in = ctk.CTkEntry(addrow, placeholder_text="Master symbol e.g. EURUSD", width=240)
        self.m_in.pack(side="left")
        ctk.CTkLabel(addrow, text="→", font=(w.FONT, 18), text_color=w.MUTED).pack(side="left", padx=10)
        self.s_in = ctk.CTkEntry(addrow, placeholder_text="Slave symbol e.g. EURUSD.m", width=240)
        self.s_in.pack(side="left")
        w.primary_button(addrow, "＋ Add map", self.add_map).pack(side="left", padx=12)

        # table
        tcard = w.card(self)
        tcard.pack(fill="both", expand=True, padx=24, pady=14)
        self.tree = w.make_table(tcard, [
            ("Master symbol", 220), ("Slave symbol", 220), ("Enabled", 100),
        ])
        self.tree.pack(fill="both", expand=True, padx=16, pady=(16, 8))
        btns = ctk.CTkFrame(tcard, fg_color="transparent")
        btns.pack(fill="x", padx=16, pady=(0, 14))
        w.ghost_button(btns, "Toggle enabled", self.toggle_selected).pack(side="left")
        w.ghost_button(btns, "Delete selected", self.delete_selected).pack(side="left", padx=10)

        self.refresh()

    def save_global(self):
        self.state.global_slave_prefix = self.prefix.get().strip()
        self.state.global_slave_suffix = self.suffix.get().strip()
        self.state.log("Global symbol rule updated")
        self.refresh()

    def add_map(self):
        ms, ss = self.m_in.get().strip(), self.s_in.get().strip()
        if ms and ss:
            self.state.symbol_maps.append(SymbolMap(ms, ss))
            self.state.log(f"Symbol map added: {ms} → {ss}")
            self.m_in.delete(0, "end")
            self.s_in.delete(0, "end")
            self.refresh()
            self.app.refresh_all()

    def _selected_index(self):
        sel = self.tree.selection()
        if not sel:
            return None
        return self.tree.index(sel[0])

    def toggle_selected(self):
        i = self._selected_index()
        if i is not None:
            self.state.symbol_maps[i].enabled = not self.state.symbol_maps[i].enabled
            self.refresh()
            self.app.refresh_all()

    def delete_selected(self):
        i = self._selected_index()
        if i is not None:
            m = self.state.symbol_maps.pop(i)
            self.state.log(f"Symbol map removed: {m.master_symbol} → {m.slave_symbol}")
            self.refresh()
            self.app.refresh_all()

    def refresh(self):
        self.preview.configure(
            text=f"Preview: EURUSD → {self.state.resolve_symbol('EURUSD')}"
        )
        self.tree.delete(*self.tree.get_children())
        for m in self.state.symbol_maps:
            self.tree.insert("", "end", values=(
                m.master_symbol, m.slave_symbol, "Yes" if m.enabled else "No",
            ))
