# Session summary — 2026-09-21 — R3D-7 tail: decals and shots on materials, tested with real shots

**Resume point:** decals and shots on materials are TESTED and the defects found are fixed. The next step is R3D-8 (the 2D board and its
canon retire: irreversible, needs the Director's ratification). Everything below is committed and pushed (`5dddb6a8`, `a51fa7e8`,
`fcdde033` and the final one of the session). No `verified/` tag was asked for. Not measured on the Moto.

## What was found and fixed (in order)
1. **A real firearm shot never reached the 3D board (since R3D-1c).** Only `DetonationPresenter` called `Board3DLive`; the packed store
   mirrored every write, so every identity gate was green while the 3D wall stayed intact (brick, pistol: 0 px changed on 3D, 5 220 on 2D).
   Fix: `Board3DLive.on_shot_commit` / `on_shot_soot` (the blast's fold is now `_commit_touched`), called by `AgentShotController` and
   `Room.apply_scoped_soot` / `fade_in_scoped_soot`. Gate: `tools/persistent/shot_3d_gate.py` (red before, green after).
2. **`MUZZLE_LEVEL` was a level literal** (`get_layer(4)` null): every tracer skipped, muzzle flash aimed at the origin, both boards.
   Now `ground_plane_level()` + `MUZZLE_LEVELS_ABOVE_GROUND` (shot controller and bench). "tracer skipped" 24 -> 0.
3. **Impact smoke/sparks were culled inside the solid dented voxel** under 3D. `dispatch_impact_vfx(..., carved_side)` anchors them
   `vfx_impact_face_offset_gu` (0.25 GU) in front of the struck face; the 2D simulation is untouched. Smoke verified (concrete, wood);
   sparks share the anchor but were not seen (they end before the first capture).
4. **A shot from the east marked the wrong face, on both boards** (`plan_point_impact` mixed voxel and GU units in `carved_side_for`).
   Fixed; `blast_calculator_selftest.test_point_impact_side_follows_the_shooters_gu` added (red on the old code).

## Verified
- Real shots 2D vs 3D: identical `[AGENT-SHOT]` lines and tier tallies in every pair (S face: pistol x 9 materials, weak pistol x 9,
  SMG x 4, shotgun, sniper, rifle; SE face: 9 pistol + weak; through thin panes with pistol/rifle/shotgun). CRACKED, DENTED, DESTROYED
  all look alike on both boards (3D dents are a dark recessed frame, the 2D ones a light chip; 3D CRACKED slightly heavier).
- `run_selftests.py` 62 clean / 0 failed; project_lint, check_invariants, gen_codemap --check clean; `shot_3d_gate.py` PASSED.

## Open / next
- **R3D-8** (Director's ratification). `GUARD_REVEAL` cost, roofs of other `kind`, the ray march: as in the 2026-09-20 summary.
- **Suspected, unverified:** `reap_orphaned_remnants()` writes glass voxels outside the shot's touched set, so the 3D board may not
  remesh a fragment that falls when a later shot destroys its frame (needs a two-shot pane scenario).
- Not verified: the CRACKED art on a lit wall (a real shot makes CRACKED only after a pane and the walls behind are dark); sparks
  (need a capture inside the impact frames); the Moto and the Galaxy for the shot path; a second map.
- A blast's marks on a lit wall read weaker on 3D than 2D (look tuning, deferred by the Director). The playable-area red line in the
  3D captures is `_draw_playable_boundary()` (DEV_VISION), not a defect. 2D and 3D differ by 116 416 light-plane texels at load
  (not investigated, not compared by any gate).
- Working tree carries two things NOT from this session: `docs/production/current_state.md` (modified) and an untracked
  `Library INFILTRAITOR alias`; `docs/measurements/` is untracked.
- Harness (memory `state-gate-blind-to-render-notify`): `INFILTRAITOR_SHOT_WEAPON` / `SHOT_AGENT_CELL` / `SHOT_GUARD_CELL` (RUNTIME cells =
  authored + 1) + the `shoot` scenario step; a test-only `weak_pistol` lives in `user://weapons`.
