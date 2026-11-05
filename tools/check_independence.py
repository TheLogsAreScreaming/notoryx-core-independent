#!/usr/bin/env python3
"""Fails if this repository contains code copied from meshcore-open.

Usage: check_independence.py <meshcore-open checkout> [repo root]

Two checks:
  1. Banned names that only appear in code taken from meshcore-open.
  2. Copied blocks: any run of WINDOW consecutive significant lines that
     also appears, in order, in a meshcore-open source file.

Lines are compared after removing all whitespace, and short lines (closing
braces, `@override`, bare imports) are ignored, so formatting changes don't
hide a copy and common boilerplate doesn't trigger one. Known false
positives go in tools/independence_allowlist.txt, one `path:line` per row.
"""

import hashlib
import re
import sys
from pathlib import Path

WINDOW = 5
MIN_CHARS = 24
SCAN_DIRS = ("lib", "test", "tools")
SUFFIXES = {".dart", ".arb", ".kt", ".swift", ".py", ".sh"}
BANNED = re.compile(r"meshcore_open|meshcore-open|zjs81|MeshCore Open", re.I)
SELF = Path(__file__).name


def significant(text):
    out = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = re.sub(r"\s+", "", raw)
        if len(line) < MIN_CHARS or line.startswith(("import'", "export'", "//")):
            continue
        out.append((number, line))
    return out


def windows(lines):
    for i in range(len(lines) - WINDOW + 1):
        chunk = "\n".join(line for _, line in lines[i : i + WINDOW])
        yield lines[i][0], hashlib.sha1(chunk.encode()).hexdigest()


def source_files(root, dirs):
    for d in dirs:
        base = root / d
        if base.is_dir():
            for path in sorted(base.rglob("*")):
                if path.suffix in SUFFIXES and path.is_file():
                    yield path


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    upstream = Path(sys.argv[1]).resolve()
    root = Path(sys.argv[2] if len(sys.argv) > 2 else ".").resolve()

    allow_file = root / "tools" / "independence_allowlist.txt"
    allowed = set()
    if allow_file.exists():
        allowed = {
            row.strip()
            for row in allow_file.read_text().splitlines()
            if row.strip() and not row.startswith("#")
        }

    known = {}
    for path in source_files(upstream, ("lib", "test", "android", "ios", "macos")):
        text = path.read_text(errors="ignore")
        for _, digest in windows(significant(text)):
            known.setdefault(digest, path.relative_to(upstream))

    problems = []
    for path in source_files(root, SCAN_DIRS):
        rel = path.relative_to(root)
        if path.name == SELF:
            continue
        text = path.read_text(errors="ignore")
        for number, raw in enumerate(text.splitlines(), 1):
            if BANNED.search(raw) and f"{rel}:{number}" not in allowed:
                problems.append(f"{rel}:{number}: banned name: {raw.strip()}")
        for number, digest in windows(significant(text)):
            if digest in known and f"{rel}:{number}" not in allowed:
                problems.append(f"{rel}:{number}: matches meshcore-open {known[digest]}")

    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} problem(s): code from meshcore-open is not allowed here.")
        sys.exit(1)
    print("OK: no meshcore-open code found.")


if __name__ == "__main__":
    main()
