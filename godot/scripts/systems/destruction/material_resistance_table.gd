## MaterialResistanceTable — DESTRUCTION_MASTER_PLAN Part 3, extended by D22.
## How much of a ring-group's voxels convert to DESTROYED vs DENTED vs CRACKED
## for a given wall/roof/floor material.
##
## D21 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): material properties are
## registered dynamic data, never hardcoded and never map-coupled — the old
## `const TABLE` literal is gone. Data now lives in `res://materials/*.json`
## (+ `user://materials/*.json`, user wins on collision), the same files
## `MaterialRegistry` reads for render properties — one row per material, one
## file per material, no duplication between the two readers. This file keeps
## its original static-accessor API (`destroy_factor`/`dent_factor`/
## `crack_factor(material_id) -> float`, same defaults) so every existing
## call site (BlastCalculator, selftests) is untouched — only the data
## source changed, lazily loaded and cached on first access.
##
## Ordering (resistance to destruction, most -> least), per Director
## (2026-07-30 session): metal > stone > concrete > wood. Values are
## first-pass placeholders — a balancing lever (D6), not researched
## constants; expect these to be retuned once real captures show the effect.
class_name MaterialResistanceTable

const RES_MATERIALS_DIR := "res://materials"
const USER_MATERIALS_DIR := "user://materials"

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
## dent_factor is the one live number.
## D32.6 (Director, 2026-08-02): "metal e madeira não ficam rachados, só dented
## ou balas." A blast on either now produces DESTROYED or DENTED and nothing
## else — crack_factor 0.0, matching the table's own standing rule that a tier
## with no art wired stays off, except here the reason is physical rather than
## practical: neither material fractures the way concrete and stone do. Their
## dent_factor is deliberately NOT raised to absorb the lost share — that
## would be a balance change nobody asked for, and the freed voxels simply
## stay intact. Bullets are unaffected: a firearm's CRACKED tier is a bullet
## MARK on the struck face, not a fracture, and it reads from the bullet
## family (VoxelRenderer.damage_variant_material's blast_sourced=false
## branch).
## PERF-02 B2 (Director, 2026-08-04): the four wall materials scaled down
## together, ~x0.65, as part of making an explosion physically smaller rather
## than only faster.
## PERF-02 B2b (2026-08-04): two of the ×0.65 results were walked back — wood's
## destroy_factor 0.6 → 0.75, metal's dent_factor 0.3 → 0.35.
## E-CRACK-01 (Director, 2026-08-08): wood's `dent_factor` 0.03 → 0.2, the ONLY
## row this session moved. At 0.03 a real PLAYGROUND blast put 7 dents on a wood
## floor that lost 137 voxels — D32.6 says wood dents instead of cracking, and
## 0.03 made that promise effectively void. Everything else the Director asked
## for this session ("menos destruídos, mais decals") was tuned on the BOMB
## (`frag_grenade.json`'s ring weights) and on the crater's own core radius
## instead, deliberately: this table is shared with FIREARMS through
## apply_container_damage(), so every row moved here silently retunes shotgun and
## sniper damage too. This one row is worth that side effect (a bullet should be
## able to dent wood at all); the rest were not.
##
## D19 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): a material behaves
## identically on floor, wall and ceiling — the old duplicate `ground_*` rows
## (a second, disagreeing row for the same material — e.g. `concrete`
## {0.3, 0.15, 0.1} vs `ground_concrete` {0.5, 0.2, 0.0}) are gone. One
## `concrete` row now, `crack_factor` 0.1, closing D10's old gap by
## construction: floors crack like walls. `grass`/`dirt`/`gravel`/`sand`
## (renamed from `ground_grass`/`ground_dirt`/`ground_gravel`/`ground_sand`,
## D20) keep the values they always had.

## Defaults stay 0.0 for dent/crack (not any row's own values) so any
## material outside the registered roster (an unknown id) keeps today's
## DESTROYED-only behaviour instead of silently picking up a damage tier that
## has no texture wired to it yet.
const DEFAULT_DESTROY_FACTOR := 0.5
const DEFAULT_DENT_FACTOR := 0.0
const DEFAULT_CRACK_FACTOR := 0.0

## Lazily loaded, cached on first access. Non-const by construction (D21) —
## a `const` here would be exactly the violation this rewrite closes.
static var _table: Dictionary = {}
static var _loaded: bool = false


static func destroy_factor(material: String) -> float:
	return float(_row(material).get("destroy_factor", DEFAULT_DESTROY_FACTOR))


static func dent_factor(material: String) -> float:
	return float(_row(material).get("dent_factor", DEFAULT_DENT_FACTOR))


static func crack_factor(material: String) -> float:
	return float(_row(material).get("crack_factor", DEFAULT_CRACK_FACTOR))


static func _row(material: String) -> Dictionary:
	_ensure_loaded()
	return _table.get(material, {})


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_scan_dir(RES_MATERIALS_DIR)
	_scan_dir(USER_MATERIALS_DIR)


static func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file := FileAccess.open(dir_path.path_join(fname), FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					var id := String(parsed.get("id", ""))
					if not id.is_empty():
						_table[id] = {
							"destroy_factor": float(parsed.get("destroy_factor", DEFAULT_DESTROY_FACTOR)),
							"dent_factor": float(parsed.get("dent_factor", DEFAULT_DENT_FACTOR)),
							"crack_factor": float(parsed.get("crack_factor", DEFAULT_CRACK_FACTOR)),
						}
		fname = dir.get_next()
