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
