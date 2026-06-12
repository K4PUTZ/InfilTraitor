# INFILTRAITOR — Design Pillars

> **Seven pillars that define the gameplay experience and constrain all design decisions.**

---

## Pillar 1: Tactical Stealth

**Description:**
The player succeeds through planning and positioning, not reflexes. Every action is deliberate; every decision is tactical.

**Why It Matters:**
- Differentiates from real-time action games; makes gameplay accessible on mobile
- Rewards patient, analytical players
- Allows for complex threat evaluation in discrete time intervals

**Design Implications:**
- Turn-based action system is non-negotiable
- No time pressure; the player controls the pace
- Threats must be readable before commitment (no surprise attacks from off-screen)
- Multiple valid solutions per encounter (force tactical choice)

**Anti-patterns:**
- Time limits on decision-making
- Enemies that move during the player's turn
- Stealth penalties that are not predictable (randomness in detection without context)

---

## Pillar 2: Environmental Information

**Description:**
Fog of war, limited vision, and noise propagation make environment knowledge a primary strategic resource. The player must observe, infer, and adapt.

**Why It Matters:**
- Creates emergent gameplay (same systems, different information state = different puzzle each time)
- Tension comes from uncertainty, not enemy power
- Replayability is built-in through procedural layout + information variance

**Design Implications:**
- Fog of war is permanent until explored
- Enemy behavior is partially observable (can infer patrol patterns through observation)
- Noise propagates visibly; guards communicate findings
- Lighting creates tactical shadows that reduce enemy detection probability
- Information gathering is a valid primary strategy (spend a turn observing, not just moving)

**Anti-patterns:**
- Revealing the entire map on load
- Making enemy behavior completely random (player cannot infer patterns)
- Hiding threat indicators until danger is immediate

---

## Pillar 3: Persistent Threat

**Description:**
The world remembers. Alarms escalate. Guards coordinate. One mistake can unravel the entire plan — but careful planning can de-escalate threats.

**Why It Matters:**
- Makes every decision feel weighty
- Discourages recklessness and spam tactics
- Creates emotional investment (one turn changes everything)
- Encourages mastery through planning rather than trial-and-error

**Design Implications:**
- Alarms persist; escalation is visible and terrifying
- Guards communicate instantly; localized alerts can become global
- Corpses remain and are discovered by patrols
- Once a guard is suspicious, de-escalation requires time or active intervention
- Each level offers one or two "points of no return" where stealth failure locks in a confrontation

**Anti-patterns:**
- Alarms that fade naturally
- Guards that forget sightings after leaving an area
- Corpses disappearing automatically
- Levels that reset if the player dies (persistence is the point)

---

## Pillar 4: Spatial Manipulation

**Description:**
The tile grid is the primary interface. Movement, positioning, and LoS geometry are core mechanics. The player manipulates space to create advantage.

**Why It Matters:**
- Isometric grid is readable and tactile on small screens
- Spatial reasoning is consistent and learnable
- "Positioning is destiny" makes tactical decisions meaningful

**Design Implications:**
- Cover is determined by LoS geometry, not arbitrary values
- Shadow tiles mechanically reduce detection probability (not just visually suggestive)
- Distance matters: guards at 9 tiles have lower detection than those at 3 tiles
- The grid is the "conversation" between player and enemies (movement is communication)
- Sight lines are always visible; player can trace LoS to know if they're detected

**Anti-patterns:**
- Grid traversal that violates isometric geometry
- Cover that works inconsistently (LoS varies between entities)
- Distance calculations that are hidden or inconsistent

---

## Pillar 5: Emergent Problem-Solving

**Description:**
Encounters emerge from interacting systems, not scripted sequences. Players face the same AI rules that enemies do. Solutions are player-discovered, not authored.

**Why It Matters:**
- Ensures true replayability (same mechanics, different layout = fresh puzzle)
- Rewards experimentation and creative problem-solving
- No "correct solution" — many valid approaches exist
- Reduces designer burden (systems do the work; content is layout + parameterization)

**Design Implications:**
- All encounter variety comes from procedural layout + system interaction, not new "encounter types"
- AI follows consistent rules; no special cases (guards have state machines, not story triggers)
- Gadgets and skills interact with systems predictably (gadgets create interactions, not exceptions)
- Player creativity is enabled through system transparency (player understands enemy rules)

**Anti-patterns:**
- Scripted patrol routes that never deviate
- Special "boss" encounters with different rules
- Hidden mechanics that only NPCs can use
- Tutorials that teach false mechanics ("guards forget quickly" when in reality they don't)

---

## Pillar 6: Progressive Mastery

**Description:**
New abilities unlock previously impossible routes and strategies. Learning compounds; mastery of early systems enables mastery of late systems.

**Why It Matters:**
- Keeps gameplay fresh across 3 campaigns + Freelance mode
- Provides clear progression trajectory
- Rewards skillful play with new options, not just stat inflation

**Design Implications:**
- Gadgets and skills must interact with existing systems in surprising ways
- Early-game tactics remain viable in late-game (not obsoleted)
- Difficulty increase comes from complex encounters (more guards, more sophisticated coordination), not stat walls
- Campaign structure teaches systems progressively (Chapter 1: vision; Chapter 2: communication; Chapter 3: coordination)

**Anti-patterns:**
- Late-game items that trivialize early-game challenges
- Skill trees that are purely stat increases
- New abilities that only work in specific circumstances
- Forced usage of new mechanics (old tactics should remain viable)

---

## Pillar 7: Information Asymmetry Creates Tension

**Description:**
The player knows less than they wish they knew. Enemies are somewhat predictable but never fully. This managed asymmetry creates dramatic tension and emotional stakes.

**Why It Matters:**
- Distinguishes from perfectly solvable puzzles (which are boring after one solution)
- Creates moment-to-moment tension (you can plan, but not guarantee)
- Replayability comes from this variance; no two guards patrol identically
- Matches the fantasy: real espionage has incomplete information

**Design Implications:**
- Guard behavior has deterministic rules but probabilistic outcomes (patrols + spontaneous pauses)
- Detection is calculated but not guaranteed (a 10% detection zone is still possible)
- Enemy communication reaches some units but not all (based on proximity, LoS, noise levels)
- Guard memory has time limits; suspicion decays but does not disappear instantly
- The player can reduce asymmetry through observation (spy a patrol pattern by watching, spend a turn gathering intel)

**Anti-patterns:**
- Completely random guard behavior (feels unfair)
- Completely predictable behavior (game becomes solved)
- Hiding information the player reasonably should know (enemy state, threat level)
- Letting randomness override player strategy (detection should be influenced by player choices)

---

## Pillar Interaction Matrix

| Pillar | Supports | Is Supported By | Tension With |
|--------|----------|-----------------|--------------|
| **Tactical Stealth** | Spatial Manipulation, Progressive Mastery | Turn system, AP limits | Real-time pressure |
| **Environmental Information** | Emergent Problem-Solving, Persistent Threat | Fog of war, noise system | Information overload |
| **Persistent Threat** | Tactical Stealth, Progressive Mastery | Alarms, communication | Trivial difficulty |
| **Spatial Manipulation** | All pillars | Grid consistency, LoS geometry | Performance, screen space |
| **Emergent Problem-Solving** | Replayability, Creativity | System transparency, consistent AI | Designer workload |
| **Progressive Mastery** | Long-term engagement | Skill trees, new abilities | Power creep, stat inflation |
| **Information Asymmetry** | Tension, Replayability | Controlled randomness, memory decay | Player frustration |

---

## Pillar Compromise Resolution

If a new feature conflicts with multiple pillars, resolve in this order:

1. **Tactical Stealth** — Non-negotiable. All other pillars serve this.
2. **Environmental Information** — Core to replayability.
3. **Persistent Threat** — Essential to tension.
4. **Spatial Manipulation** — Core to mobile readability.
5. **Emergent Problem-Solving** — Preferred over authored sequences.
6. **Progressive Mastery** — Must not create power creep.
7. **Information Asymmetry** — Can be tuned, but not eliminated.

---

## Anti-Pillar Patterns (What NOT To Do)

| Anti-Pattern | Why It Fails | Violates Pillar |
|--------------|-------------|-----------------|
| Twitch-based detection | Requires reflexes, not planning | Tactical Stealth |
| Instant map reveal | Eliminates information gathering | Environmental Information |
| Alarms that fade | Removes persistence and consequence | Persistent Threat |
| Invisible enemies | Violates spatial readability | Spatial Manipulation |
| Scripted boss encounters | Removes emergent solutions | Emergent Problem-Solving |
| Overpowered late-game items | Trivializes early content | Progressive Mastery |
| Pure randomness (no player influence) | Creates frustration, not tension | Information Asymmetry |

---

## Reference

- See: `docs/vision/design_philosophy.md` for philosophical foundations
- See: `docs/systems/` for system-specific implementations of these pillars
- See: `docs/production/roadmap.md` for milestone alignment with pillars
