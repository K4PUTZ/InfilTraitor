# ITEMS_MASTER_PLAN

> 🟢 **v0.1, OPENED 2026-11-16 (Director): "antes de montar as pranchas, abrir a milestone de itens, e tentar baixar tudo que a gente
> puder. Alguns deles vamos ter que construir, outros só adaptar, sempre pegando objetos públicos. Essa é a primeira fase, depois na
> milestone de cenários vamos continuar com os objetos ordinários de mundo."**
> 🟢 **2026-11-16 (later), the Director: "Todos podem carregar todas as armas, vamos usar as mesmas animações pros inimigos e agentes,
> mudando somente os modelos. Registra todos os objetos que temos e o que falta, inclusive kits de primeiros socorros. O que não tiver eu
> faço no Tripo."** Any character, Agent or enemy, may carry any weapon; one set of animations serves both, only the models change.
> §2.10 is the whole inventory, HAVE and MISSING; what is missing the Director generates in Tripo.
> Phase 1 = every item the Agent (or a guard) CARRIES, WIELDS, WEARS ON THE HAND / WRIST, THROWS or PLACES: the models, gathered first,
> before MOVEMENT's family lab files (`MOVEMENT_MASTER_PLAN` §11.6 step 2). Phase 2 = the ordinary objects of the world (furniture,
> machines, the story's places), in the scenarios milestone, later.

## 0. What this plan owns, and what it does not

- **Owns:** the list of items, which hold family each one uses (the poses are MOVEMENT's, §11.3 there), where each model comes from
  (downloaded, adapted, built), its licence record, and the order in which they are gathered.
- **Does not own:** the poses and animations (`MOVEMENT_MASTER_PLAN`), what an item DOES in play and its numbers (`DESIGN_MASTER_PLAN`
  §10, GAMEPLAY-01 in `docs/production/milestones.md`), how a shot / blast breaks the world (`WEAPON_MASTER_PLAN`), drop-in models and
  slots (`PROP_PIPELINE_PLAN`), what a character wears (`CHARACTER_MASTER_PLAN`, `COSMETICS_MASTER_PLAN`).

## 1. Rules

1. **Public models only, CC0** (`ACTOR` D57: a licence filter, not a preference). A CC-BY model is not taken, however good. Every model
   is recorded in `props/MODEL_SOURCES.md` (tracked) and an `ATTRIBUTION.txt` beside it (local, `ASSETS/` is git-ignored).
2. **Download first, adapt second; what no public model covers, the Director makes in Tripo** (2026-11-16: "O que não tiver eu faço no
   Tripo"; a Tripo model is ours, `ACTOR` D85). Adapting = re-cutting, re-colouring, combining parts of public models by script,
   re-runnable from the downloaded original. A script-built solid (a card, a block) stays an option where it is plainly cheaper.
3. **Colour from OUR registry** (`ACTOR` D66): a model brings geometry and surface names; the colours are our materials.
4. **One size everywhere** (HERITAGE T2 W2): an item is the size it has in the Agent's hand, set by the Director with the figure holding
   it (MOVEMENT §11.6 step 2, family by family, in the aim pose).
5. **One row per item.** A weapon is a row of `weapons/`, a bomb a row of `bombs/`, with a `model` block (path, materials, size,
   `size_certified`, points). Each model of a family is an item of its own with its own numbers (Director, 2026-11-16, MOVEMENT Q10);
   the family shares the handling.
6. **Downloads land in their own folder** under `ASSETS/ISOMETRIC/source_assets/imported_models/<source>_<name>/`, the original
   untouched; what the game reads goes under `ASSETS/props/<id>/`.

## 2. The items, by group

Status: ✅ on disk · ⬇️ to download (a CC0 candidate found, §3) · 🔧 to adapt · 🛠 to build · ❓ nothing found yet.
Hold family = `MOVEMENT_MASTER_PLAN` §11.3 (H1-H8, I1-I7), plus the new ones of §2.9.

### 2.1 Firearms (H1 handgun, H2 compact automatic, H3 long gun)

| Item | Family | Status |
|---|---|---|
| Pistols ×4 (the certified one + 3) | H1 | ✅ Quaternius Ultimate Guns Pack |
| Revolvers ×3 | H1 | ✅ same pack |
| Submachine guns ×2 | H2 | ✅ same pack |
| Shotguns ×4 (two full, short stock, sawed-off) | H3 (the sawed-off and the short stock maybe H2: the lab says) | ✅ same pack |
| Assault rifles ×3 + the bullpup | H3 | ✅ same pack |
| Sniper rifles ×4 | H3 | ✅ same pack |
| Scope, bipod, tripod, bayonet (attachments) | on a gun | ✅ same pack |
| Suppressor (attachment) | on a gun | 🛠 a cylinder on the muzzle point |
| Sling (attachment) | on a long gun | 🛠 the enemies carry their main weapon slung, among other ways (Director, 2026-11-18; `ENEMIES_MASTER_PLAN` §5a) |
| Late guns: pulse carbine, laser, plasma, sonic (`DESIGN` §10.2) | H3 | see §3 |

### 2.2 Special ranged (Director, 2026-11-16)

| Item | Family | Note |
|---|---|---|
| **Hand crossbow, tranquiliser darts** | H1 (the pistol's grip "basicamente") | Claude reads it as the canon's DART LAUNCHER (`DESIGN` §10.2, tier 3, 6 tiles): MOVEMENT Q5 answered (a pistol) |
| **Taser** | H1 | canon (FID tree) |
| **Shoulder bazooka** | **H9, new: shoulder launcher** | new item; anyone may carry it (Director, 2026-11-16: every weapon is everyone's) |

### 2.3 Melee (Director, 2026-11-16)

| Item | Family | Note |
|---|---|---|
| **Knives, daggers** | **M1, new: one-hand blade** | the canon's Knife (`DESIGN` §10.2 tier 1) |
| **Swords: katana** | **M2, new: two-hand blade** | |
| **Batons and clubs** | M1 (a baton, a cosh) / M2 (a bat) | the guards' baton too |
| **Brass knuckles** | none: the FIST | "basicamente a mesma coisa que punch": the punch's animation with a mesh on the hand |

### 2.4 The wrist blade (Director, 2026-11-16)

**An Assassin's-Creed-style hidden blade on the forearm**, three loads: **lethal**, **tranquiliser**, or a **poison that sends the
target berserk**. Worn, not held (**W, new: worn on the forearm**): the strike is its own animation, the hands stay free. Model: 🛠 (a
bracer + a blade, built or adapted from a dagger). The berserk poison is a new effect: its rules are GAMEPLAY's.

### 2.5 The grapple (Director, 2026-11-16)

**To move across the map, to trigger things at a distance, or to PULL guards and objects.** ⚠️ It widens `DESIGN` §10.0: the start kit's
rope and hook is "TRAVERSAL only", and the better grapple there brings perches. Claude's reading, to confirm: the start rope stays
traversal; the GRAPPLE (the better one) adds the pull and the distant trigger. Family: a held launcher (H1-like, one hand) or worn on
the wrist (W): open (§5 Q3). Model: see §3.

**Ruled 2026-11-17 (Director): BOTH mechanisms.** A held grapple PISTOL (H1, the Tripo `grapple_launcher`) AND a wrist launcher
worn on the LEFT forearm, the grapple taking the wrist blade's place on that bracer (W, left arm). Owed: the animation of the hook
firing with its line, and the reel turning. (The second half of Q3 is answered by the kinds and the early / late split below; how the start kit's rope and hook relates to the grapple pistol is GAMEPLAY's.)

**The grapple's KINDS (Director, 2026-11-17), each a GAMEPLAY behaviour after one common shot (the hook flies on its line and bites):**
the hook bites a guard and PULLS HIM to the Agent (the "Scorpion" pull); bites a guard and pulls the AGENT to him; bites an object and
pulls the object; bites the scenery and MOVES the Agent across the map (at points made to take it); bites the scenery and pulls it
down, breaking the wall. **Also ratified (same day):** disarm (bite the guard's weapon and tear it from his hand), the distant
trigger above (a lever, a switch, a handle), bring something down on a guard or as a noise, fetch an item, rappel / zip line between
two anchors.

**Early and late (Director, 2026-11-17):** the grapple PISTOL is the EARLY game and takes the PISTOL's slot, a hard choice: carrying
it means no firearm and no tranquiliser dart. LATE game the same hook mechanism moves to the WRIST device on the left forearm, so the
right hand is free to carry a weapon and the pistol slot holds something else. Until GAMEPLAY builds a kind, the shot shows the common part only: the hook flies, bites, holds,
and the reel winds it back (MOVEMENT §11.6 step 5, BUILT 2026-11-17).

### 2.6 Throwables (H4)

Frag grenade ✅ (certified 2026-11-16) · smoke, flashbang, gas, EMP, incendiary grenades (`DESIGN` §10.4) · stone · baseball · glass /
bottle · can (§5.4 distractions) · firework lure. See §3.

### 2.7 Placed (H5)

Explosive / C4 · breaching charge · tripwire flash · alarm clock → radio-clock · camera-loop rig · shadow generator · EMP charge · motion
and noise detectors. See §3.

### 2.8 Devices (H6 one hand, H7 two hands) and small carried things

Detonator · universal remote · spray can · chloroform bottle + rag · radio · radio scrambler · phone / phone cloner · lockpicks · zip ties
· forged credential card · master keycard · cash envelope · scout drone + its controller (H7) · tactical binoculars. Story, carried: the
report's folder, the wedding ring, the badge, the sample case. See §3.

### 2.9 New hold families this plan adds to MOVEMENT §11.3

| Family | Items | Poses it needs |
|---|---|---|
| **H9 shoulder launcher** | bazooka | shouldered aim, fire with a back-blast, reload (or one-shot) |
| **M1 one-hand melee** | knife, dagger, baton, cosh, club | idle-armed, strike (slash / stab / swing), the takedown variants |
| **M2 two-hand melee** | katana, bat | ready, swing / cut |
| **W worn on the forearm** | wrist blade (the grapple, if worn) | the strike, the shot of the grapple |
| (fist) | brass knuckles | the punch, unchanged |

### 2.10 THE INVENTORY: what we have, what is missing (2026-11-16)

**HAVE** = a model on disk (`items_polypizza/<group>/`, or the guns pack); several files = several models, each an item of its own when it
is a weapon (MOVEMENT Q10). **MISSING** = no public CC0 model: **the Director makes it in Tripo.** One list for the Agent and the enemies:
anyone may carry anything, with the same animations (Director, 2026-11-16).

| Item | Family | HAVE | MISSING (Tripo) |
|---|---|---|---|
| Pistols | H1 | 4 (guns pack) | |
| Revolvers | H1 | 3 (guns pack) | |
| Submachine guns ("uzi") | H2 | 2 (guns pack) + a sci-fi SMG | |
| Shotguns | H3 / H2 | 4 (guns pack) | |
| Assault rifles, bullpup | H3 | 3 + 1 (guns pack) | |
| Sniper rifles | H3 | 4 (guns pack) + 2 sci-fi | |
| Late guns (pulse carbine, laser, plasma, sonic) | H3 / H1 | sci-fi set: ray gun, lightning gun, 3 rifles, 3 pistols (`scifi`) | which is which: the Director's look |
| Suppressor | on a gun | 2 (`suppressors`) | |
| Scope, bipod, tripod, bayonet | on a gun | 4 (guns pack) | |
| Hand crossbow + tranquiliser darts | H1 | ✅ v1 2026-11-17: cut down by `tools/asset_generation/items/hand_crossbow.py` (no stock / scope / stirrup / fore-grip, barrel x0.6, prod x0.65, the arrow shortened into the loaded dart; zones Body, Limbs, Cams, String, Trigger, Dart*) -> `ASSETS/MODELS/props/hand_crossbow/`; checked by the Director 2026-11-17: ok; owed: the string's animation and the dart in flight | ✳️ a true HAND crossbow, if the cut-down one fails |
| Taser | H1 | ✅ checked 2026-11-17 (Tripo, Director: ok; the skin wants more detail later) | ✳️ taser |
| Bazooka / rocket launcher | H9 | 2 (`launchers`) | |
| Grenade launchers | H3 | 3 (`launchers`) | |
| Flare gun (the firework lure?) | H1 | 1 (`flare`) | |
| Knives | M1 | 10 (`knives`) | |
| Daggers | M1 | 4 (`daggers`) | |
| Katana, swords | M2 | 2 katanas + 4 swords (`swords`) | |
| Batons, clubs, bats | M1 / M2 | 10 (`clubs`) | |
| Brass knuckles | fist | | ✳️ brass knuckles |
| Wrist blade (lethal / tranquiliser / berserk poison) | W | | ✳️ the bracer and its blade (a dart / needle variant) |
| Grapple (move, pull, trigger at a distance) | W / H1 | | ✳️ the launcher, the hook, the line |
| Rope and hook (the start kit) | H6 | | ✳️ a coiled rope with a hook |
| Frag grenade | H4 | ✅ certified (Quaternius) + 3 more (`grenades`) | |
| Smoke, flashbang, incendiary, gas grenades | H4 | smoke 1, flashbang 2, incendiary 2, molotov, gasoline bomb, fire grenade (`grenades`) | ✳️ GAS grenade |
| EMP grenade / charge | H4 / H5 | a sci-fi grenade (`grenades`) | ✳️ the placed EMP CHARGE |
| Explosive / C4 | H5 | 3 bombs incl. a dynamite bundle (`placed`) | ✳️ a C4 block |
| Breaching charge | H5 | | ✳️ breaching charge (a frame charge on a door) |
| Detonator | H6 | | ✳️ detonator |
| Landmine / tripwire flash | H5 | a landmine (`placed`) | ✳️ tripwire flash |
| Alarm clock, radio-clock | H5 | a timer (`placed`), a radio (`devices`) | ✳️ the wind-up ALARM CLOCK, the radio-clock |
| Firework lure | H4 / H5 | | ✳️ firework lure |
| Stones | H4 | 3 rocks (`distractions`) | |
| Baseball | H4 | | ✳️ baseball |
| Bottle / glass, can | H4 | 3 bottles, a soda cup (`distractions`) | ✳️ a glass cup, a drink CAN |
| Universal remote | H6 | | ✳️ universal remote |
| Spray can | H6 | | ✳️ spray can |
| Chloroform bottle + rag | H6 | | ✳️ chloroform bottle, the rag |
| Radio, radio scrambler | H6 / H5 | a radio (`devices`) | ✳️ the scrambler |
| Phone, phone cloner | H6 | 2 phones (`devices`) | ✳️ the cloner |
| Lockpicks | H6 | | ✳️ lockpicks |
| Zip ties | H6 / H8 | | ✳️ zip ties |
| Credential card, master keycard | H6 | a key card, a key (`devices`) | |
| Cash envelope (bribe) | H6 | an envelope, a letter (`devices`) | |
| Tactical binoculars | H7 | 1 (`devices`) | |
| Scout drone + controller, tablet | H7 | | ✳️ drone, controller, tablet |
| Camera-loop rig, shadow generator | H5 | | ✳️ both |
| Motion detector, noise detector | worn / H6 | | ✳️ both |
| **First-aid kit** (Director, 2026-11-16) | H6 / H5 | 2 (`medkits`, Quaternius) | |
| Story, carried: the report's folder, the wedding ring, the badge, the sample case | H6 | a folder (`devices`) | ✳️ ring, badge, sample case |

**MISSING, the Tripo list in one line:** taser · brass knuckles · wrist blade · grapple · rope and hook · gas grenade · EMP charge · C4
block · breaching charge · detonator · tripwire flash · alarm clock · radio-clock · firework lure · baseball · glass cup · drink can ·
universal remote · spray can · chloroform bottle + rag · radio scrambler · phone cloner · lockpicks · zip ties · drone · drone controller
· tablet · camera-loop rig · shadow generator · motion detector · noise detector · wedding ring · badge · sample case (and a hand
crossbow if cutting the big one down fails). **Not counted:** what is WORN (goggles, balaclava, mask, pack, armour tiers) is
`CHARACTER` / `COSMETICS`'s.

### 2.11 The Tripo list: real sizes and the reference sheets (2026-11-16)

**The route (Director, 2026-11-16):** Nano Banana 2 draws an orthographic reference sheet (one row per object: FRONT | SIDE), Claude
crops each view into its own image, the Director generates the model in Tripo from those views. 4-5 objects of a similar size per
sheet; the prompts are §7. Sizes are REAL ones (cm; length × width × height, Ø = diameter), from the real-world object or its closest
real kin, so the sheet's proportions hold; the final in-hand size is still set by hand (rule 4). Ask Tripo for a low-poly mesh near the
guns pack's budget (~500-3 000 triangles).

| Sheet | Object | Real size (cm) | Reference look |
|---|---|---|---|
| 1 | Taser | 15 × 3.5 × 9 | a pistol-shaped stun gun, a cartridge at the front |
| 1 | Brass knuckles | 10 × 1.2 × 7 | four finger rings, a palm bar |
| 1 | Detonator | 11 × 3 × 6, antenna 8 | a handheld remote detonator: a flip-up safety cover over a red button, a stub antenna |
| 1 | Universal remote | 18 × 5 × 2 | a TV remote, rows of buttons |
| 1 | Spray can | Ø 6.5 × 20 | an aerosol paint can with a cap |
| 2 | Wrist-blade bracer | 20 × 9 × 7 | a forearm bracer with a slot for the blade and a dart port |
| 2 | Wrist blade | 15 × 2 × 0.4 | the blade alone (it extends in play: a separate part) |
| 2 | Grapple launcher | 25 × 5 × 15 | a pistol-grip launcher, a hook loaded at the muzzle |
| 2 | Grappling hook + coiled rope | hook 15, coil Ø 25 | three folding prongs, a coil of rope (the start kit) |
| 2 | Lockpicks | 12 × 3 × 0.5 | three picks and a tension wrench, fanned |
| 2 | Zip ties | 30 × 0.5 × 0.2 | three black cable ties, one looped |
| 3 | C4 block | 28 × 5 × 5 | a wrapped block, a detonator cap and two wires |
| 3 | Breaching charge | 60 × 5 × 2 | a long adhesive strip charge with a small firing box |
| 3 | Gas grenade | Ø 6 × 15 | a cylinder grenade, spoon and pin |
| 3 | EMP charge | Ø 15 × 6 | a disc on a magnetic base, a status light |
| 3 | Tripwire flash | 8 × 5 × 4, spike 10 | a small box, a wire spool, a ground spike |
| 4 | Firework lure | Ø 5 × 15 | a firework tube with a fuse, on a small base |
| 4 | Baseball | Ø 7.4 | red stitching |
| 4 | Glass tumbler | Ø 8 × 10 | a plain drinking glass |
| 4 | Drink can | Ø 6.6 × 12.2 | a plain soda can, no brand |
| 4 | Chloroform bottle | Ø 5 × 12 | an amber glass bottle, a screw cap |
| 4 | Rag | 30 × 30, folded 15 × 15 × 2 | a folded cloth |
| 5 | Wind-up alarm clock | 11 × 6 × 15 | twin bells, a hammer, two feet |
| 5 | Radio-clock | 20 × 8 × 11 | a battery clock radio, a speaker grille, an antenna |
| 6 | Scout drone | 30 × 30 × 8 | a small quadcopter, a camera under it |
| 6 | Drone controller | 18 × 12 × 6 | two sticks, a phone clamp |
| 6 | Tablet | 24 × 0.8 × 17 | a rugged tablet |
| 6 | Radio scrambler | 15 × 10 × 4, antennas 15 | a box with four antennas |
| 6 | Phone cloner | 9 × 6 × 2 | a small box with a cable and a plug |
| 7 | Camera-loop rig | 12 × 8 × 5 | a box with a clamp and a cable |
| 7 | Shadow generator | 15 × 15 × 10 | a squat sci-fi emitter |
| 7 | Motion detector | 8 × 3 × 6 | a clip-on sensor, a lens |
| 7 | Noise detector | 8 × 3 × 6 | a clip-on sensor, a microphone grille |
| 8 | Wedding ring | Ø 2.1 × 0.5 | a plain gold band |
| 8 | Police badge | 8 × 0.5 × 6 | a shield-shaped badge, no text |
| 8 | Sample case | 45 × 12 × 33 | an aluminium briefcase |

## 3. Sources found (2026-11-16)

**Searched:** Poly Pizza, 52 terms, every result's licence read on its own page (`"Licence":"CC0 1.0"`); CC-BY results dropped, Kenney
dropped (`DIRECTION_GLOSSARY` §10). **Downloaded** into `ASSETS/ISOMETRIC/source_assets/imported_models/items_polypizza/<group>/`, one
`ATTRIBUTION.txt` per group; the tracked list is `props/MODEL_SOURCES.md`. The fetch is two scripts kept with the plan
(`tools/asset_generation/items/pp_scan.py`, `pp_get.py`). Creators: Quaternius (most), CreativeTrio, Pichuliru, MaverickFX, MiniPoly,
Voxel_dev, smallbigsquare, scaranto, reyshapes, Isa Lousberg, all CC0.

| Group (folder) | What was found | Covers |
|---|---|---|
| `knives` | 5 Quaternius knives, a Ka-Bar, a pocket knife, a hunter's knife, a battle knife, a butcher's knife | M1 knife |
| `daggers` | 2 Quaternius daggers, a CreativeTrio dagger, a tanto | M1 dagger |
| `swords` | **2 katanas** (Pichuliru, CreativeTrio), 3 Quaternius swords, a cutlass | M2 |
| `clubs` | a baton, a police baton, 4 baseball bats, 2 nailed / saw bats, a pipe, a golf club | M1 / M2 |
| `crossbow` | a full crossbow + 2 arrows | 🔧 cut down into the HAND crossbow, the arrow into a dart |
| `launchers` | Quaternius rocket launcher, CreativeTrio bazooka, 3 grenade launchers (one sci-fi) | H9 (+ H3) |
| `scifi` | Quaternius sci-fi set: ray gun, 3 assault rifles, an SMG, 3 pistols, 2 snipers, a lightning gun | the late guns (pulse, laser, plasma, sonic) |
| `flare` | a flare gun | the firework lure's launcher? |
| `suppressors` | 2 suppressors (Pichuliru) | the suppressor ✅ (no build needed) |
| `grenades` | frag ×2, smoke, incendiary ×2, flashbang ×2, a sci-fi grenade (the EMP?), a molotov, a gasoline bomb, 2 more hand grenades, a bomb | H4 |
| `placed` | a landmine, 3 bombs, a kitchen timer | H5 (the timer: the detonator / the clock?) |
| `devices` | radio, phone, smartphone, key card, key, binoculars, envelope, folder, letter, a glove | H6, cards, the bribe, the story's folder |
| `distractions` | 3 bottles, a soda can, 3 small rocks | H4 distractions |

**Nothing CC0 found — to BUILD (scripts) or ADAPT:** brass knuckles 🛠 · taser 🛠 (or adapt a sci-fi pistol) · the wrist blade 🛠 (a
bracer + a dagger's blade) · the grapple 🛠 (a launcher + a hook) · C4 block, breaching charge, detonator, universal remote 🛠 · spray
can 🛠 · chloroform bottle + rag 🛠 · lockpicks, zip ties 🛠 · drone + its controller, tablet ❓ (no CC0 drone; a build, or another
source) · baseball 🛠 (a sphere) · alarm clock ❓ (the timer may serve) · camera-loop rig, shadow generator, scrambler, detectors 🛠
(sci-fi boxes). **Candidates kept OFF the download until the Director says yes (§6):** first-aid kits (Quaternius), crowbars
(CreativeTrio, Pichuliru), flashlight attachments, shuriken (iPoly3D), a garbage-lid shield.

## 4. Order of work

1. ✅ Download every CC0 candidate of §3 into its own folder, with its record (`props/MODEL_SOURCES.md`, `ATTRIBUTION.txt`): **87 models,
   13 groups, 7.1 MB, 2026-11-16.**
2. 🟡 The review sheet (`tools/asset_generation/items/items_review_sheet.py` -> `temp/items_sheet/items_review.png`: every model fitted to
   one cell, NOT to scale, by group): the Director keeps or rejects each model. The to-scale check is MOVEMENT's family lab files.
3. 🟡 What nothing covers: the Director's Tripo route (§2.11, §7): nine reference sheets drawn and cut 2026-11-16 (35 objects, 72
   views, §7.10); the Tripo generations are next.
4. Then MOVEMENT §11.6 step 2: the family lab files (all of a family's models beside the Agent, in the aim pose, sized one by one).
5. Phase 2 (the scenarios milestone): the ordinary objects of the world.

## 5. Open questions for the Director

1. **Is the hand crossbow the canon's dart launcher** (one item), or a second tranquiliser weapon beside it?
2. ✅ **The bazooka:** everyone's (2026-11-16: every weapon may be carried by anyone, enemies and Agents, same animations).
3. ✅ (first half, 2026-11-17: BOTH, held H1 + left-wrist launcher in the blade's place, §2.5) **The grapple:** held (a launcher in the hand) or worn on the wrist? And is the PULL / distant trigger the better grapple's, with
   the start rope still traversal only (§2.5)?
4. **What might be missing** (Claude's list, §6): which of them enter?

## 6. What may be missing (Claude, 2026-11-16, for the Director's call)

Nothing below is canon; each is one line for a yes or no.

- ✅ **A first-aid kit: YES (2026-11-16)**, in §2.10; what it heals is GAMEPLAY-01's.
- **A crowbar / pry bar:** opens a vent, a crate, a jammed door, and is a club (M2).
- **A flashlight:** the guards sweep flashlights (§10.0 counters); the Agent's own, or a guard's dropped one.
- **Throwing knives / shuriken:** silent ranged lethal (H4), between the knife and the darts.
- **The guards' kit:** riot shield, handcuffs, the radio on the belt (the counter units, `DESIGN` §11.7).
- **A body bag / carry:** carrying a body is an action, not an item; listed only so it is not forgotten.

## 7. The reference-sheet prompts (Nano Banana 2)

The STYLE block is the same on every sheet, so the sheets agree with each other and with the guns pack (Quaternius: flat-shaded facets,
flat colour regions). Each colour region is one material: our registry recolours by surface (`ACTOR` D66), so a clean split matters
more than the colour itself.

### 7.1 Sheet 1 — handheld devices (taser, brass knuckles, detonator, universal remote, spray can)

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 5 rows, 2 columns.
Each row is ONE object: its FRONT view in the left column, its SIDE view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All five objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Taser stun gun, 15 cm long, 9 cm tall: pistol-shaped, a boxy cartridge at the front with two contact points, a grip with a trigger. Black body, yellow cartridge.
2. Brass knuckles, 10 cm wide, 7 cm tall, 1.2 cm thick: four finger rings in a row and a curved palm bar below. Plain steel.
3. Handheld remote detonator, 11 cm long, 6 cm tall, 3 cm thick: a rugged box, a flip-up safety cover over one red push button, a short stub antenna 8 cm long. Olive green body, red button.
4. Universal TV remote control, 18 cm long, 5 cm wide, 2 cm thick: rows of round buttons, a small infrared window at the tip. Dark grey body, light grey buttons.
5. Aerosol spray paint can, 6.5 cm diameter, 20 cm tall: cylinder with a domed top, a nozzle and a separate cap. Plain metal can with one solid colour band, no label text.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (metal, black rubber, plastic). No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
No text, no labels, no numbers, no arrows, no measurements, no hands, no people.
In the side views, the pointed or front end faces right and any handle points down.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_jzebf0jzebf0jzeb.jpeg`, 768 × 1376. Nano Banana drew labels and
dimension lines anyway; the left column came out as the PROFILE (the taser's muzzle to the left) and the right as the END view; the
remote's second view is a three-quarter top. Cut with `tools/asset_generation/items/crop_sheet.py` (text, arrows and lines dropped, each
view squared at 1024 px; both views of an object at ONE scale and the same height, Director 2026-11-16) into `temp/items_tripo/sheet1/<name>_front.png` (the left column) / `_side.png` (the right). Sheet 2 is cut with `--left side`. On the sheet each object is only
130-310 px: ask for the largest output size the tool allows.

### 7.2 Sheet 2 — wrist and rope (wrist-blade bracer, wrist blade, grapple launcher, grappling hook + coiled rope, lockpicks, zip ties)

Six rows (the blade and the lockpicks are thin). The text ban is repeated, since sheet 1 ignored it.

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns. Highest resolution.
Each row is ONE object: its SIDE PROFILE in the left column, its FRONT (end-on) view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Wrist-blade bracer, 20 cm long, 9 cm wide, 7 cm tall: a leather and steel forearm bracer that straps around a forearm, a slot along its underside where a blade slides out, a small dart port beside it. Dark brown leather, dark steel plates, two buckled straps. The blade is retracted (not visible).
2. The wrist blade alone, 15 cm long, 2 cm wide, 0.4 cm thick: a narrow straight double-edged blade with a flat rectangular tang at the back. Bright steel.
3. Grapple launcher, 25 cm long, 15 cm tall, 5 cm wide: a compact pistol-grip launcher with a short wide barrel, a three-pronged hook seated in the muzzle, a rope drum under the barrel. Black body, steel hook.
4. Grappling hook with a coiled rope, hook 15 cm long, rope coil 25 cm across: three curved prongs on a shaft, a ring at the top, a neat coil of thick rope tied to the ring. Steel hook, tan rope.
5. Lockpick set, 12 cm long: three slim picks with different tips and one L-shaped tension wrench, fanned out side by side, flat. Steel picks with black handles.
6. Zip ties, 30 cm long, 0.5 cm wide: three black nylon cable ties, two straight and one closed into a loop.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (metal, leather, rope, plastic). No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
In the side profiles, the front or pointed end faces right and any handle points down.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_uqqbj2uqqbj2uqqb.jpeg`. No text this time. Two drifts: the bracer is
drawn with the blade OUT (asked retracted; Tripo would fuse the two), and the style turned cel-shaded with dark OUTLINES (sheet 1 had
none). Cut with `--left side --open 3 --min-area 0.0003` (no text to drop, thin parts and the tiny end views kept; rows grouped by gap)
into `temp/items_tripo/sheet2/`.

### 7.3 Sheet 3 — explosives (C4 block, breaching charge, gas grenade, EMP charge, tripwire flash)

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 5 rows, 2 columns. Highest resolution.
Each row is ONE object: its SIDE PROFILE in the left column, its FRONT (end-on) view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All five objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Plastic explosive block (C4), 28 cm long, 5 cm wide, 5 cm tall: a rectangular block wrapped in olive film, a blasting cap pushed into one end with two short wires.
2. Breaching charge, 60 cm long, 5 cm wide, 2 cm thick: a long flat adhesive strip charge, dark grey, with a small black firing box at one end.
3. Gas grenade, 6 cm diameter, 15 cm tall: a plain cylinder canister with a top fuse, a spoon lever and a pull ring. Grey body, one yellow band.
4. EMP charge, 15 cm diameter, 6 cm tall: a squat disc device on a flat magnetic base, a ring of vents around its rim, one small status light on top. Dark grey with a cyan light.
5. Tripwire flash device, 8 cm long, 5 cm wide, 4 cm tall: a small box with a wire spool on its side and a 10 cm ground spike under it. Black box, steel spike.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
In the side profiles, the front or pointed end faces right and any handle points down.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_nkpviunkpviunkpv.jpeg`. Dimension lines again; the gas grenade's and
the EMP's second view is a TOP view, not a side one (for Tripo's front + side, use their profile alone, or the top as a top). Cut with
`--left side --keep -1` (everything CONNECTED to the object is kept: the tripwire's spike, the C4's wires, the grenade's lever; no
dimension line touches an object here) into `temp/items_tripo/sheet3/`. The Director (2026-11-16): the bracer's blade is fixed later
in the model, and Tripo should read outlines as drawing, not matter.

### 7.4 Sheet 4 — distractions, FRONT + TOP (firework lure, baseball, glass tumbler, drink can, chloroform bottle, folded rag)

**The Director (2026-11-16): Tripo takes three views (front, side, top), but a TOP view cannot share a sheet with side views of stacked
objects; so a sheet is either FRONT + SIDE or FRONT + TOP.** Round objects get FRONT + TOP (their side is their front: the first
attempt at sheet 4, front + side, came out as two identical columns and was discarded). Flat objects (the knuckles, the remote, the
lockpicks, the zip ties, the C4, the breaching charge) may get a FRONT + TOP sheet of their own later. Cut with `--views front,top`.

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column (seen horizontally, at eye level) and its TOP view in the right column (seen from directly above, looking straight down). Same scale in both columns. All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Firework lure, 5 cm diameter, 15 cm tall: a cardboard firework tube with a twisted fuse on top, standing on a small square base. Red tube, white band, brown fuse.
2. Baseball, 7.4 cm diameter: a white ball with red curved stitching.
3. Glass drinking tumbler, 8 cm diameter, 10 cm tall: a plain clear glass, slightly tapered, thick base.
4. Drink can, 6.6 cm diameter, 12.2 cm tall: a plain aluminium soda can with a ring pull, one solid colour, no brand.
5. Chloroform bottle, 5 cm diameter, 12 cm tall: an amber glass pharmacy bottle with a black screw cap.
6. Folded rag, 15 cm by 15 cm, 2 cm thick: a square of off-white cloth folded twice.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_gavaq2gavaq2gava.jpeg`. Labels and headers again (dropped by the cut).
The pale objects need their own runs: the ball (white on light grey, its outline broken) and the glass (clear) are cut row by row with
`--raw` (the whole box as drawn, `--raw-pad 8`), the glass also with `--threshold 8 --open 3`; the rest with `--views front,top
--row-gap 5`. **The folded rag is dropped:** drawn from above at an angle and nearly the background's colour; the Director models it by
hand. Cuts in `temp/items_tripo/sheet4/` (front + top).

### 7.5 Sheet 5 — clocks and small electronics, FRONT + SIDE (alarm clock, radio-clock, drone controller, radio scrambler, phone cloner)

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 5 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column and its SIDE view in the right column, both seen horizontally at eye level (the object turned 90 degrees about its vertical axis; never a top view). Same scale, same vertical alignment. All five objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Wind-up twin-bell alarm clock, 11 cm wide, 6 cm deep, 15 cm tall: a round clock face, two bells on top with a hammer between them, two short feet. Red body, white face, steel bells.
2. Battery radio-clock, 20 cm wide, 8 cm deep, 11 cm tall: a boxy clock radio, a speaker grille on the left of the front, a small digital display on the right, a telescopic antenna. Black body, grey grille, green display.
3. Drone remote controller, 18 cm wide, 6 cm deep, 12 cm tall: a handheld controller with two joysticks, two short antennas, a phone clamp on top. Dark grey body.
4. Radio scrambler, 15 cm wide, 4 cm deep, 10 cm tall: a flat rugged box with four upright antennas 15 cm long on top, a row of small lights on the front. Olive body, black antennas.
5. Phone cloner, 9 cm wide, 2 cm deep, 6 cm tall: a small black box with a tiny screen, a short coiled cable ending in a plug.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no headers, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_vyxq89vyxq89vyxq.jpeg`. Dimension lines again, none touching an
object: cut with `--views front,side --keep -1 --row-gap 10` (antennas and the coiled cable kept whole) into `temp/items_tripo/sheet5/`.
⚠️ The scrambler's SIDE is drawn ~13 cm deep instead of 4 (a second front, not a side): give Tripo its front alone.

### 7.6 Sheet 6 — devices, FRONT + SIDE (tablet, camera-loop rig, shadow generator, motion detector, noise detector)

From here each row may use its OWN scale (the objects' sizes differ by 10×; a shared scale left the small ones a few dozen pixels). The
real sizes still go in the prompt for the proportions; the size in the game is set by hand anyway (rule 4).

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 5 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column and its SIDE view in the right column, both seen horizontally at eye level (the object turned 90 degrees about its vertical axis; never a top view). Within a row both views share one scale and one vertical alignment; each row may use its own scale so every object fills its row.
Rows, top to bottom:
1. Rugged tablet, 24 cm wide, 17 cm tall, 0.8 cm thick: a tablet in a thick rubber bumper case, a dark screen showing a simple map grid. Black bumper, dark blue screen.
2. Camera-loop rig, 12 cm wide, 8 cm tall, 5 cm deep: a small box with a spring clamp on its back and a short cable ending in a connector, a small antenna. Grey box, black clamp.
3. Shadow generator, 15 cm wide, 10 cm tall, 15 cm deep: a squat sci-fi emitter on four short legs, a dark lens dome on top, a ring of purple light. Dark grey body.
4. Motion detector, 8 cm wide, 6 cm tall, 3 cm deep: a clip-on sensor with a round lens on the front and a belt clip on the back. Black body, red lens.
5. Noise detector, 8 cm wide, 6 cm tall, 3 cm deep: a clip-on sensor with a round microphone grille on the front, a small level meter of five lights, a belt clip on the back. Black body, green lights.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no headers, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_xdsru2xdsru2xdsr.jpeg`. Headers and measure lines, none touching:
cut with `--views front,side --keep -1 --row-gap 10` into `temp/items_tripo/sheet6/`. The cel style with outlines came back; the
detectors' sides are drawn deeper than 3 cm (fixed by hand at the model, if it matters).

### 7.7 Sheet 7 — the story, FRONT + SIDE (sample case, police badge)

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 2 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column and its SIDE view in the right column, both seen horizontally at eye level (the object turned 90 degrees about its vertical axis; never a top view). Within a row both views share one scale and one vertical alignment; each row may use its own scale so every object fills its row.
Rows, top to bottom:
1. Aluminium sample case, 45 cm wide, 33 cm tall, 12 cm deep: a hard-shell briefcase with a handle on top, two latches, ribbed metal sides. Brushed silver, black handle.
2. Police badge, 8 cm wide, 6 cm tall, 0.5 cm thick: a shield-shaped metal badge with a star in its centre, on a black leather backing, no text.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no headers, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_gizydngizydngizy.jpeg`. A title, row captions, separators and
measures: cut with `--views front,side --row-gap 10 --keep -1` (the case's thin handle in its side view) into `temp/items_tripo/sheet7/`.

### 7.8 Sheet 8 — flat and long things, FRONT + TOP (scout drone, C4 block, breaching charge, universal remote, zip ties)

The drone needs its top; the others were drawn front + side in sheets 1-3 and gain the view that shows their shape.

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 5 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column (seen horizontally, at eye level) and its TOP view in the right column (seen from directly above, looking straight down). Within a row both views share one scale; each row may use its own scale so every object fills its row.
Rows, top to bottom:
1. Scout drone, 30 cm across, 8 cm tall: a small quadcopter, four arms with propellers in round guards, a camera ball under the body. Dark grey body, black propellers.
2. Plastic explosive block (C4), 28 cm long, 5 cm wide, 5 cm tall: a block wrapped in olive film, a blasting cap in one end with two short wires.
3. Breaching charge, 60 cm long, 5 cm wide, 2 cm thick: a long flat adhesive strip charge, dark grey, a small black firing box at one end.
4. Universal TV remote control, 18 cm long, 5 cm wide, 2 cm thick: rows of round buttons, an infrared window at the tip. Dark grey body, light grey buttons.
5. Zip ties, 30 cm long: three black nylon cable ties, two straight and one closed into a loop, lying flat.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no headers, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_my1ryfmy1ryfmy1r.jpeg`. A caption under every view: cut with
`--views front,top --row-gap 10 --keep -1 --open 5 --min-area 0.0005` into `temp/items_tripo/sheet8/`. The C4's and the remote's
"front" here is a second top: **their three views for Tripo are sheet 3 / 1 (side and end) + this sheet's TOP**; the breaching charge
likewise (sheet 3's side and end + this top); the drone and the zip ties take this sheet's two.

### 7.9 Sheet 9 — small flat things, FRONT + TOP (brass knuckles, lockpicks, wedding ring)

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 3 rows, 2 columns. Highest resolution.
Each row is ONE object: its FRONT view in the left column (seen horizontally, at eye level) and its TOP view in the right column (seen from directly above, looking straight down). Within a row both views share one scale; each row may use its own scale so every object fills its row.
Rows, top to bottom:
1. Brass knuckles, 10 cm wide, 7 cm tall, 1.2 cm thick: four finger rings in a row and a curved palm bar below. Plain steel.
2. Lockpick set, 12 cm long: three slim picks with different tips and one L-shaped tension wrench, lying flat side by side. Steel picks, black handles.
3. Wedding ring, 2.1 cm across, 0.5 cm wide: a plain gold band.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions. No outlines, no ink lines, no cel shading. No textures, no wear, no decals, no logos.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
ABSOLUTELY NO TEXT anywhere on the image: no titles, no headers, no numbers, no labels, no dimension lines, no arrows, no measurements. No hands, no people.
```

**Result (2026-11-16):** `REFERENCES/ITEMS/Gemini_Generated_Image_chtytchtytchtytc.jpeg`. Measures again; the lockpicks row is cut
on its own (`--open 3`) so the thin tension wrench survives.

### 7.10 All sheets cut: the views per object, for Tripo

**`python3 tools/asset_generation/items/cut_sheets.py`** re-cuts the nine sheets in `REFERENCES/ITEMS/` with the flags that cut each
one clean and gathers **35 objects, 72 views** into `temp/items_tripo/by_object/<object>/{front,side,top}.png` (temp/ may be wiped:
the script rebuilds it). The mapping lives in the script: where a sheet's column is not the view its name says (sheet 3's gas
grenade / EMP right column is a TOP; sheet 8's C4 / remote "front" is a second top; the scrambler's "side" a second front), the
script files it under the view it really is. Convention note: on sheet 1 a long object's FRONT is its profile; from sheet 2 on, its
FRONT is the end view and the profile is SIDE (Tripo is told which is which; the model is turned to +X later anyway). Not cut: the
folded rag (by hand) and the hand crossbow (cut down from the downloaded one).

**Pages for Tripo (Director, 2026-11-16):** Tripo is given TWO images per page, the same objects in the same slots: one with every
object's FRONT, one with every object's SIDE (or every object's TOP; never mixed on a page). `cut_sheets.py` lays them out from the
per-object cuts into `temp/items_tripo/pages/PAGE_<n>_FRONT.png` + `PAGE_<n>_SIDE.png` / `_TOP.png`: nine pages, four objects a page
(six front + side, three front + top), each slot filled by its object at one scale for its two views. The scrambler (one view) is not
on a page. The pages are listed in the script's `PAGES`. **One background on every page (Director, 2026-11-16):** the sheets' greys and white differed and the pale objects' cuts carried
squares of their own grey; each view's background, flooded from its border, becomes one grey (222, 222, 220), a clear glass with a
tighter tolerance, and a speck under 1 % of the object is dropped.

**Tripo's multi-view takes Front, Left, Right, Back (no top slot; screenshot 2026-11-16).** The Director proposed giving the TOP image
as the side and turning the model afterwards; Claude's objection, recorded for his call: a top is not a rotated side (the can is
12.2 cm tall from the front and 6.6 cm from above: no object has both silhouettes, so the geometry, not only the orientation, comes out
wrong). **Resolved the same day by the Director's reading: LAY THE OBJECT DOWN.** "Top" and "side" are names: a round object laid on its side
(axis left-right) has, as its FRONT, its front turned 90 degrees, and as its LEFT side, its top view; both are the diameter tall, so
the two silhouettes are one object, and the top's detail (the can's tab, the drone's arms) reaches Tripo; the model is stood up by
hand afterwards. Pages 7-9 exist as `PAGE_<n>_FRONT_LAID.png` + `PAGE_<n>_SIDE_LAID.png` (each top rescaled so its diameter equals
the laid front's height: the image model had drawn some tops at another scale, the gas grenade's ~1.6x; the remote, the lockpicks
and the zip ties, not round, take the front + side pair cut together on sheets 1 / 2). The TOP versions stay.
Tripo settings reviewed: Smart Mesh, TRIANGLES (Tripo's split refuses quads), the side in the LEFT slot; ~5 000 faces a page (8 000
for page 5 and the drone's); generate page 1 first and check that the four objects come out apart and the split separates them.

**2026-11-16 (end), the Director:** the cutting scripts (`crop_sheet.py`, `cut_sheets.py`) are NOT kept: the drawings are one-off and
cannot be repeated, so there is nothing to re-cut (they stay in git history, `99aeac3f`). The pages, moved to
`REFERENCES/ITEMS/tripo_pages/` (24 images, local like all of `REFERENCES/`), are the hand-off to Tripo; the smallest objects (ring, lockpicks, zip ties, the blade's end...) may be modelled by hand instead. The
Director tests the Tripo generation next; the evaluation follows.

### 7.11 The first Tripo page (2026-11-16): it works

`ASSETS/MODELS/props/tripo_Props1.glb` (page 1: Smart Mesh, triangles, 5 000 faces, front + left): ONE mesh, 4 927 triangles,
33 loose parts, **no material, no UVs, no texture** (geometry only), the stack normalised to 1.0 tall. The four objects sit in height
bands with clear gaps, so `tools/asset_generation/items/tripo_split.py` cuts them apart (bands of overlapping loose parts, top to
bottom), puts each base centre at the origin and writes `ASSETS/MODELS/props/tripo_props1_split/<name>.glb` + `_review.png`:
taser 924 tris, detonator 868, spray can 829 (its cap a separate part), phone cloner 2 306 (most of it the coiled cable). Read on the
review: the taser and the can are clean; the detonator's lid hinge is lumpy and its button merged; the cloner's cable is the cost.
**Open:** colour. Tripo's texture step costs credits; without it the colours come from OUR registry (`ACTOR` D66), which needs surface
regions: the loose parts give some (the can and its cap, the cable), the rest is painted per face in Blender.

### 7.12 Colour = OUR materials (Director, 2026-11-16)

**Ruled:** a Tripo item takes no Tripo texture; its colours come from our registry (`ACTOR` D66), by ZONE.
`tools/asset_generation/items/tripo_zones.py` names each face's zone (a material per zone in the GLB, the same contract as a
downloaded model's authored surfaces): by LOOSE PART (Tripo already separates lids, buttons, contacts, cables), and where a part holds
two zones, by a geometric rule (the taser's cartridge: the front 30 % of its body; the cloner's screen: the faces recessed into its
front). Page 1 done, `ASSETS/MODELS/props/tripo_props1_zoned/` + `_preview.png`; the zones and their materials (the prompt's colours):

| Object | Zones -> material |
|---|---|
| Taser | Body `rubber`, Cartridge `plastic@safety_yellow`, Muzzle `rubber`, Contacts `metal` |
| Detonator | Body `painted_metal@olive_drab`, Handle `rubber`, Button `plastic@signal_red`, ButtonBase `rubber` |
| Spray can | Can `metal`, Cap `plastic`, Nozzle `plastic` |
| Phone cloner | Body `rubber`, Screen `steel_dark`, Buttons `plastic`, Cable `rubber`, Plug `rubber`, PlugTip `metal` |

| Brass knuckles (page 2) | Body `metal` (the finger holes came out FILLED: the Director reshapes it by hand, the base serves) |
| Motion detector | Body `rubber`, Lens `plastic@signal_red`, LensRing `rubber` |
| Noise detector | Body `rubber`, Grille `steel_dark`, Lights `glass_screen_green` |
| Police badge | Backing `leather` (brown: the prompt's black has no paint yet), Shield `metal`, Star `metal` |

| Wrist bracer (page 3) | Shell `leather`, Plate `steel_dark`, Buckles `metal`, Port `steel_dark`, Blade `metal` (drawn OUT, fused as its own part: edited by hand) |
| Wrist blade | Blade `metal` |
| Grapple launcher | Body `rubber`, Drum `fabric@sand`, Hook `metal` (everything forward of the barrel) |
| Grappling hook + rope | Rope `fabric@sand`, Hook `metal` |

| C4 block (page 4) | Block `plastic@olive_drab`, Tape `fabric@olive_drab`, Cap `metal`, WireRed `plastic@signal_red`, WireBlack `rubber` |
| Breaching charge | Strip `steel_dark`, Box `rubber` (the -Y end) |
| Tripwire flash | Box `rubber`, Spool `metal`, Spike `metal` |
| Camera-loop rig | Box `metal`, Black `rubber` (clamp, antenna, cable), Metal `steel_dark` (connectors, pivot) |

| Alarm clock (page 5) | Body `painted_metal@signal_red`, Face `plastic@bone_white`, Hands `rubber`, Metal `metal` (bells, hammer, feet, keys) |
| Radio-clock | Body `rubber`, Grille `metal`, Display `glass_screen_green`, Knob `steel_dark`, Antenna `metal` |
| Drone controller | Body `rubber`, Buttons `plastic`, Clamp `steel_dark` |
| Tablet | Bumper `rubber`, Screen `plastic@navy`, Buttons `metal` |
| Radio scrambler | Body `painted_metal@olive_drab`, Antennas `rubber` |
| Shadow generator | Body `steel_dark`, Dome `plastic@navy` |
| Gas grenade (LAID: stand it up) | Body `metal`, Fuse `metal`; the yellow band has no faces of its own (a loop cut or a decal later); one end came out open |

| Scout drone (its own pass) | Body `steel_dark`, Rotors `rubber`, Camera `rubber`, Lens `glass`, Cables `rubber`, Claw `metal`, Top `rubber` |

**The drone (`tripo_Drone.glb`, 2026-11-16):** more sophisticated than the sheet's (a camera ball under the body and a CLAW hanging on
four cables), 9 532 triangles in 81 loose parts: three times the per-item budget (a hero gadget; decimate if the Moto says so).
Generated LAID, stood up with `tripo_stand_up.py ... -90` (the rotors to +Z), zoned by each part's BOX (`"part_where"` in
`tripo_zones.py`: a whole part's zone from its bounds, for a model with too many parts to rank).
Page 5 (`tripo_Props5.glb`, the Director's credit-saving page: SEVEN objects and more faces): alarm clock 2 324, radio-clock 904,
controller 1 494, tablet 434, scrambler 1 012, shadow generator 940, gas grenade 1 108. **The drone gets a pass of its own** (it must
be more sophisticated). **Next month (credits):** the EMP charge, the firework lure, the chloroform bottle, the baseball, the glass,
the can, the ring, the remote, the lockpicks, the zip ties, the sample case; the rag and the hand crossbow stay by hand / adapted.
Page 4 (`tripo_Props4.glb`): C4 695, breaching charge 246, tripwire 543, rig 3 105 (the clamp is the cost). Each slot filled its
page, so the breaching charge came out as long as the C4: its 60 cm is set by hand (rule 4).
Page 3 (`tripo_Props3.glb`): bracer 1 439, blade 110, launcher 1 385, hook and rope 3 518 (the coil is the cost); a page with many
small parts is zoned by part ranks AND position rules (`"where"`, on the face centre). Preview fix: the glTF importer leaves
QUATERNION rotation, so the three-quarter view needs `rotation_mode = "XYZ"`.
Page 2 (`tripo_Props2.glb`): 4 753 triangles, split clean (knuckles 902, motion 1 497, noise 1 270, badge 1 284), zoned into
`tripo_props2_zoned/`. New paint `safety_yellow` in `PaintPalette`. The mapping moves into each item's row when the item gets one; the next pages add their
objects to the script's `SPEC` (a part rank is read off a parts render first: ranks are by face count, stable for one file).

