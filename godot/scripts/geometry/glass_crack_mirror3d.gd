## GlassCrackMirror3D — the 3D board's twin of every live `GlassCrackSprite`.
##
## RENDER3D R3D-6 item 2 (moved here from R3D-4e-4b). `VoxelRenderer.spawn_glass_crack()` / `spawn_glass_craze()` produce
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

## Lifts the quad off the glass so it never z-fights the pane, in voxels.
const FACE_LIFT_VOXELS: float = 0.05

var _renderer: VoxelRenderer = null
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


func setup(renderer: VoxelRenderer, ground_level: int) -> void:
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
	return {"mesh": mesh, "mat": mat, "rec": rec}


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
