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

## ============================================================================
## 🚧 MOVEMENT MILESTONE — Director, 2026-08-16:
##    *"Pode fazer todos os bakes só com a variante DEV por enquanto. Vamos
##    fazer uma milestone só de movimentação, e só depois no final voltamos com
##    o personagem normal."*
##
## While this is true, EVERY frame set resolves to the yellow-joint bake,
## whatever the DEV VISION toggle says. That is deliberate and it is not a
## convenience: baking one variant instead of two halves the cost of every
## iteration, and the joints are the better instrument for judging motion — a
## near-black figure hides its own articulation, which is the whole thing a walk
## has to be judged on.
##
## IT FORCES THE ROUTE RATHER THAN FALLING BACK, and the difference is the point.
## A silent "use dev if normal is missing" would let the normal bakes go STALE
## while still rendering: iterate on the walk, re-bake only dev, and the normal
## set keeps playing the OLD motion until someone flips the toggle weeks later
## and sees animation nobody wrote. Routing everything through one root means the
## normal frames are never shown, so they can never be quietly wrong.
##
## ⚠️ TO END THE MILESTONE: set this to false, then re-run BOTH variants —
##    p3_posture_export.py and p3_walk_export.py with P3_DEV_ONLY=0, each
##    followed by agent_frame_bake_spike.gd on the manifest it writes. The normal
##    bakes on disk are older than the dev ones by construction; do not trust
##    them.
## ============================================================================
## ⏸ SUSPENDED 2026-08-17 for the five items that precede the movement
## milestone. The dev-only rule was there to halve the cost of iterating on
## MOTION; the next three items are weapons, an enemy variant and destruction
## materials, so it buys nothing — and it actively breaks the enemy variant,
## whose whole subject is *"outra aparência e cores"*. Judging an appearance
## through a debug tint is circular. Flip back to `true` when the movement
## milestone opens.
const DEV_ONLY_MILESTONE := false

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
## The walk's yellow-joint variant. It did NOT exist at first, and the gap was
## declared rather than fixed: with DEV VISION on, the joints vanished for the
## duration of every step and came back when the agent stopped, which reads as a
## bug in the overlay rather than as a missing bake. Director, 2026-08-16:
## *"vamos fazer os testes com dev vision ligado para ver as junções amarelas"* —
## the debug mode is only useful if it survives the thing being debugged.
const WALK_ROOT_DEV := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_walk_dev/"
## How many phases the bake actually wrote. COUNTED, never assumed: it was a
## hardcoded 8 and the Director called the result *"engasgado"* — at the ratified
## 560 ms per GU that is one frame every 70 ms, 14.3 Hz, less than half D46's
## 30 Hz. Raising the bake to 32 while a constant here still said 8 would have
## shown three quarters of the new frames to nobody.
var _walk_phases: int = 0
## Bracket-only subsampling; 0 means show every baked phase.
var _walk_quantise: int = 0
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"
const DIRECTIONS := ["N", "E", "S", "W"]
const YAW_BY_DIRECTION := {"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}

## The bake writes one directory per posture; these are `p3_posture_export.py`'s
## own names. The keys are DebugAgent.Posture values, but this file deliberately
## does not import agent.gd — the caller maps its enum to a name, which keeps the
## dependency one-way.
const POSTURE_DIRS := {"standing": "standing", "crouch": "crouch", "prone": "prone"}

## WHICH SCREEN DIRECTION EACH BAKED FRAME FACES. Measured in Blender by
## `p2_grip_spike.measure_facings()`, which projects the figure's own forward
## vector through the real camera at each yaw and loud-fails if the four ever
## come out as the diamond's VERTICES instead of its edges. The bake names its
## frames after the room PERSPECTIVE it renders (yaw 0/90/180/-90 = N/E/S/W), and
## those names are not compass facings of the figure — which is exactly the trap
## below was written to avoid.
const SCREEN_COMPASS_BY_FRAME := {"N": "NE", "E": "NW", "S": "SW", "W": "SE"}

## DIRECTION_GLOSSARY §2/§3 as SCREEN deltas, same table p2_grip_spike.py scores
## against. These are the glossary's own values, NOT unit diagonals: on a 2:1
## diamond a 45-degree world direction draws at 26.57 degrees, so (0.894, -0.447)
## fits NE at 1.000 where (0.707, -0.707) fits at 0.949.
const COMPASS_SCREEN := {
	"NE": Vector2(0.894, -0.447), "SE": Vector2(0.894, 0.447),
	"SW": Vector2(-0.894, 0.447), "NW": Vector2(-0.894, -0.447),
}

const STEPS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Grid step -> baked frame name. DERIVED at setup from the real TileMapLayer,
## never written out by hand.
##
## ⚠️ IT WAS WRITTEN OUT BY HAND FIRST, AND IT WAS WRONG. The hand-written table
## paired step (1,0) with frame "E", reading the frame names as compass
## directions. They are not: frame "E" is the yaw that draws the figure facing
## screen NW, while step (1,0) moves him screen SE — 180 degrees out, which is
## why the Director's first look reported him *"andando de costas"*. Deriving it
## from `map_to_local` makes the table a measurement of the tilemap the game
## actually has, so it cannot disagree with the floor the agent walks on.
var _frame_by_step: Dictionary = {}

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

## Bracket-only, per-family override of the light RESPONSE (never `ambient` —
## that governs the shadow read, which the Director approved as-is for the
## white bracket). The base constants above are tuned so the near-black suit's
## lit facets never clip; a bright suit has far less headroom before clipping
## white, and needs its own response to read as "vivid white on lit facets,
## the current tone in shadow" rather than either flat grey or a blown-out
## sheet. Isolated per family so it touches nothing about the agent's or the
## shipped enemy's own look. Director, 2026-08-17, explicit: "Pode isolar se
## achar necessário."
const LIGHT_RESPONSE_OVERRIDE := {
	"_test_white": {"scale": 1.00, "max": 2.20},
}
var _light_intensity_scale := LIGHT_INTENSITY_SCALE
var _light_intensity_max := LIGHT_INTENSITY_MAX

## Must match agent_frame_bake_spike.gd — D26: a different angle breaks the light
## maths silently.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

## Which baked family this sprite draws from: "" for the agent, "_enemy" for a
## guard. Set BEFORE setup(). It exists because D34's claim — that a faction is a
## colour change and colour is nearly free — is only true if one renderer can be
## pointed at two palettes; a second sprite class per faction would have made the
## claim false by construction.
var frame_family: String = ""

var room: Node = null

## The agent's facing in BASE space — see note 3. Starts N, which is what the
## placeholder implicitly was.
var _base_facing: String = "N"
var _posture: String = "standing"
var _dev_vision: bool = false
## Keyed by the dev flag: the normal and yellow-joint cycles load independently,
## so a session that never opens DEV VISION never pays for its 32 phases.
var _walk_ready: Dictionary = {}
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

	var response: Dictionary = LIGHT_RESPONSE_OVERRIDE.get(frame_family, {})
	_light_intensity_scale = response.get("scale", LIGHT_INTENSITY_SCALE)
	_light_intensity_max = response.get("max", LIGHT_INTENSITY_MAX)

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

	if DEV_ONLY_MILESTONE:
		## Loud on purpose. A build that silently ships a debug-tinted character
		## is a worse outcome than a noisy log during the milestone that asked
		## for it.
		push_warning("[AgentSprite] MOVEMENT MILESTONE: every frame set is the "
			+ "yellow-joint DEV bake. Set DEV_ONLY_MILESTONE=false and re-bake "
			+ "both variants to ship the normal character.")
	if not _ensure_posture("standing"):
		return false
	if not _derive_frame_by_step():
		return false
	_refresh()
	set_process(true)
	return true


## Measure, for each of the four grid steps, which way it actually moves the
## agent ON SCREEN, and pair it with the baked frame that faces that way.
##
## `map_to_local` is the same call `DebugAgent._cell_to_world()` uses to place
## him, so this reads the exact geometry he walks on rather than a remembered
## convention. Loud-fails if two steps resolve to one frame — that would mean the
## tilemap is no longer a 2:1 diamond and every facing in the game is a guess.
func _derive_frame_by_step() -> bool:
	var layer: TileMapLayer = (get_parent() as Node2D).get("floor_layer")
	if layer == null:
		push_error("[AgentSprite] the agent has no floor_layer — cannot derive the step facings")
		return false
	var frame_of_compass := {}
	for frame: String in SCREEN_COMPASS_BY_FRAME:
		frame_of_compass[SCREEN_COMPASS_BY_FRAME[frame]] = frame

	var origin := layer.map_to_local(Vector2i.ZERO)
	_frame_by_step.clear()
	for step: Vector2i in STEPS:
		var delta := (layer.map_to_local(step) - origin).normalized()
		var best := ""
		var best_fit := -2.0
		for compass: String in COMPASS_SCREEN:
			var fit: float = delta.dot((COMPASS_SCREEN[compass] as Vector2).normalized())
			if fit > best_fit:
				best_fit = fit
				best = compass
		_frame_by_step[step] = frame_of_compass[best]
		print_debug("[AgentSprite] step %s draws %s -> screen %s (fit %.3f) -> frame %s" % [
			step, delta, best, best_fit, _frame_by_step[step]])
	if _frame_by_step.values().size() != STEPS.size() \
			or Array(_frame_by_step.values()).duplicate().size() != _dedup(_frame_by_step.values()).size():
		push_error("[AgentSprite] the four grid steps did not resolve to four distinct facings (%s) — the floor is not a 2:1 diamond" % _frame_by_step)
		return false
	return true


static func _dedup(values: Array) -> Array:
	var seen := []
	for v in values:
		if not seen.has(v):
			seen.append(v)
	return seen


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
##
## §4.6 defines what reaches the screen as `facing − perspective`, so going the
## other way is `base = view + perspective`. The first version SUBTRACTED here as
## well as in `_refresh()`, which double-counts: at the default N perspective the
## yaw is 0 and the error is invisible, and it turns the figure the wrong way by
## twice the rotation the moment the Director rotates the room. Invisible in the
## step bracket for exactly that reason — every panel was captured at N.
## Face an arbitrary direction, reduced to the nearest of the four baked ones.
##
## The GUARDS need this and the agent does not: `guard_enemy.gd` snaps its facing
## to EIGHT directions, and D44 fixes the art at FOUR permanently — a diagonal is
## two orthogonal GU steps, which is the ruling that stops the budget growing. So
## a diagonal guard facing has no frame and never will; taking its dominant axis
## is the honest reduction, and doing it here means the rule lives in one place
## instead of in every caller that happens to have an 8-way direction.
func face_direction(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	if absi(dir.x) >= absi(dir.y):
		face_step(Vector2i(signi(dir.x), 0))
	else:
		face_step(Vector2i(0, signi(dir.y)))


func face_step(step: Vector2i) -> void:
	if not _frame_by_step.has(step):
		return
	_base_facing = _compose(String(_frame_by_step[step]), _inverse_perspective(), 1.0)
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
	## A walk already in flight has to swap frame sets too, or the tint only
	## appears once the agent next starts moving.
	if _walk_phase >= 0:
		_ensure_walk(enabled)
	_refresh()


## Called on a perspective flip and on every step, alongside the agent's own
## reposition. z_index is left alone: this is a CHILD of the agent, and the agent
## owns OCC-03's always-on-top policy.
func update_for_cell() -> void:
	_refresh()


func _set_key(name: String, dev: bool) -> String:
	return name + (":dev" if dev else "")


## The single seam the milestone switch acts on. Both roots go through here, so
## there is exactly one place to look when asking "which bake am I seeing".
func _posture_root(dev: bool) -> String:
	if dev or DEV_ONLY_MILESTONE:
		return FRAMES_ROOT_DEV
	return FRAMES_ROOT.trim_suffix("/") + frame_family + "/"


func _walk_root(dev: bool) -> String:
	if dev or DEV_ONLY_MILESTONE:
		return WALK_ROOT_DEV
	return WALK_ROOT.trim_suffix("/") + frame_family + "/"


func _ensure_posture(name: String, dev: bool = false) -> bool:
	if not POSTURE_DIRS.has(name):
		push_error("[AgentSprite] unknown posture '%s' — expected one of %s" % [name, POSTURE_DIRS.keys()])
		return false
	return _ensure_set(_set_key(name, dev),
		_posture_root(dev) + String(POSTURE_DIRS[name]) + "/")


## Every walk phase at once. Loaded on the FIRST step rather than at setup, and
## then kept: the agent walks constantly, so the second load would be pure churn,
## but a scene that never moves him should not pay for 8 phases x 4 facings.
func _ensure_walk(dev: bool) -> bool:
	if _walk_ready.get(dev, false):
		return true
	var root: String = _walk_root(dev)
	if _walk_phases == 0:
		var dir := DirAccess.open(root)
		if dir == null:
			push_error("[AgentSprite] %s missing — run p3_walk_export.py then agent_frame_bake_spike.gd" % root)
			return false
		for name: String in dir.get_directories():
			if name.begins_with("phase"):
				_walk_phases += 1
		if _walk_phases == 0:
			push_error("[AgentSprite] %s holds no phase directories" % root)
			return false
		print_debug("[AgentSprite] walk cycle: %d phases baked" % _walk_phases)
	for i in range(_walk_phases):
		if not _ensure_set(_walk_key(i, dev), root + "phase%02d/" % i):
			return false
	_walk_ready[dev] = true
	return true


func _walk_key(phase_index: int, dev: bool) -> String:
	return "walk%02d%s" % [phase_index, ":dev" if dev else ""]


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


## `a` rotated by `sign * b`, cyclically, as frame names. §4.6 defines what
## reaches the screen as `facing - perspective` (sign −1, the default, used by
## `_refresh`); `face_step` needs the inverse and passes +1.
func _compose(a: String, b: String, sign: float = -1.0) -> String:
	var yaw: float = float(YAW_BY_DIRECTION.get(a, 0.0)) + sign * float(YAW_BY_DIRECTION.get(b, 0.0))
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
## Show only `n` of the baked phases, evenly spaced. 0 restores all of them.
##
## This is how the frame COUNT gets bracketed without re-baking: 32 subsamples
## exactly to 16 and 8, so the panels differ only in how many of the SAME poses
## are shown. The turn's in-between bracket had to re-render each option, which
## meant the compared clips were never guaranteed identical apart from the
## variable under test.
func set_walk_phase_quantise(n: int) -> void:
	_walk_quantise = n
	_walk_phase = -1


func set_walk_phase(progress01: float) -> void:
	if _posture != "standing":
		return
	if not _ensure_walk(_dev_vision):
		return
	var buckets: int = _walk_phases if _walk_quantise <= 0 else _walk_quantise
	var bucket := int(floor(fposmod(progress01, 1.0) * float(buckets))) % buckets
	var index: int = (bucket * _walk_phases) / buckets
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
		var walk_entry: Dictionary = _sets.get(_walk_key(_walk_phase, _dev_vision), {})
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
		clampf(best_energy * _light_intensity_scale, 0.0, _light_intensity_max))


## CLI-baked PNGs never went through the editor's import scan, so plain load()
## fails with "No loader found". Same fix floating_collectible.gd uses.
static func _load_texture_raw(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("[AgentSprite] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
