## ShellCasings3D — the spent cases a firearm throws out (MOVEMENT, 2026-11-12).
##
## One per board, a child of it (board-local space, the space `Board3DLive.stand_height` answers in), made on the first shot (`of()`). A case is
## thrown from the gun's ejection port, up and to the shooter's right, spinning; it falls under gravity, bounces on what is under it (`stand_height`:
## the floor, a crater's bed, a crust) a couple of times, slides to a stop and STAYS, lying on its side. Every case, flying or lying, is one instance of
## a single `MultiMeshInstance3D` (one draw call; a lying case costs its 48-byte transform and nothing per frame). At `max_lying` the oldest is
## reused. The cases live as long as the board: a map load drops them (the checkpoint is HERITAGE T5's, built later).
##
## The physics is in METRES scaled to board units by the shooter (`units_per_m`, from the gun's own size), so a case falls at the figure's scale.
class_name ShellCasings3D
extends MultiMeshInstance3D

const NODE_NAME := "ShellCasings"
const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const BRASS := Color(0.78, 0.6, 0.26)

## Stats are `var` (rule 1). A real 9 mm case is 19 x 10 mm; drawn larger, or it is invisible at the game's zoom.
var case_length_m: float = 0.03
var case_radius_m: float = 0.008
var gravity_m: float = 9.8
var restitution: float = 0.35       ## of the vertical speed, per bounce
var friction: float = 0.55          ## of the horizontal speed kept per bounce
var rest_speed_m: float = 0.25      ## a bounce slower than this ends the flight
var max_lying: int = 256

var _flying: Array = []            ## [{slot, pos, vel, spin_axis, spin, angle, upm, bounces}]
var _count: int = 0                ## slots in use (lying + flying)
var _next: int = 0                 ## the slot the next case takes (wraps at max_lying: the oldest goes)
var _board: Node3D = null


## The board's casings, made on first use.
static func of(board: Node3D) -> MultiMeshInstance3D:
	var found := board.get_node_or_null(NODE_NAME) as MultiMeshInstance3D
	if found != null:
		return found
	var made = load("res://godot/scripts/geometry/shell_casings3d.gd").new()
	made.name = NODE_NAME
	made._board = board
	made._build()
	board.add_child(made)
	return made


func _build() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 0
	var sm := ShaderMaterial.new()
	sm.shader = BoardLook.graded_shader(SHADER_PATH)
	sm.set_shader_parameter("albedo", BRASS)
	sm.set_shader_parameter("sheen", 0.6)
	if _board.has_method("register_prop_light_material"):
		_board.call("register_prop_light_material", sm)
	cyl.material = sm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = max_lying
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A case leaves the port at `pos` (board-local) with `vel_m` (metres/s, board axes), at `units_per_m` board units per metre.
func eject(pos: Vector3, vel_m: Vector3, units_per_m: float) -> void:
	var slot: int = _next
	_next = (_next + 1) % max_lying
	_count = mini(_count + 1, max_lying)
	multimesh.visible_instance_count = _count
	for f: Dictionary in _flying:   ## the oldest lying case was reused while still flying: forget its flight
		if int(f["slot"]) == slot:
			_flying.erase(f)
			break
	var spin_axis := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), randf_range(-1.0, 1.0)).normalized()
	_flying.append({"slot": slot, "pos": pos, "vel": vel_m, "spin_axis": spin_axis, "spin": randf_range(18.0, 30.0),
		"angle": 0.0, "upm": units_per_m, "bounces": 0, "yaw": randf_range(0.0, TAU)})
	_write(_flying[_flying.size() - 1], false)


func _process(delta: float) -> void:
	if _flying.is_empty():
		return
	var landed: Array = []
	for f: Dictionary in _flying:
		var upm: float = float(f["upm"])
		var vel: Vector3 = f["vel"]
		vel.y -= gravity_m * delta
		var pos: Vector3 = (f["pos"] as Vector3) + vel * upm * delta
		f["angle"] = float(f["angle"]) + float(f["spin"]) * delta
		var floor_y: float = float(_board.call("stand_height", pos)) if _board.has_method("stand_height") else 0.0
		var lying_y: float = floor_y + case_radius_m * upm
		if pos.y <= lying_y and vel.y < 0.0:
			pos.y = lying_y
			f["bounces"] = int(f["bounces"]) + 1
			if -vel.y < rest_speed_m or int(f["bounces"]) >= 3:
				f["pos"] = pos
				landed.append(f)
				continue
			vel = Vector3(vel.x * friction, -vel.y * restitution, vel.z * friction)
			f["spin"] = float(f["spin"]) * 0.5
		f["pos"] = pos
		f["vel"] = vel
		_write(f, false)
	for f: Dictionary in landed:
		_write(f, true)
		_flying.erase(f)


## The case's transform: spinning in flight, lying on its side (axis level, a random heading) at rest.
func _write(f: Dictionary, lying: bool) -> void:
	var upm: float = float(f["upm"])
	var size := Vector3(case_radius_m, case_length_m, case_radius_m) * upm   ## the cylinder's axis is its local Y
	var b: Basis
	if lying:
		b = Basis(Vector3.UP, float(f["yaw"])) * Basis(Vector3.FORWARD, PI * 0.5)
	else:
		b = Basis(f["spin_axis"] as Vector3, float(f["angle"]))
	multimesh.set_instance_transform(int(f["slot"]), Transform3D(b.scaled_local(size), f["pos"] as Vector3))
