# MAT-DEFAULTS-01: Texture Supply Gaps, Live Wiring Fix & Linear-Light Blend

**Status:** Ready for implementation
**Predecessor:** MAP_MATTRESS_MASTER_PLAN v1.1 (D1, D2, D11, D13, G1–G4)
**Successor:** MAPFILE-01 / BLOCK-01 (parallel)
**Scope:** Close G1–G4 so authorial texture files actually work end-to-end; implement the D11 linear-light blend as BakeConfig's default; add WebP as an accepted authoring format.
**Effort:** ~3 hours
**Risk:** Low (additive fixes + one blend-formula swap behind BakeConfig, still gated by `enabled=false`)

---

## Context

Four gaps were identified while planning the texture-supply contract. None of Matt's future PNGs, none of the four default materials, and none of the live bake path currently function — even though the FIX-BAKE-09b E2E test genuinely passes (its hand-built spec sidesteps all four gaps). This prompt closes them together because they're small and interdependent; splitting them would multiply prompt overhead for no isolation benefit.

**Stop-and-report rule (repeated because it was violated twice in the BAKE saga):** if any measurement, matrix, or transform value you compute differs from what's stated in this prompt, halt and report the discrepancy — do not silently reconcile it by editing the code to match the doc or vice versa.

---

## Item 1 (G1) — Facade filename canon

`systems/bake_policy.gd`, `DEFAULT_FACADES`:

```gdscript
# OLD:
const DEFAULT_FACADES := {
	"concrete": "concrete_base",
	"stone": "stone_base",
	"wood": "wood_plank",
	"metal": "metal_sheet",
}

# NEW:
const DEFAULT_FACADES := {
	"concrete": "facade_concrete",
	"stone": "facade_stone",
	"wood": "facade_wood",
	"metal": "facade_metal",
}
```

This is the sole source both `room_builder._bake_textures()` and `baked_tile_lookup._make_bake_key()` already consume via `BakePolicy.facade_for_material()` — one edit, both sides updated automatically (this is precisely what BakePolicy was built for in FIX-BAKE-09).

## Item 2 (G2) — Register default materials at boot

Add to `systems/material_registry.gd`:

```gdscript
## Populate the registry with the four canon materials (MAP_MATTRESS D2).
## Call once at boot (and at the top of any test that needs materials).
func register_defaults() -> void:
	register(MaterialDef.new("concrete", Color(0.62, 0.62, 0.62), StonePatternClass.new()))
	register(MaterialDef.new("stone",    Color(0.55, 0.55, 0.58), StonePatternClass.new()))
	register(MaterialDef.new("wood",     Color(0.66, 0.47, 0.31), WoodPatternClass.new()))
	register(MaterialDef.new("metal",    Color(0.49, 0.53, 0.56), MetalPatternClass.new()))
```

(Colors are `#9E9E9E`, `#8D8D95`, `#A8794F`, `#7E8790` converted to 0–1 floats — verify conversion, don't eyeball it.)

Preload the three pattern classes at the top of the file (`StonePatternClass`, `WoodPatternClass`, `MetalPatternClass` — match whatever `class_name`/file path they already have in `systems/stone_pattern.gd` etc.).

**Call site:** wherever the game boots its systems (autoload or `room_builder.setup()` — whichever the codebase treats as "boot" per existing convention), instantiate `MaterialRegistry`, call `register_defaults()`, and publish it the same way `GLOBAL_MATERIAL_REGISTRY` is already published for tests (`Engine.set_meta`). If no clear boot autoload exists yet, add the call at the top of `room_builder._bake_textures()` guarded by a `if registry.registry.is_empty(): registry.register_defaults()` — idempotent, safe to call every map load.

## Item 3 (G3) — Purge the `_render_solid_blocks` split-brain

`grep -n "_render_solid_blocks" -r godot/scripts` currently shows both `room.gd:1411` and `room_builder.gd:272`. **Investigated and resolved (do not re-litigate):** these are not equivalent implementations with a cosmetic location difference — one of them is dead/broken code.

**Ground truth check:** `EdgeExtractor.extract()` (`geometry/edge_extractor.gd:88–95`) is the sole producer of the `solid_blocks` array, and it emits:
```gdscript
{ "gu_cell": cell, "storey": storey, "voxel_origin": ..., "material": material, "tile_name": tile_name }
```
`room.gd`'s implementation reads `gu_cell` / `storey` / `material` — matches exactly. `room_builder.gd`'s implementation reads `cell` / `storeys` — **keys that don't exist in the real payload**; it has always silently no-op'd (sentinel cell, default storeys=1) in the one call site that feeds it. This is the same class of bug as Item 4 (G4): two producers/consumers, mismatched shape, one dead.

Second, independent reason to prefer room.gd's version: it renders through `_voxel_renderer.render_block()`, which internally calls `_set_voxel_cell()` (Rule #8) — the only path that gets baking, theming, and destructibility for free per the master plan §2.1. `room_builder`'s version renders through `_place()` into `_wall_upper_layers` — the pre-voxel `TileMapLayer` fallback system, explicitly called out as legacy in `room.gd`'s own comment at line 1585 ("*the active render now comes from the edge seam's voxel geometry integration*").

**Decision (ratified):**
1. **Port** room.gd's implementation — the per-storey material grouping, contiguous-run decomposition, and `_voxel_renderer.render_block()` call — into `room_builder.gd`, replacing its broken stub. This serves the ongoing modularization (logic moves into room_builder) while fixing the field-name bug at the same time.
2. Delete the ported-from copy in `room.gd`.
3. Verify `_place()` and `_wall_upper_layers` (the legacy fallback layer system) have no other live callers before removing them; if they do, leave them in place and note it — don't cascade-delete beyond this function's scope.
4. Confirm `room_builder`'s copy still fires from the same guarded call site room.gd used (`if not extraction.get("edges", []).is_empty(): ... _render_solid_blocks(extraction.get("solid_blocks", []))`) — the voxel path must remain "the only active renderer when it has data."

## Item 4 (G4) — Live bake wiring: extractor accepts the room_builder shape

**Root cause:** `BakeCompositor._extract_walls_from_spec()` reads `map_spec.wall_tiles` (array) or `map_spec.room_geometry.walls` (array). `room_builder._bake_textures()` sends a top-level `"walls"` key (line ~186, confirmed in v0.4.9) and never populates `room_geometry.walls`. Neither branch matches → the live path always bakes an empty set → `enabled=true` in real gameplay silently does nothing (not crash — worse, silent no-op).

**Fix**, `bake_compositor.gd`:

```gdscript
func _extract_walls_from_spec(map_spec: Dictionary, geometry) -> Array:
	var walls = []

	if map_spec.has("wall_tiles"):
		for wall_tile in map_spec["wall_tiles"]:
			walls.append(wall_tile)

	if map_spec.has("walls"):                    # NEW: room_builder's actual shape
		for wall in map_spec["walls"]:
			walls.append(wall)

	if geometry and geometry.has("walls"):
		for wall in geometry["walls"]:
			walls.append(wall)

	return walls
```

**Regression test (mandatory — this is the bug a hand-built E2E spec cannot catch):** add to `bake_compositor_test.gd` a case that builds the spec **exactly as `room_builder._bake_textures()` does** (top-level `"walls"` array of `{material_id, facade_id, edge}` dicts, no `wall_tiles`, no populated `room_geometry`), calls `compositor.bake()`, and asserts `bake_set.size() > 0` and `pages.size() > 0`:

```gdscript
func test_live_shape_wiring() -> void:
	print("[LIVE-WIRING] room_builder-shaped spec must bake\n")
	var map_spec = {
		"walls": [ { "material_id": "stone", "facade_id": "facade_stone", "edge": _mock_edge("e0") } ],
	}
	var compositor = BakeCompositorClass.new()
	var resolver = TextureResolverClass.new()
	var atlas = compositor.bake(map_spec, resolver)
	assert(atlas.pages.size() > 0, "Live-shaped spec produced ZERO pages — G4 regression")
	print("  ✓ Live-shaped spec bakes: %d pages\n" % atlas.pages.size())
```

This test is the permanent guard against this exact class of "two producers, two shapes" bug recurring.

## Item 5 (D11) — Linear-light blend, wired through BakeConfig

`BakeConfig` already declares a `BlendMode` enum (`MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY_EXPERIMENTAL`) defaulting to `MULTIPLY`. Extend it rather than replacing it — this preserves the escape hatch the plan's D11 reservation explicitly wants (switch back to overlay/multiply is a one-line config change, not a re-architecture):

```gdscript
# bake_config.gd
enum BlendMode { MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY_EXPERIMENTAL, LINEAR_LIGHT }
static var blend_mode: BlendMode = BlendMode.LINEAR_LIGHT   # NEW canon default (D11)
```

`bake_compositor.gd`, `_composite_tile()` — replace the hardcoded multiply with a branch on `BakeConfig.blend_mode`:

```gdscript
# OLD:
# var result_pixel = Color(
#     mat_pixel.r * facade_lum, mat_pixel.g * facade_lum, mat_pixel.b * facade_lum, mat_pixel.a
# )

# NEW:
var result_pixel: Color
match BakeConfig.blend_mode:
	BakeConfig.BlendMode.LINEAR_LIGHT:
		result_pixel = Color(
			clampf(mat_pixel.r + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
			clampf(mat_pixel.g + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
			clampf(mat_pixel.b + 2.0 * (facade_lum - 0.5), 0.0, 1.0),
			mat_pixel.a
		)
	BakeConfig.BlendMode.OVERLAY_EXPERIMENTAL:
		result_pixel = Color(
			_overlay_channel(mat_pixel.r, facade_lum),
			_overlay_channel(mat_pixel.g, facade_lum),
			_overlay_channel(mat_pixel.b, facade_lum),
			mat_pixel.a
		)
	_:  # MULTIPLY and anything else: preserve the original behavior exactly
		result_pixel = Color(
			mat_pixel.r * facade_lum, mat_pixel.g * facade_lum, mat_pixel.b * facade_lum, mat_pixel.a
		)

# Helper (new):
func _overlay_channel(base: float, f: float) -> float:
	if base < 0.5:
		return clampf(2.0 * base * f, 0.0, 1.0)
	return clampf(1.0 - 2.0 * (1.0 - base) * (1.0 - f), 0.0, 1.0)
```

**Tier-3 identity property (must hold and be tested):** when no facade file resolves, the compositor's fallback path must feed `facade_lum = 0.5` — verify the existing Tier-3 path already does this (check what `sampler.sample()` returns for a null/absent facade Image, or wherever the compositor branches on `Tier.NONE`); if it currently defaults to something else (e.g. `1.0`, appropriate for the old multiply-neutral), **that constant must change to 0.5** or Tier-3 rendering will darken/shift under the new blend. This is exactly the kind of silent-regression seam that bit the project before — check it explicitly, don't assume.

## Item 6 (D13) — WebP as an accepted authoring format

`systems/texture_resolver.gd`, `resolve()`: after the `.png` attempt fails at each tier, probe `.webp` before falling through to the next tier:

```gdscript
func resolve(texture_id: String) -> ResolvedTexture:
	_log("")
	_log("Attempting to resolve: %s" % texture_id)

	for ext in [".png", ".webp"]:
		var user_path := tex_user_dir.path_join(texture_id + ext)
		var img := _try_load_and_validate(user_path, "USER")
		if img:
			_log("[RESOLVER] %s resolved from USER%s (dims %dx%d)" % [texture_id, ext, img.get_width(), img.get_height()])
			return ResolvedTexture.new(img, Tier.USER)

	for ext in [".png", ".webp"]:
		var default_path := tex_default_dir.path_join(texture_id + ext)
		var img := _try_load_and_validate(default_path, "DEFAULT")
		if img:
			_log("[RESOLVER] %s resolved from DEFAULT%s (dims %dx%d)" % [texture_id, ext, img.get_width(), img.get_height()])
			return ResolvedTexture.new(img, Tier.DEFAULT)

	_log("[RESOLVER] %s UNRESOLVED; wall will use MATERIAL-ONLY rendering" % texture_id)
	return ResolvedTexture.new(null, Tier.NONE)
```

PNG stays tried first at each tier (canon per D13); WebP is an accepted alternative, not a replacement. No change to `_validate_dimensions()` — it operates on the decoded `Image`, format-agnostic already.

---

## Validation & Evidence (PASS criteria — assertion-backed, red-then-green where applicable)

### Test 1: Facade files resolve end-to-end (the actual acceptance test of G1)

Create a throwaway 1024×512 grayscale test PNG at `user://textures/facade_stone.png` (or `res://textures/defaults/` in a test fixture dir), call `TextureResolver.resolve("facade_stone")`, assert `tier == Tier.USER` (or DEFAULT) and correct dimensions. This is the test that was **impossible to write before this prompt** — G1 made every real filename fail dimension validation regardless of tier.

### Test 2: Default materials registered

```gdscript
var registry = MaterialRegistryClass.new()
registry.register_defaults()
for id in ["concrete", "stone", "wood", "metal"]:
	assert(registry.get_material(id) != null, "Material '%s' must be registered" % id)
print("PASS: all four default materials registered")
```

### Test 3: G3 — no duplicate definitions

```bash
grep -rn "func _render_solid_blocks" --include="*.gd" .
# Expected: exactly ONE hit (room_builder.gd)
```

### Test 4: G4 regression (Item 4's test, run headless)

Paste raw output of `bake_compositor_test.gd` including the new `test_live_shape_wiring()` PASS line with a real page count > 0.

### Test 5: Linear-light identity & effect (red-then-green style: show both blend paths distinguishably)

```gdscript
# With BakeConfig.blend_mode = LINEAR_LIGHT
# facade_lum = 0.5 → no change
var neutral = compositor._composite_tile(mat_tile_with_known_pixel, facade_mid_gray, key, sampler, projector)
assert(neutral.get_pixel(x,y).is_equal_approx(mat_tile_with_known_pixel.get_pixel(x,y)),
	"LINEAR_LIGHT at facade=0.5 must be identity")
print("  ✓ Identity at neutral facade")

# facade_lum = 0.75 → brighter than base
# facade_lum = 0.25 → darker than base
# (assert brightened.r > base.r and darkened.r < base.r)
print("  ✓ Facade > 0.5 brightens, < 0.5 darkens (multiply could not do this)")
```

### Test 6: Tier-3 identity constant

Locate and paste the exact line where the compositor sources `facade_lum` for a `Tier.NONE` resolve; assert it equals `0.5` (not `1.0`). If it required a code change, show the before/after diff explicitly in the completion report — this is the "silent regression seam" called out in Item 5.

### Test 7: WebP probe

Provide a `.webp` fixture at a texture_id with no `.png` sibling; assert `resolve()` finds it and reports the correct tier/extension in the log line.

### Test 8: `check_invariants.py` stays green after all edits.

---

## Implementation Checklist

- [ ] Item 1: `DEFAULT_FACADES` ids get `facade_` prefix
- [ ] Item 2: `register_defaults()` added; boot call site wired (or idempotent lazy-call in `_bake_textures()`)
- [ ] Item 3: diff both `_render_solid_blocks`; consolidate to `room_builder.gd`; delete the other (or flag discrepancy)
- [ ] Item 4: `_extract_walls_from_spec()` accepts top-level `"walls"`; `test_live_shape_wiring()` added and green
- [ ] Item 5: `BlendMode.LINEAR_LIGHT` added to enum, set as default; `_composite_tile()` branches; `_overlay_channel()` helper added; Tier-3 facade_lum constant verified/fixed to 0.5
- [ ] Item 6: WebP probe added to `resolve()`, PNG-first order preserved
- [ ] All 8 validation tests run headless, raw output pasted
- [ ] `check_invariants.py` green
- [ ] Archive prompt to `PROMPTS/DONE/`; bump VERSION

## Out of scope

Actual facade PNG art (Matt supplies separately once this lands), shader-side linear-light mirror (deferred with the rest of the GPU-batch decision), per-zone theme granularity (D8, open).

---

*End MAT-DEFAULTS-01.*
