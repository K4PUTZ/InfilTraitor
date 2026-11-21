# Session summary 2026-11-20 (evening) / 2026-11-21: the guard's neck below the jaw line; the Director's cheeks; reload next

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

## State at the close
- **In the game:** the guard on the `fbf74e82` layout, with the head map committed at `ec373a61` (md5 `6e1890da…`).
  `verify.py smoke` was green on 2026-11-20.
- **His change of 2026-11-21, not committed.** He saved `textures/enemy_fid_male_head.psd` at 15:57 and exported
  `textures/enemy_fid_male_head.png` himself at 15:58. Compared with the committed map:
  - **The cheeks.** 71 557 px differ by 8 levels or more, all on the two cheeks (x 114-1017, y 260-796), plus a few px in the eyes'
    highlights and on the nose's tip. Only 10 px differ by 32 or more. They show in magenta in
    `temp/enemies/neck_hang/head_change_2026-11-21.png`.
  - **Everything else.** 752 154 px differ by at least 1 level, all of them by less than 8. The cause was not checked: it may be his
    Photopea export against the usual composite, or an adjustment he made.
  - **The collar's rows** are unchanged.
- **psd-tools is not installed** in any Python on the Mac today. Checked: the Framework 3.14, Homebrew, `/usr/local`, `/usr/bin` and
  Blender's own Python. The usual export (`topil()`, checked against `composite(force=True)`) needs it installed again, e.g. in a
  venv in the scratchpad.
- **Untracked, left alone:**
  - `work/enemy_fid_male_head_uv_guide.png`, the guide for the current layout (cyan FaceUV, orange the neck).
  - The guide inside his PSD still shows the old band layout.

## Next
1. **Reload his head map.** The game reads `textures/enemy_fid_male_head.png` itself (`actor_mesh3d.gd`, the `maps` entry of
   `TRIPO_BY_FAMILY`). A paint change therefore needs no GLB rebuild, only Godot's reimport:
   `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`, or focus the editor. In order:
   1. Compare his PNG with the PSD's composite. If they differ beyond the cheeks, ask him which one is right.
   2. Render the head before and after, to show the cheeks.
   3. Capture the board: `python3 tools/persistent/capture.py --map PLAYGROUND --still guard_7 --mode detail --view all`.
   4. Run `verify.py smoke`.
   5. Commit the PSD and the PNG together.
2. **The collar's streaks.** He paints rows y 835-1012 (§12.14's last paragraph); then reload again the same way.
3. **The plan's queue, as before:**
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
