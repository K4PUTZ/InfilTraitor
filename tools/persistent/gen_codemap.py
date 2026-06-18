#!/usr/bin/env python3
"""Generate CODEMAP.md by mechanically extracting the public surface of every
GDScript file under godot/scripts/.

This is a *mechanical* extractor, not a summarizer: it only reports what the
code literally declares (class_name, extends, file doc comment, signals, top
-level consts, @export / public config vars, public funcs). It therefore cannot
drift from the code and cannot hallucinate. The authored design knowledge (the
inviolable rules, the rationale) stays in OPERATOR_CONTEXT.md by hand.

Output is fully deterministic — no timestamps, no absolute paths, stable sort —
so a fresh run on unchanged code produces a byte-identical file. That property
is what lets the pre-commit hook use a plain diff as a freshness gate.

Usage:
    python3 tools/persistent/gen_codemap.py          # write CODEMAP.md
    python3 tools/persistent/gen_codemap.py --check   # exit 1 if stale (no write)
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "godot" / "scripts"
OUTPUT = REPO_ROOT / "tools" / "persistent" / "CODEMAP.md"
SCRIPTS_REL = "godot/scripts"

# A line is "top-level" (declaration scope) when it has no leading indentation.
RE_EXTENDS = re.compile(r"^extends\s+(.+?)\s*$")
RE_CLASS_NAME = re.compile(r"^class_name\s+(\w+)")
RE_SIGNAL = re.compile(r"^signal\s+(\w+\s*\(.*?\)|\w+)")
RE_CONST = re.compile(r"^const\s+(\w+)\s*(?::\s*[\w\[\], ]+)?\s*(?::=|=)\s*(.+?)\s*$")
RE_EXPORT_VAR = re.compile(r"^@export\s+var\s+(\w+.*?)\s*$")
RE_PUBLIC_VAR = re.compile(r"^var\s+([a-zA-Z]\w*.*?)\s*$")
RE_FUNC = re.compile(r"^func\s+([a-zA-Z]\w*)\s*\(")


@dataclass
class FileInfo:
    rel_path: str
    extends: str = ""
    class_name: str = ""
    doc: list[str] = field(default_factory=list)
    signals: list[str] = field(default_factory=list)
    consts: list[tuple[str, str]] = field(default_factory=list)
    exports: list[str] = field(default_factory=list)
    config_vars: list[str] = field(default_factory=list)
    public_funcs: list[str] = field(default_factory=list)
    line_count: int = 0


def _bracket_balance(text: str) -> int:
    """Net unclosed () [] {} in text, ignoring delimiters inside strings."""
    depth = 0
    in_str = False
    quote = ""
    for ch in text:
        if in_str:
            if ch == quote:
                in_str = False
            continue
        if ch in "\"'":
            in_str = True
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
    return depth


def parse_file(path: Path) -> FileInfo:
    rel = path.relative_to(REPO_ROOT).as_posix()
    info = FileInfo(rel_path=rel)
    lines = path.read_text(encoding="utf-8").splitlines()
    info.line_count = len(lines)

    in_top_comment = True
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i].rstrip("\n")
        stripped = line.strip()

        if in_top_comment:
            # File doc comment: first contiguous run of comment lines at the
            # top, before any code. Handles '##'- and '#'-style headers.
            if stripped == "":
                if info.doc:
                    in_top_comment = False
                i += 1
                continue
            if stripped.startswith("#"):
                text = stripped.lstrip("#").strip()
                if text:
                    info.doc.append(text)
                i += 1
                continue
            in_top_comment = False  # first real code line ends the doc block

        # Only inspect declaration-scope (unindented) lines.
        if line[:1] in (" ", "\t"):
            i += 1
            continue

        # Join continuation lines for multi-line declarations (arrays spanning
        # several lines, wrapped func signatures) so values aren't truncated.
        if _bracket_balance(line) > 0:
            parts = [line]
            depth = _bracket_balance(line)
            j = i + 1
            while j < n and depth > 0:
                cont = lines[j].rstrip("\n").strip()
                parts.append(cont)
                depth += _bracket_balance(cont)
                j += 1
            line = " ".join(p for p in parts if p)
            i = j
        else:
            i += 1

        m = RE_EXTENDS.match(line)
        if m and not info.extends:
            info.extends = m.group(1)
            continue
        m = RE_CLASS_NAME.match(line)
        if m:
            info.class_name = m.group(1)
            continue
        m = RE_SIGNAL.match(line)
        if m:
            info.signals.append(m.group(1).strip())
            continue
        m = RE_EXPORT_VAR.match(line)
        if m:
            info.exports.append(_strip_inline_comment(m.group(1)))
            continue
        m = RE_CONST.match(line)
        if m:
            info.consts.append((m.group(1), _strip_inline_comment(m.group(2))))
            continue
        m = RE_PUBLIC_VAR.match(line)
        if m:
            # Public (non-underscore) typed/initialized vars read as config.
            info.config_vars.append(_strip_inline_comment(m.group(1)))
            continue
        m = RE_FUNC.match(line)
        if m:
            info.public_funcs.append(_func_signature(line))
            continue

    return info


def _strip_inline_comment(text: str) -> str:
    # Drop a trailing ' # comment' but keep '#' inside strings/Color() literals.
    depth = 0
    in_str = False
    quote = ""
    for i, ch in enumerate(text):
        if in_str:
            if ch == quote:
                in_str = False
            continue
        if ch in "\"'":
            in_str = True
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "#" and depth == 0:
            return text[:i].rstrip()
    return text.rstrip()


def _func_signature(line: str) -> str:
    sig = line.strip()
    # Normalize: keep up to the return type / colon on the same line.
    return sig.rstrip()


def discover() -> list[FileInfo]:
    files = sorted(SCRIPTS_DIR.rglob("*.gd"), key=lambda p: p.as_posix())
    return [parse_file(p) for p in files]


def render(infos: list[FileInfo]) -> str:
    out: list[str] = []
    a = out.append

    a("# CODEMAP — INFILTRAITOR")
    a("")
    a("> **GENERATED FILE — do not edit by hand.**")
    a("> Produced by `tools/persistent/gen_codemap.py` from the actual GDScript")
    a("> source. Regenerate with `python3 tools/persistent/gen_codemap.py`.")
    a("> A pre-commit hook blocks commits when this file is stale.")
    a(">")
    a("> Design rationale and the inviolable rules live in `OPERATOR_CONTEXT.md`")
    a("> (hand-authored). This file is the mechanical mirror of the code.")
    a("")

    total_lines = sum(i.line_count for i in infos)
    a(f"**{len(infos)} scripts · {total_lines} lines total** "
      f"(under `{SCRIPTS_REL}/`)")
    a("")

    # Group by the first directory segment under godot/scripts/.
    groups: dict[str, list[FileInfo]] = {}
    for info in infos:
        rel = Path(info.rel_path).relative_to(SCRIPTS_REL)
        group = rel.parts[0] if len(rel.parts) > 1 else "(root)"
        groups.setdefault(group, []).append(info)

    a("## Index")
    a("")
    for group in sorted(groups):
        names = ", ".join(Path(i.rel_path).name for i in groups[group])
        a(f"- **{group}/** — {names}")
    a("")
    a("---")
    a("")

    for group in sorted(groups):
        a(f"## {group}/")
        a("")
        for info in groups[group]:
            _render_file(a, info)
    return "\n".join(out).rstrip() + "\n"


def _render_file(a, info: FileInfo) -> None:
    name = Path(info.rel_path).name
    header = f"### `{name}`"
    a(header)
    a("")
    meta = []
    if info.class_name:
        meta.append(f"`class_name {info.class_name}`")
    if info.extends:
        meta.append(f"extends `{info.extends}`")
    meta.append(f"{info.line_count} lines")
    a(" · ".join(meta))
    a("")
    a(f"`{info.rel_path}`")
    a("")
    if info.doc:
        a("> " + " ".join(info.doc))
        a("")
    if info.signals:
        a("**Signals**")
        for s in info.signals:
            a(f"- `signal {s}`")
        a("")
    if info.consts:
        a("**Constants / tuning**")
        for name_, val in info.consts:
            a(f"- `{name_}` = `{val}`")
        a("")
    if info.exports:
        a("**@export**")
        for v in info.exports:
            a(f"- `{v}`")
        a("")
    if info.config_vars:
        a("**Public vars**")
        for v in info.config_vars:
            a(f"- `var {v}`")
        a("")
    if info.public_funcs:
        a("**Public API**")
        for f in info.public_funcs:
            a(f"- `{f}`")
        a("")
    a("---")
    a("")


def main(argv: list[str]) -> int:
    if not SCRIPTS_DIR.is_dir():
        print(f"error: {SCRIPTS_DIR} not found", file=sys.stderr)
        return 2

    infos = discover()
    content = render(infos)

    check = "--check" in argv
    existing = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else None

    if check:
        if existing == content:
            return 0
        print("CODEMAP.md is STALE — regenerate with:", file=sys.stderr)
        print("    python3 tools/persistent/gen_codemap.py", file=sys.stderr)
        print("    git add tools/persistent/CODEMAP.md", file=sys.stderr)
        return 1

    OUTPUT.write_text(content, encoding="utf-8")
    if existing == content:
        print(f"CODEMAP.md unchanged ({len(infos)} scripts)")
    else:
        print(f"CODEMAP.md written ({len(infos)} scripts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
