#!/usr/bin/env python3
"""
rename_tiles.py
Renames all Kenney isometric tile PNGs from Kenney's naming convention to
the project's screen-space naming convention, and updates all references.

Mapping:
  Kenney _N  ->  project _SE   (bottom-right of diamond)
  Kenney _E  ->  project _WS   (bottom-left of diamond)
  Kenney _S  ->  project _WN   (top-left of diamond)
  Kenney _W  ->  project _NE   (top-right of diamond)
"""

import os
import re
import sys

# --- Config -------------------------------------------------------------------

ROOT = os.path.dirname(os.path.abspath(__file__))

PNG_DIR = os.path.join(ROOT, "ASSETS", "ISOMETRIC", "blocks-prototype", "Isometric")

FILES_TO_UPDATE = [
    os.path.join(ROOT, "godot", "resources", "tilesets", "tileset_blocks.tres"),
    os.path.join(ROOT, "godot", "scripts", "world", "tile_registry.gd"),
    os.path.join(ROOT, "godot", "scripts", "world", "room_layout_builder.gd"),
    os.path.join(ROOT, "godot", "scripts", "world", "room.gd"),
]

MAP = {"N": "SE", "E": "WS", "S": "WN", "W": "NE"}

# Regex: matches _N _E _S _W before .png or before a closing quote "
SUFFIX_RE = re.compile(r'_([NESW])(\.png|(?=["\']))')

# Regex for bare tile-name strings that end with _N/_E/_S/_W before a quote
# (e.g. "floor_N" or 'wall_E')
TILE_STR_RE = re.compile(r'_([NESW])(?=["\'])')

# ------------------------------------------------------------------------------


def replace_suffix(text: str) -> str:
    """Replace all tile-name suffixes in a block of text."""
    def _sub(m):
        letter = m.group(1)
        rest = m.group(2)  # either ".png" or "" (lookahead for quote)
        return f"_{MAP[letter]}{rest}"
    return SUFFIX_RE.sub(_sub, text)


def process_png_dir():
    """Rename PNG files and delete their .import sidecars."""
    renamed = 0
    deleted = 0

    entries = sorted(os.listdir(PNG_DIR))
    png_files = [e for e in entries if e.endswith(".png")]

    for fname in png_files:
        # Only rename if it ends with _N.png, _E.png, _S.png, _W.png
        m = re.match(r'^(.+)_([NESW])\.png$', fname)
        if not m:
            print(f"  SKIP (unrecognised pattern): {fname}")
            continue

        base = m.group(1)
        letter = m.group(2)
        new_letter = MAP[letter]
        new_fname = f"{base}_{new_letter}.png"

        old_path = os.path.join(PNG_DIR, fname)
        new_path = os.path.join(PNG_DIR, new_fname)

        os.rename(old_path, new_path)
        renamed += 1
        print(f"  RENAMED: {fname}  ->  {new_fname}")

        # Delete .import sidecar (Godot regenerates it on next editor open)
        import_path = os.path.join(PNG_DIR, fname + ".import")
        if os.path.exists(import_path):
            os.remove(import_path)
            deleted += 1

    return renamed, deleted


def update_text_file(path: str) -> int:
    """Replace suffixes in a text file. Returns number of substitutions."""
    if not os.path.exists(path):
        print(f"  WARNING: file not found: {path}")
        return 0

    with open(path, "r", encoding="utf-8") as f:
        original = f.read()

    updated = replace_suffix(original)

    if updated == original:
        print(f"  NO CHANGES: {os.path.relpath(path, ROOT)}")
        return 0

    count = len(re.findall(r'_(?:SE|WS|WN|NE)', updated)) - len(re.findall(r'_(?:SE|WS|WN|NE)', original))
    with open(path, "w", encoding="utf-8") as f:
        f.write(updated)

    changed = sum(1 for a, b in zip(original.splitlines(), updated.splitlines()) if a != b)
    print(f"  UPDATED: {os.path.relpath(path, ROOT)}  ({changed} lines changed)")
    return changed


def main():
    print("=" * 60)
    print("STEP 1: Renaming PNG files + deleting .import sidecars")
    print("=" * 60)
    renamed, deleted = process_png_dir()
    print(f"\n  -> {renamed} PNGs renamed, {deleted} .import files deleted\n")

    print("=" * 60)
    print("STEP 2: Updating text references in project files")
    print("=" * 60)
    for path in FILES_TO_UPDATE:
        update_text_file(path)

    print()
    print("=" * 60)
    print("DONE. Next steps:")
    print("  1. Open Godot editor -> it will reimport all renamed PNGs")
    print("  2. Run Tools > build_tileset.gd to regenerate tile_registry.gd")
    print("  3. git add -A && git commit")
    print("=" * 60)


if __name__ == "__main__":
    main()
