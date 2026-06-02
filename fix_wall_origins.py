#!/usr/bin/env python3
"""
Apply ONLY the correct texture_origin values to wall_* and wallCorner_* assets.
Do NOT touch any other assets.
"""

import re
from pathlib import Path

# ONLY these origins for wall and wallCorner
ORIGINS = {
    # Standard wall origins
    "wall_SE": (16, -392),
    "wall_SW": (16, -376),
    "wall_NE": (-16, -392),
    "wall_NW": (-16, -376),
    # Corner origins
    "wallCorner_SE": (0, -400),
    "wallCorner_SW": (32, -384),
    "wallCorner_NE": (-32, -384),
    "wallCorner_NW": (0, -368),
}

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    content = f.read()

original_content = content
changes_made = 0

# Split into [sub_resource] blocks
blocks = content.split('[sub_resource')
new_blocks = [blocks[0]]  # Keep the first part

for block in blocks[1:]:
    new_block = block
    
    # Extract custom_data_0 to identify asset
    asset_match = re.search(r'custom_data_0 = "([^"]+)"', block)
    if asset_match:
        asset_name = asset_match.group(1)
        
        # ONLY process if it's exactly in our ORIGINS dict
        if asset_name in ORIGINS:
            new_origin = ORIGINS[asset_name]
            old_origin_pattern = r'texture_origin = Vector2i\([^)]+\)'
            new_origin_str = f"texture_origin = Vector2i({new_origin[0]}, {new_origin[1]})"
            
            if re.search(old_origin_pattern, new_block):
                old_val = re.search(old_origin_pattern, new_block).group(0)
                new_block = re.sub(old_origin_pattern, new_origin_str, new_block)
                changes_made += 1
                print(f"✓ {asset_name}: {new_origin}")
    
    new_blocks.append(new_block)

# Reconstruct content
new_content = '[sub_resource'.join(new_blocks)

if new_content != original_content:
    with open(tileset_path, 'w') as f:
        f.write(new_content)
    print(f"\n✅ Updated {changes_made} texture_origin values (ONLY wall_* and wallCorner_*)")
else:
    print("⚠️  No changes made")
