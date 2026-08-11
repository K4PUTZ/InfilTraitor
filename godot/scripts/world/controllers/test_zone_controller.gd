## TestZoneController — TEST-ZONE placeholder (2026-07-21): right-click
## "Detonar" on a test prop.
##
## ACTOR_MASTER_PLAN D1/D2 prototype (same session): the grenade is a
## "digital twin" (Quaternius' CC0 "Grenade" model, poly.pizza) rendered via
## the real-3D-model + normal-map bake technique proven for the shotgun
## (godot/scripts/tools/grenade_frame_bake_spike.gd, 2026-07-28) — displayed
## via GrenadeProp (godot/scripts/overlays/grenade_prop.gd), NOT live
## TileMapLayer voxel cells. Superseded the original single-angle
## bake_voxel_sprite_3d.gd bake (grenade_bake_x8.png, a hand-placed BoxMesh
## voxel reconstruction of a CC0 .qb — itself already a v2 over a hand-rolled
## 2D painter's-algorithm rasterizer, v1) once that was shown to read flat
## from some angles and to ignore the room's active N/E/S/W perspective
## entirely, the same class of bug D22 found and fixed for the shotgun.
## Proves the mechanism ACTOR_MASTER_PLAN D1/D2 describes for one object
## before Parts 0-2 of that plan get built for real.
##
## Registry stays a plain Array[Dictionary] on purpose — scaffolding for the
## PLAYGROUND rebuild, not a permanent prop-interaction architecture.
## Delegates to room for shared state, same extraction pattern as
## SelectionController.
class_name TestZoneController

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const GrenadePropClass = preload("res://godot/scripts/overlays/grenade_prop.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const DetonationChoreographerClass = preload("res://godot/scripts/systems/destruction/detonation_choreographer.gd")

var room: Node
var _grenades: Array[Dictionary] = []
var _active_index: int = -1

## T-MODE: targeting mode active (grenade selected, waiting for target)
var _targeting_mode: bool = false
var _targeting_grenade_index: int = -1
## The cell the throw will actually use — ALREADY CLAMPED to throw range. The
## first pass kept no such state: the preview clamped `room._hovered_cell` for
## the bubble, and then `execute_grenade_throw()` re-read the RAW hovered cell,
## so a throw aimed past the perimeter went where the preview said it could not.
var _targeting_target_gu: Vector2i = Vector2i.ZERO

## Throw range, in GAME UNITS — the radius the perimeter ellipse draws and the
## clamp tests against, one number for both (`var`, Rule 1).
##
## Was `max_ring * 112.0 * 3.0` px, a stack of magic numbers that worked out to
## 5.57 GU by accident. Director, 2026-08-10, on the real thing: "O perímetro em
## vermelho parece ok, poderia ser um pouquinho mais largo."
var throw_range_gu: float = 6.5

## Radius of the aim dome, in GAME UNITS. Director: "cobrindo uma área de 3x3 GU
## aproximadamente" — 1.5 GU in every direction from the target cell's centre.
## Deliberately NOT derived from `bomb_def.ring_multipliers.size()`: the dome is
## the readable shape of the blast, and the per-cell truth of how far it reaches
## is what the shrapnel rays carry.
var aim_dome_radius_gu: float = 1.5

## Seconds the thrown grenade takes to travel its arc, and the cap on how long
## the fuse waits for a prediction that is still cooking.
var throw_duration_s: float = 0.6
var throw_prediction_timeout_s: float = 1.0

## Where the dome starts when targeting opens and the cursor is not over the map
## yet — three cells along +x, purely so the preview has something to show.
const DEFAULT_TARGET_OFFSET := Vector2i(3, 0)

## EXPLOSION_REBUILD_MASTER_PLAN Task 5 (E-WAVE) — keeps the in-flight
## DetonationChoreographer (a RefCounted, not a Node) alive for its whole
## ~600ms wave sequence. `detonate_active()`'s own local variable is not
## enough on its own to guarantee this across every code path; holding it
## here ties its lifetime to this controller (the whole room's), the same
## explicit-ownership pattern _grenades already uses instead of leaning on
## implicit signal-connection keep-alive semantics.
var _active_choreographer = null

## P-COOK (PREDICTION_MASTER_PLAN Task 6, 2026-08-09) — whether the
## pre-production pump coroutine is running. The prediction itself lives in
## `room._prediction_cache`; only the pump belongs to this controller.
var _pumping: bool = false

## §4.4's slice budget, split in two because the player is doing different
## things in the two cases. `var`, Rule 1.
##
## PRE-PRODUCTION runs while the player is still choosing. The scene is idle but
## the cursor may be moving and must stay smooth, so this is §4.4's proposed
## quarter of a 60 fps frame.
##
## COOKING runs with the grenade already on the ground and the fire already
## burning: the player is watching an animation and waiting for the bang, so a
## bigger bite is both affordable and desirable, because it shortens the wait.
## This is the number to raise if the fuse ever feels long.
var predict_budget_ms: float = 4.0
var cook_budget_ms: float = 8.0

const MENU_GAP_ABOVE_PX: float = 30.0

## DESTRUCTION_MASTER_PLAN Part 3: every TEST-ZONE grenade is this one bomb
## type for now — BombRegistry/BombDef exist so a future prop/inventory
## system can vary this per grenade instance instead of hardcoding it here.
const BOMB_ID: String = "frag_grenade"

## E-FLASH-01 (Director, 2026-08-08): "uma breve camera shake no período entre o
## flash frame e o fim da fumaça." It starts on the flash and decays across the
## window the smoke lives in — the smoke's own puffs run 1.0-1.8 s scaled down
## per voxel, so most of the cloud is gone by ~0.8 s and a shake outlasting that
## would be shaking at nothing. `var` (Rule 1), both are tuning levers.
## 12 px is the camera's OWN space, so the on-screen displacement is scaled by
## the current zoom (0.20-1.20) — at a typical zoom this reads as a few pixels of
## kick that settles inside half a second, which is what "breve" asks for.
## Lengthened 0.55 -> 0.7 when the shake moved to start with the fireball rather
## than with the flash: it now has the animation's own ~8 frames to cover before
## the destruction even lands, and the old duration would have been most spent
## before the crater appeared.
##
## P-PLAY (Director, 2026-08-09): "estender um pouco mais a duração do camera
## shake." 0.7 -> 1.0, and the two reasons it is safe to now are both new this
## pass rather than a decision to shake at nothing:
##   1. The blast itself is LONGER. The front was collapsing into 3 frames
##      (PREDICTION_MASTER_PLAN §1.2); it is `front_frames` = 24 now, ~0.4 s at
##      60 fps, so the destruction the shake exists to sell is still arriving at
##      a point where the old 0.7 s was already fading out.
##   2. `blast_burst_ember_life_max` went 0.75 -> 1.05 in the same pass, so
##      there is visibly burning material for the whole new window.
## The caution in the paragraph above still governs: this must not outlast the
## smoke, or the camera ends up shaking a settled scene. 1.0 s sits inside the
## per-voxel smoke's own 1.0-1.8 s envelope.
var SHAKE_SECONDS: float = 1.0
var SHAKE_AMPLITUDE_PX: float = 12.0

## P-STROBE (Director, 2026-08-09) — the strobe, exactly as specified: "1 flash
## frame branco, 1 frame negativo, outro frame branco, outro frame negativo."
## One entry = one held engine frame. Order is the look; length is the duration.
const STROBE_SEQUENCE: Array[int] = [
	ExplosionFlashOverlay.FlashMode.WHITE,
	ExplosionFlashOverlay.FlashMode.NEGATIVE,
	ExplosionFlashOverlay.FlashMode.WHITE,
	ExplosionFlashOverlay.FlashMode.NEGATIVE,
]

## How long the fire burns ALONE before the strobe starts — the Director's
## "depois do último frame" of the fire.
##
## ASSUMPTION, flagged rather than buried: the fire has no "last frame" to wait
## for any more. E-NATIVE-01 deleted the authored 4-frame fireball, so the fire
## is now particle overlays with 0.5-1.25 s lifetimes; waiting for its real end
## would put the strobe a full second after the bang. Read as "after the burst
## has visibly established itself", which is a small number of frames. 3 is a
## starting value for the Director's eye, not a derived one — it is the single
## number to move if the strobe should sit earlier or later.
var burst_lead_frames: int = 3


func _init(p_room: Node) -> void:
	room = p_room


func clear() -> void:
	for g in _grenades:
		var sprite: Sprite2D = g.get("sprite")
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_grenades.clear()
	_active_index = -1


## Place one placeholder grenade at gu_cell as a baked sprite (ground-contact
## anchored to the cell's center), and register it as right-click detonatable.
## PERSPECTIVE-01: gu_cell is a view-space cell for the room's CURRENT
## perspective at add-time — also stored converted to a base (pre-rotation)
## cell, so reposition_for_perspective() can follow rotation the same way
## room.gd already does for the agent and the selection cursor.
func add_grenade(gu_cell: Vector2i) -> void:
	var base_cell: Vector2i = room._cell_to_base(gu_cell, room._active_perspective)
	var sprite := GrenadePropClass.new()
	sprite.setup(room, gu_cell, base_cell)
	sprite.position = room.agent._cell_to_world(gu_cell)
	room.add_child(sprite)
	_grenades.append({
		"gu_cell": gu_cell,
		"base_cell": base_cell,
		"sprite": sprite,
		"detonated": false,
	})


## PERSPECTIVE-01: called from room.gd::_set_perspective() alongside the
## existing agent/selection-cursor reposition block. Every live (undetonated)
## grenade's gu_cell and sprite world position are re-derived from its
## base_cell for the new direction — the same cell_from_base() round-trip the
## agent already uses, generalized to any runtime-instantiated prop that
## isn't rebuilt fresh from _base_layout on rotation. GrenadeProp.update_cell()
## also swaps to the frame baked for the new compass direction (D22 fix).
func reposition_for_perspective(direction: String) -> void:
	var base_size: Vector2i = room._base_layout.get("size", Vector2i.ZERO)
	for g in _grenades:
		if g["detonated"]:
			continue
		var new_cell: Vector2i = PerspectiveMapperClass.cell_from_base(g["base_cell"], direction, base_size)
		g["gu_cell"] = new_cell
		var sprite: GrenadePropClass = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.position = room.agent._cell_to_world(new_cell)
			sprite.update_cell(new_cell)


## The sprite's own drawn rect, in world/global space — centered=false with a
## custom offset, so this is exactly (global_position + offset, texture_size),
## no reconstruction of the anchor math needed here.
func _sprite_global_rect(grenade: Dictionary) -> Rect2:
	var sprite: Sprite2D = grenade["sprite"]
	return Rect2(sprite.global_position + sprite.offset, sprite.texture.get_size())


## Screen-space top-center of the sprite — context menu anchor.
func _top_screen_pos(grenade: Dictionary) -> Vector2:
	var rect := _sprite_global_rect(grenade)
	var world_top := rect.position + Vector2(rect.size.x / 2.0, 0.0)
	return room.get_viewport().get_canvas_transform() * world_top


## Index of the grenade standing on the clicked GU cell, or -1. Director
## (2026-07-30): the clickable hitbox for an interactive object is the FLOOR
## CELL it occupies, not its sprite — a ground grenade is an ordinary floor
## prop, not one of the direct-click exceptions (wall-mounted breakables,
## ceiling lamps).
func hit_test(screen_pos: Vector2) -> int:
	var cell: Vector2i = room._screen_to_tile(screen_pos)
	if cell == room.INVALID_CELL:
		return -1
	for i in range(_grenades.size()):
		var g: Dictionary = _grenades[i]
		if g["detonated"]:
			continue
		if g["gu_cell"] == cell:
			return i
	return -1


func open_menu_for(index: int) -> void:
	if index < 0 or index >= _grenades.size():
		return
	_active_index = index
	var g: Dictionary = _grenades[index]
	## WEAPON-FIRE-01: the menu is shared with the weapons bench now, so the
	## verb and its handler are passed per open instead of being wired once in
	## room.gd. Same button, same signal, different action.
	room._context_menu.open_at(_top_screen_pos(g), MENU_GAP_ABOVE_PX,
		"ui.context_menu.detonate", detonate_active)

	## DESTRUCTION_MASTER_PLAN Part 3: preview the max-range GU footprint as
	## a red wireframe while the menu is open (Director, this session).
	if room._blast_wireframe_overlay != null:
		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null:
			var gu_rings := BlastCalculatorClass.flood_gu_rings(g["gu_cell"], bomb_def,
				_blocked_edges_dict(), room._blocked_cells)
			room._blast_wireframe_overlay.show_footprint(gu_rings.keys())

	## P-COOK: PRE-PRODUCTION STARTS HERE.
	##
	## §4.2's trigger is "hover, or first tap on a GU for mobile". The throw arc
	## and the hover that drives it do not exist yet (Phase B of
	## EXPLOSION_REBUILD_MASTER_PLAN), so the equivalent moment in today's flow is
	## the context menu opening: the player has picked the target and is about to
	## confirm it.
	##
	## That gap is the whole trick. A human takes several hundred milliseconds to
	## read a menu and press a button, and a prediction needs ~190 ms of work — so
	## by the time "Detonate" is pressed the Delta is normally already finished and
	## the blast starts on the very next frame, with nothing to freeze.
	_begin_preproduction(g["gu_cell"])


## T-MODE (Phase B): enter targeting mode for a grenade via the G key.
func enter_grenade_mode() -> void:
	if _grenades.is_empty():
		return
	## First available grenade for now — cycling belongs to the inventory system
	## that does not exist yet, not here.
	_targeting_grenade_index = 0
	_targeting_mode = true
	_targeting_target_gu = room.agent.cell + DEFAULT_TARGET_OFFSET
	_update_grenade_targeting_display()


## Rebuild the whole aiming preview — perimeter, dome, arc and shrapnel rays —
## from the current hover. Called on entry and on every hover change.
func _update_grenade_targeting_display() -> void:
	if not _targeting_mode or _targeting_grenade_index < 0:
		return

	var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
	if bomb_def == null:
		push_error("[TestZoneController] targeting: bomb '%s' is not in the registry" % BOMB_ID)
		cancel_targeting()
		return

	var origin_gu: Vector2i = room.agent.cell
	var agent_pos: Vector2 = room.agent.position

	## The perimeter is the locus of `throw_range_gu` around the agent, projected
	## by IsoProjection — the same radius, in the same units, the clamp below uses.
	if room._throw_perimeter_overlay != null:
		room._throw_perimeter_overlay.show_perimeter(agent_pos, throw_range_gu)

	var hovered: Vector2i = room._hovered_cell
	if hovered == room.INVALID_CELL:
		hovered = _targeting_target_gu
	_targeting_target_gu = _clamp_gu_to_throw_range(hovered, origin_gu)
	var target_pos: Vector2 = room.agent._cell_to_world(_targeting_target_gu)

	## E-BUBBLE: the dome. A fixed geometric shape, NOT the predicted footprint —
	## see aim_bubble_overlay.gd's header for why the Director ruled that out.
	if room._aim_bubble_overlay != null:
		room._aim_bubble_overlay.show_dome(target_pos, aim_dome_radius_gu)

	if room._throw_arc_overlay != null:
		room._throw_arc_overlay.show_arc(agent_pos, target_pos)

	## T-FRAG: the shrapnel rays, from the SAME wall-aware BFS the real blast
	## floods with, so a cell the grenade cannot reach never gets a ray. Cheap
	## enough to redo per hover: `max_ring` is 3, so this walks ~25 cells — the
	## expensive prediction is `_begin_preproduction()`, which stays on the throw.
	if room._shrapnel_preview_overlay != null:
		var gu_rings := BlastCalculatorClass.flood_gu_rings(_targeting_target_gu, bomb_def,
			_blocked_edges_dict(), room._blocked_cells)
		room._shrapnel_preview_overlay.show_rays(_targeting_target_gu, gu_rings)


## Throw the grenade at the target the preview is showing.
func execute_grenade_throw() -> void:
	if not _targeting_mode or _targeting_grenade_index < 0:
		return

	## `_targeting_target_gu` is already clamped — the throw and the preview
	## cannot disagree, because there is only one cell and the preview set it.
	var target_gu: Vector2i = _targeting_target_gu
	var grenade: Dictionary = _grenades[_targeting_grenade_index]

	## Leave targeting BEFORE the animation awaits its first frame: the throw is
	## in flight from here on, and an ESC during it must not try to cancel a mode
	## that is already spent.
	_targeting_mode = false
	_targeting_grenade_index = -1
	_cleanup_grenade_targeting_ui()

	_begin_preproduction(target_gu)
	_start_grenade_throw_animation(target_gu, grenade)


## Cancel targeting mode
func cancel_targeting() -> void:
	if not _targeting_mode:
		return
	_targeting_mode = false
	_targeting_grenade_index = -1
	_cleanup_grenade_targeting_ui()


## Clean up grenade targeting UI overlays
func _cleanup_grenade_targeting_ui() -> void:
	if room._throw_perimeter_overlay != null:
		room._throw_perimeter_overlay.clear()
	if room._aim_bubble_overlay != null:
		room._aim_bubble_overlay.clear()
	if room._throw_arc_overlay != null:
		room._throw_arc_overlay.clear()
	if room._shrapnel_preview_overlay != null:
		room._shrapnel_preview_overlay.clear()


## T-BUBBLE: snap a target cell to the closest one within `throw_range_gu`.
##
## Works in GU SPACE, not screen pixels. The first pass measured
## `|dx| + 2·|dy| <= range` on projected positions, which is a DIAMOND inscribed
## in the ellipse the perimeter draws — so the dome could never touch the line it
## was being clamped to except on the two axes. A plain Euclidean test in grid
## coordinates is the perimeter's own definition, and IsoProjection turns that
## same circle into the ellipse on screen.
func _clamp_gu_to_throw_range(target_gu: Vector2i, origin_gu: Vector2i) -> Vector2i:
	var delta := Vector2(target_gu - origin_gu)
	var distance_gu: float = delta.length()
	if distance_gu <= throw_range_gu:
		return target_gu
	return origin_gu + Vector2i((delta / distance_gu * throw_range_gu).round())


## T-ARC: fly the grenade along its arc, then detonate where it lands.
##
## The frame loops below advance on `room.get_process_delta_time()`. They used to
## advance on `room.get_tree().get_physics_frame()`, which does not exist on
## SceneTree in Godot 4.6 — every throw raised "Invalid call. Nonexistent
## function 'get_physics_frame'" on the first iteration, aborted this coroutine,
## and the grenade never moved and never detonated.
func _start_grenade_throw_animation(target_gu: Vector2i, grenade: Dictionary) -> void:
	var sprite: Sprite2D = grenade.get("sprite")
	if sprite == null or not is_instance_valid(sprite):
		push_error("[TestZoneController] throw: grenade %s has no sprite to animate" % target_gu)
		return

	var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
	if bomb_def == null:
		push_error("[TestZoneController] throw: bomb '%s' is not in the registry" % BOMB_ID)
		return

	var tree: SceneTree = room.get_tree()
	var target_world: Vector2 = room.agent._cell_to_world(target_gu)
	var start_pos: Vector2 = room.agent.position

	var elapsed: float = 0.0
	while elapsed < throw_duration_s:
		await tree.process_frame
		elapsed += room.get_process_delta_time()
		sprite.position = start_pos.lerp(target_world,
			minf(elapsed / throw_duration_s, 1.0))
	sprite.position = target_world
	grenade["gu_cell"] = target_gu

	## Give a prediction that is still cooking the rest of the fuse to finish in,
	## capped so a pathological one cannot hold the blast forever —
	## `_start_detonation_sequence()` cooks whatever is left anyway.
	var waited: float = 0.0
	while waited < throw_prediction_timeout_s and room._prediction_cache != null \
			and room._prediction_cache.is_busy():
		await tree.process_frame
		waited += room.get_process_delta_time()

	## Same hand-off `detonate_active()` makes: the prop stops existing at the
	## exact frame the blast starts, which is also E-FRAG's cue to throw debris.
	var anchor: Vector2 = _blast_anchor(grenade)
	sprite.visible = false
	grenade["detonated"] = true
	_stop_pumping()
	_start_detonation_sequence(_take_prediction(bomb_def, target_gu), target_gu, anchor)


## T-BUBBLE: Check if currently in targeting mode
func is_in_targeting_mode() -> bool:
	return _targeting_mode


## EXPLOSION_REBUILD_MASTER_PLAN Task 5 (E-WAVE, 2026-08-07): the real
## trigger, reconnected — disconnected 2026-08-05 (commit `d412480`) while the
## destruction visual system was rebuilt from scratch (the prior patch-on-
## patch arc, PERF-01/02/03 + D11 + D-ARCH-01, was judged not worth its own
## cost/complexity). `DetonationPlanBuilder.build_plan()` (Task 4) does all
## resolution and exposure fallback up front; `DetonationChoreographer`
## (Task 5) is the only thing that actually paints it, as the real 15-wave
## sequence from §1's table. Firearm destruction
## (WeaponBenchController.fire_active()) is untouched by this — it still
## renders through VoxelRenderer.process_dirty()'s single-frame D-ARCH-01 swap.
##
## Gap, flagged not silently dropped: VFX-01's per-voxel dust/spark/chip
## debris (room._dispatch_destruction_vfx(), driven by the voxel_destroyed
## signal) does not fire for blast-caused destruction any more — the
## choreographer's destroy wave calls layer.erase_cell() directly rather than
## going through VoxelRenderer.process_dirty(), and the DetonationPlan's own
## destroy entries carry no material to dispatch debris VFX from (§6.1's
## literal shape is {cell, level} only). Firearms are unaffected (still the
## signal-driven path). Revisit if the Director wants blast debris back —
## needs material threaded onto destroy plan entries, not a quick patch here.
func detonate_active() -> void:
	if _active_index < 0 or _active_index >= _grenades.size():
		return
	var g: Dictionary = _grenades[_active_index]
	if not g["detonated"]:
		var anchor: Vector2 = _blast_anchor(g)
		var sprite: Sprite2D = g["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false
		g["detonated"] = true

		var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
		if bomb_def != null and room._edge_registry != null and room._slab_registry != null:
			var gu: Vector2i = g["gu_cell"]
			## P-COOK (2026-08-09) — **NOTHING BLOCKS HERE ANY MORE.** This used
			## to be `build_plan()` + `commit()` on adjacent lines, ~190 ms of
			## synchronous work inside the frame the player clicked on. The
			## prediction started when the menu opened and is normally already
			## finished; `_take_prediction()` returns whatever exists, done or
			## half-built, and never waits. The sequence below cooks if it must.
			_stop_pumping()
			_start_detonation_sequence(_take_prediction(bomb_def, gu), gu, anchor)

	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	_active_index = -1


## The prediction for this GU — resumed from the cache, or started now if the
## menu path was bypassed (the capture harness calls `detonate_active()`
## directly). Never waits.
func _take_prediction(bomb_def, gu: Vector2i) -> DetonationPrediction:
	var ctx := _build_detonation_ctx(gu)
	return room._prediction_cache.request(
		PredictionCache.blast_signature(BOMB_ID, gu, room._active_perspective),
		room._world_revision, bomb_def, gu, ctx)


## §4.2's pre-production, started when the player picks a target.
##
## Cancelling and restarting is CHEAP by construction — Tasks 2 and 3 mean
## nothing has been written, so there is nothing to undo. That is what makes the
## Director's *"jogar fora e começar de novo rapidamente"* an actual property of
## the code rather than an aspiration. The cache does the cancelling (§4.2: a
## superseded request is cancelled, not finished); this only asks.
func _begin_preproduction(gu: Vector2i) -> void:
	var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
	if bomb_def == null or room._edge_registry == null or room._slab_registry == null:
		return
	var ctx := _build_detonation_ctx(gu)
	room._prediction_cache.request(
		PredictionCache.blast_signature(BOMB_ID, gu, room._active_perspective),
		room._world_revision, bomb_def, gu, ctx)
	_pump_prediction()


## Advances the cache's in-flight prediction one budget per frame until it
## finishes or something cancels it.
##
## A coroutine rather than a `_process()` because this controller is not a Node —
## the same reason `_start_detonation_sequence()` is one. Self-terminating (the
## cache stops being busy) and interruptible (`_stop_pumping()`), so there is no
## timer to leak and no second one can start while one is running.
func _pump_prediction() -> void:
	if _pumping:
		return
	_pumping = true
	while _pumping and room._prediction_cache.is_busy():
		room._prediction_cache.pump(predict_budget_ms)
		await room.get_tree().process_frame
	_pumping = false


func _stop_pumping() -> void:
	_pumping = false


## Called when the player backs out of the menu. The half-built prediction is
## KEPT, not cancelled: the cache is keyed on (action, world revision), so if the
## player reopens the same grenade with nothing changed in between, the work
## already done is still valid and gets resumed instead of repeated. §5.1's whole
## point — "coming back is the common case, because the sweep is a comparison."
func cancel_preproduction() -> void:
	_stop_pumping()


## P-STROBE (Director, 2026-08-09) — the detonation is THREE SEPARATE BEATS now,
## in the Director's own words: *"separar o fogo, do flash, da destruição."*
##
##   1. FIRE       burst + camera shake, alone, for `burst_lead_frames`
##   2. STROBE     4 held frames — white, negative, white, negative — with the
##                 fire still burning underneath ("o fogo se extende mais um
##                 pouco e permanece acontecendo durante os 4 frames do flash")
##   3. DESTRUCTION played clean, with no flash over it at all
##                 ("frame positivo com a destruição limpa acontecendo")
##
## This replaces E-FLASH-01's arrangement, where everything landed on one beat
## and the fade ran *underneath* the destruction. What forced the change: once
## the blast dropped to 5 frames (Q2's re-answer) the entire destruction
## finished inside the old 0.32 s fade, so the expanding front was invisible.
## Separating the beats is what makes the front visible AND keeps the flash.
##
## Nothing here is on a wall clock — every beat is counted in frames, the same
## rule the choreographer itself now runs on. A slow frame stretches a beat
## instead of skipping it.
##
## P-COOK (Task 6, 2026-08-09) prepends a beat 0 to that list, and it is the
## Director's own:
##
##   *"Se por acaso o cálculo ainda não tiver sido finalizado, travamos o sistema
##   aqui para ele finalizar o processamento. A granada fica 'cooking' no chão,
##   até soltar a cena."*
##
##   0. COOKING    the fire is already lit and the engine finishes thinking
##                 underneath it — for as long as it needs, zero frames if the
##                 pre-production already finished
##
## **Beat 0 costs nothing when it is not needed, and it needed no new visual.**
## P-STROBE had already established that the fire burns alone for
## `burst_lead_frames` before the strobe, so "the grenade sits there burning" was
## a beat this sequence already had — cooking simply makes its length depend on
## the engine instead of on a constant. That answers Q4 as "no, it does not need
## its own animation": the honest visual for *"the engine is still thinking"* was
## already on screen.
##
## The order matters and is not negotiable: FIRE FIRST, then think. Starting the
## burst before pumping is what removes the freeze — the player sees the
## explosion begin on the very frame they clicked, and the remaining computation
## happens under an animation instead of under a frozen camera.
##
## The DAMAGE is applied at the END of beat 0, by `delta.commit()`, once there is
## a Delta to commit. Everything after that only schedules when the player SEES
## it, so a dropped frame or a map reload mid-sequence loses pixels, never state.
##
## The choreographer is still handed `delta.waves`, never the Delta: playback has
## no business knowing a prediction layer exists, and a choreographer that could
## reach `commit()` would be a second writer.
##
## A coroutine (it awaits frames), deliberately called WITHOUT await by
## detonate_active(): the caller's remaining work — clearing the wireframe,
## resetting _active_index — belongs to the click, not to the animation. `self`
## stays alive because room holds `_test_zone_controller`, the same explicit
## ownership `_active_choreographer` exists for.
func _start_detonation_sequence(job: DetonationPrediction, gu: Vector2i,
		anchor: Vector2) -> void:
	## Beat 1 — fire and shake, alone. Unconditionally FIRST, before any
	## remaining computation: this is the frame the player clicked on.
	room.spawn_blast_burst(anchor)
	if room._camera_controller != null:
		room._camera_controller.shake(SHAKE_SECONDS, SHAKE_AMPLITUDE_PX)

	## Beat 0 — COOKING. Usually zero iterations, because pre-production started
	## when the menu opened. `cook_budget_ms` is the bigger of the two budgets:
	## with the grenade already burning there is no cursor to keep smooth, and a
	## bigger bite ends the wait sooner.
	var cook_frames: int = 0
	while not job.is_done() and not job.is_cancelled():
		job.step(cook_budget_ms)
		await room.get_tree().process_frame
		cook_frames += 1
	if job.delta == null:
		## Cancelled out from under us — a map load or a rotation while the fuse
		## was burning. Loud rather than silent: the fire is already on screen and
		## no destruction is going to follow it, which is worth a line in the log.
		push_warning("[P-COOK] prediction for gu=%s was cancelled mid-fuse — no destruction" % gu)
		return
	if cook_frames > 0:
		print_debug("[P-COOK] gu=%s cooked %d frame(s) at %.1f ms — pre-production was short by %.0f ms"
			% [gu, cook_frames, cook_budget_ms, float(cook_frames) * cook_budget_ms])

	## The commit, and everything that reads real Voxel state after it.
	job.delta.commit()
	DetonationPlanBuilderClass.print_census(job.delta, gu)
	## Deep diagnostic, off by default — the per-phase profile and the worst
	## single frame the prediction actually cost. §4.4's budget can only honestly
	## be judged on the REAL map (the two unsuspendable phases are both cheap on a
	## synthetic fixture), so this is the seam that measurement goes through.
	if OS.get_environment("INFILTRAITOR_PREDICTION_PROFILE") == "1":
		print("[P-SLICE] %d step(s) · worst step %.1f ms (phase %s) · total %.1f ms"
			% [job.steps, job.worst_step_ms, job.worst_step_phase, job.delta.cost_ms])
		for line in job.profile_lines():
			print("[P-SLICE]   " + line)
		print(room._prediction_cache.stats_line())
	room._gu_blast_count[gu] = int(room._gu_blast_count.get(gu, 0)) + 1
	## VL-PERSIST: record every voxel this blast actually changed so rotation
	## replays it — the exact set the Delta already carries, no second flood/
	## find_affected_containers pass needed. Reads the real Voxel fields, so it
	## has to follow the commit.
	for voxel in job.delta.touched_voxels:
		room.record_voxel_damage_to_base(voxel.grid_pos, voxel.level, voxel.damage_state,
			voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant,
			voxel.damage_substrate)
	var waves: Dictionary = job.delta.waves
	## §5.2: the world just moved, so every cached prediction — including this
	## one — is now stale. AFTER the commit, never before.
	room.bump_world_revision()

	## The rest of beat 1: however much fire-only lead is still owed. Cooking
	## already spent frames here, so a long fuse does not additionally delay the
	## strobe — `burst_lead_frames` is a MINIMUM, not an extra.
	for _i in range(maxi(burst_lead_frames - cook_frames, 0)):
		await room.get_tree().process_frame

	## Beat 2 — E-SHARD: camera-facing shard that becomes the negative flash.
	## Replaces STROBE_SEQUENCE entirely (WHITE frames never used anymore).
	## One frame leaving the grenade (small, black) → 2 frames growing/desaturating
	## toward grey → holds at full negative (1.0) for 1 frame → 3 frames fade
	## to normal (1.0 → 0.0).
	var flash_overlay = room._explosion_flash_overlay
	if flash_overlay != null:
		## Shard frames 1-3: growing approach (strobe animates 0 → 1)
		for i in range(3):
			flash_overlay.strobe_negative_amount = float(i + 1) / 3.0
			flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
			await room.get_tree().process_frame
		## Peak frame: full negative
		flash_overlay.strobe_negative_amount = 1.0
		flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
		await room.get_tree().process_frame
		## Shard frames 5-7: fading out (strobe animates 1.0 → 0)
		for i in range(3):
			flash_overlay.strobe_negative_amount = 1.0 - float(i + 1) / 3.0
			flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
			await room.get_tree().process_frame
		flash_overlay.clear()

	## E-DEBUG-RAY: show debug rays to all affected voxels before destruction
	if room._debug_ray_overlay != null:
		room._debug_ray_overlay.show_debug_rays(anchor, waves, room._voxel_renderer)

	## E-FRAG: shrapnel from affected cells
	if room._shrapnel_overlay != null:
		room._shrapnel_overlay.spawn_shrapnel(anchor, waves, room._voxel_renderer)

	## Beat 3 — destruction, clean.
	_start_waves(waves)


func _start_waves(waves: Dictionary) -> void:
	var choreographer := DetonationChoreographerClass.new()
	_active_choreographer = choreographer
	choreographer.finished.connect(func(): _active_choreographer = null)
	choreographer.start(waves, room._voxel_renderer, room._smoke_spark_overlay, room.get_tree())


## The point the fireball blooms from: the top-centre of the grenade sprite, in
## world space — the Director's "anchor point em cima da granada". Deliberately
## the same geometry _top_screen_pos() uses for the context menu, minus its
## canvas-transform step, so the two never drift apart.
func _blast_anchor(grenade: Dictionary) -> Vector2:
	var sprite: Sprite2D = grenade["sprite"]
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return room.agent._cell_to_world(grenade["gu_cell"])
	var rect := _sprite_global_rect(grenade)
	return rect.position + Vector2(rect.size.x / 2.0, 0.0)


## The real ctx DetonationPlanBuilder.build_plan() needs, assembled from the
## live room — mirrors detonation_plan_selftest.gd's own MinimalRoom ctx
## builder, except lights/shadow_results come from the REAL LightingController
## instead of a hand-converted map-data dict (a real room already has one).
func _build_detonation_ctx(source_gu: Vector2i) -> Dictionary:
	var lights: Array = []
	var shadow_results: Array = []
	if room._lighting_controller != null:
		var registry = room._lighting_controller.get_light_registry()
		if registry != null:
			lights = registry.get_active_lights()
		shadow_results = room._lighting_controller.get_shadow_results()
	return {
		"edge_registry": room._edge_registry,
		"slab_registry": room._slab_registry,
		"voxel_renderer": room._voxel_renderer,
		"blocked_edges": _blocked_edges_dict(),
		"blocked_cells": room._blocked_cells,
		"lights": lights,
		"shadow_results": shadow_results,
		"under_structure": room._under_structure,
		## D2: unlocked from this GU's SECOND blast onward.
		"deep_layer_unlocked": int(room._gu_blast_count.get(source_gu, 0)) > 0,
		## E-DENT-01 (Director, 2026-08-08): "vamos apagar o stamp de fuligem por
		## enquanto." The blast's authored soot stamp is OFF for every real
		## detonation now — the 2026-08-08 A/B proved it is what produces the
		## "quebradiça" checkerboard, and it was covering the dented/cracked
		## atoms this phase exists to look at. Deliberately a live-caller flip,
		## not a deletion: build_plan()'s own default stays `true` (the stamp is
		## still the designed behavior, Task 3), so nothing in the calculation
		## layer or its selftests moves, and the whole reversal is this one
		## boolean. INFILTRAITOR_ENABLE_STAMP_SOOT=1 brings it back for a
		## comparison capture — the same seam as before, inverted.
		## derive_soot_rings()/apply_self_soot() are untouched: a voxel next to a
		## real hole still scorches, which is the soot that predates the rebuild.
		"stamp_soot_enabled": OS.get_environment("INFILTRAITOR_ENABLE_STAMP_SOOT") == "1",
	}


func cancel_active() -> void:
	_active_index = -1
	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	cancel_preproduction()


## room._current_blocked_edges entries are {"from": Vector2i, "to": Vector2i}
## pairs (see map_geometry.gd's _wall_cell_blocked_edges()) — folds them into
## the keyed Dictionary shape WallEdgeData.is_edge_blocked() queries, same
## conversion MovementOverlay.set_blocked_edges() already does.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked
