"""Logs page: rolling activity log."""
from __future__ import annotations

import customtkinter as ctk

from . import widgets as w


class LogsPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        head = ctk.CTkFrame(self, fg_color="transparent")
        head.pack(fill="x", padx=24, pady=(20, 0))
        w.title(head, "Activity Log").pack(side="left")
        w.ghost_button(head, "Clear", self.clear).pack(side="right")

        box = w.card(self)
        box.pack(fill="both", expand=True, padx=24, pady=16)
        self.text = ctk.CTkTextbox(box, fg_color=w.CARD, text_color=w.TEXT,
                                   font=("Consolas", 12))
        self.text.pack(fill="both", expand=True, padx=8, pady=8)
        self.refresh()

    def clear(self):
        self.state.logs.clear()
        self.refresh()

    def refresh(self):
        self.text.configure(state="normal")
        self.text.delete("1.0", "end")
        self.text.insert("end", "\n".join(self.state.logs))
        self.text.see("end")
        self.text.configure(state="disabled")
