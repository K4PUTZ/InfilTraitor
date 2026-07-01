# WALL-EDGE-01 — Subcube Wall Straddle: Variantes Direcionais no Tileset

> **Pré-requisitos:** COORD-01-B (`SubcubeGeometry`) já no repo; subcubo renderizando
> na tela (wall faces visíveis, mesmo que mal-posicionadas).
> **Natureza:** Edição CIRÚRGICA e ADITIVA em `room.gd` — apenas
> `_build_subcube_tileset()` e `_paint_subcube_descriptor()`. Zero outras funções.

---

## CONTEXT

O sistema de subcubos atual renderiza faces de parede com o mesmo tile neutro usado
para blocos sólidos — sem nenhum offset direcional. O efeito visível: os subcubos
ficam **dentro** do tile de parede, consumindo área útil do espaço interno da sala.

O sistema antigo (`build_tileset.gd`) já resolveu esse problema com
`EDGE_VISUAL_OFFSETS`: cada direção de parede recebe um `texture_origin` diferente
que empurra o sprite para estralar a aresta entre os dois tiles adjacentes. Este
prompt replica exatamente esse mecanismo no tileset de subcubos — reutilizando os
valores já calibrados.

**Mecanismo:** Cada material de subcubo (`concrete`, `metal`, `stone`, `wood`) ganha
4 variantes direcionais (`_NW`, `_NE`, `_SE`, `_SW`), todas usando o mesmo PNG de
base, mas com `texture_origin` diferente. Quando `_paint_subcube_descriptor()` pinta
uma face de parede, seleciona a variante correspondente à direção da aresta.

**Valores de straddle** (mesmos do `EDGE_VISUAL_OFFSETS` de `build_tileset.gd`,
calibrados em commit 924dbf0 — não alterar sem calibração visual):

```
NW: Vector2i(-16,  8)   →  texture_origin final = Vector2i(-16, -32)
NE: Vector2i(-16, -8)   →  texture_origin final = Vector2i(-16, -48)
SE: Vector2i( 16, -8)   →  texture_origin final = Vector2i( 16, -48)
SW: Vector2i( 16,  8)   →  texture_origin final = Vector2i( 16, -32)
```

`texture_origin final = SUBCUBE_BASE_ORIGIN + straddle_offset`
`SUBCUBE_BASE_ORIGIN = Vector2i(0, -40)` (valor atual, não muda)

---

## MODULE

- `godot/scripts/world/room.gd` — edição aditiva cirúrgica (2 funções + 2 consts)

---

## TASK

### 1. Adicionar 2 constantes junto do bloco de subcube (após linha `const SUBCUBE_STEP_PX`)

```gdscript
## Ponto de origem base para todos os tiles de subcubo no tileset (inalterado).
const SUBCUBE_BASE_ORIGIN := Vector2i(0, -40)

## Offsets de straddle por direção de aresta — replicam EDGE_VISUAL_OFFSETS de
## build_tileset.gd (calibrados em commit 924dbf0). Somados a SUBCUBE_BASE_ORIGIN
## para compor o texture_origin da variante direcional.
const SUBCUBE_FACE_OFFSETS: Dictionary = {
	"NW": Vector2i(-16,  8),
	"NE": Vector2i(-16, -8),
	"SE": Vector2i( 16, -8),
	"SW": Vector2i( 16,  8),
}
```

### 2. Substituir `_build_subcube_tileset()` (conteúdo integral)

Substitui a função existente por esta versão que, para cada material, registra
primeiro o tile base (para blocos sólidos) e depois as 4 variantes direcionais
(para faces de parede), todas apontando para o mesmo PNG.

```gdscript
func _build_subcube_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var source_id: int = 0
	var materials: Array[String] = ["subcube_concrete", "subcube_metal", "subcube_stone", "subcube_wood"]
	var directions: Array[String] = ["NW", "NE", "SE", "SW"]

	for mat in materials:
		var path := "res://ASSETS/ISOMETRIC/source_assets/subcubes/%s.png" % mat
		var texture: Texture2D = load(path)
		if texture == null:
			push_warning("Room: missing subcube texture: %s" % path)
			continue

		## Tile base — blocos sólidos (sem offset direcional)
		var src_base := TileSetAtlasSource.new()
		src_base.texture = texture
		src_base.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		src_base.create_tile(Vector2i(0, 0))
		ts.add_source(src_base, source_id)
		var td_base: TileData = src_base.get_tile_data(Vector2i(0, 0), 0)
		if td_base != null:
			td_base.texture_origin = SUBCUBE_BASE_ORIGIN
			td_base.set_custom_data("tile_name", mat)
		_subcube_tile_ids[mat] = source_id
		source_id += 1

		## Variantes direcionais — faces de parede (mesmo PNG, texture_origin diferente)
		for dir in directions:
			var variant_name := "%s_%s" % [mat, dir]
			var src_dir := TileSetAtlasSource.new()
			src_dir.texture = texture
			src_dir.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
			src_dir.create_tile(Vector2i(0, 0))
			ts.add_source(src_dir, source_id)
			var td_dir: TileData = src_dir.get_tile_data(Vector2i(0, 0), 0)
			if td_dir != null:
				td_dir.texture_origin = SUBCUBE_BASE_ORIGIN + SUBCUBE_FACE_OFFSETS[dir]
				td_dir.set_custom_data("tile_name", variant_name)
			_subcube_tile_ids[variant_name] = source_id
			source_id += 1

	if source_id == 0:
		push_warning("Room: subcube tileset could not be built; subcube render will stay on fallback.")
		return null
	return ts
```

### 3. Substituir `_paint_subcube_descriptor()` (conteúdo integral)

A única mudança lógica: quando `is_wall_face`, deriva a direção a partir de
`edge_delta` e usa a variante direcional em vez do tile base. Todo o resto
(footprint, layer_index, set_cell) é idêntico ao original.

```gdscript
func _paint_subcube_descriptor(desc: Dictionary, source_id: int, layer_count: int) -> void:
	var base_cell: Vector2i = INVALID_CELL
	var edge_delta: Vector2i = INVALID_CELL
	var is_wall_face: bool = false

	if desc.has("unit"):
		base_cell = Vector2i(desc["unit"])
	elif desc.has("edge"):
		var edge: Dictionary = desc["edge"]
		base_cell = Vector2i(edge.get("from", INVALID_CELL))
		var to_cell: Vector2i = Vector2i(edge.get("to", INVALID_CELL))
		edge_delta = to_cell - base_cell
		is_wall_face = true
	else:
		return

	## Seleciona tile: variante direcional para faces de parede, base para blocos.
	var active_source_id: int = source_id  ## fallback = tile base passado pelo caller
	if is_wall_face:
		var dir: String = _edge_delta_to_dir(edge_delta)
		if dir != "":
			var tile_name := "subcube_concrete_%s" % dir
			var dir_id: int = _subcube_tile_ids.get(tile_name, -1)
			if dir_id >= 0:
				active_source_id = dir_id

	var storey: int = maxi(0, int(desc.get("storey", 0)))
	var footprint: Array[Vector2i] = SubcubeCoordsClass.unit_subcubes(base_cell)

	## Wall faces paint only subcubes along the edge; solid blocks fill the footprint
	if is_wall_face:
		footprint = _subcubes_on_edge(base_cell, edge_delta)

	for local_level in range(SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS):
		var layer_index := storey * SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS + local_level
		if layer_index < 0 or layer_index >= layer_count:
			continue
		var layer := _subcube_layers[layer_index]
		for subcell in footprint:
			layer.set_cell(subcell, active_source_id, Vector2i(0, 0))
```

### 4. Adicionar helper `_edge_delta_to_dir()` após `_subcubes_on_edge()`

```gdscript
func _edge_delta_to_dir(delta: Vector2i) -> String:
	## Converte edge_delta de subcube_geometry para sufixo direcional (NW/NE/SE/SW).
	## Retorna "" para deltas inválidos (não deve ocorrer em geometria válida).
	match delta:
		Vector2i( 0, -1): return "NW"
		Vector2i( 1,  0): return "NE"
		Vector2i( 0,  1): return "SE"
		Vector2i(-1,  0): return "SW"
	return ""
```

---

## DO NOT TOUCH

- **`_subcubes_on_edge()`** — não muda; continua retornando a row/coluna de aresta
  da unit. O straddle visual é feito exclusivamente via `texture_origin`.
- **`_render_subcube_geometry()`** — não muda; continua chamando
  `_paint_subcube_descriptor(block, source_id, layer_count)` para blocos. O
  `source_id` passado ali é o tile base (concrete) — correto para blocos sólidos.
- **`_ensure_subcube_layers()`** — não muda.
- **`subcube_geometry.gd`** e **`map_compiler.gd`** — não tocados neste prompt.
- **Nenhum outro arquivo** fora de `room.gd`.
- **Não alterar os valores** de `SUBCUBE_FACE_OFFSETS` sem calibração visual
  confirmada pelo diretor de arte.

---

## ACCEPTANCE

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural (grep)

```bash
## Constantes novas presentes
grep -n "SUBCUBE_BASE_ORIGIN\|SUBCUBE_FACE_OFFSETS" godot/scripts/world/room.gd

## Variantes direcionais registradas no tileset
grep -c '"NW"\|"NE"\|"SE"\|"SW"' godot/scripts/world/room.gd  # >= 8 ocorrências

## Helper presente
grep -n "_edge_delta_to_dir" godot/scripts/world/room.gd

## Nenhum outro arquivo alterado
git diff --name-only  # apenas room.gd
```

### Comportamento esperado no jogo

Ao rodar o PLAYGROUND ou SIGMA-01, as faces de parede subcube devem visualmente
estralar as arestas dos tiles — a massa principal da parede sentada sobre o limite
entre os dois tiles adjacentes, em vez de dentro do tile de parede. O interior da
sala deve ganhar área útil visível. Blocos sólidos (`block_SE` de divisórias) não
devem ser afetados.

---

**Escopo:** 1 arquivo (`room.gd`) · 4 alterações cirúrgicas
(2 consts + 2 funções substituídas + 1 helper adicionado) · 1 sessão.
