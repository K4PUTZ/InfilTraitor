#!/usr/bin/env python3
"""Mechanically enforce INFILTRAITOR's inviolable architecture rules.

These rules live (with rationale) in CLAUDE.md. This script encodes
the subset that can be checked mechanically with HIGH confidence and ZERO false
positives against the current tree — a guard, not a linter. It scans the whole
`godot/scripts/` tree and exits non-zero on any violation, so the pre-commit
hook can block drift before it enters history.

Checks implemented:
  R1  Gameplay stats are never `const` (HP/AP/armor/move-point ceilings)
  R2  `VISUAL_GRID_OFFSET` is only defined in room.gd (never copied into children)
  R3  `_edge_key()` is only defined in wall_edge_data.gd (single source of truth)
  R4  guard `state` is only assigned inside `_enter_state()`
  R5  `_alert_meter` is only *accumulated* inside `_apply_tic_result()`
  B1  Baking: voxel_renderer is the sole caller of set_cell() (branch exclusivity)
  B4  Baking: FNV-1a constants are pinned in facade_sampler.gd (determinism)
  L1  LEVEL-RENUMBER: `get_layer(0)` (or any negative literal) is never the
      ground plane — ask `ground_plane_level()`

Not mechanized (documented for honesty):
  R6  mission structure vs narrative — no such code exists yet
  R7  maps authored in inner coords — '+ buffer' is too heuristic to detect
      without false positives; relies on review.

Usage:
    python3 tools/persistent/check_invariants.py          # report + exit code
    python3 tools/persistent/check_invariants.py --quiet  # exit code only
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "godot" / "scripts"

# R1: const declarations of gameplay-stat names. Kept to the explicit examples
# from CLAUDE.md (+ close variants) to stay zero-false-positive; tuning
# consts like VISION_RANGE are intentionally NOT in scope here.
R1_STAT_CONST = re.compile(
    r"^const\s+(MAX_HP|MOVE_POINTS_PER_AP|MOVE_POINTS|MAX_AP|MAX_ARMOR|MAX_MOVE)\b"
)
R2_VISUAL_OFFSET = re.compile(r"^\s*const\s+VISUAL_GRID_OFFSET\b")
R3_EDGE_KEY = re.compile(r"^\s*(static\s+)?func\s+_edge_key\b")
R4_STATE_ASSIGN = re.compile(r"^\s+state\s*=(?!=)")
B1_VOXEL_LAYER_SET_CELL = re.compile(r"_voxel_layers?\[?\s*[.\[]\s*set_cell\s*\(")
B4_FNV_CONST = re.compile(r"\b(2166136261|16777619)\b")
# L1: the pre-LEVEL-RENUMBER ground/floor level numbers, still spelled as literals.
# `_layers` is keyed by ABSOLUTE level and the ground plane moved to PLAYABLE_LEVEL
# (80) on 2026-08-24, so `get_layer(0)` — and the old floor levels -1 / -2 — return
# null on every map. Nothing errors: the caller takes its own null branch and does
# nothing at all, forever. That cost four live defects, found together on 2026-09-01
# (OCC-FIX-03): a wireframe wedge drawn to the scene origin, a dev overlay painted
# in one pile there, and three props whose `_apply_z_index()` became a silent no-op.
# Deliberately narrow — a literal 0 or a negative one, which are exactly the numbers
# that used to mean "ground" and now mean "nothing". A selftest that builds a fixture
# at some arbitrary positive level is not making this mistake and is not flagged.
L1_GROUND_LAYER_LITERAL = re.compile(r"\bget_layer\s*\(\s*(0|-\s*\d+)\s*\)")
FUNC_DECL = re.compile(r"^func\s+(\w+)\s*\(")


@dataclass
class Violation:
    rule: str
    file: str
    line: int
    text: str


def _rel(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def _func_ranges(lines: list[str]) -> list[tuple[str, int, int]]:
    """[(func_name, start_idx, end_idx_exclusive)] for top-level funcs."""
    ranges: list[tuple[str, int, int]] = []
    cur: tuple[str, int] | None = None
    for i, line in enumerate(lines):
        m = FUNC_DECL.match(line)
        if m:
            if cur is not None:
                ranges.append((cur[0], cur[1], i))
            cur = (m.group(1), i)
    if cur is not None:
        ranges.append((cur[0], cur[1], len(lines)))
    return ranges


def _enclosing_func(idx: int, ranges: list[tuple[str, int, int]]) -> str | None:
    for name, start, end in ranges:
        if start <= idx < end:
            return name
    return None


def _is_alert_accumulation(line: str) -> bool:
    """True when the line *increments* _alert_meter (vs. reset to 0 / set to max)."""
    if re.search(r"_alert_meter\s*\+=", line):
        return True
    # _alert_meter = <expr containing _alert_meter + ...>
    if re.search(r"_alert_meter\s*=\s*.*_alert_meter\s*\+", line):
        return True
    return False


def check_file(path: Path) -> list[Violation]:
    rel = _rel(path)
    name = path.name
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[Violation] = []
    ranges = _func_ranges(lines)

    for i, line in enumerate(lines):
        lineno = i + 1

        # R1 — gameplay stats must not be const
        if R1_STAT_CONST.match(line):
            out.append(Violation(
                "R1 stats-are-var",
                rel, lineno,
                "gameplay stat declared as const (must be `var` to scale with tiers)",
            ))

        # R2 — VISUAL_GRID_OFFSET only in room.gd
        if name != "room.gd" and R2_VISUAL_OFFSET.match(line):
            out.append(Violation(
                "R2 visual-offset-param",
                rel, lineno,
                "VISUAL_GRID_OFFSET must be passed via setup(), not redefined here",
            ))

        # R3 — _edge_key only in wall_edge_data.gd
        if name != "wall_edge_data.gd" and R3_EDGE_KEY.match(line):
            out.append(Violation(
                "R3 single-edge-key",
                rel, lineno,
                "use WallEdgeData.edge_key(); never define a local _edge_key()",
            ))

        # R4 — guard state only assigned in _enter_state()
        if name == "guard_enemy.gd" and R4_STATE_ASSIGN.match(line):
            if _enclosing_func(i, ranges) != "_enter_state":
                out.append(Violation(
                    "R4 state-via-enter-state",
                    rel, lineno,
                    "assign guard state only inside _enter_state()",
                ))

        # R5 — _alert_meter accumulation only in _apply_tic_result()
        if name == "room.gd" and "_alert_meter" in line and _is_alert_accumulation(line):
            if _enclosing_func(i, ranges) != "_apply_tic_result":
                out.append(Violation(
                    "R5 alert-meter-locality",
                    rel, lineno,
                    "_alert_meter may only accumulate inside _apply_tic_result()",
                ))

        # L1 — the ground plane is ground_plane_level(), never a literal 0 / -N.
        # voxel_renderer.gd owns the level→layer store, so it is the one file
        # allowed to speak in raw level numbers. Comments are skipped: the fix
        # commits quote the broken call in their own headers.
        if (name != "voxel_renderer.gd"
                and not line.lstrip().startswith("#")
                and L1_GROUND_LAYER_LITERAL.search(line)):
            out.append(Violation(
                "L1 ground-plane-not-zero",
                rel, lineno,
                "get_layer(0)/get_layer(-N) is null since LEVEL-RENUMBER — "
                "use get_layer(<renderer>.ground_plane_level()) (and relative_level() for offsets)",
            ))

        # B1 — _voxel_layers (voxel grid) only modified via voxel_renderer._set_voxel_cell()
        if B1_VOXEL_LAYER_SET_CELL.search(line) and name != "voxel_renderer.gd":
            out.append(Violation(
                "B1 branch-exclusivity",
                rel, lineno,
                "_voxel_layers cells must only be set via voxel_renderer._set_voxel_cell() (seam integration)",
            ))

    # B4 — FNV-1a constants pinned in facade_sampler.gd
    if name == "facade_sampler.gd":
        text = "".join(lines)
        has_offset = "2166136261" in text
        has_prime = "16777619" in text
        if not (has_offset and has_prime):
            out.append(Violation(
                "B4 fnv1a-constants",
                rel, 0,
                "FNV-1a offset_basis (2166136261) and prime (16777619) must be pinned in _fnv1a_hash()",
            ))

    return out


def main(argv: list[str]) -> int:
    quiet = "--quiet" in argv
    if not SCRIPTS_DIR.is_dir():
        print(f"error: {SCRIPTS_DIR} not found", file=sys.stderr)
        return 2

    violations: list[Violation] = []
    for path in sorted(SCRIPTS_DIR.rglob("*.gd"), key=lambda p: p.as_posix()):
        violations.extend(check_file(path))

    if not violations:
        if not quiet:
            print("✓ invariants OK — no rule violations")
        return 0

    print(f"✗ {len(violations)} invariant violation(s):", file=sys.stderr)
    for v in violations:
        print(f"  [{v.rule}] {v.file}:{v.line} — {v.text}", file=sys.stderr)
    print("\nSee CLAUDE.md (Architecture — Inviolable Rules).",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
