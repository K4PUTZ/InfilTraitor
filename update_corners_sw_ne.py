#!/usr/bin/env python3
"""
Update all corner_*_SW and corner_*_NE assets to match wallCorner pattern:
- texture_region_size: 256×528 (height 512 → 528)
- SW: texture_origin → (32, -392)
- NE: texture_origin → (-32, -392)
"""

import re
from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    lines = f.readlines()

# Map of assets to their new origins
updates = {
    "columnCorner_SW": (32, -392),
    "columnCorner_NE": (-32, -392),
    "sloperCornerInner_SW": (32, -392),
    "sloperCornerInner_NE": (-32, -392),
    "sloperCornerOuter_SW": (32, -392),
    "sloperCornerOuter_NE": (-32, -392),
    "stairsCornerInner_SW": (32, -392),
    "stairsCornerInner_NE": (-32, -392),
    "stairsCornerOuter_SW": (32, -392),
    "stairsCornerOuter_NE": (-32, -392),
    "stairsOpenCornerInner_SW": (32, -392),
    "stairsOpenCornerInner_NE": (-32, -392),
    "stairsOpenCornerOuter_SW": (32, -392),
    "stairsOpenCornerOuter_NE": (-32, -392),
    "wallCornerHalf_SW": (32, -392),
    "wallCornerHalf_NE": (-32, -392),
}

changes = 0
current_asset = None

i = 0
while i < len(lines):
    # Track current asset
    if 'custom_data_0 = "' in lines[i]:
        match = re.search(r'custom_data_0 = "([^"]+)"', lines[i])
        if match:
            current_asset = match.group(1)
    
    # If this is a texture_region_size line and we're in an asset to update
    if current_asset and current_asset in updates:
        if 'texture_region_size = Vector2i(256, 512)' in lines[i]:
            lines[i] = lines[i].replace(
                'Vector2i(256, 512)',
                'Vector2i(256, 528)'
            )
            print(f"✓ {current_asset}: texture_region_size 256×512 → 256×528")
            changes += 1
    
    # If this is a texture_origin line and we're in an asset to update
    if current_asset and current_asset in updates:
        if 'texture_origin = Vector2i(' in lines[i]:
            new_origin = updates[current_asset]
            lines[i] = re.sub(
                r'texture_origin = Vector2i\([^)]+\)',
                f'texture_origin = Vector2i({new_origin[0]}, {new_origin[1]})',
                lines[i]
            )
            print(f"✓ {current_asset}: texture_origin → ({new_origin[0]}, {new_origin[1]})")
            current_asset = None  # Reset
    
    i += 1

with open(tileset_path, 'w') as f:
    f.writelines(lines)

print(f"\n✅ Updated corner assets SW/NE")
