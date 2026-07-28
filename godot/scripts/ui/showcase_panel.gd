## ACTOR_MASTER_PLAN D20/Part 5a — Showcase screen.
##
## First concrete Part 5 (live 3D inspection window) application: a live
## SubViewport with a real Camera3D shows an imported mesh (D12's
## imported-mesh path, proven by shotgun_preview_spike.gd) filling most of
## the screen, auto-rotating slowly (D10's "auto-spin" option). Name/info
## sits in a separate area, laid out adaptively — a bottom strip in portrait
## (9:16), a side panel in landscape (16:9) — per D20. Breakpoint value and
## info content are both first-cut choices, not final (§7 open question #14).
##
## The object here (Shotgun Short Stock, D18's objects-track first case) is
## hardcoded for this first cut — no ShowcaseItem registry exists yet; that
## is exactly the kind of thing D19 says not to build before proving the
## mechanism works.
class_name ShowcasePanel
extends WindowBase

const MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Shotgun Short Stock.glb"
const ELEVATION_DEG := 30.0
const AZIMUTH_START_DEG := 45.0
## Kept matching FloatingCollectible.ROTATION_DEG_PER_SEC exactly (see that
## file's header) — 14.0 -> 36.0 (Director, 2026-07-28): the baked flipbook
## needs its frame-swap rate (FRAME_COUNT / rotation-period) above ~10-12Hz
## to read as smooth motion rather than discrete "soquinhos" jumps; 14 deg/s
## made even 72 frames swap at only ~2.8Hz. Showcase's live 3D spin has no
## such constraint but is kept in sync anyway for a consistent perceived
## speed between the two views.
const SPIN_DEG_PER_SEC := 36.0
## Aspect ratio below this is treated as portrait (info strip at the bottom);
## at or above it, landscape (info panel on the side). 1.0 = square cutoff;
## first-cut choice, not tuned against real device aspect ratios yet.
const PORTRAIT_ASPECT_CUTOFF := 1.0

@onready var _layout := BoxContainer.new()
@onready var _viewport_container := SubViewportContainer.new()
@onready var _sub_viewport := SubViewport.new()
@onready var _info_panel := PanelContainer.new()
@onready var _info_margin := MarginContainer.new()
@onready var _info_vbox := VBoxContainer.new()
@onready var _lbl_name := Label.new()
@onready var _lbl_desc := Label.new()
@onready var _btn_back := Button.new()

var _cam: Camera3D = null
var _model_center := Vector3.ZERO
var _model_extent := 1.0
var _azimuth_deg := AZIMUTH_START_DEG


func _ready() -> void:
	pausable = true
	super._ready()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = get_node_or_null("background")
	if bg:
		bg.color = Color(0.05, 0.05, 0.07, 0.96)

	title = tr("ui.showcase.title")

	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layout)

	_viewport_container.stretch = true
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(_viewport_container)

	_sub_viewport.transparent_bg = true
	_sub_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport_container.add_child(_sub_viewport)
	_build_3d_scene()

	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0, 0, 0, 0.85)
	_info_panel.add_theme_stylebox_override("panel", info_style)
	_layout.add_child(_info_panel)

	_info_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info_margin.add_theme_constant_override("margin_left", 24)
	_info_margin.add_theme_constant_override("margin_right", 24)
	_info_margin.add_theme_constant_override("margin_top", 24)
	_info_margin.add_theme_constant_override("margin_bottom", 24)
	_info_panel.add_child(_info_margin)

	_info_vbox.add_theme_constant_override("separation", 12)
	_info_margin.add_child(_info_vbox)

	_lbl_name.text = tr("ui.showcase.item.shotgun_breaching")
	_lbl_name.add_theme_font_size_override("font_size", 22)
	_info_vbox.add_child(_lbl_name)

	_lbl_desc.text = tr("ui.showcase.item.shotgun_breaching_desc")
	_lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_info_vbox.add_child(_lbl_desc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_vbox.add_child(spacer)

	_btn_back.text = tr("ui.showcase.back")
	_btn_back.custom_minimum_size = Vector2(160, 44)
	_btn_back.pressed.connect(request_close)
	_info_vbox.add_child(_btn_back)

	_reflow_layout()
	get_viewport().size_changed.connect(_reflow_layout)
	set_process(true)


func open() -> void:
	super.open()
	_reflow_layout()
	_btn_back.grab_focus()


## D20: viewport fills most of the screen either way; the info area is a
## bottom strip in portrait, a side panel in landscape. Re-evaluated on open
## and on every resize (device rotation, window resize) rather than fixed
## once at _ready().
func _reflow_layout() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.y <= 0.0:
		return
	var aspect := vp_size.x / vp_size.y
	var portrait := aspect < PORTRAIT_ASPECT_CUTOFF
	_layout.vertical = portrait
	if portrait:
		_info_panel.custom_minimum_size = Vector2(0, vp_size.y * 0.22)
	else:
		_info_panel.custom_minimum_size = Vector2(vp_size.x * 0.28, 0)


func _build_3d_scene() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	world_env.environment = env
	_sub_viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.8
	_sub_viewport.add_child(light)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_sub_viewport.add_child(_cam)
	_cam.current = true

	## Same runtime GLTFDocument load shotgun_preview_spike.gd already
	## proved (D12's imported-mesh path) — no editor import step needed.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(MODEL_PATH, state)
	if err != OK:
		push_error("[ShowcasePanel] failed to load %s (error %d)" % [MODEL_PATH, err])
		return
	var model_root: Node = doc.generate_scene(state)
	if model_root == null:
		push_error("[ShowcasePanel] generate_scene returned null for %s" % MODEL_PATH)
		return
	_sub_viewport.add_child(model_root)

	await get_tree().process_frame
	var aabb := _compute_aabb(model_root)
	_model_center = aabb.get_center()
	_model_extent = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if _model_extent <= 0.0:
		_model_extent = 1.0
	_cam.size = _model_extent * 1.6
	_update_camera_position()


func _process(delta: float) -> void:
	if _cam == null:
		return
	_azimuth_deg = fmod(_azimuth_deg + SPIN_DEG_PER_SEC * delta, 360.0)
	_update_camera_position()


func _update_camera_position() -> void:
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(_azimuth_deg)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	_cam.look_at_from_position(_model_center + dir * _model_extent * 3.0, _model_center, Vector3.UP)


func _compute_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for inst in _all_visual_instances(node):
		var world_box: AABB = inst.global_transform * inst.get_aabb()
		if first:
			result = world_box
			first = false
		else:
			result = result.merge(world_box)
	return result


func _all_visual_instances(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_visual_instances(child))
	return found
