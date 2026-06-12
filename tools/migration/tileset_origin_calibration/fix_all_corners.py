#!/usr/bin/env python3
"""
Expand all corner_*_SE and corner_*_NW assets from 256→320 width.
Direct string replacement approach.
"""

import re
from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    content = f.read()

original_content = content

# Assets that need expansion
expand_after = [
    "sloperCornerInner_SE", "sloperCornerInner_NW",
    "sloperCornerOuter_SE", "sloperCornerOuter_NW",
    "stairsCornerInner_SE", "stairsCornerInner_NW",
    "stairsCornerOuter_SE", "stairsCornerOuter_NW",
    "stairsOpenCornerInner_SE", "stairsOpenCornerInner_NW",
    "stairsOpenCornerOuter_SE", "stairsOpenCornerOuter_NW",
    "wallCornerHalf_SE", "wallCornerHalf_NW",
    "columnCorner_SE", "columnCorner_NW",
]

changes = 0

for asset in expand_after:
    # Find: texture_region_size = Vector2i(256, 512) that comes BEFORE this asset
    # Pattern: find the asset custom_data_0 line, then search backwards for texture_region_size
    
    pattern = f'custom_data_0 = "{asset}"'
    match = re.search(pattern, content)
    
    if match:
        # Get position of this asset
        pos = match.start()
        
        # Search backwards from this position for texture_region_size 256x512
        search_text = content[:pos]
        
        # Find the last occurrence of texture_region_size = Vector2i(256, 512) before this asset
        last_size_pos = search_text.rfind('texture_region_size = Vector2i(256, 512)')
        
        if last_size_pos != -1:
            # Replace this specific occurrence
            content = (content[:last_size_pos] + 
                      'texture_region_size = Vector2i(320, 512)' + 
                      content[last_size_pos + len('texture_region_size = Vector2i(256, 512)'):])
            changes += 1
            print(f"✓ {asset}: texture_region_size 256→320")

if content != original_content:
    with open(tileset_path, 'w') as f:
        f.write(content)
    print(f"\n✅ Updated {changes} corner assets")
else:
    print("⚠️  No changes made")
