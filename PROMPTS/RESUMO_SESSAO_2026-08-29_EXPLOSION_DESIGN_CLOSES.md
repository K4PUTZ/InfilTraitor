# RESUMO_SESSAO — 2026-08-29 · THE EXPLOSION DESIGN CLOSES

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-28_PRESENTER_AND_THE_SMOKE.md`
**Commits (all pushed):** `334600e2` D-4 brasa · `013ea093` D-4 life_gain trim ·
`665698aa` D-5 light 2.0→0.5 s · `76b58a5c` fuse/boom pre-pass · `e475284f`
D-6 (1/2) presenter is the only path · `4c89b972` `throw_event` capture action ·
`30e19b35` D-8 defer the light derive until the smoke clears · plus DOCS.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · cell probe `1169 erased · 0 RESTORED · 512 appeared · 0 VANISHED` on
the DEFAULT path (no env) — identical to every run since D-2.
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

> **Director, 2026-08-29:** *"isso conclui nosso design da explosão, com exceção
> do vidro que ainda vamos trabalhar na milestone de materiais. Fica pendente a
> limpeza e a otimização do código + cook da luz."*

**THE EXPLOSION DESIGN IS CLOSED.** The event: fuse (grenade intact, sputtering) →
boom → one commit frame → the consequence channel (smoke, plumes, brasa) → the
light lands after the smoke clears. All shipped and on the default path.

**Three things remain, all engineering, none design:**

1. **D-6 part 2** — the irreversible ~1600-line deletion: the choreographer,
   `BurnScheduler`, `_advance_burn` + the burn profiler + residue probe in
   `room.gd`, `FireGlowOverlay`, the D-0 env vars, `consequence_soot_seconds`;
   also `consequence_light_seconds` 0.5 → ~1.0 s (Diablo-II "Den of Evil" light
   transform, swiffh SFX deferred to audio). Scope + the Director's 3 answers +
   the file list: **§6 below** and master plan §8.11. The **"before" 3× video** is
   `d6_BEFORE_choreo.mp4` (scratchpad — re-shoot if gone). Selftests 40 → 38.
2. **§7.4 — the light cook.** Compute the light field in the pure cook so
   `play_consequence_light()` is a pixel write with no ~202 ms freeze. §8.12/D-8
   only HIDES that freeze (defers it to a still scene); this removes it. Own task
   — getting it wrong is wrong everywhere.
3. **Polish `throw_event`** (§6b) — the capture action's rough edges.

**Glass** — *"tem que quebrar muito mais com a granada"* — is `MATERIALS_MASTER_PLAN`
M4, end of the materials milestone.

The tree is clean at every commit — the choreographer is dead code, not
half-wired.

---

## 1. THE DIRECTOR DOWNSCOPED THE SYMBOLIC FIRE ON SIGHT

Presented with the §5.1 plan (per-voxel vibrating flame → incandescent voxel →
black → smoke, transmission that turns a voxel to ash), the Director closed it:

> *"Olha a gente já chegou num visual bem bom, só falta um pouquinho de brasa nos
> materiais moles, e pronto. Faz como você achar melhor, o que a gente conseguir
> colocar de vermelho brilhando que vira preto é lucro. De resto pode deixar
> assim mesmo. Só vamos precisar trabalhar o vidro, porque ele tem que quebrar
> muito mais com a granada, mas vamos fazer isso no final da milestone de
> materiais."*

So §5.1's spec is **not built as written** and does not need to be — see §2. The
glass break (*"tem que quebrar muito mais"*) is parked to the end of the
materials milestone (`MATERIALS_MASTER_PLAN` M4, the non-local pane break).

## 2. ✅ D-4 — THE BRASA (§8.8)

**The glow was already on screen.** `_build_ember_wave()` queues exactly one
ember on every voxel the fire consumes — the proof is structural, not measured:
`_maybe_burn()` is only ever called from `_build_ember_wave()` / `_climb_from()`,
always immediately after that cell gets its ember, so `burnt ⊆ ember-wave cells`.
Measured on the real PLAYGROUND fabric wall at gu (31,3): **235 of 235 consumed
voxels carry an ember** (`[E-BURNEMBER] 235 of 235`). And `EmberOverlay` already
ramps yellow-hot → deep red → charcoal and hands a puff to the smoke overlay on
death. "Vermelho que vira preto" was tuning, not construction.

**What shipped — a flag and three knobs, no new overlay, no new wave kind:**

- **`DetonationPlanBuilder._mark_burnt_embers()`** — PHASE_BURN, right after
  `_commit_burn_to_delta()`. Walks `waves["ember"]`, sets `burnt: true` and `at`
  (the retired schedule's pace) on every entry whose cell is in `burnt`.
- **`EmberOverlay.burnt_ember_radius_gain` (1.18) · `_life_gain` (1.15) ·
  `_cool_rate` (0.85)** — the boost a flagged ember gets. `DetonationEntryWriter`
  reads them and passes them to `add_ember()` as `radius_scale`, a
  `duration_scale` multiplier and `cool_rate`. An unflagged edge ember passes
  `1.0 / 1.0 / 1.0` and is **byte-for-byte unchanged** — so **wood's ratified
  VL-D4 look is untouched** (wood burns nothing, flags nothing).

⚠️ **THE FIRST CUT WAS A FIREBALL.** `burnt_ember_gain = 1.6` on both radius and
life turned 235 consumed voxels into one blown-out yellow sheet under ADD — the
exact "molten sheet" E-EMBER-02 lowered `val_*` to avoid. Toned to 1.18 / 1.15 on
the second capture and it reads as coals: bright orange at f60–75, cooling
through red, nearly out by f165. Every value is a `var` and the Director tunes it
on the filmstrip.

**Works on both paths.** The writer is shared (D-3) and `ember` is already in the
choreographer's `PLAYED_KINDS`. The choreographer ignores `at` and paces the
flagged embers with its radial front; the presenter releases them by `at`, in the
order the fire spread. The choreographer is D-6's to delete either way.

⚠️ **A flagged ember sits ON the hole the fire opened** — the exact opposite of
`_build_ember_wave()`'s survivor predicate. `detonation_plan_selftest` `test_7`
pins that predicate for the UNFLAGGED embers; the new **`test_11`** pins the
inverse for the flagged ones (every flagged ember on a destroyed cell, carries
`at`; a concrete blast flags none). The two rules live side by side on purpose.

## 3. Evidence

- **Cell probe** (P-FILM, `INFILTRAITOR_PRESENTER=1`, fabric gu (31,3)):
  `1169 erased · 0 RESTORED · 512 appeared · 0 VANISHED` — identical to D-2/D-3.
  The brasa writes no cells, so this was expected, and it confirms no regression.
- **Filmstrip** `Screenshots/filmstrip/` (gitignored) + `brasa_montage.png` —
  f48 ignition, f62–95 orange coals, f120–150 cooling to deep red under the
  rising smoke.
- `test_11`: 235/235 flagged, every flagged ember on a hole and carrying `at`,
  concrete flags 0.

## 4. ✅ D-5 — THE LIGHT RAMP, 2026-08-29 (`665698aa`)

`consequence_light_seconds` **2.0 → 0.5** (the D-0 rehearsal value). Soot was
already in the commit (D-3/D-3b). Gate by CONTAINMENT: same binary, same
`INFILTRAITOR_RNG_SEED`, 0.5 s vs 2.0 s — **every differing pixel is inside the
crater bbox, 0 outside** (`>32`: 263 in / 0 out). The literal settled-final-frame
0 is unreachable (the 2.0 s control ramp outlives the capture's held-camera
window); the destination is identical by construction —
`play_consequence_light()`'s terminal `_write_cell_bucket(to_bucket[k])` loop is
unconditional and the var feeds only `frames_per_step`.

⚠️ **The Director then asked for ~1.0 s** (§5 answer 2) — that bump is part of
D-6 part 2, not done yet.

## 5. ✅ THE FUSE/BOOM PRE-PASS, 2026-08-29 (`76b58a5c`)

Director on the D-6 "before" video: *"the flash negativo está demorando muito
depois da detonação. A cena fica praticamente vazia aos 1s"* → then the model
correction: *"the grenade should be intact when cooking… we pull the pin, throw
it, and wait for the boom. This period of anxiety can be delayed more or less at
will to buy process time. Then, the grenade becomes shrapnels and everything else
happens."*

- **`spawn_blast_burst()` + the shake moved from beat 1 → beat 2 (the boom).**
  They used to fire the instant the sequence started; on a long cook the fireball
  bloomed and decayed before the strobe.
- **The grenade sprite stays visible through the cook**, hidden at the boom.
  `_start_detonation_sequence()` took a `grenade` param; both call sites stopped
  hiding it early.
- **`spawn_fuse_sputter()`** (renamed from `spawn_cook_flame`) — a tiny
  grenade-sized flicker every frame of the wait.
- **`cook_budget_ms` 8 → 14** — the boom lands ~0.45 s into the 3× filmstrip
  (0 cook frames in real play, so unchanged there).

## 6. 🟠 D-6 PART 2 — THE DELETION, NOT YET DONE

**Part 1 shipped (`e475284f`):** presenter is the only path;
`_active_choreographer` → `_active_presenter`; `_warm_prediction` lost
`playback_queue`; `is_resolving_action()` → `_blast_resolving` flag
(`begin_blast_lock()` at the fuse, `end_blast_lock()` from the presenter when the
smoke is up).

**The Director's 3 scope answers:**

1. **`_burn_precook` (P7c):** *"Se a performance está ok… podemos remover. Mas é
   bom avaliar se o mecanismo ainda pode ser útil pra melhorar o desempenho."* —
   remove; input empty since D-2, concept alive as W-PRECOOK. The §7.4
   light-derive precompute is separate.
2. **`is_resolving_action()`:** *"travar durante o fogo, até as fumaças estarem
   instanciadas e subindo. A partir daí o mundo continua, inclusive a luz."* —
   done in part 1. **`consequence_light_seconds` → ~1.0 s** for the ~1 s Diablo-II
   "Den of Evil" light transform; swiffh SFX deferred to audio; the turn advance
   (no turn system yet) waits for the light to land.
3. **`FireGlowOverlay`:** *"Se o glow não está aparecendo pode tirar."* — remove;
   only washed the `BURN_SUSPEND_REGION_LIGHT` edge.

**Deletes:** `detonation_choreographer.gd` (809) + selftest (441),
`burn_scheduler.gd` (109) + selftest (217), `fire_glow_overlay.gd`. Selftests
40 → 38.
**Rewires `room.gd`** (~700 lines): `_advance_burn`, `start_burn`, `_burn_precook`,
`_burn_final_repaint`, `_burn_residue_probe`, `await_destruction_settled`, the
`_burn_prof_*` field wall, `BURN_*` consts, the `_process` call, `_fire_glow_overlay`
wiring, the `_capture_two_fires` action.
**Rewires** `detonation_plan_builder.gd` (`cook_owns_fire` always true;
`_maybe_burn` gains the `INFILTRAITOR_NO_BURN` gate; `waves["burn"]` drops),
`world_delta.gd` (drop `"burn"`), `vfx_draw_probe.gd` comment, ~5 more comment refs.
**Env vars removed:** `INFILTRAITOR_PRESENTER / FRONT_FRAMES / SOOT_SECONDS /
BURN_SCHEDULE / BURN_PROFILE / BURN_PRECOOK`. `consequence_soot_seconds` goes.

**"Before" 3× video:** `d6_BEFORE_choreo.mp4` (scratchpad). Gate: "after" against it.

### 6c. THE LIGHT LAG — DEFERRED, NOT FIXED (`30e19b35`)

Director, watching the real-time video: *"Consigo claramente ver o lag pela
fumaça, quando aparece 'light landed'. A fumaça dá uma pausinha quando entra.
Vamos adiar a luz até o fim mesmo — a não ser que a gente consiga colocar a
fumaça em uma thread separada."* (A separate thread is not viable — Godot overlay
rendering and the derive are both main-thread.)

`DetonationPresenter._wait_for_smoke()` — after the consequence channel, poll
`SmokeSparkOverlay.smoke_count()` until it drops to `light_smoke_slack` (4) or
`light_smoke_max_s` (3.5 s) elapses, THEN `play_consequence_light()`. The ~202 ms
derive still costs 202 ms; the freeze now lands on a still, empty scene (~5.0 s)
instead of over drifting smoke (~3.2 s). Both values `var`. **The real fix is
still §7.4** — compute the light field in the cook.

## 6b. NEW CAPTURE ACTION — `throw_event` (`4c89b972`)

`INFILTRAITOR_CAPTURE_ACTION=throw_event` — the whole detonation in one boot from
real actions: `enter_grenade_mode` → `_set_targeting_target` → wait out the
prediction → `execute_grenade_throw` → grab every frame at `--fixed-fps 60`
through arc, fuse, boom, consequence, light. Encode PNGs at 60 fps for real-time.
Envs: `INFILTRAITOR_EVENT_{AGENT_CELL,TARGET_GU,FOCUS_GU,FRAMES_TOTAL,THROW_AT}`.

⚠️ **Rough edges — a follow-up task:** the aim dome flashes ~1 frame before the
throw despite the `dev_vision` disable; `_set_targeting_target`'s throw-range
clamp mangles a far `TARGET_GU` (the agent's real GU on the reformed PLAYGROUND
was never worked out — a default throw lands at gu (21,8)); a concrete default
throw shows dents, not a crater or fire. The whole event IS captured every run;
it just needs framing + a soft-material target.

## 7. OPEN — after D-6 part 2

1. **Polish `throw_event`** — kill the dome flash, sort the GU/clamp so it can aim
   a fabric wall, tighten the framing.
2. **§7.4 — the light derive, ~202 ms in one frame.** The whole remaining stall.
   Now has a ~1 s light beat + the ratified smoke second to hide under.
2. **D-2b** — the pre-fabricated pattern; also what makes an authored breach point
   work.
3. **D-7**, SS-6 with D-7.
4. **Glass** — *"tem que quebrar muito mais com a granada"*, end of the materials
   milestone (`MATERIALS_MASTER_PLAN` M4).
5. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, `update_docs.py`'s silent wipe, audio (incl. the
   swiffh).
