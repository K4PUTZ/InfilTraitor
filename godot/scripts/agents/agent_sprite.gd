## CHARACTER_MASTER_PLAN Part 2 §10 — the baked figure ON the playable agent.
##
## This is the node that closes Part 2. `AgentProbeProp` put the figure in the
## room to be LOOKED at; this one puts it on the thing the player moves, which is
## the difference §10 draws between "the pipeline works" and done.
##
## It is a child of `DebugAgent` rather than a replacement for it, because the
## agent is a Node2D that owns grid state, tweening and signals, and none of that
## wants to become a Sprite2D. The agent keeps position; this keeps appearance.
##
## --- FOUR THINGS IT DOES THAT THE PROBE DOES NOT ---
##
## 1. THREE POSTURES, EACH ITS OWN BAKE WITH ITS OWN ANCHOR. The placeholder it
##    replaces drew three shapes; a single standing sprite would have been a
##    regression, not a swap. The anchors are NOT shared: the bake recentres each
##    model on its own AABB, so the pixel its feet land on differs per posture
##    (standing 227.99, crouch 184.00, prone 156.74 — measured, and read from each
##    posture's own anchor.json rather than transcribed).
##
## 2. FACING, SNAPPED AT THE GU BOUNDARY (D47). Ordinary movement changes facing
##    with no transition frames — the Director judged that blind on 2026-08-15,
##    and it is the row that keeps the art budget at 744 body sets instead of
##    4608. So the facing is set once per step, from the step's own direction,
##    and nothing interpolates.
##
## 3. FACING IS STORED IN BASE SPACE, NOT VIEW SPACE. A perspective flip rotates
##    the room; an agent facing a wall must still face that wall afterwards. The
##    cell round-trip through `_cell_to_base` already exists for exactly this
##    reason and the facing has to make the same trip, or the figure would
##    silently turn 90 degrees every time the Director rotated the view.
##
## 4. POSTURE FRAME SETS LOAD ON FIRST USE. D42 names RAM, not CPU, as this
##    character's binding constraint. A session where the agent never goes prone
##    should not pay for the prone bake.
##
## Everything else — the relight shader, the perspective-aware light mapping
## (D22), the ground-contact anchoring, the raw-PNG loader — is `AgentProbeProp`'s
## behaviour, and the duplication between the two files is real and known. The
## probe stays the single-pose bracket rig it was built as; this is the shipping
## path.
class_name AgentSprite
extends Sprite2D

const FRAMES_ROOT := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"
## The same three postures with only the `joint` material recoloured. Two bakes
## rather than a shader tint because the shader has no channel that says "this
## pixel is a joint" — and the joints kept their own material through the
## near-black pass precisely so this variant would be one env var away
## (p1_agent_model.py, P1_JOINTS_YELLOW=1).
const FRAMES_ROOT_DEV := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_dev/"
## The walk cycle, one directory per phase. ONE CYCLE PER GU is derived rather
## than chosen (p3_walk_export.py): a full cycle is two footfalls, a ~1.9 m
## figure's footfall is ~0.80 m, and a GU is 1.60 m exactly — so the foot plants
## on the tile boundary, every tile. That is also why the phase can be read
## straight off the step's progress with no accumulator to drift.
const WALK_ROOT := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_walk/"
const WALK_PHASES := 8
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"
const DIRECTIONS := ["N", "E", "S", "W"]
const YAW_BY_DIRECTION := {"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}

## The bake writes one directory per posture; these are `p3_posture_export.py`'s
## own names. The keys are DebugAgent.Posture values, but this file deliberately
## does not import agent.gd — the caller maps its enum to a name, which keeps the
## dependency one-way.
const POSTURE_DIRS := {"standing": "standing", "crouch": "crouch", "prone": "prone"}

## The grid step that produces each facing. The four baked yaws come out as the
## diamond's EDGES (NE/SE/SW/NW measured, not asserted — p2_grip_spike.py's
## measure_facings loud-fails if they ever come out as the vertices instead), and
## the edges are the grid axes, which is exactly the set of directions a
## tile-stepping character can walk in. So this mapping is total: every legal
## step has a baked frame, and no step falls between two.
const FACING_BY_STEP := {
	Vector2i(0, -1): "N",
	Vector2i(1, 0): "E",
	Vector2i(0, 1): "S",
	Vector2i(-1, 0): "W",
}

## Derived, not tuned: the bake pins one texel to one screen pixel (a 0.20 m rise
## measured 20.000 px against VOXEL_STEP_PX), so any scale but 1.0 breaks it.
const SPRITE_SCALE := 1.0

## The suit is near-black and matte. Specular is OUT for this character, not
## merely low — Director, 2026-08-16: *"tecido não tem reflexo duro, somente
## manchas opacas"*. These are AgentProbeProp's ratified values.
const SPECULAR_STRENGTH := 0.0
const AMBIENT := 0.42
const SATURATION := 1.25
const CONTRAST := 1.12
const LIGHT_INTENSITY_SCALE := 0.60
const LIGHT_INTENSITY_MAX := 1.30

## Must match agent_frame_bake_spike.gd — D26: a different angle breaks the light
## maths silently.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

var room: Node = null

## The agent's facing in BASE space — see note 3. Starts N, which is what the
## placeholder implicitly was.
var _base_facing: String = "N"
var _posture: String = "standing"
var _dev_vision: bool = false
var _walk_ready: bool = false
## -1 when standing still. Any other value is an index into the walk cycle, and
## the sprite shows that phase instead of the posture's idle frame.
var _walk_phase: int = -1

## "<posture>" / "<posture>:dev" -> {"color": {dir: Texture}, "normal": {...},
## "anchor": Vector2}. Keyed with the dev flag rather than held in a second
## dictionary so that "which frames am I showing" is one lookup and cannot
## disagree with itself.
var _sets: Dictionary = {}
var _material: ShaderMaterial

var _cam_right := Vector3.ZERO
var _cam_up := Vector3.ZERO
var _cam_toward_viewer := Vector3.ZERO


func _init() -> void:
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var to_camera := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev)).normalized()
	var forward := -to_camera
	_cam_right = forward.cross(Vector3.UP).normalized()
	_cam_up = _cam_right.cross(forward).normalized()
	_cam_toward_viewer = to_camera


func setup(p_room: Node) -> bool:
	room = p_room
	centered = false
	scale = Vector2.ONE * SPRITE_SCALE

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	## Opt in explicitly: this shader is SHARED with the grenade and every weapon,
	## so relying on its defaults would restyle all of them the day one is tuned.
	_material.set_shader_parameter("specular_strength", SPECULAR_STRENGTH)
	_material.set_shader_parameter("ambient", AMBIENT)
	_material.set_shader_parameter("saturation", SATURATION)
	_material.set_shader_parameter("contrast", CONTRAST)
	_material.set_shader_parameter("outline_width", 0.0)
	material = _material

	if not _ensure_posture("standing"):
		return false
	_refresh()
	set_process(true)
	return true


## Called by the agent when its posture changes. Takes a NAME, not the enum —
## see POSTURE_DIRS.
func set_posture_name(name: String) -> void:
	if name == _posture:
		return
	if not _ensure_posture(name, _dev_vision):
		return
	_posture = name
	_refresh()


## D47's snap. `step` is the grid delta the agent is about to walk, in VIEW
## space; it is converted to base space so a later perspective flip preserves it.
func face_step(step: Vector2i) -> void:
	if not FACING_BY_STEP.has(step):
		return
	var view_facing: String = FACING_BY_STEP[step]
	_base_facing = _compose(view_facing, _inverse_perspective())
	_refresh()


## Follows room.gd's _set_view_mode("dev"), the same toggle every other dev
## overlay uses. Loaded on FIRST enable and never at setup — a normal session has
## no business paying RAM for a debug bake, and D42 names RAM as this character's
## binding constraint.
func set_dev_vision(enabled: bool) -> void:
	if enabled == _dev_vision:
		return
	if enabled and not _ensure_posture(_posture, true):
		return
	_dev_vision = enabled
	_refresh()


## Called on a perspective flip and on every step, alongside the agent's own
## reposition. z_index is left alone: this is a CHILD of the agent, and the agent
## owns OCC-03's always-on-top policy.
func update_for_cell() -> void:
	_refresh()


func _set_key(name: String, dev: bool) -> String:
	return name + (":dev" if dev else "")


func _ensure_posture(name: String, dev: bool = false) -> bool:
	if not POSTURE_DIRS.has(name):
		push_error("[AgentSprite] unknown posture '%s' — expected one of %s" % [name, POSTURE_DIRS.keys()])
		return false
	return _ensure_set(_set_key(name, dev),
		(FRAMES_ROOT_DEV if dev else FRAMES_ROOT) + String(POSTURE_DIRS[name]) + "/")


## Every walk phase at once. Loaded on the FIRST step rather than at setup, and
## then kept: the agent walks constantly, so the second load would be pure churn,
## but a scene that never moves him should not pay for 8 phases x 4 facings.
func _ensure_walk() -> bool:
	if _walk_ready:
		return true
	for i in range(WALK_PHASES):
		if not _ensure_set(_walk_key(i), WALK_ROOT + "phase%02d/" % i):
			return false
	_walk_ready = true
	return true


func _walk_key(phase_index: int) -> String:
	return "walk%02d" % phase_index


func _ensure_set(key: String, dir: String) -> bool:
	if _sets.has(key):
		return true
	var anchor := _load_anchor(dir)
	if anchor == Vector2.ZERO:
		return false
	var colors := {}
	var normals := {}
	for direction: String in DIRECTIONS:
		var c := _load_texture_raw("%sframe_%s_color.png" % [dir, direction])
		var n := _load_texture_raw("%sframe_%s_normal.png" % [dir, direction])
		if c == null or n == null:
			push_error("[AgentSprite] frame set '%s' is missing direction %s in %s — run the matching p3_*_export.py then agent_frame_bake_spike.gd" % [key, direction, dir])
			return false
		colors[direction] = c
		normals[direction] = n
	_sets[key] = {"color": colors, "normal": normals, "anchor": anchor}
	return true


## Each posture's own anchor, read from the bake rather than transcribed from its
## printout — the one-number-in-two-places mistake AgentProbeProp's header calls
## out, and it matters more here because there are now three of them.
##
## Vector2.ZERO is the failure sentinel, which is safe rather than lazy and is
## the bake's OWN convention (`agent_frame_bake_spike.gd::_init` quits on exactly
## this value): the anchor is the projection of the figure's feet through a
## camera aimed at the model, so it lands near the middle-bottom of the frame —
## 227.99, 184.00 and 156.74 for the three postures. The frame's top-left corner
## is not a value it can legitimately take.
func _load_anchor(dir: String) -> Vector2:
	var path := dir + "anchor.json"
	if not FileAccess.file_exists(path):
		push_error("[AgentSprite] %s missing — run agent_frame_bake_spike.gd for this posture" % path)
		return Vector2.ZERO
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("anchor_px"):
		push_error("[AgentSprite] %s is not a bake anchor file" % path)
		return Vector2.ZERO
	var a: Array = parsed["anchor_px"]
	return Vector2(float(a[0]), float(a[1]))


## The room's perspective, as the compass name whose yaw undoes it.
func _inverse_perspective() -> String:
	if room == null:
		return "N"
	return String(room._active_perspective)


## Compose two compass directions by adding their yaws, cyclically. §4.6 defines
## what reaches the screen as `facing - perspective`; storing the base facing and
## re-composing on every refresh is the same relationship read the other way.
func _compose(a: String, b: String) -> String:
	var yaw: float = float(YAW_BY_DIRECTION.get(a, 0.0)) - float(YAW_BY_DIRECTION.get(b, 0.0))
	for d: String in DIRECTIONS:
		if is_equal_approx(fposmod(float(YAW_BY_DIRECTION[d]) - yaw, 360.0), 0.0):
			return d
	return "N"


## `progress01` is how far through the CURRENT GU the agent is, 0 to 1. Because
## one cycle is one GU exactly, that is also the cycle phase — no accumulator, so
## nothing can drift out of step over a long path.
##
## The walk exists for STANDING only. A crouched or prone agent showing a walking
## silhouette would be worse than a sliding one, so those keep their idle frame
## and slide; crouch-walk and crawl are their own poses and are not built.
func set_walk_phase(progress01: float) -> void:
	if _posture != "standing":
		return
	if not _ensure_walk():
		return
	var index := int(floor(fposmod(progress01, 1.0) * float(WALK_PHASES))) % WALK_PHASES
	if index == _walk_phase:
		return
	_walk_phase = index
	_refresh()


## Back to the posture's idle frame. Called when a move finishes.
func stop_walking() -> void:
	if _walk_phase == -1:
		return
	_walk_phase = -1
	_refresh()


func _refresh() -> void:
	if _walk_phase >= 0 and _posture == "standing":
		## The walk has no DEV VISION bake — the joint tint is a debug aid and
		## losing it for the duration of a step is better than not shipping the
		## cycle. Stated rather than silent, because a dev overlay that flickers
		## off during motion looks like a bug in the overlay.
		var walk_entry: Dictionary = _sets.get(_walk_key(_walk_phase), {})
		if not walk_entry.is_empty():
			_apply(walk_entry)
			return
	var entry: Dictionary = _sets.get(_set_key(_posture, _dev_vision), {})
	if not entry.is_empty():
		_apply(entry)


## Show one frame set at the current facing. The ANCHOR comes from the set, not
## from the sprite: the bake recentres every model on its own AABB, so a walk
## that bobs 6 px has a different feet-pixel per phase (228.17 / 226.81 / 225.18
## …). Reusing one anchor across the cycle would cancel the bob exactly.
func _apply(entry: Dictionary) -> void:
	var view_facing := _compose(_base_facing, _inverse_perspective())
	var colors: Dictionary = entry["color"]
	if not colors.has(view_facing):
		return
	texture = colors[view_facing]
	offset = -(entry["anchor"] as Vector2)
	if _material != null:
		_material.set_shader_parameter("normal_tex", (entry["normal"] as Dictionary)[view_facing])


func _process(_delta: float) -> void:
	_update_light_uniform()


## Verbatim in behaviour from AgentProbeProp/GrenadeProp (D22's fix): de-rotate
## both cells to the base (North) orientation before applying the grid -> world
## mapping, because the bake camera's fixed azimuth was derived against a
## canonical N view.
func _update_light_uniform() -> void:
	if room == null or room._lighting_controller == null or _material == null:
		return
	var registry = room._lighting_controller.get_light_registry()
	if registry == null:
		return

	var agent_cell: Vector2i = (get_parent() as Node2D).get("cell")
	var best_light = null
	var best_energy := -1.0
	for light in registry.get_active_lights():
		if not light.affects_cell(agent_cell):
			continue
		var energy: float = light.get_effective_tactical_energy()
		if energy > best_energy:
			best_energy = energy
			best_light = light

	if best_light == null:
		_material.set_shader_parameter("light_intensity", 0.0)
		return

	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	var base_light_cell: Vector2i = room._cell_to_base(best_light.cell, room._active_perspective, base_size)
	var base_agent_cell: Vector2i = room._cell_to_base(agent_cell, room._active_perspective, base_size)
	var grid_delta: Vector2i = base_light_cell - base_agent_cell
	var light_dir_world := Vector3(float(grid_delta.x), 0.0, float(grid_delta.y)).normalized()
	if grid_delta == Vector2i.ZERO:
		light_dir_world = _cam_toward_viewer

	var light_dir_view := Vector3(
		light_dir_world.dot(_cam_right),
		light_dir_world.dot(_cam_up),
		light_dir_world.dot(_cam_toward_viewer)
	).normalized()

	_material.set_shader_parameter("light_dir", light_dir_view)
	_material.set_shader_parameter("light_intensity",
		clampf(best_energy * LIGHT_INTENSITY_SCALE, 0.0, LIGHT_INTENSITY_MAX))


## CLI-baked PNGs never went through the editor's import scan, so plain load()
## fails with "No loader found". Same fix floating_collectible.gd uses.
static func _load_texture_raw(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("[AgentSprite] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
