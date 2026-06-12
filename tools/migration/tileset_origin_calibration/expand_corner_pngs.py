#!/usr/bin/env python3
"""
Expand corner asset PNGs to match tileset declarations:
- SE/NW corners: 256×512 → 320×512 (add 64px width, 32px each side, anchor centered)
- SW/NE corners: 256×512 → 256×528 (add 16px height to bottom, anchor top/center)
"""

from PIL import Image
from pathlib import Path

base_path = Path("/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/ASSETS/ISOMETRIC/blocks-prototype/Isometric")

# SE/NW corners: expand width to 320×512 (add 32px left, 32px right)
se_nw_assets = [
    "columnCorner_SE.png", "columnCorner_NW.png",
    "sloperCornerInner_SE.png", "sloperCornerInner_NW.png",
    "sloperCornerOuter_SE.png", "sloperCornerOuter_NW.png",
    "stairsCornerInner_SE.png", "stairsCornerInner_NW.png",
    "stairsCornerOuter_SE.png", "stairsCornerOuter_NW.png",
    "stairsOpenCornerInner_SE.png", "stairsOpenCornerInner_NW.png",
    "stairsOpenCornerOuter_SE.png", "stairsOpenCornerOuter_NW.png",
    "wallCornerHalf_SE.png", "wallCornerHalf_NW.png",
]

# SW/NE corners: expand height to 256×528 (add 16px to bottom)
sw_ne_assets = [
    "columnCorner_SW.png", "columnCorner_NE.png",
    "sloperCornerInner_SW.png", "sloperCornerInner_NE.png",
    "sloperCornerOuter_SW.png", "sloperCornerOuter_NE.png",
    "stairsCornerInner_SW.png", "stairsCornerInner_NE.png",
    "stairsCornerOuter_SW.png", "stairsCornerOuter_NE.png",
    "stairsOpenCornerInner_SW.png", "stairsOpenCornerInner_NE.png",
    "stairsOpenCornerOuter_SW.png", "stairsOpenCornerOuter_NE.png",
    "wallCornerHalf_SW.png", "wallCornerHalf_NE.png",
]

print("🎨 Expanding corner assets...\n")

# Process SE/NW (width expansion)
print("📐 SE/NW Corners (256×512 → 320×512, +32px each side):")
for asset in se_nw_assets:
    filepath = base_path / asset
    if filepath.exists():
        img = Image.open(filepath)
        if img.size == (256, 512):
            # Create new image with transparent background (RGBA)
            new_img = Image.new('RGBA', (320, 512), (0, 0, 0, 0))
            # Paste original in center (32px from left)
            new_img.paste(img, (32, 0), img if img.mode == 'RGBA' else None)
            new_img.save(filepath)
            print(f"  ✓ {asset}: 256×512 → 320×512")
        else:
            print(f"  ⚠️  {asset}: Already {img.size}, skipping")
    else:
        print(f"  ✗ {asset}: Not found")

# Process SW/NE (height expansion)
print("\n📏 SW/NE Corners (256×512 → 256×528, +16px bottom):")
for asset in sw_ne_assets:
    filepath = base_path / asset
    if filepath.exists():
        img = Image.open(filepath)
        if img.size == (256, 512):
            # Create new image with transparent background (RGBA)
            new_img = Image.new('RGBA', (256, 528), (0, 0, 0, 0))
            # Paste original at top (0 from top)
            new_img.paste(img, (0, 0), img if img.mode == 'RGBA' else None)
            new_img.save(filepath)
            print(f"  ✓ {asset}: 256×512 → 256×528")
        else:
            print(f"  ⚠️  {asset}: Already {img.size}, skipping")
    else:
        print(f"  ✗ {asset}: Not found")

print("\n✅ Done!")
