# OCC-04 — The silhouette stroke, only where he is actually hidden

**Master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`, Part 3 (O7) — **second half.**
**Baseline:** commit `3fc4360` (VERSION 0.9.4). **Pull first.**
**Wave 2. Consumes Part 1. Independent of OCC-02 — the two may run in either order.**
**SCREENSHOT SESSION: ON.**

---

## CONTEXT

OCC-03 put the agent on top of everything. That alone is a lie of a different kind:
he now floats over walls with no cue that he is *behind* them. O7 asks for the
missing half — **a stroke on the part of his silhouette that is behind geometry.**
The whole silhouette when he is behind a wall; legs-to-waist when he is behind a
crate.

This is the half that was split out of Part 3 deliberately: "the portion behind
geometry" is a **consumer of the occluded-cell set**, and re-deriving that set here
instead of reading it would be a second live copy of one truth.

### What exists to build on

- `OcclusionSet.get_occluded_cells()` → `Vector2i (voxel column) → ring`, recomputed
  on map load, agent step and view change via `room.gd::_recompute_occlusion()`.
  That is the single recompute path; do not add another.
- `agent.gd` already draws a **placeholder bounding box** at standing-character
  dimensions (`SILHOUETTE_WIDTH` / `SILHOUETTE_HEIGHT`, OCC-03). The stroke clips to
  that box. There is still no character art — v1 stays on the placeholder (O7), and
  the real silhouette is a later milestone.

### The honest hard part

"Which part of him is behind geometry" is a **screen-space** question: which columns
of the occluded set actually overlap the agent's box on screen, and how high do they
rise. A wall column reaches far above its ground cell (each level lifts by
`GeometryCoords.VOXEL_STEP_PX = 20`), which is exactly why a two-storey wall hides
all of him while a crate hides only his legs.

Note the known limitation the debug overlay has here (master plan, Wave 1
post-mortem): it paints columns at level 0. **You cannot inherit that shortcut** —
the stroke needs the column's real screen *height*, not just its footprint.

If you conclude the set as it stands does not carry enough information to answer
this, **say so and stop.** That is a legitimate finding and a cheap one; inventing a
second occlusion computation inside `agent.gd` to work around it is not.

## MODULE

- `godot/scripts/agents/agent.gd` — the stroke.
- `godot/scripts/world/room.gd` — feeding the agent what it needs from the existing
  occlusion set. Read-only consumption.

## DO NOT TOUCH

- `occlusion_set.gd`'s formula — Part 1 is closed. You may *read* it. If it needs a
  new accessor, add one; do not change what it computes.
- `Voxel.visible`, `damage_state`, dirty flags (O1).
- **Guard rendering (O2).** Actors are hidden by *knowledge* — radar, noise, line of
  sight — never by geometry. An actor the agent does not know about is not drawn at
  all, which is what makes ghosting structurally incapable of leaking enemy
  positions. **Do not make any actor's rendering depend on occlusion.** If you do,
  that guarantee dies silently.
- Anything not in MODULE. Evidence Rule 9: findings go in NOTES.

## ACCEPTANCE

Four criteria. A ✅ requires a literal, executed artifact directly above it.
Evidence Rule 8: *deferred / assumed / will / available in* disqualify a ✅.

1. **Whole silhouette behind a wall.** A real capture, game window only, agent
   behind a wall of at least two storeys, stroke covering his whole outline. State
   the filename and **open it before you write PASS.**

2. **Partial silhouette behind a low obstacle.** A second real capture, same map,
   agent behind a single-storey crate: the stroke covers only the lower part of him.
   If both captures look the same, the stroke is not reading height and the
   criterion fails.

3. **No stroke when nothing is in front of him.** A third capture, agent in the
   open: no stroke at all. This is the control — without it, criteria 1 and 2 could
   both be satisfied by drawing the stroke unconditionally.

4. **Lint.** Pasted literal output of `python3 tools/persistent/project_lint.py`,
   zero real compile errors. Warnings zero-tolerance on files you touched.

Version bump, commit and push, `[OCC-04]` prefix.
