# Session summary — 2026-10-11: the glass blast optimised on the Moto; the collapse after the blast, crossfaded

Resume point for the next session. Everything below is on `main`. Detailed record: `PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` 1e, 1f, 1g.

## 1. Numbers (Moto g04s, GLASS `glass_blast` take, release APK, uncapped, two runs each)
| | heavy frames (ms) | COMMIT (ms) |
|---|---|---|
| session start | 679 / 430 / 343 / 277 | 665 |
| round 1 (picture identical) | 347 / 338 / 240 / 166 | ~215 |
| round 2 (collapse after the blast, crossfade) | 245 / 183 / 181 / 177 | 157 |
| round 3 (blast rain as a budgeted job) | **not measured: the phone dropped off ADB** | — |

## 2. What was built
- **Attribution:** `WorldDelta.commit_split`, printed with `THROW_PROFILE` as `[T-PROF] COMMIT SPLIT — …`.
- **Glass bookkeeping:** `Room` indexes cell -> pane slice and pane -> slices once per edge registry (`_ensure_glass_index`, packed
  cells, no Voxel materialised); anchor contexts per pane (`GlassShatter.remnant_anchor_context` / `rim_shard_anchor_context` /
  `mask_in_context`) reused within a loop.
- **Craze sheets** prefetched on a thread when the cook's Delta is final (`Room.prefetch_glass_crazes`,
  `VoxelBoard.prefetch_glass_crack_sheet`).
- **Rain:** field names hashed once per flight (`GlassRainOverlay._unit_p`, bit-identical, 420 000 cases), shards in a
  `PackedFloat64Array`, the shard field warmed at load (`Board3DLive._warm_glass_fall`), and the rain as a resumable job
  (`Room.begin_glass_rain` / `step_glass_rain`).
- **Persist** as a budgeted queue task (`_stage_persist_step`); the hit-stop queue's budget is the whole frame's (stage 2).
- **Collapse (Director's ruling):** no support walk in the cook any more; `schedule_glass_collapse()` walks it after the event while
  the pane stands (at least `GLASS_COLLAPSE_BLAST_DELAY_S` = 1/3 s), the landing index is awaited before the swap, the collapse's rain
  is laid paused and unpaused with the swap; `GlassVoxelFall3D.FADE_IN` 0/25/50/75/100% on each cube's thickness, the fall from
  `FALL_FROM_FRAME` 2. The broad faces and the crack are the pane's own in both looks and stay whole.
- **Take** `glass_collapse_close` on GLASS (still camera on the big pane).

## 3. Proofs
Every round: lint, `run_selftests.py` (76 clean), `verify.py` smoke PASSED. Rounds 1 and 3: the desktop take's 904 frames identical
to the code before (round 2 changes the look on purpose: judged on the `glass_crossfade_close` sheet and the take's video).

## 4. NEXT
1. Reconnect the Moto and measure round 3 (`THROW_PROFILE=1`, the take `glass_blast`); then the Galaxy (owed all session).
2. Remainders (in `technical_debt.md`): COMMIT `damage` 66 / `crazes` 35 ms, presenter commit ~110, glass tail 111-158 (the whole pane
   still on the board), the collapse's swap step ~175 ms.
3. The Director's verdict on the crossfade's look.
4. One SIGABRT (exit -6) of a desktop capture of the pre-change code, not reproduced on the rerun; cause unknown.
