# RESUMO DA SESSÃO — 2026-10-24 — The cast of the tree, the model inventory, the deponent's form, the bike and the helmet, the voices

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`: `cfd493ec`, `b2e57c9f`, `3201633b`, `da7971b8`, `4073bb68`, `80bae948`, and
this record). Design and documentation only; nothing in `godot/` changed. **Previous record:**
`PROMPTS/RESUMO_SESSAO_2026-10-23_FACTION_DRESS_PLOT_CLOSE.md` (the same conversation, continued past midnight).

## 1. Who introduces each node of the tree (`cfd493ec`)

The Director asked for the enemies and characters who introduce each technology, and approved Claude's proposal as drawn.

- **`DESIGN` §11.7 (new):**
  - **L1**: the twelve specialists.
  - **L2**: a named store KEEPER per faction, seen in lap 1 before he matters: **Urn** (FID evidence room), **Tank Mercer** (Calm Waters
    armoury), **Tithe** (Bunsen Burners chop shop; gas and smoke from Censer's lab), **Margin** (Corporation R&D floor). The LED coat stays Hedge's.
  - **L3**: a Freelance Captain fields the prototype; the Agent knocks him out, takes the SAMPLE, and **Zest** researches it (a fence and engineer
    met in the neutral missions).
  - **Counters**: twelve enemy UNITS, one per faction and lane, three gear stages each; the author's faction fields a counter first, the others
    a stage later; many stages are behaviour, zones or voxel materials, not models.
- **§11.6's table synced to the tree** (Cairn, Rex, Chip, Censer, Sexton, Hedge's L1 nodes; breaching charges moved to L3).
- Diagram `DIAGRAMS/ELENCO_ARVORE.png`, generator `tools/asset_generation/tech_tree_cast_poster.py`.

## 2. The model inventory (`b2e57c9f`, `3201633b`)

**`docs/systems/MODEL_INVENTORY.md` (new, ratified):** every model the campaign needs, derived from `COSMETICS` §8-§9, `PROP_PIPELINE` §9 and
`DESIGN`, never overriding them. **Director's rule: architecture and large objects are built in VOXELS.** Rulings on Claude's five questions:

1. Vehicles stay MESH.
2. The K9 dog gets its own quadruped skeleton (the one model outside the one-skeleton rule).
3. The alarm clock is an old wind-up clock, later the radio-clock.
4. Some women in every faction's rank-and-file, not on every model.
5. Two women per faction among its four named people (Claude chose them, §4 below).

## 3. The deponent's form, the opening, the bike (`da7971b8`)

- **The form (Director; `DESIGN` §2.2):** the game opens on a police form for a DEPONENT: name, sex, race, eye colour, nationality, home town. The
  home town is the story's city: the nationality's cities in alphabetical order with a search field, "Custom" at the top for a free name (an empty
  one reads Lowmere); the towns around come from the nationality's country. The sex sets the model, so the opening shows the right Agent and
  spouse. The deposition then chooses the attributes of his PAST.
  - Claude's framing: the form is the deposition's intake sheet; the opening that follows is the night before.
  - Claude's guards: "race" follows each country's form and sets the skin tone only, never the face; the home town stays on the device per
    character, and the world map's base remains the account's opt-in (`COSMETICS` §6).
- **The motorcycle and the helmet (Director's idea; the clue chain is Claude's, under delegation; `DESIGN` §2.6, §2.4):**
  - his spouse had the car, so he rode his own old bike that night (his alibi was the phone left at home);
  - the Militia's perimeter camera caught a RIDER at the wall, and a guard's round GRAZED the helmet; a rider by a kamikaze drone reads as a
    Bunsen Burner, which served his frame-up;
  - the helmet hangs on the handlebar in the opening, the graze fresh;
  - the Confessor was hunting that rider for "Deacon"; the Agent takes his file with the mask, and the helmet is gone from the handlebar from
    the next scene (he rides in the balaclava);
  - at the finale the reporter matches the helmet; the helmet is never a disguise;
  - the chop shop's L2 node is Tithe's work on THIS bike (swapped plates, a stash), never a second bike (§15).
- **The women (Claude, under delegation; `DESIGN` §11.7):** FID Pyre and Vault; Calm Waters Ace Skyler and Tank Mercer; Bunsen Burners Censer and
  Tithe; Corporation Ledger and Escrow; Zest. The others are men.

## 4. The voices (`4073bb68`)

**Director: unintelligible voices, like the teacher in *Charlie Brown*, with the text on screen** (`DESIGN` §2.3). The voice tells who speaks
(man, woman, young, old, child, dog) and the mood; the content is written. Claude's proposals recorded with it:

- One recording for every language: nothing dubbed (`LOCALIZATION_REFERENCE`'s per-locale voice streams marked unused).
- The bank: voice types × a handful of emotions × short / medium / long phrases, plus interjections, commands, acknowledgements, pain,
  laughter, sobbing, screams (~80-100 clips per performer).
- A named character = voice type + performer + a small pitch offset.
- A line = speaker + emotion + text key.
- Barks work the same way.
- The child's voice is heard only off the board.

## 5. The deposition's recap (`80bae948`)

**Director:** in the deposition the Agent recaps the night (home, a noise, the TV, the dam giving way, the call, the family in the other town),
so the player is sure of what happened. **Claude:** every sentence is technically true, and he leaves out the ride home the opening showed. It
is his alibi, and one more fair-reveal clue (`DESIGN` §2.4).

## 6. Still open (`DESIGN` §18)

- The voice bank's performers and sizes.
- Where hair, face and height are chosen (the form or the deposition).
- The race field's options per country.
- Everything §18 already held from 2026-10-23.

## 7. Natural next steps

- Wire the noise pipeline (the Director: next).
- The hero adapter to `ActorMesh3D` (bone and action names), still the first job before the hero is playable (`ACTOR` D77).
- The female base, now required for the opening (`COSMETICS` §8.1, `MODEL_INVENTORY` §1).
