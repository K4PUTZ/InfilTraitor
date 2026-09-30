## VoxPropBuilder — a parsed `.vox` model into the cells of a destructible prop. PURE.
##
## PROP_PIPELINE_PLAN PP4. Steps, in order: SCALE (each source voxel becomes `scale`^3 board voxels; the target is the board voxel, 1/8 GU),
## MATERIAL (each palette index resolves to a registry material id through `material_of`), HOLLOW (keep only voxels with an empty
## 6-neighbour, like the crate's shell: a 16^3 model is ~1 200 claims, not 4 096), CENTRE (the model stands on the floor, centred on the
## footprint area). The result is grouped by material: one entry per material, each a list of cells in footprint-local voxel coordinates
## (x, y horizontal, z UP = the board level above the floor), because the store holds one material per container.
class_name VoxPropBuilder

## `material_of`: Callable(colour index: int, colour: Color) -> String. `area`: the footprint's size in BOARD voxels (x, y).
## Returns {"materials": {material_id: Array[Vector3i]}, "claims": int, "size": Vector3i (scaled model), "fits": bool}.
static func build(model: VoxModel, scale: int, material_of: Callable, area: Vector2i) -> Dictionary:
	var k: int = maxi(scale, 1)
	var scaled := Vector3i(model.size.x * k, model.size.y * k, model.size.z * k)
	var index_at: Dictionary = {}   ## Vector3i (source cell) -> colour index
	for v: Vector4i in model.voxels:
		index_at[Vector3i(v.x, v.y, v.z)] = v.w
	## The scaled occupancy, only as far as the hollowing test needs it.
	var out: Dictionary = {}
	var claims: int = 0
	var off_x: int = maxi(int((area.x - scaled.x) / 2.0), 0)
	var off_y: int = maxi(int((area.y - scaled.y) / 2.0), 0)
	var keys: Array = index_at.keys()
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for src: Vector3i in keys:
		var colour_index: int = int(index_at[src])
		var material_id: String = String(material_of.call(colour_index, model.palette[colour_index - 1]))
		for dz in range(k):
			for dy in range(k):
				for dx in range(k):
					var c := Vector3i(src.x * k + dx, src.y * k + dy, src.z * k + dz)
					if not _is_surface(c, k, index_at):
						continue
					if not out.has(material_id):
						out[material_id] = []
					(out[material_id] as Array).append(Vector3i(c.x + off_x, c.y + off_y, c.z))
					claims += 1
	return {"materials": out, "claims": claims, "size": scaled, "fits": scaled.x <= area.x and scaled.y <= area.y}


## A scaled cell is kept when any of its six neighbours is empty (outside the model, or inside an empty source voxel).
static func _is_surface(c: Vector3i, k: int, index_at: Dictionary) -> bool:
	for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var n: Vector3i = c + d
		if n.x < 0 or n.y < 0 or n.z < 0:
			return true
		var src := Vector3i(int(floor(float(n.x) / float(k))), int(floor(float(n.y) / float(k))), int(floor(float(n.z) / float(k))))
		if not index_at.has(src):
			return true
	return false
