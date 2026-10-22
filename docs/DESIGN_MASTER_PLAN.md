# INFILTRAITOR — Design Master Plan

> **The game-design canon: every ratified mechanic, in one place, in English.**
> Recovered 2026-08-06 from the June 2026 brainstorming archive, which was
> stamped DEPRECATED for its *architecture* sections while its *design*
> sections had never been superseded by anything.

---

## How to use this document

**This file owns design intent — what the game does and why.** It does not
own implementation status, tuning values in force, or code structure. Those
belong to the docs linked per section, and those docs win on detail.

| If you want | Read |
|---|---|
| What the game *is*, and the pillars that break ties | [`vision/game_vision.md`](vision/game_vision.md), [`vision/pillars.md`](vision/pillars.md), [`vision/design_philosophy.md`](vision/design_philosophy.md) |
| **What each mechanic does** | **this file** |
| How a built system actually works today | [`systems/`](systems/), [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| What is built, half-built, or paused | [`README.md`](README.md) master-plan section, [`production/current_state.md`](production/current_state.md) |

Each section is tagged:

- **`BUILT`** — a real implementation exists; the linked doc is the arbiter,
  and the numbers here are the *original intent*, not the values in force.
- **`PARTIAL`** — some of it ships, the rest is design only.
- **`DESIGNED`** — ratified design, nothing built. Do not invent a parallel
  design for these; extend this one or ask the Director to change it.

Where the shipped build knowingly diverges from the design below, §20 records
it. Everything numeric in §20 was read out of the code on 2026-08-06, not
copied from another document.

---

## 1. Identity and model

**Genre:** turn-based tactical stealth with RPG progression — a game with no
ending.
**Platform:** mobile-first (iOS / Android), HTML5 supported. Portrait, camera
follows the agent. **2026-10-10 (Director):** the desktop is a way to play too,
in a landscape window; handsets stay portrait-locked. The HUD is ONE
orientation-neutral mechanism, a 3×3 grid of screen regions in both shapes plus
an interface layer on the board in GU (`INTERFACE_MASTER_PLAN` Part 7).
**Engine:** Godot 4.6, GDScript, isometric 2.5D, dimetric projection (45°
horizontal / 26.57° elevation).
**Pitch:** *"The only turn-based stealth tactics game that works on mobile —
because every decision is yours, not your reflexes."*
**References:** Dishonored (feeling), XCOM 2 (tactical system), Phoenix Point
(adversarial progression), Hitman GO (mobile stealth), Invisible Inc
(information as resource), Diablo (infinite power escalation).

**Central concept — information is the primary resource.** The agent is a
spy; success depends on *knowing* without being known. Fog of war, noise
propagation and enemy unpredictability make every run unique and every action
consequential.

**The game does not end.** The 3-chapter campaign is prehistory — a narrative
tutorial that establishes the lore, justifies the title, and introduces the
mechanics progressively. After it, the agent enters **Freelance mode**:
procedural missions, content packs, community contributions. Enemies scale,
the agent scales, the challenge stays proportional. Design every progression
system to scale, never to cap (§19 Rule 1).

---

## 2. Narrative — `DESIGNED`

### 2.1 The four factions (revised 2026-10-22)

*(Director, 2026-10-21/22: four entities — "Polícia Federal (Uniforme/Autoridade), Milícia Privada (Soldados High Tech), Corporação
(Engravatados/Gangsters), Traficantes (Paramilitares/Bikers)"; each must outlive its leader and be "minimamente uniformizável"; "Tanto faz o nome, o
importante é serem equilibradas".)* Names are working names. All four orbit one company, **GRUB DRILL INC** (§2.6).

| Faction | Uniform / turf | Public face | Truth | Plays as (§11.1) |
|---|---|---|---|---|
| **The Federal Police** (in the game a FICTIONAL federal agency, its ranks localised per country: a real institution never plays the corrupt faction) | Official uniforms and equipment; stations, checkpoints | The law | Paid to look away from the traffickers; its leaks reach the militia; its chief knows the company's containment pit is where the traffickers' enemies are dumped | Information: radios, check-ins, cameras, trail reading |
| **The Militia** — a private military security company | High-tech uniforms and gear; GRUB DRILL's complex across several towns | Security hired by the company's CEO, in exchange for backing his Senate campaign | Takes the traffickers' territory, buys police leaks, bills for security it never delivers | Technology and force: drones, sensors, armour, pairs |
| **The Traffickers** — paramilitaries behind a motorcycle club | Club vests and patches, bikes; chop shops, the refinery's back rooms | A motorcycle club | Divert banned precursors from the company's refinery into synthetic drugs; their dead go into the pit | Numbers and improvisation: bikes, routes, explosives, chemistry |
| **The Corporation** — GRUB DRILL's executives and minority shareholders | Suits **of their own cut, palette and earpieces, never the hero's fedora and coat** (D70: on the board at ~190 px the Agent must not read as one of them) | The company's governance | Sabotage the CEO: against his government contract, they drive the stock down so a foreign fund can take the company over; they finance the traffickers and open the facilities to them, for a scandal; they have their own suited agents | Money and access: bribes, hacking, private agents |
| **The Agent** | His own costume (D70) | A federal investigator, a grieving father | The police leak that sells information to the militia, and the man who breached the dam (§2.6) | — |

**Each faction outlives its leader:** the police are an institution (a new chief, the same cover-ups); the militia is a contract and a territory; the
club is a business with a chapter structure; the Corporation is a fund and a board. **All four are innocent of the attack and guilty of the massacre**
(§2.6); the Agent is guilty of the attack.

**Balance (Director: equivalent as a whole, different in everything else):** each faction owns one axis and has the weakness another exploits; each gets
the same total threat budget, spent differently; balance is MEASURED (completion rate per faction and per route, §2.6), never asserted on paper, and the
weekly war re-targets each faction's objective from that data (`COSMETICS_MASTER_PLAN` §4). ⚠️ §11.1's counters (visor / weapon / armour) were written
for three factions; the fourth needs its own (§18).

**None is the final deception.** The campaign first invites the player to read the four factions' shared guilt as the answer (§2.6, twist 1). That is
the false resolution: the Agent himself is the infiltraitor and the traitor, and has known it throughout (twist 2).

**The name is the narrative:** INFILTRAITOR — the agent is both infiltrator and traitor: the police's own leak, then a guest in each faction's uniform who
betrays it in turn. **He knows what he did while the player does not** (no amnesia, no recurring flashbacks), but **not the whole story** (Director,
2026-10-21: *"Seria melhor que ele precisasse investigar, e fosse descobrindo pelo caminho que a ação dele foi catalisada pelos erros dos demais"*), and
uses the campaign's heroic framing to make the player execute his plan under a false conviction.

### 2.2 Two modes

**Campaign — the prehistory (an opening and two laps around the four factions; revised 2026-10-22).** Linear, curated, and a complete tutorial.
It is the same campaign for free and paying players (§16); payment changes progression speed, never access. Each chapter introduces a faction and its
mechanics. It has a beginning, middle and end — the traitor is exposed here. **The Elite prologue of the earlier canon is superseded:** the game opens at
home (Director, 2026-10-21).

```
OPENING — Home (Director)
  The Agent comes home and pours a drink. The news: a fire at a substation
  failed the dams' containment; a mass collapse floods the town; curfew.
  He is genuinely stunned. His phone, left at home, shows missed calls
  from his wife. It rings: his wife is in intensive care; their son is
  dead. He falls to his knees. Titles.

THE POLICE STATION
  His deposition. Too close to the case, he is barred from it, suspended,
  his badge taken. Outside, a faction approaches him: THE PLAYER CHOOSES
  WHICH. Its uniform is his first disguise: he moves freely on its turf
  first, and earns access to the others as he goes.

LAP 1 — the favours (four chapters, one per faction)
  Leader A shares what he knows only for a favour: investigate leader B.
  B asks for C, C for D, and D points back at A (the circle, §2.6). Each
  favour earns a piece of information and the access (uniform, credentials)
  to the next turf. Each chapter teaches its faction's mechanics; the order
  is the player's, so no chapter may depend on another's.
  Midpoint: his wife dies in intensive care; the baby is delivered by an
  emergency caesarean and survives in the neonatal unit.

LAP 2 — the confrontations
  He returns to A with three new pieces: a mortal confrontation, A's
  confession of its share in the disaster, a clue: "someone did X". Each
  clue leads to the next leader. TWIST 1 (the false resolution) builds:
  the four shares made the massacre. Every clue describes the Agent: he is
  not following leads, he is killing witnesses.

THE LAST LEADER
  In the dialogue the Agent reveals that he planted the bomb, and that he
  lost everything that day (TWIST 2). They fight to the death.

EPILOGUE
  The neonatal unit, the baby in his arms: "I found all of them." The CEO
  is elected on the "accident" version, the foreign fund buys the company,
  the Agent's bet has paid. "There is no right or wrong. There are only
  winners."
  Unlocks: FREELANCE MODE (every week a faction calls; he sells to whoever
  pays: COSMETICS_MASTER_PLAN §4).
```

**Freelance — the endless game.** Missions come from a procedural generator
(LLM-authored narrative, §2.5), content packs and seasonal events, community
contributions, and faction contracts repeated at higher stats (the Diablo
cycle). The agent keeps growing; enemies grow proportionally; the tenth-shot
rule (§9.2) still kills. Tension never disappears.

### 2.3 Narrative delivery

- **Mission briefing** — 2–3 lines before a level. Skippable.
- **Comm-link messages** — speech bubbles on specific tiles/events. Never
  block play.
- **Intel fragments** — optional collectibles that build deeper lore.
- **Victory/defeat screen** — brief narrative outcome + stats + rewards.
- **Dossier** — accumulated intel log between missions, for players who want
  the full narrative.

**The mission interface is an unreliable narrator because the Agent controls
its intelligence.** The player chooses tactics, routes and actions, but the
Agent supplies the strategic objective and the labels through which it is
understood. The player is never given access to his private thoughts. Briefings
may misdirect by omission or technically-true wording; the game may not invent
an off-screen fact at the finale merely to manufacture surprise.

### 2.4 The fair-reveal contract

The final reveal must **reinterpret evidence the player really saw**, not
invalidate the campaign with facts withheld arbitrarily. On a first playthrough
the evidence reads as atmosphere; on a second it reads as confession:

- targets recognise the Agent too early or call him by another codename;
- apparent communication interference suppresses what witnesses are saying;
- files carry dates that contradict the official chronology;
- some "hostiles" flee, protect civilians or guard evidence rather than attack;
- mission language remains technically true while its moral subject is false;
- objectives that appear independent form one visible chain when placed in
  their real order.

The preferred reveal mechanism is the project's own information grammar: an
outside breach or recovered source removes the Agent's filter and relabels
`HOSTILE` as `WITNESS`, `WEAPON CACHE` as `EVIDENCE ARCHIVE`, or `EXTRACTION`
as `ACTIVATION SITE`. **The game has done to the player what the player does to
guards: controlled behaviour by controlling information.** A post-campaign
Truth Mode may expose uncensored briefings, communications and dossiers to
turn the twist into replay value; its exact scope is not yet decided.

### 2.5 LLM mission generation (Freelance, future)

The generator will produce briefings, NPCs with names and motivations,
varied objectives, tier-appropriate rewards, and organically embedded
secrets.

**The architectural premise matters now even though the feature does not:**
structure and content are separate objects. `MissionData` (id,
difficulty_tier, faction, segments, objectives, rewards) is engine-owned and
must work with no narrative attached. `MissionNarrative` (briefing text, NPC
names, dialogue, secret hints) is a pluggable layer on top. **The engine must
never depend on narrative content to resolve game logic** (§19 Rule 2).


### 2.6 The inciting event: the dam — `DESIGNED` (Director, 2026-10-21/22; Claude's proposals marked, those accepted say so)

*(Director, 2026-10-21/22: a federal investigator in debt, his wife pregnant with their second child, the house about to be foreclosed, bets against the
mining company and attacks it, "apostando que o dano seria pequeno", meaning to blame one of the factions in an investigation he expected to lead; the
whole structure comes down, the containment pit fails, the sirens stay silent; his wife and son, driving home early from an event in another town, are
caught near the epicentre; "No fim das contas todos os envolvidos são corruptos, inclusive o agente".)* **Supersedes this section's two earlier versions
(the "controlled breach" and the "unknown client").**

**Fiction, not reportage.** Inspired by the tailings-dam collapses of recent years, never named after them: no real person, company or detail that
identifies a real case, and the dead treated with respect (no spectacle of the mud, no gameplay that makes light of it). **The town is the city the
player chooses as his base** (Director: *"É uma obra de ficção sobre uma tragédia que pode acontecer em qualquer lugar"*); real names and flags appear
only on neutral places (`COSMETICS_MASTER_PLAN` §6); a player who gives no city gets a fictional default. **Backup settings:** an OIL REFINERY or a
HYDROELECTRIC PLANT carries the same plot.

**GRUB DRILL INC** (fictional; a quick web search on 2026-10-21 found no company or mark of that name — a registry search before launch; the only known
"GRUB"s are unrelated: GNU GRUB, Grubhub). A complex of refinery, mining and chemical-agent production across several towns. Its CEO runs for the Senate
and wants an exploration contract with the government; he hired the Militia's company to guard the complex in exchange for campaign support. One of its
sites is the dam.

**The Agent (Director; "he is the leak" is Claude's proposal, accepted 2026-10-22).** Before the disaster he already sold police information to the
Militia (the police's leak is him). His plan: a SMALL spill at a secondary basin far from the town, a bet against the company, and the blame on the
traffickers (a kamikaze drone is their signature) in an investigation he expected to lead. He left his phone at home (the antennas put him there: his
alibi) and launched the drone. **He did not know the four failures below.**

**The bet (Claude, 2026-10-22, answering the Director's question).** **Short-dated PUT OPTIONS bought through a front ("laranja")**, not a short sale: a
man in debt can afford a premium (a short needs margin and can lose without limit), and the leverage makes a small spill pay. **Many bettors hide him:**
the Corporation is openly building a bearish position and has leaked the buried engineering report to the market, so after the disaster the regulator
finds a crowd of puts and goes after the biggest (the Corporation's fund), which feeds twist 1. **His tell is the expiry:** everyone else bet over months;
he bought puts expiring days later, which only someone who knew the date would do (the Corporation's clue in lap 2). Proposed origin of the idea: he sees
the Corporation's bets through police intelligence: if they bet on a fall, he will make the fall, and they will be the suspects. **Not a dark-web
contract paid in bitcoin:** there is no market for it, and bitcoin's public ledger is traceable at the cash-out; if crypto appears at all, it pays for the
drone parts or the front, and then it is one more trail.

**What happened.** The drone struck the substation that powers the pumps and the sirens. **Four failures turned a small spill into a massacre; each
faction is guilty of one and innocent of the attack.** The official version, "a fire at a substation", suits all four, so none wants a real
investigation, and each needs one off the books.

**The family.** His wife and son, driving home early from an event in another town (her missed calls), were caught near the epicentre. The son dies; the
wife dies in intensive care at the campaign's midpoint; the baby survives (Director, 2026-10-22: *"a mãe morre mas o bebê sobrevive no fim"*).

**The circle (Director's structure, 2026-10-22; the table is Claude's, accepted):** each leader trades what he knows for a favour that points at the next:
Police → Militia → Traffickers → Corporation → Police. The pairs outside the circle are extra clues for free (Police and Traffickers: the bribes; Militia
and Corporation: the CEO against the shareholders).

| Faction | Asks for (and points at) | Really hides | Its failure in the disaster | Alibi | Obstacle | Its clue about the trigger (lap 2) |
|---|---|---|---|---|---|---|
| **Police** (the chief) | Investigate a "leak" off the books → the **Militia**, which receives it | The pit as a dump for bodies; the deal with the traffickers | Blocked the pit's inspections: the containment failed | The official "substation fire" version is his, and he runs the case | Cannot use his own men (the leak); fears federal scrutiny | "Someone passed the road block that night on a police credential" |
| **Militia** (the commander of the CEO's security) | Prove it was the traffickers (a drone) → the **Traffickers** | Billed the sirens' backup power and never installed it; takes the traffickers' territory | The sirens stayed silent | Holds the drone's wreck: "proof" of an outside attack | Cannot let any inspector near the siren system | "The drone took off inside our perimeter, with codes only we and our informant knew" |
| **Traffickers** (the club's president) | Find who leaks to the militia; they suspect their financiers → the **Corporation** | The lab in the refinery; their dead in the pit | Chemical waste dumped in the dam: the reservoir over its limit | Lost their lab and men: they look like victims | The bodies may surface with the mud; the bought police no longer protect them | "Someone bought drone parts at our chop shop weeks before" |
| **Corporation** (the minority shareholders' leader) | Prove it was the State's negligence (the chief) → the **Police** | Finances the traffickers; wants the stock down for the foreign fund | Buried the engineers' risk report | The fall "hurts" them in public; no weapons | The market regulator investigates the bets against the company, theirs included | "Someone bet against us through a front, on puts expiring that week" |

**The same clues in every route (Director, 2026-10-21).** The circle is a cycle: the player's choice picks where it starts, the order is a rotation, every
route meets the same four pieces and the same four clues, and the last one always completes the picture: §2.4's fair reveal is written once. Alone, each
clue is ambiguous; together they describe one man. The model is Agatha Christie's *The Murder of Roger Ackroyd* (1926): the narrator is the culprit and
every clue is in plain sight.

**The investigation goes abroad (Director, 2026-10-21):** the attack is a FEDERAL case, so the Agent travels beyond the disaster area (the foreign fund,
the front's offshore broker, the traffickers' routes); the campaign's locations sit on the game's 3D globe, also its mission hub (`COSMETICS_MASTER_PLAN`
§6).

**Open (Director):** whether lap 2's first three confrontations are shorter than the last (the campaign's length); the fictional federal agency's name and
its ranks per country (the Director's draft says "Tenente", a military rank: Brazil's federal police ranks are agente, escrivão, perito, delegado); the
dedication and the partnership (`LAUNCH_MASTER_PLAN` §1).

---

## 3. Turn system — `BUILT`

*Implementation: [`systems/movement.md`](systems/movement.md), `TurnController`.*

### 3.1 Base structure
- Strictly turn-based. The agent gets **2 AP** per turn.
- Each AP buys: move, gadget/skill, attack, interact, or wait.
- After the agent spends AP (or ends the turn manually), all enemies resolve
  their turns **sequentially** — never simultaneously (§19, and it keeps
  replays deterministic).
- Loop: *observe → plan → act → observe consequences.*

### 3.2 Turn order and the walking camera — `DESIGNED`
- Every actor has its own turn; the camera walks to each in order.
- A **portrait panel** in the screen corner shows every active actor in turn
  order. The active one pulses; after acting it goes muted. The panel must
  scale from 2 to 20+ actors (§19 Rule 6).
- **Camera speed is variable, and this is the cheapest drama in the game:**
  routine turn = fast, the player barely notices; alerted guard = slower;
  imminent detection = a dramatic pause before resolving. Implemented as a
  tween-duration variable — zero cost, large impact.

### 3.3 The TIC system — event-driven on edge change
- Detection and noise are **event-driven, never per-frame loops**.
- A "tic" fires **whenever any actor crosses an edge** from one tile to
  another. Crossing checks: exposure of the destination tile in every active
  guard cone, chance of noise generated by the movement, trail and overlay
  updates.
- **Guards moving also fire tics** — their cone moves and can reveal an agent
  who was safe a moment ago.
- Two payoffs: **determinism** (the player can always reconstruct why they
  were detected) and **mobile performance** (no per-frame AI).

### 3.4 Overwatch and the reaction window — `DESIGNED`
- Ending a turn with unspent AP via *Wait* puts the agent in **Overwatch**: a
  threat entering vision during the enemy turn triggers a pre-selected
  automatic reaction.
- **Detection reaction window:** on being detected during the enemy turn, the
  game pauses briefly and offers an emergency menu — use gadget, use skill, or
  accept the alert-meter increase.

---

## 4. Detection — `BUILT`

*Implementation: [`systems/perception.md`](systems/perception.md),
[`systems/stealth.md`](systems/stealth.md),
[`systems/AI_MASTER_PLAN.md`](systems/AI_MASTER_PLAN.md). Shipped tuning
differs — see §20.*

### 4.1 The tile cone
Each guard faces one of **8 directions**. The cone is a **tile mask with
fixed probabilities**, rotated/mirrored per direction — cardinals and
diagonals share one probability set. Cardinal cones open ~90°; diagonals use
the same mask rotated 45°.

| Distance | Base probability | Relaxed state |
|---|---|---|
| Tile 1 (adjacent) | 100% | 60% |
| Tile 2 | 95% | ~55% |
| Tile 3 | 85% | ~45% |
| Tile 4 | 60% | ~30% |
| Tile 5 | 40% | ~20% |
| Tile 6 | 15% | ~8% |
| Tile 7 | 5% | ~2% |
| Tile 8 | 1% | ~0% |

Lateral columns fall off rather than cutting hard: column ±1 runs 40% → 15% →
5% with distance; column ±2 is 5% near, 1% far. **Slipping past a guard's
flank is a real risk, just a smaller one.**

### 4.2 Cone by guard state
- **Relaxed / patrolling** — reduced cone (the "relaxed" column above);
  skills and equipment can reduce it further.
- **Tense / alert** — normal cone.
- **Searching / chasing** — probabilities triple; the cone may expand to
  omnidirectional.
- **Omnidirectional** — a guard standing still at maximum alert perceives in
  every direction, in a symmetric diamond. **No safe side.**

### 4.3 Shadow as a tile multiplier
Walls cast shadows geometrically from the level's real light sources. Every
tile carries a lighting state that modifies cone probability:

| Tile | State | Effect |
|---|---|---|
| Dark (deep shadow) | Total cover | Probability ÷ 2 |
| Half-shadow | Partial cover | Probability × 0.75 |
| Normally lit | No cover | Unchanged |
| Over-lit | Exposed | Probability × 1.5 |

**At least 1/4 of every room has a guaranteed shadow trail** (exterior walls
always block some light) — there is always a stealth path, even in the
hardest room. **The visually darkest tile is the mechanically safest tile**:
learnable by instinct, never by tooltip.

### 4.4 Light as level design
Light placement defines the shadow zones, so **light is level design**.

- **Agent-manipulable:** kill a lamp (1 AP, makes noise) for permanent shadow
  in that segment; hack an electrical panel to darken a whole room, possibly
  tripping an alarm; throw an object at a bulb (silent, costs an item).
- **Dynamic lights:** a rotating spotlight whose moving shadow creates a
  *calculable* passage window; a blinking emergency light that alternates risk
  per turn; a red alarm light that **erases every protective shadow in the
  room**.

### 4.5 The cumulative detection meter
Detection accumulates across turns; it is never binary. Leaving the cone
starts a decay whose rate depends on guard state — relaxed decays fast,
chasing barely decays at all. **At 100% the agent is discovered and the
confrontation phase begins.**

The accumulation curve is **sigmoid**: below 40% detection is hard to build,
40–70% climbs fast, above 70% any further sighting closes it out. This is
what produces "I *just* got away with that".

### 4.6 The cone is vector, never a sprite — `DECIDED`
Probabilities change with guard state, so the cone changes colour
dynamically; 8 directions × several states would be 32+ sprites of pointless
art cost; and the event-driven system keeps it cheap on mobile.

| Probability | Colour | Alpha |
|---|---|---|
| 100% | Red `#FF2020` | 0.85 |
| 85–95% | Orange `#FF6600` | 0.75 |
| 60% | Amber `#FFA000` | 0.65 |
| 40% | Yellow `#FFD000` | 0.55 |
| 15% | Yellow-green `#C8E000` | 0.45 |
| 5% | Light green `#80D000` | 0.35 |
| 1% | Green `#40C000` | 0.25 |

### 4.7 Evidence detection — the cone reads trails — `DESIGNED`
The cone does not only detect a living agent standing on a tile. It detects
**evidence**: noise and movement trails with residual intensity.

```
On each edge-crossing tic, the system checks:
  1. Is the agent on the tile?      → roll normal detection
  2. Does the tile hold a noise trail?    → roll detection × trail intensity
  3. Does the tile hold a movement trail? → roll detection × trail opacity

Guards follow trails the way the snake follows the apple:
  cone touches evidence at tile X
  → guard goes SUSPICIOUS, moves to X
  → at X, the cone sweeps for fresh evidence
  → chains onward until the trail dies or the agent is found
```

Managing your own trail — standing still, using abilities that erase evidence
— is real gameplay. **The agent can have left a position and still be
tracked.**

**Evidence the liquids leave (`DESIGNED`; M6, Director 2026-10-17/18; built on the engine side, read by no guard yet).** A liquid leaves
footprints (up to eight, fading, `gameplay.footprint`); biohazard STAINS the agent for 5 turns; a nuclear dose makes the agent GLOW (a small
tactical light: it already counts in the exposure); a splash raises noise and some liquids carry a smell. Ruled for the AI milestone: a guard
near a print may notice it (the liquid's contrast and smell, distance, the guard's perception, the light, the print's age), goes SUSPICIOUS and
follows the trail — the same chain as above. The stain and the glow are what a guard who sees the agent reads. Planned in `AI_MASTER_PLAN`
("Planned from the liquids").

---

## 5. Noise — `BUILT`

*Implementation: [`systems/noise.md`](systems/noise.md).*

### 5.1 Generation per tic
Each tic gives the agent a chance to generate **silence / small / medium /
loud** noise, weighted by destination terrain and the action taken.

- Standing still: 0%.
- Walking: low chance, 1-tile amplitude.
- Running (2 tiles on 1 AP): high chance, 2-tile amplitude.
- **Inside a guard's 1-AP zone the chance doubles.**

### 5.2 Noise icons and persistent trails
Every noise leaves a **visible icon on the tile where it was produced** — a
running visual log of the player's mistakes accumulating. Intensity degrades
per turn: a three-turn-old noise is weaker evidence.

The icon is not decoration; it is grid data. Each tile stores
`noise_intensity: float` (0.0–1.0) and `noise_age: int`. Intensity decays each
turn to zero. **Guard cones read `noise_intensity` as well as agent presence**
(§4.7), which is what makes tracking-after-the-fact possible.

### 5.3 Propagation
Noise uses the **same propagation system** as the guard whistle and the
alarm. Walls attenuate — amplitude drops by 1 per wall crossed. Guards in
range react according to their current state.

Reference amplitudes: agent walking 1 AP · agent running 2 AP · guard whistle
2 AP (deliberately equal to a run) · radio open mic 3 AP (it leaks) · alarm
panel = whole scene · body falling 1 AP · breaking glass 2 AP.

---

## 6. Organic patrol — `PARTIAL`

**Guards are not robots.** Speed, attention and behaviour vary by state.

| State | Movement | Idle behaviour | Detection mult |
|---|---|---|---|
| **Relaxed** | May spend only 1 of 2 AP | ~20% chance of a 1–2 turn pause; ~30% chance to rotate facing without moving; ~15% chance of a ±1 tile detour | 0.6× |
| **Suspicious** | Normal, both AP | No random pauses; rotates facing ~60% per turn | 1.8× |
| **Alert** | Normal, no detours | — | 2.2× |
| **Chasing** | Direct A*, maximum speed | — | 3.0× |

Speed is a per-turn `patrol_ap_budget` (relaxed returns 1 about 30% of the
time, every other state returns 2). The movement tween duration scales with
state too — relaxed reads slow, chase reads fast. **The visible tempo of a
guard is the player's cheapest read on its state.**

---

## 7. Trails and prediction — `PARTIAL`

- **Agent trail (yellow)** — the last N tiles walked, opacity dropping 20%
  per tile. **Ordinary enemies cannot see it** — that would be far too hard,
  far too early. **Elite enemies can**, and predict from it.
- **Guard route prediction (blue)** — the guard's next N tiles, same opacity
  falloff, unlocked by agent progression.
- **The elite inversion** — the elite enemy does not merely read the trail;
  it predicts **through the shadow zones**. Its prediction points where the
  shadows lead, not where the agent is. This forces the agent out into lit
  tiles. Shadow is refuge against ordinary guards and a trap against the
  elite — a genuine dilemma, from one inverted rule.

### 7.1 Information as the progression reward

| Agent level | Information available |
|---|---|
| Recruit | The map only. No overlays. Learns the hard way. |
| Operative | Guard detection cones visible, colour-coded. |
| Agent | Yellow trail of the last 3 tiles. |
| Specialist | Blue prediction of guards' next 3 tiles. |
| Veteran | Full trail (5) + full prediction (5). |
| Elite | All of the above + which guard acts next, in the portrait panel. |

The cone's own visual fidelity ladders the same way: monochrome shape →
3 colour zones → all 7 probability zones → percentages in text.

**The UI is the progression reward. The map stays exactly as dangerous — the
agent simply comes to understand what was always happening.**

---

## 8. Confrontation — `DESIGNED`

Nothing here is built. Combat is at 0%.

### 8.1 Stealth → confrontation
At 100% detection the camera pushes in on the guard's face, holds a dramatic
beat, and the music changes. **The transition is a clearly marked moment —
the player knows the game just changed.** A smoke bomb can reverse it (§8.5).

### 8.2 The four cover states

| State | Visual | Hit taken | Damage taken | Own aim |
|---|---|---|---|---|
| **No cover** | Standing, exposed | 100% | 100% | 100% |
| **Minimal** | Prone on the floor | 70% | 70% | 50% |
| **Half** | Crouched behind a low object | 50% | 50% | 75% |
| **Full** | Behind a wall or pillar | 25% | 25% | 100% |

Transitions: improving cover costs 1 AP and exposes you briefly in transit.
Dropping to minimal cover is free but you may do nothing else that turn except
shoot at 50% aim. **Getting up out of prone costs 1 AP and pins you for at
least a turn** — going prone is a commitment, not a dodge.

### 8.3 Peek, from full cover
Shooting from full cover requires momentarily leaving it. During the peek,
incoming hit chance rises to ~60% while own aim stays 100%. Guards on
overwatch can wait for the peek — **a duel of patience**.

### 8.4 Flanking
Full flanking (enemy perpendicular to the cover) degrades cover by one level.
Partial flanking (diagonal) cuts the protection multiplier by 15%. **Minimal
cover is immune** — prone has no weak side — but changing aim direction while
prone costs 1 AP. A downed guard's body works as minimal cover: tactically
useful and narratively coherent.

### 8.5 The smoke bomb as the pivot
In confrontation, smoke does more than block line of sight: it **partially
resets detection state**. Guards lose the confirmed position and fall back to
searching from the tile where the smoke landed, opening a 2–3 turn window to
reposition. **This is the mechanism that lets a good player slide back out of
combat into stealth** — without it, one mistake would be terminal, which the
Persistent Threat pillar wants, and the Player Agency pillar does not.

### 8.6 Combat resolution per tic
```
Attack tic:
  1. Hit die:  base chance − target cover + attacker precision
  2. On hit:   damage die (range by weapon/skill)
  3. Damage resolves against the target's resistance layers
  4. On miss:  visual feedback (round in the floor, spark on the wall)
```

**Step 4 is no longer only feedback.** Everything a miss does to the scenario is
built and shipped — the round travels the origin→target line to the wall behind
and breaks real voxels there, with material-specific response, bullet marks and
face-local soot. `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` §5b owns that half in
full; this section stays the gameplay statement of it.

### 8.7 Target selection — aim mode — `DESIGNED` *(Director, 2026-08-13)*

**The reference is Fallout 3 / XCOM: you pick a target from a short list, read
its hit chance, and commit.** There is no free aim and no reticle — the player
chooses *who*, never *where*. What moves the odds is cover (§8.2), flanking
(§8.4), shadow (§4.3) and the agent's own stats; the environment does the aiming.

```
enter aim mode  ->  nearest enemy auto-targeted, hit % shown
                    cycle through EVERY valid target, % updates
                    confirm on the SAME target  ->  the dice roll
```

**The target list is not capped.** Two or three targets is the common case, not
a limit — six visible enemies means six cyclable targets, and that situation is
rare mostly because a segment does not hold many enemies (special maps aside).
Cycling is therefore a real list traversal, never a fixed set of slots.

Confirmation is deliberately a **second** input on an already-chosen target —
choosing and firing are two separate acts. That separation is what gives the
engine a window to pre-compute the shot, which is the difference between a shot
that fires instantly and one that stalls the frame it is fired on.

**Deliberately not decided here, Director's own:** *"Vamos definir isso melhor
depois em COMBATE."* The hit-chance formula, AP cost, which enemies qualify as
targets at all, ammunition, and how a shotgun's many independent pellets collapse
into one displayed percentage all belong to the COMBAT wave. They are enumerated
as open questions in `WEAPON_MASTER_PLAN.md` §7c.

**What the agent is holding while he aims:** the whole arsenal, not one weapon —
§10.2's per-mission pick is superseded, see the note there.

**Interaction and pre-computation detail:** `WEAPON_MASTER_PLAN.md` §5c and
D31–D36. The grenade's equivalent flow is already built and is the model to read
against — `PROMPTS/DONE/TARGETING_MASTER_PLAN.md`.

---

## 9. Agent resistance — `DESIGNED`

### 9.1 Three layers
| Layer | Start | Campaign max | Notes |
|---|---|---|---|
| **HP** | 3 | 5 | Scales with tier in Freelance |
| **Armour** | 0 | 3 | Absorbs before HP; **degrades 1 point per hit taken** |
| **Reserved** | — | 1 | Held for a late-game mechanic |
| **Total** | | **9** | |

### 9.2 The ceiling of 9 and the tenth-shot rule
The maximum sum of all layers in the campaign is **9 points**, and **the
tenth hit is always fatal** — it skips armour, skips every protection, and
resolves as a lethal critical. It gets special treatment: slow motion, a
different sound, a distinct death animation.

**In Freelance the number moves but the rule does not.** If a tier-5 agent
survives 27 hits, the 28th is still always fatal. *The tenth shot is a
metaphor, not a number — it is always one hit past the ceiling* (§19 Rule 4).

**Why it exists:** to make open combat lose by default. However much HP the
veteran accumulates, shooting everyone eventually kills him. It is also a
readability device — the player counts shots, and a badly damaged agent reads
visually.

### 9.3 Damage die
| Roll | Damage | Reading |
|---|---|---|
| Low | 1 | Grazed |
| Medium | 2 | Direct hit |
| High | 3 | Critical |
| Tenth shot | Fatal | Ignores everything |

---

## 10. Equipment — three classes — `DESIGNED`

**The agent picks one item from each class before a mission, plus at most 2
consumable gadgets.** Three loadout decisions: simple to teach, deep to
master. Gadgets are found on the map, bought from NPCs, or awarded.

### 10.1 Class 1 — Armour
*Narrative progression: discreet spy → armoured threat. **More protection
always costs mobility or stealth.***

| Tier | Item | Bonus HP | Armour | Stealth penalty |
|---|---|---|---|---|
| 1 | Civilian clothes | 0 | 0 | Perfect disguise |
| 2 | Tactical clothing | 0 | 1 | Slight noise when running |
| 3 | Ballistic vest | 1 | 2 | Noise cone +1 |
| 4 | Modular armour | 2 | 3 | Movement +0.5 AP |
| 5 | Light exoskeleton | 3 | 3 | None (powered) |
| 6 | Full plating | 3 | 4 | Minimal cover impossible |
| 7 | Adaptive skin | 2 | 2 | Shadow multiplier ×2 |

### 10.2 Class 2 — Weapon

> **🔄 The one-weapon-per-mission rule is SUPERSEDED as a live constraint
> (Director, 2026-08-13).** *"Vamos ter mais armas disponíveis, desde granadas
> até dardos tranquilizantes. Podemos ter mais decisões relacionadas ao modelo
> de gameplay restringindo o acesso a tudo de uma vez, mas por enquanto deixa
> liberado."*
>
> The agent carries the **whole arsenal** — firearms, explosives, and the
> non-destructive tier — and selects between them in play (aim mode, §8.7).
> **The table below stands as the weapon catalog and its tier progression**;
> what no longer binds is §10's framing of Class 2 as a single pre-mission pick.
>
> **Restricting access is still on the table as a design lever, and is
> undecided** — so nothing should be built that assumes either an open set or a
> restricted one is permanent. What *is* settled: any weapon-selection UI has to
> survive the carried set growing, so it cannot be N fixed slots.
> Register entry: `WEAPON_MASTER_PLAN.md` D37.

| Tier | Weapon | Damage | Noise | Range |
|---|---|---|---|---|
| 1 | Fist | 1 | None | Adjacent |
| 1 | Knife | 2 | Minimal | Adjacent |
| 2 | Suppressed pistol | 1–2 | Low | 6 tiles |
| 2 | Shock weapon | Stuns 2 turns | Low | Adjacent |
| 3 | Suppressed rifle | 2–3 | Medium | 12 tiles |
| 3 | Dart launcher | Knockout (sedative) | None | 6 tiles |
| 4 | Laser weapon | 3–4 | High | 15 tiles |
| 5 | Plasma weapon | 4–5 | High | 10 tiles |
| 6 | Sonic weapon | Stuns 3×3 area | Very high | 5 tiles |

### 10.3 Class 3 — Visor
*Each visor fundamentally changes how the player reads the map.*

| Tier | Visor | Reveals | Limitation |
|---|---|---|---|
| 1 | Normal vision | Standard cone | No overlay |
| 2 | Night vision | Dark tiles | Blinded on lit tiles |
| 2 | Tactical binoculars | Guard cones at range | Static |
| 3 | Thermal | Guards through thin walls | Cannot tell friend from foe |
| 3 | Motion vision | Any actor that moved last turn | Blind to the static |
| 4 | X-ray | Through walls and objects | Battery — 3 turns per charge |
| 4 | WiFi vision | Cameras, sensors, radios | Electronics only |
| 5 | Tactical analysis | Detection probability per tile | Only while standing still |
| 5 | Predictive | Guard route prediction | Imprecise against elites |
| 6 | Spectral | Thermal + X-ray + WiFi + analysis | Heavy, +noise |

### 10.4 Gadgets (consumable, max 2)
| Tier | Gadget | Effect | Uses |
|---|---|---|---|
| 1 | Motion detector | Movement on an adjacent unseen tile | Passive |
| 1 | Noise detector | Surrounding noise intensity | Passive |
| 2 | Smoke bomb | Blocks LOS 3×3 for 3 turns | 3 |
| 2 | Flashbang | Blinds an area for 1 turn | 2 |
| 2 | Gas bomb | Knocks out anything breathing, 2 turns | 2 |
| 3 | EMP bomb | Disables room electronics, 3 turns | 2 |
| 3 | Incendiary | Tile impassable for 4 turns | 2 |
| 3 | Explosive | Area damage, destroys cover | 1 |
| 4 | Recon drone | Flies 5 tiles revealing area | 1/mission |
| 4 | Sound lure | Creates noise on a distant tile | 3 |
| 5 | Camera loop | Camera shows a false feed, 3 turns | 2 |
| 5 | Radio scrambler | Blocks communication in a room | 1/mission |
| 6 | Shadow generator | Artificial shadow tile, 3 turns | 2 |

---

## 11. Enemies — `PARTIAL`

One guard archetype ships. Everything below the hierarchy is design only.

### 11.1 Three factions
> **2026-10-22:** the enemy factions are the FOUR of §2.1: the Federal Police (a fictional agency), the Militia (a private military security company),
> the Traffickers (a motorcycle club) and the Corporation (GRUB DRILL's executives). The three play styles below were written for the older roster; the
> mapping and the fourth faction's counter are open (§18).

**The Agency — control through information.** Guards with radios and check-in
protocols, AI cameras, motion sensors, lieutenants who read trails and predict
routes, jammers that scramble visor readings. *Natural counter: the agent's
visor.*

**The Militia — brute force and intimidating presence.** Heavy armour, high
HP, **patrols always in pairs, never alone**, little technology but excellent
cover and positioning, specialists in coordinated flanking. *Natural counter:
the agent's weapon.*

**The Corporation — technological efficiency.** Autonomous drones, lasers,
fixed-pattern cameras. Predictable behaviour but fast recovery, vulnerable to
EMP and hacking, precision weapons that ignore armour. *Natural counter: the
agent's armour.*

### 11.2 Guard hierarchy
| Rank | Capability | Threatens |
|---|---|---|
| **Recruit** | Basic cone, normal hearing, no radio | The careless agent |
| **Standard** | Normal cone, patrol route, whistle | Whoever underestimates the flank |
| **Veteran** | Wider cone, peripheral sweeps, partial trail reading | Whoever repeats predictable routes |
| **Lieutenant** | Radio (exact position to everyone), full trail reading, shadow-based route prediction, check-in protocol | Whoever doesn't cut communications first |
| **Captain** | Everything above + immune to smoke, sees through disguises, coordinates subordinate positioning, changes routes on suspicion | Whoever relies on a single trick |
| **Rival Agent** (boss) | A complete mirror of the player: gadgets, cover changes, retreats and regroups, has HP and armour, heals between encounters | Whoever doesn't adapt |

### 11.3 The five point/counterpoint techniques
Every agent power gets an enemy mirror (the Phoenix Point lesson):

| # | Agent power | Enemy counter | Introduced by |
|---|---|---|---|
| 1 | Thermal vision | Thermal insulation suit | Agency, ch. 3 |
| 2 | Suppressed pistol | Suppressor detector | Militia, ch. 2 |
| 3 | Sedative dart | Injectable antidote / respirator | Corporation, ch. 4 |
| 4 | Radio scrambler | Alternate frequency / analogue comms | Agency + Militia |
| 5 | Full cover | Two-guard coordinated flanking | Militia |

### 11.4 Telegraphing — the fairness rule
```
Chapter N:   the agent unlocks the smoke bomb
Chapter N+1: guards with a visible MASK appear in sprites — seen, not fought
Chapter N+2: first real encounter with a masked guard — already understood
```
**The player is never surprised by a mechanic they have never seen.** Hard,
never unfair.

---

## 12. Guard AI depth — `PARTIAL`

*Built portion: [`systems/AI_MASTER_PLAN.md`](systems/AI_MASTER_PLAN.md) is
the arbiter. The layered model below is design only — see §20.*

### 12.1 Three independent state layers
1. **Physical status** — `ALIVE / UNCONSCIOUS / STUNNED / DEAD` (later:
   poisoned, burning, injured, frozen). **Layer 1 suspends layer 3 entirely**
   — a stunned guard does not process its FSM at all.
2. **Loyalty** — `NORMAL / BRIBED / CONTROLLED / CONVERTED / ALLY`. Modifies
   detection gain: a bribed guard has gain 0 toward the agent but still
   processes every other stimulus normally.
3. **Operational state** — the FSM proper: `RELAXED, PATROLLING, TENSE,
   ALERT, SEARCHING, CHASING, REPOSITIONING, ATTACKING, FLEEING,
   CALLING_ALARM`.

### 12.2 GuardKnowledge — distributed information, no blackboard
**Each guard owns its own knowledge object. There is no global blackboard.**
Information moves only through explicit communication events. *This is what
makes information warfare a mechanic rather than a theme* (§19 Rule 5, and
the Information Asymmetry pillar).

Each object carries `last_known_tile`, a broader `last_known_area` (used when
the guard only *heard* something), `knowledge_age`, a `confidence` of
`NONE / INFERRED / HEARD / SEEN`, and the `source_guard_id` that told it.

- **Merge only upgrades confidence, never downgrades it** — being told
  something vague cannot erase what you saw.
- **Confidence decays with age:** SEEN → HEARD after 3 turns without update,
  HEARD → INFERRED after 5 more.

### 12.3 Dual-cone FOV
- **Primary** — frontal, `fov_degrees` (default 90°), 8 tiles, the §4.1
  distance curve.
- **Peripheral** — 180°, only 2 tiles, base chance 0.08, and it **triggers
  only if the agent moved on their last turn**. Movement in the corner of the
  eye, nothing else.

### 12.4 Sweep pattern for SEARCHING
A searching guard reaching `last_known_tile` runs a **deterministic clockwise
spiral** (centre, N, NE, E, SE, S, SW, W, NW; 1-tile radius, then 2), pathing
to each point and skipping impassable tiles — **never a random wander**.
Spotting the agent mid-sweep transitions straight to CHASING. Determinism
here is what lets the player learn to predict a search.

### 12.5 Unactivated guards
A guard that has never been activated is **not shown to the player** — the
camera does not follow it. It emits a FOOTSTEP noise event (amplitude 1) with
10% chance per turn, rendered as a **sound wave pointing toward the source**,
visible from the agent's position if in range. **The player infers where an
unseen guard is without being shown it.** Such a guard still perceives
normally; crossing detection 0.3 reveals it and puts it in TENSE.

### 12.6 Delayed activation — the 1-turn reaction window
When a guard first becomes aware (detection crosses 0.3, or it receives a
noise report), **its state change is queued with a 1-turn delay**. This gives
the agent a reaction window and prevents instantly punishing transitions.

### 12.7 Guard profiles
Guard types are a `GuardProfile` resource, never subclasses: `fov_degrees`,
`peripheral_fov`, `detection_gain_multiplier`, `decay_rate_multiplier`,
`patrol_speed`, `max_search_turns`, `has_radio`, `will_flee_to_alarm`,
`will_whistle`, `courage_threshold`.

| Profile | FOV | Gain | Decay | Radio | Notes |
|---|---|---|---|---|---|
| Rookie | 70° | 0.7× | 1.5× | No | Early levels |
| Standard | 90° | 1.0× | 1.0× | No | Default |
| Veteran | 110° | 1.3× | 0.7× | No | Harder levels |
| Commander | 90° | 1.2× | 0.8× | Yes | Broadcasts on detection |
| Civilian | 60° | 0.5× | 2.0× | No | Flees immediately, trips the alarm |

---

## 13. Enemy communication — `PARTIAL`

*Whistle and radio ship as signals; the alarm panel does not.*

**Whistle (local)** — range 2 AP in tiles, attenuated by walls. The hearer
gains the agent's approximate position. 2-turn cooldown per guard. Visual: a
directional sound wave pointing at the agent.

**Radio (global, Lieutenant and above)** — transmits the agent's *exact*
position to every radio-carrying guard, no distance limit. **The radio emits
audible noise before transmitting, giving the agent one turn to react.**
3-turn cooldown. Automatic check-in every 5 turns; a guard who does not answer
gets investigated.

**Wall alarm** — an interactable object in the scene. A fleeing guard paths to
the nearest panel; activating costs a full turn (1 AP move + 1 AP action),
**so the agent can intercept and take the guard down before it resolves**.
Activation pushes every guard in the scene to maximum alert. The agent can
disable panels pre-emptively (1 AP, adjacent).

---

## 14. Map and mission structure — `PARTIAL`

### 14.1 Segment structure (locked)
- Map: a **3×3 grid of 18×36 tile segments**.
- Playable interior: 7×25 tiles per segment.
- Access points: 1 main + 1 secondary (locked) + 1 secret per active edge.
- **Full AP reset on entering a new segment.**
- A 2-tile safe zone on the entry edge, guaranteed encounter-free.

### 14.2 Mission structure
Each mission is a floor with an entrance, objectives and an exit. **Every room
carries at least one of:** enemy encounter, stealth puzzle, objective, reward
cache, traversal restriction, narrative event.

Objectives: reach a terminal · neutralise a guard · pass undetected · recover
an item · escort or rescue · sabotage a system · survive an ambush.

### 14.3 The MVP — three focused chapters
> ⚠️ **2026-10-22: written for the older three-faction, three-chapter campaign.** The campaign is now four factions in two laps, in an order the
> player picks (§2.2, §2.6), so each faction's chapter must teach its mechanic without depending on the others'. The kit / enemy / lesson ladder below
> is still the intent per faction; its re-mapping to four factions is open (§18).

| Chapter | Setting | Agent kit | Enemies | Mechanic taught | Lesson |
|---|---|---|---|---|---|
| **1 — The Agency** | Corporate HQ | Civilian clothes, knife, normal vision, 1 gadget | Recruit, radio guard, simple camera | Vision cones + shadows | Understand detection |
| **2 — The Militia** | Industrial site | Light vest, suppressed pistol, binoculars, 2 gadgets | Armoured guard, paired patrol, lieutenant | Noise + cover | Silence has a cost; confrontation has rules |
| **3 — The Corporation** | Laboratory | Modular armour, shock weapon, night vision, 2 gadgets | Drone, AI camera, high-tech guard | Electronics + automation | No solution is universal |

---

## 15. Progression — `DESIGNED`

**The Elite prologue previews the destination before progression begins.** Its
armour, exceptional powers and senior information overlays are a temporary
narrative loadout, not inventory the player earned and then lost. After the
prologue, the Agent starts from zero and every demonstrated capability becomes
a long-term progression promise. The mature powers must expand tactical
possibility rather than turn the final game into a solved map.

**Item sources:** chests on the map, NPC vendors, mission rewards, and
[future] a TF2-style player market.

**The Informant — a guaranteed NPC.** A map may contain a Network contact
embedded in the location. Reaching their tile (1 AP) **before being detected**
buys exactly one piece of intel: the primary objective's exact position, one
specific guard's patrol route (overlay, 5 turns), or the nearest secret
passage.

**Deliberately impossible rooms.** Some rooms are visually accessible and
mechanically impossible without a specific skill — a radio guard in a room
with no cover at all cannot be handled without signal interference. **The map
shows these clearly, tempting the player and punishing the unprepared.**
Veterans recognise and route around them; beginners learn through pain.

**Infinite escalation (the Diablo cycle).** Each cycle: enemies gain HP,
damage and detection; the agent can equip higher tiers; new enemy types
appear; generated maps grow larger; contracts pay more. The tenth-shot rule
holds, proportional to the new ceiling.

---

## 16. Monetisation — `DESIGNED`

**Company identity: user-friendly before money-friendly.** The free/offline
game must be enjoyable because of challenge and difficulty, not because an
artificial barrier is sold back to the player. Revenue may accelerate progress,
extend a failed run or sell expression. It may not make content permanently
unavailable to a non-payer, fabricate urgency, punish a missed streak, sell
random rewards to an all-ages audience, or make an online service necessary to
enjoy the core game.

**Access model — free-to-play, not a premium campaign.** The same curated
campaign and Freelance mode are eventually available to every player. There is
no premium campaign in the initial model. Paying players skip some progression
steps and reach senior powers sooner; free players can acquire the same things
through play. The early/shareware portion is deliberately generous enough that
the progression difference is barely felt while the player learns the game.

| Type | Ratified implementation |
|---|---|
| Permanent progression boost | A low-priced permanent **2× multiplier on every currency captured during gameplay**. The 1× player can earn the same purchases in twice the play; the economy is designed around that transparent proportion. Exact prices and pacing require real progression data. |
| Continue | Initially **one** explicitly optional rewarded ad after mission death. It exists only after conventional options are exhausted and lets the player play a little longer; number of continues and exact restore point remain tunable. |
| Offline death | Normal defeat animation and reload wait. The loss carries consequence without requiring connectivity or payment. Exact duration is presentation tuning, not an economy gate. |
| Advertising boundary | Ads are wanted, but no automatic pre-level/post-level interstitial placement is ratified. An ad is a voluntary extra option, not the price of entering ordinary play. |
| Cosmetics | A modest initial catalog of shop-exclusive agent cosmetics. Cosmetics express identity/state but never confer the state (`ACTOR_MASTER_PLAN` D36). |
| Random rewards | **No purchased loot boxes** in the all-ages product. The status of play-earned random reward boxes is separate and not yet decided. |
| FOMO boundary | No punitive streaks, artificial energy, expiring paid passes, fabricated urgency or content removed merely to force a purchase. |
| Social surface | Players may eventually meet and talk in a lobby while missions remain short and individual. The communication model is deliberately unresolved pending safety, moderation, parental-control and operational research. No PvP is planned initially. |

**This is paid acceleration, not a claim of zero paid advantage.** A paying
player reaches powers earlier; a non-paying player reaches the same powers
later. With no PvP initially, the boost advances one player's own campaign
rather than defeating another player. Future competitive surfaces must revisit
that premise explicitly instead of inheriting it by accident.

**The endless model remains the revenue model.** Players who reach Freelance
are retained players whose value grows over time, but recurring monetisation
must be earned by a healthy game before stores, seasons or markets are layered
onto it.

---

## 17. Art direction

**Current phase — placeholder.** Coloured shapes on the grid: agent = green
diamond, guard = red diamond, camera = orange triangle. *(Superseded in
practice by the voxel render system — see
[`technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`](technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md)
and [`../ASSETS/ART_SPECIFICATIONS.md`](../ASSETS/ART_SPECIFICATIONS.md),
which own art authoring today.)*

**Final phase — pre-rendered 3D.** Assets modelled in Blender, rendered to 2D
sprite sheets: directional sprites (N/S/E/W) and animation frames (idle, walk,
action). **A purely visual swap — TileMap and game logic do not change.**

**Content extensibility (Director, 2026-09-30).** Objects the world is made of are **models that fill slots** (a footprint, a size box, material zones, a budget; gameplay belongs to the slot, never the model). A player may drop in their own model for a slot (a car, a bed): it is **local and cosmetic** (seen only by its player, on their device), several models of one slot can be on screen at once, and a model that does not fit simply becomes the slot's **generic**. Colour and texture come from the game's own material library, so every model shares one palette. A prop's material decides how it breaks and burns. Builds: [`PROP_PIPELINE_PLAN`](../PROMPTS/PLANNING/PROP_PIPELINE_PLAN.md), [`PROPS_TIER4_PLAN`](../PROMPTS/PLANNING/PROPS_TIER4_PLAN.md).

**Palette and visual language.** Dark, restrained backgrounds (concrete,
steel) with high-contrast colour reserved for the agent and threats.
Isometric 2.5D dimetric, portrait. **Minimal UI:** alert meter (top), AP
indicator (top), contextual menu (tap), portrait panel (side). *(2026-10-10: the
positions become regions of the 3×3 grid — controls where the thumbs are,
indicators in the others; `INTERFACE_MASTER_PLAN` Part 7.)*

---

## 18. Open design decisions

**Decided:**
- ✅ **Vision cone: asset or vector?** → **Always vector.** Dynamic per state,
  no art cost.
- ✅ **Does the agent die in one shot, or have HP?** → **3 base HP,
  proportional ceiling per tier, and the tenth shot (relative to the ceiling)
  is always fatal.**
- ✅ **Procedural generation: fixed per chapter or adaptive?** → **Fixed per
  chapter in the campaign, escalation cycles in Freelance.**
- ✅ **Items: found or bought?** → **Both** — chests, NPCs, mission rewards.
- ✅ **Does the game end?** → **No.** The 3-chapter campaign is prehistory;
  Freelance is infinite.
- ✅ **Who knows the Agent is the villain?** → **The Agent knows his own act
  from the beginning (not who hired him, nor the others' shares); the player
  does not.** He performs the hero throughout the
  campaign and is exposed at the finale (§2.4).
- ✅ **The Agent's moral boundary** → **for money (a bet against the company)
  he attacked a dam meaning a small spill, not knowing it would kill**; with
  the four factions' failures it killed hundreds, his son among them, and his
  wife later (Director, 2026-10-21/22; §2.6).
- ✅ **The inciting event and the factions** → four factions around GRUB
  DRILL INC, each guilty of one failure that turned the Agent's small attack
  into a massacre and innocent of the attack itself; the player picks the
  recruiting faction at the police station; two laps around a circle of
  favours (Director, 2026-10-22; §2.1, §2.2, §2.6).
- ✅ **Premium campaign or shared campaign?** → **Shared.** Free and paying
  players can reach the same campaign, Freelance content and powers; payment
  accelerates progression (§16).
- ✅ **Purchased loot boxes for an all-ages audience?** → **No.**

**Still open — do not decide these unilaterally:**
- [ ] The Agent's concrete endgame — the epilogue (§2.2) leaves him the
  winner of the bet, the father of the baby and the one man who knows all
  four factions' secrets; whether that becomes a "broker" role in Freelance
  is open.
- [ ] Final player agency after the reveal — embrace the Agent's plan, reject
  it, choose among endings, or witness one canonical villain victory.
- [ ] The fictional federal agency's name and its ranks per country (§2.6);
  whether lap 2's first three confrontations are shorter (the campaign's
  length); §11.1's counters for FOUR factions (they were written for three).
- [ ] The age rating: §16 speaks of an "all-ages product", but the §2.6
  narrative (a policeman causing a mass-casualty disaster, drugs, bodies,
  militias) will be rated 16-18; §16's wording and the social features must
  follow the rating.
- [ ] Exact 1× economy pacing and the catalog of paid boosts beyond the
  permanent gameplay-currency 2×.
- [ ] Rewarded continue restore point and whether one per mission remains the
  final limit after playtesting.
- [ ] Lobby communication model — presence/emotes, predefined phrases, public
  text, or private communication; requires safety/operations research first.
- [ ] Psionic protection — reserved for the future, out of the MVP.
- [ ] Player-to-player item market — future.
- [ ] Diagonal movement — blocked at the start, possibly a late-game skill
  unlock. **Its rendering consequence is no longer open (Director, 2026-08-14):
  if diagonal movement is ever offered, the agent walks two orthogonal GU steps
  rather than traversing diagonally**, so the character's facing set stays at
  four permanently and this decision can never enlarge the actor art budget.
  Whether the movement is offered at all is still open; how it would look is
  settled. See `PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md` D44.
- [ ] Multi-floor / elevation — future, out of the MVP. *(Note: the voxel
  render system now supports vertical storeys; the open question is the
  gameplay rule, not the renderer.)*
- [ ] Exact AP cost per terrain type — needs playtesting.
- [ ] Overlay palette (1 AP, 2 AP, danger, interactable, quest).
- [ ] Do weapons use ammunition, cooldown, or only noise?
- [ ] LLM mission generator — the structure/content split is settled;
  integration is future.
- [ ] Exact noise-trail decay rate — needs playtesting.
- [ ] Exact pause/detour chances in organic patrol — needs playtesting.

---

## 19. Architecture rules for an endless game

These constrain all development, so that the endless model stays reachable.
They complement the eight inviolable rules in `CLAUDE.md`; they do not replace
them.

**Rule 1 — Stats are always data-driven, never hardcoded.** Every numeric
value (HP, damage, range, detection) lives in a resource or dictionary. No
`const MAX_HP`. The system must behave correctly at any difficulty tier.
*(This is the origin of `CLAUDE.md`'s inviolable rule 1.)*

**Rule 2 — Structure and narrative content are always separate.**
`MissionData` works without `MissionNarrative`. The engine never reads text to
resolve logic. All text is replaceable without touching game code.
*(`CLAUDE.md` inviolable rule 6 is this rule's enforcement arm.)*

**Rule 3 — The mission generator takes a tier and produces proportional
encounters.** No encounter is hardcoded to a specific stat level. The same map
template must work at tier 1 and tier 50.

**Rule 4 — The tenth-shot rule is proportional, never absolute.** The fatal
threshold is always "current ceiling + 1", computed dynamically as
`sum(hp, armour, extras) + 1`. It is never the literal number 10.

**Rule 5 — Enemy communication systems are pluggable.** Whistle, radio and
alarm are independent behaviours a guard equips. Adding a new communication
type must not require refactoring existing guards.

**Rule 6 — The portrait panel supports a variable actor count.** Never assume
a fixed number of guards. The UI scales from 2 to 20+ actors without breaking.

---

## 20. Where the build already diverges

Read out of the code on **2026-08-06**. These are not errors to "fix" — they
are shipped decisions that outran this design. They are recorded so nobody
re-derives the design numbers as if they were in force.

| Area | Designed here | Shipped |
|---|---|---|
| Guard state model (§12.1) | 3 layers, 10 operational states | One string FSM, 5 states (`guard_enemy.gd:35`). No `PhysicalStatus`, `Loyalty`, `GuardKnowledge` or `GuardProfile` type exists anywhere in `godot/scripts/`. |
| State detection multipliers (§6) | 0.6 / 1.8 / 2.2 / 3.0 | 0.55 patrol · 1.60 suspicious · 0.80 search · 2.00 alert · 2.80 chase (`tic_system.gd:8`) |
| Shadow multipliers (§4.3) | ÷2 · ×0.75 · ×1.5 over-lit | Five exposure classes: 1.00 / 0.80 / 0.55 / 0.30 / 0.10, plus 0.01 occluded void (`exposure_system.gd:76`). **Richer than designed, and there is no over-lit class above 1.0** — being over-lit is currently no worse than normal. |
| Posture (unspecified here) | — | Standing 1.00 · crouching 0.55 · prone 0.20 (`agent.gd:20`) |
| Dual cone (§12.3) | Primary + 180°/2-tile peripheral, movement-only | No peripheral cone in code |
| Detection thresholds | Meter to 100% then confrontation | 0.30 suspicious / 0.60 alert / 1.00 chase, wired at `turn_controller.gd:212-222`. **Chase, not a confrontation phase — §8 does not exist yet.** |

---

## Provenance

Recovered on 2026-08-06 from
[`history/design-concepts/infiltraitor_master_design.md`](history/design-concepts/infiltraitor_master_design.md)
(§§1–16, 18–19) and
[`history/design-concepts/infiltraitor_enemy_ai_system.md`](history/design-concepts/infiltraitor_enemy_ai_system.md)
(§12 here). Both stay archived and unmodified; **this file supersedes them as
the design reference.** Their §17-equivalent technical-state sections were
deliberately *not* recovered — those were genuinely obsolete, and that is what
earned the archives their DEPRECATED banner.

`history/design-concepts/infiltraitor_wall_system.md` holds nothing worth
recovering: the edge-based wall tiling it describes was fully superseded by
the voxel render system.

**Maintenance:** this file changes when the *design* changes, which should be
rare and always by Director decision. It does not track implementation
progress — if you find yourself updating it because code changed, you are
probably editing the wrong document, except in §20.
