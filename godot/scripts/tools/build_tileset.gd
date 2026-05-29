extends SceneTree
## TileSet builder for INFILTRAITOR — blocks-prototype pack
##
## HOW TO RUN (terminal, from the project root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/build_tileset.gd
## NOTE: Open Godot editor once first so PNGs are imported into .godot/imported/
##
## OUTPUT:
##   godot/resources/tilesets/tileset_blocks.tres  ← used by TileMapLayer nodes
##   godot/scripts/world/tile_registry.gd          ← auto-generated name→id lookup

const TILES_PATH    := "res://ASSETS/ISOMETRIC/blocks-prototype/Isometric/"
const TILESET_OUT   := "res://godot/resources/tilesets/tileset_blocks.tres"
const REGISTRY_OUT  := "res://godot/scripts/world/tile_registry.gd"

## Tile cell dimensions (the isometric diamond base, 2:1 ratio)
const CELL_SIZE     := Vector2i(256, 128)
## Full PNG dimensions (diamond + 3D block height above)
const PNG_SIZE      := Vector2i(256, 512)
## Sprite Y-offset: shifts PNG up so bottom 128px (floor diamond) aligns with cell
## floor diamond occupies PNG rows 384–512 → shift up by 384px
const SPRITE_OFFSET := Vector2i(0, -384)
## Each wall sits on the OUTER edge of its boundary tile, straddling it with the
## adjacent outside tile. In diamond-down isometric (cell 256×128):
##   North outer edge (NE diagonal): half-step north  = screen (+64, -32)
##   South outer edge (SW diagonal): half-step south  = screen (-64, +32)
##   East  outer edge (SE diagonal): half-step east   = screen (+64, +32)
##   West  outer edge (NW diagonal): half-step west   = screen (-64, -32)
const EDGE_VISUAL_OFFSETS := {
	"N": Vector2i(64, -32),
	"S": Vector2i(-64, 32),
	"E": Vector2i(64, 32),
	"W": Vector2i(-64, -32),
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

	# ── Scan tile directory ───────────────────────────────────────────────────
	var dir := DirAccess.open(TILES_PATH)
	if dir == null:
		push_error("[build_tileset] Cannot open: " + TILES_PATH)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".png"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()  # deterministic source_id ordering

	# ── Register each tile ───────────────────────────────────────────────────
	var registry_entries: Array[String] = []
	var source_id := 0

	for file_name in files:
		var tile_name: String = file_name.get_basename()      # e.g. "floor_N"
		var texture: Texture2D = load(TILES_PATH + file_name)
		if texture == null:
			push_warning("[build_tileset] Cannot load: " + file_name)
			continue

		# Parse base name: strip last "_N" / "_S" / "_E" / "_W"
		var parts := tile_name.rsplit("_", true, 1)
		var base_name: String = parts[0] if parts.size() > 1 else tile_name
		var props: Dictionary = TILE_PROPS.get(base_name,
				{walkable=true, cover=false, interactive=false})

		# One TileSetAtlasSource per PNG (standalone tile, not an atlas)
		var source := TileSetAtlasSource.new()
		source.texture             = texture
		source.texture_region_size = PNG_SIZE

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


func _get_texture_origin(tile_name: String, base_name: String) -> Vector2i:
	var offset := SPRITE_OFFSET
	if not _is_edge_aligned_tile(base_name):
		return offset

	var parts := tile_name.rsplit("_", true, 1)
	if parts.size() < 2:
		return offset

	var direction := parts[1]
	if not EDGE_VISUAL_OFFSETS.has(direction):
		return offset

	return offset + EDGE_VISUAL_OFFSETS[direction]


func _is_edge_aligned_tile(base_name: String) -> bool:
	if base_name in EDGE_ALIGNED_EXCLUSIONS:
		return false
	for prefix in EDGE_ALIGNED_PREFIXES:
		if base_name.begins_with(prefix):
			return true
	return false
