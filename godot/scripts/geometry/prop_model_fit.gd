## PropModelFit — a prop model (glTF/GLB, or a plain box) fitted into its `mesh_size`: turned by `rotation_deg`, scaled
## uniformly to fit, standing on Y = 0 and centred on X/Z (so local X/Z = 0 is the cell's centre, a board-voxel boundary,
## and local Y = 0 is the floor). One answer, used by the thing that DRAWS the prop (`PropMesh3D.setup_model`) and by the
## thing that turns it into voxels (`PropVoxelizer`), so the two can never disagree about where the prop is.
##
## Cached per (path, rotation, fit size): a model is built once and every instance of it shares the parts (PROP_PIPELINE_PLAN
## §1b, several instances of one model). A part is {"mesh": Mesh, "xf": Transform3D}, `xf` already carrying the fit. `surfaces` is
## the name of the material each surface was authored with, in the order `PropVoxelizer` numbers its zones (across the parts).
class_name PropModelFit

static var _cache: Dictionary = {}


## {"ok": bool, "parts": Array[Dictionary], "size": Vector3 (the fitted box)}. A failure is `push_error`'d once and cached.
static func fit(path: String, rotation_deg: Vector3, fit_size: Vector3) -> Dictionary:
	var key := "%s|%s|%s" % [path, rotation_deg, fit_size]
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = _load_fit(path, rotation_deg, fit_size)
	_cache[key] = out
	return out


## The placeholder: a box of `size`, standing on Y = 0. What a Tier 4 prop with no model voxelizes from.
static func box(size: Vector3) -> Dictionary:
	var key := "box|%s" % size
	if _cache.has(key):
		return _cache[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	var out := {"ok": true, "size": size, "surfaces": [""],
		"parts": [{"mesh": mesh, "xf": Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0))}]}
	_cache[key] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


static func _load_fit(path: String, rotation_deg: Vector3, fit_size: Vector3) -> Dictionary:
	var failed := {"ok": false, "parts": [], "size": Vector3.ZERO, "surfaces": []}
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("[PropModelFit] cannot load '%s'" % path)
		return failed
	var root: Node = scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			meshes.append(n as MeshInstance3D)
	if meshes.is_empty():
		push_error("[PropModelFit] '%s' holds no mesh" % path)
		root.free()
		return failed
	## The model's own node transforms (the import's axis fix, a unit scale) are part of its shape: measure through them.
	var turn := Basis.from_euler(Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z)))
	var box := AABB()
	var first := true
	var xforms: Array[Transform3D] = []
	for m in meshes:
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != root.get_parent():
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		xf = Transform3D(turn, Vector3.ZERO) * xf
		xforms.append(xf)
		var bb: AABB = xf * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		push_error("[PropModelFit] '%s' has a flat or empty bounding box %s" % [path, box.size])
		root.free()
		return failed
	var k: float = minf(fit_size.x / box.size.x, minf(fit_size.y / box.size.y, fit_size.z / box.size.z))
	var centre := Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	var fit := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), -centre * k)
	var parts: Array = []
	var surfaces: Array = []
	for i in range(meshes.size()):
		parts.append({"mesh": meshes[i].mesh, "xf": fit * xforms[i]})
		for s in range(meshes[i].mesh.get_surface_count()):
			var src: Material = meshes[i].mesh.surface_get_material(s)
			surfaces.append(src.resource_name if src != null else "")
	root.free()
	return {"ok": true, "parts": parts, "size": box.size * k, "surfaces": surfaces}
