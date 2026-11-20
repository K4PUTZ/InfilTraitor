# Session summary 2026-11-19 / 2026-11-20 — the FID guard on the board: skinned, painted, a face, head and uniform apart

ENEMIES' first slice (E-2): the male FID guard, the month's one Tripo generation, from the bare Standard to a painted figure on
the board. Plan: `PROMPTS/PLANNING/ENEMIES_MASTER_PLAN.md` §12.11-§12.14 (the plan is the truth; this record is the resume point).

## Rulings of the two days (Director)
- `ASSETS/MODELS/` is one folder per character with its stages inside; a path is asked (`model_paths.py` / `ModelPaths`), never
  typed (2026-11-19; CLAUDE.md).
- The guard's head and uniform are separate maps AND meshes, so a head moves to another body as the Agents' do ("de maneira
  efetiva e completa, mesmo que seja necessário mexer no mesh e no map", 2026-11-20).
- The head map is his: he paints it in a layered PSD in Photopea (`textures/enemy_fid_male_head.psd`); Claude exports the PSD's
  saved composite to `textures/enemy_fid_male_head.png` (what the game reads), checks it on the model and the board, and commits
  both. The image is never filled by code ("Não faz por código, eu prefiro limpar a imagem").
- When paint does not land where it should, suspect the PROJECTION before the image ("O problema não é a imagem, é a projeção na
  cabeça"): his dot test (colour spots painted on the map in Blender's Texture Paint, then looked for on the model) proved it.
- The CHIN BLEND layer Claude appended to his PSD is dropped: he saved the PSD back to its committed content ("Sim", 2026-11-20).

## Done (commits `0628ee73` .. `c43ea66d`)
- The four factions' accessory-sheet prompts (§12.7-§12.10) and the licence note (own generations only).
- The guard skinned on the Agent's skeleton (`enemy_skin_from_agent.py`), lightened (`enemy_light.py`: Tripo's head piece kept
  whole as its own region), painted (`enemy_texture.py`): a uniform map (smart projection) and a head map (the male Agent's FaceUV
  moved by the nose offset, the neck on a band under the face); the Director's face (Nano Banana over his PSD) in; two meshes,
  `Head` and `Body`, on one skeleton; `ActorMesh3D` reads each map by source-material name.
- The head's projection in four steps on 2026-11-20 (§12.14's last paragraphs): the neck below the chin to the band; downward
  faces under the nose sent there too and brought back (they broke the lips and chin); the faces near FaceUV's axis to the band
  (the triangle under the chin), which took the jaw's sides with them; the jaw's sides back on the face (`c43ea66d`: a near face
  joins the band only when its normal's z is under -0.7; the band's height range is pinned to the whole lower head, 0 texel shift).

## State at the close
- The game shows the guard with the head map committed at `ec373a61` on the `c43ea66d` layout; `verify.py smoke` green there.
- **The Director at the close: "de novo o problema é a projeção."** He did not say where. The next session starts by asking him
  what he sees, or by rendering the views he names. Measured candidates, not conclusions:
  1. Downward faces still on FaceUV are squashed in the map: the nose's underside (13 faces at z 0.911, normals' z -0.74 to
     -0.96) and the mouth's slit (4 faces at z 0.893, -0.98 to -1.0, almost no area in the map). A front-low render shows the
     nose's underside as blocky patches.
  2. The jaw's underside and the neck carry the band's flat paint: a hard seam along the jaw's lower edge, with a small step at
     its left.
  3. The jaw's sides are big triangles 3.2-3.5 cm from FaceUV's axis: each spans 268-288 texels of the map's width, so the paint
     is stretched there.
  4. Under all of them: FaceUV is ONE cylinder about the head's vertical axis, and on the guard that axis runs 6 mm behind the
     throat. A projection of its own for the lower face (a planar front, or a second axis forward in the jaw) is a design change:
     the Director's call.
- Files: his PSD (saved 17:46) holds the committed content layer by layer (21 layers, composite = `head.png`) but other bytes
  (metadata), so git lists it as modified: commit or restore it at his word. Untracked in `work/`: `enemy_fid_male_head_uv_guide.png`
  (the current layout: cyan FaceUV, orange band), `enemy_fid_male_head_chin_blend_layer.png` (obsolete),
  `enemy_fid_male_head_DEFEITO.png`, `HEAD_BODY_ENEMY_FID_MALE.blend` (nothing reads it). The guide inside his PSD (a hidden smart
  object) is the old layout. `work/FACE_PAINT_ENEMY_FID_MALE.blend` was regenerated; his 16:52 save is
  `temp/enemies/split/FACE_PAINT_his_save_1652.blend`.
- Helpers, disposable (`temp/enemies/split/helpers/`): `dot_render.py` (a GLB plus a head map with test spots -> front / left /
  right renders), `jaw_probe.py` + `jaw_hits.py` (each head face's FaceUV, normal, distance from the axis and band reason; the faces
  over a given texel), `uv_compare.py` (two layouts triangle by triangle), `uv_guide.py`.

## Traps learned
- A test build of `enemy_texture.py` to another path must set `ENEMY_NO_CARRY=1`: a GLB an earlier test left at that path is read
  as the old layout, the carry runs and the Director's maps are REWRITTEN (it happened once on 2026-11-20; both maps restored from
  git, md5 identical).
- A carry is wrong whenever faces change region (band <-> face): it paints the old region's colour over the new one. When the maps
  already hold the right paint, rebuild with `ENEMY_NO_CARRY=1`.

## Next
1. The head's projection: ask the Director what he sees, then fix it (the candidates above).
2. Then: the guard measured on the Moto, the female guard, the other factions' guards, the officers' own bodies, the accessories
   through Tripo (December).
3. Still paused: the shotgun draw (H3, `PROMPTS/RESUMO_SESSAO_2026-11-18_LONG_GUN_DRAW.md`).
4. Left: the stray `Icosphere` in the light GLB (42 vertices, no parent).
