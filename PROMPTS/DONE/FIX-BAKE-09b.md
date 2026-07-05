# FIX-BAKE-09b: Final Punch List – Real Evidence, Key Parity, Red Run

**Status:** Ready for implementation
**Predecessor:** FIX-BAKE-09 + VERIFY_FIX_BAKE_09_20260705
**Scope:** Seven small items. No new architecture. This prompt closes the BAKE fix saga; its acceptance evidence is designed to be impossible to satisfy without actually executing the suite.
**Effort:** ~2 hours
**Risk:** Low (test/doc/polish; one one-line policy delegation)

---

## Context

FIX-BAKE-09's engineering was verified correct by independent replication (geometry invariant, data contract, unified seeding, mask removal, caching). What failed — for the third time — was evidence: the E2E test never enabled baking, its consistency check compared a value to itself, the red run was skipped, and the NW row of the coverage table in TILE_ANATOMY.md was hand-derived (sign-negation of SE) rather than captured from execution.

**Standing rule for this prompt:** every transcript below must be raw console output from an actual run. The auditor holds independent mathematical replicas of the expected outputs and will diff them. Hand-derived numbers will be detected (they were, twice).

---

## Item 1 — E2E test: turn the key

Modify `godot/scripts/tools/fix_bake_09_e2e_test.gd` (or replace with `fix_bake_09b_e2e_test.gd`):

1. **Enable baking inside the test** (and restore afterwards):
```gdscript
var BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
var _prev_enabled: bool

func _init() -> void:
	_prev_enabled = BakeConfigClass.enabled
	BakeConfigClass.enabled = true
	# ... run test ...
	BakeConfigClass.enabled = _prev_enabled
	quit(0 if all_pass else 1)
```

2. **Use a material that exists in MaterialRegistry.** Query the registry first and fail loudly if empty:
```gdscript
var registry = MaterialRegistryClass.new()
Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)
var material_id := "stone"   # must exist; if registry uses other ids, pick the first registered one
assert(registry.get_material(material_id) != null, "Registry must contain '%s' for this test" % material_id)
```
Create the Edge with that material: `EdgeClass.between(Vector2i(0,0), Vector2i(1,0), 1, material_id)`. `BakePolicy.facade_for_material("stone")` → `"stone_base"`; the mock resolver must resolve it (any 64N×32N or synthetic grayscale image with a valid tier — reuse the existing mock but make it return a properly sized Image and a tier ≠ NONE).

3. **Hard assertions — the acceptance criteria of the entire fix sequence:**
```gdscript
assert(baked_atlas.pages.size() > 0, "Bake must produce at least one page (got 0 → bake set was empty)")
assert(baked_atlas.lookup.size() > 0, "Bake must produce lookup entries")

var result = lookup.resolve(edge, 0, Vector2i.ZERO)
assert(result != null, "resolve() returned null")
assert(result.source_id.begins_with("BAKED_ATLAS_"),
	"E2E FAILED: expected baked hit, got '%s' (generic fallback = keys do not match between bake and resolve)" % result.source_id)
print("  ✓ BAKED HIT: %s @ %s (source_id_int=%d)" % [result.source_id, result.atlas_coords, result.source_id_int])
```
Delete the "ℹ Generic fallback … acceptable" branch entirely. **A generic fallback is a FAIL in this test.** There is no acceptable-miss path when baking is enabled and the same Edge was baked.

4. Note on `source_id_int`: with the mocked `BAKED_ATLAS_SOURCE_IDS = {0: 999}`, expect `999`. Assert it.

## Item 2 — Real key-parity check (replace the tautology)

Delete the `edge.key_string() == edge.key_string()` comparison. Replace with true cross-module parity: derive the key string **through the compositor's path** and **through the lookup's path** for the same Edge, and compare:

```gdscript
# Compositor-side key (mirror _populate_bake_set derivation)
var facade_id = BakePolicyClass.facade_for_material(material_id)
var sampler = FacadeSamplerClass.new()
var origin = sampler.get_window_origin_isolated_texels(edge, facade_id)
var comp_key = BakeCompositorClass.BakeKey.new()
comp_key.material_id = material_id
comp_key.facade_id = facade_id
comp_key.variant_k = BakePolicyClass.variant_for(edge, material_id)
comp_key.face = 0
comp_key.plane_col = origin.x
comp_key.plane_row = origin.y
var comp_key_str = compositor._bake_key_to_string(comp_key)

# Lookup-side key (its own reconstruction)
var lookup_key = lookup._make_bake_key(edge, 0, Vector2i.ZERO)
var lookup_key_str = lookup._bake_key_to_string(lookup_key)

print("  Compositor key: %s" % comp_key_str)
print("  Lookup key:     %s" % lookup_key_str)
assert(comp_key_str == lookup_key_str, "KEY PARITY FAILED — bake and resolve derive different keys")
print("  ✓ Key parity: identical derivation on both sides")
```

If Item 1's baked-hit assertion passes, this necessarily passes too; keep both anyway — when a future change breaks parity, this pinpoints *where*.

## Item 3 — Red run (mandatory, skipped twice)

Procedure, transcripts pasted in the completion report:

1. In `per_face_projector.gd`, temporarily change the NE matrix entry `0.5` → `0.51`.
2. Run `per_face_projector_test.gd` headless. Paste the raw output showing `push_error` lines (`M_inv[...] non-integer` / fractional sweep) and the assertion failure.
3. Revert the change (git checkout or manual).
4. Run again. Paste the raw green output ending in `[GEOMETRY] ✓ Inverse integer mapping validated for all faces`.

Both transcripts, verbatim, labeled RED RUN and GREEN RUN. A completion report without the RED transcript is an automatic reject.

## Item 4 — Correct the NW coverage row from execution

The current NW row in `docs/production/TILE_ANATOMY.md` (`flat_x ∈ [−30, 32], flat_y ∈ [−62, 30]`) was not produced by the shipped code. Run the coverage report and paste **all four lines from actual execution** into the doc, replacing the table. For calibration, the auditor's independent replica of the shipped transforms yields:

```
[NE] flat_x ∈ [-64, -18], flat_y ∈ [98, 128]
[SE] flat_x ∈ [-32, 30],  flat_y ∈ [-30, 62]
[SW] flat_x ∈ [-96, -50], flat_y ∈ [-128, -98]
[NW] flat_x ∈ [2, 64],    flat_y ∈ [2, 94]
```

Your executed output must match these. If any line differs, do not edit the doc to match — stop and report the discrepancy (it would mean the transforms changed).

## Item 5 — room_builder delegates to BakePolicy

In `world/builders/room_builder.gd`: delete the local `DEFAULT_FACADES` const and `_facade_for_material()`; call `BakePolicy.facade_for_material(edge.material)` directly in the descriptor builder (BakePolicy has `class_name`, no preload needed — or preload if the linter prefers). One source of truth; the duplicated dict is a divergence time bomb.

## Item 6 — Cache BakeConfig in baked_tile_lookup fallback branch

In `baked_tile_lookup.gd`, the `else` branch of the enabled-check still does `load("res://.../bake_config.gd")` per resolve. Cache it:
```gdscript
var _bake_config_ref = null
...
if _bake_config_ref == null:
	_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
baking_enabled = _bake_config_ref.enabled
```

## Item 7 — Item 6 of FIX-09 (silhouette / B3): formal deferral

The canonical-silhouette alpha remains unimplemented (honestly reported — acknowledged). Authorial decision: **deferred to a dedicated prompt (BAKE-SILHOUETTE-01), and until it lands, baking must not ship enabled.** Record this in `tools/persistent/OPERATOR_CONTEXT.md`:

```
⚠ GO-LIVE BLOCKER (B3): Baked tiles carry constant alpha=1.0 (opaque rectangles); canonical
silhouette import is pending (BAKE-SILHOUETTE-01). BakeConfig.enabled MUST remain false in
shipped builds until B3 is closed. The E2E/selftest suites run with enabled=true only inside
tests, restoring the flag afterwards.
```

Do not implement the silhouette in this prompt — keep 09b small and verifiable.

---

## Acceptance Evidence (all mandatory, all verbatim)

1. **E2E green transcript** including, literally:
   - `Baked atlas pages: <n>` with n ≥ 1
   - `✓ BAKED HIT: BAKED_ATLAS_0 @ (<x>, <y>) (source_id_int=999)`
   - `✓ Key parity: identical derivation on both sides` preceded by the two printed key strings (which must be character-identical and contain the real texel origin, e.g. `stone|stone_base|<k>|0|<col>|<row>`)
2. **RED RUN + GREEN RUN transcripts** (Item 3).
3. **Coverage output**, four lines, matching the calibration table (Item 4), pasted into TILE_ANATOMY.md and into the completion report.
4. `python3 tools/persistent/check_invariants.py` output (must stay green).
5. Diff summary confirming Items 5–7 (policy delegation, config cache, OPERATOR_CONTEXT blocker note).
6. Update the RESUMO correction section: append "ADDENDUM (FIX-BAKE-09b)" with the real transcripts, superseding the tautological "Keys match" evidence.
7. Bump VERSION per convention. Archive this prompt and FIX-BAKE-09 to `PROMPTS/DONE/`.

## Out of scope

Silhouette implementation (BAKE-SILHOUETTE-01), GPU batch decision, run continuity, face-exposure culling, multi-storey rows — all unchanged.

---

*End FIX-BAKE-09b.*
