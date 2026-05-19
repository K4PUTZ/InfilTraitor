extends RefCounted
## Procedural room generator — M3 placeholder
##
## Inputs:
##   theme  : Dictionary  — tile selection per ASSET_MAP.md chapter themes
##   size   : Vector2i    — room dimensions in tiles
##   seed   : int         — RNG seed for reproducible generation
##
## Output:
##   Dictionary { "floor": Array[Vector2i], "structure": Array[tile_name, cell] }
##
## Algorithm (planned):
##   1. Fill interior with floor tiles
##   2. Place perimeter walls (block_N/S/E/W based on facing direction)
##   3. Cut entry/exit door openings
##   4. Scatter cover props (crates, walls) using weighted random placement
##   5. Place interactable elements (switches, ladders) per room objective
##   6. Validate: path must exist from each entry to each exit
