## FacadeSampler — the FNV-1a hash every deterministic pick in the game reads (B4)
##
## It began as the 2D bake's sampler of the infinite facade plane (mirrored-repeat addressing) and its per-run window
## origins. Both went with the 2D board (R3D-END; last present in `6bb89cb4`, and the window origins are R3D-LOOK's
## reference). What is left is the hash, kept in this file because the B4 hook pins its constants here.

class_name FacadeSampler

## FNV-1a 32-bit hash
## Static: pure function of `input`, no instance state. Made static 2026-07-16
## (DESTRUCTION D2/D4) so EarthVariantSelector can call it directly — B4
## pins this exact algorithm, so it gets ONE owner, not a second copy.
## Existing instance-call sites (e.g. `instance._fnv1a_hash(...)` in
## earth_variant_selftest.gd) remain valid: GDScript allows calling a static func
## through an instance reference.
static func _fnv1a_hash(input: String) -> int:
	var hash_val: int = 2166136261  # FNV offset basis
	var fnv_prime: int = 16777619
	
	for byte_val in input.to_ascii_buffer():
		hash_val ^= byte_val
		hash_val = (hash_val * fnv_prime) & 0xFFFFFFFF  # Keep 32-bit
	
	return hash_val
