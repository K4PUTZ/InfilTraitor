## PropVoxelizer — turns any fitted model (`PropModelFit`) into board-size voxels, keeping its SHAPE.
##
## PROPS_TIER4_PLAN P1 / `ACTOR` D67. A voxel here is exactly one board voxel (1/8 GU, `VOXELS_PER_UNIT_AXIS` per axis), on the
## board's own lattice: local X/Z = 0 is a voxel boundary (a cell's centre is 4 voxels in) and local Y = 0 is a level boundary, so
## a cell index is the offset from the prop's cell centre / floor and adds straight onto the board's voxel coordinates.
##
## METHOD. Every triangle marks each voxel whose box it overlaps (Akenine-Moller's separating-axis test, conservative: a leg thinner
## than a voxel is still a column). A table keeps its top plate and its legs because SURFACES are rasterised, not the bounding box.
## A cell takes the zone (the surface index across the model's parts) of the first triangle that marked it. The output is sorted
## (y, z, x), so the same model always gives the same bytes.
##
## Generic on purpose: it knows nothing about tables. Whatever a `mesh_tier 4` prop is, this is what its fragments are made from;
## a box (the placeholder, or a slot's generic) voxelizes to a box.
class_name PropVoxelizer

## Shrinks the test box a hair so a triangle that only TOUCHES a voxel's face (a plate lying exactly on a level boundary) does not
## also mark the voxel on the other side of it.
const TOUCH_EPS: float = 1.0e-4

static var _cache: Dictionary = {}


## Cached per model key (the same key `PropModelFit` uses). {"cells": Array[Vector3i], "zones": PackedInt32Array, "voxel": float}.
static func for_model(path: String, rotation_deg: Vector3, fit_size: Vector3) -> Dictionary:
	var key := "%s|%s|%s" % [path, rotation_deg, fit_size]
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = {"cells": [], "zones": PackedInt32Array(), "voxel": voxel_size()}
	var model: Dictionary = PropModelFit.fit(path, rotation_deg, fit_size) if path != "" else PropModelFit.box(fit_size)
	if bool(model["ok"]):
		out = voxelize(model["parts"])
	_cache[key] = out
	return out


static func clear_cache() -> void:
	_cache.clear()


static func voxel_size() -> float:
	return 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)


## `parts`: Array of {"mesh": Mesh, "xf": Transform3D}. Returns {"cells", "zones", "voxel"}; `zones[i]` is the zone of `cells[i]`.
static func voxelize(parts: Array, voxel: float = -1.0) -> Dictionary:
	var v: float = voxel if voxel > 0.0 else voxel_size()
	var half := Vector3.ONE * (v * 0.5 - TOUCH_EPS)
	var zone_of: Dictionary = {}   ## Vector3i -> int
	var zone_base: int = 0
	## The model's middle: a face lying EXACTLY on a voxel boundary touches neither voxel's shrunk box, and belongs to the one
	## on the model's inside (else a box aligned to the grid would grow a voxel on every side).
	var inward := Vector3.ZERO
	var bounds := AABB()
	var bounds_set: bool = false
	for part: Dictionary in parts:
		var bb: AABB = (part["xf"] as Transform3D) * (part["mesh"] as Mesh).get_aabb()
		bounds = bb if not bounds_set else bounds.merge(bb)
		bounds_set = true
	if bounds_set:
		inward = bounds.position + bounds.size * 0.5
	for part: Dictionary in parts:
		var mesh: Mesh = part["mesh"]
		var xf: Transform3D = part["xf"]
		for s in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var tri_count: int = int(idx.size() / 3.0) if idx.size() > 0 else int(verts.size() / 3.0)
			for t in range(tri_count):
				var i0: int = idx[t * 3] if idx.size() > 0 else t * 3
				var i1: int = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
				var i2: int = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
				_mark_triangle(xf * verts[i0], xf * verts[i1], xf * verts[i2], v, half, zone_base + s, zone_of, inward)
		zone_base += mesh.get_surface_count()
	var cells: Array = zone_of.keys()
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var zones := PackedInt32Array()
	zones.resize(cells.size())
	for i in range(cells.size()):
		zones[i] = int(zone_of[cells[i]])
	return {"cells": cells, "zones": zones, "voxel": v}


static func _mark_triangle(a: Vector3, b: Vector3, c: Vector3, v: float, half: Vector3, zone: int, zone_of: Dictionary,
		inward: Vector3) -> void:
	if _mark_cells(a, b, c, v, half, zone, zone_of):
		return
	## Nothing overlapped: the triangle lies on a voxel boundary. Slide it a hair toward the model's inside and mark again.
	var g: Vector3 = (a + b + c) / 3.0
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() > 1.0e-18:
		var d: Vector3 = n.normalized()
		if d.dot(inward - g) < 0.0:
			d = -d
		var shift: Vector3 = d * (TOUCH_EPS * 3.0)
		if _mark_cells(a + shift, b + shift, c + shift, v, half, zone, zone_of):
			return
	## A degenerate sliver: the cell its centroid is in.
	var cell := Vector3i(floori(g.x / v), maxi(floori(g.y / v), 0), floori(g.z / v))
	if not zone_of.has(cell):
		zone_of[cell] = zone


## Marks every voxel the triangle overlaps; true when it marked (or already held) at least one.
static func _mark_cells(a: Vector3, b: Vector3, c: Vector3, v: float, half: Vector3, zone: int, zone_of: Dictionary) -> bool:
	var lo := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
	var hi := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))
	var marked: bool = false
	for y in range(maxi(floori(lo.y / v), 0), floori(hi.y / v) + 1):
		for z in range(floori(lo.z / v), floori(hi.z / v) + 1):
			for x in range(floori(lo.x / v), floori(hi.x / v) + 1):
				var centre := Vector3((float(x) + 0.5) * v, (float(y) + 0.5) * v, (float(z) + 0.5) * v)
				if triangle_overlaps_box(centre, half, a, b, c):
					marked = true
					var cell := Vector3i(x, y, z)
					if not zone_of.has(cell):
						zone_of[cell] = zone
	return marked


## Separating-axis test (Akenine-Moller 2001): triangle `a b c` against the box at `centre` with half-extents `h`.
static func triangle_overlaps_box(centre: Vector3, h: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0: Vector3 = a - centre
	var v1: Vector3 = b - centre
	var v2: Vector3 = c - centre
	## The box's own three axes: the triangle's bounds against the box.
	if minf(v0.x, minf(v1.x, v2.x)) > h.x or maxf(v0.x, maxf(v1.x, v2.x)) < -h.x:
		return false
	if minf(v0.y, minf(v1.y, v2.y)) > h.y or maxf(v0.y, maxf(v1.y, v2.y)) < -h.y:
		return false
	if minf(v0.z, minf(v1.z, v2.z)) > h.z or maxf(v0.z, maxf(v1.z, v2.z)) < -h.z:
		return false
	var e0: Vector3 = v1 - v0
	var e1: Vector3 = v2 - v1
	var e2: Vector3 = v0 - v2
	## The triangle's plane.
	var n: Vector3 = e0.cross(e1)
	var r: float = h.x * absf(n.x) + h.y * absf(n.y) + h.z * absf(n.z)
	if absf(n.dot(v0)) > r:
		return false
	## The nine edge x axis cross products.
	for e: Vector3 in [e0, e1, e2]:
		if not _axis_overlaps(Vector3(0.0, -e.z, e.y), v0, v1, v2, h):
			return false
		if not _axis_overlaps(Vector3(e.z, 0.0, -e.x), v0, v1, v2, h):
			return false
		if not _axis_overlaps(Vector3(-e.y, e.x, 0.0), v0, v1, v2, h):
			return false
	return true


static func _axis_overlaps(axis: Vector3, v0: Vector3, v1: Vector3, v2: Vector3, h: Vector3) -> bool:
	if axis.length_squared() < 1.0e-18:
		return true   ## a degenerate axis separates nothing
	var p0: float = axis.dot(v0)
	var p1: float = axis.dot(v1)
	var p2: float = axis.dot(v2)
	var r: float = h.x * absf(axis.x) + h.y * absf(axis.y) + h.z * absf(axis.z)
	return not (minf(p0, minf(p1, p2)) > r or maxf(p0, maxf(p1, p2)) < -r)
