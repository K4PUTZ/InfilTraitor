# INFILTRAITOR — Design Philosophy

> **Principles that guide every system, feature, and decision in INFILTRAITOR.**

This document is NOT a feature list. It is a set of invariable principles that constrain and inform design.

---

## Core Principles

### 1. Information Is a Resource

**Principle:** Knowledge is scarcer than ammunition or health. The player must gather intelligence before acting.

**Implications:**
- Fog of war is permanent; it only clears through movement or dedicated reconnaissance
- Enemy patrol patterns are not immediately visible; guards must be observed to understand their behavior
- Detection probability is probabilistic and information-dependent (visual cone color-coded by likelihood)
- The player can always *ask the question* before committing to a path

**Anti-patterns to avoid:**
- Revealing entire maps instantly (kills tension)
- Making enemy behavior completely predictable (removes emergent challenges)
- Showing detection probability only after detection occurs (too late)

---

### 2. Stealth Over Combat

**Principle:** The game assumes the player prefers stealth; violence is a last resort, not the primary solution path.

**Implications:**
- Combat is always possible but never incentivized (no experience, loot, or score multipliers for kills)
- The path of least bloodshed is always cheaper (in AP, resources, and noise) than violent confrontation
- Alarms triggered by combat escalate the threat quickly; multiple guards respond
- Silent takedowns exist but require positioning and opportunity — they're not reliable spam

**Anti-patterns to avoid:**
- Making combat the path of least resistance
- Rewarding aggressive play with better loot or progression
- Allowing the player to simply "murder their way through" without consequences

---

### 3. Systemic Over Scripted

**Principle:** Encounters emerge from interacting systems, not from authored event chains. The player faces the same AI rules that enemies do.

**Implications:**
- No cutscenes that bypass the turn system
- No guaranteed safe routes (patrols vary; noise propagates unpredictably)
- Guard behavior is rule-driven: state machines, detection cones, noise thresholds
- The same detection logic applies to guards as to the player
- Emergent encounters (guard stumbling upon a corpse, multiple guards sharing information) create organic challenge

**Anti-patterns to avoid:**
- Scripted patrol routes that never deviate
- Enemies that "cheat" (detecting the player when they shouldn't)
- Events that trigger based on player location rather than game state
- Invisible walls that prevent "creative" solutions

---

### 4. Readability Over Realism

**Principle:** The game sacrifices verisimilitude for tactical clarity. Every information element is readable on a small mobile screen.

**Implications:**
- Tile grid is always visible; isometric perspective is consistent
- Detection cones are color-coded (blue/yellow/red for low/medium/high probability)
- Shadow tiles are visually distinct from regular floor
- Enemy facing angle is rendered clearly (guards have visible directional markers)
- UI information (AP cost, threat level, detected enemies) is never hidden

**Anti-patterns to avoid:**
- Over-realistic lighting that obscures enemy positions
- Ambiguous tile ownership (is the agent on this tile or adjacent?)
- Cluttered UI with tooltips that require careful reading
- Perspective shifts that make grid navigation unclear

---

### 5. Discrete Tactics, Continuous Perception

**Principle:** The turn system is discrete (each action is one turn), but enemy perception is continuous (enemies always perceive the world, even during player turns).

**Implications:**
- Player actions are atomic: one AP, one action, then phase resolution
- Enemy vision cones update every frame, not just at turn boundaries
- Noise propagation is instantaneous; alerts broadcast immediately
- The player can SEE enemy reactions in real-time (visual feedback is immediate)
- Turns feel "fair" because both sides use the same rule set

**Anti-patterns to avoid:**
- Enemies that only update their state at turn boundaries
- Delayed visual feedback (player takes action, then waits to see enemy reaction)
- Treating the turn system as a "pause" where the world freezes

---

### 6. Persistent Consequences

**Principle:** Actions have lasting impact. The world does not reset or forget. Mistakes escalate situations.

**Implications:**
- Alarms persist; once raised, they cannot be instantly cleared
- Guards communicate; one guard's alert reaches others within seconds
- Tripped traps alert the area (cannot be "un-discovered")
- Corpses remain; guards find them and escalate alert level
- Once a guard enters CHASE state, they remain hostile for the entire level
- Failed stealth changes the dynamic — future decisions must account for active threats

**Anti-patterns to avoid:**
- Resets that erase consequences (e.g., "retry without loading")
- Forgetting guards who have been alerted (treating alert state as temporary)
- Allowing the player to "undo" mistakes via reloads within a level
- Corpses disappearing or resetting after time

---

### 7. Fair Difficulty

**Principle:** The game is hard because it is *complex*, not because it is unfair. The player always understands why they failed.

**Implications:**
- All enemy detection logic is visible and explainable (why was I detected? What made the difference?)
- Randomness exists but is bounded (detection rolls happen only in ambiguous situations)
- The player is never surprised by an enemy appearing from off-screen
- Audio feedback and visual cues warn of incoming threats
- Difficulty scaling is consistent; harder levels are more complex, not "cheaply harder"

**Anti-patterns to avoid:**
- Invisible enemies or off-screen attacks
- Detection rolls with no visual indicator
- Surprise difficulty spikes between levels
- Enemies that "cheat" (detect through walls, see impossibly far)
- Mechanics that work inconsistently

---

### 8. Information Asymmetry Creates Drama

**Principle:** The player knows less than they wish they knew. Enemies are somewhat predictable but never fully. This asymmetry creates tension.

**Implications:**
- Patrol routes can be guessed but not perfectly predicted (guards have spontaneous pauses, momentary direction changes)
- Detection probability is shown but not guaranteed (a low-probability tile is still possible to detect from)
- Enemy communicat​ion reaches some allies but not all (LOS-based radio propagation)
- Guard suspicion states have memory; they don't forget forever, but they do de-escalate
- The player can reduce this asymmetry through observation and experimentation

**Anti-patterns to avoid:**
- Making enemy behavior completely random (feels unfair)
- Making enemy behavior completely predictable (game becomes solved)
- Hiding information the player reasonably should know (enemy state)

---

### 9. Player Agency is Paramount

**Principle:** The player always has meaningful choices. Constraints create decision points, not frustration.

**Implications:**
- Every level has multiple valid solutions (stealth vs. alarm, gadgets vs. skills, etc.)
- AP limits force prioritization but don't eliminate options
- Gadgets are powerful but consumable; decision point is "when to use it"
- Skill trees unlock new strategies, not just stat increases
- Level design avoids "gotchas" where only one path is valid

**Anti-patterns to avoid:**
- Encounters with only one viable solution
- Unannounced stat checks or hidden difficulty conditions
- Gadgets that are "always optimal" (no interesting choice about when to use them)
- Levels that punish player creativity

---

### 10. Progression Without Power Creep

**Principle:** The player grows stronger, but threats scale proportionally. The game never becomes trivial; tension persists.

**Implications:**
- Enemy AI improves as the campaign progresses (more coordinated, faster reactions)
- Freelance mode has escalating missions; contracts get harder as the player succeeds
- New gadgets and skills open up possibilities, but old tactics remain viable
- The "difficulty sweet spot" (challenging but fair) is maintained across the entire game
- A decisive victory in chapter 1 is an equal match in chapter 3

**Anti-patterns to avoid:**
- Overpowered late-game items that eliminate all challenge
- Early levels becoming trivial with end-game gear
- Difficulty that scales only through stat inflation
- Losing strategic viability of early-game tactics

---

## Application

These principles are applied through:

1. **System Design** — Each system (perception, noise, lighting, AI) reflects one or more of these principles
2. **Level Design** — Each room is designed to require multiple decision points and strategic planning
3. **Difficulty Tuning** — Each level is tuned to maintain challenge while respecting fairness
4. **UI/UX** — Every visual element supports readability and information clarity
5. **Feedback Loops** — Player actions generate immediate, clear feedback

---

## When Principles Conflict

These principles will occasionally conflict. Resolution order:

1. **Readability** always trumps realism
2. **Fair difficulty** always trumps surprise
3. **Player agency** always trumps forced narratives
4. **Systemic coherence** always trumps individual feature coolness

Example: A visually cool "teleporting enemy" might violate readability and fairness. It does not get implemented.

---

## Evolution

These principles are intentionally stable and unlikely to change. However, they *can* evolve if new evidence emerges (playtesting feedback, design breakthroughs, etc.).

Any change to these principles is a major decision that requires consensus and documentation.

---

## Reference

- See: `docs/vision/game_vision.md` for the broader vision
- See: `docs/systems/` for system-specific design rationale
- See: `docs/production/roadmap.md` for implementation phases
