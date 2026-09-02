## Geometry Module — Edge Registry: single source of truth linking model
## Port from voxel_registry.gd with edge tracking
class_name EdgeRegistry

signal edge_registered(edge: Edge)
signal slice_registered(slice: Slice)

var _edges: Dictionary = {}     ## edge.id → Edge
var _slices: Dictionary = {}    ## slice.id → Slice


## Register an edge
func register_edge(edge: Edge) -> void:
	_edges[edge.id] = edge
	edge_registered.emit(edge)


## Register a slice; also backfill edge.slice_a_id or slice_b_id
func register_slice(slice: Slice) -> void:
	_slices[slice.id] = slice
	
	# Backfill the parent edge's slice ID
	var edge := get_edge(slice.edge_id)
	if edge:
		if slice.face == edge.face_a:
			edge.slice_a_id = slice.id
		elif slice.face == edge.face_b:
			edge.slice_b_id = slice.id
		else:
			push_error("EdgeRegistry.register_slice: slice face %d doesn't match edge faces %d/%d" % 
				[slice.face, edge.face_a, edge.face_b])
	
	slice_registered.emit(slice)


## Get edge by ID; returns null if not found
func get_edge(id: String) -> Edge:
	return _edges.get(id)


## Get slice by ID; returns null if not found
func get_slice(id: String) -> Slice:
	return _slices.get(id)


## Get both slices of an edge in order [slice_a, slice_b]
## Returns array of 2 slices, or empty if edge not found or slices not yet registered
func slices_of_edge(edge_id: String) -> Array:
	var edge := get_edge(edge_id)
	if not edge:
		return []
	
	var result: Array = []
	if edge.slice_a_id:
		var slice_a := get_slice(edge.slice_a_id)
		if slice_a:
			result.append(slice_a)
	if edge.slice_b_id:
		var slice_b := get_slice(edge.slice_b_id)
		if slice_b:
			result.append(slice_b)
	
	return result



## Get sibling slice on the other side of the wall
## Returns null if slice not found or sibling not registered
func sibling_slice(slice_id: String) -> Slice:
	var slice := get_slice(slice_id)
	if not slice:
		return null
	
	var edge := get_edge(slice.edge_id)
	if not edge:
		return null
	
	# Return the other slice
	if slice.id == edge.slice_a_id:
		return get_slice(edge.slice_b_id)
	elif slice.id == edge.slice_b_id:
		return get_slice(edge.slice_a_id)
	else:
		push_error("EdgeRegistry.sibling_slice: slice not part of edge")
		return null


## All edges touching a given Gameplay Unit (at most 4)
func edges_touching_gu(gu: Vector2i) -> Array:
	var result: Array = []
	for edge in _edges.values():
		if edge.gu_a == gu or edge.gu_b == gu:
			result.append(edge)
	return result


## All registered edges
func all_edges() -> Array:
	return _edges.values()


## All registered slices
func all_slices() -> Array:
	return _slices.values()


## GLASS G7 (GLASS_MASTER_PLAN §7.2) — every glass PANEL edge, keyed the way
## `blocked_edges` is (`WallEdgeData.edge_key`), value = the edge's `pane_id`.
## Half-thickness glass panels never populate `blocked_edges`, so the pellet
## flood needs this separate lookup to know a round is crossing glass — it
## registers a hole there and keeps going (G-D5). Glass BLOCKS (pane_id
## `PANE_BLOCK_*`) are excluded: their cells are in `blocked_cells` and their
## pass-through is deferred with the rest of the block work.
func glass_edge_keys() -> Dictionary:
	var out: Dictionary = {}
	for edge in _edges.values():
		if not GlassMaterials.is_glass(edge.material):
			continue
		var pid: String = ""
		var sa := get_slice(edge.slice_a_id)
		var sb := get_slice(edge.slice_b_id)
		if sa != null and sa.pane_id != "":
			pid = sa.pane_id
		elif sb != null and sb.pane_id != "":
			pid = sb.pane_id
		if pid.begins_with("PANE_BLOCK_"):
			continue
		out[WallEdgeData.edge_key(edge.gu_a, edge.gu_b)] = pid
	return out


## GLASS G-D16 / V-C — the glass edges a ROUND STOPS AT, keyed like the above,
## value = pane_id. INDESTRUCTIBLE members only (the control-interface screens):
## *"trinca mas o tiro para"*.
##
## ⚠️ THIS IS A SECOND SET, NOT A FILTER ON THE FIRST, and the distinction is the
## same conflation G3 Stage D already had to undo once. `glass_edge_keys()` reads
## as "these edges are glass" and today answers TWO different questions —
## `build_movement_edge_set` asks *does this stop a body*, the pellet flood asks
## *does a round go through*. Narrowing it to the passable subset would have
## silently made every screen WALK-THROUGH, because a half-thickness panel is not
## in `blocked_edges` either: it would have vanished from both answers at once.
## So the pass-through question gets its own set and the movement question keeps
## the full one.
func glass_stop_edge_keys() -> Dictionary:
	var out: Dictionary = {}
	for edge in _edges.values():
		if not GlassMaterials.is_glass(edge.material):
			continue
		var sa := get_slice(edge.slice_a_id)
		var sb := get_slice(edge.slice_b_id)
		## V-D — the class is read off the SLICE, not the edge, because the
		## per-placement override travels with the placement. Either side will do:
		## a panel has exactly one slice, and a full-thickness pane's two slices
		## come from the same authored panel.
		var override: int = GlassMaterials.CLASS_UNSET
		if sa != null:
			override = sa.glass_class
		elif sb != null:
			override = sb.glass_class
		if not GlassMaterials.stops_a_round(edge.material, override):
			continue
		var pid: String = ""
		if sa != null and sa.pane_id != "":
			pid = sa.pane_id
		elif sb != null and sb.pane_id != "":
			pid = sb.pane_id
		if pid.begins_with("PANE_BLOCK_"):
			continue
		out[WallEdgeData.edge_key(edge.gu_a, edge.gu_b)] = pid
	return out


## Dirty slices (dirty_count > 0) — TIC entry point
func dirty_slices() -> Array:
	var result: Array = []
	for slice in _slices.values():
		if slice.dirty_count > 0:
			result.append(slice)
	return result


## Clear all registrations
func clear() -> void:
	_edges.clear()
	_slices.clear()


## Check if registry is empty
func is_empty() -> bool:
	return _edges.is_empty() and _slices.is_empty()


## Debug: print all edges and slices
func debug_print() -> void:
	print("\n=== EdgeRegistry Debug ===")
	print("Edges: %d" % _edges.size())
	for edge in _edges.values():
		print("  %s" % edge)
	print("Slices: %d" % _slices.size())
	for slice in _slices.values():
		print("  %s" % slice)
	print("=== End ===\n")
