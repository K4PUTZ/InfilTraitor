# AUDIT — the olive/yellow cast on crazed glass panes near a blast

**Status:** 🟡 OPEN — reproduced, isolated to a class of node, root not yet named.
**Opened:** 2026-09-06. Director asked to stop and write the state down; continue next session.
**Supersedes** the diagnosis in `GLASS_MASTER_PLAN.md` §18.14b (commit `03444a61`),
which this session's deeper probe did **not** confirm — see "What §18.14b got wrong".

---

## 1. The symptom

A glass pane that goes **CRACKED** from a nearby grenade blast reads **olive‑green /
yellow** on the perspective view the blast happened in. It is stable (does not fade
meaningfully over 4 s / 240 frames), and it **vanishes completely on a perspective
rotation**, leaving the pane its normal blue‑grey.

- Director‑reported 2026‑09‑06, and **pre‑existing** — he has seen it "várias vezes".
  **Not** introduced by the G4‑4 shard‑rain work.
- The FLOOR‑CRATER‑01 fix (commits `921a5009` / `5cb1d948`, the magenta canary) removed
  a *different* bug — the flat orange floor placeholder showing through a rotated
  crater — and did **not** touch this olive cast.

## 2. How to reproduce

```
INFILTRAITOR_MAP=GLASS INFILTRAITOR_CAPTURE_ACTION=glass_blast_demo \
INFILTRAITOR_AUTO_SCREENSHOT=1 INFILTRAITOR_GLASS_BLAST_GU=13,13 \
INFILTRAITOR_FREEZE_GUARD_TURN=1 \
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

- `Screenshots/history/glass_blast_demo_after.png` — view N, 240 frames post‑blast:
  the two crazed panes are vividly olive‑green.
- `Screenshots/history/glass_blast_demo_flip_E.png` — after `_set_perspective("E")`:
  the panes are neutral. The cast is gone.

The two panes that craze on this blast are **`PANE_SLICE_16_10_SW`** (the big pane,
1152 CRACKED voxels) and **`PANE_SLICE_16_15_SW`** (432). **Both are plain `glass`
material** — *not* the `glass_screen_green` / `glass_screen_amber` variant panels
(which live at gu x=5..8, y=9 and the blast does not reach).

## 3. Measurements (this session, `INFILTRAITOR_GLASS_OLIVE_PROBE` — since reverted)

Pixel samples on the crazed pane region, GLASS map, blast at gu (13,13):

| state | crazed pane pixel | note |
|---|---|---|
| normal, ~90 frames post‑blast | `(142,162,79)` | olive: g > r > b, low blue |
| normal, ~240 frames | `(115,133,47)` / `(106,122,45)` | still olive, slightly darker |
| **uncrazed** glass, same frame | `(64,74,91)` | normal blue‑grey glass |
| after rotation to E | neutral (olive gone) | reproduced every run |
| glass panes hidden (`_glass_layers.visible=false`) | **`(164,164,5)` pure yellow** | a yellow *thing behind the pane* is revealed, pane‑rectangle shaped |
| panes **and** craze sprite (`_glass_crack_root`) hidden | `(101,101,2)` darker yellow | a yellow slab still stands where the panes were |
| `crack_color` forced to red on the craze sprites | web strands go red, **fill stays yellow** | the yellow is behind the craze sprite, not its output |

`PANE_TINT[0]` (plain `glass`) = `Color(0.47, 0.63, 0.90)` blue. A blue MULTIPLY tint
over a bright‑yellow background gives olive‑green. **So `glass_pane.gdshader` is doing
the right thing on wrong input** — the bug is the yellow behind the pane.

### Isolation results

1. **dev vision OFF** → olive barely moves (`20002 → 17187` matching px; pane pixel
   `(115,133,47) → (106,122,45)`). **Not a dev/HUD overlay.**
2. **hide the craze sprite** (`_glass_crack_root`), panes visible → olive *increases*
   (`→ 25874`). The whitish craze web was slightly veiling the olive, not causing it.
3. **hide the glass panes** → ~75 % of the olive gone; what remains is the pure
   yellow `(164,164,5)` behind. **The pane composite tints that yellow → olive.**
4. **hide `_glass_backbuffer`** (the `BackBufferCopy`) → **no change** to the pane
   pixel (`(115,133,48)`). The pane is **not** picking the yellow up from
   `glass_screen` / `SCREEN_UV` via the BackBufferCopy node. (Godot still resolves
   `hint_screen_texture` without the node; and the yellow is directly behind the pane
   in screen space regardless.)
5. **force `crack_color` red** → proves the yellow FILL is not the craze shader output.
6. **node sweep** (`self` + `_voxel_renderer` + `VisionController` children, hide one
   at a time): only hiding the **entire `_voxel_renderer`** kills the yellow (`n=15`).
   No single `voxel_layer_72..103`, `glass_backbuffer`, or `glass_crack_root` removes
   it. Biggest single drop is `voxel_layer_79` (FLOOR_TOP). ⚠️ **The sweep is
   confounded** — it takes ~60 frames and the transient VFX overlays (smoke / spark /
   ember, z 37‑39) decay across it, so `smoke_spark_overlay`'s apparent large drop is
   not trustworthy.

### At a CRACKED glass voxel (L80, e.g. grid `(88,87)`)

- opaque layer cell: **EMPTY** (correctly erased — glass never lives on the opaque layer)
- glass sublayer cell: `src=18` (a face‑mask atom), atom centre `(0,0,0,0)`, modulate white

So neither the opaque nor the glass layer at the pane holds anything yellow — **the
yellow is seen *through* the erased pane gap**, from something further back / lower.

### Shader state (both craze sprites, `glass_crack.gdshader`, field mode)

`crack_color`, `crack_opacity`, `crack_strength` — unset on the material → shader
defaults `(0.90,0.94,1.0)` / `0.80` / `1.0`. `crack_field=true`,
`crack_field_origin`/`dir`/`pane_lo`/`pane_hi`/`crack_occupancy`/`crack_opening`
all bound and sane. **No shader compile errors in the boot log.**

## 4. What §18.14b got wrong

§18.14b (from `INFILTRAITOR_GLASS_WARM_PROBE`, commit `03444a61`) claimed the cast is
**"warm blast content in the framebuffer sampled via `SCREEN_UV`"**, rooted in the
**G‑D18b z‑bump** putting the glass composite over a floor crater. This session:

- Hiding the `BackBufferCopy` changes the pane pixel **not at all** → the SCREEN_UV /
  backbuffer path is not how the yellow reaches the pane.
- The cast is **stable for 4 s**, not a fading warm ramp.
- The **floor crater renders correct dark soot** in the same frame (FLOOR‑CRATER‑01
  is fixed) — the yellow is *not* the crater.
- The crazed panes are plain `glass`, and the yellow behind them is a clean
  pane‑shaped slab — consistent with a wall/pane‑anchored effect, not a floor one.

The `SCREEN_UV` note may still be partly right (the pane clearly shows *something*
behind it), but the "warm blast content / crater in the backbuffer" story is not it.

## 5. Open leads for next session

1. **Name the pure yellow `(164,164,5)` slab.** It is pane‑shaped, in the
   `_voxel_renderer` subtree, blast‑view only, cleared by rotation. Bisect cleanly:
   hide opaque `voxel_layer_80/81/82` **and** `_glass_layers[80/81/82]` individually,
   with a fresh control between each and VFX frozen or long‑decayed (wait ≥400
   frames, or gate the VFX overlays off up front) so the decay confound is gone.
2. **Rotation clears it → it is applied at render time during the blast and not
   replayed on rebuild.** That points at a *transient* effect, not persisted damage
   state. Check `play_consequence_light()` and the VL light‑field **alt minting** for
   a non‑greyscale / warm modulate on the wall the pane sits in — `_ensure_light_alt`
   is supposed to be `Color(lum,lum,lum,soot_alpha)` (greyscale), so a warm alt there
   would be the bug.
3. **The atom BLUE channel (`t.b`) is the tint index `glass_class_tint()` reads.**
   Even though the crazed panes are plain `glass`, verify no CRACK / craze path
   writes a *variant* tint index (green=2 `(0.24,0.62,0.34)`, amber=4
   `(0.82,0.60,0.20)`) into a plain‑glass voxel's atom. `glass_screen_amber` tint is
   very close to the observed yellow.
4. Consider whether the yellow is the **craze OPENING mask or occupancy image**
   bound as a shader texture being *drawn* somewhere (an `ImageTexture` rendered
   raw), or a `_glass_rim` source.

## 6. Evidence (committed)

`Screenshots/history/glass_olive_audit_{1..6}_*.png`:

1. `_1_normal` — the olive cast, view N, as seen normally.
2. `_2_panes_hidden` — `_glass_layers` hidden: the pure yellow behind, + the craze web.
3. `_3_panes_and_craze_hidden` — panes + `_glass_crack_root` hidden: the dark‑yellow
   slab still stands.
4. `_4_craze_forced_red` — `crack_color` forced red: web red, fill still yellow.
5. `_5_after_rotation` — view E: the cast is gone.
6. `_6_floor_top_hidden` — `voxel_layer_79` hidden (biggest single sweep drop);
   the yellow slab survives it.
