# AUDIT — the Slab↔Voxel reference cycle, found via the PLAYGROUND reform

> **STATUS: CLOSED 2026-08-17 (LEAK-CYCLE-01).** Fixed structurally — `Voxel`
> holds its container by **instance id**, not by reference. Measured before and
> after on the real path; see "Closure" at the end. Two claims made in the
> original write-up below turned out to be **wrong** and are corrected there
> rather than deleted, because the reasoning that produced them is the
> interesting part.

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

## Why this never surfaced before today — ❌ WRONG, corrected 2026-08-17

**The explanation below is incorrect.** Measured on closure day: the untouched
`roof_bake_selftest.gd` on a **warm** cache leaks **410 408 instances** anyway.
A cache hit avoids the bake work, not the `Slab`/`Voxel` graph — `room_builder`
builds 2232 Slabs / 143 392 Voxels on every build regardless of what the disk
cache serves. The real reason nobody saw it is duller: `run_selftests.py` fails
a run on a non-zero exit or a `SCRIPT ERROR` line, and `ObjectDB instances
leaked at exit` is neither. The leak was printing on every run, unread.

Kept below as originally written:

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

- **Narrow:** ❌ **this option does not exist** (established 2026-08-17).
  `DamageVariantBaker` has no throwaway bake-time `Slab`/`Voxel` objects to
  clear: it references `Voxel.DamageState` and `Voxel.CarvedSide` — two
  **enums** — and never constructs either class. Every `Slab`/`Voxel` in the
  process comes from `room_builder` via `SlabGenerator`/`SliceGenerator`. The
  original text is preserved here: "break the cycle only in
  `DamageVariantBaker`'s throwaway bake-time objects — clear `slab.voxels` and
  each voxel's `_parent_container` once the atom is captured. Contained,
  low-risk." It was neither contained nor a fix; it was aimed at code that
  isn't there. Which left the structural option as the only real one.
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

---

# Closure — LEAK-CYCLE-01 (2026-08-17)

Director: *"vamos investigar mais detalhadamente e consertar o problema."*

## The fix

`Voxel._parent_container` (a strong reference to the owning Slab/Slice/
JunctionColumn) became `Voxel._parent_container_id` — a plain `int` instance id.
`_set_dirty()` / `clear_dirty()` resolve it with `instance_from_id()`. The
container owns its voxels strongly; the voxels point back weakly. No cycle can
form, anywhere the pattern is used, by construction.

**Why an id and not a `WeakRef`:** a `WeakRef` per Voxel would have meant
143 392 extra objects on PLAYGROUND alone (RAM is the constraint — D42). A
shared `WeakRef` per container avoids that but changes `Voxel.new()`'s contract
at all 15 call sites. The id costs zero allocations and leaves the constructor
signature untouched.

**The loud-fail contract is intact.** `WorldDelta.project_voxel()` still builds
its projected copy with a null container; null still maps to id 0,
`instance_from_id(0)` still resolves to null, and a write still dies on the same
`SCRIPT ERROR`. Verified with a direct probe, not assumed.

## Measurements — before → after

| Measurement | Before | After |
|---|---|---|
| `roof_bake_selftest.gd`, leaked instances at exit | **410 408** | **0** |
| ...`resources still in use` | voxel.gd, slice.gd, slab.gd | none |
| Isolated probe: 10 slabs × 64 voxels, refs dropped | 653 leaked | 0 leaked |
| Isolated probe: 64 000 voxels, 96.11 MB built | **0.02 MB reclaimed** | **94.04 MB reclaimed** |
| Real path, PLAYGROUND build+free ×3 (2232 slabs / 143 392 voxels) | retained **301 → 602 → 907 MB** | retained **4.18 → 4.18 → 4.18 MB** |
| ...peak static memory by round 3 | 1377.77 MB | 772.09 MB |
| Dirty transition cost (128 000 transitions) | 0.319 µs each | 0.358 µs each |

The +0.039 µs per dirty transition (+12%) is the whole cost, and it is only paid
on damage — `mark_all_dirty()`/`clear_all_dirty()` bypass the back-reference
entirely. 128 000 transitions cost +5 ms total.

## What broke, and why that was the point

Weakening the reference exposed **six fixtures that never owned their
container** — it stayed alive only because the cycle made it immortal. Each one
failed **loudly** (`Attempt to call function 'increment_dirty' ... on a null
instance`), which is the B6 behaviour working:

- `voxel_decal_selftest.gd` — an inline `_StubContainer.new()` argument.
- `blast_calculator_selftest.gd` — `_synthetic_voxels()`, `_crater_patch()`, and
  three `make_patch` lambdas, all of which hand out voxels and drop the Slab.

Fixed by anchoring the container (a named local, or the new `_fixture_slabs`
array — the fixture's stand-in for the registry that owns real Slabs). Production
never had this problem: `SlabRegistry` owns Slabs, `EdgeRegistry` owns Slices,
`room._junction_columns` owns columns. All 15 `Voxel.new()` call sites audited.

## Verification

- `run_selftests.py` — **35 clean, 0 failed.** `bake_selftest.gd`'s
  "teardown crash after PASS" warning is **pre-existing**: measured identical
  with the change stashed and restored.
- `occlusion_set_test.gd` (outside the `*_selftest.gd` glob, creates Voxels) —
  5/5 passed.
- `project_lint.py` ✅, `check_invariants.py` ✅, `gen_codemap.py --check` ✅.
- Warnings: `unsafe_method_access` measured at **0 (IGNORE)** in project
  settings, so `instance_from_id(...).increment_dirty()` adds none; no integer
  division introduced.
- Real map, real damage (literal selftest output):
  `blast_purity_selftest` — "202272 voxel(s) x 7 fields and **2560
  dirty_count(s)** unchanged", "167 entries committed, every one landed exactly
  as described"; `roof_integration_selftest` — "A real roof Slab from the actual
  map is independently destructible (damaged 1/64 voxels, dirty_count=1)".
- Real windowed boot capture: `Screenshots/history/leak_cycle_01_playground_boot.png`
  (non-`auto_` name, so the 50-file rotation leaves it alone).

**Not exercised:** `build_filmstrip.py` (P-FILM) could not run — it needs three
pre-placed floor grenades and commit `66253137` retired them from PLAYGROUND
deliberately, making the tool fail loud. That is a known consequence of the
reform, not a regression from this change, and it was left alone as out of scope.
