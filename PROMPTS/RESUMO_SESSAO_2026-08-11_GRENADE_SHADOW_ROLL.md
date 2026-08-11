# RESUMO_SESSAO — 2026-08-11 (Grenade Ground Shadow + Free Settle Roll)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-10_11_BUBBLE_FOUNDATION.md`
**Plan:** `PROMPTS/PLANNING/TARGETING_MASTER_PLAN.md` — §6.1 A and B both closed;
§7 reordered, §6.2 (wall sectioning of the dome) is now next.

---

## The one-line version

The two items the last session was holding mid-task are landed: the grenade now
casts a real ground shadow through its whole flight, and its settle roll is no
longer a fraction of a turn — it grades freely from the throw's own energy.

---

## A. The ground shadow

`object_ground_shadow.gdshader` existed and was inert. It is wired now:
`GrenadeProp` gains a shadow child fed the SAME colour frame the body is
showing, and the throw animation drives it by HEIGHT — flight, bounce, and 0 at
rest. The four resting test-zone props get 0 for free.

**The step the spec did not anticipate.** A child inherits its parent's WHOLE
transform, so counter-rotating the shadow is not enough: its ground offset gets
rotated too, and the shadow ORBITS the tumbling grenade instead of lying under
it. `_sync_shadow_transform()` undoes rotation AND offset exactly —

    parent = T(pos)·R(θ)·S(s)      child = T(R(-θ)·(0,h)/s)·R(-θ)·S(m, m·0.5)
    parent·child = T(pos + (0,h)) · S(s·m, s·m·0.5)

— a plain screen-space drop of `h` px, no rotation left, the uniform parent
scale cancelling out of the linear part. The algebra is in the docstring.

**The tuning miss, and how it was diagnosed.** The first values rendered nothing
visible. Rather than guess, a `print_debug` proved the node was in the tree,
visible, textured, holding a loaded shader, at a correct world position; then
forcing `strength` to 1.0 and the scale to 3.0 rendered a perfectly placed black
grenade. The wiring was never the problem — `FloatingCollectible`'s airborne
alpha (0.28) is too faint for a 22 px squashed silhouette when it works fine for
a baked, dilated blob. Walked back to 0.35 in flight / 0.55 on the ground.

`SHADOW_HEIGHT_REF_PX` = 90 is derived, not picked: `arc_height_for()` floors
every apex at `launch_px · 1.4` = 89.6 px for a standing throw, so even the
shortest throw the geometry allows reaches the full effect at its own apex.

**Stated substitution, not hidden.** This reads the alpha of the colour frame
already on screen instead of a baked shadow pass, because `grenade_frames/` has
none — only `grenade_collectible_frames/` does. Full rationale in the shader
header and the plan.

---

## B. The settle roll, freed

The old amount was a literal `1/16` turn multiplied by a distance factor
**clamped to [0.45, 1.5]** and measured in SCREEN PIXELS — a 3.3:1 band centred
on a fraction, which is what the Director was seeing.

The plan derived a friction model. It shipped, but re-anchored: since `ω₀ ∝ v`,
the results collapse to `T ∝ v` and `θ ∝ v²`, so `friction` and `restitution`
cancel out of the code entirely. What is left is **one free number** —
`roll_turns_at_max_range` = 1/8 turn — plus a duration at max range **derived
from the fuse** (`grenade_cook_s ÷ (1 + roll_back_duration_ratio)`), so the
longest throw comes to rest exactly as the grenade goes off and no clamp ever
truncates the very throw the effect is sized by. The ease-out is byte-for-byte
the old one: under constant friction it was already the exact solution.

Gone: `roll_reference_px`, `roll_scale_min/max`, `roll_forward_turns`,
`roll_back_turns`, `roll_forward_s`, `roll_back_s`.

---

## Verification

    project_lint.py           ✅ 205 files, 0 errors
    GDScript warnings         ✅ 0 in all three modified files
    check_invariants.py       ✅ OK
    gen_codemap.py --check    ✅ OK (regenerated, 205 scripts)
    run_selftests.py          34 clean, 1 failed — see below

Traced on the REAL `_start_grenade_throw_animation`, eight throws:

| target | GU dist | forward roll | duration |
|---|---|---|---|
| (15,13) | 2.236 | 4.59° | 0.188 s |
| (13,11) | 3.000 | 8.27° | 0.252 s |
| (11,9) | 5.385 | 26.63° | 0.453 s |
| (9,9) | 6.403 | 37.65° | 0.538 s |

Free and continuous — no fraction of a turn anywhere. And the plan's
GU-not-pixels requirement is **confirmed, not asserted**: four throws of exactly
3.000 GU in four different grid directions from (13,14) all returned identical
numbers (8.27° over 0.252 s), which a screen-px measure could not have done.

Hand-named captures (exempt from the 50-file rotation):
`grenade_shadow_flight.png`, `grenade_shadow_ground.png`, and the red/green
partner `grenade_shadow_off.png` — same binary, same map, same frame, shadow
strength forced to 0. Diffing the pair: **291 px changed, peak darkening 55.4%**.

**No capture for the roll, on purpose.** A still cannot show a rotation over
time; the trace above is the evidence rather than a screenshot claimed to stand
in for one.

---

## Unchanged from session start — both still belong to the blast work

Neither is this plan's to fix, and neither regressed:

- `detonation_choreographer_selftest` fails deterministically (the same single
  failure the last session closed on). Cause already proven: `[E-FUME] 20334c3`
  pulled soot out of `WAVE_TABLE`. Belongs to `EXPLOSION_REBUILD_MASTER_PLAN`.
- E-FRAG's post-blast debris still never fires —
  `VoxelRenderer.cell_level_to_world()` does not exist
  (`shrapnel_overlay.gd:49`, `debug_ray_overlay.gd:45`).

---

## The lesson worth keeping

"It does not appear on screen" has at least four causes, and eyeballing a dark
floor distinguishes none of them. Printing the node's real state and then forcing
the effect to an unmissable extreme separated "not wired" from "too subtle" in
one run each — and the answer was the second, which no amount of re-reading the
transform algebra would have found.
