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
  L1  LEVEL-RENUMBER: `get_layer(<integer literal>)` — a level is always
      derived (`ground_plane_level()` / `storey_level_base()`), never typed

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
# L1: a level spelled as a literal. `_layers` is keyed by ABSOLUTE level and the
# ground plane moved to PLAYABLE_LEVEL (80) on 2026-08-24, so `get_layer(0)` — and
# the old floor levels -1 / -2 — return null on every map. Nothing errors: the
# caller takes its own null branch and does nothing at all, forever. That cost four
# live defects, found together on 2026-09-01 (OCC-FIX-03): a wireframe wedge drawn
# to the scene origin, a dev overlay painted in one pile there, and three props
# whose `_apply_z_index()` became a silent no-op.
#
# WIDENED the same day (Director: "vamos continuar corrigindo tudo que aparecer"),
# after the narrow 0/-N version let roof_slab_selftest.gd through: it rendered a
# block at storey 0 (levels 80..87) and then read its "roof" from `get_layer(8)`,
# seventy-two levels BELOW the block, and passed anyway because it only asserted
# material. A positive literal is the same mistake wearing a number that still
# resolves to a layer — so every integer literal is a violation now. A level is
# always derived: `ground_plane_level()`, `storey_level_base()`, or an expression
# over one of them.
L1_GROUND_LAYER_LITERAL = re.compile(r"\bget_layer\s*\(\s*-?\s*\d+\s*\)")
FUNC_DECL = re.compile(r"^func\s+(\w+)\s*\(")

# L2: glass-ness is ASKED, never COMPARED (GLASS_MASTER_PLAN G-D16, V-A).
#
# Before the family seam, "is this glass?" was a bare `material == "glass"` in
# twenty-five places across rendering, geometry, occlusion, the guard phase, the
# shot path and the cook — and every one of them is a BEHAVIOUR: glass does not
# occlude, groups into a pane, lets a round through, renders on its own
# transparent layers, drops no smoke, anchors no shards.
#
# G-D16 makes glass a FAMILY (`glass_armored`, `glass_screen_*`). A literal
# comparison silently excludes every new member, and the failure is invisible:
# the new material is simply an OPAQUE wall that happens to be named glass. It
# renders, it occludes, it stops rounds, and nothing errors — the same failure
# class as a rejected facade.
#
# So the roster is read out of glass_materials.gd rather than duplicated here
# (check_decal.py's `_wired_materials()` discipline: a source that moves must not
# leave a stale copy behind), and any `== "<member>"` / `!= "<member>"` outside
# that file is a violation. It matches COMPARISONS only — a dict row
# (`"glass": 0.4`), an authoring default (`get("material", "glass")`) and a
# lookup (`resistance("glass")`) are data, not predicates, and stay legal.
GLASS_FAMILY_SOURCE = SCRIPTS_DIR / "systems" / "glass_materials.gd"
GLASS_FAMILY_CONST = re.compile(r"^const\s+FAMILY\s*:.*=\s*\[(.*)\]")


def _glass_family() -> list[str] | None:
    """The glass material ids, read from the seam module. None when the constant
    cannot be found, so a refactor of that file degrades this rule to "cannot
    check" instead of to a false pass."""
    try:
        for line in GLASS_FAMILY_SOURCE.read_text(encoding="utf-8").splitlines():
            m = GLASS_FAMILY_CONST.match(line)
            if m:
                return [t.strip().strip('"') for t in m.group(1).split(",") if t.strip()]
    except OSError:
        return None
    return None


_GLASS_MEMBERS = _glass_family()
L2_GLASS_COMPARISON = re.compile(
    r"[=!]=\s*\"(%s)\"" % "|".join(re.escape(m) for m in _GLASS_MEMBERS)
) if _GLASS_MEMBERS else None


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

        # L1 — a level is derived, never a literal.
        # voxel_renderer.gd owns the level→layer store, so it is the one file
        # allowed to speak in raw level numbers. Comments are skipped: the fix
        # commits quote the broken call in their own headers.
        if (name != "voxel_renderer.gd"
                and not line.lstrip().startswith("#")
                and L1_GROUND_LAYER_LITERAL.search(line)):
            out.append(Violation(
                "L1 level-never-a-literal",
                rel, lineno,
                "get_layer(<literal>) hardcodes a level — the ground plane is "
                "PLAYABLE_LEVEL (80), not 0. Derive it: ground_plane_level() / "
                "storey_level_base() (and relative_level() for offsets)",
            ))

        # L2 — glass-ness is asked, never compared.
        #
        # Two exemptions, both reasoned rather than convenient:
        #   · glass_materials.gd OWNS the family and has to name its members;
        #   · godot/scripts/tools/ is where selftests assert on FIXTURE AND MAP
        #     DATA — `s.material_at(7) == "glass"` in glass_transparency_selftest
        #     is checking that the GLASS map authored a glass middle band, which
        #     is a fact about the data and not a predicate about behaviour. A gate
        #     that failed it would be failing known-good code, which is
        #     check_facade.py's own first-run mistake. A selftest that MIRRORS an
        #     engine rule should still call the seam, and the two in
        #     glass_shatter_selftest.gd were converted with this rule.
        if (L2_GLASS_COMPARISON is not None
                and name != "glass_materials.gd"
                and "/tools/" not in rel
                and not line.lstrip().startswith("#")
                and L2_GLASS_COMPARISON.search(line)):
            out.append(Violation(
                "L2 glass-is-a-family",
                rel, lineno,
                "comparing a material against a glass id excludes every other "
                "member of the family (G-D16: glass_armored, glass_screen_*) and "
                "fails SILENTLY — the new material renders as an opaque wall. "
                "Ask GlassMaterials.is_glass(<id>) instead",
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
