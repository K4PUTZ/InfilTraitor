# RESUMO_SESSAO — 2026-08-16 (the placeholder is gone, and he walks)

**Version:** 0.9.103, unchanged — no bump asked for, no tag.
**Commits:** `c748aa1f` (the swap), `1754ef62` (the walk + the bracket). Both pushed.
**Evidence:** `Screenshots/history/p3_agent_{standing,crouch,prone}.png`,
`p3_postures.png` / `p3_postures_3x.png`, `p3_step_bracket_sheet.png`, and the
untracked-by-policy `p3_step_bracket_blind.mp4`.

---

## The one-line version

**Part 2 is CLOSED** — `agent.gd::_draw()`'s vector placeholder is deleted and the
baked figure is the playable agent, at three postures and four facings under the
room's real light. **Part 3 is open and moving**: an 8-phase distance-driven walk
cycle runs in the real game, and the step duration is out for the Director's
blind judgement.

---

## 1. What the Director asked, and what that turned out to require

*"Precisamos criar um mínimo de animações para ele se movimentar pelo cenário."*

Reading the code first changed the shape of the task three times:

| Found | Consequence |
|---|---|
| The boneco was a **prop**; the thing that moves was still the green diamond | The animation had nowhere to live until Part 2 §10's swap happened |
| `_draw()` drew **three** posture shapes | A single standing sprite would be a regression. The minimum is 3 poses × 4 facings, not 4 frames |
| `STEP_DURATION` 0.13 s over a 1.60 m GU is **12.3 m/s** | No walk cycle survives it; the duration is a Director call and it blocks the cadence |
| D47 was already ratified | Movement needs **no** transition yaws — the walk is 4 facings, not 96 |

---

## 2. Three times a measurement overturned my own reasoning

**1. The crouch band was reachable all along.** The first crouch hit §4.7's
5.0–6.2 voxels by folding the spine and read as a crawl on the rendered sheet. I
concluded the spec was unreachable as a real crouch and changed the solver's
target to argue around it. Then I probed instead: **legs alone, torso upright,
reach 6.17 voxels at thigh −130 and 5.62 at −150** — the whole band, no torso
fold at all. The objection was my reference pose, not the spec. Target restored
to the band's centre; ships at **5.60 voxels**.

**2. The knee had to be driven by velocity, not position.** `max(0, -sin)` leaves
BOTH knees straight when the legs pass through vertical, so phase 0 and phase 4
of 8 rendered **byte-identical** and the cycle collapsed into two identical
half-cycles — `s2_corner_render.py`'s four-footfalls defect, reached from the
other direction. `cos` is the derivative of `sin`, so `max(0, cos)` names the leg
swinging forward. Verified by hashing: **8 distinct frames of 8**.

**3. The panels' backgrounds were not different.** The first bracket still looked
like four different camera setups. Measured before acting: frame 0 of each run
differs from the others by **~9 000 px on a 921 600 px frame** — the agent's own
silhouette. The camera was identical; the STILL was sampling four loops at
unrelated points. Fixed the still, not the capture.

---

## 3. Two bugs the gates caught, both worth the gates

- **`export_posed` had only ever run ONCE per Blender session.** Three calls leave
  `arm.scale` at 1.0537, so armature space stops being world space: the crouch's
  measured −0.4063 m ground correction moved the figure −0.4281 m and left it
  0.0218 m under the floor — *exactly* 0.4063 × 0.0537. It also never removed the
  GLB it re-imports to verify itself, so posture N's file would have contained
  postures 1..N−1 as loose geometry. Fixed by reopening the `.blend` per posture,
  which cannot rot the way a cleanup list can.
- **A height typed twice went stale within the hour.** The crouch bake command
  carried 1.220 m from an earlier run against a file measuring 1.120; the Godot
  height gate rejected it. Heights now travel in the manifest, measured off the
  shipped GLB, and the contact sheet reads its caption from there.

---

## 4. One behavioural change that is not about the character

`occlusion_set.gd`'s agent silhouette was **22/61** — the vector diamond's — with
a comment instructing a hand re-sync when the agent's on-screen size changed. It
changed: the baked figure measures **104 × 222 px**, so the old pair understated
him **3.6× in height** and a wall tower overlapping his head triggered no ghost
at all. Re-synced; `occlusion_set_test.gd` (outside the selftest glob) passes 5/5
against it.

---

## 5. What is waiting on the Director

**The step duration** — `p3_step_bracket_blind.mp4`, four panels looping
together, blind labels, order randomised under a fixed seed with the slowest not
last, and judged on a figure that has legs (the turn test's objection 3, applied
before the fact rather than after). Key in `p3_step_bracket_blind_KEY.json`.

**How to read the answer:** a pick in the MIDDLE is a real optimum; a pick at
either END means the range still is not bracketed and it has to run again wider —
the same conclusion the turn test's first pass reached.

---

## 6. Where the next session starts

1. Apply the ratified step duration to `agent.gd::step_duration`.
2. **The phase count is the walk's own open question** — 8 is the classic count,
   not a ratified one. It is the counterpart of D46's in-between count and the
   same blind machinery re-runs it.
3. Smaller things, all stated rather than hidden: the walk is **standing-only**
   (crouch-walk and crawl are separate poses, unbuilt); the walk has **no DEV
   VISION bake**, so the yellow joints drop out during a step; `AgentProbeProp`
   still duplicates `AgentSprite`'s relight logic; and the **guards are still red
   vector diamonds**, which is Part 7 and is now very obvious on screen.
4. Pending D-rows in `ACTOR_MASTER_PLAN` for the postures and the walk.
