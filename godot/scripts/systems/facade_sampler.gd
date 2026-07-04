## FacadeSampler — Sample the infinite facade plane via mirrored-repeat addressing
##
## The facade is a concrete texture (64N × 32N pixels) that defines an infinite
## deterministic plane via mirrored repetition. Given a coordinate in the infinite
## plane, return the luminance from the wrapped texture.

class_name FacadeSampler

## Sample facade at (plane_x, plane_y) in the infinite plane
## Uses mirrored-repeat addressing
## Returns: luminance [0, 1]
func sample(facade: Image, plane_x: float, plane_y: float) -> float:
	var tex_width = facade.get_width()
	var tex_height = facade.get_height()
	
	var sampled = _mirror_2d(plane_x, plane_y, tex_width, tex_height)
	var pixel = facade.get_pixel(sampled.x, sampled.y)
	
	# Extract luminance (V in HSV, works for grayscale)
	return pixel.v

## Get window origin for a contiguous run of edges
## Deterministic based on canonical minimum edge
func get_window_origin_run(canonical_min_edge, facade_id: String) -> Vector2i:
	return _window_origin_run(canonical_min_edge, facade_id)

## Get window origin for an isolated wall
## Randomized based on edge hash
func get_window_origin_isolated(edge, facade_id: String) -> Vector2i:
	return _window_origin_isolated(edge, facade_id)

## Get window bounds from origin and dimensions
func get_window_bounds(origin: Vector2i, width_voxels: int, height_voxels: int, N: int) -> Rect2i:
	return Rect2i(origin.x, origin.y, width_voxels * N, height_voxels * N)

## Mirror 2D coordinates into texture domain
func _mirror_2d(plane_x: float, plane_y: float, tex_width: int, tex_height: int) -> Vector2i:
	var tx = _mirror_1d(plane_x, tex_width)
	var ty = _mirror_1d(plane_y, tex_height)
	return Vector2i(int(tx), int(ty))

## Mirror 1D coordinate: fold into [0, S), with mirrored-repeat
func _mirror_1d(k: float, S: int) -> float:
	var S_int = float(S)
	var k2 = fmod(k, 2.0 * S_int)
	
	# Handle negative fmod results
	if k2 < 0:
		k2 += 2.0 * S_int
	
	# Boundary case: exactly at S wraps to next period
	if abs(k2 - S_int) < 0.0001:
		return 0.0
	
	# Reflect if in the second half of the period
	if k2 > S_int:
		k2 = 2.0 * S_int - k2
	
	return k2

## Window origin for contiguous run (all edges use same origin from canonical min)
func _window_origin_run(canonical_min_edge, facade_id: String) -> Vector2i:
	# Get key string from edge (duck typing; expects .key_string() method or property)
	var key_str = ""
	if canonical_min_edge.has_method("key_string"):
		key_str = canonical_min_edge.key_string()
	else:
		key_str = canonical_min_edge.key_string as String
	
	var hash_input = key_str + ":" + facade_id
	var hash_val = _fnv1a_hash(hash_input)
	
	# Column offset: [0, 64N)
	var plane_col = (hash_val % 64)
	var plane_row = 0  # v1 uses row 0
	
	return Vector2i(plane_col, plane_row)

## Window origin for isolated wall (independent hash per edge)
func _window_origin_isolated(edge, facade_id: String) -> Vector2i:
	var key_str = ""
	if edge.has_method("key_string"):
		key_str = edge.key_string()
	else:
		key_str = edge.key_string as String
	
	var hash_input = key_str + ":" + facade_id
	var hash_val = _fnv1a_hash(hash_input)
	
	# Two independent hashes
	var plane_col = ((hash_val >> 0) & 0xFF) % 64
	var plane_row = ((hash_val >> 8) & 0xFF) % 32
	
	return Vector2i(plane_col, plane_row)

## FNV-1a 32-bit hash
func _fnv1a_hash(input: String) -> int:
	var hash_val: int = 2166136261  # FNV offset basis
	var fnv_prime: int = 16777619
	
	for byte_val in input.to_ascii_buffer():
		hash_val ^= byte_val
		hash_val = (hash_val * fnv_prime) & 0xFFFFFFFF  # Keep 32-bit
	
	return hash_val
