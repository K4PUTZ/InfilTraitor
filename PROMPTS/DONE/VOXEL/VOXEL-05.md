# VOXEL-05 — Junction Detection + Extra Voxel Column

> **Série:** VOXEL · **Prompt:** 05 de 11
> **Depende de:** VOXEL-04 (`_place_wall_voxels` a funcionar) ✅
> **Desbloqueia:** VOXEL-06 (VoxelRegistry) — conclui a Phase 1 (Core Rendering)
> **Arquivo tocado:** `godot/scripts/world/room.gd` (3 str_replace)
> **Natureza:** detecção de junções V/T/X e preenchimento de corners descobertos.
> Zero alteração na lógica de rendering existente — apenas novas funções + calls.

---

## CONTEXT

Após VOXEL-04, os 2 slices básicos de cada aresta são colocados correctamente.
Falta preencher os **corners de junção descobertos** (V-junction gap).

### Geometria dos Corners

Em cada vértice `(vx, vy)` do grid de GAME UNITs existem 4 possíveis arestas de
parede, cada uma checável por **2 chaves** (a aresta pode ser gerada pelo mapa de
qualquer um dos dois lados adjacentes):

```
eA: entre GU(vx,vy) e GU(vx,vy-1)   →  keys ["vx,vy,0,-1"   ,  "vx,vy-1,0,1"  ]
eB: entre GU(vx,vy) e GU(vx-1,vy)   →  keys ["vx,vy,-1,0"   ,  "vx-1,vy,1,0"  ]
eC: entre GU(vx-1,vy) e GU(vx-1,vy-1) → keys ["vx-1,vy,0,-1" ,  "vx-1,vy-1,0,1"]
eD: entre GU(vx,vy-1) e GU(vx-1,vy-1) → keys ["vx,vy-1,-1,0" ,  "vx-1,vy-1,1,0"]
```

Cada aresta cobre 2 dos 4 corners diagonais deste vértice. Um corner está
**descoberto** se as suas 2 arestas cobertas estiverem **ambas ausentes**:

```
Corner  │ Posição voxel absoluta          │ Coberto por
────────┼─────────────────────────────────┼────────────────────
GU_TL   │ ((vx-1)*8+7, (vy-1)*8+7)        │ eC ou eD
GU_BR   │ (vx*8,       vy*8)              │ eA ou eB
GU_BL   │ ((vx-1)*8+7, vy*8)             │ eB ou eC
GU_TR   │ (vx*8,       (vy-1)*8+7)        │ eA ou eD
```

**Regra:** corner descoberto + pelo menos 1 aresta presente no vértice
→ colocar 1 coluna de voxel extra. Sem corner descoberto → não colocar nada.

**Exemplos verificados:**
- V junction L-shape (eA+eB apenas): GU_TL descoberto → 1 extra ✓
- Parede recta (eB+eD apenas): todos cobertos → 0 extras ✓
- T junction (eA+eB+eC): todos cobertos → 0 extras ✓
- X junction (eA+eB+eC+eD): todos cobertos → 0 extras ✓

### Cálculo de Vértices

Cada aresta toca exactamente 2 vértices do grid. Fórmula correcta por delta:

```
delta=(-1,0) [NW]: v1=from_cell,           v2=from_cell+(0,1)
delta=(1,0)  [SE]: v1=from_cell+(1,0),     v2=from_cell+(1,1)
delta=(0,-1) [NE]: v1=from_cell,           v2=from_cell+(1,0)
delta=(0,1)  [SW]: v1=from_cell+(0,1),     v2=from_cell+(1,1)
```

Referências:
- `docs/technical/VOXEL_MASTER_PLAN.md` §5 (Junction Rules)
- `tools/persistent/OPERATOR_CONTEXT.md` → Rule 8

Pre-flight:
```bash
git status
grep -c "func _place_wall_voxels" godot/scripts/world/room.gd
# Expected: 1  (VOXEL-04 foi aplicado)
grep -c "func _add_junction_extra" godot/scripts/world/room.gd
# Expected: 0  (ainda não existe — este prompt cria)
```

---

## MODULE

**Único arquivo tocado:** `godot/scripts/world/room.gd`

---

## TASK

### str_replace 1 — Declarar `_voxel_junction_extras` ao lado de `_voxel_wall_slices`

old_str:
```gdscript
## Slices de parede voxel actuais (VOXEL-04). Indexados pelo VoxelRegistry em VOXEL-06.
var _voxel_wall_slices: Array = []
```

new_str:
```gdscript
## Slices de parede voxel actuais (VOXEL-04). Indexados pelo VoxelRegistry em VOXEL-06.
var _voxel_wall_slices: Array = []
## VoxelRefs de corner extra (VOXEL-05). Um por nível por corner de V-junction descoberto.
var _voxel_junction_extras: Array = []
```

---

### str_replace 2 — Acrescentar clear de `_voxel_junction_extras` no bloco de limpeza

old_str:
```gdscript
	## Limpar estado anterior
	for layer in _voxel_layers:
		layer.clear()
	_voxel_wall_slices.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
```

new_str:
```gdscript
	## Limpar estado anterior
	for layer in _voxel_layers:
		layer.clear()
	_voxel_wall_slices.clear()
	_voxel_junction_extras.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
```

---

### str_replace 3 — Adicionar chamada de junção no fim de `_place_wall_voxels` e inserir 4 funções novas antes de `_build_wall_containers`

old_str:
```gdscript
			_voxel_wall_slices.append(ws)


func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
```

new_str:
```gdscript
			_voxel_wall_slices.append(ws)

	## Corner extras: preencher corners de V-junction descobertos
	_build_voxel_junction_extras(edge_groups)


func _build_voxel_junction_extras(edge_groups: Dictionary) -> void:
	## Detecta corners de vértice não cobertos por nenhum outer slice e coloca
	## uma coluna extra de voxel. Um corner está descoberto quando as suas 2 arestas
	## cobertas estão AMBAS ausentes do edge_groups.
	## Dual-key: cada aresta física pode ser representada por qualquer dos 2 lados.
	## Ver VOXEL_MASTER_PLAN.md §5 e DIRECTION_GLOSSARY.md §5.
	if _voxel_tileset == null:
		return
	var source_id: int = _voxel_tile_ids.get("voxel_concrete", -1)
	if source_id < 0:
		return
	var tile_coord := Vector2i(0, 0)
	var vpu: int = SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS   ## 8

	## Recolher todos os vértices tocados por arestas presentes
	var vertices: Dictionary = {}
	for key: String in edge_groups:
		var from_cell: Vector2i = Vector2i(edge_groups[key]["from"])
		var delta: Vector2i     = Vector2i(edge_groups[key]["delta"])
		match delta:
			Vector2i(-1,  0):  ## NW: aresta esquerda
				vertices[from_cell] = true
				vertices[from_cell + Vector2i(0, 1)] = true
			Vector2i( 1,  0):  ## SE: aresta direita
				vertices[from_cell + Vector2i(1, 0)] = true
				vertices[from_cell + Vector2i(1, 1)] = true
			Vector2i( 0, -1):  ## NE: aresta topo
				vertices[from_cell] = true
				vertices[from_cell + Vector2i(1, 0)] = true
			Vector2i( 0,  1):  ## SW: aresta base
				vertices[from_cell + Vector2i(0, 1)] = true
				vertices[from_cell + Vector2i(1, 1)] = true

	## Para cada vértice, verificar os 4 corners diagonais
	for vtx: Vector2i in vertices:
		var vx: int = vtx.x
		var vy: int = vtx.y

		## As 4 arestas físicas do vértice, cada uma checável por 2 chaves
		## (a aresta pode ser emitida pelo mapa de qualquer um dos lados adjacentes).
		var eA_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy,    0, -1],   ## NE de GU(vx,vy)
			"%d,%d,%d,%d" % [vx,   vy-1,  0,  1]]   ## SW de GU(vx,vy-1)
		var eB_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy,   -1,  0],   ## NW de GU(vx,vy)
			"%d,%d,%d,%d" % [vx-1, vy,    1,  0]]   ## SE de GU(vx-1,vy)
		var eC_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx-1, vy,    0, -1],   ## NE de GU(vx-1,vy)
			"%d,%d,%d,%d" % [vx-1, vy-1,  0,  1]]   ## SW de GU(vx-1,vy-1)
		var eD_keys: Array[String] = [
			"%d,%d,%d,%d" % [vx,   vy-1, -1,  0],   ## NW de GU(vx,vy-1)
			"%d,%d,%d,%d" % [vx-1, vy-1,  1,  0]]   ## SE de GU(vx-1,vy-1)

		var eA: bool = _has_any(edge_groups, eA_keys)
		var eB: bool = _has_any(edge_groups, eB_keys)
		var eC: bool = _has_any(edge_groups, eC_keys)
		var eD: bool = _has_any(edge_groups, eD_keys)

		if not (eA or eB or eC or eD):
			continue   ## nenhuma aresta neste vértice

		## storey_count: máximo de todas as arestas presentes neste vértice
		var sc: int = _max_storey_of(edge_groups,
				eA_keys + eB_keys + eC_keys + eD_keys)

		## GU_TL corner — coberto por eC ou eD
		if not (eC or eD):
			_add_junction_extra(
				Vector2i((vx-1)*vpu + vpu-1, (vy-1)*vpu + vpu-1),
				sc, source_id, tile_coord)

		## GU_BR corner — coberto por eA ou eB
		if not (eA or eB):
			_add_junction_extra(
				Vector2i(vx*vpu, vy*vpu),
				sc, source_id, tile_coord)

		## GU_BL corner — coberto por eB ou eC
		if not (eB or eC):
			_add_junction_extra(
				Vector2i((vx-1)*vpu + vpu-1, vy*vpu),
				sc, source_id, tile_coord)

		## GU_TR corner — coberto por eA ou eD
		if not (eA or eD):
			_add_junction_extra(
				Vector2i(vx*vpu, (vy-1)*vpu + vpu-1),
				sc, source_id, tile_coord)


func _has_any(edge_groups: Dictionary, keys: Array[String]) -> bool:
	## Retorna true se alguma das chaves existir em edge_groups.
	for k: String in keys:
		if edge_groups.has(k):
			return true
	return false


func _max_storey_of(edge_groups: Dictionary, keys: Array[String]) -> int:
	## Retorna o max storey_count das arestas presentes na lista de chaves.
	var sc: int = 1
	for k: String in keys:
		if edge_groups.has(k):
			sc = maxi(sc, int(edge_groups[k]["max_storey"]) + 1)
	return sc


func _add_junction_extra(voxel_pos: Vector2i, storey_count: int,
		source_id: int, tile_coord: Vector2i) -> void:
	## Coloca 1 coluna voxel extra num corner de V-junction descoberto.
	## Regista VoxelRefs em _voxel_junction_extras para TIC e BakeSystem.
	var layer_count: int = storey_count * SubcubeCoordsClass.VOXELS_PER_UNIT_AXIS
	_ensure_voxel_layers(layer_count)
	for level in layer_count:
		_voxel_layers[level].set_cell(voxel_pos, source_id, tile_coord)
	for level in layer_count:
		_voxel_junction_extras.append(VoxelRef.new(voxel_pos, level))


func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
```

---

## DO NOT TOUCH

- O corpo de `_build_wall_containers()` — não apagar, não modificar
- `_place_wall_voxels()` — só o bloco de limpeza e a linha final (já feitos acima)
- `_voxel_slice_positions()` — não modificar
- Qualquer função de subcubo (`_build_subcube_tileset`, `_ensure_subcube_layers`, etc.)
- Qualquer `.gd` fora de `room.gd`
- Qualquer `.tres`, `.tscn`

---

## ACCEPTANCE

**A1 — `_voxel_junction_extras` declarado:**
```bash
grep -c "var _voxel_junction_extras" godot/scripts/world/room.gd
# Expected: 1
```

**A2 — 4 novas funções presentes:**
```bash
grep -c "func _build_voxel_junction_extras\|func _has_any\|func _max_storey_of\|func _add_junction_extra" \
    godot/scripts/world/room.gd
# Expected: 4
```

**A3 — Chamada de junção no fim de `_place_wall_voxels`:**
```bash
grep -n "_build_voxel_junction_extras" godot/scripts/world/room.gd
# Expected: ≥ 2 linhas — 1 definição + 1 chamada dentro de _place_wall_voxels
```

**A4 — `_voxel_junction_extras.clear()` no bloco de limpeza:**
```bash
grep -c "_voxel_junction_extras.clear()" godot/scripts/world/room.gd
# Expected: 1
```

**A5 — Dual-key check presente (eA/eB/eC/eD com 2 chaves cada):**
```bash
grep -c "eA_keys\|eB_keys\|eC_keys\|eD_keys" godot/scripts/world/room.gd
# Expected: ≥ 8  (declaração + uso de cada)
```

**A6 — 4 corners verificados (GU_TL / GU_BR / GU_BL / GU_TR):**
```bash
grep -c "GU_TL\|GU_BR\|GU_BL\|GU_TR" godot/scripts/world/room.gd
# Expected: 4
```

**A7 — Cálculo de vértices usa fórmula correcta por delta (match com 4 cases):**
```bash
grep -A 20 "## Recolher todos os vértices" godot/scripts/world/room.gd | \
    grep -c "Vector2i(-1,  0)\|Vector2i( 1,  0)\|Vector2i( 0, -1)\|Vector2i( 0,  1)"
# Expected: 4
```

**A8 — `_add_junction_extra` chama `set_cell` (Rule 8):**
```bash
grep -A 10 "func _add_junction_extra" godot/scripts/world/room.gd | \
    grep -c "set_cell"
# Expected: 1
```

**A9 — Sistema subcubo e `_build_wall_containers` preservados:**
```bash
grep -c "func _build_wall_containers\|func _build_subcube_tileset\|SUBCUBE_STEP_PX" \
    godot/scripts/world/room.gd
# Expected: 3
```

**A10 — Runtime: abrir Godot, carregar cena, verificar corners:**
```
Inspecção visual obrigatória:

ANTES (VOXEL-04): gaps visíveis nos corners exteriores de paredes em L
DEPOIS (VOXEL-05): corners preenchidos — nenhum gap visível em:
  • V junctions (2 paredes em L)
  • T junctions (3 paredes, zero extras)
  • X junctions (4 paredes, zero extras)

Output NÃO deve conter warnings voxel novos.
```

**A11 — Git status: apenas `room.gd` modificado:**
```bash
git status --short
# Expected: M  godot/scripts/world/room.gd  (+ .uid se Godot regenerar)
```

---

## DONE CRITERIA

A1..A9 passam via grep/bash. A10 confirmado visualmente (corners V-junction
preenchidos; T/X sem extras espúrios). A11 mostra apenas `room.gd` modificado.

**Concluída a Phase 1 do sistema Voxel (VOXEL-00..05):** paredes voxel renderizadas
correctamente, todos os tipos de junção tratados, zero calibração empírica.

Mover para `PROMPTS/DONE/VOXEL-05.md`.