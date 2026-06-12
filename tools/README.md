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
- Creates ZIP archives (BACKUP_YYYYMMDD_HHMMSS.zip)
- Excludes ASSETS/, ARCHIVE/, .git, cache directories
- Excludes large binaries and cache files
- Preserves entire source structure (godot/, docs/, scripts)
- Typical output: ~50KB (code + structure only)

**When to Use:**
- Before major refactors
- Before experimenting with risky changes
- When backup needed for archival

**Configuration:**
- Edit `EXCLUDE_DIRS` and `EXCLUDE_FILES` inside script to customize

**Output:** BACKUP_*.ZIP files (gitignored)

**Maintenance:** None required (self-contained)

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
| Migration scripts | Never (archived) | None | Reference only |

---

## Related Documentation

- [Repository Structure](../docs/technical/repo_structure.md)
- [Archive Policy](../docs/technical/archive_policy.md)
- [Development Guide](../docs/technical/developer_setup.md)

---

**Last Updated:** 2026-06-12  
**Maintained By:** Architecture Team  
**Status:** Active 🟢
