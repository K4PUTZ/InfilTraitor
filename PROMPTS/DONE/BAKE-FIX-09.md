# BAKE-FIX-09 — Reader/Writer Lookup Key Mismatch: Make the Dictionary Actually Match

> **Corrective prompt, re-opens BAKE-FIX-05's Task 1. An Overlord audit (2026-07-07)
> found that BAKE-FIX-05's completion report claimed "Bug 1 FIXED" for populating
> `baked_atlas.lookup`, and the writer side genuinely was fixed — but the reader side
> was never touched, uses a completely different key-generation scheme, and the two
> will essentially never produce a matching key for real input. The dictionary went
> from empty to populated, but the lookup this whole system exists to perform still
> fails in practice, silently falling back to the generic material atlas every time.
> This is the exact bug BAKE-FIX-05 was supposed to close, now hidden one layer
> deeper.**

---

## CONTEXT

Two functions build the same documented key format —
`"%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]`
— but compute its components completely differently:

**Writer**, `godot/scripts/systems/bake_compositor.gd:263-273`:
```gdscript
# Key format: "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
# For master strips: variant_k=atom_idx, face=0, plane_col/row based on tile position
var variant_k = atom_idx  # Each atom in the strip is a potential variant
...
var plane_col = int(float(tile_x) / float(VOXEL_ATOM_W))
var plane_row = int(float(tile_y_in_page) / float(VOXEL_ATOM_H))
var lookup_key = "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
```
`variant_k` here is the atom's sequential index within the master strip (0–8, since
`STRIP_LENGTH=9`). `plane_col`/`plane_row` are the atom's literal tile position within
the 4096×4096 page. `face` is hardcoded `0`.

**Reader**, `godot/scripts/systems/baked_tile_lookup.gd:118-127`:
```gdscript
# For now, compute the plane column/row for the voxel in the strip
# This will be replaced with more sophisticated strip walking once BAKE-FIX-01 dictionary is available
var variant_k = abs(hash(str(edge.key_string()) + str(voxel_xy))) % 4
# Build lookup key: "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
# For now, use position_in_run as plane_col (simplified)
var plane_col = (window_origin_texels.x / TEX_AUTHORING_N + position_in_run) % (64 * TEX_AUTHORING_N)
var plane_row = window_origin_texels.y / TEX_AUTHORING_N
var lookup_key = "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
```
`variant_k` here is `hash(edge + voxel_xy) % 4` — a value in 0–3, computed from
entirely different inputs than the writer's sequential atom index. `plane_col`/
`plane_row` are derived from `FacadeSampler.get_window_origin_run_texels()` and
`position_in_run` — a run/texel coordinate space, not a page-tile coordinate space.
The comment directly above this code (line 118-119) is a leftover placeholder that
admits it was never finished: *"For now... This will be replaced with more
sophisticated strip walking once BAKE-FIX-01 dictionary is available."* The BAKE-FIX-01
dictionary has been available since BAKE-FIX-05 landed; this code was never revisited.

These two schemes do not and cannot produce matching keys for the same real
(edge, face, voxel_xy) input — `lookup_dict.has(lookup_key)` at
`baked_tile_lookup.gd:129` will essentially always return `false` in practice.
`_resolve_baked_strip()` returns `null`, `resolve()` falls through to
`_resolve_generic()` (line 74), and the baked path is never actually exercised —
functionally identical to the original pre-BAKE-FIX-05 bug, just masked by a
non-empty dictionary that nothing ever successfully queries.

BAKE-FIX-05's own prompt anticipated exactly this failure mode and required tracing
both sides to confirm alignment, with an explicit instruction to flag a mismatch
rather than paper over it. That verification was not done; no test was ever added
that calls `bake()` then `resolve()` with real data and asserts a hit.

---

## MODULE

- `godot/scripts/systems/baked_tile_lookup.gd` — `_resolve_baked_strip()`: rewrite key
  computation to match the writer's actual scheme
- `godot/scripts/systems/bake_compositor.gd` — read only, to confirm the writer's
  scheme as ground truth (do not change it unless this investigation finds the writer
  itself is wrong — see Task 1)
- A new or existing test file under `godot/scripts/tools/` for the required
  end-to-end verification

---

## TASK

### 1. Decide which side is "right" and reconcile

The writer's scheme (`bake_compositor.gd`) is deterministic and directly derived from
how atoms are physically laid out on the page — it is the ground truth for *what
exists*. The reader's scheme (`baked_tile_lookup.gd`) needs to compute, from a real
placement-time voxel, **the same `variant_k`/`plane_col`/`plane_row` the writer used
when baking that voxel's atom** — not an independently-invented value.

Trace precisely: for a given `edge`, `face`, `voxel_xy` at placement time, which atom
in which master strip does this voxel actually correspond to? (`variant_k` should
presumably select which of the 9 atoms in the strip applies to this voxel's position —
e.g. based on `position_in_run` mod strip length, not a hash of unrelated data.) Which
page/tile position was that atom rendered to? (`plane_col`/`plane_row` need to be
derived from the same page-layout math `_render_strips_to_pages()` used, not from
`window_origin_run_texels()`, unless you can show those two are actually equivalent —
trace it, don't assume it.)

If, after tracing, you find the writer's key scheme itself is unsuited to placement-time
lookup (e.g. it's keyed by physical page position instead of something a placement
query can naturally compute), say so explicitly and change the **writer** instead, or
change the key scheme on both sides consistently — whichever requires the least
invention and most directly reflects the actual atom layout. Do not invent a third
scheme without explaining why the two existing ones are each wrong.

### 2. Add the end-to-end verification test BAKE-FIX-05 was supposed to add

Build a real test: call `BakeCompositor.bake(...)` (or however baking is invoked) to
produce a real `BakedAtlas`, then call `BakedTileLookup.resolve(edge, face, voxel_xy)`
with a real edge/voxel that was part of what got baked, and assert:
- The result is non-null (i.e. the baked path was actually taken, not a fallback).
- Its `atlas_coords` matches the literal, hand-computed expected position for that
  specific atom (not just "some non-null result") — compute the expected value
  independently of the code under test, from first principles of the page layout.

This test must fail loudly if the keys don't match (i.e. it must currently fail before
your fix, and pass after).

### 3. Confirm no regression in the generic fallback path

`_resolve_generic()` must still work for edges/voxels with no baked equivalent (e.g.
`BakeConfig.enabled = false`, or an edge not in any run) — don't break the fallback
while fixing the baked path.

---

## DO NOT TOUCH

- `BakeConfig.enabled`'s default — stays `false`.
- `_render_strips_to_pages()`'s actual pixel-rendering logic (only its key-writing
  logic is in scope, and only if Task 1 concludes the writer's scheme must change).
- Junction-column mirroring logic in `voxel_renderer.gd` — BAKE-FIX-10 covers that;
  this prompt only needs to make the underlying lookup actually work so that
  downstream mirroring has something real to resolve.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script <the new end-to-end test file>
# expected: literal PASS showing bake() -> resolve() -> matching atlas_coords,
# with the expected value computed independently and printed alongside the actual
```

- Completion report must show, for at least one real case: the edge/face/voxel input,
  the literal lookup_key computed by both writer and reader for the atom it
  corresponds to (proving they now match), and the resolved atlas_coords.
- Completion report explicitly states which side changed (reader, writer, or both)
  and why.
- Bump `VERSION` per repo convention.

---

**Scope:** ~2 files touched, 1 new test · this is the load-bearing fix underneath both
BAKE-FIX-06 (junction mirroring) and BAKE-FIX-07 (B3 pixel closure) — neither can
produce a real baked result to compare/mirror until this lookup actually resolves.
