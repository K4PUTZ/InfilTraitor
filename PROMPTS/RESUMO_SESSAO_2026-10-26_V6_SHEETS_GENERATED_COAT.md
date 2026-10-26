# RESUMO DA SESSÃO — 2026-10-26 — The final look's sheets, a generated coat re-cut to our body, the goggles

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`). Blender and the Director's PC; nothing in Godot.
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-26_COLLAGE_TARGET_FACE_HOODED_EYE.md`.

## 1. Questions and rulings (Director)

- **The final look:** "a gente chegou o visual final do agente". The sheets are in `REFERENCES/Personagem/Referencia/` (git-ignored).
  - They are TF2-style model sheets: a black leather coat, a black shirt and tie, a belt, messy brown hair and stubble.
  - One of them (`image_47ad3232.jpeg`) carries a VALVE mark that the image generator invented. It never goes into a generator uncropped.
- **Paid or local generation?** The Director was tempted by a paid service, then chose the PC, in small steps checked one by one.
  - The PC was reached over JAMES's SSH while "Qwen mode" was on.
- **The goggles (`ACTOR` D83):** the vision leaves the hat-mask for GOGGLES, a piece of their own.
  - The hired assassin wears the mask without goggles.
  - The goggles come from another faction (possibly the Militia), unlock their vision types over time, and are a cosmetic family to sell.
  - The eye glow and its penalty in the dark are theirs. Without the mask, the Agent may wear the balaclava with them.
  - "Hired to attack the player" was only the boss fight: the assassin stays Deacon's man.
- **Delegation:** "Pode continuar desenvolvendo o modelo, tomando as decisões recomendadas, sem perguntar." The choices below are Claude's,
  under it (`ACTOR` D84).
- **Mid-way:** "O sobretudo esta se somando ao agente." The coat sat on the body as a second shell. The fix is the re-cut in §3.

## 2. The PC ladder (generation)

| Step | What | Result |
|---|---|---|
| 0 | Inputs | Clean RGBA crops: body with coat, body without coat, head. The head is unusable: the sheet's frame clips the top of the hair. Later, the coat on its own from the Director's coat sheet. `ARCHIVE/wip/gen3d/prep_inputs.py` |
| 1 | `D:\gen3d` on the PC | uv 0.13.5, Python 3.11.17 and torch 2.7.1+cu126, nothing system-wide. Torch sees the RTX 3060 Ti (fp16 matmul 12 TFLOPS). Pins: `transformers<5` (v5 renamed DINOv2's keys) and `diffusers<0.36` (newer needs a newer `huggingface_hub`) |
| 2 | Hunyuan3D-2mini, shape only, body with coat | 385 562 tris, one piece, watertight, 64 s, 4.6 GiB VRAM. The form follows the sheet; it is a statue |
| 3 | Body without coat | 274 620 tris, one piece |
| 3c | The coat alone | 1 019 286 tris. HOLLOW: two walls 7-16 mm apart, an open front, tube sleeves. Reduced to the coat's LOD budget (1 560 tris, faceted), it held its collar, lapels, epaulettes and cuffs. At the same count, v5.2's coat (its real LOD) read smoother |

Helpers (git-ignored, `ARCHIVE/wip/gen3d/`): `pc.sh` (a PowerShell command on the PC), `pc_copy.sh` (scp both ways), `pc_scripts/`,
`render_compare.py`, `coat_lod.py`, `v6_apose.py` (the sheet's A pose, idle, face close-ups), `v6_pen.py` (penetration counts),
`glb_diff.py`.

## 3. Built: hero v6 knobs in `tools/asset_generation/hero/hero_tailor.py` (off = v5.2)

Build with:

```
COAT_SRC=…/coat_mini_s0.glb LOOK=infil HAIR_CUT=messy BEARD=1 [DECIMATE=0.2 FACETED=1] hero_quick.sh TAG "hawk_nose:0.25,hooded_eyes:1"
```

- **`COAT_SRC`, `coat_from_source()`:**
  1. Scale and place the coat by its shoulder corners.
  2. Pose the upper arms along its sleeves (PCA of the sleeve slices).
  3. Keep the outside wall BY PAIRS.
  4. Re-cut it to our body:
     - torso slices to the tailor's dummy plus 2 cm;
     - the front closed to the sheet's opening;
     - the skirt stretched to a 0.48 m hem;
     - sleeves onto the arms' bone lines, shoulder to wrist, radius plus 2 cm.
  5. Push it clear of the dummy, neck, head, legs and hands.
  6. Weight it from the posed body: hand moved to forearm, the pack hump, the hanging skirt, four influences.
  7. Unpose it by inverse skinning.
  8. Line it with an inward copy carrying the same weights.
- **`LOOK=infil`:**
  - no jacket;
  - a black shirt with `Outfit_ShirtSleeves`, hidden in the coat's state;
  - a matte black tie, plain black trousers, a belt with a silver buckle;
  - a matte leather coat;
  - stubble for `BEARD=1`.
- **`HAIR_CUT=messy`:**
  - our own geometry: a puff mass and edge blade locks, voxel-fused and decimated, shaded flat;
  - brown, not greyed;
  - `Face_HairFree` for the hatless look, `Face_Hair` pressed under the hat.
- **`FACETED=1`:** a flat-shaded game LOD.
- **`tailor_dummy(sleeves=False)`:** the torso alone.
- **`hero_review.py`:** `NORMAL_HIDE` gains the two v6 pieces.

**Numbers:**

| | Master coat | LOD visible: normal / black / mask |
|---|---|---|
| v6 | 13 980 tris (lined) | 6 459 / 5 146 / 4 007 |
| v5.2 | — | 5 597 / 4 712 / 4 377 |

- **The default build** keeps every piece's and every state's triangle count. Every piece but the coat's collar module matches within 1e-6 m.
  - The collar differs by at most 51 of 640 000 pixels in the big renders, and 36 of 26 400 at the game size.
  - Two builds of the same code differ by 1 pixel. Cause not identified.
- **Verify:** `verify.py` (smoke tier) green.

## 4. Traps (for whoever touches the external coat next)

- **Sleeve detection:**
  - A sleeve search that starts at the hem reads the flared skirt's sides as a sleeve, and the axis comes out pointing UP. Start at the cuff (the
    sleeve's farthest point).
  - `COAT_SHOULDER_X` and `COAT_SRC_TRIS` on one `;` line: a comment appended mid-line swallowed the rest (trap 7 again).
- **The pack:** pushed out along the nearest face's normal, the cloth inside a box went out through its top and sides, and the pouches showed
  through. Over the pack the cloth goes straight BACK; the tailor's dummy now holds the pack.
- **The two walls:**
  - Two walls weighted apart cross as soon as the rig moves.
  - Judged face by face (nearest body point, or rays alone), a sleeve's outside facing the torso and the panel under a lapel read as inside: holed
    sleeves, torn lapels. Pair them.
- **`bmesh.ops.duplicate`'s `vert_map` runs both ways, and the op renumbers the originals.** Read indices BEFORE it, and map by identity.
  Indexing after it scrambled the lining's weights: the coat exploded in idle.
- **Four influences:** the glTF export keeps four. Unposing with more would not return the pose; limit to four first.
- **Pushing off the muscled body ADDS the coat to the agent** (the Director's "somando"): pecs and deltoids imprint, and the sleeves puff over the
  biceps. Fit to the dummy, and hide what is under the sleeve.
- **Hair attempts:**
  - Locks everywhere read as a cauliflower, then as a shrub with the scalp showing.
  - A mass alone reads as a fur cap.
  - Mass + edge locks reads as hair. The front band is still open.

## 5. Open

- **Hair:** the hair's front band, where the sheet has a fringe (an art pass).
- **Body proportions vs the sheet:** a bigger head, a heavier torso, shorter legs. The Director's call; D81's lesson stands.
- **The coat:**
  - its clean source (a paid service whose output we own, or our own re-model on this shape);
  - the LOD budget (6.5k vs ~5k: the coat source at 12k is the lever).
- **Readability:** black at play zoom (D71).
- **Not done yet:**
  - the female base;
  - v6 in Godot and on a handset.
- **D83's open questions:**
  - when and from whom the goggles come;
  - whether the goggles can be worn bare-faced;
  - whether infrared is its own mode.
- **The collar diff:** the cause of the default build's collar difference.
