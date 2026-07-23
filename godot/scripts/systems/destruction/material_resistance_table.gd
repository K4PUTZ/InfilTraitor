## MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3.
## How much of a ring-group's voxels convert to DESTROYED vs CRACKED for a
## given wall/roof material. Engine-tuning data (not content-author data
## like BombDef), so no res://+user:// two-tier — a plain fixed table,
## matching bake_policy.gd's material→facade mapping shape.
##
## Ordering (resistance to destruction, most -> least), per Director
## (this session): metal > stone > concrete > wood. Values below are
## first-pass placeholders — a balancing lever (D6), not researched
## constants; expect these to be retuned once real captures show the effect.
class_name MaterialResistanceTable

## destroy_factor: fraction of a ring-group's voxels that convert to
## DESTROYED, before multiplying by that ring's ring_multiplier.
## crack_factor: same, but for DamageState.CRACKED (visual distortion only —
## metal "pode ser distorcido," not destroyed). Applied to voxels NOT already
## selected for destruction within the same ring-group.
const TABLE := {
	"metal":    {"destroy_factor": 0.05, "crack_factor": 0.6},
	"stone":    {"destroy_factor": 0.3,  "crack_factor": 0.0},
	"concrete": {"destroy_factor": 0.5,  "crack_factor": 0.0},
	"wood":     {"destroy_factor": 0.9,  "crack_factor": 0.0},
}

const DEFAULT_DESTROY_FACTOR := 0.5
const DEFAULT_CRACK_FACTOR := 0.0


static func destroy_factor(material: String) -> float:
	return float(TABLE.get(material, {}).get("destroy_factor", DEFAULT_DESTROY_FACTOR))


static func crack_factor(material: String) -> float:
	return float(TABLE.get(material, {}).get("crack_factor", DEFAULT_CRACK_FACTOR))
