# SESSION SUMMARY — 2026-09-12 (evening)
## Device performance: ablation on the Moto g04s, down to the 24 fps floor

**Director's request:** *"Vamos continuar com os trabalhos de diagnóstico,
desabilitando features, reduzindo efeitos e outros elementos que possam estar
consumindo memória. Um bom candidato é o sistema de iluminação procedural em tempo
real. Se chegar proximo do nosso piso de 24 fps pode parar."*

**Answer: the floor is reached on the benchmark — and the lighting was not the
cause.** Full record: [`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) §10.11.

---

## 1. The result

Moto g04s, release APK, bake ON, PLAYGROUND, automated benchmark (2 detonations,
RNG pinned), same binary on both sides:

| | before | after |
|---|---|---|
| idle board | 40.4 ms/frame | **20.1 ms/frame** |
| detonation 1 — mean | 52.8 ms (19 fps) | **26.9 ms (37 fps)** |
| detonation 2 — mean | 62.1 ms (16 fps) | **34.4 ms (29 fps)** |

Both detonations are above the 24–25 fps floor; the second is just under the
30 fps target. The committed binary was re-run as a final check: **27.4 / 34.3 ms**
with the frame probe, **27.3 / 34.1 ms** without it.

## 2. The cause: nine guards redrawing cones that had not moved

The idle frame on this handset was paced by **script**, not by the GPU. The GPU
ablations (face shader off, 3.5× fewer pixels) moved `render gpu` and left the
frame at 40 ms; hiding everything outside the voxel board took it to 15 ms.

A per-call-site clock (`FrameSplit`, new) named it in one run:
`guard cone smooth draw 26.87 ms/frame`. `GuardEnemy._process()` queued a redraw
of the guard and both vision-cone nodes **every frame**, and each redraw casts 33
rays through `can_see_cell()` — ~3 ms per guard on a T606, for a cone that is not
moving.

**Fix:** the cone redraws only when what it draws changed (angle beyond 1e-5 rad,
facing, cell, state, LOS data). `CONE_REDRAW_ALWAYS=1` puts the old path back for
comparison.

## 3. Four harness defects that were corrupting measurements

| defect | fix |
|---|---|
| `device_run.py` killed the game when `adb logcat` exited by itself — a 250 s run died 55 s in, during map load, reporting "no fatal error" | reattaches the stream; ends the capture when the game exits by itself |
| `export_android.py --renderer` never reached the APK — the "Compatibility" build was Vulkan | overrides `project.godot` for the export only and asserts the packed binary |
| `HIDE_VOXELS` hid nothing (undone a few lines later) | fixed |
| `Performance.TIME_PROCESS` looked like a per-frame cost | it is a maximum held over ~1 s — read 246 ms in a window whose mean was 92 ms |

Also measured, not fixable: **this handset cannot turn vsync off under Vulkan**,
so its ms/frame is always quantised to the 90 Hz refresh. And **`NO_LIGHT` is
degenerate on the current build** (the LIGHT beat goes 2.6 s → 17.4 s) — it
predates the cooked light and must not be quoted.

## 4. What is left, in the order it was measured

1. **The voxel face shader (the "procedural lighting" on the GPU): ~4 ms of every
   frame.** With it off, detonations go 26.9/34.4 → **22.9/30.3 ms** and the idle
   frame 20.1 → 16.8 ms. Removing it changes the picture — **a Director decision**
   (a cheaper mobile shader tier), not an engineering one.
2. **Non-voxel rendering: ~7 ms of GPU** (render gpu 19.0 → 12.0 with it hidden).
3. **Single-frame freezes during playback, unchanged by anything above:** COMMIT
   ~260–310 ms, and the first SOOT FADE frame **1.7 s on the second detonation**.
4. **The cone cost comes back whenever guards turn** — nine guards rotating in the
   enemy phase is ~27 ms again. The fix removed the idle cost, not the cost of a
   redraw.
5. **Memory is unchanged:** 2.1–2.2 GB PSS, 0.5–1.0 GB swap on a 3.8 GB handset.

## 5. ⚠️ Not verified this session

- **Hand play.** Everything above is the automated benchmark (DIAG-11's gap
  between benchmark and hand play is still unexplained).
- **The Galaxy A16 5G** was not connected and was not re-run.
- **Pixel identity of the cone fix.** A desktop A/B shows no difference beyond the
  harness's own run-to-run spread, and every differing pixel lies inside a vision
  cone — but the capture is not deterministic there, so a 0-px gate was never
  earned.

## 6. New instruments (all default absent, all reachable in the APK)

`FrameSplit` / `[FRAME-SPLIT]` · `FRAME_PROBE` process/physics/node columns ·
`NO_FACE_SHADER` · `HIDE_VOXELS` · `HIDE_LEVELS_ABOVE` / `HIDE_LEVELS_BELOW` ·
`QUADRANT` · `STRETCH_VIEWPORT` · `ZOOM` · `HIDE_NON_VOXEL` ·
`HIDE_NODES=<name*>` · `NODE_CENSUS` · `CONE_REDRAW_ALWAYS` · `NO_LIGHT`
(degenerate, see §3).

## 7. Where to resume

The device cycle is two commands and every ablation above is a flags file, no
rebuild:

```bash
python3 tools/persistent/export_android.py --install --device ZF524T5TG5
python3 tools/persistent/device_run.py --device ZF524T5TG5 --seconds 400 --mem-poll 30
```

Next decisions for the Director: the face-shader tier (§4.1), and whether the
freezes (§4.3) are the next target or hand play (§5) is measured first.
