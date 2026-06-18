# INFILTRAITOR Tools & Utilities

> **Central registry of project tools, scripts, and development utilities.**

---

## Quick Navigation

- **[Persistent Tools](#persistent-tools)** — Active utilities
- **[Migration Archive](#migration-archive)** — Historical scripts
- **[Experimental Tools](#experimental-tools)** — Sandbox/testing
- **[Archive](#archive)** — Deprecated code

---

## Persistent Tools

**Active development utilities maintained and supported.**

### BACKUP.py

**Purpose:** Create incremental project backups excluding large assets  
**Category:** Maintenance utility  
**Status:** ✅ Active  

**Usage:**
```bash
cd /Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR
python3 tools/persistent/BACKUP.py
```

**Features:**
- Creates a single `BACKUP.ZIP` at the repo root (overwrites the previous one)
- Excludes ASSETS/, ARCHIVE/, REFERENCES/, export/, .git, .godot, .vscode, .claude, cache directories
- Excludes images and binaries by extension (code + textual docs only)
- Preserves the source structure (godot/, docs/, tools/, scripts)

**When to Use:**
- Before major refactors
- Before experimenting with risky changes
- When backup needed for archival

**Configuration:**
- Edit `EXCLUDE_DIRS` and `EXCLUDE_FILES` inside script to customize

**Output:** `BACKUP.ZIP` (gitignored)

**Maintenance:** None required (structure-agnostic — `rglob` + exclude lists, so new
files are picked up automatically without editing the script)

---

### gen_codemap.py

**Purpose:** Mechanically generate `CODEMAP.md` from the GDScript source so the
file map / API surface / tuning tables never drift from the code
**Category:** Documentation automation
**Status:** ✅ Active

**Usage:**
```bash
python3 tools/persistent/gen_codemap.py          # write CODEMAP.md
python3 tools/persistent/gen_codemap.py --check   # exit 1 if stale (no write)
```

**Features:**
- Extracts `class_name`, `extends`, file doc, `signal`s, top-level `const`s,
  `@export` / public vars, and public funcs from every `godot/scripts/**/*.gd`
- Deterministic output (no timestamps / absolute paths) so unchanged code yields
  a byte-identical file — a plain diff is a valid freshness check
- Mechanical extraction only: cannot hallucinate, cannot drift

**Output:** `CODEMAP.md` (generated — do not edit by hand)

**Related:** Design rationale + inviolable rules stay hand-authored in
`OPERATOR_CONTEXT.md`. The two files are complementary: authored *why* vs.
generated *what*.

---

### check_invariants.py

**Purpose:** Mechanically enforce the inviolable architecture rules from
OPERATOR_CONTEXT.md so violations can't enter the codebase unnoticed
**Category:** Code-quality automation
**Status:** ✅ Active

**Usage:**
```bash
python3 tools/persistent/check_invariants.py          # report + exit code
python3 tools/persistent/check_invariants.py --quiet   # exit code only
```

**Checks (high-confidence, zero false-positive against the current tree):**
- **R1** gameplay stats are never `const` (HP/AP/armor/move-point ceilings)
- **R2** `VISUAL_GRID_OFFSET` is only defined in room.gd (never copied to children)
- **R3** `_edge_key()` is only defined in wall_edge_data.gd
- **R4** guard `state` is only assigned inside `_enter_state()` (scope-aware)
- **R5** `_alert_meter` only *accumulates* inside `_apply_tic_result()` (scope-aware)

**Not mechanized:** R6 (no mission code yet) and R7 (`+ buffer` too heuristic to
detect without false positives) — those still rely on review.

---

### hooks/pre-commit

**Purpose:** Two pre-commit gates — (1) the inviolable-rule guard and (2) the
`CODEMAP.md` freshness gate
**Category:** Automation (git hook)
**Status:** ✅ Active

**Install (one-time, from repo root):**
```bash
git config core.hooksPath tools/persistent/hooks
```

**Behavior:** On commit it runs `check_invariants.py` first — any rule violation
aborts the commit (no auto-fix; you fix the code). Then it runs
`gen_codemap.py --check`; if `CODEMAP.md` is stale it regenerates + `git add`s it
and aborts for review. Neither gate lets a bad commit reach history.
`core.hooksPath` is local git config, so a fresh clone re-runs the install once.

---

## Migration Archive

**Historical scripts from development phases. Use only for reference or emergency recovery.**

### Tileset Origin Calibration (M2.06)

**Phase:** M2.06 — Tactical Shadows System  
**Objective:** Transform tileset from Kenney naming → screen-space naming; calibrate texture origins; expand corner assets  

**Scripts Included:**

| Script | Purpose | Status |
|--------|---------|--------|
| `rename_tiles.py` | Convert Kenney naming (N/E/S/W) to screen-space (SE/SW/NE/NW) | ✅ Complete |
| `update_texture_origins.py` | Apply calibrated origins to wall-aligned assets (CANONICAL) | ✅ Complete |
| `fix_wall_origins.py` | Fix wall/wallCorner origins specifically | ✅ Complete |
| `fix_corner_origins.py` | Fix corner asset origins | ✅ Complete |
| `fix_sw_ne_corners.py` | Fix SW/NE corner dimensions | ✅ Complete |
| `expand_all_corners.py` | Expand corner assets 256→320px | ✅ Complete |
| `expand_corner_assets.py` | Adjust for expanded canvas | ✅ Complete |
| `expand_corner_pngs.py` | PNG expansion logic | ✅ Complete |
| `fix_all_corners.py` | Comprehensive corner fix (direct approach) | ✅ Complete |
| `update_corners_sw_ne.py` | SW/NE corner final refinement | ✅ Complete |

**Documentation:** See [MIGRATION_HISTORY.md](tileset_origin_calibration/MIGRATION_HISTORY.md)

**When to Use:**
- **Reference:** Understanding how texture origins work
- **Recovery:** If tileset is corrupted and needs rebuilding
- **Education:** Learning asset calibration workflow

**When NOT to Use:**
- For new assets (use modern tooling)
- For routine maintenance
- Without reading MIGRATION_HISTORY.md first

**Risks:**
- ⚠️ Scripts modify tileset_blocks.tres directly
- ⚠️ No validation of output (check visually after run)
- ⚠️ Overwrite without backup = data loss

**Recovery:** If something breaks, revert via git:
```bash
git checkout HEAD~1 -- godot/resources/tilesets/tileset_blocks.tres
```

---

## Experimental Tools

**Sandbox for new tooling development. Not guaranteed to be stable.**

*Currently empty. Add new experimental tools here before promoting to Persistent.*

---

## Archive

**Deprecated code preserved for historical reference.**

*Currently empty. Add deprecated tools here instead of deleting.*

---

## Tooling Guidelines

### Adding New Tools

1. **Develop & test** in `experimental/`
2. **Document** in README.md
3. **Verify no implicit dependencies** (other scripts shouldn't call it)
4. **When stable** → promote to `persistent/` or archive old version
5. **Commit with message** describing the new tool

### Removing Tools

1. **Never delete** — archive instead
2. Move to `archive/` with reason document
3. Update this README.md
4. Commit explaining removal

### Naming Conventions

- **Active tools:** descriptive name (BACKUP.py, validate_tileset.py)
- **Migration scripts:** use phase prefix (migration_phase_1.py)
- **Experimental:** use feature name (new_asset_pipeline.py)

---

## Tooling Lifecycle

```
Idea
  ↓
Experimental/ (develop & test)
  ↓
Persistent/ (promote when stable)
  ↓
Archive/ (deprecate, move when replacing)
```

---

## Maintenance

| Tool | Frequency | Owner | Notes |
|------|-----------|-------|-------|
| BACKUP.py | As-needed | Anyone | Run before major changes |
| gen_codemap.py | Automatic | pre-commit hook | Regenerates CODEMAP.md; never edit by hand |
| check_invariants.py | Automatic | pre-commit hook | Enforces OPERATOR_CONTEXT inviolable rules |
| hooks/pre-commit | One-time install | Anyone | `git config core.hooksPath tools/persistent/hooks` |
| Migration scripts | Never (archived) | None | Reference only |

---

## Related Documentation

- [Repository Structure](../docs/technical/repo_structure.md)
- [Archive Policy](../docs/technical/archive_policy.md)
- [Development Guide](../docs/technical/developer_setup.md)

---

**Last Updated:** 2026-06-18  
**Maintained By:** Architecture Team  
**Status:** Active 🟢
