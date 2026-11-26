#!/usr/bin/env python3
"""Renders PNG layout mockups of the safety and accessibility screens.

When no Android device or Flutter SDK is attached, this script draws layout
mockups directly with ImageMagick primitives using the real color tokens from
`lib/theme/colors.dart` and the current UI copy from `lib/l10n/strings.dart`.

Outputs (into docs/screenshots/):
  get-help-1.png            emergency card + counselors
  get-help-2.png            crisis lines, reporting, disclaimer
  home-with-help.png        schedule screen with the Help button + disclaimer bar
  settings-safety.png       Settings > Safety section
  get-help-deuteranopia.png the same Get help screen under deuteranopia
  get-help-spanish.png      the Get help screen in Spanish
  language-picker.png       Settings language picker sheet
  palette-simulated.png     color chips under normal / deutan / protan / tritan

Usage: python3 tools/render_mockups.py
"""

from __future__ import annotations

import functools
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_contrast import parse_tokens, simulate_cvd  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "screenshots"
SCALE = 2.0
W = 412  # dp width of a typical Android phone

L = parse_tokens()["light"]


def hexc(name: str) -> str:
    r, g, b = L[name]
    return f"#{r:02X}{g:02X}{b:02X}"


def remap(name: str, kind: str | None) -> str:
    """Color token -> hex, optionally through a CVD simulation."""
    r, g, b = simulate_cvd(L[name], kind)
    return f"#{r:02X}{g:02X}{b:02X}"


# ---------------------------------------------------------- text measurement
@functools.lru_cache(maxsize=8192)
def measure(text: str, size: float, bold: bool) -> float:
    """Width in dp, measured from the actual font (cached)."""
    font = "DejaVu-Sans-Bold" if bold else "DejaVu-Sans"
    out = subprocess.run(
        ["convert", "-font", font, "-pointsize", str(int(size * 2)),
         f"label:{text}", "-format", "%w", "info:"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return float(out) / 2.0


# --------------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, width: int, height: int, kind: str | None = None):
        self.w, self.h, self.kind = width, height, kind
        self.ops: list[str] = []
        self.bottom = 0.0
        self.c = lambda n: remap(n, kind)

    # -- primitives -----------------------------------------------------
    def _p(self, v: float) -> int:
        return int(round(v * SCALE))

    def rect(self, x, y, w, h, fill, radius=0, stroke=None, sw=1):
        self.bottom = max(self.bottom, y + h)
        X, Y, Wd, H = self._p(x), self._p(y), self._p(w), self._p(h)
        if radius:
            r = self._p(radius)
            geom = f"roundrectangle {X},{Y} {X + Wd},{Y + H} {r},{r}"
        else:
            geom = f"rectangle {X},{Y} {X + Wd},{Y + H}"
        if fill:
            self.ops.append(f"fill '{self._c(fill)}' stroke none {geom}")
        if stroke:
            self.ops.append(
                f"fill none stroke '{self._c(stroke)}' stroke-width {self._p(sw)} {geom}"
            )

    def _c(self, token_or_hex: str) -> str:
        if token_or_hex == "none":
            return "none"
        return token_or_hex if token_or_hex.startswith("#") else self.c(token_or_hex)

    def circle(self, cx, cy, r, fill):
        self.bottom = max(self.bottom, cy + r)
        self.ops.append(
            f"fill '{self._c(fill)}' stroke none circle {self._p(cx)},{self._p(cy)} "
            f"{self._p(cx + r)},{self._p(cy)}"
        )

    def text(self, x, y, s, size=14, color="onSurface", bold=False, align="left",
             italic=False, spacing=1.0):
        self.bottom = max(self.bottom, y + size * 0.4)
        width_px = measure(s, size, bold) * spacing
        tx = x
        if align == "center":
            tx = x - width_px / 2
        elif align == "right":
            tx = x - width_px
        font = "DejaVu-Sans-Bold" if bold else (
            "DejaVu-Sans-Oblique" if italic else "DejaVu-Sans")
        safe = s.replace("\\", "\\\\").replace('"', '\\"').replace("'", "\u2019")
        self.ops.append(
            f"font '{font}' font-size {self._p(size)} fill '{self._c(color)}' "
            f"stroke none text {self._p(tx)},{self._p(y)} \"{safe}\""
        )
        return width_px

    def wrap(self, x, y, s, max_w, size=13, color="onSurfaceVariant", bold=False,
             line_h=None, align="left"):
        line_h = line_h or size * 1.5
        words, line, lines = s.split(), "", []
        for word in words:
            candidate = f"{line} {word}".strip()
            if not line or measure(candidate, size, bold) <= max_w:
                line = candidate
            else:
                lines.append(line)
                line = word
        if line:
            lines.append(line)
        cy = y
        for ln in lines:
            if align == "center":
                self.text(x + max_w / 2, cy, ln, size=size, color=color,
                          bold=bold, align="center")
            else:
                self.text(x, cy, ln, size=size, color=color, bold=bold,
                          align=align)
            cy += line_h
        return cy

    def icon(self, cx, cy, kind="help", color="onSurfaceVariant", size=12):
        """Flat stand-ins for Material icons; recognisable at mockup scale."""
        col = self._c(color)
        s = size
        if kind == "help":  # support agent: head + shoulders
            self.circle(cx, cy - s * 0.35, s * 0.38, color)
            self.ops.append(
                f"fill '{col}' stroke none roundrectangle "
                f"{self._p(cx - s * 0.62)},{self._p(cy + s * 0.1)} "
                f"{self._p(cx + s * 0.62)},{self._p(cy + s * 0.95)} "
                f"{self._p(s * 0.4)},{self._p(s * 0.4)}"
            )
        elif kind == "phone":  # classic handset: two ear pieces + a bar
            for dx, dy in ((-s * 0.55, -s * 0.45), (s * 0.55, s * 0.45)):
                self.circle(cx + dx, cy + dy, s * 0.32, color)
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(s * 0.45)} fill none "
                f"line {self._p(cx - s * 0.45)},{self._p(cy - s * 0.35)} "
                f"{self._p(cx + s * 0.45)},{self._p(cy + s * 0.35)}"
            )
        elif kind == "mail":
            self.rect(cx - s * 0.8, cy - s * 0.55, s * 1.6, s * 1.1, "none",
                      radius=2, stroke=color, sw=1.2)
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.2)} fill none "
                f"polyline {self._p(cx - s * 0.8)},{self._p(cy - s * 0.5)} "
                f"{self._p(cx)},{self._p(cy + s * 0.15)} "
                f"{self._p(cx + s * 0.8)},{self._p(cy - s * 0.5)}"
            )
        elif kind == "globe":
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.3)} fill none "
                f"circle {self._p(cx)},{self._p(cy)} "
                f"{self._p(cx + s * 0.85)},{self._p(cy)}"
            )
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.1)} fill none "
                f"line {self._p(cx)},{self._p(cy - s * 0.85)} "
                f"{self._p(cx)},{self._p(cy + s * 0.85)}"
            )
        elif kind == "warn":  # triangle with bang
            self.ops.append(
                f"fill '{col}' stroke none polygon "
                f"{self._p(cx)},{self._p(cy - s)} "
                f"{self._p(cx + s)},{self._p(cy + s * 0.8)} "
                f"{self._p(cx - s)},{self._p(cy + s * 0.8)}"
            )
        elif kind == "sms":
            self.rect(cx - s * 0.85, cy - s * 0.6, s * 1.7, s * 1.05, "none",
                      radius=s * 0.3, stroke=color, sw=1.2)
        elif kind == "check":
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.6)} fill none polyline "
                f"{self._p(cx - s * 0.6)},{self._p(cy)} "
                f"{self._p(cx - s * 0.1)},{self._p(cy + s * 0.5)} "
                f"{self._p(cx + s * 0.65)},{self._p(cy - s * 0.5)}"
            )
        elif kind == "gear":
            self.circle(cx, cy, s * 0.55, color)
            self.circle(cx, cy, s * 0.22, "surfaceContainerLow")
        elif kind == "chevron":  # chevron_right
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.6)} fill none polyline "
                f"{self._p(cx - s * 0.25)},{self._p(cy - s * 0.5)} "
                f"{self._p(cx + s * 0.25)},{self._p(cy)} "
                f"{self._p(cx - s * 0.25)},{self._p(cy + s * 0.5)}"
            )
        elif kind == "download":  # download_done: tray plus arrow
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.4)} fill none polyline "
                f"{self._p(cx - s * 0.6)},{self._p(cy + s * 0.15)} "
                f"{self._p(cx - s * 0.6)},{self._p(cy + s * 0.7)} "
                f"{self._p(cx + s * 0.6)},{self._p(cy + s * 0.7)} "
                f"{self._p(cx + s * 0.6)},{self._p(cy + s * 0.15)}"
            )
            self.ops.append(
                f"stroke '{col}' stroke-width {self._p(1.4)} fill none polyline "
                f"{self._p(cx)},{self._p(cy - s * 0.7)} "
                f"{self._p(cx)},{self._p(cy + s * 0.25)} "
                f"{self._p(cx - s * 0.4)},{self._p(cy - s * 0.15)} "
                f"{self._p(cx)},{self._p(cy + s * 0.25)} "
                f"{self._p(cx + s * 0.4)},{self._p(cy - s * 0.15)}"
            )

    def button_width(self, label, kind_icon=True, pad=32) -> float:
        return measure(label, 13, True) + pad + (22 if kind_icon else 0)

    def button(self, x, y, w, h, label, style="filled", kind=None):
        styles = {
            "filled": ("error", "onError"),
            "primary": ("primary", "onPrimary"),
            "tonal": ("secondaryContainer", "onSecondaryContainer"),
            "outlined": ("none", "primary"),
            "text": ("none", "primary"),
        }
        bg, fg = styles[style]
        radius = 8
        if bg != "none":
            self.rect(x, y, w, h, bg, radius=radius)
        else:
            self.rect(x, y, w, h, None, radius=radius, stroke="outline", sw=1)
        if kind:
            self.icon(x + 20, y + h / 2, kind, color=fg, size=8)
            self.text(x + 34, y + h / 2 + 4.5, label, size=13, color=fg, bold=True)
        else:
            self.text(x + w / 2, y + h / 2 + 4.5, label, size=13, color=fg,
                      bold=True, align="center")

    def section_title(self, x, y, label, icon_kind="help"):
        self.icon(x + 10, y - 4, icon_kind, color="primary", size=9)
        self.text(x + 28, y, label, size=15, color="onSurface", bold=True)

    def card(self, x, y, w, h, fill="surfaceContainerLow", stroke="outlineVariant"):
        self.rect(x, y, w, h, fill, radius=12, stroke=stroke, sw=1)

    # -- output ---------------------------------------------------------
    def save(self, path: Path, pad: int = 20):
        OUT.mkdir(parents=True, exist_ok=True)
        draw = " ".join(self.ops)
        height = min(self.h, int(self.bottom + pad))
        cmd = [
            "convert", "-size", f"{self._p(self.w)}x{self._p(self.h)}",
            f"xc:{self.c('background')}", "-draw", draw,
            "-crop", f"{self._p(self.w)}x{self._p(height)}+0+0", "+repage",
            str(path),
        ]
        subprocess.run(cmd, check=True)
        print("wrote", path.relative_to(ROOT), f"({height}dp)")


# ------------------------------------------------------------------ get help
def _paragraph(c, x, y, text, max_w, size=13, color="onSurfaceVariant",
               bold=False, line_h=None):
    """Draws a wrapped paragraph and returns the y after it."""
    return c.wrap(x, y, text, max_w, size=size, color=color, bold=bold,
                  line_h=line_h)


def get_help_screen(kind: str | None = None) -> Canvas:
    c = Canvas(W, 2400, kind)
    c.rect(0, 0, W, 56, "primaryContainer")
    c.text(16, 35, "Get help", size=20, color="onPrimaryContainer", bold=True)
    c.icon(W - 28, 28, "globe", color="onPrimaryContainer", size=9)

    # ---- emergency card ----
    x, w = 12, W - 24
    y = 72
    inner_x, inner_w = x + 16, w - 32
    text_h = measure("Call 911 now if you or someone else is in danger of being "
                     "hurt, or if you need emergency help right away.", 13, False)
    lines = 2
    h = 16 + 20 + 8 + lines * 19 + 12 + 48 + 10 + 2 * 17 + 16
    c.rect(x, y, w, h, "errorContainer", radius=12)
    c.icon(inner_x + 9, y + 26, "warn", color="onErrorContainer", size=10)
    c.text(inner_x + 24, y + 31, "In immediate danger?", size=15,
           color="onErrorContainer", bold=True)
    cy = _paragraph(c, inner_x, y + 52,
                    "Call 911 now if you or someone else is in danger of being "
                    "hurt, or if you need emergency help right away.", inner_w,
                    size=13, color="onErrorContainer")
    c.button(inner_x, cy + 6, inner_w, 48, "Call 911", style="filled",
             kind="phone")
    _paragraph(c, inner_x, cy + 66,
               "If you are not sure whether it is an emergency, call or text "
               "988 to talk through next steps with a counselor.",
               inner_w, size=11, color="onErrorContainer")
    y += h + 22

    # ---- counselors ----
    c.section_title(12, y, "Talk to a counselor at Westview", "help")
    y += 14
    rows = [("A–C", "Taylor Oakley", "3080"), ("D–J", "Isabella Rusy", "3062"),
            ("K–M", "Christine Cudmore", "3030"),
            ("N–Sh", "Adriana Chittuluru", "3026"),
            ("Si–Z", "Vicki deJesus", "3023")]
    card_h = (24 + 3 * 19 + 96 + 22 + 19 + 18 + len(rows) * 36 + 12 + 3 * 16
              + 16)
    c.card(12, y, w, card_h)
    ix, iw = x + 16, w - 32
    cy = _paragraph(c, ix, y + 24,
                    "Counselors are in the Wolverine Center during school hours. "
                    "You can drop in, ask a teacher for a pass, or email your "
                    "counselor directly.", iw, size=13,
                    color="onSurface")
    c.button(ix, cy + 8, 168, 48, "Call the office", style="tonal", kind="phone")
    c.button(ix + 180, cy + 8, 172, 48, "Counseling site", style="outlined")
    _paragraph(c, ix, cy + 70,
               "Westview High School · 13500 Camino del Sur · (858) 780-2000",
               iw, size=11)
    dy = cy + 92
    c.rect(ix, dy, iw, 1, "outlineVariant")
    c.text(ix, dy + 24, "Find your counselor", size=13, color="onSurface",
           bold=True)
    c.text(ix, dy + 40, "Listed by the first letter of your last name.", size=11)
    ry = dy + 54
    for caseload, name, ext in rows:
        c.rect(ix, ry, 52, 26, "secondaryContainer", radius=8)
        c.text(ix + 26, ry + 17, caseload, size=11, color="onSecondaryContainer",
               bold=True, align="center")
        c.text(ix + 64, ry + 12, name, size=13, color="onSurface", bold=True)
        c.text(ix + 64, ry + 26, f"(858) 780-2000 ext {ext}", size=10)
        c.icon(x + w - 62, ry + 13, "phone", color="primary", size=8)
        c.icon(x + w - 30, ry + 13, "mail", color="primary", size=8)
        ry += 36
    c.text(ix, ry + 14, "College & career · Danielle Beccarelli · ext 3019",
           size=10)
    _paragraph(c, ix, ry + 34,
               "Staff assignments can change during the school year. Verified "
               "November 2025; confirm current caseloads with the counseling "
               "office.", iw, size=10)
    return c


def get_help_screen_2(kind: str | None = None) -> Canvas:
    c = Canvas(W, 2600, kind)
    c.rect(0, 0, W, 56, "primaryContainer")
    c.text(16, 35, "Get help", size=20, color="onPrimaryContainer", bold=True)

    y = 78
    c.section_title(12, y, "24/7 free crisis lines", "warn")
    y += 22

    # Deaf / hard-of-hearing note placed above the phone numbers.
    deaf_note = (
        "Deaf, hard of hearing, or unable to speak aloud? Every service below "
        "supports text or online chat. 988 and Crisis Text Line work directly "
        "by text, and San Diego County\u2019s line is reachable through 711 relay."
    )
    c.icon(22, y + 8, "help", color="onSurfaceVariant", size=7)
    y = _paragraph(c, 38, y, deaf_note, W - 52, size=11, line_h=15) + 10

    hotlines = [
        ("988 Suicide & Crisis Lifeline",
         "Free, confidential 24/7 support by call or text for emotional "
         "distress or suicidal crisis.",
         "Call 988", "Text 988"),
        ("San Diego Access & Crisis Line",
         "San Diego County's 24/7 mental health and substance use crisis line "
         "for yourself or someone else, with interpreters in 200+ languages.",
         "Call 1-888-724-7240", None),
        ("Crisis Text Line",
         "Free, confidential 24/7 crisis support over text with a trained "
         "counselor.",
         None, "Text HOME to 741741"),
    ]
    for name, desc, call, text in hotlines:
        # wrap first to learn the height
        probe = Canvas(W, 10, kind)
        bottom = probe.wrap(28, 0, desc, W - 56, size=11)
        desc_lines = int(round(bottom / (11 * 1.5)))
        actions = 1 if (call and text) else 1
        h = 16 + 18 + 6 + desc_lines * 17 + 10 + 44 + 16
        c.card(12, y, W - 24, h)
        c.text(28, y + 26, name, size=13, color="onSurface", bold=True)
        _paragraph(c, 28, y + 44, desc, W - 56, size=11)
        by = y + h - 60
        if call and text:
            c.button(28, by, c.button_width(call) + 16, 44, call,
                     style="tonal", kind="phone")
            c.button(28 + c.button_width(call) + 28, by,
                     c.button_width(text) + 16, 44, text, style="outlined",
                     kind="sms")
        elif call:
            c.button(28, by, c.button_width(call) + 16, 44, call,
                     style="tonal", kind="phone")
        else:
            c.button(28, by, c.button_width(text) + 16, 44, text,
                     style="outlined", kind="sms")
        y += h + 10

    # reporting
    y += 10
    c.section_title(12, y, "Report a safety concern", "warn")
    y += 16
    probe = Canvas(W, 10, kind)
    intro_lines = int(round(probe.wrap(28, 0,
        "If you are concerned about a classmate, a threat, a weapon, or "
        "something you saw online, tell a trusted adult or submit an anonymous "
        "report:",
        W - 56, size=13) / (13 * 1.5)))
    report_h = 24 + intro_lines * 20 + 12 + 2 * 44 + 30
    c.card(12, y, W - 24, report_h)
    ix, iw = 28, W - 56
    cy = _paragraph(c, ix, y + 24,
                    "If you are concerned about a classmate, a threat, a "
                    "weapon, or something you saw online, tell a trusted adult "
                    "or submit an anonymous report:", iw, size=13,
                    color="onSurface")
    for name, num in [("Say Something Anonymous Reporting",
                       "Call 1-844-5-SAYNOW"),
                      ("PUSD See Something, Say Something",
                       "Call 1-844-PUSD-TIP")]:
        c.text(ix, cy + 14, name, size=12, color="onSurface", bold=True)
        c.text(ix, cy + 28, num, size=10)
        c.button(W - 100, cy + 2, 72, 40, "Call", style="tonal")
        cy += 44
    _paragraph(c, ix, cy + 12,
               "You do not need to be certain before reporting a good-faith "
               "safety concern.", iw, size=10)
    y += report_h + 22

    # disclaimer
    c.section_title(12, y, "About this app", "globe")
    y += 16
    disp_en = ("DISCLAIMER: This activity is not a school-sponsored activity "
               "and is not endorsed by the school or Poway Unified School "
               "District. The products or services advertised in this flyer "
               "are not endorsed by the school or the District.")
    disp_es = ("AVISO LEGAL: Esta actividad no es una actividad patrocinada "
               "por la escuela y no está avalada por la escuela ni por el "
               "Distrito Escolar Unificado de Poway.")
    probe = Canvas(W, 10, kind)
    en_lines = int(round(probe.wrap(28, 0, disp_en, W - 56, size=11, bold=True)
                         / (11 * 1.5)))
    es_lines = int(round(probe.wrap(28, 0, disp_es, W - 56, size=11, bold=True)
                         / (11 * 1.5)))
    h = 16 + 26 + 10 + en_lines * 17 + 12 + es_lines * 17 + 12 + 5 * 15 + 18
    c.rect(12, y, W - 24, h, "surfaceContainerHighest", radius=12,
           stroke="outlineVariant")
    c.icon(30, y + 26, "check", color="onSurfaceVariant", size=9)
    c.text(48, y + 31, "This app is not part of Poway Unified", size=13,
           color="onSurface", bold=True)
    cy = _paragraph(c, 28, y + 54, disp_en, W - 56, size=11,
                    color="onSurfaceVariant", bold=True)
    cy = _paragraph(c, 28, cy + 8, disp_es, W - 56, size=11,
                    color="onSurfaceVariant", bold=True)
    cy = _paragraph(c, 28, cy + 10,
                    "Westview HS (WVAA) is built independently by a student and "
                    "is not built, run, or reviewed by Poway Unified or Westview "
                    "High School. Confirm schedules and contacts with the school "
                    "office.", W - 56, size=10)
    _paragraph(c, 28, cy + 8,
               "Translated summaries are provided for convenience; the official "
               "English and Spanish district disclaimers above govern.", W - 56,
               size=10,
               )
    return c


# ----------------------------------------------------------------- home page
def home_screen(kind: str | None = None) -> Canvas:
    c = Canvas(W, 800, kind)
    c.rect(0, 0, W, 800, "background")

    # segmented schedule selector
    c.rect(12, 12, W - 24, 44, "surfaceContainerHighest", radius=22)
    c.rect(16, 16, (W - 32) / 3, 36, "secondaryContainer", radius=18)
    for i, label in enumerate(["Mon/Fri", "Tue/Thu", "Wed"]):
        c.text(16 + (W - 32) / 6 + i * (W - 32) / 3, 39, label, size=12,
               color="onSecondaryContainer" if i == 0 else "onSurfaceVariant",
               bold=i == 0, align="center")

    # "Now" card: highlight fill, left accent bar, and a "Now" pill near the
    # countdown. No play arrow, so nothing reads as a button.
    c.rect(12, 68, W - 24, 104, "primaryContainer", radius=12)
    c.text(W / 2, 100, "Period 2 · Algebra 2", size=16,
           color="onPrimaryContainer", bold=True, align="center")
    c.text(W / 2, 128, "24:18 left", size=22, color="onPrimaryContainer",
           align="center")
    pill_w = 46
    c.rect(W / 2 - pill_w / 2, 142, pill_w, 20, "primary", radius=10)
    c.text(W / 2, 156, "Now", size=10, color="onPrimary", bold=True,
           align="center")

    # period rows, including the running period with its left accent bar
    y = 184
    for name, detail, times, is_now in [
        ("Period 1", "Mr. Smith · Rm 402", "8:00 – 9:40", False),
        ("Period 2", "Algebra 2", "10:33 – 11:58", True),
        ("Passing", "", "11:58 – 12:04", False),
        ("Lunch", "", "12:04 – 12:39", False),
    ]:
        fill = "primaryContainer" if is_now else "surfaceContainerLow"
        ink = "onPrimaryContainer" if is_now else "onSurface"
        detail_ink = "onPrimaryContainer" if is_now else "onSurfaceVariant"
        c.card(12, y, W - 24, 62, fill=fill)
        text_x = 28
        if is_now:
            c.rect(20, y + 13, 4, 36, "primary", radius=2)
            text_x = 34
        c.text(text_x, y + 26, name, size=14, color=ink, bold=True)
        if detail:
            c.text(text_x, y + 44, detail, size=11, color=detail_ink)
        start, end = times.split(" – ")
        c.text(W - 150, y + 26, start, size=12, color=ink)
        c.text(W - 84, y + 26, end, size=12, color=ink)
        y += 70

    # FAB row: Help (extended) + Settings
    fab_y = y + 12
    c.rect(12, fab_y, 148, 56, "secondaryContainer", radius=16)
    c.icon(36, fab_y + 28, "help", color="onSecondaryContainer", size=10)
    c.text(56, fab_y + 26, "Help", size=14, color="onSecondaryContainer",
           bold=True)
    c.text(56, fab_y + 42, "long-press = exit", size=9,
           color="onSecondaryContainer")
    c.rect(172, fab_y, 56, 56, "secondaryContainer", radius=16)
    c.icon(200, fab_y + 28, "gear", color="onSecondaryContainer", size=11)

    # nav bar (5 destinations)
    nav_y = 668
    c.rect(0, nav_y, W, 80, "surfaceContainerLow")
    labels = ["Schedule", "Newsletters", "Publications", "Calendar", "Get help"]
    step = W / 5
    for i, label in enumerate(labels):
        cx = step * i + step / 2
        active = i == 4
        if active:
            c.rect(cx - 32, nav_y + 12, 64, 30, "secondaryContainer", radius=15)
        c.icon(cx, nav_y + 27, "help" if i == 4 else "check",
               color="onSecondaryContainer" if active else "onSurfaceVariant",
               size=9)
        c.text(cx, nav_y + 60, label, size=10,
               color="onSurface" if active else "onSurfaceVariant",
               bold=active, align="center")

    # disclaimer bar
    dy = nav_y + 80
    c.rect(0, dy, W, 52, "surfaceContainerHighest")
    c.icon(20, dy + 26, "warn", color="onSurfaceVariant", size=5)
    c.wrap(34, dy + 18, "Not a Poway Unified app. Student-built; not sponsored "
           "or endorsed by Poway Unified School District or Westview High "
           "School.",
           W - 52, size=9, align="center", line_h=12)
    return c


# --------------------------------------------------------------- settings
def settings_screen(kind: str | None = None) -> Canvas:
    c = Canvas(W, 640, kind)
    c.rect(0, 0, W, 56, "primaryContainer")
    c.text(16, 35, "Settings", size=20, color="onPrimaryContainer", bold=True)

    y = 76
    c.text(16, y, "SAFETY", size=11, color="primary", bold=True)
    y += 14
    c.rect(16, y, W - 32, 64, "surfaceContainerLow", radius=12)
    c.icon(40, y + 32, "help", color="onSurfaceVariant", size=10)
    c.text(64, y + 26, "Get help now", size=14, color="onSurface")
    c.wrap(64, y + 44, "Westview counselors, 24/7 crisis lines, and safety "
           "reporting (works offline).", W - 120, size=10, line_h=12)
    y += 76

    for title, sub, on in [
        ("Quick exit", "Long-press any Help button to leave the app right away.", True),
        ("Hide preview in app switcher", "Blanks out the last screen in Android recent apps.", True),
    ]:
        c.rect(16, y, W - 32, 72, "surfaceContainerLow", radius=12)
        c.text(64, y + 28, title, size=14, color="onSurface")
        c.wrap(64, y + 46, sub, W - 150, size=10, line_h=12)
        # switch
        track = "primary" if on else "surfaceContainerHighest"
        c.rect(W - 76, y + 24, 44, 24, track, radius=12,
               stroke=None if on else "outline")
        c.circle(W - 76 + (32 if on else 12), y + 36, 8,
                 "onPrimary" if on else "outline")
        y += 84

    # Language row, titled with every language name so it stays findable.
    c.rect(16, y, W - 32, 72, "surfaceContainerLow", radius=12)
    c.icon(40, y + 36, "globe", color="onSurfaceVariant", size=10)
    c.text(64, y + 26, "English \u00b7 Espa\u00f1ol \u00b7 \u4e2d\u6587 \u00b7 "
           "Filipino \u00b7 Fran\u00e7ais", size=12, color="onSurface")
    c.text(64, y + 46, "System default", size=10, color="onSurfaceVariant")
    c.icon(W - 34, y + 36, "chevron", color="onSurfaceVariant", size=8)
    y += 96

    c.text(16, y + 10, "SAVED CONTENT", size=11, color="primary", bold=True)
    y += 24
    c.rect(16, y, W - 32, 72, "surfaceContainerLow", radius=12)
    c.icon(40, y + 36, "download", color="onSurfaceVariant", size=10)
    c.text(64, y + 26, "Clear saved content", size=14, color="onSurface")
    c.wrap(64, y + 44, "Removes cached calendars, lunch menus, and nutrition "
           "data so they download fresh next time.", W - 150, size=10, line_h=12)
    return c




# ------------------------------------------------------- Spanish Get help
def get_help_screen_es(kind: str | None = None) -> Canvas:
    """Spanish Get help layout, verifying that ~20% longer text wraps cleanly."""
    c = Canvas(W, 1200, kind)
    c.rect(0, 0, W, 56, "primaryContainer")
    c.text(16, 35, "Ayuda", size=20, color="onPrimaryContainer", bold=True)
    c.icon(W - 28, 28, "globe", color="onPrimaryContainer", size=9)

    x, w = 12, W - 24
    y = 72
    inner_x, inner_w = x + 16, w - 32
    body = ("Llama al 911 ahora si t\u00fa o alguien m\u00e1s corre peligro de salir "
            "herido, o si necesitas ayuda de emergencia de inmediato.")
    body_h = len(_wrap_lines(body, inner_w, 13)) * 19
    h = 16 + 20 + 8 + body_h + 10 + 56 + 10 + 3 * 17 + 16
    c.rect(x, y, w, h, "errorContainer", radius=12)
    c.icon(inner_x + 9, y + 26, "warn", color="onErrorContainer", size=10)
    c.text(inner_x + 24, y + 31, u"\u00bfPeligro inmediato?", size=15,
           color="onErrorContainer", bold=True)
    cy = _paragraph(c, inner_x, y + 52, body, inner_w, size=13,
                    color="onErrorContainer")
    # 56dp button height for the primary emergency action.
    c.button(inner_x, cy + 4, inner_w, 56, "Llamar al 911", style="filled",
             kind="phone")
    _paragraph(c, inner_x, cy + 72,
               "Si no sabes con seguridad si es una emergencia, llama o env\u00eda "
               "un texto al 988 para hablar con un consejero sobre qu\u00e9 hacer.",
               inner_w, size=11, color="onErrorContainer")
    y += h + 22

    c.section_title(12, y, u"L\u00edneas de crisis gratuitas 24/7", "warn")
    y += 20
    # Deaf/HoH note placed above the phone numbers.
    note = ("\u00bfSordo, con p\u00e9rdida auditiva o sin poder hablar en voz alta? "
            "Todos los servicios de abajo funcionan por texto o chat en l\u00ednea. "
            "El 988 y Crisis Text Line funcionan por mensaje de texto, y la "
            "l\u00ednea del Condado de San Diego est\u00e1 disponible mediante el 711.")
    lines = _wrap_lines(note, w - 40, 11)
    c.icon(24, y + 6, "help", color="onSurfaceVariant", size=7)
    ny = _paragraph(c, 40, y, note, w - 52, size=11, line_h=15)
    y = ny + 10

    for name, desc, action in [
        ("988 Suicide & Crisis Lifeline", "Llama o env\u00eda un texto al 988.", "Llamar al 988"),
        ("San Diego Access & Crisis Line",
         "Condado de San Diego \u00b7 24/7 \u00b7 int\u00e9rpretes en m\u00e1s de 200 idiomas.",
         "Llamar al 1-888-724-7240"),
        ("Crisis Text Line", "Env\u00eda HOLA al 741741.", "Enviar texto"),
    ]:
        card_h = 16 + 20 + 15 * 2 + 12 + 44 + 16
        c.card(12, y, w, card_h)
        c.text(28, y + 24, name, size=14, color="onSurface", bold=True)
        c.wrap(28, y + 42, desc, w - 32, size=11, line_h=15)
        c.button(28, y + card_h - 60, inner_w, 44, action, style="tonal",
                 kind="phone")
        y += card_h + 10
    return c


def _wrap_lines(text, max_w, size=13, bold=False):
    words, line, lines = text.split(), "", []
    for word in words:
        candidate = f"{line} {word}".strip()
        if not line or measure(candidate, size, bold) <= max_w:
            line = candidate
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


# ------------------------------------------------------ language picker
def language_picker_screen(kind: str | None = None) -> Canvas:
    """Settings language row with the bottom-sheet picker open."""
    c = Canvas(W, 780, kind)
    c.rect(0, 0, W, 56, "primaryContainer")
    c.text(16, 35, "Settings", size=20, color="onPrimaryContainer", bold=True)

    y = 76
    c.text(16, y, "SAFETY", size=11, color="primary", bold=True)
    y += 14
    c.rect(16, y, W - 32, 76, "surfaceContainerLow", radius=12)
    c.icon(40, y + 38, "help", color="onSurfaceVariant", size=10)
    c.text(64, y + 30, "Get help now", size=14, color="onSurface")
    c.wrap(64, y + 48, "Westview counselors, 24/7 crisis lines, and safety "
           "reporting (works offline).", W - 120, size=10, line_h=12)
    y += 88

    # dimmed backdrop
    c.rect(0, y - 8, W, 430, "surfaceContainerHighest")
    sheet_y = y + 60
    c.rect(0, sheet_y, W, 410, "surfaceContainerLow", radius=24)
    c.rect(W / 2 - 18, sheet_y + 10, 36, 4, "outlineVariant", radius=2)
    c.text(16, sheet_y + 42, "App language", size=15, color="onSurface",
           bold=True)
    rows = [
        ("System default", "English \u00b7 Espa\u00f1ol \u00b7 \u4e2d\u6587 \u00b7 "
                           "Filipino \u00b7 Fran\u00e7ais", True),
        ("English", "English \u00b7 Ingl\u00e9s \u00b7 \u82f1\u8bed \u00b7 "
                    "Ingles \u00b7 Anglais", False),
        ("Espa\u00f1ol", "Espa\u00f1ol \u00b7 Spanish \u00b7 \u897f\u73ed\u7259\u8bed \u00b7 "
                         "Espanyol \u00b7 Espagnol", False),
        ("\u7b80\u4f53\u4e2d\u6587", "\u7b80\u4f53\u4e2d\u6587 \u00b7 Chinese \u00b7 Chino \u00b7 "
                                        "Tsino \u00b7 Chinois", False),
        ("Filipino", "Filipino \u00b7 Tagalog \u00b7 \u83f2\u5f8b\u5bbe\u8bed \u00b7 "
                     "Filipino \u00b7 Philippin", False),
        ("Fran\u00e7ais", "Fran\u00e7ais \u00b7 French \u00b7 Franc\u00e9s \u00b7 "
                          "\u6cd5\u8bed \u00b7 Pranses", False),
    ]
    ry = sheet_y + 60
    for name, sub, selected in rows:
        if selected:
            c.rect(8, ry - 4, W - 16, 48, "secondaryContainer", radius=10)
        c.text(20, ry + 16, name, size=14, color="onSurface",
               bold=selected)
        c.text(20, ry + 32, sub, size=9, color="onSurfaceVariant")
        if selected:
            c.icon(W - 30, ry + 20, "check", color="primary", size=8)
        ry += 52
    # The mockup environment has no CJK font, so the Chinese glyphs in the
    # labels above did not render. Say so instead of leaving a silent gap.
    c.text(20, ry + 8, "(Chinese glyphs omitted: no CJK font in this mockup "
           "environment.)", size=9, color="onSurfaceVariant")
    return c


# ------------------------------------------------------------------- export
def palette_sheet() -> None:
    """Chips showing the brand and semantic colors under each CVD type."""
    kinds = [None, "deutan", "protan", "tritan"]
    names = ["primary", "primaryContainer", "secondaryContainer",
             "error", "errorContainer", "surfaceContainerLow"]
    chip_w, chip_h, pad = 120, 56, 12
    width = pad + len(names) * (chip_w + pad)
    height = 40 + len(kinds) * (chip_h + pad + 22)
    c = Canvas(width, height, None)
    c.rect(0, 0, width, height, "surface")
    labels = ["Normal vision", "Deuteranopia", "Protanopia", "Tritanopia"]
    for row, kind in enumerate(kinds):
        y = 16 + row * (chip_h + pad + 22)
        c.text(pad, y + 12, labels[row], size=13, color="onSurface", bold=True)
        for col, token in enumerate(names):
            x = pad + col * (chip_w + pad)
            r, g, b = simulate_cvd(L[token], kind)
            c.ops.append(
                f"fill '#{r:02X}{g:02X}{b:02X}' stroke '#{hexc('outlineVariant')[1:]}' "
                f"stroke-width 1 roundrectangle {c._p(x)},{c._p(y + 20)} "
                f"{c._p(x + chip_w)},{c._p(y + 20 + chip_h)} 8,8"
            )
            if row == 0:
                c.text(x + 6, y + 20 + chip_h + 12, token, size=8,
                       color="onSurfaceVariant")
    c.save(OUT / "palette-simulated.png")


def main() -> None:
    get_help_screen().save(OUT / "get-help-1.png")
    get_help_screen_2().save(OUT / "get-help-2.png")
    home_screen().save(OUT / "home-with-help.png")
    settings_screen().save(OUT / "settings-safety.png")
    get_help_screen("deutan").save(OUT / "get-help-deuteranopia.png")
    get_help_screen_es().save(OUT / "get-help-spanish.png")
    language_picker_screen().save(OUT / "language-picker.png")
    palette_sheet()


if __name__ == "__main__":
    main()
