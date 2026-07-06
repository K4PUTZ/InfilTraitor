# FIX-LEGACY-PROPS-01: Migrate SIGMA_01's Sprite Crates to Voxel `crate_full`

**Status:** Ready for implementation
**Predecessor:** PROP-01 (voxel props pipeline, verified), PLAYGROUND-02 (already uses `voxel_props` natively, proves the path works)
**Directive:** part of "make the whole world voxels" before OCCLUSION & DESTRUCTION — legacy sprite props are the last authored-content piece still not voxels.
**Scope:** `SIGMA_01` is the only real map still using the legacy sprite `props` vocabulary (flat 2D tiles, no bake, no theme, no real 3D presence). Migrate its 9 crates to `voxel_props` entries using `crate_full` (PROP-01). Fix a real coupling gap found while scoping this: shadow-height data (`_prop_heights`) is only ever populated from the legacy sprite path today — migrating without fixing this would silently drop shadows for every migrated crate.
**Effort:** ~2 hours
**Risk:** Low-medium — content migration is mechanical; the `_prop_heights` fix touches shared rendering-support code, verify it doesn't affect the legacy path (which some future map may still use)

---

## Item 0 — Ground truth

### The legacy path (still real, still in use)

`sigma_01_map.gd:52-66` — 9 entries, `{"cell": ..., "tile": "crate_SE"|"crate_SW"|"crate_NW"|"crate_NE"}`, no `stack` field used (all default to `1`). `MapCompiler.compile()` (`map_compiler.gd:144-159`) turns these into `structure_tiles`, rendered by `room_builder.build_from_layout()` (`room_builder.gd:82-95`) as flat sprites via `_place()` on `structure_layer`/`_prop_stack_layers` — no `Edge`, no bake, no theme, no true voxel presence.

### The voxel path (already proven, PLAYGROUND-02 uses it)

`voxel_props` spec key → `MapCompiler` (`map_compiler.gd:144-161`, PROP-01) → `voxel_prop_instances` → `RoomBuilder._render_voxel_props()` (`room_builder.gd:327+`) → `VoxelRenderer.render_prop()`. Entry shape: `{"def": "crate_full", "gu": [x, y]}`. `crate_full` is a symmetric full-GU cube (`props/crate_full.json`) — the 4 sprite orientation suffixes (`_SE`/`_SW`/`_NW`/`_NE`) in the legacy data have no equivalent in the voxel prop (PROP-01 shipped no rotation support, and a symmetric cube doesn't need one) — drop the suffix, keep the position.

### Finding — `_prop_heights` (shadow data) has no producer for voxel props

`room_builder.gd:_cache_blocked_cells()`:

```gdscript
_prop_heights.clear()
for entry in layout.get("structure_tiles", []):
    if entry is Dictionary and entry.has("height"):
        _prop_heights[Vector2i(entry["cell"])] = int(entry["height"])
```

This reads **only** `structure_tiles` (legacy sprite props). `voxel_prop_instances` is never consulted here. `_prop_heights` feeds shadow-length calculation elsewhere (grep its other read sites before changing anything, to know exactly what consumes it and in what units). **If this prompt migrates SIGMA_01's crates to `voxel_props` without also feeding `_prop_heights` from `voxel_prop_instances`, those crates will silently stop casting the shadow length they used to** — a real visual regression, not hypothetical. Fix this as part of the migration, not as an afterthought:

```gdscript
# In _cache_blocked_cells(), alongside the existing structure_tiles loop:
for instance in layout.get("voxel_prop_instances", []):
    var prop_def_id: String = instance.get("def_id", "")
    # Derive a height value consistent with whatever unit structure_tiles' "height" is in
    # (re-read _prop_height_for_stack()'s convention in map_compiler.gd before picking a number —
    # do not invent a new unit/scale for voxel props' shadow height).
    _prop_heights[instance["gu_cell"]] = <derived height, matching the existing convention>
```

**Stop-and-report checkpoint:** if `structure_tiles`' `"height"` and a voxel prop's natural height concept turn out to be measured in incompatible units (e.g. one is "sprite stack count" and the other is "storeys"), don't silently pick a conversion factor — report the mismatch and propose the mapping before committing to one.

---

## Item 1 — Migrate `SIGMA_01`'s data

Replace `sigma_01_map.gd`'s `"props"` key with `"voxel_props"`:

```gdscript
"voxel_props": [
    {"def": "crate_full", "gu": [3, 32]},
    {"def": "crate_full", "gu": [14, 32]},
    {"def": "crate_full", "gu": [7, 21]},
    {"def": "crate_full", "gu": [10, 21]},
    {"def": "crate_full", "gu": [15, 13]},
    {"def": "crate_full", "gu": [16, 13]},
    {"def": "crate_full", "gu": [15, 14]},
    {"def": "crate_full", "gu": [5, 17]},
    {"def": "crate_full", "gu": [13, 17]},
],
```

(Same 9 cells as the original `props` list — this is a faithful position-preserving port, not a redesign. Delete the old `"props"` key entirely; don't leave both.)

## Item 2 — Fix `_prop_heights` sourcing (Item 0's finding)

Implement the fix described in Item 0. Confirm the legacy `structure_tiles`-driven path is untouched (some future map might still use sprite props for something voxels genuinely can't do yet — e.g. directional/asymmetric dressing — so the legacy path itself is not being removed in this prompt, only fed from an additional source).

---

## Acceptance Criteria (assertion-backed, real execution evidence only)

1. **SIGMA_01 has no `props` key, has `voxel_props` with 9 entries**: real diff/read of the file.
2. **Compile produces 9 `voxel_prop_instances`, 0 legacy `structure_tiles` crate entries**: real printed compiled-output counts.
3. **Cells match**: the 9 compiled `gu_cell` values (post-buffer-offset) match the original 9 positions +buffer, one-to-one — paste both lists.
4. **Shadows preserved**: `_prop_heights` contains an entry for all 9 migrated crates after the fix, with a real printed value — and state explicitly what unit/convention was used and why it matches the pre-migration shadow length (not just "added an entry").
5. **Blocked cells unchanged**: SIGMA_01's total blocked-cell count before/after this migration is identical (crates still block their cell either way).
6. **Screenshot**: SIGMA_01's Zone 0 and Zone B crates, showing them as real voxel cubes (not flat sprites) with visible shadows.
7. **`check_invariants.py` / `map_lint.gd`**: clean, verbatim.
8. **Non-regression**: SIGMA_01's guard patrols (unrelated to props but sharing the same compiled layout) still resolve identically — paste the enemy_defs output before/after, confirm unchanged.

---

## Explicitly out of scope

- Removing the legacy sprite `props`/`structure_tiles` machinery itself (`_place()`, `_prop_stack_layers`, `_ensure_prop_stack_layers`) — it may still be needed for content voxels can't do yet; that's a design call for the dead-code cleanup pass, not this content migration.
- Adding rotation/orientation to `crate_full` to match the old sprite suffixes — the voxel cube is symmetric, no visual need for it; if a future prop genuinely needs orientation, that's `PROP-REG-01`/a new `PropDef` feature, not this prompt.
- Any change to `PLAYGROUND` or `TEST_BLOCKS` — they already use `voxel_props` natively (PLAYGROUND-02) or don't use props at all.

---

*End FIX-LEGACY-PROPS-01 prompt.*
