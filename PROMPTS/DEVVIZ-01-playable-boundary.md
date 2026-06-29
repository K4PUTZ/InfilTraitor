# DEVVIZ-01 — DEV_VISION: Boundary da Área Jogável

> **Natureza:** 1 arquivo · 2 str_replace em `room.gd`.
> **Pré-requisito:** nenhum.

---

## CONTEXT

Em DEV_VISION, o designer precisa ver claramente onde termina a área jogável.
Atualmente não há indicador — a borda da sala só é inferida pela posição das
paredes. Uma linha vermelha fina traçando o perímetro do grid de chão resolve
isso sem poluir a visão de gameplay.

**Geometria:** o floor grid abrange cells `(0,0)` até `(_room_size - 1)`.
Em DIAMOND_DOWN 256×128, os quatro vértices extremos do grid são exatamente:

```
N = floor_layer.map_to_local(Vector2i(0,       0      ))  # top vertex de (0,0)
E = floor_layer.map_to_local(Vector2i(W,       0      ))  # right vertex de (W-1, 0)
S = floor_layer.map_to_local(Vector2i(W,       H      ))  # bottom vertex de (W-1, H-1)
W = floor_layer.map_to_local(Vector2i(0,       H      ))  # left vertex de (0, H-1)
```

Todos somados a `VISUAL_GRID_OFFSET` para ficar no espaço visual do Room.

---

## MODULE

- `godot/scripts/world/room.gd` — `_draw()` + nova função `_draw_playable_boundary()`.

---

## TASK

### 1. Adicionar `_draw_playable_boundary()` após `_draw_spawn_marker()`

Inserir a nova função **imediatamente após** `func _draw_spawn_marker() -> void: ...`
(que termina com o `draw_polyline` do spawn marker).

Adicionar **após** o bloco `_draw_spawn_marker()`:

```gdscript
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

---

### 2. Chamar `_draw_playable_boundary()` em `_draw()`

**str_replace** — localizar:

```
func _draw() -> void:
	_draw_exit_markers()
	_draw_spawn_marker()
	_draw_shadow_debug()
```

**Substituir por:**

```
func _draw() -> void:
	_draw_exit_markers()
	_draw_spawn_marker()
	_draw_playable_boundary()
	_draw_shadow_debug()
```

---

## DO NOT TOUCH

- `_draw_exit_markers()`, `_draw_spawn_marker()`, `_draw_shadow_debug()` — não mudam.
- `VISUAL_GRID_OFFSET` — não muda.
- Qualquer overlay ou lógica de gameplay.

---

## ACCEPTANCE

```bash
## Parse check
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Função presente
grep -n "_draw_playable_boundary" godot/scripts/world/room.gd
# esperado: 1 definição + 1 chamada = 2 ocorrências

## Apenas 1 arquivo alterado
git diff --name-only
# esperado: godot/scripts/world/room.gd
```

**Visualmente em DEV_VISION:**

- Uma linha vermelha fina traça o diamante isométrico ao redor de todo o
  floor grid — vértices N/E/S/W nos quatro extremos do mapa.
- Fora de DEV_VISION: invisível.
- Útil para alinhar e diagnosticar o offset entre grid e wall containers.

---

**Escopo:** 1 arquivo · 2 str_replace · ~20 linhas adicionadas.
**Próximo:** CONTAINER-05 — Dirty Flag + ciclo TIC.
