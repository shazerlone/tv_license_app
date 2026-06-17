"""Master / Slave configuration page.

One master fans out to many slaves. Pick a master, attach slaves, and tune
each slave's lot sizing / direction independently.
"""
from __future__ import annotations

import customtkinter as ctk

from ..models import LotMode
from . import widgets as w


class MasterSlavePage(ctk.CTkFrame):
    def __init__(self, parent, state, app):
        super().__init__(parent, fg_color=w.BG)
        self.state = state
        self.app = app
        self.current_master = None

        w.title(self, "Master / Slave").pack(anchor="w", padx=24, pady=(20, 0))
        w.subtitle(self, "Assign one master to multiple slave accounts").pack(anchor="w", padx=24)

        # master selector row
        sel = w.card(self)
        sel.pack(fill="x", padx=24, pady=14)
        ctk.CTkLabel(sel, text="Master account", font=(w.FONT, 13, "bold"),
                     text_color=w.TEXT).pack(side="left", padx=(16, 10), pady=14)
        self.master_menu = ctk.CTkOptionMenu(
            sel, values=["—"], command=self.on_master_change, width=360,
            fg_color=w.BG, button_color=w.ACCENT, button_hover_color=w.ACCENT_HOVER,
        )
        self.master_menu.pack(side="left", pady=14)
        w.ghost_button(sel, "Promote selected to master", self.promote_dialog).pack(
            side="right", padx=16
        )

        # add-slave row
        addrow = ctk.CTkFrame(self, fg_color="transparent")
        addrow.pack(fill="x", padx=24)
        self.slave_menu = ctk.CTkOptionMenu(
            addrow, values=["—"], width=360, fg_color=w.CARD,
            button_color=w.ACCENT, button_hover_color=w.ACCENT_HOVER,
        )
        self.slave_menu.pack(side="left")
        w.primary_button(addrow, "＋ Attach slave", self.attach_slave).pack(side="left", padx=10)

        # slaves list (scrollable)
        self.slaves_frame = ctk.CTkScrollableFrame(self, fg_color="transparent")
        self.slaves_frame.pack(fill="both", expand=True, padx=24, pady=14)

        self.refresh()

    # ------------------------------------------------------------------ #
    def promote_dialog(self):
        login = self.slave_menu.get().split(" ")[0]
        if login and login != "—":
            self.state.set_master(login)
            self.current_master = login
            self.refresh()
            self.app.refresh_all()

    def on_master_change(self, value):
        self.current_master = value.split(" ")[0] if value != "—" else None
        self.refresh_slaves()

    def attach_slave(self):
        if not self.current_master:
            return
        login = self.slave_menu.get().split(" ")[0]
        if login and login != "—":
            self.state.add_slave(self.current_master, login)
            self.refresh()
            self.app.refresh_all()

    def detach(self, slave_login):
        self.state.remove_slave(self.current_master, slave_login)
        self.refresh()
        self.app.refresh_all()

    # ------------------------------------------------------------------ #
    def refresh(self):
        masters = self.state.masters()
        master_vals = [a.display for a in masters] or ["—"]
        self.master_menu.configure(values=master_vals)
        if self.current_master is None and masters:
            self.current_master = masters[0].login
        if self.current_master:
            acc = self.state.account(self.current_master)
            if acc:
                self.master_menu.set(acc.display)
        else:
            self.master_menu.set("—")

        # available accounts to attach = anything that isn't this master
        avail = [a for a in self.state.accounts if a.login != self.current_master]
        self.slave_menu.configure(values=[a.display for a in avail] or ["—"])
        if avail:
            self.slave_menu.set(avail[0].display)

        self.refresh_slaves()

    def refresh_slaves(self):
        for child in self.slaves_frame.winfo_children():
            child.destroy()
        group = self.state.group_for(self.current_master) if self.current_master else None
        if not group or not group.slaves:
            ctk.CTkLabel(self.slaves_frame, text="No slaves attached yet.",
                         text_color=w.MUTED, font=(w.FONT, 13)).pack(pady=30)
            return
        for sc in group.slaves:
            self._slave_row(sc)

    def _slave_row(self, sc):
        acc = self.state.account(sc.account_login)
        row = w.card(self.slaves_frame)
        row.pack(fill="x", pady=6)

        top = ctk.CTkFrame(row, fg_color="transparent")
        top.pack(fill="x", padx=14, pady=(12, 4))
        name = acc.display if acc else sc.account_login
        ctk.CTkLabel(top, text=name, font=(w.FONT, 14, "bold"),
                     text_color=w.GREEN).pack(side="left")
        ctk.CTkButton(top, text="✕ Detach", width=90, height=28, fg_color="transparent",
                      border_width=1, border_color=w.RED, text_color=w.RED,
                      hover_color=w.CARD,
                      command=lambda l=sc.account_login: self.detach(l)).pack(side="right")

        ctrls = ctk.CTkFrame(row, fg_color="transparent")
        ctrls.pack(fill="x", padx=14, pady=(0, 12))

        # enabled switch
        en = ctk.BooleanVar(value=sc.enabled)
        ctk.CTkSwitch(ctrls, text="Enabled", variable=en,
                      command=lambda v=en, s=sc: setattr(s, "enabled", v.get()),
                      progress_color=w.GREEN).grid(row=0, column=0, padx=(0, 18))

        # lot mode
        ctk.CTkLabel(ctrls, text="Lot mode", text_color=w.MUTED).grid(row=0, column=1, padx=(0, 6))
        mode = ctk.CTkOptionMenu(
            ctrls, values=[m.value for m in LotMode], width=150,
            fg_color=w.BG, button_color=w.ACCENT,
            command=lambda v, s=sc: setattr(s, "lot_mode", LotMode(v)),
        )
        mode.set(sc.lot_mode.value)
        mode.grid(row=0, column=2, padx=(0, 18))

        # lot value
        ctk.CTkLabel(ctrls, text="Value", text_color=w.MUTED).grid(row=0, column=3, padx=(0, 6))
        val = ctk.CTkEntry(ctrls, width=80)
        val.insert(0, str(sc.lot_value))
        val.grid(row=0, column=4, padx=(0, 18))
        val.bind("<FocusOut>", lambda e, s=sc, v=val: self._set_float(s, "lot_value", v))

        # reverse
        rev = ctk.BooleanVar(value=sc.reverse)
        ctk.CTkSwitch(ctrls, text="Reverse", variable=rev,
                      command=lambda v=rev, s=sc: setattr(s, "reverse", v.get()),
                      progress_color=w.AMBER).grid(row=0, column=5, padx=(0, 18))

        # copy SL/TP
        sltp = ctk.BooleanVar(value=sc.copy_sl_tp)
        ctk.CTkSwitch(ctrls, text="Copy SL/TP", variable=sltp,
                      command=lambda v=sltp, s=sc: setattr(s, "copy_sl_tp", v.get()),
                      progress_color=w.ACCENT).grid(row=0, column=6)

    @staticmethod
    def _set_float(obj, attr, entry):
        try:
            setattr(obj, attr, float(entry.get()))
        except ValueError:
            entry.delete(0, "end")
            entry.insert(0, str(getattr(obj, attr)))
