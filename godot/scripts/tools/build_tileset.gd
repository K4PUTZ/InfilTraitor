extends SceneTree
## TileSet builder for INFILTRAITOR — single-source asset pipeline
##
## HOW TO RUN (terminal, from the project root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/build_tileset.gd
## NOTE: Open Godot editor once first so PNGs are imported into .godot/imported/
##
## OUTPUT:
##   godot/resources/tilesets/tileset_blocks.tres  ← used by TileMapLayer nodes
##   godot/scripts/world/tile_registry.gd          ← auto-generated name→id lookup

## Single source of truth: recursive scan of this folder finds ALL asset PNGs
const SOURCE_PATH   := "res://ASSETS/ISOMETRIC/source_assets/"
const TILESET_OUT   := "res://godot/resources/tilesets/tileset_blocks.tres"
const REGISTRY_OUT  := "res://godot/scripts/world/tile_registry.gd"

## Tile cell dimensions (the isometric diamond base, 2:1 ratio)
const CELL_SIZE     := Vector2i(256, 128)
## Full PNG dimensions (diamond + 3D block height above)
const PNG_SIZE      := Vector2i(256, 512)
## Sprite Y-offset: shifts PNG up so bottom 128px (floor diamond) aligns with cell
## floor diamond occupies PNG rows 384–512 → shift up by 384px
const SPRITE_OFFSET := Vector2i(0, -384)
## ── EDGE-STRADDLING SYSTEM ───────────────────────────────────────────────────
## INFILTRAITOR blocks movement at EDGES between tiles, not at full tiles.
## Walls are placed on the boundary between two adjacent tiles — half the visual
## thickness sits in each tile. This is a permanent engine design decision.
##
## The master wall assets (master_assets/walls/) encode this positioning: each
## PNG has its wall face authored near the tile edge rather than at canvas
## centre. The texture_origin values below are the CALIBRATED offsets that shift
## each sprite into the correct straddle position for its direction.
##
## ── WALL FACE OFFSETS (wall / wallHalf) ──────────────────────────────────────
## Assets NE/NW/SE/SW are authored with the face near (but not exactly at) the
## tile edge. A small directional nudge (±16 px X, ±8 px Y — 1/8 cell step)
## moves the face to straddle the boundary evenly.
##
## ── CORNER OFFSETS (wallCorner / wallCornerHalf) ──────────────────────────────
## Corner point coincides with a grid vertex shared by two wall faces. Because
## both adjacent wall faces were shifted outward to straddle their edges, there
## is a gap at the vertex. The corner sprites were extended to fill this gap:
##   NW / SE corners → canvas widened to 320 px (extra 64 px on the right, since
##                      Godot expands canvas to the right by default)
##   NE / SW corners → canvas heightened to 528 px (extra 16 px at the bottom)
## The texture_origin values below compensate for that asymmetric expansion so
## the corner visually meets both adjacent wall faces exactly.
##
## Changing these values without updating the master PNG geometry will break
## visual alignment. Calibrated in commit 924dbf0.
## ─────────────────────────────────────────────────────────────────────────────
const EDGE_VISUAL_OFFSETS := {
	"N": Vector2i(64, -32),
	"S": Vector2i(-64, 32),
	"E": Vector2i(64, 32),
	"W": Vector2i(-64, -32),
	## Diagonal wall faces (NE/NW/SE/SW): straddle the boundary at half a
	## diamond-step. Values calibrated in commit 924dbf0.
	"NE": Vector2i(-16, -8),
	"NW": Vector2i(-16,  8),
	"SE": Vector2i( 16, -8),
	"SW": Vector2i( 16,  8),
}

## wallCorner / wallCornerHalf need a distinct per-direction shift because
## their geometry spans the full corner vertex, not just one edge face.
## Values calibrated in commit 924dbf0.
const CORNER_VISUAL_OFFSETS := {
	"NE": Vector2i(-32, -8),
	"NW": Vector2i(  0, 16),
	"SE": Vector2i(  0,-16),
	"SW": Vector2i( 32, -8),
}

## Tile properties keyed by base name (without _N/_S/_E/_W suffix).
## walkable   → agent/guard can move onto this tile
## cover      → provides tactical cover (blocks line-of-sight at hip height)
## interactive → can be triggered by the agent (doors, switches, ladders)
const TILE_PROPS: Dictionary = {
	# Floor
	"floor":                  {walkable=true,  cover=false, interactive=false},
	"floorHalf":              {walkable=true,  cover=false, interactive=false},
	"floorQuarter":           {walkable=true,  cover=false, interactive=false},
	# Solid blocks
	"block":                  {walkable=false, cover=true,  interactive=false},
	"blockHalf":              {walkable=false, cover=true,  interactive=false},
	"blockAngle":             {walkable=false, cover=true,  interactive=false},
	"blockQuarter":           {walkable=false, cover=true,  interactive=false},
	# Walls
	"wall":                   {walkable=false, cover=true,  interactive=false},
	"wallHalf":               {walkable=false, cover=true,  interactive=false},
	"wallCorner":             {walkable=false, cover=true,  interactive=false},
	"wallCornerHalf":         {walkable=false, cover=true,  interactive=false},
	"wallCurve":              {walkable=false, cover=true,  interactive=false},
	"wallCurveHalf":          {walkable=false, cover=true,  interactive=false},
	"wallBattlement":         {walkable=false, cover=true,  interactive=false},
	# Windows
	"window":                 {walkable=false, cover=false, interactive=false},
	"windowLeft":             {walkable=false, cover=false, interactive=false},
	"windowMiddle":           {walkable=false, cover=false, interactive=false},
	"windowRight":            {walkable=false, cover=false, interactive=false},
	# Doors / passages
	"doorClosed":             {walkable=false, cover=false, interactive=true},
	"doorOpen":               {walkable=true,  cover=false, interactive=true},
	"doorway":                {walkable=true,  cover=false, interactive=false},
	"doorwayBottom":          {walkable=true,  cover=false, interactive=false},
	"doorwayCenter":          {walkable=true,  cover=false, interactive=false},
	"doorwayLeft":            {walkable=true,  cover=false, interactive=false},
	"doorwayLeftBottom":      {walkable=true,  cover=false, interactive=false},
	"doorwayMiddle":          {walkable=true,  cover=false, interactive=false},
	"doorwayMiddleBottom":    {walkable=true,  cover=false, interactive=false},
	"doorwayRight":           {walkable=true,  cover=false, interactive=false},
	"doorwayRightBottom":     {walkable=true,  cover=false, interactive=false},
	# Cover props
	"crate":                  {walkable=false, cover=true,  interactive=true},
	# Structural details
	"column":                 {walkable=false, cover=false, interactive=false},
	"columnBlocks":           {walkable=false, cover=false, interactive=false},
	"columnCorner":           {walkable=false, cover=false, interactive=false},
	"pole":                   {walkable=false, cover=false, interactive=false},
	"poleGroup":              {walkable=false, cover=false, interactive=false},
	"fence":                  {walkable=false, cover=false, interactive=false},
	# Slopes / ramps
	"slope":                  {walkable=true,  cover=false, interactive=false},
	"slopeHalf":              {walkable=true,  cover=false, interactive=false},
	"slopeQuarter":           {walkable=true,  cover=false, interactive=false},
	"slopeSmall":             {walkable=true,  cover=false, interactive=false},
	"sloperCornerInner":      {walkable=true,  cover=false, interactive=false},
	"sloperCornerOuter":      {walkable=true,  cover=false, interactive=false},
	# Stairs
	"stairs":                 {walkable=true,  cover=false, interactive=false},
	"stairsCornerInner":      {walkable=true,  cover=false, interactive=false},
	"stairsCornerOuter":      {walkable=true,  cover=false, interactive=false},
	"stairsOpen":             {walkable=true,  cover=false, interactive=false},
	"stairsOpenCornerInner":  {walkable=true,  cover=false, interactive=false},
	"stairsOpenCornerOuter":  {walkable=true,  cover=false, interactive=false},
	"steps":                  {walkable=true,  cover=false, interactive=false},
	"ladder":                 {walkable=true,  cover=false, interactive=true},
	# Slabs / platforms
	"slab":                   {walkable=true,  cover=false, interactive=false},
	"slabHalf":               {walkable=true,  cover=false, interactive=false},
	"slabAngle":              {walkable=true,  cover=false, interactive=false},
	"slabQuarter":            {walkable=true,  cover=false, interactive=false},
	# Switches / triggers
	"switchFloorOff":         {walkable=true,  cover=false, interactive=true},
	"switchFloorOn":          {walkable=true,  cover=false, interactive=true},
	"switchWallOff":          {walkable=false, cover=false, interactive=true},
	"switchWallOn":           {walkable=false, cover=false, interactive=true},
	# Direction markers
	"arrow":                  {walkable=true,  cover=false, interactive=false},
	"arrowWall":              {walkable=false, cover=false, interactive=false},
}

## Base names whose sprites need a half-step shift to sit on the outer edge.
## Simple "wall" includes wallHalf but NOT the compound variants below.
const EDGE_ALIGNED_PREFIXES := [
	"arrowWall",
	"door",
	"fence",
	"switchWall",
	"wall",
	"window",
]

## These base names start with a prefix above but must NOT receive an edge
## offset — their corner / curve geometry is already at the correct vertex.
const EDGE_ALIGNED_EXCLUSIONS := [
	"wallCorner",
	"wallCornerHalf",
	"wallCurve",
	"wallCurveHalf",
	"wallBattlement",
]


func _initialize() -> void:
	_build()
	quit()


func _build() -> void:
	print("[build_tileset] Starting...")

	# ── Create TileSet ────────────────────────────────────────────────────────
	var tile_set := TileSet.new()
	tile_set.tile_shape  = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size   = CELL_SIZE

	# Custom data layers (index order is fixed — do not reorder)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "tile_name")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "walkable")
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(2, "cover")
	tile_set.set_custom_data_layer_type(2, TYPE_BOOL)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(3, "interactive")
	tile_set.set_custom_data_layer_type(3, TYPE_BOOL)

	# ── Scan SOURCE_PATH recursively for all PNGs ─────────────────────────────
	var all_pngs: Array[String] = []
	_scan_source_recursive(SOURCE_PATH, all_pngs)
	all_pngs.sort()  # deterministic source_id ordering

	if all_pngs.is_empty():
		push_error("[build_tileset] No PNGs found in: " + SOURCE_PATH)
		return
	print("[build_tileset] Found %d PNG(s) in %s" % [all_pngs.size(), SOURCE_PATH])

	# ── Register each tile ───────────────────────────────────────────────────
	var registry_entries: Array[String] = []
	var source_id := 0

	for png_path in all_pngs:
		var tile_name: String = png_path.get_basename().get_file()  # e.g. "wallFace_NW"

		# Parse base name: strip last "_N" / "_S" / "_E" / "_W"
		var parts := tile_name.rsplit("_", true, 1)
		var base_name: String = parts[0] if parts.size() > 1 else tile_name

		# Load texture from SOURCE_PATH (single source of truth, no fallback)
		var texture: Texture2D = load(png_path)
		if texture == null:
			push_warning("[build_tileset] Cannot load: " + png_path)
			continue

		var props: Dictionary = TILE_PROPS.get(base_name,
				{walkable=true, cover=false, interactive=false})

		# One TileSetAtlasSource per PNG (standalone tile, not an atlas)
		var source := TileSetAtlasSource.new()
		source.texture             = texture
		# Use the actual PNG dimensions so non-standard canvases (wallCorner/
		# wallCornerHalf: 320×512 or 256×528) are registered correctly.
		source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())

		source.create_tile(Vector2i(0, 0))

		# Add to TileSet FIRST so TileData gets the tile_set reference —
		# set_custom_data() requires it.
		tile_set.add_source(source, source_id)

		var td: TileData = source.get_tile_data(Vector2i(0, 0), 0)

		# Align floor plane with TileMap cell.
		# SPRITE_OFFSET shifts the 512px-tall sprite UP so its bottom 128px
		# (the isometric floor diamond) sits exactly at the cell boundary.
		# Adjust this constant if tiles appear too high or low in the editor.
		td.texture_origin = _get_texture_origin(tile_name, base_name)

		td.set_custom_data("tile_name",   tile_name)
		td.set_custom_data("walkable",    props.get("walkable",    true))
		td.set_custom_data("cover",       props.get("cover",       false))
		td.set_custom_data("interactive", props.get("interactive", false))

		registry_entries.append('\t"%s": %d,' % [tile_name, source_id])
		source_id += 1

	# ── Save TileSet resource ─────────────────────────────────────────────────
	var err := ResourceSaver.save(tile_set, TILESET_OUT)
	if err != OK:
		push_error("[build_tileset] Failed to save TileSet: " + str(err))
		return
	print("[build_tileset] Saved TileSet → %s  (%d tiles)" % [TILESET_OUT, source_id])

	# ── Save TileRegistry script ──────────────────────────────────────────────
	var lines: PackedStringArray = [
		"# AUTO-GENERATED by godot/scripts/tools/build_tileset.gd",
		"# Re-run the builder whenever tiles are added or renamed.",
		"# Maps tile_name strings to TileSet source_ids.",
		"class_name TileRegistry",
		"extends RefCounted",
		"",
		"const TILES: Dictionary = {",
	]
	for entry in registry_entries:
		lines.append(entry)
	lines.append("}")
	lines.append("")

	var fa := FileAccess.open(REGISTRY_OUT, FileAccess.WRITE)
	if fa == null:
		push_error("[build_tileset] Cannot write registry: " + REGISTRY_OUT)
		return
	fa.store_string("\n".join(lines))
	fa.close()
	print("[build_tileset] Saved registry → " + REGISTRY_OUT)
	print("[build_tileset] Done.")


## Recursively scan SOURCE_PATH (and its subfolders) for all PNG files.
## Returns array of full resource paths sorted alphabetically.
## Example: ["res://ASSETS/ISOMETRIC/source_assets/generated/wallFace_NW.png", ...]
func _scan_source_recursive(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var full := path + f
		if dir.current_is_dir():
			_scan_source_recursive(full + "/", out)    # recurse into subfolders
		elif f.ends_with(".png"):
			out.append(full)
		f = dir.get_next()
	dir.list_dir_end()


func _get_texture_origin(tile_name: String, base_name: String) -> Vector2i:
	var parts := tile_name.rsplit("_", true, 1)
	var direction := parts[1] if parts.size() > 1 else ""

	if base_name in ["wallCorner", "wallCornerHalf"]:
		return SPRITE_OFFSET + CORNER_VISUAL_OFFSETS.get(direction, Vector2i.ZERO)

	if not _is_edge_aligned_tile(base_name):
		return SPRITE_OFFSET

	return SPRITE_OFFSET + EDGE_VISUAL_OFFSETS.get(direction, Vector2i.ZERO)


func _is_edge_aligned_tile(base_name: String) -> bool:
	if base_name in EDGE_ALIGNED_EXCLUSIONS:
		return false
	for prefix in EDGE_ALIGNED_PREFIXES:
		if base_name.begins_with(prefix):
			return true
	return false
