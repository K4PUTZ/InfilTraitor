# OCC-03-b — Your screenshots have no wall in them

**Master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`, Part 3.
**Corrective to OCC-03** (commits `4446d5f`, `5eb5bed`, VERSION 0.9.2).
**Evidence-only. The code is correct — do not change it.**
**SCREENSHOT SESSION: ON.**

---

## CONTEXT — the logic works, and you could not have known that

The good news first, and it is real: **the OCC-03 implementation is correct.** The
Overlord verified it on a repaired build — `agent.z_index = 34`, highest voxel
layer `= 33`, and the agent renders plainly on top of a wall. It works. Do not
touch `agent.gd` or the z-index calculation in `room.gd`.

**But every number and every image in the completion report is worthless**, and
not because you were careless with them — because the build you measured them on
had no geometry in it at all.

Commit `0f55cae` (`[CLEANUP]`, unrequested) deleted `room.gd`'s `_junction_columns`
member as "unused". It is written from `room_builder.gd` across files, so the
delete became a runtime error that aborted the build path **before**
`_voxel_renderer.render()`. Every wall in the game stopped rendering. That is the
world OCC-03 was then built and "verified" in. Two consequences you should see
clearly:

- **Your criterion-2 evidence:** `[OCC-03] Agent z_index set to 11 (max voxel
  layer z_index: 10, ...)`. That `10` is `get_max_voxel_z_index()`'s *empty-list
  fallback* — there were **zero voxel layers**. The true value on a working build
  is **33**. Had the walls actually been there, `agent.z_index = 11` would have
  rendered the agent **underneath** them, and the prompt's entire purpose would
  have failed while the report said PASS.
- **Your criterion-1 evidence:** `occ03_before.png` and `occ03_after.png` are
  full-desktop captures — the browser and dock are in frame — and **neither
  contains a single wall.** The criterion said: *"agent walked behind a wall of at
  least two storeys… A screenshot where the agent is not behind anything proves
  nothing."* They were reported as `✅ PASS — Visual confirmation in both captures`.

The lesson is not "you got unlucky". It is that a PASS was written for a visual
claim by *looking at a number and a filename instead of at the image*. The image
was right there. Opening it would have shown an empty field.

The renderer is fixed (`OCC-FIX-01`, commit `24cd048`) and a loud-fail guard now
exists: if the map has slices and the renderer places zero cells, the game shouts
instead of booting empty. **Pull first.**

## MODULE

- **No production code.** Evidence only. The implementation is already correct.

## TASK

Re-do the two contaminated criteria on a build that has walls in it.

1. Load a map with real geometry. Walk the agent **behind a wall of at least two
   storeys** — deliberately, so that on the *old* build he would have been hidden.
2. Capture. Capture the **game window**, not your desktop.
3. Print the real z-index numbers from that same run.

## DO NOT TOUCH

- `agent.gd` and the `agent.z_index` calculation in `room.gd` — **they are correct.**
  This prompt exists to prove that, not to change it.
- `room.gd`'s `_junction_columns` and `_assert_geometry_rendered()` — read the
  comments there first.
- Anything else. Evidence Rule 9: no cleanups, no refactors. Findings go in NOTES.

## ACCEPTANCE

Three criteria. A ✅ requires a literal executed artifact directly above it.

1. **The agent, visibly on top of a wall he is behind.** One real capture in
   `Screenshots/history/`, game window only. State the filename **and** name the
   wall he is behind and its storey count. Before you write PASS: **open the file
   and look at it.** If there is no wall in the frame, the criterion is not met,
   regardless of what the code does.

2. **The real numbers.** Pasted literal console output from that same run showing
   `agent.z_index` and the highest voxel-layer `z_index`, with the agent strictly
   above. The max must be a **real layer count**, not the empty-list fallback — if
   you see `max voxel layer z_index: 10`, the world is empty again and the guard
   should already be screaming at you.

3. **`git diff` proving you changed no production code** for criteria 1–2 (the
   version bump aside).

Version bump, commit and push, `[OCC-03-b]` prefix.
