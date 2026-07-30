## MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3, extended by D22.
## How much of a ring-group's voxels convert to DESTROYED vs DENTED vs CRACKED
## for a given wall/roof material. Engine-tuning data (not content-author data
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
## dent_factor: same, for DamageState.DENTED — a sunken special piece, short
## of destroyed. Applied to voxels NOT already selected for DESTROYED.
## crack_factor: same, for DamageState.CRACKED — a flat surface mark, no
## sinking. Applied to voxels NOT already selected for DESTROYED or DENTED.
## D22 (Director, 2026-07-30): every material can reach every tier — no
## material is hardcoded to stay whole. What used to be metal's lone
## crack_factor 0.6 is now split across dent_factor (the sunken look metal was
## originally meant to show) and a smaller crack_factor (a lighter graze).
## "glass" (D22, 2026-07-30): DESTROYED-only, by explicit Director decision —
## "não vai ter dented; é buraco feito, ou não feito" — dent/crack forced to
## 0.0 rather than left to the default, so the rule reads as intentional data,
## not an accident of an unlisted material. destroy_factor set high (glass is
## fragile) as a first-pass placeholder; the "grandes chances de levar vários
## voxels em volta, ou quebrar a janela inteira" cascade beyond the normal
## ring falloff is NOT modeled here yet — flagged open in
## DESTRUCTION_MASTER_PLAN §7 item 4, not invented on the spot.
const TABLE := {
	"metal":    {"destroy_factor": 0.05, "dent_factor": 0.5,  "crack_factor": 0.3},
	"stone":    {"destroy_factor": 0.3,  "dent_factor": 0.3,  "crack_factor": 0.2},
	"concrete": {"destroy_factor": 0.5,  "dent_factor": 0.2,  "crack_factor": 0.15},
	"wood":     {"destroy_factor": 0.9,  "dent_factor": 0.05, "crack_factor": 0.03},
	"glass":    {"destroy_factor": 0.7,  "dent_factor": 0.0,  "crack_factor": 0.0},
}

## Defaults stay 0.0 for dent/crack (not the table's own values) so any
## material outside the four canon ones (earth/ground floor variants, an
## unknown id) keeps today's DESTROYED-only behaviour instead of silently
## picking up a damage tier that has no texture wired to it yet.
const DEFAULT_DESTROY_FACTOR := 0.5
const DEFAULT_DENT_FACTOR := 0.0
const DEFAULT_CRACK_FACTOR := 0.0


static func destroy_factor(material: String) -> float:
	return float(TABLE.get(material, {}).get("destroy_factor", DEFAULT_DESTROY_FACTOR))


static func dent_factor(material: String) -> float:
	return float(TABLE.get(material, {}).get("dent_factor", DEFAULT_DENT_FACTOR))


static func crack_factor(material: String) -> float:
	return float(TABLE.get(material, {}).get("crack_factor", DEFAULT_CRACK_FACTOR))
