# RESUMO_SESSAO — 2026-08-09 (Alpha Explosion Flow)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-08_09_EXPLOSION_WAVES.md`, which
closed with the radial front shipped but invisible, and Task 6 (the tuning pass)
just opened.
**VERSION:** 0.9.93 → **0.9.94**.
**Commits:** `51d0307`, `41aa657`, `9937523`, `6442172`, `48eeb4b`, `cbb97fe`,
`9313f4a`, `d13193f`, `0512c1b`, `d38281d`, `502460e`, plus this session's
closing version bump.
**Mode:** Solo mode.

---

## The one-line version

**A detonation no longer freezes the camera.** It opened as a look-tuning
session, turned into an engine session on the second Director message, and
closed with a complete prediction layer: `build_plan()` computes what a grenade
*would* do without doing it, the work starts when the player picks a target, and
whatever is left finishes under a burning grenade instead of under a frozen
frame.

---

## What happened, in order

### 1. The tuning pass, and the two problems underneath it

The Director opened on Task 6 — fine-tune the explosion. The first report was a
look complaint with a structural cause:

> *"Eu vejo o console carregando os arquivos no momento da explosão… a câmera
> trava e de repente a explosão já está toda construída. O que a gente quer é
> que a explosão flua numa ordem natural, mas que as etapas aconteçam em
> sequência sem travar e nem aparecer tudo de uma vez."*

Measuring rather than tuning found **two separate defects**, and neither was
visible in any existing log:

1. **`build_plan()` blocked ~171 ms and appeared in NO log** — `[E-WAVE]` starts
   its clock *after* it returns, so every detonation performance discussion this
   project has had was measuring the cheap half.
2. **Every blast was three frames.** `cells_due_now()` derived its quota from a
   wall-clock deadline, so one slow frame made the next frame's quota the entire
   queue — measured, **2 057 of 2 185 steps on one frame**.

The Director's answer to the pre-production question set the session's real
scope:

> *"Quero fazer da maneira mais definitiva e bem planejada, em quantas etapas
> forem necessárias. Não temos pressa e sim a necessidade de deixar a engine
> perfeita. Vamos fazer um master plan para essa otimização… queremos um cache e
> a pré-produção profissionais."*

That became **[`PREDICTION_MASTER_PLAN.md`](PLANNING/PREDICTION_MASTER_PLAN.md)**
(`51d0307`) — an engine capability, not an explosion feature.

### 2. The blast becomes visible (P-PLAY, `41aa657` + `9937523`)

`cells_due_now()` is gone. The front advances by **frame index**, snapped to
`band_voxels` multiples — no wall-clock term survives anywhere in the pacing
path, which makes the collapse unreachable rather than merely unlikely.

**The concentric ripple the Director asked for needed no new feature.** The
radial ordering had shipped two days earlier (`04bfed1`); it was invisible only
because the queue drained in 3 frames. Fixing the pacing produced it.

First shipped at 24 frames, then re-answered on the running game: *"ficou ótima
a explosão, mas está muito lenta, tem que ter mais ou menos 1/5 dessa duração."*
`front_frames` 24 → 5.

**A selftest threshold moved and the reasoning is recorded in the test itself so
it is not mistaken for weakening.** Test 5b's "< 50% of the queue on one frame"
had been written when `front_frames` was 24 (even split 4.2%); at 5 frames the
even split is 20% and a healthy radial front measures 45.9% on the real map. The
bound is now 70%, anchored to the 94% collapse it exists to catch rather than to
any even-split multiple, and the test prints the full per-frame profile.

### 3. Three beats, not one (P-STROBE, `6442172`)

> *"Separar o fogo, do flash, da destruição… 1 flash frame branco, 1 frame
> negativo, outro frame branco, outro frame negativo. Em seguida: frame positivo
> com a destruição limpa acontecendo."*

**The timed fade was deleted, not shortened.** `flash()`, `_process()`,
`flash_fade_seconds/power/peak_alpha` and `flash_max_step_seconds` are all gone,
replaced by `hold_frame(mode)` + `clear()`, driven one frame at a time by the
caller. The last of those vars was the E-FLASH-03 fix; **a frame-driven strobe
cannot express that bug** — there is no curve to burn, and a slow frame makes a
strobe frame *last* longer, which is correct.

Verified by luminance against an undetonated baseline of 61.9 (the scene is
DARK, so the negative frame is the *bright* one): 62.6 · 63.5 · **237.3** ·
**176.3** · **236.9** · **177.1** · 62.8.

### 4. The filmstrip, and what it caught (P-FILM, `48eeb4b`)

`tools/persistent/build_filmstrip.py` — every frame of ONE detonation on one
contact sheet. Two design points the obvious version gets wrong, both of which
had been live mistakes in this session's own earlier captures: **one detonation,
not one boot per frame** (embers use `randf_range()`, so a stitched strip shows
the fire jumping), and **`--fixed-fps 60` is load-bearing** (fire and smoke
advance on delta, so at the harness's real ~8 fps they age ~7× too fast per
frame and the sheet would misrepresent exactly what it is being used to judge).

**Its own stale-frame bug took three attempts and two false positives.** The real
cause was `build_plan()`'s 166 ms main-thread block, and the fix is the general
lesson: **grab on `RenderingServer.frame_post_draw`, never on
`SceneTree.process_frame`** — the bug only becomes visible when something blocks
the main thread, so a rig that looks correct today starts lying the moment it is
pointed at expensive work.

### 5. The fire blooms, and goes dark (P-FIRE / P-DARKFIRE, `cbb97fe`, `9313f4a`)

> *"O fogo precisa ser escuro no flash negativo. O fogo está praticamente parado
> no lugar… comece menor, do tamanho da granada, e se expanda rapidamente."*

Only the NEGATIVE quad was lifted above ember/smoke — **deliberately reversing
E-NATIVE-01's ordering call**, recorded in both files so nobody "fixes" it back
by reading the older comment. The WHITE frame still draws under the fire.

Embers gained `velocity`, `drag` (exponential) and `rise` (undecayed — buoyancy
does not run out of steam the way the blast impulse does), all trailing and
defaulted to zero so the per-voxel scorch embers are byte-for-byte unaffected.

**The first bloom was wrong and the filmstrip caught it.** The fire spread
sideways and barely climbed, because the burst was modelled as one squashed 2D
circle — which makes "up" merely the NORTH ground direction, at half the
horizontal rate. Ground and altitude are different axes: ground is x-full,
y-halved; altitude is pure −y, unsquashed. Each ember now gets a ground angle
*and* an elevation, asymmetric (up to 72°, down only 10°).

Then the inverted fire came out **navy** — the inverse of orange is blue, exactly
E-NATIVE-01's original objection. *"Dessatura a inversão pra ficar escuro neutro
em vez de azul."* Rec.709 luma, not a flat average. Verified on the real frames:
max saturation 0, and zero blue-leaning pixels among the 400 darkest.

---

## The engine half — PREDICTION_MASTER_PLAN, all six tasks

### Task 2 · P-PURE (`d13193f`) — the blast can be computed without being caused

`apply_container_damage()` / `apply_crater_damage()` split into a pure
`simulate_*` returning an ordered damage Delta, and a `commit_damage()` that
applies one. The old mutators survive as `commit(simulate(…))` with byte-identical
signatures — which is why **`blast_calculator_selftest.gd` passed with zero
edits**, the gate this refactor rests on.

**The risk the plan called "the single highest-risk detail" did not exist.**
§3.3 claimed both functions read `voxel.damage_state` as they go, requiring a
read overlay. Two greps reversed it: the only Voxel state access in either
function is the `set_damage()` write itself, and no voxel is written twice in one
call. Same shape as the earlier firearms claim — **a risk stated in a plan is a
hypothesis.**

### Task 3 · P-DELTA (`0512c1b`) — build_plan() becomes a prediction

`build_plan()` changes nothing and returns a `WorldDelta` (waves, census,
touched, cost_ms). New `godot/scripts/systems/prediction/`.

The projection models `Voxel.set_damage()` exactly, including the early return
and `visible` following DESTROYED only. **One real trap:** `damaged_voxels` feeds
`apply_self_soot()`, which reads damage fields off the objects in it — real
Voxels would have read INTACT and the self-soot on every fresh dent and crack
would have vanished with no error at all.

### Task 4 · P-SLICE, Task 5 · P-CACHE, Task 6 · P-COOK (`d38281d`)

- **P-SLICE.** An 11-phase resumable state machine; `build_plan()` is that
  machine with an unlimited budget. **One implementation** — a separate fast path
  would be a second copy of a 300-line pipeline and the 0-pixel gate could only
  vouch for one of them. The three map-wide walks merged into one.
- **P-CACHE.** `PredictionCache` keyed `(signature, room._world_revision)`, LRU 8.
  `room.bump_world_revision()` from four mutation sites. A superseded in-flight
  prediction is cancelled and dropped; a finished one is kept.
- **P-COOK.** Pre-production starts when the context menu opens. **Fire first,
  then think:** the burst and shake are unconditional and land on the frame the
  player clicked; beat 0 finishes the computation underneath them.

---

## Measurements that matter

**The freeze, gone.** Harshest case the harness can produce (Enter ~10 frames
after the menu, far faster than a human): the grenade cooks 16 frames (~0.27 s)
with the fire burning and the camera shaking throughout. **Zero frozen frames.**

**0 differing pixels** against the pre-refactor capture — the same image, through
four tasks of refactoring.

**And the 0-pixel gate had to be earned before it meant anything.** At the
default 45-frame wait, two runs of the *same code* differ by **36 733 pixels**
(45 fixed frames is 0.75 s, well inside the fire and smoke lifetimes). Only at
`INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400` is the harness deterministic.

**Cost, six real detonations each side:**

| | mean | range |
|---|---|---|
| before P-DELTA | 178 ms | 159–195 |
| after P-DELTA | 229 ms | 214–259 |
| after P-SLICE's merged walk | **192 ms** | 185–203 |

**§1.1's phase table — which every plan decision was reasoned from — turned out
to mis-attribute the cost.** The first real per-phase profile:

| | plan said | measured |
|---|---|---|
| soot BFS | 66 ms | **10,5 ms** |
| light field | 35 ms | **0,1 ms** |
| map-wide voxel walk | *not a phase* | **133 ms — 66% of everything** |

Corrected in §8.8 and §12.

---

## Two gates recorded as SHORT, not declared met

1. **§4.4's 4 ms per-frame budget.** Worst unsuspendable visit is 7–9 ms — the
   soot BFS and one large wall slice, both atomic by construction. Half a 60 fps
   frame, once per prediction, during pre-production rather than during the
   blast. The fix for the larger is named and costed in §8.8 and deliberately not
   taken: it would make `BlastCalculator`'s BFS frontier resumable, and
   `room.gd`'s repaint path calls the same function.
2. **Total build cost ~192 ms vs a pre-refactor 178 ms.** ~37 of P-DELTA's 51 ms
   regression recovered; ~14 ms is what purity costs on this map.

Also untested rather than claimed: the cache's LRU **eviction** (PLAYGROUND
offers 5 distinct slice-bearing GUs, not 9).

---

## Open questions

- **Q6 (PREDICTION §10)** — `strobe_white_alpha` is 1.0, so a white strobe frame
  puts the whole image in the top 16% of the brightness range and the fire that
  is supposed to keep burning through it is rendered but invisible. One number.
- **Q1/Q2/Q3/Q4/Q5** are all answered.
- The visual timing (fire / flash / destruction) is **deliberately un-tuned** —
  the Director's call: *"a gente só vai conseguir fazer o fine tuning da fluidez
  quando todo o mecanismo estiver bem estabelecido."*

---

## Where the next session starts

1. **The Director's own fine-tuning pass on the fluidity**, now that the
   mechanism is established. The interval between the click and the strobe is the
   thing to look at first.
2. **`EXPLOSION_REBUILD_MASTER_PLAN` Phase B** (targeting UI, throw arc, bubble).
   It plugs straight into the prediction cache's seam — the hover that drives the
   bubble is the same hover that should trigger pre-production, which is what
   §4.2 always described and what the context menu is standing in for today.
3. Still open from the original Task 6 scope, untouched all session: the **crack
   decal art** surviving downsample to a voxel face (an art problem), and the
   **GPU-flush** structural safeguard.

**The trap to carry forward:** any NEW committed mutation must call
`room.bump_world_revision()`, or cached predictions go stale. It is in CLAUDE.md's
reference map for that reason.
