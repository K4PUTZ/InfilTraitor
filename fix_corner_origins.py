#!/usr/bin/env python3
"""
Fix texture_origin for wallCorner_SE and wallCorner_NW
"""

import re
from pathlib import Path

tileset_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/godot/resources/tilesets/tileset_blocks.tres")

with open(tileset_path, 'r') as f:
    lines = f.readlines()

changes = 0

for i in range(len(lines)):
    # wallCorner_SE: find texture_origin = Vector2i(0, -400) that comes before custom_data_0 = "wallCorner_SE"
    if 'custom_data_0 = "wallCorner_SE"' in lines[i]:
        # Look backwards for the texture_origin
        for j in range(i-1, max(0, i-15), -1):
            if 'texture_origin = Vector2i(0, -400)' in lines[j]:
                lines[j] = lines[j].replace('Vector2i(0, -400)', 'Vector2i(-32, -400)')
                changes += 1
                print("✓ wallCorner_SE texture_origin: (0,-400) → (-32,-400)")
                break
    
    # wallCorner_NW: find texture_origin = Vector2i(0, -368) that comes before custom_data_0 = "wallCorner_NW"
    if 'custom_data_0 = "wallCorner_NW"' in lines[i]:
        # Look backwards for the texture_origin
        for j in range(i-1, max(0, i-15), -1):
            if 'texture_origin = Vector2i(0, -368)' in lines[j]:
                lines[j] = lines[j].replace('Vector2i(0, -368)', 'Vector2i(-32, -368)')
                changes += 1
                print("✓ wallCorner_NW texture_origin: (0,-368) → (-32,-368)")
                break

if changes > 0:
    with open(tileset_path, 'w') as f:
        f.writelines(lines)
    print(f"\n✅ Updated {changes} texture_origin values")
else:
    print("⚠️  No changes made")
