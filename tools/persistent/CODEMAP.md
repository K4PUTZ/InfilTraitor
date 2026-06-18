# CODEMAP — INFILTRAITOR

> **GENERATED FILE — do not edit by hand.**
> Produced by `tools/persistent/gen_codemap.py` from the actual GDScript
> source. Regenerate with `python3 tools/persistent/gen_codemap.py`.
> A pre-commit hook blocks commits when this file is stale.
>
> Design rationale and the inviolable rules live in `OPERATOR_CONTEXT.md`
> (hand-authored). This file is the mechanical mirror of the code.

**51 scripts · 9714 lines total** (under `godot/scripts/`)

## Index

- **agents/** — agent.gd, guard_attention.gd, guard_enemy.gd
- **controllers/** — camera_controller.gd, fow_controller.gd, guard_coordinator.gd, hud_controller.gd, lighting_controller.gd, vision_controller.gd
- **data/** — agent_stats.gd
- **navigation/** — guard_pathfinder.gd, movement_overlay.gd, path_preview.gd
- **overlays/** — ceiling_prop_overlay.gd, elite_exposure_overlay.gd, exposure_overlay.gd, guard_noise_indicator.gd, height_overlay.gd, light_overlay.gd, noise_overlay.gd, shadow_overlay.gd, temporal_overlay.gd, tile_overlay.gd, tile_risk_overlay.gd, trail_overlay.gd
- **systems/** — enemy_phase_controller.gd, exposure_system.gd, light_anchor.gd, light_registry.gd, light_source.gd, shadow_projector.gd, shadow_result.gd, noise_system.gd, tic_system.gd, turn_manager.gd
- **tools/** — build_tileset.gd
- **ui/** — compass_rose.gd, fog_of_war_overlay.gd, selection_overlay.gd, tile_labels_overlay.gd
- **world/** — level_graph.gd, playground_map.gd, procedural_map.gd, sigma_01_map.gd, map_catalog.gd, map_compiler.gd, map_geometry.gd, room.gd, tile_registry.gd, tile_semantics.gd, wall_edge_data.gd

---

## agents/

### `agent.gd`

`class_name DebugAgent` · extends `Node2D` · 221 lines

`godot/scripts/agents/agent.gd`

**Signals**
- `signal move_started(from_cell: Vector2i, to_cell: Vector2i)`
- `signal step_finished(cell: Vector2i)`
- `signal move_finished(cell: Vector2i)`
- `signal posture_changed(new_posture: Posture)`

**Constants / tuning**
- `POSTURE_CHANGE_AP` = `1`
- `POSTURE_DETECTION_MULT` = `{ Posture.STANDING:  1.00, Posture.CROUCHING: 0.55, Posture.PRONE:     0.20, }`
- `POSTURE_MOVE_AP_COST` = `{ Posture.STANDING:  0, Posture.CROUCHING: 1,   ## each tile costs +1 extra AP Posture.PRONE:     99,  ## cannot move (99 = effective block) }`
- `POSTURE_COLORS` = `{ Posture.STANDING:  Color(0.16, 0.78, 0.32, 1.0),   ## green — current color Posture.CROUCHING: Color(0.90, 0.75, 0.10, 1.0),   ## yellow Posture.PRONE:     Color(0.90, 0.35, 0.10, 1.0),   ## orange }`
- `POSTURE_HIT_MULT` = `{ Posture.STANDING:  1.00, Posture.CROUCHING: 0.50, Posture.PRONE:     0.70, }`
- `POSTURE_AIM_MULT` = `{ Posture.STANDING:  1.00, Posture.CROUCHING: 0.75, Posture.PRONE:     0.50, }`
- `COVER_FULL_MULT` = `0.20`
- `COVER_PARTIAL_MULT` = `0.55`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `STEP_DURATION` = `0.13`
- `COLOR_BODY` = `Color(0.16, 0.78, 0.32, 1.0)`
- `COLOR_BODY_DARK` = `Color(0.07, 0.42, 0.18, 1.0)`
- `COLOR_HEAD` = `Color(0.84, 0.96, 0.88, 1.0)`
- `COLOR_SHADOW` = `Color(0.0, 0.0, 0.0, 0.28)`

**Public vars**
- `var posture: Posture = Posture.STANDING`
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var cell: Vector2i = Vector2i.ZERO`
- `var vision_radius: int = 7`
- `var vision_mode: String = "normal"`
- `var is_moving: bool = false`
- `var dev_vision: bool = false`
- `var cover_state: CoverType = CoverType.NONE`
- `var cover_direction: Vector2i = Vector2i.ZERO`

**Public API**
- `func setup(tile_layer: TileMapLayer, offset: Vector2, start_cell: Vector2i) -> void:`
- `func set_cell(new_cell: Vector2i) -> void:`
- `func get_vision_radius() -> int:`
- `func set_vision_radius(new_radius: int) -> void:`
- `func set_posture(new_posture: Posture) -> void:`
- `func update_cover(blocked_cells: Dictionary) -> void:`
- `func move_along_path(path: Array[Vector2i]) -> void:`

---

### `guard_attention.gd`

`class_name GuardAttention` · extends `RefCounted` · 21 lines

`godot/scripts/agents/guard_attention.gd`

**Constants / tuning**
- `DECAY_RATE` = `0.65`

**Public vars**
- `var target_cell: Vector2i = Vector2i.ZERO`
- `var interest: float = 0.0`
- `var timer: float = 0.0`

**Public API**
- `func focus(p_cell: Vector2i, strength: float, duration: float) -> void:`
- `func update(delta: float) -> void:`
- `func active() -> bool:`

---

### `guard_enemy.gd`

`class_name GuardEnemy` · extends `Node2D` · 1113 lines

`godot/scripts/agents/guard_enemy.gd`

**Signals**
- `signal move_started(from_cell: Vector2i, to_cell: Vector2i)`
- `signal step_finished(cell: Vector2i)`
- `signal move_finished(cell: Vector2i)`
- `signal whistled(origin_cell: Vector2i, last_known: Vector2i)`
- `signal radioed(origin_cell: Vector2i, last_known: Vector2i)`

**Constants / tuning**
- `TileOverlayClass` = `preload("res://godot/scripts/overlays/tile_overlay.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `STEP_DURATION_BASE` = `0.13`
- `COLOR_BODY` = `Color(0.86, 0.26, 0.22, 1.0)`
- `COLOR_BODY_DARK` = `Color(0.58, 0.12, 0.10, 1.0)`
- `COLOR_HEAD` = `Color(1.0, 0.87, 0.80, 1.0)`
- `COLOR_SHADOW` = `Color(0.0, 0.0, 0.0, 0.28)`
- `FOV_DISTANCE_CURVE` = `[ 1.00, 1.00, 0.95, 0.88, 0.70, 0.48, 0.20, 0.06, 0.01 ]`
- `FOV_LATERAL_FALLOFF` = `[1.0, 0.50, 0.10]`
- `COLOR_VISION_SMOOTH` = `Color(1.0, 0.9, 0.2, 0.5)`
- `CARDINAL_DIRS` = `[Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]`
- `VISION_RANGE` = `6`
- `VISION_CONE_RADIUS` = `6`
- `VISION_CONE_HALF_WIDTH_TILES` = `3`
- `STATE_PATROL` = `"patrol"`
- `STATE_SUSPICIOUS` = `"suspicious"`
- `STATE_ALERT` = `"alert"`
- `STATE_CHASE` = `"chase"`
- `STATE_SEARCH` = `"search"`
- `INVALID_CELL` = `Vector2i(-9999, -9999)`
- `SHADOW_MULT` = `0.30`
- `PENUMBRA_MULT` = `0.55`
- `TIMER_ALERT_TO_CHASE` = `3`
- `TIMER_SUSPICIOUS_TO_PATROL` = `4`
- `TIMER_CHASE_TO_SEARCH` = `3`
- `TIMER_SEARCH_TO_SUSPICIOUS` = `2`
- `TIMER_NOISE_SUSPICIOUS` = `3`
- `TIMER_NOISE_SUSPICIOUS_MED` = `2`
- `TURN_SPEED` = `4.0`
- `SEARCH_RADIUS` = `2`
- `SEARCH_TURNS_MAX` = `5`
- `COMMS_LABEL_DURATION` = `2.0`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var enemy_id: String = ""`
- `var cell: Vector2i = Vector2i.ZERO`
- `var patrol_route: Array[Vector2i] = []`
- `var patrol_index: int = 0`
- `var facing: Vector2i = Vector2i.UP`
- `var state: String = STATE_PATROL`
- `var state_timer: int = 0`
- `var last_known_agent_cell: Vector2i = INVALID_CELL`
- `var is_moving: bool = false`
- `var fov_degrees: float = 90.0`
- `var fov_range: int = 8`
- `var facing_angle_deg: float = 0.0`
- `var body_angle: float   = 0.0`
- `var vision_angle: float = 0.0`
- `var attention: GuardAttention = GuardAttention.new()`
- `var dev_vision: bool = false`
- `var detection: float = 0.0`
- `var idle_turns_remaining: int = 0`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_los_data(blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i = Vector2i.ZERO, shadow_tiles: Dictionary = {}) -> void:`
- `func setup( tile_layer: TileMapLayer, offset: Vector2, id: String, route: Array[Vector2i], start_index: int = 0 ) -> void:`
- `func reset_to_route_start() -> void:`
- `func evaluate_detection( player_cell: Vector2i, _vision_range: int = VISION_RANGE, blocked_cells: Dictionary = {}, blocked_edges: Dictionary = {}, _close_warning_range: int = 2, agent_ref: DebugAgent = null ) -> Dictionary:`
- `func pick_next_patrol_cell( occupied_cells: Dictionary, blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i ) -> Vector2i:`
- `func move_to_cell_animated( new_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i ) -> void:`
- `func move_along_path(path: Array[Vector2i]) -> void:`
- `func can_see_cell(target_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary) -> bool:`
- `func receive_alert(known_cell: Vector2i, target_state: String) -> void:`
- `func observe_player(player_visible: bool, severity: int, player_cell: Vector2i) -> void:`
- `func hear_noise(noise_tile: Vector2i, perceived_intensity: float) -> void:`
- `func tick_state() -> void:`
- `func choose_next_cell( occupied_cells: Dictionary, blocked_cells: Dictionary, blocked_edges: Dictionary, player_cell: Vector2i, room_size: Vector2i ) -> Vector2i:`

---

## controllers/

### `camera_controller.gd`

extends `Node` · 182 lines

`godot/scripts/controllers/camera_controller.gd`

**Constants / tuning**
- `DRAG_THRESHOLD_SQ` = `64.0`
- `ZOOM_MIN` = `0.20`
- `ZOOM_MAX` = `1.20`
- `ZOOM_STEP` = `0.06`
- `CAMERA_MAX_BORDER_TILES` = `4`
- `CAMERA_SOFT_ZONE_TILES` = `2`
- `WORLD_TILE_PX` = `128.0`

**Public API**
- `func setup(camera_ref: Camera2D, room_ref: Node2D) -> void:`
- `func handle_input(event: InputEvent) -> bool:`
- `func focus_on(world_pos: Vector2) -> void:`

---

### `fow_controller.gd`

extends `Node` · 77 lines

`godot/scripts/controllers/fow_controller.gd`

**Public API**
- `func setup(room_ref: Node2D, fog_of_war_ref: FogOfWarOverlay, fog_rect_ref: ColorRect) -> void:`
- `func initialize_fog(floor_layer: TileMapLayer, visual_offset: Vector2, room_size: Vector2i) -> void:`
- `func reveal_around(center: Vector2i, radius: int) -> void:`
- `func reset_fog() -> void:`
- `func add_peek_reveal(cell: Vector2i) -> void:`
- `func reset_peek_reveals() -> void:`
- `func is_cell_revealed(cell: Vector2i) -> bool:`
- `func update_vision_center(_agent_world_pos: Vector2, agent_screen_uv: Vector2, vision_radius_tiles: float, zoom: float, vp_size: Vector2) -> void:`

---

### `guard_coordinator.gd`

extends `Node` · 108 lines

`godot/scripts/controllers/guard_coordinator.gd`

**Signals**
- `signal guard_whistled(origin_cell: Vector2i, last_known: Vector2i)`
- `signal guard_radioed(origin_cell: Vector2i, last_known: Vector2i)`
- `signal alarm_raised(origin_cell: Vector2i)`
- `signal all_guards_alerted()`

**Public API**
- `func setup(room_ref: Node2D) -> void:`
- `func register_guard(guard: Object) -> void:`

---

### `hud_controller.gd`

extends `Node` · 129 lines

`godot/scripts/controllers/hud_controller.gd`

**Signals**
- `signal end_turn_requested()`
- `signal reset_requested()`
- `signal fullscreen_toggled(enabled: bool)`
- `signal viewport_toggled()`
- `signal numbers_toggled(enabled: bool)`

**Public API**
- `func setup(refs: Dictionary) -> void:`
- `func update_ap(current: int, max_ap: int, is_enemy_phase: bool = false) -> void:`
- `func update_alert(pct: float) -> void:`
- `func show_enemy_banner() -> void:`
- `func hide_enemy_banner() -> void:`
- `func show_busted(text: String = "Busted") -> void:`
- `func hide_busted() -> void:`
- `func set_end_turn_enabled(value: bool) -> void:`
- `func is_auto_end_turn_enabled() -> bool:`
- `func set_numbers_button_active(active: bool) -> void:`
- `func set_viewport_button_text(text: String) -> void:`

---

### `lighting_controller.gd`

extends `Node` · 252 lines

`godot/scripts/controllers/lighting_controller.gd`

**Signals**
- `signal lighting_rebuilt()`

**Constants / tuning**
- `LightRegistryClass` = `preload("res://godot/scripts/systems/lighting/light_registry.gd")`
- `ShadowProjectorClass` = `preload("res://godot/scripts/systems/lighting/shadow_projector.gd")`
- `ExposureSystemClass` = `preload("res://godot/scripts/systems/lighting/exposure_system.gd")`
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `LightAnchorClass` = `preload("res://godot/scripts/systems/lighting/light_anchor.gd")`
- `ShadowResultClass` = `preload("res://godot/scripts/systems/lighting/shadow_result.gd")`
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`

**Public API**
- `func setup(room_ref: Node2D) -> void:`
- `func get_light_registry():`
- `func get_exposure_system():`
- `func get_tile_semantics_map() -> Dictionary:`
- `func get_light_anchors() -> Array:`
- `func rebuild() -> void:`
- `func rebuild_all() -> void:`
- `func rebuild_deferred() -> void:`

---

### `vision_controller.gd`

extends `Node2D` · 266 lines

`godot/scripts/controllers/vision_controller.gd`

**Constants / tuning**
- `LightOverlayClass` = `preload("res://godot/scripts/overlays/light_overlay.gd")`
- `ShadowOverlayClass` = `preload("res://godot/scripts/overlays/shadow_overlay.gd")`
- `ExposureOverlayClass` = `preload("res://godot/scripts/overlays/exposure_overlay.gd")`
- `TileRiskOverlayClass` = `preload("res://godot/scripts/overlays/tile_risk_overlay.gd")`
- `HeightOverlayClass` = `preload("res://godot/scripts/overlays/height_overlay.gd")`
- `TemporalOverlayClass` = `preload("res://godot/scripts/overlays/temporal_overlay.gd")`
- `EliteExposureOverlayClass` = `preload("res://godot/scripts/overlays/elite_exposure_overlay.gd")`

**Public vars**
- `var dev_vision: bool = false`
- `var light_vision: bool = false`
- `var heat_vision: bool = false`

**Public API**
- `func setup(room_ref: Node2D, fog_of_war_ref: Node2D) -> void:`
- `func toggle_dev() -> void:`
- `func toggle_light() -> void:`
- `func toggle_heat() -> void:`
- `func request_redraw() -> void:`

---

## data/

### `agent_stats.gd`

`class_name AgentStats` · 37 lines

`godot/scripts/data/agent_stats.gd`

**Public vars**
- `var max_ap: int = 2`
- `var move_points_per_ap: int = 3`
- `var max_hp: int = 3`
- `var max_armor: int = 0`
- `var current_hp: int = 3`
- `var current_armor: int = 0`
- `var vision_radius: int = 7`
- `var vision_mode: String = "normal"`
- `var alert_max: int = 100`
- `var alert_gain_warning: int = 20`
- `var alert_gain_full: int = 45`
- `var difficulty_tier: int = 1`

**Public API**
- `func get_max_resistance() -> int:`
- `func is_fatal_hit(hits_taken: int) -> bool:`

---

## navigation/

### `guard_pathfinder.gd`

`class_name GuardPathfinder` · 80 lines

`godot/scripts/navigation/guard_pathfinder.gd`

---

### `movement_overlay.gd`

`class_name MovementOverlay` · extends `Node2D` · 242 lines

`godot/scripts/navigation/movement_overlay.gd`

**Constants / tuning**
- `TILE_TOP_TO_CENTER` = `Vector2(0.0, 64.0)`
- `BLUE_LINE` = `Color(0.25, 0.70, 1.0, 0.90)`
- `ORANGE_LINE` = `Color(1.0, 0.60, 0.20, 0.95)`
- `FILL_COLOR` = `Color(1.0, 1.0, 1.0, 1.0)`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var origin_cell: Vector2i = Vector2i(-9999, -9999)`
- `var max_path_cost: int = 0`

**Public API**
- `func setup(tile_layer: TileMapLayer, offset: Vector2, points_per_ap: int = 3) -> void:`
- `func set_blocked_cells(cells: Array[Vector2i]) -> void:`
- `func set_blocked_edges(edges: Array[Dictionary]) -> void:`
- `func rebuild(start_cell: Vector2i, new_max_path_cost: int) -> void:`
- `func clear_overlay() -> void:`
- `func set_highlight_ap(ap: int) -> void:`
- `func set_remaining_ap(ap: int) -> void:`
- `func is_reachable(cell: Vector2i) -> bool:`
- `func get_cost(cell: Vector2i) -> int:`
- `func get_ap_cost(cell: Vector2i) -> int:`
- `func build_path_to(target: Vector2i) -> Array[Vector2i]:`

---

### `path_preview.gd`

`class_name PathPreview` · extends `Node2D` · 61 lines

`godot/scripts/navigation/path_preview.gd`

**Constants / tuning**
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `PREVIEW_LINE` = `Color(1.0, 0.79, 0.18, 0.95)`
- `PREVIEW_FILL` = `Color(1.0, 0.76, 0.20, 0.22)`
- `TARGET_LINE` = `Color(1.0, 0.45, 0.10, 0.95)`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func setup(tile_layer: TileMapLayer, offset: Vector2) -> void:`
- `func set_path(cells: Array[Vector2i], ap_cost: int) -> void:`
- `func clear_path() -> void:`

---

## overlays/

### `ceiling_prop_overlay.gd`

`class_name CeilingPropOverlay` · extends `Node2D` · 47 lines

`godot/scripts/overlays/ceiling_prop_overlay.gd`

**Constants / tuning**
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2, ceiling_lift: float) -> void:`
- `func set_lights(light_sources: Array) -> void:`

---

### `elite_exposure_overlay.gd`

extends `Node2D` · 233 lines

`godot/scripts/overlays/elite_exposure_overlay.gd`

> EliteExposureOverlay — Advanced Tactical Vision for Stealth Mastery Displays sophisticated shadow semantics: - Shadow depth (gradient 0-6) - Exposure confidence (reliability of darkness) - Structural vs temporal shadows - Risk contours and safe corridors - Temporal instability zones NOT visible in normal gameplay. Appears in: - DEV_VISION overlay - Spectator modes - Future elite HUD (equipment unlock) Purpose: Enable high-skill stealth mastery and tactical reading.

**Constants / tuning**
- `ExposureSystemClass` = `preload("res://godot/scripts/systems/lighting/exposure_system.gd")`

**Public vars**
- `var depth_gradient: Dictionary = { 5: Color.RED,              # FULL_LIT (danger) 4: Color.ORANGE,           # DIM 3: Color.YELLOW,           # PENUMBRA 2: Color.GREEN,            # SHADOW 1: Color.CYAN,             # DEEP_SHADOW 0: Color.BLUE,             # OCCLUDED_VOID (extreme stealth) }`
- `var stability_colors: Dictionary = { "static": Color.LIGHT_GREEN,     # Structural: reliable "temporal": Color.YELLOW,        # Flicker: unreliable "dynamic": Color.ORANGE,         # Moving: temporary "occluded": Color.BLUE,          # Structural void: ultimate }`
- `var confidence_gradient_low: Color = Color.RED`
- `var confidence_gradient_high: Color = Color.GREEN`
- `var show_depth: bool = true`
- `var show_confidence: bool = true`
- `var show_stability: bool = false`
- `var show_contours: bool = false`
- `var show_risk_zones: bool = false`
- `var show_safe_corridors: bool = false`
- `var overlay_opacity: float = 0.4`
- `var exposure_system = null`
- `var floor_layer: TileMapLayer = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func load_exposure_system(sys) -> void:`
- `func toggle_mode(mode: String) -> void:`
- `func debug_info() -> String:`

---

### `exposure_overlay.gd`

extends `Node2D` · 143 lines

`godot/scripts/overlays/exposure_overlay.gd`

> ExposureOverlay — Tactical Visibility Classification Visualization Displays the semantic stealth visibility of each tile as computed by ExposureSystem. This overlay shows tactical exposure, NOT visual brightness. Colors represent stealth risk: - Yellow: FULL_LIT (high risk) - Orange: DIM (moderate risk) - Blue: PENUMBRA (low risk) - Purple: SHADOW (minimal risk) - Dark Blue/Black: DEEP_SHADOW (hidden)

**Constants / tuning**
- `EXPOSURE_SYSTEM_CLASS` = `preload("res://godot/scripts/systems/lighting/exposure_system.gd")`

**Public vars**
- `var exposure_system`
- `var floor_layer: TileMapLayer = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_show_labels(show_labels: bool) -> void:`

---

### `guard_noise_indicator.gd`

extends `Node2D` · 83 lines

`godot/scripts/overlays/guard_noise_indicator.gd`

**Constants / tuning**
- `COLOR_LOW` = `Color(0.95, 0.65, 0.2, 1.0)`
- `COLOR_HIGH` = `Color(0.95, 0.3, 0.15, 1.0)`
- `FONT_SIZE` = `24`
- `INDICATOR_RADIUS` = `120.0`
- `INDICATOR_FLOAT_DIST` = `40.0`
- `INDICATOR_DURATION` = `1.8`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2) -> void:`
- `func add_indicator(agent_world_pos: Vector2, noise_world_pos: Vector2, intensity: float) -> void:`

---

### `height_overlay.gd`

extends `Node2D` · 258 lines

`godot/scripts/overlays/height_overlay.gd`

> HeightOverlay — DEV visualization of height classes and structural semantics Displays: - Height classes (FLOOR, LOW_COVER, HUMAN, TALL, OVERHEAD) - Structural categories - Occluders and light blockers - Light anchor sockets - Subfloor hazards Color coding makes semantic information immediately readable. Shows the "worldbuilding reality" independent of sprite appearance.

**Constants / tuning**
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`
- `LightAnchorClass` = `preload("res://godot/scripts/systems/lighting/light_anchor.gd")`

**Public vars**
- `var tile_semantics_map: Dictionary = {}`
- `var light_anchors: Array = []`
- `var floor_layer: TileMapLayer = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var height_colors := { 0: Color(0.8, 0.7, 0.6, 0.6),           # Tan (FLOOR) 1: Color(0.6, 0.8, 0.6, 0.6),           # Light green (LOW_COVER) 2: Color(0.7, 0.7, 1.0, 0.6),           # Light blue (HUMAN) 3: Color(0.9, 0.6, 0.6, 0.6),           # Light red (TALL) 4: Color(0.8, 0.6, 0.9, 0.6),           # Light purple (OVERHEAD) }`
- `var struct_colors := { TileSemanticsClass.STRUCT_FLOOR: Color(0.9, 0.8, 0.7, 0.5), TileSemanticsClass.STRUCT_LOW_COVER: Color(0.5, 0.9, 0.5, 0.5), TileSemanticsClass.STRUCT_WALL: Color(0.8, 0.4, 0.4, 0.5), TileSemanticsClass.STRUCT_TALL: Color(0.9, 0.5, 0.4, 0.5), TileSemanticsClass.STRUCT_OVERHEAD: Color(0.7, 0.6, 0.9, 0.5), }`
- `var show_height: bool = true`
- `var show_structural: bool = false`
- `var show_blockers: bool = true`
- `var show_anchors: bool = true`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func toggle_mode(mode: String) -> void:`
- `func load_semantics(semantics_map: Dictionary) -> void:`
- `func load_anchors(anchors: Array) -> void:`

---

### `light_overlay.gd`

extends `Node2D` · 114 lines

`godot/scripts/overlays/light_overlay.gd`

> LightOverlay — Visual debug overlay for light sources Shows: - Light position and radius - Light type and height class - Direction vectors (for cone/directional types) - Active/inactive state Only visible in DEV_VISION mode.

**Constants / tuning**
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `LightRegistryClass` = `preload("res://godot/scripts/systems/lighting/light_registry.gd")`

**@export**
- `light_registry = null`
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func is_dev_vision_enabled() -> bool:`

---

### `noise_overlay.gd`

extends `Node2D` · 58 lines

`godot/scripts/overlays/noise_overlay.gd`

**Public API**
- `func setup( room_ref: Node2D, floor_layer: TileMapLayer, visual_offset: Vector2, noise_system ) -> void:`

---

### `shadow_overlay.gd`

extends `Node2D` · 89 lines

`godot/scripts/overlays/shadow_overlay.gd`

> ShadowOverlay — Debug visualization of shadow projection Shows computed shadow topology from ShadowProjector. Only visible in DEV_VISION mode. Display includes: - Directly lit tiles (bright green) - Penumbra/dim zone (yellow) - Shadow tiles (dark blue) - Deep shadow tiles (very dark) - Occlusion boundaries (red outline)

**Constants / tuning**
- `ShadowResultClass` = `preload("res://godot/scripts/systems/lighting/shadow_result.gd")`

**@export**
- `shadow_projector = null`
- `light_registry = null`
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func is_dev_vision_enabled() -> bool:`

---

### `temporal_overlay.gd`

extends `Node2D` · 223 lines

`godot/scripts/overlays/temporal_overlay.gd`

> TemporalOverlay — DEV Visualization of Temporal Lighting Effects Displays: - Light positions and temporal states (ON/OFF/FLICKER/PULSE) - Energy levels and multipliers - Rotation directions for spotlights - Frequency information (flicker intervals, pulse speeds) Updated every frame to show real-time temporal animation. Purpose: Validate stealth temporal behavior, debug timing, ensure auditability.

**Constants / tuning**
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`

**Public vars**
- `var state_colors: Dictionary = { "on": Color.WHITE,           # Fully on "off": Color(0.2, 0.2, 0.2), # Off/dark "flicker": Color.YELLOW,     # Flickering "pulse": Color.CYAN,         # Pulsing }`
- `var show_lights: bool = true`
- `var show_state_labels: bool = true`
- `var show_energy_bars: bool = true`
- `var show_rotations: bool = true`
- `var light_registry = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var all_lights: Array = []`
- `var flicker_animation_phase: float = 0.0`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func load_lights(registry) -> void:`
- `func debug_info() -> String:`

---

### `tile_overlay.gd`

extends `Node2D` · 201 lines

`godot/scripts/overlays/tile_overlay.gd`

**Constants / tuning**
- `TILE_HW` = `128.0`
- `TILE_HH` = `64.0`
- `PRIO_SHADOW` = `1`
- `PRIO_DETECT` = `2`
- `PRIO_MOVEMENT` = `3`
- `PRIO_NAV` = `4`
- `PRIO_DEV` = `5`
- `PALETTE` = `{ ## Shadows — cool-blue tint, intensity encoded as the RGB multiply factor. ## Each step keeps a different fraction of floor brightness → smooth gradient, ## floor texture reads through at every level. "shadow_full":   Color(0.48, 0.48, 0.58, 1.0),  ## darkest — keeps ~48% brightness "shadow_mid":    Color(0.60, 0.60, 0.68, 1.0),  ## keeps ~60% "shadow_lite":   Color(0.70, 0.70, 0.78, 1.0),  ## penumbra — keeps ~70% "lit":           Color(1.00, 1.00, 1.00, 0.00),  ## no overlay (skipped: alpha≈0) ## Artistic shadow spill — soft cosmetic halo around full-shadow tiles. ## Lighter RGB than shadow_full → a gentle gradient toward lit, not a second dark ## band. PURELY VISUAL: detection reads the exposure grid, never this overlay — ## so the spill softens the silhouette without offering any hiding value. "shadow_spill_near": Color(0.82, 0.82, 0.87, 1.0),  ## ring 1 (≤1 tile) — keeps ~82% "shadow_spill_far":  Color(0.92, 0.92, 0.95, 1.0),  ## ring 2 (2 tiles) — keeps ~92% ## Detection cone — 5 probability bands "detect_0":      Color(0.30, 1.00, 0.30, 0.70),  ## 0.0–0.2   light green "detect_1":      Color(0.60, 0.95, 0.50, 0.75),  ## 0.2–0.4 "detect_2":      Color(1.00, 0.95, 0.30, 0.75),  ## 0.4–0.6   yellow "detect_3":      Color(1.00, 0.60, 0.30, 0.75),  ## 0.6–0.8   orange "detect_4":      Color(1.00, 0.20, 0.20, 0.80),  ## 0.8–1.0   red ## Exits and markers "exit":          Color(0.55, 0.10, 0.90, 0.28),  ## pure purple — segment exits "spawn":         Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn position "spawn_dev":     Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn in DEV_VISION ## Objectives "objective":     Color(0.90, 0.75, 0.20, 0.75),  ## gold/amber — primary objective "secondary":     Color(0.75, 0.75, 0.75, 0.60),  ## light gray — secondary }`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2 = Vector2.ZERO) -> void:`
- `func paint(cell: Vector2i, color: Color, priority: int = 0) -> void:`
- `func paint_named(cell: Vector2i, palette_key: String, priority: int = 0) -> void:`
- `func unpaint(cell: Vector2i) -> void:`
- `func clear_priority(priority: int) -> void:`
- `func clear_all() -> void:`
- `func set_cells(cells: Array[Vector2i], color: Color, priority: int = 0) -> void:`
- `func set_cells_named(cells: Array[Vector2i], palette_key: String, priority: int = 0) -> void:`

---

### `tile_risk_overlay.gd`

extends `Node2D` · 110 lines

`godot/scripts/overlays/tile_risk_overlay.gd`

> TileRiskOverlay — Tactical Threat Heatmap Visualization Displays per-tile risk/threat assessment based on tactical exposure. Shows detection probability heatmap (red = danger, blue = safe). Color gradient: Blue (safe) → Green → Yellow → Orange → Red (danger)

**Public vars**
- `var exposure_system`
- `var floor_layer: TileMapLayer = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`

---

### `trail_overlay.gd`

extends `Node2D` · 43 lines

`godot/scripts/overlays/trail_overlay.gd`

**Public API**
- `func setup(room_ref: Node2D, floor_layer: TileMapLayer, visual_offset: Vector2) -> void:`

---

## systems/

### `enemy_phase_controller.gd`

`class_name EnemyPhaseController` · extends `Node` · 80 lines

`godot/scripts/systems/enemy_phase_controller.gd`

**Constants / tuning**
- `DEFAULT_VISION_RANGE` = `6`

**Public API**
- `func run_single_guard_turn( guard, player_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i, occupied: Dictionary, tic_callback: Callable,   ## room._apply_tic_result noise_callback: Callable  ## M2-14: room._on_guard_emits_noise (guard noise emission) ) -> Dictionary:`
- `func build_blocked_edge_set(edges: Array[Dictionary]) -> Dictionary:`

---

### `exposure_system.gd`

`class_name ExposureSystem` · extends `Node` · 553 lines

`godot/scripts/systems/lighting/exposure_system.gd`

> ExposureSystem — Tactical Exposure & Stealth Semantics Responsibility: Convert shadow topology into discrete visibility classes for tactical stealth queries and gameplay semantics. This system: - Does NOT render or project shadows - Does NOT control AI perception (yet) - Does interpret lighting topology as stealth risk The exposure grid maps each tile to a semantic visibility class that gameplay and AI can query to make stealth decisions.

**Constants / tuning**
- `FULL_LIT` = `5`
- `DIM` = `4`
- `PENUMBRA` = `3`
- `SHADOW` = `2`
- `DEEP_SHADOW` = `1`
- `OCCLUDED_VOID` = `0`
- `CLASS_NAMES` = `{ FULL_LIT: "FULL_LIT", DIM: "DIM", PENUMBRA: "PENUMBRA", SHADOW: "SHADOW", DEEP_SHADOW: "DEEP_SHADOW", OCCLUDED_VOID: "OCCLUDED_VOID", }`
- `STABILITY_STATIC` = `"static"`
- `STABILITY_TEMPORAL` = `"temporal"`
- `STABILITY_DYNAMIC` = `"dynamic"`
- `STABILITY_OCCLUDED` = `"occluded"`
- `STABILITY_NAMES` = `{ STABILITY_STATIC: "Static", STABILITY_TEMPORAL: "Temporal", STABILITY_DYNAMIC: "Dynamic", STABILITY_OCCLUDED: "Occluded", }`
- `DETECTION_MULT` = `{ FULL_LIT:      1.00,    # Agent fully visible (100% base chance) DIM:           0.80,    # Dimly lit (80% base chance) PENUMBRA:      0.55,    # Edge of shadow (55% base chance) SHADOW:        0.30,    # Concealed in shadow (30% base chance) DEEP_SHADOW:   0.10,    # Hidden in deep shadow (10% base chance) OCCLUDED_VOID: 0.01,    # Extreme stealth (1% base chance, elite only) }`

**Public vars**
- `var blocked_cells: Dictionary = {}`
- `var blocked_edges: Dictionary = {}`
- `var confidence_static: float = 0.90`
- `var confidence_dynamic: float = 0.50`
- `var confidence_temporal: float = 0.25`
- `var confidence_occluded: float = 1.00`

**Public API**
- `func set_room_size(size: Vector2i) -> void:`
- `func set_structural_data(cells: Dictionary, edges: Dictionary) -> void:`
- `func rebuild_from_shadow_result(result) -> void:`
- `func rebuild_from_results(results: Array) -> void:`
- `func get_cells_by_exposure(level: int) -> Array[Vector2i]:`
- `func get_shadow_cells() -> Array[Vector2i]:`
- `func get_penumbra_cells() -> Array[Vector2i]:`
- `func get_visibility_class(cell: Vector2i) -> int:`
- `func is_hidden(cell: Vector2i) -> bool:`
- `func get_exposure_label(cell: Vector2i) -> String:`
- `func get_tiles_by_class(target_class: int) -> Array:`
- `func get_exposure_stats() -> Dictionary:`
- `func get_detection_multiplier(cell: Vector2i) -> float:`
- `func get_tile_risk(cell: Vector2i) -> float:`
- `func get_tile_debug_info(cell: Vector2i) -> String:`
- `func get_shadow_depth(cell: Vector2i) -> int:`
- `func get_exposure_confidence(cell: Vector2i) -> float:`
- `func is_structurally_hidden(cell: Vector2i) -> bool:`
- `func get_shadow_stability(cell: Vector2i) -> String:`
- `func get_structurally_hidden_tiles() -> Array:`
- `func get_tiles_by_stability(stability_type: String) -> Array:`
- `func clear() -> void:`

---

### `light_anchor.gd`

`class_name LightAnchor` · extends `RefCounted` · 136 lines

`godot/scripts/systems/lighting/light_anchor.gd`

> LightAnchor — Semantic light placement socket Represents a natural attachment point for light sources. Decouples light placement from visual art. Anchors serve as "sockets" where level design specifies valid light positions. Examples: ceiling mount, wall sconce, floor uplighter, column spotlight.

**Constants / tuning**
- `TYPE_CEILING` = `"ceiling"`
- `TYPE_WALL` = `"wall"`
- `TYPE_FLOOR` = `"floor"`
- `TYPE_COLUMN` = `"column"`
- `TYPE_SPOTLIGHT` = `"spotlight"`
- `TYPE_AMBIENT` = `"ambient"`

**Public vars**
- `var anchor_cell: Vector2i = Vector2i.ZERO`
- `var anchor_type: String = TYPE_CEILING`
- `var anchor_height: int = 0`
- `var emission_direction: Vector2i = Vector2i.DOWN`
- `var light_radius: int = 4`
- `var light_intensity: float = 1.0`
- `var light_color: Color = Color.WHITE`
- `var authored: bool = true`
- `var locked: bool = false`
- `var description: String = ""`

**Public API**
- `func is_valid() -> bool:`
- `func get_expected_direction() -> Vector2i:`
- `func debug_string() -> String:`
- `func debug_info() -> String:`

---

### `light_registry.gd`

`class_name LightRegistry` · extends `Node` · 141 lines

`godot/scripts/systems/lighting/light_registry.gd`

> LightRegistry — Centralized light source management Responsibilities: ✓ Register/unregister lights ✓ Query lights by position/properties ✓ Track ownership and state Does NOT: ✗ Render lights ✗ Calculate shadows ✗ Compute exposure ✗ Manage visual effects Pure data storage and queries for the lighting system.

**Signals**
- `signal light_registered(light)`
- `signal light_removed(light)`

**Constants / tuning**
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`

**Public API**
- `func register_light(light) -> void:`
- `func remove_light(light_id: String) -> void:`
- `func get_all_lights() -> Array:`
- `func get_active_lights() -> Array:`
- `func get_lights_by_type(light_type: String) -> Array:`
- `func get_lights_affecting_cell(target_cell: Vector2i) -> Array:`
- `func get_lights_at_cell(cell: Vector2i) -> Array:`
- `func get_light(light_id: String):`
- `func get_light_count() -> int:`
- `func is_empty() -> bool:`
- `func update_temporal_all(delta: float) -> Array:`
- `func clear_all() -> void:`

---

### `light_source.gd`

`class_name LightSource` · extends `RefCounted` · 214 lines

`godot/scripts/systems/lighting/light_source.gd`

> LightSource — Explicit light entity with semantic ownership Foundation for tactical lighting system. Defines: - Spatial properties (position, height, radius) - Type semantics (omni, directional, cone, ambient) - Energy levels (tactical, visual) - Direction for directional/cone types Does NOT define: - shadow projection - exposure calculation - color/visual appearance - runtime animation

**Constants / tuning**
- `TYPE_OMNI` = `"omni"`
- `TYPE_DIRECTIONAL` = `"directional"`
- `TYPE_CONE` = `"cone"`
- `TYPE_AMBIENT` = `"ambient"`
- `TYPE_INTERMITTENT` = `"intermittent"`
- `TYPE_EMERGENCY` = `"emergency"`
- `TYPE_MOBILE` = `"mobile"`
- `HEIGHT_FLOOR` = `0`
- `HEIGHT_LOW_COVER` = `1`
- `HEIGHT_HUMAN` = `2`
- `HEIGHT_TALL_STRUCTURE` = `3`
- `HEIGHT_OVERHEAD` = `4`
- `STATE_ON` = `"on"`
- `STATE_OFF` = `"off"`
- `STATE_FLICKER` = `"flicker"`
- `STATE_PULSE` = `"pulse"`

**Public vars**
- `var cell: Vector2i = Vector2i.ZERO`
- `var height_class: int = HEIGHT_OVERHEAD`
- `var light_type: String = TYPE_OMNI`
- `var radius: int = 5`
- `var active: bool = true`
- `var direction_angle: float = 0.0`
- `var cone_angle: float = 90.0`
- `var tactical_energy: float = 1.0`
- `var visual_energy: float = 1.0`
- `var flicker_enabled: bool = false`
- `var flicker_interval: float = 1.0`
- `var flicker_phase: float = 0.0`
- `var pulse_enabled: bool = false`
- `var pulse_speed: float = 1.0`
- `var pulse_phase: float = 0.0`
- `var pulse_min: float = 0.5`
- `var pulse_max: float = 1.0`
- `var rotation_speed: float = 0.0`
- `var rotation_phase: float = 0.0`
- `var current_state: String = STATE_ON`
- `var energy_multiplier: float = 1.0`
- `var changed_this_frame: bool = false`
- `var last_energy: float = 1.0`
- `var last_angle: float = 0.0`
- `var light_id: String = ""`
- `var owner_name: String = ""`

**Public API**
- `func update_temporal_state(delta: float) -> void:`
- `func set_flicker(enabled: bool, interval: float = 1.0) -> void:`
- `func set_pulse(enabled: bool, speed: float = 1.0, min_energy: float = 0.5, max_energy: float = 1.0) -> void:`
- `func set_rotation(speed_radians_per_sec: float) -> void:`
- `func get_effective_tactical_energy() -> float:`
- `func debug_temporal_state() -> String:`
- `func affects_cell(target_cell: Vector2i) -> bool:`
- `func get_direction_vector() -> Vector2:`
- `func get_cone_spread() -> float:`

---

### `shadow_projector.gd`

`class_name ShadowProjector` · extends `Node` · 253 lines

`godot/scripts/systems/lighting/shadow_projector.gd`

> ShadowProjector — Geometric (tiered + penumbra) floor-shadow projection For each light, classifies reachable cells (clear LOS within radius) as fully_lit / dim, then casts a *geometric* shadow from each occluding object: the shadow falls in the grid direction away from the light, with a length derived from object-height tier × light-height factor × a mild distance stretch (deterministic, not random). The shadow tip softens to penumbra. Slice 1 (VIS-01): object shadows from blocked_cells. Wall-edge floor shadows and multi-tile silhouette width are future work. Does NOT: - blend shadows from multiple lights (ExposureSystem max-merges per cell) - cache results (caller manages ShadowResult lifetime) - render visualization (that's ShadowOverlay's job)

**Constants / tuning**
- `ShadowResultClass` = `preload("res://godot/scripts/systems/lighting/shadow_result.gd")`
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `WallEdgeDataClass` = `preload("res://godot/scripts/world/wall_edge_data.gd")`

**Public vars**
- `var blocked_cells: Dictionary = {}`
- `var blocked_edges: Dictionary = {}`
- `var room_size: Vector2i = Vector2i.ZERO`
- `var obstacle_heights: Dictionary = {}`
- `var near_band_ratio: float = 0.65`
- `var min_blocker_height: int = 1`
- `var height_tier_length: Dictionary = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4}`
- `var light_height_factor: Dictionary = {0: 1.6, 1: 1.4, 2: 1.2, 3: 0.9, 4: 0.6}`
- `var distance_stretch: float = 0.06`
- `var max_shadow_length: int = 6`

**Public API**
- `func project_light(light):`
- `func set_blocked_cells(cells: Dictionary) -> void:`
- `func set_blocked_edges(edges: Dictionary) -> void:`
- `func set_obstacle_heights(heights: Dictionary) -> void:`
- `func set_room_size(size: Vector2i) -> void:`

---

### `shadow_result.gd`

`class_name ShadowResult` · extends `RefCounted` · 152 lines

`godot/scripts/systems/lighting/shadow_result.gd`

> ShadowResult — Grid-based shadow projection result Stores computed shadow topology from a single light source. Designed for: - auditability (can inspect exact tile classifications) - determinism (same light always produces same result) - extensibility (supports all 5 visibility classes) Does NOT: - render (that's ShadowOverlay's job) - cache (caller manages lifetime) - perform physics (discrete grid only)

**Public vars**
- `var fully_lit_tiles: Dictionary = {}`
- `var dim_tiles: Dictionary = {}`
- `var penumbra_tiles: Dictionary = {}`
- `var shadow_tiles: Dictionary = {}`
- `var deep_shadow_tiles: Dictionary = {}`
- `var source_light: LightSource = null`
- `var computed_tile_count: int = 0`

**Public API**
- `func add_tile(cell: Vector2i, visibility_class: String) -> void:`
- `func is_fully_lit(cell: Vector2i) -> bool:`
- `func is_shadowed(cell: Vector2i) -> bool:`
- `func is_penumbra(cell: Vector2i) -> bool:`
- `func get_visibility_class(cell: Vector2i) -> String:`
- `func get_tiles_by_class(visibility_class: String) -> Array[Vector2i]:`
- `func merge(other: ShadowResult) -> void:`
- `func clear() -> void:`

---

### `noise_system.gd`

`class_name NoiseSystem` · 58 lines

`godot/scripts/systems/noise_system.gd`

**Constants / tuning**
- `NOISE_CHANCE_WALK` = `0.20`
- `NOISE_CHANCE_RUN` = `0.80`
- `NOISE_INTENSITY_WALK` = `0.5`
- `NOISE_INTENSITY_RUN` = `1.0`
- `NOISE_DECAY_PER_TURN` = `0.25`
- `NOISE_RADIUS` = `2`

**Public API**
- `func emit(tile: Vector2i, intensity: float) -> void:`
- `func decay_all() -> void:`
- `func get_intensity(tile: Vector2i) -> float:`
- `func get_noisy_tiles() -> Array:`
- `func clear() -> void:`

---

### `tic_system.gd`

`class_name TicSystem` · 124 lines

`godot/scripts/systems/tic_system.gd`

**Constants / tuning**
- `STATE_MULTIPLIER` = `{ "patrol":     0.55, "suspicious": 1.60, "search":      0.80, "alert":      2.00, "chase":      2.80, }`
- `DETECTION_GAIN_PER_TIC` = `0.4`
- `HEARING_RADIUS` = `2`

---

### `turn_manager.gd`

`class_name TacticalTurnManager` · extends `Node` · 70 lines

`godot/scripts/systems/turn_manager.gd`

**Signals**
- `signal ap_changed(current_ap: int, max_ap: int)`
- `signal enemy_phase_started`
- `signal player_turn_started`

**Public vars**
- `var max_ap: int = 2`
- `var move_points_per_ap: int = 3`
- `var current_ap: int`
- `var is_enemy_phase: bool = false`

**Public API**
- `func reset_player_turn() -> void:`
- `func end_turn() -> void:`
- `func finish_enemy_phase() -> void:`
- `func get_max_move_points() -> int:`
- `func can_afford_path_cost(path_cost: int) -> bool:`
- `func spend_for_path_cost(path_cost: int) -> bool:`
- `func consume_ap(amount: int) -> void:`
- `func path_cost_to_ap(path_cost: int) -> int:`

---

## tools/

### `build_tileset.gd`

extends `SceneTree` · 282 lines

`godot/scripts/tools/build_tileset.gd`

**Constants / tuning**
- `TILES_PATH` = `"res://ASSETS/ISOMETRIC/blocks-prototype/Isometric/"`
- `TILESET_OUT` = `"res://godot/resources/tilesets/tileset_blocks.tres"`
- `REGISTRY_OUT` = `"res://godot/scripts/world/tile_registry.gd"`
- `CELL_SIZE` = `Vector2i(256, 128)`
- `PNG_SIZE` = `Vector2i(256, 512)`
- `SPRITE_OFFSET` = `Vector2i(0, -384)`
- `EDGE_VISUAL_OFFSETS` = `{ "N": Vector2i(64, -32), "S": Vector2i(-64, 32), "E": Vector2i(64, 32), "W": Vector2i(-64, -32), }`
- `TILE_PROPS` = `{ # Floor "floor":                  {walkable=true,  cover=false, interactive=false}, "floorHalf":              {walkable=true,  cover=false, interactive=false}, "floorQuarter":           {walkable=true,  cover=false, interactive=false}, # Solid blocks "block":                  {walkable=false, cover=true,  interactive=false}, "blockHalf":              {walkable=false, cover=true,  interactive=false}, "blockAngle":             {walkable=false, cover=true,  interactive=false}, "blockQuarter":           {walkable=false, cover=true,  interactive=false}, # Walls "wall":                   {walkable=false, cover=true,  interactive=false}, "wallHalf":               {walkable=false, cover=true,  interactive=false}, "wallCorner":             {walkable=false, cover=true,  interactive=false}, "wallCornerHalf":         {walkable=false, cover=true,  interactive=false}, "wallCurve":              {walkable=false, cover=true,  interactive=false}, "wallCurveHalf":          {walkable=false, cover=true,  interactive=false}, "wallBattlement":         {walkable=false, cover=true,  interactive=false}, # Windows "window":                 {walkable=false, cover=false, interactive=false}, "windowLeft":             {walkable=false, cover=false, interactive=false}, "windowMiddle":           {walkable=false, cover=false, interactive=false}, "windowRight":            {walkable=false, cover=false, interactive=false}, # Doors / passages "doorClosed":             {walkable=false, cover=false, interactive=true}, "doorOpen":               {walkable=true,  cover=false, interactive=true}, "doorway":                {walkable=true,  cover=false, interactive=false}, "doorwayBottom":          {walkable=true,  cover=false, interactive=false}, "doorwayCenter":          {walkable=true,  cover=false, interactive=false}, "doorwayLeft":            {walkable=true,  cover=false, interactive=false}, "doorwayLeftBottom":      {walkable=true,  cover=false, interactive=false}, "doorwayMiddle":          {walkable=true,  cover=false, interactive=false}, "doorwayMiddleBottom":    {walkable=true,  cover=false, interactive=false}, "doorwayRight":           {walkable=true,  cover=false, interactive=false}, "doorwayRightBottom":     {walkable=true,  cover=false, interactive=false}, # Cover props "crate":                  {walkable=false, cover=true,  interactive=true}, # Structural details "column":                 {walkable=false, cover=false, interactive=false}, "columnBlocks":           {walkable=false, cover=false, interactive=false}, "columnCorner":           {walkable=false, cover=false, interactive=false}, "pole":                   {walkable=false, cover=false, interactive=false}, "poleGroup":              {walkable=false, cover=false, interactive=false}, "fence":                  {walkable=false, cover=false, interactive=false}, # Slopes / ramps "slope":                  {walkable=true,  cover=false, interactive=false}, "slopeHalf":              {walkable=true,  cover=false, interactive=false}, "slopeQuarter":           {walkable=true,  cover=false, interactive=false}, "slopeSmall":             {walkable=true,  cover=false, interactive=false}, "sloperCornerInner":      {walkable=true,  cover=false, interactive=false}, "sloperCornerOuter":      {walkable=true,  cover=false, interactive=false}, # Stairs "stairs":                 {walkable=true,  cover=false, interactive=false}, "stairsCornerInner":      {walkable=true,  cover=false, interactive=false}, "stairsCornerOuter":      {walkable=true,  cover=false, interactive=false}, "stairsOpen":             {walkable=true,  cover=false, interactive=false}, "stairsOpenCornerInner":  {walkable=true,  cover=false, interactive=false}, "stairsOpenCornerOuter":  {walkable=true,  cover=false, interactive=false}, "steps":                  {walkable=true,  cover=false, interactive=false}, "ladder":                 {walkable=true,  cover=false, interactive=true}, # Slabs / platforms "slab":                   {walkable=true,  cover=false, interactive=false}, "slabHalf":               {walkable=true,  cover=false, interactive=false}, "slabAngle":              {walkable=true,  cover=false, interactive=false}, "slabQuarter":            {walkable=true,  cover=false, interactive=false}, # Switches / triggers "switchFloorOff":         {walkable=true,  cover=false, interactive=true}, "switchFloorOn":          {walkable=true,  cover=false, interactive=true}, "switchWallOff":          {walkable=false, cover=false, interactive=true}, "switchWallOn":           {walkable=false, cover=false, interactive=true}, # Direction markers "arrow":                  {walkable=true,  cover=false, interactive=false}, "arrowWall":              {walkable=false, cover=false, interactive=false}, }`
- `EDGE_ALIGNED_PREFIXES` = `[ "arrowWall", "door", "fence", "switchWall", "wall", "window", ]`
- `EDGE_ALIGNED_EXCLUSIONS` = `[ "wallCorner", "wallCornerHalf", "wallCurve", "wallCurveHalf", "wallBattlement", ]`

---

## ui/

### `compass_rose.gd`

extends `Control` · 56 lines

`godot/scripts/ui/compass_rose.gd`

> CompassRose — debug overlay showing isometric N/E/S/W on screen. Drawn at the bottom-right corner in screen space (CanvasLayer child). Directions assume dimetric 45° horizontal: N = upper-right  |  E = lower-right S = lower-left   |  W = upper-left

**Constants / tuning**
- `ARROW_LEN` = `44.0`
- `LABEL_GAP` = `12.0`
- `CORNER_PAD` = `Vector2(80.0, 80.0)`
- `_DIRS` = `[ {"lbl": "N", "dir": Vector2( 1.0, -1.0)}, {"lbl": "E", "dir": Vector2( 1.0,  1.0)}, {"lbl": "S", "dir": Vector2(-1.0,  1.0)}, {"lbl": "W", "dir": Vector2(-1.0, -1.0)}, ]`
- `_COL_ARROW` = `Color(1.0, 1.0, 1.0, 0.85)`
- `_COL_LABEL` = `Color(1.0, 0.9, 0.2, 1.0)`
- `_COL_BG` = `Color(0.0, 0.0, 0.0, 0.45)`

---

### `fog_of_war_overlay.gd`

`class_name FogOfWarOverlay` · extends `Node2D` · 154 lines

`godot/scripts/ui/fog_of_war_overlay.gd`

**Constants / tuning**
- `TILE_HALF_W` = `128.0`
- `TILE_HALF_H` = `64.0`
- `FOG_COLOR` = `Color(0.04, 0.04, 0.09, 0.93)`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2, room_size: Vector2i) -> void:`
- `func reveal_around(center: Vector2i, radius: int) -> void:`
- `func reset_fog() -> void:`
- `func add_peek_reveal(cell: Vector2i) -> void:`
- `func reset_peek_reveals() -> void:`
- `func is_cell_revealed(cell: Vector2i) -> bool:`

---

### `selection_overlay.gd`

extends `Node2D` · 39 lines

`godot/scripts/ui/selection_overlay.gd`

**Constants / tuning**
- `COLOR_PINK` = `Color(0.90, 0.10, 0.45, 1.0)`
- `LINE_W` = `4.0`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_selected(cell: Vector2i) -> void:`
- `func clear_selected() -> void:`

---

### `tile_labels_overlay.gd`

extends `Node2D` · 34 lines

`godot/scripts/ui/tile_labels_overlay.gd`

**Constants / tuning**
- `FONT_SIZE` = `40`
- `COLOR_LABEL` = `Color(0.0, 0.0, 0.0, 1.0)`
- `COLOR_SHADOW` = `Color(1.0, 1.0, 1.0, 0.60)`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var room_w: int = 0`
- `var room_h: int = 0`

---

## world/

### `level_graph.gd`

`class_name LevelGraph` · extends `RefCounted` · 103 lines

`godot/scripts/world/level_graph.gd`

**Constants / tuning**
- `SEG_SIZE` = `Vector2i(18, 36)`
- `EXIT_CELLS` = `{ "NW": Vector2i(9, 0), "SE": Vector2i(9, 35), "SW": Vector2i(0, 17), "NE": Vector2i(17, 17), }`

**Public API**
- `func generate(seed_input: int) -> Dictionary:`

---

### `playground_map.gd`

`class_name PlaygroundMap` · extends `RefCounted` · 75 lines

`godot/scripts/world/maps/definitions/playground_map.gd`

---

### `procedural_map.gd`

`class_name ProceduralMap` · extends `RefCounted` · 25 lines

`godot/scripts/world/maps/definitions/procedural_map.gd`

---

### `sigma_01_map.gd`

`class_name Sigma01Map` · extends `RefCounted` · 82 lines

`godot/scripts/world/maps/definitions/sigma_01_map.gd`

---

### `map_catalog.gd`

`class_name MapCatalog` · extends `RefCounted` · 29 lines

`godot/scripts/world/maps/map_catalog.gd`

**Constants / tuning**
- `PlaygroundMapClass` = `preload("res://godot/scripts/world/maps/definitions/playground_map.gd")`
- `Sigma01MapClass` = `preload("res://godot/scripts/world/maps/definitions/sigma_01_map.gd")`
- `ProceduralMapClass` = `preload("res://godot/scripts/world/maps/definitions/procedural_map.gd")`
- `DEFAULT_MAP_ID` = `"PLAYGROUND"`

---

### `map_compiler.gd`

`class_name MapCompiler` · extends `RefCounted` · 247 lines

`godot/scripts/world/maps/map_compiler.gd`

**Constants / tuning**
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `MapGeometryClass` = `preload("res://godot/scripts/world/maps/map_geometry.gd")`
- `REQUIRED_KEYS` = `["inner_size", "agent_start"]`

---

### `map_geometry.gd`

`class_name MapGeometry` · extends `RefCounted` · 140 lines

`godot/scripts/world/maps/map_geometry.gd`

---

### `room.gd`

extends `Node2D` · 1767 lines

`godot/scripts/world/room.gd`

**Constants / tuning**
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `GuardEnemyClass` = `preload("res://godot/scripts/agents/guard_enemy.gd")`
- `GuardNoiseIndicatorClass` = `preload("res://godot/scripts/overlays/guard_noise_indicator.gd")`
- `CeilingPropOverlayClass` = `preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")`
- `TileOverlayClass` = `preload("res://godot/scripts/overlays/tile_overlay.gd")`
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`
- `VisionControllerClass` = `preload("res://godot/scripts/controllers/vision_controller.gd")`
- `HudControllerClass` = `preload("res://godot/scripts/controllers/hud_controller.gd")`
- `LightingControllerClass` = `preload("res://godot/scripts/controllers/lighting_controller.gd")`
- `CameraControllerClass` = `preload("res://godot/scripts/controllers/camera_controller.gd")`
- `FowControllerClass` = `preload("res://godot/scripts/controllers/fow_controller.gd")`
- `GuardCoordinatorClass` = `preload("res://godot/scripts/controllers/guard_coordinator.gd")`
- `TILESET_PATH` = `"res://godot/resources/tilesets/tileset_blocks.tres"`
- `INVALID_CELL` = `Vector2i(-9999, -9999)`
- `VISUAL_GRID_OFFSET` = `Vector2(0.0, 512.0)`
- `WALL_BASE_Z_INDEX` = `10`
- `WALL_FLOOR_STEP_PX` = `158.0`
- `SHADOW_MULT` = `GuardEnemy.SHADOW_MULT`
- `PENUMBRA_MULT` = `GuardEnemy.PENUMBRA_MULT`
- `OBSTACLE_HEIGHTS` = `{ "crate":     1.0, "wall":      2.0, "block":     2.0, "column":    3.0, "half_wall": 1.0, }`
- `OBSTACLE_HEIGHT_DEFAULT` = `1.5`
- `VISION_TILE_RADIUS` = `5`
- `FOW_REVEAL_RADIUS` = `9`
- `WORLD_TILE_PX` = `128.0`
- `DETECTION_THRESHOLD_SUSPICIOUS` = `0.30`
- `DETECTION_THRESHOLD_ALERT` = `0.60`
- `DETECTION_THRESHOLD_CHASE` = `1.00`
- `ENEMY_INTER_TURN_DELAY` = `1.0`
- `ENEMY_CAMERA_TWEEN_DURATION` = `0.45`
- `ENEMY_PHASE_MAX_OPEN_ZOOM` = `0.65`
- `ACTOR_END_HOLD_DELAY` = `0.5`
- `_PERSPECTIVE_SUFFIX_MAP` = `{ "N": {"NE": "NE", "SE": "SE", "SW": "SW", "NW": "NW"}, "E": {"NE": "SE", "SE": "SW", "SW": "NW", "NW": "NE"}, "S": {"NE": "SW", "SE": "NW", "SW": "NE", "NW": "SE"}, "W": {"NE": "NW", "SE": "NE", "SW": "SE", "NW": "SW"}, }`
- `TRAIL_MAX` = `5`
- `GUARD_NOISE_CHANCE_BY_STATE` = `{ "patrol": 0.15, "suspicious": 0.40, "alert": 0.60, "chase": 0.70, "search": 0.50, }`
- `GUARD_NOISE_INTENSITY_BY_STATE` = `{ "patrol": 0.4, "suspicious": 0.6, "alert": 0.9, "chase": 1.0, "search": 0.7, }`

**@export**
- `segment_grid_pos: Vector2i = Vector2i(1, 1)`
- `level_seed: int = 0`
- `map_id: String = "PLAYGROUND"`

**Public vars**
- `var vision_bonus_tiles: int = 0`

---

### `tile_registry.gd`

`class_name TileRegistry` · extends `RefCounted` · 248 lines

`godot/scripts/world/tile_registry.gd`

> AUTO-GENERATED by godot/scripts/tools/build_tileset.gd Re-run the builder whenever tiles are added or renamed. Maps tile_name strings to TileSet source_ids.

**Constants / tuning**
- `TILES` = `{ "arrowWall_SW": 0, "arrowWall_SE": 1, "arrowWall_NW": 2, "arrowWall_NE": 3, "arrow_SW": 4, "arrow_SE": 5, "arrow_NW": 6, "arrow_NE": 7, "blockAngle_SW": 8, "blockAngle_SE": 9, "blockAngle_NW": 10, "blockAngle_NE": 11, "blockHalf_SW": 12, "blockHalf_SE": 13, "blockHalf_NW": 14, "blockHalf_NE": 15, "blockQuarter_SW": 16, "blockQuarter_SE": 17, "blockQuarter_NW": 18, "blockQuarter_NE": 19, "block_SW": 20, "block_SE": 21, "block_NW": 22, "block_NE": 23, "columnBlocks_SW": 24, "columnBlocks_SE": 25, "columnBlocks_NW": 26, "columnBlocks_NE": 27, "columnCorner_SW": 28, "columnCorner_SE": 29, "columnCorner_NW": 30, "columnCorner_NE": 31, "column_SW": 32, "column_SE": 33, "column_NW": 34, "column_NE": 35, "crate_SW": 36, "crate_SE": 37, "crate_NW": 38, "crate_NE": 39, "doorClosed_SW": 40, "doorClosed_SE": 41, "doorClosed_NW": 42, "doorClosed_NE": 43, "doorOpen_SW": 44, "doorOpen_SE": 45, "doorOpen_NW": 46, "doorOpen_NE": 47, "doorwayBottom_SW": 48, "doorwayBottom_SE": 49, "doorwayBottom_NW": 50, "doorwayBottom_NE": 51, "doorwayCenter_SW": 52, "doorwayCenter_SE": 53, "doorwayCenter_NW": 54, "doorwayCenter_NE": 55, "doorwayLeftBottom_SW": 56, "doorwayLeftBottom_SE": 57, "doorwayLeftBottom_NW": 58, "doorwayLeftBottom_NE": 59, "doorwayLeft_SW": 60, "doorwayLeft_SE": 61, "doorwayLeft_NW": 62, "doorwayLeft_NE": 63, "doorwayMiddleBottom_SW": 64, "doorwayMiddleBottom_SE": 65, "doorwayMiddleBottom_NW": 66, "doorwayMiddleBottom_NE": 67, "doorwayMiddle_SW": 68, "doorwayMiddle_SE": 69, "doorwayMiddle_NW": 70, "doorwayMiddle_NE": 71, "doorwayRightBottom_SW": 72, "doorwayRightBottom_SE": 73, "doorwayRightBottom_NW": 74, "doorwayRightBottom_NE": 75, "doorwayRight_SW": 76, "doorwayRight_SE": 77, "doorwayRight_NW": 78, "doorwayRight_NE": 79, "doorway_SW": 80, "doorway_SE": 81, "doorway_NW": 82, "doorway_NE": 83, "fence_SW": 84, "fence_SE": 85, "fence_NW": 86, "fence_NE": 87, "floorHalf_SW": 88, "floorHalf_SE": 89, "floorHalf_NW": 90, "floorHalf_NE": 91, "floorQuarter_SW": 92, "floorQuarter_SE": 93, "floorQuarter_NW": 94, "floorQuarter_NE": 95, "floor_SW": 96, "floor_SE": 97, "floor_NW": 98, "floor_NE": 99, "ladder_SW": 100, "ladder_SE": 101, "ladder_NW": 102, "ladder_NE": 103, "poleGroup_SW": 104, "poleGroup_SE": 105, "poleGroup_NW": 106, "poleGroup_NE": 107, "pole_SW": 108, "pole_SE": 109, "pole_NW": 110, "pole_NE": 111, "slabAngle_SW": 112, "slabAngle_SE": 113, "slabAngle_NW": 114, "slabAngle_NE": 115, "slabHalf_SW": 116, "slabHalf_SE": 117, "slabHalf_NW": 118, "slabHalf_NE": 119, "slabQuarter_SW": 120, "slabQuarter_SE": 121, "slabQuarter_NW": 122, "slabQuarter_NE": 123, "slab_SW": 124, "slab_SE": 125, "slab_NW": 126, "slab_NE": 127, "slopeHalf_SW": 128, "slopeHalf_SE": 129, "slopeHalf_NW": 130, "slopeHalf_NE": 131, "slopeQuarter_SW": 132, "slopeQuarter_SE": 133, "slopeQuarter_NW": 134, "slopeQuarter_NE": 135, "slopeSmall_SW": 136, "slopeSmall_SE": 137, "slopeSmall_NW": 138, "slopeSmall_NE": 139, "slope_SW": 140, "slope_SE": 141, "slope_NW": 142, "slope_NE": 143, "sloperCornerInner_SW": 144, "sloperCornerInner_SE": 145, "sloperCornerInner_NW": 146, "sloperCornerInner_NE": 147, "sloperCornerOuter_SW": 148, "sloperCornerOuter_SE": 149, "sloperCornerOuter_NW": 150, "sloperCornerOuter_NE": 151, "stairsCornerInner_SW": 152, "stairsCornerInner_SE": 153, "stairsCornerInner_NW": 154, "stairsCornerInner_NE": 155, "stairsCornerOuter_SW": 156, "stairsCornerOuter_SE": 157, "stairsCornerOuter_NW": 158, "stairsCornerOuter_NE": 159, "stairsOpenCornerInner_SW": 160, "stairsOpenCornerInner_SE": 161, "stairsOpenCornerInner_NW": 162, "stairsOpenCornerInner_NE": 163, "stairsOpenCornerOuter_SW": 164, "stairsOpenCornerOuter_SE": 165, "stairsOpenCornerOuter_NW": 166, "stairsOpenCornerOuter_NE": 167, "stairsOpen_SW": 168, "stairsOpen_SE": 169, "stairsOpen_NW": 170, "stairsOpen_NE": 171, "stairs_SW": 172, "stairs_SE": 173, "stairs_NW": 174, "stairs_NE": 175, "steps_SW": 176, "steps_SE": 177, "steps_NW": 178, "steps_NE": 179, "switchFloorOff_SW": 180, "switchFloorOff_SE": 181, "switchFloorOff_NW": 182, "switchFloorOff_NE": 183, "switchFloorOn_SW": 184, "switchFloorOn_SE": 185, "switchFloorOn_NW": 186, "switchFloorOn_NE": 187, "switchWallOff_SW": 188, "switchWallOff_SE": 189, "switchWallOff_NW": 190, "switchWallOff_NE": 191, "switchWallOn_SW": 192, "switchWallOn_SE": 193, "switchWallOn_NW": 194, "switchWallOn_NE": 195, "wallBattlement_SW": 196, "wallBattlement_SE": 197, "wallBattlement_NW": 198, "wallBattlement_NE": 199, "wallCornerHalf_SW": 200, "wallCornerHalf_SE": 201, "wallCornerHalf_NW": 202, "wallCornerHalf_NE": 203, "wallCorner_SW": 204, "wallCorner_SE": 205, "wallCorner_NW": 206, "wallCorner_NE": 207, "wallCurveHalf_SW": 208, "wallCurveHalf_SE": 209, "wallCurveHalf_NW": 210, "wallCurveHalf_NE": 211, "wallCurve_SW": 212, "wallCurve_SE": 213, "wallCurve_NW": 214, "wallCurve_NE": 215, "wallHalf_SW": 216, "wallHalf_SE": 217, "wallHalf_NW": 218, "wallHalf_NE": 219, "wall_SW": 220, "wall_SE": 221, "wall_NW": 222, "wall_NE": 223, "windowLeft_SW": 224, "windowLeft_SE": 225, "windowLeft_NW": 226, "windowLeft_NE": 227, "windowMiddle_SW": 228, "windowMiddle_SE": 229, "windowMiddle_NW": 230, "windowMiddle_NE": 231, "windowRight_SW": 232, "windowRight_SE": 233, "windowRight_NW": 234, "windowRight_NE": 235, "window_SW": 236, "window_SE": 237, "window_NW": 238, "window_NE": 239, }`

---

### `tile_semantics.gd`

`class_name TileSemantics` · extends `RefCounted` · 222 lines

`godot/scripts/world/tile_semantics.gd`

> TileSemantics — Semantic metadata for worldbuilding Centralizes height classes, structural meaning, stealth modifiers, and flags. Decouples tile behavior from visual representation. This is the source of truth for tile meaning in the lighting system.

**Constants / tuning**
- `HEIGHT_FLOOR` = `0`
- `HEIGHT_LOW_COVER` = `1`
- `HEIGHT_HUMAN` = `2`
- `HEIGHT_TALL_STRUCTURE` = `3`
- `HEIGHT_OVERHEAD` = `4`
- `STRUCT_FLOOR` = `"floor"`
- `STRUCT_LOW_COVER` = `"low_cover"`
- `STRUCT_WALL` = `"wall"`
- `STRUCT_TALL` = `"tall"`
- `STRUCT_OVERHEAD` = `"overhead"`
- `LAYER_SUBFLOOR` = `0`
- `LAYER_PLAYABLE` = `1`
- `LAYER_STRUCTURAL` = `2`
- `LAYER_OVERHEAD` = `3`
- `HEIGHT_NAMES` = `{ HEIGHT_FLOOR: "FLOOR", HEIGHT_LOW_COVER: "LOW_COVER", HEIGHT_HUMAN: "HUMAN", HEIGHT_TALL_STRUCTURE: "TALL", HEIGHT_OVERHEAD: "OVERHEAD", }`
- `STRUCT_NAMES` = `{ STRUCT_FLOOR: "Floor", STRUCT_LOW_COVER: "LowCover", STRUCT_WALL: "Wall", STRUCT_TALL: "Tall", STRUCT_OVERHEAD: "Overhead", }`
- `LAYER_NAMES` = `{ LAYER_SUBFLOOR: "L0-Subfloor", LAYER_PLAYABLE: "L1-Playable", LAYER_STRUCTURAL: "L2-Structural", LAYER_OVERHEAD: "L3-Overhead", }`

**Public vars**
- `var height_class: int = HEIGHT_FLOOR`
- `var structural_type: String = STRUCT_FLOOR`
- `var layer_assignment: int = LAYER_PLAYABLE`
- `var receives_shadow: bool = true`
- `var receives_light: bool = true`
- `var blocks_los: bool = false`
- `var blocks_light: bool = false`
- `var blocks_shadow: bool = false`
- `var stealth_modifier: float = 1.0`
- `var acoustic_dampening: float = 0.0`
- `var is_light_anchor: bool = false`
- `var anchor_type: String = ""`
- `var has_hazard: bool = false`
- `var hazard_type: String = ""`

**Public API**
- `func obstructs_light() -> bool:`
- `func obstructs_los() -> bool:`
- `func is_valid_light_socket() -> bool:`
- `func can_receive_shadow() -> bool:`
- `func can_receive_light() -> bool:`
- `func debug_string() -> String:`
- `func debug_info() -> String:`

---

### `wall_edge_data.gd`

`class_name WallEdgeData` · 39 lines

`godot/scripts/world/wall_edge_data.gd`

> Consolidated edge key generation and wall blocking logic. Centralizes edge handling to prevent duplication and enable consistent future enhancements.

---
