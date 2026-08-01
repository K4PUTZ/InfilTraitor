# CODEMAP — INFILTRAITOR

> **GENERATED FILE — do not edit by hand.**
> Produced by `tools/persistent/gen_codemap.py` from the actual GDScript
> source. Regenerate with `python3 tools/persistent/gen_codemap.py`.
> A pre-commit hook blocks commits when this file is stale.
>
> Design rationale and the inviolable rules live in `CLAUDE.md`
> (hand-authored). This file is the mechanical mirror of the code.

**163 scripts · 35228 lines total** (under `godot/scripts/`)

## Index

- **agents/** — agent.gd, guard_attention.gd, guard_enemy.gd
- **controllers/** — camera_controller.gd, fow_controller.gd, guard_coordinator.gd, hud_controller.gd, lighting_controller.gd, vision_controller.gd
- **debug/** — dev_vision_status_panel.gd, map_loader_panel.gd, theme_matrix_debug_view.gd, voxel_ruler_overlay.gd
- **geometry/** — edge.gd, edge_extractor.gd, edge_registry.gd, face.gd, geometry_coords.gd, high_wall.gd, junction_resolver.gd, slab.gd, slab_generator.gd, slab_registry.gd, slice.gd, slice_generator.gd, voxel.gd, voxel_renderer.gd
- **navigation/** — guard_pathfinder.gd, movement_overlay.gd, path_preview.gd
- **overlays/** — blast_wireframe_overlay.gd, ceiling_prop_overlay.gd, elite_exposure_overlay.gd, ember_overlay.gd, exposure_overlay.gd, floating_collectible.gd, grenade_prop.gd, gu_grid_overlay.gd, guard_noise_indicator.gd, height_overlay.gd, light_overlay.gd, light_ray_overlay.gd, noise_overlay.gd, occlusion_overlay.gd, occlusion_slice_panel.gd, occlusion_wireframe_overlay.gd, shadow_boundary_overlay.gd, shadow_overlay.gd, temporal_overlay.gd, tile_overlay.gd, tile_risk_overlay.gd, trail_overlay.gd
- **systems/** — bake_compositor.gd, bake_config.gd, bake_policy.gd, baked_tile_lookup.gd, collectible_bake_config.gd, collectible_frame_cache.gd, blast_calculator.gd, bomb_def.gd, bomb_registry.gd, material_resistance_table.gd, weapon_def.gd, weapon_registry.gd, earth_variant_selector.gd, enemy_phase_controller.gd, facade_sampler.gd, exposure_system.gd, light_anchor.gd, light_registry.gd, light_source.gd, shadow_projector.gd, shadow_result.gd, voxel_light_field.gd, localization_manager.gd, material_registry.gd, metal_pattern.gd, noise_system.gd, occlusion_set.gd, prop_def.gd, prop_registry.gd, registries_autoload.gd, stone_pattern.gd, texture_resolver.gd, theme_applier.gd, tic_system.gd, turn_manager.gd, version_info.gd, wood_pattern.gd
- **tools/** — actor_frame_bake_spike.gd, actor_part0_spike.gd, bake_cache_test.gd, bake_selftest.gd, bake_voxel_sprite_3d.gd, blast_calculator_selftest.gd, build_tileset.gd, destruction_part0_spike.gd, earth_variant_selftest.gd, fixed_floor_selftest.gd, floor_integration_selftest.gd, floor_zone_bake_selftest.gd, geometry_selftest.gd, grenade_collectible_bake_spike.gd, grenade_frame_bake_spike.gd, input_controller_test.gd, map_lint.gd, mapfile_roundtrip_test.gd, negative_storey_selftest.gd, neon_flicker_selftest.gd, occlusion_set_test.gd, panel_base_test.gd, project_lint_validator.gd, prop_01_tests.gd, resolver_hardening_tests.gd, roof_bake_selftest.gd, roof_integration_selftest.gd, roof_slab_selftest.gd, shotgun_preview_spike.gd, slab_geometry_selftest.gd, slab_render_selftest.gd, slice_geometry_selftest.gd, texture_resolver_selftest.gd, tile_anatomy_audit.gd, version_info_test.gd, voxel_light_incremental_selftest.gd, voxel_persist_selftest.gd, weapon_frames_bake.gd
- **ui/** — controls_panel.gd, detonate_context_menu.gd, enemy_banner_panel.gd, fog_of_war_overlay.gd, main_menu_panel.gd, modal_stack.gd, panel_base.gd, selection_overlay.gd, showcase_panel.gd, tile_labels_overlay.gd, top_bar_panel.gd, window_base.gd
- **world/** — room_builder.gd, debug_tools_controller.gd, input_controller.gd, selection_controller.gd, test_zone_controller.gd, turn_controller.gd, weapon_bench_controller.gd, world_markers_overlay_controller.gd, level_graph.gd, playground_map.gd, procedural_map.gd, sigma_01_map.gd, file_map_source.gd, map_catalog.gd, map_compiler.gd, map_geometry.gd, map_file_service.gd, map_section_registry.gd, map_sections_v1.gd, room.gd, tile_registry.gd, tile_semantics.gd, perspective_mapper.gd, wall_edge_data.gd

---

## agents/

### `agent.gd`

`class_name DebugAgent` · extends `Node2D` · 241 lines

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
- `SILHOUETTE_WIDTH` = `44.0`
- `SILHOUETTE_HEIGHT` = `61.0`
- `SILHOUETTE_OUTLINE_COLOR` = `Color(1.0, 1.0, 1.0, 0.3)`
- `SILHOUETTE_OUTLINE_WIDTH` = `1.5`

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

`class_name GuardEnemy` · extends `Node2D` · 1111 lines

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

extends `Node` · 211 lines

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
- `func set_zoom_for_capture(new_z: float) -> void:`

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

extends `Node` · 184 lines

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
- `func show_busted(text_key: String = "ui.banner.busted") -> void:`
- `func hide_busted() -> void:`
- `func is_auto_end_turn_enabled() -> bool:`
- `func set_numbers_button_active(active: bool) -> void:`
- `func set_viewport_button_text(text: String) -> void:`

---

### `lighting_controller.gd`

extends `Node` · 270 lines

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
- `func get_shadow_results() -> Array:`
- `func rebuild() -> void:`
- `func rebuild_all() -> void:`
- `func rebuild_deferred() -> void:`

---

### `vision_controller.gd`

extends `Node2D` · 297 lines

`godot/scripts/controllers/vision_controller.gd`

**Constants / tuning**
- `LightOverlayClass` = `preload("res://godot/scripts/overlays/light_overlay.gd")`
- `ShadowOverlayClass` = `preload("res://godot/scripts/overlays/shadow_overlay.gd")`
- `ExposureOverlayClass` = `preload("res://godot/scripts/overlays/exposure_overlay.gd")`
- `TileRiskOverlayClass` = `preload("res://godot/scripts/overlays/tile_risk_overlay.gd")`
- `HeightOverlayClass` = `preload("res://godot/scripts/overlays/height_overlay.gd")`
- `TemporalOverlayClass` = `preload("res://godot/scripts/overlays/temporal_overlay.gd")`
- `EliteExposureOverlayClass` = `preload("res://godot/scripts/overlays/elite_exposure_overlay.gd")`

---

## debug/

### `dev_vision_status_panel.gd`

`class_name DevVisionStatusPanel` · extends `Control` · 117 lines

`godot/scripts/debug/dev_vision_status_panel.gd`

> DEV-HUD-01: DEV VISION systems status panel Displays live state of bake, vision, color systems, and debug toggles. Single-source rule: reads live state from owning systems each frame (no internal state copies). Refresh: on-frame timer (fast enough for F6/F7/H/L/V feedback).

**Constants / tuning**
- `UPDATE_INTERVAL` = `0.1`

**Public API**
- `func setup(room_ref: Node) -> void:`

---

### `map_loader_panel.gd`

extends `ConfirmationDialog` · 64 lines

`godot/scripts/debug/map_loader_panel.gd`

**Constants / tuning**
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`

**Public API**
- `func setup(room: Node2D) -> void:`

---

### `theme_matrix_debug_view.gd`

`class_name ThemeMatrixDebugView` · extends `CanvasLayer` · 170 lines

`godot/scripts/debug/theme_matrix_debug_view.gd`

> ThemeMatrixDebugView — Visual grid showing all materials × all themes Reveals saturation issues before they reach gameplay. Press F5 to toggle visibility.

**Public vars**
- `var is_active: bool = false`
- `var material_registry`
- `var theme_list: Array[Color] = []`

**Public API**
- `func toggle() -> void:`
- `func render_matrix() -> void:`

---

### `voxel_ruler_overlay.gd`

`class_name VoxelRulerOverlay` · extends `Node2D` · 103 lines

`godot/scripts/debug/voxel_ruler_overlay.gd`

**Constants / tuning**
- `VOXEL_TILE_SIZE` = `Vector2i(32, 16)`
- `FLOOR_TILE_SIZE` = `Vector2i(256, 128)`
- `VOXELS_PER_AXIS` = `8`
- `VOXEL_LINE_COLOR` = `Color(0.0, 1.0, 1.0, 0.25)`
- `GU_LINE_COLOR` = `Color(0.0, 1.0, 1.0, 0.5)`
- `VOXEL_LINE_WIDTH` = `0.5`
- `GU_LINE_WIDTH` = `1.0`

**Public vars**
- `var visible_grid: bool = false`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2, room_size: Vector2i) -> void:`

---

## geometry/

### `edge.gd`

`class_name Edge` · 84 lines

`godot/scripts/geometry/edge.gd`

> Geometry Module — Edge: logical wall between two adjacent Gameplay Units Canonical identity model: anchor = lexicographically smaller cell; face_a ∈ {SE, SW}

**Public vars**
- `var id: String`
- `var gu_a: Vector2i`
- `var gu_b: Vector2i`
- `var face_a: int`
- `var face_b: int`
- `var storey_count: int`
- `var start_storey: int`
- `var material: String`
- `var slice_a_id: String = ""`
- `var slice_b_id: String = ""`

**Public API**
- `func key_string() -> String:`

---

### `edge_extractor.gd`

`class_name EdgeExtractor` · 178 lines

`godot/scripts/geometry/edge_extractor.gd`

> Geometry Module — Edge Extractor: converts compiled map to Edge objects Ported from legacy geometry system; refined by SLICE-02 refactor (docs/history/)

**Constants / tuning**
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `_EDGE_BY_SUFFIX` = `{ "NW": Face.NW,  ## (-1, 0) "NE": Face.NE,  ## (0, -1) "SE": Face.SE,  ## (+1, 0) "SW": Face.SW,  ## (0, +1) }`

---

### `edge_registry.gd`

`class_name EdgeRegistry` · 136 lines

`godot/scripts/geometry/edge_registry.gd`

> Geometry Module — Edge Registry: single source of truth linking model Port from voxel_registry.gd with edge tracking

**Signals**
- `signal edge_registered(edge: Edge)`
- `signal slice_registered(slice: Slice)`

**Public API**
- `func register_edge(edge: Edge) -> void:`
- `func register_slice(slice: Slice) -> void:`
- `func get_edge(id: String) -> Edge:`
- `func get_slice(id: String) -> Slice:`
- `func slices_of_edge(edge_id: String) -> Array:`
- `func sibling_slice(slice_id: String) -> Slice:`
- `func edges_touching_gu(gu: Vector2i) -> Array:`
- `func all_edges() -> Array:`
- `func all_slices() -> Array:`
- `func dirty_slices() -> Array:`
- `func clear() -> void:`
- `func is_empty() -> bool:`
- `func debug_print() -> void:`

---

### `face.gd`

`class_name Face` · 49 lines

`godot/scripts/geometry/face.gd`

> Geometry Module — Face enum and helpers Single source for face semantics (per DIRECTION_GLOSSARY §3, §6)

---

### `geometry_coords.gd`

`class_name GeometryCoords` · 86 lines

`godot/scripts/geometry/geometry_coords.gd`

> Geometry Module — Coordinate constants and conversions Ported from legacy coordinate system; validated by SLICE-00 Transform Canon

**Constants / tuning**
- `VOXELS_PER_UNIT_AXIS` = `8`
- `VOXEL_TILE_SIZE` = `Vector2i(32, 16)`
- `VOXEL_STEP_PX` = `20.0`
- `VOXEL_STOREY_HEIGHT_PX` = `160.0`
- `LEVELS_PER_STOREY` = `8`
- `TEX_AUTHORING_N` = `16`
- `VOXEL_ATOM_W` = `32`
- `VOXEL_ATOM_H` = `36`
- `VOXEL_TILE_H` = `16`
- `FLOOR_TOP_LEVEL` = `-1`
- `FLOOR_DEEP_LEVEL` = `-2`

---

### `high_wall.gd`

`class_name HighWallGroup` · 69 lines

`godot/scripts/geometry/high_wall.gd`

> Geometry Module — High Wall Group: bake-time grouping container Port from world/high_wall.gd into module namespace as HighWallGroup VOXEL-08: maximal-run regrouping strategy is deferred

**Public vars**
- `var id: String`
- `var edge_ids: Array[String] = []`
- `var slice_ids: Array[String] = []`
- `var junction_columns: Array = []`
- `var bake_texture: Texture2D`
- `var baked: bool = false`
- `var dirty_count: int = 0`
- `var voxel_bounds: Rect2i`

**Public API**
- `func add_edge_with_slices(edge: Edge, slice_a: Slice, slice_b: Slice) -> void:`
- `func add_junction_columns(columns: Array) -> void:`
- `func total_voxel_count() -> int:`
- `func mark_all_dirty() -> void:`
- `func decrement_dirty() -> void:`
- `func clear_dirty() -> void:`

---

### `junction_resolver.gd`

`class_name JunctionResolver` · 139 lines

`godot/scripts/geometry/junction_resolver.gd`

> Geometry Module — Junction Resolver: fills V-junction corner columns. Rewritten (JUNCTION-02): the previous version reconstructed GU cells from voxel-index vertex coordinates and divided them back down by 8. That broke whenever a vertex used the "+7" near-edge offset (true for one axis of almost every vertex _get_edge_vertices produced) instead of a clean multiple of 8 — integer division silently floored into the wrong bucket, so the resolver picked a cell adjacent to the elbow instead of the true diagonal notch. This version never touches voxel coordinates for the detection step: it stays in GU-cell space the whole time, using the faces already recorded on each Edge. Scope: V-junctions (2 walls) and free-standing wall ends (3 walls, all genuinely open — e.g. a divider stopping next to a gate) both get filler columns, one per adjacent (non-opposite) pair of occupied faces at the cell. A true T-junction (a wall butting flush into another, already-solid wall) also presents as 3 faces on a naive count, but EdgeExtractor's exposure culling (see edge_extractor.gd) already removes the spurious flush-contact face before this ever sees it, so it correctly reduces to 2 opposite (straight-through) faces — 0 columns, nothing to fill. This only works because that culling fix landed first; see JUNCTION-01b prompt. X-junctions (4 walls) are intentionally skipped — assumed already covered by surrounding wall geometry; revisit only if a real gap is reported there.

---

### `slab.gd`

`class_name Slab` · 104 lines

`godot/scripts/geometry/slab.gd`

> Geometry Module — Slab: horizontal voxel container (floor, ceiling, interior) DESTRUCTION_MASTER_PLAN D1: the container sibling of Slice for the horizontal plane. A wall voxel belongs to a Slice which belongs to an Edge; a floor/ceiling voxel has no edge, so it gets this container instead — same dirty-count/TIC-skip contract as Slice, none of the edge-specific fields (face, edge_id). Floor, ceiling and interior cutaway are ONE class: a ceiling is a Slab at a different level/role, not a different type. See voxel.gd's Voxel._parent_container for why Voxel is shared unmodified between Slice and Slab.

**Public vars**
- `var id: String`
- `var gu_cell: Vector2i`
- `var role: int`
- `var level: int`
- `var material: String`
- `var voxels: Array[Voxel] = []`
- `var dirty_count: int = 0`
- `var texture_anchor: Vector2i = Vector2i.ZERO`

**Public API**
- `func get_voxel(index: int) -> Voxel:`

---

### `slab_generator.gd`

`class_name SlabGenerator` · 62 lines

`godot/scripts/geometry/slab_generator.gd`

> Geometry Module — Slab Generator: creates Slabs and Voxels for one GU's horizontal footprint (floor/ceiling/interior). Mirrors SliceGenerator, but a Slab has no Edge to derive from — it's just a GU cell, a role and a level.

---

### `slab_registry.gd`

`class_name SlabRegistry` · 52 lines

`godot/scripts/geometry/slab_registry.gd`

> Geometry Module — Slab Registry: single source of truth for Slab containers DESTRUCTION_MASTER_PLAN D1. Mirrors EdgeRegistry's slice-half (get/all/dirty/ clear); no edge-linking half exists because Slab voxels have no edge to link to.

**Signals**
- `signal slab_registered(slab: Slab)`

**Public API**
- `func register_slab(slab: Slab) -> void:`
- `func get_slab(id: String) -> Slab:`
- `func all_slabs() -> Array:`
- `func dirty_slabs() -> Array:`
- `func clear() -> void:`
- `func is_empty() -> bool:`
- `func debug_print() -> void:`

---

### `slice.gd`

`class_name Slice` · 73 lines

`godot/scripts/geometry/slice.gd`

> Geometry Module — Slice: wall segment on one face of one Gameplay Unit Identity reform: B-side slice carries gu_b, not gu_a Port from wall_slice.gd

**Public vars**
- `var id: String`
- `var gu_cell: Vector2i`
- `var face: int`
- `var edge_id: String`
- `var storey_count: int`
- `var start_storey: int`
- `var material: String`
- `var facade_id: String = ""`
- `var voxels: Array[Voxel] = []`
- `var dirty_count: int = 0`
- `var baked: bool = false`
- `var bake_texture: Texture2D`

**Public API**
- `func get_voxel(index: int) -> Voxel:`
- `func total_voxel_count() -> int:`
- `func mark_all_dirty() -> void:`
- `func increment_dirty() -> void:`
- `func decrement_dirty() -> void:`
- `func clear_all_dirty() -> void:`

---

### `slice_generator.gd`

`class_name SliceGenerator` · 90 lines

`godot/scripts/geometry/slice_generator.gd`

> Geometry Module — Slice Generator: creates Slices and Voxels from Edges Port from room.gd _place_wall_voxels() and _voxel_slice_positions() logic

---

### `voxel.gd`

`class_name Voxel` · 106 lines

`godot/scripts/geometry/voxel.gd`

> Geometry Module — Voxel: single 32×32 voxel in a wall slice Port from voxel_ref.gd with damage state tracking

---

### `voxel_renderer.gd`

`class_name VoxelRenderer` · extends `Node2D` · 1558 lines

`godot/scripts/geometry/voxel_renderer.gd`

> Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering Port from room.gd voxel functions, honoring Transform Canon Extends Node2D to add to scene tree

**Signals**
- `signal voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String)`

**Constants / tuning**
- `VOXEL_SOURCE_ID` = `0`
- `MATERIALS` = `[ "concrete", "metal", "stone", "wood", "glass", "earth_0", "earth_1", "earth_2", "earth_3", "earth_4", "earth_5", "earth_6", "earth_7", "concrete_dented", "concrete_cracked", "metal_dented", "metal_cracked", "stone_dented", "stone_cracked", "wood_dented", "wood_cracked", "concrete_blast_dented", "concrete_blast_cracked", "metal_blast_dented", "metal_blast_cracked", "stone_blast_dented", "stone_blast_cracked", "wood_blast_dented", "wood_blast_cracked", ## D25: the carved half-voxels, four per material — see the block comment ## above damage_variant_material(). The flat "*_blast_dented" entries just ## above them are superseded for any voxel whose carved side is known, but ## stay in this array forever: MATERIALS is append-only (source_id == index), ## and they remain the honest fallback when no epicentre bias was supplied. "concrete_blast_dented_top", "concrete_blast_dented_bottom", "concrete_blast_dented_left", "concrete_blast_dented_right", "metal_blast_dented_top", "metal_blast_dented_bottom", "metal_blast_dented_left", "metal_blast_dented_right", "stone_blast_dented_top", "stone_blast_dented_bottom", "stone_blast_dented_left", "stone_blast_dented_right", "wood_blast_dented_top", "wood_blast_dented_bottom", "wood_blast_dented_left", "wood_blast_dented_right", ]`
- `VOXEL_ASSET_TEMPLATE` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png"`
- `IMPACT_ASSET_TEMPLATE` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/impact_marks/voxel_%s.png"`
- `_IMPACT_SUFFIXES` = `[ "_dented", "_cracked", "_dented_top", "_dented_bottom", "_dented_left", "_dented_right", ]`
- `_CARVED_SIDE_SUFFIX` = `{ Voxel.CarvedSide.TOP: "_top", Voxel.CarvedSide.BOTTOM: "_bottom", Voxel.CarvedSide.LEFT: "_left", Voxel.CarvedSide.RIGHT: "_right", }`
- `FLOOR_DEPTH_DIM` = `[1.0, 0.70, 0.45, 0.34, 0.28]`
- `EMPTY_COLUMN` = `-9999`

**Public vars**
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`
- `var debug_nudge: Vector2 = Vector2.ZERO`

**Public API**
- `func setup(visual_grid_offset: Vector2, wall_base_z_index: int = 10) -> void:`
- `func set_baked_lookup(lookup) -> void:`
- `func register_baked_atlas_page(page_image: Image, atlas_coords_used: Array = [], tile_modulate: Color = Color.WHITE) -> int:`
- `func get_layer(level: int) -> TileMapLayer:`

---

## navigation/

### `guard_pathfinder.gd`

`class_name GuardPathfinder` · 80 lines

`godot/scripts/navigation/guard_pathfinder.gd`

---

### `movement_overlay.gd`

`class_name MovementOverlay` · extends `Node2D` · 260 lines

`godot/scripts/navigation/movement_overlay.gd`

**Constants / tuning**
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `BLUE_LINE` = `Color(0.25, 0.70, 1.0, 0.90)`
- `ORANGE_LINE` = `Color(1.0, 0.60, 0.20, 0.95)`
- `FILL_COLOR` = `Color(1.0, 1.0, 1.0, 1.0)`
- `PERIMETER_INSET_DISTANCE` = `6.0`

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

### `blast_wireframe_overlay.gd`

`class_name BlastWireframeOverlay` · extends `Node2D` · 76 lines

`godot/scripts/overlays/blast_wireframe_overlay.gd`

**Constants / tuning**
- `LINE_COLOR` = `Color(1.0, 0.15, 0.15, 0.9)`
- `LINE_WIDTH` = `3.0`
- `PERIMETER_INSET_DISTANCE` = `6.0`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:`
- `func show_footprint(cells) -> void:`
- `func clear() -> void:`

---

### `ceiling_prop_overlay.gd`

`class_name CeilingPropOverlay` · extends `Node2D` · 45 lines

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

### `ember_overlay.gd`

`class_name EmberOverlay` · extends `Node2D` · 75 lines

`godot/scripts/overlays/ember_overlay.gd`

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

### `floating_collectible.gd`

`class_name FloatingCollectible` · extends `Node2D` · 614 lines

`godot/scripts/overlays/floating_collectible.gd`

> ACTOR_MASTER_PLAN D21/D17/D14 — floating/rotating collectible, the reusable "simplification" display for any object (Part 6, still otherwise unspecified). First proven with the shotgun; STANDARDIZED (Director, 2026-07-28) to take its bake folder and visual scale per-instance via setup(), so every future collectible reuses this same class instead of a per-object copy. Cycles pre-rendered flat-color + normal-map frame pairs (produced by a bake tool following actor_frame_bake_spike.gd's template) through a per-pixel relighting shader (flat_normal_relight.gdshader) so the sprite shades directionally against the world's real light data — no voxel geometry, no live 3D scene at runtime, matching D16's "simplification" concept exactly. Floats with a vertical sine bob and spins continuously (Director, 2026-07-27). GROUND SHADOW (Director, 2026-07-28, re-tuned twice same day). Uses two dedicated frame_%02d_shadow_{sharp,soft}.png per frame instead of the oblique COLOR frame reused-and-squashed (that shears diagonal silhouettes and rotates their apparent angle) — a true top-down bake (actor_frame_bake_spike.gd), which has no directional foreshortening to shear when squashed. Pinned to floor height independent of the bob. Two Sprite2D layers crossfade by the object's CURRENT bob height (Director's corrected spec, replacing an earlier "wider at bottom" misread): near the floor (bottom of the bob) the shadow is small and SHARP at 80% opacity; at the top of the bob it's bigger and SOFT/diffuse at 50% opacity — real depth needs size AND focus to change together, not size alone. A fixed HOVER_HEIGHT_PX lift keeps a visible gap between object and shadow even at the bob's lowest point. Frame count and rotation speed come from CollectibleBakeConfig (godot/scripts/systems/collectible_bake_config.gd) — the bake tool that produced frames_dir MUST have used the exact same FRAME_COUNT/camera convention, or the frame index math and the light-direction math below both go wrong silently. Light-direction simplification, stated plainly rather than hidden: the game has no real 3D world space — gameplay is a 2D grid + an isometric screen projection. To relight a normal map baked from a fixed 3D camera, this maps grid-x -> bake-world-x and grid-y -> bake-world-z (an explicit, documented choice, not a derived one). PERSPECTIVE-AWARE FIX (Director, 2026-07-28, closes ACTOR_MASTER_PLAN open question #16 / D22): the grid delta between light and object is computed in the room's CURRENT view-space cells, then de-rotated back to base (North) orientation via PerspectiveMapper.cell_to_base() before the grid-x/grid-y -> world-x/world-z mapping is applied — the bake camera's fixed azimuth was always derived against a canonical N view, so feeding it a raw view-space delta from a rotated (E/S/W) perspective silently picked the wrong world direction. Same idea as TestZoneController.reposition_for_perspective(): this object also now tracks its own base_cell and re-derives its view-space gu_cell on every perspective flip (see reposition_for_perspective() below), so gu_cell never goes stale the way it used to before this fix. STATIC FACING MODE (Director, 2026-07-29 — "colocar 4 shotguns estáticas [...] apontando para [os blocos]"). The bake already contains every facing: actor_frame_bake_spike.gd renders FRAME_COUNT yaws of a full turn, so a prop that must POINT somewhere instead of spinning is the same flipbook frozen on the matching frame — no second bake, no second class. Pass a compass edge to setup()'s optional p_static_facing and the object stops spinning, stops bobbing, and holds the frame whose muzzle runs along that edge; everything else (relighting, ground shadow, depth-aware z) is shared with the spinning path byte-for-byte. See FACING_YAW_DEG for how those yaws were measured.

**Constants / tuning**
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`

---

### `grenade_prop.gd`

`class_name GrenadeProp` · extends `Sprite2D` · 182 lines

`godot/scripts/overlays/grenade_prop.gd`

> ACTOR_MASTER_PLAN objects track — grenade re-bake (2026-07-28). Replaces TestZoneController's old plain Sprite2D (a single frozen-angle bake, bake_voxel_sprite_3d.gd) with a relit prop driven by grenade_frame_bake_spike.gd's real per-direction 3D renders (one flat-color + one view-space-normal-map pair per N/E/S/W compass direction). Deliberately NOT a FloatingCollectible: this is a static ground prop, not a spinning pickup — no continuous rotation timer, no bob. The only thing that changes which of the 4 baked frames is shown is the room's active N/E/S/W perspective (the whole scene visually rotates on a perspective flip; this prop follows by swapping to the frame baked at the matching yaw, same PerspectiveMapper convention floating_collectible.gd's reposition_for_ perspective() uses). Per-pixel relighting (flat_normal_relight.gdshader) and its perspective-aware light-direction math are otherwise identical to FloatingCollectible's fixed version — see that file for the fuller rationale (ACTOR_MASTER_PLAN D22 / open question #16).

**Constants / tuning**
- `FRAMES_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/"`
- `DIRECTIONS` = `["N", "E", "S", "W"]`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`
- `ANCHOR_PX` = `Vector2(48.0, 73.15551)`
- `SPRITE_SCALE` = `0.75`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`

**Public vars**
- `var room: Node = null`
- `var gu_cell: Vector2i = Vector2i.ZERO`
- `var base_cell: Vector2i = Vector2i.ZERO`

**Public API**
- `func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i) -> void:`
- `func update_cell(p_gu_cell: Vector2i) -> void:`

---

### `gu_grid_overlay.gd`

`class_name GuGridOverlay` · extends `Node2D` · 56 lines

`godot/scripts/overlays/gu_grid_overlay.gd`

**Constants / tuning**
- `COLOR_BLACK` = `Color(0.0, 0.0, 0.0, 0.35)`
- `LINE_WIDTH` = `1.5`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:`
- `func set_room_size(room_size: Vector2i) -> void:`

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

extends `Node2D` · 121 lines

`godot/scripts/overlays/light_overlay.gd`

> LightOverlay — Visual debug overlay for light sources Shows: - Light position and radius - Light type and height class - Direction vectors (for cone/directional types) - Active/inactive state Only visible in DEV_VISION mode.

**Constants / tuning**
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `LightRegistryClass` = `preload("res://godot/scripts/systems/lighting/light_registry.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**@export**
- `light_registry = null`
- `floor_layer: TileMapLayer = null`
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func is_dev_vision_enabled() -> bool:`

---

### `light_ray_overlay.gd`

extends `Node2D` · 101 lines

`godot/scripts/overlays/light_ray_overlay.gd`

**Constants / tuning**
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**@export**
- `floor_layer: TileMapLayer = null`
- `visual_offset: Vector2 = Vector2.ZERO`

**Public vars**
- `var ray_color: Color       = Color(1.0, 0.82, 0.30, 1.0)`
- `var alpha_full_lit: float  = 1.0`
- `var alpha_dim: float       = 1.0`
- `var ceiling_lift: float    = 0.0`

**Public API**
- `func setup(fl_layer: TileMapLayer, v_offset: Vector2, lift: float) -> void:`
- `func refresh(shadow_results: Array) -> void:`

---

### `noise_overlay.gd`

extends `Node2D` · 58 lines

`godot/scripts/overlays/noise_overlay.gd`

**Public API**
- `func setup( room_ref: Node2D, floor_layer: TileMapLayer, visual_offset: Vector2, noise_system ) -> void:`

---

### `occlusion_overlay.gd`

extends `Node2D` · 139 lines

`godot/scripts/overlays/occlusion_overlay.gd`

> Occlusion Overlay — DEV visualization of occluded geometry Displays: voxel cells that occlude the agent, color-coded by ring distance. This is the only visual output of OCC-01 (geometry computation).

**Constants / tuning**
- `OcclusionSetClass` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var occlusion_set: OcclusionSetClass = null`
- `var voxel_renderer = null`
- `var voxel_tile_size: Vector2 = Vector2(32, 16)`
- `var ring_colors := { 0: Color(1.0, 0.0, 0.0, 0.5),   # Red — ring 0 (nearest, most transparent) 1: Color(1.0, 0.5, 0.0, 0.5),   # Orange — ring 1 (middle) 2: Color(1.0, 1.0, 0.0, 0.5),   # Yellow — ring 2 (outer, least transparent) }`

**Public API**
- `func set_occlusion_set(occ_set: OcclusionSetClass) -> void:`
- `func set_voxel_renderer(renderer) -> void:`

---

### `occlusion_slice_panel.gd`

extends `Node2D` · 79 lines

`godot/scripts/overlays/occlusion_slice_panel.gd`

> Occlusion Wireframe Panel — OCC-27 (2026-07-21) Draws ALL wireframe geometry for ONE LEVEL, at that level's own z_index (see occlusion_wireframe_overlay.gd for why z_index must track the real voxel layer). Supersedes the old per-structural-unit box panel (OCC-08-b through OCC-23): geometry now comes from OcclusionSet's own unified hidden-face-culling pass (_build_wireframe_geometry) over the shared occluded-column set, so this script no longer needs to know whether a given line/fill came from a wall, a junction column, or a roof. Simplified line style (Director, 2026-07-21 — "menos linhas sobrepostas, foco em arestas externas"): a "solid" line (this volume's own near side, nothing of its own bulk between it and the camera) draws as a plain solid line, no dots. A "dots" line (the volume's far side, behind its own bulk) draws as dots only, no underline — hidden-line-removal convention (CAD tradition: visible edges solid, hidden edges dashed), replacing the old "underline + dots on every edge regardless" look that read as one continuous, cluttered mesh. Fill alpha comes straight from VoxelRenderer.GHOST_ALPHAS (see that constant for the current per-ring values) — restoring OCC-19's original intent that the wireframe's glass fill uses the SAME alpha the real ghosted material already uses, not a second, independently-tuned value.

**Constants / tuning**
- `FILL_COLOR` = `Color(0.7, 0.7, 0.7)`
- `LINE_COLOR` = `Color(1.0, 1.0, 1.0, 1.0)`
- `DOT_ALPHA` = `0.5`
- `DOT_RADIUS` = `0.75`
- `DOT_BLUR_SIGMA` = `1.0`

**Public vars**
- `var fills: Array = []`
- `var lines: Array = []`

---

### `occlusion_wireframe_overlay.gd`

extends `Node2D` · 140 lines

`godot/scripts/overlays/occlusion_wireframe_overlay.gd`

> Occlusion Wireframe Overlay — OCC-27 (2026-07-21) Draws the wireframe over each occluded (erased) voxel's translucent band, reading OcclusionSet.get_wireframe_by_level() — geometry already unified across walls, junctions and roofs by OcclusionSet's own hidden-face- culling pass (see occlusion_set.gd::_build_wireframe_geometry() for why). VoxelRenderer.apply_occlusion() ghosts the band this outlines (ring alpha, OCC-08/O6); the edge's own base band underneath is left fully opaque and untouched (OCC-10) — solid enough on its own that it needs no outline. History: OCC-07-b through OCC-23 built this as one independent box PER STRUCTURAL UNIT (one per wall Edge, one per roof GU or later GU-rectangle, one disabled per junction column), each spawning its own OcclusionSlicePanel per level. OCC-27 supersedes that architecture: since the geometry is now ALREADY organized per level (one merged set of lines+fills per level, not per unit), this spawns exactly one panel PER LEVEL — no structural-unit grouping left to reason about, and far fewer nodes than before. z_index still tracks the real voxel layer per level (OCC-23): a panel for level L must draw BEHIND visible voxels at level L+1 and above, but IN FRONT of everything strictly below it (most visibly the edge's own opaque base band, OCC-10). Offset -1 puts the panel exactly between its level's layer and the one below.

**Constants / tuning**
- `OcclusionSetClass` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `SlicePanelClass` = `preload("res://godot/scripts/overlays/occlusion_slice_panel.gd")`

**Public vars**
- `var occlusion_set: OcclusionSetClass = null`
- `var voxel_renderer = null`

**Public API**
- `func set_occlusion_set(occ_set: OcclusionSetClass) -> void:`
- `func set_voxel_renderer(renderer) -> void:`

---

### `shadow_boundary_overlay.gd`

extends `Node2D` · 120 lines

`godot/scripts/overlays/shadow_boundary_overlay.gd`

> ShadowBoundaryOverlay — Always-visible shadow region visualization Renders two passes on shadow cells: 1. Semi-transparent fill (vignette effect) inside shadow tiles 2. Dark lines on boundaries where shadow meets non-shadow Uses pure drawing (no blend mode) so lines are not overridden by multiply blend. Updated whenever lighting rebuilds via set_shadow_cells().

**@export**
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func setup(floor_layer: TileMapLayer, offset: Vector2) -> void:`
- `func set_full_shadow_cells(cells: Array[Vector2i]) -> void:`
- `func set_lite_shadow_cells(cells: Array[Vector2i]) -> void:`

---

### `shadow_overlay.gd`

extends `Node2D` · 94 lines

`godot/scripts/overlays/shadow_overlay.gd`

> ShadowOverlay — Debug visualization of shadow projection Shows computed shadow topology from ShadowProjector. Only visible in DEV_VISION mode. Display includes: - Directly lit tiles (bright green) - Penumbra/dim zone (yellow) - Shadow tiles (dark blue) - Deep shadow tiles (very dark) - Occlusion boundaries (red outline)

**Constants / tuning**
- `ShadowResultClass` = `preload("res://godot/scripts/systems/lighting/shadow_result.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**@export**
- `shadow_projector = null`
- `light_registry = null`
- `floor_layer: TileMapLayer = null`
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func is_dev_vision_enabled() -> bool:`

---

### `temporal_overlay.gd`

extends `Node2D` · 262 lines

`godot/scripts/overlays/temporal_overlay.gd`

> TemporalOverlay — DEV Visualization of Temporal Lighting Effects Displays: - Light positions and temporal states (ON/OFF/FLICKER/PULSE) - Energy levels and multipliers - Rotation directions for spotlights - Frequency information (flicker intervals, pulse speeds) Updated every frame to show real-time temporal animation. Purpose: Validate stealth temporal behavior, debug timing, ensure auditability.

**Constants / tuning**
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**Public vars**
- `var state_colors: Dictionary = { "on": Color.WHITE,           # Fully on "off": Color(0.2, 0.2, 0.2), # Off/dark "flicker": Color.YELLOW,     # Flickering "pulse": Color.CYAN,         # Pulsing }`
- `var show_lights: bool = true`
- `var show_state_labels: bool = true`
- `var show_energy_bars: bool = true`
- `var show_rotations: bool = true`
- `var ui_scale: float = 1.5`
- `var light_registry = null`
- `var floor_layer: TileMapLayer = null`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var fixture_lift: float = 0.0`
- `var all_lights: Array = []`
- `var flicker_animation_phase: float = 0.0`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func load_lights(registry) -> void:`
- `func debug_info() -> String:`

---

### `tile_overlay.gd`

extends `Node2D` · 208 lines

`godot/scripts/overlays/tile_overlay.gd`

**Constants / tuning**
- `TILE_HALF_W` = `128.0`
- `TILE_HALF_H` = `64.0`
- `PRIO_SHADOW` = `1`
- `PRIO_DETECT` = `2`
- `PRIO_MOVEMENT` = `3`
- `PRIO_NAV` = `4`
- `PRIO_DEV` = `5`
- `PALETTE` = `{ ## Shadows — cool-blue tint, intensity encoded as the RGB multiply factor. ## Each step keeps a different fraction of floor brightness → smooth gradient, ## floor texture reads through at every level. "shadow_full":   Color(0.48, 0.48, 0.58, 1.0),  ## darkest — keeps ~48% brightness "shadow_mid":    Color(0.60, 0.60, 0.68, 1.0),  ## keeps ~60% "shadow_lite":   Color(0.70, 0.70, 0.78, 1.0),  ## penumbra — keeps ~70% "lit":           Color(1.00, 1.00, 1.00, 0.00),  ## no overlay (skipped: alpha≈0) ## Artistic shadow spill — soft cosmetic halo around full-shadow tiles. Its colors ## are computed PER-CELL in room._spill_color (directional + density-driven), not from ## fixed keys here, and painted via set_cells_colored(). PURELY VISUAL: detection reads ## the exposure grid, never this overlay — the spill grants no hiding value. ## Detection cone — 5 probability bands "detect_0":      Color(0.30, 1.00, 0.30, 0.70),  ## 0.0–0.2   light green "detect_1":      Color(0.60, 0.95, 0.50, 0.75),  ## 0.2–0.4 "detect_2":      Color(1.00, 0.95, 0.30, 0.75),  ## 0.4–0.6   yellow "detect_3":      Color(1.00, 0.60, 0.30, 0.75),  ## 0.6–0.8   orange "detect_4":      Color(1.00, 0.20, 0.20, 0.80),  ## 0.8–1.0   red ## Exits and markers "exit":          Color(0.55, 0.10, 0.90, 0.28),  ## pure purple — segment exits "spawn":         Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn position "spawn_dev":     Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn in DEV_VISION ## Objectives "objective":     Color(0.90, 0.75, 0.20, 0.75),  ## gold/amber — primary objective "secondary":     Color(0.75, 0.75, 0.75, 0.60),  ## light gray — secondary }`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2 = Vector2.ZERO) -> void:`
- `func paint(cell: Vector2i, color: Color, priority: int = 0) -> void:`
- `func paint_named(cell: Vector2i, palette_key: String, priority: int = 0) -> void:`
- `func unpaint(cell: Vector2i) -> void:`
- `func clear_priority(priority: int) -> void:`
- `func clear_all() -> void:`
- `func set_cells(cells: Array[Vector2i], color: Color, priority: int = 0) -> void:`
- `func set_cells_named(cells: Array[Vector2i], palette_key: String, priority: int = 0) -> void:`
- `func set_cells_colored(colored: Dictionary, priority: int = 0) -> void:`

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

### `bake_compositor.gd`

`class_name BakeCompositor` · 1133 lines

`godot/scripts/systems/bake_compositor.gd`

> BakeCompositor — Continuous-plane facade baking (OVERLORD-FIX-01) Model (replaces every previous half-face/strip scheme): A wall run is ONE continuous inclined plane on screen. Each atom carries a 32-texel-wide window of that plane, anchored at u = col*16 — consecutive atoms' windows OVERLAP by 16 texels on purpose: the occluded halves carry the same plane content as the neighbor that covers them, so every visible mix of atom fragments (sawtooth overlaps included) is seamless by construction. Runs exist in two screen directions, so atoms are baked per direction (dir 0: plane descends screen-right; dir 1: mirrored, descends screen-left) and direction is part of the lookup key. Per atom (col, row, dir), side-face content at atom pixel (x, y): dir 0:  u = col*16 + x          y_top(x) = 8 + x/2 dir 1:  u = col*16 + (31 - x)   y_top(x) = 8 + (31 - x)/2 v = (31 - row)*16 + (y - y_top(x)) * 16/20      (row 31 = top storey) Equivalently (what the code does): pre-scale the facade ×20/16 vertically, shear it ±x/2 once per direction ("plane image" P), and every atom is an axis-aligned 32×28 crop of P at (x0, (31-row)*20 + col*8 + V_MARGIN), pasted at atom-local (0, 8) — the x-terms cancel exactly, so composition is pure blit_rect with no per-pixel sampling. RGB in pages is pure facade luminance (grayscale); blend modes are applied at registration time via per-tile modulate (TEXTURE_ONLY = white, MULTIPLY = material base color). Top faces are baked as material color. Alpha = canonical voxel silhouette via blit_rect_mask + an exact byte-level fixup of the antialiased (partial-alpha) pixels (B3: alpha verbatim).

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `BakeConfigClass` = `preload("res://godot/scripts/systems/bake_config.gd")`
- `TEX_AUTHORING_N` = `GeometryCoordsClass.TEX_AUTHORING_N`
- `VOXEL_ATOM_W` = `GeometryCoordsClass.VOXEL_ATOM_W`
- `VOXEL_ATOM_H` = `GeometryCoordsClass.VOXEL_ATOM_H`
- `VOXEL_VISIBLE_Y_START` = `16`
- `SHEET_COLS` = `64`
- `SHEET_ROWS` = `32`
- `FACADE_W` = `1024`
- `FACADE_H` = `512`
- `PLANE_W` = `FACADE_W + 32`
- `V_MARGIN` = `32`
- `SCALED_H` = `640`
- `PLANE_H` = `1232`
- `PAGE_W` = `4096`
- `PAGE_TILE_COLS` = `128`
- `PAGE_H` = `576`
- `VOXEL_MATERIALS` = `["concrete", "metal", "stone", "wood", "ground_grass", "ground_concrete", "ground_dirt", "ground_gravel", "ground_sand"]`
- `VOXEL_BASE_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_"`

---

### `bake_config.gd`

`class_name BakeConfig` · 69 lines

`godot/scripts/systems/bake_config.gd`

> BakeConfig — Unified bake system configuration Master kill-switch and feature toggles for the baking pipeline. Branch-exclusive (structural, not tested); values set at boot.

---

### `bake_policy.gd`

`class_name BakePolicy` · 36 lines

`godot/scripts/systems/bake_policy.gd`

> BakePolicy — Shared deterministic rules for texture baking Ensures the bake pass and lookup pass use identical: - Facade assignment (material ID → facade ID) - Variant seeding (edge + material → [0, 4) variant)

**Constants / tuning**
- `DEFAULT_FACADES` = `{ "concrete": "facade_concrete", "stone": "facade_stone", "wood": "facade_wood", "metal": "facade_metal", ## Floor-zone bake (full-color, see MaterialRegistry.full_color): facade_id ## == material_id for these, since each ground material owns exactly one ## photographic source (no shared/reused facade across materials, unlike ## walls, where several materials could reuse a facade). "ground_grass": "ground_grass", "ground_concrete": "ground_concrete", "ground_dirt": "ground_dirt", "ground_gravel": "ground_gravel", "ground_sand": "ground_sand", }`

---

### `baked_tile_lookup.gd`

`class_name BakedTileLookup` · 419 lines

`godot/scripts/systems/baked_tile_lookup.gd`

> BakedTileLookup — Single lookup seam for placement path Insertion point between placement code and tile source selection. Query for a voxel face → either baked atlas or generic material atlas. OVERLORD-FIX-01: addresses per-direction continuous-plane sheets via (material, facade, column_in_run, level, dir) keys, with mirrored-repeat wrapping. Fallback chain: baked → generic material atlas.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`

**Public API**
- `func set_test_config(config) -> void:`
- `func set_baked_atlas(atlas) -> void:`
- `func set_source_ids(source_ids: Dictionary) -> void:`
- `func register_runs(runs: Array) -> void:`
- `func resolve(edge, face: int, voxel_xy: Vector2i, level: int = 0, column_in_run: int = -1) -> TileLookupResult:`
- `func resolve_flat(material_id: String, local_pos: Vector2i) -> TileLookupResult:`
- `func resolve_junction(voxel_pos: Vector2i, level: int) -> TileLookupResult:`

---

### `collectible_bake_config.gd`

`class_name CollectibleBakeConfig` · 67 lines

`godot/scripts/systems/collectible_bake_config.gd`

> ACTOR_MASTER_PLAN D17/D21/D14/D22 — shared bake/animation constants for every "simplification" floating collectible (FloatingCollectible + whichever bake tool produced its frames, e.g. actor_frame_bake_spike.gd). Standardized 2026-07-28 after tuning these against the shotgun so every future collectible starts from the same known-good baseline instead of re-deriving it per object. Per-object knobs (MESH_SCALE, ORTHO_SIZE, VIEWPORT_SIZE, SPRITE_SCALE) are deliberately NOT here — those depend on each model's own real-world size and stay a visual judgment call tuned per object, same convention as MESH_SCALE always has been.

**Constants / tuning**
- `FRAME_COUNT` = `120`
- `ROTATION_DEG_PER_SEC` = `36.0`
- `FRAME_SWAP_HZ` = `ROTATION_DEG_PER_SEC * FRAME_COUNT / 360.0`

---

### `collectible_frame_cache.gd`

`class_name CollectibleFrameCache` · 92 lines

`godot/scripts/systems/collectible_frame_cache.gd`

> CollectibleFrameCache — one copy of a bake's frames, shared by every prop that displays it. FRAME-MEM-01 (2026-07-29). MEASURED problem, not a suspected one: one FloatingCollectible's 480 frame textures cost **48.2 MB of real VRAM** (windowed GPU measurement). Every instance loaded its own, so the four bench shotguns held four identical copies — 241 MB for the five props already in the test zone, and a projected **1447 MB** for the 6-weapons × 4-columns + 6-pickups layout being built next. On a mobile-first project that is not a tuning problem, it is a wall. Two levers, both here: 1. SHARE per bake folder — instances of the same weapon hold one set. 2. Load only the frames a prop can actually SHOW. A spinning collectible cycles all FRAME_COUNT of them; a static prop only ever displays four (one per N/E/S/W perspective), so it has no reason to pay for 120. Frames are cached sparsely and filled in on demand, so a static prop asking for 4 and a collectible later asking for all 120 share the 4 they overlap on. Lives in the Registries autoload rather than in a `static var` on FloatingCollectible: a GDScript static var is owned by the Script resource and is torn down during GDScriptLanguage::finish(), which is exactly the unsafe window FIX-SHUTDOWN-CRASH-01b moved MapCatalog's static state out of. Autoload Nodes are freed during normal SceneTree cleanup instead.

**Constants / tuning**
- `PASSES` = `["color", "normal", "shadow_sharp", "shadow_soft"]`

**Public API**
- `func request(frames_dir: String, indices: Array) -> Dictionary:`
- `func extents_of(frames_dir: String) -> Dictionary:`
- `func describe() -> String:`

---

### `blast_calculator.gd`

`class_name BlastCalculator` · 653 lines

`godot/scripts/systems/destruction/blast_calculator.gd`

> BlastCalculator — DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Pure/static: everything it needs is passed in (no registry ownership, same statelessness as EarthVariantSelector) so it stays testable in isolation against synthetic fixtures, matching every other Part's selftest convention. Three-stage pipeline for one detonation: 1. flood_gu_rings() — wall-aware BFS from the source GU, one ring per GU step, capped at the bomb's range. Director (this session): walls block/reduce propagation — reuses the same blocked-edge gate movement_overlay.gd already uses for movement, not a naive radius. 2. find_affected_containers() — every wall Slice and roof Slab (Role. CEILING) touching a flooded GU, ring-tagged. The GU flood step IS the "walk sideways along the wall" step (a wall's own footprint GU sits in the flood like any other GU), so no separate wall-run adjacency walk is needed here. 3. apply_container_damage() — combines a container's ring multiplier with MaterialResistanceTable to get a destroy/crack voxel COUNT, then picks WHICH voxels deterministically (FNV-1a hash-and-rank, mirroring EarthVariantSelector — no RNG, same inputs always produce the same result).

**Constants / tuning**
- `GRENADE_LEVEL` = `0`
- `NO_EPICENTER_BIAS` = `Vector2i(-999999, -999999)`

---

### `bomb_def.gd`

`class_name BombDef` · 37 lines

`godot/scripts/systems/destruction/bomb_def.gd`

> BombDef — bomb/grenade definition resource. DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Mirrors PropDef's shape exactly (plain object + from_json() factory, not a Godot Resource) so multiple bomb types can be authored as data instead of hardcoded per detonation — "outras bombas terão um alcance maior ou menor, de acordo com o tipo, tamanho e habilidades de cada personagem" (Director, this session).

**Public vars**
- `var id: String`
- `var ring_multipliers: Array[float] = []`
- `var gameplay: Dictionary = {}`
- `var tags: Array[String] = []`

---

### `bomb_registry.gd`

`class_name BombRegistry` · 55 lines

`godot/scripts/systems/destruction/bomb_registry.gd`

> BombRegistry — Bomb definitions catalog (two-tier: res:// + user://). Line-for-line the PropRegistry pattern (godot/scripts/systems/prop_registry.gd): user-tier bombs override res:// bombs on id collision.

**Constants / tuning**
- `RES_BOMBS_DIR` = `"res://bombs"`
- `USER_BOMBS_DIR` = `"user://bombs"`

**Public vars**
- `var registry: Dictionary = {}`

**Public API**
- `func register(bomb_def) -> void:`
- `func get_bomb(p_id: String):`
- `func count() -> int:`
- `func load_from_disk() -> void:`

---

### `material_resistance_table.gd`

`class_name MaterialResistanceTable` · 57 lines

`godot/scripts/systems/destruction/material_resistance_table.gd`

> MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3, extended by D22. How much of a ring-group's voxels convert to DESTROYED vs DENTED vs CRACKED for a given wall/roof material. Engine-tuning data (not content-author data like BombDef), so no res://+user:// two-tier — a plain fixed table, matching bake_policy.gd's material→facade mapping shape. Ordering (resistance to destruction, most -> least), per Director (this session): metal > stone > concrete > wood. Values below are first-pass placeholders — a balancing lever (D6), not researched constants; expect these to be retuned once real captures show the effect.

**Constants / tuning**
- `TABLE` = `{ "metal":    {"destroy_factor": 0.05, "dent_factor": 0.5,  "crack_factor": 0.3}, "stone":    {"destroy_factor": 0.3,  "dent_factor": 0.3,  "crack_factor": 0.2}, "concrete": {"destroy_factor": 0.5,  "dent_factor": 0.2,  "crack_factor": 0.15}, "wood":     {"destroy_factor": 0.9,  "dent_factor": 0.05, "crack_factor": 0.03}, "glass":    {"destroy_factor": 0.7,  "dent_factor": 0.0,  "crack_factor": 0.0}, }`

---

### `weapon_def.gd`

`class_name WeaponDef` · 88 lines

`godot/scripts/systems/destruction/weapon_def.gd`

> WeaponDef — weapon definition resource. WEAPON_MASTER_PLAN Part 1 (D1/D2/D7). Mirrors BombDef's shape exactly (plain object + from_json() factory, not a Godot Resource), which itself mirrors PropDef — the fourth use of one proven pattern, not a new one. D1: a weapon that touches the scenario declares a DELIVERY SHAPE plus a STEP FALLOFF TABLE. `step_multipliers` is the generalisation of BombDef.ring_multipliers: index 0 is the weapon's own GU (full effect), each further index one step outward along whatever "outward" means for that shape, and the table's LENGTH is the weapon's range. What varies between a grenade, a shotgun and a rifle is only what one step means: RADIAL — a wall-aware BFS ring (BlastCalculator.flood_gu_rings) CONE   — the same BFS, gated to a wedge around a facing (flood_gu_cone) LINE   — penetration depth along a ray (not built yet) NONE   — no voxel damage at all; the effect belongs to perception/noise/AI Deliberately carries only fields something actually consumes today. Rarity, firerate, ammo and AP cost are NOT here — WEAPON_MASTER_PLAN D9 defers them, and a speculative field that nothing reads is a field that rots.

**Constants / tuning**
- `DELIVERY_RADIAL` = `"RADIAL"`
- `DELIVERY_CONE` = `"CONE"`
- `DELIVERY_LINE` = `"LINE"`
- `DELIVERY_NONE` = `"NONE"`
- `VALID_DELIVERIES` = `[ DELIVERY_RADIAL, DELIVERY_CONE, DELIVERY_LINE, DELIVERY_NONE, ]`

**Public vars**
- `var id: String`
- `var delivery: String = DELIVERY_NONE`
- `var step_multipliers: Array[float] = []`
- `var cone_half_angle_deg: float = 0.0`
- `var destroy_multiplier: float = 1.0`
- `var projectile_count: int = 1`
- `var gameplay: Dictionary = {}`
- `var tags: Array[String] = []`

**Public API**
- `func has_range() -> bool:`

---

### `weapon_registry.gd`

`class_name WeaponRegistry` · 57 lines

`godot/scripts/systems/destruction/weapon_registry.gd`

> WeaponRegistry — Weapon definitions catalog (two-tier: res:// + user://). WEAPON_MASTER_PLAN Part 1 (D7). Line-for-line the BombRegistry pattern (which is itself line-for-line PropRegistry): user-tier weapons override res:// weapons on id collision, and a new weapons/*.json needs ZERO code changes to appear.

**Constants / tuning**
- `RES_WEAPONS_DIR` = `"res://weapons"`
- `USER_WEAPONS_DIR` = `"user://weapons"`

**Public vars**
- `var registry: Dictionary = {}`

**Public API**
- `func register(weapon_def) -> void:`
- `func get_weapon(p_id: String):`
- `func count() -> int:`
- `func load_from_disk() -> void:`

---

### `earth_variant_selector.gd`

`class_name EarthVariantSelector` · 33 lines

`godot/scripts/systems/earth_variant_selector.gd`

> EarthVariantSelector — DESTRUCTION_MASTER_PLAN D2/D4 core. Floor/slab voxels don't have corners or continuous facade planes to project (unlike walls) — they're just a small pre-authored palette of voxel atoms, scattered across the grid by a deterministic hash of position. This is the whole mechanism: no shear, no junction compositor, no per-map baking step. Determinism is the entire point (D5): hash(x, y, level) is recomputed identically forever, never stored. A voxel's look never changes just because a neighbour got destroyed and exposed it — there is nothing to "pop" because nothing was ever assigned; it's re-derived the same way every time it's looked at.

**Constants / tuning**
- `VARIANT_COUNT` = `8`
- `ASSET_PATH_TEMPLATE` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_earth_%d.png"`

---

### `enemy_phase_controller.gd`

`class_name EnemyPhaseController` · extends `Node` · 80 lines

`godot/scripts/systems/enemy_phase_controller.gd`

**Constants / tuning**
- `DEFAULT_VISION_RANGE` = `6`

**Public API**
- `func run_single_guard_turn( guard, player_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i, occupied: Dictionary, tic_callback: Callable,   ## room._apply_tic_result noise_callback: Callable  ## M2-14: room._on_guard_emits_noise (guard noise emission) ) -> Dictionary:`
- `func build_blocked_edge_set(edges: Array[Dictionary]) -> Dictionary:`

---

### `facade_sampler.gd`

`class_name FacadeSampler` · 115 lines

`godot/scripts/systems/facade_sampler.gd`

> FacadeSampler — Sample the infinite facade plane via mirrored-repeat addressing The facade is a concrete texture (64N × 32N pixels) that defines an infinite deterministic plane via mirrored repetition. Given a coordinate in the infinite plane, return the luminance from the wrapped texture.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public API**
- `func sample(facade: Image, plane_x: float, plane_y: float) -> float:`
- `func get_window_origin_run_texels(canonical_min_edge, facade_id: String) -> Vector2i:`
- `func get_window_origin_isolated_texels(edge, facade_id: String) -> Vector2i:`

---

### `exposure_system.gd`

`class_name ExposureSystem` · extends `Node` · 484 lines

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
- `func rebuild_from_results(results: Array) -> void:`
- `func get_cells_by_exposure(level: int) -> Array[Vector2i]:`
- `func get_shadow_cells() -> Array[Vector2i]:`
- `func get_penumbra_cells() -> Array[Vector2i]:`
- `func get_visibility_class(cell: Vector2i) -> int:`
- `func get_exposure_label(cell: Vector2i) -> String:`
- `func get_tiles_by_class(target_class: int) -> Array:`
- `func get_exposure_stats() -> Dictionary:`
- `func get_detection_multiplier(cell: Vector2i) -> float:`
- `func get_tile_risk(cell: Vector2i) -> float:`
- `func get_tile_debug_info(cell: Vector2i) -> String:`
- `func get_shadow_depth(cell: Vector2i) -> int:`
- `func get_exposure_confidence(cell: Vector2i) -> float:`
- `func get_shadow_stability(cell: Vector2i) -> String:`
- `func get_structurally_hidden_tiles() -> Array:`
- `func clear() -> void:`

---

### `light_anchor.gd`

`class_name LightAnchor` · extends `RefCounted` · 104 lines

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
- `func debug_string() -> String:`
- `func debug_info() -> String:`

---

### `light_registry.gd`

`class_name LightRegistry` · extends `Node` · 111 lines

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
- `func is_empty() -> bool:`
- `func update_temporal_all(delta: float) -> Array:`
- `func clear_all() -> void:`

---

### `light_source.gd`

`class_name LightSource` · extends `RefCounted` · 257 lines

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

`class_name ShadowResult` · extends `RefCounted` · 144 lines

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
- `func is_shadowed(cell: Vector2i) -> bool:`
- `func get_visibility_class(cell: Vector2i) -> String:`
- `func get_tiles_by_class(visibility_class: String) -> Array[Vector2i]:`
- `func merge(other: ShadowResult) -> void:`
- `func clear() -> void:`

---

### `voxel_light_field.gd`

`class_name VoxelLightField` · extends `RefCounted` · 408 lines

`godot/scripts/systems/lighting/voxel_light_field.gd`

> VoxelLightField — per-voxel light BUCKET data (VL-01, VOXEL_LIGHT_MASTER_PLAN). The single seam between tactical lighting (LightRegistry / ShadowProjector, GU resolution) and every VISUAL consumer. VoxelRenderer.apply_light_field() reads it to repaint faces; future vision modes (thermal / night / X-ray) query it instead of touching tilemaps. Canon split preserved: this consumes LightSource.visual_energy, never tactical_energy — visual brightness is not tactical visibility. Deterministic and discrete: same lights + same layout always produce the same bucket per (cell, level). No per-frame work — built on lighting_rebuilt, queried lazily with a cache.

**Public vars**
- `var ambient_intensity: float = 0.15`
- `var no_lights_bucket: int = -1`
- `var vertical_gu_per_storey: float = 0.5`
- `var inner_full_ratio: float = 0.45`
- `var face_top_factor: float = 1.00`
- `var face_se_factor: float = 0.74`
- `var face_sw_factor: float = 0.48`
- `var face_enclosed_factor: float = 0.30`
- `var ao_strength: float = 0.55`

---

### `localization_manager.gd`

`class_name LocalizationManager` · extends `Node` · 145 lines

`godot/scripts/systems/localization/localization_manager.gd`

**Signals**
- `signal language_changed(locale: String)`

**Constants / tuning**
- `SOURCE_DIR` = `"res://godot/localization/translations/"`
- `SOURCE_FILES` = `["system.csv", "ui.csv"]`
- `SETTINGS_PATH` = `"user://settings.cfg"`
- `SETTINGS_SECTION` = `"localization"`
- `SETTINGS_KEY` = `"locale"`

**Public vars**
- `var default_locale: String = "en"`
- `var supported_locales: PackedStringArray = ["en", "pt_BR"]`

**Public API**
- `func set_language(locale: String) -> void:`
- `func cycle_language() -> void:`

---

### `material_registry.gd`

`class_name MaterialRegistry` · 84 lines

`godot/scripts/systems/material_registry.gd`

> MaterialRegistry — Material definitions and pattern algorithms Materials are code, not files. Each material couples a base color with a deterministic pattern algorithm that creates per-voxel luminance variation. This is the only place where pixels are created; all other baking stages operate on these pixels.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `StonePatternClass` = `preload("res://godot/scripts/systems/stone_pattern.gd")`
- `WoodPatternClass` = `preload("res://godot/scripts/systems/wood_pattern.gd")`
- `MetalPatternClass` = `preload("res://godot/scripts/systems/metal_pattern.gd")`

**Public vars**
- `var registry: Dictionary = {}`

**Public API**
- `func register(material: MaterialDef) -> void:`
- `func get_material(p_id: String) -> MaterialDef:`
- `func list_materials() -> Array:`
- `func count() -> int:`
- `func register_defaults() -> void:`
- `func register_ground_defaults() -> void:`

---

### `metal_pattern.gd`

`class_name MetalPattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 32 lines

`godot/scripts/systems/metal_pattern.gd`

> MetalPattern — Sheen band across the face Simulates reflective specular highlight; smooth gradient

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

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

### `occlusion_set.gd`

`class_name OcclusionSet` · 869 lines

`godot/scripts/systems/occlusion_set.gd`

> Occlusion Module — Computes which geometry occludes the agent POLICY: O1 — Occlusion is VIEW, not STATE - _occluded_cells is owned solely by this module - Never writes Voxel.visible, never uses dirty flag, never persists - NEVER reads _active_perspective (coordinates already rotated when entering) POLICY: O4′ — One view-space formula, no rotation applied The map is rebuilt rotated; we compute in already-rotated coordinates. POLICY: O5 — Depth is (x + y) in view-space, never z_index Isometric diamond layout: screen-y ∝ (x + y). Greater sum = nearer camera.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `FaceMod` = `preload("res://godot/scripts/geometry/face.gd")`
- `SlabMod` = `preload("res://godot/scripts/geometry/slab.gd")`
- `BASE_VISIBLE_LEVELS` = `2`
- `SMALL_ROOF_MAX_STRIPES` = `5`
- `_FACE_DIRS` = `[Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]`

**Public API**
- `func get_occluded_cells() -> Dictionary:`
- `func get_wireframe_by_level() -> Dictionary:`
- `func get_recompute_count() -> int:`
- `func recompute(agent_cells, slices: Array, room_size: Vector2i, junction_columns: Array = [], ceiling_slabs: Array = []) -> void:`

---

### `prop_def.gd`

`class_name PropDef` · 39 lines

`godot/scripts/systems/prop_def.gd`

> PropDef — Prop definition resource Describes a voxel prop (crate, pillar, container, etc.) Schema mirrors the file format and supports future destruction phase per-voxel granularity.

**Public vars**
- `var id: String`
- `var size_vox: Vector3i`
- `var layers: Array`
- `var material_zones: Dictionary`
- `var footprint_gus: Array[Vector2i]`
- `var storeys: int = 1`
- `var gameplay: Dictionary`
- `var tags: Array[String]`

---

### `prop_registry.gd`

`class_name PropRegistry` · 61 lines

`godot/scripts/systems/prop_registry.gd`

> PropRegistry — Prop definitions catalog (two-tier: res:// + user://) User-tier props override res:// props on id collision, same pattern as MaterialRegistry and TextureResolver.

**Constants / tuning**
- `RES_PROPS_DIR` = `"res://props"`
- `USER_PROPS_DIR` = `"user://props"`

**Public vars**
- `var registry: Dictionary = {}`

**Public API**
- `func register(prop_def) -> void:`
- `func get_prop(p_id: String):`
- `func count() -> int:`
- `func load_from_disk() -> void:`

---

### `registries_autoload.gd`

extends `Node` · 159 lines

`godot/scripts/systems/registries_autoload.gd`

> Registries — Global autoload for MaterialRegistry and PropRegistry Replaces Engine.set_meta() pseudo-singletons with real Godot autoload. This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup() after ScriptServer::finish_languages() has begun dismantling the script language. Strategy: Use weak references to avoid holding strong refs that prevent GC cleanup.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `PropRegistryClass` = `preload("res://godot/scripts/systems/prop_registry.gd")`
- `BombRegistryClass` = `preload("res://godot/scripts/systems/destruction/bomb_registry.gd")`
- `WeaponRegistryClass` = `preload("res://godot/scripts/systems/destruction/weapon_registry.gd")`
- `CollectibleFrameCacheClass` = `preload("res://godot/scripts/systems/collectible_frame_cache.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`

**Public vars**
- `var material_registry: MaterialRegistryClass:`

**Public API**
- `func ensure_material_registry() -> MaterialRegistryClass:`
- `func ensure_prop_registry() -> PropRegistryClass:`
- `func get_material_registry() -> MaterialRegistryClass:`
- `func get_prop_registry() -> PropRegistryClass:`
- `func ensure_bomb_registry() -> BombRegistryClass:`
- `func get_bomb_registry() -> BombRegistryClass:`
- `func ensure_weapon_registry() -> WeaponRegistryClass:`
- `func get_weapon_registry() -> WeaponRegistryClass:`
- `func get_frame_cache() -> CollectibleFrameCacheClass:`
- `func ensure_file_map_source() -> FileMapSourceClass:`

---

### `stone_pattern.gd`

`class_name StonePattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 30 lines

`godot/scripts/systems/stone_pattern.gd`

> StonePattern — Granular per-voxel jitter Simulates natural surface granularity; grainy texture with high-frequency variation

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

---

### `texture_resolver.gd`

`class_name TextureResolver` · 177 lines

`godot/scripts/systems/texture_resolver.gd`

> Texture Resolver — Fallback chain for baked facade sources Part of BAKING_MASTER_PLAN: §4.2 TextureResolver See TEXTURE_CATALOG.md for the full texture contract

**Constants / tuning**
- `MAX_FILE_SIZE_BYTES` = `10 * 1024 * 1024`

**Public vars**
- `var tex_user_dir: String = "user://textures/"`
- `var tex_default_dir: String = "res://ASSETS/TEXTURES/defaults/"`
- `var log_lines: PackedStringArray = []`

**Public API**
- `func resolve(texture_id: String) -> ResolvedTexture:`
- `func get_log() -> PackedStringArray:`
- `func get_log_string() -> String:`

---

### `theme_applier.gd`

`class_name ThemeApplier` · 47 lines

`godot/scripts/systems/theme_applier.gd`

> ThemeApplier — Apply theme color tints to wall layers Themes (map-specific color tints) are applied at render time via modulate, not baked into the atlas. This buys flexibility: atlas is reusable across themes, and switching themes is instant (single modulate call).

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public API**
- `func apply(theme_color: Color) -> void:`
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

`class_name TacticalTurnManager` · extends `Node` · 63 lines

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
- `func spend_for_path_cost(path_cost: int) -> bool:`
- `func consume_ap(amount: int) -> void:`
- `func path_cost_to_ap(path_cost: int) -> int:`

---

### `version_info.gd`

extends `Node` · 54 lines

`godot/scripts/systems/version_info.gd`

> VersionInfo — Single source of truth for game version Reads VERSION file at startup and exposes version components. Autoload singleton: automatically initialized at engine boot.

**Public vars**
- `var version_string: String = "0.0.0-unknown"`
- `var major: int = 0`
- `var minor: int = 0`
- `var patch: int = 0`

---

### `wood_pattern.gd`

`class_name WoodPattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 32 lines

`godot/scripts/systems/wood_pattern.gd`

> WoodPattern — Columnar periodic grooves Simulates wood grain with vertical groove directionality

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

---

## tools/

### `actor_frame_bake_spike.gd`

extends `SceneTree` · 324 lines

`godot/scripts/tools/actor_frame_bake_spike.gd`

> ACTOR_MASTER_PLAN D17/D21/D14 — flat-3D + normal-map + shadow bake TEMPLATE for a FloatingCollectible. Renders N rotation frames of an imported mesh (D12's path, proven by shotgun_preview_spike.gd) from the SAME fixed isometric camera the rest of the game uses — the OBJECT rotates around its own vertical axis between frames, the camera never moves, matching how a spinning collectible would actually be seen by the game's one fixed view. Each frame gets THREE renders: - color: a flat, unlit pass (today's D13-style ambient-only look, intentionally not baking any directional light in) - normal: view-space surface normal encoded as RGB (the standard normal-bake technique) — the pair a runtime CanvasItem shader needs to relight the flat sprite per-pixel against the world's real light data, without any voxel geometry at runtime - shadow: a SEPARATE straight-down (top-view) silhouette pass, NOT the color frame reused — squashing the oblique color view on Y to fake a ground shadow shears diagonal silhouettes and visibly rotates their apparent angle (Director-reported, 2026-07-28). A true top-down view has no directional foreshortening, so it can be squashed on Y to fit the isometric ground diamond without distortion. Dilated + blurred at bake time (cheaper once than every runtime frame) for a soft blob edge. STANDARDIZED (Director, 2026-07-28): this was the shotgun's own bake script; frame count, rotation speed, and the fixed bake-camera/shadow conventions now live in CollectibleBakeConfig (godot/scripts/systems/ collectible_bake_config.gd) so every future collectible reuses the same tuned sweet spot instead of re-deriving it — see that file for the frame-swap-rate and shadow-squash reasoning. To bake a NEW collectible: copy this file, change MODEL_PATH/OUT_DIR and re-tune the per-object knobs below (MESH_SCALE/VIEWPORT_SIZE/ORTHO_SIZE/SHADOW_* — always a visual judgment call, same convention MESH_SCALE always has been); never touch the CollectibleBakeConfig-sourced values. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/actor_frame_bake_spike.gd

**Constants / tuning**
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Shotgun Short Stock.glb"`
- `OUT_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/"`
- `VIEWPORT_SIZE` = `Vector2i(160, 160)`
- `ORTHO_SIZE` = `4.0`
- `MESH_SCALE` = `0.5`
- `SHADOW_VIEWPORT_SIZE` = `Vector2i(80, 80)`
- `SHADOW_ORTHO_SIZE` = `5.0`
- `SHADOW_CAMERA_DISTANCE` = `12.0`
- `NORMAL_BAKE_SHADER_CODE` = `"""`
- `GRADE_BRIGHTNESS_GAIN` = `1.9`
- `GRADE_BLACK_LIFT` = `0.06`
- `GRADE_SATURATION_BOOST` = `1.8`
- `GRADE_TINT_COLOR` = `Color(0.4, 0.55, 0.75)`
- `GRADE_TINT_STRENGTH` = `0.22`

---

### `actor_part0_spike.gd`

extends `SceneTree` · 226 lines

`godot/scripts/tools/actor_part0_spike.gd`

> ACTOR_MASTER_PLAN — Part 0 measurement spike. "Build one actor's digital twin at ×8, bake one pose, measure compose time and texture memory for real. Go/no-go on ×8 as the runtime default before Part 1 gets written in earnest." (§5 Part 0) The twin here is a SYNTHETIC PLACEHOLDER humanoid (leg/torso/arm/head blocks in proportion, no real character art exists yet — that is Part 2b/ mass-import, explicitly deferred). This script exists only to turn D2's "×8" resolution choice from a guess into a measured number before Part 1 is written on top of it, same discipline destruction_part0_spike.gd used for DESTRUCTION_MASTER_PLAN. Honesty boundary, stated once here instead of at every print: this reuses bake_voxel_sprite_3d.gd's exact camera/lighting rig verbatim (one MeshInstance3D + BoxMesh + StandardMaterial3D per voxel — the same approach already shipped for the grenade, not a redesigned renderer). D13 (VoxelLightField reuse) is Part 2's job, not measured here — this script keeps the existing tool's flat lighting on purpose, so the numbers below measure geometry/compose cost only, not a lighting change. Must run WINDOWED (real GPU rasterizer) — `sub.get_texture().get_image()` needs a real display driver, exactly like bake_voxel_sprite_3d.gd. Run via: godot --path . --position 4000,4000 --quit-after 30 \ --script res://godot/scripts/tools/actor_part0_spike.gd

**Constants / tuning**
- `VIEWPORT_SIZE` = `Vector2i(480, 640)`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`
- `CUBE_SIZE` = `1.0`
- `BODY_HEIGHT_UNITS` = `6`
- `BODY_WIDTH_UNITS` = `3`
- `BODY_DEPTH_UNITS` = `2`
- `TIERS` = `[4, 8, 16]`
- `MAX_SAFE_VOXELS` = `18000`

---

### `bake_cache_test.gd`

extends `SceneTree` · 430 lines

`godot/scripts/tools/bake_cache_test.gd`

> BAKE-CACHE-01 — Content-addressed disk cache test suite Acceptance criteria: 1. Transparency: compose cold → save → reload via disk → byte-identical 2. Invalidation: change BAKE_CODE_VERSION → different key → MISS 3. Warm-boot budget: cold + warm; warm ≤ 150ms 4. Corruption safety: truncate file → warning + MISS + recompose, no crash 5-7. Regressions + lint + version bump

**Constants / tuning**
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `BakeConfigClass` = `preload("res://godot/scripts/systems/bake_config.gd")`

**Public vars**
- `var test_results: Array = []`

---

### `bake_selftest.gd`

extends `SceneTree` · 338 lines

`godot/scripts/tools/bake_selftest.gd`

> BAKE-FIX-01: MASTER-STRIP SELFTEST Updated selftest suite for master-strip baking architecture. Tests B1–B6 with focus on real voxel alpha matching and canonical silhouette copying.

**Constants / tuning**
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `VOXEL_BASE_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_"`
- `VOXEL_MATERIALS` = `["concrete", "metal", "stone", "wood"]`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_B1_branch_exclusivity() -> void:`
- `func test_B2_grayscale_enforcement() -> void:`
- `func test_B3_alpha_from_canonical() -> void:`
- `func test_B4_fnv1a_determinism() -> void:`
- `func test_B5_no_rebake_on_destruction() -> void:`
- `func test_B6_loud_fail_validation() -> void:`
- `func test_real_voxel_atoms_loadable() -> void:`
- `func test_master_strip_dimensions() -> void:`

---

### `bake_voxel_sprite_3d.gd`

extends `SceneTree` · 139 lines

`godot/scripts/tools/bake_voxel_sprite_3d.gd`

> ACTOR_MASTER_PLAN D1/D2 prototype v2 (2026-07-21) — one-off bake tool, not production tooling yet. Director's proposal: instead of a hand-rolled 2D painter's-algorithm rasterizer (bake_grenade_sprite.py, v1 — the "esquisito" result), build real BoxMesh cubes in a SubViewport, light them with a real Camera3D at the angle that matches the existing flat atom's 2:1 top-face ratio (30° elevation solves sin(theta)=TILE_H/TILE_W=0.5), and let the GPU depth buffer handle occlusion + MSAA handle edges — both weak points of v1. Must run WINDOWED (real GPU rasterizer), not --headless (dummy driver, confirmed by SCREENSHOT-HOOK-01's own auto_screenshot.py — same constraint applies here). Run via: godot --path . --position 4000,4000 --quit-after 30 \ --script res://godot/scripts/tools/bake_voxel_sprite_3d.gd VOXEL_JSON_PATH is NOT checked in (ASSETS/ is gitignored) — regenerate it from the CC0 "Free Voxel Weapon Pack" .qb (OpenGameArt) via the scratchpad parse_qb.py: json.dump([{'x','y','z','r','g','b'} per solid voxel]). Output is raw (untrimmed, oversized canvas) — autocrop + downscale to the target sprite size afterward (transparent-margin trim + ~0.25x LANCZOS resize got the shipped grenade_bake_x8.png to 38×68px, matching the agent's own silhouette scale, agent.gd SILHOUETTE_WIDTH/HEIGHT=44/61).

**Constants / tuning**
- `VOXEL_JSON_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_voxels.json"`
- `OUT_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8_3d.png"`
- `ANCHOR_OUT_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_bake_x8_3d_anchor.json"`
- `VIEWPORT_SIZE` = `Vector2i(240, 400)`
- `ORTHO_SIZE` = `26.0`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`
- `CAMERA_DISTANCE` = `40.0`
- `CUBE_SIZE` = `1.0`

---

### `blast_calculator_selftest.gd`

extends `SceneTree` · 953 lines

`godot/scripts/tools/blast_calculator_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 3 — BlastCalculator selftest. Rodar: godot --headless --script res://godot/scripts/tools/blast_calculator_selftest.gd Synthetic fixtures only (SliceGenerator/SlabGenerator against a hand-built Edge list), same discipline as roof_slab_selftest.gd/slab_render_selftest.gd — no real map involved. Real-map end-to-end proof is the screenshot captures (INFILTRAITOR_CAPTURE_ACTION=test_zone_menu/test_zone_detonate).

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `BombDefClass` = `preload("res://godot/scripts/systems/destruction/bomb_def.gd")`
- `MaterialResistanceTableClass` = `preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")`
- `VoxelClass` = `preload("res://godot/scripts/geometry/voxel.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `NE` = `Vector2i(0, -1)`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_flood_unobstructed_rings() -> void:`
- `func test_flood_stops_at_blocked_edge() -> void:`
- `func test_flood_capped_at_bomb_range() -> void:`
- `func test_affected_slice_on_source_gu_boundary() -> void:`
- `func test_deterministic_selection_is_stable() -> void:`
- `func test_deterministic_selection_differs_by_salt_and_container() -> void:`
- `func test_metal_container_produces_cracked_not_destroyed() -> void:`
- `func test_damage_tiers_are_mutually_exclusive() -> void:`
- `func test_wood_container_mostly_destroyed_at_ring_zero() -> void:`
- `func test_ring_beyond_range_untouched() -> void:`
- `func test_soot_rings_spread_by_distance() -> void:`
- `func test_soot_min_ring_wins_between_two_holes() -> void:`
- `func test_crater_core_solid_rim_ragged_beyond_intact() -> void:`
- `func test_bias_prefers_epicenter_facing_side() -> void:`
- `func test_no_bias_sentinel_keeps_hash_only_behavior() -> void:`
- `func test_cone_is_directional_not_radial() -> void:`
- `func test_cone_widens_with_distance() -> void:`
- `func test_cone_respects_range_and_half_angle() -> void:`
- `func test_cone_stops_at_blocked_edge() -> void:`
- `func test_cone_output_shape_matches_rings() -> void:`
- `func test_destroy_multiplier_scales_damage() -> void:`
- `func test_pellet_impacts_no_hard_range_cap() -> void:`
- `func test_pellet_impacts_count_matches_projectile_count() -> void:`
- `func test_pellet_does_not_detour_around_narrow_obstacle() -> void:`
- `func test_point_impact_marks_only_the_impact_voxel() -> void:`
- `func test_point_impact_cascades_only_on_full_destroy() -> void:`
- `func test_pellet_selection_is_deterministic() -> void:`
- `func test_carved_side_faces_the_blast() -> void:`
- `func test_carved_side_survives_rotation() -> void:`

---

### `build_tileset.gd`

extends `SceneTree` · 342 lines

`godot/scripts/tools/build_tileset.gd`

**Constants / tuning**
- `SOURCE_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/generated/"`
- `TILESET_OUT` = `"res://godot/resources/tilesets/tileset_blocks.tres"`
- `REGISTRY_OUT` = `"res://godot/scripts/world/tile_registry.gd"`
- `CELL_SIZE` = `Vector2i(256, 128)`
- `PNG_SIZE` = `Vector2i(256, 512)`
- `SPRITE_OFFSET` = `Vector2i(0, -384)`
- `EDGE_VISUAL_OFFSETS` = `{ "N": Vector2i(64, -32), "S": Vector2i(-64, 32), "E": Vector2i(64, 32), "W": Vector2i(-64, -32), ## Diagonal wall faces (NE/NW/SE/SW): straddle the boundary at half a ## diamond-step. Values calibrated in commit 924dbf0. "NE": Vector2i(-16, -8), "NW": Vector2i(-16,  8), "SE": Vector2i( 16, -8), "SW": Vector2i( 16,  8), }`
- `CORNER_VISUAL_OFFSETS` = `{ "NE": Vector2i(-32, -8), "NW": Vector2i(  0, 16), "SE": Vector2i(  0,-16), "SW": Vector2i( 32, -8), }`
- `TILE_PROPS` = `{ # Floor "floor":                  {walkable=true,  cover=false, interactive=false}, "floorHalf":              {walkable=true,  cover=false, interactive=false}, "floorQuarter":           {walkable=true,  cover=false, interactive=false}, # Solid blocks "block":                  {walkable=false, cover=true,  interactive=false}, "blockHalf":              {walkable=false, cover=true,  interactive=false}, "blockAngle":             {walkable=false, cover=true,  interactive=false}, "blockQuarter":           {walkable=false, cover=true,  interactive=false}, # Walls "wall":                   {walkable=false, cover=true,  interactive=false}, "wallHalf":               {walkable=false, cover=true,  interactive=false}, "wallCorner":             {walkable=false, cover=true,  interactive=false}, "wallCornerHalf":         {walkable=false, cover=true,  interactive=false}, "wallCurve":              {walkable=false, cover=true,  interactive=false}, "wallCurveHalf":          {walkable=false, cover=true,  interactive=false}, "wallBattlement":         {walkable=false, cover=true,  interactive=false}, # Windows "window":                 {walkable=false, cover=false, interactive=false}, "windowLeft":             {walkable=false, cover=false, interactive=false}, "windowMiddle":           {walkable=false, cover=false, interactive=false}, "windowRight":            {walkable=false, cover=false, interactive=false}, # Doors / passages "doorClosed":             {walkable=false, cover=false, interactive=true}, "doorOpen":               {walkable=true,  cover=false, interactive=true}, "doorway":                {walkable=true,  cover=false, interactive=false}, "doorwayBottom":          {walkable=true,  cover=false, interactive=false}, "doorwayCenter":          {walkable=true,  cover=false, interactive=false}, "doorwayLeft":            {walkable=true,  cover=false, interactive=false}, "doorwayLeftBottom":      {walkable=true,  cover=false, interactive=false}, "doorwayMiddle":          {walkable=true,  cover=false, interactive=false}, "doorwayMiddleBottom":    {walkable=true,  cover=false, interactive=false}, "doorwayRight":           {walkable=true,  cover=false, interactive=false}, "doorwayRightBottom":     {walkable=true,  cover=false, interactive=false}, # Cover props "crate":                  {walkable=false, cover=true,  interactive=true}, # Structural details "column":                 {walkable=false, cover=false, interactive=false}, "columnBlocks":           {walkable=false, cover=false, interactive=false}, "columnCorner":           {walkable=false, cover=false, interactive=false}, "pole":                   {walkable=false, cover=false, interactive=false}, "poleGroup":              {walkable=false, cover=false, interactive=false}, "fence":                  {walkable=false, cover=false, interactive=false}, # Slopes / ramps "slope":                  {walkable=true,  cover=false, interactive=false}, "slopeHalf":              {walkable=true,  cover=false, interactive=false}, "slopeQuarter":           {walkable=true,  cover=false, interactive=false}, "slopeSmall":             {walkable=true,  cover=false, interactive=false}, "sloperCornerInner":      {walkable=true,  cover=false, interactive=false}, "sloperCornerOuter":      {walkable=true,  cover=false, interactive=false}, # Stairs "stairs":                 {walkable=true,  cover=false, interactive=false}, "stairsCornerInner":      {walkable=true,  cover=false, interactive=false}, "stairsCornerOuter":      {walkable=true,  cover=false, interactive=false}, "stairsOpen":             {walkable=true,  cover=false, interactive=false}, "stairsOpenCornerInner":  {walkable=true,  cover=false, interactive=false}, "stairsOpenCornerOuter":  {walkable=true,  cover=false, interactive=false}, "steps":                  {walkable=true,  cover=false, interactive=false}, "ladder":                 {walkable=true,  cover=false, interactive=true}, # Slabs / platforms "slab":                   {walkable=true,  cover=false, interactive=false}, "slabHalf":               {walkable=true,  cover=false, interactive=false}, "slabAngle":              {walkable=true,  cover=false, interactive=false}, "slabQuarter":            {walkable=true,  cover=false, interactive=false}, # Switches / triggers "switchFloorOff":         {walkable=true,  cover=false, interactive=true}, "switchFloorOn":          {walkable=true,  cover=false, interactive=true}, "switchWallOff":          {walkable=false, cover=false, interactive=true}, "switchWallOn":           {walkable=false, cover=false, interactive=true}, # Direction markers "arrow":                  {walkable=true,  cover=false, interactive=false}, "arrowWall":              {walkable=false, cover=false, interactive=false}, }`
- `EDGE_ALIGNED_PREFIXES` = `[ "arrowWall", "door", "fence", "switchWall", "wall", "window", ]`
- `EDGE_ALIGNED_EXCLUSIONS` = `[ "wallCorner", "wallCornerHalf", "wallCurve", "wallCurveHalf", "wallBattlement", ]`

---

### `destruction_part0_spike.gd`

extends `SceneTree` · 159 lines

`godot/scripts/tools/destruction_part0_spike.gd`

> DESTRUCTION_MASTER_PLAN — Part 0 measurement spike. Not a standing gate, not a selftest suite. This is the one-shot investigation Part 0 calls for: "force the worst cases and measure... find where it breaks." No production code depends on this script; it exists to turn the plan's one real unknown (TileMapLayer count scaling) and its two other worst-case numbers into real, printed, reproducible evidence before Slab (Part 1) is written on top of a guess. Honesty boundary, stated once here instead of at every print: this runs `--headless` on a Mac, not on the target mobile device. Headless Godot has no display driver, so nothing here measures GPU draw cost — only the CPU-side bookkeeping cost (node creation, TileMapLayer.set_cell(), memory). The plan itself asks for target-device numbers (§5 Part 0); this script produces the Mac/CPU half of that, not a substitute for it.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `MAP_GU_SIZE` = `26`

---

### `earth_variant_selftest.gd`

extends `SceneTree` · 173 lines

`godot/scripts/tools/earth_variant_selftest.gd`

> DESTRUCTION_MASTER_PLAN D2/D4 — EarthVariantSelector selftest. Rodar: godot --headless --script res://godot/scripts/tools/earth_variant_selftest.gd This is the "core, isolated, verified before anything consumes it" prompt: no VoxelRenderer/TileSet/Slab wiring here on purpose — that's the next wave.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_determinism() -> void:`
- `func test_range() -> void:`
- `func test_not_constant() -> void:`
- `func test_distribution_uses_all_variants() -> void:`
- `func test_assets_loadable_and_canon_sized() -> void:`
- `func test_fnv1a_static_call_matches_instance_call() -> void:`

---

### `fixed_floor_selftest.gd`

extends `SceneTree` · 170 lines

`godot/scripts/tools/fixed_floor_selftest.gd`

> DESTRUCTION_MASTER_PLAN D13 — fixed floor level selftest. Rodar: godot --headless --script res://godot/scripts/tools/fixed_floor_selftest.gd Proves render_fixed_earth_level() (the 7 non-destructible levels) and render_slab() (the 1 destructible top) compose into the full D13 8-level stack — without the fixed levels ever touching Slab/Voxel/dirty-tracking.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_fixed_level_places_correct_cells() -> void:`
- `func test_fixed_level_does_not_touch_slab_registry() -> void:`
- `func test_one_call_builds_only_the_requested_level() -> void:`
- `func test_full_d13_stack_top_destructible_rest_fixed() -> void:`

---

### `floor_integration_selftest.gd`

extends `SceneTree` · 292 lines

`godot/scripts/tools/floor_integration_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 2 — real map integration selftest. Rodar: godot --headless --script res://godot/scripts/tools/floor_integration_selftest.gd Drives the REAL RoomBuilder.build_from_layout() against a REAL compiled map (PLAYGROUND, via FileMapSource + MapCompiler — the exact same path room.gd::load_map() uses), not a synthetic map_spec. Proves the floor integration lands correctly end-to-end: every GU gets a real Slab at level -1, cells round-trip against an independently re-derived hash, and the existing wall/prop pipeline is unaffected.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_real_playground_map_gets_a_real_floor() -> void:`

---

### `floor_zone_bake_selftest.gd`

extends `SceneTree` · 512 lines

`godot/scripts/tools/floor_zone_bake_selftest.gd`

> FLOOR-BAKE-01 — floor-zone photographic ground bake selftest. Rodar: godot --headless --script res://godot/scripts/tools/floor_zone_bake_selftest.gd Mirrors roof_bake_selftest.gd's structure/rigor for the floor-zone bake feature (author-declared rectangular material zones, full-color RGB instead of grayscale-luminance-times-tint). Proves: 1. A floor_zones-only map_spec composes the SAME "ROOF|mat|fac|col|row" page family roof/ceiling uses (bake_compositor.gd deliberately never introduced a separate "FLOOR|" prefix) with a lookup entry for every folded LOCAL cell 2. resolve_flat() returns exactly the independently re-derived atom 3. PIXEL continuity + ISOTROPY at the floor's own 1024x1024 target size (not the wall/ceiling-inherited 1024x512) + full_color's WHITE modulate does not alter the composed page's raw pixel RGB (the compositor forces the modulate at TileData registration time, a draw-time multiply — never a page-pixel write) 4. Real FLOOR_ZONES_TEST map, bake ENABLED: every voxel in a declared zone carries the baked source + coords its STRUCTURE-LOCAL offset predicts (own flood-fill re-derivation, keyed on "same zone material" instead of "both roofed"); unzoned floor still resolves to the "earth" sentinel with zero anchor 5. ROTATION: building the E view puts a zone's Slab material at the correctly-rotated GU, exactly like roof's block rotation Every expectation is re-derived locally (own mirror fold, own key format, own component flood fill, own rotation math) — never read back from the code under test.

**Constants / tuning**
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `ATOM_W` = `32`
- `ATOM_H` = `36`
- `V_MARGIN` = `32`
- `FLOOR_TOP_LEVEL` = `-1`
- `FLOOR_TARGET_H` = `1024`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `geometry_selftest.gd`

extends `SceneTree` · 234 lines

`godot/scripts/tools/geometry_selftest.gd`

> Geometry Module — Selftest: minimal validation Headless selftest Usage: godot --headless --script geometry_selftest.gd

---

### `grenade_collectible_bake_spike.gd`

extends `SceneTree` · 262 lines

`godot/scripts/tools/grenade_collectible_bake_spike.gd`

> ACTOR_MASTER_PLAN objects track — grenade COLLECTIBLE bake (2026-07-29). Copy of actor_frame_bake_spike.gd following that file's own documented "to bake a NEW collectible" recipe: only the per-object knob block below changes, never the CollectibleBakeConfig-sourced values (frame count, camera elevation/azimuth/distance, shadow dilate/blur) — FloatingCollectible's light-direction math is derived against that exact camera convention and breaks SILENTLY if a bake drifts from it. Why a second grenade bake instead of reusing grenade_frames/: that folder holds the STATIC ground prop's 4 compass frames (N/E/S/W) and GrenadeProp still reads them — the thrown-grenade-on-the-ground representation stays, the Director wants it for "o agente arremessar as granadas ativamente". This one is the spinning pickup: the same model on the collectible's own 120-frame + shadow-pass convention, written to its own folder. This bake is also the evidence for a claim, not just an asset: the shotgun was the only object FloatingCollectible had ever displayed, so "the class works for any object" was asserted rather than shown. A second, very differently-shaped model (small, round, stubby vs. long and thin) going through the identical pipeline is what actually tests it. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/grenade_collectible_bake_spike.gd

**Constants / tuning**
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"`
- `OUT_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_collectible_frames/"`
- `VIEWPORT_SIZE` = `Vector2i(160, 160)`
- `ORTHO_SIZE` = `4.0`
- `MESH_SCALE` = `2.0`
- `SHADOW_VIEWPORT_SIZE` = `Vector2i(80, 80)`
- `SHADOW_ORTHO_SIZE` = `4.0`
- `SHADOW_CAMERA_DISTANCE` = `12.0`
- `NORMAL_BAKE_SHADER_CODE` = `"""`

---

### `grenade_frame_bake_spike.gd`

extends `SceneTree` · 227 lines

`godot/scripts/tools/grenade_frame_bake_spike.gd`

> ACTOR_MASTER_PLAN objects track — grenade re-bake (2026-07-28), replacing TestZoneController's old single-angle grenade_bake_x8.png (bake_voxel_ sprite_3d.gd, a hand-placed BoxMesh voxel reconstruction of a CC0 .qb) with the SAME real-3D-model + dual color/normal-map technique proven for the shotgun (actor_frame_bake_spike.gd). Unlike the shotgun's FloatingCollectible (a spinning pickup, 24 frames), the grenade is a STATIC ground prop — it never spins on its own, but the game's N/E/S/W perspective toggle visually rotates the whole scene, so it still needs one real render per compass direction (4 frames, not 24) to look correct from every perspective instead of showing a frozen single angle regardless of view (D22 finding, same root cause the FloatingCollectible perspective fix addressed). Ground-anchor technique borrowed from bake_voxel_sprite_3d.gd: the pivot recenters the mesh so its AABB center sits at the pivot's local origin, which means the AABB's bottom-center (the ground-contact point) always lands exactly on the pivot's own Y (vertical) rotation axis — invariant under yaw, so one cam.unproject_position() call gives an anchor pixel valid for all 4 frames. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/grenade_frame_bake_spike.gd

**Constants / tuning**
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"`
- `OUT_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/"`
- `ANCHOR_OUT_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/anchor.json"`

---

### `input_controller_test.gd`

extends `SceneTree` · 275 lines

`godot/scripts/tools/input_controller_test.gd`

> !/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script INPUT-01-c Test: Verify InputController dispatches all 18 actions with real signal firing. Run: godot --headless --script godot/scripts/tools/input_controller_test.gd

**Constants / tuning**
- `InputControllerClass` = `preload("res://godot/scripts/world/controllers/input_controller.gd")`

**Public vars**
- `var test_passed: int = 0`
- `var test_failed: int = 0`
- `var action_expectations: Dictionary = { "ui_posture_lower": ["posture_lower_requested", []], "ui_posture_raise": ["posture_raise_requested", []], "ui_view_mode_dev": ["view_mode_requested", ["dev"]], "ui_view_mode_light": ["view_mode_requested", ["light"]], "ui_view_mode_heat": ["view_mode_requested", ["heat"]], "ui_peek": ["peek_initiated", []], "ui_move_up": ["movement_input_requested", [Vector2i.UP, false]], "ui_move_down": ["movement_input_requested", [Vector2i.DOWN, false]], "ui_move_left": ["movement_input_requested", [Vector2i.LEFT, false]], "ui_move_right": ["movement_input_requested", [Vector2i.RIGHT, false]], "debug_toggle_map_loader": ["debug_command_requested", ["toggle_map_loader"]], "debug_toggle_voxel_ruler": ["debug_command_requested", ["toggle_voxel_ruler"]], "debug_toggle_nudge_mode": ["debug_command_requested", ["toggle_nudge_mode"]], "debug_toggle_bake_mode": ["debug_command_requested", ["toggle_bake_mode"]], "debug_cycle_blend_mode": ["debug_command_requested", ["cycle_blend_mode"]], "debug_cycle_language": ["debug_command_requested", ["cycle_language"]], "debug_nudge_reset": ["debug_command_requested", ["nudge_reset"]], "debug_screenshot": ["screenshot_requested", []], }`

**Public API**
- `func test_all_actions_fire_signals() -> void:`
- `func test_screenshot_signal_firing(controller: Node, action: String, expected_signal: String, _expected_args: Array) -> void:`
- `func test_action_signal_firing(controller: Node, action: String, expected_signal: String, expected_args: Array) -> void:`
- `func assert_eq(actual: Variant, expected: Variant, message: String) -> void:`
- `func assert_true(condition: bool, message: String) -> void:`

---

### `map_lint.gd`

extends `SceneTree` · 58 lines

`godot/scripts/tools/map_lint.gd`

> map_lint.gd — Headless tool to validate all .map.json files Scans res://maps/ and user://maps/ for *.map.json files, loads each through MapFileService with full registry, and reports pass/fail with error details. Exit code: 0 if all pass, 1 if any fail.

**Public vars**
- `var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")`
- `var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")`
- `var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")`

---

### `mapfile_roundtrip_test.gd`

extends `SceneTree` · 322 lines

`godot/scripts/tools/mapfile_roundtrip_test.gd`

> mapfile_roundtrip_test.gd — Comprehensive round-trip and migration testing Tests: 1. Basic round-trip: save spec -> load -> verify structural equality 2. Tolerant round-trip: unknown section preservation (M3) 3. Migration RED (missing migration fails loudly) + GREEN (migration present succeeds)

**Public vars**
- `var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")`
- `var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")`
- `var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")`

---

### `negative_storey_selftest.gd`

extends `SceneTree` · 239 lines

`godot/scripts/tools/negative_storey_selftest.gd`

> DESTRUCTION_MASTER_PLAN D17/D18 — negative storey selftest. Rodar: godot --headless --script res://godot/scripts/tools/negative_storey_selftest.gd Proves the floor can live at negative levels without disturbing the existing (positive) wall/block/prop pipeline at all — D17's whole claim.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_negative_layer_creation_and_lookup() -> void:`
- `func test_negative_level_position_and_zindex_formula() -> void:`
- `func test_lazy_not_contiguous() -> void:`
- `func test_positive_pipeline_unaffected() -> void:`
- `func test_slab_render_routes_negative_level_correctly() -> void:`
- `func test_set_voxel_cell_still_rejects_unensured_level() -> void:`

---

### `neon_flicker_selftest.gd`

extends `SceneTree` · 187 lines

`godot/scripts/tools/neon_flicker_selftest.gd`

> NEON-FLICKER-01 — LightSource flicker selftest. Rodar: godot --headless --script res://godot/scripts/tools/neon_flicker_selftest.gd The flicker is a TIME-SHAPED effect: no screenshot can show that a lamp stays lit longer than it stays dark, or that its dark stretches arrive in irregular bursts instead of on a metronome. So the shape is measured here, by driving the real update_temporal_state() at a real frame delta and reading the resulting energy trace — the same call room._process() makes every frame. The repaint-rate test is not decoration: every energy change schedules an incremental relight of the lamp's GUs (room._update_temporal_lights), so an over-eager flicker is a performance bug, not just a look. That ceiling is what keeps this effect event-driven instead of per-frame analog.

**Constants / tuning**
- `FRAME_DELTA` = `1.0 / 60.0`
- `SIM_SECONDS` = `120.0`
- `INTERVAL` = `0.6`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_lit_far_longer_than_dark() -> void:`
- `func test_durations_are_varied_not_binary() -> void:`
- `func test_dark_arrives_in_bursts() -> void:`
- `func test_deterministic_per_light_identity() -> void:`
- `func test_repaint_rate_stays_sane() -> void:`

---

### `occlusion_set_test.gd`

`class_name OcclusionSetTest` · extends `SceneTree` · 245 lines

`godot/scripts/tools/occlusion_set_test.gd`

> OCC-01: Occlusion Set — Headless Test Usage: godot --headless --script godot/scripts/tools/occlusion_set_test.gd

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `OcclusionSetMod` = `preload("res://godot/scripts/systems/occlusion_set.gd")`

---

### `panel_base_test.gd`

extends `SceneTree` · 171 lines

`godot/scripts/tools/panel_base_test.gd`

> !/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script PANEL-01 Test: Standalone verification of PanelBase and WindowBase functionality. Run: godot --headless --script godot/scripts/tools/panel_base_test.gd

**Constants / tuning**
- `PanelBaseClass` = `preload("res://godot/scripts/ui/panel_base.gd")`
- `WindowBaseClass` = `preload("res://godot/scripts/ui/window_base.gd")`

**Public vars**
- `var test_passed: int = 0`
- `var test_failed: int = 0`

**Public API**
- `func test_panel_base() -> void:`
- `func test_window_base() -> void:`
- `func test_background_swap_simple() -> void:`
- `func assert_eq(actual: Variant, expected: Variant, message: String) -> void:`
- `func assert_true(condition: bool, message: String) -> void:`

---

### `project_lint_validator.gd`

extends `SceneTree` · 97 lines

`godot/scripts/tools/project_lint_validator.gd`

> PROJECT_LINT_VALIDATOR — Full-project GDScript parse check Walks res://godot/scripts/ and loads every .gd file, collecting parse errors

**Public vars**
- `var parse_errors: PackedStringArray = []`
- `var files_checked: int = 0`
- `var all_gd_files: PackedStringArray = []`
- `var failed_files: PackedStringArray = []`

---

### `prop_01_tests.gd`

extends `SceneTree` · 363 lines

`godot/scripts/tools/prop_01_tests.gd`

> PROP-01 Acceptance Tests Tests the PropDef/PropRegistry/voxel prop rendering system

**Public vars**
- `var PropDefClass`
- `var PropRegistryClass`
- `var MapCompilerClass`
- `var FileMapSourceClass`
- `var MapCatalogClass`
- `var VoxelRendererClass`

**Public API**
- `func test_criterion_1_propdef_from_json() -> void:`
- `func test_criterion_2_propregistry_override() -> void:`
- `func test_criterion_3_render_prop_footprint() -> void:`
- `func test_criterion_4_mapcompiler_voxel_props() -> void:`
- `func test_criterion_5_file_map_source_round_trip() -> void:`
- `func test_criterion_6_invariants_check() -> void:`
- `func test_criterion_7_non_regression() -> void:`

---

### `resolver_hardening_tests.gd`

extends `SceneTree` · 527 lines

`godot/scripts/tools/resolver_hardening_tests.gd`

> BAKE-08: Resolver Integration Hardening End-to-end resolver tests with live user:// content. Exercises corrupt-file handling, oversized files, dimension mismatches, and tier fallback. All tiers (USER, DEFAULT, NONE) validated with console evidence.

**Constants / tuning**
- `TEST_USER_DIR` = `"user://resolver_test/"`
- `TEST_DEFAULT_DIR` = `"user://resolver_test_defaults/"`
- `TEX_AUTHORING_N` = `16`

**Public vars**
- `var TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")`
- `var GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `var test_passed = 0`
- `var test_failed = 0`

---

### `roof_bake_selftest.gd`

extends `SceneTree` · 488 lines

`godot/scripts/tools/roof_bake_selftest.gd`

> ROOF-BAKE-01/02 — roof/ceiling baked-surface selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_bake_selftest.gd Proves the ROOF-BAKE-02 contract end-to-end: 1. A roofs-only map_spec composes the dedicated roof page family with a "ROOF|mat|fac|col|row" lookup entry for every (folded) LOCAL cell 2. resolve_flat() returns exactly the independently re-derived atom 3. PIXEL continuity + ISOTROPY: placed atom top-diamonds equal a direct read of the roof plane (built from the UNSCALED facade — no wall ×20/16 pre-scale) at the projected offset 4. Real PLAYGROUND, bake ENABLED: every roof voxel carries the baked source + coords its STRUCTURE-LOCAL offset predicts, with component anchors re-derived by this test's own flood fill; storey-step borders follow the level-aware rule (suppress toward same-or-higher, eave over lower) 5. ROTATION (02a): building the E view puts a roof Slab of the right material at every block's ROTATED position Every expectation is re-derived locally (own mirror fold, own key format, own component flood fill, own rotation math) — never read back from the code under test.

**Constants / tuning**
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `ATOM_W` = `32`
- `ATOM_H` = `36`
- `V_MARGIN` = `32`
- `ROOF_LEVEL_COUNT` = `2`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_1_roof_cells_get_lookup_entries(fx: Dictionary) -> void:`
- `func test_2_resolve_flat_matches_rederived_atoms(fx: Dictionary, bake_config) -> void:`
- `func test_3_pixel_continuity_and_isotropy(fx: Dictionary) -> void:`
- `func test_4_real_playground_local_keys_and_step_borders() -> void:`
- `func test_5_rotated_view_roofs_follow_structures() -> void:`

---

### `roof_integration_selftest.gd`

extends `SceneTree` · 267 lines

`godot/scripts/tools/roof_integration_selftest.gd`

> DESTRUCTION D1-ROOF — real map roof integration selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_integration_selftest.gd Drives the REAL RoomBuilder.build_from_layout() against the REAL PLAYGROUND map (FileMapSource + MapCompiler, the exact path room.gd::load_map() uses) and confirms real roofs land above the real concrete/stone/wood/metal blocks it actually contains (maps/PLAYGROUND.map.json's "blocks" section).

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_real_playground_blocks_get_real_roofs() -> void:`

---

### `roof_slab_selftest.gd`

extends `SceneTree` · 313 lines

`godot/scripts/tools/roof_slab_selftest.gd`

> DESTRUCTION_MASTER_PLAN — roof/ceiling ("laje") geometry selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_slab_selftest.gd Proves the "2+ levels, ALL destructible, existing wall material" roof model this session's Director asked for: unlike the floor (1 destructible Slab + 7 fixed non-Slab levels, D13), a roof is N independent Slabs, one per level, each fully destructible — falls out of calling the EXISTING SlabGenerator N times, zero new geometry classes needed. No bake system involved yet (Director's call: geometry first, bake as a later experiment) — render_slab_solid() places one fixed wall material per voxel, the same way render_block() already does for a whole block, just through Slab/Voxel so every level is independently dirty-tracked.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_multi_level_roof_is_n_independent_slabs() -> void:`
- `func test_render_slab_solid_uses_fixed_material_no_hash() -> void:`
- `func test_each_roof_level_independently_destructible() -> void:`
- `func test_roof_positioned_above_a_block_uses_the_blocks_own_material() -> void:`
- `func test_border_expands_footprint_to_10x10_offset_by_minus_one() -> void:`
- `func test_border_per_side_zero_skips_that_side_only() -> void:`
- `func test_adjacent_multi_gu_roofs_do_not_self_overlap() -> void:`

---

### `shotgun_preview_spike.gd`

extends `SceneTree` · 141 lines

`godot/scripts/tools/shotgun_preview_spike.gd`

> ACTOR_MASTER_PLAN Part 2 (D12 imported-mesh path) — one-off preview render. Loads each shotgun variant from the Quaternius Ultimate Guns Pack (CC0, see ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/ ATTRIBUTION.txt) through the SAME camera/lighting rig bake_voxel_sprite_3d.gd already ships for the grenade, using Godot's runtime GLTFDocument loader instead of a voxel-JSON twin — the D12 "imported mesh" path, not yet exercised by any script until this one. Purpose: a real look at each variant at the actual isometric bake angle, to pick one before committing to Part 5a (Showcase). Not a production tool — one-off, same spirit as bake_voxel_sprite_3d.gd's own header. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/shotgun_preview_spike.gd

**Constants / tuning**
- `MODELS_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/"`
- `OUT_DIR` = `"res://Screenshots/history/"`
- `MODELS` = `[ "Shotgun.glb", "Shotgun-ZmPTnh7njL.glb", "Shotgun Sawed Off.glb", "Shotgun Short Stock.glb", ]`
- `VIEWPORT_SIZE` = `Vector2i(480, 480)`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`

---

### `slab_geometry_selftest.gd`

extends `SceneTree` · 223 lines

`godot/scripts/tools/slab_geometry_selftest.gd`

> DESTRUCTION_MASTER_PLAN D1/Part 1 — Slab container selftest. Rodar: godot --headless --script res://godot/scripts/tools/slab_geometry_selftest.gd Mirrors the Slice/EdgeRegistry contract Slab is built to match: dirty-count propagation from Voxel, clear-all, and the TIC-skip shape (dirty_slabs() returns only what's actually dirty, empty means truly free).

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_slab_identity_and_voxel_count() -> void:`
- `func test_voxel_dirty_propagates_to_slab() -> void:`
- `func test_clear_all_dirty_resets_count_and_flags() -> void:`
- `func test_voxel_reuse_across_slice_and_slab() -> void:`
- `func test_registry_dirty_skip_contract() -> void:`

---

### `slab_render_selftest.gd`

extends `SceneTree` · 189 lines

`godot/scripts/tools/slab_render_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 2 — consumer wave selftest. Rodar: godot --headless --script res://godot/scripts/tools/slab_render_selftest.gd Proves the D2/D4 core (EarthVariantSelector, landed in isolation) actually renders correctly once something consumes it: SlabGenerator builds real Voxels, VoxelRenderer.render_slab() places real TileMapLayer cells, and the cell each voxel actually got matches what the pure hash function predicted — the same round-trip discipline OCC-02 used for ghost restore.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_slab_generator_produces_64_voxels() -> void:`
- `func test_render_slab_places_cells_matching_the_hash() -> void:`
- `func test_render_slab_idempotent() -> void:`
- `func test_d13_two_layer_floor_independent_containers() -> void:`

---

### `slice_geometry_selftest.gd`

extends `SceneTree` · 224 lines

`godot/scripts/tools/slice_geometry_selftest.gd`

**Constants / tuning**
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`
- `EdgeExtractorClass` = `preload("res://godot/scripts/geometry/edge_extractor.gd")`

---

### `texture_resolver_selftest.gd`

extends `SceneTree` · 327 lines

`godot/scripts/tools/texture_resolver_selftest.gd`

> TextureResolver — Selftest (TEX-CATALOG-01) Validates all resolver tiers, validations, and fallback chain Usage: godot --headless --script res://godot/scripts/tools/texture_resolver_selftest.gd Output: "TEX-CATALOG-01 SELFTEST: PASS" + exit 0, or "...FAIL" + exit 1

**Constants / tuning**
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `TEST_USER_DIR` = `"user://textures_test/"`
- `TEST_DEFAULT_DIR` = `"user://textures_defaults_test/"`

---

### `tile_anatomy_audit.gd`

extends `MainLoop` · 298 lines

`godot/scripts/tools/tile_anatomy_audit.gd`

> !/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script BAKE-FIX-00 Ground-Truth Audit Tool Measures real voxel atom geometry, facade dimensions, and wall-run lengths Usage: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/tile_anatomy_audit.gd

**Constants / tuning**
- `VOXEL_MATERIALS` = `["concrete", "metal", "stone", "wood"]`
- `VOXEL_BASE_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_"`
- `FACADE_BASE_PATH` = `"res://ASSETS/TEXTURES/defaults/facade_"`
- `EXPECTED_VOXEL_W` = `32`
- `EXPECTED_VOXEL_H` = `36`
- `EXPECTED_VOXEL_TILE_H` = `16`
- `EXPECTED_VOXEL_SIDE_H` = `20`
- `EXPECTED_FACADE_W` = `1024`
- `EXPECTED_FACADE_H` = `512`
- `EXPECTED_TEX_N` = `16`

**Public API**
- `func audit_voxel_assets() -> Dictionary:`
- `func compute_alpha_histogram(img: Image) -> Dictionary:`
- `func audit_facade_multiply_region() -> void:`
- `func audit_facade_assets() -> Dictionary:`
- `func audit_map_wall_runs() -> void:`
- `func extract_wall_runs(map_data: Variant) -> Array:`
- `func get_median(arr: Array) -> int:`

---

### `version_info_test.gd`

extends `SceneTree` · 49 lines

`godot/scripts/tools/version_info_test.gd`

> VERSION-01 Test: VersionInfo singleton initialization

---

### `voxel_light_incremental_selftest.gd`

extends `SceneTree` · 195 lines

`godot/scripts/tools/voxel_light_incremental_selftest.gd`

> VL-03 selftest — incremental repaint must match a full rebuild exactly. Run: godot --headless --script res://godot/scripts/tools/voxel_light_incremental_selftest.gd A temporal light (flicker/pulse) toggles energy_multiplier on the SAME LightSource instance and repaints only VoxelLightField.gus_in_light_range() via clear_caches() + bucket_for() — never a full build(). The whole point of VL-03 is that this must be indistinguishable from re-deriving everything from scratch: 1. Every voxel INSIDE the toggled light's influence set must read the same bucket as a fresh build() with the light at its new energy would give. 2. Every voxel OUTSIDE that influence set must be UNCHANGED by the toggle (clear_caches() must not corrupt values a caller reads for cells the incremental pass never touched). 3. The static factor (surface/soot/under-structure) must survive the toggle unchanged — it does not depend on which lights are on.

**Constants / tuning**
- `VLF` = `preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")`
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_influence_set_matches_full_rebuild() -> void:`
- `func test_cells_outside_influence_set_unchanged() -> void:`
- `func test_static_factor_survives_toggle() -> void:`

---

### `voxel_persist_selftest.gd`

extends `SceneTree` · 95 lines

`godot/scripts/tools/voxel_persist_selftest.gd`

> VL-PERSIST selftest — the coordinate math destruction persistence relies on. Run: godot --headless --script res://godot/scripts/tools/voxel_persist_selftest.gd Destruction is recorded in BASE (N-frame) voxel coords and re-applied per view by PerspectiveMapper.cell_to_base / cell_from_base at 8× the GU resolution (base_size × VOXELS_PER_UNIT_AXIS). Two properties must hold or holes land on the wrong voxels after a rotation: 1. cell_from_base and cell_to_base are exact inverses at voxel scale. 2. A voxel's rotation is consistent with its owning GU's rotation — the 8×8 quadrant rotates coherently, so a voxel stays inside its rotated GU.

**Constants / tuning**
- `PM` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_voxel_roundtrip_all_directions() -> void:`
- `func test_voxel_stays_in_rotated_gu() -> void:`

---

### `weapon_frames_bake.gd`

extends `SceneTree` · 306 lines

`godot/scripts/tools/weapon_frames_bake.gd`

> Weapon collectible bake — WEAPON_MASTER_PLAN Part 1 support (2026-07-29). Bakes N weapons in one run instead of N copy-pasted spike scripts. This is the first, deliberately small step of ACTOR_MASTER_PLAN Part 2b (D15's manifest-driven batch tool): a table here, not a JSON manifest, and scoped to weapons only. Everything past that — arbitrary object types, per-object config files, license bookkeeping — stays unbuilt until something actually needs it. ONE SHARED FRAMING FOR EVERY GUN, which is the point of doing them together. The Quaternius pack's models share a coordinate scale (measured 2026-07-29: pistol 1.8 native units long, shotgun 4.5, sniper up to 7.3), so a single MESH_SCALE/ORTHO_SIZE renders them all at TRUE RELATIVE SIZE — a sniper reads long and a pistol reads stubby, instead of every gun being auto-framed to fill its canvas and arriving on the bench the same apparent length. The numbers are chosen so px-per-world-unit matches the already-shipped shotgun bake EXACTLY (160/4.0 = 40 = 220/5.5), which is what lets the new weapons drop in beside it with the same SPRITE_SCALE, the same outline width in texels, and no re-tuning. The canvas is bigger only so the longest sniper fits with margin; a centred sprite treats the extra as transparent padding. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/weapon_frames_bake.gd

**Constants / tuning**
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `MODEL_ROOT` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/"`
- `OUT_ROOT` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"`
- `WEAPONS` = `[ {"model": "Pistol.glb", "out": "pistol_frames"}, {"model": "Revolver.glb", "out": "revolver_frames"}, {"model": "Submachine Gun.glb", "out": "smg_frames"}, {"model": "Assault Rifle.glb", "out": "assault_rifle_frames"}, {"model": "Sniper Rifle.glb", "out": "sniper_rifle_frames"}, ]`
- `VIEWPORT_SIZE` = `Vector2i(220, 220)`
- `ORTHO_SIZE` = `5.5`
- `MESH_SCALE` = `0.5`
- `SHADOW_VIEWPORT_SIZE` = `Vector2i(110, 110)`
- `SHADOW_ORTHO_SIZE` = `5.5`
- `SHADOW_CAMERA_DISTANCE` = `12.0`
- `NORMAL_BAKE_SHADER_CODE` = `"""`

---

## ui/

### `controls_panel.gd`

`class_name ControlsPanel` · extends `WindowBase` · 122 lines

`godot/scripts/ui/controls_panel.gd`

> PAUSE-MENU-02: Controls Panel.

**Public API**
- `func open() -> void:`

---

### `detonate_context_menu.gd`

`class_name DetonateContextMenu` · extends `Control` · 141 lines

`godot/scripts/ui/detonate_context_menu.gd`

> DetonateContextMenu — small black-box context menu for right-clicking an interactive TEST-ZONE prop (placeholder, 2026-07-21). One parameterised action then a separator then "Cancelar (Esc)". Enter/Space activate the focused button natively (Godot's own Control focus system) — no custom accept handling needed. Esc and outside-clicks are handled by the caller (room.gd owns all mouse/keyboard coordination — see its _unhandled_input), not here, so there is exactly one place deciding "is the menu open" instead of two competing input handlers. WEAPON-FIRE-01 (2026-07-29): the action label and its handler are now passed in at open_at() time, because a second prop type needed a second verb ("Atirar" on a bench weapon vs. "Detonar" on a grenade). One shared menu INSTANCE is deliberate, not incidental: room.gd's _unhandled_input treats any click while `_context_menu.visible` as an outside-click cancel, and a second instance would need that guard to know about both. The class and file name are now historical — this is no longer detonation specific. Renaming both is a follow-up, not a silent partial rename that would leave the file and the class disagreeing.

**Signals**
- `signal action_requested`
- `signal cancelled`
- `signal opened`
- `signal closed`

**Public API**
- `func open_at(top_anchor_screen_pos: Vector2, gap_above_px: float = 30.0, action_key: String = "ui.context_menu.detonate", on_confirm: Callable = Callable()) -> void:`
- `func close() -> void:`

---

### `enemy_banner_panel.gd`

`class_name EnemyBannerPanel` · extends `"res://godot/scripts/ui/window_base.gd"` · 31 lines

`godot/scripts/ui/enemy_banner_panel.gd`

**Public vars**
- `var lbl_enemy_turn: Label`

**Public API**
- `func show_banner() -> void:`
- `func hide_banner() -> void:`

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

### `main_menu_panel.gd`

`class_name MainMenuPanel` · extends `WindowBase` · 113 lines

`godot/scripts/ui/main_menu_panel.gd`

> PAUSE-MENU-01: First concrete menu built on WindowBase.

**Signals**
- `signal reset_requested`
- `signal settings_requested`
- `signal controls_requested`
- `signal showcase_requested`

**Public API**
- `func open() -> void:`

---

### `modal_stack.gd`

`class_name ModalStack` · 46 lines

`godot/scripts/ui/modal_stack.gd`

> ModalStack — single source of truth for what Escape targets next. Root cause this replaces: Escape (`ui_pause`) was handled unconditionally in InputController._input(), which runs before room.gd's own _unhandled_input() — so a context menu's own Escape-aware check never got a chance to run, and Escape always opened the Main Menu instead of cancelling whatever was actually on top (2026-07-22 bug report). Any modal — a WindowBase panel, the grenade context menu, a future sub-menu — pushes its own close callable when it opens and is removed when it closes, by whatever path (Escape, its own Cancel/Back button, an outside click). Escape always targets the top of the stack, so nested menus (Main Menu -> Controls, or a world context menu opened over gameplay) close in the right order on successive presses instead of every Escape independently racing to open the Main Menu.

**Public API**
- `func push(close_callable: Callable) -> void:`
- `func remove(close_callable: Callable) -> void:`
- `func is_empty() -> bool:`
- `func handle_escape() -> bool:`

---

### `panel_base.gd`

`class_name PanelBase` · 53 lines

`godot/scripts/ui/panel_base.gd`

> PANEL-01: Base class for all panels and windows. Provides open/close state management and signal hooks. Background slot (background child) is designed to be replaced by TextureRect/AnimatedSprite2D later.

**Signals**
- `signal opened`
- `signal closed`

**@export**
- `title: String = ""`

**Public API**
- `func open() -> void:`
- `func close() -> void:`
- `func is_open() -> bool:`

---

### `selection_overlay.gd`

extends `Node2D` · 34 lines

`godot/scripts/ui/selection_overlay.gd`

**Constants / tuning**
- `COLOR_PINK` = `Color(0.90, 0.10, 0.45, 1.0)`
- `LINE_W` = `4.0`

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_selected(cell: Vector2i) -> void:`

---

### `showcase_panel.gd`

`class_name ShowcasePanel` · extends `WindowBase` · 211 lines

`godot/scripts/ui/showcase_panel.gd`

> ACTOR_MASTER_PLAN D20/Part 5a — Showcase screen. First concrete Part 5 (live 3D inspection window) application: a live SubViewport with a real Camera3D shows an imported mesh (D12's imported-mesh path, proven by shotgun_preview_spike.gd) filling most of the screen, auto-rotating slowly (D10's "auto-spin" option). Name/info sits in a separate area, laid out adaptively — a bottom strip in portrait (9:16), a side panel in landscape (16:9) — per D20. Breakpoint value and info content are both first-cut choices, not final (§7 open question #14). The object here (Shotgun Short Stock, D18's objects-track first case) is hardcoded for this first cut — no ShowcaseItem registry exists yet; that is exactly the kind of thing D19 says not to build before proving the mechanism works.

**Constants / tuning**
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Shotgun Short Stock.glb"`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_START_DEG` = `45.0`

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

### `top_bar_panel.gd`

`class_name TopBarPanel` · extends `"res://godot/scripts/ui/panel_base.gd"` · 63 lines

`godot/scripts/ui/top_bar_panel.gd`

**Public vars**
- `var btn_end_turn: Button`
- `var btn_reset: Button`
- `var btn_fullscreen: Button`
- `var btn_viewport: Button`
- `var btn_numbers: Button`
- `var chk_auto_end_turn: CheckBox`
- `var lbl_ap: Label`
- `var lbl_alert: Label`
- `var lbl_end_turn: Label`

**Public API**
- `func open() -> void:`
- `func close() -> void:`

---

### `window_base.gd`

`class_name WindowBase` · extends `"res://godot/scripts/ui/panel_base.gd"` · 24 lines

`godot/scripts/ui/window_base.gd`

> PANEL-01: Base class for all windows (panels with close semantics). Extends PanelBase with close_requested signal and pause handling.

**Signals**
- `signal close_requested`

**@export**
- `pausable: bool = false`

**Public API**
- `func request_close() -> void:`

---

## world/

### `room_builder.gd`

`class_name RoomBuilder` · 988 lines

`godot/scripts/world/builders/room_builder.gd`

> RoomBuilder Orchestrates room construction, tile placement, and perspective transformations. Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

**Constants / tuning**
- `WALL_FLOOR_STEP_PX` = `20.0`
- `WALL_BASE_Z_INDEX` = `8`
- `INVALID_CELL` = `Vector2i(-1, -1)`

**Public vars**
- `var room: Node`
- `var PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")`
- `var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`
- `var PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")`
- `var floor_layer: TileMapLayer = null`
- `var structure_layer: TileMapLayer = null`

**Public API**
- `func setup(floor_ref: TileMapLayer, structure: TileMapLayer, wall_tileset: TileSet) -> void:`
- `func build_from_layout(layout: Dictionary, room_size: Vector2i) -> void:`
- `func get_blocked_cells() -> Dictionary:`
- `func get_prop_heights() -> Dictionary:`
- `func get_exit_cells() -> Array[Vector2i]:`
- `func get_light_sources() -> Array:`
- `func build_registry(ts: TileSet) -> void:`
- `func build_navigation_blocked_cells(guards: Array) -> Array[Vector2i]:`
- `func invalidate_bake_cache() -> void:`
- `func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:`

---

### `debug_tools_controller.gd`

`class_name DebugToolsController` · 158 lines

`godot/scripts/world/controllers/debug_tools_controller.gd`

> DEBUG-02: Debug tools controller — handles F2/F3/F4 debug toggles and voxel nudging. Extracted from room.gd (Task 03 modularization). Signals room on mode changes; room holds references to debug overlays and toggles.

**Public vars**
- `var room: Node`

**Public API**
- `func toggle_map_loader_panel() -> void:`
- `func create_map_loader_button() -> void:`
- `func toggle_voxel_ruler_overlay() -> void:`
- `func toggle_nudge_mode() -> void:`
- `func toggle_bake_mode() -> void:`
- `func cycle_blend_mode() -> void:`
- `func apply_nudge(delta: Vector2) -> void:`
- `func reset_nudge() -> void:`
- `func try_change_posture(new_posture: DebugAgent.Posture) -> void:`
- `func is_nudge_mode_active() -> bool:`

---

### `input_controller.gd`

`class_name InputController` · 159 lines

`godot/scripts/world/controllers/input_controller.gd`

> INPUT-01: Input controller — dispatches mapped input actions to signals. Extracted from room.gd to provide a single source of truth for input bindings and enable rebinding without touching gameplay code. Signals are emitted here; room.gd connects and handles the resulting actions.

**Signals**
- `signal posture_lower_requested`
- `signal posture_raise_requested`
- `signal view_mode_requested(mode: String)`
- `signal peek_initiated`
- `signal movement_input_requested(direction: Vector2i, is_large_step: bool)`
- `signal debug_command_requested(command: String)`
- `signal screenshot_requested`
- `signal pause_requested`

**Public vars**
- `var room: Node`

---

### `selection_controller.gd`

`class_name SelectionController` · 98 lines

`godot/scripts/world/controllers/selection_controller.gd`

> Selection Controller: manages tile selection, validation, and player movement attempts. Extracted from room.gd (Task 05 modularization). Delegates to room for state access (movement_overlay, selection_overlay, etc.)

**Public vars**
- `var room: Node`
- `var selected_cell: Vector2i = Vector2i(-1, -1)`

**Public API**
- `func is_selectable_cell(cell: Vector2i) -> bool:`
- `func set_selected_cell(cell: Vector2i) -> void:`
- `func handle_tile_click(cell: Vector2i) -> void:`
- `func try_move_to(cell: Vector2i) -> bool:`
- `func handle_move_click(cell: Vector2i) -> void:`

---

### `test_zone_controller.gd`

`class_name TestZoneController` · 369 lines

`godot/scripts/world/controllers/test_zone_controller.gd`

> TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click "Detonar" on a test prop. ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a "digital twin" (Quaternius' CC0 "Grenade" model, poly.pizza) rendered via the real-3D-model + normal-map bake technique proven for the shotgun (godot/scripts/tools/grenade_frame_bake_spike.gd, 2026-07-28) — displayed via GrenadeProp (godot/scripts/overlays/grenade_prop.gd), NOT live TileMapLayer voxel cells. Superseded the original single-angle bake_voxel_sprite_3d.gd bake (grenade_bake_x8.png, a hand-placed BoxMesh voxel reconstruction of a CC0 .qb — itself already a v2 over a hand-rolled 2D painter's-algorithm rasterizer, v1) once that was shown to read flat from some angles and to ignore the room's active N/E/S/W perspective entirely, the same class of bug D22 found and fixed for the shotgun. Proves the mechanism ACTOR_MASTER_PLAN D1/D2 describes for one object before Parts 0-2 of that plan get built for real. Registry stays a plain Array[Dictionary] on purpose — scaffolding for the PLAYGROUND rebuild, not a permanent prop-interaction architecture. Delegates to room for shared state, same extraction pattern as SelectionController.

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GrenadePropClass` = `preload("res://godot/scripts/overlays/grenade_prop.gd")`
- `MENU_GAP_ABOVE_PX` = `30.0`
- `BOMB_ID` = `"frag_grenade"`
- `_EMBER_NEIGHBOURS` = `[ Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), ]`

**Public vars**
- `var room: Node`

**Public API**
- `func clear() -> void:`
- `func cancel_active() -> void:`

---

### `turn_controller.gd`

`class_name TurnController` · 376 lines

`godot/scripts/world/controllers/turn_controller.gd`

> TurnController Orchestrates turn phases, enemy AI execution, and alert meter management. Handles tactical state updates, detection/alert accumulation, and camera control.

**Constants / tuning**
- `DETECTION_THRESHOLD_SUSPICIOUS` = `0.25`
- `DETECTION_THRESHOLD_ALERT` = `0.50`
- `DETECTION_THRESHOLD_CHASE` = `0.75`
- `ENEMY_CAMERA_TWEEN_DURATION` = `0.4`
- `ENEMY_PHASE_MAX_OPEN_ZOOM` = `2.0`
- `ACTOR_END_HOLD_DELAY` = `0.2`

**Public vars**
- `var room: Node`
- `var turn_manager: TacticalTurnManager = null`
- `var enemy_phase_controller: EnemyPhaseController = null`
- `var agent: DebugAgent = null`
- `var camera: Camera2D = null`
- `var floor_layer: TileMapLayer = null`
- `var VISUAL_GRID_OFFSET: Vector2 = Vector2.ZERO`
- `var FOW_REVEAL_RADIUS: int = 0`
- `var vision_bonus_tiles: int = 0`

**Public API**
- `func setup( p_turn_manager: TacticalTurnManager, p_enemy_phase_controller: EnemyPhaseController, p_agent: DebugAgent, p_camera: Camera2D, p_floor_layer: TileMapLayer, p_fow_controller: Object, p_hud_controller: Object, p_vision_controller: Object, p_guard_coordinator: Object, p_noise_system: Object, p_noise_overlay: Object ) -> void:`
- `func set_constants( p_visual_grid_offset: Vector2, p_fow_radius: int, p_vision_bonus: int, p_alert_max: int, p_alert_gain: int ) -> void:`
- `func set_game_state( p_guards: Array, p_blocked_cells: Dictionary, p_current_blocked_edges: Array[Dictionary], p_room_size: Vector2i ) -> void:`
- `func get_alert_meter() -> int:`

---

### `weapon_bench_controller.gd`

`class_name WeaponBenchController` · 306 lines

`godot/scripts/world/controllers/weapon_bench_controller.gd`

> WeaponBenchController — WEAPON-FIRE-01 (Director, 2026-07-29): right-click "Atirar" on a placed weapon, producing a directional cone of destruction against whatever material it is aimed at. Sibling of TestZoneController, not an extension of it. That class is the GRENADE controller — its own header calls itself "scaffolding for the PLAYGROUND rebuild, not a permanent prop-interaction architecture" — and a weapon differs from a grenade in every part that matters: it has a FACING, it is not consumed when used, and its damage is a wedge rather than rings. What the two share (screen-space hit-test, context-menu anchoring) is ~40 lines of geometry, which is cheaper to mirror than a premature generalisation of two things that are both explicitly temporary. The weapons themselves are FloatingCollectible instances in static-facing mode (see that class's header) — this controller owns the registry and the interaction, not the rendering.

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `FloatingCollectibleClass` = `preload("res://godot/scripts/overlays/floating_collectible.gd")`
- `FACING_DELTA` = `{ "NW": Vector2i(-1, 0), "NE": Vector2i(0, -1), "SE": Vector2i(1, 0), "SW": Vector2i(0, 1), }`
- `MENU_GAP_ABOVE_PX` = `30.0`
- `WEAPON_GRADE_SATURATION` = `1.3`
- `WEAPON_GRADE_CONTRAST` = `1.15`
- `PELLET_FLOOD_MAX_STEPS` = `40`

**Public vars**
- `var room: Node`

**Public API**
- `func clear() -> void:`
- `func add_weapon(gu_cell: Vector2i, facing: String, weapon_id: String, frames_dir: String, sprite_scale: float, shadow_scale_factor: float) -> void:`
- `func reposition_for_perspective(direction: String) -> void:`
- `func hit_test(screen_pos: Vector2) -> int:`
- `func open_menu_for(index: int) -> void:`
- `func cancel_active() -> void:`
- `func fire_active() -> void:`

---

### `world_markers_overlay_controller.gd`

`class_name WorldMarkersOverlayController` · 165 lines

`godot/scripts/world/controllers/world_markers_overlay_controller.gd`

> WorldMarkersOverlayController Manages shadow spill cosmetics and marker overlays (shadow boundary, light rays). Shadow spill is a cosmetic halo that bleeds from full-shadow tiles onto neighbours. Purely visual — never feeds gameplay (ExposureSystem reads raw geometry).

**Constants / tuning**
- `SHADOW_SPILL_RADIUS` = `2`
- `SHADOW_SPILL_MAX_RADIUS` = `4`
- `SHADOW_SPILL_DENSITY_STEP` = `2`
- `SHADOW_SPILL_BASE_DARKEN` = `0.18`
- `SHADOW_SPILL_FALLOFF` = `0.5`
- `SHADOW_SPILL_DIAGONAL_FACTOR` = `0.65`
- `PENUMBRA_MULT` = `0.5`

**Public vars**
- `var room: Node`
- `var floor_layer: Node2D = null`

**Public API**
- `func setup(tile_shadow: Node2D, lighting_controller: Node, shadow_boundary: Node, light_ray: Node, vision_controller: Node, floor_layer_ref: Node2D, visual_offset: Vector2, room_size: Vector2i, shadow_tiles: Dictionary) -> void:`
- `func repaint_world_shadows() -> void:`
- `func draw_shadow_debug() -> void:`

---

### `level_graph.gd`

`class_name LevelGraph` · extends `RefCounted` · 98 lines

`godot/scripts/world/level_graph.gd`

**Constants / tuning**
- `SEG_SIZE` = `Vector2i(18, 36)`
- `EXIT_CELLS` = `{ "NW": Vector2i(9, 0), "SE": Vector2i(9, 35), "SW": Vector2i(0, 17), "NE": Vector2i(17, 17), }`

**Public API**
- `func generate(seed_input: int) -> Dictionary:`

---

### `playground_map.gd`

`class_name PlaygroundMap` · extends `RefCounted` · 18 lines

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

### `file_map_source.gd`

`class_name FileMapSource` · extends `RefCounted` · 151 lines

`godot/scripts/world/maps/file_map_source.gd`

**Constants / tuning**
- `RES_MAPS_DIR` = `"res://maps"`
- `USER_MAPS_DIR` = `"user://maps"`

**Public vars**
- `var registry: Variant`
- `var service: Variant`

**Public API**
- `func list_available() -> Dictionary:`
- `func get_runtime_spec(map_id: String) -> Dictionary:`

---

### `map_catalog.gd`

`class_name MapCatalog` · extends `RefCounted` · 49 lines

`godot/scripts/world/maps/map_catalog.gd`

**Constants / tuning**
- `PlaygroundMapClass` = `preload("res://godot/scripts/world/maps/definitions/playground_map.gd")`
- `Sigma01MapClass` = `preload("res://godot/scripts/world/maps/definitions/sigma_01_map.gd")`
- `ProceduralMapClass` = `preload("res://godot/scripts/world/maps/definitions/procedural_map.gd")`
- `DEFAULT_MAP_ID` = `"PLAYGROUND"`

---

### `map_compiler.gd`

`class_name MapCompiler` · extends `RefCounted` · 356 lines

`godot/scripts/world/maps/map_compiler.gd`

**Constants / tuning**
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `MapGeometryClass` = `preload("res://godot/scripts/world/maps/map_geometry.gd")`
- `REQUIRED_KEYS` = `["inner_size", "agent_start"]`
- `EXTERIOR_WALL_STOREYS` = `3`
- `DEFAULT_CEILING_FLOORS` = `8`

---

### `map_geometry.gd`

`class_name MapGeometry` · extends `RefCounted` · 159 lines

`godot/scripts/world/maps/map_geometry.gd`

---

### `map_file_service.gd`

`class_name MapFileService` · extends `RefCounted` · 135 lines

`godot/scripts/world/maps/persistence/map_file_service.gd`

> MapFileService — Load/save .map.json files with migration and validation Core responsibilities: 1. Load .map.json from res://maps/ or user://maps/ (user wins on ID collision) 2. Apply per-section migrations (registry delegates the heavy lifting) 3. Deserialize each section via its owner 4. Validate the result before returning 5. Save via serialize + re-emit unknown sections verbatim (tolerant round-trip)

**Constants / tuning**
- `FORMAT_TAG` = `"infiltraitor-map"`
- `CURRENT_SCHEMA_VERSION` = `3`

**Public vars**
- `var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")`
- `var registry: Variant`

**Public API**
- `func load_file(path: String) -> Dictionary:`
- `func save_file(path: String, spec: Dictionary) -> Dictionary:`

---

### `map_section_registry.gd`

`class_name MapSectionRegistry` · extends `RefCounted` · 65 lines

`godot/scripts/world/maps/persistence/map_section_registry.gd`

> MapSectionRegistry — Anti-breakage core for tolerant round-trip serialization A section owner encapsulates everything the engine knows about a given section's internal shape: serialization, deserialization, and the migration chain from prior versions. The registry is the ONLY code that special-cases sections by name; the core load/save loop (MapFileService) is generic and never touches section internals. Adding a new section = one registration; adding a field to an existing section = one migration lambda. This mechanism satisfies requirement 4: "hard to break; keeps saving correctly after new sections are invented."

**Public API**
- `func register(owner: SectionOwner) -> void:`
- `func get_owner(section_id: String) -> SectionOwner:`
- `func known_sections() -> Array:`
- `func migrate_section(section_id: String, raw: Dictionary) -> Variant:`

---

### `map_sections_v1.gd`

`class_name MapSectionsV1` · extends `RefCounted` · 159 lines

`godot/scripts/world/maps/persistence/map_sections_v1.gd`

> MapSectionsV1 — Registration of board, walls, blocks, props, actors sections (v1)

---

### `room.gd`

extends `Node2D` · 3333 lines

`godot/scripts/world/room.gd`

**Constants / tuning**
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `GuardEnemyClass` = `preload("res://godot/scripts/agents/guard_enemy.gd")`
- `GuardNoiseIndicatorClass` = `preload("res://godot/scripts/overlays/guard_noise_indicator.gd")`
- `CeilingPropOverlayClass` = `preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")`
- `TileOverlayClass` = `preload("res://godot/scripts/overlays/tile_overlay.gd")`
- `DebugToolsControllerClass` = `preload("res://godot/scripts/world/controllers/debug_tools_controller.gd")`
- `InputControllerClass` = `preload("res://godot/scripts/world/controllers/input_controller.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `SelectionControllerClass` = `preload("res://godot/scripts/world/controllers/selection_controller.gd")`
- `TestZoneControllerClass` = `preload("res://godot/scripts/world/controllers/test_zone_controller.gd")`
- `WeaponBenchControllerClass` = `preload("res://godot/scripts/world/controllers/weapon_bench_controller.gd")`
- `DetonateContextMenuClass` = `preload("res://godot/scripts/ui/detonate_context_menu.gd")`
- `ModalStackClass` = `preload("res://godot/scripts/ui/modal_stack.gd")`
- `WorldMarkersOverlayControllerClass` = `preload("res://godot/scripts/world/controllers/world_markers_overlay_controller.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `TurnControllerClass` = `preload("res://godot/scripts/world/controllers/turn_controller.gd")`
- `ShadowBoundaryOverlayClass` = `preload("res://godot/scripts/overlays/shadow_boundary_overlay.gd")`
- `LightRayOverlayClass` = `preload("res://godot/scripts/overlays/light_ray_overlay.gd")`
- `EmberOverlayClass` = `preload("res://godot/scripts/overlays/ember_overlay.gd")`
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`
- `VisionControllerClass` = `preload("res://godot/scripts/controllers/vision_controller.gd")`
- `HudControllerClass` = `preload("res://godot/scripts/controllers/hud_controller.gd")`
- `LightingControllerClass` = `preload("res://godot/scripts/controllers/lighting_controller.gd")`
- `CameraControllerClass` = `preload("res://godot/scripts/controllers/camera_controller.gd")`
- `FowControllerClass` = `preload("res://godot/scripts/controllers/fow_controller.gd")`
- `GuardCoordinatorClass` = `preload("res://godot/scripts/controllers/guard_coordinator.gd")`
- `BakeConfigClass` = `preload("res://godot/scripts/systems/bake_config.gd")`
- `DevVisionStatusPanelClass` = `preload("res://godot/scripts/debug/dev_vision_status_panel.gd")`
- `GuGridOverlayClass` = `preload("res://godot/scripts/overlays/gu_grid_overlay.gd")`
- `BlastWireframeOverlayClass` = `preload("res://godot/scripts/overlays/blast_wireframe_overlay.gd")`
- `EdgeExtractorClass` = `preload("res://godot/scripts/geometry/edge_extractor.gd")`
- `SliceGeneratorClass` = `preload("res://godot/scripts/geometry/slice_generator.gd")`
- `JunctionResolverClass` = `preload("res://godot/scripts/geometry/junction_resolver.gd")`
- `EdgeRegistryClass` = `preload("res://godot/scripts/geometry/edge_registry.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `OcclusionSetClass` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `OcclusionOverlayClass` = `preload("res://godot/scripts/overlays/occlusion_overlay.gd")`
- `OcclusionWireframeOverlayClass` = `preload("res://godot/scripts/overlays/occlusion_wireframe_overlay.gd")`
- `TILESET_PATH` = `"res://godot/resources/tilesets/tileset_blocks.tres"`
- `INVALID_CELL` = `Vector2i(-9999, -9999)`
- `VISUAL_GRID_OFFSET` = `Vector2(0.0, 512.0)`
- `WALL_BASE_Z_INDEX` = `10`
- `WALL_FLOOR_STEP_PX` = `158.0`
- `VOXEL_STEP_PX` = `20.0`
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
- `TRAIL_MAX` = `5`
- `TEST_ZONE_GRENADE_GUS` = `[ Vector2i(3, 5),   ## concrete wall (gu 2,2 - 4,2) Vector2i(8, 5),   ## metal wall (gu 7,2 - 9,2) Vector2i(13, 5),  ## stone wall (gu 12,2 - 14,2) Vector2i(18, 5),  ## wood wall (gu 17,2 - 19,2) ]`

**Public vars**
- `var CRATE_STACK_STEP_PX: float = 128.0`
- `var vision_bonus_tiles: int = 0`

**Public API**
- `func record_voxel_damage_to_base(grid_pos: Vector2i, level: int, damage_state: int, is_blast: bool = false, carved_side: int = Voxel.CarvedSide.NONE) -> void:`

---

### `tile_registry.gd`

`class_name TileRegistry` · extends `RefCounted` · 12 lines

`godot/scripts/world/tile_registry.gd`

> AUTO-GENERATED by godot/scripts/tools/build_tileset.gd Re-run the builder whenever tiles are added or renamed. Maps tile_name strings to TileSet source_ids.

**Constants / tuning**
- `TILES` = `{ "floor_NE": 0, "floor_NW": 1, "floor_SE": 2, "floor_SW": 3, }`

---

### `tile_semantics.gd`

`class_name TileSemantics` · extends `RefCounted` · 166 lines

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
- `func debug_string() -> String:`
- `func debug_info() -> String:`

---

### `perspective_mapper.gd`

`class_name PerspectiveMapper` · 238 lines

`godot/scripts/world/utilities/perspective_mapper.gd`

> Perspective Mapper: static utility for isometric perspective transformations. Handles direction-based cell coordinate conversions and tile name suffix remapping. Extracted from room.gd (Task 04 modularization).

**Constants / tuning**
- `SUFFIX_MAP` = `{ "N": {"NE": "NE", "SE": "SE", "SW": "SW", "NW": "NW"}, "E": {"NE": "SE", "SE": "SW", "SW": "NW", "NW": "NE"}, "S": {"NE": "SW", "SE": "NW", "SW": "NE", "NW": "SE"}, "W": {"NE": "NW", "SE": "NE", "SW": "SE", "NW": "SW"}, }`

---

### `wall_edge_data.gd`

`class_name WallEdgeData` · 30 lines

`godot/scripts/world/wall_edge_data.gd`

> Consolidated edge key generation and wall blocking logic. Centralizes edge handling to prevent duplication and enable consistent future enhancements.

---
