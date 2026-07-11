# VOXEL-04 — `_place_wall_voxels()`: Placement Básico de Paredes

> **Série:** VOXEL · **Prompt:** 04 de 11
> **Depende de:** VOXEL-03 (data classes VoxelRef / WallSlice / HighWall) ✅
> **Desbloqueia:** VOXEL-05 (junction detection + extra voxel)
> **Arquivo tocado:** `godot/scripts/world/room.gd` (3 str_replace)
> **Natureza:** substituição da chamada a `_build_wall_containers()` por
> `_place_wall_voxels()`. Walls são renderizadas via `set_cell()` puro.
> Sem junctions ainda — isso vem em VOXEL-05.

---

## CONTEXT

Até agora: o tileset voxel está construído (`_voxel_tileset`), as layers existem
(`_ensure_voxel_layers`), e as data classes estão definidas (`VoxelRef`, `WallSlice`).

Este prompt adiciona a função que efetivamente renderiza paredes:
`_place_wall_voxels(subcube_geometry)`.

Ela lê `subcube_geometry["wall_faces"]` — o mesmo array que `_build_wall_containers()`
consumia — e para cada aresta de GAME UNIT:
1. Agrupa por edge key para obter `storey_count` (multi-storey support)
2. Calcula as 8 posições voxel de cada um dos 2 slices (S0 inner + S1 outer)
3. Chama `set_cell()` em `_voxel_layers[level]` para cada (posição, nível)
4. Cria instâncias `WallSlice` + `VoxelRef` e acumula em `_voxel_wall_slices`

`_build_wall_containers()` **deixa de ser chamada** mas **permanece no código** —
não apagar. VOXEL-05 adiciona junction extras; VOXEL-06 constrói o registry.

Referências:
- `docs/technical/VOXEL_MASTER_PLAN.md` §5 (Wall Construction)
- `tools/persistent/OPERATOR_CONTEXT.md` → Rule 8 (set_cell only)
- `DIRECTION_GLOSSARY.md` §3 e §5 (NW/NE/SE/SW + slice positions)

Pre-flight:
```bash
git status
grep -c "func _ensure_voxel_layers" godot/scripts/world/room.gd
# Expected: 1  (VOXEL-02 foi aplicado)
grep -c "^class_name WallSlice" godot/scripts/world/wall_slice.gd
# Expected: 1  (VOXEL-03 foi aplicado)
```

---

## MODULE

**Único arquivo tocado:** `godot/scripts/world/room.gd`

---

## TASK

### str_replace 1 — Acrescentar `_voxel_wall_slices` ao bloco de vars voxel

old_str:
```gdscript
## Voxel render plane (VOXEL-02). TileSet separado (tile_size 32×16), sem offsets empíricos.
var _voxel_tileset: TileSet = null
var _voxel_layers: Array[TileMapLayer] = []
var _voxel_tile_ids: Dictionary = {}
```

new_str:
```gdscript
## Voxel render plane (VOXEL-02). TileSet separado (tile_size 32×16), sem offsets empíricos.
var _voxel_tileset: TileSet = null
var _voxel_layers: Array[TileMapLayer] = []
var _voxel_tile_ids: Dictionary = {}
## Slices de parede voxel actuais (VOXEL-04). Indexados pelo VoxelRegistry em VOXEL-06.
var _voxel_wall_slices: Array = []
```

---

### str_replace 2 — Substituir chamada a `_build_wall_containers` por `_place_wall_voxels`

old_str:
```gdscript
		_render_subcube_geometry(subcube_geometry, max_floors)   ## blocos sólidos (TileMapLayer)
		_build_wall_containers(subcube_geometry)     ## faces de parede (Containers)
		structure_wall_layer.visible = false
```

new_str:
```gdscript
		_render_subcube_geometry(subcube_geometry, max_floors)   ## blocos sólidos (TileMapLayer)
		_place_wall_voxels(subcube_geometry)                     ## VOXEL-04: faces de parede (voxels)
		structure_wall_layer.visible = false
```

---

### str_replace 3 — Inserir as duas funções voxel antes de `_build_wall_containers`

old_str:
```gdscript
func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
```

new_str:
```gdscript
## ── Voxel wall placement (VOXEL-04) ──────────────────────────────────────────

func _voxel_slice_positions(from_cell: Vector2i, edge_delta: Vector2i,
		slice_index: int) -> Array[Vector2i]:
	## Retorna as 8 posições voxel para um slice de uma aresta de parede.
	## slice_index 0 = inner (no from_cell), 1 = outer (no to_cell adjacente).
	## Usa VOXELS_PER_UNIT_AXIS (= 8) de SubcubeCoordsClass.
	## Ver VOXEL_MASTER_PLAN.md §5 e DIRECTION_GLOSSARY.md §5 para geometria.
	var positions: Array[Vector2i] = []
	var to_cell: Vector2i = from_cell + edge_delta
	var vpu: int = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS  ## 8

	match edge_delta:
		Vector2i(-1, 0):   ## NW: col fixo, j varia em from_cell ou to_cell
			var col: int = (from_cell.x * vpu) if slice_index == 0 \
					else (to_cell.x * vpu + vpu - 1)
			for j in vpu:
				positions.append(Vector2i(col, from_cell.y * vpu + j))

		Vector2i(0, -1):   ## NE: row fixo, i varia
			var row: int = (from_cell.y * vpu) if slice_index == 0 \
					else (to_cell.y * vpu + vpu - 1)
			for i in vpu:
				positions.append(Vector2i(from_cell.x * vpu + i, row))

		Vector2i(1, 0):    ## SE: col fixo (extremidade oposta a NW)
			var col: int = (from_cell.x * vpu + vpu - 1) if slice_index == 0 \
					else (to_cell.x * vpu)
			for j in vpu:
				positions.append(Vector2i(col, from_cell.y * vpu + j))

		Vector2i(0, 1):    ## SW: row fixo (extremidade oposta a NE)
			var row: int = (from_cell.y * vpu + vpu - 1) if slice_index == 0 \
					else (to_cell.y * vpu)
			for i in vpu:
				positions.append(Vector2i(from_cell.x * vpu + i, row))

	return positions


func _place_wall_voxels(subcube_geometry: Dictionary) -> void:
	## Renderiza arestas de parede como tiles voxel via set_cell() em _voxel_layers[].
	## Substitui _build_wall_containers() (arquivada — NÃO apagar).
	## Sem junction extras ainda — vem em VOXEL-05.
	## Cria WallSlice + VoxelRef; acumula em _voxel_wall_slices.
	if _voxel_tileset == null:
		push_warning("_place_wall_voxels: _voxel_tileset null — correr VOXEL-01/02 primeiro.")
		return

	## Limpar estado anterior
	for layer in _voxel_layers:
		layer.clear()
	_voxel_wall_slices.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
	if faces.is_empty():
		return

	## Agrupar faces por edge key para obter max_storey por aresta
	var edge_groups: Dictionary = {}
	for face: Dictionary in faces:
		var edge: Dictionary     = face.get("edge", {})
		var from_cell: Vector2i  = Vector2i(edge.get("from", Vector2i.ZERO))
		var to_cell:   Vector2i  = Vector2i(edge.get("to",   Vector2i.ZERO))
		var edge_delta: Vector2i = to_cell - from_cell
		var storey: int          = maxi(0, int(face.get("storey", 0)))
		var key: String = "%d,%d,%d,%d" % [from_cell.x, from_cell.y,
				edge_delta.x, edge_delta.y]
		if not edge_groups.has(key):
			edge_groups[key] = {"from": from_cell, "delta": edge_delta,
					"max_storey": storey}
		else:
			edge_groups[key]["max_storey"] = maxi(
					edge_groups[key]["max_storey"], storey)

	## Colocar voxels: 2 slices por aresta (S0 inner + S1 outer)
	var vpu: int       = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
	if source_id < 0:
		push_warning("_place_wall_voxels: 'voxel_concrete' não encontrado no tileset.")
		return
	var tile_coord := Vector2i(0, 0)

	for key: String in edge_groups:
		var grp: Dictionary      = edge_groups[key]
		var from_cell: Vector2i  = Vector2i(grp["from"])
		var edge_delta: Vector2i = Vector2i(grp["delta"])
		var storey_count: int    = int(grp["max_storey"]) + 1
		var layer_count: int     = storey_count * vpu
		var wall_dir: String     = _edge_delta_to_dir(edge_delta)
		if wall_dir.is_empty():
			continue
		_ensure_voxel_layers(layer_count)

		for si in 2:   ## 0 = inner (S0), 1 = outer (S1)
			var positions: Array[Vector2i] = \
					_voxel_slice_positions(from_cell, edge_delta, si)

			## Colocar tiles em todas as layers verticais
			for level in layer_count:
				for pos in positions:
					_voxel_layers[level].set_cell(pos, source_id, tile_coord)

			## Criar WallSlice + VoxelRefs (ordem posição-maior para o BakeSystem)
			var ws := WallSlice.new()
			ws.id           = "%s_%s_S%d" % [key, wall_dir, si]
			ws.direction    = wall_dir
			ws.slice_index  = si
			ws.gu_cell      = from_cell
			ws.storey_count = storey_count
			for pos in positions:
				for level in layer_count:
					ws.voxels.append(VoxelRef.new(pos, level))
			_voxel_wall_slices.append(ws)


func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
```

---

## DO NOT TOUCH

- O corpo de `_build_wall_containers()` — não apagar, não modificar
- `_render_subcube_geometry()` — não modificar
- `_build_subcube_tileset()`, `_ensure_subcube_layers()` — não modificar
- `SUBCUBE_STEP_PX`, `SUBCUBE_BASE_ORIGIN`, `SUBCUBE_FACE_OFFSETS` — não modificar
- `_subcube_tileset`, `_subcube_layers`, `_subcube_tile_ids` — não modificar
- Qualquer `.gd` fora de `room.gd`
- Qualquer `.tres`, `.tscn`

---

## ACCEPTANCE

**A1 — `_voxel_wall_slices` declarado:**
```bash
grep -c "var _voxel_wall_slices" godot/scripts/world/room.gd
# Expected: 1
```

**A2 — Funções voxel presentes:**
```bash
grep -c "func _place_wall_voxels\|func _voxel_slice_positions" \
    godot/scripts/world/room.gd
# Expected: 2
```

**A3 — `_build_wall_containers` não é mais chamada (apenas definida):**
```bash
grep -n "_build_wall_containers" godot/scripts/world/room.gd
# Expected: apenas a linha "func _build_wall_containers..." — zero chamadas activas
# A única ocorrência que NÃO é a definição deve ter desaparecido (era linha ~1878)
```

**A4 — `_place_wall_voxels` é chamada no `_build_room()` path:**
```bash
grep -n "_place_wall_voxels" godot/scripts/world/room.gd
# Expected: ≥ 2 linhas — a definição e pelo menos 1 chamada
```

**A5 — `set_cell` usado em `_place_wall_voxels` (Rule 8):**
```bash
grep -A 60 "func _place_wall_voxels" godot/scripts/world/room.gd | \
    grep "set_cell"
# Expected: ≥ 1 linha com set_cell
```

**A6 — Sem `blend_rect` ou `FACE_CENTER_OFFSET` na função nova:**
```bash
grep -A 80 "func _place_wall_voxels" godot/scripts/world/room.gd | \
    grep -Ec "blend_rect|FACE_CENTER_OFFSET|Image\.load|atom_image"
# Expected: 0
```

**A7 — `WallSlice.new()` e `VoxelRef.new()` usados na função:**
```bash
grep -A 80 "func _place_wall_voxels" godot/scripts/world/room.gd | \
    grep -c "WallSlice.new()\|VoxelRef.new("
# Expected: 2
```

**A8 — `_voxel_slice_positions`: 4 cases cobertos (NW, NE, SE, SW):**
```bash
grep -A 40 "func _voxel_slice_positions" godot/scripts/world/room.gd | \
    grep -c "Vector2i(-1, 0)\|Vector2i(0, -1)\|Vector2i(1, 0)\|Vector2i(0, 1)"
# Expected: 4
```

**A9 — Sistema subcubo preservado:**
```bash
grep -c "func _build_wall_containers\|func _build_subcube_tileset\|func _ensure_subcube_layers" \
    godot/scripts/world/room.gd
# Expected: 3  (todas as três funções ainda existem)
```

**A10 — Runtime: abrir Godot, carregar cena, verificar:**
```
Output NÃO deve conter:
  "_place_wall_voxels: _voxel_tileset null"
  "_place_wall_voxels: 'voxel_concrete' não encontrado"

Visual esperado:
  • Paredes cinzentas/concreto (32×16 voxels) visíveis na cena
  • Sem V/T/X junction gaps corrigidos — normal (vem em VOXEL-05)
  • Floor e estruturas (blocos sólidos) continuam normais
```

**A11 — Git status: apenas `room.gd` modificado:**
```bash
git status --short
# Expected:
#  M godot/scripts/world/room.gd
# (+ .uid se Godot regenerar — aceitável)
```

---

## DONE CRITERIA

A1..A9 passam via grep/bash. A10 confirmado visualmente no Godot.
A11 mostra apenas `room.gd` modificado.
Mover para `PROMPTS/DONE/VOXEL-04.md`.
