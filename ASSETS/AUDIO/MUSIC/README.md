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

## Notes

- Current prototype reference: `THEME/Black Tux Pulse.mp3`
- Working paper: `INFILTRAITOR_Music_Authorship_Project_Paper.pdf`

## Production mechanism (2026-10-18)

`python3 tools/persistent/music_pipeline.py` implements the paper's pipeline (§8-§10):

- `bible.json` is the Music Bible (paper §12): global tonal/BPM/timbre DNA, the three motifs (still `pending`, to be authored) and the seven gameplay contexts. Values marked draft are working defaults.
- `prompt <context>` builds a generation prompt from the bible with the paper's §8 template.
- `register <context> <file> --tool … --tool-version … --license …` copies a generated take to `Raw/<context>/` (git-ignored) and writes `provenance/<take-id>.json` (versioned): hash, tool, version, licence, prompt, parameters, human edits.
- `export <take-id>` masters to a -16 LUFS Ogg Vorbis under `Export/<context>/` and records its hash in the manifest.
- `check` validates the bible and every manifest (including that an export was not changed after the fact); `list` shows takes.

Generation itself (ACE-Step or a DAW) happens outside the script; its model version and weights licence go in `register`.
