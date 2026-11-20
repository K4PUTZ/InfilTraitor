# ENEMIES_MASTER_PLAN

> 🟢 **v0.1, OPENED 2026-11-18 (Director): *"Antes de continuar com as armas, vamos abrir a milestone ENEMIES, e fazer um levantamento
> de todos os tipos de modelos que vão ser necessários, incluindo todos os personagens principais, subchefes, oficiais, e pool de thugs
> comuns pra cada facção."***
> This version is the SURVEY: every model the four factions need, from the leaders down to the common pool and the machines, where each
> one is canon, where it appears (the board or a staged scene), and how it could be made. **Nothing is built, and this file ratifies
> nothing:** the cast is canon from its owners (§1); the build routes of §6 and the counts that depend on them are Claude's proposal, and
> §9 holds what is still open.
>
> 🟢 **v0.2, 2026-11-18 (later): the Director ruled the officers and the enemies' weapons.** *"todo oficial vai ter uma estrutura
> corporal parecida com o agente (male e female) + o casaco. Fim. Todo o resto vai ser diferente. Sapato, chapeu, cabelo, calça, camisa,
> cinto, etc. Então, sim agente e oficiais são membros da mesma classe. Mas vão ser essencialmente bem diferentes."* (§6) *"Os inimigos
> em geral vão ter um tipo de arma principal (mais algumas secundárias) e ela vai estar sendo carregada na mão, a tiracolo ou seguradas
> casualmente de umas 3 maneira diferentes."* (§5a) The pool's route is still open (§9).

## 0. What this plan owns, and what it does not

- **Owns:** the list of the enemy side's MODELS (who needs one, on which body, made how), their status, the order in which they are
  made, and the engine step that puts them on the board (the guards on the Tripo rig, §7).
- **Does not own:** who they are and what they do in the story (`DESIGN_MASTER_PLAN` §2, §11), how they behave (`AI_MASTER_PLAN`,
  `DESIGN` §11-§13), the slots and the palette (`COSMETICS_MASTER_PLAN` §8-§9), how they move (`MOVEMENT_MASTER_PLAN`), what they carry
  (`ITEMS_MASTER_PLAN`), what a segment may hold (`PERFORMANCE_BUDGET_MASTER_PLAN` PB-1).
- **The ratified source is [`MODEL_INVENTORY`](../../docs/systems/MODEL_INVENTORY.md)** (§1 bases, §4 factions, §5 named characters,
  §7.1 rulings 6-10 of 2026-10-29). This plan expands its enemy rows and tracks them from now on; where the two disagree, the inventory's
  rulings stand until the Director rules otherwise.

## 1. Rules already in force

| # | Rule | Source |
|---|---|---|
| 1 | Every character is a Tripo generation (paid plan: the outputs are ours), rigged by Tripo on the 65-joint Mixamo skeleton, ~1 m; our code adapts to it | `ACTOR` D85 |
| 2 | **One set of animations for the Agent and every enemy;** any of them may carry any weapon; only the models change | `MOVEMENT` §11.8 Q8 (Director, 2026-11-16) |
| 3 | A model is generated bare and its swappable pieces are generated afterwards and fitted; for the Agent "bare" is the BASIC DRESS (shirt, trousers, shoes), not a nude body | `MODEL_INVENTORY` §7.1 #6, `ACTOR` D86, D89 |
| 4 | Bosses and sub-leaders are unique models | §7.1 #7 |
| 5 | The rank-and-file is a shared roster of ~10 varied humans (both figures, ages, builds), interchangeable across factions: a soldier = a roster body + the faction's pieces | §7.1 #8 |
| 6 | Some women in every faction's rank-and-file, not on every model; two women among each faction's four named (three specialists + the keeper) | §7 #4-#5, `DESIGN` §11.7 |
| 7 | A heavy build for the bruisers of Calm Waters and the Bunsen Burners, and for Kessler, Hardcastle and "Deacon" | `MODEL_INVENTORY` §1, §5; `COSMETICS` §8.1 |
| 8 | Field officers (Lieutenant up) wear an overcoat in the faction's colours with its emblem: ONE coat silhouette, four colour rows; the sub-leaders are the most senior of them, with distinctions | `DESIGN` §2.1, §11.2; `COSMETICS` §8.3 |
| 9 | A piece's colour is a palette entry times a grayscale detail, with hand-painted pieces where needed; the four palette families | `ACTOR` D87; `COSMETICS` §9.4 |
| 10 | One game LOD of ~5 k triangles per figure, made offline (`build_agents.sh`) | `ACTOR` D73, D91 |
| 11 | Machines complement the humans: four per faction, one per role (fixed eye, mobile, armed, alarm); the K9 is the police's mobile one, on its own quadruped skeleton | §7.1 #9, §7 #2 |
| 12 | A segment holds 4 / 6 / 10 guards (LOW / TYPICAL / HEAVY; HEAVY with 2 types) and 0 / 2 / 4 cameras or drones | `PERFORMANCE_BUDGET` PB-1 |
| 13 | The sub-leaders (and the reporter, the spouse) are never reachable actors on a playable board: a scene, behind glass, a comm-link | `DESIGN` §2.8 |
| 14 | The first slice is the opening every route shares (ruled); then, proposed, the other three faction sets, one per territory, each measured on the Moto before the next | `COSMETICS` §8.5 (the first slice ruled by the Director, 2026-10-23) |
| 15 | Traps on the path wait for the scenarios milestone | §7.1 #10 |

## 2. The cast in one picture

Per faction, from the top. The four are built to the same shape (`DESIGN` §2.1: equivalent as a whole, different in everything else).

| Tier | Per faction | Kind of model | Appears on |
|---|---|---|---|
| Leader (boss of lap 2) | 1 | unique | the board: a mortal confrontation (`DESIGN` §2.2) |
| Sub-leader (handler, successor) | 1, + Prudence Vane for the Corporation | unique | scenes only (rule 13) |
| Rival boss (§11.2's Rival Agent tier) | the Confessor (club), Hedge (Corporation) | unique | the board (`DESIGN` §2.2, §2.8) |
| Specialists: EYE, HAND, WALL | 3 | unique, named | the board: each fields the tech he authors (`DESIGN` §11.6) |
| Store keeper (L2) | 1 | unique, named | the board, at the store (`DESIGN` §11.7) |
| Member abroad (the trips) | 1, proposed | unique | a trip's map (`DESIGN` §2.6; open in §18) |
| Freelance prototype captain (L3) | 1 | an officer + the L3 item, not named | the board (`DESIGN` §11.7) |
| Field officers: Lieutenant, Captain | 2 ranks | the Agent's body + the coat, every other slot his own (ruled 2026-11-18, §6) | the board |
| Rank-and-file: Recruit, Standard, Veteran | 3 ranks | the common pool | the board |
| Counter units: EYE, HAND, WALL | 3 units × 3 gear stages | pieces on the pool | the board (`DESIGN` §11.7) |
| Machines | 4 | one mesh each (PP7 when it moves) | the board |

## 3. The survey, faction by faction

Figure: M / F; "heavy" where the canon says so. The specialists' build (standard or heavy) is not assigned (`MODEL_INVENTORY` §5).

### 3.1 The FID, Federal Inquiry Directorate (blue / white / yellow; the investigators' mustard coat)

| Tier | Who | Figure | Notes |
|---|---|---|---|
| Leader | **Commissioner Martin Graves** | M | takes the badge; runs the Agent off the books (`DESIGN` §2.2) |
| Sub-leader | **Deputy Commissioner Irene Barrow** | F | the policeman route's handler and the official investigator (§2.8); the overcoat with distinctions |
| EYE | **Cairn**, the K9 handler | M | + the dog (§5) |
| HAND | **Pyre**, the taser officer | F | the taser (`ITEMS` §2.2) |
| WALL | **Vault**, the dispatcher | F | radio check-ins, roadblocks |
| Keeper | **Urn**, the evidence clerk | M | the evidence room |
| Abroad | the money man who launders Graves's protection money | open | a private bank in a tax haven |
| L3 captain | a Chief Inspector | officer | the FID's L3 prototype |
| Officers | Inspector (Lt), Chief Inspector (Cpt) | officer | **the Agent's own coat AND colour** (he is an Inspector); every other slot is their own (§6), so his fedora, tie and shoes set him apart (`DESIGN` §2.1) |
| Pool | Cadet, Agent, Senior Agent | pool | uniform shirt, trousers, boots, cap, duty belt; rank: radio (Lt up), tactical vest, a commander's jacket (`COSMETICS` §8.3). The opening's station officers |
| Counter units | forensic tech · riot officer · radio sergeant | pieces | scent-decoy kit, tablet, jammer case · insulated vest, detector wand, ear defenders · analogue handset, runner's satchel |
| Machines | street CCTV dome · **K9 dog** · taser sentry on a tripod · siren box | | |

### 3.2 Calm Waters Security, the Militia (red / wine / grey / white)

| Tier | Who | Figure | Notes |
|---|---|---|---|
| Leader | **Commander Dale Kessler** | heavy M | |
| Sub-leader | **Duke Hardcastle**, head of operations | heavy M | the overcoat with distinctions |
| EYE | **Ace Skyler**, the drone pilot | F | the scout drone and its controller |
| HAND | **Rex Hawke**, the marksman | M | the suppressed rifle |
| WALL | **Chip Voltz**, sensors and laser tripwires | M | the EMP charge |
| Keeper | **Tank Mercer**, the quartermaster | F | the armoury |
| Abroad | the parent holding's finance director | open | the PMC's offshore headquarters |
| L3 captain | a Site Commander | officer | |
| Officers | Team Leader (Lt), Site Commander (Cpt) | officer | a grey tactical coat with red and wine bands (proposed, `COSMETICS` §8.3) |
| Pool | Contractor, Operator, Senior Operator | pool | tactical top, armour vest, helmet or cap, boots, gloves; rank: goggles / visor, drone controller, a heavier armour; heavy bodies for the bruisers; patrols in pairs (`DESIGN` §11.1) |
| Counter units | counter-drone crew · spotter + heavy · hardened tech | pieces | anti-drone gun, insulation suit · spotting scope, insulated armour, reflective plating · shielded case, pressure plates (a floor prop) |
| Machines | watchtower camera on a mast · quad scout drone · auto-turret · motion sensor + flare | | |

### 3.3 Bunsen Burners MC, the Traffickers (orange / brown / green / aqua)

| Tier | Who | Figure | Notes |
|---|---|---|---|
| Leader | **President "Deacon"** (Wade Cutler) | heavy M | |
| Sub-leader | **Vice President "Choirboy"** | M | the overcoat with distinctions |
| Rival boss | **"the Confessor"**, Deacon's hired assassin | M | a hired man, not a patched member; wears the hat-mask, NO goggles (`ACTOR` D83); a boss (`DESIGN` §2.2); the rest of his look is not written |
| EYE | **Vespers**, the lookout with fireworks | M | the firework lure |
| HAND | **Censer**, the chemist | F | gas and sedatives; the dart launcher |
| WALL | **Sexton**, booby traps on the routes | M | the tripwire flash |
| Keeper | **Tithe**, the chop-shop mechanic | F | |
| Abroad | the overseas supplier of the banned precursors | open | a port and a warehouse |
| L3 captain | a Sergeant-at-Arms | officer | |
| Officers | Road Captain (Lt), Sergeant-at-Arms (Cpt) | officer | a BROWN leather duster with orange trim, never an orange coat (it merges with the mustard for colour-blind players, `COSMETICS` §9.4) |
| Pool | Hang-around, Prospect, Patch | pool | a patched vest over a shirt or tee, jeans, boots; rank: bandana or balaclava, chains, a president's colours; heavy bodies for the bruisers; the labs' cooks |
| Counter units | sentry · gas-mask cook · road crew | pieces | none (behaviour only) · antidote injector, respirator, foam extinguisher · sweeping torch, spike strip + roadblock |
| Machines | phone on a pole · RC scout car · jury-rigged shotgun turret · air horn on a battery | | |

The club's bikes are vehicles (mesh, `PROP_PIPELINE_PLAN` §9.5), listed so the club's look is complete.

### 3.4 The Corporation, GRUB DRILL INC (black / purple / navy)

| Tier | Who | Figure | Notes |
|---|---|---|---|
| Leader | **CEO Gordon Pryce** | M | the Senate candidate |
| Sub-leader | **Evelyn Marsh**, the board's bloc leader | F | the overcoat with distinctions |
| Counsel | **Prudence Vane** | F | sells the guard rotations (Marsh's sub-mission, `DESIGN` §2.7); scenes |
| Rival boss + HAND | **Hedge**, the envoy in the LED prototype | M | the shadow generator (seen); the LED coat in lap 2 = the coat silhouette with the LED shader (`DESIGN` §10.5, `MODEL_INVENTORY` §2) |
| EYE | **Ledger**, the hacker of cameras and phones | F | camera loops |
| WALL | **Escrow**, the fixer | F | |
| Keeper | **Margin**, head of the R&D floor | M | |
| Abroad | Carrion Capital's partner, Marsh's buyer | open | the fund's tower |
| L3 captain | a Head of Security | officer | |
| Officers | Case Manager (Lt), Head of Security (Cpt) | officer | a black coat with purple and navy (proposed); the black may vanish on the dark board, so the accents and the emblem carry it (`COSMETICS` §9.4, to measure) |
| Pool | Staffer, Operative, Senior Operative | pool | a suit of their own cut and palette, earpiece; rank: sunglasses, briefcase, the leaders' tailoring; never the Agent's fedora (`DESIGN` §2.1) |
| Counter units | feed monitor · floodlight team · compliance officer | pieces | tablet, multi-spectrum camo suit · flare + portable floodlight, heavy plating · credential reader, keypad (a wall prop) |
| Machines | face-recognition camera · wheeled security robot · ceiling laser turret · laser grid + alarm panel | | |

### 3.5 Outside the factions (listed, not this plan's)

The Agent, Thomas Marlow, the spouse (Claire / Clement), Zest, the civilians and the crowd sets (press, mourners, medical staff, looters):
the same pipeline, owned by `MODEL_INVENTORY` §5 and `COSMETICS` §8.4. The looters are hostile but nobody's faction. **The opening's
slice needs Marlow and a few civilians beside its enemies** (rule 14), so they are made with it. The named rivals of `DESIGN` §11.5 wait
for an IP opinion.

## 4. The common pool (the rank-and-file)

What a faction's thug is made of, from the canon:
- **the faction's base set**, the cloth he always wears (the "Pool" rows of §3);
- **rank pieces**, most of them rigid (cap, helmet, bandana, balaclava, radio, visor, chains, sunglasses, briefcase);
- **the counter units' gear**, three units × three stages per faction: ~22-26 pieces in all (`MODEL_INVENTORY` §8 counts ~22); the
  "(behaviour)", "(zone)" and "(architecture)" stages need no model. Three are whole SUITS (the insulation suit, the insulated armour,
  the multi-spectrum camo suit), which are cloth, not rigid;
- **colour from the faction's palette family**, never a PNG (rule 9).

**What reads at the game camera.** A figure is ~190 px tall and a face ~10 px (`ACTOR` D73, D108): in play a thug is told apart by
silhouette (build, headgear, gear), by the colour of his clothes inside the family, and by skin tone. A face is a portrait's. So a few
bodies go a long way once the headgear and the palette vary, and the segment bounds what is on screen at once (rule 12: 6 guards in a
typical segment, 10 of 2 types in the heaviest).

**How many bodies:** rule 5 says ~10, shared by the four factions; confirmed 2026-11-18 (§6), and read with §12 (one body per sex).

### 4.1 The Standard's outfit per faction, "the piano mover" (Claude's proposal, approved by the Director 2026-11-18: "Tudo ok")

The most common thug is §11.2's Standard rank. Each must read by SILHOUETTE at ~190 px without relying on colour (colour-blind
players); none wears a long coat, which is the officers'. The weapons below are the look; their numbers stay GAMEPLAY-01's.

| | FID: an Agent (the rank) | Calm Waters: an Operator | Bunsen Burners: a Prospect | Corporation: an Operative |
|---|---|---|---|---|
| **Silhouette** | the law's uniform: cap and duty belt | hard and square: helmet, vest, knee pads | loose and wide: an open leather vest, a bandana | narrow and clean: a dark suit, sunglasses |
| **Head** | a navy peaked cap with a white band | a matte grey helmet, goggles pushed up | a brown bandana or a shaved head, a beard | short hair, sunglasses, a coiled earpiece |
| **Torso** | a blue uniform shirt (long sleeves since §12) | a grey tactical top under a red-wine plate vest | a green or aqua tee under the brown leather vest with the Prospect's bottom rocker only (the full patch is not earned yet) | a black jacket, a dark purple shirt, no tie |
| **Legs** | navy trousers with a white side stripe | grey cargo trousers, knee pads | worn jeans | black dress trousers |
| **Feet** | black combat boots | tactical boots | biker boots | black dress shoes |
| **Waist** | a duty belt: radio, handcuffs, baton, holstered pistol | a belt with pouches, a grenade hanging | a wallet chain, a knife | discreet: a pistol hidden under the jacket |
| **Main weapon** | a shotgun | an assault rifle, slung | a sawed-off shotgun or a submachine gun | a compact submachine gun |
| **Casual pose** (§5a) | the shotgun on the shoulder, a hand on the belt | the rifle slung, arms crossed over it | the sawed-off as a cane, leaning | the gun dangling from one hand, on the phone |

**Cost:** rigid pieces (cap, helmet, goggles, earpiece, plates, belts and pouches, chain) are cheap; the cloth that must fit the body is
the expense, the open biker vest and the corporate jacket most of all (they stand off the body).

## 5. Machines and the dog

The ratified roster (`MODEL_INVENTORY` §7.1) is in each faction's "Machines" row: **16 models**, 15 meshes (PP7 where they move: the
drone, the RC car, the wheeled robot, the turrets, the cameras' pan) and the K9 on its own quadruped skeleton and clips (walk, sniff,
alert, bark, down). What they do (sight cone, noise, hacking) is `AI_MASTER_PLAN`'s. **Assumed here (Claude):** their models are made
with the AI that drives them (E-5), not with the human pools. **Not tried:** whether Tripo rigs a quadruped.

## 5a. The enemies' weapons (Director, 2026-11-18)

*"Os inimigos em geral vão ter um tipo de arma principal (mais algumas secundárias) e ela vai estar sendo carregada na mão, a tiracolo
ou seguradas casualmente de umas 3 maneira diferentes."*

- **Each enemy has ONE main weapon type, plus a few secondary ones.** Which weapon per faction, rank and unit is GAMEPLAY-01's (with
  `DESIGN` §10.2 and §11); the two firearm lists that do not match yet are noted in `MOVEMENT` §11.7.
- **The main weapon is carried in sight:** in the hand, slung across the body, or held casually. Claude reads "about three ways" as
  three casual holds besides the hand and the sling, to be chosen on renders (to confirm then).
- **What it asks of the models:** the weapons are `ITEMS`' (anyone carries any weapon, at one size everywhere); new is a SLING on the
  long guns (`ITEMS` §2.1). Where the secondaries ride while the main weapon is out (a holster, the back) is not said yet.
- **What it asks of the poses:** `MOVEMENT` §11.6 step 11 (recorded there): the carries per hold family, the passage from each to the
  aim and back, and walking and running with them (step 10's gaits). The bank holds pistol carries only (S2, S3): no long-gun carry
  exists yet.
- **Detailed (Director, 2026-11-18, later):** the casual holds are silly ways to carry a rifle (resting it on the ground, leaning on it
  like a cane), taken when an enemy is confident and unaware; the secondaries are hidden or hung at the WAIST (a pistol, a grenade,
  other items: belt-hung meshes); stronger bosses add a second weapon (a bazooka, a rifle) on the BACK, a strap across the chest, and
  switch weapons in play. Long-gun carry poses are for every actor (`MOVEMENT` §11.6 step 11).
- **It answers §8's first finding:** a guard does not draw from a coat he does not wear. The officers wear the Agent's body and coat
  (§6), so his draws from the coat, with their keys, work on them as built.

## 6. How each tier could be built (Claude's reading, PROPOSED: the Director's call)

**What the Agent taught, measured in this repo:**
- **A whole Tripo generation brings its clothes already skinned to its rig** (D85), and two generations share every clip (the female and
  the male share the 65 joints, `MOVEMENT` §1 items 2-3).
- **Fitting a CLOTH piece to a body is the dominant cost.** The overcoat on the two Agents has needed work since `ACTOR` D86
  (2026-10-27): its weights, the legs' push (D94), the T pose (D97), the light build's masks and armpit panel (D91-D93, D106-D107), and
  corrective shape keys made BY HAND per clip and per figure (`IdleFix`, `WalkFix`, `RunFix`, `CrouchFix_f*`, `DrawFix`, `ThrowFix_f*`,
  `RiseFix`, `LongDrawFix_f*`: `docs/pipelines/timeline_coat_keys.md`). Every new clip still adds its own. A shape key belongs to one
  mesh: a long coat on a new body starts that work over.
- **A RIGID piece on a bone socket fits a body with one offset per socket and no cloth refitting** (`COSMETICS` §9.8 says it of the
  small accessories; helmets, caps, visors, radios, masks, respirators, chains and a vest of plates on the chest bone are rigid the same
  way).
- **Colour is free** (D87's palette). **A face is not,** and the police form already needs several on the Agent's body: one per
  ethnicity, both sexes (`DESIGN` §2.2, revised 2026-10-25: a choice of race is a whole face).

**The field officers: RULED (Director, 2026-11-18).** *"todo oficial vai ter uma estrutura corporal parecida com o agente (male e
female) + o casaco. Fim. Todo o resto vai ser diferente. Sapato, chapeu, cabelo, calça, camisa, cinto, etc. Então, sim agente e
oficiais são membros da mesma classe. Mas vão ser essencialmente bem diferentes."* An officer is the Agent's body (male or female)
wearing the coat in his faction's colours and emblem (D90); every other slot is his own. What follows (Claude's reading):
- **The coat comes with everything already done for it:** the legs' push (D94), the light build's masks and every hand-made coat key
  belong to that coat on that body, so they carry over. The Freelance captains are officers, and Hedge in the LED coat (a shader on the
  same coat) rides the same body.
- **The swappable slots are new meshes, each fitted once per body:** hair, hat, shoes, belt, tie (`ACTOR` D98's REPLACED pieces). A
  piece fitted to the two bodies serves every officer who wears it, in any faction.
- **The shirt and the trousers are the body's own shell** on the Agent's base (D98 KEPT them, texture only, and deleted the faces they
  hide): an officer's differ by colour, print and material for free. A different CUT is a new mesh made to cover that same body, one
  fitting per cut, wherever a render shows the texture is not enough.
- **In practice, modified versions of the male and female Agents (Director, 2026-11-18, later), and EQUALLY POWERFUL:** each officer
  has specific abilities, which other abilities, items and powers can overcome (their rules are GAMEPLAY-01's).
- **Same class, different people:** the Agent and his colleagues share the slots, never the pieces; the fedora, the tie and the dress
  shoes stay his.

**The pool: RULED (Director, 2026-11-18): route A, the ~10 shared humans.** *"Sim, vamos manter os 10 humanos, que vão ser mais uma camada de variabilidade. Usando todo tipo de artifício para criar mais NPCs e inimigos: facções, logos, skins, cabelos, roupas, calçados, etc."* The ten bodies are one layer of variety, multiplied by every other: faction sets, logos, skins, hair, clothes, shoes. They serve NPCs as well as enemies. Route B below is kept as the record of the choice.

**Two routes for the pool** (decided above):

| | Route A: the canon as written (rules 3, 5) | Route B: Claude's recommendation |
|---|---|---|
| **The pool** | ~10 bare bodies shared by the four factions; each faction's base set (4-5 cloth pieces) fitted to every body | **~4 generations per faction, already IN the faction's base set** (rule 3 read as D89 reads it for the Agent: what a guard always wears is his basic dress); at least one woman; heavy bodies where the faction has bruisers. Rank and counter gear as rigid socket pieces; the three suits as generations of their own |
| **Cloth fittings** | up to ~10 bodies × 4 sets × 4-5 pieces (a scripted transfer of tight pieces, which have no skirt between the legs, is untried) | none for the pool |
| **Pool bodies to generate** | ~10 | ~16 |
| **What it breaks or risks** | the fitting cost grows with bodies × sets | replaces rule 5's "interchangeable across factions"; a faction's base set is baked into its bodies, so a new outfit is a new generation |

**The named characters, in either route:** one generation each (rule 4, and `MODEL_INVENTORY` §5 lists every named one), made chapter
by chapter, never on the pools' critical path. A named character who wears the long coat AND plays on the board (Hedge, in the LED
coat) rides the Agent's coated body, as the officers do. The scene-only cast (the four sub-leaders, Vane: rule 13) needs only its scene
clips, so a coat generated on them needs keys for those alone.

## 7. What exists, and the engine gap

- **On the board today:** the guards wear `agent_live_enemy_white.glb` (the pre-Tripo rig, 20 joints, a white blazer) and the field
  officers `agent_live.glb` (the old Agent, promoted on 2026-11-08: `guard_enemy.gd`'s `officer`, the map's `actors.officers`), through
  `ActorMesh3D.RIG_BY_FAMILY`. Rank has no rules yet (GAMEPLAY). Per faction, the actor shader knows only the reveal silhouette's colours
  (`REVEAL_PALETTES`), not the clothes'.
- **The path exists:** the `TRIPO_FIGURE` flag already puts the Tripo Agent on every actor of a room. Measured on the Moto (`ACTOR`
  D105): a room's 10 actors on the Tripo idle 20.8-20.9 ms against 20.5-20.7 on the old rig; 9 LIGHT figures walking +5.0 ms (about
  0.55 ms each); PSS +10 to +20 MB.
- **The engine step (E-2):** a guard's model chosen by map data (faction, rank, body), the clothes' palette per actor, rigid pieces on
  sockets, the two old rigs retired; then the cost of N DISTINCT models in one segment on the Moto (the memory per model is unmeasured).
  This answers the mesh half of `PERFORMANCE_BUDGET` Q4; rule 2 already settled its rig half.

## 8. Findings for the owner plans (not acted on)

1. **`MOVEMENT`: the draw comes out of the coat.** The pistol leaves the coat's left flap and the long guns its right one (§11.6); with
   one set of animations (rule 2), an uncoated guard reaches into nothing. **Answered 2026-11-18 (§5a):** the enemies carry their main
   weapon in sight, and the officers share the Agent's body and coat.
2. **`COSMETICS` C3: the FID's officers wear the Agent's coat and colour.** From afar the non-cosmetic cue that marks the Agent carries
   much of the difference. **Eased 2026-11-18 (§6):** every other slot of an officer differs, the hat first; a render is still owed
   once the officers exist.
3. **`MODEL_INVENTORY` §5 still lists "Pith & Peel's front man, standard M"**, while `COSMETICS` §8.4 and `DESIGN` §2.8 make him the dead
   colleague, a photograph only.
4. **`DESIGN`: the specialists' rank is not written,** and whether they wear the officer's coat changes how they are built (§6).
5. **`DESIGN` §18: the members abroad are still a proposal** ("three or four trips", one member per faction proposed): 3-4 models.

## 9. Open questions for the Director

1. ✅ **The pool** (ruled 2026-11-18: route A, the ~10 shared humans, §6). Was: **route A or route B?** And how many bodies per faction (Claude: 4, at least one woman, heavy ones where the faction
   has bruisers).
2. ✅ **The officers** (ruled 2026-11-18, §6): the Agent's body (male / female) and the coat; every other slot their own.

## 10. Order of work (proposed; the first slice is ruled, rule 14)

| Step | What |
|---|---|
| **E-0** ✅ | This survey (2026-11-18) |
| E-1 | The answer to §9; the reference sheets for the first slice (prompts as in `ITEMS` §7, for Tripo): the FID pool, the FID officers' own pieces (hair, hats, shoes, belts, ties; shirts and trousers by texture, §6), Graves, the four sub-leaders at the station door, with Marlow and a few civilians (§3.5) |
| E-2 | The engine (§7): guards on the Tripo rig by map data, the clothes' palette per actor, socket pieces, the old rigs retired; the Moto |
| E-3 | The first slice through `build_agents.sh` (the light build), judged in the four real facings |
| E-4 | The other three factions' pools and officers, one per territory, each measured on the Moto before the next |
| E-5 | The named characters chapter by chapter; the counter units' gear with the counters' AI; the machines with theirs |

## 11. Totals

| Kind | Count | Exists |
|---|---|---|
| Named, enemy side | **30**: FID 7, Calm Waters 7, Bunsen Burners 8, Corporation 8 (4 of them the proposed members abroad) | none |
| ... of them women | 11 (+ the members abroad, open) | |
| ... of them heavy | 3: Kessler, Hardcastle, "Deacon" | |
| Field officers | the Agent's two bodies + the coat in 4 faction colours (2 ranks; the 4 Freelance captains among them); per faction their own hair, hats, shoes, belts and ties (meshes) and shirts and trousers (textures), §6 | the old Agent, a placeholder |
| Enemy weapons | `ITEMS`' models + a sling for the long guns; the carry poses are `MOVEMENT` §11.6 step 11 (§5a) | the pistol cycle only |
| Pool bodies | route A ~10 shared, route B ~16 (4 per faction) | the white blazer, a placeholder |
| Rank pieces | `COSMETICS` §8.3's, rigid wherever they can be | none |
| Counter-unit gear | ~22-26 pieces, 3 of them suits | none |
| Machines | 16: 15 meshes + the K9 | none |

## 12. The model pipeline and the first prompt (Director, 2026-11-18)

*"Vamos pensar em como vai ser o pipeline: primeiro vamos fazer a arte no Nano Banana 2 e depois gerar o modelo no Tripo. O estilo TF2
já garante nossa estética low poly. Inimigos vão ter varias cabeças e acessórios diferentes, mas o corpo vai ser compartilhado entre
todos, de forma que as animações são universais (male e female)."*

- **The art: Nano Banana 2, by EDITING the Agent's own Tripo inputs** (`REFERENCES/ACTORS/AGENT/Referencia/MaleNoCoatFront.png` and
  `MaleNoCoatSide.jpeg`; for a woman `femaleNoCoatFront.png` and `femaleNoCoatSide.png`): the edit keeps his body, pose, camera,
  framing and look, and changes only the clothes and the head. So the shared body already holds in the drawing, and the enemies come
  out in the Agent's own style. **The style is anchored on his image, not on the name of the game** (Claude): the prompt leaves "Team
  Fortress 2" out so the drawing does not drift toward Valve's characters; add it if the look needs a push.
- **Two images per model, as the Agents had:** the FRONT, then the SIDE (made from the Agent's side AND the new front, so the views
  agree). Ask for the largest output the tool allows (`ITEMS` §7.1's lesson).
- **BARE first** (rule 3; the Agent's own lesson, `ACTOR` D86: his generated belt fused into the trousers and was removed by hand): the
  model is generated in the faction's basic dress with a bare head; the headgear and the belt with its gear come after, as an item
  sheet (`ITEMS` §7's way), and are fitted to the body. That is also what lets the heads and the accessories vary.
- **The model: Tripo, as the Agents were made** (D85): multi-view, the front plus the side in the LEFT slot (the Agent's side image
  shows his left side), triangles, the parts split, the Mixamo rig.
- **What is kept, decided on the first result (Claude, to see):** (a) the whole generation, whose body follows the Agent's proportions
  on the same 65 joints; or (b) its head and boots moved onto the Agent's own body (`tripo_dress.py`'s way) with the uniform painted on
  his shirt and trousers (D98: texture only), which shares the body exactly. (b) is why the shirt has LONG sleeves: the Agent's sleeves
  have no arms under them.
- **The variety (Claude's reading of the ruling, to confirm):** one body per sex; rule 13's "10 humans" are its heads; headgear, gear
  and palette go on top.

### 12.1 The first model: the FID's Agent (the rank), male, BARE — the FRONT

Attach `MaleNoCoatFront.png`.

```
Edit this image. Keep EXACTLY the same body, proportions, height, pose (the same A-pose: arms slightly away from the body, hands open and relaxed), camera angle, framing, lighting, white background and art style (stylized low-poly game character: bold simple shapes, flat-shaded facets, clean solid colours). Change ONLY the clothes and the head, as described below.

The new man: a rank-and-file patrol officer of a fictional federal police force. Early thirties, a broad face, short black hair cut close at the sides and a little longer on top, clean-shaven, medium-brown skin, a serious, alert expression with the mouth closed. Bare head: no cap, no hat.

His basic uniform, and nothing else:
- Shirt: a medium-blue uniform shirt with LONG sleeves buttoned at the wrists, a pointed collar open at the neck, two buttoned chest pockets, shoulder straps, neatly tucked into the trousers.
- Trousers: navy-blue uniform trousers, straight cut, a thin white stripe down the outer side of each leg, a plain smooth waistband with no belt and no belt loops showing.
- Boots: black lace-up ankle boots, the trousers falling over them.

No belt, no holster, no radio, no pouches, no tie, no jacket, no coat, no gloves, no backpack, no weapon. Hands empty.
Each material a clearly separated solid colour region (blue cloth, navy cloth, black leather, skin, hair). No writing, no badges, no patches, no logos, no dirt, no fabric pattern.
Full body from head to toes, centred, nothing cropped. No text, no labels, no arrows, no other people, no props, no shadow on the floor.
```

### 12.2 The same man — the SIDE

Attach `MaleNoCoatSide.jpeg` FIRST, then the front just made.

```
Edit the first image (a side view). Keep EXACTLY its body, proportions, pose, camera angle, framing, lighting, white background and art style. Replace the clothes and the head with those of the man in the second image (the same man seen from the front): the same face, short black hair and skin, bare head, the same blue long-sleeved uniform shirt tucked in, the same navy trousers with the white side stripe and a plain waistband with no belt, the same black lace-up boots, in the same colours, now seen from the side.
No belt, no holster, no pouches, no tie, no jacket, no backpack, no weapon. Hands empty.
Full body from head to toes, nothing cropped. No text, no labels, no other people, no shadow on the floor.
```

### 12.3 The FID's result (2026-11-18): APPROVED ("Parece tudo ok")

The Director ran §12.1-§12.2 for a man and a woman (her prompt the same, with the woman's references): both bare, long sleeves, the
striped trousers, no belt. Accepted as they came: the boots read as low lace-up shoes, the man shows a white undershirt at the collar.
**The two side views face opposite ways:** his shows his LEFT side (Tripo's LEFT slot), hers faces right, so it shows her RIGHT side
(Tripo's RIGHT slot, or mirror it into the LEFT one). The images are on the Director's disk.

**The order the Director took:** every faction's bare Standard first, both sexes; the accessory sheets after (the FID's: the cap,
the duty belt with its holster, radio, handcuff case and baton).

### 12.4 The second model: Calm Waters' Operator (§4.1), BARE

Next in the circle of favours. The hair is kept flat on top, since a helmet goes on later. The FRONT, with `MaleNoCoatFront.png`:

```
Edit this image. Keep EXACTLY the same body, proportions, height, pose (the same A-pose: arms slightly away from the body, hands open and relaxed), camera angle, framing, lighting, white background and art style (stylized low-poly game character: bold simple shapes, flat-shaded facets, clean solid colours). Change ONLY the clothes and the head, as described below.

The new man: a rank-and-file operator of a fictional private military security company. Mid-forties, a weathered square face, fair skin, a greying buzz cut kept very short and flat on top, a short trimmed beard, a serious, watchful expression with the mouth closed. Bare head: no helmet, no cap.

His basic outfit, and nothing else:
- Top: a fitted mid-grey long-sleeved tactical combat shirt, a short stand-up collar with a zip at the neck, darker charcoal panels on the shoulders and the upper sleeves, a small zipped pocket on each upper sleeve, tucked into the trousers.
- Trousers: charcoal-grey cargo trousers, a large flat cargo pocket on the side of each thigh, reinforced panels over the knees, a plain smooth waistband with no belt and no belt loops showing.
- Boots: black high lace-up tactical boots, the trousers tucked into them.

No armour vest, no helmet, no goggles, no knee pads, no gloves, no belt, no pouches, no holster, no grenade, no backpack, no weapon. Hands empty.
Each material a clearly separated solid colour region (mid-grey cloth, charcoal cloth, black leather, skin, hair). No writing, no badges, no patches, no logos, no dirt, no camouflage, no fabric pattern.
Full body from head to toes, centred, nothing cropped. No text, no labels, no arrows, no other people, no props, no shadow on the floor.
```

For the woman, with `femaleNoCoatFront.png`, the second paragraph becomes the one below, and "His basic outfit" becomes "Her basic
outfit":

```
The new woman: a rank-and-file operator of a fictional private military security company. Late twenties, a lean face with high cheekbones, light-olive skin, dark hair pulled back tight into a low bun at the nape, flat on top, a serious, watchful expression with the mouth closed. Bare head: no helmet, no cap.
```

The SIDE, with the side reference FIRST and the new front second (for the woman: "woman", "her"):

```
Edit the first image (a side view). Keep EXACTLY its body, proportions, pose, camera angle, framing, lighting, white background and art style. Replace the clothes and the head with those of the man in the second image (the same man seen from the front): the same face, buzz cut, beard and skin, bare head, the same grey long-sleeved tactical shirt with the zipped collar and the sleeve pockets, the same charcoal cargo trousers with the thigh pockets and a plain waistband with no belt, tucked into the same black tactical boots, in the same colours, now seen from the side.
No armour vest, no helmet, no knee pads, no belt, no pouches, no backpack, no weapon. Hands empty.
Full body from head to toes, nothing cropped. No text, no labels, no other people, no shadow on the floor.
```

Its accessories, later: the helmet with the goggles pushed up, the red-wine plate vest, the knee pads, the belt with its pouches and
the grenade.

**Result (2026-11-18): APPROVED ("Parece tudo certo").** Both bare as asked. Accepted as they came: the woman came out older and
grey-haired instead of late twenties and dark-haired (more age range for the pool), and the trousers show belt loops. The Director then made a YOUNGER, dark-haired version as asked; the older one may be kept as well (one more head). Her side faces
right, as the FID woman's (Tripo's RIGHT slot); his shows his left side (LEFT slot).

### 12.5 The third model: the Bunsen Burners' Prospect (§4.1), BARE

The shirt is a LONG-sleeved henley tucked in, not the table's tee: the same reason as the FID's sleeves (§12, route (b)); the canon
allows "a shirt or tee" under the vest (`COSMETICS` §8.3). The leather vest is a slot piece (`COSMETICS` §8.2 `vest`), so it comes
with the accessories, like the Operator's plate vest. The FRONT, with `MaleNoCoatFront.png`:

```
Edit this image. Keep EXACTLY the same body, proportions, height, pose (the same A-pose: arms slightly away from the body, hands open and relaxed), camera angle, framing, lighting, white background and art style (stylized low-poly game character: bold simple shapes, flat-shaded facets, clean solid colours). Change ONLY the clothes and the head, as described below.

The new man: a prospect of a fictional outlaw motorcycle club, a biker. Late thirties, a heavy-browed face, tanned light-brown skin, a clean-shaved head, a thick full dark-brown beard, a hard, sullen expression with the mouth closed. Bare head: no bandana, no cap.

His basic clothes, and nothing else:
- Shirt: a dull olive-green long-sleeved henley (a plain knit, three buttons at the neck, the cuffs at the wrists), tucked into the jeans.
- Jeans: faded blue denim jeans, straight cut, a plain waistband with no belt.
- Boots: black leather biker boots, heavy and round-toed, the jeans falling over them.

No leather vest, no jacket, no bandana, no sunglasses, no gloves, no belt, no wallet chain, no knife, no jewellery, no backpack, no weapon. Hands empty.
Each material a clearly separated solid colour region (olive-green knit, blue denim, black leather, skin, beard). No writing, no badges, no patches, no logos, no tattoos, no dirt, no fabric pattern.
Full body from head to toes, centred, nothing cropped. No text, no labels, no arrows, no other people, no props, no shadow on the floor.
```

For the woman, with `femaleNoCoatFront.png` ("Her basic clothes"):

```
The new woman: a prospect of a fictional outlaw motorcycle club, a biker. Early thirties, a sharp freckled face, pale skin, dark auburn hair pulled back into a low ponytail, flat on top, a hard, sullen expression with the mouth closed. Bare head: no bandana, no cap.
```

The SIDE, with the side reference FIRST and the new front second (for the woman: "woman", "her", and her hair instead of the shaved
head and beard):

```
Edit the first image (a side view). Keep EXACTLY its body, proportions, pose, camera angle, framing, lighting, white background and art style. Replace the clothes and the head with those of the man in the second image (the same man seen from the front): the same face, shaved head, beard and skin, bare head, the same olive-green long-sleeved henley tucked in, the same faded blue jeans with a plain waistband and no belt, the same black biker boots, in the same colours, now seen from the side.
No leather vest, no jacket, no bandana, no belt, no wallet chain, no backpack, no weapon. Hands empty.
Full body from head to toes, nothing cropped. No text, no labels, no other people, no shadow on the floor.
```

Its accessories, later: the brown leather vest with the Prospect's bottom rocker (the emblem a decal, `ACTOR` D90), the bandana,
the wallet chain, the knife.

**Result (2026-11-18): APPROVED ("Parece tudo ok").** Both bare; accepted as they came: the man's henley is untucked, the boots
read as low ones. Her side faces right (Tripo's RIGHT slot), his shows his left side (LEFT).

### 12.6 The fourth model: the Corporation's Operative (§4.1), BARE

The suit jacket is a slot piece (`COSMETICS` §8.2 `jacket`), so it comes with the accessories; the bare model is the shirt, the dress
trousers and the shoes. The Corporation wears no headgear, so the hair is free. The FRONT, with `MaleNoCoatFront.png`:

```
Edit this image. Keep EXACTLY the same body, proportions, height, pose (the same A-pose: arms slightly away from the body, hands open and relaxed), camera angle, framing, lighting, white background and art style (stylized low-poly game character: bold simple shapes, flat-shaded facets, clean solid colours). Change ONLY the clothes and the head, as described below.

The new man: a private security operative of a fictional corporation. Late twenties, a lean clean-cut face, East Asian features, light skin, short neat black hair parted at the side, clean-shaven, a cold, composed expression with the mouth closed.

His basic clothes, and nothing else:
- Shirt: a dark purple dress shirt with long sleeves buttoned at the wrists, a pointed collar buttoned up to the neck, no tie, neatly tucked in.
- Trousers: black slim dress trousers with a sharp crease, a plain smooth waistband with no belt.
- Shoes: black polished dress shoes.

No suit jacket, no coat, no tie, no sunglasses, no earpiece, no gloves, no belt, no holster, no watch, no jewellery, no backpack, no weapon. Hands empty.
Each material a clearly separated solid colour region (purple cloth, black cloth, black leather, skin, hair). No writing, no badges, no logos, no dirt, no fabric pattern.
Full body from head to toes, centred, nothing cropped. No text, no labels, no arrows, no other people, no props, no shadow on the floor.
```

For the woman, with `femaleNoCoatFront.png` ("Her basic clothes"):

```
The new woman: a private security operative of a fictional corporation. Mid-thirties, a sharp composed face, dark-brown skin, black hair in a sleek chin-length bob, a cold, composed expression with the mouth closed.
```

The SIDE, with the side reference FIRST and the new front second (for the woman: "woman", "her", and her bob):

```
Edit the first image (a side view). Keep EXACTLY its body, proportions, pose, camera angle, framing, lighting, white background and art style. Replace the clothes and the head with those of the man in the second image (the same man seen from the front): the same face, neat black hair and skin, the same dark purple long-sleeved dress shirt buttoned to the neck and tucked in, the same black dress trousers with a plain waistband and no belt, the same black dress shoes, in the same colours, now seen from the side.
No suit jacket, no tie, no sunglasses, no earpiece, no belt, no backpack, no weapon. Hands empty.
Full body from head to toes, nothing cropped. No text, no labels, no other people, no shadow on the floor.
```

Its accessories, later: the black suit jacket (it hides the pistol), the sunglasses, the coiled earpiece, the hidden holster.

**Result (2026-11-18): APPROVED ("Tudo ok").** Both bare; accepted as they came: the woman came out with East Asian features and
light skin instead of dark-brown skin. Her side faces right (RIGHT slot), his shows his left side (LEFT).

**The four factions' bare Standards are done, both sexes (2026-11-18): 9 heads so far** (the older Operator woman kept as one more).
**Next (Director: "As pranchas de acessórios montamos amanhã"):** the accessory sheets per faction (§12.2-§12.6's "accessories,
later" lines), then Tripo.

**Licence note (2026-11-19, the Tripo terms read again):** a gallery model may be used only if its author generated it on a FREE
account (§5.2.1 waives the rights); a paid author's public model stays his (§5.2.3 licenses Tripo alone), and the page does not show
which plan made it. **Ruled by the Director: we generate our own.**

### 12.7 The FID's accessory sheet (Nano Banana 2, `ITEMS` §7's way)

Front + side per object, one real scale, then Tripo by pages (`ITEMS` §7.10). Sizes are for an adult; each piece is fitted to the
shared body afterwards.

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns.
Each row is ONE object: its FRONT view in the left column, its SIDE view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Police peaked patrol cap, 21 cm across, 12 cm tall: a navy-blue soft crown, a white band all around it, a short stiff black visor. Shown on its own, empty, no head inside.
2. Police duty belt laid out as a closed ring seen as worn, 34 cm wide (waist size), 5 cm tall: thick black leather, a plain silver buckle, a row of black keepers. Nothing attached to it.
3. Black leather pistol holster for the right hip, 22 cm tall: a closed flap, a pistol grip showing at the top, a belt loop at the back.
4. Black radio pouch with a handheld police radio in it, 18 cm tall: a short stub antenna, a belt loop at the back.
5. Black handcuff case, 10 cm tall: a closed flap with a snap, a belt loop at the back.
6. Short black police baton, 50 cm long, 3 cm thick: a side handle near one end; in the side view it hangs downward.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (navy cloth, white cloth, black leather, metal). No textures, no wear, no badges, no logos, no writing.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
No text, no labels, no numbers, no arrows, no measurements, no hands, no people.
```

### 12.8 Calm Waters' accessory sheet

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns.
Each row is ONE object: its FRONT view in the left column, its SIDE view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Tactical combat helmet, 24 cm across, 18 cm tall: matte grey shell with side rails, protective goggles with dark lenses pushed up and resting on the front of the helmet, a black chin strap hanging open. Empty, no head inside.
2. Plate-carrier armour vest, 40 cm wide, 45 cm tall, seen as worn but empty: a dark red-wine front plate panel and a matching back panel, joined by black shoulder straps and side straps, open in the middle where the body would be, three flat magazine pouches across the front.
3. Pair of knee pads, each 12 cm wide, 18 cm tall: a hard rounded grey cap over a black padded base, two black elastic straps; draw ONE pad, front and side.
4. Tactical belt laid out as a closed ring seen as worn, 34 cm wide, 5 cm tall: black webbing, a flat metal quick-release buckle. Nothing attached to it.
5. Pair of small black belt pouches side by side, each 10 cm tall, with a belt loop at the back.
6. Round fragmentation grenade with its lever and ring pin, 10 cm tall, hanging from a short black clip.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (grey shell, red-wine cloth, black webbing, metal, dark lens). No textures, no wear, no badges, no logos, no writing.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
No text, no labels, no numbers, no arrows, no measurements, no hands, no people.
```

### 12.9 The Bunsen Burners' accessory sheet

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns.
Each row is ONE object: its FRONT view in the left column, its SIDE view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Biker's leather vest, 44 cm wide, 55 cm tall, seen as worn but empty: worn brown leather, sleeveless, open at the front with no buttons, a turned-down collar, two small chest pockets; on the back a plain curved blank strip near the bottom hem (a bottom rocker with no text). Front view shows the open front, side view its profile.
2. Bandana tied on the head as a skullcap, 20 cm across, 10 cm tall: brown cloth tight over the crown, a small knot at the back with two short tails. Empty, no head inside.
3. Black leather biker belt laid out as a closed ring seen as worn, 34 cm wide, 4 cm tall: a heavy square steel buckle. Nothing attached to it.
4. Wallet chain, 35 cm long: a heavy steel chain hanging in a loose U, a clip at one end and a small black leather wallet at the other.
5. Knife in a brown leather belt sheath, 25 cm tall: a black handle showing above the sheath, a belt loop at the back.
6. Pair of black fingerless leather gloves; draw ONE glove, back of the hand and side, fingers straight.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (brown leather, brown cloth, black leather, steel). No textures, no wear marks, no patches with symbols, no logos, no writing.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
No text, no labels, no numbers, no arrows, no measurements, no hands, no people.
```

### 12.10 The Corporation's accessory sheet

```
Orthographic product reference sheet, a technical turnaround for 3D modeling. Portrait page, 6 rows, 2 columns.
Each row is ONE object: its FRONT view in the left column, its SIDE view in the right column (the same object rotated 90 degrees, same scale, same vertical alignment). All six objects are drawn at the same real-world scale, relative to each other.
Rows, top to bottom:
1. Black single-breasted suit jacket, 46 cm wide, 75 cm tall, seen as worn but empty: slim cut, notch lapels, two buttons closed, long sleeves, a flap pocket on each side, hem at the hips. Front view buttoned, side view its profile.
2. Black wraparound sunglasses, 15 cm wide: thin black frame, dark lenses, straight arms.
3. Security earpiece with a coiled clear tube, 25 cm long: a small black ear bud, the transparent coiled tube hanging down from it.
4. Black leather shoulder holster harness laid out as worn, 40 cm wide: two straps crossing at the back, a holster under the left arm with a pistol grip showing.
5. Plain black leather dress belt laid out as a closed ring seen as worn, 34 cm wide, 3.5 cm tall: a small silver buckle. Nothing attached to it.
6. Black aluminium briefcase, 45 cm wide, 33 cm tall, 10 cm thick: a top handle, two silver latches.
Style: stylized low-poly game asset, flat-shaded facets, clean simple shapes, bold readable silhouette, solid flat colours with clearly separated material regions (black cloth, black leather, dark glass, clear plastic, silver metal). No textures, no wear, no badges, no logos, no writing.
Rendering: flat even studio lighting, no cast shadows, no reflections, plain light grey background, wide empty spacing between objects, nothing touching or overlapping.
No text, no labels, no numbers, no arrows, no measurements, no hands, no people.
```

### 12.11 Where the art is, and the first Tripo generation (2026-11-19)

The bare Standards (both sexes, the four factions) and the four accessory sheets are on the Director's disk, in
`REFERENCES/ACTORS/ENEMIES/` and `REFERENCES/ACTORS/ENEMIES/ACESSORIES/` (local, like all of `REFERENCES/`). **One Tripo generation is left this
month: the Director makes the male standard guard** (`cop_male_front.jpg` + `cop_male_side.jpg`), so the engine can start on a
second body and the placeholder guards (`agent_live_enemy_white.glb`, §7) can retire: step E-2.

### 12.12 The guard skinned on the Agent's skeleton (2026-11-19)

The month's Tripo generation came without the parts split and without the auto-rig (no credits until December):
`ASSETS/MODELS/actors/enemies/FID/guard_male/source/tripo_cop_male_no_rig.glb`, one mesh, 19 765 triangles, 1.0 m, no material. Laid over
`MALE_AGENT_BASE` the silhouettes coincide front and side (the art was an edit of his image), so **`tools/asset_generation/tripo/
enemy_skin_from_agent.py`** gives it the Agent's 65-joint armature and copies his skin weights to the nearest surface (4 influences,
normalised): 10 971 vertices, none unweighted. The bank's `walk` plays on it in the four facings at the game camera with no tear
(Blender, `temp/enemies/`). Open: the light build (~5 k), the palette by region, the separable pieces (cut by region), then E-2.

### 12.13 The guard on the board (2026-11-19): E-2's first slice BUILT

- **The light build:** `tools/asset_generation/tripo/enemy_light.py` decimates the skinned guard to 5 000 triangles and colours it
  by REGION, one material each (the bone that weighs most on a face: head = skin with the crown and the back as hair, the collar
  set apart from the neck; torso and arms = shirt; hips and legs = trousers; feet = shoes), from a palette file
  (`enemy_palette_fid_male.json`). It keys one rest frame, since Godot gives a GLB an AnimationPlayer only when it carries a clip.
  Output: `ASSETS/MODELS/actors/enemies/FID/guard_male/game/ENEMY_FID_MALE_LIGHT.glb`. The stripe on the trousers and the face are not painted; a few
  collar faces at the nape still take the skin colour (hidden at the game's size).
- **The engine:** `ActorMesh3D.TRIPO_BY_FAMILY` puts that body on the rank-and-file family (`_enemy_white`), playing the male
  Agent's game clips; `agent_live_enemy_white.glb` is no longer read. The officers keep the old Agent's rig (`_officer`) until their
  own body exists (§6).
- **Checked:** PLAYGROUND's nine guards boot on it with no error; capture `capture.py --map PLAYGROUND --still guard_7 --mode detail
  --view all` (the map's automatic `guard_<n>` anchors); `verify.py smoke` green. **Not measured:** the Moto with ten actors on two
  different Tripo bodies (the memory per distinct model, §7).

### 12.14 The guard's painted texture (2026-11-19)

The five flat region colours became one atlas painted from the reference sheet (`REFERENCES/ACTORS/ENEMIES/`), by
`tools/asset_generation/tripo/enemy_texture.py` run on enemy_light.py's output. The atlas is 2:1: the LEFT square is the head on a
cylindrical projection about the neck (the face upright and frontal at its centre, the seam down the back), for the Director to
paint by hand; the RIGHT square is the body (smart projection). The paint is a function of each texel's position at rest, read
from the bones: chest pockets with flaps, placket and buttons, epaulettes, collar, cuffs, the white undershirt at the collar's
opening, the trousers' waistband and white side stripe, the crease, the shoes' soles, the hairline. The per-face regions of
enemy_light.py are settled again per texel at the neck (the collar measured on the source: it stands 0.06-0.10 m out up to
0.855 m and rises at the back), at the waist (the shirt's hem weighs on the hips bone) and at the wrists.

- Master: `ASSETS/MODELS/actors/enemies/FID/guard_male/textures/enemy_fid_male_master.png` (2048 x 1024); the GLB carries it at 1024 x 512.
- Face file: `ASSETS/MODELS/actors/enemies/FID/guard_male/work/FACE_PAINT_ENEMY_FID_MALE.blend` (the mesh at rest wearing the master by path: Image > Save writes the
  master). A rerun of enemy_texture.py KEEPS the master's head square (`ENEMY_TEX_FORCE=1` repaints it and loses the hand paint).
  The face goes into the GLB by rebuilding the chain from the source (`enemy_skin_from_agent.py` -> `enemy_light.py` ->
  `enemy_texture.py`; the intermediates live in `temp/`): the body is repainted, the head kept.
- Seen on the board in four views (`capture.py --map PLAYGROUND --still guard_7 --mode detail --view all`). Not measured on the
  Moto (one 1024 x 512 texture, below the 5 % rule).

**The face (2026-11-19, later).** The head square now uses the male Agent's FaceUV (`face_uv_map.py`, `male_faceuv.json`): the enemies
share his silhouette, so his painted `male_face_master.png` is the layout an enemy face is drawn on (test-fitted: his face on the
guard lands eyes, nose and mouth in place). The Director draws the guard's face from it (Nano Banana, then by hand) as a 2048 x 2048
`painted/ENEMIES/FID/enemy_fid_male_face.png`; `enemy_texture.py` drops it into the head square, replacing skin and hair only (the collar stays
the shirt's). Without it the script writes `painted/ENEMIES/FID/enemy_fid_male_face_guide.png`. The Agent's master is bald (his hat covers it):
an enemy face image must carry the hair too.

**The face prompt (Nano Banana 2, 2026-11-19).** Input: the male Agent's `male_face_master.png` (2048 x 2048).

> Edit this image. It is a flat, unwrapped face texture for a 3D game character: keep it EXACTLY the same layout, the same square
> size, the same flat front-facing projection, and every feature at the same position and size: eyes, eyebrows, nose, mouth, ears,
> jawline, cheeks. Keep the same painted, soft stylised look and the same flat even lighting with no shadows from a light source.
> Change only the person: a Black man in his thirties, dark brown skin (#8d5a3b), clean-shaven with no beard, no moustache and no
> stubble, a calm stern expression, dark brown eyes, short black eyebrows. Add short black hair, a close crop with a clean straight
> hairline, covering the whole top, the sides above the ears and the back of the head down to the nape, the hair filling the upper
> part of the square the way a scalp unwrapped around the head would. Skin everywhere else, the same tone to every edge of the
> image. No background, no border, no text, no shading of a 3D head: it must stay a flat texture map.

**The face installed (2026-11-19).** The Director's face, `painted/ENEMIES/FID/cop_male_face_master.jpg` (1024 x 1024, from the prompt
above), goes in with `ENEMY_FACE=<file>`. The guard's head is a little taller than the Agent's, so its crown lies past FaceUV's top:
those texels are clamped to the square's top edge, and the edges (the crown's row, the back seam's column above the nape) and the
generated crown are painted hair, so a face image that paints only the hairline band still gets a full crop.
**The face aligned (2026-11-19, the Director: eyes and nose landed low).** The guard's head sits 2.0 cm higher and 1.3 cm forward of
the Agent's: `enemy_texture.py` moves FaceUV by the offset between the two nose tips (the Agent's measured on AGENT_MALE_LIGHT.glb).
The neck under the jaw shares the jaw's texels on a cylinder, so faces below the chin (nose - 5.5 cm) and below FaceUV's floor go to
the body's square.

**Where an enemy's files live (the Director, 2026-11-19): one folder per faction.** `ASSETS/MODELS/props/tripo_enemies/<FACTION>/`
(Tripo's raw generations) and `ASSETS/MODELS/actors/agent/<fig>/textures/ENEMIES/<FACTION>/` (the face, the master, the guide); the FID's
folder is `FID`.

**The master is the Director's (2026-11-19).** The game reads the guard's painted atlas itself
(`actors/enemies/FID/guard_male/textures/enemy_fid_male_master.png`, `ActorMesh3D` `TRIPO_BY_FAMILY` `atlas`), replacing the copy
inside the GLB, so his Photoshop save reaches the board when Godot reimports it (its `.import` is versioned: mipmaps + VRAM
compression); Blender's paint file links the same PNG (Image > Reload). `enemy_texture.py` keeps an existing master and only
rebuilds the GLB around it (`ENEMY_TEX_FORCE=1` repaints it and loses the edit). Proved on the board: the master inverted, the
guards drew inverted; restored, normal. The cost: the script's rules (collar, stripe, pockets) are frozen in the PNG from now on.

**Head and uniform are two maps (2026-11-20, the Director).** The one 2048 x 1024 atlas is split into
`textures/enemy_fid_male_head.png` (the head on the male Agent's FaceUV) and `textures/enemy_fid_male_body.png` (the uniform), 1024 x 1024
each, cut losslessly from his edited master (the master and its copy inside the GLB are gone; his `.psd` stays his). The GLB carries two
materials, `Enemy_head` and `Enemy_body`, each with its u stretched back to 0..1; `ActorMesh3D`'s `maps` names the PNG per material
(the carried weapon keeps its own texture: before this it was given the atlas too). So a face and a uniform swap apart: N heads x M
uniforms, never N x M atlases. The MESH is still one piece: a head shared by two different bodies needs a standard neck ring (same
height, vertices and weights; the collar covers the cut) and waits for the second enemy body.

**Head and body are two meshes, the head Tripo's own piece (2026-11-20, the Director: "de maneira efetiva e completa").** Tripo models
the head and neck as a loose piece (the eyes two more inside it). `enemy_light.py` marks it before the decimation (a vertex group;
the collapse never joins two pieces) and gives its faces skin or hair only; nothing else is (the hands are `Enemy_hands`, skin's
colour; what the neck bone weighs on outside the piece is the collar). `enemy_texture.py` puts the whole piece on the HEAD map:
FaceUV for the face, and the neck below the chin, which falls on the face's own texels on FaceUV's cylinder (the streaks of
2026-11-19), on a band of their own under the face (same angle, height along the neck). Only BELOW the chin: moving every downward
face under the nose too took the lips' and the chin's undersides off FaceUV and broke the mouth (measured and reverted the same day).
`ENEMY_NO_CARRY=1` keeps the maps as they are when they already fit the layout. The GLB carries two meshes,
`Head` and `Body`, on one skeleton; the paint file the same. When the layout changes under the Director's maps, his paint is
CARRIED across triangle by triangle from the GLB being replaced (same rest geometry, matched by centroid; `ENEMY_REPAINT_BODY=1`
carries the head only and paints the uniform afresh), and a head-piece triangle the old layout had on the body map takes the skin of
his lower face. The chain: `enemy_skin_from_agent.py` -> `enemy_light.py` -> `enemy_texture.py`, intermediates in `temp/enemies/`.
Left: the `Icosphere` (42 vertices, no parent) that rides in the light GLB since the first build.

**The triangle under the chin was FaceUV's axis (2026-11-20).** FaceUV is a cylinder about the head's vertical axis, and on the guard
that axis (y -0.022) runs 6 mm behind the throat's front (-0.028): every face within a few centimetres of it spans 25-60 % of the
map's width (measured per face) and shows as a flat triangle without texture, which no painting could fix (a checker on the head
showed it). Fix in `enemy_texture.py`: faces under the jaw within 4.2 cm of the face's midline axis (the nose's x, so both sides cut
alike; the chin's front and the lips start at 4.3 cm) join the neck band, and the band is unrolled about the NECK's own axis (between
the Neck and Head bones) with its height along the profile (z plus the distance from that axis), so the jaw's underside is a strip
and not a line. Overlap in the band 1246 -> 360 texels; FaceUV itself unchanged (the Director's PSD stays aligned). What is left is
paint: the band's top now holds the jaw's underside, to be blended into the chin's lower edge (a transparent layer for the PSD,
`work/enemy_fid_male_head_chin_blend_layer.png`, made by a 3-D seam blend: within 12 mm of the seam a band texel takes the colour of
the nearest FaceUV texel).

**The jaw's sides went back on the face (2026-11-20, the Director's dot test).** He painted red and blue spots on the map's jaw
beside the chin and a green one on the chin: only the green showed on the head. The 4.2 cm circle had taken the jaw's sides too,
16 faces that look OUT (normals' z -0.17 to -0.58), not only its underside, 9 faces that look DOWN (-0.76 to -0.99), so the face
painting's jaw fell on no triangle and the jaw showed the band's flat brown. Now a near face joins the band only when its normal's
z is under -0.7 (`UNDER_JAW_NZ`); the jaw's sides are on FaceUV, where the painted face already has them, and its underside stays
on the band (no fans: a checker shows the band's stripes under the chin). The band's height range is taken over the whole lower
head (below the chin or near the axis, whichever way a face looks), so which near faces join it never rescales it: the 59 faces
that stay on the band keep their texels exactly (0 texel shift measured) and the paint in it stays put. Rebuilt with
`ENEMY_NO_CARRY=1`: a carry would have copied the band's brown over the painted jaw. A test build to another path must also set it
(that path's GLB from an earlier test is the "old layout" the carry reads, and the maps are rewritten).

**Open at the close of 2026-11-20:** the Director, after the jaw fix: "de novo o problema é a projeção", without saying where. The
measured candidates (downward faces still on FaceUV, the nose's underside and the mouth's slit; the band's seam under the jaw; the
jaw's stretched sides; FaceUV's single axis 6 mm behind the throat) are in `PROMPTS/RESUMO_SESSAO_2026-11-20_GUARD_HEAD_MAP.md`.
