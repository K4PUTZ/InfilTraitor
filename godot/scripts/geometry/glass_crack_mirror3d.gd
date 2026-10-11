## GlassCrackMirror3D — the 3D board's twin of every live `GlassCrackSprite`.
##
## RENDER3D R3D-6 item 2 (moved here from R3D-4e-4b). `VoxelBoard.spawn_glass_crack()` / `spawn_glass_craze()` produce
## each crack as a RECORD: the centre voxel, the face, the run axis, the span, the pane bounds and `params`, every shader
## parameter as data (the occupancy cut and the opening void included). This node gives each record a quad on the pane's
## plane in the 3D world and copies `params` into it every frame. **R3D-9: it reads the record and nothing else** — not
## the 2D sprite, not its ShaderMaterial; the sprite is the same record's 2D consumer, until R3D-END. Nothing here
## decides a crack.
##
## PLACEMENT. The record says which voxel the crack is centred on (`impact_cell`, `impact_level`,
## `face`), which way the pane runs (`run_axis`: 0 = along X, 1 = along Z) and how large the sheet
## is (`crack_span`, in voxels). The quad is that many voxels wide and tall, centred on the
## impact voxel, standing on the face's own plane, and carries the sprite's UV so the shader's
## `off` is the same run/level offset it is in 2D.
class_name GlassCrackMirror3D
extends Node3D

const SHADER_PATH: String = "res://godot/shaders/glass_crack3d.gdshader"

## The record's uniforms, copied verbatim.
const MIRRORED: Array[String] = [
	"crack_sheet", "crack_span", "crack_pane_lo", "crack_pane_hi", "crack_field",
	"crack_tile_span", "crack_field_origin", "crack_field_dir", "crack_occupancy",
	"crack_occ_size", "crack_occ_origin", "crack_hole_cut", "crack_opening",
	"crack_opening_origin", "crack_opening_size", "crack_opacity",
]

## The strips' ink tone per edge plane, as the pane's own edges shade theirs (top lighter, ends darker, bottom darkest).
const STRIP_TONE_TOP: float = 0.85
const STRIP_TONE_END: float = 0.5
const STRIP_TONE_BOTTOM: float = 0.4

## Lifts the quad off the glass so it never z-fights the pane, in voxels.
const FACE_LIFT_VOXELS: float = 0.05

var _renderer: VoxelBoard = null
var _ground_level: int = 0
var _unit: float = 1.0
var _shader: Shader = null
## crack record id -> {"mesh": MeshInstance3D, "mat": ShaderMaterial, "rec": the record}
var _twins: Dictionary = {}

## CRACK-03/04 on the pane: the glass ShaderMaterials the applied openings are pushed into.
var pane_materials: Array = []
const OPEN_MAX: int = 16
const OPEN_TEXELS_PER_VOXEL: int = 12
var _open_seen: int = -1


func setup(renderer: VoxelBoard, ground_level: int) -> void:
	_renderer = renderer
	_ground_level = ground_level
	_unit = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		push_error("[GlassCrackMirror3D] R3D-6: %s failed to load — no crack will draw in 3D" % SHADER_PATH)


func _process(_delta: float) -> void:
	if _renderer == null or _shader == null:
		return
	_sync_openings()
	var live: Dictionary = {}
	for rec: Dictionary in _renderer.glass_crack_records():
		if not rec.has("params"):
			continue
		var id: int = int(rec["id"])
		live[id] = true
		var twin: Dictionary = _twins.get(id, {})
		if twin.is_empty():
			twin = _make_twin(rec)
			_twins[id] = twin
		_mirror(twin)
	for id: int in _twins.keys():
		if not live.has(id):
			(_twins[id]["mesh"] as MeshInstance3D).queue_free()
			_twins.erase(id)


func twin_count() -> int:
	return _twins.size()


func _make_twin(rec: Dictionary) -> Dictionary:
	var span: Vector2 = (rec["params"] as Dictionary).get("crack_span", Vector2(8.0, 8.0))
	var mesh := MeshInstance3D.new()
	mesh.name = "Crack_%d" % int(rec["id"])
	var quad := QuadMesh.new()
	quad.size = span * _unit
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	## Drawn after the pane's own pass, which reads what is behind it.
	mat.render_priority = 1
	mesh.material_override = mat
	mesh.transform = _placement(rec)
	add_child(mesh)
	var strips: MeshInstance3D = _make_strips(rec, mat)
	if strips != null:
		mesh.add_child(strips)
		strips.top_level = true   ## placed in the geometry root's space, not the quad's
		strips.global_transform = (get_parent() as Node3D).global_transform
	return {"mesh": mesh, "mat": mat, "rec": rec}


## 2026-10-10 (Director: "precisamos cobrir as laterais, topos e fundos dos outros painéis que racharam com os decals […] quando a
## face da frente rachar, a espessura precisa rachar também — sem alterar a diferenciação de opacidades/tons dos slivers"): the
## crack's ink on the pane's THICKNESS. Four thin quads on the pane's top, bottom and two ends, with the SAME material (so every
## parameter is the crack's own) and UVs that put each one on the front face's border: a crack line reaching the border carries over
## the edge. Drawn OVER the edge faces (the decal's blend), so the edges keep their own tones. Depth-tested: an end that meets a wall
## is hidden by it. The pane is one voxel thick (a panel, D16); the occupancy cut still applies, so a hole's border has no strip ink.
func _make_strips(rec: Dictionary, mat: ShaderMaterial) -> MeshInstance3D:
	var p: Dictionary = rec["params"]
	var span: Vector2 = p.get("crack_span", Vector2.ZERO)
	var lo: Vector2 = p.get("crack_pane_lo", Vector2.ZERO)
	var hi: Vector2 = p.get("crack_pane_hi", Vector2.ZERO)
	if span.x <= 0.0 or span.y <= 0.0:
		return null
	var run_is_x: bool = int(rec["run_axis"]) == 0
	var cell: Vector2i = rec["impact_cell"]
	var run_c: float = float(cell.x if run_is_x else cell.y)       ## the impact voxel's run index
	var lvl_abs: int = int(rec["impact_level"])
	var lvl_c: float = float(lvl_abs - _ground_level)
	## The pane's thickness, read from the store (2026-10-10: assuming the impact cell's own voxel put the strips one voxel off):
	## the cross cells around the impact that hold a pane voxel.
	var cross_i: int = cell.y if run_is_x else cell.x
	var t_lo: int = cross_i
	var t_hi: int = cross_i
	var store: VoxelStore = VoxelStore.active
	if store != null:
		var found: Array = []
		for d: int in [-1, 0, 1]:
			var cx: int = cell.x if run_is_x else cross_i + d
			var cy: int = cross_i + d if run_is_x else cell.y
			if store.has_glass_pane(cx, cy, lvl_abs):
				found.append(cross_i + d)
		if not found.is_empty():
			t_lo = found.min()
			t_hi = found.max()
	var lift: float = FACE_LIFT_VOXELS
	## A point (run, height, across) in voxel units -> the geometry root's space.
	var at := func(r: float, h: float, t: float) -> Vector3:
		return (Vector3(r, h, t) if run_is_x else Vector3(t, h, r)) * _unit
	var uv := func(off: Vector2) -> Vector2: return Vector2(off.x / span.x + 0.5, 0.5 - off.y / span.y)
	## An offset `o` of the crack is the point run_c + 0.5 + o (the impact voxel's centre is 0). `crack_pane_lo/hi` come two ways: a
	## whole number is a border CELL's centre (an impact crack), a half one is already the pane's EDGE (a craze field: -23.5 / 24.5,
	## measured 2026-10-10 — taking it for a centre put every strip half a voxel outside the pane). Either way, to the edge.
	var edge_lo := func(v: float) -> float: return v - 0.5 if is_equal_approx(v, roundf(v)) else v
	var edge_hi := func(v: float) -> float: return v + 0.5 if is_equal_approx(v, roundf(v)) else v
	var r0: float = run_c + 0.5 + float(edge_lo.call(lo.x))
	var r1: float = run_c + 0.5 + float(edge_hi.call(hi.x))
	var h0: float = lvl_c + 0.5 + float(edge_lo.call(lo.y))
	var h1: float = lvl_c + 0.5 + float(edge_hi.call(hi.y))
	var t0: float = float(t_lo)
	var t1: float = float(t_hi + 1)
	var depth: float = t1 - t0
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var tone: Array = [STRIP_TONE_TOP]
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
		var base: int = verts.size()
		verts.append_array([a, b, c, d])
		uvs.append_array([ua, ub, uc, ud])
		for _k: int in range(4):
			cols.append(Color(float(tone[0]), 1, 1, 1))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	## The DECAL itself on each edge, not a border line stretched (Director, 2026-10-10): the face's band just inside that border,
	## as deep as the pane is thick, folded over the corner — so the edge shows the crack's real texture, continuous at the corner.
	## Top / bottom: along the run; across the thickness the level runs inward from the border.
	## (Offsets stay inside the crack's pane clip, `crack_pane_lo/hi`, which are the border cells' CENTRES.)
	var fy0: float = hi.y
	var fy1: float = hi.y - depth
	quad.call(at.call(r0, h1 + lift, t1), at.call(r1, h1 + lift, t1), at.call(r1, h1 + lift, t0), at.call(r0, h1 + lift, t0),
		uv.call(Vector2(lo.x, fy0)), uv.call(Vector2(hi.x, fy0)), uv.call(Vector2(hi.x, fy1)), uv.call(Vector2(lo.x, fy1)))
	tone[0] = STRIP_TONE_BOTTOM
	var by0: float = lo.y
	var by1: float = lo.y + depth
	quad.call(at.call(r0, h0 - lift, t1), at.call(r1, h0 - lift, t1), at.call(r1, h0 - lift, t0), at.call(r0, h0 - lift, t0),
		uv.call(Vector2(lo.x, by0)), uv.call(Vector2(hi.x, by0)), uv.call(Vector2(hi.x, by1)), uv.call(Vector2(lo.x, by1)))
	## The two ends: up the height; across the thickness the run goes inward from the end.
	tone[0] = STRIP_TONE_END
	var ex0: float = hi.x
	var ex1: float = hi.x - depth
	quad.call(at.call(r1 + lift, h1, t1), at.call(r1 + lift, h1, t0), at.call(r1 + lift, h0, t0), at.call(r1 + lift, h0, t1),
		uv.call(Vector2(ex0, hi.y)), uv.call(Vector2(ex1, hi.y)), uv.call(Vector2(ex1, lo.y)), uv.call(Vector2(ex0, lo.y)))
	var sx0: float = lo.x
	var sx1: float = lo.x + depth
	quad.call(at.call(r0 - lift, h1, t1), at.call(r0 - lift, h1, t0), at.call(r0 - lift, h0, t0), at.call(r0 - lift, h0, t1),
		uv.call(Vector2(sx0, hi.y)), uv.call(Vector2(sx1, hi.y)), uv.call(Vector2(sx1, lo.y)), uv.call(Vector2(sx0, lo.y)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Strips"
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Centre and basis of the quad, in the geometry root's local space.
func _placement(rec: Dictionary) -> Transform3D:
	var cell: Vector2i = rec["impact_cell"]
	var face: int = int(rec.get("face", Face.SW))
	var run_axis: int = int(rec["run_axis"])
	var lift: float = FACE_LIFT_VOXELS
	var x: float = float(cell.x) + 0.5
	var z: float = float(cell.y) + 0.5
	## Each face stands on its own edge of the voxel: SW and SE are the near ones (+Z, +X),
	## NE and NW the far ones (-Z, -X); a far face's lift goes the other way.
	match face:
		Face.SW: z = float(cell.y) + 1.0 + lift
		Face.SE: x = float(cell.x) + 1.0 + lift
		Face.NE: z = float(cell.y) - lift
		Face.NW: x = float(cell.x) - lift
	var y: float = float(int(rec["impact_level"]) - _ground_level) + 0.5
	var run_dir: Vector3 = Vector3.RIGHT if run_axis == 0 else Vector3.BACK
	var basis := Basis(run_dir, Vector3.UP, run_dir.cross(Vector3.UP))
	return Transform3D(basis, Vector3(x, y, z) * _unit)


## Only writes what changed: this runs every frame per crack.
func _mirror(twin: Dictionary) -> void:
	var rec: Dictionary = twin["rec"]
	var mesh: MeshInstance3D = twin["mesh"]
	mesh.visible = bool(rec.get("visible", true))
	var src: Dictionary = rec["params"]
	var mat: ShaderMaterial = twin["mat"]
	for param: String in MIRRORED:
		var value: Variant = src.get(param)
		if value != null and mat.get_shader_parameter(param) != value:
			mat.set_shader_parameter(param, value)


## The applied openings as pane cuts. Rebuilt only when the renderer's log grew (or was cleared by a
## reload); the masks are rasterised in one common frame so a single Texture2DArray serves them all.
func _sync_openings() -> void:
	var recs: Array = _renderer.glass_applied_openings()
	if recs.size() == _open_seen or pane_materials.is_empty():
		return
	_open_seen = recs.size()
	var used: Array = recs.slice(maxi(0, recs.size() - OPEN_MAX))
	if recs.size() > OPEN_MAX:
		push_warning("[GlassCrackMirror3D] %d applied openings, the pane shader cuts the last %d" % [recs.size(), OPEN_MAX])
	var half: float = 1.0
	var polys: Array = []
	for rec: Dictionary in used:
		var poly: PackedVector2Array = GlassOpening.polygon(String(rec["opening"]))
		polys.append(poly)
		for pt: Vector2 in poly:
			half = maxf(half, maxf(absf(pt.x), absf(pt.y)))
	half = ceilf(half + 0.25)
	var n: int = int(half * 2.0) * OPEN_TEXELS_PER_VOXEL
	var images: Array[Image] = []
	var params := PackedVector4Array()
	params.resize(OPEN_MAX)
	for i: int in range(used.size()):
		var rec: Dictionary = used[i]
		var a: Vector3i = rec["anchor"]
		params[i] = Vector4(float(a.x), float(a.y), float(a.z), 1.0 if bool(rec["run_is_x"]) else 0.0)
		var img := Image.create(n, n, false, Image.FORMAT_R8)
		var poly: PackedVector2Array = polys[i]
		if not poly.is_empty():
			for y: int in range(n):
				for x: int in range(n):
					var p := Vector2(-half + (float(x) + 0.5) / float(n) * 2.0 * half,
						half - (float(y) + 0.5) / float(n) * 2.0 * half)
					if Geometry2D.is_point_in_polygon(p, poly):
						img.set_pixel(x, y, Color(1.0, 0.0, 0.0))
		images.append(img)
	var array := Texture2DArray.new()
	if not images.is_empty():
		var err: int = array.create_from_images(images)
		if err != OK:
			push_error("[GlassCrackMirror3D] opening masks: create_from_images failed (%s)" % error_string(err))
			return
	for m: ShaderMaterial in pane_materials:
		m.set_shader_parameter("open_a", params)
		m.set_shader_parameter("open_half", half)
		m.set_shader_parameter("open_masks", array)
		m.set_shader_parameter("open_count", images.size())
		m.set_shader_parameter("mesh_ground_level", _ground_level)
