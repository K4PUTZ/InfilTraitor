# DEVICE_DIAGNOSTICS_MASTER_PLAN
## Measuring the real build on a real entry-tier phone — v1.3

**Status:** 🟢 **v1.3 — measuring, and the instruments come next (2026-09-14).**
Where the Moto g04s stands:

- **Benchmark:** idle frame 18.7 ms, render gpu 16.9 ms, detonations ~26–29 /
  ~32–33 ms — above the 24–25 fps floor (DIAG-12 §10.11, DIAG-14 §10.14).
  ⚠️ **It runs in the 390×844 portrait band at zoom 0.5** — a framing nobody
  plays in, not the player's frame (§10.16.1).
- **Hand play (DIAG-15 §10.15, re-read by DIAG-16 §10.16):** draw calls go
  1 370 → ~9 000, render gpu 17 → 86 ms, the frame sits at ~88 ms and
  detonations average 96–125 ms. **Most likely the VIEW, not the grenade:** the
  jump came with the "D" framing (1280×720, ~2.8× the world area) and the zoom.
  On the desktop the pinch minimum alone takes an untouched board 4 209 → 49 688
  draw calls. Not yet closed on the phone.
- **The voxel face shader (DIAG-13/14, §10.12–§10.14):** priced stage by stage;
  the per-quad plane path shipped with the debug paint compiled out.
- **§14 — the TEL suite, PROPOSED:** event timeline, command and view telemetry,
  runtime render attribution, frame percentiles and hitches, a scenario-driven
  benchmark that runs the human sequence, and an analyzer. §13 Q5–Q7 are open.
- **Director rulings (§14.6):** the framing follows the phone's orientation;
  JAMES is suspended until the performance milestone closes — Claude does
  everything, interface included.

⚠️ Not re-measured: the Galaxy A16. Untouched: the COMMIT and SOOT FADE freezes
(3.5–3.9 s by hand). Sections below that still read as proposals (§6–§8, §12)
predate the measured sections and are kept as written.

**Director, 2026-09-12:** *"A prioridade máxima é a gente testar se a explosão
vai ser factível num celular comum. O resto não serve pra nada se o jogo não
funcionar."* — and, on scope: *"Vamos construir a ferramenta completa, precisamos
ter diagnósticos confiáveis e bem arquitetados."*

---

## 0. Scope boundary — what this plan does NOT own

Two plans already own detonation performance, and this one must not become a
third voice on the same question (see the standing rule: when two systems
describe one feature, delete a claim instead of reconciling).

| Plan | Owns |
|---|---|
| [`DETONATION_PERFORMANCE_MASTER_PLAN`](DETONATION_PERFORMANCE_MASTER_PLAN.md) | The post-detonation stall and how it was closed. The measurements and the method stand. |
| [`PERFORMANCE_MASTER_PLAN`](PERFORMANCE_MASTER_PLAN.md) | Per-cell state leaving the TileSet; the standing engine perf architecture. |
| **This plan** | **Getting a trustworthy number off a physical Android device, reproducibly and without a human finger.** Nothing else. |

When this harness produces a number that says the blast is too expensive, the
FIX belongs in one of the two plans above, and is cited there — not here.

---

## 0.5 THE RATIFIED BUDGET (Director, 2026-09-12)

> *"O nosso sonho é 60 fps, mas se a gente conseguir 24/25 já estamos no lucro.
> A meta é 30fps. Lembrando que podemos demorar/lag no load do game, no load do
> mapa, e no pre-cook, mas NÃO durante o play do evento da explosão."*

| | fps | ms/frame |
|---|---|---|
| dream | 60 | 16.7 |
| **target** | **30** | **33.3** |
| floor ("no lucro") | 24–25 | 40–41.7 |

**The budget applies to the detonation's PLAYBACK frames only.** Game load, map
load and the pre-cook are explicitly allowed to be slow. This is not a loophole
— it is a scoping instruction the instrument can honour exactly, because
`[E-FRAME]` records beats as MARKS on the frame timeline: the cook beats are
identifiable, so the worst *playback* frame can be reported separately from the
worst frame overall. **Report both, and never let a cook frame be quoted as the
verdict.**

⚠️ This also settles what a first device run must not do: quoting a boot or bake
number as the answer. Measured on the Moto G04s, 2026-09-12: 46 s from launch to
`OnGodotMainLoopStarted`, of which the damage-variant bake is 6 227 ms. **Under
this ruling, none of that is a defect.**

---

## 1. The question, stated so it can be answered

> On a Moto G04s and a Galaxy A16 **5G**, does a full detonation on PLAYGROUND stay
> inside an acceptable frame budget — and does it stay there after several
> minutes of play, once the SoC is hot?

Three things about that phrasing are deliberate:

- **"a full detonation"**, not a synthetic patch. The standing lesson is that a
  green selftest does not mean the feature fires on the real map; a synthetic
  perf fixture is the same failure wearing a stopwatch.
- **"frame budget"**, not FPS. `INFILTRAITOR_EVENT_FRAMES` already reports the
  worst single frame of an event, which is the number a player actually feels.
- **"after several minutes"** — the entry-tier risk is thermal, and no single
  cold run can see it. See DIAG-07.

### 1.1 The targets are harsher than "celular comum" suggests

Both devices are entry tier with weak GPUs; the Moto G04s is expected to be the
harsher of the two.

The Galaxy is the **5G** variant (Director, 2026-09-12). That distinction is not
trivia: the A16 ships in 4G and 5G variants built on *different* SoCs, so "A16"
alone does not identify the hardware a number came from. Record the variant in
every result file next to the `getprop` block.

⚠️ **Do not write their SoC, GPU or RAM into this document
from memory.** DIAG-01 records them from `adb shell getprop` on the actual
handsets, and every result file carries that block, so no number is ever
orphaned from the hardware that produced it.

---

## 2. The blocker: 207 diagnostics that cannot be reached on a phone

The instrument this plan needs already exists and is well built.
`INFILTRAITOR_EVENT_FRAMES=1` (`room.gd:5805`) keeps the gap between *every*
frame of a detonation, marks each beat as a position on that timeline, and
prints:

```
[E-FRAME] <label> — N frame(s), X ms wall clock, mean Y ms · WORST Z ms on frame K
[E-FRAME]   f<i>  <beat>   its frame  A ms · then  B f,  C ms, max  D ms
```

Its own header explains why it refuses to bucket frames by beat, and that
reasoning is sound. **The instrument is not the problem.**

The problem is the switch. There are **207 `OS.get_environment` call sites**
across `godot/`, with **no central helper**. Environment variables do not reach
an Android application. So the entire diagnostic surface —
`EVENT_FRAMES`, `FRAME_PROBE`, `BURN_PROFILE`, `REPAINT_PROFILE`,
`THROW_PROFILE`, `PREDICTION_PROFILE`, every capture action — is **inert inside
the APK**. Today the build on the phone is a black box.

That is the single thing to fix. Everything else in this plan is assembly.

---

## 3. DIAG-00 — the flag-channel spike ✅ RESOLVED 2026-09-12

Run on the real handset. **The winner is the app's EXTERNAL files directory**,
and it is better than any option this plan originally listed.

| # | Channel | Verdict |
|---|---|---|
| **A** | `command_line/extra_args` in the Android preset | Works (it is how `--xr-mode off --fullscreen …` already reach the engine), but costs a full re-export + install ≈ 40 s per flag change. Kept as a fallback, not the primary. |
| **B** | `adb push` to `user://` (app-private internal storage) | ⛔ Needs a debuggable build, and a debug template is not a release template — it would change the perf being measured. Rejected. |
| **C** | Intent extra `--esa command_line_args` on `am start` | ⛔ **MEASURED DEAD.** The extra is accepted by Android (`Intent { … (has extras) }`) and **never reaches Godot**: `InitEngine with params:` came back byte-identical, and `--verbose` produced zero extra engine output. Assumed working in v0.1 of this plan; it is not. |
| **B′** | **`adb push` to `/sdcard/Android/data/<pkg>/files/`** | ✅ **THE ANSWER.** |

### 3.1 Why B′ wins outright

```
adb push dev_flags.cfg /sdcard/Android/data/com.example.infiltraitor/files/
```

15 bytes in 0.001 s. The directory is owned by the app's own uid
(`u0_a314`, group `ext_data_rw`), so **the app can read it with no permission
declared** — Android 11+ gives every app free access to its own external files
directory. Consequences, all of which matter:

- **No debuggable build.** The APK measured is the APK shipped: release
  template, release renderer, release performance.
- **No manifest permission**, so nothing about the build changes to enable
  diagnostics.
- **Seconds per flag change**, against 40 s for channel A.

`DevFlags` therefore resolves: `OS.get_environment` → this file → default.
⚠️ Godot reading that absolute path is the one step not yet proven on device
(it needs DevFlags to exist). DIAG-01 must verify it against a real read and
keep channel A as the fallback if Godot refuses the path.

---

## 4. DIAG-01 — `DevFlags`, the one seam ✅ BUILT 2026-09-12 (01a + 01b)

**Verified on the handset, which was the one step §3.1 left unproven:**

```
[DevFlags] 3 override(s) from /sdcard/Android/data/com.example.infiltraitor/files/dev_flags.cfg
           — EVENT_FRAMES=1, MAP=PLAYGROUND, NO_VSYNC=0
```

Release APK, no declared permission, no debuggable build, 84 bytes pushed in
0.000 s. Godot reads the absolute external path; the channel-A fallback is not
needed.

**01b migrated ten sites in `room.gd`** — `EVENT_FRAMES`, `EVENT_FRAMES_TOTAL`,
`EVENT_THROW_AT`, `EVENT_NO_STRIP`, `FRAME_PROBE` (×2), `NO_VSYNC`, `MAP` (×2).
The other ~195 are untouched, per the staged policy below.

**Two traps found while migrating, both recorded in the code:**

- **The autoload is absent under `godot --script`**, which is how several tools
  and selftests instantiate `room.gd`. `room.gd` therefore asks through
  `_dev_flag()`, which uses `get_node_or_null("/root/DevFlags")` — the project's
  established idiom (`Localization`) — and falls back to the literal
  pre-DIAG-01 expression, so a `--script` context behaves exactly as before.
- **`_frame_probe` could not stay a member initialiser.** Those run before the
  node is in the tree, so `/root/DevFlags` is unreachable and every device run
  would have fallen silently through to the environment — which on Android is
  empty. It resolves in `_ready()` now.

`dev_flags_selftest.tscn` pins the seam and was proven RED before green:
inverting the resolution order (file before environment) fails TEST 2 with
`environment not honoured — on()=false value()='0'`. `dev_flags.cfg` is
gitignored, because `res://` is a candidate path and a committed one would
silently override the environment for everyone in every build.

**DIAG-12 (2026-09-12) added, all default absent and asked through `DevFlags`:**
`NO_FACE_SHADER`, `HIDE_VOXELS` (fixed — it was inert), `HIDE_LEVELS_ABOVE` /
`HIDE_LEVELS_BELOW`, `QUADRANT`, `STRETCH_VIEWPORT`, `ZOOM`, `HIDE_NON_VOXEL`,
`HIDE_NODES=<name*>`, `NODE_CENSUS`, `CONE_REDRAW_ALWAYS`, and `NO_LIGHT` now
reaching the APK (degenerate on this build — §10.11.1). `FRAME_PROBE` gained
`process` / `physics` / node columns (held maxima, not means) and a `[FRAME-SPLIT]`
line from `FrameSplit`. What each one measured is §10.11.

### 4.1 The original design (unchanged)

An autoload exposing the diagnostic switch, with a strict resolution order:

1. `OS.get_environment(name)` — **first, always.** Desktop behaviour is
   bit-identical to today, so nothing in the existing harness regresses.
2. The channel DIAG-00 chose.
3. The default.

```
DevFlags.on("EVENT_FRAMES")        -> bool
DevFlags.get("SHOT_WEAPON", "")    -> String
DevFlags.num("EVENT_FRAMES_TOTAL", 0) -> int
```

**Migration policy — deliberately not "all 207 at once".** The Director asked
for the complete tool, and the complete tool is the *seam*, not a mass edit. A
207-site sweep in one commit is exactly the shape of change that deleted every
wall in the game on 2026-07-12. So:

- **DIAG-01a** — build `DevFlags` + its selftest. Zero call sites migrated.
- **DIAG-01b** — migrate the **detonation measurement path only**:
  `EVENT_FRAMES`, `EVENT_FRAMES_TOTAL`, `FRAME_PROBE`, `MAP`, plus whatever
  DIAG-03's scenario needs. Roughly a dozen sites, each one read before it is
  touched.
- **DIAG-01c** — the remaining sites migrate *on demand*, whenever a probe is
  first needed on device. A site nobody has needed on a phone is not a gap.

An invariant hook (`L4 dev-flag-behind-the-seam`) is **deferred to DIAG-08** and
only lands once 01c is substantially done — a gate that fires on 190 legitimate
un-migrated sites is a gate that gets bypassed, which is its own standing lesson.

---

## 4.5 ✅ THE GAME RUNS ON THE MOTO G04s (2026-09-12)

The prior question to every number in this plan, and it is answered: the release
APK boots, loads a map, bakes the agent and renders, under the **Vulkan Mobile**
renderer, with no fatal error. Hardware recorded by `device_run.py`:

```
motorola moto g04s (Spreadtrum T606), Android 14 / SDK 34,
3834312 kB, 720x1612 @ 280 dpi, arm64-v8a, GPU Mali
```

⚠️ **The first launch said otherwise, and it was lying.** With the phone's
screen off, the log read:

```
E vulkan : native_window_api_connect() failed: No such device (-19)
ERROR: Failed to create vulkan window.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

That is **not** a Vulkan driver failure on a cheap SoC, which is exactly what it
looks like and what §7 had primed everyone to expect. The activity took
`OnResume` and then `OnPause` 33 ms later because the device was dozing and
locked, so there was no surface to attach to. **A screensaver was one report away
from being recorded as a renderer verdict.** `device_run.py` checks wakefulness
and lock state before it will launch, for this reason and no other.

Two more device facts the harness needed:

- `am start -n <pkg>/com.godot.game.GodotApp` is **denied** — Godot's main
  activity is `exported=false`. The launchable entry is the alias
  **`com.godot.game.GodotAppLauncher`**.
- Logcat on this handset emits `audio_hw_record_nr` and `BLASTBufferQueue` lines
  roughly every 10 ms, permanently. §5's "logcat drops lines under load" risk is
  real and present at idle; the capture filters by tag.

---

## 5. DIAG-02 — results out of the device ✅ BUILT 2026-09-12 (`device_run.py`)

`print()` on Android goes to logcat, so the existing probes need no output
change. The harness reads them with:

```
adb logcat -c && adb shell am start -n com.example.infiltraitor/com.godot.game.GodotApp && adb logcat -d -s godot:V
```

⚠️ **logcat drops lines under load.** A detonation that floods the log can lose
exactly the `[E-FRAME]` line the run existed to produce. Mitigations, in order:
keep the probe's output to the handful of summary lines it already prints (it
does); raise the buffer with `adb logcat -G 16M`; and **fail loudly** if the
expected `[E-FRAME]` line is absent, never silently report a partial run. A
harness that writes nothing is a claim about the harness, not about the game.

---

## 6. DIAG-03 — a scenario that runs without a finger

A measurement is worthless if the human varies it. The desktop capture harness
already solves this (`INFILTRAITOR_CAPTURE_ACTION` and friends drive a scripted
boot → place agent → throw → detonate → report → quit). **Reuse it; do not write
a second one.** Once DIAG-01b makes those flags reachable, the device scenario is
the same scenario.

Pinned by `INFILTRAITOR_RNG_SEED` so two runs are comparable, and by a fixed
grenade GU so the blast hits identical geometry every time.

---

## 7. DIAG-04 — the renderer spike ⚠️ (possible re-scoping finding)

`project.godot:175` sets `renderer/rendering_method="mobile"` — the **Vulkan**
Mobile renderer. There is no `.mobile` platform override in the file, so that is
what the APK runs.

Entry-tier SoCs are exactly where Vulkan driver quality is worst, and a bad
driver does not announce itself: it shows up as a frame-time number that gets
blamed on the blast. So the harness must be able to answer *"is this the
detonation, or is this the renderer?"* by running the identical scenario under
`gl_compatibility` as a control.

**If `gl_compatibility` is dramatically faster on these handsets, that is a
finding that outranks every detonation optimization in the other two plans**,
and it must be reported before any blast tuning is proposed.

---

## 8. DIAG-05 — the emulator, and what it is honestly for

Install `emulator` + `system-images;android-34;google_apis;arm64-v8a` (neither
is currently present under `/opt/homebrew/share/android-commandlinetools`;
there are no AVDs).

**It is for rehearsing the harness, never for producing a number.** On Apple
Silicon it runs arm64 natively on an M-series CPU with a Metal-backed GPU and
desktop cooling. It is a desktop wearing Android. It will answer the priority
question optimistically, confidently, and wrongly — and it is structurally
incapable of showing thermal throttling, which is the main entry-tier risk.

What it genuinely buys: the whole install → flag → launch → logcat → parse loop
can be debugged with no handset attached, which is worth real time given the
phone is currently not even enumerating on USB.

**Every result file records whether it came from an emulator or a handset, and
the parser refuses to write an emulator number into a device results table.**

---

## 9. DIAG-06 — `tools/persistent/export_android.py` ✅ BUILT 2026-09-12

Director-requested, and the only task in this plan that did not need the flag
channel, so it landed first.

**Result of the first real run:** 491.1 MB → **130.6 MB**, 33 s, signed, all
three trap assertions green. The previous `export/Infiltraitor.apk` was
confirmed pre-fix by the script itself: 130 source-texture entries and **zero**
localization CSVs (only the unused `.translation` products), exactly traps #1
and #2 from `MobileTesting.md`.

### 9.1 ⚠️ The finding that justifies the whole script

`--export-release` **writes a complete, correct-looking APK even when the export
FAILED.** With no release keystore, Godot printed `Could not find release
keystore, unable to export.` and exited 1 — and left a 129.3 MB APK on disk that
passed *every* content assertion and contained **no `META-INF` at all**.
Unsigned. Installable on nothing.

A first draft of this script checked only `apk.exists()` and reported success on
that build. Two checks were added because of it, and both belong to the standing
loud-fail contract:

- the export step now fails on Godot's own `export for preset … failed` line;
- the verifier asserts a `META-INF` signature block.

**Neither the file existing, nor it being the right size, nor it containing the
right files, is evidence that an export succeeded.**

### 9.2 Signing route, measured

| route | result |
|---|---|
| no release keystore | exit 1, unsigned APK left on disk |
| `keystore/release=…` in `export_presets.cfg` | ⛔ did **not** work — fields persisted, Godot reported the same "could not find" |
| `GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}` | ✅ exit 0, `apksigner verify` clean |

The env-var route is also the only one that belongs in a tracked repo:
`export_presets.cfg` is committed, so the preset route would have put a keystore
path and password into git history. The script discovers Godot's own debug
keystore and sets the variables itself.

⚠️ This signs a **release** build with the **debug** keystore — correct for
measuring our own handsets, not publishable. A store build needs a real release
keystore, which is a Director decision and outside this script.

### 9.3 What it does

- Runs the headless export, times it, and reports the resulting APK size.
- **Refuses to hand back an APK that still contains the excluded source
  textures.** The current `export/Infiltraitor.apk` (515 MB, 2026-09-11) is
  pre-fix: `unzip -l` shows `digital_00017_diffuse_2048.jpg-….ctex` at 10 MB and
  many siblings. The preset's `exclude_filter` is correct *now*, so this is a
  stale artifact — but a size/content assertion is the only thing that keeps it
  from silently coming back.
- Optional `--install` (adb), `--flags` (writes the DIAG-00 channel).
- Prints the `.pck`/assets composition on request, because reading what a build
  really contains is how all three export traps were found in the first place.

---

## 10. DIAG-07 — the sustained run

One cold detonation is the easy half. The entry-tier question is what the frame
budget looks like on the **tenth** detonation, several minutes in, with the SoC
throttled.

- N detonations back to back in one boot, reporting every `[E-FRAME]` line.
- `adb shell dumpsys thermalservice` and battery temperature sampled alongside,
  so a degrading number can be attributed rather than guessed at.
- **Report the curve, not the mean.** A mean hides exactly the effect being
  looked for.

This is also where the standing "expensive vs expensive ONCE" lesson applies:
fire the event more than once in a boot before concluding anything about cost.

---

## 10.5 🔴 THE FIRST REAL NUMBER — 2026-09-12, Moto G04s

Three hand-played detonations on PLAYGROUND, release APK, vsync ON, no capture
harness, `EVENT_FRAMES=1` through the DIAG-00 channel.

```
detonation — 233 frame(s), 32076 ms wall clock, mean 137.7 ms · WORST 4728.7 ms on frame 110
detonation — 239 frame(s), 31127 ms wall clock, mean 130.2 ms · WORST 3746.5 ms on frame 117
detonation — 235 frame(s), 23935 ms wall clock, mean 101.9 ms · WORST  486.1 ms on frame 113
```

### 10.5.1 The verdict against §0.5's budget

Read the THIRD run — the first two pay one-time costs and the worst frame falls
4728 → 3746 → 486 ms across them, which is the standing "expensive vs expensive
ONCE" lesson behaving exactly as documented. Steady state, split at the beat the
Director's ruling splits at:

| span | frames | wall | mean/frame | vs 33.3 ms |
|---|---|---|---|---|
| fuse + PUMP (pre-cook, **allowed** to lag) | 113 | 11 190.7 ms | 99.0 ms | — |
| **playback (COMMIT → WAVES end)** | **122** | **12 744.3 ms** | **104.5 ms** | **3.1× over** |
| worst single playback frame (COMMIT) | 1 | 486.1 ms | 486.1 ms | **14.6× over** |
| worst single playback frame, COLD | 1 | 4 728.7 ms | 4 728.7 ms | **142× over** |

**The detonation is not viable on this handset today.** Playback runs at ~9.6 fps
against a 30 fps target, and misses even the 24–25 fps floor by 2.6×. No reading
of the ruling rescues it: the over-budget frames are all after COMMIT, which is
play, not cook.

⚠️ One honest note on the fuse: the 11.2 s PUMP span **is** the pre-cook and is
therefore inside the allowance — but it is also 113 frames the player spends
watching a lit grenade at ~10 fps. It is not a budget violation; whether it is
acceptable is a separate Director question.

### 10.5.2 ⚠️ The cause is probably NOT the blast — read this before optimising

Two instruments were read immediately after, and they point somewhere else.

**Thermal is exonerated.** SoC 41.3 °C, battery 30.3 °C, `mStatus=0` on every
zone — no throttling at all. §10's thermal hypothesis is not what happened here.

**Memory is not.** `dumpsys meminfo`, same session:

```
GL mtrack:       1 055 556 kB   (1.05 GB of graphics memory)
TOTAL PSS:       2 589 208 kB   (2.59 GB)
TOTAL RSS:       1 467 940 kB
TOTAL SWAP PSS:  1 181 411 kB   (1.18 GB SWAPPED OUT)
```

**On a 3.83 GB device, 1.18 GB of our process is paged out.** Every frame that
touches swapped memory pays decompression or flash I/O, and that is precisely
the shape of what was measured: a 4.7 s first COMMIT falling to 486 ms once the
pages are resident, with no thermal component.

This is a **hypothesis with strong evidence, not a conclusion.** What it predicts
and how to falsify it is DIAG-09 below. What it should stop immediately is anyone
optimising the detonation's arithmetic on the strength of §10.5.1 alone — the
3.1× may not be in the blast at all, and 1.05 GB of GL memory on a phone is a
number that needs explaining regardless of what it is costing.

Prior art that makes this more likely, not less: `PERFORMANCE_MASTER_PLAN`'s
standing finding that per-cell visual state lives in TileSet alternatives, and
that minting one alternative rebuilds every layer's TileSet. A large alternative
population is exactly how a 2D tile game arrives at a gigabyte of texture memory.

### 10.5.3 DIAG-09 — falsify the memory hypothesis before optimising anything

In this order, cheapest first. Each is an A/B on the same handset, same map,
steady state (third detonation onward), reading `[E-FRAME]` and `meminfo` together:

1. **Count the TileSet alternatives** and the atlas memory at load, before any
   detonation. If graphics memory is already near 1 GB at idle, the blast is a
   victim.
2. **Dev overlays off** (`CAPTURE_NO_DEV` and friends, now reachable on device
   via DevFlags). The occlusion wireframe and the DEV VISION panel are live in
   these runs; on desktop the VFX overlays were once measured at 25 ms/frame.
   ⚠️ A control run is mandatory — a number that improves is not proof the
   overlay was the cause unless the same run shows the overlay gone.
3. **`gl_compatibility` vs `mobile`** (§7), unchanged in intent but now
   third in line, because thermal is out and memory is in.
4. **The same three detonations on the Galaxy A16 5G**, which has a different
   SoC and a different memory size. If playback scales with available memory
   rather than with CPU class, the hypothesis holds.

---

## 10.6 🔴 DIAG-09 §1 ANSWERED — the blast is a victim, and the map is the cost

`MEM_CENSUS=1`, Moto G04s, PLAYGROUND, release APK, **nothing detonated**.

```
[MEM-CENSUS] tileset: 135 source(s), 32987 tile(s), 0 minted alternative(s)
[MEM-CENSUS] atlas upper bound (RGBA8): 163.8 MB
[MEM-CENSUS] layers: 32 opaque, 16 glass · placed cells: 145448
```

and `dumpsys meminfo` at that exact moment, against the same reading taken after
the three detonations of §10.5:

| | **at load, nothing detonated** | after 3 detonations | delta |
|---|---|---|---|
| GL mtrack (graphics) | **733 760 kB — 734 MB** | 1 055 556 kB — 1.05 GB | **+322 MB** |
| Native Heap, resident | **804 464 kB — 804 MB** | 194 956 kB — 195 MB | **−609 MB, paged out** |
| TOTAL PSS | **2 221 914 kB — 2.22 GB** | 2 589 208 kB — 2.59 GB | +367 MB |
| TOTAL SWAP PSS | 625 705 kB — 626 MB | 1 181 411 kB — 1.18 GB | **+555 MB** |
| device MemAvailable | **589 MB** | — | — |

### 10.6.1 The mechanism, now measured rather than suspected

**The map alone costs 2.22 GB on a 3.83 GB phone, leaving 589 MB available
before anything happens.** A detonation then asks for ~322 MB more graphics
memory, and the only way the OS can find it is to page out 555 MB more of our
native heap — 804 MB resident becomes 195 MB. Every subsequent frame that
touches that heap pays to bring it back.

That is the 4 728 ms first COMMIT, and it is why the third detonation cost
486 ms: by then the pages it needed were resident again.

**The §10.5.2 hypothesis is confirmed, and the consequence is a re-scoping.** The
detonation is not 3.1× over budget because its arithmetic is slow. It is over
budget because it runs in 589 MB of headroom. **Optimising the blast would be
optimising the wrong thing.**

### 10.6.2 ⚠️ 570 MB of graphics memory is NOT the tileset

This is the open question, and the census is what made it askable. Our own atlas
sources total **163.8 MB** as an RGBA8 upper bound — a bound, so the real figure
is that or less. Graphics memory at the same instant is **734 MB**.

**The gap is ~570 MB and we do not know what it is.** Candidates, none measured:
- the 48 `TileMapLayer`s' own rendering data across 145 448 placed cells;
- the agent sprite bakes (24 yaws × layers × postures × facings, all built at
  load — the boot log shows them);
- the damage-variant bake (264 atoms) and its composite pages.

⚠️ **Do not act on that list.** It is three guesses, and the session that just
ended contains two separate cases of a plausible reading being wrong (a
screensaver that read as a Vulkan driver failure; a detonation cost that was
really a paging cost). Measure which one it is first.

### 10.6.3 Two instruments returned null, and both are recorded as such

- `RenderingServer.get_rendering_info(...)` — texture, buffer and video memory
  all read **0.0 MB**, on desktop Forward+ *and* on the device, at a moment when
  the atlas is provably 163.8 MB. The census prints a warning when all three are
  zero rather than reporting a zero.
- `OS.get_static_memory_usage()` — 1 340.3 MB on the desktop editor build,
  **0.0 MB in the release APK**. It is debug-only.

Neither is evidence about the machine. `dumpsys meminfo` is the working
instrument on device.

### 10.6.4 What comes next

DIAG-09 §2–4 (dev overlays, renderer, the A16) are **not superseded**, but they
are now second-order: they are questions about frame cost, and the finding above
says the constraint is footprint. The next measurement should locate the 570 MB.

---

## 10.7 🔴 THE 570 MB IS THE BOARD ITSELF — boot decomposed, 2026-09-12

`MEM_STAGES=1` markers correlated against `device_run.py --mem-poll 5`. Moto
G04s, PLAYGROUND, release APK.

| stage | at | GL mtrack | TOTAL PSS |
|---|---|---|---|
| 00 flags resolved | 18:14:26 | 67.5 MB | 322 MB |
| 10 voxel TileSet built | 18:14:27 | 67.5 MB | — |
| 11 room build starts | 18:14:27 | 67.5 MB | 582 → 1053 MB |
| 12 wall/facade bake complete | 18:14:45 | **→ 198.8 MB** | 1251 MB |
| (room build continues) | 18:14:52 | **→ 461.5 MB** | 1529 MB |
| 19 before damage bake | 18:14:56 | 461.5 MB | 1599 MB |
| 20 damage variants baked | 18:14:58 | **461.5 MB — unchanged** | 1638 MB |
| 40 map loaded | 18:15:18 | **→ 728.8 MB** | 2210 MB |

### 10.7.1 Two of the three candidates are eliminated

**The damage-variant bake is EXONERATED.** It runs 18:14:56.8 → 18:14:58.4 —
1 586 ms for 447 atoms — and graphics memory across it is **461.5 MB before and
461.5 MB after**. It was the candidate that looked most likely from the desktop
side; it costs essentially no graphics memory.

**The agent sprite bake is exonerated too.** Its frames load between stages 20
and 40 (its own log lines are in the same timeline) while GL mtrack sits flat at
461.5 MB until the final submission.

**What is left is the board.** Graphics memory arrives in three steps, none of
them a bake of ours:

| | |
|---|---|
| voxel TileSet | 67.5 MB |
| wall/facade bake | +131 MB |
| room build / voxel placement | +263 MB |
| final map-load submission | +267 MB |
| **total** | **728.8 MB** |

**~530 MB of the 734 MB is room build, voxel placement and submission** — the
**32 opaque + 16 glass `TileMapLayer`s carrying 145 448 placed cells**. Our atlas
sources are 163.8 MB of it; the rest is what the engine allocates to DRAW that
many cells across that many layers.

⚠️ Attribution is bounded by a 5-second poll interval. Each step above is
bracketed by stage markers, but a cost could sit anywhere inside its bracket.
The three conclusions that do NOT depend on the interval are the two
exonerations (GL mtrack is flat across both bakes, at samples on either side)
and the totals.

### 10.7.2 ⚠️ The board is evicted at IDLE, before the blast is thrown

After "40 map loaded", with nobody touching the game:

```
18:15:18  PSS 2210 MB   swap   128 MB
18:15:40  PSS 2232 MB   swap   622 MB
18:16:11  PSS 2240 MB   swap   817 MB
```

**817 MB of our process is paged out within a minute of loading, at idle.** The
detonation does not arrive at a healthy process and then overload it — it
arrives at one the OS has already been evicting for a minute. That is why the
first COMMIT cost 4 728 ms and the third 486 ms, and it reframes §10.5 one more
step: the blast's cost is largely the cost of faulting the board back in.

### 10.7.3 What this makes the real question

Not "why is the detonation slow" but **"why does a 44×22 board cost 2.2 GB"**.
That question belongs to `PERFORMANCE_MASTER_PLAN`, whose standing finding —
per-cell visual state living in TileSet alternatives, one mint rebuilding every
layer's TileSet — is about the same subsystem this measurement just named.

Two shapes of answer, neither investigated, both out of this plan's scope:
fewer layers, or fewer live cells per layer. ⚠️ **Do not pick one from this
paragraph.** Three candidate causes were written down before this measurement
and two of them were wrong.

### 10.7.4 Instruments, honestly

A third null to add to §10.6.4: `FileAccess.open("/proc/self/status")` returns
**null with error 1 on Android** — the engine's path sandbox admits `/sdcard/...`
(DevFlags reads its overrides there) but not `/proc`, and there is no stock
Godot API for per-process memory in a release build. `MemStage` therefore prints
the stage LABEL regardless, so the timeline survives for correlation:
**losing the numbers is a degraded measurement, losing the timeline is no
measurement at all.** `dumpsys meminfo` from the host is the working instrument,
and `--mem-poll` is how it gets sampled.

---

## 10.8 🔴 THE GALAXY REPLICATES IT — a 2× faster CPU bought 8%

Same battery on a **Galaxy A16 5G** (SM-A166W, Exynos 1330 / `s5e8535`, Android
16, **3.37 GB** — less RAM than the G04s — 1080×2340 @450 dpi, 8 GB of swap).

### 10.8.1 The comparison that settles it

| | Moto G04s (T606) | Galaxy A16 5G (Exynos 1330) | ratio |
|---|---|---|---|
| boot → map loaded | ~51 s | **24.5 s** | **2.08× faster** |
| playback mean (3rd run) | 104.5 ms | **95.9 ms** | **1.09× faster** |
| playback worst frame | 486.1 ms | **2 134.8 ms** | **4.4× worse** |
| GL mtrack at load | 734 MB | **746 MB** | — |
| GL mtrack after 3 blasts | 1.05 GB | **1.04 GB** | — |
| TOTAL PSS at load | 2.22 GB | **2.24 GB** | — |
| swap at idle | 817 MB | **1.42 GB** | — |
| RSS resident, steady | 1.47 GB | **840 MB** | — |

**A CPU that halves the boot time moves playback by 8%.** That is the finding.
Whatever the detonation is waiting on, it is not arithmetic.

### 10.8.2 The footprint is architectural, and the screen proves it

Graphics memory is **746 MB vs 734 MB** — a 1.6% difference — on a screen with
**2.2× the pixels** (1080×2340 vs 720×1612). If any meaningful part of that
figure were framebuffer, resolution-dependent surfaces, or render targets, the
Galaxy would be far higher. It is not.

The same holds after three detonations: **1.04 GB vs 1.05 GB**. Two different
SoCs, two different GPU vendors, two different Android versions, two different
screen resolutions — and the same footprint to within 1%. **It is our board,
and it is hardware-independent.**

The `MEM_CENSUS` numbers are byte-identical on both: 135 sources, 32 987 tiles,
163.8 MB of atlas, 32 opaque + 16 glass layers, 145 448 placed cells.

**The damage-variant bake is exonerated a second time**, independently:
GL mtrack 463.0 MB before it and 465.2 MB after, on a different SoC and OS.

### 10.8.3 ⚠️ Where the prediction was WRONG, and what it teaches

§10.7 predicted the Galaxy would be *"equal or worse"*. On the mean it was
right — 8% is equal, not the 2× a doubled CPU would imply. **On the worst frame
it was wrong in an informative direction.**

The two handsets trend in OPPOSITE directions across three detonations:

```
Moto G04s    worst frame   4728.7  ->  3746.5  ->   486.1 ms    (warms up)
Galaxy A16   worst frame    672.6  ->  2059.6  ->  2134.8 ms    (degrades)
```

The G04s warms: pages faulted in by the first blast are still resident for the
third. The Galaxy cannot — it has **450 MB less RAM** and is already 1.42 GB in
swap at idle with only 840 MB of 2.24 GB resident. Each detonation evicts what
the last one faulted in, so there is no warm state to reach.

**That is the mechanism confirmed from the other side.** §10.5 read the
G04s's 4728 → 486 as one-time costs being paid; the Galaxy shows the same
memory story producing the opposite curve when the headroom is smaller. A
reading that explains both is stronger than one that explained the first.

⚠️ It also retires a convenience: **"take the third run, it is warm" is not a
general rule.** It was a property of that handset's headroom. Report the curve.

### 10.8.4 The verdict on the priority question

Against §0.5's ratified budget (30 fps / 33.3 ms on playback frames), on the
better of the two target handsets:

- playback mean **95.9 ms — 2.9× over**, ~10.4 fps;
- worst playback frame **2 134.8 ms — 64× over**;
- the 24–25 fps floor is missed by **2.4×**.

**The detonation is not viable on either target device, and the cause is not
the device.** Two handsets that differ in CPU class, GPU vendor, OS version,
screen resolution and RAM produce the same 2.2 GB board and the same verdict.

---

## 10.9 🔴 DIAG-10 — THE BAKE IS THE TRADE-OFF AXIS, and the benchmark has a fidelity gap

Automated benchmark (`BENCHMARK=1`, `BENCH_RUNS=3`, `RNG_SEED=1234`), Galaxy
A16 5G, release APK, three runs each side.

| | bake ON | bake OFF (`NO_BAKE=1`) |
|---|---|---|
| playback mean, runs 1/2/3 | **24.1 / 29.3 / 23.9 ms** | **58.2 / 53.5 / 54.9 ms** |
| worst frame, runs 1/2/3 | 135.8 / 861.1 / 139.4 ms | 923.7 / 795.8 / 819.0 ms |
| GL mtrack | 736 MB | **312 MB** |
| TOTAL PSS | 2.19 GB | **1.15 GB** |
| swap | 1.31 GB | **358 MB** |
| boot → map loaded | 22.2 s | **8.4 s** |
| TileSet | 135 sources, **32 987 tiles**, 163.8 MB atlas | 98 sources, **98 tiles**, 0.4 MB atlas |

### 10.9.1 The bake buys speed with memory, and the exchange rate is now known

**Turning the bake off halves the footprint** — 2.19 GB → 1.15 GB, graphics
−424 MB, swap −950 MB, boot 2.6× faster — **and makes the detonation 2.3×
slower**, 24 → 55 ms mean.

The census says exactly why: the bake takes the TileSet from **98 tiles to
32 987**. That is the 163.8 MB of atlas, and it is most of the ~424 MB of
graphics memory that goes with it. §10.7 found the board was the cost and
named "room build / voxel placement" — **this locates it one level further:
it is the baked tile population those layers are placed FROM.**

This also confirms, on device, the desktop finding that the bake is a *saving*
in frame cost (measured there as off = +243%; here +130%). **It was never a
question of the bake being waste. It is a trade: ~1 GB of RAM for 2.3× blast
speed** — and on a 3.4 GB handset that is a trade worth re-pricing, which is a
Director decision, not an engineering one.

### 10.9.2 ⚠️ THE BENCHMARK DOES NOT REPRODUCE HAND PLAY — 3.5× apart

**Do not quote 24.1 ms as the player's experience.** On the same handset, the
same map, the same day:

| | hand-played | automated |
|---|---|---|
| playback mean | 78.5 / 85.4 / 88.1 ms | 24.1 / 29.3 / 23.9 ms |
| COMMIT frame | 2 134.8 ms | 112.7 ms |
| SOOT FADE | 1 679.9 ms | 71.8 ms |
| LIGHT, 60 frames both | 4 145 ms | 1 161 ms |
| fuse/PUMP per frame | 71.9 ms | 35.6 ms |

Every beat is cheaper in the scripted path, including the FUSE — which runs
before anything is destroyed, so this is not simply "the blast hit less
geometry".

**The obvious explanation was tested and failed.** Memory state was nearly
identical: 1.31 GB of swap during the automated run against 1.42 GB during the
hand-played one. Paging does not account for it.

So the scripted path is missing something the real one does, and **until that
is named the benchmark is a COMPARATOR, not a measurement.** Its A/B above is
valid — both sides ran the identical path — while its absolute numbers are not
the player's. This is the standing "instrument fidelity before symptom" trap:
a demo that skips what the real path does measures its own gap.

**DIAG-11, open:** name the gap. Candidates, unranked and none tested — the
targeting/throw flow the benchmark bypasses by calling `detonate_active()`
directly; HUD and dev overlays live during play; the agent's own per-frame work
while selected. ⚠️ Two of three candidate lists in this plan have already been
wrong; measure, do not pick.

### 10.9.3 What the budget says, with that caveat attached

Against §0.5 (30 fps / 33.3 ms, playback frames), on the Galaxy:

- **hand-played, bake ON: 78–88 ms — 2.4–2.6× over.** This is the number that
  reflects a player, and it is the honest verdict until DIAG-11 closes.
- benchmark, bake ON: 24 ms — inside budget, but see §10.9.2.
- benchmark, bake OFF: 55 ms — 1.65× over, at half the memory.

**Nothing here overturns §10.8's verdict.** It adds the axis the fix will be
chosen on.

---

## 10.10 🔴 DIAG-11 — THE IDLE BOARD IS THE CONSTRAINT, AND IT IS GPU

`FRAME_PROBE=1` alongside the benchmark, Galaxy A16 5G, release APK, bake ON.
The board **settling with nothing happening**:

```
[FRAME-PROBE] 22.2 ms/frame · render cpu 2.5 ms · render gpu 15.9 ms · 1379 draw call(s) · 41082 primitive(s) · 25535 object(s)
[FRAME-PROBE] 17.7 ms/frame · render cpu 2.6 ms · render gpu 14.3 ms · 1379 draw call(s) · 41082 primitive(s) · 25535 object(s)
[FRAME-PROBE] 24.2 ms/frame · render cpu 2.9 ms · render gpu 19.8 ms · 1379 draw call(s) · 41082 primitive(s) · 25535 object(s)
[FRAME-PROBE] 16.5 ms/frame · render cpu 2.4 ms · render gpu 14.3 ms · 1379 draw call(s) · 41082 primitive(s) · 25535 object(s)
```

**A static board, no detonation, nothing moving, costs 17–24 ms/frame — of a
33.3 ms budget.** And the split names the half: **render gpu 14–20 ms against
render cpu 2.4–3.3 ms.** It is not script. It is **1 379 draw calls and 25 535
objects**, every frame, to draw a board that is not changing.

⚠️ vsync is ON in this run, so readings at ~16.7 ms are the refresh cap, not the
work. `render gpu` is measured independently of it and is the honest signal —
and it never drops below **14.3 ms**.

### 10.10.1 What this does to every earlier number

**The detonation adds roughly 10 ms to a frame that already costs 20.** The
benchmark's 24–29 ms playback mean is an idle board of ~20 ms plus a blast of
~5–10 ms. That is the whole story of §10.9's "inside budget" reading, and it was
never a statement about the blast being cheap.

It also reframes the hand-played 78–88 ms: the blast cannot account for it, so
**that session's IDLE frame must have been far more expensive than this one's**.
DIAG-11's gap is therefore not something the scripted path does differently
*during* the detonation — it is the steady-state cost of the board in that
situation. ⚠️ Still not named: what raises it. Now measurable directly, because
`FRAME_PROBE` reports draw calls and object count, so the next hand-played
session can be compared against these exact figures rather than argued about.

### 10.10.2 The three findings finally agree

Every measurement this session pointed at the same subsystem, from a different
side each time:

| finding | what it saw |
|---|---|
| §10.7 memory | ~530 MB of graphics is room build / placement / submission |
| §10.9 bake ablation | the bake takes the TileSet 98 → 32 987 tiles; off = half the memory, 2.3× slower |
| §10.10 frame probe | 1 379 draw calls and 25 535 objects, 14–20 ms of GPU, on a board doing nothing |

**32 opaque + 16 glass `TileMapLayer`s over 145 448 placed cells** is the cost —
in memory, in draw calls, and in GPU time. The detonation was never the problem;
it is the thing that happens to run on top of a board that already consumes most
of the frame.

⚠️ **And this is where the session stops, deliberately.** The fix is an
architecture decision (fewer layers, or fewer live cells per layer) and it
belongs to the Director and to `PERFORMANCE_MASTER_PLAN`. Three candidate lists
in this plan were written before their measurements and two were wrong; there is
no case for guessing at the fourth when the instrument to decide it now exists.

---

## 10.11 🟢 DIAG-12 — ON THE MOTO THE IDLE FRAME WAS SCRIPT, AND ONE CALL SITE WAS 27 ms OF IT

**Director, 2026-09-12:** *"desabilitando features, reduzindo efeitos e outros
elementos que possam estar consumindo memória. Um bom candidato é o sistema de
iluminação procedural em tempo real. Se chegar proximo do nosso piso de 24 fps
pode parar."*

Moto g04s, release APK, bake ON, PLAYGROUND, `BENCHMARK=1 BENCH_RUNS=2
RNG_SEED=1234`. Every row in a table below ran the SAME binary unless marked.

### 10.11.1 Seven things were wrong before any number could be trusted

| defect | how it showed | fix |
|---|---|---|
| `device_run.py` force-stopped the game when the `adb logcat` child exited on its own (code 255) | a 250 s run ended **55 s in, mid map-load**, reporting "no fatal error"; `dumpsys activity exit-info` said **FORCE STOP** from the script | reattach + dedupe; the capture now ends when the game exits by itself (benchmark runs self-terminate) |
| `export_android.py --renderer` never changed the renderer | the "Compatibility" APK's `assets/project.binary` said `mobile` | override `project.godot` for the export only, restore in `finally`, assert the packed binary — the old APK is now REJECTED |
| `HIDE_VOXELS` was inert | applied before `layer.visible = true` in the same function | moved after it |
| vsync cannot be disabled on this handset | `The requested V-Sync mode Disabled is not available. Falling back to V-Sync mode Enabled.` | none possible under Vulkan — **ms/frame is always 90 Hz-quantised here; `render gpu` is the independent column** |
| `Performance.TIME_PROCESS` is a held maximum, not a mean | read **246 ms inside a window whose frame mean was 92 ms** | report it as such; attribute with `FrameSplit` clocks |
| the APK on the Moto predated the benchmark | the first baseline ran zero detonations | reinstalled |
| `NO_LIGHT` is degenerate on this build | LIGHT beat 2.6 s → **17.4 s**, first frame 2.9 s | none — it predates D-7's cooked light. **Not a valid ablation; do not quote it** |

### 10.11.2 The ablation table — the GPU was not what paced the frame

| config | idle ms/frame | render cpu | render gpu | objects | det 1 mean | det 2 mean |
|---|---|---|---|---|---|---|
| control | 40.3 | 6.0 | 19.0 | 25 535 | 60.8 | 63.0 |
| `NO_FACE_SHADER=1` | 40.3 | 5.7 | 14.4 | 25 535 | 54.5 | 63.3 |
| `STRETCH_VIEWPORT=1` ⚠️ older binary | 40.2 | 6.0 | 24.1 | 25 535 | 52.7 | 63.3 |
| `HIDE_VOXELS=1` | 34.8 | 1.9 | 10.5 | 12 811 | 50.7 | 51.0 |
| **`HIDE_NON_VOXEL=1`** | **15.1** | 4.1 | 12.0 | 12 729 | **21.0** | **29.5** |

Three GPU-side ablations moved `render gpu` by up to 5 ms and the frame by
**nothing**; rendering 3.5× fewer pixels moved nothing (fill is not the bound).
Removing the voxel board entirely bought 5.5 ms. Removing everything OUTSIDE it
bought 25 ms. **The frame was paced by the main thread.**

### 10.11.3 `FrameSplit` named it in one run

```
[FRAME-SPLIT] per frame: guard cone smooth draw 26.87 ms (9/f) · sprite light+throw 0.45 ms (10/f) · room temporal lights 0.06 ms (1/f) · room vision fog 0.05 ms (1/f) · guard attention 0.03 ms (9/f) · room enemy visibility 0.02 ms (1/f)
```

`GuardEnemy._process()` queued a redraw of itself and both cone nodes **every
frame**, and `_draw_vision_smooth()` casts 33 rays through `can_see_cell()` —
**~3 ms per guard on a T606, nine guards, for cones that had not moved.**
`VisionSmooth` is always visible, so hiding dev vision never stopped it.

### 10.11.4 The fix, measured

The cone redraws only when what it draws changed: `vision_angle` beyond
`CONE_REDRAW_ANGLE_EPS`, `facing_angle_deg`, `cell`, `state`, or the LOS
revision/sizes. `CONE_REDRAW_ALWAYS=1` restores the old path in the same binary.

| | `CONE_REDRAW_ALWAYS=1` | on change |
|---|---|---|
| guard cone draw | 26.8–27.8 ms/frame | 0 once settled |
| idle ms/frame | 40.4 | **20.1** |
| detonation 1 mean / worst | 52.8 / 279.9 ms | **26.9 / 260.6 ms** |
| detonation 2 mean / worst | 62.1 / 1 684.5 ms | **34.4 / 1 692.6 ms** |
| same, `FRAME_PROBE=0` | — | **27.7 / 34.4 ms** |
| **committed binary** (EPS 1e-5), probe / no probe | — | **27.4 / 34.3 · 27.3 / 34.1 ms**, idle 21.0 |

The rows above the last were measured at `EPS = 1e-3`; the committed binary
reproduces them. In it the cone settles within two probe windows:
`guard cone smooth draw 28.10 ms (9/f)` → `1.96 ms (1/f)` → absent.

Against §0.5: **36 and 29 fps** — above the 24–25 fps floor on both runs, the
second just under the 30 fps target. The probe's GPU sync costs nothing
measurable (26.9 vs 27.7, 34.4 vs 34.4).

**Look.** A desktop same-map capture, OLD vs NEW, two runs of each. At
`EPS = 1e-3` the new path differed from the old beyond the old path's own
run-to-run spread (rim pixels up to 123 levels on ~2 000 px against ~450), so EPS
went to **1e-5**. At 1e-5 the OLD×NEW pairs (42 833 and 27 843 px, delta>1 on
10 557 and 2 192) sit inside the spread of the same-code pairs (31 186 and
41 258 px, delta>1 on 2 727 and 8 606). ⚠️ **That is "no difference detectable",
not "pixel-identical"** — the harness is not deterministic in the cones (the
capture lands at different points of the angle's convergence), so a 0-px gate
was never earned. Every differing pixel in every pair lies inside a vision cone.

### 10.11.5 With the script bound gone, the face shader now shows

Same fixed binary:

| | control | `NO_FACE_SHADER=1` |
|---|---|---|
| idle ms/frame · render gpu | 20.1 · 19.0 | **16.8 · 12.8** |
| detonation 1 / 2 mean | 26.9 / 34.4 | **22.9 / 30.3** |

`voxel_face_shading.gdshader` — per-face tone, soot plane, P3 light bucket,
residue quantisation — costs **~4 ms of every frame** on the Mali-G57. It is the
largest remaining single lever measured, and removing it changes the picture, so
it is a Director decision (a mobile shader tier), not an engineering one.

⚠️ **Superseded by §10.12.** The no-op shader also removes the P3 LIGHT and the
per-face SOOT, so this row priced the lighting system, not a look tier. Priced
stage by stage, most of the cost is the light and soot path, and the lever is
engineering after all.

### 10.11.6 ⚠️ What this does NOT fix — read before quoting 29 fps as done

- **The single-frame freezes are untouched.** COMMIT 257–312 ms and the first
  SOOT FADE frame **1.7 s on the second detonation** (235 ms on the first) are
  the same with and without the fix. They are playback frames under §0.5.
- **The cone cost returns whenever guards turn.** The fix removes the IDLE cost,
  not the per-redraw one — nine guards rotating in the enemy phase is ~27 ms
  again. `_draw_vision_smooth()` is O(rays × range²) LOS walks.
- **Hand play is still not measured** (DIAG-11), and the Galaxy was not re-run.
- **§10.10's "the idle board is GPU" was a Galaxy reading.** On the Moto the
  binding constraint was script; once removed, the Moto frame sits near render
  gpu 19 + render cpu 6, which is §10.10's picture again. Both are true, on
  different sides of one fix.
- Memory is unchanged: 2.1–2.2 GB PSS, ~0.6–1.0 GB swap.

### 10.11.7 The remaining ~7 ms of non-voxel GPU is NOT in the obvious nodes

On the fixed binary, `HIDE_NON_VOXEL=1` still takes render gpu 19.0 → 12.0 and
objects 25 535 → 12 729. Bisected by name (`HIDE_NODES`), same binary:

| hidden | idle ms · render gpu | objects | detonation 1 / 2 mean |
|---|---|---|---|
| nothing (§10.11.4 last row) | 21.0 · 19.0 | 25 535 | 27.4 / 34.3 |
| `VisionSmooth` (9 cones) | 20.2 · 18.9 | 25 533 | 27.4 / 34.1 |
| `HUD` | 19.6 · 18.4 | 25 090 | 26.6 / 33.2 |
| `Enemies` | 20.0 · 18.8 | 25 527 | 38.1 ⚠️ / 34.7 |
| `Agent` | 20.1 · 18.9 | 25 530 | 27.4 / 34.1 |

**None of them is it** — the HUD is worth ~0.5 ms and nothing else registers
(the 38.1 ms run is one outlier against a 34.7 ms second run on the same flags,
not a finding). What `HIDE_NON_VOXEL` also hides and this table does not:
`FloorLayer` (1 104 256×128 tiles under the whole board), `ShadowFullLayer`,
`ShadowPartialLayer`, `StructureLayer`, and the code-built `@Node2D@N` overlays.
⚠️ **12 800 objects cannot come from ~130 non-voxel nodes**, so one of those
holds far more drawn items than its node count says — that is the next
`NODE_CENSUS` / `HIDE_NODES` question, not a guess to act on.

---

## 10.12 🟢 DIAG-13 — THE FACE SHADER, PRICED STAGE BY STAGE: THERE IS NO CHEAP LOOK TIER

**Director, 2026-09-13:** chose the face shader (§10.11.5) as the next target on
the Moto, over hand play, the non-voxel GPU and the freezes.

**§10.11.5's framing was incomplete, and the measurement below is why.**
`NO_FACE_SHADER` swaps in `shader_type canvas_item;` and nothing else, so its
~6 ms removed the LIGHT (PERF-P3 moved the bucket multiply into this shader), the
per-face SOOT, the face tone, the residue snap, a second `TEXTURE` sample and six
debug branches, all at once. "Removing it changes the picture" was true — it
priced the lighting system, not a cheaper look.

### 10.12.1 The instrument

`FACE_SHADER_STRIP=<STAGE,...>`, stages `DEBUG`, `TEXA`, `RESIDUE`, `FACE`,
`SOOT`, `LIGHT`. They are `#ifndef FACE_STRIP_*` guards in the SHIPPED shader;
`VoxelRenderer._face_shader_with_strips()` injects the `#define`s after its
`shader_type` line, so no flag compiles the exact file and a flag strips that
file, not a copy. `PLANE` is derived (LIGHT + SOOT + DEBUG all gone) and removes
the cell recovery and the plane fetch. An unknown stage is a `push_error` and
leaves the shader whole. It reaches the APK through `DevFlags`: every device log
below prints its own strip line, and the 8 logs contain 0 shader errors.

### 10.12.2 The cost — Moto g04s, one APK, stages removed cumulatively

Release APK, bake ON, PLAYGROUND, `BENCHMARK=1 BENCH_RUNS=2
BENCH_SETTLE_FRAMES=240 RNG_SEED=1234 FRAME_PROBE=1 NO_VSYNC=1 EVENT_FRAMES=1`.
Idle = median of the 8 settled probe windows after the two runs; within every
row those 8 samples sit inside ±0.2 ms (apart from one warm-up window each in
the FACE and no-op rows).

| removed (cumulative) | idle ms · render gpu | Δ render gpu | detonation 1 / 2 mean |
|---|---|---|---|
| nothing (control) | 20.1 · **19.0** | — | 30.7 / 34.6 |
| `DEBUG` | 19.6 · 18.4 | **−0.6** | 27.8 / 34.0 |
| + `TEXA` | 19.6 · 18.5 | 0 | 27.2 / 33.5 |
| + `RESIDUE` | 18.7 · 17.3 | **−1.2** | 26.8 / 33.2 |
| + `FACE` | 18.7 · 17.2 | −0.1 | 25.6 / 32.6 |
| + `SOOT` | 17.9 · 15.3 | **−1.9** | 24.1 / 31.0 |
| + `LIGHT` (→ `PLANE`) | 16.8 · **12.7** | **−2.6** | 23.0 / 29.3 |
| `NO_FACE_SHADER` (floor) | 16.9 · 12.6 | −0.1 | 23.5 / 29.1 |

**The ladder closes:** every stage stripped (12.7) lands on the no-op (12.6), so
the six stages account for the whole shader — **6.3 ms, a third of the idle GPU
frame.** Split: light + cell recovery + plane fetch 2.6 (41%), soot decode 1.9
(30%), residue snap 1.2 (19%), debug branches 0.6 (10%), face tone 0.1, second
sample 0.

⚠️ A cumulative ladder charges an interaction to the LATER stage (SOOT's 1.9 was
measured with RESIDUE and FACE already gone). ⚠️ The control's detonation 1
(30.7 ms, worst 465) is above §10.11.4's 27.4 on the same code: event means carry
run-to-run spread that the idle `render gpu` column does not, so that column is
the one that separates stages; the detonation means move the same way but no
single step of them is significant at n = 1.

### 10.12.3 The look — desktop captures, one binary, pixel diffs

The harness was earned first: two control captures (PLAYGROUND,
`test_zone_detonate`, 400-frame wait, `--fixed-fps 60`, cones hidden) differ by
**0 px**.

| variant | differs from | result |
|---|---|---|
| `DEBUG` | control, wide frame | 32 px of 921 600, max 5 levels — isolated pixels at REPEATING atom-relative positions (pairs 16 px apart): face-classification boundary pixels re-rounded by the recompiled shader |
| `DEBUG,TEXA` | `DEBUG`, wide frame | **0 px** — exact, and it buys nothing, so it is not proposed |
| `DEBUG,TEXA` | control, close-up on the blast | **0 px** |
| + `RESIDUE` | `DEBUG,TEXA`, close-up | 70.9% of the frame, **max 3 levels** |
| + `FACE` | same | 66.5%, max 9 |
| + `RESIDUE,FACE` | same | 91.0%, max 10 |
| + `SOOT` | same | 32.3%, max 84 — the scorch is gone |
| + `LIGHT` | same | 31.0%, max 81 |

Sheets (crater crop at 2×, difference ×16), kept because the decision they serve
is still open: `Screenshots/history/diag13_face_shader_look_residue_face.png`
and `Screenshots/history/diag13_face_shader_look_soot_light.png`.
⚠️ **Substitution, stated:** the look was captured on the desktop (macOS), not on
the Mali. What a stage does to a pixel is the shader's arithmetic; the COST is
the part only the device could answer, and that is what the device measured.

### 10.12.4 What it means — the lever is engineering, not look

- **The stages that ARE the look — light and soot — are 4.5 of the 6.3 ms**, and
  neither can leave the game.
- **What can leave buys little:** debug branches 0.6 (zero look), the residue
  snap 1.2 (≤3 levels, but it is FACE-READ-03's unconditional "never three
  identical faces" guarantee, which is Director canon), the face tone 0.1.
- **The 4.5 ms is paid per FRAGMENT for data that is constant per QUAD.** The
  shader's own header says all three faces of a voxel resolve to one cell; the
  cell recovery, the plane fetch, the bucket lookup and the base-5 soot decode
  run again on every fragment of that quad. Doing them once per quad and passing
  flat varyings would keep the picture and remove most of the cost. **Upper bound
  4.5 ms, unmeasured.** ⚠️ The cell recovery took PERFORMANCE §12.8–§12.9 to make
  exact, and what fixed it — the per-fragment corner test on `v_corner` — is
  exactly what a vertex stage cannot see. That makes it a spike with a gate,
  not an edit.

### 10.12.5 Open for the Director

1. **Compile the debug modes out of the shipping shader** (−0.6 ms, zero look)?
   The gates that set `cell_debug_paint` would then have to request the define —
   it touches the PERF-P3 / §12.8 gate path, which is why it was not done here.
2. **The residue snap** (−1.2 ms): keep FACE-READ-03's guarantee, or trade it?
3. **Spike the per-quad plane path** (up to −4.5 ms, zero look intended)?

---

## 10.13 🟡 DIAG-14 — THE PER-QUAD SPIKE: EXACT, AND WORTH NOTHING UNTIL THE DEBUG BRANCHES LEAVE

**Director, 2026-09-14:** *"Faz o spike do cálculo por voxel"* — §10.12.5 item 3.

### 10.13.1 What was built

`FACE_PLANE_PER_QUAD=1`, default absent, riding the same `#define` injection as
`FACE_SHADER_STRIP` (the two combine). The VERTEX stage recovers the quad's cell,
fetches the plane and decodes the light and the three soot multipliers; the
fragment receives them as flat varyings.

The corner problem, solved without assuming a provoking vertex: a vertex can
decide Y by lattice membership (a bottom corner inverts to +2.25, never a whole
cell) but not X, because (32, 0) is `e1 − e2`. So it reads BOTH candidates —
A, the cell it would be as a left corner, and B = A + (−1, +1) — and the fragment
picks with §12.9's own `v_vertex.x − v_corner.x < 0` test. Debug modes 1–3 read
the cell the per-quad path chose, so the cell gate audits the path under test.

### 10.13.2 It is exact — and both gates were shown to fail

Desktop, same binary, harness earned (control vs control 0 px):

| check | Metal (Forward Mobile) | Compatibility (GL) |
|---|---|---|
| blast close-up, per-fragment vs per-quad | **0 px** | **0 px** |
| wide frame | **0 px** | — |
| cell gate, floor view | 100.000%, both paths | 100.000%, both paths |
| cell gate at the metal wall — L79–L94, 16 levels, 921 600 px | **100.000%**, both paths | **100.000%**, both paths |
| gate plain frame and recovered-cell map, per-fragment vs per-quad | 0 px | 0 px |

Metal control against Compatibility control differs by 131 582 px, so the second
renderer genuinely rasterises another way — the other provoking-vertex convention
is covered, not assumed.

**Teeth.** The two candidates were swapped on purpose: the cell gate went to
**FAIL, 0.271% inside** (689 770 px outside), the close-up differed by 413 004 px
(max 126) and the plain frame by 370 758 px. The shader was restored byte-identical
(`cmp`) and the selftests re-run on the restored file: 53 clean.

### 10.13.3 On the Moto it buys nothing — as the shader stands

ABAB, one APK:

| run | render gpu (8 windows) | detonation 1 / 2 mean |
|---|---|---|
| control | 18.9 | 26.9 / 34.1 |
| per-quad | 19.1 | 27.2 / 34.5 |
| control | 19.0 | 29.2 / 34.3 |
| per-quad | 19.1 | 28.0 / 34.7 |

Draw calls, primitives and objects are identical in all four (1 370 / 41 082 /
25 535), so it is shader work, not batching.

### 10.13.4 The decomposition — the debug branches eat it

Same APK, idle render gpu:

| stripped | per-fragment | per-quad | Δ |
|---|---|---|---|
| nothing | 19.0 | 19.1 | +0.1 |
| `DEBUG` | 18.4 | **16.9** | **−1.5** |
| `DEBUG,TEXA,RESIDUE,FACE` (soot alive) | 17.2 | 15.9 | −1.3 |
| `DEBUG,TEXA,RESIDUE,SOOT` (face tone alive) | 16.1 | 14.1 | −2.0 |
| `DEBUG,TEXA,RESIDUE,FACE,SOOT` | 15.3 (repeated: 15.3) | 14.0 | −1.3 |

- **Per-quad saves 1.3–2.0 ms in every configuration without the debug branches,
  and nothing with them.** Those branches cost 0.6 ms on the per-fragment path and
  **2.2 ms** on the per-quad path.
- **Per-quad with the debug modes compiled out: 19.0 → 16.9 ms, −2.1 ms, picture
  unchanged** — blast close-up 0 px; wide frame 32 px (max 5), which are exactly the
  pixels DIAG-13's `DEBUG` strip already moved (that capture against this one: 0 px).
- ⚠️ **§10.12's stage names over-claim.** Its "SOOT" step also killed the face
  classification, which is 0.8 of its 1.9 ms (face tone kept: 16.1 against 15.3);
  its "LIGHT" step also killed the `v_vertex`/`v_corner` varyings, and per-quad
  recovers only 1.3 of its 2.6 ms (14.0 against 12.7).
- ⚠️ The per-quad soot SELECT costs more than the per-fragment decode it replaced
  (15.9 − 14.1 = 1.8 against 17.2 − 16.1 = 1.1). Suspected: the six extra varying
  floats it keeps alive. Not measured further.

### 10.13.5 A hypothesis tested and killed: hoisted debug fetches

An implicit-LOD `texture()` inside a branch needs derivatives, so a compiler may
sample it on every fragment. Both debug-branch fetches were changed to
`textureLod(…, 0.0)` — the same value for `cell_soot`, which has no mipmaps and
filters nearest. Desktop gates unchanged (100%, 0 px). On the Moto, ABAB: control
18.9 / 19.0, per-quad 18.9 / 18.9. **No change, so that is not the mechanism, or
not the only one; the edit was reverted.** Why six untaken branches cost 0.6–2.2 ms
on this GPU is unexplained.

### 10.13.6 Open for the Director

Per-quad pays only together with §10.12.5 item 1, so the candidate is ONE change:
**compile the debug modes out of the shipping shader and take the per-quad path**
— idle render gpu 19.0 → 16.9 ms, detonation 1 at 25.6 ms in the one run measured,
picture unchanged. Its cost: the P3 cell gate and the §12.8 instruments would
request a debug build of the shader explicitly (the injection this track already
uses) instead of finding the modes compiled in. Both halves are still flags today.

Logs (local only): `docs/measurements/device_2026-09-13_moto_g04s_diag13_{d0–d3,
x5–x7, y1–y3, e0–e3}_*.log` — named for the session's start, run on 2026-09-14.

---

## 10.14 🟢 DIAG-14 SHIPPED — the per-quad plane path is ON and the debug paint is compiled out

**Director, 2026-09-14:** *"Liga as duas: debug fora e cálculo por voxel"* —
§10.13.6, as one change.

### 10.14.1 What changed

- **The shader's default build** takes the per-quad plane path, and the six debug
  paint branches exist only under `FACE_DEBUG_PAINT`.
- **`VoxelRenderer._face_shader_variant(debug_paint)`** is the one place that
  decides which build a voxel layer draws. With no flag set and no paint mode it
  returns the shader FILE itself — no injection, no copy.
- **`debug_set_cell_paint_mode(mode)`** swaps every layer onto the
  `FACE_DEBUG_PAINT` build for any mode above 0, and back for 0. It is the only
  writer of `cell_debug_paint` in the repo (the P3 cell gate and the
  `CELL_PAINT_MODE` capture both call it), so no instrument lost its branches.
- **Instruments:** `FACE_PLANE_PER_QUAD=0` is the per-fragment path, for
  comparison only (the `GLASS_TILE` convention). `FACE_SHADER_STRIP` no longer has
  a `DEBUG` stage — a flags file that still names it now errors loudly and strips
  nothing. `NO_FACE_SHADER` is unchanged.

### 10.14.2 The gates — desktop, this exact code

| check | result |
|---|---|
| new default vs the gated per-quad build (debug compiled in), blast close-up | **0 px** |
| new default vs per-quad with the `DEBUG` strip, close-up / wide frame | **0 px** / **0 px** |
| new default vs the previous default, wide frame | 32 px, max 5 — the pixels DIAG-13's `DEBUG` strip already moved |
| `FACE_PLANE_PER_QUAD=0` vs the previous default, close-up | **0 px** |
| Compatibility renderer, new default vs the gated per-quad build | **0 px** |
| cell gate at the metal wall, 16 levels, 921 600 px judged — default / `=0` / Compatibility | **100.000%** · **100.000%** · **100.000%** |
| cell gate, floor view, 827 924 px judged | **100.000%** |
| gate plain frame and recovered-cell map vs the gated per-quad build | **0 px** |

Each gate log prints `face shader variant — FACE_DEBUG_PAINT` when painting
starts, so the swap happened; and the plane, the ladder and `layer_origin`
survived it, because the gate paints the plane THROUGH those parameters and every
judged pixel still lands inside its own quad. Lint clean, invariants OK, CODEMAP
regenerated, **53 selftests clean**. The APK was exported and installed, and its
packed shader is byte-identical to the repo's.

### 10.14.3 ✅ MEASURED ON THE MOTO — 19.0 → 16.9 ms, as predicted

The ABAB of this exact APK, 2026-09-14 13:33–13:41, after a hand unlock (the first
attempt found the handset locked; a three-hour wait expired and it was detached
by 04:11). The APK on the handset has the same SHA-256 as `export/Infiltraitor.apk`,
exported from this commit's code.

| run | render gpu (8 windows) | idle ms/frame | detonation 1 / 2 mean |
|---|---|---|---|
| default — per-quad, no debug | **16.9** | 18.7 | 28.9 / 32.9 |
| `FACE_PLANE_PER_QUAD=0` | 18.4 | 19.6 | 27.2 / 33.8 |
| default | **16.9** | 18.6 | 26.3 / 32.4 |
| `FACE_PLANE_PER_QUAD=0` | 18.4 | 19.6 | 27.0 / 33.7 |

- **Both predictions land exactly:** §10.13.4's 16.9 (per-quad) and 18.4
  (per-fragment with the debug branches out).
- **Against the previous default** (render gpu 19.0, idle 20.1–20.2 ms, §10.13.3):
  **−2.1 ms of render gpu, and the idle frame −1.5 ms.**
- **Detonation 2: 34.1–34.3 → 32.4–32.9 ms.** Detonation 1 spreads 26.3–28.9 here
  and 26.8–29.2 across §10.13's controls, so no change is claimed for it.
- Draw calls 1 370 in all four runs; 0 shader errors; the `=0` runs log
  `FACE_PLANE_PER_FRAGMENT` and the default runs log no variant — they draw the
  shader file itself. The handset's `dev_flags.cfg` is reset.

---

## 10.15 🔴 DIAG-15 — HAND PLAY ON THE SHIPPED BUILD: FINE UNTIL THE GRENADE COMES OUT, THEN DRAW CALLS GO ×6.6

**Director, 2026-09-14:** *"Agora mede o jogo manual no Moto"*.

Moto g04s, the shipped APK (§10.14), PLAYGROUND, `EVENT_FRAMES=1 FRAME_PROBE=1
MAP=PLAYGROUND NO_VSYNC=0` — 2026-09-12's hand-session flags plus the frame
probe. The Director played by hand: three grenade detonations and one end of
turn. Log (local): `docs/measurements/device_2026-09-14_moto_g04s_diag15_hand.log`.

### 10.15.1 The idle board by hand IS the benchmark's idle board

13:49:20–13:50:30, nothing happening: **1 370 draw calls · 25 535 objects ·
render gpu 16.8–17.0 ms · 18.6 ms/frame** — against the benchmark's 16.9 / 18.7
on the same APK. §10.10.1's inference that hand play's IDLE frame "must have been
far more expensive" is false for an untouched board; the gap opens later.

### 10.15.2 The moment the grenade comes out

| time | what the log says | draw calls | objects | render cpu · gpu | ms/frame |
|---|---|---|---|---|---|
| 13:50:30 | idle | 1 370 | 25 535 | 6.0 · 16.9 | 18.6 |
| 13:50:34 | the throw — `[AgentSprite] throw 'standing_raise'` and `[BombRegistry] Registered: frag_grenade` within the next second | **9 070** | **50 505** | **19.9 · 85.9** | 65.0 |
| 13:52:06–16 | between detonations 2 and 3, nothing exploding | 9 466 | 50 378 | 20.8 · 87.0 | **88** |
| 13:53:04 | after the last detonation, guards acting (cone redraw logged) | 12 424 | 54 756 | 22.9 · 91.8 | 79.8 |
| 13:53:08–12 | after the guards' turn | 4 902 | 45 449 | 13.3–32.9 · 60.5–63.8 | 62–67 |

- **About +7 700 draw calls and +25 000 objects appear at the throw** — the objects
  roughly double, by almost exactly the voxel board's own count — and **render gpu
  goes 17 → 86 ms, render cpu 6 → 20 ms.**
- **It is rendering, not script:** `FRAME-SPLIT` is the same on both sides of the
  jump (sprite light 0.46 ms, no cone redraw).
- Draw calls creep up per detonation (9 070 → 9 282 → 9 468 → 9 800), fall to
  4 902 after the guards' turn, and never return to 1 370 in this session.
- ⚠️ **The log records no input**, so whether the throw-targeting UI stayed open
  between throws is not known — "a state that persists" and "open while aiming"
  cannot be told apart from this run.

### 10.15.3 The detonations

| detonation | mean | worst frame (COMMIT) | SOOT FADE, first frame |
|---|---|---|---|
| 1 (cold) | 124.9 ms | 3 939 ms | 3 561 ms |
| 2 | 95.9 ms | 534 ms | 378 ms |
| 3 | 120.5 ms | 3 489 ms | 3 386 ms |

2026-09-12's hand session on this handset: 137.7 / 130.2 / 101.9 ms. Over the same
span the benchmark went 52.8 → 26.9 ms; **hand play moved ~10%**, because every
hand-played frame sits on §10.15.2's ~88 ms board and the blast is 10–35 ms on
top of it — §10.10.1's shape, with the expensive part now located. ⚠️ The third
detonation's COMMIT (3.5 s) is as slow as the cold first, unlike 2026-09-12's
third (486 ms); unexplained.

Memory: PSS 2.21 GB idle → 2.26–2.36 GB after the throw; GL mtrack 742 → 747–824 MB;
swap about 1.0 GB throughout.

### 10.15.4 What this locates, and what it does not name

**DIAG-11's gap is LOCATED:** not the idle board, not the blast, not script — a
render state that switches on with the grenade throw and adds ~7 700 draw calls
and ~25 000 objects. It is also why the benchmark never saw it: the benchmark
calls `detonate_active()` and never enters the throw flow (§10.9.2's first
candidate). **It is NOT named** — which node draws those items is the next
question. `FRAME_PROBE`'s counters read the same on the desktop, and
`NODE_CENSUS` / `HIDE_NODES` exist, but both are applied at map load and would
have to run at the moment of the throw.

> ⚠️ **SUPERSEDED THE SAME DAY by §10.16.** The ~7 700 extra draw calls most
> likely came with the Director's "D" framing and zoom, not with the throw, and
> "the counters read the same on the desktop" holds only at the same canvas and
> zoom — the desktop boots in D, the phone in the portrait band. The table above
> stands as measured; its attribution to the grenade does not.

---

## 10.16 🟡 DIAG-16 — THE ×6.6 WAS PROBABLY THE VIEW, NOT THE GRENADE

**Director, 2026-09-14:** *"O problema do teste manual é que eu faço mais coisas,
tipo mudar a orientação pra preencher toda a tela, centralizar a cena, escolher a
GU, clicar de novo, etc."* — and, on what the phone shows: *"Quando o jogo inicia,
ele começa em 'paisagem' porém com janela vertical [...] Quando eu abro, clico em
'D' pra que ele fique realmente paisagem (desktop), e preencha toda a tela.
Consigo aumentar ou diminuir o zoom, reposicionar, etc."*

### 10.16.1 What the phone actually shows — two framings, and the benchmark ran in one

- **The APK is landscape-locked.** `aapt dump xmltree export/Infiltraitor.apk
  AndroidManifest.xml` → `android:screenOrientation=0x0` (landscape).
  `project.godot` sets no `display/window/handheld/orientation`, so Godot's
  default (landscape) is what ships. The canon says portrait.
- **A touch boot draws a portrait band.** `_apply_boot_viewport()` sets
  `content_scale_size = 390×844` on any touch device, so the landscape screen
  shows a vertical strip between two black bars — the Director's description.
- **"D" fills the screen.** `_apply_viewport_mode()` sets the canvas to
  **1280×720**: ~2.8× the world area of the 390×844 band at the same zoom
  (921 600 vs 329 160 canvas px).
- **The benchmark ran in the band, at the scene's default zoom 0.5**
  (`room.tscn`). Hand play ran in D, with pinch and pan.

### 10.16.2 The counts follow the view — measured on the desktop

macOS desktop, windowed, PLAYGROUND, `FRAME_PROBE=1`, board untouched, 75 s per
boot, **613 nodes in all three**. The desktop boots in D (1280×720). `render gpu`
reads 0.0 on this machine, so only the counts and `render cpu` are read here.
Log (local): `docs/measurements/desktop_2026-09-14_diag16_zoom.log`.

| boot | draw calls | primitives | objects | render cpu |
|---|---|---|---|---|
| control (zoom 0.5 from the scene) | 4 209 | 81 372 | 45 613 | 3.7 ms |
| `ZOOM=0.5` | 4 200 | 80 774 | 45 366 | 3.7 ms |
| **`ZOOM=0.2`** (the pinch minimum, `ZOOM_MIN`) | **49 688** | **323 942** | **166 188** | **15.3 ms** |

Control and `ZOOM=0.5` agree within 0.6%, so the counter is reproducible. At the
pinch minimum, with nothing on the board changed, the same scene submits
**11.8× the draw calls and 3.6× the objects**, and `render cpu` quadruples on a
far faster CPU than the Moto's.

### 10.16.3 DIAG-15's log, re-read with that

- **The node count does not move across the jump** — 606 before, 606 after.
  Nothing was created; the same nodes drew more.
- **The jump precedes the throw.** The probe window ending 13:50:34.349 already
  reads 9 070 draws; the first throw line (`[AgentSprite] throw 'standing_raise'`)
  is at 13:50:35.092. That window also carries `physics 19.5 ms` (a held maximum,
  0.1 everywhere else) — a one-off event, consistent with a canvas change.
- **The enemy phase moved the count down.** 9 800 → 4 902 draws / 45 449 objects
  while `_focus_camera_for_enemy_phase()` tweened the camera to each guard (its
  zoom cap, 2.0, is above `ZOOM_MAX` 1.2, so it only pans). Desktop D at zoom 0.5
  reads 4 209 / 45 613.

### 10.16.4 What changes, and what is still open

- **§10.15.4's attribution is withdrawn:** the evidence no longer points at the
  throw. It is not refuted on the phone either — see below.
- **DIAG-11's benchmark-vs-hand gap (§10.9.2) has a leading explanation that is
  not the throw flow: framing.** The benchmark measured the band at zoom 0.5; the
  hand measured D plus whatever zoom the hand chose. Until re-run with the
  framing recorded, §10.9.2's table compares two framings, not two paths.
- **The board's cost scales with the board area on screen.** A budget verdict
  must name its framing and zoom (§13 Q5–Q7).
- **NOT closed on the Moto.** It needs a run with no grenade: band idle → D idle
  → pinch out → pan, with the framing in the log (§14 TEL-02/TEL-03). The
  ~4 800 draws between desktop D at zoom 0.5 (4 209) and the hand's 9 070 are
  unattributed: zoom, pan, aim overlays and glass shards are all candidates.

---

## 10.17 🔴 DIAG-17 — THE ZOOM LADDER ON THE MOTO: FILLING THE SCREEN COSTS MORE THAN ZOOMING OUT

**Director, 2026-09-14:** *"Vamos estabelecer alguns pontos de zoom e verificar o
quanto isso pesa, e até onde dá pra chegar."* (§13 Q6)

Moto g04s, the TEL build (commits `85da2f45` + `b3808ba7`; APK manifest
`screenOrientation=0x1`), PLAYGROUND, board untouched, no finger. The run was
driven entirely by `SCENARIO=` (TEL-06a) and analysed by `bench_analyze.py`
(TEL-07a).
- Logs (local): `docs/measurements/device_2026-09-14_moto_g04s_tel_zoom_ladder.log`
  and `docs/measurements/tel_2026-09-14_moto_ladder/tel_2026-09-14_15-39-11.jsonl`.
- Each row is the median of the windows that started after the segment's mark;
  the one window per segment that straddled the change is excluded.
- ⚠️ Vsync cannot be disabled on this handset (90 Hz FIFO, §10.11.1), so
  ms/frame is refresh-quantised. Read `render gpu` / `render cpu` for cost.

### 10.17.1 TEL-00 is answered — the file sink works on a release APK

- The release APK wrote
  `/sdcard/Android/data/com.example.infiltraitor/files/telemetry/tel_2026-09-14_15-39-11.jsonl`,
  and `adb pull` read it with no debuggable build.
- The file and the logcat capture each hold **105 records, 0 dropped lines**, and
  analyse to the same table (one float rounds differently in its last digit).
- The session header read: Android 14, Mali-G57, Vulkan 1.3.225, renderer
  `mobile`, screen 720×1612 at 90 Hz.

### 10.17.2 The table

| framing | zoom | cells on screen | draws | objects | render cpu | render gpu | ms/frame |
|---|---|---|---|---|---|---|---|
| portrait M 390×873 | 0.50 | 95 | 1 641 | 25 989 | 6.5 | **58.6** | 60.0 |
| portrait M | 0.42 | 115 | 3 091 | 30 726 | 9.1 | 69.0 | 70.3 |
| portrait M | 0.35 | 173 | 5 603 | 43 944 | 14.0 | 87.7 | 89.1 |
| portrait M | 0.30 | 235 | 10 531 | 55 231 | 22.7 | 106.2 | 107.6 |
| portrait M | 0.25 | 303 | 15 738 | 71 032 | 31.5 | 123.4 | 125.2 |
| portrait M | 0.20 | 354 | 20 670 | 80 397 | 39.4 | 132.9 | 135.1 |
| desktop D 1280×720 | 0.50 | 230 | 4 200 | 45 366 | 12.1 | 60.7 | 61.9 |
| desktop D | 0.35 | 450 | 12 686 | 77 138 | 27.5 | 101.7 | 102.8 |
| desktop D | 0.20 | 909 | 49 688 | 166 188 | 89.8 | 207.4 | 222.8 |

Every count matches the desktop's for the same framing and zoom (§10.16.2,
TEL-07a's cross-check), so the counts depend on the view, not the device.

### 10.17.3 What it says — two costs, and the first one is new

- **Filling the screen is the bigger cost.** The benchmark read 18.7 ms/frame
  and 16.9 ms of GPU at 1 370 draws (§10.14.3), but it ran in the old portrait
  band, ~333×720 px ≈ 240 000 pixels on the landscape screen (§10.16.1).
  Portrait M now covers 720×1612 = 1 160 640 pixels, **4.8× more**. The draws
  barely moved (1 370 → 1 641) while the GPU went **16.9 → 58.6 ms**.
  ⚠️ That is the reading, not yet the proof — §10.17.4 is the ablation that
  separates pixels from board.
- **Zooming out costs submission and primitives, at fixed pixels.** From zoom
  0.5 to 0.2 in portrait:
  - cells on screen 95 → 354 (×3.7), draws 1 641 → 20 670 (×12.6)
  - render cpu 6.5 → 39.4 ms, render gpu 58.6 → 132.9 ms
  - The pixel count never changed along the ladder, so the GPU growth there is
    per primitive (vertex work and tile binning), not per pixel.
- **No zoom stop is inside the 33.3 ms budget, idle, in the verdict framing.**
  §13 Q6's floor cannot be chosen from this table until the fill cost is
  understood, because it sits under every row.

### 10.17.4 The ablation — the fill is proven, and at the default zoom it is the largest single cost

Same APK and scenario shape, at three of the ladder's stops, with
`STRETCH_VIEWPORT=1`: the 2D renders at the canvas size and is upscaled. That is
390×873 = 340 470 pixels instead of 1 160 640 (3.4× fewer), with the same board
and framing. Log (local):
`docs/measurements/device_2026-09-14_moto_g04s_diag17_stretch_ablation.log` —
63 records, 0 dropped; `[PERF-DEV] STRETCH_VIEWPORT — 2D renders at (390, 844),
upscaled to (720, 1612)`.

| zoom | draws · objects · cells | render cpu, full · stretch | render gpu, full | render gpu, stretch | **GPU the pixels cost** | ms/frame, full → stretch |
|---|---|---|---|---|---|---|
| 0.50 | 1 641 · 25 989 · 95 | 6.5 · 6.4 | 58.6 | 22.3 | **36.3** | 60.0 → **23.8** |
| 0.35 | 5 603 · 43 944 · 173 | 14.0 · 14.0 | 87.7 | 41.0 | **46.7** | 89.1 → 42.6 |
| 0.20 | 20 670 · 80 397 · 354 | 39.4 · 39.4 | 132.9 | 86.9 | **46.0** | 135.1 → 88.4 |

- **The ablation changed only the pixels.** At every stop the counts and
  `render cpu` are identical to the ladder's.
- **At the default zoom, 36 of the 58.6 ms of GPU is pixel fill (62%).**
  Rendering at the canvas resolution puts idle portrait M at **23.8 ms/frame,
  inside the 33.3 ms budget.**
- **What follows the zoom is not fill.** With the fill removed, GPU still goes
  22.3 → 86.9 ms and `render cpu` 6.4 → 39.4 ms from zoom 0.5 to 0.2. That is
  §10.17.3's per-primitive cost, now isolated from the pixels.
- **§10.11.2 does not carry over.** Its "fill is not the bound"
  (`STRETCH_VIEWPORT` moved nothing) was measured in the ~240 000-pixel band, on
  a frame that script then paced. In a filled portrait screen, fill is the
  biggest single cost.

### 10.17.5 The villains, named — and what each lever costs the game

| villain | measured | lever | what the lever costs |
|---|---|---|---|
| **pixel fill** — 720×1612 shaded through the stacked `TileMapLayer`s and the face shader | 36–47 ms of GPU at every zoom | render M below native resolution; `STRETCH_VIEWPORT` is the 3.4× extreme | sharpness — **a look decision** (§13 Q9) |
| **board on screen** — per primitive: submission and tile binning | +64 ms GPU and +33 ms cpu from zoom 0.5 to 0.2, with the fill removed | an M zoom floor (§13 Q6); fewer layers or fewer live cells (`PERFORMANCE_MASTER_PLAN`) | how far out the player sees; or engineering |
| **the blast** | ~10–35 ms on top of whatever frame it lands on (§10.14.3, §10.15.3) | `DETONATION_PERFORMANCE_MASTER_PLAN` | — |

**With the fill at canvas resolution,** zoom 0.5 reads 23.8 ms ✅, zoom 0.35
reads 42.6 ms (just past the 41.7 ms floor) and zoom 0.2 reads 88.4 ms. So an
idle M zoom floor that fits the budget sits between 0.5 and 0.35, before any
blast is added. ⚠️ That is interpolated between two stops, not measured. The
next measurement is a finer ladder under whichever render scale the Director
chooses.

⚠️ **`STRETCH_VIEWPORT` is an instrument, not a setting.** It upscales a 390-wide
canvas 1.85× on the Moto. Whether that, or an intermediate scale, keeps enough
sharpness has to be judged on the phone's real screen, not from this table.

---

## 11. DIAG-08 — gates and documentation

- `L4 dev-flag-behind-the-seam` invariant (see §4 — deferred until 01c).
- A `DevFlags` selftest registered with `run_selftests.py`.
- `tools/persistent/MobileTesting.md` gains the device section; it currently
  documents only the web/ngrok route.
- ⚠️ Verify the new gates do not block the ordinary daily workflow — a gate that
  obstructs routine work gets bypassed, which is worse than no gate.

---

## 12. Proposed order

```
DIAG-06  export_android.py           ✅ BUILT 2026-09-12
DIAG-00  flag-channel spike          ✅ RESOLVED 2026-09-12 (channel B′)
DIAG-02  device_run.py + preconditions  ✅ BUILT 2026-09-12
DIAG-05  emulator install            (parallel — unblocks harness work)
DIAG-01  DevFlags seam + 01b         ✅ BUILT 2026-09-12
DIAG-02b logcat parser               → superseded by TEL-07 (§14)
DIAG-03  scripted scenario on device → superseded by TEL-06 (§14)
         ── first real number here ── ✅ 2026-09-12 (§10.5)
DIAG-04  renderer control run
DIAG-07  sustained / thermal run     → instrumented by TEL-08 (§14)
DIAG-08  gates + docs                → TEL-09 carries the suite's share
```

**From 2026-09-14 the order is §14.4's.** The lines above are kept as history;
where one says "superseded", §14 is the only authority for that task.

---

## 13. Open questions for the Director

1. **§4's staged migration (01a/01b/01c) vs. one 207-site sweep.** The staged
   route is recommended; the sweep is the shape of change with the worst history
   in this project.
2. **Which handset is the reference target** for a pass/fail verdict — the
   harsher one, or both independently?
3. ~~What frame budget counts as "factível"?~~ ✅ **ANSWERED 2026-09-12 — see
   §0.5.** 30 fps target / 33.3 ms, 24–25 fps floor, playback frames only.
4. **Does the blast get a device-specific quality tier** if it fails, or does
   the detonation get optimized until it passes everywhere? This decides whether
   a failure re-opens the other two plans or opens a new one.
5. ~~**The landscape canvas: what world scale?**~~ ✅ **ANSWERED 2026-09-14 —
   (a) 844×390.** Director: *"A escala do canvas pode ser limitada, vamos com
   (a)."* The same canvas area as portrait, the view turned. Landscape is not a
   default (Q7), so (a) is the size any landscape M framing uses when one is
   asked for.
6. **The pinch floor on a phone — becomes a MEASUREMENT.** Director: *"Vamos
   estabelecer alguns pontos de zoom e verificar o quanto isso pesa, e até onde
   dá pra chegar."* `ZOOM_MIN = 0.20` took an untouched board to 11.8× the draw
   calls on the desktop (§10.16.2). The Moto measures a ladder of zoom stops in
   the portrait M framing; the M floor is then chosen from that table. It is not
   picked before the table exists.
7. ~~**Which framing does a pass/fail verdict require?**~~ ✅ **ANSWERED
   2026-09-14 — portrait.** Director: *"A princípio não vamos ter a versão
   horizontal por default, então vamos fazer os testes verticalmente. Mas
   precisamos preencher toda a tela de verdade."* So the verdict framing is
   portrait M, and it must FILL the screen — no black bars at any aspect ratio.
8. ✅ **RULED 2026-09-14 — M carries the restrictions, D does not.** Director:
   *"Mantemos a qualidade FULL HD no modo Desktop, mas no modo M usamos as
   restrições."* ⚠️ Assumption, stated: D keeps today's 1280×720 canvas, which
   `canvas_items` stretch already renders at the screen's native resolution —
   full HD on a full HD screen. M's restrictions are the (a) canvas scale and the
   zoom floor Q6 will set.
9. **The render scale of M — a look decision the measurements now force.**
   (§10.17.4–§10.17.5) On the Moto at the default zoom, 36 of the 58.6 ms of GPU
   is pixel fill. Rendering the 2D at the canvas size (390×873, upscaled 1.85×)
   takes the idle frame from 60.0 to 23.8 ms. Options: native (720 wide), an
   intermediate scale, or the canvas size. The choice has to be made on the
   phone's real screen, from paired captures of the same view — not from the
   table. D is unaffected (Q8). ⚠️ `STRETCH_VIEWPORT` only reaches the extreme,
   so pricing an intermediate scale needs a render-scale mechanism of its own.
   That is proposed as TEL-UI-02 once the Director has seen the two ends.

---

## 14. TEL — the telemetry and benchmark-analysis suite

**Status:** 🟢 **RATIFIED 2026-09-14 — building** (Director: *"Pode seguir com a
implementação."*). TEL-01 ✅, TEL-02 ✅, TEL-03 ✅, TEL-UI-01 ✅ (desktop),
TEL-06a ✅, TEL-07a ✅ (`bench_analyze.py`: session header, dropped lines, one
row per `scenario.mark` segment). §14.4 is reordered by §13 Q5–Q8. **The Moto
zoom ladder is measured (DIAG-17, §10.17), and TEL-00 is answered by it.**
Portrait M filling the screen is confirmed on the Moto's own screen:
`adb exec-out screencap` gave 720×1612, board edge to edge, no bars.
**Next: §13 Q9 (M render scale), then TEL-05.**

**TEL-07a cross-check (desktop).** On a ladder-shaped scenario, the analyzer
dropped exactly one straddling window per segment. Its `D_z020` row read 49 688
draws, 166 188 objects and 323 942 primitives — identical to the DIAG-16 boot at
`ZOOM=0.2`, which was taken with no telemetry at all (§10.16.2). Portrait M at
390×873 read 1 632 draws (95 cells on screen) at zoom 0.5 and 20 661 (354 cells)
at zoom 0.2.

**TEL-UI-01 + TEL-06a, verified on the desktop (2026-09-14):**
- `Room.set_framing(portrait|landscape|desktop)`. The HUD M/D button, the boot
  and `FRAMING=` all go through it.
- `project.godot` now ships portrait: `window/handheld/orientation=1`.
- A scenario of `framing portrait; window 360x806` (the Moto's aspect) read
  `visible=390×873 aspect=expand`: the canvas filled the window with no bars.
- Floor cells on screen: 95 of 1 104 at zoom 0.5 in portrait, 354 at zoom 0.2,
  and 909 in desktop D at zoom 0.2.
- `SCENARIO=zoom 0.5; zoom abc; quit` was refused before any step ran:
  `[Room] SCENARIO rejected — step 2 'zoom abc': zoom takes a positive number`.
- A `quit` step ends the process with exit 0 and exactly one `scenario.end`
  (the first run wrote two; fixed).
- ⚠️ Portrait "fills the screen" is proven here only as the canvas matching the
  window. The phone's real screen is the evidence that counts, and the Moto run
  captures it.

**Built so far (2026-09-14):**
- `Telemetry` autoload (`godot/scripts/systems/telemetry.gd`) with
  `telemetry_selftest`.
- `ViewContext` (`godot/scripts/systems/view_context.gd`), feeding the
  `[FRAME-PROBE]` view column and the `frame.window` / `view.settled` events.
- Command events at the seams:
  - HUD handlers and board taps in `room.gd`.
  - Pinch, wheel and pan ends plus touch counts in `CameraController`.
  - Menu, aim and blast in `TestZoneController`.
  - End-turn and the enemy phase in `TurnController`.

The desktop run (`TELEMETRY=1 FRAME_PROBE=1 BENCHMARK=1 BENCH_RUNS=1 ZOOM=0.35`)
wrote, in this order, `session`, `view.settled` (D 1280×720, zoom 0.35, 450 of
1 104 floor cells on screen), `menu.open`, `menu.choice`, `blast.start`,
`blast.end` and 8 `frame.window` records, with the file sink open.

**Director, 2026-09-14:** *"Precisamos na realidade melhorar nosso benchmark pra
ser mais realista, executando as sequencias como um humano faria, e também
melhorar nossa telemetria, precisamos saber quando um comando é pressionado"* —
*"Precisamos capacitar o nosso sistema para ele ter mais ferramentas e mecanismos
de diagnósticos, com ênfase na otimização para mobile."* — and, on whether the
detail is worth chasing: *"precisamos determinar quem é o(s) vilão(ões), pra
poder fazer escolhas educadas e conscientes."*

This is inside §0's boundary: it is the harness, and nothing else. A fix the
suite points at still belongs to `PERFORMANCE` or `DETONATION_PERFORMANCE`.

### 14.1 Why — every row is a session this plan already lost

| what went wrong | measured cost | the suite's answer |
|---|---|---|
| a count read without its view (§10.16) | the ×6.6 blamed on the grenade for a day | every probe window carries the framing — **TEL-03** |
| no input in the log (§10.15.2) | "aiming UI open" vs "a state that persists" could not be told apart | semantic command events — **TEL-02** |
| the benchmark skips the human path (§10.9.2) | 24 ms scripted vs 78–88 ms by hand, three sessions unexplained | a scenario runner that issues the commands a hand does — **TEL-06** |
| census and ablations only at map load (§10.15.4) | nothing could be named at the moment it happened | runtime-triggered census and ablation — **TEL-04** |
| means and held maxima (§10.11.1) | `TIME_PROCESS` read 246 ms inside a 92 ms window; the freezes hide inside means | per-frame ring buffer, percentiles, hitch records — **TEL-05** |
| logcat drops lines and its child exits (§5, DIAG-02) | a 250 s run ended 55 s in and reported success | sequence numbers on every event, plus a lossless file sink — **TEL-00/01** |
| APIs that return 0 on Android release | three memory APIs read as zero | "unavailable", enforced by the analyzer's schema — **TEL-07** |
| one run quoted as the verdict (§10.8.3) | two handsets trend in opposite directions | every run reported, same-build spread before any delta — **TEL-07** |

### 14.2 Principles — binding on every TEL task

1. **A number travels with its context:** build, device, resolved flags, framing
   (canvas, window, orientation, zoom, camera centre, visible GU rect) and phase.
   A number without its context is not comparable, and the analyzer says so.
2. **A timeline, not snapshots.** Every event carries `frame`
   (`Engine.get_process_frames()`) and `t_us` (`Time.get_ticks_usec()`), one
   clock. "What happened when the counter jumped" becomes a join, not a guess.
3. **Machine-readable first, human lines kept.** One structured line shape for
   the analyzer. `[FRAME-PROBE]`, `[FRAME-SPLIT]` and `[E-FRAME]` stay
   byte-compatible, with new columns appended at the end, so every earlier log in
   this plan still parses.
4. **Off costs nothing; on is priced.** Each channel is measured on and off on
   the Moto before its numbers are quoted. `FRAME_PROBE`'s render timing already
   forces a GPU sync, which is the precedent.
5. **One channel into the shipped APK: `DevFlags`.** No debuggable build and no
   second flag path.
6. **Loud on absence.** A run missing an expected event fails its analysis; a
   null API reports "unavailable", never a number.
7. **Seams, not sprinkles.** Events are emitted where a command or mode is
   DECIDED (the `room.gd` HUD handlers, `CameraController`, `TestZoneController`,
   `TurnController`), never as a print per call site.

### 14.3 The tasks

**TEL-00 — spike: a lossless sink on the phone.** `DevFlags` proves the release
APK can READ `/sdcard/Android/data/<pkg>/files/`. WRITING there, and `adb pull`
from it, are unproven on Android 14 (Moto) and 16 (Galaxy). Also measure the
write cost per 1 000 events on the Moto. The result decides whether TEL-01 gets a
file sink or stays logcat-only with drop detection.

**TEL-01 — the `Telemetry` autoload.** `Telemetry.event(kind, fields)`, a
per-session sequence number (a gap is a dropped line, counted), and two sinks: a
compact logcat line `[TEL] <seq> <frame> <t_us> <kind> k=v …` and JSONL to the
TEL-00 file. It opens with a session header: version and commit, device model,
GPU adapter/vendor/API version (`RenderingServer`), screen size and refresh rate,
and every flag `DevFlags` resolved. Flags: `TELEMETRY=1`, and `TEL_CHANNELS=` to
pick channels. A selftest pins the schema.

**TEL-02 — command events.** Semantic events, not raw touches:
`input.tap cell`, `menu.open target`, `menu.choice action`, `aim.enter weapon`,
`aim.select gu`, `aim.confirm gu`, `aim.cancel`, `view.framing M|D|auto`,
`view.fullscreen`, `view.orientation`, `camera.zoom_end zoom` (at gesture end,
not per drag event), `camera.pan_end centre`, `turn.end`, `turn.enemy_phase
start|end`, `view.mode dev|light|heat`. Raw touches are one counter per probe
window.

**TEL-03 — the view context.** A `view` event on every change, plus a trailing
`view=` column on each `[FRAME-PROBE]` window: canvas (`content_scale_size`),
window size, orientation, stretch aspect, camera zoom and centre, the visible
world rect, and the visible GU rect with its GU count. **TEL-02 plus TEL-03 is the
smallest thing that would have answered DIAG-15 and DIAG-16 in one run.**

**TEL-04 — render attribution at runtime.**
(a) A census on a trigger: `CENSUS_ON=draws_jump:50%` fires `NODE_CENSUS` when
the draw calls jump between windows; `CENSUS_ON=aim.enter` fires it on a TEL-02
event; a scenario can call it as a step.
(b) A per-`TileMapLayer` estimate of visible quadrants (quadrants intersecting
the visible rect that hold cells), printed with the census, because Godot counts
draw calls per viewport, not per node.
(c) `AUTO_ABLATE=<groups>`: hide a group for one probe window, record the
delta, restore. Bisection without a rebuild, runnable inside a scenario.
⚠️ Estimates are labelled estimates; only hide-deltas are measurements.

**TEL-05 — the frame timeline.** A per-frame ring buffer (frame ms, plus process
ms from `FrameSplit` clocks rather than `TIME_PROCESS`'s held maximum). Each
window reports p50 / p95 / p99 / max and the frames over 33.3 and 41.7 ms. Each
phase reports the same — idle, aiming, flight, playback, enemy phase, load — cut
by TEL-02 events and the existing `[E-FRAME]` beat marks. Any frame over 100 ms is
a hitch record, with every event of the preceding 500 ms attached. That aims
straight at the open COMMIT and SOOT FADE freezes. The playback verdict honours
§0.5: a cook frame is never the verdict.

**TEL-06 — the scenario runner (benchmark v2).** A scenario is DATA, a step list
pushed through the `DevFlags` channel or bundled:

```
framing D · zoom 0.35 · centre_on gu(26,9) · wait 2
open_grenade · aim gu(28,10) · dwell 3 · confirm · await blast_end
end_turn · await enemy_phase_end · census · ablate HUD
```

Steps run through the SAME entry points the input path calls (the functions
TEL-02 instruments), never a shortcut such as `detonate_active()`. So a scenario
run and a hand run emit the same stream, and one analyzer reads both. Pinned by
`RNG_SEED`, map, grenade GU, framing and zoom. It ships with three scenarios:
- `hand_throw_v1` — the Director's sequence: D, zoom, centre, aim, confirm ×3,
  end the turn.
- `idle_matrix` — {band, D} × zoom {0.5, 0.35, 0.2}, 20 s each, no action.
- `BENCHMARK=1`, kept unchanged as a COMPARATOR for A/B continuity with
  §10.9–§10.14.

Dwell times come from a recorded hand session's TEL-02 stream, not from a guess.
**Not now:** turning a recorded stream into a scenario automatically (record →
replay). That stays deferred until the step format has survived real use.

**TEL-07 — the analyzer, `tools/persistent/bench_analyze.py`.** It reads the
logcat capture or the JSONL file, plus TEL-08's host samples. It writes a per-run
report: session header, framing, phases, percentiles, the budget verdict per
phase, hitches with their preceding events, counter jumps joined to the nearest
TEL-02/03 event, and the memory and thermal tracks. `--compare A B` refuses a
delta whose pair has no same-build control. It fails loudly on missing expected
events and reports sequence gaps as dropped lines with a count. Markdown goes to
stdout, with an optional HTML chart page. A selftest runs it on a stored real
log. Every run is reported, never only a mean.

**TEL-08 — host-side device sampling in `device_run.py`.** `--thermal-poll`
(`dumpsys thermalservice` status and temperatures), battery temperature, per-core
CPU frequency (`/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`, reported
"unavailable" if a release build cannot read it), refresh rate, and the existing
`--mem-poll`. All are stamped with the device clock so they join the logcat
stream. This is DIAG-07's instrument.

**TEL-09 — gates and docs.** A schema selftest and an analyzer fixture selftest,
both registered with `run_selftests.py`. The overhead is measured on the Moto
(`TELEMETRY=0` vs `1`, same scenario) and recorded here.
`docs/pipelines/device_telemetry.md` becomes the operating doc (flags, scenario
format, analyzer), cross-linked from `MobileTesting.md`. ⚠️ §11's rule applies:
verify no gate blocks the daily workflow.

**TEL-UI-01 — portrait M fills the screen; D stays unrestricted.** The benchmark
cannot be realistic while the shipped build shows a band nobody plays in. First
direction (Director: *"O ideal é que a orientação da tela retrato x paisagem siga
automaticamente a orientação do celular"*), then narrowed by §13 Q5–Q8: portrait
is the default and the test framing, and landscape is not a default.
- `display/window/handheld/orientation` becomes `1` (portrait). Sensor rotation
  is deferred until a landscape version exists.
- **M fills the screen:** the 390×844 canvas takes `CONTENT_SCALE_ASPECT_EXPAND`,
  so a taller phone gets a taller canvas instead of black bars (Moto 720×1612 →
  390×873).
- **D is today's 1280×720**, unrestricted. On a handheld it turns the screen to
  landscape through `DisplayServer.screen_set_orientation()`, so the Director's
  test habit keeps working on a portrait-locked APK.
- `FRAMING=portrait|landscape|desktop` in `DevFlags` forces the boot framing for a
  test; `landscape` is M at (a) 844×390.
- On a handheld the framing changes only the canvas and the orientation. Today
  `_apply_viewport_mode()` also calls `window_set_mode(WINDOWED)`,
  `window_set_size()` and `window_set_position()`, whose effect on Android is
  unmeasured.
- The web preset already sets `progressive_web_app/orientation=2`; the APK
  shipped landscape. This task aligns the APK.

### 14.4 Order

```
TEL-01  Telemetry autoload                               ✅ 2026-09-14
TEL-02  command events      ┐ together — the smallest thing that
TEL-03  view context        ┘ would have answered DIAG-15/16
TEL-UI-01  portrait M fills the screen · D unrestricted  (§13 Q5–Q8)
TEL-06a scenario core: framing · zoom · centre · wait · quit
        ── Moto: the zoom ladder in portrait M, and D at the same stops.
           TEL-00 is answered by the same run (see below). Closes DIAG-16
           and gives §13 Q6 its table ──
TEL-05  frame timeline, percentiles, hitches
TEL-07  analyzer
TEL-06b action steps — hand_throw_v1 with dwell times from a recorded session
TEL-04  runtime census / auto-ablation
TEL-08  host-side thermal / CPU sampling → DIAG-07 sustained run
TEL-09  gates + docs
```

**Reordered 2026-09-14.**
- **TEL-00 folded into the first Moto run.** An isolated spike would need its own
  export anyway, and TEL-01's file sink already warns and falls back to logcat
  when it cannot write. That run answers both of TEL-00's questions: does the
  write succeed, and does `adb pull` reach the file.
- **TEL-UI-01 moved ahead of the device run.** The Director's verdict framing is
  portrait M filling the screen (Q7), so measuring the old band would measure a
  framing nobody plays in.
- **TEL-06 splits.** The view steps come first, because the zoom ladder needs no
  finger. The action steps come after the analyzer.

**Why this order.** Telemetry comes before the benchmark because the scenario's
dwell times and framing come from a recorded hand session. The analyzer comes
before the runner so the runner's first output lands in a tool rather than in
scrollback.

### 14.5 What stays out

- No input record → replay system (TEL-06 note).
- No on-screen telemetry HUD: the phone's screen is what is being measured, and
  a readout there changes the frame it reports.
- No second flag channel and no debuggable build (§14.2 #5).

### 14.6 Director rulings of 2026-09-14

- **The framing follows the phone's orientation**; a forced framing is a test
  tool (TEL-UI-01).
- **The benchmark must run the sequence a human runs** (TEL-06).
- **JAMES is suspended until the performance milestone closes:** *"vamos
  suspender o JAMES até terminar o milestone de performance - você faz tudo, sem
  divisão de tarefas."*
  - Claude does both engine and interface work on `main`: `godot/scripts/ui/`,
    `godot/scenes/ui/`, `hud_controller.gd`, `input_controller.gd`.
  - The L3 seam stays; it is architecture, not staffing.
  - `check_design_scope.py` only warns on `main`, so no gate changes.
  - **Before JAMES resumes, `feat/design-interface-hud` must merge `main`** —
    interface files changed here in the interval conflict otherwise.
  - Recorded in `CLAUDE.md` and `.README_WORKSPACE.md`.
  - Assumption, stated: "the performance milestone" closes when the Director
    declares §0.5's budget met. No written definition of that milestone exists.
