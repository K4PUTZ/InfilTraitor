## CHARACTER_MASTER_PLAN Part 2 — the agent, standing in the real room.
##
## WHAT THIS IS FOR, exactly: the Director asked whether the figure can be put in
## the scene yet to judge PROPORTIONS and LIGHTING. This is that probe and only
## that. It does not touch `agent.gd` — the playable agent is still its vector
## placeholder, and Part 2's definition of done (§10: the placeholder is GONE) is
## deliberately not claimed here. What this answers is whether the baked figure
## sits at the right size against real voxel geometry and takes the room's real
## light, which is the thing that has to be true before the swap is worth doing.
##
## A lean sibling of GrenadeProp: same four-frames-per-room-perspective contract,
## same `flat_normal_relight.gdshader`, same perspective-aware light mapping
## (ACTOR_MASTER_PLAN D22), same ground-contact anchoring. Three differences, all
## deliberate:
##
## 1. SPRITE_SCALE IS 1.0, AND THAT IS A DERIVATION RATHER THAN A SETTING.
##    Every other prop in this project carries a hand-tuned sprite scale, which
##    is right for a grenade and wrong here: the question being asked IS the
##    figure's size, so a scale tuned until it looked right would answer itself.
##    `agent_frame_bake_spike.gd` bakes at the game's own pixel scale and gates on
##    it — a 0.20 m rise measured 20.000 px against VOXEL_STEP_PX's 20.0 — so one
##    texel is already one world pixel and any scale but 1.0 would BREAK it.
##
## 2. THE ANCHOR IS READ FROM THE BAKE, NOT COPIED FROM IT.
##    GrenadeProp hardcodes its `ANCHOR_PX` as a constant transcribed from the
##    bake's printout. That is one number in two places, and it goes stale the
##    first time the canvas size changes. The bake already writes `anchor.json`;
##    this reads it.
##
## 3. NO GROUND SHADOW, ON PURPOSE.
##    GrenadeProp fakes one by squashing the sprite's own silhouette on Y — a
##    stated substitution that works because a grenade is a small round object.
##    A 1.9 m standing figure squashed on Y is a long smear, not a footprint, and
##    the bake's own header notes the honest version is a separate top-down pass
##    (which `actor_frame_bake_spike.gd` does and this bake does not). Shipping a
##    knowingly-wrong shadow into a probe about how the figure READS would
##    corrupt the very judgement it exists for. The figure will look unmoored;
##    that is the missing pass, not a placement bug.
class_name AgentProbeProp
extends Sprite2D

const FRAMES_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"
const SHADER_PATH := "res://godot/shaders/flat_normal_relight.gdshader"
const DIRECTIONS := ["N", "E", "S", "W"]
## The yaw each baked frame was rendered at, matching agent_frame_bake_spike.gd.
const YAW_BY_DIRECTION := {"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}

## See note 1. Not a knob.
const SPRITE_SCALE := 1.0

## --- The washed-out fix (Director, 2026-08-16: "conserta o lavado"). ---
##
## MEASURED FIRST, then tuned. The figure's baked albedo is (138,138,150) — a
## real blue cast, b-r = 12. On screen it came back at b-r = 5 with its lit faces
## averaging ~200 and 390 pixels fully clipped. Both symptoms have one cause: the
## specular term is WHITE, so it simultaneously blows the highlights and pulls
## the hue out of everything it touches. `flat_normal_relight`'s defaults were
## tuned against weapons, and a gun barrel is specular in a way a wool suit is
## not.
##
## So the biggest move here is dropping specular, not dimming the light — dimming
## alone would have made a grey figure darker instead of a blue figure. The
## saturation/contrast pair is D31's own same-day answer to this exact complaint
## about the weapons ("dá pra aumentar um pouquinho a saturação e o contraste
## [...] sem refazer o bake?"), set slightly gentler than the bench's 1.3/1.15
## because this albedo starts with hue rather than needing it manufactured.
## ZERO, not merely low. Director, 2026-08-16, on seeing the additive row of the
## suit bracket: *"sem o brilho em volta e nem o reflexo branco que deixa com
## aparência de plástico. Tecido não tem reflexo duro, somente manchas opacas."*
## That rules the specular lever OUT for this character rather than turning it
## down — which also means the near-black suit's volume has to come from the
## geometry and albedo edges built in p1_agent_model.py, since the two additive
## terms the bracket offered are both now declined (the outline defaults to 0).
const SPECULAR_STRENGTH := 0.0
const AMBIENT := 0.42             ## was 0.55
const SATURATION := 1.25
const CONTRAST := 1.12
## The shared clamp is 3.0, sized for objects D31 had to grade UP from a mean of
## 47. This albedo already lands at 138, so the same headroom overshoots.
const LIGHT_INTENSITY_SCALE := 0.60
const LIGHT_INTENSITY_MAX := 1.30

## Must match agent_frame_bake_spike.gd's camera, which is CollectibleBakeConfig's
## convention — D26: a different angle breaks the light maths silently.
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
var base_cell: Vector2i = Vector2i.ZERO

var _material: ShaderMaterial
var _color_frames: Dictionary = {}
var _normal_frames: Dictionary = {}
var _anchor_px: Vector2 = Vector2.ZERO
var _frames_dir: String = FRAMES_DIR
## The agent's OWN facing, independent of the room's perspective. §4.6 is
## explicit that what reaches the screen is `facing - perspective`, cyclic, so a
## figure facing N in a room viewed from E shows a different frame than one
## facing E. Until now this prop only ever tracked the perspective, which is
## correct for a grenade and wrong for a character — and it is why four probes in
## one room all showed the same face. Director, 2026-08-16: "coloca o boneco 4x
## na cena para a gente avaliar todas as faces."
var _facing: String = "N"

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


## `cfg` is optional and every key falls back to the constants above. It exists
## for the suit bracket (Director, 2026-08-16): several figures in one frame,
## each on its own bake and its own additive treatment, so a near-black suit can
## be judged against its neighbours instead of against a memory of the last
## capture. Same per-instance reasoning D26 applied to FloatingCollectible when
## its hardcoded shotgun paths turned out to describe only the shotgun.
##   frames_dir · specular · ambient · saturation · contrast · outline
func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i,
		cfg: Dictionary = {}) -> void:
	room = p_room
	gu_cell = p_gu_cell
	base_cell = p_base_cell
	_frames_dir = String(cfg.get("frames_dir", FRAMES_DIR))
	_facing = String(cfg.get("facing", "N"))

	if not _load_anchor():
		return
	for direction: String in DIRECTIONS:
		_color_frames[direction] = _load_texture_raw("%sframe_%s_color.png" % [_frames_dir, direction])
		_normal_frames[direction] = _load_texture_raw("%sframe_%s_normal.png" % [_frames_dir, direction])
		if _color_frames[direction] == null or _normal_frames[direction] == null:
			push_error("[AgentProbeProp] frames missing for %s in %s — run agent_frame_bake_spike.gd" % [direction, _frames_dir])
			return

	centered = false
	offset = -_anchor_px
	scale = Vector2.ONE * SPRITE_SCALE

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	## Opt in explicitly, the same contract outline_width and saturation already
	## use: this shader is SHARED with the grenade and every weapon, so a default
	## changed in the shader itself would silently restyle all of them.
	_material.set_shader_parameter("specular_strength", float(cfg.get("specular", SPECULAR_STRENGTH)))
	_material.set_shader_parameter("ambient", float(cfg.get("ambient", AMBIENT)))
	_material.set_shader_parameter("saturation", float(cfg.get("saturation", SATURATION)))
	_material.set_shader_parameter("contrast", float(cfg.get("contrast", CONTRAST)))
	## D28's stroke. It is the OTHER additive lever: a constant-colour outline that
	## does not scale with albedo, added precisely because "a arma está muito
	## escura em relação ao fundo" — the same sentence a near-black suit invites.
	_material.set_shader_parameter("outline_width", float(cfg.get("outline", 0.0)))
	material = _material

	_apply_direction(room._active_perspective)
	_apply_z_index()
	set_process(true)


## The anchor pixel the bake computed and wrote — see note 2.
func _load_anchor() -> bool:
	var anchor_path := _frames_dir + "anchor.json"
	if not FileAccess.file_exists(anchor_path):
		push_error("[AgentProbeProp] %s missing — run agent_frame_bake_spike.gd first" % anchor_path)
		return false
	var text := FileAccess.get_file_as_string(anchor_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("anchor_px"):
		push_error("[AgentProbeProp] %s is not a bake anchor file" % anchor_path)
		return false
	var a: Array = parsed["anchor_px"]
	_anchor_px = Vector2(float(a[0]), float(a[1]))
	return true


## Called on a perspective flip, alongside the position update — same contract
## GrenadeProp.update_cell() has. z_index is re-applied because
## _set_perspective() rebuilds every voxel layer from scratch.
func update_cell(p_gu_cell: Vector2i) -> void:
	gu_cell = p_gu_cell
	_apply_direction(room._active_perspective)
	_apply_z_index()


## Sorts like the level-0 geometry it stands on, NOT "always on top". OCC-03's
## always-on-top rule is the agent's own policy and is explicitly agent-only —
## copying it onto a prop is the D22-FOLLOWUP mistake, and this probe is a prop.
func _apply_z_index() -> void:
	if room == null or room._voxel_renderer == null:
		return
	var ground_layer: TileMapLayer = room._voxel_renderer.get_layer(0)
	if ground_layer != null:
		z_index = ground_layer.z_index


## `perspective` is the room's; the frame shown is the composition of it with the
## agent's own facing, which is what §4.6 defines. With facing "N" this reduces
## to the old behaviour exactly.
func _apply_direction(perspective: String) -> void:
	var yaw: float = float(YAW_BY_DIRECTION.get(perspective, 0.0)) \
		+ float(YAW_BY_DIRECTION.get(_facing, 0.0))
	var direction: String = "N"
	for d: String in DIRECTIONS:
		if is_equal_approx(fposmod(float(YAW_BY_DIRECTION[d]) - yaw, 360.0), 0.0):
			direction = d
			break
	if not _color_frames.has(direction):
		return
	texture = _color_frames[direction]
	if _material != null:
		_material.set_shader_parameter("normal_tex", _normal_frames[direction])


func _process(_delta: float) -> void:
	_update_light_uniform()


## Verbatim in behaviour from GrenadeProp._update_light_uniform (D22's fix):
## de-rotate both cells to the base (North) orientation before applying the
## grid -> world mapping, because the bake camera's fixed azimuth was derived
## against a canonical N view.
func _update_light_uniform() -> void:
	if room == null or room._lighting_controller == null or _material == null:
		return
	var registry = room._lighting_controller.get_light_registry()
	if registry == null:
		return

	var best_light = null
	var best_energy := -1.0
	for light in registry.get_active_lights():
		if not light.affects_cell(gu_cell):
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
	var grid_delta: Vector2i = base_light_cell - base_cell
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
		push_error("[AgentProbeProp] failed to load %s (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)
