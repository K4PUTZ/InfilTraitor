# MAPFILE Reference — `.map.json` Persistence System

**Distilled from:** `MAP_MATTRESS_MASTER_PLAN_v1.1` (closed 2026-07-09) and the
MAPFILE-01 / MAPFILE-02 implementations. This is the living reference for the
map persistence system; the archived plan holds the full decision rationale
(D-register D1–D16).

---

## Module inventory

| Module | Role |
|---|---|
| `godot/scripts/world/maps/map_catalog.gd` | `MapCatalog.get_spec(map_id, context)` — single entry point used by `room.gd`. **File-first:** tries `FileMapSource` for any id, then falls back to code generators (`PLAYGROUND`, `CALIB`, `SIGMA_01`, `PROCEDURAL`). |
| `godot/scripts/world/maps/file_map_source.gd` | Scans map folders, peeks ids cheaply for listing, loads via `MapFileService`, translates file spec → runtime spec (JSON-compatible values → Godot types). |
| `godot/scripts/world/maps/persistence/map_file_service.gd` | Load/save core. `CURRENT_SCHEMA_VERSION = 3`. Applies per-section migrations, deserializes via section owners, loud-fail validation — never returns a half-loaded map (`{ok, spec, errors}`). |
| `godot/scripts/world/maps/persistence/map_section_registry.gd` | Registry of section owners `{section_id, version, serialize, deserialize, migrations[]}`. The core loader knows no section's contents. |
| `godot/scripts/world/maps/persistence/map_sections_v1.gd` | Built-in section owner definitions (see table below). |
| `godot/scripts/tools/map_lint.gd` | Headless validator over both map folders + golden round-trip (load→save→compare) for shipped maps. |

## File locations & shipped maps

- `res://maps/*.map.json` — shipped maps. Currently: `PLAYGROUND`, `SIGMA_01`,
  `TEST_BLOCKS`, `TEXTURES` (bake fixture).
- `user://maps/*.map.json` — user/custom maps. **User id wins on collision.**
- Adding a map = dropping a `.map.json` in a scanned folder. No code
  registration required; the file-first catalog resolves any id from disk
  before consulting code generators.

## Format (D6)

JSON, sectioned, versioned — chosen over `.tres` because it is human-diffable,
git-friendly, and inert to parse (`load()` on user `.tres` is an execution
vector; `JSON.parse` is not).

```json
{
  "format": "infiltraitor-map",
  "schema_version": 3,
  "id": "SIGMA_01",
  "meta": { "title": "...", "author": "..." },
  "sections": { ... }
}
```

Coordinates are **internal** throughout; the buffer is applied only in
`MapCompiler` (architecture Rule 7). Each section carries its own `"v"`.

### Registered sections (map_sections_v1.gd)

| Section | Content |
|---|---|
| `board` | `inner_size`, `buffer`, `floor_tile` |
| `walls` | edge runs as `a→b` spans: `{a, b, material, storeys, facade}`; `"facade": null` = material default via `BakePolicy` (M6 prefix canon) |
| `blocks` | solid GU blocks: `{gu, storeys, material}` (BLOCK-01 vocabulary) |
| `props` | voxel props: `{def, gu, vox_offset, rot}` (PROP-01) |
| `actors` | `agent_start` + `guards` as **bare array-of-routes** (D16: `[[x,y],...]` per guard — no wrapper dict, no `class` field until guard AI needs it; richer config arrives later as a routine `v1→v2` section migration) |
| `legacy_compiler` | **D15 bridge:** flat cell/grid vocabulary `MapCompiler` natively understands (`wall_height`, `access_points`, `dividers`, `lights`). Keeps golden exports lossless until the compiler learns the native `walls`/`blocks`/`props` vocabulary end-to-end. |

### Reserved, not yet registered

`procedural` (`{generator, seed, params}`) and `patches` (ordered ops:
`set_wall_material`, `add_prop`, `remove_edge`, …) are schema-reserved from
plan §3.3 but have **no registered section owner yet** — files carrying them
round-trip verbatim as unknown sections (M3). Flow when implemented:
`generator(seed, params) → base spec → patches in order → MapCompiler`.
Generator ids are canon (D10): a generator whose output changes for old seeds
gets a new id (`shell_v2`), never a silent change.

## Invariants (M1–M7)

- **M1** — Map files are declarative data only; engine-derived state (compiled
  edges, slices, nav, bakes) is never serialized.
- **M2** — Every section is versioned with a total migration chain
  (`v(n)→v(n+1)` pure functions; upgrade in memory, rewrite on disk only on
  explicit save).
- **M3** — Tolerant round-trip: unknown sections/keys are preserved verbatim;
  files from newer builds survive older ones.
- **M4** — `_blocked_cells` single-writer (architecture rule, restated here
  because map loading is where violations historically crept in).
- **M5** — Props render via `set_cell()` only.
- **M6** — Facade filename prefix canon (`facade_<material>`).
- **M7** — Determinism: same file ⇒ same map, always (seed + patches included).

## Extension protocol

**New feature = new registered section.** Register an owner
(`{section_id, version, serialize, deserialize, migrations[]}`) with
`MapSectionRegistry`; the loader and saver pick it up with no core changes.
Do not widen an existing section for unrelated data, and do not parse JSON
ad hoc outside `MapFileService`.

Validation is loud-fail: post-load structural checks return the full error
list and `ok=false` — never repair silently, never half-load.

## Key decisions (full rationale in the archived plan)

| D | Decision |
|---|---|
| D6 | JSON sectioned/versioned over `.tres` |
| D10 | Generator ids are canon; behavior changes ⇒ new id |
| D13 | PNG is texture authoring canon; WebP-lossless accepted alternative; AVIF rejected |
| D15 | `legacy_compiler` bridge section until native vocabulary lands in `MapCompiler` |
| D16 | Guards schema = bare array-of-routes, ratified 2026-07-05 |
