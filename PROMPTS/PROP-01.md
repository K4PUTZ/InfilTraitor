# PROP-01: VoxelProp — Crate MVP & PropDef/PropRegistry Plumbing

**Status:** Ready for implementation
**Predecessor:** BLOCK-01b (verified — `start_storey`/Edge/Slice pipeline stable; MAP_MATTRESS §2.1 closed), MAPFILE-02 (verified — flagged this exact gap, see Item 0-C)
**Successor:** PLAYGROUND-02 (District E — Crate Yard — is the first real visual QA for this prompt's output)
**Scope:** `PropDef` resource format + `PropRegistry` (res:// defaults + user:// override, D9), a `crate_full` PropDef, a voxel renderer entry point that fills a prop's footprint the same way solid blocks do, and the missing `.map.json` → `MapCompiler` translation for the native `props` section that MAPFILE-01 already registered but nothing consumes yet.
**Effort:** ~4 hours
**Risk:** Low-medium (new, isolated subsystem; the one shared-file touch is `MapCompiler.compile()`, additive only — no existing branch is modified)

---

## Item 0 — Mandatory ground truth (read before writing any code)

Three things this prompt depends on were verified directly in the repo; if any of your own checks disagree, **stop and report** rather than silently reconciling.

### Finding A — `VOXELS_PER_UNIT_AXIS = 8` is the XY micro-grid, not a Z-height

`geometry_coords.gd:6`. `GeometryCoords.gu_voxels(gu_cell) -> Array[Vector2i]` returns the 8×8=64 micro-cell XY positions inside one GU footprint (`geometry_coords.gd:56-61`). Height is expressed **only** in whole storeys — one `level` in `VoxelRenderer` is one entire `TileMapLayer` (one storey), not a sub-storey Z-slice. `render_block()` already fills all 64 XY positions at every storey in `[start_level, start_level+storey_span)` (`voxel_renderer.gd:121-130`) — this is the exact mechanic a full-cube prop needs.

**Consequence for `PropDef.layers`:** the master plan's `size_vox: [8,8,8]` / per-Z-level bitmask schema (§2.2) is **authoring-forward data for the future destruction phase**, which needs true per-voxel Z granularity to "peel" a crate one voxel at a time (§2.3: destruction is ~1 voxel/shot, cover degrades continuously). The engine has no renderer for that granularity today, and building one is explicitly **not** this prompt's job — §2.3 says outright: *"PROP-01 v1 ships crates with a static declared `cover` value; the dynamic ladder lands with destruction."*

**Ratified scope decision (so you don't have to guess):** `PropDef` stores `size_vox` and `layers` verbatim (schema fidelity for the future importer/PropGen/destruction consumers), but the v1 **renderer only consumes**: `footprint_gus` (which GU cells it occupies) and `storeys` (derived as `1` for `crate_full` — a full-height single-storey solid, matching "8-voxel height intact = FULL cover" in the §2.3 table, where "8 voxels" is the *future* destruction-phase unit, not a storey count here). Render a full-footprint prop with a thin wrapper around the same fill mechanic `render_block()` already uses — do not build a per-Z-slice renderer. If you find a reason this reading is wrong (e.g. a prop that must literally span 2 storeys visually in this prompt's own test), stop and report before improvising a different renderer.

### Finding B — the runtime-spec key must be `voxel_props`, not `props`

`MapCompiler.compile()` already consumes a **legacy, sprite-based** `spec.get("props", [])` (flat dicts: `cell`, `tile`, `stack`, `height` — see `map_compiler.gd:20-21,144-159`), which feeds the existing prop-stack sprite layers (`_prop_stack_layers`, `_ensure_prop_stack_layers` in `room_builder.gd`). This is a **different, pre-existing feature** — do not touch it, do not reuse its key.

The MAPFILE `props` *section* (registered already in `map_sections_v1.gd:76-88`, schema v1, `{"items": [...]}`) uses the master-plan shape from §3.2: `{"def": "crate_full", "gu": [9,4], "vox_offset": [0,0], "rot": 0}` — same key name (`props`), **incompatible shape**. `FileMapSource._translate_to_runtime_spec()` already has the stub for this, verbatim:

```gdscript
# --- Loud, non-blocking warning for sections that exist but have no translator yet ---
for future_section in ["walls", "props"]:
    ...
    push_warning("[FileMapSource] Map '%s' has non-empty '%s' section with no MapCompiler translation yet (pending BLOCK-01/PROP-01) — ignored" % ...)
```

**Ratified naming (same pattern BLOCK-01 used for `solidblock_` vs. legacy `block_SE`):** translate the `props` *section*'s items into a **new** runtime spec key, `voxel_props`, so it never collides with the legacy sprite `props` key at the `MapCompiler.compile()` level. `MapCompiler` gains a new loop reading `spec.get("voxel_props", [])`, parallel to (not replacing) its existing `spec.get("props", [])` sprite loop.

### Finding C — `_blocked_cells` single-writer (M4) still applies

`MapCompiler.compile()`'s local `blocked_map: Dictionary` is the only writer during compilation (existing pattern: dividers, blocks, and legacy props all check-then-set into it before returning `blocked_cells`). Your new `voxel_props` loop must follow the exact same pattern — check `blocked_map.has(cell)` before placing, then set it — never introduce a second blocked-cells collection.

---

## Item 1 — `PropDef` resource

New file: `godot/scripts/systems/prop_def.gd`

```gdscript
class_name PropDef

var id: String
var size_vox: Vector3i          # authoring-forward; not consumed by the v1 renderer (Finding A)
var layers: Array               # authoring-forward; not consumed by the v1 renderer (Finding A)
var material_zones: Dictionary  # {"default": "wood", ...}
var footprint_gus: Array        # Array[Vector2i] — GU cells (relative to placement anchor) this prop occupies
var storeys: int = 1            # how many storeys tall the *rendered* solid is (v1: full-height fill only)
var gameplay: Dictionary        # {"cover": "full"|"half"|"quarter"|"none", "destructible": bool}
var tags: Array                 # Array[String]

static func from_json(data: Dictionary) -> PropDef:
    var def := PropDef.new()
    def.id = String(data.get("id", ""))
    var sv = data.get("size_vox", [8, 8, 8])
    def.size_vox = Vector3i(int(sv[0]), int(sv[1]), int(sv[2]))
    def.layers = data.get("layers", [])
    def.material_zones = data.get("material_zones", {"default": "concrete"})
    def.footprint_gus = []
    for fp in data.get("footprint_gus", [[0, 0]]):
        def.footprint_gus.append(Vector2i(int(fp[0]), int(fp[1])))
    def.storeys = int(data.get("storeys", 1))
    def.gameplay = data.get("gameplay", {"cover": "none", "destructible": false})
    def.tags = data.get("tags", [])
    return def
```

Field names, defaults, and the `from_json` factory are not prescriptive line-by-line — match the existing `MaterialRegistry.MaterialDef` style (`material_registry.gd:24-33`) for consistency. Keep `size_vox`/`layers` as plain data fields even though v1 doesn't render from them — deleting them now would just have to be re-added for the destruction phase.

## Item 2 — `PropRegistry`

New file: `godot/scripts/systems/prop_registry.gd`. Mirror `MaterialRegistry`'s `register()`/`get_material()`/`list_materials()`/`count()` shape (`material_registry.gd:36-58`) with prop-appropriate names (`register()`, `get_prop(id) -> PropDef`, `list_props()`, `count()`).

Add directory-scan loading (D9, ratified — `user://props/` overrides `res://props/` on id collision, same tier rule as `MaterialRegistry`'s texture resolver and `MapCatalog`'s `FileMapSource`):

```gdscript
func load_from_disk() -> void:
    _scan_dir("res://props")
    _scan_dir("user://props")  # loaded second — overwrites on id collision, i.e. wins

func _scan_dir(dir_path: String) -> void:
    var dir = DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var fname = dir.get_next()
    while fname != "":
        if fname.ends_with(".json"):
            var file = FileAccess.open(dir_path.path_join(fname), FileAccess.READ)
            if file:
                var parsed = JSON.parse_string(file.get_as_text())
                file.close()
                if typeof(parsed) == TYPE_DICTIONARY:
                    register(PropDef.from_json(parsed))
        fname = dir.get_next()
```

**Boot wiring:** there is currently no real game-boot call site for `MaterialRegistry.register_defaults()` either — it's only invoked from tests and lazily published via `Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", ...)` (`bake_compositor.gd:337-340`; every real call site is in `godot/scripts/tools/*_test.gd`). Match this exact precedent for consistency rather than inventing a different DI mechanism: publish the loaded registry as `Engine.set_meta("GLOBAL_PROP_REGISTRY", registry)` from the same place a test or future boot script would call `MaterialRegistry.register_defaults()`. Do not invent a new autoload singleton — this is a pre-existing, pre-BakeConfig-go-live gap (see `OPERATOR_CONTEXT.md` go-live blockers), not something this prompt should fix project-wide.

## Item 3 — `crate_full` PropDef (the MVP content)

New file: `res://props/crate_full.json`. One full GU, one storey, wood, full cover, destructible (§2.3 cover ladder's top rung):

```json
{
  "id": "crate_full",
  "size_vox": [8, 8, 8],
  "layers": [
    "11111111/11111111/11111111/11111111/11111111/11111111/11111111/11111111"
  ],
  "material_zones": { "default": "wood" },
  "footprint_gus": [[0, 0]],
  "storeys": 1,
  "gameplay": { "cover": "full", "destructible": true },
  "tags": ["crate", "cover", "container"]
}
```

## Item 4 — `VoxelRenderer.render_prop()`

`godot/scripts/geometry/voxel_renderer.gd`, new method, thin wrapper honoring Finding A (reuse the exact fill mechanic `render_block` already proved out, named for what it is):

```gdscript
## Render a VoxelProp's footprint as a full solid fill (v1: whole-storey granularity only;
## sub-storey/partial-layer rendering is deferred to the destruction phase — see PROP-01 Item 0-A).
func render_prop(gu_cell: Vector2i, start_storey: int, prop_def: PropDef) -> void:
    var material_name: String = prop_def.material_zones.get("default", "concrete")
    for footprint_offset in prop_def.footprint_gus:
        render_block(gu_cell + footprint_offset, start_storey, prop_def.storeys, material_name)
```

No `edge` argument (props are not wall/facade geometry — same no-edge, material-only fallback path `render_block` already takes; theming still applies automatically since `ThemeApplier`'s `modulate` is per voxel *layer*, not per-edge — nothing extra to wire here).

## Item 5 — Wire the `props` section through `FileMapSource` and `MapCompiler`

**`file_map_source.gd`**, replace the `props` half of the existing warning-only stub (leave the `walls` half untouched — that's BLOCK-... no, that's a future prompt, not this one — actually walls translation already ships via native `blocks`/BLOCK-01, only the *warning* loop's `props` entry is what you're replacing here; confirm with a quick read before editing, don't assume `walls` needs touching):

```gdscript
# --- Props section: now translatable (PROP-01 implementation) ---
var props_section = sections.get("props", {})
if props_section.get("items", []).size() > 0:
    var voxel_props: Array = []
    for item in props_section["items"]:
        voxel_props.append(item)  # already {def, gu, vox_offset, rot} shape post JSON-coercion-reversal
    runtime["voxel_props"] = _convert_from_json_compatible(voxel_props)
```

**`map_compiler.gd`**, new loop, placed near the existing `blocks` loop (after it, before the props/structure_tiles block — read the surrounding code first, don't guess the exact line):

```gdscript
## --- voxel props (crates etc.) — native PropDef-driven, distinct from legacy sprite "props" ---
for prop_item: Dictionary in spec.get("voxel_props", []):
    var cell: Vector2i = Vector2i(prop_item.get("gu", Vector2i.ZERO)) + offset
    if blocked_map.has(cell):
        continue
    voxel_prop_instances.append({
        "gu_cell": cell,
        "def_id": String(prop_item.get("def", "")),
        "storey": 0,
    })
    blocked_map[cell] = true
```

(`voxel_prop_instances` is a new local `Array`, added to the function's `result` dict as a new key, e.g. `"voxel_prop_instances"`, alongside `structure_tiles`/`blocked_cells`/etc.) `vox_offset` and `rot` are accepted in the section schema (§3.2) but **not applied** in v1 since `crate_full`'s footprint is a symmetric single GU — record them on the compiled instance dict for forward compatibility, don't implement offset/rotation math this prompt doesn't need yet.

**`room_builder.gd`**, new method mirroring `_render_solid_blocks()`'s shape (`room_builder.gd:272-318`) but resolving through `PropRegistry` instead of a raw material string:

```gdscript
func _render_voxel_props(instances: Array) -> void:
    if instances.is_empty():
        return
    var registry = _get_prop_registry()  # same Engine.get_meta lookup pattern as _get_material_registry()
    for instance in instances:
        var prop_def: PropDef = registry.get_prop(instance.get("def_id", ""))
        if prop_def == null:
            push_warning("[RoomBuilder] Unknown prop def '%s' — skipped" % instance.get("def_id", ""))
            continue
        room._voxel_renderer.render_prop(instance["gu_cell"], instance.get("storey", 0), prop_def)
        _prop_cover[instance["gu_cell"]] = prop_def.gameplay.get("cover", "none")
```

Call it from `build_from_layout()` alongside the existing `_render_solid_blocks(extraction.get("solid_blocks", []))` call (`room_builder.gd:74`) — same `if not extraction...is_empty()` branch, since props also need the voxel layers to exist. Add `var _prop_cover: Dictionary = {}` next to `_prop_heights` (`room_builder.gd:15`) and a `get_prop_cover() -> Dictionary` getter next to `get_prop_heights()` (`room_builder.gd:130`) — static data only, no TIC/exposure-class wiring (that's the OCCLUSION & DESTRUCTION phase, out of scope here per §2.3).

---

## Acceptance Criteria (assertion-backed, real execution evidence only — no "PASS" from code reading)

1. **`PropDef.from_json` round-trips `crate_full.json`** — a test loads the file, asserts `id == "crate_full"`, `footprint_gus == [Vector2i(0,0)]`, `gameplay["cover"] == "full"`.
2. **`PropRegistry` two-tier override** — isolated test: register a `res://`-tier prop, then a `user://`-tier prop with the same id but a different `material_zones.default`; assert `get_prop(id)` returns the `user://` version (mirrors the existing texture-resolver override test pattern).
3. **`render_prop()` produces the same voxel footprint as `render_block()` for an equivalent full cube** — isolated test comparing voxel counts (64 XY positions × 1 storey) for both call paths; assert equal, proving no accidental scope narrowing (partial fill) crept into the wrapper.
4. **End-to-end compile**: a test map spec with one `voxel_props` entry (`{"def": "crate_full", "gu": [x,y]}`) compiles via `MapCompiler.compile()`; assert `voxel_prop_instances` is non-empty, the target cell appears in `blocked_cells`, and the legacy sprite `structure_tiles`/`props` path is **not** affected (regression check — compile a spec with both a legacy sprite prop and a voxel prop, assert both render paths produce their expected entries independently).
5. **`.map.json` round-trip**: extend one golden export (or add a new small fixture map) with a `props` section entry in the `{def, gu, vox_offset, rot}` shape; confirm `FileMapSource.get_runtime_spec()` produces `voxel_props` (not `props`) in the translated runtime spec, and that loading it through `MapCompiler.compile()` places the crate and blocks its cell. Real console output, not narrated.
6. **`check_invariants.py` and `map_lint.gd`** both executed post-change; verbatim output pasted; must show no new violations (M4 single-writer, M5 props-render-via-set_cell-only).
7. **Non-regression**: SIGMA_01 and PLAYGROUND golden maps still compile/render identically (same blocked-cell count, same light/tile-semantics numbers as BLOCK-01b's baseline) — this prompt adds a new code path, it must not perturb existing maps that have no `voxel_props` section.

Every criterion above gets its own verbatim transcript in the completion report — per `OPERATOR_CONTEXT.md`'s Evidence & Reporting Discipline, "deferred"/"assumed"/"narrated" is not a passing state, and the self-check before writing "✅ Complete" applies here as everywhere else.

---

## Explicitly out of scope (deferred, do not implement)

- Sub-storey / per-Z-voxel rendering from `PropDef.layers` (destruction phase).
- Dynamic cover ladder, TIC exposure-class wiring, cover glyphs (destruction phase, §2.3).
- `vox_offset`/`rot` actually repositioning/rotating the footprint (record only; no math).
- `.vox` importer / parametric `PropGen` (deferred `PROP-REG-01`).
- Retiring the legacy sprite `props`/`structure_tiles` path — it stays, untouched, indefinitely.

---

*End PROP-01 prompt.*
