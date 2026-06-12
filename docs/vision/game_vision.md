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
- **Campaign:** ~30–45 minutes (3 chapters, each ~10–15 min)
- **Replayability:** Procedural generation ensures variety while hand-crafted templates maintain fairness

### Progression Arc
- **Early game** (Campaign Chapter 1): Learn detection mechanics, shadows, and basic evasion
- **Mid game** (Campaign Chapter 2): Manage complex enemy behaviors (communication, coordination, suspicion escalation)
- **Late game** (Campaign Chapter 3 + Freelance): Master advanced systems (EMP, hacking, coordinated enemy squads)

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
- **Not free-to-play predatory.** Monetization is ads + optional cosmetics; never pay-to-win.

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

Two factions compete for the player's allegiance:
- **The Agency** — projects stability through intelligence and control
- **The Network** — promises transparency through information freedom

Neither is purely heroic. The campaign narrativizes the player's moral drift as they uncover the Agency's true methods and choose their path.

After the campaign, **Freelance mode** unlocks: the agent now operates independently, accepting contracts, growing in power, and facing increasingly sophisticated threats.

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
| **Session length** | 1–3 minutes (level); ~45 min (campaign) |
| **Mobile playability** | Full experience on 5–6.5" screens without UI clutter |
| **Difficulty clarity** | New players understand tactics within 5 minutes |
| **Replay value** | Procedural generation ensures fresh layouts each attempt |
| **Monetization balance** | Ad-supported with optional cosmetics; zero pay-to-win mechanics |
| **Platform flexibility** | iOS, Android, and HTML5 all supported without compromise |

---

## Next Phase

This vision document establishes the **what** and **why**. Implementation phases (Pillars, Mechanics, Systems, Content) translate the vision into playable features.

See: `docs/production/roadmap.md`
