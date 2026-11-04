#!/usr/bin/env python3
##
## temp_dir.py — the one folder for what can be thrown away (Director, 2026-11-04: "a gente precisa formalizar uma pasta 'temp' pra eu
## poder deletar manualmente a qualquer momento").
##
## temp/ at the repo root holds every generated video, still, filmstrip, render, test APK and work file. It is git-ignored, and its
## `.gdignore` keeps Godot from scanning it. THE RULE: nothing reads from temp/ between runs, so the Director may delete the whole folder
## at any moment and the next run makes it again. A capture worth keeping is moved by hand to REFERENCES/. Claude never empties it.
##
## room.gd's dev captures write here too; its `_temp_dir()` is the GDScript side of this file and makes the same `.gdignore`.
##
##     from temp_dir import temp_path
##     VIDEOS = temp_path("videos")      # <repo>/temp/videos, created now
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMP = ROOT / "temp"


def temp_path(*parts: str) -> Path:
    """temp/<parts...> as a folder that exists, with the `.gdignore` that keeps the editor out of all of temp/."""
    path = TEMP.joinpath(*parts)
    path.mkdir(parents=True, exist_ok=True)
    (TEMP / ".gdignore").touch()
    return path
