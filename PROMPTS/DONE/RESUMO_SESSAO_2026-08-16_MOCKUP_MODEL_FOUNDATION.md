# RESUMO_SESSAO — 2026-08-16 (the mockup: he is in the room)

**Version:** 0.9.102 → **0.9.103 "Alpha Mockup Model Foundation"**. No tag —
none was asked for.
**Evidence produced:** `Screenshots/history/p2_*.png`, eight named captures that
opt out of the `auto_` rotation on purpose.

---

## The one-line version

Part 2's grip spike ran and closed, and the agent now **stands in PLAYGROUND** —
near-black, relit by the room's real light registry, at a gated 10.0 voxels, four
facings visible in one frame, with a backpack and a DEV VISION joint mode.
`agent.gd`'s vector placeholder is **untouched**, so §10's definition of done is
explicitly not claimed.

---

## 1. What was built, in order

| | |
|---|---|
| **The three-grip spike** | D40's 3 grips × 2 weapons × D44's 4 facings = 24 frames at true ship size |
| **A per-facing pose fix** | `pistol/lowered` and `pistol/ready` measured **0 px** of visible weapon facing NE |
| **The in-scene probe** | posed GLB → 4-perspective bake → `AgentProbeProp` → PLAYGROUND |
| **Ten voxels** | 2.000 m exactly, Director's call, verified end to end |
| **The near-black suit** | applied to suit, trousers, shoe and hat; specular ruled out |
| **Folds and creases** | 22 seam parts, front and back |
| **Tailoring volume** | the jacket stopped being a body |
| **DEV VISION joints** | a second bake, yellow, on the existing dev toggle |
| **The backpack** | D53's stow container, finally geometry |

---

## 2. Six findings, each measured rather than judged

**1. The palette had never left Blender.** `p1_agent_model.py` authored colour
with `use_nodes = False` + `diffuse_color` — the *viewport* value. Workbench reads
it, which is why every character render this project had ever judged (T-pose
sheet, S2, the grip matrix) showed the suit/shirt/skin split correctly. **The
glTF exporter does not read it.** It reads the Principled base colour, which
reloads at Blender's default 0.8 grey. The first agent bake measured mean RGB
(234,233,233) with **53.3% of opaque pixels pure white**, and it looked
plausible until it was measured.

**2. "Ship size" was 21% wrong in two existing scripts.** `ortho_scale = 2.15`
in `p1_agent_preview.py` and `p8_sculpt_start_scene.py` is a *framing* value, not
a scale one. The game pins **115.47 px per screen-metre**; those scripts draw the
figure ~150 px where the game draws ~190. Recorded, not fixed — outside the task.

**3. The washed-out look was specular, not brightness.** Lit faces at
(182,183,199) with 7.8% clipped against a (138,138,150) albedo, and hue collapsing
from b−r +12 to +5. The white specular term blew the highlights *and* desaturated.
Dimming alone would have produced a darker grey figure instead of a blue one.
After: (137,137,152), **0.4% clipped**, hue intact.

**4. Near-black compresses volume, and that is arithmetic.**
`lit = albedo × (ambient + light·N·L)` is multiplicative, so darkening the albedo
does not move the range, it **shrinks** it. Bracketed four suit values past the
breaking point; the Director ratified the darkest and named the reason —
infiltration *wants* him hard to see, and posture still reads.

**5. The creases' problem was facing, not dose.** Asked to raise the dose,
measured first: 59 changed pixels in frame N against **879 in frame S** — a 14×
gap, because every crease was a front feature and N/E are the facings that show
the back. Raising the dose would have made 59 pixels brighter and changed nothing
the Director was looking at. Fixed by authoring the back.

**6. Isometric silhouettes are taller than their figures.** Two gates were
written comparing a measured silhouette against `height × cos(elevation)` and
**both reported false failures** (207 px and 205 px against a 189.8 px "ideal"),
because the body's own depth projects into screen-Y too. The same mistake, twice
in one day, in two languages. Scale is now gated where it can be gated exactly:
a 0.20 m rise must draw `VOXEL_STEP_PX`. It measures **20.000**.

---

## 3. Instrumentation honesty

Three measurement scripts were written and **discarded rather than reported**:
two on-screen contrast measurements that sampled floor instead of suit (one
returned an 86-level spread for an albedo whose ceiling is 7) and one hat-band
anchor that fragmented into 23 clusters. Every number in this document and in the
commits comes from a measurement that survived scrutiny.

Two errors were caught by the scripts' own gates rather than by eye: a lowered
two-handed carry that was **geometrically impossible** (the left hand 0.356 m
outside reach — leaving `shoulder_L/R` at rest was the real error), and a facing
check that reported N/E/S/W at a **perfect 1.000 fit** while the frames were
correctly NE/NW/SW/SE, because the camera transform had been written but not
flushed. A perfect fit is a reason to suspect the instrument.

---

## 4. The cost that was moved, stated not absorbed

§4.7 records the **body** at 1.80 m = 9.00 voxels, and `s2_posture_scale.py`
VERIFIED the standing/crouched/prone bands against it. Scaling the whole figure to
10.0 voxels carries the body to 1.897 m (9.48). **That verification no longer
describes this asset.** The alternative that preserves it — raising only the hat,
the question `agent_sculpt_start.blend` already draws as two labelled lines — is
one constant away in `p2_grip_spike.py::EXPORT_HEIGHT_M`.

---

## 5. Decisions the Director settled, pending D-rows in ACTOR_MASTER_PLAN

- The suit family is **near-black**, applied to shoe and hat.
- **Specular is out** for this character — *"tecido não tem reflexo duro, somente
  manchas opacas"* — and so is D28's outline.
- Volume comes from **folds and seams**, front and back.
- The joints carry the suit's colour but keep their **own material**, which is
  what made the next item cost one env var.
- **DEV VISION tints the joints yellow.**
- The **backpack** D53's costume already referred to now exists on `back_upper`.
- A very dark agent is a **design advantage** in an infiltration game, not a
  legibility problem to solve.

---

## 6. Where the next session starts

**Part 2's actual definition of done** (§10): delete `agent.gd::_draw()`'s vector
placeholder and put this baked figure on the playable agent. Everything it needs
now exists and is measured. Two smaller things travel with it:

- the hip joints are hidden under the fuller jacket hem, so DEV VISION shows three
  of four joint pairs;
- the probe has **no ground shadow** on purpose — `GrenadeProp` fakes one by
  squashing its own silhouette on Y, which is a smear on a 1.9 m figure. The
  honest version is a separate top-down pass, which `actor_frame_bake_spike.gd`
  does and this bake does not.

**Still open and not blocking:** whether `lowered` and `ready` stay two grips for
long guns — at ship size they are nearly indistinguishable, and only `aimed`
separates.
