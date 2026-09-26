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
	
	# Boundary case: exactly at S wraps to S-1 (GL mirrored-repeat convention, no spike)
	if abs(k2 - S_int) < 0.0001:
		return S_int - 1.0
	
	# Reflect if in the second half of the period
	if k2 > S_int:
		k2 = 2.0 * S_int - k2
	
	return k2

## FNV-1a 32-bit hash
## Static: pure function of `input`, no instance state. Made static 2026-07-16
## (DESTRUCTION D2/D4) so EarthVariantSelector can call it directly — B4
## pins this exact algorithm, so it gets ONE owner, not a second copy.
## Existing instance-call sites (e.g. `sampler._fnv1a_hash(...)` in
## bake_selftest.gd) remain valid: GDScript allows calling a static func
## through an instance reference.
static func _fnv1a_hash(input: String) -> int:
	var hash_val: int = 2166136261  # FNV offset basis
	var fnv_prime: int = 16777619
	
	for byte_val in input.to_ascii_buffer():
		hash_val ^= byte_val
		hash_val = (hash_val * fnv_prime) & 0xFFFFFFFF  # Keep 32-bit
	
	return hash_val
