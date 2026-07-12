# OCC-03 — The agent draws on top

**Master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md`, Part 3 (O7) — **first half.**
**Baseline:** tag `verified/v0.9.0` (= HEAD).
**Wave 1. Independent of OCC-01 and OCC-02 — may run in parallel.**
**SCREENSHOT SESSION: ON for this phase** (already turned on by OCC-01; if you
run this one first, run `python3 tools/persistent/screenshot_toggle.py --on`).

---

## CONTEXT

The complaint this closes: **"I can't see my agent behind a wall."** The fix
reveals exactly one thing — your own guy — and it touches no voxel state.

**Part 3 has been split.** O7 asks for the agent on top *and* a silhouette stroke
over the portion of him that is behind geometry. The stroke is a **consumer of
the occluded-cell set** (OCC-01): implementing it independently would mean
re-deriving that set a second time, which is the project's split-brain pain. So:

- **This prompt (OCC-03):** the agent draws above all geometry, with a
  placeholder bounding box at standing-character dimensions.
- **OCC-04 (Wave 2):** the stroke, restricted to the portion actually behind
  geometry, reading OCC-01's set.

### Why he vanishes today

`room.gd` line ~349 sets `agent.z_index = 10`. `room.gd` line ~89 sets
`WALL_BASE_Z_INDEX = 10`, and `VoxelRenderer._ensure_voxel_layers()` gives each
voxel layer `z_index = WALL_BASE_Z_INDEX + level`.

So the agent **ties** with level-0 voxels and **loses to every level ≥ 1**. That
is the entire bug. There is no depth subtlety here — it is one number.

Note there is a **second, divergent copy** of the constant:
`room_builder.gd` line ~677 declares its own `WALL_BASE_Z_INDEX := 8`. Do not
"fix" it in this prompt — but do not derive your value from it either. Report it
in your completion notes; it is a split-brain smell and it will get its own
prompt.

### No character art exists yet (O7)

There are no character animations, so v1 ships a **placeholder bounding box** at
standing-character dimensions. The agent currently draws a posture-dependent
diamond in `agent.gd::_draw()` — keep that; the box is the silhouette proxy the
stroke will later be clipped to.

## MODULE

- `godot/scripts/agents/agent.gd` — the placeholder bounding box.
- `godot/scripts/world/room.gd` — the z-index.

## TASK

1. **The agent draws above every voxel layer, on every map.** Do not hardcode a
   magic number that happens to work on today's tallest map; derive it, or pin it
   with a named constant *and* an assertion that it exceeds the highest voxel
   layer's `z_index` for the loaded map. It must stay **below** the dev hover
   label (`z_index = 200`).

2. **Placeholder bounding box** at standing-character dimensions, drawn in
   `agent.gd`. It is a debug-visible rect for now — OCC-04 will clip the stroke
   to it. Its dimensions are tuning: name them as constants.

3. Guards (`enemies_root.z_index = 10`) are **out of scope**. Actor visibility
   belongs to the agent-knowledge system, never to geometry (O2) — do not make
   any actor's rendering depend on geometry. Leave them exactly as they are.

## DO NOT TOUCH

- `Voxel.visible`, `damage_state`, dirty flags, `_blocked_cells` (O1).
- `VoxelRenderer` — no placement changes, no TileSet changes.
- `enemies_root` / guard rendering (O2).
- `room_builder.gd`'s divergent `WALL_BASE_Z_INDEX := 8` — report it, don't fix it here.

## ACCEPTANCE

Four criteria. Paste literal output; a described result is not a result.

1. **He is visible behind a wall — shown, not asserted.** Two real screenshots in
   `Screenshots/history/`, same map, agent walked **behind a wall of at least two
   storeys**: one before your change, one after. In the "after", the agent is
   plainly visible through/over the wall. State both filenames. A screenshot where
   the agent is not behind anything proves nothing — pick the position
   deliberately.

2. **It holds on a tall map.** Paste a runtime print of the highest voxel layer
   `z_index` for the loaded map alongside `agent.z_index`, showing the agent is
   strictly above it. Do this on the tallest map available, not the first one that
   boots.

3. **Guards did not move.** Paste `git diff` for `enemies_root` /
   `enemy` z-index lines showing **no change** (O2).

4. **Lint.** Pasted literal output of `python3 tools/persistent/project_lint.py`
   showing zero real compile errors.

Version bump, commit and push per the Git & Push Protocol, `[OCC-03]` message
prefix.
