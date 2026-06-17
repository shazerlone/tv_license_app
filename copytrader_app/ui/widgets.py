"""Shared UI helpers and theme constants."""
from __future__ import annotations

import customtkinter as ctk

# palette
BG = "#0f1419"
CARD = "#1a212b"
ACCENT = "#2f80ed"
ACCENT_HOVER = "#1f6fd6"
GREEN = "#27ae60"
RED = "#eb5757"
AMBER = "#f2994a"
MUTED = "#8a94a6"
TEXT = "#e6edf3"

FONT = "Segoe UI"


def title(parent, text: str, size: int = 22):
    return ctk.CTkLabel(parent, text=text, font=(FONT, size, "bold"), text_color=TEXT)


def subtitle(parent, text: str):
    return ctk.CTkLabel(parent, text=text, font=(FONT, 13), text_color=MUTED)


def card(parent, **kw):
    return ctk.CTkFrame(parent, fg_color=CARD, corner_radius=12, **kw)


def stat_card(parent, label: str, value: str, color: str = TEXT):
    c = card(parent)
    ctk.CTkLabel(c, text=label, font=(FONT, 12), text_color=MUTED).pack(
        anchor="w", padx=16, pady=(14, 0)
    )
    val = ctk.CTkLabel(c, text=value, font=(FONT, 26, "bold"), text_color=color)
    val.pack(anchor="w", padx=16, pady=(0, 14))
    c.value_label = val
    return c


def primary_button(parent, text, command, **kw):
    return ctk.CTkButton(
        parent, text=text, command=command, fg_color=ACCENT,
        hover_color=ACCENT_HOVER, font=(FONT, 13, "bold"), height=36,
        corner_radius=8, **kw,
    )


def ghost_button(parent, text, command, **kw):
    return ctk.CTkButton(
        parent, text=text, command=command, fg_color="transparent",
        hover_color=CARD, border_width=1, border_color=MUTED,
        text_color=TEXT, font=(FONT, 13), height=34, corner_radius=8, **kw,
    )


def make_table(parent, columns: list[tuple[str, int]]):
    """Create a dark-styled ttk.Treeview. `columns` = list of (heading, width)."""
    from tkinter import ttk

    style = ttk.Style()
    try:
        style.theme_use("clam")
    except Exception:
        pass
    style.configure(
        "Copier.Treeview", background=CARD, fieldbackground=CARD,
        foreground=TEXT, rowheight=30, borderwidth=0, font=(FONT, 12),
    )
    style.configure(
        "Copier.Treeview.Heading", background=BG, foreground=MUTED,
        font=(FONT, 11, "bold"), borderwidth=0,
    )
    style.map("Copier.Treeview", background=[("selected", ACCENT)])

    keys = [c[0] for c in columns]
    tree = ttk.Treeview(
        parent, columns=keys, show="headings", style="Copier.Treeview", height=10,
    )
    for heading, width in columns:
        tree.heading(heading, text=heading)
        tree.column(heading, width=width, anchor="w")
    return tree
