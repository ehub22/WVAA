#!/usr/bin/env python3
"""Turn a `flutter test` / `flutter analyze` log into GitHub annotations.

Why this exists: the raw step log is a 30 MB download from a storage host that
some review environments cannot reach, while *annotations* are small and
available through the check-run API. So the CI step pipes output here and this
script prints one `::error` per distinct failure, which is then readable with:

    gh api repos/OWNER/REPO/check-runs/<id>/annotations

Usage:
    flutter test --reporter expanded > /tmp/test.log 2>&1 || true
    python3 tools/annotate_ci.py /tmp/test.log test

Exit code is always 0 — the calling step re-exits with the command's own status.
"""

from __future__ import annotations

import pathlib
import re
import sys

MAX_ANNOTATIONS = 25
MAX_LEN = 900


def escape(text: str) -> str:
    """GitHub workflow-command escaping."""
    return (
        text.replace("%", "%25")
        .replace("\r", "")
        .replace("\n", "%0A")
    )


def annotate(level: str, title: str, message: str) -> None:
    print(f"::{level} title={escape(title)}::{escape(message)}")


def test_annotations(text: str) -> None:
    lines = text.splitlines()

    # 1. Compile errors: "Error: ..." points at the real problem, everything
    #    else in the log is noise.
    compile_errors: list[str] = []
    for i, line in enumerate(lines):
        if line.startswith("Error: ") or " Error: " in line:
            context = [line.strip()]
            # The following two lines usually hold the file:line reference.
            for follow in lines[i + 1 : i + 3]:
                if re.search(r"\.dart:\d+:\d+", follow):
                    context.append(follow.strip())
            compile_errors.append(" | ".join(context))
    for message in compile_errors[:MAX_ANNOTATIONS]:
        annotate("error", "compile error", message[:MAX_LEN])

    # 2. Failing tests. The expanded reporter writes
    #        00:09 +107 -3: /path/test/foo_test.dart: name [E]
    #        <detail lines...>
    #        00:09 +107 -3: Next test...
    # so collect every line between a failure header and the next progress
    # line, without trying to pattern-match the detail itself.
    progress = re.compile(r"^\d\d:\d\d \+\d+")
    failures = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.endswith("[E]"):
            continue
        failures += 1
        name = stripped.split(": ", 1)[-1].removesuffix("[E]").strip()
        detail: list[str] = []
        for follow in lines[i + 1 : i + 40]:
            nxt = follow.strip()
            if progress.match(nxt) or nxt.endswith("[E]"):
                break
            if nxt:
                detail.append(nxt)
            elif detail:
                break
        annotate(
            "error",
            f"test failed ({failures}): {name}"[:200],
            "\n".join(detail)[:MAX_LEN] or "no detail captured",
        )

    # 2b. The expanded reporter prints the actual exception *before* the
    # "[E]" line ("Test failed. See exception logs above."), so capture those
    # blocks directly: they are the only place the real reason appears.
    blocks: list[str] = []
    for i, line in enumerate(lines):
        if not re.search(r"(EXCEPTION CAUGHT|The following .* was thrown)", line):
            continue
        block = [line.strip()]
        for follow in lines[i + 1 : i + 14]:
            if re.match(r"^\d\d:\d\d \+\d+", follow.strip()):
                break
            if follow.strip():
                block.append(follow.strip())
        blocks.append(" | ".join(block))
    for index, block in enumerate(blocks[:6], start=1):
        annotate("error", f"exception {index}", block[:MAX_LEN])

    # 3. A one-line summary so the count is visible in the check list.
    summary = next(
        (ln.strip() for ln in reversed(lines) if re.search(r"\+\d+.*(-\d+)?", ln)),
        "",
    )
    if summary:
        annotate("notice", "test summary", summary[:MAX_LEN])


def build_annotations(text: str) -> None:
    """Dart/Gradle build failures.

    `flutter build` prints Dart compile errors as
        lib/foo.dart:12:5: Error: ...
    and Gradle failures as lines containing "FAILURE:" or "Caused by:".
    """
    dart_error = re.compile(
        r"^(?P<path>[\w./-]+\.dart):(?P<line>\d+):(?P<col>\d+): "
        r"Error: (?P<msg>.+)$"
    )
    seen = 0
    for line in text.splitlines():
        match = dart_error.match(line.strip())
        if match:
            seen += 1
            if seen > MAX_ANNOTATIONS:
                continue
            annotate(
                "error",
                f"{match.group('path')}:{match.group('line')}:{match.group('col')}",
                match.group("msg")[:MAX_LEN],
            )
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("FAILURE:") or stripped.startswith("Caused by:"):
            annotate("error", "gradle", stripped[:MAX_LEN])
    if seen == 0 and "FAILURE:" not in text:
        tail = "\n".join(text.splitlines()[-12:])
        annotate("error", "build failed", tail[:MAX_LEN])


def analyze_annotations(text: str) -> None:
    pattern = re.compile(r"^\s*(error|warning|info)\s+•\s+(.+?)\s+•\s+(.+?):(\d+):(\d+)\s+•\s+(.+)$")
    count = 0
    for line in text.splitlines():
        match = pattern.match(line)
        if not match:
            continue
        severity, message, path, line_no, col, code = match.groups()
        if severity != "error":
            continue
        count += 1
        if count > MAX_ANNOTATIONS:
            break
        annotate(
            "error",
            f"{path}:{line_no}:{col} [{code}]",
            message,
        )
    if count == 0:
        annotate("notice", "flutter analyze", "no errors")


def main() -> int:
    if len(sys.argv) < 3:
        print(
        "usage: annotate_ci.py <logfile> <test|analyze|build>", file=sys.stderr
    )
        return 0
    path = pathlib.Path(sys.argv[1])
    if not path.exists():
        annotate("warning", "annotate_ci", f"{path} not found")
        return 0
    text = path.read_text(errors="replace")
    mode = sys.argv[2]
    if mode == "analyze":
        analyze_annotations(text)
    elif mode == "build":
        build_annotations(text)
    else:
        test_annotations(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
