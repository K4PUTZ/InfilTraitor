# CODEMAP — INFILTRAITOR

> **GENERATED FILE — do not edit by hand.**
> Produced by `tools/persistent/gen_codemap.py` from the actual GDScript
> source. Regenerate with `python3 tools/persistent/gen_codemap.py`.
> A pre-commit hook blocks commits when this file is stale.
>
> Design rationale and the inviolable rules live in `CLAUDE.md`
> (hand-authored). This file is the mechanical mirror of the code.

**239 scripts · 86002 lines total** (under `godot/scripts/`)

## Index

- **agents/** — agent.gd, agent_sprite.gd, guard_attention.gd, guard_enemy.gd
- **controllers/** — camera_controller.gd, fow_controller.gd, guard_coordinator.gd, hud_controller.gd, lighting_controller.gd, vision_controller.gd
- **debug/** — atom_sheet_debug.gd, circle_gate_probe.gd, damage_gallery_debug.gd, dev_vision_status_panel.gd, map_loader_panel.gd, theme_matrix_debug_view.gd, vfx_draw_probe.gd, voxel_ruler_overlay.gd
- **geometry/** — damage_composite_cache.gd, decal_compositor.gd, edge.gd, edge_extractor.gd, edge_registry.gd, face.gd, geometry_coords.gd, glass_pane_grouper.gd, half_voxel_compositor.gd, high_wall.gd, junction_resolver.gd, passage_query.gd, slab.gd, slab_generator.gd, slab_registry.gd, slice.gd, slice_generator.gd, voxel.gd, voxel_renderer.gd
- **navigation/** — guard_pathfinder.gd, movement_overlay.gd, path_preview.gd
- **overlays/** — agent_probe_prop.gd, aim_bubble_overlay.gd, blast_wireframe_overlay.gd, ceiling_prop_overlay.gd, circle_field.gd, debris_overlay.gd, elite_exposure_overlay.gd, ember_overlay.gd, explosion_flash_overlay.gd, exposure_overlay.gd, floating_collectible.gd, glass_crack_sprite.gd, glass_rain_overlay.gd, grenade_prop.gd, gu_grid_overlay.gd, guard_noise_indicator.gd, height_overlay.gd, light_overlay.gd, light_ray_overlay.gd, noise_overlay.gd, occlusion_overlay.gd, occlusion_slice_panel.gd, occlusion_wireframe_overlay.gd, shadow_boundary_overlay.gd, shadow_overlay.gd, shard_field.gd, shrapnel_overlay.gd, shrapnel_preview_overlay.gd, smoke_spark_overlay.gd, target_cursor_overlay.gd, temporal_overlay.gd, throw_arc_overlay.gd, throw_perimeter_overlay.gd, tile_overlay.gd, tile_risk_overlay.gd, tracer_overlay.gd, trail_overlay.gd
- **systems/** — bake_compositor.gd, bake_config.gd, bake_policy.gd, baked_tile_lookup.gd, collectible_bake_config.gd, collectible_frame_cache.gd, damage_variant_baker.gd, blast_calculator.gd, bomb_def.gd, bomb_registry.gd, detonation_entry_writer.gd, detonation_plan_builder.gd, detonation_presenter.gd, glass_crack.gd, glass_fall.gd, glass_opening.gd, glass_shard_shapes.gd, glass_shatter.gd, material_resistance_table.gd, shot_hit_roll.gd, shot_punch_table.gd, weapon_def.gd, weapon_registry.gd, earth_variant_selector.gd, enemy_phase_controller.gd, facade_sampler.gd, glass_materials.gd, exposure_system.gd, light_anchor.gd, light_registry.gd, light_source.gd, shadow_projector.gd, shadow_result.gd, voxel_light_field.gd, localization_manager.gd, material_registry.gd, metal_pattern.gd, noise_system.gd, occlusion_set.gd, detonation_prediction.gd, prediction_cache.gd, world_delta.gd, prop_def.gd, prop_registry.gd, registries_autoload.gd, save_state.gd, stone_pattern.gd, texture_resolver.gd, theme_applier.gd, tic_system.gd, turn_manager.gd, version_info.gd, voxel_variant_registry.gd, wood_pattern.gd
- **tools/** — actor_frame_bake_spike.gd, actor_part0_spike.gd, agent_frame_bake_spike.gd, bake_cache_selftest.gd, bake_selftest.gd, bake_voxel_sprite_3d.gd, blast_calculator_selftest.gd, blast_purity_selftest.gd, build_tileset.gd, ceiling_carve_seam_selftest.gd, damage_atom_bake_selftest.gd, damage_composite_cache_selftest.gd, decal_compositor_equality_selftest.gd, decal_seam_selftest.gd, destruction_part0_spike.gd, detonation_plan_selftest.gd, dump_glass_openings.gd, earth_variant_selftest.gd, fixed_floor_selftest.gd, floor_integration_selftest.gd, floor_sunk_seam_selftest.gd, floor_zone_bake_selftest.gd, generic_mark_seam_selftest.gd, geometry_selftest.gd, glass_crack_selftest.gd, glass_fall_selftest.gd, glass_remnant_atom_capture.gd, glass_rim_capture.gd, glass_shard_shapes_capture.gd, glass_shard_shapes_selftest.gd, glass_shatter_selftest.gd, glass_transparency_selftest.gd, grenade_collectible_bake_spike.gd, grenade_frame_bake_spike.gd, half_thickness_selftest.gd, half_voxel_compositor_equality_selftest.gd, half_voxel_seam_selftest.gd, input_controller_selftest.gd, iso_projection_selftest.gd, map_lint.gd, mapfile_roundtrip_selftest.gd, material_reform_selftest.gd, material_tree_selftest.gd, negative_storey_selftest.gd, neon_flicker_selftest.gd, occlusion_set_selftest.gd, panel_base_selftest.gd, passage_query_selftest.gd, project_lint_validator.gd, prop_01_selftest.gd, resolver_hardening_selftest.gd, roof_bake_selftest.gd, roof_integration_selftest.gd, roof_slab_selftest.gd, s1_normal_compression_spike.gd, s2_resident_memory_probe.gd, save_state_selftest.gd, shotgun_preview_spike.gd, slab_geometry_selftest.gd, slab_render_selftest.gd, slice_geometry_selftest.gd, texture_resolver_selftest.gd, tile_anatomy_audit.gd, tint_baked_atom_selftest.gd, version_info_selftest.gd, voxel_decal_selftest.gd, voxel_face_separation_selftest.gd, voxel_light_incremental_selftest.gd, voxel_persist_selftest.gd, weapon_frames_bake.gd
- **ui/** — controls_panel.gd, detonate_context_menu.gd, enemy_banner_panel.gd, fog_of_war_overlay.gd, main_menu_panel.gd, modal_stack.gd, panel_base.gd, selection_overlay.gd, showcase_panel.gd, tile_labels_overlay.gd, top_bar_panel.gd, window_base.gd
- **world/** — room_builder.gd, agent_shot_controller.gd, debug_tools_controller.gd, input_controller.gd, selection_controller.gd, test_zone_controller.gd, turn_controller.gd, weapon_bench_controller.gd, world_markers_overlay_controller.gd, level_graph.gd, playground_map.gd, procedural_map.gd, sigma_01_map.gd, file_map_source.gd, map_catalog.gd, map_compiler.gd, map_geometry.gd, map_file_service.gd, map_section_registry.gd, map_sections_v1.gd, room.gd, tile_registry.gd, tile_semantics.gd, iso_projection.gd, perspective_mapper.gd, wall_edge_data.gd

---

## agents/

### `agent.gd`

`class_name DebugAgent` · extends `Node2D` · 497 lines

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
- `POSTURE_HIT_MULT` = `{ Posture.STANDING:  1.00, Posture.CROUCHING: 0.50, Posture.PRONE:     0.70, }`
- `POSTURE_AIM_MULT` = `{ Posture.STANDING:  1.00, Posture.CROUCHING: 0.75, Posture.PRONE:     0.50, }`
- `POSTURE_SPRITE_NAME` = `{ Posture.STANDING: "standing", Posture.CROUCHING: "crouch", Posture.PRONE: "prone", }`
- `COVER_FULL_MULT` = `0.20`
- `COVER_PARTIAL_MULT` = `0.55`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `COLOR_SHADOW` = `Color(0.0, 0.0, 0.0, 0.28)`
- `HEAD_OFFSET` = `{ Posture.STANDING: Vector2(0.0, -64.0), Posture.CROUCHING: Vector2(0.0, -44.0), Posture.PRONE: Vector2(26.0, -10.0), }`
- `MUZZLE_DROP_FRACTION` = `0.18`
- `THROW_RAISE_SECONDS` = `0.18`
- `THROW_RELEASE_SECONDS` = `0.40`
- `THROW_CANCEL_SECONDS` = `0.12`
- `SILHOUETTE_WIDTH` = `104.0`
- `SILHOUETTE_HEIGHT` = `222.0`
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
- `var sprite: AgentSprite = null`
- `var cover_state: CoverType = CoverType.NONE`
- `var cover_direction: Vector2i = Vector2i.ZERO`
- `var step_duration: float = 0.56`

**Public API**
- `func throw_origin() -> Vector2:`
- `func muzzle_origin() -> Vector2:`
- `func play_throw_raise() -> bool:`
- `func play_throw_cancel() -> bool:`
- `func play_throw_release() -> bool:`
- `func set_grip(name: String) -> void:`
- `func throw_launch_height() -> float:`
- `func setup(tile_layer: TileMapLayer, offset: Vector2, start_cell: Vector2i) -> void:`
- `func attach_sprite(p_room: Node) -> bool:`
- `func set_cell(new_cell: Vector2i) -> void:`
- `func get_vision_radius() -> int:`
- `func set_posture(new_posture: Posture) -> void:`
- `func set_dev_vision(enabled: bool) -> void:`
- `func on_perspective_changed() -> void:`
- `func update_cover(blocked_cells: Dictionary) -> void:`
- `func move_along_path(path: Array[Vector2i]) -> void:`

---

### `agent_sprite.gd`

`class_name AgentSprite` · extends `Sprite2D` · 1454 lines

`godot/scripts/agents/agent_sprite.gd`

> CHARACTER_MASTER_PLAN Part 2 §10 — the baked figure ON the playable agent. This is the node that closes Part 2. `AgentProbeProp` put the figure in the room to be LOOKED at; this one puts it on the thing the player moves, which is the difference §10 draws between "the pipeline works" and done. It is a child of `DebugAgent` rather than a replacement for it, because the agent is a Node2D that owns grid state, tweening and signals, and none of that wants to become a Sprite2D. The agent keeps position; this keeps appearance. --- FOUR THINGS IT DOES THAT THE PROBE DOES NOT --- 1. THREE POSTURES, EACH ITS OWN BAKE WITH ITS OWN ANCHOR. The placeholder it replaces drew three shapes; a single standing sprite would have been a regression, not a swap. The anchors are NOT shared: the bake recentres each model on its own AABB, so the pixel its feet land on differs per posture (standing 227.99, crouch 184.00, prone 156.74 — measured, and read from each posture's own anchor.json rather than transcribed). 2. FACING, SNAPPED AT THE GU BOUNDARY (D47). Ordinary movement changes facing with no transition frames — the Director judged that blind on 2026-08-15, and it is the row that keeps the art budget at 744 body sets instead of 4608. So the facing is set once per step, from the step's own direction, and nothing interpolates. 3. FACING IS STORED IN BASE SPACE, NOT VIEW SPACE. A perspective flip rotates the room; an agent facing a wall must still face that wall afterwards. The cell round-trip through `_cell_to_base` already exists for exactly this reason and the facing has to make the same trip, or the figure would silently turn 90 degrees every time the Director rotated the view. 4. POSTURE FRAME SETS LOAD ON FIRST USE. D42 names RAM, not CPU, as this character's binding constraint. A session where the agent never goes prone should not pay for the prone bake. Everything else — the relight shader, the perspective-aware light mapping (D22), the ground-contact anchoring, the raw-PNG loader — is `AgentProbeProp`'s behaviour, and the duplication between the two files is real and known. The probe stays the single-pose bracket rig it was built as; this is the shipping path.

**Constants / tuning**
- `DEV_ONLY_MILESTONE` = `false`
- `FRAMES_ROOT` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"`
- `FRAMES_ROOT_DEV` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_dev/"`
- `WALK_ROOT` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_walk/"`
- `WALK_ROOT_DEV` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_walk_dev/"`
- `THROW_ROOT` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_throw/"`
- `THROW_ROOT_DEV` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_throw_dev/"`
- `THROW_RAISE` = `"raise"`
- `THROW_RELEASE` = `"release"`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`
- `DIRECTIONS` = `["N", "E", "S", "W"]`
- `YAW_BY_DIRECTION` = `{"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}`
- `POSTURE_DIRS` = `{"standing": "standing", "crouch": "crouch", "prone": "prone"}`
- `LAYER_ROOTS` = `{ "head": "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_head", "hat": "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_hat", }`
- `LAYERS_BY_FAMILY` = `{ "": ["head", "hat"], "_dev": ["head", "hat"], "_enemy": ["head"], "_enemy_white": ["head"], }`
- `LAYERS_DEFAULT` = `["head"]`
- `HEAD_YAW_LIMIT_DEG` = `60.0`
- `SCREEN_COMPASS_BY_FRAME` = `{"N": "NE", "E": "NW", "S": "SW", "W": "SE"}`
- `COMPASS_SCREEN` = `{ "NE": Vector2(0.894, -0.447), "SE": Vector2(0.894, 0.447), "SW": Vector2(-0.894, 0.447), "NW": Vector2(-0.894, -0.447), }`
- `STEPS` = `[Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]`
- `SPRITE_SCALE` = `1.0`
- `SPECULAR_STRENGTH` = `0.0`
- `AMBIENT` = `0.42`
- `SATURATION` = `1.25`
- `CONTRAST` = `1.12`
- `LIGHT_INTENSITY_SCALE` = `0.60`
- `LIGHT_INTENSITY_MAX` = `1.30`
- `LIGHT_RESPONSE_OVERRIDE` = `{ ## 0.75 is the Director's pick from the WHITE-AMBIENT-01 bracket (2026-08-17), ## and the pick is the THIRD step, not the brightest: *"vamos ficar com o ## terceiro, pra não correr o risco de ficar estourado em algumas telas."* ## Measured on PLAYGROUND — floor around the guard spans luma 85 (shadow side) ## to 146 (lit side); 0.75 puts the suit at 174, clear of the whole range by ## +28, while 0.90 reached 212 and visibly flattened the folds. Headroom ## against an over-bright display was the deciding factor, not contrast. "_test_white": {"scale": 1.00, "max": 2.20, "ambient": 0.75}, ## UPDATE 2026-08-18: enemy_white uses the same white blazer, so inherits the ## same light response values. Without this, ambient 0.42 makes the 0.92 albedo ## render as 0.386 in unlit areas — DARKER than PLAYGROUND's floor (~0.55-0.65), ## the "branco virou cinza igual ao chão" issue. "_enemy_white": {"scale": 1.00, "max": 2.20, "ambient": 0.75}, }`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`
- `THROW_RELEASE_FRACTION` = `0.5`

**Public vars**
- `var frame_family: String = ""`
- `var weapon: String = ""`

**Public API**
- `func set_weapon_bake(name: String) -> bool:`
- `func preload_grip(name: String) -> bool:`
- `func set_posture_name(name: String) -> void:`
- `func face_direction(dir: Vector2i) -> void:`
- `func face_step(step: Vector2i) -> void:`
- `func set_dev_vision(enabled: bool) -> void:`
- `func update_for_cell() -> void:`
- `func play_throw(sequence: String, seconds: float, hold: bool = false, reversed_playback: bool = false) -> bool:`
- `func stop_throw() -> void:`
- `func is_throwing() -> bool:`
- `func set_walk_phase_quantise(n: int) -> void:`
- `func set_walk_phase(progress01: float) -> void:`
- `func stop_walking() -> void:`
- `func head_offset_px() -> Vector2:`
- `func set_head_yaw_grid_deg(grid_deg: float) -> void:`
- `func clear_head_yaw() -> void:`

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

`class_name GuardEnemy` · extends `Node2D` · 1237 lines

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

**Public vars**
- `var floor_layer: TileMapLayer = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var enemy_id: String = ""`
- `var cell: Vector2i = Vector2i.ZERO`
- `var patrol_route: Array[Vector2i] = []`
- `var patrol_index: int = 0`
- `var facing: Vector2i = Vector2i.UP`
- `var sprite: AgentSprite = null`
- `var state: String = STATE_PATROL`
- `var state_timer: int = 0`
- `var last_known_agent_cell: Vector2i = INVALID_CELL`
- `var is_moving: bool = false`
- `var fov_degrees: float = 90.0`
- `var fov_range: int = 8`
- `var facing_angle_deg: float = 0.0`
- `var body_angle: float   = 0.0`
- `var vision_angle: float = 0.0`

---

## controllers/

### `camera_controller.gd`

extends `Node` · 283 lines

`godot/scripts/controllers/camera_controller.gd`

**Constants / tuning**
- `DRAG_THRESHOLD_SQ` = `64.0`
- `ZOOM_MIN` = `0.20`
- `ZOOM_MAX` = `1.20`
- `ZOOM_STEP` = `0.06`
- `CAMERA_MAX_BORDER_TILES` = `4`
- `CAMERA_SOFT_ZONE_TILES` = `2`
- `WORLD_TILE_PX` = `128.0`

**Public vars**
- `var shake_phase: float = 0.0`
- `var shake_frequency_x: float = 31.0`
- `var shake_frequency_y: float = 23.0`
- `var shake_decay_power: float = 2.0`

**Public API**
- `func setup(camera_ref: Camera2D, room_ref: Node2D) -> void:`
- `func handle_input(event: InputEvent) -> bool:`
- `func focus_on(world_pos: Vector2) -> void:`
- `func shake(duration: float, amplitude: float) -> void:`
- `func stop_shake() -> void:`
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

extends `Node2D` · 316 lines

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

### `atom_sheet_debug.gd`

`class_name AtomSheetDebug` · extends `CanvasLayer` · 323 lines

`godot/scripts/debug/atom_sheet_debug.gd`

> ATOM-SHEET (2026-08-08, Director) — a contact sheet of EVERY pre-baked damage atom in the loaded map, grouped by material and by the surface it belongs to (WALL / CEILING / FLOOR), with its decal visible. Why a sheet and not more in-world geometry: `damage_gallery_debug.gd` (F5) forces damage onto real voxels scattered across the map, which proves the RENDER PATH works but can only ever show the handful of atoms the map's own geometry happens to expose, at whatever angle the camera is at. This reads the `VoxelVariantRegistry` directly, so what it displays IS the bake — every atom that exists, nothing that doesn't, and a count that can be checked against `registry.size()`. The two are complements: F5 answers "does a damaged voxel render correctly", F8 answers "what did the map actually bake". Atoms come back through `DamageCompositeCache.get_image_at()`, the same readback `DamageVariantBaker` already uses to persist its disk cache — the real composited pixels, not a re-derivation, so an atom that is wrong here is wrong in the game. Substrates: an atom exists once per (material, damage name, substrate) and the substrate axis is just a different crop of the same facade — three near-identical tiles per row, which triples the sheet's size for very little signal. Substrate 0 only by default; set `INFILTRAITOR_ATOM_SHEET_SUBSTRATES=all` to see the axis itself. Debug-only. Never called from gameplay.

**Constants / tuning**
- `DEFAULT_ATOM_SCALE` = `2`
- `ELEMENT_ORDER` = `["WALL", "CEILING", "FLOOR"]`

**Public API**
- `func setup(room: Node) -> bool:`

---

### `circle_gate_probe.gd`

`class_name CircleGateProbe` · extends `Node2D` · 73 lines

`godot/scripts/debug/circle_gate_probe.gd`

**Public vars**
- `var use_field: bool = false`
- `var count: int = 220`
- `var area: Vector2 = Vector2(1180.0, 620.0)`

**Public API**
- `func circle_count() -> int:`

---

### `damage_gallery_debug.gd`

`class_name DamageGalleryDebug` · 252 lines

`godot/scripts/debug/damage_gallery_debug.gd`

> DAMAGE-GALLERY (2026-08-07) — forces DENTED/CRACKED onto real voxels of every declared material, on WALL/FLOOR/CEILING, and reports whether VoxelRenderer.apply_damage_voxel_swap() actually hit a pre-baked atom. Built because the Post-Task-5 soot diagnosis (EXPLOSION_REBUILD_MASTER_PLAN) concluded the "quebradiça" floor texture comes from pre-existing dent/crack art, without first confirming those atoms are baked at all for every material — this checks that assumption directly instead of reasoning about it. Debug-only, triggered by F5 (see debug_tools_controller.gd), never called from gameplay. WALL/FLOOR/CEILING all paint through REAL, registered containers — room._edge_registry's Slices for WALL (EdgeExtractor gives every block-to-block/block-to-floor boundary a real Slice, confirmed by probe: SLICE_13_3_SW etc — the map's per-material test blocks are NOT purely render_block()-anonymous, only their non-boundary interior voxels are), room._slab_registry's Slabs for FLOOR/CEILING. This matters beyond correctness: a throwaway, unregistered Voxel/Slice (this file's first version, for WALL) paints once via a direct apply_damage_voxel_swap() call and then gets silently overwritten by the next repaint (light/occlusion/ FOW reveal all re-render from each container's own tracked Voxel objects) — nothing persists the forced damage anywhere a repaint would consult, so the mark visibly reverted to intact by the time of the capture. Confirmed real, non-reverting bullet marks exist on these same blocks (a live shotgun weapon_fire capture, 2026-08-08) — this now uses that exact register-and-repaint-safe path instead of a one-shot poke.

**Constants / tuning**
- `BLOCK_STOREYS` = `2`
- `MAP_BUFFER_OFFSET` = `Vector2i(1, 1)`
- `MATERIAL_BLOCK_GU` = `{ "concrete": Vector2i(3, 2) + MAP_BUFFER_OFFSET, "metal": Vector2i(8, 2) + MAP_BUFFER_OFFSET, "stone": Vector2i(13, 2) + MAP_BUFFER_OFFSET, "wood": Vector2i(18, 2) + MAP_BUFFER_OFFSET, }`
- `MATERIAL_FLOOR_GU` = `{ "concrete": Vector2i(3, 5) + MAP_BUFFER_OFFSET, "metal": Vector2i(8, 5) + MAP_BUFFER_OFFSET, "stone": Vector2i(13, 5) + MAP_BUFFER_OFFSET, "wood": Vector2i(18, 5) + MAP_BUFFER_OFFSET, }`

---

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

### `vfx_draw_probe.gd`

`class_name VfxDrawProbe` · extends `RefCounted` · 148 lines

`godot/scripts/debug/vfx_draw_probe.gd`

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

### `damage_composite_cache.gd`

`class_name DamageCompositeCache` · extends `RefCounted` · 175 lines

`godot/scripts/geometry/damage_composite_cache.gd`

> D33 Part 1 — DamageCompositeCache: allocates and tracks runtime-composited decal atoms on a growing set of dynamic TileSetAtlasSource pages, mirroring how baked facade pages already work (VoxelRenderer.register_baked_atlas_page()) rather than inventing a second placement mechanism. See PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 1 and §11 for why the key is caller-supplied and opaque here: Part 3 (not yet built) owns constructing a key that is stable in base space and varies by physical face, the two things §10's Part 0 correction established actually matter. This class only owns slot allocation, page growth, and the reset a room rebuild needs — never scene placement (Rule 8: only ever registers a TileSetAtlasSource; every voxel still reaches the tilemap through set_cell()). Lifetime: one instance per VoxelRenderer, reset alongside prune_baked_sources() — same category of per-rebuild-transient state as the baked pages themselves (§11: with player rotation gone, a rebuild only happens once per mission, so "surviving the rebuild" — §10's hardest open question — is no longer something this cache needs to do at all).

**Constants / tuning**
- `ATOM_W` = `32`
- `ATOM_H` = `36`
- `DEFAULT_PAGE_W` = `2048`
- `DEFAULT_PAGE_H` = `2048`

**Public API**
- `func has(key: String) -> bool:`
- `func resolve(key: String) -> Dictionary:`
- `func store(key: String, composite: Image) -> Dictionary:`
- `func flush_dirty_pages() -> int:`
- `func size() -> int:`
- `func page_count() -> int:`
- `func get_image_at(source_id: int, atlas_coords: Vector2i) -> Image:`
- `func get_page_image(page_idx: int) -> Image:`
- `func reset() -> void:`

---

### `decal_compositor.gd`

`class_name DecalCompositor` · extends `RefCounted` · 211 lines

`godot/scripts/geometry/decal_compositor.gd`

> D33 Part 2 — DecalCompositor: the GDScript port of tools/asset_generation/generate_voxel.py's real compositing math (_paste_decal + compose_decal_voxel), NOT the simplified "resize + shear" sketch D33's own §5 originally described — that sketch was written from memory before this file was read line by line. The actual Python compositor inverse-maps every destination pixel into the decal's parametric (s, t) space through a general parallelogram (not a fixed shear), 4x4-supersamples it, and premultiplied-alpha-blends the result — see _paste_decal's own docstring for why (inverse mapping so an oblique projection leaves no holes). This port must be numerically equal to that function, not to a cheaper approximation of it — proven by godot/scripts/tools/decal_compositor_equality_selftest.gd against fixtures godot/scripts/tools/fixtures/d33_part2/ generated straight from the real Python functions (tools/asset_generation/d33_part2_fixture_gen.py). Known, accepted sources of sub-tolerance divergence from the Python reference (measured by the selftest, not assumed away): - Godot's Image.INTERPOLATE_LANCZOS and Pillow's Image.LANCZOS are different implementations (kernel radius/windowing); the pre-resize step this class ports (native x 4 supersample) cannot be bit-identical across them. - Python's round() is round-half-to-even; GDScript Image.set_pixel() on an RGBA8-format Image rounds half-up at the C++ level. Only reachable at exact .5 boundaries in 0..255 space, so it affects at most a handful of pixels' least-significant bit. Rule 8 is not implicated here: this class produces an Image the caller registers exactly like any other baked/composite page (Part 1's DamageCompositeCache) — it never touches the tilemap directly.

**Constants / tuning**
- `SUPERSAMPLE` = `4`
- `V_N` = `Vector2(16, 0)`
- `V_E` = `Vector2(32, 8)`
- `V_S` = `Vector2(16, 16)`
- `V_W` = `Vector2(0, 8)`
- `V_WB` = `Vector2(0, 28)`
- `V_SB` = `Vector2(16, 36)`
- `V_EB` = `Vector2(32, 28)`
- `LATERAL_NATIVE` = `Vector2i(16, 20)`
- `TOP_NATIVE` = `Vector2i(16, 16)`
- `FACE_TOP` = `{"origin": V_N, "u_end": V_E, "v_end": V_W, "native": TOP_NATIVE}`
- `FACE_SW` = `{"origin": V_W, "u_end": V_S, "v_end": V_WB, "native": LATERAL_NATIVE}`
- `FACE_SE` = `{"origin": V_S, "u_end": V_E, "v_end": V_SB, "native": LATERAL_NATIVE}`
- `FACE_SE_MIRRORED` = `{"origin": V_E, "u_end": V_S, "v_end": V_EB, "native": LATERAL_NATIVE}`

---

### `edge.gd`

`class_name Edge` · 195 lines

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
- `var material_bands: Dictionary = {}`
- `var glass_class: int = GlassMaterials.CLASS_UNSET`
- `var occupied_sides: int = OccupiedSides.BOTH`

**Public API**
- `func has_material_bands() -> bool:`
- `func material_at(rel_level: int) -> String:`
- `func set_occupied_gu(gu_cell: Vector2i) -> bool:`
- `func occupied_gu() -> Vector2i:`
- `func occupies_cell(gu_cell: Vector2i) -> bool:`
- `func occupies_a() -> bool:`
- `func occupies_b() -> bool:`
- `func is_half_thickness() -> bool:`
- `func key_string() -> String:`

---

### `edge_extractor.gd`

`class_name EdgeExtractor` · 246 lines

`godot/scripts/geometry/edge_extractor.gd`

> Geometry Module — Edge Extractor: converts compiled map to Edge objects Ported from legacy geometry system; refined by SLICE-02 refactor (docs/history/)

**Constants / tuning**
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `_EDGE_BY_SUFFIX` = `{ "NW": Face.NW,  ## (-1, 0) "NE": Face.NE,  ## (0, -1) "SE": Face.SE,  ## (+1, 0) "SW": Face.SW,  ## (0, +1) }`

---

### `edge_registry.gd`

`class_name EdgeRegistry` · 203 lines

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
- `func glass_edge_keys() -> Dictionary:`
- `func glass_stop_edge_keys() -> Dictionary:`
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

`class_name GeometryCoords` · 121 lines

`godot/scripts/geometry/geometry_coords.gd`

> Geometry Module — Coordinate constants and conversions Ported from legacy coordinate system; validated by SLICE-00 Transform Canon

**Constants / tuning**
- `VOXELS_PER_UNIT_AXIS` = `8`
- `VOXEL_TILE_SIZE` = `Vector2i(32, 16)`
- `VOXEL_STEP_PX` = `20.0`
- `VOXEL_STOREY_HEIGHT_PX` = `160.0`
- `LEVELS_PER_STOREY` = `8`
- `PLAYABLE_STOREY` = `10`
- `PLAYABLE_LEVEL` = `PLAYABLE_STOREY * LEVELS_PER_STOREY`
- `TEX_AUTHORING_N` = `16`
- `VOXEL_ATOM_W` = `32`
- `VOXEL_ATOM_H` = `36`
- `VOXEL_TILE_H` = `16`
- `FLOOR_TOP_LEVEL` = `PLAYABLE_LEVEL - 1`
- `FLOOR_DEEP_LEVEL` = `PLAYABLE_LEVEL - 2`

---

### `glass_pane_grouper.gd`

`class_name GlassPaneGrouper` · 232 lines

`godot/scripts/geometry/glass_pane_grouper.gd`

> Geometry Module — GlassPaneGrouper (GLASS_MASTER_PLAN §4, G2). Stamps `Slice.pane_id` on every glass slice in an EdgeRegistry so the cascade (G3) can take a whole continuous surface from one hit. Run once at map load, right after SliceGenerator.generate(), never per shot. Two producers, one consumer: · BLOCKS — "um bloco é um bloco" (G-D2). Every glass `solid_block_instance` footprint cell is merged into one set and FLOOD-FILLED into connected components (§4.2); each component is one pane. This is deliberately NOT per-authored-instance: PLAYGROUND spells a 3-wide glass block as three adjacent 1×1 declarations, and those are one block, not three. · PANELS — contiguous coplanar half-thickness faces. Union-find: two glass panel slices are the same pane when they share a face orientation AND their owning GUs are adjacent along that face's RUN axis (perpendicular to Face.delta). A lone panel is its own pane. Every glass slice leaves this pass with a non-empty `pane_id`.

**Constants / tuning**
- `MAX_PANE_RUN_GU` = `8`
- `MAX_PANE_STOREYS` = `4`

---

### `half_voxel_compositor.gd`

`class_name HalfVoxelCompositor` · extends `RefCounted` · 309 lines

`godot/scripts/geometry/half_voxel_compositor.gd`

> D33 Part 3b — HalfVoxelCompositor: the GDScript port of generate_voxel.py's generate_half_voxel() (LEFT/RIGHT wall variants only — "top"/floor and "bottom"/ceiling are a further increment, see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3b). This is a DIFFERENT primitive from DecalCompositor (Part 2): a decal is PROJECTED onto a face through a sheared parallelogram (inverse-mapped, resampled); a half-voxel's kept geometry is a straight, same-coordinate POLYGON MASK copy — Pillow's `Image.paste(source, (0,0), _polygon_mask(poly))`, which has no direct Godot Image equivalent. paste_masked() below is that primitive: point-in-polygon per destination pixel, no resampling, no shear. Proven equal to the real Python output (not assumed) by godot/scripts/tools/half_voxel_compositor_equality_selftest.gd against fixtures generated straight from generate_half_voxel() itself (tools/asset_generation/d33_part3b_fixture_gen.py).

**Constants / tuning**
- `DecalCompositorClass` = `preload("res://godot/scripts/geometry/decal_compositor.gd")`

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

`class_name JunctionResolver` · 196 lines

`godot/scripts/geometry/junction_resolver.gd`

> Geometry Module — Junction Resolver: fills V-junction corner columns. Rewritten (JUNCTION-02): the previous version reconstructed GU cells from voxel-index vertex coordinates and divided them back down by 8. That broke whenever a vertex used the "+7" near-edge offset (true for one axis of almost every vertex _get_edge_vertices produced) instead of a clean multiple of 8 — integer division silently floored into the wrong bucket, so the resolver picked a cell adjacent to the elbow instead of the true diagonal notch. This version never touches voxel coordinates for the detection step: it stays in GU-cell space the whole time, using the faces already recorded on each Edge. Scope: V-junctions (2 walls) and free-standing wall ends (3 walls, all genuinely open — e.g. a divider stopping next to a gate) both get filler columns, one per adjacent (non-opposite) pair of occupied faces at the cell. A true T-junction (a wall butting flush into another, already-solid wall) also presents as 3 faces on a naive count, but EdgeExtractor's exposure culling (see edge_extractor.gd) already removes the spurious flush-contact face before this ever sees it, so it correctly reduces to 2 opposite (straight-through) faces — 0 columns, nothing to fill. This only works because that culling fix landed first; see JUNCTION-01b prompt. X-junctions (4 walls) are intentionally skipped — assumed already covered by surrounding wall geometry; revisit only if a real gap is reported there.

---

### `passage_query.gd`

`class_name PassageQuery` · 296 lines

`godot/scripts/geometry/passage_query.gd`

> PassageQuery — MATERIALS_MASTER_PLAN M3-2. "Can the agent get through this wall, and how?" PURE. It reads `Voxel.damage_state` and writes nothing — no caches, no signals, no side effects — so a prediction can ask it about a hypothetical world exactly the way the committed one is asked (PREDICTION_MASTER_PLAN's split: `build_plan()` is pure, `delta.commit()` is the only writer). THE RULE, Director 2026-08-21: > *"uma parede comum é feita de um par de slices, uma em cada GU anexas. Para > o agente passar agachado (ou transpor uma janela), é necessário que as duas > estejam desobstruídas. Se tiver 4 slices destruídas (2 pares empilhados), o > agente consegue entrar em pé."* ⚠️ THE UNIT THAT STACKS IS THE **STOREY**, not the voxel level, and that correction is the whole of M3-0. The Director's "slice" is *one storey of wall on one GU face* — this file calls it a **storey-face**. The code's `Slice` class is the WHOLE face across every storey (128 voxels at storey_count 2), a different object with the same name. Confusing the two is what made three earlier readings of this rule wrong. Checked, not transcribed: the baked agent is 222 px against `WALL_FLOOR_STEP_PX` 158 — **1.41 storeys tall**. A one-storey opening is 0.71 of him (crouch); two storeys is 1.41x (standing). ⚠️ THIS ANSWERS GEOMETRY, NOT REACHABILITY. `passage_class()` says an opening of a given size exists somewhere in this wall; it does NOT say the agent can stand in front of it. A hole two storeys up is a window, and whether he can reach it is the movement system's question — which is why `clear_storeys()` is public and returns WHICH storeys are open, rather than this file quietly deciding that only an opening at storey 0 counts. The Director's own wording covers both cases in one sentence (*"passar agachado (ou transpor uma janela)"*), so the distinction is real and is not this query's to make.

---

### `slab.gd`

`class_name Slab` · 111 lines

`godot/scripts/geometry/slab.gd`

> Geometry Module — Slab: horizontal voxel container (floor, ceiling, interior) DESTRUCTION_MASTER_PLAN D1: the container sibling of Slice for the horizontal plane. A wall voxel belongs to a Slice which belongs to an Edge; a floor/ceiling voxel has no edge, so it gets this container instead — same dirty-count/TIC-skip contract as Slice, none of the edge-specific fields (face, edge_id). Floor, ceiling and interior cutaway are ONE class: a ceiling is a Slab at a different level/role, not a different type. See voxel.gd's Voxel._parent_container_id for why Voxel is shared unmodified between Slice and Slab, and why it points back by instance id rather than by reference. LEAK-CYCLE-01: a Slab owns its `voxels` strongly and they point back weakly, so dropping the Slab frees the whole cluster. Whoever builds a Slab must keep it alive for as long as its voxels are in use — SlabRegistry does that for every real Slab; a fixture that hands out voxels without their Slab has to anchor the Slab itself.

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

`class_name Slice` · 102 lines

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
- `var pane_id: String = ""`
- `var material_bands: Dictionary = {}`
- `var glass_class: int = GlassMaterials.CLASS_UNSET`

**Public API**
- `func has_material_bands() -> bool:`
- `func material_at(rel_level: int) -> String:`
- `func get_voxel(index: int) -> Voxel:`
- `func total_voxel_count() -> int:`
- `func mark_all_dirty() -> void:`
- `func increment_dirty() -> void:`
- `func decrement_dirty() -> void:`
- `func clear_all_dirty() -> void:`

---

### `slice_generator.gd`

`class_name SliceGenerator` · 108 lines

`godot/scripts/geometry/slice_generator.gd`

> Geometry Module — Slice Generator: creates Slices and Voxels from Edges Port from room.gd _place_wall_voxels() and _voxel_slice_positions() logic

---

### `voxel.gd`

`class_name Voxel` · 187 lines

`godot/scripts/geometry/voxel.gd`

> Geometry Module — Voxel: single 32×32 voxel in a wall slice Port from voxel_ref.gd with damage state tracking

---

### `voxel_renderer.gd`

`class_name VoxelRenderer` · extends `Node2D` · 6810 lines

`godot/scripts/geometry/voxel_renderer.gd`

> Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering Port from room.gd voxel functions, honoring Transform Canon Extends Node2D to add to scene tree

**Signals**
- `signal voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String)`

**Constants / tuning**
- `GlassShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `DecalCompositorClass` = `preload("res://godot/scripts/geometry/decal_compositor.gd")`
- `HalfVoxelCompositorClass` = `preload("res://godot/scripts/geometry/half_voxel_compositor.gd")`
- `VoxelVariantRegistryClass` = `preload("res://godot/scripts/systems/voxel_variant_registry.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `GlassOpening` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `VOXEL_SOURCE_ID` = `0`

**Public vars**
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`

---

## navigation/

### `guard_pathfinder.gd`

`class_name GuardPathfinder` · 80 lines

`godot/scripts/navigation/guard_pathfinder.gd`

---

### `movement_overlay.gd`

`class_name MovementOverlay` · extends `Node2D` · 272 lines

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
- `func set_blocked_edge_keys(keys: Dictionary) -> void:`
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

### `agent_probe_prop.gd`

`class_name AgentProbeProp` · extends `Sprite2D` · 320 lines

`godot/scripts/overlays/agent_probe_prop.gd`

> CHARACTER_MASTER_PLAN Part 2 — the agent, standing in the real room. WHAT THIS IS FOR, exactly: the Director asked whether the figure can be put in the scene yet to judge PROPORTIONS and LIGHTING. This is that probe and only that. It does not touch `agent.gd` — the playable agent is still its vector placeholder, and Part 2's definition of done (§10: the placeholder is GONE) is deliberately not claimed here. What this answers is whether the baked figure sits at the right size against real voxel geometry and takes the room's real light, which is the thing that has to be true before the swap is worth doing. A lean sibling of GrenadeProp: same four-frames-per-room-perspective contract, same `flat_normal_relight.gdshader`, same perspective-aware light mapping (ACTOR_MASTER_PLAN D22), same ground-contact anchoring. Three differences, all deliberate: 1. SPRITE_SCALE IS 1.0, AND THAT IS A DERIVATION RATHER THAN A SETTING. Every other prop in this project carries a hand-tuned sprite scale, which is right for a grenade and wrong here: the question being asked IS the figure's size, so a scale tuned until it looked right would answer itself. `agent_frame_bake_spike.gd` bakes at the game's own pixel scale and gates on it — a 0.20 m rise measured 20.000 px against VOXEL_STEP_PX's 20.0 — so one texel is already one world pixel and any scale but 1.0 would BREAK it. 2. THE ANCHOR IS READ FROM THE BAKE, NOT COPIED FROM IT. GrenadeProp hardcodes its `ANCHOR_PX` as a constant transcribed from the bake's printout. That is one number in two places, and it goes stale the first time the canvas size changes. The bake already writes `anchor.json`; this reads it. 3. NO GROUND SHADOW, ON PURPOSE. GrenadeProp fakes one by squashing the sprite's own silhouette on Y — a stated substitution that works because a grenade is a small round object. A 1.9 m standing figure squashed on Y is a long smear, not a footprint, and the bake's own header notes the honest version is a separate top-down pass (which `actor_frame_bake_spike.gd` does and this bake does not). Shipping a knowingly-wrong shadow into a probe about how the figure READS would corrupt the very judgement it exists for. The figure will look unmoored; that is the missing pass, not a placement bug.

**Constants / tuning**
- `FRAMES_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"`
- `FRAMES_DIR_DEV` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_dev/"`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`
- `DIRECTIONS` = `["N", "E", "S", "W"]`
- `YAW_BY_DIRECTION` = `{"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}`
- `SPRITE_SCALE` = `1.0`

---

### `aim_bubble_overlay.gd`

`class_name AimBubbleOverlay` · extends `Node2D` · 775 lines

`godot/scripts/overlays/aim_bubble_overlay.gd`

**Constants / tuning**
- `SEG_STRIDE` = `6`
- `SEG_AXIS_X` = `0`
- `SEG_POS` = `1`
- `SEG_SPAN_MIN` = `2`
- `SEG_SPAN_MAX` = `3`
- `SEG_Z_MIN` = `4`
- `SEG_Z_MAX` = `5`

**Public vars**
- `var dome_color: Color = Color(1.0, 0.66, 0.30, 1.0)`
- `var fill_alpha: float = 0.13`
- `var floor_fill_alpha: float = 0.20`
- `var floor_line_alpha: float = 0.55`
- `var rim_alpha: float = 0.90`
- `var line_width: float = 3.5`
- `var grid_alpha: float = 0.45`
- `var grid_line_width: float = 2.4`
- `var lat_ring_count: int = 5`
- `var long_meridian_count: int = 12`
- `var grid_meridian_steps: int = 16`
- `var grid_ring_steps: int = 48`
- `var wall_fill_alpha: float = 0.24`
- `var wall_line_alpha: float = 0.85`
- `var wall_grid_alpha: float = 0.60`
- `var wall_grid_step_gu: float = 0.25`
- `var wall_search_margin: float = 1.0`
- `var silhouette_angles: int = 180`
- `var silhouette_ellipse_steps: int = 720`
- `var silhouette_phi_steps: int = 6`
- `var floor_ring_steps: int = 720`
- `var patch_edge_sample_px: float = 4.0`
- `var edge_shadow_nudge_gu: float = 0.01`
- `var patch_arc_steps: int = 48`
- `var patch_visibility_samples: int = 12`

**Public API**
- `func show_dome(center: Vector2, radius_gu: float, center_gu: Vector2i, wall_height_edges: Dictionary) -> void:`
- `func update_position(center: Vector2, center_gu: Vector2i) -> void:`

---

### `blast_wireframe_overlay.gd`

`class_name BlastWireframeOverlay` · extends `Node2D` · 121 lines

`godot/scripts/overlays/blast_wireframe_overlay.gd`

**Constants / tuning**
- `LINE_COLOR` = `Color(1.0, 0.15, 0.15, 0.9)`
- `LINE_WIDTH` = `3.0`
- `PERIMETER_INSET_DISTANCE` = `6.0`

**Public vars**
- `var ring_fill_alphas: PackedFloat32Array = PackedFloat32Array([0.34, 0.22, 0.13])`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:`
- `func show_footprint(cells, ring_by_cell: Dictionary = {}) -> void:`
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

### `circle_field.gd`

`class_name CircleField` · extends `RefCounted` · 243 lines

`godot/scripts/overlays/circle_field.gd`

**Constants / tuning**
- `FLOATS_PER_INSTANCE` = `12`
- `FEATHER_SHADER_SRC` = `"shader_type canvas_item;\nrender_mode %s;\nuniform float feather : hint_range(0.0, 1.0) = 0.6;\nvarying vec4 inst_color;\nvoid vertex() {\n\tinst_color = COLOR;\n}\nvoid fragment() {\n\tfloat d = length(UV * 2.0 - 1.0);\n\tCOLOR = inst_color;\n\tCOLOR.a *= 1.0 - smoothstep(1.0 - feather, 1.0, d);\n}\n"`

**Public API**
- `func attach(parent: Node2D, blend: CanvasItemMaterial.BlendMode, behind: bool = false, feather: float = 0.0) -> void:`
- `func begin(capacity: int) -> void:`
- `func push(pos: Vector2, radius: float, color: Color) -> void:`
- `func flush() -> void:`
- `func clear() -> void:`

---

### `debris_overlay.gd`

`class_name DebrisOverlay` · extends `Node2D` · 268 lines

`godot/scripts/overlays/debris_overlay.gd`

**Public vars**
- `var dust_delay_min: float = 0.25`
- `var dust_delay_max: float = 0.45`
- `var dust_fall_duration_min: float = 0.45`
- `var dust_fall_duration_max: float = 0.75`
- `var dust_settle_duration_min: float = 0.7`
- `var dust_settle_duration_max: float = 1.2`
- `var dust_speck_count_min: int = 7`
- `var dust_speck_count_max: int = 12`
- `var dust_speck_spread: float = 9.0`
- `var dust_speck_radius: float = 2.6`
- `var dust_alpha_gain: float = 1.7`
- `var dust_fade_power: float = 1.3`
- `var chip_arc_duration_min: float = 0.4`
- `var chip_arc_duration_max: float = 0.6`
- `var chip_settle_duration_min: float = 0.8`
- `var chip_settle_duration_max: float = 1.3`
- `var chip_gravity: float = 420.0`
- `var chip_horizontal_jitter: float = 40.0`
- `var chip_half_w: float = 3.5`
- `var chip_half_h: float = 1.6`
- `var chip_size_jitter_min: float = 0.7`
- `var chip_size_jitter_max: float = 1.3`
- `var chip_rotation_speed_min: float = -10.0`
- `var chip_rotation_speed_max: float = 10.0`
- `var chip_fade_power: float = 1.3`

**Public API**
- `func add_dust(origin: Vector2, target: Vector2, color: Color) -> void:`
- `func add_chips(origin: Vector2, target: Vector2, count: int, color: Color) -> void:`
- `func clear() -> void:`

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

`class_name EmberOverlay` · extends `Node2D` · 398 lines

`godot/scripts/overlays/ember_overlay.gd`

---

### `explosion_flash_overlay.gd`

`class_name ExplosionFlashOverlay` · extends `Node2D` · 233 lines

`godot/scripts/overlays/explosion_flash_overlay.gd`

**Constants / tuning**
- `NEGATIVE_FLASH_SHADER` = `"""`

**Public vars**
- `var strobe_white_alpha: float = 1.0`
- `var strobe_negative_amount: float = 1.0`
- `var strobe_negative_desaturate: float = 1.0`
- `var flash_mode: int = FlashMode.NEGATIVE`

**Public API**
- `func set_negative_z_index(z: int) -> void:`
- `func hold_frame(mode: int) -> void:`
- `func clear() -> void:`

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

`class_name FloatingCollectible` · extends `Node2D` · 620 lines

`godot/scripts/overlays/floating_collectible.gd`

> ACTOR_MASTER_PLAN D21/D17/D14 — floating/rotating collectible, the reusable "simplification" display for any object (Part 6, still otherwise unspecified). First proven with the shotgun; STANDARDIZED (Director, 2026-07-28) to take its bake folder and visual scale per-instance via setup(), so every future collectible reuses this same class instead of a per-object copy. Cycles pre-rendered flat-color + normal-map frame pairs (produced by a bake tool following actor_frame_bake_spike.gd's template) through a per-pixel relighting shader (flat_normal_relight.gdshader) so the sprite shades directionally against the world's real light data — no voxel geometry, no live 3D scene at runtime, matching D16's "simplification" concept exactly. Floats with a vertical sine bob and spins continuously (Director, 2026-07-27). GROUND SHADOW (Director, 2026-07-28, re-tuned twice same day). Uses two dedicated frame_%02d_shadow_{sharp,soft}.png per frame instead of the oblique COLOR frame reused-and-squashed (that shears diagonal silhouettes and rotates their apparent angle) — a true top-down bake (actor_frame_bake_spike.gd), which has no directional foreshortening to shear when squashed. Pinned to floor height independent of the bob. Two Sprite2D layers crossfade by the object's CURRENT bob height (Director's corrected spec, replacing an earlier "wider at bottom" misread): near the floor (bottom of the bob) the shadow is small and SHARP at 80% opacity; at the top of the bob it's bigger and SOFT/diffuse at 50% opacity — real depth needs size AND focus to change together, not size alone. A fixed HOVER_HEIGHT_PX lift keeps a visible gap between object and shadow even at the bob's lowest point. Frame count and rotation speed come from CollectibleBakeConfig (godot/scripts/systems/collectible_bake_config.gd) — the bake tool that produced frames_dir MUST have used the exact same FRAME_COUNT/camera convention, or the frame index math and the light-direction math below both go wrong silently. Light-direction simplification, stated plainly rather than hidden: the game has no real 3D world space — gameplay is a 2D grid + an isometric screen projection. To relight a normal map baked from a fixed 3D camera, this maps grid-x -> bake-world-x and grid-y -> bake-world-z (an explicit, documented choice, not a derived one). PERSPECTIVE-AWARE FIX (Director, 2026-07-28, closes ACTOR_MASTER_PLAN open question #16 / D22): the grid delta between light and object is computed in the room's CURRENT view-space cells, then de-rotated back to base (North) orientation via PerspectiveMapper.cell_to_base() before the grid-x/grid-y -> world-x/world-z mapping is applied — the bake camera's fixed azimuth was always derived against a canonical N view, so feeding it a raw view-space delta from a rotated (E/S/W) perspective silently picked the wrong world direction. Same idea as TestZoneController.reposition_for_perspective(): this object also now tracks its own base_cell and re-derives its view-space gu_cell on every perspective flip (see reposition_for_perspective() below), so gu_cell never goes stale the way it used to before this fix. STATIC FACING MODE (Director, 2026-07-29 — "colocar 4 shotguns estáticas [...] apontando para [os blocos]"). The bake already contains every facing: actor_frame_bake_spike.gd renders FRAME_COUNT yaws of a full turn, so a prop that must POINT somewhere instead of spinning is the same flipbook frozen on the matching frame — no second bake, no second class. Pass a compass edge to setup()'s optional p_static_facing and the object stops spinning, stops bobbing, and holds the frame whose muzzle runs along that edge; everything else (relighting, ground shadow, depth-aware z) is shared with the spinning path byte-for-byte. See FACING_YAW_DEG for how those yaws were measured.

**Constants / tuning**
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`

---

### `glass_crack_sprite.gd`

`class_name GlassCrackSprite` · extends `Sprite2D` · 153 lines

`godot/scripts/overlays/glass_crack_sprite.gd`

> GlassCrackSprite — GLASS_MASTER_PLAN CRACK-02 / G-D27 (§13, stage S-1). ONE crack event = ONE of these. A Sprite2D carrying the fracture sheet, laid over the pane in the pane's OWN basis, drawing additively and touching nothing about the glass underneath. ⚠️ THE TRANSFORM IS THE WHOLE TRICK, so it is here and not scattered: CRACK-01-D measured the wall face's basis — a voxel sits at `impact + run · RUN_STEP + level · (0, −VOXEL_STEP)`, RUN_STEP = (16, 8) for a run along X and (−16, 8) along Y — and CRACK-01's shader had to INVERT it per fragment. Baking the FORWARD basis into `transform` instead makes the quad the pane's parallelogram, so the sheet is already anchored, already sheared correctly, and the shader has no inverse in it at all. What this buys over CRACK-01's renderer-side plane (G-D27, all four measurable): the glass behind is untouched by construction; a crack is a NODE with a position, so a perspective rebuild can recreate it (S-3); N impacts are N sprites that alpha-composite, so the 16-group cap, the per-cell group plane and the RGBAF strip are gone; and every glass fragment on the map loses a `texture()` + branch.

**Constants / tuning**
- `RUN_STEP_X` = `Vector2(16.0, 8.0)`
- `RUN_STEP_Y` = `Vector2(-16.0, 8.0)`
- `LEVEL_STEP` = `Vector2(0.0, -20.0)`
- `PANE_CLIP_SLACK` = `0.5`

**Public API**
- `func setup(sheet: Texture2D, span: Vector2, origin: Vector2, run_axis: int, pane_lo: Vector2, pane_hi: Vector2, shader: Shader) -> void:`
- `func set_opening(tex: Texture2D, origin: Vector2, size: Vector2) -> void:`
- `func set_hole_cut(v: float) -> void:`

---

### `glass_rain_overlay.gd`

`class_name GlassRainOverlay` · extends `Node2D` · 219 lines

`godot/scripts/overlays/glass_rain_overlay.gd`

**Constants / tuning**
- `ShardFieldClass` = `preload("res://godot/scripts/overlays/shard_field.gd")`
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`

**Public vars**
- `var fall_frames_min: int = 14`
- `var fall_frames_max: int = 26`
- `var stagger_frames: int = 10`
- `var bounce_frames: int = 7`
- `var bounce_scale: float = 0.16`
- `var hold_frames: int = 26`
- `var fade_frames: int = 18`
- `var arc_px_min: float = 6.0`
- `var arc_px_max: float = 22.0`
- `var spin_min: float = -0.16`
- `var spin_max: float = 0.16`
- `var tint: Color = Color(0.77, 0.91, 0.96, 0.95)`
- `var max_shards: int = 3000`

**Public API**
- `func spawn(flights: Array, pieces_per_voxel_max: int = 4) -> int:`
- `func live_count() -> int:`
- `func span_frames() -> int:`

---

### `grenade_prop.gd`

`class_name GrenadeProp` · extends `Sprite2D` · 373 lines

`godot/scripts/overlays/grenade_prop.gd`

> ACTOR_MASTER_PLAN objects track — grenade re-bake (2026-07-28). Replaces TestZoneController's old plain Sprite2D (a single frozen-angle bake, bake_voxel_sprite_3d.gd) with a relit prop driven by grenade_frame_bake_spike.gd's real per-direction 3D renders (one flat-color + one view-space-normal-map pair per N/E/S/W compass direction). Deliberately NOT a FloatingCollectible: this is a static ground prop, not a spinning pickup — no continuous rotation timer, no bob. The only thing that changes which of the 4 baked frames is shown is the room's active N/E/S/W perspective (the whole scene visually rotates on a perspective flip; this prop follows by swapping to the frame baked at the matching yaw, same PerspectiveMapper convention floating_collectible.gd's reposition_for_ perspective() uses). Per-pixel relighting (flat_normal_relight.gdshader) and its perspective-aware light-direction math are otherwise identical to FloatingCollectible's fixed version — see that file for the fuller rationale (ACTOR_MASTER_PLAN D22 / open question #16).

**Constants / tuning**
- `FRAMES_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/grenade_frames/"`
- `DIRECTIONS` = `["N", "E", "S", "W"]`
- `SHADER_PATH` = `"res://godot/shaders/flat_normal_relight.gdshader"`
- `SHADOW_SHADER_PATH` = `"res://godot/shaders/object_ground_shadow.gdshader"`
- `CollectibleBakeConfig` = `preload("res://godot/scripts/systems/collectible_bake_config.gd")`
- `ANCHOR_PX` = `Vector2(48.0, 73.15551)`
- `SPRITE_SCALE` = `0.75`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`
- `SHADOW_HEIGHT_REF_PX` = `90.0`
- `SHADOW_STRENGTH_AT_GROUND` = `0.55`
- `SHADOW_STRENGTH_IN_FLIGHT` = `0.35`
- `SHADOW_SCALE_AT_GROUND` = `0.80`
- `SHADOW_SCALE_IN_FLIGHT` = `1.05`
- `SHADOW_BLUR_MAX_PX` = `5.0`

**Public vars**
- `var room: Node = null`
- `var gu_cell: Vector2i = Vector2i.ZERO`
- `var base_cell: Vector2i = Vector2i.ZERO`

**Public API**
- `func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i) -> void:`
- `func set_flight_height_px(px: float) -> void:`
- `func update_cell(p_gu_cell: Vector2i) -> void:`
- `func set_airborne(airborne: bool) -> void:`

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

extends `Node2D` · 146 lines

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

extends `Node2D` · 160 lines

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

### `shard_field.gd`

`class_name ShardField` · extends `RefCounted` · 177 lines

`godot/scripts/overlays/shard_field.gd`

**Constants / tuning**
- `FLOATS_PER_INSTANCE` = `16`
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `FIELD_SHADER_PATH` = `"res://godot/shaders/glass_shard_field.gdshader"`

**Public API**
- `func attach(parent: Node2D, behind: bool = false) -> void:`
- `func begin(capacity: int) -> void:`
- `func push(pos: Vector2, size_px: float, rot: float, shape_index: int, color: Color, flip: bool = false, flop: bool = false) -> void:`
- `func flush() -> void:`
- `func live_count() -> int:`
- `func clear() -> void:`

---

### `shrapnel_overlay.gd`

`class_name ShrapnelOverlay` · extends `Node2D` · 185 lines

`godot/scripts/overlays/shrapnel_overlay.gd`

**Public vars**
- `var glow_radius: float = 16.0`
- `var min_lifetime: float = 0.45`
- `var max_lifetime: float = 0.85`
- `var max_velocity: float = 1600.0`
- `var frag_count: int = 12`
- `var frag_color: Color = Color(0.05, 0.05, 0.06, 1.0)`
- `var trail_length: float = 46.0`
- `var trail_segments: int = 4`
- `var trail_head_alpha: float = 0.34`
- `var trail_tail_alpha: float = 0.0`
- `var trail_width: float = 5.0`

**Public API**
- `func spawn_shrapnel(blast_center: Vector2, plan: Dictionary, voxel_renderer) -> void:`
- `func clear() -> void:`

---

### `shrapnel_preview_overlay.gd`

`class_name ShrapnelPreviewOverlay` · extends `Node2D` · 233 lines

`godot/scripts/overlays/shrapnel_preview_overlay.gd`

**Constants / tuning**
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`

**Public vars**
- `var ray_color: Color = Color(1.0, 0.42, 0.14, 1.0)`
- `var line_width: float = 2.0`
- `var ring_alpha: PackedFloat32Array = PackedFloat32Array([0.0, 0.70, 0.45, 0.25])`
- `var ray_origin_lift_gu: float = 0.18`
- `var length_scale: float = 1.35`
- `var circularity: float = 1.0`
- `var lateral_scale: float = 1.3`
- `var ground_brake: float = 0.42`
- `var rays_per_cell: int = 3`
- `var spread_rad: float = 0.26`

**Public API**
- `func setup(floor_layer: TileMapLayer, visual_offset: Vector2) -> void:`
- `func show_rays(source_gu: Vector2i, gu_rings: Dictionary) -> void:`
- `func clear() -> void:`

---

### `smoke_spark_overlay.gd`

`class_name SmokeSparkOverlay` · extends `Node2D` · 340 lines

`godot/scripts/overlays/smoke_spark_overlay.gd`

---

### `target_cursor_overlay.gd`

`class_name TargetCursorOverlay` · extends `Node2D` · 79 lines

`godot/scripts/overlays/target_cursor_overlay.gd`

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/virtual_grenade.gdshader"`

**Public vars**
- `var mark_color: Color = Color(1.0, 0.0, 0.0, 1.0)`
- `var overlay_strength: float = 0.5`
- `var outline_px: float = 2.0`
- `var hatch_px: float = 2.0`
- `var hatch_spacing_px: float = 12.0`

**Public API**
- `func show_at(center: Vector2, direction: String) -> void:`
- `func clear() -> void:`

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

### `throw_arc_overlay.gd`

`class_name ThrowArcOverlay` · extends `Node2D` · 189 lines

`godot/scripts/overlays/throw_arc_overlay.gd`

**Public vars**
- `var arc_color: Color = Color(1.0, 0.8, 0.3, 0.7)`
- `var line_width: float = 2.0`
- `var arc_segments: int = 24`
- `var arc_height_ratio: float = 0.35`
- `var bounce_height_ratio: float = 0.12`
- `var bounce_duration_s: float = 0.18`
- `var flight_turns: float = 1.0`

---

### `throw_perimeter_overlay.gd`

`class_name ThrowPerimeterOverlay` · extends `Node2D` · 53 lines

`godot/scripts/overlays/throw_perimeter_overlay.gd`

**Public vars**
- `var perimeter_color: Color = Color(1.0, 0.3, 0.3, 1.0)`
- `var line_alpha: float = 0.75`
- `var line_width: float = 2.0`
- `var arc_segments: int = 64`

**Public API**
- `func show_perimeter(center: Vector2, radius_gu: float) -> void:`
- `func clear() -> void:`

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

### `tracer_overlay.gd`

`class_name TracerOverlay` · extends `Node2D` · 148 lines

`godot/scripts/overlays/tracer_overlay.gd`

**Constants / tuning**
- `CORE_COLOR` = `Color(1.0, 0.93, 0.72, 0.95)`
- `TAIL_COLOR` = `Color(1.0, 0.62, 0.22, 0.55)`
- `CORE_WIDTH_PX` = `2.0`
- `TAIL_WIDTH_PX` = `4.0`

---

### `trail_overlay.gd`

extends `Node2D` · 43 lines

`godot/scripts/overlays/trail_overlay.gd`

**Public API**
- `func setup(room_ref: Node2D, floor_layer: TileMapLayer, visual_offset: Vector2) -> void:`

---

## systems/

### `bake_compositor.gd`

`class_name BakeCompositor` · 1261 lines

`godot/scripts/systems/bake_compositor.gd`

> BakeCompositor — Continuous-plane facade baking (OVERLORD-FIX-01) Model (replaces every previous half-face/strip scheme): A wall run is ONE continuous inclined plane on screen. Each atom carries a 32-texel-wide window of that plane, anchored at u = col*16 — consecutive atoms' windows OVERLAP by 16 texels on purpose: the occluded halves carry the same plane content as the neighbor that covers them, so every visible mix of atom fragments (sawtooth overlaps included) is seamless by construction. Runs exist in two screen directions, so atoms are baked per direction (dir 0: plane descends screen-right; dir 1: mirrored, descends screen-left) and direction is part of the lookup key. Per atom (col, row, dir), side-face content at atom pixel (x, y): dir 0:  u = col*16 + x          y_top(x) = 8 + x/2 dir 1:  u = col*16 + (31 - x)   y_top(x) = 8 + (31 - x)/2 v = (31 - row)*16 + (y - y_top(x)) * 16/20      (row 31 = top storey) Equivalently (what the code does): pre-scale the facade ×20/16 vertically, shear it ±x/2 once per direction ("plane image" P), and every atom is an axis-aligned 32×28 crop of P at (x0, (31-row)*20 + col*8 + V_MARGIN), pasted at atom-local (0, 8) — the x-terms cancel exactly, so composition is pure blit_rect with no per-pixel sampling. RGB in pages is pure facade luminance (grayscale); blend modes are applied at registration time via per-tile modulate (TEXTURE_ONLY = white, MULTIPLY = material base color). Top faces are baked as material color. Alpha = canonical voxel silhouette via blit_rect_mask + an exact byte-level fixup of the antialiased (partial-alpha) pixels (B3: alpha verbatim).

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `BakeConfigClass` = `preload("res://godot/scripts/systems/bake_config.gd")`
- `GlassMaterialsClass` = `preload("res://godot/scripts/systems/glass_materials.gd")`
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

---

### `bake_config.gd`

`class_name BakeConfig` · 69 lines

`godot/scripts/systems/bake_config.gd`

> BakeConfig — Unified bake system configuration Master kill-switch and feature toggles for the baking pipeline. Branch-exclusive (structural, not tested); values set at boot.

---

### `bake_policy.gd`

`class_name BakePolicy` · 153 lines

`godot/scripts/systems/bake_policy.gd`

> BakePolicy — Shared deterministic rules for texture baking Ensures the bake pass and lookup pass use identical: - Texture assignment (material ID + surface class → texture ID) - Variant seeding (edge + material → [0, 4) variant) D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): texture identity is a (material, surface_class) pair, mechanically derived — no per-material dict to keep in sync, matching MAPFILE_REFERENCE.md's existing M6 prefix canon (`facade_<material>`). SLICE (walls/roofs, reprojected from the same source) always resolves to `facade_<id>`. A missing asset (e.g. a material with no wall facade) is handled the same way it always was: TextureResolver.resolve() falls back to Tier.NONE and every caller already treats that as "fall back to the generic atlas". D34/E-SEAM-01 (Director, 2026-08-08) — **amends D20's SLAB half.** D20 sent EVERY floor zone down the `slab_<id>` photographic path, which is what made a concrete floor unable to read as the same material as a concrete wall (they were literally different art: `facade_concrete` grayscale+tinted vs `slab_concrete`, an unrelated ground photo at WHITE). The Director's model instead: **a floor is a roof at the base of the scene** — same bake, same grayscale source, same multiply tint, so wall/roof/floor of one material all read as that material. Which family a SLAB request resolves to is therefore derived from the MATERIAL, not from the surface alone: has_facade == true  -> `facade_<id>`, the SLICE family (concrete, metal, stone, wood today) has_facade == false -> `slab_<id>`, the photographic exception, kept on purpose for organic/wild ground (grass, dirt, sand, gravel) where hue IS the material identity and a grayscale source cannot carry it `has_facade` is consulted for SLAB only; SLICE resolves to `facade_<id>` regardless. This also retires the never-read `MaterialDef.slab_full_color` flag — the same split is derivable from `has_facade`, so there is no second field to keep in sync with it (E-SEAM-03).

**Constants / tuning**
- `CANONICAL_ATOM_ALIASES` = `{ "earth": "earth_0", "brick": "concrete", "cardboard": "concrete", "fabric": "concrete", "plywood": "concrete", }`

---

### `baked_tile_lookup.gd`

`class_name BakedTileLookup` · 484 lines

`godot/scripts/systems/baked_tile_lookup.gd`

> BakedTileLookup — Single lookup seam for placement path Insertion point between placement code and tile source selection. Query for a voxel face → either baked atlas or generic material atlas. OVERLORD-FIX-01: addresses per-direction continuous-plane sheets via (material, facade, column_in_run, level, dir) keys, with mirrored-repeat wrapping. Fallback chain: baked → generic material atlas.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`

**Public API**
- `func set_test_config(config) -> void:`
- `func set_material_registry(registry) -> void:`
- `func set_baked_atlas(atlas) -> void:`
- `func set_source_ids(source_ids: Dictionary) -> void:`
- `func register_runs(runs: Array) -> void:`
- `func resolve(edge, face: int, voxel_xy: Vector2i, level: int = 0, column_in_run: int = -1, material_override: String = "") -> TileLookupResult:`

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

### `damage_variant_baker.gd`

`class_name DamageVariantBaker` · extends `RefCounted` · 353 lines

`godot/scripts/systems/damage_variant_baker.gd`

> DamageVariantBaker — EXPLOSION_REBUILD_MASTER_PLAN Task 1b (E-BAKE, 2026-08-06) Pre-bakes CRACKED/DENTED/MARKED damage-decal ATOMS once per map load — replaces D-ARCH-01's per-CELL bake (which this class used to be: bake_wall_voxel()/bake_ceiling_voxel()/bake_zoned_floor_voxel(), called once per placed Voxel, 71,296 cells × N variants — infeasible, see EXPLOSION_REBUILD_MASTER_PLAN §0). The new model's whole premise: a damaged voxel no longer shows ITS OWN facade under the decal, it shows a randomly chosen crop of that material's facade — so the bake surface collapses from cells × variants to materials × damage-type × decal × substrate, ~207-279 atoms for the WHOLE MAP, not per cell. Drives the SAME compositor functions the D33 live-compositing path uses (VoxelRenderer._composite_full_voxel_decal() etc.) — same pixels, computed once here instead of lazily at hit time — via a synthetic, edge-free substrate crop (VoxelRenderer._composite_full_voxel_decal()'s own doc comment explains why `edge == null` triggers resolve_flat() there instead of the edge-based resolve()). Results register into a VoxelVariantRegistry keyed by (element_class, material, damage_material_name, substrate_variant) — no cell dimension — that VoxelRenderer.apply_damage_voxel_swap() consults before falling back to D33 runtime compositing. Scope is derived from what VoxelRenderer._set_voxel_cell()'s own dispatch actually reaches, same as the retired per-cell version: - WALL (element_class "WALL", any `has_facade` material): DENTED blast+bullet(mark) (2 sides × 3 decal variants each) + CRACKED bullet(mark) (2 sides × 3 variants) + CRACKED blast (3 variants, only materials with crack_factor > 0 — D10's derived rule, not the hardcoded IMPACT_CRACK_MATERIALS list this file used to lean on). D12 (2026-08-06): bullet marks bake BOTH shapes (cracked full-voxel AND dented half-voxel) — confirmed with the Director, since ShotPunchTable.damage_state_for() genuinely produces either outcome and the whole point of D12 was moving bullets fully off live compositing. - CEILING (element_class "CEILING", any `has_facade` material): DENTED blast-bottom, a silhouette carve with **1 shape** today (not D7's eventual 3 irregular cut shapes — HalfVoxelCompositor. carve_ceiling_silhouette() takes no shape parameter yet; that art/code doesn't exist, so this bakes what's real rather than pretending 3 variants exist). D6: CRACKED is universal — the SAME wall CRACKED-blast atom (already a 3-face composite, D6's "bakes onto all three visible faces at once") is additionally registered under "CEILING" with no re-compositing. - FLOOR (element_class "FLOOR", only materials actually used as a real floor zone — D9): DENTED blast-top, 3 variants. The registry NAME is always the shared "earth_blast_dented_top_N" pseudo-name (floor_damage_material()'s own rule, unchanged) but the ATOM's substrate is the GU's REAL ground material (D9) — so the registry key's material component must be the real material, not the naming constant, or every real floor material would collide into one slot. FLOOR CRACKED is not composited here: §3.2's roster makes CRACKED universal (floor + wall + ceiling, D6) and the wall's CRACKED-blast atom IS that atom, so a floor material with crack_factor > 0 gets it registered a second time under "FLOOR" from the same composite — see _bake_wall_and_marked()'s `is_floor_material`. Both halves of the old reason this was skipped are gone: D34/E-SEAM-02 made floor_damage_material() material-real (a concrete floor asks for "concrete_blast_cracked_all_N", not the "earth" sentinel), and E-CRACK-01 gave apply_crater_damage() a real crack tier, so a floor voxel can reach CRACKED at all. - INTERIOR slabs and plain (unzoned) earth floors: skipped entirely, same reasoning as the retired version — neither ever reaches the baked D33 path, so there is nothing expensive to pre-bake for them. Soot is never part of this: it is a per-cell modulate-alpha code (VoxelLightField.encode_face_soot()) applied by the light-repaint pass after any set_cell(), independent of which tile a cell shows.

**Constants / tuning**
- `SUBSTRATE_POSITIONS` = `[Vector2i(0, 0), Vector2i(20, 0), Vector2i(40, 0)]`
- `BAKE_LEVEL` = `0`
- `FLOOR_SHADE_BRIGHTNESS` = `0.72`
- `DAMAGE_CACHE_PATH` = `"user://damage_atom_cache/"`

**Public API**
- `func bake_all(declared_materials: Array[String], floor_materials: Array[String] = []) -> int:`

---

### `blast_calculator.gd`

`class_name BlastCalculator` · 1947 lines

`godot/scripts/systems/destruction/blast_calculator.gd`

> BlastCalculator — DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Pure/static: everything it needs is passed in (no registry ownership, same statelessness as EarthVariantSelector) so it stays testable in isolation against synthetic fixtures, matching every other Part's selftest convention. Three-stage pipeline for one detonation: 1. flood_gu_rings() — wall-aware BFS from the source GU, one ring per GU step, capped at the bomb's range. Director (this session): walls block/reduce propagation — reuses the same blocked-edge gate movement_overlay.gd already uses for movement, not a naive radius. 2. find_affected_containers() — every wall Slice and roof Slab (Role. CEILING) touching a flooded GU, ring-tagged. The GU flood step IS the "walk sideways along the wall" step (a wall's own footprint GU sits in the flood like any other GU), so no separate wall-run adjacency walk is needed here. 3. apply_container_damage() — combines a container's ring multiplier with MaterialResistanceTable to get a destroy/crack voxel COUNT, then picks WHICH voxels deterministically (FNV-1a hash-and-rank, mirroring EarthVariantSelector — no RNG, same inputs always produce the same result).

**Constants / tuning**
- `GRENADE_LEVEL` = `0`
- `NO_EPICENTER_BIAS` = `Vector2i(-999999, -999999)`
- `FACE_SOOT_CLEAN` = `4`

---

### `bomb_def.gd`

`class_name BombDef` · 83 lines

`godot/scripts/systems/destruction/bomb_def.gd`

> BombDef — bomb/grenade definition resource. DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Mirrors PropDef's shape exactly (plain object + from_json() factory, not a Godot Resource) so multiple bomb types can be authored as data instead of hardcoded per detonation — "outras bombas terão um alcance maior ou menor, de acordo com o tipo, tamanho e habilidades de cada personagem" (Director, this session).

**Public vars**
- `var id: String`
- `var ring_multipliers: Array[float] = []`
- `var destroy_ring_weights: Array[float] = []`
- `var dent_ring_weights: Array[float] = []`
- `var crack_ring_weights: Array[float] = []`
- `var soot_ring_tones: Array[int] = []`
- `var smoke_ring_weights: Array[float] = []`
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

### `detonation_entry_writer.gd`

`class_name DetonationEntryWriter` · extends `RefCounted` · 264 lines

`godot/scripts/systems/destruction/detonation_entry_writer.gd`

> DetonationEntryWriter — ONE plan entry's real work, and the only place in the whole pipeline that calls `layer.set_cell()`/`erase_cell()` or hands a puff to an overlay. Extracted from `DetonationChoreographer._apply_entry()` on 2026-08-28 for D-3 (`DETONATION_PRESENTATION_MASTER_PLAN` §3), unchanged in behaviour. It exists because the reform replaces the choreographer's PACING, not its writing: §3's table says the cell writes "survive as one loop inside the commit" and the VFX dispatch "survives and MOVES". Two paths now need this code and they have to run from one binary (D-3's gate), so copying it would have created exactly the second place for them to drift — and D-6 would then have to reconcile two versions instead of deleting one file. ⚠️ **KIND IS THE ONLY THING THAT DECIDES WHAT HAPPENS HERE — there is no ordering, no pacing and no frame in this class.** That is what makes it shared: everything the reform is removing lives in the caller. The two families are worth naming because the reform separates them: - **cells** (`destroy`, `expose`, `dented`, `cracked`, `soot`) — mutate the board, and after D-3 they all land in ONE frame; - **VFX** (`smoke`, `ember`, `debris`) — write nothing, and are what the consequence channel animates afterwards. `is_cell_kind()` is that split, in code, so a caller cannot get it wrong by listing kinds by hand.

**Constants / tuning**
- `SMOKE_COLOR` = `Color(0.62, 0.60, 0.57, 0.2)`
- `DEBRIS_FALLBACK_COLOR` = `Color(0.6, 0.6, 0.6)`
- `SURFACE_SPARK_SPEED_SCALE` = `1.3`
- `SURFACE_SPARK_DURATION_SCALE` = `0.6`
- `CELL_KINDS` = `["destroy", "expose", "dented", "cracked", "soot"]`

**Public vars**
- `var ember_overlay: EmberOverlay = null`
- `var debris_overlay: DebrisOverlay = null`
- `var debris_colors: Dictionary = {}`
- `var smoke_tints: Dictionary = {}`
- `var soot_clean: bool = false`
- `var soot_ramp_cells: Dictionary = {}`

**Public API**
- `func apply(kind: String, entry: Dictionary, voxel_renderer, smoke_overlay) -> int:`

---

### `detonation_plan_builder.gd`

`class_name DetonationPlanBuilder` · 2320 lines

`godot/scripts/systems/destruction/detonation_plan_builder.gd`

> DetonationPlanBuilder — EXPLOSION_REBUILD_MASTER_PLAN Task 4 (E-PLAN). Builds one `WorldDelta` for a single grenade detonation: all resolution, all exposure fallback, and the single map-wide light-field query, folded into one object a later choreography driver (Task 5/E-WAVE) can play back from `delta.waves` as a pure sequence of `set_cell()`/`erase_cell()` calls with zero further compositing/lookup — the performance idea §2 states once: "no compositing, no lookup, no light rebuild, no allocation happens inside a wave." **P-DELTA (PREDICTION_MASTER_PLAN Task 3, 2026-08-09): this class is now PURE.** It changes nothing — not a tile, not a Voxel — and returns a description of what a detonation WOULD do. `delta.commit()` is what makes it happen, and the caller owns that decision. Everything this pass used to read off freshly-mutated Voxels it now reads through `WorldDelta`'s projection. What this class does NOT do, on purpose: - It never calls `layer.set_cell()`/`erase_cell()` — every VoxelRenderer call it makes runs in resolve-only mode (`apply=false`, Task 4's own seam added to `_set_voxel_cell()`/`render_slab()`/ `render_fixed_earth_level()`/`resolve_damage_voxel_swap()`). A voxel's on-screen TILE is only ever resolved, never painted, until a wave chooses to apply the plan entry produced here. - It never writes DAMAGE STATE either, since P-DELTA. `BlastCalculator`'s `commit_damage()` remains the single writer (DESTRUCTION_MASTER_PLAN §3); this pass only ever calls its `simulate_*` half. - It never CALLS `room.record_voxel_damage_to_base()`/increments `_gu_blast_count`/appends a stamped-blast replay list — that is Task 5's job, the same split Task 2/3 already established for their own new parameters. It DOES return the raw material for the first of those (`delta.touched_voxels`, `Array[Voxel]` — every voxel this blast's containers would change the damage_state of, DESTROYED or DENTED/ CRACKED), so Task 5's caller can persist without a second flood/ find_affected_containers pass to re-derive the same set. That list is only meaningful AFTER `commit()`, which is when its caller reads it. - It never schedules or times anything — the plan is a static census of what EVERY wave should eventually paint; Task 5 owns turning that into a 40 ms-cadenced sequence. `ctx` is a plain Dictionary rather than a typed context object, matching the project's existing MinimalRoom precedent (damage_atom_bake_selftest.gd) for running real BlastCalculator machinery against either a full `room.gd` or a trimmed selftest scaffold without either needing to know about the other: "edge_registry": EdgeRegistry        (required) "slab_registry": SlabRegistry        (required) "voxel_renderer": VoxelRenderer      (required) "blocked_edges": Dictionary          (optional, default {}) "blocked_cells": Dictionary          (optional, default {}) "lights": Array                      (optional, default [] — real light sources, e.g. RoomBuilder.get_ light_sources()) "shadow_results": Array              (optional, default []) "under_structure": Dictionary        (optional, default {} — VL-D3 "never saw the sun" darkening; derived from the CURRENT geometry if omitted, see _columns_with_structure()) "deep_layer_unlocked": bool          (optional, default false — D2; no live caller drives true yet)

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `WorldDeltaClass` = `preload("res://godot/scripts/systems/prediction/world_delta.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `VoxelLightFieldClass` = `preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `CRATER_MAX_FACTOR` = `0.40`
- `CRATER_CORE_FACTOR` = `0.30`
- `SMOKE_BLOBS_PER_VOXEL` = `1`
- `PHASE_SETUP` = `0`
- `PHASE_SLICES` = `1`

---

### `detonation_presenter.gd`

`class_name DetonationPresenter` · extends `RefCounted` · 373 lines

`godot/scripts/systems/destruction/detonation_presenter.gd`

> DetonationPresenter — D-3 of `DETONATION_PRESENTATION_MASTER_PLAN`. **The world changes once, and the EFFECTS are what is animated.** That is the whole inversion (§4). `DetonationChoreographer` animates the WORLD — it spreads 20 ms of cell writes across 24 frames and decorates them — and this replaces it with one frame that writes everything and then N frames that write nothing. Behind `INFILTRAITOR_PRESENTER=1`; the choreographer stays the default until D-6 removes it. Both run from one binary, so a before/after needs no stash. ## What it does NOT contain, which is the point No `flatten_plan()`, no `_sort_key()`, no `KIND_RADIUS_BIAS`, no `front_radius_for()`, no `front_frames`, no `_fade_in_soot()`. Every one of those exists to decide WHEN a cell is written, and there is only one frame that writes cells. §3.1: the ordering problem does not get solved here, it stops existing — `KIND_RADIUS_BIAS` had been re-derived three times. ## The three beats 1. **THE COMMIT — one frame.** Every `destroy`, `expose`, `dented`, `cracked` and `soot` entry, then one flush. From here the board is FINAL. 2. **The consequence channel — N frames, zero cell writes.** `smoke`, `ember` and `debris`, each released at its own time. 3. **The light**, unchanged and still last (§7, the Director's standing ruling: scorch is what the light is about to reveal). ⚠️ **THE SCORCH IS IN THE COMMIT, AND THAT IS WHY `soot_clean` IS FALSE HERE.** §13.4 made the wave write clean geometry because its scorch arrived later in a ramp, and a hole that opened already-scorched then had to be wiped and refilled. With one commit frame there is no later — §7.1 — so the cell writes carry their own soot and `_fade_in_soot()` has nothing left to do. Setting this true would produce a permanently clean crater with no error anywhere.

**Signals**
- `signal finished()`

**Constants / tuning**
- `PLAYED_KINDS` = `[ "destroy", "dented", "cracked", "soot", "smoke", "ember", "debris", ]`

**Public vars**
- `var consequence_room = null`
- `var consequence_delta = null`
- `var ring_step_s: float = 0.055`
- `var storey_bias_s: float = 0.020`
- `var jitter_s: float = 0.060`
- `var consequence_max_seconds: float = 0.75`
- `var light_smoke_slack: int = 4`
- `var light_smoke_max_s: float = 3.5`
- `var soot_fade_frames: int = 5`

**Public API**
- `func set_vfx_targets(ember_overlay: EmberOverlay, smoke_tints: Dictionary = {}, debris_overlay: DebrisOverlay = null, debris_colors: Dictionary = {}) -> void:`
- `func start(plan: Dictionary, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:`

---

### `glass_crack.gd`

`class_name GlassCrack` · 517 lines

`godot/scripts/systems/destruction/glass_crack.gd`

> GlassCrack — GLASS_MASTER_PLAN CRACK-02 (§13, G-D14 / G-D24 / G-D26 / G-D27). A round that lands on a pane and does NOT breach the voxel (a weak hit, or a rifle round whose shatter roll was lost) leaves the pane STANDING and crazes the glass around the hole. That is this file: given the pane, the hit and the weapon's hole width, it returns the still-standing glass cells to mark CRACKED and everything the crack SPRITE needs to be placed. PURE by construction — it takes slice lists, never the registry — so the shot path applies the result the way `agent_shot_controller` applies `GlassShatter.plan_pane_shatter()`, and the selftest hands it a synthetic frame (PREDICTION_MASTER_PLAN's rule for `build_plan()`). ⚠️ STATE AND RENDER ARE DECOUPLED HERE, AND THAT IS THE POINT OF CRACK-02. `plan_pane_crack()` decides which voxels enter the CRACKED STATE — a gameplay fact, saved by VL-PERSIST, unrelated to pixels. The RENDER is a `GlassCrackSprite` laid over the pane in the pane's own basis (G-D27), whose reach is `SHEET_SPAN_*` and has nothing to do with the state radius. CRACK-01 conflated the two through a per-cell group plane; that plane is deleted. G-D24 — a cell already covered by a DIFFERENT crack, reached by this fracture, is not crazed: it is DESTROYED (crossed cracks drop the piece) and falls through `GlassFall` like any other break. With no per-cell plane the test is geometric, against the renderer's crack registry (`glass_crack_covering`).

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `FacadeSampler` = `preload("res://godot/scripts/systems/facade_sampler.gd")`

---

### `glass_fall.gd`

`class_name GlassFall` · 254 lines

`godot/scripts/systems/destruction/glass_fall.gd`

> GLASS G-D16a — WHERE A SHARD LANDS. GLASS_MASTER_PLAN §5.4 / §18.5. G-D13b answers "does this shard survive where it is"; this answers the other half, "where does the glass that fell end up", and it is deliberately ONE rule rather than one feature per surface: A destroyed glass voxel SCATTERS a few cells from its own column and then falls until it meets the first horizontal surface, and lands there. Base pile, counter top, windowsill, and a skylight dropping a whole storey are then the same code with different geometry underneath — no per-case branch. ── G4-4 / G-D41 + G-D42 — THE SCATTER ────────────────────────────────────── (Director, 2026-09-05: *"A maior parte dos elementos fica na primeira sub-GU mais próxima […] Alguns cacos conseguem vencer até 3 sub-GUs de distância […] uma força vetor que desloca todo o conjunto de cacos mais pra longe, baseado na força e na distância da granada."*) A pane is a vertical sheet, so its voxels project onto a LINE of grid cells — and until G4-4 that line was the whole pile. The scatter spreads it into a band: most shards on the pane's own column, fewer one cell out, a tail reaching `SCATTER_MAX_CELLS` (G-D41's "3 sub-GUs"). A sub-GU is one voxel cell (G-D41), so every distance here is in cells, not GUs. The symmetric draw covers "perpendicular to the pane BOTH ways and along the run" by construction — for any pane orientation one grid axis is the run and the other is perpendicular, and an isotropic symmetric offset spreads both the same. So this file never needs the pane's face; it only needs a DIRECTION for the shockwave, and the caller hands that in `impulse`. `impulse` — `{dir: Vector2, strength: float, lift: float}` in GRID space, from the bomb's own `ring_multipliers` falloff (G-D42 — no second force model). At zero impulse the scatter is symmetric; a near grenade shifts the band's mean downrange and, per-shard-scaled, spreads it wider ("caírem mais longe, mais espalhados"). `lift` is the skylight term and is UNEXERCISED by any real map — G-D16c/d is unbuilt, CEILING glass renders opaque and has no `pane_id`, so no skylight can shatter yet. It is authored with a synthetic test rather than quietly, so it does not become a fourth built-but-never-triggered feature. ⚠️ THE SCATTER OFFSET IS HASHED IN GRID SPACE, NOT BASE SPACE, and that is correct here rather than a shortcut. The result becomes STATE at `commit()` — the G6 pile is recorded in base coords and never recomputed, only re-laid (`Room._respawn_base_shards()`) — exactly as the un-scattered landing already was. The hash only has to be stable across the many `build_plan()` calls of one event, and the cursor is on one target throughout, so the grid key is. PURE, and that is not decoration. It takes a surface INDEX, never the SlabRegistry, so the selftest can hand it a synthetic counter and prove the rule without building a map — the same contract PREDICTION_MASTER_PLAN holds `build_plan()` to, and the same one `GlassShatter.collect_anchor_positions()` already follows. ⚠️ This module decides WHERE, never WHETHER anything is drawn. G6 (`Room.record_glass_shards()`) turns a landing into a floor pile decal and G6b-2 (`Room.spawn_glass_rain()`) into the falling shards; both are BUILT and consume this file's output. This module stays pure and knows about neither.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `NO_LANDING` = `-1`
- `SCATTER_MAX_CELLS` = `3`

---

### `glass_opening.gd`

`class_name GlassOpening` · 396 lines

`godot/scripts/systems/destruction/glass_opening.gd`

> GLASS CRACK-04 / G-D34 — THE FAMILY OF OPENINGS. (Director, 2026-09-04: *"Vamos usar formatos simples internos conhecidos, como os 4 sugeridos anteriormente, e outros para os buracos maiores. Criamos uma família de aberturas para serem escolhidas. Os decals se adaptam a esses formatos internos, podendo variar completamente do buraco para fora. Dessa forma já sabemos como construir o buraco sempre, independente de como vai ser o decal."*) ── WHAT AN OPENING IS ────────────────────────────────────────────────────── A closed polygon in the PANE's own (run, level) space, in VOXEL units, centred on the struck cell's CENTRE. Its interior is the hole. That single shape is the whole contract: * a glass cell entirely inside it is ERASED; * a cell the boundary CROSSES keeps only the glass outside the polygon — the intrusion into that cell's border the Director asked for; * a cell entirely outside is untouched; * and the crack sheet's inner void is this same polygon, so the hole's total shape and the decal's internal shape are equal by construction. ⚠️ THE OPENING IS THE AUTHORITY, NOT THE ART — AND THAT IS THE POINT OF THE FAMILY. The previous ruling (*"o decal é o dono da forma"*) was refined the same day for a concrete reason: if the shape lived in the sheet's pixels, the voxel side would have to RECOVER it (flood-fill the central black region, which is exactly what I was measuring when the Director stopped me), and the hole could not be built at all until that class's art existed. Measured on the two sheets that do exist: `fracture_glass_tight`'s void is **0.29 voxels** across and `fracture_glass_wide`'s is **2.02** — both well-defined, and both irrelevant, because a known family means *"já sabemos como construir o buraco sempre, independente de como vai ser o decal"*. The decal adapts to the opening; beyond the opening it is free to be anything. ⚠️ CHOSEN BY HASH, NEVER BY `randf()` — B4's rule, and G-D32's for the same reason one level up. The opening is re-picked whenever the geometry is rebuilt (a perspective flip, a load), so an RNG would reshape a standing hole every time the camera turned. The key must be BASE-space; `pick()` takes the key rather than building one, because the renderer has no base-space knowledge and the room does (`PerspectiveMapper.cell_to_base`).

**Constants / tuning**
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `COVERAGE_SAMPLES` = `33`
- `MIN_VALLEY` = `0.708`
- `FAMILY` = `{ ## A — "bico fundo": the long-spiked star, the silhouette the build has been ## making since CRACK-03. "star_deep":    {"lobes": 8, "r_out": 1.90, "r_in": 0.75, "phase": 0.0, "size": "small"}, ## B — "bico raso": the same star pulled in to half the reach. "star_shallow": {"lobes": 8, "r_out": 1.30, "r_in": 0.74, "phase": 0.0, "size": "small"}, ## C — "entalhe em V, cantos ficam": four points on the orthogonals only, so ## the diagonal corners of the struck cell's neighbours are never reached. "notch_v":      {"lobes": 4, "r_out": 1.70, "r_in": 0.76, "phase": 0.0, "size": "small"}, ## D — "chanfro 45 graus": the compact one. `r_in = r_out · cos(π/8)` makes it ## a regular octagon rather than a star. "chamfer_45":   {"lobes": 8, "r_out": 0.80, "r_in": 0.739, "phase": 0.3927, "size": "small"}, ## The large members. Same language, more reach — a rifle or a shotgun breach ## is not a different mechanism, only a bigger polygon. "star_deep_wide":  {"lobes": 8, "r_out": 3.20, "r_in": 1.05, "phase": 0.0, "size": "large"}, "star_ragged_wide": {"lobes": 11, "r_out": 2.80, "r_in": 1.20, "phase": 0.19, "size": "large"}, "chamfer_45_wide": {"lobes": 8, "r_out": 2.10, "r_in": 1.94, "phase": 0.3927, "size": "large"}, ## ── THE IRREGULAR MEMBERS (Director, 2026-09-04: *"algumas mais esquisitas, ## com um chunk grande faltando, angulos irregulares"*, on three references — ## a real bullet impact and two shard renders). ────────────────────────── ## ## ⚠️ EVERY RADIUS STILL CLEARS `MIN_VALLEY`. An asymmetric opening is one ## whose LARGE side is much larger, never one whose small side vanishes: the ## struck voxel is gone whole either way, so a radius under 0.708 would ask ## to keep a corner of it. [16] holds the line for these the same as the rest. ## ## `chunk_bite` — one big smooth chunk gone from a single quadrant, the rest a ## tight ragged rim. The asymmetry IS the shape. ## ## ⚠️ THE READ COMES FROM THE JUMP BETWEEN ADJACENT RADII, NOT FROM THE RANGE. ## The first pass at these two used 16 vertices easing smoothly from 4.2 down ## to 1.0, a 4:1 range — and both rendered as ROUND BLOBS ## (`glass_openings_family_2026-09-04.png`, first version). Every reference the ## Director sent is made of long STRAIGHT fracture edges, and a straight edge ## is what you get when two adjacent vertices are far apart in radius: the ## chord between them cuts across. Fewer vertices, bigger jumps. "chunk_bite": {"size": "small", "phase": 0.55, "radii": [ 2.90, 3.10, 1.00, 0.85, 1.60, 0.80, 1.10, 0.78, 0.90, 2.20]}, ## `star_wild` — irregular in BOTH axes: spikes of unequal length at unequal ## angles, so no two arms of the hole read as a pair. "star_wild": {"size": "small", "phase": 0.11, "radii": [ 2.10, 0.80, 1.30, 0.75, 2.60, 0.90, 1.00, 0.76, 1.70, 0.80, 2.30, 0.85], "angles": [ 0.00, 0.06, 0.13, 0.21, 0.27, 0.35, 0.44, 0.51, 0.60, 0.68, 0.79, 0.90]}, ## `shard_fan_wide` — the many-thin-spikes read of the third reference: a ## dense fan of long slivers, each a different length. "shard_fan_wide": {"size": "large", "phase": 0.0, "radii": [ 3.40, 1.10, 2.60, 1.05, 3.90, 1.20, 2.20, 1.00, 3.10, 1.15, 3.60, 1.05, 2.40, 1.10, 3.30, 1.00, 2.80, 1.20, 3.70, 1.10]}, ## `crescent_wide` — the first reference's silhouette: a huge chunk taken out ## of one side with a long sweeping edge, the far side barely opened. "crescent_wide": {"size": "large", "phase": 0.30, "radii": [ 4.30, 3.90, 1.15, 1.00, 1.40, 1.05, 0.95, 1.20, 1.00, 1.60, 2.60, 3.90]}, ## `gash_wide` — the one shape class the other eleven did not have: ELONGATED. ## Every other member is roughly radial, so a map of them reads as twelve sizes ## of the same idea. This one runs long on one axis and stays tight on the ## other, with the sides jagged rather than parallel — a pane that split along ## a line rather than a round that punched through it. "gash_wide": {"size": "large", "phase": 0.08, "radii": [ 3.60, 1.50, 2.20, 0.90, 1.10, 0.85, 2.90, 3.80, 1.30, 0.90, 1.00, 0.80, 1.90, 1.20]}, }`
- `POOLS` = `{ "small": ["star_deep", "star_shallow", "notch_v", "chamfer_45", "chunk_bite", "star_wild"], "large": ["star_deep_wide", "star_ragged_wide", "chamfer_45_wide", "shard_fan_wide", "crescent_wide", "gash_wide"], }`

---

### `glass_shard_shapes.gd`

`class_name GlassShardShapes` · 568 lines

`godot/scripts/systems/destruction/glass_shard_shapes.gd`

> GLASS G4-1 / G-D38 + G-D39 + G-D44 — THE SHARD SHAPE FAMILY. (Director, 2026-09-05: *"Precisamos de alguns voxels especiais, nos mesmos moldes que usamos para fazer as aberturas das balas, com formatos bem irregulares e angulosos"*, and *"os demais voxels também se transformam em uma multidão de partículas com formatos irregulares, que na verdade vão ser só umas 5 shapes"*.) ── ONE FAMILY, TWO CONSUMERS (G-D38) ──────────────────────────────────────── Those two sentences describe the SAME five shapes, and saying so once is what keeps this cheap: * `polygon(id)` — the free fragment, jagged all round. Rasterised into a 5-cell atlas, it is one instance of the falling rain's MultiMesh. * `anchored_polygon(id, mask, flop)` — the same member rotated to face the material it hangs from, pushed into that edge and CUT FLAT there. It cuts a voxel atom's alpha, exactly as `GlassOpening` already cuts a bullet hole's rim, and it is the remnant stuck in the frame. ⚠️ **THIS CANNOT BE `GlassOpening` WITH THE TEST INVERTED.** An opening's INTERIOR is removed; a fragment's interior is what is KEPT. Reusing those members the other way round gives remnants shaped like the NEGATIVE of a bullet hole — a ring, or a cell with a star-shaped bite out of it — which is the opposite of *"irregulares e angulosos"*. Same authoring language, different family, and the two never share a member. ⚠️ **THE ATTACH EDGE IS STRAIGHT, AND THAT IS PHYSICS, NOT A SHORTCUT.** A remnant is the glass that survived inside its own cell, and it meets the frame at the CELL BOUNDARY, which is a straight line. So `anchored_polygon()` clips at that plane: flat where it is held, jagged everywhere it broke. ⚠️ **G-D39 — ORIENTED BY THE ANCHOR, NEVER FREELY ROTATED.** The four-neighbour test in `GlassShatter.plan_pane_shatter()` has already decided which side is solid. A jagged fragment placed without regard to it floats in the middle of the opening with its solid corner facing away from the brick — the detail that would make the whole feature read as decoration rather than as physics. ── THE SIZE LAW (G-D44) ───────────────────────────────────────────────────── *"os cacos se subdividem todos em partes com tamanhos entre 1 e 1/2 voxel."* Every member is authored to fit inside one voxel, and an instance asks for a TARGET SIZE in `TARGET_MIN..TARGET_MAX` which `size_scale()` converts to that member's own multiplier — so the band is exact for every member rather than approximate for most. The member's own invariant is what `glass_shard_shapes_selftest` pins: * `EXTENT_MAX` — never wider or taller than one voxel, either axis; * `MAJOR_MIN` — and its long axis reaches at least half a voxel; * `AREA_MAX` — never a filled cell. A member at area 1.0 IS the square this whole feature exists to remove. * `ASPECT_MAX` and `FILL_MIN` — and not degenerate: not a splinter, not a spider. ⚠️ Two bounds, not one: see the constants' own note, where a single absolute area floor rejected the family's one deliberately elongated member and a single fill ratio then let a 10:1 needle straight through. * `ANGULAR_JUMPS` — at least this many adjacent-vertex pairs whose radii differ by `ANGULAR_RATIO`. ⚠️ **The angular read comes from the JUMP between adjacent radii, not from the range of them** — a straight fracture edge is the chord between two vertices at very different radii, and `GlassOpening` paid for this lesson once already with sixteen smoothly-eased vertices that rendered as round blobs. ⚠️ CHOSEN BY HASH, NEVER BY `randf()` — B4's rule. A remnant is re-picked whenever the geometry is rebuilt (a perspective flip, a load), so an RNG would reshape a standing fragment every time the camera turned. The rain does not need this for correctness (G-D43: it rests nowhere), but it keeps it anyway, because a `randf()` field cannot host a pixel gate and a hashed one can.

**Constants / tuning**
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `EXTENT_MAX` = `1.0`
- `MAJOR_MIN` = `0.50`
- `AREA_MAX` = `0.58`
- `ANGULAR_RATIO` = `1.55`
- `ANGULAR_JUMPS` = `2`
- `ASPECT_MAX` = `3.0`
- `FILL_MIN` = `0.22`
- `ANCHOR_RUN_POS` = `1`
- `ANCHOR_RUN_NEG` = `2`
- `ANCHOR_LEVEL_POS` = `4`
- `ANCHOR_LEVEL_NEG` = `8`
- `ANCHOR_DIRS` = `{ ANCHOR_RUN_POS: Vector2(1.0, 0.0), ANCHOR_RUN_NEG: Vector2(-1.0, 0.0), ANCHOR_LEVEL_POS: Vector2(0.0, 1.0), ANCHOR_LEVEL_NEG: Vector2(0.0, -1.0), }`
- `FAMILY` = `{ ## A — the classic fragment: one long point, a broad back. "wedge": {"phase": 0.06, "radii": [ 0.30, 0.24, 0.50, 0.20, 0.34, 0.19, 0.29]}, ## B — elongated. Every other member is roughly radial, so without this one a ## map of them reads as four sizes of the same idea: a pane splits along a ## LINE as often as it punches out a disc. ## ## ⚠️ THE FIRST VERSION OF THIS MEMBER WAS A FOUR-POINTED STAR, NOT A SPLINTER, ## and every number passed. It had radii alternating 0.50 / 0.13 at EVENLY ## SPACED angles, which is a sparkle — the shape had the elongation in its ## radii and none in its outline, because two long points opposite each other ## on a symmetric ring make a cross, not a shard. Elongation lives in the ANGLE ## table: the long radii sit at 0.00 and 0.50 turns and everything between them ## is short, so the outline itself runs long. Found by looking at the capture; ## the gate had flagged it as the lowest fill ratio in the family and I read ## that as "it is thin", which was the symptom and not the shape. ## ⚠️ AND THE SECOND VERSION WAS A SMOOTH LENS. Ten vertices whose radii eased ## from 0.50 down to 0.15 and back gave a convex almond — elongated, and with ## nothing on its flanks that reads as a break. The elongation has to come from ## the angle table AND the flanks have to zigzag, so the radii alternate along ## them instead of easing. "sliver": {"phase": 0.0, "radii": [ 0.50, 0.19, 0.29, 0.15, 0.25, 0.14, 0.21, 0.38, 0.16, 0.27, 0.13, 0.23, 0.15, 0.30], "angles": [0.00, 0.06, 0.13, 0.20, 0.27, 0.34, 0.42, 0.50, 0.57, 0.64, 0.71, 0.79, 0.86, 0.93]}, ## C — blocky: three broad faces with hard corners between them, the piece that ## came away along two existing cracks. ⚠️ Its radii used to be 0.31 / 0.20, ## a ratio of 1.55 — exactly ANGULAR_RATIO, so it counted as angular and read ## as a rounded hexagon. `angular_jumps()` is a floor, not a target. "chip": {"phase": 0.19, "radii": [ 0.34, 0.15, 0.30, 0.17, 0.36, 0.14]}, ## D — asymmetric, with a concave bite out of one flank. The bite IS the shape. "hook": {"phase": 0.42, "radii": [ 0.47, 0.42, 0.14, 0.19, 0.44, 0.24, 0.36, 0.16, 0.30]}, ## E — one long straight edge against a jagged opposite side: the piece that ## broke along an existing crack on one flank only. "blade": {"phase": 0.27, "radii": [ 0.49, 0.46, 0.17, 0.29, 0.15, 0.34, 0.18, 0.44], "angles": [0.00, 0.09, 0.28, 0.40, 0.52, 0.66, 0.80, 0.91]}, }`
- `IDS` = `["wedge", "sliver", "chip", "hook", "blade"]`
- `ATLAS_CELL_PX` = `64`
- `ATLAS_MARGIN` = `0.10`
- `ATLAS_SUPERSAMPLE` = `3`

---

### `glass_shatter.gd`

`class_name GlassShatter` · 632 lines

`godot/scripts/systems/destruction/glass_shatter.gd`

> GlassShatter — GLASS_MASTER_PLAN §5.1 (REWRITTEN 2026-08-31), G-D11. The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power, NOT a single `pane_shatter_punch` threshold. Every pellet or round that lands on a pane rolls its OWN chance `p_shatter(glass_punch)` to take the pane — or a region larger than its own hole (G-D12, the region flood — Stage B). A shotgun's 24 pellets each roll and the pane's odds compound with the count, and it is legitimately possible that none of them shatter it. `glass_punch` is exactly `ShotPunchTable.compute(weapon.punch, "glass", …)` — the same coefficient the local hole already uses. At neutral skill / point blank / neutral luck it is `PUNCH_GAIN(3.0) · weapon.punch / RESISTANCE["glass"](0.4)`. THE CURVE: a shifted, renormalised logistic. The shift-and-clamp is what guarantees the "near-flat bottom" the Director asked for — a plain logistic's low tail never reaches zero, so an smg round would still shatter panes a few percent of the time. `s(p) - SHATTER_C` clamped at zero kills that tail outright; `/ (1 - SHATTER_C)` renormalises so the top still approaches `SHATTER_P_MAX`. s(p) = 1 / (1 + e^(-SHATTER_K · (p - SHATTER_X0))) p_shatter(p) = clamp( SHATTER_P_MAX · (s(p) - SHATTER_C) / (1 - SHATTER_C), 0.0, SHATTER_P_MAX ) DIRECTOR-APPROVED TARGET DISTRIBUTION (2026-08-31, neutral skill/luck), pinned by `glass_shatter_selftest` reading the shipped weapon JSONs within a tolerance — so a later balance edit to a weapon's `punch` fails the suite rather than silently turning a pistol into a pane-breaker: | round               | glass_punch | P(shatter) target | this curve | |---------------------|-------------|-------------------|------------| | smg                 | 1.65        | ~0%               | 0.6%       | | shotgun pellet (1)  | 1.80        | ~2%               | 2.0%       | | pistol              | 2.10        | ~2.5%             | 5.5%       | | revolver            | 2.63        | ~16%              | 14.3%      | | assault rifle       | 3.75        | ~44%              | 43.8%      | | sniper              | 5.25        | ~81%              | 81.1%      | | shotgun blast (24×) | —           | ~38%              | 38.2%  = 1 - (1 - 0.020)^24 | The flat bottom is load-bearing: it is what keeps a shotgun's VOLUME (24 rolls at ~2%) its advantage over a pistol's single ~5% roll, and it is what keeps "none of the 24 shattered it" a real outcome. Pistol lands a touch high (5.5% vs 2.5%) — the target has a very sharp knee between punch 2.1 and 2.63 that no smooth sigmoid catches; `SHATTER_C` is the knob for it and the Director calibrates against real play (Director, 2026-08-31: *"Boa — fixar como está"*). ALL TUNABLES ARE `static var`, not `const` (architecture Rule 1, and the same reason ShotPunchTable's are): this file is a balancing lever the Director dials at runtime.

**Constants / tuning**
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `ShotPunchTableClass` = `preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")`
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `ShardShapesClass` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`

---

### `material_resistance_table.gd`

`class_name MaterialResistanceTable` · 264 lines

`godot/scripts/systems/destruction/material_resistance_table.gd`

> MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3, extended by D22. How much of a ring-group's voxels convert to DESTROYED vs DENTED vs CRACKED for a given wall/roof/floor material. D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): material properties are registered dynamic data, never hardcoded and never map-coupled — the old `const TABLE` literal is gone. Data now lives in `res://materials/*.json` (+ `user://materials/*.json`, user wins on collision), the same files `MaterialRegistry` reads for render properties — one row per material, one file per material, no duplication between the two readers. This file keeps its original static-accessor API (`destroy_factor`/`dent_factor`/ `crack_factor(material_id) -> float`, same defaults) so every existing call site (BlastCalculator, selftests) is untouched — only the data source changed, lazily loaded and cached on first access. Ordering (resistance to destruction, most -> least), per Director (2026-07-30 session): metal > stone > concrete > wood. Values are first-pass placeholders — a balancing lever (D6), not researched constants; expect these to be retuned once real captures show the effect.

**Constants / tuning**
- `RES_MATERIALS_DIR` = `"res://ASSETS/materials"`
- `USER_MATERIALS_DIR` = `"user://materials"`

---

### `shot_hit_roll.gd`

`class_name ShotHitRoll` · 70 lines

`godot/scripts/systems/destruction/shot_hit_roll.gd`

> ShotHitRoll — WEAPON_MASTER_PLAN D12's FIRST roll: does the shot hit the actor it was aimed at? The second roll (how much damage) is ShotPunchTable's and has shipped since 2026-08-02; this is the half that never existed. WHY IT EXISTS AS A REAL SEAM RATHER THAN AN `if false`. §6c Part C, in the Director's own scoping of this wave: the agent *"erra sempre o alvo (por enquanto)"* — but the always-miss has to run THROUGH the roll and force its outcome, not around it. A caller that skipped straight to the wall-damage path would be a second code path to delete the day the hit lands, and the deletion is the part that goes wrong. Forcing the outcome instead means the hit path is one enum away. WHAT IS DELIBERATELY NOT HERE. D12 is explicit that hittability is a STATS concern decoupled from what the sprite looks like: agent skill, cover, shadow, weapon level, powerups. None of those stats exist on any actor yet, so `chance_for()` below is a single named seam returning a placeholder, in the same spirit as WeaponBenchController._agent_skill() — one obvious place for the real terms to land, rather than a literal smeared across call sites. D32 will make the number player-facing (the cyclable target list's hit percentage). That is combat-phase surface and explicitly NOT this wave; the function it will read is this one. Tunables are `static var`, never `const` — architecture rule 1, and this file is a balancing lever like every other table beside it.

---

### `shot_punch_table.gd`

`class_name ShotPunchTable` · 429 lines

`godot/scripts/systems/destruction/shot_punch_table.gd`

> ShotPunchTable — DESTRUCTION_MASTER_PLAN D30 (Director, 2026-08-02). ONE scalar decides everything a single projectile does to the scenery: punch = PUNCH_GAIN x weapon_punch x skill x distance x luck / resistance Every factor is centred on 1.0, so a `punch` printed to the console is directly readable: 1.0 is "neutral shot, neutral agent, point blank, average luck, neutral material". That readability IS the requirement — Director: *"precisamos criar um coeficiente de destruição que seja fácil de mensurar e configurar."* WHY A NEW RESISTANCE TABLE INSTEAD OF MaterialResistanceTable's factors: those three numbers were calibrated as GROUP FRACTIONS ("what share of a ring group converts to this tier") and are consumed that way by apply_container_damage(). Reading them as a single-point divisor silently changes what they mean — metal's destroy_factor 0.05 would make a sniper round land below even the CRACKED threshold, i.e. bullets stop marking metal at all. Repurposing numbers tuned for another model is exactly the data-shape assumption CLAUDE.md's evidence rules warn about, so the point model gets its own explicit, separately tunable row set. All tunables are `static var`, not `const`: this whole file is a balancing lever (D6) and the Director asked for it to be configurable, which a `const` would prevent at runtime.

---

### `weapon_def.gd`

`class_name WeaponDef` · 114 lines

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

`class_name EarthVariantSelector` · 36 lines

`godot/scripts/systems/earth_variant_selector.gd`

> EarthVariantSelector — DESTRUCTION_MASTER_PLAN D2/D4 core. Floor/slab voxels don't have corners or continuous facade planes to project (unlike walls) — they're just a small pre-authored palette of voxel atoms, scattered across the grid by a deterministic hash of position. This is the whole mechanism: no shear, no junction compositor, no per-map baking step. Determinism is the entire point (D5): hash(x, y, level) is recomputed identically forever, never stored. A voxel's look never changes just because a neighbour got destroyed and exposed it — there is nothing to "pop" because nothing was ever assigned; it's re-derived the same way every time it's looked at.

**Constants / tuning**
- `VARIANT_COUNT` = `8`
- `ASSET_PATH_TEMPLATE` = `"res://ASSETS/materials/earth/voxel_earth_%d.png"`

---

### `enemy_phase_controller.gd`

`class_name EnemyPhaseController` · extends `Node` · 131 lines

`godot/scripts/systems/enemy_phase_controller.gd`

**Constants / tuning**
- `DEFAULT_VISION_RANGE` = `6`

**Public API**
- `func run_single_guard_turn( guard, player_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary, room_size: Vector2i, occupied: Dictionary, tic_callback: Callable,   ## room._apply_tic_result noise_callback: Callable,  ## M2-14: room._on_guard_emits_noise (guard noise emission) ## G3 STAGE D — the set the guard's FEET obey, which since G-D8 is not the ## one its eyes do. Empty means "same as `blocked_edges`", so every caller ## that has not been split behaves exactly as it did. movement_edges: Dictionary = {} ) -> Dictionary:`
- `func build_blocked_edge_set(edges: Array[Dictionary]) -> Dictionary:`
- `func build_movement_edge_set(edges: Array[Dictionary], glass_edges: Dictionary, edge_registry) -> Dictionary:`

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

### `glass_materials.gd`

`class_name GlassMaterials` · 240 lines

`godot/scripts/systems/glass_materials.gd`

> GlassMaterials — GLASS_MASTER_PLAN G-D16, the glass FAMILY seam. WHY THIS EXISTS, and it is measured rather than stylistic. Before G-VARIANT, "is this glass?" was written as a bare `material == "glass"` in TWENTY-FIVE places across rendering, geometry, occlusion, the guard phase, the shot path and the cook. Every one of them is a BEHAVIOUR: a glass slice does not occlude, does not enter the vision edge set, groups into a pane, lets a round through, renders on its own transparent layers, drops no smoke, and anchors no shards. G-D16 adds `glass_armored` and `glass_screen_{green,red,amber}` as members of that same family — *"a family of tinted behaviour classes, not new geometry"*. Adding them against 25 literal comparisons would make each new material a silently OPAQUE wall that happens to be named glass: it would occlude, block sight, stop rounds, puff smoke, and never form a pane. Nothing would error. So the family is asked, never compared. `is_glass()` is the only question the engine is allowed to ask about glass-ness, and `check_invariants.py` rule **L2** fails any new bare comparison outside this file. ── WHAT THIS FILE IS NOT ── It is not a second material registry. Resistance, destroy/dent/crack factors and `base_color` stay where they already live — `ASSETS/materials/<id>/<id>.json` via `MaterialResistanceTable`/`MaterialRegistry`, and `ShotPunchTable`'s balance rows. This file answers exactly one thing: which material ids are in the glass family, and (from V-C) which behaviour class each one carries.

**Constants / tuning**
- `FAMILY` = `["glass", "glass_armored", "glass_screen_green", "glass_screen_red", "glass_screen_amber"]`
- `BASE` = `"glass"`
- `TINT_SLOTS` = `5`
- `FRACTURE_WIDTHS` = `["tight", "wide"]`

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

`class_name VoxelLightField` · extends `RefCounted` · 675 lines

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

`class_name MaterialRegistry` · 177 lines

`godot/scripts/systems/material_registry.gd`

> MaterialRegistry — Material definitions, pattern algorithms, and resistance (destroy/dent/crack) — D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): material properties are registered dynamic data, never hardcoded and never map-coupled. Two-tier disk load (res:// then user://, user wins on collision), same pattern as BombRegistry/PropRegistry/WeaponRegistry. D19/D20: one row per material, surface-independent for behavior (this file). Texture identity is a SEPARATE axis, owned by BakePolicy.texture_for_material(). D34/E-SEAM-01 (Director, 2026-08-08): that axis is no longer surface-keyed either. A `has_facade` material renders EVERY surface — wall, roof and floor — from `facade_<id>`, tinted by `base_color` under MULTIPLY, so the three read as one material; only `has_facade == false` (organic ground) keeps the photographic `slab_<id>` source at WHITE. The WHITE-vs-tinted modulate is still decided by the texture id's own prefix at bake time (bake_compositor.gd's _modulate_for_mode), never by a field on this class — what changed is which ids reach it.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `StonePatternClass` = `preload("res://godot/scripts/systems/stone_pattern.gd")`
- `WoodPatternClass` = `preload("res://godot/scripts/systems/wood_pattern.gd")`
- `MetalPatternClass` = `preload("res://godot/scripts/systems/metal_pattern.gd")`
- `RES_MATERIALS_DIR` = `"res://ASSETS/materials"`
- `USER_MATERIALS_DIR` = `"user://materials"`

**Public vars**
- `var registry: Dictionary = {}`

**Public API**
- `func register(material: MaterialDef) -> void:`
- `func get_material(p_id: String) -> MaterialDef:`
- `func list_materials() -> Array:`
- `func count() -> int:`
- `func register_defaults() -> void:`
- `func load_from_disk() -> void:`

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

`class_name OcclusionSet` · 906 lines

`godot/scripts/systems/occlusion_set.gd`

> Occlusion Module — Computes which geometry occludes the agent POLICY: O1 — Occlusion is VIEW, not STATE - _occluded_cells is owned solely by this module - Never writes Voxel.visible, never uses dirty flag, never persists - NEVER reads _active_perspective (coordinates already rotated when entering) POLICY: O4′ — One view-space formula, no rotation applied The map is rebuilt rotated; we compute in already-rotated coordinates. POLICY: O5 — Depth is (x + y) in view-space, never z_index Isometric diamond layout: screen-y ∝ (x + y). Greater sum = nearer camera. POLICY: O7 — Glass does not occlude (a see-through pane hides nothing). A slice whose base material is glass is filtered out in _group_slices_by_edge() — see that function's header.

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

### `detonation_prediction.gd`

`class_name DetonationPrediction` · extends `RefCounted` · 164 lines

`godot/scripts/systems/prediction/detonation_prediction.gd`

> DetonationPrediction — PREDICTION_MASTER_PLAN §4, Task 4 (P-SLICE), 2026-08-09. One detonation being computed, as an object you can hold, advance a few milliseconds at a time, ask about, and throw away. `DetonationPlanBuilder` owns the pipeline and its phases; this owns the *handle*. The split matters for §5: a cache stores predictions, and a cache entry that is a bare `Dictionary` of pipeline internals would leak that pipeline into every consumer. ## Cancellation is free, and that is the entire payoff of Tasks 2 and 3 `cancel()` drops the state. There is no rollback, no restore set, nothing to undo — because nothing was done. Every phase writes only into the Delta and the build's own scratch dictionaries, so an abandoned prediction leaves the world byte-identical to how it found it. That property is asserted, not assumed: `blast_purity_selftest.gd` cancels a half-finished build mid-phase and snapshots all 7 mutable fields of all ~100 000 voxels either side. §3.2 rejected snapshot/restore partly on this: a restore-based design would have to enumerate its undo set perfectly on every cancellation, and a player sweeping a cursor across ten GUs cancels nine times. ## Best-effort budgets `step()` honours its budget BETWEEN chunks, never inside one, and two phases (SOOT, LIGHT) cannot be suspended at all — see `DetonationPlanBuilder`'s phase table and §8.8's measurements. A caller must treat the budget as a target, not a guarantee, and `worst_step_ms` is here so it can find out what it actually got instead of trusting the number it asked for.

**Constants / tuning**
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`

**Public vars**
- `var delta: WorldDelta = null`
- `var signature: String = ""`
- `var steps: int = 0`
- `var worst_step_ms: float = 0.0`
- `var worst_step_phase: String = ""`
- `var warmed: bool = false`

**Public API**
- `func begin(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> void:`
- `func step(budget_ms: float) -> bool:`
- `func run(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> WorldDelta:`
- `func cancel() -> void:`
- `func is_cancelled() -> bool:`
- `func is_done() -> bool:`
- `func progress() -> float:`
- `func phase_name() -> String:`
- `func profile_lines() -> Array[String]:`

---

### `prediction_cache.gd`

`class_name PredictionCache` · extends `RefCounted` · 208 lines

`godot/scripts/systems/prediction/prediction_cache.gd`

> PredictionCache — PREDICTION_MASTER_PLAN §5, Task 5 (P-CACHE), 2026-08-09. Holds finished predictions so that coming BACK to a target is free. The Director's own reason, and it is the right one: *"O jogador pode decidir mudar de GU na última hora (é o mais provável, a gente só pára de ficar mexendo quando acerta a que estava buscando), então temos que jogar fora e começar de novo rapidamente."* A cursor sweeping ten GUs generates ten predictions and discards nine. Coming back is the COMMON case, because the sweep is a comparison. ## The key, and why invalidation is deliberately blunt `(signature, world_revision)`. The signature is the action's own identity (bomb + target GU + perspective); the revision is a counter the world bumps on every committed mutation. A bumped revision drops the whole cache at once. That is coarse on purpose. §5.2: a precise dependency graph is a second system to get wrong, and the common case — nothing changes while the player is choosing a target — is served perfectly by the blunt version. Flagged there as revisitable, not as final. ## One prediction is pumped at a time, and a superseded one is CANCELLED §4.2: *"hover moves to another GU → previous request cancelled, not completed; cache keeps whatever finished."* A half-built prediction for a GU the player has already left is pure cost, so it is dropped rather than finished in the background. Cancelling is free (nothing was written — see `DetonationPrediction`), which is what makes "throw away and start again quickly" a real option instead of an expensive one. ## Sizing `max_entries` = 8 by default, and that is a SETTLED number rather than a provisional one (§5.4, Q3): the workload is one cursor comparing GUs, not a guard swarm. Guard AI is out of scope and gets its own system if it ever needs one, so nothing here is shaped around it.

**Constants / tuning**
- `DetonationPredictionClass` = `preload("res://godot/scripts/systems/prediction/detonation_prediction.gd")`

**Public vars**
- `var max_entries: int = 8`
- `var hits: int = 0`
- `var misses: int = 0`
- `var evictions: int = 0`
- `var cancellations: int = 0`
- `var invalidations: int = 0`

**Public API**
- `func request(signature: String, revision: int, bomb_def, source_gu: Vector2i, ctx: Dictionary) -> DetonationPrediction:`
- `func peek(signature: String, revision: int) -> WorldDelta:`
- `func pump(budget_ms: float) -> bool:`
- `func is_busy() -> bool:`
- `func invalidate() -> void:`
- `func size() -> int:`
- `func stats_line() -> String:`

---

### `world_delta.gd`

`class_name WorldDelta` · extends `RefCounted` · 400 lines

`godot/scripts/systems/prediction/world_delta.gd`

> WorldDelta — PREDICTION_MASTER_PLAN §3.1, Task 3 (P-DELTA), 2026-08-09. **A description of what WOULD change, never a change.** An action is simulated into one of these; committing it is a separate, explicit act. That split is the whole plan: it is what lets the engine answer *"what would this grenade do"* without doing it, and therefore what lets a detonation be computed early (§4), cached (§5), thrown away when the player moves the cursor, or read by a HUD that must not damage anything to draw a number. It lives under `systems/prediction/`, not under `systems/destruction/`, deliberately — §0: *"Explosions are this layer's first consumer and its proving ground, not its owner."* ## The projection, and why it is not just a dictionary of new values Half of this class is `_by_voxel`: the answer to *"what would this voxel be if this Delta committed?"* Everything downstream of the damage step in `DetonationPlanBuilder` — soot derivation, occupancy, tile resolution, the census — used to read that answer off the real Voxel, because the damage had already been applied to it. With a pure builder there is nothing to read, so the projection has to answer instead. It models `Voxel.set_damage()` EXACTLY, including the two rules that are easy to miss and would silently produce a Delta that predicts the wrong thing: - **the early return.** An entry naming a state the voxel is already in writes nothing — and, critically, leaves the OTHER four fields at their older values. A projection that just overwrote would invent a fresh variant/substrate for a voxel that is going to keep its old one. - **`visible` follows DESTROYED only.** Nothing sets it back to true, so a voxel that was destroyed and is later marked DENTED stays invisible. That is pre-existing behaviour, and the projection reproduces it rather than tidying it up. ## What a Delta must not be trusted to survive `damage` entries and `touched_voxels` hold **live Voxel references**. They are valid only against the world revision the Delta was computed on — which is exactly what §5.2's cache key exists to enforce. A Delta that outlives a map reload points at freed objects; `touched` (plain `Vector3i` cells) is the field to read when a consumer needs to survive that.

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `P_STATE` = `0`
- `P_BLAST` = `1`
- `P_SIDE` = `2`
- `P_VARIANT` = `3`
- `P_SUBSTRATE` = `4`
- `P_VISIBLE` = `5`

**Public vars**
- `var damage: Array = []`
- `var waves: Dictionary = { "destroy": {}, "dented": {}, "cracked": {}, "smoke": {}, "ember": {}, "debris": {}, "soot": {}, }`
- `var census: Dictionary = {}`
- `var touched: Array[Vector3i] = []`
- `var touched_voxels: Array = []`
- `var cost_ms: float = 0.0`
- `var scorch_writes: Dictionary = {}`
- `var glass_openings: Array = []`
- `var glass_crazes: Array = []`
- `var glass_shard_piles: Dictionary = {}`

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

extends `Node` · 156 lines

`godot/scripts/systems/registries_autoload.gd`

> Registries — Global autoload for MaterialRegistry and PropRegistry Replaces Engine.set_meta() pseudo-singletons with real Godot autoload. This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup() after ScriptServer::finish_languages() has begun dismantling the script language. Strategy: the AUTOLOAD is what fixes the crash — a real Node with a real lifetime, torn down before the script language is dismantled. The weak references below were belt-and-braces on top of that. REG-STRONG-01 (2026-08-13, measured): the belt was costing real work every frame it was worn. Nothing else in the game holds a registry, so each one was being collected between accesses and REBUILT FROM DISK on the next call — measured on one real grenade throw: the bomb registry re-read `bombs/*.json` **4 times**, the material registry re-scanned `materials/*.json` **twice**. They are strong refs now, which is what `_frame_cache` below already does for exactly the same reason (FRAME-MEM-01, and it shipped without bringing the shutdown crash back — the precedent is six lines down from the bug).

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

### `save_state.gd`

`class_name SaveState` · extends `RefCounted` · 212 lines

`godot/scripts/systems/save_state.gd`

**Constants / tuning**
- `FORMAT_VERSION` = `1`

---

### `stone_pattern.gd`

`class_name StonePattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 30 lines

`godot/scripts/systems/stone_pattern.gd`

> StonePattern — Granular per-voxel jitter Simulates natural surface granularity; grainy texture with high-frequency variation

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

---

### `texture_resolver.gd`

`class_name TextureResolver` · 231 lines

`godot/scripts/systems/texture_resolver.gd`

> Texture Resolver — Fallback chain for baked facade sources Part of BAKING_MASTER_PLAN: §4.2 TextureResolver See TEXTURE_CATALOG.md for the full texture contract

**Constants / tuning**
- `MAX_FILE_SIZE_BYTES` = `10 * 1024 * 1024`

**Public vars**
- `var tex_user_dir: String = "user://textures/"`
- `var tex_default_dir: String = "res://ASSETS/materials/"`
- `var log_lines: PackedStringArray = []`

**Public API**
- `func resolve(texture_id: String, material_folder: String = "") -> ResolvedTexture:`
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

### `voxel_variant_registry.gd`

`class_name VoxelVariantRegistry` · 76 lines

`godot/scripts/systems/voxel_variant_registry.gd`

> VoxelVariantRegistry — Pre-fabricated damage-ATOM lookup (EXPLOSION_REBUILD_MASTER_PLAN Task 1b/E-BAKE, 2026-08-06, §3.1) Stores and resolves pre-baked damage-decal tile references created during map load. D-ARCH-01's per-CELL key (grid_pos, level, material) is gone — the atom-bake model's whole premise is that a damaged voxel shows a RANDOMLY CHOSEN facade crop for its material, not its own, so there is no cell dimension left to key on. The key is now purely about WHICH ATOM: (element_class, material, damage_material_name, substrate_variant). `damage_material_name` is the exact string VoxelRenderer. damage_variant_material()/floor_damage_material() computes for a given (damage_state, blast_sourced, carved_side, decal_variant) — the same functions VoxelRenderer.apply_damage_voxel_swap() calls to build its lookup key, so a hit and its D33 runtime-compositing fallback can never name a cell differently. `substrate_variant` is Voxel.damage_substrate, rolled once per mark and persisted (see Voxel's own doc). Soot is deliberately NOT part of this registry: soot is a per-cell modulate-alpha code (VoxelLightField.encode_face_soot()) applied by the light-repaint pass after any set_cell(), independent of which source_id/atlas_coords a cell shows. DESTROYED voxels are not registered either — Voxel.set_damage(DESTROYED) sets visible = false and the renderer erases the cell directly, never reaching a damage-variant lookup at all.

**Public API**
- `func register(variant_key: String, source_id: int, atlas_coords: Vector2i) -> void:`
- `func get_variant(variant_key: String) -> Dictionary:`
- `func clear() -> void:`
- `func size() -> int:`

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

### `agent_frame_bake_spike.gd`

extends `SceneTree` · 968 lines

`godot/scripts/tools/agent_frame_bake_spike.gd`

> CHARACTER_MASTER_PLAN Part 2 — bake the posed agent for placement in the room. A sibling of grenade_frame_bake_spike.gd, copied per that file's own stated convention, and it differs from it in exactly two ways. Both differences exist because this object is a CHARACTER whose size is a ratified number, not a prop whose size is a judgement call. 1. MESH_SCALE IS 1.0 AND ORTHO_SIZE IS DERIVED, NOT TUNED. Every other bake in this project carries the comment "first-guess world scale, visually tuned, not derived from a formula" — correct for a grenade, and disqualifying here: the whole point of putting the agent in the scene is to judge his PROPORTIONS, and a scale tuned by eye would make that judgement circular. §4.7 fixes 1 voxel at 0.20 m (the figure ships at 2.00 m = 10.0 voxels, the Director's 2026-08-16 call — see p2_grip_spike.py's scale_to_target_height for what that costs), and QUICK_REFERENCE fixes VOXEL_STEP_PX at 20, so the frame's pixels-per-metre is pinned at 20 / (0.20 * cos 30) = 115.47 and nothing else reproduces the game's size. The source GLB is authored in real metres, so MESH_SCALE is 1.0 and ORTHO_SIZE follows from the viewport. The bake then MEASURES the rendered figure and fails loudly if it missed. 2. RECENTRED IN Y ONLY, NOT ON THE FULL AABB. The grenade recentres on its whole AABB, which puts the AABB bottom-centre on the yaw axis and makes one anchor valid for all four frames. That works because a grenade is symmetric. This figure HOLDS A SHOTGUN sticking 0.6 m forward, so its AABB centre is not its footprint centre, and recentring on X/Z too would stand him off his own tile by the length of the weapon. Shifting in Y alone keeps the figure's own vertical axis on the yaw axis — still rotation-invariant, still one anchor — while the ground point stays where the model was authored: under the FEET. The exported GLB's origin is that point (p1_agent_model.py loud-fails if the figure does not stand on z=0), which is why no measurement is needed to find it. Source: tools/asset_generation/p2_grip_spike.py with P2_EXPORT_GLB, so what gets baked is the same pose the Director judged on the grip matrix, not a second pose that merely resembles it. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/agent_frame_bake_spike.gd

**Constants / tuning**
- `DEFAULT_MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_posed_shotgun_ready.glb"`
- `DEFAULT_OUT_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames/"`
- `DIRECTIONS` = `["N", "E", "S", "W"]`
- `YAW_BY_DIRECTION` = `{"N": 0.0, "E": 90.0, "S": 180.0, "W": -90.0}`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_DEG` = `45.0`
- `CAMERA_DISTANCE` = `12.0`
- `VOXEL_M` = `0.20`
- `VOXEL_STEP_PX` = `20.0`
- `FIGURE_HEIGHT_M` = `2.00`
- `MESH_SCALE` = `1.0`
- `SCALE_TOLERANCE_PX` = `0.25`
- `MAX_WHITE_FRACTION` = `0.10`
- `NORMAL_BAKE_SHADER_CODE` = `"""`
- `NO_RECENTRE_OVERRIDE` = `INF`
- `NECK_MESH_NAME` = `"seg_neck"`
- `HEAD_MESH_NAME` = `"seg_head"`
- `DEFAULT_LAYER_YAWS` = `24`
- `VERIFY_CANVAS` = `Vector2i(512, 512)`
- `VERIFY_MAX_MISMATCH_FRACTION` = `0.015`

**Public API**
- `func expected_height_px_for(height_m: float) -> float:`

---

### `bake_cache_selftest.gd`

extends `SceneTree` · 441 lines

`godot/scripts/tools/bake_cache_selftest.gd`

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

extends `SceneTree` · 358 lines

`godot/scripts/tools/bake_selftest.gd`

> BAKE-FIX-01: MASTER-STRIP SELFTEST Updated selftest suite for master-strip baking architecture. Tests B1–B6 with focus on real voxel alpha matching and canonical silhouette copying.

**Constants / tuning**
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `VOXEL_PATH_TEMPLATE` = `"res://ASSETS/materials/%s/voxel_%s.png"`
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

extends `SceneTree` · 2632 lines

`godot/scripts/tools/blast_calculator_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 3 — BlastCalculator selftest. Rodar: godot --headless --script res://godot/scripts/tools/blast_calculator_selftest.gd Synthetic fixtures only (SliceGenerator/SlabGenerator against a hand-built Edge list), same discipline as roof_slab_selftest.gd/slab_render_selftest.gd — no real map involved. Real-map end-to-end proof is the screenshot captures (INFILTRAITOR_CAPTURE_ACTION=test_zone_menu/test_zone_detonate).

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `BombDefClass` = `preload("res://godot/scripts/systems/destruction/bomb_def.gd")`
- `BombRegistryClass` = `preload("res://godot/scripts/systems/destruction/bomb_registry.gd")`
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
- `func test_face_soot_points_at_the_hole() -> void:`
- `func test_face_soot_merges_at_a_corner() -> void:`
- `func test_face_soot_leaves_isotropic_result_untouched() -> void:`
- `func test_crater_core_solid_rim_ragged_beyond_intact() -> void:`
- `func test_crater_dents_rim_and_band_by_material() -> void:`
- `func test_bias_prefers_epicenter_facing_side() -> void:`
- `func test_no_bias_sentinel_keeps_hash_only_behavior() -> void:`
- `func test_cone_is_directional_not_radial() -> void:`
- `func test_cone_widens_with_distance() -> void:`
- `func test_cone_respects_range_and_half_angle() -> void:`
- `func test_cone_stops_at_blocked_edge() -> void:`
- `func test_flood_rings_stops_at_solid_block() -> void:`
- `func test_flood_cone_stops_at_solid_block() -> void:`
- `func test_cone_output_shape_matches_rings() -> void:`
- `func test_destroy_multiplier_scales_damage() -> void:`
- `func test_ring3_reached_but_zero_weighted() -> void:`
- `func test_vertical_falloff_identical_for_wall_and_roof() -> void:`
- `func test_roof_two_levels_same_ring_group() -> void:`
- `func test_crater_dent_varies_by_real_floor_material_wood_vs_concrete() -> void:`
- `func test_deep_layer_gate_blocks_floor_deep_level() -> void:`
- `func test_slab_pierce_multiplier_scales_destruction() -> void:`
- `func test_pellet_impacts_no_hard_range_cap() -> void:`
- `func test_pellet_impacts_count_matches_projectile_count() -> void:`
- `func test_pellet_does_not_detour_around_narrow_obstacle() -> void:`
- `func test_point_impact_marks_only_the_impact_voxel() -> void:`
- `func test_point_impact_neighbour_ladder() -> void:`
- `func test_point_impact_cascades_only_on_full_destroy() -> void:`
- `func test_point_impact_never_re_marks_an_existing_hole() -> void:`
- `func test_punch_coefficient_ordering() -> void:`
- `func test_cone_spread_is_a_disc_not_a_line() -> void:`
- `func test_no_shipped_weapon_reaches_the_cascade() -> void:`
- `func test_line_impact_is_straight_and_measures_distance() -> void:`
- `func test_line_passes_through_glass_and_hits_what_is_behind() -> void:`
- `func test_aim_offset_steers_the_shot_off_axis() -> void:`
- `func test_pellet_selection_is_deterministic() -> void:`
- `func test_carved_side_faces_the_blast() -> void:`
- `func test_carved_side_survives_rotation() -> void:`
- `func test_self_soot_faces_dented_lateral_sides() -> void:`
- `func test_self_soot_faces_dented_top_and_bottom() -> void:`
- `func test_self_soot_faces_cracked_blast_hits_all_three() -> void:`
- `func test_self_soot_faces_cracked_bullet_no_side_falls_back_to_top() -> void:`
- `func test_self_soot_faces_intact_and_destroyed_get_none() -> void:`
- `func test_apply_self_soot_fills_in_when_nothing_stronger_exists() -> void:`
- `func test_apply_self_soot_never_weakens_an_existing_stronger_ring() -> void:`
- `func test_crater_crack_absent_without_weights() -> void:`
- `func test_crater_crack_bands_and_severity_ladder() -> void:`

---

### `blast_purity_selftest.gd`

extends `SceneTree` · 684 lines

`godot/scripts/tools/blast_purity_selftest.gd`

> Prediction-layer selftest (PREDICTION_MASTER_PLAN Tasks 2-6, 2026-08-09). Purity and determinism (P-PURE, P-DELTA), frame-slicing and cancellation (P-SLICE), and the cache's sweep/invalidation behaviour (P-CACHE). Rodar: python3 tools/persistent/run_selftests.py --only blast_purity This is the test §11.4 calls "the test that makes the whole plan safe": it asserts that computing a detonation changes NOTHING about the world, so a prediction that is computed and thrown away costs nothing but the time. **Task 3 widened its subject from the two mutators to the whole pass.** It opened running a hand-written mirror of `build_plan()`'s damage phase, because `build_plan()` itself still committed and would have defeated a purity test outright. Now that P-DELTA made the builder pure, the mirror is gone and every test below runs the REAL `DetonationPlanBuilder.build_plan()` — which is both a stronger claim (the whole 170 ms pipeline is pure, not just its damage step) and one fewer copy of the pipeline free to drift out of sync with the original. Why it lives in its own file rather than inside blast_calculator_selftest.gd: that suite is Task 2's REGRESSION NET — its ~20 direct calls to the mutating `apply_*` functions pin today's behaviour, and the task's own gate is that it passes with **zero edits**. Adding to it would have compromised the one piece of evidence the refactor rests on. Everything here runs against the REAL PLAYGROUND map and the REAL frag grenade, not a synthetic patch — CLAUDE.md's own standing lesson (a floor-dent feature that passed its fixture with 69 dents and produced ZERO on the real map). Test 3 exists specifically to make a silently-inert simulate impossible to mistake for a clean one. RED-BEFORE-GREEN, recorded because a purity test that has never failed proves nothing. With one `voxel.set_damage(...)` added inside `BlastCalculator.damage_entry()` — the smallest edit that makes BOTH simulate functions impure at once — this run came back: ✗ 167 voxel(s) changed state during build_plan() (e.g. (7, 11) level 0: [0, false, 0, 0, 0, true, false] -> [2, true, 0, 0, 0, false, true]) ✗ 3 container(s) had their dirty_count moved by build_plan() RESULT: 6 PASS, 2 FAIL Note what stayed green under that break, because it is the reason test 1 has to exist separately: determinism (2) and the tier census (3) both still passed, and test 4 still reported every entry landing correctly — it merely counted 167 no-ops instead of 0. An impure builder is invisible to every check here except this one.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`
- `BombRegistryClass` = `preload("res://godot/scripts/systems/destruction/bomb_registry.gd")`
- `WallEdgeDataClass` = `preload("res://godot/scripts/world/wall_edge_data.gd")`
- `BUDGET_MS` = `4.0`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_1_simulate_writes_nothing(before: Dictionary, after: Dictionary) -> void:`
- `func test_2_simulate_is_deterministic(da: WorldDelta, db: WorldDelta) -> void:`
- `func test_3_the_delta_is_not_empty_on_the_real_map(wd: WorldDelta) -> void:`

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

### `ceiling_carve_seam_selftest.gd`

extends `SceneTree` · 213 lines

`godot/scripts/tools/ceiling_carve_seam_selftest.gd`

> D33 Part 3d — the real render-seam selftest for ceiling DENTED marks, sibling to decal_seam_selftest.gd (3a), half_voxel_seam_selftest.gd (3b), and floor_sunk_seam_selftest.gd (3c). This is the last one — Part 3 is complete after this suite passes. Rodar: godot --headless --script res://godot/scripts/tools/ceiling_carve_seam_selftest.gd

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_plan_parser_recognizes_ceiling_case() -> void:`
- `func test_set_voxel_cell_end_to_end_picks_the_ceiling_composite() -> void:`
- `func test_resolve_flat_receives_the_real_material_directly() -> void:`
- `func test_floor_still_resolves_when_both_could_apply() -> void:`
- `func test_no_baked_atom_falls_through_to_generic() -> void:`

---

### `damage_atom_bake_selftest.gd`

extends `SceneTree` · 421 lines

`godot/scripts/tools/damage_atom_bake_selftest.gd`

> E-BAKE — damage-atom pre-bake selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1b, 2026-08-06). Rodar: godot --headless --script res://godot/scripts/tools/damage_atom_bake_selftest.gd Boots the REAL PLAYGROUND map through the exact room.gd::load_map() path (mirrors floor_zone_bake_selftest.gd's own scaffold) and proves: 1. DamageVariantBaker.bake_all() actually populates the registry — real coverage across all three element classes (WALL/CEILING/FLOOR), not just a non-empty count. 2. apply_damage_voxel_swap() resolves through the NEW (element_class, material, name, substrate) key — a real Voxel with damage_state/carved_side/variant/substrate set swaps to a pre-baked tile instead of falling through to D33 live compositing. 3. The user:// disk cache actually skips recompositing on a second bake of the identical declared-material set — same atom count, real disk cache hits. 4. D13's loud-fail: a material used by the map but missing from its declared damage_materials produces a real warning, not a silent gap. Every expectation is checked against the REAL registry/renderer state — never read back from the code under test's own success claim.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `VoxelVariantRegistryClass` = `preload("res://godot/scripts/systems/voxel_variant_registry.gd")`
- `DamageVariantBakerClass` = `preload("res://godot/scripts/systems/damage_variant_baker.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_1_real_coverage_across_element_classes(built: Dictionary) -> void:`
- `func test_2_apply_damage_voxel_swap_resolves_new_key(built: Dictionary) -> void:`
- `func test_3_cache_hit_on_second_bake() -> void:`

---

### `damage_composite_cache_selftest.gd`

extends `SceneTree` · 251 lines

`godot/scripts/tools/damage_composite_cache_selftest.gd`

> D33 Part 1 — DamageCompositeCache selftest. Rodar: godot --headless --script res://godot/scripts/tools/damage_composite_cache_selftest.gd Part 1's scope (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5/§11) is the cache + its dynamic page, NOT the pixel math (Part 2) or the render-path wiring (Part 3) — so this suite proves allocation, idempotence, page overflow, real TileSet registration, and the reset prune_baked_sources() now drives, without composing a single real decal.

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `DamageCompositeCacheClass` = `preload("res://godot/scripts/geometry/damage_composite_cache.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_empty_cache_reports_nothing() -> void:`
- `func test_store_registers_a_real_tile_and_is_idempotent() -> void:`
- `func test_two_distinct_keys_land_in_distinct_slots_with_correct_pixels() -> void:`
- `func test_wrong_sized_image_is_rejected_without_corrupting_state() -> void:`
- `func test_page_overflow_allocates_a_second_page() -> void:`
- `func test_reset_clears_everything_and_next_store_starts_fresh() -> void:`

---

### `decal_compositor_equality_selftest.gd`

extends `SceneTree` · 186 lines

`godot/scripts/tools/decal_compositor_equality_selftest.gd`

> D33 Part 2 — the equality proof the plan calls "the single highest-risk step" (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 2). Compares DecalCompositor's GDScript output against a reference composited by the REAL Python function it ports (generate_voxel.py's compose_decal_voxel), on fixtures neither side generates itself: godot/scripts/tools/fixtures/d33_part2/{substrate,decal}.png       — inputs godot/scripts/tools/fixtures/d33_part2/reference_{lateral,top}.png — Python output (produced by tools/asset_generation/d33_part2_fixture_gen.py, which calls the real _paste_decal/compose_decal_voxel unmodified). Rodar: godot --headless --script res://godot/scripts/tools/decal_compositor_equality_selftest.gd Tolerance is MEASURED here, not assumed: DecalCompositor's own doc comment names two real sources of divergence (Lanczos implementation differences, Python round-half-to-even vs Godot's round-half-up at 8-bit quantization). The thresholds below are the actual measured worst case on this fixture, recorded so a future regression shows up as a real failure instead of a silently loosened bound.

**Constants / tuning**
- `DecalCompositorClass` = `preload("res://godot/scripts/geometry/decal_compositor.gd")`
- `FIXTURE_DIR` = `"res://godot/scripts/tools/fixtures/d33_part2/"`
- `FACE_SE` = `DecalCompositorClass.FACE_SE`
- `FACE_TOP` = `DecalCompositorClass.FACE_TOP`
- `FACE_SW` = `DecalCompositorClass.FACE_SW`
- `FACE_SE_MIRRORED` = `DecalCompositorClass.FACE_SE_MIRRORED`
- `MAX_CHANNEL_DIFF_TOLERANCE` = `3`
- `MAX_MISMATCHED_PIXEL_FRACTION` = `0.0`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_face(label: String, target: Dictionary, reference_filename: String, substrate: Image, decal: Image) -> void:`
- `func test_b3_clamp_never_exceeds_substrate_silhouette(substrate: Image, decal: Image) -> void:`

---

### `decal_seam_selftest.gd`

extends `SceneTree` · 338 lines

`godot/scripts/tools/decal_seam_selftest.gd`

> D33 Part 3a — the real render-seam selftest. Rodar: godot --headless --script res://godot/scripts/tools/decal_seam_selftest.gd Parts 1/2 proved the cache and the compositor in isolation. This suite proves the SEAM (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3a): VoxelRenderer._full_voxel_decal_plan() (name parsing) and _composite_full_voxel_decal() (substrate read + tint + compose + cache), wired into the real _set_voxel_cell(), against a REAL registered baked page and the REAL decal_bullet_concrete_0.png art (not a synthetic placeholder — Part 3a's whole point is compositing onto what the wall around it actually shows). _baked_lookup is stubbed (a small duck-typed fake, not the real BakedTileLookup) so this test doesn't have to stand up a full EdgeRegistry/facade bake just to control what "the wall's baked atom" resolves to — that machinery is what the bake selftests already cover; this one owns what D33 added on top of it.

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_plan_parser_recognizes_full_voxel_cases() -> void:`
- `func test_composite_applies_tint_and_pastes_the_real_decal() -> void:`
- `func test_composite_is_idempotent() -> void:`
- `func test_set_voxel_cell_end_to_end_picks_the_composite() -> void:`
- `func test_dented_and_non_impact_names_are_unaffected() -> void:`
- `func test_no_baked_atom_falls_through_to_generic() -> void:`

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

### `detonation_plan_selftest.gd`

extends `SceneTree` · 1018 lines

`godot/scripts/tools/detonation_plan_selftest.gd`

> E-PLAN — DetonationPlanBuilder selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 4, 2026-08-07). Rodar: godot --headless --script res://godot/scripts/tools/detonation_plan_selftest.gd Boots the REAL PLAYGROUND map through the exact room.gd::load_map() path (mirrors damage_atom_bake_selftest.gd's own MinimalRoom scaffold), runs DetonationPlanBuilder.build_plan() against a REAL grenade throw at a real wall's own GU, and proves: 1. The Task 4 gate itself — a printed wave census (cell counts per ring, per wave kind) from a real detonation, not a synthetic fixture. 2. Every dented/cracked/expose entry carries a real, resolved (source_id, atlas_coords, alt) triple — never a placeholder. 3. build_plan() never mutates the live TileMapLayer — every placed cell's (source_id, atlas_coords, alt) is BYTE-IDENTICAL before and after, proven by a real snapshot diff, not by re-reading the code's own claim. 4. The exposure fallback (§2/B5) fires for real: at least one destroy entry carries a non-empty `expose` array once the crater opens the floor. 5. smoke_ring_weights is consumed for real (duration/scale fall off with ring, matching the JSON's own weights) — the "still unread" gap Task 3's closure note flagged. 6. The per-tier ring gates from the REAL frag_grenade.json hold on real data: crack_ring_weights[0]=0.0 means ring 0 never has a cracked entry, dent_ring_weights[2]=0.0 means ring 2 never has a dented one. 7. E-EMBER-01: a real blast at PLAYGROUND's own WOOD wall queues embers, every one on a SURVIVING combustible voxel 6-adjacent to a hole this same blast opens — cell->material read off the live registries, not assumed. Non-zero on real data is the point: this is the exact shape of failure the floor-dent case (69 on a fixture, 0 on PLAYGROUND) is remembered for. 8. E-SMOKE-TINT-01: every per-voxel smoke entry carries the material it came from, without which the choreographer cannot tint the puff. 9. E-EMBER-02: fire creeps UPWARD one level at a time (every rung sits directly above another lit voxel and burns shorter than it), the creep is FNV-1a-deterministic across two builds of the same blast, and an ember COOLS yellow-hot -> deep red while dimming — the one detail the Director first described inverted and then corrected. 10. E-DEBRIS-01: dust/sparks/chips fire only on cells the blast DESTROYS, only on materials their own rule lists, with counts inside their range and identical across two builds — plus the contract that a ctx carrying no debris policy produces exactly zero, so no pre-existing caller moved. Every expectation is checked against the REAL plan/registry/renderer state — never read back from the code under test's own success claim.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`
- `BombRegistryClass` = `preload("res://godot/scripts/systems/destruction/bomb_registry.gd")`
- `WallEdgeDataClass` = `preload("res://godot/scripts/world/wall_edge_data.gd")`
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`
- `EmberOverlayClass` = `preload("res://godot/scripts/overlays/ember_overlay.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `dump_glass_openings.gd`

extends `SceneTree` · 61 lines

`godot/scripts/tools/dump_glass_openings.gd`

> GLASS CRACK-04 — print the opening family as JSON, for the sheet generator. Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \ --script godot/scripts/tools/dump_glass_openings.gd ⚠️ THE FAMILY HAS ONE AUTHORITY AND IT IS `glass_opening.gd`. The fracture sheets are generated in Python, and a Python copy of the twelve polygons would be a second definition of the shape the whole track exists to keep single — drifting silently the first time a member is retuned, with the art quietly describing a hole the engine no longer cuts. So the generator ASKS. This prints, and `gen_fracture_sheet.py` runs it and reads stdout; nothing is stored in the repo to go stale. Output: one JSON object, `{"openings": [{id, size, r_max, radii: [...]}, ...]}`, with `radii` sampled at `SAMPLES` evenly spaced angles from +run counter-clockwise — the boundary distance the generator starts each crack from.

**Constants / tuning**
- `GlassOpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `SAMPLES` = `180`

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

extends `SceneTree` · 186 lines

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

extends `SceneTree` · 296 lines

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

### `floor_sunk_seam_selftest.gd`

extends `SceneTree` · 209 lines

`godot/scripts/tools/floor_sunk_seam_selftest.gd`

> D33 Part 3c — the real render-seam selftest for floor-sunk DENTED marks, sibling to decal_seam_selftest.gd (3a) and half_voxel_seam_selftest.gd (3b). Rodar: godot --headless --script res://godot/scripts/tools/floor_sunk_seam_selftest.gd

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_plan_parser_recognizes_floor_sunk_case() -> void:`
- `func test_set_voxel_cell_end_to_end_picks_the_floor_composite() -> void:`
- `func test_resolve_flat_receives_the_real_zone_material_not_the_pseudo_name() -> void:`
- `func test_empty_zone_material_falls_through_to_generic() -> void:`
- `func test_no_baked_atom_falls_through_to_generic() -> void:`

---

### `floor_zone_bake_selftest.gd`

extends `SceneTree` · 524 lines

`godot/scripts/tools/floor_zone_bake_selftest.gd`

> FLOOR-BAKE-01 — floor-zone photographic ground bake selftest. Rodar: godot --headless --script res://godot/scripts/tools/floor_zone_bake_selftest.gd Mirrors roof_bake_selftest.gd's structure/rigor for the floor-zone bake feature (author-declared rectangular material zones, full-color RGB instead of grayscale-luminance-times-tint). Proves: 1. A floor_zones-only map_spec composes the SAME "ROOF|mat|fac|col|row" page family roof/ceiling uses (bake_compositor.gd deliberately never introduced a separate "FLOOR|" prefix) with a lookup entry for every folded LOCAL cell 2. resolve_flat() returns exactly the independently re-derived atom 3. PIXEL continuity + ISOTROPY at the floor's own 1024x1024 target size (not the wall/ceiling-inherited 1024x512) + full_color's WHITE modulate does not alter the composed page's raw pixel RGB (the compositor forces the modulate at TileData registration time, a draw-time multiply — never a page-pixel write) 4. Real FLOOR_ZONES_TEST map, bake ENABLED: every voxel in a declared zone carries the baked source + coords its STRUCTURE-LOCAL offset predicts (own flood-fill re-derivation, keyed on "same zone material" instead of "both roofed"); unzoned floor still resolves to the "earth" sentinel with zero anchor 5. ROTATION: building the E view puts a zone's Slab material at the correctly-rotated GU, exactly like roof's block rotation Every expectation is re-derived locally (own mirror fold, own key format, own component flood fill, own rotation math) — never read back from the code under test.

**Constants / tuning**
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `ATOM_W` = `32`
- `ATOM_H` = `36`
- `V_MARGIN` = `32`
- `FLOOR_TOP_LEVEL` = `GeometryCoords.FLOOR_TOP_LEVEL`
- `FLOOR_TARGET_H` = `1024`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_1_floor_cells_get_lookup_entries(fx: Dictionary) -> void:`
- `func test_2_resolve_flat_matches_rederived_atoms(fx: Dictionary, bake_config) -> void:`
- `func test_3_pixel_continuity_isotropy_and_full_color_modulate(fx: Dictionary) -> void:`
- `func test_4_real_map_local_keys_and_unzoned_fallback() -> void:`
- `func test_5_rotated_view_zones_follow_declared_material() -> void:`

---

### `generic_mark_seam_selftest.gd`

extends `SceneTree` · 307 lines

`godot/scripts/tools/generic_mark_seam_selftest.gd`

> D33 Part 4b — the real render-seam selftest for the generic/vector-mark fallback compositor, sibling to decal_seam_selftest.gd (3a), half_voxel_seam_selftest.gd (3b), floor_sunk_seam_selftest.gd (3c) and ceiling_carve_seam_selftest.gd (3d). Those four all stub a REAL baked atom in; this suite deliberately runs with BakeConfig OFF (the release canon — see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 4's own risk note) so every one of Part 3's branches misses by construction, proving the NEW fallback catches every shape instead of reaching the last-resort composites/-backed MATERIALS.find(). Rodar: godot --headless --script res://godot/scripts/tools/generic_mark_seam_selftest.gd

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_plan_parser_recognizes_old_flat_names() -> void:`
- `func test_flat_mark_resolves_with_bake_off() -> void:`
- `func test_flat_mark_dented_has_a_true_alpha_cut_cracked_does_not() -> void:`
- `func test_full_voxel_cracked_resolves_with_bake_off() -> void:`
- `func test_half_voxel_wall_resolves_with_bake_off() -> void:`
- `func test_half_voxel_variant_threading_is_not_collapsed() -> void:`
- `func test_floor_sunk_resolves_with_bake_off() -> void:`
- `func test_ceiling_resolves_with_bake_off_no_decal_needed() -> void:`
- `func test_composite_is_idempotent() -> void:`
- `func test_non_impact_material_is_unaffected() -> void:`

---

### `geometry_selftest.gd`

extends `SceneTree` · 234 lines

`godot/scripts/tools/geometry_selftest.gd`

> Geometry Module — Selftest: minimal validation Headless selftest Usage: godot --headless --script geometry_selftest.gd

---

### `glass_crack_selftest.gd`

extends `SceneTree` · 2048 lines

`godot/scripts/tools/glass_crack_selftest.gd`

> GLASS_MASTER_PLAN §8.1 / CRACK-01 — the CRACKED tier for glass. Rodar: python3 tools/persistent/run_selftests.py --only glass_crack §8.1 was written up as a CONTRADICTION: the art order's step 3 asked to raise `glass.json`'s `crack_factor` above 0 and add `glass` to `IMPACT_DECAL_MATERIALS`, which together make `voxel_decal_selftest` [12] demand `decal_crack_glass_{0,1,2}.png` — the per-voxel crack family G-D21 explicitly folded into the fracture SHEET. The resolution (Director, 2026-09-02): glass reaches CRACKED by the route it ALREADY has — `ShotPunchTable.damage_state_for()` returns CRACKED for a sub-breach glass hit — and NOT through the blast `crack_factor` probability path. So `crack_factor` stays 0.0, `glass` stays out of both decal lists, and the whole [12] coupling is untouched. Glass is simply the first material whose CRACKED art is a sheet, not a decal family. This suite is the guard on that resolution — it fails if a future edit "fixes" §8.1 by commissioning the decal family, and (from CRACK-01 stages B/C) it grows to pin the render and the shot-path event. What each test catches: [1] the CRACKED tier going unreachable for glass — the enum path breaking. [2] a crack DECAL FAMILY appearing for glass — in data, in the wiring lists, or on disk. [3] the fracture SHEETS (the real CRACKED art) going missing or unimported. [8] the crack coming back INSIDE glass_pane.gdshader — CRACK-02 / G-D27 took it out of the voxel because a crack drawn there inherits `dim`, `cover` and the quad seams, and no tuning survives that. [10] the sheet shearing off the voxels — the CRACK-01-B/C bug, now pinned against the SPRITE'S OWN TRANSFORM instead of a shader inverse. [11] a crack bleeding past the frame of the pane it is on. [12] G-D30's cut reading anything other than the live glass tilemap, the occupancy rows going upside down, or the dial collapsing to a boolean. [13] S-3's rebuild path acquiring side effects — a perspective flip that re-damages the pane it is only supposed to redraw. [14] a cell's cut collapsing to one shape (the cell OFFSET being dropped from the atom key), a PARTIAL cell being cut away entirely, or the cut eating the pane's slivers. [16] the opening FAMILY going malformed — an opening that does not leave the struck cell, a pooled id with no shape, a pick that stops hashing, or the SHEET's void drifting from the voxel cut (G-D34's whole point). [15] the applied hole drifting from the opening it claims to be — a cell cut that coverage() calls outside, or left whole that it calls PARTIAL — and the shards NOT SURVIVING a later render pass, which is what kept CRACK-03's rim off the screen for its entire life.

**Constants / tuning**
- `ShotPunchTableClass` = `preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")`
- `MaterialResistanceTableClass` = `preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GlassMaterialsClass` = `preload("res://godot/scripts/systems/glass_materials.gd")`
- `GlassCrackClass` = `preload("res://godot/scripts/systems/destruction/glass_crack.gd")`
- `GlassCrackSpriteClass` = `preload("res://godot/scripts/overlays/glass_crack_sprite.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `GlassOpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `GlassShatterClass` = `preload("res://godot/scripts/systems/destruction/glass_shatter.gd")`
- `GlassShardShapesClass` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `CRACK_DECAL_TEMPLATE` = `"res://ASSETS/materials/glass/decals/decal_crack_glass_%d.png"`
- `FRACTURE_TEMPLATE` = `"res://ASSETS/materials/glass/fracture_glass_%s.png"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_glass_reaches_cracked_through_the_shot_ladder() -> void:`
- `func test_glass_has_no_crack_decal_family() -> void:`
- `func test_the_fracture_sheets_are_the_cracked_art() -> void:`
- `func test_plan_pane_crack_marks_standing_glass_in_radius() -> void:`
- `func test_plan_pane_crack_skips_destroyed_and_banded_frame() -> void:`
- `func test_plan_pane_crack_run_axis_follows_the_face() -> void:`
- `func test_wide_for_blowout_splits_the_arsenal() -> void:`
- `func test_the_glass_shaders_split_the_crack_out() -> void:`
- `func test_apply_spawns_a_sprite_and_gd24_crosses() -> void:`

---

### `glass_fall_selftest.gd`

extends `SceneTree` · 352 lines

`godot/scripts/tools/glass_fall_selftest.gd`

> GLASS_MASTER_PLAN §5.4 / §18.5 — GlassFall selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_fall G-D16a's claim is that ONE rule — fall to the first horizontal surface below — produces every case the Director named without a branch per case. G4-4 adds a second: the shard first SCATTERS a few cells from its own column (G-D41), and a grenade's shockwave BIASES that scatter downrange (G-D42). So the tests are those cases, on the same function, with nothing changing but the geometry underneath and the `impulse` on top: [1] a pane over bare floor            -> the base pile, count preserved [2] the same pane over a counter      -> the counter top, not the floor [3] a skylight two storeys up         -> the floor below, a whole storey down [4] glass under glass                 -> falls THROUGH, does not rest on it [5] nothing underneath                -> NO_LANDING, dropped, not faked [6] scatter conserves and concentrates -> 24 shards, a band near the column [7] the scatter shape                 -> mostly 0, a tail to 3, never past it [8] the shockwave biases downrange    -> the mean shifts, some clear the tail [9] lift widens the scatter           -> SYNTHETIC, no real map exercises it [10] determinism                       -> two identical plans, byte for byte

**Constants / tuning**
- `GlassFallClass` = `preload("res://godot/scripts/systems/destruction/glass_fall.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_pane_over_bare_floor_piles_at_the_base() -> void:`
- `func test_a_counter_catches_the_shards_before_the_floor() -> void:`
- `func test_a_skylight_drops_a_whole_storey() -> void:`
- `func test_glass_is_not_a_surface() -> void:`
- `func test_nothing_underneath_is_no_landing() -> void:`
- `func test_scatter_conserves_and_concentrates() -> void:`
- `func test_the_scatter_shape() -> void:`
- `func test_the_shockwave_biases_downrange() -> void:`
- `func test_lift_widens_the_scatter() -> void:`
- `func test_determinism() -> void:`

---

### `glass_remnant_atom_capture.gd`

extends `SceneTree` · 119 lines

`godot/scripts/tools/glass_remnant_atom_capture.gd`

> GLASS G4-3 — photograph the REMNANT ATOMS, off the production cut path. Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \ --script godot/scripts/tools/glass_remnant_atom_capture.gd ⚠️ IT CALLS `VoxelRenderer._build_glass_pane_atom()` AND THE REAL CUT HELPERS, not a re-implementation of them. What this sheet shows is the image that would be uploaded to a TileSetAtlasSource on a real break — the same pixels, at the same 32 x 36 the board draws. The leftmost column is the UNCUT atom, and it is the point of the sheet: the claim being checked is "a remnant is not the same little square", so the square has to be next to it.

**Constants / tuning**
- `RendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `OUT_PATH` = `"res://Screenshots/history/glass_remnant_atoms_2026-09-05.png"`
- `AW` = `32`
- `AH` = `36`
- `ZOOM` = `5`
- `PAD` = `6`
- `BG` = `Color(0.086, 0.094, 0.110, 1.0)`
- `GUIDE` = `Color(0.20, 0.22, 0.25, 1.0)`

---

### `glass_rim_capture.gd`

extends `SceneTree` · 250 lines

`godot/scripts/tools/glass_rim_capture.gd`

> GLASS CRACK-04 — RENDER THE FAMILY OF OPENINGS FROM THE REAL ATOMS. Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \ --script godot/scripts/tools/glass_rim_capture.gd One panel per member of `GlassOpening.FAMILY`, each a real pierced pane with that opening applied through the real `refresh_glass_rims()`. This is the picture a shape decision gets made on. ⚠️ WHY THIS EXISTS AS A COMMITTED TOOL AND NOT A SCRATCH SCRIPT. `glass_rim_shape_options_2026-09-02.png` — the picture G-D32 was ratified from — was made by an ad-hoc script that was never committed and no longer exists. It was captured at 04:11 on 2026-09-03, **four minutes before `330d285d` cut the neighbour count from 8 to 4**, so the silhouette it shows is one the build has not made since. A picture that cannot be re-made is a citation that decays (the same lesson the `auto_*.png` rotation already taught this project). ⚠️ IT COMPOSITES ATOMS, IT DOES NOT BOOT THE GAME. That is the point: the question is what SILHOUETTE an opening cuts, and a play-zoom screenshot cannot answer it — the difference between two openings is tenths of a voxel there. Compositing runs headless, deterministically, in under a second. The geometry is the atom's own, not a re-derivation: a SW face's diamond edge runs `vw -> vs`, so the RUN step in canvas is (16, 8), and a level is `VOXEL_STEP_PX` straight up. Those two vectors ARE the pane's basis — the same one `GlassCrackSprite` bakes into its Transform2D.

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `GlassOpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `RUNS` = `15`
- `LEVELS` = `13`
- `OUT_DIR` = `"res://Screenshots/history"`
- `BG` = `Color(0.16, 0.17, 0.22, 1.0)`
- `GLASS_FLAT` = `Color(1.0, 0.93, 0.20, 1.0)`

---

### `glass_shard_shapes_capture.gd`

extends `SceneTree` · 147 lines

`godot/scripts/tools/glass_shard_shapes_capture.gd`

> GLASS G4-1 — photograph the shard shape family, from the SHIPPED data. Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \ --script godot/scripts/tools/glass_shard_shapes_capture.gd ⚠️ IT RASTERISES `GlassShardShapes` ITSELF, never a copy of the numbers. A preview drawn from a transcription would be a picture of a second family that happens to look similar, and the whole point of a true-size check is that it is the thing that ships. Three bands, because they answer different questions: 1. the five free members, magnified — what each shape IS 2. every member x every anchor placement (G-D39) — how it hangs 3. TRUE SIZE — the only band that decides anything. A voxel's face is 20 px tall (`GeometryCoords.VOXEL_STEP_PX`), so a shard at G-D44's band is 10 to 20 px, and detail that reads beautifully in band 1 dissolves here.

**Constants / tuning**
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `OUT_PATH` = `"res://Screenshots/history/glass_shard_family_2026-09-05.png"`
- `BG` = `Color(0.086, 0.094, 0.110)`
- `CELL` = `Color(0.172, 0.184, 0.207)`
- `CELL_EDGE` = `Color(0.255, 0.274, 0.309)`
- `GLASS` = `Color(0.769, 0.910, 0.957)`
- `BRICK` = `Color(0.659, 0.361, 0.290)`
- `LABEL` = `Color(0.55, 0.58, 0.63)`
- `STUDY_PX` = `120`
- `TRUE_PX` = `20`

---

### `glass_shard_shapes_selftest.gd`

extends `SceneTree` · 554 lines

`godot/scripts/tools/glass_shard_shapes_selftest.gd`

> GLASS G4-1 / G-D38 + G-D39 + G-D44 — GlassShardShapes selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_shard_shapes [1] G-D44's size law, member by member, with the measured numbers printed [2] every member is ANGULAR — straight chords, not a round blob [3] the size law has TEETH: a filled cell is rejected by it [4] the anchored form stays in its cell, touches its edge, and is FLAT there [5] a corner anchor is cut on BOTH edges, not on a 45 degree plane [6] the flop is a different placement, not the same polygon twice [7] every member is REACHABLE by pick() [8] the family shares no member with GlassOpening [9] an empty anchor mask invents no placement

**Constants / tuning**
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `OpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `ShardFieldClass` = `preload("res://godot/scripts/overlays/shard_field.gd")`
- `RainClass` = `preload("res://godot/scripts/overlays/glass_rain_overlay.gd")`
- `EPS` = `0.0005`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_size_law() -> void:`
- `func test_members_are_angular() -> void:`
- `func test_the_size_law_has_teeth() -> void:`
- `func test_anchored_form_is_flush_and_flat() -> void:`
- `func test_a_corner_is_cut_on_both_edges() -> void:`
- `func test_the_flop_is_a_different_placement() -> void:`
- `func test_every_member_is_reachable() -> void:`
- `func test_no_member_is_shared_with_glassopening() -> void:`
- `func test_an_empty_mask_invents_nothing() -> void:`
- `func test_the_atlas_holds_five_distinct_cells() -> void:`
- `func test_the_field_writes_the_buffer_it_claims() -> void:`
- `func test_the_rain_ages_in_frames_and_frees_itself() -> void:`

---

### `glass_shatter_selftest.gd`

extends `SceneTree` · 1328 lines

`godot/scripts/tools/glass_shatter_selftest.gd`

> GLASS_MASTER_PLAN §5.1 / G-D11 — GlassShatter selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_shatter Pins `GlassShatter.p_shatter()` against the Director-approved target distribution BY READING THE SHIPPED WEAPON JSONS (res://weapons/*.json), the same discipline `test_no_shipped_weapon_reaches_the_cascade` uses for the cascade ceiling: a later balance edit to a weapon's `punch` fails this suite rather than silently turning a pistol into a pane-breaker. What each test catches: 1. The curve drifting off the target table for any shipped round. 2. The shotgun's 24-pellet compound odds drifting off ~38%. 3. The flat bottom eroding — a weak hit gaining a shatter chance. 4. The ceiling reaching 1.0 — a common round GUARANTEEING a full shatter (only a primed armored pane may, G-D15). 5. Monotonicity — more punch must never mean less shatter chance. 6. The roll being deterministic and honouring the probability.

**Constants / tuning**
- `GlassShatterClass` = `preload("res://godot/scripts/systems/destruction/glass_shatter.gd")`
- `ShotPunchTableClass` = `preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")`
- `WeaponDefClass` = `preload("res://godot/scripts/systems/destruction/weapon_def.gd")`
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`
- `WorldDeltaClass` = `preload("res://godot/scripts/systems/prediction/world_delta.gd")`
- `BombDefClass` = `preload("res://godot/scripts/systems/destruction/bomb_def.gd")`
- `TARGETS` = `{ "smg": 0.00, "pistol": 0.025, "revolver": 0.16, "assault_rifle": 0.44, "sniper_rifle": 0.81, }`
- `SINGLE_TOL` = `0.06`
- `PELLET_TARGET` = `0.02`
- `BLAST_TARGET` = `0.38`
- `BLAST_TOL` = `0.08`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_region_radius_scales_with_punch() -> void:`
- `func test_small_pane_is_binary_with_remnants() -> void:`
- `func test_big_pane_partial_then_full() -> void:`
- `func test_remnant_floor_never_leaves_zero_border() -> void:`
- `func test_blast_glass_punch_reliable_inside_zero_outside() -> void:`
- `func test_banded_pane_never_destroys_its_own_frame_bands() -> void:`
- `func test_unanchored_pane_keeps_nothing() -> void:`
- `func test_layer_falloff_weakens_each_successive_pane() -> void:`
- `func test_local_hole_does_not_wall_off_the_flood() -> void:`
- `func test_armored_takes_the_whole_pane_and_leaves_fewer_remnants() -> void:`
- `func test_indestructible_never_breaks_and_stops_the_round() -> void:`
- `func test_glass_never_dents() -> void:`
- `func test_per_placement_class_overrides_the_material() -> void:`
- `func test_only_rifle_class_pierces_armored_glass() -> void:`
- `func test_cook_proposes_the_opening_and_only_commit_claims_it() -> void:`

---

### `glass_transparency_selftest.gd`

extends `SceneTree` · 670 lines

`godot/scripts/tools/glass_transparency_selftest.gd`

> GLASS_MASTER_PLAN G1 — glass transparency routing selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_transparency G1 moves glass cells off the opaque `_layers` and onto their own MUL + ADD blend sublayers (glass_shading.gdshaderinc), so the background shows through (G-D1). This suite is the round-trip proof of that routing on the REAL `_set_voxel_cell()` seam every render path funnels through — not a fixture that only exercises the happy branch. GLASS G1 GEOMETRY (2026-08-31) — it also pins the face-culling rule: an interior voxel gets the main-only atom (mask 0), the frontmost column gets main+side (mask 1), the top level main+top (mask 2), and `_glass_face_mask()` returns those bits. 16 atom sources (4 faces × 4 masks), all distinct. What each test catches, worst first: 1. A glass voxel that STILL lands on the opaque layer — the pane would be a solid cube again, G1 undone with no error. 2. A glass sublayer built for a level that has no glass — a wasted layer pair, and a sign the lazy-build guard slipped. 3. A concrete voxel that got routed to the glass sublayers — the one test that proves the `material_name == "glass"` gate is not catching everything. 4. A destroyed glass voxel left drawn on a sublayer — the pane keeps a shard that was shot out. 5. Intact glass dropped from `build_occupancy()` — the light field would stop seeing the pane the moment G1 landed (this suite pins it BLOCKS light exactly as before; whether it should transmit is a later call).

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

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

### `half_thickness_selftest.gd`

extends `SceneTree` · 307 lines

`godot/scripts/tools/half_thickness_selftest.gd`

> MATERIALS_MASTER_PLAN M3-2b — half-thickness elements. Rodar: python3 tools/persistent/run_selftests.py --only half_thickness A normal wall is two voxels thick (D16): one storey-face on each of the two adjacent GUs. Fabric, cardboard, glass and plywood are HALF thickness — one face only. A glass window covers one face and leaves the opposite face empty inside the opening, which is what gives the reveal its depth. What this suite exists to catch, in order of how badly each would hurt: 1. THE CANONICALISATION TRAP. `Edge._init()` SWAPS gu_a and gu_b when the face points NW or NE. So a boolean "side_a" on the mapfile would mean different things for different walls depending on which way the author drew them — correct at the author's end, wrong after a normalisation nobody remembers. The side must be an ABSOLUTE GU CELL, and test 1 is the proof that it survives the swap where a boolean would not. 2. Exactly one slice is BORN. Not two-then-destroy-one: a DESTROYED voxel is a hole with soot and a history, an ABSENT one is geometry that never existed, and every census, D24's soot-from-absence derivation and PassageQuery read the difference. 3. The consumers tolerate a missing sibling — the shot ladder, the passage query, and the junction resolver, each of which reaches for "the other side" in its own way.

**Constants / tuning**
- `PassageQueryClass` = `preload("res://godot/scripts/geometry/passage_query.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_absolute_cell_survives_the_canonicalisation_swap() -> void:`
- `func test_only_one_slice_is_born() -> void:`
- `func test_full_thickness_is_unchanged_by_default() -> void:`
- `func test_sibling_lookup_returns_null_cleanly() -> void:`
- `func test_point_impact_terminates_without_a_sibling() -> void:`
- `func test_passage_opens_on_the_only_face() -> void:`
- `func test_junction_resolver_survives_a_half_thickness_edge() -> void:`

---

### `half_voxel_compositor_equality_selftest.gd`

extends `SceneTree` · 263 lines

`godot/scripts/tools/half_voxel_compositor_equality_selftest.gd`

> D33 Parts 3b/3c/3d — HalfVoxelCompositor equality proof, same discipline as Part 2's decal_compositor_equality_selftest.gd: compare the GDScript port against a reference built by the REAL Python function it ports (generate_voxel.py's generate_half_voxel()/generate_dented_voxel(), plus compose_decal_voxel() for the full real pipeline where a decal exists), on fixtures neither side generates itself: godot/scripts/tools/fixtures/d33_part3b/{atom,decal}.png                — wall inputs godot/scripts/tools/fixtures/d33_part3b/half_{left,right}.png           — wall mask-only reference godot/scripts/tools/fixtures/d33_part3b/composited_{left,right}.png     — wall mask + decal reference godot/scripts/tools/fixtures/d33_part3c/{atom,decal}.png                — floor inputs godot/scripts/tools/fixtures/d33_part3c/half_top.png                    — floor mask-only reference godot/scripts/tools/fixtures/d33_part3c/composited_top.png              — floor mask + decal reference godot/scripts/tools/fixtures/d33_part3d/atom.png                       — ceiling input (no decal) godot/scripts/tools/fixtures/d33_part3d/bottom.png                      — ceiling carve reference (produced by tools/asset_generation/d33_part3{b,c,d}_fixture_gen.py). Rodar: godot --headless --script res://godot/scripts/tools/half_voxel_compositor_equality_selftest.gd

**Constants / tuning**
- `HalfVoxelCompositorClass` = `preload("res://godot/scripts/geometry/half_voxel_compositor.gd")`
- `DecalCompositorClass` = `preload("res://godot/scripts/geometry/decal_compositor.gd")`
- `FIXTURE_DIR` = `"res://godot/scripts/tools/fixtures/d33_part3b/"`
- `FLOOR_FIXTURE_DIR` = `"res://godot/scripts/tools/fixtures/d33_part3c/"`
- `CEILING_FIXTURE_DIR` = `"res://godot/scripts/tools/fixtures/d33_part3d/"`
- `CUT_FILL` = `Color(140.0 / 255.0, 136.0 / 255.0, 129.0 / 255.0, 1.0)`

---

### `half_voxel_seam_selftest.gd`

extends `SceneTree` · 268 lines

`godot/scripts/tools/half_voxel_seam_selftest.gd`

> D33 Part 3b — the real render-seam selftest for half-voxel DENTED marks, sibling to decal_seam_selftest.gd (Part 3a, full-voxel CRACKED). Rodar: godot --headless --script res://godot/scripts/tools/half_voxel_seam_selftest.gd

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `BakedTileLookupClass` = `preload("res://godot/scripts/systems/baked_tile_lookup.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_plan_parser_recognizes_dented_wall_cases() -> void:`
- `func test_flat_material_side_color_is_cached_and_nonwhite() -> void:`
- `func test_set_voxel_cell_end_to_end_picks_the_half_voxel_composite() -> void:`
- `func test_cracked_still_goes_through_full_voxel_path_not_half() -> void:`
- `func test_floor_and_ceiling_dented_are_unaffected() -> void:`
- `func test_no_baked_atom_falls_through_to_generic() -> void:`

---

### `input_controller_selftest.gd`

extends `SceneTree` · 275 lines

`godot/scripts/tools/input_controller_selftest.gd`

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

### `iso_projection_selftest.gd`

extends `SceneTree` · 447 lines

`godot/scripts/tools/iso_projection_selftest.gd`

> IsoProjection selftest — the aiming overlays' geometry, checked against the REAL TileSet instead of against itself. Run: python3 tools/persistent/run_selftests.py --only iso_projection_selftest Why this file exists. T-BUBBLE's first pass sized the aim bubble with `max_ring * 112.0 * 3.0`, drew it as a circle over a 2:1 perimeter ellipse, and clamped the cursor with a third shape again. Nothing was wrong in a way a compiler could see; it was wrong in a way only the screen showed. Every claim IsoProjection makes is therefore asserted here, and test [1] asserts the two horizontal basis vectors against `tileset_blocks.tres` itself — a self-comparison would pass no matter what the constants said.

**Constants / tuning**
- `TILESET_PATH` = `"res://godot/resources/tilesets/tileset_blocks.tres"`
- `EPS` = `0.0001`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_basis_matches_real_tileset() -> void:`
- `func test_ellipses_are_axis_aligned() -> void:`
- `func test_floor_ellipse_is_two_to_one() -> void:`
- `func test_dome_is_a_real_hemisphere() -> void:`
- `func test_arc_endpoints_seam_exactly() -> void:`
- `func test_projection_preserves_grid_distance() -> void:`
- `func test_dome_covers_three_by_three_gu() -> void:`
- `func test_throw_perimeter_lands_on_cell_centres() -> void:`
- `func test_throw_arc_goes_up() -> void:`
- `func test_throw_arc_is_ballistic() -> void:`
- `func test_silhouette_great_circle() -> void:`

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

### `mapfile_roundtrip_selftest.gd`

extends `SceneTree` · 322 lines

`godot/scripts/tools/mapfile_roundtrip_selftest.gd`

> mapfile_roundtrip_test.gd — Comprehensive round-trip and migration testing Tests: 1. Basic round-trip: save spec -> load -> verify structural equality 2. Tolerant round-trip: unknown section preservation (M3) 3. Migration RED (missing migration fails loudly) + GREEN (migration present succeeds)

**Public vars**
- `var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")`
- `var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")`
- `var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")`

---

### `material_reform_selftest.gd`

extends `SceneTree` · 493 lines

`godot/scripts/tools/material_reform_selftest.gd`

> E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a, D19/D20/D21, 2026-08-06). Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd Proves the two halves of the reform independently: 1. BEHAVIOR is unified — one row per material (MaterialRegistry + MaterialResistanceTable), the old duplicate `ground_concrete` row is gone, not merely shadowed. 2. RENDERING follows the MATERIAL, not the surface — D34/E-SEAM-01 (Director, 2026-08-08) **reversed D20's original answer here.** D20 sent every floor down the photographic `slab_` path, so a concrete floor and a concrete wall were literally different art and could never read as the same material. The rule now: `has_facade == true` -> the floor bakes through the SAME `facade_<id>` its wall and roof do (grayscale + multiply); `has_facade == false` -> the photographic `slab_<id>` exception, kept on purpose for organic ground. Tests 3-5 below assert the new contract; they asserted the opposite before, and were rewritten rather than relaxed. 3. The projection that made the merge free — D34 extends a 1024x512 wall facade to the isotropic 1024x1024 a horizontal surface addresses by MIRRORED VERTICAL REPEAT, never by resize (tests 6-7). Every expectation is computed independently (own expected values), never read back from the code under test.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `MaterialResistanceTableClass` = `preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")`
- `BakePolicyClass` = `preload("res://godot/scripts/systems/bake_policy.gd")`
- `BakeCompositorClass` = `preload("res://godot/scripts/systems/bake_compositor.gd")`
- `TextureResolverClass` = `preload("res://godot/scripts/systems/texture_resolver.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_6_horizontal_plane_is_mirrored_not_stretched() -> void:`
- `func test_7_roof_and_floor_specs_merge_their_cells() -> void:`
- `func test_8_earth_is_a_buildable_material() -> void:`

---

### `material_tree_selftest.gd`

extends `SceneTree` · 202 lines

`godot/scripts/tools/material_tree_selftest.gd`

> ASSET_TREE_REFORM — the invariant the per-material tree makes possible. Rodar: python3 tools/persistent/run_selftests.py --only material_tree WHY THIS TEST EXISTS, stated as the bug it would have caught. Before 2026-08-21 a material's art was scattered across four flat directories, so "does concrete have everything it needs" could only be answered by grepping four folders and knowing which files each one owed. `glass` sat in `BASE_MATERIALS` and NOT in `BakeCompositor.VOXEL_MATERIALS` for months and nothing saw it, because no glass block had ever been placed — the moment one was, B6 fired with `voxel_glass.png` on disk the whole time. One folder per material turns that into a structural question, and this is the test that asks it: 1. every REGISTERED material has a folder; 2. every FOLDER is a registered material (no orphan art nothing can reach); 3. every material that claims `has_facade` has its facade file; 4. every material in `IMPACT_DECAL_MATERIALS` has a complete decal family. Deliberately reads the REAL tree and the REAL registry, not a fixture: the property under test is that the two agree on this machine, right now.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `MATERIALS_ROOT` = `"res://ASSETS/materials"`
- `GENERIC_DIR` = `"_generic"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_every_registered_material_has_a_folder(registered: Array, folders: Array[String]) -> void:`
- `func test_every_folder_is_a_registered_material(registered: Array, folders: Array[String]) -> void:`
- `func test_facade_materials_have_their_facade(registry, registered: Array) -> void:`
- `func test_decal_materials_have_a_complete_family() -> void:`

---

### `negative_storey_selftest.gd`

extends `SceneTree` · 260 lines

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

### `occlusion_set_selftest.gd`

extends `SceneTree` · 313 lines

`godot/scripts/tools/occlusion_set_selftest.gd`

> OCC-01: Occlusion Set — Headless Test Usage: godot --headless --script godot/scripts/tools/occlusion_set_selftest.gd TEST-DEBT-01 (2026-09-01): renamed from `occlusion_set_test.gd` into the `*_selftest.gd` glob, so `run_selftests.py` — the arbiter — actually runs it. The `class_name OcclusionSetTest` it used to declare went with the rename: no caller ever used it, no sibling selftest declares one, and a global class name on a `--script` entry point only buys a "hides a global script class" parse error the moment the file moves.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `OcclusionSetMod` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `FIXTURE_LEVELS` = `6`

---

### `panel_base_selftest.gd`

extends `SceneTree` · 177 lines

`godot/scripts/tools/panel_base_selftest.gd`

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

### `passage_query_selftest.gd`

extends `SceneTree` · 405 lines

`godot/scripts/tools/passage_query_selftest.gd`

> MATERIALS_MASTER_PLAN M3-2 — PassageQuery selftest. Rodar: python3 tools/persistent/run_selftests.py --only passage_query Synthetic fixtures only (a hand-built Edge through SliceGenerator), the same discipline as blast_calculator_selftest.gd. What it pins is the RULE, which is the part that has already been read wrong three times: - the unit that stacks is the STOREY, not the voxel level (M3-0); - BOTH storey-faces of a pair must be clear, not either one; - STANDING needs two STACKED storeys, not two clear ones anywhere; - "both" means "every face that EXISTS", which is what half-thickness elements will need (M3-2b) and what makes this query survive them.

**Constants / tuning**
- `PassageQueryClass` = `preload("res://godot/scripts/geometry/passage_query.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_intact_wall_is_no_passage() -> void:`
- `func test_one_side_clear_is_not_a_passage() -> void:`
- `func test_both_sides_of_one_storey_is_crouch() -> void:`
- `func test_two_stacked_storeys_is_standing() -> void:`
- `func test_two_unstacked_storeys_is_only_crouch() -> void:`
- `func test_incomplete_destruction_still_opens_a_passage() -> void:`
- `func test_the_criterion_is_the_amount_not_the_shape() -> void:`
- `func test_survivors_inside_the_opening_are_scenery() -> void:`
- `func test_standing_needs_the_two_runs_to_OVERLAP() -> void:`
- `func test_half_thickness_edge_opens_on_its_only_face() -> void:`
- `func test_clear_storeys_reports_where_ascending() -> void:`
- `func test_glass_blocks_the_body_until_it_breaks() -> void:`

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

### `prop_01_selftest.gd`

extends `Node` · 405 lines

`godot/scripts/tools/prop_01_selftest.gd`

> PROP-01 Acceptance Tests Tests the PropDef/PropRegistry/voxel prop rendering system TEST-DEBT-03 (2026-09-01) — RUNS AS A SCENE, not as a `--script` SceneTree. That is the whole point: criterion 7 reaches `MapCatalog.get_spec()`, which routes through `Registries.ensure_file_map_source()`, and `Registries` is an AUTOLOAD. Godot registers autoload names as parse-time globals and adds their nodes only when a MAIN SCENE runs — a `--script` run does neither, so this file used to fail to load outright (`Compile Error: Identifier not found: Registries` from map_catalog.gd) and criterion 7 could only ever SKIP itself. Launched as `res://godot/scripts/tools/prop_01_selftest.tscn` the autoloads are real, and run_selftests.py knows to invoke a `*_selftest.tscn` that way. Measured: the probe that settled it printed `VersionInfo global: true`.

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

### `resolver_hardening_selftest.gd`

extends `SceneTree` · 527 lines

`godot/scripts/tools/resolver_hardening_selftest.gd`

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

extends `SceneTree` · 495 lines

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

extends `SceneTree` · 269 lines

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

extends `SceneTree` · 325 lines

`godot/scripts/tools/roof_slab_selftest.gd`

> DESTRUCTION_MASTER_PLAN — roof/ceiling ("laje") geometry selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_slab_selftest.gd Proves the "2+ levels, ALL destructible, existing wall material" roof model this session's Director asked for: unlike the floor (1 destructible Slab + 7 fixed non-Slab levels, D13), a roof is N independent Slabs, one per level, each fully destructible — falls out of calling the EXISTING SlabGenerator N times, zero new geometry classes needed. No bake system involved yet (Director's call: geometry first, bake as a later experiment) — render_slab_solid() places one fixed wall material per voxel, the same way render_block() already does for a whole block, just through Slab/Voxel so every level is independently dirty-tracked.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `CEILING_LEVEL` = `GeometryCoordsClass.PLAYABLE_LEVEL + GeometryCoordsClass.LEVELS_PER_STOREY`

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

### `s1_normal_compression_spike.gd`

extends `SceneTree` · 437 lines

`godot/scripts/tools/s1_normal_compression_spike.gd`

> CHARACTER_MASTER_PLAN Part 0 / S1 — do normal maps survive mobile texture compression? THE QUESTION. D17's entire relight technique reads a baked normal map per pixel. Lossy VRAM compression corrupts normals in a way that surfaces as WRONG LIGHTING rather than as visible blur — so it can pass a "looks fine" eyeball check and still be broken. If it does not survive, the character's normal maps need an uncompressed budget, which changes CHARACTER_MASTER_PLAN §8's RAM arithmetic materially. WHAT IS MEASURED. Not the normal maps — the LIT OUTPUT, through the real `flat_normal_relight.gdshader`, because what matters is what the player sees. Source frames are the shotgun's real bake (120 colour + 120 normal pairs), produced by actor_frame_bake_spike.gd at the real camera convention. No synthetic fixture: this is the actual art the actual shader consumes. THE PIXEL-DIFF GATE IS EARNED, NOT ASSUMED (CLAUDE.md). Every run first renders the SAME uncompressed config twice and diffs it. If that is not 0, the harness is non-deterministic and every other number in the run is noise wearing a number — the script says so and stops trusting itself. This project measured 36 733 pixels of difference between two identical captures on 2026-08-09; the discipline exists because it was paid for. THE SECOND VALIDITY GATE (D22's trap). A light direction that happens to back-light the object produces a nearly flat lit image, and a diff against a flat image is ~0 for the WRONG REASON — it measures "nothing was lit", not "compression is safe". So each light direction reports the reference image's own luma spread, and any direction that fails to produce real directional variation is reported as INVALID rather than as a pass. Grazing light is included deliberately: normal error is amplified at grazing angles, so a technique that survives head-on light can still fail there. Must run WINDOWED (real GPU rasterizer). Run via: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/s1_normal_compression_spike.gd

**Constants / tuning**
- `FRAMES_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/"`
- `EVIDENCE_DIR` = `"res://Screenshots/history/"`
- `TEST_FRAMES` = `[0, 30, 60, 90]`
- `LIGHT_DIRS` = `[ {"name": "front", "dir": Vector3(0.0, 0.0, 1.0)}, {"name": "side45", "dir": Vector3(0.707, 0.0, 0.707)}, {"name": "grazing", "dir": Vector3(0.95, 0.10, 0.30)}, ]`
- `ALPHA_CUTOFF` = `102`

---

### `s2_resident_memory_probe.gd`

extends `SceneTree` · 127 lines

`godot/scripts/tools/s2_resident_memory_probe.gd`

> CHARACTER_MASTER_PLAN §8 / ACTOR §7 #28 — measures the RESIDENT texture cost of a character frame set, instead of assuming it. WHY THIS EXISTS. S1 proved the relight technique survives ASTC compression. It did NOT measure how much memory a character costs, and it did not measure headroom — those are different questions, and §7 #28 still lists the resident frame count as unmeasured. This probe closes the arithmetic half of it with real compressed byte counts read out of Godot, not a spec sheet. WHAT IT DOES NOT ANSWER. Device headroom. Knowing a set costs N MB says nothing about what a given phone has spare alongside the voxel tilemap, the atlas pages and the engine itself. That needs an on-device run, and this probe deliberately does not pretend otherwise. THE RESIDENT SET IS NOT THE CATALOG (D42). The multiplicative axes are mutually exclusive at runtime: the player wears one archetype in one silhouette class. Guards are the same frames under a different tint (D41), so they cost nothing extra in texture memory. RAM holds one loadout; the rest of the catalog is a disk cost. Run: godot --path . --position 4000,4000 \ --script res://godot/scripts/tools/s2_resident_memory_probe.gd

**Constants / tuning**
- `CANVASES` = `[ Vector2i(96, 128), Vector2i(128, 160), Vector2i(160, 192), Vector2i(192, 256), ]`
- `YAW_OPTIONS` = `[4, 8, 16, 32, 48, 64]`
- `POSE_COUNT` = `8`
- `TRANSITION_MULTIPLIER` = `3.0`

---

### `save_state_selftest.gd`

extends `SceneTree` · 182 lines

`godot/scripts/tools/save_state_selftest.gd`

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

extends `SceneTree` · 303 lines

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
- `func test_floor_dent_places_carved_asset_on_both_branches() -> void:`

---

### `slice_geometry_selftest.gd`

extends `SceneTree` · 257 lines

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
- `VOXEL_BASE_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/voxels/materials/voxel_"`
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

### `tint_baked_atom_selftest.gd`

extends `SceneTree` · 152 lines

`godot/scripts/tools/tint_baked_atom_selftest.gd`

> PERF-01 — proves VoxelRenderer._tint_image_rgb() (byte-buffer multiply) matches the get_pixel()/set_pixel() loop it replaced inside _tint_baked_atom(), within MAX_CHANNEL_DIFF_TOLERANCE. Tolerance is MEASURED here, not assumed (same discipline as the D33 Part 2 equality selftests, decal_compositor_equality_selftest.gd): every modulate <= 1.0 (no clamping needed) round-trips byte-for-byte, 0/1152 pixels differ. Only a modulate > 1.0 — which pushes byte*modulate through _tint_image_rgb()'s clampf(...,0.0,1.0) branch — shows a ±1/255 diff on a real fraction of pixels (measured 2026-08-04: 228/1152). Root cause, confirmed by reproducing the exact divide/multiply/clamp/scale sequence get_pixel()+set_pixel() run and STILL seeing the same 228 mismatches: GDScript's float is 64-bit; Godot's internal Color->byte quantization (engine-side, C++) is 32-bit. The identical real-valued expression can round to a different integer on either side of that precision boundary when the product lands within one ULP of an exact integer — an unavoidable consequence of computing the same math at two different float widths, not a logic error in either implementation. Rodar: godot --headless --script res://godot/scripts/tools/tint_baked_atom_selftest.gd

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `MAX_CHANNEL_DIFF_TOLERANCE` = `1`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_case(label: String, modulate: Color) -> void:`
- `func test_white_fast_path() -> void:`

---

### `version_info_selftest.gd`

extends `Node` · 74 lines

`godot/scripts/tools/version_info_selftest.gd`

> VERSION-01 Test: VersionInfo singleton initialization TEST-DEBT-03 (2026-09-01) — RUNS AS A SCENE, not as a `--script` SceneTree. `VersionInfo` is an autoload, and Godot registers autoload names as parse-time globals (and adds their nodes) only when a MAIN SCENE runs. Under `--script` this file did not merely fail its assertions, it failed to LOAD: "Compile Error: Identifier not found: VersionInfo" — so the one test of the version singleton had never run since the day it was written. Launched as `res://godot/scripts/tools/version_info_selftest.tscn` the autoload is real; run_selftests.py knows to invoke a `*_selftest.tscn` that way.

---

### `voxel_decal_selftest.gd`

extends `SceneTree` · 659 lines

`godot/scripts/tools/voxel_decal_selftest.gd`

> DESTRUCTION_MASTER_PLAN D32 — damage-decal placement selftest. Rodar: godot --headless --script res://godot/scripts/tools/voxel_decal_selftest.gd What this suite exists to catch, stated as the bug it would have caught: before D32 every firearm hit on a wall painted its bullet hole on the voxel's TOP diamond, because apply_point_impact() never resolved which face was struck and the art had the mark baked on the top face. Nothing failed — it just rendered wrong. So the assertions here are about WHICH NAME a given (tier, cause, side) resolves to, and about every one of those names having a real asset behind it, rather than about the pixels. Deliberately NOT asserted here: what the decal looks like. That is verified on the asset side (the generator's own geometry checks) and by real capture.

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `MANIFEST_PATH` = `"res://ASSETS/materials/manifest.json"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_manifest_agrees_with_the_renderer() -> void:`
- `func test_bullet_marks_the_struck_lateral_face_only() -> void:`
- `func test_cracked_is_whole_voxel_for_a_blast() -> void:`
- `func test_ceiling_carve_is_variantless() -> void:`
- `func test_floor_dent_uses_the_real_material_art() -> void:`
- `func test_variant_selects_distinct_names() -> void:`
- `func test_unknown_material_falls_back_instead_of_composing_a_missing_name() -> void:`
- `func test_shooter_gu_resolves_a_real_side() -> void:`

---

### `voxel_face_separation_selftest.gd`

extends `SceneTree` · 235 lines

`godot/scripts/tools/voxel_face_separation_selftest.gd`

> FACE-READ-02 selftest — the "never three identical faces" guarantee. Run: godot --headless --script res://godot/scripts/tools/voxel_face_separation_selftest.gd Director, 2026-08-01: *"forçar a fuligem de destruição e tiros a seguir o mesmo princípio de nunca deixar um voxel existir com as 3 faces totalmente iguais [...] garantir que as 3 faces tem uma micro diferença."* The property under test is a CONTRACT BETWEEN TWO FILES that are tuned independently: the shader's per-face constants (godot/shaders/voxel_face_shading.gdshader) and the darkening canon they have to stay separable against (VoxelRenderer.bucket_luminance and its FLOOR_DEPTH_DIM). Either side can be retuned in good faith and silently destroy the guarantee — soot to 0.20 is exactly what broke it originally — so both sides are read from their real owners here, and the shader constants are PARSED from the shader file rather than copied, so a value changed there fails this test instead of drifting. FACE-SOOT-01 (2026-08-01) moved soot OUT of the light bucket and into this same shader, as a per-face multiplier (`soot_face_mult`). The scan follows it: the incoming colour is now bucket x depth only, and every one of the 64 per-face ring COMBINATIONS is swept, because two faces at different soot rings are a collapse risk this test could not previously even express. A headless run has no rasteriser, so this reproduces the shader's arithmetic rather than sampling real pixels: quantised 8-bit output for each of the three faces. That is a deliberate, stated substitution — the real-pixel evidence for this feature is the capture cited in the session record.

**Constants / tuning**
- `VoxelRendererClass` = `preload("res://godot/scripts/geometry/voxel_renderer.gd")`
- `VoxelLightFieldClass` = `preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")`
- `SHADER_PATH` = `"res://godot/shaders/voxel_face_shading.gdshader"`
- `BLACK_CEILING` = `0`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_three_faces_never_identical(uniforms: Dictionary) -> void:`
- `func test_guarantee_depends_on_the_separation_term(uniforms: Dictionary) -> void:`
- `func test_sooted_dark_voxel_is_separable(uniforms: Dictionary) -> void:`

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

extends `SceneTree` · 162 lines

`godot/scripts/tools/voxel_persist_selftest.gd`

> VL-PERSIST selftest — the coordinate math destruction persistence relies on. Run: godot --headless --script res://godot/scripts/tools/voxel_persist_selftest.gd Destruction is recorded in BASE (N-frame) voxel coords and re-applied per view by PerspectiveMapper.cell_to_base / cell_from_base at 8× the GU resolution (base_size × VOXELS_PER_UNIT_AXIS). Two properties must hold or holes land on the wrong voxels after a rotation: 1. cell_from_base and cell_to_base are exact inverses at voxel scale. 2. A voxel's rotation is consistent with its owning GU's rotation — the 8×8 quadrant rotates coherently, so a voxel stays inside its rotated GU. 3. GLASS §16.6 — the GEOMETRY the coordinates point at rotates too. Properties 1 and 2 were green for months while every half-thickness PANEL stood still through a quarter turn, because `layout_with_perspective()` never rotated `panel_instances`. A coordinate test cannot see that: the key was right, the pane was not there.

**Constants / tuning**
- `PM` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `SliceGeneratorClass` = `preload("res://godot/scripts/geometry/slice_generator.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_voxel_roundtrip_all_directions() -> void:`
- `func test_voxel_stays_in_rotated_gu() -> void:`
- `func test_panel_rotates_with_the_map() -> void:`

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

`class_name RoomBuilder` · 1270 lines

`godot/scripts/world/builders/room_builder.gd`

> RoomBuilder Orchestrates room construction, tile placement, and perspective transformations. Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

**Public vars**
- `var room: Node`
- `var PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")`
- `var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`
- `var PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")`
- `var MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")`
- `var DamageVariantBakerClass = preload("res://godot/scripts/systems/damage_variant_baker.gd")`
- `var VoxelVariantRegistryClass = preload("res://godot/scripts/systems/voxel_variant_registry.gd")`

**Public API**
- `func invalidate_bake_cache() -> void:`
- `func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:`

---

### `agent_shot_controller.gd`

`class_name AgentShotController` · 1125 lines

`godot/scripts/world/controllers/agent_shot_controller.gd`

> AgentShotController — WEAPON_MASTER_PLAN §6c: THE AGENT SHOOTS. The Director's own scoping of the wave (2026-08-16): *"O que a gente quer testar agora é só a mecânica de mirar da GU A para a GU B e o tiro acertar a parede C atrás. Pra isso só precisamos de um inimigo em qualquer posição, e ao clicar nele + 'disparar', como fizemos com a granada, o agente atira, e por falta de outra opção, erra sempre o alvo (por enquanto)."* THIS IS D25 LITERALLY — a shot always targets an ACTOR, picked through the same contextual menu the grenade already uses. It is NOT §5c's aim mode: D31's weapon slots and `S` key and D32's Tab-cycled target list with a visible hit percentage are combat-phase surface, explicitly out of this wave. D32 later replaces this menu AS A UI while leaving D25's principle untouched, so nothing here is written to survive it — the parts worth keeping are the roll (ShotHitRoll), the origin (Agent.muzzle_origin()) and the off-axis aim (BlastCalculator's aim_offset_deg), all of which live outside this file. WHAT IT REUSES RATHER THAN REBUILDS, which is most of it: §6c's own audit found that everything downstream of a miss shipped in July. The pellet selection, the impact resolution, D30's punch ladder, the bullet marks, the face-local soot and the whole decal pipeline are called here exactly as WeaponBenchController calls them. What is genuinely new is that a shot now leaves an ACTOR AT A POSITION and that something is drawn between the muzzle and the wall. WHY IT IS A SECOND CONTROLLER AND NOT A BRANCH INSIDE WeaponBenchController: that one owns static props placed on a bench — it holds `_weapons` rows with their own GU cells, facings and shot counters, and PLAYGROUND retired every one of them on 2026-08-17. Threading an actor through its prop model would have meant a fake prop standing in for the agent, which is the substitution this project's evidence rules ban. The bench file stays as it is, unused by PLAYGROUND but intact for its calibration history (§6b).

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `WEAPON_ID` = `"shotgun"`

**Public API**
- `func cancel_active() -> void:`
- `func fire_at_active() -> void:`

---

### `debug_tools_controller.gd`

`class_name DebugToolsController` · 189 lines

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
- `func force_damage_gallery() -> void:`
- `func toggle_atom_sheet() -> void:`
- `func apply_nudge(delta: Vector2) -> void:`
- `func reset_nudge() -> void:`
- `func try_change_posture(new_posture: DebugAgent.Posture) -> void:`
- `func is_nudge_mode_active() -> bool:`

---

### `input_controller.gd`

`class_name InputController` · 238 lines

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
- `signal grenade_mode_requested`
- `signal grenade_throw_requested`
- `signal grenade_cancel_requested`
- `signal weapon_select_requested(weapon_id: String)`

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

`class_name TestZoneController` · 1567 lines

`godot/scripts/world/controllers/test_zone_controller.gd`

> TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click "Detonar" on a test prop. ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a "digital twin" (Quaternius' CC0 "Grenade" model, poly.pizza) rendered via the real-3D-model + normal-map bake technique proven for the shotgun (godot/scripts/tools/grenade_frame_bake_spike.gd, 2026-07-28) — displayed via GrenadeProp (godot/scripts/overlays/grenade_prop.gd), NOT live TileMapLayer voxel cells. Superseded the original single-angle bake_voxel_sprite_3d.gd bake (grenade_bake_x8.png, a hand-placed BoxMesh voxel reconstruction of a CC0 .qb — itself already a v2 over a hand-rolled 2D painter's-algorithm rasterizer, v1) once that was shown to read flat from some angles and to ignore the room's active N/E/S/W perspective entirely, the same class of bug D22 found and fixed for the shotgun. Proves the mechanism ACTOR_MASTER_PLAN D1/D2 describes for one object before Parts 0-2 of that plan get built for real. Registry stays a plain Array[Dictionary] on purpose — scaffolding for the PLAYGROUND rebuild, not a permanent prop-interaction architecture. Delegates to room for shared state, same extraction pattern as SelectionController.

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GrenadePropClass` = `preload("res://godot/scripts/overlays/grenade_prop.gd")`
- `AgentProbePropClass` = `preload("res://godot/scripts/overlays/agent_probe_prop.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`
- `DetonationPresenterClass` = `preload("res://godot/scripts/systems/destruction/detonation_presenter.gd")`
- `DEFAULT_TARGET_OFFSET` = `Vector2i(3, 0)`

**Public vars**
- `var room: Node`
- `var throw_range_gu: float = 7.0`
- `var throw_range_penalty_gu: Dictionary = { DebugAgent.Posture.STANDING: 0.0, DebugAgent.Posture.CROUCHING: 2.0, DebugAgent.Posture.PRONE: 4.0, }`
- `var aim_dome_radius_gu: float = 2.0`
- `var throw_duration_s: float = 0.6`
- `var grenade_cook_s: float = 1.0`
- `var throw_prediction_timeout_s: float = 1.0`

**Public API**
- `func is_targeting() -> bool:`
- `func effective_throw_range_gu() -> float:`

---

### `turn_controller.gd`

`class_name TurnController` · 381 lines

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

`class_name WeaponBenchController` · 494 lines

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
- `MUZZLE_OFFSET_GU_FRACTION` = `0.42`
- `MUZZLE_HEIGHT_PX` = `-18.0`
- `MUZZLE_LEVEL` = `3`

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

`class_name FileMapSource` · extends `RefCounted` · 161 lines

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

`class_name MapCompiler` · extends `RefCounted` · 423 lines

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

`class_name MapSectionsV1` · extends `RefCounted` · 249 lines

`godot/scripts/world/maps/persistence/map_sections_v1.gd`

> MapSectionsV1 — Registration of board, walls, blocks, props, actors sections (v1)

---

### `room.gd`

extends `Node2D` · 10656 lines

`godot/scripts/world/room.gd`

**Constants / tuning**
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`
- `GlassShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `ShardField` = `preload("res://godot/scripts/overlays/shard_field.gd")`
- `GlassRainOverlay` = `preload("res://godot/scripts/overlays/glass_rain_overlay.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `GuardEnemyClass` = `preload("res://godot/scripts/agents/guard_enemy.gd")`
- `GuardNoiseIndicatorClass` = `preload("res://godot/scripts/overlays/guard_noise_indicator.gd")`
- `CeilingPropOverlayClass` = `preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")`
- `TileOverlayClass` = `preload("res://godot/scripts/overlays/tile_overlay.gd")`
- `DebugToolsControllerClass` = `preload("res://godot/scripts/world/controllers/debug_tools_controller.gd")`
- `InputControllerClass` = `preload("res://godot/scripts/world/controllers/input_controller.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GlassCrackSpriteClass` = `preload("res://godot/scripts/overlays/glass_crack_sprite.gd")`
- `GlassOpening` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `SelectionControllerClass` = `preload("res://godot/scripts/world/controllers/selection_controller.gd")`
- `TestZoneControllerClass` = `preload("res://godot/scripts/world/controllers/test_zone_controller.gd")`
- `WeaponBenchControllerClass` = `preload("res://godot/scripts/world/controllers/weapon_bench_controller.gd")`
- `AgentShotControllerClass` = `preload("res://godot/scripts/world/controllers/agent_shot_controller.gd")`
- `DetonateContextMenuClass` = `preload("res://godot/scripts/ui/detonate_context_menu.gd")`
- `ModalStackClass` = `preload("res://godot/scripts/ui/modal_stack.gd")`
- `WorldMarkersOverlayControllerClass` = `preload("res://godot/scripts/world/controllers/world_markers_overlay_controller.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `TurnControllerClass` = `preload("res://godot/scripts/world/controllers/turn_controller.gd")`
- `ShadowBoundaryOverlayClass` = `preload("res://godot/scripts/overlays/shadow_boundary_overlay.gd")`
- `LightRayOverlayClass` = `preload("res://godot/scripts/overlays/light_ray_overlay.gd")`
- `ShrapnelOverlayClass` = `preload("res://godot/scripts/overlays/shrapnel_overlay.gd")`
- `AimBubbleOverlayClass` = `preload("res://godot/scripts/overlays/aim_bubble_overlay.gd")`
- `ThrowPerimeterOverlayClass` = `preload("res://godot/scripts/overlays/throw_perimeter_overlay.gd")`
- `ThrowArcOverlayClass` = `preload("res://godot/scripts/overlays/throw_arc_overlay.gd")`
- `ShrapnelPreviewOverlayClass` = `preload("res://godot/scripts/overlays/shrapnel_preview_overlay.gd")`
- `TargetCursorOverlayClass` = `preload("res://godot/scripts/overlays/target_cursor_overlay.gd")`
- `EmberOverlayClass` = `preload("res://godot/scripts/overlays/ember_overlay.gd")`
- `SmokeSparkOverlayClass` = `preload("res://godot/scripts/overlays/smoke_spark_overlay.gd")`
- `DebrisOverlayClass` = `preload("res://godot/scripts/overlays/debris_overlay.gd")`
- `ExplosionFlashOverlayClass` = `preload("res://godot/scripts/overlays/explosion_flash_overlay.gd")`
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

**Public vars**
- `var CRATE_STACK_STEP_PX: float = 128.0`

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

### `iso_projection.gd`

`class_name IsoProjection` · 134 lines

`godot/scripts/world/utilities/iso_projection.gd`

**Constants / tuning**
- `AXIS_X` = `Vector2(128.0, 64.0)`
- `AXIS_Y` = `Vector2(-128.0, 64.0)`
- `AXIS_Z` = `Vector2(0.0, -160.0)`

---

### `perspective_mapper.gd`

`class_name PerspectiveMapper` · 289 lines

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
