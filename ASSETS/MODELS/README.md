# ASSETS/MODELS (versioned since 2026-10-31; organised by ACTOR D89; cleaned 2026-11-04)
Only official/ is imported by Godot. sources/, history/ and fit/ are read by Blender scripts alone and carry a `.gdignore`, so the editor never
imports them (each .blend would start Blender on a scan, each GLB would extract its textures beside it). Test renders, work files and every other
disposable output go to temp/ (CLAUDE.md), never here. Out of git: Blender's .blend1 backups and the raw .zip download.

official/  the source of truth
  FEMALE_AGENT_BASE, MALE_AGENT_BASE  the clean bases: shirt, trousers, shoes, tie; no belt, hat, coat
  COAT_BASE                           the coat
  AGENT_<FIG>.glb, AGENT_<FIG>_LIGHT.glb  the built Agents (tools/asset_generation/tripo/build_agents.sh)
  detail/, painted/                   their maps (ACTOR D87). The AGENT_*_<part>.png beside the GLBs are Godot's extractions, not versioned
base/      FROZEN 2026-11-04: the permanent base of the two characters, read-only (ACTOR D99)
  AGENT_<FIG>_A.blend          the A pose with the coat, as the Director finished it by hand
  AGENT_<FIG>_T.blend          the T pose with the coat, as the Director finished it by hand (the former COAT_FIT_<FIG>_T_HAND.blend)
  MANIFEST.sha256              `shasum -c MANIFEST.sha256` from this folder proves the four are untouched
  A and T are welded separately, so their vertex counts differ per piece: a transition must map them first. A change means a new file and a new D-row, never a save over these
fit/       the coat's fit, Blender working files (ACTOR D97)
  COAT_FIT_<FIG>.blend         the A pose with the fitted coat
  COAT_FIT_<FIG>_T.blend       the T built from the A (tripo_fit_tpose.py)
  COAT_FIT_<FIG>_TFIX.blend    the A rest untouched, the T's correction in a TFix shape key
sources/   Tripo downloads, content untouched, renamed:
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
