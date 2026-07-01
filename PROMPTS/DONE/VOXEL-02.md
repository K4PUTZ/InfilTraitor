# VOXEL-02 — Constantes Voxel + Infraestrutura de TileSet em `room.gd`

> **Série:** VOXEL · **Prompt:** 02 de 11
> **Depende de:** VOXEL-01 (4 PNGs em `source_assets/voxels/`) ✅
> **Desbloqueia:** VOXEL-03 (data classes VoxelRef / WallSlice / HighWall)
> **Arquivos tocados:** `subcube_coords.gd` · `room.gd` (5 str_replace, 0 delete)
> **Natureza:** infraestrutura paralela ao subcubo — o sistema subcubo existente é
> preservado integralmente. Nenhuma renderização nova é activada neste prompt.

---

## CONTEXT

VOXEL-01 gerou os 4 atoms PNG (32×36 px). Este prompt:

1. Acrescenta as constantes de coordenadas voxel a `subcube_coords.gd`
   (`VOXELS_PER_UNIT_AXIS`, `VOXEL_TILE_SIZE`, funções de conversão GU↔Voxel).

2. Acrescenta a constante de renderização `VOXEL_STEP_PX = 20.0` a `room.gd`
   (paralela a `SUBCUBE_STEP_PX = 40.0`).

3. Declara as três variáveis de estado voxel em `room.gd`
   (`_voxel_tileset`, `_voxel_layers`, `_voxel_tile_ids`).

4. Adiciona `_build_voxel_tileset()` — constrói o TileSet em runtime, sem offset
   empírico. Chamado em `_ready()` logo após `_build_subcube_tileset()`. Falha
   graciosamente (`null`) se os PNGs não existirem.

5. Adiciona `_ensure_voxel_layers(count)` — cria TileMapLayers paralelos a
   `_ensure_subcube_layers`, usando `VOXEL_STEP_PX`. Ainda não é chamado por nenhum
   caminho de renderização (isso vem em VOXEL-04).

Ao final, `room._ready()` constrói o tileset voxel silenciosamente. A cena continua
a funcionar identicamente — nenhuma parede voxel é renderizada ainda.

Referências:
- `docs/technical/VOXEL_MASTER_PLAN.md` §3, §11
- `tools/persistent/OPERATOR_CONTEXT.md` → "Voxel Asset Pipeline" e Rule 8

Pre-flight:
```bash
git status          # deve estar limpo
python3 -c "from PIL import Image; Image.open('ASSETS/ISOMETRIC/source_assets/voxels/voxel_concrete.png'); print('PNGs OK')"
```

---

## MODULE

- `godot/scripts/world/subcube_coords.gd` — adicionar bloco voxel **no final**
- `godot/scripts/world/room.gd` — 4 str_replace cirúrgicos

---

## TASK

### 1 — `subcube_coords.gd`: acrescentar bloco Voxel no final do arquivo

**str_replace** — âncora: última linha do ficheiro (o `return out` final).

old_str:
```gdscript
## Os 16 subcubos de uma unit, em ordem de varredura (y exterior, x interior).
static func unit_subcubes(unit: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []
	for j in SUBCUBES_PER_UNIT_AXIS:
		for i in SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out
```

new_str:
```gdscript
## Os 16 subcubos de uma unit, em ordem de varredura (y exterior, x interior).
static func unit_subcubes(unit: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []
	for j in SUBCUBES_PER_UNIT_AXIS:
		for i in SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out


## ── Voxel plane (VOXEL series) ────────────────────────────────────────────────
## 8×8 voxels por Gameplay Unit (eixo horizontal). API espelha o bloco subcubo
## acima; conversões são floor-division negativa-seguras (floori / posmod).

## Razão linear HORIZONTAL: 1 Gameplay Unit = 8×8 Voxels no piso.
## Distinto de VOXEL_STEP_PX (vertical, em room.gd).
const VOXELS_PER_UNIT_AXIS: int = 8

## tile_size do TileSet de voxels — deve coincidir com generate_voxel.py TILE_W / TILE_H.
const VOXEL_TILE_SIZE: Vector2i = Vector2i(32, 16)

## Origem (canto NW) do bloco 8×8 de voxels de uma Gameplay Unit.
static func gu_to_voxel_origin(gu: Vector2i) -> Vector2i:
	return gu * VOXELS_PER_UNIT_AXIS

## Gameplay Unit a que um voxel pertence. Floor-division negativa-segura.
static func voxel_to_gu(v: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(v.x) / VOXELS_PER_UNIT_AXIS),
		floori(float(v.y) / VOXELS_PER_UNIT_AXIS),
	)

## Offset local do voxel dentro da sua Gameplay Unit. Sempre em 0..7 (negativa-seguro).
static func voxel_local(v: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(v.x, VOXELS_PER_UNIT_AXIS),
		posmod(v.y, VOXELS_PER_UNIT_AXIS),
	)

## Os 64 voxels de uma Gameplay Unit, em ordem de varredura (y exterior, x interior).
static func gu_voxels(gu: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = gu_to_voxel_origin(gu)
	var out: Array[Vector2i] = []
	for j in VOXELS_PER_UNIT_AXIS:
		for i in VOXELS_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out
```

---

### 2 — `room.gd` str_replace 1: acrescentar `VOXEL_STEP_PX` após `SUBCUBE_FACE_OFFSETS`

old_str:
```gdscript
	"SW": Vector2i( 16,  8),   ## baixo-esquerda: edge_delta (0,+1)
}

var _subcube_tileset: TileSet = null
```

new_str:
```gdscript
	"SW": Vector2i( 16,  8),   ## baixo-esquerda: edge_delta (0,+1)
}

## Voxel render plane (VOXEL series): 1 storey = 8 voxel rows, each steps 20 px.
## 20 = 1.25 × VOXEL_TILE_SIZE.y (16). Must match generate_voxel.py SIDE_H.
## Invariant: 8 × VOXEL_STEP_PX (160) == 4 × SUBCUBE_STEP_PX (160). ✓
const VOXEL_STEP_PX: float = 20.0

var _subcube_tileset: TileSet = null
```

---

### 3 — `room.gd` str_replace 2: declarar variáveis de estado voxel

old_str:
```gdscript
var _subcube_tileset: TileSet = null
var _subcube_layers: Array[TileMapLayer] = []
var _subcube_tile_ids: Dictionary = {}

## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
```

new_str:
```gdscript
var _subcube_tileset: TileSet = null
var _subcube_layers: Array[TileMapLayer] = []
var _subcube_tile_ids: Dictionary = {}

## Voxel render plane (VOXEL-02). TileSet separado (tile_size 32×16), sem offsets empíricos.
var _voxel_tileset: TileSet = null
var _voxel_layers: Array[TileMapLayer] = []
var _voxel_tile_ids: Dictionary = {}

## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
```

---

### 4 — `room.gd` str_replace 3: chamar `_build_voxel_tileset()` em `_ready()`

old_str:
```gdscript
	_subcube_tileset = _build_subcube_tileset()
	
	var graph: LevelGraph = LevelGraphClass.new()
```

new_str:
```gdscript
	_subcube_tileset = _build_subcube_tileset()
	_voxel_tileset   = _build_voxel_tileset()    ## VOXEL-02: null-safe if PNGs missing

	var graph: LevelGraph = LevelGraphClass.new()
```

---

### 5 — `room.gd` str_replace 4: inserir as duas funções voxel após `_ensure_subcube_layers`

old_str:
```gdscript
	for i in range(_subcube_layers.size()):
		_subcube_layers[i].visible = i < count


func _render_subcube_geometry(subcube_geometry: Dictionary, max_floors: int) -> void:
```

new_str:
```gdscript
	for i in range(_subcube_layers.size()):
		_subcube_layers[i].visible = i < count


## ── Voxel render plane (VOXEL series) ────────────────────────────────────────

func _build_voxel_tileset() -> TileSet:
	## Builds the voxel TileSet at runtime from source_assets/voxels/*.png.
	## tile_size = 32×16, texture_origin = (0,0) — no empirical offset needed.
	## One source per material, no directional variants.
	## Returns null (with push_warning) if any PNG is missing; safe to call always.
	var ts := TileSet.new()
	ts.tile_shape  = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size   = Vector2i(32, 16)

	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var source_id: int = 0
	var materials: Array[String] = ["concrete", "metal", "stone", "wood"]

	for mat in materials:
		var path     := "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png" % mat
		var texture: Texture2D = load(path)
		if texture == null:
			push_warning("Room._build_voxel_tileset: missing %s — run VOXEL-01 first." % path)
			continue

		var src := TileSetAtlasSource.new()
		src.texture             = texture
		src.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, source_id)

		var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
		if td != null:
			td.texture_origin = Vector2i(0, 0)              ## analytically correct — no calibration
			td.set_custom_data("tile_name", "voxel_%s" % mat)

		_voxel_tile_ids["voxel_%s" % mat] = source_id
		source_id += 1

	if source_id == 0:
		push_warning("Room._build_voxel_tileset: no voxel textures loaded.")
		return null
	return ts


func _ensure_voxel_layers(count: int) -> void:
	## Creates TileMapLayers for the voxel render plane, one per vertical level.
	## Layer k: position.y = VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX × k
	##          z_index    = WALL_BASE_Z_INDEX + k
	## Parallel to _ensure_subcube_layers but uses VOXEL_STEP_PX (20) instead of 40.
	if _voxel_tileset == null:
		return
	while _voxel_layers.size() < count:
		var level := _voxel_layers.size()
		var layer := TileMapLayer.new()
		layer.tile_set     = _voxel_tileset
		layer.y_sort_origin = 1
		layer.position     = Vector2(
				VISUAL_GRID_OFFSET.x,
				VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX * float(level))
		layer.z_index      = WALL_BASE_Z_INDEX + level
		add_child(layer)
		_voxel_layers.append(layer)
	for i in range(_voxel_layers.size()):
		_voxel_layers[i].visible = i < count


func _render_subcube_geometry(subcube_geometry: Dictionary, max_floors: int) -> void:
```

---

## DO NOT TOUCH

- `_subcube_tileset`, `_subcube_layers`, `_subcube_tile_ids` — preservar integralmente
- `_build_subcube_tileset()` — não modificar
- `_ensure_subcube_layers()` — não modificar
- `_render_subcube_geometry()` — não modificar
- `_build_wall_containers()` — não modificar
- `SUBCUBE_STEP_PX`, `SUBCUBE_BASE_ORIGIN`, `SUBCUBE_FACE_OFFSETS` — preservar
- As funções de subcubo em `subcube_coords.gd` (`unit_to_subcube_origin`, etc.)
- Qualquer `.tscn`, `.tres`, `map_compiler.gd`, `subcube_geometry.gd`

---

## ACCEPTANCE

**A1 — Constantes voxel em `subcube_coords.gd`:**
```bash
grep -cE "VOXELS_PER_UNIT_AXIS\s*:\s*int\s*=\s*8|VOXEL_TILE_SIZE\s*:.*=\s*Vector2i\(32,\s*16\)" \
    godot/scripts/world/subcube_coords.gd
# Expected: 2
```

**A2 — Funções voxel existem em `subcube_coords.gd`:**
```bash
grep -c "gu_to_voxel_origin\|voxel_to_gu\|voxel_local\|gu_voxels" \
    godot/scripts/world/subcube_coords.gd
# Expected: 4
```

**A3 — Funções subcubo originais intactas (invariante):**
```bash
grep -c "unit_to_subcube_origin\|subcube_to_unit\|subcube_local\|subcube_at\|unit_subcubes" \
    godot/scripts/world/subcube_coords.gd
# Expected: 5
```

**A4 — `VOXEL_STEP_PX` declarado em `room.gd`:**
```bash
grep -E "const VOXEL_STEP_PX\s*:\s*float\s*=\s*20\.0" godot/scripts/world/room.gd
# Expected: 1 match
```

**A5 — Três variáveis voxel declaradas em `room.gd`:**
```bash
grep -c "_voxel_tileset\|_voxel_layers\|_voxel_tile_ids" godot/scripts/world/room.gd
# Expected: ≥ 6  (declaração + uso em funções)
```

**A6 — Funções voxel existem em `room.gd`:**
```bash
grep -c "func _build_voxel_tileset\|func _ensure_voxel_layers" \
    godot/scripts/world/room.gd
# Expected: 2
```

**A7 — Chamada em `_ready()` presente:**
```bash
grep -n "_voxel_tileset.*_build_voxel_tileset" godot/scripts/world/room.gd
# Expected: 1 linha, próxima de _build_subcube_tileset
```

**A8 — Sistema subcubo preservado (invariante):**
```bash
grep -cE "SUBCUBE_STEP_PX|SUBCUBE_BASE_ORIGIN|SUBCUBE_FACE_OFFSETS|_build_subcube_tileset|_ensure_subcube_layers" \
    godot/scripts/world/room.gd
# Expected: ≥ 8  (constantes + chamadas — não deve ter reduzido)
```

**A9 — `tile_size 32×16` e `texture_origin (0,0)` presentes em `_build_voxel_tileset`:**
```bash
grep -E "Vector2i\(32,\s*16\)|texture_origin\s*=\s*Vector2i\(0,\s*0\)" \
    godot/scripts/world/room.gd
# Expected: ≥ 2 matches
```

**A10 — Runtime: abrir Godot, recarregar cena, verificar Output:**
```
Godot Output não deve conter:
  "Room._build_voxel_tileset: missing"
  "Room._build_voxel_tileset: no voxel textures loaded"

Deve conter (ou silêncio — sem warnings voxel):
  [Normal boot sequence sem erros novos]
```

Verificar via `print(_voxel_tileset != null)` temporário em `_ready()` se necessário.
Remover qualquer print de debug antes de commitar.

**A11 — Git status: apenas 2 ficheiros modificados:**
```bash
git status --short
# Expected:
#  M godot/scripts/world/room.gd
#  M godot/scripts/world/subcube_coords.gd
# (+ .uid files se o Godot os regenerar — aceitável)
```

---

## DONE CRITERIA

A1..A9 passam via grep. A10 confirmado manualmente no Godot (sem warnings voxel).
A11 mostra apenas os 2 ficheiros esperados modificados.
Mover para `PROMPTS/DONE/VOXEL-02.md`.
