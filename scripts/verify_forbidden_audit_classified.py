#!/usr/bin/env python3
"""Verify forbidden-string audit output is classified in the rollout checklist.

Usage:
  python3 scripts/verify_forbidden_audit_classified.py --self-test
  python3 scripts/verify_forbidden_audit_classified.py <raw-audit-file> <checklist.md>

The raw audit file is expected to contain ripgrep-style lines:
  path:line:matched content

Each non-empty raw hit must be represented by a checklist table row whose
file/path cell and matched-string cell are compatible with the raw hit. Rows
classified as normal-ui-blocker or forbidden fail the gate.
"""

from __future__ import annotations

import argparse
import fnmatch
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

BLOCKING_CATEGORIES = {"normal-ui-blocker", "forbidden"}
ALLOWED_CATEGORIES = {
    "internal",
    "diagnostics",
    "legal",
    "generated",
    "icon",
    "icon/constant",
    "constant",
    "allowed-test-doc-only",
}


@dataclass(frozen=True)
class AuditHit:
    raw: str
    path: str
    line: str
    text: str


@dataclass(frozen=True)
class Classification:
    file_cell: str
    match_cell: str
    category: str
    raw_row: str


def split_markdown_row(line: str) -> list[str]:
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return []
    return [cell.strip().replace("`", "") for cell in stripped.strip("|").split("|")]


def normalize_category(value: str) -> str:
    return value.strip().lower().replace(" ", "-")


def is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c.replace(" ", "")) for c in cells)


def parse_checklist(path: Path) -> list[Classification]:
    rows: list[Classification] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        cells = split_markdown_row(line)
        if len(cells) < 6 or is_separator(cells):
            continue
        header = [c.lower() for c in cells]
        if "phase" in header[:1] or "category" in header:
            continue
        category = normalize_category(cells[4])
        if category in BLOCKING_CATEGORIES or category in ALLOWED_CATEGORIES:
            rows.append(
                Classification(
                    file_cell=cells[1],
                    match_cell=cells[2],
                    category=category,
                    raw_row=line.strip(),
                )
            )
    return rows


def parse_hit(raw: str) -> AuditHit | None:
    if not raw.strip():
        return None
    # ripgrep format: path:line:text. Windows drive letters are not expected in repo-relative audit files.
    parts = raw.split(":", 2)
    if len(parts) == 3 and parts[1].isdigit():
        return AuditHit(raw=raw, path=parts[0].replace("\\\\", "/"), line=parts[1], text=parts[2])
    # Fallback: keep line as text but still require checklist classification.
    return AuditHit(raw=raw, path="", line="", text=raw)


def cell_tokens(value: str) -> list[str]:
    value = value.strip()
    if not value or value in {"--", "-", "none"}:
        return []
    raw_tokens = re.split(r"\s+(?:/|or|和|及|,|，)\s+|\s*;\s*", value)
    tokens: list[str] = []
    for token in raw_tokens:
        token = token.strip().strip(".")
        if token:
            tokens.append(token)
    return tokens


def path_matches(file_cell: str, hit_path: str) -> bool:
    if not hit_path:
        return True
    tokens = cell_tokens(file_cell)
    if not tokens:
        return False
    for token in tokens:
        token = token.replace("\\\\", "/")
        if token in {"existing dirty tree", "task-owned diff"}:
            continue
        # Drop optional :line suffix in checklist cell.
        token_path = token.split(":", 1)[0]
        patterns = {token_path, token_path.replace("*", "**")}
        for pattern in patterns:
            if fnmatch.fnmatch(hit_path, pattern) or hit_path.startswith(pattern.rstrip("*")):
                return True
            if pattern in hit_path or hit_path in pattern:
                return True
    return False


def text_matches(match_cell: str, hit_text: str) -> bool:
    tokens = cell_tokens(match_cell)
    if not tokens:
        return False
    lowered = hit_text.lower()
    for token in tokens:
        token_l = token.lower()
        if token_l in {"*", "n/a", "none"}:
            continue
        if token_l in lowered:
            return True
        # Treat slash-separated alternatives inside one cell, e.g. http/https/tg/mailto.
        for alt in re.split(r"/", token_l):
            if alt and alt in lowered:
                return True
    return False


def classify(hit: AuditHit, rows: list[Classification]) -> Classification | None:
    for row in rows:
        if path_matches(row.file_cell, hit.path) and text_matches(row.match_cell, hit.text):
            return row
    # Some checklist rows intentionally classify a path/surface rather than exact literal.
    for row in rows:
        if path_matches(row.file_cell, hit.path):
            return row
    return None


def verify(raw_audit: Path, checklist: Path, quiet: bool = False) -> int:
    rows = parse_checklist(checklist)
    raw_hits = [parse_hit(line) for line in raw_audit.read_text(encoding="utf-8").splitlines()]
    hits = [hit for hit in raw_hits if hit is not None]
    failures: list[str] = []
    for hit in hits:
        row = classify(hit, rows)
        if row is None:
            failures.append(f"UNCLASSIFIED: {hit.raw}")
            continue
        if row.category in BLOCKING_CATEGORIES:
            failures.append(f"BLOCKER({row.category}): {hit.raw} <= {row.raw_row}")
    if failures:
        if not quiet:
            print("Forbidden audit classification failed:", file=sys.stderr)
            for failure in failures:
                print(f"- {failure}", file=sys.stderr)
        return 1
    if not quiet:
        print(f"Forbidden audit classification passed: {len(hits)} hit(s), {len(rows)} classification row(s).")
    return 0


def self_test() -> int:
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        checklist = base / "checklist.md"
        audit = base / "audit.txt"
        checklist.write_text(
            """
| Phase | file:line | Matched string | Surface | Category | Rationale | Action/blocker |
| --- | --- | --- | --- | --- | --- | --- |
| Phase X | lib/ui/login.dart | 用户协议 | legal link | legal | allowed legal entry | none |
| Phase X | lib/internal/config.dart | DNS | internal config | internal | internal-only literal | none |
""".strip()
            + "\n",
            encoding="utf-8",
        )
        audit.write_text("lib/ui/login.dart:10:Text('用户协议')\n", encoding="utf-8")
        if verify(audit, checklist, quiet=True) != 0:
            return 1
        audit.write_text("lib/ui/home.dart:7:Text('DNS')\n", encoding="utf-8")
        if verify(audit, checklist, quiet=True) == 0:
            print("self-test expected unclassified hit to fail", file=sys.stderr)
            return 1
        checklist.write_text(
            """
| Phase | file:line | Matched string | Surface | Category | Rationale | Action/blocker |
| --- | --- | --- | --- | --- | --- | --- |
| Phase X | lib/ui/home.dart | DNS | normal UI | normal-ui-blocker | forbidden visible term | remove |
""".strip()
            + "\n",
            encoding="utf-8",
        )
        if verify(audit, checklist, quiet=True) == 0:
            print("self-test expected normal-ui-blocker to fail", file=sys.stderr)
            return 1
    print("self-test passed")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw_audit", nargs="?")
    parser.add_argument("checklist", nargs="?")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.raw_audit or not args.checklist:
        parser.error("expected <raw-audit-file> <checklist.md> or --self-test")
    return verify(Path(args.raw_audit), Path(args.checklist))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
