#!/usr/bin/env python3
##
## verify.py — ONE command for "is it done", in tiers, failing fast (R3D-END, 2026-09-25).
##
## WHY. The verification protocol had grown to ~10 gates run in sequence (about 10 minutes, most of it two boots of every case
## just to re-prove determinism, and a 10-minute timeout whenever another Godot was alive). Measured 2026-09-25, one boot is
## 15-45 s; the cost was the number of gates, the doubled boots and the hangs. So:
##
## 2026-11-12 (Director: *"o objetivo mais grosso da engine, que é explosão, fogo e destruição do cenário, já foi atingido ... a única
## coisa que talvez ainda vai gerar algum custo expressivo são as mudanças na iluminação"*): the checks follow the work that is
## left (actors, animation, guard AI, HUD, inventories, light). The blast / glass / shot gates and 66 selftests of the closed
## engine work are PARKED, not deleted: `run_selftests.py --all`, and each gate by hand (listed in `steps_for`).
##
##   quick   ~45 s      project_lint, check_invariants, gen_codemap --check, worker_typing_check, map_lint, segment_budget, and
##                      the selftests NOT parked (28: actors, stealth, HUD, maps, save, catalogues, light, infrastructure).
##   smoke   ~1.5 min   quick + a boot of PLAYGROUND and SEG_TYPICAL (guards on both) that rotates E then N and resets the alert
##                      (smoke_boot.py): no grenade, no shot. THE DEFAULT for any change under godot/.
##   look    ~2.5 min   smoke + the LIGHT gate (`pixel_gate --light`: each map as loaded and turned to E, no event) held to the
##                      stored baseline. For a change to how something LOOKS or is LIT. If the change is intended, take a new
##                      baseline first (`--baseline`) and say so.
##   full    ~4 min     smoke + occ_canonical, roof_yaw, pick + the light gate. For a change to the light, the occlusion or the
##                      board. Run when the Director asks or to close a stage that rewires them.
##   docs    seconds    check_invariants + gen_codemap --check. Markdown / PROMPTS / docs only.
##   auto    (default)  picks docs / quick / smoke from the files you changed (`git status`, or the last commit if the tree is clean).
##
## THE BASELINE. `verify.py --baseline` runs `pixel_gate --light --keep` (two boots per map, so it also proves the harness is
## deterministic today) and stores it under `Screenshots/verify_baseline/` (git-ignored) with the commit. Take it at the START of
## a task, on the code before your change. With no baseline the light gate falls back to its two-boot form and says so. (The
## old baseline replayed two grenades and a shot; GLASS g0 diverged in ~1 boot of 3 because the blast's stages are sliced by a
## wall-clock budget even at a fixed FPS: accepted as known noise when the blast gates were parked, 2026-11-12.)
##
## FAILS FAST. A boot gate refuses to start while another Godot is alive (the editor included): concurrent load moves the
## frame timing the gates depend on, and a hung boot used to burn a 600 s timeout before saying so. Every boot now times out at
## 180-300 s. The first failing step stops the run (`--keep-going` to see them all).
##
## A BOOT GATE CAN HANG UNDER A REMOTE DESKTOP SESSION (2026-10-03). The gates open the game's window at `--position 4000,4000`,
## off every monitor, and a gate's `capture` waits for a frame the window draws. While the Mac was reached through Chrome Remote
## Desktop a boot hung at a capture about every other run (CPU spinning, no new log line, the 180 s timeout; the same boot took 34 s
## on another try, and the unmodified code hung the same way). With the session closed, three runs in a row passed (two of the
## one-boot form, 68-77 s, one of the two-boot form, 143 s). The likely cause is the OS not compositing a window on a virtual or
## sleeping display, so it is a hypothesis, not a proof. If a boot gate times out: close the remote session and run it again before
## suspecting the code; do not read a hang as a regression without a control run on the previous commit (`git stash`).
##
## THE RUNNER HELPS WITH THE HANG (2026-10-03). A boot step that dies with a `TimeoutExpired` is run ONCE more and reported as
## retried: a real hang hangs twice and still fails, a flaky one costs a minute instead of a manual rerun. A retry is printed in the
## summary, never hidden. It does NOT try to detect a remote session: Chrome Remote Desktop's host (`remoting_me2me_host`, its
## launchd service and broker) runs all the time once installed, with or without a session, so a process check is true on every
## run. The sure sign is the on-screen "being shared" banner; when it is up, expect the hang.
##
## Usage:
##     python3 tools/persistent/verify.py                 # auto
##     python3 tools/persistent/verify.py quick|look|full|docs
##     python3 tools/persistent/verify.py --baseline      # take the reference set (two boots per case)
##     python3 tools/persistent/verify.py full --only pick,roof-yaw --keep-going
##     python3 tools/persistent/verify.py --list          # the steps of a tier, without running

import argparse
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
P = "tools/persistent/"
BASELINE = ROOT / "Screenshots" / "verify_baseline"
STAMP = BASELINE / "BASELINE.txt"
PY = sys.executable

## Files that need no boot to be judged. Anything else under godot/, plus project.godot, needs the full tier.
DOC_PATTERNS = (r"^Library", r"\.md$", r"^docs/", r"^PROMPTS/", r"^Screenshots/", r"CODEMAP\.md$", r"^VERSION$", r"\.uid$")
QUICK_PATTERNS = (r"^godot/scripts/tools/", r"^tools/", r"^godot/localization/", r"^\.githooks/")


def sh(*args):
    return [PY, P + args[0], *args[1:]]


## (name, boots a windowed game, command builder taking the baseline-present flag)
def steps_for(tier: str, have_baseline: bool):
    quick = [
        ("lint", False, sh("project_lint.py")),
        ("invariants", False, sh("check_invariants.py")),
        ("codemap", False, sh("gen_codemap.py", "--check")),
        ("surfaces", False, sh("check_surface.py", "--declared")),
        ("segment-budget", False, sh("segment_budget.py")),
        ("worker-typing", False, sh("worker_typing_check.py")),   ## no untyped operator in code a worker thread runs (Godot 4.6.1 / 4.7.2 race, 2026-10-19)
        ("map-lint", False, sh("map_lint.py")),   ## every .map.json loads through MapFileService (~1 s; HERITAGE T1, 2026-11-11)
        ("selftests", False, sh("run_selftests.py")),
    ]
    if tier == "docs":
        return quick[1:3]
    if tier == "quick":
        return quick
    if tier == "smoke":
        return quick + [("smoke-boot", False, sh("smoke_boot.py"))]
    ## 2026-11-12 (Director): the blasts, glass, soot and shots are closed engine work; the light is what may still cost. `look`
    ## and `full` hold the LIGHT capture (each map as loaded and turned to E, no event) to the baseline; `full` adds the
    ## occlusion / rotation / picking gates. The blast and shot gates are parked: run them by hand when that code is touched
    ## (`pixel_gate.py`, `board_probe.py gate`, `shot_3d_gate.py`, `struct_audit.py`, `ground_gate.py`, `mirror_gate.py`,
    ## `world_gate.py`, `canvas_gate.py`, `board_probe.py roundtrip --with-store`).
    light = (sh("pixel_gate.py", "--light", "--single", "--against", str(BASELINE / "light")) if have_baseline
             else sh("pixel_gate.py", "--light"))
    light_step = ("light-gate" if have_baseline else "light-gate (2 boots, NO BASELINE)", True, light)
    smoke = ("smoke-boot", False, sh("smoke_boot.py"))
    if tier == "look":
        return quick + [smoke, light_step]
    return quick + [
        smoke,
        ("occ-canonical", True, sh("occ_canonical_gate.py")),
        ("roof-yaw", True, sh("roof_yaw_gate.py")),
        ("pick", True, sh("pick_gate.py")),
        light_step,
    ]


def other_godots():
    """(pid, elapsed, command) of every Godot process alive. The gates boot their own; any other one is a hazard."""
    out = subprocess.run(["ps", "-axo", "pid,etime,command"], capture_output=True, text=True).stdout
    found = []
    for line in out.splitlines()[1:]:
        m = re.match(r"\s*(\d+)\s+(\S+)\s+(.*)$", line)
        if m and "Godot.app/Contents/MacOS/Godot" in m.group(3):
            found.append((m.group(1), m.group(2), m.group(3)[:110]))
    return found


def run_step(cmd, boots):
    """Run one step, echoing its output as it comes. A boot step that dies with a TimeoutExpired is run once more.
    Returns (rc, retried)."""
    for attempt in (1, 2):
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        text = []
        for line in proc.stdout:
            print(line, end="", flush=True)
            text.append(line)
        rc = proc.wait()
        if rc != 0 and boots and attempt == 1 and "TimeoutExpired" in "".join(text[-40:]):
            print("[verify] the boot timed out; running the step once more (a real hang hangs twice)", flush=True)
            continue
        return rc, attempt == 2
    return rc, True


def changed_files():
    def lines(cmd):
        return [l for l in subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True).stdout.splitlines() if l.strip()]
    files = [l[3:].strip().strip('"') for l in lines(["git", "status", "--porcelain"])]
    if not files:
        files = lines(["git", "diff", "--name-only", "HEAD~1", "HEAD"])
    return files


def auto_tier():
    files = changed_files()
    if not files:
        return "quick", files
    if all(any(re.search(p, f) for p in DOC_PATTERNS) for f in files):
        return "docs", files
    if all(any(re.search(p, f) for p in DOC_PATTERNS + QUICK_PATTERNS) for f in files):
        return "quick", files
    return "smoke", files


def baseline_note():
    if not STAMP.exists():
        return None
    return STAMP.read_text().strip().splitlines()[0]


def take_baseline() -> int:
    godots = other_godots()
    if godots:
        print("[verify] REFUSED: another Godot is alive (%s). Close it (the editor included) and run again." % godots[0][0])
        return 2
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT,
                                capture_output=True, text=True).stdout.strip())
    head = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    BASELINE.mkdir(parents=True, exist_ok=True)
    print("[verify] baseline of %s%s: two boots per case, so it also proves the harness is deterministic today"
          % (head, " + UNCOMMITTED CHANGES (the baseline is of that tree)" if dirty else ""))
    for name, cmd in (("light", sh("pixel_gate.py", "--light", "--keep", str(BASELINE / "light"))),):
        t0 = time.time()
        rc = subprocess.run(cmd, cwd=ROOT).returncode
        print("[verify] baseline %s: %s in %.0f s" % (name, "ok" if rc == 0 else "FAILED (rc %d)" % rc, time.time() - t0))
        if rc != 0:
            print("[verify] the baseline is NOT stored: a harness that is not deterministic today cannot hold anything.")
            STAMP.unlink(missing_ok=True)
            return rc
    STAMP.write_text("%s%s %s\n" % (head, "+dirty" if dirty else "", datetime.now().strftime("%Y-%m-%d %H:%M")))
    print("[verify] baseline stored: %s" % baseline_note())
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Tiered, fail-fast verification (see the header).")
    ap.add_argument("tier", nargs="?", default="auto", choices=["auto", "docs", "quick", "smoke", "look", "full"])
    ap.add_argument("--baseline", action="store_true", help="take the reference set (two boots per case) and stop")
    ap.add_argument("--keep-going", action="store_true", help="run every step even after a failure")
    ap.add_argument("--only", default="", help="comma list: run only the steps whose name contains one of these")
    ap.add_argument("--list", action="store_true", help="print the steps and stop")
    args = ap.parse_args()
    if args.baseline:
        return take_baseline()
    tier, files = (args.tier, []) if args.tier != "auto" else auto_tier()
    base = baseline_note()
    steps = steps_for(tier, base is not None)
    if args.only:
        wanted = [w.strip() for w in args.only.split(",") if w.strip()]
        steps = [s for s in steps if any(w in s[0] for w in wanted)]
    print("[verify] tier %s%s%s" % (tier, " (auto, from %d changed file(s))" % len(files) if args.tier == "auto" else "",
          "; baseline %s" % base if tier == "full" and base else ("; NO BASELINE" if tier == "full" else "")))
    if args.list:
        for name, boots, cmd in steps:
            print("  %-34s %s%s" % (name, "boots a game  " if boots else "", " ".join(cmd[1:])))
        return 0
    if any(boots for _, boots, _ in steps):
        godots = other_godots()
        if godots:
            print("[verify] REFUSED: another Godot is alive — pid %s, up %s (%s)." % godots[0])
            print("[verify] The boot gates need the machine to themselves (the editor included); close it and run again.")
            return 2
        if tier in ("full", "look") and base is None:
            print("[verify] ⚠ no baseline: the identity gates run in their two-boot form (slower, proves less). "
                  "Take one at the start of a task with `verify.py --baseline`.")
    results = []
    failed = False
    for name, boots, cmd in steps:
        t0 = time.time()
        print("\n[verify] ── %s ──" % name, flush=True)
        rc, retried = run_step(cmd, boots)
        results.append((name + (" (retried after a timeout)" if retried else ""), rc, time.time() - t0))
        if rc != 0:
            failed = True
            if not args.keep_going:
                break
    print("\n[verify] " + "=" * 60)
    for name, rc, secs in results:
        print("[verify] %-4s %5.0f s  %s" % ("ok" if rc == 0 else "FAIL", secs, name))
    skipped = len(steps) - len(results)
    if skipped:
        print("[verify] %d step(s) not run (stopped at the first failure; --keep-going to see them all)" % skipped)
    print("[verify] %s in %.0f s" % ("FAILED" if failed else "PASSED", sum(r[2] for r in results)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
