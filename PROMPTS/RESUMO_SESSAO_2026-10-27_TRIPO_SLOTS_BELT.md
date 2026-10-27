# RESUMO DA SESSÃO — 2026-10-27 — Tripo characters into our slots: the assembly tool, the no-coat variant, the hat, the belt rebuilt

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`). Blender and the Tripo web app; nothing in Godot.
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-26_TRIPO_PIVOT.md`. **Decision:** `ACTOR_MASTER_PLAN` D85 (its later paragraphs).

## 1. Rulings (Director)

- **Female base:** the Director's female sheet, same outfit, her own face. **P2** for the main characters; **P1** to be compared on the first enemy.
- **Segmentation route:** generate in Triangle, then segment + part completion, then rig. The rig KEEPS the parts (106 skinned meshes on one Mixamo skeleton).
- **No-coat variant:** generated from the same sheet, to supply the shirt sleeves and the full hair.
- **Fit direction:** fit the garment to the BODY, never the body to the garment. The base body is shared by every version and cosmetic.
- **Hat:** rigid on the head, placed by the face, 1.5 cm back, its back tilted 8° down about the brow; the hair under it is MASKED.
- **Belt:** buckles will be SOLD, so the belt is rebuilt: the Tripo band flattened into the trousers, OUR strap on the measured curve, and the buckle
  a slot of its own (new buckles from an image of the buckle alone, fitted to the slot).
- **Animation:** Tripo's AI clips give the raw motion; we make them game-ready (strip root motion, loops, D61 step timing, mirrors). For cover → run
  → cover, generate one multi-segment take, cut it into pieces and chain the pieces in code.

## 2. Built (`tools/asset_generation/tripo/`)

- **`tripo_common.py`:** what the Tripo tools share (load in rest pose, weights, welded islands, the coat rules, review renders).
  `tripo_coat_weights.py` uses it, and its output is byte-identical to before the split.
- **`tripo_assemble.py`:** a segmented, rigged Tripo character becomes one mesh per slot: `Outfit_Coat / _Shirt / _Tie / _Belt / _Buckle /
  _Trousers / _Shoes / _Hat`, `Body_Head / _Hands / _Hair`.
  - **Anchors:** from each part's bone family and size; the head is the face a front ray meets.
  - **Details:** a band resting on the hat goes to the hat; a part in front of the face goes to the head; any other head part is hair; a head-weighted
    part touching a garment goes to that garment (a collar); anything else goes to the nearest garment sharing its bones.
  - **Weights:** the coat fix; a garment detail lying ON its garment takes the garment's weights, others keep Tripo's.
  - **The belt rebuild** (above).
  - **Corrections:** `SLOT_OVERRIDE` fixes a part by hand.
  - **Review renders:** `RV_OUT` writes them.
- **Commits:** `a7fe8fd7`, `e6f95c49`, `d4cfe17b`, `9ef8f988`, `45eddb22`.

## 3. Measured

- **The two female generations:** the same 65 joints, about 2.5 % of H apart; the no-coat one is 0.981 tall.
- **Hair mask:** 870 of 1 878 hair faces are hidden under the hat.
- **Buckle:** 6.0 × 2.3 × 1.0 % of H, 39 tris; it fits the slot (6 × 4.5 × 1.5 %, ≤ 500 tris).
- **A failed export:** one export of the no-coat variant came out with a broken rig (everything weighted to the hips, 54 bones); a re-export fixed it.

## 4. Traps

- **Exporting a frame.** Exporting while a clip plays freezes the pose into the mesh; export in rest pose.
- **Segmentation varies run to run** (106 parts vs 14), so the rules must not assume either.
- **The belt is not level**, and per-sector ledges catch pocket edges. A tilted-ring fit is clean.
- **Rest the strap on the trousers' outermost point** over the band, or it sinks in at the front.
- **A detail weighted from a distant garment stays behind in motion** (the forearm sleeves in "fall").

## 5. Open (next session starts here)

- **The belt needs adjusting (Director, 2026-10-27, "precisa dar uma ajustada no cinto"):** look at it with him first; then strap width and
  thickness, the front, the buckle seat.
- **The coat on the base body:** fit it to the body, weight it from the body, mask the shirt under it. The dress-fit test script is in the session
  scratchpad, not in the repo.
- **Belt on the coat model:** its strap is thin at the front. That model only lends the coat and the hat.
- **Not done yet:** game import (scale, root motion, `ActorMesh3D` bone names), textures, LOD; the male via the same route.
