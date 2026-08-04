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
## "earth" (FLOOR-DENT-01, 2026-08-01): consumed by the floor-dent path only —
## apply_crater_damage()'s crater geometry ignores destroy_factor, so
## dent_factor is the one live number: the prevalence of carved-TOP pockmarks
## among crater-rim survivors and in the fading band beyond the crater. Same
## first-pass placeholder status as every other row. crack_factor stays 0.0:
## no earth crack texture exists, and the table's own rule is that a tier with
## no texture wired stays off.
## D32.6 (Director, 2026-08-02): "metal e madeira não ficam rachados, só dented
## ou balas." A blast on either now produces DESTROYED or DENTED and nothing
## else — crack_factor 0.0, matching the table's own standing rule that a tier
## with no art wired stays off, except here the reason is physical rather than
## practical: neither material fractures the way concrete and stone do. Their
## dent_factor is deliberately NOT raised to absorb the lost share — that would
## be a balance change nobody asked for, and the freed voxels simply stay
## intact. Bullets are unaffected: a firearm's CRACKED tier is a bullet MARK on
## the struck face, not a fracture, and it reads from the bullet family
## (VoxelRenderer.damage_variant_material's blast_sourced=false branch).
## PERF-02 B2 (Director, 2026-08-04): the four wall materials scaled down
## together, ~x0.65, as part of making an explosion physically smaller rather
## than only faster. Scaling destroy_factor ALONE would have been worse than
## useless here: the voxels it spared would fall through to dent_factor/
## crack_factor, which is the expensive runtime-decal-composite path — the
## same total churn, just relabelled. Lowering all three is what actually
## reduces how many voxels a blast touches. Rows below the four (glass, earth,
## the ground_* zones) are deliberately untouched: this pass is about the wall
## materials the test bench exercises, and the floor's own volume is addressed
## structurally by B4 instead.
const TABLE := {
	"metal":    {"destroy_factor": 0.03, "dent_factor": 0.3,  "crack_factor": 0.0},
	"stone":    {"destroy_factor": 0.2,  "dent_factor": 0.2,  "crack_factor": 0.1},
	"concrete": {"destroy_factor": 0.3,  "dent_factor": 0.15, "crack_factor": 0.1},
	"wood":     {"destroy_factor": 0.6,  "dent_factor": 0.03, "crack_factor": 0.0},
	"glass":    {"destroy_factor": 0.7,  "dent_factor": 0.0,  "crack_factor": 0.0},
	"earth":    {"destroy_factor": 0.5,  "dent_factor": 0.3,  "crack_factor": 0.0},
	## FLOOR-DENT-01 — the ground_* zone materials (MaterialRegistry.
	## register_ground_defaults()). Added with "earth" because the only floor
	## in the real test map (PLAYGROUND) is a single ground_concrete zone
	## covering all 24x16 GUs: without these rows the floor-dent path is
	## reachable ONLY on plain earth and produces literally zero dents on the
	## map it is tested against (measured: 0 dents across 42 affected floor
	## slabs before this row existed). dent_factor mirrors each material's
	## obvious counterpart above, same first-pass placeholder status as every
	## other row. destroy_factor is inert for floors — apply_crater_damage()
	## decides removal geometrically — and is listed only so the rows are not
	## half-specified. crack_factor 0.0: no ground crack texture exists.
	"ground_concrete": {"destroy_factor": 0.5, "dent_factor": 0.2,  "crack_factor": 0.0},
	"ground_gravel":   {"destroy_factor": 0.5, "dent_factor": 0.3,  "crack_factor": 0.0},
	"ground_dirt":     {"destroy_factor": 0.5, "dent_factor": 0.35, "crack_factor": 0.0},
	"ground_grass":    {"destroy_factor": 0.5, "dent_factor": 0.35, "crack_factor": 0.0},
	"ground_sand":     {"destroy_factor": 0.5, "dent_factor": 0.4,  "crack_factor": 0.0},
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
