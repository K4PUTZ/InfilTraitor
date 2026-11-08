DAMAGE DECALS — authoring drop point
====================================

Canvas: 256 x 256 px, SQUARE, RGBA with real alpha.
Paint the mark; leave everything else transparent.

Do NOT pre-stretch anything to compensate for the isometric view. The
generator applies the x20/16 vertical stretch (lateral faces) and the shear.
A circle drawn here comes out as a physically round mark on the wall.

TEMPLATE_decal_256x256.png is a blank canvas with a magenta guide frame.
The frame is a guide only — it is never read by the generator.

Files here are NEVER overwritten once they exist. Replace any
decal_<family>_<material>_<n>.png with your art, then run:

    python3 tools/asset_generation/generate_voxel.py

...and every composite in the parent folder is rebuilt around it.

Full specification: ASSETS/ART_SPECIFICATIONS.md section 7.
