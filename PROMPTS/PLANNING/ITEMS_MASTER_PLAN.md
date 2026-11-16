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
| Hand crossbow + tranquiliser darts | H1 | a full crossbow + 2 arrows (`crossbow`), to cut down | ✳️ a true HAND crossbow, if the cut-down one fails |
| Taser | H1 | | ✳️ taser |
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
3. What nothing covers: adapt (scripts) or build (scripts).
4. Then MOVEMENT §11.6 step 2: the family lab files (all of a family's models beside the Agent, in the aim pose, sized one by one).
5. Phase 2 (the scenarios milestone): the ordinary objects of the world.

## 5. Open questions for the Director

1. **Is the hand crossbow the canon's dart launcher** (one item), or a second tranquiliser weapon beside it?
2. ✅ **The bazooka:** everyone's (2026-11-16: every weapon may be carried by anyone, enemies and Agents, same animations).
3. **The grapple:** held (a launcher in the hand) or worn on the wrist? And is the PULL / distant trigger the better grapple's, with
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
