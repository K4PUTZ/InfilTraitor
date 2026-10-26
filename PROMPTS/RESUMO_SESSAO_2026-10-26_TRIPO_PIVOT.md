# RESUMO DA SESSÃO — 2026-10-26 — The characters move to Tripo: a whole model, their Mixamo rig, our code adapts

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`). Blender and the Tripo web app; nothing in Godot.
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-26_V6_SHEETS_GENERATED_COAT.md`.
**Decision:** `ACTOR_MASTER_PLAN` **D85** (it holds the measurements in full; this record is the resume point).

## 1. Questions and rulings (Director)

- **Is a Tripo3D model viable?** The Director generated models on Tripo's site and asked. The answer hinged on the licence first:
  - Tripo's Terms §5.2.1: for FREE users Tripo keeps every right to the inputs and the outputs.
  - §5.2.2: PAID users hold the rights to theirs.
  - The Director subscribed ("o serviço básico (starter)") and generated after it, with Privacy set to Private.
- **"A gente só vai usar os modelos do tripo, não vale a pena ajustar para o Hunyuan."** Generate the whole model with its pieces, possibly with their rig.
- **"Talvez seja mais inteligente modificar nosso código para usar o mecanismo deles, em vez de ficar sofrendo pra fazer conversões."**
- **Ratified:** "registre o D85 (só modelos do Tripo, rig Mixamo deles, o que foi medido)", and the coat-weight script goes into the repo as a tool.

## 2. The ladder (what each Tripo try returned)

| Try | Settings | Result |
|---|---|---|
| 1 | "formal male character", one turnaround image | TWO headless figures in one FBX (front + side read as two people); ~4 975 tris each, quads; no rig; a 4096² texture on 1 189 UV islands |
| 2 | The coat alone; Smart Mesh, Quad 5 000; front + left views | 10 106 tris, hollow, two walls, no UV. In `COAT_SRC` it flared 36 cm behind the body (the fit sliced VERTEX rows; a sparse quad mesh breaks that). Fixed by surface samples in a scratch copy, then dropped with the route |
| 3 | The detective; Smart Mesh, Quad 10 000; front + left; Rig Humanoid / Mixamo; 13 clips | One mesh, 10 956 v / 19 951 tris; 62 welded pieces; 65 Mixamo joints with fingers; ≤4 influences; a 1 m figure; root motion in the Hips; the coat's skirt weighted to the HANDS |

## 3. Built: `tools/asset_generation/tripo/tripo_coat_weights.py`

- **What it does** (the rules and the measured gap are in its header):
  - strips forearm / hand weights off everything but the sleeves and the hands' own pieces;
  - hangs the skirt from Hips + Spine, following each side's thigh more toward the knee.
- **Usage:**

  ```
  TRIPO_GLB=in.glb TRIPO_OUT=out.glb [RV_OUT=dir RV_CLIPS="run.001,..."] blender -b -P tripo_coat_weights.py
  ```

  `RV_OUT` writes before / after clay renders and one sheet per clip.
- **On the real file:** 528 vertices stripped, 704 re-hung. The flaps are gone on run, stealth walk, box_01 and agree.
- **Checked:**
  - deterministic: the output is byte-identical with and without the renders;
  - a wrong input (the coat alone, no rig) exits 1 with the reason.

## 4. Traps

- **One figure per view slot.** A turnaround sheet as a single image gives one figure per drawing.
- **Hands beside the coat in the input pose.** The auto-rig gives the skirt to the hands. Spread the arms (~40°) in the input; the tool fixes the rest.
- **Tripo's segmentation refuses Quad models** ("Modelos Quad não suportam segmentação").
- **Tripo splits vertices along every hard edge** (its faceted shading). Islands must be read on the WELDED surface, or the coat is dozens of pieces.
- **Blender's glTF importer adds a 42-vertex bone-shape icosphere.** Pick the skinned mesh with the most vertices, not the first mesh.
- **Tripo exports a 1 m figure and bakes root motion into the Hips.** Both must be handled on import.
- **Re-exporting after a clay review render bloats the mesh** (59 780 vertices from flat shading). Restore the materials and smooth flags first: the tool does.
- **The hat generated with the head fuses the hair under it.**

## 5. Open (D85 has the full list)

- **Pieces and states** (coat off, hat ↔ goggles, black style, faction zones):
  - route A: Triangle → segmentation + part completion → remesh to quads → rig, to test once;
  - route B (the fallback): a whole model per state on the same skeleton.
- **The same Mixamo rig on every biped:** prove it on a second character.
- **Import steps:** scale to the game's height; strip the Hips' horizontal root motion; `ActorMesh3D` reading `mixamorig:` bone names.
- **The 43 UAL clips:** retarget them once to Mixamo, or drop them for Tripo's clips.
- **Still to do:** textures, the LOD, the female base, face expressions on a Tripo head.

The before / after sheets are rebuilt by the tool's `RV_OUT` from the source GLB in `ASSETS/MODELS/` (git-ignored).
