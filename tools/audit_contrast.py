#!/usr/bin/env python3
"""Offline accessibility audit for the WVAA palettes.

Checks two things that a screenshot cannot:

1. WCAG 2.1 contrast for every text/background pair the app actually paints.
2. Colour-vision-deficiency (CVD) separation for the one place the UI uses
   colour to carry meaning: the "this period is happening now" card
   (primaryContainer) versus an ordinary period card (surfaceContainerLow).

Run from the repo root:  python3 tools/audit_contrast.py [--strict]
Exits non-zero under --strict if any pair fails, so CI can enforce it.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path

COLORS_DART = Path(__file__).resolve().parent.parent / "lib/theme/colors.dart"

# (label, foreground token, background token, minimum ratio)
PAIRS = [
    # Body and headings
    ("body on surface", "onSurface", "surface", 4.5),
    ("body on lowest surface", "onSurface", "surfaceContainerLowest", 4.5),
    ("body on low surface", "onSurface", "surfaceContainerLow", 4.5),
    ("body on container", "onSurface", "surfaceContainer", 4.5),
    ("body on high surface", "onSurface", "surfaceContainerHigh", 4.5),
    ("body on highest surface", "onSurface", "surfaceContainerHighest", 4.5),
    ("body on background", "onSurface", "background", 4.5),
    ("secondary text on surface", "onSurfaceVariant", "surface", 4.5),
    ("secondary text on low surface", "onSurfaceVariant", "surfaceContainerLow", 4.5),
    ("secondary text on highest surface", "onSurfaceVariant", "surfaceContainerHighest", 4.5),
    # Primary / containers
    ("onPrimary on primary", "onPrimary", "primary", 4.5),
    ("primary on surface (links/labels)", "primary", "surface", 4.5),
    ("primary on low surface (links)", "primary", "surfaceContainerLow", 4.5),
    ("primary on background", "primary", "background", 4.5),
    ("onPrimaryContainer on primaryContainer", "onPrimaryContainer", "primaryContainer", 4.5),
    ("onSecondaryContainer on secondaryContainer", "onSecondaryContainer", "secondaryContainer", 4.5),
    ("onTertiaryContainer on tertiaryContainer", "onTertiaryContainer", "tertiaryContainer", 4.5),
    # Errors (911 card, banners)
    ("onError on error", "onError", "error", 4.5),
    ("onErrorContainer on errorContainer", "onErrorContainer", "errorContainer", 4.5),
    # Inverse (snackbars)
    ("onInverseSurface on inverseSurface", "onInverseSurface", "inverseSurface", 4.5),
    # Non-text: icons/dividers against their surfaces (WCAG 1.4.11 -> 3.0)
    ("outline on surface (icons/borders)", "outline", "surface", 3.0),
    ("outlineVariant on surface (dividers)", "outlineVariant", "surface", 1.0),
]

# CVD transforms: sRGB -> LMS (Hunt-Pointer-Estevez, D65) -> dichromat
# projection (Viénot, Brettel & Mollon 1999) -> back to sRGB.
RGB_TO_LMS = [
    [0.31399022, 0.63951294, 0.04649755],
    [0.15537241, 0.75789446, 0.08670142],
    [0.01775239, 0.10944209, 0.87256922],
]
LMS_TO_RGB = [
    [5.47221206, -4.6419601, 0.16963708],
    [-1.1252419, 2.29317094, -0.1678952],
    [0.02980165, -0.19318073, 1.16364789],
]
# Projections that collapse the missing cone's axis.
DEUTAN = [[1, 0, 0], [0.9513092, 0, 0.04866992], [0, 0, 1]]
PROTAN = [[0, 1.05118294, -0.05116099], [0, 1, 0], [0, 0, 1]]
TRITAN = [[1, 0, 0], [0, 1, 0], [-0.86744736, 1.86727089, 0]]


def parse_tokens() -> dict[str, dict[str, tuple[int, int, int]]]:
    """Reads every `const nameBrightness = Color(0xAARRGGBB);` from colors.dart."""
    text = COLORS_DART.read_text()
    tokens: dict[str, dict[str, tuple[int, int, int]]] = {}
    for match in re.finditer(
        r"const\s+(\w+?)(Light|Dark)\s*=\s*Color\(0x[0-9A-Fa-f]{2}([0-9A-Fa-f]{6})\)", text
    ):
        name, mode, hexrgb = match.groups()
        rgb = tuple(int(hexrgb[i:i + 2], 16) for i in (0, 2, 4))
        bucket = tokens.setdefault(mode.lower(), {})
        bucket[name] = rgb  # type: ignore[assignment]
        # `inverseOnSurface` is spelled `inverseOnSurfaceX` in colors.dart while
        # the ColorScheme role is `onInverseSurface`; register both spellings.
        if name.startswith("inverseOn"):
            bucket["onInverse" + name[len("inverseOn"):]] = rgb  # type: ignore[assignment]
    return tokens


# ----------------------------------------------------------------- primitives
def _srgb_to_linear(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(c: float) -> float:
    v = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return max(0.0, min(1.0, v)) * 255.0


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    r, g, b = (_srgb_to_linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = relative_luminance(a), relative_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def _matmul(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]


def simulate_cvd(rgb: tuple[int, int, int], kind: str | None) -> tuple[int, int, int]:
    if kind is None:
        return rgb
    lin = [_srgb_to_linear(c) for c in rgb]
    lms = _matmul(RGB_TO_LMS, lin)
    proj = {"deutan": DEUTAN, "protan": PROTAN, "tritan": TRITAN}[kind]
    sim = _matmul(LMS_TO_RGB, _matmul(proj, lms))
    return tuple(int(round(_linear_to_srgb(max(0.0, min(1.0, c))))) for c in sim)  # type: ignore[return-value]


def _to_lab(rgb: tuple[int, int, int]):
    r, g, b = (_srgb_to_linear(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 1.00000
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e_76(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, aa, ba = _to_lab(a)
    lb, ab, bb = _to_lab(b)
    return math.dist((la, aa, ba), (lb, ab, bb))


# ----------------------------------------------------------------------- main
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="fail on any violation")
    parser.add_argument(
        "--delta-e-min",
        type=float,
        default=10.0,
        help="minimum ΔE(76) between the 'now' card and a normal card under CVD "
             "(below this the difference is effectively colour-only)",
    )
    args = parser.parse_args()

    tokens = parse_tokens()
    failures = 0

    for mode in ("light", "dark"):
        t = tokens[mode]
        print(f"\n=== {mode.upper()} theme ===")
        for label, fg, bg, minimum in PAIRS:
            if fg not in t or bg not in t:
                print(f"  ?  {label}: missing token ({fg}/{bg})")
                continue
            ratio = contrast_ratio(t[fg], t[bg])
            ok = ratio >= minimum
            if not ok:
                failures += 1
            flag = "PASS" if ok else "FAIL"
            note = "" if minimum > 1.0 else " (informational)"
            print(f"  {flag} {label:<48} {ratio:5.2f}:1  (min {minimum}){note}")

        # Colour-only meaning check: the current-period card vs a normal card.
        highlights = t["primaryContainer"]
        normal = t["surfaceContainerLow"]
        print("  --- 'now' card vs normal card (colour-only check) ---")
        for kind in (None, "deutan", "protan", "tritan"):
            h = simulate_cvd(highlights, kind)
            n = simulate_cvd(normal, kind)
            d = delta_e_76(h, n)
            label = "normal vision" if kind is None else f"{kind}opia"
            ok = d >= args.delta_e_min
            if not ok:
                failures += 1
            print(f"  {'PASS' if ok else 'FAIL'} {label:<14} ΔE={d:5.1f}"
                  f"  (min {args.delta_e_min})")
            if not ok:
                print("        -> colour alone cannot convey 'now'; keep the "
                      "explicit label/icon cue on the card.")

    print()
    if failures:
        print(f"{failures} accessibility problem(s) found.")
    else:
        print("All checked pairs meet their targets.")
    return 1 if (failures and args.strict) else 0


if __name__ == "__main__":
    sys.exit(main())
