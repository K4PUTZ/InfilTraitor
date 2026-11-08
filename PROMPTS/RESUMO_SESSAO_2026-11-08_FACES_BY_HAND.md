# Session record 2026-11-08 — the faces painted by hand, installed; the shirt "lining" explained (CHARACTER §7a, ACTOR D108)

Continues `RESUMO_SESSAO_2026-11-07_TEXTURING_POLICE_COAT_SIDES.md`, whose first NEXT item was the Director painting the faces by hand.
Ends with both faces installed in the LIGHT Agents and the plan's step 1 closed.

## Done
- **Both faces painted by the Director** (Photopea, from a layered PSD) and installed: `painted/<fig>_face_master.png` (2048, his) -> the
  512 map `painted/<fig>_head_light.png` (Blender's own `image.scale`, the scaler `tripo_face_apply.py` uses) -> `glb_swap_image.py` on
  `AGENT_<FIG>_LIGHT.glb`, image name `<fig>_head_light`. Checked: the image read back from each GLB equals the PNG on disk. The male was
  updated twice (his edits at 00:37) and the female once more at the end of the session; each time the same three steps.
- Commit `135b9698` holds the first install of both faces; the female's last update and the docs of this record are in the commit after it.

## The method for hand-painting a face (reuse it)
1. Open `ASSETS/MODELS/fit/FACE_PAINT_<FIG>.blend` (the pieces the head does not need are hidden in it now: coat, hat, hat hair, the three
   `_Coated` pieces, the icosphere). Texture Paint on `Body_Head`, or paint outside Blender.
2. **A layered PSD with the UV lines as a guide layer** was made without Blender's UV exporter (`bpy.ops.uv.export_layout` needs a GPU and
   fails in background): the UVs of `Body_Head` are dumped to JSON in a background Blender, the polygon outlines are drawn with PIL on a
   2048 transparent PNG (`v` flipped: `y = (1 - v) * 2048`), and `psd-tools` (a venv, `PSDImage.new` + `create_pixel_layer`) writes the master
   and the guide as two layers. The files lived in `temp/face/` (disposable). Hide the guide layer before exporting the PNG over the master.
3. A PNG saved by Photopea is 2048 RGB, which is what the chain reads. `painted/<fig>_face_master.psd` is git-ignored (30-36 MB).
4. `face_paint.json` keeps `"hand": true` for both: the painter refuses to overwrite the hand paint.

## Findings (Blender previews are not the game)
- **The "lining" the Director saw coming out of the shirt is the `_Coated` pieces over the whole ones.** Each Agent GLB carries BOTH
  `Outfit_Shirt` (700 tris) and `Outfit_Shirt_Coated` (300 tris, the faces the coat always hides removed), likewise trousers and belt. The
  game shows one set (`TripoFigure.DRESSED_ONLY_PIECES` vs `UNDRESSED_PIECES`: dressed it always hides the whole pieces). In Blender both
  are visible, and the Coated fragments poke through the whole shirt as blue patches. The whole shirt alone is clean in both figures.
  There is no game state "without the coat": the game always wears the dressed set.
- **The dark patches on the faces are Blender's shading, not the map.** The 2048 masters are uniform skin; a render with the sun's shadow off
  is the same; a render with no light at all (emission from the map) shows clean skin in both, LIGHT and FULL alike (the FULL head carries
  no texture in `AGENT_<FIG>_BASE_A.glb`: it needs `tripo_face_apply.py` to wear the master). Which of the preview's effects (the faceted
  750-triangle head, EEVEE's occlusion) paints them was not isolated.
- **Heads:** the female's FULL head has the same 750 faces as her LIGHT; the male's has 4 748 against 749. Her deficit is geometry (posters only).
- **The shirt's and the trousers' "defects" (plan §7a item 2) were NOT reproduced** with the whole pieces: the four maps are a uniform weave,
  no dark line or break in them; the unlit and the lit renders (front, side, back, both figures) show no dark lines on the trousers. What
  does show on the whole shirt: a wide step at the female's cuffs and a fold on the male's left sleeve (geometry). The Director parked it.
  The `_Coated` pieces alone (what the game draws under the coat) were not searched for dark lines.
- **Game capture:** the take `agent_walk` (PLAYGROUND, `INFILTRAITOR_TRIPO_FIGURE=<female|male>`) frames the figure too small to judge a
  face; the anchors `poi:agent_walk_south` and `region:agent_walk_area` do not exist in the map's `layout` (the capture fails loudly).

## Open (the ordered list is `CHARACTER` §7a)
1. Commit the female's last texture update (GLB + two PNG) with these docs.
2. The shirt's and trousers' defects: the Director parked it; needs a screenshot of a defect (piece and angle) or the `_Coated` pieces alone.
3. The lower face for the game camera; the male's neck line; the dress variants in the chain (`build_light_base.sh`); the in-game dress
   switch and the turning tie; the factions' symbols; the female's face geometry; the official FULL GLB's old head map (unchanged).
4. A map anchor for the agent in PLAYGROUND (`layout` POI) so a still can frame the figure close.

## Traps met
- `bpy.ops.uv.export_layout` in a background Blender: `GPU functions for drawing requires the gpu module to be initialized`.
- zsh reads `$var:word` as a modifier: write `${var}:word`.
- A FULL head with no material renders black under an emission-only test; the head must wear the master first.
- `open -a` with a file path loads a PNG or a PSD in the Photopea Chrome app; it opened the file both times.
- A `^C` in the tool log is not the Director.
