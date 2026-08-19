## AgentShotController — WEAPON_MASTER_PLAN §6c: THE AGENT SHOOTS.
##
## The Director's own scoping of the wave (2026-08-16): *"O que a gente quer
## testar agora é só a mecânica de mirar da GU A para a GU B e o tiro acertar a
## parede C atrás. Pra isso só precisamos de um inimigo em qualquer posição, e ao
## clicar nele + 'disparar', como fizemos com a granada, o agente atira, e por
## falta de outra opção, erra sempre o alvo (por enquanto)."*
##
## THIS IS D25 LITERALLY — a shot always targets an ACTOR, picked through the
## same contextual menu the grenade already uses. It is NOT §5c's aim mode: D31's
## weapon slots and `S` key and D32's Tab-cycled target list with a visible hit
## percentage are combat-phase surface, explicitly out of this wave. D32 later
## replaces this menu AS A UI while leaving D25's principle untouched, so nothing
## here is written to survive it — the parts worth keeping are the roll
## (ShotHitRoll), the origin (Agent.muzzle_origin()) and the off-axis aim
## (BlastCalculator's aim_offset_deg), all of which live outside this file.
##
## WHAT IT REUSES RATHER THAN REBUILDS, which is most of it: §6c's own audit
## found that everything downstream of a miss shipped in July. The pellet
## selection, the impact resolution, D30's punch ladder, the bullet marks, the
## face-local soot and the whole decal pipeline are called here exactly as
## WeaponBenchController calls them. What is genuinely new is that a shot now
## leaves an ACTOR AT A POSITION and that something is drawn between the muzzle
## and the wall.
##
## WHY IT IS A SECOND CONTROLLER AND NOT A BRANCH INSIDE WeaponBenchController:
## that one owns static props placed on a bench — it holds `_weapons` rows with
## their own GU cells, facings and shot counters, and PLAYGROUND retired every
## one of them on 2026-08-17. Threading an actor through its prop model would
## have meant a fake prop standing in for the agent, which is the substitution
## this project's evidence rules ban. The bench file stays as it is, unused by
## PLAYGROUND but intact for its calibration history (§6b).
class_name AgentShotController

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")

## B2, and DECLARED rather than quietly picked, because §6c asks for exactly
## that: this wave fires whatever the figure is holding, which is the shotgun in
## D40's grip. It sidesteps the live collision between D31's three weapon slots
## and DESIGN_MASTER_PLAN §10.2's one-weapon-per-mission rule (§7c Q1) instead of
## silently resolving it — that is a balance decision and it is not this wave's.
const WEAPON_ID: String = "shotgun"

## The four grid-axis GU steps, in the compass vocabulary DIRECTION_GLOSSARY
## fixes. Same table WeaponBenchController carries; kept local rather than
## imported because the two controllers must be free to diverge (that one reads
## a prop's authored facing, this one derives an aim from two actor positions).
const FACING_DELTA: Array[Vector2i] = [
	Vector2i(-1, 0),   ## NW
	Vector2i(0, -1),   ## NE
	Vector2i(1, 0),    ## SE
	Vector2i(0, 1),    ## SW
]

const MENU_GAP_ABOVE_PX: float = 30.0

## D26: no hard range cap — a miss keeps travelling. Same generous constant
## WeaponBenchController uses, and for the same reason: it is a walk limit, not
## a weapon range.
const PELLET_FLOOD_MAX_STEPS: int = 40

## Where the muzzle flash and the tracers originate vertically, in the voxel
## level the shot is treated as leaving from. Matches the bench's chest-height
## convention (D18: shots are chest-height and horizontal).
const MUZZLE_LEVEL: int = 4

## How far above a guard's own origin the menu anchors, in pixels. Deliberately
## NOT DebugAgent.SILHOUETTE_HEIGHT: that constant measures the BAKED figure, and
## agent.gd's own header records that the guards are still vector diamonds
## (Part 7). Borrowing the agent's 222 px would float the menu well above a
## diamond that is nothing like that tall. Re-derive this from the guard's own
## bake the day the guards stop being diamonds.
const GUARD_TOP_PX: float = 72.0

## B4, as the Director ratified it (2026-08-19): the agent gets a real firing
## pose. `_aimed` is the directory suffix p3_posture_export.py's GRIP_SUFFIX
## writes for P3_GRIP=aimed, and the grip spike found `aimed` the one of D40's
## three that reads unmistakably as aiming.
const GRIP_AIMED: String = "_aimed"
const GRIP_LOWERED: String = ""

var room = null
var _active_guard_index: int = -1


func _init(room_ref) -> void:
	room = room_ref


## Index into room._guards of the guard standing on the clicked GU cell, or -1.
##
## The hitbox is the FLOOR CELL, not the sprite — the same rule the Director set
## for grenades on 2026-07-30. It matters more here than there: the baked figure
## is 104x222 px and overhangs its own cell by a long way, so a sprite-rect
## hitbox would swallow clicks meant for the tiles behind him.
func hit_test(screen_pos: Vector2) -> int:
	var cell: Vector2i = room._screen_to_tile(screen_pos)
	if cell == room.INVALID_CELL:
		return -1
	var guards: Array = room._guards
	for i in range(guards.size()):
		var g = guards[i]
		if g == null or not is_instance_valid(g):
			continue
		if g.cell == cell:
			return i
	return -1


## B1, as the Director ratified it: the action lives on the ENEMY's menu. The
## grenade's menu opens on the thrown object; a shot has a shooter and a target,
## and opening on the target is what scales when there are several enemies —
## each one carries its own action instead of one menu having to ask which.
func open_menu_for(index: int) -> void:
	var guards: Array = room._guards
	if index < 0 or index >= guards.size():
		return
	var guard = guards[index]
	if guard == null or not is_instance_valid(guard):
		return
	_active_guard_index = index
	## The weapon comes up when the target is picked, not when the trigger is
	## pulled — the menu being open IS the moment the player has committed to a
	## target, the same moment the grenade path uses to start pre-production.
	## It also means the raised weapon is on screen while the menu is, which is
	## what makes the pose visible at all: the shot itself resolves in one frame.
	if room.agent != null and is_instance_valid(room.agent):
		## He TURNS TOWARD THE TARGET before raising the weapon. Not listed in
		## §6c's parts, and included because the first capture made the omission
		## obvious: a figure firing over his own shoulder reads as a bug in the
		## shot, not as a missing nicety. `face_direction()` already owns the
		## reduction from an arbitrary delta to one of D44's four facings (a
		## diagonal has no frame and never will), so this passes the raw GU delta
		## and lets the sprite apply the rule in the one place it lives.
		if room.agent.sprite != null:
			room.agent.sprite.face_direction(guard.cell - room.agent.cell)
		room.agent.set_grip(GRIP_AIMED)
	room._context_menu.open_at(_top_screen_pos(guard), MENU_GAP_ABOVE_PX,
		"ui.context_menu.fire", fire_at_active)


## Idempotent, and lowers the weapon. Reached from three directions — the menu's
## own Cancelar, room.gd's outside-click/Escape path, and the end of a shot — so
## the weapon coming back down cannot be forgotten on any one of them.
func cancel_active() -> void:
	_active_guard_index = -1
	if room != null and is_instance_valid(room) and room.agent != null \
			and is_instance_valid(room.agent):
		room.agent.set_grip(GRIP_LOWERED)


## The trigger. Mirrors WeaponBenchController.fire_active()'s resolution stage
## deliberately and almost line for line — that path is selftested and has been
## shipping since July, and a second, subtly different copy of the damage
## pipeline is exactly how two behaviours drift apart.
func fire_at_active() -> void:
	var guards: Array = room._guards
	if _active_guard_index < 0 or _active_guard_index >= guards.size():
		return
	var guard = guards[_active_guard_index]
	if guard == null or not is_instance_valid(guard):
		cancel_active()
		return
	var agent = room.agent
	if agent == null or not is_instance_valid(agent):
		push_error("[AgentShotController] no agent to fire from — §6c Part A requires a shooter, not a prop.")
		cancel_active()
		return
	## W-GUARD-01: loud, never silent. See WeaponBenchController's own note — a
	## silent guard on a self-clearing latch is indistinguishable from a broken
	## trigger.
	if room._destruction_render_busy:
		push_warning("[AgentShotController] shot ignored — a destruction render pass is still running.")
		return
	var weapon_def = Registries.get_weapon_registry().get_weapon(WEAPON_ID)
	if weapon_def == null:
		push_error("[AgentShotController] no WeaponDef for id '%s'" % WEAPON_ID)
		cancel_active()
		return
	if weapon_def.delivery != WeaponDef.DELIVERY_CONE \
			and weapon_def.delivery != WeaponDef.DELIVERY_LINE:
		push_error("[AgentShotController] '%s' declares delivery %s — only CONE and LINE are implemented (WEAPON_MASTER_PLAN Part 2 / Part 3b)." %
			[WEAPON_ID, weapon_def.delivery])
		cancel_active()
		return
	if room._edge_registry == null or room._slab_registry == null:
		cancel_active()
		return

	var origin_gu: Vector2i = agent.cell
	var target_gu: Vector2i = guard.cell
	if origin_gu == target_gu:
		push_warning("[AgentShotController] shooter and target share a GU — no aim direction exists.")
		cancel_active()
		return

	var salt: String = "AGENTSHOT_%s_%s_%d" % [origin_gu, target_gu, room._world_revision]

	## ── PART C: THE ROLL IS REAL, AND ITS OUTCOME IS FORCED ────────────────
	## §6c is explicit that the scaffold must not bypass D12. It does not: the
	## roll runs, ShotHitRoll.FORCE_OUTCOME pins it to MISS, and the hit branch
	## below refuses loudly rather than quietly falling through to the miss path.
	## That refusal is the point — the day a hit path exists it lands in one
	## place, and until then nothing can reach it by accident.
	var distance_gu: float = Vector2(target_gu - origin_gu).length()
	var outcome: int = ShotHitRoll.roll(ShotPunchTable.SKILL_NEUTRAL, distance_gu, salt)
	if outcome == ShotHitRoll.Outcome.HIT:
		push_error("[AgentShotController] the to-hit roll returned HIT, and there is no hit path yet (§6c is the always-miss wave). Set ShotHitRoll.FORCE_OUTCOME back to Outcome.MISS, or build actor damage first.")
		cancel_active()
		return

	## ── PART A: THE AIM LEAVES AN ACTOR, AND IT IS OFF-AXIS ────────────────
	## The two actors are almost never on a shared grid axis, so the aim is
	## decomposed into the nearest axis plus the residual angle the cone is then
	## biased by. Derived from the GU delta, never from screen pixels: a
	## perspective flip rotates the board and an empirical screen angle would
	## silently aim somewhere else afterwards.
	var aim: Vector2 = Vector2(target_gu - origin_gu)
	var forward: Vector2i = _nearest_axis(aim)
	var lateral := Vector2i(-forward.y, forward.x)
	var aim_offset_deg: float = rad_to_deg(atan2(
		aim.dot(Vector2(lateral)), aim.dot(Vector2(forward))))

	## E-MUZZLE-01: the flash fires at the shot, before any damage resolves —
	## the barrel does not wait to find out what it hit. The origin is the
	## AGENT's own muzzle anchor (Part A), not a prop cell centre.
	var muzzle_world: Vector2 = agent.muzzle_origin()
	var aim_world: Vector2 = _gu_centre_world(target_gu) - muzzle_world
	if aim_world != Vector2.ZERO:
		room.spawn_muzzle_flash(muzzle_world, aim_world.normalized())

	var pellet_picks: Array = []
	if weapon_def.delivery == WeaponDef.DELIVERY_LINE:
		var line_hit := BlastCalculatorClass.select_line_impact(
			origin_gu, forward, PELLET_FLOOD_MAX_STEPS,
			_blocked_edges_dict(), room._blocked_cells, aim_offset_deg)
		if not line_hit.is_empty():
			pellet_picks.append(line_hit)
	else:
		pellet_picks = BlastCalculatorClass.select_cone_pellet_impacts(
			origin_gu, forward, weapon_def.cone_half_angle_deg,
			PELLET_FLOOD_MAX_STEPS, weapon_def.projectile_count,
			_blocked_edges_dict(), room._blocked_cells, salt, aim_offset_deg)

	var cell_to_voxel: Dictionary = {}
	var _impact_vfx_done: Dictionary = {}
	var pellets_landed: int = 0
	var punch_log: Array = []
	var is_line: bool = weapon_def.delivery == WeaponDef.DELIVERY_LINE
	for i in range(pellet_picks.size()):
		var resolved := BlastCalculatorClass.resolve_pellet_voxel(
			pellet_picks[i], room._edge_registry, "%s:%d" % [salt, i])
		if resolved.is_empty():
			continue
		pellets_landed += 1
		var slice: Slice = resolved["slice"]
		## D30: one coefficient decides tier, neighbour count and cascade, and
		## each projectile rolls its OWN luck — D36's independent pellets.
		## Distance stays neutral for both shapes, as on the bench: D29's
		## falloff is explicitly deferred and switching it on here would be a
		## behaviour change nobody asked for in this wave.
		var punch: float = ShotPunchTable.compute(
			weapon_def.punch, slice.material, ShotPunchTable.SKILL_NEUTRAL,
			1.0, "%s:%d" % [salt, i])
		punch_log.append(snappedf(punch, 0.01))
		## D32.4: the SHOOTER's GU decides which face the mark lands on — without
		## it apply_point_impact() leaves carved_side NONE and the bullet hole
		## renders on the voxel's top diamond.
		var touched := BlastCalculatorClass.apply_point_impact(
			slice, resolved["voxel_index"], punch,
			room._edge_registry, "%s:%d" % [salt, i],
			weapon_def.step_multipliers if is_line else [],
			origin_gu)
		## ── PART D: the decorative projectile, one per pellet ───────────────
		## D14's per-projectile independence falls out for free because the
		## drawing is per-projectile: a shotgun draws N streaks because it
		## resolved N pellets, not because anything here counts them.
		_draw_tracer(muzzle_world, pellet_picks[i])
		for v in touched:
			_index_voxel(cell_to_voxel, v)
			if v.damage_state != Voxel.DamageState.DESTROYED:
				var vkey := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
				if not _impact_vfx_done.has(vkey):
					_impact_vfx_done[vkey] = true
					room.dispatch_impact_vfx(v.grid_pos, v.level, slice.material)

	## B3: a round with no wall behind the target is VOID and nothing happens
	## (D15). That is a legitimate outcome, not a failure, so it is reported
	## rather than warned about — the capture for this wave is required to
	## include one, or the wave only proves the lucky case.
	## The impact GUs are PRINTED, not just counted. A bare "landed=24/24" says a
	## number of pellets met a wall and nothing about WHICH wall — and "the wall
	## C behind the target" is the entire geometric claim this wave exists to
	## test. It is also what an unattended capture needs in order to frame the
	## damage instead of the shooter.
	var impact_gus: Dictionary = {}
	for pick in pellet_picks:
		impact_gus[pick["gu"]] = true
	## The TIER TALLY, not just the voxel count. "24 pellets landed" and "the wall
	## changed" are different claims, and only the second one is the wave's: a
	## punch below ShotPunchTable.PUNCH_DENT_MIN still counts as landed while
	## leaving a mark too faint to see on a busy stone facade. Counting the
	## resulting states is what tells a capture-that-shows-nothing apart from a
	## shot-that-did-nothing.
	var tiers: Dictionary = {}
	for key in cell_to_voxel:
		var tv: Voxel = cell_to_voxel[key]
		tiers[tv.damage_state] = int(tiers.get(tv.damage_state, 0)) + 1
	print_debug("[AGENT-SHOT] from=%s at=%s outcome=MISS(forced) axis=%s offset=%.1f deg landed=%d/%d impacts=%s voxels=%d tiers=%s punch=%s" %
		[origin_gu, target_gu, forward, aim_offset_deg,
		pellets_landed, pellet_picks.size(), impact_gus.keys(),
		cell_to_voxel.size(), tiers, punch_log])

	## PREDICTION_MASTER_PLAN §5.2 — a shot is a committed mutation, so every
	## cached blast prediction is now stale.
	room.bump_world_revision()

	## VL-PERSIST: record into base coords so the damage survives a perspective
	## flip, which rebuilds every Voxel from the MapSpec.
	for key in cell_to_voxel:
		var av: Voxel = cell_to_voxel[key]
		room.record_voxel_damage_to_base(av.grid_pos, av.level, av.damage_state,
			av.damage_is_blast, av.damage_carved_side, av.damage_variant, av.damage_substrate)

	cancel_active()
	if cell_to_voxel.is_empty():
		return

	## PERF-01: spread across frames instead of one synchronous batch, and
	## W-GUARD-01: every `await` below is a place the ROOM can go away (a map
	## load frees it and builds a new VoxelRenderer), so each resume revalidates
	## and abandons loudly rather than reaching through a freed reference. Both
	## rules are WeaponBenchController's, copied because they are properties of
	## this pipeline rather than of that caller.
	room._destruction_render_busy = true
	await room._voxel_renderer.process_dirty_async(room._edge_registry)
	if not is_instance_valid(room) or not is_instance_valid(room._voxel_renderer):
		push_warning("[AgentShotController] room went away mid-shot (map reload?) — render pass abandoned")
		return
	await room._voxel_renderer.process_dirty_slabs_async(room._slab_registry)
	if not is_instance_valid(room) or not is_instance_valid(room._voxel_renderer):
		push_warning("[AgentShotController] room went away mid-shot (map reload?) — render pass abandoned")
		return
	## PERF-03: a shot changes geometry and soot only, never a light or a shadow
	## result — same contract the bench and the grenade repaint under.
	if room.has_method("_repaint_voxel_light_buckets"):
		room._repaint_voxel_light_buckets(true)
	room._destruction_render_busy = false


## The grid-axis step whose direction best matches `aim`. Four candidates and a
## dot product, rather than an angle bucket: the axes are 90 deg apart, so the
## largest projection IS the nearest one, with no wraparound case to get wrong.
func _nearest_axis(aim: Vector2) -> Vector2i:
	var best: Vector2i = FACING_DELTA[0]
	var best_dot: float = -INF
	for d in FACING_DELTA:
		var dot: float = aim.normalized().dot(Vector2(d))
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


## One tracer, from the muzzle to the GU the pellet actually stopped in. The
## endpoint is the pick's own resolved GU, so the streak can never point
## somewhere the shot did not go — including after a perspective rotation, since
## the GU→world conversion is what supplies the point.
func _draw_tracer(muzzle_world: Vector2, pick: Dictionary) -> void:
	if room._tracer_overlay == null:
		return
	var impact_world: Vector2 = _gu_centre_world(pick["gu"])
	if impact_world == Vector2.ZERO:
		return
	room._tracer_overlay.add_tracer(muzzle_world, impact_world)


## Screen position above the guard, for the menu anchor. Uses the guard's own GU
## cell centre rather than its sprite rect: the sprite overhangs its cell and
## anchoring to it would drift the menu by posture.
func _top_screen_pos(guard) -> Vector2:
	var world: Vector2 = guard.position + Vector2(0.0, -GUARD_TOP_PX)
	return room.get_viewport().get_canvas_transform() * world


func _index_voxel(cell_to_voxel: Dictionary, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v


## Same conversion TestZoneController and WeaponBenchController do — room's
## {"from","to"} pairs folded into the keyed shape WallEdgeData queries.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked


## World position of a GU cell's centre at chest height — the same
## GU→voxel→world chain the bench's muzzle flash uses.
func _gu_centre_world(gu: Vector2i) -> Vector2:
	if room._voxel_renderer == null:
		return Vector2.ZERO
	var half: int = int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0)
	var centre: Vector2i = GeometryCoords.gu_to_voxel_origin(gu) + Vector2i(half, half)
	return room._voxel_renderer.voxel_world_position(centre, MUZZLE_LEVEL)
