extends SceneTree
## TileSet builder for VOXELS in INFILTRAITOR
##
## HOW TO RUN:
##   Godot --headless --path . --script godot/scripts/tools/build_voxel_tileset.gd

const SOURCE_PATH := "res://ASSETS/ISOMETRIC/source_assets/voxels/"
const TILESET_OUT := "res://godot/resources/tilesets/tileset_voxels.tres"

func _init() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 16)
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN

	# Scan for voxel PNGs
	var dir := DirAccess.open(SOURCE_PATH)
	if dir == null:
		push_error("[build_voxel_tileset] No folder found: " + SOURCE_PATH)
		quit(1)
		return

	var all_pngs: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".png"):
			all_pngs.append(SOURCE_PATH + f)
		f = dir.get_next()
	dir.list_dir_end()
	all_pngs.sort()

	if all_pngs.is_empty():
		push_error("[build_voxel_tileset] No PNGs found in: " + SOURCE_PATH)
		quit(1)
		return

	print("[build_voxel_tileset] Found %d voxel PNG(s)" % all_pngs.size())
	var source_id := 0

	for png_path in all_pngs:
		var tile_name: String = png_path.get_basename().get_file()
		var texture: Texture2D = load(png_path)
		if texture == null:
			push_warning("[build_voxel_tileset] Cannot load: " + png_path)
			continue

		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		source.create_tile(Vector2i(0, 0))

		tile_set.add_source(source, source_id)

		var td: TileData = source.get_tile_data(Vector2i(0, 0), 0)
		td.texture_origin = Vector2i(0, 0)
		td.y_sort_origin = 8

		# Store naming meta for ease of debug mapping if needed
		td.set_custom_data_layer_by_name(tile_name, null) # Optional / just for debug
		print("  Voxel %s -> source_id %d" % [tile_name, source_id])
		source_id += 1

	var dir_res := DirAccess.open("res://godot/resources/tilesets")
	if dir_res == null:
		DirAccess.make_dir_recursive_absolute("res://godot/resources/tilesets")

	var err := ResourceSaver.save(tile_set, TILESET_OUT)
	if err != OK:
		push_error("[build_voxel_tileset] Failed to save TileSet: " + str(err))
		quit(1)
		return

	print("[build_voxel_tileset] Saved Voxel TileSet -> %s (%d tiles)" % [TILESET_OUT, source_id])
	quit(0)
