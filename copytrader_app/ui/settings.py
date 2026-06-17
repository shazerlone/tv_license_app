"""Settings page: engine mode (demo/live), dry-run safety, poll interval."""
from __future__ import annotations

import customtkinter as ctk

from . import widgets as w


class SettingsPage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app

        w.title(self, "Settings").pack(anchor="w", padx=28, pady=(22, 0))
        w.subtitle(self, "Engine mode and safety controls").pack(anchor="w", padx=28)

        # ---- mode card ---------------------------------------------------- #
        mode = w.card(self)
        mode.pack(fill="x", padx=28, pady=16)
        ctk.CTkLabel(mode, text="Connection mode", font=(w.FONT, 15, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=18, pady=(16, 2))
        self.mode_desc = ctk.CTkLabel(mode, text="", text_color=w.MUTED,
                                      font=(w.FONT, 12), justify="left")
        self.mode_desc.pack(anchor="w", padx=18)
        self.live_switch = ctk.CTkSwitch(
            mode, text="Live mode (connect to real MT4/MT5 terminals)",
            command=self.toggle_live, progress_color=w.RED, font=(w.FONT, 13),
        )
        self.live_switch.pack(anchor="w", padx=18, pady=(10, 18))

        # ---- safety card -------------------------------------------------- #
        safety = w.card(self)
        safety.pack(fill="x", padx=28, pady=(0, 16))
        ctk.CTkLabel(safety, text="Safety", font=(w.FONT, 15, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=18, pady=(16, 2))
        ctk.CTkLabel(
            safety,
            text="Dry-run reads the master's live trades but NEVER sends orders —\n"
                 "it only logs what it would do. Keep this ON until you've verified\n"
                 "the copy behaviour on a demo account.",
            text_color=w.MUTED, font=(w.FONT, 12), justify="left",
        ).pack(anchor="w", padx=18)
        self.dry_switch = ctk.CTkSwitch(
            safety, text="Dry-run (do not place real orders)",
            command=self.toggle_dry, progress_color=w.GREEN, font=(w.FONT, 13),
        )
        self.dry_switch.pack(anchor="w", padx=18, pady=(10, 18))

        # ---- poll interval ------------------------------------------------ #
        poll = w.card(self)
        poll.pack(fill="x", padx=28, pady=(0, 16))
        ctk.CTkLabel(poll, text="Poll interval", font=(w.FONT, 15, "bold"),
                     text_color=w.TEXT).pack(anchor="w", padx=18, pady=(16, 2))
        ctk.CTkLabel(poll, text="How often the engine checks the master for new trades.",
                     text_color=w.MUTED, font=(w.FONT, 12)).pack(anchor="w", padx=18)
        prow = ctk.CTkFrame(poll, fg_color="transparent")
        prow.pack(anchor="w", padx=18, pady=(10, 18))
        self.poll_val = ctk.CTkLabel(prow, text="", text_color=w.TEXT,
                                     font=(w.FONT, 13, "bold"), width=70)
        self.slider = ctk.CTkSlider(prow, from_=0.5, to=10, number_of_steps=19,
                                    command=self.set_poll, width=280,
                                    button_color=w.ACCENT, progress_color=w.ACCENT)
        self.slider.pack(side="left")
        self.poll_val.pack(side="left", padx=12)

        self.banner = ctk.CTkLabel(self, text="", font=(w.FONT, 13, "bold"))
        self.banner.pack(anchor="w", padx=28, pady=(4, 0))

        self.refresh()

    # ------------------------------------------------------------------ #
    def toggle_live(self):
        self.state.live_mode = bool(self.live_switch.get())
        self.state.log(f"Mode set to {'LIVE' if self.state.live_mode else 'DEMO'}")
        self.refresh()
        self.app.refresh_all()

    def toggle_dry(self):
        # switch reads 1 when "dry-run on"
        self.state.dry_run = bool(self.dry_switch.get())
        self.state.log(f"Dry-run {'ON' if self.state.dry_run else 'OFF'}")
        self.refresh()

    def set_poll(self, value):
        self.state.poll_seconds = round(float(value), 1)
        self.poll_val.configure(text=f"{self.state.poll_seconds:g} s")

    def refresh(self):
        if self.state.live_mode:
            self.live_switch.select()
            self.mode_desc.configure(
                text="LIVE — the engine talks to your real terminals.")
        else:
            self.live_switch.deselect()
            self.mode_desc.configure(
                text="DEMO — simulated brokers. Safe to explore; nothing real trades.")

        self.dry_switch.select() if self.state.dry_run else self.dry_switch.deselect()
        self.slider.set(self.state.poll_seconds)
        self.poll_val.configure(text=f"{self.state.poll_seconds:g} s")

        if self.state.live_mode and not self.state.dry_run:
            self.banner.configure(
                text="⚠ LIVE + real orders enabled — trades will be placed on real accounts.",
                text_color=w.RED)
        elif self.state.live_mode and self.state.dry_run:
            self.banner.configure(
                text="● LIVE read-only (dry-run) — observing real trades, sending none.",
                text_color=w.AMBER)
        else:
            self.banner.configure(text="● Demo mode — simulated activity.",
                                  text_color=w.GREEN)
