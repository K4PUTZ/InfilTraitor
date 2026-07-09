## DEV-HUD-01: DEV VISION systems status panel
## Displays live state of bake, vision, color systems, and debug toggles.
## Single-source rule: reads live state from owning systems each frame (no internal state copies).
## Refresh: on-frame timer (fast enough for F6/F7/H/L/V feedback).

extends Control

class_name DevVisionStatusPanel

# ── References ─────────────────────────────────────────────────────────────────
var _room: Node = null
var _label: Label = null
var _bake_config_class = null
var _vision_controller: Node = null
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  ## Refresh every 100ms (10 FPS for status display)

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0))  ## Light green
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Styling: black backplate matching _dev_hover_label
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	panel_bg.content_margin_left = 6.0
	panel_bg.content_margin_right = 6.0
	panel_bg.content_margin_top = 4.0
	panel_bg.content_margin_bottom = 4.0
	panel_bg.corner_radius_top_left = 3
	panel_bg.corner_radius_top_right = 3
	panel_bg.corner_radius_bottom_left = 3
	panel_bg.corner_radius_bottom_right = 3
	_label.add_theme_stylebox_override("normal", panel_bg)
	
	_label.text = "DEV VISION: loading..."
	add_child(_label)
	
	# Position: top-left corner, below tile-info panel
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 8.0
	offset_top = 200.0  ## Below _dev_hover_label (which is at 80.0)


func setup(room_ref: Node) -> void:
	_room = room_ref
	_bake_config_class = preload("res://godot/scripts/systems/bake_config.gd")
	
	# Get vision controller from room
	_vision_controller = room_ref._vision_controller
	
	print("[DEV-HUD-01] DEV VISION Status Panel initialized")


func _process(delta: float) -> void:
	# Update panel visibility: visible when dev_vision is active
	if _vision_controller:
		visible = _vision_controller.dev_vision
	
	# Refresh display on timer
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_display()
		_update_timer = UPDATE_INTERVAL


func _update_display() -> void:
	if not _room or not _vision_controller or not _bake_config_class:
		return
	
	var lines: Array[String] = []
	
	# ── MAP & PERSPECTIVE ──────────────────────────────────────────────────────
	lines.append("MAP: %s | VIEW: %s" % [_room.map_id, _room._active_perspective])
	
	# ── BAKE STATE ─────────────────────────────────────────────────────────────
	var bake_status = "✗ OFF"
	if _bake_config_class.enabled:
		var blend_mode_name = _bake_config_class.BlendMode.keys()[_bake_config_class.blend_mode]
		bake_status = "✓ %s" % blend_mode_name
	
	# ── BAKE FEATURES ──────────────────────────────────────────────────────────
	var facade_str = "✓" if _bake_config_class.facade_enabled else "✗"
	var pattern_str = "✓" if _bake_config_class.material_pattern_enabled else "✗"
	var dump_str = "✓" if _bake_config_class.debug_bake_set_dump else "✗"
	
	lines.append("BAKE: %s | facade%s pattern%s dump%s" % [bake_status, facade_str, pattern_str, dump_str])
	
	# ── VISION SYSTEMS ─────────────────────────────────────────────────────────
	var dev_str = "✓" if _vision_controller.dev_vision else "·"
	var light_str = "✓" if _vision_controller.light_vision else "·"
	var heat_str = "✓" if _vision_controller.heat_vision else "·"
	
	lines.append("VISION: dev%s light%s heat%s" % [dev_str, light_str, heat_str])
	
	# ── FOG & SHADOW STATE ─────────────────────────────────────────────────────
	# Fog is visible when dev_vision is OFF (negated)
	var fog_str = "·" if _room.fog_of_war.visible else "✓"  ## ✓ = hidden (dev mode), · = visible (normal)
	
	# Shadow overlay state — follows light_vision
	var shadow_str = "✓" if _vision_controller.is_shadow_overlay_visible() else "·"
	
	lines.append("FOG: %s | SHADOW: %s" % [fog_str, shadow_str])
	
	# ── HELPER LEGEND ──────────────────────────────────────────────────────────
	lines.append("[F6:bake F7:blend H:heat L:light V:dev]")
	
	# ── BUILD DISPLAY ──────────────────────────────────────────────────────────
	_label.text = "\n".join(lines)

