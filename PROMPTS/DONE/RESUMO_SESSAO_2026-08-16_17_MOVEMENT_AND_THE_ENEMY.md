# RESUMO_SESSAO — 2026-08-16/17 (he walks, there is an enemy, and the plan turns)

**Version:** 0.9.103 throughout — no bump asked for, no tag.
**Commits:** 11, all pushed. `c748aa1f` · `1754ef62` · `2ef777e5` · `2b2c0cf0` ·
`bd0cd22f` · `d6e8b6be` · `18cda954` · `22f41bbd` · `20659075` · `3b72ae1e` ·
`c89de29f`.

---

## The one-line version

**Part 2 CLOSED** (the vector placeholder is deleted), **the walk exists and is
ratified at 0.56 s per GU**, **the enemy is the same figure in another palette**,
and the Director closed the question the whole character track existed to
answer: **the creation pipeline works.** What opened in its place is
`MOVEMENT_MASTER_PLAN` — the motion is not situational yet, and that is now a
plan rather than an impression.

---

## 1. What shipped

| | |
|---|---|
| **Part 2 §10** | `agent.gd::_draw()`'s three posture diamonds and head circle DELETED; `AgentSprite` draws the baked figure at 3 postures × 4 facings under real room light |
| **The walk** | 32 phases, distance-driven, **one cycle per GU derived from the grid** (two footfalls × 0.80 m = 1.60 m = one GU exactly) |
| **§9 #12 CLOSED** | **0.56 s per GU (2.86 m/s)**, blind bracket, and the pick was INTERIOR to the range |
| **DEV VISION** | survives the walk — 32 phases baked twice, loaded independently |
| **Part 7 half** | the enemy palette, on the guard, measured 49.5 levels from the agent |
| **Two new plans** | `MOVEMENT_MASTER_PLAN` opened; `DESTRUCTION_MASTER_PLAN` reopened for materials |

---

## 2. Five times a measurement overturned my own reasoning

This is the section worth re-reading. In every case the wrong answer was
available, cheap, and would have shipped.

1. **The crouch band was reachable all along.** I concluded §4.7's 5.0–6.2 voxels
   forced a torso fold that read as a crawl, and changed the solver's target to
   argue around it. Probed instead: **legs alone, torso upright, reach 6.17
   voxels at thigh −130 and 5.62 at −150.** My reference pose was the problem.
2. **The knee had to be driven by velocity, not position.** `max(0, -sin)` leaves
   both knees straight at the passing pose, so phases 0 and 4 of 8 rendered
   **byte-identical** and the cycle collapsed into two identical halves.
3. **The walk moonwalked, and no angle tuning could have fixed it.** The planted
   foot moved backward from phase 0 to 0.25 and then **forward** to 0.5 with its
   z on the floor. *"The planted foot moves backward"* is a property of the foot's
   **path**; angles satisfy it only by coincidence. Rebuilt as an authored foot
   trajectory solved through the same two-bone IK the grips use.
4. **Prone was face-planting, and the height band was structurally blind to it** —
   a body lying flat and a body with its feet in the air are the same HEIGHT.
   Measured: head crown **+0.102**, hips +0.333, **feet +0.404**.
5. **The bracket panels' backgrounds were not different.** Measured before
   acting: frame 0 of each run differs by ~9 000 px on a 921 600 px frame — the
   agent's own silhouette. The still was the problem, not the capture.

**And twice my own instrument was the defect:** a yellow-pixel counter calibrated
for full-brightness yellow reported 4 px on joints the room dims to a third of it
(real answer: 669); and a "warm accent" metric meant to detect the red hatband
was measuring the shotgun's wooden stock.

---

## 3. The gates that earned their place

- **The moonwalk gate CAUGHT ITSELF.** After the foot-roll refinement it failed
  at +23 mm. The defect was the *gate*: it identified the planted foot as the
  lower one, which is right for a flat foot and wrong the moment the foot rolls —
  at heel strike the TOE is the highest part of the planted foot. It now takes
  the stance foot from the authored path and measures the real contact point.
- **Three anatomy invariants** now run on every solved posture: the crown is
  above the hips, no foot floats above the hips, a lying figure is flat not
  piked. Written because the height band could not see orientation.
- **The bake's height gate rejected a stale number** I had retyped from an
  earlier run (1.220 against a file measuring 1.120). Heights travel in the
  manifest now.

---

## 4. Three defects the Director found by looking

*"Andando de costas e dobrando a perna errado. O crouch e o rastejo também estão
esquisitos."* All three were real, and the diagnosis was right about the cause.

1. **The facing was 180° out on the E/W axis.** I hand-wrote the step→frame table
   reading the bake's frame names as compass directions. They are not — the bake
   names frames after the room PERSPECTIVE, and `measure_facings()` had already
   MEASURED yaw 0/90/180/270 as drawing NE/NW/SW/SE. Now derived from the real
   `TileMapLayer`; all four fit at **1.000**.
2. **A second facing bug, invisible in the bracket:** `face_step` composed the
   perspective with the wrong sign. At the default N perspective the yaw is 0 and
   the error vanishes — and every bracket panel was captured at N.
3. **Prone was independently broken** — the static captures never called
   `face_step`, so bug 1 never touched them.

---

## 5. Where the plan turned

**The Director ratified the pipeline** (*"podemos concluir que nosso workflow vai
funcionar"*) and in the same breath named what is missing: the motion is not
**coherent with the situation**. The agent is a stealth infiltrator — a quiet
hunched run with the weapon down but ready and the head checking around, pressing
against walls, the Wolfenstein corner pose, an asymmetric one-knee crouch, a
crawl with the weapon in front of the head. `MOVEMENT_MASTER_PLAN` captures that
brief and deliberately does NOT invent the rest: the pose references, the
fluid-animation survey and the open-source survey are all missing inputs, and §4
is a research Part rather than fabricated content.

**Recorded honestly there:** the refinement pass already shipped (foot roll,
eased swing, head stabilisation, torso twist) is **not** the answer to *"molejo"*
— it landed and the verdict was still *"mecânico"*.

**Five items come before that milestone**, and the Director scoped them down
himself: no aim mode (combat phase), just click the enemy + *"disparar"* like the
grenade, always missing for now. Planned in `WEAPON_MASTER_PLAN` §6c and
`DESTRUCTION_MASTER_PLAN`'s reopening note.

---

## 6. Where the next session starts

1. **`WEAPON_MASTER_PLAN` §6c, Parts A–E** — the agent shoots. Almost all of the
   downstream is already shipped; what is missing is a **shooter** and a visible
   projectile. Four questions are posed there and should be answered before code.
2. **`DESTRUCTION_MASTER_PLAN`'s reopening** — glass is one hard problem (a
   non-local break; what IS a "whole window"?) and fabric/cardboard fill a
   `flammability` column the table already reserved for them by name.
3. **Two switches are currently SUSPENDED and must be flipped back together**
   when the movement milestone opens: `AgentSprite.DEV_ONLY_MILESTONE` and
   `P3_DEV_ONLY`.
4. **Open and unblocking nothing:** the crouch ships at 5.60 voxels and the
   Director called it *"esquisito"* — the band allows up to 6.17 with the legs
   alone; the walk's phase count (8/16/32) has a blind bracket delivered and no
   verdict; Part 7 owes D41's head turn and a real appearance difference.
5. **A milestone surfaced in passing and recorded so it stops being invisible:
   INTERFACE.** Everything is improvised keys, the game is mobile-first portrait,
   and D31 already calls those keys *"the desktop mirror of on-screen controls"* —
   the debt being that what they mirror does not exist.
