# CODEMAP — INFILTRAITOR

> **GENERATED FILE — do not edit by hand.**
> Produced by `tools/persistent/gen_codemap.py` from the actual GDScript
> source. Regenerate with `python3 tools/persistent/gen_codemap.py`.
> A pre-commit hook blocks commits when this file is stale.
>
> Design rationale and the inviolable rules live in `CLAUDE.md`
> (hand-authored). This file is the mechanical mirror of the code.

**280 scripts · 83546 lines total** (under `godot/scripts/`)

## Index

- **agents/** — actor_pose.gd, agent.gd, guard_attention.gd, guard_enemy.gd
- **controllers/** — camera_controller.gd, fow_controller.gd, guard_coordinator.gd, hud_controller.gd, lighting_controller.gd, vision_controller.gd
- **debug/** — dev_vision_status_panel.gd, map_loader_panel.gd, theme_matrix_debug_view.gd, vfx_draw_probe.gd, voxel_ruler_overlay.gd
- **geometry/** — actor_head_turn3d.gd, actor_mesh3d.gd, board3d_live.gd, board_look.gd, circle_field3d.gd, edge.gd, edge_extractor.gd, edge_registry.gd, face.gd, floor_openings.gd, floor_pile3d.gd, geometry_coords.gd, glass_crack_mirror3d.gd, glass_pane_grouper.gd, ground_canvas3d.gd, ground_decals3d.gd, ground_grid.gd, ground_scatter.gd, ground_transitions3d.gd, junction_resolver.gd, mesh_prop_instance.gd, object_mesh3d.gd, particle_math.gd, passage_query.gd, pick_math.gd, prop_block.gd, prop_fragment_sim.gd, prop_fragments3d.gd, prop_mesh3d.gd, prop_model_fit.gd, prop_shadow.gd, prop_voxelizer.gd, quad_field3d.gd, shard_field3d.gd, slab.gd, slab_generator.gd, slab_registry.gd, slice.gd, slice_generator.gd, vision_cone3d.gd, voxel.gd, voxel_board.gd, voxel_container.gd, world_canvas3d.gd
- **navigation/** — guard_pathfinder.gd, movement_overlay.gd, path_preview.gd
- **overlays/** — aim_bubble_overlay.gd, blast_wireframe_overlay.gd, ceiling_prop_overlay.gd, debris_overlay.gd, elite_exposure_overlay.gd, ember_overlay.gd, explosion_flash_overlay.gd, exposure_overlay.gd, floating_collectible.gd, glass_rain_overlay.gd, grenade_prop.gd, gu_grid_overlay.gd, height_overlay.gd, light_overlay.gd, light_ray_overlay.gd, noise_overlay.gd, occlusion_overlay.gd, shadow_boundary_overlay.gd, shadow_overlay.gd, shrapnel_overlay.gd, shrapnel_preview_overlay.gd, smoke_spark_overlay.gd, target_cursor_overlay.gd, temporal_overlay.gd, throw_arc_overlay.gd, throw_perimeter_overlay.gd, tile_overlay.gd, tile_risk_overlay.gd, tracer_overlay.gd, trail_overlay.gd, vent_emitter.gd
- **systems/** — board_probe.gd, cell_plane_store.gd, cosmetic_density.gd, blast_calculator.gd, bomb_def.gd, bomb_registry.gd, detonation_entry_writer.gd, detonation_plan_builder.gd, detonation_presenter.gd, glass_crack.gd, glass_crack_params.gd, glass_fall.gd, glass_opening.gd, glass_shard_shapes.gd, glass_shatter.gd, material_resistance_table.gd, shot_hit_roll.gd, shot_punch_table.gd, weapon_def.gd, weapon_registry.gd, dev_flags.gd, earth_variant_selector.gd, enemy_phase_controller.gd, facade_sampler.gd, frame_rate.gd, frame_split.gd, gfx_census.gd, glass_materials.gd, image_source.gd, json_file.gd, exposure_system.gd, light_anchor.gd, light_registry.gd, light_source.gd, shadow_projector.gd, shadow_result.gd, voxel_light_field.gd, localization_manager.gd, material_registry.gd, mem_stage.gd, metal_pattern.gd, noise_system.gd, occlusion_set.gd, paint_palette.gd, claim_grid.gd, detonation_prediction.gd, prediction_cache.gd, prediction_reaper.gd, walk_warmer.gd, world_delta.gd, prop_def.gd, prop_registry.gd, prop_validator.gd, prop_vox_library.gd, registries_autoload.gd, save_state.gd, scenario_draw.gd, scenario_runner.gd, slot_def.gd, stone_pattern.gd, surface_rules.gd, telemetry.gd, texture_resolver.gd, tic_system.gd, turn_manager.gd, version_info.gd, view_context.gd, vox_model.gd, vox_prop_builder.gd, voxel_store.gd, wood_pattern.gd, world_render_scale.gd
- **tools/** — actor_decisions_selftest.gd, blast_calculator_selftest.gd, blast_purity_selftest.gd, board_look_selftest.gd, board_probe_selftest.gd, circle_field_octagon_selftest.gd, cosmetic_density_selftest.gd, detonation_plan_selftest.gd, dev_flags_selftest.gd, dump_glass_openings.gd, earth_variant_selftest.gd, fixed_floor_selftest.gd, floor_integration_selftest.gd, floor_openings_selftest.gd, floor_pile_tiles_selftest.gd, floor_zone_bake_selftest.gd, geometry_selftest.gd, glass_crack_selftest.gd, glass_fall_selftest.gd, glass_shard_shapes_capture.gd, glass_shard_shapes_selftest.gd, glass_shatter_selftest.gd, glass_transparency_selftest.gd, ground_canvas3d_selftest.gd, ground_decals_selftest.gd, ground_grid_selftest.gd, ground_scatter_selftest.gd, half_thickness_selftest.gd, hud_seam_selftest.gd, input_controller_selftest.gd, iso_projection_selftest.gd, map_lint.gd, mapfile_roundtrip_selftest.gd, material_reform_selftest.gd, material_tints_selftest.gd, material_tree_selftest.gd, negative_storey_selftest.gd, neon_flicker_selftest.gd, occlusion_set_selftest.gd, occlusion_view_selftest.gd, paint_palette_selftest.gd, panel_base_selftest.gd, particle_space_selftest.gd, passage_query_selftest.gd, project_lint_validator.gd, prop_01_selftest.gd, prop_fragment_sim_selftest.gd, prop_model_path_selftest.gd, prop_shadow_selftest.gd, prop_slot_selftest.gd, prop_voxelizer_selftest.gd, registry_load_errors_selftest.gd, resolver_hardening_selftest.gd, roof_bake_selftest.gd, roof_entity_selftest.gd, roof_integration_selftest.gd, roof_occlusion_selftest.gd, roof_slab_selftest.gd, save_state_file_selftest.gd, save_state_selftest.gd, scenario_draw_selftest.gd, scenario_selftest.gd, slab_geometry_selftest.gd, slab_render_selftest.gd, slice_geometry_selftest.gd, soot_stamp_selftest.gd, soot_truth_selftest.gd, surface_rules_selftest.gd, telemetry_selftest.gd, texture_resolver_selftest.gd, vent_emitter_selftest.gd, version_info_selftest.gd, vox_model_selftest.gd, voxel_decal_selftest.gd, voxel_handle_selftest.gd, voxel_light_incremental_selftest.gd, voxel_persist_selftest.gd, voxel_store_selftest.gd
- **ui/** — controls_panel.gd, detonate_context_menu.gd, enemy_banner_panel.gd, fog_of_war_overlay.gd, main_menu_panel.gd, modal_stack.gd, options_panel.gd, panel_base.gd, selection_overlay.gd, showcase_panel.gd, tile_labels_overlay.gd, top_bar_panel.gd, window_base.gd
- **world/** — room_builder.gd, agent_shot_controller.gd, debug_tools_controller.gd, input_controller.gd, selection_controller.gd, test_zone_controller.gd, turn_controller.gd, world_markers_overlay_controller.gd, level_graph.gd, playground_map.gd, procedural_map.gd, sigma_01_map.gd, file_map_source.gd, map_catalog.gd, map_compiler.gd, map_geometry.gd, map_file_service.gd, map_section_registry.gd, map_sections_v1.gd, room.gd, tile_semantics.gd, iso_projection.gd, perspective_mapper.gd, wall_edge_data.gd

---

## agents/

### `actor_pose.gd`

`class_name ActorPose` · extends `Node` · 233 lines

`godot/scripts/agents/actor_pose.gd`

> ActorPose — WHAT an actor's figure is doing: its facing, posture, grip, weapon, walk, throw and head. It draws nothing; `ActorMesh3D` draws it (RENDER3D R3D-ACTORS, `ACTOR` D64). R3D-ACTORS step 5 (2026-10-01) RETIRED THE GAMEPLAY FRAME BAKE from this node: the colour/normal frame sets, the head and hat layers, the per-posture anchors and D17's normal-map relight are gone, and with them every texture this file loaded (D42's RAM was the atlases'). What stayed is the half both renderers shared, unchanged in meaning: - FACING, SNAPPED AT THE GU BOUNDARY (D47), one of FOUR (D44, kept for gameplay at step 2: the mesh could turn to any yaw, but whether movement keeps four facings is a design question, and keeping it changes nothing). Stored as the BASE grid step it came from, so it survives a camera turn by construction. - THE POSTURE, THE GRIP, THE WEAPON. Each is now a name the live rig has an action for (`tools/asset_generation/r3d_live_rig_export.py`); a name it does not have is refused loudly and the previous one kept. - THE WALK, read straight off the step's progress (one cycle per GU, D61): no accumulator to drift. Standing only, as before: a crouched or prone figure slides. - THE THROW: raise (held for the aim), release, and the cancel as the raise played backwards (the Director's own reuse rule). `throw_released` fires when the release crosses THROW_RELEASE_FRACTION — the fraction of the key list p3_throw_export.py releases at — and at the latest when the release ends, because `execute_grenade_throw()` awaits it. Standing only, as the bake was. - THE HEAD'S GRID ANGLE (a guard looking where its cone points), clamped to HEAD_YAW_LIMIT_DEG off the body by the mesh. It was `AgentSprite`, a `Sprite2D` that drew nothing; it is a plain `Node` now (RETIRE of R3D-RETIRE-2D). The members that name it (`Agent.sprite`, `attach_sprite()`) keep their old names for the callers' sake.

**Signals**
- `signal throw_released`

**Constants / tuning**
- `THROW_RAISE` = `"raise"`
- `THROW_RELEASE` = `"release"`
- `THROW_RELEASE_FRACTION` = `0.5`
- `HEAD_YAW_LIMIT_DEG` = `60.0`
- `POSTURES` = `["standing", "crouch", "prone"]`
- `GRIPS` = `["", "_aimed"]`
- `WEAPONS` = `["", "_pistol"]`
- `STEPS` = `[Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]`
- `START_STEP` = `Vector2i(0, -1)`

**Public vars**
- `var frame_family: String = ""`
- `var grip: String = ""`
- `var weapon: String = ""`
- `var room: Node = null`

**Public API**
- `func setup(p_room: Node) -> bool:`
- `func face_step(step: Vector2i) -> void:`
- `func face_direction(dir: Vector2i) -> void:`
- `func set_posture_name(name: String) -> void:`
- `func set_grip(name: String) -> void:`
- `func preload_grip(name: String) -> bool:`
- `func set_weapon_bake(name: String) -> bool:`
- `func set_walk_phase_quantise(_n: int) -> void:`
- `func set_walk_phase(progress01: float) -> void:`
- `func stop_walking() -> void:`

---

### `agent.gd`

`class_name DebugAgent` · extends `Node2D` · 482 lines

`godot/scripts/agents/agent.gd`

**Signals**
- `signal move_started(from_cell: Vector2i, to_cell: Vector2i)`
- `signal step_finished(cell: Vector2i)`
- `signal move_finished(cell: Vector2i)`
- `signal posture_changed(new_posture: Posture)`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
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
- `COVER_RING_RADIUS_PX` = `30.0`
- `COVER_RING_SEGMENTS` = `32`

**Public vars**
- `var posture: Posture = Posture.STANDING`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var cell: Vector2i = Vector2i.ZERO`
- `var vision_radius: int = 7`
- `var vision_mode: String = "normal"`
- `var is_moving: bool = false`
- `var dev_vision: bool = false`
- `var sprite: ActorPose = null`
- `var cover_state: CoverType = CoverType.NONE`
- `var cover_direction: Vector2i = Vector2i.ZERO`
- `var step_duration: float = 0.56`
- `var ground_shadow_half_px := Vector2(28.0, 10.0)`

**Public API**
- `func throw_origin() -> Vector2:`
- `func muzzle_origin() -> Vector2:`
- `func play_throw_raise() -> bool:`
- `func play_throw_cancel() -> bool:`
- `func play_throw_release() -> bool:`
- `func set_grip(name: String) -> void:`
- `func throw_launch_height() -> float:`
- `func setup(offset: Vector2, start_cell: Vector2i) -> void:`
- `func attach_sprite(p_room: Node) -> bool:`
- `func set_cell(new_cell: Vector2i) -> void:`
- `func get_vision_radius() -> int:`
- `func set_posture(new_posture: Posture) -> void:`
- `func set_dev_vision(enabled: bool) -> void:`
- `func on_perspective_changed() -> void:`
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

`class_name GuardEnemy` · extends `Node2D` · 1322 lines

`godot/scripts/agents/guard_enemy.gd`

**Signals**
- `signal move_started(from_cell: Vector2i, to_cell: Vector2i)`
- `signal step_finished(cell: Vector2i)`
- `signal move_finished(cell: Vector2i)`
- `signal vision_smooth_ready(points: PackedVector2Array, colors: PackedColorArray)`
- `signal whistled(origin_cell: Vector2i, last_known: Vector2i)`
- `signal radioed(origin_cell: Vector2i, last_known: Vector2i)`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
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

**Public vars**
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var enemy_id: String = ""`

---

## controllers/

### `camera_controller.gd`

extends `Node` · 255 lines

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
- `func initialize_fog(visual_offset: Vector2, room_size: Vector2i) -> void:`
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

extends `Node` · 285 lines

`godot/scripts/controllers/hud_controller.gd`

---

### `lighting_controller.gd`

extends `Node` · 259 lines

`godot/scripts/controllers/lighting_controller.gd`

**Signals**
- `signal lighting_rebuilt()`

**Constants / tuning**
- `LightRegistryClass` = `preload("res://godot/scripts/systems/lighting/light_registry.gd")`
- `ShadowProjectorClass` = `preload("res://godot/scripts/systems/lighting/shadow_projector.gd")`
- `ExposureSystemClass` = `preload("res://godot/scripts/systems/lighting/exposure_system.gd")`
- `LightSourceClass` = `preload("res://godot/scripts/systems/lighting/light_source.gd")`
- `LightAnchorClass` = `preload("res://godot/scripts/systems/lighting/light_anchor.gd")`
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

---

### `vision_controller.gd`

extends `Node2D` · 325 lines

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

`class_name DevVisionStatusPanel` · extends `Control` · 101 lines

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

`class_name VoxelRulerOverlay` · extends `Node2D` · 133 lines

`godot/scripts/debug/voxel_ruler_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `VOXEL_TILE_SIZE` = `Vector2i(32, 16)`
- `FLOOR_TILE_SIZE` = `Vector2i(256, 128)`
- `VOXELS_PER_AXIS` = `8`
- `VOXEL_LINE_COLOR` = `Color(0.0, 1.0, 1.0, 0.25)`
- `GU_LINE_COLOR` = `Color(0.0, 1.0, 1.0, 0.5)`
- `VOXEL_LINE_WIDTH` = `0.5`
- `GU_LINE_WIDTH` = `1.0`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var visible_grid: bool = false`

**Public API**
- `func setup(visual_grid_offset: Vector2, room_size: Vector2i) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

## geometry/

### `actor_head_turn3d.gd`

`class_name ActorHeadTurn3D` · extends `SkeletonModifier3D` · 34 lines

`godot/scripts/geometry/actor_head_turn3d.gd`

> ActorHeadTurn3D — turns a live rig's head about the vertical, on top of whatever action is playing (R3D-ACTORS, the mesh half of `ActorPose`'s head layer). A `SkeletonModifier3D` because it has to run AFTER the AnimationPlayer has posed the skeleton this frame; a bone pose written from `_process` would be overwritten by the next seek. `yaw` is relative to the body (`ActorMesh3D` clamps it to `ActorPose.HEAD_YAW_LIMIT_DEG`), about the skeleton's up axis, so a crouched figure whose neck is pitched still turns its head around the vertical rather than around its own tilted neck.

**Constants / tuning**
- `HEAD_BONE` = `"head"`

**Public vars**
- `var yaw: float = 0.0`

---

### `actor_mesh3d.gd`

`class_name ActorMesh3D` · extends `Node3D` · 333 lines

`godot/scripts/geometry/actor_mesh3d.gd`

> ActorMesh3D — an actor as a live skinned mesh on the 3D board (RENDER3D R3D-ACTORS, `ACTOR` D64). THE MESH SHOWS, `ActorPose` DECIDES (step 3, the bridge). The contract the retired `ActorBillboard3D` kept: the sprite still owns every decision — facing (D44's four, D47's snap at the GU boundary), posture, grip, weapon, the walk's progress, the throw and the head's grid angle — and this node reads them each frame through `ActorPose.mesh_state()` and turns them into a yaw, an action and a time. Nothing in the actor's logic knows which of the two draws it. THE RIG is `tools/asset_generation/r3d_live_rig_export.py`'s: one skinned mesh, every motion a keyed action (`<posture>_<weapon>_<grip>`, `walk_<weapon>`, `throw_raise_<weapon>`, `throw_release_<weapon>`), the weapons on `hand_R` and the grenade on `hand_L` as `BoneAttachment3D`s. An action is never PLAYED: it is SEEKED to the fraction the sprite is at, so the walk stays locked to the step's progress (one cycle per GU, D61) and the throw to the sprite's own clock, which is what fires `throw_released`. LIT the board's way (`actor_mesh3d.gdshader`: no Godot light, one cell-plane fetch; Moto: 9 walking rigs +1.0 ms), its materials kept in sync by `Board3DLive.register_prop_light_material()` exactly as a prop's are. PLACED in BASE world coordinates: the feet are the sprite's 2D position through `Board3DLive.ground_point()` (the N lattice in every view), the yaw is the base grid step's, so a camera yaw turns the figure with the board for free.

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/actor_mesh3d.gdshader"`
- `SILHOUETTE_SHADER_PATH` = `"res://godot/shaders/actor_mesh_silhouette3d.gdshader"`
- `SILHOUETTE_PRIORITY` = `20`
- `SHADOW_SHADER` = `"res://godot/shaders/ground_overlay3d.gdshader"`
- `SHADOW_LIFT` = `0.005`
- `HeadTurnRef` = `preload("res://godot/scripts/geometry/actor_head_turn3d.gd")`
- `RIG_DIR` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/"`
- `RIG_BY_FAMILY` = `{ "": "agent_live.glb", "_enemy_white": "agent_live_enemy_white.glb", }`
- `WEAPON_BY_SUFFIX` = `{"": "shotgun", "_pistol": "pistol", "_rifle": "shotgun"}`
- `METRES_TO_UNITS` = `1.0 / 1.6`
- `DEFAULT_SHADOW` = `Color(0.0, 0.0, 0.0, 0.28)`
- `REVEAL_PALETTES` = `{ &"agent": {"stripe_a": Color(0.86, 0.96, 1.0), "stripe_b": Color(0.16, 0.28, 0.38), "outline_color": Color(1.0, 1.0, 1.0)}, &"agency": {"stripe_a": Color(0.46, 0.64, 1.0), "stripe_b": Color(0.08, 0.14, 0.40), "outline_color": Color(0.30, 0.56, 1.0)}, &"militia": {"stripe_a": Color(1.0, 0.52, 0.36), "stripe_b": Color(0.40, 0.10, 0.06), "outline_color": Color(1.0, 0.34, 0.18)}, &"corporation": {"stripe_a": Color(1.0, 0.84, 0.30), "stripe_b": Color(0.38, 0.28, 0.04), "outline_color": Color(1.0, 0.74, 0.12)}, &"network": {"stripe_a": Color(0.46, 0.96, 0.62), "stripe_b": Color(0.06, 0.30, 0.14), "outline_color": Color(0.28, 0.90, 0.46)}, }`

**Public vars**
- `var reveal_behind_walls: bool = false:`
- `var silhouette_phase: float = 0.0:`
- `var reveal_faction: StringName = &"":`

**Public API**
- `func setup_actor(board: Node3D, source: ActorPose) -> bool:`
- `func hand_grenade_world() -> Vector3:`
- `func head_offset_px() -> Vector2:`

---

### `board3d_live.gd`

extends `Node3D` · 2617 lines

`godot/scripts/geometry/board3d_live.gd`

> Board3DLive — THE board: the voxel world as depth-tested 3D meshes under the 2D game. DIAG-21 (DEVICE_DIAGNOSTICS_MASTER_PLAN §15.7–§15.10) built this as a spike under `spikes/`; RENDER3D R3D-3 (2026-09-17) moved it here. Since R3D-END (2026-09-24/25) it is the ONLY board: the 2D `TileMapLayer` board was deleted (the last commit that builds it is `34881f81`) and `VoxelBoard` — the class that used to render it — holds only the state this file draws. It is built after a real map load. Actors, props, fog, the overlays and the HUD still draw in 2D, on top of it, until R3D-ACTORS / R3D-PROPS. WHAT IT READS: the `VoxelStore` (visible claims, glass state, decal state) and the registries the real load built (every Slice with its half thickness and material bands, every junction corner column, every floor, deep-floor and roof Slab), plus the light and soot cell planes `VoxelBoard` keeps. It reads, it never writes game state — and it never writes a tile (the R8 hook keeps it so). THE LOOK, and how it maps from the 2D lattice: - voxel (grid x, level, grid y) → world (x/8, (level − ground plane)/8, y/8), so a GU is one world unit and a storey one unit tall (the 30° camera's cube); - only the three faces the camera can see are emitted — top (+Y), SE (+X) and SW (+Z) — the same three `VoxelLightField.surface_factor()` names; - a material is `base_color × facade luminance` (MULTIPLY), sampled in world space at 16 texels per voxel with mirrored repeat; - LIGHT AND SOOT ARE PER CELL, NOT PER VERTEX. The fragment finds its own voxel from its world position and reads bucket and soot code from a `Texture2DArray` holding the cell planes, one layer per level, so faces merge by MATERIAL only and a soot or light change is a layer upload instead of a remesh (a remesh for colour changes cost ~240 ms on the Moto, §15.9); - the terms are applied in a fixed order: face tone × bucket luminance × per-face soot × floor depth dim, all in sRGB, the product decoded once (`BoardLook` owns the constants). ⚠️ NOT A PARITY CLAIM against the deleted 2D board: facade continuity is world-space (not per wall run), a true cube projects 19.6 px per level where the 2D sprites expect 20, and R3D-LOOK owns whatever else differs. Compare against the 2D board only from a worktree of `34881f81`.

**Signals**
- `signal view_changed(direction: String)`

**Constants / tuning**
- `PickMathRef` = `preload("res://godot/scripts/geometry/pick_math.gd")`
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `VERTICAL_SCALE_MATCHED` = `158.0 / 156.8`
- `FACADE_SPAN_VOXELS` = `Vector2(64.0, 32.0)`
- `DIR_STEP` = `[Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]`
- `DIR_NORMAL` = `[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]`
- `ALL_DIRS` = `[Dir.TOP, Dir.SE, Dir.SW, Dir.NW, Dir.NE]`
- `VIEW_FACE_SLOTS` = `{ "N": Vector2i(1, 2), "E": Vector2i(2, 1), "S": Vector2i(1, 2), "W": Vector2i(2, 1), }`
- `VIEW_YAW_DEG` = `{"N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0}`
- `OPAQUE_SHADER` = `"""`

---

### `board_look.gd`

`class_name BoardLook` · extends `RefCounted` · 130 lines

`godot/scripts/geometry/board_look.gd`

> BoardLook — the one owner of the board's look constants (R3D-9, 2026-09-24). Until now the same numbers lived in three places: the 2D face shader's uniform defaults, `Board3DLive`'s fallbacks, and (for the light ladder) `VoxelBoard`. The 3D board read them by asking the 2D renderer's ground layer for its `ShaderMaterial`, which made the 3D board depend on a node the 3D path is meant to outlive. Now both boards read this; the 2D face shader gets these values pushed as uniforms until R3D-END deletes it, and `board_look_selftest` parses the shader's defaults so a change there cannot drift from here.

**Constants / tuning**
- `SOOT_FACE_MULT` = `[0.38, 0.60, 0.76, 0.90]`
- `SOOT_CHAR_MIN` = `0.10`
- `SOOT_CHAR_MAX` = `0.30`
- `FACE_TONE` = `[1.0, 0.975, 0.945]`
- `GRADE_SATURATION` = `1.0`
- `GRADE_CONTRAST` = `1.0`
- `GRADE_LIFT` = `0.0`

---

### `circle_field3d.gd`

`class_name CircleField3D` · extends `"res://godot/scripts/geometry/quad_field3d.gd"` · 41 lines

`godot/scripts/geometry/circle_field3d.gd`

> CircleField3D — many camera-facing discs on the 3D board, in ONE draw call, depth-tested. RENDER3D R3D-4e-1. The 3D twin of `CircleField` (PERF-P7b): the same clients, the same begin/push/flush/clear frame, but each disc has a WORLD position (`ParticleMath`), so a wall in front of it hides it. Built on `QuadField3D` (R3D-4e-3): the disc is a quad whose shader discards outside the unit circle and feathers the rim — a frame ships only a transform and a colour per instance, exactly as the 2D field does with its circle fan, and a quad is four vertices where the fan was 192. `QuadField3D`'s header carries the `custom_aabb` and draw-order warnings that apply here too.

**Constants / tuning**
- `SHADER_MIX` = `"res://godot/shaders/particle_disc3d.gdshader"`
- `SHADER_ADD` = `"res://godot/shaders/particle_disc3d_add.gdshader"`

**Public API**
- `func attach(parent: Node3D, additive: bool, feather: float = 0.0, priority: int = 0) -> void:`
- `func push(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2, radius_px: float, color: Color) -> void:`

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

`class_name EdgeRegistry` · 192 lines

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

---

### `face.gd`

`class_name Face` · 49 lines

`godot/scripts/geometry/face.gd`

> Geometry Module — Face enum and helpers Single source for face semantics (per DIRECTION_GLOSSARY §3, §6)

---

### `floor_openings.gd`

`class_name FloorOpenings` · extends `RefCounted` · 57 lines

`godot/scripts/geometry/floor_openings.gd`

> FloorOpenings — a real opening in the floor (R3D-SURFACES SM-6b, 2026-10-06, DS-18): which voxel cells of a GU the floor does NOT have. A grating is not a dark texture, it is an object with holes: `SlabGenerator` skips the cells this returns, on BOTH floor levels (the top plane and the deep one beneath it), so a shaft runs through the ground and the camera sees the void at its bottom. It is the very state the buffer ring's missing deep plane and a crater already are (cells that do not exist), so the mesher, the light planes, the occupancy and the destruction already cope with it. An opening is a rectangle of WHOLE GUs (`gu`, `size`, in raw GU) of one of two patterns: - `slats`: bars of one voxel (1/8 GU, ~12 cm) running along `axis` ("x" or "z"), a bar every `pitch` voxels (2: one bar, one gap), inside a one-voxel FRAME that is always floor. The bars are floor voxels of the opening's `material`, so they are walkable, shootable-through gaps, and a grenade takes them like any floor. - `open`: nothing at all, frame included: a bare shaft (a pit; a hazard for the gameplay milestone, not built). Pure and deterministic, so the selftest pins it without a board.

**Constants / tuning**
- `PATTERNS` = `["slats", "open"]`
- `AXES` = `["x", "z"]`
- `DEFAULT_PITCH` = `2`
- `DEFAULT_MATERIAL` = `"steel_dark"`

---

### `floor_pile3d.gd`

`class_name FloorPile3D` · extends `RefCounted` · 289 lines

`godot/scripts/geometry/floor_pile3d.gd`

> FloorPile3D — decals lying flat on the 3D board's floor (glass-shard piles, the ground/leaf patch, Tier 4 debris). RENDER3D R3D-6 (item 6). The 2D board draws a landed pane's piles as one `Sprite2D` per cell (`VoxelBoard.spawn_floor_shard_pile`); under the 3D board that renderer is hidden, so the piles — the white band that stays on the floor after a pane is shot out — were not drawn at all. HOW (R3D-9): a pile is DATA — a world-space centre, a level, a variant and an opacity (`VoxelBoard.spawn_floor_shard_pile` hands them over, from `Room._base_shards`); nothing is read from a sprite. One `ArrayMesh` per decal variant (three), rebuilt once per frame at most when a pile changes, so a whole pane's ~650 piles are three draw calls. Depth-tested: a wall in front hides a pile. GEOMETRY (rewritten 2026-09-28, Director: the piles read as screen-facing squares, not the ground's own isometric losango — glass included, not just the newer debris). The quad used to be built by taking a SCREEN-space square and back-projecting it onto the ground through the camera (`ground_affine()`), which is why it always looked axis-aligned to the screen regardless of the camera's angle — a leftover from when this was a `Sprite2D` and the goal was literally "keep the same screen footprint it had as a sprite". It is now a plain flat quad in WORLD space (X/Z, like every other piece of ground geometry — the same convention `Board3DLive._emit_quad()`'s top face and `PropMesh3D` already use), so it shears under the camera exactly like the floor tile beneath it. `half_gu` is a half-side in WORLD units, not screen pixels — 1.0 world unit = 1 GU (8 voxels). State stays where it always was (`Room._base_shards`, base-space); this only draws it.

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/floor_decal3d.gdshader"`
- `DEFAULT_HALF_GU` = `0.5 / GeometryCoords.VOXELS_PER_UNIT_AXIS`
- `TILE_GRID` = `8`

---

### `geometry_coords.gd`

`class_name GeometryCoords` · 103 lines

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

### `glass_crack_mirror3d.gd`

`class_name GlassCrackMirror3D` · extends `Node3D` · 178 lines

`godot/scripts/geometry/glass_crack_mirror3d.gd`

> GlassCrackMirror3D — the 3D board's twin of every live `GlassCrackSprite`. RENDER3D R3D-6 item 2 (moved here from R3D-4e-4b). `VoxelBoard.spawn_glass_crack()` / `spawn_glass_craze()` produce each crack as a RECORD: the centre voxel, the face, the run axis, the span, the pane bounds and `params`, every shader parameter as data (the occupancy cut and the opening void included). This node gives each record a quad on the pane's plane in the 3D world and copies `params` into it every frame. **R3D-9: it reads the record and nothing else** — not the 2D sprite, not its ShaderMaterial; the sprite is the same record's 2D consumer, until R3D-END. Nothing here decides a crack. PLACEMENT. The record says which voxel the crack is centred on (`impact_cell`, `impact_level`, `face`), which way the pane runs (`run_axis`: 0 = along X, 1 = along Z) and how large the sheet is (`crack_span`, in voxels). The quad is that many voxels wide and tall, centred on the impact voxel, standing on the face's own plane, and carries the sprite's UV so the shader's `off` is the same run/level offset it is in 2D.

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/glass_crack3d.gdshader"`
- `MIRRORED` = `[ "crack_sheet", "crack_span", "crack_pane_lo", "crack_pane_hi", "crack_field", "crack_tile_span", "crack_field_origin", "crack_field_dir", "crack_occupancy", "crack_occ_size", "crack_occ_origin", "crack_hole_cut", "crack_opening", "crack_opening_origin", "crack_opening_size", "crack_opacity", ]`
- `FACE_LIFT_VOXELS` = `0.05`
- `OPEN_MAX` = `16`
- `OPEN_TEXELS_PER_VOXEL` = `12`

**Public vars**
- `var pane_materials: Array = []`

**Public API**
- `func setup(renderer: VoxelBoard, ground_level: int) -> void:`
- `func twin_count() -> int:`

---

### `glass_pane_grouper.gd`

`class_name GlassPaneGrouper` · 232 lines

`godot/scripts/geometry/glass_pane_grouper.gd`

> Geometry Module — GlassPaneGrouper (GLASS_MASTER_PLAN §4, G2). Stamps `Slice.pane_id` on every glass slice in an EdgeRegistry so the cascade (G3) can take a whole continuous surface from one hit. Run once at map load, right after SliceGenerator.generate(), never per shot. Two producers, one consumer: · BLOCKS — "um bloco é um bloco" (G-D2). Every glass `solid_block_instance` footprint cell is merged into one set and FLOOD-FILLED into connected components (§4.2); each component is one pane. This is deliberately NOT per-authored-instance: PLAYGROUND spells a 3-wide glass block as three adjacent 1×1 declarations, and those are one block, not three. · PANELS — contiguous coplanar half-thickness faces. Union-find: two glass panel slices are the same pane when they share a face orientation AND their owning GUs are adjacent along that face's RUN axis (perpendicular to Face.delta). A lone panel is its own pane. Every glass slice leaves this pass with a non-empty `pane_id`.

**Constants / tuning**
- `MAX_PANE_RUN_GU` = `8`
- `MAX_PANE_STOREYS` = `4`

---

### `ground_canvas3d.gd`

`class_name GroundCanvas3D` · extends `RefCounted` · 278 lines

`godot/scripts/geometry/ground_canvas3d.gd`

> GroundCanvas3D — a 2D overlay's flat drawing, re-issued on the 3D board's ground plane. RENDER3D R3D-5b. The ground-plane gameplay overlays (movement range, path preview, the selection diamond, ...) draw in 2D canvas pixels on top of everything, so under a 3D board they paint over the actors and the props (the Director saw the movement outline cut the agent's hat and a grenade). This keeps each overlay's own drawing code and changes only WHERE it lands. HOW: it has the four `CanvasItem` calls those overlays use — `draw_colored_polygon`, `draw_line`, `draw_polyline`, `draw_circle` — so an overlay draws into it exactly as it draws into itself (`var c = _ground if _ground != null else self`). Each call is tessellated in 2D (a line becomes a quad `width` px thick, measured on SCREEN, as the 2D line was), every vertex is carried onto the ground plane by the board's own 2D→ground affine, and one `ArrayMesh` per redraw is published. WHY THE LOOK DOES NOT CHANGE: the ground plane maps to the screen affinely, so a vertex placed on the ground from a 2D point projects back to that very pixel. What changes is depth: a tile behind a wall is hidden by it, and the agent's billboard, which stands in front of the floor, covers the tile under his feet. `ground_canvas3d_selftest` proves the pixel identity through the real camera. LAYERING. 2D `z_index` decided which overlay sat over which; here `priority` (material render priority) does, and each canvas sits at its own `lift` above the floor so coplanar overlays never z-fight the floor or each other.

**Constants / tuning**
- `SHADER_MIX` = `"res://godot/shaders/ground_overlay3d.gdshader"`
- `SHADER_MUL` = `"res://godot/shaders/ground_overlay3d_mul.gdshader"`
- `SHADER_BEHIND_GLASS` = `"res://godot/shaders/ground_overlay3d_behind_glass.gdshader"`
- `GLASS_FADE` = `0.3`
- `CIRCLE_SEGMENTS` = `48`

---

### `ground_decals3d.gd`

`class_name GroundDecals3D` · extends `RefCounted` · 170 lines

`godot/scripts/geometry/ground_decals3d.gd`

> GroundDecals3D — the map's `ground_decals` section drawn on the floor (R3D-SURFACES S2). A ground decal is a GU-sized photographic mark (leaves, mud, a puddle) lying on the floor. It is ANCHORED on the voxel lattice: `at` = (x, y) in GU, any multiple of 1/8 GU (the board's own voxel; it was a half-GU lattice until 2026-10-06), so an integer pair is the shared CORNER of four GUs, `+ 0.5` the middle of an edge, and any other voxel position a place inside a GU. `rot` is free. The size is always one GU. It rides `FloorPile3D`, the path the glass-shard pile and the Tier 4 debris already use, one node set per `kind`. COSMETIC: the map declares it, nothing saves it. The one thing it must not do is outlive its floor, so a decal is dropped when any floor-top voxel of its footprint is gone (a crater under a leaf would show the leaf floating one voxel above it).

**Constants / tuning**
- `ART_DIR` = `"res://ASSETS/materials/_generic/decals/"`
- `MAX_VARIANTS` = `3`
- `LIFT` = `0.021`
- `PRIORITY` = `3`
- `FloorPileRef` = `preload("res://godot/scripts/geometry/floor_pile3d.gd")`
- `SurfaceRulesRef` = `preload("res://godot/scripts/systems/surface_rules.gd")`

**Public API**
- `func attach(board: Node3D, instances: Array, level: int, floor_tags_of: Callable = Callable()) -> void:`
- `func detach() -> void:`
- `func count() -> int:`
- `func refresh(has_floor: Callable) -> void:`

---

### `ground_grid.gd`

`class_name GroundGrid` · extends `RefCounted` · 52 lines

`godot/scripts/geometry/ground_grid.gd`

> GroundGrid — the game's isometric cell lattice as closed-form maths, with no TileMapLayer in it. RENDER3D R3D-5a. Until now every "which cell is here" and "where is this cell" went through `floor_layer.map_to_local()` / `local_to_map()`: a floor TileMapLayer was being asked a question that has one answer, fixed by the TileSet's 256×128 diamond. That kept a 2D tilemap in the middle of INPUT and of every actor's placement, which is what R3D-5 exists to remove. This is the same lattice, measured rather than assumed (2026-09-18, `tileset_blocks.tres` (deleted at R3D-RETIRE-2D), tile_shape ISOMETRIC, layout DIAMOND_DOWN): map_to_local(c) = ((c.x − c.y) · 128 + 128, (c.x + c.y) · 64 + 64) and `ground_grid_selftest` asserts it against a REAL TileMapLayer on the game's own TileSet, for a range of cells and for random points, so this can never quietly disagree with the tilemap it replaces. Coordinates here are FLOOR-LAYER-LOCAL, exactly as `map_to_local()` returns them; the caller applies the layer's transform and the room's `VISUAL_GRID_OFFSET`, as it always did.

**Constants / tuning**
- `HALF_W` = `128.0`
- `HALF_H` = `64.0`

---

### `ground_scatter.gd`

`class_name GroundScatter` · extends `RefCounted` · 131 lines

`godot/scripts/geometry/ground_scatter.gd`

> GroundScatter — expands the map's `ground_scatter` zones into placed stamps (R3D-SURFACES SM-2, 2026-10-06; SURFACES_MASTER_PLAN §4-§5). A scatter ITEM is `{zone, kind, density?, seed, scale?}`: the kind is a CLUSTER STAMP (several decals baked into one image), the zone a rectangle in raw GU. The expansion is a pure function of the item, so it is the same in every run and on every machine (B4: positions come from FNV-1a of `kind|seed|cell`, never from a RNG): a jittered grid of cell side `1 / sqrt(density)` GU, one stamp per cell at a jittered position (snapped to the voxel lattice, 1/8 GU), with a free rotation and a scale in the kind's range. A stamp is dropped when the floor rules forbid its kind under it (`SurfaceRules`: no leaf in the desert) or when something stands where it would lie (a wall, a block, a prop: `blocked`), both QUIETLY here and counted, because a zone of three thousand cells must not print three thousand errors. Stacking is allowed: two stamps may overlap, and so may two kinds in one zone.

**Constants / tuning**
- `SurfaceRulesRef` = `preload("res://godot/scripts/systems/surface_rules.gd")`

---

### `ground_transitions3d.gd`

`class_name GroundTransitions3D` · extends `RefCounted` · 205 lines

`godot/scripts/geometry/ground_transitions3d.gd`

> GroundTransitions3D — the feathered border between two organic ground materials (R3D-SURFACES transitions, 2026-10-06). The floor of a map is a grid of GUs, and each GU wears one material, so where grass meets dirt the eye sees a ruler-straight line. For every floor GU that touches (edge or corner) a GU of a DIFFERENT organic ground, this puts one flat quad over it that wears the neighbour's photographic plane with an alpha feathered by `ground_transition3d.gdshader`: 0.5 on the shared edge, 0 one band-width away, the iso-line moved in and out by a world-space noise. The neighbour does the same with this GU's photo, so both sides show the same mix at the edge and no priority between materials is needed. WHICH pairs: both materials declare a `photo` floor (`MaterialDef.surface_floor`), i.e. organic ground. A human material (concrete, tile) keeps today's hard GU edge; a regular, right-angled transition for those is the same mechanism with no noise and is not built yet. An undeclared GU (the "earth" sentinel) is not a target. COSMETIC, like `GroundDecals3D`: the map declares it, nothing saves it, and a quad whose GU lost any floor-top voxel ends (`refresh()`, from `Room.bump_world_revision()`), so a crater never wears a feather floating over it.

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/ground_transition3d.gdshader"`
- `LIFT` = `0.012`
- `PRIORITY` = `1`
- `NOISE_SIZE` = `256`
- `NOISE_SEED` = `7`
- `NEIGHBOURS` = `[ [Vector2i(-1, 0), 1], [Vector2i(1, 0), 2], [Vector2i(0, -1), 4], [Vector2i(0, 1), 8], [Vector2i(-1, -1), 16], [Vector2i(1, -1), 32], [Vector2i(-1, 1), 64], [Vector2i(1, 1), 128], ]`

**Public API**
- `func attach(board: Node3D, gu_material: Dictionary, is_organic: Callable, level: int) -> void:`
- `func detach() -> void:`
- `func count() -> int:`
- `func refresh(has_floor: Callable) -> void:`

---

### `junction_resolver.gd`

`class_name JunctionResolver` · 181 lines

`godot/scripts/geometry/junction_resolver.gd`

> Geometry Module — Junction Resolver: fills V-junction corner columns. Rewritten (JUNCTION-02): the previous version reconstructed GU cells from voxel-index vertex coordinates and divided them back down by 8. That broke whenever a vertex used the "+7" near-edge offset (true for one axis of almost every vertex _get_edge_vertices produced) instead of a clean multiple of 8 — integer division silently floored into the wrong bucket, so the resolver picked a cell adjacent to the elbow instead of the true diagonal notch. This version never touches voxel coordinates for the detection step: it stays in GU-cell space the whole time, using the faces already recorded on each Edge. Scope: V-junctions (2 walls) and free-standing wall ends (3 walls, all genuinely open — e.g. a divider stopping next to a gate) both get filler columns, one per adjacent (non-opposite) pair of occupied faces at the cell. A true T-junction (a wall butting flush into another, already-solid wall) also presents as 3 faces on a naive count, but EdgeExtractor's exposure culling (see edge_extractor.gd) already removes the spurious flush-contact face before this ever sees it, so it correctly reduces to 2 opposite (straight-through) faces — 0 columns, nothing to fill. This only works because that culling fix landed first; see JUNCTION-01b prompt. X-junctions (4 walls) are intentionally skipped — assumed already covered by surrounding wall geometry; revisit only if a real gap is reported there.

---

### `mesh_prop_instance.gd`

`class_name MeshPropInstance` · 35 lines

`godot/scripts/geometry/mesh_prop_instance.gd`

> Geometry Module — MeshPropInstance: one Tier 3/4 prop's placement record. R3D-PROPS Tier 3/4 (small/medium non-destructible props with cosmetic soot/smoke by proximity, and medium/large organic props that swap for a fragment-cube VFX burst on impact) never become `VoxelStore` state — rule 8 does not apply to them, there is no voxel here to place. This is the data `Board3DLive` reads to build one `PropMesh3D` per instance and `Room` reads to resolve a blast's proximity effect against.

**Public vars**
- `var id: String`
- `var cell: Vector2i`
- `var level: int`
- `var material_id: String`
- `var mesh_tier: int`
- `var mesh_size: Vector3`
- `var surface_materials: Dictionary = {}`
- `var model_path: String = ""`
- `var model_rotation_deg: Vector3 = Vector3.ZERO`
- `var fragment_division: int = 0`
- `var shattered: bool = false`

---

### `object_mesh3d.gd`

`class_name ObjectMesh3D` · extends `Node3D` · 196 lines

`godot/scripts/geometry/object_mesh3d.gd`

> ObjectMesh3D — a free-moving object (a thrown grenade, a spinning pickup, a probe) as a real mesh on the 3D board. RETIRE-2 of R3D-RETIRE-2D. `ACTOR` D65: static props are meshes. This replaces the `Sprite2D` props that reached the board through `PropBillboard3D` from baked frames: the model brings the geometry, OUR material registry the colour (D66, through `PropMesh3D.build_model`), and the board's cell planes the light, so a prop is lit and sooted like the walls around it. THE 2D CONTRACT IS KEPT, THE 2D NODE IS NOT. The thrown grenade's flight is authored in 2D screen space (`ThrowArcOverlay`'s parabola, the landing hop, the roll) and is driven by the controller each frame. Those callers keep handing this node the same two numbers they handed the sprite: `screen_position` (where the object is drawn, lifted off the floor by its flight) and `flight_px` (how far above its own ground point that is). The ground point under it is `screen_position + (0, flight_px)`; `Board3DLive.particle_origin()` turns the pair into the world point, height included, so nothing in the flight is re-derived. The object stands on its base at that point. It is turned about its CENTRE (`set_tumble`) and about the vertical (`yaw`), and its contact shadow lies on the ground under it, sharper and smaller as it nears the floor.

**Constants / tuning**
- `SHADOW_SHADER` = `"res://godot/shaders/ground_overlay3d.gdshader"`
- `SHADOW_LIFT` = `0.005`
- `SHADOW_SEGMENTS` = `12`
- `COS_ELEVATION` = `0.8660254`

---

### `particle_math.gd`

`class_name ParticleMath` · extends `RefCounted` · 89 lines

`godot/scripts/geometry/particle_math.gd`

> ParticleMath — the one place a 2D particle's screen displacement becomes a world displacement. RENDER3D R3D-4e-1. Every VFX overlay simulates in 2D canvas pixels, and folds a particle's height into screen y (smoke "rises" by decreasing y). That is fine on a 2D board and wrong on a 3D one: with no world position a particle cannot be depth-tested, so it draws over a wall it is behind. R3D-WORLD: the POSITION basis is the BASE view's (`Board3DLive.lattice_basis()`), because the 2D simulation runs in the N lattice in every view; the SHAPE basis (a disc, a chip) is the live camera's, so it faces the eye. In view N the two are the same basis. The fix does NOT rewrite the simulation. A particle keeps its 2D state; it also remembers the 3D point it was emitted from (its ANCHOR) and the 2D point that anchor projects to. Its world position is then the anchor plus its 2D displacement carried across EXACTLY: - horizontal screen displacement → along the camera's right axis, ÷ px-per-unit; - vertical screen displacement   → straight UP in the world, ÷ (px-per-unit × cos 30°), because a vertical extent projects to cos(elevation) of its length on screen. Projected back through the camera the particle lands on the pixel the 2D path would have drawn, so the look is unchanged and only the DEPTH is new: a puff at the foot of a wall is behind the wall, and a plume that climbs above its top is in front of what is behind it.

**Constants / tuning**
- `COS_ELEVATION` = `0.8660254`
- `NO_FLOOR` = `Vector2(INF, INF)`
- `NO_ANCHOR` = `Vector3(INF, INF, INF)`

---

### `passage_query.gd`

`class_name PassageQuery` · 301 lines

`godot/scripts/geometry/passage_query.gd`

> PassageQuery — MATERIALS_MASTER_PLAN M3-2. "Can the agent get through this wall, and how?" PURE. It reads `Voxel.damage_state` and writes nothing — no caches, no signals, no side effects — so a prediction can ask it about a hypothetical world exactly the way the committed one is asked (PREDICTION_MASTER_PLAN's split: `build_plan()` is pure, `delta.commit()` is the only writer). THE RULE, Director 2026-08-21: > *"uma parede comum é feita de um par de slices, uma em cada GU anexas. Para > o agente passar agachado (ou transpor uma janela), é necessário que as duas > estejam desobstruídas. Se tiver 4 slices destruídas (2 pares empilhados), o > agente consegue entrar em pé."* ⚠️ THE UNIT THAT STACKS IS THE **STOREY**, not the voxel level, and that correction is the whole of M3-0. The Director's "slice" is *one storey of wall on one GU face* — this file calls it a **storey-face**. The code's `Slice` class is the WHOLE face across every storey (128 voxels at storey_count 2), a different object with the same name. Confusing the two is what made three earlier readings of this rule wrong. Checked, not transcribed: the baked agent is 222 px against `WALL_FLOOR_STEP_PX` 158 — **1.41 storeys tall**. A one-storey opening is 0.71 of him (crouch); two storeys is 1.41x (standing). ⚠️ THIS ANSWERS GEOMETRY, NOT REACHABILITY. `passage_class()` says an opening of a given size exists somewhere in this wall; it does NOT say the agent can stand in front of it. A hole two storeys up is a window, and whether he can reach it is the movement system's question — which is why `clear_storeys()` is public and returns WHICH storeys are open, rather than this file quietly deciding that only an opening at storey 0 counts. The Director's own wording covers both cases in one sentence (*"passar agachado (ou transpor uma janela)"*), so the distinction is real and is not this query's to make.

---

### `pick_math.gd`

`class_name PickMath` · extends `RefCounted` · 27 lines

`godot/scripts/geometry/pick_math.gd`

> PickMath — the pure geometry of picking (kept out of `Board3DLive`, which needs the autoloads and so cannot be loaded headless by a selftest).

---

### `prop_block.gd`

`class_name PropBlock` · extends `VoxelContainer` · 25 lines

`godot/scripts/geometry/prop_block.gd`

> Geometry Module — PropBlock: one destructible prop's solid voxel fill, one GU cell wide. R3D-PROPS Tier 1/2 (crates and other square props render through the SAME `VoxelStore` mechanism as a wall — this is that mechanism's container, mirroring Slice's minimal contract (id, material, voxels, dirty bookkeeping) since `VoxelStore._fill()` reads containers duck-typed, not by class: any object with those fields fills the same way. v1 scope matches `PropDef`'s own doc ("whole-storey granularity only"): one fixed material, a solid box, no per-voxel bitmask (PROP-01 Item 0-A defers that).

**Public vars**
- `var id: String`
- `var material: String`
- `var floor_level: int = -1`

---

### `prop_fragment_sim.gd`

`class_name PropFragmentSim` · extends `RefCounted` · 360 lines

`godot/scripts/geometry/prop_fragment_sim.gd`

> PropFragmentSim — what a Tier 4 prop does in the half second after a blast, as pure deterministic maths. PROPS_TIER4_PLAN P2 / `ACTOR` D67. The prop has been voxelized (`PropVoxelizer`, board-size cubes that keep its shape). This moves those cubes: they fall from where the prop stood; the blast carves away the ones nearest it (by the ring weight) and pushes the rest outward; what is left lands, STACKS on the column under it, slumps downhill, and ends as a pile of charred cubes on the board's own voxel lattice. No Godot physics, no scene, no `randf()`: every roll is a hash of (seed, fragment), so the same blast on the same prop gives the same pile (a replay, a rotation and a test all see one answer). TIMED, NOT COUNTED. `advance(delta)` runs fixed 1/60 s steps of SIMULATED time, so 0.5 s is 0.5 s on a 30 fps handset (15 drawn frames) and on the desktop (30) alike; a long frame runs several steps, capped so a hitch can never spiral. SPACE. World units are GU (1.0 = one game unit; the board voxel is 1/8). `origin` is the world position of the prop's local (0, 0, 0): the floor, on a voxel boundary in X/Z, so a local cell index plus `origin / voxel` is the board's own voxel column.

**Constants / tuning**
- `GRAVITY` = `8.0`
- `STEP` = `1.0 / 60.0`
- `MAX_STEPS_PER_ADVANCE` = `8`
- `MAX_SIM_TIME` = `1.6`
- `SLIDE_TIME` = `0.07`
- `PUSH_SPEED` = `1.3`
- `PUSH_UP` = `1.2`
- `CHAR_TIME` = `0.30`
- `P_TONE` = `1`
- `P_JIT` = `2`
- `P_DESTROY` = `3`
- `P_VANISH` = `4`
- `P_DIR` = `5`
- `P_SPEED` = `6`
- `P_UP` = `7`
- `P_SX` = `8`
- `P_SY` = `9`
- `P_SZ` = `10`
- `P_SLUMP` = `100`

**Public vars**
- `var count: int = 0`
- `var voxel: float = 0.125`
- `var origin: Vector3 = Vector3.ZERO`
- `var weight: float = 1.0`
- `var time: float = 0.0`
- `var wave_time: float = 0.06`
- `var pos: PackedVector3Array = PackedVector3Array()`
- `var vel: PackedVector3Array = PackedVector3Array()`
- `var euler: PackedVector3Array = PackedVector3Array()`
- `var spin: PackedVector3Array = PackedVector3Array()`
- `var state: PackedInt32Array = PackedInt32Array()`
- `var zone: PackedInt32Array = PackedInt32Array()`
- `var level: PackedInt32Array = PackedInt32Array()`
- `var column: Array[Vector2i] = []`
- `var tone: PackedFloat32Array = PackedFloat32Array()`
- `var jitter: PackedFloat32Array = PackedFloat32Array()`
- `var vanish_at: PackedFloat32Array = PackedFloat32Array()`

**Public API**
- `func is_done() -> bool:`
- `func advance(delta: float) -> void:`
- `func step() -> void:`
- `func pile_records() -> Array:`
- `func vanished_count() -> int:`
- `func char_amount(i: int) -> float:`
- `func char_finished() -> bool:`
- `func rotation_of(i: int) -> Basis:`

---

### `prop_fragments3d.gd`

`class_name PropFragments3D` · extends `Node3D` · 236 lines

`godot/scripts/geometry/prop_fragments3d.gd`

> PropFragments3D — the voxel fragments of one broken prop, in ONE draw call, depth-tested, lit by the board's planes. PROPS_TIER4_PLAN P2 / `ACTOR` D67. While a `PropFragmentSim` runs, this node moves the cubes every frame; when the sim is done it keeps only the landed ones as a static pile. `make_pile()` builds the same thing from saved records (a checkpoint restore rebuilds the board and drops every node, so the pile is laid back from `Room._base_prop_piles`). ONE MultiMesh of a cube of the FRAGMENT lattice (the board voxel, 1/8 GU, divided by the prop's `division`; the sim says which), the `ShardField3D` precedent: `custom_aabb` set (a MultiMesh's bounds come from its base mesh, so without it every cube away from the node origin is culled). The material is the board's prop shader with `use_color`: the cell planes give it light and soot, the per-instance colour gives it the prop's material colour, each cube's small brightness variation and its charring. The colour is handed over in linear (vertex colour is linear, the shader's `albedo` is sRGB). COLOUR COMES FROM THE MATERIAL REGISTRY (`ACTOR` D66): each fragment carries the zone of the surface it came from, and a zone is a material id (`zone_materials[zone]`, resolved through the fallback chain). The node draws with the facade of the material most of its cubes are made of (one draw call, one texture): the others keep their own colour under that detail.

**Signals**
- `signal settled(records: Array)`

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/prop_mesh3d.gdshader"`
- `FLOATS_PER_INSTANCE` = `16`

**Public API**
- `func setup(board: Node3D, sim: PropFragmentSim, zone_materials: Array) -> void:`
- `func is_finished() -> bool:`
- `func floor_y() -> float:`
- `func voxel_size() -> float:`
- `func finish_now() -> void:`

---

### `prop_mesh3d.gd`

`class_name PropMesh3D` · extends `Node3D` · 130 lines

`godot/scripts/geometry/prop_mesh3d.gd`

> PropMesh3D — a static prop as a real mesh on the 3D board. RENDER3D R3D-PROPS (`ACTOR` D65: static props are meshes, destructible ones are voxels — a destructible prop like `crate_full` already renders through the store, rule 8, no new path here). Lit the board's way (`prop_mesh3d.gdshader`, promoted from R3D-SPIKE-3D's measured spike): no Godot light, one cell-plane fetch, kept in sync by `Board3DLive.register_prop_light_material()`. Placement uses the same voxel-grid convention `Board3DLive._emit_quad()` uses for a TOP face: one world unit is `GeometryCoords.VOXELS_PER_UNIT_AXIS` voxels, and a level's top sits at `(level + 1 - ground_level)` world-Y units. A mesh's own local origin is assumed centred horizontally and resting on Y=0 (its base), so it is placed directly on the level's top face with no extra offset.

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/prop_mesh3d.gdshader"`

**Public API**
- `func setup(board: Node3D, mesh: Mesh, cell: Vector2i, level: int, albedo: Color, mesh_half_height: float) -> void:`
- `func setup_model(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3, cell: Vector2i, level: int, surface_materials: Dictionary = {}, default_material: String = "generic") -> void:`
- `func build_model(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3, surface_materials: Dictionary = {}, default_material: String = "generic") -> Dictionary:`

---

### `prop_model_fit.gd`

`class_name PropModelFit` · 125 lines

`godot/scripts/geometry/prop_model_fit.gd`

> PropModelFit — a prop model (glTF/GLB, or a plain box) fitted into its `mesh_size`: turned by `rotation_deg`, scaled uniformly to fit, standing on Y = 0 and centred on X/Z (so local X/Z = 0 is the cell's centre, a board-voxel boundary, and local Y = 0 is the floor). One answer, used by the thing that DRAWS the prop (`PropMesh3D.setup_model`) and by the thing that turns it into voxels (`PropVoxelizer`), so the two can never disagree about where the prop is. Cached per (path, rotation, fit size): a model is built once and every instance of it shares the parts (PROP_PIPELINE_PLAN §1b, several instances of one model). A part is {"mesh": Mesh, "xf": Transform3D}, `xf` already carrying the fit. `surfaces` is the name of the material each surface was authored with, in the order `PropVoxelizer` numbers its zones (across the parts).

---

### `prop_shadow.gd`

`class_name PropShadow` · 141 lines

`godot/scripts/geometry/prop_shadow.gd`

> PropShadow — a prop's contact shadow, built from its voxels (PROPS_TIER4_PLAN P6, `ACTOR` D68). THE SHAPE comes from the prop's own voxel set (the same kind of data `PropVoxelizer` gives a mesh prop and the store gives a voxel prop), so a table casts a tabletop and four thin legs, a crate a block, a pile a small heap. Each vertical run of voxels in a column is swept along the key light onto the floor (a parallelogram), rasterised into a small image (`TEXELS_PER_VOXEL` per voxel), blurred a hair for a soft edge, and drawn as ONE flat quad with `prop_shadow3d.gdshader`. No shadow maps, no per-frame work: the image is built when a prop appears and again only when its voxels change (a blast or a shot), and a prop that is gone takes its shadow with it. Coordinates are ABSOLUTE board voxels (x, y = UP, z), the same lattice as everything else: world = voxel / 8.

**Constants / tuning**
- `TEXELS_PER_VOXEL` = `2`
- `PAD_VOXELS` = `2`
- `KEY_DIR` = `Vector3(-0.45, 0.8, 0.4)`
- `SHADER_PATH` = `"res://godot/shaders/prop_contact_shadow3d.gdshader"`

---

### `prop_voxelizer.gd`

`class_name PropVoxelizer` · 212 lines

`godot/scripts/geometry/prop_voxelizer.gd`

> PropVoxelizer — turns any fitted model (`PropModelFit`) into board-size voxels, keeping its SHAPE. PROPS_TIER4_PLAN P1 / `ACTOR` D67. A voxel here is one board voxel (1/8 GU, `VOXELS_PER_UNIT_AXIS` per axis) divided by `division` (1, 2 or 4): the FRAGMENT lattice. A prop that is about to be destroyed does not have to obey the world's voxel size, so a thin table top and thin legs are rasterised on a finer lattice (division 4 = 1/32 GU = 5 cm) and still read as the table they were (Director, 2026-09-30). The lattice is the board's own, only subdivided: local X/Z = 0 is a voxel boundary at any division (a cell's centre is 4 x division voxels in) and local Y = 0 is a level boundary, so a cell index is the offset from the prop's cell centre / floor. METHOD. Every triangle marks each voxel whose box it overlaps (Akenine-Moller's separating-axis test, conservative: a leg thinner than a voxel is still a column). A table keeps its top plate and its legs because SURFACES are rasterised, not the bounding box. A cell takes the zone (the surface index across the model's parts) of the first triangle that marked it. The output is sorted (y, z, x), so the same model always gives the same bytes. Generic on purpose: it knows nothing about tables. Whatever a `mesh_tier 4` prop is, this is what its fragments are made from; a box (the placeholder, or a slot's generic) voxelizes to a box.

**Constants / tuning**
- `TOUCH_EPS` = `1.0e-4`
- `MAX_DIVISION` = `4`
- `FRAGMENT_BUDGET` = `900`
- `CELLS_PER_AREA` = `0.8`

---

### `quad_field3d.gd`

`class_name QuadField3D` · extends `RefCounted` · 185 lines

`godot/scripts/geometry/quad_field3d.gd`

> QuadField3D — many camera-facing rectangles on the 3D board, in ONE draw call, depth-tested. RENDER3D R3D-4e-3. The base of `CircleField3D` (discs) and the field for everything the VFX draw as a line or a polygon: spark and shrapnel streaks, rotated debris chips. A rectangle is a centre and two half-extent vectors in 2D SCREEN space; `ParticleMath` carries all three into the world, so a line is a thin rectangle and a chip is a rotated one, with no per-shape code. Everything `CircleField3D`'s header says holds here: one quad built once, only a transform and a colour per instance per frame, `custom_aabb` set (a MultiMesh's bounds come from its base mesh, and without the box every instance far from the origin is culled), instances draw in push order, and `priority` stands in for the 2D z-order between fields.

**Constants / tuning**
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `SHADER_RECT` = `"res://godot/shaders/particle_quad3d.gdshader"`
- `FLOATS_PER_INSTANCE` = `16`

---

### `shard_field3d.gd`

`class_name ShardField3D` · extends `RefCounted` · 134 lines

`godot/scripts/geometry/shard_field3d.gd`

> ShardField3D — the glass rain's shards on the 3D board, in ONE draw call, depth-tested. RENDER3D R3D-4e-4. The 3D twin of `ShardField`: a MultiMesh of quads, each carrying its shape's atlas cell in the instance custom data, so 3000 shards are one draw call. Unlike the other 3D fields it takes a WORLD position per shard, not an anchor + a 2D displacement: a shard travels between two real 3D points (its pane and its landing), and interpolating them in 3D puts it at the right depth all the way, where carrying a 2D displacement would drift a scattered landing off the floor it lands on. `custom_aabb` is set for the reason `CircleField3D`'s header gives: culling bounds come from the base mesh, so without the box every shard far from the origin is culled.

**Constants / tuning**
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `SHADER_PATH` = `"res://godot/shaders/glass_shard_field3d.gdshader"`
- `FLOATS_PER_INSTANCE` = `20`

**Public API**
- `func attach(parent: Node3D, priority: int = 0) -> void:`
- `func detach() -> void:`
- `func begin_on_board(capacity: int) -> void:`
- `func push(pos: Vector3, size_px: float, rot: float, shape_index: int, color: Color, flip: bool = false, flop: bool = false) -> void:`
- `func flush() -> void:`
- `func live_count() -> int:`
- `func clear() -> void:`

---

### `slab.gd`

`class_name Slab` · extends `VoxelContainer` · 76 lines

`godot/scripts/geometry/slab.gd`

> Geometry Module — Slab: horizontal voxel container (floor, ceiling, interior) DESTRUCTION_MASTER_PLAN D1: the container sibling of Slice for the horizontal plane. A wall voxel belongs to a Slice which belongs to an Edge; a floor/ceiling voxel has no edge, so it gets this container instead — same dirty-count/TIC-skip contract as Slice, none of the edge-specific fields (face, edge_id). Floor, ceiling and interior cutaway are ONE class: a ceiling is a Slab at a different level/role, not a different type. See voxel.gd's Voxel._parent_container_id for why Voxel is shared unmodified between Slice and Slab, and why it points back by instance id rather than by reference. LEAK-CYCLE-01: a Slab owns its `voxels` strongly and they point back weakly, so dropping the Slab frees the whole cluster. Whoever builds a Slab must keep it alive for as long as its voxels are in use — SlabRegistry does that for every real Slab; a fixture that hands out voxels without their Slab has to anchor the Slab itself.

**Public vars**
- `var id: String`
- `var gu_cell: Vector2i`
- `var role: int`
- `var level: int`
- `var material: String`
- `var texture_anchor: Vector2i = Vector2i.ZERO`

---

### `slab_generator.gd`

`class_name SlabGenerator` · 63 lines

`godot/scripts/geometry/slab_generator.gd`

> Geometry Module — Slab Generator: creates Slabs and Voxels for one GU's horizontal footprint (floor/ceiling/interior). Mirrors SliceGenerator, but a Slab has no Edge to derive from — it's just a GU cell, a role and a level.

---

### `slab_registry.gd`

`class_name SlabRegistry` · 44 lines

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

---

### `slice.gd`

`class_name Slice` · extends `VoxelContainer` · 66 lines

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
- `var baked: bool = false`
- `var pane_id: String = ""`
- `var material_bands: Dictionary = {}`
- `var glass_class: int = GlassMaterials.CLASS_UNSET`

**Public API**
- `func has_material_bands() -> bool:`
- `func material_at(rel_level: int) -> String:`
- `func total_voxel_count() -> int:`

---

### `slice_generator.gd`

`class_name SliceGenerator` · 108 lines

`godot/scripts/geometry/slice_generator.gd`

> Geometry Module — Slice Generator: creates Slices and Voxels from Edges Port from room.gd _place_wall_voxels() and _voxel_slice_positions() logic

---

### `vision_cone3d.gd`

`class_name VisionCone3D` · extends `MeshInstance3D` · 73 lines

`godot/scripts/geometry/vision_cone3d.gd`

> VisionCone3D — a guard's smooth vision cone, drawn on the 3D board's ground plane. RENDER3D R3D-4c. The 2D cone was painted at z −4 under everything the 2D board drew above it, so a wall covered it. The 2D canvas draws over the 3D board, so left in 2D the cone would paint across walls and over the actors. Here it is a triangle fan on the ground, a hair above it, depth-tested: geometry covers it, actors stand over it. ONE AUTHORITY. The polygon is the guard's own (`_draw_vision_smooth_body` — LOS cuts, fov, range, the fade to alpha 0 at the rim). The guard publishes it through `vision_smooth_ready` while it is computed (on request, once per change, while the guard is visible); this only re-expresses each 2D point on the ground.

**Constants / tuning**
- `GROUND_LIFT` = `0.02`

**Public API**
- `func setup(board: Node3D, guard: Node2D) -> void:`

---

### `voxel.gd`

`class_name Voxel` · 227 lines

`godot/scripts/geometry/voxel.gd`

> Geometry Module — Voxel: thin index wrapper over one claim in VoxelStore RENDER3D R3D-1d: Voxel used to duplicate every field VoxelStore now packs. Since R3D-1c closed with all five readers on the store, that duplication was ~191 MB on the Moto for nothing the store didn't already answer. Voxel keeps its exact public surface (grid_pos, level, visible, damage_state, ..., set_damage(), set_visible()) so every existing caller (room.gd, agent_shot_controller.gd, blast_calculator.gd, glass_crack.gd, Slice/Slab/JunctionColumn) is unchanged — only what sits behind that surface moved to VoxelStore's packed arrays, addressed by `claim`.

**Public vars**
- `var grid_pos: Vector2i`
- `var level: int`
- `var dirty: bool:`
- `var claim: int = -1`
- `var visible: bool:`
- `var damage_state: int:`
- `var damage_is_blast: bool:`
- `var damage_carved_side: int:`
- `var damage_variant: int:`
- `var damage_substrate: int:`

**Public API**
- `func container_id() -> int:`
- `func set_visible(v: bool) -> void:`
- `func set_damage(new_state: int, from_blast: bool = false, carved_side: int = CarvedSide.NONE, variant: int = 0, substrate: int = 0) -> void:`
- `func clear_dirty() -> void:`

---

### `voxel_board.gd`

`class_name VoxelBoard` · extends `Node2D` · 2460 lines

`godot/scripts/geometry/voxel_board.gd`

> Geometry Module — VoxelBoard: the state of the voxel board that the 3D board (`Board3DLive`) draws. It renders nothing. Its levels are a registry (`level_origin()`, `level_z_index()`, `voxel_world_position()`), it owns the light and soot cell planes and their application, it turns dirty voxels into `voxel_destroyed`, and it keeps the glass crack / rim / shard-pile records the 3D board mirrors. Until R3D-END (2026-09-25) it was `VoxelRenderer`, a `TileMapLayer` renderer; this rename came after the 2D board was deleted (END-0 to END-6) and changed no behaviour. Extends Node2D so the 2D overlays that still parent to it keep working.

**Signals**
- `signal voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String)`

**Constants / tuning**
- `GlassOpening` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `IMPACT_DECAL_MATERIALS` = `["concrete", "metal", "stone", "wood", "brick"]`
- `IMPACT_DECAL_VARIANTS` = `3`
- `GlassCrackParamsClass` = `preload("res://godot/scripts/systems/destruction/glass_crack_params.gd")`
- `CRAZE_MASK_TEXELS_PER_VOXEL` = `6`
- `FloorPile3DRef` = `preload("res://godot/scripts/geometry/floor_pile3d.gd")`
- `PropMesh3DRef` = `preload("res://godot/scripts/geometry/prop_mesh3d.gd")`

**Public vars**
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`
- `var render_frame_budget_ms: float = 200.0`

**Public API**
- `func build_occupancy(predict_destroyed: Dictionary = {}) -> Dictionary:`
- `func build_occupancy_live(changes: Array[Vector3i]) -> Dictionary:`
- `func build_occupancy_live_erasing(predict: Dictionary, changes: Array[Vector3i], erased: Array[Vector3i]) -> Dictionary:`
- `func columns_with_structure() -> Dictionary:`
- `func note_external_write(level: int, cell: Vector2i) -> void:`
- `func apply_light_field(field) -> void:`
- `func apply_light_field_cells(field, cells: Dictionary) -> void:`
- `func apply_light_field_gus(field, gus: Array) -> void:`
- `func process_dirty(registry: EdgeRegistry) -> void:`
- `func process_dirty_slabs(registry: SlabRegistry) -> void:`
- `func process_dirty_async(registry: EdgeRegistry, states: Array = []) -> void:`
- `func process_dirty_slabs_async(registry: SlabRegistry, states: Array = []) -> void:`
- `func glass_crack_covering(pane_id: String, run: int, level: int) -> int:`
- `func spawn_glass_crack(spec: Dictionary) -> int:`
- `func spawn_glass_craze(spec: Dictionary) -> int:`
- `func spawn_floor_shard_pile(level: int, cell: Vector2i, count: int, variant: int) -> bool:`
- `func set_pile_board3d(board: Node3D) -> void:`
- `func place_debris_piece(id, center: Vector2, level: int, material_id: String, variant: int, tint: Color, rot: float = 0.0) -> void:`
- `func place_prop_demo(board: Node3D, prop_id: String, cell: Vector2i, level: int) -> void:`
- `func clear_floor_shards() -> void:`
- `func floor_shard_pile_count() -> int:`
- `func floor_shard_pile3d_count() -> int:`
- `func set_glass_cracks_visible(v: bool) -> void:`

---

### `voxel_container.gd`

`class_name VoxelContainer` · extends `RefCounted` · 252 lines

`godot/scripts/geometry/voxel_container.gd`

> Geometry Module — VoxelContainer: what `Slice`, `Slab`, `JunctionColumn` and `PropBlock` share, the voxels and their dirty count. R3D-CLAIMS C2. A container used to OWN every `Voxel` object it generated, for the life of the board: ~296 000 of them on PLAYGROUND, ~990 B each on the Moto (~270 MB of a 1.30 GB peak). Since R3D-1d a `Voxel` holds no state (its fields are read and written through `VoxelStore`, by `claim`), so the object is only a handle, and a handle can be made again when someone asks for it. A container therefore has two modes: FULL (the default, and every fixture): `_voxels` holds the objects, exactly as before. A selftest that builds a container with `container.voxels.append(Voxel.new(...))` is in this mode and never leaves it. RELEASED (a live board, after `VoxelStore.build(..., release_objects = true)`): the objects are gone; `_sparse` has one slot per claim, null until `voxel_at(i)` makes the handle (cached, so a claim keeps ONE object: a Dictionary keyed by `Voxel` stays consistent). `voxels` converts the container to FULL, reusing the handles it already made, for the readers that walk a whole container; `Stats` counts those, so a reader that walks the whole board shows up as a number, not as ~270 MB. R3D-CLAIMS C4 adds a third mode BEFORE the store exists, so the generators make no object at all: CELLS (what `SliceGenerator`, `SlabGenerator` and `JunctionColumn` fill, through `add_cell()`): `_cells` holds x, y, level per voxel, 12 B each instead of an object (~4.3 us to make, ~990 B to keep on the Moto). `VoxelStore._fill()` reads them and the container goes straight to RELEASED. A reader that asks for `voxels` BEFORE the store is built converts the container to FULL (the objects it always had) and `Stats.from_cells` counts it, so a build-time reader that walks the board shows as a number. A reader that wants one claim asks `voxel_at(i)`; one that wants a count asks `voxel_count()`; one that wants the whole container (a blast over an affected slice) reads `voxels`, as it always did.

**Public vars**
- `var dirty_count: int = 0`
- `var voxels: Array[Voxel]:`

**Public API**
- `func add_cell(x: int, y: int, level: int) -> void:`
- `func voxel_count() -> int:`
- `func cells_packed() -> PackedInt32Array:`
- `func has_cells_only() -> bool:`
- `func voxel_at(i: int) -> Voxel:`

---

### `world_canvas3d.gd`

`class_name WorldCanvas3D` · extends `RefCounted` · 242 lines

`godot/scripts/geometry/world_canvas3d.gd`

> WorldCanvas3D — a 2D overlay's drawing that has HEIGHT (a tracer, a throw arc, a lamp), as world geometry on the 3D board. R3D-WORLD. `GroundCanvas3D` lifts what lies on the floor; it cannot place a point above it, because a 2D canvas point folds height into screen y and the floor beneath it is lost. The overlays that draw in the air already know that floor (a muzzle is above the agent's feet, an arc sample above the lerp of its two ground ends), so they hand this canvas the pair and it asks the board for the world point: `Board3DLive.particle_origin()`, the VFX's own rule, through the BASE view's basis (`lattice_basis()`), so the point is world state and stays put when the view turns. LINES are ribbons `width_px` wide (2D canvas pixels, as the 2D call took them) turned to face the LIVE camera; they are rebuilt when the view changes (`Board3DLive.view_changed` asks the owner to redraw). Depth-tested by default, so a wall hides what is behind it; `on_top` draws over everything, the way the 2D overlay did.

**Constants / tuning**
- `SHADER` = `"res://godot/shaders/ground_overlay3d.gdshader"`
- `CIRCLE_SEGMENTS` = `24`

**Public API**
- `func attach(board: Node3D, owner: CanvasItem, priority: int = 0, on_top: bool = false) -> void:`
- `func detach() -> void:`
- `func begin() -> void:`
- `func end() -> void:`
- `func clear() -> void:`
- `func begin_empty() -> void:`
- `func lift(point_2d: Vector2, floor_2d: Vector2) -> Vector3:`
- `func line(a: Vector3, b: Vector3, color: Color, width_px: float) -> void:`
- `func polyline(points: PackedVector3Array, color: Color, width_px: float) -> void:`
- `func disc(centre: Vector3, radius_px: float, color: Color) -> void:`
- `func polygon(points: PackedVector3Array, color: Color) -> void:`
- `func ring(centre: Vector3, radius_px: float, color: Color, width_px: float) -> void:`
- `func up(px: float) -> Vector3:`

---

## navigation/

### `guard_pathfinder.gd`

`class_name GuardPathfinder` · 80 lines

`godot/scripts/navigation/guard_pathfinder.gd`

---

### `movement_overlay.gd`

`class_name MovementOverlay` · extends `Node2D` · 287 lines

`godot/scripts/navigation/movement_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `BLUE_LINE` = `Color(0.25, 0.70, 1.0, 0.90)`
- `ORANGE_LINE` = `Color(1.0, 0.60, 0.20, 0.95)`
- `PERIMETER_INSET_DISTANCE` = `6.0`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var ground_size: Callable = Callable()`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var origin_cell: Vector2i = Vector2i(-9999, -9999)`
- `var max_path_cost: int = 0`

**Public API**
- `func setup(offset: Vector2, points_per_ap: int = 3) -> void:`
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
- `func set_board3d(board: Node3D) -> void:`

---

### `path_preview.gd`

`class_name PathPreview` · extends `Node2D` · 87 lines

`godot/scripts/navigation/path_preview.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `PREVIEW_LINE` = `Color(1.0, 0.79, 0.18, 0.95)`
- `PREVIEW_FILL` = `Color(1.0, 0.76, 0.20, 0.22)`
- `TARGET_LINE` = `Color(1.0, 0.45, 0.10, 0.95)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func setup(offset: Vector2) -> void:`
- `func set_path(cells: Array[Vector2i], ap_cost: int) -> void:`
- `func clear_path() -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

## overlays/

### `aim_bubble_overlay.gd`

`class_name AimBubbleOverlay` · extends `Node2D` · 816 lines

`godot/scripts/overlays/aim_bubble_overlay.gd`

**Constants / tuning**
- `SEG_STRIDE` = `6`
- `SEG_AXIS_X` = `0`
- `SEG_POS` = `1`
- `SEG_SPAN_MIN` = `2`
- `SEG_SPAN_MAX` = `3`
- `SEG_Z_MIN` = `4`
- `SEG_Z_MAX` = `5`
- `WorldCanvas3DRef` = `preload("res://godot/scripts/geometry/world_canvas3d.gd")`

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
- `func set_board3d(board: Node3D) -> void:`
- `func show_dome(center: Vector2, radius_gu: float, center_gu: Vector2i, wall_height_edges: Dictionary) -> void:`

---

### `blast_wireframe_overlay.gd`

`class_name BlastWireframeOverlay` · extends `Node2D` · 147 lines

`godot/scripts/overlays/blast_wireframe_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `LINE_COLOR` = `Color(1.0, 0.15, 0.15, 0.9)`
- `LINE_WIDTH` = `3.0`
- `PERIMETER_INSET_DISTANCE` = `6.0`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var ring_fill_alphas: PackedFloat32Array = PackedFloat32Array([0.34, 0.22, 0.13])`

**Public API**
- `func setup(visual_grid_offset: Vector2) -> void:`
- `func show_footprint(cells, ring_by_cell: Dictionary = {}) -> void:`
- `func clear() -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `ceiling_prop_overlay.gd`

`class_name CeilingPropOverlay` · extends `Node2D` · 58 lines

`godot/scripts/overlays/ceiling_prop_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `WorldCanvas3DRef` = `preload("res://godot/scripts/geometry/world_canvas3d.gd")`

**Public API**
- `func set_board3d(board: Node3D) -> void:`
- `func setup(visual_offset: Vector2, ceiling_lift: float) -> void:`
- `func set_lights(light_sources: Array) -> void:`

---

### `debris_overlay.gd`

`class_name DebrisOverlay` · extends `Node2D` · 416 lines

`godot/scripts/overlays/debris_overlay.gd`

**Constants / tuning**
- `CircleField3DRef` = `preload("res://godot/scripts/geometry/circle_field3d.gd")`
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `QuadField3DRef` = `preload("res://godot/scripts/geometry/quad_field3d.gd")`

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
- `var glass_dust_count_min: int = 10`
- `var glass_dust_count_max: int = 18`
- `var glass_dust_delay_min: float = 0.04`
- `var glass_dust_delay_max: float = 0.16`
- `var glass_dust_spread_min: float = 0.28`
- `var glass_dust_spread_max: float = 0.46`
- `var glass_dust_settle_min: float = 0.5`
- `var glass_dust_settle_max: float = 0.9`
- `var glass_dust_speck_radius: float = 2.0`
- `var glass_dust_flatten: float = 0.5`
- `var glass_dust_concentration: float = 1.7`
- `var glass_dust_alpha_gain: float = 1.35`
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
- `var trickle_count_min: int = 9`
- `var trickle_count_max: int = 13`
- `var trickle_delay: float = 0.5`
- `var trickle_span_min: float = 0.35`
- `var trickle_span_max: float = 0.6`
- `var trickle_fall_min: float = 0.45`
- `var trickle_fall_max: float = 0.65`
- `var trickle_rest_min: float = 0.3`
- `var trickle_rest_max: float = 0.5`
- `var trickle_sway: float = 1.1`
- `var trickle_pile_spread: float = 3.2`
- `var trickle_dash_half: Vector2 = Vector2(0.5, 2.0)`
- `var trickle_opacity: float = 0.5`
- `var trickle_origin_shift: Vector2 = Vector2(2.0, -3.0)`
- `var trickle_start_radii: Vector2 = Vector2(3.0, 3.6)`

**Public API**
- `func add_dust(origin: Vector2, target: Vector2, color: Color) -> void:`
- `func add_sand_trickle(origin: Vector2, target: Vector2, color: Color) -> void:`
- `func add_glass_dust(center: Vector2, reach: float, color: Color) -> void:`
- `func add_chips(origin: Vector2, target: Vector2, count: int, color: Color) -> void:`
- `func set_board3d(board: Node3D) -> void:`
- `func clear() -> void:`

---

### `elite_exposure_overlay.gd`

extends `Node2D` · 255 lines

`godot/scripts/overlays/elite_exposure_overlay.gd`

> EliteExposureOverlay — Advanced Tactical Vision for Stealth Mastery Displays sophisticated shadow semantics: - Shadow depth (gradient 0-6) - Exposure confidence (reliability of darkness) - Structural vs temporal shadows - Risk contours and safe corridors - Temporal instability zones NOT visible in normal gameplay. Appears in: - DEV_VISION overlay - Spectator modes - Future elite HUD (equipment unlock) Purpose: Enable high-skill stealth mastery and tactical reading.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

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
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func load_exposure_system(sys) -> void:`
- `func set_board3d(board: Node3D) -> void:`
- `func toggle_mode(mode: String) -> void:`
- `func debug_info() -> String:`

---

### `ember_overlay.gd`

`class_name EmberOverlay` · extends `Node2D` · 399 lines

`godot/scripts/overlays/ember_overlay.gd`

---

### `explosion_flash_overlay.gd`

`class_name ExplosionFlashOverlay` · extends `Node2D` · 268 lines

`godot/scripts/overlays/explosion_flash_overlay.gd`

**Constants / tuning**
- `NEGATIVE_FLASH_SHADER` = `"""`
- `KEEPALIVE_SECONDS` = `2.0`

**Public vars**
- `var strobe_white_alpha: float = 1.0`
- `var strobe_negative_amount: float = 1.0`
- `var strobe_negative_desaturate: float = 1.0`
- `var flash_mode: int = FlashMode.NEGATIVE`

**Public API**
- `func set_negative_z_index(z: int) -> void:`
- `func hold_frame(mode: int) -> void:`
- `func warm() -> void:`
- `func clear() -> void:`

---

### `exposure_overlay.gd`

extends `Node2D` · 164 lines

`godot/scripts/overlays/exposure_overlay.gd`

> ExposureOverlay — Tactical Visibility Classification Visualization Displays the semantic stealth visibility of each tile as computed by ExposureSystem. This overlay shows tactical exposure, NOT visual brightness. Colors represent stealth risk: - Yellow: FULL_LIT (high risk) - Orange: DIM (moderate risk) - Blue: PENUMBRA (low risk) - Purple: SHADOW (minimal risk) - Dark Blue/Black: DEEP_SHADOW (hidden)

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `EXPOSURE_SYSTEM_CLASS` = `preload("res://godot/scripts/systems/lighting/exposure_system.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var exposure_system`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `floating_collectible.gd`

`class_name FloatingCollectible` · extends `ObjectMesh3D` · 75 lines

`godot/scripts/overlays/floating_collectible.gd`

> A floating, spinning pickup — the reusable "simplification" display for any object (`ACTOR_MASTER_PLAN` D21/D17/D14) — as a real mesh (RETIRE-2 of R3D-RETIRE-2D; D65). It was a `Sprite2D` cycling 120 baked frame pairs (colour + normal map + two shadow layers, ~48 MB of VRAM per pickup) through a per-pixel relight shader and mirrored into the 3D board by `PropBillboard3D`. Now the model IS in the world: coloured by OUR material registry (D66), lit by the board's cell planes, turning about the vertical by real yaw (so there is no frame count, no frame cache and no per-view re-pick), and its ground shadow is one soft disc that follows the bob. Behaviour kept from the sprite (Director, 2026-07-27/28): it hovers `HOVER_HEIGHT_PX` above its floor point, bobs with a sine of `BOB_AMPLITUDE_PX` (raised from 6 because the shadow needs the separation to read) over `BOB_PERIOD_SEC`, and spins at `ROTATION_DEG_PER_SEC`. The ground shadow stays pinned to the floor ("deixar claro onde está posicionada a arma em relação ao chão"): small and sharp (alpha 0.55) at the bottom of the bob, bigger and softer (alpha 0.28) at the top. DROPPED WITH THE FRAMES: the static-facing mode ("4 shotguns pointing at the blocks"), which was a frame frozen on a compass yaw measured from the bake; nothing calls it (the weapon bench places no weapons), and a mesh yaw for a model's muzzle would be a new measurement, not a port. `outline_color` and the saturation/contrast grade belonged to the sprite shader.

**Constants / tuning**
- `ROTATION_DEG_PER_SEC` = `36.0`
- `BOB_AMPLITUDE_PX` = `18.0`
- `BOB_PERIOD_SEC` = `2.0`
- `HOVER_HEIGHT_PX` = `60.0`
- `SHADOW_STRENGTH_AT_BOTTOM` = `0.55`
- `SHADOW_STRENGTH_AT_TOP` = `0.28`
- `SHADOW_SOFTNESS_AT_TOP` = `0.6`
- `SHADOW_SCALE_AT_TOP` = `1.00`
- `SHADOW_SCALE_AT_BOTTOM` = `0.90`

**Public vars**
- `var room: Node = null`
- `var gu_cell: Vector2i = Vector2i.ZERO`

**Public API**
- `func setup(p_room: Node, p_gu_cell: Vector2i, spec: Dictionary, board: Node3D) -> bool:`
- `func billboard_height_px() -> float:`

---

### `glass_rain_overlay.gd`

`class_name GlassRainOverlay` · extends `Node2D` · 276 lines

`godot/scripts/overlays/glass_rain_overlay.gd`

**Constants / tuning**
- `ShardField3DRef` = `preload("res://godot/scripts/geometry/shard_field3d.gd")`
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
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
- `var tint: Color = Color(0.78, 0.92, 0.97, 0.55)`
- `var air_alpha: float = 0.28`
- `var alpha_var_min: float = 0.55`
- `var pieces_low_bias: float = 1.6`
- `var max_shards: int = 3000`

**Public API**
- `func set_board3d(board: Node3D) -> void:`
- `func spawn(flights: Array, pieces_per_voxel_max: int = 4) -> int:`
- `func live_count() -> int:`
- `func span_frames() -> int:`

---

### `grenade_prop.gd`

`class_name GrenadeProp` · extends `ObjectMesh3D` · 96 lines

`godot/scripts/overlays/grenade_prop.gd`

> The grenade on the ground and in flight, as a real mesh (RETIRE-2 of R3D-RETIRE-2D; `ACTOR` D65). It was a `Sprite2D` showing one of four baked frames (`grenade_frames`, a colour + a normal map per compass direction), relit by a per-pixel shader and mirrored into the 3D board by `PropBillboard3D`. Now it IS a node of the 3D board: the Quaternius `Grenade.glb`, coloured by OUR material registry (D66) and lit by the board's cell planes like every prop, so a perspective change needs no frame swap (the camera turns over one world) and the light and soot come from the world, not from a per-prop light search. What the flight code (`TestZoneController`) still drives is unchanged in meaning: `screen_position` and `flight_px` (`ObjectMesh3D`), the roll (`roll()`, about the axis perpendicular to the travel `set_roll_direction()` was given — a roll across the screen shows the whole turn and one toward the camera shows none, now by geometry instead of by a `roll_dir.x` factor) and `visible`, which the throw code uses as logic (a detonated grenade is hidden). GROUND SHADOW (Director, 2026-08-10: *"durante o vôo da granada, a sombra precisa acompanhar no chão, aumentando e diminuindo a opacidade e a difusão, de acordo com a distância vertical. Quando a granada encosta no chão a sombra é muito bem definida e bem menor, por baixo do asset."*). One height drives size, strength and softness, so they cannot disagree about how high the grenade is. `SHADOW_HEIGHT_REF_PX` is where the flight look is fully reached: `ThrowArcOverlay.arc_height_for()` floors every apex at `launch_px * 1.4`, 89.6 px for a standing throw, so even the shortest throw reaches the full effect at its apex and longer ones hold it. The strengths are `FloatingCollectible`'s ratified ground alpha (0.55) and the flight alpha MEASURED on the old shadow (0.35: the softer one read too faint under a body that flies past 90 px).

**Constants / tuning**
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"`
- `FIT_SIZE` = `Vector3(0.2, 0.2, 0.2)`
- `SURFACE_MATERIALS` = `{"Green": "painted_metal@olive_drab", "DarkGreen": "painted_metal@olive_drab", "DarkGrey": "steel_dark"}`
- `SHADOW_HALF_GU` = `0.14`
- `CONTRAST` = `1.8`
- `SHADOW_HEIGHT_REF_PX` = `90.0`
- `SHADOW_STRENGTH_AT_GROUND` = `0.55`
- `SHADOW_STRENGTH_IN_FLIGHT` = `0.35`
- `SHADOW_SCALE_AT_GROUND` = `0.80`
- `SHADOW_SCALE_IN_FLIGHT` = `1.05`
- `SHADOW_SOFTNESS_IN_FLIGHT` = `0.7`
- `FUSE_LOCAL_FRACTION` = `Vector3(0.0, 1.0, 0.0)`

**Public vars**
- `var room: Node = null`
- `var gu_cell: Vector2i = Vector2i.ZERO`
- `var base_cell: Vector2i = Vector2i.ZERO`

**Public API**
- `func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i, board: Node3D) -> bool:`
- `func fuse_point_world() -> Vector3:`
- `func set_roll_direction(screen_dir: Vector2) -> void:`
- `func roll(angle: float) -> void:`
- `func billboard_height_px() -> float:`
- `func set_flight_height_px(px: float) -> void:`
- `func update_cell(p_gu_cell: Vector2i) -> void:`

---

### `gu_grid_overlay.gd`

`class_name GuGridOverlay` · extends `Node2D` · 85 lines

`godot/scripts/overlays/gu_grid_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `COLOR_BLACK` = `Color(0.0, 0.0, 0.0, 0.35)`
- `LINE_WIDTH` = `1.5`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public API**
- `func setup(visual_grid_offset: Vector2) -> void:`
- `func set_room_size(room_size: Vector2i) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `height_overlay.gd`

extends `Node2D` · 282 lines

`godot/scripts/overlays/height_overlay.gd`

> HeightOverlay — DEV visualization of height classes and structural semantics Displays: - Height classes (FLOOR, LOW_COVER, HUMAN, TALL, OVERHEAD) - Structural categories - Occluders and light blockers - Light anchor sockets - Subfloor hazards Color coding makes semantic information immediately readable. Shows the "worldbuilding reality" independent of sprite appearance.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TileSemanticsClass` = `preload("res://godot/scripts/world/tile_semantics.gd")`
- `LightAnchorClass` = `preload("res://godot/scripts/systems/lighting/light_anchor.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var tile_semantics_map: Dictionary = {}`
- `var light_anchors: Array = []`
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
- `func set_board3d(board: Node3D) -> void:`

---

### `light_overlay.gd`

extends `Node2D` · 140 lines

`godot/scripts/overlays/light_overlay.gd`

> LightOverlay — Visual debug overlay for light sources Shows: - Light position and radius - Light type and height class - Direction vectors (for cone/directional types) - Active/inactive state Only visible in DEV_VISION mode.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**@export**
- `light_registry = null`
- `tile_size: Vector2 = Vector2(128, 64)`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `light_ray_overlay.gd`

extends `Node2D` · 114 lines

`godot/scripts/overlays/light_ray_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `WorldCanvas3DRef` = `preload("res://godot/scripts/geometry/world_canvas3d.gd")`

**@export**
- `visual_offset: Vector2 = Vector2.ZERO`

**Public vars**
- `var ray_color: Color       = Color(1.0, 0.82, 0.30, 1.0)`
- `var alpha_full_lit: float  = 1.0`
- `var alpha_dim: float       = 1.0`
- `var ceiling_lift: float    = 0.0`

**Public API**
- `func setup(v_offset: Vector2, lift: float) -> void:`
- `func set_board3d(board: Node3D) -> void:`
- `func refresh(shadow_results: Array) -> void:`

---

### `noise_overlay.gd`

extends `Node2D` · 84 lines

`godot/scripts/overlays/noise_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public API**
- `func setup( room_ref: Node2D, visual_offset: Vector2, noise_system ) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `occlusion_overlay.gd`

extends `Node2D` · 172 lines

`godot/scripts/overlays/occlusion_overlay.gd`

> Occlusion Overlay — DEV visualization of occluded geometry Displays: voxel cells that occlude the agent, color-coded by ring distance. This is the only visual output of OCC-01 (geometry computation).

**Constants / tuning**
- `OcclusionSetClass` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var occlusion_set: OcclusionSetClass = null`
- `var voxel_board = null`
- `var voxel_tile_size: Vector2 = Vector2(32, 16)`
- `var ring_colors := { 0: Color(1.0, 0.0, 0.0, 0.5),   # Red — ring 0 (nearest, most transparent) 1: Color(1.0, 0.5, 0.0, 0.5),   # Orange — ring 1 (middle) 2: Color(1.0, 1.0, 0.0, 0.5),   # Yellow — ring 2 (outer, least transparent) }`

**Public API**
- `func set_occlusion_set(occ_set: OcclusionSetClass) -> void:`
- `func set_voxel_board(renderer) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `shadow_boundary_overlay.gd`

extends `Node2D` · 148 lines

`godot/scripts/overlays/shadow_boundary_overlay.gd`

> ShadowBoundaryOverlay — Always-visible shadow region visualization Renders two passes on shadow cells: 1. Semi-transparent fill (vignette effect) inside shadow tiles 2. Dark lines on boundaries where shadow meets non-shadow Uses pure drawing (no blend mode) so lines are not overridden by multiply blend. Updated whenever lighting rebuilds via set_shadow_cells().

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**@export**
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func setup(offset: Vector2) -> void:`
- `func set_full_shadow_cells(cells: Array[Vector2i]) -> void:`
- `func set_lite_shadow_cells(cells: Array[Vector2i]) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `shadow_overlay.gd`

extends `Node2D` · 115 lines

`godot/scripts/overlays/shadow_overlay.gd`

> ShadowOverlay — Debug visualization of shadow projection Shows computed shadow topology from ShadowProjector. Only visible in DEV_VISION mode. Display includes: - Directly lit tiles (bright green) - Penumbra/dim zone (yellow) - Shadow tiles (dark blue) - Deep shadow tiles (very dark) - Occlusion boundaries (red outline)

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**@export**
- `shadow_projector = null`
- `light_registry = null`
- `visual_offset: Vector2 = Vector2(0, 0)`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `shrapnel_overlay.gd`

`class_name ShrapnelOverlay` · extends `Node2D` · 222 lines

`godot/scripts/overlays/shrapnel_overlay.gd`

**Constants / tuning**
- `CircleField3DRef` = `preload("res://godot/scripts/geometry/circle_field3d.gd")`
- `QuadField3DRef` = `preload("res://godot/scripts/geometry/quad_field3d.gd")`
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`

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
- `func set_board3d(board: Node3D) -> void:`
- `func spawn_shrapnel(blast_center: Vector2, plan: Dictionary, voxel_board, floor_pos: Vector2 = ParticleMathRef.NO_FLOOR) -> void:`
- `func clear() -> void:`

---

### `shrapnel_preview_overlay.gd`

`class_name ShrapnelPreviewOverlay` · extends `Node2D` · 264 lines

`godot/scripts/overlays/shrapnel_preview_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `WorldCanvas3DRef` = `preload("res://godot/scripts/geometry/world_canvas3d.gd")`

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
- `func set_board3d(board: Node3D) -> void:`
- `func setup(visual_offset: Vector2) -> void:`
- `func show_rays(source_gu: Vector2i, gu_rings: Dictionary) -> void:`
- `func clear() -> void:`

---

### `smoke_spark_overlay.gd`

`class_name SmokeSparkOverlay` · extends `Node2D` · 370 lines

`godot/scripts/overlays/smoke_spark_overlay.gd`

---

### `target_cursor_overlay.gd`

`class_name TargetCursorOverlay` · extends `Node3D` · 65 lines

`godot/scripts/overlays/target_cursor_overlay.gd`

**Constants / tuning**
- `SHADER_PATH` = `"res://godot/shaders/virtual_object3d.gdshader"`

**Public vars**
- `var mark_color: Color = Color(1.0, 0.0, 0.0, 1.0)`
- `var overlay_strength: float = 0.5`
- `var hatch_px: float = 2.0`
- `var hatch_spacing_px: float = 8.0`

**Public API**
- `func set_board3d(board: Node3D) -> void:`
- `func show_at(center: Vector2) -> void:`
- `func clear() -> void:`

---

### `temporal_overlay.gd`

extends `Node2D` · 282 lines

`godot/scripts/overlays/temporal_overlay.gd`

> TemporalOverlay — DEV Visualization of Temporal Lighting Effects Displays: - Light positions and temporal states (ON/OFF/FLICKER/PULSE) - Energy levels and multipliers - Rotation directions for spotlights - Frequency information (flicker intervals, pulse speeds) Updated every frame to show real-time temporal animation. Purpose: Validate stealth temporal behavior, debug timing, ensure auditability.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_CENTER_OFFSET` = `Vector2(0.0, 64.0)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var state_colors: Dictionary = { "on": Color.WHITE,           # Fully on "off": Color(0.2, 0.2, 0.2), # Off/dark "flicker": Color.YELLOW,     # Flickering "pulse": Color.CYAN,         # Pulsing }`
- `var show_lights: bool = true`
- `var show_state_labels: bool = true`
- `var show_energy_bars: bool = true`
- `var show_rotations: bool = true`
- `var ui_scale: float = 1.5`
- `var light_registry = null`
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var fixture_lift: float = 0.0`
- `var all_lights: Array = []`
- `var flicker_animation_phase: float = 0.0`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func load_lights(registry) -> void:`
- `func set_board3d(board: Node3D) -> void:`
- `func debug_info() -> String:`

---

### `throw_arc_overlay.gd`

`class_name ThrowArcOverlay` · extends `Node2D` · 220 lines

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

`class_name ThrowPerimeterOverlay` · extends `Node2D` · 83 lines

`godot/scripts/overlays/throw_perimeter_overlay.gd`

**Constants / tuning**
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var perimeter_color: Color = Color(1.0, 0.3, 0.3, 1.0)`
- `var line_alpha: float = 0.75`
- `var line_width: float = 2.0`
- `var arc_segments: int = 64`

**Public API**
- `func show_perimeter(center: Vector2, radius_gu: float) -> void:`
- `func set_board3d(board: Node3D) -> void:`
- `func clear() -> void:`

---

### `tile_overlay.gd`

extends `Node2D` · 220 lines

`godot/scripts/overlays/tile_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_HALF_W` = `128.0`
- `TILE_HALF_H` = `64.0`
- `PRIO_SHADOW` = `1`
- `PRIO_NAV` = `4`
- `PRIO_DEV` = `5`
- `PALETTE` = `{ ## Shadows — cool-blue tint, intensity encoded as the RGB multiply factor. ## Each step keeps a different fraction of floor brightness → smooth gradient, ## floor texture reads through at every level. "shadow_full":   Color(0.48, 0.48, 0.58, 1.0),  ## darkest — keeps ~48% brightness "shadow_mid":    Color(0.60, 0.60, 0.68, 1.0),  ## keeps ~60% "shadow_lite":   Color(0.70, 0.70, 0.78, 1.0),  ## penumbra — keeps ~70% "lit":           Color(1.00, 1.00, 1.00, 0.00),  ## no overlay (skipped: alpha≈0) ## Artistic shadow spill — soft cosmetic halo around full-shadow tiles. Its colors ## are computed PER-CELL in room._spill_color (directional + density-driven), not from ## fixed keys here, and painted via set_cells_colored(). PURELY VISUAL: detection reads ## the exposure grid, never this overlay — the spill grants no hiding value. ## Detection cone — 5 probability bands "detect_0":      Color(0.30, 1.00, 0.30, 0.70),  ## 0.0–0.2   light green "detect_1":      Color(0.60, 0.95, 0.50, 0.75),  ## 0.2–0.4 "detect_2":      Color(1.00, 0.95, 0.30, 0.75),  ## 0.4–0.6   yellow "detect_3":      Color(1.00, 0.60, 0.30, 0.75),  ## 0.6–0.8   orange "detect_4":      Color(1.00, 0.20, 0.20, 0.80),  ## 0.8–1.0   red ## Exits and markers "exit":          Color(0.55, 0.10, 0.90, 0.28),  ## pure purple — segment exits "spawn":         Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn position "spawn_dev":     Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn in DEV_VISION ## Objectives "objective":     Color(0.90, 0.75, 0.20, 0.75),  ## gold/amber — primary objective "secondary":     Color(0.75, 0.75, 0.75, 0.60),  ## light gray — secondary }`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public API**
- `func setup(visual_offset: Vector2 = Vector2.ZERO) -> void:`
- `func paint(cell: Vector2i, color: Color, priority: int = 0) -> void:`
- `func paint_named(cell: Vector2i, palette_key: String, priority: int = 0) -> void:`
- `func clear_priority(priority: int) -> void:`
- `func clear_all() -> void:`
- `func set_cells(cells: Array[Vector2i], color: Color, priority: int = 0) -> void:`
- `func set_cells_named(cells: Array[Vector2i], palette_key: String, priority: int = 0) -> void:`
- `func set_cells_colored(colored: Dictionary, priority: int = 0) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `tile_risk_overlay.gd`

extends `Node2D` · 135 lines

`godot/scripts/overlays/tile_risk_overlay.gd`

> TileRiskOverlay — Tactical Threat Heatmap Visualization Displays per-tile risk/threat assessment based on tactical exposure. Shows detection probability heatmap (red = danger, blue = safe). Color gradient: Blue (safe) → Green → Yellow → Orange → Red (danger)

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var exposure_system`
- `var tile_size: Vector2 = Vector2(256, 128)`
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_dev_vision(enabled: bool) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `tracer_overlay.gd`

`class_name TracerOverlay` · extends `Node2D` · 160 lines

`godot/scripts/overlays/tracer_overlay.gd`

**Constants / tuning**
- `CORE_COLOR` = `Color(1.0, 0.93, 0.72, 0.95)`
- `TAIL_COLOR` = `Color(1.0, 0.62, 0.22, 0.55)`
- `CORE_WIDTH_PX` = `2.0`
- `TAIL_WIDTH_PX` = `4.0`

---

### `trail_overlay.gd`

extends `Node2D` · 68 lines

`godot/scripts/overlays/trail_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public API**
- `func setup(room_ref: Node2D, visual_offset: Vector2) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `vent_emitter.gd`

`class_name VentEmitter` · extends `Node` · 83 lines

`godot/scripts/overlays/vent_emitter.gd`

> VentEmitter — a steady plume rising from a floor vent (R3D-SURFACES SM-6, 2026-10-06; DS-14: "um vapor subindo pela grade por enquanto"). The map's `ground_vents` section places vents (a grating over a vent shaft, a roof outlet) and this node makes each one breathe: every `interval` seconds a vent releases a small puff through `emit`, which the `Room` turns into `SmokeSparkOverlay.add_smoke()` (the existing world-space, depth-tested smoke, one draw call). COSMETIC like every floor mark: nothing is saved and nothing is gameplay. Each vent has its own phase (a hash of its position, never a RNG), so a row of vents does not pulse in step and every run looks the same (B4). The timing is pure (`step()` returns what to emit and touches nothing else), so the selftest pins it without a renderer.

**Public API**
- `func setup(instances: Array, emit: Callable) -> void:`
- `func count() -> int:`
- `func clear() -> void:`
- `func step(delta: float) -> Array:`

---

## systems/

### `board_probe.gd`

`class_name BoardProbe` · extends `RefCounted` · 288 lines

`godot/scripts/systems/board_probe.gd`

> BoardProbe — the world's voxel state, written as data another run can be compared against value by value. RENDER3D R3D-0 (`RENDER3D_MASTER_PLAN` §4). Every later stage of that plan moves voxel state, or its drawing, from one owner to another: objects to a packed store, tile-shaped plan entries to render-neutral ones, the 2D board to the 3D one. Each move is judged the same way — the world after it must be the world before it — and this is the instrument that says so. WHY NOT THE CELL PROBE. `INFILTRAITOR_CELL_PROBE` answers "did a voxel come back" by reading the TileMapLayer, which is exactly what R3D-END deletes: a gate built on it would die with the thing it judges. This reads the voxel containers and the cell planes — the simulation's own record — and never a tile. A DUMP, one record per line, text so a comparison can name what moved: BOARDPROBE <version> <label> META <key> <value>                    informational, never counted as a difference M <index> <material id>               written before the first container using it C <kind> <id> <n> <coords> <state>    kind = slice | column | slab P <level> <w> <h> <format> <ox> <oy> <plane> END voxels=<n> containers=<n> materials=<n> levels=<n> - `coords`: base64 of little-endian int32 triples (grid x, grid y, level), one per voxel, in the container's own order. - `state`: base64 of 4 bytes per voxel — 0  visible (bit 0) · damage_state (bits 1-2) · damage_is_blast (bit 3) · damage_carved_side (bits 4-6) 1  damage_variant   2  damage_substrate   3  material index (the `M` lines) - An empty container writes `-` for both. - `plane`: base64 of the GZIP-compressed `Image.get_data()` of one level's cell plane (RG8 today: R = face soot code, G = light bucket). The cell at texel (tx, ty) is (tx − ox, ty − oy). VALUES, NOT HASHES. The plan names hashes grouped by container and level. A hash can say THAT two runs differ, never WHERE, and the whole PLAYGROUND board is a few MB of text — so the dump carries the values and the comparison does the grouping. `dirty` is deliberately absent: it is TIC bookkeeping, cleared within the frame. `face_atlas_rect` retires with the atlas. Everything else a `Voxel` holds is in. THE COMPARISON LIVES IN ONE PLACE: `tools/persistent/board_probe.py diff`. This file only writes. ⚠️ LOUD ON A VALUE THE FORMAT CANNOT HOLD. A `PackedByteArray` element silently wraps anything outside 0..255, so a variant of 256 would read back as 0 and match a voxel it does not match. Every packed field is range-checked, and one bad value aborts the write and removes the partial file.

**Constants / tuning**
- `FORMAT_VERSION` = `1`
- `KIND_SLICE` = `"slice"`
- `KIND_COLUMN` = `"column"`
- `KIND_SLAB` = `"slab"`
- `KIND_PROP` = `"prop"`

---

### `cell_plane_store.gd`

`class_name CellPlaneStore` · extends `RefCounted` · 179 lines

`godot/scripts/systems/cell_plane_store.gd`

> CellPlaneStore — the render-neutral home for the per-cell soot/light planes. RENDER3D R3D-2 step 3. Moved out of `VoxelBoard` verbatim (a relocation, not a redesign — the API already matched what a future reader needs): one 512x512 `Image.FORMAT_RG8` per level, R = the per-face soot code (0..215 base 6, 172 = clean; PERF-P2, widened for the charred tone 2026-09-29), G = the light bucket (0..11, PERF-P3; 255 = `BUCKET_UNWRITTEN`, never written). `VoxelBoard` is now one reader/writer of this store, same standing the 3D board will have — `cell_plane_image()`/`cell_plane_levels()` are already documented as "read-only by contract" for exactly that use (DIAG-21). See `RENDER3D_MASTER_PLAN` R3D-2: "the cell planes move to a render-neutral owner (name decided at build time), which both renderers read."

**Constants / tuning**
- `BUCKET_UNWRITTEN` = `255`
- `SOOT_PLANE_ORIGIN` = `Vector2i(64, 64)`
- `SOOT_TEX_SIZE` = `512`

**Public API**
- `func write_soot(level: int, cell: Vector2i, code: int) -> void:`
- `func flush(_skip_writes: bool) -> int:`
- `func ensure_level(level: int) -> void:`
- `func reset_all() -> void:`

---

### `cosmetic_density.gd`

`class_name CosmeticDensity` · 43 lines

`godot/scripts/systems/cosmetic_density.gd`

> CosmeticDensity — how many purely decorative particles a device is asked to draw. Roadmap step A1 (2026-10-07): the shard rain, the ember burst, the smoke blobs and the debris pieces scale per device; GAMEPLAY NEVER DOES. Only sites that draw and own no state may ask `scaled()` — a count that feeds the plan, the store, a damage roll or a persisted record must not. `DevFlags` sets `factor` at boot from `COSMETIC_DENSITY` (`low` / `mid` / `high`, or a float in (0, 1]). The default is 1.0, which returns every count unchanged, so the desktop and every gate are bit-identical to before this class existed.

**Constants / tuning**
- `TIER_LOW` = `0.4`
- `TIER_MID` = `0.7`
- `TIER_HIGH` = `1.0`
- `FLOOR_FACTOR` = `0.1`

---

### `blast_calculator.gd`

`class_name BlastCalculator` · 1852 lines

`godot/scripts/systems/destruction/blast_calculator.gd`

> BlastCalculator — DESTRUCTION_MASTER_PLAN Part 3 ("the trigger"). Pure/static: everything it needs is passed in (no registry ownership, same statelessness as EarthVariantSelector) so it stays testable in isolation against synthetic fixtures, matching every other Part's selftest convention. Three-stage pipeline for one detonation: 1. flood_gu_rings() — wall-aware BFS from the source GU, one ring per GU step, capped at the bomb's range. Director (this session): walls block/reduce propagation — reuses the same blocked-edge gate movement_overlay.gd already uses for movement, not a naive radius. 2. find_affected_containers() — every wall Slice and roof Slab (Role. CEILING) touching a flooded GU, ring-tagged. The GU flood step IS the "walk sideways along the wall" step (a wall's own footprint GU sits in the flood like any other GU), so no separate wall-run adjacency walk is needed here. 3. apply_container_damage() — combines a container's ring multiplier with MaterialResistanceTable to get a destroy/crack voxel COUNT, then picks WHICH voxels deterministically (FNV-1a hash-and-rank, mirroring EarthVariantSelector — no RNG, same inputs always produce the same result).

**Constants / tuning**
- `GRENADE_LEVEL` = `0`
- `NO_EPICENTER_BIAS` = `Vector2i(-999999, -999999)`
- `FACE_SOOT_CLEAN` = `4`
- `FACE_SOOT_CHAR` = `5`

---

### `bomb_def.gd`

`class_name BombDef` · 101 lines

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

`class_name BombRegistry` · 77 lines

`godot/scripts/systems/destruction/bomb_registry.gd`

> BombRegistry — Bomb definitions catalog (two-tier: res:// + user://). Line-for-line the PropRegistry pattern (godot/scripts/systems/prop_registry.gd): user-tier bombs override res:// bombs on id collision.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`
- `RES_BOMBS_DIR` = `"res://bombs"`
- `USER_BOMBS_DIR` = `"user://bombs"`

**Public vars**
- `var registry: Dictionary = {}`
- `var load_errors: Array[String] = []`

**Public API**
- `func register(bomb_def) -> void:`
- `func get_bomb(p_id: String):`
- `func count() -> int:`
- `func load_from_disk() -> void:`

---

### `detonation_entry_writer.gd`

`class_name DetonationEntryWriter` · extends `RefCounted` · 229 lines

`godot/scripts/systems/destruction/detonation_entry_writer.gd`

> DetonationEntryWriter — ONE plan entry's real work, and the only place in the whole pipeline that calls `layer.set_cell()`/`erase_cell()` or hands a puff to an overlay. Extracted from `DetonationChoreographer._apply_entry()` on 2026-08-28 for D-3 (`DETONATION_PRESENTATION_MASTER_PLAN` §3), unchanged in behaviour. It exists because the reform replaces the choreographer's PACING, not its writing: §3's table says the cell writes "survive as one loop inside the commit" and the VFX dispatch "survives and MOVES". Two paths now need this code and they have to run from one binary (D-3's gate), so copying it would have created exactly the second place for them to drift — and D-6 would then have to reconcile two versions instead of deleting one file. ⚠️ **KIND IS THE ONLY THING THAT DECIDES WHAT HAPPENS HERE — there is no ordering, no pacing and no frame in this class.** That is what makes it shared: everything the reform is removing lives in the caller. The two families are worth naming because the reform separates them: - **cells** (`destroy`, `expose`, `dented`, `cracked`, `soot`) — mutate the board, and after D-3 they all land in ONE frame; - **VFX** (`smoke`, `ember`, `debris`) — write nothing, and are what the consequence channel animates afterwards.

**Constants / tuning**
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `SMOKE_COLOR` = `Color(0.62, 0.60, 0.57, 0.2)`
- `DEBRIS_FALLBACK_COLOR` = `Color(0.6, 0.6, 0.6)`
- `SURFACE_SPARK_SPEED_SCALE` = `1.3`
- `SURFACE_SPARK_DURATION_SCALE` = `0.6`

**Public vars**
- `var ember_overlay: EmberOverlay = null`
- `var debris_overlay: DebrisOverlay = null`
- `var debris_colors: Dictionary = {}`
- `var smoke_tints: Dictionary = {}`
- `var soot_clean: bool = false`
- `var soot_ramp_cells: Dictionary = {}`

**Public API**
- `func apply(kind: String, entry: Dictionary, voxel_board, smoke_overlay) -> int:`
- `func flush(voxel_board) -> int:`

---

### `detonation_plan_builder.gd`

`class_name DetonationPlanBuilder` · 3151 lines

`godot/scripts/systems/destruction/detonation_plan_builder.gd`

> DetonationPlanBuilder — EXPLOSION_REBUILD_MASTER_PLAN Task 4 (E-PLAN). Builds one `WorldDelta` for a single grenade detonation: all resolution, all exposure fallback, and the single map-wide light-field query, folded into one object a later choreography driver (Task 5/E-WAVE) can play back from `delta.waves` as a pure sequence of `set_cell()`/`erase_cell()` calls with zero further compositing/lookup — the performance idea §2 states once: "no compositing, no lookup, no light rebuild, no allocation happens inside a wave." **P-DELTA (PREDICTION_MASTER_PLAN Task 3, 2026-08-09): this class is now PURE.** It changes nothing — not a tile, not a Voxel — and returns a description of what a detonation WOULD do. `delta.commit()` is what makes it happen, and the caller owns that decision. Everything this pass used to read off freshly-mutated Voxels it now reads through `WorldDelta`'s projection. What this class does NOT do, on purpose: - It never calls `layer.set_cell()`/`erase_cell()` — every VoxelBoard call it makes runs in resolve-only mode (`apply=false`, Task 4's own seam added to `_set_voxel_cell()`/`register_slab()`/ `register_fixed_level()`/`resolve_damage_voxel_swap()`). A voxel's on-screen TILE is only ever resolved, never painted, until a wave chooses to apply the plan entry produced here. - It never writes DAMAGE STATE either, since P-DELTA. `BlastCalculator`'s `commit_damage()` remains the single writer (DESTRUCTION_MASTER_PLAN §3); this pass only ever calls its `simulate_*` half. - It never CALLS `room.record_voxel_damage_to_base()`/increments `_gu_blast_count`/appends a stamped-blast replay list — that is Task 5's job, the same split Task 2/3 already established for their own new parameters. It DOES return the raw material for the first of those (`delta.touched_voxels`, `Array[Voxel]` — every voxel this blast's containers would change the damage_state of, DESTROYED or DENTED/ CRACKED), so Task 5's caller can persist without a second flood/ find_affected_containers pass to re-derive the same set. That list is only meaningful AFTER `commit()`, which is when its caller reads it. - It never schedules or times anything — the plan is a static census of what EVERY wave should eventually paint; Task 5 owns turning that into a 40 ms-cadenced sequence. `ctx` is a plain Dictionary rather than a typed context object, matching the project's existing MinimalRoom precedent (the deleted damage_atom_bake_selftest.gd's) for running real BlastCalculator machinery against either a full `room.gd` or a trimmed selftest scaffold without either needing to know about the other: "edge_registry": EdgeRegistry        (required) "slab_registry": SlabRegistry        (required) "voxel_board": VoxelBoard      (required) "blocked_edges": Dictionary          (optional, default {}) "blocked_cells": Dictionary          (optional, default {}) "lights": Array                      (optional, default [] — real light sources, e.g. RoomBuilder.get_ light_sources()) "shadow_results": Array              (optional, default []) "under_structure": Dictionary        (optional, default {} — VL-D3 "never saw the sun" darkening; derived from the CURRENT geometry if omitted, see _columns_with_structure()) "deep_layer_unlocked": bool          (optional, default false — D2; no live caller drives true yet)

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `WorldDeltaClass` = `preload("res://godot/scripts/systems/prediction/world_delta.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `VoxelLightFieldClass` = `preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")`
- `CRATER_MAX_FACTOR` = `0.40`
- `CRATER_CORE_FACTOR` = `0.30`
- `SMOKE_BLOBS_PER_VOXEL` = `1`
- `PHASE_SETUP` = `0`
- `PHASE_SLICES` = `1`

---

### `detonation_presenter.gd`

`class_name DetonationPresenter` · extends `RefCounted` · 616 lines

`godot/scripts/systems/destruction/detonation_presenter.gd`

> DetonationPresenter — D-3 of `DETONATION_PRESENTATION_MASTER_PLAN`. **The world changes once, and the EFFECTS are what is animated.** That is the whole inversion (§4). `DetonationChoreographer` animates the WORLD — it spreads 20 ms of cell writes across 24 frames and decorates them — and this replaces it with one frame that writes everything and then N frames that write nothing. It is the only detonation path: the choreographer it replaced was deleted at D-6 (`620f8e3a`). ## What it does NOT contain, which is the point No `flatten_plan()`, no `_sort_key()`, no `KIND_RADIUS_BIAS`, no `front_radius_for()`, no `front_frames`, no `_fade_in_soot()`. Every one of those exists to decide WHEN a cell is written, and there is only one frame that writes cells. §3.1: the ordering problem does not get solved here, it stops existing — `KIND_RADIUS_BIAS` had been re-derived three times. ## The three beats 1. **THE COMMIT — one frame.** Every `destroy`, `expose`, `dented`, `cracked` and `soot` entry, then one flush. From here the board is FINAL. 2. **The consequence channel — N frames, zero cell writes.** `smoke`, `ember` and `debris`, each released at its own time. 3. **The light**, unchanged and still last (§7, the Director's standing ruling: scorch is what the light is about to reveal). ⚠️ **THE SCORCH IS IN THE COMMIT, AND THAT IS WHY `soot_clean` IS FALSE HERE.** §13.4 made the wave write clean geometry because its scorch arrived later in a ramp, and a hole that opened already-scorched then had to be wiped and refilled. With one commit frame there is no later — §7.1 — so the cell writes carry their own soot and `_fade_in_soot()` has nothing left to do. Setting this true would produce a permanently clean crater with no error anywhere.

**Signals**
- `signal finished()`

**Public vars**
- `var is_done: bool = false`
- `var background_step: Callable = Callable()`
- `var background_budget_us: int = 8000`
- `var consequence_room = null`
- `var consequence_delta = null`
- `var ring_step_s: float = 0.055`
- `var storey_bias_s: float = 0.020`
- `var jitter_s: float = 0.060`
- `var consequence_max_seconds: float = 0.75`
- `var hit_stop: bool = false`
- `var hit_stop_ceiling_ms: float = 200.0`
- `var light_smoke_slack: int = 4`
- `var light_smoke_max_s: float = 3.5`
- `var soot_fade_frames: int = 5`
- `var soot_start_s: float = 0.0`
- `var soot_step_s: float = 0.075`

**Public API**
- `func set_vfx_targets(ember_overlay: EmberOverlay, smoke_tints: Dictionary = {}, debris_overlay: DebrisOverlay = null, debris_colors: Dictionary = {}) -> void:`
- `func start(plan: Dictionary, voxel_board, smoke_overlay, tree: SceneTree) -> void:`
- `func commit_under_flash(plan: Dictionary, voxel_board) -> float:`
- `func run_hit_stop_tail(voxel_board) -> float:`

---

### `glass_crack.gd`

`class_name GlassCrack` · 503 lines

`godot/scripts/systems/destruction/glass_crack.gd`

> GlassCrack — GLASS_MASTER_PLAN CRACK-02 (§13, G-D14 / G-D24 / G-D26 / G-D27). A round that lands on a pane and does NOT breach the voxel (a weak hit, or a rifle round whose shatter roll was lost) leaves the pane STANDING and crazes the glass around the hole. That is this file: given the pane, the hit and the weapon's hole width, it returns the still-standing glass cells to mark CRACKED and everything the crack SPRITE needs to be placed. PURE by construction — it takes slice lists, never the registry — so the shot path applies the result the way `agent_shot_controller` applies `GlassShatter.plan_pane_shatter()`, and the selftest hands it a synthetic frame (PREDICTION_MASTER_PLAN's rule for `build_plan()`). ⚠️ STATE AND RENDER ARE DECOUPLED HERE, AND THAT IS THE POINT OF CRACK-02. `plan_pane_crack()` decides which voxels enter the CRACKED STATE — a gameplay fact, saved by VL-PERSIST, unrelated to pixels. The RENDER is a `GlassCrackSprite` laid over the pane in the pane's own basis (G-D27), whose reach is `SHEET_SPAN_*` and has nothing to do with the state radius. CRACK-01 conflated the two through a per-cell group plane; that plane is deleted. G-D24 — a cell already covered by a DIFFERENT crack, reached by this fracture, is not crazed: it is DESTROYED (crossed cracks drop the piece) and falls through `GlassFall` like any other break. With no per-cell plane the test is geometric, against the renderer's crack registry (`glass_crack_covering`).

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `FacadeSampler` = `preload("res://godot/scripts/systems/facade_sampler.gd")`

---

### `glass_crack_params.gd`

`class_name GlassCrackParams` · extends `RefCounted` · 105 lines

`godot/scripts/systems/destruction/glass_crack_params.gd`

> GlassCrackParams — GLASS_MASTER_PLAN CRACK-02 / G-D27 (§13), as DATA. ONE crack event = ONE of these: every shader parameter the crack carries (the fracture sheet, its span, the pane's clip bounds, the craze field, the occupancy cut, the opening void, the hole-cut dial). `VoxelBoard` keeps it in the crack's record (`rec["params"]` is `params`, by reference), and `GlassCrackMirror3D` gives the record a quad on the pane's plane in the 3D board and copies `params` into it every frame. R3D-END (END-2): this was `GlassCrackSprite`, a Sprite2D laid over the pane in the pane's own canvas basis, with a ShaderMaterial on `glass_crack.gdshader` as the record's 2D consumer. The 2D board is gone, so the node, its transform and its material are too; what the 3D board reads was always only `params` (R3D-9).

**Constants / tuning**
- `PANE_CLIP_SLACK` = `0.5`

**Public vars**
- `var params: Dictionary = {}`
- `var valid: bool = false`

**Public API**
- `func setup(sheet: Texture2D, span: Vector2, pane_lo: Vector2, pane_hi: Vector2) -> void:`
- `func setup_field(sheet: Texture2D, span: Vector2, pane_lo: Vector2, pane_hi: Vector2, tile_span: Vector2, field_origin: Vector2, field_dir: Vector2) -> void:`
- `func set_occupancy(tex: Texture2D, size: Vector2, origin: Vector2) -> void:`
- `func set_opening(tex: Texture2D, origin: Vector2, size: Vector2) -> void:`
- `func set_hole_cut(v: float) -> void:`

---

### `glass_fall.gd`

`class_name GlassFall` · 341 lines

`godot/scripts/systems/destruction/glass_fall.gd`

> GLASS G-D16a — WHERE A SHARD LANDS. GLASS_MASTER_PLAN §5.4 / §18.5. G-D13b answers "does this shard survive where it is"; this answers the other half, "where does the glass that fell end up", and it is deliberately ONE rule rather than one feature per surface: A destroyed glass voxel SCATTERS a few cells from its own column and then falls until it meets the first horizontal surface, and lands there. Base pile, counter top, windowsill, and a skylight dropping a whole storey are then the same code with different geometry underneath — no per-case branch. ── G4-4 / G-D41 + G-D42 — THE SCATTER ────────────────────────────────────── (Director, 2026-09-05: *"A maior parte dos elementos fica na primeira sub-GU mais próxima […] Alguns cacos conseguem vencer até 3 sub-GUs de distância […] uma força vetor que desloca todo o conjunto de cacos mais pra longe, baseado na força e na distância da granada."*) A pane is a vertical sheet, so its voxels project onto a LINE of grid cells — and until G4-4 that line was the whole pile. The scatter spreads it into a band: most shards on the pane's own column, fewer one cell out, a tail reaching `scatter_max_cells()` (G-D41's "3 sub-GUs"). A sub-GU is one voxel cell (G-D41), so every distance here is in cells, not GUs. The symmetric draw covers "perpendicular to the pane BOTH ways and along the run" by construction — for any pane orientation one grid axis is the run and the other is perpendicular, and an isotropic symmetric offset spreads both the same. So this file never needs the pane's face; it only needs a DIRECTION for the shockwave, and the caller hands that in `impulse`. `impulse` — `{from: Vector2, strength: float, lift: float}` in GRID space, from the bomb's own `ring_multipliers` falloff (G-D42 — no second force model). At zero impulse the scatter is symmetric; a near grenade shifts the band's mean downrange and, per-shard-scaled, spreads it wider ("caírem mais longe, mais espalhados"). `lift` is the skylight term and is UNEXERCISED by any real map — G-D16c/d is unbuilt, CEILING glass renders opaque and has no `pane_id`, so no skylight can shatter yet. It is authored with a synthetic test rather than quietly, so it does not become a fourth built-but-never-triggered feature. ⚠️ THE SCATTER OFFSET IS HASHED IN GRID SPACE, NOT BASE SPACE, and that is correct here rather than a shortcut. The result becomes STATE at `commit()` — the G6 pile is recorded in base coords and never recomputed, only re-laid (`Room._respawn_base_shards()`) — exactly as the un-scattered landing already was. The hash only has to be stable across the many `build_plan()` calls of one event, and the cursor is on one target throughout, so the grid key is. PURE, and that is not decoration. It takes a surface INDEX, never the SlabRegistry, so the selftest can hand it a synthetic counter and prove the rule without building a map — the same contract PREDICTION_MASTER_PLAN holds `build_plan()` to, and the same one `GlassShatter.collect_anchor_positions()` already follows. ⚠️ This module decides WHERE, never WHETHER anything is drawn. G6 (`Room.record_glass_shards()`) turns a landing into a floor pile decal and G6b-2 (`Room.spawn_glass_rain()`) into the falling shards; both are BUILT and consume this file's output. This module stays pure and knows about neither.

**Constants / tuning**
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `NO_LANDING` = `-1`

---

### `glass_opening.gd`

`class_name GlassOpening` · 389 lines

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

`class_name GlassShatter` · 902 lines

`godot/scripts/systems/destruction/glass_shatter.gd`

> GlassShatter — GLASS_MASTER_PLAN §5.1 (REWRITTEN 2026-08-31), G-D11. The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power, NOT a single `pane_shatter_punch` threshold. Every pellet or round that lands on a pane rolls its OWN chance `p_shatter(glass_punch)` to take the pane — or a region larger than its own hole (G-D12, the region flood — Stage B). A shotgun's 24 pellets each roll and the pane's odds compound with the count, and it is legitimately possible that none of them shatter it. `glass_punch` is exactly `ShotPunchTable.compute(weapon.punch, "glass", …)` — the same coefficient the local hole already uses. At neutral skill / point blank / neutral luck it is `PUNCH_GAIN(3.0) · weapon.punch / RESISTANCE["glass"](0.4)`. THE CURVE: a shifted, renormalised logistic. The shift-and-clamp is what guarantees the "near-flat bottom" the Director asked for — a plain logistic's low tail never reaches zero, so an smg round would still shatter panes a few percent of the time. `s(p) - SHATTER_C` clamped at zero kills that tail outright; `/ (1 - SHATTER_C)` renormalises so the top still approaches `SHATTER_P_MAX`. s(p) = 1 / (1 + e^(-SHATTER_K · (p - SHATTER_X0))) p_shatter(p) = clamp( SHATTER_P_MAX · (s(p) - SHATTER_C) / (1 - SHATTER_C), 0.0, SHATTER_P_MAX ) DIRECTOR-APPROVED TARGET DISTRIBUTION (2026-08-31, neutral skill/luck), pinned by `glass_shatter_selftest` reading the shipped weapon JSONs within a tolerance — so a later balance edit to a weapon's `punch` fails the suite rather than silently turning a pistol into a pane-breaker: | round               | glass_punch | P(shatter) target | this curve | |---------------------|-------------|-------------------|------------| | smg                 | 1.65        | ~0%               | 0.6%       | | shotgun pellet (1)  | 1.80        | ~2%               | 2.0%       | | pistol              | 2.10        | ~2.5%             | 5.5%       | | revolver            | 2.63        | ~16%              | 14.3%      | | assault rifle       | 3.75        | ~44%              | 43.8%      | | sniper              | 5.25        | ~81%              | 81.1%      | | shotgun blast (24×) | —           | ~38%              | 38.2%  = 1 - (1 - 0.020)^24 | The flat bottom is load-bearing: it is what keeps a shotgun's VOLUME (24 rolls at ~2%) its advantage over a pistol's single ~5% roll, and it is what keeps "none of the 24 shattered it" a real outcome. Pistol lands a touch high (5.5% vs 2.5%) — the target has a very sharp knee between punch 2.1 and 2.63 that no smooth sigmoid catches; `SHATTER_C` is the knob for it and the Director calibrates against real play (Director, 2026-08-31: *"Boa — fixar como está"*). ALL TUNABLES ARE `static var`, not `const` (architecture Rule 1, and the same reason ShotPunchTable's are): this file is a balancing lever the Director dials at runtime.

**Constants / tuning**
- `FacadeSamplerClass` = `preload("res://godot/scripts/systems/facade_sampler.gd")`
- `ShotPunchTableClass` = `preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")`
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `ShardShapesClass` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`

---

### `material_resistance_table.gd`

`class_name MaterialResistanceTable` · 267 lines

`godot/scripts/systems/destruction/material_resistance_table.gd`

> MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3, extended by D22. How much of a ring-group's voxels convert to DESTROYED vs DENTED vs CRACKED for a given wall/roof/floor material. D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): material properties are registered dynamic data, never hardcoded and never map-coupled — the old `const TABLE` literal is gone. Data now lives in `res://materials/*.json` (+ `user://materials/*.json`, user wins on collision), the same files `MaterialRegistry` reads for render properties — one row per material, one file per material, no duplication between the two readers. This file keeps its original static-accessor API (`destroy_factor`/`dent_factor`/ `crack_factor(material_id) -> float`, same defaults) so every existing call site (BlastCalculator, selftests) is untouched — only the data source changed, lazily loaded and cached on first access. Ordering (resistance to destruction, most -> least), per Director (2026-07-30 session): metal > stone > concrete > wood. Values are first-pass placeholders — a balancing lever (D6), not researched constants; expect these to be retuned once real captures show the effect.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`
- `RES_MATERIALS_DIR` = `"res://ASSETS/materials"`
- `USER_MATERIALS_DIR` = `"user://materials"`

---

### `shot_hit_roll.gd`

`class_name ShotHitRoll` · 70 lines

`godot/scripts/systems/destruction/shot_hit_roll.gd`

> ShotHitRoll — WEAPON_MASTER_PLAN D12's FIRST roll: does the shot hit the actor it was aimed at? The second roll (how much damage) is ShotPunchTable's and has shipped since 2026-08-02; this is the half that never existed. WHY IT EXISTS AS A REAL SEAM RATHER THAN AN `if false`. §6c Part C, in the Director's own scoping of this wave: the agent *"erra sempre o alvo (por enquanto)"* — but the always-miss has to run THROUGH the roll and force its outcome, not around it. A caller that skipped straight to the wall-damage path would be a second code path to delete the day the hit lands, and the deletion is the part that goes wrong. Forcing the outcome instead means the hit path is one enum away. WHAT IS DELIBERATELY NOT HERE. D12 is explicit that hittability is a STATS concern decoupled from what the sprite looks like: agent skill, cover, shadow, weapon level, powerups. None of those stats exist on any actor yet, so `chance_for()` below is a single named seam returning a placeholder, in the same spirit as WeaponBenchController._agent_skill() — one obvious place for the real terms to land, rather than a literal smeared across call sites. D32 will make the number player-facing (the cyclable target list's hit percentage). That is combat-phase surface and explicitly NOT this wave; the function it will read is this one. Tunables are `static var`, never `const` — architecture rule 1, and this file is a balancing lever like every other table beside it.

---

### `shot_punch_table.gd`

`class_name ShotPunchTable` · 427 lines

`godot/scripts/systems/destruction/shot_punch_table.gd`

> ShotPunchTable — DESTRUCTION_MASTER_PLAN D30 (Director, 2026-08-02). ONE scalar decides everything a single projectile does to the scenery: punch = PUNCH_GAIN x weapon_punch x skill x distance x luck / resistance Every factor is centred on 1.0, so a `punch` printed to the console is directly readable: 1.0 is "neutral shot, neutral agent, point blank, average luck, neutral material". That readability IS the requirement — Director: *"precisamos criar um coeficiente de destruição que seja fácil de mensurar e configurar."* WHY A NEW RESISTANCE TABLE INSTEAD OF MaterialResistanceTable's factors: those three numbers were calibrated as GROUP FRACTIONS ("what share of a ring group converts to this tier") and are consumed that way by apply_container_damage(). Reading them as a single-point divisor silently changes what they mean — metal's destroy_factor 0.05 would make a sniper round land below even the CRACKED threshold, i.e. bullets stop marking metal at all. Repurposing numbers tuned for another model is exactly the data-shape assumption CLAUDE.md's evidence rules warn about, so the point model gets its own explicit, separately tunable row set. All tunables are `static var`, not `const`: this whole file is a balancing lever (D6) and the Director asked for it to be configurable, which a `const` would prevent at runtime.

---

### `weapon_def.gd`

`class_name WeaponDef` · 119 lines

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

`class_name WeaponRegistry` · 56 lines

`godot/scripts/systems/destruction/weapon_registry.gd`

> WeaponRegistry — Weapon definitions catalog (two-tier: res:// + user://). WEAPON_MASTER_PLAN Part 1 (D7). Line-for-line the BombRegistry pattern (which is itself line-for-line PropRegistry): user-tier weapons override res:// weapons on id collision, and a new weapons/*.json needs ZERO code changes to appear.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`
- `RES_WEAPONS_DIR` = `"res://weapons"`
- `USER_WEAPONS_DIR` = `"user://weapons"`

**Public vars**
- `var registry: Dictionary = {}`
- `var load_errors: Array[String] = []`

**Public API**
- `func register(weapon_def) -> void:`
- `func get_weapon(p_id: String):`
- `func count() -> int:`
- `func load_from_disk() -> void:`

---

### `dev_flags.gd`

extends `Node` · 236 lines

`godot/scripts/systems/dev_flags.gd`

> DevFlags — the one seam every diagnostic switch is asked through. DIAG-01. Autoload singleton, registered as `DevFlags`. WHY THIS EXISTS The project's diagnostic surface is ~200 `OS.get_environment("INFILTRAITOR_*")` reads. That works perfectly on desktop and is **completely inert inside an APK**: environment variables do not reach an Android application. So on the one platform the game actually ships to, `INFILTRAITOR_EVENT_FRAMES` — the instrument that reports the worst frame of a detonation, which is the number the whole device track exists to obtain — could not be turned on at all, and the build on the phone was a black box. RESOLUTION ORDER, and why it is this order: 1. `OS.get_environment("INFILTRAITOR_<name>")` 2. the overrides file (see below) 3. the caller's default The environment comes FIRST so that desktop behaviour is bit-identical to what it was before this file existed. Every capture harness, every `INFILTRAITOR_X=1 godot ...` invocation in the docs, and every selftest keeps working unchanged, and a stale flags file on a dev machine can never quietly override what a developer typed on the command line. THE OVERRIDES FILE — `/sdcard/Android/data/<package>/files/dev_flags.cfg` Measured 2026-09-12 on a Moto G04s, against the three alternatives: - An intent extra (`am start --esa command_line_args …`) is **accepted by Android and never reaches Godot** — `InitEngine with params:` came back byte-identical and `--verbose` produced no extra output. Dead end. - `adb push` to `user://` needs a **debuggable** build, and a debug template is not a release template — it would change the very performance being measured. - `command_line/extra_args` in the export preset works, but is baked at export time: ~40 s per flag change. The app's own EXTERNAL files directory has none of those problems. Android 11+ grants every app free access to it, `adb push` writes there in milliseconds with no declared permission, and the APK being measured stays the APK that ships. That is the whole reason this class reads a file at all. FORMAT — one `KEY=VALUE` per line, `#` comments and blank lines ignored. The KEY is the flag name WITHOUT the `INFILTRAITOR_` prefix: # measure one detonation EVENT_FRAMES=1 MAP=PLAYGROUND ⚠️ THE FILE IS READ ONCE, AT BOOT. Pushing a new one mid-run changes nothing until the next launch — deliberate, so a flag cannot change underneath a measurement that is already running.

**Constants / tuning**
- `FLAG_PREFIX` = `"INFILTRAITOR_"`
- `FLAGS_BASENAME` = `"dev_flags.cfg"`

**Public API**
- `func on(flag_name: String) -> bool:`
- `func value(flag_name: String, fallback: String = "") -> String:`
- `func num(flag_name: String, fallback: int = 0) -> int:`
- `func real(flag_name: String, fallback: float = 0.0) -> float:`
- `func source_path() -> String:`
- `func overrides() -> Dictionary:`
- `func external_files_dir() -> String:`

---

### `earth_variant_selector.gd`

`class_name EarthVariantSelector` · 29 lines

`godot/scripts/systems/earth_variant_selector.gd`

> EarthVariantSelector — DESTRUCTION_MASTER_PLAN D2/D4 core. Floor/slab voxels don't have corners or continuous facade planes to project (unlike walls) — they were a small pre-authored palette of voxel atoms, scattered across the grid by a deterministic hash of position. This is the whole mechanism: no shear, no junction compositor, no per-map baking step. R3D-END cleanup (2026-09-26): the eight atoms this indexed (`voxel_earth_0..7.png`) were archived to ARCHIVE/voxel_atoms_2d/ — the 3D board has no atom. The selector stays as the deterministic-variant reference (B4) for R3D-LOOK, which decides what a variant is on a 3D face. Determinism is the entire point (D5): hash(x, y, level) is recomputed identically forever, never stored. A voxel's look never changes just because a neighbour got destroyed and exposed it — there is nothing to "pop" because nothing was ever assigned; it's re-derived the same way every time it's looked at.

**Constants / tuning**
- `VARIANT_COUNT` = `8`

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

`class_name FacadeSampler` · 31 lines

`godot/scripts/systems/facade_sampler.gd`

> FacadeSampler — the FNV-1a hash every deterministic pick in the game reads (B4) It began as the 2D bake's sampler of the infinite facade plane (mirrored-repeat addressing) and its per-run window origins. Both went with the 2D board (R3D-END; last present in `6bb89cb4`, and the window origins are R3D-LOOK's reference). What is left is the hash, kept in this file because the B4 hook pins its constants here.

---

### `frame_rate.gd`

`class_name FrameRate` · extends `RefCounted` · 50 lines

`godot/scripts/systems/frame_rate.gd`

> FrameRate — the player's frame-rate cap (Director, 2026-10-08). The default is 30 fps on every platform: the ratified target (`DEVICE_DIAGNOSTICS` §0.5), and on the floor device (Moto g04s) 30 and 60 are the same run, because a frame costs ~23 ms of GPU and vsync already holds it at 30. On a faster phone or a desktop the cap saves power and heat. A player with better hardware may choose 60 or no cap (0); the choice is kept in `user://settings.cfg` (the file `LocalizationManager` already writes), section `display`, key `max_fps`. ⚠️ NO CHOICE UNDER 30. Measured 2026-10-08 (`PERFORMANCE_BUDGET_MASTER_PLAN` §0c): below 30 the cost per frame does not fall and the blast's effects, which age in drawn frames, stretch in wall time (6.9 s -> 9.3 s at 15 fps). `MAX_FPS=<n>` (DevFlags) still overrides this for a measurement (`Room._apply_perf_ablations()`).

**Constants / tuning**
- `CHOICES` = `[30, 60, 0]`

---

### `frame_split.gd`

`class_name FrameSplit` · extends `RefCounted` · 45 lines

`godot/scripts/systems/frame_split.gd`

> FrameSplit — per-subsystem CPU attribution for the frame probe. PERF-DEV (2026-09-12). On the Moto g04s the idle frame was measured process-bound: `Performance.TIME_PROCESS` held ~42 ms while render gpu read 19 ms. That monitor is a MAXIMUM retained over roughly a second, not a mean (it read 246 ms inside a span whose frame mean was 92 ms), and it says nothing about WHERE the main thread goes. Each device cycle costs minutes, so ablating one subsystem per build is the slow way to find it; this names the share of each instrumented call site in a single run. Armed by `Room` from `FRAME_PROBE`. Call sites guard their own clock read with `FrameSplit.enabled`, so a disarmed build pays one static bool per site. ⚠️ The shares do not add up to the frame. Anything not wrapped is not counted, and `_draw()` callbacks run during the deferred flush, not inside the `_process` that queued them — read each label as a floor on that subsystem, never the remainder as "the engine".

---

### `gfx_census.gd`

`class_name GfxCensus` · extends `RefCounted` · 337 lines

`godot/scripts/systems/gfx_census.gd`

> GfxCensus — PERFORMANCE_BUDGET PB-2: WHO owns the graphics memory. The Galaxy A16 reads ~590 MiB of `Graphics` PSS after a PLAYGROUND load and Android's release build has no engine counter for it (`RenderingServer.get_rendering_info` reads 0 there). This walks what the scene actually HOLDS on the GPU side and sizes it from the CPU-side description: every texture a material, a mesh or a canvas item points at (deduplicated by RID, sized with `Image.get_data_size()` so the format and the mipmaps are counted), every mesh's vertex / index arrays, every MultiMesh's instance buffer, and the viewports' render targets. Each item lands in a CATEGORY (asset folder or owning node), so the answer is a table, not a total. ⚠️ AN ESTIMATE OF THE CONTENT, NOT A DRIVER READ. The driver adds padding, its own copies, the shader cache and the render targets' intermediate buffers; compare the sum with the engine counters printed beside it (desktop) and with the handset's `GL mtrack` total, and treat the gap as "engine/driver", never as zero. Called from the scenario op `gfx_census <name>`. Diagnostic only: it reads images back from the GPU (slow), never in play.

**Constants / tuning**
- `MIB` = `1024.0 * 1024.0`

---

### `glass_materials.gd`

`class_name GlassMaterials` · 225 lines

`godot/scripts/systems/glass_materials.gd`

> GlassMaterials — GLASS_MASTER_PLAN G-D16, the glass FAMILY seam. WHY THIS EXISTS, and it is measured rather than stylistic. Before G-VARIANT, "is this glass?" was written as a bare `material == "glass"` in TWENTY-FIVE places across rendering, geometry, occlusion, the guard phase, the shot path and the cook. Every one of them is a BEHAVIOUR: a glass slice does not occlude, does not enter the vision edge set, groups into a pane, lets a round through, renders on its own transparent layers, drops no smoke, and anchors no shards. G-D16 adds `glass_armored` and `glass_screen_{green,red,amber}` as members of that same family — *"a family of tinted behaviour classes, not new geometry"*. Adding them against 25 literal comparisons would make each new material a silently OPAQUE wall that happens to be named glass: it would occlude, block sight, stop rounds, puff smoke, and never form a pane. Nothing would error. So the family is asked, never compared. `is_glass()` is the only question the engine is allowed to ask about glass-ness, and `check_invariants.py` rule **L2** fails any new bare comparison outside this file. ── WHAT THIS FILE IS NOT ── It is not a second material registry. Resistance, destroy/dent/crack factors and `base_color` stay where they already live — `ASSETS/materials/<id>/<id>.json` via `MaterialResistanceTable`/`MaterialRegistry`, and `ShotPunchTable`'s balance rows. This file answers exactly one thing: which material ids are in the glass family, and (from V-C) which behaviour class each one carries.

**Constants / tuning**
- `FAMILY` = `["glass", "glass_armored", "glass_screen_green", "glass_screen_red", "glass_screen_amber"]`
- `BASE` = `"glass"`
- `FRACTURE_WIDTHS` = `["tight", "wide"]`

---

### `image_source.gd`

`class_name ImageSource` · 45 lines

`godot/scripts/systems/image_source.gd`

> ImageSource — the one way runtime code reads a PNG as pixels. Two sources, chosen per path: - The raw file, when it is on disk: editor runs and `--script` CLI runs (selftests, bakes). CLI-baked PNGs have never been through the editor's import scan, so `load()` fails with "No loader found" for them. - The imported resource, when the raw file is NOT on disk: every exported build (web, Android). An export ships only the imported `.ctex`, never the source PNG, so a raw `Image.load()` fails there — grey walls with no facade, an invisible grenade, silently. Every PNG in this project imports with `compress/mode=0` (lossless), so the imported pixels equal the source pixels — B2 (grayscale) and B3 (alpha from canon) hold on both paths.

---

### `json_file.gd`

`class_name JsonFile` · 64 lines

`godot/scripts/systems/json_file.gd`

> JsonFile — the one way a catalogue reads a JSON row from disk, loudly (B6). AUDIT 2026-10-07: the five catalogues (`MaterialRegistry`, `MaterialResistanceTable`, `PropRegistry` props and slots, `BombRegistry`, `WeaponRegistry`) dropped a row that did not parse or had no `id` without saying which file: Godot's own `Parse JSON failed. Error at line 0` names no path, and an id-less row said nothing at all. A typo in `bombs/frag_grenade.json` made the grenade vanish; a broken material row fell to the generic look, silently wrong. Every failure here is `push_error`'d WITH the path and appended to the caller's `errors`, so a selftest (`registry_load_errors_selftest`) and a future mod validator can read it. The same goes for the vector fields a row carries: `[1.0]` where three numbers are expected used to abort `from_json()` half-way with a SCRIPT ERROR (the rest of the row unread); `vector3()` / `vector2i()` fall back to the default and say so.

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

`class_name LightRegistry` · extends `Node` · 110 lines

`godot/scripts/systems/lighting/light_registry.gd`

> LightRegistry — Centralized light source management Responsibilities: ✓ Register/unregister lights ✓ Query lights by position/properties ✓ Track ownership and state Does NOT: ✗ Render lights ✗ Calculate shadows ✗ Compute exposure ✗ Manage visual effects Pure data storage and queries for the lighting system.

**Signals**
- `signal light_registered(light)`
- `signal light_removed(light)`

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

`class_name ShadowProjector` · extends `Node` · 252 lines

`godot/scripts/systems/lighting/shadow_projector.gd`

> ShadowProjector — Geometric (tiered + penumbra) floor-shadow projection For each light, classifies reachable cells (clear LOS within radius) as fully_lit / dim, then casts a *geometric* shadow from each occluding object: the shadow falls in the grid direction away from the light, with a length derived from object-height tier × light-height factor × a mild distance stretch (deterministic, not random). The shadow tip softens to penumbra. Slice 1 (VIS-01): object shadows from blocked_cells. Wall-edge floor shadows and multi-tile silhouette width are future work. Does NOT: - blend shadows from multiple lights (ExposureSystem max-merges per cell) - cache results (caller manages ShadowResult lifetime) - render visualization (that's ShadowOverlay's job)

**Constants / tuning**
- `ShadowResultClass` = `preload("res://godot/scripts/systems/lighting/shadow_result.gd")`
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

`class_name VoxelLightField` · extends `RefCounted` · 617 lines

`godot/scripts/systems/lighting/voxel_light_field.gd`

> VoxelLightField — per-voxel light BUCKET data (VL-01, VOXEL_LIGHT_MASTER_PLAN). The single seam between tactical lighting (LightRegistry / ShadowProjector, GU resolution) and every VISUAL consumer. VoxelBoard.apply_light_field() reads it to repaint faces; future vision modes (thermal / night / X-ray) query it instead of touching tilemaps. Canon split preserved: this consumes LightSource.visual_energy, never tactical_energy — visual brightness is not tactical visibility. Deterministic and discrete: same lights + same layout always produce the same bucket per (cell, level). No per-frame work — built on lighting_rebuilt, queried lazily with a cache.

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
- `var under_structure_factor: float = 0.68`

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

`class_name MaterialRegistry` · 249 lines

`godot/scripts/systems/material_registry.gd`

> MaterialRegistry — Material definitions, pattern algorithms, and resistance (destroy/dent/crack) — D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): material properties are registered dynamic data, never hardcoded and never map-coupled. Two-tier disk load (res:// then user://, user wins on collision), same pattern as BombRegistry/PropRegistry/WeaponRegistry. D19/D20: one row per material, surface-independent for behavior (this file). Texture identity is a SEPARATE axis (derived from the material id and `has_facade`; `BakePolicy.texture_for_material()` owned it until R3D-END). D34/E-SEAM-01 (Director, 2026-08-08): that axis is no longer surface-keyed either. A `has_facade` material renders EVERY surface — wall, roof and floor — from `facade_<id>`, tinted by `base_color` under MULTIPLY, so the three read as one material; only `has_facade == false` (organic ground) keeps the photographic `slab_<id>` source at WHITE. The WHITE-vs-tinted modulate was decided by the texture id's own prefix at bake time (the 2D bake's `_modulate_for_mode`, deleted at R3D-END), never by a field on this class — what changed is which ids reach it.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`
- `StonePatternClass` = `preload("res://godot/scripts/systems/stone_pattern.gd")`
- `WoodPatternClass` = `preload("res://godot/scripts/systems/wood_pattern.gd")`
- `MetalPatternClass` = `preload("res://godot/scripts/systems/metal_pattern.gd")`
- `SurfaceRulesRef` = `preload("res://godot/scripts/systems/surface_rules.gd")`
- `RES_MATERIALS_DIR` = `"res://ASSETS/materials"`
- `USER_MATERIALS_DIR` = `"user://materials"`

**Public vars**
- `var registry: Dictionary = {}`
- `var load_errors: Array[String] = []`

**Public API**
- `func register(material: MaterialDef) -> void:`
- `func get_material(p_id: String) -> MaterialDef:`
- `func resolve(p_id: String) -> MaterialDef:`
- `func list_materials() -> Array:`
- `func count() -> int:`
- `func register_defaults() -> void:`
- `func load_from_disk() -> void:`

---

### `mem_stage.gd`

`class_name MemStage` · extends `RefCounted` · 188 lines

`godot/scripts/systems/mem_stage.gd`

> MemStage — DIAG-09 §1b: where in the boot does the memory actually go? The device census (2026-09-12, Moto G04s) established that PLAYGROUND costs **2.22 GB with nothing detonated**, leaving 589 MB of headroom on a 3.83 GB handset — and that our own TileSet atlases account for at most 163.8 MB of the 734 MB of graphics memory. **~570 MB is unexplained**, and three candidates were written down as guesses, deliberately not acted on. This is how the guessing is avoided: a marker at each boot stage, printing the process's own memory and the DELTA since the previous marker. The stage whose delta is large is the answer; the other two candidates are eliminated in the same run, without anyone having to be right in advance. ⚠️ WHY IT READS `/proc/self/status` AND NOT A GODOT API. Both engine-side instruments tried first returned null and are recorded as null in the plan: `RenderingServer.get_rendering_info(...)` reads 0.0 MB on desktop Forward+ AND on the device while the atlas is provably 163.8 MB, and `OS.get_static_memory_usage()` is debug-only — 1 340 MB in the editor build, 0.0 MB in the release APK. `/proc/self/status` is readable by the app itself on Android with no permission, and is the same accounting `dumpsys meminfo` reports from outside. ⚠️ WHAT IT CANNOT SEE. `VmRSS` does not include graphics driver memory — the `GL mtrack` figure that grew 734 MB → 1.05 GB across three detonations. A stage that allocates only GPU-side will move these numbers hardly at all. That is why `device_run.py --mem-poll` samples `dumpsys meminfo` alongside: the two instruments see different halves, and a stage invisible to BOTH is genuinely not where the memory went. Called as `MemStage.mark("label")` — a `class_name`, not an autoload, so it is reachable from `room_builder.gd` and other non-Node classes and survives a `godot --script` context where autoloads do not exist.

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

`class_name OcclusionSet` · 1340 lines

`godot/scripts/systems/occlusion_set.gd`

> Occlusion Module — Computes which geometry occludes the agent POLICY: O1 — Occlusion is VIEW, not STATE - _occluded_cells is owned solely by this module - Never writes Voxel.visible, never uses dirty flag, never persists - Coordinates enter in BASE space; each view's turned geometry is built once (R3D-ROT) and picked by `view` POLICY: O4′ — One view-space formula, no rotation applied The map never rotates (one world, the camera turns); each view's geometry is the base turned once, at first use. POLICY: O5 — Depth is (x + y) in view-space, never z_index Isometric diamond layout: screen-y ∝ (x + y). Greater sum = nearer camera. POLICY: O7 — Glass does not occlude (a see-through pane hides nothing). A slice whose base material is glass is filtered out in _group_slices_by_edge() — see that function's header.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `FaceMod` = `preload("res://godot/scripts/geometry/face.gd")`
- `SlabMod` = `preload("res://godot/scripts/geometry/slab.gd")`
- `MAX_RING` = `2`
- `ROOF_REACH` = `6`
- `ROOF_FADE` = `2`
- `ROOF_ADJACENT_CORNERS` = `true`
- `BASE_VISIBLE_LEVELS` = `2`
- `SMALL_ROOF_MAX_STRIPES` = `5`
- `_FACE_DIRS` = `[Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]`
- `FACE_DIRS` = `_FACE_DIRS`

**Public vars**
- `var view: String = "N"`
- `var base_voxel_size: Vector2i = Vector2i.ZERO`
- `var base_gu_size: Vector2i = Vector2i.ZERO`
- `var last_phase_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])`
- `var last_tail_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])`

**Public API**
- `func turn_voxel(p: Vector2i) -> Vector2i:`
- `func turn_gu(g: Vector2i) -> Vector2i:`
- `func near_dirs() -> Vector2i:`
- `func get_occluded_cells() -> Dictionary:`
- `func get_column_entries() -> Dictionary:`
- `func get_roof_gus() -> Dictionary:`
- `func is_empty() -> bool:`
- `func entry_at(column: Vector2i) -> Variant:`
- `func get_wireframe_by_level() -> Dictionary:`
- `func get_wireframe_lines_by_level() -> Dictionary:`
- `func get_recompute_count() -> int:`
- `func recompute(agent_cells, slices: Array, room_size: Vector2i, junction_columns: Array = [], ceiling_slabs: Array = []) -> void:`
- `func get_exposure() -> Dictionary:`

---

### `paint_palette.gd`

`class_name PaintPalette` · 36 lines

`godot/scripts/systems/paint_palette.gd`

> PaintPalette — the named paints a painted surface can wear (`painted_metal@olive_drab`). A paint is ONE COLOUR. A surface that takes paint keeps its material (its detail, its family, its soot and light behaviour) and only its `albedo` changes, so repainting is a single shader parameter write: no texture, no material copy, no disk row. The grayscale facade of a material that has one stays the detail the paint is multiplied by (B2), and is the natural mask for wear later (chips that show the metal under the paint). It lives in code, not in `ASSETS/materials/` (git-ignored there) nor in a JSON the export filter would have to list: the palette is a short table that ships with the scripts.

**Constants / tuning**
- `PAINTS` = `{ "olive_drab": Color(0.30, 0.34, 0.17), "sand": Color(0.62, 0.55, 0.38), "navy": Color(0.14, 0.18, 0.30), "signal_red": Color(0.62, 0.12, 0.10), "bone_white": Color(0.78, 0.76, 0.70), }`
- `SEPARATOR` = `"@"`

---

### `claim_grid.gd`

`class_name ClaimGrid` · extends `RefCounted` · 64 lines

`godot/scripts/systems/prediction/claim_grid.gd`

> ClaimGrid - the detonation plan's `cell_to_voxel`, without the 215 000-entry Dictionary of `Voxel` objects. R3D-CLAIMS C2. The plan's WALK used to build `Dictionary[Vector3i -> Voxel]` over every claim of the board (and `VoxelStore.walk_cache` kept it for the store's life: ~21 MB, and every `Voxel` object in it alive). The answer is already in the store: its dense grid knows which claim holds a cell, so this object answers `voxel_at()` / `has()` / `size()` from the grid and hands back the container's own `Voxel` for that claim (made on request, one per claim). Same answers as the Dictionary, "the last claim of a cell wins" included: a cell two claims hold answers for the one that comes last in claim order, which is what assigning in walk order did. A plan built over a board with no matching store (a fixture) has no grid to ask; it fills `put()` as the old walk did.

**Public API**
- `func put(key: Vector3i, voxel: Voxel) -> void:`

---

### `detonation_prediction.gd`

`class_name DetonationPrediction` · extends `RefCounted` · 165 lines

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

`class_name PredictionCache` · extends `RefCounted` · 216 lines

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

---

### `prediction_reaper.gd`

`class_name PredictionReaper` · extends `RefCounted` · 79 lines

`godot/scripts/systems/prediction/prediction_reaper.gd`

> PredictionReaper - lets go of a finished cook's working state a few milliseconds a frame. R3D-LIGHT (2026-09-26, Moto g04s): `bump_world_revision()` at the commit cancels the cached job, `cancel()` drops the cook's state dictionary, and freeing that one object (every ring, cell-to-voxel and packaging table the cook built) took **115 ms** inside the commit frame. Dropping a reference is atomic, so the state is handed here instead and emptied entry by entry under a budget; whatever a frame does not reach waits for the next one. Nothing reads a retired state again: `cancel()` had already made it unreachable.

**Constants / tuning**
- `BIG_MEMBER` = `4000`
- `DRAINABLE` = `["cell_to_voxel"]`

---

### `walk_warmer.gd`

`class_name WalkWarmer` · extends `RefCounted` · 51 lines

`godot/scripts/systems/prediction/walk_warmer.gd`

> WalkWarmer - builds the detonation WALK's geometry indexes in idle frames, so the first grenade's cook does not. R3D-LIGHT (2026-09-26, Moto g04s): the WALK visits every claim (~215 000) to build `cell_to_voxel`, `flammable_cells` and `burn_cells`, ~950 ms of a cook's ~1.9 s. They depend on geometry alone, so `VoxelStore.walk_cache` keeps them for the store's life and a warm cook enumerates only the claims that can be a hole. The FIRST cook of a board would still pay the build, so `Room._rebuild_voxel_store()` hands the store here and the same walk runs `budget_ms` a frame until it is done. A cook that starts first simply walks cold (and publishes the cache itself); a rebuilt board abandons the job.

---

### `world_delta.gd`

`class_name WorldDelta` · extends `RefCounted` · 391 lines

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
- `var gu_rings: Dictionary = {}`
- `var touched: Array[Vector3i] = []`
- `var touched_voxels: Array = []`
- `var reaped_voxels: Array = []`
- `var cost_ms: float = 0.0`
- `var scorch_writes: Dictionary = {}`
- `var glass_openings: Array = []`
- `var glass_crazes: Array = []`
- `var glass_shard_piles: Dictionary = {}`

---

### `prop_def.gd`

`class_name PropDef` · 85 lines

`godot/scripts/systems/prop_def.gd`

> PropDef — Prop definition resource Describes a voxel prop (crate, pillar, container, etc.) Schema mirrors the file format and supports future destruction phase per-voxel granularity.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`

**Public vars**
- `var id: String`
- `var size_vox: Vector3i`
- `var layers: Array`
- `var material_zones: Dictionary`
- `var footprint_gus: Array[Vector2i]`
- `var storeys: int = 1`
- `var gameplay: Dictionary`
- `var tags: Array[String]`
- `var model_path: String = ""`
- `var slot: String = ""`
- `var vox_model: String = ""`
- `var vox_scale: int = 1`
- `var vox_materials: Dictionary = {}`
- `var surface_materials: Dictionary = {}`
- `var model_rotation_deg: Vector3 = Vector3.ZERO`
- `var fragment_division: int = 0`
- `var hollow_shell: int = 0`

---

### `prop_registry.gd`

`class_name PropRegistry` · 215 lines

`godot/scripts/systems/prop_registry.gd`

> PropRegistry — Prop definitions catalog (two-tier: res:// + user://) User-tier props override res:// props on id collision, same pattern as MaterialRegistry and TextureResolver. SLOTS (PROP_PIPELINE_PLAN PP1, `ACTOR` D66): `props/slots/*.json` (two tiers) are `SlotDef`s; a `PropDef` with `slot` is one MODEL of that slot and several models of one slot coexist. `resolve_placement()` turns what a map names (a prop id, or a slot id) into a prop that FITS, walking the fallback chain when it does not: the model -> the slot's default model -> the slot's GENERIC (a plain box of the slot's size in the `generic` material) -> the generic box of the prop's own size. A rejection is one `push_warning` per prop id.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`
- `RES_PROPS_DIR` = `"res://props"`
- `USER_PROPS_DIR` = `"user://props"`
- `RES_SLOTS_DIR` = `"res://props/slots"`
- `USER_SLOTS_DIR` = `"user://props/slots"`

**Public vars**
- `var registry: Dictionary = {}`
- `var load_errors: Array[String] = []`
- `var slots: Dictionary = {}`

---

### `prop_validator.gd`

`class_name PropValidator` · 49 lines

`godot/scripts/systems/prop_validator.gd`

> PropValidator — does this model fit its slot? PURE: plain data in, a list of problems out (empty = it fits). PROP_PIPELINE_PLAN PP1 / `ACTOR` D66, D69. A rejection is never fatal and never silent: the registry walks its fallback chain (model -> the slot's default -> the slot's generic -> the `generic` box) and logs the FIRST problem once. This class only answers; it reads no file and no registry (the selftest feeds it literals; `family_of` is a Callable so a test needs no autoload). `stats` is `PropModelFit.stats(model)` (a mesh) or `PropVoxLibrary.stats(def, registry)` (a voxel model, which adds "claims" and "materials"): {"ok", "size": Vector3 (the fitted box), "triangles", "surfaces": Array[String], "finite"}.

---

### `prop_vox_library.gd`

`class_name PropVoxLibrary` · 89 lines

`godot/scripts/systems/prop_vox_library.gd`

> PropVoxLibrary — `.vox` models as destructible props: loads, builds and caches (PROP_PIPELINE_PLAN PP4, `ACTOR` D66/D69). A `PropDef` with `vox_model` is a VOXEL prop (mesh_tier 0): its `.vox` is scaled, mapped to registry materials, hollowed and centred on the footprint by `VoxPropBuilder`, then `VoxelBoard.register_vox_prop()` turns the result into `PropBlock`s — one per (GU, material), so every assumption the destruction code already makes (one material, one GU per block) still holds. They enter the `VoxelStore`, so light, soot, the charred tone, fire, blast and firearm damage, picking, rotation and save are the crate's, for free. Colour -> material: `vox_materials` maps a palette index (as a string) to a registry material id; an index with no entry takes the registry material whose `base_color` is nearest the palette colour (glass, ground, organic and generic rows are never candidates).

---

### `registries_autoload.gd`

extends `Node` · 143 lines

`godot/scripts/systems/registries_autoload.gd`

> Registries — Global autoload for MaterialRegistry and PropRegistry Replaces Engine.set_meta() pseudo-singletons with real Godot autoload. This fixes the SIGABRT crash on quit (FIX-SHUTDOWN-CRASH-01) caused by Engine.set_meta()-stored GDScript instances being destroyed during Main::cleanup() after ScriptServer::finish_languages() has begun dismantling the script language. Strategy: the AUTOLOAD is what fixes the crash — a real Node with a real lifetime, torn down before the script language is dismantled. The weak references below were belt-and-braces on top of that. REG-STRONG-01 (2026-08-13, measured): the belt was costing real work every frame it was worn. Nothing else in the game holds a registry, so each one was being collected between accesses and REBUILT FROM DISK on the next call — measured on one real grenade throw: the bomb registry re-read `bombs/*.json` **4 times**, the material registry re-scanned `materials/*.json` **twice**. They are strong refs now.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `PropRegistryClass` = `preload("res://godot/scripts/systems/prop_registry.gd")`
- `BombRegistryClass` = `preload("res://godot/scripts/systems/destruction/bomb_registry.gd")`
- `WeaponRegistryClass` = `preload("res://godot/scripts/systems/destruction/weapon_registry.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`

**Public vars**
- `var material_registry: MaterialRegistryClass:`

**Public API**
- `func ensure_material_registry() -> MaterialRegistryClass:`
- `func ensure_prop_registry() -> PropRegistryClass:`
- `func get_material_registry() -> MaterialRegistryClass:`
- `func ensure_bomb_registry() -> BombRegistryClass:`
- `func get_bomb_registry() -> BombRegistryClass:`
- `func ensure_weapon_registry() -> WeaponRegistryClass:`
- `func get_weapon_registry() -> WeaponRegistryClass:`
- `func ensure_file_map_source() -> FileMapSourceClass:`

---

### `save_state.gd`

`class_name SaveState` · extends `RefCounted` · 308 lines

`godot/scripts/systems/save_state.gd`

**Constants / tuning**
- `FORMAT_VERSION` = `3`
- `OLDEST_READABLE_VERSION` = `1`

---

### `scenario_draw.gd`

`class_name ScenarioDraw` · extends `RefCounted` · 37 lines

`godot/scripts/systems/scenario_draw.gd`

> ScenarioDraw — wait for the next DRAWN frame, but never forever. `await RenderingServer.frame_post_draw` returns only after a frame is actually drawn. A harness window sits off-screen (`--position 4000,4000`, so it never pops up over the Director's work) and macOS sometimes treats such a window as occluded: the engine then keeps running process frames flat out (`DisplayServerMacOS::can_any_window_draw()` is false, no draw is issued, ~100 % CPU) and every `await RenderingServer.frame_post_draw` waits for ever. Found 2026-10-06 after FOUR intermittent "hangs" (a scenario that never reached its next step; a `verify.py --baseline` boot that timed out), by sampling a hung process: its main thread was in ordinary `SceneTree::process` work and no drawing symbol appeared anywhere in the stack. ⚠️ THE CAUSE IS INFERRED, NOT PROVEN: the stack showed ordinary frames, `can_any_window_draw()` being asked and no draw issued; before this change about 3 of 6 runs of one GLASS scenario hung, after it 14 of 14 ran clean, but the fallback was never seen firing (no warning in those 14), and a minimised window still draws, so the condition could not be forced. If a hang ever shows with this in place, the cause is something else. So: wait for the draw, but if `WAIT_FRAMES` process frames pass without one, say so (a warning) and force one (`RenderingServer.force_draw`), which draws the viewports whether or not the OS thinks the window is visible. A capture taken after it is a real frame. In gameplay the window is visible, a draw comes every frame and this costs nothing.

**Constants / tuning**
- `WAIT_FRAMES` = `20`

---

### `scenario_runner.gd`

extends `Node` · 570 lines

`godot/scripts/systems/scenario_runner.gd`

> ScenarioRunner — a measured session a finger does not have to perform. TEL-06a (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). The benchmark detonates by calling `detonate_active()` directly, so it never ran the framing, zoom or pan a player does, and DIAG-16 (§10.16) showed those decide the board's cost more than the blast does. A scenario is a list of the steps a human would take, written as DATA and run through the same Room entry points the HUD and the camera gestures reach. FORMAT — one `DevFlags` value, `SCENARIO`, steps separated by `;` (or newlines): SCENARIO=framing portrait; centre agent; zoom 0.5; wait 20; mark z050; quit framing portrait|landscape|desktop   M portrait, M landscape (§13 Q5 (a)), or D zoom <z>                             through the camera's own clamp centre agent | centre <x>,<y>        camera onto the agent or a GU wait <seconds>                       real time frames <n>                           rendered frames mark <label>                         a `scenario.mark` boundary for the analyzer window <W>x<H>                       desktop only: emulate a phone's aspect detonate <index>                     dev grenade #index, camera on it, menu path; waits for the blast to end (TEL-06b) throw <index> <x,y>                  RETIRE-2: dev grenade #index THROWN to the GU x,y through the real throw (the agent's release, the arc, the landing hop, the roll, the fuse, the blast); returns at once, so follow it with `frames`/`capture_at` aim <x,y>                            RETIRE-2D: the grenade targeting preview on a GU (the perimeter, the dome, the arc, the shrapnel rays, the footprint and the virtual grenade), as a player aiming; stays open canvas_check <name>                  RETIRE-2D: prints `[CANVAS-CHECK] <name> examined=N canvas=M <names>`: how many overlays that have a 3D target there are, and which of them are painting the 2D canvas instead capture <name>                       the root viewport to captures/<name>.png (the external files dir on Android) capture_at <beat> <offset> <name>    RENDER3D R3D-0: ARM a capture for INSIDE the next blast — taken <offset> after the Room names <beat> (`Room.blast_beat`). The beat is written with `_` for a space (`SOOT_FADE`); the offset is frames (`2f`) or seconds of process delta (`1.5s`) — the clock the consequence channel and the embers age on, so a 2D and a 3D run at very different frame times photograph the same moment of the effect. Arm it BEFORE `detonate`, which returns only once the blast is over. probe <name>                         RENDER3D R3D-0: a `BoardProbe` dump of the voxel state to probes/<name>.txt (same dir as capture); compare with board_probe.py alloc objects|packed|bytes <count>   RENDER3D R3D-0 instrument: hold <count> `Voxel` objects / packed int32 cells / bytes until quit, for --mem-poll to read container_stats <name>               R3D-CLAIMS C2: prints how many released containers were converted back to full `Voxel` objects and how many single handles were made (`VoxelContainer.Stats`) probe_store <name>                   RENDER3D R3D-1b: the same dump, read from the shadow `VoxelStore` (`VOXEL_STORE=1`) shoot <guard index>                  R3D-1b gate: a shot through the menu entry points needs that guard to exist (GLASS has none: the step aborts the scenario) reload                               R3D-1b gate: F2's `load_map()` on the current map save_restore                         R3D-1b gate: SaveState capture → reload → restore perspective N|E|S|W                  R3D-1b gate: a rotation through `_set_perspective()` view_mode dev|light|heat|numbers|ruler   flips one analysis aid, through the same toggles the HUD and the F-keys reach (the dev overlays under a camera yaw need a scenario to switch them on; call it again to flip it back) pick_check <name>                    touch picking in the CURRENT view: the centre of every on-screen cell goes through the real pick (`_screen_to_tile`) and must come back as that cell (or the standing prop that covers it); prints `[PICK-CHECK]` (tools/persistent/pick_gate.py reads it) world_check <name>                   the maths the air overlays (tracer, throw arc, aim dome, lamps) stand on, in the CURRENT view: where `WorldCanvas3D.lift()` puts fixed points (world state, must not move with the view) and whether `screen_axes()` is what the camera really does to a grid step; prints `[WORLD-CHECK]` (tools/persistent/world_gate.py) relight                              R3D-13: the map-wide light repaint on the CURRENT world, in place — what a rotation or a restore runs, without either (a probe before and after names what the incremental light left different from a full relight) passages <label>                     RENDER3D R3D-1c: every edge's passage class, as a count and a digest occ_bench <x,y> <x,y> <reps>         R3D-7 instrument: put the agent on the two cells in turn <reps> times through the real occlusion path (`_recompute_occlusion`), one frame apart, and print the set / 3D cutaway / total cost place_guard <i> <x,y>                R3D-7: guard <i> onto a cell (position only), vision refreshed quit                                end the process (the harness waits on it) EVERY STEP IS ON THE TIMELINE as `scenario.step`, which is what lets one analyzer cut windows out of a scripted run and a hand run the same way. ⚠️ LOUD ON A BAD SCENARIO. `parse()` rejects the WHOLE scenario on the first bad step rather than skipping it. A skipped `zoom` would leave every later window measuring the previous zoom under a mark that names a different one — a table that is wrong and looks right. TEL-06b adds the action steps (aim, confirm, end turn) once the analyzer exists.

**Constants / tuning**
- `ARITY` = `{ "framing": 1, "zoom": 1, "centre": 1, "wait": 1, "frames": 1, "mark": -1, "window": 1, "capture": 1, "detonate": 1, "quit": 0, "probe": 1, "alloc": 2, "capture_at": 3, "throw": 2, "aim": 1, "canvas_check": 1, "probe_store": 1, "shoot": 1, "reload": 0, "save_restore": 0, "perspective": 1, "relight": 0, "view_mode": 1, "container_stats": 1, "gfx_census": 1, "gpu_alloc": 1, "passages": 1, "mirror_check": 1, "ground_check": 1, "pick_check": 1, "world_check": 1, "occ_bench": 3, "place_guard": 2, "decal_wall": 2, }`
- `ScenarioDrawRef` = `preload("res://godot/scripts/systems/scenario_draw.gd")`
- `VIEW_MODES` = `["dev", "light", "heat", "numbers", "ruler"]`
- `FRAMINGS` = `["portrait", "landscape", "desktop"]`
- `ALLOC_KINDS` = `["objects", "packed", "bytes"]`
- `BEAT_TOKEN_PATTERN` = `"^[A-Za-z0-9_]+$"`

**Public API**
- `func run(room: Node, steps: Array) -> void:`

---

### `slot_def.gd`

`class_name SlotDef` · 51 lines

`godot/scripts/systems/slot_def.gd`

> SlotDef — a SLOT: the visual container a prop model has to fit (`ACTOR` D66, PROP_PIPELINE_PLAN §1). A model does not define gameplay, a slot does: the footprint, the box it may fill, the cover it gives, how it breaks (its mesh tier), the budgets it must respect and which kinds of material it may be made of. Any number of models fill one slot (`PropDef.slot`); a map may place "the slot" (the registry picks a model) or one model by id. `props/slots/<id>.json`, two tiers like every registry.

**Constants / tuning**
- `JsonFileRef` = `preload("res://godot/scripts/systems/json_file.gd")`

**Public vars**
- `var id: String = ""`
- `var footprint_gus: Array[Vector2i] = [Vector2i.ZERO]`
- `var max_size: Vector3 = Vector3.ONE`
- `var mesh_tier: int = 4`
- `var gameplay: Dictionary = {"cover": "none", "destructible": false}`
- `var default_model: String = ""`
- `var generic_material: String = "generic"`
- `var max_triangles: int = 4000`
- `var max_surfaces: int = 4`
- `var max_claims: int = 1500`
- `var max_materials: int = 4`
- `var allowed_families: Array[String] = []`

---

### `stone_pattern.gd`

`class_name StonePattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 30 lines

`godot/scripts/systems/stone_pattern.gd`

> StonePattern — Granular per-voxel jitter Simulates natural surface granularity; grainy texture with high-frequency variation

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

---

### `surface_rules.gd`

`class_name SurfaceRules` · extends `RefCounted` · 115 lines

`godot/scripts/systems/surface_rules.gd`

> SurfaceRules — which floor marks (patches) may lie on which floors (R3D-SURFACES, 2026-10-06; `docs/systems/SURFACES_CATALOG.md` §3). A floor material declares `tags` out of a CLOSED vocabulary, a patch kind declares `requires` (ALL of these tags on the floor) and `forbids` (ANY of these on the floor means no), all in `res://surfaces/rules.json`. Co-existence is the default; exclusivity is a `forbids` entry ("no leaf in the desert" = `leaf` forbids `arid`). A tag outside the vocabulary and a kind with no rule are loud errors (B6), never a silent pass.

**Constants / tuning**
- `PATH` = `"res://surfaces/rules.json"`

---

### `telemetry.gd`

extends `Node` · 298 lines

`godot/scripts/systems/telemetry.gd`

> Telemetry — the one timeline every diagnostic run writes into. TEL-01 (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). Autoload singleton, registered as `Telemetry` after `DevFlags` (which arms it) and `VersionInfo` (which it reports). WHY THIS EXISTS The device track lost sessions to numbers read without their context. DIAG-15 tied a ×6.6 jump in draw calls to a grenade throw because the log held the counters and nothing else; DIAG-16 found the jump came with a change of framing and zoom that no line recorded (plan §10.16). A counter is only comparable with the view, the command and the phase it was read under, so each of those becomes an EVENT on one clock here, and "what happened when the counter moved" becomes a join instead of a guess. THE RECORD — every event carries, in this order: seq   per-session sequence number. logcat drops lines under load (plan §5), so a gap in `seq` is a dropped line — counted, never silently absent. f     `Engine.get_process_frames()` t_us  `Time.get_ticks_usec()` — the clock `FrameSplit` and the frame probe read, so their windows join against events exactly. kind  `<channel>.<name>` — `input.tap`, `view.framing`, `frame.window` ... ...   the event's own fields. TWO SINKS, because neither is enough alone: - logcat: `[TEL] <seq> <f> <t_us> <kind> k=v ...` — lands in the capture `device_run.py` already takes, but is lossy under load. - a JSONL file, one record per line — lossless. On Android it goes to the app's EXTERNAL files dir (where `DevFlags` already reads its overrides from, and `adb pull` reaches without a debuggable build); elsewhere to `user://`. If it cannot be opened the run says so and continues on logcat alone. FLAGS (through `DevFlags`, so every one of them reaches a release APK): TELEMETRY=1        arm it. Disarmed, every call costs one bool test. TEL_CHANNELS=a,b   only these channels (default: all). `session` always. TEL_FILE=0         no file sink. TEL_LOGCAT=0       no logcat lines (the file only). ⚠️ PRICED, NOT FREE. `stats()` reports the events written, their bytes and the microseconds spent writing them. §14.2 #4 requires that cost to be measured on the Moto before a telemetry-on number is quoted beside a telemetry-off one.

**Constants / tuning**
- `FILE_DIR_NAME` = `"telemetry"`
- `FLUSH_INTERVAL_USEC` = `500_000`

**Public vars**
- `var enabled: bool = false`

**Public API**
- `func start(channels: PackedStringArray, sink_path: String, to_logcat: bool) -> void:`
- `func stop() -> void:`
- `func wants(kind: String) -> bool:`
- `func event(kind: String, fields: Dictionary = {}) -> void:`
- `func count(counter: String, amount: int = 1) -> void:`
- `func take_counters() -> Dictionary:`
- `func stats() -> Dictionary:`
- `func file_path() -> String:`
- `func session_fields() -> Dictionary:`

---

### `texture_resolver.gd`

`class_name TextureResolver` · 240 lines

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

### `view_context.gd`

`class_name ViewContext` · extends `RefCounted` · 100 lines

`godot/scripts/systems/view_context.gd`

> ViewContext — what the screen was showing when a number was read. TEL-03 (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). DIAG-16 (§10.16) measured one untouched board at 4 209 draw calls and at 49 688: the same scene and the same nodes, at two zooms. A frame-probe count means nothing without the view it was read under, so the frame probe and the telemetry timeline both take it from here. Pure reads, no state. The caller hands over everything it owns: the visual grid offset arrives as a parameter (architecture rule 2), and the cell-to-screen mapping arrives as Room's own inverse of `_screen_to_tile()` rather than being copied here. ⚠️ TWO COSTS, ON PURPOSE. `read()` is a handful of property reads and is safe once per probe window. `count_visible_cells()` walks every floor cell near the screen — thousands at the pinch minimum — so the caller caches it per view and recounts only when the view changed. A probe that recounted every window would put its own spike into the frames it reports.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `SCAN_MARGIN_CELLS` = `2`

---

### `vox_model.gd`

`class_name VoxModel` · extends `RefCounted` · 161 lines

`godot/scripts/systems/vox_model.gd`

> VoxModel — a MagicaVoxel `.vox` file, parsed. PURE data in, data out; every read is bounds-checked and every count is capped, so a truncated, hostile or simply odd file ends in `error`, never a crash, a hang or a huge allocation (PROP_PIPELINE_PLAN PP4, D69). The format (little endian): "VOX " + version, then a MAIN chunk whose children are chunks `id(4) content_size(4) children_size(4)` + content + children. We read SIZE (x, y, z), XYZI (n, then n x (x, y, z, colour index)) and RGBA (256 colours); everything else (the scene graph of newer files, materials, layers) is skipped. ONLY THE FIRST MODEL of a file is read. Axes are MagicaVoxel's: z is UP. A colour index is 1..255 and maps to `palette[index - 1]`.

**Constants / tuning**
- `MAX_DIM` = `256`
- `MAX_VOXELS` = `200000`

**Public vars**
- `var size: Vector3i = Vector3i.ZERO`
- `var voxels: Array[Vector4i] = []`
- `var palette: PackedColorArray = PackedColorArray()`
- `var error: String = ""`

**Public API**
- `func is_ok() -> bool:`

---

### `vox_prop_builder.gd`

`class_name VoxPropBuilder` · 55 lines

`godot/scripts/systems/vox_prop_builder.gd`

> VoxPropBuilder — a parsed `.vox` model into the cells of a destructible prop. PURE. PROP_PIPELINE_PLAN PP4. Steps, in order: SCALE (each source voxel becomes `scale`^3 board voxels; the target is the board voxel, 1/8 GU), MATERIAL (each palette index resolves to a registry material id through `material_of`), HOLLOW (keep only voxels with an empty 6-neighbour, like the crate's shell: a 16^3 model is ~1 200 claims, not 4 096), CENTRE (the model stands on the floor, centred on the footprint area). The result is grouped by material: one entry per material, each a list of cells in footprint-local voxel coordinates (x, y horizontal, z UP = the board level above the floor), because the store holds one material per container.

---

### `voxel_store.gd`

`class_name VoxelStore` · extends `RefCounted` · 873 lines

`godot/scripts/systems/voxel_store.gd`

> VoxelStore — the packed voxel store, THE writer and the only place voxel state lives. RENDER3D R3D-1b (`RENDER3D_MASTER_PLAN` §4) built this as a SHADOW beside the `Voxel` objects: every claim's state in flat per-voxel arrays, contiguous per container, plus a derived dense grid that answers "is this cell occupied, and by which claim". R3D-1c moved every reader onto it, one subsystem at a time, gated against the objects. R3D-1d removed the objects. `Voxel` is now a thin wrapper (`claim: int` + this store) — it holds no state of its own, so there is nothing left to mirror. `set_damage()` / `set_visible()` below ARE the write seam; `Voxel.set_damage()` / `set_visible()` just forward to them and record dirty bookkeeping. Built from the registries after every board build (`Room._rebuild_voxel_store()`). `BoardProbe.write_store()` dumps it for `board_probe.py gate`. A CLAIM is one `Voxel` in one container. PLAYGROUND holds 216 104 claims in 215 432 cells: where two slices of one GU meet at a corner, both claim the cell, and under a blast their states diverge (R3D-1a). The store keeps both, exactly as the objects do. THE ARRAYS, per claim, in container order (slices, slabs, junction columns — the prediction WALK's order): state  bit 0 visible · bits 1-2 damage · bit 3 blast · bits 4-6 carved side (`BoardProbe`'s packing) aux    variant (low nibble) · substrate (high nibble) mat    index into `material_ids`, band-resolved on a slice, the override on a column xyz    grid x, grid y, level THE DERIVED GRID, per cell of the padded bounds (2 cells and 2 levels of air on every side, as R3D-1a measured it, so a reader's ±1/±2 neighbour read needs no bounds check): occ    1 when ANY claim of the cell is visible owner  the first visible claim, else the first claim, else -1 A cell more than one claim holds is listed in `_multi`, so a write can recompute it. FINDING A CLAIM FROM A VOXEL costs no field on `Voxel`. Each container's voxels are laid out in a regular box — level, then y, then x — so the claim is the container's offset plus arithmetic on the voxel's own cell. That is VERIFIED for every voxel when the store is built; a container whose order breaks it gets a lookup table instead, and is counted, so the arithmetic is never trusted blind.

**Constants / tuning**
- `PAD` = `2`
- `KIND_SLICE` = `0`
- `KIND_SLAB` = `1`
- `KIND_COLUMN` = `2`
- `KIND_PROP` = `3`
- `GEOM_STRIDE` = `7`
- `CELL_STRIDE` = `4`

**Public vars**
- `var claims: int = 0`
- `var state := PackedByteArray()`
- `var aux := PackedByteArray()`
- `var mat := PackedByteArray()`
- `var xyz := PackedInt32Array()`
- `var pane := PackedByteArray()`
- `var material_ids := PackedStringArray()`
- `var walk_cache: Dictionary = {}`
- `var gone_claims: Dictionary = {}`
- `var x0: int = 0`
- `var y0: int = 0`
- `var l0: int = 0`
- `var w: int = 0`
- `var h: int = 0`
- `var nl: int = 0`
- `var plane: int = 0`
- `var occ := PackedByteArray()`
- `var owner := PackedInt32Array()`
- `var container_ids := PackedStringArray()`
- `var containers: Array = []`
- `var claim_container := PackedInt32Array()`
- `var dirty_bits := PackedByteArray()`
- `var container_kinds := PackedByteArray()`
- `var writes_mirrored: int = 0`
- `var writes_unknown_container: int = 0`
- `var writes_misplaced: int = 0`
- `var build_ms: float = 0.0`

**Public API**
- `func last_claim_at(x: int, y: int, level: int) -> int:`
- `func distinct_cells() -> int:`
- `func make_voxel(claim: int, container: Object) -> Voxel:`
- `func container_of(claim: int) -> Object:`
- `func voxel_of(claim: int) -> Voxel:`
- `func mark_dirty(claim: int) -> bool:`
- `func unmark_dirty(claim: int) -> bool:`
- `func cell_index(x: int, y: int, level: int) -> int:`
- `func has_cell(x: int, y: int, level: int) -> bool:`
- `func has_solid(x: int, y: int, level: int) -> bool:`
- `func claim_of(v: Voxel) -> int:`
- `func mirror(v: Voxel) -> void:`
- `func set_visible(claim: int, v: bool) -> bool:`
- `func set_damage(claim: int, new_state: int, from_blast: bool, carved_side: int, variant: int, substrate: int) -> bool:`
- `func grid_mismatches() -> int:`
- `func occupancy_dict(predict_destroyed: Dictionary = {}) -> Dictionary:`
- `func occupancy_live(changes: Array[Vector3i]) -> Dictionary:`
- `func occupancy_live_erasing(predict: Dictionary, changes: Array[Vector3i], erased: Array[Vector3i]) -> Dictionary:`

---

### `wood_pattern.gd`

`class_name WoodPattern` · extends `"res://godot/scripts/systems/material_registry.gd".PatternAlgorithm` · 32 lines

`godot/scripts/systems/wood_pattern.gd`

> WoodPattern — Columnar periodic grooves Simulates wood grain with vertical groove directionality

**Public API**
- `func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:`

---

### `world_render_scale.gd`

extends `Node` · 172 lines

`godot/scripts/systems/world_render_scale.gd`

> WorldRenderScale — the world renders below the screen's resolution; the HUD does not. TEL-UI-02 (DEVICE_DIAGNOSTICS_MASTER_PLAN §13 Q9). Director, 2026-09-14: *"Pode seguir com o TEL-UI-02, escala 0,75"*. DIAG-17 (§10.17.4) measured pixel fill at 36–47 ms of the Moto's GPU frame at every zoom, and rendering the whole 2D at the canvas size took the idle frame 60 → 23.8 ms — but that instrument also upscaled the HUD. This renders only the WORLD at a fraction of the screen's pixels. HOW — the world is drawn once, by a SubViewport, and never by the root viewport: - The SubViewport SHARES the root's World2D. No world node moves in the tree: `get_viewport()` still answers the root, and input picking (`_screen_to_tile()`, which reads the root's canvas transform) is untouched. - Its canvas transform is the root's (the camera's), scaled to its own pixels, and copied on `RenderingServer.frame_pre_draw` so it never lags the camera a frame. - Its texture is shown by a TextureRect in a CanvasLayer at layer -1, beneath the fog and the HUD. - The root viewport's `canvas_cull_mask` keeps ONLY `MAIN_BIT`, which every CanvasItem inside one of the root's CanvasLayers carries (added as it enters the tree). So the root draws the HUD, the fog and the scaled world — and not the world a second time. PROVEN before it was wired — a standalone spike on this engine build, desktop, real captures (2026-09-14): world content on the same pixel with the scale on and off, a HUD rect's pixel box identical, and with the displayed texture hidden the root viewport held ZERO world pixels. The root had really stopped drawing the world. ⚠️ EACH AXIS HAS ITS OWN SCALE. The spike scaled both axes by the width's ratio; rounding the SubViewport's height to whole pixels made the vertical ratio differ by 0.16%, and world content drifted ~1.5 px down the screen. Each axis is scaled by its own pixel ratio here, so a world point maps onto the display rect exactly. At 1.0 the mechanism is OFF — no SubViewport exists and the cull mask is every bit — so D (§13 Q8) is the unscaled path itself, not a 1.0 copy of this one. Shaders that read the screen (`glass_pane`, the explosion flash) are world nodes, so they read the SubViewport's own screen: the world, as before. `vision_fog` reads only SCREEN_UV and stays in the root, drawn over the scaled world.

**Constants / tuning**
- `MAIN_BIT` = `1 << 31`
- `EVERY_BIT` = `0xFFFFFFFF`
- `MIN_SCALE` = `0.25`

**Public API**
- `func current_scale() -> float:`
- `func is_active() -> bool:`
- `func viewport_rid() -> RID:`
- `func set_measure(enabled: bool) -> void:`
- `func apply(scale: float) -> void:`

---

## tools/

### `actor_decisions_selftest.gd`

extends `SceneTree` · 149 lines

`godot/scripts/tools/actor_decisions_selftest.gd`

> actor_decisions_selftest — R3D-ACTORS: what `ActorPose` decides for the live mesh, and how `ActorMesh3D` turns a facing into a yaw. The rendering is checked by capture; this pins the decisions a capture cannot see: the one-time `throw_released` (a release that never fires hangs `execute_grenade_throw()`), the cancel firing nothing, D44's reduction of a diagonal, the names the rig has no action for being refused, and the rig's front being its local -Z.

**Constants / tuning**
- `ActorPoseRef` = `preload("res://godot/scripts/agents/actor_pose.gd")`
- `ActorMesh3DRef` = `preload("res://godot/scripts/geometry/actor_mesh3d.gd")`
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`

---

### `blast_calculator_selftest.gd`

extends `SceneTree` · 2423 lines

`godot/scripts/tools/blast_calculator_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 3 — BlastCalculator selftest. Rodar: godot --headless --script res://godot/scripts/tools/blast_calculator_selftest.gd Synthetic fixtures only (SliceGenerator/SlabGenerator against a hand-built Edge list), same discipline as roof_slab_selftest.gd/slab_render_selftest.gd — no real map involved. Real-map end-to-end proof is the screenshot captures (INFILTRAITOR_CAPTURE_ACTION=test_zone_menu/test_zone_detonate).

**Constants / tuning**
- `PickMathRef` = `preload("res://godot/scripts/geometry/pick_math.gd")`
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
- `func test_throw_line_clamp_range_and_walls() -> void:`
- `func test_throw_flies_over_props() -> void:`
- `func test_charred_soot_code() -> void:`
- `func test_prop_boundary_rings() -> void:`
- `func test_prop_shot_impact() -> void:`
- `func test_prop_pick_ray_box() -> void:`
- `func test_flood_capped_at_bomb_range() -> void:`
- `func test_affected_slice_on_source_gu_boundary() -> void:`
- `func test_deterministic_selection_is_stable() -> void:`
- `func test_deterministic_selection_differs_by_salt_and_container() -> void:`
- `func test_metal_container_produces_cracked_not_destroyed() -> void:`
- `func test_damage_tiers_are_mutually_exclusive() -> void:`
- `func test_wood_container_mostly_destroyed_at_ring_zero() -> void:`
- `func test_ring_beyond_range_untouched() -> void:`
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
- `func test_point_impact_side_follows_the_shooters_gu() -> void:`
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
- `func test_crater_crack_absent_without_weights() -> void:`
- `func test_crater_crack_bands_and_severity_ladder() -> void:`

---

### `blast_purity_selftest.gd`

extends `SceneTree` · 675 lines

`godot/scripts/tools/blast_purity_selftest.gd`

> Prediction-layer selftest (PREDICTION_MASTER_PLAN Tasks 2-6, 2026-08-09). Purity and determinism (P-PURE, P-DELTA), frame-slicing and cancellation (P-SLICE), and the cache's sweep/invalidation behaviour (P-CACHE). Rodar: python3 tools/persistent/run_selftests.py --only blast_purity This is the test §11.4 calls "the test that makes the whole plan safe": it asserts that computing a detonation changes NOTHING about the world, so a prediction that is computed and thrown away costs nothing but the time. **Task 3 widened its subject from the two mutators to the whole pass.** It opened running a hand-written mirror of `build_plan()`'s damage phase, because `build_plan()` itself still committed and would have defeated a purity test outright. Now that P-DELTA made the builder pure, the mirror is gone and every test below runs the REAL `DetonationPlanBuilder.build_plan()` — which is both a stronger claim (the whole 170 ms pipeline is pure, not just its damage step) and one fewer copy of the pipeline free to drift out of sync with the original. Why it lives in its own file rather than inside blast_calculator_selftest.gd: that suite is Task 2's REGRESSION NET — its ~20 direct calls to the mutating `apply_*` functions pin today's behaviour, and the task's own gate is that it passes with **zero edits**. Adding to it would have compromised the one piece of evidence the refactor rests on. Everything here runs against the REAL PLAYGROUND map and the REAL frag grenade, not a synthetic patch — CLAUDE.md's own standing lesson (a floor-dent feature that passed its fixture with 69 dents and produced ZERO on the real map). Test 3 exists specifically to make a silently-inert simulate impossible to mistake for a clean one. RED-BEFORE-GREEN, recorded because a purity test that has never failed proves nothing. With one `voxel.set_damage(...)` added inside `BlastCalculator.damage_entry()` — the smallest edit that makes BOTH simulate functions impure at once — this run came back: ✗ 167 voxel(s) changed state during build_plan() (e.g. (7, 11) level 0: [0, false, 0, 0, 0, true, false] -> [2, true, 0, 0, 0, false, true]) ✗ 3 container(s) had their dirty_count moved by build_plan() RESULT: 6 PASS, 2 FAIL Note what stayed green under that break, because it is the reason test 1 has to exist separately: determinism (2) and the tier census (3) both still passed, and test 4 still reported every entry landing correctly — it merely counted 167 no-ops instead of 0. An impure builder is invisible to every check here except this one.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
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

### `board_look_selftest.gd`

extends `SceneTree` · 81 lines

`godot/scripts/tools/board_look_selftest.gd`

---

### `board_probe_selftest.gd`

extends `SceneTree` · 203 lines

`godot/scripts/tools/board_probe_selftest.gd`

> RENDER3D R3D-0 Test: the BoardProbe dump format. Run: python3 tools/persistent/run_selftests.py --only board_probe WHAT THIS PINS — the writer half. The comparison lives in `tools/persistent/board_probe.py diff` and is proven on the real path (the gate's control: a grenade must move the dump). This pins that the writer puts each fact where that tool reads it, and that nothing else moves: 1. Two dumps of an unchanged world are the same bytes. 2. One damaged voxel changes exactly one line — its container's — and the four state bytes of that voxel decode to the damage written, while every other voxel's bytes stay put (assert identity, not absence). 3. A banded slice carries its material PER VOXEL: the band's level reads the band's material, the level beside it reads the base. 4. One plane texel changes exactly one line — that level's `P` record. 5. A value a byte cannot hold aborts the write loudly and leaves no file. A wrapped byte would match a voxel it does not match.

**Constants / tuning**
- `BoardProbeClass` = `preload("res://godot/scripts/systems/board_probe.gd")`
- `OUT_DIR` = `"user://board_probe_selftest"`
- `BAND_LEVEL_REL` = `1`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_repeatable(fixture: Dictionary, dump_a: String) -> void:`
- `func test_one_damage_moves_one_line(fixture: Dictionary, dump_a: String) -> String:`
- `func test_banded_material_per_voxel(dump_a: String) -> void:`
- `func test_plane_texel_moves_its_line(fixture: Dictionary, dump_c: String) -> void:`
- `func test_out_of_range_aborts(fixture: Dictionary) -> void:`

---

### `circle_field_octagon_selftest.gd`

extends `SceneTree` · 53 lines

`godot/scripts/tools/circle_field_octagon_selftest.gd`

> R3D-SURFACES — the disc field's octagon: `CircleField3D.visible_radius` follows the feather (a hard edge keeps the whole disc, a soft one drops its invisible rim), and `QuadField3D._octagon_mesh` is a regular octagon whose inscribed circle is exactly that radius, so nothing visible is clipped and the rasterised area drops (the Moto pays per blended pixel).

**Constants / tuning**
- `CircleFieldClass` = `preload("res://godot/scripts/geometry/circle_field3d.gd")`
- `QuadFieldClass` = `preload("res://godot/scripts/geometry/quad_field3d.gd")`

---

### `cosmetic_density_selftest.gd`

extends `SceneTree` · 31 lines

`godot/scripts/tools/cosmetic_density_selftest.gd`

> Roadmap A1 (2026-10-07) — CosmeticDensity: the default is the identity (so every gate stays bit-identical), the tiers thin a count without erasing it, a bad value is refused loudly (falls back), and the factor is clamped to its floor.

---

### `detonation_plan_selftest.gd`

extends `SceneTree` · 998 lines

`godot/scripts/tools/detonation_plan_selftest.gd`

> E-PLAN — DetonationPlanBuilder selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 4, 2026-08-07). Rodar: godot --headless --script res://godot/scripts/tools/detonation_plan_selftest.gd Boots the REAL PLAYGROUND map through the exact room.gd::load_map() path (mirrors the deleted damage_atom_bake_selftest.gd's own MinimalRoom scaffold), runs DetonationPlanBuilder.build_plan() against a REAL grenade throw at a real wall's own GU, and proves: 1. The Task 4 gate itself — a printed wave census (cell counts per ring, per wave kind) from a real detonation, not a synthetic fixture. 2. Every dented/cracked/expose entry carries a real, resolved (source_id, atlas_coords, alt) triple — never a placeholder. 3. build_plan() never mutates the live TileMapLayer — every placed cell's (source_id, atlas_coords, alt) is BYTE-IDENTICAL before and after, proven by a real snapshot diff, not by re-reading the code's own claim. 4. The exposure fallback (§2/B5) fires for real: at least one destroy entry carries a non-empty `expose` array once the crater opens the floor. 5. smoke_ring_weights is consumed for real (duration/scale fall off with ring, matching the JSON's own weights) — the "still unread" gap Task 3's closure note flagged. 6. The per-tier ring gates from the REAL frag_grenade.json hold on real data: crack_ring_weights[0]=0.0 means ring 0 never has a cracked entry, dent_ring_weights[2]=0.0 means ring 2 never has a dented one. 7. E-EMBER-01: a real blast at PLAYGROUND's own WOOD wall queues embers, every one on a SURVIVING combustible voxel 6-adjacent to a hole this same blast opens — cell->material read off the live registries, not assumed. Non-zero on real data is the point: this is the exact shape of failure the floor-dent case (69 on a fixture, 0 on PLAYGROUND) is remembered for. 8. E-SMOKE-TINT-01: every per-voxel smoke entry carries the material it came from, without which the choreographer cannot tint the puff. 9. E-EMBER-02: fire creeps UPWARD one level at a time (every rung sits directly above another lit voxel and burns shorter than it), the creep is FNV-1a-deterministic across two builds of the same blast, and an ember COOLS yellow-hot -> deep red while dimming — the one detail the Director first described inverted and then corrected. 10. E-DEBRIS-01: dust/sparks/chips fire only on cells the blast DESTROYS, only on materials their own rule lists, with counts inside their range and identical across two builds — plus the contract that a ctx carrying no debris policy produces exactly zero, so no pre-existing caller moved. Every expectation is checked against the REAL plan/registry/renderer state — never read back from the code under test's own success claim.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
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

### `dev_flags_selftest.gd`

extends `Node` · 106 lines

`godot/scripts/tools/dev_flags_selftest.gd`

> DIAG-01 Test: the DevFlags seam. ⚠️ RUNS AS A SCENE, not as a `--script` SceneTree — `DevFlags` is an autoload, and Godot registers autoload names as parse-time globals only when a MAIN SCENE runs. Under `--script` this file would fail to LOAD, not merely fail its assertions. `run_selftests.py` knows to launch a `*_selftest.tscn` that way. (`version_info_selftest` carries the same warning for the same reason.) ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch must `return` as well — otherwise a later `quit(0)` OVERWRITES the failure's exit code and the suite reports PASS. WHAT THIS PINS, and why each one is here rather than assumed: 1. The autoload exists and answers. 2. **The environment wins over the file.** This is the property that makes the seam safe to introduce at all: desktop behaviour has to stay bit-identical, so a stale flags file must never override what a developer typed on the command line. 3. An unset flag returns the caller's fallback, and `on()` is false — the project's `== "1"` convention, not "any non-empty value". 4. `num()` refuses a non-integer instead of silently yielding 0. A flag typo that reads as zero is the kind of defect that passes for the whole life of the bug.

**Constants / tuning**
- `FLAG_ENV` = `"INFILTRAITOR_SELFTEST_DEVFLAG"`
- `FLAG_NAME` = `"SELFTEST_DEVFLAG"`

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

extends `SceneTree` · 146 lines

`godot/scripts/tools/earth_variant_selftest.gd`

> DESTRUCTION_MASTER_PLAN D2/D4 — EarthVariantSelector selftest. Rodar: godot --headless --script res://godot/scripts/tools/earth_variant_selftest.gd This is the "core, isolated, verified before anything consumes it" prompt: no VoxelBoard/TileSet/Slab wiring here on purpose — that's the next wave.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_determinism() -> void:`
- `func test_range() -> void:`
- `func test_not_constant() -> void:`
- `func test_distribution_uses_all_variants() -> void:`
- `func test_fnv1a_static_call_matches_instance_call() -> void:`

---

### `fixed_floor_selftest.gd`

extends `SceneTree` · 151 lines

`godot/scripts/tools/fixed_floor_selftest.gd`

> DESTRUCTION_MASTER_PLAN D13 — fixed floor level selftest. Rodar: godot --headless --script res://godot/scripts/tools/fixed_floor_selftest.gd Proves register_fixed_level() (the 7 non-destructible levels) and register_slab() (the 1 destructible top) compose into the full D13 8-level stack — without the fixed levels ever touching Slab/Voxel/dirty-tracking. R3D-END (END-1): [1] (the 64 placed cells' variant) went with the 2D board (it read placed TILES; no tile is written any more). The rest stays until END-4 deletes `register_fixed_level()` and the level layers.

**Constants / tuning**
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_fixed_level_does_not_touch_slab_registry() -> void:`
- `func test_one_call_builds_only_the_requested_level() -> void:`
- `func test_full_d13_stack_top_destructible_rest_fixed() -> void:`

---

### `floor_integration_selftest.gd`

extends `SceneTree` · 247 lines

`godot/scripts/tools/floor_integration_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 2 — real map integration selftest. Rodar: godot --headless --script res://godot/scripts/tools/floor_integration_selftest.gd Drives the REAL RoomBuilder.build_from_layout() against a REAL compiled map (PLAYGROUND, via FileMapSource + MapCompiler — the exact same path room.gd::load_map() uses), not a synthetic map_spec. Proves the floor integration lands correctly end-to-end: every GU gets a real Slab at level -1, cells round-trip against an independently re-derived hash, and the existing wall/prop pipeline is unaffected.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_real_playground_map_gets_a_real_floor() -> void:`

---

### `floor_openings_selftest.gd`

extends `SceneTree` · 70 lines

`godot/scripts/tools/floor_openings_selftest.gd`

> R3D-SURFACES SM-6b — `FloorOpenings` and its path into the floor: which cells an opening carves (slats with a frame, a bare shaft, a multi-GU rectangle), that `SlabGenerator` really builds slabs WITHOUT them on both floor levels, and that the section reaches the compiler on the real gallery map.

**Constants / tuning**
- `FloorOpeningsClass` = `preload("res://godot/scripts/geometry/floor_openings.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`

---

### `floor_pile_tiles_selftest.gd`

extends `SceneTree` · 78 lines

`godot/scripts/tools/floor_pile_tiles_selftest.gd`

> R3D-SURFACES tile culling — `FloorPile3D.tile_mask` keeps exactly the tiles that hold alpha, and a pile built with `cull_tiles` rasterises only those: a stamp opaque in one corner becomes one small quad, an empty one nothing, a full one the same quad as before; the mipmap chain is built.

**Constants / tuning**
- `FloorPileClass` = `preload("res://godot/scripts/geometry/floor_pile3d.gd")`

---

### `floor_zone_bake_selftest.gd`

extends `SceneTree` · 196 lines

`godot/scripts/tools/floor_zone_bake_selftest.gd`

> FLOOR-BAKE-01 — floor-zone photographic ground bake selftest. Rodar: godot --headless --script res://godot/scripts/tools/floor_zone_bake_selftest.gd R3D-END END-4: the compositor and the baked lookup are gone, and with them criteria [1]-[3] (the shared page family, the resolved atoms, pixel continuity, isotropy and the full-colour modulate) and [4] (END-1). What survives is the data contract: 5. ROTATION: building the E view puts a zone's Slab material at the correctly-rotated GU, exactly like roof's block rotation 6. BUFFER RING (R3D-FINISH F2): the ring around the playable area is the SAME ground as the playable edge it continues The expectation is re-derived locally (own rotation math), never read back from the code under test.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `FLOOR_TOP_LEVEL` = `GeometryCoords.FLOOR_TOP_LEVEL`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_5_rotated_view_zones_follow_declared_material() -> void:`
- `func test_6_buffer_ring_continues_the_edge_ground() -> void:`

---

### `geometry_selftest.gd`

extends `SceneTree` · 232 lines

`godot/scripts/tools/geometry_selftest.gd`

> Geometry Module — Selftest: minimal validation Headless selftest Usage: godot --headless --script geometry_selftest.gd

---

### `glass_crack_selftest.gd`

extends `SceneTree` · 1683 lines

`godot/scripts/tools/glass_crack_selftest.gd`

> GLASS_MASTER_PLAN §8.1 / CRACK-01 — the CRACKED tier for glass. Rodar: python3 tools/persistent/run_selftests.py --only glass_crack §8.1 was written up as a CONTRADICTION: the art order's step 3 asked to raise `glass.json`'s `crack_factor` above 0 and add `glass` to `IMPACT_DECAL_MATERIALS`, which together make `voxel_decal_selftest` [12] demand `decal_crack_glass_{0,1,2}.png` — the per-voxel crack family G-D21 explicitly folded into the fracture SHEET. The resolution (Director, 2026-09-02): glass reaches CRACKED by the route it ALREADY has — `ShotPunchTable.damage_state_for()` returns CRACKED for a sub-breach glass hit — and NOT through the blast `crack_factor` probability path. So `crack_factor` stays 0.0, `glass` stays out of both decal lists, and the whole [12] coupling is untouched. Glass is simply the first material whose CRACKED art is a sheet, not a decal family. This suite is the guard on that resolution — it fails if a future edit "fixes" §8.1 by commissioning the decal family, and (from CRACK-01 stages B/C) it grows to pin the render and the shot-path event. What each test catches: [1] the CRACKED tier going unreachable for glass — the enum path breaking. [2] a crack DECAL FAMILY appearing for glass — in data, in the wiring lists, or on disk. [3] the fracture SHEETS (the real CRACKED art) going missing or unimported. [8] the crack coming back INSIDE the pane shader (glass_pane3d.gdshader) — CRACK-02 / G-D27 took it out of the voxel because a crack drawn there inherits `dim`, `cover` and the quad seams, and no tuning survives that; and a uniform the mirror feeds that glass_crack3d.gdshader does not declare (dropped with no error). [11] a crack bleeding past the frame of the pane it is on. [12] G-D30's cut reading anything other than the live glass state (the store's pane cells), the occupancy rows going upside down, or the dial collapsing to a boolean. [13] S-3's rebuild path acquiring side effects — a perspective flip that re-damages the pane it is only supposed to redraw. [16] the opening FAMILY going malformed — an opening that does not leave the struck cell, a pooled id with no shape, a pick that stops hashing, or the SHEET's void drifting from the voxel cut (G-D34's whole point). [15] the applied hole drifting from the opening it claims to be — a cell cut that coverage() calls outside, or left whole that it calls PARTIAL — and the rebuild path (a flip, a load) shaping different cells from the shot path. [22] a rotation re-shaping every standing hole with the DEFAULT opening — CRACK-04, GLASS §16.13. The mechanism was never broken; the ORDER was. The perspective rebuild renders the pane intact, erases the recorded holes back out of it and flushes, so unless it CLAIMS first the flush sees a batch of unclaimed erases and invents a shape for each. R3D-END (END-2): [10] (the 2D sprite's transform on the wall-face basis), [14] (the shard ATOMS a cell's cut was drawn with) and [20] (the remnant atom) went with the 2D board, whose tiles they drew; the openings, the shaped cells, the occupancy and the sheet are what the 3D board draws from, and those stay pinned.

**Constants / tuning**
- `ShotPunchTableClass` = `preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")`
- `MaterialResistanceTableClass` = `preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `GlassMaterialsClass` = `preload("res://godot/scripts/systems/glass_materials.gd")`
- `GlassCrackClass` = `preload("res://godot/scripts/systems/destruction/glass_crack.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `GlassOpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `GlassShatterClass` = `preload("res://godot/scripts/systems/destruction/glass_shatter.gd")`
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
- `func test_the_pane_bounds_clip_the_sprite() -> void:`
- `func test_the_occupancy_cut_reads_the_live_tilemap() -> void:`
- `func test_sprite_spec_is_render_only() -> void:`
- `func test_the_opening_family_is_well_formed() -> void:`
- `func test_only_the_four_orthogonal_neighbours_become_shards() -> void:`
- `func test_the_armored_sheet_is_chosen_by_the_pane_not_the_weapon() -> void:`
- `func test_the_craze_field_covers_the_pane_and_tiles() -> void:`
- `func test_the_craze_field_is_cut_to_the_holes() -> void:`
- `func test_an_unclaimed_hole_is_reshaped_and_the_replay_claims_first() -> void:`

---

### `glass_fall_selftest.gd`

extends `SceneTree` · 454 lines

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
- `func test_the_shockwave_is_radial_not_parallel() -> void:`
- `func test_the_sliced_index_is_the_one_shot_index() -> void:`

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

extends `SceneTree` · 508 lines

`godot/scripts/tools/glass_shard_shapes_selftest.gd`

> GLASS G4-1 / G-D38 + G-D39 + G-D44 — GlassShardShapes selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_shard_shapes [1] G-D44's size law, member by member, with the measured numbers printed [2] every member is ANGULAR — straight chords, not a round blob [3] the size law has TEETH: a filled cell is rejected by it [4] the anchored form stays in its cell, touches its edge, and is FLAT there [5] a corner anchor is cut on BOTH edges, not on a 45 degree plane [6] the flop is a different placement, not the same polygon twice [7] every member is REACHABLE by pick() [8] the family shares no member with GlassOpening [9] an empty anchor mask invents no placement

**Constants / tuning**
- `ShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `OpeningClass` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
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
- `func test_the_rain_ages_in_frames_and_frees_itself() -> void:`

---

### `glass_shatter_selftest.gd`

extends `SceneTree` · 1588 lines

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

---

### `glass_transparency_selftest.gd`

extends `SceneTree` · 436 lines

`godot/scripts/tools/glass_transparency_selftest.gd`

> GLASS_MASTER_PLAN G1 — glass transparency routing selftest. Rodar: python3 tools/persistent/run_selftests.py --only glass_transparency Born as the round-trip proof of G1's routing of glass cells onto their own tile layers (G-D1); what it still pins is the glass STATE and grouping those layers used to carry, now asked of the store and the grouper. R3D-END (END-1): the tests that read which TILE LAYER a glass voxel landed on ([1] Option A's mirror, [1b] the seam cull, [2] lazy sublayers, [3] concrete on the opaque layer, [4] a destroyed pane cell erased from its layer) went with the 2D board: no tile is written any more, and the glass state lives in the `VoxelStore` (R3D-14). [7] now reads the store's pane cells; [12] reads the plan's tile-less entry. END-2 took [11] (per-member pane atoms and the tint in their BLUE channel: the 3D board tints each member's material directly). What is left, worst first: 5. Intact glass dropped from `build_occupancy()` — the light field would stop seeing the pane. 7. A G-D9 brick band read as pane glass (or the reverse) — a brick sill that cracks and rains shards. 6/10. Panes grouped wrong (`GlassPaneGrouper`) — a plain pane merged into an armoured one defeats the armour. 8. Glass occluding (O7) — the cutaway would ghost a see-through pane. 9. A pane larger than the fracture sheet accepted silently (G-D23). 12. A damaged glass voxel yielding an opaque plan entry (GLASS-OLIVE).

**Constants / tuning**
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `ground_canvas3d_selftest.gd`

extends `SceneTree` · 246 lines

`godot/scripts/tools/ground_canvas3d_selftest.gd`

> Ground-canvas selftest — RENDER3D R3D-5b. Run: python3 tools/persistent/run_selftests.py --only ground_canvas3d_selftest The claim: an overlay drawn through `GroundCanvas3D` lands on the SAME PIXELS it would have drawn in 2D — every vertex of every polygon, line quad and circle, carried onto the ground plane and projected through a real `Camera3D`, comes out at the 2D point it came from. If that holds, moving the overlay onto the ground changes its depth and nothing else. The camera and the 2D→ground affine are built exactly as `Board3DLive._make_camera()` builds them; a comparison against the canvas's own maths would pass whatever the constants said.

**Constants / tuning**
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`
- `PPU` = `256.0 / sqrt(2.0)`
- `EPS_PX` = `0.05`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_polygon_vertices_land_on_their_pixels() -> void:`
- `func test_line_is_a_quad_of_the_asked_width() -> void:`
- `func test_circle_and_polyline() -> void:`
- `func test_owner_transform_is_applied() -> void:`
- `func test_empty_draw_publishes_nothing() -> void:`
- `func test_per_vertex_colours_and_positions() -> void:`
- `func test_rect_transform_and_string() -> void:`

---

### `ground_decals_selftest.gd`

extends `SceneTree` · 80 lines

`godot/scripts/tools/ground_decals_selftest.gd`

> R3D-SURFACES S2 — the `ground_decals` section, end to end on the real FLOOR_ZONES_TEST map: FileMapSource reads it, MapCompiler forwards `ground_decal_instances` shifted by the buffer, the voxel lattice (1/8 GU) holds, a variant is a stable pick, and a decal ends with the floor-top voxel under its footprint (and only then).

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `GroundDecals3DClass` = `preload("res://godot/scripts/geometry/ground_decals3d.gd")`

---

### `ground_grid_selftest.gd`

extends `SceneTree` · 117 lines

`godot/scripts/tools/ground_grid_selftest.gd`

> GroundGrid selftest — RENDER3D R3D-5a. Run: python3 tools/persistent/run_selftests.py --only ground_grid_selftest The claim: `GroundGrid` IS the lattice the floor TileMapLayer gives, so replacing the layer's `map_to_local()` with it in input and in every actor's placement changes nothing. Asserted against a real TileMapLayer on a TileSet with the game's own lattice settings — not against the formula's own output — for a range of cells (negative ones included) and for random points, including the exact algorithm `Room` uses to pick a tile under a click (`_screen_to_tile`).

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `OFFSET` = `Vector2(-37.0, 21.0)`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_map_to_local_matches_the_tilemap() -> void:`
- `func test_cell_containing_matches_the_room_pick() -> void:`
- `func test_cell_center_round_trips() -> void:`

---

### `ground_scatter_selftest.gd`

extends `SceneTree` · 110 lines

`godot/scripts/tools/ground_scatter_selftest.gd`

> R3D-SURFACES SM-2 — `GroundScatter`: the expansion of a scatter zone is deterministic, stays inside its zone, lies on the voxel lattice, honours the kind's scale range, the floor rules (no leaf in the desert) and the avoid mask, scales with density, and the section reaches the compiler on the real SURFACES_SCATTER map.

**Constants / tuning**
- `GroundScatterClass` = `preload("res://godot/scripts/geometry/ground_scatter.gd")`
- `SurfaceRulesClass` = `preload("res://godot/scripts/systems/surface_rules.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`

**Public API**
- `func spec_for_mix() -> Dictionary:`

---

### `half_thickness_selftest.gd`

extends `SceneTree` · 310 lines

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

### `hud_seam_selftest.gd`

extends `Node` · 202 lines

`godot/scripts/tools/hud_seam_selftest.gd`

> UI-SPLIT-02 — the HUD seam between the engine and the design branch. What this pins is the CONTRACT, not the look: HudController must resolve every widget it needs out of the real godot/scenes/ui/hud.tscn, raise a signal for each interaction the engine acts on, and change the widgets when the engine asks. If that holds, the interface can be restructured on the design branch without the engine noticing — which is the whole reason the split exists. It is written against the REAL scene, deliberately. A fixture built here would be assembled from the node names this test already assumes, so it could not catch the failure that matters: someone renaming a node in hud.tscn and the engine silently losing a null @onready. Loading the shipped scene is what makes a rename fail HERE instead of on the Director's screen. RUNS AS A SCENE (TEST-DEBT-03): HudController reaches /root/Localization and calls tr(), so it needs autoloads, which exist only when a MAIN SCENE runs. run_selftests.py launches the sibling .tscn for exactly this reason. ⚠️ SceneTree.quit(code) is DEFERRED — every failing branch must `return` too, or a later quit(0) overwrites the failure's exit code.

**Constants / tuning**
- `HudControllerClass` = `preload("res://godot/scripts/controllers/hud_controller.gd")`
- `HUD_SCENE` = `"res://godot/scenes/ui/hud.tscn"`

---

### `input_controller_selftest.gd`

extends `SceneTree` · 273 lines

`godot/scripts/tools/input_controller_selftest.gd`

> !/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script INPUT-01-c Test: Verify InputController dispatches all 16 actions with real signal firing. Run: godot --headless --script godot/scripts/tools/input_controller_selftest.gd

**Constants / tuning**
- `InputControllerClass` = `preload("res://godot/scripts/world/controllers/input_controller.gd")`

**Public vars**
- `var test_passed: int = 0`
- `var test_failed: int = 0`
- `var action_expectations: Dictionary = { "ui_posture_lower": ["posture_lower_requested", []], "ui_posture_raise": ["posture_raise_requested", []], "ui_view_mode_dev": ["view_mode_requested", ["dev"]], "ui_view_mode_light": ["view_mode_requested", ["light"]], "ui_view_mode_heat": ["view_mode_requested", ["heat"]], "ui_peek": ["peek_initiated", []], "ui_move_up": ["movement_input_requested", [Vector2i.UP, false]], "ui_move_down": ["movement_input_requested", [Vector2i.DOWN, false]], "ui_move_left": ["movement_input_requested", [Vector2i.LEFT, false]], "ui_move_right": ["movement_input_requested", [Vector2i.RIGHT, false]], "debug_toggle_map_loader": ["debug_command_requested", ["toggle_map_loader"]], "debug_toggle_voxel_ruler": ["debug_command_requested", ["toggle_voxel_ruler"]], "debug_toggle_nudge_mode": ["debug_command_requested", ["toggle_nudge_mode"]], "debug_cycle_language": ["debug_command_requested", ["cycle_language"]], "debug_nudge_reset": ["debug_command_requested", ["nudge_reset"]], "debug_screenshot": ["screenshot_requested", []], }`

**Public API**
- `func test_all_actions_fire_signals() -> void:`
- `func test_screenshot_signal_firing(controller: Node, action: String, expected_signal: String, _expected_args: Array) -> void:`
- `func test_action_signal_firing(controller: Node, action: String, expected_signal: String, expected_args: Array) -> void:`
- `func assert_eq(actual: Variant, expected: Variant, message: String) -> void:`
- `func assert_true(condition: bool, message: String) -> void:`

---

### `iso_projection_selftest.gd`

extends `SceneTree` · 445 lines

`godot/scripts/tools/iso_projection_selftest.gd`

> IsoProjection selftest — the aiming overlays' geometry, checked against the REAL TileSet instead of against itself. Run: python3 tools/persistent/run_selftests.py --only iso_projection_selftest Why this file exists. T-BUBBLE's first pass sized the aim bubble with `max_ring * 112.0 * 3.0`, drew it as a circle over a 2:1 perimeter ellipse, and clamped the cursor with a third shape again. Nothing was wrong in a way a compiler could see; it was wrong in a way only the screen showed. Every claim IsoProjection makes is therefore asserted here, and test [1] asserts the two horizontal basis vectors against a real `TileSet` (isometric diamond-down, 256x128) itself — a self-comparison would pass no matter what the constants said.

**Constants / tuning**
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

extends `SceneTree` · 367 lines

`godot/scripts/tools/mapfile_roundtrip_selftest.gd`

> mapfile_roundtrip_selftest.gd — Comprehensive round-trip and migration testing Tests: 1. Basic round-trip: save spec -> load -> verify structural equality 2. Tolerant round-trip: unknown section preservation (M3) 3. Migration RED (missing migration fails loudly) + GREEN (migration present succeeds)

**Public vars**
- `var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")`
- `var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")`
- `var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")`

---

### `material_reform_selftest.gd`

extends `SceneTree` · 179 lines

`godot/scripts/tools/material_reform_selftest.gd`

> E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a, D19/D20/D21, 2026-08-06). Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd Proves the two halves of the reform independently: 1. BEHAVIOR is unified — one row per material (MaterialRegistry + MaterialResistanceTable), the old duplicate `ground_concrete` row is gone, not merely shadowed. 2. The has_facade FLAG is the contract — D34/E-SEAM-01 (Director, 2026-08-08) made texture identity follow the MATERIAL, not the surface (**reversing D20's original answer**): `has_facade == true` -> wall, roof and floor share one `facade_<id>`; `has_facade == false` -> organic ground (the photographic `slab_<id>` exception). This test pins the flag in the data. R3D-END END-4: the tests that drove the compositor (the shared modulate, the two families baked in one session, the mirrored vertical repeat, the roof/floor spec merge) went with it, and so did the generic-atlas half of test 8. R3D-END cleanup (2026-09-26): `BakePolicy` (the policy that turned the flag into a texture id) and the voxel atoms were retired, so test 3 keeps only the flag and test 8 lost its canonical-atom checks (the alias, the alpha, the identity). Every expectation is computed independently (own expected values), never read back from the code under test.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `MaterialResistanceTableClass` = `preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `material_tints_selftest.gd`

extends `SceneTree` · 47 lines

`godot/scripts/tools/material_tints_selftest.gd`

> R3D-SURFACES `material_tints` (per-map colour of a material): the albedo -> base_color conversion on real rows, the section through FileMapSource and MapCompiler on the real SURFACES_GALLERY map, and a malformed tint being refused.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`

---

### `material_tree_selftest.gd`

extends `SceneTree` · 243 lines

`godot/scripts/tools/material_tree_selftest.gd`

> ASSET_TREE_REFORM — the invariant the per-material tree makes possible. Rodar: python3 tools/persistent/run_selftests.py --only material_tree WHY THIS TEST EXISTS, stated as the bug it would have caught. Before 2026-08-21 a material's art was scattered across four flat directories, so "does concrete have everything it needs" could only be answered by grepping four folders and knowing which files each one owed. `glass` sat in `BASE_MATERIALS` and NOT in `BakeCompositor.VOXEL_MATERIALS` for months and nothing saw it, because no glass block had ever been placed — the moment one was, B6 fired with `voxel_glass.png` on disk the whole time. One folder per material turns that into a structural question, and this is the test that asks it: 1. every REGISTERED material has a folder; 2. every FOLDER is a registered material (no orphan art nothing can reach); 3. every material that claims `has_facade` has its facade file; 4. every material in `IMPACT_DECAL_MATERIALS` has a complete decal family. Deliberately reads the REAL tree and the REAL registry, not a fixture: the property under test is that the two agree on this machine, right now.

**Constants / tuning**
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `MATERIALS_ROOT` = `"res://ASSETS/materials"`
- `GENERIC_DIR` = `"_generic"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_every_registered_material_has_a_folder(registered: Array, folders: Array[String]) -> void:`
- `func test_every_folder_is_a_registered_material(registered: Array, folders: Array[String]) -> void:`
- `func test_facade_materials_have_their_facade(registry, registered: Array) -> void:`
- `func test_photo_surfaces_have_their_plane(registry, registered: Array) -> void:`
- `func test_decal_materials_have_a_complete_family() -> void:`

---

### `negative_storey_selftest.gd`

extends `SceneTree` · 156 lines

`godot/scripts/tools/negative_storey_selftest.gd`

> DESTRUCTION_MASTER_PLAN D17/D18 — negative storey selftest. Rodar: godot --headless --script res://godot/scripts/tools/negative_storey_selftest.gd Proves the floor can live at negative levels without disturbing the existing (positive) wall/block/prop pipeline at all — D17's whole claim. R3D-END (END-1): [4] and [5] (register_block_levels() / register_slab() placed cells) went with the 2D board (it read placed TILES; no tile is written any more). END-4: [6] (`_set_voxel_cell()` on an unensured level) went with the placement. The rest stays until END-6 turns the level layers into arithmetic.

**Constants / tuning**
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_negative_layer_creation_and_lookup() -> void:`
- `func test_negative_level_position_and_zindex_formula() -> void:`
- `func test_lazy_not_contiguous() -> void:`

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

### `occlusion_view_selftest.gd`

extends `SceneTree` · 105 lines

`godot/scripts/tools/occlusion_view_selftest.gd`

> R3D-ROT — the cutaway under a view is the cutaway of the TURNED world. Run: python3 tools/persistent/run_selftests.py --only occlusion_view_selftest The claim: `OcclusionSet` keyed in BASE coordinates with `view = E` gives exactly what the same set gives in the N view over the map turned a quarter turn (cells, agent and size), once its columns are turned back. Asserted for E, S and W, on a fixture with both near and far columns around the agent, comparing every column's ring and level span. A pillar in front of the agent from the east is NOT in front of him from the north, so a view the set ignores fails it.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `OcclusionSetMod` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `FIXTURE_LEVELS` = `6`
- `GU_SIZE` = `Vector2i(20, 12)`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `paint_palette_selftest.gd`

extends `SceneTree` · 74 lines

`godot/scripts/tools/paint_palette_selftest.gd`

> PaintPalette selftest — a surface declared `material@paint` wears that paint, and `repaint()` recolours exactly those. Run: python3 tools/persistent/run_selftests.py --only paint_palette_selftest

**Constants / tuning**
- `GRENADE` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `panel_base_selftest.gd`

extends `SceneTree` · 177 lines

`godot/scripts/tools/panel_base_selftest.gd`

> !/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script PANEL-01 Test: Standalone verification of PanelBase and WindowBase functionality. Run: godot --headless --script godot/scripts/tools/panel_base_selftest.gd

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

### `particle_space_selftest.gd`

extends `SceneTree` · 224 lines

`godot/scripts/tools/particle_space_selftest.gd`

> Particle-space selftest — RENDER3D R3D-4e-1. Run: python3 tools/persistent/run_selftests.py --only particle_space_selftest The claim under test is the one the whole of R3D-4e rests on: a particle carried into the world by `ParticleMath` projects, through the REAL board camera's own projection, to the pixel its 2D simulation put it on. If that holds, moving the VFX into 3D changes their depth and nothing else. The projection is asked of a real `Camera3D` configured the way `Board3DLive._make_camera()` configures it — a self-comparison against `ParticleMath` would pass whatever the constants said.

**Constants / tuning**
- `ParticleMathRef` = `preload("res://godot/scripts/geometry/particle_math.gd")`
- `QuadField3DRef` = `preload("res://godot/scripts/geometry/quad_field3d.gd")`
- `CircleField3DRef` = `preload("res://godot/scripts/geometry/circle_field3d.gd")`
- `PPU` = `256.0 / sqrt(2.0)`
- `EPS_PX` = `0.05`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_displacement_projects_to_the_same_pixels() -> void:`
- `func test_rise_is_world_up() -> void:`
- `func test_origin_from_floor_reads_the_height() -> void:`
- `func test_field_buffer_layout() -> void:`
- `func test_field_survives_an_empty_frame() -> void:`
- `func test_line_ends_land_on_their_pixels() -> void:`
- `func test_rotated_chip_corners_land_on_their_pixels() -> void:`

---

### `passage_query_selftest.gd`

extends `SceneTree` · 414 lines

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

extends `SceneTree` · 88 lines

`godot/scripts/tools/project_lint_validator.gd`

> PROJECT_LINT_VALIDATOR — Full-project GDScript parse check Walks res://godot/scripts/ and loads every .gd file, collecting parse errors

**Public vars**
- `var parse_errors: PackedStringArray = []`
- `var files_checked: int = 0`
- `var all_gd_files: PackedStringArray = []`
- `var failed_files: PackedStringArray = []`

---

### `prop_01_selftest.gd`

extends `Node` · 318 lines

`godot/scripts/tools/prop_01_selftest.gd`

> PROP-01 Acceptance Tests Tests the PropDef/PropRegistry/voxel prop rendering system TEST-DEBT-03 (2026-09-01) — RUNS AS A SCENE, not as a `--script` SceneTree. That is the whole point: criterion 7 reaches `MapCatalog.get_spec()`, which routes through `Registries.ensure_file_map_source()`, and `Registries` is an AUTOLOAD. Godot registers autoload names as parse-time globals and adds their nodes only when a MAIN SCENE runs — a `--script` run does neither, so this file used to fail to load outright (`Compile Error: Identifier not found: Registries` from map_catalog.gd) and criterion 7 could only ever SKIP itself. Launched as `res://godot/scripts/tools/prop_01_selftest.tscn` the autoloads are real, and run_selftests.py knows to invoke a `*_selftest.tscn` that way. Measured: the probe that settled it printed `VersionInfo global: true`.

**Public vars**
- `var PropDefClass`
- `var PropRegistryClass`
- `var MapCompilerClass`
- `var FileMapSourceClass`
- `var MapCatalogClass`
- `var VoxelBoardClass`

**Public API**
- `func test_criterion_1_propdef_from_json() -> void:`
- `func test_criterion_2_propregistry_override() -> void:`
- `func test_criterion_4_mapcompiler_voxel_props() -> void:`
- `func test_criterion_5_file_map_source_round_trip() -> void:`
- `func test_criterion_6_invariants_check() -> void:`
- `func test_criterion_7_non_regression() -> void:`

---

### `prop_fragment_sim_selftest.gd`

extends `SceneTree` · 250 lines

`godot/scripts/tools/prop_fragment_sim_selftest.gd`

> Selftest — PropFragmentSim (PROPS_TIER4_PLAN P2): a voxelized prop falls, is carved by the blast, piles up and slumps, deterministically and in simulated time. Synthetic table (boxes), no ASSETS needed.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `prop_model_path_selftest.gd`

extends `SceneTree` · 61 lines

`godot/scripts/tools/prop_model_path_selftest.gd`

> AUDIT 2026-10-07 — a prop's `model` is loaded with `load()` + `instantiate()` (`PropModelFit`), and `PropRegistry` reads prop JSON from `user://props/` too. A scene there can carry an embedded GDScript, so a player-supplied prop could run code (PROP_PIPELINE_PLAN: a player's file never goes through `ResourceLoader`). The loader must refuse anything but a shipped glTF/GLB under `res://`, and must refuse it BEFORE loading. The attack here is real: a `.tscn` in `user://` whose script raises a flag in `_init()`.

**Constants / tuning**
- `PropModelFitClass` = `preload("res://godot/scripts/geometry/prop_model_fit.gd")`
- `EVIL_PATH` = `"user://selftest_prop_model_path.tscn"`
- `FLAG` = `&"selftest_prop_model_path_ran"`
- `SHIPPED_MODEL` = `"res://ASSETS/props/wooden_table_02/wooden_table_02_1k.gltf"`

---

### `prop_shadow_selftest.gd`

extends `SceneTree` · 108 lines

`godot/scripts/tools/prop_shadow_selftest.gd`

> Selftest — PropShadow (PROPS_TIER4_PLAN P6): a voxel set becomes a soft floor shadow, thrown along the key light, deterministic.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `prop_slot_selftest.gd`

extends `SceneTree` · 156 lines

`godot/scripts/tools/prop_slot_selftest.gd`

> Selftest — slots, several models per slot, the validator and the fallback chain (PROP_PIPELINE_PLAN PP1, `ACTOR` D66/D69). In-memory registry and box models only (no disk, no ASSETS, no autoload).

**Constants / tuning**
- `FAMILIES` = `{"wood": "wood", "plywood": "wood", "metal": "metal", "rubber": "rubber", "generic": "generic", "glass": "glass"}`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `prop_voxelizer_selftest.gd`

extends `SceneTree` · 205 lines

`godot/scripts/tools/prop_voxelizer_selftest.gd`

> Selftest — PropVoxelizer (PROPS_TIER4_PLAN P1): a model keeps its SHAPE when it becomes board voxels. Synthetic meshes only (a table built from boxes), so it runs on a clone without the local-only ASSETS.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `registry_load_errors_selftest.gd`

extends `SceneTree` · 86 lines

`godot/scripts/tools/registry_load_errors_selftest.gd`

> AUDIT 2026-10-07 — the catalogues read their rows through `JsonFile`: a row that does not parse, has no `id`, or carries a vector field of the wrong shape is reported WITH its path (push_error + the registry's `load_errors`), never dropped in silence; a bomb past `BombDef.MAX_RING` is cut, loudly. Red before this: a broken `user://bombs/*.json` printed only Godot's path-less "Parse JSON failed. Error at line 0", and an id-less row printed nothing. (1) the SHIPPED data loads with zero errors in every catalogue; (2) broken user-tier rows are each reported and the good rows survive.

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

extends `SceneTree` · 129 lines

`godot/scripts/tools/roof_bake_selftest.gd`

> ROOF-BAKE-01/02 — roof/ceiling baked-surface selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_bake_selftest.gd R3D-END END-4: the compositor and the baked lookup are gone, and with them criteria [1]-[3] (the roof page family, the resolved atoms, pixel continuity and isotropy of the placed atoms) and [4] (END-1). What survives is the data contract: 5. ROTATION (02a): building the E view puts a roof Slab of the right material at every block's ROTATED position The expectation is re-derived locally (own rotation math), never read back from the code under test.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_5_rotated_view_roofs_follow_structures() -> void:`

---

### `roof_entity_selftest.gd`

extends `SceneTree` · 146 lines

`godot/scripts/tools/roof_entity_selftest.gd`

> R3D-7 — the free-standing `roofs` entity, end to end on the real OCCLUSION_ROOM map: FileMapSource reads the section, MapCompiler forwards `roof_instances` offset by the board buffer, PerspectiveMapper rotates it (the ROOF-BAKE-02a lesson: without an explicit rotation the roof lands on the wrong GUs in the E/S/W views), and RoomBuilder turns it into two CEILING slabs per GU at the height it names, through the same code a block's roof uses, with NO walls beneath it.

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

---

### `roof_integration_selftest.gd`

extends `SceneTree` · 268 lines

`godot/scripts/tools/roof_integration_selftest.gd`

> DESTRUCTION D1-ROOF — real map roof integration selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_integration_selftest.gd Drives the REAL RoomBuilder.build_from_layout() against the REAL PLAYGROUND map (FileMapSource + MapCompiler, the exact path room.gd::load_map() uses) and confirms real roofs land above the real concrete/stone/wood/metal blocks it actually contains (maps/PLAYGROUND.map.json's "blocks" section).

**Constants / tuning**
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `RoomBuilderClass` = `preload("res://godot/scripts/world/builders/room_builder.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_real_playground_blocks_get_real_roofs() -> void:`

---

### `roof_occlusion_selftest.gd`

extends `SceneTree` · 204 lines

`godot/scripts/tools/roof_occlusion_selftest.gd`

> R3D-7 — the roof half of the occlusion set: a roof an origin stands UNDER opens by ADJACENCY of its slabs, the way a wall opens by adjacency of its edges (Director, 2026-09-20). Reach ROOF_REACH (6) slabs from the slab above the origin, the last ROOF_FADE (2) fading (rings 1 and 2); everything nearer is ring 0. Corner-touching slabs count as adjacent (square rings). A roof nobody stands under stays solid. Every fixture is real: Slabs from SlabGenerator in a SlabRegistry, handed to OcclusionSet.recompute() exactly as room.gd hands them (CEILING slabs only), and the assertions read the cells the set itself returns. RED-BEFORE-GREEN is built in: with the old stripe rule (reveal only within MAX_RING = 2 of the origin's x+y) the slab 3 away is NOT revealed, so test [1] fails; with reach 3 the slab 5 away is revealed and test [2] fails.

**Constants / tuning**
- `GeometryCoordsMod` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
- `OcclusionSetMod` = `preload("res://godot/scripts/systems/occlusion_set.gd")`

---

### `roof_slab_selftest.gd`

extends `SceneTree` · 308 lines

`godot/scripts/tools/roof_slab_selftest.gd`

> DESTRUCTION_MASTER_PLAN — roof/ceiling ("laje") geometry selftest. Rodar: godot --headless --script res://godot/scripts/tools/roof_slab_selftest.gd Proves the "2+ levels, ALL destructible, existing wall material" roof model this session's Director asked for: unlike the floor (1 destructible Slab + 7 fixed non-Slab levels, D13), a roof is N independent Slabs, one per level, each fully destructible — falls out of calling the EXISTING SlabGenerator N times, zero new geometry classes needed. No bake system involved yet (Director's call: geometry first, bake as a later experiment) — register_slab_solid() places one fixed wall material per voxel, the same way register_block_levels() already does for a whole block, just through Slab/Voxel so every level is independently dirty-tracked.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`
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

### `save_state_file_selftest.gd`

extends `SceneTree` · 36 lines

`godot/scripts/tools/save_state_file_selftest.gd`

> AUDIT 2026-10-07 — the checkpoint save is written through `SaveState.write_text_atomic()`: a sibling `.tmp` renamed over the old file, so a kill mid-write never leaves a truncated save (the checkpoint is the only state that survives the app being killed).

**Constants / tuning**
- `SaveStateClass` = `preload("res://godot/scripts/systems/save_state.gd")`
- `PATH` = `"user://selftest_save_state_file.json"`

---

### `save_state_selftest.gd`

extends `SceneTree` · 264 lines

`godot/scripts/tools/save_state_selftest.gd`

---

### `scenario_draw_selftest.gd`

extends `SceneTree` · 34 lines

`godot/scripts/tools/scenario_draw_selftest.gd`

> ScenarioDraw — waiting for a drawn frame always returns: in at most WAIT_FRAMES + a few process frames, whether or not the engine draws (the headless dummy renderer and an occluded window both draw nothing). A forced draw is announced by a warning, never silent.

**Constants / tuning**
- `ScenarioDrawClass` = `preload("res://godot/scripts/systems/scenario_draw.gd")`

---

### `scenario_selftest.gd`

extends `Node` · 142 lines

`godot/scripts/tools/scenario_selftest.gd`

> TEL-06a Test: the scenario format. ⚠️ RUNS AS A SCENE — `scenario_runner.gd` names the `Telemetry` autoload, which exists as a global only when a MAIN SCENE runs (see `dev_flags_selftest`). ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch also returns. WHAT THIS PINS: 1. A realistic zoom ladder parses into exactly the steps written, arguments typed (a zoom is a float, a GU is a Vector2i), newlines and a trailing `;` tolerated. 2. **One bad step rejects the whole scenario**, and the error names the step. The failure this prevents is quiet: a `zoom` that is skipped leaves every later window measuring the previous zoom under a mark naming a new one. 3. Each argument check refuses the input it exists for — not merely "some garbage" (assert identity, not absence). `run()` needs a Room, so it is exercised on the real path, not here.

**Constants / tuning**
- `ScenarioRunnerClass` = `preload("res://godot/scripts/systems/scenario_runner.gd")`

---

### `slab_geometry_selftest.gd`

extends `SceneTree` · 244 lines

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

extends `SceneTree` · 119 lines

`godot/scripts/tools/slab_render_selftest.gd`

> DESTRUCTION_MASTER_PLAN Part 2 — consumer wave selftest. Rodar: godot --headless --script res://godot/scripts/tools/slab_render_selftest.gd Proves SlabGenerator builds real Voxels and that the floor's two Slabs are independent containers. R3D-END: the three tests that read the TILE each voxel was placed as (the earth-variant hash round trip, the re-render idempotence, the carved floor-dent asset) went with the 2D board; the 3D board draws the store, not those tiles.

**Constants / tuning**
- `GeometryCoordsClass` = `preload("res://godot/scripts/geometry/geometry_coords.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_slab_generator_produces_64_voxels() -> void:`
- `func test_d13_two_layer_floor_independent_containers() -> void:`

---

### `slice_geometry_selftest.gd`

extends `SceneTree` · 210 lines

`godot/scripts/tools/slice_geometry_selftest.gd`

**Constants / tuning**
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `EdgeExtractorClass` = `preload("res://godot/scripts/geometry/edge_extractor.gd")`

---

### `soot_stamp_selftest.gd`

extends `SceneTree` · 218 lines

`godot/scripts/tools/soot_stamp_selftest.gd`

---

### `soot_truth_selftest.gd`

extends `Node` · 104 lines

`godot/scripts/tools/soot_truth_selftest.gd`

> SOOT-TRUTH — `Room._soot_map` is the one truth and the soot plane is its projection (2026-10-02). `board_probe.py roundtrip --with-store` found 3-7 soot texels after a SaveState restore on PLAYGROUND: the live plane and the restored plane (which projects the map) disagreed. Three writers had each broken the rule; this pins each: 1. A cell no voxel stands on takes no soot: a blast commits its destruction BEFORE it stamps, so its ember CHARRED rows on the voxels it burnt away used to land in the map and outlive them. 2. Erasing a destroyed voxel's entry clears the PLANE in the same step (it only erased the map before, so the old tone stayed on screen and a restore, which projects the map, then differed). 3. A cell another claim still stands on keeps its scorch (the cell is the soot's key; it is not orphaned). 4. `settle_soot()` gives every cell a blast stamped the map's tone, including one no wave carried, and is idempotent.

**Constants / tuning**
- `RoomScript` = `preload("res://godot/scripts/world/room.gd")`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `surface_rules_selftest.gd`

extends `SceneTree` · 48 lines

`godot/scripts/tools/surface_rules_selftest.gd`

> R3D-SURFACES tags — the closed vocabulary, the material tags and the patch rules (`res://surfaces/rules.json`), against the real material files and the art on disk: every tag a material declares is in the vocabulary, every patch kind that has art has a rule, and the rule says what the catalog says (no leaf in the desert, a leaf on grass, nothing for a kind with no rule).

**Constants / tuning**
- `SurfaceRulesClass` = `preload("res://godot/scripts/systems/surface_rules.gd")`
- `MaterialRegistryClass` = `preload("res://godot/scripts/systems/material_registry.gd")`

---

### `telemetry_selftest.gd`

extends `Node` · 173 lines

`godot/scripts/tools/telemetry_selftest.gd`

> TEL-01 Test: the Telemetry timeline. ⚠️ RUNS AS A SCENE, not as a `--script` SceneTree — `Telemetry`, `DevFlags` and `VersionInfo` are autoloads, which exist as globals only when a MAIN SCENE runs (see `dev_flags_selftest` for the same warning). `run_selftests.py` launches `telemetry_selftest.tscn` that way. ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch also returns. WHAT THIS PINS, and why each one is here rather than assumed: 1. Disarmed by default. A build without `TELEMETRY=1` must write nothing — otherwise every measurement ever taken without the flag carries its cost. 2. The logcat line's exact shape. `bench_analyze.py` (TEL-07) splits on spaces, so a value with a space in it, or a vector printed as `(3, 4)`, silently shifts every field after it. 3. The file sink round-trips: the session header comes first, `seq` has no gaps, the clock never runs backwards, and a vector arrives as an array. A gap in `seq` is how the analyzer counts DROPPED lines, so a sink that skips numbers on its own would report losses that never happened. 4. A channel filter drops what it should and never drops `session`. 5. Counters belong to one window: taking them resets them.

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

### `vent_emitter_selftest.gd`

extends `SceneTree` · 65 lines

`godot/scripts/tools/vent_emitter_selftest.gd`

> R3D-SURFACES SM-6 — `VentEmitter`: the timing is pure and deterministic, vents are out of phase, a hitch does not burst, a bad kind is refused, and the `ground_vents` section reaches the compiler on the real gallery map.

**Constants / tuning**
- `VentEmitterClass` = `preload("res://godot/scripts/overlays/vent_emitter.gd")`
- `FileMapSourceClass` = `preload("res://godot/scripts/world/maps/file_map_source.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`

---

### `version_info_selftest.gd`

extends `Node` · 74 lines

`godot/scripts/tools/version_info_selftest.gd`

> VERSION-01 Test: VersionInfo singleton initialization TEST-DEBT-03 (2026-09-01) — RUNS AS A SCENE, not as a `--script` SceneTree. `VersionInfo` is an autoload, and Godot registers autoload names as parse-time globals (and adds their nodes) only when a MAIN SCENE runs. Under `--script` this file did not merely fail its assertions, it failed to LOAD: "Compile Error: Identifier not found: VersionInfo" — so the one test of the version singleton had never run since the day it was written. Launched as `res://godot/scripts/tools/version_info_selftest.tscn` the autoload is real; run_selftests.py knows to invoke a `*_selftest.tscn` that way.

---

### `vox_model_selftest.gd`

extends `SceneTree` · 160 lines

`godot/scripts/tools/vox_model_selftest.gd`

> Selftest — VoxModel (the `.vox` parser) and VoxPropBuilder (scale, material, hollow, centre). Pure: bytes built in memory.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

---

### `voxel_decal_selftest.gd`

extends `SceneTree` · 247 lines

`godot/scripts/tools/voxel_decal_selftest.gd`

> DESTRUCTION_MASTER_PLAN D32 — damage-decal ART selftest. Rodar: godot --headless --script res://godot/scripts/tools/voxel_decal_selftest.gd What this suite exists to catch: a decal family, a variant or a generic mark missing from disk, or the generator's manifest drifting from the constants the board reads. Nothing fails loudly otherwise — a mark is silently dropped. R3D-END END-4: the criteria about WHICH NAME a (tier, cause, side) resolves to went with the 2D name resolver (`damage_variant_material()` and its plan parsers); the board picks a decal by (family, material, variant) and this suite keeps the asset side of that. Deliberately NOT asserted here: what the decal looks like. That is verified on the asset side (the generator's own geometry checks) and by real capture.

**Constants / tuning**
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `MANIFEST_PATH` = `"res://ASSETS/materials/manifest.json"`
- `DECAL_NAME_TEMPLATE` = `"res://ASSETS/materials/%s/decals/decal_%s_%s_%d.png"`
- `GENERIC_MARK_TEMPLATE` = `"res://ASSETS/materials/_generic/decals/decal_generic_%s_%d.png"`
- `GENERIC_MARK_VARIANT_COUNT` = `3`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_every_family_variant_has_an_asset() -> void:`
- `func test_manifest_agrees_with_the_renderer() -> void:`

---

### `voxel_handle_selftest.gd`

extends `SceneTree` · 249 lines

`godot/scripts/tools/voxel_handle_selftest.gd`

> R3D-CLAIMS C1 Test: a claim reached WITHOUT its persistent object. `VoxelStore.voxel_of(claim)` builds a transient `Voxel` from the store's own arrays. R3D-CLAIMS removes the ~296 000 persistent wrappers (~990 B each on the Moto), so everything that today holds one has to be able to ask for it again, and the new one has to be INTERCHANGEABLE with the old: same cell, level, container, state, and the same dirty bit. What this pins, against the persistent objects of a real fixture (a banded slice, a slice sharing a corner cell, slabs, a junction column): 1. EVERY claim: `voxel_of()` answers the persistent voxel's grid_pos, level, claim, container id and state, and `container_of()` is the container that holds it. 2. A write through a HANDLE is the persistent voxel's: damage, visibility, and the dirty bit (the container's `dirty_count` moves once), and a clear through the PERSISTENT voxel clears the handle's. 3. Two handles of one claim share their dirty bit (it used to be per wrapper: that was the bug-in-waiting). 4. A claimless voxel (a detached fixture) keeps its own dirty flag and never touches the store's bits. 5. Mutation control: the check of (1) FAILS when a handle is built for the wrong claim. 6. RELEASED containers (`VoxelStore.build(..., release_objects = true)`, C2): the persistent objects are gone, `voxel_at(i)` makes ONE handle per claim and keeps it, `voxels` converts the container back to full objects that REUSE the handles already made and match the cells the fixture was built with, `Stats` counts the conversion, and `clear_all_dirty()` clears the store's bits without making a handle. 7. CELLS (C4): the generators fill `add_cell()` and make NO object; the store reads the cells; reading `voxels` before the store turns the container into objects and `Stats.from_cells` counts it; after a store has bound it the objects carry `claim = offset + i`; a released container keeps its cells, so a SECOND store built over it answers the same cells.

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_every_claim_matches(store: VoxelStore) -> void:`
- `func test_write_through_handle(store: VoxelStore) -> void:`
- `func test_handles_share_dirty(store: VoxelStore) -> void:`
- `func test_claimless_voxel_keeps_its_own_flag(store: VoxelStore) -> void:`
- `func test_mutation_control(store: VoxelStore) -> void:`
- `func test_released_containers() -> void:`
- `func test_cells_mode() -> void:`

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

### `voxel_store_selftest.gd`

extends `SceneTree` · 428 lines

`godot/scripts/tools/voxel_store_selftest.gd`

> RENDER3D R3D-1b Test: the shadow `VoxelStore` holds what the objects hold. WHAT THIS PINS, each against `BoardProbe`'s own dump of the OBJECTS, so a check reads "the store says what the objects say" rather than "the store says what this test expects": 1. A built store dumps identically to the objects — a banded slice, slabs, a junction column, a cell two slices claim, and a slab whose voxels are out of box order (which must be found irregular and served by a table, not by the arithmetic). 2. A damage write through `Voxel.set_damage()` lands in the store: dumps identical, and the derived grid follows (destroyed → not occupied). 3. A cell two claims hold: destroying the first hands ownership to the second while the cell stays occupied; destroying both empties it. Grid rebuilt from the claims agrees at each step. 4. A write into the out-of-order slab lands on the right claim. 5. A write the store cannot place is COUNTED: a voxel of a container the store never saw. A container-less projection (`WorldDelta.project_voxel()`) is not a claim and is not counted. 7. The glass pane queries (R3D-14): `glass_pane_face_at()` answers from the claims what the hidden glass layer used to. A banded glass slice is a pane only on its glass levels, on the slice's face; a glass INTERIOR slab is a pane (face NW), a glass CEILING slab is not; a cell two glass claims hold answers for the LAST visible one, and for the other once that one is destroyed; a destroyed pane and a cell with no glass answer 0. 6. `occupancy_dict_after()`, the cook's predicted occupancy, works per CLAIM: a cell two claims hold stays occupied while one of them is gone and empties when both are, a cell one claim holds empties with it, and the store itself is not written (R3D-13: the per-cell predecessor emptied a box corner at the first claim destroyed, which put the cook's light 21 and 13 cells from a full relight on PLAYGROUND).

**Constants / tuning**
- `BoardProbeClass` = `preload("res://godot/scripts/systems/board_probe.gd")`
- `OUT_DIR` = `"user://voxel_store_selftest"`

**Public vars**
- `var passed: int = 0`
- `var failed: int = 0`

**Public API**
- `func test_build_matches_objects(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_write_mirrors(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_collision_ownership(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_irregular_write(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_unplaceable_writes_counted(store: VoxelStore) -> void:`
- `func test_occupancy_after(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_occupancy_live(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_gone_claims(fixture: Dictionary, store: VoxelStore) -> void:`
- `func test_glass_panes(fixture: Dictionary, store: VoxelStore) -> void:`

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

`class_name FogOfWarOverlay` · extends `Node2D` · 181 lines

`godot/scripts/ui/fog_of_war_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `TILE_HALF_W` = `128.0`
- `TILE_HALF_H` = `64.0`
- `FOG_COLOR` = `Color(0.04, 0.04, 0.09, 0.93)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public API**
- `func setup(visual_offset: Vector2, room_size: Vector2i) -> void:`
- `func reveal_around(center: Vector2i, radius: int) -> void:`
- `func reset_fog() -> void:`
- `func add_peek_reveal(cell: Vector2i) -> void:`
- `func reset_peek_reveals() -> void:`
- `func is_cell_revealed(cell: Vector2i) -> bool:`
- `func set_board3d(board: Node3D) -> void:`

---

### `main_menu_panel.gd`

`class_name MainMenuPanel` · extends `WindowBase` · 154 lines

`godot/scripts/ui/main_menu_panel.gd`

> PAUSE-MENU-01: First concrete menu built on WindowBase.

**Signals**
- `signal reset_requested`
- `signal settings_requested`
- `signal controls_requested`
- `signal showcase_requested`

**Constants / tuning**
- `SHORT_SCREEN_HEIGHT` = `560.0`

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

### `options_panel.gd`

`class_name OptionsPanel` · extends `WindowBase` · 154 lines

`godot/scripts/ui/options_panel.gd`

> OPTIONS-01 (Director, 2026-10-08): the Options window, opened from the Main Menu (Escape). Holds the player's choices that persist in `user://settings.cfg`: - Frame rate: 30 (default) / 60 / uncapped — `FrameRate` (no choice under 30, see its header). - Language: every `Localization.supported_locales` entry — `Localization.set_language()`, which also saves it. Built in code like `MainMenuPanel` and `ControlsPanel`; texts are rebuilt on a language change.

**Public API**
- `func open() -> void:`

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

extends `Node2D` · 59 lines

`godot/scripts/ui/selection_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `COLOR_PINK` = `Color(0.90, 0.10, 0.45, 1.0)`
- `LINE_W` = `4.0`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var visual_offset: Vector2 = Vector2.ZERO`

**Public API**
- `func set_selected(cell: Vector2i) -> void:`
- `func set_board3d(board: Node3D) -> void:`

---

### `showcase_panel.gd`

`class_name ShowcasePanel` · extends `WindowBase` · 221 lines

`godot/scripts/ui/showcase_panel.gd`

> ACTOR_MASTER_PLAN D20/Part 5a — Showcase screen. First concrete Part 5 (live 3D inspection window) application: a live SubViewport with a real Camera3D shows an imported mesh (D12's imported-mesh path, proven by shotgun_preview_spike.gd) filling most of the screen, auto-rotating slowly (D10's "auto-spin" option). Name/info sits in a separate area, laid out adaptively — a bottom strip in portrait (9:16), a side panel in landscape (16:9) — per D20. Breakpoint value and info content are both first-cut choices, not final (§7 open question #14). The object here (Shotgun Short Stock, D18's objects-track first case) is hardcoded for this first cut — no ShowcaseItem registry exists yet; that is exactly the kind of thing D19 says not to build before proving the mechanism works.

**Constants / tuning**
- `MODEL_PATH` = `"res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Shotgun Short Stock.glb"`
- `ELEVATION_DEG` = `30.0`
- `AZIMUTH_START_DEG` = `45.0`

---

### `tile_labels_overlay.gd`

extends `Node2D` · 63 lines

`godot/scripts/ui/tile_labels_overlay.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `FONT_SIZE` = `40`
- `COLOR_LABEL` = `Color(0.0, 0.0, 0.0, 1.0)`
- `COLOR_SHADOW` = `Color(1.0, 1.0, 1.0, 0.60)`
- `GroundCanvas3DRef` = `preload("res://godot/scripts/geometry/ground_canvas3d.gd")`

**Public vars**
- `var visual_offset: Vector2 = Vector2.ZERO`
- `var room_w: int = 0`
- `var room_h: int = 0`

**Public API**
- `func set_board3d(board: Node3D) -> void:`

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

`class_name RoomBuilder` · 534 lines

`godot/scripts/world/builders/room_builder.gd`

> RoomBuilder Orchestrates room construction, tile placement, and perspective transformations. Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

**Constants / tuning**
- `FloorOpeningsRef` = `preload("res://godot/scripts/geometry/floor_openings.gd")`

**Public vars**
- `var room: Node`
- `var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")`
- `var PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")`

**Public API**
- `func build_from_layout(layout: Dictionary, room_size: Vector2i) -> void:`
- `func get_blocked_cells() -> Dictionary:`
- `func get_exit_cells() -> Array[Vector2i]:`
- `func get_light_sources() -> Array:`
- `func build_navigation_blocked_cells(guards: Array) -> Array[Vector2i]:`

---

### `agent_shot_controller.gd`

`class_name AgentShotController` · 1201 lines

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

`class_name DebugToolsController` · 151 lines

`godot/scripts/world/controllers/debug_tools_controller.gd`

> DEBUG-02: Debug tools controller — handles F2/F3/F4 debug toggles and voxel nudging. Extracted from room.gd (Task 03 modularization). Signals room on mode changes; room holds references to debug overlays and toggles.

**Public vars**
- `var room: Node`

**Public API**
- `func toggle_map_loader_panel() -> void:`
- `func create_map_loader_button() -> void:`
- `func create_grenade_button() -> void:`
- `func attach_board3d(live: Node3D) -> void:`
- `func toggle_voxel_ruler_overlay() -> void:`
- `func toggle_nudge_mode() -> void:`
- `func apply_nudge(delta: Vector2) -> void:`
- `func reset_nudge() -> void:`
- `func try_change_posture(new_posture: DebugAgent.Posture) -> void:`
- `func is_nudge_mode_active() -> bool:`

---

### `input_controller.gd`

`class_name InputController` · 218 lines

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

`class_name TestZoneController` · 1793 lines

`godot/scripts/world/controllers/test_zone_controller.gd`

> TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click "Detonar" on a test prop. ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a "digital twin" (Quaternius' CC0 "Grenade" model, poly.pizza) rendered via the real-3D-model + normal-map bake technique proven for the shotgun (godot/scripts/tools/grenade_frame_bake_spike.gd, 2026-07-28) — displayed via GrenadeProp (godot/scripts/overlays/grenade_prop.gd), NOT live TileMapLayer voxel cells. Superseded the original single-angle bake_voxel_sprite_3d.gd bake (grenade_bake_x8.png, a hand-placed BoxMesh voxel reconstruction of a CC0 .qb — itself already a v2 over a hand-rolled 2D painter's-algorithm rasterizer, v1) once that was shown to read flat from some angles and to ignore the room's active N/E/S/W perspective entirely, the same class of bug D22 found and fixed for the shotgun. Proves the mechanism ACTOR_MASTER_PLAN D1/D2 describes for one object before Parts 0-2 of that plan get built for real. Registry stays a plain Array[Dictionary] on purpose — scaffolding for the PLAYGROUND rebuild, not a permanent prop-interaction architecture. Delegates to room for shared state, same extraction pattern as SelectionController.

**Constants / tuning**
- `BlastCalculatorClass` = `preload("res://godot/scripts/systems/destruction/blast_calculator.gd")`
- `GrenadePropClass` = `preload("res://godot/scripts/overlays/grenade_prop.gd")`
- `DetonationPlanBuilderClass` = `preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")`
- `DetonationPresenterClass` = `preload("res://godot/scripts/systems/destruction/detonation_presenter.gd")`
- `DEFAULT_TARGET_OFFSET` = `Vector2i(3, 0)`

**Public vars**
- `var room: Node`
- `var throw_range_gu: float = 7.0`
- `var throw_range_penalty_gu: Dictionary = { DebugAgent.Posture.STANDING: 0.0, DebugAgent.Posture.CROUCHING: 2.0, DebugAgent.Posture.PRONE: 4.0, }`
- `var throw_range_skill_bonus_gu: float = 0.0`
- `var aim_dome_radius_gu: float = 2.0`
- `var throw_duration_s: float = 0.6`
- `var grenade_cook_s: float = 1.0`
- `var prepare_budget_us: int = 6000`
- `var throw_prediction_timeout_s: float = 1.0`

**Public API**
- `func is_targeting() -> bool:`
- `func effective_throw_range_gu() -> float:`

---

### `turn_controller.gd`

`class_name TurnController` · 379 lines

`godot/scripts/world/controllers/turn_controller.gd`

> TurnController Orchestrates turn phases, enemy AI execution, and alert meter management. Handles tactical state updates, detection/alert accumulation, and camera control.

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
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
- `var VISUAL_GRID_OFFSET: Vector2 = Vector2.ZERO`
- `var FOW_REVEAL_RADIUS: int = 0`
- `var vision_bonus_tiles: int = 0`

**Public API**
- `func setup( p_turn_manager: TacticalTurnManager, p_enemy_phase_controller: EnemyPhaseController, p_agent: DebugAgent, p_camera: Camera2D, p_fow_controller: Object, p_hud_controller: Object, p_vision_controller: Object, p_guard_coordinator: Object, p_noise_system: Object, p_noise_overlay: Object ) -> void:`
- `func set_constants( p_visual_grid_offset: Vector2, p_fow_radius: int, p_vision_bonus: int, p_alert_max: int, p_alert_gain: int ) -> void:`
- `func set_game_state( p_guards: Array, p_blocked_cells: Dictionary, p_current_blocked_edges: Array[Dictionary], p_room_size: Vector2i ) -> void:`
- `func get_alert_meter() -> int:`

---

### `world_markers_overlay_controller.gd`

`class_name WorldMarkersOverlayController` · 164 lines

`godot/scripts/world/controllers/world_markers_overlay_controller.gd`

> WorldMarkersOverlayController Manages shadow spill cosmetics and marker overlays (shadow boundary, light rays). Shadow spill is a cosmetic halo that bleeds from full-shadow tiles onto neighbours. Purely visual — never feeds gameplay (ExposureSystem reads raw geometry).

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `SHADOW_SPILL_RADIUS` = `2`
- `SHADOW_SPILL_MAX_RADIUS` = `4`
- `SHADOW_SPILL_DENSITY_STEP` = `2`
- `SHADOW_SPILL_BASE_DARKEN` = `0.18`
- `SHADOW_SPILL_FALLOFF` = `0.5`
- `SHADOW_SPILL_DIAGONAL_FACTOR` = `0.65`
- `PENUMBRA_MULT` = `0.5`

**Public vars**
- `var room: Node`

**Public API**
- `func setup(tile_shadow: Node2D, lighting_controller: Node, shadow_boundary: Node, light_ray: Node, vision_controller: Node, visual_offset: Vector2, room_size: Vector2i, shadow_tiles: Dictionary) -> void:`
- `func repaint_world_shadows() -> void:`
- `func draw_shadow_debug(canvas: Object = null) -> void:`

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

`class_name FileMapSource` · extends `RefCounted` · 201 lines

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

`class_name MapCatalog` · extends `RefCounted` · 48 lines

`godot/scripts/world/maps/map_catalog.gd`

**Constants / tuning**
- `PlaygroundMapClass` = `preload("res://godot/scripts/world/maps/definitions/playground_map.gd")`
- `Sigma01MapClass` = `preload("res://godot/scripts/world/maps/definitions/sigma_01_map.gd")`
- `ProceduralMapClass` = `preload("res://godot/scripts/world/maps/definitions/procedural_map.gd")`

---

### `map_compiler.gd`

`class_name MapCompiler` · extends `RefCounted` · 562 lines

`godot/scripts/world/maps/map_compiler.gd`

**Constants / tuning**
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `MapGeometryClass` = `preload("res://godot/scripts/world/maps/map_geometry.gd")`
- `FloorOpeningsRef` = `preload("res://godot/scripts/geometry/floor_openings.gd")`
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

`class_name MapSectionsV1` · extends `RefCounted` · 362 lines

`godot/scripts/world/maps/persistence/map_sections_v1.gd`

> MapSectionsV1 — Registration of board, walls, blocks, props, actors sections (v1)

---

### `room.gd`

extends `Node2D` · 11334 lines

`godot/scripts/world/room.gd`

**Constants / tuning**
- `GroundGridRef` = `preload("res://godot/scripts/geometry/ground_grid.gd")`
- `ScenarioDrawRef` = `preload("res://godot/scripts/systems/scenario_draw.gd")`
- `MapCatalogClass` = `preload("res://godot/scripts/world/maps/map_catalog.gd")`
- `GroundDecals3DRef` = `preload("res://godot/scripts/geometry/ground_decals3d.gd")`
- `SurfaceRulesRef` = `preload("res://godot/scripts/systems/surface_rules.gd")`
- `VentEmitterRef` = `preload("res://godot/scripts/overlays/vent_emitter.gd")`
- `GroundScatterRef` = `preload("res://godot/scripts/geometry/ground_scatter.gd")`
- `GroundTransitions3DRef` = `preload("res://godot/scripts/geometry/ground_transitions3d.gd")`
- `GlassShardShapes` = `preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")`
- `GlassRainOverlay` = `preload("res://godot/scripts/overlays/glass_rain_overlay.gd")`
- `MapCompilerClass` = `preload("res://godot/scripts/world/maps/map_compiler.gd")`
- `LevelGraphClass` = `preload("res://godot/scripts/world/level_graph.gd")`
- `GuardEnemyClass` = `preload("res://godot/scripts/agents/guard_enemy.gd")`
- `CeilingPropOverlayClass` = `preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")`
- `TileOverlayClass` = `preload("res://godot/scripts/overlays/tile_overlay.gd")`
- `DebugToolsControllerClass` = `preload("res://godot/scripts/world/controllers/debug_tools_controller.gd")`
- `InputControllerClass` = `preload("res://godot/scripts/world/controllers/input_controller.gd")`
- `PerspectiveMapperClass` = `preload("res://godot/scripts/world/utilities/perspective_mapper.gd")`
- `GlassOpening` = `preload("res://godot/scripts/systems/destruction/glass_opening.gd")`
- `SelectionControllerClass` = `preload("res://godot/scripts/world/controllers/selection_controller.gd")`
- `TestZoneControllerClass` = `preload("res://godot/scripts/world/controllers/test_zone_controller.gd")`
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
- `ViewContextClass` = `preload("res://godot/scripts/systems/view_context.gd")`
- `ScenarioRunnerClass` = `preload("res://godot/scripts/systems/scenario_runner.gd")`
- `Board3DLiveClass` = `preload("res://godot/scripts/geometry/board3d_live.gd")`
- `ActorMesh3DClass` = `preload("res://godot/scripts/geometry/actor_mesh3d.gd")`
- `VisionCone3DClass` = `preload("res://godot/scripts/geometry/vision_cone3d.gd")`
- `BoardProbeClass` = `preload("res://godot/scripts/systems/board_probe.gd")`
- `WorldRenderScaleClass` = `preload("res://godot/scripts/systems/world_render_scale.gd")`
- `TargetCursorOverlayClass` = `preload("res://godot/scripts/overlays/target_cursor_overlay.gd")`
- `EmberOverlayClass` = `preload("res://godot/scripts/overlays/ember_overlay.gd")`
- `SmokeSparkOverlayClass` = `preload("res://godot/scripts/overlays/smoke_spark_overlay.gd")`
- `DebrisOverlayClass` = `preload("res://godot/scripts/overlays/debris_overlay.gd")`
- `ExplosionFlashOverlayClass` = `preload("res://godot/scripts/overlays/explosion_flash_overlay.gd")`
- `VisionControllerClass` = `preload("res://godot/scripts/controllers/vision_controller.gd")`
- `HudControllerClass` = `preload("res://godot/scripts/controllers/hud_controller.gd")`
- `LightingControllerClass` = `preload("res://godot/scripts/controllers/lighting_controller.gd")`
- `CameraControllerClass` = `preload("res://godot/scripts/controllers/camera_controller.gd")`
- `FowControllerClass` = `preload("res://godot/scripts/controllers/fow_controller.gd")`
- `GuardCoordinatorClass` = `preload("res://godot/scripts/controllers/guard_coordinator.gd")`
- `DevVisionStatusPanelClass` = `preload("res://godot/scripts/debug/dev_vision_status_panel.gd")`
- `GuGridOverlayClass` = `preload("res://godot/scripts/overlays/gu_grid_overlay.gd")`
- `BlastWireframeOverlayClass` = `preload("res://godot/scripts/overlays/blast_wireframe_overlay.gd")`
- `VoxelBoardClass` = `preload("res://godot/scripts/geometry/voxel_board.gd")`
- `OcclusionSetClass` = `preload("res://godot/scripts/systems/occlusion_set.gd")`
- `OcclusionOverlayClass` = `preload("res://godot/scripts/overlays/occlusion_overlay.gd")`
- `INVALID_CELL` = `Vector2i(-9999, -9999)`
- `VISUAL_GRID_OFFSET` = `Vector2(0.0, 512.0)`
- `WALL_BASE_Z_INDEX` = `10`
- `WALL_FLOOR_STEP_PX` = `158.0`
- `VOXEL_STEP_PX` = `20.0`
- `GROUND_SCATTER_LAYER_BUDGET` = `1.5`

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

`class_name PerspectiveMapper` · 320 lines

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
