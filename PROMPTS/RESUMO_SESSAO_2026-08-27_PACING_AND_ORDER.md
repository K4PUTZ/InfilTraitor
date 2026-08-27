# RESUMO_SESSAO — 2026-08-27 · THE PERFORMANCE WAVE HAD BROKEN THE CHOREOGRAPHY

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-26_PERF_WAVE_AND_CONSEQUENCE.md`
**Commits:** `037ea0e5` `a68552ab` `5f6a04e8` — all pushed.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅.
**VERSION:** unchanged at 0.9.107 (no tag requested).
**Method:** every finding this session came from recording the detonation at
**3× slow motion** (`build_filmstrip.py --video --fps 20`, capture pinned at
`--fixed-fps 60`) and reading the frames. Not one came from reading the code
first.

---

## Read this first if you are resuming

The session was asked to organise the ORDER of the explosion's effects. It found
that the order was not the problem — **duration was**, and the cause was the
performance wave that shipped the day before. Two pacing defects were fixed
(`E-PACE`), then the ordering mechanism itself (`E-ORDER`). Hard materials are
now organised and verified. Soft materials are analysed, NOT changed: the two
mismatches found there are Director decisions, not bugs, and are listed as open.

**Where work resumes:** nothing is half-done. The tree is clean and pushed. The
Director ruled on the soot storage model (§5) and that reform has not started.

---

## 1. ⚠️ THE PERFORMANCE WAVE SHORTENED THE BLAST ~5× IN SILENCE

The single most important thing in this session, and it is a lesson about
**units**, not about explosions.

`DetonationChoreographer.front_frames` is denominated in FRAMES. §12 made a blast
frame cheap. The front's wall-clock duration fell with it, and nobody re-tuned
it, because nothing in the perf work touched a file that mentions duration.

```
ratified 2026-08-09:   5 frames x 86.1 ms  =  430 ms
measured 2026-08-26:   5 frames x 17.6 ms  =   88 ms
restoring 430 ms:      430 / 17.6          =   24 frames
```

Measured on the real thing before the fix: the whole front — decals, holes,
expose, debris, embers, smoke — occupied **5 frames / 83 ms** of a 60 fps
filmstrip, immediately behind a 5-frame strobe covering **99.4% of the screen**.
The Director's report was that the ordering could not be read. At 83 ms there was
no ordering to read.

**The file had already written down the rule that would have caught this:**
*"Duration is `front_frames × the cost of a blast frame`, never
`front_frames × 16.7 ms` (…) If the duration needs to track real time, the honest
lever is this number."* It was written as advice for a hypothetical. It came due
and nobody was watching.

**The generalisable rule: a performance change that alters frame cost silently
retunes every frame-denominated look value in the project.** `front_frames` is
one; `soot_fade_frames_per_step` and `consequence_light_steps` are others, and
both are now derived from seconds rather than held as frame counts.

## 2. The light beat existed in the log and not on screen

§13 shipped `consequence_light_seconds = 2.0` over 12 steps. It ran. It painted
almost nothing.

`play_consequence_light()` skipped every cell whose origin bucket was
`BUCKET_UNWRITTEN`, reasoning that a sentinel is not a value to lerp out of. True
of the integer, false of the picture: **`voxel_face_shading.gdshader` clamps 255
down to 11**, so those cells are already being drawn at full light. There is a
start value; it is just not the byte in the plane.

```
of 661 changed: 640 UNWRITTEN (skipped the ramp), 21 rampable
```

⚠️ **And they did not "arrive at the end" — they arrived at the START**, which is
why this was invisible rather than ugly. The repaint applies the real light to
everything; the rewind that follows is what puts the ramp's cells back. A skipped
cell is never rewound, so it keeps the repaint's value, and there is no `await`
between the two — so the change is presented inside the repaint's own frame,
folded into the last step of the soot ladder. **96.8% of the light beat was not a
beat at all.**

```
ramp steps that paint:   3  ->  10
ramp pixels:         ~1 100  ->  ~5 500
final frame vs control:  0 differing px
```

The destination is provably untouched: a control run with only this fix reverted
produced a **pixel-identical** final frame.

## 3. E-ORDER — the bias table was not deciding the order

`E-CLEAN` (2026-08-26) corrected `KIND_RADIUS_BIAS` so the decals lead the hole.
The Director's report survived that fix, and this is why: `_sort_key()` salted its
jitter roll per **(KIND, cell)**, giving every effect on one cell an INDEPENDENT
±0.45 wobble while the biases separating them are 0.05–0.10 apart. **The wobble
won.** Measured on the real PLAYGROUND plan, per-cell pairs the table says are
ordered, counting how many the queue delivered inverted:

```
cracked -> destroy     48 pair(s),  40 inverted  (83.3%)
destroy -> expose     242 pair(s), 120 inverted  (49.6%)
cracked -> expose      32 pair(s),  10 inverted  (31.2%)
dented  -> cracked     92 pair(s),  24 inverted  (26.1%)
```

The hole opened before its own crack on **five cells out of six**.

The old comment argued the kind-salt was needed so *"their bias separation would
not be all that ever distinguishes them"* — backwards: the bias separation IS the
ordering. Salted per CELL, every effect on a cell shares one wobble, so the order
within a cell is exactly the table and the front stays ragged (raggedness is a
property of WHERE a cell is, never of which effect).

**SMOKE WAS THE ONE PLAYED KIND WITH NO `cell`.** `_sort_key()`'s
`Vector2i.ZERO` fallback gave every puff in the blast the SAME roll: the smoke
front was a machined circle while everything else was ragged, and its separation
from the destruction was one random constant per blast (±0.45 on top of its 0.70
bias) rather than an average — so on some blasts the smoke led the decals. Both
smoke sites now carry the cell they already knew.

After, same plan, same audit — every ordered pair, **including the 1 664 smoke
pairs the audit could not even see before**: `0 INVERTED (0.0%)`.

## 4. The Director's hard-material spec, item by item

| item | state |
|---|---|
| decals loaded before the flash | ✅ the plan cooks in Beat 0, the flash is Beat 2 |
| revealed as a wave, centre outward | ✅ 24 frames, 1 voxel per frame |
| holes + dents + cracks TOGETHER | ✅ **this session** — 0% inversion across 15 pair kinds |
| then the smoke | ✅ and it stopped being a smooth ring |
| everything CLEAN in that window, no soot | ✅ measured: `soot fade: 0 of 825 entry cell(s) already carry their target scorch` |
| soot after the smoke, before the light | ✅ |

**"Waves or pure distance?"** — the Director could not remember. It is **pure
distance, and already was**: `flatten_plan()` sorts every step by
`r + KIND_RADIUS_BIAS[kind] + jitter`, and the ring table is a pure FILTER
(*"Dropping them changes what is drawn, never when."*). The Director's *"libertar
o sistema para executar a destruição do centro para fora, num passo só, com os
elementos se justapondo"* **is the shipped architecture** — it was simply running
12× too fast to see.

## 5. ⛔ DIRECTOR'S RULING — the soot map becomes the source of truth

Asked to disambiguate *"aplicar a fuligem na área afetada de forma permanente, no
mapa de fuligem"*, the Director chose: **stop re-deriving; the map is the truth.**
That is `SOOT_MASTER_PLAN` §3.2 Option B (stored per-cell state), which the plan
had recorded as not needed.

⚠️ **This does not contradict §6 Q3 and must not be read as reversing it.** Q3
answered *accumulation* — "two blasts on one spot should not leave a dirtier mark
than one" — and that still stands. **Permanence and accumulation are different
things:** permanence is about a blast's scorch never being recomputed or disturbed
by a later blast; accumulation is about it getting darker. Option B under this
ruling is permanent and NON-accumulating.

**Not started.** It is an architecture reform and wants its own plan first.

## 6. Soft materials — analysed, deliberately NOT changed

First capture of a flammable material this session (fabric, gu 31,5, 600 frames).
Phases, measured by diffing each frame against the settled end state (which
removes the static scenery for free):

| phase | time |
|---|---|
| cook | 0 – 0.60 s (nothing on screen) |
| flash | 0.62 – 0.67 s |
| destruction front | 0.68 – 1.07 s |
| fire | 0.80 – 1.80 s |
| **frozen board** | **1.87 – 2.60 s** |
| soot + light | 2.67 – 3.60 s |

**Two mismatches with the Director's spec, both DECISIONS rather than bugs:**

1. **"o que sobra fica em brasa nas bordas" — nothing survives.**
   `[E-BURN] 316 voxel(s) scheduled to burn AWAY — of 316 lit (100%)`. Every voxel
   the fire lights is consumed; lighting and being consumed are the same event.
   The glowing edge the Director describes needs a state that does not exist
   today — a lit voxel that does NOT enter the consumption list.
2. **0.73 s of dead board** between the fire ending and the soot arriving. ~10 900
   px of warm content is held and then released in one hard cut. Candidate is
   `BURN_SUSPEND_REGION_LIGHT` being restored in one step — **NOT VERIFIED**, and
   deliberately left as a hypothesis rather than written up as a finding.

**What is already built and working** (the mechanism is nearly all there):
`EMBER_CLIMB_*` climbs the fire up to 3 levels at decreasing chance,
`EMBER_CLIMB_LIFE_DECAY` shortens each rung's life, `EMBER_CLIMB_DELAY_S` staggers
the climb, `BURN_RADIAL_REACH_VOXELS` makes distance burn less, and every ember
death already calls `add_smoke()` — the Director's *"cada brasa que se apaga solta
uma fumacinha"* exists. Embers die cleanly: 324 → 201 → 24 → 0.

## 7. ⚠️ THREE OF MY OWN READINGS WERE WRONG. Recorded because the pattern repeats.

Every one was a number reported before it was checked, and the correction cost
more than the check would have.

- **"21 572 px of light land in one frame at the end."** One boot. It did not
  reproduce on ANY later boot of the identical build. The cook is budgeted in
  milliseconds, so the blast lands on a different frame index every run
  (`PERFORMANCE_MASTER_PLAN` §12.7 already says this). The real mechanism was the
  opposite — the cells arrived at the START (§2).
- **"The fire never goes out — 26 933 px frozen for 8 seconds."** The mask was
  wrong: it was counting static scenery (wooden crates, the light cone). The real
  slab was 2 839 px, and it was not fire at all.
- **"It is an overlay, not voxels."** Based on `INFILTRAITOR_HIDE_VOXELS=1` — and
  **the instrument did not take effect**; the walls and crates are still on screen
  in that capture. See §8.

**The orange slab was never a defect.** Director: *"O laranja é o fundo da cena.
Temos duas camadas de voxels no chão, quando as duas são destruídas aparece o
laranja."* They offered an indestructible third layer to make measurement easier;
declined, because the instrument is what needed fixing — diffing against the
settled end state removes static scenery for free and needs no map change.

## 8. ⚠️ `INFILTRAITOR_HIDE_VOXELS` DOES NOT DO WHAT ITS NOTE CLAIMS

It sets `layer.visible = false` inside `_build_voxel_layer_node()`. In a real
PLAYGROUND capture with it set, **the walls, crates and floor are all still
drawn** (`scratchpad/hidevox.png`, this session). Not investigated further.

This matters beyond this session: the instrument is listed in the 2026-08-26
summary's kept-instruments block and was used to price the voxel layers during the
performance wave. **Any conclusion that rests on it should be re-measured.**

---

## 8b. ⚠️ `update_docs.py` CAN SILENTLY DELETE DOCUMENTATION

Caught while closing this session, on the first run of the doc refresh:
`current_state.md`'s `version_history` block was replaced with
`(no version history)`, wiping five real entries. It did **not** reproduce on a
second run, and the git query it depends on measures 0.02 s returning 5 lines —
so this was a TRANSIENT failure of the subprocess.

`get_version_history()` ends in `except Exception: return []`, and
`build_version_history_block()` turns an empty list into the literal string
`(no version history)`. So any passing hiccup in one git call — this repo lives on
an external volume — **overwrites documented content with a placeholder, exits 0,
and says nothing.** The block is auto-generated, so the loss is recoverable from
git; the danger is that it is also invisible, and `update_docs.py` runs on push.

**Not fixed** — it is tooling and outside what this session was asked to change.
The shape of the fix is to fail loudly (or preserve the existing block) instead of
writing a placeholder over real content, which is the loud-fail rule this project
already applies everywhere else.

---

## 9. OPEN — in order

1. **The soot reform (§5), ruled on and not started.** Wants its own plan before
   any code: `SOOT_MASTER_PLAN` currently documents Option A as shipped and
   Option B as unnecessary, and both statements now need rewriting rather than
   patching.
2. **The glowing edge (§6.1)** — a new burn state, not an ordering change.
   Director decision on whether the fire should leave survivors at all.
3. **The 0.73 s frozen board (§6.2)** — shorten it, fill it by bringing the soot
   in earlier, or keep it as a deliberate breath. Needs the unverified
   `BURN_SUSPEND_REGION_LIGHT` hypothesis confirmed first.
4. **`INFILTRAITOR_HIDE_VOXELS` (§8)** — fix or retire, and re-check what was
   measured with it.
5. **`update_docs.py`'s silent wipe (§8b)** — one-line hardening, deliberately
   left for the Director to authorise.
6. **Smoke separation** — the Director chose to judge the 0.70-voxel trail on
   video rather than change the number blind. Now that the ordering is
   deterministic, that number finally means what it says.
7. **The sound effect for the new shadows** — carried from 2026-08-26. The
   Director ruled this session that audio waits for the audio milestone; there is
   no audio system at all (0 `AudioStreamPlayer` in the project, no bus layout,
   4 orphaned WAVs in a gitignored folder). `technical_debt.md` #6 estimates
   2–3 weeks and the roadmap puts it in Phase 4.
8. **Everything else from 2026-08-26 §9 is unchanged** — `build_occupancy()` /
   `field.build`, P7c's debris chips, `forget_ghost_record()`, SaveState's missing
   caller, MATERIALS M4/M5/M6.
