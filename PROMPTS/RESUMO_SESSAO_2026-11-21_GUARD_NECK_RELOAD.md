# Session summary 2026-11-20 (evening) / 2026-11-21: the guard's neck below the jaw line; the Director's cheeks reloaded; the collar next

This session worked on ENEMIES E-2, the FID guard's head map. Plan: `PROMPTS/PLANNING/ENEMIES_MASTER_PLAN.md` §12.14, its last two
paragraphs. The plan is the truth; this record is the resume point.

This record replaces `RESUMO_SESSAO_2026-11-20_GUARD_HEAD_MAP.md` on the head's projection. That record's "Next 1" is done. Of its
four candidates, the Director meant number 2: the hard seam along the jaw.

## Rulings (Director)
- *"a imagem está correta, mas não existem os polígonos certos mapeados"* (2026-11-20). The neck must read the skin he painted
  under the jaw's outline. Done in `fbf74e82`.
- *"Deixa, eu pinto"* (2026-11-20). He will paint out the fine vertical streaks in the collar's V himself; the layout stays
  (`7defbc12`).
- *"Vamos fazer essa correção na próxima sessão. Eu tive que fazer uma pequena alteração na cabeça, então precisamos recarregar
  novamente."* (2026-11-21). The collar paint goes to the next session, and his change to the head has to be reloaded first.
- *"pode recarregar agora"* (2026-11-21, the same evening). The reload is done now, not next session.

## Done
- **`fbf74e82`: the neck hangs below the jaw line.** `_neck_layout` in `enemy_texture.py` unrolls the neck downward from the seam
  it shares with the face. The band at the map's foot is retired.
  - Measured: the seam has 17 vertices; 2 face triangles joined the neck; 3 vertices were moved into their ring.
  - The neck covers 154 845 texels with 0 overlaps. Every other FaceUV triangle is unchanged.
  - Dot test: the four spots under the jaw now land under the jaw.
- **`7defbc12`: the squeezed rows measured.**
  - The zone, on the 1024 map: 2× or more on rows y 835-1012, 4× or more on 873-1012, 8× or more on 978-1012.
  - The fix: a tone smooth along each row, carried down to the bottom edge.
  - Sheet: `temp/enemies/neck_hang/neck_squeeze_zone_sheet.png`.
- **His cheeks reloaded (2026-11-21, committed together with his PSD and PNG).**
  - His PNG was reimported by `Godot --headless --path . --import`; that one file was reimported, and its imported source md5 is
    now `3065c19d…`.
  - Before and after on the model: `temp/enemies/reload_2026-11-21/cheeks_before_after.png`.
  - On the board (`guard_7`, four views, no error in the log): `temp/enemies/reload_2026-11-21/board_guard_7_sheet.png`.
  - `verify.py smoke` green.

## State at the close
- **In the game:** the guard on the `fbf74e82` layout, with his head map of 2026-11-21 (md5 `3065c19d…`), committed together with
  his PSD. `verify.py smoke` green on 2026-11-21 (48 s).
- **His change of 2026-11-21, reloaded the same evening.** He saved `textures/enemy_fid_male_head.psd` at 15:57 and exported
  `textures/enemy_fid_male_head.png` himself at 15:58. Measured at the reload, with psd-tools:
  - **The PSD changed only on the cheeks.**
    - Layers: two new ones, `Layer 9` and `Layer 9 copy` (boxes x 655-913 and 110-368, y 475-821). `Layer 3` is now hidden and
      `Layer 3 copy` was added. A second UV-guide smart object was added, hidden.
    - The composite saved inside the PSD moved 70 255 px by 8 levels or more, every one inside the two cheek layers' boxes.
    - Every other layer's pixels are unchanged.
  - **His PNG is his Photopea export of that PSD, not a second edit.** Against the composite saved inside the PSD:
    - 98.7 % of px are within 3 levels, with no bias.
    - 448 px differ by 8-26 levels, on the eyes' catchlights, the mouth and the nose's highlight. Side by side at 4x they look the
      same, and the difference shows no stroke.
    - The few px in "the eyes' highlights and the nose's tip" of the first diff were this export, not paint.
    - His PNG is used as is.
  - **The collar's rows** are unchanged.
- **psd-tools is not installed on the Mac.** It ran from a venv in this session's scratchpad (Homebrew Python 3.11, psd-tools
  1.27.0); a later session will not have it.
- **Untracked, left alone:**
  - `work/enemy_fid_male_head_uv_guide.png`, the guide for the current layout (cyan FaceUV, orange the neck).
  - The guide inside his PSD still shows the old band layout.

## Next
1. **The collar's streaks.** He paints rows y 835-1012 (§12.14's last paragraph), then the map is reloaded the way his cheeks were.
   The game reads `textures/enemy_fid_male_head.png` itself (`actor_mesh3d.gd`, the `maps` entry of `TRIPO_BY_FAMILY`). A paint
   change therefore needs no GLB rebuild, only Godot's reimport (or focus the editor):
   `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`. In order:
   1. Compare his PNG with the composite saved inside the PSD (psd-tools, in a venv in the scratchpad). A rounding difference like
      the 2026-11-21 export is fine. Ask him only if the difference shows an edit: a stroke, or a change outside the layers he
      touched.
   2. Reimport.
   3. Render the head before and after.
   4. Capture the board: `python3 tools/persistent/capture.py --map PLAYGROUND --still guard_7 --mode detail --view all`.
   5. Run `verify.py smoke`.
   6. Commit the PSD and the PNG together.
2. **The plan's queue, as before:**
   - the guard measured on the Moto;
   - the female guard;
   - the other factions' guards;
   - the officers' own bodies;
   - the accessories (December).

   Still paused: the shotgun draw (H3). Still left: the stray `Icosphere` in the light GLB.

## Traps
- **The build's input lives in `temp/`.** Every `enemy_texture.py` build since 2026-11-20 reads
  `temp/enemies/split/light_flat.glb`. Nothing in `tools/`, `PROMPTS/` or `docs/` names that file or the command that made it, and the
  Director may wipe `temp/` at any moment.
  - A paint reload does not need it.
  - A LAYOUT rebuild after a wipe must remake it first. `enemy_light.py -- <rigged.glb> <out.glb> <palette.json> [target_tris]`
    makes a light GLB; whether it made this one was not checked.
- **Rebuilding over his maps.** Every layout rebuild over his maps runs with `ENEMY_NO_CARRY=1`. Without it, the carry reads the
  old layout and rewrites his maps.
