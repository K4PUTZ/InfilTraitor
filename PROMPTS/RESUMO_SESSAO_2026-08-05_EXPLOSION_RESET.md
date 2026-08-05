# RESUMO_SESSAO — 2026-08-05 (D-ARCH-01 Phase 2 investigation → explosion system reset)

**Continues:** `RESUMO_SESSAO_2026-08-04_VFX01_DETONATION_PERFORMANCE.md` and
`RESUMO_SESSAO_2026-08-04_PERF02.md` (the PERF-01/02/03+D11 arc the Director
called "terrível"), plus an untracked prior chunk of this same 2026-08-05
session that landed D-ARCH-01 as incomplete scaffolding (commits `9c941b7`
through `2ad1494` — empty registry, unwired baker, D11 choreography removed).
**VERSION:** 0.9.89 at start → **0.9.89 at close** (no bump — not asked for).
**Mode:** Solo mode.

---

## Executive summary

Two arcs, back to back, ending in a deliberate reset rather than a fix:

1. **D-ARCH-01 Phase 2 investigation** — asked to finish the pre-baked
   damage-variant architecture (populate the registry, wire the baker).
   Found and fixed two real bugs in the existing scaffold (soot baked into
   the wrong place, a broken lookup key), then ran a real measurement spike
   that proved the architecture's core premise — eager whole-map pre-bake at
   map-load time — is not viable (~95ms/wall-voxel, tens of minutes
   projected across the map). Reported back with real numbers instead of
   shipping past the finding.
2. **Full reset** — after the Director judged the whole patch-on-patch
   process a mistake ("a gente já errou demais... o remendo está ficando
   cada vez pior"), explosive voxel destruction was disconnected entirely
   (kept as dead-but-preserved tooling), a real crash in firearm destruction
   was found and fixed, and light flicker was turned off for cleaner
   diagnostics. **Current state: grenades detonate but damage nothing;
   firearms damage normally.** This is intentional, not a bug — see
   `[[explosion-destruction-reset-2026-08-05]]` in memory.

---

## 1. D-ARCH-01 Phase 2 — corrected the tooling, proved eager bake infeasible

Two real bugs found by reading the actual D33/soot code rather than trusting
the scaffold's own model (`VoxelVariantRegistry`'s own docstring):

- **Soot doesn't belong in the registry.** It's a per-cell modulate-alpha
  code (`VoxelLightField.encode_face_soot()`) applied by the light-repaint
  pass *after* any `set_cell()`, orthogonal to which tile a cell shows. The
  scaffold's `[source_id × 3 soot]` shape baked in a wrong mental model
  (position-hash instead of real ring-distance) that would have tripled the
  bake surface for nothing. Registry now stores one `{source_id,
  atlas_coords}` per exact `damage_variant_material()`/`floor_damage_material()`
  name.
- **`apply_damage_voxel_swap()`'s lookup key was wrong** even with a
  populated registry — hardcoded `edge_id="global"`, passed
  `damage_variant_name=""` for DENTED, never distinguished bullet-vs-blast
  CRACKED, hardcoded `Vector2i.ZERO` atlas_coords. Rewritten to derive the
  *same* name the D33 fallback line already computes, so a hit and its
  fallback can never disagree.
- `DamageVariantBaker` rewritten to drive the real, already-selftested
  compositor functions on `VoxelRenderer` instead of its own placeholder
  pixel math.

**The real measurement (Task #4 in this session's plan, the reason to stop):**
instrumented a small real sample (20 voxels/type) on PLAYGROUND via a
temporary `INFILTRAITOR_CAPTURE_ACTION=damage_bake_spike` hook (added,
measured, reverted — same discipline as every PERF-0x round):

| Type | Cost/voxel |
|---|---|
| Wall | ~95 ms |
| Ceiling | ~0.4 ms |
| Zoned floor | ~11 ms |

Against 71,296 total placed cells on PLAYGROUND, eager whole-map bake
projects to **tens of minutes** — infeasible. Investigated the Director's
proposed fix (bake during the grenade's throw/flight animation, using that
elapsed time as hidden budget) and found the flight-time mechanic **does not
exist anywhere in the codebase** — `TestZoneController` is explicitly
documented as disposable scaffolding, `TurnController` has zero grenade
references. Reported this back rather than building an unrequested
gameplay feature or silently descoping.

Commit `f0fe5c3`: the corrected registry/swap/baker, kept in the repo,
unwired (`room_builder.gd` still installs an empty registry), ready for
whatever sequencing the Director gives next.

---

## 2. The reset

Director: *"eu estou com a impressão que a gente já errou demais nesse
processo, e o remendo está ficando cada vez pior. Vamos refazer todo o
sistema visual de explosão."* Three ordered asks, all done:

1. **Light flicker off** (commit `a2d0d47`) — `LightingController` no longer
   honors a map light's `"flicker": true`; it was contaminating diagnostic
   captures. `LightSource`'s flicker system itself is untouched.
2. **Firearm destruction fixed** (commit `be0f35d`) — real root cause, found
   by running the actual weapon-bench capture harness, not by reading code:
   `WeaponBenchController.fire_active()` crashed on `room._destruction_render_busy`,
   a field a same-day `[CLEANUP]` commit (`743bde2`) had deleted as an
   apparent unused var — cross-file write, invisible to per-file lint, the
   **same incident class CLAUDE.md already documents once** for
   `_junction_columns` in `room.gd`. Restored with the same
   `@warning_ignore("unused_private_class_variable")` annotation so it can't
   happen again. Verified with a real capture: `[SHOT] ... landed=24/24`,
   visible damage on the wall, no script error.
3. **Explosive destruction disconnected** (commit `d412480`) —
   `TestZoneController.detonate_active()` no longer calls
   `BlastCalculator.apply_container_damage()`/`apply_crater_damage()`; the
   grenade still hides its sprite and closes its menu, it just damages
   nothing. Four now-orphaned helpers removed with it
   (`_render_damage_stage`, `_expose_below`, `_index_voxel`,
   `_is_freshly_scorched`). Explicitly **kept intact**: `BlastCalculator`,
   `DecalCompositor`, `HalfVoxelCompositor`, the decal assets, and this
   session's corrected D-ARCH-01 tooling. The blast-radius wireframe preview
   (`open_menu_for()`) is untouched — it never damaged voxels. Verified with
   a real detonation capture: no `[BLAST]` log line at all, no script error,
   zero damage across all four PLAYGROUND materials.

---

## 3. State at close

- **VERSION 0.9.89** (unchanged).
- `project_lint` PASSED · `run_selftests` 29 clean / 0 failed ·
  `check_invariants` OK · `gen_codemap --check` clean — re-verified after
  every commit this session.
- Four commits, all pushed: `f0fe5c3` (D-ARCH-01 tooling correction),
  `be0f35d` (firearm crash fix), `a2d0d47` (flicker off), `d412480`
  (explosive destruction disconnected).
- Memory updated: `detonation-perf-arc-under-review` marked resolved,
  points to a new `explosion-destruction-reset-2026-08-05` memory recording
  the current intentional state (so a future session doesn't mistake
  "grenade does nothing" for a regression).
- Temporary measurement spike (`INFILTRAITOR_CAPTURE_ACTION=damage_bake_spike`
  in `room.gd`) fully reverted before commit — `grep -n damage_bake_spike`
  returns nothing.

## 4. Next session starts here

**Waiting on the Director.** They said explicitly: *"Posteriormente vou
fornecer instruções melhores pra gente reconstruir as explosões usando os
recursos numa sequência apropriada."* Do not start rebuilding explosion
destruction without that go-ahead. When it comes, the reusable resources are
already inventoried in `[[explosion-destruction-reset-2026-08-05]]`:
`BlastCalculator`, `DecalCompositor`, `HalfVoxelCompositor`, decal assets,
and the corrected `VoxelVariantRegistry`/`DamageVariantBaker`/
`apply_damage_voxel_swap()`. A real grenade-throw/flight animation is
expected to be part of that sequencing (to buy hidden compute budget) but
does not exist yet and would need to be designed as its own piece.
