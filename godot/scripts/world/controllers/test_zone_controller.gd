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
const AgentProbePropClass = preload("res://godot/scripts/overlays/agent_probe_prop.gd")
const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")
const DetonationChoreographerClass = preload("res://godot/scripts/systems/destruction/detonation_choreographer.gd")

var room: Node
var _grenades: Array[Dictionary] = []
var _active_index: int = -1
## CHARACTER_MASTER_PLAN Part 2 probe — baked agent figures standing on the
## floor so the Director can judge proportion and lighting against real voxel
## geometry. Kept in their own list, not in `_grenades`: they are not
## detonatable, not throwable, and nothing here should ever iterate them as if
## they were. See AgentProbeProp's header for what this deliberately is NOT.
var _agent_probes: Array[Dictionary] = []

## T-MODE: targeting mode active (grenade selected, waiting for target)
var _targeting_mode: bool = false


## Public, because room.gd's input router has to know whether AIM MODE owns the
## right button this frame. Reading `_targeting_mode` across the boundary would
## make a private field part of the contract.
func is_targeting() -> bool:
	return _targeting_mode
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
## vermelho parece ok, poderia ser um pouquinho mais largo" → 6.5, then "o
## perímetro precisa passar pelo centro das últimas GUs que o arremesso alcança"
## → **7.0**.
##
## KEEP THIS A WHOLE NUMBER. The projection preserves grid distance exactly
## (iso_projection_selftest [6]), so a cell exactly R GU away lands exactly ON
## the drawn ellipse — but only if R is a whole number of cells, because cell
## centres only ever sit at integer offsets. At 6.5 the line ran through empty
## space between two rings and meant nothing on the board.
var throw_range_gu: float = 7.0

## POSTURE PENALTIES (Director, 2026-08-19: *"deitar e atirar a granada (com
## penalidades de distância)"*).
##
## Whole numbers, for the reason the note above gives about `throw_range_gu`
## itself: the perimeter ellipse only means anything at integer cell radii, and a
## penalty that produced 4.9 would draw a ring through empty space. So the
## penalty is expressed as CELLS SUBTRACTED rather than as a multiplier — a
## multiplier is the natural way to write it and would quietly reintroduce the
## fractional radius this overlay was already burned by.
##
## Placeholders, like every balancing row in this project: a crouched thrower
## loses reach, a prone one loses most of it. Nothing is calibrated against
## anything yet, and D6 makes these levers rather than constants.
var throw_range_penalty_gu: Dictionary = {
	DebugAgent.Posture.STANDING: 0.0,
	DebugAgent.Posture.CROUCHING: 2.0,
	DebugAgent.Posture.PRONE: 4.0,
}


## The reach this agent actually has right now. Floored at 1 GU: a prone agent
## throwing a grenade badly is a design outcome, a prone agent unable to throw at
## all is a silently disabled action.
func effective_throw_range_gu() -> float:
	var penalty: float = float(throw_range_penalty_gu.get(
		room.agent.posture, 0.0))
	return maxf(throw_range_gu - penalty, 1.0)

## Radius of the aim dome, in GAME UNITS. Deliberately NOT derived from
## `bomb_def.ring_multipliers.size()`: the dome is the readable shape of the
## blast, and the per-cell truth of how far it reaches is what the shrapnel rays
## carry.
##
## 1.5 -> 2.0 (Director, 2026-08-10): "pode ser um pouquinho mais largo que as
## 1,5 GUs, vamos fazer 2, para ficar uma sobrinha por cima de outras GUs nos
## cantos. A ideia é indicar que a granada é meio imprecisa, e a região de dano
## se estende além das GUs, sem uma localização exata." At exactly 2.0 the rim
## passes through the centres of the cells two out along each axis — the spill
## is the message, so the number is not arbitrary.
var aim_dome_radius_gu: float = 2.0

## Seconds the thrown grenade takes to travel its arc; how long it then sits on
## the ground before going off; and the cap on how much longer the fuse may
## stretch for a prediction that is somehow still cooking after all that.
var throw_duration_s: float = 0.6
var grenade_cook_s: float = 1.0
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

## `INFILTRAITOR_THROW_PROFILE=1` — one timeline for a whole throw, from the
## release to the last wave, in both milliseconds and FRAMES. Off by default,
## same seam and same reasoning as `INFILTRAITOR_PREDICTION_PROFILE`: the
## question "is the engine still thinking when the fuse ends" can only be
## answered on the real map, and only end to end. Frames are reported next to
## the clock because everything in this sequence is paced by frames — a wall
## clock alone cannot tell a slow frame from an extra one.
const THROW_PROFILE_ENV := "INFILTRAITOR_THROW_PROFILE"
var _prof_t0_ms: int = 0
var _prof_f0: int = 0

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
	for p in _agent_probes:
		var probe: Sprite2D = p.get("sprite")
		if probe != null and is_instance_valid(probe):
			probe.queue_free()
	_agent_probes.clear()
	_active_index = -1
	## RUNTIME-GUARD-01 (2026-08-13): drop an in-flight blast too. This runs on
	## map load (`_populate_test_zone_if_playground()`), and a sequence started
	## against the OLD room's VoxelRenderer has nothing left to paint into — the
	## renderer is rebuilt by `load_map()`. Releasing the reference lets the
	## coroutine's own `is_instance_valid()` guard end it on the next frame
	## instead of it running on against freed geometry.
	_active_choreographer = null


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


## CHARACTER_MASTER_PLAN Part 2 probe. Same perspective contract add_grenade()
## uses — the view-space cell is stored converted to a base cell so rotation can
## follow it — because a figure that drifts off its tile on a perspective flip
## would corrupt the proportion judgement this probe exists for.
func add_agent_probe(gu_cell: Vector2i, cfg: Dictionary = {}) -> void:
	var base_cell: Vector2i = room._cell_to_base(gu_cell, room._active_perspective)
	var sprite := AgentProbePropClass.new()
	sprite.setup(room, gu_cell, base_cell, cfg)
	sprite.position = room.agent._cell_to_world(gu_cell)
	room.add_child(sprite)
	_agent_probes.append({"gu_cell": gu_cell, "base_cell": base_cell, "sprite": sprite})


## Follows room.gd's dev-vision toggle. The probes are the only props with a
## second bake, so this stays here rather than becoming a general prop contract.
func set_agent_probes_dev_vision(enabled: bool) -> void:
	for p in _agent_probes:
		var probe: AgentProbePropClass = p.get("sprite")
		if probe != null and is_instance_valid(probe):
			probe.set_dev_vision(enabled)


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
	for p in _agent_probes:
		var probe_cell: Vector2i = PerspectiveMapperClass.cell_from_base(p["base_cell"], direction, base_size)
		p["gu_cell"] = probe_cell
		var probe: AgentProbePropClass = p["sprite"]
		if probe != null and is_instance_valid(probe):
			probe.position = room.agent._cell_to_world(probe_cell)
			probe.update_cell(probe_cell)


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
	## First grenade that has NOT already gone off. This used to be a flat
	## `_targeting_grenade_index = 0`, which is the bug the Director reported as
	## "uma segunda granada não aparece sendo lançada": after the first throw,
	## grenade 0 is spent and its sprite has `visible = false`, so the second
	## throw dutifully animated an invisible prop along the arc and then detonated
	## a grenade that had already detonated. Nothing appeared, and the count of
	## grenades never went down.
	##
	## The test-zone scaffold does not have a real inventory yet, so when the
	## player has exhausted every live grenade we spawn a fresh one on the spot
	## instead of blocking the action. That suspends the effective grenade limit
	## in this gameplay path without introducing a separate inventory system.
	_targeting_grenade_index = _first_live_grenade()
	if _targeting_grenade_index < 0:
		var spawn_cell: Vector2i = room.agent.cell if room.agent != null else Vector2i.ZERO
		add_grenade(spawn_cell)
		_targeting_grenade_index = _first_live_grenade()
	if _targeting_grenade_index < 0:
		print_debug("[T-MODE] no grenades left to throw")
		return
	_targeting_mode = true
	_targeting_target_gu = room.agent.cell + DEFAULT_TARGET_OFFSET
	## Director, 2026-08-19: *"Quando o jogador selecionar a GU [...] o agente já
	## mira."* The arm comes up the moment targeting opens and HOLDS there for the
	## whole aim — `hold: true` freezes the raise on its last frame, which is the
	## cocked pose. By the time the player commits, the throw is already loaded.
	room.agent.play_throw_raise()
	_update_grenade_targeting_display()


## Index of the first grenade still on the board, or -1 when they are all spent.
func _first_live_grenade() -> int:
	for i: int in range(_grenades.size()):
		if not _grenades[i]["detonated"]:
			return i
	return -1


## Hover-driven entry point — room._input() calls this whenever the cursor
## crosses into a new cell.
func _update_grenade_targeting_display() -> void:
	if not _targeting_mode or _targeting_grenade_index < 0:
		return
	var hovered: Vector2i = room._hovered_cell
	if hovered == room.INVALID_CELL:
		hovered = _targeting_target_gu
	_set_targeting_target(hovered)


## T-TAP (Director, 2026-08-10): "um segundo clique/tap na GU que está com a
## bolha marcada dispara a bomba (enter)."
##
## First tap aims, second tap on the SAME cell throws — which is what makes the
## flow work with no hover at all, and PREDICTION_MASTER_PLAN §4.2's own trigger
## ("hover, or first tap on a GU for mobile"). The comparison is made on the
## CLAMPED cell, not the raw one: two taps beyond the perimeter both resolve to
## the same edge cell, so the second still fires rather than silently re-aiming
## at a target that never moved.
##
## Returns true when the click belonged to targeting, so the caller can consume
## it instead of moving the agent.
func handle_targeting_click(cell: Vector2i) -> bool:
	if not _targeting_mode or _targeting_grenade_index < 0:
		return false
	if cell == room.INVALID_CELL:
		return false
	if _clamp_gu_to_throw_range(cell, room.agent.cell) == _targeting_target_gu:
		execute_grenade_throw()
	else:
		_set_targeting_target(cell)
	return true


## Aim at a cell (clamped to range) and rebuild every aiming overlay —
## perimeter, dome, arc, shrapnel rays, affected GUs and the virtual grenade.
func _set_targeting_target(cell: Vector2i) -> void:
	if not _targeting_mode or _targeting_grenade_index < 0:
		return

	var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
	if bomb_def == null:
		push_error("[TestZoneController] targeting: bomb '%s' is not in the registry" % BOMB_ID)
		cancel_targeting()
		return

	var origin_gu: Vector2i = room.agent.cell
	var agent_pos: Vector2 = room.agent.position

	## T-DEV (Director, 2026-08-10): "tanto o perímetro vermelho do alcance,
	## quanto o perímetro vermelho do dano, vamos deixar ativos só no DEV VISION.
	## Durante o gameplay normal o HUD só vai mostrar a bolha, os raios, e a
	## granada virtual."
	##
	## Both reds are exact, legible diagrams of numbers the player is not supposed
	## to be reading off the board — the throw's radius and the blast's cell list.
	## They stay as a development instrument; the dome and the rays are what say
	## the same things approximately, which is the point.
	var dev: bool = room._vision_controller != null and room._vision_controller.dev_vision

	## The perimeter is the locus of `throw_range_gu` around the agent, projected
	## by IsoProjection — the same radius, in the same units, the clamp below uses.
	## The CLAMP is unaffected by the toggle: the range is real either way, only
	## the line drawing it is a dev tool.
	if room._throw_perimeter_overlay != null:
		if dev:
			room._throw_perimeter_overlay.show_perimeter(agent_pos,
				effective_throw_range_gu())
		else:
			room._throw_perimeter_overlay.clear()

	_targeting_target_gu = _clamp_gu_to_throw_range(cell, origin_gu)
	## He faces what he is about to throw at, and re-faces when the aim moves.
	## `face_direction()` owns the reduction to D44's four facings, so an
	## arbitrary GU delta is the right thing to hand it.
	if room.agent.sprite != null and _targeting_target_gu != origin_gu:
		room.agent.sprite.face_direction(_targeting_target_gu - origin_gu)
	var target_pos: Vector2 = room.agent._cell_to_world(_targeting_target_gu)

	## E-BUBBLE: the dome. A fixed geometric shape, NOT the predicted footprint —
	## see aim_bubble_overlay.gd's header for why the Director ruled that out.
	## The GU cell goes along with the screen position because the dome sections
	## itself against nearby walls, and `room._wall_height_edges` is keyed by the
	## cell PAIR each wall separates — a screen position cannot find them.
	if room._aim_bubble_overlay != null:
		room._aim_bubble_overlay.show_dome(target_pos, aim_dome_radius_gu,
			_targeting_target_gu, room._wall_height_edges)

	## The throw leaves the agent's HANDS, not their feet — the perimeter is a
	## ground shape but the arc is not.
	if room._throw_arc_overlay != null:
		room._throw_arc_overlay.set_launch_height(room.agent.throw_launch_height())
		room._throw_arc_overlay.show_arc(room.agent.throw_origin(), target_pos)

	## ⚠️ PRE-PRODUCTION STARTS HERE NOW, not on the throw.
	##
	## The Director asked (2026-08-19) to confirm whether the grenade pre-computes
	## *"assim que o jogador aperta G e seleciona a GU"*. It did NOT: the line
	## below used to end *"the expensive part is `_begin_preproduction()`, which
	## stays on the throw"*, and `execute_grenade_throw()` was its only caller in
	## this flow. So the aim window — the seconds a human spends reading the dome
	## and deciding — was being spent on overlays while the ~190 ms of prediction
	## waited for the confirm.
	##
	## Moving it here is what P-COOK was designed for and says so in its own
	## header: the trigger is *"hover, or first tap on a GU"*. It is safe to
	## re-trigger, because `_begin_preproduction()` cancels and re-keys against
	## `PredictionCache` — which is exactly the cycling/cancellation shape §0
	## says the cache already solves. `execute_grenade_throw()` still calls it
	## too: the target can change between the select and the confirm, and a
	## second call on an unchanged target is a cache hit rather than a re-run.
	_begin_preproduction(_targeting_target_gu)

	## The SAME wall-aware BFS the real blast floods with feeds both the rays and
	## the highlighted footprint, so a cell the grenade cannot reach gets neither.
	## Cheap enough to redo per hover: `max_ring` is 3, so this walks ~25 cells.
	var gu_rings := _damaging_rings(BlastCalculatorClass.flood_gu_rings(
		_targeting_target_gu, bomb_def, _blocked_edges_dict(), room._blocked_cells), bomb_def)

	## T-FRAG: the shrapnel rays.
	if room._shrapnel_preview_overlay != null:
		room._shrapnel_preview_overlay.show_rays(_targeting_target_gu, gu_rings)

	## T-FILL: the affected GUs, at the base of the dome — Director: "assim como
	## no Phoenix Point, vamos realçar as GUs afetadas pela granada, para indicar
	## quais inimigos vão ser atingidos." Same overlay the right-click menu
	## already uses; passing the ring data turns on its graded red fill.
	## Dev-only per T-DEV above — the exact cell list is the developer's readout.
	if room._blast_wireframe_overlay != null:
		if dev:
			room._blast_wireframe_overlay.show_footprint(gu_rings.keys(), gu_rings)
		else:
			room._blast_wireframe_overlay.clear()

	## T-CURSOR: the virtual grenade replaces the magenta selection diamond for
	## as long as the throw is being aimed. The perspective goes with it — it is
	## the real baked prop, so it has a per-view frame like the prop does.
	if room._target_cursor_overlay != null:
		room._target_cursor_overlay.show_at(target_pos, room._active_perspective)
	if room.selection_overlay != null:
		room.selection_overlay.visible = false


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

	_prof_t0_ms = Time.get_ticks_msec()
	_prof_f0 = int(Engine.get_process_frames())
	_prof("RELEASE — throw starts, pre-production starts")

	_begin_preproduction(target_gu)
	## THE ARC WAITS FOR THE HAND. The release sequence emits `throw_released` at
	## the phase the grenade actually leaves — derived from the key list, not from
	## a hardcoded frame — so the projectile and the arm agree even if the
	## animation is retimed. `await` on a signal that may never fire would hang
	## the throw, so a posture with no throw bake (crouch/prone, still being
	## refined) returns false and the arc starts immediately, exactly as it did
	## before this animation existed.
	if room.agent.play_throw_release():
		await room.agent.sprite.throw_released
	_start_grenade_throw_animation(target_gu, grenade)


## Cancel targeting mode
func cancel_targeting() -> void:
	if not _targeting_mode:
		return
	_targeting_mode = false
	_targeting_grenade_index = -1
	## Director: *"cancelar a granada [...] bem rapidinho, só pra não sumir de
	## repente."* The arm comes back down along the same path it went up, because
	## this IS the raise sequence played backwards — see AgentSprite's THROW_ROOT
	## note for why the cancel is not its own bake.
	room.agent.play_throw_cancel()
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
	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	if room._target_cursor_overlay != null:
		room._target_cursor_overlay.clear()
	## The magenta diamond only steps aside for the duration of the throw.
	if room.selection_overlay != null:
		room.selection_overlay.visible = true


## The subset of a flood that actually TAKES damage.
##
## Director, 2026-08-10: "o perímetro vermelho da granada no chão está muito
## largo, vamos reduzir uma GU no raio." It was too wide by exactly one ring, and
## the reason is in the bomb data rather than in any drawing code:
## `flood_gu_rings()` caps at `ring_multipliers.size() - 1` because that array's
## LENGTH is the bomb's range — but `frag_grenade`'s last entry is `0.0`, and
## every one of its per-tier weights is 0.0 there too. That outermost ring is
## reached and takes nothing. It exists so the smoke and soot tables have a
## faint outer step, which is cosmetic.
##
## So this trims by DAMAGE rather than by a hardcoded -1: a bomb whose outermost
## ring does hurt keeps it, and one with two dead rings loses both.
func _damaging_rings(gu_rings: Dictionary, bomb_def) -> Dictionary:
	var kept: Dictionary = {}
	var multipliers: Array = bomb_def.ring_multipliers
	for cell: Vector2i in gu_rings.keys():
		var ring: int = int(gu_rings[cell])
		if ring < multipliers.size() and float(multipliers[ring]) > 0.0:
			kept[cell] = ring
	return kept


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
	if distance_gu <= effective_throw_range_gu():
		return target_gu
	## The CLAMP has to scale by the EFFECTIVE range, not the base one. Reading
	## `throw_range_gu` here while the test two lines up reads the effective range
	## would let an out-of-range target snap to a cell the agent cannot reach —
	## the penalty would shrink the ring and change nothing about where the
	## grenade lands, which is the worst of both.
	return origin_gu + Vector2i(
		(delta / distance_gu * effective_throw_range_gu()).round())


## T-ARC: fly the grenade along its arc, then detonate where it lands.
##
## The frame loops below advance on `room.get_process_delta_time()`. They used to
## advance on `room.get_tree().get_physics_frame()`, which does not exist on
## SceneTree in Godot 4.6 — every throw raised "Invalid call. Nonexistent
## function 'get_physics_frame'" on the first iteration, aborted this coroutine,
## and the grenade never moved and never detonated.
func _start_grenade_throw_animation(target_gu: Vector2i, grenade: Dictionary) -> void:
	## Typed as the prop, not as Sprite2D: the flight drives the ground shadow
	## through `set_flight_height_px()`, which only GrenadeProp has.
	var sprite: GrenadePropClass = grenade.get("sprite")
	if sprite == null or not is_instance_valid(sprite):
		push_error("[TestZoneController] throw: grenade %s has no sprite to animate" % target_gu)
		return

	var bomb_def = Registries.get_bomb_registry().get_bomb(BOMB_ID)
	if bomb_def == null:
		push_error("[TestZoneController] throw: bomb '%s' is not in the registry" % BOMB_ID)
		return

	var tree: SceneTree = room.get_tree()
	var target_world: Vector2 = room.agent._cell_to_world(target_gu)
	## Same origin the preview arc used — the agent's hands, not their feet.
	var start_pos: Vector2 = room.agent.throw_origin()

	## The flight follows ThrowArcOverlay's OWN parabola, with the overlay's own
	## ratio — the grenade cannot fly a different curve from the one the player
	## was shown while aiming.
	var arc = room._throw_arc_overlay
	if arc == null:
		push_error("[TestZoneController] throw: no ThrowArcOverlay to take the trajectory from")
		return
	var launch_px: float = room.agent.throw_launch_height()
	var arc_height: float = ThrowArcOverlay.arc_height_for(
		start_pos, target_world, arc.arc_height_ratio, launch_px)

	## ROTATION IS ONE CONTINUOUS MOTION from release to rest, and that is the
	## whole fix for the Director's "a roladinha da granada no final do arremesso
	## não ficou natural, parece forçada". The first version played three
	## unrelated motions back to back: a tumble at constant full speed for the
	## entire flight, a bounce with the sprite frozen solid, then a 22.5° twitch
	## starting from a standstill. Each was individually tuned and the sequence
	## still read as forced, because nothing connected them. Now one angular
	## velocity decays from the tumble, through the bounce, into the settle.
	##
	## Two things that a fixed rule genuinely cannot cover — the Director's own
	## objection ("depende do ângulo, e da distância") — are handled by deriving
	## them instead of picking numbers:
	##
	## ANGLE. A ground roll spins about an axis perpendicular to travel. When that
	## axis lies across the screen you see the whole rotation; when it points at
	## the camera (a throw straight up or down the screen) you see none of it —
	## a real grenade rolling away from you does not appear to spin, it just
	## recedes. `roll_dir.x` IS that projection, so it replaces the old arbitrary
	## `sign()` and the vertical-throw case stops being a coin flip.
	##
	## DISTANCE, AND WHY IT IS MEASURED IN GU. `ThrowArcOverlay`'s friction model
	## (see its `roll_turns_at_max_range` block) grades the settle by the speed the
	## grenade lands at — duration linearly, amount with the square. The speed here
	## is the ground track over the flight time, so all that varies is the ground
	## DISTANCE, and that has to be read in GAME UNITS, not in screen pixels: the
	## isometric floor is 181.02 px/GU across and 90.51 px/GU down
	## (`IsoProjection.floor_circle_semi_axes`), so the same real throw measures
	## half as far when aimed up or down the screen. Pixels would under-rate exactly
	## the throws the Director's "depende do ângulo" is about.
	var ground_start: Vector2 = start_pos + Vector2(0.0, launch_px)
	var travel: Vector2 = target_world - ground_start
	var roll_dir: Vector2 = travel.normalized() if travel.length() > 0.001 else Vector2.RIGHT
	var spin_visibility: float = roll_dir.x

	var origin_gu: Vector2i = room.agent.cell
	var distance_gu: float = Vector2(target_gu - origin_gu).length()
	## 0 at the thrower's feet, 1 at the far edge of the throw perimeter. Both
	## curves below are anchored to what happens at 1, so nothing is quantised and
	## nothing is clamped from underneath — a 1 GU lob really does roll almost
	## nothing, and that is the physics, not a floor.
	## Deliberately the BASE range, not the effective one: this is how fast the
	## grenade flies for a given distance, and a 3 GU throw should look like a
	## 3 GU throw whether the thrower is standing or prone. Normalising by the
	## penalised range would make every prone throw fly at full speed.
	var speed_ratio: float = clampf(distance_gu / maxf(throw_range_gu, 0.001), 0.0, 1.0)
	var settle_forward_s: float = arc.settle_duration_at_max_range(grenade_cook_s) * speed_ratio
	var settle_back_s: float = settle_forward_s * arc.roll_back_duration_ratio
	var forward_turns: float = arc.roll_turns_at_max_range * speed_ratio * speed_ratio
	var back_turns: float = forward_turns * arc.roll_back_ratio

	## Turns per second the flight tumbles at, and the rate the settle STARTS at.
	## The second is derived, not chosen: an ease-out of 1-(1-t)² has an initial
	## derivative of 2, so a roll of `forward_turns` over `settle_forward_s` begins
	## at exactly this speed. Decaying the bounce down to it is what makes the
	## hand-off invisible.
	var flight_rate: float = arc.flight_turns / maxf(throw_duration_s, 0.001)
	var settle_rate: float = minf(
		2.0 * forward_turns / maxf(settle_forward_s, 0.001), flight_rate)

	## The ground shadow follows the flight by HEIGHT, not by the sprite's screen
	## position — Director: "a sombra precisa acompanhar no chão... de acordo com a
	## distância vertical." The height is the gap between the body and the ground
	## point directly under it, which on this path is the linear ground track from
	## the hand's own floor point to the target. Taking it from the arc rather than
	## re-deriving a second parabola is the same rule the tumble already follows.
	## Z-INDEX-01 (Director, 2026-08-13): while airborne this prop must draw
	## above every real voxel column, not sort by the level-0 value
	## `_apply_z_index()` set at `setup()` — see `GrenadeProp.set_airborne()`
	## for the full reasoning and the measurement that found the bug (405 px
	## of real apex height, z_index frozen at level 0 the whole flight).
	## Restored to ground-level sorting once the landing bounce settles, below.
	sprite.set_airborne(true)

	var turns: float = 0.0
	var elapsed: float = 0.0
	while elapsed < throw_duration_s:
		await tree.process_frame
		var delta: float = room.get_process_delta_time()
		elapsed += delta
		var t: float = minf(elapsed / throw_duration_s, 1.0)
		sprite.position = ThrowArcOverlay.arc_point(
			start_pos, target_world, t, arc_height, launch_px)
		turns += flight_rate * delta
		sprite.rotation = turns * TAU * spin_visibility
		sprite.set_flight_height_px(ground_start.lerp(target_world, t).y - sprite.position.y)
	sprite.position = target_world
	sprite.set_flight_height_px(0.0)
	grenade["gu_cell"] = target_gu

	## The landing hop — Director: "dá um bounce no chão de leve" — with the
	## tumble bleeding off across it instead of stopping dead on contact.
	var bounce_height: float = arc_height * arc.bounce_height_ratio
	var bounced: float = 0.0
	while bounced < arc.bounce_duration_s:
		await tree.process_frame
		var delta: float = room.get_process_delta_time()
		bounced += delta
		var bt: float = minf(bounced / arc.bounce_duration_s, 1.0)
		var lift: float = ThrowArcOverlay.bounce_lift(bt, bounce_height)
		sprite.position = target_world - Vector2(0.0, lift)
		turns += lerpf(flight_rate, settle_rate, bt) * delta
		sprite.rotation = turns * TAU * spin_visibility
		sprite.set_flight_height_px(lift)
	sprite.position = target_world
	sprite.set_flight_height_px(0.0)
	## Back on the ground for real — the post-bounce roll is real floor
	## contact and belongs under D22-FOLLOWUP's ordinary level-0 sort again.
	sprite.set_airborne(false)

	## COOKING — Director: "antes de pausar para ficar 'cooking' por aprox. 1
	## segundo." The grenade sits on the ground for a beat before it goes off.
	## The prediction finishes INSIDE this second rather than after it: that is
	## the whole point of P-COOK's pre-production, and the fuse is exactly the
	## kind of human-paced gap §4.2 was designed to hide the work in.
	##
	## The settle happens inside that second: "a granada pode rolar um pouquinho
	## pra frente (em relação ao arremesso), e depois rolar um pouco pra trás, e
	## parar." Rolling back less than it rolled forward is what makes it read as
	## settling rather than as bouncing.
	##
	## Both durations now come from the throw's own energy (see the friction block
	## above), so a lob settles in a fraction of a second and a full-range throw
	## rolls for most of the fuse. The ease-out below is UNCHANGED — under constant
	## friction it is already the exact solution, so freeing the graduation was only
	## ever a question of where its two numbers come from.
	##
	## And it is a ROLL, not a pivot: every turn moves the grenade `r·θ` along the
	## ground. That coupling is what a spin-in-place was missing, and it is also
	## why the translation uses the TURNS rather than the visible rotation — a
	## grenade rolling away from the camera still travels even though it shows no
	## rotation at all.
	var turns_at_rest: float = turns
	var cooked: float = 0.0
	while cooked < grenade_cook_s:
		await tree.process_frame
		cooked += room.get_process_delta_time()
		if cooked < settle_forward_s:
			## Ease-out: starts at exactly `settle_rate`, arrives stopped.
			var ft: float = cooked / settle_forward_s
			turns = turns_at_rest + forward_turns * (1.0 - (1.0 - ft) * (1.0 - ft))
		elif cooked < settle_forward_s + settle_back_s:
			## Smoothstep back: leaves and arrives at zero speed, so neither end
			## of the rock reads as a jolt.
			var bt2: float = (cooked - settle_forward_s) / maxf(settle_back_s, 0.001)
			turns = turns_at_rest + forward_turns \
				- back_turns * smoothstep(0.0, 1.0, bt2)
		else:
			turns = turns_at_rest + forward_turns - back_turns
		sprite.rotation = turns * TAU * spin_visibility
		sprite.position = target_world \
			+ roll_dir * arc.roll_radius_px * TAU * (turns - turns_at_rest)

	## Only if the prediction is STILL going does the fuse stretch, capped so a
	## pathological one cannot hold the blast forever —
	## `_start_detonation_sequence()` cooks whatever is left anyway.
	_prof("FUSE ends — grenade has settled and cooked")
	var waited: float = 0.0
	while waited < throw_prediction_timeout_s and room._prediction_cache != null \
			and room._prediction_cache.is_busy():
		await tree.process_frame
		waited += room.get_process_delta_time()
	if waited > 0.0:
		_prof("FUSE STRETCHED — held %.0f ms more waiting on the prediction" % (waited * 1000.0))

	## Same hand-off `detonate_active()` makes: the prop stops existing at the
	## exact frame the blast starts, which is also E-FRAG's cue to throw debris.
	var anchor: Vector2 = _blast_anchor(grenade)
	sprite.visible = false
	grenade["detonated"] = true
	_stop_pumping()
	var tk0: int = Time.get_ticks_usec()
	var job: DetonationPrediction = _take_prediction(bomb_def, target_gu)
	_prof("TAKE — _take_prediction (ctx rebuild + cache lookup) %.2f ms" % [
		float(Time.get_ticks_usec() - tk0) / 1000.0])
	_start_detonation_sequence(job, target_gu, anchor)


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
## Gap, flagged not silently dropped: VFX-01's per-voxel debris
## (room._dispatch_destruction_vfx(), driven by the voxel_destroyed signal)
## does not fire for blast-caused destruction — the choreographer's destroy wave
## calls layer.erase_cell() directly rather than going through
## VoxelRenderer.process_dirty(), so the signal never reaches the room.
## Firearms are unaffected (still the signal-driven path).
##
## PARTIALLY CLOSED 2026-08-13 (E-EMBER-01 / E-SMOKE-TINT-01, Director: "reativar
## as brasas e a fumaça na madeira"). Two of the three halves are back, and NOT
## by reconnecting that dispatch — doing so would double every puff against the
## staged smoke waves. Instead the plan carries what each effect needs and the
## choreographer plays it in the front:
##   · the per-voxel EMBER glow on combustible material (VL-D4, dead since the
##     2026-08-05 `[RESET]`) — a real `ember` wave, gated on the material
##     table's new `flammability` column;
##   · the per-material SMOKE TINT — `material` on each smoke entry, colours
##     from room.blast_smoke_tints().
## STILL DISCONNECTED, deliberately, and the Director has not asked for it: the
## DUST / SPARK / CHIP debris of that same dispatch. It is not blocked by
## anything any more (destroy entries could take a material the same way smoke
## did) — it is simply out of the scope that was requested.
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
	_pump_prediction(room._prediction_cache.request(
		PredictionCache.blast_signature(BOMB_ID, gu, room._active_perspective),
		room._world_revision, bomb_def, gu, ctx))


## Advances the cache's in-flight prediction one budget per frame until it
## finishes or something cancels it.
##
## A coroutine rather than a `_process()` because this controller is not a Node —
## the same reason `_start_detonation_sequence()` is one. Self-terminating (the
## cache stops being busy) and interruptible (`_stop_pumping()`), so there is no
## timer to leak and no second one can start while one is running.
func _pump_prediction(job: DetonationPrediction = null) -> void:
	if _pumping:
		return
	_pumping = true
	var pumped: int = 0
	var pump_work_us: int = 0
	while _pumping and room._prediction_cache.is_busy():
		var t0: int = Time.get_ticks_usec()
		room._prediction_cache.pump(predict_budget_ms)
		pump_work_us += Time.get_ticks_usec() - t0
		pumped += 1
		await room.get_tree().process_frame
	## `_pumping` is still true here when the loop ended because the CACHE went
	## idle — that is the prediction finishing on its own. False means someone
	## called `_stop_pumping()` and the work was abandoned part-built.
	var finished: bool = _pumping
	_prof("PUMP ends — %d frame(s) pumped, %.1f ms of real work at a %.1f ms budget (%s)" % [
		pumped, float(pump_work_us) / 1000.0, predict_budget_ms,
		"prediction finished" if finished else "interrupted"])
	if finished and job != null:
		await _warm_prediction(job)
	_pumping = false


## P-WARM (Director, 2026-08-12): *"antes de mexer com o tempo e os frames, a
## gente precisa garantir que a pré-produção da destruição está funcionando e
## carrega todos os dados necessários (...) Assim a gente garante que estamos
## vendo os frames 'livres', e não travando por conta de processamento."*
##
## The prediction being DONE was never the same thing as the blast being ready
## to play. Three pieces of work survived into playback, and all three landed on
## the frames the Director was watching:
##
##   · flattening + radially sorting the 1 590-step queue   8.5 ms, once
##   · minting the TileSet alternatives each cell needs     ~105 ms PER FRAME
##   · uploading the composited damage page to the GPU      ~133 ms, once
##
## The middle one is the whole story and it is not obvious: `_ensure_light_alt()`
## calls `create_alternative_tile()`, which mutates the TileSet that EVERY
## TileMapLayer shares, so a single new alternative on a frame forces the lot to
## rebuild. That is why the cost was flat — a frame minting one alternative and a
## frame minting three hundred cost the same, and a frame minting none cost
## nothing. Measured end to end on a real PLAYGROUND throw:
##
##     before   5 wave frames over 753 ms   (~150 ms each)
##     after    5 wave frames over  85 ms   (~17 ms each — a normal frame)
##
## Done HERE and not in the pipeline because two of the three mutate the
## renderer, and `build_plan()` is pure by architecture (PREDICTION_MASTER_PLAN
## §3.3). This is playback preparation that happens to be cheap to do early, not
## part of the prediction — hence a controller step, and hence `warmed` living on
## the job rather than inside the Delta.
##
## DELIBERATELY NOT SLICED, and that is the whole trick rather than an omission.
## The first version budgeted the mint pass across frames the way the pump does,
## and made things WORSE: it took the warm-up from one frame to five, and the
## throw animation stuttered for 490 ms (measured, f=44 to f=49). The cost is not
## the CPU of `_ensure_light_alt()` — that is ~19 ms for the lot — it is the
## TileSet rebuild that any frame minting ANYTHING has to pay, once. Spreading
## the mints spreads that penalty over every frame it touches.
##
## This is the same inversion DetonationChoreographer's own header warns about
## ("a naive 'spread the work thinner' budget makes the blast three to twenty
## times SLOWER"), met a second time from the other side. One frame pays it once.
##
## Where that frame LANDS is what makes it affordable: the prediction finishes
## around +730 ms on a real throw, which is already past the 600 ms flight — so
## the hitch falls while the grenade is sitting on the ground cooking, not while
## it is arcing through the air.
func _warm_prediction(job: DetonationPrediction) -> void:
	if job.delta == null or job.warmed:
		return
	var warm_start_us: int = Time.get_ticks_usec()
	var minted_before: int = room._voxel_renderer.minted_light_alt_count()

	## 1. The playback queue. Pure, so it could live anywhere; it lives here
	##    because this is the only place with a frame to spare.
	job.playback_queue = DetonationChoreographerClass.flatten_plan(job.delta.waves)

	## 2. Every tile alternative the plan will place. Walks the PLAN rather than
	##    the queue, so soot — which E-FUME took out of WAVE_TABLE and applies as
	##    its own late step — is covered too.
	for triple: Array in _plan_light_alt_triples(job.delta.waves):
		room._voxel_renderer._ensure_light_alt(triple[0], triple[1], triple[2])

	## 3. Push the composited damage pages the PACKAGE phase blitted. Whole
	##    2048x2048 pages, so this is a real upload — and it belongs in the same
	##    frame as the mints, so the sequence pays one penalty and not two.
	var pages: int = room._voxel_renderer.flush_damage_composite_pages()

	job.warmed = true
	_prof("WARM done — %d step(s) queued, %d alt(s) minted, %d page(s) uploaded, %.1f ms cpu" % [
		job.playback_queue.size(),
		room._voxel_renderer.minted_light_alt_count() - minted_before, pages,
		float(Time.get_ticks_usec() - warm_start_us) / 1000.0])
	_prof("WARM carries — %s" % _plan_inventory(job.delta.waves))
	var dropped: int = _entries_playback_will_drop(job.delta.waves)
	if dropped > 0:
		push_warning("[P-WARM] %d plan entr(ies) are in a kind DetonationChoreographer never plays — computed, warmed, and dropped. See _entries_playback_will_drop()." % dropped)
	## The frame this returns on is the one that pays the rebuild; waiting for it
	## here keeps the caller's own timing line honest about where it landed.
	await room.get_tree().process_frame


## What a finished plan actually holds, per kind — the Director's own acceptance
## question for pre-production: *"carrega todos os dados necessários desde os
## voxels destruídos até o disparo da fumaça e a fuligem"*. A zero here is the
## honest way to find a stage that silently produces nothing, which is exactly
## how the floor-dent path stayed inert for a session (CLAUDE.md's own example).
func _plan_inventory(plan: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	## `ember` added 2026-08-13 with E-EMBER-01. This readout exists so a zero
	## exposes a stage that silently produces nothing — a new kind missing from
	## the list is the same failure one level up, in the instrument itself.
	for kind: String in ["destroy", "expose", "dented", "cracked", "soot", "smoke", "ember", "debris"]:
		var count: int = 0
		for ring: int in plan.get(kind, {}).keys():
			count += plan[kind][ring].size()
		if kind == "expose":
			count = 0
			for ring2: int in plan.get("destroy", {}).keys():
				for entry in plan["destroy"][ring2]:
					count += entry.get("expose", []).size()
		parts.append("%s=%d" % [kind, count])
	return " ".join(parts)


## Plan entries in a kind `DetonationChoreographer` never draws — computed by the
## pipeline, pre-minted by this warm-up, then never read.
##
## THIS COUNTER EARNED ITS KEEP ON THE DAY IT SHIPPED. It found 18 ring-2 dents
## dropped on every PLAYGROUND blast, because the choreographer's `WAVE_TABLE`
## re-gated by ring what `frag_grenade.json`'s own `dent_ring_weights` had
## already decided, and the two had drifted. E-ORGANIC-02 removed that second
## gate (Director: "vamos liberar eles para serem orgânicos, e não limitados
## pelos rings"), so rings can no longer be the cause — but the KIND axis still
## can, and a new plan key nobody wired into playback would be exactly as silent.
##
## `soot` is deliberately exempt: E-FUME took it out of the played kinds on
## purpose and `_run_queue()` applies it as its own late step after the front.
func _entries_playback_will_drop(plan: Dictionary) -> int:
	var dropped: int = 0
	for kind: String in plan.keys():
		if kind == "soot" or DetonationChoreographerClass.PLAYED_KINDS.has(kind):
			continue
		for ring: int in plan[kind].keys():
			dropped += plan[kind][ring].size()
	return dropped


## Every (source_id, atlas_coords, alt) a plan will hand to `set_cell()`.
## `destroy` carries its reveals nested, and only ever erases on its own account;
## `smoke` never touches a tile at all.
func _plan_light_alt_triples(plan: Dictionary) -> Array:
	var triples: Array = []
	for kind: String in ["dented", "cracked", "soot"]:
		for ring: int in plan.get(kind, {}).keys():
			for entry in plan[kind][ring]:
				triples.append([entry["source_id"], entry["atlas_coords"], entry["alt"]])
	for ring2: int in plan.get("destroy", {}).keys():
		for entry2 in plan["destroy"][ring2]:
			for exposed in entry2.get("expose", []):
				triples.append([exposed["source_id"], exposed["atlas_coords"], exposed["alt"]])
	return triples


func _stop_pumping() -> void:
	_pumping = false


## One line of the throw timeline. See THROW_PROFILE_ENV.
func _prof(label: String) -> void:
	if OS.get_environment(THROW_PROFILE_ENV) != "1":
		return
	print("[T-PROF] +%6d ms  f=%3d  %s" % [
		Time.get_ticks_msec() - _prof_t0_ms,
		int(Engine.get_process_frames()) - _prof_f0, label])


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
	_prof("BEAT 1 — fire lit")
	room.spawn_blast_burst(anchor)
	if room._camera_controller != null:
		room._camera_controller.shake(SHAKE_SECONDS, SHAKE_AMPLITUDE_PX)

	## Beat 0 — COOKING. Usually zero iterations, because pre-production started
	## when the menu opened. `cook_budget_ms` is the bigger of the two budgets:
	## with the grenade already burning there is no cursor to keep smooth, and a
	## bigger bite ends the wait sooner.
	var cook_frames: int = 0
	var cook_work_us: int = 0
	while not job.is_done() and not job.is_cancelled():
		var ct0: int = Time.get_ticks_usec()
		job.step(cook_budget_ms)
		cook_work_us += Time.get_ticks_usec() - ct0
		await room.get_tree().process_frame
		cook_frames += 1
	_prof("BEAT 0 — cooking done: %d frame(s), %.1f ms of leftover work at a %.1f ms budget" % [
		cook_frames, float(cook_work_us) / 1000.0, cook_budget_ms])
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
	var commit_t0: int = Time.get_ticks_usec()
	job.delta.commit()
	_prof("COMMIT — %.1f ms, %d voxel(s) written" % [
		float(Time.get_ticks_usec() - commit_t0) / 1000.0, job.delta.touched_voxels.size()])
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
	## M3-3: hand the burn schedule to the room. AFTER the commit, because the
	## scheduler drops any voxel this blast already destroyed and it can only
	## know that once the Delta has been written.
	room.start_burn(job.delta.waves.get("burn", {}))
	_prof("CENSUS — print_census done")
	room._gu_blast_count[gu] = int(room._gu_blast_count.get(gu, 0)) + 1
	var rec0: int = Time.get_ticks_usec()
	## VL-PERSIST: record every voxel this blast actually changed so rotation
	## replays it — the exact set the Delta already carries, no second flood/
	## find_affected_containers pass needed. Reads the real Voxel fields, so it
	## has to follow the commit.
	for voxel in job.delta.touched_voxels:
		room.record_voxel_damage_to_base(voxel.grid_pos, voxel.level, voxel.damage_state,
			voxel.damage_is_blast, voxel.damage_carved_side, voxel.damage_variant,
			voxel.damage_substrate)
	_prof("PERSIST — record_voxel_damage_to_base x%d took %.2f ms" % [
		job.delta.touched_voxels.size(), float(Time.get_ticks_usec() - rec0) / 1000.0])

	## ⚠️ THE BLAST OWNS ITS OWN RENDERING, SO IT MUST DROP ITS OWN FLAGS.
	##
	## `set_damage()` marks every written voxel dirty, and `dirty` means exactly
	## one thing: SOMEBODY STILL HAS TO RENDER THIS. For a blast nobody does —
	## `DetonationChoreographer` writes `erase_cell()`/`set_cell()` straight to
	## the TileMapLayers from its pre-built plan and never touches the dirty
	## pipeline (its own `_apply_entry()` header says so). So the flags stayed
	## set forever, and the next unfiltered `process_dirty_async()` — which only
	## the FIREARM path ever calls — walked the whole backlog and re-emitted
	## `voxel_destroyed` for every destroyed voxel in it.
	##
	## Measured before the fix (`INFILTRAITOR_CAPTURE_ACTION=grenade_then_shot`):
	##     grenade 0: 0 dispatches · grenade 1: 0 · THE SHOT: 498
	## against 5 voxels the shot actually destroyed. That is the Director's
	## report exactly — *"todos os voxels afetados pelas explosões soltam fumaça
	## novamente"*.
	##
	## Cleared HERE, at the commit, rather than after the choreographer finishes:
	## the moment the plan exists the choreographer owns these pixels, and a shot
	## fired DURING the playback would otherwise hit the same backlog in a
	## smaller window. `touched_voxels` is the exact written set, so this is not a
	## blanket clear — a flag set by anything else survives it.
	for voxel in job.delta.touched_voxels:
		voxel.clear_dirty()
	var waves: Dictionary = job.delta.waves
	## §5.2: the world just moved, so every cached prediction — including this
	## one — is now stale. AFTER the commit, never before.
	room.bump_world_revision()

	## The rest of beat 1: however much fire-only lead is still owed. Cooking
	## already spent frames here, so a long fuse does not additionally delay the
	## strobe — `burst_lead_frames` is a MINIMUM, not an extra.
	for _i in range(maxi(burst_lead_frames - cook_frames, 0)):
		await room.get_tree().process_frame
	_prof("BEAT 1 ends — fire-only lead served (%d of %d frame(s) owed)" % [
		maxi(burst_lead_frames - cook_frames, 0), burst_lead_frames])

	## Beat 2 — E-FRAG-02 (Director, 2026-08-26): *"Tem que ser um estouro de
	## metais voando com o clarão junto mesmo."*
	##
	## ⚠️ THE ORDER WAS INVERTED, and that is what the note was about. The metal
	## used to spawn AFTER all seven flash frames had already played out, so the
	## flash was over before a single fragment existed and the two beats read as
	## two separate events. The shrapnel now leaves FIRST, on the same frame the
	## flash begins, and the negative peak lands one frame later — *"o frame
	## negativo já tem que acontecer logo em seguida"* — instead of three frames
	## of ramp later.
	var frag0: int = Time.get_ticks_usec()
	if room._shrapnel_overlay != null:
		room._shrapnel_overlay.spawn_shrapnel(anchor, waves, room._voxel_renderer)
	_prof("FRAG — spawn_shrapnel %.2f ms (BEFORE the flash now)" % [
		float(Time.get_ticks_usec() - frag0) / 1000.0])

	var flash_overlay = room._explosion_flash_overlay
	if flash_overlay != null:
		## ONE approach frame instead of three: the metal is already in flight, so
		## a long ramp only delays the bang it is supposed to be part of.
		flash_overlay.strobe_negative_amount = 0.5
		flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
		await room.get_tree().process_frame
		## Peak, on frame 2.
		flash_overlay.strobe_negative_amount = 1.0
		flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
		await room.get_tree().process_frame
		## The fade is UNCHANGED at three frames — it is what keeps the strobe
		## from reading as a single dropped frame, and nothing asked for it to
		## move.
		for i in range(3):
			flash_overlay.strobe_negative_amount = 1.0 - float(i + 1) / 3.0
			flash_overlay.hold_frame(ExplosionFlashOverlay.FlashMode.NEGATIVE)
			await room.get_tree().process_frame
		flash_overlay.clear()
	_prof("BEAT 2 ends — metal away, then 5 flash frames (was 7 flash frames, then metal)")
	_prof("BEAT 3 — destruction starts%s" % ["" if job.warmed else " (NOT warmed — paying at playback)"])

	## Beat 3 — destruction, clean.
	_start_waves(waves, job.playback_queue)


func _start_waves(waves: Dictionary, playback_queue: Array = []) -> void:
	var choreographer := DetonationChoreographerClass.new()
	_active_choreographer = choreographer
	choreographer.finished.connect(func():
		_prof("WAVES end — the blast is over")
		_active_choreographer = null)
	## E-EMBER-01 / E-SMOKE-TINT-01: the two VFX targets that are not on
	## `start()`'s signature — the ember overlay VL-D4's per-voxel glow needs, and
	## the per-material smoke tints only a MaterialRegistry owner can resolve.
	choreographer.set_vfx_targets(room._ember_overlay, room.blast_smoke_tints(),
		room._debris_overlay, room.blast_debris_palette())
	choreographer.start(waves, room._voxel_renderer, room._smoke_spark_overlay,
		room.get_tree(), playback_queue)


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
		## E-JUNCTION-01: wall-junction corner columns, so a grenade's
		## omnidirectional flood can reach them the way it already reaches
		## every Slice/Slab. find_affected_containers() defaults this to []
		## when absent, so any other build_plan() caller is unaffected.
		"junction_columns": room._junction_columns,
		"blocked_edges": _blocked_edges_dict(),
		"blocked_cells": room._blocked_cells,
		"lights": lights,
		"shadow_results": shadow_results,
		"under_structure": room._under_structure,
		## Passed rather than left to `build_plan()`'s own defaults, which is a
		## fix and not a tidy-up: the builder read `ctx.get("blast_soot_rings", 4)`
		## while `room` carried its own `blast_soot_rings`, and nothing connected
		## them — a detonation and a repaint of the same crater could disagree
		## about soot's reach with no error anywhere. Same drift as §1.2 of
		## SOOT_MASTER_PLAN, in a spot that plan had not found.
		"blast_soot_rings": room.blast_soot_rings + room.blast_soot_feather_rings,
		## E-DEBRIS-01: which materials throw dust/sparks/chips, and how often.
		## Room policy as plain data — see Room.blast_debris_policy(). Absent
		## means no debris, which is what every non-explosion caller wants.
		"debris": room.blast_debris_policy(),
		"weapon_soot_rings": room.weapon_soot_rings,
		## D2: unlocked from this GU's SECOND blast onward.
		"deep_layer_unlocked": int(room._gu_blast_count.get(source_gu, 0)) > 0,
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
