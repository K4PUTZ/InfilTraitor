# JUNCTION-02 — Patch: Reescrever detecção de V-junction (célula errada)

> **Pré-requisito:** JUNCTION-01 aplicado (`registry.register_edge()` sendo
> chamado; sem isso `resolve()` não tem nada pra iterar e nada do que segue
> importa).
> **Natureza:** correção de resultado — colunas agora aparecem, mas na
> célula errada, sobrepondo geometria de parede já existente (invisíveis).
> Substitui inteiramente `_edge_covers_corner`/`_get_corner_gus`/
> `_corner_gu_to_voxel` por um algoritmo em espaço GU puro, sem
> reconstrução a partir de coordenadas de vértice de voxel.
> **Correção de registro:** o teste sintético adicionado pelo JUNCTION-01
> (`geometry_selftest.gd`) afirmava `gu_cell == Vector2i(2, 2)` pro caso do
> cotovelo — esse valor esperado estava errado, é reescrito aqui pro valor
> correto `(2, 3)`, verificado à mão por adjacência de grid pura,
> independente da implementação.

---

## CONTEXT

Print/screenshot em anexo confirma o diagnóstico do diretor: o operador
calcula a coluna extra na célula **de dentro** do cotovelo (sobrepõe voxels
de parede já desenhados ali — por isso "some"), quando deveria calcular a
célula **diagonal, do lado de fora** dos dois segmentos de parede.

Causa raiz: `_get_edge_vertices()` produz vértices onde um dos dois eixos
usa o offset "quase-borda" `+7` (índice de voxel local máximo dentro de uma
célula 8×8) em vez do múltiplo limpo de 8 que marcaria a fronteira real
entre duas células. `_get_corner_gus()` então faz `vertex.x / 8` e
`vertex.y / 8` — divisão inteira — assumindo que o vértice cai exatamente
numa fronteira limpa. Pra um vértice como `(24, 23)`: o eixo X (24) é limpo
(`24/8 = 3`, correto), mas o eixo Y (23) não é — é o índice local 7 dentro
da linha `gu_y=2`, e deveria representar a fronteira entre a linha 2 e a
linha 3. `23/8 = 2` (truncado), não 3. Isso desloca todo o bloco 2×2 de GUs
candidatos pra um conjunto errado.

Verificação numérica (à mão, independente do código): elbow em `(3,2)` com
paredes nas faces NW (contra `(2,2)`) e SW (contra `(3,3)`). As 4 células
que realmente compartilham esse ponto de canto, por adjacência pura de grid
2×2, são `{(2,2), (3,2), (2,3), (3,3)}` — a diagonal correta é `(2,3)`. O
código antigo (`_get_corner_gus` a partir do vértice `(24,23)`) calculava
`{(2,1), (3,1), (3,2), (2,2)}` — um conjunto **completamente diferente**,
que nem contém `(2,3)`. É por isso que a coluna cai sempre do lado errado,
independentemente de qualquer ajuste na contagem de cobertura (o fix do
JUNCTION-01 pra `_edge_covers_corner` foi necessário mas não suficiente —
operava sobre a lista de candidatos já errada).

**Correção:** eliminar a etapa de vértice-de-voxel inteiramente pra
detecção. Cada `Edge` já sabe exatamente quais faces toca em quais células
(`face_a`/`face_b`, `gu_a`/`gu_b`) — usar isso direto. Pra qualquer célula
com exatamente 2 paredes em faces adjacentes (não-opostas), a diagonal
correta é `célula + Face.delta(fa) + Face.delta(fb)`. Sem arredondamento,
sem vértice, sem espaço de voxel até o último passo (escolher qual dos 64
voxels daquela célula fica exatamente na quina).

---

## MODULE

- `godot/scripts/geometry/junction_resolver.gd` *(reescrita completa)*
- `godot/scripts/tools/geometry_selftest.gd` *(substituir grupo de teste)*

---

## TASK

### 1. `junction_resolver.gd` — Substituir o arquivo inteiro

**Apagar todo o conteúdo do arquivo e substituir por:**

```gdscript
## Geometry Module — Junction Resolver: fills V-junction corner columns.
## Rewritten (JUNCTION-02): the previous version reconstructed GU cells from
## voxel-index vertex coordinates and divided them back down by 8. That broke
## whenever a vertex used the "+7" near-edge offset (true for one axis of
## almost every vertex _get_edge_vertices produced) instead of a clean
## multiple of 8 — integer division silently floored into the wrong bucket,
## so the resolver picked a cell adjacent to the elbow instead of the true
## diagonal notch. This version never touches voxel coordinates for the
## detection step: it stays in GU-cell space the whole time, using the faces
## already recorded on each Edge.
## Scope: pure V-junctions only (exactly 2 walls meeting at one cell). T/X
## junctions (3–4 walls at a cell) are intentionally skipped — see JUNCTION-01b.
class_name JunctionResolver


## Container for a corner column at a V-junction.
class JunctionColumn:
	var gu_cell: Vector2i         ## the diagonal GU that owns this column (outside the elbow)
	var voxel_pos: Vector2i       ## the voxel position of the column
	var storey_count: int         ## height (max of the two adjacent edges' storey_count)
	var voxels: Array[Voxel]      ## the voxel objects
	
	func _init(p_gu: Vector2i, p_voxel_pos: Vector2i, p_storey_count: int):
		gu_cell = p_gu
		voxel_pos = p_voxel_pos
		storey_count = p_storey_count
		voxels = []
	
	func _to_string() -> String:
		return "JunctionColumn{gu=%s, voxel=%s, storeys=%d}" % [gu_cell, voxel_pos, storey_count]


## Resolve V-junctions from a registry of edges.
## Returns an Array of JunctionColumn objects, one per detected elbow.
static func resolve(registry: EdgeRegistry) -> Array:
	var result: Array = []
	var cells_seen: Dictionary = {}  ## Vector2i -> true; each edge touches 2 cells, visit each once
	
	for edge in registry.all_edges():
		for gu in [edge.gu_a, edge.gu_b]:
			if cells_seen.has(gu):
				continue
			cells_seen[gu] = true
			
			## Which faces of THIS cell have a wall, and which Edge put it there.
			var faces_at_cell: Dictionary = {}  ## face(int) -> Edge
			for e in registry.edges_touching_gu(gu):
				var face_here: int = e.face_a if e.gu_a == gu else e.face_b
				faces_at_cell[face_here] = e
			
			## Pure V-junction only: exactly 2 walls at this cell. 1 wall =
			## plain wall segment, nothing to close. 3–4 walls = T/X, out
			## of scope here (see class doc comment).
			if faces_at_cell.size() != 2:
				continue
			
			var faces: Array = faces_at_cell.keys()
			var fa: int = faces[0]
			var fb: int = faces[1]
			
			## Opposite faces (NW-SE or NE-SW) = a straight wall passing
			## through the cell, not a turn. No column needed.
			if fb == Face.opposite(fa):
				continue
			
			var edge_a: Edge = faces_at_cell[fa]
			var edge_b: Edge = faces_at_cell[fb]
			
			## fa, fb adjacent and non-opposite → their deltas sum to a
			## clean (±1, ±1): the cell diagonal to the elbow, outside both
			## walls — the visual notch that needs the filler column.
			var d: Vector2i = Face.delta(fa) + Face.delta(fb)
			var diagonal_cell: Vector2i = gu + d
			var max_storey: int = maxi(edge_a.storey_count, edge_b.storey_count)
			
			## The one voxel inside diagonal_cell nearest the elbow — the
			## corner of its 8×8 block that actually touches `gu`.
			var origin := GeometryCoords.gu_to_voxel_origin(diagonal_cell)
			var last := GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
			var local_x := last if d.x < 0 else 0
			var local_y := last if d.y < 0 else 0
			var voxel_pos := origin + Vector2i(local_x, local_y)
			
			result.append(JunctionColumn.new(diagonal_cell, voxel_pos, max_storey))
	
	return result
```

> Nenhuma outra classe do módulo muda: `JunctionColumn` mantém exatamente os
> mesmos 4 campos (`gu_cell`, `voxel_pos`, `storey_count`, `voxels`), então
> `voxel_renderer.gd::_render_junction_column()` não precisa de nenhuma
> alteração — ele só lê `column.storey_count` e `column.voxel_pos`.

---

### 2. `geometry_selftest.gd` — Substituir grupo de teste do JunctionResolver

**Localizar** o bloco inteiro que começa em:

```gdscript
	# GROUP: JunctionResolver — V-junction corner detection (fix for the
```

e termina logo antes de:

```gdscript
	for name_key in classes:
```

(inclui a declaração de `JunctionResolverClass`, `EdgeClass`,
`EdgeRegistryClass`, `SliceGeneratorClass`, e o bloco `l_registry`/
`l_columns` com a asserção `Vector2i(2, 2)` — esse é exatamente o teste que
o JUNCTION-01 introduziu e que carrega o valor esperado errado.)

**Substituir por:**

```gdscript
	# GROUP: JunctionResolver — V-junction corner detection (JUNCTION-02
	# rewrite: the previous voxel-vertex approach silently picked the wrong
	# diagonal cell — see junction_resolver.gd header. Both cases below were
	# re-derived from plain GU-grid adjacency, independent of the
	# implementation under test.
	print("\nGROUP: JunctionResolver — V-junction detection")
	var JunctionResolverClass = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeClass = load("res://godot/scripts/geometry/edge.gd")
	var EdgeRegistryClass = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass = load("res://godot/scripts/geometry/slice_generator.gd")

	# Case 1 — matches the reported screenshot: a rectangular room's actual
	# top-left interior corner. Cell (2,2) has a wall on its NE face (north
	# perimeter, vs 2,1) and its NW face (west perimeter, vs 1,2). The open
	# diagonal notch — outside both walls — is (1,1).
	var corner_registry = EdgeRegistryClass.new()
	var north_wall = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1)  # NE face of (2,2)
	var west_wall = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)   # NW face of (2,2)
	SliceGeneratorClass.generate([north_wall, west_wall], corner_registry)
	var corner_columns = JunctionResolverClass.resolve(corner_registry)
	total_count += 1
	if corner_columns.size() == 1 and corner_columns[0].gu_cell == Vector2i(1, 1):
		pass_count += 1
		print("  ✓ Room corner (walls at 2,2) produces exactly 1 column at GU (1,1): %s" % corner_columns[0])
	else:
		print("  ✗ Room corner produced %d column(s): %s — expected exactly 1 at GU (1,1)" % [corner_columns.size(), corner_columns])

	# Case 2 — an elbow one step over: SE face of (2,2) turning into SW face
	# of (3,2). Cross-checked by hand against plain 2×2-block grid adjacency:
	# (2,2)/(3,2) share their far edge with (2,3)/(3,3), so the cell diagonal
	# to elbow (3,2) is (2,3) — NOT (2,2). (JUNCTION-01's test asserted (2,2)
	# here; that assertion was wrong, a byproduct of the same vertex-bucket
	# bug this rewrite removes — corrected now.)
	var l_registry = EdgeRegistryClass.new()
	var l_edge_a = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	var l_edge_b = EdgeClass.between(Vector2i(3, 2), Vector2i(3, 3), 1)  # SW face of (3,2)
	SliceGeneratorClass.generate([l_edge_a, l_edge_b], l_registry)
	var l_columns = JunctionResolverClass.resolve(l_registry)
	total_count += 1
	if l_columns.size() == 1 and l_columns[0].gu_cell == Vector2i(2, 3):
		pass_count += 1
		print("  ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,3): %s" % l_columns[0])
	else:
		print("  ✗ L-corner produced %d column(s): %s — expected exactly 1 at GU (2,3)" % [l_columns.size(), l_columns])

	# Negative case: straight wall through a cell (opposite faces) — a
	# corridor passing through (2,2), not a turn. Must NOT produce a column.
	var straight_registry = EdgeRegistryClass.new()
	var s_edge_a = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)  # NW face of (2,2)
	var s_edge_b = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	SliceGeneratorClass.generate([s_edge_a, s_edge_b], straight_registry)
	var straight_columns = JunctionResolverClass.resolve(straight_registry)
	total_count += 1
	if straight_columns.is_empty():
		pass_count += 1
		print("  ✓ Straight-through wall (opposite faces) produces 0 columns")
	else:
		print("  ✗ Straight-through wall produced %d column(s), expected 0: %s" % [straight_columns.size(), straight_columns])

```

---

## DO NOT TOUCH

- `voxel_renderer.gd` — `_render_junction_column()` e `render()` continuam
  corretos, `JunctionColumn` não muda de forma.
- `room_builder.gd` — já chama `JunctionResolver.resolve()` e passa o
  resultado adiante corretamente; nada muda na assinatura.
- `EdgeRegistry`, `SliceGenerator`, `Edge`, `Face` — não fazem parte deste
  bug; só são consumidos.
- `room.gd::_build_room()` (linha 1561) — tem sua própria cópia morta
  (nunca chamada, resíduo do Task 07/RoomBuilder) que também chama
  `JunctionResolver.resolve()`. Como a assinatura da função não muda, ela
  continua morta e inofensiva. Não faz parte deste patch — fica anotada
  pro próximo ciclo de faxina (mesma família do `_layout_with_perspective`
  morto que o ENHANCE-04b já limpou em `room.gd`).

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Heurística de vértice/distância totalmente removida
grep -n "_get_edge_vertices\|_get_corner_gus\|_edge_covers_corner\|_corner_gu_to_voxel\|distance_to" godot/scripts/geometry/junction_resolver.gd
# esperado: vazio (0 resultados)

## Selftest passa, incluindo os 3 casos novos
godot --headless --script res://godot/scripts/tools/geometry_selftest.gd
# esperado:
#   ✓ Room corner (walls at 2,2) produces exactly 1 column at GU (1,1)
#   ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,3)
#   ✓ Straight-through wall (opposite faces) produces 0 columns

## Apenas os 2 arquivos do MODULE mudaram
git diff --name-only
```

**Smoke visual** — o mesmo mapa da screenshot em anexo: carregar, olhar os
4 cantos da sala retangular. Cada canto deve ganhar 1 coluna de voxel na
célula diagonal **fora** da sala (onde estava marcado rosa), não sobre a
geometria de parede já existente. Altura da coluna igual à altura das duas
paredes que formam aquele canto.

---

**Escopo:** 2 arquivos · reescrita completa de 1 classe + teste · 1 sessão.
**Próximo:** JUNCTION-01b (T e X junctions) fica pra depois de confirmar V
em jogo nos 4 cantos — a imagem de referência já mostra que essas duas não
precisam de coluna extra, mas isso merece verificação própria com o novo
algoritmo em espaço GU (provavelmente um `faces_at_cell.size() == 3`
ou `== 4` tratados à parte, não simplesmente ignorados como agora).
