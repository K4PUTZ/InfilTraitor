# Session summary — 2026-09-20 — R3D-7 closes: the cutaway's cost, guards behind walls, roofs as an entity

**Resume point:** R3D-7 (the cutaway) is built, measured on the Moto and its gaps are closed or recorded. The
Director asked, at the end, for **decals and shots on materials to be tested before R3D-8** (the bullet decal, the
crack from a real shot and a shot through a pane are the untested part: GLASS has no guard, so the one scenario the
R3D-6 items were measured in, a blast, could not fire a round). Then R3D-8 (retire the 2D board and its canon):
irreversible, needs the Director's ratification. Nothing below is pushed-and-tagged: no `verified/` tag was asked for.

## What the Director decided (in order)
1. **Wall picking by ray: not built.** A click on a wall face keeps picking the ground plane, identical to the 2D.
   It reopens when the first **wall-mounted interactive object** exists (a switch, a control panel: it acts on click,
   no selection step).
2. **Guard visibility is GAMEPLAY, not physics** (vision by skills and progress). The renderer never infers "revealed";
   gameplay says so and the renderer draws it. Look, specified by the Director: the actor's **silhouette filled with
   alternating diagonal stripes that scroll, outlined in purple, 2 texels, fill UNDER the lines (two layers)**, drawn only
   where an opaque wall is nearer than the actor. Static now; a looping idle (breathing) is coming in the movement
   milestone and the plumbing to animate the silhouette is in place (noted in `MOVEMENT_MASTER_PLAN` §6.4).
3. **Glass in the cutaway stays whole.** Never ghosted, never in the occlusion set (as in the 2D).
4. **A roof opens by adjacency of its slabs, like a wall by its edges:** only the roof ABOVE the agent (and the hover
   cell) triggers; **reach 6 slabs, the last 2 fading** (an ordinary room opens whole, an immense roof opens a disc).
   **A roof is an entity of its own**, not limited to blocks (a floating roof is allowed), extensible to pointed and
   diagonal roofs later, and the natural complement of walls for the procedural scenario builder.
5. **No camera-direction depth buffer for the ray march**; **use the Moto only** for measurement (the Galaxy A16 turned
   out 3-4x faster on this workload).
6. Then, when a roof reveal cost too much on the Moto: **store roofs per GU**.

## Commits (all on `main`)
| Commit | What |
|---|---|
| `7bf20139` `[DOCS]` | wall picking decided, not built |
| `1fd61dec` `e1f08a36` `d19175db` | `occ_bench` scenario step + phase clocks; OcclusionSet keeps per-edge geometry between steps (Moto recompute 124 → 24 ms) and a 16-entry result memo |
| `21b82595` `ed056f37` `81cbe228` | cutaway ray march inlined + stops at the store's box + empty-space skip (4x4 block tops); side fills and merge (Moto cutaway 28 → 12.6 ms) |
| `54f4e04c` | fills built on demand; the hidden 2D wireframe overlay is no longer rebuilt under the 3D cutaway (-25 ms) |
| `62a2814e` `346e66f9` `37cf3c26` | revealed actors behind walls: the striped silhouette, thicker purple outline as its own layer (`GUARD_REVEAL=1`, off by default) |
| `2fce17c8` `13006a08` `e62fcc6d` `40a637be` | glass decision; Galaxy baseline; SIGMA_01; three-deep nesting on `OCCLUSION_NEST` |
| `180d09ad` `[FIX]` | `_assert_geometry_rendered` counts cells the 3D board owns (opaque-only maps no longer raise a false "render path broken") |
| `aa3b920d` `759beedc` | `OCCLUSION_ROOM`; **the `roofs` entity + roof occlusion by adjacency** |
| `a195b0d8` `60215573` | roof geometry cached; shared exposure; **the hidden 2D `apply_occlusion` skipped under the 3D board (68-291 ms)** |
| `b21252d4` `15fbdc52` | canonical digests; **roofs stored per GU** with a per-GU texture (HALL 652 → 42 ms) |
| `14e72a7c` `[R3D-6]` | decals, dents and rim wedge measured on the Moto; the comparison switches reach the APK |
| (this commit) | `tools/persistent/occ_canonical_gate.py`, this summary, plan/CLAUDE.md/DEVICE/OCCLUSION/MAP docs |

## The numbers (Moto g04s, release APK; whole agent step INCLUDING the next frame unless said)
| Case | Start of the session | End |
|---|---|---|
| GLASS, agent under a wall volume (occlusion set recompute / cutaway) | 124 / 28 ms (step 195) | 8.9 / 11.7 ms (step 42) |
| `OCCLUSION_NEST` (3 nested volumes, 300 columns) | 16 / 21 ms (step 149) | 11.4 / 15.7 ms (step 52) |
| `OCCLUSION_ROOM` (agent inside a roofed room, 1 764 columns) | 65 / 50 ms (step 314) | 15.6 / 11.8 ms (step 39) |
| `OCCLUSION_HALL` (floating 15x15 roof, 7 744 columns, the largest reveal the reach allows) | 91 / 54 ms (step 652, measured) | 14.6 / 13.7 ms (step 42) |

Set + cutaway is ~28 ms on both roof cases, inside the 33.3 ms budget. **R3D-6 items on the Moto** (GLASS, blast, median
of 3, one APK): dents +873 quads and ~15 ms of threaded remesh, decals ~8 ms, rim wedge nothing measurable; idle
identical (23.3 ms/frame); the settled scene with damage 25.9 vs 24.7 ms/frame (+1.2 ms GPU, +2 092 primitives); memory
none; the 2.5 s worst frame of a blast is the light/consequence commit and does not move with any of them.

## Findings worth remembering
1. **Hidden 2D work under the 3D board was the largest cost, twice** (`_occlusion_wireframe_overlay.refresh()` 25 ms,
   `VoxelRenderer.apply_occlusion()` 68 ms on a 5x5 room and 291 ms on a 15x15 hall) and both were OUTSIDE every clock
   I had put on the 3D path. Wrap the rest of the step in one clock before optimising the part you can see.
2. **The Galaxy A16 is 3-4x FASTER than the Moto g04s here.** The Moto is the constraint.
3. **An exact skip needs the same float32 sequence.** The empty-space ray skip adds `step` the certain number of times
   instead of running the body; a scalar closed form would have changed borderline decisions. Only ~20% came of it:
   a block that holds one tall wall never lets a rising ray skip, and a finer table does not help (8/4/2-block: 134k /
   127k / 167k body steps on NEST).
4. **A digest that depends on emission order cannot judge a change of representation.** The set became per-GU and the
   order changed; the gate became CANONICAL (sorted). `tools/persistent/occ_canonical_gate.py` holds the 7 cases.
5. **A cheap instrument can dominate what it measures:** the canonical digest (sorting strings) sat inside the timed
   window and read as a 29 ms "mesh build" on the HALL. Digest work now runs after the step is timed.
6. **A nearer wall sits LOWER on screen**, so only a taller one still covers the agent's silhouette. That is why the
   nesting fixture's walls grow (3, 5, 7 storeys) and why an equal-height first draft ghosted nothing.
7. **The map format only generated roofs over solid blocks.** A roof over walkable floor was not expressible, which is
   why the interior of the ring fixture had no ceiling and the Director's "roofs are an entity" ruling was needed.
8. **The 2D agent is always drawn on top of the scenery (OCC-03); the 3D billboard is depth-tested.** An unghosted
   roof that hides the agent in 3D is invisible in the 2D. Roofs beyond the reach also stay solid; corner-touching slabs
   count as adjacent (an ASSUMPTION of mine, `ROOF_ADJACENT_CORNERS`; edge-only left the room's near corner over the agent).
9. **`OS.get_environment` flags never reach an APK.** `DECALS3D` and `GLASS_OPENINGS3D` were unusable for an on-device
   A/B until `Board3DLive.build()` / `GlassCrackMirror3D.setup()` read `DevFlags` as well (same trap as `CUTAWAY_ON`,
   which STILL reads the environment only).
10. **A second `_recompute_occlusion` consumer read a Dictionary of 7 744 entries** four times per step (compare, exposure,
    texture, expansion). Per-GU roofs cut it ~64x; the roof half of the cutaway is now a per-GU texture next to the
    per-column one, the shader asks the column first and the GU only when the column has no texel.

## Tooling added
Scenario steps `occ_bench <a> <b> <reps>` (per-phase clocks and canonical digests) and `place_guard <i> <x,y>`;
flags `GUARD_REVEAL`, `DECALS3D`, `DENTS3D`, `GLASS_OPENINGS3D`; fixtures `OCCLUSION_NEST`, `OCCLUSION_ROOM`,
`OCCLUSION_HALL`; selftests `roof_occlusion_selftest` (17 + exposure + per-GU checks), `roof_entity_selftest`,
`mapfile_roundtrip_selftest` case 5 (62 in all); `occ_canonical_gate.py`.

## Open / next
- **Decals and shots on materials (Director: before R3D-8).** Needs a map with a guard behind glass and behind each
  material; the bullet decal, the crack from a real shot, the rim wedge on a shot (a blast's voxel hole is usually larger
  than the polygon, so it barely draws there).
- **R3D-8**: needs the Director's ratification (irreversible). Wall picking reopens with the first wall-mounted object.
- `GUARD_REVEAL` is OFF until gameplay asks; the frame cost of SEVERAL revealed guards is unmeasured (two extra quads
  per sprite part). A roof of `kind` other than "flat" logs a `push_error` and is skipped (that path is untested).
- A roof activated only by an occluded wall of its own structure keeps the OLD stripe rule (`MAX_RING`); only a roof an
  origin stands UNDER uses the adjacency rule.
- The ray march is still 4-9 ms on the Moto; a camera-direction depth buffer would cut it but was declined.
- Not measured: the Galaxy for the roof cases, the upper storey (the game does not play one).
- Working tree carries two things that are NOT this session's: `docs/production/current_state.md` (modified before it
  began) and an untracked `Library INFILTRAITOR alias`.
