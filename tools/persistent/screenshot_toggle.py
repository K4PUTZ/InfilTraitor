#!/usr/bin/env python3
##
## screenshot_toggle.py — SCREENSHOT-HOOK-02: session on/off switch for the
## pre-commit auto-capture (SCREENSHOT-HOOK-01).
##
## Default is OFF. Auto-capture costs ~5-6s per commit (a real windowed
## Godot boot) — worth it while a feature has real visual surface (facade
## work, occlusion, destruction, UI), wasted on routine architecture-only
## commits, doc updates, or planning sessions. This is a session-level
## switch: turn it on when entering a visual-heavy phase and off when
## leaving one, rather than deciding per-commit.
##
## For a single commit that deserves a capture while the session switch is
## OFF, don't flip this — set INFILTRAITOR_SCREENSHOT_ONCE=1 on that one
## commit instead (see auto_screenshot.py). This script is for the
## multi-commit phase switch, not a one-off.
##
## Usage:
##   python3 tools/persistent/screenshot_toggle.py --on
##   python3 tools/persistent/screenshot_toggle.py --off
##   python3 tools/persistent/screenshot_toggle.py --status
##
## State file: tools/persistent/.screenshot_session (gitignored, local to
## this machine — not a project artifact, not shared via commits).
##

import argparse
import os
import subprocess
import sys


def state_file_path() -> str:
    repo_root = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=False,
    ).stdout.strip()
    if not repo_root:
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(repo_root, "tools", "persistent", ".screenshot_session")


def is_enabled() -> bool:
    path = state_file_path()
    if not os.path.isfile(path):
        return False  # default OFF
    with open(path, "r", encoding="utf-8") as f:
        return f.read().strip() == "on"


def set_enabled(enabled: bool) -> None:
    path = state_file_path()
    with open(path, "w", encoding="utf-8") as f:
        f.write("on" if enabled else "off")


def main() -> int:
    parser = argparse.ArgumentParser(description="Toggle SCREENSHOT-HOOK-01's session auto-capture switch.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--on", action="store_true", help="Enable auto-capture for every commit until turned off.")
    group.add_argument("--off", action="store_true", help="Disable auto-capture (default state).")
    group.add_argument("--status", action="store_true", help="Print the current state, change nothing.")
    args = parser.parse_args()

    if args.status:
        print("ON" if is_enabled() else "OFF")
        return 0

    if args.on:
        set_enabled(True)
        print("[SCREENSHOT-TOGGLE] Session auto-capture: ON")
        print("  Every commit will now capture a real screenshot (~5-6s each).")
        print("  Turn off when leaving a visual-heavy phase: --off")
        return 0

    set_enabled(False)
    print("[SCREENSHOT-TOGGLE] Session auto-capture: OFF (default)")
    print("  Commits will no longer auto-capture. For a single commit that")
    print("  still deserves one, set INFILTRAITOR_SCREENSHOT_ONCE=1 instead.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
