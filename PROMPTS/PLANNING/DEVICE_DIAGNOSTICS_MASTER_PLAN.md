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

## 3. DIAG-00 — the flag-channel spike (BLOCKING, do this first)

⚠️ **Nothing else may be designed until this is measured**, because the answer
decides the shape of `DevFlags`. Three candidate channels, none of them yet
verified on this project:

| # | Channel | Cost per flag change | Risk |
|---|---|---|---|
| **A** | `command_line/extra_args` in the Android preset (`export_presets.cfg:.. command_line/extra_args=""` — the field exists) | a full re-export | Baked at build time. Fine for a fixed harness build, useless for iterating. |
| **B** | A flags file pushed with `adb`, read at `user://dev_flags.cfg` | seconds | `user://` on Android is the app's private files dir. A **release** APK is not debuggable, so `adb push` / `run-as` cannot write there. Making it debuggable to win the push **changes the perf being measured** — a debug template is not a release template. This tension is the whole reason the spike exists. |
| **C** | An intent extra on `am start` (`--es command_line_args ...`) | seconds | **UNVERIFIED.** Godot's Android launcher may or may not accept this. Must be tested, never assumed. |

**Spike deliverable:** one paragraph naming the winning channel with the command
that proves it, plus the measured cost of one flag change. If C works, it wins
outright. If not, the likely answer is **A for the release measurement build and
B for a separate debuggable iteration build**, with the plan stating in writing
that B's numbers are never quoted as device performance.

---

## 4. DIAG-01 — `DevFlags`, the one seam

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

## 5. DIAG-02 — results out of the device

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
DIAG-00  flag-channel spike          BLOCKING
DIAG-05  emulator install            (parallel — unblocks harness work)
DIAG-01  DevFlags seam + 01b
DIAG-02  logcat capture + parser
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
3. **What frame budget counts as "factível"?** Without a ratified number, the
   harness reports and nobody can close the question. A proposal: the worst
   single frame of a detonation, on the reference handset, under some ratified
   ceiling in ms.
4. **Does the blast get a device-specific quality tier** if it fails, or does
   the detonation get optimized until it passes everywhere? This decides whether
   a failure re-opens the other two plans or opens a new one.
