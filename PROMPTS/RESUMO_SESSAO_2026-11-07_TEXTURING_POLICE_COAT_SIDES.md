# Session record 2026-11-06/07 — texturing the Agents: the POLICE dress, the coat's two sides, the female's face (CHARACTER §7a, ACTOR D108)

Continues `RESUMO_SESSAO_2026-11-06_LIGHT_WALK.md` (the Director's next step there: the texture). Ends with both LIGHT Agents installed in the
POLICE dress, the coat CLOSED by the Director, the female's face retouched, and the faces handed to the Director to paint by hand
(2026-11-08). The ordered NEXT list is `CHARACTER_MASTER_PLAN` §7a ("Status 2026-11-07").

## Decided (Director)
- Textures: the game camera first, the models ready for any poster / cutscene technique; both hairs brown; the hats' colours TEMPORARY
  (female purple `#4B2266`, male navy `#1C2A4A`); Claude paints, the Director fixes defects.
- The coat's look from his references: matte leather with a slight sheen, no latex; the sheen level "Suave está bom". After the textures'
  Moto run he asked to stop re-testing the characters' performance ("Podemos desencanar de ficar testando performance para os personagens?").
- The trousers first in the coat's leather, the shoes glossier; then the shirt BLUE and the tie WHITE (a Moonwalker homage, IP advice given:
  the colours alone are free, never his marks, poses or names).
- **The tie turns at the knot** (white face, black back), player-controlled, for hiding / disguise: planned, not built (`DESIGN` §10.6).
- **Two dresses:** POLICE = denim jeans `#255C91`, the coat YELLOW (mustard) out, the emblem the police symbol in the shirt's blue; CIVIL
  ("paisana") = dark trousers and the coat inside out (black). The police coat's lining stays BLACK (it is the civil face).
- The lining leaks are fixed starting with D94 ("Sim, começar pelo D94"); the coat's work is then CLOSED ("Vamos fechar o casaco", meaning
  to wrap it up, not to button it), its Moto run not needed ("com certeza é irrisório").
- Faces: all three priorities (the defects, the game readability, the female's geometry); the female's brows "mais pra cima, no topo da
  cavidade ocular" (his marked screenshot). He will paint the faces by hand himself (2026-11-08).

## Done (commits on `main`)
- `46b6d89d`, `7ff01828` TX-1..TX-4, TX-6: surfaces for head / hands / hair / belt / buckle; **FaceUV** (`face_uv_map.py`, cylindrical,
  a function of position, so the FULL and the LIGHT share ONE 2048 master); `tripo_face_paint.py` + `face_paint.json` paint the masters;
  `tripo_face_apply.py` puts FaceUV + the master at 512 on the LIGHT head.
- `2f41768a` the coat's master painted on the FULL (`tripo_coat_regions.py`, edges) and carried to the LIGHT's UV (`tripo_coat_transfer.py`).
- `2c444d2c`, `691e7659` the leather's sheen (`plane_sheen()`, `TripoFigure.SHEEN`), Moto measured (+5.2 / +4.8 ms vs +4.8 / +5.0 without).
- `1fed51ef` `glb_swap_image.py`: a texture swapped in a finished Agent with every other byte identical.
- `93dd4851`, `29c68f4e`, `eacd6b1b` the blue shirt / white tie, the POLICE dress (`CR_PALETTE=police`, the `denim` detail, `emblem_police`),
  the black lining recorded.
- `9e33c97b` **D94's lining gap:** a coat face turned to the body stops `push_lining_gap` = 20 mm short (`coat_push.gdshaderinc`).
- `9da60a86` **The coat's two sides:** `tripo_coat_sides.py` (the wall in the coat map's alpha, the colours as `coat_sides` extras via
  `glb_coat_extras.py`), `actor_coat3d.gdshader` draws a back-facing fragment in the other wall's colour (`TripoFigure.apply_sides`); the
  last step of `build_light_base.sh`.
- `49cc566b` the female's face: brows wider and darker, forehead filled, the temple's black wedge filled, `eye_skin` (the under-eye box).
- This record's commit: her brows raised 60 px; `tripo_face_paint_file.py` + `ASSETS/MODELS/fit/FACE_PAINT_<FIG>.blend` (the Director's
  paint files); `face_paint.json` `"hand": true` for both (the painter refuses to overwrite); `DESIGN` §10.6; the plans' status.

## Measured
- Faces (Blender): female FULL face 518 tris vs male 2 044, the same texel count; the deficit is geometry and paint, not resolution.
- Moto g04s, 9 walking, uncapped: textures +4.8 / +5.0 ms (D105 untextured +5.0); the sheen +5.2 / +4.8 (both within the noise).
- The coat's walls: 4.0 / 3.6 mm apart at the median on the skirt (female / male), up to 22 / 16 mm (p90).
- At the game camera the hat's brim hides the eyes and brows of both figures; nose, mouth and chin read.

## How the lining leak was found and closed (the method to reuse)
1. Paint the lining a loud colour (magenta) in a COPY of the LIGHT's coat map, `glb_swap_image.py` it in, take `agent_walk`, crop the figure
   frame by frame; restore the GLB byte for byte afterwards (`cmp`).
2. Toggle one cause at a time: `push_on` off in `CoatPush3D` (temporary edit, reverted) separated D94's part; the idle in Blender with no push
   showed the rest was the POSE (a cut of the outer wall opening over a continuous lining).
3. Two dead ends, both reverted: re-weighting the lining to the outer wall (one lining vertex sits under two panels); repainting the faces a
   pose reveals (the back lining seen through the open front is the same face). The fix is the side the eye meets.

## Open (the ordered list is `CHARACTER` §7a)
1. The Director paints the faces (`fit/FACE_PAINT_<FIG>.blend`, Image > Save); then Claude installs the 512 map with `glb_swap_image.py`.
2. The shirt's and the trousers' defects (seen in Blender with the coat hidden): not investigated; the plan is in §7a.
3. The lower face for the game camera; the male's neck line; the dress variants in the chain (it builds the CIVIL coat; the installed POLICE
   one and the jeans were made by hand); the in-game dress switch and the turning tie; the factions' symbols; the female's face geometry
   (posters only); the official FULL GLB's old head map.
4. `ASSETS/emblems/emblem_police.png` exists only on this disk (`*.png` is git-ignored there).
5. Remaining one-pixel dark flecks on the coat's edges (close up only).

## Traps met
- A Blender round trip of a finished Agent (`tripo_surface.py`) wrote the coat's COLOR_0 alpha as 1.0 (the skirt glued, the coat through the
  legs) or exported it as VEC3 float; `glb_keep_coat_color.py` then wrote VEC4 over the coat's JOINTS (the skinning broke in Godot). A texture
  or extras change on a finished Agent is a byte edit: `glb_swap_image.py`, `glb_coat_extras.py`. `glb_keep_coat_color.py` is superseded.
- `-CAMERA_DIRECTION_WORLD` gave no sheen; the eye direction is `INV_VIEW_MATRIX[2].xyz`.
- Blender's glTF import shows the coat RED (COLOR_0 read as a vertex colour) and the figure in its first animation frame: clear the
  animation and set the armature to REST before judging.
- The grey band on the female's forehead in EEVEE is the fringe's shadow, not the map (the game draws no shadow on the face).
- Blender's `image.save()` of a PNG loaded as RGB drops an alpha written into its pixels: `tripo_common.write_png` now writes RGBA.
- A Blender GUI started from the Bash tool with `&` dies with the shell: save a `.blend` in the background, then `open -a Blender <file>`.
- `capture.py --view N` alone writes the still without the view suffix; the walk tracker latched onto a guard past frame ~64.
