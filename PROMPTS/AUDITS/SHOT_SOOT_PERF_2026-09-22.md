# AUDIT — the shotgun's "monster stutter" traces to `_build_soot_snapshot()`'s index walk, not to decals, minting, or scope size

> **✅ RESOLVED 2026-09-22 — SOOT-STAMP shipped (Director: *"Faz todas as correções, não importa o
> visual. Queremos máxima performance e eficiência do código"*).** Soot is stamped once per event and
> never derived; numbers in **§ Resolution** at the end.
>
> **UPDATE 2026-09-22 (dedicated session) — ANALYSED, NOTHING SHIPPED YET.** The open
> questions below are answered by measurement in **§ Dedicated session** at the end of
> this file: the reuse-guard ambiguity (a bug: the aim's prediction pass wipes the
> index), how the cost grows with accumulated damage (linearly, in the shot AND in the
> blast's cook), and a side defect (the impact frame writes old scorch CLEAN). The
> recommended direction (finish `SOOT_STORAGE_REFORM` with event-local scorch) waits
> for the Director's ruling.
>
> **STATUS (original): OPEN — dedicated session needed.** Director, 2026-09-22, on closing this
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

---

## Dedicated session (2026-09-22, later) — what the soot actually costs, measured

The Director's question: *is it possible at all to derive soot from the holes without
interfering with the whole scene?* The Director's working model when asking was
"81 GUs are repainted every frame". That is not where the time goes (the scoped apply
was already measured at 0.5 ms above, and is re-measured below); the time goes into
four MAP-WIDE steps that run once per event. Every number below is from one desktop
editor build, map `PLAYGROUND_2`, shotgun at guard 2, `RENDER3D` default (3D board),
read off the engine's own clocks. The shot is deterministic across runs (same
`[AGENT-SHOT]` impacts, voxel counts and tiers in every run below), which is the
control for comparing them.

### Instruments added (all env-gated, default behaviour unchanged)

- `INFILTRAITOR_SOOT_SPLIT=1` now NAMES the path per call (`FAST` = index reused,
  `SLOW (prediction pass)`, `SLOW (index invalid)`), and prints absorb / store
  projection time plus an **order-independent digest of the soot store**, so two runs
  compare for identity, not only for size. It also times the blast cook's `SOOT`
  phase (`detonation_plan_builder.gd` `_phase_soot`).
- `INFILTRAITOR_SOOT_PREDICT_REUSE=1` — the experiment: a prediction pass reads the
  committed index (predicted seeds appended to copies) instead of wiping it.
- `INFILTRAITOR_SOOT_FLICKER_PROBE=1` — counts sooted plane cells in a scoped repaint's
  GUs before the apply and how many the apply turned CLEAN.

Harnesses: `shot_filmstrip` with `INFILTRAITOR_SHOT_FILM_SECOND_AT=25` (two shots, per-frame
wall times, images NOT saved so the times are valid), and a scenario
`wait 2; detonate 0..4; shoot 2; shoot 2` with `SEED_GRENADES=1`,
`GRENADE_GUS="3,3;8,3;13,3;23,3;43,3"` (concrete, metal, stone, brick, glass).

### 1. The reuse guard: a BUG, and it costs two full walks per shot

```
[SOOT-SPLIT] SLOW (prediction pass) · index walk 379.7 ms (173128 voxel(s) indexed · seeds: 0 blast, 2 weapon, 0 damaged)
[SHOT-FILM] frame 02    458.2 ms   <-- the frame after MENU (the aim's W-PRECOOK)
[SOOT-SPLIT] SLOW (index invalid) · index walk 373.4 ms (173128 voxel(s) indexed · seeds: 0 blast, 2 weapon, 21 damaged)
[SHOT-SOOT] single-pass repaint 414.60 ms · 109 GUs
[SHOT-FILM] frame 16    424.5 ms   <-- the soot frame, 2 frames after the impact
```

`_build_soot_snapshot()`'s `else` branch (`_soot_index_cache = {}`) runs for EVERY
prediction pass, so the aim's precook throws the index away and the post-impact soot
pass finds it invalid and walks again. The index was built to walk once per map; it
walks twice per shot.

**Red → green, same binary, same shots** (`INFILTRAITOR_SOOT_PREDICT_REUSE=1`):

| | aim frame | impact frame | soot frame | store digest after shot 1 / shot 2 |
|---|---|---|---|---|
| today | 458.2 ms | 115.9 ms | 424.5 ms | 260317595 / 1110915410 |
| prediction reuses the index | 75.3 ms | 122.8 ms | 52.8 ms | 260317595 / 1110915410 |

`INFILTRAITOR_SOOT_GATE=1` on the green run: **PASS, 0 disagreement(s) against a full
walk** on every call of both shots (the gate's own full walk shows up as the
~420 ms "crater replay" on those lines, expected). Bit-identical scorch.

### 2. The design cost: every event re-derives the WHOLE LEVEL's scorch

After five grenades, the same shot (index fix ON, so the walk is gone):

```
[SOOT-SPLIT] FAST (index reused, 22 dirty) · index walk 1.1 ms (seeds: 2005 blast, 2 weapon, 1906 damaged) · build_soot_field 192.7 ms (14778 cell(s) out)
[SOOT-SPLIT]   crater replay 0.1 · absorb 53.9 ms · store projection 44.6 ms (16785 stored cell(s), digest 55353797)
[SCOPED-PROF] soot 297.9 · occupancy 30.0 · field.build 23.0 · apply 142.3 ms (109 GUs, soot=true)
[SHOT-SOOT] single-pass repaint 494.17 ms · 109 GUs      (today, without the fix: 887.34 ms, same digest)
```

The BFS itself is local (it only walks surviving visible voxels within the ring reach
of its seeds), but it is fed EVERY hole on the level, so a shot that adds ~100 scorched
cells re-derives 14 778, re-absorbs them into the store, and re-projects all 16 785
stored cells. On a virgin map the same three steps cost 0.8 + 0.3 + 0.3 ms.

**The blast's cook has the same shape**, inside one un-budgeted call (`_phase_soot`
ignores its `deadline`):

```
grenade 1  SOOT phase  44.7 ms · seeds  385 blast,  378 damaged ·  3368 scorch write(s) on the Delta
grenade 2  SOOT phase  79.5 ms · seeds  611 blast,  882 damaged ·  6123
grenade 3  SOOT phase 123.2 ms · seeds  946 blast, 1306 damaged ·  9021
grenade 4  SOOT phase 164.2 ms · seeds 1369 blast, 1743 damaged · 12299
grenade 5  SOOT phase 212.3 ms · seeds 2005 blast, 1886 damaged · 15403
```

Linear in the level's accumulated damage; each grenade re-writes every earlier
grenade's scorch onto its Delta (`absorb_scorch()` at commit). The blast's final
repaint does NOT call `_build_soot_snapshot()` (cooked path, D-7) — confirmed: no
`[SOOT-SPLIT]` line during any detonation.

Since `SOOT_STORAGE_REFORM` SS-2/SS-3 (2026-08-27) the store is the source of truth and
is min-wins, so re-deriving an old hole's scorch can only write what is already there.
The re-derivation is the step that plan's **SS-5 ("subtraction") was scheduled to
remove and never did.**

### 3. Side defect: the impact frame writes old scorch CLEAN (measured on the plane)

The impact repaint runs soot-free on purpose (Director, 2026-08-19: soot after the
impact). A soot-free field answers CLEAN for every cell, and the GU-scoped apply writes
that into the soot plane for EVERY placed cell in the 7x7-per-impact scope — including
scorch an earlier event left there:

```
[SOOT-FLICKER] soot=false: 4199 sooted plane cell(s) in scope before, 4199 turned CLEAN by this apply
[BOARD3D] recolour shot — 18 level(s) uploaded in 1.3 ms
... two frames later ...
[BOARD3D] recolour shot soot — 18 level(s) uploaded in 0.8 ms
```

The 3D board uploads the cleaned planes in the impact frame and the restored ones two
frames later: an earlier crater inside the shot's scope goes clean and comes back.
`room.gd`'s own note on this branch says a soot-free field is *"right for the caller's
OWN GUs"* — it is not, when those GUs already carry older scorch. **Not yet confirmed
by a screen capture** — the plane state and the uploads are measured, the pixels are not.
It also explains most of the soot frame's `field.build` 23 ms / `apply` 142 ms on the
damaged map: every sooted cell in scope changes twice (clean, then back), so the stale
set holds thousands of cells instead of ~100.

### 4. Not soot, in the same frames (flagged, not analysed)

- `build_occupancy()` is ~30 ms map-wide on EVERY scoped repaint (three per shot: aim,
  impact, soot).
- The impact frame's scoped apply is 57-78 ms over 93-109 GUs with `cells written: 0`
  — the hidden 2D board walked under the 3D board (plane writes only).

### What this answers

- **Is deriving soot from holes inherently scene-wide? No.** The derivation is local;
  the scene-wide parts are the INPUT (the index walk, and every hole on the level as a
  seed), the OUTPUT (re-absorb and re-project the whole store), and the soot-free
  intermediate repaint.
- **Splitting across frames** would spread work that is ~99% redundant (14 778 cells
  re-derived to add ~100) and add a resumable state machine that must survive the world
  changing mid-spread. Useful only for a residual, not as the fix.
- **Delaying the soot entirely** is what the shot already does (2 frames later); measured,
  it moves the stall instead of removing it (425 / 887 ms soot frame), and the delay is
  what forces the soot-free repaint that erases older scorch (§3).
- **Remodelling = finishing `SOOT_STORAGE_REFORM`**: each event proposes scorch from its
  OWN holes only (the shot already holds them in `cell_to_voxel`; the blast's cook in its
  plan), min-wins into the store; the repaint stops deriving (SS-5) and only the cells the
  event changed reach the field and the planes; the impact repaint keeps the store's
  existing scorch instead of writing CLEAN. Expected shape (NOT measured, an estimate from
  the virgin-map components above): the shot's soot work ~1-3 ms whatever the level's
  history, the blast's SOOT phase ~45 ms per grenade instead of growing.
- **Difference to review under the Director's eye before switching:** under global
  re-derivation a LATER event can change an older crater's scorch (a surface revealed
  later is scorched retroactively by an old hole; a later hole that cuts a BFS path can
  lighten old scorch). Event-local scorch keeps what was deposited, which is the
  2026-08-27 ruling (*"de forma permanente"*), but it is a visible difference in edge
  cases and needs a paired capture. `SOOT_STORAGE_REFORM` §5.3 (scorch of voxels that no
  longer exist) stays open and is the Director's.

---

## Resolution — SOOT-STAMP (2026-09-22, same day)

**The Director's ruling, after the analysis above:** *"Faz todas as correções, não importa o visual. Queremos
máxima performance e eficiência do código. Se tiver uma sugestão mais simples, a fuligem é meramente um efeito a
mais, não é pra sugar CPU. (...) embutir 3 a 5 estados de fuligem permanentes pra cada voxel (...) Sorteamos os
layers em volta do buraco pra ligar ou desligar esses 5 estados conforme a distância do anel, e pronto."*

**Built:** one tone 0..3 per cell in `Room._soot_map` (base-keyed), the same on every face, stamped once:
- a shot: an L1 ball of radius 3 around the voxels it touched (`BlastCalculator.stamp_around()`), two frames after
  the impact, into the map and the plane, one upload;
- a blast: every surviving voxel of the flood by 3D distance to the epicentre, in four bands from the crater edge
  to the flood edge (`DetonationPlanBuilder._soot_ring_by_distance()`). ⚠️ NOT `ring_of`'s GU ring: a per-GU stamp is
  what the Director rejected in 2026-08 (*"um monte de quadradinhos (...) muito forte por GUs"*, `BombDef`'s note);
- a fire: the six neighbours of each burnt cell;
- the "sorteio": `soot_jitter()` lightens a cell one tone with a per-ring chance, seeded by `hash(Vector3i)`.
Deleted: the derivation (`derive_soot_rings`, `build_soot_field`, faces, six-direction format, self-soot), the map
index and its cache/gate, `Voxel.soot_dirty`, `_crater_floor_soot`, the shot's soot fade, and every soot write in
the light applies (so the side defect of §3 cannot happen). The map-wide repaint resets the planes and
re-projects the map; `SaveState` v2 saves it. A new `soot_stamp_selftest` pins the rules; 17 selftests of the
derivation were deleted with it.

**Before -> after, same harnesses, same binary conditions (desktop editor build):**

| | before | after |
|---|---|---|
| shotgun, virgin map — aim frame | 458 ms | 58 ms |
| — impact frame | 116 ms | 52 ms |
| — soot frame | 425 ms | 13.5 ms (the stamp itself 3.7–4.3 ms) |
| shotgun after 5 grenades — soot work | 876 / 836 ms | 3.9 / 3.6 ms |
| blast cook SOOT phase, grenades 1..5 | 44.5 / 79 / 119 / 160 / 206 ms (one call) | 19 / 16 / 16 / 16 / 15 ms (chunked) |
| blast SOOTWAVE, grenades 1..5 | 10 / 30 / 49 / 70 / 92 ms | 16 / 12 / 13 / 14 / 15 ms |
| blast cook, worst single step | 53 / 92 / 124 / 171 / 218 ms | 36 / 58 / 32 / 36 / 38 ms |
| map load, full repaint | soot 407 + apply 1 164–1 192 ms | apply 888 ms (reset + re-projection included) |

Seen on screen (scenario captures, 3D board, not kept): the blast's scorch is a dithered darkening around the
crater on floor and walls with no GU blocks; the shot's scorch lands on the struck face and the floor at its
base; an older blast's scorch beside the shot survives the shot. `shot_3d_gate.py`: PASSED (brick 6 997 px vs 2D
control 7 441 px, concrete 10 015 vs 11 635). **Not measured on the Moto.**

