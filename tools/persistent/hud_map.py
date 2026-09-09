#!/usr/bin/env python3
"""Print the HUD's node tree and geometry as a compact map.

For JAMES, whose whole job is this scene and who works in a 32K context.
Reading godot/scenes/ui/hud.tscn costs ~1 300 tokens — 4% of his window — and
nearly all of it is boilerplate he does not need. This prints the same
information in ~250: every node path (which is what hud_controller.setup()
resolves), its type, and the numbers that actually decide layout.

QWEN.md carries a snapshot of this output so the common case costs him nothing
at all. That snapshot is a SNAPSHOT — after changing the scene, run this and
paste the new one in, or the map lies about the thing it exists to describe.

    python3 tools/persistent/hud_map.py
    python3 tools/persistent/hud_map.py --check   # snapshot still current?
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

SCENE = "godot/scenes/ui/hud.tscn"
SNAPSHOT_HOST = "QWEN.md"
FENCE = "```hud-map"

## Only the properties that change where a control sits or how big it is.
GEOMETRY_KEYS = ("custom_minimum_size", "anchors_preset", "offset_left",
                 "offset_top", "offset_right", "offset_bottom", "visible",
                 "text")


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, check=False).stdout.strip()
    return Path(out) if out else Path.cwd()


def build_map(scene_text: str) -> str:
    node_re = re.compile(
        r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?')
    order: list[tuple[str, str]] = []
    props: dict[str, dict[str, str]] = {}
    current: str | None = None

    for line in scene_text.splitlines():
        m = node_re.match(line)
        if m:
            name, node_type, parent = m.group(1), m.group(2), m.group(3) or ""
            path = name if parent in ("", ".") else f"{parent}/{name}"
            current = path
            order.append((path, node_type))
            props[path] = {}
            continue
        if current and "=" in line and not line.startswith("["):
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip()
            if key in GEOMETRY_KEYS:
                props[current][key] = value

    lines: list[str] = []
    for path, node_type in order:
        p = props.get(path, {})
        bits: list[str] = []
        if "custom_minimum_size" in p:
            bits.append("min" + p["custom_minimum_size"].replace("Vector2", ""))
        if "anchors_preset" in p:
            bits.append(f"preset={p['anchors_preset']}")
        offsets = [p.get(f"offset_{side}") for side in
                   ("left", "top", "right", "bottom")]
        if any(offsets):
            bits.append("off(" + ",".join(o or "·" for o in offsets) + ")")
        if p.get("visible") == "false":
            bits.append("hidden")
        if "text" in p:
            bits.append(f"text={p['text']}")
        indent = "  " * path.count("/")
        leaf = path.split("/")[-1]
        lines.append(f"{indent}{leaf:<20} {node_type:<15} {' '.join(bits)}".rstrip())
    return "\n".join(lines)


def snapshot_in(host_text: str) -> str | None:
    start = host_text.find(FENCE)
    if start == -1:
        return None
    start = host_text.index("\n", start) + 1
    end = host_text.find("```", start)
    return host_text[start:end].rstrip("\n") if end != -1 else None


def main() -> int:
    root = repo_root()
    scene = root / SCENE
    if not scene.is_file():
        print(f"[HUD-MAP] {SCENE} not found — run from the repository.",
              file=sys.stderr)
        return 2

    current = build_map(scene.read_text())

    if "--check" in sys.argv:
        host = root / SNAPSHOT_HOST
        if not host.is_file():
            print(f"[HUD-MAP] no {SNAPSHOT_HOST} to check against.")
            return 0
        saved = snapshot_in(host.read_text())
        if saved is None:
            print(f"[HUD-MAP] {SNAPSHOT_HOST} carries no `{FENCE}` block.")
            return 1
        if saved.strip() == current.strip():
            print(f"[HUD-MAP] ✓ the {SNAPSHOT_HOST} snapshot matches the scene.")
            return 0
        print(f"[HUD-MAP] ✗ the {SNAPSHOT_HOST} snapshot is STALE — the scene "
              f"changed. Paste this in:\n")
        print(current)
        return 1

    print(current)
    return 0


if __name__ == "__main__":
    sys.exit(main())
