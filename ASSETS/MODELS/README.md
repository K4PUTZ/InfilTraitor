# ASSETS/MODELS (versioned since 2026-10-31; organised by ACTOR D89; cleaned 2026-11-04; ONE FOLDER PER CHARACTER since 2026-11-19)

**Where a model lives is asked, never typed** (the Director, 2026-11-19): `tools/asset_generation/model_paths.py` for the tools
(`python3 tools/asset_generation/model_paths.py --sh <figure>` for a shell script, `--check` proves the folders) and
`godot/scripts/systems/model_paths.gd` (`ModelPaths`) for the game. A reorganisation edits those two files, nothing else.

    actors/
      agent/<female|male>/  source/ (ignored)  base/ (ignored)  work/ (ignored)  game/ (imported)  textures/ (imported)
      agent/shared/         COAT_BASE, AGENT_SURFACE.json; source/ = the shared downloads (ignored)
      shared/detail/        the tileable grain maps
      enemies/<FACTION>/<character>/   the same stages; skins/<skin>/ for a character's variations
    props/                  Tripo's prop and gadget generations, raw, split and zoned (was sources/tripo_props*; ignored)
    history/                earlier steps (ignored)

Godot imports only game/, textures/, agent/shared/ and shared/detail/; every ignored folder carries a `.gdignore` (each .blend would
start Blender on a scan, each GLB would extract its textures beside it). Test renders and disposable output go to temp/ (CLAUDE.md).
Out of git: Blender's .blend1 backups and the raw .zip download. The old-to-new map of the move is in git history (2026-11-19).
The sections below keep their content from before the move; read each folder name through the map above.

actors/agent/<fig>/game/ + textures/ + actors/agent/shared/  the source of truth (was official/)
  FEMALE_AGENT_BASE, MALE_AGENT_BASE  the clean bases: shirt, trousers, shoes, tie; no belt, hat, coat
  COAT_BASE                           the coat
  AGENT_<FIG>.glb, AGENT_<FIG>_LIGHT.glb  the built Agents (tools/asset_generation/tripo/build_agents.sh)
  detail/, painted/                   their maps (ACTOR D87). The AGENT_*_<part>.png beside the GLBs are Godot's extractions, not versioned
actors/agent/<fig>/base/  the two characters' base, OPEN while they are animated (ACTOR D102; frozen 2026-11-04 at D99/D101, last frozen at 2ee3cf25)
  AGENT_<FIG>_A.blend          the A pose with the coat, hand-finished
  AGENT_<FIG>_T.blend          the T pose with the coat, hand-finished (the former COAT_FIT_<FIG>_T_HAND.blend)
  A and T are welded separately, so their vertex counts differ per piece: tripo_transition.py maps them by UV
actors/agent/<fig>/work/  Blender working files: the coat's fit, corrective frames, SEQ_ / POSE_ / FAMILY_ labs (was fit/) (ACTOR D97)
  RUN_FIX*_FEMALE.blend, IDLE_FIX_FEMALE.blend  baked frames the Director edited; tripo_pose_fix_back.py takes them to the corrective keys (ACTOR D103)
  COAT_FIT_<FIG>.blend         the A pose with the fitted coat
  COAT_FIT_<FIG>_T.blend       the T built from the A (tripo_fit_tpose.py)
  COAT_FIT_<FIG>_TFIX.blend    the A rest untouched, the T's correction in a TFix shape key
  HAT_FIT / HAT_CUT / HAT_SKIN / COATED_<FIG>.blend  the LIGHT chain's stages from the base: hat seated, hair cut, hat skinned, coat-cut variants (ACTOR D106)
  LIGHT_<FIG>.blend            the LOD's output, the game mesh BEFORE the finishing steps: the anchor the Director hand-edits (ACTOR D107); the male's is edited in its Basis,
                               the female's `WalkFix` edits live in LIGHT_FEMALE_WF2.blend (LIGHT_FEMALE_WF.blend is its earlier step)
  WALK_FIX_F<n>_LIGHT_<FIG>.blend  a bank-clip frame baked by tripo_light_bake_frame.py for a hand edit (vertices only), taken back by tripo_pose_fix_back.py
  AGENT_*_A_STRUCT / _FLAP, RUN_FIX_F8 / F9 / DRAPE  dropped coat experiments of 2026-11-05 (D103-D104), kept as record
  FACE_PAINT_<FIG>.blend       where the Director paints a face by hand (CHARACTER §7a, 2026-11-07): the LIGHT at rest, the head wearing
                               ../official/painted/<fig>_face_master.png by path; Image > Save writes the master. Rebuilt by tripo_face_paint_file.py
actors/agent/<fig>/source/ (and agent/shared/source/)  Tripo downloads, content untouched, renamed (was sources/):
  tripo_female_base.glb        <- FEMALE_BASE.glb
  tripo_male_base.glb          <- MALE_BASE.glb
  tripo_female_nocoat.glb      <- female+no+coat.glb
  tripo_female_nocoat_02.glb   <- female detective no coat 3d model.glb
  tripo_female_coat_hat.glb    <- female+detective+figure+3d+model.glb
  tripo_male_nocoat.glb        <- MaleCharacterNoCoat.glb
  tripo_male_coat_hat.glb      <- MaleCharacterHatAndCoat.glb
  tripo_male_detective.glb     <- Male+detective+figure+3d+model.glb
  tripo_trench_coat.glb        <- leather trench coat 3d model.glb
  formal_male_character.zip    <- formal male character 3d model.zip
  tripo_female_ANIMATIONS.glb  99 clips: the male's list without `dive`, which she has in tripo_female_base.glb
  tripo_male_ANIMATIONS.glb    100 clips
history/   the steps: FEMALE_BASE_edit, FEMALE_AGENT_BASE_longtie, MALE_BASE_edit, MALE_BASE_edit_waist, MALE_AGENT_BASE_belted (the official male until
           2026-10-31), MALE_AGENT_BASE_hat
