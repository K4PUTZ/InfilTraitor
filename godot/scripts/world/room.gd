extends Node2D
## Tactical room controller: input, UI wiring, agent turns and scene setup.

const MapCatalogClass    = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass   = preload("res://godot/scripts/world/maps/map_compiler.gd")
const LevelGraphClass    = preload("res://godot/scripts/world/level_graph.gd")
const GuardEnemyClass    = preload("res://godot/scripts/agents/guard_enemy.gd")
const GuardNoiseIndicatorClass = preload("res://godot/scripts/overlays/guard_noise_indicator.gd")
const CeilingPropOverlayClass = preload("res://godot/scripts/overlays/ceiling_prop_overlay.gd")
const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")
const DebugToolsControllerClass = preload("res://godot/scripts/world/controllers/debug_tools_controller.gd")
const InputControllerClass = preload("res://godot/scripts/world/controllers/input_controller.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const SelectionControllerClass = preload("res://godot/scripts/world/controllers/selection_controller.gd")
const TestZoneControllerClass = preload("res://godot/scripts/world/controllers/test_zone_controller.gd")
const WeaponBenchControllerClass = preload("res://godot/scripts/world/controllers/weapon_bench_controller.gd")
## WEAPON_MASTER_PLAN §6c — the agent shoots. Separate from the bench controller
## above, which fires from a static prop; see agent_shot_controller.gd's header.
const AgentShotControllerClass = preload("res://godot/scripts/world/controllers/agent_shot_controller.gd")
const DetonateContextMenuClass = preload("res://godot/scripts/ui/detonate_context_menu.gd")
const ModalStackClass = preload("res://godot/scripts/ui/modal_stack.gd")
const WorldMarkersOverlayControllerClass = preload("res://godot/scripts/world/controllers/world_markers_overlay_controller.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const TurnControllerClass = preload("res://godot/scripts/world/controllers/turn_controller.gd")
const ShadowBoundaryOverlayClass = preload("res://godot/scripts/overlays/shadow_boundary_overlay.gd")
const LightRayOverlayClass = preload("res://godot/scripts/overlays/light_ray_overlay.gd")
const ShrapnelOverlayClass = preload("res://godot/scripts/overlays/shrapnel_overlay.gd")
const AimBubbleOverlayClass = preload("res://godot/scripts/overlays/aim_bubble_overlay.gd")
const ThrowPerimeterOverlayClass = preload("res://godot/scripts/overlays/throw_perimeter_overlay.gd")
const ThrowArcOverlayClass = preload("res://godot/scripts/overlays/throw_arc_overlay.gd")
const ShrapnelPreviewOverlayClass = preload("res://godot/scripts/overlays/shrapnel_preview_overlay.gd")
const TargetCursorOverlayClass = preload("res://godot/scripts/overlays/target_cursor_overlay.gd")
const EmberOverlayClass = preload("res://godot/scripts/overlays/ember_overlay.gd")
const SmokeSparkOverlayClass = preload("res://godot/scripts/overlays/smoke_spark_overlay.gd")
const DebrisOverlayClass = preload("res://godot/scripts/overlays/debris_overlay.gd")
const ExplosionFlashOverlayClass = preload("res://godot/scripts/overlays/explosion_flash_overlay.gd")
const TileSemanticsClass = preload("res://godot/scripts/world/tile_semantics.gd")
const VisionControllerClass = preload("res://godot/scripts/controllers/vision_controller.gd")
const HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
const LightingControllerClass = preload("res://godot/scripts/controllers/lighting_controller.gd")
const CameraControllerClass = preload("res://godot/scripts/controllers/camera_controller.gd")
const FowControllerClass = preload("res://godot/scripts/controllers/fow_controller.gd")
const GuardCoordinatorClass = preload("res://godot/scripts/controllers/guard_coordinator.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const DevVisionStatusPanelClass = preload("res://godot/scripts/debug/dev_vision_status_panel.gd")
const GuGridOverlayClass = preload("res://godot/scripts/overlays/gu_grid_overlay.gd")
const BlastWireframeOverlayClass = preload("res://godot/scripts/overlays/blast_wireframe_overlay.gd")

## SLICE-02: Geometry module (Edge → Slice → Voxel pipeline)
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
const SliceGeneratorClass = preload("res://godot/scripts/geometry/slice_generator.gd")
const JunctionResolverClass = preload("res://godot/scripts/geometry/junction_resolver.gd")
const EdgeRegistryClass = preload("res://godot/scripts/geometry/edge_registry.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

## OCC-01: Occlusion system (geometry occlusion set, view-space computation)
const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const OcclusionOverlayClass = preload("res://godot/scripts/overlays/occlusion_overlay.gd")
const OcclusionWireframeOverlayClass = preload("res://godot/scripts/overlays/occlusion_wireframe_overlay.gd")

@onready var floor_layer:         TileMapLayer = $FloorLayer
@onready var turn_manager:        TacticalTurnManager = $TurnManager
@onready var enemy_phase_controller: EnemyPhaseController = $EnemyPhaseController
@onready var enemies_root:         Node2D       = $Enemies
@onready var movement_overlay:    MovementOverlay = $MovementOverlay
@onready var path_preview:        PathPreview  = $PathPreview
@onready var structure_layer:            TileMapLayer = $StructureLayer
@onready var shadow_full_layer:    TileMapLayer = $ShadowFullLayer
@onready var shadow_partial_layer: TileMapLayer = $ShadowPartialLayer
@onready var selection_overlay:   Node2D       = $SelectionOverlay
@onready var agent:               DebugAgent   = $Agent
@onready var tile_labels_overlay: Node2D       = $TileLabelsOverlay
@onready var camera:              Camera2D     = $Camera2D
@onready var btn_numbers:         Button       = $HUD/TopBar/Row/BtnNumbers
@onready var btn_fullscreen:      Button       = $HUD/TopBar/Row/BtnFullscreen
@onready var btn_viewport:        Button       = $HUD/TopBar/Row/BtnViewport
@onready var btn_reset:           Button       = $HUD/TopBar/Row/BtnReset
@onready var toolbar_row:         HBoxContainer = $HUD/TopBar/Row
@onready var perspective_pad:     PanelContainer = $HUD/PerspectivePad
@onready var btn_perspective_nw:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveNW
@onready var btn_perspective_ne:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveNE
@onready var btn_perspective_sw:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveSW
@onready var btn_perspective_se:  Button       = $HUD/PerspectivePad/Grid/BtnPerspectiveSE
@onready var btn_view_h:          Button       = $HUD/TopBar/Row/BtnViewH
@onready var btn_view_l:          Button       = $HUD/TopBar/Row/BtnViewL
@onready var btn_view_v:          Button       = $HUD/TopBar/Row/BtnViewV
@onready var lbl_ap:              Label        = $HUD/TopBar/Row/LblAp
@onready var chk_auto_end_turn:   CheckBox        = $HUD/TopBar/Row/BtnEndTurn/Content/ChkAutoEndTurn
@onready var btn_end_turn:        Button          = $HUD/TopBar/Row/BtnEndTurn
@onready var lbl_alert:           Label           = $HUD/TopBar/Row/LblAlert
@onready var busted_dialog:       Label           = $HUD/BustedDialog
@onready var enemy_turn_banner:   Control         = $HUD/EnemyTurnBanner
@onready var lbl_end_turn:        Label           = $HUD/TopBar/Row/BtnEndTurn/Content/LblEndTurn
@onready var lbl_enemy_turn:      Label           = $HUD/EnemyTurnBanner/LblEnemyTurn
@onready var fog_of_war:          Node2D          = $FogOfWarOverlay
@onready var _fog_rect:           ColorRect       = $VisionFogOverlay/FogRect

const TILESET_PATH := "res://godot/resources/tilesets/tileset_blocks.tres"
const INVALID_CELL := Vector2i(-9999, -9999)

## The TileMap renders the current 512px-tall source tiles lower than the
## logical grid used by map_to_local/local_to_map. Compensate with one fixed
## visual offset so camera, labels, selection and picking all agree.
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)

## Wall storeys (N-floor stacking). Walls are VOXELS, not sprites: VoxelRenderer creates one
## TileMapLayer per voxel level, z_index = WALL_BASE_Z_INDEX + level. WALL_FLOOR_STEP_PX is the
## per-storey height in px. Reserve z=100 band for a future overhead ceiling/light layer
## (below noise at z=140).
##
## The old sprite path (StructureWallLayer + runtime _wall_upper_layers) was deleted on
## 2026-07-12: the layers were created, cleared and then hidden on every build, and nothing
## was ever placed into them. Do not recreate them — see docs/technical/ASSET_MAP.md.
const WALL_BASE_Z_INDEX := 10
## One storey = the cube's side-face height. Measured from the art: opaque block height 286 −
## top-diamond 128 = 158 px (block_SE and wall_NE — sistema vértice-alinhado).
## Upper courses stack on this step so a cube seats exactly on the one below. Tunable.
const WALL_FLOOR_STEP_PX := 158.0
var _wall_tileset: TileSet = null

## Voxel render plane (VOXEL series): 1 storey = 8 voxel rows, each steps 20 px.
## 20 = 1.25 × VOXEL_TILE_SIZE.y (16). Must match generate_voxel.py SIDE_H.
## Invariant: storey height (160 px) consistency across voxel stack rendering. ✓
const VOXEL_STEP_PX: float = 20.0


## SLICE-02: New geometry module state
var _edge_registry: EdgeRegistry = null       ## EdgeRegistry of all edges and slices
## DESTRUCTION_MASTER_PLAN D1/Part 1: SlabRegistry, the horizontal-plane sibling of
## _edge_registry. Published from room_builder.gd the same way and for the same
## reason (see the comment on that assignment) — empty until Part 2 gives it a
## producer, never null, so _tic_slab_system() always has a real registry to skip.
var _slab_registry: SlabRegistry = null
## Written from room_builder.gd (`room._junction_columns = junction_columns`), not from
## this file. It looks unused to a grep confined to room.gd — it is not. Deleting it makes
## that external write a runtime error that aborts build_from_layout() before render(),
## and the game boots with no walls. This cost a full session on 2026-07-12. Do not
## "clean it up"; see _assert_geometry_rendered().
##
## The @warning_ignore below is load-bearing: Godot's own linter reports this as
## UNUSED_PRIVATE_CLASS_VARIABLE, because it cannot see the cross-file write either. That
## false warning is what invited the delete in the first place. Silencing it here is the
## fix for the *cause*, not cosmetics.
@warning_ignore("unused_private_class_variable")
var _junction_columns: Array = []             ## Array of JunctionResolver.JunctionColumn
var _voxel_renderer: VoxelRenderer = null     ## Voxel rendering engine

## Prop stacking (e.g. stacked crates). Each extra sprite seats on the one below,
## offset up by the crate body step. Must equal the crate sprite's CUBE_HEIGHT
## (tools/asset_generation/generate_*_crate.py) so stacked crates seat seamlessly.
var CRATE_STACK_STEP_PX: float = 128.0

## tile_name → TileSet source_id
var _room_size: Vector2i = Vector2i.ZERO
var _map_buffer: int = 0   ## Buffer offset from MapCompiler (SLICE-00)
var _blocked_cells: Dictionary = {}
var _prop_heights: Dictionary = {}  ## rotated cell → prop shadow height class (1-4)
var _base_layout: Dictionary = {}
var _current_blocked_edges: Array[Dictionary] = []
## edge_key (WallEdgeData) -> {"start_storey": int, "storey_count": int}, in
## GU (1 storey == 1 GU, GeometryCoords.LEVELS_PER_STOREY == VOXELS_PER_UNIT_AXIS
## == 8). Populated by RoomBuilder from EdgeExtractor's own edges — the same
## per-edge height range SliceGenerator turns into voxels, retained here
## because nothing else needed it at runtime before AimBubbleOverlay's E-BUBBLE
## §6.2 wall-sectioned grid. Unlike `_current_blocked_edges` this carries real
## HEIGHT, not just a movement/LOS boolean. NOT CURRENTLY CONSUMED: the first
## grid version that read this (a ray-clamp against each wall's plane) was
## rejected by the Director 2026-08-11 as the wrong distortion shape ("mais
## angulosa" — more angular — was asked for, needs a refined spec) and pulled
## back out of AimBubbleOverlay. Left populated because it's cheap, tested,
## and correct on its own — re-deriving it later would be pure waste.
var _wall_height_edges: Dictionary = {}
var _guards: Array = []

var _shadow_tiles: Dictionary = {}     ## Vector2i → float (multiplicador)
var _exit_cells: Array[Vector2i] = []  ## Segment exit tiles (doorOpen_*)
var _current_light_sources: Array = []  ## Active (rotated) map lights for LightingController
## VL-01: per-voxel light buckets, rebuilt on every lighting_rebuilt. Kept as a
## member (not a local) because it is the query seam future vision modes
## (thermal / night / X-ray) consume — see VOXEL_LIGHT_MASTER_PLAN.
var _voxel_light_field: VoxelLightField = null
## VL-D2: soot on the revealed CRATER FLOOR (level → {cell: ring}). Separate from
## the Voxel-borne soot because the revealed level has no Voxel objects
## (render_fixed_earth_level places cells directly). Cleared on map load.
var _crater_floor_soot: Dictionary = {}

## VL-PERSIST: authoritative destruction state in BASE (N-frame) voxel coords, so
## it survives a perspective rotation (which rebuilds every Voxel from the
## MapSpec, dropping damage_state). Keyed Vector3i(base_vx, base_vy,
## level). Recorded on detonate (view→base), re-applied after each rotation
## rebuild (base→view). Cleared on map load. See VOXEL_LIGHT_MASTER_PLAN
## VL-PERSIST — this is also the shared prerequisite for the deferred 4-view
## prebuild (which would apply this same registry to all 4 copies).
## D24 (2026-07-30): soot has no base-coord counterpart any more — it derives
## fresh every repaint from whichever voxels damage_state already marks
## destroyed, so persisting it separately would just be a second copy of the
## same fact.
## D23/D25 (2026-07-31): the value is no longer a bare damage_state. A blast
## mark also has to remember that it CAME from a blast, and which side of the
## voxel the blast ate — neither of which survived a rotation before, because
## only damage_state was stored and set_damage()'s other arguments fell back to
## their defaults on reapply. That silently reverted every blast mark to the
## BULLET texture family on the first perspective flip.
## Packed as Array[int]: [damage_state, is_blast, dir_x, dir_y, dir_z, variant,
## substrate], where dir is the BASE-space unit direction pointing at the blast
## (Vector3i.ZERO = unknown). Base-space is the whole point: LEFT/RIGHT are
## screen-relative, so the carved side has to be re-derived per view — see
## _carved_side_from_base(). D32 appended `variant` (which of the three authored
## decals this mark uses) for exactly the reason is_blast was appended at D25: a
## value that is not persisted falls back to its default on reapply, so every
## mark would silently snap to variant 0 on the first rotation. Records written
## before D32 are 5 long and read back as variant 0. D3/§3.3
## (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) appended `substrate` for the
## identical reason — records written before this are 6 long or shorter and
## read back as substrate 0.
var _base_damage: Dictionary = {}   ## base voxel key → Array[int] record (see above)

## D2 (EXPLOSION_REBUILD_MASTER_PLAN §4.4, Task 5/E-WAVE, 2026-08-07) — how
## many times a GU has been detonated on, base-coord keyed (Vector2i) for the
## identical reason `_base_damage` is: it must survive a perspective rotation,
## which rebuilds every Voxel from the MapSpec but never re-derives how many
## blasts a spot has already taken. First blast on a GU: `apply_crater_damage()`
## only cedes `FLOOR_TOP_LEVEL`. Second and later: `deep_layer_unlocked` flips
## true for that GU's `DetonationPlanBuilder.build_plan()` call, and
## `FLOOR_DEEP_LEVEL` becomes a candidate too. Cleared on map load, same as
## `_base_damage`.
var _gu_blast_count: Dictionary = {}

## PREDICTION_MASTER_PLAN §5.2 (P-CACHE, 2026-08-09) — a monotonic counter the
## prediction cache keys against. Every COMMITTED mutation bumps it, and a bump
## drops the whole cache: a Delta computed against revision N is only valid
## against revision N, because a blast's outcome depends on prior damage state
## (§2.4, `set_damage()`'s read-once rule).
##
## Deliberately blunt — one counter for the whole world, not a dependency graph.
## §5.2 argues the case: a precise graph is a second system to get wrong, and the
## common case (nothing changes while the player picks a target) is served
## perfectly by the blunt version.
##
## Bumped from four places today, which is §2.4's list minus the ones that cannot
## happen yet: a committed detonation, a firearm impact, a map load, and a
## perspective change.
var _world_revision: int = 0

## The one cache. Lives on the room because the room IS the world the revision
## counts — a cache held anywhere else would need a way to learn that the world
## moved, which is exactly the coupling the revision exists to avoid.
var _prediction_cache: PredictionCache = PredictionCache.new()


## Invalidates every cached prediction. Call AFTER the mutation lands, never
## before: a prediction started in between would be filed under the old
## revision and immediately be wrong.
func bump_world_revision() -> void:
	_world_revision += 1
	_prediction_cache.invalidate()

## VL-D3: floor columns (Vector2i x,y) that had a wall/block/roof above them in
## the INTACT layout. Recomputed each build from the freshly rendered geometry
## (before reapply_damage), so it survives detonation and rotation on its own —
## a floor voxel here reads darker once exposed (it never saw the sun). Not
## base-coord: it's derived from the current view's geometry, which is rebuilt
## intact every rotation, so recomputing per build is correct and self-consistent.
var _under_structure: Dictionary = {}


## Voxel-grid size of the base (N-frame) layout — GU size × 8. The perspective
## rotation of a voxel coordinate is the SAME 90° rotation as a GU cell, at 8×
## the resolution (the 8×8 quadrant inside a GU rotates coherently with the GU),
## so PerspectiveMapper.cell_to_base/from_base work directly at this size.
func _base_voxel_size() -> Vector2i:
	return _base_layout.get("size", Vector2i.ZERO) * GeometryCoords.VOXELS_PER_UNIT_AXIS


## VL-PERSIST — record one voxel's destruction state in base coords. grid_pos is
## in the CURRENT view; convert to base so it re-applies correctly under any
## later rotation. damage_state 0 means "nothing to persist". D24: no soot
## parameter any more — soot derives fresh from damage_state at repaint time,
## see BlastCalculator.derive_soot_rings().
## D23/D25: is_blast and carved_side ride along now — see _base_damage's doc for
## why storing damage_state alone silently downgraded every blast mark to a
## bullet mark on the first rotation. carved_side is VIEW-space
## (Voxel.CarvedSide); it is converted to a base-space direction here and back
## to whatever the carved side is under the NEW view on reapply.
func record_voxel_damage_to_base(grid_pos: Vector2i, level: int, damage_state: int,
		is_blast: bool = false, carved_side: int = Voxel.CarvedSide.NONE,
		variant: int = 0, substrate: int = 0) -> void:
	if damage_state <= 0:
		return
	var base_xy := PerspectiveMapperClass.cell_to_base(grid_pos, _active_perspective, _base_voxel_size())
	var key := Vector3i(base_xy.x, base_xy.y, level)
	var dir := _carved_side_to_base_dir(grid_pos, carved_side)
	_base_damage[key] = [damage_state, 1 if is_blast else 0, dir.x, dir.y, dir.z, variant, substrate]


## D25 — VIEW-space Voxel.CarvedSide → BASE-space unit direction pointing at the
## blast. TOP/BOTTOM are vertical and so rotation-invariant; LEFT/RIGHT are the
## screen-space read of the two front-facing horizontal edges (SW and SE, whose
## grid deltas are (0,+1) and (+1,0)), and those DO rotate, so they go through
## the same PerspectiveMapper the cells themselves use. Taking the difference of
## two rotated points keeps that conversion honest — the affine offsets cancel,
## so there is no second rotation formula here to drift out of sync with the one
## in PerspectiveMapper.
func _carved_side_to_base_dir(grid_pos: Vector2i, carved_side: int) -> Vector3i:
	return BlastCalculator.carved_side_to_base_dir(grid_pos, carved_side, _active_perspective, _base_voxel_size())


## D25 — the inverse of the above, for the perspective the room is in NOW.
## Horizontal directions are re-projected to screen space and classified by the
## sign of their screen-x ((x − y) under this isometric projection), the same
## test BlastCalculator.carved_side_for() applies at detonation time.
func _carved_side_from_base(base_xy: Vector2i, dir: Vector3i) -> int:
	return BlastCalculator.carved_side_from_base(base_xy, dir, _active_perspective, _base_voxel_size())


## VL-PERSIST — re-apply the base-coord destruction registry to the freshly
## rebuilt geometry after a perspective rotation. build_from_layout() rebuilt
## every Voxel intact from the MapSpec; this stamps the recorded damage back
## on, converting each base key to the current view. Must run after the build
## (registries fresh) and before the light-field repaint (so it sees the holes
## that _build_soot_snapshot() needs to derive soot from).
func _reapply_base_damage() -> void:
	if _base_damage.is_empty():
		return
	if _edge_registry == null or _slab_registry == null:
		return
	var base_size_vox := _base_voxel_size()

	## Index this view's voxels by (grid_pos, level) — the same shape the soot
	## snapshot builds, cheap next to the rebuild it follows.
	var index: Dictionary = {}
	for slice in _edge_registry.all_slices():
		for v in slice.voxels:
			index[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = v
	for slab in _slab_registry.all_slabs():
		for v in slab.voxels:
			index[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = v

	_crater_floor_soot.clear()   ## rebuilt below for this view's coords
	## FLOOR-DEPTH-01: two reveal buckets, because the level under a holed floor
	## plane is now sometimes a real Slab (FLOOR_DEEP_LEVEL, generated by this very
	## rebuild but not rendered) and sometimes D13's fixed direct-cell ground. One
	## gu→level dict could not hold both anyway: a GU cratered through BOTH planes
	## needs the deep Slab drawn AND the fixed level under it.
	var reveal_slab_gus: Dictionary = {}    ## Vector2i(gu) → true (deep Slab to draw)
	var reveal_fixed: Dictionary = {}       ## Vector2i(gu) → fixed level to draw

	for base_key in _base_damage:
		var vxy := PerspectiveMapperClass.cell_from_base(
				Vector2i(base_key.x, base_key.y), _active_perspective, base_size_vox)
		var v = index.get(Vector3i(vxy.x, vxy.y, base_key.z))
		if v == null:
			continue
		## D23/D25: replay the FULL record, not just damage_state — the carved
		## side is re-derived for the perspective being entered, so the hole
		## stays on the side that physically faced the blast instead of
		## following the screen.
		var rec: Array = _base_damage[base_key]
		var rec_state: int = int(rec[0])
		v.set_damage(rec_state, int(rec[1]) == 1,
			_carved_side_from_base(Vector2i(base_key.x, base_key.y),
				Vector3i(int(rec[2]), int(rec[3]), int(rec[4]))),
			int(rec[5]) if rec.size() > 5 else 0,
			int(rec[6]) if rec.size() > 6 else 0)
		## A destroyed FLOOR voxel exposes the level beneath it — re-reveal it and
		## scorch the revealed cell, same as the original detonation did (VL-D2).
		if base_key.z < 0 and rec_state == Voxel.DamageState.DESTROYED:
			var gu := Vector2i(v.grid_pos.x >> 3, v.grid_pos.y >> 3)
			var below_level: int = v.level - 1
			if below_level >= GeometryCoords.FLOOR_DEEP_LEVEL:
				## The deep Slab draws itself; its exposed surface's soot is
				## derived the ordinary way at the next repaint (D24), on its
				## own now-restored Voxels — nothing to replay here for it.
				reveal_slab_gus[gu] = true
			else:
				reveal_fixed[gu] = below_level
				## FLOOR-DEPTH-02: the SAME cap the detonation wrote — a rotation
				## re-derives this side map from scratch, so a different ring here
				## would repaint the crater floor a different shade every time the
				## map turned. (The deep plane needs no equivalent: D24 re-derives
				## its soot from its own restored Voxels at the next repaint.)
				add_crater_floor_soot(below_level, v.grid_pos,
						BlastCalculator.EXPOSED_FLOOR_SOOT_RING)

	## Reveal AFTER the damage loop, never during it: reveal_floor_slab() skips
	## destroyed voxels, so the deep plane must already know which of its own
	## voxels are holes before it draws itself — otherwise this replay would place
	## cells back into the crater it is supposed to be restoring.
	for gu in reveal_slab_gus:
		var deep_slab: Slab = _slab_registry.get_slab(
				Slab.make_id(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_DEEP_LEVEL))
		if deep_slab != null:
			_voxel_renderer.reveal_floor_slab(deep_slab)
	for gu in reveal_fixed:
		_voxel_renderer.render_fixed_earth_level(gu, reveal_fixed[gu])
	_voxel_renderer.process_dirty(_edge_registry)
	_voxel_renderer.process_dirty_slabs(_slab_registry)
var _ceiling_overlay: Node2D = null  ## VIS-01: overhead ceiling props/lights (CeilingPropOverlay)
const SHADOW_MULT   := GuardEnemy.SHADOW_MULT
const PENUMBRA_MULT := GuardEnemy.PENUMBRA_MULT

## M2-13: Obstacle heights (in tiles above the floor plane)
const OBSTACLE_HEIGHTS: Dictionary = {
	"crate":     1.0,
	"wall":      2.0,
	"block":     2.0,
	"column":    3.0,
	"half_wall": 1.0,
}
const OBSTACLE_HEIGHT_DEFAULT := 1.5

## Vision & FOW radii — independent of each other:
## VISION_TILE_RADIUS  controls only the shader gradient (live clear-circle around agent).
## FOW_REVEAL_RADIUS   controls how many tiles get permanently revealed each move.
const VISION_TILE_RADIUS := 5      ## shader gradient radius (tiles)
const FOW_REVEAL_RADIUS  := 9      ## FOW reveal radius (tiles)
const WORLD_TILE_PX      := 128.0  ## horizontal px per isometric tile step (used by vision fog shader)

## Viewport toggle state
var _is_desktop_viewport: bool = false
var _pending_auto_end_turn: bool = false
var _selected_cell: Vector2i = INVALID_CELL
var _active_perspective: String = "N"
var _alert_meter: int = 0

var _alert_max: int = 100
var _alert_gain_full: int = 45

## ID-01: Detection meter thresholds for state transitions
const DETECTION_THRESHOLD_SUSPICIOUS := 0.30
const DETECTION_THRESHOLD_ALERT      := 0.60
const DETECTION_THRESHOLD_CHASE      := 1.00

const ENEMY_INTER_TURN_DELAY := 1.0
const ENEMY_CAMERA_TWEEN_DURATION := 0.45
const ENEMY_PHASE_MAX_OPEN_ZOOM := 0.65
const ACTOR_END_HOLD_DELAY := 0.5

var _actor_end_pause_active: bool = false

## DEBUG-02: Voxel ruler overlay and nudge mode
var _debug_tools_controller: DebugToolsControllerClass = null

## INPUT-01: Input dispatcher
var _input_controller: InputControllerClass = null

## Selection state management
var _selection_controller: SelectionControllerClass = null

## TEST-ZONE placeholder (2026-07-21): right-click "Detonar" on a test prop.
var _test_zone_controller: TestZoneControllerClass = null
## FRAME-MEM-01 / 2026-07-29: every spinning pickup in the collectibles strip.
## _floating_collectible stays as an alias for the first of them, because the
## test_collectible capture action and _set_perspective already reference it.
var _collectibles: Array[Node] = []
var _floating_collectible: Node = null
## TEST-ZONE weapons bench (2026-07-29): static, aimed, right-click-firable
## weapon props — see TEST_ZONE_WEAPON_ROWS and WeaponBenchController.
var _weapon_bench_controller: WeaponBenchControllerClass = null
## §6c: right-click an ENEMY to open "Atirar" (B1, Director 2026-08-19 — the
## action lives on the target's menu, not the shooter's).
var _agent_shot_controller: AgentShotControllerClass = null
## §6c Part D: the decorative projectile. Amends D21 — visible, never simulated.
var _tracer_overlay: TracerOverlay = null
var _context_menu: DetonateContextMenuClass = null
## ESC-STACK-01: see modal_stack.gd — single source of truth for what Escape
## targets next (main menu, controls sub-panel, the grenade context menu, ...).
var _modal_stack: ModalStackClass = null

## World markers overlay (shadows, spill, light rays)
var _world_markers_controller: WorldMarkersOverlayControllerClass = null

## Room builder (map construction, tile placement, perspective transforms)
var _room_builder: RoomBuilderClass = null

## Turn controller (turn management, enemy phase, alert system)
var _turn_controller: TurnControllerClass = null

## Vision bonus added by agent abilities; combined with the player vision radius.
var vision_bonus_tiles: int = 0
var _agent_start_cell: Vector2i = Vector2i.ZERO
var _agent_start_cell_base: Vector2i = Vector2i.ZERO


## M2-10: Peek mechanic state
var _peek_active: bool = false
var _peek_timer: int   = 0
var _peek_pending: bool = false

## Dev 03: tile hover info
var _dev_hover_label: Label = null
var _hovered_cell: Vector2i = Vector2i(-1, -1)

## DEV-HUD-01: dev vision status panel
var _dev_vision_status_panel: Control = null

## Dev 04: agent trail overlay
const TRAIL_MAX := 5
var _agent_trail: Array[Vector2i] = []
var _tile_shadow: Node2D = null  ## TileOverlay for shadows (z=1, multiply)
var _light_ray_overlay: Node2D = null  ## LightRayOverlay — golden shafts from lamps (z=0, additive)
var _shrapnel_overlay: Node2D = null  ## E-FRAG — decorative shrapnel from blast
var _aim_bubble_overlay: Node2D = null  ## E-BUBBLE — Phase B aim-bubble UI
var _throw_perimeter_overlay: Node2D = null  ## T-MODE — throw range perimeter
var _throw_arc_overlay: Node2D = null  ## T-ARC — parabolic throw arc
var _shrapnel_preview_overlay: Node2D = null  ## T-FRAG — aiming shrapnel rays
var _target_cursor_overlay: Node2D = null  ## T-CURSOR — virtual grenade marker

## T-Z: the aiming stack's slots in the flat "UI above everything" z tier, whose
## first occupant is `_blast_wireframe_overlay` at 100. Bottom to top, and the
## order is the reading order of the preview: which GUs are hit, how far you can
## throw, the blast volume, the fragments, the trajectory, the grenade itself.
const AIM_Z_FOOTPRINT: int = 100
const AIM_Z_PERIMETER: int = 101
const AIM_Z_DOME: int = 102
const AIM_Z_RAYS: int = 103
const AIM_Z_ARC: int = 104
const AIM_Z_GRENADE: int = 105
var _ember_overlay: EmberOverlay = null  ## VL-D4 — fading glow VFX for freshly blasted voxels
var _smoke_spark_overlay: SmokeSparkOverlay = null  ## VFX-01 — smoke puffs + metal/stone sparks
var _debris_overlay: DebrisOverlay = null  ## VFX-01 — masonry dust + wood chips
var _explosion_flash_overlay: ExplosionFlashOverlay = null  ## E-FLASH-01 — 4-frame fireball + white flash frame

## VFX-01: chance (0-1) that a destroyed voxel of the relevant material also
## spawns dust/sparks/chips — starting points to tune after seeing it run;
## smoke always fires (no chance gate), per Director's request.
var vfx_dust_chance: float = 0.4
var vfx_spark_chance: float = 0.65
var vfx_chip_chance: float = 0.55
var vfx_dust_materials: Array[String] = ["concrete", "stone", "gravel", "earth"]
var vfx_metal_spark_count_min: int = 3
var vfx_metal_spark_count_max: int = 8
var vfx_stone_spark_count: int = 2
var vfx_chip_count_min: int = 1
var vfx_chip_count_max: int = 4
var vfx_smoke_darken_wood: float = 0.55   ## Color.darkened() amount — wood smoke reads darker
var vfx_smoke_darken_default: float = 0.15  ## masonry/metal/ground smoke reads lighter
var vfx_smoke_alpha: float = 0.6
var vfx_metal_spark_color: Color = Color(1.0, 0.95, 0.7, 1.0)
var vfx_stone_spark_color: Color = Color(0.9, 0.6, 0.35, 0.9)

## E-SPARK-01 (Director, 2026-08-13): *"o metal deveria gerar bastante faísca
## num tiro da shotgun. É o trade-off de não ter fumaça é bastante faísca.
## Pedra menos, e assim por diante."*
##
## WHY THIS TABLE HAD TO EXIST AT ALL, because the bug was not "too few sparks":
## `_dispatch_destruction_vfx()` runs off `VoxelRenderer.voxel_destroyed`, so it
## only ever fires for a voxel that is DESTROYED. Measured on the real bench
## (D30's ladder: <0.30 CRACKED, <0.60 DENTED, above DESTROYED) —
##
##     shotgun -> metal   punch 0.29-0.39   every pellet DENTED/CRACKED
##     shotgun -> stone   punch 0.42-0.53   every pellet DENTED
##     shotgun -> wood    punch 0.78-1.06   every pellet DESTROYED
##
## — metal and stone under a shotgun structurally never reach DESTROYED, so they
## produced NO vfx at all while wood got the full dispatch. Exactly inverted.
## Same structural gap D33-SOOT-01 found for soot on 2026-08-03 and closed with
## `apply_self_soot()`; this is the VFX half of that finding.
##
## A round that DENTS steel and bounces off should throw more sparks than one
## that punches through, not fewer — so the impact profile is deliberately not a
## scaled-down copy of the destruction one. Metal trades smoke for sparks
## outright, per the Director's own rule; wood trades sparks for splinters and
## dark smoke; masonry sits between with dust.
##
## All `var` (Rule 1) and read as data — a material with no row here throws
## nothing on impact, which is today's behaviour for everything.
## E-SPARK-02 (Director, 2026-08-13) set the per-material ladder directly:
## *"cimento gera só um pouquinho de faísca, metal bastante, pedra médio,
## madeira não."* Concrete had 0 and now has its pouquinho; wood stays at zero,
## which is the one row that is a hard rule rather than a level on a dial.
var vfx_impact_profiles: Dictionary = {
	"metal":    {"sparks": 16, "smoke": false, "dust": false, "chips": 0},
	"stone":    {"sparks": 7,  "smoke": false, "dust": true,  "chips": 0},
	"concrete": {"sparks": 2,  "smoke": true,  "dust": true,  "chips": 0},
	"wood":     {"sparks": 0,  "smoke": true,  "dust": false, "chips": 2},
}
## Per-impact spark count jitter, so 24 pellets do not all throw the identical
## fan. Multiplies the profile's own count.
var vfx_impact_spark_jitter: float = 0.35
## E-SPARK-04 (Director): a spark thrown off a struck SURFACE flies out and is
## gone faster than the muzzle's own, which stays as it is. Per-call overrides on
## add_sparks(), never edits to the shared spark tunables — see that function.
var vfx_surface_spark_speed_scale: float = 1.3
var vfx_surface_spark_duration_scale: float = 0.6

## E-DEBRIS-01 (Director, 2026-08-13) — the last piece of VFX-01 that never
## reached explosions: dust, sparks and wood chips.
##
## THE ONE NUMBER THAT MATTERS, and the reason this is a scale rather than three
## more independent chances. The `vfx_*_chance` values above are per DESTROYED
## VOXEL and were calibrated against a FIREARM, where one shot destroys a handful
## of voxels. A real PLAYGROUND grenade destroys 243-500. Reusing them unchanged
## would put several hundred dust clusters and chip volleys on screen for one
## blast — not "more debris", a curtain — and the mistake would look like a
## tuning accident rather than the unit error it is.
##
## So the blast rates are expressed as ONE documented fraction of the firearm
## rates. That keeps a single knob for the Director's eye, and keeps the two
## weapon families from silently drifting apart the way the soot rings did
## (SOOT_MASTER_PLAN §1.2). 0.25 is a starting point measured on a real capture,
## not a researched constant — expect it to move.
var blast_debris_rate_scale: float = 0.25

## E-NATIVE-01 — the blast burst (see spawn_blast_burst()). All `var` (Rule 1);
## these are the whole tuning surface for the detonation's core now that the
## authored fireball is gone, so expect them to move on the Director's eye.
## The ember cluster is short-lived on purpose: EmberOverlay's own defaults
## (1.5-4.0 s) are tuned for scorched voxels cooling down, and a detonation's
## flash-core is a fraction of that.
##
## P-PLAY (Director, 2026-08-09): "aumentar um pouco as dimensões e a duração
## do efeito do fogo." Spread and lifetime both up; the counts rise with the
## spread rather than staying put, because widening the cluster without adding
## embers thins it out — the same overlap economics E-SMOKE-01 measured for the
## per-voxel smoke, where density comes from OVERLAP and a wider sparse cluster
## reads as fewer, more legible individual dots instead of one fire.
##
## P-STROBE (Director, 2026-08-09): "o fogo se extende mais um pouco e permanece
## acontecendo durante os 4 frames do flash." Lifetimes up again, 0.40-1.05 →
## 0.50-1.25.
##
## The "permanece acontecendo" half of that was **already satisfied by a wide
## margin and is not what moved** — measured, not assumed: the strobe runs
## `burst_lead_frames` (3) + 4 held frames = 7 frames, ≈117 ms at 60 fps,
## against a fire whose SHORTEST ember already lived 400 ms. So the extension is
## purely for the look the Director asked for, not to cover the strobe. Recorded
## because "extend it so it covers X" is exactly the kind of instruction that
## later gets read as a constraint and re-tuned against.
var blast_burst_ember_count: int = 22
var blast_burst_ember_spread_px: float = 64.0
var blast_burst_ember_life_min: float = 0.50
var blast_burst_ember_life_max: float = 1.25

## P-FIRE (Director, 2026-08-09) — the fireball EXPANDS now instead of appearing
## at full size. See spawn_blast_burst() for how these compose.
##
## Where the numbers come from, so the next pass tunes them and does not
## re-derive them: at drag 3.4 an ember travels `speed / drag` px over its whole
## flight (the integral of an exponential decay), so the 150-320 px/s range
## reaches ~44-94 px — straddling `blast_burst_ember_spread_px` (64), which used
## to be the radius the cluster was SCATTERED across at t=0 and is now the reach
## it grows INTO. That is the one relationship worth preserving when retuning:
## speed/drag should land near the spread, or the fire either falls short of its
## own smoke or outruns it.
var blast_burst_ember_start_radius_px: float = 7.0   ## "do tamanho da granada"
var blast_burst_ember_speed_min: float = 150.0
var blast_burst_ember_speed_max: float = 320.0
var blast_burst_ember_drag: float = 3.4              ## fast out, then coasts

## E-EMBER-02 (Director, 2026-08-13): *"o foguinho brilhando… queremos que suba
## rapidamente pra cima verticalmente e ao longo da parede, e apague em
## seguida, deixando para trás voxels bem vermelhos e brilhantes"* — and, on why
## it mattered: *"talvez já esteja funcionando, mas como o foguinho está por
## cima eu não estou vendo."* That diagnosis was right. The burst and the
## per-voxel scorch embers share ONE overlay and therefore one z_index, so for
## the fire's whole life it drew over the very thing it was supposed to be
## revealing.
##
## Fixed by moving the fire rather than by shortening it: at 46 px/s a burst
## ember climbed ~46 px over a ~1 s life — less than two voxel steps, so it
## effectively sat on the crater until it died. Tripled, it clears the crater
## early and is still alive and visible ABOVE it, which is both what the
## Director described and what keeps P-STROBE's "o fogo permanece acontecendo
## durante os 4 frames do flash" intact. **Shortening the lifetime would have
## broken that** and is the obvious wrong lever here.
##
## The jitter is E-EMBER-02's "velocidades ligeiramente diferentes": buoyancy
## used to be one constant shared by all 22 embers, which made the cluster rise
## as a rigid plate. Per-ember it frays into a plume.
var blast_burst_ember_rise_px_s: float = 150.0       ## buoyancy, never decays
var blast_burst_ember_rise_jitter: float = 0.45      ## +/- fraction, per ember

## The dome the fire blooms into, in degrees of elevation off the ground plane.
## Asymmetric on purpose — "pra baixo não muito por causa do chão" is expressed
## as a shallow downward cone rather than as a damping factor, because elevation
## is the axis the Director actually described. Up is generous: a fireball is a
## rising thing, and nothing is in its way.
var blast_burst_ember_up_deg: float = 72.0
var blast_burst_ember_down_deg: float = 10.0

## The isometric floor's own foreshortening — one horizontal unit of depth is
## half a unit on screen. Ground movement is squashed by it; ALTITUDE is not.
## Same 0.5 the burst's original spawn offset used, named now that two different
## axes depend on it meaning different things.
const BLAST_ISO_GROUND_SQUASH: float = 0.5
var blast_burst_spark_count: int = 34
var blast_burst_spark_color: Color = Color(1.0, 0.9, 0.62, 1.0)
var blast_burst_dust_count: int = 7
var blast_burst_dust_drop_px: float = 44.0
var blast_burst_dust_color: Color = Color(0.62, 0.58, 0.52, 1.0)

## PERF-01: guards against a second detonate/fire racing the same
## TileMapLayers mid-render while an async destruction render pass
## (process_dirty_async()/process_dirty_slabs_async(), spread across frames)
## is in flight. Both check-and-early-return on this before starting another
## pass — two concurrent passes would race on the same TileMapLayers.
## The @warning_ignore below is load-bearing: Godot's own linter reports this as
## UNUSED_PRIVATE_CLASS_VARIABLE, because it cannot see the cross-file write either
## (weapon_bench_controller.gd, test_zone_controller.gd) — that false warning is
## what invited an earlier delete (743bde2) that silently broke both callers'
## fire_active()/detonate_active() with a runtime "Invalid access" error.
@warning_ignore("unused_private_class_variable")
var _destruction_render_busy: bool = false
var _shadow_boundary_overlay: Node2D = null  ## ShadowBoundaryOverlay — edges of playable shadows (z=4)
## GU-GRID-01: always-on per-GU floor boundary grid (GuGridOverlay) —
## restores the reference grid the legacy floor art used to bake into its own
## texture, lost when the earth-voxel Slab floor (DESTRUCTION_MASTER_PLAN
## D2/D4) started painting over it. Independent of the F3 debug ruler
## (DebugToolsController's VoxelRulerOverlay — denser, voxel-subdivided).
var _gu_grid_overlay: Node2D = null
## DESTRUCTION_MASTER_PLAN Part 3: red blast-radius wireframe preview, shown
## while a grenade's context menu is open. See TestZoneController.open_menu_for().
var _blast_wireframe_overlay: Node2D = null
var _tile_game: Node2D = null   ## TileOverlay for visual gameplay (z=3, mix)
var _trail_overlay: Node2D = null

## M2-04: noise system and overlay
var _noise_system = null
var _noise_overlay: Node2D = null

## OCC-01: Occlusion module and debug overlay
var _occlusion_set: OcclusionSetClass = null
var _occlusion_overlay: Node2D = null
var _occlusion_wireframe_overlay: Node2D = null

## M2-14: Guard noise indicator — flutuante ao redor do agente
var _guard_noise_indicator: Node2D = null

## MODULARIZE-01: VisionController to manage debug/analysis overlays
var _vision_controller: Node2D = null

## MODULARIZE-02: HudController to manage UI wiring
var _hud_controller: Node = null

## PAUSE-MENU-01: Main menu panel
var _main_menu_panel: Node = null

## PAUSE-MENU-02: Controls panel
var _controls_panel: Node = null
var _showcase_panel: Node = null

## MODULARIZE-04: CameraController to manage drag, zoom, perspective
var _camera_controller: Node = null

## MODULARIZE-03: LightingController to manage lighting systems
var _lighting_controller: Node = null

## MODULARIZE-05: FowController to manage reveal and shader parameters
var _fow_controller: Node = null

## MODULARIZE-06: GuardCoordinator to route coordination signals between guards
var _guard_coordinator: Node = null

## M2-14: Noise chance per guard state
const GUARD_NOISE_CHANCE_BY_STATE := {
	"patrol": 0.15,
	"suspicious": 0.40,
	"alert": 0.60,
	"chase": 0.70,
	"search": 0.50,
}

## M2-14: Noise intensity per guard state
const GUARD_NOISE_INTENSITY_BY_STATE := {
	"patrol": 0.4,
	"suspicious": 0.6,
	"alert": 0.9,
	"chase": 1.0,
	"search": 0.7,
}

## Position of this segment in the 3×3 level grid (gx, gy in 0..2).
## Set before _ready() runs (e.g. by the level controller or via the Inspector).
## Controls which exits LevelGraph assigns; default (1,1) = centre segment (all exits open).
@export var segment_grid_pos: Vector2i = Vector2i(1, 1)
## Seed for the level graph random generator. Match across all 9 segments in a level.
@export var level_seed: int = 0
## Which map MapCatalog resolves for this room: "PLAYGROUND", "SIGMA_01", "PROCEDURAL".
@export var map_id: String = "PLAYGROUND"  ## Restored default 2026-07-22 — PLAYGROUND is now the destruction test zone
## Quick-test override for wall storeys (0 = use the map's own wall_height). Inspector-tweakable.
@export var wall_height_override: int = 8  ## Legacy, now ignored (FIX-EXTERIOR-WALLS-01: exterior walls have fixed EXTERIOR_WALL_STOREYS height)
## SLICE-00: Enable voxel alignment probe to measure and report world-space deltas.
@export var debug_probe_voxel_alignment: bool = true

const WHISTLE_RADIUS := 3


## Loads (or reloads) the given map into the already-initialized room. Safe to call
## after _ready() — used by _ready() itself and by the F2 debug panel.
func load_map(new_map_id: String, new_seed: int = 0) -> void:
	map_id = new_map_id
	if new_map_id == "PROCEDURAL":
		level_seed = new_seed

	var graph: LevelGraph = LevelGraphClass.new()
	var connections: Dictionary = graph.generate(level_seed)

	var spec: Dictionary = MapCatalogClass.get_spec(map_id, {
		"connections":      connections,
		"segment_grid_pos": segment_grid_pos,
		"seed":             level_seed,
	})
	var layout: Dictionary = MapCompilerClass.compile(spec, {
		"connections":      connections,
		"segment_grid_pos": segment_grid_pos,
		"seed":             level_seed,
	})
	if layout.is_empty():
		push_error("[Room] Map compilation failed for map_id '%s' — room state unchanged" % new_map_id)
		return
	_base_layout = layout.duplicate(true)
	## §5.2: a new map is the bluntest possible world change — every cached
	## prediction points at Voxels that are about to be replaced wholesale.
	bump_world_revision()
	_agent_start_cell_base = layout.get("agent_start_cell", Vector2i.ZERO)
	var room_size: Vector2i = layout.get("size", Vector2i.ZERO)
	if room_size == Vector2i.ZERO:
		push_error("Room layout did not provide a valid map size.")
		return

	## VL-PERF-BAKE: a (re)load always does a full rebake — the rotation fast-path
	## caches sources, but a reload may intend to pick up changed facades.
	_room_builder.invalidate_bake_cache()
	var view_layout := _room_builder.layout_with_perspective(layout, _active_perspective)
	room_size = view_layout.get("size", room_size)
	_map_buffer = view_layout.get("buffer", 0)
	_room_builder.build_from_layout(view_layout, room_size)
	## VL-D3: floor columns under structure, from the intact just-built geometry.
	_under_structure = _voxel_renderer.columns_with_structure()
	_room_size = room_size
	_assert_geometry_rendered()
	_refresh_gu_grid_overlay()

	## SCREENSHOT-HOOK-01: persist the last successfully loaded map id so the
	## pre-commit auto-screenshot capture (a separate Godot process) knows
	## which map to boot into. Written only after a load actually succeeds
	## (past both error-return points above) so a failed load never
	## overwrites a good last-known value.
	var current_map_config := ConfigFile.new()
	current_map_config.set_value("state", "map_id", new_map_id)
	if new_map_id == "PROCEDURAL":
		current_map_config.set_value("state", "seed", new_seed)
	var save_err := current_map_config.save("user://current_map.cfg")
	if save_err != OK:
		push_warning("[Room] Could not persist current_map.cfg (error %d) — auto-screenshot will use its fallback map" % save_err)

	## Sync cached data from builder to room state
	_blocked_cells = _room_builder.get_blocked_cells()
	_prop_heights = _room_builder.get_prop_heights()
	_exit_cells = _room_builder.get_exit_cells()
	_current_light_sources = _room_builder.get_light_sources()
	_crater_floor_soot.clear()  ## VL-D2: fresh map, no crater floor scorch yet
	_base_damage.clear()        ## VL-PERSIST: fresh map, no destruction yet
	_gu_blast_count.clear()     ## D2: fresh map, no GU has been blasted yet
	if _ember_overlay != null:
		_ember_overlay.clear()  ## VL-D4: any in-flight glow belongs to the old map
	if _smoke_spark_overlay != null:
		_smoke_spark_overlay.clear()  ## VFX-01: same reasoning as the ember overlay above
	if _debris_overlay != null:
		_debris_overlay.clear()
	if _explosion_flash_overlay != null:
		_explosion_flash_overlay.clear()  ## E-FLASH-01: same reasoning as the overlays above
	if _shrapnel_overlay != null:
		_shrapnel_overlay.clear()  ## E-FRAG: same reasoning as the overlays above
	if _aim_bubble_overlay != null:
		_aim_bubble_overlay.clear()  ## E-BUBBLE: same reasoning as the overlays above
	if _throw_perimeter_overlay != null:
		_throw_perimeter_overlay.clear()  ## T-MODE: same reasoning as the overlays above
	if _throw_arc_overlay != null:
		_throw_arc_overlay.clear()  ## T-ARC: same reasoning as the overlays above
	if _shrapnel_preview_overlay != null:
		_shrapnel_preview_overlay.clear()  ## T-FRAG: same reasoning as the overlays above
	if _target_cursor_overlay != null:
		_target_cursor_overlay.clear()  ## T-CURSOR: same reasoning as the overlays above
	if _camera_controller != null:
		## E-FLASH-01: a map load mid-shake must not leave the camera displaced.
		_camera_controller.stop_shake()

	## Reset turn/agent state so a reload doesn't leave stale AP/position/FOW from the
	## previous map. Reuse whatever _ready() already does after _build_room() for
	## agent placement, turn_manager reset, FOW rebuild, camera recenter.
	var agent_start_cell: Vector2i = view_layout.get("agent_start_cell", Vector2i.ZERO)
	_agent_start_cell = agent_start_cell
	_center_camera(agent_start_cell)

	## Give overlays their references.
	movement_overlay.z_index = 5
	movement_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, turn_manager.move_points_per_ap)
	movement_overlay.set_blocked_cells(_room_builder.build_navigation_blocked_cells(_guards))
	var blocked_edges: Array[Dictionary] = []
	for e in view_layout.get("blocked_edges", []):
		blocked_edges.append(e)
	_current_blocked_edges = blocked_edges.duplicate(true)
	movement_overlay.set_blocked_edges(blocked_edges)
	path_preview.setup(floor_layer, VISUAL_GRID_OFFSET)
	path_preview.z_index = 6
	selection_overlay.floor_layer = floor_layer
	selection_overlay.visual_offset = VISUAL_GRID_OFFSET
	selection_overlay.z_index = 7

	agent.setup(floor_layer, VISUAL_GRID_OFFSET, agent_start_cell)
	## CHARACTER Part 2 §10: the baked figure replaces the vector placeholder.
	## Idempotent, so a map reload does not stack a second sprite; it returns
	## false (having already push_error'd) if the bake is missing, and the agent
	## stays playable but invisible rather than taking the room down with it.
	if not agent.attach_sprite(self):
		push_warning("[Room] the agent's baked figure is unavailable — run "
			+ "p3_posture_export.py and agent_frame_bake_spike.gd")
	agent.set_dev_vision(_vision_controller.dev_vision)
	## W-LOAD-02: the AIMED grip's frames, loaded here instead of on the click
	## that opens the fire menu. Measured 2026-08-20: the first set_grip("_aimed")
	## cost 146 ms of a 160 ms frame, and that frame is the one the player judges
	## the menu's responsiveness by. Best-effort and silent on a missing bake —
	## AgentShotController.open_menu_for() still calls set_grip(), which is the
	## loud path. Director's rule for this session: everything that can be loaded
	## at the start, is.
	if agent.sprite != null:
		agent.sprite.preload_grip(AgentShotControllerClass.GRIP_AIMED)

	# OCC-03: Agent renders above all voxel layers, below dev hover label (z=200)
	var max_voxel_z_index := _voxel_renderer.get_max_voxel_z_index()
	agent.z_index = max_voxel_z_index + 1
	print("[OCC-03] Agent z_index set to %d (max voxel layer z_index: %d, room size: %s)" % [agent.z_index, max_voxel_z_index, room_size])
	## VL-02a: overhead fixtures/shafts are DRAWN at ceiling_lift — above the whole
	## wall stack on screen — so they must sort above it too. Their old z values
	## (rays 0; lamps WALL_BASE_Z_INDEX + ceil_floors + 1 = 19) were derived from the
	## ceiling-FIXTURE height, not the built wall height, so any voxel level above 9
	## (z >= 20) drew over them. Recomputed per map load, like the agent's, because
	## layer count is map-dependent. Same family as VL-01's OVERHEAD-anchor bug.
	_apply_overhead_overlay_z(max_voxel_z_index)
	assert(agent.z_index < 200, "Agent z_index must stay below dev overlay (200)")
	
	_spawn_guards(view_layout.get("enemy_defs", []))
	enemies_root.z_index = 10
	
	## Sync game state to TurnController
	if _turn_controller != null:
		_turn_controller.set_game_state(_guards, _blocked_cells, _current_blocked_edges, _room_size)
	
	_fow_controller.initialize_fog(floor_layer, VISUAL_GRID_OFFSET, room_size)
	_fow_controller.reveal_around(agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	## HEAT-Z-01 sweep (Director, 2026-07-28): the dev cell-number overlay was the
	## other casualty of D17's voxel earth floor reaching z=0 — it is a plain
	## Node2D in room.tscn, so it kept the default z_index 0 and, being a scene
	## child added BEFORE VoxelRenderer, lost the tie and disappeared under the
	## concrete. z=8 is the top of the floor-plane band (shadows 1, FOW 2, game
	## tiles 3, shadow boundary 4, AP 5, path 6, selection 7) and still below the
	## walls (WALL_BASE_Z_INDEX = 10): labels are sparse text meant to be READ, so
	## unlike the HEAT tint they go above the other floor overlays, not under them.
	tile_labels_overlay.z_index = 8
	tile_labels_overlay.floor_layer = floor_layer
	tile_labels_overlay.visual_offset = VISUAL_GRID_OFFSET
	tile_labels_overlay.room_w = room_size.x
	tile_labels_overlay.room_h = room_size.y
	tile_labels_overlay.visible = false
	btn_numbers.modulate = Color(1.0, 1.0, 1.0, 0.35)
	camera.ignore_rotation = true
	camera.rotation_degrees = 0.0

	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	turn_manager.reset_player_turn()
	_update_alert_label()
	enemy_turn_banner.visible = false

	tile_labels_overlay.queue_redraw()
	_lighting_controller.rebuild_all()
	if _ceiling_overlay != null:
		_ceiling_overlay.set_lights(_current_light_sources)
	_agent_trail.clear()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()
	if _noise_system != null:
		_noise_system.clear()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()

	_alert_meter = 0
	_update_alert_label()
	_update_guard_los_data()
	_populate_test_zone_if_playground()


func _ready() -> void:
	## ESC-STACK-01: created before any modal (menu panels, context menu) so
	## every wiring below can push/pop into it unconditionally.
	_modal_stack = ModalStackClass.new()

	## Initialize registries via autoload (FIX-SHUTDOWN-CRASH-01: real autoload, not Engine.set_meta).
	## Material registry is used by baking; ensure it's ready before map compilation.
	Registries.ensure_material_registry()
	
	## Load user:// bake toggle before any map builds (BAKE-LIVE-BOOT-01).
	BakeConfigClass.load_config()

	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("TileSet not found: " + TILESET_PATH)
		return

	floor_layer.tile_set = ts
	## Legacy coarse floor plane sits UNDER the voxel earth floor (negative
	## levels render at z = level+1 → bedrock -8..-2 occupies z -7..-1, top at
	## 0). See VoxelRenderer._build_voxel_layer_node for the slot map.
	floor_layer.z_index = -9
	structure_layer.tile_set = ts
	structure_layer.z_index = 10
	_wall_tileset = ts
	## M2-13: Initialize shadow layers
	shadow_full_layer.tile_set = ts
	shadow_partial_layer.tile_set = ts
	shadow_full_layer.z_index = 1
	shadow_partial_layer.z_index = 1
	shadow_full_layer.modulate = Color(0.58, 0.58, 0.58, 1.0)
	shadow_partial_layer.modulate = Color(0.78, 0.78, 0.78, 1.0)

	## Initialize RoomBuilder (map construction orchestrator)
	_room_builder = RoomBuilderClass.new(self)
	_room_builder.setup(floor_layer, structure_layer, ts)
	_room_builder.build_registry(ts)

	## Initialize TurnController (turn phases, enemy AI, alert system)
	_turn_controller = TurnControllerClass.new(self)

	## SLICE-02: Initialize VoxelRenderer
	_voxel_renderer = VoxelRendererClass.new()
	add_child(_voxel_renderer)
	_voxel_renderer.setup(VISUAL_GRID_OFFSET, WALL_BASE_Z_INDEX)

	## MODULARIZE-03: Initialize LightingController (before VisionController, which connects to its signals)
	_lighting_controller = LightingControllerClass.new()
	_lighting_controller.name = "LightingController"
	add_child(_lighting_controller)
	_lighting_controller.setup(self)

	## MODULARIZE-01: Initialize VisionController (after systems ready, before final _ready() wiring)
	_vision_controller = VisionControllerClass.new()
	_vision_controller.name = "VisionController"
	add_child(_vision_controller)
	_vision_controller.setup(self, fog_of_war)
	set_meta("vision_controller", _vision_controller)

	## Create shadow boundary overlay (dark edges of playable shadows)
	_shadow_boundary_overlay = Node2D.new()
	_shadow_boundary_overlay.set_script(ShadowBoundaryOverlayClass)
	_shadow_boundary_overlay.z_index = 4  ## Above _tile_game (z=3), well above fog_of_war (z=2)
	add_child(_shadow_boundary_overlay)
	_shadow_boundary_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

	## GU-GRID-01: always-on GU boundary grid — z_index 1 puts it above the
	## earth-voxel floor's top level (z=0, see VoxelRenderer's negative-level
	## z formula) and level with the shadow tint layers, so walls/shadow/fog
	## still draw over it like they do the floor itself. room_size is not
	## known yet at this point in _ready(); load_map() refreshes it below.
	_gu_grid_overlay = Node2D.new()
	_gu_grid_overlay.set_script(GuGridOverlayClass)
	_gu_grid_overlay.z_index = 1
	add_child(_gu_grid_overlay)
	_gu_grid_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

	## DESTRUCTION_MASTER_PLAN Part 3: blast-radius preview — deliberately
	## above walls (z=100, matching the F3 debug ruler's reasoning) since it's
	## an active preview the player is meant to notice, not ambient floor
	## decoration like _gu_grid_overlay.
	_blast_wireframe_overlay = Node2D.new()
	_blast_wireframe_overlay.set_script(BlastWireframeOverlayClass)
	_blast_wireframe_overlay.z_index = AIM_Z_FOOTPRINT
	add_child(_blast_wireframe_overlay)
	_blast_wireframe_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

	## M2-14: Create and setup TileOverlay instances for shadow and game visuals
	_tile_shadow = Node2D.new()
	_tile_shadow.set_script(TileOverlayClass)
	_tile_shadow.z_index = 1  ## Renders below (shadow)
	add_child(_tile_shadow)
	_tile_shadow.material = CanvasItemMaterial.new()
	_tile_shadow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tile_shadow.setup(floor_layer, VISUAL_GRID_OFFSET)

	_tile_game = Node2D.new()
	_tile_game.set_script(TileOverlayClass)
	_tile_game.z_index = 3  ## Renders above noise/detection
	add_child(_tile_game)
	_tile_game.material = CanvasItemMaterial.new()
	_tile_game.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_tile_game.setup(floor_layer, VISUAL_GRID_OFFSET)

	## Initialize light ray overlay (before world markers controller, setup later with ceiling_lift)
	_light_ray_overlay = LightRayOverlayClass.new()
	_light_ray_overlay.z_index = 0
	_light_ray_overlay.visible = false  ## hidden by default; toggled by VisionController (L key)
	add_child(_light_ray_overlay)

	## E-FRAG: decorative shrapnel overlay. z assigned in
	## _apply_overhead_overlay_z() once the real wall-stack height is known.
	_shrapnel_overlay = ShrapnelOverlayClass.new()
	add_child(_shrapnel_overlay)

	## E-BUBBLE: Phase B aim-bubble (UI layer, always visible if shown).
	_aim_bubble_overlay = AimBubbleOverlayClass.new()
	add_child(_aim_bubble_overlay)

	## T-MODE: throw range perimeter (UI layer).
	_throw_perimeter_overlay = ThrowPerimeterOverlayClass.new()
	add_child(_throw_perimeter_overlay)

	## T-ARC: throw arc parabola (UI layer).
	_throw_arc_overlay = ThrowArcOverlayClass.new()
	add_child(_throw_arc_overlay)

	## T-FRAG: aiming shrapnel rays. Added AFTER the aim dome so it draws over
	## it at the same z — the rays are the tactical information, the dome is the
	## shape they travel inside.
	_shrapnel_preview_overlay = ShrapnelPreviewOverlayClass.new()
	add_child(_shrapnel_preview_overlay)
	_shrapnel_preview_overlay.setup(floor_layer, VISUAL_GRID_OFFSET)

	## T-CURSOR: the hatched grenade standing on the target cell, in place of
	## SelectionOverlay's magenta diamond while a throw is being aimed.
	_target_cursor_overlay = TargetCursorOverlayClass.new()
	add_child(_target_cursor_overlay)

	## VL-D4: ember glow overlay (blast VFX). z assigned in
	## _apply_overhead_overlay_z() once the real wall-stack height is known.
	_ember_overlay = EmberOverlayClass.new()
	add_child(_ember_overlay)

	## VFX-01: smoke/spark (above-floor) and dust/chip (floor-level) VFX for
	## VoxelRenderer.voxel_destroyed — same deferred z-assignment as above.
	_smoke_spark_overlay = SmokeSparkOverlayClass.new()
	add_child(_smoke_spark_overlay)
	_debris_overlay = DebrisOverlayClass.new()
	## Fixed floor-level z (not overhead-band, unlike ember/smoke/spark): dust
	## and chips read as sitting ON the ground, not floating above every wall.
	## Just above the floor layer (-9), below structure/agents — see
	## _apply_overhead_overlay_z()'s doc for the overhead-band siblings.
	_debris_overlay.z_index = -8
	add_child(_debris_overlay)
	## E-FLASH-01: the detonation fireball + its white flash frame. Added LAST of
	## the overhead-band overlays so it draws over smoke and embers — the flash
	## is meant to wash out everything the blast just did, including the VFX.
	_explosion_flash_overlay = ExplosionFlashOverlayClass.new()
	add_child(_explosion_flash_overlay)
	_ember_overlay.set_smoke_overlay(_smoke_spark_overlay)
	_voxel_renderer.voxel_destroyed.connect(_on_voxel_destroyed)

	## Initialize world markers overlay controller (shadows, spill, light rays)
	## MUST be before signal connections to LightingController
	_world_markers_controller = WorldMarkersOverlayControllerClass.new(self)
	_world_markers_controller.setup(_tile_shadow, _lighting_controller, _shadow_boundary_overlay,
		_light_ray_overlay, _vision_controller, floor_layer, VISUAL_GRID_OFFSET, _room_size, _shadow_tiles)

	## Connect LightingController signal to VisionController for overlay updates
	_lighting_controller.lighting_rebuilt.connect(_vision_controller.request_redraw)
	## Geometric floor shadows are real-world elements → repaint the always-on
	## world shadow layer whenever lighting rebuilds (e.g. perspective rotation).
	_lighting_controller.lighting_rebuilt.connect(_world_markers_controller.repaint_world_shadows)
	## VL-01: project tactical lighting onto voxel faces (6 buckets) whenever
	## lighting rebuilds — map load, perspective rotation, light changes.
	_lighting_controller.lighting_rebuilt.connect(_repaint_voxel_light_buckets)

	## MODULARIZE-02: Initialize HudController (after nodes ready)
	_hud_controller = HudControllerClass.new()
	_hud_controller.name = "HudController"
	add_child(_hud_controller)
	_hud_controller.setup({
		"btn_end_turn": btn_end_turn,
		"btn_reset": btn_reset,
		"btn_fullscreen": btn_fullscreen,
		"btn_viewport": btn_viewport,
		"btn_numbers": btn_numbers,
		"chk_auto_end_turn": chk_auto_end_turn,
		"lbl_ap": lbl_ap,
		"lbl_alert": lbl_alert,
		"busted_dialog": busted_dialog,
		"enemy_turn_banner": enemy_turn_banner,
		"lbl_end_turn": lbl_end_turn,
		"lbl_enemy_turn": lbl_enemy_turn,
	})

	## Connect HudController signals to turn controller handlers
	_hud_controller.end_turn_requested.connect(_turn_controller._on_hud_end_turn_requested)
	_hud_controller.reset_requested.connect(_on_hud_reset_requested)
	_hud_controller.fullscreen_toggled.connect(_on_hud_fullscreen_toggled)
	_hud_controller.viewport_toggled.connect(_on_hud_viewport_toggled)
	_hud_controller.numbers_toggled.connect(_on_hud_numbers_toggled)

	## MODULARIZE-04: Initialize CameraController (after camera ready)
	_camera_controller = CameraControllerClass.new()
	_camera_controller.name = "CameraController"
	add_child(_camera_controller)
	_camera_controller.setup(camera, self)

	## MODULARIZE-05: Initialize FowController (before fog operations)
	_fow_controller = FowControllerClass.new()
	_fow_controller.name = "FowController"
	add_child(_fow_controller)
	_fow_controller.setup(self, fog_of_war, _fog_rect)

	## MODULARIZE-06: Initialize GuardCoordinator (after fow controller)
	_guard_coordinator = GuardCoordinatorClass.new()
	_guard_coordinator.name = "GuardCoordinator"
	add_child(_guard_coordinator)
	_guard_coordinator.setup(self)

	## MODULARIZE-08: Setup TurnController (turn management, enemy phase, alert system)
	_turn_controller.setup(
		turn_manager,
		enemy_phase_controller,
		agent,
		camera,
		floor_layer,
		_fow_controller,
		_hud_controller,
		_vision_controller,
		_guard_coordinator,
		_noise_system,
		_noise_overlay
	)
	_turn_controller.set_constants(
		VISUAL_GRID_OFFSET,
		FOW_REVEAL_RADIUS,
		vision_bonus_tiles,
		_alert_max,
		_alert_gain_full
	)

	turn_manager.ap_changed.connect(_on_ap_changed)
	turn_manager.player_turn_started.connect(_turn_controller._on_player_turn_started)
	turn_manager.enemy_phase_started.connect(_turn_controller._on_enemy_phase_started)
	agent.move_started.connect(_on_agent_move_started)
	agent.step_finished.connect(_on_agent_step_finished)
	agent.move_finished.connect(_on_agent_move_finished)
	## Perspective button connections now in CameraController

	## VL-00 (Director, 2026-07-23): every boot resumes the last map actually
	## worked on (persisted by load_map() itself into user://current_map.cfg).
	## The @export default (PLAYGROUND) only applies when no cfg exists yet.
	## Supersedes SCREENSHOT-HOOK-01's env-var confinement — the auto-capture
	## process now shares the normal-boot path.
	var last_map_config := ConfigFile.new()
	if last_map_config.load("user://current_map.cfg") == OK:
		var last_map_id: String = last_map_config.get_value("state", "map_id", map_id)
		if last_map_id != "":
			map_id = last_map_id
			level_seed = int(last_map_config.get_value("state", "seed", level_seed))

	load_map(map_id, level_seed)

	## DEBUG-01: Create map loader toolbar button
	## Initialize debug tools controller
	_debug_tools_controller = DebugToolsControllerClass.new(self)
	_debug_tools_controller.create_map_loader_button()

	## INPUT-01: Create and setup input controller
	set_meta("_camera_controller", _camera_controller)
	_input_controller = InputControllerClass.new(self)
	add_child(_input_controller)
	_input_controller.posture_lower_requested.connect(_on_posture_lower_requested)
	_input_controller.posture_raise_requested.connect(_on_posture_raise_requested)
	_input_controller.view_mode_requested.connect(_on_view_mode_requested)
	_input_controller.peek_initiated.connect(_on_peek_initiated)
	_input_controller.movement_input_requested.connect(_on_movement_input_requested)
	_input_controller.debug_command_requested.connect(_on_debug_command_requested)
	_input_controller.screenshot_requested.connect(_on_screenshot_requested)
	_input_controller.pause_requested.connect(_on_pause_requested)
	_input_controller.grenade_mode_requested.connect(_on_grenade_mode_requested)
	_input_controller.weapon_select_requested.connect(_on_weapon_select_requested)
	_input_controller.grenade_throw_requested.connect(_on_grenade_throw_requested)
	_input_controller.grenade_cancel_requested.connect(_on_grenade_cancel_requested)

	## PAUSE-MENU-01: Initialize main menu panel
	var MainMenuPanelClass = preload("res://godot/scripts/ui/main_menu_panel.gd")
	_main_menu_panel = MainMenuPanelClass.new()
	$HUD.add_child(_main_menu_panel)
	_main_menu_panel.reset_requested.connect(_on_hud_reset_requested)
	_main_menu_panel.controls_requested.connect(_on_controls_requested)
	_main_menu_panel.showcase_requested.connect(_on_showcase_requested)
	_main_menu_panel.hide() # Hidden by default
	## ESC-STACK-01: pause is a side effect of the panel actually being open,
	## not of the keypress that opened it — fires the same way whether it
	## closed via Escape (ModalStack), "New Game", or any future close button.
	_main_menu_panel.opened.connect(func(): _modal_stack.push(_main_menu_panel.close))
	_main_menu_panel.closed.connect(func():
		_modal_stack.remove(_main_menu_panel.close)
		get_tree().paused = false
	)

	## PAUSE-MENU-02: Initialize controls panel
	var ControlsPanelClass = preload("res://godot/scripts/ui/controls_panel.gd")
	_controls_panel = ControlsPanelClass.new()
	$HUD.add_child(_controls_panel)
	_controls_panel.hide() # Hidden by default
	## ESC-STACK-01: Controls sits ON TOP of the still-open Main Menu (see
	## _on_controls_requested) — pushing it means the first Escape closes only
	## Controls, revealing Main Menu still open; a second Escape closes that.
	_controls_panel.opened.connect(func(): _modal_stack.push(_controls_panel.close))
	_controls_panel.closed.connect(func(): _modal_stack.remove(_controls_panel.close))

	## ACTOR_MASTER_PLAN D20/Part 5a: Showcase screen (live 3D inspection window).
	var ShowcasePanelClass = preload("res://godot/scripts/ui/showcase_panel.gd")
	_showcase_panel = ShowcasePanelClass.new()
	$HUD.add_child(_showcase_panel)
	_showcase_panel.hide() # Hidden by default
	_showcase_panel.opened.connect(func(): _modal_stack.push(_showcase_panel.close))
	_showcase_panel.closed.connect(func(): _modal_stack.remove(_showcase_panel.close))

	## Initialize selection controller
	_selection_controller = SelectionControllerClass.new(self)

	## TEST-ZONE placeholder (2026-07-21): right-click "Detonar" on a test prop.
	## WEAPON-FIRE-01 (2026-07-29): and "Atirar" on a bench weapon — ONE menu
	## instance shared by both, because _unhandled_input's outside-click guard
	## keys off `_context_menu.visible` and a second instance would have to be
	## taught about the first. Which verb it shows, and what confirming it does,
	## are now passed in per open (DetonateContextMenu.open_at).
	_test_zone_controller = TestZoneControllerClass.new(self)
	_weapon_bench_controller = WeaponBenchControllerClass.new(self)
	## §6c: same shared menu instance, a third verb. The bench is retired from
	## PLAYGROUND but its controller stays constructed — the menu contract is
	## per-open (open_at), so an unused controller costs nothing and removing it
	## would be an unrequested cleanup of code that still carries §6b's history.
	_agent_shot_controller = AgentShotControllerClass.new(self)
	_context_menu = DetonateContextMenuClass.new()
	$HUD.add_child(_context_menu)
	_context_menu.cancelled.connect(_cancel_prop_menus)
	## ESC-STACK-01: close callable also cancels the pending grenade (matches
	## what _unhandled_input's outside-click path and Cancelar already do).
	_context_menu.opened.connect(func(): _modal_stack.push(_cancel_context_menu))
	_context_menu.closed.connect(func(): _modal_stack.remove(_cancel_context_menu))
	_populate_test_zone_if_playground()

	## §6c Part D: the tracer overlay. Added to the ROOM rather than the HUD so
	## it lives in world space — the muzzle and the impact are both world points,
	## and a HUD child would need both converted every frame instead of once.
	var TracerOverlayClass = preload("res://godot/scripts/overlays/tracer_overlay.gd")
	_tracer_overlay = TracerOverlayClass.new()
	add_child(_tracer_overlay)

	## Dev 04: Create and setup trail overlay
	var TrailOverlayClass = preload("res://godot/scripts/overlays/trail_overlay.gd")
	_trail_overlay = Node2D.new()
	_trail_overlay.set_script(TrailOverlayClass)
	add_child(_trail_overlay)
	_trail_overlay.setup(self, floor_layer, VISUAL_GRID_OFFSET)

	## M2-04: Create and setup noise system and overlay
	var NoiseSystemClass = preload("res://godot/scripts/systems/noise_system.gd")
	_noise_system = NoiseSystemClass.new()

	var NoiseOverlayClass = preload("res://godot/scripts/overlays/noise_overlay.gd")
	_noise_overlay = Node2D.new()
	_noise_overlay.set_script(NoiseOverlayClass)
	add_child(_noise_overlay)
	_noise_overlay.setup(self, floor_layer, VISUAL_GRID_OFFSET, _noise_system)

	## OCC-01: Create and setup occlusion module and debug overlay
	_occlusion_set = OcclusionSetClass.new()
	_occlusion_overlay = Node2D.new()
	_occlusion_overlay.set_script(OcclusionOverlayClass)
	## OCC-FIX-02: z=5 put the debug overlay UNDERNEATH the voxel layers (z = 10 + level,
	## up to 33 on a real map) — i.e. beneath the very walls whose cells it paints. It was
	## drawing correctly the whole time and could never be seen. A debug overlay for
	## occlusion must sit above everything it describes; 150 clears the tallest geometry
	## and stays below the dev hover label (200).
	_occlusion_overlay.z_index = 150
	add_child(_occlusion_overlay)
	_occlusion_overlay.set_occlusion_set(_occlusion_set)
	_occlusion_overlay.set_voxel_renderer(_voxel_renderer)
	## OCC-21m (2026-07-15): start invisible — now controlled by light_vision, not a
	## separate toggle. Director's call: colored ring overlay is analysis/debug, should
	## be part of LIGHT_VISION suite, not visible in normal gameplay.
	_occlusion_overlay.visible = false

	## OCC-07-b: the real, gameplay-facing occlusion visual — a silhouette outline over
	## the hidden geometry, one rectangle per occluded Slice (its own real shape, not
	## a generic box). Unlike _occlusion_overlay (dev-only diamond painter, starts
	## hidden behind a debug toggle), this one is meant to be visible from the start —
	## it is the whole point of occluding at all.
	## z_index stays at the default (0, relative) on THIS manager node — it no longer
	## carries a flat elevated z_index itself. Each occluded slice spawns its own
	## per-level child panel stamped with that level's REAL voxel-layer z_index (read
	## off VoxelRenderer directly), so the wireframe draws in the same bucket as the
	## geometry it stands in for and nearer, unoccluded walls correctly cover it —
	## a flat 150 always won regardless of what should have been in front of it.
	_occlusion_wireframe_overlay = Node2D.new()
	_occlusion_wireframe_overlay.set_script(OcclusionWireframeOverlayClass)
	add_child(_occlusion_wireframe_overlay)
	_occlusion_wireframe_overlay.set_occlusion_set(_occlusion_set)
	_occlusion_wireframe_overlay.set_voxel_renderer(_voxel_renderer)
	## OCC-12 (2026-07-14): back on — the diagonal-seam artifact was root-caused
	## to per-edge corner_a/corner_b coming from each edge's own independently
	## -scanned voxel bounds, which could disagree with a neighbor's at a real
	## corner. Rebuilt on OcclusionSet's merged hull segments (true shared grid
	## vertices, one box per straight run, not one per Slice/Edge) — see
	## OcclusionSet._build_wireframe_segments().
	_occlusion_wireframe_overlay.visible = true

	## OCC-FIX-02: seed the set for the map we just loaded.
	##
	## OCC-01 hooked recompute to agent step and _set_perspective only — and
	## _set_perspective returns early when the direction is unchanged. So on boot, in
	## the starting view, the occluded set stayed EMPTY until the player took his first
	## step: geometry standing in front of a motionless agent ghosted nothing. The
	## four-view harness caught it instantly (N=0 cells, E/S/W=85/97/85). Boot is the
	## third trigger; there is no fourth.
	_recompute_occlusion()

	## Paint the initial always-on world shadows from the geometric exposure.
	_world_markers_controller.repaint_world_shadows()

	## M2-14 Quickfix: Z-index ordering — floor(0) < shadow(1) < fog(2) < structures(3) < sprites(4+)
	## Ensure fog_of_war is properly layered above shadow overlay
	fog_of_war.z_index = 2

	## M2-14: Create and setup guard noise indicator — as child of agent so it orbits naturally
	_guard_noise_indicator = GuardNoiseIndicatorClass.new()
	agent.add_child(_guard_noise_indicator)
	_guard_noise_indicator.setup(floor_layer, VISUAL_GRID_OFFSET)

	## VIS-01 Slice 3: overhead ceiling layer (lights as placeholders for now),
	## raised above the wall stack and drawn above the top storey.
	_ceiling_overlay = CeilingPropOverlayClass.new()
	add_child(_ceiling_overlay)
	var ceil_floors: int = int(_base_layout.get("max_floors", 1))
	## VL-02a: real z is assigned by _apply_overhead_overlay_z() from the built
	## wall stack; this is only the pre-load placeholder.
	_ceiling_overlay.z_index = WALL_BASE_Z_INDEX + ceil_floors + 1
	## Lift to ceiling height: top of the wall stack + ~0.75 storey so fixtures read
	## as mounted overhead. True "5th-floor" verticality needs taller storeys (pairs
	## with the view-occlusion slice, else taller walls hide the interior).
	var ceiling_lift: float = WALL_FLOOR_STEP_PX * (float(ceil_floors) + 0.75)
	_ceiling_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, ceiling_lift)
	_ceiling_overlay.set_lights(_current_light_sources)

	## Light ray overlay — always-visible golden shafts, MIX blend, below shadow MUL (z=1).
	## Created here (after ceil_floors) so ceiling_lift matches the CeilingPropOverlay exactly.
	_light_ray_overlay.setup(floor_layer, VISUAL_GRID_OFFSET, ceiling_lift)
	## Initial populate: _repaint_world_shadows() ran before this node existed, so feed it now.
	_light_ray_overlay.refresh(_lighting_controller.get_shadow_results())
	## VL-02a: both overhead overlays exist only now — load_map()'s own call ran
	## before they were constructed, so assign their real z here too.
	_apply_overhead_overlay_z(_voxel_renderer.get_max_voxel_z_index())

	## Dev 03: Create hover label for tile coordinates
	_dev_hover_label = Label.new()
	_dev_hover_label.add_theme_font_size_override("font_size", 13)
	_dev_hover_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	_dev_hover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_dev_hover_label.add_theme_constant_override("shadow_offset_x", 1)
	_dev_hover_label.add_theme_constant_override("shadow_offset_y", 1)
	## Black 80% backplate for contrast (matches other DEV/UI panels)
	var _hover_bg := StyleBoxFlat.new()
	_hover_bg.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	_hover_bg.content_margin_left = 8.0
	_hover_bg.content_margin_right = 8.0
	_hover_bg.content_margin_top = 6.0
	_hover_bg.content_margin_bottom = 6.0
	_hover_bg.corner_radius_top_left = 4
	_hover_bg.corner_radius_top_right = 4
	_hover_bg.corner_radius_bottom_left = 4
	_hover_bg.corner_radius_bottom_right = 4
	_dev_hover_label.add_theme_stylebox_override("normal", _hover_bg)
	_dev_hover_label.position = Vector2(12.0, 80.0)   ## below TopBar
	_dev_hover_label.z_index = 200
	_dev_hover_label.visible = false
	$HUD.add_child(_dev_hover_label)

	## DEV-HUD-01: Create and setup dev vision status panel
	_dev_vision_status_panel = DevVisionStatusPanelClass.new()
	_dev_vision_status_panel.name = "DevVisionStatusPanel"
	$HUD.add_child(_dev_vision_status_panel)
	_dev_vision_status_panel.setup(self)

	_update_perspective_button_state()

	## Centering camera/setup initial state
	_update_guard_los_data()
	_on_hud_viewport_toggled()

	## Initialize debug views (S1: FIX-BAKE-06)
	_initialize_debug_views()

	## SLICE-02: Run alignment probe if debug flag is set
	if debug_probe_voxel_alignment:
		print_debug("[DEBUG] _ready() complete, starting probe")
		_debug_probe_voxel_alignment()

	## SCREENSHOT-HOOK-01: opt-in auto-capture for the pre-commit hook's
	## dedicated Godot process (INFILTRAITOR_AUTO_SCREENSHOT=1). Never fires
	## during normal play — the env var is only set by the hook's own launch
	## command. Deferred a few frames past _ready() so the just-built map has
	## actually been rasterized before capture (SLICE-02's own probe above
	## proves _ready() completing does not by itself guarantee a drawn frame).
	if OS.get_environment("INFILTRAITOR_AUTO_SCREENSHOT") == "1":
		_run_auto_screenshot_capture()


func _set_perspective(direction: String) -> void:
	if not PerspectiveMapperClass.is_valid_direction(direction):
		return
	if _active_perspective == direction:
		_update_perspective_button_state()
		return

	var prev_direction := _active_perspective
	var base_agent := _cell_to_base(agent.cell, prev_direction)
	var has_selected := _selected_cell != INVALID_CELL
	var base_selected := _cell_to_base(_selected_cell, prev_direction) if has_selected else INVALID_CELL

	_active_perspective = direction
	## §2.4 lists the active perspective as a real input: carved sides and every
	## other screen-space read resolve differently after a rotation, and the
	## rotation rebuilds every Voxel besides.
	bump_world_revision()
	if not _base_layout.is_empty():
		var view_layout := _room_builder.layout_with_perspective(_base_layout, _active_perspective)
		var room_size: Vector2i = view_layout.get("size", _room_size)
		_room_builder.build_from_layout(view_layout, room_size)
		_room_size = room_size
		_assert_geometry_rendered()
		_refresh_gu_grid_overlay()
		_agent_start_cell = view_layout.get("agent_start_cell", _agent_start_cell)
		
		# Clear legacy shadow layers (migrated to _tile_shadow, but kept for compatibility)
		shadow_full_layer.clear()
		shadow_partial_layer.clear()
		
		# Update cache data from builder
		_blocked_cells = _room_builder.get_blocked_cells()
		_prop_heights = _room_builder.get_prop_heights()
		_exit_cells = _room_builder.get_exit_cells()
		_current_light_sources = _room_builder.get_light_sources()
		
		# Update tile semantics and shadow heights for new layout (LIGHT-FIX-03)
		# Now delegated to LightingController
		
		_spawn_guards(view_layout.get("enemy_defs", []))
		movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
		var blocked_edges: Array[Dictionary] = []
		for e in view_layout.get("blocked_edges", []):
			blocked_edges.append(e)
		_current_blocked_edges = blocked_edges.duplicate(true)
		movement_overlay.set_blocked_edges(blocked_edges)
		
		## Sync new game state to TurnController after perspective change
		if _turn_controller != null:
			_turn_controller.set_game_state(_guards, _blocked_cells, _current_blocked_edges, _room_size)

		tile_labels_overlay.room_w = _room_size.x
		tile_labels_overlay.room_h = _room_size.y

		var next_agent := PerspectiveMapperClass.cell_from_base(base_agent, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
		if not _is_cell_inside_room(next_agent):
			next_agent = _agent_start_cell
		agent.set_cell(next_agent)
		## The cell made the base-space round trip; so must the FACING, or the
		## figure turns 90 degrees every time the view rotates. AgentSprite stores
		## it in base space, so this only has to ask for a recompose.
		agent.on_perspective_changed()

		if has_selected:
			var next_selected := PerspectiveMapperClass.cell_from_base(base_selected, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
			_selected_cell = next_selected if _is_selectable_cell(next_selected) else next_agent
		else:
			_selected_cell = next_agent
		selection_overlay.set_selected(_selected_cell)

		## PERSPECTIVE-01: runtime-instantiated props outside _base_layout
		## (test-zone grenades) don't get rebuilt by build_from_layout() above —
		## reposition them explicitly, same pattern as the agent/selection block.
		if _test_zone_controller != null:
			_test_zone_controller.reposition_for_perspective(_active_perspective)
		for pickup in _collectibles:
			if pickup != null and is_instance_valid(pickup):
				pickup.reposition_for_perspective(_active_perspective)
		if _weapon_bench_controller != null:
			_weapon_bench_controller.reposition_for_perspective(_active_perspective)

		_fow_controller.initialize_fog(floor_layer, VISUAL_GRID_OFFSET, _room_size)
		_fow_controller.reveal_around(agent.cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
		_update_guard_los_data()
		_center_camera(agent.cell)

		## VL-D3: capture which floor columns are under structure from the INTACT
		## geometry (build just rendered everything unbroken) — before reapply
		## damage punches holes, so it reflects the ORIGINAL cover.
		_under_structure = _voxel_renderer.columns_with_structure()
		## VL-PERSIST: stamp recorded destruction back onto the freshly rebuilt
		## geometry BEFORE the lighting rebuild, so the repaint sees the holes and
		## soot in this view (build_from_layout rebuilt every Voxel intact).
		_reapply_base_damage()

		## Re-derive the per-cell overlays for the rotated layout so they follow the scenery:
		## numbers redraw, lighting (lights/semantics/shadows/exposure) rebuilds from the rotated
		## cells and emits lighting_rebuilt → VisionController refreshes its analysis overlays.
		tile_labels_overlay.queue_redraw()
		_lighting_controller.rebuild_all()
		_ceiling_overlay.set_lights(_current_light_sources)
		## Dev agent trail cells are now stale under the rotation — clear it.
		_agent_trail.clear()
		if _trail_overlay != null:
			_trail_overlay.queue_redraw()
		## VL-D4: an in-flight ember's stored world position is in the OLD
		## view's screen space — carrying it into the rotated frame would show
		## a glow floating over the wrong voxel instead of just fading away.
		if _ember_overlay != null:
			_ember_overlay.clear()
		if _smoke_spark_overlay != null:
			_smoke_spark_overlay.clear()
		if _debris_overlay != null:
			_debris_overlay.clear()
		if _shrapnel_overlay != null:
			_shrapnel_overlay.clear()
		if _aim_bubble_overlay != null:
			_aim_bubble_overlay.clear()
		if _throw_perimeter_overlay != null:
			_throw_perimeter_overlay.clear()
		if _throw_arc_overlay != null:
			_throw_arc_overlay.clear()
		if _shrapnel_preview_overlay != null:
			_shrapnel_preview_overlay.clear()
		if _target_cursor_overlay != null:
			_target_cursor_overlay.clear()
		if _explosion_flash_overlay != null:
			## E-FLASH-01: the fireball is anchored in the OLD view's screen
			## space, exactly like the ember glow above it.
			_explosion_flash_overlay.clear()
		if _camera_controller != null:
			_camera_controller.stop_shake()

		## OCC-01: Recompute occlusion set on perspective change
		_recompute_occlusion()

		_refresh_tactical_state()
	_update_perspective_button_state()


func _update_perspective_button_state() -> void:
	var active_mod := Color(1.0, 1.0, 1.0, 1.0)
	var inactive_mod := Color(1.0, 1.0, 1.0, 0.45)
	btn_perspective_nw.modulate = active_mod if _active_perspective == "W" else inactive_mod
	btn_perspective_ne.modulate = active_mod if _active_perspective == "N" else inactive_mod
	btn_perspective_sw.modulate = active_mod if _active_perspective == "S" else inactive_mod
	btn_perspective_se.modulate = active_mod if _active_perspective == "E" else inactive_mod


func _center_camera(focus_cell: Vector2i) -> void:
	var centre_world := floor_layer.map_to_local(focus_cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	camera.global_position = centre_world


func _on_hud_numbers_toggled() -> void:
	tile_labels_overlay.visible = not tile_labels_overlay.visible
	_hud_controller.set_numbers_button_active(tile_labels_overlay.visible)


func _on_hud_fullscreen_toggled(enabled: bool) -> void:
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(target_mode)


func _on_hud_end_turn_requested() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	turn_manager.end_turn()


func _on_hud_reset_requested() -> void:
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	_hud_controller.hide_enemy_banner()
	agent.set_cell(_agent_start_cell)
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)
	_fow_controller.reset_fog()
	_fow_controller.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)
	_center_camera(_agent_start_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()
	_alert_meter = 0
	_update_alert_label()
	## Dev 04: clear trail on reset
	_agent_trail.clear()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()
	## M2-04: clear noise on reset
	if _noise_system != null:
		_noise_system.clear()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	turn_manager.reset_player_turn()


func _on_hud_viewport_toggled() -> void:
	_is_desktop_viewport = not _is_desktop_viewport
	var target := Vector2i(1280, 720) if _is_desktop_viewport else Vector2i(390, 844)
	_hud_controller.set_viewport_button_text("D" if _is_desktop_viewport else "M")

	## Exit fullscreen first — can't resize while in fullscreen.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	## Resize the OS window.
	DisplayServer.window_set_size(target)

	## Change the logical canvas resolution so the camera sees the right world area.
	## Without this, canvas_items stretch just scales the fixed 390×844 base to fill the window.
	get_tree().root.content_scale_size = target

	## Center on screen after resize.
	var screen_size := DisplayServer.screen_get_size()
	var centered := Vector2(screen_size - target) / 2.0
	DisplayServer.window_set_position(Vector2i(centered.round()))


func _set_view_mode(which: String, btn: Button) -> void:
	if not _vision_controller:
		return
	match which:
		"dev": _vision_controller.toggle_dev()
		"light": _vision_controller.toggle_light()
		"heat": _vision_controller.toggle_heat()
	var enabled: bool = _vision_controller.dev_vision if which == "dev" \
		else (_vision_controller.light_vision if which == "light" else _vision_controller.heat_vision)
	btn.set_pressed_no_signal(enabled)
	btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(1.0, 1.0, 1.0, 0.35)

	## The agent and the probes both carry a second bake whose joints are yellow —
	## the same toggle drives both, so there is one dev switch rather than three.
	if which == "dev":
		agent.set_dev_vision(enabled)
		if _test_zone_controller != null:
			_test_zone_controller.set_agent_probes_dev_vision(enabled)

	## T-DEV: the two red aiming diagnostics are gated on dev vision, so toggling
	## it mid-aim has to rebuild the preview — otherwise the perimeter and the
	## footprint linger (or stay missing) until the cursor happens to move.
	if which == "dev" and _test_zone_controller != null \
			and _test_zone_controller.is_in_targeting_mode():
		_test_zone_controller._update_grenade_targeting_display()


func _on_view_h_toggled(_is_enabled: bool) -> void:
	_set_view_mode("heat", btn_view_h)


func _on_view_l_toggled(_is_enabled: bool) -> void:
	_set_view_mode("light", btn_view_l)


func _on_view_v_toggled(_is_enabled: bool) -> void:
	_set_view_mode("dev", btn_view_v)


func _update_guard_los_data() -> void:
	var blocked_edges := enemy_phase_controller.build_blocked_edge_set(
		_current_blocked_edges
	)
	for guard in _guards:
		if is_instance_valid(guard):
			guard.set_los_data(_blocked_cells, blocked_edges, _room_size, _shadow_tiles)


func _draw_exit_markers() -> void:
	## Purple diamond on each segment exit tile.
	## Drawn in the Room node's _draw() — renders below fog_of_war.
	## Revealed naturally when the FOW uncovers the area. Visible in DEV_VISION
	## because the fog is hidden (fog_of_war.visible = false).
	if _exit_cells.is_empty():
		return
	for cell: Vector2i in _exit_cells:
		var world := _world_center_for_cell(cell)
		var hw := 90.0
		var hh := 45.0
		var pts := PackedVector2Array([
			world + Vector2(0.0, -hh),
			world + Vector2(hw,  0.0),
			world + Vector2(0.0,  hh),
			world + Vector2(-hw, 0.0),
		])
		draw_colored_polygon(pts, Color(0.55, 0.10, 0.90, 0.28))
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.72, 0.25, 1.00, 0.82), 3.0
		)

func _draw_spawn_marker() -> void:
	## Dark diamond on the spawn point — DEV_VISION only.
	## Lets you quickly identify the AGENT_START_CELL when testing maps.
	if not _vision_controller.dev_vision:
		return
	if _agent_start_cell == INVALID_CELL:
		return
	var world := _world_center_for_cell(_agent_start_cell)
	var hw := 55.0
	var hh := 28.0
	var pts := PackedVector2Array([
		world + Vector2(0.0, -hh),
		world + Vector2(hw,  0.0),
		world + Vector2(0.0,  hh),
		world + Vector2(-hw, 0.0),
	])
	draw_colored_polygon(pts, Color(0.05, 0.05, 0.05, 0.45))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.22, 0.22, 0.22, 0.80), 2.0
	)


func _draw_playable_boundary() -> void:
	## Linha vermelha fina ao redor da área JOGÁVEL (excluindo o buffer ring).
	## Visível apenas em DEV_VISION.
	if not _vision_controller.dev_vision:
		return
	if floor_layer == null or _base_layout.is_empty():
		return

	## playable_rect: Rect2i(offset, inner_size) — injetado pelo MapCompiler.
	## Fallback para _room_size inteiro quando não disponível (mapas legados).
	var pr: Rect2i = _base_layout.get("playable_rect", Rect2i(Vector2i.ZERO, _room_size))
	var origin: Vector2i = pr.position
	var size:   Vector2i = pr.size
	var off:    Vector2  = VISUAL_GRID_OFFSET

	var n: Vector2 = floor_layer.map_to_local(origin) + off
	var e: Vector2 = floor_layer.map_to_local(origin + Vector2i(size.x, 0)) + off
	var s: Vector2 = floor_layer.map_to_local(origin + size) + off
	var w: Vector2 = floor_layer.map_to_local(origin + Vector2i(0, size.y)) + off

	draw_polyline(
		PackedVector2Array([n, e, s, w, n]),
		Color(1.0, 0.15, 0.15, 0.90),
		2.5,
		true
	)

## Artistic shadow spill: a full-shadow tile bleeds a soft halo onto its neighbours.
## COSMETIC only — never feeds gameplay (detection reads ExposureSystem), so the spill
## has no hiding value. Shaped two ways:
##   • density — denser real-shadow clusters (e.g. tall crate stacks) push the halo out
##     one extra ring per SHADOW_SPILL_DENSITY_STEP neighbours, up to SHADOW_SPILL_MAX_RADIUS.
##   • direction — orthogonal spill tiles read slightly darker than diagonal ones, which
##     softens the hard concentric rings.
## All tunable (var, not gameplay stat). See _compute_shadow_spill / _spill_color.
## MOVED TO: WorldMarkersOverlayController
var SHADOW_SPILL_MAX_RADIUS: int = 4        ## hard cap on density-extended reach
var SHADOW_SPILL_DENSITY_STEP: int = 2      ## +1 ring per this many clustered full cells
var SHADOW_SPILL_BASE_DARKEN: float = 0.18  ## ring-1 orthogonal darkening (1 - keeps)
var SHADOW_SPILL_FALLOFF: float = 0.5       ## darkening multiplier per further ring
var SHADOW_SPILL_DIAGONAL_FACTOR: float = 0.65  ## diagonal keeps lighter than orthogonal

## Paint the always-on world shadow layer from the geometric exposure result.
## MOVED TO: WorldMarkersOverlayController.repaint_world_shadows()


## Build the cosmetic spill halo around the FULL-shadow tiles.
## MOVED TO: WorldMarkersOverlayController._compute_shadow_spill()


## Spill reach (ring count) for a full cell: base radius + 1 per density step of clustered
## MOVED TO: WorldMarkersOverlayController._spill_reach_for()


## Multiply tint for a spill cell at ring `level` (1 = closest), orthogonal or diagonal.
## MOVED TO: WorldMarkersOverlayController._spill_color()


func _on_ap_changed(current_ap: int, max_ap: int) -> void:
	_hud_controller.update_ap(current_ap, max_ap, turn_manager.is_enemy_phase)
	movement_overlay.set_remaining_ap(current_ap)
	if not agent.is_moving:
		_refresh_tactical_state()
	
	if current_ap == 0 and not turn_manager.is_enemy_phase:
		_peek_pending = false


## Peek mechanic: look past an adjacent obstacle without moving
func _try_peek(direction: Vector2i) -> void:
	if turn_manager.current_ap < 1:
		return
	
	var target_cell := agent.cell + direction
	if not _blocked_cells.has(target_cell):
		return # Peeking only makes sense against obstacles

	## Reveal 3 tiles ahead in the peek direction
	for i in range(1, 4):
		var peek_cell := agent.cell + direction * i
		if not _is_cell_inside_room(peek_cell):
			break
		_fow_controller.add_peek_reveal(peek_cell)
		
	turn_manager.consume_ap(1)
	_peek_active = true
	_peek_timer = 1
	_update_guard_los_data()


func _on_agent_move_started(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	selection_overlay.set_selected(to_cell)
	movement_overlay.clear_overlay()
	path_preview.clear_path()


func _on_agent_step_finished(step_cell: Vector2i) -> void:
	_fow_controller.reveal_around(step_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Dev 04: register trail — last position when stepping in
	if _agent_trail.is_empty() or _agent_trail.back() != step_cell:
		_agent_trail.append(step_cell)
		if _agent_trail.size() > TRAIL_MAX:
			_agent_trail.pop_front()

	if _vision_controller.dev_vision and _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## M2-04: Generate noise per tic — roll the dice on each step
	if _noise_system != null:
		if randf() < NoiseSystem.NOISE_CHANCE_WALK:
			_noise_system.emit(step_cell, NoiseSystem.NOISE_INTENSITY_WALK)
		if _noise_overlay != null:
			_noise_overlay.queue_redraw()

	## OCC-01: Recompute occlusion set on agent step
	_recompute_occlusion()

	## M2-05: Immediate auditory detection after generating noise
	_process_audio_detection()

	## Detection tic — the agent crossed an edge
	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var result: TicSystem.TicResult = TicSystem.evaluate(
			guard, step_cell, _blocked_cells, blocked_edges
		)
		_apply_tic_result(guard, result)

	## Process voxel system dirty flags (VOXEL-07)
	_tic_voxel_system()


## Wrapper: processes auditory detection for all guards
func _process_audio_detection() -> void:
	if _turn_controller != null:
		_turn_controller._process_audio_detection()
	elif _noise_system != null:
		var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(
			_current_blocked_edges
		)
		for guard in _guards:
			if not is_instance_valid(guard):
				continue
			for noise_tile in _noise_system.get_noisy_tiles():
				var intensity: float = _noise_system.get_intensity(noise_tile)
				if intensity <= 0.0:
					continue
				var perceived: float = TicSystem.evaluate_audio(
					guard, noise_tile, intensity, blocked_edges
				)
				if perceived > 0.0:
					guard.hear_noise(noise_tile, perceived)


## Wrapper: processes the result of a detection tic for a guard
func _apply_tic_result(guard, result: TicSystem.TicResult) -> void:
	if _turn_controller != null:
		_turn_controller._apply_tic_result(guard, result)
	else:
		## Fallback: accumulate or decay the guard's detection field
		if result.visible:
			guard.detection = clampf(
				guard.detection + result.raw_chance * TicSystem.DETECTION_GAIN_PER_TIC,
				0.0, 1.0
			)
		else:
			## Decay outside the cone
			var decay := _get_detection_decay(guard.state)
			guard.detection = clampf(guard.detection + decay, 0.0, 1.0)

		## M2-04: Noise amplifies detection if the guard already sees the tile
		if _noise_system != null:
			var noise_intensity: float = _noise_system.get_intensity(agent.cell)
			if noise_intensity > 0.0 and result.visible:
				var bonus: float = noise_intensity * 0.3
				guard.detection = clampf(guard.detection + bonus, 0.0, 1.0)

		if _vision_controller.dev_vision:
			guard.queue_redraw()

		## ID-01: Gradual threshold-based escalation — only when the agent is visible
		if result.visible:
			if guard.detection >= DETECTION_THRESHOLD_CHASE:
				guard.observe_player(true, 3, agent.cell)
				_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
				if _alert_meter >= _alert_max:
					_guard_coordinator._on_guard_alarmed(guard.cell)
			elif guard.detection >= DETECTION_THRESHOLD_ALERT:
				guard.observe_player(true, 2, agent.cell)
				_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
				if _alert_meter >= _alert_max:
					_guard_coordinator._on_guard_alarmed(guard.cell)
			elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
				guard.observe_player(true, 1, agent.cell)

		_update_alert_label()


## Processes detection decay based on guard state
func _get_detection_decay(state: String) -> float:
	match state:
		"patrol":
			return -0.15
		"suspicious":
			return -0.06
		"alert":
			return -0.04
		"chase":
			return -0.01
	return -0.10


## Processes the result of a detection tic for a guard.


func _on_agent_move_finished(_cell: Vector2i) -> void:
	_selected_cell = agent.cell
	selection_overlay.set_selected(agent.cell)
	
	## M2-10: Update cover
	agent.update_cover(_blocked_cells)
	
	_update_enemy_visibility()
	movement_overlay.set_remaining_ap(turn_manager.current_ap)
	if _pending_auto_end_turn:
		_pending_auto_end_turn = false
		turn_manager.end_turn()
		return
	_refresh_tactical_state()


func _refresh_tactical_state() -> void:
	movement_overlay.set_blocked_cells(_build_navigation_blocked_cells())
	movement_overlay.rebuild(agent.cell, turn_manager.get_max_move_points())
	_update_selected_preview()
	_update_enemy_visibility()
	_update_movement_highlight()





## ID-02: Full memory flush — resets all state when the room needs to restart
func _reset_room_state() -> void:
	## Zero the global alert
	_alert_meter = 0

	## Reset the agent position
	agent.set_cell(_agent_start_cell)
	_selected_cell = _agent_start_cell
	selection_overlay.set_selected(_agent_start_cell)

	## Reset all guards to their starting routes
	for guard in _guards:
		if is_instance_valid(guard):
			guard.reset_to_route_start()

	## Clear the agent trail
	_agent_trail.clear()

	## Reset FOW
	_fow_controller.reset_fog()
	_fow_controller.reveal_around(_agent_start_cell, FOW_REVEAL_RADIUS + vision_bonus_tiles)

	## Clear the noise system
	if _noise_system != null:
		_noise_system.clear()

	## Reset visual overlays
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	if _trail_overlay != null:
		_trail_overlay.queue_redraw()

	## Center the camera on the agent
	_center_camera(agent.cell)

	## Force UI update
	_update_alert_label()


func _get_all_guards() -> Array:
	## Returns all GuardEnemy children in the enemies_root node.
	var result: Array = []
	for child in enemies_root.get_children():
		if child is GuardEnemy:
			result.append(child)
	return result


func _update_dev_hover_label() -> void:
	if _dev_hover_label == null:
		return

	_dev_hover_label.visible = _vision_controller.dev_vision

	if not _vision_controller.dev_vision or _hovered_cell == INVALID_CELL:
		return

	var cell := _hovered_cell
	var info := "tile  %d , %d" % [cell.x, cell.y]
	info += "\nblocked: %s" % ("yes" if _blocked_cells.has(cell) else "no")

	## Lighting / shadow semantics (ExposureSystem)
	var exposure = _lighting_controller.get_exposure_system()
	if exposure != null:
		info += "\nlight: %s" % exposure.get_tile_debug_info(cell)
		info += "\nshadow: depth %d · %s · conf %.2f" % [
			exposure.get_shadow_depth(cell),
			exposure.get_shadow_stability(cell),
			exposure.get_exposure_confidence(cell)]

	if _exit_cells.has(cell):
		info += "\nexit tile"

	for light in _current_light_sources:
		if int(light.get("x", 0)) == cell.x and int(light.get("y", 0)) == cell.y:
			info += "\nlight source (r%d)" % int(light.get("radius", 0))
			break

	for guard in _guards:
		if is_instance_valid(guard) and guard.cell == cell:
			info += "\nguard: %s  [%s]" % [guard.enemy_id, guard.state]

	if agent.cell == cell:
		info += "\nagent here"

	_dev_hover_label.text = info


func _spawn_guards(enemy_defs: Array) -> void:
	for child in enemies_root.get_children():
		child.queue_free()
	_guards.clear()

	for i in range(enemy_defs.size()):
		var entry: Dictionary = enemy_defs[i]
		var route: Array[Vector2i] = []
		for c in entry.get("route", []):
			route.append(c)
		if route.size() < 2:
			continue

		var guard = GuardEnemyClass.new()
		enemies_root.add_child(guard)
		guard.setup(
			floor_layer,
			VISUAL_GRID_OFFSET,
			String(entry.get("id", "guard_%d" % (i + 1))),
			route,
			int(entry.get("start_index", 0))
		)
		
		## CHARACTER Part 7: the baked enemy figure, same swap the agent took.
		## Idempotent and non-fatal — a guard with no bake keeps its vector
		## diamond rather than vanishing from the map mid-mission.
		if not guard.attach_sprite(self):
			push_warning("[Room] guard '%s' has no baked figure — run "
				% guard.enemy_id
				+ "p1_agent_model.py with P1_PALETTE=enemy, then "
				+ "p3_posture_export.py and agent_frame_bake_spike.gd")
		_guard_coordinator.register_guard(guard)
		_guards.append(guard)

	_update_enemy_visibility()


func _build_navigation_blocked_cells() -> Array[Vector2i]:
	var nav: Array[Vector2i] = _get_blocked_cells_array()
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.cell == agent.cell:
			continue
		nav.append(guard.cell)
	return nav


func _is_guard_cell(cell: Vector2i) -> bool:
	for guard in _guards:
		if is_instance_valid(guard) and guard.cell == cell:
			return true
	return false





## Utility: converts a cell coordinate to world position
func _world_center_for_cell(cell: Vector2i) -> Vector2:
	return floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET


## Wrapper: updates the HUD alert label from alert meter value
## VL-02a — put the overhead light fixtures and their ray shafts above the whole
## voxel stack (they are drawn at ceiling_lift, i.e. above it on screen) while
## staying below the agent-adjacent dev overlays. Null-guarded: load_map() runs
## once from _ready() BEFORE these overlays are constructed.
func _apply_overhead_overlay_z(max_voxel_z_index: int) -> void:
	if _light_ray_overlay != null:
		_light_ray_overlay.z_index = max_voxel_z_index + 2
	if _shrapnel_overlay != null:
		_shrapnel_overlay.z_index = max_voxel_z_index + 5
	## T-Z (Director, 2026-08-10): "os raios laranjas precisam ficar por cima do
	## perímetro vermelho. A granada virtual fica por cima dos raios."
	##
	## The aiming overlays take ABSOLUTE slots rather than `max_voxel_z_index + n`,
	## and that is the fix rather than a tidy-up. `_blast_wireframe_overlay` — the
	## red footprint — has always sat at the flat 100 of the "UI above everything"
	## tier (see QUICK_REFERENCE's z table), while these were riding a few ticks
	## above the tallest voxel, which on this map is nowhere near 100. So the
	## footprint drew over the rays no matter what order the ticks were in. Now
	## the whole aiming stack lives in that same tier, in the order it is read:
	## footprint, perimeter, dome, rays, arc, grenade.
	if _throw_perimeter_overlay != null:
		_throw_perimeter_overlay.z_index = AIM_Z_PERIMETER
	if _aim_bubble_overlay != null:
		_aim_bubble_overlay.z_index = AIM_Z_DOME
	if _shrapnel_preview_overlay != null:
		_shrapnel_preview_overlay.z_index = AIM_Z_RAYS
	if _throw_arc_overlay != null:
		_throw_arc_overlay.z_index = AIM_Z_ARC
	if _target_cursor_overlay != null:
		_target_cursor_overlay.z_index = AIM_Z_GRENADE
	if _ceiling_overlay != null:
		_ceiling_overlay.z_index = max_voxel_z_index + 3
	## VL-D4: the glow must draw above whichever voxel face it's decorating —
	## same reasoning as the two overlays above. Its exact tick is assigned below,
	## with the flash, since E-NATIVE-01 made the two order-dependent.
	## VFX-01: smoke/sparks are the same "always above the geometry" family as
	## the ember glow — one tick higher so it never competes with ember for a
	## pixel. Debris (dust/chips) is deliberately NOT in this overhead band:
	## it's meant to read as sitting on the ground, not floating above every
	## wall, so it gets a fixed floor-level z instead (see _ready()/OCC-03).
	if _smoke_spark_overlay != null:
		_smoke_spark_overlay.z_index = max_voxel_z_index + 6
	## E-NATIVE-01 (2026-08-09): the flash sits BELOW ember/smoke now, not above.
	## It was on top while it was a white wash meant to cover everything the blast
	## did, VFX included. The negative flash inverts what is under it — so with the
	## blast's core built from real embers and sparks, putting it on top turned the
	## fire BLUE (observed directly, first capture after the switch). The world is
	## what gets blown out by the blast; the fire is the thing doing the blowing
	## out, and it must not be inverted along with everything else.
	##
	## P-DARKFIRE (Director, 2026-08-09, after seeing the filmstrip) — **the
	## paragraph above is deliberately overruled for the NEGATIVE layer only:**
	## "o fogo precisa ser escuro no flash negativo." A negative frame that
	## exempts the brightest thing on screen does not read as a negative frame.
	## The overlay itself stays at +4 (so the WHITE frame still draws under the
	## fire and does not erase it), and only the negative quad is lifted above
	## ember (+5) and smoke (+6). If a future capture shows the fire reading BLUE
	## rather than DARK, that is E-NATIVE-01's original objection resurfacing and
	## it is a Director call, not a bug to quietly revert.
	if _explosion_flash_overlay != null:
		_explosion_flash_overlay.z_index = max_voxel_z_index + 4
		_explosion_flash_overlay.set_negative_z_index(max_voxel_z_index + 7)
	if _ember_overlay != null:
		_ember_overlay.z_index = max_voxel_z_index + 5


## VFX-01: dispatch VoxelRenderer.voxel_destroyed to the smoke/spark/debris
## overlays. Ember keeps its own separate trigger (TestZoneController's
## freshly-scorched-neighbour loop) — that condition ("survives next to a
## fresh hole") is different from "this voxel was destroyed", so it isn't
## folded in here. Fires for both blast and firearm destruction — both paths
## emit the same signal (VoxelRenderer.process_dirty()/process_dirty_slabs()).
## VFX-01 — dispatch smoke/dust/sparks/chips immediately when voxels are destroyed.
## D-ARCH-01: No buffering needed — damage applies in a single frame via tile swap,
## so VFX is dispatched directly as the voxel_destroyed signal fires.
func _on_voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String) -> void:
	_vfx_destroy_count += 1
	_dispatch_destruction_vfx(grid_pos, level, material_id)


## DIAGNOSTIC (2026-08-19). Counts voxel_destroyed dispatches so a capture can
## prove whether a shot re-fires VFX for voxels an EARLIER grenade already
## destroyed. Kept because the count is the only honest way to tell "the smoke
## looks wrong" apart from "the smoke IS wrong": the effect is transient and a
## screenshot of it cannot be compared against anything.
var _vfx_destroy_count: int = 0


func _vfx_count_take() -> int:
	var n := _vfx_destroy_count
	_vfx_destroy_count = 0
	return n


## E-NATIVE-01 (Director, 2026-08-09) — the detonation's visible core, built from
## this game's OWN vfx vocabulary instead of an imported sprite sheet.
##
## The Director's read on the authored 4-frame fireball was that its comic style
## "não combina com o resto do cenário", and asked whether Godot had something
## more integrated. The honest answer turned out not to be a Godot feature at all:
## this project already owns every piece needed — EmberOverlay's warm fading glow,
## SmokeSparkOverlay's puffs and sparks, DebrisOverlay's dust. A blast assembled
## from those is integrated by construction, because it is literally the same
## material every other effect on screen is made of. Nothing here is new
## machinery; it is four calls to overlays that already existed.
##
## Deliberately NOT a particle system: GPUParticles2D would be the native route
## for something this project did not already have, but adding one here would
## introduce a second, parallel VFX vocabulary right next to the one that already
## reads correctly. Revisit only if these overlays run out of expressiveness.
##
## PURELY VISUAL, like every overlay it drives — losing a burst to a reload costs
## nothing.
func spawn_blast_burst(world_pos: Vector2) -> void:
	if _ember_overlay != null:
		## The core: a tight cluster of embers rather than one big glow, so it
		## flickers and cools unevenly the way the per-voxel scorch already does.
		##
		## P-FIRE (Director, 2026-08-09): "o fogo está praticamente parado no
		## lugar. A gente quer que ele comece menor, do tamanho da granada, bem
		## em cima dela, e se expanda rapidamente, pra cima e em todas as
		## direções em volta (pra baixo não muito por causa do chão), se
		## dissipando para fora."
		##
		## So the cluster is no longer scattered across its final radius at
		## t=0 — it is born grenade-sized and THROWN outward. Every ember starts
		## inside `blast_burst_ember_start_radius_px` and carries a velocity;
		## `blast_burst_ember_spread_px` stopped being a spawn radius and is now
		## the reach the expansion aims for, which is the whole difference
		## between a puff that appears and a fireball that blooms.
		##
		## E-AUDIT (2026-08-13): and that made it a field NO CODE READS — the
		## reach is an emergent property of `speed / drag`, and the "relationship
		## worth preserving when retuning" recorded at the declaration was
		## enforced by a comment alone. That is the `slab_full_color` shape
		## exactly (E-SEAM-03: a documented field silently disagreeing with what
		## the code does), and the retune two commits ago walked right past it.
		## An `assert` makes the relationship real at zero release cost — Godot
		## strips these from release builds, which is the project's stated use
		## for them. It changes no pixel; it just stops the next retune from
		## drifting speed/drag away from the reach the comment claims.
		assert(blast_burst_ember_speed_min / maxf(blast_burst_ember_drag, 0.001)
				<= blast_burst_ember_spread_px
			and blast_burst_ember_speed_max / maxf(blast_burst_ember_drag, 0.001)
				>= blast_burst_ember_spread_px,
			"[Room] blast burst reach (speed/drag) no longer straddles blast_burst_ember_spread_px — see P-FIRE")
		for i in range(blast_burst_ember_count):
			## Golden-angle stepping rather than i/count around a circle: at
			## these counts an even sweep visibly reads as spokes once the
			## embers start travelling outward along their own angle, because
			## the eye follows the motion and the gaps become rays.
			var ground_angle: float = float(i) * PI * (3.0 - sqrt(5.0))
			## GROUND and ALTITUDE are different axes in an isometric view, and
			## conflating them is what made the first pass at this spread
			## sideways instead of blooming (real filmstrip, 2026-08-09): a
			## single squashed 2D circle makes "up" merely the NORTH direction
			## of the ground plane, at HALF the horizontal rate. Altitude is not
			## north — it is straight up the screen, unsquashed. So each ember
			## gets a direction around the ground plane AND an elevation:
			##   ground → x full, y × 0.5 (the diamond's own foreshortening)
			##   altitude → pure −y, no squash
			## which is what "pra cima e em todas as direções em volta" asks for.
			var elev: float = deg_to_rad(randf_range(
				-blast_burst_ember_down_deg, blast_burst_ember_up_deg))
			var ce: float = cos(elev)
			var dir := Vector2(
				cos(ground_angle) * ce,
				sin(ground_angle) * ce * BLAST_ISO_GROUND_SQUASH - sin(elev))
			var start := world_pos + dir * blast_burst_ember_start_radius_px
			var speed: float = randf_range(blast_burst_ember_speed_min,
				blast_burst_ember_speed_max)
			_ember_overlay.add_ember(start,
				randf_range(blast_burst_ember_life_min, blast_burst_ember_life_max),
				dir.normalized() * speed,
				blast_burst_ember_drag,
				blast_burst_ember_rise_px_s * randf_range(
					1.0 - blast_burst_ember_rise_jitter,
					1.0 + blast_burst_ember_rise_jitter))
	if _smoke_spark_overlay != null:
		_smoke_spark_overlay.add_sparks(world_pos, blast_burst_spark_count, blast_burst_spark_color)
	if _debris_overlay != null:
		## Dust falls toward the floor under the blast, the same origin→target
		## shape VFX-01's per-voxel dust already uses.
		var floor_pos: Vector2 = world_pos + Vector2(0.0, blast_burst_dust_drop_px)
		for _d in range(blast_burst_dust_count):
			_debris_overlay.add_dust(world_pos, floor_pos, blast_burst_dust_color)


## E-MUZZLE-01 (Director, 2026-08-13): *"as armas de fogo também precisam de um
## clarão e uma fumacinha na ponta quando disparam. Nós ainda precisamos fazer
## os sprites com o agente empunhando a arma, mas de qualquer forma já vamos
## deixar a física pronta nos modelos da bancada."*
##
## So this is deliberately built against a MUZZLE POSITION AND A DIRECTION, not
## against the bench prop. The bench weapon is the only caller today; an agent
## holding a rifle will pass its own hand position and facing and get the
## identical effect with no new code.
##
## BUILT FROM THIS PROJECT'S OWN OVERLAYS, not from the reference sheets the
## Director shared. Those are authored sprite sheets, and E-NATIVE-01 is the
## ratified precedent: the imported 4-frame fireball was REMOVED because its
## style did not fit, and the blast's core was rebuilt out of ember/spark/smoke.
## A muzzle flash assembled the same way is integrated by construction — it is
## literally the same material every other effect on screen is made of. The
## reference images informed the SHAPE (a bright core, a forward cone of sparks,
## a soft puff hanging where the core was), not the pixels.
##
## Three beats, all sub-second: the flash itself (a very short, bright ember
## with no rise — a muzzle flash does not float), a forward spark cone, and one
## small puff that lingers after both are gone.
var muzzle_flash_count: int = 8             ## embers forming the core
## 0.09 -> 0.17 -> 0.30. Twice now the honest instinct ("a flash is brief") has
## lost to what the Director actually sees on screen: *"não consigo ver o clarão
## na frente das armas, tenta deixar ele ativo mais um frame."* At 60 fps 0.30 s
## is ~18 frames, which still reads as an instant next to a 0.85 s spark, and it
## is the number the eye needs rather than the number physics suggests.
var muzzle_flash_life: float = 0.30         ## seconds — a flash, not a fire
var muzzle_flash_spread_px: float = 7.0
var muzzle_flash_forward_px: float = 9.0    ## how far the core sits ahead of the muzzle
var muzzle_spark_count: int = 14
var muzzle_spark_cone_deg: float = 26.0     ## half-angle of the forward spray
var muzzle_spark_color: Color = Color(1.0, 0.93, 0.66, 1.0)
## E-MUZZLE-02 (Director): *"preferencialmente um cinza mais claro."* Powder
## smoke is pale, not the dark carbon a burning wall throws.
var muzzle_smoke_color: Color = Color(0.88, 0.87, 0.84, 0.34)
## E-MUZZLE-02 (Director): *"tem que ser mais pra frente... e se dissipar
## logo."* The puff moved BEHIND the barrel in E-MUZZLE-01 for a real reason —
## SmokeSparkOverlay draws one tick ABOVE EmberOverlay
## (_apply_overhead_overlay_z()), so a puff centred on the flash paints a dark
## disc over its core, which is exactly what the first muzzle print showed. The
## fix is not to move it back again but to move it FORWARD, PAST the flash: it
## clears the core on the far side instead of hiding behind the gun.
##
## `drift_scale` and `duration_scale` are what make it powder smoke rather than a
## plume — it barely rises and it is gone quickly, instead of climbing the screen
## for a second and a half like a crater's.
var muzzle_smoke_scale: float = 0.7
var muzzle_smoke_puffs: int = 2
var muzzle_smoke_forward_px: float = 22.0   ## past the flash core, not behind the gun
var muzzle_smoke_duration_scale: float = 0.35
var muzzle_smoke_drift_scale: float = 0.22
## The puff waits for the flash — and waits for ALL of it. 0.75 was chosen so the
## two would "overlap for an instant"; that instant is precisely what the capture
## showed as a dark hole. Pale grey in NORMAL blend drawn over an ADDITIVE flash
## reads as a hole in it, however light the grey, so there is no overlap value
## that looks right. 1.0 = the smoke starts as the flash ends.
var muzzle_smoke_delay_factor: float = 1.0
## The core is a FLASH, not a coal: EmberOverlay.glow_radius is tuned to 9 px for
## the crater's per-voxel embers, which is the wrong size by an order of
## magnitude for a barrel. See EmberOverlay.add_ember()'s `radius_scale`.
var muzzle_flash_radius_scale: float = 2.0


## Fire one muzzle flash at `muzzle_pos`, pointing along `direction` (a screen/
## world-space vector; it is normalized here). Purely visual, same contract as
## every other overlay call in this file.
func spawn_muzzle_flash(muzzle_pos: Vector2, direction: Vector2) -> void:
	var dir: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	if _ember_overlay != null:
		## No velocity and no rise: the core sits at the barrel for its 90 ms and
		## goes. Giving it the burst's buoyancy would make a gunshot bloom like a
		## small explosion, which is the opposite of the read.
		for i in range(muzzle_flash_count):
			var lateral: Vector2 = Vector2(-dir.y, dir.x) * randf_range(
				-muzzle_flash_spread_px, muzzle_flash_spread_px) * 0.5
			var at: Vector2 = muzzle_pos + dir * randf_range(
				0.0, muzzle_flash_forward_px) + lateral
			## cool_rate 0.0 — a flash does not cool, it ends. See add_ember().
			## smoke_on_death FALSE: a flash leaves powder smoke (spawned below,
			## pale and forward), never a coal's dark burn-out puff.
			_ember_overlay.add_ember(at, muzzle_flash_life * randf_range(0.7, 1.3),
				Vector2.ZERO, 0.0, 0.0, 1.0, 0.0, muzzle_flash_radius_scale, 0.0, false)
	if _smoke_spark_overlay != null:
		## The forward spray. add_sparks() throws a full circle, so the cone is
		## built here by placing each spark's own start point along the barrel
		## line — cheap, and it keeps SmokeSparkOverlay free of weapon geometry
		## it has no business knowing.
		for i in range(muzzle_spark_count):
			var a: float = deg_to_rad(randf_range(-muzzle_spark_cone_deg, muzzle_spark_cone_deg))
			var spread: Vector2 = dir.rotated(a)
			_smoke_spark_overlay.add_sparks(
				muzzle_pos + spread * randf_range(2.0, muzzle_flash_forward_px * 1.6),
				1, muzzle_spark_color)
		for j in range(muzzle_smoke_puffs):
			_smoke_spark_overlay.add_smoke(
				muzzle_pos + dir * randf_range(
					muzzle_flash_forward_px, muzzle_smoke_forward_px),
				muzzle_smoke_color, muzzle_smoke_scale,
				muzzle_smoke_duration_scale, 0, muzzle_smoke_drift_scale,
				muzzle_flash_life * muzzle_smoke_delay_factor)


## E-SPARK-01 — VFX for a voxel that was HIT but survived (DENTED/CRACKED).
##
## The counterpart to `_dispatch_destruction_vfx()`, and deliberately a separate
## entry point rather than a branch inside it: that one is signal-driven off
## `voxel_destroyed`, which by definition never fires for a survivor. Callers
## pass the material because a `Voxel` does not carry one (it lives on the
## Slice/Slab), exactly as the destruction path's signal does.
##
## PUBLIC because the caller is `WeaponBenchController.fire_active()`, which is
## the only place that knows which voxels a shot just marked — the same shape as
## the blast, where the plan knows what it damaged and the choreographer plays
## it. No new signal: a signal would have to be emitted from the render pass,
## which re-renders dirty voxels for reasons that have nothing to do with being
## freshly shot.
func dispatch_impact_vfx(grid_pos: Vector2i, level: int, material_id: String) -> void:
	if _voxel_renderer == null or _smoke_spark_overlay == null or _debris_overlay == null:
		return
	var profile: Dictionary = vfx_impact_profiles.get(material_id, {})
	if profile.is_empty():
		return
	var origin: Vector2 = _voxel_renderer.voxel_world_position(grid_pos, level)
	var floor_pos: Vector2 = _voxel_renderer.voxel_world_position(grid_pos, 0)
	if floor_pos == Vector2.ZERO:
		floor_pos = origin

	var spark_count: int = int(profile.get("sparks", 0))
	if spark_count > 0:
		var jittered: int = maxi(1, int(round(float(spark_count) * randf_range(
			1.0 - vfx_impact_spark_jitter, 1.0 + vfx_impact_spark_jitter))))
		_smoke_spark_overlay.add_sparks(origin, jittered,
			vfx_metal_spark_color if material_id == "metal" else vfx_stone_spark_color,
			vfx_surface_spark_speed_scale, vfx_surface_spark_duration_scale)
	if bool(profile.get("smoke", false)):
		_smoke_spark_overlay.add_smoke(origin, _vfx_smoke_color_for_material(material_id))
	if bool(profile.get("dust", false)) and randf() < vfx_dust_chance:
		_debris_overlay.add_dust(origin, floor_pos, _vfx_material_base_color(material_id))
	var chips: int = int(profile.get("chips", 0))
	if chips > 0:
		_debris_overlay.add_chips(origin, floor_pos, chips,
			_vfx_material_base_color(material_id))


func _dispatch_destruction_vfx(grid_pos: Vector2i, level: int, material_id: String) -> void:
	if _voxel_renderer == null or _smoke_spark_overlay == null or _debris_overlay == null:
		return
	var origin: Vector2 = _voxel_renderer.voxel_world_position(grid_pos, level)
	var floor_pos: Vector2 = _voxel_renderer.voxel_world_position(grid_pos, 0)
	if floor_pos == Vector2.ZERO:
		floor_pos = origin

	_smoke_spark_overlay.add_smoke(origin, _vfx_smoke_color_for_material(material_id))

	if vfx_dust_materials.has(material_id) and randf() < vfx_dust_chance:
		var dust_color: Color = _vfx_material_base_color(material_id)
		_debris_overlay.add_dust(origin, floor_pos, dust_color)

	if material_id == "metal" and randf() < vfx_spark_chance:
		_smoke_spark_overlay.add_sparks(origin, randi_range(vfx_metal_spark_count_min, vfx_metal_spark_count_max), vfx_metal_spark_color)
	elif material_id == "stone" and randf() < vfx_spark_chance:
		_smoke_spark_overlay.add_sparks(origin, vfx_stone_spark_count, vfx_stone_spark_color)

	if material_id == "wood" and randf() < vfx_chip_chance:
		var wood_color: Color = _vfx_material_base_color(material_id)
		_debris_overlay.add_chips(origin, floor_pos, randi_range(vfx_chip_count_min, vfx_chip_count_max), wood_color)


## VFX-01: MaterialDef.base_color for `material_id`, or a neutral gray if the
## material has no registry entry (e.g. "earth" — resistance-table-only, see
## material_resistance_table.gd).
func _vfx_material_base_color(material_id: String) -> Color:
	var mat_def = Registries.get_material_registry().get_material(material_id)
	return mat_def.base_color if mat_def != null else Color(0.6, 0.6, 0.6)


## E-SMOKE-TINT-01 (2026-08-13) — the same per-material tints VFX-01 gives
## firearm destruction, resolved once per detonation as `{material_id: Color}`
## for DetonationChoreographer to look up per smoke entry.
##
## It lives here, and is passed in, because `DetonationPlanBuilder` is static and
## runs headless in selftests where the `Registries` autoload does not exist —
## the plan therefore carries the material ID and never the colour. Built from
## the registry's whole roster (not just this blast's materials) because it is a
## handful of entries and this way one map's cached plan can never be replayed
## against a map whose materials the map has since changed.
##
## Only the HUE is consumed downstream; the choreographer keeps SMOKE_COLOR's own
## alpha, for the reason spelled out at its call site.
func blast_smoke_tints() -> Dictionary:
	var tints: Dictionary = {}
	var registry = Registries.get_material_registry()
	if registry == null:
		return tints
	for material_id in registry.list_materials():
		tints[material_id] = _vfx_smoke_color_for_material(material_id)
	return tints


## E-DEBRIS-01 — which materials throw what, and how often, as plain DATA for
## `DetonationPlanBuilder` to gate on. The material→effect mapping is room
## policy, not builder knowledge, so it travels in `ctx` exactly the way
## `blast_soot_rings` does; the builder stays generic and testable.
##
## Rates are the firearm ones scaled — see `blast_debris_rate_scale` for why
## that unit conversion is the whole point rather than a tidy-up.
func blast_debris_policy() -> Dictionary:
	var s: float = blast_debris_rate_scale
	return {
		"dust": {
			"materials": vfx_dust_materials,
			"chance": vfx_dust_chance * s,
			"count_min": 1, "count_max": 1,
		},
		"sparks": {
			## E-SPARK-02: the Director's ladder, per material — "cimento só um
			## pouquinho, metal bastante, pedra médio, madeira não". `per_material`
			## overrides the shared count range where a row exists; the shared
			## range stays as the fallback so the rule is still readable without
			## it, and so the selftest's own simpler policy keeps working.
			"materials": ["metal", "stone", "concrete"],
			"chance": vfx_spark_chance * s,
			"count_min": vfx_metal_spark_count_min,
			"count_max": vfx_metal_spark_count_max,
			"per_material": {
				"metal": [7, 13],
				"stone": [3, 6],
				"concrete": [1, 2],
			},
		},
		"chips": {
			## Splinters — combustible-looking material, but keyed on the
			## material list rather than on `flammability`, because a chip is
			## about how a material BREAKS, not whether it burns. Glass will
			## want chips and no ember; that stays expressible.
			##
			## Director, 2026-08-21: *"Pode pôr lascas só no madeirite. Papelão
			## não."* Plywood is wood in sheets and splinters like it; cardboard
			## tears into flaps, which is a different debris shape and does not
			## get this effect just for being soft. That the list is a list —
			## and not `flammability > 0` — is precisely what lets those two
			## soft materials disagree here.
			"materials": ["wood", "plywood"],
			"chance": vfx_chip_chance * s,
			"count_min": vfx_chip_count_min,
			"count_max": vfx_chip_count_max,
		},
	}


## E-DEBRIS-01 — `{"<effect>:<material>": Color}` for the choreographer, resolved
## here for the same reason `blast_smoke_tints()` is: `DetonationPlanBuilder` is
## static and runs headless in selftests where the `Registries` autoload does not
## exist, so the plan carries the material id and never the colour.
func blast_debris_palette() -> Dictionary:
	var palette: Dictionary = {}
	var registry = Registries.get_material_registry()
	if registry == null:
		return palette
	for material_id in registry.list_materials():
		## Dust and chips take the material's own colour (VFX-01's own choice:
		## masonry throws masonry-coloured dust, wood throws wood-coloured
		## splinters). Sparks do NOT — a spark is incandescence, its colour comes
		## from the strike, not from the material's albedo.
		var base: Color = _vfx_material_base_color(material_id)
		palette["dust:%s" % material_id] = base
		palette["chips:%s" % material_id] = base
		palette["sparks:%s" % material_id] = \
			vfx_metal_spark_color if material_id == "metal" else vfx_stone_spark_color
	return palette


## VFX-01: smoke tint per material — darker/desaturated version of the
## material's own base color so wood reads as dark smoke and masonry/metal
## read as light smoke, per the Director's request.
func _vfx_smoke_color_for_material(material_id: String) -> Color:
	var base: Color = _vfx_material_base_color(material_id)
	var darken: float = vfx_smoke_darken_wood if material_id == "wood" else vfx_smoke_darken_default
	var smoke: Color = base.darkened(darken)
	smoke.a = vfx_smoke_alpha
	return smoke


## VL-01 — project the tactical lighting state onto voxel faces (6 buckets).
## Connected to lighting_rebuilt: runs on map load, perspective rotation and
## any light change. The field stays queryable on _voxel_light_field — the
## seam future vision modes (thermal / night / X-ray) will consume.
## PERF-03 — `geometry_only` is forwarded to VoxelLightField.build(); see its
## doc for the contract. Defaults false, so the `lighting_rebuilt` signal
## connection (which passes no arguments) keeps the full, unconditional rebuild.
## W-PRECOOK / §0 Route 2 — the SCOPED repaint, for a firearm.
##
## THE MEASUREMENT THAT PRODUCED THIS, because it contradicts the hypothesis it
## was asked for under. The Director's read was that a shot stalls because it is
## *"processando a destruição na parede"*. Instrumented on the real map:
##
##     [AGENT-SHOT-PROF] resolve+apply 1.32 ms · repaint 581.10 ms · 23 voxel(s)
##     [REPAINT-PROF] occupancy 28.4 · soot 141.4 · field.build 11.2 · apply 399.7
##
## Damage resolution is 1.3 ms — 0.2% of the shot. Pre-computing it, which is
## what the grenade's P-COOK does, would save nothing measurable. The cost is
## `apply_light_field()` walking every placed cell on a 44x22 board.
##
## VL-03 already built the scoped version and measured it (~75 ms against
## ~590 ms for a light toggle, 88% off); nothing had pointed the FIREARM at it.
## This does. `_placed_by_gu` is built by the last full pass, which the boot
## always runs, and a GU it does not know about is a silent no-op there by
## design — so the scope must be generous, and the soot reach is why it is.
## `include_soot=false` skips `_build_soot_snapshot()` entirely — the map-wide
## walk that measured 141 ms of the shot's remaining ~210. It is skippable at all
## only because of the Director's 2026-08-19 ruling: *"a fuligem pode ser
## processada depois do fato, desde que apareça com fade in, e não de repente."*
## Geometry and lighting are still exact; only the soot is missing, and
## `fade_in_scoped_soot()` below brings it in afterwards.
func _repaint_voxel_light_buckets_scoped(gus: Array, include_soot: bool = true,
		soot_lighten: int = 0) -> void:
	if gus.is_empty():
		_repaint_voxel_light_buckets(true)
		return
	if _voxel_renderer == null or _lighting_controller == null:
		return
	var registry = _lighting_controller.get_light_registry()
	if registry == null:
		return
	if _voxel_light_field == null:
		_voxel_light_field = VoxelLightField.new()
	var top_wall_level: int = maxi(_voxel_renderer.get_layer_count() - 1, 0)
	var soot_faces: Dictionary = {}
	## The FIELD is still built map-wide, and that is not laziness: D24 derives
	## soot from which voxels are absent ANYWHERE, so a scoped snapshot would be
	## a second soot producer — the exact drift SOOT_MASTER_PLAN §1.2 found
	## between two of them. Only the APPLY is scoped, which is where the time is.
	## The FIELD is still built map-wide when soot is included, and that is not
	## laziness: D24 derives soot from which voxels are absent ANYWHERE, so a
	## scoped snapshot would be a second soot producer — the exact drift
	## SOOT_MASTER_PLAN §1.2 found between two of them. Only the APPLY is scoped.
	var _sp: bool = OS.get_environment("INFILTRAITOR_REPAINT_PROFILE") == "1"
	var _s0: int = Time.get_ticks_usec()
	var soot: Dictionary = _build_soot_snapshot(soot_faces) if include_soot else {}
	var _s1: int = Time.get_ticks_usec()
	var occ: Dictionary = _voxel_renderer.build_occupancy()
	var _s2: int = Time.get_ticks_usec()
	_voxel_light_field.build(
			registry.get_active_lights(),
			_lighting_controller.get_shadow_results(),
			top_wall_level,
			occ,
			soot,
			_under_structure,
			soot_faces,
			true)
	var _s3: int = Time.get_ticks_usec()
	## W-TUNE-01: the same readout the map-wide repaint has always had, on the
	## path a SHOT actually takes. Without it the diagnostic answered a question
	## nobody was asking — it ran at boot, where there is no damage, and reported
	## "sooted voxels=0" for every shot ever fired through here.
	if include_soot and OS.get_environment("INFILTRAITOR_FACE_SOOT_DIAG") == "1":
		_print_face_soot_diagnostics(soot_faces)
	_voxel_renderer.apply_light_field_gus(_voxel_light_field, gus, soot_lighten)
	if _sp:
		print("[SCOPED-PROF] soot %.1f · occupancy %.1f · field.build %.1f · apply %.1f ms (%d GUs, soot=%s)"
			% [float(_s1 - _s0) / 1000.0, float(_s2 - _s1) / 1000.0,
			float(_s3 - _s2) / 1000.0,
			float(Time.get_ticks_usec() - _s3) / 1000.0, gus.size(), include_soot])
		print("[SCOPED-PROF]   cells written: %d · TileSet alternatives minted: %d"
			% [_voxel_renderer._scoped_writes, _voxel_renderer._alts_minted])
	## THE SCOPE GATE. A scoped repaint is only correct if it leaves the board in
	## the state a full one would have — the same class of claim PERF-03's
	## equivalence probe guards for incremental invalidation, and the same class
	## of drift SOOT_MASTER_PLAN §1.2 caught between two soot producers. This is
	## how the 581 -> 210 ms win is EARNED rather than asserted: snapshot every
	## cell's alternative, force the full apply, snapshot again, count. Env-gated
	## because it costs a full repaint on top of the scoped one.
	if OS.get_environment("INFILTRAITOR_SHOT_SCOPE_PROBE") == "1":
		var before: Dictionary = _perf_snapshot_alts()
		_voxel_renderer.apply_light_field(_voxel_light_field)
		var after: Dictionary = _perf_snapshot_alts()
		var differ: int = 0
		for k in after:
			if before.get(k, -12345) != after[k]:
				differ += 1
		print("[SHOT-SCOPE] %d cells checked, %d differ from a full apply (scope %d GUs)"
			% [after.size(), differ, gus.size()])


## How far a shot's repaint has to reach past the GUs it actually hit. D24
## derives soot up to 3 rings from an absent voxel, so a hole changes the look of
## cells three GUs away and a scope tighter than this leaves a visible seam.
const SHOT_REPAINT_SOOT_RINGS: int = 3


## How many rungs the deferred soot fades in over, and how many frames each rung
## holds. Mirrors DetonationChoreographer's `soot_fade_steps` /
## `soot_fade_frames_per_step` so a bullet's soot and a blast's arrive at the
## same rate — two fades at different speeds read as two different materials.
## A/B SWITCH, and it exists because the first answer was wrong. Deferring the
## soot cut the trigger frame's CPU but ADDED five stalls of 240-420 ms behind
## it — measured by frame, not by function, which is the measurement that should
## have been taken first. `INFILTRAITOR_SHOT_SOOT_DEFER=1` turns it back on.
var shot_soot_deferred: bool = OS.get_environment("INFILTRAITOR_SHOT_SOOT_DEFER") == "1"
var shot_soot_fade_steps: int = 4
var shot_soot_fade_frames_per_step: int = 2


## Bring the deferred soot in, across frames, WITHOUT blocking the shot.
##
## The field is built ONCE here (the expensive map-wide snapshot) and then
## applied `steps` times at descending `soot_lighten`. Rebuilding per step would
## cost more than never deferring, which is the trap this shape avoids.
##
## The first build is awaited on its own frame so the shot's own repaint has
## already been presented — deferring the work and then doing it in the same
## frame would move the stall, not remove it.
## The soot, once, after everything else. See the caller's note for why this is
## a single pass rather than a fade.
##
## The first frame is yielded first so the impact — tile swap, smoke — has been
## PRESENTED before this runs. Deferring the work and then doing it in the same
## frame would move the stall, not remove it; that mistake was made once already
## in this file's history.
func apply_scoped_soot(gus: Array) -> void:
	if gus.is_empty() or _voxel_renderer == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_voxel_renderer):
		return
	_repaint_voxel_light_buckets_scoped(gus, true, 0)


func fade_in_scoped_soot(gus: Array) -> void:
	if gus.is_empty() or _voxel_renderer == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_voxel_renderer):
		return
	var steps: int = maxi(shot_soot_fade_steps, 1)
	## Build once, at the FAINTEST rung, then walk down to full strength.
	_repaint_voxel_light_buckets_scoped(gus, true, steps - 1)
	print_debug("[SHOT-SOOT] fade starts — %d step(s) over %d GUs"
		% [steps, gus.size()])
	for step in range(steps - 2, -1, -1):
		for _f in range(maxi(shot_soot_fade_frames_per_step, 1)):
			await get_tree().process_frame
		if not is_instance_valid(_voxel_renderer):
			return
		## Re-APPLY only. `_voxel_light_field` still holds the sooty field the
		## line above built, so each rung is a scoped set_cell pass and not a
		## second map-wide snapshot.
		_voxel_renderer.apply_light_field_gus(_voxel_light_field, gus, step)
	## THE END-STATE GATE. Deferring soot is only legitimate if the board ENDS
	## where a full, immediate repaint would have put it — a fade that settles on
	## the wrong picture is worse than a stall. Same probe as the scoped apply's,
	## run at the bottom of the ladder where `soot_lighten` is 0.
	if OS.get_environment("INFILTRAITOR_SHOT_SCOPE_PROBE") == "1":
		var before: Dictionary = _perf_snapshot_alts()
		_voxel_renderer.apply_light_field(_voxel_light_field)
		var after: Dictionary = _perf_snapshot_alts()
		var differ: int = 0
		for k in after:
			if before.get(k, -12345) != after[k]:
				differ += 1
		print("[SHOT-SOOT] settled: %d cells checked, %d differ from a full apply"
			% [after.size(), differ])


## --- W-PRECOOK: the shot's pre-production --------------------------------
##
## Director, 2026-08-19: *"Quando o jogador selecionar algum alvo a gente já
## começa a calcular a destruição dos tiros. Mas se ele clicar em 'disparar' a
## gente só solta a animação depois que tudo estiver processado. É melhor dar o
## lag depois que clica no botão do que no meio da execução."*
##
## WHAT IS ACTUALLY PRE-COOKED, and it is not what the name suggests. The
## destruction itself resolves in 1.5 ms; pre-computing it saves nothing. The
## measured cost of a shot is **412 `create_alternative_tile()` calls** — the
## TileSet rebuild that lands on the impact frame and that no profiler inside
## the shot could see (see the SHOT-FILM measurements). So what this warms is the
## ALTERNATIVE CACHE, by building the light field for the world as it will be
## after the shot and touching every alternative that world will need.
##
## WHY IT IS SAFE TO DO SPECULATIVELY: minting is idempotent and cached in
## `_minted_light_alts`. A prediction that is wrong costs a cache miss, never a
## wrong picture — `_ensure_light_alt()` still mints on demand at apply time.
## Nothing is committed, nothing is drawn, and cancelling is just dropping it.
var _shot_precook_token: int = 0
var _shot_precook_done: bool = false
var _shot_precook_minted: int = 0


## Begin warming. Returns immediately; `await shot_precook_ready()` to join.
func begin_shot_precook(predict_destroyed: Dictionary, predict_damaged: Array,
		scope_gus: Array, variant_cells: Array = []) -> void:
	_shot_precook_token += 1
	_shot_precook_done = false
	_run_shot_precook(_shot_precook_token, predict_destroyed, predict_damaged,
		scope_gus, variant_cells)


func cancel_shot_precook() -> void:
	_shot_precook_token += 1
	_shot_precook_done = false


## Block until the warm finishes. The Director's *"o lag depois que clica no
## botão"* — this is where that lag lives, and it is only a lag at all when the
## player confirms faster than the warm completes.
func shot_precook_ready() -> void:
	var token: int = _shot_precook_token
	while not _shot_precook_done and token == _shot_precook_token:
		await get_tree().process_frame


func _run_shot_precook(token: int, predict_destroyed: Dictionary,
		predict_damaged: Array, scope_gus: Array, variant_cells: Array = []) -> void:
	if _voxel_renderer == null or _lighting_controller == null or scope_gus.is_empty():
		_shot_precook_done = true
		return
	var registry = _lighting_controller.get_light_registry()
	if registry == null:
		_shot_precook_done = true
		return
	## One frame first, so the menu that just opened gets to draw before this
	## starts. Warming inside the click's own frame would move the stall onto the
	## action that is supposed to hide it.
	await get_tree().process_frame
	if token != _shot_precook_token or not is_instance_valid(_voxel_renderer):
		return

	## ⚠️ THE SHARED FIELD, NOT A FRESH ONE. `VoxelLightField` invalidates
	## incrementally against its own previous state; a `new()` one has none and
	## rebuilds the whole map — measured at 1450 ms in the first version of this
	## warm, which is the boot repaint's cost paid inside the aim window.
	##
	## Reusing the live field is safe because nothing reads it between here and
	## the shot: `_repaint_voxel_light_buckets_scoped()` rebuilds it from real
	## state before the apply, so the predicted contents left here are always
	## overwritten before they can reach a pixel.
	if _voxel_light_field == null:
		_voxel_light_field = VoxelLightField.new()
	var field = _voxel_light_field
	var soot_faces: Dictionary = {}
	var top_wall_level: int = maxi(_voxel_renderer.get_layer_count() - 1, 0)
	var occupancy: Dictionary = _voxel_renderer.build_occupancy(predict_destroyed)
	var lights: Array = registry.get_active_lights()
	var shadows = _lighting_controller.get_shadow_results()

	## ⚠️ TWO WORLDS ARE WARMED, NOT ONE, AND BOTH IN THIS SAME FRAME.
	##
	## The shot now paints in two stages — the impact repaint runs WITHOUT soot
	## (the Director took it out of that frame entirely) and a later pass adds it.
	## Those two stages need DIFFERENT alternatives, because soot is part of the
	## alternative id. Warming only the sooty world left the impact minting 40 of
	## its own: a warm that predicts the wrong world is no warm at all.
	##
	## Both are minted here because the TileSet rebuild is charged once per FRAME
	## THAT MINTS — so two worlds in one frame cost one rebuild, and splitting
	## them across two frames would cost two.
	_shot_precook_minted = 0
	for with_soot in [false, true]:
		field.build(lights, shadows, top_wall_level, occupancy,
				_build_soot_snapshot(soot_faces, predict_destroyed.keys(),
					predict_damaged) if with_soot else {},
				_under_structure, soot_faces, true)
		if token != _shot_precook_token or not is_instance_valid(_voxel_renderer):
			return
		_shot_precook_minted += _voxel_renderer.warm_light_alts_for_gus(
			field, scope_gus, variant_cells)
	if token != _shot_precook_token:
		return
	_shot_precook_done = true
	print_debug("[W-PRECOOK] warm complete — %d TileSet alternative(s) minted ahead of the shot (soot-free + sooty)"
		% _shot_precook_minted)


## The GU scope for a shot: every impact GU, grown by the soot reach.
func shot_repaint_scope(impact_gus: Array) -> Array:
	var scope: Dictionary = {}
	for gu in impact_gus:
		for dx in range(-SHOT_REPAINT_SOOT_RINGS, SHOT_REPAINT_SOOT_RINGS + 1):
			for dy in range(-SHOT_REPAINT_SOOT_RINGS, SHOT_REPAINT_SOOT_RINGS + 1):
				scope[(gu as Vector2i) + Vector2i(dx, dy)] = true
	return scope.keys()


func _repaint_voxel_light_buckets(geometry_only: bool = false) -> void:
	if _voxel_renderer == null or _lighting_controller == null:
		return
	var registry = _lighting_controller.get_light_registry()
	if registry == null:
		return
	if _voxel_light_field == null:
		_voxel_light_field = VoxelLightField.new()
	## OVERHEAD lamps anchor at the top of the ACTUAL built wall stack, not the
	## 8-storey ceiling-fixture height — see VoxelLightField.build().
	var top_wall_level: int = maxi(_voxel_renderer.get_layer_count() - 1, 0)
	## FACE-SOOT-01: one derivation feeds both — the isotropic ring map (probes,
	## vision modes, selftests) and the per-face triples the renderer packs into
	## each cell's modulate alpha.
	var soot_faces: Dictionary = {}
	## W-PRECOOK profiling seam, env-gated like every other standing dev probe in
	## this function. §0's routes are chosen from WHERE the repaint's time goes,
	## and the only figures on record are from the retired bench in August.
	var _prof: bool = OS.get_environment("INFILTRAITOR_REPAINT_PROFILE") == "1"
	var _t0: int = Time.get_ticks_usec()
	var occupancy: Dictionary = _voxel_renderer.build_occupancy()
	var _t1: int = Time.get_ticks_usec()
	var soot: Dictionary = _build_soot_snapshot(soot_faces)
	var _t2: int = Time.get_ticks_usec()
	_voxel_light_field.build(
			registry.get_active_lights(),
			_lighting_controller.get_shadow_results(),
			top_wall_level,
			occupancy,
			soot,
			_under_structure,
			soot_faces,
			geometry_only)
	var _t3: int = Time.get_ticks_usec()
	_voxel_renderer.apply_light_field(_voxel_light_field)
	if _prof:
		print("[REPAINT-PROF] occupancy %.1f · soot %.1f · field.build %.1f · apply %.1f ms (geometry_only=%s)"
			% [float(_t1 - _t0) / 1000.0, float(_t2 - _t1) / 1000.0,
			float(_t3 - _t2) / 1000.0,
			float(Time.get_ticks_usec() - _t3) / 1000.0, geometry_only])
	## PERF-03 equivalence probe — env-gated (INFILTRAITOR_LIGHT_EQUIV_PROBE=1),
	## same standing-dev-tool precedent as INFILTRAITOR_FACE_SOOT_DIAG above.
	## Snapshots every cell's alternative, forces a full rebuild, and reports
	## how many cells disagree; 0 means the incremental invalidation left
	## nothing stale. Kept rather than deleted after it did its job once,
	## because it guards a regression class nothing else can see: the
	## invalidation neighbourhood in VoxelLightField._stale_cells() is derived
	## from how far _face_occlusion() samples, so widening that sampling
	## silently makes the neighbourhood too small — a stale-lighting bug with
	## no visible symptom until someone looks at the right voxel. Run it after
	## touching either. Doubles the repaint cost while enabled, hence the gate.
	if geometry_only and OS.get_environment("INFILTRAITOR_LIGHT_EQUIV_PROBE") == "1":
		var _snap_a: Dictionary = _perf_snapshot_alts()
		_repaint_voxel_light_buckets(false)
		var _snap_b: Dictionary = _perf_snapshot_alts()
		var _diff: int = 0
		for k in _snap_b:
			if _snap_a.get(k, -12345) != _snap_b[k]:
				_diff += 1
		print("[LIGHT-EQUIV] %d cells, %d differ" % [_snap_b.size(), _diff])
	if OS.get_environment("INFILTRAITOR_FACE_SOOT_DIAG") == "1":
		_print_face_soot_diagnostics(soot_faces)


## PERF-03 — every placed cell's current alternative id, for the equivalence
## probe above. Reads both layer stores the renderer keeps (positive wall
## levels and the negative floor/background ones), so "every cell" really is
## every cell and not just the walls.
func _perf_snapshot_alts() -> Dictionary:
	var out: Dictionary = {}
	for level in range(_voxel_renderer._voxel_layers.size()):
		var layer: TileMapLayer = _voxel_renderer._voxel_layers[level]
		for cell in layer.get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = layer.get_cell_alternative_tile(cell)
	for level in _voxel_renderer._negative_voxel_layers.keys():
		var nlayer: TileMapLayer = _voxel_renderer._negative_voxel_layers[level]
		for cell in nlayer.get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = nlayer.get_cell_alternative_tile(cell)
	return out


## FACE-SOOT-01 diagnostics — env-gated (INFILTRAITOR_FACE_SOOT_DIAG=1). Reports
## what the REAL map actually produced, because a selftest on a synthetic patch
## cannot catch a feature made inert by real data (the floor-dent lesson,
## 2026-08-01: 69 dents on a fixture, zero on PLAYGROUND).
func _print_face_soot_diagnostics(soot_faces: Dictionary) -> void:
	var total: int = 0
	var directional: int = 0        ## faces genuinely differ from each other
	## PERF-02 B3-2: one slot per real ring plus clean — sized off the constant
	## so a further tone change cannot silently drop counts off the end.
	var histogram_slots: int = BlastCalculator.FACE_SOOT_CLEAN + 1
	var per_face_rings := {}
	for face_idx in range(3):
		var row: Array = []
		for _slot in range(histogram_slots):
			row.append(0)
		per_face_rings[face_idx] = row
	for level in soot_faces:
		for cell in soot_faces[level]:
			var f: Vector3i = soot_faces[level][cell]
			total += 1
			if f.x != f.y or f.y != f.z:
				directional += 1
			per_face_rings[0][clampi(f.x, 0, histogram_slots - 1)] += 1
			per_face_rings[1][clampi(f.y, 0, histogram_slots - 1)] += 1
			per_face_rings[2][clampi(f.z, 0, histogram_slots - 1)] += 1
	print("[FACE-SOOT-DIAG] sooted voxels=%d directional=%d (%.1f%%)"
			% [total, directional, 100.0 * float(directional) / maxf(float(total), 1.0)])
	print("[FACE-SOOT-DIAG] ring histogram [r0..r%d,clean] top=%s se=%s sw=%s"
			% [BlastCalculator.FACE_SOOT_CLEAN - 1,
			per_face_rings[0], per_face_rings[1], per_face_rings[2]])
	## Lazily minted (source, atlas_coords, alt) triples across the whole tileset —
	## NOT comparable to the 1536-wide alternative-id space, which is per TILE.
	## This is the number that costs memory on a phone.
	print("[FACE-SOOT-DIAG] minted tile alternatives=%d" % _voxel_renderer.minted_alt_count())


## VL-D1/D24 — level → {cell: soot_ring}, DERIVED fresh from which voxels are
## currently absent (BlastCalculator.derive_soot_rings()) rather than read off
## a stored field. *(Director, 2026-07-30: "queremos o sistema de derivar a
## fuligem de acordo com os voxels faltantes, em vez de guardar a informação
## de cada um.")* Rebuilt on every repaint from the two registries — same cost
## baseline the old per-voxel read already paid (one pass over every voxel),
## plus one bounded BFS from this map's current holes. A destroyed voxel's
## absence already survives rotation via _base_damage, so nothing about soot
## itself needs to persist separately any more. Empty when nothing is holed.
## PERF-02 B3 (Director, 2026-08-04): "a fuligem não é mais forte, é mais
## distante... só pra bombas." A bomb's scorch reaches further than a firearm's;
## it is not darker. Two separate BFS passes (see _build_soot_snapshot()),
## because BlastCalculator.derive_soot_rings()' internal min-ring merge does not
## compose across two calls into the same snapshot — a second call cannot lower
## an already-recorded ring — so they run into scratch dictionaries and merge
## externally. `var`, not `const` (Rule 1): both are tuning numbers.
## PERF-02 B3-2: 4, not 5 — one cell of reach per available tone, so the bomb's
## extra distance reads as a real gradient step rather than a flat band of the
## faintest tone. Four is the ceiling, not a preference: see
## VoxelRenderer.FACE_SOOT_CODE_COUNT for the measured alternative-id limit.
var weapon_soot_rings: int = 3
var blast_soot_rings: int = 4

## S-FEATHER (Director, 2026-08-12): *"poderia ter um pouco de fuligem bem
## levinha expandindo pra fora, como um feather."*
##
## Extra BFS reach BEYOND the graded rings above, at no extra tone. Every
## distance past `intensity_rings` is capped by `derive_soot_rings()` at the
## faintest real tone, so these rings come out as one flat, faint tail — which is
## precisely the feather, and precisely what `blast_soot_rings` was pinned at 4
## to AVOID: *"one cell of reach per available tone, so the bomb's extra distance
## reads as a real gradient step rather than a flat band of the faintest tone"*
## (PERF-02 B3-2, the note directly above).
##
## That reasoning is not wrong, it was answering a different question. It was
## about where the GRADIENT should end, and this is about what happens after it
## ends. Kept as two numbers rather than one raised number so the two ideas stay
## separately tunable, and so the older note keeps meaning what it said.
##
## Only the falloff face survives out here: `_face_rings_for()` sends every
## non-facing face to CLEAN once `ring + falloff` reaches the intensity count, so
## the tail is directional — the faces that saw the blast, and nothing else.
var blast_soot_feather_rings: int = 2

## out_faces, when supplied, additionally receives the FACE-SOOT-01 per-face
## triples for every voxel this pass scorches (see BlastCalculator).
## `predict_weapon_cells` (W-PRECOOK, 2026-08-19): extra Vector3i seeds treated
## as firearm-made holes that do not exist yet. Same purpose as
## `build_occupancy(predict_destroyed)` — see its note — and the same safety: a
## wrong guess only costs a cache miss.
## `predict_damaged` are Voxels the shot will DENT or CRACK. They matter to the
## warm even though they are not holes: D33-SOOT-01 feeds dented/cracked voxels
## into the soot derivation, so leaving them out of the prediction changed 13
## cells' soot codes — and 13 misses cost a whole TileSet rebuild, exactly as
## much as 412 would.
func _build_soot_snapshot(out_faces: Dictionary = {},
		predict_weapon_cells: Array = [],
		predict_damaged: Array = []) -> Dictionary:
	var cell_to_voxel: Dictionary = {}   ## Vector3i -> Voxel, every voxel (destroyed included)
	## PERF-02 B3: seeds split by what made the hole. Voxel.damage_is_blast
	## already carries that distinction — nothing new has to be recorded.
	var blast_cells: Array = []          ## Vector3i seeds, bomb-made holes
	var weapon_cells: Array = []         ## Vector3i seeds, firearm-made holes
	var damaged_voxels: Array = []       ## D33-SOOT-01: DENTED/CRACKED, not destroyed
	if _edge_registry != null:
		for slice in _edge_registry.all_slices():
			for v in slice.voxels:
				_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v)
	if _slab_registry != null:
		for slab in _slab_registry.all_slabs():
			for v in slab.voxels:
				_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v)
	for predicted in predict_weapon_cells:
		if not weapon_cells.has(predicted):
			weapon_cells.append(predicted)
	## W-PRECOOK-02: `predict_damaged` carries plan_point_impact() ENTRIES, not
	## Voxels, and it has to. The voxel a shot is about to dent is still INTACT
	## right now, and `apply_self_soot()` reads the tuple off the object — so the
	## previous version of this loop, which appended live Voxels, contributed
	## nothing at all and left the predicted world un-sooted exactly where the
	## shot was going to scorch it. Any voxel the prediction covers is dropped
	## from the live list, so a re-hit voxel scorches from its FUTURE face rather
	## than merging its old one in.
	var predicted_keys: Dictionary = {}
	for entry in predict_damaged:
		var pv: Voxel = entry["voxel"]
		predicted_keys[Vector3i(pv.grid_pos.x, pv.grid_pos.y, pv.level)] = true
	if not predicted_keys.is_empty():
		damaged_voxels = damaged_voxels.filter(func(dv):
			return not predicted_keys.has(Vector3i(dv.grid_pos.x, dv.grid_pos.y, dv.level)))
	## E-JUNCTION-01 (2026-08-13): wall-junction corner columns. Explosions
	## already dent/crack/destroy them (see DetonationPlanBuilder's own
	## PHASE_JUNCTIONS); firearms deliberately still don't (a shot's aim
	## resolves to a Slice face, never the diagonal notch a column owns — the
	## Director's own call, since there is no way for a player to aim at a
	## corner on purpose). But soot is a PROXIMITY read, not a hit test — a
	## column standing right next to a hole either weapon opened should scorch
	## like its neighbours, or it reads as an untouched island inside a
	## blackened room. Indexing it here is what lets derive_soot_rings() see
	## it at all, regardless of which weapon made the nearby hole.
	for column in _junction_columns:
		for v in column.voxels:
			_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v)

	## S-DEDUP: the sequence lives in BlastCalculator.build_soot_field() now —
	## the same call the detonation path makes, so a repaint and a detonation
	## cannot disagree about what soot IS. `also_visible` is deliberately not
	## passed: by repaint time the crater floor is genuinely visible, so there is
	## nothing to promise about the future.
	var snapshot: Dictionary = {}
	BlastCalculator.build_soot_field(cell_to_voxel, blast_cells, weapon_cells,
			damaged_voxels, blast_soot_rings + blast_soot_feather_rings,
			weapon_soot_rings, snapshot, out_faces, {}, predict_damaged)

	## VL-D2: the revealed crater-floor soot (non-Voxel cells), through the same
	## helper the detonation path uses for the same kind of cell.
	##
	## S-DEDUP changed two things here, both strictly toward the detonation
	## path's behaviour: this used to OVERWRITE the snapshot (so a cell already
	## carrying darker soot could be LIGHTENED by the crater ring) and it never
	## wrote `out_faces` at all, leaving those cells on
	## `face_soot_code()`'s isotropic fallback. Min-wins can now only darken, and
	## the faces are written top-only — which renders identically for a floor
	## cell, since a floor cell has exactly one visible face.
	##
	## THE ONE PIECE OF THIS TASK WITH NO CAPTURE PATH: `_crater_floor_soot` is
	## only populated by the rotation replay (see add_crater_floor_soot()'s
	## caller), and no capture action rotates the view. The rest of this function
	## is exercised by a real firearm shot and was pixel-diffed; this block was
	## reasoned about, not measured, and is flagged as such rather than folded
	## into the same claim.
	for level in _crater_floor_soot.keys():
		for cell in _crater_floor_soot[level].keys():
			BlastCalculator.scorch_floor_cell(snapshot, out_faces, level, cell,
					int(_crater_floor_soot[level][cell]))
	return snapshot


func _index_soot_voxel(cell_to_voxel: Dictionary, blast_cells: Array,
		weapon_cells: Array, damaged_voxels: Array, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v
	if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
		if v.damage_is_blast:
			blast_cells.append(key)
		else:
			weapon_cells.append(key)
	elif v.damage_state == Voxel.DamageState.DENTED or v.damage_state == Voxel.DamageState.CRACKED:
		damaged_voxels.append(v)


## VL-D2 — record soot on a revealed crater-floor cell (no Voxel to hang it on).
## Min ring wins, same as the Voxel path.
func add_crater_floor_soot(level: int, cell: Vector2i, ring: int) -> void:
	if not _crater_floor_soot.has(level):
		_crater_floor_soot[level] = {}
	var existing = _crater_floor_soot[level].get(cell, 99)
	if ring < existing:
		_crater_floor_soot[level][cell] = ring


func _update_alert_label() -> void:
	if _hud_controller == null:
		return
	if _turn_controller != null:
		var pct := float(_turn_controller.get_alert_meter()) / float(_alert_max)
		_hud_controller.update_alert(pct)
	else:
		var pct := float(_alert_meter) / float(_alert_max)
		_hud_controller.update_alert(pct)


func _update_enemy_visibility() -> void:
	# Update enemy alpha/saturation each frame while moving.
	# Visibility is driven by the player's vision radius + ability bonuses.
	# At vision distance the guard starts to desaturate, then fades out one tile later.
	if _vision_controller.dev_vision:
		for guard in _guards:
			if not is_instance_valid(guard):
				continue
			guard.modulate = Color.WHITE
		queue_redraw()
		return

	var enemy_vision := float(agent.get_vision_radius() + vision_bonus_tiles)
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		var d: float = (guard.cell - agent.cell).length()
		var tile_distance: int = int(floor(d + 0.5))
		if tile_distance <= int(enemy_vision) - 1:
			guard.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif tile_distance == int(enemy_vision):
			guard.modulate = Color(0.85, 0.85, 0.85, 1.0)
		elif tile_distance == int(enemy_vision) + 1:
			guard.modulate = Color(0.65, 0.65, 0.65, 0.5)
		else:
			guard.modulate = Color(1.0, 1.0, 1.0, 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_exit_markers()
	_draw_spawn_marker()
	_draw_playable_boundary()
	_world_markers_controller.draw_shadow_debug()

	## Draw enemy last_known markers
	for guard in _guards:
		if not is_instance_valid(guard):
			continue
		if guard.last_known_agent_cell == INVALID_CELL:
			continue
		if guard.state == guard.STATE_PATROL:
			continue
		var world := _world_center_for_cell(guard.last_known_agent_cell)
		draw_circle(world, 18.0, Color(1.0, 0.72, 0.18, 0.24))
		draw_circle(world, 18.0, Color(1.0, 0.9, 0.2, 0.82), 3.0)
		draw_line(world + Vector2(-8.0, 0.0), world + Vector2(8.0, 0.0), Color(1.0, 1.0, 1.0, 0.92), 2.5)
		draw_line(world + Vector2(0.0, -8.0), world + Vector2(0.0, 8.0), Color(1.0, 1.0, 1.0, 0.92), 2.5)


func _update_selected_preview() -> void:
	if _selected_cell == INVALID_CELL or _selected_cell == agent.cell:
		path_preview.clear_path()
		return

	if not movement_overlay.is_reachable(_selected_cell):
		path_preview.clear_path()
		return

	var path: Array[Vector2i] = movement_overlay.build_path_to(_selected_cell)
	if path.size() < 2:
		path_preview.clear_path()
		return

	path_preview.set_path(path, movement_overlay.get_ap_cost(_selected_cell))


func _update_movement_highlight() -> void:
	if turn_manager.is_enemy_phase or agent.is_moving:
		return

	var hovered_ap: int = movement_overlay.get_ap_cost(_hovered_cell)
	if hovered_ap > 0:
		movement_overlay.set_highlight_ap(hovered_ap)
	else:
		# If hovering origin or unreachable, default to 1 AP zone
		# (which is usually visible at the start of the turn)
		movement_overlay.set_highlight_ap(1)


func _is_selectable_cell(cell: Vector2i) -> bool:
	if _selection_controller == null:
		return false
	return _selection_controller.is_selectable_cell(cell)


func _set_selected_cell(cell: Vector2i) -> void:
	if _selection_controller == null:
		return
	_selection_controller.set_selected_cell(cell)
	_selected_cell = _selection_controller.selected_cell


func _handle_tile_click(cell: Vector2i) -> void:
	if _selection_controller == null:
		return
	_selection_controller.handle_tile_click(cell)
	_selected_cell = _selection_controller.selected_cell









func _debug_probe_voxel_alignment() -> void:
	## SLICE-02: measures world-space delta between the canonical GU diamond and the
	## voxel plane's 8x8 block. Diagnostic for block/voxel layer alignment.
	## Uses corrected formula: adjusted = map_to_local() - half_tile_size
	if not debug_probe_voxel_alignment:
		return
	if _voxel_renderer == null or _voxel_renderer.get_layer(0) == null:
		print_debug("[SLICE-02 probe] ABORT: no voxel renderer or layer 0")
		return

	print_debug("[SLICE-02 probe] ===== STARTING ALIGNMENT CHECK =====")

	# Find a floor layer cell that exists
	var floor_cell = Vector2i.ZERO
	var floor_found = false
	for x in range(-5, 10):
		for y in range(-5, 10):
			if floor_layer.get_cell_source_id(Vector2i(x, y)) != -1:
				floor_cell = Vector2i(x, y)
				floor_found = true
				break
		if floor_found: break

	if not floor_found:
		print("[SLICE-02 probe] ABORT: no floor tile found")
		return

	var floor_ts = floor_layer.tile_set
	var floor_tile_size = floor_ts.tile_size
	var floor_half_size = Vector2(floor_tile_size) / 2.0

	var vlayer = _voxel_renderer.get_layer(0)
	var voxel_ts = vlayer.tile_set
	var voxel_tile_size = voxel_ts.tile_size
	var voxel_half_size = Vector2(voxel_tile_size) / 2.0

	## Corrected formula: adjusted = map_to_local - half_tile_size
	var floor_map = floor_layer.map_to_local(floor_cell)
	var floor_adjusted = floor_map - floor_half_size

	var voxel_cell = floor_cell * 8
	var voxel_map = vlayer.map_to_local(voxel_cell)
	var voxel_adjusted = voxel_map - voxel_half_size

	## Compare adjusted positions
	var canon_pos = floor_adjusted + VISUAL_GRID_OFFSET
	var voxel_pos = voxel_adjusted + vlayer.position
	var delta = voxel_pos - canon_pos

	print_debug("[SLICE-02 probe] floor_cell = %s  voxel_cell = %s" % [floor_cell, voxel_cell])
	print_debug("[SLICE-02 probe] floor_map=%s  voxel_map=%s" % [floor_map, voxel_map])
	print_debug("[SLICE-02 probe] floor_adjusted=%s  voxel_adjusted=%s" % [floor_adjusted, voxel_adjusted])
	print_debug("[SLICE-02 probe] canon_pos=%s  voxel_pos=%s  delta=%s px" % [canon_pos, voxel_pos, delta])

	## I2: Check painted voxels for solid blocks
	if _base_layout.is_empty():
		return

	var structure_tiles: Array = _base_layout.get("structure_tiles", [])
	var block_found = false
	var block_cell = Vector2i.ZERO

	for entry in structure_tiles:
		var tile_name: String = entry.get("tile_name", "")
		if tile_name.begins_with("block_"):
			block_cell = entry.get("cell", Vector2i.ZERO)
			block_found = true
			break

	if not block_found:
		print_debug("[SLICE-02 probe] INFO: no block_* tile found for footprint check")
		return

	print_debug("[SLICE-02 probe] === Block Footprint Check ===")
	print_debug("[SLICE-02 probe] block_cell (GU coords) = %s" % block_cell)

	## Get expected voxel positions for this GU
	var GeometryCoordinatesClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
	var expected_voxels: Array[Vector2i] = GeometryCoordinatesClass.gu_voxels(block_cell)

	## Check which voxel cells are actually painted at voxel layer 0
	var painted_voxels: Array[Vector2i] = []
	for vx in expected_voxels:
		if vlayer.get_cell_source_id(vx) != -1:
			painted_voxels.append(vx)

	print_debug("[SLICE-02 probe] expected voxel count = %d" % expected_voxels.size())
	print_debug("[SLICE-02 probe] painted voxel count = %d" % painted_voxels.size())

	if painted_voxels.size() == expected_voxels.size():
		print_debug("[SLICE-02 probe] result = MATCH (all expected voxels painted)")
	else:
		print_debug("[SLICE-02 probe] result = MISMATCH")
		var missing: Array[Vector2i] = []
		for ev in expected_voxels:
			if not painted_voxels.has(ev):
				missing.append(ev)
		if missing.size() > 0:
			print_debug("[SLICE-02 probe] missing voxels: %s" % missing)


func _tic_voxel_system() -> void:
	if _voxel_renderer != null and _edge_registry != null:
		_voxel_renderer.process_dirty(_edge_registry)
	_tic_slab_system()


## DESTRUCTION_MASTER_PLAN D1/Part 1: Slab's TIC-skip half. No renderer consumer
## exists yet (Part 3 wires the destruction trigger, Part 4 wires rendering) — this
## only clears dirty flags so a future producer's marks don't accumulate unconsumed.
## _slab_registry stays empty until Part 2, so dirty_slabs() is always [] today; that
## emptiness is the skip-when-clean contract already paying for itself at zero cost.
func _tic_slab_system() -> void:
	if _slab_registry == null:
		return
	var dirty_slabs: Array = _slab_registry.dirty_slabs()
	if dirty_slabs.is_empty():
		return
	for slab in dirty_slabs:
		slab.clear_all_dirty()



## M2-13: Quantized isometric directions (8 directions)
const SHADOW_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const SHADOW_LENGTH_MAX := 5


func _get_blocked_cells_array() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		cells.append(cell)
	return cells


func _is_cell_inside_room(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _room_size.x and cell.y < _room_size.y




func _cell_to_base(view_cell: Vector2i, direction: String, base_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var size := base_size
	if size == Vector2i.ZERO:
		size = _base_layout.get("size", Vector2i.ZERO)
	return PerspectiveMapperClass.cell_to_base(view_cell, direction, size)




## Convert a screen-space press position to the tile cell underneath it.
## local_to_map uses the TOP VERTEX as anchor, so it only gives the correct
## cell when clicking the top quadrant. The 3×3 search over visual CENTERs
## (map_to_local + Vector2(0,64)) finds the diamond that truly contains the
## click — this corrects the other three quadrants.
func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var lp: Vector2 = floor_layer.to_local(ct.affine_inverse() * screen_pos)
	var logical_lp := lp - VISUAL_GRID_OFFSET
	var tile_seed: Vector2i = floor_layer.local_to_map(logical_lp)
	var best := tile_seed
	var best_dist := INF
	var found_inside := false
	for dc: int in [-1, 0, 1]:
		for dr: int in [-1, 0, 1]:
			var c := tile_seed + Vector2i(dc, dr)
			var center := floor_layer.map_to_local(c) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
			var d := lp - center
			var dist := absf(d.x) / 128.0 + absf(d.y) / 64.0
			if dist <= 1.0 and dist < best_dist:
				best_dist = dist
				best = c
				found_inside = true
	if found_inside:
		return best
	return INVALID_CELL


## Exact inverse of _screen_to_tile(): the screen position that resolves back
## to `cell`'s floor-GU hit-test. D22-INPUT-01 (Director, 2026-07-30): the
## clickable hitbox for an interactive floor object is the GU cell it stands
## on, not its sprite — anything that synthesizes "a click on this object"
## (the dev capture harness below; any future scripted input) must target
## this, not a sprite-derived screen position, or it silently misses the
## object's own hit_test().
func _tile_to_screen_center(cell: Vector2i) -> Vector2:
	var local_center: Vector2 = floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
	var global_pos: Vector2 = floor_layer.to_global(local_center)
	return get_viewport().get_canvas_transform() * global_pos


## OCC-FIX-01 — B6 loud-fail: geometry in, geometry out.
##
## This lives in the CALLER, not inside build_from_layout(), and that placement is the
## whole point. On 2026-07-12 a commit deleted this file's `_junction_columns` member as
## an "unused variable". It is not unused — room_builder.gd writes to it from the outside
## (`room._junction_columns = junction_columns`). Deleting it turned that write into a
## *runtime* error, which aborts build_from_layout() at that line — before clear() and
## render() ever run. A guard placed after render() inside the builder would never have
## executed either. Execution DOES return here, so here is where the check has to be.
##
## Why nothing else caught it: GDScript raises invalid-property-assignment at runtime, not
## compile time, so project_lint.py passed clean. The floor is drawn before the failing
## line, so the game still looked like a game. It simply had no walls — and every check
## downstream then "passed" against that empty world, including an agent z-index derived
## from an empty layer list.
##
## The invariant: if the edge registry produced slices, the renderer must have placed
## cells. Zero cells from a non-empty registry is a broken render path, and it must be
## loud rather than silently shipping an empty map.
func _assert_geometry_rendered() -> void:
	if _voxel_renderer == null or _edge_registry == null:
		return
	var slice_count: int = _edge_registry.all_slices().size()
	if slice_count == 0:
		return  ## a genuinely wall-less map is legal
	var placed: int = _voxel_renderer.get_placed_cell_count()
	if placed > 0:
		return
	push_error(
		"[VOXEL] Render path is broken: %d slices produced 0 placed cells. " % slice_count
		+ "The map has geometry but none of it was placed. Do not trust any visual "
		+ "result from this build."
	)
	assert(false, "VoxelRenderer placed 0 cells for %d slices — render path broken" % slice_count)


## OCC-FIX-02: the single recompute path for the occlusion set. Called from exactly three
## places: map load (seed), agent step, and view change. Previously this block was copied
## into the latter two by hand — two live copies of one truth, which is the project's
## split-brain pain, and the copy that was missing at boot is what left the set empty.
func _recompute_occlusion() -> void:
	if _occlusion_set == null:
		return
	## OCC-26 capture instrument: INFILTRAITOR_OCC_DISABLE=1 forces an empty
	## occlusion set, so a capture pair (same agent cell, occlusion on/off)
	## isolates exactly the erased pixels — the erased-silhouette boundary is the
	## ground truth wireframe alignment is measured against.
	if OS.get_environment("INFILTRAITOR_OCC_DISABLE") == "1":
		if _voxel_renderer != null:
			_voxel_renderer.apply_occlusion({})
		if _occlusion_wireframe_overlay != null:
			_occlusion_wireframe_overlay.refresh()
		return
	## OCC-07: the occlusion decision is per-Slice now, not per raw voxel column —
	## feed it the same EdgeRegistry the renderer itself just built from (published
	## by RoomBuilder.build_from_layout(), see room_builder.gd's comment on why this
	## handle is shared rather than re-derived).
	var slices: Array = _edge_registry.all_slices() if _edge_registry != null else []
	
	## OCC-HOVER-01 (2026-07-15): Multi-origin occlusion — includes hover cell when
	## it's within agent's reachable zone (movement_overlay.is_reachable). This
	## reveals geometry occluding EITHER the agent OR the hover point, giving the
	## player a preview of what they'll see after moving there.
	var origins: Array[Vector2i] = [agent.cell]
	if _hovered_cell != INVALID_CELL and _hovered_cell != agent.cell:
		if movement_overlay != null and movement_overlay.is_reachable(_hovered_cell):
			origins.append(_hovered_cell)

	## ROOF-OCC-01: ceiling slabs join the computation (screen-horizontal GU
	## stripes) — the registry is rebuilt per view rotation, so these are
	## already in view-space like the slices.
	var ceiling_slabs: Array = []
	if _slab_registry != null:
		for slab in _slab_registry.all_slabs():
			if slab.role == Slab.Role.CEILING:
				ceiling_slabs.append(slab)

	_occlusion_set.recompute(origins, slices, _room_size, _junction_columns, ceiling_slabs)

	## OCC-02: paint it. The set is the truth; ghosts are its only rendering.
	if _voxel_renderer != null:
		_voxel_renderer.apply_occlusion(_occlusion_set.get_occluded_cells())

	if _occlusion_overlay != null:
		_occlusion_overlay.queue_redraw()
	if _occlusion_wireframe_overlay != null:
		## OCC-07-b: rebuilds the per-level panel children (each with its own
		## z_index) — this manager no longer draws anything itself, so a plain
		## queue_redraw() here would do nothing.
		_occlusion_wireframe_overlay.refresh()


## OCC-01: Collect all voxel cells currently placed in the renderer
## Returns an array of Vector2i voxel-grid cells (in view-space, already rotated).
func _collect_all_voxel_cells() -> Array:
	var voxel_cells: Array = []
	
	if _voxel_renderer == null:
		return voxel_cells
	
	# Iterate through all voxel levels and collect used cells
	for level in range(8):  # GeometryCoords.LEVELS_PER_STOREY = 8
		var layer: TileMapLayer = _voxel_renderer.get_layer(level)
		if layer != null:
			var used_cells := layer.get_used_cells()
			for cell in used_cells:
				if not voxel_cells.has(cell):
					voxel_cells.append(cell)
	
	return voxel_cells


func _process(_delta: float) -> void:
	# Update temporal lighting effects (flicker, pulse, rotation)
	_update_temporal_lights(_delta)
	
	_update_vision_fog()
	if _has_moving_guards():
		_update_enemy_visibility()


## Update temporal state for all lights and trigger rebuilds if needed (L-IMP-06)
func _update_temporal_lights(delta: float) -> void:
	if _lighting_controller == null:
		return
	
	var light_registry = _lighting_controller.get_light_registry()
	if light_registry == null:
		return
	
	var changed_lights: Array = light_registry.update_temporal_all(delta)
	if changed_lights.is_empty():
		return

	## VL-03: repaint ONLY the changed lights' influence set, never the whole
	## map. rebuild_deferred() (the old path) re-derives EVERYTHING — shadow,
	## exposure, and the light field — at ~590-675ms on PLAYGROUND; paying that
	## twice a second for a flickering lamp would stall the game. Two things
	## make the incremental path correct, not just faster:
	##   1. Tactical shadow/exposure (_rebuild_all_shadows_and_exposure) reads
	##      only light.active, never energy_multiplier — a flicker toggle was
	##      ALWAYS a no-op for the tactical layer, so skipping it here loses
	##      nothing (canon: visual brightness ≠ tactical visibility).
	##   2. `changed_lights` holds the SAME LightSource instances the field's
	##      _lights array already references (registry and field share
	##      objects) — update_temporal_all() already mutated energy_multiplier
	##      in place, so the field sees the new value the instant its caches
	##      are cleared; no need to rebuild _lights itself.
	if _voxel_light_field == null or _voxel_renderer == null:
		return  ## field not built yet (pre-first lighting_rebuilt); nothing to do
	_voxel_light_field.clear_caches()
	var affected_gus: Dictionary = {}
	for light in changed_lights:
		for gu in _voxel_light_field.gus_in_light_range(light):
			affected_gus[gu] = true
	_voxel_renderer.apply_light_field_gus(_voxel_light_field, affected_gus.keys())


func _has_moving_guards() -> bool:
	for guard in _guards:
		if is_instance_valid(guard) and guard.is_moving:
			return true
	return false


## Update the distance-fog shader uniforms every frame so the gradient tracks
## the agent's screen position and scales correctly with zoom and viewport size.
func _update_vision_fog() -> void:
	if _fow_controller == null:
		return
	
	var agent_world := agent.global_position
	var canvas_t    := get_viewport().get_canvas_transform()
	var vp_size     := get_viewport().get_visible_rect().size
	var screen_px   := canvas_t * agent_world
	var screen_uv   := screen_px / vp_size
	var zoom        := camera.zoom.x
	var vision_r_tiles := float(VISION_TILE_RADIUS + vision_bonus_tiles)
	
	_fow_controller.update_vision_center(agent_world, screen_uv, vision_r_tiles, zoom, vp_size)


## Unified input: keyboard · wheel zoom · motion drag.
## Camera input handled first; if CameraController consumes it, done.
## INPUT-01: Delegated to InputController via signals.
func _input(event: InputEvent) -> void:
	## Mouse motion: preview path on hover
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var new_hover := _screen_to_tile(mm.position)
		if new_hover != _hovered_cell:
			## OCC-HOVER-01: Cache previous hover to detect reachability zone changes
			var old_hover := _hovered_cell
			var old_reachable := (old_hover != INVALID_CELL and old_hover != agent.cell
				and movement_overlay != null and movement_overlay.is_reachable(old_hover))

			_hovered_cell = new_hover

			## Recompute occlusion if hover moved in/out of reachable zone
			var new_reachable := (_hovered_cell != INVALID_CELL and _hovered_cell != agent.cell
				and movement_overlay != null and movement_overlay.is_reachable(_hovered_cell))
			if old_reachable != new_reachable:
				_recompute_occlusion()
			elif new_reachable:
				## Both old and new are reachable, but different cells — recompute to
				## update preview. Only when inside reachable zone to avoid spam.
				_recompute_occlusion()

			if _vision_controller.dev_vision:
				_update_dev_hover_label()
			_update_movement_highlight()

			## T-GRENADE: Update grenade targeting display when hover changes
			if _test_zone_controller != null and _test_zone_controller.is_in_targeting_mode():
				_test_zone_controller._update_grenade_targeting_display()

			## UI-01: Update selection and path preview on hover
			if _is_selectable_cell(_hovered_cell):
				_selected_cell = _hovered_cell
				selection_overlay.set_selected(_hovered_cell)
				_update_selected_preview()
			elif _hovered_cell == agent.cell or not movement_overlay.is_reachable(_hovered_cell):
				## Hide preview if hovering agent or unreachable zone
				_selected_cell = agent.cell
				selection_overlay.set_selected(agent.cell)
				path_preview.clear_path()


## Left mouse: only runs when no GUI Control consumed the event first.
## This lets HUD buttons work while still handling pan + tile selection.
func _unhandled_input(event: InputEvent) -> void:
	if turn_manager.is_enemy_phase or _actor_end_pause_active:
		return

	## TEST-ZONE placeholder (2026-07-21): the context menu itself owns no
	## input handling (see detonate_context_menu.gd) — room.gd is the single
	## place deciding "is the menu open". Escape is handled earlier, in
	## _on_pause_requested() via _modal_stack (ESC-STACK-01) — InputController
	## fires that from _input(), which runs before _unhandled_input() ever
	## sees the event, so only the outside-click dismissal is left to do here.
	## A click that reaches _unhandled_input while the menu is visible never
	## landed on the menu's own buttons (Control/Button input consumes those
	## first), so any mouse press here is an "outside" click.
	if _context_menu != null and _context_menu.visible:
		if event is InputEventMouseButton and event.pressed:
			_cancel_context_menu()
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton

	## ── Right button (desktop, INPUT-SPLIT-01): move DIRECTLY to the clicked
	## cell — select + move in one action. Replaces the old "execute move to
	## the previously selected tile"; touch devices have no right button, so
	## this branch is desktop-only by nature.
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		## ── AIM MODE OWNS THE RIGHT BUTTON, AND WALKING IS OFF ──────────────
		## Director, 2026-08-19: *"quando entra no modo mira, tanto de granadas
		## quanto de armas, o comando para andar com o botão direito tem que ser
		## desabilitado, e volta depois que o tiro for dado ou cancelado"*, and
		## *"No celular é um tap pra selecionar e outro pra confirmar, podemos
		## padronizar assim também no desktop, usando o botão direito"*.
		##
		## So one button drives the whole flow: first right-click picks the GU,
		## a second on the SAME GU throws. Standardising desktop on the mobile
		## two-tap is not merely tidiness — it means the aim flow has one
		## description instead of two that can drift apart per platform.
		##
		## The branch RETURNS unconditionally, including when the click resolved
		## to nothing: that is the "walking is disabled" half. Falling through to
		## the move fallback is exactly what used to send the agent walking
		## across the board mid-aim.
		##
		## The WEAPON's aim needs no case here — it is a modal context menu, and
		## the guard at the top of this function already swallows every click
		## while `_context_menu.visible`.
		if _test_zone_controller != null and _test_zone_controller.is_targeting():
			var aim_cell := _screen_to_tile(mb.position)
			if aim_cell != INVALID_CELL:
				_test_zone_controller.handle_targeting_click(aim_cell)
			get_viewport().set_input_as_handled()
			return

		## TEST-ZONE placeholder (2026-07-21): right-click on a detonatable test
		## prop opens the context menu instead of moving the agent there.
		##
		## Removed by `ecdae79` ("now G-key only") and RESTORED 2026-08-10 on the
		## Director's call: "vamos manter as granadas antigas que estavam no chão,
		## e o menu para detonar funcionando, de maneira que você possa continuar
		## fazendo testes até a gente fechar a coreografia e a otimização da
		## explosão." The two routes are not rivals — G aims and throws a NEW
		## grenade, this detonates one already lying on the floor. Removing it also
		## silently killed the test_zone_menu / test_zone_detonate /
		## test_zone_escape capture actions, which drive exactly this click.
		var grenade_index := -1
		if _test_zone_controller != null:
			grenade_index = _test_zone_controller.hit_test(mb.position)
		if grenade_index != -1:
			_test_zone_controller.open_menu_for(grenade_index)
			get_viewport().set_input_as_handled()
			return
		## WEAPON-FIRE-01: same pattern, second prop type. Checked AFTER the
		## grenades because the bench sits behind them and a click that could
		## plausibly be either should take the nearer, consumable one.
		var weapon_index := -1
		if _weapon_bench_controller != null:
			weapon_index = _weapon_bench_controller.hit_test(mb.position)
		if weapon_index != -1:
			_weapon_bench_controller.open_menu_for(weapon_index)
			get_viewport().set_input_as_handled()
			return
		## §6c / B1: right-click an ENEMY opens "Atirar" instead of walking the
		## agent onto him. Checked LAST of the three prop routes and before the
		## move fallback: the grenades and the bench are consumable test props
		## that a click should prefer, and a guard's cell is never a legal move
		## target anyway (it is in the navigation blocked set), so this branch
		## takes a click that would otherwise have been silently discarded.
		var guard_index := -1
		if _agent_shot_controller != null:
			guard_index = _agent_shot_controller.hit_test(mb.position)
		if guard_index != -1:
			_agent_shot_controller.open_menu_for(guard_index)
			get_viewport().set_input_as_handled()
			return
		var move_target := _screen_to_tile(mb.position)
		if move_target != INVALID_CELL:
			_selection_controller.handle_move_click(move_target)
		get_viewport().set_input_as_handled()
		return

	## ── Left button: click to select (camera pan delegated to CameraController) ──────────
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mb.pressed:
		## Left mouse released: check if it was just a click (not a drag handled by CameraController)
		var cell := _screen_to_tile(mb.position)

		## UI-02 / INPUT-SPLIT-01: on TOUCH devices the (emulated) left tap
		## drives the full mobile flow — first tap selects, tapping the
		## selected cell again walks (handle_tile_click). On desktop the left
		## button only ever selects; movement lives on the right button.
		if cell != INVALID_CELL:
			## T-TAP: while a throw is being aimed the LEFT button also belongs
			## to it — this is the TOUCH path, where the emulated left tap is the
			## only button there is. On desktop the same flow now lives on the
			## right button (see the right-button branch above, and the
			## Director's 2026-08-19 standardisation); both routes call the same
			## `handle_targeting_click()`, so select-then-confirm behaves
			## identically whichever device is driving it.
			if _test_zone_controller != null \
					and _test_zone_controller.handle_targeting_click(cell):
				get_viewport().set_input_as_handled()
				return
			if DisplayServer.is_touchscreen_available():
				_handle_tile_click(cell)
			else:
				_set_selected_cell(cell)


## P-FILM (Director, 2026-08-09): "queria ver se a gente consegue fazer um
## filmstrip com todos os frames da explosão pra analisar a sequência com mais
## calma." Dumps every frame of ONE detonation as a numbered PNG;
## tools/persistent/build_filmstrip.py drives this and stitches the contact
## sheet.
##
## ONE detonation, not one boot per frame — and that is the whole point, not an
## optimization. Room.spawn_blast_burst() places its embers with randf_range(),
## so frames stitched from separate runs would show the fire jumping between
## tiles. Every frame here comes from the same blast.
##
## MUST be run with `--fixed-fps 60` (the Python driver passes it). Grabbing the
## viewport every frame is a GPU→CPU readback and drags real frame time to a
## crawl, which would matter enormously: the destruction front and the strobe
## are frame-driven and stay exact no matter how slow the capture runs, but the
## fire and smoke advance on DELTA, so at the harness's real ~8 fps they would
## age ~7× too fast per frame and the filmstrip would lie about the effect the
## Director is trying to judge. `--fixed-fps` pins every delta to 1/60 s and
## makes the strip a faithful 60 fps read of all three beats at once.
## CHARACTER Part 3 / §9 #12 — every frame of ONE walk, at one step duration.
##
## Feeds `p3_step_bracket.py`, which runs this once per candidate duration and
## assembles the panels blind. The duration is swept through `agent.step_duration`
## — the same field the game reads — rather than through a test-only path, so what
## the Director judges is the real movement code at a different number.
##
## `--fixed-fps 60` is MANDATORY here for the same reason build_filmstrip.py
## states it: grabbing the viewport every frame is a GPU→CPU readback that drags
## real frame time to a crawl, and the step tween advances on DELTA. Without the
## pin, every panel would play at the capture's speed instead of its own, which
## is precisely the quantity under judgement.
func _capture_walk_filmstrip() -> void:
	var ms_env := OS.get_environment("INFILTRAITOR_WALK_STEP_MS")
	var step_ms: float = float(ms_env) if ms_env.is_valid_float() else 130.0
	var gus_env := OS.get_environment("INFILTRAITOR_WALK_GUS")
	var gus: int = gus_env.to_int() if gus_env.is_valid_int() else 4
	var out_name := OS.get_environment("INFILTRAITOR_WALK_OUT")
	if out_name == "":
		out_name = "walk_%04dms" % int(step_ms)

	var out_dir := ProjectSettings.globalize_path("res://") + "Screenshots/walk/" + out_name
	DirAccess.make_dir_recursive_absolute(out_dir)
	var existing := DirAccess.open(out_dir)
	if existing != null:
		for f in existing.get_files():
			if f.begins_with("frame_") and f.ends_with(".png"):
				existing.remove(f)

	## A straight, walkable run of `gus` tiles. Tried in a fixed order and the
	## first clear one wins, so every duration in the bracket walks the SAME path
	## — four panels crossing different geometry would compare scenery, not speed.
	var path: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var candidate: Array[Vector2i] = [agent.cell]
		var clear := true
		for i in range(1, gus + 1):
			var c: Vector2i = agent.cell + dir * i
			if not _is_cell_inside_room(c) or _blocked_cells.has(c):
				clear = false
				break
			candidate.append(c)
		if clear:
			path = candidate
			break
	if path.is_empty():
		push_error("[P3-WALK] no clear %d-GU run from %s in any direction" % [gus, agent.cell])
		return

	agent.step_duration = step_ms / 1000.0
	## INFILTRAITOR_WALK_PHASES subsamples the baked cycle, so the frame COUNT can
	## be bracketed against the identical poses instead of a re-bake.
	var phases_env := OS.get_environment("INFILTRAITOR_WALK_PHASES")
	if phases_env.is_valid_int() and agent.sprite != null:
		agent.sprite.set_walk_phase_quantise(phases_env.to_int())
	if _camera_controller != null:
		## Framed on the MIDDLE of the run, not on the agent, so the camera never
		## moves during the capture. A camera that tracks would hide exactly the
		## thing being judged: how fast the figure crosses the ground.
		_camera_controller.focus_on(agent._cell_to_world(path[int(path.size() / 2)]))
	if _fow_controller != null:
		_fow_controller.reveal_around(agent.cell, 12)
	for _s in range(60):
		await get_tree().process_frame

	## Total frames the move will occupy at the pinned 60 fps, plus a short tail
	## so the last panel shows him STOPPED rather than cutting mid-stride.
	var frame_count: int = int(ceil(float(gus) * step_ms / 1000.0 * 60.0)) + 12
	print("[P3-WALK] %s: %d GUs at %.0f ms -> %.2f m/s, %d frames" % [
		out_name, gus, step_ms, 1.60 / (step_ms / 1000.0), frame_count])

	agent.move_along_path(path)
	for i in range(frame_count):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img == null:
			push_error("[P3-WALK] null viewport image at frame %d" % i)
			continue
		img.save_png("%s/frame_%03d.png" % [out_dir, i])
	print("[P3-WALK] wrote %d frames to %s" % [frame_count, out_dir])


## Give the dev-capture actions something to detonate. PLAYGROUND stopped
## shipping floor grenades on 2026-08-17 when they were retired (Director:
## "vamos fazer os testes com o agente mesmo"), and that silently killed both
## capture tools that index them: P-FILM wrote zero frames, and the four-view
## rotation-persistence capture detonated nothing. Between them the project lost
## its frame-by-frame view of a blast AND its check that crater/soot survive a
## rotation.
##
## Seeded here rather than by putting grenades back on the map: every caller is
## an env-gated dev-capture action the player never reaches, so the retirement
## stands untouched for real play. The cells come from TEST_ZONE_GRENADE_GUS —
## the constant the reform deliberately kept for its calibration history — and
## they are still correct: verified against maps/PLAYGROUND.map.json that the
## four material walls remain at gu 2-4/7-9/12-14/17-19 on row 2, unmoved when
## the board grew 24x16 -> 44x22.
## `INFILTRAITOR_GRENADE_GUS="34,5;27,5"` overrides the seeded cells.
##
## TEST_ZONE_GRENADE_GUS covers the four HARD walls only (gu 3/8/13/18 on row 5),
## which is its calibration history and stays untouched. The five newer materials
## sit at gu 22..40 and no dev capture could reach them — so verifying anything
## about a blast on fabric, cardboard, plywood, brick or glass meant editing a
## constant. This is the same env-gated dev seam the rest of this file uses.
func _seed_dev_grenades_if_empty(tag: String) -> void:
	if _test_zone_controller == null or not _test_zone_controller._grenades.is_empty():
		return
	var cells: Array = TEST_ZONE_GRENADE_GUS
	var env := OS.get_environment("INFILTRAITOR_GRENADE_GUS")
	if env != "":
		var parsed: Array = []
		for pair in env.split(";", false):
			var xy := pair.split(",")
			if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
				parsed.append(Vector2i(xy[0].strip_edges().to_int(), xy[1].strip_edges().to_int()))
			else:
				push_warning("[%s] INFILTRAITOR_GRENADE_GUS: cannot parse %r — expected \"x,y;x,y\"" % [tag, pair])
		if not parsed.is_empty():
			cells = parsed
	for seed_gu in cells:
		_test_zone_controller.add_grenade(seed_gu)
	print("[%s] seeded %d dev grenade(s) — PLAYGROUND no longer ships them" % [
		tag, _test_zone_controller._grenades.size()])


## WEAPON_MASTER_PLAN §6c Part E — the evidence capture for "the agent shoots".
##
## Drives the REAL click path, not the controller's methods: a synthetic
## right-click through _unhandled_input() at the guard's own hit-test cell, then
## a parsed Enter InputEventKey through the focused Button. Same standing
## precedent, and the same reason, as test_zone_detonate — calling
## fire_at_active() directly would prove the damage pipeline works and say
## nothing about whether the menu can be reached.
##
## Both actor cells are overridable because the wave's whole claim is
## geometric ("GU A to GU B, and the wall C behind it"), and the guard PATROLS —
## an unattended capture that let him wander would photograph a different shot
## every run. INFILTRAITOR_SHOT_AGENT_CELL / INFILTRAITOR_SHOT_GUARD_CELL pin
## both ends; unset, it fires from wherever the two actors happen to stand,
## which is the honest default for a "does this work at all" run.
func _capture_agent_shot() -> void:
	if agent == null or _guards.is_empty():
		push_error("[AGENT-SHOT-CAPTURE] needs an agent AND at least one guard — PLAYGROUND ships one of each.")
		return
	var guard_env_idx := OS.get_environment("INFILTRAITOR_SHOT_GUARD_INDEX")
	var guard_idx: int = guard_env_idx.to_int() if guard_env_idx.is_valid_int() else 0
	if guard_idx < 0 or guard_idx >= _guards.size():
		push_error("[AGENT-SHOT-CAPTURE] guard index %d out of range (%d on the map)"
			% [guard_idx, _guards.size()])
		return
	var guard = _guards[guard_idx]
	var agent_env := OS.get_environment("INFILTRAITOR_SHOT_AGENT_CELL")
	if agent_env != "":
		var ap := agent_env.split(",")
		if ap.size() == 2:
			agent.set_cell(Vector2i(ap[0].to_int(), ap[1].to_int()))
	## GuardEnemy has NO set_cell() — that is the Agent's API, and assuming the
	## two actors shared it cost one real run to find out (the SCRIPT ERROR
	## aborted the rest of this function and the process still exited 0, exactly
	## the trap CLAUDE.md's selftest rule describes). A guard's cell is placed by
	## its own two fields plus the world transform, the same three lines
	## `setup()` and `reset_to_route_start()` both use.
	var guard_env := OS.get_environment("INFILTRAITOR_SHOT_GUARD_CELL")
	if guard_env != "":
		var gp := guard_env.split(",")
		if gp.size() == 2:
			guard.cell = Vector2i(gp[0].to_int(), gp[1].to_int())
			guard.position = guard._cell_to_world(guard.cell)
			guard.queue_redraw()

	## Frame BOTH actors: a capture centred on either one alone cannot show the
	## trajectory, which is the thing being verified.
	var mid: Vector2i = (agent.cell + guard.cell) / 2
	if _camera_controller != null:
		_camera_controller.focus_on(agent._cell_to_world(mid))
	var zoom_env := OS.get_environment("INFILTRAITOR_SHOT_ZOOM")
	if zoom_env.is_valid_float() and _camera_controller != null:
		_camera_controller.set_zoom_for_capture(zoom_env.to_float())
	if _fow_controller != null:
		_fow_controller.reveal_around(mid, 24)
	_recompute_occlusion()
	for _i in range(12):
		await get_tree().process_frame

	print("[AGENT-SHOT-CAPTURE] agent at %s, guard at %s" % [agent.cell, guard.cell])
	## NAMED, not auto_-prefixed. Screenshots/history/ rotates to the 50 most
	## recent `auto_` files and never touches anything else, so a capture meant to
	## be CITED has to opt out of the rotation by not carrying that prefix —
	## measured 2026-08-03, when 16 of 23 cited captures had already been pruned.
	var shot_dir := ProjectSettings.globalize_path("res://") + "Screenshots/history"
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var tag := OS.get_environment("INFILTRAITOR_SHOT_TAG")
	if tag == "":
		tag = "default"

	## The real right-click, at the guard's own GU floor cell — the hitbox
	## AgentShotController.hit_test() actually reads.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _tile_to_screen_center(guard.cell)
	_unhandled_input(click)
	for _j in range(12):
		await get_tree().process_frame
	if _context_menu == null or not _context_menu.visible:
		push_error("[AGENT-SHOT-CAPTURE] the right-click did not open a menu on the guard — B1's routing is not reaching AgentShotController.hit_test().")
		return
	## FRAME 1 — the menu open on the ENEMY (B1) and the weapon UP (B4). Taken
	## before the trigger because both are true only while the menu is open: the
	## shot itself resolves in a single frame and lowers the weapon on its way
	## out.
	await _save_shot_frame(shot_dir, "shot_%s_1_aim.png" % tag)

	## INFILTRAITOR_SHOT_CONTROL=1 — the CONTROL run: everything identical up to
	## and including the menu, then Escape instead of Enter. It exists because
	## "15 voxels DENTED" and "a mark you can see" are different claims, and the
	## stone facade is busy enough that squinting at one screenshot cannot tell
	## them apart. Two frames from the same boot, the same camera path and the
	## same binary differ ONLY by the shot, so a diff over the wall region is a
	## measurement rather than an impression.
	var control := OS.get_environment("INFILTRAITOR_SHOT_CONTROL") == "1"
	var fire_key: Key = KEY_ESCAPE if control else KEY_ENTER
	if control:
		print("[AGENT-SHOT-CAPTURE] CONTROL run — cancelling instead of firing")
	var key_down := InputEventKey.new()
	key_down.keycode = fire_key
	key_down.pressed = true
	Input.parse_input_event(key_down)
	var key_up := InputEventKey.new()
	key_up.keycode = fire_key
	key_up.pressed = false
	Input.parse_input_event(key_up)

	## Long enough for the frame-spread render pass to finish and the damage to
	## be on screen. The TRACER is deliberately gone by then (it lives ~0.2 s):
	## a capture of the streak needs a much shorter wait, which is what
	## INFILTRAITOR_SHOT_WAIT_FRAMES is for.
	## FRAME 2 — the decorative projectile in flight (Part D). TracerOverlay
	## holds for 0.05 s and fades over 0.16 s, so this frame has to be taken
	## early or there is nothing to photograph; the number is derived from those
	## two constants rather than guessed.
	var tracer_env := OS.get_environment("INFILTRAITOR_SHOT_TRACER_FRAMES")
	var tracer_wait: int = tracer_env.to_int() if tracer_env.is_valid_int() else 4
	for _t in range(maxi(tracer_wait, 0)):
		await get_tree().process_frame
	await _save_shot_frame(shot_dir, "shot_%s_2_tracer.png" % tag)

	## FRAME 3 — the damage, once the frame-spread render pass has landed it.
	var wait_env := OS.get_environment("INFILTRAITOR_SHOT_WAIT_FRAMES")
	var wait: int = wait_env.to_int() if wait_env.is_valid_int() else 90
	for _k in range(maxi(wait, 0)):
		await get_tree().process_frame
	## Reframe onto the impact before the last frame: the wall the round reached
	## is often nowhere near the shooter (D26 — a miss keeps travelling), and a
	## capture centred on the shooter proves the shot happened while showing none
	## of what it did.
	var impact_env := OS.get_environment("INFILTRAITOR_SHOT_IMPACT_CELL")
	if impact_env != "" and _camera_controller != null:
		var ip := impact_env.split(",")
		if ip.size() == 2:
			_camera_controller.focus_on(agent._cell_to_world(
				Vector2i(ip[0].to_int(), ip[1].to_int())))
			var iz := OS.get_environment("INFILTRAITOR_SHOT_IMPACT_ZOOM")
			if iz.is_valid_float():
				_camera_controller.set_zoom_for_capture(iz.to_float())
			for _f in range(20):
				await get_tree().process_frame
	await _save_shot_frame(shot_dir, "shot_%s_3_damage.png" % tag)


## One named capture frame for the §6c evidence set. Separate from
## _capture_screenshot_to_file() because that one owns the Shift+P destination
## and this one must land in history/ under a name the rotation ignores.
## MATERIALS_MASTER_PLAN M3-1 — the measurement §3.4 asks for.
##
## §3.4 claims the "cardboard blocks light until it burns" behaviour is FREE:
## light never reads `damage_state`, `build_occupancy()` is built from
## `get_used_cells()`, and a DESTROYED voxel has its cell erased — so burning is
## already an opacity change and needs no coupling to LIGHT_MASTER_PLAN. That
## claim was READ OFF THE CODE and marked as such. This runs it.
##
## Three passes in ONE boot, because a count of changed cells means nothing
## without knowing what the instrument reports when nothing happened:
##   CONTROL   rebuild the light field, change nothing. Must report 0.
##   ONE VOXEL destroy a single voxel of a soft wall. Must report > 0.
##   WHOLE     destroy every voxel of that material. The milestone's real case.
##
## `INFILTRAITOR_BURN_PROBE_MATERIAL` picks the material (default fabric — the
## one the Director says burns entirely and fastest).
var _burn_probe_targets: Array = []


func _capture_light_burn_probe() -> void:
	if _voxel_renderer == null or _edge_registry == null:
		push_error("[BURN-PROBE] needs a voxel renderer and an edge registry.")
		return
	var material := OS.get_environment("INFILTRAITOR_BURN_PROBE_MATERIAL")
	if material == "":
		material = "fabric"

	var targets: Array = []
	for slice in _edge_registry.all_slices():
		if slice.material == material:
			targets.append(slice)
	if targets.is_empty():
		push_error("[BURN-PROBE] no slice of material %r on this map." % material)
		return
	_burn_probe_targets = targets
	var voxel_total: int = 0
	for slice in targets:
		voxel_total += slice.voxels.size()
	print("[BURN-PROBE] material=%s slices=%d voxels=%d" % [material, targets.size(), voxel_total])

	## Frame the wall, so the two captures are comparable and show the thing.
	## voxel_to_gu() is not optional here: a Slice's voxels carry VOXEL grid
	## coordinates (8 per GU axis), so handing grid_pos straight to
	## _cell_to_world() aims the camera roughly eight boards away — which is
	## exactly what the first run of this probe photographed, an empty screen.
	var focus: Vector2i = Vector2i.ZERO
	if not targets[0].voxels.is_empty():
		focus = GeometryCoords.voxel_to_gu(targets[0].voxels[0].grid_pos)
	if agent != null and _camera_controller != null:
		_camera_controller.focus_on(agent._cell_to_world(focus))
	if _fow_controller != null:
		_fow_controller.reveal_around(focus, 24)
	_recompute_occlusion()
	for _i in range(12):
		await get_tree().process_frame

	var shot_dir := ProjectSettings.globalize_path("res://") + "Screenshots/history"
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var tag := OS.get_environment("INFILTRAITOR_SHOT_TAG")
	if tag == "":
		tag = material
	await _save_shot_frame(shot_dir, "burn_%s_1_intact.png" % tag)

	var base: Dictionary = _burn_probe_snapshot()
	print("[BURN-PROBE] baseline: %d placed cells" % base.size())
	_burn_probe_passages("baseline")

	## CONTROL — the same full rebuild, with nothing destroyed. Any non-zero
	## here and every number below it is noise wearing a value.
	_repaint_voxel_light_buckets(false)
	await get_tree().process_frame
	_burn_probe_report("CONTROL   (nothing destroyed)", base, _burn_probe_snapshot())

	## ONE VOXEL — §3.4's own wording. The sharpest form of the question: does
	## the field move at all for a single erased cell, with no opacity state?
	var one: Array = [BlastCalculator.damage_entry(
		targets[0].voxels[0], Voxel.DamageState.DESTROYED, false)]
	BlastCalculator.commit_damage(one)
	bump_world_revision()
	_burn_probe_render()
	_repaint_voxel_light_buckets(false)
	await get_tree().process_frame
	var after_one: Dictionary = _burn_probe_snapshot()
	_burn_probe_report("ONE VOXEL (%s lvl %d)" % [targets[0].voxels[0].grid_pos,
		targets[0].voxels[0].level], base, after_one)

	## WALLS — every Slice of this material. "fabric burns entirely, always"
	## (§3.1) is the case the milestone actually needs.
	var wall_entries: Array = []
	for slice in targets:
		for v in slice.voxels:
			if v.damage_state != Voxel.DamageState.DESTROYED:
				wall_entries.append(BlastCalculator.damage_entry(
					v, Voxel.DamageState.DESTROYED, false))
	BlastCalculator.commit_damage(wall_entries)
	bump_world_revision()
	_burn_probe_render()
	_repaint_voxel_light_buckets(false)
	for _j in range(6):
		await get_tree().process_frame
	_burn_probe_report("WALLS     (%d more voxels)" % wall_entries.size(),
		base, _burn_probe_snapshot())
	await _save_shot_frame(shot_dir, "burn_%s_2_walls.png" % tag)

	## OBJECT — and the reason there is a fourth pass at all. The first run of
	## this probe destroyed every fabric SLICE and photographed a block that was
	## still standing: a block's interior fill and its roof are SLABS
	## (Slab.Role.INTERIOR / CEILING), which no Slice contains. "Burns entirely"
	## therefore cannot be expressed as "destroy the edges" — M3-3 needs an
	## object scope that spans both registries. Found by looking at the capture,
	## not by reading the code.
	var slab_entries: Array = []
	var by_role: Dictionary = {}
	if _slab_registry != null:
		for slab in _slab_registry.all_slabs():
			if slab.material != material:
				continue
			var role_name: String = Slab.role_name(slab.role)
			by_role[role_name] = int(by_role.get(role_name, 0)) + slab.voxels.size()
			for v in slab.voxels:
				if v.damage_state != Voxel.DamageState.DESTROYED:
					slab_entries.append(BlastCalculator.damage_entry(
						v, Voxel.DamageState.DESTROYED, false))
	print("[BURN-PROBE] %s slabs by role: %s" % [material, by_role])
	BlastCalculator.commit_damage(slab_entries)
	bump_world_revision()
	_burn_probe_render()
	_repaint_voxel_light_buckets(false)
	for _k in range(6):
		await get_tree().process_frame
	_burn_probe_report("OBJECT    (+%d slab voxels)" % slab_entries.size(),
		base, _burn_probe_snapshot())

	## ⚠️ WAIT FOR THE SMOKE, or the capture photographs the wrong thing.
	## `VoxelRenderer.voxel_destroyed` fires per voxel and room.gd dispatches it
	## to the smoke/spark/debris overlays — so erasing 3 080 cells in one frame
	## raises a dust cloud that HIDES the hole it is announcing. The first three
	## runs of this probe produced a pale mass exactly where the wall had been,
	## and it took a census (0 fabric voxels intact, 3 080 cells gone) to
	## establish that the geometry really was gone and the mass was VFX.
	var settle_env := OS.get_environment("INFILTRAITOR_BURN_PROBE_SETTLE_FRAMES")
	var settle: int = settle_env.to_int() if settle_env.is_valid_int() else 240
	for _s in range(maxi(settle, 0)):
		await get_tree().process_frame
	await _save_shot_frame(shot_dir, "burn_%s_3_object.png" % tag)

	## What is LEFT of the object, counted rather than eyeballed — the capture
	## still shows a pale mass where the block was, and "that is the interior"
	## is a guess until something counts it.
	var left_slice: int = 0
	var left_slab: int = 0
	for slice in _edge_registry.all_slices():
		if slice.material != material:
			continue
		for v in slice.voxels:
			if v.damage_state != Voxel.DamageState.DESTROYED:
				left_slice += 1
	if _slab_registry != null:
		for slab in _slab_registry.all_slabs():
			if slab.material != material:
				continue
			for v in slab.voxels:
				if v.damage_state != Voxel.DamageState.DESTROYED:
					left_slab += 1
	print("[BURN-PROBE] %s voxels still intact after the object burn: slices=%d slabs=%d"
		% [material, left_slice, left_slab])

	## ...and WHAT ELSE stands in the same GUs. Zero fabric voxels left and a
	## pale mass still on screen means the remainder belongs to a container
	## carrying a DIFFERENT material id, which is a fact about how a block is
	## composed and worth having in writing.
	var burnt_gus: Dictionary = {}
	for slice in targets:
		if not slice.voxels.is_empty():
			burnt_gus[GeometryCoords.voxel_to_gu(slice.voxels[0].grid_pos)] = true
	var others: Dictionary = {}
	for slice in _edge_registry.all_slices():
		if slice.voxels.is_empty():
			continue
		if not burnt_gus.has(GeometryCoords.voxel_to_gu(slice.voxels[0].grid_pos)):
			continue
		var alive: int = 0
		for v in slice.voxels:
			if v.damage_state != Voxel.DamageState.DESTROYED:
				alive += 1
		others["SLICE:" + slice.material] = int(others.get("SLICE:" + slice.material, 0)) + alive
	if _slab_registry != null:
		for slab in _slab_registry.all_slabs():
			if not burnt_gus.has(slab.gu_cell):
				continue
			var alive2: int = 0
			for v in slab.voxels:
				if v.damage_state != Voxel.DamageState.DESTROYED:
					alive2 += 1
			var k: String = "SLAB:%s:%s" % [slab.material, Slab.role_name(slab.role)]
			others[k] = int(others.get(k, 0)) + alive2
	print("[BURN-PROBE] still standing in the same GUs %s: %s" % [burnt_gus.keys(), others])

	## M3-2 ON THE REAL MAP. A green selftest does not mean the feature fires on
	## a real map (CLAUDE.md, and the floor-dent path is the standing example),
	## and the passage query's fixtures are synthetic by design. This asks the
	## real EdgeRegistry, after a real object burn, what the wall now offers.
	_burn_probe_passages("after the object burn", targets)

	## THE HALF OF §3.4 THAT IS NOT FREE, checked in the same boot rather than
	## argued. The VOXEL light field reads occupancy; the LAMP's shadow does not
	## — ShadowProjector runs on `_blocked_cells`, a GU-resolution structure
	## built by RoomBuilder and re-fed only on a rebuild. If the wall's GUs are
	## still in it after every voxel is gone, then "light passes through the
	## burnt wall" is true of the visual shading and false of the cast shadow.
	var still_blocked: Array = []
	for slice in targets:
		if slice.voxels.is_empty():
			continue
		var gu: Vector2i = GeometryCoords.voxel_to_gu(slice.voxels[0].grid_pos)
		if _blocked_cells.has(gu) and not still_blocked.has(gu):
			still_blocked.append(gu)
	print("[BURN-PROBE] shadow map after the burn: %d of the burnt GUs are STILL in _blocked_cells %s"
		% [still_blocked.size(), still_blocked])


## ⚠️ The probe renders through the RENDERER, not through `_tic_voxel_system()`,
## and that is a correction rather than a preference. `_tic_voxel_system()` calls
## `_tic_slab_system()`, which CLEARS every slab's dirty flags **without
## rendering them** — its comment still says "_slab_registry stays empty until
## Part 2, so dirty_slabs() is always []", which stopped being true when floors
## and roofs became slabs. Measured here: the OBJECT pass destroyed 1672 slab
## voxels and moved `cells_gone` by ZERO, because the flags were consumed before
## anything drew. Reported to the Director rather than fixed inside a
## measurement task.
## M3-2 ON THE REAL MAP. A green selftest does not mean the feature fires on a
## real map (CLAUDE.md, and the floor-dent path is the standing example) — the
## passage query's own fixtures are synthetic by design. This asks the real
## EdgeRegistry, before and after a real burn, what the wall offers.
func _burn_probe_passages(label: String, slices: Array = []) -> void:
	var pool: Array = slices
	if pool.is_empty():
		pool = _burn_probe_targets
	var tally: Dictionary = {}
	var seen: Dictionary = {}
	for slice in pool:
		if seen.has(slice.edge_id):
			continue
		seen[slice.edge_id] = true
		var e: Edge = _edge_registry.get_edge(slice.edge_id)
		if e == null:
			continue
		var pc: String = PassageQuery.class_name_of(PassageQuery.passage_class(e, _edge_registry))
		tally[pc] = int(tally.get(pc, 0)) + 1
	print("[BURN-PROBE] passage_class over %d edges (%s): %s" % [seen.size(), label, tally])


func _burn_probe_render() -> void:
	_voxel_renderer.process_dirty(_edge_registry)
	if _slab_registry != null:
		_voxel_renderer.process_dirty_slabs(_slab_registry)


## Every placed cell's light bucket, keyed by (x, y, level). The fixed set is
## the BASELINE's — a cell that stops existing is reported as removed rather
## than silently dropping out of the comparison, which is the difference between
## "the light changed" and "the geometry did".
func _burn_probe_snapshot() -> Dictionary:
	var out: Dictionary = {}
	if _voxel_light_field == null:
		return out
	for level in range(_voxel_renderer._voxel_layers.size()):
		for cell in _voxel_renderer._voxel_layers[level].get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = _voxel_light_field.bucket_for(cell, level)
	for level in _voxel_renderer._negative_voxel_layers.keys():
		for cell in _voxel_renderer._negative_voxel_layers[level].get_used_cells():
			out[Vector3i(cell.x, cell.y, level)] = _voxel_light_field.bucket_for(cell, level)
	return out


func _burn_probe_report(label: String, base: Dictionary, now: Dictionary) -> void:
	var removed: int = 0
	var changed: int = 0
	var brighter: int = 0
	var darker: int = 0
	for key in base:
		if not now.has(key):
			removed += 1
			continue
		if now[key] == base[key]:
			continue
		changed += 1
		if int(now[key]) > int(base[key]):
			brighter += 1
		else:
			darker += 1
	print("[BURN-PROBE] %-34s cells_gone=%4d  bucket_changed=%4d  (brighter %d / darker %d)"
		% [label, removed, changed, brighter, darker])


func _save_shot_frame(dir_path: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("[AGENT-SHOT-CAPTURE] null viewport image for %s" % file_name)
		return
	var full := "%s/%s" % [dir_path, file_name]
	img.save_png(full)
	print("[AGENT-SHOT-CAPTURE] wrote %s" % full)


## THE SHOT, FRAME BY FRAME, WITH EACH FRAME'S OWN DURATION.
##
## Built 2026-08-19 on the Director's report that everything stutters. Per-phase
## CPU profiling said the trigger frame fell from 581 ms to ~94 ms, and the
## report says it got WORSE — which is exactly the shape a profile cannot see:
## deferring work does not delete it, and a stall broken into six stalls across
## six frames can read worse than one long one. Only a per-FRAME timeline shows
## that, so this prints one line per frame and saves one PNG per frame.
##
## The number that matters is the frame DELTA, not the CPU inside any one
## function: a 60 Hz frame is 16.7 ms, and anything above that is a frame the
## player did not get.
func _capture_shot_filmstrip() -> void:
	var out_dir := ProjectSettings.globalize_path("res://") + "Screenshots/filmstrip_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var existing := DirAccess.open(out_dir)
	if existing != null:
		for f in existing.get_files():
			if f.begins_with("shot_") and f.ends_with(".png"):
				existing.remove(f)

	if _guards.is_empty():
		push_error("[SHOT-FILM] needs a guard")
		return
	var idx_env := OS.get_environment("INFILTRAITOR_SHOT_GUARD_INDEX")
	var guard_idx: int = idx_env.to_int() if idx_env.is_valid_int() else 0
	guard_idx = clampi(guard_idx, 0, _guards.size() - 1)
	## W-TUNE-01: the sheet's SUBJECT is selectable, because the two things worth
	## watching are 12 GU apart. Centred between shooter and target (the default)
	## the figure and the muzzle flash read and the wall does not; the round is
	## gone before it arrives by design (TRACER_FLIGHT_FRAMES), so a wall-centred
	## sheet shows the damage and the smoke and no projectile. Pick per question.
	var focus_env := OS.get_environment("INFILTRAITOR_SHOT_FILM_FOCUS")
	if _camera_controller != null and agent != null:
		var focus_cell: Vector2i = (agent.cell + _guards[guard_idx].cell) / 2
		var fp := focus_env.split(",")
		if fp.size() == 2 and fp[0].is_valid_int() and fp[1].is_valid_int():
			focus_cell = Vector2i(fp[0].to_int(), fp[1].to_int())
		_camera_controller.focus_on(agent._cell_to_world(focus_cell))
	var zoom_env := OS.get_environment("INFILTRAITOR_SHOT_ZOOM")
	_camera_controller.set_zoom_for_capture(
		zoom_env.to_float() if zoom_env.is_valid_float() else 0.5)
	if _fow_controller != null:
		_fow_controller.reveal_around(agent.cell, 26)
	for _i in range(15):
		await get_tree().process_frame

	## W-TUNE-02: prove the WEAPON KEYS, not just the env override. The override
	## sets `_weapon_id` directly and would pass whether or not the InputMap
	## action, the signal and set_weapon() are wired at all; parsing the real digit
	## key exercises every link in that chain, and the tier print then says which
	## weapon actually fired. 1 rifle · 2 pistol · 3 shotgun.
	var wkey_env := OS.get_environment("INFILTRAITOR_SHOT_WEAPON_KEY")
	if wkey_env.is_valid_int():
		var wk_down := InputEventKey.new()
		wk_down.keycode = KEY_0 + wkey_env.to_int()
		wk_down.pressed = true
		Input.parse_input_event(wk_down)
		var wk_up := InputEventKey.new()
		wk_up.keycode = KEY_0 + wkey_env.to_int()
		wk_up.pressed = false
		Input.parse_input_event(wk_up)
		await get_tree().process_frame

	var frames_env := OS.get_environment("INFILTRAITOR_SHOT_FILM_FRAMES")
	var count: int = frames_env.to_int() if frames_env.is_valid_int() else 40
	var save_images: bool = OS.get_environment("INFILTRAITOR_SHOT_FILM_SAVE") == "1"
	var fire_at: int = 6
	var last_us: int = Time.get_ticks_usec()
	var over_budget: int = 0
	var worst_ms: float = 0.0
	## The MENU opens well before the trigger, exactly as a player does it. The
	## first version opened and fired on the same frame and charged the trigger
	## with the one-off cost of loading the `aimed` grip's textures — a real cost,
	## but one that belongs to the aim, not to the shot.
	var menu_at: int = 1
	## A SECOND SHOT, on demand, because "expensive" and "expensive ONCE" are
	## different findings and no single-shot timeline can tell them apart. The
	## impact frame still costs ~300 ms with 80 ms of CPU in it and zero
	## alternatives minted (W-PRECOOK-02), so the remaining time is engine-side —
	## and the two candidates, a first GPU upload of the damage-variant page and a
	## first particle-material compile, are BOTH one-offs that would vanish on a
	## second shot. INFILTRAITOR_SHOT_FILM_SECOND_AT=<frame> opens the menu again
	## at that frame and fires five frames later, exactly as the first one does.
	var second_env := OS.get_environment("INFILTRAITOR_SHOT_FILM_SECOND_AT")
	var menu2_at: int = second_env.to_int() if second_env.is_valid_int() else -1
	var fire2_at: int = (menu2_at + fire_at - menu_at) if menu2_at >= 0 else -1
	for i in range(count):
		if i == menu_at or i == menu2_at:
			_agent_shot_controller.open_menu_for(guard_idx)
		if i == fire_at or i == fire2_at:
			_agent_shot_controller.fire_at_active()
		await RenderingServer.frame_post_draw
		var now_us: int = Time.get_ticks_usec()
		var ms: float = float(now_us - last_us) / 1000.0
		last_us = now_us
		if ms > 17.0:
			over_budget += 1
		worst_ms = maxf(worst_ms, ms)
		print("[SHOT-FILM] frame %02d  %7.1f ms%s" % [i, ms,
			"   <-- FIRE" if i == fire_at else (
			"   <-- FIRE 2" if i == fire2_at else (
			"   <-- MENU" if i == menu_at else (
			"   <-- MENU 2" if i == menu2_at else (
			"   <-- DROPPED" if ms > 17.0 else ""))))])
		## ⚠️ SAVING A PNG COSTS ~180 ms, SO THE TIMED PASS MUST NOT SAVE ONE.
		## The first version of this harness saved every frame and reported 187 ms
		## and 184 ms for the two frames BEFORE the trigger — a flat baseline that
		## is the encoder, not the game. A frame-timing harness that pays 180 ms
		## per frame cannot measure a 90 ms stall; it can only measure itself.
		## `INFILTRAITOR_SHOT_FILM_SAVE=1` turns the images back on for a run
		## where the PICTURES are what is wanted and the timings are known junk.
		if save_images:
			var img := get_viewport().get_texture().get_image()
			if img != null:
				img.save_png("%s/shot_%02d.png" % [out_dir, i])
		await get_tree().process_frame
	print("[SHOT-FILM] %d of %d frames over 17 ms; worst %.1f ms%s" %
		[over_budget, count, worst_ms,
		"  (TIMINGS INVALID — images were saved)" if save_images else ""])


## The Director's report, made measurable (2026-08-19): *"digamos que eu joguei
## duas granadas no chao. Quando eu der o primeiro tiro com a shotgun, todos os
## voxels afetados pelas explosoes soltam fumaca novamente."*
##
## Throws N grenades, then fires one shot, and prints the `voxel_destroyed`
## dispatch count for each. A shot that only destroys its own voxels dispatches a
## number in single digits; a shot that re-fires every voxel the grenades already
## destroyed dispatches hundreds. That difference is the whole claim, and it
## cannot be read off a screenshot because smoke is transient.
func _capture_grenade_then_shot() -> void:
	_seed_dev_grenades_if_empty("VFX-LEAK")
	if _fow_controller != null and agent != null:
		_fow_controller.reveal_around(agent.cell, 24)
	for _i in range(12):
		await get_tree().process_frame

	var count_env := OS.get_environment("INFILTRAITOR_VFXLEAK_GRENADES")
	var grenades: int = count_env.to_int() if count_env.is_valid_int() else 2
	for g in range(grenades):
		_vfx_count_take()
		_test_zone_controller.open_menu_for(g)
		_test_zone_controller.detonate_active()
		for _j in range(150):
			await get_tree().process_frame
		print("[VFX-LEAK] grenade %d: %d voxel_destroyed dispatch(es)"
			% [g, _vfx_count_take()])

	if _guards.is_empty() or _agent_shot_controller == null:
		push_error("[VFX-LEAK] needs a guard and the shot controller")
		return
	_vfx_count_take()
	_agent_shot_controller.open_menu_for(0)
	await _agent_shot_controller.fire_at_active()
	for _k in range(90):
		await get_tree().process_frame
	print("[VFX-LEAK] the shot: %d voxel_destroyed dispatch(es)" % _vfx_count_take())


## The throw ANIMATION, frame by frame, in one boot. Same reasoning P-FILM's own
## header gives for the detonation strip: a sequence stitched from separate boots
## is not the sequence, and a per-frame claim about motion cannot be made from a
## single screenshot.
##
## No `--fixed-fps` requirement here, unlike P-FILM: the throw's phase is driven
## by accumulated delta against a duration, so it is frame-rate independent by
## construction and the strip cannot age it wrongly. The RANDOMNESS that forces
## P-FILM's fixed FPS lives in the blast's embers, which this strip never reaches.
func _capture_throw_filmstrip() -> void:
	var out_dir := ProjectSettings.globalize_path("res://") + "Screenshots/filmstrip_throw"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var existing := DirAccess.open(out_dir)
	if existing != null:
		for f in existing.get_files():
			if f.begins_with("throw_") and f.ends_with(".png"):
				existing.remove(f)

	_seed_dev_grenades_if_empty("THROW-FILM")
	if _camera_controller != null and agent != null:
		_camera_controller.focus_on(agent._cell_to_world(agent.cell))
	var zoom_env := OS.get_environment("INFILTRAITOR_SHOT_ZOOM")
	_camera_controller.set_zoom_for_capture(
		zoom_env.to_float() if zoom_env.is_valid_float() else 1.10)
	if _fow_controller != null:
		_fow_controller.reveal_around(agent.cell, 16)
	for _i in range(15):
		await get_tree().process_frame

	## Every frame is taken through the REAL flow — enter targeting, then throw —
	## not by calling play_throw() directly. What is being checked is that the
	## animation is reached by the actions a player takes.
	_test_zone_controller.enter_grenade_mode()
	var frames_env := OS.get_environment("INFILTRAITOR_THROW_FRAMES")
	var count: int = frames_env.to_int() if frames_env.is_valid_int() else 30
	var shot := 0
	for i in range(count):
		## Fire the throw a third of the way in, so the strip opens on the HELD
		## aim (which is what the player stares at) and then shows the release.
		if i == int(float(count) / 3.0):
			_test_zone_controller.execute_grenade_throw()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/throw_%02d.png" % [out_dir, shot])
			shot += 1
		await get_tree().process_frame
	print("[THROW-FILM] wrote %d frames to %s" % [shot, out_dir])


func _capture_detonation_filmstrip() -> void:
	var frames_env := OS.get_environment("INFILTRAITOR_FILMSTRIP_FRAMES")
	var frame_count: int = frames_env.to_int() if frames_env.is_valid_int() else 24
	var index_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_INDEX")
	var tz_index: int = index_env.to_int() if index_env.is_valid_int() else 2

	var out_dir := ProjectSettings.globalize_path("res://") + "Screenshots/filmstrip"
	DirAccess.make_dir_recursive_absolute(out_dir)
	## Stale frames from a shorter previous run would silently pad the strip.
	var existing := DirAccess.open(out_dir)
	if existing != null:
		for f in existing.get_files():
			if f.begins_with("frame_") and f.ends_with(".png"):
				existing.remove(f)

	_seed_dev_grenades_if_empty("P-FILM")

	if tz_index < 0 or tz_index >= _test_zone_controller._grenades.size():
		push_error("[P-FILM] grenade index %d out of range (%d placed)" % [
			tz_index, _test_zone_controller._grenades.size()])
		return
	var gu: Vector2i = _test_zone_controller._grenades[tz_index]["gu_cell"]
	if _camera_controller != null and agent != null:
		_camera_controller.focus_on(agent._cell_to_world(gu))
	if _fow_controller != null:
		_fow_controller.reveal_around(gu, 12)
	## Let the camera settle and the fog reveal land BEFORE frame 0, so the
	## strip opens on the scene the blast is about to change rather than on a
	## camera still travelling.
	##
	## 20 → 60: focus_on() eases rather than snapping, and 20 frames was enough
	## only sometimes — one sheet opened on frame 0 still showing the agent's
	## end of the map with the movement overlay up. A filmstrip whose first tile
	## is a different place is worse than a slow one, and these frames are
	## simulated (`--fixed-fps`), so the cost is capture time, never fidelity.
	for _s in range(60):
		await get_tree().process_frame

	print("[P-FILM] capturing %d frames of one detonation at gu=%s" % [frame_count, gu])
	## open_menu_for() is only here because detonate_active() reads the
	## `_active_index` it sets — a direct call never reaches the button handler
	## that normally closes the menu, and left open it parks "Detonate (Enter) /
	## Cancel (Esc)" over the blast in EVERY tile of the sheet.
	##
	## Closed BEFORE detonating, matching DetonateContextMenu._on_action_pressed()'s
	## own documented order ("close() must run first so the menu is already gone
	## by the time the action's own visuals play"). close() emits only `closed`,
	## never `cancelled`, so `_active_index` survives it — cancel_active() is what
	## would clear it, and that is on the cancelled path.
	_test_zone_controller.open_menu_for(tz_index)
	if _context_menu != null:
		_context_menu.close()
	if _blast_wireframe_overlay != null:
		_blast_wireframe_overlay.clear()   ## open_menu_for() draws the red preview
	_test_zone_controller.detonate_active()

	## `RenderingServer.frame_post_draw`, NOT `SceneTree.process_frame`.
	##
	## `process_frame` fires during idle processing, BEFORE the frame is drawn,
	## so a grab there returns whatever was last presented — normally one frame
	## behind, and arbitrarily further behind when the main thread has just
	## blocked. That is exactly this sequence's situation: `detonate_active()`
	## runs `build_plan()`, ~166 ms of synchronous work, and the first grab after
	## it came back showing the pre-detonation scene from the other end of the
	## map (observed on two real sheets).
	##
	## Discarding warm-up grabs did hide it, and was the wrong fix twice over:
	## placed after the detonation it flushed the buffer using the blast's own
	## opening frames and the sheet lost the head of beat 1, and placed before it
	## the staleness came straight back, because the 166 ms block is what causes
	## it. `frame_post_draw` fires after the draw actually completes, so every
	## grab matches the frame it belongs to and no frames are spent.
	for i in range(frame_count):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img == null:
			push_error("[P-FILM] null viewport image at frame %d" % i)
			continue
		img.save_png("%s/frame_%03d.png" % [out_dir, i])
	print("[P-FILM] wrote %d frames to %s" % [frame_count, out_dir])


func _capture_screenshot_to_file() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Failed to capture screenshot")
		return

	## Salva em Screenshots/ dentro do diretório do projeto (res://).
	## Mais acessível que user:// (app-data do Godot).
	var project_root := ProjectSettings.globalize_path("res://")
	var absolute_screenshots_dir := project_root + "Screenshots"
	DirAccess.make_dir_absolute(absolute_screenshots_dir)

	## Generate filename with timestamp
	var timestamp := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		timestamp["year"],
		timestamp["month"],
		timestamp["day"],
		timestamp["hour"],
		timestamp["minute"],
		timestamp["second"],
	]
	var filename := "%s/screenshot_%s.png" % [absolute_screenshots_dir, date_str]

	## Save PNG
	var error := image.save_png(filename)
	if error != OK:
		push_error("Failed to save screenshot: %s (error code: %d)" % [filename, error])
		return

	var short_name := filename.get_file()
	print("Screenshot saved: %s" % filename)
	_show_screenshot_toast("💾 %s" % short_name)


## SCREENSHOT-HOOK-01: entry point for the pre-commit hook's dedicated,
## off-screen Godot process. Waits for the just-loaded map to actually be
## rasterized, captures the real viewport (same mechanism as
## _capture_screenshot_to_file(), separate destination + retention policy),
## prunes Screenshots/history/ to the 50 most recent files, then
## quits the process itself — the hook does not need to kill it.
## OCC-FIX-02: drive the real rotation path and capture one PNG per view, overlay on.
## Agent is left where he is — the whole point is the SAME agent under four views.
func _capture_all_four_views() -> void:
	## OCC-02: the debug overlay paints opaque diamonds over the very cells the ghosts make
	## see-through, so it must be OFF when the thing under test is the ghosting itself.
	## INFILTRAITOR_CAPTURE_OVERLAY=1 turns it back on for verifying the SET (OCC-01).
	var show_overlay := OS.get_environment("INFILTRAITOR_CAPTURE_OVERLAY") == "1"
	if _occlusion_overlay != null:
		_occlusion_overlay.visible = show_overlay

	var project_root := ProjectSettings.globalize_path("res://")
	var history_dir := project_root + "Screenshots/history"
	DirAccess.make_dir_recursive_absolute(history_dir)

	for view in ["N", "E", "S", "W"]:
		_set_perspective(view)
		if _occlusion_overlay != null:
			_occlusion_overlay.visible = show_overlay
			_occlusion_overlay.queue_redraw()
		for _f in range(12):
			await get_tree().process_frame

		var img := get_viewport().get_texture().get_image()
		if img == null:
			push_error("[OCC-FIX-02] Null image capturing view %s" % view)
			continue
		var path := "%s/occ_view_%s.png" % [history_dir, view]
		img.save_png(path)
		## OCC-02 criterion 3: a cell that leaves the set must come back to EXACTLY the
		## alternative it had. Checked here rather than described: snapshot every placed
		## cell, ghost the set, release it, snapshot again, compare. A lossy restore would
		## permanently damage the map as the agent walks, and it would do so silently.
		var roundtrip_ok: bool = _voxel_renderer.verify_ghost_roundtrip(
			_occlusion_set.get_occluded_cells())
		print("[OCC-02] view=%s ghost restore round-trip: %s" % [
			view, "IDENTICAL" if roundtrip_ok else "*** LOSSY — CELLS DAMAGED ***"])

		print("[OCC-FIX-02] view=%s active=%s agent_cell=%s collected=%d occluded_cells=%d → %s" % [
			view, _active_perspective, agent.cell, _collect_all_voxel_cells().size(),
			(_occlusion_set.get_occluded_cells().size() if _occlusion_set != null and _occlusion_set.has_method("get_occluded_cells") else -1),
			path.get_file()
		])


## TEST-ZONE placeholder (2026-07-22): open floor cell 2 GU south of each
## wall segment's middle voxel (Director's call — clear of the block instead
## of hugging it) on the rebuilt PLAYGROUND (maps/PLAYGROUND.map.json) — one
## grenade per wall material (concrete/metal/stone/wood). The grenade itself
## is a baked sprite — see TestZoneController's own header for the
## ACTOR_MASTER_PLAN D1/D2 prototype this became. Populated via
## TestZoneController whenever PLAYGROUND loads — see
## _populate_test_zone_if_playground().
const TEST_ZONE_GRENADE_GUS: Array[Vector2i] = [
	Vector2i(3, 5),   ## concrete wall (gu 2,2 - 4,2)
	Vector2i(8, 5),   ## metal wall (gu 7,2 - 9,2)
	Vector2i(13, 5),  ## stone wall (gu 12,2 - 14,2)
	Vector2i(18, 5),  ## wood wall (gu 17,2 - 19,2)
]

## CHARACTER_MASTER_PLAN Part 2 probe (2026-08-16) — the baked agent standing on
## the PLAYGROUND floor so proportion and lighting can be judged against real
## voxel geometry instead of against a Blender render. Two cells on purpose: one
## in the OPEN, where nothing competes with the silhouette, and one right beside
## the concrete wall, which is the only way to read the figure's height against
## the 8-voxel SLICE it is supposed to stand slightly taller than (§4.7). One
## alone would answer half the question.
##
## This does NOT replace `agent.gd`'s vector placeholder — see AgentProbeProp's
## header for what the probe deliberately is not.
## Director, 2026-08-16: *"coloca ele próximo do bloco de concreto, pra gente
## comparar e ver se ele tem aprox. 10 voxels de altura em standing com chapéu."*
## The concrete wall (gu 2,2 - 4,2) is one SLICE = 8 voxels tall, which makes it
## the measuring stick: a 10-voxel figure beside it must stand exactly 1.25x its
## height.
##
## Cell (2,5) rather than something adjacent, and the first attempt is why: at
## (3,4) the block drew straight over his upper body. This prop sorts as level-0
## geometry ON PURPOSE (AgentProbeProp: OCC-03's always-on-top rule is agent-only
## and copying it onto a prop is the D22-FOLLOWUP mistake), so anything that
## overlaps him on screen correctly hides him — which is right for the game and
## useless for a height comparison. (2,5) is the same "2 GU south, clear of the
## block instead of hugging it" standard the Director already set for
## TEST_ZONE_GRENADE_GUS, and it puts both silhouettes whole in one frame, which
## is what measuring needs.
## THE SUIT BRACKET (Director, 2026-08-16: *"digamos que a gente queira que o
## terno dele seja bem escuro, quase totalmente preto mas ainda distinguindo o
## volume com a iluminação"*).
##
## The obstacle is arithmetic, not taste. `flat_normal_relight` computes
## `lit = albedo * (ambient + light * N·L) + specular`, and the light term is
## MULTIPLICATIVE: darkening the albedo does not move the range, it SHRINKS it.
## At the shipped 0.26 suit the form spans roughly 28..115 in value; at 0.02 that
## entire span collapses into 2..9, so volume dies of compression rather than of
## darkness. This is D31 in reverse — there, no runtime light could manufacture a
## hue that was never baked; here, no runtime light can restore modelling the
## albedo has already crushed.
##
## What does NOT shrink with the albedo are the ADDITIVE terms: `specular`, which
## is how a black object is legible in the real world (we read it almost entirely
## by its highlights), and D28's constant-colour outline, which exists because
## "a arma está muito escura em relação ao fundo" — the same sentence a near-black
## suit invites. So the bracket varies two axes, and it is bracketed PAST the
## breaking point on purpose: 0.02 is there to fail, so the limit shows up in the
## picture instead of in an opinion.
##
## Row 6 = the current matte treatment. Row 8 = both additive levers pushed.
## FOUR AGENTS, ONE PER FACING (Director, 2026-08-16: "coloca o boneco 4x na cena
## para a gente avaliar todas as faces"). They differ only in the agent's OWN
## facing — §4.6's `facing - perspective` — so one capture shows every side of
## the figure under the same light instead of four captures showing the same
## side. Spread two GU apart so no silhouette touches its neighbour.
## RETIRED 2026-08-19, Director: *"Vamos tirar as cópias do agente e deixar só o
## principal."* The four probes were a four-facing reference board from when the
## baked figure was new and needed checking against itself; the playable agent
## now shows every facing by walking, and four motionless duplicates of him
## standing in the middle of the destruction test zone are scenery that gets in
## the way of the thing being tested.
##
## The CONSTANT stays and the loop that reads it stays, both empty: the probe
## machinery (TestZoneController.add_agent_probe, its dev-vision sync) is a
## working instrument for exactly this kind of check, and deleting a tool because
## today's board does not need it is how it has to be rebuilt from memory next
## time. Put cells back here to bring the board back.
const TEST_ZONE_AGENT_PROBE_BRACKET: Array[Dictionary] = []

## TEST-ZONE weapons bench (Director, 2026-07-29; pared down 2026-07-30 for
## real destruction calibration — "a bancada está muito cheia [...] vai ser
## impossível atirar diretamente na parede durante o jogo"). Revolver/SMG/
## assault rifle dropped: they added rows without adding mechanical coverage
## (all three are LINE, same as pistol and sniper, and LINE isn't built yet).
## Three weapons left, one per range band: shotgun (CONE, short), pistol
## (LINE, short), sniper rifle (LINE, long).
##
## The bench is a MATRIX, and this table is its row axis: one entry per weapon
## type, placed once per wall material (the column axis, TEST_ZONE_WALL_GU_X) so
## every weapon can be tried against every material. `row_y` is the distance
## that weapon is actually meant to be used at — "na distância mais adequada
## para utilização" — so the rows read as a range ladder marching south as
## engagement range grows:
##
##   y=2   the wall row itself
##   y=5   ground grenades (kept, Director's explicit call — unmoved)
##   y=6   shotgun (CONE)
##   y=9   pistol (LINE)
##   y=13  sniper rifle (LINE, longest)
##
## Shotgun moved from y=4 to y=6 (Director: "a shotgun está muito próxima da
## parede [...] vamos [...] trazer a shotgun mais pra trás"). y=6 is not an
## arbitrary pullback — it is `flood_gu_cone()`'s hard ceiling: with the wall
## at y=2 and `weapons/shotgun.json`'s step_multipliers holding 5 entries
## (indices 0-4), a voxel only takes damage at ring <= 4
## (apply_container_damage: `if ring >= ring_multipliers.size(): continue`),
## and one GU-step = one row here (facing NE = grid delta (0,-1), so distance
## in y IS distance in cone steps). y=6 -> distance 4 -> the wall is hit at the
## cone's weakest possible ring (multiplier 0.15) and still registers damage;
## y=7 or beyond would miss the wall entirely. If this reads as too weak once
## captured, the fix is step_multipliers/destroy_multiplier in
## weapons/shotgun.json, not pushing the row back further — there is no
## further back to push it without the shot going dark.
##
## All weapons aim NE — the compass edge from a bench cell to the wall directly
## "above" it (grid delta (0,-1), docs/DIRECTION_GLOSSARY.md §3). Sprite scale
## and shadow factor are per-object, exactly as for a collectible; the five
## weapons baked together by weapon_frames_bake.gd share a framing, hence a
## shared 2.0 shadow factor, while the shotgun keeps the 2.5 its own earlier
## bake produced.
const TEST_ZONE_WALL_GU_X: Array[int] = [3, 8, 13, 18]
const BAKE_DIR := "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/"
const TEST_ZONE_WEAPON_ROWS: Array[Dictionary] = [
	{"id": "shotgun", "row_y": 6, "facing": "NE",
		"frames_dir": BAKE_DIR + "shotgun_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.5},
	{"id": "pistol", "row_y": 9, "facing": "NE",
		"frames_dir": BAKE_DIR + "pistol_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"id": "sniper_rifle", "row_y": 13, "facing": "NE",
		"frames_dir": BAKE_DIR + "sniper_rifle_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
]

## Collectibles strip — OFF (Director, 2026-07-29: "os objetos coletáveis estão
## ótimos, pode tirar eles do cenário por enquanto, já vimos que vai
## funcionar"). The pipeline is proven; the pickups were a demonstration, and a
## demonstration that has landed is just cost. Real cost: a spinning pickup
## holds all 120 baked frames (~48 MB VRAM each, measured — FRAME-MEM-01) while
## a bench prop holds 4, so seven of them were the single most expensive thing
## in the test zone.
##
## The TABLE below stays because it is DATA, not dead code — which object goes
## in which slot, and each one's scale and shadow factor, all of which had to be
## derived. Flip this flag to put them back.
const TEST_ZONE_COLLECTIBLES_ENABLED := false

## A dedicated row south of the whole bench, so nothing a gun is aimed at can be
## confused with something you pick up, and no collectible ever stands in a
## firing lane (every weapon fires NORTH, away from this row). One slot per
## baked object: the grenade plus each bench weapon, since the same 120-frame
## bake serves both the frozen prop and the spinning pickup.
const TEST_ZONE_COLLECTIBLE_ROW_Y := 15
const TEST_ZONE_COLLECTIBLES: Array[Dictionary] = [
	{"gu_x": 3, "frames_dir": BAKE_DIR + "grenade_collectible_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"gu_x": 6, "frames_dir": BAKE_DIR + "shotgun_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.5},
	{"gu_x": 9, "frames_dir": BAKE_DIR + "pistol_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"gu_x": 12, "frames_dir": BAKE_DIR + "revolver_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"gu_x": 15, "frames_dir": BAKE_DIR + "smg_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"gu_x": 18, "frames_dir": BAKE_DIR + "assault_rifle_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
	{"gu_x": 21, "frames_dir": BAKE_DIR + "sniper_rifle_frames/",
		"sprite_scale": 1.15, "shadow_scale_factor": 2.0},
]


## TEST-ZONE placeholder (2026-07-21): called from load_map() (real map
## switches, e.g. the map-loader toolbar) and once from _ready() (initial
## boot, before load_map()'s own call site can reach a controller that
## doesn't exist yet). No-ops on every map except PLAYGROUND.
func _populate_test_zone_if_playground() -> void:
	if _test_zone_controller == null:
		return
	_test_zone_controller.clear()
	for pickup in _collectibles:
		if pickup != null and is_instance_valid(pickup):
			pickup.queue_free()
	_collectibles.clear()
	_floating_collectible = null
	if _weapon_bench_controller != null:
		_weapon_bench_controller.clear()
	## The weapons bench and the floor grenades were RETIRED here 2026-08-17
	## (Director: "vamos fazer os testes com o agente mesmo, então não
	## precisamos mais desse esquema") — firing now goes through the agent
	## himself (WEAPON_MASTER_PLAN §6c), not a static bench prop. Left as dead
	## constants below (TEST_ZONE_GRENADE_GUS, TEST_ZONE_WEAPON_ROWS,
	## TEST_ZONE_WALL_GU_X) rather than deleted: they carry real calibration
	## history (§6b's shotgun row-distance derivation) other docs still cite.
	if map_id == "PLAYGROUND":
		for entry in TEST_ZONE_AGENT_PROBE_BRACKET:
			var cfg: Dictionary = entry.duplicate()
			cfg["frames_dir"] = "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/%s/" % entry["dir"]
			_test_zone_controller.add_agent_probe(entry["cell"], cfg)
		## Apply the CURRENT dev-vision state, not just future toggles. Dev vision
		## is ON at boot, so a probe created here would otherwise sit in its normal
		## bake until someone happened to toggle the button twice.
		if _vision_controller != null:
			_test_zone_controller.set_agent_probes_dev_vision(_vision_controller.dev_vision)
		var FloatingCollectibleClass = preload("res://godot/scripts/overlays/floating_collectible.gd")

		## ACTOR_MASTER_PLAN D21 — the spinning pickups, one per baked object.
		## Moved out of the bench (Director, 2026-07-29: collectibles get their
		## own area so the wall row belongs to the guns). The same 120-frame bake
		## feeds both roles — frozen on one frame for the aimed bench prop,
		## cycled here — so a weapon costs one bake, not two.
		##
		## Bake folder + sprite scale + shadow_scale_factor are per-object;
		## frame count, rotation speed and the camera convention come from
		## CollectibleBakeConfig and must stay identical for every object, or the
		## light-direction math breaks silently. shadow_scale_factor is
		## (SHADOW_ORTHO/SHADOW_VIEWPORT.y)/(ORTHO/VIEWPORT.y) of whichever bake
		## produced the folder.
		if TEST_ZONE_COLLECTIBLES_ENABLED:
			for collectible in TEST_ZONE_COLLECTIBLES:
				var pickup = FloatingCollectibleClass.new()
				pickup.setup(
					self, Vector2i(int(collectible["gu_x"]), TEST_ZONE_COLLECTIBLE_ROW_Y),
					String(collectible["frames_dir"]),
					float(collectible["sprite_scale"]),
					float(collectible["shadow_scale_factor"]),
				)
				add_child(pickup)
				_collectibles.append(pickup)
			## The first pickup keeps the _floating_collectible alias the
			## test_collectible capture action and _set_perspective already use.
			_floating_collectible = _collectibles[0]

		## Same shape as "[Room] N tiles registered" — a placement summary that
		## can be checked from a log instead of counted off a screenshot.
		print("[TestZone] %d pickups" % _collectibles.size())




## GU-GRID-01: re-run whenever room_size can have changed — a real map load
## (load_map()) or a perspective/rotation rebuild (_set_perspective()), both
## of which call _room_builder.build_from_layout() with a possibly different
## size. z_index 1 (not the F3 ruler's 100): see the creation comment in
## _ready() for why this sits at the floor/shadow level instead of above
## everything.
func _refresh_gu_grid_overlay() -> void:
	if _gu_grid_overlay == null:
		return
	_gu_grid_overlay.set_room_size(_room_size)


func _run_auto_screenshot_capture() -> void:
	## A few extra frames past _ready() so the GPU has actually drawn the
	## map before capture (see the SCREENSHOT-HOOK-01 comment at the call site).
	for _i in range(10):
		await get_tree().process_frame

	## Optional pre-capture action, for HUD states that only exist transiently
	## mid-turn and so cannot be caught by a plain boot capture.
	## INFILTRAITOR_CAPTURE_ACTION=end_turn really ends the player's turn (the
	## same call the End Turn button makes) and then waits, so the capture lands
	## while the enemy-phase banner is actually on screen. Needs a map with
	## guards — on a guardless map the enemy phase resolves in the same frame and
	## the banner is gone before any capture can see it.
	## INFILTRAITOR_CAPTURE_ACTION=busted shows the busted overlay through the
	## same HudController call the turn controller makes when a guard catches the
	## agent. Triggered directly, not reached through play — a real capture is
	## still the point (the overlay must be in the pixels), but reaching it
	## organically needs a guard to actually spot the agent across several turns.
	## OCC-FIX-02 — INFILTRAITOR_CAPTURE_VIEWS=1: capture the SAME agent position under
	## all four perspectives (N/E/S/W), occlusion overlay forced on, one PNG per view.
	##
	## This exists because the four-view criterion was not merely unmet, it was
	## UNMEETABLE. Rotating the view is mouse-only — the perspective pad has no key
	## binding — so an unattended run cannot rotate the map. OCC-01-b tried to press a
	## "Q key" that does not exist, the map never turned, and four byte-identical game
	## windows were reported as four views. The tool was missing; asking a third time
	## would only have produced a third fabrication.
	##
	## _set_perspective() is the same call the pad's buttons make, so this drives the
	## real rotation path (full layout rebuild), not a camera trick.
	## INFILTRAITOR_CAPTURE_AGENT_CELL="x,y" (2026-07-16): teleport the agent
	## through the same cell setter a real move uses, reveal FOW there, and
	## recompute occlusion — so an unattended capture can exercise ghost bands
	## and wireframe at any chosen spot (agent_start rarely stands where a
	## reported visual bug is). Composes with the other capture actions.
	## ROOF-OCC-01: INFILTRAITOR_CAPTURE_REVEAL_RADIUS overrides the FOW reveal
	## radius for the teleported capture — a large map's geometry is otherwise
	## too dark to visually verify anything past the default radius.
	var agent_cell_env := OS.get_environment("INFILTRAITOR_CAPTURE_AGENT_CELL")
	if agent_cell_env != "" and agent != null:
		var cell_parts := agent_cell_env.split(",")
		if cell_parts.size() == 2:
			var forced_cell := Vector2i(cell_parts[0].to_int(), cell_parts[1].to_int())
			var reveal_radius := FOW_REVEAL_RADIUS + vision_bonus_tiles
			var radius_env := OS.get_environment("INFILTRAITOR_CAPTURE_REVEAL_RADIUS")
			if radius_env.is_valid_int() and radius_env.to_int() > 0:
				reveal_radius = radius_env.to_int()
			agent.set_cell(forced_cell)
			_fow_controller.reveal_around(forced_cell, reveal_radius)
			_recompute_occlusion()
			for _j in range(10):
				await get_tree().process_frame
		else:
			push_warning("[SCREENSHOT-HOOK-01] Bad INFILTRAITOR_CAPTURE_AGENT_CELL '%s' — expected 'x,y'" % agent_cell_env)

	## BENCH-VIEW-01 (2026-07-29): frame an arbitrary cell, at an arbitrary zoom.
	## AGENT_CELL above deliberately does NOT move the camera (see its own note —
	## that was found the hard way), which is right for "put the agent here and
	## check occlusion" but useless for "show me the whole weapons bench at once".
	## These two are the missing half: FOCUS_CELL="x,y" recentres, and ZOOM (the
	## CameraController's own 0.20..1.20 range, smaller = further out) pulls back
	## far enough to fit a 10-row bench in one frame.
	var focus_env := OS.get_environment("INFILTRAITOR_CAPTURE_FOCUS_CELL")
	if focus_env != "" and _camera_controller != null and agent != null:
		var focus_parts := focus_env.split(",")
		if focus_parts.size() == 2:
			_camera_controller.focus_on(agent._cell_to_world(
				Vector2i(focus_parts[0].to_int(), focus_parts[1].to_int())))
		else:
			push_warning("[SCREENSHOT-HOOK-01] Bad INFILTRAITOR_CAPTURE_FOCUS_CELL '%s' — expected 'x,y'" % focus_env)
	var zoom_env := OS.get_environment("INFILTRAITOR_CAPTURE_ZOOM")
	if zoom_env.is_valid_float() and _camera_controller != null:
		_camera_controller.set_zoom_for_capture(zoom_env.to_float())
	if focus_env != "" or zoom_env != "":
		for _j in range(10):
			await get_tree().process_frame

	## HEAT-Z-01 (2026-07-28): force one or more analysis modes ON for the capture,
	## comma-separated ("heat", "light", "dev", "numbers" — the H / L / D / #
	## on-screen toggles). Same standing-dev-tool precedent as the capture actions
	## below: a z-order claim about an overlay that is hidden by default cannot be
	## proven by any unattended capture without a way to switch it on. Routed
	## through the SAME toggle methods the buttons call, so this exercises the real
	## path rather than poking `visible` directly.
	var vision_env := OS.get_environment("INFILTRAITOR_CAPTURE_VISION")
	if vision_env != "" and _vision_controller != null:
		for raw_mode in vision_env.split(","):
			match raw_mode.strip_edges().to_lower():
				"heat":
					_vision_controller.toggle_heat()
				"light":
					_vision_controller.toggle_light()
				"dev":
					_vision_controller.toggle_dev()
				"numbers":
					_on_hud_numbers_toggled()
				_:
					push_warning("[SCREENSHOT-HOOK-01] Unknown INFILTRAITOR_CAPTURE_VISION mode '%s' — expected heat/light/dev/numbers" % raw_mode)
		## This block toggles the controller DIRECTLY rather than going through
		## _set_view_mode(), which is where the agent's yellow-joint bake is kept
		## in step. Without this line the capture harness would photograph a
		## developer-tinted agent while the HUD says dev is off — the first
		## three-posture capture did exactly that.
		if agent != null:
			agent.set_dev_vision(_vision_controller.dev_vision)
		for _j in range(10):
			await get_tree().process_frame

	## CHARACTER Part 2 §10 — INFILTRAITOR_CAPTURE_POSTURE=standing|crouch|prone.
	## The swap replaced a placeholder that drew THREE shapes, so verifying it
	## means photographing three postures; without this an unattended run can only
	## ever reach the standing one, because posture is changed by a HUD button.
	## It goes through `set_posture()`, the same call the button makes, so this
	## drives the real path rather than poking the sprite directly.
	var posture_env := OS.get_environment("INFILTRAITOR_CAPTURE_POSTURE")
	if posture_env != "" and agent != null:
		var wanted: Variant = {
			"standing": DebugAgent.Posture.STANDING,
			"crouch": DebugAgent.Posture.CROUCHING,
			"prone": DebugAgent.Posture.PRONE,
		}.get(posture_env.strip_edges().to_lower())
		if wanted == null:
			push_warning("[SCREENSHOT-HOOK-01] Unknown INFILTRAITOR_CAPTURE_POSTURE '%s' — expected standing/crouch/prone" % posture_env)
		else:
			agent.set_posture(wanted)
			for _j in range(6):
				await get_tree().process_frame

	## INFILTRAITOR_CAPTURE_FACING=N|E|S|W — the agent's own facing, independent
	## of the room's perspective (§4.6). Driven through the same `face_step` D47
	## uses on a real move, so what is captured is a facing the game can actually
	## produce.
	var facing_env := OS.get_environment("INFILTRAITOR_CAPTURE_FACING")
	if facing_env != "" and agent != null and agent.sprite != null:
		var step: Variant = {
			"N": Vector2i(0, -1), "E": Vector2i(1, 0),
			"S": Vector2i(0, 1), "W": Vector2i(-1, 0),
		}.get(facing_env.strip_edges().to_upper())
		if step == null:
			push_warning("[SCREENSHOT-HOOK-01] Unknown INFILTRAITOR_CAPTURE_FACING '%s' — expected N/E/S/W" % facing_env)
		else:
			agent.sprite.face_step(step)
			for _j in range(4):
				await get_tree().process_frame

	var capture_action := OS.get_environment("INFILTRAITOR_CAPTURE_ACTION")
	if OS.get_environment("INFILTRAITOR_CAPTURE_VIEWS") == "1":
		## VL-PERSIST verification: detonate a grenade first, then capture all four
		## views — the crater/soot must persist through each rotation. Index
		## defaults to 0 (concrete/metal); INFILTRAITOR_CAPTURE_DETONATE_INDEX
		## selects another test-zone grenade (VL-D4: 3 = wood).
		if OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_FIRST") == "1" and _test_zone_controller != null:
			var detonate_index_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_INDEX")
			var detonate_index := detonate_index_env.to_int() if detonate_index_env.is_valid_int() else 0
			_seed_dev_grenades_if_empty("CAPTURE-VIEWS")
			_test_zone_controller.open_menu_for(detonate_index)
			_test_zone_controller.detonate_active()
			for _j in range(45):
				await get_tree().process_frame
		await _capture_all_four_views()
		get_tree().quit(0)
		return
	if capture_action == "end_turn" and turn_manager != null:
		turn_manager.end_turn()
		for _j in range(20):
			await get_tree().process_frame
	elif capture_action == "busted" and _hud_controller != null:
		_hud_controller.show_busted()
		for _j in range(20):
			await get_tree().process_frame
	elif capture_action == "shot_filmstrip" and _agent_shot_controller != null:
		await _capture_shot_filmstrip()
		get_tree().quit(0)
		return
	elif capture_action == "grenade_then_shot" and _test_zone_controller != null:
		await _capture_grenade_then_shot()
		get_tree().quit(0)
		return
	elif capture_action == "throw_filmstrip" and _test_zone_controller != null:
		await _capture_throw_filmstrip()
		get_tree().quit(0)
		return
	elif capture_action == "agent_shot" and _agent_shot_controller != null:
		await _capture_agent_shot()
	elif capture_action == "light_burn_probe":
		await _capture_light_burn_probe()
		get_tree().quit(0)
		return
	elif capture_action == "detonation_filmstrip" and _test_zone_controller != null:
		await _capture_detonation_filmstrip()
		get_tree().quit(0)
		return
	elif capture_action == "walk_filmstrip" and agent != null:
		await _capture_walk_filmstrip()
		get_tree().quit(0)
		return
	elif capture_action == "escape_open_menu":
		## ESC-STACK-01 fallback check: with nothing else open, Escape must
		## still open the Main Menu (the ModalStack empty-stack branch of
		## _on_pause_requested()) — the counterpart proof to test_zone_escape,
		## which checks the non-empty-stack branch closes the top modal
		## instead. Real Escape InputEventKey, not a direct open() call.
		var esc_down := InputEventKey.new()
		esc_down.keycode = KEY_ESCAPE
		esc_down.pressed = true
		Input.parse_input_event(esc_down)
		var esc_up := InputEventKey.new()
		esc_up.keycode = KEY_ESCAPE
		esc_up.pressed = false
		Input.parse_input_event(esc_up)
		for _j in range(10):
			await get_tree().process_frame
	elif (capture_action == "weapon_menu" or capture_action == "weapon_fire") and _weapon_bench_controller != null:
		## WEAPON-FIRE-01 dev capture action, mirroring test_zone_menu/
		## test_zone_detonate exactly: "weapon_menu" drives _unhandled_input()
		## with a synthetic right-click at the bench weapon's real hit-test
		## position (so the cone WIREFRAME PREVIEW is what gets captured);
		## "weapon_fire" additionally parses a real Enter InputEventKey, so the
		## focused-Button keyboard route is exercised rather than assumed, and
		## the capture shows the real damage.
		## INFILTRAITOR_CAPTURE_WEAPON_INDEX picks which of the bench's weapons
		## (default 0 = the concrete column); the 4 columns are one per wall
		## material, which is the whole point of the bench.
		## INFILTRAITOR_CAPTURE_PERSPECTIVE rotates the room first, so a capture
		## can prove the cone follows rotation rather than only that the sprite
		## does — the facing is stored in BASE space and rotated per view, which
		## is exactly the kind of thing that fails silently (the muzzle keeps
		## pointing where the target used to be).
		var persp_env := OS.get_environment("INFILTRAITOR_CAPTURE_PERSPECTIVE")
		if persp_env in ["N", "E", "S", "W"]:
			_set_perspective(persp_env)
			for _p in range(10):
				await get_tree().process_frame
		## The bench was retired from PLAYGROUND 2026-08-17 (see
		## _populate_test_zone_if_playground()) — this capture action now has no
		## weapons to index and must say so rather than index an empty array.
		if _weapon_bench_controller._weapons.is_empty():
			push_warning("[SCREENSHOT-HOOK-01] weapon_menu/weapon_fire: the bench is retired on PLAYGROUND, nothing to capture")
			get_tree().quit(1)
			return
		var wi_env := OS.get_environment("INFILTRAITOR_CAPTURE_WEAPON_INDEX")
		var wi := wi_env.to_int() if wi_env.is_valid_int() else 0
		if wi < 0 or wi >= _weapon_bench_controller._weapons.size():
			wi = 0
		var w_cell: Vector2i = _weapon_bench_controller._weapons[wi]["gu_cell"]
		## Frame the WALL the weapon is aimed at, not the weapon itself — the
		## point of the capture is the damage arriving at its target.
		## `w_cell.y - 2` alone was written when every bench weapon was the
		## shotgun at y=6 (so y=4, right against the wall row). D30 put LINE
		## weapons on the bench at y=9 and y=13, where the same offset frames
		## empty floor and the impact falls off-screen entirely — observed on
		## the first sniper capture. Taking whichever of the two is closer to
		## the wall keeps the shotgun's original framing and fixes the rest.
		var aim_center := Vector2i(w_cell.x, maxi(mini(w_cell.y - 2, 3), 0))
		if _camera_controller != null and agent != null:
			_camera_controller.focus_on(agent._cell_to_world(aim_center))
		if _fow_controller != null:
			_fow_controller.reveal_around(aim_center, 12)
		for _c in range(5):
			await get_tree().process_frame
		## D22-INPUT-01: the hitbox is the GU floor cell, not the sprite — click
		## there, not at _top_screen_pos() (that stays the MENU anchor, below).
		var w_click := InputEventMouseButton.new()
		w_click.button_index = MOUSE_BUTTON_RIGHT
		w_click.pressed = true
		w_click.position = _tile_to_screen_center(w_cell)
		_unhandled_input(w_click)
		for _j in range(10):
			await get_tree().process_frame
		if capture_action == "weapon_fire":
			var w_key_down := InputEventKey.new()
			w_key_down.keycode = KEY_ENTER
			w_key_down.pressed = true
			Input.parse_input_event(w_key_down)
			var w_key_up := InputEventKey.new()
			w_key_up.keycode = KEY_ENTER
			w_key_up.pressed = false
			Input.parse_input_event(w_key_up)
			## E-SPARK-CAP (Director, 2026-08-13: *"não to conseguindo ver os
			## efeitos… consegue tirar um print dos efeitos acontecendo?"*).
			##
			## The fixed 30 was why they could not. A spark lives 0.2-0.4 s
			## (`SmokeSparkOverlay.spark_duration_min/max`), and this capture
			## harness renders off-screen at a small fraction of real time — so
			## by frame 30 every spark from that shot had died, several times
			## over. The firearm VFX have been correct and effectively
			## uncapturable for as long as this action has existed; no capture
			## in the repo shows them.
			##
			## `INFILTRAITOR_CAPTURE_WEAPON_WAIT_FRAMES` mirrors
			## INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES exactly, which the
			## detonation side has had since the filmstrip work. Default
			## unchanged, so every existing use of this action is untouched.
			var w_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_WEAPON_WAIT_FRAMES")
			var w_wait := w_wait_env.to_int() if w_wait_env.is_valid_int() else 30
			for _j in range(maxi(w_wait, 0)):
				await get_tree().process_frame
	elif (capture_action == "test_zone_view" or capture_action == "test_zone_menu" or capture_action == "test_zone_detonate" or capture_action == "test_zone_escape") and _test_zone_controller != null:
		## TEST-ZONE placeholder (2026-07-21) dev capture action, same
		## standing-tool precedent as end_turn/busted above. "test_zone_view"
		## just frames the grenade (no click) for a plain look; "test_zone_menu"
		## drives _unhandled_input() with a synthetic right-click at grenade
		## 0's real hit-test position (the same call path a real click
		## takes); "test_zone_detonate" additionally parses a real Enter
		## InputEventKey so the focused-Button keyboard route is exercised,
		## not assumed. "test_zone_escape" (ESC-STACK-01, 2026-07-22) parses a
		## real Escape InputEventKey after opening the menu — proves the fix
		## for "Escape opened the Main Menu instead of cancelling the context
		## menu" through the real InputController._input() -> _on_pause_requested()
		## -> ModalStack path, not a direct cancel_active() call.
		## Frames/reveals the whole row (4 walls, gu x=2..19) — not just one
		## grenade — since TEST_ZONE_GRENADE_GUS now has one entry per wall.
		## VL-D4: INFILTRAITOR_CAPTURE_DETONATE_INDEX also selects which of the
		## 4 test-zone grenades this action clicks/frames (default 0, unchanged
		## behavior for every pre-existing use of this action).
		var tz_index_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_INDEX")
		var tz_index := tz_index_env.to_int() if tz_index_env.is_valid_int() else 0
		var row_center := Vector2i(10, 4)
		if tz_index > 0 and tz_index < TEST_ZONE_GRENADE_GUS.size():
			row_center = TEST_ZONE_GRENADE_GUS[tz_index]
		if _camera_controller != null and agent != null:
			_camera_controller.focus_on(agent._cell_to_world(row_center))
		if _fow_controller != null:
			_fow_controller.reveal_around(row_center, 12)
		for _c in range(5):
			await get_tree().process_frame
		if capture_action != "test_zone_view":
			## The floor grenades were retired from PLAYGROUND 2026-08-17 (see
			## _populate_test_zone_if_playground()), so this action seeds its own
			## — the same fix P-FILM and the four-view capture already carry, and
			## this is the third and last caller that was left warning-and-quit.
			## It matters more than the others: this is the only capture path
			## that reaches DetonationPlanBuilder.print_census(), which is where
			## the per-surface/material tally (including JUNCTION) is read.
			_seed_dev_grenades_if_empty("SCREENSHOT-HOOK-01")
			if _test_zone_controller._grenades.is_empty():
				push_warning("[SCREENSHOT-HOOK-01] %s: no grenade to detonate" % capture_action)
				get_tree().quit(1)
				return
			## D22-INPUT-01: click the GU floor cell, not the sprite.
			var g_cell: Vector2i = _test_zone_controller._grenades[tz_index]["gu_cell"]
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = true
			click.position = _tile_to_screen_center(g_cell)
			_unhandled_input(click)
			for _j in range(10):
				await get_tree().process_frame
		if capture_action == "test_zone_detonate":
			## Real focus + Enter keypress path (Button.grab_focus() + a
			## parsed InputEventKey), not a direct signal call — Input.
			## action_press() alone never reaches Control._gui_input(), so a
			## real queued key event is required to prove the keyboard route.
			var key_down := InputEventKey.new()
			key_down.keycode = KEY_ENTER
			key_down.pressed = true
			Input.parse_input_event(key_down)
			var key_up := InputEventKey.new()
			key_up.keycode = KEY_ENTER
			key_up.pressed = false
			Input.parse_input_event(key_up)
			## VL-02b: _flash_white() runs a 0.03s + 0.25s tween. Ten frames
			## caught the capture mid-flash, washing the crater out of every
			## detonation screenshot. Wait past the tween so the shot shows
			## the real damage.
			## E-SMOKE-01 (2026-08-08): 45 frames is past the tween but also past
			## most of the SMOKE — puffs live 0.6-1.0s scaled down per voxel, so
			## every detonation capture ever taken has shown the damage with the
			## VFX already gone. INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES lands
			## the shot mid-sequence instead, which is the only way to make a
			## visual claim about smoke at all. Defaults to the historical 45, so
			## every pre-existing capture invocation is unchanged.
			var det_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES")
			var det_wait: int = det_wait_env.to_int() if det_wait_env.is_valid_int() else 45
			for _j in range(maxi(det_wait, 0)):
				await get_tree().process_frame
			## VFX-01 dev verification: the 45-frame wait above is enough to
			## catch the flash-tween settling, but VFX-01's dust (starts
			## falling ~1s after the blast) and ember extinguish-puffs (up to
			## a few seconds) land later than that. Purely additive — 0
			## frames when unset, same as every other capture-only env var in
			## this function.
			var extra_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_EXTRA_WAIT_FRAMES")
			var extra_wait: int = extra_wait_env.to_int() if extra_wait_env.is_valid_int() else 0
			for _e in range(extra_wait):
				await get_tree().process_frame
			## FLOOR-DENT-01 (2026-08-01): rotate AFTER the blast, so a capture
			## proves damage SURVIVES rotation instead of only that it renders
			## once. Deliberately distinct from INFILTRAITOR_CAPTURE_PERSPECTIVE
			## (weapon bench), which rotates BEFORE firing and therefore says
			## nothing about persistence. This is the exact failure class that bit
			## D23 on 2026-07-31: _base_damage stored too little, so every rotation
			## silently replayed the wrong marks.
			var rotate_after := OS.get_environment("INFILTRAITOR_CAPTURE_ROTATE_AFTER")
			if rotate_after in ["N", "E", "S", "W"]:
				## Re-read the grenade's GU here: the click block above scopes its
				## own copy, and this runs whether or not that block ran.
				var blast_gu: Vector2i = _test_zone_controller._grenades[tz_index]["gu_cell"]
				var gu_base := PerspectiveMapperClass.cell_to_base(
					blast_gu, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
				_set_perspective(rotate_after)
				for _r in range(30):
					await get_tree().process_frame
				## The crater moved with the map — follow it, or the capture frames
				## whatever is now at the old screen position and proves nothing.
				var gu_now := PerspectiveMapperClass.cell_from_base(
					gu_base, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
				if _camera_controller != null and agent != null:
					_camera_controller.focus_on(agent._cell_to_world(gu_now))
				if _fow_controller != null:
					_fow_controller.reveal_around(gu_now, 12)
				for _r2 in range(10):
					await get_tree().process_frame
		if capture_action == "test_zone_escape":
			var esc_down := InputEventKey.new()
			esc_down.keycode = KEY_ESCAPE
			esc_down.pressed = true
			Input.parse_input_event(esc_down)
			var esc_up := InputEventKey.new()
			esc_up.keycode = KEY_ESCAPE
			esc_up.pressed = false
			Input.parse_input_event(esc_up)
			for _j in range(10):
				await get_tree().process_frame
	elif capture_action in ["grenade_aim", "grenade_throw", "grenade_cancel",
			"grenade_tap", "grenade_second"] and _test_zone_controller != null:
		## T-MODE/E-BUBBLE dev capture action (2026-08-10) — the unattended path
		## for the aiming preview, same standing-tool precedent as weapon_menu
		## above (which exists so the CONE preview can be captured rather than
		## described). Real G keypress through InputController and a real
		## InputEventMouseMotion through _input(), so what the shot proves is the
		## whole chain: key -> targeting mode -> hover -> perimeter/dome/rays.
		##
		## INFILTRAITOR_CAPTURE_AIM_CELL="x,y" is the cell the cursor hovers
		## (default (11,9), open floor next to the test-zone wall row). Combine
		## with INFILTRAITOR_CAPTURE_AGENT_CELL to change where the throw starts
		## and therefore where the perimeter is centred.
		var aim_cell := Vector2i(11, 9)
		var aim_env := OS.get_environment("INFILTRAITOR_CAPTURE_AIM_CELL")
		if aim_env.contains(","):
			var parts := aim_env.split(",")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				aim_cell = Vector2i(parts[0].to_int(), parts[1].to_int())
			else:
				push_warning("[SCREENSHOT-HOOK-01] Bad INFILTRAITOR_CAPTURE_AIM_CELL '%s' — expected 'x,y'" % aim_env)
		if _camera_controller != null and agent != null:
			_camera_controller.focus_on(agent._cell_to_world(aim_cell))
		if _fow_controller != null:
			_fow_controller.reveal_around(aim_cell, 14)
		## The camera tween has to SETTLE before the synthetic motion below is
		## positioned, or _tile_to_screen_center() is computed against a transform
		## that is still moving and the hover lands on a different cell. Measured
		## 2026-08-10: at 5 frames this misfired roughly one run in four at the
		## harness's ~8 fps.
		for _c in range(15):
			await get_tree().process_frame

		## T-DEV: `dev_vision` defaults TRUE in this build (ROTATE-KILL-01), so the
		## harness always shows the developer's view. This turns it off through the
		## real V keybind, which is the only way to capture what the player's HUD
		## actually looks like during a throw.
		if OS.get_environment("INFILTRAITOR_CAPTURE_NO_DEV") == "1":
			var v_down := InputEventKey.new()
			v_down.keycode = KEY_V
			v_down.pressed = true
			Input.parse_input_event(v_down)
			var v_up := InputEventKey.new()
			v_up.keycode = KEY_V
			v_up.pressed = false
			Input.parse_input_event(v_up)
			for _j in range(6):
				await get_tree().process_frame

		var g_down := InputEventKey.new()
		g_down.keycode = KEY_G
		g_down.pressed = true
		Input.parse_input_event(g_down)
		var g_up := InputEventKey.new()
		g_up.keycode = KEY_G
		g_up.pressed = false
		Input.parse_input_event(g_up)
		for _j in range(5):
			await get_tree().process_frame

		## The hover is what moves the dome — without it the preview sits on
		## enter_grenade_mode()'s placeholder cell and the capture proves nothing
		## about the cursor path.
		var motion := InputEventMouseMotion.new()
		motion.position = _tile_to_screen_center(aim_cell)
		_input(motion)
		for _j in range(10):
			await get_tree().process_frame

		if capture_action == "grenade_throw":
			## Real Enter through InputController's targeting branch — the same
			## route the player takes, and the only way to prove the throw
			## coroutine survives its own frame loop. It did not before
			## 2026-08-10: it called SceneTree.get_physics_frame(), which does not
			## exist, so the coroutine aborted and nothing ever detonated.
			var t_down := InputEventKey.new()
			t_down.keycode = KEY_ENTER
			t_down.pressed = true
			Input.parse_input_event(t_down)
			var t_up := InputEventKey.new()
			t_up.keycode = KEY_ENTER
			t_up.pressed = false
			Input.parse_input_event(t_up)
			## Past the 0.6 s throw, the fuse wait, and the flash tween — the same
			## reasoning (and the same env var) test_zone_detonate uses.
			var throw_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES")
			var throw_wait: int = throw_wait_env.to_int() if throw_wait_env.is_valid_int() else 120
			for _j in range(maxi(throw_wait, 0)):
				await get_tree().process_frame

		if capture_action == "grenade_second":
			## T-SECOND: throw TWICE from one boot. The Director's bug was that
			## "uma segunda granada não aparece sendo lançada" — targeting always
			## selected grenade 0, which after the first throw is spent and
			## invisible. A capture of one throw can never show this; only the
			## second one can, so the check is which prop is in the air.
			##
			## INFILTRAITOR_CAPTURE_SECOND_OFFSET="x,y" moves where the SECOND
			## throw lands relative to the first; default (1,0) is the original
			## behaviour, byte for byte. "0,0" puts both on the same GU, which is
			## the only way to exercise D2's deep-layer unlock
			## (`deep_layer_unlocked` reads `_gu_blast_count[gu] > 0`) from the
			## unattended harness — the Director's "jogando duas ou mais granadas
			## no mesmo lugar aparecem alguns voxels especiais".
			var second_offset := Vector2i(1, 0)
			var offset_env := OS.get_environment("INFILTRAITOR_CAPTURE_SECOND_OFFSET")
			if offset_env.contains(","):
				var off_parts := offset_env.split(",")
				if off_parts.size() == 2 and off_parts[0].is_valid_int() and off_parts[1].is_valid_int():
					second_offset = Vector2i(off_parts[0].to_int(), off_parts[1].to_int())
				else:
					push_warning("[SCREENSHOT-HOOK-01] Bad INFILTRAITOR_CAPTURE_SECOND_OFFSET '%s' — expected 'x,y'" % offset_env)
			for shot: int in range(2):
				var g_down2 := InputEventKey.new()
				g_down2.keycode = KEY_G
				g_down2.pressed = true
				Input.parse_input_event(g_down2)
				var g_up2 := InputEventKey.new()
				g_up2.keycode = KEY_G
				g_up2.pressed = false
				Input.parse_input_event(g_up2)
				for _j in range(5):
					await get_tree().process_frame
				print("[T-SECOND] shot %d: targeting=%s picked_index=%d" %
					[shot + 1, is_grenade_targeting(),
					_test_zone_controller._targeting_grenade_index])
				var motion2 := InputEventMouseMotion.new()
				motion2.position = _tile_to_screen_center(aim_cell + second_offset * shot)
				_input(motion2)
				for _j in range(5):
					await get_tree().process_frame
				var e_down := InputEventKey.new()
				e_down.keycode = KEY_ENTER
				e_down.pressed = true
				Input.parse_input_event(e_down)
				var e_up := InputEventKey.new()
				e_up.keycode = KEY_ENTER
				e_up.pressed = false
				Input.parse_input_event(e_up)
				## Honours INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES like every
				## other detonating action, defaulting to the 150 this always
				## used. The blast's own smoke runs 1.8-3.2 s, so 150 frames
				## lands mid-cloud — fine for "did a second grenade fly", useless
				## for looking at the crater it left.
				var second_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES")
				var second_wait: int = second_wait_env.to_int() if second_wait_env.is_valid_int() else 150
				for _j in range(maxi(second_wait, 0)):
					await get_tree().process_frame

		if capture_action == "grenade_tap":
			## T-TAP: the mobile flow, driven through the real _unhandled_input()
			## release branch rather than by calling the handler directly. TWO taps
			## on a cell the hover is NOT already sitting on: the first must only
			## re-aim, the second must throw. Doing it on the hovered cell instead
			## would prove nothing, because one tap would already match.
			var tap_cell := aim_cell + Vector2i(1, 1)
			for tap: int in range(2):
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				press.position = _tile_to_screen_center(tap_cell)
				_unhandled_input(press)
				var release := InputEventMouseButton.new()
				release.button_index = MOUSE_BUTTON_LEFT
				release.pressed = false
				release.position = press.position
				_unhandled_input(release)
				print("[T-TAP] tap %d on %s: targeting=%s" % [tap + 1, tap_cell, is_grenade_targeting()])
				for _j in range(6):
					await get_tree().process_frame
			var tap_wait_env := OS.get_environment("INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES")
			var tap_wait: int = tap_wait_env.to_int() if tap_wait_env.is_valid_int() else 120
			for _j in range(maxi(tap_wait, 0)):
				await get_tree().process_frame

		if capture_action == "grenade_cancel":
			## Real Escape, for the branch `ui_pause` used to swallow: with a throw
			## being aimed, Escape must clear the preview and leave the game
			## running, NOT open the Main Menu and pause. A capture showing the
			## menu is this action failing.
			var c_down := InputEventKey.new()
			c_down.keycode = KEY_ESCAPE
			c_down.pressed = true
			Input.parse_input_event(c_down)
			var c_up := InputEventKey.new()
			c_up.keycode = KEY_ESCAPE
			c_up.pressed = false
			Input.parse_input_event(c_up)
			for _j in range(10):
				await get_tree().process_frame
			print("[T-GRENADE] after Escape: targeting=%s paused=%s"
				% [is_grenade_targeting(), get_tree().paused])
	elif capture_action == "damage_gallery" and _voxel_renderer != null:
		## DAMAGE-GALLERY dev capture action (2026-08-07) — frames the map's
		## per-material test row wide enough to cover the wall row (y=2), this
		## rig's floor patches south of it (y=4-6), and the roof above, then
		## forces every material's WALL/FLOOR/CEILING DENTED/CRACKED atoms so
		## the capture shows whether they're actually baked. See
		## damage_gallery_debug.gd — real F5 keybind counterpart for
		## interactive use, this is the unattended-capture path for it.
		var dg_row_center := Vector2i(10, 5)
		if _camera_controller != null and agent != null:
			_camera_controller.focus_on(agent._cell_to_world(dg_row_center))
		if _fow_controller != null:
			_fow_controller.reveal_around(dg_row_center, 14)
		for _c in range(5):
			await get_tree().process_frame
		var DamageGalleryDebugClass = preload("res://godot/scripts/debug/damage_gallery_debug.gd")
		DamageGalleryDebugClass.run(self)
		for _j in range(10):
			await get_tree().process_frame
		if OS.get_environment("INFILTRAITOR_GALLERY_READBACK") == "1":
			DamageGalleryDebugClass.readback_probe(self)
	elif capture_action == "export_atoms":
		## ATOM-EXPORT dev action (Director, 2026-08-08) — dumps every baked
		## damage atom to Screenshots/atoms/ as its own PNG plus a manifest,
		## for reviewing the decals while iterating on their source art.
		## Compose the printable sheet from it with
		## `python3 tools/persistent/build_atom_sheet.py`.
		var AtomSheetExportClass = preload("res://godot/scripts/debug/atom_sheet_debug.gd")
		AtomSheetExportClass.export_atoms(self)
		for _j in range(5):
			await get_tree().process_frame
	elif capture_action == "atom_sheet" and _debug_tools_controller != null:
		## ATOM-SHEET dev capture action (2026-08-08) — the unattended-capture
		## path for F8. Needs no camera framing at all, unlike damage_gallery
		## above: the sheet is a full-screen overlay built from the registry,
		## not something happening out in the world.
		_debug_tools_controller.toggle_atom_sheet()
		for _j in range(10):
			await get_tree().process_frame
	elif capture_action == "open_showcase" and _main_menu_panel != null:
		## ACTOR_MASTER_PLAN D20/Part 5a dev verification: real button-handler
		## path (Main Menu's own _on_showcase_pressed(), same as a real click
		## would trigger via the emitted signal), not a direct panel.open()
		## call. Extra wait past the usual capture delay so the GLTF load +
		## a few auto-spin frames are visibly in the captured pixels.
		## INFILTRAITOR_CAPTURE_PORTRAIT=1 forces the OS window to the
		## project's own mobile viewport size (390x844) before opening, so
		## the D20 adaptive-layout breakpoint can be verified in both
		## orientations from one capture action — --resolution alone does not
		## survive room.gd's own boot path in this build.
		if OS.get_environment("INFILTRAITOR_CAPTURE_PORTRAIT") == "1":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(390, 844))
			get_tree().root.content_scale_size = Vector2i(390, 844)
			for _j in range(5):
				await get_tree().process_frame
		_main_menu_panel.open()
		for _j in range(5):
			await get_tree().process_frame
		_main_menu_panel._on_showcase_pressed()
		for _j in range(40):
			await get_tree().process_frame
	elif capture_action == "test_collectible" and _floating_collectible == null:
		## The strip is off (TEST_ZONE_COLLECTIBLES_ENABLED), so this action has
		## nothing to frame. Say so — a silent no-op here would look like a
		## broken capture rather than a disabled fixture.
		push_warning("[SCREENSHOT-HOOK-01] test_collectible: no pickup in the scene — set TEST_ZONE_COLLECTIBLES_ENABLED to put the strip back")
	elif capture_action == "test_collectible" and _floating_collectible != null:
		## ACTOR_MASTER_PLAN D17/D21 dev verification: INFILTRAITOR_CAPTURE_AGENT_CELL
		## only teleports the agent + reveals FOW, it does not recentre the
		## camera (found the hard way — two identical "recaptures" before
		## realizing this) — focus_on() is the real camera-move call the
		## test_zone_* actions already use for the same reason.
		var target_cell: Vector2i = _floating_collectible.gu_cell
		if _camera_controller != null and agent != null:
			_camera_controller.focus_on(agent._cell_to_world(target_cell))
		if _fow_controller != null:
			_fow_controller.reveal_around(target_cell, 8)
		for _j in range(15):
			await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("[SCREENSHOT-HOOK-01] Failed to capture auto-screenshot — image was null")
		get_tree().quit(1)
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var history_dir := project_root + "Screenshots/history"
	var dir_err := DirAccess.make_dir_recursive_absolute(history_dir)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_warning("[SCREENSHOT-HOOK-01] Could not create history dir (error %d)" % dir_err)
		get_tree().quit(1)
		return

	var timestamp := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		timestamp["year"],
		timestamp["month"],
		timestamp["day"],
		timestamp["hour"],
		timestamp["minute"],
		timestamp["second"],
	]
	var filename := "%s/auto_%s.png" % [history_dir, date_str]

	var save_err := image.save_png(filename)
	if save_err != OK:
		push_warning("[SCREENSHOT-HOOK-01] Failed to save auto-screenshot: %s (error %d)" % [filename, save_err])
		get_tree().quit(1)
		return

	print("[SCREENSHOT-HOOK-01] Captured: %s" % filename)
	_prune_auto_screenshot_history(history_dir)
	get_tree().quit(0)


## Keeps Screenshots/history/ at the 50 most recent auto_*.png
## files (oldest-first deletion by filename, which sorts chronologically
## since the timestamp format is zero-padded and lexicographic-safe).
func _prune_auto_screenshot_history(history_dir: String) -> void:
	const MAX_HISTORY_FILES := 50
	var dir := DirAccess.open(history_dir)
	if dir == null:
		push_warning("[SCREENSHOT-HOOK-01] Could not open history dir for pruning: %s" % history_dir)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.begins_with("auto_") and entry.ends_with(".png"):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	if files.size() <= MAX_HISTORY_FILES:
		return

	files.sort()  ## chronological: zero-padded timestamp in the filename
	var excess := files.size() - MAX_HISTORY_FILES
	for i in range(excess):
		var path := "%s/%s" % [history_dir, files[i]]
		var rm_err := DirAccess.remove_absolute(path)
		if rm_err != OK:
			push_warning("[SCREENSHOT-HOOK-01] Could not prune old screenshot: %s (error %d)" % [path, rm_err])
		else:
			print("[SCREENSHOT-HOOK-01] Pruned: %s" % files[i])


## Exibe uma mensagem temporária no HUD (CanvasLayer $HUD).
## Aparece no canto inferior-esquerdo e desvanece em 2 s.
func _show_screenshot_toast(message: String) -> void:
	var hud: CanvasLayer = get_node_or_null("HUD")
	if hud == null:
		return

	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_bottom = -24.0
	lbl.offset_left   =  16.0
	hud.add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


## ── INPUT-01: Signal handlers for InputController ──────────────────────────

func _on_posture_lower_requested() -> void:
	print_debug("[ROOM] Handler: posture lower")
	## Z lowers: STANDING -> CROUCHING -> PRONE
	var next_posture := agent.posture
	if agent.posture == DebugAgent.Posture.STANDING:
		next_posture = DebugAgent.Posture.CROUCHING
	elif agent.posture == DebugAgent.Posture.CROUCHING:
		next_posture = DebugAgent.Posture.PRONE
	
	if next_posture != agent.posture:
		_debug_tools_controller.try_change_posture(next_posture)


func _on_posture_raise_requested() -> void:
	print_debug("[ROOM] Handler: posture raise")
	## X raises: PRONE -> CROUCHING -> STANDING
	var next_posture := agent.posture
	if agent.posture == DebugAgent.Posture.PRONE:
		next_posture = DebugAgent.Posture.CROUCHING
	elif agent.posture == DebugAgent.Posture.CROUCHING:
		next_posture = DebugAgent.Posture.STANDING
	
	if next_posture != agent.posture:
		_debug_tools_controller.try_change_posture(next_posture)


func _on_view_mode_requested(mode: String) -> void:
	print_debug("[ROOM] Handler: view mode %s" % mode)
	## V/L/H: switch view modes
	var btn: Node = null
	match mode:
		"dev":
			btn = btn_view_v
		"light":
			btn = btn_view_l
		"heat":
			btn = btn_view_h
	
	if btn:
		_set_view_mode(mode, btn)


func _on_peek_initiated() -> void:
	print_debug("[ROOM] Handler: peek initiated")
	## P: set peek pending flag
	_peek_pending = true


func _on_movement_input_requested(direction: Vector2i, is_large_step: bool) -> void:
	print_debug("[ROOM] Handler: movement %s (large_step=%s)" % [direction, is_large_step])
	## Arrow keys: dual-purpose (nudge or peek, decided by state)
	if _debug_tools_controller.is_nudge_mode_active():
		var step := 8.0 if is_large_step else 1.0
		_debug_tools_controller.apply_nudge(Vector2(direction) * step)
	elif _peek_pending:
		_try_peek(direction)
		_peek_pending = false


func _on_debug_command_requested(command: String) -> void:
	print_debug("[ROOM] Handler: debug command %s" % command)
	## F2/F3/F4/F6/F7/F17/K/R: debug commands
	match command:
		"toggle_map_loader":
			_debug_tools_controller.toggle_map_loader_panel()
		"toggle_voxel_ruler":
			_debug_tools_controller.toggle_voxel_ruler_overlay()
		"toggle_nudge_mode":
			_debug_tools_controller.toggle_nudge_mode()
		"toggle_bake_mode":
			_debug_tools_controller.toggle_bake_mode()
		"cycle_blend_mode":
			_debug_tools_controller.cycle_blend_mode()
		"cycle_language":
			var localization: Variant = get_node_or_null("/root/Localization")
			if localization:
				localization.cycle_language()
		"toggle_occlusion":
			## OCC-21m (2026-07-15): Toggle deprecated — occlusion overlay now follows
			## light_vision state. F2 key kept functional for backwards compat (just
			## mirrors what L key already does), but "K" input now unmapped.
			if _vision_controller != null:
				_vision_controller.toggle_light()
				print_debug("[OCC-21m] Occlusion overlay toggled via light_vision: %s" % _vision_controller.light_vision)
		"nudge_reset":
			if _debug_tools_controller.is_nudge_mode_active():
				_debug_tools_controller.reset_nudge()
		"force_damage_gallery":
			_debug_tools_controller.force_damage_gallery()
		"toggle_atom_sheet":
			_debug_tools_controller.toggle_atom_sheet()


## ESC-STACK-01: Escape's ONE entry point (InputController emits this
## unconditionally on every ui_pause press, from _input() — see input_controller.gd).
## The old body special-cased "controls open? close it" / "else toggle main
## menu" by hand; that only ever covered two hardcoded levels and raced the
## context menu's own Escape handling in _unhandled_input (2026-07-22 bug:
## Escape always opened the Main Menu instead of cancelling the grenade
## menu). _modal_stack now owns "what does Escape affect next" for any
## number of nested modals — this function is just its empty-stack fallback.
func _on_pause_requested() -> void:
	if _modal_stack != null and _modal_stack.handle_escape():
		return
	_main_menu_panel.open()
	get_tree().paused = true


## T-GRENADE: whether a throw is currently being aimed. InputController asks
## before claiming Enter/Escape — see its _is_grenade_targeting().
func is_grenade_targeting() -> bool:
	return _test_zone_controller != null and _test_zone_controller.is_in_targeting_mode()


## T-MODE (Phase B): G key to enter grenade targeting mode
## W-TUNE-02: keys 1/2/3 pick the firearm. Routed through the controller rather
## than written here so the re-keying of an open aim (see set_weapon()) cannot be
## forgotten by a second caller.
func _on_weapon_select_requested(weapon_id: String) -> void:
	if _agent_shot_controller != null:
		_agent_shot_controller.set_weapon(weapon_id)


func _on_grenade_mode_requested() -> void:
	if _test_zone_controller != null:
		_test_zone_controller.enter_grenade_mode()


## T-GRENADE: Enter key to throw grenade
func _on_grenade_throw_requested() -> void:
	if _test_zone_controller != null:
		_test_zone_controller.execute_grenade_throw()


## T-GRENADE: ESC key to cancel grenade mode
func _on_grenade_cancel_requested() -> void:
	if _test_zone_controller != null:
		_test_zone_controller.cancel_targeting()


func _on_controls_requested() -> void:
	_controls_panel.open()


func _on_showcase_requested() -> void:
	_showcase_panel.open()


## ESC-STACK-01: the grenade context menu's ModalStack close callable — closes
## the box AND cancels the pending grenade, same pairing _unhandled_input's
## outside-click path and the menu's own "Cancelar" button already use.
func _cancel_context_menu() -> void:
	_context_menu.close()
	_cancel_prop_menus()


## WEAPON-FIRE-01: one menu serves several prop types, so cancelling has to
## clear whichever one armed it. Every cancel is idempotent (each early-returns
## when it has no active index), so calling them all unconditionally is safe and
## avoids a "which controller opened this" variable that could go stale.
##
## §6c added the third: the agent's shot, armed from an ENEMY rather than a prop.
func _cancel_prop_menus() -> void:
	_test_zone_controller.cancel_active()
	if _weapon_bench_controller != null:
		_weapon_bench_controller.cancel_active()
	if _agent_shot_controller != null:
		_agent_shot_controller.cancel_active()

func _on_screenshot_requested() -> void:
	print_debug("[ROOM] Handler: screenshot requested (Shift+P)")
	## Shift+P: capture screenshot
	_capture_screenshot_to_file()


## Initialize debug views (S1: FIX-BAKE-06)
func _initialize_debug_views() -> void:
	# Only in debug builds
	if not (OS.is_debug_build() or Engine.is_editor_hint()):
		return

	print("[DEBUG] Initializing debug views...")
	print("""
	[DEBUG BINDINGS]
	F5:  Toggle Theme Matrix (saturation calibration grid)
	F6:  Toggle bake mode (BAKED / GENERIC), reloads current map
	F7:  Cycle bake blend mode (MULTIPLY/TEXTURE_ONLY/MATERIAL_ONLY/OVERLAY/LINEAR_LIGHT), reloads current map
	F8:  Toggle Atom Sheet — every pre-baked damage atom in this map, by
	     material and surface, read off the VoxelVariantRegistry
	     (INFILTRAITOR_ATOM_SHEET_SUBSTRATES=all shows the substrate axis too)
	F12: (Reserved) Selftest — run headless:
	     godot --headless --script godot/scripts/tools/bake_selftest.gd
	""")

	# Theme Matrix (F5)
	var theme_matrix_class = preload("res://godot/scripts/debug/theme_matrix_debug_view.gd")
	var theme_matrix = theme_matrix_class.new()
	add_child(theme_matrix)
	print("[DEBUG] F5: Theme Matrix viewer initialized")
