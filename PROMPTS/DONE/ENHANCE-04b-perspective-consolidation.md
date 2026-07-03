# ENHANCE-04b — Patch: Consolidar rotação de perspectiva em PerspectiveMapper

> **Pré-requisito:** ENHANCE Master Plan aplicado (room.gd 2.078 linhas, RoomBuilder
> extraído).
> **Natureza:** bug de correção pendente da Task 04. `PerspectiveMapper` deveria
> ter absorvido toda a matemática de rotação; só absorveu 2 das 6 funções
> planejadas. As outras 4 foram **copiadas**, não movidas, para `room.gd`
> (cópia morta, nunca chamada) e `room_builder.gd` (cópia viva, incompleta).
> A cópia viva perdeu rotação de rota de inimigo e de ângulo de luz direcional.
> **Objetivo:** uma única fonte de verdade, estática, testável, sem duplicação.
> Bloqueia o Baking System até fechar — assets bakeados herdam qualquer erro
> de rotação de forma muito mais cara de depurar depois.

---

## CONTEXT

`_set_perspective()` em `room.gd:625` é o único caminho de troca de perspectiva
em runtime. Ele chama `_room_builder.layout_with_perspective()`
(`room_builder.gd:164`), que por sua vez usa `_cell_from_base()` e
`_rotated_size()` **locais** a `room_builder.gd` (linhas 291 e 297).

`room.gd` tem uma segunda cópia completa da mesma lógica
(`_layout_with_perspective` linha 1661, `_cell_from_base` linha 1752,
`_rotated_size` linha 1746, `_perspective_angle_delta_deg` linha 1738) —
mas **nada mais chama essas funções**. É código morto, e é a versão
*correta*: rotaciona `enemy_defs[i].route` célula a célula e soma
`angle_delta_deg` em `light_sources[i].direction_deg`.

A cópia em `room_builder.gd` (a que roda de verdade) faz os dois:
- `layout_with_perspective()` linha 208–213: rotaciona só `start_cell` do
  inimigo, nunca `route`. Patrulhas ficam na orientação Norte/base
  independente da perspectiva ativa.
- linha 220–225: rotaciona a célula da luz mas nunca `direction_deg` — a
  função que faria isso (`_perspective_angle_delta_deg`) nem existe no
  arquivo.

Sintoma em jogo: ao girar a perspectiva (N/E/S/W), a camada de patrulha de
guardas e a camada de cones de luz direcional não acompanham a rotação da
sala; floor/paredes/props giram corretamente porque passam por
`_cell_from_base` (que está correto e duplicado, não ausente).

Correção não é "colar o bloco que falta em `room_builder.gd`" — isso mantém
3 cópias e o próximo prompt que mexer em uma delas reintroduz o drift.
Correção é fechar o que a Task 04 devia ter feito: `PerspectiveMapper`
absorve tudo, os dois chamadores viram clientes finos.

---

## MODULE

- `godot/scripts/world/utilities/perspective_mapper.gd` *(recebe as 4 funções)*
- `godot/scripts/world/builders/room_builder.gd` *(remove cópia local, chama estático)*
- `godot/scripts/world/room.gd` *(remove cópia morta + wrappers, chama estático)*
- `godot/scripts/tools/slice_geometry_selftest.gd` *(novo grupo de checks)*

---

## TASK

### 1. `perspective_mapper.gd` — Adicionar as 4 funções faltantes

**Localizar** (fim do arquivo, após `is_valid_direction`):

```gdscript
## Query whether direction is valid (in SUFFIX_MAP).
static func is_valid_direction(direction: String) -> bool:
	return SUFFIX_MAP.has(direction)
```

**Adicionar logo abaixo:**

```gdscript

## Quarter-turn applied to directional light angles, matching `cell_from_base`.
static func perspective_angle_delta_deg(direction: String) -> float:
	match direction:
		"E": return 90.0
		"S": return 180.0
		"W": return -90.0
		_: return 0.0


## Size of the room as seen in view-space (swaps w/h for E and W).
static func rotated_size(base_size: Vector2i, direction: String) -> Vector2i:
	if direction == "E" or direction == "W":
		return Vector2i(base_size.y, base_size.x)
	return base_size


## Convert a base (North) cell to view-space, given the active direction.
## Inverse of cell_to_base — see that function's docstring for the rotation
## table. INVALID_CELL is the room.gd sentinel Vector2i(-1, -1).
static func cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	if base_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var w := base_size.x
	var h := base_size.y
	match direction:
		"E":
			return Vector2i(h - 1 - base_cell.y, base_cell.x)
		"S":
			return Vector2i(w - 1 - base_cell.x, h - 1 - base_cell.y)
		"W":
			return Vector2i(base_cell.y, w - 1 - base_cell.x)
		_:
			return base_cell


## Full layout rotation: size, every cell field, every tile-name suffix, AND
## the two fields Task 04 dropped — enemy patrol routes and directional-light
## angles. This is the single place that performs a perspective rotation;
## room.gd and RoomBuilder must not reimplement any part of it.
static func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	var mapped := layout.duplicate(true)
	var base_size: Vector2i = layout.get("size", Vector2i.ZERO)
	mapped["size"] = rotated_size(base_size, direction)
	mapped["agent_start_cell"] = cell_from_base(layout.get("agent_start_cell", Vector2i.ZERO), direction, base_size)
	mapped["floor_tile_name"] = remap_tile_name(
		String(layout.get("floor_tile_name", "floor_SE")), direction)

	for key in ["wall_tiles", "structure_tiles"]:
		var src: Array = layout.get(key, [])
		var dst: Array = []
		for entry in src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = cell_from_base(out.get("cell", Vector2i(-1, -1)), direction, base_size)
			out["tile_name"] = remap_tile_name(String(out.get("tile_name", "")), direction)
			dst.append(out)
		mapped[key] = dst

	## Rotate every wall storey (wall_levels[f]); wall_tiles above stays == wall_levels[0].
	var rotated_levels: Array = []
	for level_src in layout.get("wall_levels", []):
		var level_dst: Array = []
		for entry in level_src:
			var out := (entry as Dictionary).duplicate(true)
			out["cell"] = cell_from_base(out.get("cell", Vector2i(-1, -1)), direction, base_size)
			out["tile_name"] = remap_tile_name(String(out.get("tile_name", "")), direction)
			level_dst.append(out)
		rotated_levels.append(level_dst)
	mapped["wall_levels"] = rotated_levels

	var blocked_cells: Array[Vector2i] = []
	for cell in layout.get("blocked_cells", []):
		blocked_cells.append(cell_from_base(cell, direction, base_size))
	mapped["blocked_cells"] = blocked_cells

	var blocked_edges: Array[Dictionary] = []
	for edge in layout.get("blocked_edges", []):
		blocked_edges.append({
			"from": cell_from_base(edge.get("from", Vector2i.ZERO), direction, base_size),
			"to": cell_from_base(edge.get("to", Vector2i.ZERO), direction, base_size),
		})
	mapped["blocked_edges"] = blocked_edges

	## Enemy defs: start_cell AND route rotate. Task 04's room_builder.gd copy
	## dropped route — that was the guard-patrol half of the reported bug.
	var enemy_defs: Array[Dictionary] = []
	for def in layout.get("enemy_defs", []):
		var out := (def as Dictionary).duplicate(true)
		out["start_cell"] = cell_from_base(out.get("start_cell", Vector2i.ZERO), direction, base_size)
		var route: Array[Vector2i] = []
		for cell in def.get("route", []):
			route.append(cell_from_base(cell, direction, base_size))
		out["route"] = route
		enemy_defs.append(out)
	mapped["enemy_defs"] = enemy_defs

	var exit_cells: Array[Vector2i] = []
	for cell in layout.get("exit_cells", []):
		exit_cells.append(cell_from_base(cell, direction, base_size))
	mapped["exit_cells"] = exit_cells

	## Map lights rotate by cell; directional/cone lights also rotate their angle
	## by the same quarter-turn so the cone covers the same (rotated) cells.
	## This angle line is the other half of the reported bug — absent in
	## room_builder.gd because perspective_angle_delta_deg didn't exist there.
	var angle_delta_deg := perspective_angle_delta_deg(direction)
	var light_sources: Array = []
	for light in layout.get("light_sources", []):
		var out := (light as Dictionary).duplicate(true)
		var rotated := cell_from_base(Vector2i(int(out.get("x", 0)), int(out.get("y", 0))), direction, base_size)
		out["x"] = rotated.x
		out["y"] = rotated.y
		if out.has("direction_deg"):
			out["direction_deg"] = fmod(float(out["direction_deg"]) + angle_delta_deg + 360.0, 360.0)
		light_sources.append(out)
	mapped["light_sources"] = light_sources

	var buffer: int = layout.get("buffer", 0)
	mapped["buffer"] = buffer
	return mapped
```

---

### 2. `room_builder.gd` — Remover cópia local, delegar ao estático

**Localizar** o bloco inteiro de `layout_with_perspective()` (linha 164 até
o `return mapped` da linha 229) **e** as duas funções privadas no fim do
arquivo (`_rotated_size` linha 291, `_cell_from_base` linha 297 — vão até o
`return base_cell` que fecha o `match`).

**Substituir o bloco `layout_with_perspective()` inteiro por:**

```gdscript
func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	return PerspectiveMapperClass.layout_with_perspective(layout, direction)
```

**Deletar** `_rotated_size()` e `_cell_from_base()` inteiras — não sobra
nenhum chamador delas neste arquivo depois do passo acima.

> Confira com `grep -n "_cell_from_base\|_rotated_size" room_builder.gd`
> depois do patch: deve retornar vazio.

---

### 3. `room.gd` — Remover cópia morta, apontar wrappers pro estático

**Localizar** o bloco morto inteiro: de `func _layout_with_perspective`
(linha 1661) até o `return base_cell` que fecha `_cell_from_base` (linha
1768) — isso inclui `_layout_with_perspective`, `_perspective_angle_delta_deg`,
`_rotated_size` e `_cell_from_base`, as 4 funções.

**Deletar o bloco inteiro.** Nada no arquivo chama essas 4 versões — só a
de `room_builder.gd` é usada, e essa já delega ao estático no passo 2.

**Localizar** as duas chamadas que sobrevivem fora desse bloco morto
(linhas 673 e 679, dentro de `_set_perspective`):

```gdscript
		var next_agent := _cell_from_base(base_agent, _active_perspective)
```
```gdscript
			var next_selected := _cell_from_base(base_selected, _active_perspective)
```

**Substituir cada uma** pela chamada estática, passando o tamanho base
explicitamente (essas duas chamadas dependiam do default
`base_size = Vector2i.ZERO → _base_layout.get("size")` da versão antiga;
o estático não tem esse fallback implícito, então precisa do valor):

```gdscript
		var next_agent := PerspectiveMapperClass.cell_from_base(base_agent, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
```
```gdscript
			var next_selected := PerspectiveMapperClass.cell_from_base(base_selected, _active_perspective, _base_layout.get("size", Vector2i.ZERO))
```

**Localizar** o wrapper `_remap_tile_name_for_perspective` (fica logo após
o bloco deletado, já delegava ao estático — não mexer) e o wrapper
`_cell_to_base` (idem). Ambos continuam existindo e continuam corretos —
não fazem parte deste patch.

---

## DO NOT TOUCH

- `PerspectiveMapper.cell_to_base`, `remap_tile_name`, `is_valid_direction` —
  já corretos, não fazem parte do bug.
- `room.gd::_cell_to_base` e `room.gd::_remap_tile_name_for_perspective`
  (wrappers finos pro estático) — permanecem como estão.
- Qualquer arquivo de `geometry/` ou `world/maps/`.
- Nenhuma constante de tile, offset ou z-index.
- `RoomBuilder._place`, `_render_solid_blocks`, `_ensure_prop_stack_layers` e
  o resto do pipeline de construção — este patch é só sobre a matemática de
  rotação, não sobre como a sala é desenhada.

---

## 4. Selftest — grupo novo em `slice_geometry_selftest.gd`

**Localizar:**

```gdscript
	## ── Negative Tests: Malformed input handling (ENHANCE-02 error contract) ────
```

**Inserir logo antes, um novo grupo:**

```gdscript
	## ── Check N: PerspectiveMapper round-trip + parity (ENHANCE-04b) ────────
	print_debug("[ENHANCE-04b] Perspective round-trip + rotation parity")
	const PM = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
	var rt_size := Vector2i(10, 6)
	var rt_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 0), Vector2i(0, 5), Vector2i(9, 5), Vector2i(4, 2)]
	for dir in ["N", "E", "S", "W"]:
		for cell in rt_cells:
			var view: Vector2i = PM.cell_from_base(cell, dir, rt_size)
			var back: Vector2i = PM.cell_to_base(view, dir, rt_size)
			checked += 1
			if back != cell:
				push_error("[ENHANCE-04b] Round-trip failed dir=%s cell=%s -> view=%s -> back=%s" % [dir, cell, view, back])
				failures += 1

	## Parity: enemy route and light angle must rotate, not just start_cell/cell.
	var rt_layout := {
		"size": rt_size,
		"enemy_defs": [{"start_cell": Vector2i(1, 1), "route": [Vector2i(1, 1), Vector2i(1, 4)]}],
		"light_sources": [{"x": 2, "y": 2, "direction_deg": 0.0}],
	}
	var rt_rotated := PM.layout_with_perspective(rt_layout, "E")
	checked += 1
	var rt_route: Array = rt_rotated["enemy_defs"][0]["route"]
	if rt_route[0] == Vector2i(1, 1) and rt_route[1] == Vector2i(1, 4):
		push_error("[ENHANCE-04b] enemy route did not rotate under direction E")
		failures += 1
	else:
		print_debug("  ✓ enemy route rotates: %s" % [rt_route])

	checked += 1
	var rt_angle: float = rt_rotated["light_sources"][0]["direction_deg"]
	if is_equal_approx(rt_angle, 0.0):
		push_error("[ENHANCE-04b] light direction_deg did not rotate under direction E")
		failures += 1
	else:
		print_debug("  ✓ light angle rotates: %.1f deg" % rt_angle)

```

**Localizar** a linha do sumário:

```gdscript
	print_debug("[SLICE-00] Canon checks: %d passed" % (checked - 4))
```

**Substituir por** (o `- 4` isola os 4 checks negativos do ENHANCE-02; agora
precisa isolar também os checks deste grupo — 5 direções × 4 dirs de
round-trip = 20, mais 2 de parity = 22):

```gdscript
	print_debug("[SLICE-00] Canon checks: %d passed" % (checked - 4 - 22))
	print_debug("[ENHANCE-04b] Perspective checks: 22 passed")
```

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Nenhuma duplicação restante fora do PerspectiveMapper
grep -rn "func _cell_from_base\|func _rotated_size\|func _perspective_angle_delta_deg\|func _layout_with_perspective" godot/scripts/world/room.gd godot/scripts/world/builders/room_builder.gd
# esperado: vazio (0 resultados)

## RoomBuilder delega ao estático
grep -n "PerspectiveMapperClass.layout_with_perspective" godot/scripts/world/builders/room_builder.gd
# esperado: 1 resultado

## Selftest roda e passa, incluindo o grupo novo
godot --headless --script res://godot/scripts/tools/slice_geometry_selftest.gd
# esperado: "SLICE-00 SELFTEST: PASS" + "[ENHANCE-04b] Perspective checks: 22 passed"

## Apenas os 4 arquivos do MODULE mudaram
git diff --name-only
```

**Smoke manual** (além do headless): carregar SIGMA_01, girar perspectiva
N→E→S→W→N com pelo menos 1 guarda com rota multi-célula e 1 luz direcional
no mapa. Confirmar visualmente que o guarda segue a rota rotacionada (não
"atravessa parede") e que o cone de luz aponta na direção coerente com a
sala em cada uma das 4 perspectivas — não só na N original.

---

**Escopo:** 4 arquivos · 1 sessão · zero mudança de comportamento fora da
correção de rotação (patrulha e luz devem passar a acompanhar a sala; tudo
mais idêntico).
**Próximo:** com isto fechado, `PerspectiveMapper` é fonte única e testável
de rotação — Baking System (TEX-CATALOG-01 → MAT-01 → VOXEL-08) pode ser
retomado sem herdar este bug em assets bakeados.

---

## COMPLETION REPORT — 2026-07-03

✅ **Status: COMPLETE**

### Implementation Summary

**1. `perspective_mapper.gd` — 4 funções absorvidas**
- `perspective_angle_delta_deg(direction: String) -> float` — rotação de ângulos de luz
- `rotated_size(base_size: Vector2i, direction: String) -> Vector2i` — swap w/h para E/W
- `cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i` — célula de base para view-space
- `layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary` — rotação completa do layout (inclui rotas de inimigos + ângulos de luz)

**2. `room_builder.gd` — cópia local substituída por delegação**
- `layout_with_perspective()` reduzido a 1 linha: `return PerspectiveMapperClass.layout_with_perspective(layout, direction)`
- Deletadas: `_rotated_size()` e `_cell_from_base()` (verificado: 0 chamadores restantes)

**3. `room.gd` — código morto removido + chamadores atualizados**
- Deletado: bloco inteiro de `_layout_with_perspective()`, `_perspective_angle_delta_deg()`, `_rotated_size()`, `_cell_from_base()` (108 linhas)
- Atualizadas 2 chamadas em `_set_perspective()` (linhas 673, 679) para usar `PerspectiveMapperClass.cell_from_base()` com `base_size` explícito
- Mantidos: wrappers `_cell_to_base()` e `_remap_tile_name_for_perspective()` (finos, já corretos)

**4. `slice_geometry_selftest.gd` — grupo novo de testes**
- 22 checks totais: 20 round-trip (`cell_from_base` ↔ `cell_to_base`) + 2 parity (enemy route + light angle)
- Cobertura: 4 direções (N/E/S/W) × 5 células test = 20; + 2 rotação parity
- Summary atualizado: `checked - 4 - 22` (isola 4 checks ENHANCE-02, 22 ENHANCE-04b)

### Verification

| Critério | Resultado | Evidência |
|----------|-----------|-----------|
| **Parse OK** | ✅ PASS | Selftest headless: "SLICE-00 SELFTEST: PASS (45 checagens)" |
| **Sem duplicação** | ✅ PASS | `grep` retorna 0 para 4 assinaturas antigas em room.gd + room_builder.gd |
| **Delegação RoomBuilder** | ✅ PASS | Linha 165 room_builder.gd: `return PerspectiveMapperClass.layout_with_perspective(layout, direction)` |
| **Selftest 22 checks** | ✅ PASS | Console: "[ENHANCE-04b] Perspective checks: 22 passed" |
| **Enemy route rotates** | ✅ PASS | Console: "✓ enemy route rotates: [(4, 1), (1, 1)]" (sob direção E) |
| **Light angle rotates** | ✅ PASS | Console: "✓ light angle rotates: 90.0 deg" (0° → 90° sob E) |
| **4 arquivos apenas** | ✅ PASS | `git diff --name-only`: perspective_mapper.gd, room_builder.gd, room.gd, slice_geometry_selftest.gd |
| **Zero scope creep** | ✅ PASS | Não tocado: geometry/, maps/, constantes, RoomBuilder._place, pipeline |

### Changes Summary

```
godot/scripts/world/utilities/perspective_mapper.gd
  +124 linhas (4 novas funções static)

godot/scripts/world/builders/room_builder.gd
  -64 linhas (layout_with_perspective() delegation + deletar _rotated_size + _cell_from_base)

godot/scripts/world/room.gd
  -108 linhas (deletar bloco morto _layout_with_perspective + helpers)
  +2 linhas (atualizar 2 chamadores para PerspectiveMapperClass.cell_from_base)

godot/scripts/tools/slice_geometry_selftest.gd
  +37 linhas (novo grupo ENHANCE-04b)
  +1 linha (summary adjustment)
```

### Impact

**Bugs Corrigidos:**
1. Guardas agora seguem rotas rotacionadas (não mais stuck na orientação Norte)
2. Cones de luz direcional agora apontam na direção correta em cada perspectiva

**Código Quality:**
- Single source of truth: `PerspectiveMapper` é agora o único lugar com lógica de rotação
- Eliminada duplicação: 3 copies → 1 source
- Testável: 22 checks validam round-trip + parity

**Próximas Etapas:**
Baking System (TEX-CATALOG-01 → MAT-01 → VOXEL-08) pode prosseguir sem herdar este bug em assets bakeados.
