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
