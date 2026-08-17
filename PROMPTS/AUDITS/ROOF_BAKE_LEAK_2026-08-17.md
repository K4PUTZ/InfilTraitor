# AUDIT — the Slab↔Voxel reference cycle, found via the PLAYGROUND reform

**2026-08-17.** Not requested — surfaced while reforming PLAYGROUND (bigger
board, weapon bench/grenades retired, a light over the guard). `run_selftests.py`
failed `roof_bake_selftest.gd` the moment the board size changed at all, and the
investigation the Director asked me to run down (*"vamos pausar a tarefa
anterior e resolver o bug"*) found something bigger than the selftest.

## The finding

**`Voxel` and `Slab` hold a live reference cycle, and Godot's `RefCounted` has
no cycle collector — once created, neither side is ever freed.**

- `godot/scripts/geometry/slab_generator.gd:18` (and `:58`):
  `var voxel := Voxel.new(voxel_pos, level, slab)` — the third constructor
  argument becomes `Voxel._parent_container` (`voxel.gd:74/77`), a live
  reference back to the `Slab`.
- `Slab.voxels` (`slab.gd:18`) holds that same `Voxel` forward.
- Plain reference counting cannot resolve a cycle: neither object's refcount
  ever reaches zero on its own, regardless of what else still points at the
  `SlabRegistry` or the `Room` that built them.

## Why this never surfaced before today

`DamageVariantBaker` disk-caches baked atoms
(`damage_atom_cache/<hash>.bin`). A cache **hit** loads a flat image and never
builds a live `Slab`/`Voxel` graph at all. PLAYGROUND has not changed shape in
months, so every developer run has been a cache hit — the live-bake path,
where the cycle is actually built, was never exercised by this selftest.

**Proved, not inferred:** cleared `damage_atom_cache/` entirely and re-ran
`roof_bake_selftest.gd` against the untouched, original `PLAYGROUND.map.json`
(24×16, no content changes) — it leaked too (`ERROR: 3 resources still in use
at exit`, `voxel.gd`/`slice.gd`/`slab.gd`). A cold cache — a fresh clone, a
fresh machine, CI — hits this on the **original** map, not just the enlarged
one. The PLAYGROUND reform didn't create the bug; it was the first thing in a
long time to force a cache miss.

## What does NOT explain it (ruled out, not assumed)

1. **Not the two-builds-in-one-process pattern.** `roof_bake_selftest.gd`
   builds PLAYGROUND twice (N view, then E view). Disabling the second build
   entirely — one PLAYGROUND, one `queue_free()` — still leaked.
2. **Not a missing frame-wait on the deferred `queue_free()`.** Added
   `await process_frame` (×2) around both builds, matching the pattern
   `agent_frame_bake_spike.gd` already uses. Measured before trusting it:
   leaked instances went from 38 to **415,730** — an order-of-magnitude
   regression, not a fix. Reverted immediately (`git diff` on
   `roof_bake_selftest.gd` is clean). Read as: an extra idle frame let the
   room's own per-frame repaint machinery run again before teardown, which
   allocates a fresh pass over the whole map (D24's "every repaint walks the
   whole map fresh") — pure waste layered on top of the real leak, not a fix
   for it.
3. **Not `room`'s own fields.** Explicitly nulled every field `MinimalRoom`
   exposes (`_edge_registry`, `_junction_columns`, `_slab_registry`,
   `_voxel_renderer`, `_wall_height_edges`) and separately `queue_free()`'d
   the `voxel_renderer` child before freeing `room` — no change. Confirms the
   cycle sustains itself independent of anything room-level: each
   `Slab` + its own `voxels` array is a **self-contained** leaked cluster
   once built, reachable from nothing external.
4. **Not signal connections.** Checked `SlabRegistry.slab_registered` (the
   only signal in the chain) — nothing in `room_builder.gd` or
   `voxel_renderer.gd` connects to it in this path.

## A second, unrelated bug found in the same session, already fixed by descoping

Placing a real `glass` wall block (PLAYGROUND reform draft) failed
`roof_bake_selftest.gd`'s own content check — **520 of 2600 roof voxels missing
a baked lookup entry** — independent of the leak above and independent of
board size (reproduced identically at 24×16 and 44×22). `glass` has wall/floor
rendering and a full `MaterialResistanceTable` entry (D22: DESTROYED-only), but
apparently no authored **roof** facade — placing it as a real block exposes a
real content gap, not a test defect. **Resolution:** `glass` was pulled back
to RESERVED-but-unbuilt in `PLAYGROUND.map.json`, the same treatment as
brick/cardboard/fabric, until its roof coverage is actually authored.

## Blast radius — this is not a roof-bake-selftest problem

`slab_generator.gd`/`slice_generator.gd`'s `Voxel.new(pos, level, slab)`
pattern is how **every** `Slab`/`Slice` in the game is built, including real
gameplay rooms via `room_builder.gd`. Any session that unloads a room (a map
switch) leaks that room's entire `Slab`/`Voxel` graph — it is simply never been
large enough, or repeated enough times in one process, for anyone to notice.

## Left undone, on purpose (Director, 2026-08-17: "vamos... documentar")

No fix attempted at the architecture level. Two shapes were sketched but not
built, and are recorded here rather than in a teammate's memory:

- **Narrow:** break the cycle only in `DamageVariantBaker`'s throwaway
  bake-time objects — clear `slab.voxels` and each voxel's `_parent_container`
  once the atom is captured. Fixes the selftest and the bake-time leak
  specifically; does not touch real gameplay `Slab`/`Voxel` objects.
  Contained, low-risk.
- **Structural:** stop `Voxel` holding a strong reference to its container
  (`WeakRef`, or drop `_parent_container` and pass context where it's actually
  needed instead of storing it). Fixes the leak everywhere the pattern is
  used, including real map switches during play. Touches the geometry
  system's most central data structure — needs real review before starting,
  not a same-session decision.

## Evidence

- `python3 tools/persistent/run_selftests.py` — 35/35 clean (was 34/1 with the
  reformed PLAYGROUND before glass was pulled back to reserved).
- `check_invariants.py`, `gen_codemap.py --check`, `project_lint.py` — all
  clean.
- Real capture: `Screenshots/history/p_playground_final.png`.
