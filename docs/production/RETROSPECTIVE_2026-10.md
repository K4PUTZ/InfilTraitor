# INFILTRAITOR — Retrospective, Weeks 9-21 (the engine phase and the performance work)

**Period:** 2026-07-12 → 2026-10-09 · **1 431 commits** (1 845 in total) · **280 scripts** ·
**83 201 lines of GDScript** · `VERSION` 0.9.107 · baseline `2fb06604`.
**Written by:** Claude, at the Director's request, 2026-10-09: *"vamos gastar uma rodada pra fazer uma avaliação do projeto como um
todo, e do trabalho de aprimoramento da performance até aqui. Reconhecendo que a parte de gameplay ainda está pendente."*
**Health at writing:** `verify.py smoke` PASSED in 102 s on `2fb06604` (lint, invariants, codemap, surfaces, 74 selftests, the
PLAYGROUND and GLASS boots).

> The successor of [`RETROSPECTIVE_2026-07.md`](RETROSPECTIVE_2026-07.md). The same rule holds: where a number can settle a
> question, the number is here; where it cannot, the question is written so that one can. Every figure below was read out of git,
> the code or a plan on 2026-10-09, not remembered. Recommendations are proposals for the Director, not decisions.

---

## 1. The numbers, then and now

| | 2026-07-12 | 2026-10-09 |
|---|---:|---:|
| Commits (cumulative) | 413 | 1 845 |
| GDScript files / lines | 147 / 26 318 | 280 / 83 201 |
| `room.gd` | 2 183 | **11 339** (11 145 at the 2026-10-07 audit) |
| Selftests (`run_selftests.py`) | — | 74 (21 046 lines) + the `verify.py full` gates |
| Python tools | — | 68 files, 19 419 lines |
| Markdown in `docs/` + `PROMPTS/` | — | 249 files, **88 400 lines** |

Lines of GDScript by area now: `tools/` 21 400 · `systems/` 20 343 (of it `destruction/` 9 773) · `world/` 18 325 (of it `room.gd`
11 339) · `geometry/` 11 517 · `overlays/` 5 871 · `agents/` 2 058 · `ui/` 1 310 · `controllers/` 1 309 · `debug/` 616 ·
`navigation/` 452.

**The stealth core is about 2 800 lines, ~3.4 % of the code:** `tic_system.gd` 124, `noise_system.gd` 58, `turn_controller.gd` 379,
`guard_enemy.gd` 1 322 (part of it now rendering), `agent.gd` 482, `navigation/` 452. `tic_system.gd` and `noise_system.gd` were last
changed on **2026-06-17**. **None of the 74 selftests covers the stealth core** (grep for the TIC, noise, turn and guard FSM classes: the
one hit is the junction resolver's corner detection). There is no `AudioStreamPlayer` anywhere in `godot/`.

Since the July retrospective: 408 of the 1 431 commits (28.5 %) are tagged `[DOCS]`, and the churn is 154 509 Markdown lines against
195 076 GDScript and 28 936 Python lines.

## 2. The July question is still open

July recorded a disagreement and a falsifiable question: *when the detection meter drives transitions, is the game fun on the first
honest five-minute play?* The meter does drive transitions (thresholds 0.30 / 0.60 / 1.00 in `turn_controller.gd`, wired 2026-06-13;
chase, not confrontation: `DESIGN_MASTER_PLAN` §20). **No session since has recorded that play test, and hand play has never been
measured on a handset (DIAG-11).** The question is unanswered, not answered "yes".

The July "inversion" (gameplay more mature than the engine) has fully flipped. The engine is close to finished (2026-10-07 review);
the game loop is the June loop. That was the Director's chosen order and this document does not relitigate it. What it does record is
the order's cost, which is now concrete: **most of the open performance decisions are gameplay questions in disguise.** Q3 (where
the frag grenade appears), Q4 (do guards share the agent's rig), Q5 (load between segments, or prepare the next one), Q6 (debounce the
prediction while aiming), the `segment_spec` counts (6-10 guards, 30-60 props: "conservative" estimates), and the per-device defaults
of `CosmeticDensity` all wait on how the game is played, and nothing in the engine can answer them.

## 3. What the engine phase delivered

- **A world model on a 3D board:** the packed `VoxelStore` (cells, not objects, since R3D-CLAIMS), `Board3DLive`, camera-only
  rotation (one world, occlusion built once), live skinned actors, props through slots with Tier 4 voxel replacement and a persistent
  pile, surfaces and floor marks, screen-free glass, the destruction pipeline and its pure prediction (`build_plan()` → `WorldDelta`).
- **An immune system that is now routine, not a scar.** Eleven architecture rules (nine hook-checked), loud catalogue loading
  (`JsonFile`), `verify.py` tiers (the cheap tier is the default, the heavy one is earned), gates proven by mutation, red-before-green.
  July's "a tool that sees" became a family: board probe, pixel / ground / pick / roof / world gates, filmstrips, device video.
- **A measurement harness for real phones:** `export_android.py` → `device_run.py --mem-poll` → `bench_analyze.py`, `DevFlags`,
  `stress_scenario.py`, `scale_study.py`, `apk_audit.py` (release APK 127.7 → 62.0 MB), `gfx_census`, `gpu_alloc`, `MemStage`.

July's named debt: the bake cache is moot (the bake was deleted at R3D-END); animation moved from 0 to a live rig with keyed actions
(the final model is the A1b gate); combat moved from 0 to a shot that always misses through a real roll seam; audio, narrative in game
and confrontation are still at 0; UI gained the HUD facade and an Options window.

## 4. Performance — the trajectory on the floor device

All rows are release APKs on the handsets, PLAYGROUND (44×22, larger than a segment), portrait, `RNG_SEED=1`. Sources: the top
blocks of `DEVICE_DIAGNOSTICS_MASTER_PLAN`, `PERFORMANCE_BUDGET_MASTER_PLAN` §0b/§0c, `technical_debt.md`. **Units: the older
rows say MB (decimal); PB-2 says MiB. Converted here where it matters (1 MiB = 1.049 MB).**

**Moto g04s (floor device, budget 33.3 ms per frame, ceiling 1.0 GiB TOTAL PSS):**

| Date, stage | Load | PSS peak | Idle ms/frame | Worst blast frame |
|---|---|---|---|---|
| 2026-09-24, the 2D board (last row) | 53.9 s | 2 330 MB | 54.2 | 389 / **3 855** |
| 2026-09-24, R3D-13 (3D board) | 16.3 s | 1 380 MB | 18.9 | 319-402 / 693-725 |
| 2026-09-25, END-8 (the only board) | 15.2-15.5 s | 1 085-1 108 MB | 18.8-19.4 | 254-263 |
| 2026-10-04, RETIRE-2D + the commit fix | — | 1 067-1 089 MB | 19.5-19.9 | grenade 0: 100-117 |
| 2026-10-04, the 5 GU buffer ring | — | 1 295-1 304 MB | 19.6-20.1 | grenade 0: 101-114 · glass COMMIT 711-721 |
| 2026-10-05, R3D-CLAIMS | store 781-807 ms | 945-967 MB | unchanged | unchanged |
| 2026-10-06, R3D-LOOK's soot bake | — | — | 21.3 | (thrown at the pre-ring coordinates: not the standard blast) |
| 2026-10-09, PB-2 | — | 890-914 MiB (= 933-958 MB) | see §5 A | — |

**Galaxy A16 (mid reference):** load 7.9-8.0 s → 7.1-7.4 (END-8) → ~6 s (2026-10-08); PSS 1 299-1 329 MB (R3D-13) → 1 331-1 365 MB
(2026-10-04) → 1 198-1 257 MiB (2026-10-08) → **~785 MiB** (PB-2); idle 23-27 ms (GPU-bound); grenade 0 worst 74-108 → 115 / 79 ms
with the snapshot flash; STRESS after the A1 rework 145 / 140 ms (control 366 / 641).

**What it adds up to.** On the floor device, against the last 2D row: memory ~-60 % (2 330 → 933-958 MB), idle frame ~-60 %
(54.2 → 19-21 ms), load ~-70 % (53.9 → ~15 s), the first grenade's worst frame ~-70 % (389 → 100-117 ms) and the second's 3 855 →
254 ms at END-8 (the glass box PLAYGROUND gained on 2026-10-02 later made that grenade's COMMIT 711-721 ms: the glass track's item).
The idle frame and the detonation mean sit inside 30 fps. Memory sits under the ratified ceiling on both phones. This is a real
outcome, measured the way it should be.

### What worked (keep doing these)

1. **Rebuilding the foundation instead of tuning it.** The 2D board could not be tuned to budget (54 ms idle); the 3D board started at
   19 ms. The largest performance decision was architectural.
2. **Attribution before trimming.** PB-2 proved with `gpu_alloc` that Android's `Graphics` counts allocator blocks, then bisected the
   Galaxy's ~280 MiB to two screen reads. Nothing was trimmed on a guess.
3. **A/B on the device, alternating installs, two or more boots per side**, and red-before-green on the real path (the shot pre-cook,
   the commit fix, CLAIMS, the aim dome).
4. **Budgets ratified before the work** (PB-0, §0.5, `segment_spec`): the ceiling stopped being a moving number.
5. **Decisions that cost nothing on the floor device were taken on evidence:** the 30 fps cap (60 and 30 are the same run on the Moto),
   portrait (a rotation reopens the Galaxy's 256 MiB block), the screen-free glass.

## 5. What is weak in the performance work

**A. The evidence is drifting away from a fixed reference.** No standard-scenario blast row exists on the current code (the
coordinates moved +4 at R3D-BUFFER; the R3D-LOOK rows threw at the old ones; A1 and PB-2 then rewrote the commit path, the flash and
the glass). The last standard idle row on the Moto is 21.3 ms (2026-10-06). The later readings come from three different scenarios:
GPU 22.9 ms at zoom 0.2 (frame-cap study), 27 ms on STRESS, **28.9 ms in the aim scenario, whose framing is not recorded** (the Galaxy
read 12.7-14.3 there against its usual 23-27, so the framing differs). **Drift cannot be told from scenario.** Step B ("one handset
round") was deferred on purpose; in practice handset runs kept happening, just never the standard one.

**B. A comparison that overstates PB-2 on the Moto.** The plan reads "Moto 890-914 MiB, against 945-1 304 MB in the earlier rounds".
In one unit, 890-914 MiB is 933-958 MB: about **1-3 % under R3D-CLAIMS's 945-967 MB** (2026-10-05; that the scenarios match is not
established). The Moto's memory win is CLAIMS's; PB-2's win is the Galaxy's (~-35 %), which is exactly where its cause lived (the
256 MiB block never opens on the Moto). The data is right; the comparison picks the pre-CLAIMS ring row.

**C. The GPU is now the binding constraint, and it has never been attributed.** Moto idle: GPU 17.3-18.0 ms (frame 18.8-19.4,
September) → frame 21.3 ms after R3D-LOOK's soot bake → **GPU ~25 ms on PROPS and DORM** (real content, 67 draws, ~5 200
primitives) → GPU 25.4 on STRESS → GPU ~28.5-29 in the aim scenario. The budget is 33.3. The Galaxy is GPU-bound too, and the record
says *"consistent with pixel-bound, not tested"*. Memory got PB-2's instruments and an ablation; the frame has had none. The look
items since R3D-END each added per-pixel work (the overlays' second pass +0.7 ms, R3D-LOOK +1.4-1.6 ms after its bake, the aim dome
+1.2 ms GPU while aiming on the Galaxy), and a segment adds 6-10 guards, 30-60 props and the planned visual-sound interface. **On
current evidence the GPU runs out before memory does.**

**D. The hit-stop is designed, not verified, on the floor device.** Its ceiling is 200 ms. The last Moto run (before the 2026-10-08
rework) read stage 0, the world commit alone, at **425-445 ms** (×3.7 the desktop), and the rework does not split that stage. The
Galaxy meets the ceiling (145 / 140 ms). The Moto result is a prediction.

**E. The load time on the floor device is old and large.** 15.2-15.5 s at END-8 (CLAIMS has since cut the store build by ~0.5-1 s; not
re-measured). A level is nine segments. Whether a segment loads behind a screen or is prepared in advance (Q5) changes PB-4's target
and the transient peak, and should be answered before PB-4 runs.

**F. The costs of the gameplay systems have no row on the current board.** The last enemy-phase number is pre-3D (nine guards turning:
~27 ms). Vision cones, AI turns, pathing and noise at HEAVY counts (10 guards) have not been measured on the Moto.

**G. A known leak blocks the segment cycle:** 8 resources still in use at exit after a grenade throw (PB-4 holds the reproduction).
One leak per grenade is one leak per segment.

## 6. The process

**What holds.** Evidence discipline is the project's default now, not a fight. The tiers cut the cost of verifying. The plans are
accurate; the 2026-10-07 audit found real defects (code execution through a player prop, a non-atomic save) and fixed each with a
selftest.

**What it costs.**
- **Documentation is as large as the code** (88 400 Markdown lines against 83 201 GDScript), and 28.5 % of commits since July are
  docs-only. That is partly the price of the evidence rule and worth paying. The avoidable part is **duplication**: one PB-2 result
  (the Moto's 890-914 MiB) is restated in 7 files, the aim dome's 44.5 ms in 12. The 2026-08-30 state audit found that *the pointers
  rot while the plans stay accurate*; restating a number in N indexes is the same mechanism. `CLAUDE.md` is 43.7 KB, loaded every
  session, and its reference-map rows carry status blurbs that go stale (the RENDER3D row still says "🟢 v1.51"; the plan is v1.61). The three largest plans (GLASS 4 595 lines, RENDER3D 4 071, DEVICE_DIAGNOSTICS 3 257) grow
  by stacking dated top blocks.
- **`room.gd` grew from 2 183 to 11 339 lines**, +194 since the audit two days ago. Every gameplay task (A2) lands in it, and it lands
  on a stealth core with **no selftest**.

## 7. Risks, ranked

1. **Fun is unproven.** The highest product risk, and no engine work reduces it.
2. **GPU headroom on the floor device with real segment content** (§5 C).
3. **Gameplay lands in `room.gd` on an untested core** (§6).
4. **Ship blockers, known and parked:** `DevFlags` live in the release build, the debug keystore, no checkpoint wired to a save, no
   audio, the iOS export never built. None is urgent before a public build; all are listed.
5. **A1b gates movement authoring:** crouch, prone and sneak are part of the stealth read and wait for the final agent model.

## 8. Recommendations (proposals for the Director)

1. **Give the performance phase an exit and close it.** Finish PB-3 (marginal costs) and PB-4 (the segment cycle, with the leak fixed),
   **attribute the Moto's GPU frame** by ablation (`HIDE_NODES` and per-pass toggles: a PB-2 for the GPU), take one standard round on
   both phones, verify the hit-stop on the Moto, then **freeze**: PB-7's budget check keeps it from regressing while gameplay is built.
   After that, the next useful performance information comes from real gameplay content, not from more synthetic maps.
2. **Run July's five-minute test as early as A2 allows,** on the Moto, in a segment-sized map with TYPICAL content and the existing loop;
   record the answer honestly, and measure hand play (DIAG-11) in the same session.
3. **Before A2 touches `room.gd`:** pin the current stealth behaviour (thresholds, decay by state, state transitions, noise) with a
   selftest, so AI-02's tuning is measured against something, and choose the controller seam AI-02 / AI-03 land in.
4. **A standard reference row at the end of each performance round** (both phones, the fixed scenario, MiB) instead of one large deferred
   step B: drift then has a baseline to show against.
5. **One owner per number:** the plan states it; roadmap, `current_state.md`, `CLAUDE.md` and the session record point to it without
   restating it; `CLAUDE.md`'s reference map gets one line per row. The Director curates the docs, so this is a proposal only.

## 9. Where it stands

The engine the July retrospective called "expensive, and not done" is done in every dimension the July table measured, and it runs on
a 4 GB phone at 30 fps with memory under a ratified ceiling. The performance work was effective and unusually well evidenced; its
weaknesses are a missing fixed reference, the unattributed GPU, and a hit-stop that is verified on only one of the two phones.

The game is where it was in June. The next information that matters can only come from playing it.

---

## 10. The Director's ruling (2026-10-09, the same day)

> *"Só vamos encerrar a fase de performance quando a engine estiver totalmente otimizada e preparada para a carga de gameplay. Ontem
> fizemos uma boa estimativa do que o programa vai ter. O mecanismo de segmentos nos permite ter a segurança de que na pior das
> hipóteses podemos simplesmente diminuir o tamanho de cada segmento, ao invés de piorar a qualidade do jogo. Além disso temos ainda
> diferentes válvulas de escape que nos permitem gastar esforço prévio em troca de qualidade. O teste dos 5 minutos não importa nesse
> momento, o gameplay é secundário diante da engine. Quando a gente tiver um mundo controlado pela nossa vontade vai ser simples criar
> diversão e entretenimento."*

- **Recommendation 1 (an exit, then a freeze): DECLINED.** The performance phase closes only when the engine is fully optimised and
  ready for the gameplay load; that load is PB-1's `segment_spec`.
- **Recommendation 2 (the five-minute test early in A2): DECLINED for now.** Gameplay is secondary to the engine; the Director's July
  position stands, restated. The July question stays on the record for the next retrospective, unanswered.
- **The fallback is the segment, not the quality:** if the HEAVY segment does not fit, the segment shrinks. The other valves trade
  effort paid in advance for quality (pre-cook, hit-stop, caches).
- Recommendations 3-5: not ruled.

**Technical note (Claude), for the plan, not against the ruling:** the segment valve reaches what scales with the segment (memory, load
time, content per segment). It does not reach the per-frame GPU cost, which scales with the screen's pixels and with what is in view:
the Moto's idle GPU is ~18 ms on a near-empty board and ~25 ms with real content, whatever the segment's size. That cost needs a lever
of its own, so the GPU attribution of §5 C belongs inside the continuing performance phase.
