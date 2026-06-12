#!/usr/bin/env python3
"""
Expand all corner_*_SE and corner_*_NW assets from 256→320 width.
Keeps texture_origin X at 0 (anchor is center, asset expands both sides).
"""

from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    lines = f.readlines()

# Assets that need expansion (SE and NW only)
assets_to_expand = {
    "columnCorner_SE", "columnCorner_NW",
    "sloperCornerInner_SE", "sloperCornerInner_NW",
    "sloperCornerOuter_SE", "sloperCornerOuter_NW",
    "stairsCornerInner_SE", "stairsCornerInner_NW",
    "stairsCornerOuter_SE", "stairsCornerOuter_NW",
    "stairsOpenCornerInner_SE", "stairsOpenCornerInner_NW",
    "stairsOpenCornerOuter_SE", "stairsOpenCornerOuter_NW",
    "wallCornerHalf_SE", "wallCornerHalf_NW",
}

changes = 0
current_asset = None

for i in range(len(lines)):
    # Track current asset
    if 'custom_data_0 = "' in lines[i]:
        import re
        match = re.search(r'custom_data_0 = "([^"]+)"', lines[i])
        if match:
            current_asset = match.group(1)
    
    # If this is a texture_region_size line and we're in an asset to expand
    if current_asset and current_asset in assets_to_expand:
        if 'texture_region_size = Vector2i(256, 512)' in lines[i]:
            lines[i] = lines[i].replace(
                'Vector2i(256, 512)',
                'Vector2i(320, 512)'
            )
            changes += 1
            print(f"✓ {current_asset}: texture_region_size 256→320")
            current_asset = None  # Reset for next asset

with open(tileset_path, 'w') as f:
    f.writelines(lines)

print(f"\n✅ Updated {changes} corner assets (SE/NW expansion)")

