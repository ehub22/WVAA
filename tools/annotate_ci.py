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

    # 2. Failing tests: the "Expected/Actual" block after a [E] marker.
    failures = 0
    for i, line in enumerate(lines):
        if not re.search(r"\[E\]$", line.strip()):
            continue
        failures += 1
        name = line.strip().removesuffix("[E]").strip()
        detail: list[str] = []
        for follow in lines[i + 1 : i + 12]:
            stripped = follow.strip()
            if re.match(r"^\d\d:\d\d \+\d+.*\[E\]$", stripped):
                break
            if stripped.startswith(("package:", "test/", "dart:")):
                detail.append(stripped)
                continue
            if detail or any(
                key in stripped
                for key in ("Expected:", "Actual:", "Which:", "Exception:",
                            "The following", "══╡")
            ):
                detail.append(stripped)
            if len(detail) >= 6:
                break
        annotate("error", f"test failed: {name}"[:180],
                 "\n".join(detail)[:MAX_LEN] or "see the step log")

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
