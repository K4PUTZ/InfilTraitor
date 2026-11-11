## WeaponDef — weapon definition resource. WEAPON_MASTER_PLAN Part 1 (D1/D2/D7).
##
## Mirrors BombDef's shape exactly (plain object + from_json() factory, not a
## Godot Resource), which itself mirrors PropDef — the fourth use of one proven
## pattern, not a new one.
##
## D1: a weapon that touches the scenario declares a DELIVERY SHAPE plus a STEP
## FALLOFF TABLE. `step_multipliers` is the generalisation of
## BombDef.ring_multipliers: index 0 is the weapon's own GU (full effect), each
## further index one step outward along whatever "outward" means for that shape,
## and the table's LENGTH is the weapon's range. What varies between a grenade,
## a shotgun and a rifle is only what one step means:
##   RADIAL — a wall-aware BFS ring (BlastCalculator.flood_gu_rings)
##   CONE   — the same BFS, gated to a wedge around a facing (flood_gu_cone)
##   LINE   — penetration depth along a ray (not built yet)
##   NONE   — no voxel damage at all; the effect belongs to perception/noise/AI
##
## Deliberately carries only fields something actually consumes today. Rarity,
## firerate, ammo and AP cost are NOT here — WEAPON_MASTER_PLAN D9 defers them,
## and a speculative field that nothing reads is a field that rots.
class_name WeaponDef

const JsonFileRef = preload("res://godot/scripts/systems/json_file.gd")

## D1's four delivery shapes. Stored as a String in JSON (authoring stays
## readable) and validated on load — an unknown value loud-fails rather than
## silently defaulting to something destructive.
const DELIVERY_RADIAL := "RADIAL"
const DELIVERY_CONE := "CONE"
const DELIVERY_LINE := "LINE"
const DELIVERY_NONE := "NONE"
const VALID_DELIVERIES: Array[String] = [
	DELIVERY_RADIAL, DELIVERY_CONE, DELIVERY_LINE, DELIVERY_NONE,
]

var id: String
var delivery: String = DELIVERY_NONE
## Index 0 = the weapon's own GU, each further index one step outward; the
## table's size IS the weapon's range in GU. Same contract as
## BombDef.ring_multipliers, which is what makes bombs/*.json migratable.
var step_multipliers: Array[float] = []
## CONE only — half-angle of the wedge, measured in GU space around the facing.
## D2: this IS the weapon's accuracy. Tighter = more accurate = narrower cone.
var cone_half_angle_deg: float = 0.0
## D2's calibre/punch knob: multiplies MaterialResistanceTable.destroy_factor,
## so a heavier round beats concrete where a lighter one only scratches it.
## 1.0 = exactly as destructive as a grenade against the same material.
var destroy_multiplier: float = 1.0
## D30: the weapon's base term in the ShotPunchTable coefficient — what ONE
## projectile of this weapon is worth before skill, distance, luck and material
## resistance apply. Deliberately SEPARATE from destroy_multiplier because the
## two answer different questions: destroy_multiplier scales a GROUP fraction
## (how much of a ring group converts), punch scales a SINGLE point impact.
## The shotgun is what forces the split — 0.6 is right as a group scalar, but
## each of its 24 pellets is individually feeble (*"cada tiro da shotgun tem seu
## próprio dado, mas individualmente tem menos potência do que outros tiros
## singulares"*). Falls back to destroy_multiplier when the JSON omits it, so a
## definition written before this field keeps its old relative strength instead
## of silently reading as 0.
var punch: float = 1.0
## D14/D27: how many independent projectiles one shot fires — sniper 1,
## shotgun ~8, pistol 1. Each rolls its own hit, its own impact point
## (BlastCalculator.select_cone_pellet_impacts()), its own damage tier
## (apply_point_impact()). Default 1 covers every single-projectile weapon
## without needing the field in every JSON.
var projectile_count: int = 1
## W-TUNE-02 (Director, 2026-08-20): how much of the neighbouring wall goes with
## this round's hole, as a share of ShotPunchTable's punch-driven ramp. 1.0 is a
## round that fragments what it breaches (a rifle); 0.0 is one that punches a
## clean single-voxel hole (a pistol — and each individual shotgun pellet, whose
## character is 24 separate marks, not one crater).
##
## It is a WEAPON axis rather than a function of punch because punch cannot
## express it: a pistol in wood and a rifle in concrete land in overlapping punch
## bands, and the Director wants one voxel from the first and five from the
## second. Default 1.0 keeps every definition written before this field exactly
## as destructive as it was.
var blowout: float = 1.0
## SOOT-VARY 3 (Director, 2026-09-22 plan): how far this weapon's scorch reaches
## from each voxel it touched, in voxel steps (L1). Falls back to Room's old flat
## default (3) so a definition written before this field keeps its old spread.
var soot_radius: int = 3
var gameplay: Dictionary = {}
var tags: Array[String] = []

## HERITAGE T2 W1 (2026-11-11) — what the weapon LOOKS like, in one row for every copy of it: in the Agent's hand, on
## the floor, on a table, as a pickup (`"model"` in `weapons/<id>.json`). Ruling (Director, 2026-11-11): a weapon is
## ALWAYS the size it was given in the Agent's hands. `size_certified` is the day that size was set by hand with the
## figure holding it (MOVEMENT_MASTER_PLAN §9 item 7); "" = not yet, and such a weapon WARNS when its row loads.
var model_path: String = ""
var surface_materials: Dictionary = {}
## Where the Tripo figure holds it: the bone, the offset in the bone's frame (figure units) and the scale (1.0 once the
## size is certified, the proportion being baked into the model).
var hand_bone: String = "RightHand"
var hand_pos: Vector3 = Vector3.ZERO
var hand_scale: float = 1.0
var size_certified: String = ""
## HERITAGE T2 W4 — the muzzle: where a round leaves, a point of the MODEL (its own units, the barrel along +X), measured
## once off the mesh (the front face of the barrel / slide). A shot starts at this point carried by the gun's real
## placement in the hand, never at a world coordinate. Vector3.INF = not measured (the shot falls back to the old anchor).
var muzzle: Vector3 = Vector3.INF
## The grip the old r3d_live rig holds this weapon with ("shotgun" / "pistol"); "" = it has none, and the figure keeps
## what it holds (`ActorPose.set_weapon`).
var held_as: String = "shotgun"


## Factory: parse WeaponDef from a JSON dict — same contract as
## BombDef.from_json()/PropDef.from_json().
static func from_json(data: Dictionary) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = String(data.get("id", ""))

	def.delivery = String(data.get("delivery", DELIVERY_NONE))
	if not VALID_DELIVERIES.has(def.delivery):
		push_error("[WeaponDef] '%s': unknown delivery '%s' — expected one of %s" %
			[def.id, def.delivery, VALID_DELIVERIES])
		return def

	def.step_multipliers = []
	for m in data.get("step_multipliers", []):
		def.step_multipliers.append(float(m))

	def.cone_half_angle_deg = float(data.get("cone_half_angle_deg", 0.0))
	def.destroy_multiplier = float(data.get("destroy_multiplier", 1.0))
	def.punch = float(data.get("punch", def.destroy_multiplier))
	def.projectile_count = int(data.get("projectile_count", 1))
	def.blowout = float(data.get("blowout", 1.0))
	def.soot_radius = int(data.get("soot_radius", 3))
	def.gameplay = data.get("gameplay", {})

	def.tags = []
	for tag in data.get("tags", []):
		def.tags.append(String(tag))

	def.held_as = String(data.get("held_as", "shotgun"))
	var model: Variant = data.get("model", null)
	if model is Dictionary:
		var m: Dictionary = model
		def.model_path = String(m.get("path", ""))
		def.surface_materials = m.get("surface_materials", {})
		def.size_certified = String(m.get("size_certified", ""))
		if m.has("muzzle"):
			def.muzzle = JsonFileRef.vector3(m.get("muzzle"), Vector3.INF, "weapon '%s' muzzle" % def.id, [])
		var hand: Variant = m.get("hand", {})
		if hand is Dictionary:
			var h: Dictionary = hand
			def.hand_bone = String(h.get("bone", "RightHand"))
			def.hand_pos = JsonFileRef.vector3(h.get("pos", [0.0, 0.0, 0.0]), Vector3.ZERO, "weapon '%s' hand pos" % def.id, [])
			def.hand_scale = float(h.get("scale", 1.0))
		if def.model_path != "" and def.size_certified == "":
			push_warning("[WeaponDef] '%s': its size in the Agent's hands is not certified yet (MOVEMENT_MASTER_PLAN §9 item 7): it is drawn at its model's own size" % def.id)

	return def


## World units per model unit, everywhere this weapon is drawn: the Tripo figure's own scale (the model is held in the
## figure's units) times the hand scale. The one size of the ruling: the hand, the floor, the table and the pickup.
func world_scale() -> float:
	return TripoFigure.WORLD_SCALE * hand_scale


## The weapon's box in world units when its model is turned by `rotation_deg` (a table copy lies flat): the size it has in
## the Agent's hands, measured off the model. Vector3.ZERO when it has no model or the model does not load.
func world_size(rotation_deg: Vector3 = Vector3.ZERO) -> Vector3:
	if model_path == "":
		return Vector3.ZERO
	return PropModelFit.native_size(model_path, rotation_deg) * world_scale()

