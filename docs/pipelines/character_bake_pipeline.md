# Character Bake Pipeline

**How a character goes from a Python-described model to the PNG frames
`AgentSprite` draws.** Written 2026-08-17 so the pipeline can be executed by
someone who did not build it. Everything here is measured off the scripts, not
recalled: where a number appears, the file that owns it is named.

Sibling document: [`lighting_authoring_pipeline.md`](lighting_authoring_pipeline.md).
For the *voxel/facade* bake system (B1–B6) — a different pipeline that shares
none of this — see
[`../technical/BAKE_SYSTEM_REFERENCE.md`](../technical/BAKE_SYSTEM_REFERENCE.md).

---

## 0. The shape of it

Four stages, three of them Blender, one Godot. Each stage writes files the next
one reads; none of them talk to each other any other way.

```
  p1_agent_model.py      Blender  ─►  agent_base<variant>.blend / .glb
        │                                (T-pose, rigged, palette applied)
        ▼
  p3_posture_export.py   Blender  ─►  agent_posed_<grip><variant>_<posture>.glb
   (imports p2_grip_spike)              + Screenshots/p3_postures<variant>/manifest.json
        │
        ▼
  agent_frame_bake_spike.gd  GODOT ─►  actor_bakes/agent_frames<family>/<posture>/
   (WINDOWED, real GPU)                   frame_{N,E,S,W}_{color,normal}.png
        │                                 anchor.json
        ▼
  AgentSprite (runtime)              relights the flat frames via the normal map
```

`p3_walk_export.py` is the same as stage 2 but emits a 32-phase cycle instead of
three postures. It writes the same manifest shape, so stage 3 is unchanged.

---

## 1. Hard invariants — break any of these and the result is silently wrong

| Constant | Value | Owner | Why it cannot move |
|---|---|---|---|
| Camera elevation / azimuth | **30° / 45°** | `agent_frame_bake_spike.gd`, `p1_agent_preview.py`, `AgentSprite` | D26. The normal map is baked in this camera's space; the runtime shader feeds `light_dir` in that same space. A different angle breaks the light maths **with no error**. |
| Voxel size | **0.20 m** | `§4.7` | The unit the character spec is written in. |
| `VOXEL_STEP_PX` | **20** | `QUICK_REFERENCE.md` | Fixes pixels-per-metre at `20 / (0.20 · cos 30°)` = **115.470**. |
| Viewport | **256 × 256** | `agent_frame_bake_spike.gd` | Frame size; `anchor.json` records it. |
| `MESH_SCALE` | **1.0** | `agent_frame_bake_spike.gd` | The GLB is authored in real metres. A tuned scale would make a proportion judgement circular. |
| Canonical rest height | **1.898 m** | `p2_grip_spike.scale_to_target_height` | Part 1's own model height, hardcoded as `src`. |
| Ship scale factor | **2.00 / 1.898 = ×1.0537** | same | Shared by **every** variant so all bodies are the same size. See §4. |
| `MAX_WHITE_FRACTION` | **0.10** | `agent_frame_bake_spike.gd` | Albedo gate — catches a palette that blows out to white. |

Directions are `N,E,S,W` at yaws `0, 90, 180, -90`. In Blender's export the same
four yaws are labelled `NE,NW,SW,SE` (`p2_grip_spike.YAWS`) because that compass
is vertex-aligned — see [`../DIRECTION_GLOSSARY.md`](../DIRECTION_GLOSSARY.md).
They are the same four rotations; do not "fix" one to match the other.

---

## 2. Stage 1 — the model (`p1_agent_model.py`)

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset_generation/p1_agent_model.py
```

Writes `ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_base<VARIANT>.{blend,glb}`.

| Env | Default | Effect |
|---|---|---|
| `P1_VARIANT` | `""` | **Output filename suffix.** This is the one that decides what gets overwritten. |
| `P1_PALETTE` | `""` | Key into `PALETTES` — `enemy`, `test_white`. Empty = the agent. |
| `P1_JOINTS_YELLOW` | unset | Dev bake: yellow joints. |
| `P1_NO_CREASES` | unset | Skip the fold/seam family (a control for judging its contribution). |
| `P1_NO_HAT` / `P1_FORCE_HAT` | unset | Override the palette's hat decision. |
| `P1_NO_BACKPACK` / `P1_FORCE_BACKPACK` | unset | Override the palette's backpack decision. |

**⚠ `P1_MODEL` is NOT a thing here.** It belongs to `p1_agent_preview.py`.
Passing it to the model script does nothing and the script writes to
`agent_base.blend` anyway — which is how the default agent model was clobbered
on 2026-08-17. The output files are gitignored, so git cannot restore them;
regenerate with a plain default run.

### Which parts a palette gets

Palette-conditional, not universal:

- **Hat** (`seg_fedora_brim/curl/band/crown`) — skipped for `enemy`.
- **Backpack** (4 parts) — skipped for `enemy`; it is the agent's gadget pack (D53).
- **Pinstripes** (44 parts: torso + sleeves + trousers) — built only for `test_white`.

Every part binds to the bone of the limb it sits on, never to a parent — a
sleeve stripe bound to `chest` stays behind when the arm poses.

---

## 3. Stage 2 — posing and export (`p3_posture_export.py`)

```bash
P2_MODEL=agent_base_enemy P3_DEV_ONLY=0 P2_EXPECTED_HEIGHT_M=1.920 \
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset_generation/p3_posture_export.py
```

| Env | Default | Effect |
|---|---|---|
| `P2_MODEL` | `agent_base` | Which `.blend` to pose. **Must be set before import** — the module reads it at import time. |
| `P3_DEV_ONLY` | **`1`** | Forces `P2_MODEL=agent_base_devjoints`. Set `0` for the normal character. |
| `P3_GRIP` | `lowered` | D40: idle, walk and turn are all `lowered`. |
| `P3_WEAPON` | `shotgun` | |
| `P2_EXPECTED_HEIGHT_M` | `2.00` | The standing height the export **gates** against. See §4. |
| `P3_WALK_PHASES` | `32` | `p3_walk_export.py` only. |

> **`P3_DEV_ONLY` defaults to `1` while `AgentSprite.DEV_ONLY_MILESTONE` is
> `false`.** The two are supposed to flip together and currently disagree. Pass
> `P3_DEV_ONLY=0` explicitly for any ship-facing bake, or you will export the
> yellow-joint figure with correct-looking filenames.

Outputs, per posture: a posed `.glb`, four preview PNGs, and
`Screenshots/p3_postures<variant>/manifest.json`.

### ⚠ Read the manifest, not the closing log

The script's final hand-off prints, for every variant:

```
AGENT_BAKE_OUT=.../actor_bakes/agent_frames/<posture>/
```

That path is a **hardcoded string that ignores `bake_family()`**. Copying those
lines bakes a variant straight over the agent's own frames. The `manifest.json`
written alongside carries the correct `agent_frames<family>/` paths — drive the
bake from it.

`bake_family()`: `""` → `""`, `_devjoints` → `_dev`, anything else keeps its own
suffix (`_enemy` → `agent_frames_enemy/`).

---

## 4. The height gate, and why it refuses correct models

`scale_to_target_height()` multiplies every figure by a **fixed** factor
`2.00 / 1.898`. It does not re-measure. That is deliberate: it guarantees every
variant's body is the same size, so a faction is a palette and not a different
build of person (D34).

The consequence is that **total height varies with silhouette**. Measured
2026-08-17:

| Model | Rest height | × 1.0537 | Ships at |
|---|---|---|---|
| `agent_base` (fedora) | 1.8978 m | | **2.000 m** (10.00 voxels) |
| `agent_base_enemy` (bare-headed) | 1.8220 m | | **1.920 m** (9.60 voxels) |

A fedora is 7.6 cm. So the hatless export lands outside the standing band and is
refused — correctly. The fix is **never** to let the scale re-solve (that grows
the body to fit the number); it is to declare the expected height:

```bash
P2_EXPECTED_HEIGHT_M=1.920 ...
```

`EXPECTED_STANDING_HEIGHT_M` and the scale factor are separate constants for
exactly this reason. The gate stays a gate — the caller states what it expects
and the export refuses anything else, the same contract `AGENT_BAKE_HEIGHT_M`
uses downstream.

**Procedure when a new silhouette's height is unknown:** run once without
declaring it and read the measured value out of the failure message. Do not
compute it by hand.

Crouch and prone are **solved**, not asserted: a binary search scales the folded
pose until the height lands in its voxel band, so a re-proportioned model
re-solves instead of drifting.

---

## 5. Stage 3 — the frame bake (`agent_frame_bake_spike.gd`)

**Must run WINDOWED.** `--headless` forces Godot's dummy rasteriser, which never
produces real pixels.

Single model:

```bash
AGENT_BAKE_MODEL=res://ASSETS/.../agent_posed_shotgun_lowered_enemy.glb \
AGENT_BAKE_OUT=res://ASSETS/.../actor_bakes/agent_frames_enemy/standing/ \
AGENT_BAKE_HEIGHT_M=1.9199 \
/Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
  --script res://godot/scripts/tools/agent_frame_bake_spike.gd
```

**A whole sequence in ONE boot — prefer this:**

```bash
AGENT_BAKE_MANIFEST=Screenshots/p3_postures_enemy/manifest.json \
/Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
  --script res://godot/scripts/tools/agent_frame_bake_spike.gd
```

Each manifest entry carries its own `out_dir` and its own **measured**
`height_m`, which is the only way the gate survives a sequence — a walk cycle
bobs between 9.72 and 10.02 voxels and one expected height would reject most
phases.

`--position 4000,4000` puts the window off any real screen. It still needs a
real GPU; there is no headless path.

### Output, per directory

```
frame_N_color.png   frame_N_normal.png
frame_E_color.png   frame_E_normal.png
frame_S_color.png   frame_S_normal.png
frame_W_color.png   frame_W_normal.png
anchor.json
```

`anchor.json`:

```json
{"anchor_px": [128.0, 223.99],
 "expected_height_px": 191.99,
 "px_per_screen_m": 115.470053837925,
 "viewport_size": [256, 256]}
```

The figure is recentred **in Y only**, never on the full AABB: it holds a weapon
sticking ~0.6 m forward, so an AABB-centre recentre would stand it off its own
tile by the length of the gun. The GLB's origin is already the point under the
feet (stage 1 loud-fails if the figure does not stand on z=0).

---

## 6. Runtime contract (`AgentSprite`)

Frames are loaded from `FRAMES_ROOT.trim_suffix("/") + frame_family + "/"`, so
`frame_family = "_enemy"` reads `agent_frames_enemy/`. Set it **before**
`setup()`.

The shader is `flat_normal_relight.gdshader`:

```
lit = albedo * (ambient + ndotl * light_intensity) + spec
```

Consequences worth knowing before authoring a palette:

- On an unlit facet `ndotl ≈ 0`, so the whole thing collapses to
  `albedo * ambient`. **No palette value and no light-response tuning can
  brighten a shadowed surface** — only `ambient` moves it.
- `ambient` lives per `frame_family` in `LIGHT_RESPONSE_OVERRIDE`, never
  globally: 0.42 is ratified for the agent's near-black suit.
- CLI-baked PNGs never went through the editor's import scan, so `AgentSprite`
  loads them with a raw loader — a plain `load()` fails with "No loader found".

---

## 6b. Layers — the head and the hat, added 2026-08-18

A layer is a second sprite drawn over the body from **this same camera into this
same 256×256 frame**. It exists so the head can turn without multiplying the
body's four facings by the head's yaw sweep — `p3_head_turn_spike.py` measured the
premise: the head layer at one absolute yaw is **0 of 126 000 pixels** different
under a body at 0° and at 90°, so head art is indexed by absolute yaw and shared
across all four facings.

Three things make a layer register, and none of them is a tuned offset:

1. **The parts come out of ONE posed export.** `p2.export_posed(..., parts=...)`
   writes the full figure, then the headless body, the head and the hat, before
   its verification re-import. A partition gate refuses a split that drops or
   duplicates a mesh.
2. **The layer inherits the BODY's Y recentring**, read back out of the body's own
   `anchor.json` (`recentre_y_m`), never its own — a head centred on itself lands
   in the middle of the frame instead of on its neck.
3. **The frames are cropped to their alpha box**, and the crop origin is written
   per frame. Measured 50–70× smaller than the uncropped frame; D42 names RAM as
   this character's binding constraint.

`anchor.json` gained `recentre_y_m`, `head_socket_px` (per direction, the top
centre of `seg_neck`) and `headless`. **`headless` is per frame set and is what
`AgentSprite` reads to decide whether to draw layers at all** — so a re-bake need
not be atomic: postures can ship headless while the walk still carries its baked
heads, and both render correctly.

The registration gate runs automatically at the end of the same Godot boot; see
[`PROMPTS/BAKE_ORDER_CHARACTER_LAYERS.md`](../../PROMPTS/BAKE_ORDER_CHARACTER_LAYERS.md)
for the commands, the measured figures and what each printed line means.

## 7. Verification — what to check before calling a bake done

1. **Stage 2 gates already ran**: height band, X-span (catches an un-posed
   T-pose at 1.76 m), floor-on-origin at 0.03 m tolerance, and the anatomy
   invariants (crown above hips, no foot above the hips, flat when lying).
2. **Stage 3 gates**, and they are two *different* checks — do not conflate them:
   - **Projection scale**, `SCALE_TOLERANCE_PX = 0.25`: a 0.20 m rise must draw
     `VOXEL_STEP_PX` (20 px) on screen. This is the game's own constant, so if it
     holds the bake is at the game's size *whatever shape the figure is*.
   - **Albedo**, `MAX_WHITE_FRACTION = 0.10`: catches a palette blowing out.

   `AGENT_BAKE_HEIGHT_M` does not gate here — it feeds
   `expected_height_px_for()`, which is written into `anchor.json` for the
   runtime. The height *band* gate lives upstream, in stage 2.
3. **Look at the frames.** Build a contact sheet; the gates measure size and
   whiteness, not whether the character is right.
4. **Boot the real game** and capture
   (`INFILTRAITOR_SCREENSHOT_ONCE=1 python3 tools/persistent/auto_screenshot.py`).
   A green bake chain is not evidence the figure reads in the room.
5. **Do not pixel-diff the `end_turn` capture** to prove anything: that harness
   is non-deterministic — 849 349 pixels differ between two runs of identical
   code (measured 2026-08-17).

---

## 8. Known traps, all of them paid for

| Trap | Symptom | Guard |
|---|---|---|
| `P1_MODEL` passed to the model script | `agent_base` silently overwritten with another palette | Use `P1_VARIANT` |
| Copying stage 2's closing log lines | a variant baked over `agent_frames/` | Drive from `manifest.json` |
| `P3_DEV_ONLY` left at its default | yellow-joint figure with ship filenames | Pass `P3_DEV_ONLY=0` |
| Letting the scale re-solve for a new silhouette | body grows to hit 2.00 m | Declare `P2_EXPECTED_HEIGHT_M` |
| `--headless` on stage 3 | blank or missing frames | Windowed + `--position 4000,4000` |
| Baking a head layer over a body that still has a head | the baked head peeks out at non-zero yaw | Bake the body headless — see the bake order |
