# CONTAINER-01 — WallContainer: Substituição do TileMapLayer por Sprites de Parede

> **Pré-requisitos:** WALL-EDGE-01 concluído. WALL-EDGE-01b e WALL-EDGE-02 aplicados
> (serão revertidos aqui como parte do cleanup).
> **Natureza:** Cleanup de 3 arquivos + 1 arquivo novo + edição em `room.gd`.
> Resolve o bug dos 3 subcubos e estabelece a arquitetura de Container para paredes.

---

## CONTEXT

O sistema `wallCorner_*` foi uma tentativa de adaptar tiles Kenney (320×512 px) ao
pipeline de subcubos (64×72 px). O resultado são dois renderers em conflito na mesma
célula e offsets de corner completamente descalibrados. A solução correta é o
**Container System**: cada face de parede vira um `Node2D` com filhos `Sprite2D`,
um por subcubo. Faces separadas são nós separados — zero overwrite, zero conflito.

**Por que isso resolve o bug dos 3 subcubos:**
No `TileMapLayer`, duas faces na mesma célula fazem `set_cell()` no mesmo slot —
a segunda sobrescreve a primeira. Com Containers como `Node2D` independentes,
duas faces no mesmo corner cell são simplesmente dois nós irmãos. Eles se
sobrepõem visualmente sem conflito de dados.

**Fórmula de posicionamento** (derivada analiticamente):

Para um `Sprite2D` com `centered = true`, texture `64×72`, em tilemap `tile_size=(64,32)`:

```
sprite.position = ref_layer.map_to_local(subcell)
                + FACE_CENTER_OFFSET[dir]
                + Vector2(0.0, -(storey * 4 + level) * SUBCUBE_STEP_PX)
```

Onde `FACE_CENTER_OFFSET` (precalculado — não alterar sem calibração visual):

```gdscript
const FACE_CENTER_OFFSET := {
    "NW": Vector2(-16.0, -12.0),
    "NE": Vector2(-16.0, -28.0),
    "SE": Vector2( 16.0, -28.0),
    "SW": Vector2( 16.0, -12.0),
}
const BLOCK_CENTER_OFFSET := Vector2(0.0, -20.0)  ## blocos sólidos (sem straddle)
```

---

## MODULE

- `godot/scripts/world/maps/map_geometry.gd` — revert WALL-EDGE-01b (corners → dois wall_*)
- `godot/scripts/world/maps/subcube_geometry.gd` — revert WALL-EDGE-01b + WALL-EDGE-02
- `godot/scripts/world/room.gd` — revert partes do WALL-EDGE-02 + nova função + disable TileMapLayer para walls
- `godot/scripts/world/wall_container.gd` — **NOVO** (classe WallContainer)

---

## TASK

### 1. Reverter `map_geometry.gd` (revert WALL-EDGE-01b)

**Localizar:**

```gdscript
	## Corners generate one wallCorner_* tile (two face-descriptors via _CORNER_EDGES
	## in subcube_geometry.gd). Single tile avoids double set_cell() at the vertex subcube.
	if on_nw and on_sw:
		tiles.append("wallCorner_NW")
	elif on_nw and on_ne:
		tiles.append("wallCorner_NE")
	elif on_se and on_sw:
		tiles.append("wallCorner_SW")
	elif on_se and on_ne:
		tiles.append("wallCorner_SE")
	## Straight edges generate one wall
```

**Substituir por:**

```gdscript
	## Corners emit two wall_* entries — one per exposed face direction.
	## Each becomes an independent WallContainer (Node2D). No set_cell() conflict.
	if on_nw and on_sw:
		tiles.append("wall_NW")
		tiles.append("wall_SW")
	elif on_nw and on_ne:
		tiles.append("wall_NW")
		tiles.append("wall_NE")
	elif on_se and on_sw:
		tiles.append("wall_SE")
		tiles.append("wall_SW")
	elif on_se and on_ne:
		tiles.append("wall_SE")
		tiles.append("wall_NE")
	## Straight edges generate one wall
```

---

### 2. Reverter `subcube_geometry.gd` (revert WALL-EDGE-01b + WALL-EDGE-02)

#### 2a. Remover `_CORNER_EDGES` e `_CORNER_FILL_LOCAL`

**Localizar e DELETAR** o bloco inteiro (adicionado pelo WALL-EDGE-01b + 02):

```gdscript
## sufixo de vértice → as duas arestas expostas do corner (NW/NE/SW/SE)
const _CORNER_EDGES: Dictionary = {
	"NW": [Vector2i(0, -1), Vector2i(-1, 0)],
	"NE": [Vector2i(0, -1), Vector2i( 1, 0)],
	"SW": [Vector2i(0,  1), Vector2i(-1, 0)],
	"SE": [Vector2i(0,  1), Vector2i( 1, 0)],
}
```

E se existir `_CORNER_FILL_LOCAL`, deletar também.

#### 2b. Remover `corner_fills` de `build()`

**Localizar:**

```gdscript
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []
	var corner_fills: Array[Dictionary] = []
```

**Substituir por:**

```gdscript
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []
```

#### 2c. Remover branch `wallCorner_*` de `build()`

**Localizar e DELETAR** o branch inteiro (adicionado pelo WALL-EDGE-01b):

```gdscript
			elif tile_name.begins_with("wallCorner_"):
				var suffix: String = tile_name.trim_prefix("wallCorner_")
				for d: Vector2i in _CORNER_EDGES.get(suffix, []):
					wall_faces.append(_face(cell, d, storey, tile_name, SC))
```

#### 2d. Remover `corner_fills` do return

**Localizar:**

```gdscript
	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks, "corner_fills": corner_fills}
```

**Substituir por:**

```gdscript
	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks}
```

#### 2e. Remover helper `_corner_fill()` se existir

Deletar a função `_corner_fill()` inteira caso tenha sido adicionada pelo WALL-EDGE-02.

---

### 3. Criar `godot/scripts/world/wall_container.gd` (NOVO)

```gdscript
class_name WallContainer
extends Node2D
## Container de parede: representa UMA face de parede (1 unit wide × 1 storey).
## Filhos Sprite2D = 4 subcubos horizontais × 4 níveis de altura = 16 sprites.
## Nó independente — dois WallContainers num mesmo corner cell coexistem sem conflito.
##
## Posicionamento derivado analiticamente de tile_size=(64,32) e sprite=(64,72):
##   sprite.position = ref_layer.map_to_local(subcell)
##                   + FACE_CENTER_OFFSET[dir]
##                   + Vector2(0, -(storey * 4 + level) * SUBCUBE_STEP_PX)

const SUBCUBE_STEP_PX       := 40.0
const SUBCUBES_PER_AXIS     := 4       ## SubcubeCoords.SUBCUBES_PER_UNIT_AXIS

## Offset do centro do Sprite2D (centered=true, 64×72) relativo a map_to_local(subcell).
## Incorpora SUBCUBE_BASE_ORIGIN + SUBCUBE_FACE_OFFSETS. Não alterar sem calibração visual.
const FACE_CENTER_OFFSET: Dictionary = {
	"NW": Vector2(-16.0, -12.0),
	"NE": Vector2(-16.0, -28.0),
	"SE": Vector2( 16.0, -28.0),
	"SW": Vector2( 16.0, -12.0),
}

## Direção desta face (NW / NE / SE / SW).
var dir: String = ""


## Constrói os Sprite2D filhos para esta face.
##
## ref_layer   — qualquer TileMapLayer de subcubo ativo; usado apenas para map_to_local().
## atom_texture — PNG do átomo (subcube_concrete.png ou similar).
## face_subcells — os 4 subcells da aresta (Array[Vector2i], tamanho == SUBCUBES_PER_AXIS).
## wall_dir      — "NW" / "NE" / "SE" / "SW".
## storey        — índice do andar (0 = térreo).
func build(ref_layer: TileMapLayer, atom_texture: Texture2D,
		face_subcells: Array, wall_dir: String, storey: int) -> void:
	dir = wall_dir
	var center_off: Vector2 = FACE_CENTER_OFFSET.get(wall_dir, Vector2.ZERO)

	for level in SUBCUBES_PER_AXIS:
		var height_off := Vector2(0.0, -(storey * SUBCUBES_PER_AXIS + level) * SUBCUBE_STEP_PX)
		for sc: Vector2i in face_subcells:
			var sp := Sprite2D.new()
			sp.texture    = atom_texture
			sp.centered   = true

			## Posição no espaço local do nó pai (mesmo espaço que ref_layer).
			## ref_layer.position compensa offset do layer (VISUAL_GRID_OFFSET etc).
			sp.position = ref_layer.position + ref_layer.map_to_local(sc) \
						+ center_off + height_off

			## z_index para painter's algorithm isométrico:
			## maior (sc.x + sc.y) = mais próximo do viewer = desenhado por último.
			sp.z_index = sc.x + sc.y + level * 1000 + storey * 100_000

			add_child(sp)
```

---

### 4. Editar `room.gd`

#### 4a. Remover partes do WALL-EDGE-02 de `room.gd`

Localizar e **DELETAR**:

- A constante `SUBCUBE_CORNER_OFFSETS` (se presente).
- O bloco de registro de variantes de corner no tileset dentro de `_build_subcube_tileset()`
  (o bloco `for cdir in corner_dirs:` adicionado pelo WALL-EDGE-02).
- A função `_paint_corner_fill()` inteira.
- As 3 linhas de corner fill em `_render_subcube_geometry()`:
  ```gdscript
  var fills: Array = subcube_geometry.get("corner_fills", [])
  for fill: Dictionary in fills:
      _paint_corner_fill(fill, layer_count)
  ```

#### 4b. Adicionar variável de estado após as declarações de `_subcube_layers`

```gdscript
## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
## para faces de parede; blocos sólidos ainda usam TileMapLayer.
var _wall_containers: Array[WallContainer] = []
```

#### 4c. Modificar `_render_subcube_geometry()` — pular faces, delegar para Containers

**Localizar** o bloco que pinta as faces (dentro de `_render_subcube_geometry()`):

```gdscript
	var faces: Array = subcube_geometry.get("wall_faces", [])
	...
	for face: Dictionary in faces:
		_paint_subcube_descriptor(face, source_id, layer_count)
```

**Substituir por** (mantém blocos, pula faces):

```gdscript
	## Wall faces são renderizadas por WallContainers (ver _build_wall_containers).
	## Blocos sólidos continuam no TileMapLayer.
```

> O loop de `solid_blocks` permanece intacto. Apenas o loop de faces é removido.

#### 4d. Adicionar `_build_wall_containers()` após `_render_subcube_geometry()`

```gdscript
func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
		if is_instance_valid(wc):
			wc.queue_free()
	_wall_containers.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
	if faces.is_empty():
		return

	## Textura base dos átomos de parede.
	var atom_texture: Texture2D = load(
		"res://ASSETS/ISOMETRIC/source_assets/subcubes/subcube_concrete.png"
	)
	if atom_texture == null:
		push_warning("WallContainer: atom texture not found.")
		return

	## Usa o primeiro layer de subcubo como referência de mapa de coordenadas.
	if _subcube_layers.is_empty():
		push_warning("WallContainer: subcube layers not initialized.")
		return
	var ref_layer: TileMapLayer = _subcube_layers[0]

	for face: Dictionary in faces:
		var edge: Dictionary = face.get("edge", {})
		var from_cell: Vector2i = Vector2i(edge.get("from", Vector2i.ZERO))
		var to_cell:   Vector2i = Vector2i(edge.get("to",   Vector2i.ZERO))
		var edge_delta: Vector2i = to_cell - from_cell
		var storey: int = maxi(0, int(face.get("storey", 0)))

		## Converte edge_delta → sufixo direcional.
		var wall_dir: String = _edge_delta_to_dir(edge_delta)
		if wall_dir == "":
			continue

		## Obtém os 4 subcells da aresta (mesma lógica de _subcubes_on_edge).
		var face_subcells: Array[Vector2i] = _subcubes_on_edge(from_cell, edge_delta)
		if face_subcells.is_empty():
			continue

		## Cria e popula o WallContainer.
		var wc := WallContainer.new()
		wc.build(ref_layer, atom_texture, face_subcells, wall_dir, storey)
		add_child(wc)
		_wall_containers.append(wc)
```

#### 4e. Chamar `_build_wall_containers()` no fluxo de build da sala

**Localizar** o trecho onde `_render_subcube_geometry()` é chamado (dentro de `build_room()` ou equivalente):

```gdscript
		_render_subcube_geometry(subcube_geometry)
```

**Substituir por:**

```gdscript
		_render_subcube_geometry(subcube_geometry)   ## blocos sólidos (TileMapLayer)
		_build_wall_containers(subcube_geometry)     ## faces de parede (Containers)
```

---

## DO NOT TOUCH

- **`_subcubes_on_edge()`** — não muda; WallContainer reutiliza sua lógica via `_build_wall_containers`.
- **`_edge_delta_to_dir()`** — não muda; WallContainer usa o helper existente.
- **`_paint_subcube_descriptor()`** — não muda; continua sendo usado para blocos sólidos.
- **`_build_subcube_tileset()`** — remover apenas o bloco de corner do WALL-EDGE-02;
  variantes direcionais (NW/NE/SE/SW) de WALL-EDGE-01 permanecem (usadas por blocos futuros).
- **Floor layer, prop layers, structure layer** — intocados.
- **`subcube_geometry.gd`** — só o revert descrito; `_face()`, `_EDGE_BY_SUFFIX`, e
  o branch `wall_*` permanecem idênticos.
- **Nenhum outro arquivo** além dos quatro do MODULE.

---

## ACCEPTANCE

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural

```bash
## Cleanup confirmado: wallCorner ausente
grep -rn "wallCorner\|_CORNER_EDGES\|corner_fills\|_paint_corner_fill\|SUBCUBE_CORNER_OFFSETS" \
  godot/scripts/world/maps/subcube_geometry.gd \
  godot/scripts/world/maps/map_geometry.gd \
  godot/scripts/world/room.gd
# esperado: ZERO ocorrências

## WallContainer existe e tem build()
grep -n "class_name WallContainer\|func build" godot/scripts/world/wall_container.gd
# esperado: 2 linhas

## _build_wall_containers presente em room.gd
grep -n "_build_wall_containers\|_wall_containers" godot/scripts/world/room.gd
# esperado: 3+ ocorrências (declaração + definição + chamada)

## Blocos ainda usam TileMapLayer
grep -n "solid_blocks\|_paint_subcube_descriptor" godot/scripts/world/room.gd
# esperado: presente (blocos sólidos permanecem no TileMapLayer)
```

### Comportamento esperado no jogo

Ao rodar o PLAYGROUND ou SIGMA-01:

- **Paredes**: renderizadas por Sprite2D (WallContainers). Posição aproximadamente
  correta (pode precisar de ajuste fino de `FACE_CENTER_OFFSET` se visualmente
  deslocada — reportar o delta em pixels para calibração).
- **Corners**: dois WallContainers irmãos — sem overwrite, sem bug dos 3 subcubos.
  Cada face tem 4 subcubos completos visíveis.
- **Blocos sólidos** (divisórias, pilares): inalterados, ainda no TileMapLayer.
- **Floor**: inalterado.
- **Kenney wall tiles (legacy `_place()`)**: ainda são colocados nas wall layers
  (não afetados por este prompt). Podem criar dupla renderização visualmente —
  isso é aceito e será resolvido no CONTAINER-02.

> Se as paredes aparecerem em posição errada (offset uniforme em todas as direções),
> reportar: delta_x e delta_y observados vs. esperados. O ajuste é em
> `FACE_CENTER_OFFSET` em `wall_container.gd`.

---

**Escopo:** 4 arquivos · cleanup em 3 (revert ~30 linhas) · 1 novo (`wall_container.gd`
~55 linhas) · 3 edições em `room.gd` (remover + adicionar ~40 linhas) · 1 sessão.
**Próximo:** CONTAINER-02 — desativar legacy `_place()` para walls + Image composition
(PIL via Godot Image API) para reducer de 16 para 1 Sprite2D por Container.
