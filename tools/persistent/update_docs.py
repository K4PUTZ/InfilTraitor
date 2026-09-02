#!/usr/bin/env python3
"""Auto-update documentation blocks during push.

Regenerates:
  - CODEMAP.md (via gen_codemap.py subprocess)
  - docs/production/current_state.md AUTO blocks (header, pending_prompts, inventory, version_history)

Marker blocks protect hand-written prose:
  <!-- AUTO:BEGIN section_id -->...generated...<!-- AUTO:END section_id -->

All content outside markers is copied byte-identical. Missing/malformed markers fail
loudly with non-zero exit (never guess, never append).

⚠️ UNDETERMINED IS NOT EMPTY, and conflating the two silently destroyed a tracked
file. Measured 2026-09-02: a routine run on this repo (which lives on a slow
external drive) hit `get_version_history()`'s 5-second git timeout, the
`except Exception: return []` turned that into "no rows", and the caller wrote
the literal "(no version history)" OVER five real entries in
docs/production/current_state.md. Re-running a minute later restored them, so the
input was never empty — only unreadable, once. It was caught by reading the diff;
nothing in the tooling would have said a word.

So every source below answers with `None` for "I could not determine this" and
keeps [] / 0 / "" for "I determined this and it is empty", and a block whose
source is None is LEFT EXACTLY AS IT IS ON DISK. A skipped block also makes the
run exit non-zero, because this is the one signal that survives: the pre-commit
hook runs this script as `> /dev/null 2>&1`, so stderr never reaches a human
there — the exit code is what makes it decline to stage the file, and what makes
push.sh refuse to publish a doc it could not verify.

Usage:
    python3 tools/persistent/update_docs.py
    echo $?  # 0 on success, 1 on failure (e.g., stale CODEMAP, missing marker)
"""

from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

## A git read on this repo is a read from a slow external drive, and the 5-second
## limit these calls carried was measured failing on a COLD cache and succeeding
## a minute later. The retry is what makes "undetermined" rare enough that
## treating it as an error is reasonable rather than a nuisance.
GIT_TIMEOUT_S = 20
GIT_ATTEMPTS = 2


def _git(args: list[str]) -> str | None:
    """Run a git command and return its stdout, or None if it could not be run.

    None means UNDETERMINED and never "the answer is empty" — a command that
    succeeds and prints nothing returns "". Callers must keep that distinction:
    it is the whole point of this module.
    """
    for attempt in range(GIT_ATTEMPTS):
        try:
            result = subprocess.run(
                ["git"] + args,
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                timeout=GIT_TIMEOUT_S,
            )
        except Exception as e:
            if attempt == GIT_ATTEMPTS - 1:
                print(f"[GIT] ❌ `git {' '.join(args)}` failed: {e}", file=sys.stderr)
                return None
            continue
        if result.returncode == 0:
            return result.stdout
        if attempt == GIT_ATTEMPTS - 1:
            print(f"[GIT] ❌ `git {' '.join(args)}` exited {result.returncode}: "
                  f"{result.stderr.strip()}", file=sys.stderr)
            return None
    return None


@dataclass
class UpdateResult:
    file: str
    updated: bool
    reason: str


def run_gen_codemap() -> bool:
    """Regenerate CODEMAP.md via gen_codemap.py subprocess. Return True on success."""
    script = REPO_ROOT / "tools" / "persistent" / "gen_codemap.py"
    try:
        result = subprocess.run(
            [sys.executable, str(script)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode != 0:
            print(f"[CODEMAP] ❌ gen_codemap.py failed:", file=sys.stderr)
            print(result.stderr, file=sys.stderr)
            return False
        print(f"[CODEMAP] ✅ {result.stdout.strip()}")
        return True
    except Exception as e:
        print(f"[CODEMAP] ❌ Exception: {e}", file=sys.stderr)
        return False


def get_git_branch() -> str | None:
    """Return current git branch name, or None if it could not be read.

    It used to answer "unknown", which is a VALUE — it would be written into the
    header over a correct branch name on any transient failure.
    """
    out = _git(["rev-parse", "--abbrev-ref", "HEAD"])
    return out.strip() if out is not None else None


def get_git_head_short() -> str | None:
    """Return short commit hash, or None if it could not be read."""
    out = _git(["rev-parse", "--short", "HEAD"])
    return out.strip() if out is not None else None


def get_git_head_subject() -> str | None:
    """Return current commit subject, or None if it could not be read."""
    out = _git(["log", "-1", "--format=%s"])
    return out.strip() if out is not None else None


def get_version_string() -> str:
    """Read VERSION file; return MAJOR.MINOR.PATCH."""
    version_file = REPO_ROOT / "VERSION"
    try:
        return version_file.read_text(encoding="utf-8").strip()
    except Exception as e:
        print(f"[VERSION] ❌ Cannot read VERSION: {e}", file=sys.stderr)
        sys.exit(1)


def get_pending_prompts() -> list[str] | None:
    """List PROMPTS/*.md (root only, exclude DONE/PLANNING), or None if the tree
    could not be read.

    `PROMPTS/` always exists in this repo, so its ABSENCE is not the true answer
    "there are no prompts" — it is the working tree being unreadable, which on an
    external drive is a real transient. An empty root, on the other hand, is a
    real and common state: measured, 60 commits in this file's history carry a
    genuine "(none)" from an era when every prompt was archived.
    """
    prompts_dir = REPO_ROOT / "PROMPTS"
    if not prompts_dir.is_dir():
        print("[PROMPTS] ❌ PROMPTS/ is not readable — pending_prompts undetermined",
              file=sys.stderr)
        return None
    prompts = []
    for f in prompts_dir.glob("*.md"):
        prompts.append(f.name)
    return sorted(prompts) if prompts else []


def count_inventory() -> dict[str, int] | None:
    """Count modules, tests, maps, shipped facades, archived prompts — or None if
    the tree could not be read.

    ⚠️ The guard is `godot/scripts/` ONLY, and the asymmetry is deliberate.
    That directory always exists, so its absence means an unreadable tree and a
    zeroed inventory would be a lie. `godot/textures/defaults/` genuinely does
    NOT exist any more (assets moved to ASSETS/materials/<id>/ on 2026-08-21), so
    `shipped_facades: 0` is the measured truth and must NOT be turned into an
    error — the one that is really missing is the one that must not fail.
    """
    scripts_dir_probe = REPO_ROOT / "godot" / "scripts"
    if not scripts_dir_probe.is_dir():
        print("[INVENTORY] ❌ godot/scripts/ is not readable — inventory undetermined",
              file=sys.stderr)
        return None
    result = {
        "gdscript_modules": 0,
        "test_scripts": 0,
        "known_maps": 0,
        "shipped_facades": 0,
        "archived_prompts": 0,
    }

    # GDScript modules under godot/scripts/ (excluding tools/)
    scripts_dir = REPO_ROOT / "godot" / "scripts"
    if scripts_dir.exists():
        for f in scripts_dir.rglob("*.gd"):
            if "tools" not in f.parts:
                result["gdscript_modules"] += 1

    # Test scripts
    tools_dir = scripts_dir / "tools" if scripts_dir.exists() else None
    if tools_dir and tools_dir.exists():
        for f in tools_dir.glob("*_test*.gd"):
            result["test_scripts"] += 1
        for f in tools_dir.glob("*selftest*.gd"):
            result["test_scripts"] += 1

    # Known maps (from MapCatalog.list_map_ids())
    result["known_maps"] = 3  # PLAYGROUND, SIGMA_01, PROCEDURAL

    # Shipped facades in godot/textures/defaults/ (if it exists)
    facades_dir = REPO_ROOT / "godot" / "textures" / "defaults"
    if facades_dir.exists():
        result["shipped_facades"] = len(list(facades_dir.glob("*.png")))

    # Archived prompts in PROMPTS/DONE/
    done_dir = REPO_ROOT / "PROMPTS" / "DONE"
    if done_dir.exists():
        result["archived_prompts"] = len(list(done_dir.glob("*.md")))

    return result


def get_version_history(lines_count: int = 5) -> list[str] | None:
    """Last N git log entries touching VERSION, or None if git could not be run.

    ⚠️ THE ORIGINAL DEFECT LIVED HERE. A timeout returned [], the caller could
    not tell that from "VERSION has no history", and five real rows were
    overwritten with "(no version history)".
    """
    out = _git(["log", "--oneline", "-n", str(lines_count), "--", "VERSION"])
    if out is None:
        return None
    stripped = out.strip()
    return stripped.split("\n") if stripped else []


def build_auto_header() -> str | None:
    """Build AUTO:header content for docs/production/current_state.md.

    Deliberately carries NO commit hash/subject (removed 2026-07-10, Director
    decision): the header is regenerated at pre-commit time, so any commit it
    could name is the PREVIOUS one — a field that is stale by construction and
    reads as a lie ("Last commit: Alpha End Beep" weeks later). Version,
    date and branch are accurate at commit time; for history, use git.
    """
    branch = get_git_branch()
    if branch is None:
        return None
    version = get_version_string()
    date_str = datetime.now().strftime("%Y-%m-%d")

    return f"**Version:** {version} · **Updated:** {date_str} · **Branch:** {branch}"


def build_pending_prompts_block() -> str | None:
    """Build AUTO:pending_prompts content, or None if it is undetermined."""
    prompts = get_pending_prompts()
    if prompts is None:
        return None
    if not prompts:
        return "(none)"
    return "\n".join(f"- {p}" for p in prompts)


def build_inventory_block() -> str | None:
    """Build AUTO:inventory content, or None if it is undetermined."""
    counts = count_inventory()
    if counts is None:
        return None
    lines = [
        "**Code & Test Inventory**",
        "",
        f"- GDScript modules: {counts['gdscript_modules']}",
        f"- Test scripts: {counts['test_scripts']}",
        f"- Known maps: {counts['known_maps']}",
        f"- Shipped facade files: {counts['shipped_facades']}",
        f"- Archived prompts: {counts['archived_prompts']}",
    ]
    return "\n".join(lines)


def build_version_history_block() -> str | None:
    """AUTO:version_history content, or None if git could not be read.

    "(no version history)" is now reachable ONLY from a git command that ran and
    printed nothing — never from a failure.
    """
    lines = get_version_history(5)
    if lines is None:
        return None
    if not lines or lines == [""]:
        return "(no version history)"
    return "\n".join(f"- {line}" for line in lines if line)


def replace_marker_block(
    content: str,
    section_id: str,
    new_content: str,
) -> tuple[str, bool]:
    """Replace content between markers. Return (new_content, was_updated).
    
    Raises ValueError if markers are missing or malformed.
    """
    begin_marker = f"<!-- AUTO:BEGIN {section_id} -->"
    end_marker = f"<!-- AUTO:END {section_id} -->"

    if begin_marker not in content:
        raise ValueError(f"Missing marker: {begin_marker}")
    if end_marker not in content:
        raise ValueError(f"Missing marker: {end_marker}")

    # Ensure markers are in correct order
    begin_idx = content.index(begin_marker)
    end_idx = content.index(end_marker)
    if begin_idx >= end_idx:
        raise ValueError(f"Markers in wrong order for {section_id}")

    # Extract the parts
    before = content[:begin_idx + len(begin_marker)]
    after = content[end_idx:]

    # Get old content for change detection
    old_inner = content[begin_idx + len(begin_marker):end_idx]

    # Build new content
    new_inner = "\n" + new_content + "\n"
    result = before + new_inner + after

    # Detect if anything changed
    was_updated = (old_inner != new_inner)
    return result, was_updated


def update_current_state_md() -> UpdateResult:
    """Update docs/production/current_state.md AUTO blocks."""
    file_path = REPO_ROOT / "docs" / "production" / "current_state.md"

    if not file_path.exists():
        return UpdateResult(
            file="docs/production/current_state.md",
            updated=False,
            reason="file not found"
        )

    content = file_path.read_text(encoding="utf-8")
    any_updated = False
    skipped: list[str] = []

    try:
        ## A builder answering None means UNDETERMINED, and the block is left
        ## byte-identical — the same protection the prose outside the markers
        ## already had. Content on disk was written when the source WAS readable,
        ## so it is the best answer available; generated-from-nothing is not.
        for section_id, builder in (
            ("header", build_auto_header),
            ("pending_prompts", build_pending_prompts_block),
            ("inventory", build_inventory_block),
            ("version_history", build_version_history_block),
        ):
            block = builder()
            if block is None:
                skipped.append(section_id)
                continue
            content, updated = replace_marker_block(content, section_id, block)
            any_updated = any_updated or updated

        if any_updated:
            file_path.write_text(content, encoding="utf-8")

        if skipped:
            return UpdateResult(
                file="docs/production/current_state.md",
                updated=any_updated,
                reason="UNDETERMINED, left on disk: %s" % ", ".join(skipped),
            )
        if any_updated:
            return UpdateResult(
                file="docs/production/current_state.md",
                updated=True,
                reason="4 blocks refreshed"
            )
        return UpdateResult(
            file="docs/production/current_state.md",
            updated=False,
            reason="all blocks unchanged"
        )

    except ValueError as e:
        return UpdateResult(
            file="docs/production/current_state.md",
            updated=False,
            reason=f"marker error: {e}"
        )


def check_version_consistency() -> bool:
    """Validate VERSION file format (MAJOR.MINOR.PATCH). Return True if valid."""
    version = get_version_string()
    parts = version.split(".")
    if len(parts) != 3:
        print(f"[VERSION-CHECK] ❌ VERSION is not MAJOR.MINOR.PATCH: {version}", file=sys.stderr)
        return False
    try:
        [int(p) for p in parts]
        return True
    except ValueError:
        print(f"[VERSION-CHECK] ❌ VERSION contains non-integer parts: {version}", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point. Return 0 on success, 1 on failure."""
    print()
    print("=" * 70)
    print("DOC-HOOK-01: Auto-Update Documentation")
    print("=" * 70)
    print()

    # Step 1: Version consistency check
    print("[STEP 1] Version consistency check...")
    if not check_version_consistency():
        return 1
    print(f"[VERSION-CHECK] ✅ VERSION valid: {get_version_string()}")
    print()

    # Step 2: Regenerate CODEMAP.md
    print("[STEP 2] Regenerate CODEMAP.md...")
    if not run_gen_codemap():
        return 1
    print()

    # Step 3: Update AUTO blocks in current_state.md
    print("[STEP 3] Update docs/production/current_state.md AUTO blocks...")
    result = update_current_state_md()
    if result.reason.startswith("marker error") or result.reason == "file not found":
        print(f"[current_state.md] ❌ {result.reason}", file=sys.stderr)
        return 1

    ## ⚠️ THE EXIT CODE IS THE ONLY SIGNAL THAT SURVIVES HERE. The pre-commit
    ## hook runs this script as `> /dev/null 2>&1`, so a message on stderr
    ## reaches nobody in the path where the damage happens. Non-zero is what
    ## makes that hook print its warning and DECLINE TO STAGE the file, and what
    ## makes push.sh refuse to publish a doc it could not verify. The blocks
    ## themselves are already safe by then — this is the report, not the fix.
    if result.reason.startswith("UNDETERMINED"):
        print(f"[current_state.md] ❌ {result.reason}", file=sys.stderr)
        print("[current_state.md] the block(s) on disk were NOT overwritten. "
              "Re-run once the source is readable.", file=sys.stderr)
        print()
        print("=" * 70)
        print("❌ Documentation refresh INCOMPLETE — see above")
        print("=" * 70)
        print()
        return 1

    status = "✅ UPDATED" if result.updated else "⏭️  UNCHANGED"
    print(f"[current_state.md] {status} ({result.reason})")
    print()

    print("=" * 70)
    print("✅ Documentation refresh complete")
    print("=" * 70)
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
