#!/usr/bin/env python3
"""
Update corner_*_SW and corner_*_NE to 256×528 and correct origins.
Direct approach - find each asset and update backwards.
"""

import re
from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    content = f.read()

original = content
changes = 0

# For each asset, find it and update the texture_region_size and texture_origin BEFORE it
assets_sw_ne = {
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

for asset, (origin_x, origin_y) in assets_sw_ne.items():
    pattern = f'custom_data_0 = "{asset}"'
    pos = content.find(pattern)
    
    if pos > 0:
        # Find the texture_region_size line before this asset
        before = content[:pos]
        
        # Find last occurrence of texture_region_size = Vector2i(256, 512) before this asset
        size_search = 'texture_region_size = Vector2i(256, 512)'
        last_size_pos = before.rfind(size_search)
        
        if last_size_pos >= 0:
            # Replace this specific occurrence
            content = (content[:last_size_pos] + 
                      'texture_region_size = Vector2i(256, 528)' + 
                      content[last_size_pos + len(size_search):])
            print(f"✓ {asset}: texture_region_size 256×512 → 256×528")
            changes += 1

# Now update texture_origin for each asset
for asset, (origin_x, origin_y) in assets_sw_ne.items():
    pattern = f'custom_data_0 = "{asset}"'
    match = re.search(pattern, content)
    
    if match:
        pos = match.start()
        # Look backwards for texture_origin
        before = content[:pos]
        
        # Find the last texture_origin before this asset
        origin_patterns = [
            r'texture_origin = Vector2i\(0, -368\)',
            r'texture_origin = Vector2i\(-16, -392\)',
            r'texture_origin = Vector2i\(0, -384\)',
            r'texture_origin = Vector2i\(-32, -384\)',
            r'texture_origin = Vector2i\(32, -384\)',
            r'texture_origin = Vector2i\([^)]+\)',
        ]
        
        # Find any texture_origin before this asset
        last_origin_pos = -1
        for pattern_str in origin_patterns:
            matches = list(re.finditer(pattern_str, before))
            if matches:
                last_match = matches[-1]
                if last_match.start() > last_origin_pos:
                    last_origin_pos = last_match.start()
        
        if last_origin_pos >= 0:
            # Find the full match at that position
            after = content[last_origin_pos:]
            origin_match = re.match(r'texture_origin = Vector2i\([^)]+\)', after)
            if origin_match:
                old_origin = origin_match.group(0)
                new_origin = f'texture_origin = Vector2i({origin_x}, {origin_y})'
                content = (content[:last_origin_pos] + new_origin + 
                          content[last_origin_pos + len(old_origin):])
                print(f"✓ {asset}: texture_origin → ({origin_x}, {origin_y})")
                changes += 1

if content != original:
    with open(tileset_path, 'w') as f:
        f.write(content)
    print(f"\n✅ Updated {changes} items")
else:
    print("⚠️  No changes")
