# BAKE ORDER — character layers (head turn, hat swap)

**Raised 2026-08-17. Rewritten 2026-08-18**, after the runtime layer system was
built and the first two families were baked and verified. This file is the
executable request: it can be run on another machine with no other context.

**Read [`docs/pipelines/character_bake_pipeline.md`](../docs/pipelines/character_bake_pipeline.md)
first** for the stage-by-stage mechanism, every env var, and the traps common to
all character bakes. This file adds the layer-specific ones.

---

## Status

| Family | Bodies | Head layer | Hat layer | Registration |
|---|---|---|---|---|
| agent `""` | ✅ headless (standing, crouch) | ✅ 24 yaws × 2 postures | ✅ 24 × 2 | ✅ worst **1.20 %** |
| enemy `_enemy` | ✅ headless (standing, crouch) | ✅ 24 × 2 | — bare-headed | ✅ worst **1.20 %** |
| walk `agent_walk` | ✅ headless (32 phases) | reuses standing | reuses standing | — |
| dev `_dev` | ✅ headless (standing, crouch, prone) | ✅ 24 × 2 | ✅ 24 × 2 | ✅ worst **1.20 %** |
| bracket `_test_white` | ✅ headless (standing, crouch, prone) | ✅ 24 × 2 | ✅ 24 × 2 | ✅ worst **1.18 %** |

**Nothing is broken by the unfinished rows.** `AgentSprite` reads `headless` out
of *each frame set's own* `anchor.json` and turns the layers on per set, so a
head-ful walk simply keeps its baked head and does not turn it, while the idle
postures use the layer. The two are the same geometry at yaw 0, so the swap is
invisible. Finish the rows when the behaviour needs them, not before.

> **The bakes are not in git.** `.gitignore:69` excludes
> `ASSETS/ISOMETRIC/source_assets/*`, so every PNG, `anchor.json` and `layer.json`
> named here is a generated artifact that exists only on the machine that made it.
> A fresh clone has the code, the gates and this order — and no frames. That is
> what makes this file the deliverable rather than a record.

---

## Four corrections to the order as first written

Each replaced an assumption with a measurement. They change what to bake.

**1. `P1_NO_HEAD` was never needed and does not exist.** The original order asked
for a model flag to build a headless figure. The parts are instead split at
EXPORT time, out of the same posed scene: `p2.export_posed(..., parts=...)` writes
the full figure, then the headless body, the head and the hat as separate GLBs
before its verification re-import. That is what makes registration exact — the
layers are three views of ONE export, not three exports — and it removes the
variant `.blend` the flag would have required. A partition gate refuses a split
that drops or duplicates a mesh (agent: 58 + 1 + 4 = 63; enemy: 54 + 1 = 55).

**2. Standing and crouch do NOT share a head set.** They were meant to, on the
reasoning that only the head's position changes. `POSTURES["crouch"]` pitches
`neck` by **14°** and the head bone inherits it, so the crouched head is a
different picture and no offset can rotate one into the other. Each layered
posture gets its own set. This costs nothing — a cropped head set is **0.17 MB** —
and it settles the byte-comparison the original §B asked for, by measurement.

**3. Prone has no layer and keeps its head baked in.** A prone head is pitched
~-92°, so turning it is a rotation about the spine, which after that pitch is
roughly HORIZONTAL. The bake makes its yaws by spinning the head mesh about the
WORLD vertical — the same rotation for an upright head, a swing through a cone for
a prone one. Prone opts out at zero cost: guards have no posture at all, so no
head-turn behaviour can reach a prone figure. **Head frames per family: 48
(24 × standing + 24 × crouch), not the 48 the original order budgeted as
24 upright + 24 prone.**

**4. The head socket is per direction, never one point.** The original design
collapsed it to a single pixel on the theory that the neck sits on the figure's
yaw axis. Standing measures **0.000 px** of spread across the four facings and
looks like proof; **the crouch measures 9.6 px** (agent) and **8.9 px** (enemy)
because it leans forward. A single-point delta would have placed the crouched head
that far from its own neck. An earlier gate that *enforced* the collapse would
also have rejected a crouch layer that in fact registers perfectly — it is gone,
replaced by a printed diagnostic and by the composite check below.

---

## The one decision still open

**How many yaws.** `AgentSprite` counts what is on disk, so this is a bake flag
(`P3_LAYER_YAWS`) and not a code change. The shipped sets are **24** (15° a step).

A 90° head turn at the guard's own rate takes ~600 ms, so 15° steps show 6 images
in that time — **10 Hz**, against D46's 30 Hz authoring rate. Whether that reads as
a turn or as a stutter is a judgement, and
[`Screenshots/p3_head_sweep/head_sweep_blind.gif`](../Screenshots/p3_head_sweep/head_sweep_blind.gif)
is the bracket: three blind columns, the game's own exponential lerp, key in
`head_sweep_key.txt`. Rebuild it with
`python3 tools/asset_generation/p3_head_sweep_sheet.py`.

Cost, measured, per family per posture:

| Yaws | Step | Head | Hat | vs. the walk's body phases |
|---|---|---|---|---|
| 24 | 15° | 0.17 MB | 0.24 MB | 67 MB |
| 36 | 10° | 0.26 MB | 0.35 MB | 67 MB |
| 72 | 5° | 0.51 MB | 0.71 MB | 67 MB |

The count must **divide 360** — frames are named `yaw_<000..359>` in whole
degrees, so 48 (7.5°) would round two frames onto one filename. Valid: 24, 36, 40,
45, 60, 72, 90.

---

## How to run it

Two stages per family: Blender exports, then ONE windowed Godot boot bakes the
bodies, the layers and the registration check together. **Godot must be windowed**
(a real GPU rasteriser) — `--position 4000,4000` parks it off-screen.

### A. A posture family (bodies + layers + verification)

```bash
# agent — the default palette
P3_DEV_ONLY=0 /Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset_generation/p3_posture_export.py

AGENT_BAKE_MANIFEST=Screenshots/p3_postures/manifest.json \
/Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
  --script res://godot/scripts/tools/agent_frame_bake_spike.gd
```

```bash
# enemy — note BOTH extra variables; the second is not optional
P2_MODEL=agent_base_enemy P3_DEV_ONLY=0 P2_EXPECTED_HEIGHT_M=1.920 \
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset_generation/p3_posture_export.py

AGENT_BAKE_MANIFEST=Screenshots/p3_postures_enemy/manifest.json \
/Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
  --script res://godot/scripts/tools/agent_frame_bake_spike.gd
```

`P2_EXPECTED_HEIGHT_M=1.920` is the bare-headed enemy's real height. Without it
the export fails at *"exported figure is 1.920 m, outside the 1.990–2.010 m
band"* — the gate working, not a bug.

The Blender stage prints the exact Godot line to run next, built from the
manifest it just wrote. **Copy that line rather than the ones in this file** if
they ever disagree; the manifest is the single source of truth for out-dirs and
measured heights.

### B. The walk (32 phases, headless bodies)

```bash
P3_DEV_ONLY=0 /Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset_generation/p3_walk_export.py

AGENT_BAKE_MANIFEST=Screenshots/p3_walk/manifest.json \
/Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
  --script res://godot/scripts/tools/agent_frame_bake_spike.gd
```

The walk ships **headless** and reuses the STANDING head set across all 32
phases, carried by the neck socket, which is baked per phase and per direction —
that is the case the socket exists for. The walk exports head and hat subsets per
phase too, only so the partition gate has something to check at every phase, and
deletes them immediately; they are not shipping assets.

> **A known, bounded approximation.** The walk pitches `neck` and `head` by
> `HEAD_STABILISE_DEG_PER_M * drop * 0.5` to hold the head level over the bob. At
> the 0.16 m hip-drop cap that is **≤ 3.7°**, which the flat head layer does not
> reproduce — about 1.3 px at the extremes of a ~40 px head. The socket carries
> the head's POSITION exactly, which is the part that matters. If a run shows it
> reads badly, the fix is to drop the head's share of the stabilisation (the
> `"head"` line in `p3_walk_export.py`) and keep the neck's, not to bake head
> yaws per phase.

### C. Other families

Same as §A with the model named. The dev-joint family is
`P3_DEV_ONLY=1` (its default); the white bracket is `P2_MODEL=agent_base_test_white`.
Neither is needed for the head turn to work on the shipped agent and enemy.

---

## What the run must print, and what each line means

```
part 'body': 58/63 meshes -> ..._body.glb          the partition gate
part 'head': 1/63 meshes  -> ..._head.glb
part 'hat':  4/63 meshes  -> ..._hat.glb
standing ships ..._body.glb at 1.6860 m (8.43 voxels)   measured off the SHIPPED file

scale check: a 0.20 m rise draws 20.000 px         the only real scale proof
anchor_px=(128.0, 168.18) | head socket {...} | headless=true
base sockets spread 0.000 px (on the yaw axis)     diagnostic; 9.6 px on a crouch is CORRECT
24 frames, 0.17 MB cropped (12.00 MB uncropped — 69.9x)

VERIFY: composite vs. whole figure
  N: reference 9367 px, silhouette mismatch 112 px (1.20%), colour mismatch 254 px
  registration OK — worst 1.20% of the silhouette
```

**The VERIFY block is the gate that makes the rest mean anything.** It composites
`headless body + head + hat` with the exact arithmetic `AgentSprite` uses, and
compares it against a bake of the whole figure. It runs automatically at the end
of the same boot, so it cannot be skipped.

A perfect zero is not expected and would be suspicious: the reference rasterises
head and body in one pass, the composite antialiases each against transparency
and then blends. **The ceiling is 1.5 %, earned from the measurement, not
invented** — 1.20 % worst on the agent, 0.88 % crouch, 1.20 % / 0.51 % on the
enemy. Set `AGENT_BAKE_VERIFY_DUMP=<dir>` to write composite / reference / diff
PNGs when a number needs a face: a **shift** paints red down one edge and blue
down the opposite one in disjoint ranges; **antialiasing** speckles both colours
evenly around the whole outline, feet and shotgun included, with balanced counts
(measured: 55 red vs 57 blue). The 2026-08-18 run is the second case.

---

## If a gate fires

| Message | What it means | Fix |
|---|---|---|
| `exported figure is 1.920 m, outside the 1.990–2.010 m band` | a bare-headed or otherwise different silhouette | declare `P2_EXPECTED_HEIGHT_M` |
| `the parts cover N meshes but the figure has M` | the split drops or duplicates geometry | a mesh name changed in `p1_agent_model.py`; update `HEAD_MESHES` / `HAT_MESHES` in `p3_posture_export.py` |
| `predates the layer system (no recentre_y_m / head_socket_px)` | the layer was baked before its body | bake the BODY first; the manifest already orders them |
| `no seg_neck in <glb>` | the socket cannot be measured | the neck was renamed or landed in the wrong part |
| `LAYER REGISTRATION FAILED — worst N%` | the layers do not land on their body | run with `AGENT_BAKE_VERIFY_DUMP` and look before changing anything |
| `N yaws gives a step of X deg, which is not a whole number` | the filename convention needs integer degrees | pick a count that divides 360 |
| `a HEADLESS body frame is showing but no layer bake exists` | half a swap landed | bake the layer for that family, or restore a head-ful body |

---

## Verification, after any run

1. `python3 tools/persistent/project_lint.py` — zero compile errors.
2. `python3 tools/persistent/run_selftests.py` — the arbiter (35 clean today).
3. The VERIFY block above, green, for every layered posture.
4. Look at the figure in the game, not only at the numbers.

---

## ✅ COMPLETED 2026-08-18

All five families baked headless with head/hat layers and verified:
- **walk** (32 phases): headless bodies reuse standing head layers
- **dev** (standing, crouch, prone + 4 layer sets): worst 1.20% / 0.88%
- **white bracket** (standing, crouch, prone + 4 layer sets): worst 1.18% / 0.88%

Gates passed: `project_lint.py` clean, `check_invariants.py` OK, `gen_codemap.py --check` OK, `run_selftests.py` 35 clean / 0 failed.
