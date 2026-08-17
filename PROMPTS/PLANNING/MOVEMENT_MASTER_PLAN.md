# MOVEMENT_MASTER_PLAN
## How the Agent Moves — Situations, Poses, Transitions and the Motion-Design Pipeline — v0.1 (BRIEF CAPTURED, NOT YET A PLAN)

> **Status: 🟡 OPENED 2026-08-16. This is the Director's brief, recorded, plus
> the questions that have to be answered before it becomes executable.**
>
> It is deliberately NOT a finished plan. Three of its inputs do not exist yet:
> the Director's pose references, a survey of the animation literature, and a
> survey of open-source resources. Writing an execution plan on top of missing
> research is exactly the "theoretical visual mechanism" D30 refused to test
> against.
>
> **The movement milestone does not open yet.** Director, 2026-08-16: five items
> come first (see §6).

---

## 0. Ownership boundary — read before editing this or CHARACTER_MASTER_PLAN

| Document | Owns |
|---|---|
| `ACTOR_MASTER_PLAN` §2 | the **decision register** (D-rows). Cite by number, never restate |
| `CHARACTER_MASTER_PLAN` | the **figure**: model, rig, sockets, scale, bake pipeline, the Parts |
| **this document** | **what the figure DOES**: which situations produce which pose, which transitions exist, and how motion gets authored and judged |

The split matters because they answer different questions. `CHARACTER` answers
*can we draw him at all* — and as of 2026-08-16 that is settled (§1). This one
answers *is what he is doing the right thing to be doing*.

---

## 1. ✅ THE PIPELINE IS PROVEN — Director, 2026-08-16

*"Está ficando muito bom. […] para a nossa intenção aqui de avaliar proporção e
viabilidade da nossa pipeline de criação, já serve esse mecanismo. Então podemos
concluir que nosso workflow vai funcionar."*

**This closes the question Part 0 was created to answer.** Rig → posed GLB →
Godot bake → relit sprite → the playable agent, at three postures, four facings
and a 32-phase walk, all gated end to end. Proportion and viability are no longer
open; what remains is *quality of motion*, which is this document's subject.

**And the same message says the motion is not there yet:** *"Ainda parece
mecânico. Falta mais 'molejo' nas articulações, mais micro movimentos que fazem
um movimento natural e orgânico."* Recorded as the standing quality bar, not as a
defect to fix in isolation — §5 is where it gets a method.

---

## 2. 🔴 THE REAL GAP: the movement is not COHERENT WITH THE SITUATION

Director, 2026-08-16, and this is the finding that opens this document:

> *"O personagem não vai andar dessa forma robótica para frente. Ele é um agente
> numa missão stealth."*

The walk that exists is a **neutral locomotion cycle**. It is correct as a cycle
and wrong as a character: nothing about it says *infiltrator*. The agent's motion
has to read as a job being done under threat of being seen — which is the same
thing `DESIGN_MASTER_PLAN` asks of every other system, arriving at animation.

### 2.1 The poses the Director specified

Verbatim intent, structured. **These are examples he gave, explicitly not an
exhaustive list** — *"Esses são só alguns exemplos."*

| # | Situation | Pose |
|---|---|---|
| **M1** | Moving, open ground | A **quiet little run** (*"corridinha silenciosa"*) — head and shoulders **hunched**, weapon **pointing down but ready to use**, head **looking around** to check nobody is watching |
| **M2** | Arriving at a GU that has a **wall** | **Presses himself against it**, to offer less visible area |
| **M3** | At a **corner** | The **Wolfenstein 3D cover pose** |
| **M4** | **Crouched with no wall** | One knee **touching the ground**, the other up and bent; one hand holding the **pistol raised**, the other supported on the ground on **five fingertips** |
| **M5** | **Crawling** | One leg extended, the other half-bent **pushing the ground backward**; aiming forward with the **weapon in front of the head** |

**Note what M1 does to the current asset.** The shipped walk is upright, level-
headed and forward-facing — the opposite of hunched, and with no looking around
at all. M1 is not a tweak to it; it is a different cycle. The existing walk is
not wasted (it proved the pipeline, §1) but it is not the ship asset.

**Note what M2/M3 introduce that nothing in the project has:** a pose that
depends on **what is adjacent to the GU**, not only on the agent's own state.
`agent.gd` already computes `cover_state`/`cover_direction` (NONE/PARTIAL/FULL
and which side), so the *data* exists; nothing has ever driven a visual from it.

**Note what M4 costs against §4.7's band.** The crouch that ships is a symmetric
squat at 5.60 voxels. M4 is asymmetric — one knee down, one hand down — which is
a different silhouette AND a different height. §4.7's 5.0–6.2 voxel band was
measured against a squat; whether it still describes M4 is an open question, not
an assumption.

### 2.2 The method the Director proposed

> *"Eu proponho que a gente comece só com as poses iniciais e finais, e depois
> crie todas as animações intermediárias."*

**Key poses first, in-betweens second.** This is classic pose-to-pose animation
rather than straight-ahead, and it is the right call for this pipeline for a
reason worth stating: every asset here is a **baked sprite**, so an in-between is
a bake, and bakes are the expensive step. Settling the extremes first means the
expensive step runs once against a ratified target instead of repeatedly against
a moving one.

It also matches what the project already learned: the walk's phase count was
raised from 8 to 32 only *after* the cycle's shape was right, and the shape was
what "mechanical" was actually about.

---

## 3. What has to be enumerated before anything is authored

The Director's own framing: *"Precisamos elencar as situações mais comuns e fazer
uma lista de movimentos que vamos utilizar, incluindo as transições, quando
necessárias."*

**The list does not exist yet and must not be invented here.** What this section
records is the SHAPE the list has to have, so that filling it is a session's work
rather than a design negotiation:

1. **Situations** — the game states that demand a distinct pose. Sources that
   already constrain this and must be read rather than guessed:
   `agent.gd`'s three postures and its cover state; `DESIGN_MASTER_PLAN` §8's
   cover model and §10's equipment; D37's hood/stealth mode; D40's three grips.
2. **Poses** — one per situation, as M1–M5 above.
3. **Transitions** — which pairs need authored motion between them and which can
   snap. **D47 is the precedent and the budget guard**: ordinary movement changes
   facing by a hard snap with no transition frames, judged blind, and that single
   ruling is what keeps the body budget at 744 sets instead of 4608. The same
   question has to be asked of every transition here, and the default answer is
   *snap until proven otherwise*.
4. **Cost** — every entry priced in `archetype × silhouette × pose × yaw` terms
   (`CHARACTER_MASTER_PLAN` §8), because the pose count is the multiplicative
   axis and this document is the thing that grows it.

---

## 4. Part 0 — RESEARCH, and it runs before authoring

Director: *"precisamos dar uma pesquisada na literatura sobre animação fluída,
verificar o que existe de recursos open source, e montar o pipeline de trabalho."*

**Not yet done, and deliberately not faked here.** Three deliverables:

- **R1 — Fluid-animation literature.** What makes motion read as organic: the
  established principles (anticipation, overlap and follow-through, secondary
  action, ease, arcs), and specifically which of them survive at **~200 px tall,
  4 facings, baked sprites**. Several will not; the point of the survey is to
  find out which, rather than to apply all twelve out of reverence.
- **R2 — Open-source resources.** Motion-capture libraries, rigged CC0 humanoids,
  animation sets. **The licence filter is already ratified and is hard: D57 — CC0
  only.** Two known failures are recorded there (Meshy free tier is CC BY 4.0;
  SMPL-X/MANO are non-commercial research) and must not be re-litigated.
- **R3 — The authoring pipeline.** How a pose gets from reference → rig → baked
  frames → judged. The bake half is built and proven (§1); the **authoring** half
  is currently "a Python function that writes joint angles", which produced a
  moonwalk and a face-planting prone before gates caught them. Whether that
  scales to M1–M5 and their in-betweens is exactly what R3 has to answer.

**The Director supplies pose references** (*"Eu posso fornecer referências das
poses prontas"*), which is an input this plan waits on rather than substitutes
for.

---

## 5. The quality bar, and why "molejo" needs a method rather than a knob

*"Falta mais 'molejo' nas articulações, mais micro movimentos."*

Recorded honestly: **the refinement pass already done is not it.** Foot roll,
eased swing, head stabilisation and a small torso counter-rotation all landed on
2026-08-16 and the answer was still *"ainda parece mecânico"*. So the next attempt
must not be another handful of hand-authored offsets — that approach has now been
tried and measured against the Director's eye once.

What that suggests, as a question for R1 rather than an answer: the missing
quality may be **secondary motion** (parts that lag and settle rather than
arriving with the joint that drives them), which is a *simulation* property, not
a pose property — and simulation is the one thing a fixed set of baked poses
cannot express unless it is baked in. That is a real tension between D34's budget
and the quality bar, and it belongs in R1's findings, not in a guess here.

---

## 6. ⛔ Sequencing — five items come FIRST

Director, 2026-08-16: *"Entretanto, antes de entrar na milestone de movimento,
vamos aproveitar que já temos o personagem empunhando a arma, e finalizar:"*

| | Item | Where it lives | State found 2026-08-16 |
|---|---|---|---|
| 1 | **Firearm pre-production (W-PRECOOK)** | `WEAPON_MASTER_PLAN` §0 / D30 | **Its deferral condition is now DISCHARGED.** D30 postponed it *"until the character exists and can hold the weapons"* — that is true as of today |
| 2 | **Firing with the wielded weapon**, decorative projectiles | `WEAPON_MASTER_PLAN` D21 | ⚠️ **Amends D21**, which ratified *"the projectile does not exist in the scene — no travel, only its consequences are drawn (animations are later)"*. "Later" is now |
| 3 | **An enemy variant of the figure** — other appearance and colours | `CHARACTER_MASTER_PLAN` Part 7 | Guards are still red vector diamonds. D34 says colour is a **free shader uniform**, so a tint variant should be cheap; a different *appearance* is not the same claim |
| 4 | **A shot that MISSES and hits a wall**, no combat yet | `WEAPON_MASTER_PLAN` D27/D30 | The miss path is **built and shipped** — on the bench, which has *"no turn and no shooter"*. What is new is firing it from the AGENT |
| 5 | **Close the destruction milestone** + glass, fabric, cardboard | `DESTRUCTION_MASTER_PLAN` | That plan is **CLOSED (2026-08-13)**, so this REOPENS it. Glass was deferred with a stated reason (D32: no DENTED/CRACKED tier, cracks become a future multi-voxel system); **fabric and cardboard are entirely new materials** |

This document resumes when those close.

---

## 7. Open questions

1. **Does the shipped walk survive M1?** It is upright and level-headed; M1 is
   hunched and looking around. Probably a replacement rather than a revision —
   but it stays as the proof of §1 either way.
2. **What drives a pose from the WORLD rather than from the agent?** M2 and M3
   depend on adjacency. `cover_state`/`cover_direction` exist and have never
   driven a visual.
3. **Does §4.7's crouch band still describe M4?** It was measured against a
   symmetric squat, not against one-knee-down.
4. **How many transitions actually need frames?** D47's precedent says assume
   snap and make each exception earn itself.
5. **Can baked sprites carry secondary motion at all** (§5), or does "organic"
   have a hard ceiling in this rendering model? The most consequential one, and
   the reason R1 is a survey rather than a formality.
