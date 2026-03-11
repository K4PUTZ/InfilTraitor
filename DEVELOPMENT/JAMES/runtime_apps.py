from __future__ import annotations

import subprocess


SPECIAL_KEY_CODES = {
    "return": 36,
    "enter": 36,
    "tab": 48,
    "space": 49,
    "delete": 51,
    "escape": 53,
    "esc": 53,
    "left": 123,
    "right": 124,
    "down": 125,
    "up": 126,
    "f1": 122,
    "f2": 120,
    "f3": 99,
    "f4": 118,
    "f5": 96,
    "f6": 97,
    "f7": 98,
    "f8": 100,
    "f9": 101,
    "f10": 109,
    "f11": 103,
    "f12": 111,
}


def _run_osascript(osascript_path: str, script: str, timeout: float = 2) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            [osascript_path, "-e", script],
            capture_output=True,
            text=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return None


def get_frontmost_app(osascript_path: str) -> str | None:
    script = (
        'tell application "System Events" '\
        'to get name of first application process whose frontmost is true'
    )
    result = _run_osascript(osascript_path, script)
    if not result or result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def activate_app(osascript_path: str, app_name: str) -> bool:
    script = f'tell application "{app_name}" to activate'
    result = _run_osascript(osascript_path, script)
    return bool(result and result.returncode == 0)


def get_screen_size(osascript_path: str) -> tuple[int, int]:
    """Return the logical screen size in points (what cliclick coordinates use).

    Reads Finder desktop bounds which reflect the current display's logical resolution,
    including Retina scaling — so a 2880×1800 Retina panel running at 'looks like 1440×900'
    returns (1440, 900), matching cliclick's coordinate space.
    """
    script = 'tell application "Finder" to get bounds of window of desktop'
    result = _run_osascript(osascript_path, script, timeout=4)
    if result and result.returncode == 0:
        parts = [p.strip() for p in result.stdout.strip().split(",")]
        if len(parts) == 4:
            try:
                return int(parts[2]), int(parts[3])
            except ValueError:
                pass
    return 1440, 900  # safe default


def click_at(cliclick_path: str, x: int, y: int) -> bool:
    result = subprocess.run([cliclick_path, f"c:{x},{y}"], capture_output=True, text=True, check=False)
    return result.returncode == 0


def double_click_at(cliclick_path: str, x: int, y: int) -> bool:
    result = subprocess.run([cliclick_path, f"dc:{x},{y}"], capture_output=True, text=True, check=False)
    return result.returncode == 0


def drag_from_to(cliclick_path: str, x1: int, y1: int, x2: int, y2: int) -> bool:
    """Click-drag from (x1,y1) to (x2,y2) using cliclick's mouse-down / mouse-up primitives."""
    result = subprocess.run(
        [cliclick_path, f"dd:{x1},{y1}", f"du:{x2},{y2}"],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0


def type_text(osascript_path: str, text: str) -> bool:
    """Type text into the currently focused field via System Events keystroke.

    Uses osascript rather than cliclick so that special characters and multi-byte
    input are handled by the OS input pipeline instead of raw key codes.
    """
    # Escape backslashes first, then double-quotes to produce a safe AppleScript string.
    safe = text.replace("\\", "\\\\").replace('"', '\\"')
    script = f'tell application "System Events" to keystroke "{safe}"'
    timeout = max(5.0, len(text) * 0.15)
    result = _run_osascript(osascript_path, script, timeout=timeout)
    return bool(result and result.returncode == 0)


def key_combo(osascript_path: str, key: str, modifiers: list[str]) -> bool:
    """Send a key combination via System Events.

    Args:
        key:       Key character or name (e.g. "s", "return", "escape").
        modifiers: Zero or more of "command", "shift", "option", "control".

    Examples:
        key_combo(osascript_path, "s", ["command"])      → ⌘S
        key_combo(osascript_path, "z", ["command", "shift"])  → ⌘⇧Z
        key_combo(osascript_path, "return", [])           → Enter
    """
    normalized_key = key.strip().lower()
    mod_list = ", ".join(f"{m} down" for m in modifiers)
    special_key_code = SPECIAL_KEY_CODES.get(normalized_key)
    if special_key_code is not None:
        if modifiers:
            script = f'tell application "System Events" to key code {special_key_code} using {{{mod_list}}}'
        else:
            script = f'tell application "System Events" to key code {special_key_code}'
    else:
        safe_key = key.replace("\\", "\\\\").replace('"', '\\"')
        if not modifiers:
            script = f'tell application "System Events" to keystroke "{safe_key}"'
        else:
            script = f'tell application "System Events" to keystroke "{safe_key}" using {{{mod_list}}}'
    result = _run_osascript(osascript_path, script, timeout=3)
    return bool(result and result.returncode == 0)
