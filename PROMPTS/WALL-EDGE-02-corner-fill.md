# WALL-EDGE-02 — Corner Fill: Gap de Esquina Preenchido por Coluna Extra de Subcubos

> **Pré-requisitos:** WALL-EDGE-01 concluído e visualmente validado (faces de parede
> estralando arestas corretamente).
> **Natureza:** Edição ADITIVA em `subcube_geometry.gd` (novo array `corner_fills`
> no output) + edição CIRÚRGICA em `room.gd` (variantes de corner no tileset +
> nova função de pintura). Zero regressão nas faces e blocos existentes.

---

## CONTEXT

Após WALL-EDGE-01, as faces de parede retas estão corretamente posicionadas sobre
as arestas. Porém, no encontro de duas paredes perpendiculares (`wallCorner_XX`),
o offset direcional de cada face cria um **gap triangular** no vértice diagonal
da esquina — a geometria de cada face se afasta do centro e as duas extremidades
não se encontram.

A solução é uma **coluna extra de subcubos** (corner fill) posicionada exatamente
sobre o vértice da esquina, com overlapping deliberado sobre as extremidades das
duas faces adjacentes. Subcubos puros — sem asset novo, sem shading próprio.

**Posição do corner fill** (em subcube local coords da unit `wallCorner_XX`):

```
wallCorner_NW  →  local (0, 0)  →  vértice NW da unit
wallCorner_NE  →  local (3, 0)  →  vértice NE da unit
wallCorner_SW  →  local (0, 3)  →  vértice SW da unit
wallCorner_SE  →  local (3, 3)  →  vértice SE da unit
```

**Offsets de corner** (mesmos do `CORNER_VISUAL_OFFSETS` de `build_tileset.gd`,
calibrados em commit 924dbf0 — não alterar sem calibração visual):

```
NW: Vector2i(  0, 16)  →  texture_origin final = Vector2i(  0, -24)
NE: Vector2i(-32, -8)  →  texture_origin final = Vector2i(-32, -48)
SE: Vector2i(  0,-16)  →  texture_origin final = Vector2i(  0, -56)
SW: Vector2i( 32, -8)  →  texture_origin final = Vector2i( 32, -48)
```

`texture_origin final = SUBCUBE_BASE_ORIGIN + corner_offset`
`SUBCUBE_BASE_ORIGIN = Vector2i(0, -40)` (definido em WALL-EDGE-01)

---

## MODULE

- `godot/scripts/world/maps/subcube_geometry.gd` — edição aditiva (novo array
  `corner_fills` + helper `_corner_fill`)
- `godot/scripts/world/room.gd` — edição cirúrgica (1 const nova +
  variantes de corner no tileset + 1 função nova `_paint_corner_fill` +
  1 linha em `_render_subcube_geometry`)

---

## TASK

### 1. Editar `godot/scripts/world/maps/subcube_geometry.gd`

#### 1a. Adicionar constante `_CORNER_FILL_LOCAL` após `_CORNER_EDGES`

```gdscript
## Posição local (no espaço de subcubos da unit) da coluna de corner fill,
## indexada pela direção da esquina. Corresponde ao vértice mais externo da unit
## em cada direção.
const _CORNER_FILL_LOCAL: Dictionary = {
	"NW": Vector2i(0, 0),
	"NE": Vector2i(3, 0),
	"SW": Vector2i(0, 3),
	"SE": Vector2i(3, 3),
}
```

#### 1b. Modificar `build()` — aditivo dentro do bloco `wallCorner_`

Localizar o bloco existente:

```gdscript
		elif tile_name.begins_with("wallCorner_"):
			var suffix: String = tile_name.trim_prefix("wallCorner_")
			for d: Vector2i in _CORNER_EDGES.get(suffix, []):
				wall_faces.append(_face(cell, d, storey, tile_name, SC))
```

Substituir por (mesmas duas linhas de face, mais o corner fill):

```gdscript
		elif tile_name.begins_with("wallCorner_"):
			var suffix: String = tile_name.trim_prefix("wallCorner_")
			for d: Vector2i in _CORNER_EDGES.get(suffix, []):
				wall_faces.append(_face(cell, d, storey, tile_name, SC))
			corner_fills.append(_corner_fill(cell, suffix, storey, SC))
```

#### 1c. Declarar `corner_fills` no topo de `build()`, junto de `wall_faces`

Localizar:
```gdscript
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []
```

Substituir por:
```gdscript
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []
	var corner_fills: Array[Dictionary] = []
```

#### 1d. Adicionar `corner_fills` ao return de `build()`

Localizar:
```gdscript
	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks}
```

Substituir por:
```gdscript
	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks, "corner_fills": corner_fills}
```

#### 1e. Adicionar helper `_corner_fill()` após `_face()`

```gdscript
static func _corner_fill(cell: Vector2i, dir: String, storey: int, SC) -> Dictionary:
	## Descritor de coluna de corner fill para fechar o gap diagonal.
	## `subcube` é a posição absoluta no grid de subcubos (origin + local offset).
	var origin: Vector2i = SC.unit_to_subcube_origin(cell)
	var local_offset: Vector2i = _CORNER_FILL_LOCAL.get(dir, Vector2i(0, 0))
	return {
		"type":   "corner_fill",
		"subcube": origin + local_offset,
		"dir":    dir,
		"storey": storey,
	}
```

---

### 2. Editar `godot/scripts/world/room.gd`

#### 2a. Adicionar constante `SUBCUBE_CORNER_OFFSETS` junto de `SUBCUBE_FACE_OFFSETS`

```gdscript
## Offsets de corner fill por direção — replicam CORNER_VISUAL_OFFSETS de
## build_tileset.gd (calibrados em commit 924dbf0). Somados a SUBCUBE_BASE_ORIGIN
## para compor o texture_origin da variante de corner.
const SUBCUBE_CORNER_OFFSETS: Dictionary = {
	"NW": Vector2i(  0,  16),
	"NE": Vector2i(-32,  -8),
	"SE": Vector2i(  0, -16),
	"SW": Vector2i( 32,  -8),
}
```

#### 2b. Modificar `_build_subcube_tileset()` — adicionar variantes de corner

No loop `for mat in materials:`, após o bloco das variantes direcionais
(`for dir in directions:`), adicionar o bloco de variantes de corner:

```gdscript
		## Variantes de corner fill — fecham o gap diagonal em esquinas wallCorner_XX
		var corner_dirs: Array[String] = ["NW", "NE", "SE", "SW"]
		for cdir in corner_dirs:
			var corner_name := "%s_corner_%s" % [mat, cdir]
			var src_corner := TileSetAtlasSource.new()
			src_corner.texture = texture
			src_corner.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
			src_corner.create_tile(Vector2i(0, 0))
			ts.add_source(src_corner, source_id)
			var td_corner: TileData = src_corner.get_tile_data(Vector2i(0, 0), 0)
			if td_corner != null:
				td_corner.texture_origin = SUBCUBE_BASE_ORIGIN + SUBCUBE_CORNER_OFFSETS[cdir]
				td_corner.set_custom_data("tile_name", corner_name)
			_subcube_tile_ids[corner_name] = source_id
			source_id += 1
```

#### 2c. Modificar `_render_subcube_geometry()` — processar corner_fills

Localizar o bloco existente de pintura:

```gdscript
	var blocks: Array = subcube_geometry.get("solid_blocks", [])
	var faces: Array = subcube_geometry.get("wall_faces", [])
	for block: Dictionary in blocks:
		_paint_subcube_descriptor(block, source_id, layer_count)
	for face: Dictionary in faces:
		_paint_subcube_descriptor(face, source_id, layer_count)
```

Substituir por (bloco original intacto + 3 linhas aditivas ao final):

```gdscript
	var blocks: Array = subcube_geometry.get("solid_blocks", [])
	var faces: Array = subcube_geometry.get("wall_faces", [])
	for block: Dictionary in blocks:
		_paint_subcube_descriptor(block, source_id, layer_count)
	for face: Dictionary in faces:
		_paint_subcube_descriptor(face, source_id, layer_count)
	var fills: Array = subcube_geometry.get("corner_fills", [])
	for fill: Dictionary in fills:
		_paint_corner_fill(fill, layer_count)
```

#### 2d. Adicionar `_paint_corner_fill()` após `_paint_subcube_descriptor()`

```gdscript
func _paint_corner_fill(fill: Dictionary, layer_count: int) -> void:
	## Pinta 1 coluna de subcubos no vértice de corner, fechando o gap diagonal.
	## Usa variante direcional com SUBCUBE_CORNER_OFFSETS para o offset visual.
	var dir: String = String(fill.get("dir", ""))
	if dir == "":
		return
	var tile_name := "subcube_concrete_corner_%s" % dir
	var fill_source_id: int = _subcube_tile_ids.get(tile_name, -1)
	if fill_source_id < 0:
		push_warning("Room: corner fill tile not found: %s" % tile_name)
		return
	var subcell: Vector2i = Vector2i(fill["subcube"])
	var storey: int = maxi(0, int(fill.get("storey", 0)))
	for local_level in range(SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS):
		var layer_index := storey * SubcubeCoordsClass.SUBCUBES_PER_UNIT_AXIS + local_level
		if layer_index < 0 or layer_index >= layer_count:
			continue
		_subcube_layers[layer_index].set_cell(subcell, fill_source_id, Vector2i(0, 0))
```

---

## DO NOT TOUCH

- **`_face()`** em `subcube_geometry.gd` — não muda; corner_fill é emitido em
  paralelo, não substitui as duas faces normais da esquina.
- **`_paint_subcube_descriptor()`** em `room.gd` — não muda; corner fills têm
  função própria (`_paint_corner_fill`).
- **`_subcubes_on_edge()`** — não muda.
- **Nenhum outro arquivo** além dos dois do MODULE.
- **Não alterar os valores** de `SUBCUBE_CORNER_OFFSETS` sem calibração visual
  confirmada pelo diretor de arte.
- **`source_id` base (concrete)** continuando a ser passado como fallback em
  `_render_subcube_geometry()` para blocos — não alterar essa lógica.

---

## ACCEPTANCE

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural (grep)

```bash
## subcube_geometry.gd — corner_fills presente
grep -n "corner_fills\|_corner_fill\|_CORNER_FILL_LOCAL" godot/scripts/world/maps/subcube_geometry.gd

## subcube_geometry.gd — return atualizado
grep -n '"corner_fills"' godot/scripts/world/maps/subcube_geometry.gd

## room.gd — constante e função de corner presentes
grep -n "SUBCUBE_CORNER_OFFSETS\|_paint_corner_fill\|corner_fills" godot/scripts/world/room.gd

## Apenas os 2 arquivos do MODULE alterados
git diff --name-only  # subcube_geometry.gd + room.gd
```

### Invariantes de regressão

```bash
## wall_faces e solid_blocks continuam presentes no output de subcube_geometry
grep -n '"wall_faces"\|"solid_blocks"' godot/scripts/world/maps/subcube_geometry.gd
```

### Comportamento esperado no jogo

Ao rodar o PLAYGROUND ou SIGMA-01, os vértices das esquinas de parede
(`wallCorner_NW`, `wallCorner_NE`, etc.) devem ter o gap diagonal fechado por
uma coluna de subcubos. O interior das paredes deve aparecer contínuo, sem
"buracos" diagonais nos cantos. Paredes retas e blocos sólidos não devem ser
afetados.

---

**Escopo:** 2 arquivos · `subcube_geometry.gd` (1 const + 3 vars + 1 helper +
1 linha no loop + 1 chave no return) · `room.gd` (1 const + 1 bloco no tileset +
3 linhas em `_render_subcube_geometry` + 1 função nova) · 1 sessão.
