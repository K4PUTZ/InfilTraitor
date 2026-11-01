# Session record — 2026-10-30/31: the PRIMARY items, the clean base, and the coat's faction emblem as a decal

Picks up `RESUMO_SESSAO_2026-10-30_MALE_WAIST.md` ("NEXT SESSION: texturing the models"). The texturing build itself (`ACTOR` D87's T1-T4)
did not start: the Director first settled what the bases are and how an item may vary, then asked for a test of an emblem on the coat.

## Directed (Director)
- Asked whether both figures, the clean base above all, exist as separate files made official as the source of truth.
- The clean base: *"A base limpa são os agentes com roupa básica (camisa, calça, sapatos, sem cinto, chapeu e sobretudo). Os sapatos a gente
  vai querer separar depois pra vender, mas por enquanto a base serve."*
- The primary items: *"A gente vai ter um número específico de itens primários, que fazem parte tanto do gameplay quanto da estética: camisa,
  calça, sapato, cinto, gravata, sobretudo, chapéu [...] Alguns deles tipo a camisa, calça e sapatos, nunca vão sair. Não tem o agente
  descalço. Porém queremos ter a opção de trocar o calçado a qualquer momento. QUeremos trocar a camisa por outra camisa colorida com estampa
  de cavalos marinhos [...] Posteriormente teremos itens secundários (armas, proteção, etc), e itens terciários (oculos, broches, poderes)."*
- Asked whether a shirt's colour and print can change on the same model. Answer: yes, both are parameters of the material. The condition is
  clean UVs on the piece; a plain colour hides bad UVs, a print does not.
- The test and the rule: *"Eu queria por exemplo testar fazer uma 'tatuagem' (decal) por cima do sobretudo com um símbolo de cada facção [...]
  A idéia é a gente testar se não vai ficar distorcido ou borrado. Porque aí a gente fixa em um estilo 3D de camisa e o resto não pode musar o
  mesh, no máximo trocar cor e estampa/material. Mas eu estou considerando a hipotese de refazer os dois modelos nus, e depois vestir com
  camisa, calça, etc."*
- On the renders: *"Ótimo. Eu gostei das versões com as capas, mas seria melhor sem o criculo em vbolta do símbolo, e nem o fundo branco. Só o
  logotipo colado no casaco."* Then: *"Sim, a gente precisa melhorar a leitura dos logos. Mas por enquanto está ok. Vamos documentar tudo e
  atualizar os master plans."*

## Ratified (in the plans)
- **`ACTOR` D89:** seven PRIMARY slots (shirt, trousers, shoes, belt, tie, overcoat, hat), each swapped and sold. Shirt, trousers and shoes
  are never off. Each slot keeps one 3-D style; a variant changes only colour, print and material. The tiers: primary, secondary (weapons,
  protection), tertiary (glasses, pins, powers). The clean base is the basic dress. The nude remake is OPEN (Claude: not now).
- **`ACTOR` D90:** a faction's emblem on the coat is a projected decal in a UV channel of its own, the logo alone.
- **`ACTOR` D87 amended:** the surface also takes a print and decals; T3 includes clean UVs per primary.
- `COSMETICS_MASTER_PLAN` v0.7 (C4, §9.2's coat-back row, §9.4's readability note); `DESIGN_MASTER_PLAN` §10 (the three tiers mapped onto the
  classes); `MODEL_INVENTORY` rule 6 (bare = the basic dress, not a nude body); `CHARACTER_MASTER_PLAN` top block; `CLAUDE.md`'s
  character row.

## Found
- **The bases.** `MALE_AGENT_BASE` (official since 2026-10-30) still carries the belt, as two loose objects (`Outfit_Belt`, `Outfit_Buckle`).
  Hidden in a render, they leave the shirt's hem clean over the trousers. The female has no official file: `FEMALE_BASE_edit` is the worked
  one (its belt was pushed into the trousers on 2026-10-29), `FEMALE_BASE` is Tripo's raw file. Both carry Tripo's tie and a stray `Icosphere`
  (80 faces). `ASSETS/` is git-ignored, so the sources live on one disk only.
- **The decal is sharp.** Projected into its own UV channel, the emblem is crisp up close and at the game camera. Baked into the coat's own
  1024 texture, its edges step.
- **The coat's back is not ready for prints.** At rest the emblem stays round, apart from a fold modelled into `COAT_BASE` under it. In motion
  it waves and folds: little in the walk, strongly in the run with the arms swinging and in the stealth run. The back is weighted to the
  shoulders and arms (C4), so an arm going back drags the middle of the back. The plain coat had hidden this.
- **Readability.** Without the white disc, the Bunsen Burners' orange flask vanishes on the mustard coat at the game camera (the collapse
  `COSMETICS` §9.4 had measured). Line art (the drone) weakens; solid silhouettes (the shield, the grub) read.

## Measured (Blender EEVEE, both figures dressed in `COAT_BASE`)
- Back width at shoulder-blade height: male 0.31 H, female 0.28 H. The emblem square is 0.6 of it: 0.19 H / 0.17 H (~34 / 31 cm at 1.80 m).
- Coat vertices fully under the emblem: 204 (male), 194 (female), ~15 across.
- Clips: the stealth run (`correr_furtivamente_segurando_uma_pistola_aponta`, the bank's pair, 120 frames), the male's `walk` (57) and `run`
  (31). The Hips' translation was muted (the figure runs in place).

## Built
- `tools/research/coat_decal_lab/` (README with the commands):
  - `emblems.py`: the four placeholder emblems, the logo alone by default, `medallion` for the first look;
  - `dress_both.sh`: both figures dressed in `COAT_BASE`;
  - `decal_render.py`: the projection, the 1024 bake for comparison, rest, motion and game-camera renders;
  - `decal_sheets.py`: the contact sheets.
- Nothing was written to `ASSETS/`, and no engine code changed.

## OPEN — where to resume
1. **The clean base files, awaiting the Director:**
   - `FEMALE_AGENT_BASE` from `FEMALE_BASE_edit`;
   - `MALE_AGENT_BASE` without the belt and the Icosphere, the belted file kept as history;
   - the tools' usage lines on the two names;
   - a backup of `ASSETS/MODELS/`.
2. **The nude remake (D89, open).** Claude's recommendation is not now; a partial body (forearms, neck) if a skin-showing variant ever comes.
3. **The coat's back weights (D90 owed), before any print or emblem on the back.** The middle of the back goes on the spine chain, and the
   shoulders' influence fades toward the armholes. The fold under the emblem is owed as well.
4. **D87's T1-T4**, with clean UVs and clean weights per primary before prints.
5. **The emblem, later:**
   - the logos' readability, when the real logos are drawn;
   - its size and height;
   - the Godot side (UV2 or a custom channel + the mask) and its Moto cost.
6. **Still open from 2026-10-30:**
   - the coat in `sit`, the armpit fold, the female's collar;
   - MV-1's per-clip review sheets and the ~100 new clips per figure;
   - the T1 slot table;
   - the male's 9 k-tri hair against the Moto budget.

## Later: `ASSETS/MODELS/` organised (Director: "Sim, aplica")
- `official/`: `FEMALE_AGENT_BASE` (from `FEMALE_BASE_edit`, the Icosphere dropped), `MALE_AGENT_BASE` (the belt and the Icosphere dropped),
  `COAT_BASE`. Both bases exported in POSE with their clips (female `climb`, `dive`; male `dive`, `heart_pose`).
- `sources/`: the Tripo downloads renamed (`tripo_female_base` <- `FEMALE_BASE`, `tripo_male_base` <- `MALE_BASE`, `tripo_female_nocoat` <-
  `female+no+coat`, `tripo_female_nocoat_02` <- `female detective no coat 3d model`, `tripo_female_coat_hat` <- `female+detective+figure+3d+model`,
  `tripo_male_nocoat` <- `MaleCharacterNoCoat`, `tripo_male_coat_hat` <- `MaleCharacterHatAndCoat`, `tripo_male_detective` <-
  `Male+detective+figure+3d+model`, `tripo_trench_coat` <- `leather trench coat 3d model`, `formal_male_character.zip`).
- `history/`: `FEMALE_BASE_edit`, `MALE_BASE_edit` (+ `.blend1`), `MALE_BASE_edit_waist`, `MALE_AGENT_BASE_belted`, `MALE_AGENT_BASE_hat`.
- The tools follow (`bank_sources.json`, `dress_both.sh`, `tripo_waist.py`'s usage line); `dress_both.sh` dressed both new bases cleanly.
  Item 1 of OPEN above is done except the backup.

## Later: texturing, and the two base Agents closed in Blender (ACTOR D87)
- Decisions taken as recommended (Director: "pode seguir tomando as decisões recomendadas"): a painted head map of ours, 512 px per material,
  1024 for the head. Concept art: `REFERENCES/Personagem/concept_2026-10-31/` (local).
- Built: `tripo_uv.py` (clean garment UVs; limbs cylindrical, never mirrored), `tripo_detail_maps.py` (our grey details), `tripo_head_map.py`
  (painted head maps), `tripo_look.py` (faceted, matte, dressed states, test knobs), `build_agents.sh` (both Agents end to end);
  `AGENT_SURFACE.json` (the palette); `tripo_dress.py` gained the belt mask under the coat and the hair re-seat before the hat.
- Ruled on renders: white ties, dark-brown belts with light-grey buckles; the female's tie shortened; the female's original head kept (a
  subdivided one was tried); faceted + matte after the concept art; a charcoal coat; the female's cuffs without the sleeve fit; the male's
  sleeves as they were (a hands-only fit was tried and reverted: "Piorou"); matte strand hair, the same brown; her fringe; her hat lower.
- Out: `ASSETS/MODELS/official/AGENT_FEMALE.glb`, `AGENT_MALE.glb`, `painted/*_head.png`. Triangles: female ~20 k, male ~25-28 k.
- OPEN: the game LOD (CHARACTER's ~5 k target); T4, the Godot shader and its Moto cost; the clips checked on the final files.

## Later: the game LOD planned (ACTOR D91) — WHERE TO RESUME
- The Director asked whether the light version is converted in-game to swap clothes. Answer recorded as D91: no; each primary slot and the
  body get ONE light mesh made offline in `build_agents.sh` (before the UV and head-map steps), the game only switches pieces on the shared
  rig; a per-piece budget inside ~5 k; one LOD (fixed camera); merging the chosen pieces at load only if the Moto shows draw calls cost.
- **NEXT SESSION:** the light female, compared with the full one at the game camera; then the male; then T4 (Godot shader, Moto cost).

## Later: the light female built (ACTOR D91) — WHERE TO RESUME
- `tripo_lod.py` (new): WELD (Tripo splits vertices at hard edges; a collapse on the shards opened cracks = bright flecks), then collapse-decimate per piece to its
  budget, weights back to 4 influences. `build_agents.sh` runs it for `LIGHT_FIGS` (default `female`) -> `official/AGENT_FEMALE_LIGHT.glb` + `painted/female_head_light.png`.
- Result: the dressed set 20 k -> 4 648 tris (all pieces with variants 35.8 k -> 6.8 k); front / back / game camera clean next to the full one; the `climb` clip deforms alike on both.
- Trap: `tripo_look` reads `painted/<fig>_head.png` beside the surface JSON — a light render needs a copy of the JSON with the LIGHT map under that name (else the face garbles).
- NEXT: the male (`LIGHT_FIGS="female male"`, check his 9 k-tri hair), a `sit` pose check, then T4 (Godot, `ActorMesh3D`, Moto measured). Budgets are a first guess; nothing committed.
- **The light male built too (same day):** the dressed set 4 646 tris (head 4 729 -> 749, hair 9 062 -> 600; all pieces 43 k -> 6.8 k); front / back / game camera and the `dive` clip read like the full one, beard and face kept. `LIGHT_FIGS` now defaults to both. Note: `tripo_look` hides the hat unless `LOOK_HAT=1`; renders of a dressed figure need it. NEXT: T4 (Godot test scene, then the Moto with light vs full).

## Later: the floor leaking through the Agents on the board — CAUSE AND FIX (Director spotted it; his guess was the coat mask)
- **Cause: the `_Coated` masks** (`tripo_dress.py`): the shirt / trousers / belt cut away under the coat leave an OPEN RIM, and through the coat's opening the game's `cull_back` shader sees the rim's BACK and drops it: floor-coloured slits down the front. Measured with a coat-less control: with the whole garments under the coat the chest is clean.
- **Fix:** `FRONT_KEEP` (default 0.05 H each side of the centre; 0.10 first, then lowered after the colour test below): nothing in the front strip is masked. Floor pixels inside the silhouette (game capture minus an empty-scene capture, `ingame_holes`): full female 93 -> 16, full male 74 -> 42, light female 21, light male 43 (the floor of legitimate gaps between arm and body).
- **Wrong turns, recorded:** (1) a "turn the decimate's flipped faces back" step in `tripo_lod.py` made the light figures WORSE (107 -> 277, 74 -> 380) and is removed; (2) Blender draws the back of a face and the game does not, so a probe made in Blender's default view sees none of this: `tripo_crack_probe.py` now sets the Workbench's `show_backface_culling` (the material flag is Eevee's: it changed nothing); (3) the audit's "Icosphere" is the glTF importer's own bone shape, not in any file; (4) skin weights of coincident vertices agree (0 mismatches, a few in the male's hair), so the skinning is not the cause.
- Tools: `tripo_mesh_audit.py` (per piece: split vertices, components, open edges, winding, degenerate faces, weight mismatches), `tripo_crack_probe.py` (8 views from the game camera, holes inside the silhouette; states dressed / base / unmasked). Bench states: `agent_<light|full>_<female|male>[_nocoat|_unmasked]`.
- **Colour test (white shirt under a black coat; bench `_tint`, probe `PROBE_COLORS=1`): the masks ARE needed** (unmasked, the shirt shows through the sleeve and chest on both figures). FRONT_KEEP 0 leaves slits (and the trousers show under the tie on the male); 0.10 lets white flecks out at both armpits; 0.05 is the pick. Built official files are at 0.05. NOT re-checked in the game after the last build: the desktop Godot hung at boot (log stops at `[WALK-WARM]`) for every run after ~19:00, display kept awake, cause unknown.
- OPEN (was): whether the masks are still needed at all; the male head is 6 pieces (eyes / mouth), 68 glued edges, not a visible defect.
- **The armpit specks (Director's marked screenshot):** the coat HAD real holes where the sleeve meets the body (open loops: four tiny ones per armpit on the female, two ~17 cm on the male, three at the front-left). `tripo_dress.py` now closes every open loop up to `HOLE_MAX` (0.20 m of perimeter; pockets, collar, hem and front opening stay), patches wound to agree with their neighbours (`flipped_edges` 0), then a 0.5 mm weld. In game: the female's four armpits are clean, the male's right armpit too.
- Godot desktop boots hung for hours ("[WALK-WARM]" last line) while the display was kept awake; one capture per foreground call worked, background runs did not. Cause unknown.

## Later: the armpit mark on the male, found and fixed (corrects the two bullets that stood here)
- **I was wrong twice, in order.** (1) I called what was left "geometry, not a hole" and tried sphere gussets (dropped: they cover the open window beside the aperture). (2) My gap analysis
  looked at the four GAMEPLAY views (az 45/135/225/315) while the Director's capture was the bench's FRONT view: the bench rotated the rig 45 degrees to face the camera, which the game
  never does (`ActorMesh3D.yaw_for_direction` turns the figure by the grid step, multiples of 90 degrees, so the camera on the diagonal sees 3/4 views). Bench facings are now
  `agent_<..>_f0 .. _f3` (the four real ones); no suffix = the front, a diagnostic view.
- **The marked hole was REAL** (reproduced in Blender at az 0 with per-piece / per-coat-component colours, culling on): the ray through it meets no front face and ends on the back of the far wall,
  passing 9 mm from faces 89 / 76. It is a 12-edge, 21.7 cm open loop of the male coat at (-0.112, 0.012, 0.669), the right armpit, left open because my `HOLE_MAX` was 0.20 m and the loop is a
  FIGURE 8 (two cycles meeting at a vertex) which the old fill refused. `close_small_holes` (`tripo_dress.py`) now splits every open boundary into simple cycles and closes each with a FAN from
  its centre (each triangle runs the shared edge opposite to the face already on it: winding never wrong; no n-gons for the exporter to triangulate; centre weights = mean of the rim's).
  `HOLE_MAX` 0.50 m; loops longer than 0.12 H and centred below 0.52 H (the pocket slits, z 0.49) stay open; 2-edge slivers are skipped. Male coat: only the pockets and the main edge stay open.
- **The white fleck beside it was a different thing:** a section of the figure at z = 0.698 shows the shirt crossing the coat's outline where the lapel meets the sleeve root (five 2 cm2 faces,
  one vertex outside the coat). New mask rule (SHARDS, `SHARD_Z` 0.60-0.80 H, `SHARD_X` 0.072 H from the centre line): a shirt vertex not inside the coat, off the front strip and the collar ring, takes
  its face. 0.062 and 0.068 also took a strip of lapel-edge shirt and showed the trousers through it at 45 degrees; 0.072 removes the flecks at 0 and 315 degrees and leaves 45 identical; the female is untouched.
- Earlier traps found on the way: my "ghost loops" of 17 and 47 cm were the SHIRT's cuffs and hem (the listing printed both pieces in a row); the glTF round trip is fine.
- Result in game (tinted, floor-coloured pixels inside the figure, empty-scene diff): female 16 / light 17, male 9 / light 8 at the front; male 16-22 at the four real facings.

## Later: the armpit V made less acute (Director: "um tecido normal iria naturalmente se acomodar e emendar mais pra baixo")
- Cause measured: sections of the coat at z 0.74 / 0.71 / 0.68 / 0.65 / 0.62 / 0.59 show sleeve and torso ONE surface above z 0.70, then a round sleeve tube tangent to the side panel (gaps 3 mm / 7 mm / 1.5-2 cm / 3 cm): an acute V whose apex sits at z about 0.69, and the game's camera sees the floor through it (the bench's FRONT view; at the 3/4 views the walls block it).
- **The masks are NOT the cause** (the Director asked): with the whole shirt back, white flecks of it come out through the armpit instead of a more natural apex.
- Tried and dropped: pulling the sleeve's inner vertices to the torso panel (deformed the sleeve; one side's channel is between two TORSO surfaces, one of them my fan patch; glTF seam copies need one decision per position).
- Built: `close_armpit_slits` (`tripo_dress.py`): rays from the game's camera (30 deg down) find each see-through slit; per row the slit's THROAT (narrowest depth) gets a thin TWO-SIDED panel anchored in both walls; closed for `ARM_COVER` 0.045 H below the apex, then a quarter-circle taper (`ARM_TAPER` 0.03 H, a blunt end). The panel starts 6 mm ABOVE the apex (a thread of slit was left otherwise). 144-160 faces, no new holes, the four gameplay views unchanged; the female gets it too (her enclosed floor pixels drop in two views). In game the slits start about 5 cm lower, full and light.
- Trap: the glTF round trip is fine; the audit's open loops of 17 / 47 cm were the SHIRT's cuffs and hem.

## Later: the Agents on the Moto (2026-11-01, T4's measurement; Moto g04s ZF524T5TG5, APK `export_android.py`, PLAYGROUND portrait, MAX_FPS=0)
- Method: `tools/persistent/actor_scenario.py` (one boot per model, an `idle` segment with nothing spawned, then 9 rigs in a 3 x 3 block inside the view, a synthetic sine on the Mixamo bones so the skeleton is LIVE
  and in place); `actor_bench agent_<light|full>_<female|male>` flat albedo, the dressed set only. Logs: `docs/measurements/actor_<model>_x9.log`. The Android preset now excludes `ASSETS/MODELS/sources/*` and `history/*`
  (they would have been packed, +85 MB). The first run was DISCARDED: its `idle` already held the rigs (no wait after the mark) and the `dive` action walked the figures out of the view (3-4 of 9 visible).
- Idle (same in all five boots: 20.5 ms/frame, GPU 19.0, 65 draws, 41 216 primitives). With 9 rigs, frame time / GPU time / draws / primitives:
  | | ms/frame (delta) | GPU ms (delta) | draws | primitives |
  |---|---|---|---|---|
  | shipped agent (`agent_live`, 11 k tris, 20 joints) | 26.3 (+5.8) | 24.7 (+5.5) | 98 | 133 972 |
  | female LIGHT (4.6 k tris, 89 joints) | 23.5 (+3.0) | 21.9 (+2.9) | 153 | 79 471 |
  | male LIGHT | 23.5 (+3.0) | 21.9 (+2.9) | 151 | 78 875 |
  | female FULL (19.8 k) | 29.4 (+8.9) | 28.1 (+9.1) | 153 | 218 125 |
  | male FULL (25 k) | 30.3 (+9.8) | 28.9 (+9.9) | 152 | 246 729 |
- Reading: the cost is the GPU and follows the triangles (about 0.05-0.075 ms per 1 000 primitives); the render CPU stays at 1.2 ms with +88 draw calls. **The light Agents cost about HALF of the shipped agent per figure
  (0.33 vs 0.64 ms), 89 joints and 11 pieces notwithstanding**; the full ones are for the showcase only. PSS: about +5 to +10 MB for 9 rigs (about 670 MB total, ceiling 1.0 GiB).
- NOT measured: the painted maps / detail textures and the real shader (flat albedo here), a skeleton driven by real clips, the masked-variant swaps, one run per model (the idle baseline did not move between boots).
