# RESUMO DA SESSÃO — 2026-10-23 — The faction dress, the progression rulings, the plot pass, the plot closed

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`: `295173aa`, `15d6bd1a`, `c4591e18`, `54ed6f61`, and this record). Design and
planning only; nothing was built or rendered. The Director asked to plan before executing ("não precisa executar ainda, vamos planejar
primeiro"). **Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-22_STORY_COSMETICS_LAUNCH.md`.

## 1. What the Director asked

The Agent's whole outfit, including each faction's version, recognisable by details, symbols, colours, pins and accessories: *"A gente não
vai mudar o estilo de se vestir propriamente dito, mas a embalagem final. Nos retratos do ranking vai ficar mais evidente porque vamos usar o
banner no fundo como complemento."* That opened a wider set of rulings on rank, access, the LED coat, enemies, the ending and the classes.
Claude separated them by theme, checked each against the canon, and flagged the collisions.

## 2. Where each ruling lives

| Ruling | Where | State |
|---|---|---|
| A faction is PACKAGING on the same dress; the banner behind the ranking portrait completes it | `ACTOR` D78, `COSMETICS` §3, §9 | ratified |
| Every faction's field officers (the Lieutenant tier and the sub-leaders) wear an overcoat in its colours and symbol; the Agent is an FID Inspector below Barrow (his modest pay, the police's internal dispute) | `DESIGN` §2.1, §11.2, `COSMETICS` §8.3 | ratified |
| Mustard is the FID investigators' coat; his hat, shoes and tie set him apart | `DESIGN` §2.1, `ACTOR` D70 note | ratified |
| The start kit: a common pistol, the coat (black inside), stones, a chokehold (wakes after N turns) or a neck snap (dead), a balaclava, the coat stowed in the pack; shadow stealth works fully from the start | `DESIGN` §10.0 | ratified |
| He starts in an ordinary fedora and finds the hat-mask early, in the official work every route shares | `DESIGN` §2.2, §10.0, `ACTOR` D77 note | ratified (Claude's recommendation) |
| Access: police facilities only at the start; other turfs closed even after a faction's contact; a PASS comes from a leader's trust or an inside mechanism; a BLUFF is the LED coat's symbol; each access incorporates that faction | `DESIGN` §2.2 | ratified (the pass / bluff shape is Claude's, under delegation) |
| Lap-1 chapters are infiltrations on the investigated turf; a favour earns the ASKER's pass; after the badge, Graves's favours earn no police pass | `DESIGN` §2.2 | ratified + plot-pass fix |
| The LED coat: the Corporation's secret project, replaces the common coat, shows any incorporated faction's symbol from afar (not too close, never switched in sight), needs energy; a mid-to-late-game tool on EVERY route (met in lap 1 through Hedge, acquired in lap 2) | `DESIGN` §10.5, `ACTOR` D72 note | ratified (the lap-2 anchor is Claude's obvious reading) |
| Specialists: about three per faction, each the author of a tech the Agent can acquire after meeting it; enemies and Agent evolve together (Phoenix Point) | `DESIGN` §11.6 | ratified (the roster and the Eye / Hand / Wall template are proposals) |
| Classes = the BACKGROUND stated in the deposition (lifelong policeman, ex-biker, army veteran, ex-private security); it decides abilities, equipment and the ranking's faction; being approached grants no access | `DESIGN` §2.2, §15, `COSMETICS` §2 | ratified (the background → faction → handler mapping is Claude's, under delegation) |
| The police from inside: Graves bans him in public and runs him off the books in every route; Barrow runs him too on the policeman's background; neither knows of the other; the badge is taken to bury what he found at the pit | `DESIGN` §2.2, §2.7 | Claude's, under delegation |
| Who takes the blame: the leaked Graves–"Deacon" deal, built from lap 1's favours and the Agent's own lie (the policeman killed in the flood); the memorial is the sub-leaders' truce; every sub-leader ends believing him innocent of the dam | `DESIGN` §2.2, §2.7 | Claude's, under delegation |

## 3. The plot pass (2026-10-23)

**Fixed in the text (`15d6bd1a`):** Graves's favours after the badge earn no police pass; the police chapter is the one lap-1 chapter entered
on his own badge; Pith & Peel was registered BEFORE the disaster to the colleague who lent his name (a "laranja"); the reporter sees his source
barred from the case, not suspended.

**Ruled by the Director on Claude's recommendations (`c4591e18`):** the truth stays buried even if the reporter lives and publishes (a
conspiracy theory against the truce and the faked death); the puts paid into Pith & Peel's account in the dead colleague's name, untouchable
for the living Agent, a second motive for the faked death; "innocent" means of the dam, and each handler keeps his complicity quiet;
Hardcastle's rescue is a Militia publicity stunt; the Corporation carries no weapons IN PUBLIC. Then (`54ed6f61`): the LED coat is mid-to-late
game on every route.

## 4. The plot: CLOSED (Director, 2026-10-23)

The structure has no known hole. **What stays open is authoring detail or gameplay, none of it structural** (`DESIGN` §18):

- **Plot details to write:**
  - which official mission holds the hat-mask, and who built it;
  - the official missions themselves (only the power station is named);
  - where the investigation abroad sits in the laps;
  - the debt's specific origin (the rank explains the pressure);
  - how much he hands over at the Militia's and the Corporation's favours;
  - each sub-leader's character beyond name and motive;
  - the epilogue's joints (the badge taken back, the ring, his blood on the pit's edge, the foreclosed house);
  - what the reporter does with the gun (the truth stays buried either way);
  - which lap-2 confrontation is the complete mission.
- **Gameplay:**
  - the four backgrounds' abilities and equipment;
  - the chokehold's N turns;
  - the energy numbers and recharge;
  - the bluff's distances and what reveals it;
  - the specialist roster and template;
  - §11.1's counters for four factions.
- **Look (proposed, `COSMETICS` §9, `ACTOR` D78):**
  - accent zones;
  - the colour-blind-safe palette (CIEDE2000 worst pair 31.5 / 33.7 / 23.6 / 27.5 against the poster's 25.8 / 7.1 / 9.3 / 8.2);
  - the mark of his past per background;
  - the field officers' coats per faction.
  - The poster (`DIAGRAMS/CIRCULO_ENREDO.png`) keeps its placeholder colours until the palette is ratified.
- **Outside the game:**
  - a city that lived a real dam disaster;
  - an IP opinion before named rivals (§11.5);
  - registry checks of every name.

## 4b. Later the same day (Director)

- **The mask:** it belongs to a hired assassin "Deacon" contracted, who is investigating the same thing; the Agent arrives late at a site
  already infiltrated, eliminates him in time, and takes the hat-mask. Only "Deacon" knows where it came from.
  - Claude placed it at an official-work site, so it stays early and at the same point in every route.
  - Claude proposed that the assassin counts as a boss (excluded from the violence count) and the name "the Confessor".
  - Claude noted the fair-reveal reading: the "luck" is the Agent silencing an investigator closing in on him (`DESIGN` §2.2).
- **The pack battery is a later upgrade** powering both the mask and the LED coat (`DESIGN` §10.5, `ACTOR` D72 / D77 notes).
- **The trips abroad:** three or four, to find a faction member operating from abroad and to vary the scenery on the globe. Claude proposes
  four, one per lap-1 chapter (`DESIGN` §2.6, `PROP_PIPELINE` §9.2, `COSMETICS` §8.4).
- **The palette's families are the Director's:**
  - police blue / white / yellow;
  - traffickers orange / brown / green / aqua;
  - militia red / wine / grey / white;
  - corporation black / purple / navy.

  Measured (`COSMETICS` §9.4): the primaries are excellent once their values are pulled apart (35.9 / 26.3 / 23.3 / 25.0). The risk is in the
  secondaries (green beside red 3.2 deutan, purple beside blue 9.9), so accents never carry a faction alone. The bikers' officers wear a brown
  coat, since orange collapses against the mustard coat.

## 5. Memory

Claude's project memory was consolidated at the Director's request: 189 files → 17, the index 20.8 KB → 2.6 KB; the retired files are archived
in the memory folder (`_archive/retired-2026-10-23.tar.gz`). Lessons merged by theme (verification, performance, architecture), the
Director's preferences grouped, the stale "Agency vs Network" premise removed, the "severed motors" (`NoiseSystem.emit()` with no callers,
`PassageQuery` unread, as of 2026-08-30) kept as open threads to check before gameplay work.

## 5b. Later the same day (after the plot closed)

- **D78 renders:** `Screenshots/history/d78_faction_dress_*.png` (portraits, game size with a deuteranopia row, officer coats, the Agent in each uniform). Tools: `tools/asset_generation/hero/hero_faction_dress.py`, `faction_dress_art.py`, `faction_palette.json`. The bikers' armband on the Agent is brown with orange stripes.
- **Uniform ≠ access** (`DESIGN` §2.2):
  - a uniform passes from afar;
  - access plus the right uniform means he is left alone;
  - up close (a checkpoint, the GU next to an officer) he is always recognised;
  - standing per faction: none / access / wanted;
  - one uniform per mission until the LED coat;
  - the armband follows the coat.
- **Failure and alert** (`DESIGN` §2.2):
  - caught → wanted → silence the witnesses (a knockout or a dart counts) and escape; the alert rises;
  - seen masked, he is taken for the club's assassin;
  - highly watched zones block the LED coat;
  - death or arrest → game over, back to the map; the failure screen tells his fate.
- **Neutral missions between the laps** (Freelance-like, dividends); their kills count in the violence average (redemption).
- **The tech and skill tree** (`DESIGN` §15, `DIAGRAMS/ARVORE_TECNOLOGICA.png`):
  - 4 factions × EYE / HAND / WALL × lap 1 / lap 2 / Freelance;
  - each node has an enemy counter; visors become mask modules;
  - backgrounds pick ONE own-faction L1 node plus a passive and an active;
  - the balance pass and the map affordance tags were adopted.
- **The LED coat** comes from Hedge, the Corporation envoy who watches the Agent (glints in earlier maps). Faction stores: the evidence room and the armoury.
- **Start kit = the attack's gear** (a fair-reveal clue): alarm clock (retrievable under a rule), spray can, chloroform, a short rope and hook for authored traversals. Perches (Arkham predator) come later; still one playable plane.
- **Distractions** (`DESIGN` §5.4): stones are the bread and butter (a limited stack, swappable items), scenery distractions, a universal remote. They depend on wiring the noise pipeline (`AI_MASTER_PLAN`).

## 6. Natural next steps

- Wire the noise pipeline (the Director: next).
- The consolidated model inventory (slots + cast + props from the tree).
- (done) The decision renders for D78 (the four faction versions at portrait size and at 132×200, the palette on the real hero), as the Director's
  "render, don't describe" rule asks.
- The hero adapter to `ActorMesh3D` (bone and action names), still the first job before the hero is playable (`ACTOR` D77).
