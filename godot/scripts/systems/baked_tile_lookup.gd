## BakedTileLookup — Single lookup seam for placement path (BAKE-FIX-02: run-aware)
##
## Insertion point between placement code and tile source selection.
## Query for a voxel face → either baked atlas or generic material atlas.
## BAKE-FIX-02: Walks master-strip dictionary with mirroring for boundary cases.
## Features a fallback chain: baked → generic material atlas.

class_name BakedTileLookup

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N
const VOXEL_ATOM_W: int = GeometryCoordsClass.VOXEL_ATOM_W  # 32
const VOXEL_ATOM_H: int = GeometryCoordsClass.VOXEL_ATOM_H  # 36
const STRIP_LENGTH: int = 9  # Master-strip atom count [TILE_ANATOMY.md §4]
const PAGE_WIDTH: int = 4096  # Physical page width in pixels
const TILES_PER_PAGE_X: int = 128  # PAGE_WIDTH / VOXEL_ATOM_W (4096 / 32)

# For testing: can inject a mock BakeConfig
var _bake_config = null
var _bake_config_ref = null  # Cache BakeConfig class reference

# BAKE-FIX-02: Run information (edge_id -> run) for strip walking
var _edge_run_map: Dictionary = {}  # edge.id -> {"edges": [], "min_edge": Edge, ...}

# BAKE-LIVE-VERIFY-01-b: Instance storage for baked atlas and source ID mapping
# Populated by room_builder; takes precedence over Engine.get_meta() fallback
var _baked_atlas = null
var _source_ids: Dictionary = {}  # page_idx -> source_id_int

# BAKE-DIAG-01: throttled miss logging (avoid spamming console per-voxel)
var _diag_miss_count: int = 0
var _diag_miss_log_limit: int = 5

## Result of a tile lookup query
class TileLookupResult:
	var source_id_int: int       # Integer tileset source id (for set_cell)
	var source_id: String        # String identifier (for debugging; deprecated)
	var atlas_coords: Vector2i   # (col, row) within that source
	var alternative_id: int      # For future use (always 0 for now)

	func _init(p_source_id_int: int, p_source_id: String, p_atlas_coords: Vector2i, p_alternative_id: int = 0) -> void:
		source_id_int = p_source_id_int
		source_id = p_source_id
		atlas_coords = p_atlas_coords
		alternative_id = p_alternative_id


## Set mock config for testing (optional)
func set_test_config(config) -> void:
	_bake_config = config


## Set baked atlas for testing or injection
## Stores as instance field (production path via room_builder).
## FIX-SHUTDOWN-CRASH-01/01b: deliberately does NOT also write
## Engine.set_meta("GLOBAL_BAKED_ATLAS", ...) — that pattern stores a
## GDScript RefCounted instance in a table that survives past
## ScriptServer::finish_languages(), aborting (SIGABRT/exit 134) when the
## instance is torn down during Main::cleanup(). _get_baked_atlas() already
## checks this instance field first, so the meta write was pure dead-weight
## risk with no reader that needed it.
func set_baked_atlas(atlas) -> void:
	if atlas != null:
		_baked_atlas = atlas


## Set source ID mapping for baked atlas pages
## BAKE-LIVE-VERIFY-01-b: Room_builder populates this before rendering
func set_source_ids(source_ids: Dictionary) -> void:
	if source_ids != null:
		_source_ids = source_ids


## BAKE-FIX-02: Register run information for later lookup during placement
## Called by room_builder after grouping edges into runs
func register_runs(runs: Array) -> void:
	_edge_run_map.clear()
	for run in runs:
		var edges = run.get("edges", [])
		for edge in edges:
			_edge_run_map[edge.id] = run


## Main resolve function: placement calls this once per set_cell()
## BAKE-FACADE-PLANE-01: Now 2-D — accepts level and column_in_run for sheet addressing
func resolve(edge, face: int, voxel_xy: Vector2i, level: int = 0, column_in_run: int = -1) -> TileLookupResult:
	# If baking is disabled, always use generic material atlas
	var baking_enabled = false
	if _bake_config:
		baking_enabled = _bake_config.is_enabled() if _bake_config.has_method("is_enabled") else _bake_config.enabled
	else:
		# Use global BakeConfig (cache the class reference)
		if _bake_config_ref == null:
			_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
		baking_enabled = _bake_config_ref.enabled if _bake_config_ref else false

	if not baking_enabled:
		return _resolve_generic(edge, face, voxel_xy)

	# If column_in_run not provided, compute it from edge and voxel_xy
	if column_in_run < 0:
		column_in_run = _compute_column_in_run(edge, voxel_xy)

	# BAKE-FACADE-PLANE-01: Try 2-D baked lookup with level and column_in_run
	var baked_result = _resolve_baked_sheet(edge, face, voxel_xy, level, column_in_run)
	if baked_result != null:
		return baked_result

	# Fallback to generic
	return _resolve_generic(edge, face, voxel_xy)


## Mirror an integer index into [0, period) using mirrored-repeat addressing
## This matches FacadeSampler._mirror_1d() for consistent wrapping
## Mirrored-repeat: period is 2*S, fold back at S boundary
func _mirror_index_1d(index: int, period: int) -> int:
	var period_2x = period * 2
	var k2 = index % period_2x
	
	# Handle negative modulo results
	if k2 < 0:
		k2 += period_2x
	
	# Reflect if in the second half of the period
	if k2 >= period:
		k2 = period_2x - k2 - 1
	
	return k2


## Detect the run axis by examining min/max coordinates of the run
## Returns 0 if X-axis run (SE), 1 if Y-axis run (SW)
func _detect_run_axis(run: Dictionary) -> int:
	var edges = run.get("edges", [])
	if edges.size() == 0:
		return 0  # Default to X
	
	var min_x = 2147483647  # INT32_MAX
	var max_x = -2147483648  # INT32_MIN
	var min_y = 2147483647
	var max_y = -2147483648
	
	for edge in edges:
		# Edges have start and end positions in grid coords
		# Try common property names
		var pos_start = edge.get("pos_start", null) if typeof(edge) == TYPE_DICTIONARY else null
		var pos_end = edge.get("pos_end", null) if typeof(edge) == TYPE_DICTIONARY else null
		
		# Fallback: try to use pos as Vector2i
		if pos_start == null and "pos" in edge:
			pos_start = edge.pos if typeof(edge.pos) == TYPE_VECTOR2I else Vector2i(edge.pos)
		if pos_end == null and "pos" in edge:
			pos_end = edge.pos if typeof(edge.pos) == TYPE_VECTOR2I else Vector2i(edge.pos)
		
		if pos_start and typeof(pos_start) == TYPE_VECTOR2I:
			min_x = mini(min_x, pos_start.x)
			max_x = maxi(max_x, pos_start.x)
			min_y = mini(min_y, pos_start.y)
			max_y = maxi(max_y, pos_start.y)
		
		if pos_end and typeof(pos_end) == TYPE_VECTOR2I:
			min_x = mini(min_x, pos_end.x)
			max_x = maxi(max_x, pos_end.x)
			min_y = mini(min_y, pos_end.y)
			max_y = maxi(max_y, pos_end.y)
	
	# Run along X if X range > Y range, else Y
	var x_range = max_x - min_x
	var y_range = max_y - min_y
	
	return 1 if y_range > x_range else 0


## Compute column_in_run from edge and voxel position, detecting run axis
## column_in_run = position_in_run * 8 + voxel_offset (8 voxels per GU)
## Detects whether run goes along X (SE edge) or Y (SW edge) and picks correct voxel component
func _compute_column_in_run(edge, voxel_xy: Vector2i) -> int:
	var run = _edge_run_map.get(edge.id, null)
	if run == null:
		return -1  # Edge not in any run

	var position_in_run = _get_edge_position_in_run(edge, run)
	if position_in_run < 0:
		return -1

	# Detect run axis: 0 = X-axis (SE edges), 1 = Y-axis (SW edges)
	var run_axis = _detect_run_axis(run)
	
	# BAKE-FACADE-PLANE-01-b: Pick voxel component matching run axis
	var voxel_offset_along_run = voxel_xy.y if run_axis == 1 else voxel_xy.x
	return position_in_run * 8 + voxel_offset_along_run


## Compute facade sheet key for 2-D addressing with mirrored-repeat wrapping
func _compute_facade_key(material_id: String, facade_id: String, column_in_run: int, level: int) -> String:
	# BAKE-FACADE-PLANE-01-b: Use mirrored indexing (matching FacadeSampler._mirror_1d)
	var sheet_col = _mirror_index_1d(column_in_run, 64)
	var sheet_row = _mirror_index_1d(level, 32)
	return "%s|%s|%d|%d" % [material_id, facade_id, sheet_col, sheet_row]


## BAKE-DIAG-01: is verbose diagnostic logging enabled (reads BakeConfig.debug_bake_set_dump)
func _debug_enabled() -> bool:
	if _bake_config_ref == null:
		_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
	return _bake_config_ref != null and _bake_config_ref.debug_bake_set_dump


## BAKE-FACADE-PLANE-01: Resolve using 2-D baked atom sheet
## Returns null if baked atlas not available; caller will use fallback
func _resolve_baked_sheet(edge, _face: int, _voxel_xy: Vector2i, level: int, column_in_run: int) -> TileLookupResult:
	# Get the baked atlas and lookup dictionary
	var baked_atlas = _get_baked_atlas()
	if baked_atlas == null:
		if _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
			_diag_miss_count += 1
			print("[BAKE-DIAG] lookup MISS reason=NO_BAKED_ATLAS (edge=%s)" % [edge])
		return null

	var lookup_dict = baked_atlas.get("lookup", {}) if baked_atlas is Dictionary else baked_atlas.lookup
	if lookup_dict.is_empty():
		if _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
			_diag_miss_count += 1
			print("[BAKE-DIAG] lookup MISS reason=EMPTY_LOOKUP_DICT (edge=%s)" % [edge])
		return null

	# Get material and facade for this edge
	var material_id = "default"
	if edge.has_method("get_material_id"):
		material_id = edge.get_material_id()
	elif "material" in edge:
		material_id = edge.material

	var facade_id = BakePolicyClass.facade_for_material(material_id)

	# Validate column_in_run
	if column_in_run < 0:
		if _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
			_diag_miss_count += 1
			print("[BAKE-DIAG] lookup MISS reason=INVALID_COLUMN_IN_RUN (column=%d)" % column_in_run)
		return null

	# BAKE-FACADE-PLANE-01: Compute 2-D sheet address from column_in_run and level
	var lookup_key = _compute_facade_key(material_id, facade_id, column_in_run, level)

	if lookup_dict.has(lookup_key):
		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)

		if page_idx >= 0:
			var source_id = _get_baked_atlas_source_id(page_idx)
			if source_id >= 0:
				return TileLookupResult.new(source_id, "BAKED_ATLAS_%d" % page_idx, atlas_coords, 0)
			elif _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
				_diag_miss_count += 1
				print("[BAKE-DIAG] lookup MISS reason=NO_SOURCE_ID_FOR_PAGE (page_idx=%d, key=%s)" % [page_idx, lookup_key])
	elif _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
		_diag_miss_count += 1
		var sample_keys: Array = lookup_dict.keys()
		sample_keys = sample_keys.slice(0, mini(3, sample_keys.size()))
		print("[BAKE-DIAG] lookup MISS reason=KEY_NOT_IN_DICT (key=%s, col_in_run=%d, level=%d, dict_size=%d, sample_keys=%s)" % [
			lookup_key, column_in_run, level, lookup_dict.size(), sample_keys
		])

	return null


## Get the position of an edge within its run (0 = first edge, 1 = second, etc.)
func _get_edge_position_in_run(edge, run: Dictionary) -> int:
	var edges = run.get("edges", [])
	for i in range(edges.size()):
		if edges[i].id == edge.id:
			return i
	return -1


## Fallback: resolve using generic material atlas
func _resolve_generic(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	var material_id = "default"

	if edge.has_method("get_material_id"):
		material_id = edge.get_material_id()
	elif "material" in edge:
		material_id = edge.material

	# Seed variant by voxel position
	var seed_str = str(edge.key_string() if edge.has_method("key_string") else edge) + "_" + material_id + "_" + str(voxel_xy.x) + "_" + str(voxel_xy.y)
	var seed_val = hash(seed_str)
	var variant_k = abs(seed_val) % 4

	# Lookup in GLOBAL_MATERIAL_ATLAS
	var material_atlas = _get_material_atlas()
	if material_atlas:
		var atlas_coords = material_atlas.get_coords(material_id, face, variant_k)
		return TileLookupResult.new(
			material_atlas.source_id_int if material_atlas.has("source_id_int") else 0,
			material_atlas.source_id if material_atlas.has("source_id") else "MATERIAL_SOURCE",
			atlas_coords,
			0
		)

	# Fallback: return material index 0
	return TileLookupResult.new(
		0,
		"MATERIAL_ATLAS",
		Vector2i(0, 0),
		0
	)


## Get baked atlas source id (int) for a given page
func _get_baked_atlas_source_id(page_idx: int) -> int:
	# BAKE-LIVE-VERIFY-01-b: Check instance field first (production path)
	if _source_ids.has(page_idx):
		return _source_ids[page_idx]
	
	# Fallback to legacy Engine.get_meta for test/production compatibility
	if Engine.has_meta("BAKED_ATLAS_SOURCE_IDS"):
		var test_source_ids = Engine.get_meta("BAKED_ATLAS_SOURCE_IDS")
		return test_source_ids.get(page_idx, -1)
	
	return -1


## Get global baked atlas (if populated)
func _get_baked_atlas():
	# BAKE-LIVE-VERIFY-01-b: Check instance field first (production path)
	if _baked_atlas != null:
		return _baked_atlas
	
	# Check legacy Engine.get_meta for test/production compatibility
	if Engine.has_meta("GLOBAL_BAKED_ATLAS"):
		return Engine.get_meta("GLOBAL_BAKED_ATLAS")
	
	return null


## Get global material atlas
func _get_material_atlas():
	if Engine.has_meta("GLOBAL_MATERIAL_ATLAS"):
		return Engine.get_meta("GLOBAL_MATERIAL_ATLAS")
	return null
