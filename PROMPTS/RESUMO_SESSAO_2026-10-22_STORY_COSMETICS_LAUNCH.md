# RESUMO DA SESSÃO — 2026-10-21/22 — The story, the factions, cosmetics, the world map, the launch

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`). Design and planning only; nothing built after the hero v5.1 (see
`PROMPTS/RESUMO_SESSAO_2026-10-21_HERO_V5.md`). Every ruling below is in the docs named in each line; this record is the map.

## 1. Where each decision lives

| Topic | Where | State |
|---|---|---|
| The four factions (Federal Police — a fictional agency in the game, Militia, Traffickers, Corporation) around GRUB DRILL INC | `DESIGN_MASTER_PLAN` §2.1 | ratified |
| The campaign: home opening, police station, the player picks the recruiting faction (its uniform first), lap 1 of favours, wife dies at the midpoint and the baby survives, lap 2 of confrontations (first three short, the last complete), the last leader, the neonatal epilogue | §2.2 | ratified |
| The dam: the Agent (a federal investigator in debt, the police's leak to the militia) attacks for a bet; four failures (pit, sirens, waste, buried report) make a massacre; the circle table; same clues in every route; the town is the player's city; backups: refinery or hydro plant | §2.6 | ratified (the circle table and "he is the leak" were Claude's proposals, accepted) |
| The bet: short-dated puts through a front, hidden among other bettors; the expiry is his tell; no dark-web/bitcoin contract | §2.6 | Claude's answer, recorded |
| The 16+ audience; launch social defaults (age gate, emotes and set phrases, no private messages between strangers, no profiling ads under 18); no paid loot boxes at any rating | §16, §18 | ratified (defaults are Claude's) |
| Cosmetics: TF2 item schema, server ownership, slots and pieces, signed assets, backpack/shop masters, attributes, contributions, armband / banner, the weekly war, **the model slot inventory (§8)** | `COSMETICS_MASTER_PLAN` v0.3 | proposed (C1-C11) |
| The world: a 3D globe of political borders as the mission hub, lit cities, common landmarks, missions personalised by the home city (nearby names, the capital, flags only on neutral places, signage language) | `COSMETICS_MASTER_PLAN` §6 | ratified |
| The launch milestone: the partnership with those affected, notes L1-L6 | `LAUNCH_MASTER_PLAN` v0.1 | notes |
| The company logo: a stylised curled grub (`REFERENCES/grub.webp`) | `DESIGN` §2.6 | direction (no art made: the Director said not now) |

## 2. Open for tomorrow (the Director: "amanhã fechamos as últimas pontas soltas")

1. The fictional federal agency's name and its ranks per country (the draft's "Tenente" is a military rank).
2. §11.1's counters and §14.3's chapter ladder re-mapped to FOUR factions.
3. The Agent's endgame in Freelance (a "broker"?), and the player's agency after the reveal.
4. `COSMETICS` §5: prizes, the banner, the backend, contributions, trading; ratify C1-C11.
5. `LAUNCH` L1-L6 scope; whether the dedication / partnership stays now that no real case is named.
6. Hero: the hair style; D70's black-swap duration; D72's cloak numbers; the adapter to `ActorMesh3D`; the handset measurement of v5.1.

## 3. Review pass (2026-10-22, later the same day)

The Director reviewed the plot against Claude's list of tensions and stale text. Ruled, and written into the docs:

| Ruling | Where |
|---|---|
| **The reporter**, a fifth element (not a faction): bought from the Agent, as an anonymous police source, the information about the traffickers that the Militia used; supplies the leads in lap 2 (his hints change with the order); at the finale he has put the pieces together, aims a gun at the Agent and exposes him (twist 2; he is §2.4's outside source); after the fight the player KILLS him (the Agent stays free) or FLEES (the Agent becomes a fugitive); in both endings he goes on infiltrating and charging for information | `DESIGN` §2.1, §2.2, §2.4, §18 |
| A permanent **tattoo** marks the choice, per character instance; achievements for a no-kill run, bosses excluded | `DESIGN` §2.2; `COSMETICS` §3, §8.2 |
| **Motives:** the Corporation hid the report hoping for a CONTAINED leak, for a commission on selling the company at half price to foreign funds, and buys no options; the Militia leaks from the inside (its men let the traffickers' labs into the facilities it guards) | `DESIGN` §2.1, §2.6 |
| **Structure:** lap 1 keeps the circle; lap 2 in any order; the reporter's finale is the complete mission (Claude's reading, stated, not contested) | `DESIGN` §2.2, §2.6 |
| **Four characters, one per faction**, each an instance of the Agent created at the police station: four story routes; classes restrict some powers early (replay value), converge at the endgame except a few faction specials; equivalent power, any class against any faction; missions need routes per style (stealth, brawl...), possibly per 3×3 segment | `DESIGN` §2.2, §14.3, §15, §18; `COSMETICS` §2 |
| **Leagues:** many simultaneous leagues of 4 x 30 characters; invite friends; bots fill seats and are shown as bots; prizes to humans only; absence is the player's right; the challenge is a class left empty; the ranking mostly shows the avatar | `COSMETICS` §4; `LAUNCH` L4 |
| **A forum** moderated by the community through earned privileges (Stack Overflow) | `DESIGN` §16; `LAUNCH` L7 |
| **Brumadinho:** the Director's doubt (barring a player's city may hurt more) recorded with Claude's recommendation (dam everywhere, ask the association before launch, the backup setting as a silent tool); NOT ruled | `DESIGN` §2.6; `LAUNCH` §1 |

Also applied (Claude's list B, no objection): the stale "3-chapter campaign", Elite prologue, "unknown client", "planted the bomb", Agency /
Network and league-of-90 text in `DESIGN` §1/§11/§15/§18, `docs/vision/*`, `current_state.md`, `COSMETICS` (v0.4, §7 before §8) and `LAUNCH` (v0.2).

**The finale, re-cut the same day (Director):** no fight. A public memorial at the cemetery after the town is restored, before the four factions and
the press; the Agent, at the grave of the son he has just buried, lets slip what only the attacker could know; walking away, the reporter draws a gun;
the revelation in the rain; the Agent draws too; the player KILLS the reporter (discovered: a fugitive) or LETS HIM LIVE (the Agent hands him his own
gun, tells him to do what he thinks necessary and turns his back; the reporter is tempted to erase him or sets justice after him: endings open; a
fugitive too). The "kill and stay free" ending is gone; the epilogue is to re-cut. Floated, open: the wife and the son surviving by choices (Claude's
remarks in `DESIGN` §2.6). **The reporter RATIFIED:** Thomas, the outlet *Blind Spot*, first seen at the police station's door, the real approach
at the hospital after the wife's death; the canon is in English, names may be localised later. **The family (still in doubt):** the son's death is
fixed; a survivor would need the Agent to fake his own death and watch them grow from afar, decided by an easter egg at the start (restore the power
first: mother and baby live); Claude's recommendation (`DESIGN` §2.6): the easter egg only gives, the start becomes a playable night of the
disaster (the tutorial), the faked death closes every branch. **Then (Director):** the power moment moves to the AFTERMATH, after the police station,
and needs more thought (Claude's "night of the disaster" withdrawn); "no baby at all, the wife survives or dies" floated, undecided. **The aftermath
is the campaign's backdrop (ratified):** the devastated region, the Agent helping the authorities in the chaos, rescue teams / firefighters / police /
workers fighting for jurisdiction, curfew, traffickers' zones, Militia facilities; the same places revisited over time with small changes (Deus Ex).
`DESIGN` §2.2, §14.4 (Claude's proposals there: jurisdiction as a zone rule with uniforms, the rescue never a battlefield); the engine need is a
top note in `docs/systems/MAP_MASTER_PLAN.md`.

**Then ratified (Director):** **no baby.** After the station the commissioner "forbids" the case and hands over urgent OFFICIAL missions in zones
the police barely reach (the power station among them), done first, in the player's order, all infiltration (evidence, people, bugs, acting on the
world: a sluice gate, a tank). The rescue is scenery (vehicles, cordons, hoardings, closed zones); the rest of the town is held by factions and
looters. **Acid, not mud** (the drug waste): dangerous ground, obstacle-heavy scenes; the engine has the liquid. **Time states are AUTHORED maps,
campaign only;** Freelance plays the places in any time and order; in-mission change is the engine's (fire, glass, lights; a nightfall is NOT built).
To confirm: Claude's reading that the order of the official missions decides the wife's fate (power first: she lives, and he fakes his death).
`DESIGN` §2.2, §2.6, §14.2, §14.4, §18; the map plan note rewritten (no mechanism planned). **The badge (Director):** at the station the ban is
VERBAL and he keeps the badge; the commissioner takes it later, in the lap-1 chapter that investigates the police over the pit ("interfering for
revenge"); police zones stay walkable, but checkpoints stop him and he is discovered. **The commissioner IS the police chief** (the lap-2 leader; ruled by the Director). **The wife's fate (Director):** she SURVIVES by default; a run that kills
too many people leaves the hospital short of a supply and she dies; classes stay equivalent, the violent player of any class sees the sadder
ending (Dishonored's chaos). Claude's proposals in `DESIGN` §2.6, not yet ratified: the supply is blood, the midpoint is the warning, a generous
threshold, what counts (player-caused deaths by any means; not knockouts, the leaders or the reporter), a non-lethal option in every class kit.
Superseded: the power / the official missions' order deciding her fate. **Then (Director):** those proposals RATIFIED; and he FAKES HIS OWN DEATH in
every scenario (wife alive or not, reporter alive or not): he must disappear either way; if she lives, he watches her from afar. **Then
(Director, closing the plot for now):** the threshold is an average above 50% of the enemies killed; he fakes his death at the pit (the gun, the
badge and his DNA into the acid), a TV report confirms it, the camera pulls back from his wife with her relatives, out through the window, to
the Agent watching outside, who turns and disappears into the horizon. Claude's open joints (`DESIGN` §2.2): the badge taken back from the chief's
body, the wedding ring (the reporter holds the gun in one branch), his blood on the pit's edge (acid destroys DNA), the empty foreclosed house as
the sad ending's last shot, the old beats on the same news bulletin.

## 4. Where the plot stands (closed for now, 2026-10-22)

Ratified in `DESIGN_MASTER_PLAN` §2 / §14.4 / §15 / §18. Still open, none blocking: the agency's name and ranks; the reporter's surname; §11.1's
counters and §14.3's ladder for four factions; the four class kits and whether later characters replay the campaign; which lap-2 confrontation is
the complete mission; what the reporter does with the gun; the epilogue's open joints; a city that lived a real dam disaster (for the
association); `COSMETICS` §5 and C1-C11; `LAUNCH` scope; the hero items (§2 item 6).

**Open after this pass** (items 1, 4, 5, 6 of §2 above still stand; item 3 is ruled): the four class kits and whether later characters replay the
whole campaign; the reporter's name, outlet, first contact, what the final fight is made of, and whether killing him breaks a no-kill run; where the
tattoo sits on the body; each Agent instance's look per class; the forum in-game or on the web; the Brumadinho question for the association.
