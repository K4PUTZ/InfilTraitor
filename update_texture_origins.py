#!/usr/bin/env python3
"""
Update texture_origin for all wall-aligned assets in tileset_blocks.tres
Apply the calibrated origins from wall_* and wallCorner_* to all directional variants.
"""

import re
from pathlib import Path

# Define the proper origins based on calibration
STANDARD_ORIGINS = {
    "SE": (16, -392),
    "SW": (16, -376),
    "NE": (-16, -392),
    "NW": (-16, -376),
}

CORNER_ORIGINS = {
    "SE": (0, -400),
    "SW": (32, -384),
    "NE": (-32, -384),
    "NW": (0, -368),
}

# Asset families that should use standard wall origins
WALL_ALIGNED_FAMILIES = {
    "window_",
    "windowLeft_",
    "windowMiddle_",
    "windowRight_",
    "doorOpen_",
    "doorClosed_",
    "doorway",
    "column_",
    "columnBlocks_",
    "poleGroup_",
    "pole_",
    "crate_",
}

# Asset families that should use corner origins
CORNER_ALIGNED_FAMILIES = {
    "columnCorner_",
    "wallCornerHalf_",
}

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    content = f.read()

original_content = content

# Split into [sub_resource] blocks
blocks = content.split('[sub_resource')
new_blocks = [blocks[0]]  # Keep the first part (before any sub_resources)

changes_made = 0

for block in blocks[1:]:
    new_block = block
    
    # Extract custom_data_0 to identify asset
    asset_match = re.search(r'custom_data_0 = "([^"]+)"', block)
    if asset_match:
        asset_name = asset_match.group(1)
        new_origin = None
        
        # Determine which origin to use
        for direction in ["SE", "SW", "NE", "NW"]:
            if asset_name.endswith("_" + direction):
                # Check if corner-aligned
                for family in CORNER_ALIGNED_FAMILIES:
                    if asset_name.startswith(family):
                        new_origin = CORNER_ORIGINS[direction]
                        break
                
                # If not corner, check standard wall-aligned
                if not new_origin:
                    for family in WALL_ALIGNED_FAMILIES:
                        if asset_name.startswith(family):
                            new_origin = STANDARD_ORIGINS[direction]
                            break
                
                break
        
        # Apply update if found
        if new_origin:
            old_origin_pattern = r'texture_origin = Vector2i\([^)]+\)'
            new_origin_str = f"texture_origin = Vector2i({new_origin[0]}, {new_origin[1]})"
            
            if re.search(old_origin_pattern, new_block):
                new_block = re.sub(old_origin_pattern, new_origin_str, new_block)
                changes_made += 1
                print(f"✓ {asset_name}: {new_origin}")
    
    new_blocks.append(new_block)

# Reconstruct content
new_content = '[sub_resource'.join(new_blocks)

if new_content != original_content:
    with open(tileset_path, 'w') as f:
        f.write(new_content)
    print(f"\n✅ Updated {changes_made} texture_origin values")
else:
    print("⚠️  No changes made")



