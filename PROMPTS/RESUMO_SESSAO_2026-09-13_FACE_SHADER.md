# SESSION SUMMARY — 2026-09-13
## Device performance: the face shader, priced stage by stage on the Moto g04s

**Director's request:** *"Vamos continuar com os testes no moto."* — then, asked
for the next target, chose **the face shader** (over hand play, the non-voxel GPU
and the freezes).

**Answer: there is no cheap look tier.** The shader is 6.3 ms of the Moto's 19 ms
idle GPU frame, and 4.5 ms of that is the light and the soot — the look itself.
What can be removed buys little. The real lever is engineering: that 4.5 ms is
paid per fragment for data that is constant per quad. Full record:
[`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) §10.12.

---

## 1. The finding that reframed the task

`NO_FACE_SHADER` replaces the shader with an empty one. Since PERF-P3 that shader
also applies the **light bucket** and the **per-face soot**, so §10.11.5's "~4 ms
for the face shader" was really the price of the lighting system, not of a look
detail. Stage-by-stage pricing was needed before any capture could mean anything.

## 2. The result — Moto g04s, one APK, stages removed cumulatively

| removed | idle render gpu | Δ | detonation 1 / 2 |
|---|---|---|---|
| nothing | 19.0 ms | — | 30.7 / 34.6 |
| debug branches | 18.4 | −0.6 | 27.8 / 34.0 |
| + second texture sample | 18.5 | 0 | 27.2 / 33.5 |
| + residue snap (FACE-READ-03) | 17.3 | −1.2 | 26.8 / 33.2 |
| + face tone | 17.2 | −0.1 | 25.6 / 32.6 |
| + soot decode | 15.3 | −1.9 | 24.1 / 31.0 |
| + light bucket, cell recovery, plane fetch | 12.7 | −2.6 | 23.0 / 29.3 |
| no-op shader | 12.6 | — | 23.5 / 29.1 |

Everything stripped matches the no-op, so the ladder accounts for the whole shader.

## 3. The look — desktop, pixel diffs, harness earned at 0 px

- Debug branches + second sample removed: **0 px** on a close-up of the blast
  (32 px, max 5 levels, on the wide frame — classification-boundary pixels).
- Residue snap removed: **max 3 levels**, but it is the Director's "never three
  identical faces" guarantee.
- Face tone removed: max 9 levels, for 0.1 ms.
- Soot or light removed: max 84 / 81 levels — plainly visible.

Sheets: `Screenshots/history/diag13_face_shader_look_residue_face.png`,
`Screenshots/history/diag13_face_shader_look_soot_light.png`.
⚠️ Captured on the desktop, not on the Mali — the device measured the cost.

## 4. Decisions waiting for the Director

1. Compile the debug modes out of the shipping shader: −0.6 ms, zero look; it
   touches the path the PERF-P3 gates use to paint cells.
2. Residue snap: keep the guarantee, or trade it for −1.2 ms.
3. Spike a per-quad plane path (cell, fetch and decode once per quad, flat
   varyings): up to −4.5 ms with the picture unchanged — unmeasured, and the cell
   recovery it replaces took two PERFORMANCE sections to make exact.

## 5. Left in a clean state

- New instrument `FACE_SHADER_STRIP` (default absent, reachable in the APK). With
  no flag the shader compiles to exactly what it was.
- Gates: lint clean, invariants OK, CODEMAP regenerated, **53 selftests clean**.
- The Moto's `dev_flags.cfg` is reset to a comment-only file.
- `export/Infiltraitor.apk` is this session's code and is installed on the Moto.
- Device logs: `docs/measurements/device_2026-09-13_moto_g04s_diag13_s0..s7_*.log`
  (local only — `*.log` is gitignored).

## 6. Not done this session

Hand play, the Galaxy A16, the ~7 ms of non-voxel GPU (§10.11.7) and the
COMMIT / SOOT FADE freezes are unchanged and unmeasured today.

---

# PART 2 — 2026-09-14: the per-quad spike

**Director:** *"Faz o spike do cálculo por voxel"* (decision 3 above). Full record:
DEVICE_DIAGNOSTICS_MASTER_PLAN §10.13.

**Answer: it is exact, and on its own it buys nothing.** Together with compiling
the debug modes out, it takes the Moto's idle GPU frame from 19.0 to 16.9 ms with
the picture unchanged.

## 7. What was built

`FACE_PLANE_PER_QUAD=1` (default absent): the vertex stage reads the cell plane and
decodes light and soot once per quad. A vertex cannot tell whether it is a left
or right corner, so it reads both candidate cells and the fragment picks with the
already-proven §12.9 test.

## 8. Correctness — every gate passed, and every gate was shown able to fail

- Pixel diff, per-fragment vs per-quad: **0 px** on the blast close-up (Metal and
  Compatibility) and on the wide frame.
- Cell gate: **100.000%** on 16 levels at the metal wall, both renderers.
- Fault injected on purpose (candidates swapped): gate **FAIL at 0.271%**, close-up
  413 004 px different. Restored byte-identical; selftests 53 clean.

## 9. Cost on the Moto

| | render gpu |
|---|---|
| control (two runs) | 18.9 / 19.0 |
| per-quad (two runs) | 19.1 / 19.1 |
| debug modes compiled out, per-fragment | 18.4 |
| **debug modes compiled out, per-quad** | **16.9** |

Without the debug branches per-quad saves 1.3–2.0 ms in every configuration tried;
with them, nothing. A fix aimed at the suspected cause (explicit-LOD fetches in the
debug branches) changed nothing on the device and was reverted — why those
untaken branches cost so much on this GPU is still unexplained.

## 10. Decision waiting for the Director

One change, both halves already flags: **debug modes compiled out of the shipping
shader + per-quad path → −2.1 ms of idle GPU, same picture.** The P3 cell gate
would then ask for a debug build of the shader explicitly.

## 11. State

- Nothing defaults on. The shader compiles exactly as before without flags.
- The Moto runs the committed code with a neutral `dev_flags.cfg`.
- Logs: `docs/measurements/device_2026-09-13_moto_g04s_diag13_{d,x,y,e}*.log` (local).

---

# PART 3 — 2026-09-14: both shipped

**Director:** *"Liga as duas: debug fora e cálculo por voxel"*. Full record:
DEVICE_DIAGNOSTICS_MASTER_PLAN §10.14.

## 12. What changed

- The voxel face shader now reads the cell plane **once per quad** by default, and
  its debug paint branches are **compiled out** of the build that ships.
- `VoxelRenderer._face_shader_variant()` is the one place that picks the build;
  `debug_set_cell_paint_mode()` swaps to the debug build when a paint mode is
  asked for, so the P3 cell gate keeps working.
- `FACE_PLANE_PER_QUAD=0` brings back the per-fragment path for comparison.
  `FACE_SHADER_STRIP` no longer accepts `DEBUG`.

## 13. Verified

Desktop, this exact code: 0 px against the gated per-quad build (blast close-up,
wide frame, Compatibility renderer); the cell gate at 100.000% on the default, on
`=0` and on Compatibility, with the gate log showing the debug build being
swapped in; lint, invariants, CODEMAP; 53 selftests clean; the APK's shader is
byte-identical to the repo's.

## 14. ⚠️ Not verified

**The shipped APK was not measured on the Moto** — the phone was locked and a
three-hour wait for an unlock expired, and by 04:11 it was no longer attached. The expected result (19.0 → 16.9 ms of idle
render gpu) is the measurement of a near-identical build from part 2, not of this
one. The flags for the check are prepared (plan §10.14.3); it needs the phone
unlocked by hand.
