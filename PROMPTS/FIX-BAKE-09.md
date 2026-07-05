# FIX-BAKE-09: Hotfix Round – Geometry Invariant, Data Contract, Seeds & Evidence

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-01..08 + VERIFY_FIX_BAKE_20260705
**Scope:** Single consolidated hotfix. Eight items, ordered by dependency. Items 1–4 are blockers; 5–7 are correctness/perf; 8 is evidence discipline.
**Effort:** ~4–5 hours
**Risk:** Medium (touches live seam path, but all changes are behind `BakeConfig.enabled = false` default)

---

## Context (read before coding)

The verification audit (VERIFY_FIX_BAKE_20260705) found that FIX-01/02/04/06/07/08 were substantially delivered, but:

- **The integer-shear assertion fires on ~50% of points on every face** with the shipped matrices. Any debug instantiation of `PerFaceProjector` halts. All test transcripts claiming otherwise are invalid.
- **Crucial mathematical finding:** the assertion was written in the **wrong direction**. The shipped forward matrices (flat→screen) have ±0.5 coefficients — non-integer for odd flat coords. But their **inverses (screen→flat) are exactly integer**:

  | Face | Forward M | Inverse M⁻¹ |
  |---|---|---|
  | NE | [[1, 0.5], [0, −0.5]] | [[1, 1], [0, −2]] |
  | SE | [[0.5, 0], [0.5, 0.5]] | [[2, 0], [−2, 2]] |
  | SW | [[1, −0.5], [0, 0.5]] | [[1, 1], [0, 2]] |
  | NW | [[−0.5, 0], [−0.5, 0.5]] | [[−2, 0], [−2, 2]] |

  The composite pipeline **iterates integer screen pixels and calls `screen_to_flat()`** — the inverse direction. NEAREST fidelity requires: *integer screen px → integer flat px*. That property **holds** with the shipped matrices. The forward direction is never iterated over texels anywhere in the pipeline.
- **The data contract between `room_builder._bake_textures()` and the compositor is broken**: Edge objects are consumed with Dictionary API (2-arg `Object.get()` = runtime error), `facade_id` is never assigned, `Edge` lacks `key_string()` and `get_owning_wall()`, and the variant seed formula differs between compositor and lookup (so keys could never match anyway).

Do NOT invent new matrices. Do NOT weaken any assertion to make it pass. Every item below has acceptance evidence that must be pasted literally.

---

## Item 1 — Geometry invariant: assert the direction the pipeline uses

### 1a. Replace the forward-direction shear assertion

In `per_face_projector.gd`, replace `_assert_integer_shear_all_faces()` / `_validate_face_shear()` with an **inverse-mapping integrity check**:

```gdscript
## Validate that the SAMPLING direction (screen → flat) is texel-exact.
## The composite pipeline iterates integer screen pixels and fetches flat texels;
## NEAREST fidelity requires integer screen coords to map to integer flat coords.
func _assert_inverse_integer_mapping_all_faces() -> void:
	print("[GEOMETRY] Validating inverse (screen→flat) integer mapping for all faces...")
	for face in [Face.NE, Face.SE, Face.SW, Face.NW]:
		_validate_face_inverse_mapping(face)
	print("[GEOMETRY] ✓ Inverse integer mapping validated for all faces\n")

func _validate_face_inverse_mapping(face: int) -> void:
	var face_name = ["NE", "SE", "SW", "NW"][face]
	var tolerance = 0.0001
	var failures: Array = []

	# 1. Inverse matrix entries must be integers (structural guarantee)
	var t = transforms[face]
	var M_inv = _invert_2x2(t["matrix"])
	for i in range(2):
		for j in range(2):
			var frac = absf(M_inv[i][j] - roundf(M_inv[i][j]))
			if frac > tolerance:
				failures.append("  M_inv[%d][%d] = %.6f (non-integer)" % [i, j, M_inv[i][j]])

	# 2. Offsets must be integers (so integer screen - offset stays integer)
	var off = t["offset"]
	if absf(off.x - roundf(off.x)) > tolerance or absf(off.y - roundf(off.y)) > tolerance:
		failures.append("  offset = (%.4f, %.4f) (non-integer)" % [off.x, off.y])

	# 3. Empirical sweep: every integer screen pixel in the 32×16 tile → integer flat coords
	for sy in range(0, 16):
		for sx in range(0, 32):
			var flat = screen_to_flat(face, Vector2(float(sx), float(sy)))
			var fx_frac = absf(flat.x - roundf(flat.x))
			var fy_frac = absf(flat.y - roundf(flat.y))
			if fx_frac > tolerance or fy_frac > tolerance:
				failures.append("  screen(%d,%d) → flat(%.4f, %.4f) fractional" % [sx, sy, flat.x, flat.y])

	if failures.is_empty():
		print("  ✓ [%s] Inverse matrix integer; all 512 screen px map to integer flat coords" % face_name)
	else:
		push_error("[%s] Inverse mapping FAILED: %d violations:" % [face_name, failures.size()])
		for msg in failures.slice(0, 5):
			push_error(msg)
		assert(false, "Inverse integer mapping FAILED for face %s" % face_name)
```

Call it from `_init()` (replacing the old call). **Keep it armed. Do not remove or soften it.**

With the current matrices, sanity check by hand before running: NE inverse [[1,1],[0,−2]], offset (0, 64) — both integer; integer screen − integer offset through an integer matrix stays integer. All four faces should pass **legitimately**. If any face fails, the matrices/offsets changed since the audit — stop and report, don't patch the test.

### 1b. Correct TILE_ANATOMY.md

Rewrite the invariant section of `docs/production/TILE_ANATOMY.md`:

- Delete the claim "All columns map to integer screen positions" and the "for even flat_y" hedge.
- State the real invariant: *"The sampling direction is screen→flat. All four inverse matrices are integer-valued and all offsets are integer, so every integer screen pixel fetches exactly one flat texel under NEAREST. The forward direction (flat→screen) has half-integer shear and is intentionally not iterated anywhere in the pipeline."*
- Add the inverse-matrix table (from the Context section above).
- Document the measured **flat coverage** of one screen tile per face (Item 2 output): the rectangle/parallelogram of flat coords actually touched by the 32×16 sweep. This replaces the unverified "128×128 → 32×16 compression" claim — describe what IS, as measured, not what was assumed.

---

## Item 2 — Probe-pattern coverage report (empirical, replaces guessed scale claims)

Add to `per_face_projector_test.gd` (or a new `fix_bake_09_coverage_test.gd`) a **coverage report**: for each face, sweep all 512 integer screen pixels through `screen_to_flat()` and report min/max flat_x and flat_y actually touched.

```gdscript
func _report_flat_coverage() -> void:
	print("[COVERAGE] Flat-space region touched by one 32×16 screen tile:")
	var projector = PerFaceProjectorClass.new()
	for face in [0, 1, 2, 3]:
		var face_name = ["NE", "SE", "SW", "NW"][face]
		var min_f = Vector2(INF, INF)
		var max_f = Vector2(-INF, -INF)
		for sy in range(16):
			for sx in range(32):
				var f = projector.screen_to_flat(face, Vector2(float(sx), float(sy)))
				min_f = Vector2(minf(min_f.x, f.x), minf(min_f.y, f.y))
				max_f = Vector2(maxf(max_f.x, f.x), maxf(max_f.y, f.y))
		print("  [%s] flat_x ∈ [%.0f, %.0f], flat_y ∈ [%.0f, %.0f]" % [face_name, min_f.x, max_f.x, min_f.y, max_f.y])
```

Paste this output verbatim into TILE_ANATOMY.md (Item 1b). Note: negative flat coordinates are expected and legal — the mirrored-repeat sampler folds them. The point of this report is to make the true window footprint canonical instead of the fictional "128×128" claim.

Keep the existing round-trip test (flat→screen→flat error < 0.1 px for all 4 faces).

---

## Item 3 — Edge API & data contract (unblocks enabled=true)

### 3a. Add the canonical key accessor to Edge

In `geometry/edge.gd`, add:

```gdscript
## Canonical string identity for hashing (baking, sampling).
## MUST be stable across runs: derived from GU coordinates, never from instance identity.
func key_string() -> String:
	return "E_%d_%d__%d_%d" % [gu_a.x, gu_a.y, gu_b.x, gu_b.y]
```

Adapt field names to the real ones in `edge.gd` (`gu_a`/`gu_b` or equivalents — check `WallEdgeData` canon; the edge key rule #3 says WallEdgeData is the sole edge-key source, so if a canonical key already exists there, `key_string()` must delegate to it rather than invent a second format).

### 3b. Build wall descriptors in `_bake_textures()` — do not feed raw Edge objects into Dictionary API

In `world/builders/room_builder.gd`, `_bake_textures()`:

```gdscript
# Build wall descriptors: the compositor consumes Dictionaries, by contract.
var wall_descriptors: Array = []
for edge in extraction.get("edges", []):
	wall_descriptors.append({
		"material_id": edge.material,          # Edge already carries material
		"facade_id": _facade_for_material(edge.material),
		"edge": edge,
	})

var map_spec = {
	"walls": wall_descriptors,
	"room_geometry": extraction.get("room_geometry", {}),
}
```

Add the facade assignment policy (v1: simple material→facade map; authorial values TBD, use safe defaults):

```gdscript
## v1 facade assignment: one default facade per material.
## Authorial per-wall overrides come later via map spec.
const DEFAULT_FACADES := {
	"concrete": "concrete_base",
	"stone": "stone_base",
	"wood": "wood_plank",
	"metal": "metal_sheet",
}

func _facade_for_material(material_id: String) -> String:
	return DEFAULT_FACADES.get(material_id, "")
```

Empty string → compositor skips that wall (already handled) → falls back to generic. That is the correct graceful degradation for unmapped materials.

Also propagate `facade_id` into the Slice (`slice.facade_id`) inside `SliceGenerator.generate()` or wherever slices are born from edges, so the render path carries it (currently the declared field is never written).

### 3c. Remove `get_owning_wall()` from the lookup path

In `baked_tile_lookup.gd`, `_make_bake_key()` must not call a method that exists only on mocks. Replace the wall backreference with direct reads:

```gdscript
func _make_bake_key(edge, face: int, _voxel_xy: Vector2i) -> BakeCompositorClass.BakeKey:
	# material: Edge carries it directly (real geometry). Mocks may expose get_material_id().
	var material_id: String = "default"
	if edge.has_method("get_material_id"):
		material_id = edge.get_material_id()
	elif "material" in edge:
		material_id = edge.material

	# facade: same policy as the bake pass — MUST match room_builder._facade_for_material().
	var facade_id: String = BakePolicy.facade_for_material(material_id)
	...
```

To guarantee the bake pass and the lookup pass use the **same** facade policy, extract `_facade_for_material()` into a small shared static (`systems/bake_policy.gd`, e.g. `class_name BakePolicy` with `static func facade_for_material()` and the `DEFAULT_FACADES` const), used by both `room_builder` and `baked_tile_lookup`. Divergence here = silent lookup misses.

Update `baked_tile_lookup_test.gd` mocks accordingly (mocks may keep `get_material_id()`; delete `get_owning_wall()` from MockEdge/MockWall).

---

## Item 4 — Unify variant seeding (one formula, one place)

Add to `BakePolicy` (from 3c):

```gdscript
## Deterministic variant selection. Stable across runs: NEVER uses instance identity.
static func variant_for(edge, material_id: String) -> int:
	var edge_key: String = edge.key_string() if edge.has_method("key_string") else str(edge)
	return abs(("%s_%s" % [edge_key, material_id]).hash()) % 4
```

Replace **both** call sites:
- `bake_compositor.gd` `_populate_bake_set()`: delete `hash(str(edge) + "_" + material_id)`; call `BakePolicy.variant_for(edge, material_id)`.
- `baked_tile_lookup.gd` `_make_bake_key()`: same call.

Note `String.hash()` is deterministic across runs in Godot (unlike `hash()` on Objects via `str(edge)` instance addresses). The window origin must also be seed-compatible: both sides already call `get_window_origin_isolated_texels(edge, facade_id)` — verify both pass the **same facade_id** (guaranteed by BakePolicy in Item 3c).

---

## Item 5 — Remove the byte-mask origin collapse

In `facade_sampler.gd`, `_window_origin_isolated_texels()`:

```gdscript
# OLD (collapses to [0,256) of [0,1024) and [0,256) of [0,512)):
var plane_col_texels = ((hash_val >> 0) & 0xFF) % (64 * N)
var plane_row_texels = ((hash_val >> 8) & 0xFF) % (32 * N)

# NEW (full range, two independent bit windows of the 32-bit hash):
var plane_col_texels = hash_val % (64 * N)
var plane_row_texels = (hash_val >> 16) % (32 * N)
```

Update `fix_bake_02_sampler_test.gd` (or equivalent) distribution test: with 200 sampled edges, assert that at least one origin has `x >= 512` and at least one has `y >= 256` — this is the regression trap for the byte-mask (statistically certain with full range; impossible with the mask).

---

## Item 6 — B3: canonical silhouette alpha

The material tile currently hard-sets `pixel.a = 1.0` and the composite preserves it → baked tiles are opaque rectangles. Import the canonical silhouette:

1. In `_get_material_tile()`, after computing the RGB, fetch the alpha for (screen_x, screen_y) from the **canonical voxel tile silhouette** — the same 32×16 mask used by the generic material tileset. Source it from wherever the tileset builder defines the diamond mask (check `build_voxel_tileset.gd` / the material tileset's source texture). Implementation options, in order of preference:
   - (a) Load the canonical material tile Image once (cache as a static), copy its per-pixel alpha.
   - (b) If no PNG is loadable headless, replicate the analytic diamond mask from the tileset builder code (do NOT invent a new shape — copy the builder's formula).
2. `_composite_tile()` keeps `result_pixel.a = mat_pixel.a` (already does).
3. Add to the FIX-04 test: assert the baked tile has **both** fully-opaque pixels (a > 0.99) **and** fully-transparent pixels (a < 0.01), proving a silhouette exists:

```gdscript
var has_opaque := false
var has_transparent := false
for y in range(16):
	for x in range(32):
		var a = composite.get_pixel(x, y).a
		if a > 0.99: has_opaque = true
		elif a < 0.01: has_transparent = true
assert(has_opaque and has_transparent, "B3: baked tile must carry canonical silhouette (opaque + transparent regions)")
print("    ✓ B3: silhouette present (opaque + transparent pixels)")
```

---

## Item 7 — Cache hot-path objects

1. `geometry/voxel_renderer.gd`: promote to members, initialized once (lazy or in `_ready`/setup):
```gdscript
var _bake_config = null       # Script ref, loaded once
var _baked_lookup = null      # BakedTileLookup instance, created once
```
`_set_voxel_cell()` uses the cached members; no `load()` or `.new()` per cell.
2. `baked_tile_lookup.gd`: cache the FacadeSampler as a member (`var _sampler = FacadeSamplerClass.new()` at class level or `_init`), and cache the BakeConfig script ref (kill the per-resolve `load()`).
3. In `facade_sampler.gd`, hoist the two function-local `const GeometryCoordsClass = preload(...)` to class level (single preload; also removes a per-call load).

---

## Item 8 — Evidence discipline (non-negotiable)

Deliverables for this prompt's PASS:

1. **Full headless run, raw console pasted**, of: `per_face_projector_test.gd` (or `fix_bake_09_coverage_test.gd`), `facade_sampler_test.gd`, `bake_compositor_test.gd`, `baked_tile_lookup_test.gd`, `bake_selftest.gd`. The output MUST include the literal line:
   ```
   [GEOMETRY] ✓ Inverse integer mapping validated for all faces
   ```
   and the `[COVERAGE]` block with four faces.
2. **One red run** (required by FIX-07 spec, skipped last time): temporarily corrupt one inverse-matrix entry (e.g. change a matrix coefficient from 0.5 to 0.51), run `per_face_projector_test.gd`, paste the failure output showing `push_error` + assertion, then revert and paste the green run. Both transcripts go in the completion report.
3. **Lookup hit proof end-to-end**: a test that (a) builds wall descriptors the way `_bake_textures()` does, using a real `Edge` instance (not a mock), (b) runs `compositor.bake()`, (c) sets `GLOBAL_BAKED_ATLAS` + `BAKED_ATLAS_SOURCE_IDS`, (d) calls `BakedTileLookup.resolve()` with the **same real Edge**, and (e) asserts the result is a **baked hit** (`source_id_string.begins_with("BAKED_ATLAS_")`), not the generic fallback. This single test exercises Items 3, 4, 5 together — it is the acceptance test of the whole hotfix.
4. Rectify `PROMPTS/DONE/RESUMO_SESSAO_20260704_BAKE_FIX.md`: append a "CORRECTION (FIX-BAKE-09)" section stating that the FIX-03 and selftest transcripts in the original summary were invalid (projector assertion could not pass with shipped code), superseded by this hotfix's evidence. Do not delete the original text — the record of the failure is part of the record.
5. Do NOT enable baking by default. `BakeConfig.enabled = false` stays.

---

## Implementation Checklist

- [ ] Item 1a: replace forward shear assert with inverse integer-mapping assert; keep armed in `_init()`
- [ ] Item 1b: rewrite TILE_ANATOMY.md invariant section (+ inverse table, + coverage numbers from Item 2)
- [ ] Item 2: coverage report in projector test; paste output into doc
- [ ] Item 3a: `Edge.key_string()` (delegating to WallEdgeData canon if one exists)
- [ ] Item 3b: wall descriptors in `_bake_textures()`; `BakePolicy` with `DEFAULT_FACADES`; propagate `facade_id` into Slice
- [ ] Item 3c: remove `get_owning_wall()` from `_make_bake_key()`; direct reads + BakePolicy; update mocks
- [ ] Item 4: `BakePolicy.variant_for()`; replace both seed call sites
- [ ] Item 5: remove `& 0xFF` masks; add distribution regression assertions
- [ ] Item 6: canonical silhouette alpha; opaque+transparent assertion
- [ ] Item 7: cache config/lookup/sampler; hoist local preloads
- [ ] Item 8: full green transcripts + one red transcript + end-to-end lookup-hit test + RESUMO correction
- [ ] Run `python3 tools/persistent/check_invariants.py` (must stay green)
- [ ] Bump VERSION per convention

---

## Out of scope (unchanged decisions)

- GPU batch remains deferred (pending authorial ratification of CPU-primary vs D4).
- Run continuity remains a placeholder (v1.5, Edge Registry adjacency).
- Face-exposure culling in `_populate_bake_set()` (currently bakes all 4 faces per wall) — acceptable waste for v1; note as TODO.
- Multi-storey facade rows (row 0 only).

---

*End FIX-BAKE-09.*
