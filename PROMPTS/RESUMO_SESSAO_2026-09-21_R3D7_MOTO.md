# Session summary — 2026-09-21 (second session) — R3D-7 tail: the shot path, sparks, GUARD_REVEAL and touch, on the Moto g04s

**Resume point:** the R3D-7 pending tests that could be run were run on the Moto (release APK from `083ce9b6` + two DEV knobs). The one item
left that needs a hand is the **pinch**. Next is **R3D-8** (the 2D board and its canon retire: irreversible, needs the Director's ratification).
Full record with the numbers: `RENDER3D_MASTER_PLAN` v1.11. No `verified/` tag was asked for.

## What was tested (and the answer)
| Pending item | Result |
|---|---|
| A real shot on the Moto (the v1.10 fix was "not measured on the Moto") | Works. Brick/pistol 3D vs 2D control: identical `[AGENT-SHOT]` line and tiers; wall band 11 626 px (3D) vs 18 924 px (2D). Also metal, glass, concrete/shotgun, wood, and a shot from the EAST (mark on the SE face). Tail 593-611 ms (2D 745), of which 572-585 ms is the light repaint, shared by both boards |
| Sparks (v1.10: "not seen") | Seen, both boards, desktop and Moto (burst in frame 2 on the desktop, frame 4 on the Moto; tracer in frame 2) |
| `GUARD_REVEAL` with several revealed guards (unmeasured) | 8 guards, 6 boots: +12 draw calls, +24 primitives, GPU 22.4-23.5 ms on vs 25.1-25.2 ms off. Not slower (the on side was faster: unexplained) |
| Touch/picking on the Moto (R3D-5: "not run") | Tap selects exactly the cell under the finger, second tap walks, drag pans (`camera.pan_end`); same as the 2D. **Pinch: not automatable** (SELinux blocks `/dev/input` writes for `shell`) |
| `reap_orphaned_remnants()` (suspected) | Analysed, NOT reproduced, NOT fixed (needs a two-blast pane scenario on GLASS at a chunk edge). The `glass_reap_demo` mismatch on 3D is the demo mutating without telling `Board3DLive` |

## Code changed (both DEV knobs, defaults unchanged)
- `agent_shot_controller.gd`: `SHOT_WEAPON` reads through `DevFlags` (it was environment-only, inert on an APK).
- `room.gd` `scenario_shoot`: `SHOT_SETTLE_FRAMES` (default 30) replaces the hard-coded 30 frames after the round.
- `RENDER3D_MASTER_PLAN` v1.11, this summary, CODEMAP regenerated.

## Verification
`project_lint.py` PASSED; `run_selftests.py` 62 clean / 0 failed; `check_invariants.py` OK; `gen_codemap.py --check` after regenerating;
`shot_3d_gate.py` (see the commit message for its result).

## Open / next
- **Pinch: DONE by the Director's hand** (`camera.zoom_end via=pinch` 0.259 ... 1.200 ... 0.200, both clamps hit).
- **R3D-8** (Director's ratification). Still open in R3D-7: the reap suspicion, the CRACKED art on a lit wall, a second map, the Galaxy A16 for
  the shot path, roofs of `kind` other than "flat" (logged and skipped), the ray march (4-9 ms).
- A lead not taken: a shot costs 0.57 s of light repaint on the Moto (the field is built map-wide by design, D24), not a render cost.
- Working tree carries two things NOT from this session: `docs/production/current_state.md` (modified) and an untracked
  `Library INFILTRAITOR alias`; `docs/measurements/` is untracked (the Moto logs of this session are in it).
- Harness traps met (in the plan): boot on the Moto is 55-70 s so `device_run.py --seconds` >= 150; script-started `logcat` processes pile up;
  macOS has no `timeout`.

## Addendum — the last pending items (same day, Galaxy connected)
Galaxy A16 shot path (identical lines; 3D brick tail 357.5 ms vs 2D 213.9, opposite of the Moto, one boot each, not investigated); the reap
HARDENED (returns its felled voxels, `WorldDelta.reaped_voxels`, both callers hand them to `Board3DLive`; a real two-blast GLASS run fires a
real reap without errors); CRACKED art on a lit wall compared; second map SIGMA_01 identical; unknown roof kind tested in `roof_entity_selftest`.
Nothing R3D-7 is open except what is by decision. Next: R3D-8. Full record: `RENDER3D_MASTER_PLAN` v1.12.

**Resume point for the next session:** start R3D-8 (irreversible). First step, before touching code: list what R3D-8 deletes (the 2D board, `floor_layer` tile data, rules 2/8, L1, B1-B6) and what the identity gate (`board_probe.py gate`, `shot_3d_gate.py`, `occ_canonical_gate.py`) must cover; then ask the Director to ratify. Open lead (not R3D-7): the Galaxy 3D brick shot tail (357 ms) was slower than 2D (214 ms), one boot.
