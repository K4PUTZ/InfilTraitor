# JUNCTION-01 — Patch: Corrigir coluna extra ausente no V-junction (esquina L)

> **Pré-requisito:** SLICE-02 aplicado (voxels funcionando; screenshot em anexo
> confirma parede reta OK).
> **Natureza:** 2 bugs empilhados no caminho V-junction, um mascarando o outro.
> `JunctionResolver` existe, está plugado corretamente em `room_builder.gd` e
> `voxel_renderer.gd`, mas nunca produz nenhuma coluna em runtime.
> **Escopo:** 2 arquivos de produção + 1 arquivo de selftest. Nenhuma mudança
> de contrato público.

---

## CONTEXT

Comportamento esperado (ver referência anexa — diagrama V/T/X junction):
numa esquina em L, os dois voxels de parede que se encontram em 90° deixam
uma quina vazia na diagonal externa; falta 1 coluna de voxel ali pra fechar
visualmente. `JunctionResolver.resolve()` já implementa essa detecção e
`VoxelRenderer._render_junction_column()` já sabe desenhar a coluna — o problema
é que a coluna nunca chega a ser calculada.

**Bug 1 — `EdgeRegistry.register_edge()` nunca é chamado em lugar nenhum do
repo.** `SliceGenerator.generate()` (o único ponto que povoa o registry a
partir das edges extraídas) só chama `registry.register_slice()` pra cada
slice — nunca `registry.register_edge()`. Resultado: `registry.all_edges()`
retorna sempre `[]`. `JunctionResolver.resolve(registry)` começa iterando
exatamente essa lista (linha 31: `for edge in registry.all_edges()`) — com
ela vazia, a função não tem nada pra processar e retorna `[]` sempre,
independente de qualquer outra lógica estar certa ou errada.

**Bug 2 — mesmo com a lista de edges povoada, `_edge_covers_corner()` usa uma
heurística de distância em vez de adjacência exata:**

```gdscript
if (edge.gu_a.distance_to(corner_gu) <= 2 or edge.gu_b.distance_to(corner_gu) <= 2):
    return true
```

Uma edge só toca exatamente 2 GUs (`gu_a`, `gu_b`) — nunca um terceiro por
proximidade. Esse teste de distância super-conta: marca como "cobrindo" GUs
que a edge nem encosta, inflando `edge_count` pra 2 em cantos que deveriam
contar 1. Como `resolve()` só adiciona coluna quando `edge_count == 1`
(V-junction real), esse falso positivo mascararia o corner mesmo depois do
Bug 1 corrigido.

Os dois juntos explicam o sintoma da screenshot: parede reta renderiza (não
depende do JunctionResolver), mas nenhuma quina em L nunca ganha a coluna
extra — o pipeline de V-junction está morto de ponta a ponta.

---

## MODULE

- `godot/scripts/geometry/slice_generator.gd`
- `godot/scripts/geometry/junction_resolver.gd`
- `godot/scripts/tools/geometry_selftest.gd`

---

## TASK

### 1. `slice_generator.gd` — Registrar a edge no registry

**Localizar:**

```gdscript
	for edge in edges:
		if not (edge is Edge):
			push_error("SliceGenerator.generate: non-Edge object in edges array")
			continue
		
		# Create slice A (on gu_a, face_a)
```

**Substituir por:**

```gdscript
	for edge in edges:
		if not (edge is Edge):
			push_error("SliceGenerator.generate: non-Edge object in edges array")
			continue
		
		# Register the edge itself. Without this, EdgeRegistry.all_edges()
		# stays empty forever — JunctionResolver.resolve() iterates it to
		# find V-junctions, so a missing register_edge() here silently
		# produces zero corner columns regardless of how correct the
		# junction math is. register_edge() was defined but never called
		# anywhere in the codebase before this fix.
		registry.register_edge(edge)
		
		# Create slice A (on gu_a, face_a)
```

---

### 2. `junction_resolver.gd` — Trocar heurística de distância por adjacência exata

**Localizar:**

```gdscript
## Check if an edge covers a corner GU at the given vertex
static func _edge_covers_corner(edge: Edge, corner_gu: Vector2i, vertex: Vector2i) -> bool:
	# An edge covers a corner if:
	# 1. One end of the edge is adjacent to corner_gu
	# 2. The edge's vertex matches the given vertex
	
	# Simplified: check if either gu_a or gu_b is adjacent to corner_gu
	# and the edge's voxel vertices include the given vertex
	
	var edge_verts := _get_edge_vertices(edge)
	if vertex not in edge_verts:
		return false
	
	# Also check that one GU is actually adjacent to the corner
	if (edge.gu_a.distance_to(corner_gu) <= 2 or edge.gu_b.distance_to(corner_gu) <= 2):
		return true
	
	return false
```

**Substituir por:**

```gdscript
## Check if an edge covers a corner GU at the given vertex
static func _edge_covers_corner(edge: Edge, corner_gu: Vector2i, vertex: Vector2i) -> bool:
	# An edge covers a corner if:
	# 1. The edge's vertex matches the given vertex
	# 2. corner_gu is exactly one of the edge's two owning cells (gu_a/gu_b) —
	#    an edge only ever touches those two GUs, never a third one nearby.
	#    A distance-based check here over-counts: it also matches GUs the
	#    edge doesn't actually border, which masks real V-junctions by
	#    inflating edge_count above 1.
	var edge_verts := _get_edge_vertices(edge)
	if vertex not in edge_verts:
		return false
	
	return corner_gu == edge.gu_a or corner_gu == edge.gu_b
```

---

### 3. `geometry_selftest.gd` — Grupo de teste sintético do L-corner

**Localizar:**

```gdscript
	for name_key in classes:
		total_count += 1
		var class_path = classes[name_key]
		var cls = load(class_path)
		if cls != null:
```

**Inserir logo antes:**

```gdscript
	# GROUP: JunctionResolver — V-junction corner detection (fix for the
	# missing-column bug: register_edge() was never called, so resolve()
	# always iterated an empty edge list; and _edge_covers_corner used a
	# distance heuristic that over-counted and suppressed real corners).
	print("\nGROUP: JunctionResolver — V-junction detection")
	var JunctionResolverClass = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeClass = load("res://godot/scripts/geometry/edge.gd")
	var EdgeRegistryClass = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass = load("res://godot/scripts/geometry/slice_generator.gd")

	# Positive case: an L — wall on the SE face of (2,2) [border with (3,2)]
	# turning into the SW face of (3,2) [border with (3,3)]. The two edges
	# share GU (3,2) as the elbow. Hand-verified: they share voxel vertex
	# (24,23); of the 4 corner GUs around that vertex, (3,2) is touched by
	# both edges (fully covered — no gap) and (2,2) is touched by exactly
	# one (the visual notch the V-junction column must fill).
	var l_registry = EdgeRegistryClass.new()
	var l_edge_a = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	var l_edge_b = EdgeClass.between(Vector2i(3, 2), Vector2i(3, 3), 1)  # SW face of (3,2)
	SliceGeneratorClass.generate([l_edge_a, l_edge_b], l_registry)
	var l_columns = JunctionResolverClass.resolve(l_registry)
	total_count += 1
	if l_columns.size() == 1 and l_columns[0].gu_cell == Vector2i(2, 2):
		pass_count += 1
		print("  ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,2): %s" % l_columns[0])
	else:
		print("  ✗ L-corner produced %d column(s): %s — expected exactly 1 at GU (2,2)" % [l_columns.size(), l_columns])

```

> Nota: este grupo só cobre o caso positivo (L-corner canônico), verificado
> à mão passo a passo (vértice compartilhado, os 4 GUs candidatos, contagem
> de cobertura). Não incluí caso negativo — tentei um par de edges paralelas
> pra testar "parede reta = 0 colunas" e percebi que, nessa geometria, uma
> edge isolada sem vizinho perpendicular também gera coluna nas próprias
> pontas (comportamento provavelmente correto — tampa de topo de parede solta
> — mas não verificado). Se quiser essa cobertura, é um prompt à parte depois
> de confirmar visualmente o comportamento esperado pra pontas soltas e
> T-junctions (a régua da imagem 2 já mostra que T e X não precisam de coluna
> extra — vale um teste dedicado pra isso quando o V estiver validado em jogo).

---

## DO NOT TOUCH

- `VoxelRenderer._render_junction_column()` e `render()` — já corretos, só
  não recebiam colunas pra desenhar.
- `_get_edge_vertices`, `_get_corner_gus`, `_corner_gu_to_voxel`,
  `_max_storey_of_edges` — não fazem parte deste bug.
- `room_builder.gd` — já chama `JunctionResolver.resolve()` e passa o
  resultado pro renderer corretamente; nada a mudar lá.
- Qualquer arquivo de `world/` fora do já listado.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## register_edge agora é chamado
grep -n "registry.register_edge(edge)" godot/scripts/geometry/slice_generator.gd
# esperado: 1 resultado

## Heurística de distância removida
grep -n "distance_to" godot/scripts/geometry/junction_resolver.gd
# esperado: vazio (0 resultados)

## Selftest passa, incluindo o grupo novo
godot --headless --script res://godot/scripts/tools/geometry_selftest.gd
# esperado: "✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,2)"

## Apenas os 3 arquivos do MODULE mudaram
git diff --name-only
```

**Smoke visual** (o que realmente importa aqui): carregar um mapa com pelo
menos 1 esquina em L de paredes (ex. o próprio room da screenshot em anexo —
ele já tem 4 cantos de sala retangular, todos deveriam ganhar a coluna).
Comparar antes/depois: cada canto externo deve fechar sem falha visível na
quina. Height igual ao das paredes adjacentes (`storey_count` = máximo das
duas edges que formam o canto).

---

**Escopo:** 3 arquivos · 2 correções + 1 grupo de teste · 1 sessão.
**Próximo:** com V confirmado em jogo, vale um JUNCTION-01b específico pra
T e X (a imagem de referência já mostra que essas duas não precisam de
coluna extra — "missing column is naturally filled" / "4 overlapping" — mas
isso merece verificação própria, não assumir que o mesmo fix cobre os 3
casos).
