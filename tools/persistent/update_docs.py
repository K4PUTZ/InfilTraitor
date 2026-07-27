#!/usr/bin/env python3
"""Auto-update documentation blocks during push.

Regenerates:
  - CODEMAP.md (via gen_codemap.py subprocess)
  - docs/production/current_state.md AUTO blocks (header, pending_prompts, inventory, version_history)

Marker blocks protect hand-written prose:
  <!-- AUTO:BEGIN section_id -->...generated...<!-- AUTO:END section_id -->

All content outside markers is copied byte-identical. Missing/malformed markers fail
loudly with non-zero exit (never guess, never append).

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


def get_git_branch() -> str:
    """Return current git branch name."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def get_git_head_short() -> str:
    """Return short commit hash."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def get_git_head_subject() -> str:
    """Return current commit subject."""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%s"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def get_version_string() -> str:
    """Read VERSION file; return MAJOR.MINOR.PATCH."""
    version_file = REPO_ROOT / "VERSION"
    try:
        return version_file.read_text(encoding="utf-8").strip()
    except Exception as e:
        print(f"[VERSION] ❌ Cannot read VERSION: {e}", file=sys.stderr)
        sys.exit(1)


def get_pending_prompts() -> list[str]:
    """List PROMPTS/*.md (root only, exclude DONE/PLANNING). Return sorted list."""
    prompts_dir = REPO_ROOT / "PROMPTS"
    if not prompts_dir.exists():
        return []
    prompts = []
    for f in prompts_dir.glob("*.md"):
        prompts.append(f.name)
    return sorted(prompts) if prompts else []


def count_inventory() -> dict[str, int]:
    """Count modules, tests, maps, shipped facades, archived prompts."""
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


def get_version_history(lines_count: int = 5) -> list[str]:
    """Return last N lines of git log touching VERSION, as plain strings."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-n", str(lines_count), "--", "VERSION"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip().split("\n") if result.returncode == 0 else []
    except Exception:
        return []


def build_auto_header() -> str:
    """Build AUTO:header content for docs/production/current_state.md.

    Deliberately carries NO commit hash/subject (removed 2026-07-10, Director
    decision): the header is regenerated at pre-commit time, so any commit it
    could name is the PREVIOUS one — a field that is stale by construction and
    reads as a lie ("Last commit: Alpha End Beep" weeks later). Version,
    date and branch are accurate at commit time; for history, use git.
    """
    version = get_version_string()
    date_str = datetime.now().strftime("%Y-%m-%d")
    branch = get_git_branch()

    return f"**Version:** {version} · **Updated:** {date_str} · **Branch:** {branch}"


def build_pending_prompts_block() -> str:
    """Build AUTO:pending_prompts content."""
    prompts = get_pending_prompts()
    if not prompts:
        return "(none)"
    return "\n".join(f"- {p}" for p in prompts)


def build_inventory_block() -> str:
    """Build AUTO:inventory content."""
    counts = count_inventory()
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


def build_version_history_block() -> str:
    """Build AUTO:version_history content (last 5 git log entries touching VERSION)."""
    lines = get_version_history(5)
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

    try:
        # AUTO:header
        header = build_auto_header()
        content, updated = replace_marker_block(content, "header", header)
        any_updated = any_updated or updated

        # AUTO:pending_prompts
        prompts = build_pending_prompts_block()
        content, updated = replace_marker_block(content, "pending_prompts", prompts)
        any_updated = any_updated or updated

        # AUTO:inventory
        inventory = build_inventory_block()
        content, updated = replace_marker_block(content, "inventory", inventory)
        any_updated = any_updated or updated

        # AUTO:version_history
        history = build_version_history_block()
        content, updated = replace_marker_block(content, "version_history", history)
        any_updated = any_updated or updated

        if any_updated:
            file_path.write_text(content, encoding="utf-8")
            return UpdateResult(
                file="docs/production/current_state.md",
                updated=True,
                reason="4 blocks refreshed"
            )
        else:
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
