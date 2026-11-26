#!/usr/bin/env python3
"""Structural check for lib/l10n/strings.dart.

Because `lib/l10n/strings.dart` is a large hand-edited Dart map, a missing comma
or stray `$` turns into a vague Dart compiler failure later in CI. This script
parses each language block directly and reports exact line numbers right away.

Checks:
  * every entry is `'key': 'value',` or `'key':` followed by indented adjacent
    string literals ending in a comma;
  * keys are unique within each language;
  * all four languages (`en`, `es`, `zh`, `tl`) define the exact same key set;
  * no empty values, no tab characters, and no `$` interpolation characters.

Usage: python3 tools/check_strings.py
Exit code 1 on any problem.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STRINGS_FILE = ROOT / "lib" / "l10n" / "strings.dart"
LANGUAGES = ["en", "es", "zh", "tl"]

ENTRY = re.compile(r"^    '([^']+)':(.*)$")
OPEN_STRING = re.compile(r"""^(\s*)('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")\s*(,?)\s*$""")
CONTINUED = re.compile(r"""^        ('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")$""")


def strip_comment(line: str) -> str:
    """Remove a trailing // comment that is not inside a string literal."""
    out = []
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\":
                out.append(line[i + 1 : i + 2])
                i += 2
                continue
            if ch == quote:
                quote = None
        else:
            if ch in "'\"":
                quote = ch
                out.append(ch)
            elif line.startswith("//", i):
                break
            else:
                out.append(ch)
        i += 1
    return "".join(out)


def language_blocks(text: str) -> dict[str, list[tuple[int, str]]]:
    blocks: dict[str, list[tuple[int, str]]] = {}
    current = None
    depth = 0
    for number, raw in enumerate(text.splitlines(), 1):
        line = strip_comment(raw)
        start = re.match(r"^  '([a-z]{2})': \{$", line)
        if start and current is None:
            current = start.group(1)
            blocks[current] = []
            depth = 1
            continue
        if current is not None:
            if line.startswith("  },"):
                current = None
                depth = 0
                continue
            blocks[current].append((number, line))
    return blocks


def parse_block(
    name: str, lines: list[tuple[int, str]]
) -> tuple[dict[str, str], list[str]]:
    """Parse one language map.

    Keys sit at four spaces of indent; continuation lines (implicit string
    concatenation) are indented further. Anything else is a mistake.
    """
    problems: list[str] = []
    values: dict[str, str] = {}
    index = 0
    total = len(lines)

    def literal(text: str) -> str:
        """Return the parts of every adjacent string literal in `text`."""
        parts = re.findall(r"'((?:\\.|[^'\\])*)'", text)
        if not parts:
            parts = re.findall(r'"((?:\\.|[^"\\])*)"', text)
        return "".join(parts)

    while index < total:
        number, line = lines[index]
        if not line.strip():
            index += 1
            continue
        match = re.match(r"^    '([^']+)':(.*)$", line)
        if not match:
            problems.append(
                f"{name}:{number}: expected a key at 4 spaces, found {line.strip()!r}"
            )
            index += 1
            continue
        key, rest = match.group(1), match.group(2)

        chunk = [rest] if rest.strip() else []
        last_line = number
        last_text = line
        index += 1
        while index < total:
            n2, l2 = lines[index]
            if not l2.strip():
                index += 1
                continue
            if re.match(r"^    '", l2):
                break
            if not l2.startswith("        "):
                problems.append(
                    f"{name}:{n2}: odd indentation inside {key!r}: {l2.strip()!r}"
                )
            chunk.append(l2)
            last_line, last_text = n2, l2
            index += 1

        joined = " ".join(part.strip() for part in chunk)
        value = literal(joined)
        if not joined.strip():
            problems.append(f"{name}:{number}: {key!r} has no value")
        elif not last_text.strip().endswith(","):
            problems.append(f"{name}:{last_line}: {key!r} is missing a trailing comma")
        if key in values:
            problems.append(f"{name}:{number}: duplicate key {key!r}")
        values[key] = value
    return values, problems


def main() -> int:
    text = STRINGS_FILE.read_text()
    blocks = language_blocks(text)
    problems: list[str] = []

    missing = [lang for lang in LANGUAGES if lang not in blocks]
    if missing:
        problems.append(f"string catalog languages not found: {missing}")
        print("\n".join(problems))
        return 1

    parsed: dict[str, dict[str, str]] = {}
    for lang in LANGUAGES:
        values, block_problems = parse_block(lang, blocks[lang])
        parsed[lang] = values
        problems.extend(block_problems)

    english = set(parsed["en"])
    for lang in LANGUAGES[1:]:
        missing_keys = english - set(parsed[lang])
        extra_keys = set(parsed[lang]) - english
        if missing_keys:
            problems.append(f"{lang} is missing {len(missing_keys)} keys: {sorted(missing_keys)[:12]}")
        if extra_keys:
            problems.append(f"{lang} has {len(extra_keys)} unknown keys: {sorted(extra_keys)[:12]}")

    for lang, values in parsed.items():
        for key, value in values.items():
            if not value.strip():
                problems.append(f"{lang}: {key!r} has an empty value")
            if "$" in value:
                problems.append(
                    f"{lang}: {key!r} contains '$', which Dart would interpolate"
                )
            if "\t" in value:
                problems.append(f"{lang}: {key!r} contains a tab")

    if problems:
        print(f"{len(problems)} problem(s) in {STRINGS_FILE.relative_to(ROOT)}:")
        for problem in problems:
            print("  -", problem)
        return 1

    print(
        f"ok: {len(english)} keys x {len(LANGUAGES)} languages "
        f"({', '.join(LANGUAGES)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
