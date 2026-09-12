# DEVICE_DIAGNOSTICS_MASTER_PLAN
## Measuring the real build on a real entry-tier phone — v0.1

**Status:** 🟡 **v0.1 — a captured brief, awaiting Director sign-off.**
Nothing here is built. The task IDs are proposals, not a landed sequence.

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
DIAG-02b logcat parser
DIAG-03  scripted scenario on device
         ── first real number here ──
DIAG-04  renderer control run
DIAG-07  sustained / thermal run
DIAG-08  gates + docs
```

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
