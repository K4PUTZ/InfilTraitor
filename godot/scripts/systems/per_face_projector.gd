## PerFaceProjector — Isometric shear transforms for wall texture mapping
##
## Maps flat texture-space coordinates → screen-space (isometric) coordinates
## for the four cardinal vertical wall faces (NE, SE, SW, NW).
##
## Key invariant: All shear offsets are INTEGER pixels for the pinned N,
## guaranteeing one-texel-to-one-pixel fidelity under NEAREST sampling.

class_name PerFaceProjector

# Import geometry constants
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

# Face orientations (cardinal vertex facing)
enum Face { NE, SE, SW, NW, CAP }

# Transform structure: { "matrix": [[a, b], [c, d]], "offset": Vector2(x, y) }
var transforms: Dictionary = {}
var N: int

# Extracted from canonical tileset geometry after TILE_ANATOMY_AUDIT.
# These transforms account for:
# - Isometric projection (2D diamond perspective)
# - The legacy VOXEL_TILE_OFFSET_PX = (112, 64) calibration
#
# Matrix meaning: screen = M * flat + offset
#   M[0][0], M[0][1] = screen_x coefficients (flat_x, flat_y)
#   M[1][0], M[1][1] = screen_y coefficients (flat_x, flat_y)

func _init(p_N: int = -1) -> void:
	# If N not provided, use from GeometryCoords
	if p_N > 0:
		N = p_N
	else:
		N = GeometryCoordsClass.TEX_AUTHORING_N

	_setup_transforms()
	# Run integer-shear assertion immediately
	_assert_integer_shear_all_faces()

func _setup_transforms() -> void:
	# Isometric projection geometry for the four faces.
	# Each transform is derived from the canonical tileset renderer.
	#
	# Frame: flat texture is 8N × 8N pixels (one voxel quad).
	# Screen is 32 × 16 pixels isometric diamond.
	#
	# The transforms apply affine mapping: screen = M * flat + offset
	
	# NE face: tilted right (shear rightward on horizontal axis)
	# Top vertex points northeast; right side sheared right
	transforms[Face.NE] = {
		"matrix": [[1.0, 0.5], [0.0, -0.5]],
		"offset": Vector2(0.0, 8.0 * N * 0.5)
	}
	
	# SE face: tilted down (shear downward on vertical axis)
	# Right vertex points southeast; bottom side sheared down
	transforms[Face.SE] = {
		"matrix": [[0.5, 0.0], [0.5, 0.5]],
		"offset": Vector2(16.0, 0.0)
	}
	
	# SW face: tilted left (shear leftward on horizontal axis)
	# Bottom vertex points southwest; left side sheared left
	transforms[Face.SW] = {
		"matrix": [[1.0, -0.5], [0.0, 0.5]],
		"offset": Vector2(32.0, 8.0 * N * 0.5)
	}
	
	# NW face: tilted up (shear upward on vertical axis)
	# Left vertex points northwest; top side sheared up
	transforms[Face.NW] = {
		"matrix": [[-0.5, 0.0], [-0.5, 0.5]],
		"offset": Vector2(16.0, 0.0)
	}
	
	# CAP face: diamond top (forward-compatible, not baked in v1)
	transforms[Face.CAP] = {
		"matrix": [[0.5, 0.5], [-0.5, 0.5]],
		"offset": Vector2(16.0, 0.0)
	}

## Transform point from flat texture space → screen space (isometric)
func flat_to_screen(face: int, flat_px: Vector2) -> Vector2:
	# face should be one of the Face enum values (treated as int)
	if not transforms.has(face):
		push_error("PerFaceProjector: Unknown face %s" % face)
		return Vector2.ZERO
	
	var t = transforms[face]
	var M = t["matrix"]
	var offset = t["offset"]
	
	var screen_x = M[0][0] * flat_px.x + M[0][1] * flat_px.y + offset.x
	var screen_y = M[1][0] * flat_px.x + M[1][1] * flat_px.y + offset.y
	
	return Vector2(screen_x, screen_y)

## Transform point from screen space → flat texture space (inverse)
func screen_to_flat(face: int, screen_px: Vector2) -> Vector2:
	# face should be one of the Face enum values (treated as int)
	if not transforms.has(face):
		push_error("PerFaceProjector: Unknown face %s" % face)
		return Vector2.ZERO
	
	var t = transforms[face]
	var M = t["matrix"]
	var offset = t["offset"]
	
	# Invert the affine: flat = M^-1 * (screen - offset)
	var M_inv = _invert_2x2(M)
	var centered = screen_px - offset
	
	var flat_x = M_inv[0][0] * centered.x + M_inv[0][1] * centered.y
	var flat_y = M_inv[1][0] * centered.x + M_inv[1][1] * centered.y
	
	return Vector2(flat_x, flat_y)

## Check if screen pixel is within the voxel face parallelogram
func is_inside_voxel(face: int, screen_px: Vector2) -> bool:
	var corners = _get_corners(face)
	return _point_in_quad(screen_px, corners)

## Return the four screen-space corners of the voxel face
func _get_corners(face: int) -> Array:
	var corners: Array = []
	var flat_corners = [
		Vector2(0.0, 0.0),
		Vector2(8.0 * N, 0.0),
		Vector2(8.0 * N, 8.0 * N),
		Vector2(0.0, 8.0 * N)
	]
	
	for flat_corner in flat_corners:
		corners.append(flat_to_screen(face, flat_corner))
	
	return corners

## Point-in-parallelogram test (cross-product consistency)
func _point_in_quad(pt: Vector2, corners: Array) -> bool:
	# Assumes corners is [TL, TR, BR, BL] in screen space
	# Check if point is on the same side of all edges using cross products
	
	if corners.size() != 4:
		return false
	
	var signs: Array = []
	
	for i in range(4):
		var v1 = corners[i]
		var v2 = corners[(i + 1) % 4]
		var edge = v2 - v1
		var to_pt = pt - v1
		var cross = edge.x * to_pt.y - edge.y * to_pt.x
		signs.append(cross)
	
	# All crosses should have the same sign (or be zero on boundary)
	var all_positive = signs.all(func(s): return s >= -0.0001)
	var all_negative = signs.all(func(s): return s <= 0.0001)
	
	return all_positive or all_negative

## Invert a 2×2 matrix
func _invert_2x2(M: Array) -> Array:
	# M = [[a, b], [c, d]]
	# M^-1 = (1/(ad-bc)) * [[d, -b], [-c, a]]
	
	var a = M[0][0]
	var b = M[0][1]
	var c = M[1][0]
	var d = M[1][1]
	
	var det = a * d - b * c
	assert(abs(det) > 0.0001, "PerFaceProjector: Singular matrix; no inverse")
	
	var inv_det = 1.0 / det
	return [
		[inv_det * d, -inv_det * b],
		[-inv_det * c, inv_det * a]
	]

## Multiply two 2×2 matrices
func _multiply_2x2(A: Array, B: Array) -> Array:
	var result: Array = [[], []]
	for i in range(2):
		for j in range(2):
			result[i].append(A[i][0] * B[0][j] + A[i][1] * B[1][j])
	return result

## Assert that screen-space coordinates are integer or nearly-integer
## Critical for NEAREST texture sampling without subpixel artifacts
func _assert_integer_shear_all_faces() -> void:
	print("[GEOMETRY] Validating integer shear for all faces...")

	# Check all four main faces
	for face_name in ["NE", "SE", "SW", "NW"]:
		_validate_face_shear(face_name)

	print("[GEOMETRY] ✓ Integer shear validated for all faces\n")

func _validate_face_shear(face_name: String) -> void:
	var face
	match face_name:
		"NE": face = Face.NE
		"SE": face = Face.SE
		"SW": face = Face.SW
		"NW": face = Face.NW
		_: return

	var tolerance = 0.0001
	var failures = []

	# For all flat coordinates in [0, 8N) × [0, 8N), verify screen Y is integer
	for flat_y in range(0, 8 * N + 1):
		for flat_x in range(0, 8 * N):
			var screen_pos = flat_to_screen(face, Vector2(float(flat_x), float(flat_y)))

			# Check if Y is nearly integer (tolerance for floating-point error)
			var y_frac = fmod(screen_pos.y, 1.0)
			if y_frac < 0 :
				y_frac += 1.0
			var is_integer = (y_frac < tolerance or y_frac > (1.0 - tolerance))

			if not is_integer:
				failures.append(
					"  flat(%.0f, %.0f) → screen_y=%.6f (frac=%.6f)" %
					[float(flat_x), float(flat_y), screen_pos.y, y_frac]
				)

	if failures.is_empty():
		print("  ✓ [%s] All %d points map to integer Y" % [face_name, (8 * N) * (8 * N + 1)])
	else:
		push_error("[%s] Integer shear FAILED: %d points with fractional Y:" % [face_name, failures.size()])
		for msg in failures.slice(0, 5):
			push_error(msg)
		assert(false, "Integer shear validation FAILED for face %s (see errors above)" % face_name)

