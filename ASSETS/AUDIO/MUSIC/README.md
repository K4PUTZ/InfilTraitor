# MUSIC Production Workspace

This folder is the project-wide home for music production assets and tooling.

## Policy

- Keep production documents, prompts, project files, stems and final exports in Git.
- Keep raw media local only (put them inside a `Raw/` or `Bruto/` folder).
- Keep release-ready outputs in `Export/` (this folder is versioned on purpose).

## Dependencies (local .venv)

Install/update with:

```bash
.venv/bin/pip install -r ASSETS/AUDIO/MUSIC/requirements.txt
```

System tool used by audio workflows:

- `ffmpeg` (already available on this machine)

Python note:

- This workspace currently uses Python 3.14.
- `pydub` is intentionally not included because it depends on `audioop`, removed from Python 3.14.
- Use `soundfile`, `scipy`, and `ffmpeg` for conversions and processing.

## Suggested structure

- `THEME/` : theme composition and arrangement work
- `Export/` : approved rendered outputs for versioning
- `Raw/` : source captures and other heavy raw media (ignored by Git)
- `SESSIONS/` : Ardour sessions and the specs that build them (PC)

## Notes

- Current prototype reference: `THEME/Black Tux Pulse.mp3`
- Working paper: `INFILTRAITOR_Music_Authorship_Project_Paper.pdf`
- Production record (current state, PC workspace, work history): `MUSIC_PRODUCTION.md`

## Production mechanism (2026-10-18)

`python3 tools/persistent/music_pipeline.py` implements the paper's pipeline (§8-§10):

- `bible.json` is the Music Bible (paper §12): global tonal/BPM/timbre DNA, the three motifs (still `pending`, to be authored) and the seven gameplay contexts. Values marked draft are working defaults.
- `prompt <context>` builds a generation prompt from the bible with the paper's §8 template.
- `register <context> <file> --tool … --tool-version … --license …` copies a generated take to `Raw/<context>/` (git-ignored) and writes `provenance/<take-id>.json` (versioned): hash, tool, version, licence, prompt, parameters, human edits.
- `export <take-id>` masters to a -16 LUFS Ogg Vorbis under `Export/<context>/` and records its hash in the manifest.
- `check` validates the bible and every manifest (including that an export was not changed after the fact); `list` shows takes.

Generation itself (ACE-Step or a DAW) happens outside the script; its model version and weights licence go in `register`.

## Sessions: separate lines on one timeline (2026-11-12, PC)

A session is an Ardour project where every line is its own track and every clip sits on the same grid, so the Director can press play, move, loop, copy and paste. `tools/persistent/music_session.py` builds one from a JSON spec, `SESSIONS/<name>.spec.json`:

- The spec fixes `tempo`, `meter` (`N/4`) and `bars` once for the whole session. Clips are whole bars, so every line stays on the beat.
- A track is one line: a name, an instrument (`Surge XT` and a factory patch, e.g. `Basses/Bass 5`), an optional `gain_db` and its `clips`.
- A clip is a MIDI region: `bar` (start), `bars` (length) and its notes, either a one-bar `pattern` repeated over the clip or explicit `notes`. Notes are names (`E1`, `F#2`, `Bb3`; C4 = 60) or MIDI numbers.
- The timbre is a property of the track, not of the clip. Changing the patch in Surge XT's own window inside Ardour changes every clip of that track.

```powershell
.venv\Scripts\python tools\persistent\music_session.py build ASSETS\AUDIO\MUSIC\SESSIONS\bassline-e1.spec.json
.venv\Scripts\python tools\persistent\music_session.py render bassline-e1    # SESSIONS\bassline-e1\export\bassline-e1.wav, to listen without Ardour
.venv\Scripts\python tools\persistent\music_session.py open bassline-e1      # opens the session in Ardour
```

- The build reads every note back from Ardour and stops if one differs from the spec.
- Once built, the session folder belongs to the Director's edits in Ardour. `build` never overwrites it: `--force` moves the old folder aside as `<name>.replaced-<time>` (git-ignored).
- How it works: `ardour9-lua` opens a headless session and starts Ardour's own MCP HTTP surface on port 4820 for the length of the build, then switches it off again in the saved file. The port must be free, and the surface listens on every network interface while it runs.
- Needs Ardour 9 and Surge XT scanned by Ardour once (`ardour-vst3-scanner "<Surge XT.vst3>"`).
- `SESSIONS/.gitignore` keeps Ardour's scratch (peaks, backups, history, renders) out of Git. The session file, the spec and the MIDI sources are versioned.
- Not covered yet: audio clips on the same grid, instruments other than Surge XT, tempo or meter changes inside a session.

## Loose samples for listening (ACE-Step, PC)

`tools/persistent/music_sample.py` turns a free prompt into short instrumental samples with a local ACE-Step 1.5, to hear ideas and compare. Nothing is registered and the Bible is not read. It runs in the ACE-Step environment (`D:\ACE-Step`), not the project `.venv`:

```powershell
cd D:\ACE-Step
uv run python D:\INFILTRAITOR-PC\tools\persistent\music_sample.py "<prompt>" --bpm 120 --key "E minor" --duration 10 --n 2
```

Each sample lands in `ASSETS/AUDIO/SAMPLES/` as a `.wav` plus a `.json` with the prompt and seed. The folder is git-ignored. A sample worth keeping goes through `music_pipeline.py register`. `-i` keeps the model loaded and reads one prompt per line. On a GPU under 10 GiB the models are offloaded to RAM between steps (`--no-offload` turns it off): without it the second take fails the VRAM pre-flight.
