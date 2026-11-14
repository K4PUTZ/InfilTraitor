# RESUMO_SESSAO 2026-11-14 — the dash (both AP on one move = the run clip)

## Decisions (Director)
- A move that spends both AP (the orange zone) is a DASH: the agent runs the whole path (not walk-then-run).
- Tempo kept at `Agent.dash_step_duration = 0.32` s/GU (still not written into D61, which fixes only the walk's 0.56 s).
- Order of work from here (Director, end of session): **first the characters TURN, then the idle -> run and idle -> walk passages.**
  The idle <-> move passage stays a snap (D47) until then.

## Built (commit `cc9be987`)
- `SelectionController.try_move_to`: `path_cost_to_ap(path_cost) >= 2` -> `agent.move_along_path(path, true)`.
- `Agent.move_along_path(path, dash)`, `dash_step_duration`, `_dashing`; `ActorPose.set_dash()` and `"dash"` in `mesh_state()`.
- `ActorMesh3D`: `TRIPO_RUN`, `_run_pass` (the run clip's `travel_m`); a dash plays `run`, phased by the ground covered (no slide).
- PLAYGROUND: POI `agent_dash_far` (27.5, 15.5), take `agent_dash` (six cells south). Videos in `temp/videos/PLAYGROUND_agent_dash_{male,female}.mp4`.
- `verify.py` smoke green. Not measured on the Moto (the clip swap does not move the cost by 5 %).

## Tried and reverted
- A 0.18 s idle <-> move crossfade via `AnimationPlayer.play(clip, custom_blend)`. **Trap: `ActorMesh3D` drives the clip by `seek(t, true)` every frame;
  with a blend the run clip never showed and the figure glided in the idle pose** (seen on extracted frames of the male take). Reverted, nothing landed.
  A real passage needs either our own pose mix (a weight over the two clips' bone rotations) or authored poses in Blender.

## Owed / open
- The characters turning (next), then the passages idle -> run / idle -> walk (and back), both figures, judged on video.
- The dash tempo (0.32) and the female take were judged by the Director only on video; no gate covers them.
- Guards' `move_along_path` has no dash parameter (the dash is the player's).
