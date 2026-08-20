# RESUMO_SESSAO — 2026-08-20 (the pre-cook closes, and the weapons stop agreeing)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-19_SHOT_PERFORMANCE.md`
**Commits:** `83e78d11`, `d9eec5ba`, `ceaf6c2a`, `8d987188`, `02ce1a93`,
`860895f9`, and this one — all pushed to `main`, tagged
`alpha-pre-cook-weapons`.
**Gates at close:** lint 210 ✅ · selftests 35 clean / 0 failed ✅ · invariants ✅
· CODEMAP ✅.

---

## Read this first if you are resuming

Last session's rule still governs the render path and nothing here supersedes it:

> **The TileSet rebuild is charged once per FRAME THAT MINTS, not per mint.**

Two rules join it, both forced by measurement rather than chosen:

> **A single global destroy threshold cannot make different materials break at
> different rates.** `punch` divides by RESISTANCE, but LUCK spans 1.41x while
> RESISTANCE spans 2.75x — each material's punch band is narrow and the four
> barely overlap, so any one threshold falls entirely above a band or entirely
> below it. 0% or 100%, never "a few".

> **A stall your CPU probes cannot account for may be a ONE-OFF.** Fire the same
> event twice in one boot before optimising it. The shot's impact frame was
> 303 ms and then 82 ms, and the difference was a texture upload that belonged to
> the map load.

**Nothing is open that the Director has flagged.** The one incomplete item is
art, not code: pressing `1` genuinely arms a rifle — different ladder, different
penetration, different pre-cook — and the figure still holds a shotgun, because
no posed GLB exists for any other weapon. The runnable order is
[`BAKE_ORDER_WEAPON_GRIPS.md`](BAKE_ORDER_WEAPON_GRIPS.md).

---

## 1. The pre-cook's last 36 mints (W-PRECOOK-02, `83e78d11`)

The warm read the atlas coords each cell has **now**, and a DENTED voxel does not
keep them — it moves to a damage-VARIANT atom whose light alternative was
therefore minted on the frame the wall breaks. 17 on the impact, 19 on the soot
pass. An earlier attempt guessed the damage tuple and warmed 11 the shot did not
want while missing the 13 it did.

The fix is a shape, not a number: **`BlastCalculator.plan_point_impact()`** is
D30's ladder as PURE data — one entry per voxel `apply_point_impact()` would
touch, carrying `set_damage()`'s five arguments and the wall SLICE it lands in —
and the applier is a loop over its result. One ladder, so a prediction that runs
the same code cannot disagree with what happens.

Three things fell out of it:

- The plan had only ever seen the voxel each pellet named. D30.1's neighbours and
  D16's second layer were invisible to it: 24 pellets touch 31 voxels.
- `VoxelRenderer.resolve_damage_swap_for()` takes the tuple as arguments instead
  of reading a Voxel, so the warm can ask which atom a voxel *will* land on.
- **`room._build_soot_snapshot()`'s `predict_damaged` was contributing nothing.**
  It was fed live Voxels, which are still INTACT before the shot, and
  `apply_self_soot()` returns clean for INTACT.

Measured, 3 runs a side, same binary and map (stash/pop), medians: warm frame
533.7 → 502.4 ms · impact 341.5 → 305.5 ms · soot **431.2 → 226.6 ms** · mints
after the warm **36 → 0**. Byte-identical `[AGENT-SHOT]` line, and
`INFILTRAITOR_SHOT_SCOPE_PROBE` reports 192 535 cells with 0 differing.

## 2. The impact frame's residue was never the shot's (W-LOAD-01, `ceaf6c2a`)

`INFILTRAITOR_SHOT_FILM_SECOND_AT=<frame>` fires twice in one boot. The first
impact frame cost 303 ms against 79 ms of CPU; the **second cost 82 ms**. So the
~225 ms was a one-off, and a one-off belongs to a preload, not to another warm.

Bisected rather than guessed, with temporary probes: without the light repaint the
first frame was still 229 ms and the second 14 ms; without the impact VFX it was
296 ms. Neither, so the tile swap — and there the code says it plainly.
`DamageVariantBaker.bake_all()` blits 318 atoms into a 2048×2048 page at map load
and marks it dirty; `store()` only **marks**, and the GPU upload waits for a
`flush_dirty_pages()` that nothing called at load. **One 16 MB
`ImageTexture.update()`, landing on the frame the player's first shot breaks a
wall.**

Flushing after the bake: **2 ms** at load, impact frame **303 → 86 ms**, and total
process wall time unchanged over 3 runs a side (13.8-14.3 s against 14.2-15.2 s) —
the upload is absorbed by the render thread during load frames already waiting on
the 1.8 s bake. Verified by rendering, not only by timing: an un-uploaded slot
draws TRANSPARENT, so a wrong flush would show as missing voxels;
`Screenshots/history/shot_default_3_damage.png` has the dents, the holes, the soot
and the smoke.

## 3. The click (W-LOAD-02, `02ce1a93`)

Probed before reordering anything: opening the menu costs **0.3 ms**, the shot
plan 4.9 ms, and `set_grip("_aimed")` **146 ms** — four body frames plus the head
and hat layer sets, off disk, on the first aim of a session.

`AgentSprite.preload_grip()` loads a grip's frames without switching to it (grip
restored, no `_refresh()`, silent on a missing bake) and room.gd calls it at map
load; `open_menu_for()` opens the menu on its **first line**, so the ordering
holds whatever else that function grows into. Menu frame **160 → 12-43 ms**.

## 4. The weapons stop agreeing (W-TUNE-01/02, `02ce1a93`, `860895f9`)

Two axes had to exist before any number could differentiate them — see §0 of
`WEAPON_MASTER_PLAN` and D39/D40 there for the measurements that forced each.
`ShotPunchTable.DESTROY_MIN` is per material (breaching ≠ marking) and
`WeaponDef.blowout` is per weapon (how wide the hole is). The final matrix, all
twelve, on PLAYGROUND's four blocks — s1 is the struck slice, s2 the one behind
it, C/D/X = cracked/dented/destroyed:

| weapon | concrete | metal | stone | wood |
|---|---|---|---|---|
| shotgun | s1 19D **3X** · s2 3D | s1 5C 13D | s1 18D | s1 15D **5X** · s2 5D |
| assault_rifle | s1 **5X** · s2 **3X** | s1 **2X** · s2 1X | s1 **3X** · s2 1D | s1 6X · s2 6X |
| pistol | s1 **1X** · s2 1D | s1 1D | s1 1D | s1 **1X** · s2 1D |

Soot needed no constant of its own for the "less on concrete and wood" half — D24
derives scorch from ABSENT voxels, so fewer holes is less soot at the source
(concrete 258 sooted voxels → 22, wood 498 → 142 at the first pass). Metal was
never at zero as reported: it scorched 18 voxels, all at ring 2, the faintest tone
there is, on a bright facade. `SELF_SOOT_RING_BULLET` (1) is split from the
blast's `SELF_SOOT_RING` (2) so a bullet's own-face mark is one rung darker and a
grenade's rim marks change not at all.

## 5. Keys, and the figure that does not follow yet

**1 rifle · 2 pistol · 3 shotgun · 4 grenade.** 4 is a second event on
`ui_grenade_mode` beside G rather than a branch of its own — the only shape where
*"o mesmo que G"* survives a rebind. `set_weapon()` re-keys an open aim, because
the warm is keyed on the weapon.

Verified through the real InputMap, not the env override:
`INFILTRAITOR_SHOT_WEAPON_KEY` parses the digit and the tier print says which
weapon fired; key 5, bound to nothing, does nothing.

`AgentSprite.weapon` is the bake-directory suffix the figure would follow, in
every path and every cache key, and `p3_posture_export.py` now carries
`WEAPON_SUFFIX` into its output path (`P3_WEAPON` had existed since that script
was written, and nothing carried it — so a pistol run would have overwritten the
shipped shotgun frames, the third instance of a collision that file's own comments
already record twice). **Only the shotgun is baked**, so `set_weapon_bake()` warns
once per weapon and keeps the shotgun pose.

## 6. Two things the code pass found

- **`warm_light_alts_for_gus()` took a `SceneTree` and a `still_valid` Callable
  and used neither**, while its doc claimed cancellation was "still honoured".
  Once the frame-spread version was removed there is no point inside it at which
  a caller could interleave. Both parameters are gone; cancellation lives where it
  can actually happen, in `_run_shot_precook()`'s token checks around the call.
- **`INFILTRAITOR_SHOT_SOOT_DEFER=1` did nothing.** `shot_soot_deferred` was
  declared and documented as the A/B for the soot fade, and read by nobody —
  which also made `fade_in_scoped_soot()` unreachable. Now wired: with it set, the
  fade runs and the run reports 8 dropped frames instead of 4, which is the
  regression it was kept to demonstrate.

---

## Instrumentation, all env-gated

| Switch | What it answers |
|---|---|
| `INFILTRAITOR_CAPTURE_ACTION=shot_filmstrip` | per-frame timeline of a shot (`..._SHOT_FILM_SAVE=1` for images — timings then invalid) |
| `INFILTRAITOR_SHOT_FILM_SECOND_AT=<frame>` | a SECOND shot in the same boot — tells "expensive" from "expensive once" |
| `INFILTRAITOR_SHOT_FILM_FOCUS=x,y` | which of shooter/wall the sheet is about (the tracer never reaches the wall) |
| `INFILTRAITOR_SHOT_WEAPON=<id>` / `..._WEAPON_KEY=<n>` | the weapon by id, or through the real InputMap |
| `INFILTRAITOR_MINT_TRACE=1` | every TileSet alternative actually created |
| `INFILTRAITOR_REPAINT_PROFILE=1` | repaint phase split, cells written, alternatives minted |
| `INFILTRAITOR_FACE_SOOT_DIAG=1` | now also on the SCOPED repaint — it only ever ran map-wide at boot, where there is no damage, and had reported "sooted voxels=0" for every shot ever fired |
| `INFILTRAITOR_SHOT_SCOPE_PROBE=1` | scoped-vs-full apply equivalence |
| `INFILTRAITOR_SHOT_SOOT_DEFER=1` | the soot fade that regressed — now actually reachable |
| `build_filmstrip.py --shot WEAPON --guard N --focus x,y` | a contact sheet of one shot |

## Open, in priority order

1. **The rifle's and pistol's posed frames** — [`BAKE_ORDER_WEAPON_GRIPS.md`](BAKE_ORDER_WEAPON_GRIPS.md).
   The pistol is a run; the rifle needs a grip solve first.
2. **The aim warm is ~500 ms**, the largest number left in a shot. It is lag
   during aiming rather than during action, so it is inside the Director's rules,
   but it is roughly one TileSet rebuild (~250 ms) plus the map-wide soot snapshot
   (~142 ms) plus two occupancy/field builds.
3. **The soot pass is ~228 ms per shot**, CPU-bound on that same snapshot, which
   D24 requires to stay map-wide.
4. **Calibration is one sample per material.** The tables are tuned against a
   single shot into each of PLAYGROUND's four blocks; the punch bands are known
   analytically (§0) but the observed counts are one roll of luck each.
