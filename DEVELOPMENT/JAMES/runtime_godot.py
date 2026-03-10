from __future__ import annotations

from pathlib import Path
import subprocess


def launch_godot_project(godot_app_path: Path, project_path: Path) -> bool:
    if not godot_app_path.exists() or not project_path.exists():
        return False
    result = subprocess.run(
        ["open", "-a", str(godot_app_path), str(project_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0
