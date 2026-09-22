# AUDIT — the shotgun's "monster stutter" traces to `_build_soot_snapshot()`'s index walk, not to decals, minting, or scope size

> **STATUS: OPEN — dedicated session needed.** Director, 2026-09-22, on closing this
> investigation: *"eu acho que eu criei um defeito, eu sugeri essa proposta de 'derivar' a
> fuligem dos buracos, crente que ia ajudar alguma coisa, mas isso está arruinando o
> projeto porque fica interferindo em cada cálculo."* This document is the handoff — every
> number below is real and reproduced twice, but the fix itself was never attempted. The
> last capture in this session had the soot repaint landing off-screen (Director caught
> it live), so the VISUAL side of these numbers is unverified; the CPU timings are not —
> they come from the engine's own clock around the exact functions that ran, independent
> of what the camera was pointed at.

**Trigger.** Not requested as a perf task — surfaced while building a uniform 9-material
weapon-VFX bench (`PLAYGROUND_2`, this session) and tuning shot-impact spark speed
(`vfx_surface_spark_speed_scale` 1.3→2.2, CONFIRMED good by the Director on both pistol
and shotgun — that fix is landed and is not what this document is about). Director, firing
the shotgun live in the editor: *"Esta ficando bom, testa com a shotgun também depois"* →
*"tá dando uma travada monstra no meio dos tiros com a shotgun... não é problema de
visual... me parece ser performance mesmo. E eu tenho uma intuição que tem a ver com o
cálculo e carregamento dos decals."*

## The finding

**`_build_soot_snapshot()` (`room.gd:5441`) walks all 173 128 voxels on `PLAYGROUND_2`
every single time it runs, and that walk alone costs 382–391 ms — every time, not once.**
It is invoked once per shot (`_repaint_voxel_light_buckets_scoped(gus, true, 0)` →
`apply_scoped_soot()`, `room.gd:4894`), synchronously, un-awaited relative to the rest of
the shot, landing 2 frames after the impact tile-swap. Measured with
`INFILTRAITOR_SOOT_SPLIT=1` (two shotgun blasts, same boot, same map, nothing reloaded
between them):

```
shot 1: index walk 386.2 ms (173128 voxel(s) indexed · seeds: 0 blast, 0 weapon, 0 damaged) · build_soot_field 0.0 ms (0 cell(s) out)
        [precook pass, predicted — see below]
shot 1: index walk 389.1 ms (173128 voxel(s) indexed · seeds: 0 blast, 1 weapon, 0 damaged) · build_soot_field 0.4 ms (9 cell(s) out)
shot 1: index walk 381.9 ms (173128 voxel(s) indexed · seeds: 0 blast, 1 weapon, 18 damaged) · build_soot_field 0.4 ms (9 cell(s) out)
        → [SHOT-SOOT] single-pass repaint 422.15 ms · 81 GUs
shot 2: index walk 391.3 ms (173128 voxel(s) indexed · seeds: 0 blast, 1 weapon, 11 damaged) · build_soot_field 0.4 ms (10 cell(s) out)
shot 2: index walk 382.0 ms (173128 voxel(s) indexed · seeds: 0 blast, 1 weapon, 34 damaged) · build_soot_field 0.5 ms (10 cell(s) out)
        → [SHOT-SOOT] single-pass repaint 422.16 ms · 81 GUs
```

`build_soot_field()` — the BFS ring propagation from seeds, the OTHER half `§13.1`'s own
comment (`room.gd:5444-5452`) flagged as the thing worth measuring separately — is **not**
the cost. 0.0–0.5 ms every time. The entire 380-420 ms is the walk that produces
`cell_to_voxel`/`blast_cells`/`weapon_cells`/`damaged_voxels`.

**The reuse guard exists specifically to make this walk NOT happen every time, and it
did not skip it once across five calls in one boot with nothing invalidating it in
between.** `_soot_index_cache_valid` (`room.gd:5650`) is set `true` by
`_soot_store_index()` (`room.gd:5667`) right after a full walk, and `invalidate_soot_index()`
is called from exactly four places (`room.gd:1780, 2638, 4007`; `save_state.gd:175, 226`)
— map load, perspective rotation, room reset, save restore. **None of those happened
between the two shots in this capture.** Either `_reuse` (`room.gd:5472`) evaluated false
on every one of these five calls for a reason not yet found, or the "173128 voxel(s)
indexed" the print reports is the SIZE of the (possibly cache-served) `cell_to_voxel` dict
rather than proof a fresh walk ran — **this print does not currently distinguish the two
paths, and that ambiguity is the first thing the dedicated session needs to resolve**
before touching anything.

## What does NOT explain it (ruled out, not assumed, in the order they were tested)

1. **Not a naive per-pellet TileSet mint loop.** Traced the full call chain
   (`agent_shot_controller.gd:398` `fire_at_active()` → `Voxel.set_damage()` (pure data,
   `voxel.gd:201`) → `room.dispatch_impact_vfx()` (pure VFX, `room.gd:4513`) → ONE
   `process_dirty_async()`/`process_dirty_slabs_async()` pair for the whole shot →
   `apply_damage_voxel_swap()`, a plain `set_cell()` against an atom the precook already
   warmed). Neither of the two functions the Director's original intuition named
   (`Voxel.set_damage()`, `dispatch_impact_vfx()`) touches a `TileSet` at all. This part
   of the pipeline is already the "commit once" shape `DetonationPresenter` uses for
   blasts.
2. **Not TileSet minting.** `W-PRECOOK` reported **0 alternatives minted** ahead of every
   shot in this session's tests (soot-free + sooty worlds both warmed during aim, per its
   own design). `[SCOPED-PROF]` confirms **0 cells written · 0 alternatives minted** on
   both the impact-frame and the soot-frame repaint. The precook mechanism the Director
   asked about (*"dá pra calcular tudo no W-PRECOOK da mira?"*) is already doing its job
   for the minting half — that's not where the 400+ ms is.
3. **Not the 81-GU apply scope.** `shot_repaint_scope()` (`room.gd:5068`) unions a
   `SHOT_REPAINT_SOOT_RINGS=3` (7×7) box around every distinct impact GU; three impact
   GUs close together on this shotgun blast produced a verified 81-cell union (math
   confirmed by hand: 56 + 25 = 81). This LOOKS like the obvious lever (repainting 4×
   the actually-damaged area) and was the Director's and this session's first hypothesis
   — but `[SCOPED-PROF]` shows the `apply` step against those 81 GUs costs **0.5 ms**.
   Splitting it spatially (impact points → ring 1 → ring 2, the Director's proposal)
   would be optimizing a step that is already free.
4. **Not a cold-cache one-time cost.** The `INFILTRAITOR_SHOT_FILM_SECOND_AT` harness
   (built 2026-08-19 for exactly this question — see `room.gd:9936-9943`, *"'expensive'
   and 'expensive ONCE' are different findings"*) fired two shotgun blasts in one boot.
   Soot cost on shot 2 (371.9–413.5 ms range across three separate runs) was
   indistinguishable from shot 1. Whatever is expensive, it is expensive **every time**.

## Architectural root, as far as this session traced it

Soot is **derived from voxel absence, checked map-wide, by design** (D24, cited inline at
`room.gd:4764-4771` and `5528-5532`: *"soot is a PROXIMITY read, not a hit test"* — a
column standing next to a hole opened by either weapon needs to scorch, and the only way
to know a voxel is absent is to be able to see the whole board). That rule is almost
certainly correct as a CORRECTNESS requirement (`SOOT_MASTER_PLAN §1.2` is cited twice in
this file as the incident that happens when two soot producers drift). The
`_soot_index_cache`/`_soot_fold_dirty()` machinery (`§13.2`, `room.gd:5643-5717`) was
already built, with real prior measurements in its own comments (126 ms / 215 432 voxels
for the walk alone, on whatever board that was measured on), specifically to turn "walk
everything" into "walk once, then re-classify only what changed." **On `PLAYGROUND_2`
today, across five calls in one boot with nothing that should invalidate the cache, that
mechanism did not produce a cheaper second call.** Either it has a live bug, or the
walk itself was never the part being cached (see the "reuse guard" paragraph above), or
`PLAYGROUND_2`'s 173 128-voxel count (up from whatever the 215 432-voxel measurement's
board was — possibly a stale number from a different board entirely) crosses some cost
threshold the cache math doesn't help with. **Not determined — this is the open question.**

The Director's own diagnosis, stated when calling this session to a stop, is worth
recording verbatim as the working hypothesis for the dedicated session: the 2026-08-13
design decision to derive soot from geometry rather than store/paint it directly may
itself be the defect — not a missing optimization on top of a sound design, but a design
that structurally cannot be cheap no matter how the caching around it is tuned, because
"is this voxel absent" has to be askable for the whole board to answer "does this
standing voxel next to a hole need to darken."

## What the dedicated session should do first

1. **Resolve the reuse-guard ambiguity above** — instrument `_reuse` itself (not just the
   voxel count) so a log line says definitively FAST-PATH or SLOW-PATH per call, then
   re-run the exact two-shots-in-one-boot capture this audit used
   (`INFILTRAITOR_SOOT_SPLIT=1 INFILTRAITOR_SHOT_FILM_SECOND_AT=25`, shotgun, guard 2,
   map `PLAYGROUND_2`) to see which path actually ran both times.
2. **Get a clean visual capture** — the Director caught this session's last attempt with
   the soot rendering off-screen; the CPU numbers above stand regardless (they come from
   `Time.get_ticks_usec()` around the function, not from anything drawn), but nobody has
   actually SEEN the 81-GU/173k-voxel-walk version of this on screen yet, paired against
   what a cheap version should look like.
3. **Decide whether D24's map-wide-proximity read is still the right contract** before
   optimizing under it — the Director's suspicion above. If it is, the fix is making the
   existing `§13.2` incremental index actually deliver its designed saving (bug hunt). If
   it is not, this is a design change to `SOOT_MASTER_PLAN`, not a perf patch, and needs
   the Director's ratification the way every other design change in this file does.
4. **Re-measure `build_soot_field`'s cost on a map with real accumulated damage** — this
   session's numbers are from a nearly-virgin `PLAYGROUND_2` (1-2 weapon seeds, ≤34
   damaged voxels). `build_soot_field` walks `blast_cells + weapon_cells + damaged_voxels`
   for its BFS; a map with hundreds of prior shots/blasts may load that function
   differently than the 0.0–0.5 ms measured here.

## What shipped this session (not part of the defect, landed separately)

- `PLAYGROUND_2` (`maps/PLAYGROUND_2.map.json`) — a fresh, uniform 9-material weapon-VFX
  bench: identical 3-wide/2-storey wall + 3×3 floor zone + one 2-cell guard patrol + one
  overhead light per material, spacing uniform at 5 GU (unlike `PLAYGROUND`, where the
  first four materials sit at Director-calibrated DIFFERENT distances on purpose —
  2026-08-19 ruling, impact-angle testing — and stay that way; `PLAYGROUND_2` does not
  touch or replace `PLAYGROUND`). `INFILTRAITOR_AGENT_START_GU="x,y"` (new,
  `file_map_source.gd`) repositions the capture spawn without editing any map file, same
  idiom as `INFILTRAITOR_GRENADE_GUS`/`INFILTRAITOR_EVENT_TARGET_GU`.
- `vfx_surface_spark_speed_scale` 1.3 → 2.2 (`room.gd:1570`) — CONFIRMED by the Director
  on paired before/after captures, pistol and shotgun, stone. Impact sparks now visibly
  disperse instead of hovering near the mark. Does not touch `spark_speed_min/max` or the
  muzzle flash's own sparks (already "quase perfeito").
- `[SHOT-SOOT] single-pass repaint %.2f ms · %d GUs` print added to `apply_scoped_soot()`
  (`room.gd:4894`) — the default (non-deferred) soot path had zero instrumentation before
  this session; `fade_in_scoped_soot()` already had its own `[SHOT-SOOT]` print. This is
  what made the 422 ms number visible at all and should stay.
- All 9 materials captured on `PLAYGROUND_2` as 2D filmstrips
  (`Screenshots/filmstrip_shot/materials/filmstrip_<material>_2D.png`) for the shot-VFX
  bench — not yet repeated on the 3D board (RENDER3D default) or cross-checked against
  the register in `RENDER3D_MASTER_PLAN` items 5-7.
