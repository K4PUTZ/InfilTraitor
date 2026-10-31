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
