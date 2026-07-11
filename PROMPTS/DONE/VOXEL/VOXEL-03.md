# VOXEL-03 — Data Classes: `VoxelRef` · `WallSlice` · `HighWall`

> **Série:** VOXEL · **Prompt:** 03 de 11
> **Depende de:** VOXEL-02 (constantes + tileset infra) ✅
> **Desbloqueia:** VOXEL-04 (`_place_wall_voxels`) e VOXEL-06 (VoxelRegistry)
> **Arquivos criados:** 4 novos `.gd`, nenhum existente modificado.
> **Natureza:** data classes puras — sem renderização, sem TIC, sem referências a `room.gd`.

---

## CONTEXT

Este prompt define as três estruturas de dados do sistema Voxel:

- **`VoxelRef`** — estado de um voxel individual: posição, nível, visibilidade,
  dirty flag, estado de dano, e o rect de atlas pré-baked (usado a partir de VOXEL-08).
- **`WallSlice`** — container primário: uma face de parede numa direção, num GU
  adjacente, N andares. Dois `WallSlice` por aresta de parede (inner S0 + outer S1).
- **`HighWall`** — container secundário: grupo nomeado de WallSlices + extras de
  junção. Unidade de baking secundário (VOXEL-09).

As classes são **dados apenas** neste prompt — sem chamar `set_cell`, sem aceder ao
`_voxel_tileset`. A ligação ao sistema de renderização de `room.gd` vem em VOXEL-04
(`_place_wall_voxels`) e ao TIC em VOXEL-07. O BakeSystem preenche `face_atlas_rect`
em VOXEL-08.

Referências:
- `docs/technical/VOXEL_MASTER_PLAN.md` §6 (Container System) e §10 (Destructibility)
- `tools/persistent/OPERATOR_CONTEXT.md` → Rule 8, Voxel Wall System

Pre-flight:
```bash
git status    # deve estar limpo
grep -c "VOXELS_PER_UNIT_AXIS" godot/scripts/world/subcube_coords.gd
# Expected: 1  (VOXEL-02 foi aplicado)
```

---

## MODULE

Quatro ficheiros **novos**:

- `godot/scripts/world/voxel_ref.gd`     — `class_name VoxelRef`
- `godot/scripts/world/wall_slice.gd`    — `class_name WallSlice`
- `godot/scripts/world/high_wall.gd`     — `class_name HighWall`
- `godot/scripts/tools/voxel_selftest.gd` — selftest headless

---

## TASK

### 1. Criar `godot/scripts/world/voxel_ref.gd`

```gdscript
class_name VoxelRef
## Estado de um voxel individual no plano de render Voxel (VOXEL series).
## Uma instância por posição × nível vertical dentro de um WallSlice.
##
## Renderização:  room._voxel_layers[level].set_cell / erase_cell (VOXEL-04+).
## Dirty flag:    set_visible / set_damage marcam dirty = true.
##                O TIC loop processa voxels com dirty = true (VOXEL-07).
## Propagação:    dirty_count no WallSlice pai é incrementado pelo caller —
##                não há back-reference nesta classe (vem em VOXEL-06/07).
## face_atlas_rect: preenchido pelo BakeSystem em VOXEL-08; ignorado até lá.

## Estados de dano. Usar com set_damage().
const DAMAGE_INTACT:    int = 0   ## visual completo
const DAMAGE_CRACKED:   int = 1   ## overlay de dano (VOXEL-10)
const DAMAGE_DESTROYED: int = 2   ## invisível; erase_cell no próximo TIC

var grid_pos:        Vector2i = Vector2i.ZERO
var level:           int      = 0
var visible:         bool     = true
var dirty:           bool     = false
var damage_state:    int      = DAMAGE_INTACT
var face_atlas_rect: Rect2i   = Rect2i()   ## set by BakeSystem (VOXEL-08)

func _init(pos: Vector2i, lv: int) -> void:
	grid_pos = pos
	level    = lv

## Altera visibilidade. No-op se o valor não muda (não suja dirty).
## O caller é responsável por incrementar WallSlice.dirty_count (VOXEL-07).
func set_visible(v: bool) -> void:
	if visible == v:
		return
	visible = v
	dirty   = true

## Aplica estado de dano. DAMAGE_DESTROYED força visible = false.
## O caller é responsável por incrementar WallSlice.dirty_count (VOXEL-07).
func set_damage(state: int) -> void:
	damage_state = clamp(state, DAMAGE_INTACT, DAMAGE_DESTROYED)
	if damage_state == DAMAGE_DESTROYED:
		visible = false
	dirty = true

## Limpa o dirty flag após o TIC ter aplicado o estado ao TileMapLayer.
func clear_dirty() -> void:
	dirty = false
```

---

### 2. Criar `godot/scripts/world/wall_slice.gd`

```gdscript
class_name WallSlice
## Container primário do sistema Voxel.
## Representa uma face de parede: 1 direção × 1 GU adjacente × N andares.
## Cada aresta de GAME UNIT produz 2 WallSlices (slice_index 0=inner, 1=outer).
## Voxels: 8 × (8 × storey_count) = 64 por andar.
##
## dirty_count: incrementado pelo caller quando VoxelRef.dirty é marcado.
##              Decrementado / zerado pelo TIC loop após processar (VOXEL-07).

var id:               String   = ""
var direction:        String   = ""          ## "NW" | "NE" | "SE" | "SW"
var slice_index:      int      = 0           ## 0 = inner (GU primário), 1 = outer (GU adjacente)
var gu_cell:          Vector2i = Vector2i.ZERO  ## GU primário (coordenada de gameplay)
var storey_count:     int      = 1
var voxels:           Array    = []          ## Array[VoxelRef], 64 × storey_count
var dirty_count:      int      = 0
var baked:            bool     = false
var parent_high_wall: String   = ""          ## id do HighWall pai; "" se standalone

## Retorna o VoxelRef no índice linear dado, ou null se fora de bounds.
func get_voxel(index: int) -> VoxelRef:
	if index < 0 or index >= voxels.size():
		return null
	return voxels[index]

## Número total de VoxelRefs neste slice (= 64 × storey_count em uso normal).
func total_voxel_count() -> int:
	return voxels.size()

## Marca todos os voxels como dirty e actualiza dirty_count.
## Usado em rebuild de sala ou debug — não chama set_visible.
func mark_all_dirty() -> void:
	for v: VoxelRef in voxels:
		v.dirty = true
	dirty_count = voxels.size()
```

---

### 3. Criar `godot/scripts/world/high_wall.gd`

```gdscript
class_name HighWall
## Container secundário do sistema Voxel.
## Agrupa WallSlices nomeados + voxels de junção extra (V-junction corners).
## Unidade de baking secundário: uma textura cobre todos os voxels constituintes.
##
## dirty_count: soma dos dirty_counts dos slices filhos.
##              Gerido pelo VoxelRegistry / TIC loop (VOXEL-06 / VOXEL-07).
## voxel_bounds: bounding box em coordenadas de voxel; preenchido em VOXEL-04
##               quando os slices são adicionados.

var id:              String     = ""
var slices:          Array      = []     ## Array[WallSlice]
var junction_extras: Array      = []     ## Array[VoxelRef] — colunas extra de V-junction
var bake_texture:    Texture2D  = null   ## atribuído pelo BakeSystem (VOXEL-08)
var baked:           bool       = false
var dirty_count:     int        = 0
var voxel_bounds:    Rect2i     = Rect2i()   ## preenchido em VOXEL-04

## Retorna o WallSlice com o id dado, ou null se não encontrado.
func get_slice(slice_id: String) -> WallSlice:
	for s: WallSlice in slices:
		if s.id == slice_id:
			return s
	return null

## Número total de VoxelRefs (slices + extras de junção).
func total_voxel_count() -> int:
	var n: int = junction_extras.size()
	for s: WallSlice in slices:
		n += s.total_voxel_count()
	return n

## Todos os VoxelRefs em ordem: slices primeiro, extras de junção por último.
## Usado pelo BakeSystem para iterar num único passo (VOXEL-08/09).
func all_voxels() -> Array:
	var out: Array = []
	for s: WallSlice in slices:
		out.append_array(s.voxels)
	out.append_array(junction_extras)
	return out
```

---

### 4. Criar `godot/scripts/tools/voxel_selftest.gd`

```gdscript
extends SceneTree
## Selftest headless das data classes Voxel (VOXEL-03).
## Rodar: godot --headless --script res://godot/scripts/tools/voxel_selftest.gd
## Saída: "VOXEL-03 SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

func _initialize() -> void:
	var VR = load("res://godot/scripts/world/voxel_ref.gd")
	var WS = load("res://godot/scripts/world/wall_slice.gd")
	var HW = load("res://godot/scripts/world/high_wall.gd")
	var SC = load("res://godot/scripts/world/subcube_coords.gd")
	var failures: int = 0
	var checked:  int = 0

	## ── VoxelRef ─────────────────────────────────────────────────────────
	var vr = VR.new(Vector2i(3, 4), 2)
	checked += 1; if vr.grid_pos != Vector2i(3, 4): push_error("VR: grid_pos"); failures += 1
	checked += 1; if vr.level   != 2:               push_error("VR: level");    failures += 1
	checked += 1; if vr.visible != true:             push_error("VR: visible");  failures += 1
	checked += 1; if vr.dirty   != false:            push_error("VR: dirty");    failures += 1

	## set_visible no-op
	vr.set_visible(true)
	checked += 1; if vr.dirty != false: push_error("VR: set_visible no-op sujo dirty"); failures += 1

	## set_visible muda estado
	vr.set_visible(false)
	checked += 1; if vr.visible != false: push_error("VR: set_visible(false).visible"); failures += 1
	checked += 1; if vr.dirty   != true:  push_error("VR: set_visible(false).dirty");  failures += 1

	## clear_dirty
	vr.clear_dirty()
	checked += 1; if vr.dirty != false: push_error("VR: clear_dirty"); failures += 1

	## DAMAGE_DESTROYED força visible=false
	vr.set_visible(true); vr.clear_dirty()
	vr.set_damage(VR.DAMAGE_DESTROYED)
	checked += 1; if vr.visible      != false:              push_error("VR: DESTROYED.visible"); failures += 1
	checked += 1; if vr.dirty        != true:               push_error("VR: DESTROYED.dirty");   failures += 1
	checked += 1; if vr.damage_state != VR.DAMAGE_DESTROYED: push_error("VR: damage_state");      failures += 1

	## DAMAGE_CRACKED não esconde
	var vr2 = VR.new(Vector2i(0, 0), 0)
	vr2.set_damage(VR.DAMAGE_CRACKED)
	checked += 1; if vr2.visible == false: push_error("VR: CRACKED nao deve esconder"); failures += 1
	checked += 1; if vr2.dirty   != true:  push_error("VR: CRACKED.dirty");             failures += 1

	## ── WallSlice ────────────────────────────────────────────────────────
	var ws = WS.new()
	ws.id           = "WALL_NW_GC01_GR02_S0"
	ws.direction    = "NW"
	ws.slice_index  = 0
	ws.gu_cell      = Vector2i(1, 2)
	ws.storey_count = 1

	## Povoa: 8 posições × 8 níveis = 64 VoxelRefs
	for j in 8:
		for lv in 8:
			ws.voxels.append(VR.new(Vector2i(1 * 8, 2 * 8 + j), lv))

	checked += 1; if ws.total_voxel_count() != 64: push_error("WS: total_voxel_count"); failures += 1
	checked += 1; if ws.get_voxel(0)  == null:     push_error("WS: get_voxel(0)");      failures += 1
	checked += 1; if ws.get_voxel(63) == null:     push_error("WS: get_voxel(63)");     failures += 1
	checked += 1; if ws.get_voxel(64) != null:     push_error("WS: get_voxel(64) OOB"); failures += 1
	checked += 1; if ws.get_voxel(-1) != null:     push_error("WS: get_voxel(-1) OOB"); failures += 1

	ws.mark_all_dirty()
	checked += 1; if ws.dirty_count != 64: push_error("WS: dirty_count"); failures += 1
	var all_dirty: bool = true
	for v in ws.voxels:
		if not v.dirty: all_dirty = false; break
	checked += 1; if not all_dirty: push_error("WS: mark_all_dirty nao marcou todos"); failures += 1

	## ── HighWall ─────────────────────────────────────────────────────────
	var hw = HW.new()
	hw.id = "HIGHWALL_001"
	hw.slices.append(ws)

	var extra = VR.new(Vector2i(7, 15), 0)
	hw.junction_extras.append(extra)

	checked += 1; if hw.total_voxel_count() != 65:                            push_error("HW: total 64+1");      failures += 1
	checked += 1; if hw.get_slice("WALL_NW_GC01_GR02_S0") == null:            push_error("HW: get_slice found"); failures += 1
	checked += 1; if hw.get_slice("WALL_NE_GC00_GR00_S0") != null:            push_error("HW: get_slice miss");  failures += 1
	checked += 1; if hw.all_voxels().size() != 65:                             push_error("HW: all_voxels");      failures += 1
	checked += 1; if hw.all_voxels()[64] != extra:                             push_error("HW: extra last");      failures += 1

	## ── SubcubeCoords voxel API (VOXEL-02) ───────────────────────────────
	for uy in range(0, 10):
		for ux in range(0, 10):
			var gu: Vector2i     = Vector2i(ux, uy)
			var origin: Vector2i = SC.gu_to_voxel_origin(gu)
			checked += 1
			if origin != gu * 8:
				push_error("SC.gu_to_voxel_origin(%s)" % gu); failures += 1
			checked += 1
			if SC.voxel_to_gu(origin) != gu:
				push_error("SC.voxel_to_gu round-trip %s" % gu); failures += 1
			var local_v: Vector2i = SC.voxel_local(origin + Vector2i(3, 7))
			checked += 1
			if local_v != Vector2i(3, 7):
				push_error("SC.voxel_local %s" % gu); failures += 1
			checked += 1
			if SC.gu_voxels(gu).size() != 64:
				push_error("SC.gu_voxels size %s" % gu); failures += 1

	## ── Sumário ──────────────────────────────────────────────────────────
	if failures == 0:
		print("VOXEL-03 SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("VOXEL-03 SELFTEST: FAIL (%d falhas / %d checagens)" % [failures, checked])
		quit(1)
```

### 5. Executar o selftest

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
    --headless --path . \
    --script res://godot/scripts/tools/voxel_selftest.gd
```

Output esperado:
```
VOXEL-03 SELFTEST: PASS (XXX checagens)
```

---

## DO NOT TOUCH

- Qualquer arquivo existente em `godot/scripts/world/` — apenas novos ficheiros
- Qualquer arquivo existente em `godot/scripts/tools/` — apenas `voxel_selftest.gd` novo
- `room.gd` — não tocado neste prompt
- `subcube_coords.gd` — não tocado neste prompt
- Qualquer `.tres`, `.tscn`, `map_compiler.gd`, `subcube_geometry.gd`

---

## ACCEPTANCE

**A1 — Três ficheiros de classe existem:**
```bash
test -f godot/scripts/world/voxel_ref.gd  && \
test -f godot/scripts/world/wall_slice.gd && \
test -f godot/scripts/world/high_wall.gd  && echo PASS || echo FAIL
```

**A2 — `class_name` correctos:**
```bash
grep -c "^class_name VoxelRef"  godot/scripts/world/voxel_ref.gd
grep -c "^class_name WallSlice" godot/scripts/world/wall_slice.gd
grep -c "^class_name HighWall"  godot/scripts/world/high_wall.gd
# Expected: 1 cada
```

**A3 — Constantes de dano em VoxelRef:**
```bash
grep -cE "DAMAGE_INTACT\s*:\s*int\s*=\s*0|DAMAGE_CRACKED\s*:\s*int\s*=\s*1|DAMAGE_DESTROYED\s*:\s*int\s*=\s*2" \
    godot/scripts/world/voxel_ref.gd
# Expected: 3
```

**A4 — Métodos obrigatórios presentes:**
```bash
grep -c "func set_visible\|func set_damage\|func clear_dirty" \
    godot/scripts/world/voxel_ref.gd
# Expected: 3

grep -c "func get_voxel\|func total_voxel_count\|func mark_all_dirty" \
    godot/scripts/world/wall_slice.gd
# Expected: 3

grep -c "func get_slice\|func total_voxel_count\|func all_voxels" \
    godot/scripts/world/high_wall.gd
# Expected: 3
```

**A5 — Campos obrigatórios em WallSlice:**
```bash
grep -cE "var direction|var slice_index|var gu_cell|var storey_count|var dirty_count|var parent_high_wall" \
    godot/scripts/world/wall_slice.gd
# Expected: 6
```

**A6 — Campos obrigatórios em HighWall:**
```bash
grep -cE "var slices|var junction_extras|var bake_texture|var dirty_count|var voxel_bounds" \
    godot/scripts/world/high_wall.gd
# Expected: 5
```

**A7 — `face_atlas_rect: Rect2i` em VoxelRef:**
```bash
grep -c "face_atlas_rect" godot/scripts/world/voxel_ref.gd
# Expected: 1
```

**A8 — Sem referências a `room.gd`, `set_cell`, ou renderização:**
```bash
grep -Ec "set_cell|erase_cell|TileMapLayer|_voxel_layers|room\." \
    godot/scripts/world/voxel_ref.gd \
    godot/scripts/world/wall_slice.gd \
    godot/scripts/world/high_wall.gd
# Expected: 0
```

**A9 — Selftest passa:**
```bash
/Applications/Godot.app/Contents/MacOS/Godot \
    --headless --path . \
    --script res://godot/scripts/tools/voxel_selftest.gd
# Expected: exit 0, output contém "PASS"
```

**A10 — Git status: apenas ficheiros novos:**
```bash
git status --short
# Expected: "??" entries apenas — 4 novos ficheiros (+ .uid se Godot regenerar)
# Nenhuma linha "M" — room.gd e subcube_coords.gd não foram tocados
```

---

## DONE CRITERIA

A1..A9 passam. A10 confirma zero ficheiros tracked modificados.
Mover para `PROMPTS/DONE/VOXEL-03.md`.
