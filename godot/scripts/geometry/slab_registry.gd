## Geometry Module — Slab Registry: single source of truth for Slab containers
## DESTRUCTION_MASTER_PLAN D1. Mirrors EdgeRegistry's slice-half (get/all/dirty/
## clear); no edge-linking half exists because Slab voxels have no edge to link to.
class_name SlabRegistry

signal slab_registered(slab: Slab)

var _slabs: Dictionary = {}    ## slab.id → Slab


## Register a slab
func register_slab(slab: Slab) -> void:
	_slabs[slab.id] = slab
	slab_registered.emit(slab)


## Get slab by ID; returns null if not found
func get_slab(id: String) -> Slab:
	return _slabs.get(id)


## All registered slabs
func all_slabs() -> Array:
	return _slabs.values()


## Dirty slabs (dirty_count > 0) — TIC entry point, mirrors EdgeRegistry.dirty_slices()
func dirty_slabs() -> Array:
	var result: Array = []
	for slab in _slabs.values():
		if slab.dirty_count > 0:
			result.append(slab)
	return result


## Clear all registrations
func clear() -> void:
	_slabs.clear()


## Check if registry is empty
func is_empty() -> bool:
	return _slabs.is_empty()


## Debug: print all slabs
func debug_print() -> void:
	print("\n=== SlabRegistry Debug ===")
	print("Slabs: %d" % _slabs.size())
	for slab in _slabs.values():
		print("  %s" % slab)
	print("=== End ===\n")
