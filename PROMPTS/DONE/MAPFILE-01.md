# MAPFILE-01 COMPLETION SUMMARY

## Overview

**Task**: "The `.map.json` format, a section-registry-based `MapFileService`, per-section migrations, tolerant round-trip, loud-fail validation, and a headless `map_lint` tool"

**Status**: ✅ COMPLETE (v0.4.10 → v0.4.11)

**Completion Date**: 2026-07-05

---

## Implementation Checklist

### ✅ Item 1: File Format & Location
- **`.map.json` specification** (infiltraitor-map v3):
  - Top-level `format`, `schema_version`, `id`, `meta` keys
  - `sections` dict with per-section version fields ("v")
  - Procedural & patches stored as sibling keys (design fork for pre-processing semantics)
- **Directory structure**:
  - Shipped maps: `res://maps/*.map.json`
  - User-custom maps: `user://maps/*.map.json`
  - User directory wins on collision (name-based shadowing)

### ✅ Item 2: Section Registry & Anti-Breakage
- **[map_section_registry.gd](godot/scripts/world/maps/persistence/map_section_registry.gd)**:
  - `SectionOwner` class encapsulates serialization contract (serialize/deserialize/migrations/default_value)
  - `register(owner)` validates no duplicate registrations
  - `migrate_section(section_id, raw)` applies ordered migration chain
  - **M3 (Tolerant round-trip)**: Unknown sections preserved verbatim; known sections with unrecognized versions pass through
  - No-op registry pattern allows safe deployment of future version files

### ✅ Item 3: Load/Save Service with Migrations
- **[map_file_service.gd](godot/scripts/world/maps/persistence/map_file_service.gd)**:
  - `load_file(path)` → `{ok: bool, spec: Dictionary, errors: Array}`
    - Validates file exists, JSON parses, format tag matches
    - Migrates each section via registry; fills defaults for known sections not in file
    - Deserializes via owner.deserialize(); preserves unknown sections verbatim
  - `save_file(path, spec)` → `{ok: bool, errors: Array}`
    - Serializes known sections; unknown sections pass through untouched
    - Preserves procedural and patches as sibling keys (not nested)
  - `_validate(spec)` checks id not empty (extensible)
  - Directory creation handled gracefully

### ✅ Item 4: Section Owners for v1 (Rehearsal Migration)
- **[map_sections_v1.gd](godot/scripts/world/maps/persistence/map_sections_v1.gd)**:
  - Registered sections: `board`, `walls`, `blocks`, `props`, `actors`
  - All v1 except `walls` (v2 for migration rehearsal)
  - `register_walls`: Fictional v1→v2 migration backfills `storeys=1`
  - Proven working: TEST 3 validation passes both RED (no migration) and GREEN (with migration)

### ✅ Item 5: Headless Validation Tool
- **[map_lint.gd](godot/scripts/tools/map_lint.gd)**:
  - Scans `res://maps/` and `user://maps/` directories
  - Loads each `.map.json` via `MapFileService` with full registry
  - Reports ✓/✗ per file with error details
  - Exit code: 0 (all pass) or 1 (any fail)
  - Tested: Graceful empty-dir handling, successful PLAYGROUND validation

### ✅ Item 6: Comprehensive Test Suite
- **[mapfile_roundtrip_test.gd](godot/scripts/tools/mapfile_roundtrip_test.gd)** (3 test cases):
  
  **TEST 1 — Basic round-trip** (PASS ✅)
  - Save spec → load → structural equality
  - Handles JSON numeric coercion (int→float→int comparison)
  - Evidence: "[TEST 1] Basic round-trip... PASS: basic_roundtrip"
  
  **TEST 2 — Tolerant unknown section** (PASS ✅)
  - Hand-craft JSON with unknown "future_section"
  - Load, save, reload preserves data verbatim (M3)
  - Handles JSON numeric coercion for arrays
  - Evidence: "[TEST 2]... ✓ Unknown section preserved verbatim... PASS: tolerant_unknown_section"
  
  **TEST 3 — Migration RED + GREEN** (PASS ✅)
  - RED: Registry without v1→v2 migration → loud-fail
  - GREEN: Registry with migration → succeeds, `storeys` backfilled, `v` bumped
  - Evidence: "[TEST 3]... ✓ RED correctly failed... ✓ GREEN correctly loaded... PASS: migration_red_then_green"

---

## Test Results (Final Run)

```
======================================================================
MAPFILE ROUNDTRIP: ALL TESTS PASS
======================================================================

[TEST 1] Basic round-trip: save → load → structural equality
  ✓ Saved to user://test_roundtrip.map.json
  ✓ Loaded from disk
  ✓ Structural equality verified
  PASS: basic_roundtrip

[TEST 2] Tolerant round-trip: unknown section preservation (M3)
  ✓ Written test file with unknown section
  ✓ Loaded file with unknown section
  ✓ Unknown section preserved verbatim
  ✓ Re-saved with unknown section intact
  ✓ Unknown section survived second round-trip
  PASS: tolerant_unknown_section

[TEST 3] Migration RED (missing) + GREEN (present)
  [RED] Testing broken migration chain (missing v1->v2)...
  ERROR: [MAPFILE] Section 'walls' has no migration from v1 to v2 — file cannot be safely loaded
  ✓ RED correctly failed with: 'Section 'walls' migration returned null — check logs for details'
  [GREEN] Testing correct migration chain (with v1->v2)...
  ✓ GREEN correctly loaded
  ✓ Migration correctly backfilled storeys=1
  PASS: migration_red_then_green

[INFILTRAITOR] Version 0.4.10
```

---

## Map Lint Validation

```
======================================================================
MAP LINT
======================================================================

  ✓ res://maps/PLAYGROUND.map.json
[LINT] (no directory: user://maps)

1 checked, 0 failed
[INFILTRAITOR] Version 0.4.10
```

**Golden Test File**: [maps/PLAYGROUND.map.json](maps/PLAYGROUND.map.json)
- Valid infiltraitor-map v3 with all 5 section owners
- Inner size [28, 18] (fits buffer=1 constraint)
- Complete wall, block, prop, actor definitions

---

## Design Decisions

### D1: Procedural & Patches as Sibling Keys
**Decision**: Store procedural and patches as top-level keys alongside sections, not nested.

**Rationale**: These represent pre-processing state (map generation parameters, overlay patches) that exist *before* content sections. Nesting under sections would suggest they are section data, violating semantic clarity.

**Impact**: Simpler traversal; tolerant round-trip preserves sibling structure naturally.

### D2: JSON Numeric Coercion Acceptance
**Decision**: Accept that JSON.parse_string() converts all numbers to float; handle via int() casting in comparisons.

**Rationale**: JSON has no integer type; all numbers are floats in spec. Comparisons must normalize, not reject.

**Impact**: TEST 1 and TEST 2 both handle [20, 15] vs [20.0, 15.0] correctly.

### D3: Tolerant Round-Trip (M3) Mechanism
**Decision**: Unknown sections pass through verbatim; known sections with unrecognized versions also pass through (not migration-failed).

**Rationale**: Allows deployment of future-version files in older engines without breakage. Registry is a *filter*, not a validator.

**Impact**: Safe forward compatibility; old engine can load v3 files created by new engine.

---

## Integration Points

### For Users
- Export maps via MapCatalog (MAPFILE-02 task)
- Load maps in game via room_builder → MapFileService

### For Developers
- Validate maps locally: `godot --path . --headless --script godot/scripts/tools/map_lint.gd`
- Add new sections in MAPFILE-03 task (BlockRegistry, PropRegistry, ActorRegistry patterns)
- Future migrations: Add v1→v2 migration callable in map_sections_v*.gd

---

## Known Limitations & Future Work

1. **Per-section schema validation** (extensible): `_validate()` method exists but not populated per section; easy to add shape checks
2. **Error message formatting**: Errors are simple strings; could be structured {code, section, detail} tuples for localization
3. **Directory creation refinement**: Simplified but robust; could add mode bits or permission checks if needed
4. **map_lint integration**: Tool exists; not yet wired to CI/CD or editor validation

---

## Files Modified/Created

### Core Implementation
- ✅ Created: `godot/scripts/world/maps/persistence/map_section_registry.gd`
- ✅ Created: `godot/scripts/world/maps/persistence/map_file_service.gd`
- ✅ Created: `godot/scripts/world/maps/persistence/map_sections_v1.gd`
- ✅ Created: `godot/scripts/tools/map_lint.gd`
- ✅ Created: `godot/scripts/tools/mapfile_roundtrip_test.gd`
- ✅ Created: `maps/` directory

### Test Validation
- ✅ Golden file: `maps/PLAYGROUND.map.json`

---

## Invariants Verified

- ✅ All JSON numeric coercion handled (int/float comparison normalized)
- ✅ Tolerant round-trip: Unknown section data survives save/load cycle (TEST 2)
- ✅ Loud-fail migration: Missing v1→v2 causes logged error (TEST 3 RED)
- ✅ Silent recovery migration: Present v1→v2 succeeds with backfill (TEST 3 GREEN)
- ✅ map_lint tool: Scans dirs, validates files, reports per-file status
- ✅ No split-brain: Single MapFileService instance owns all load/save logic

---

## Next Steps

**MAPFILE-02** (Planned):
- Wire MapCatalog to enumerate/export shipped maps
- Create exporter for user://maps/ → .map.json files

**MAPFILE-03** (Planned):
- Implement BlockRegistry (blocks section owner pattern)
- Implement PropRegistry (props section owner pattern)
- Implement ActorRegistry (actors section owner pattern)

**CI/CD** (Planned):
- Run map_lint in build pipeline before export
- Flag invalid maps during asset staging

---

## Completion Evidence

| Item | Status | Evidence |
|------|--------|----------|
| Format & location | ✅ | infiltraitor-map v3, res://maps/, user://maps/ |
| Section registry | ✅ | MapSectionRegistry + SectionOwner pattern proven in TEST 3 |
| Load/save service | ✅ | MapFileService load_file/save_file with migrations |
| Section owners v1 | ✅ | All 5 registered; v1→v2 migration rehearsed (TEST 3) |
| map_lint tool | ✅ | Scans dirs, validates, reports exit code |
| Test suite | ✅ | 3/3 tests PASS with full output captured |
| Golden files | ✅ | PLAYGROUND.map.json valid and linted |

---

**Task Status**: ✅ COMPLETE

**Version Bump**: 0.4.10 → 0.4.11

**Archive Date**: 2026-07-05
