## BakedTileLookup — Single lookup seam for placement path
##
## Insertion point between placement code and tile source selection.
## Query for a voxel face → either baked atlas or generic material atlas.
## OVERLORD-FIX-01: addresses per-direction continuous-plane sheets via
## (material, facade, column_in_run, level, dir) keys, with mirrored-repeat
## wrapping. Fallback chain: baked → generic material atlas.

class_name BakedTileLookup

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
# (facade_sampler/bake_compositor preloads removed in OVERLORD-FIX-01 — the
# lookup no longer samples or bakes; it only addresses per-direction sheets)
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

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
# OVERLORD-FIX-01: throttled HIT logging (placement continuity probe)
var _diag_hit_log_count: int = 0

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
## BAKE-FACADE-PLANE-02-c: MATERIAL_ONLY mode short-circuits to generic (no baking)
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
	
	# BAKE-FACADE-PLANE-02-c: MATERIAL_ONLY mode short-circuits to generic material atlas
	# (MATERIAL_ONLY ignores facade by definition, so no baking needed)
	var is_material_only = false
	if _bake_config:
		is_material_only = (_bake_config.blend_mode == _bake_config.BlendMode.MATERIAL_ONLY) if ("blend_mode" in _bake_config) else false
	else:
		if _bake_config_ref == null:
			_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
		is_material_only = (_bake_config_ref.blend_mode == _bake_config_ref.BlendMode.MATERIAL_ONLY) if _bake_config_ref else false

	if not baking_enabled or is_material_only:
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


## Detect the run axis from the wall's intrinsic face orientation.
## Edge.face_a is always SE or SW (extractor canon): an SE face borders the
## +X neighbor, so an SE wall surface RUNS along Y (axis 1); an SW face
## borders +Y, so an SW wall surface runs along X (axis 0). No positional
## heuristics — the previous min/max probe read fields Edge doesn't have and
## silently returned axis 0 for everything (OVERLORD-FIX-01).
func _detect_run_axis(run: Dictionary) -> int:
	var edges = run.get("edges", [])
	if edges.is_empty():
		return 0
	var first = edges[0]
	if "face_a" in first:
		return 1 if first.face_a == Face.SE else 0
	return 0

## Map run axis to bake direction (which pre-sheared plane the sheet used).
## dir 0 = plane descends screen-right (X-axis/SW-face runs, view N);
## dir 1 = mirrored plane, descends screen-left (Y-axis/SE-face runs).
## If the marker probe ever shows both directions swapped, flip ONLY this.
func _dir_for_axis(axis: int) -> int:
	return axis


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


## Compute facade sheet key for 3-D addressing (col, row, direction) with
## mirrored-repeat wrapping. OVERLORD-FIX-01: direction is part of the baked
## key — the compositor bakes one sheet per direction with the mirroring and
## shear already in the pixels; no key-side column flipping (the previous
## flip hack never executed anyway: it probed `edge.has_method("id")`, but
## `id` is a property, so the run was never found).
func _compute_facade_key(material_id: String, facade_id: String, column_in_run: int, level: int, dir: int) -> String:
	var sheet_col = _mirror_index_1d(column_in_run, 64)
	var sheet_row = _mirror_index_1d(level, 32)
	return "%s|%s|%d|%d|%d" % [material_id, facade_id, sheet_col, sheet_row, dir]


## BAKE-DIAG-01: is verbose diagnostic logging enabled (reads BakeConfig.debug_bake_set_dump)
func _debug_enabled() -> bool:
	if _bake_config_ref == null:
		_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
	return _bake_config_ref != null and _bake_config_ref.debug_bake_set_dump


## BAKE-FACADE-PLANE-01: Resolve using 2-D baked atom sheet
## BAKE-FACADE-PLANE-02-b: Pass edge to compute_facade_key for run-axis detection (second-direction fix)
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

	# OVERLORD-FIX-01: sheet address = (col, row, direction); direction comes
	# from the run's face orientation and selects the per-direction sheet
	var run = _edge_run_map.get(edge.id, null)
	var dir: int = _dir_for_axis(_detect_run_axis(run)) if run != null else 0
	var lookup_key = _compute_facade_key(material_id, facade_id, column_in_run, level, dir)

	if lookup_dict.has(lookup_key):
		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)

		if page_idx >= 0:
			var source_id = _get_baked_atlas_source_id(page_idx)
			if source_id >= 0:
				if _debug_enabled() and level == 0 and _diag_hit_log_count < 96:
					_diag_hit_log_count += 1
					print("[BAKE-DIAG] HIT edge=%s dir=%d col=%d level=%d key=%s coords=%s" % [
						edge.id, dir, column_in_run, level, lookup_key, atlas_coords
					])
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


## ROOF-BAKE-01/02c: resolve a HORIZONTAL surface voxel (roof/ceiling slab).
## The compositor's roof page family projects the facade flat 1:1 (isotropic,
## unlike the wall sheets' ×20/16 vertical pre-scale): the screen offset
## between two horizontally adjacent roof voxels (±16, +8) equals the
## crop-window offset in the roof plane exactly, so the top surface is
## seam-continuous by construction. local_pos is the STRUCTURE-LOCAL offset
## (voxel − Slab.texture_anchor, 02c): anchoring per connected roofed
## component kills world-line mirror seams and keeps the pattern glued to
## the structure across view rotations. Mirrored-repeat fold: x → col and
## y → row, BOTH period 64 (ROOF-SIDE-03 — the atom's SE half consumes y
## as a dir-1 run position). Returns null on any miss — caller
## falls back to the generic material atlas, same contract as resolve().
func resolve_flat(material_id: String, local_pos: Vector2i) -> TileLookupResult:
	# Same enable/MATERIAL_ONLY gates as resolve()
	var baking_enabled = false
	if _bake_config:
		baking_enabled = _bake_config.is_enabled() if _bake_config.has_method("is_enabled") else _bake_config.enabled
	else:
		if _bake_config_ref == null:
			_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
		baking_enabled = _bake_config_ref.enabled if _bake_config_ref else false
	var is_material_only = false
	if _bake_config:
		is_material_only = (_bake_config.blend_mode == _bake_config.BlendMode.MATERIAL_ONLY) if ("blend_mode" in _bake_config) else false
	else:
		if _bake_config_ref == null:
			_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
		is_material_only = (_bake_config_ref.blend_mode == _bake_config_ref.BlendMode.MATERIAL_ONLY) if _bake_config_ref else false
	if not baking_enabled or is_material_only:
		return null

	var facade_id = BakePolicyClass.facade_for_material(material_id)
	if facade_id == "":
		return null

	var baked_atlas = _get_baked_atlas()
	if baked_atlas == null:
		return null
	var lookup_dict = baked_atlas.get("lookup", {}) if baked_atlas is Dictionary else baked_atlas.lookup
	# ROOF-BAKE-02c: dedicated roof page family, no direction component
	# ROOF-SIDE-03: BOTH axes fold at period 64 — the atom's SE half consumes
	# y as a dir-1 run position, which the old period-32 y-fold cannot carry.
	var lookup_key = "ROOF|%s|%s|%d|%d" % [
		material_id, facade_id,
		_mirror_index_1d(local_pos.x, 64), _mirror_index_1d(local_pos.y, 64),
	]
	if not lookup_dict.has(lookup_key):
		if _debug_enabled() and _diag_miss_count < _diag_miss_log_limit:
			_diag_miss_count += 1
			print("[BAKE-DIAG] flat lookup MISS reason=KEY_NOT_IN_DICT (key=%s, local=%s)" % [lookup_key, local_pos])
		return null
	var entry = lookup_dict[lookup_key]
	var source_id: int = _get_baked_atlas_source_id(entry.get("page", -1))
	if source_id < 0:
		return null
	return TileLookupResult.new(source_id, "BAKED_FLAT", entry.get("atlas_coords", Vector2i.ZERO), 0)


## OVERLORD-FIX-02: junction columns have dedicated baked atoms whose halves
## continue each adjacent leg's plane. Keyed by the column's own voxel_pos +
## level; returns null when absent (caller falls back to the mirror path).
func resolve_junction(voxel_pos: Vector2i, level: int) -> TileLookupResult:
	var baked_atlas = _get_baked_atlas()
	if baked_atlas == null:
		return null
	var lookup_dict = baked_atlas.get("lookup", {}) if baked_atlas is Dictionary else baked_atlas.lookup
	var key := "JUNCTION|%d|%d|%d" % [voxel_pos.x, voxel_pos.y, level]
	if not lookup_dict.has(key):
		return null
	var entry = lookup_dict[key]
	var source_id: int = _get_baked_atlas_source_id(entry.get("page", -1))
	if source_id < 0:
		return null
	return TileLookupResult.new(source_id, "BAKED_JUNCTION", entry.get("atlas_coords", Vector2i.ZERO), 0)


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
