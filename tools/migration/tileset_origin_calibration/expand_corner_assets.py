#!/usr/bin/env python3
"""
Adjust wallCorner_SE and wallCorner_NW for expanded canvas (256→320px width).
Updates texture_region_size and texture_origin to compensate the -32px shift.
"""

import re
from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    content = f.read()

original_content = content

# Search and replace for each corner asset
# wallCorner_SE: texture_region_size + texture_origin + location of asset

# Find and replace the TileSetAtlasSource blocks for each corner asset

# wallCorner_SE - find the section starting with texture = ExtResource("120_j87jf")
# and update texture_region_size from Vector2i(256, 512) to Vector2i(320, 512)
pattern_se = r'(texture = ExtResource\("120_j87jf"\)\ntexture_region_size = )Vector2i\(256, 512\)'
replacement_se = r'\1Vector2i(320, 512)'
content = re.sub(pattern_se, replacement_se, content)

# wallCorner_NW - find the section starting with texture = ExtResource("121_ap31o")
pattern_nw = r'(texture = ExtResource\("121_ap31o"\)\ntexture_region_size = )Vector2i\(256, 512\)'
replacement_nw = r'\1Vector2i(320, 512)'
content = re.sub(pattern_nw, replacement_nw, content)

# Update texture_origin for wallCorner_SE: (0, -400) → (-32, -400)
content = re.sub(
    r'(0:0/0/custom_data_0 = "wallCorner_SE"\n\s+0:0/0/custom_data_2 = true\n\s+0:0/0/)texture_origin = Vector2i\(0, -400\)',
    r'\1texture_origin = Vector2i(-32, -400)',
    content
)

# Update texture_origin for wallCorner_NW: (0, -368) → (-32, -368)
content = re.sub(
    r'(0:0/0/custom_data_0 = "wallCorner_NW"\n\s+0:0/0/custom_data_2 = true\n\s+0:0/0/)texture_origin = Vector2i\(0, -368\)',
    r'\1texture_origin = Vector2i(-32, -368)',
    content
)

if content != original_content:
    with open(tileset_path, 'w') as f:
        f.write(content)
    print("✅ Updated wallCorner_SE and wallCorner_NW:")
    print("  ✓ texture_region_size: 256×512 → 320×512")
    print("  ✓ wallCorner_SE texture_origin: (0,-400) → (-32,-400)")
    print("  ✓ wallCorner_NW texture_origin: (0,-368) → (-32,-368)")
else:
    print("⚠️  No changes made")
