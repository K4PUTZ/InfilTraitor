#!/usr/bin/env python3
##
## run_selftests.py — HARNESS-GAP-01 (flagged 2026-07-30, closed 2026-08-01):
## a runtime SCRIPT ERROR inside a selftest does NOT fail the suite when the
## selftest is run bare. GDScript aborts only the erroring function, the
## caller continues, the fail counter never increments, and the script still
## reaches quit(0) — observed on a broken call that printed an error while
## the run reported PASS with exit 0.
##
## GDScript has no in-process hook to catch its own script errors, so the
## arbiter has to sit OUTSIDE the Godot process — the same reasoning
## project_lint.py already applies to parse/compile errors. This runner
## executes a selftest and fails it if EITHER:
##   - the process exits non-zero (the selftest's own fail counter), OR
##   - any "SCRIPT ERROR" line appears in the combined output (runtime
##     script errors included, which the bare run silently survives).
##
## push_error() output ("ERROR: ...") is deliberately NOT a failure signal:
## loud-fail selftests (B6) exercise push_error paths on purpose. A SCRIPT
## ERROR is never on purpose.
##
## Usage:
##   python3 tools/persistent/run_selftests.py                    # all *_selftest.gd
##   python3 tools/persistent/run_selftests.py --only blast_calculator
##
## Exit 0 only when every selftest run is clean.
##

import argparse
import glob
import os
import re
import subprocess
import sys
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SELFTEST_DIR = os.path.join("godot", "scripts", "tools")
GODOT_CANDIDATES = [
    "/Applications/Godot.app/Contents/MacOS/Godot",
    "godot",
]
## A hung selftest should fail loudly, not park the runner forever. The
## slowest current selftest finishes in a few seconds; 120s is comfortably
## past any legitimate run.
TIMEOUT_S = 120

## Headless-autoload false positive, the SAME class project_lint.py
## whitelists per-file: in --script mode the script (and its dependency
## chain) is compiled once BEFORE autoloads register — a bare `Registries`
## reference fails that first compile, Godot retries after autoloads exist,
## and the suite then runs and passes for real. Exact observed instance
## (2026-08-01, slice_geometry_selftest.gd): the two SCRIPT ERROR lines
## below, followed by the suite's own "SLICE-00 SELFTEST: PASS (44
## checagens)" and exit 0. Suppressed ONLY for the lint's autoload
## whitelist; any other identifier stays a failure.
AUTOLOAD_WHITELIST = ("Localization", "Registries", "VersionInfo")
AUTOLOAD_ERROR_RE = re.compile(
    r"SCRIPT ERROR: (?:Parse|Compile) Error: Identifier not found: (?:%s)\b"
    % "|".join(AUTOLOAD_WHITELIST))
DEPENDED_ERROR = "SCRIPT ERROR: Compile Error: Failed to compile depended scripts."


def find_godot() -> str:
    for candidate in GODOT_CANDIDATES:
        if os.path.sep in candidate:
            if os.path.exists(candidate):
                return candidate
        else:
            from shutil import which
            if which(candidate):
                return candidate
    print("[SELFTEST] ERROR: no Godot binary found (looked for: %s)" % ", ".join(GODOT_CANDIDATES))
    sys.exit(2)


def run_one(godot: str, script_rel: str) -> dict:
    res_path = "res://" + script_rel.replace(os.path.sep, "/")
    start = time.time()
    try:
        proc = subprocess.run(
            [godot, "--headless", "--script", res_path],
            cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=TIMEOUT_S,
        )
        output = proc.stdout + proc.stderr
        exit_code = proc.returncode
        timed_out = False
    except subprocess.TimeoutExpired as e:
        output = ((e.stdout or b"").decode(errors="replace")
                  + (e.stderr or b"").decode(errors="replace"))
        exit_code = -1
        timed_out = True
    elapsed = time.time() - start

    raw_errors = [line.strip() for line in output.splitlines() if "SCRIPT ERROR" in line]
    suppressed_autoload = any(AUTOLOAD_ERROR_RE.search(line) for line in raw_errors)
    script_errors = [
        line for line in raw_errors
        if not AUTOLOAD_ERROR_RE.search(line)
        and not (suppressed_autoload and DEPENDED_ERROR in line)
    ]

    ## A script that fails to LOAD (parse error in the selftest itself) exits
    ## 0 having run NOTHING — observed 2026-08-01 with an injected static
    ## call to a nonexistent method: "SCRIPT ERROR: Parse Error: ...", no
    ## suite output at all, exit 0. So a clean verdict additionally requires
    ## the suite's own output to have appeared: every selftest prints a PASS
    ## banner on success, and a legitimately failing suite fails on exit code
    ## before this check matters.
    ran_and_passed = "PASS" in output

    ## Engine teardown crash AFTER the verdict, observed 2026-08-01 with
    ## bake_selftest.gd: "RESULT: 19 PASS, 0 FAIL" ... then
    ## "handle_crash: Program crashed with signal 11" inside Main::cleanup
    ## (ObjectDB::cleanup of leaked GDScriptInstances), exit code flaky
    ## (0 or -6 across runs). The suite itself completed; tolerated as
    ## clean-with-warning ONLY when the crash is in Main::cleanup and the
    ## PASS banner made it out first.
    teardown_crash = ("handle_crash" in output and "Main::cleanup" in output)
    exit_ok = (exit_code == 0) or (teardown_crash and ran_and_passed)

    ok = exit_ok and not script_errors and not timed_out and ran_and_passed
    return {
        "script": script_rel,
        "ok": ok,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "script_errors": script_errors,
        "teardown_crash": teardown_crash,
        "elapsed": elapsed,
        "output": output,
    }


## AUDIT-01 (2026-08-06): the glob above is *_selftest.gd, and eight test files
## in the same folder are named *_test.gd / *_tests.gd. They had been invisible
## to this runner — the arbiter — for as long as they existed, and the audit that
## finally ran them by hand found one failing outright (input_controller_test,
## exit 1, 17 SCRIPT ERRORs) and one reporting "3/5 passed" while exiting 0
## (occlusion_set_test, fixtures stale since OCC-07). Both are fixed now.
##
## Renaming them into the glob is NOT free: prop_01_tests and version_info_test
## depend on autoloads (Registries, VersionInfo), which `--script` runs do not
## instantiate, so they cannot pass under this runner as written — the same
## limitation project_lint.py whitelists. Until that is solved, the runner at
## least refuses to stay silent about its own blind spot.
def report_unrun_tests(ran: list) -> None:
    ran_names = {os.path.basename(s) for s in ran}
    others = sorted(
        os.path.basename(p)
        for pat in ("*_test.gd", "*_tests.gd")
        for p in glob.glob(os.path.join(PROJECT_ROOT, SELFTEST_DIR, pat))
        if os.path.basename(p) not in ran_names
    )
    if not others:
        return
    print("[SELFTEST] NOT RUN — %d test file(s) outside the *_selftest.gd glob:" % len(others))
    for name in others:
        print("    · %s" % name)
    print("[SELFTEST] Run one by hand: godot --headless --path . --script %s/<name>" % SELFTEST_DIR)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Godot selftests with SCRIPT ERROR detection")
    parser.add_argument("--only", help="substring of the selftest name (e.g. blast_calculator)")
    args = parser.parse_args()

    pattern = os.path.join(PROJECT_ROOT, SELFTEST_DIR, "*_selftest.gd")
    scripts = sorted(os.path.relpath(p, PROJECT_ROOT) for p in glob.glob(pattern))
    if args.only:
        scripts = [s for s in scripts if args.only in os.path.basename(s)]
    if not scripts:
        print("[SELFTEST] ERROR: no selftest matches %r under %s" % (args.only, SELFTEST_DIR))
        return 2

    godot = find_godot()
    print("[SELFTEST] Running %d selftest(s) via %s" % (len(scripts), godot))
    failures = []
    for script in scripts:
        result = run_one(godot, script)
        name = os.path.basename(script)
        if result["ok"]:
            note = "  ⚠ teardown crash after PASS (engine cleanup, not the suite)" \
                if result["teardown_crash"] else ""
            print("  ✓ %-42s %.1fs%s" % (name, result["elapsed"], note))
        else:
            failures.append(result)
            reason = ("TIMEOUT after %ds" % TIMEOUT_S) if result["timed_out"] else \
                ("exit %d" % result["exit_code"] if not result["script_errors"]
                 else "exit %d + %d SCRIPT ERROR line(s)" % (result["exit_code"], len(result["script_errors"])))
            print("  ✗ %-42s %.1fs — %s" % (name, result["elapsed"], reason))
            for line in result["script_errors"][:5]:
                print("      %s" % line)
            ## The selftest's own tail usually names which assertion failed.
            tail = [ln for ln in result["output"].splitlines() if ln.strip()][-4:]
            for line in tail:
                print("      | %s" % line)

    print("[SELFTEST] RESULT: %d clean, %d failed" % (len(scripts) - len(failures), len(failures)))
    if not args.only:
        report_unrun_tests(scripts)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
