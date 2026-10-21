# RESUMO DA SESSÃO — 2026-10-20/21 — THE HERO CHARACTER (a new body, a costume of our own, a face, a mask)

**Branch:** `claude/r3d-actors-y5r8hs` (commits land on `origin/main`). **Decisions:** `ACTOR_MASTER_PLAN` **D70–D76**.
**Build owner:** `CHARACTER_MASTER_PLAN` (pointer added at its top). **Everything below was measured or rendered this session; what was not, is listed under
"NOT done / NOT measured".**

## 1. What the Director asked for, in order

1. A richer 3D character built from FREE parts (hands, feet, clothes, hat…) merged into one new model; a **backpack that carries the gadgets**; the in-game figure
   is a **miniature of the menu / ranking hero**; outfits are shown on ranking and social pages and **sold / dropped as cosmetics**; **rig flexibility first**,
   because animations will be redone; **an agile, not husky, body**; a **female option** (architecture decided now, the body built later).
2. **Realistic means proportions, not photographic**; the menu shows the model big, so it cannot be very low poly: **simplify at render** (D73).
3. The costume mechanics (D70–D72): a **white/mustard overcoat the backpack absorbs** (no cape), a **hat that becomes a mask** with lit amber eyes and tactical
   vision, a **stationary LED cloak** ("Frodo's rock", Crysis-style ghost). Cosmetic delivery: stock base in the APK, extras downloaded at first load (D74).
4. Costume refinement notes (real shoes, no spats, a loose half-open coat, mustard, a flatter pack, fabric not latex), then: **no openings at the shoulders, more
   visible collars, a manipulable face (D75), a first mask model with lit eyes (D76)**; "document everything and end the session".

## 2. What exists now (inventory; the models themselves are git-ignored: `ASSETS/ISOMETRIC/source_assets/*`)

| Thing | Where | Notes |
|---|---|---|
| Body source (CC0) | `ASSETS/.../imported_models/quaternius_universal_base/` + `ATTRIBUTION.txt` | Quaternius Universal Base [Standard], free Superhero Male / Female, 65-bone UE skeleton with fingers, ~14k tris. **Only the husky "Superhero" bodies are free** (Regular / Teen are the paid Source). Licence read in the pack's own `License_Standard.txt` (CC0 1.0); NOT cross-checked on quaternius.com against a newer "QAL" licence. |
| Animations (CC0) | same folder | Quaternius Universal Animation Library [Standard], 43 actions, **the same 65 bone names, so no retargeting** (Walk_Formal, Crouch_Fwd/Idle, Pistol_Aim_*/Shoot, Roll, Death01, Idle, Sprint…). No prone, cover, peek, throw, shotgun/rifle grips. Godot strips `_Loop`: the action is `Walk_Formal`. |
| Pipeline scripts | `tools/asset_generation/hero/` | `hero_lean_export.py` (colour texture only, 1024 px), `hero_remodel.py` (the agile body, keeps rig + weights), **`hero_tailor.py` (the costume, the face, the mask; v4)**, `hero_dress.py` (the older placeholder). Env vars in each header. |
| Agile body "B" | `superhero_male_agile_b_lean.glb` | Torso x0.76 / y0.84, arms 0.72-0.80, thighs 0.76, shoulders in 4.5 cm; same height, topology, rig, weights. "A" (moderate) also exists. |
| The hero | `hero_tailor4.glb` (master ~25k tris) and `hero_tailor4_g5.glb` (game LOD, 5.9k with the mask kit) | All states in one file (see the header of `hero_tailor.py`). |
| Bench | `godot/scripts/debug/actor_viability_bench.gd`, scenario op `actor_bench <model> <n>` (`scenario_runner.gd`) | Models: `agent`, `quat`, `hero_<file>[_normal\|_black\|_mask\|_maskoff][_march][_cloak]`. Dev only; not gameplay, not saved. |
| Prototype shaders | `godot/shaders/actor_cloth3d.gdshader` (cloth sheen), `actor_cloak3d.gdshader` (the D72 ghost), `actor_mask_eye3d.gdshader`, `actor_mask_halo3d.gdshader` | None reads the screen or the depth buffer (that costs ~250-295 MiB of driver memory on the Galaxy). `BoardLook.graded_shader` is used for the first three. |

## 3. Measured on the Moto g04s (PLAYGROUND, portrait, zoom 0.5, `MAX_FPS=0`, ONE run each, animated figures; board alone 21.2 ms, PSS ~665 MB)

| Case | ms/frame | Draw calls | PSS MB |
|---|---|---|---|
| shipped agent x24 (11k tris, 23 materials) | 31.5 | 169 | 670 |
| Quaternius body x24 (14k tris, 3 surfaces, walking) | 27.9 | 152 | 667 |
| placeholder outfit, 12 surfaces, 14.4k x24 / 7.3k x24 / 3.7k x24 | 29.2 / 26.7 / 25.0 | 305 | 686 / 683 / 679 |
| tailored costume v1, ~5.2k, coat x24 / black x24 | 26.1 / 25.5 | 356 / 339 | ~675 |
| **costume v2, ~5k, 373 draw calls, normal x24 / black x24** | **25.9 / 26.0** | 373 | ~673 |
| D72 cloak ghost shader, 12-surface figures x12 / x24, vs the same opaque | +0.5 / +1.2 | same | n/a |

**Never measured on a handset (the Moto was unplugged on 2026-10-21 and not reconnected): costume v3 and v4, the face blend shapes, the mask kit, the cloth
sheen shader.** Desktop draw calls for v3 g5 x24: 389 (v2: 374). Cost is GPU (render CPU stays 1-2 ms); geometry, not surfaces, is what a crowd costs.
The Galaxy A16 was not run at all. Single runs: no variance estimate.

## 4. Decisions taken or recommended this session (all in the plan)

D70 three independent costume layers + the pack absorbs the coat · D71 the hat becomes a matte mask with tactical vision and a detectable eye glow ·
D72 the stationary LED cloak (odds 1 GU auto / 2 GU 50% / 3 guards fail; entry 1 AP; exit undecided) · **D73 one master model, ONE ~5k game LOD (Claude's
call, as the Director delegated it)** · D74 cosmetics delivered at first load + the suit is ours · **D75 the face blend shapes** · **D76 the first mask model**.

## 5. Traps found (each cost real time; they are in the header of `hero_tailor.py`)

1. **The glTF import splits vertices along UV seams.** Offset along per-vertex normals and every piece cracked at the seams: this was "the openings at the
   shoulders", and it had been hiding behind three wrong theories (group staircases, the neck group, skin-weight transfer). **Found by COUNTING open edges
   (252 -> 0), not by looking.** Weld with `remove_doubles` when copying the body.
2. A copy of the body carries its Armature modifier: a second one poses the piece twice (everything exploded).
3. The 43 UAL tracks all start at frame 1, so the rig is posed at "frame 1": fit and weight against REST (weights were transferred from a twisted body).
4. Two bisect planes with `clear_inner` / `clear_outer` erase each other's hand (gloves came out empty).
5. Setting `colorspace_settings` on a generated image AFTER its pixels regenerates a blank buffer (black textures).
6. Workbench renders textured materials black in a background render: preview by colour, judge textures in the engine.
7. A comment on a line of `;`-joined statements eats the rest (the tipped hat's band silently disappeared).
8. `zsh` does not word-split `$c`; use `${=c}`. A phone's notification shade open makes `screenrecord` record the shade, not the game.
9. A decimated mesh cannot carry shape keys: the game LOD has no face.

## 6. NOT done / NOT measured (so nobody assumes it)

- **Not in the game.** `ActorMesh3D` expects the old rig (bone `head`, `hand_R`; actions named `<posture>_<weapon>_<grip>`, `walk_<weapon>`, throw_*; a head-turn
  modifier). The hero uses `Head`, `hand_r` and the UAL's names. **An adapter (names, weapon attachments, the head turn) is the first job to make him playable.**
- **Missing animations** for the plan's §4.4 set: prone, cover, peek, throw, shotgun / rifle grips, turn in place; and every costume animation (the coat's
  paraglider-strap restore, gloves on, hat to mask, the cloak's crouch under the coat).
- **Missing rig for the mechanisms:** a hat hinge at the nape, the cheek plates out of the collar, the tie hook, the nape tether with its cables, the coat's
  retract parameter. The tipped hat is a static copy; the coat hides by visibility.
- **Cloth and menu finish:** smooth cloth with folds but no normal map; the body is still the husky Superhero with a hard-jawed bald head; no hair (the pack ships
  CC0 hairstyles); the pack is a bevelled box; the tie and shirt need darkening in the black style (the engine would tint them); the 5k LOD shows a small
  patch of jacket at one shoulder; gloves are 5.2k of the 25k master tris because the hands are dense.
- **Face:** the open mouth deforms the lips crudely, no teeth or tongue; blend shapes vs facial bones for animation retargeting is open.
- **Handsets:** v3 / v4 / face / mask unmeasured (see §3). The female body and its outfit fit are not built.
- **Gameplay numbers of D72** (two guards, the cloak's exit cost) and the open items listed in each D-row are the Director's.

## 7. How to reproduce (from a clean checkout; the assets are git-ignored)

```bash
# 1. download (itch.io, the free "Standard" zips, CC0) the Quaternius Universal Base Characters and Universal Animation Library; unzip them somewhere
export HERO_REPO="$PWD/"  HERO_UBC_DIR=".../Universal Base Characters[Standard]/Base Characters/Godot - UE/"  HERO_UAL_GLB=".../UAL1_Standard.glb"
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/hero/hero_lean_export.py   # -> superhero_male_lean.glb
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/hero/hero_remodel.py -- b # -> superhero_male_agile_b_lean.glb
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/hero/hero_tailor.py       # -> hero_tailor4.glb (+ previews in $HERO_TMP)
DECIMATE=0.2 OUT_SUFFIX=_tailor4_g5 /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/asset_generation/hero/hero_tailor.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
INFILTRAITOR_MAP=PLAYGROUND INFILTRAITOR_SCENARIO="framing desktop; centre agent; zoom 2.0; frames 50; actor_bench hero_tailor4_g5_mask 1; wait 1.5; capture mask; quit" \
  /Applications/Godot.app/Contents/MacOS/Godot --path .        # states: _normal | _black | _mask | _maskoff ; walk lane: _march
```
Handset: `export_android.py --install --device <serial>`, then a `dev_flags.cfg` with `MAP=PLAYGROUND FRAME_PROBE=1 TELEMETRY=1 MAX_FPS=0 SCENARIO=...`
through `device_run.py --mem-poll 4 --save <log>` and `bench_analyze.py <log>` (zsh: `${=c}` to split arguments).

## 8. Recommended next steps, in order

1. **Reconnect the Moto and measure v4 + the mask + the face** (the one number this session owes).
2. **Adapter to `ActorMesh3D`** so the hero replaces the agent in a real map; then the missing animations and the mechanism bones.
3. Body polish for the menu: the agile body's face and head (or the paid Regular body), hair, a normal map for the cloth, a real backpack.
4. Decide D72's open numbers and D70-D76's open items with the Director; run the Galaxy.
