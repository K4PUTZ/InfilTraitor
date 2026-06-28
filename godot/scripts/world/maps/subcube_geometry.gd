class_name SubcubeGeometry
## Costura (Master Plan FASE A / COORD-01-B): expande a geometria de Gameplay Units
## em DESCRITORES de subcubo para o plano de render. NÃO materializa subcubos
## individuais nem pixels — o render layer (SUB-01) expande os descritores e aplica
## o offset de straddle (espessura dividida entre tiles vizinhos).
##
##   wall_*     → FACE fina ancorada na ARESTA (4 de largura × andar)
##   block_*    → bloco SÓLIDO (footprint 4×4 × andar)
##   doorOpen_* → vão (nenhum descritor no andar)
##   piso / props → fora do escopo (render por regra / sprites)
##
## Vertical fica em ANDARES (storeys); o render multiplica por SUBCUBES_PER_FLOOR.
## Largura/footprint horizontal = SubcubeCoords.SUBCUBES_PER_UNIT_AXIS (= 4).

## Sufixo de face → edge_delta em UNIT coords (sistema vértice-alinhado, N=topo).
## NW=cima-esq | NE=cima-dir | SE=baixo-dir | SW=baixo-esq
## Ver DIRECTION_GLOSSARY.md §3 e §6.
const _EDGE_BY_SUFFIX: Dictionary = {
	"NW": [Vector2i(-1, 0)],
	"NE": [Vector2i( 0,-1)],
	"SE": [Vector2i( 1, 0)],
	"SW": [Vector2i( 0, 1)],
}

## Constrói os descritores a partir do dict já compilado (usa "wall_levels").
static func build(compiled: Dictionary) -> Dictionary:
	var SC = load("res://godot/scripts/world/subcube_coords.gd")
	var wall_levels: Array = compiled.get("wall_levels", [])
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []

	for storey in wall_levels.size():
		var course: Array = wall_levels[storey]
		for entry: Dictionary in course:
			var cell: Vector2i = entry["cell"]
			var tile_name: String = String(entry["tile_name"])

			if tile_name.begins_with("doorOpen_"):
				continue  ## vão — sem descritor neste andar

			elif tile_name.begins_with("wall_"):
				var suffix: String = tile_name.trim_prefix("wall_")
				for d: Vector2i in _EDGE_BY_SUFFIX.get(suffix, []):
					wall_faces.append(_face(cell, d, storey, tile_name, SC))

			elif tile_name.begins_with("block_"):
				solid_blocks.append({
					"unit": cell,
					"storey": storey,
					"footprint_subcubes": SC.SUBCUBES_PER_UNIT_AXIS,
					"tile": tile_name,
				})
			## crate_* e outros não aparecem em wall_levels; ignorados por segurança.

	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks}


static func _face(cell: Vector2i, edge_delta: Vector2i, storey: int, tile: String, SC) -> Dictionary:
	return {
		"edge": {"from": cell, "to": cell + edge_delta},
		"storey": storey,
		"width_subcubes": SC.SUBCUBES_PER_UNIT_AXIS,
		"tile": tile,
	}
