#!/usr/bin/env python3
##
## auto_screenshot.py — SCREENSHOT-HOOK-01: pre-commit auto-capture trigger
##
## Launches a real, windowed (non-headless) Godot process off-screen, with
## INFILTRAITOR_AUTO_SCREENSHOT=1 set so room.gd boots into the last map the
## Operator actually worked on (user://current_map.cfg) and captures a real
## rendered frame to Screenshots/history/ before quitting itself.
##
## Why not --headless: Godot 4.6's --headless mode forces the "dummy"
## rendering driver (confirmed via `--rendering-driver help`), which never
## rasterizes a real frame — only the `dummy` (null) driver is available
## under --display-driver headless. There is no way to get real pixels out
## of a --headless invocation. The only way to reuse the game's own
## get_viewport().get_texture().get_image() (the same path Shift+P already
## uses) is a real windowed process with a real rendering driver — hence
## `--position` far off any real screen plus `--quit-after` so it never
## lingers or requires a window manager.
##
## Best-effort by design (Director's call, 2026-07-11): any failure here
## prints a warning and returns non-zero, but the CALLER (pre-commit hook)
## must not treat that as fatal — screenshot capture is a support tool, not
## a correctness gate like invariants/CODEMAP/lint.
##
## SCREENSHOT-HOOK-02 (2026-07-11): capture is now gated, default OFF. Every
## commit used to pay the ~5-6s cost; that's wasted on routine architecture
## commits, doc updates, and planning sessions. Runs only when either:
##   (a) the session switch is ON (tools/persistent/screenshot_toggle.py
##       --on — the Overlord flips this for a visual-heavy phase, e.g.
##       occlusion/destruction work, and flips it back off after), or
##   (b) INFILTRAITOR_SCREENSHOT_ONCE=1 is set for this one commit (the
##       Overlord asks for this in a specific prompt when that prompt's
##       work has real visual surface, even during an otherwise-OFF phase).
##

import os
import subprocess
import sys
import time

import screenshot_toggle

GODOT_CANDIDATES = [
    "/Applications/Godot.app/Contents/MacOS/Godot",
    "/usr/bin/godot",
    "/usr/local/bin/godot",
]

# Generous ceiling: real bake + boot has been observed to take a few seconds
# in this project (junction-heavy maps bake ~20+ facade combos on load).
# --quit-after is frame-based (not time-based), so this timeout is a safety
# net for a process that never reaches --quit-after's frame count at all
# (e.g. a genuine hang) — not the expected exit path.
PROCESS_TIMEOUT_SECONDS = 45
QUIT_AFTER_FRAMES = 200
OFFSCREEN_POSITION = "4000,4000"


def find_godot_binary():
    for candidate in GODOT_CANDIDATES:
        if os.path.isfile(candidate):
            return candidate
    return None


def main() -> int:
    once = os.environ.get("INFILTRAITOR_SCREENSHOT_ONCE") == "1"
    session_on = screenshot_toggle.is_enabled()
    if not once and not session_on:
        print("[AUTO-SCREENSHOT] Skipped — session capture is OFF and "
              "INFILTRAITOR_SCREENSHOT_ONCE not set for this commit. "
              "Enable with: python3 tools/persistent/screenshot_toggle.py --on")
        return 1
    reason = "one-off (INFILTRAITOR_SCREENSHOT_ONCE=1)" if once else "session switch ON"
    print(f"[AUTO-SCREENSHOT] Capture enabled ({reason})")

    repo_root = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=False,
    ).stdout.strip()
    if not repo_root:
        print("[AUTO-SCREENSHOT] Could not resolve repo root — skipping (non-fatal)")
        return 1

    godot_bin = find_godot_binary()
    if godot_bin is None:
        print("[AUTO-SCREENSHOT] Godot binary not found — skipping (non-fatal)")
        return 1

    env = os.environ.copy()
    env["INFILTRAITOR_AUTO_SCREENSHOT"] = "1"

    cmd = [
        godot_bin,
        "--path", repo_root,
        "--position", OFFSCREEN_POSITION,
        "--quit-after", str(QUIT_AFTER_FRAMES),
    ]

    print("[AUTO-SCREENSHOT] Launching capture process (off-screen, auto-quit)...")
    start = time.time()
    try:
        result = subprocess.run(
            cmd, cwd=repo_root, env=env,
            capture_output=True, text=True,
            timeout=PROCESS_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        print(f"[AUTO-SCREENSHOT] Capture process exceeded {PROCESS_TIMEOUT_SECONDS}s — "
              "killed, skipping (non-fatal)")
        return 1

    elapsed = time.time() - start
    combined_output = result.stdout + result.stderr
    captured_line = next(
        (line for line in combined_output.splitlines()
         if "[SCREENSHOT-HOOK-01] Captured:" in line),
        None,
    )

    if captured_line:
        print(f"[AUTO-SCREENSHOT] {captured_line.strip()} ({elapsed:.1f}s)")
        return 0

    print(f"[AUTO-SCREENSHOT] No capture confirmation in output after {elapsed:.1f}s "
          "— skipping (non-fatal)")
    # Surface a short tail for diagnosis without flooding the commit output.
    tail = "\n".join(combined_output.strip().splitlines()[-8:])
    if tail:
        print("[AUTO-SCREENSHOT] Last output lines:")
        print(tail)
    return 1


if __name__ == "__main__":
    sys.exit(main())
