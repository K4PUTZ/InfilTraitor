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

## Addendum 2 — video, DEV panels, blast soot (end of the session)
- **Video mechanism:** `tools/persistent/device_record.py` (presets `blast` / `blast100`, `--scenario`, trims from the game's own log, removes the flags from the
  handset); `videos/` git-ignored; guide `docs/pipelines/device_video_recording.md`. Recording costs +1 to +2 ms/frame on the Moto.
- **`DEV_PANELS`** hides the DEV VISION text panels, the playable-area line and the spawn diamond by default (DEV VISION itself unchanged); a scenario
  `detonate` closes the Detonate menu; `SHOT_WEAPON` reaches an APK; `SHOT_SETTLE_FRAMES`.
- **Blast soot** now darkens after the crater in 4 timed steps (0.075 s each, `soot_step_s` / `soot_start_s` in `detonation_presenter.gd`). Decided by the Director from
  `videos/explosao_moto_fuligem.mp4`.
- **Resume point:** port the EMBERS and the FIRE to the 3D board BEFORE R3D-8 (Director). First: a real wood burn and a real ember, 2D vs 3D, `board_probe.py gate` and
  captures, to list what is actually missing (R3D-6 item 6 saw unidentified flecks over the embers under 3D). Then R3D-8 (list what it deletes and what the gates
  must cover, then ask for ratification). Per-step soot upload cost on the Moto is not measured.

## Addendum 3 — the plan is reordered (Director)
The fine look adjustment is no longer deferred: the full switch needs the 3D identical to the 2D. Order now: **look-parity pass (register in `RENDER3D_MASTER_PLAN` v1.14) -> embers and fire port -> R3D-8 last.**
Resume point: propose the paired 2D/3D capture matrix (one command) to the Director, get the order of the register, then rule item by item.

## Addendum 4 — the parity bar and the plan for the next session (nothing built)
"Identical" = the SYSTEM; tone/hue differences are fine; an item closes at **9 out of 10** closeness to the 2D feature (Director's grade). Next session, in order: (1) the paired 2D/3D
capture matrix and the Director's grades, (2) system defects first (FIRE under 3D, EMBERS port, the end-of-blast light jump, the 116 416 light-plane texels), (3) items graded below 9 (values before code),
(4) Moto measurements of what was added, (5) R3D-8 last. Details: `RENDER3D_MASTER_PLAN` v1.15.
