#!/usr/bin/env python3
"""Keep the design branch's work out of the engine, mechanically.

INFILTRAITOR is developed from two workspaces against one repository: the
engine on `main` (agent CLAUDE) and the interface on `feat/design-interface-hud`
(agent JAMES). Until this file existed, the ONLY thing keeping design work out
of engine files was prose in `.README_WORKSPACE.md` and CLAUDE.md — a rule an
agent has to read, remember and obey. This is the same rule expressed as a gate
that runs whether or not anyone read it, in the spirit of check_invariants.py.

THIS FILE IS THE SINGLE AUTHORITY for what belongs to the design branch. The
pre-commit hook calls it, and the process docs point at `--list` rather than
restating the paths, so the two cannot drift apart.

Direction of enforcement is deliberately ASYMMETRIC, because the risk is:
  * On a DESIGN branch: touching an engine file is BLOCKED. This is the case
    the Director asked for — "o que for feito lá não vai interferir aqui".
  * On `main`: touching a UI file only WARNS. CLAUDE.md makes Claude
    engine-only, but the Director commits here too and a hard block would
    stop him working in his own repository. A warning names the file and the
    rule; it does not decide for him.

Usage:
    python3 tools/persistent/check_design_scope.py            # staged files
    python3 tools/persistent/check_design_scope.py --against main
    python3 tools/persistent/check_design_scope.py --list
"""

from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys

# ── Which branches are design branches ──────────────────────────────────────
DESIGN_BRANCH_GLOBS = ["feat/design-*"]

# ── What a design branch MAY change ─────────────────────────────────────────
# Anything not matched here is engine territory. Keep this list small and
# explicit: a glob that is too generous silently re-opens the door this file
# exists to close.
DESIGN_ALLOWED = [
    # The UI layer proper — scripts and (once it exists) scenes.
    "godot/scripts/ui/*",
    "godot/scenes/ui/*",
    # The HUD's state/signal hub. It lives under scripts/controllers/ beside
    # five ENGINE controllers (camera, fow, guard_coordinator, lighting,
    # vision), so the folder cannot be allowed wholesale — only this file.
    "godot/scripts/controllers/hud_controller.gd",
    "godot/scripts/controllers/hud_controller.gd.uid",
    # Input wiring is design's by the workspace charter.
    "godot/scripts/world/controllers/input_controller.gd",
    "godot/scripts/world/controllers/input_controller.gd.uid",
    # Player-facing strings are UI text.
    "godot/localization/translations/*",
    # The design side's own documentation, and JAMES's own context file —
    # QWEN.md is what Qwen Code auto-loads from the workspace root.
    "QWEN.md",
    ".README_WORKSPACE.md",
    "PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md",
    "docs/technical/INPUT_REFERENCE.md",
    # Design's own screenshots and prompt files.
    "Screenshots/history/*",
    "PROMPTS/RESUMO_SESSAO_*",
    "PROMPTS/UI_*",
]

# ── The file BOTH sides genuinely need, and why that is a defect ────────────
# room.tscn left this list when the HUD was extracted (UI-SPLIT-01) and room.gd
# left it when the engine stopped naming widgets (UI-SPLIT-02) — it is now an
# ordinary engine file, blocked because it is not in the allowlist, and invariant
# L3 keeps it that way. project.godot is what remains.
# These are not "engine files JAMES might touch by accident". They are files
# the interface CANNOT be built without, that the engine also owns. Blocking
# them is correct but it is not a solution — the solution is to un-share them,
# which is a structural change awaiting the Director. The message says so,
# so whoever hits this gate learns the real state instead of just being told
# "no".
CONTESTED = {
    "project.godot": (
        "the [input] section is design's and every other section is the "
        "engine's, and Godot cannot split this file. Ask the Director to "
        "apply an input-map change on main rather than editing it here."
    ),
}


def _run(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=False
    ).stdout.strip()


def merge_in_progress() -> bool:
    """True while a merge (or a revert/cherry-pick) is being concluded.

    A design branch pulling `main` is the DOCUMENTED, REQUIRED sync — it stages
    every engine file that changed since the last sync, which looks exactly like
    the violation this tool exists to block. Caught on the very first real sync
    on 2026-09-09: the gate refused the merge commit and made the split
    unusable. The scope rule is about what a branch AUTHORS, never about what it
    RECEIVES from main, so a merge is exempt by construction rather than by
    someone remembering `--no-verify`.
    """
    git_dir = _run("rev-parse", "--git-dir")
    if not git_dir:
        return False
    from pathlib import Path
    d = Path(git_dir)
    return any((d / n).exists()
               for n in ("MERGE_HEAD", "REVERT_HEAD", "CHERRY_PICK_HEAD"))


def current_branch() -> str:
    return _run("rev-parse", "--abbrev-ref", "HEAD")


def is_design_branch(branch: str) -> bool:
    return any(fnmatch.fnmatch(branch, g) for g in DESIGN_BRANCH_GLOBS)


def is_allowed(path: str) -> bool:
    return any(fnmatch.fnmatch(path, g) for g in DESIGN_ALLOWED)


def staged_files() -> list[str]:
    out = _run("diff", "--cached", "--name-only", "--diff-filter=ACMRT")
    return [p for p in out.splitlines() if p]


def resolve_ref(ref: str) -> str:
    """Pick the ref that actually answers "what would I merge into REF".

    A parallel workspace keeps a LOCAL `main` that nobody checks out and that
    therefore never advances. Measured on the first real run, 2026-09-09: the
    design clone's local `main` was SEVEN commits behind `origin/main`, so
    `--against main` diffed against a fortnight-stale tree and reported 36
    engine files — every one of them already merged in — as out of scope. A
    tool that answers confidently and wrongly is worse than no tool, so prefer
    the remote-tracking ref and always print which one was used.
    """
    if ref.startswith("origin/"):
        return ref
    remote = f"origin/{ref}"
    if _run("rev-parse", "--verify", "--quiet", remote):
        behind = _run("rev-list", "--count", f"{ref}..{remote}")
        if behind and behind != "0":
            print(f"· local '{ref}' is {behind} commit(s) behind {remote} — "
                  f"using {remote}")
        return remote
    return ref


def files_between(ref: str) -> list[str]:
    """Files HEAD would bring into `ref` — the pre-merge question."""
    out = _run("diff", "--name-only", "--diff-filter=ACMRT", f"{ref}...HEAD")
    return [p for p in out.splitlines() if p]


def report(paths: list[str], branch: str, *, blocking: bool) -> int:
    contested = [p for p in paths if p in CONTESTED]
    engine = [p for p in paths if p not in CONTESTED and not is_allowed(p)]

    if not contested and not engine:
        return 0

    label = "✗ OUT OF SCOPE" if blocking else "⚠ out of scope"
    print(f"{label} for branch '{branch}' — this is the design branch, which "
          f"owns the interface only.")
    print()

    for p in contested:
        print(f"  ⛔ {p}")
        print(f"     SHARED FILE — {CONTESTED[p]}")
        print()
    for p in engine:
        print(f"  ⛔ {p}")
    if engine:
        print()

    print("  What this branch MAY change:")
    for g in DESIGN_ALLOWED:
        print(f"    {g}")
    print()
    print("  Authority for this list: tools/persistent/check_design_scope.py")
    return 1 if blocking else 0


def warn_ui_on_main(paths: list[str], branch: str) -> None:
    ui = [p for p in paths if is_allowed(p) and p.startswith("godot/")]
    if not ui:
        return
    print(f"⚠ '{branch}' is not the design branch, but this commit touches "
          f"interface files:")
    for p in ui:
        print(f"    {p}")
    print("  CLAUDE.md makes Claude engine-only; UI belongs to "
          "feat/design-interface-hud.")
    print("  Not blocking — the Director works here too. (not blocking)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--against", metavar="REF",
                    help="report what HEAD would bring into REF (pre-merge)")
    ap.add_argument("--list", action="store_true",
                    help="print the design scope and exit")
    args = ap.parse_args()

    if args.list:
        print("Design branches:")
        for g in DESIGN_BRANCH_GLOBS:
            print(f"  {g}")
        print("\nPaths a design branch may change:")
        for g in DESIGN_ALLOWED:
            print(f"  {g}")
        print("\nShared files, blocked on a design branch:")
        for p in CONTESTED:
            print(f"  {p}")
        return 0

    branch = current_branch()

    if args.against:
        ref = resolve_ref(args.against)
        paths = files_between(ref)
        if not paths:
            print(f"✓ nothing to merge into {ref}")
            return 0
        print(f"'{branch}' would bring {len(paths)} file(s) into {ref}.")
        if not is_design_branch(branch):
            print("  (not a design branch — scope not enforced)")
            return 0
        rc = report(paths, branch, blocking=True)
        if rc == 0:
            print("✓ every file is inside the design scope — safe to merge.")
        return rc

    if merge_in_progress():
        print("· scope gate skipped — merge in progress (a sync from main "
              "stages engine files by design)")
        return 0

    paths = staged_files()
    if not paths:
        return 0

    if is_design_branch(branch):
        return report(paths, branch, blocking=True)

    warn_ui_on_main(paths, branch)
    return 0


if __name__ == "__main__":
    sys.exit(main())
