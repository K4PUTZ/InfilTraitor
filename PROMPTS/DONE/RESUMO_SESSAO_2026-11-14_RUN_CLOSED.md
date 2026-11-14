# Session record — 2026-11-14 (later): the RUN closed

MOVEMENT milestone. The Director closed the RUN for both figures: turning on the first tap, the authored start, the loop, two authored stops per figure, and the coat's corrective keys on in the idle and the walk. Commits `79a074e6` → `cd741189`, all on `main`.

## What was built

| Piece | What it does | Where |
|---|---|---|
| Turn on the first tap | The idle agent turns toward a selected destination; the second tap starts the move, even mid-turn. With no second tap the idle keeps playing | `ActorPose.turn_aim_dir`, `SelectionController._turn_toward`, scenario step `turn`, take `agent_turn` |
| Run start | The Director's timeline: the left foot stays planted, the body projects forward, ends one step ahead on run frame 14. The agent accelerates out of the idle (the first GU follows the authored travel) | `SEQ_run_start_<FIG>_arm6.blend` → `sequences/<fig>/run_start.json`; `TripoFigure.FOOTED_CLIPS`; `Agent._dash_start_profile` |
| Run stops (one per foot) | Contact on that foot, a braking step with the other foot, then the striking foot closes into idle frame 90. It has to be two steps: at contact the hips are only ~0.19 figure-m behind the striking foot and still at full speed | `tripo_pose_lab.run_stop_new`, `SEQ_run_stop_<L\|R>_<FIG>.blend` → `sequences/<fig>/run_stop_<l\|r>.json` |
| Stop choice (option A, fixed length) | At a dash's first frame the mesh picks the foot whose run contact (frame 14 right, 21 left, the same on both figures) lands nearest where the stop must start. It evens the stride (`_phase_k`, 0.7–1.4) so the contact lands exactly there. The last step follows the stop to rest on the cell's centre; the idle resumes at frame 90. Each dash logs `[RUN-PASSAGE] <fig> dash of N GU: stop on the <side> foot, stride xK` | `ActorMesh3D._plan_stop`, `Agent._step_next`, `ActorPose.stop_t / stop_side / dash_len` |
| 6° arm opening | Moved out of the code into the bank's `idle.glb` (`glb_open_arms.py`; `ARM_OPEN_DEG` deleted). After the move the clips match the previous ones within 0.36° (importer noise) | `ASSETS/ANIMATIONS/bank/*/idle.glb` |
| Timelines rebased | The frame 1 of draw, throw and run start, and the throw's frame 26, are the new idle (frame 90 with the 6°). **Edit the `_arm6` files** | `SEQ_draw_pistol_<FIG>_arm6.blend`, `SEQ_throw_overhand_<FIG>_arm6.blend`, `SEQ_run_start_<FIG>_arm6.blend` |
| Coat keys in the game | IdleFix is on in the idle (fades as the aim rises; a throw drives it while it plays). WalkFix is on while walking, RunFix while running. The coat keys of the start and the stops play frame by frame | `ActorMesh3D._update_run_coat` |
| Long-run take | `agent_run_long`: a straight 12 GU dash with a wide camera (dev flag `MOVE_POINTS_PER_AP`, capture only) | `maps/PLAYGROUND.map.json` |

## Measured

- The run loop: 30 frames (1.25 s), about 3.8 GU, four footfalls (right on 14 and 29, left on 6 and 21). The Director saw no seam on the 12 GU run.
- Stops: 13 frames (~0.5 s), 0.66–0.70 figure-m (~0.8 GU).
  - The planted foot does not slide, and no foot point goes below the floor.
  - Shins fall short of their target by at most 4.5 mm (male) and 8 mm (female).
- Stop choices logged (`[RUN-PASSAGE]`):

| Dash | Male | Female |
|---|---|---|
| 6 GU | left ×1.093 | right ×0.898 |
| 12 GU | left ×1.016 | left ×1.025 |

## Rulings by the Director

- **Transitions carry the game pose at both ends:** the first and last frames of a transition hold the full in-game pose of the clips they join, coat keys included.
- **Stop length:** option A, a fixed-length stop; the game evens the run's stride so the contact always lands at the same distance before the cell's centre.
- **The 6° opening belongs in the clip data, not in code** ("uma bela armadilha pro futuro").

## Open

- No take shows the male's right-foot stop in the game.
- Several coat keys are empty (they exist but change nothing):
  - `StopRFix_*` on both figures;
  - `StopLFix_f09` on the male;
  - `StartFix_f13` on the female.
- A possible 1.2° yaw snap where the start hands over to the run (the run clip is turned 1.2° to line up with the figure's front).
- WalkFix and IdleFix switch instantly at the walk ↔ idle cut (the same snap as the clips, D47).
- A 1 GU dash has a start but no stop, by design: the stop needs a GU of its own.
