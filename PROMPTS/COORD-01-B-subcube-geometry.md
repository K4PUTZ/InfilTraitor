# COORD-01-B — Costura: `map_compiler` emite geometria de subcubos (SubcubeGeometry)

> **Pré-requisitos:** COORD-01-A (`SubcubeCoords`) já no repo; `SUBCUBE_MASTER_PLAN.md`
> (sessão 4) no lugar.
> **Natureza:** 1 arquivo novo + 1 edição cirúrgica e ADITIVA no `map_compiler.gd`
> + 1 selftest. Fecha a FASE A.

---

## CONTEXT

A costura do modelo de dois níveis (Master Plan §1): a partir da geometria já
compilada em **Gameplay Units**, gerar a **geometria de subcubos** que o render
layer (SUB-01, futuro) vai consumir. Esta tarefa **adiciona** uma chave
`subcube_geometry` ao retorno de `MapCompiler.compile()` — **todas as chaves
existentes ficam idênticas**, então o plano de gameplay (que lê as outras chaves)
não enxerga diferença → zero regressão.

Decisões de geometria (confirmadas pelo diretor de arte):

- **Parede = face fina, ancorada na ARESTA.** `wall_*` / `wallCorner_*` viram
  descritores de face (4 subcubos de largura × andar), posicionados sobre a aresta
  entre a célula de parede e o vizinho externo. A parede **não** preenche a célula.
- **O offset de straddle** (dividir a espessura entre os dois tiles vizinhos) é do
  **render (SUB-01)**, não desta costura. Aqui só ancoramos à aresta.
- **Bloco = sólido.** `block_*` (divisórias, colunas) → bloco sólido (footprint
  4×4 por andar).
- **Porta = vão.** `doorOpen_*` não emite descritor (no andar térreo). Andares
  superiores (parede acima da porta) emitem normalmente.
- **Piso e props: fora do escopo.** Piso é render-por-regra; props seguem sprites.

Disciplina de eixo (a pegadinha dos 4×4): esta costura trabalha em **andares**
(vertical fica em storeys; o render multiplica por `SUBCUBES_PER_FLOOR`). A única
razão usada aqui é a **horizontal** `SubcubeCoords.SUBCUBES_PER_UNIT_AXIS` (= 4,
largura da face / footprint). **Não** introduzir constante vertical aqui.

---

## MODULE

- `godot/scripts/world/maps/subcube_geometry.gd` — `class_name SubcubeGeometry` (NOVO)
- `godot/scripts/world/maps/map_compiler.gd` — edição aditiva mínima (preload + chave)
- `godot/scripts/tools/subcube_geometry_selftest.gd` — selftest headless (NOVO)

---

## TASK

### 1. Criar `godot/scripts/world/maps/subcube_geometry.gd` (conteúdo exato)

```gdscript
class_name SubcubeGeometry
## Costura (Master Plan FASE A / COORD-01-B): expande a geometria de Gameplay Units
## em DESCRITORES de subcubo para o plano de render. NÃO materializa subcubos
## individuais nem pixels — o render layer (SUB-01) expande os descritores e aplica
## o offset de straddle (espessura dividida entre tiles vizinhos).
##
##   wall_* / wallCorner_*  → FACE fina ancorada na ARESTA (4 de largura × andar)
##   block_*                → bloco SÓLIDO (footprint 4×4 × andar)
##   doorOpen_*             → vão (nenhum descritor no andar)
##   piso / props           → fora do escopo (render por regra / sprites)
##
## Vertical fica em ANDARES (storeys); o render multiplica por SUBCUBES_PER_FLOOR.
## Largura/footprint horizontal = SubcubeCoords.SUBCUBES_PER_UNIT_AXIS (= 4).

## sufixo de borda → arestas expostas (deltas em UNIT coords)
const _EDGE_BY_SUFFIX: Dictionary = {
	"NW": [Vector2i(0, -1)],
	"SE": [Vector2i(0,  1)],
	"SW": [Vector2i(-1, 0)],
	"NE": [Vector2i( 1, 0)],
}
## canto → as duas arestas expostas
const _CORNER_EDGES: Dictionary = {
	"NW": [Vector2i(0, -1), Vector2i(-1, 0)],
	"NE": [Vector2i(0, -1), Vector2i( 1, 0)],
	"SW": [Vector2i(0,  1), Vector2i(-1, 0)],
	"SE": [Vector2i(0,  1), Vector2i( 1, 0)],
}

## Constrói os descritores a partir do dict já compilado (usa "wall_levels").
static func build(compiled: Dictionary) -> Dictionary:
	var wall_levels: Array = compiled.get("wall_levels", [])
	var wall_faces: Array[Dictionary] = []
	var solid_blocks: Array[Dictionary] = []

	for storey in wall_levels.size():
		var course: Array = wall_levels[storey]
		for entry: Dictionary in course:
			var cell: Vector2i = entry["cell"]
			var tile_name: String = String(entry["tile_name"])

			if tile_name.begins_with("doorOpen_"):
				continue  ## vão — sem descritor neste andar

			elif tile_name.begins_with("wallCorner_"):
				var suffix: String = tile_name.trim_prefix("wallCorner_")
				for d: Vector2i in _CORNER_EDGES.get(suffix, []):
					wall_faces.append(_face(cell, d, storey, tile_name))

			elif tile_name.begins_with("wall_"):
				var suffix: String = tile_name.trim_prefix("wall_")
				for d: Vector2i in _EDGE_BY_SUFFIX.get(suffix, []):
					wall_faces.append(_face(cell, d, storey, tile_name))

			elif tile_name.begins_with("block_"):
				solid_blocks.append({
					"unit": cell,
					"storey": storey,
					"footprint_subcubes": SubcubeCoords.SUBCUBES_PER_UNIT_AXIS,
					"tile": tile_name,
				})
			## crate_* e outros não aparecem em wall_levels; ignorados por segurança.

	return {"wall_faces": wall_faces, "solid_blocks": solid_blocks}


static func _face(cell: Vector2i, edge_delta: Vector2i, storey: int, tile: String) -> Dictionary:
	return {
		"edge": {"from": cell, "to": cell + edge_delta},
		"storey": storey,
		"width_subcubes": SubcubeCoords.SUBCUBES_PER_UNIT_AXIS,
		"tile": tile,
	}
```

### 2. Editar `godot/scripts/world/maps/map_compiler.gd` (aditivo, mínimo)

**2a.** Junto dos outros `preload` (após `const MapGeometryClass = ...`), adicionar:

```gdscript
const SubcubeGeometryClass = preload("res://godot/scripts/world/maps/subcube_geometry.gd")
```

**2b.** No fim de `compile()`, trocar **apenas** o `return { ... }` por uma var +
a chave aditiva. Antes:

```gdscript
	return {
		"size":             map_size,
		...
		"exit_cells":       exit_cells,
	}
```

Depois (mesmas chaves, sem alterar nenhuma; só renomeia para `result`, adiciona a
chave de subcubo e retorna):

```gdscript
	var result: Dictionary = {
		"size":             map_size,
		...
		"exit_cells":       exit_cells,
	}
	result["subcube_geometry"] = SubcubeGeometryClass.build(result)
	return result
```

> Nenhuma outra linha do `map_compiler.gd` muda. As chaves existentes ficam
> idênticas em nome, ordem e valor.

### 3. Criar `godot/scripts/tools/subcube_geometry_selftest.gd` (conteúdo exato)

```gdscript
extends SceneTree
## Selftest headless de SubcubeGeometry (COORD-01-B).
## Rodar: godot --headless --script res://godot/scripts/tools/subcube_geometry_selftest.gd

func _initialize() -> void:
	var failures: int = 0

	## --- 1. Sala sintética 3x3, 1 andar, sem portas: anel de 8 paredes -> 12 faces
	var spec_a: Dictionary = {
		"inner_size": Vector2i(3, 3),
		"buffer": 0,
		"agent_start": Vector2i(1, 1),
		"floor_tile": "floor_SE",
	}
	var c_a: Dictionary = MapCompiler.compile(spec_a)

	if not c_a.has("subcube_geometry"):
		push_error("compile() sem chave subcube_geometry"); failures += 1
	for k in ["size", "wall_levels", "wall_tiles", "blocked_cells", "blocked_edges"]:
		if not c_a.has(k):
			push_error("chave original sumiu: %s" % k); failures += 1

	var sg_a: Dictionary = c_a.get("subcube_geometry", {})
	var faces_a: Array = sg_a.get("wall_faces", [])
	var blocks_a: Array = sg_a.get("solid_blocks", [])
	if faces_a.size() != 12:
		push_error("3x3: esperado 12 faces, veio %d" % faces_a.size()); failures += 1
	if blocks_a.size() != 0:
		push_error("3x3: esperado 0 blocos, veio %d" % blocks_a.size()); failures += 1
	for f: Dictionary in faces_a:
		var from: Vector2i = f["edge"]["from"]
		var to: Vector2i = f["edge"]["to"]
		var dd: Vector2i = (to - from).abs()
		if dd.x + dd.y != 1:
			push_error("face com aresta nao-cardinal: %s" % f); failures += 1
		if int(f["width_subcubes"]) != 4:
			push_error("face com largura != 4: %s" % f); failures += 1
	var nw_edges: Array = []
	for f: Dictionary in faces_a:
		if String(f["tile"]) == "wallCorner_NW":
			nw_edges.append(f["edge"]["to"] - f["edge"]["from"])
	if not (nw_edges.has(Vector2i(0, -1)) and nw_edges.has(Vector2i(-1, 0))):
		push_error("wallCorner_NW nao gerou as 2 arestas esperadas: %s" % str(nw_edges)); failures += 1

	## --- 2. Divisória vira bloco sólido; porta vira vão (andar 0)
	var spec_b: Dictionary = {
		"inner_size": Vector2i(5, 5),
		"buffer": 0,
		"agent_start": Vector2i(2, 2),
		"floor_tile": "floor_SE",
		"access_points": [{"cell": Vector2i(2, 0)}],          ## porta na borda NW
		"dividers": [{"cells": [Vector2i(2, 2)]}],            ## 1 divisória interna
	}
	var c_b: Dictionary = MapCompiler.compile(spec_b)
	var sg_b: Dictionary = c_b.get("subcube_geometry", {})
	if (sg_b.get("solid_blocks", []) as Array).is_empty():
		push_error("divisoria nao gerou solid_block"); failures += 1
	for f: Dictionary in sg_b.get("wall_faces", []):
		if f["edge"]["from"] == Vector2i(2, 0) and int(f["storey"]) == 0:
			push_error("porta (2,0) gerou face no andar 0 (deveria ser vao)"); failures += 1

	## --- 3. Smoke test com SIGMA-01 real: tudo cardinal/largura 4; portas sem face
	var c_s: Dictionary = MapCompiler.compile(Sigma01Map.spec())
	var sg_s: Dictionary = c_s.get("subcube_geometry", {})
	for f: Dictionary in sg_s.get("wall_faces", []):
		var dd2: Vector2i = (Vector2i(f["edge"]["to"]) - Vector2i(f["edge"]["from"])).abs()
		if dd2.x + dd2.y != 1 or int(f["width_subcubes"]) != 4:
			push_error("SIGMA-01 face invalida: %s" % f); failures += 1
	## portas SIGMA-01 (inner (9,0) e (9,35) + buffer 5) = (14,5) e (14,40): sem face andar 0
	for f: Dictionary in sg_s.get("wall_faces", []):
		var fr: Vector2i = f["edge"]["from"]
		if (fr == Vector2i(14, 5) or fr == Vector2i(14, 40)) and int(f["storey"]) == 0:
			push_error("SIGMA-01 porta com face no andar 0: %s" % f); failures += 1

	if failures == 0:
		print("COORD-01-B SELFTEST: PASS")
		quit(0)
	else:
		print("COORD-01-B SELFTEST: FAIL (%d falhas)" % failures)
		quit(1)
```

---

## DO NOT TOUCH

- **Qualquer chave existente** do retorno de `compile()` — nome, ordem e valor
  idênticos. A única mudança é a chave aditiva `subcube_geometry` + o preload.
- **Nenhum outro arquivo** além dos três do MODULE. Sem wiring no `room.gd` ou render.
- **Sem pixels, sem offset de straddle, sem `map_to_local`** — isso é do SUB-01.
- **Sem constante vertical** (`SUBCUBES_PER_FLOOR`, `SUBCUBE_STEP_PX`) — a costura é
  em andares. Sem materializar subcubos individuais (só descritores).
- **Sem piso, sem props** na `subcube_geometry`.

---

## ACCEPTANCE

### Correção (gate — selftest headless)

```bash
godot --headless --script res://godot/scripts/tools/subcube_geometry_selftest.gd
# espera-se: "COORD-01-B SELFTEST: PASS" e exit code 0
```

### Estrutural (grep)

```bash
grep -nE 'class_name SubcubeGeometry' godot/scripts/world/maps/subcube_geometry.gd
grep -cE 'static func (build|_face)\(' godot/scripts/world/maps/subcube_geometry.gd  # 2
grep -nE 'SubcubeCoords\.SUBCUBES_PER_UNIT_AXIS' godot/scripts/world/maps/subcube_geometry.gd  # usa razão horizontal
grep -nE 'SUBCUBES_PER_FLOOR|SUBCUBE_STEP_PX|map_to_local' godot/scripts/world/maps/subcube_geometry.gd  # espera-se: VAZIO
```

### Mudança aditiva e mínima no compiler

```bash
grep -nE 'SubcubeGeometryClass' godot/scripts/world/maps/map_compiler.gd   # preload + 1 uso
grep -nE 'result\["subcube_geometry"\] = SubcubeGeometryClass\.build' godot/scripts/world/maps/map_compiler.gd
# diff do map_compiler.gd deve conter SOMENTE: +preload, return->var result, +2 linhas.
git diff --stat godot/scripts/world/maps/map_compiler.gd
```

### Isolamento (sem wiring prematuro)

```bash
grep -rn 'SubcubeGeometry' godot/scripts
# espera-se SOMENTE: subcube_geometry.gd (def) + map_compiler.gd (uso) + selftest.
```

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

---

**Escopo:** 1 arquivo novo + 1 edição aditiva + selftest · 1 sessão. Sem render,
sem pixels, sem vertical, sem piso/props.
