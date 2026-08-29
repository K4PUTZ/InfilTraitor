# RESUMO_SESSAO — 2026-08-29 · D-6 PART 2 — THE DELETION

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-29_EXPLOSION_DESIGN_CLOSES.md`
**Commit:** `[D-6]` (one commit, as the Director asked) — pushed.
**Gates at close:** lint ✅ · selftests **38 clean / 0 failed** ✅ (was 40) ·
invariants ✅ · CODEMAP ✅ (220 scripts).
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## What this was

The Director on 2026-08-29: *"Fica pendente a limpeza e a otimização do código +
cook da luz."* This session did the **limpeza** — D-6 part 2, the irreversible
deletion the explosion design's closure left standing. Pure engineering, no
behaviour change on the default path.

## Deleted

**Five files** (`git rm`, with their `.uid`):
`detonation_choreographer.gd` (809) + `detonation_choreographer_selftest.gd` (441),
`burn_scheduler.gd` (109) + `burn_scheduler_selftest.gd` (217),
`fire_glow_overlay.gd` (113).

**`room.gd` 9 722 → 8 484 lines.** Gone:
- `_advance_burn` + its `_process` call + the `_burn_prof` timing wrappers;
- `start_burn`, `_burn_precook`, `_burn_final_repaint`, `_burn_residue_probe`,
  `await_destruction_settled`;
- the whole `_burn_prof_*` field wall (~40 vars), `_burn_scheduler`,
  `_burn_pending`, `_burn_commit_accum`, `_burn_touched_edges`, `_burn_soot_gus`,
  `_burn_last_soot_gus`, `BURN_SUSPEND_REGION_LIGHT`, `BURN_COMMIT_INTERVAL_S`;
- `_fire_glow_overlay` field + `FireGlowOverlayClass` preload + `add_child` +
  z-index wiring;
- `_capture_two_fires` + `_tf_watch_*` helpers + `_report_two_fires_soot_drift`
  + the `two_fires` capture-action dispatch;
- `consequence_soot_seconds`;
- `begin_consequence_beat` + `_consequence_pending` + `_consequence_light_done`
  — all write-only once `_burn_final_repaint` (their only reader) was gone. The
  presenter path is unconditional, so the beat needed no "the beat owns the
  ending" latch.

**`detonation_plan_builder.gd`:** `cook_owns_fire` static var deleted — the
`s["burnt"][...] = {...}` branch in `_maybe_burn` is now unconditional and the
`_append(s["waves"]["burn"], ...)` block is gone. New `static var no_burn` (reads
`INFILTRAITOR_NO_BURN`) with an early return at the top of `_maybe_burn` — the
gate the controller used to own moved to where the fire actually lives. The
`[E-BURN]` census reads `delta.burnt_cells` only (the `waves["burn"]` fallback
went).

**`world_delta.gd`:** `"burn"` dropped from the `waves` dict + doc rewrite.

**Comment / wiring rewires:** `detonation_prediction.gd`, `test_zone_controller.gd`
(`_entries_playback_will_drop` no longer special-cases `"burn"`; the
`begin_consequence_beat` call removed), `vfx_draw_probe.gd`.
`VfxDrawProbe.reset()` moved from `start_burn()` to `Room.begin_blast_lock()` so
the VFX-draw window still opens at the detonation.

**Env vars removed:** `INFILTRAITOR_PRESENTER`, `_FRONT_FRAMES`, `_SOOT_SECONDS`,
`_BURN_SCHEDULE`, `_BURN_PROFILE`, `_BURN_PRECOOK`, and the `_BURN_END_GATE` /
`_MAPWIDE_END` / `_RESIDUE_PROBE` / `_PRECOOK_STAGES` / `_TWO_FIRES*` diagnostics
that lived inside the deleted functions. `INFILTRAITOR_NO_BURN` survives (now in
`DetonationPlanBuilder`); `INFILTRAITOR_BURN_PROBE_*` survives (it belongs to
`_capture_light_burn_probe`, which is untouched).

## Changed value

`consequence_light_seconds` **0.5 → 1.0** (§8.11 answer 2 — the ~1 s Diablo II
"Den of Evil" light transform; the swiffh SFX is still deferred to the audio
pass). It is a `var` and the Director tunes it on a filmstrip.

## Evidence

- **Repo-wide grep** for every deleted symbol (`BurnScheduler`,
  `detonation_choreographer`, `FireGlowOverlay`, `_advance_burn`, `start_burn`,
  `_burn_final_repaint`, `await_destruction_settled`, `consequence_soot_seconds`,
  `cook_owns_fire`, `INFILTRAITOR_BURN_SCHEDULE`, `_capture_two_fires`,
  `playback_queue`, `flatten_plan`): **only prose / history references remain**
  (e.g. *"the same trap DetonationChoreographer's header warned about"*).
- Lint ✅ · selftests **38 clean / 0 failed** (the two retired suites are the
  whole 40 → 38) · invariants ✅ · CODEMAP regenerated, 220 scripts.
- **3× slow-motion gate:** `d6_AFTER_presenter.mp4` (scratchpad, 240 frames @ 20
  fps) against `d6_BEFORE_choreo.mp4`. The whole event still plays on the
  presenter: fuse sputter → boom strobe → orange fireball → crater in the fabric
  wall → embers cooling yellow → red → charcoal → plumes rising and drifting →
  soot on the scorched face → the light settles last. Contact sheet:
  `Screenshots/filmstrip/filmstrip.png` (gitignored).
- P-FILM boot: **0** `SCRIPT ERROR` / `push_error` / `push_warning`.

## Still open — after this

1. **§7.4 — the light cook.** `play_consequence_light()` still runs the ~202 ms
   map-wide derive in one frame; D-8 only hides it on a cleared scene. Compute the
   field in the pure cook (the WALK phase already does 133 ms of that work) and
   apply it as a pixel write. **Its own task** — getting it wrong is wrong
   everywhere. This is the Director's *"otimização do código + cook da luz"*.
2. **Polish `throw_event`** (§8.13) — the dome flash, the GU/throw-range clamp so
   it can aim a fabric wall, the framing.
3. **Glass** — *"tem que quebrar muito mais com a granada"* — `MATERIALS_MASTER_PLAN`
   M4, end of the materials milestone.
4. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, audio (incl. the swiffh).
