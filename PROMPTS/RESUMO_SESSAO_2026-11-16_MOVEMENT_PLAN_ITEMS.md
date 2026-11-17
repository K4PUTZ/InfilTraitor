# Session summary — 2026-11-16 (later): MOVEMENT's plan after the basic moves, the grenade's size, the ITEMS milestone

Milestones: MOVEMENT (planning + §11.6 steps 0-1) and the new ITEMS-01. 32 commits on `main`, from `0a09145d` to this summary;
`verify.py` green at every code commit.

## MOVEMENT

1. **§11 written (v1.5, `0a09145d`):** what is left after the basic moves, as HOLD families × BODY postures × the stop cycle; the hold
   families H1-H8, interactions I1-I7, the cover / corner bodies B3-B6, the order of work §11.6. **Prone SUSPENDED** (a GAMEPLAY-01
   note, a line in `DESIGN` §8.2); the bowl throw is standing only (throw study §6).
2. **Step 0: the grenade is the hand's size everywhere (`9d3dabf4`).** `bombs/frag_grenade.json` has a `model` block (`height_gu`
   0.065, `size_certified` 2026-11-12); `BombDef` reads it, `BombRegistry.shared()` is the process's one registry; `GrenadeProp`
   (flight, floor), the aim's ghost and the hand (`TripoFigure.held_prop_scale`) draw that one height; `FIT_SIZE` gone (it drew the
   grenade 3× the hand's). Before / after on `grenade_throw`.
3. **Step 1: the model sheet** (`tools/asset_generation/weapons/gun_model_sheet.py`). Rulings: **all 21 pack firearms are used**,
   each **a weapon of its own** (specs in GAMEPLAY-01) on its family's shared handling (Q10); sized **family by family, every model
   beside the Agent in the aim pose, one by one**, DRAW / HOLDING after all families (Q11); **everyone carries every weapon with one
   animation set** (Q8). Found: the male LIGHT Agent measures 1.08 GU with the hat, not the 1.225 the plan assumed (§11.5, open).

## ITEMS-01 (opened today, `PROMPTS/PLANNING/ITEMS_MASTER_PLAN.md`)

1. **The inventory (§2.10):** every carried / wielded / thrown / placed item, HAVE vs MISSING; new families H9 shoulder launcher, M1 /
   M2 melee, W worn on the forearm (wrist blade: lethal / tranquiliser / berserk poison; the grapple pulls guards and objects).
   First-aid kits in.
2. **89 CC0 models downloaded** from Poly Pizza (licence read on each model's page; Kenney and CC-BY dropped), recorded in
   `props/MODEL_SOURCES.md` (`tools/asset_generation/items/pp_scan.py`, `pp_get.py`, `items_review_sheet.py`).
3. **The missing ones through Nano Banana -> Tripo (Director's route):** real sizes (§2.11), nine reference sheets (prompts §7) in
   `REFERENCES/ITEMS/`, cut into per-view images and PAGES of stacked objects (one FRONT image + one SIDE image per page; round objects
   LAID DOWN so their top becomes a side, the Director's idea), now in `REFERENCES/ITEMS/tripo_pages/`. The cutting scripts were
   one-off and removed (git history `99aeac3f`).
4. **Tripo results: 24 objects done** (pages 1-5 and the drone), each split (`tripo_split.py`: height bands of loose parts), the
   laid ones stood up (`tripo_stand_up.py`), and coloured by **OUR materials** (Director: no Tripo texture; `tripo_zones.py` names
   each face's zone by loose part, part box or position rule). Outputs `ASSETS/MODELS/sources/tripo_props{1..5}_zoned/`,
   `tripo_drone_zoned/`, each with `_preview.png`; zone tables in §7.12. New paint `safety_yellow`.

## Open

- **Next month (credits):** EMP charge, firework lure, chloroform bottle, baseball, glass, can, ring, remote, lockpicks, zip ties,
  sample case. By hand: the rag; adapt: the hand crossbow.
- **Hand edits owed:** brass knuckles (finger holes filled), the bracer's fused blade, the gas grenade's yellow band and open end,
  the detonator's merged button; heavy ones: the drone (9 532 tris), the rig (3 105), the hook and rope (3 518).
- **No item has a game row yet** (the zone -> material mapping moves into each row when the item is mounted in the hand).
- MOVEMENT §11.8: Q1-Q7 and Q9 still open; the Agent's height (1.08 vs 1.225 GU).
