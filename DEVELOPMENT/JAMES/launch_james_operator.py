from __future__ import annotations

import argparse
import shlex
import subprocess
import time
from pathlib import Path

from runtime_apps import get_app_window_titles, is_app_running
from runtime_config import load_config
from runtime_godot import launch_godot_project


def _is_process_running(pattern: str) -> bool:
    result = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True, check=False)
    return result.returncode == 0 and bool(result.stdout.strip())


def _run_osascript(script: str) -> bool:
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, check=False)
    return result.returncode == 0


def _open_terminal_window(command: str, title: str) -> bool:
    banner_command = f"printf '\\n=== {title} ===\\n'; {command}"
    escaped_command = banner_command.replace("\\", "\\\\").replace('"', '\\"')
    script = f'''
tell application "Terminal"
    activate
    do script "{escaped_command}"
end tell
'''
    return _run_osascript(script)


def _godot_project_tokens(project_path: Path) -> tuple[str, ...]:
    stem = project_path.parent.name.lower()
    return (stem, stem.replace("-", ""), "infiltraitor")


def _is_project_open(config, project_path: Path) -> bool:
    if not is_app_running(config.osascript_path, "Godot"):
        return False
    tokens = _godot_project_tokens(project_path)
    titles = [title.lower() for title in get_app_window_titles(config.osascript_path, "Godot")]
    return any(token in title for title in titles for token in tokens)


def _ensure_godot_project(config, project_path: Path) -> str:
    godot_running = is_app_running(config.osascript_path, "Godot")
    project_open = _is_project_open(config, project_path)

    if project_open:
        return "Godot is already running with the INFILTRAITOR project open."

    if launch_godot_project(config.godot_app_path, project_path):
        time.sleep(1.0)
        if godot_running:
            return "Godot was already running; requested the INFILTRAITOR project to open in Godot."
        return "Launched Godot with the INFILTRAITOR project."

    return "Could not launch or focus the INFILTRAITOR Godot project."


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch James into dedicated operator terminals.")
    parser.add_argument("--goal", default="Voice operator request", help="Default goal for listen mode captures")
    parser.add_argument("--skip-godot", action="store_true", help="Do not check or launch Godot")
    parser.add_argument("--skip-listen", action="store_true", help="Do not start the James listen terminal")
    parser.add_argument("--skip-monitor", action="store_true", help="Do not start the James monitor terminal")
    args = parser.parse_args()

    config = load_config()
    root_dir = config.root_dir
    python_bin = root_dir / "../../../.venv/bin/python"
    if not python_bin.exists():
        python_bin = Path("python3")

    if not args.skip_godot:
        message = _ensure_godot_project(config, Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/infil-traitor/project.godot"))
        print(message)

    listen_pattern = "james.py listen"
    monitor_pattern = "james.py monitor"

    listen_command = (
        f"cd {shlex.quote(str(root_dir))} && "
        f"{shlex.quote(str(python_bin))} james.py listen --goal {shlex.quote(args.goal)}"
    )
    monitor_command = (
        f"cd {shlex.quote(str(root_dir))} && "
        f"{shlex.quote(str(python_bin))} james.py monitor"
    )

    if not args.skip_listen:
        if _is_process_running(listen_pattern):
            print("James listen process already running.")
        elif _open_terminal_window(listen_command, "James Listen"):
            print("Opened James listen terminal.")
        else:
            print("Failed to open James listen terminal.")

    if not args.skip_monitor:
        if _is_process_running(monitor_pattern):
            print("James monitor process already running.")
        elif _open_terminal_window(monitor_command, "James Monitor"):
            print("Opened James monitor terminal.")
        else:
            print("Failed to open James monitor terminal.")

    print("James operator launcher complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())