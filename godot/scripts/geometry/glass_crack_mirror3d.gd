## GlassCrackMirror3D — the 3D board's twin of every live `GlassCrackSprite`.
##
## RENDER3D R3D-6 item 2 (moved here from R3D-4e-4b). Under `RENDER3D=1` the 2D crack sprites are
## still created — by `VoxelRenderer.spawn_glass_crack()` / `spawn_glass_craze()`, with the
## occupancy cut and the opening void built by the code that already owns them — but they hang
## off the hidden 2D renderer and draw nothing. This node reads those records and gives each one
## a quad on the pane's plane in the 3D world, copying the sprite's shader parameters every frame
## (the same mirror `ActorBillboard3D` is to `AgentSprite`). Nothing here decides a crack.
##
## PLACEMENT. The record says which voxel the crack is centred on (`impact_cell`, `impact_level`,
## `face`), which way the pane runs (`run_axis`: 0 = along X, 1 = along Z) and how large the sheet
## is (`crack_span`, in voxels). The quad is that many voxels wide and tall, centred on the
## impact voxel, standing on the face's own plane, and carries the sprite's UV so the shader's
## `off` is the same run/level offset it is in 2D.
class_name GlassCrackMirror3D
extends Node3D

const SHADER_PATH: String = "res://godot/shaders/glass_crack3d.gdshader"

## The sprite's uniforms, copied verbatim.
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
## crack record id -> {"mesh": MeshInstance3D, "mat": ShaderMaterial, "sprite": GlassCrackSprite}
var _twins: Dictionary = {}


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
	var live: Dictionary = {}
	for rec: Dictionary in _renderer.glass_crack_records():
		var sprite: Node = rec.get("sprite") as Node
		if sprite == null or not is_instance_valid(sprite):
			continue
		var id: int = int(rec["id"])
		live[id] = true
		var twin: Dictionary = _twins.get(id, {})
		if twin.is_empty():
			twin = _make_twin(rec, sprite as Sprite2D)
			_twins[id] = twin
		_mirror(twin)
	for id: int in _twins.keys():
		if not live.has(id):
			(_twins[id]["mesh"] as MeshInstance3D).queue_free()
			_twins.erase(id)


func twin_count() -> int:
	return _twins.size()


func _make_twin(rec: Dictionary, sprite: Sprite2D) -> Dictionary:
	var src := sprite.material as ShaderMaterial
	var span: Vector2 = src.get_shader_parameter("crack_span") if src != null else Vector2(8.0, 8.0)
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
	return {"mesh": mesh, "mat": mat, "sprite": sprite}


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
	var sprite: Sprite2D = twin["sprite"]
	var mesh: MeshInstance3D = twin["mesh"]
	mesh.visible = sprite.visible
	var src := sprite.material as ShaderMaterial
	if src == null:
		return
	var mat: ShaderMaterial = twin["mat"]
	for param: String in MIRRORED:
		var value: Variant = src.get_shader_parameter(param)
		if value != null and mat.get_shader_parameter(param) != value:
			mat.set_shader_parameter(param, value)
