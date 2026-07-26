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
