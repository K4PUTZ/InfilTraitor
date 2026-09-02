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

## W-WEAPON-01 (Director, 2026-08-20): *"Vamos trocar a arma empunhada, conforme
## o número for selecionado."* Weapon id -> the bake-directory suffix
## AgentSprite.weapon takes. The shotgun maps to "" because its posed GLBs are
## the ones that shipped and their directories carry no weapon segment — the
## same "the default earns no suffix" rule p3_posture_export.py applies to grips.
##
## ⚠️ ONLY THE SHOTGUN ROW HAS ART TODAY. The rifle and pistol rows name
## directories that do not exist yet, and set_weapon_bake() warns once and keeps
## the shotgun pose. That is the honest state: the WEAPON changes (ladder,
## pre-cook, ballistics all switch), the FIGURE does not, until the bakes in
## PROMPTS/BAKE_ORDER_WEAPON_GRIPS.md are run.
const WEAPON_BAKE_SUFFIX: Dictionary = {
	"shotgun": "",
	"assault_rifle": "_rifle",
	"pistol": "_pistol",
}

## How many DRAWN FRAMES the rounds get to cross before the wall reacts. A frame
## count, not a duration: see the note in fire_at_active() for why a duration is
## exactly the thing that failed here. 8 frames at 60 Hz is ~0.13 s, which is
## TracerOverlay.HOLD_S — the flight, and nothing more.
## How many DRAWN FRAMES the rounds get before the wall reacts. A frame count,
## not a duration: see fire_at_active()'s note for why a duration is exactly the
## thing that failed here.
##
## `TracerOverlay.HOLD_FRAMES + FADE_FRAMES` must not exceed this — the round has
## to be GONE before the impact frame, or a stall freezes it in mid-air. See that
## file's own note; the two constants are one decision in two places.
const TRACER_FLIGHT_FRAMES: int = 8

var room = null
var _active_guard_index: int = -1


## Voxel.DamageState -> the word the tier print uses. The enum's own ordering is
## INTACT/CRACKED/DESTROYED/DENTED, which reads as a typo when printed raw.
const _TIER_NAME: Dictionary = {
	Voxel.DamageState.CRACKED: "CRACKED",
	Voxel.DamageState.DENTED: "DENTED",
	Voxel.DamageState.DESTROYED: "DESTROYED",
}


## W-TUNE-01 (Director, 2026-08-20): *"vamos trocar a arma pelo fuzil e testar
## novamente, seguido da pistola."*
##
## A DEV SWITCH, not D31's weapon slots. `WEAPON_ID` above is still the declared
## default and the §6c scoping is unchanged — this only lets a capture run fire
## `assault_rifle` or `pistol` without editing the file, which is what comparing
## three weapons on the same four walls requires. It is also, incidentally, the
## exact seam D31 will replace when the player gets to choose.
var _weapon_id: String = WEAPON_ID


func _init(room_ref) -> void:
	room = room_ref
	var env := OS.get_environment("INFILTRAITOR_SHOT_WEAPON")
	if env != "":
		_weapon_id = env
		print("[AGENT-SHOT] weapon overridden to '%s' by INFILTRAITOR_SHOT_WEAPON" % env)


## Switch the firearm. Loud on an unknown id and a no-op on the current one.
##
## RE-KEYS AN OPEN AIM, which is the whole reason this is not a one-line setter:
## the W-PRECOOK warm is keyed on the weapon (its picks, its punch ladder, its
## penetration table), so changing weapons with a target already selected leaves
## a warm predicting the wrong shot entirely. Cancelling and re-running the
## prediction costs the aim window, which is exactly the window it is meant to
## be spent in.
func set_weapon(weapon_id: String) -> void:
	if weapon_id == _weapon_id:
		return
	if Registries.get_weapon_registry().get_weapon(weapon_id) == null:
		push_error("[AgentShotController] no WeaponDef for id '%s' — weapon unchanged" % weapon_id)
		return
	_weapon_id = weapon_id
	print_debug("[AGENT-SHOT] weapon -> %s" % weapon_id)
	## The FIGURE follows the choice, or says why it cannot. Unknown ids fall back
	## to the shotgun suffix rather than to a guess: a weapon nobody has baked and
	## a weapon nobody has named should look the same, which is "the one that
	## exists".
	if room.agent != null and is_instance_valid(room.agent) and room.agent.sprite != null:
		room.agent.sprite.set_weapon_bake(String(WEAPON_BAKE_SUFFIX.get(weapon_id, "")))
	if _active_guard_index < 0:
		return
	var guards: Array = room._guards
	if _active_guard_index >= guards.size():
		return
	var guard = guards[_active_guard_index]
	if guard == null or not is_instance_valid(guard):
		return
	room.cancel_shot_precook()
	_begin_precook(guard)


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
	## ⚠️ THE MENU IS THE FIRST THING THAT HAPPENS, AND THAT IS THE POINT.
	##
	## Director, 2026-08-20: *"o lag está acontecendo no momento do clique com o
	## botão direito no inimigo. Me parece que a gente poderia chamar o menu
	## imediatamente no clique sobre o inimigo, e depois iniciar o cálculo."*
	##
	## Opening it costs 0.3 ms (measured); everything below it used to run first.
	## The weight was `set_grip()` — 146 ms of a 160 ms frame, on the first aim of
	## a session — and W-LOAD-02 moved those frames to the map load, so what is
	## left after this line is ~5 ms. Both halves matter: the ordering makes the
	## menu independent of whatever the rest of this function ever grows into.
	room._context_menu.open_at(_top_screen_pos(guard), MENU_GAP_ABOVE_PX,
		"ui.context_menu.fire", fire_at_active)
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
	## W-PRECOOK: the target is picked, so the warm starts NOW. Everything below
	## is a PREDICTION — nothing is committed and nothing is drawn — so a player
	## who cancels loses only the work, and one who changes target re-keys it.
	_begin_precook(guard)


## Idempotent, and lowers the weapon. Reached from three directions — the menu's
## own Cancelar, room.gd's outside-click/Escape path, and the end of a shot — so
## the weapon coming back down cannot be forgotten on any one of them.
## Predict this shot's destroyed voxels and warm the alternative cache for them.
##
## The prediction runs the SAME functions the shot will — same salt, same picks,
## same punch ladder — so it does not have to be trusted: it is deterministic by
## construction, and where it is wrong it costs a cache miss and nothing else.
## `apply_point_impact()` is never called here, so no voxel is written.
func _begin_precook(guard) -> void:
	var agent = room.agent
	if agent == null or not is_instance_valid(agent) or room._edge_registry == null:
		return
	var weapon_def = Registries.get_weapon_registry().get_weapon(_weapon_id)
	if weapon_def == null:
		return
	var plan := _build_shot_plan(agent.cell, guard.cell, weapon_def)
	if plan.is_empty():
		return
	room.begin_shot_precook(plan["destroyed"], plan["damaged"],
		room.shot_repaint_scope(plan["impact_gus"]), plan["variant_cells"])


## PURE. The shot that WOULD be fired, as data, writing nothing:
##   "destroyed"     Dictionary[Vector3i] — every voxel the ladder would remove
##   "damaged"       Array of plan_point_impact() entries — the DENTED/CRACKED
##                   ones, tuple included, for the predicted self-soot
##   "variant_cells" Array of {"level","cell","source_id","atlas_coords"} — the
##                   atoms those damaged voxels will MOVE to
##   "impact_gus"    Array[Vector2i]
## The two consumers are the precook above and, one day, D32's hit-percentage
## readout.
func _build_shot_plan(origin_gu: Vector2i, target_gu: Vector2i, weapon_def) -> Dictionary:
	if origin_gu == target_gu:
		return {}
	var salt := _salt_for(origin_gu, target_gu)
	var aim: Vector2 = Vector2(target_gu - origin_gu)
	var forward: Vector2i = _nearest_axis(aim)
	var lateral := Vector2i(-forward.y, forward.x)
	var offset: float = rad_to_deg(atan2(aim.dot(Vector2(lateral)),
		aim.dot(Vector2(forward))))
	## THE SAME DELIVERY BRANCH fire_at_active() takes, and it has to be. The plan
	## was cone-only while the shotgun was the only weapon; the moment
	## INFILTRAITOR_SHOT_WEAPON can name a LINE weapon, a cone-only plan predicts a
	## spray of 24 pellets for a shot that fires one round — every warmed
	## alternative wrong, and the impact frame paying for all of them again.
	var is_line: bool = weapon_def.delivery == WeaponDef.DELIVERY_LINE
	var picks: Array = []
	if is_line:
		var line_hit := BlastCalculatorClass.select_line_impact(
			origin_gu, forward, PELLET_FLOOD_MAX_STEPS,
			_blocked_edges_dict(), room._blocked_cells, offset, _glass_edges_dict())
		if not line_hit.is_empty():
			picks.append(line_hit)
	else:
		picks = BlastCalculatorClass.select_cone_pellet_impacts(
			origin_gu, forward, weapon_def.cone_half_angle_deg,
			PELLET_FLOOD_MAX_STEPS, weapon_def.projectile_count,
			_blocked_edges_dict(), room._blocked_cells, salt, offset, _glass_edges_dict())
	## GLASS G7 — a hole in every pane the round crossed on the way in.
	picks = _flatten_glass_passthrough(picks)
	var destroyed: Dictionary = {}
	var damaged: Array = []
	var variant_cells: Array = []
	var gus: Dictionary = {}
	for i in range(picks.size()):
		gus[picks[i]["gu"]] = true
		var resolved := BlastCalculatorClass.resolve_pellet_voxel(
			picks[i], room._edge_registry, "%s:%d" % [salt, i])
		if resolved.is_empty():
			continue
		var slice: Slice = resolved["slice"]
		## G-D17 — the round arrives at this pick already through `glass_depth`
		## layers of glass, and everything downstream uses the weakened projectile:
		## the hole it makes here, the pane roll below, and the mark on whatever
		## wall it finally reaches.
		var layer_depth: int = int(picks[i].get("glass_depth", 0))
		var punch: float = ShotPunchTable.compute(
			GlassShatter.punch_after_layers(weapon_def.punch, layer_depth),
			slice.material, ShotPunchTable.SKILL_NEUTRAL,
			1.0, "%s:%d" % [salt, i])
		## ⚠️ THE WHOLE LADDER, NOT JUST THE VOXEL THE PELLET NAMED.
		##
		## This used to read `damage_state_for(punch)` on the resolved voxel alone
		## and call that the prediction. D30's ladder touches more than that: a
		## DESTROYED hit takes neighbours with it (D30.1) and penetrates into the
		## sibling slice (D16's second layer), and the shot the plan is predicting
		## reports 31 touched voxels for 24 pellets. Every one of those the plan did
		## not know about was a cell whose occupancy, whose soot and whose ATOM the
		## warm got wrong.
		##
		## step_multipliers mirrors fire_at_active()'s own branch: for a LINE weapon
		## the table is D1's PENETRATION axis, for a cone it means distance and has
		## no business attenuating depth (see apply_point_impact()'s note).
		for entry in BlastCalculatorClass.plan_point_impact(
				slice, int(resolved["voxel_index"]), punch, room._edge_registry,
				"%s:%d" % [salt, i],
				weapon_def.step_multipliers if is_line else [], origin_gu,
				weapon_def.blowout):
			var v: Voxel = entry["voxel"]
			## DESTROYED changes occupancy (what the light field is built from);
			## DENTED and CRACKED do not, but they DO feed the soot derivation
			## (D33-SOOT-01), and soot is part of the alternative id.
			if int(entry["state"]) == Voxel.DamageState.DESTROYED:
				destroyed[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = true
				continue
			damaged.append(entry)
			## ...and a DENTED or CRACKED voxel also MOVES to another atom, whose
			## light alternative is a fresh mint on the impact frame unless it is
			## warmed here. An empty resolve is the D33 runtime-composite fallback
			## (registry miss): its atlas coords are allocated while rendering, so
			## there is nothing to warm ahead of time and it is skipped rather than
			## guessed at.
			if room._voxel_renderer == null:
				continue
			var swap: Dictionary = room._voxel_renderer.resolve_damage_swap_for(
				entry["container"], int(entry["state"]), bool(entry["is_blast"]),
				int(entry["carved_side"]), int(entry["variant"]),
				int(entry["substrate"]))
			if swap.is_empty():
				continue
			variant_cells.append({"level": v.level, "cell": v.grid_pos,
				"source_id": swap["source_id"], "atlas_coords": swap["atlas_coords"]})
	return {"destroyed": destroyed, "damaged": damaged,
		"variant_cells": variant_cells, "impact_gus": gus.keys()}


## ONE definition of the shot's salt, because the precook and the real shot must
## roll identically or the prediction warms the wrong alternatives.
func _salt_for(origin_gu: Vector2i, target_gu: Vector2i) -> String:
	return "AGENTSHOT_%s_%s_%d" % [origin_gu, target_gu, room._world_revision]


func cancel_active() -> void:
	_active_guard_index = -1
	room.cancel_shot_precook()
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
	var weapon_def = Registries.get_weapon_registry().get_weapon(_weapon_id)
	if weapon_def == null:
		push_error("[AgentShotController] no WeaponDef for id '%s'" % _weapon_id)
		cancel_active()
		return
	if weapon_def.delivery != WeaponDef.DELIVERY_CONE \
			and weapon_def.delivery != WeaponDef.DELIVERY_LINE:
		push_error("[AgentShotController] '%s' declares delivery %s — only CONE and LINE are implemented (WEAPON_MASTER_PLAN Part 2 / Part 3b)." %
			[_weapon_id, weapon_def.delivery])
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

	var salt: String = _salt_for(origin_gu, target_gu)

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

	## ── THE LAG GOES HERE, ON PURPOSE ──────────────────────────────────────
	## Director, 2026-08-19: *"se ele clicar em 'disparar' a gente só solta a
	## animação depois que tudo estiver processado. É melhor dar o lag depois que
	## clica no botão do que no meio da execução."*
	##
	## So the warm started at target selection is JOINED here, before a single
	## frame of animation plays. When the player takes longer to read the menu
	## than the warm takes — the normal case — this returns immediately and there
	## is no lag at all. When they slam the button, they wait once, here, with
	## nothing on screen half-finished.
	await room.shot_precook_ready()
	if not is_instance_valid(room) or not is_instance_valid(room._voxel_renderer):
		return

	## E-MUZZLE-01: the flash fires at the shot, before any damage resolves —
	## the barrel does not wait to find out what it hit. The origin is the
	## AGENT's own muzzle anchor (Part A), not a prop cell centre.
	var muzzle_world: Vector2 = agent.muzzle_origin()
	var aim_world: Vector2 = _gu_centre_world(target_gu) - muzzle_world
	if aim_world != Vector2.ZERO:
		room.spawn_muzzle_flash(muzzle_world, aim_world.normalized())

	var prof_t0: int = Time.get_ticks_usec()
	var pellet_picks: Array = []
	if weapon_def.delivery == WeaponDef.DELIVERY_LINE:
		var line_hit := BlastCalculatorClass.select_line_impact(
			origin_gu, forward, PELLET_FLOOD_MAX_STEPS,
			_blocked_edges_dict(), room._blocked_cells, aim_offset_deg, _glass_edges_dict())
		if not line_hit.is_empty():
			pellet_picks.append(line_hit)
	else:
		pellet_picks = BlastCalculatorClass.select_cone_pellet_impacts(
			origin_gu, forward, weapon_def.cone_half_angle_deg,
			PELLET_FLOOD_MAX_STEPS, weapon_def.projectile_count,
			_blocked_edges_dict(), room._blocked_cells, salt, aim_offset_deg, _glass_edges_dict())
	## GLASS G7 (G-D5) — the round passes through glass; every pane it crossed
	## takes a hole, resolved and applied by the same loop as the terminal hit.
	pellet_picks = _flatten_glass_passthrough(pellet_picks)

	var cell_to_voxel: Dictionary = {}
	## W-TUNE-01: the tier tally is only readable PER MATERIAL. A shot walks a
	## cone across whatever happens to be in front of it, and "8 destroyed, 23
	## dented" says nothing about whether the ladder is right — metal and wood sit
	## three resistance rows apart and are supposed to answer differently. Every
	## calibration question the Director has asked about this ladder is a
	## per-material question, so the print answers in those terms.
	var cell_to_material: Dictionary = {}
	var cell_to_depth: Dictionary = {}
	var _impact_vfx_done: Dictionary = {}
	var pellets_landed: int = 0
	var punch_log: Array = []
	var is_line: bool = weapon_def.delivery == WeaponDef.DELIVERY_LINE

	## ── RESOLVE FIRST, THEN FLY, THEN BREAK ────────────────────────────────
	## The pellet loop used to do all three in one pass, and the DECORATIVE
	## PROJECTILE was invisible because of it. Measured 2026-08-19:
	## TracerOverlay._draw() ran exactly TWICE for a shot, at age 0.000 s and
	## 0.141 s — a single frame 141 ms long. The firearm path pays ~310 ms of
	## synchronous CPU at the trigger (WEAPON_MASTER_PLAN §0's W-PRECOOK
	## measurement, technical_debt 16), so the tracer's whole 0.14 s flight
	## elapsed INSIDE one stalled frame and the round was only ever drawn
	## already arrived.
	##
	## Splitting the pass fixes it without waiting for W-PRECOOK, and the split
	## is the more correct order anyway — Director, 2026-08-19: *"Daí rolamos o
	## dado, e é só soltar a animação do clarão, fumacinha, etc."* Flash, then
	## the round crosses, then the wall reacts. `resolve_pellet_voxel()` is a
	## lookup and mutates nothing, so moving it ahead of the flight changes no
	## outcome; `apply_point_impact()` is the mutation and stays after.
	## Declared before the resolve loop because the RENDER pass below needs it to
	## scope its repaint, and the profile print needs it after that.
	var impact_gus: Dictionary = {}
	var resolved_picks: Array = []
	for i in range(pellet_picks.size()):
		var resolved := BlastCalculatorClass.resolve_pellet_voxel(
			pellet_picks[i], room._edge_registry, "%s:%d" % [salt, i])
		if resolved.is_empty():
			continue
		resolved_picks.append({"index": i, "resolved": resolved})
		_draw_tracer(muzzle_world, pellet_picks[i])

	## NOTE THE NAME. This is RESOLVE only — the apply loop runs after the flight
	## and was silently outside every earlier measurement, which is how ~250 ms of
	## the impact frame went unaccounted for.
	var prof_resolve_ms: float = float(Time.get_ticks_usec() - prof_t0) / 1000.0
	var prof_apply0: int = 0
	## Let the rounds cross. Frame-counted rather than timed, because what has to
	## elapse is FRAMES DRAWN — the whole defect above was time passing without
	## any being drawn.
	for _f in range(TRACER_FLIGHT_FRAMES):
		await room.get_tree().process_frame
	if not is_instance_valid(room) or not is_instance_valid(room._voxel_renderer):
		push_warning("[AgentShotController] room went away mid-flight (map reload?) — shot abandoned")
		return

	var prof_tail0: int = Time.get_ticks_usec()
	prof_apply0 = Time.get_ticks_usec()
	for entry in resolved_picks:
		var i: int = int(entry["index"])
		var resolved: Dictionary = entry["resolved"]
		pellets_landed += 1
		var slice: Slice = resolved["slice"]
		## D30: one coefficient decides tier, neighbour count and cascade, and
		## each projectile rolls its OWN luck — D36's independent pellets.
		## Distance stays neutral for both shapes, as on the bench: D29's
		## falloff is explicitly deferred and switching it on here would be a
		## behaviour change nobody asked for in this wave.
		## G-D17 — the round arrives at this pick already through `glass_depth`
		## layers of glass, and everything downstream uses the weakened projectile:
		## the hole it makes here, the pane roll below, and the mark on whatever
		## wall it finally reaches. The precook loop above applies the identical
		## attenuation, because it has to warm the alternatives this will land on.
		var layer_depth: int = int(pellet_picks[i].get("glass_depth", 0))
		var punch: float = ShotPunchTable.compute(
			GlassShatter.punch_after_layers(weapon_def.punch, layer_depth),
			slice.material, ShotPunchTable.SKILL_NEUTRAL,
			1.0, "%s:%d" % [salt, i])
		punch_log.append(snappedf(punch, 0.01))
		## D32.4: the SHOOTER's GU decides which face the mark lands on — without
		## it apply_point_impact() leaves carved_side NONE and the bullet hole
		## renders on the voxel's top diamond.
		## W-TUNE-02: `blowout` is the weapon's own hole-widening share — see
		## WeaponDef.blowout. Passed rather than defaulted because the shotgun and
		## the pistol both declare 0.0 and would otherwise crater like a rifle.
		var plan_entries := BlastCalculatorClass.plan_point_impact(
			slice, int(resolved["voxel_index"]), punch,
			room._edge_registry, "%s:%d" % [salt, i],
			weapon_def.step_multipliers if is_line else [],
			origin_gu, weapon_def.blowout)
		var touched: Array = []
		for pe in plan_entries:
			var pv: Voxel = pe["voxel"]
			pv.set_damage(int(pe["state"]), bool(pe["is_blast"]),
				int(pe["carved_side"]), int(pe["variant"]), int(pe["substrate"]))
			touched.append(pv)
			var pkey := Vector3i(pv.grid_pos.x, pv.grid_pos.y, pv.level)
			## The DEPTH is the Director's own vocabulary for calibrating this —
			## *"uns 5 voxels na primeira slice e até 3 na segunda"* — so the report
			## has to carry it. Min-wins: a voxel reached at both depths (only
			## possible through D30.2's cascade) belongs to the shallower one.
			var d: int = int(pe["depth"])
			if not cell_to_depth.has(pkey) or d < int(cell_to_depth[pkey]):
				cell_to_depth[pkey] = d
			_index_voxel(cell_to_voxel, pv)
			cell_to_material[pkey] = slice.material
			if pv.damage_state != Voxel.DamageState.DESTROYED:
				if not _impact_vfx_done.has(pkey):
					_impact_vfx_done[pkey] = true
					room.dispatch_impact_vfx(pv.grid_pos, pv.level, slice.material)

		## GLASS G3 (G-D11/G-D12/G-D13) — on top of the local hole, this pellet
		## rolls its OWN chance to take the whole pane (or a region larger than
		## its hole). After the local hole so the flood spreads from a real gap.
		_maybe_shatter_pane(slice, int(resolved["voxel_index"]), weapon_def,
			"%s:%d" % [salt, i], cell_to_voxel, cell_to_material, cell_to_depth,
			layer_depth)

	var prof_apply_ms: float = float(Time.get_ticks_usec() - prof_apply0) / 1000.0
	## B3: a round with no wall behind the target is VOID and nothing happens
	## (D15). That is a legitimate outcome, not a failure, so it is reported
	## rather than warned about — the capture for this wave is required to
	## include one, or the wave only proves the lucky case.
	## The impact GUs are PRINTED, not just counted. A bare "landed=24/24" says a
	## number of pellets met a wall and nothing about WHICH wall — and "the wall
	## C behind the target" is the entire geometric claim this wave exists to
	## test. It is also what an unattended capture needs in order to frame the
	## damage instead of the shooter.
	for pick in pellet_picks:
		impact_gus[pick["gu"]] = true
	## The TIER TALLY, not just the voxel count. "24 pellets landed" and "the wall
	## changed" are different claims, and only the second one is the wave's: a
	## punch below ShotPunchTable.PUNCH_DENT_MIN still counts as landed while
	## leaving a mark too faint to see on a busy stone facade. Counting the
	## resulting states is what tells a capture-that-shows-nothing apart from a
	## shot-that-did-nothing.
	var tiers: Dictionary = {}
	var by_material: Dictionary = {}
	for key in cell_to_voxel:
		var tv: Voxel = cell_to_voxel[key]
		tiers[tv.damage_state] = int(tiers.get(tv.damage_state, 0)) + 1
		var mat: String = "%s:s%d" % [String(cell_to_material.get(key, "?")),
			int(cell_to_depth.get(key, 0)) + 1]
		if not by_material.has(mat):
			by_material[mat] = {"CRACKED": 0, "DENTED": 0, "DESTROYED": 0}
		## `_TIER_NAME` covers the three tiers a shot can produce, and INTACT is
		## not one of them — but this row is initialised with those three keys and
		## a bare `dict[missing] += 1` is a hard runtime error, not a zero. So the
		## unknown tier gets counted under a key that EXISTS and says so, rather
		## than taking the tier print down with it: a diagnostic must not be the
		## thing that crashes the shot it is diagnosing.
		var tier_name: String = String(_TIER_NAME.get(tv.damage_state, ""))
		if tier_name == "":
			push_warning("[AgentShotController] voxel %s ended a shot in tier %d, which no rung of the ladder produces — counted as UNKNOWN."
				% [tv.grid_pos, tv.damage_state])
			tier_name = "UNKNOWN"
		if not by_material[mat].has(tier_name):
			by_material[mat][tier_name] = 0
		by_material[mat][tier_name] += 1
	print_debug("[AGENT-SHOT] from=%s at=%s outcome=MISS(forced) axis=%s offset=%.1f deg landed=%d/%d impacts=%s voxels=%d tiers=%s punch=%s" %
		[origin_gu, target_gu, forward, aim_offset_deg,
		pellets_landed, pellet_picks.size(), impact_gus.keys(),
		cell_to_voxel.size(), tiers, punch_log])
	var tier_keys: Array = by_material.keys()
	tier_keys.sort()
	for mat in tier_keys:
		var row: Dictionary = by_material[mat]
		var bare: String = String(mat).split(":")[0]
		## An UNKNOWN bucket only exists if the warning above fired; printing it
		## unconditionally would put a permanent "unknown=0" on a line the Director
		## reads a calibration matrix off.
		var unknown: String = ""
		if int(row.get("UNKNOWN", 0)) > 0:
			unknown = "  unknown=%d" % int(row["UNKNOWN"])
		print_debug("[AGENT-SHOT-TIER] %-12s cracked=%2d dented=%2d destroyed=%2d  (resist %.2f, breach %.2f)%s"
			% [mat, row["CRACKED"], row["DENTED"], row["DESTROYED"],
			ShotPunchTable.resistance(bare), ShotPunchTable.destroy_min(bare), unknown])

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
	var prof_render0: int = Time.get_ticks_usec()
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
	var prof_render_ms: float = float(Time.get_ticks_usec() - prof_render0) / 1000.0
	var prof_repaint0: int = Time.get_ticks_usec()
	## SCOPED, not map-wide. See Room._repaint_voxel_light_buckets_scoped() for
	## the measurement: the full apply walks every placed cell on the board and
	## is ~400 ms of the shot's ~581, for 23 voxels of actual damage.
	var repaint_scope: Array = room.shot_repaint_scope(impact_gus.keys())
	if room.has_method("_repaint_voxel_light_buckets_scoped"):
		## ⚠️ NO SOOT HERE, EVER. Director, 2026-08-19: *"A fuligem vamos tirar da
		## conta totalmente. Só vamos começar a calcular a fuligem depois que o
		## impacto já foi, os tiles trocaram, e a fumacinha está saindo da
		## parede."* The map-wide snapshot is ~140 ms and this frame already
		## carries the tile swap and the smoke; soot has no business in it.
		room._repaint_voxel_light_buckets_scoped(repaint_scope, false)
	elif room.has_method("_repaint_voxel_light_buckets"):
		room._repaint_voxel_light_buckets(true)
	var prof_repaint_ms: float = float(Time.get_ticks_usec() - prof_repaint0) / 1000.0
	room._destruction_render_busy = false
	## W-PROF-01, on the AGENT path this time. §0's routes are chosen from these
	## two numbers, so they are printed rather than assumed — the figures it was
	## scheduled on (resolve 1 ms, repaint ~310 ms) are from the retired bench in
	## August and deserve re-measuring before anything is built on them.
	## THE WHOLE TAIL, against the sum of its parts. The impact frame measured
	## ~520 ms while the parts summed to ~253 — so either something between the
	## probes is expensive, or the cost is engine-side and outside this function
	## entirely. This line is what tells those two apart.
	print_debug("[AGENT-SHOT-PROF] TAIL TOTAL %.2f ms (post-flight, wall)"
		% [float(Time.get_ticks_usec() - prof_tail0) / 1000.0])
	print_debug("[AGENT-SHOT-PROF] resolve %.2f · apply+vfx %.2f · render-pass %.2f · repaint %.2f ms · %d voxel(s)"
		% [prof_resolve_ms, prof_apply_ms, prof_render_ms, prof_repaint_ms,
		cell_to_voxel.size()])

	## NOT awaited, and deliberately LAST. The tiles have swapped and the smoke is
	## out; the soot is the only thing left, and the Director has ruled that a lag
	## here is acceptable — *"Se der lag nesse momento, OK."* It is a SINGLE pass,
	## not a fade: each fade rung writes a different soot code, so each rung mints
	## a fresh set of alternatives, and the TileSet rebuild is charged per FRAME
	## THAT MINTS. A four-step fade therefore costs four rebuilds — measured at
	## 240-420 ms each, which is how the fade turned one stall into five.
	## The A/B the last session left behind, ACTUALLY WIRED. `shot_soot_deferred`
	## was declared, documented as *"INFILTRAITOR_SHOT_SOOT_DEFER=1 turns it back
	## on"*, and read by nobody — so the switch did nothing and the fade it names
	## was unreachable code. A lever that silently does nothing is worse than no
	## lever: the next person to try it concludes the fade is harmless.
	if room.shot_soot_deferred:
		room.fade_in_scoped_soot(repaint_scope)
	else:
		room.apply_scoped_soot(repaint_scope)


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
	## GLASS G7 — a pass-through crossing is not where the round stopped; the
	## tracer runs to the terminal hit only.
	if pick.has("pane_id"):
		return
	var impact_world: Vector2 = _gu_centre_world(pick["gu"])
	if impact_world == Vector2.ZERO:
		push_warning("[AgentShotController] tracer skipped — GU %s has no world position" % pick["gu"])
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


## GLASS G3 — the per-projectile shatter roll (G-D11), the region flood (G-D12)
## and the frame-ring remnant floor (G-D13). Called once per pellet that landed
## on a pane, AFTER its local hole is applied. On a won roll every flooded voxel
## is DESTROYED and folded into the shot's own bookkeeping so the render pass,
## VL-PERSIST and `bump_world_revision()` all pick it up unchanged.
##
## Panel panes only — glass BLOCKS (`PANE_BLOCK_*`) have no single run axis and
## are deferred (they were never the target case, GLASS_MASTER_PLAN §0).
func _maybe_shatter_pane(hit_slice: Slice, hit_voxel_index: int, weapon_def: WeaponDef,
		pick_salt: String, cell_to_voxel: Dictionary, cell_to_material: Dictionary,
		cell_to_depth: Dictionary, layer_depth: int = 0) -> void:
	if hit_slice.pane_id == "" or hit_slice.pane_id.begins_with("PANE_BLOCK_"):
		return
	if hit_voxel_index < 0 or hit_voxel_index >= hit_slice.voxels.size():
		return
	var hv: Voxel = hit_slice.voxels[hit_voxel_index]
	## G-D9: on a brick-capped window the hit may be in a brick band — not a pane hit.
	var rel: int = hv.level - GeometryCoords.storey_level_base(hit_slice.start_storey)
	## G-D16: the hit's OWN glass id, carried from here on rather than the literal
	## it used to be. Identical for base glass, and it is what lets an armored or
	## screen pane take its own resistance row when V-B adds them.
	var hit_material: String = hit_slice.material_at(rel)
	if not GlassMaterials.is_glass(hit_material):
		return
	## The glass punch for THIS pellet, at this pellet's own luck — G-D17: through
	## whatever glass it has already crossed. Attenuating the ROLL and leaving the
	## REGION at full strength would give a pane that barely breaks a sniper-sized
	## hole, so `punch_after_layers` is applied once, here, and carried into both.
	var glass_punch: float = ShotPunchTable.compute(
		GlassShatter.punch_after_layers(weapon_def.punch, layer_depth), hit_material,
		ShotPunchTable.SKILL_NEUTRAL, 1.0, pick_salt)
	if not GlassShatter.rolls_shatter(glass_punch, pick_salt):
		return

	var all_slices: Array = room._edge_registry.all_slices()
	var pane_slices: Array = []
	for s in all_slices:
		if s.pane_id == hit_slice.pane_id:
			pane_slices.append(s)

	## G-D13b — a shard survives only where it has something to hang from. The
	## anchor set is every non-glass voxel in the pane's own plane: its G-D9
	## bands, and any wall (half-thickness included) on the same edge line. An
	## EMPTY set means a free-standing pane, and then the whole thing goes.
	var anchors: Dictionary = GlassShatter.collect_anchor_positions(
		pane_slices, hit_slice.face, all_slices)
	var plan: Array = GlassShatter.plan_pane_shatter(pane_slices, hit_slice.face,
		hv.grid_pos, hv.level, glass_punch, pick_salt, anchors)
	var n: int = 0
	var fallen: Array = []
	for e in plan:
		var s2: Slice = e["slice"]
		var pv: Voxel = s2.voxels[int(e["voxel_index"])]
		if pv.damage_state == Voxel.DamageState.DESTROYED:
			continue
		pv.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
		var pkey := Vector3i(pv.grid_pos.x, pv.grid_pos.y, pv.level)
		_index_voxel(cell_to_voxel, pv)
		cell_to_material[pkey] = hit_material
		if not cell_to_depth.has(pkey):
			cell_to_depth[pkey] = 0
		n += 1
		fallen.append({"grid_pos": pv.grid_pos, "level": pv.level})
	if n > 0:
		print_debug("[GLASS-SHATTER] pane=%s glass_punch=%.2f radius=%d flooded=%d voxel(s)"
			% [hit_slice.pane_id, glass_punch, GlassShatter.region_radius(glass_punch), n])
		## G-D16a — where the glass that fell ends up. Reported on the REAL path from
		## the day the rule exists, not left until G6 can draw it: §7.1's own risk
		## note is that this project has already shipped two features that were built
		## and never triggered, and a number in the shot's own log is the cheapest
		## thing that cannot rot unnoticed. G6 is the consumer that makes it visible,
		## and it is blocked on the `shard_floor` art.
		var landings: Array = GlassFall.plan_landings(fallen, room._slab_registry.all_slabs())
		var piles: Dictionary = GlassFall.pile_by_cell(landings)
		var deepest: int = 0
		for c in piles.values():
			deepest = maxi(deepest, int(c))
		print_debug("[GLASS-FALL] %d of %d shard(s) landed, on %d cell(s), deepest pile %d (%d fell out of the world)"
			% [landings.size(), n, piles.size(), deepest, n - landings.size()])


## Same conversion TestZoneController and WeaponBenchController do — room's
## {"from","to"} pairs folded into the keyed shape WallEdgeData queries.
func _blocked_edges_dict() -> Dictionary:
	var blocked: Dictionary = {}
	for e in room._current_blocked_edges:
		blocked[WallEdgeData.edge_key(e["from"], e["to"])] = true
	return blocked


## GLASS G7 — glass PANEL edges the round passes THROUGH (G-D5), keyed like
## `_blocked_edges_dict()`, value = pane_id. Panels never reach
## `_current_blocked_edges`, so this comes straight off the edge registry.
func _glass_edges_dict() -> Dictionary:
	if room._edge_registry == null:
		return {}
	return room._edge_registry.glass_edge_keys()


## GLASS G7 — turn each pick's `glass_passed` (the panes a round crossed) into
## standalone picks, in flight order, so the shot's normal resolve/apply loop
## puts a hole in every pane on the way to the terminal hit.
## G-D17 stamps `glass_depth` HERE, because this is the one place that knows the
## flight order: within one original pellet the crossings come out in the order
## the ray met them, and the terminal hit last. Depth 0 is the first glass the
## round meets, so an unobstructed shot is bit-identical to before.
func _flatten_glass_passthrough(picks: Array) -> Array:
	var out: Array = []
	for p in picks:
		var crossed: int = 0
		for g in p.get("glass_passed", []):
			var g2: Dictionary = g.duplicate()
			g2["glass_depth"] = crossed
			crossed += 1
			out.append(g2)
		if p.has("gu"):
			## The terminal hit is behind everything the round went through, so it
			## arrives with the full stack's attenuation — a wall behind two panes
			## takes a weaker mark than the same wall in the open. That is the
			## Director's own wording: the PROJECTILE loses power, not just its
			## chance of taking a pane.
			var p2: Dictionary = p.duplicate()
			p2["glass_depth"] = crossed
			out.append(p2)
	return out


## World position of a GU cell's centre at chest height — the same
## GU→voxel→world chain the bench's muzzle flash uses.
func _gu_centre_world(gu: Vector2i) -> Vector2:
	if room._voxel_renderer == null:
		return Vector2.ZERO
	var half: int = int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0)
	var centre: Vector2i = GeometryCoords.gu_to_voxel_origin(gu) + Vector2i(half, half)
	return room._voxel_renderer.voxel_world_position(centre, MUZZLE_LEVEL)
