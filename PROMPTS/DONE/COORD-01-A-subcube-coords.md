# COORD-01-A — Módulo de conversão `unit ↔ subcube` (SubcubeCoords)

> **Pré-requisito:** `PROMPTS/SUBCUBE_MASTER_PLAN.md` (sessão 4) no lugar.
> **Natureza:** dois arquivos NOVOS, isolados. Não toca em nada existente.
> Primeiro módulo da FASE A. Base de toda a geometria de subcubos.

---

## CONTEXT

A engine usa dois espaços de coordenadas (Master Plan §1): o **plano de gameplay**
(grid grosso, inalterado) raciocina em **Gameplay Units**; o **plano de geometria/
render** desenha em **Subcube Cells** (`4×4` subcubos por unit, no piso). Este
módulo é a conversão pura entre os dois — só índices de célula, sem pixels, sem
estado. Espelha o padrão de `godot/scripts/navigation/guard_pathfinder.gd`
(`class_name` + `static func`, sem instanciar).

⚠️ **Disciplina de eixo (a pegadinha dos 4×4 — Master Plan, Glossário).** Este
módulo é **2D, plano do piso**. A razão horizontal é `SUBCUBES_PER_UNIT_AXIS = 4`
(uma unit = 4×4 subcubos no chão). Isso é **distinto** de `SUBCUBES_PER_FLOOR = 4`
(VERTICAL, altura de um andar), que **não pertence a este módulo** — vive no plano
de render (SUB-01). Não introduzir altura/Z aqui.

Floor-division **negativa-segura** é obrigatória: o `/` e o `%` de int em GDScript
truncam/seguem o sinal errado para negativos. Use `floori(...)` e `posmod(...)`.
(Na prática as coords são ≥ 0 por causa do buffer/`INNER_ORIGIN`, mas a matemática
tem que estar correta — e o selftest cobre negativos.)

---

## MODULE

Dois arquivos **novos**:

- `godot/scripts/world/subcube_coords.gd` — `class_name SubcubeCoords`
- `godot/scripts/tools/coord_selftest.gd` — selftest headless

---

## TASK

### 1. Criar `godot/scripts/world/subcube_coords.gd` (conteúdo exato)

```gdscript
class_name SubcubeCoords
## Conversões puras entre Gameplay Units (grid grosso) e Subcube Cells (grid fino).
## SOMENTE plano do piso (2D, índices de célula). NÃO trata altura/vertical —
## subcube height é plano de render (ver SUBCUBE_MASTER_PLAN.md §1, §5).
## Sem estado, sem pixels: só índices de célula e a razão horizontal 4×.
## Espelha o padrão de GuardPathfinder (class_name + static func, sem instanciar).

## Razão linear HORIZONTAL: 1 Gameplay Unit = 4×4 Subcube Cells no piso.
## Distinto de SUBCUBES_PER_FLOOR (=4, VERTICAL, plano de render).
const SUBCUBES_PER_UNIT_AXIS: int = 4

## Origem (canto NW) do bloco 4×4 de subcubos de uma unit.
static func unit_to_subcube_origin(unit: Vector2i) -> Vector2i:
	return unit * SUBCUBES_PER_UNIT_AXIS

## Unit a que um subcube pertence. Floor-division negativa-segura.
static func subcube_to_unit(sub: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(sub.x) / SUBCUBES_PER_UNIT_AXIS),
		floori(float(sub.y) / SUBCUBES_PER_UNIT_AXIS),
	)

## Offset local do subcube dentro da sua unit. Sempre em 0..3 (negativa-seguro).
static func subcube_local(sub: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(sub.x, SUBCUBES_PER_UNIT_AXIS),
		posmod(sub.y, SUBCUBES_PER_UNIT_AXIS),
	)

## Subcube absoluto a partir de unit + offset local (0..3). Conveniência inversa.
static func subcube_at(unit: Vector2i, local_offset: Vector2i) -> Vector2i:
	return unit_to_subcube_origin(unit) + local_offset

## Os 16 subcubos de uma unit, em ordem de varredura (y exterior, x interior).
static func unit_subcubes(unit: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []
	for j in SUBCUBES_PER_UNIT_AXIS:
		for i in SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out
```

### 2. Criar `godot/scripts/tools/coord_selftest.gd` (conteúdo exato)

```gdscript
extends SceneTree
## Selftest headless de SubcubeCoords (COORD-01-A).
## Rodar: godot --headless --script res://godot/scripts/tools/coord_selftest.gd
## Saída: "COORD-01-A SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

func _initialize() -> void:
	var failures: int = 0
	var checked: int = 0

	## Inclui negativos, zero e valores grandes de propósito.
	for uy in range(-3, 30):
		for ux in range(-3, 30):
			var u: Vector2i = Vector2i(ux, uy)
			checked += 1
			## Round-trip: unit -> origem -> unit
			var back: Vector2i = SubcubeCoords.subcube_to_unit(
				SubcubeCoords.unit_to_subcube_origin(u))
			if back != u:
				push_error("RT unit falhou: %s -> %s" % [u, back]); failures += 1
			## unit_subcubes: 16, únicos, todos mapeiam de volta para u
			var cubes: Array[Vector2i] = SubcubeCoords.unit_subcubes(u)
			if cubes.size() != 16:
				push_error("unit_subcubes size=%d em %s" % [cubes.size(), u]); failures += 1
			var seen: Dictionary = {}
			for c in cubes:
				seen[c] = true
				if SubcubeCoords.subcube_to_unit(c) != u:
					push_error("subcube %s nao mapeia p/ unit %s" % [c, u]); failures += 1
			if seen.size() != 16:
				push_error("unit_subcubes nao unico em %s" % u); failures += 1

	## Round-trip: subcube -> (unit, local) -> subcube; local sempre 0..3
	for sy in range(-12, 120):
		for sx in range(-12, 120):
			var s: Vector2i = Vector2i(sx, sy)
			checked += 1
			var u: Vector2i = SubcubeCoords.subcube_to_unit(s)
			var l: Vector2i = SubcubeCoords.subcube_local(s)
			if l.x < 0 or l.x > 3 or l.y < 0 or l.y > 3:
				push_error("local fora de 0..3: %s -> %s" % [s, l]); failures += 1
			if SubcubeCoords.subcube_at(u, l) != s:
				push_error("RT subcube falhou: %s" % s); failures += 1

	if failures == 0:
		print("COORD-01-A SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("COORD-01-A SELFTEST: FAIL (%d falhas)" % failures)
		quit(1)
```

---

## DO NOT TOUCH

- **Qualquer arquivo existente.** Esta tarefa só cria os dois arquivos acima.
- **Não fazer wiring.** Não chamar `SubcubeCoords` em `room.gd`, `map_compiler.gd`,
  agentes, mapas, ou em qualquer lugar. A integração é o COORD-01-B (depois).
  Resistir à tentação de "já usar".
- **Não introduzir altura/Z/vertical** neste módulo (é plano do piso). Nada de
  `SUBCUBES_PER_FLOOR`, `SUBCUBE_STEP_PX`, pixels, ou `map_to_local`.
- **Não mexer** nas conversões pixel↔célula existentes (TileMapLayer/`map_to_local`).

---

## ACCEPTANCE

### Correção (gate principal — rodar o selftest headless)

```bash
godot --headless --script res://godot/scripts/tools/coord_selftest.gd
# espera-se: "COORD-01-A SELFTEST: PASS (...)" e exit code 0
```

### Estrutural (grep)

```bash
# class_name e as 5 funções static com tipagem
grep -nE 'class_name SubcubeCoords' godot/scripts/world/subcube_coords.gd
grep -cE 'static func (unit_to_subcube_origin|subcube_to_unit|subcube_local|subcube_at|unit_subcubes)\(' \
  godot/scripts/world/subcube_coords.gd   # espera-se: 5

# constante de eixo HORIZONTAL nomeada corretamente (não "PER_FLOOR")
grep -nE 'const SUBCUBES_PER_UNIT_AXIS: int = 4' godot/scripts/world/subcube_coords.gd

# negativa-segura: usa floori/posmod, NÃO usa int / ou % crus para a divisão
grep -nE 'floori\(|posmod\(' godot/scripts/world/subcube_coords.gd   # espera-se: match
```

### Isolamento (nenhum wiring prematuro)

```bash
grep -rn 'SubcubeCoords' godot/scripts
# espera-se SOMENTE: subcube_coords.gd (definição) + coord_selftest.gd (selftest).
# Qualquer outra ocorrência = wiring indevido → reprovar.
```

### Sanidade de parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
# o projeto continua abrindo sem erros novos.
```

---

**Escopo:** 2 arquivos novos · isolado · 1 sessão. Sem wiring, sem vertical, sem pixels.
