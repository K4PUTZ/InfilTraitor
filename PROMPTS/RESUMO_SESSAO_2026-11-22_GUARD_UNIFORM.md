# Session summary 2026-11-21 / 2026-11-22: the guard's uniform re-cut, baked from the Tripo source, painted by piece; installed

This session worked on ENEMIES E-2, the FID guard's uniform. The plan is the truth: `PROMPTS/PLANNING/ENEMIES_MASTER_PLAN.md`
§12.14, its last paragraph. This record is the resume point. It follows `RESUMO_SESSAO_2026-11-21_GUARD_NECK_RELOAD.md`, whose
head-map items still stand.

## Rulings (Director)
- *"Falta corrigir o defeito na gola da camisa. E eu queria dar uma geral na roupa como um todo, acho que está com baixa resolução
  e qualidade ruim. Da uma analisada no mapa UV e veja o que você consegue fazer pra deixar com uma aparência mais profissional."*
  (2026-11-21). The answer was a prototype in `temp/`, shown before anything was installed.
- *"Deixa sem a camiseta. Queremos usar a cabeça em outros corpos. Possivelmente ainda vamos melhorar o uniforme, mas por enquanto
  vamos assim mesmo. Pode instalar no game."* (2026-11-22). So:
  - No white undershirt in the V, on either map. The head map stays body-neutral.
  - The prototype goes in as it was shown, at 2048 (the size of the prototype he saw).

## Done
- **Analysis of the installed uniform (2026-11-21).** The smart projection had:
  - 838 islands, 332 of them a single triangle;
  - 26 % of a 1024 map used, about 6 texels per figure-centimetre (the face has 33).

  The paint placed details by bone rules, beside Tripo's modelled pockets and buttons. The collar's defect was the V rule painting
  skin and white on the collar's inner faces. The actor shader lights only 0.72-1.0. The neck's streaks in the V are his head map's
  rows: unchanged.
- **`tools/asset_generation/tripo/enemy_uniform.py` (new).** The prototype ported into the pipeline, in Blender's Python (numpy and
  mathutils; no scipy, no PIL). It has three steps:
  - The layout: Tripo's pieces, tailor's panels, disks, unwrap, pack.
  - The Cycles bake from the source: AO at 7 cm and at 1.2 cm, and the normal.
  - The paint by piece. The bleed is jump flooding, in place of scipy's distance transform.
- **`enemy_texture.py`.**
  - The uniform's UVs and map now come from `enemy_uniform`.
  - The old body rules are gone: V zone, undershirt, pockets, placket, cuffs, stripe, shoes.
  - The head path is unchanged, apart from the head-only raster and the undershirt removed from the generated head.
  - The command takes `<source.glb>` before `[paint.blend]`.
  - The keep, carry and repaint rules are per map.
  - The GLB's previews are 512 each.
- **Installed (2026-11-22)** with `ENEMY_NO_CARRY=1 ENEMY_REPAINT_BODY=1`:
  - The new `game/ENEMY_FID_MALE_LIGHT.glb`, the 2048 `textures/enemy_fid_male_body.png` and the regenerated
    `work/FACE_PAINT_ENEMY_FID_MALE.blend`.
  - The source `source/tripo_cop_male_no_rig.glb` is committed: it is now a build input.
  - Godot reimported the files.
- **Measured and checked:**
  - Layout: 133 islands, 52.7 % of the map used, a median of 17.1 texels per figure-centimetre. This equals the prototype's figures
    (same formula on its saved triangles).
  - The Head mesh in the GLB is identical to the committed one, attribute by attribute. His head PNG is untouched (md5
    `3065c19d…`).
  - The Body keeps the same 4 452 triangles, corners and skin weights.
  - A test build and the real build are byte-identical (GLB and map).
  - Renders of the prototype and of the installed uniform, same cameras: `temp/enemies/uniform_install/renders/cmp_full.png`,
    `cmp_collar.png`, `cmp_game.png`.
  - The board in four views, before and after: `temp/enemies/uniform_install/board_guard_7_before_after.png`.
  - `verify.py smoke` green (48 s).

## State at the close
- **In the game:** the guard wears the 2048 tailored uniform with his head map of 2026-11-21. The uniform map costs +2 MiB of GPU
  memory (2.67 MiB compressed, against 0.67 MiB); not measured on the Moto, under the 5 % rule.
- **The uniform map is generated** (the Director has not painted it). Once it exists a re-run keeps it like his maps;
  `ENEMY_REPAINT_BODY=1` paints it afresh.
- **Untracked, left alone** (the Director's or earlier sessions'):
  - his `textures/enemy_fid_male_master.psd`;
  - `work/HEAD_BODY_ENEMY_FID_MALE.blend`, `work/enemy_fid_male_head_DEFEITO.png`, `work/enemy_fid_male_head_chin_blend_layer.png`,
    `work/enemy_fid_male_head_uv_guide.png`;
  - the GLB's extracted previews in `game/`;
  - the two deleted files `textures/cop_male_face_master.jpg` and `textures/enemy_fid_male_face_guide.png`, deleted before this
    session and not staged.

## Next
1. **The collar's streaks** (unchanged from the last record): he paints rows y 835-1012 of the head map, then it is reloaded:
   compare his PNG with the PSD, reimport, render, board capture, `verify.py smoke`, commit.
2. **The uniform, later, if he asks.** What is open:
   - the shoes' stretch;
   - the packing, at 52.7 % (it could reach about 60 %);
   - the right piping's top tick at the waistband.
   
   A second body (the female guard, another faction) needs its pieces checked against `enemy_uniform._kind_of`.
3. **The plan's queue:**
   - the guard measured on the Moto;
   - the female guard;
   - the other factions' guards;
   - the officers' own bodies;
   - the accessories (December).

   Still paused: the shotgun draw (H3). Still left: the stray `Icosphere` in the light GLB.

## Traps
- **The build's input still lives in `temp/`:** `temp/enemies/split/light_flat.glb`. A layout rebuild after a wipe must remake it
  first. The source GLB, by contrast, is versioned now.
- **Rebuilding over his maps needs `ENEMY_NO_CARRY=1`** whenever the maps already fit the layout. Without it the carry resamples
  them.
- **To regenerate the uniform, add `ENEMY_REPAINT_BODY=1`.** Without it the existing uniform map is kept. A kept map of another size
  stops the build with a hint.
- **The packed layout depends on the face order of the input.** The same `light_flat.glb` gives the same map. A different input with
  the same geometry may place the islands elsewhere, and then the carry moves a painted uniform across.
