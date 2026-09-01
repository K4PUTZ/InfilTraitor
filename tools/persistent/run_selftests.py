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
## executes a selftest and fails it if ANY of:
##   - the process exits non-zero (the selftest's own fail counter), OR
##   - any "SCRIPT ERROR" line appears in the combined output (runtime
##     script errors included, which the bare run silently survives), OR
##   - anything is still alive at exit — "ObjectDB instances leaked at exit"
##     or "resources still in use at exit" (LEAK-GATE-01, 2026-08-17), OR
##   - the engine crashes during teardown (Main::cleanup).
##
## The last two were added the day the Slab/Voxel reference cycle was fixed.
## Both symptoms had been printing on real runs for months — one ignored by
## this runner, one tolerated by it as "engine cleanup, not the suite" — and
## between them they hid a leak costing 301 MB per map build. A check the
## arbiter declines to enforce is not a check.
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
    ## TEST-DEBT-03 (2026-09-01): a `*_selftest.tscn` is launched as the MAIN
    ## SCENE instead of via `--script`, and that is the only difference that
    ## matters — Godot registers autoload names as parse-time globals, and adds
    ## their nodes, only for a scene run. Two selftests need that and could not
    ## exist before it: version_info_selftest (`VersionInfo` is the thing under
    ## test) and prop_01_selftest (criterion 7 reaches MapCatalog, which reaches
    ## the `Registries` autoload). Under `--script` the first failed to LOAD and
    ## the second could only SKIP that criterion while counting it as a pass.
    ## Every other check below — script errors, leaks, PASS banner, exit code —
    ## applies to both invocations unchanged.
    argv = ([godot, "--headless", "--path", PROJECT_ROOT, res_path]
            if res_path.endswith(".tscn")
            else [godot, "--headless", "--script", res_path])
    start = time.time()
    try:
        proc = subprocess.run(
            argv,
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

    ## LEAK-GATE-01 (2026-08-17): an object still alive when the process exits
    ## is a FAILURE, not a footnote. This is the check whose absence let the
    ## Slab/Voxel reference cycle hide for months — it printed
    ## "ObjectDB instances leaked at exit" on every single run while the runner
    ## only ever looked at the exit code and SCRIPT ERROR lines, so nobody read
    ## it. A leaked Slab/Voxel graph cost 301 MB per map build (LEAK-CYCLE-01);
    ## the whole point of fixing that was to be able to hold this line.
    ##
    ## Both spellings matter: the ObjectDB warning covers Objects/RefCounteds,
    ## and "resources still in use" covers Resources (scripts, images) pinned by
    ## them. Neither needs --verbose to appear.
    leaked = ("ObjectDB instances leaked at exit" in output
              or "resources still in use at exit" in output)

    ## Engine teardown crash AFTER the verdict, observed 2026-08-01 with
    ## bake_selftest.gd: "RESULT: 19 PASS, 0 FAIL" ... then
    ## "handle_crash: Program crashed with signal 11" inside Main::cleanup
    ## (ObjectDB::cleanup of leaked GDScriptInstances), exit code flaky
    ## (0 or -6 across runs). Tolerated for months as "engine cleanup, not the
    ## suite" — it was neither. Root-caused 2026-08-17: bake_selftest.gd was the
    ## only selftest that called Engine.set_meta() without a matching
    ## remove_meta(), so engine metadata still held a MockRegistry (an inner
    ## class of that script) at unregister_core_types(); clearing it destroyed a
    ## GDScriptInstance whose GDScript was already gone. Two remove_meta() calls
    ## ended it. No selftest crashes at teardown any more, so the tolerance is
    ## gone: a teardown crash now FAILS the run like any other crash. It is
    ## still detected separately, purely so the report can name it.
    teardown_crash = ("handle_crash" in output and "Main::cleanup" in output)
    exit_ok = (exit_code == 0)

    ok = (exit_ok and not script_errors and not timed_out and ran_and_passed
          and not leaked and not teardown_crash)
    return {
        "script": script_rel,
        "ok": ok,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "script_errors": script_errors,
        "teardown_crash": teardown_crash,
        "leaked": leaked,
        "elapsed": elapsed,
        "output": output,
    }


## AUDIT-01 (2026-08-06): the glob above is *_selftest.gd, and eight test files
## in the same folder were named *_test.gd / *_tests.gd. They had been invisible
## to this runner — the arbiter — for as long as they existed, and the audit that
## finally ran them by hand found one failing outright (input_controller_test,
## exit 1, 17 SCRIPT ERRORs) and one reporting "3/5 passed" while exiting 0
## (occlusion_set_test, fixtures stale since OCC-07). Both were fixed then.
##
## TEST-DEBT-01 (2026-09-01, Director: "vamos corrigir o que for necessário"):
## being invisible let them rot again, and this time nothing anywhere said so.
## bake_cache_test had been 1 PASS / 6 FAIL since the 2026-08-21 asset-tree
## reform gave TextureResolver.resolve() a material-folder argument;
## occlusion_set_test had been 2/5 with an EMPTY occlusion set since the
## 2026-08-24 level renumber, one of its two "passes" reading
## "Cardinality reasonable: 0 cells (expect dozens)". Both files had a written
## record of passing months earlier. So six of the eight moved INTO the glob and
## are gated from here on:
##     bake_cache · input_controller · mapfile_roundtrip · occlusion_set ·
##     panel_base · resolver_hardening
## occlusion_set needed three things before it could join: derived levels, a
## cardinality guard that rejects the degenerate answer, and `quit(0)`/`quit(1)`
## instead of a bare `quit()` — its verdict line could not report a failure to
## anything outside itself.
##
## TEST-DEBT-03 (2026-09-01) closed the last two as well, by removing the
## limitation instead of documenting it: `prop_01_selftest` and
## `version_info_selftest` are `*_selftest.tscn` scenes now, launched as the main
## scene so the autoloads they need are genuinely present (see run_one). All
## eight formerly-invisible files are gated. This report stays because the blind
## spot can come back the moment someone adds another `*_test.gd`.
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

    ## Both shapes: a plain `--script` SceneTree selftest, and a `*_selftest.tscn`
    ## run as a scene so autoloads exist (see run_one). A .tscn and its .gd share
    ## a basename, so the .gd is skipped when a scene owns it — otherwise the same
    ## suite would run twice, once in the mode it cannot work in.
    scene_paths = sorted(glob.glob(os.path.join(PROJECT_ROOT, SELFTEST_DIR, "*_selftest.tscn")))
    scene_stems = {os.path.splitext(os.path.basename(p))[0] for p in scene_paths}
    script_paths = [
        p for p in sorted(glob.glob(os.path.join(PROJECT_ROOT, SELFTEST_DIR, "*_selftest.gd")))
        if os.path.splitext(os.path.basename(p))[0] not in scene_stems
    ]
    scripts = sorted(
        os.path.relpath(p, PROJECT_ROOT) for p in (script_paths + scene_paths))
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
            print("  ✓ %-42s %.1fs" % (name, result["elapsed"]))
        else:
            failures.append(result)
            ## Name every reason, not just the first: a leak and a crash at the
            ## same exit are the same underlying fault often enough that showing
            ## one and hiding the other sends the reader down the wrong path.
            reasons = []
            if result["timed_out"]:
                reasons.append("TIMEOUT after %ds" % TIMEOUT_S)
            else:
                reasons.append("exit %d" % result["exit_code"])
            if result["script_errors"]:
                reasons.append("%d SCRIPT ERROR line(s)" % len(result["script_errors"]))
            if result["leaked"]:
                reasons.append("LEAKED objects at exit (see LEAK-GATE-01)")
            if result["teardown_crash"]:
                reasons.append("teardown crash in Main::cleanup")
            print("  ✗ %-42s %.1fs — %s" % (name, result["elapsed"], " + ".join(reasons)))
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
