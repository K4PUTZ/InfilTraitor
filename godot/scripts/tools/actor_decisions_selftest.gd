## actor_decisions_selftest — R3D-ACTORS: what `AgentSprite` decides for the live mesh, and how `ActorMesh3D` turns a
## facing into a yaw. The rendering is checked by capture; this pins the decisions a capture cannot see: the one-time
## `throw_released` (a release that never fires hangs `execute_grenade_throw()`), the cancel firing nothing, D44's
## reduction of a diagonal, the names the rig has no action for being refused, and the rig's front being its local -Z.
extends SceneTree

const AgentSpriteRef = preload("res://godot/scripts/agents/agent_sprite.gd")
const ActorMesh3DRef = preload("res://godot/scripts/geometry/actor_mesh3d.gd")
const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")

var _fails: int = 0
var _released: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ACTOR-DECISIONS SELFTEST")
	print("=".repeat(70) + "\n")
	_test_defaults()
	_test_facing()
	_test_refusals()
	_test_release_fires_once()
	_test_cancel_fires_nothing()
	_test_walk()
	_test_yaw_faces_the_step()
	_test_lattice_basis_is_the_n_camera()
	print("")
	if _fails == 0:
		print("[ACTOR-DECISIONS] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[ACTOR-DECISIONS] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[ACTOR-DECISIONS] ✅ %s" % label)
	else:
		print("[ACTOR-DECISIONS] ❌ %s" % label)
		_fails += 1


func _sprite() -> AgentSprite:
	var s: AgentSprite = AgentSpriteRef.new()
	s.setup(null)
	return s


func _test_defaults() -> void:
	var s := _sprite()
	var st: Dictionary = s.mesh_state()
	_check(st["step"] == AgentSpriteRef.START_STEP and st["posture"] == "standing" and st["throw"] == ""
		and float(st["walk"]) < 0.0 and is_nan(float(st["head"])),
		"a new figure stands, idle, facing its start step, no head turn (%s)" % st)
	s.free()


func _test_facing() -> void:
	var s := _sprite()
	s.face_direction(Vector2i(3, -1))
	_check(s.mesh_state()["step"] == Vector2i(1, 0), "a diagonal reduces to its dominant axis (3,-1) -> (1,0)")
	s.face_direction(Vector2i(1, -2))
	_check(s.mesh_state()["step"] == Vector2i(0, -1), "(1,-2) -> (0,-1)")
	s.face_direction(Vector2i.ZERO)
	_check(s.mesh_state()["step"] == Vector2i(0, -1), "a zero direction leaves the facing alone")
	s.free()


func _test_refusals() -> void:
	var s := _sprite()
	_check(not s.set_weapon_bake("_rifle") and s.weapon == "", "the rifle (no grip in the rig) is refused, the shotgun kept")
	_check(s.set_weapon_bake("_pistol") and s.weapon == "_pistol", "the pistol is held")
	s.set_grip("_ready")
	_check(s.grip == "", "a grip the rig has no action for is refused")
	s.set_grip("_aimed")
	_check(s.grip == "_aimed", "the aimed grip is taken")
	s.set_posture_name("crouch")
	_check(not s.play_throw(AgentSpriteRef.THROW_RAISE, 0.2, true), "no crouched throw (standing only, as the bake was)")
	s.free()


func _on_released() -> void:
	_released += 1


func _test_release_fires_once() -> void:
	var s := _sprite()
	_released = 0
	s.throw_released.connect(_on_released)
	_check(s.play_throw(AgentSpriteRef.THROW_RELEASE, 0.4), "a standing release starts")
	var fired_at: float = -1.0
	var t: float = 0.0
	for _i in range(6):
		s._process(0.1)
		t += 0.1
		if _released == 1 and fired_at < 0.0:
			fired_at = t
	_check(_released == 1, "throw_released fired exactly once (%d)" % _released)
	_check(absf(fired_at - 0.2) < 0.001, "at the release fraction: 0.2 s of 0.4 (%.2f)" % fired_at)
	_check(s.mesh_state()["throw"] == "", "the sequence ended")
	s.free()


func _test_cancel_fires_nothing() -> void:
	var s := _sprite()
	_released = 0
	s.throw_released.connect(_on_released)
	s.play_throw(AgentSpriteRef.THROW_RAISE, 0.2, false, true)
	s._process(0.05)
	var u: float = float(s.mesh_state()["throw_u"])
	_check(absf(u - 0.75) < 0.001, "the cancel plays the raise backwards (u %.2f after a quarter)" % u)
	for _i in range(5):
		s._process(0.05)
	_check(_released == 0 and s.mesh_state()["throw"] == "", "a cancel fires nothing and ends")
	s.free()


func _test_walk() -> void:
	var s := _sprite()
	s.set_walk_phase(1.25)
	_check(absf(float(s.mesh_state()["walk"]) - 0.25) < 0.001, "the walk is the GU progress, wrapped (1.25 -> 0.25)")
	s.stop_walking()
	_check(float(s.mesh_state()["walk"]) < 0.0, "stopping ends the walk")
	s.set_posture_name("prone")
	s.set_walk_phase(0.5)
	_check(float(s.mesh_state()["walk"]) < 0.0, "a prone figure does not walk (it slides)")
	s.free()


## The rig's front is its local -Z (the toes and the knee pole, read from the GLB). The yaw for a grid step must turn
## that front onto the step's world direction: grid x is world +X, grid y world +Z.
func _test_yaw_faces_the_step() -> void:
	for step: Vector2i in AgentSpriteRef.STEPS:
		var yaw: float = ActorMesh3DRef.yaw_for_direction(Vector2(step))
		var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -1.0)
		_check(front.is_equal_approx(Vector3(float(step.x), 0.0, float(step.y))),
			"step %s: the front points along it (%s)" % [step, front])


## R3D-WORLD: a 2D-lattice displacement becomes a world one through `Board3DLive.lattice_basis()`. It must be EXACTLY the
## camera the board builds for view N (`_make_camera()`: rotation_degrees (-30, 45 + 0, 0)), or every VFX and lifted overlay
## moves in view N, the one view that was supposed not to change.
func _test_lattice_basis_is_the_n_camera() -> void:
	var cam := Node3D.new()
	cam.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	var lattice: Basis = ParticleMathRef.lattice_basis()
	_check(lattice.is_equal_approx(cam.transform.basis), "lattice_basis() is the view-N camera's basis")
	cam.free()
