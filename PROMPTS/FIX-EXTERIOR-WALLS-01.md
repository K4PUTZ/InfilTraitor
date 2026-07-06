# FIX-EXTERIOR-WALLS-01: Exterior Walls Become First-Class Edges (fixed height, no config knob)

**Status:** Ready for implementation
**Predecessor:** FIX-VOXEL-HEIGHT-01 (correct storey→level math is what exposed this — the "N-floor stacking" mechanism produced absurd heights once levels-per-storey was fixed, revealing it was never a real wall system to begin with)
**Directive (verbatim intent, ratified by Matt):** exterior walls should exist, but be "só paredes mesmo" — ordinary facade walls with their own slices, subject to occlusion, destruction, and lighting like every other wall in the game. No artificial visual ceiling, no user-configurable "wall height" knob, no separate code path. Height is fixed (8 storeys initially) because only the ground floor is playable — upper floors exist purely to verticalize the scene.
**Scope:** Delete the legacy "N-floor stacking" mechanism (`wall_height`/`wall_levels` duplication in `MapCompiler`, the `Wall Height` debug-panel field, `_upper_course_tile()`); make `EdgeExtractor`'s wall branch assign a fixed storey height to every exterior-wall Edge, routed through the exact same Edge/Slice/bake/theme pipeline solid blocks already use.
**Effort:** ~2–3 hours
**Risk:** Medium — touches the perimeter-wall code path every map depends on; verify against all 3 existing maps before calling it done

---

## Item 0 — Ground truth: what exists today, and exactly what's being removed

### The current mechanism (`map_compiler.gd:105-125`)

```gdscript
## --- wall storeys (N-floor stacking) ------------------------------------
var wall_height: int = int(context.get("wall_height_override", 0))
if wall_height <= 0:
    wall_height = int(spec.get("wall_height", 1))
wall_height = maxi(1, wall_height)

var wall_levels: Array = [wall_tiles]
if wall_height > 1:
    var solid_ring: Array = MapGeometryClass.build_room(outer_rect, [])["wall_tiles"]
    for _level in range(1, wall_height):
        var course: Array[Dictionary] = []
        for entry: Dictionary in solid_ring:
            course.append({"cell": entry["cell"], "tile_name": _upper_course_tile(...)})
        wall_levels.append(course)
```

This builds `wall_height` **duplicate copies** of the solid outer ring (no door gaps — only the ground course, `wall_tiles`, has doors) and stacks them as separate array entries. `EdgeExtractor.extract()` (`edge_extractor.gd:47-88`) then derives each wall Edge's `storey_count` by **counting how many of those array slots contain a `wall_` tile at that cell** — i.e., "height" is encoded as "how many duplicate courses did MapCompiler bother to generate," not as a real per-wall field. Two more things confirmed while reading this code, both relevant:

- **Exterior wall material is hardcoded.** `edge_extractor.gd:80`: `Edge.between(cell_a, cell_b, 1, "concrete")` — every exterior wall edge is `"concrete"` regardless of anything in the spec. This was already true before this prompt; not introduced by FIX-VOXEL-HEIGHT-01, and not something this prompt is asked to change (no facade/material selection for exterior walls was requested) — just noting it so nobody mistakes fixing the height mechanism for also fixing this.
- **Doors are just omitted cells.** `MapGeometryClass.build_room()`'s door-gap logic already lives entirely in the single ground course (`wall_tiles`) — the duplicated upper courses use the door-less `solid_ring` instead specifically so doorways don't get artificially capped. This means **switching to a fixed-height single-course model does not lose door-gap behavior** — door gaps only ever existed in the course that survives this change.

### `map_loader_panel.gd`'s `Wall Height` field (`map_loader_panel.gd:34-42`)

A `SpinBox` (default `0`, max `8`) that sets `wall_height_override` in the context passed to `MapCompiler.compile()`. This is what Matt used to discover the giant-wall behavior. It has no reason to exist once height is fixed — remove the field entirely, not just relabel it.

### `ceiling_floors` — a separate concept, check the coupling before touching it

`map_compiler.gd:142`: `var ceiling_floors: int = maxi(1, int(spec.get("ceiling_floors", wall_height)))` — this **defaults from `wall_height`** if a map doesn't set its own `ceiling_floors`. `ceiling_floors` feeds the lighting/vision `ceiling_lift` formula (`QUICK_REFERENCE.md`: `ceiling_lift = WALL_FLOOR_STEP_PX * (max_floors + 0.75)`), which is unrelated to wall rendering height — it's a vision/lighting mechanic. **Stop-and-report checkpoint:** once `wall_height` is deleted, decide what `ceiling_floors` should default from instead (the new fixed exterior-wall-storeys constant is the obvious candidate, since it's the same "how tall is this room, roughly" concept) and confirm this doesn't change `ceiling_lift`'s computed value for any existing map that doesn't explicitly set `ceiling_floors` — if it does change, that's a lighting/vision behavior change riding on a wall-rendering fix, and must be called out explicitly in the report, not silently absorbed.

---

## Item 1 — Fixed exterior-wall height, no configuration surface

Add a single named constant — `map_compiler.gd` is the right home (this is compile-policy, not geometry primitive):

```gdscript
## Exterior perimeter walls are always this many storeys tall (verticality for scene
## composition, not gameplay — only the ground floor is playable). Not configurable:
## no spec field, no debug override. See FIX-EXTERIOR-WALLS-01.
const EXTERIOR_WALL_STOREYS: int = 8
```

Delete: the `wall_height`/`wall_height_override` reads, the `wall_levels` multi-array construction, `_upper_course_tile()` (dead once there's only one course). Keep: `wall_tiles` (the single ground course, doors intact) exactly as-is — it becomes the **only** input `EdgeExtractor` needs for exterior walls.

`result["wall_levels"]` (the key `EdgeExtractor` reads) becomes `[wall_tiles]` unconditionally — always exactly one course. (Confirm no other consumer of `wall_levels`/`_wall_upper_layers` depends on there being more than one array entry before deleting the multi-course path — `room_builder.gd`'s legacy sprite fallback references `_wall_upper_layers`; check whether that fallback is still reachable for any real map or is dead code post-SLICE-02. If it's genuinely dead — `extraction.get("edges", [])` is never empty for any map with a perimeter — say so in the report; if it's still reachable for some map type, stop and report before deleting anything it depends on.)

## Item 2 — `EdgeExtractor`'s wall branch: fixed height, not counted height

Currently (`edge_extractor.gd:82-87`), a wall edge's storey span is *derived* from how many `wall_levels` array slots contained it. With only one course now, that derivation collapses to always `1` — wrong, we want `EXTERIOR_WALL_STOREYS`. Change the wall branch to assign the fixed height directly instead of accumulating `max_storey` across array slots:

```gdscript
# Wall branch — exterior walls are always EXTERIOR_WALL_STOREYS tall (FIX-EXTERIOR-WALLS-01),
# not derived from how many wall_levels entries exist (there is now exactly one: the ground course).
if edge.id not in edge_groups:
    edge_groups[edge.id] = {"edge_template": edge, "min_storey": 0, "max_storey": EdgeExtractor.EXTERIOR_WALL_STOREYS_CONST - 1}
```

(Naming/plumbing detail left to you — whether `EdgeExtractor` imports the constant from `MapCompiler` or gets it passed in via the `compiled` dict is your call; pick whichever avoids a circular preload. The important invariant: every exterior wall Edge ends up with `storey_count == EXTERIOR_WALL_STOREYS`, `start_storey == 0`, computed once, not accumulated per array slot.)

## Item 3 — Remove the debug panel's `Wall Height` field

`map_loader_panel.gd`: delete `_height_spinbox` and its label entirely, along with the `height` read in `_on_load_pressed()` and whatever passes it into the load call (check the full call chain — `_on_load_pressed()` likely forwards `height` into a `context` dict passed to `MapCatalog.get_spec()`/`MapCompiler.compile()`; remove that plumbing too, not just the UI widget, so `wall_height_override` has no remaining producer anywhere in the codebase).

---

## Item 4 — Verification against all 3 existing maps

1. **PLAYGROUND**: District A/D solid blocks (already correct per FIX-VOXEL-HEIGHT-01) must render unchanged — this prompt only touches the *exterior perimeter*, not interior solid blocks. Exterior walls should now render at `EXTERIOR_WALL_STOREYS` storeys uniformly, with door gaps intact, no debug-panel override possible.
2. **SIGMA_01**, **TEST_BLOCKS**: same check — perimeter renders at the fixed height, compiles cleanly, door gaps still open.
3. Confirm `ceiling_floors`/`ceiling_lift` per Item 0's stop-and-report note — paste the before/after computed value for at least one map that didn't set `ceiling_floors` explicitly.

---

## Acceptance Criteria (assertion-backed, real execution evidence only)

1. **Fixed height, no config path exists**: grep confirms `wall_height`, `wall_height_override`, `_upper_course_tile` are gone from the codebase (or, if any reference legitimately must remain, name it and justify it explicitly — don't leave a partial removal unexplained).
2. **Every exterior wall Edge is `EXTERIOR_WALL_STOREYS` tall**: real printed `storey_count` for a sample of exterior-wall Edges from a compiled map, all equal to `8`.
3. **Debug panel no longer offers the knob**: confirm `map_loader_panel.gd` has no height input; confirm the load call chain has nothing left to receive it.
4. **Door gaps intact**: a real access-point cell on at least one map's perimeter is confirmed absent from the compiled wall Edge set (i.e., still a walkable gap), same as before this change.
5. **`ceiling_floors`/`ceiling_lift` disposition stated explicitly**: either "unchanged, here's the before/after number" or "changed, here's why and here's the new default source" — not silently absorbed either way.
6. **Non-regression**: `check_invariants.py`, `map_lint.gd`, and a fresh `bake_selftest.gd` run, all clean, verbatim.
7. **Screenshot**: at least one map's exterior wall at the new fixed height, next to an interior solid-block wall from PLAYGROUND District A/D for visual comparison (both should now look like normal, consistently-scaled walls — not a squat interior and a previously-giant/previously-tiny exterior).

---

## Explicitly out of scope (real design direction, deferred — do not build now)

Matt named these as the intended destination, not this prompt's job:

- **Negative storeys** (below-ground levels for smoke/fog/lava effects) — `Edge`/`Slice`/`start_storey` would need to support negative indices and `_ensure_voxel_layers()`/array-backed level storage would need an offset scheme (can't index a Godot `Array` at -1). Needs its own design pass before any implementation prompt.
- **Per-floor parallax** on movement — a camera/rendering feature, unrelated to the Edge/Slice geometry this prompt touches.
- **Lamps and light-emitting props authored on the topmost exterior floor** — content-authoring + lighting-system work, depends on this prompt's fixed-8-storey structure existing first, but is not part of it.
- **Procedural continuation beyond the map buffer** ("terminates" the scene so exterior walls don't read as a capped box) — a separate, larger system (ties into the deferred procedural-generator work already noted in MAP_MATTRESS_MASTER_PLAN's District G gap).

These are real next steps, not forgotten ideas — flagging them here so the next planning pass (a short amendment note, not necessarily a full master plan) picks them up deliberately rather than each landing as a surprise inside an unrelated prompt.

---

*End FIX-EXTERIOR-WALLS-01 prompt.*
