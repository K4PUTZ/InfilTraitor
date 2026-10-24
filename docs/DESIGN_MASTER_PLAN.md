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

**The game does not end.** The campaign is prehistory — an opening, two laps
around the four factions and the finale at the cemetery (§2.2), played once per
character: four story routes, one per faction (§15). It is a narrative
tutorial that establishes the lore, justifies the title, and introduces the
mechanics progressively. After it, the agent enters **Freelance mode**:
procedural missions, content packs, community contributions. Enemies scale,
the agent scales, the challenge stays proportional. Design every progression
system to scale, never to cap (§19 Rule 1).

---

## 2. Narrative — `DESIGNED`

> 🏁 **The plot is CLOSED (Director, 2026-10-23)** after the faction-dress rulings and a plot pass: what remains is authoring detail and
> gameplay, none of it structural (§18). Record: `PROMPTS/RESUMO_SESSAO_2026-10-23_FACTION_DRESS_PLOT_CLOSE.md` §4.

### 2.1 The four factions and the reporter (revised 2026-10-22)

*(Director, 2026-10-21/22: four entities — "Polícia Federal (Uniforme/Autoridade), Milícia Privada (Soldados High Tech), Corporação
(Engravatados/Gangsters), Traficantes (Paramilitares/Bikers)"; each must outlive its leader and be "minimamente uniformizável"; "Tanto faz o nome, o
importante é serem equilibradas".)* Names are working names. All four orbit one company, **GRUB DRILL INC** (§2.6).

| Faction | Uniform / turf | Public face | Truth | Plays as (§11.1) |
|---|---|---|---|---|
| **The Federal Police — the FID, Federal Inquiry Directorate** (§2.7; in the game a FICTIONAL federal agency, its ranks localised per country: a real institution never plays the corrupt faction) | Official uniforms and equipment; stations, checkpoints | The law | Paid to look away from the traffickers; its leaks reach the militia; its chief knows the company's containment pit is where the traffickers' enemies are dumped | Information: radios, check-ins, cameras, trail reading |
| **The Militia** — a private military security company, **Calm Waters Security** (§2.7) | High-tech uniforms and gear; GRUB DRILL's complex across several towns | Security hired by the company's CEO, in exchange for backing his Senate campaign | Takes the traffickers' territory, buys police leaks, bills for security it never delivers; **leaks from the inside** (Director, 2026-10-22): some of its own men sell access, codes and shifts, so the traffickers produce their toxic substances inside the facilities it guards; **unhappy with the "partnership"** (Director, 2026-10-23): the CEO pays late and it presses him to pay before the election, yet it cannot walk away, since it must defend the facilities against the traffickers, and attack them, to keep its hold (§2.6) | Technology and force: drones, sensors, armour, pairs |
| **The Traffickers** — paramilitaries behind a motorcycle club, the **Bunsen Burners MC** (§2.7) | Club vests and patches, bikes; chop shops, the refinery's back rooms | A motorcycle club | Divert banned precursors from the company's refinery into synthetic drugs, in labs the Militia's insiders let them run; their dead go into the pit | Numbers and improvisation: bikes, routes, explosives, chemistry |
| **The Corporation** — GRUB DRILL INC itself: its CEO **Gordon Pryce**, the leader (Director, 2026-10-23), and the board's minority bloc under **Evelyn Marsh**, the sub-leader (§2.7) | Suits **of their own cut, palette and earpieces**; their field officers wear overcoats like every faction's (below), never the Agent's fedora; **the LED camouflage coat is their secret project** (Director, 2026-10-23; §10.5) | The company's governance | A head in name only (Director, 2026-10-23): the CEO cooks the books (future energy sales booked as cash) and buried the engineers' risk report to protect them; the board's bloc knows the company is not making a profit but cannot prove it, knew of the report and kept quiet, hoping for a CONTAINED leak that would drop the company's value without the full accident and bring him down (Director, 2026-10-22: they sabotage the CEO), and covets a fat commission for selling it at half price to foreign funds; no options of their own; the bloc finances the traffickers, for a scandal; they have their own suited agents (§2.6) | Money and access: bribes, hacking, private agents, prototypes (the LED camouflage) |
| **The Agent** | The FID investigators' mustard overcoat; his hat, shoes and tie set him apart (D70, D78) | A federal investigator (a field officer, Inspector), a grieving father | The police leak that sells information to the militia (and to the reporter, below), and the man who breached the dam (§2.6) | — |
| **The Press** — a reporter, **Thomas Marlow of *The Sieve*** (§2.7), a fifth element, NOT a faction (no guards, no uniform, no league) | — | An investigative journalist | Consulted the Agent as an anonymous police source: bought the information about the traffickers that the Militia used. **Innocent of the massacre: the only one who did not cause the son's death** (Director, 2026-10-22) | The campaign's lead supplier in lap 2 and its final encounter (§2.2) |

**Each faction outlives its leader:** the police are an institution (a new chief, the same cover-ups); the militia is a contract and a territory; the
club is a business with a chapter structure; the Corporation is a fund and a board. **All four are innocent of the attack and guilty of the massacre**
(§2.6); the Agent is guilty of the attack.

**Field officers wear overcoats, in every faction (Director, 2026-10-23).** Above the street ranks, each faction has field officers who lead
the soldiers in ordinary missions: §11.2's Lieutenant tier (Inspector, Team Leader, Road Captain, Case Manager), the sub-leaders being the most
senior of them, with distinctions. They wear an overcoat in their faction's colours, with its symbol. **The Agent is one of the FID's**: an
Inspector, below Deputy Commissioner Barrow, who is more decorated and takes Graves's post. Mustard is the colour of the FID investigators'
coat; the Agent's hat, shoes and tie set him apart from his colleagues. That rank explains his modest pay (the debt, §2.6) and the police's
internal dispute (§2.2). **Readability (D78):** in another faction's uniform its guards may take him for one of their officers from afar (§2.2,
§10.5), never up close (his hat, tie and shoes give him away); the player never loses him, because a non-cosmetic cue marks the Agent
(`COSMETICS_MASTER_PLAN` C3).

**Balance (Director: equivalent as a whole, different in everything else):** each faction owns one axis and has the weakness another exploits; each gets
the same total threat budget, spent differently; balance is MEASURED (completion rate per faction and per route, §2.6), never asserted on paper, and the
weekly war re-targets each faction's objective from that data (`COSMETICS_MASTER_PLAN` §4). ⚠️ §11.1's counters (visor / weapon / armour) were written
for three factions; the fourth needs its own (§18).

**None is the final deception.** The campaign first invites the player to read the four factions' shared guilt as the answer (§2.6, twist 1). That is
the false resolution: the Agent himself is the infiltraitor and the traitor, and has known it throughout (twist 2), which the reporter, the one outsider
who puts the pieces together, throws in his face at the finale (§2.2, §2.4).

**The name is the narrative:** INFILTRAITOR — the agent is both infiltrator and traitor: the police's own leak, then a guest on each faction's turf (its pass, or
its symbol on his coat) who betrays it in turn. **He knows what he did while the player does not** (no amnesia, no recurring flashbacks), but **not the whole story** (Director,
2026-10-21: *"Seria melhor que ele precisasse investigar, e fosse descobrindo pelo caminho que a ação dele foi catalisada pelos erros dos demais"*), and
uses the campaign's heroic framing to make the player execute his plan under a false conviction.

### 2.2 Two modes

**Campaign — the prehistory (an opening, two laps around the four factions and the finale at the cemetery; revised 2026-10-22).** Curated, and a
complete tutorial. It is the same campaign for free and paying players (§16); payment changes progression speed, never access. Each chapter introduces a
faction and its mechanics. It has a beginning, middle and end — the traitor is exposed here. **The Elite prologue of the earlier canon is superseded:**
the game opens at home (Director, 2026-10-21). **It is played once per character, four story routes** (Director, 2026-10-22; revised 2026-10-23): the
BACKGROUND the player states in the deposition creates that character (his class, §15) and ties him to one faction for good; the same player
replays the campaign with another background to get another character.

```
OPENING — Home (Director)
  The Agent comes home and pours a drink. The news: a fire at a substation
  failed the dam's containment; a mass collapse floods the town with
  acid (§2.6); curfew. He is genuinely stunned. His phone, left at home, shows missed calls
  from his wife. It rings: his wife is in intensive care; their son is
  dead. He falls to his knees. Titles.

THE POLICE STATION
  His deposition. Too close to the case, the commissioner (the police
  chief, the leader he faces in lap 2: Director, 2026-10-22) forbids him,
  VERBALLY, to work on it, and hands him urgent OFFICIAL missions instead,
  in the zones where the police has limited access; he keeps his badge
  for now (Director, 2026-10-22). In private, the same commissioner runs
  him OFF THE BOOKS, hidden from his deputy Barrow (Director, 2026-10-23;
  the commissioner paragraph below).
  THE DEPOSITION IS THE CHARACTER CREATION (Director, 2026-10-22; the
  model is Fallout 3's): the camera's little light comes on, it points at
  the player, and the deposition begins; he states who he is, his height,
  the colour of his eyes, and so on, and as he describes himself the
  character is built. The name he gives is the one the epilogue's TV
  report reads. He also states WHERE HE GREW UP AND WHAT HE CAN DO: a
  policeman all his life, a former member of a motorcycle club, an army
  veteran, or a former private security guard (Director, 2026-10-23).
  That background is his class (§15): it decides his unique abilities,
  the equipment he can operate, and the faction he answers for in the
  rankings (COSMETICS_MASTER_PLAN §2).
  Outside, the faction of his past approaches him (Claude, under the
  Director's delegation, 2026-10-23): the old club, the old comrades
  now at Calm Waters, the old employer, or, for the lifelong policeman,
  Barrow. The one who approaches is that faction's SUB-LEADER, not its
  leader (§2.7): his handler for the whole campaign, who wants the
  leader's post. **Being approached grants NO access** (Director,
  2026-10-23): he starts with the police's common facilities only, in
  the FID investigators' overcoat; every other turf is closed until he
  earns a PASS (the leader's trust, or an inside mechanism: below).
  *(Supersedes "the faction picked here creates the character; its
  uniform is his first disguise and he moves freely on its turf".)*

ACCESS — the UNIFORM and the ACCESS are two separate things
  (Director, 2026-10-23; supersedes the same day's "passes and bluffs")
  - A UNIFORM (a faction's field-officer overcoat, §2.1) is EASY: stolen,
    found or earned. From a distance it lets him pass in that faction's
    zones, but it grants no access.
  - ACCESS comes from that faction's leader's trust (a favour done, lap
    1) or from an inside mechanism: the Militia's insiders who sell
    codes and shifts (§2.1), Barrow's forged pass (§2.7), a bribe
    (§11.6). WITH ACCESS AND THE RIGHT UNIFORM he is not bothered. In
    any other dress he is a TARGET there, the black suit included.
  - UP CLOSE NOTHING HIDES HIM: at a CHECKPOINT, or in the GU next to an
    OFFICER (§11.2: Lieutenant and up), he is recognised whatever coat or
    LED panel he wears, because the coat does not hide his hat, his tie,
    his shoes and the rest. Then:
    - with access he goes on;
    - if that faction WANTS him, he is arrested or killed;
    - without access he becomes a target (Director, 2026-10-23).
  - Per faction his standing is NO ACCESS, ACCESS or WANTED, and wanted
    overrides access. What makes him wanted, and what an arrest is in
    play, is open (§18).
  - Before the LED coat he wears ONE uniform per mission, so he passes as
    one faction at a time (Director). The choice is made before the
    mission, as a slot of its own beside §10's three classes (Director,
    2026-10-23). The ARMBAND is part of the uniform and follows the coat
    he wears; his background shows in the lining, the tie, the pocket
    square, the mark of his past and the banner, which are also among
    the differences that give him away up close (Director, 2026-10-23;
    `COSMETICS_MASTER_PLAN` §9.2). The LED coat (§10.5) carries every uniform he holds and
    switches between them.
  - Access can be lost: the police's goes with the badge (lap 1). The
    mustard coat still passes from afar, but checkpoints and officers
    now stop him. From then on Graves's favours earn information, never
    a police access (his trust is secret, his ban public); the police
    turf then takes Barrow's forged pass or an infiltration.
  - Technology is incorporated by meeting its author (§11.6); each
    uniform he gets joins the LED coat's wardrobe.

CAUGHT, MASKED, ALERT, ARREST (Director, 2026-10-23)
  - CAUGHT: if he breaks a rule of conduct and is caught, that faction
    WANTS him in that scenario, which basically means a shootout. He
    must silence the witnesses: killing them, knocking them out and
    tranquilliser darts all count. Above all he must ESCAPE before more
    of them arrive, to stay anonymous.
    - He need not finish the objective, but the ALERT rises and the
      mission must still be done at some point: it stays open.
    - If he dies, he dies: GAME OVER (below).
    - The knockout and the dart keep §2.6's no-kill run and non-lethal
      option intact. A knocked-out witness wakes knowing there was an
      intruder, never who (Claude).
  - MASKED: seen in the black suit and the mask, he leads the factions to
    the WRONG conclusion that the club's masked assassin is still alive,
    supposing more people know of him, which deflects suspicion. Only
    "Deacon" knows the man is dead and his mask taken (THE MASK, above).
    Claude: it feeds the official version that the club did it (who
    takes the blame, below).
  - ALERT: between scenarios, toward the end, the alert level rises.
    HIGHLY WATCHED ZONES accept no uniform and no LED coat: there only
    hiding works (the LED coat's cloak, §10.5). Elsewhere the LED coat
    stays useful always.
    Claude's reading, to confirm: the rise is more and wider high-
    security zones, authored in the time states (§14.4), climbing one
    step with each leader's death in lap 2 and with each CAUGHT incident.
  - GAME OVER, on a death or an arrest (Director, 2026-10-23). An arrest
    is never a state of play: the Agent fights.
    - The failure screen tells the fate by faction: scrutinised by
      justice for the police, executed by the bandits.
    - Then he is back on the MAP (the globe, the mission hub,
      `COSMETICS_MASTER_PLAN` §6) and may REPEAT the mission or CHOOSE
      ANOTHER; the mission stays open.
    - Claude's readings: §16's single optional rewarded continue comes
      before the return to the map; a repeat starts the mission over,
      since leaving a level clears its checkpoint state (the save model).
    - Considered and set aside: a jailbreak, which makes him a fugitive
      before the finale; and buying his escape from a leader with
      another's secret, which spreads knowledge across the circle and
      breaks the leaves rule (§2.6, §2.7).

THE AFTERMATH — the backdrop of the whole campaign (Director, 2026-10-22)
  Leaving the station, the map is revealed: the region is devastated.
  The rescue is heard of more than seen: police vehicles, cordons,
  hoardings, closed zones. The rest of the town is chaos, held by the
  factions for lack of authorities, under the curfew; some areas taken
  by looters, or by faction members using the moment. The flood was
  ACID, not mud (§2.6): the ground stays dangerous to walk long after,
  which is why the scenes are full of obstacles. That chaos is what lets
  him move through the region's towns, and the campaign's places come
  back as time passes, changed a little (§14.4).

THE OFFICIAL WORK — first (Director, 2026-10-22)
  The commissioner's missions are his JOB, not the parallel investigation
  he does for the factions. The player picks which come first, before
  leaving for the investigations; one of them is restoring the power
  station. All are infiltration: gathering evidence, talking to people,
  planting bugs, acting on the world (opening a sluice gate, draining a
  tank).
  He starts with almost nothing (§10.0), the gear of the attack: a common
  pistol, his overcoat, stones, a chokehold, an alarm clock, a spray can,
  chloroform, a short rope and hook; a balaclava hides his face, the coat stowed in his
  black pack. He starts in an ordinary fedora.
  THE MASK (Director, 2026-10-23): it belongs to a HIRED ASSASSIN whom
  "Deacon" contracted to carry out his jobs, and who is investigating
  the same thing as the Agent. By luck the Agent arrives late: the
  place has already been infiltrated, but he gets there in time to
  eliminate the assassin, and takes the mask. It IS a fedora (its crown
  comes down over the face, `ACTOR` D77) and replaces his own. Nobody
  in the club knows where the mask came from except "Deacon".
  - Where (Claude, reconciling the same day's ruling that the mask comes
    early and at the same point in every route): the assassin has
    infiltrated one of these official-work sites ahead of him. Which
    one: open (§18).
  - The assassin counts as a BOSS (Claude, a consequence to confirm): a
    mortal confrontation like the four leaders', excluded from the
    violence threshold and from the no-kill achievement (§2.6), so a
    required kill never breaks either.
  - Name (Claude, proposed, in the club's churchly style): "the
    Confessor", who makes his targets confess before he kills them.
  - Why it works (Claude's remarks): Deacon's lap-1 favour ("find who
    leaks to the Militia") is the job his dead assassin was doing, so he
    hands it to the Agent. Deacon knows the mask, so when he faces the
    masked intruder in lap 2 he knows who killed his man, and the secret
    dies with him. And on a second playthrough (§2.4) the "luck" reads
    as the Agent silencing an investigator who was closing in on him.
  - The pack battery is a later UPGRADE (§10.5); until then the mask
    runs on its own small charge.

LAP 1 — the favours (four chapters, one per faction; the circle stays:
  Director, 2026-10-22)
  Leader A shares what he knows only for a favour: investigate leader B.
  B asks for C, C for D, and D points back at A (the circle, §2.6). Each
  favour earns a piece of information and the ASKER's trust: the access to
  the asker's turf (revised 2026-10-23: the access is the asker's, never
  lent; a UNIFORM can come earlier, stolen or found, and passes only from
  afar, ACCESS above). Each chapter teaches its faction's mechanics; the
  starting faction is the player's, so no chapter may depend on another's.
  WHERE A CHAPTER IS PLAYED (Director, 2026-10-23): on the turf of the
  faction being INVESTIGATED, as an INFILTRATION: he holds no access there,
  only what an inside mechanism or the asker's help can open, and a
  stolen uniform that fools from afar, never at a checkpoint; the LED
  coat comes later, in lap 2 (§10.5) (the police chapter is the exception:
  he walks in on his own badge, and Graves takes it there); the chapter teaches the investigated
  faction's mechanics, and its specialists (§11.6) first appear there.
  So chapter 1 is the next faction round the circle, and CHAPTER 4 IS
  ALWAYS THE PLAYER'S OWN FACTION: every route closes lap 1 with the
  Agent investigating his own leader, at the request of the faction
  before it, with his handler's blessing (§2.7). The order per route:
    Police route:       Militia, Traffickers, Corporation, Police
    Militia route:      Traffickers, Corporation, Police, Militia
    Traffickers route:  Corporation, Police, Militia, Traffickers
    Corporation route:  Police, Militia, Traffickers, Corporation
  THE BADGE (Director, 2026-10-22): when lap 1 reaches the police over
  the pit (the Corporation's favour, §2.6), the commissioner says he is
  interfering with the investigation for revenge, and takes his badge.
  From then on he can still walk police zones, but checkpoints stop him
  and he is discovered: the police ACCESS is gone (the mustard coat still
  passes from afar), so his own turf now needs Barrow's forged pass
  (§2.7) or an infiltration. That chapter's position moves with the route
  (4th on the Police route, 1st on the Corporation route), and so does
  how long he keeps the badge.
  Midpoint: his wife's condition turns critical, and the hospital is
  short of blood: every shootout's wounded drain the same bank (the
  warning, §2.6). There is no baby (Director, 2026-10-22).

BETWEEN THE LAPS — the neutral missions (Director, 2026-10-23)
  A series of NEUTRAL missions between the laps. They let the player raise
  his stats where he is weak in a kind of skill, or get better equipment.
  They resemble Freelance mode (below), with different kinds of
  objectives that pay DIVIDENDS.
  Claude's proposals:
  - They are LEAVES like the sub-missions (§2.7): they read the world
    (access, the alert, the time state) and never carry a piece of the
    disaster.
  - Each kind of objective trains one family of skills and pays in its
    own way:
    - RECOVERY (goods from the acid zone or a depot): gear;
    - SURVEILLANCE (photographs, a bug planted): information sold
      faceless, money;
    - SABOTAGE (a camera net, a drone hub): one faction's alert down a
      step, the counterweight to CAUGHT;
    - DELIVERY (courier runs across the zones): money, and practice with
      uniforms and access.
  - They reuse the campaign's kits and the trips' places on the globe,
    and the generator and templates Freelance will use (§2.5).
  - Failing one is the same game over: back to the map.
  - Their kills COUNT in the violence average (Director, 2026-10-23,
    §2.6): diluting a violent run by playing them clean is a valid
    redemption.

LAP 2 — the confrontations, in ANY order (Director, 2026-10-22: he will
  kill each leader eventually, so the order is free)
  The leads now come from THE REPORTER, who consulted the Agent as an
  anonymous police source before the disaster and investigates it too;
  his hints change with the order the player chose. At each leader: a
  mortal confrontation (a SHORT mission), the leader's confession of its
  share in the disaster, a clue: "someone did X". TWIST 1 (the false
  resolution) builds: the four shares made the massacre. Every clue
  describes the Agent: he is not following leads, he is killing witnesses.
  When a leader dies, his SUB-LEADER takes the post and answers for that
  faction from then on (§2.7). The sub-leaders blame EACH OTHER for the
  deaths, never the Agent; that war is why the next visits find new
  checkpoints (§14.4), until the memorial's truce (who takes the blame,
  below). Deaths between factions are scenery and never
  count toward the run's violence (§2.6: only the player's kills do).

THE CEMETERY — the finale (a scene, no fight: Director, 2026-10-22)
  Time has passed and the town is restored. A public memorial at the
  cemetery, before the four factions and the press, gathered by the
  tragedy, where the four sub-leaders seal their truce on the official
  version (who takes the blame, below); the Agent pays homage at the grave of the son he has just
  buried, his wife beside him, or buried there too if the run's violence
  cost her life (§2.6). He lets slip something only the attacker could know; to the
  player it reads as grief. Cut: walking away from the ceremony, the
  reporter, who has put every piece together, draws a gun. In the rain,
  the revelation (TWIST 2): he knows the Agent is the villain; the only
  one who did not is the player. The Agent draws too: a standoff. The
  player chooses:
  - KILL THE REPORTER, the only one who did not cause his son's death:
    he is discovered and becomes a FUGITIVE.
  - LET HIM LIVE: remorseful, his son just buried, the Agent puts his
    own gun in the reporter's hand, tells him to do what he thinks
    necessary, and turns his back. The reporter, implicated himself, is
    tempted to erase him, or sets justice after him (the endings to
    explore: open). The Agent becomes a FUGITIVE.
  THE TRUTH STAYS BURIED in both branches (Director, 2026-10-23): the
  blame must never fall on the Agent. If the reporter publishes, the
  faked death (his DNA "dissolved" in the pit) and the truce the four
  factions sealed at the memorial make the story read as a conspiracy
  theory against the official version; The Sieve's motto, "Everything
  gets through", is the irony. Only the reporter, and the player, know.
  A permanent tattoo marks the choice on that character
  (COSMETICS_MASTER_PLAN §3).

EPILOGUE (Director, 2026-10-22)
  Both branches leave him a FUGITIVE (supersedes "kill him and stay
  free"), and in EVERY scenario he FAKES HIS OWN DEATH and disappears,
  whether his wife lives or not, whether the reporter lives or not.
  At the pit (the police's dump for bodies), he throws his belongings
  into the acid, the gun, the badge, and his own DNA: the acid explains
  why there is no body. A TV news report confirms his death. The camera
  pulls back from the room and finds his wife with her relatives; it
  keeps pulling back, out through the window, to the Agent outside,
  watching her with her family, before he turns his back and disappears
  into the horizon. Dead to the world, he goes on infiltrating and
  charging for information.
  Unlocks: FREELANCE MODE for that character (COSMETICS_MASTER_PLAN §4).
```

**The epilogue's open joints (Claude's proposals, not yet ratified):**
- **The badge** was taken by the commissioner in lap 1 (§2.2); for it to go into the acid he takes it back from the chief's body after the lap-2
  confrontation, a beat of its own.
- **The gun:** in the let-him-live branch the reporter holds it; there other belongings go in, and one goes in every branch: his wedding ring.
- **The DNA:** a strong acid destroys DNA, so his blood is left on the pit's edge (the railing) while the belongings go in; the investigators read
  "dissolved in the acid". This is the acid's second use in the story.
- **The sad ending's last shot** (the wife died): the TV plays in the empty house the bank has taken (the debt, §2.6); the camera pulls back
  through the window to the Agent alone outside, who turns and disappears.
- **The earlier beats ride the same news bulletin** before his death is reported: the CEO dead as a candidate, his death blamed on the war
  between the factions; the hole in his books, found afterwards and laid on the dead man; Evelyn Marsh in his chair, selling the company to
  Carrion Capital at half price; the Militia never paid (Director, 2026-10-23: the CEO is the Corporation's leader and dies a candidate, §2.6).
  "I found all of them" stays at the son's grave (§2.2); "There is no right or wrong. There are only winners." is his last line before he turns
  away. *(Claude, remark: half price is roughly what a company with that hole is worth, which is why a vulture fund takes it. Superseded
  2026-10-23: "the CEO elected on the 'accident' version", and Claude's newly elected senator steering the exploration contract.)*

**The commissioner is the police chief (Director, 2026-10-22).** He bans the Agent verbally at the station, gives him the official missions,
takes his badge in the Corporation's chapter, and is the man the Agent later kills.

**The police from inside (Director, 2026-10-23; the arrangement is Claude's, under his delegation).** Graves does not trust his deputy: Irene
Barrow is more decorated than the Agent and covets the chair, and Graves cannot use his own men either (the leak, §2.6). So, in every route,
Graves bans the Agent in public, for the record and for Barrow to hear, and **runs him OFF THE BOOKS** ("find the leak, from outside": his favour
in the circle). **Barrow runs him too, against Graves,** when she is his handler (the lifelong policeman's background, §2.7): *"Graves wants his leak
found. I want Graves's chair."* Neither knows of the other. **The badge is no contradiction:** when the Corporation's favour brings the Agent to
the pit, his investigation has reached Graves himself; Graves takes the badge to bury what he found ("revenge", in public) and keeps him as a
deniable asset who now depends on him alone, so in any route order the channel stays open. *(Supersedes the earlier 2026-10-23 line "the ban is
Graves's and official; the job is Barrow's", which met the same objection by keeping Graves out of the job.)*

**Who takes the blame (Claude, under the Director's delegation, 2026-10-23).** The Director's constraint: every sub-leader ends believing the
Agent innocent (only the reporter knows), and the blame lands on leaders, possibly through a leaked deal between two of them. **The deal that leaks
is Graves and "Deacon"'s:** the police's protection of the club's labs, the pit as the dump for its dead (§2.6), and the kamikaze drone, the
club's signature. The official version the memorial seals: the club struck the substation in its war with the Militia, through a policeman on
Graves's payroll who passed it the Militia's codes and the roadblock; the pit, whose inspections Graves had blocked to hide the bodies, gave way.
- **It is built out of lap 1:** the Militia's favour ("prove it was the traffickers": the drone, the chop shop) and the Corporation's ("prove the
  State's negligence": the pit) are the evidence, and the Agent hands both over with no name of his on them.
- **Its fall guy is the Agent's own lie:** the "policeman killed in the flood" he names as the leak (§2.6) is that payroll policeman, and the
  Militia's codes and the roadblock's police credential (the lap-2 clues, §2.6) both point at him. Pith & Peel Holdings was registered, before the
  disaster (ruled 2026-10-23, on Claude's recommendation; the money, §2.6), to that same colleague, who lent his name for a cut (a "laranja"); his death in the flood is chance, and it
  is why the Agent names him, so the puts (the Corporation's clue) stop at him too.
- **The dead do not deny:** Graves and "Deacon" both die in lap 2. Barrow and "Choirboy" each blame their own dead leader, which legitimises
  their coups ("Choirboy" believes Deacon ordered it without the chapter); Hardcastle and Marsh accept it gladly, since it keeps the silent sirens
  and the buried report out of view. The CEO's hole still surfaces only on the epilogue's bulletin, laid on a dead man.
- **The irony:** the Agent's original plan (the blame on the traffickers, in an investigation he expected to lead) comes true; only the reporter
  holds the piece that breaks it (the informant is his own source, and alive).

**Lap 2's lengths:** with the finale a scene, the campaign's last playable mission is a leader confrontation in a free order, so which one is the
complete mission is open again (Claude's recommendation: four standard missions of one size, so no faction needs both a short and a complete
version). Superseded: "the reporter's finale is the complete mission". **The reporter's hints (Claude):** keyed by the faction he points at and how many pieces the player already holds (4 x 4 = 16 lines), never
by the full order (24 permutations).

**The kill count (Director, 2026-10-22):** achievements for a run with no kills, bosses excluded. **Consequence (Claude):** every mission needs a
non-lethal route (knockout, sedative dart, smoke: §8, §10.4, §11.3); the four leaders are the bosses. The reporter is not one (there is no fight),
so killing him is a kill and a no-kill run must let him live (Claude: follows from the cemetery finale).

**The reporter (Claude's proposals, RATIFIED by the Director 2026-10-22).** **The canon is in English; names may be swapped per language later**
(Director). Name: **Thomas Marlow** (the doubter who must see to believe; Marlow, the witness of *Heart of Darkness*; Tomás, Tomasz, Tommaso if
localised), never a surname that evokes a real case (no "Vale"). Outlet: an independent, reader-funded local investigative site, **The Sieve**
(§2.7; it replaced *Blind Spot* on 2026-10-22, a real newsletter's name; localised like signage; a registry check before launch). First contact: seen at the police station's door in the opening (he recognises his source being barred from the case); the real approach at the
hospital after the wife's death, with the trade that opens lap 2 (his leads for the leaders' confessions); the cemetery is kept for the finale. Why
only he can close the case: the Militia's clue speaks of "our informant", and only he knows the informant is his own source, because his scoops
reached the Militia before he published them. The slip at the memorial: a line about the target only the attacker could know (e.g. "it was only
supposed to be the lower basin").

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
  their real order;
- **the start kit is the attack's gear** (Director, 2026-10-23, §10.0): what the player carried from the first mission is what the Agent wore
  that night; the rope and hook got him over the Militia's wall.

The preferred reveal mechanism is the project's own information grammar: an
outside breach or recovered source removes the Agent's filter and relabels
`HOSTILE` as `WITNESS`, `WEAPON CACHE` as `EVIDENCE ARCHIVE`, or `EXTRACTION`
as `ACTIVATION SITE`. **The game has done to the player what the player does to
guards: controlled behaviour by controlling information.** **The outside source
is the reporter (2026-10-22, §2.2):** his accusation at the finale is the
reveal, and the relabelling follows it (Claude's mapping of the Director's
finale onto this mechanism). A post-campaign
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
(the "controlled breach" and the "unknown client").** The pregnancy was dropped on 2026-10-22: there is no baby.

**Fiction, not reportage.** Inspired by the tailings-dam collapses of recent years, never named after them: no real person, company or detail that
identifies a real case, and the dead treated with respect (no spectacle of the flood, no gameplay that makes light of it). **Acid, not mud
(Director, 2026-10-22):** the flood is an acid one, born of the traffickers' drug waste in the reservoir; the ground stays dangerous to walk long
after the tragedy, which justifies scenes full of obstacles, and it moves the game's image away from the real collapses' mud. The engine already
has the liquid (`liquids/acido.json`, M6: exposure in the shallows and the deep, footprints, it corrodes floors, curbs and metal). **The town is the city the
player chooses as his base** (Director: *"É uma obra de ficção sobre uma tragédia que pode acontecer em qualquer lugar"*); real names and flags appear
only on neutral places (`COSMETICS_MASTER_PLAN` §6); a player who gives no city gets a fictional default. **Backup settings:** an OIL REFINERY or a
HYDROELECTRIC PLANT carries the same plot. **Open — a city that lived a real dam disaster** (Director, 2026-10-22: barring a player from his own
city might be even more unpleasant than the fiction). Claude's recommendation: the dam stays in every city, as ruled; the question goes to the
association of those affected before launch (`LAUNCH_MASTER_PLAN` §1); the backup setting is kept as a tool, swapped silently if they ask for it, never
a "your city is not allowed".

**GRUB DRILL INC** (fictional; a quick web search on 2026-10-21 found no company or mark of that name — a registry search before launch; the only known
"GRUB"s are unrelated: GNU GRUB, Grubhub). **Logo (Director, 2026-10-22):** a stylised curled grub (reference `REFERENCES/grub.webp`); the symbol is drawn by us, the photo is only a reference.
A complex of refinery, mining and chemical-agent production across several towns. Its CEO runs for the Senate
and wants an exploration contract with the government; he hired the Militia's company to guard the complex in exchange for campaign support. One of its
sites is the dam.

**The CEO's fraud (Director, 2026-10-23).** He pays the Militia with money the company does not have: he books contracts for FUTURE ENERGY SALES
(energy not yet delivered) as cash in hand. He runs for the Senate (his first election) to win the government exploration contract, the resources
that would let him deliver that energy and honour those contracts, so the seat is existential for him. **The board knows the company is not making
a profit, but cannot prove it:** one more tension, and one more reason for the Corporation to want him down.

**The Militia is not satisfied either (Director, 2026-10-23).** The payments run late, and it presses the CEO to pay before the election: the
"partnership" sours. Yet it cannot walk away: it must defend the facilities against the traffickers, and attack them, to keep its hold on the
complex. That raises the Militia's stake in everything that follows.

**The CEO is the Corporation's leader (Director, 2026-10-23).** In the last instance he represents the Corporation, and he is the Militia's client
and paymaster, with Commander Kessler at his side as the "contracted partner". On paper he heads both; **in practice he heads nobody**: the board
does not trust his books and the commander is not being paid, so his hold on both ends depends on the campaign succeeding. He buried the engineers'
report himself, and the board's bloc under Evelyn Marsh, his sub-leader (§2.7), knew and kept quiet (the Corporation's failure, the table below).
**He dies a candidate:** the Agent kills him in lap 2, and the campaign, the only thing holding his two ends together, dies with him (the epilogue,
§2.2).

*(Claude, remarks: the Militia's leverage is the campaign support, worth nothing once he is elected, hence "before the election". Its favour,
"prove it was the traffickers", now pays twice: a war it needs, and a lever on the CEO, since it is the only thing between him and the
traffickers. A real investigation would find the sirens and could sink the candidate who owes it, so it needs the official version twice over.
The late pay is also a reason for its own men to sell access to the traffickers' labs (§2.1), which ties the CEO's fraud to the Militia's
insiders without making it one of the four failures. The Militia bills for sirens that do not exist and is paid, late, with money that does not
exist. A contained leak would bring inspectors and auditors in, which is how the bloc would prove what it cannot, one more reason to hide the
report. And the proof surfaces only after his death, on the epilogue's bulletin (§2.2), so a sub-mission may brush the fraud but never close it
(§2.7: sub-missions are leaves).)*

**The Agent (Director; "he is the leak" is Claude's proposal, accepted 2026-10-22).** Before the disaster he already sold police information to the
Militia (the police's leak is him), and a reporter bought the information about the traffickers from him as an anonymous police source (Director,
2026-10-22; §2.1). **He sells to the Militia FACELESS** (Director, 2026-10-23): a dead drop and a burner phone, so nobody in the Militia knows who
their informant is; otherwise the Militia route, which recruits him, and Kessler's clue ("codes only we and our informant knew") both break. The
reporter is the only buyer who knows his face (§2.2). His plan: a SMALL spill at a secondary basin far from the town, a bet against the company, and the blame on the
traffickers (a kamikaze drone is their signature) in an investigation he expected to lead. He left his phone at home (the antennas put him there: his
alibi) and launched the drone. **He did not know the four failures below.**

**The bet (Claude, 2026-10-22, answering the Director's question).** **Short-dated PUT OPTIONS bought through a front ("laranja")**, not a short sale: a
man in debt can afford a premium (a short needs margin and can lose without limit), and the leverage makes a small spill pay. **He bets alone
(Director, 2026-10-22: the Corporation buys no options):** the board's bloc wants the fall for a different payout, the commission on selling the company
at half price to foreign funds, and kept quiet about the engineers' report hoping for a CONTAINED leak to get it (the CEO buried it, below). **The Corporation and the Agent wanted the same
thing, a small spill (Claude's remark):** that makes the Corporation the natural suspect and feeds twist 1. **His tell is the expiry:** he bought puts
expiring days later, which only someone who knew the date would do; the Corporation, watching its own stock for the sale, sees them (its clue in lap 2).
Proposed origin of the idea (Claude, revised 2026-10-22): police intelligence shows him the Corporation's talks with the fund: if they want a fall, he will
make the fall, and they will be the suspects. **Not a dark-web
contract paid in bitcoin:** there is no market for it, and bitcoin's public ledger is traceable at the cash-out; if crypto appears at all, it pays for the
drone parts or the front, and then it is one more trail.

**The money (Director, 2026-10-23, on Claude's recommendation).** The puts PAID, into Pith & Peel's offshore account, which stands in the name of
the colleague who lent his name for a cut and died in the flood (§2.2, who takes the blame). For the living Agent that money is untouchable: a
dead man's account under a federal case. That is why the debt still stands and the bank can take the house in the sad ending, and it gives the
faked death a second motive beside watching his wife from afar: only a dead man can reach a dead man's money, abroad (the investigation's
offshore broker, below).

**What happened.** The drone struck the substation that powers the pumps and the sirens. The flood was acid: the traffickers' waste had turned the
reservoir (their failure, below). **Four failures turned a small spill into a massacre; each
faction is guilty of one and innocent of the attack.** The official version, "a fire at a substation", suits all four, so none wants a real
investigation, and each needs one off the books.

**The family (Director, 2026-10-22: no baby).** His wife and son, driving home early from an event in another town (her missed calls), were caught
near the epicentre. The son dies, and is buried late, after the town is restored (the cemetery finale, §2.2). The wife is in intensive care.

**Her fate is the run's violence (Director, 2026-10-22).** **The common ending is that she SURVIVES.** If the player kills too many people, in the end
the hospital runs short of a supply because of the excess of deaths, and she dies. The classes stay equivalent in play and in Freelance; a player who
goes in hard with ANY class sees the sadder ending. *(This is Dishonored's chaos, a reference the game already names in §1.)* **He fakes his own
death in every scenario (Director, 2026-10-22)**, whether she lives or not; if she lives, he watches her from afar. The cemetery scene has two
versions (with her beside him, or at her grave).

Claude's proposals for it (RATIFIED by the Director, 2026-10-22):
- **The supply is blood:** the wounded of every shootout drain the same blood bank she depends on, which makes "deaths cause a shortage" causal
  without showing anything (a line on the radio, the hospital's appeal for donors).
- **It is warned, never a trap:** the midpoint is the warning beat (her condition turns critical, the bank is short, §2.2), and the world reports
  the shootouts' toll on the radio, so the player is never surprised by a rule he never saw (§11.4). Dishonored was criticised for punishing players
  who used the combat it handed them; the warning and a GENEROUS threshold ("many" kills, not a few) are the answer.
- **What counts:** deaths the player causes, by any means (a shot, a blast, a guard pushed into the acid); knockouts do not; the four leaders'
  mortal confrontations do not (they are required); the reporter does not (the cemetery comes after her fate is sealed). **The threshold
  (Director, 2026-10-22): the run kills, on average over its missions, MORE THAN 50% of the enemies** (bosses excluded); it is data (§19 Rule 1),
  per character (each route has its own ending). **The neutral missions COUNT in that average** (Director, 2026-10-23, §2.2 BETWEEN THE
  LAPS): diluting a violent run by playing them clean is a valid redemption.
- **Every class needs a non-lethal option from the start** (§15), or one class would be pushed toward the sad ending. A no-kill run (the
  achievement, §2.2) always reaches the common ending.

**Superseded 2026-10-22:** the baby (*"a mãe morre mas o bebê sobrevive no fim"*), the son's survival as a variant, Claude's playable "night of the
disaster", the power (or the order of the official missions) deciding her fate. **The power lights the area (Claude, proposal, kept):** restoring it
switches the area's lights on, so the right act costs the player his cover; the engine already turns lights on and off at runtime for fire
(`LightingController.add_extra_lights()` + `rebuild_tactical()`), and a district coming back on is that mechanism at a larger scale, its cost
unmeasured.

**The circle (Director's structure, 2026-10-22; the table is Claude's, accepted):** each leader trades what he knows for a favour that points at the next:
Police → Militia → Traffickers → Corporation → Police. The pairs outside the circle are extra clues for free (Police and Traffickers: the bribes; Militia
and Corporation: the CEO against the shareholders, the Militia paid with money his books invent). **The poster (2026-10-23):**
`DIAGRAMS/CIRCULO_ENREDO.png`, drawn by `tools/asset_generation/plot_circle_poster.py` (Blender): the four factions in the sheet's corners,
the favour arrows, the Agent at the centre. Its symbols are placeholders until the faction logos exist; regenerate it when the circle changes.

| Faction | Asks for (and points at) | Really hides | Its failure in the disaster | Alibi | Obstacle | Its clue about the trigger (lap 2) |
|---|---|---|---|---|---|---|
| **Police** (the chief, who is also the commissioner of §2.2: he bans the Agent verbally, gives him the official missions, later takes his badge) | Investigate a "leak" off the books → the **Militia**, which receives it | The pit as a dump for bodies; the deal with the traffickers | Blocked the pit's inspections: the containment failed | The official "substation fire" version is his, and he runs the case | Cannot use his own men (the leak); fears federal scrutiny | "Someone passed the road block that night on a police credential" |
| **Militia** (the commander of the CEO's security) | Prove it was the traffickers (a drone) → the **Traffickers** | Billed the sirens' backup power and never installed it; takes the traffickers' territory; its own men sell access to the traffickers' labs inside the guarded facilities | The sirens stayed silent | Holds the drone's wreck: "proof" of an outside attack | Cannot let any inspector near the siren system, nor near its insiders | "The drone took off inside our perimeter, with codes only we and our informant knew" |
| **Traffickers** (the club's president) | Find who leaks to the militia; they suspect their financiers → the **Corporation** | The lab in the refinery, run with the Militia's insiders; their dead in the pit | Chemical waste dumped in the dam: the reservoir over its limit | Lost their lab and men: they look like victims | The bodies may surface with the flood; the bought police no longer protect them | "Someone bought drone parts at our chop shop weeks before" |
| **Corporation** (the CEO, Gordon Pryce: Director, 2026-10-23) | Prove it was the State's negligence (the chief) → the **Police**; the chapter in which the commissioner takes the Agent's badge (§2.2) | His cooked books (future energy sales booked as cash); the board's bloc finances the traffickers and wants a contained leak to sell the company at half price to foreign funds, for a commission | The engineers' risk report buried: by him, to protect the fraud (the repairs need money the company does not have, and halting the dam breaks the energy contracts); the bloc knew and kept quiet, hoping for a contained leak. One failure, two hands on the same drawer | The fall "hurts" them in public; no weapons in public (their private agents are covert: §11.6, ruled 2026-10-23) | A real investigation finds the report and the books: it sinks his campaign, and the bloc's sale with it | "Someone bet against us through a front, on puts expiring that week" |

**What he hands over (Director, 2026-10-23).** Two favours ask for the same thing, the Police's "leak" and the Traffickers' "who leaks to the
Militia", and the answer to both is the Agent himself. **He gives both the same lie, in any order: a policeman killed in the flood** (the dead do not
deny). The lie is a clue of its own: the reporter knows the informant is his own source, and alive (§2.2), so at the finale it is one more piece
that points at the Agent. *(Claude, remark: the other two favours need no lie. The Militia's "prove it was the traffickers" is the blame he planned
all along, and the Corporation's "prove it was the State" is true, since the chief blocked the pit's inspections. How much of each he hands over is
open, §18.)*

**The same clues in every route (Director, 2026-10-21; revised 2026-10-22).** Lap 1 is a rotation of the circle from the character's faction; lap 2 is
in any order. Every route meets the same four pieces and the same four clues, and **the reporter, at the finale, completes the picture: §2.4's fair
reveal is written once**, whatever the order, with the Agent's own slip at the memorial as the last piece. Alone, each clue is ambiguous; together they describe one man. The model is Agatha Christie's *The Murder of Roger Ackroyd* (1926): the narrator is the culprit and
every clue is in plain sight.

**The investigation goes abroad (Director, 2026-10-21):** the attack is a FEDERAL case, so the Agent travels beyond the disaster area (the foreign fund,
the front's offshore broker, the traffickers' routes); the campaign's locations sit on the game's 3D globe, also its mission hub (`COSMETICS_MASTER_PLAN`
§6). **The trips (Director, 2026-10-23):** three or four trips abroad, each to find a contact, or a piece of information, about a faction
member who operates from outside the country. The aim is to vary the scenery and make real use of the globe.

**Claude's proposal:** FOUR trips, one per faction, so the routes stay equal. Each is the last mission of the lap-1 chapter that investigates
that faction, where the favour's missing piece lies abroad, so every route visits all four in its own order. Afterwards they become Freelance
places on the globe.

| Faction | Its member abroad | The place |
|---|---|---|
| FID | the money man who launders Graves's protection money | a private bank in a tax haven |
| Calm Waters | the parent holding's finance director, who billed the sirens never installed | the PMC's offshore headquarters |
| Bunsen Burners | the club's overseas supplier of the banned precursors (canon: the traffickers' routes) | a port and a warehouse |
| Corporation | Carrion Capital's partner, Marsh's buyer | the fund's tower in a financial city |

- **The Corporation's trip holds a fair-reveal beat** (§2.4): the same city hosts Pith & Peel's offshore broker, and the Agent quietly derails
  the trail to the front, the account he can never touch (the money, above).
- **Real names and flags only on neutral places;** the factions' buildings stay fictional (`COSMETICS` §6).
- **The cost:** four new location kits (`PROP_PIPELINE_PLAN` §9.2) and four new characters (`COSMETICS` §8.4).

**Lap 2's lengths:** §2.2 (open again since the finale became a scene; superseded "the first three short, the last complete").

**Open (Director):** the agency's ranks PER COUNTRY when the game is localised (the English canon is §2.7 and §11.2: civil ranks, never military,
which settles the draft's "Tenente"); the
dedication and the partnership (`LAUNCH_MASTER_PLAN` §1); what the reporter does in the let-him-live branch; the epilogue's open joints (§2.2); a city that
lived a real dam disaster (above).

### 2.7 Names (Director, 2026-10-22: ratified, with "pitadas de humor")

**The canon is in English; each language may swap names later** (localisation). The humour lives in the factions' names and characters, never in
the victims or the tragedy (§2.6). A quick web search on 2026-10-22 found no exact homonym for any organisation below (it replaced three that
collided: *Blind Spot*, a real newsletter; "Cordon", a real French defence group; "Orchard Holdings", several real firms); **a registry check
before launch**, as for GRUB DRILL INC. Near-match to weigh: the real State Burner's Motorcycle Club (Philadelphia, 1946, a community club).

| Organisation | Name | The joke |
|---|---|---|
| The federal agency | **Federal Inquiry Directorate (FID)** | Motto: *"We'll get back to you."* |
| The reporter's outlet | **The Sieve** | A site that lives on leaks, named after a leaky utensil. Motto: *"Everything gets through."* |
| The Militia (a PMC) | **Calm Waters Security** | Paid to keep the dam's waters calm. Motto: *"Peace of mind, billed monthly."* (they billed for the sirens they never installed) |
| The Traffickers | **Bunsen Burners MC** | Biker chemists: they burn rubber and cook on a Bunsen burner |
| The Agent's front ("laranja") | **Pith & Peel Holdings** | An orange's pith and peel, dressed as a law firm |
| The foreign fund | **Carrion Capital** | A vulture fund named after what vultures eat; it buys GRUB DRILL at half price |

| Faction | Leader (dies in lap 2) | The sub-leader who takes the post |
|---|---|---|
| FID | **Commissioner Martin Graves** | **Deputy Commissioner Irene Barrow** — the police's top brass all have burial names (graves, a barrow); the next one will be called Tomb |
| Calm Waters Security | **Commander Dale Kessler** | **Duke Hardcastle**, head of operations, named like an action figure and acting like one |
| Bunsen Burners MC | **President "Deacon"** (Wade Cutler) | **Vice President "Choirboy"**, whose real name nobody says aloud; the officers' road names are all churchly |
| The Corporation | **Gordon Pryce**, GRUB DRILL's CEO and Senate candidate (Director, 2026-10-23): his name is the share price, which his books inflate | **Evelyn Marsh**, leader of the board's minority bloc, who wants his chair and sells the company once he is dead |

**The rest of the cast:** the Agent **Victor Rook** by default ("Victor", the winner; a rook moves straight on a grid, and "to rook" is to cheat);
his wife **Claire Rook**; his son **Leo Rook**; the reporter **Thomas Marlow**; Marsh's counsel **Prudence Vane**
(prudent in name only, a weathervane that turns with the wind; the Corporation's sub-leader until 2026-10-23, when the CEO became the leader); the default town for a player who gives no city, **Lowmere** (not yet web-checked). **Ratified (§2.2):** the deposition at the police
station is the character creation; the player names the Agent there, and the TV report of the epilogue reads that name.

**The creator's limits (Claude, proposed):** it shapes LOOKS only; the figure on the board keeps one gameplay size (a cosmetic never changes the game,
`ACTOR_MASTER_PLAN` D36, `COSMETICS_MASTER_PLAN` C3). Height is a narrow cosmetic scale, never the hitbox or a cover rule; eye and skin colour are
shader uniforms (free); the face is the hero's blend shapes (`ACTOR` D75); hair and beard are the hero's CC0 pieces. Each of a player's four
characters has his own deposition.

**The Agent may be a woman (Director, 2026-10-22).** The spouse then becomes a husband, and the lines adapt. **Wherever this document says "his
wife", read "the Agent's spouse"**; the son, the debt, the spouse's fate (§2.6) and every beat stay the same. Defaults (Claude, proposed): the
Agent **Victoria Rook**, her husband **Clement Rook** (Claire's counterpart; a clementine is one more orange). **Consequences (Claude):** every line
that names the Agent or the spouse is written in two genders for the gendered languages (Portuguese, Spanish, French...: a `tr()` key per variant,
`LOCALIZATION_REFERENCE`); the female base becomes required, not optional (`COSMETICS` §8.1), and every piece of the Agent's costume must fit
both bases.

**The sub-leaders: optional supports for the narrative (Director, 2026-10-23: they create variability and prevent collisions; sub-missions
exist or not depending on the player's choices).** The successors above are the sub-leaders. The rule (Claude's proposal, ratified 2026-10-23):
**the leader is the one the Agent hunts; the sub-leader speaks for the faction whenever the leader cannot**, because the leader is the target,
because he is dead, or because he is the head of the character's own faction.
- **The handler.** On each route the sub-leader of the faction of his BACKGROUND (§2.2, §15: revised 2026-10-23) is the one who approaches the
  Agent outside the police station and runs him; the approach grants no access (§2.2). He wants the leader's post, so lap 1's chapter 4 (the
  Agent investigating his own leader) serves him, and the leader's death in lap 2 is his coup; the faction stays the character's. Each sub-leader
  leads one route and is an optional support in the other three. For the lifelong policeman it is Barrow, while Graves also runs him in secret,
  neither knowing of the other (§2.2).
- **In lap 1** each one stands beside the leader (seen before it matters, §11.4) and often hands over the favour's details. **In lap 2**, when the
  leader dies, the sub-leader takes the post (each faction outlives its leader, §2.1) and answers for that faction. The sub-leaders blame each
  other for the deaths, and the new orders change the next visits to the same places (new checkpoints: the authored time states of §14.4).
- **The cemetery memorial's "four factions"** are the four sub-leaders before the press, sealing their truce on the leaked Graves–"Deacon" deal
  (§2.2, who takes the blame): all four leave believing the Agent innocent OF THE DAM, a grieving father; only the reporter knows (Director,
  2026-10-23). **Each handler knows a little more and keeps quiet** (ruled 2026-10-23): he blessed the Agent's chapter against his own leader
  and profits from that leader's death, so his post depends on his silence. **In Freelance** they are the clients who pay the "dead"
  Agent for information, none of them knowing who he is: he sells faceless, as he sold to the Militia (§2.6).
- **Sub-missions are leaves, not branches.** They READ the state of the world (the lap-2 order, the run's violence, the badge) and pay in access,
  gear, guard rotations or money. **They never carry a piece of the disaster** (the four failures, the four clues, the reveal: §2.6, §2.4), and no
  beat of the main plot depends on one, so any of them may exist or not without contradicting the plot in any route or order.

**One kind of condition per sub-leader (Claude's examples, ratified 2026-10-23):**

| Sub-leader | Motive | Sub-mission (example) | Exists if |
|---|---|---|---|
| Irene Barrow | Graves's chair | Bug Graves's office (the recording goes to her, never to the Agent) → a forged pass that gets him through checkpoints | **The badge:** only once the Agent has lost it |
| Duke Hardcastle | Command, on camera | A staged heroic rescue so he looks the part (a Militia publicity stunt for the cameras, never the official rescue, which stays scenery: ruled 2026-10-23) → the Militia's drone codes | **The leader alive:** only while Kessler lives |
| "Choirboy" | The club's "brothers" | Spring a cook from a rival chapter → the recipe for an explosive or smoke gadget | **The violence:** gone if the player killed club members in that chapter |
| Evelyn Marsh | Pryce's chair, and the sale: she backs whoever is winning | Sells, through her counsel Prudence Vane, the guard rotations of the Agent's next target | **Progress:** only once two or more leaders are dead |

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

### 5.4 Distractions — throwables and the scenery — `DESIGNED` (Director, 2026-10-23)

**Throwing a stone and running is the game's bread and butter** (Director). Around it:

- **THROWABLES (Director):** the pack holds a LIMITED number at once, restocked at certain places or replaced by similar objects: baseballs,
  glass cups, anything that makes a noise and is easy to handle.
  - **Claude's proposals:** a stack of 3; each lands as a noise at a point, on §5.3's scale.

    | Object | Noise and range | Reuse | Trace |
    |---|---|---|---|
    | stone | 2, medium range | can be picked up again | none in rubble |
    | baseball | 2, it bounces further | can be picked up again | none |
    | glass cup or bottle | 2, breaking glass | single use | leaves SHARDS, evidence that also crunches underfoot |
    | can | 1-2, it rolls | can be picked up again | none |

  - **Restock points** are map affordances (§15): rubble for stones (everywhere in the aftermath, and the destruction engine makes more),
    bars and kitchens for glasses, parks and sports shops for baseballs, bins for cans.
  - The throw reuses the grenade's wall-aware throw line.
- **THE SCENERY (Director, after Dishonored):** distractions in the world itself, so a player with no items always has an alternative.
  Claude's catalogue:
  - **unpowered:** objects to knock over, a door slammed, a valve (steam: the vent exists; water: the liquids engine moves it);
  - **powered:** TVs, radios, ringing phones, car alarms (a stone at a car sets one off: throwables and scenery combine), vending machines,
    a fire alarm (a big pull and a step of alert), and the LIGHTS: switching one off makes shadow and brings a guard to fix it (light is
    tactical, §4.4).
  - Powered devices only work where the power is back: the official work's power station brings districts back (§2.2), so the scenery's
    options grow as the campaign advances.
- **THE UNIVERSAL REMOTE (Director: "uma forma engraçada"):** switches TVs on and off, and radios, so guards go and check.
  **Claude's proposals:** it is the Agent's own TV remote, picked up in the opening at home (the scene with the TV news, §2.2); it works on a
  powered device in line of sight within a few GU.
- **Repetition (Claude, as for the alarm clock, §10.0):**
  - Guards investigate a noise and return. The same trick in the same zone in the same mission makes them SUSPECT a trick: the alert goes up
    instead of a guard simply walking over (guards never forget, §1's anti-patterns).
  - Thrown objects stay where they land: in rubble a stone blends in; in a clean corridor it is evidence (§4.7).
- ⚠️ **Dependency:** none of this works until the noise pipeline is wired. As measured 2026-08-30, `NoiseSystem.emit()` had no caller and
  the noise → detection bonus only counted when the guard already saw the Agent. Planned in `AI_MASTER_PLAN` (planned from the faction
  dress).

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
**Plus the UNIFORM (Director, 2026-10-23):** a pre-mission choice of its own,
one faction's officer coat among those he holds (his armband follows it),
which decides where he can walk unbothered (§2.2, ACCESS); the LED coat
replaces the choice (§10.5).

### 10.0 The starting kit (Director, 2026-10-23)

**He starts with practically nothing; the rest is unlocked along the way.**

| What | Detail |
|---|---|
| A common pistol | The weapon class's tier 1 (§10.2) |
| His overcoat | The FID investigators' mustard coat, black inside (§2.1, `ACTOR` D78) |
| Throwing stones | A distraction (a noise on a chosen tile): the bread and butter, a limited stack restocked in the world or replaced by baseballs, glasses, cans (§5.4) |
| A chokehold or a neck snap | The chokehold knocks a guard out and he **wakes after N turns** (N open, §18); the neck snap kills and he never wakes. The knockout is the non-lethal option every class must hold from the start (§2.6) |
| An ALARM CLOCK | ONE per mission (Director, 2026-10-23): he sets it for N turns, and when it rings it draws several guards to that zone at once, opening him a way. Later upgraded to a battery RADIO-CLOCK playing a "song" of sirens, shots and screams. **Claude's proposals:** the radio-clock draws more guards from further away, but they arrive ALERT (weapons out, searching); it comes from the evidence room (§15) or is bought. **Retrieval (adopted 2026-10-23):** he may go back for the clock, but a guard who reaches it first CONFISCATES it as evidence (knock him out and search him to get it back), re-arming costs 1 AP, and a second ring in the same mission makes the guards suspect a trick: it raises the alert instead of simply drawing them. That keeps one clock from becoming an endless loop |
| A SPRAY CAN | Blinds cameras (Director). **Claude:** a few sprays per can, from the camera's blind side; a blinded camera is EVIDENCE that guards come to check, unlike the Corporation's clean camera loop (§15) |
| CHLOROFORM | Puts BIGGER enemies to sleep, those a chokehold cannot drop (Director): fragile, volatile, one bottle at a time, found in the world. **Claude:** it breaks if he takes a hit or falls; once opened it evaporates within a few turns; it is found in labs, clinics and chemical stores (an affordance tag, §15). It keeps §2.6's non-lethal promise against the heavies (the heavier base, `COSMETICS_MASTER_PLAN` §8.1) |
| A SHORT ROPE AND HOOK | TRAVERSAL only (Director, 2026-10-23): from one AUTHORED anchor to another, over a wall, a fence, a dug channel, a pool of acid. He never stands on anything: he lands on the ground beyond. The rope's length and the anchors are the scene builder's (affordance tags, §15). It doubles as an evasion: a wall the guards must walk around. Costs AP and makes a noise on the throw (numbers open) |
| A balaclava | For the first missions: masked, with the coat stowed in his black pack, he already looks like the Infiltraitor, with no technology. He wears an ordinary fedora; the **mask** (`ACTOR` D71/D77), itself a fedora, is taken soon from the club's hired assassin at an official-work site and replaces it (§2.2) |

**The start kit is the gear of the ATTACK (Director, 2026-10-23):** the "uniform" he wore the night he breached the dam, which is why he
starts with some skills. It is a fair-reveal clue (§2.4): the gear the player has carried since the first mission is the attack's. Claude: the
rope and hook is how he got over the Militia's perimeter wall to launch the drone from inside (its clue, §2.6).

**PERCHES, later (Director, 2026-10-23; Batman Arkham's predator):** a better grapple brings PERCHES: isolated high points AUTHORED by the
scene builder (a roof edge, a water tower, a catwalk).
- What he does there: climbs, watches, swings from perch to perch, and drops onto a passing guard for a knockout.
- **One playable plane still (the canon below holds):** a perch is a cell with a height, never a storey. It never connects to an interior,
  so a roof stays a lighting event and never an access.
- **Seeing him up there is a GAMEPLAY rule:** guards look up only at higher alert, with flashlights, or through drones, as with the revealed
  guards.
- **Counters:** guards who look up and sweep flashlights from a set alert; the Militia's drones; snipers; no perches in highly watched
  zones; few per map; the mask's eye glow betrays a still Agent in the dark (D71).
- **Open:** where the better grapple comes from and when (Claude: lap 2, like the other mid-game tools).

**The start kit is CRUDE, the trees are CLEAN (Claude, 2026-10-23).** The start kit's tools are one-shot and leave traces; the trees give
the clean versions (§15): stones → alarm clock → firework lure; spray → camera loop; chokehold → taser and darts; chloroform → darts and gas.

**Stealth by shadow works 100% from the start** (§4.3): the progression adds tools, never the core loop. The background (§15) adds its own
abilities and the equipment it can operate.

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

### 10.5 The LED coat and the energy system — `DESIGNED` (Director, 2026-10-23)

**The LED coat is a Corporation secret project** (its specialist Hedge wears the prototype, §11.6) that **replaces the common overcoat** once
acquired. It does two things, both electronic:
- **The cloak** (`ACTOR` D72, unchanged): standing still, he fades into the scenery.
- **The wardrobe (new):** the LEDs show the uniform (colours and symbol) of any faction whose uniform he holds, so **from a distance he passes
  for one of that faction's field officers** (§2.1), and with that faction's ACCESS he is not bothered there. **It is a wardrobe, not an
  access** (Director, 2026-10-23): before it he wears one uniform per mission; with it he carries all of them at once.
  **Up close it hides nothing:** at a checkpoint, or in the GU next to an officer, he is recognised as in any coat (his hat, tie and shoes), and
  only his access decides (§2.2, ACCESS). **It is a mid-to-late-game tool on EVERY route** (Director, 2026-10-23: "um acessório muito forte,
  designado pra meio/fim de jogo"; supersedes the same day's "its arrival varies by route"). **It comes from the Corporation's ENVOY**
  (Director, 2026-10-23): Hedge (§11.6) has been WATCHING the Agent on several occasions. Earlier maps carry an easter egg of his presence, a
  glint or a shimmer of the LEDs (§11.4: seen before it matters). The Agent meets him in lap 1's Corporation chapter, where Hedge wears the
  coat against him, and takes it from him in lap 2, as he took the mask from the club's assassin.
  - **Claude's proposals:** the ambush comes at the opening of lap 2 on every route, the one point all routes reach at the same stage; Hedge
    counts as a boss like the assassin (excluded from the violence count); he was sent by Pryce to watch the investigator who could find the
    books, so what he saw dies with Pryce in lap 2; the glints start in the official work.
  - **It does not work in HIGHLY WATCHED ZONES** (Director): there only its cloak hides him; everywhere else the wardrobe stays useful
    (§2.2, ALERT). Its reach grows with him: it shows only the uniforms he holds. He may switch on the fly, but **not too close and never in a guard's sight**.
  With several factions on one map (segments, §14), choosing which uniform to show where is the decision: the Militia's colours near the
  club draw fire.

**It needs energy (Director: a cooldown and an energy and recharge system).** **The battery in the pack is a later UPGRADE that powers both
the mask and the LED coat** (Director, 2026-10-23). Until he gets it, the mask runs on its own small charge (§10.3 already prices X-ray in
charges). With it, the mask's vision (D71's tether at the nape carries the power: Claude's reading, the tether arrives with the upgrade) and the
coat's cloak and symbol draw on one charge, so seeing through walls and hiding compete. When the upgrade comes: open (§18). It recharges slowly per turn and quickly at power points,
which grow as the power station's restoration brings districts back (§2.2; restored light also costs cover, §2.6). The numbers are open (§18).

**Readability (`COSMETICS_MASTER_PLAN` C3):** the symbol he shows is gameplay state, so the HUD always says which uniform he shows and whether he holds that faction's access; a
cosmetic coat still shows the symbol, because the faction's colours and emblem are filled into the coat's accent zones by the game (D78).

---

## 11. Enemies — `PARTIAL`

One guard archetype ships. Everything below the hierarchy is design only.

### 11.1 Three factions
> **2026-10-22:** the enemy factions are the FOUR of §2.1: the Federal Police (a fictional agency), the Militia (a private military security company),
> the Traffickers (a motorcycle club) and the Corporation (GRUB DRILL's executives). The three play styles below were written for the older roster
> (where the Corporation flew the drones; in §2.1 the Militia does); the mapping and the fourth faction's counter are open (§18). **The same four are
> also the player's classes (§15):** any class plays against any faction, so a counter is a style the class meets, never a lock.
> **2026-10-23:** each faction also fields specialists who author its technology (§11.6), whose template proposes the four-faction counters.

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

**Rank names per faction (2026-10-22, English canon; civil ranks, never military; localised per country later):**

| Tier | FID | Calm Waters Security | Bunsen Burners MC | The Corporation |
|---|---|---|---|---|
| Recruit | Cadet | Contractor | Hang-around | Staffer |
| Standard | Agent | Operator | Prospect | Operative |
| Veteran | Senior Agent | Senior Operator | Patch | Senior Operative |
| Lieutenant | Inspector | Team Leader | Road Captain | Case Manager |
| Captain | Chief Inspector | Site Commander | Sergeant-at-Arms | Head of Security |
| Leader / successor | Commissioner / Deputy Commissioner | Commander / Head of Operations | President / Vice President | CEO / Bloc leader |

The Agent's own rank is **Inspector**.

**Field officers (Director, 2026-10-23):** Lieutenant and above lead the soldiers in ordinary missions and wear an **overcoat** in their faction's
colours and symbol (§2.1); the sub-leaders are the most senior field officers, with distinctions. This is the uniform the Agent can steal,
find or earn, and that the LED coat imitates (§2.2, §10.5). **Officers are also the ones who see through it:** in the GU next to an officer,
as at a checkpoint, the Agent is recognised whatever coat he wears (Director, 2026-10-23; §2.2, ACCESS).
Below them the factions vary freely: henchmen, super-henchmen and sub-henchmen of any look, as long as they stay complementary and of
equivalent power across the four factions.

### 11.3 The five point/counterpoint techniques
Every agent power gets an enemy mirror (the Phoenix Point lesson). *(2026-10-22: the "Introduced by" column names the older roster and its fixed
chapter order; with four routes a counter is introduced by lap POSITION, not by faction, and §11.4's telegraph rule counts positions too.)*

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

### 11.5 Named rivals — a pool of sub-enemies (CONSIDERED, Director 2026-10-22; nothing ratified)
*(Director: "um pool de sub-inimigos" and a system like Shadow of Mordor / War's nemesis, "não precisa ser exatamente igual, mas bosses difíceis
dão essa sensação de prazer em vencer. Considerar.")*

⚠️ **A patent stands in the way of a copy.** Warner Bros. holds US 10,926,179, *"Nemesis characters, nemesis forts, social vendettas and followers
in computer games"* (granted 2021; reported to run to 2036-08-11, if its fees are paid). Its claim 1, as law-firm coverage summarises it, is broad: a
player avatar and an NPC whose parameters change with their interactions. **Before any design goes past this note: an IP lawyer's opinion,** and the
system grows from this document's own rules, never from Mordor's structure or its name.

What the canon already holds to grow it from (Claude, proposed):
- **The pool sits under §11.2's ranks.** Each faction has named Lieutenants and Captains; the four successors of §2.7 are the campaign's authored
  tip of it. In Freelance the pool is procedural and endless (§1, §19 Rule 3): names and motives from the narrative layer (§2.5, Rule 2), looks
  from the cosmetics pieces and palettes (`COSMETICS` §8: one skeleton, so variety is cheap).
- **A rival's memory is §11.3's counterpoint, personalised.** The rival who lost to smoke comes back with a respirator; the one beaten by a
  suppressed pistol carries a suppressor detector. The counters are already designed; they now belong to one named enemy, and §11.4 still
  applies (the player sees the new gear before it matters).
- **A rival's weakness is information.** His traits are hidden and learned through intel (the Informant, §15; documents; eavesdropping), the
  game's primary resource (§1).
- **Non-lethal feeds it.** A rival knocked out survives and comes back; a rival killed is replaced by his successor (§2.7). It meets the violence
  rule (§2.6): the pacifist's enemies return, the killer's are replaced.
- **Cost:** persistent per-character state across missions (the save model is checkpoint-scoped today), barks as localised text (no voice),
  portraits in the variable panel (§19 Rule 6).

### 11.6 Specialists — the authors of technology — `DESIGNED` (Director, 2026-10-23; the roster is Claude's proposal)

**The rule (Director):** each faction gets about three more unique members. **Each unique enemy is the AUTHOR of one attack, technology or
skill;** the first confrontation puts that element on the Agent's radar, and contact with it unlocks the chance to acquire it for himself.
Enemies and the Agent evolve together, as in Phoenix Point's research tree (or StarCraft's). Since lap 1's chapters are played on the
investigated faction's turf (§2.2), a route meets the specialists in its own order, so each route grows its arsenal in a different order.

**Constraints (Claude, from the canon):**
- **No unlock needs a kill:** observing it with the mask, surviving it, or knocking its author out and searching him all count; otherwise the
  tree pushes the player toward the sad ending (§2.6).
- **The kamikaze drone is never an unlock:** it is the murder weapon and the club's signature (§2.6). The Militia's drone is a scout.
- **No acid weapon:** the flood was acid, and the tragedy is never played light (§2.6). The club's chemist works in gas and sedatives.
- **The specialists are authored, fixed characters:** the evolution is the FACTION's (its tech tree), never a memory per NPC, which keeps the
  design clear of US 10,926,179 (§11.5) until an IP opinion.
- **Telegraphed** (§11.4): a specialist is seen before he matters, and his element is shown before it bites.
- **A class's non-lethal option exists from the start** (§10.0); unlocks add, never replace.

**The template (Claude, proposed): the same three roles in every faction, so the power stays equivalent and the flavour differs.** EYE =
finds the Agent a new way; HAND = attacks a new way; WALL = closes routes. The names follow each faction's joke (§2.7).

| Faction | EYE | HAND | WALL |
|---|---|---|---|
| **FID** (burial names) | **Cairn**, the K9 handler (a cairn terrier, and a burial mound): the dog follows trails (§4.7) → a scent masker | **Pyre**, the taser officer → a taser (non-lethal) | **Vault**, the dispatcher: radio check-ins, roadblocks → faking radio calls |
| **Calm Waters** (action-figure names) | **Ace Skyler**, the drone pilot → a scout drone | **Rex Hawke**, the marksman → a sniper rifle | **Chip Voltz**, sensors, laser tripwires → a jammer |
| **Bunsen Burners** (churchly road names) | **Vespers**, the lookout with fireworks that alert the whole segment → flares that lure guards | **Censer**, the chemist: gas and sedatives → **tranquilliser darts** and smoke (the recipe of "Choirboy"'s sub-mission, §2.7) | **Sexton**, booby traps on the routes → breaching charges |
| **Corporation** (finance puns) | **Ledger**, the hacker of cameras and phones → camera loops | **Hedge**, the agent in the LED prototype (a hedge fund, and D72's bush): an ambush from invisibility → **the LED coat** (§10.5) | **Escrow**, the fixer: a price on the intruder's head, bribes → bribery as an inside access (§2.2) |

This template also answers §11.1's missing fourth counter: every faction meets the Agent on the same three axes. **Hedge is the
Corporation's envoy who watches the Agent across maps** (glints of his LEDs as easter eggs) and gives up the LED coat in lap 2 (§10.5).

**Faction stores, gated by ACCESS (Director, 2026-10-23).** More gadgets come from the police's EVIDENCE ROOM and from the Militia: a
high-tech weapon, and possibly super-silent shoes. With a faction's access the Agent draws from its store; without it, the store is an
infiltration target. The specific items and the two other stores (for an equal power per faction) are Claude's proposal.

| Faction | Store | Items |
|---|---|---|
| FID | the **evidence room** at the police station (seized gear) | lockpicks (silent doors); a suppressor for the common pistol; **zip ties**, so a knocked-out guard stays down (the non-lethal path's partner); a phone cloner (a guard's phone shows his rounds). After the badge is lost, it takes Barrow's forged pass or an infiltration |
| Calm Waters | the **armoury** at GRUB DRILL's complex | a **pulse carbine**, a high-tech weapon that stuns at range (non-lethal); **silent boots** with acoustic soles: walking and running make less noise (§5) |
| Bunsen Burners | the **lab** and the chop shop | the cook's recipes: darts, smoke ("Choirboy"'s sub-mission, §2.7) |
| Corporation | the **R&D floor** | prototypes: camera-loop rigs, and the LED coat's later upgrades |

The items sit in §10's classes: the pulse carbine and the suppressor in the weapon class (§10.2), the silent boots in the armour class
(§10.1), the rest as gadgets (§10.4).

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

**Every mission is a way of infiltrating (Director, 2026-10-22):** gathering
evidence, talking to people, planting bugs, acting on the world (opening a
sluice gate, draining a tank). The official missions and the investigations
alike (§2.2). *(Claude: the liquids engine already re-reads a body's walls when
the world changes (`FluidContainer`, M6), so a gate opened or a tank breached
can move water; no interactable for it exists yet.)*

### 14.3 The MVP — three focused chapters
> ⚠️ **2026-10-22: written for the older three-faction, three-chapter campaign.** The campaign is now four factions in two laps (§2.2, §2.6), played
> from four starting factions (four routes, §15), so each faction's chapter must teach its mechanic without depending on the others', and difficulty
> scales by the chapter's POSITION in the lap, not by its faction. **Routes per style (Director, 2026-10-22):** the class difference matters most at
> the START of the campaign, where having or lacking a power makes the player adopt a different style through the SAME scenarios, so every mission needs
> a stealth route, a brawl route and so on, possibly one per segment of the 3×3 grid (§14.1). The kit / enemy / lesson ladder below is still the intent
> per faction; its re-mapping to four factions is open (§18).

| Chapter | Setting | Agent kit | Enemies | Mechanic taught | Lesson |
|---|---|---|---|---|---|
| **1 — The Agency** | Corporate HQ | Civilian clothes, knife, normal vision, 1 gadget | Recruit, radio guard, simple camera | Vision cones + shadows | Understand detection |
| **2 — The Militia** | Industrial site | Light vest, suppressed pistol, binoculars, 2 gadgets | Armoured guard, paired patrol, lieutenant | Noise + cover | Silence has a cost; confrontation has rules |
| **3 — The Corporation** | Laboratory | Modular armour, shock weapon, night vision, 2 gadgets | Drone, AI camera, high-tech guard | Electronics + automation | No solution is universal |

### 14.4 The same places over time — the aftermath (Director, 2026-10-22)
After the police station the campaign plays in the devastated region (§2.2, THE AFTERMATH): the rescue heard of more than seen (police vehicles,
cordons, hoardings, closed zones), the rest of the town held by the factions for lack of authorities, looters, the curfew, the acid on the ground.
**The campaign's places come back as time passes, with small modifications that change their look and their play** (Deus Ex's revisited hubs),
and the restored town of the cemetery finale is the last state of the same place.

- **The time states are AUTHORED and belong to the campaign only (Director).** Each is a hand-made map. In Freelance the same places, though
  similar, are played at any time and in any order.
- **What changes during a mission is the engine's (Director):** a fire lit, a pane broken, lights switched on or off (built: destruction, fire,
  glass; runtime light switching for fire, `LightingController.rebuild_tactical()`). ⚠️ **A nightfall is not built:** no time-of-day or ambient
  change exists in the code (searched 2026-10-22); it belongs to the light milestone (`VOXEL_LIGHT_MASTER_PLAN` §LE, the light engine parked
  2026-10-18 until that milestone).
- *(Superseded 2026-10-22: Claude's "public bodies' uniforms as disguises" and "the rescue is never a battlefield": the rescue is scenery, not
  play; and the "same map over time" engine mechanism: the time states are authored maps.)*

---

## 15. Progression — `DESIGNED`

**Four characters, one per BACKGROUND — the classes (Director, 2026-10-22;
revised 2026-10-23).** A player has at most four characters, like Diablo's
separate classes. Each is an instance of the Agent, always an FID inspector by
trade; **the class is the past he states in the deposition** (§2.2): where he
grew up and what he can do. That past gives him unique abilities and the
equipment he can operate, and it is what the rankings show:

| Background | Faction in the rankings and the league | His handler (§2.7) |
|---|---|---|
| A policeman all his life | the FID | Irene Barrow |
| A former member of a motorcycle club | the Bunsen Burners MC | "Choirboy" |
| An army veteran | Calm Waters Security (it hires veterans) | Duke Hardcastle |
| A former private security guard | the Corporation (its private agents) | Evelyn Marsh |

*(The mapping and the handlers are Claude's, under the Director's delegation.)* The character plays the campaign from his faction's start
of the circle (four story routes); his faction never changes. **Being approached by that faction grants no access** (§2.2): every
character starts with the police's common facilities only, and the background's faction is earned like the others. Each character levels on
its own, by the player's dedication, and carries its own ending and tattoo (§2.2). The detailed kits are gameplay work still to do (§18).
- **A class restricts some abilities and equipment early.** That is the replay
  value: the same player replays the campaign from another background to play it
  another way. The START of the campaign is where it matters most (§14.3:
  routes per style through the same scenarios).
- **The endgame converges:** a mature character has unlocked every technology
  in the game; what stays his are a few special abilities or pieces of
  equipment unique to his faction.
- **Equivalent power, different style:** any class plays any mission against
  any faction, and the mission is completed either way, by stealth or by
  shooting; tired of the sniper, the player picks up the melee one.
- **Open:** the four kits (which abilities and equipment each class lacks or
  owns: §10 was written for one Agent); whether a second, third and fourth
  character replays the whole campaign; how this meets §11.1's counters.
  **Constraint (ratified 2026-10-22, §2.6):** every kit holds a non-lethal option from
  the start, since the campaign's ending turns on the run's violence.

*(Superseded 2026-10-21/22: the Elite prologue, whose temporary senior loadout
previewed the destination; the game opens at home, §2.2.)* The mature powers
must expand tactical possibility rather than turn the final game into a solved
map.

**Item sources:** the threats he meets (each specialist's technology becomes acquirable once he has met it,
§11.6), chests on the map, NPC vendors, mission rewards, and
[future] a TF2-style player market.

**Neutral missions (Director, 2026-10-23; §2.2, BETWEEN THE LAPS):** between the laps, missions in the manner of Freelance let the player
raise a skill he is weak in or get better equipment; each kind of objective pays its own dividends.

**The tech and skill tree (Director, 2026-10-23: structure ratified, "podemos fechar assim").** Diagram:
`DIAGRAMS/ARVORE_TECNOLOGICA.png` (generator `tools/asset_generation/tech_tree_poster.py`, whose node data mirrors this list). It
REDISTRIBUTES §10's catalogue (and the 2026-10-23 additions) by faction and author; it is not a parallel system.

**Structure:**
- Per faction, THREE BRANCHES: EYE (detect, giving mask modules and intel), HAND (the faction's threat, giving weapons) and WALL (control,
  giving gadgets and armour).
- THREE LEVELS:
  - L1, lap 1: the specialist met on that turf (§11.6);
  - L2, lap 2: the faction's store with access, or the envoy;
  - L3, Freelance: research; the endgame converges.
- Each node carries its author, its §10 class, lethal or not, and its enemy counter.
- **Unlocking** means meeting the author: seeing the technique used, surviving it, or knocking its author out and searching him. Never a kill.
  The stores need access.
- **§10.3's visors become MASK MODULES:** the mask arrives with night vision, and its other modes are nodes, including D71's thermal and X-ray.

| Faction | EYE (L1 → L2 → L3) | HAND (L1 → L2 → L3) | WALL (L1 → L2 → L3) |
|---|---|---|---|
| FID | trail reading (Cairn) → predictive (evidence room) → tactical analysis | taser (Pyre) → suppressor (evidence room, lethal) → sonic weapon | radio spoof (Vault) → lockpicks + zip ties (evidence room) → radio scrambler |
| Calm Waters | scout drone (Ace Skyler) → thermal (armoury) → X-ray | suppressed rifle (Rex Hawke, lethal) → pulse carbine (armoury) → laser (lethal) | EMP charge (Chip Voltz) → silent boots + vest (armoury) → exoskeleton |
| Bunsen Burners | firework lure (Vespers) → motion vision (chop shop) → street eyes (lookouts) | dart launcher (Censer) → gas + smoke (lab; also "Choirboy"'s sub-mission) → incendiary (lethal) | tripwire flash (Sexton) → getaway bike (chop shop) → breaching charge (lethal) |
| Corporation | camera loop (Ledger) → WiFi vision (R&D floor) → spectral | shadow generator (Hedge, seen) → LED coat (Hedge, lap 2; §10.1's adaptive skin) → plasma (lethal) | bribe (Escrow) → forged credentials (Escrow / R&D) → master keycard |

**The enemy side (Phoenix Point):**
- Every node has a counter, shown on the diagram: insulated vests against the taser, respirators against the darts, analogue comms against the
  radio spoof, highly watched zones against the LED coat, and the rest. §11.3's five pairs are among them.
- The factions field a counter in the NEXT stage, the Agent's most-used technique first, always telegraphed (§11.4).
- A counter weakens a technique, never nullifies it.

**Every character shares:** the start kit (§10.0) → the hat-mask (official work) → the pack battery (an upgrade; when: open) → the LED coat
(lap 2).

**Backgrounds** (§2.2): the player picks ONE of his own faction's three L1 nodes at the deposition (he knows that world; it offsets his own
chapter coming last in lap 1; the balance pass below), plus one passive and one active ability:

| Background | Passive | Active |
|---|---|---|
| Lifelong policeman (FID) | Procedure: sees each radio guard's check-in countdown | Interrogate: a knocked-out guard gives one piece of intel |
| Army veteran (Calm Waters) | Discipline: armour's stealth penalty one step lower | Suppressing fire: pins a guard in cover for a turn, no hit |
| Former biker (Bunsen Burners) | Road sense: +1 GU sprinting on open ground | Improvise: one smoke or flash per mission, from scrap |
| Former private security (Corporation) | Systems: sees camera cones and blind spots | Keycard spoof: opens one electronic door per mission |

**Balance pass (Claude, 2026-10-23; ADOPTED by the Director the same day; the numbers wait for playtests).**

*Too strong:*
- **Forged credentials** grant ACCESS, the core progression, so unbounded they skip it. Rule: one faction for one mission, bought, and
  checkpoints can verify them (their counter).
- **The comms stack** (radio spoof + scrambler + camera loop + EMP) could silence a whole map and empty the CAUGHT rule. Rule: each keeps
  §10.4's charges, and reinforcements also come by noise and sight, never by radio alone.
- **The getaway bike** could make every escape trivial. Rule: an EXTRACTION, not a teleport: it waits only at marked points or segment
  exits, it is loud (alert up), and roadblocks stop it.
- **The shadow generator** is a tier-6 gadget (§10.4) at L1, and shadow is the core of stealth. Rule: L1 is one charge for two turns, and
  §10.4's full version comes at L3.
- **The exoskeleton** has no stealth penalty (§10.1: powered). Rule: it draws on the pack battery, competing with the mask and the LED coat.
- **Interrogate and the bribe** become universal keys if unlimited. Rule: actives have charges per mission, captains cannot be bought,
  and a bribed guard may talk later.

*Too weak:*
- **Trail reading** overlaps "predictive". Rule: it shows the Agent HIS OWN trail as the guards read it (§4.7, evidence detection), so he
  can break it, which pairs with the dogs.
- **The firework lure** overlaps the start kit's stones. Rule: it pulls every guard in a radius, at the cost of a step of alert.
- **The veteran's Discipline** is empty early, when he has no armour. Rule: it also covers the pack's noise.

*Start parity:*
- With every own-L1 node open, the biker starts with silent ranged knockouts (the darts) while the private-security character starts with no
  attack at all. Rule: at the deposition, the player picks ONE of his faction's three L1 nodes, and the other two are met as usual. That
  adds a real choice at creation and evens the start.

**What the levels must offer (Claude; adopted 2026-10-23; feeds `MAP_MASTER_PLAN` and the generator, §2.5):**
- **Every obstacle is solvable by the start kit or by at least two branches**, as the canon's multiple-solutions rule asks. Deliberately
  impossible rooms (below) gate only optional rewards behind one technique.
- **The official work and the first chapter** are solvable with the start kit alone: shadows, stones, chokeholds, open doors, few cameras,
  lone guards, no radio guards yet (radio comes at Lieutenant, §11.2).
- **Each lap-1 chapter brings its faction's systems**, met first in a safe spot (§11.4):
  - the FID: dogs, check-ins, checkpoints;
  - Calm Waters: drones, sensors, snipers, armoured pairs;
  - the Bunsen Burners: firework lookouts, traps, chemical labs, bikes on the routes;
  - the Corporation: camera nets, electronic doors, agents in the shadows.
- **Lap 2 and Freelance layer the systems** in multi-faction segments, with the counters in the field and highly watched zones.
- **Maps carry AFFORDANCE TAGS**, so a technique always has a target and the generator can place them. Data, in the map's `layout` section
  (`CAPTURE_RAILS` already gives it POIs and regions):
  - power points (battery recharge) and the faction stores;
  - throwable restock points and scenery distractions, powered or not (§5.4);
  - grapple ANCHORS (traversal pairs) and PERCHES (§10.0);
  - highly watched zones (no uniform, no LED coat) and checkpoints;
  - locked and electronic doors, camera nets, radio relays;
  - dark zones (the mask's eye-glow trade-off) and thin walls (thermal, X-ray);
  - open ground (the bike, Road sense) and extraction points.

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
paid random rewards, or make an online service necessary to enjoy the core
game.

**Audience — 16+ (Director, 2026-10-22: "O jogo assume 16 anos").** The §2.6
narrative (a policeman who causes a mass-casualty disaster, drug production,
dumped bodies, militias, a child's death) targets the **16 bracket** (ClassInd
16, PEGI 16; the US ESRB has no 16, so there it is likely M, 17+). Each store's
questionnaire (IARC on Google Play) decides the final rating per region. To
stay at 16: violence without gratuitous gore, the child's death off-screen
(the opening already gives it by phone), drugs never glamorised, no sexual
content; anything beyond pushes the game to 18 and is out of scope. **Players
of 16 and 17 are still minors**, which shapes every social and data rule below.

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
| Random rewards | **No purchased loot boxes, at any age rating:** a company rule (and a regulated mechanic in several countries), not a consequence of the audience. The status of play-earned random reward boxes is separate and not yet decided. |
| FOMO boundary | No punitive streaks, artificial energy, expiring paid passes, fabricated urgency or content removed merely to force a purchase. |
| Social surface (16+; defaults set by Claude on the Director's ruling of 2026-10-22, open to change) | Missions stay short and individual; players meet in a lobby, the weekly war (`COSMETICS_MASTER_PLAN` §4) and the world map (§6 there). **An age gate at account creation** (a declared birth date): under 16, the game plays offline and the online and social features stay off. **Communication at launch: presence, emotes and predefined phrases only;** free text comes later and only with moderation in place (filters, reports, human review); **no private messages between strangers**; report and block from day one. **Profiles:** nicknames (filtered), avatars and tiers, never a real name, and a city only as part of a region's aggregate. **Ads:** rewarded only (above), and no profiling-based ads to users under 18 (the EU's rule for platforms). **Purchases:** the stores' family and parental controls apply; nothing is sold through urgency (the FOMO boundary). No PvP is planned initially. **The league and the forum (Director, 2026-10-22):** many simultaneous leagues of up to 4 x 30 characters, bots shown as bots, prizes to humans only (`COSMETICS_MASTER_PLAN` §4); a rudimentary forum moderated by the community itself, through privileges earned by participation (the Stack Overflow mechanism). The forum is free text, so it ships under the free-text rule above: community moderation is the reports-and-review layer, and it still needs automatic filters and an escalation path to staff before it opens to 16-17-year-olds (Claude; `LAUNCH_MASTER_PLAN` L7). |

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
- ✅ **Does the game end?** → **No.** The campaign is prehistory (§2.2);
  Freelance is infinite.
- ✅ **Who knows the Agent is the villain?** → **The Agent knows his own act
  from the beginning (not the four factions' shares); the player does not.**
  He performs the hero throughout the campaign and is exposed at the finale by
  the reporter, who has put the pieces together (§2.2, §2.4).
- ✅ **The Agent's moral boundary** → **for money (a bet against the company)
  he attacked a dam meaning a small spill, not knowing it would kill**; with
  the four factions' failures it killed hundreds, his son among them, and his
  wife too if his own violence in the campaign drains the hospital (Director,
  2026-10-21/22; §2.6).
- ✅ **The character creation** → the deposition at the police station: the
  camera's light comes on and the player describes the Agent (name, height,
  eyes...), Fallout 3's model; the Agent may be a woman, her spouse a husband,
  the lines adapting (Director, 2026-10-22; §2.2, §2.7).
- ✅ **The names** → the FID, The Sieve, Calm Waters Security, the Bunsen
  Burners MC, Pith & Peel Holdings, Carrion Capital; the four leaders and the
  four successors who take their posts; civil rank names per faction
  (Director, 2026-10-22; §2.7, §11.2).
- ✅ **The wife's fate** → she survives by default; a run that kills too many
  people leaves the hospital short and she dies; classes stay equivalent
  (Director, 2026-10-22; §2.6).
- ✅ **The family, the aftermath and the official work** → no baby; the flood
  is acid, not mud; after the station the commissioner (the police chief, the
  lap-2 leader) bars him from the case
  verbally (the badge goes later, in the lap-1 chapter that investigates the
  police over the pit; checkpoints then stop him) and hands him official
  missions (the power station among them) that come
  first, in the player's order, all of them infiltration; the aftermath is the
  campaign's backdrop, its time states authored maps (Director, 2026-10-22;
  §2.2, §2.6, §14.4).
- ✅ **The inciting event and the factions** → four factions around GRUB
  DRILL INC, each guilty of one failure that turned the Agent's small attack
  into a massacre and innocent of the attack itself; the player picks the
  recruiting faction at the police station; two laps around a circle of
  favours (Director, 2026-10-22; §2.1, §2.2, §2.6).
- ✅ **The finale and the player's agency after the reveal** → a scene, no
  fight: at a public memorial in the cemetery the Agent lets slip what only
  the attacker could know; walking away, the reporter (a fifth element,
  innocent of the massacre) draws a gun and exposes him in the rain; a
  standoff; the player KILLS the reporter (discovered: a fugitive) or LETS
  HIM LIVE (the Agent hands him his own gun and turns his back: a fugitive
  too); in every scenario he then fakes his own death; a permanent tattoo marks the choice on that character (Director,
  2026-10-22; §2.2).
- ✅ **The Agent's endgame** → he fakes his own death in every scenario (his
  belongings and his DNA thrown into the acid of the pit; a TV report
  confirms it; the camera pulls back to him watching his wife, if she lived,
  then he disappears) and, dead to the world, goes on infiltrating and
  charging for information: Freelance (Director, 2026-10-22; §2.2).
- ✅ **The violence threshold** → the run kills, on average, more than 50% of
  the enemies (bosses excluded): the sad ending (Director, 2026-10-22; §2.6).
- ✅ **The sub-leaders and the circle per route** → the leader is hunted, the
  sub-leader speaks for the faction when the leader cannot; the own faction's
  sub-leader is the handler (Barrow on the Police route); a lap-1 chapter is
  played on the investigated faction's turf, so chapter 4 is always the own
  faction; the Agent sells to the Militia faceless; both "leak" favours get the
  same lie (a policeman killed in the flood); sub-missions are leaves, one kind
  of condition per sub-leader (Director, 2026-10-23; §2.2, §2.6, §2.7).
- ✅ **The Corporation's leader** → the CEO, Gordon Pryce: head of the
  Corporation and paymaster of the Militia on paper, of nobody in practice
  (his books are cooked: future energy sales booked as cash; the Militia is
  paid late); he buried the engineers' report and the board's bloc kept quiet;
  Evelyn Marsh is the sub-leader, Prudence Vane her counsel; he dies a
  candidate in lap 2 (Director, 2026-10-23; §2.1, §2.6, §2.7).
- ✅ **Who the player is** → up to four characters, one per BACKGROUND stated
  in the deposition (a lifelong policeman, a former biker, an army veteran, a
  former private security guard), each an instance of the Agent and an FID
  inspector by trade: four story routes, classes of equivalent power and
  different style; the background's faction is the one in the rankings
  (Director, 2026-10-22; background revised 2026-10-23; §15).
- ✅ **The dress code and access** → every faction's field officers wear
  overcoats; the Agent is an FID one in the investigators' mustard coat; he
  starts with the police's common facilities only and almost no gear (§10.0);
  the UNIFORM (easy: stolen, found, earned; passes from afar) and the ACCESS
  (a leader's trust or an inside mechanism) are separate; with access and the
  right uniform he is not bothered, in any other dress he is a target; up
  close (a checkpoint, the GU next to an officer) he is always recognised,
  and access lets him on while WANTED means arrest or death; one uniform per
  mission until the LED coat (the Corporation's secret project), which
  carries them all, on an energy budget (Director, 2026-10-23; §2.1, §2.2,
  §10.5).
- ✅ **Specialists** → about three unique enemies per faction, each the author
  of a technology the Agent can acquire after meeting it; enemies and the Agent
  evolve together (Director, 2026-10-23; the roster in §11.6 is a proposal).
- ✅ **Who takes the blame** → every sub-leader ends believing the Agent
  innocent; the leaked Graves–"Deacon" deal carries it, built from lap 1's
  favours and the Agent's own lie (Claude, under the Director's delegation,
  2026-10-23; §2.2). **The police from inside** → Graves runs him off the
  books in every route; Barrow runs him too on the policeman's background;
  neither knows of the other (same delegation; §2.2).
- ✅ **The tech and skill tree** → three branches (EYE / HAND / WALL) x three levels (lap 1 specialist, lap 2 store or envoy, Freelance
  research) per faction, redistributing §10's catalogue by author; every node has an enemy counter; §10.3's visors become mask modules;
  backgrounds pick one of their own L1 nodes at the deposition and add a passive and an active; Claude's balance pass and level
  affordances adopted (Director, 2026-10-23; §15, `DIAGRAMS/ARVORE_TECNOLOGICA.png`).
- ✅ **The start kit grows** → an alarm clock (one per mission, set for N turns, draws several guards; later a battery radio-clock with
  sirens, shots and screams), a spray can for cameras, and chloroform for the heavies (fragile, volatile, one bottle, found in the world)
  (Director, 2026-10-23; §10.0).
- ✅ **Distractions** → throwing a stone and running is the bread and butter; a limited stack of throwables, restocked in the world or
  swapped for baseballs, glasses or cans; distractions in the scenery itself (Dishonored); a universal remote that switches TVs on and off;
  the alarm clock may be fetched back, under the confiscation and suspicion rule (Director, 2026-10-23; §5.4, §10.0).
- ✅ **The rope and hook, in two stages** → a short rope in the start kit for traversals between authored anchors (over a wall, a
  channel, acid; an evasion), then perches like Batman Arkham's predator, with their counters; still one playable plane. **The start kit is
  the attack's gear**, a fair-reveal clue (Director, 2026-10-23; §10.0, §2.4).
- ✅ **Caught, masked, alert** → caught breaking conduct, he is WANTED in that
  scenario and must silence the witnesses (killing, a knockout or a dart) and
  escape; the objective may wait, but the alert rises and the mission stays
  open; a death or an arrest is game over, back to the map to repeat the
  mission or pick another. Seen masked, he is taken for the
  club's assassin still alive, which deflects suspicion. Highly watched zones
  accept no uniform and no LED coat, only hiding. The LED coat comes from the
  Corporation's envoy who has been watching him, with glints as easter eggs
  in earlier maps. The failure screen tells the fate by faction. Faction stores: the police's evidence room, and the
  Militia's high-tech weapon and silent boots. A death or an arrest is game
  over: back to the map, to repeat the mission or choose another. Neutral
  missions between the laps, in the manner of Freelance, raise weak skills
  and buy gear, their objectives paying dividends, and their kills count in
  the violence average, so playing them clean is a valid redemption
  (Director, 2026-10-23; §2.2,
  §10.5, §11.6).
- ✅ **The plot pass of 2026-10-23** (Director, on Claude's recommendations):
  the truth stays buried even if the reporter lives and publishes (a
  conspiracy theory against the truce and the faked death, §2.2); the puts
  paid into Pith & Peel's account in the dead colleague's name, untouchable
  for the living Agent, a second motive for the faked death (§2.6); he starts
  in an ordinary fedora and takes the hat-mask early, from the club's hired
  assassin at an official-work site (§2.2; the assassin and the pack battery as
  a later upgrade: Director, later the same day);
  "innocent" means of the dam, and each handler keeps his complicity quiet
  (§2.7); Hardcastle's rescue is a publicity stunt, never the official rescue
  (§2.7); the Corporation has no weapons IN PUBLIC (§2.6); the LED coat is a
  mid-to-late-game tool on every route, met in lap 1 (Hedge) and acquired in
  lap 2 (§10.5; the Director revised the same day's "varies by route").
- ✅ **Premium campaign or shared campaign?** → **Shared.** Free and paying
  players can reach the same campaign, Freelance content and powers; payment
  accelerates progression (§16).
- ✅ **Purchased loot boxes?** → **No**, at any age rating (§16).
- ✅ **The age rating** → **16** (Director, 2026-10-22); 16-17-year-olds are
  minors, and §16 sets the social defaults for them.

**Still open — do not decide these unilaterally:**
- [ ] From 2026-10-23: the chokehold's N turns (§10.0); which official-work
  site the club's assassin has infiltrated, his name ("the Confessor",
  proposed) and whether he counts as a boss (§2.2, proposed); when the pack
  battery upgrade comes (§10.5); the energy budget's numbers and recharge
  (§10.5); where the radio-clock comes from and chloroform's numbers (§10.0, proposed); the rope's length, AP and noise, and where and when the perch grapple comes (§10.0); the throwables' stack size and noises, the scenery catalogue,
  and the universal remote's source and range (§5.4, proposed); the rules of conduct whose breach makes a faction WANT him, how the
  alert's rise is authored and how much each step weighs (Claude's reading:
  more high-security zones per leader's death and per incident), (§2.2, CAUGHT / ALERT); how
  close counts as "from afar" for a uniform (§2.2); the neutral missions'
  kinds of objective and dividends (§2.2 BETWEEN THE LAPS, proposed); Hedge's ambush point and
  sender (§10.5, proposed); the faction stores' items (§11.6, proposed); the specialist
  roster and its template (§11.6, proposed); the four backgrounds' abilities
  and equipment (§15); the four trips abroad (§2.6, proposed: one per lap-1
  chapter, a member abroad per faction); the palette's exact values and roles
  (the families are the Director's, `COSMETICS_MASTER_PLAN` §9.4).
- [ ] §11.1's counters for FOUR factions (they were written for three; §11.6's
  template proposes them); the
  agency's ranks per country when localised (the English canon is §2.7, §11.2).
- [ ] The four class kits (§15), and whether later characters replay the
  whole campaign.
- [ ] What the reporter does with the Agent's gun in the let-him-live
  branch (§2.2; whatever he does, the truth stays buried: ruled 2026-10-23); the epilogue
  per branch; which lap-2 confrontation is the complete mission (§2.2).
- [ ] The epilogue's open joints: the badge's return, the gun in the
  let-him-live branch, where the DNA is left, the sad ending's last shot
  (Claude's proposals, §2.2).
- [ ] Lore still to write (found in the circle review, 2026-10-23): the
  official missions (only the power station is named: how many, which, who
  holds each zone); the trips abroad's details (the Director set three or
  four, Claude proposes four, one per lap-1 chapter, §2.6); the
  origin of the Agent's debt (the sad ending's foreclosed house leans on it;
  his field officer's modest pay explains the pressure, §2.1, but not the
  debt itself);
  how much he hands over at the Militia's and the Corporation's favours
  (§2.6); each sub-leader's character beyond the name and the motive (§2.7).
- [ ] A city that lived a real dam disaster (§2.6; Claude's recommendation
  there, to be taken to the association of those affected).
- [ ] Exact 1× economy pacing and the catalog of paid boosts beyond the
  permanent gameplay-currency 2×.
- [ ] Rewarded continue restore point and whether one per mission remains the
  final limit after playtesting.
- [ ] Free text in the lobby — after launch, once moderation (filters,
  reports, human review) exists; the launch defaults (presence, emotes,
  predefined phrases, no private messages between strangers) are in §16.
- [ ] Named rivals (§11.5): whether to build them, after an IP opinion on
  US 10,926,179.
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
  gameplay rule, not the renderer. 2026-10-23: the rope and hook's
  traversals and the perches do NOT open it: a perch is a cell with a
  height, never a storey, §10.0.)*
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
