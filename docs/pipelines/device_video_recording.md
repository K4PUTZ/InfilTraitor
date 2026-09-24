# Recording the game on a handset

*Built 2026-09-21. One command, one file, trimmed to the scenario. Recordings live in `videos/` at the repo root, which is git-ignored.*

## Why
A still cannot show the FLOW of an effect (the order of the blast, the smoke against the scorch, a fade). The Director reviews those on a video
recorded on the Moto g04s. The soot-after-crater timing of 2026-09-21 was decided from one.

## The command
```bash
python3 tools/persistent/device_record.py --device ZF524T5TG5 --preset blast --out videos/explosao.mp4
```
- `--preset blast`: dev grenade 0 on PLAYGROUND, camera zoomed OUT to 0.5 and centred on the grenade from the start (no pan, no zoom change), fuse,
  blast, smoke, scorch. `blast100` is the same at zoom 1.0.
- `--scenario "<steps>"` for anything else (steps in `godot/scripts/systems/scenario_runner.gd`; end with `quit`; put a `mark rec` step where the
  video should start). `--map`, `--flag KEY=VALUE` (repeatable) and `--tail` are the other knobs.
- Serials: Moto g04s `ZF524T5TG5` (the constraint device), Galaxy A16 `R5CY8122K7D` (`adb devices -l`).

## What it does for you
Pushes `dev_flags.cfg` (map, `RNG_SEED=1`, the scenario), starts `adb shell screenrecord` (720x1600, 8 Mbps), runs the game through
`device_run.py`, stops and pulls the recording, **removes the flags file from the handset**, and trims with ffmpeg: the start at the scenario step
named by `--from` (default the `mark rec` step, else step 1) and the end `--tail` seconds after the last step. The cut points come from the game's
own `[SCENARIO] n/N <step>` log lines and the handset's clock, never from a guessed number of seconds (the boot and the Godot splash are ~64-72 s).

## Preconditions and traps
- **The screen must be unlocked.** A locked phone makes `device_run.py` refuse; the script then reports it. Unlock by hand (nothing types a PIN).
- Export and install the build that carries the change first: `python3 tools/persistent/export_android.py --install --device <serial>`.
- `screenrecord` caps at 180 s, so a scenario plus the boot must fit in ~170 s.
- **Cost of recording (Moto, PLAYGROUND, one detonation, 3 runs each, alternating):** frame 33.4-34.6 ms recording vs 32.3-33.5 not, GPU 24.6-24.9 vs
  23.7-23.8 ms: about +1 to +2 ms per frame. Enough to judge an effect, **not** to take a performance number from. Never record during a measurement.
- What the video shows is what the DEV flags leave on screen. The DEV VISION text panels, the playable-area line and the spawn diamond are hidden by
  default (`DEV_PANELS=1` shows them); a scenario `detonate` closes the Detonate menu like the real click.
- Video frame rate is variable (`screenrecord` writes a frame when the screen changes): do not read frame counts as timings.

## Related
`tools/persistent/device_run.py` (the launch and log capture it wraps), `DEVICE_DIAGNOSTICS_MASTER_PLAN` (the 2026-09-21 note with the measurements),
`tools/persistent/MobileTesting.md` (the web export, a different route to a phone).
