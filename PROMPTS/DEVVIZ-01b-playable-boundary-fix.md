# DEVVIZ-01b — Fix: Boundary na Área Jogável (não no buffer)

> **Natureza:** 2 arquivos · 2 str_replace.
> **Pré-requisito:** DEVVIZ-01 aplicado (`_draw_playable_boundary()` existe em room.gd).

---

## CONTEXT

O `map_compiler.gd` não expõe `buffer` nem `inner_size` no layout dict — só
repassa `"size"` = map_size total. Room.gd usa `_room_size` (= map_size total)
e a linha acaba sendo desenhada na borda exterior do buffer, não em volta da
área jogável.

**Fix:** adicionar `"playable_rect": Rect2i(offset, inner_size)` ao dict de
resultado do compiler. Room.gd lê esse rect de `_base_layout` e desenha a
linha nos 4 vértices corretos.

**Verificação rápida com PLAYGROUND (buffer=1, inner=8×8):**

```
offset = (1,1) · inner = (8,8)
playable_rect = Rect2i(Vector2i(1,1), Vector2i(8,8))

N = map_to_local(1, 1)         → vértice topo do tile (1,1)
E = map_to_local(1+8, 1)       → vértice right de (8,1)
S = map_to_local(1+8, 1+8)     → vértice bottom de (8,8)
W = map_to_local(1, 1+8)       → vértice left de (1,8)
```

A linha passa pelo limite interior das paredes — exatamente onde o chão
jogável começa.

---

## MODULE

- `godot/scripts/world/maps/map_compiler.gd` — adicionar `"playable_rect"` ao result dict.
- `godot/scripts/world/room.gd` — atualizar `_draw_playable_boundary()`.

---

## TASK

### 1. `map_compiler.gd` — Adicionar `playable_rect` ao result dict

**str_replace** — localizar:

```
	var result: Dictionary = {
		"size":             map_size,
		"agent_start_cell": agent_start_raw,
```

**Substituir por:**

```
	var result: Dictionary = {
		"size":             map_size,
		"playable_rect":    Rect2i(offset, inner_size),   ## inner playable area in grid coords
		"agent_start_cell": agent_start_raw,
```

---

### 2. `room.gd` — Atualizar `_draw_playable_boundary()`

**str_replace** — localizar o corpo completo da função atual:

```
func _draw_playable_boundary() -> void:
	## Linha vermelha fina ao redor da área jogável. Visível apenas em DEV_VISION.
	## Traça os 4 vértices extremos do floor grid no espaço world do Room node.
	if not _vision_controller.dev_vision:
		return
	if _room_size == Vector2i.ZERO or floor_layer == null:
		return

	var W: int = _room_size.x
	var H: int = _room_size.y
	var off: Vector2 = VISUAL_GRID_OFFSET

	var n: Vector2 = floor_layer.map_to_local(Vector2i(0, 0)) + off
	var e: Vector2 = floor_layer.map_to_local(Vector2i(W, 0)) + off
	var s: Vector2 = floor_layer.map_to_local(Vector2i(W, H)) + off
	var w: Vector2 = floor_layer.map_to_local(Vector2i(0, H)) + off

	draw_polyline(
		PackedVector2Array([n, e, s, w, n]),
		Color(1.0, 0.15, 0.15, 0.90),
		2.5,
		true   ## antialiased
	)
```

**Substituir por:**

```
func _draw_playable_boundary() -> void:
	## Linha vermelha fina ao redor da área JOGÁVEL (excluindo o buffer ring).
	## Visível apenas em DEV_VISION.
	if not _vision_controller.dev_vision:
		return
	if floor_layer == null or _base_layout.is_empty():
		return

	## playable_rect: Rect2i(offset, inner_size) — injetado pelo MapCompiler.
	## Fallback para _room_size inteiro quando não disponível (mapas legados).
	var pr: Rect2i = _base_layout.get("playable_rect", Rect2i(Vector2i.ZERO, _room_size))
	var origin: Vector2i = pr.position
	var size:   Vector2i = pr.size
	var off:    Vector2  = VISUAL_GRID_OFFSET

	var n: Vector2 = floor_layer.map_to_local(origin) + off
	var e: Vector2 = floor_layer.map_to_local(origin + Vector2i(size.x, 0)) + off
	var s: Vector2 = floor_layer.map_to_local(origin + size) + off
	var w: Vector2 = floor_layer.map_to_local(origin + Vector2i(0, size.y)) + off

	draw_polyline(
		PackedVector2Array([n, e, s, w, n]),
		Color(1.0, 0.15, 0.15, 0.90),
		2.5,
		true
	)
```

---

## DO NOT TOUCH

- Restante do result dict do `map_compiler.gd` — apenas 1 linha adicionada.
- `_draw()` em `room.gd` — não muda (já chama `_draw_playable_boundary()`).
- `_room_size` — continua sendo o tamanho total (usado pelo pathfinder, FOW, etc.).

---

## ACCEPTANCE

```bash
## Parse check
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## playable_rect presente no compiler
grep -n "playable_rect" godot/scripts/world/maps/map_compiler.gd
# esperado: 1 ocorrência

## playable_rect lido em room.gd
grep -n "playable_rect" godot/scripts/world/room.gd
# esperado: 1 ocorrência

## Apenas 2 arquivos alterados
git diff --name-only
# esperado: map_compiler.gd + room.gd
```

**Visualmente em DEV_VISION:**

- A linha vermelha agora circula a BORDA INTERIOR das paredes — o limite
  exato onde o chão jogável começa.
- Tiles do buffer ring (fora das paredes) ficam fora da linha.
- Confirma visualmente se as paredes estão alinhadas com o grid jogável.

---

**Escopo:** 2 arquivos · 2 str_replace · 3 linhas net adicionadas.
