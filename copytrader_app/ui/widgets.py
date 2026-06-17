"""Shared UI helpers and theme constants."""
from __future__ import annotations

import customtkinter as ctk

# palette — modern light theme
BG = "#eef1f7"          # app background (soft blue-grey)
SIDEBAR = "#ffffff"     # sidebar surface
CARD = "#ffffff"        # card surface
CARD_BORDER = "#e2e7f0" # subtle card outline
HOVER = "#eaf0ff"       # light hover / soft accent fill
ACCENT = "#4361ee"      # primary indigo
ACCENT_HOVER = "#3551d6"
GREEN = "#15a06a"
GREEN_SOFT = "#e3f7ee"
RED = "#e5484d"
AMBER = "#f59e0b"
AMBER_SOFT = "#fdf0d5"
BLUE_SOFT = "#e6ecff"
MUTED = "#7a8699"       # secondary text
TEXT = "#1b2333"        # primary text

FONT = "Segoe UI"


def title(parent, text: str, size: int = 22):
    return ctk.CTkLabel(parent, text=text, font=(FONT, size, "bold"), text_color=TEXT)


def subtitle(parent, text: str):
    return ctk.CTkLabel(parent, text=text, font=(FONT, 13), text_color=MUTED)


def card(parent, **kw):
    return ctk.CTkFrame(parent, fg_color=CARD, corner_radius=14,
                        border_width=1, border_color=CARD_BORDER, **kw)


def stat_card(parent, label: str, value: str, color: str = TEXT, accent: str = ACCENT):
    c = card(parent)
    # accent strip at the top of each stat card for a modern dashboard feel
    strip = ctk.CTkFrame(c, fg_color=accent, height=4, corner_radius=8)
    strip.pack(fill="x", padx=16, pady=(12, 0))
    ctk.CTkLabel(c, text=label.upper(), font=(FONT, 11, "bold"), text_color=MUTED).pack(
        anchor="w", padx=16, pady=(10, 0)
    )
    val = ctk.CTkLabel(c, text=value, font=(FONT, 28, "bold"), text_color=color)
    val.pack(anchor="w", padx=16, pady=(0, 16))
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
        hover_color=HOVER, border_width=1, border_color=ACCENT,
        text_color=ACCENT, font=(FONT, 13, "bold"), height=34, corner_radius=8, **kw,
    )


def pill(parent, text: str, fg: str, bg: str):
    """A small rounded status pill (badge)."""
    return ctk.CTkLabel(
        parent, text=f" {text} ", font=(FONT, 11, "bold"),
        text_color=fg, fg_color=bg, corner_radius=10, padx=8,
    )


def make_table(parent, columns: list[tuple[str, int]]):
    """Create a light-styled ttk.Treeview. `columns` = list of (heading, width)."""
    from tkinter import ttk

    style = ttk.Style()
    try:
        style.theme_use("clam")
    except Exception:
        pass
    style.configure(
        "Copier.Treeview", background=CARD, fieldbackground=CARD,
        foreground=TEXT, rowheight=34, borderwidth=0, font=(FONT, 12),
    )
    style.configure(
        "Copier.Treeview.Heading", background="#f4f6fb", foreground=MUTED,
        font=(FONT, 11, "bold"), borderwidth=0, relief="flat",
    )
    style.map("Copier.Treeview",
              background=[("selected", HOVER)],
              foreground=[("selected", TEXT)])

    keys = [c[0] for c in columns]
    tree = ttk.Treeview(
        parent, columns=keys, show="headings", style="Copier.Treeview", height=10,
    )
    for heading, width in columns:
        tree.heading(heading, text=heading)
        tree.column(heading, width=width, anchor="w")
    return tree
