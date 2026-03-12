from __future__ import annotations

from pathlib import Path
import subprocess
import time

from runtime_apps import activate_app, click_at, double_click_at, get_app_window_titles, get_screen_size, is_app_running, key_combo, type_text
from runtime_capture import capture_screen
from runtime_vision import find_text_center_coords, recognize_text


READY_MARKERS = ("scene", "filesystem", "inspector", "node", "script", "2d", "3d")
BLOCKING_MARKERS = ("importing", "reimport", "loading", "scanning", "compiling")

WORKSPACE_LABELS = {
    "2d": ("2D",),
    "3d": ("3D",),
    "script": ("Script",),
    "assetlib": ("AssetLib", "Asset Lib"),
}

PANEL_LABELS = {
    "scene": ("Scene",),
    "filesystem": ("FileSystem", "File System"),
    "inspector": ("Inspector",),
    "node": ("Node",),
    "output": ("Output",),
    "history": ("History",),
}


def _normalize_window_text(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def _project_window_tokens(project_path: Path) -> tuple[str, ...]:
    candidates = [project_path.parent.name, project_path.parent.name.replace("-", ""), project_path.parent.name.replace("_", "")]
    normalized = []
    for candidate in candidates:
        token = _normalize_window_text(candidate)
        if token and token not in normalized:
            normalized.append(token)
    return tuple(normalized)


def is_godot_project_open(osascript_path: str, project_path: Path) -> bool:
    titles = get_app_window_titles(osascript_path, "Godot")
    tokens = _project_window_tokens(project_path)
    if not tokens:
        return False
    for title in titles:
        normalized_title = _normalize_window_text(title)
        if any(token in normalized_title for token in tokens):
            return True
    return False


def launch_godot_project(godot_app_path: Path, project_path: Path, osascript_path: str) -> tuple[bool, bool, str]:
    if not godot_app_path.exists() or not project_path.exists():
        return False, False, "Godot app or project path does not exist."

    if is_app_running(osascript_path, "Godot"):
        activated = activate_app(osascript_path, "Godot")
        if activated:
            if is_godot_project_open(osascript_path, project_path):
                return True, False, f"Reused existing Godot window for {project_path.parent.name}."
            return True, False, "Godot was already running, so James reused the existing instance instead of opening another project window."
        return False, False, "Godot is already running, but activating it failed."

    result = subprocess.run(
        ["open", "-a", str(godot_app_path), str(project_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return False, False, result.stderr.strip() or f"Could not open Godot project at {project_path}."
    return True, True, f"Launched Godot project at {project_path}."


def _recognize_text_blob(image_path: Path) -> str:
    entries = recognize_text(image_path)
    return " ".join(str(entry.get("text", "")) for entry in entries).lower()


def _find_click_target(
    screencapture_path: str,
    osascript_path: str,
    output_path: Path,
    labels: tuple[str, ...],
) -> tuple[Path, tuple[int, int] | None, str | None]:
    capture_screen(screencapture_path, output_path)
    screen_width, screen_height = get_screen_size(osascript_path)
    for label in labels:
        coords = find_text_center_coords(output_path, label, screen_width, screen_height)
        if coords is not None:
            return output_path, coords, label
    return output_path, None, None


def wait_for_godot_editor_ready(
    screencapture_path: str,
    screenshots_dir: Path,
    task_id: str,
    timeout: float = 45.0,
    poll_interval: float = 1.0,
) -> tuple[bool, Path | None, str]:
    deadline = time.time() + timeout
    attempt = 0
    last_reason = "No Godot editor markers detected yet."
    last_path: Path | None = None
    while time.time() < deadline:
        attempt += 1
        shot_path = screenshots_dir / f"{task_id}_godot_ready_{attempt}.png"
        last_path = shot_path
        try:
            capture_screen(screencapture_path, shot_path)
            blob = _recognize_text_blob(shot_path)
        except Exception as exc:
            last_reason = f"screen capture or OCR failed: {exc}"
            time.sleep(poll_interval)
            continue

        ready = any(marker in blob for marker in READY_MARKERS)
        blocking = [marker for marker in BLOCKING_MARKERS if marker in blob]
        if ready and not blocking:
            return True, shot_path, "Godot editor markers detected and no import/loading blocker text is visible."
        if blocking:
            last_reason = f"still waiting for blockers to clear: {', '.join(blocking)}"
        else:
            last_reason = "Godot screenshot did not show stable editor markers yet."
        time.sleep(poll_interval)
    return False, last_path, last_reason


def switch_godot_workspace(
    cliclick_path: str,
    screencapture_path: str,
    osascript_path: str,
    output_path: Path,
    workspace: str,
) -> tuple[bool, Path, str]:
    workspace_key = workspace.strip().lower()
    labels = WORKSPACE_LABELS.get(workspace_key)
    if not labels:
        raise ValueError(f"Unsupported Godot workspace: {workspace}")
    shot_path, coords, matched = _find_click_target(screencapture_path, osascript_path, output_path, labels)
    if coords is None:
        return False, shot_path, f"workspace label not found: {workspace}"
    success = click_at(cliclick_path, coords[0], coords[1])
    return success, shot_path, f"clicked workspace label {matched}"


def focus_godot_panel(
    cliclick_path: str,
    screencapture_path: str,
    osascript_path: str,
    output_path: Path,
    panel: str,
) -> tuple[bool, Path, str]:
    panel_key = panel.strip().lower()
    labels = PANEL_LABELS.get(panel_key)
    if not labels:
        raise ValueError(f"Unsupported Godot panel: {panel}")
    shot_path, coords, matched = _find_click_target(screencapture_path, osascript_path, output_path, labels)
    if coords is None:
        return False, shot_path, f"panel label not found: {panel}"
    success = click_at(cliclick_path, coords[0], coords[1])
    return success, shot_path, f"clicked panel label {matched}"


def capture_godot_panel(
    cliclick_path: str,
    screencapture_path: str,
    osascript_path: str,
    focus_output_path: Path,
    capture_output_path: Path,
    panel: str,
) -> tuple[bool, Path, str]:
    focused, _, detail = focus_godot_panel(
        cliclick_path,
        screencapture_path,
        osascript_path,
        focus_output_path,
        panel,
    )
    if not focused:
        return False, focus_output_path, detail
    capture_screen(screencapture_path, capture_output_path)
    return True, capture_output_path, f"focused {panel} panel and captured it"


def open_godot_scene(
    cliclick_path: str,
    screencapture_path: str,
    osascript_path: str,
    output_path: Path,
    scene_ref: str,
    *,
    use_quick_open: bool = True,
) -> tuple[bool, Path, str]:
    scene_path = Path(scene_ref)
    labels = tuple(dict.fromkeys([scene_path.name, scene_path.stem]))
    shot_path, coords, matched = _find_click_target(screencapture_path, osascript_path, output_path, labels)
    if coords is not None:
        success = double_click_at(cliclick_path, coords[0], coords[1])
        return success, shot_path, f"double-clicked scene label {matched}"

    if use_quick_open:
        key_combo(osascript_path, "o", ["command", "shift"])
        time.sleep(0.35)
        type_text(osascript_path, scene_path.name)
        time.sleep(0.2)
        success = key_combo(osascript_path, "return", [])
        return success, shot_path, f"used Godot quick-open fallback for {scene_path.name}"

    return False, shot_path, f"scene label not found: {scene_ref}"


def run_godot_project(osascript_path: str) -> bool:
    return key_combo(osascript_path, "f5", [])


def stop_godot_project(osascript_path: str) -> bool:
    return key_combo(osascript_path, "f8", [])
