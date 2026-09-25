#!/usr/bin/env python3
##
## verify.py — ONE command for "is it done", in tiers, failing fast (R3D-END, 2026-09-25).
##
## WHY. The verification protocol had grown to ~10 gates run in sequence (about 10 minutes, most of it two boots of every case
## just to re-prove determinism, and a 10-minute timeout whenever another Godot was alive). Measured 2026-09-25, one boot is
## 15-45 s; the cost was the number of gates, the doubled boots and the hangs. So:
##
##   quick   ~1.5 min   project_lint, check_invariants, gen_codemap --check, run_selftests. EVERY change.
##   full    ~5 min     quick + the boot gates: ground, shot_3d, occ_canonical, mirror (1 boot), roundtrip + shadow (ONE boot per map, `--with-store`), and the two
##                      identity gates (`board_probe gate`, `pixel_gate`) held to a STORED BASELINE with ONE boot per case.
##                      For a change that touches the board, the state, the light, the ground, the geometry or the shaders.
##   docs    seconds    check_invariants + gen_codemap --check. Markdown / PROMPTS / docs only.
##   auto    (default)  picks one of the above from the files you changed (`git status`, or the last commit if the tree is clean).
##
## THE BASELINE. Determinism (two boots of the same code give the same pixels and the same dump) was earned when the gates were
## built and is re-earned ONLY when a baseline is taken: `verify.py --baseline` runs `pixel_gate --keep` and `board_probe gate
## --runs 2` (two boots each, so it also proves the harness is deterministic today) and stores them under
## `Screenshots/verify_baseline/` (git-ignored) with the commit. Take it at the START of a task, on the code before your change;
## `verify.py full` then holds ONE boot to it. With no baseline the two identity gates fall back to their two-boot form (slower,
## proves less: a change that alters both boots the same way passes) and the run says so.
##
## FAILS FAST. A boot gate refuses to start while another Godot is alive (the editor included): concurrent load moves the
## frame timing the gates depend on, and a hung boot used to burn a 600 s timeout before saying so. Every boot now times out at
## 180-300 s. The first failing step stops the run (`--keep-going` to see them all).
##
## Usage:
##     python3 tools/persistent/verify.py                 # auto
##     python3 tools/persistent/verify.py quick|full|docs
##     python3 tools/persistent/verify.py --baseline      # take the reference set (two boots per case)
##     python3 tools/persistent/verify.py full --only ground,mirror --keep-going
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
QUICK_PATTERNS = (r"^godot/scripts/tools/", r"^tools/", r"^godot/localization/", r"^\.githooks/", r"^QWEN")


def sh(*args):
    return [PY, P + args[0], *args[1:]]


## (name, boots a windowed game, command builder taking the baseline-present flag)
def steps_for(tier: str, have_baseline: bool):
    quick = [
        ("lint", False, sh("project_lint.py")),
        ("invariants", False, sh("check_invariants.py")),
        ("codemap", False, sh("gen_codemap.py", "--check")),
        ("selftests", False, sh("run_selftests.py")),
    ]
    if tier == "docs":
        return quick[1:3]
    if tier == "quick":
        return quick
    identity = []
    if have_baseline:
        identity = [
            ("probe-gate", True, sh("board_probe.py", "gate", "--runs", "1", "--against", str(BASELINE / "probes"),
                                    "--out", str(ROOT / "Screenshots" / "verify_baseline" / "_last_probe"))),
            ("pixel-gate", True, sh("pixel_gate.py", "--single", "--against", str(BASELINE / "pixels"))),
        ]
    else:
        identity = [
            ("probe-gate (2 boots, NO BASELINE)", True, sh("board_probe.py", "gate")),
            ("pixel-gate (2 boots, NO BASELINE)", True, sh("pixel_gate.py")),
        ]
    return quick + [
        ("ground", True, sh("ground_gate.py")),
        ("shot-3d", True, sh("shot_3d_gate.py")),
        ("occ-canonical", True, sh("occ_canonical_gate.py")),
        ("mirror", True, sh("mirror_gate.py", "--single")),
        ("roundtrip+shadow", True, sh("board_probe.py", "roundtrip", "--with-store")),
    ] + identity


def other_godots():
    """(pid, elapsed, command) of every Godot process alive. The gates boot their own; any other one is a hazard."""
    out = subprocess.run(["ps", "-axo", "pid,etime,command"], capture_output=True, text=True).stdout
    found = []
    for line in out.splitlines()[1:]:
        m = re.match(r"\s*(\d+)\s+(\S+)\s+(.*)$", line)
        if m and "Godot.app/Contents/MacOS/Godot" in m.group(3):
            found.append((m.group(1), m.group(2), m.group(3)[:110]))
    return found


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
    return "full", files


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
    for name, cmd in (("pixels", sh("pixel_gate.py", "--keep", str(BASELINE / "pixels"))),
                      ("probes", sh("board_probe.py", "gate", "--runs", "2", "--out", str(BASELINE / "probes")))):
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
    ap.add_argument("tier", nargs="?", default="auto", choices=["auto", "quick", "full", "docs"])
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
        if tier == "full" and base is None:
            print("[verify] ⚠ no baseline: the identity gates run in their two-boot form (slower, proves less). "
                  "Take one at the start of a task with `verify.py --baseline`.")
    results = []
    failed = False
    for name, _, cmd in steps:
        t0 = time.time()
        print("\n[verify] ── %s ──" % name, flush=True)
        rc = subprocess.run(cmd, cwd=ROOT).returncode
        results.append((name, rc, time.time() - t0))
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
