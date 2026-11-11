#!/usr/bin/env python3
##
## auto_screenshot.py — SCREENSHOT-HOOK-01: the pre-commit capture of the last map worked on.
##
## Gated OFF by default (SCREENSHOT-HOOK-02, 2026-07-11): runs only when the session switch is ON
## (`screenshot_toggle.py --on`) or `INFILTRAITOR_SCREENSHOT_ONCE=1` is set for one commit. Best-effort by
## design (Director, 2026-07-11): a failure prints a warning and returns non-zero, and the pre-commit hook
## does not treat that as fatal.
##
## 2026-11-11 (HERITAGE T3): the capture goes through CAPTURE_RAILS — `capture.py --still map` (the whole map) on the
## map `user://current_map.cfg` names (the last one the game loaded), an off-screen Movie Maker run at the
## `engine` profile — instead of room.gd's own `INFILTRAITOR_AUTO_SCREENSHOT` harness, which is deleted.
## The still is copied to `Screenshots/history/auto_<YYYYmmdd_HHMMSS>_<MAP>.png`; the 50 most recent
## `auto_` files are kept, as before (a hand-named capture is never touched).
##
##     INFILTRAITOR_SCREENSHOT_ONCE=1 python3 tools/persistent/auto_screenshot.py

import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import screenshot_toggle

ROOT = Path(__file__).resolve().parents[2]
CURRENT_MAP_CFG = Path.home() / "Library/Application Support/Godot/app_userdata/INFILTRAITOR/current_map.cfg"
HISTORY = ROOT / "Screenshots" / "history"
DEFAULT_MAP = "PLAYGROUND"
MAX_HISTORY_FILES = 50
PROCESS_TIMEOUT_SECONDS = 300


def last_map() -> str:
    """The map the game loaded last (`user://current_map.cfg`, `map_id="X"`), PLAYGROUND when there is none."""
    try:
        m = re.search(r'^map_id="([^"]+)"', CURRENT_MAP_CFG.read_text(), re.M)
    except OSError:
        return DEFAULT_MAP
    return m.group(1) if m else DEFAULT_MAP


def prune_history() -> None:
    files = sorted(p for p in HISTORY.glob("auto_*.png"))   ## chronological: the timestamp is zero-padded
    for old in files[:max(0, len(files) - MAX_HISTORY_FILES)]:
        old.unlink()
        print(f"[AUTO-SCREENSHOT] Pruned: {old.name}")


def main() -> int:
    once = os.environ.get("INFILTRAITOR_SCREENSHOT_ONCE") == "1"
    if not once and not screenshot_toggle.is_enabled():
        print("[AUTO-SCREENSHOT] Skipped — session capture is OFF and "
              "INFILTRAITOR_SCREENSHOT_ONCE not set for this commit. "
              "Enable with: python3 tools/persistent/screenshot_toggle.py --on")
        return 1
    reason = "one-off (INFILTRAITOR_SCREENSHOT_ONCE=1)" if once else "session switch ON"
    map_id = last_map()
    print(f"[AUTO-SCREENSHOT] Capture enabled ({reason}): {map_id}, the whole map")
    start = time.time()
    try:
        proc = subprocess.run([sys.executable, str(ROOT / "tools/persistent/capture.py"), "--map", map_id,
                               "--still", "map", "--mode", "wide", "--view", "N"],
                              cwd=ROOT, capture_output=True, text=True, timeout=PROCESS_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        print(f"[AUTO-SCREENSHOT] capture.py exceeded {PROCESS_TIMEOUT_SECONDS}s — skipping (non-fatal)")
        return 1
    out = proc.stdout + proc.stderr
    m = re.search(r"\[CAPTURE\] still (\S+\.png)", out)
    if proc.returncode != 0 or m is None:
        print(f"[AUTO-SCREENSHOT] capture.py failed (exit {proc.returncode}) — skipping (non-fatal)")
        tail = "\n".join(out.strip().splitlines()[-8:])
        if tail:
            print(tail)
        return 1
    HISTORY.mkdir(parents=True, exist_ok=True)
    dst = HISTORY / f"auto_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{map_id}.png"
    shutil.copy(ROOT / m.group(1), dst)
    print(f"[AUTO-SCREENSHOT] Captured: {dst.relative_to(ROOT)} ({time.time() - start:.1f}s)")
    prune_history()
    return 0


if __name__ == "__main__":
    sys.exit(main())
