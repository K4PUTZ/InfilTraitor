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
var gameplay: Dictionary = {}
var tags: Array[String] = []


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
	def.gameplay = data.get("gameplay", {})

	def.tags = []
	for tag in data.get("tags", []):
		def.tags.append(String(tag))

	return def


## True when this weapon has a range to fall off over. A NONE-delivery weapon
## (flashbang, smoke, dart) legitimately has none.
func has_range() -> bool:
	return not step_multipliers.is_empty()
