from __future__ import annotations

from pathlib import Path
import time

from runtime_apps import get_frontmost_app
from runtime_capture import capture_screen
from runtime_vision import contains_text


def wait_for_app(osascript_path: str, app_name: str, timeout: float = 15.0, poll_interval: float = 0.5) -> bool:
    """Poll until the frontmost application name contains *app_name* (case-insensitive).

    Uses a substring match so that "Godot" matches both "Godot" and "Godot Engine",
    and "Visual Studio Code" matches "Code" or "Code - Insiders".
    """
    deadline = time.time() + timeout
    needle = app_name.lower()
    while time.time() < deadline:
        current = get_frontmost_app(osascript_path) or ""
        if needle in current.lower():
            return True
        time.sleep(poll_interval)
    return False


def wait_for_text(
    screencapture_path: str,
    screenshots_dir: Path,
    task_id: str,
    label: str,
    needle: str,
    timeout: float = 15.0,
    poll_interval: float = 1.0,
) -> tuple[bool, Path | None]:
    deadline = time.time() + timeout
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        shot_path = screenshots_dir / f"{task_id}_{label}_{attempt}.png"
        try:
            capture_screen(screencapture_path, shot_path)
        except Exception:
            time.sleep(poll_interval)
            continue
        if contains_text(shot_path, needle):
            return True, shot_path
        time.sleep(poll_interval)
    return False, None


def wait_for_text_absent(
    screencapture_path: str,
    screenshots_dir: Path,
    task_id: str,
    label: str,
    needle: str,
    timeout: float = 15.0,
    poll_interval: float = 1.0,
) -> tuple[bool, Path | None]:
    deadline = time.time() + timeout
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        shot_path = screenshots_dir / f"{task_id}_{label}_{attempt}.png"
        try:
            capture_screen(screencapture_path, shot_path)
        except Exception:
            time.sleep(poll_interval)
            continue
        if not contains_text(shot_path, needle):
            return True, shot_path
        time.sleep(poll_interval)
    return False, None
