# RESUMO DA SESSÃO — 2026-10-24/25 — The hero's pieces, the coat as a kit, the fedora, the face, and the road to a unique Agent

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`: `3eb71d3a`, `b1889ddc`, `bd77e985`, `853d209d`, `0c7cf5a4`, `14c88704`, and this
record's). Blender only: **nothing was imported into Godot or measured on a handset**; the game's `hero_tailor5*.glb` are still v5.1.
Decisions: `ACTOR_MASTER_PLAN` **D79** (the coat as a kit), **D80** (the fedora), **D81** (the face), **D82** (two looks, a reversible coat; parked).
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-24_CAST_MODELS_FORM_VOICES.md`.

## 1. Every piece rendered on its own

The Director asked for the face and each garment separately: 12 sheets (four views each) from the v5.1 master. They showed what the dressed figure
hides: the shirt is a sleeveless muscled vest, the jacket and trousers follow the muscles, the coat carried the body's anatomy, the hair was pressed
under the scalp (bald patches). Tools: `hero_piece_renders.py` + `hero_piece_sheets.py`.

## 2. The overcoat (D79)

- **Director:** "the most problematic item: a muscular shape and no malleability"; "the most important garment: it defines the factions and it is
  the LED coat; it needs more than one piece".
- **Built:** the coat drapes on a TAILOR'S DUMMY (per-slice convex hulls of torso, pack and arms, hanging from the widest slice, voxel-remeshed),
  not on the muscles; the skirt is built row by row from the waist and weighted to the pelvis plus a growing thigh share (it swings, it no longer
  parts like trousers); lapels from the top button; the jacket sunk under the coat by a ray test; cuffs on the forearm.
- **The kit:** `Outfit_Coat_Body` / `_Sleeves` / `_Collar` / `_Skirt`, built and decimated whole, split before export: seams stay shared vertices in
  the master AND the LOD (Decimate keeps the inverted seam group; trap 13). Game LOD 5 614 visible tris (normal style).
- **The collar (Director: the standing collar "looks odd"; research "a trench coat, aiming at Dick Tracy"):** turned down, a stand lower in front,
  a fall snapped onto the shoulders, peak lapels. Research recorded in D79: the trench's parts (gun flap, yoke, epaulettes, D-ring belt, raglan
  sleeves, cuff straps, back vent) and Dick Tracy's coat (yellow wool, DB 6x2, belt, wide peak lapels, set-in sleeves, flapped pockets, single vent,
  below the knee). Proposal: the trench's military extras are module VARIANTS for the factions' officers.

## 3. The fedora (D80)

- **"Exactly like Michael Jackson's (Moonwalker), but black":** proportions measured from the "Smooth Criminal" hat's 2025 auction photos
  (Propstore lot 211): a narrower crown, deeper pinches, a teardrop crease, a wide band with a flat bow on his left, a 6 cm brim.
- **"Black like the suit":** it was grey because `mat()` takes LINEAR values and the suit's 0.034 is an sRGB pixel (trap 15; shoes, gloves, pack and
  mask still carry it). Felt luma 65.9 -> 24.6 (suit 20.5).
- **"The defect at the back":** the crown was 5 mm inside the nape and the pressed hair went under the scalp (279 of 757 vertices). `fit_crown()` sizes
  the crown from the head; no hair vertex under the skin (0). Trap 16.

## 4. The face (D81)

- **Director's base (now the default):** a wider chin, eye bags, salt-and-pepper hair kept mostly dark ("halfway between youth and middle age") with
  brows to match, a discreet brow scar ("it tells the agent apart from any other character"), skin texture, light age lines.
- **Signature features as knobs** ("be original, avoid the ordinary"): hawk_nose, crooked_nose, heavy_brow, high_cheeks, square_jaw, cleft_chin, smirk,
  widows_peak, grey_streak, steel_eyes; `FEATURES="name:strength"`, `FEATURE_GAIN` 2.4 (at 1 they did not read). **Approved:** hawk nose at 0.25
  (the default). A `NOSE` knob pulls the base nose back (off; unrendered).
- **Hair SHORT** (Director: "a spy would not leave a liability"). A ponytail was weighed and dropped, also for the IP risk: Michael Jackson's
  signatures were stacking on the Agent (the fedora, a ponytail, black leather, gloves, an armband). Lesson: a single generic element is fine; the
  COMBINATION evoking a real person is the right-of-publicity risk.
- **Is it a known model?** Yes: Quaternius' Superhero_Male with millimetre changes and a repainted texture.

## 5. The two looks (D82, parked)

The Director's reference (a long black leather coat over a black shirt and tie, belt with a silver buckle, leather trousers, gloves): the coat is
REVERSIBLE yellow / black (investigator / INFILTRAITOR) and the tie disguises (spun under the collar: a flashy face / a matte black one). A first
build (belt, two-faced tie and coat, black shoes and gloves, ankle-length single-breasted coat, notch lapels, looser shirt, a look mock) was PARKED
when the Director said "let's model his face first": `ARCHIVE/wip/hero_look_infiltraitor_wip_2026-10-25.patch` and `hero_tailor_look_wip_2026-10-25.py`
(git-ignored, on disk). It must be reconciled with D70 (the black style takes the coat into the pack).

## 6. How we work on 3-D models now (Director)

"Modify the model, render, open it in the conversation, done. Nothing else; I give the feedback." Small tweaks: no verify, no commit until the
Director closes the round. The loop is `tools/asset_generation/hero/hero_quick.sh TAG "FEATURES"` (any knob by env), which builds into a scratch
folder and renders the face with `hero_review.py`; sheets with `hero_grid.py`.

## 7. Open for the next session (the Director's call)

1. **The approach to a unique male AND female** (D81, researched): keep the Quaternius bases (two bodies, one skeleton; the female base is already
   on disk) and change their PROPORTIONS with landmarks + an RBF warp, our own skin and hair, optionally MakeHuman / MPFB2 (CC0 core assets) as a
   shape donor; candidates on blind sheets. The question left: Quaternius + MPFB, or Quaternius alone.
2. **The face editor** (proposed): on the FORM as the station's mugshot; blend shapes on the portrait master, shader parameters for skin / hair /
   eyes / scar; the brow scar and the amber eyes fixed on every Agent.
3. D82's two looks; D79's module list and variants; the age level left at 0.4.

## 8. Not done / risks

- Nothing in Godot; no handset numbers for v5.2.
- **The CC0 packs are gone** (UAL1_Standard.glb, the hair): they lived in another session's temporary folder, wiped 2026-10-25. Builds read the v5.1
  master kept at `ARCHIVE/hero_sources/hero_source_v51.glb` (rebuilt from the packs on 2026-10-24; same size as `hero_tailor5.glb`, bytes differ:
  the export is not byte-identical). **Re-download both Quaternius packs to a permanent folder.** Never build over that source file.
- The face is tuned on one head's coordinates (gaussians), so nothing of it transfers to the female head until the landmarks exist.

## 9. Reproduce

```bash
HERO_OUT_DIR=/tmp/hero_quick/ bash tools/asset_generation/hero/hero_quick.sh A "hawk_nose:0.25"      # the face as approved
RV_PARTS=figure,collar,nape,game HERO_OUT_DIR=/tmp/hero_quick/ bash tools/asset_generation/hero/hero_quick.sh B "hawk_nose:0.25"
```
