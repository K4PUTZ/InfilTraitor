# RESUMO_SESSAO — 2026-08-13 (Alpha Explosion Refinement)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-12_13_BUBBLE_WARM_SOOT.md`
**VERSION:** 0.9.98 → **0.9.99**
**Commits:** 8, `8f5fcb3f`–(this checkpoint).
**Plans touched:** `SOOT_MASTER_PLAN` (§6 closed), `TARGETING_MASTER_PLAN`
(§4/§6.3 closed), `EXPLOSION_REBUILD_MASTER_PLAN` (new `E-JUNCTION-01`
section, planned then built same session).

---

## The one-line version

Yesterday's filmstrip request opened the session; the Director then closed
four open items in one message (performance, rotation, soot accumulation,
throw-arc scope) and reported a fifth, bigger one live — wall-junction corner
columns taking no damage at all. Both the performance fix and the junction
fix trace back to the same lesson repeated twice this session: **a real
data probe beats a read of the class definition.** The choreographer
selftest was "fixed" once already by a diagnosis nobody had verified against
the current code; the junction plan assumed a class field was populated
because its declaration looked like a live one. Both were caught by running
the real thing before declaring done, not by re-reading the code more
carefully.

---

## 1. The filmstrip, and four items closed in one message

Built `Screenshots/history/soot_fade_beat_2026-08-13.png` (44 frames,
`--fixed-fps 60`, grenade 2) per the Director's own next-session instruction
from yesterday. Confirmed the beat structure (cook ~20f → strobe f20-24 →
destruction pop f27 → soot/smoke build f28+) and, critically, that S-FADE's
ring spreads gradually across frames 28-32 **outside** the smoke plume — the
one gap yesterday's soot reform left open ("only proven at its final state").

The Director then answered, in one message:

1. **Performance first.** `detonation_choreographer_selftest` was still red
   (91.2% of the queue on one frame) — see §2.
2. **Rotation dropped, "por enquanto."** Retires the SOOT plan's rotation-
   repaint capture gap as moot, not pending.
3. **No soot accumulation needed** — "não vamos ter tantas explosões
   assim." Option A (derived, non-accumulating soot) stays; no segment
   persistence layer required.
4. **The throw arc is normal gameplay, not dev-only** — plus a concrete
   report: check the flying grenade's z-index against walls. See §3.

---

## 2. `detonation_choreographer_selftest` — the fixture was inside a wall

The failure had a diagnosis on file already (`[E-FUME]` pulled soot out of
`WAVE_TABLE`) — stale, superseded by E-ORGANIC-02 before it was ever applied,
and never re-checked against the current code. Instrumenting the real
per-frame profile instead of trusting the old note: `_pick_source_gu()` was
copied from `detonation_plan_selftest.gd`'s scaffold, where returning
`Slice.gu_cell` (a wall's own solid GU) is correct — that file only tests
plan correctness and wants a guaranteed wall hit. Copied for a PACING test,
it detonated the fixture literally embedded in concrete, choked on every
side but one: **371/407 steps (91.2%) in the epicentre's own first frame.**

Fix: `slice.gu_cell + Face.delta(slice.face)` — step onto the GU the wall
actually faces. Real profile after: `[662, 466, 225, 50, 11]` of 1414 steps,
worst 46.8% — matching the ~46% the real map measured independently in
yesterday's P-WARM session, not a coincidence. `run_selftests.py` 35/35
clean (was 34/35). Commit `c14da26d`.

---

## 3. The flying grenade stops disappearing behind walls

`GrenadeProp._apply_z_index()` (D22-FOLLOWUP, 2026-07-28) sets z-index once,
at `setup()`, to match level-0 voxel geometry — correct for a prop resting
on the floor. `TestZoneController._start_grenade_throw_animation()`'s flight
loop moves `position` every frame for the whole 0.6 s arc and never touched
`z_index` again. Instrumented a real throw before touching code:
`z_index=10` unchanged across all 36 flight frames while the sprite rose
**405 world px** above ground at its apex. Any wall the arc's screen path
crossed drew in front of the grenade regardless of real height.

Fix: `GrenadeProp.set_airborne(bool)`, borrowing OCC-03's own agent policy
(`max_voxel_z_index + 1`) for the few hundred ms a grenade is genuinely
airborne, restored to ground-level sorting once the landing bounce settles.
Real before/after capture (same throw, same frame, stashed vs. fixed code):
the grenade fully invisible behind a stone block vs. correctly drawn in
front of it. Commit `6bb69cfc`.

---

## 4. E-JUNCTION-01 — wall-junction corner columns take real damage now

Director, with a screenshot circling three of them: *"a explosão não afeta
as COLUNAS EXTRAS nos cantos das paredes. Precisamos incluir elas no sistema
de destruição."* Told to write the plan first, then implement — both
happened this session (`bcf745c9`, `68b34ba1`).

**Root cause:** `JunctionColumn` (`junction_resolver.gd`) is a third
container class alongside `Slice`/`Slab`, held only on
`room._junction_columns`, consumed by rendering and occlusion but never by
damage — neither `find_affected_containers()` (explosions) nor
`resolve_pellet_voxel()` (firearms) had ever been told the list exists.

**Scope narrowed by the Director mid-implementation**, once the firearm side
turned out to be a real design question, not plumbing: *"as armas de fogo,
em tese, não afetam as colunas extras... não tem como o jogador decidir
atirar bem na esquina."* A shot's aim resolves to whichever `Slice` face is
in front of it; there is no way to point at a diagonal notch on purpose.
Firearm direct damage on junction columns is **dropped, not deferred**.
Soot from either weapon should still reach them for visual coherence — that
needed no firearm-specific code, just one more loop in `room.gd`'s existing
soot-indexing walk, since the soot BFS reads proximity, not the weapon that
caused it.

**Shipped:** a new `PHASE_JUNCTIONS` in `DetonationPlanBuilder`'s state
machine (mirrors `PHASE_SLICES`, same `simulate_container_damage()` ring
model), a `"junctions"` bucket in `find_affected_containers()`, a third
branch in `_resolve_damaged_tile()`/`_surface_name()`/`_material_name()`
(damage-texture orientation defaults to `face_a` — a column has two faces,
being the corner itself; flagged as a look detail, not blocking), and real
ctx coverage in `test_zone_controller.gd` plus both selftest scaffolds.

**Correction found during verification, not anticipated by the committed
plan:** a real-data probe of all 20 PLAYGROUND junction columns printed
`voxels=0` on every one. `_render_junction_column()` writes tiles straight
from `voxel_pos`/`storey_count` via `_set_voxel_cell()` — it never
constructed a `Voxel` object at all, so there was no per-voxel damage state
for any of this to read or write. The plan read `voxels: Array[Voxel]` off
the class definition and assumed it was populated like `Slice.voxels` —
unverified, and wrong. Fixed at the source: `JunctionColumn._init()` now
builds one real `Voxel` per level (mirrors `SliceGenerator._create_slice()`'s
own loop), and gained `dirty_count`/`increment_dirty()`/`decrement_dirty()`
— `Voxel._set_dirty()`'s own contract, which `Slice`/`Slab` already
satisfied and `JunctionColumn` never needed before because nothing ever
called `set_damage()` on one of its voxels.

**Real PLAYGROUND evidence** (`print_census()`, frag_grenade at gu=(6,2),
identical ctx except `junction_columns`):

    without: FLOOR/concrete, WALL/concrete, WALL/metal — no JUNCTION row
    with:    + JUNCTION/concrete destroyed 3 · dented 2 · cracked 1 (live 3)
             + JUNCTION/metal    destroyed 0 · dented 3 · cracked 0 (live 3)

Every other row byte-identical between the two runs. `(baked 0/live 3)` on
both is the deliberate B1-compliant choice — `resolve_damage_voxel_swap()`
was left untouched (still returns `{}` for a `JunctionColumn`, exactly like
the pre-existing Slab miss-path that file's own comment already flagged),
so a junction column always takes the live/generic path, never baked, never
both. Real baked art is future work, not a correctness requirement.

**Visual coherence check** (Director's follow-up ask, same session): a
before/after pair on the same concrete column, zoomed in, shows the
pristine sliver-edge visible before the fix replaced by irregular jagged
breaks after — matching the style of the breached wall right behind it, not
reading as a mismatched patch. A second throw on the same spot (compounding
damage) shows the corner blending into the wall's own breach rather than
standing out as an untouched island, which was the Director's original
complaint about the look.

---

## 5. Robustness audit — no bugs found, several reassuring confirmations

Requested explicitly after the coherence check. Checked, with reasoning
recorded so a future session does not re-derive it from scratch:

- **Persistence already works, with zero extra code.**
  `record_voxel_damage_to_base()` is called per-voxel from
  `delta.touched_voxels` (`test_zone_controller.gd:1142`), reading only the
  `Voxel`'s own fields — container-agnostic by construction. Junction column
  voxels already flow through this because `_phase_package()` appends every
  touched voxel to `touched_voxels` regardless of which container produced
  it. Whether `_reapply_base_damage()` (the REPLAY side) would correctly walk
  junction columns is untested and moot — that path is rotation-only, and
  rotation is dropped for now (§ above).
- **The phase renumbering is safe.** `PHASE_JUNCTIONS` inserted at index 2
  shifted every later phase constant by one; grepped the whole `godot/`
  tree for hardcoded phase numbers outside `detonation_plan_builder.gd`
  itself — none exist, every consumer uses the named constants.
- **The dirty-flag/TIC system (`process_dirty_async()` and friends) is not
  in the live detonation's critical path at all** — `DetonationChoreographer.
  _apply_wave()` paints from `delta.waves`'s pre-resolved
  {source_id, atlas_coords, alt} entries, computed once during planning.
  The TIC system is still real (`WeaponBenchController.fire_active()` uses
  it for firearms), but firearms don't touch junction columns by the
  Director's own scope call, so the new `increment_dirty()`/
  `decrement_dirty()` contract has no live caller yet — harmless, matching
  the same currently-unread-field pattern the codebase already tolerates
  elsewhere.
- **No other `is Slice`/`is Slab` branch was missed** — grepped both
  patterns project-wide; every hit outside selftests was already accounted
  for in the E-JUNCTION-01 change.
- **No stray debug artifacts** — grepped the whole session's diff for
  `DEBUG`/`TODO`/`FIXME`; none survived past the investigation scripts
  (which were never committed).

---

## 6. Documentation swept

`docs/README.md` — `EXPLOSION_REBUILD_MASTER_PLAN`, `TARGETING_MASTER_PLAN`
and `SOOT_MASTER_PLAN` lines all updated. One correction beyond today's new
work: `TARGETING_MASTER_PLAN`'s line was still citing the OLD, wrong
`detonation_choreographer_selftest` diagnosis — replaced with the real one.
`docs/production/current_state.md` — the same stale diagnosis corrected
there too; the rest of that file's hand-written narrative is left as-is
(per standing practice, `docs/README.md` is the trustworthy index).

---

## 7. Verification

    project_lint.py          ✅ 204 files, 0 errors (after every commit)
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ OK
    run_selftests.py         35 clean, 0 failed (was 34/35 at session start)

The one failure this project carried into the session is now gone — first
clean 35/35 in this project's recent history. No selftest was weakened to
get there; the fixture's epicentre moved, nothing else did.

Hand-named captures: `soot_fade_beat_2026-08-13.png`,
`grenade_flight_zindex_before_after.png`.

---

## 8. What's still open, deliberately

Nothing here blocks anything else:

1. **`weapon_fire`'s repaint path has no trustworthy pixel gate** —
   non-deterministic between identical runs (691 px), flagged as its own
   task by SOOT_MASTER_PLAN §7.
2. **SFX for the throw** — nobody's asked for it yet; fits the project's
   visual-first sequencing (sound is a later pillar, not started).
3. **Junction column damage-texture orientation (`face_a`)** is a look
   detail flagged for a real capture's judgement, not a correctness
   question — see EXPLOSION_REBUILD_MASTER_PLAN's E-JUNCTION-01 section.
4. **Junction columns and rotation-persistence** stay genuinely untested —
   moot while rotation is off, first thing to check if it ever comes back.
