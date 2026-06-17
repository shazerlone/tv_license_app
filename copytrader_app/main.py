"""Application entry point: window shell + sidebar navigation."""
from __future__ import annotations

import customtkinter as ctk

from . import __version__
from .models import AppState
from .ui import widgets as w
from .ui.dashboard import DashboardPage
from .ui.logs import LogsPage
from .ui.mapping import MappingPage
from .ui.masterslave import MasterSlavePage
from .ui.terminals import TerminalsPage

APP_NAME = "CopyTrader Pro"

NAV = [
    ("Dashboard", "📊", DashboardPage),
    ("Terminals", "🖥️", TerminalsPage),
    ("Master / Slave", "🔗", MasterSlavePage),
    ("Symbol Mapping", "🔁", MappingPage),
    ("Logs", "📜", LogsPage),
]


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        ctk.set_appearance_mode("dark")
        self.title(f"{APP_NAME} v{__version__}")
        self.geometry("1180x720")
        self.minsize(1000, 640)
        self.configure(fg_color=w.BG)

        self.state_data = AppState()
        self.pages: dict[str, ctk.CTkFrame] = {}
        self.nav_buttons: dict[str, ctk.CTkButton] = {}

        self._build_sidebar()
        self._build_content()
        self.show("Dashboard")

    # ------------------------------------------------------------------ #
    def _build_sidebar(self):
        bar = ctk.CTkFrame(self, fg_color=w.CARD, width=220, corner_radius=0)
        bar.pack(side="left", fill="y")
        bar.pack_propagate(False)

        ctk.CTkLabel(bar, text=f"  ⚡ {APP_NAME}", font=(w.FONT, 18, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=16, pady=(22, 4))
        ctk.CTkLabel(bar, text="  MT4 / MT5 copy trading", font=(w.FONT, 11),
                     text_color=w.MUTED).pack(anchor="w", padx=16, pady=(0, 18))

        for name, icon, _ in NAV:
            b = ctk.CTkButton(
                bar, text=f"  {icon}  {name}", anchor="w", height=42,
                fg_color="transparent", hover_color=w.BG, text_color=w.TEXT,
                font=(w.FONT, 14), corner_radius=8,
                command=lambda n=name: self.show(n),
            )
            b.pack(fill="x", padx=10, pady=2)
            self.nav_buttons[name] = b

        self.engine_lbl = ctk.CTkLabel(bar, text="● Engine stopped",
                                       text_color=w.RED, font=(w.FONT, 12))
        self.engine_lbl.pack(side="bottom", anchor="w", padx=16, pady=18)

    def _build_content(self):
        self.container = ctk.CTkFrame(self, fg_color=w.BG, corner_radius=0)
        self.container.pack(side="left", fill="both", expand=True)
        for name, _, page_cls in NAV:
            page = page_cls(self.container, self.state_data, self)
            self.pages[name] = page

    # ------------------------------------------------------------------ #
    def show(self, name: str):
        for p in self.pages.values():
            p.pack_forget()
        self.pages[name].pack(fill="both", expand=True)
        if hasattr(self.pages[name], "refresh"):
            self.pages[name].refresh()
        for n, b in self.nav_buttons.items():
            b.configure(fg_color=w.ACCENT if n == name else "transparent")
        self._update_engine_label()

    def refresh_all(self):
        for p in self.pages.values():
            if hasattr(p, "refresh"):
                try:
                    p.refresh()
                except Exception:
                    pass
        self._update_engine_label()

    def _update_engine_label(self):
        if self.state_data.copying:
            self.engine_lbl.configure(text="● Engine running", text_color=w.GREEN)
        else:
            self.engine_lbl.configure(text="● Engine stopped", text_color=w.RED)


def main():
    App().mainloop()


if __name__ == "__main__":
    main()
