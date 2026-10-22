# INFILTRAITOR — Game Vision

> **The only turn-based stealth tactics game that works on mobile — because every decision is yours, not your reflexes.**

---

## High Concept

**INFILTRAITOR** is a mobile stealth tactics game where **information is the primary resource**. The player controls a secret agent navigating hostile environments from a top-down isometric perspective on a square tile grid. Success depends on **knowing without being known** — fog of war, noise propagation, and enemy unpredictability make every run fresh and consequential.

The game combines:
- **Tactical puzzle-solving** (choosing a path through threats)
- **Room-based dungeon progression** (clear, survive, extract, unlock)
- **Character growth** (new skills, gadgets, weapons, and equipment)

---

## Core Fantasy

The player inhabits the role of **a spy infiltrating hostile territory**. The defining fantasy is not combat prowess but **information gathering and strategic planning**. 

Key emotional beats:
- **Discovery** — uncovering enemy patrol patterns
- **Tension** — nearly being detected, narrowly avoiding conflict
- **Mastery** — executing a perfect plan without raising alarms
- **Consequence** — one mistake escalates the entire situation

The game emphasizes **readability and control**: on a small mobile screen, the player always understands the threats, always sees what they are risking, and always acts intentionally.

---

## Player Experience

### Moment-to-Moment Gameplay
1. **Observe** — study the tactical layout, track enemy movements, gather intel
2. **Plan** — chart a path through threats using limited resources (AP, gadgets, skills)
3. **Act** — execute the plan with surgical precision
4. **React** — adjust to unforeseen consequences (alarms, enemy escalation, opportunities)

Each turn, the agent receives **2 Action Points (AP)**. This constraint forces meaningful choices: move, use a gadget, interact, or trade AP for strategic advantage via Overwatch and traps.

### Session Structure
- **Single level:** 1–3 minutes
- **Campaign:** an opening, two laps around the four factions and the finale at the cemetery ([`DESIGN_MASTER_PLAN`](../DESIGN_MASTER_PLAN.md) §2.2), played once per character: four story routes, one per faction; its length is not yet estimated
- **Replayability:** Procedural generation ensures variety while hand-crafted templates maintain fairness; each class replays the campaign another way (`DESIGN_MASTER_PLAN` §15)

### Progression Arc
- **Early game** (the campaign's first chapters, by position in the lap): Learn detection mechanics, shadows, and basic evasion
- **Mid game** (the later chapters and lap 2): Manage complex enemy behaviors (communication, coordination, suspicion escalation)
- **Late game** (the finale + Freelance): Master advanced systems (EMP, hacking, coordinated enemy squads)

---

## Pillars

| Pillar | Definition | Why It Matters |
|--------|-----------|-----------------|
| **Stealth-First** | Detection is failure (or heavy penalty). Patience and planning are rewarded. | Encourages thoughtful play; rewards mastery of game systems over twitch reflexes. |
| **Information Asymmetry** | Fog of war, limited vision, and noise propagation make knowledge scarce. | Creates dramatic tension; information gathering becomes a primary goal. |
| **Grid-Based Clarity** | Every element occupies discrete tiles; threats are always readable. | Mobile screens are small; visual clarity is essential for tactical decisions. |
| **Systemic Depth** | Mechanics interact emergently; no scripted encounters. | Ensures replayability and emergent problem-solving. |
| **Persistent Consequences** | Actions have lasting impact; mistakes escalate situations. | Makes decisions feel weighty; discourages recklessness. |
| **Session-Friendly** | Levels are short; saves happen between missions. | Respects mobile play patterns (commute, break-time sessions). |
| **Progressive Mastery** | New abilities unlock previously impossible routes. | Keeps gameplay fresh; rewards experimentation and skill development. |

---

## Inspirations

| Game | Influence |
|------|-----------|
| **Dishonored** | Feeling of power mixed with vulnerability; creative problem-solving over combat |
| **XCOM 2** | Turn-based tactics, readability, and information-driven decisions |
| **Phoenix Point** | Long-term threat escalation; strategic consequences of actions |
| **Invisible Inc** | Information as the core resource; stealth over combat |
| **Hitman GO** | Mobile-first tactile turn-based mechanics |
| **Diablo** | Infinite progression; escalating difficulty; no "end state" |

---

## What The Game Is NOT

- **Not a real-time action game.** Reflexes are irrelevant; planning is everything.
- **Not a roguelike permadeath game.** Levels fail or succeed; the campaign progresses.
- **Not a pure stealth game.** Combat is possible (and sometimes necessary) — the choice between stealth and confrontation is player-driven.
- **Not a puzzle game.** Encounters have multiple valid solutions; there is no single "correct" path.
- **Not a pure RPG.** Character progression exists but never trivializes tactical decisions.
- **Not friction-first free-to-play.** The full campaign, Freelance and every
  power remain earnable without payment. Monetisation is transparent paid
  acceleration (initially permanent 2× gameplay currency), a voluntary
  rewarded continue and optional cosmetics — never an artificial barrier sold
  back to the player.

---

## Core Gameplay Loop

```
PLAYER TURN
  → Observe: Study threats, track enemies, plan
  → Act: Spend 2 AP on movement, gadgets, interactions
  → End Turn

ENEMY TURN (simultaneous execution)
  → All guards advance their patrol/investigation
  → Alarms escalate
  → Noise propagates

[Loop repeats until level complete or detected]
```

---

## Narrative Identity

**The name is the narrative.** INFILTRAITOR — the agent is both infiltrator and traitor.

*(Revised 2026-10-21/22; the canon is [`DESIGN_MASTER_PLAN`](../DESIGN_MASTER_PLAN.md) §2. The Agency / Network pair it replaces is history.)*

Four factions orbit one company, GRUB DRILL INC: **the Federal Police** (a fictional agency in the game), **the Militia** (a private military
security company), **the Traffickers** (a motorcycle club) and **the Corporation** (the company's executives). A dam collapses; each faction is guilty
of one failure that turned a small attack into a massacre, and innocent of the attack itself. The Agent, a federal investigator who lost his son
that day, hunts all four in their own uniforms, until a reporter, the one outsider who put the pieces together, confronts him with the truth the player never
suspected: the Agent launched the attack.

None is purely heroic, the Agent least of all. Each faction can recruit him, so the player has up to four characters, one per faction, each a route
through the same story.

After the campaign, **Freelance mode** unlocks: the agent, now a fugitive, goes on infiltrating and charging for information, growing in power and
facing increasingly sophisticated threats.

---

## Design Principle: Information First

All systems are built around **information scarcity and revelation**:

- **Fog of War:** Unexplored tiles are invisible; exploration reveals the map
- **Enemy Vision:** Guards have limited, probabilistic sight cones
- **Noise Propagation:** Sound travels; guards communicate findings
- **Lighting:** Shadows reduce detection probability, making them tactical assets
- **Detection Meters:** Visual readouts show current threat level to each guard

The player's agency is *information-driven*: the more you know, the better you plan; the better you plan, the fewer mistakes you make.

---

## Success Metrics

| Metric | Target |
|--------|--------|
| **Session length** | 1–3 minutes (level); the campaign's length is not yet estimated |
| **Mobile playability** | Full experience on 5–6.5" screens without UI clutter |
| **Difficulty clarity** | New players understand tactics within 5 minutes |
| **Replay value** | Procedural generation ensures fresh layouts each attempt |
| **Monetization balance** | Full free/offline path; paid acceleration reaches the same powers sooner; voluntary ads only after ordinary options; no purchased random rewards or FOMO |
| **Platform flexibility** | iOS, Android, and HTML5 all supported without compromise |

---

## Next Phase

This vision document establishes the **what** and **why**. Implementation phases (Pillars, Mechanics, Systems, Content) translate the vision into playable features.

See: `docs/production/roadmap.md`
