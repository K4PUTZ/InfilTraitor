# DEVICE_DIAGNOSTICS_MASTER_PLAN
## Measuring the real build on a real entry-tier phone — v1.10

> ⏭️ **2026-09-24 — THE R3D-13 BASELINE, Moto g04s ONLY (the Galaxy A16 was not attached).** Release APK of `1788f0fd` + docs (`export/r3d13.apk`), PLAYGROUND, portrait,
> `RNG_SEED=1`, grenades `25,2;37,2`, shotgun at guard 0, `EVENT_FRAMES=1`; logs local (`/tmp`, git-ignored). **3D board (`RENDER3D=1`, two boots) vs the 2D board
> (`RENDER3D=0`, one boot, the last row for the record):** `[RNG] seeded` -> map loaded **16.3 / 16.3 s vs 53.9 s**; PSS (last poll) **1.38 / 1.38 GB vs 2.33 GB**, native heap
> 736 vs 691 MB. Idle, `FRAME_PROBE` windows: zoom 0.75 **18.9 vs 54.2 ms/frame** (gpu 17.3 vs 52.8, draws 76 vs 328), zoom 1.0 **19.1 vs 53.6** (gpu 17.5 vs 52.2, draws 55 vs 253), zoom
> 0.5 after settling **19.1-21.9 vs 53.9-61.4** (draws 55-91 vs 253-1 625). Two detonations (mean / worst frame, COMMIT frame, LIGHT ms/frame): **3D 29.5-30.2 / 32.4-32.7 ms mean,
> worst 319-402 / 693-725, COMMIT 237-239 / 230-233, LIGHT 32-32.4 / 34-35; 2D 102.5 / 128.9 ms mean, worst 389 / 3 855, COMMIT 312 / 309, LIGHT 102.7 / 112.3.** Only the 3D board is at the
> 30 fps budget (33.3 ms); the tails (the second grenade's CONSEQUENCE frame, ~720 ms, and the ~235 ms COMMIT) are the open items. **Not measured:** the Galaxy A16; the shot's tail;
> the earlier flag-malformed rows (a `RENDER3D=1 a` value silently ran the 2D board: check `[BOARD3D]` in the log before trusting any RENDER3D row).

> ⏭️ **2026-09-23 — `RENDER3D_MASTER_PLAN` R3D-SPIKE-3D on the Moto g04s** (PLAYGROUND, portrait, zoom 0.5, `FRAME_PROBE`, one boot per row,
> `docs/measurements/device_2026-09-23_moto_spike3d_*.log`): base 19.0-19.6 ms/frame (gpu 17.5-18.1). The board lit by 12 real
> lamps 43.6 (no shadow) / 58.4 (4 shadowed) / 66-73 (12 shadowed). 9 walking rigs +2.4 ms with actor-layer lamps, **+1.0 with
> the cell-plane shader**; 20 static props +9.7 with lamps, **+1.5 with the shader**, +4.3 for 200k-tri stand-ins. Real Godot
> lights are what cost on this Mali; geometry is cheap. One boot of the rig APK exited during the load with nothing in the crash
> or kill logs (not reproduced).

> ⏭️ **2026-09-22 — SOOT-STAMP measured on the Moto g04s** (release APKs before/after, `PLAYGROUND_2`, 5 grenades + 2 shotgun shots): shot soot 5.2 s -> 19 ms; blast cook SOOT phase 257 -> 1 142 ms growing -> 225–282 ms flat; detonation MEAN frame 31.2–32.9 ms on all five grenades (3 of 5 were over 33.3 ms). Still over, not soot: the commit frame ~190 ms, the cook's atomic LIGHT phase ~190 ms, the first shot after blasts (719 ms tail), grenade 5's glass (919 ms). APKs: `export/soot_before.apk` / `soot_after.apk`; table: `PROMPTS/AUDITS/SHOT_SOOT_PERF_2026-09-22.md`.


> ⏭️ **2026-09-20 — R3D-7's cutaway and R3D-6's decals/dents/rim wedge measured on the Moto g04s and, for the
> cutaway baseline, the Galaxy A16 (SM-A166W, Android 16)** (`docs/measurements/device_2026-09-20_*`, git-ignored).
> **The Galaxy is 3-4x FASTER than the Moto on this workload; the Moto is the constraint.** New instruments: the
> scenario step `occ_bench <a> <b> <reps>` (per-phase clocks for the occlusion set and the cutaway, canonical
> digests; `tools/persistent/occ_canonical_gate.py` is its desktop gate) and `place_guard`; new device flags
> `GUARD_REVEAL`, `DECALS3D`, `DENTS3D`, `GLASS_OPENINGS3D` (the first three static switches only read the OS
> environment, which an APK never gets, until `Board3DLive.build()` and `GlassCrackMirror3D.setup()` were made to read
> `DevFlags`; `CUTAWAY_ON` STILL reads the environment only). Results: an agent step with a wall volume 195 → 42 ms,
> three nested volumes 149 → 52, an agent inside a roofed room 314 → 39, a floating 15x15 roof (7 744 revealed columns)
> 652 → 42; the decals, dents and rim wedge cost +1.8 ms mean frame over a blast (+1.2 ms GPU settled), nothing at
> idle, no memory. **Lesson: the two biggest costs were hidden 2D-board work under the 3D board, outside every clock.**
> A 46 s boot is still the dominant cost of a measurement cycle; a detonation run is ~100 s. Not run: shots.
> Details: `RENDER3D_MASTER_PLAN` R3D-7, `PROMPTS/RESUMO_SESSAO_2026-09-20_R3D7_CUTAWAY_ROOFS.md`.

> ⏭️ **2026-09-21 — the R3D-7 tail measured on the Moto g04s and the Galaxy A16** (`docs/measurements/device_2026-09-21_*`, local; `RENDER3D_MASTER_PLAN` v1.11/v1.12). Real shots: post-flight tail 593-611 ms on the Moto 3D (2D 745), 572-585 of it the shared light repaint; on the Galaxy 3D brick 357 ms vs 2D 214 (opposite direction, one boot). `GUARD_REVEAL` x8: +12 draw calls, GPU not slower. Touch (`input tap`/`swipe` work; a two-finger pinch cannot be automated: SELinux blocks `/dev/input` writes for `shell`). DevFlags additions: `SHOT_WEAPON` now reaches an APK, `SHOT_SETTLE_FRAMES`. Harness traps: boot 55-70 s so `device_run.py --seconds` >= 150; script-started `logcat` piles up; clear `dev_flags.cfg` after a session.

> ⏭️ **2026-09-21 — RECORDING VIDEO on the handset costs little (Moto g04s, PLAYGROUND, one detonation, `adb shell screenrecord` 720x1600 at 8 Mbps, 3 runs each, alternating):** mean frame **33.4-34.6 ms recording vs 32.3-33.5 not**, GPU **24.6-24.9 vs 23.7-23.8 ms** (about +1 to +2 ms and +1 ms), worst window 60-68 vs 59-66 ms. Enough to judge the flow of an effect, NOT to take a number from (never record during a measurement). `python3 tools/persistent/device_record.py --device <serial> --preset blast --out videos/<name>.mp4` (`videos/` is git-ignored; full guide `docs/pipelines/device_video_recording.md`) wraps it (push a `SCENARIO` ending in `quit` first; the boot, 55-70 s on the Moto, is in the raw file, `--skip` trims it, and the tail, the home screen after `quit`, is trimmed by `--trim-end`, 4 s; the Godot splash lasts ~64 s from the start of the recording, use `--skip 60`+ ). New flag **`DEV_PANELS`**: the two DEV VISION TEXT panels (tile info and systems status) are OFF by default; `DEV_PANELS=1` shows them; DEV VISION itself (FOW off, overlays, agent tint) is untouched. The red playable-area line and the dark spawn diamond are gated by `DEV_PANELS` too. A scenario `detonate` closes the Detonate menu before the blast, like the real click.

> ⏭️ **2026-09-18 — R3D-4 and R3D-5 measured on the Moto g04s** (`docs/measurements/device_2026-09-18_*`;
> chain: `export_android.py --install` → `dev_flags.cfg` → `device_run.py --save` → `bench_analyze.py`,
> with `TELEMETRY=1`). Billboard actor spike: none 21.8 ms, A 22.2 ms, B 31.7 ms. Actors/guards/props in the
> real game: +0.2 to +0.4 ms. VFX in world space: detonation 30.2 ms vs 32.3 ms. New dev seams:
> `SPIKE=r3d4a` (+ `R3D4A_BENCH=1`), `ACTORS3D`, `VFX3D`, `GROUND3D`, `PICK3D`, `PICK_CHECK`, `SEED_GRENADES`.
> Not run: the R3D-5a pick check on the device (none connected).

**Status:** 🟢 **v1.10 — RENDER3D R3D-1a measured (2026-09-16).**
Where the Moto g04s stands:

- **R3D-1a, the voxel store's layout (§15.19):** in GDScript on the Moto, per-container
  packed arrays (B) read the three hot readers **1.9–2.8× faster than today's objects**:
  light 481 vs 1 364–1 382 ms, mesher 417 vs 788–803, walk 134 vs 362. They cost
  13.5 MB against 191 MB. The decision rule picks B, pending the Director.

- **RENDER3D R3D-0 closed (§15.18.6):** the last two reference pairs, embers and roof
  tops, were captured inside the blast by the new scenario step `capture_at`.
  - The dark "roof tops" in 3D are 2D shadow overlays drawn over the 3D board, not roofs.
  - ⚠️ **`RNG_SEED` did not reach an APK before commit `9740116a`.** `Room._ready()` read
    it with `OS.get_environment()`, not `DevFlags`, and none of 20 Moto logs from
    2026-09-15/16 prints `[RNG] seeded`. So every earlier device table that lists
    `RNG_SEED` ran with its particle rolls unseeded: §10.9–§10.11, the benchmark and the
    TEL scenarios.
    - It is fixed (Director, 2026-09-16), and all 4 Moto boots after the fix print
      `[RNG] seeded 1`.
    - A seed does not make in-blast frames repeat: seeded, they still differ by 32–42 %
      from run to run (§15.18.6).

- **RENDER3D R3D-0 (§15.18):** one APK re-ran DIAG-21/22/23 as the migration's
  baseline, and every row landed inside the earlier measurements.
  - **A `Voxel` object costs ~925 B on the Moto:** 215 432 objects add +190 MB of
    native heap in both runs. PLAYGROUND's 216 104 voxels therefore cost ~191 MB, not
    §15.17's desktop-debug 316 MB.
  - The instrument calibrates itself: the same count packed reads +1 MB, and a known
    190.7 MB array reads +191 MB.
  - The desktop half, `BoardProbe` and its identity gate, is recorded in
    `RENDER3D_MASTER_PLAN` R3D-0.

- **The decision (§15.17):** the Director ratified moving the board to Godot 3D, over a
  packed voxel store. The migration is planned in
  [`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md), stages R3D-0 to R3D-END.
  - Measured on the way: one `Voxel` object costs ~1 540 bytes, so PLAYGROUND's 215 432
    voxels cost **316 MB** on a desktop debug build, against 0.8 MB packed.
  - This plan stays the measurement harness for that track.

- **Memory, 2D vs 3D (DIAG-23, §15.15):**
  - At the look the game ships, 2D idles at **2.17–2.20 GB**, with 0.7–1.4 GB swapped
    out. The 3D path costs **at most 1.04–1.10 GB**, with nothing swapped.
  - The saving is the bake atlas, which the 2D look needs and a 3D face does not: 2D
    without it is 1.10 GB but loses the facade look.
  - The 2D board's 207 944 cells themselves free 59 MB of native heap and no graphics
    memory.

- **The cook stall (DIAG-22, §15.13):** one damage composite stored mid-cook created a
  tile on the TileSet every TileMapLayer shares, and the next frame rebuilt them all —
  hidden layers included. Tiles are now created when the page is registered at load.
  Grenade #1's cook frame: **809 → 97–115 ms** (3D, 2D writes skipped) and
  **1 734 → 189 ms** (2D). Load pays 740 ms once.
- **The 3D prototype (DIAG-20/21, §15.6–§15.11):** the live board as Godot 3D meshes
  over the real voxel registries idles at 18 ms against 60 ms in 2D, and with the hidden
  2D writes skipped grenade #1 plays in 11.2 s against 28.6 s. What is left: the LIGHT
  step of the cook (234–408 ms) and the commit frame (~270 ms). The render decision is
  the Director's (§15.12 item 4).
- **Portrait M, the verdict framing, filling the screen (DIAG-17/18, §10.17–§10.18):**
  pixel fill was the biggest cost (36–47 ms of GPU). The world render scale is **1.0**
  by Director ruling (§10.18 — 0.75 measured 40.8 ms idle but was not kept).

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
⚠️ **Before commit `9740116a` the seed half held on desktop only** (§15.18.6): the seed was
read from the environment, which an APK does not have. It is read through `DevFlags` now.

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

## 10.18 🟡 DIAG-18 — TEL-UI-02 ON THE MOTO: 0.75 BUYS 19 ms AT THE DEFAULT ZOOM, AND ONLY THE DEFAULT ZOOM REACHES THE FLOOR

**Director, 2026-09-14:** *"Pode seguir com o TEL-UI-02, escala 0,75"*.

Every row below comes from one binary: commit `bfd1b346`, APK exported at 16:59
with the portrait manifest.
- PLAYGROUND, untouched board; driven by `SCENARIO=` and read by
  `bench_analyze.py`.
- The control is `RENDER_SCALE=1`, which turns the mechanism off.
- Logs (local):
  `docs/measurements/device_2026-09-14_moto_g04s_telui02_rs100_control.log` and
  `…_telui02_rs075_ladder.log` — 46 and 89 records, 0 dropped.

### 10.18.1 The control reproduces DIAG-17 to the tenth

`RENDER_SCALE=1` at zoom 0.5 / 0.42 / 0.35 read 60.0 / 70.3 / 89.2 ms/frame and
58.6 / 69.0 / 87.7 ms of GPU. That is §10.17.2's table, measured on the previous
APK. So the scale-1.0 path is untouched, and a ladder is repeatable across
installs.

### 10.18.2 The table

| zoom | cells on screen | draws | render cpu | GPU, world 1.0 | **GPU, world 0.75** | GPU, whole 2D at canvas size (§10.17.4) | ms/frame, 1.0 → 0.75 |
|---|---|---|---|---|---|---|---|
| 0.50 | 95 | 1 642 | 6.4 | 58.6 | **39.5** | 22.3 | 60.0 → **40.8** |
| 0.45 | 109 | 2 498 | 8.1 | — | 43.2 | — | — → 44.5 |
| 0.42 | 115 | 3 092 | 9.1 | 69.0 | 47.5 | — | 70.3 → 49.0 |
| 0.38 | 157 | 4 604 | 12.3 | — | 56.4 | — | — → 57.8 |
| 0.35 | 173 | 5 604 | 14.2 | 87.7 | 62.2 | 41.0 | 89.2 → 63.7 |
| 0.30 | 235 | 10 532 | 22.6 | 106.2 (§10.17.2) | 78.8 | — | 107.6 → 80.2 |

At every stop, draws, objects and `render cpu` match the control's within 0.1 ms
or one draw. The mechanism changed pixels only.

### 10.18.3 What it says

- **0.75 saves 19.1 ms of GPU at zoom 0.5 (−33%)**, 21.5 ms at 0.42 and 25.5 ms at
  0.35. The world's pixels fell 44% (1.78×), so the saving is less than
  proportional. Part of the frame does not follow the world's pixels:
  - the root pass still draws the HUD and the fog at native resolution;
  - the upscale adds a full-screen quad;
  - the per-primitive work does not change.

  ⚠️ An estimate by pixel ratio predicted ~36 ms at zoom 0.5; the phone measured
  39.5.
- **Idle portrait M at the default zoom reads 40.8 ms/frame.** That is inside the
  41.7 ms floor and outside the 33.3 ms target. Every stop below 0.5 is past the
  floor: 0.45 already reads 44.5 ms.
- **The look** is in `Screenshots/history/moto_m_world_scale_100_vs_075_2026-09-14.png`,
  two real Moto screencaps of the same view from this binary:
  - the HUD is identical and the world is marginally softer;
  - the thin selection rectangle keeps all four sides, where the canvas extreme
    (§10.17) lost two.

### 10.18.4 What is left — and it is no longer the pixels

With the world at 0.75, the default-zoom frame is ~40 ms before any blast, and a
blast adds 10–35 ms on top (§10.14.3, §10.15.3). The remaining levers, ranked by
these numbers:

1. **The per-primitive cost of the board on screen.** From zoom 0.5 to 0.3,
   `render cpu` goes 6.4 → 22.6 ms and GPU gains another 39 ms. The lever is fewer
   layers or fewer live cells — `PERFORMANCE_MASTER_PLAN`, and the architecture
   decision already open for the Director.
2. **An M zoom floor (§13 Q6).** On this build, only 0.5 itself is inside the
   floor.
3. **The blast** (`DETONATION_PERFORMANCE_MASTER_PLAN`).

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
   **Measured under the ratified 0.75 world scale (§10.18.2):** zoom 0.5 reads
   40.8 ms (inside the 41.7 ms floor), 0.45 reads 44.5, 0.42 reads 49.0. On this
   build, the only M floor inside the budget is 0.5 itself — no pinch-out at all —
   until the per-primitive cost falls (§10.18.4). The decision stays the
   Director's: hold the floor at 0.5, or accept a known cost below it.
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
9. ✅ **RULED 2026-09-14 — 1.0 (native). The world render scale stays OFF by
   default.** After the six paired Moto captures (§10.18), the Director ruled:
   *"eu acho que não vale a pena piorar o jogo por causa disso. Vamos manter
   1.0"*. `render_scale_m` is 1.0; the TEL-UI-02 mechanism stays in the build,
   reachable only through `RENDER_SCALE=<f>`, as an instrument. ⚠️ So the verdict
   frame is §10.18's 1.0 column — 60 ms idle at the default zoom — not its 0.75
   column.
   Superseded ruling, kept for the record: **0.75, the world only.** Director: *"Pode seguir com
   o TEL-UI-02, escala 0,75"*, after seeing the paired Moto captures. Built as
   TEL-UI-02: `WorldRenderScale` renders the world into a SubViewport at 0.75× the
   screen's pixels (540×1209 on the Moto, 1.78× fewer), sharing the root
   `World2D`. The root viewport's `canvas_cull_mask` keeps only the HUD, the fog
   and the displayed world texture, so the HUD stays native. D renders at 1.0,
   with the mechanism OFF; `RENDER_SCALE=<f>` overrides it for a test.
   - Proven first by a standalone spike on this engine build: world content on
     the same pixel with the scale on and off; a HUD rect's box identical; with
     the texture hidden, 0 world pixels left in the root viewport.
   - The frame probe sums both viewports' render time, so it cannot report a
     saving that did not happen.
   - Original question, kept:
   **The render scale of M — a look decision the measurements now force.**
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
**§13 Q9 is answered and built (TEL-UI-02), and measured on the Moto in §10.18: idle portrait M at the default zoom is 40.8 ms. Next: TEL-05, and §13 Q6 for the Director, with §10.18.2's table.**

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

---

## 15. The two decisive experiments — where the detonation's anchor is, and whether it is the 2D representation

**Status:** 📋 **REGISTERED 2026-09-14 — Director: *"Ok, deixa o plano registrado e
vamos seguir."***

**DIAG-19 prerequisites BUILT (2026-09-14).**
- **Knobs through `DevFlags`, so they reach the APK:** `SMOKE_CHANCE`,
  `VFX_DRAW_NOOP`, `LIGHT_SECONDS`, `NO_LIGHT_COOK`.
- **New instruments:**
  - `NO_SOOT` — the writer's own `soot_clean`, and no fade;
  - `NO_CONSEQUENCE_LIGHT` — the light beat is not played;
  - `BLAST_MAX_RING=<n>` — all six per-ring tables are cut.
- **`detonate <index>`** scenario step (`Room.scenario_detonate()`): the camera on
  the grenade, the menu path, waits for the blast's end.
- **`bench_analyze.py`** reads `[E-FRAME]` reports into a per-detonation table.
- **Desktop, real path**, grenade #0:
  - control: 6.5 s, COMMIT 1 915 cells in 23 ms, soot fade 1 645 cells;
  - every knob on: `frag_grenade cut to 2 ring(s)`, COMMIT 914 cells, no fade.
- **On the DIAG-15 hand log**, the analyzer reproduced its three detonations
  (PUMP 106–111 frames ≈ 10 s; COMMIT 3 939 / 534 / 3 489 ms).
- **Selftests:** 55 clean. **The matrix is running on the Moto.**

**DIAG-20 spike BUILT (2026-09-14).** `SPIKE=board3d` hands `Room._ready()` over to
`godot/scenes/spikes/board3d_spike.tscn` before any map is built. The spike builds
PLAYGROUND's floor zones, blocks and panels at the 2D geometry (8 voxels per GU, 8
levels per storey, a storey as tall as a GU) and measures them.
- **Desktop, the real path:**
  - `voxel` mode: 73 024 exposed faces, 135 296 primitives, 6–7 draw calls, built
    in 320 ms;
  - `merged` mode: 160 faces;
  - **95 GUs on screen at zoom 0.5 in both — the 2D board's own count**, so the
    world area matches;
  - a real capture shows the same layout as the 2D default view.
- ⚠️ **One mesh per material, no chunking,** so every primitive is submitted every
  frame. The voxel row is an upper bound for this representation.
- **Fixed on the way:** `_draw()` still ran once before the deferred scene change
  (three SCRIPT ERRORs), so the hook now hides the room — 0 SCRIPT ERRORs after.
  The spike emits `camera.zoom_end`, so the analyzer's segments close at each
  zoom change.

**The questions, in the Director's words:**
- *"Se a gente deixar de fazer cálculos e usar explosões padronizadas […] ficaria
  mais leve? Se fizer a mesma coisa com as paredes […] Desligar a fumaça, desligar a
  fuligem, desligar a luz, diminuir o tamanho do ring […] Aonde está nossa âncora? Ou
  é tudo junto?"*
- *"Será que estamos pagando um preço muito alto por tentar simular um mundo 3D num
  engine 2D, e ficando com o pior das duas situações? […] Precisamos considerar a
  possibilidade de migrar para Unreal ou Unity."*

Both are answered by measurement, not by picking. Two of this plan's three earlier
suspect lists were wrong before they were measured.

### 15.1 What the logs already say — two anchors of different kinds

The Moto, hand play, first detonation of DIAG-15 (§10.15; D framing): **28.7 s** from
the start of the event to its end.

| beat | on the Moto | what paces it |
|---|---|---|
| PUMP — the pre-cook | 106 frames, **9.8 s** | **the frame.** `[P-COOK] cooked 107 frame(s) at 14.0 ms`: the cook gets a 14 ms budget per frame, and each frame took ~92 ms. On a 16 ms frame it would be ~1.7 s |
| COMMIT — damage written into the board | **one frame, 3.9 s** (0.5 s on the second detonation) | the detonation itself |
| SOOT FADE — its first frame | **one frame, 3.6 s** (0.4 s on the second) | the detonation itself |
| CONSEQUENCE + LIGHT | ~112 frames at ~90 ms ≈ 10 s | the board again |

1. **The board** costs every frame, grenade or not. It stretches the pre-cook and the
   long beats, and in the verdict framing it is already **60 ms idle** (§10.18.1,
   §13 Q9 ruled the world at 1.0).
2. **Two single-frame stalls** belong to the detonation itself: COMMIT and the first
   SOOT FADE frame. Those are the "lags enormes".

What each proposed simplification is EXPECTED to touch — expectations, not
measurements. §15.2 replaces them with numbers.
- **Standardised explosions** remove the prediction's arithmetic, but the arithmetic
  is not what is slow; painting the voxels and the per-frame board are. The gain
  should be small unless the pattern also caps how many voxels change.
- **A smaller ring or less damage** means fewer voxels written, so COMMIT and the
  soot stall should shrink together.
- **No soot / no light** aim at the second stall and at the long beats.
- **Blockier walls or a smaller baked atlas** are already measured: bake off halves
  the memory and makes the blast **2.3× slower** (§10.9.1). A trade, not waste.

### 15.2 DIAG-19 — the detonation ablation matrix (Moto, portrait M, world 1.0)

**The question:** which subsystem owns the detonation's wall clock and its spikes,
and how much of that time the board's pacing adds.

**Prerequisites:**
- **Route the blast knobs through `DevFlags`.** Today they are `OS.get_environment`
  only, so they are inert on the APK: `NO_LIGHT_COOK`, `LIGHT_SECONDS` (`room.gd`),
  `SMOKE_CHANCE` (`material_resistance_table.gd`), `VFX_DRAW_NOOP`
  (`vfx_draw_probe.gd`).
- **New knobs, instruments only:**
  - `NO_SOOT` — no soot written or faded;
  - `BLAST_MAX_RING=<n>` — truncates the bomb's `ring_multipliers`
    (`bombs/frag_grenade.json`, `[1.0, 0.6, 0.25, 0.0]`).
- **A working "no consequence light" instrument.** `NO_LIGHT` is degenerate since
  the cooked light (§10.11.1) and must not be quoted; the row uses whichever
  instrument the code reading shows is valid.
- **TEL-06b, first slice:** a `detonate <index>` scenario step. It centres the camera
  on a dev grenade, detonates through the menu path (`open_menu_for()` +
  `detonate_active()`) and waits for the blast to end. The blast is then ON SCREEN in
  the verdict framing; the benchmark's blast ran off screen.
- **TEL-07b:** `bench_analyze.py` reads `[E-FRAME]` reports — per detonation: wall
  clock, mean, worst frame, PUMP frames and wall clock, the COMMIT frame, the first
  SOOT FADE frame, and the ms per frame of CONSEQUENCE and LIGHT.

**The rows.** One boot each, two detonations per boot (dev grenades #0 and #1, so the
geometry is identical across rows), `RNG_SEED` fixed, one APK for all rows with its
SHA recorded:

| row | flags | isolates |
|---|---|---|
| control (run twice, for the spread) | `RENDER_SCALE=1` | the baseline, and the noise any delta must exceed |
| cheap board | `RENDER_SCALE=0.5` | how much of the wall clock the board paces |
| no soot | `NO_SOOT=1` | the SOOT FADE stall and the soot work |
| no light | the valid instrument | the CONSEQUENCE and LIGHT beats |
| no smoke / VFX | `SMOKE_CHANCE=0`, `VFX_DRAW_NOOP=1` | particle submission |
| small blast | `BLAST_MAX_RING=1` | how COMMIT and soot scale with the voxels touched |
| all off | the four subsystem rows together | "é tudo junto?" |

### 15.3 DIAG-20 — the 3D representation spike, in Godot itself

**The question:** is the 2D representation the anchor? The suspicion rests on two
measurements:
- The idle portrait board is ~42 000 primitives — trivial for this GPU in 3D — yet it
  costs 60 ms.
- 36–47 ms of that is pixel shading (§10.17.4). 48 stacked `TileMapLayer`s are drawn
  back to front with no depth buffer, and the face shader runs on every covered pixel
  of every layer.

A 3D pipeline shades each opaque pixel about once, never shades hidden faces, and
turns destruction into rebuilding a chunk mesh instead of minting tile variants per
cell — the COMMIT stall.

**Why Godot 3D, and not Unity or Unreal, first:**
- It is the renderer this project already ships (Vulkan Mobile).
- The game logic survives: turns, TIC, AI, maps, the prediction pipeline, telemetry.
- Unity or Unreal means rewriting all of that code. Only design, data and assets carry
  over.
- Unreal on a 3.8 GB Mali-G57 handset is a heavy bet on its own.

A migration is on the table only if Godot 3D fails this test.

**What gets built** — a spike scene, reachable in the shipped APK through
`SPIKE=board3d` (no second APK):
- The static board read from `maps/PLAYGROUND.map.json` (board, blocks, panels) and
  built as 3D meshes, in chunks.
- **Two meshing modes, because the answer depends on them:** per-voxel faces with
  hidden-face culling (the destructible granularity — the worst case), and faces
  merged per block surface (intact geometry — the best case).
- The materials' own facade textures on a simple material; glass as a transparent
  material.
- An orthographic `Camera3D` at the 2D projection's angle, framed like portrait M,
  with zoom stops that show the same world area as the 2D ladder (§10.17.2).
- `Telemetry` `frame.window` records and scenario marks, so `bench_analyze.py` reads
  it exactly like the 2D ladder.

**Not in the spike** — stated so nobody reads it as parity: the 12-bucket light,
soot, damage decals, destruction, actors and fog. It prices the REPRESENTATION, not
the finished look.

**Decision rule — proposed, and written down before measuring.** On the Moto, portrait
720×1612, at the zoom 0.5 world area:
- **≤ ~15 ms idle** (against 60 ms in 2D): the representation is the anchor. A 3D
  render layer inside Godot that keeps the game logic is proposed as a
  `PERFORMANCE_MASTER_PLAN` decision.
- **≥ ~35 ms:** the representation is not the villain; optimise within 2D (layers,
  cells, shader).
- **In between:** report both numbers and decide together.

### 15.4 Order

```
DIAG-19 prerequisites   knobs through DevFlags · NO_SOOT · BLAST_MAX_RING ·
                        detonate step · E-FRAME in the analyzer
DIAG-19 runs            the matrix on the Moto, in the background ─┐
DIAG-20 spike           built on the desktop meanwhile              │
DIAG-20 on the Moto     after the matrix frees the phone ◄──────────┘
report                  both tables together
```

This plan measures. What either experiment decides belongs to
`PERFORMANCE_MASTER_PLAN` or `DETONATION_PERFORMANCE_MASTER_PLAN` (§0).

### 15.5 ✅ DIAG-19 MEASURED — the stalls are the damage footprint, the duration is the board

Moto g04s, 2026-09-14 18:42–19:01. One APK for all rows (sha256 `0c8d25216a5a102d…`,
commit `31b4be42`), portrait M, world 1.0, zoom 0.5, blast on screen:
`detonate 0` (grenade #0, GU 3,5, the concrete row), then `detonate 1` (grenade #1,
GU 8,5, the metal row). Logs (local):
`docs/measurements/device_2026-09-14_moto_g04s_diag19_m0*.log`. Each value is the row
against the mean of the two controls; `~` marks a delta no larger than the controls'
own spread.

**Grenade #1 — the one with the multi-second stalls:**

| row | wall s | mean ms | worst ms | PUMP s | COMMIT ms | frame of the presenter's cell write ms | CONSEQUENCE ms/f | LIGHT ms/f |
|---|---|---|---|---|---|---|---|---|
| controls (±half-spread) | 28.8 (±0.1) | 116.6 (±0.1) | 1 937 (±92) | 14.7 (±0.2) | 348 (±1) | 1 757 (±9) | 103.1 | 101.4 |
| cheap board (`RENDER_SCALE=0.5`) | 18.5 (−36%) | 62.2 (−47%) | 1 727 (−11%) | 8.4 (−43%) | 293 (−16%) | 1 699 (−3%) | 47.8 (−54%) | 47.8 (−53%) |
| no soot | 28.4 (−1%) | 117.3 (+1%) | 2 084 (~+8%) | 14.8 (~0) | 346 (−1%) | — (no fade mark; the stall is still in the frame) | 138.6 | 101.5 |
| no light | 22.4 (−22%) | 120.9 (+4%) | 1 800 (~−7%) | 14.4 (~−2%) | 343 (−1%) | 1 753 (~0) | 103.0 | 101.9 |
| no smoke / VFX | 28.8 (~0) | 116.4 (~0) | 1 982 (~+2%) | 14.7 (~0) | 346 (−1%) | 1 758 (~0) | 101.3 | 101.3 |
| **small blast (`BLAST_MAX_RING=1`)** | 23.9 (−17%) | 100.2 (−14%) | **294 (−85%)** | 11.8 (−20%) | 294 (−15%) | **176 (−90%)** | 99.7 | 99.1 |
| all off | 17.4 (−40%) | 99.8 (−14%) | 298 (−85%) | 11.6 (−21%) | 298 (−14%) | — | 98.9 | 98.4 |

**Grenade #0** (concrete, no multi-second stall: worst 375 ms in the controls) says the
same with smaller numbers:
- cheap board: wall −37%, mean −47%, PUMP −47%;
- no light: wall −28%;
- small blast: wall −12%, PUMP −20%, COMMIT −14%;
- no soot and no smoke/VFX: within ±4%.

⚠️ **The column the table used to call "SOOT FADE 1st frame" is not soot.** The fade's
beat is marked on the same frame as the presenter's `_commit_frame()`, which writes
~1 800 damaged cells into the TileMapLayers (`set_cell` + alternative minting +
flush; `[E-PRESENT] commit frame — 1783 cell(s) in 74.003 ms of apply`). With
`NO_SOOT=1` the fade and its mark disappear, but that frame still takes 1.77 s — now
under the CONSEQUENCE mark. The remaining ~1.7 s of that frame, beyond the 74 ms of
apply, is its render after those writes. That is inferred from the marks and the
logcat stamps; the split inside the frame is not measured yet (TEL-05). The other
~1.8 s frame of grenade #1 sits INSIDE the PUMP (frame 117 of 127): a cook step that
does not divide and overruns its 14 ms budget. It also disappears with
`BLAST_MAX_RING=1`.

**What it answers:**
1. **The multi-second stalls are the damage footprint written into the 2D board,**
   and they scale far faster than the footprint. `BLAST_MAX_RING=1` roughly halves
   the cells (desktop: 1 915 → 914) and takes grenade #1's worst frame from 1.9 s to
   0.3 s. Grenade #0 writes about as many cells as #1 but stalls ~0.3 s, so the cost
   depends on WHAT is written — which layers and which tile alternatives are new —
   not on the count alone. This is the per-cell-state-in-TileSet-alternatives defect
   `PERFORMANCE_MASTER_PLAN` already names.
2. **Soot and smoke/VFX are not villains on this handset.** Removing them moves no
   stall and at most 4% of the wall clock.
3. **The consequence light is DURATION, not cost.** Its 60-frame beat is 22–28% of
   the event; no frame gets cheaper without it. It is a look constant
   (`consequence_light_seconds`), not an optimisation.
4. **The board paces everything else.** The cheap board cuts the pre-cook 43–47% and
   the long beats ~50%. With every blast knob off, the event's mean frame is still
   ~90–100 ms, because the board idles at 60 ms (§10.18.1).
5. **"Standardised explosions" would help only by writing fewer cells.** The lever
   is the footprint (ring, damage volume) and how a write reaches the renderer —
   not the arithmetic that plans it.

### 15.6 ✅ DIAG-20 MEASURED — the same board in 3D costs 2.2–7.5× less on the Moto, and is not free

Moto g04s, 2026-09-14 19:01–19:05, APK from commit `7c0ec152`, `SPIKE=board3d`.
- Log (local): `docs/measurements/device_2026-09-14_moto_g04s_diag20_spike3d.log` —
  185 records, 0 dropped.
- Captures (local): `Screenshots/spike3d_2026-09-14/`.
- **Both modes put 95 GUs on screen at zoom 0.5, the 2D board's own count**, so the
  world area matches.

| zoom | 2D board, world 1.0 (§10.17.2): ms · gpu · cpu | 3D `voxel` — 73 024 faces, 135 296 primitives, 6–7 draws | 3D `merged` — 160 faces |
|---|---|---|---|
| 0.50 | 60.0 · 58.6 · 6.5 | **27.6** · 26.1 · 0.4 | **22.3** · 20.8 · 0.4 |
| 0.42 | 70.3 · 69.0 · 9.1 | 29.3 · 28.0 · 0.4 | 22.2 · 20.6 · 0.4 |
| 0.35 | 89.2 · 87.7 · 14.0 | 30.5 · 29.2 · 0.4 | 22.2 · 20.7 · 0.4 |
| 0.30 | 107.6 · 106.2 · 22.7 | 30.7 · 29.4 · 0.4 | 20.9 · 19.4 · 0.4 |
| 0.25 | 125.2 · 123.4 · 31.5 | 29.8 · 28.4 · 0.4 | 19.9 · 18.4 · 0.4 |
| 0.20 | 135.1 · 132.9 · 39.4 | 27.9 · 26.5 · 0.5 | 17.9 · 16.5 · 0.4 |

**What it says:**
- **The representation is a major anchor.** The same board costs 2.2× (the voxel
  worst case) to 2.7× (merged) less at the default zoom, and 4.8–7.5× less at the
  pinch floor. `render cpu` is 0.4 ms against 6.5–39.4. In 3D the cost barely
  moves with zoom, so the zoom-out penalty behind §13 Q6 disappears.
- **It is not free on this GPU.** 160 lit, textured faces still take ~20 ms of GPU
  at 720×1612 — the fill of a per-pixel lit, textured full screen. The 135 000
  extra primitives of the voxel mode add only 5–8 ms. ⚠️ The merged ms/frame
  (22.2) sits on the 90 Hz grid, two intervals; `render gpu` is the cost column.
- **What the spike leaves out would sit on top of ~22–28 ms:** actors, HUD, fog,
  the 12-bucket light, soot, decals, destruction. So 3D is not a finished answer to
  the 33.3 ms budget. A production 3D path would have to price its lighting and its
  materials; the spike used a stock lit material with mipmapped facades.
- **Destruction in 3D would be chunk remeshing.** The spike's only data point: the
  whole board's 73 024 faces built in **1 956 ms in GDScript on the Moto** (139 ms
  for the merged board). A remesh scales with the chunk, not the board; the cost
  per chunk is not measured.

**The decision rule (§15.3, written before measuring):** ≤ ~15 ms means the
representation is the anchor; ≥ ~35 ms means it is not the villain; in between,
report both numbers and decide together. **Outcome: in between.** 22.3 ms (best
case) and 27.6 ms (worst case) at the default zoom — both inside the 33.3 ms budget,
where the 2D board idles at 60 ms. Per the rule, it goes to the Director.

**The options, and what each still has to prove.** The decision belongs to
`PERFORMANCE_MASTER_PLAN`.
- **(a) Stay 2D and attack the costs §15.5 named:** the damage-footprint stalls
  (cell writes and tile alternatives) and the per-frame board (layers, shader).
  §10.17–§10.18 put the default zoom at 60 ms and hold the zoom floor at 0.5; how
  far 2D can go is not measured.
- **(b) A 3D render layer inside Godot that keeps the game logic** (turns, TIC, AI,
  maps, prediction, telemetry). The board measured 22–28 ms before the rest of the
  look. The next spikes would price, on the Moto: the lighting model, actors, and a
  chunk remesh after a blast.
- **(c) Unity or Unreal.** Nothing measured here says the engine is the limit:
  Godot's own 3D path already shows the representation gain. A migration adds a
  full code rewrite on top of the same 3D work.

### 15.7 ✅ DIAG-21 step 1 MEASURED — the LIVE board in 3D: 60 → 18 ms at the default zoom, flat with zoom

**Director, 2026-09-14:** *"Certo vamos então fazer isso e montar o protótipo em 3D. Mas
aí no caso a gente continuaria usando voxels (reais), e mantendo toda a arquitetura do
baking system?"* — answered in the same session.
- **The simulation layer stays as it is.** Edge, Slice, Slab, Voxel, the registries,
  `JunctionResolver`, the glass physics, the damage tables, `VoxelLightField`,
  prediction, TIC, turns and AI hold no `TileMapLayer` / `set_cell` / atlas reference
  — checked file by file.
- **The bake keeps its logic, loses its atlas.** `TextureResolver`, `MaterialRegistry`
  and `FacadeSampler`'s FNV-1a window origins carry over; the pre-projected isometric
  atoms do not, because a 3D face has UVs.
- **The 2D drawing layer is what is replaced:** `VoxelRenderer` and the detonation
  writer.
- **The real refactor is the detonation plan.** Its entries carry
  `source_id` / `atlas_coords` / `alt` and read live layer cells; it has to become
  render-neutral.
- Canon rules 2, 8, part of 9 and B1/B3/B5 are 2D-drawing rules. They retire only at
  parity, on the Director's ratification.

**What was built** — commits `76658423`, `ae8440cf`, `625b8158`. `RENDER3D=1`
(`godot/scripts/spikes/board3d_live.gd`): after a real map load, depth-tested meshes
of the game's own data replace the drawing of the 2D voxel board, which is hidden,
not removed. Actors, fog, overlays and HUD still draw in 2D on top.
- **Data:** every visible Voxel of every Slice (`material_at`), every junction
  column, every floor, deep-floor and roof Slab — 215 432 voxels on PLAYGROUND
  (the 2D board holds 151 240 cells).
- **Faces:** the three the camera can see (top, SE, SW); a glass neighbour does not
  hide an opaque face.
- **Look:** the 2D face shader's own terms per face, read live — bucket luminance ×
  face tone × per-face soot × floor depth dim — as vertex colour; material =
  base colour × facade luminance. The maths is done in sRGB and the product is
  decoded once.
- **Meshing:** greedy merge of coplanar faces with the same material and colour, per
  32×32-voxel chunk → 1 617 quads in 72 chunks. On the Moto: collect 2.4 s + mesh
  2.2 s, at load only.
- **Camera:** follows the 2D camera every frame through an affine map of GU centres
  measured from Room, so sprites and board stay aligned on the ground plane.

**The table** — Moto g04s, portrait 720×1612, same binary (APK `cfd967c2…`), same
ladder, both runs re-centred on the agent at every stop. Cells on screen match at
every stop (95 / 115 / 173 / 235 / 354); no stop touched; 0 dropped lines.
Logs (local): `docs/measurements/device_2026-09-14_moto_g04s_diag21b_r3d_on.log`,
`…_diag21b_r3d_off_control.log`.

| zoom | 2D board: ms · gpu · cpu · draws | **3D board + 2D on top: ms · gpu · cpu · draws** |
|---|---|---|
| 0.50 | 60.0 · 58.5 · 6.6 · 1 641 | **17.9 · 16.3 · 2.2 · 225** |
| 0.42 | 70.3 · 68.8 · 9.0 · 3 091 | **18.1 · 16.5 · 2.3 · 263** |
| 0.35 | 89.0 · 87.5 · 14.0 · 5 603 | **17.9 · 16.3 · 2.3 · 267** |
| 0.30 | 107.5 · 106.1 · 22.6 · 10 531 | **18.1 · 16.4 · 2.3 · 270** |
| 0.20 | 134.5 · 133.0 · 39.4 · 20 670 | **17.1 · 15.6 · 2.4 · 285** |

**What it says:**
- **The idle game frame is inside the 33.3 ms budget at every zoom in 3D** — 3.4× cheaper
  than 2D at the default zoom, 7.9× at the pinch floor. The zoom-out penalty behind §13 Q6
  is gone: the frame is flat from 0.5 to 0.2.
- **This is the real game frame, not a board in isolation:** actors, fog, cones,
  movement overlay and HUD are all drawn. DIAG-20's lit, board-only spike cost 20.8 ms of
  GPU; the unshaded vertex-colour board with the whole 2D game on top costs 16.3.
- ⚠️ **The first ladder was contaminated, and TEL-02 caught it.** Three drags inside the
  zoom 0.5 stop moved the camera off the agent for the rest of that run; its later stops
  read fewer cells on screen than the control, and its closing capture framed the wrong
  area. `bench_analyze.py` now flags such a segment (`625b8158`). That run also predates
  the sRGB decode, and read 14.5 ms of GPU at zoom 0.5 against the clean run's 16.3. The
  +1.8 ms coincides with the per-fragment decode, but the two runs also differed in view,
  so the cost is not isolated. A cheaper form exists if it matters: linearise vertex and
  base colour on the CPU and let the sampler decode the facade. That is exact only under
  a pure power law.

**The look** — paired Moto screencaps (local): `Screenshots/diag21b_2026-09-14/pair_z050.png`,
`pair_glass.png`.
- **Matches 2D:** light falloff, floor zones, brick and wood, framing, and the agent on
  its selection diamond.
- **Differs:**
  - no per-voxel atom detail — the 2D floor shows its 8×8 grid per GU, the 3D floor is
    the smooth facade;
  - glass is a pale tint where 2D glass is a strong blue with facets;
  - a 2D overlay the voxel floor used to cover (a dark diamond under the agent) now
    shows;
  - actors are not occluded by walls;
  - no damage decals;
  - facade continuity is world-space, not per wall run.

**Not measured, and why:** memory. In `RENDER3D` mode the 2D board is still built
underneath (PSS ~2.2–2.3 GB in both runs), so no memory figure means anything until a 3D
path skips the tile placement.

### 15.8 Proposed next steps for the 3D track

1. **Remesh on detonation** — the question DIAG-19 left: after `WorldDelta.commit()`, mark
   the chunks holding `touched_voxels` dirty and rebuild only those, with the light and
   soot the cook already produced. Measure the commit frame and the whole event on the
   Moto against DIAG-19's 1.9 s stalls and 28.8 s wall clock.
2. **Actors and occlusion** — sprites as depth-tested billboards, so walls cover them
   (D35/D44 untouched).
3. **Look gaps** — glass, atom detail and decals, each priced as it lands.
4. **The render-neutral detonation plan** — entries as voxel + damage state + light
   bucket + soot code; each renderer resolves its own representation.
5. **Memory** — a 3D path that skips the 2D tile placement, measured against the 2.2 GB
   board.

### 15.9 ✅ DIAG-21 step 2 MEASURED — remesh on detonation: the event halves, and the remesh is the new stall

**Director, 2026-09-14:** *"Vamos seguir."* (§15.8 item 1)

**What was built** (commit `1db0efc0`). The presenter tells the 3D board when the 2D
board changes, on three beats:
- **commit frame:** every touched voxel's visibility is folded into the occupancy,
  with its material read through its container. Its chunk is rebuilt, plus the
  −X/−Z neighbour chunk where an emptied boundary cell exposes a face;
- **soot settled:** the same chunks, recoloured;
- **consequence light:** those chunks plus every chunk holding a light-changed cell.

Face light and soot come from the renderer's cell plane, the state the 2D board shows
at that instant: the cooked light is applied there, not to `Room._voxel_light_field`.
⚠️ **The hidden 2D board still does all its writes.** The 3D rows pay for them *and*
for the remesh.

**The matrix** — Moto g04s, APK `c4d3be35…`, portrait zoom 0.5, blast on screen, two
detonations per boot. Rows interleaved 2D, 3D, 2D, 3D so thermal drift cannot favour
a side; no segment touched. Logs (local):
`docs/measurements/device_2026-09-14_moto_g04s_diag21s2_*.log`.

| | 2D, runs a / b | **3D + remesh, runs a / b** |
|---|---|---|
| grenade #0 · wall clock | 23.2 / 23.3 s | **11.0 / 11.3 s** |
| #0 · mean frame | 90.8 / 92.5 ms | **25.1 / 25.5 ms** |
| #0 · worst frame | 315 / 322 ms | ⚠️ 428 / 504 ms |
| #0 · pre-cook (PUMP) | 130 f · 11.5 / 11.4 s | **131–133 f · 3.8 / 4.0 s** |
| grenade #1 · wall clock | 28.3 / 29.0 s | **12.2 / 12.2 s** |
| #1 · mean frame | 115.7 / 116.1 ms | **28.3 / 28.2 ms** |
| #1 · worst frame | 1 811 / 1 857 ms | **961 / 989 ms** |
| CONSEQUENCE · LIGHT | 91–103 · 90–102 ms/f | **20.6–21.2 · 20.5–21.6 ms/f** |

`[BOARD3D] remesh`, every 3D run — commit / soot / light:
- grenade #0 (5 chunks): 227–289 / 239–249 / 241 ms;
- grenade #1 (6 chunks): 238–254 / 238–239 / 235–238 ms.

The two 3D runs' closing captures are pixel-identical: the path is deterministic.

**What it says:**
- **The whole event is 2.1–2.4× shorter and the mean frame 3.6–4.1× cheaper.** The
  pre-cook runs the same ~130 frames at the same 14 ms budget, but those frames now
  cost ~30 ms instead of ~90: 11.5 s becomes 3.9 s. The consequence and light beats
  sit at ~21 ms per frame, inside the budget.
- **The remesh is the new single-frame stall.** Each rebuild of 5–6 chunks in GDScript
  costs ~240 ms on the Moto, three times per blast.
  - On grenade #0 that made the worst frame *worse*: 315 → 428–504 ms. The commit
    remesh lands on the same frame as the hidden 2D commit apply (151 ms).
  - On grenade #1 the old 1.8 s frame fell to ~0.97 s. The hidden 2D TileSet
    rebuild is still in it.
- **The look matches.** Paired Moto captures (local):
  `Screenshots/diag21s2_2026-09-14/pair_after0.png`, `pair_after1.png`. The crater
  shape, the scorch and the holes in the metal block's wall match 2D.
  - **Gaps:** no per-voxel rubble detail (decals), a 2D overlay line the voxel floor
    used to cover now shows, and some roof top faces read dark in 3D where 2D reads
    them lit. That last one was already visible in step 1's desktop captures;
    unexplained.

### 15.10 Proposed next — take the two remaining stalls out, in order of certainty

1. **Recolour without rebuilding.** The soot and light beats change no geometry. Give
   each quad's colour a slot the board can rewrite in place (vertex colours on the
   existing arrays, or a per-chunk colour texture), so two of the three ~240 ms remeshes
   become a colour upload.
2. **Make the one real remesh cheap and non-blocking:** build the chunk's arrays on a
   `WorkerThreadPool` task from a snapshot of the occupancy, and swap the mesh in on the
   main thread when it lands. Smaller chunks (16×16 voxels) cut the work per rebuild 4×
   either way.
3. **Skip the hidden 2D writes (instrument first).** `SKIP_2D_BOARD_WRITES=1` keeps the
   cell-plane image writes the 3D colours read from, and skips `set_cell` / `erase_cell`,
   tile-alternative minting, the soot texture upload and the glass refreshes.
   - ⚠️ A second detonation's cook reads live layer cells for render information, so
     near an earlier crater that read would be stale. The damage itself comes from the
     voxels. The two dev grenades are 5 GU apart; the overlap is small and must be
     stated with any number.
4. Then re-run this matrix. The target is a worst detonation frame under 100 ms.

### 15.11 ✅ DIAG-21 step 2c MEASURED — per-cell colour and skipped 2D writes: the commit is no longer the worst frame

**Director, 2026-09-14:** *"Vamos seguir"* (§15.10 items 1–3). Commit `15ed5890`.

**What changed.**
- **Light and soot per cell.** The 3D board reads light and soot from a
  `Texture2DArray` of the 2D renderer's own RG8 cell planes, one layer per level. The
  fragment finds its voxel from its world position.
- **Material-only merging.** Faces merge by material alone: 1 617 → 367 quads. The
  soot and light beats became layer uploads.
- **`SKIP_2D_BOARD_WRITES=1`, an instrument, only with `RENDER3D=1`.** It keeps the
  cell-plane image writes and skips `set_cell`/`erase_cell`, alternative minting,
  texture uploads and the glass refreshes.
- **Desktop gates:** lint 0 errors, 55 selftests clean. The default 2D path is
  untouched.

**The matrix** — Moto g04s, APK `633c7c38…`, portrait zoom 0.5, two detonations per
boot. Six boots interleaved 2D / 3D / 3D+skip, twice; no segment touched. Logs (local):
`docs/measurements/device_2026-09-14_moto_g04s_diag21c_*.log`.

| | 2D (a / b) | 3D (a / b) | **3D + skip 2D writes (a / b)** |
|---|---|---|---|
| #0 · wall clock | 23.1 / 23.0 s | 11.2 / 11.3 s | **11.7 / 11.3 s** |
| #0 · mean · worst | 90.5 / 90.7 · 318 / 317 ms | 28.4 / 28.7 · 333 / 342 ms | **28.7 / 28.3 · 419 / 313 ms** |
| #1 · wall clock | 28.5 / 28.4 s | 12.8 / 12.5 s | **11.8 / 11.9 s** |
| #1 · mean · worst | 116 / 116 · 1 800 / 1 805 ms | 32.7 / 32.4 · 911 / 904 ms | **30.7 / 30.8 · 825 / 781 ms** |
| #1 · where the worst frame is | soot-fade frame (2D rebuild) | soot-fade frame | **inside PUMP — one cook step** |
| #1 · commit frame · first soot-fade frame | 346 · 1 762 ms | 278 · 911 ms | **262–277 · 202–220 ms** |
| CONSEQUENCE · LIGHT | ~91–103 ms/f | ~25 · 25 ms/f | ~25 · 24 ms/f |

`[BOARD3D]` on the Moto, every 3D run:
- **commit remesh 118–146 ms** (faces 84–103 · merge 28–30 · upload 2–11), down from
  227–289 ms in step 2;
- **each recolour 10–22 ms** for 18 levels;
- commit apply 65–153 ms in 3D and 24–41 ms with the skip.

**What it says:**
- **The hidden 2D board's writes cost ~700 ms on grenade #1's soot-fade frame**
  (911 → 202–220 ms with the skip). That is the 2D TileSet rebuild; no 3D work is in it.
- **With the 2D writes gone, the detonation's worst frame is not the render anymore.** On
  grenade #1 it is a single step of the prediction cook inside PUMP (781–825 ms) — the
  non-divisible step DIAG-19 already saw at ~1.8 s in 2D. The commit frame is now
  262–277 ms: remesh ~125 ms + apply ~30 ms + recolour ~15 ms.
- **The picture is unchanged by the skip on this pair:** 3D and 3D+skip captures after
  grenade #1 are pixel-identical, and run A equals run B. The stale 2D layers the second
  cook read did not change the damage. Paired capture (local):
  `Screenshots/diag21c_2026-09-14/pair_skip_after1.png`.
- ⚠️ **Consequence frames cost ~25 ms against step 2's ~21.** That is the price of the
  per-fragment plane fetch — inside budget, and not isolated further.

### 15.12 Proposed next — the three stalls left, each already named

1. **The cook step (781–825 ms).** Route `PREDICTION_PROFILE` through `DevFlags`. It
   prints `[P-SLICE] worst step … (phase X)` and is env-only today, so it is inert on the
   APK. Then subdivide or pre-compute the phase it names. This is
   `PREDICTION_MASTER_PLAN` territory: the pipeline is resumable by design, one of its
   phases is not.
2. **The commit remesh (~125 ms).** Build the chunk arrays on a `WorkerThreadPool` task
   from a snapshot and swap the mesh in when it lands. The main thread then pays only the
   upload, ~2 ms.
3. **The recolour upload (10–22 ms).** Upload only the rows a blast touched, or keep the
   plane for the playable levels in one smaller texture.
4. **The decision this all feeds** (`PERFORMANCE_MASTER_PLAN`). The 3D numbers
   above still run the full 2D bookkeeping except where the instrument skips it. A real 3D
   render path retires the 2D board's writes, and with them canon rule 8, B1/B3/B5 and the
   detonation plan's tile-shaped entries (§15.7). That is the Director's call, and these
   tables are its evidence.

### 15.13 ✅ DIAG-22 MEASURED — the cook stall was one TileSet mutation, and it is gone

**The question (§15.12 item 1):** grenade #1's worst frame on the Moto sat inside the
prediction cook, but no step of the cook was that long.

**DIAG-22 — the per-phase profile on the APK** (`PREDICTION_PROFILE` through DevFlags,
commit `84bd063f`, APK `1388e819…`, boots p1–p3). Grenade #1's worst frame is **always
cook frame 117**: 1 866 ms in 2D, 682–709 ms in 3D with the 2D writes skipped. Its
worst STEP is LIGHT at 234–305 ms, and the other late phases' worst visits are SOOT
200 ms and PACKAGE 98 ms. So most of that frame is paid outside `job.step()`.

Two suspects fell on the logs, not on reasoning:
- **The warm-up (`_warm_prediction`) is not in this path.** The scenario's pump is
  interrupted at `blast.start` (`PUMP ends` at f0), so the warm never runs and the
  126 frames that follow are the cook loop in `_start_detonation_sequence`.
- **The `[BAKE] Disk cache HIT` lines are boot**, 40 s before `detonate 0`.

**DIAG-22b — the trace that names it (desktop).** `THROW_PROFILE` now reaches the APK,
and the cook loop prints `[T-COOK]` for every slow frame, with the step's phases and what
the step did to the shared TileSet: composites stored, composite pages, light
alternatives. On grenade #1 one PACKAGE step stores **ONE** damage composite, in 14.8 ms.
`DamageCompositeCache.store()` then calls `create_tile()` on a source that is already in
the TileSet — a TileSet mutation — and the frame that follows rebuilds every TileMapLayer,
hidden ones included. That frame: **217.8 ms in 2D, 86.3 ms in 3D+skip**. Grenade #0
stores none and has no slow cook frame.

**The fix:** `register_damage_composite_page()` creates every slot's tile (3 584 on a
2048² page) BEFORE the source joins the TileSet, so a later `store()` only blits
pixels. `COMPOSITE_TILES_UP_FRONT=0` is the old lazy path, kept so one APK measures
both sides. `damage_composite_cache_selftest` [8] pins the property against a control:
the lazy path's store changes the TileSet 2 times, the up-front store 0 times.

**DIAG-22c — the matrix.** Moto g04s, APK `09803093…`, portrait zoom 0.5, two
detonations per boot, five boots interleaved. Logs (local):
`docs/measurements/device_2026-09-14_moto_g04s_diag22c_*.log`.

| grenade #1 | 3D+skip · up front (a / b) | 3D+skip · lazy | 2D · up front | 2D · lazy |
|---|---|---|---|---|
| the cook frame that stores the composite | **96.6 / 114.5 ms** | 809.1 ms | **189.0 ms** | 1 733.5 ms |
| … of it outside the step | 17.5 / 16.6 ms | 711.3 ms | 30.1 ms | 1 586.5 ms |
| worst cook frame | 250.1 / 248.0 ms | 821.9 ms | 288.5 ms | 1 800.1 ms |
| worst frame of the event | 265.3 / 278.9 ms | 821.9 ms | 1 812.9 ms (f134) | 1 800.1 ms |
| wall clock | 11.1 / 11.2 s | 12.0 s | 26.8 s | 28.6 s |

- **Grenade #0 stores no composite** and is unchanged: its worst frame is the LIGHT step,
  239–408 ms in every row.
- **Load cost:** the 3 584 tiles take **740–743 ms** on the Moto (168 ms on desktop),
  once, inside a 15.3 s bake.

**What it says:**
- **The lazy tile was the whole cook stall:** ~700 ms with the 2D board hidden, ~1.6 s with
  it drawn. In 3D+skip, grenade #1's worst frame drops **822 → 265–279 ms (−66%)**.
- **In 2D the event's worst frame does not move** (1 800 → 1 813 ms). The cook stall is
  gone, but the post-cook 2D rebuild on the soot-fade frame (§15.11) was always the same
  size, and it is now the worst frame. That is the 2D board, which §15.11 already priced.
- **A cook frame that stores nothing still costs ~15 ms outside its step in 3D+skip and
  ~30 ms in 2D.** That is the render, not the cook.
- ⚠️ **The fix covers one page.** PLAYGROUND loads 447 atoms into 3 584 slots. A map whose
  blasts overflow into a second page would still add a source mid-game, and that is a
  TileSet mutation. Nothing measured reaches it.

### 15.14 Proposed next — what remains in the detonation, in order of size

1. **The LIGHT step of the cook (234–408 ms, both grenades).** It is not divisible, and
   it rebuilds occupancy map-wide per blast (`voxel_renderer.build_occupancy(predict_destroyed)`).
   `VoxelLightField` reads occupancy only through `.has(cell)`, in `surface_factor`,
   `_face_occlusion` and `_stale_cells`. So a cached occupancy with an overlay of the
   predicted-destroyed cells answers the same questions without the rebuild. This is
   `PREDICTION_MASTER_PLAN` territory.
2. **The commit frame in 3D (~265–280 ms):** remesh ~125 ms off-thread (§15.12 item 2),
   then the recolour uploads (item 3).
3. **The decision (§15.12 item 4)** is unchanged and is the Director's.

### 15.15 ✅ DIAG-23 MEASURED — memory: the 3D path is about half, and the half it saves is the bake atlas

**Director, 2026-09-14:** *"Vamos seguir com a comparação 2D x 3D"*, then chose the
memory axis — the one axis with no number (§15.7: in `RENDER3D` mode the 2D board is still
built underneath, so both runs read ~2.2 GB).

**Why the instrument is not a 3D-only load.** Skipping 2D placement at the source is not
possible yet, for two reasons read in the code:
- the load-time light apply (`_apply_light_to_layer`) writes the cell planes the 3D board
  reads its light and soot from, but only for cells present in a layer
  (`layer.get_used_cells()`);
- the detonation plan skips a cell whose `source_id` is −1.

**So the measurement is split in two, inside one process each** (commit `b6b0b17c`):
- **The atlas** is removed at the source with the existing `NO_BAKE` flag. The 3D board
  never read the bake: it samples the facades through `TextureResolver`.
- **The cells:** a scenario step, `drop2d` (`Room.scenario_drop_2d_board()` →
  `VoxelRenderer.debug_drop_board_cells()`), clears every opaque and glass layer and the
  structure layer, 105 s into idle. It keeps the floor layer, which selection, the
  movement overlay and `ViewContext` read, and it keeps the layer nodes, the TileSet, the
  planes and `_placed_index`.
- What `drop2d` frees is therefore a lower bound on the cells' cost, and the process after
  it is an **upper bound** on a 3D-only one.

Desktop, before the phone: 205 704 opaque + 2 240 glass cells cleared in 12 ms. The
captures before and after the drop differ by 0 px, and the capture shows the whole board
drawn. Without `RENDER3D` the step errors and the scenario aborts.

**The matrix** — Moto g04s, APK `d137542f…`, portrait zoom 0.5, nothing detonated.
- Six boots interleaved 2D / 2D `NO_BAKE` / 3D `NO_BAKE` + `drop2d`, twice.
- `device_run.py --mem-poll 5`. `bench_analyze.py` now tabulates the polls per scenario
  segment.
- Values are medians of 8–15 polls per segment; MB = kB / 1024.
- Logs (local): `docs/measurements/device_2026-09-14_moto_g04s_diag23_*.log`.

| runs a / b | 2D, bake ON (shipped look) | 2D, `NO_BAKE` | 3D `NO_BAKE`, 2D board hidden | **3D `NO_BAKE`, 2D board dropped** |
|---|---|---|---|---|
| TOTAL PSS | 2 201 / 2 171 | 1 107 / 1 101 | 1 090 / 1 089 | **1 099 / 1 036** |
| GL mtrack | 734 / 734 | 318 / 318 | 272 / 272 | **277 / 272** |
| swap PSS | **721 / 1 395** | 0 / 0 | 0 / 0 | **0 / 0** |
| native heap alloc · free | 1 413 · 78 | 705 · 91 | 748 · 77 | **689 · 135** |
| TileSet (`MEM_CENSUS`) | 135 sources · 36 178 tiles | 98 · 98 | 98 · 98 | 98 · 98 |
| boot → map loaded | 54.0 / 52.2 s | 19.1 / 19.6 s | 22.9 / 22.8 s | — |
| idle frame · render gpu · draws | 60.0 · 58.6 · 1 641 | 76.0 · 74.5 · 11 308 | 22.9 · 21.5 · 225 | 22.9 · 21.5 · 225 |

`drop2d` took 106–111 ms on the Moto. The closing captures are pixel-identical run a vs
run b in both `NO_BAKE` rows, and differ by 13 px in the baked 2D row. A paired capture of
the three looks (local): `Screenshots/diag23_2026-09-14/pair_memory_rows.png`.

**What it says:**
- **At the look the game ships, 2D costs 2.17–2.20 GB with 0.7–1.4 GB of it swapped out;
  the 3D path costs at most 1.04–1.10 GB with nothing swapped.** That is about half, and
  §10.7.2's mechanism — the board evicted at idle and faulted back in by the blast — is
  absent from the 3D rows.
- **The saving is the atlas, not the representation.** Removing the bake takes 2D from
  2.17–2.20 GB to 1.10 GB (graphics −416 MB, native heap −708 MB, TileSet 36 178 → 98
  tiles). Dropping 207 944 cells then frees **59 MB of native heap in both runs and no
  graphics memory at all**.
- **2D cannot take that saving at the same look.** In the paired capture, 2D without its
  atlas draws the concrete floor as a generic brown checker; 3D without it draws the
  concrete facade. The atlas exists because the 2D look is pre-projected isometric atoms,
  and a 3D face reads the same facade through its UVs. §10.9 had already priced the bake
  as a trade — ~1 GB for blast speed. In 3D it stops being a trade, because the 3D path
  has no atlas to hold.
- **The bake is also a draw-call saving in 2D:** without it the idle board issues 11 308
  draws instead of 1 641, and the frame costs 76 ms instead of 60.
- **The 3D board's own footprint is small.** Against 2D `NO_BAKE` it has 46 MB less
  graphics memory and 43 MB more native heap.
  - The graphics difference is between drawing the 2D board and not drawing it: dropping
    its cells moved no graphics memory, so holding them costs none. Which buffers, not
    measured.
  - The native heap includes the prototype's GDScript dictionaries (215 432 entries), so
    it is not production-shaped.

**Caveats, stated with the numbers:**
- ⚠️ **An upper bound, and retention is visible.** The 59 MB freed stayed in the native
  heap as free space in both runs (77 → 135 MB). PSS fell 54 MB in run b and not in run a.
- ⚠️ **The peak at load is not measured.** The drop runs after the load.
- **Neither side is production-shaped.**
  - The 3D rows still carry the 2D renderer's bookkeeping and empty layer nodes.
  - A 3D path with decals or per-voxel atom detail would add texture memory this row
    does not hold.
  - The look gaps of §15.7 are unchanged.
- **Both sides share a floor of ~1.1 GB**, with ~690–705 MB of native heap and no atlas.
  It is not decomposed.
- **The 3D idle frame reads 22.9 ms here, against §15.7's 17.9.** The difference coincides
  with step 2c's per-fragment plane fetch (§15.11) and is not isolated.

**Two harness defects surfaced by this run, both fixed** (commit `e588cdb8`):
- **`device_run.py` sorted the saved log on the HH:MM:SS string.** Run a of the 3D row
  booted at 23:59:56, so its boot, session header and first poll were written at the end
  of the file, inside the last segment. The key is now seconds of the day and handles
  midnight.
  - Red-before-green on that log: the old key puts the boot at line 637, after "map
    loaded" at line 141; the fixed key puts it at line 16, before line 215.
  - That log was re-sorted with the fixed key.
- **The poll taken after `quit` read a process tearing down**, 72 MB below idle in run a
  of the baked 2D row. `bench_analyze` now closes the memory segment at `scenario.end`.
  - ⚠️ The host and device clocks differ by ~1 s, so in two rows one teardown poll still
    sorts inside the last segment. It moves those segments' *last* value, never the
    median quoted above.

### 15.16 Proposed next

1. **The decision (§15.12 item 4) now has its memory row.** At the shipped look, 2D needs
   an atlas that the 3D path does not.
2. **A clean 3D-only number, if one is wanted, is the refactor itself:**
   - the light apply writes the planes from the registries instead of from layer cells;
   - the detonation plan stops reading layer cells (§15.8 item 4);
   - load then never places a 2D cell, and the peak at load becomes measurable.
3. **The shared ~1.1 GB floor:** §10.7's boot decomposition (`MEM_STAGES` + `--mem-poll`)
   on a `NO_BAKE` boot, now that the atlas no longer hides it. ⚠️ Candidates are not
   named here.
4. **The Galaxy A16 5G (3.37 GB):** the same six boots, to see whether 1.1 GB changes its
   swap behaviour. §10.8 measured it swapping 1.42 GB at idle.
5. **Memory growth per detonation in 3D** is not measurable with this instrument, because
   the plan reads 2D cells. It waits for item 2.

### 15.17 ✅ The decision — the board moves to Godot 3D, over a packed voxel store (2026-09-15)

**Director, 2026-09-15**, after §15.15: *"Me parece que o 3D é o caminho mais efetivo. E aí
nesse caso, precisamos reconfirmar a arquitetura. Não seria melhor fazer as paredes maciças
com fachadas inteiras, e somente substituir zonas menores por voxels conforme elas ficam
sujas?"* Shown the two measurements below, the Director answered: *"Certo então vamos fazer
isso. Faça o planejamento de todas as etapas e deixe documentado."*

**Measured to answer the question** — desktop debug build, a scratch script, two identical
runs:
- 215 432 real `Voxel.new()` objects, held in arrays of 64 the way `Slice` and `Slab` hold
  them, raise `OS.get_static_memory_usage()` by **316.4 MB — about 1 540 bytes per voxel**.
- The same count as a `PackedInt32Array` raises it by 0.8 MB, which is exactly the array's
  size, so the instrument calibrates itself.
- ⚠️ This is not yet measured on the Moto. A release build on ARM can differ, and measuring
  it is `RENDER3D` R3D-0.

**Read from the logs already on disk:**
- The 3D board merges PLAYGROUND's 108 772 visible faces into **367 quads**. After grenade
  #1 the 5 touched chunks hold 350.
- So an intact wall is already one facade quad, and voxel granularity appears only around
  damage. Soot and light need no geometry (§15.11).

**What was ratified:**
- **The render half of the proposal** — whole facades, with detail spent near damage — as
  the 3D board already draws it.
- **For the data half, a packed store instead of materialised zones.** It keeps one
  representation, prediction stays per voxel, and floors and roofs account for 145 992 of
  the 215 432 voxels.
  - ⚠️ Corrected by R3D-0 (§15.18): 215 432 is the prototype's count of distinct CELLS.
    PLAYGROUND holds **216 104 voxels**, because 672 corner cells are claimed by two
    slices.

**The plan:** [`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md), R3D-0 → R3D-END.
- This plan stays its measurement harness.
- §15.14 item 1 (the cook's LIGHT step) folds into R3D-2.
- §15.14 item 2 (the 3D commit frame) folds into R3D-3.

### 15.18 ✅ RENDER3D R3D-0 MEASURED — the baseline on one APK, and what a `Voxel` costs on the Moto

**Why.** `RENDER3D_MASTER_PLAN` R3D-0: nothing moves until the gates that judge the moves
exist. This section is the device half. The desktop half — `BoardProbe` and its identity
gate — is recorded in the plan itself.

**The APK.** Commit `5988234f`, `export/Infiltraitor.apk` sha256 `fb867845…`. It passed
`export_android.py --verify-only`: signed, no source textures, 7 map JSON, 2 CSV, the
project renderer.
- Moto g04s, portrait, world render scale 1.0, `RNG_SEED=1`.
- 16 boots, interleaved a / b.
- Logs (local): `docs/measurements/device_2026-09-15_moto_g04s_r3d0_*.log`.
- Captures (local): `Screenshots/r3d0_2026-09-15/`. All 16 boots exited cleanly.

#### 15.18.1 The `Voxel` object cost — ~925 B on the Moto, not ~1 540

**Instrument:** the scenario step `alloc objects|packed|bytes <count>`.
- It holds N `Voxel` objects in arrays of 64 (the way `Slice` and `Slab` hold them), the
  same count as a `PackedInt32Array`, or N bytes.
- It holds them until `quit`, with `device_run.py --mem-poll 5`, one allocation per
  segment.
- `bytes` is the **positive control**. `packed`'s 0.8 MB sits inside PSS noise, so it can
  only show that the instrument does not invent memory; a known size shows that it sees
  memory at all.

3D `NO_BAKE` (no swap at idle). Medians per segment, MB:

| step · runs a / b | native heap alloc | TOTAL PSS | RSS | swap PSS |
|---|---|---|---|---|
| BASE (idle) | 748 / 748 | 1 094 / 1 088 | 1 160 / 1 164 | 1 / 0 |
| → `alloc packed 215432` (0.82 MB expected) | **+1 / +1** | −2 / +2 | −5 / +2 | +5 / 0 |
| → `alloc objects 215432` | **+190 / +190** | +178 / +181 | +174 / +183 | +3 / 0 |
| → `alloc bytes 200000000` (190.7 MB, the control) | **+191 / +191** | +188 / +189 | +7 / +186 | +178 / 0 |

The allocations took 1 ms (packed), 958 / 987 ms (objects) and 632 / 567 ms (bytes).

**What it says:**
- **A `Voxel` costs ~925 B on the Moto's release build** (190 MB ÷ 215 432 objects,
  ±5 B from the whole-MB medians) — not the ~1 540 B of §15.17's desktop debug build.
  - That figure includes the arrays of 64 that hold the objects, which the real
    containers pay too.
  - **PLAYGROUND's 216 104 voxels cost ~191 MB on the device**, not 316 MB.
- **The instrument is calibrated.**
  - The known 190.7 MB reads +191 MB of heap alloc in both runs, and the 0.82 MB packed
    array reads +1.
  - TOTAL PSS lands within 3 MB of heap alloc for the control and within 12 MB for the
    objects.
- **The native heap alloc column is the reading, not RSS.** In run a the control's
  pages — all one value, so they compress — went to zram (swap +178 MB, RSS +7). In
  run b they stayed in RAM (RSS +186, swap 0). Heap alloc and TOTAL PSS followed the
  allocation both times.
- **R3D-1's saving is smaller than §15.17 estimated, but still large.** On the Moto the
  packed store replaces ~190 MB of objects with ~1 MB of state. That is 3.2× the 59 MB
  the 2D board's cells free (§15.15).
- `OS.get_static_memory_usage()` printed "unavailable (reads 0)" in every step, as
  expected on an Android release build.

#### 15.18.2 Grenades — 2D vs 3D with the 2D writes skipped

Scenario as DIAG-21c / 22c, plus two close-ups after grenade #1 for the R3D-6 look set.

| | 2D a / b | **3D + skip a / b** |
|---|---|---|
| #0 · wall clock | 24.0 / 24.0 s | **10.9 / 10.9 s** |
| #0 · mean · worst | 90.8 / 91.8 · 320 / 408 ms | **27.7 / 28.4 · 257 / 261 ms** |
| #0 · commit frame · first soot-fade frame | 320 / 299 · 289 / 331 ms | **251 / 260 · 202 / 228 ms** |
| #1 · wall clock | 27.1 / 27.2 s | **11.2 / 11.3 s** |
| #1 · mean · worst | 110.0 / 110.5 · 1 922 / 2 024 ms | **29.1 / 29.2 · 280 / 308 ms** |
| #1 · commit frame · first soot-fade frame | 345 / 346 · 1 922 / 2 024 ms | **280 / 262 · 209 / 201 ms** |
| consequence · light (ms/frame) | 90.5–103.1 · 90.1–101.5 | **24.8–26.2 · 23.6–24.8** |

- `[BOARD3D]` commit remesh: grenade #0 folds 460 voxels into 5 chunks and 350 quads in
  113–138 ms; grenade #1 folds 494 voxels into 6 chunks and 414 quads in 123–125 ms.
- **460 is the same count** `BoardProbe`'s desktop control reads for grenade #0: two
  independent instruments agree.
- **Captures, run a vs run b:** 0 px in 6 of 8 pairs. The exceptions are 15 px (2D, after
  #1) and 9 px (3D, after #0), both 3 s after a blast. The cause is not isolated.
- **Every number is within DIAG-21c / 22c's range**, so this is the baseline, not a
  change.
- ⚠️ **Every capture of this scenario carries the `Detonate / Cancel` menu and the dev
  panel** — identically in 2D and 3D and in runs a and b, so the pairs stay comparable.

#### 15.18.3 The idle ladder — one boot each

| zoom | 2D: ms · gpu · cpu · draws | **3D: ms · gpu · cpu · draws** | DIAG-21b 2D / 3D ms |
|---|---|---|---|
| 0.50 | 60.0 · 58.5 · 6.6 · 1 641 | **23.1 · 21.6 · 4.1 · 225** | 60.0 / 17.9 |
| 0.42 | 70.4 · 68.9 · 9.2 · 3 091 | **23.3 · 21.9 · 2.2 · 263** | 70.3 / 18.1 |
| 0.35 | 89.2 · 87.7 · 14.0 · 5 603 | **23.3 · 21.9 · 2.2 · 267** | 89.0 / 17.9 |
| 0.30 | 107.7 · 106.4 · 36.8 · 10 531 | **23.4 · 22.0 · 2.2 · 270** | 107.5 / 18.1 |
| 0.20 | 134.6 · 133.0 · 39.3 · 20 670 | **21.6 · 20.1 · 2.3 · 285** | 134.5 / 17.1 |

- Cells on screen match at every stop (95 / 115 / 173 / 235 / 354).
- **2D repeats DIAG-21b within 0.2 ms.** The one column that moved is render cpu at 0.30:
  36.8 ms against 22.6 ms. It is not isolated.
- **3D sits at 21.6–23.4 ms against 21b's 17.1–18.1.** That is §15.15's 22.9 ms after
  step 2c's per-fragment plane fetch — the current code, not a regression from today.

#### 15.18.4 Memory — as DIAG-23

Scenario and flags as §15.15: portrait zoom 0.5, settle 45 s, idle 60 s, then `drop2d`
in the 3D row, then 75 s. `--mem-poll 5`, medians per segment, MB.

| runs a / b | 2D, bake ON (shipped look) · IDLE | **3D `NO_BAKE` · IDLE → after `drop2d`** | DIAG-23 a / b, same rows |
|---|---|---|---|
| TOTAL PSS | 2 200 / 2 176 | **1 094 / 1 084 → 1 094 / 1 088** | 2 201 / 2 171 · 1 090 / 1 089 → 1 099 / 1 036 |
| GL mtrack | 734 / 734 | **276 / 272 → 272 / 271** | 734 · 272 → 277 / 272 |
| swap PSS | 739 / 1 246 | **0 / 0** | 721 / 1 395 · 0 |
| native heap alloc · free | 1 413 · 79 | **749 / 748 · 77 → 689 · 136** | 1 413 · 78 · 748 · 77 → 689 · 135 |
| boot → map loaded | 53.5 / 52.7 s | **23.0 / 23.0 s** | 54.0 / 52.2 · 22.9 / 22.8 s |
| idle frame · draws | 60.0 ms · 1 641 | **22.9 ms · 225** | 60.0 · 1 641 · 22.9 · 225 |

- `drop2d` cleared 205 704 opaque and 2 240 glass cells in 107 ms (run a).
- **Every row repeats DIAG-23.** At the shipped look, 3D is about half the memory, with
  nothing swapped.
- Dropping the 2D cells frees ~60 MB of native heap in both runs. It stays in the process
  as free heap (77 → 136 MB), and PSS does not move — both as in DIAG-23 run a.
- Swap on the 2D row again varies run to run (739 vs 1 246 MB) while PSS and heap hold.

#### 15.18.5 The R3D-6 reference captures

Paired 2D / 3D captures, same APK, for `RENDER3D` R3D-6. The 3D side of the grenade and
look runs skips the 2D writes; the ladder's 3D side does not. §15.11 showed that the skip
changes no pixel. Files (local): `Screenshots/r3d0_2026-09-15/`.

| R3D-6 item | captures | what the pair shows |
|---|---|---|
| 2 · glass | `r3d0_lad_*_glass`, `r3d0_lad_*_z050`, `r3d0_look_gl_*` (GLASS: idle, the variant row, and after both grenades) | **2D:** a strong blue with facets and a grid; the variant row in saturated purple, green, red and amber; crack and craze art on every cracked pane. **3D:** a pale, translucent cyan; the variant tints washed out; **no crack or craze on any pane**; shattered panes leave pale remnant chunks. |
| 3 · decals | `r3d0_g_*_close_concrete`, `…_close_metal`, `r3d0_look_pg_*_wood_burn_*` | 2D: detailed crack and dent art per voxel. 3D: flat, darker squares. |
| 4 · dents | the same close-ups | Carved voxels have the same extent. 2D insets read as art, and 3D draws no inset. |
| 5 · whole facades | `r3d0_lad_*_z050`, `r3d0_look_pg_*_wood_idle` | The 2D floor shows its 8×8 voxel grid per GU; the 3D floor is the smooth facade. Brick and wood read alike. |
| 6 · soot, burnt voxels | `r3d0_look_pg_*_wood_burn_0/4/12/32` | Same scorched extent. 2D is darker and varies per voxel. |
| R3D-5 rows seen | `r3d0_lad_3d_z050`, `r3d0_look_pg_3ds_roofs` | The dark diamond under the agent, and a red line, show only in 3D. The line is probably a 2D overlay the board used to cover; not identified. It shows on GLASS too (`r3d0_look_gl_3ds_glass_after0`). |

**Two gaps — R3D-0's capture set does not yet cover every item:**
- **Item 1, roof tops dark in 3D, is not isolated.** The `roofs` framing (`centre 13,4`,
  zoom 0.8) shows a wall face and floor. Its 3D side has a dark rhombus over the wall
  that 2D does not, but nothing in the frame identifies it as a roof top.
- **Embers (item 6) were not captured.** `detonate` waits for the blast to finish, and
  the wood burn's first capture already comes after the fire. All four burn frames are
  nearly the same.

**Caveat on every scenario capture:** the `Detonate / Cancel` menu and the dev panel stay
on screen, identically in both renderers and in both runs.

#### 15.18.6 The last two pairs — embers and roof tops (2026-09-16)

**Why.** §15.18.5 left two R3D-6 items without a pair:
- The `detonate` step waits for the blast to end, so the embers were gone before any
  capture.
- The `roofs` framing did not show a roof.

**The instrument.** `capture_at <beat> <offset> <name>` (`RENDER3D` R3D-0, commit
`13562fba`) arms a capture.
- The capture is taken `<offset>` after the Room names a blast beat.
- The offset is counted in frames, or in seconds of process delta — the clock the embers
  age on.

**The APK.**
- Commit `13562fba`, built with `export_android.py --install`. The installed APK's
  sha256 is `c3a1a6d3…`.
- ⚠️ A `--contents` pass after the install re-exported the APK on disk (`5394bbb1…`).
  Its code is the same, but it is not the file on the phone.

**The runs.**
- Moto g04s, portrait, world render scale 1.0, PLAYGROUND, grenade #3 on the wood trio.
- 4 boots, interleaved: 2D a, 3D a, 2D b, 3D b. The 3D boots set
  `SKIP_2D_BOARD_WRITES=1`. All four exited cleanly, with 7 captures each.
- Logs (local): `docs/measurements/device_2026-09-16_moto_g04s_r3d0b_pg_*.log`.
- Captures (local): `Screenshots/r3d0_2026-09-16/`.

The scenario:

```
framing portrait; centre 8,-1; zoom 0.5; wait 12; capture <run>_roofs;
centre 11,-1; zoom 0.8; wait 2; capture <run>_roofs_close; centre 18,4; zoom 1.0; wait 2;
capture_at SOOT_FADE 2f <run>_fade_2; capture_at CONSEQUENCE 0.4s <run>_embers_04;
capture_at CONSEQUENCE 1s <run>_embers_10; capture_at CONSEQUENCE 2s <run>_embers_20;
detonate 3; capture <run>_after; quit
```

**Where each armed capture landed:**

| step | 2D, a / b | 3D, a / b |
|---|---|---|
| `SOOT_FADE 2f` | 0.269 / 0.241 s | 0.231 / 0.201 s |
| `CONSEQUENCE 0.4s` | 5 / 5 frames · 0.469 / 0.463 s | 10 / 9 frames · 0.419 / 0.408 s |
| `CONSEQUENCE 1s` | 12 / 12 · 1.048 / 1.066 s | 23 / 24 · 1.008 / 1.012 s |
| `CONSEQUENCE 2s` | 24 / 24 · 2.050 / 2.040 s | 51 / 53 · 2.011 / 2.008 s |

- The consequence channel ran 15 frames in 2D (4.1 s wall) and 27–29 frames in 3D
  (3.5 s wall). Its 586 effects were the same count in all four boots: 228 smoke, 304
  ember and 54 debris.
- A 2D frame lands up to ~0.07 s later than the offset asked for, because 2D frames here
  are long. A 3D frame lands within 0.02 s.

**Run a against run b, per capture:**

| capture | 2D | 3D |
|---|---|---|
| roofs · roofs_close | 0 · 0 px | 0 · 1 px |
| fade_2 | 67.5 % | 85.3 % |
| embers 0.4 · 1.0 · 2.0 s | 33.5 · 39.3 · 41.4 % | 31.1 · 37.9 · 42.0 % |
| after | 0 px | 4 286 px (0.37 %) |

- **The frames with no blast running repeat.**
- **The in-blast frames do not repeat pixel for pixel.** Every ember, puff and spark rolls
  its own values with `randf_range()`, and these 4 boots ran unseeded: `RNG_SEED` was not
  yet read through `DevFlags` (see the status).
- **Seeded, they still do not repeat.** After the fix (commit `9740116a`, APK sha256
  `e9ede4ab…` on disk and on the phone), the same 4 boots were re-run as `r3d0c_*`. All 4
  logs print `[RNG] seeded 1`.

  | a vs b | roofs · close | fade_2 | embers 0.4 · 1.0 · 2.0 s | after |
  |---|---|---|---|---|
  | 2D, unseeded | 0 · 0 % | 67.5 % | 33.5 · 39.3 · 41.4 % | 0 % |
  | 2D, seeded | 0 · 0 % | 67.4 % | 32.7 · 37.9 · 39.7 % | 0 % |
  | 3D, unseeded | 0 · 0 % | 85.3 % | 31.1 · 37.9 · 42.0 % | 0.37 % |
  | 3D, seeded | 0 · 0 % | **17.7 %** | 32.0 · 38.0 · 42.3 % | 0.14 % |

  - Only 3D's fade frame moved much. What else varies between boots is not attributed.
    Two candidates:
    - the number of draws before the blast (the cook is budgeted in milliseconds);
    - the capture landing tens of milliseconds apart in a and b: up to 0.03 s for the
      embers, and 0.07 s for 2D's fade frame (0.204 vs 0.274 s).
- **What does repeat is the stage of the effect.** It matches in a and b, and in 2D and
  3D: yellow-hot at 0.4 s, orange at 1.0 s, mostly dark coals at 2.0 s.

**What the pairs show:**

| R3D-6 item | captures | what the pair shows |
|---|---|---|
| 6 · embers | `r3d0b_pg_*_embers_04/10/20` | The same stage at each instant in 2D and 3D: the embers are a 2D overlay over either board. Only in 3D, small brown flecks and clusters of white dots sit on top; in 2D the voxel layers cover them. Not identified (the debris overlay, z −8, is the first candidate). |
| 6 · soot fade | `r3d0b_pg_*_fade_2` | 2D is part-way through darkening. 3D shows no scorch yet: its board recolours soot once, after the fade (`[BOARD3D] recolour soot` logs 65–70 ms after the capture). |
| 6 · floor depth dim | `r3d0b_pg_*_after`, `r3d0_g_*_after0/1` | Only inside crater frames, never framed on its own. |
| 1 · roof tops | `r3d0b_pg_*_roofs`, `…_roofs_close` | The metal and stone roofs (CEILING slabs, levels 96–97) read lit in both renderers. The dark rhombus the size of a box's footprint is at ground level: the hollow box's unlit interior floor, drawn over the 3D walls. |

**Item 1, bisected on desktop.**
- The setup: 3D board, the same framing in a 360×806 window, and a temporary patch that
  hid named Room nodes after the board was built. The patch was reverted and never
  committed.
- The results, step by step:
  - hiding `shadow_full_layer` changes nothing;
  - hiding `_tile_shadow` removes the fill;
  - hiding `_shadow_boundary_overlay` as well removes the outline, and the rhombus is
    gone;
  - the GU grid lines drawn across the walls leave with the group holding
    `_gu_grid_overlay` and `_tile_game`;
  - the red line survives hiding 11 overlay nodes (the shadow layers, the game, grid,
    movement, ray, boundary, path, selection and label overlays), and is still not
    identified.
- So it is an R3D-5 row (a 2D overlay drawn over 3D geometry), not a lighting defect.
  The Director moved it to `RENDER3D` R3D-5 the same day.

**Caveat, as in §15.18.5:** the `Detonate / Cancel` menu and the dev panel are on screen in
every frame.

### 15.19 ✅ RENDER3D R3D-1a MEASURED — which packed layout holds the voxel store

**Why.** `RENDER3D_MASTER_PLAN` R3D-1a. That section holds the decision rule (committed
before the run, `43af4062`), the layouts, the identity checks on desktop and the memory
table. This section is the device half.

**The APK.** Commit `8c7b2e55`, sha256 `908934e5…`, the same file on disk and on the
phone.
- Moto g04s, portrait, 3D board with the 2D writes skipped, `NO_BAKE=1`, `RNG_SEED=1`
  (`[RNG] seeded 1` in both logs).
- The scenario: `detonate 0; detonate 1; store_spike 5` on PLAYGROUND, with
  `GRENADE_GUS=25,2;37,2` beside four boxes' corners.
- 2 boots, both exited cleanly.
- Logs (local): `docs/measurements/device_2026-09-16_moto_g04s_r3d1a_pg_{a,b}.log`.

**Identity on the device:** every layout's T1, T2 and T3 answer equals O's, in both boots,
and equals desktop's (T1 214 718 · 2 637 094; T2 109 219 faces; T3 736 blast seeds, 467
damaged).

**Medians of 5, ms, boot a / boot b.** The layouts were interleaved inside each
repetition. Every repetition lies within ±6 % of its median.

| | T1 light occupancy reads | T2 mesher scan | T3 walk reads |
|---|---|---|---|
| O — objects and today's dictionaries | 1 363.9 / 1 381.7 | 787.6 / 802.6 | 362.0 / 362.0 |
| A — dense grid | 480.9 / 481.4 | 593.0 / 604.7 | **421.8 / 421.1** |
| Ac — dense per allocated chunk | 1 044.8 / 1 044.1 | 640.8 / 640.3 | 292.3 / 292.0 |
| B — per-container arrays + derived grid | 481.1 / 480.4 | 417.0 / 415.2 | 134.1 / 134.5 |

- **The Moto runs the kernels 4.6–7.9× slower than desktop.**
  - O's object walk slows the most: T3 is 7.9× slower on the phone, where every packed
    layout is 4.6–4.8×.
  - So A's T3 penalty SHRINKS on the device: 2.0× O on desktop, 1.16× on the Moto.
  - Ac's T3 goes from slower than O on desktop (63 vs 46 ms) to faster on the Moto
    (292 vs 362).
  - T1 and T2 rank the layouts the same way on both.
- **A fails the rule's speed gate** on T3, 16 % above O. Its walk visits all 2.19 M
  padded cells.
- **B's T2 + T3 is 550 ms against Ac's 933**, so the rule picks B.
- **The spike's own setup** — collecting 216 104 claims and building O's dictionaries plus
  three layouts — took 532–538 ms and 8.6–8.8 s. Not separated per layout.
