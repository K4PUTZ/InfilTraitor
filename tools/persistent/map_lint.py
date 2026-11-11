#!/usr/bin/env python3
## map_lint.py — every `.map.json` loads through the real MapFileService (HERITAGE T1, 2026-11-11).
##
## Runs `godot/scripts/tools/map_lint.gd` headless and fails unless it exits 0, prints no SCRIPT ERROR and
## prints its own "N checked, 0 failed" summary (a script that fails to load exits 0 having run nothing).
## Takes about a second; part of `verify.py quick`.
##
##     python3 tools/persistent/map_lint.py
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_selftests import PROJECT_ROOT, find_godot  # noqa: E402

SCRIPT = "res://godot/scripts/tools/map_lint.gd"
SUMMARY = re.compile(r"^(\d+) checked, (\d+) failed$", re.M)


def main() -> int:
    godot = find_godot()
    proc = subprocess.run([godot, "--headless", "--path", PROJECT_ROOT, "--script", SCRIPT],
                          cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=300)
    out = proc.stdout + proc.stderr
    errors = [line.strip() for line in out.splitlines() if "SCRIPT ERROR" in line]
    m = SUMMARY.search(out)
    for line in out.splitlines():
        if "✗" in line or "FAIL" in line:
            print(line)
    if errors:
        print("[MAP-LINT] FAILED — %d script error(s):" % len(errors))
        for line in errors[:10]:
            print("  " + line)
        return 1
    if m is None:
        print("[MAP-LINT] FAILED — no summary line: map_lint.gd did not run (exit %d)" % proc.returncode)
        return 1
    checked, failed = int(m.group(1)), int(m.group(2))
    if proc.returncode != 0 or failed != 0 or checked == 0:
        print("[MAP-LINT] FAILED — %d checked, %d failed, exit %d" % (checked, failed, proc.returncode))
        return 1
    print("[MAP-LINT] ✅ %d map(s) load clean" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
