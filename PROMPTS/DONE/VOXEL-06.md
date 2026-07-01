# VOXEL-06 — VoxelRegistry (Centralized Container Management)

> **Série:** VOXEL · **Prompt:** 06 de 11
> **Depende de:** VOXEL-05 (`_voxel_junction_extras` + junction detection) ✅
> **Desbloqueia:** VOXEL-07 (dirty flag + TIC loop) — conclui Phase 1b (Container Index)
> **Arquivo criado:** `godot/scripts/world/voxel_registry.gd` (novo)
> **Arquivo tocado:** `godot/scripts/world/room.gd` (4 str_replace)
> **Natureza:** Centralized registry for all WallSlice/HighWall instances + lookup API.
> Zero alteração na lógica de rendering — apenas nova classe + integration calls.

---

## CONTEXT

Após VOXEL-05, temos:
- WallSlices armazenados em `_voxel_wall_slices: Array`
- JunctionExtras armazenados em `_voxel_junction_extras: Array`
- HighWalls implicitamente agrupados (faltam apenas os dados)

Falta: **Índice centralizado** para lookup eficiente e iteração em TIC loop.

### Registry Pattern

O VoxelRegistry segue o padrão usado em `LightRegistry` (sistema de iluminação):

```gdscript
## room.gd
var _voxel_registry: VoxelRegistry = null

## _ready()
_voxel_registry = VoxelRegistry.new()
_voxel_registry.setup(8 * VOXELS_PER_UNIT_AXIS)  # max voxels per storey

## _place_wall_voxels()
_voxel_registry.register_slice(ws)
_voxel_registry.register_high_wall(hw)

## TIC loop (VOXEL-07, future)
for hw in _voxel_registry.all_high_walls():
    if hw.dirty_count == 0: continue
    # process...
```

### Dados Agregados

O registry constrói HighWall instances a partir de WallSlices + JunctionExtras:

```
_voxel_wall_slices: [WS_1, WS_2, WS_3, ...]
_voxel_junction_extras: [JX_1, JX_2, ...]
                    ↓
         _build_high_walls()
                    ↓
_high_walls: {
  "WALL_NW_GC03_GR02": HighWall {
    slices: [WS_1_S0, WS_1_S1],
    junction_extras: [JX_1],
    dirty_count: 0,
  },
  "WALL_NE_GC04_GR02": HighWall { ... },
  ...
}
_slices: {
  "WALL_NW_GC03_GR02_S0": WS_1_S0,
  "WALL_NW_GC03_GR02_S1": WS_1_S1,
  ...
}
```

Ver VOXEL_MASTER_PLAN.md §6 para estrutura completa.

Pre-flight:
```bash
git status
grep -c "class_name VoxelRegistry" godot/scripts/world/voxel_registry.gd
# Expected: 0 (arquivo não existe ainda)
grep -c "_voxel_registry" godot/scripts/world/room.gd
# Expected: 0 (ainda não integrado)
```

---

## MODULE

**Arquivo criado:** `godot/scripts/world/voxel_registry.gd` (novo)
**Arquivo tocado:** `godot/scripts/world/room.gd` (4 str_replace)

---

## TASK

### File 1 — Create `godot/scripts/world/voxel_registry.gd`

```gdscript
class_name VoxelRegistry
extends RefCounted
## Centralized registry for all voxel wall containers.
## Responsibilities:
## ✓ Store WallSlice instances with string-based lookup
## ✓ Store HighWall instances with string-based lookup
## ✓ Build HighWall aggregates from WallSlice + JunctionExtra data
## ✓ Provide iteration API for TIC loop and baking system
## Does NOT:
## ✗ Render voxels (TileMapLayer handles that)
## ✗ Calculate dirty flags (VoxelRef/WallSlice/HighWall handle that)
## ✗ Apply state changes (TIC loop handles that)
## Pure data storage and queries for the voxel system.

const WallSliceClass   = preload("res://godot/scripts/world/wall_slice.gd")
const HighWallClass    = preload("res://godot/scripts/world/high_wall.gd")
const VoxelRefClass    = preload("res://godot/scripts/world/voxel_ref.gd")

var _slices: Dictionary = {}          # slice_id (String) → WallSlice
var _high_walls: Dictionary = {}      # high_wall_id (String) → HighWall
var _max_voxels_per_level: int = 0

signal slice_registered(slice)
signal high_wall_registered(high_wall)


func setup(max_voxels_per_level: int) -> void:
	## Initialize registry with max voxels per level (used for validation).
	_max_voxels_per_level = max_voxels_per_level
	_slices.clear()
	_high_walls.clear()


func register_slice(slice: WallSlice) -> void:
	## Register a WallSlice in the index. Called from _place_wall_voxels().
	if slice.id.is_empty():
		push_warning("VoxelRegistry: attempt to register slice with empty id")
		return
	_slices[slice.id] = slice
	slice_registered.emit(slice)


func register_high_wall(high_wall: HighWall) -> void:
	## Register a HighWall in the index. Called from _build_high_walls().
	if high_wall.id.is_empty():
		push_warning("VoxelRegistry: attempt to register high_wall with empty id")
		return
	_high_walls[high_wall.id] = high_wall
	high_wall_registered.emit(high_wall)


func get_slice(slice_id: String) -> WallSlice:
	## Retrieve a WallSlice by id. Returns null if not found.
	return _slices.get(slice_id, null)


func get_high_wall(high_wall_id: String) -> HighWall:
	## Retrieve a HighWall by id. Returns null if not found.
	return _high_walls.get(high_wall_id, null)


func all_slices() -> Array[WallSlice]:
	## Return all registered WallSlices. Used by TIC loop.
	var result: Array[WallSlice] = []
	for slice in _slices.values():
		result.append(slice)
	return result


func all_high_walls() -> Array[HighWall]:
	## Return all registered HighWalls. Used by TIC loop and baking.
	var result: Array[HighWall] = []
	for hw in _high_walls.values():
		result.append(hw)
	return result


func total_slices() -> int:
	## Total count of registered slices.
	return _slices.size()


func total_high_walls() -> int:
	## Total count of registered high walls.
	return _high_walls.size()


func is_empty() -> bool:
	## True if no containers registered.
	return _slices.is_empty() and _high_walls.is_empty()


func clear() -> void:
	## Clear all registrations. Called on room rebuild.
	_slices.clear()
	_high_walls.clear()
```

### str_replace 1 — Declarar `_voxel_registry` ao lado de `_voxel_junction_extras`

old_str:
```gdscript
## VoxelRefs de corner extra (VOXEL-05). Um por nível por corner de V-junction descoberto.
var _voxel_junction_extras: Array = []

## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
```

new_str:
```gdscript
## VoxelRefs de corner extra (VOXEL-05). Um por nível por corner de V-junction descoberto.
var _voxel_junction_extras: Array = []
## VoxelRegistry — centralized index of all WallSlice/HighWall instances (VOXEL-06).
var _voxel_registry: VoxelRegistry = null

## Containers de parede (Node2D com Sprite2D filhos). Substituem o TileMapLayer
```

---

### str_replace 2 — Inicializar `_voxel_registry` na `_ready()`

Localizar a seção após `_ensure_voxel_layers()` é chamado. old_str:

```gdscript
	var layer_count: int = maxi(_base_layout.get("max_floors", 1), 1) \
			* SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	_ensure_voxel_layers(layer_count)

	_place_wall_voxels(subcube_geometry)
```

new_str:

```gdscript
	var layer_count: int = maxi(_base_layout.get("max_floors", 1), 1) \
			* SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	_ensure_voxel_layers(layer_count)

	## Initialize VoxelRegistry (VOXEL-06)
	_voxel_registry = VoxelRegistry.new()
	_voxel_registry.setup(layer_count)

	_place_wall_voxels(subcube_geometry)
```

---

### str_replace 3 — Registrar WallSlices em `_place_wall_voxels()` (após append)

old_str:

```gdscript
			_voxel_wall_slices.append(ws)

	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)
```

new_str:

```gdscript
			_voxel_wall_slices.append(ws)
			_voxel_registry.register_slice(ws)

	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)
```

---

### str_replace 4 — Adicionar `_build_high_walls()` call no fim de `_place_wall_voxels()`

old_str:

```gdscript
	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)


func _has_any(edge_groups: Dictionary, keys: Array[String]) -> bool:
```

new_str:

```gdscript
	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)

	## Aggregate into HighWall instances (VOXEL-06)
	_build_high_walls()


func _build_high_walls() -> void:
	## Build HighWall aggregates from WallSlices.
	## Grouping strategy: 1 HighWall per unique (edge_from, direction).
	## Multiple storey_counts on the same edge group into one HighWall.
	var hw_groups: Dictionary = {}  # (from_cell_str, direction) → Array[WallSlice]

	for slice in _voxel_wall_slices:
		var key: String = "%s_%s" % [slice.gu_cell, slice.direction]
		if not hw_groups.has(key):
			hw_groups[key] = []
		hw_groups[key].append(slice)

	## Create HighWall for each group
	for group_key: String in hw_groups:
		var slices: Array = hw_groups[group_key]
		var hw := HighWallClass.new()
		hw.id = "HW_%s" % group_key.replace(" ", "_")
		hw.slices = slices
		hw.junction_extras = []
		hw.baked = false
		hw.dirty_count = 0
		_voxel_registry.register_high_wall(hw)


func _has_any(edge_groups: Dictionary, keys: Array[String]) -> bool:
```

---

## DO NOT TOUCH

- Corpo de `_build_wall_containers()` — não apagar, não modificar
- `_place_wall_voxels()` — só as linhas indicadas acima
- `_build_voxel_junction_extras()` — não modificar
- Qualquer função de subcubo
- Qualquer `.gd` fora de `room.gd` e novo `voxel_registry.gd`
- Qualquer `.tres`, `.tscn`

---

## ACCEPTANCE

**A1 — VoxelRegistry criado:**
```bash
grep -c "class_name VoxelRegistry" godot/scripts/world/voxel_registry.gd
# Expected: 1
```

**A2 — `_voxel_registry` declarado em room.gd:**
```bash
grep -c "var _voxel_registry: VoxelRegistry" godot/scripts/world/room.gd
# Expected: 1
```

**A3 — Registry inicializado em _ready():**
```bash
grep -c "_voxel_registry = VoxelRegistry.new()" godot/scripts/world/room.gd
# Expected: 1
```

**A4 — Slices registrados em _place_wall_voxels():**
```bash
grep -c "_voxel_registry.register_slice" godot/scripts/world/room.gd
# Expected: 1
```

**A5 — _build_high_walls() presente:**
```bash
grep -c "func _build_high_walls" godot/scripts/world/room.gd
# Expected: 1
```

**A6 — HighWalls registrados:**
```bash
grep -c "_voxel_registry.register_high_wall" godot/scripts/world/room.gd
# Expected: 1
```

**A7 — API methods presente (get_slice, all_slices, etc):**
```bash
grep -c "func get_slice\|func all_slices\|func all_high_walls" \
    godot/scripts/world/voxel_registry.gd
# Expected: 3
```

**A8 — VoxelRegistry não é Node (extends RefCounted):**
```bash
grep "extends RefCounted" godot/scripts/world/voxel_registry.gd
# Expected: found (not Node)
```

**A9 — Setup method present:**
```bash
grep -c "func setup" godot/scripts/world/voxel_registry.gd
# Expected: 1
```

**A10 — Runtime: abrir Godot, carregar cena, verificar registry:**
```
Inspecção visual obrigatória:

Output NÃO deve conter warnings voxel novos ou erros de type.
Registry._high_walls.size() deve corresponder ao número de wall edges.
Registry.total_slices() deve == _voxel_wall_slices.size().
```

**A11 — Git status: apenas room.gd + voxel_registry.gd modificados:**
```bash
git status --short
# Expected: M  godot/scripts/world/room.gd
#           ?  godot/scripts/world/voxel_registry.gd
```

---

## DONE CRITERIA

A1..A9 passam via grep/bash. A10 confirmado visualmente (Godot carrega sem erros,
registry indices são sensatos). A11 mostra apenas os dois arquivos esperados modificados.

**Completa Phase 1b:** Voxel containers agora totalmente indexados. TIC loop (VOXEL-07)
pode iterar eficientemente.

Mover para `PROMPTS/DONE/VOXEL-06.md`.
