## DEBUG-02: Debug tools controller — handles F2/F3/F4 debug toggles and voxel nudging.
## Extracted from room.gd (Task 03 modularization).
## Signals room on mode changes; room holds references to debug overlays and toggles.
class_name DebugToolsController

var room: Node
var _voxel_ruler_overlay: Node2D = null
var _nudge_mode_active: bool = false
var _map_loader_panel: Node = null


func _init(p_room: Node) -> void:
	room = p_room


## Toggle map loader panel (F2)
func toggle_map_loader_panel() -> void:
	if _map_loader_panel == null:
		var MapLoaderPanelClass = preload("res://godot/scripts/debug/map_loader_panel.gd")
		_map_loader_panel = ConfirmationDialog.new()
		_map_loader_panel.set_script(MapLoaderPanelClass)
		room.add_child(_map_loader_panel)
		_map_loader_panel.setup(room)
	_map_loader_panel.popup_centered_ratio(0.5)
	print_debug("[DEBUG-02] Map loader panel opened")


## Create map loader toolbar button
func create_map_loader_button() -> void:
	if room.toolbar_row == null:
		return
	var btn_map := Button.new()
	btn_map.text = "🗺️"
	btn_map.add_theme_font_size_override("font_size", 16)
	btn_map.custom_minimum_size = Vector2(40.0, 32.0)
	btn_map.pressed.connect(toggle_map_loader_panel)
	room.toolbar_row.add_child(btn_map)


## Toggle voxel ruler grid overlay (F3)
func toggle_voxel_ruler_overlay() -> void:
	if _voxel_ruler_overlay == null:
		var VoxelRulerClass = preload("res://godot/scripts/debug/voxel_ruler_overlay.gd")
		_voxel_ruler_overlay = Node2D.new()
		_voxel_ruler_overlay.set_script(VoxelRulerClass)
		room.add_child(_voxel_ruler_overlay)
		_voxel_ruler_overlay.setup(room.floor_layer, room.VISUAL_GRID_OFFSET, room._room_size)

	_voxel_ruler_overlay.visible_grid = not _voxel_ruler_overlay.visible_grid
	_voxel_ruler_overlay.queue_redraw()
	print_debug("[DEBUG-02] Voxel ruler overlay: %s" % ("ON" if _voxel_ruler_overlay.visible_grid else "OFF"))


## Toggle nudge mode (F4) for voxel renderer debug positioning
func toggle_nudge_mode() -> void:
	_nudge_mode_active = not _nudge_mode_active

	if _nudge_mode_active:
		var msg := "NUDGE MODE ON — arrows: 1px, Shift+arrows: 8px, R: reset, F4: exit"
		print_debug("[DEBUG-02] %s" % msg)
	else:
		print_debug("[DEBUG-02] Nudge mode OFF")


## Toggle bake mode (F6) for visual QA: flip BakeConfig.enabled and reload current map
func toggle_bake_mode() -> void:
	var BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
	BakeConfigClass.enabled = not BakeConfigClass.enabled
	
	# Reload the current map through the full rendering pipeline
	room.load_map(room.map_id)
	
	var mode_name := "BAKED" if BakeConfigClass.enabled else "GENERIC"
	print_debug("[DEBUG-02] Bake mode: %s (enabled=%s)" % [mode_name, BakeConfigClass.enabled])
	
	# Show transient on-screen label
	_show_bake_mode_label(mode_name)


## Show a transient on-screen label displaying the bake mode
func _show_bake_mode_label(mode_name: String) -> void:
	var label := Label.new()
	label.text = "Bake Mode: %s" % mode_name
	label.add_theme_font_size_override("font_size", 20)
	label.set("theme_override_colors/font_color", Color.WHITE)
	label.position = Vector2(100.0, 20.0)  # Top-left, below UI
	room.add_child(label)
	
	# Auto-remove after 2.5 seconds
	var timer := Timer.new()
	timer.wait_time = 2.5
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		label.queue_free()
		timer.queue_free()
	)
	room.add_child(timer)
	timer.start()



## Apply nudge to voxel renderer
func apply_nudge(delta: Vector2) -> void:
	if room._voxel_renderer == null:
		return
	room._voxel_renderer.apply_debug_nudge(delta)
	# Get base TILE_OFFSET from VoxelRenderer to keep nudge print truthful
	var base_offset := Vector2(112.0, 64.0)  # Must match VoxelRenderer.TILE_OFFSET
	print_debug("[NUDGE] accumulated = (%.1f, %.1f) px  →  suggested TILE_OFFSET = (%.1f, %.1f)" % [
		room._voxel_renderer.debug_nudge.x,
		room._voxel_renderer.debug_nudge.y,
		base_offset.x + room._voxel_renderer.debug_nudge.x,
		base_offset.y + room._voxel_renderer.debug_nudge.y
	])


## Reset nudge to zero
func reset_nudge() -> void:
	if room._voxel_renderer == null:
		return
	var current: Vector2 = room._voxel_renderer.debug_nudge
	room._voxel_renderer.apply_debug_nudge(-current)
	print_debug("[NUDGE] reset to (0.0, 0.0) px  →  suggested TILE_OFFSET = (112.0, 64.0)")


## Try to change agent posture (Z key to cycle STANDING → CROUCHING → PRONE)
func try_change_posture(new_posture: DebugAgent.Posture) -> void:
	if room.agent.posture == new_posture:
		return
	if room.turn_manager.is_enemy_phase:
		return
	if room.turn_manager.current_ap < DebugAgent.POSTURE_CHANGE_AP:
		return
		
	room.turn_manager.consume_ap(DebugAgent.POSTURE_CHANGE_AP)
	room.agent.set_posture(new_posture)
	room._refresh_tactical_state()


## Query nudge mode state
func is_nudge_mode_active() -> bool:
	return _nudge_mode_active
