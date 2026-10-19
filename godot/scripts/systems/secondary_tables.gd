## SecondaryTables — gives every SECONDARY material (`MaterialRows`, `inherits`) its primary's entry in the behaviour tables keyed by material id,
## once at boot (`Registries._ready`). Kept apart from `MaterialRows` so the row reader depends on no render or destruction class.
class_name SecondaryTables
extends RefCounted

const MaterialRowsRef = preload("res://godot/scripts/systems/material_rows.gd")
const RubblePresetsRef = preload("res://godot/scripts/systems/destruction/rubble_presets.gd")
const ShotPunchTableRef = preload("res://godot/scripts/systems/destruction/shot_punch_table.gd")
const SoftSheetPresetsRef = preload("res://godot/scripts/systems/destruction/soft_sheet_presets.gd")
const Board3DLiveRef = preload("res://godot/scripts/geometry/board3d_live.gd")


## The material-keyed behaviour tables (static). A secondary takes its primary's entry in each, so `RubblePresets.NO_FALL.has(id)` or
## `ShotPunchTable.RESISTANCE.get(id)` answers for an object as for its substance with no change at the call sites. `material_rows_selftest`
## fails when a table of these four classes is added without being listed here. Instance tables (Room's VFX profiles) are aliased where they live.
## Glass is NOT here: a glass member is asked through `GlassMaterials.is_glass()`, its own family mechanism. Returns the entries added.
static func apply() -> int:
	var n: int = 0
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.SPEED)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.NO_FALL)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.SPLINTERS)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.FLY_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.RAMP_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.JITTER_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLOCK_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.STAY_EDGE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.STAY_INNER_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.FLY_TEXTURED_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_ROOF_HOLE_RADIUS_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_CHUNK_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_MAX_CHUNKS_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_VOXEL_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_MAX_VOXELS_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_SUB_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_MAX_SUBS_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_UP_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_MAX_UP_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_UP_PUSH_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_SOOT_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_RIM_TRICKLES_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_RIM_DELAY_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_DUST_REACH_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_FALL_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_RIM_BITS_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_RIM_BITS_SOOT_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_RIM_BITS_TEXTURED)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_FIRE_SPREAD_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ROOF_TOP_SOOT_LIFT_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_TRICKLE_MATERIALS)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_TRICKLE_SHARE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_BREACH_MATERIALS)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_DUST_CHANCE_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.BLAST_CHIPS_MULT_OF)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.FORWARD_MATERIALS)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.NO_DUST)
	n += MaterialRowsRef.alias_secondaries(RubblePresetsRef.ZONE_RADIUS_OF)
	n += MaterialRowsRef.alias_secondaries(ShotPunchTableRef.RESISTANCE)
	n += MaterialRowsRef.alias_secondaries(ShotPunchTableRef.DESTROY_MIN)
	n += MaterialRowsRef.alias_secondaries(ShotPunchTableRef.HOLE_ONLY_MATERIALS)
	n += MaterialRowsRef.alias_secondaries(ShotPunchTableRef.TEAR_SIZE)
	n += MaterialRowsRef.alias_secondaries(ShotPunchTableRef.CASCADE_MIN)
	n += MaterialRowsRef.alias_secondaries(SoftSheetPresetsRef.OF)
	n += MaterialRowsRef.alias_secondaries(Board3DLiveRef.FRESH_KEEPS_FACADE)
	n += MaterialRowsRef.alias_secondaries(Board3DLiveRef.FRESH_LIFT_OF)
	n += MaterialRowsRef.alias_secondaries(Board3DLiveRef.FRESH_CLEAN_OF)
	if n > 0:
		print("[SecondaryTables] %d table entr%s given to secondary materials" % [n, "y" if n == 1 else "ies"])
	return n
