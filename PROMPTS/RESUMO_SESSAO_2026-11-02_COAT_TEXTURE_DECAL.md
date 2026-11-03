# Session record — 2026-11-02: the armpit shards, the coat's texture, the sold mesh and the emblem decal

Picks up `RESUMO_SESSAO_2026-11-01_COAT_LEGS_PUSH.md` (open then: the armpits in a run, T4, the female clips). The decisions are `ACTOR` D95 and D96; this is the path to them.

## Directed (Director)
- Start: "ainda temos alguns probleminhas nas axilas durante a corrida"; later, clarified: the red hatching in his images was his own marking over BLACK bits of the coat ("o buraco existe mesmo; o que me incomoda são esses artefatos"), and "o mesh está criando artefatos no Blender, antes de chegar no Godot".
- His reading of the cause: loose pieces ("tampa de bolso, forro, tudo que estiver saindo da superfície") should be merged into the coat; "deletar não, vamos mesclar". Then: texture the coat as it is, with the trims indicated by the texture ("vamos experimentar com merge, usando a textura pra indicar os aviamentos"); "o relevo soldado seria legal, mas ... vai virar ruído".
- The look: references of a black faceted leather trench coat; fabrics suggested and applied (hat in the coat's leather, ecru poplin shirt, charcoal wool twill trousers, oxblood silk tie, shoes in a darker leather; trousers NOT leather, "não quero que vire muito latex-herói"); the store look is the sold `COAT_BASE` in a matte leather, roughness 0.55 ("Essa ficou a melhor").
- "cadê a malha original do coat que fizemos no tripo?" -> the lineage render; "a gente vai vender o mesh full ... a segunda versão ... vai ser a exibida na loja"; the dressing "ficou bem torto": to be redone with his hands.
- The emblem: `REFERENCES/coat_decal.png` (a flaming skull); "um pouco mais pra cima, pra ficar entre as omoplatas, e não brigar com o cinto"; then the plan: in-game decal with only a free zone on the model, a user folder like the facades', dimensions and position formalised, planned in the master plan BEFORE the test.

## Found
- **Every in-game capture of the day before the reimport showed the previous day's model:** `capture.run_godot` loads `.godot/imported/*.scn`, which a rebuild does not refresh. Run `godot --headless --path . --import` after each rebuild. The Blender-side measurements stand; the game-side A/B of the panel, the fills, the weights and the shell tests are void and were not redone.
- The black bits under the arm are the coat's 13 LOOSE islands (buttons, pocket flaps, cuff tabs, belt tabs, four pieces at the hips), bound to the nearest vertex of the generation's coat; found by tracing rays through the pixels the Director marked, then listing the islands of the finished coat. The patch work of the last days (weights, caps, V panel, fills) did not touch them.
- `COAT_BASE` (4 999 faces) and the original Tripo coat (`sources/tripo_trench_coat.glb`, 10 106) are good; the dress step and `tripo_lod` (886 faces) degrade them: see D96.
- The panel-bigger, hole-fill-off, ease, liner, underlay and refine experiments changed nothing visible and were removed (Blender metrics that counted silhouette holes or flipped faces did not track what the eye saw: silhouettes have legitimate gaps).
- Blender traps: `-b` exits 0 on a Python error; a coat's vertex colour (the push mask) multiplies into its texture in a Blender render; `tc.load`'s `B` holds only the bones `NEED` names.

## Built (the scripts and the plans are committed; the rebuilt GLBs and the painted PNGs are outputs and are not)
- `tripo_coat_regions.py`, `tripo_surface.py`, `tripo_coat_weld.py`, `tripo_coat_merge.py`, `tripo_coat_decal.py`; helpers in `tripo_common.py` (`write_png`, `detail_tiled`, `textured_material`, the active vertex colour exported); `coat_push.py` embeds `COAT_TEX`; `build_agents.sh` (`--python-exit-code 1`, the regions and surface steps, flags `COAT_WELD` / `COAT_MERGE`); `AGENT_SURFACE.json` (the fabrics); the bench draws a textured piece without its tint; `tools/persistent/actor_video.py` (`record` / `combine`).
- Videos and stills (git-ignored): `videos/run_asis_vs_welded.mp4`, `Screenshots/coat_*` (the lineage, the store views, the matte levels, the decal options).
- The installed `ASSETS/MODELS/official/AGENT_*.glb` are the MERGED variant of the last build (`COAT_MERGE=1`), with the diagnostic coat texture embedded; the painted maps are in `official/painted/`.

## NEXT (in this order)
1. The decal pipeline test of D95, end to end, on the current dressing: the zone step in the build, the channel layout (push direction into COLOR.a, `DecalMask` in COLOR.b, `DecalUV` in UV2), the shader, the `emblem_` branch of `TextureResolver` and its selftest, `check_emblem.py`, the `.gitignore` whitelist for `ASSETS/emblems/`, the bench, the Moto.
2. The dressing redone from `COAT_BASE` with the Director (D96).
3. The LIGHT coat after it.
Before any of it: the Director picks as-is / welded / merged for the loose pieces (the video compares the first two; the merged one was only seen alone, in Blender).

## Resume point
Plans are written (D95, D96, pointers in CHARACTER and COSMETICS). Nothing of D95 beyond the zone script exists. Check `git status` first: the working tree holds the rebuilt GLBs (merged variant) and the painted PNGs, uncommitted.

---

## Addendum (same day, later): the decal pipeline test closed; the male animations planned; the coat's hand fit begun

**Built and committed:** D95 end to end (`coat_decal_zone.json` + `coat_decal_zone.py`, push direction in COLOR.a / mask COLOR.b / DecalUV UV2, `CoatEmblem` with ONE shared texture per emblem, the `emblem_` resolver branch + selftest, `check_emblem.py`, `.gitignore` whitelist); Moto g04s, 9 light Agents: 25.7 ms with and without, PSS 681 vs 686 MB (a texture per coat cost ~250 MB). `MOVEMENT` §3.2 plans the male's 30 missing clips from `tripo_male_ANIMATIONS.glb`; the Tripo source GLBs (ANIMATIONS files included) are versioned, the zip stays out.

**The coat's hand fit (D96 step 2), all under `tools/asset_generation/tripo/` and `ASSETS/MODELS/fit/`:** `tripo_coat_fit_min.py` (COAT_BASE on the base figure, sleeves turned onto the arms, a `Fit` shape key) -> `COAT_FIT_<FIG>.blend`; the Director's hand fit of the male is in its Basis / Fit keys; `tripo_coat_fit_relief.py` (triceps + forearm walls pulled out), `tripo_coat_fit_armpit.py` (back pleats smoothed), `tripo_coat_fit_rigid.py` (the `Rigid` lapel pin), `tripo_fit_tpose.py` (a T-pose working state, `COAT_FIT_<FIG>_T.blend`: collarbone takes 25 % (male) / 50 % (female) of the turn, the coat's chest weight to Spine2), `tripo_coat_fit_round.py` (armpits rounded in T), `tripo_shirt_sleeves.py` (sleeves 10 % toward the arms; a build step, NOT yet rebuilt into the Agents).

**Traps:** a shape key written with `foreach_set` is NOT saved by Blender (write through the edit mesh / bmesh); the select-all pose clear skips hidden bones (the male's file held a leftover pose: zero every pose bone); a plain Laplacian on the shirt's armpit tears it (layers lie close).

**NEXT (not done):** `tripo_fit_from_tpose.py` (the EXACT per-vertex inverse of the blended bone matrix, using the T file's coat weights, with an unedited-roundtrip check against the A file), then relief / armpit scripts on the female, the shirt's armpit in T (hand sculpt or a bridge), rebuild the Agents with the sleeve step and the fitted coat, then the LIGHT coat. Left open in Blender: `COAT_FIT_FEMALE_T.blend`.
