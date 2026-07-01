# WALLALIGN-01 — Fix: Posição da Subcube Layer (+100, +2 espúrios)

> **Natureza:** 1 arquivo · 1 str_replace em `room.gd`.
> **Risco:** baixo — a linha alterada é a única fonte de posicionamento das subcube layers.

---

## ROOT CAUSE

Em `_ensure_subcube_layers()`, a posição de cada subcube TileMapLayer é:

```gdscript
layer.position = Vector2(VISUAL_GRID_OFFSET.x + 100, VISUAL_GRID_OFFSET.y + 2 - SUBCUBE_STEP_PX * float(level))
```

Os offsets `+100` (x) e `+2` (y) são artefatos de calibração que não têm
justificativa geométrica. A prova:

```
# Para qualquer tile (col, row) e seu subcubo origem (4*col, 4*row):
floor_layer.map_to_local(col, row)         = ((col-row)*128, (col+row)*64)
subcube_layer.map_to_local(4*col, 4*row)   = ((col-row)*128, (col+row)*64)
# ── idênticos. Os dois sistemas de coordenadas concordam em local space.

# Em world space:
# floor tile (1,1) top vertex = map_to_local(1,1) + VISUAL_GRID_OFFSET = (0, 128) + (0, 512) = (0, 640)
# subcube (4,4) com layer em (100, 514):                                  (0, 128) + (100, 514) = (100, 642) ✗
# subcube (4,4) com layer em (0, 512)  = VISUAL_GRID_OFFSET:              (0, 128) + (0,   512) = (0,  640) ✓
```

**Conclusão:** a subcube layer deve estar em `VISUAL_GRID_OFFSET` puro —
`(0, 512)` para level=0. `FACE_CENTER_OFFSET` é derivado geometricamente e
**não** compensa o offset da layer; removê-los restaura o alinhamento.

---

## MODULE

- `godot/scripts/world/room.gd` — `_ensure_subcube_layers()`.

---

## TASK

### 1. Corrigir posição da subcube layer

**str_replace** — localizar:

```
		layer.position = Vector2(VISUAL_GRID_OFFSET.x + 100, VISUAL_GRID_OFFSET.y + 2 - SUBCUBE_STEP_PX * float(level))
```

**Substituir por:**

```
		layer.position = Vector2(VISUAL_GRID_OFFSET.x, VISUAL_GRID_OFFSET.y - SUBCUBE_STEP_PX * float(level))
```

---

## DO NOT TOUCH

- `VISUAL_GRID_OFFSET` — não muda.
- `FACE_CENTER_OFFSET` em `wall_container.gd` — não muda (é geométrico).
- `SUBCUBE_BASE_ORIGIN`, `SUBCUBE_FACE_OFFSETS` — não mudam.
- Qualquer outra linha de `_ensure_subcube_layers()`.

---

## ACCEPTANCE

```bash
## Parse check
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Confirmar linha corrigida
grep -n "layer.position" godot/scripts/world/room.gd
# esperado: Vector2(VISUAL_GRID_OFFSET.x, VISUAL_GRID_OFFSET.y - SUBCUBE_STEP_PX * float(level))
# NÃO deve conter "+ 100" ou "+ 2"

## Apenas 1 arquivo alterado
git diff --name-only
# esperado: godot/scripts/world/room.gd
```

**Visualmente:**

- Paredes alinhadas com o grid de chão — o topo das faces de parede deve
  coincidir com a aresta do tile correspondente no floor grid.
- Se houver um resíduo vertical pequeno (1-2 px), reportar para calibração
  de `base_y` em `FACE_CENTER_OFFSET`.
- Corner fills e solid subcubes seguem o mesmo realinhamento automaticamente
  (herdam a posição da layer).

---

**Escopo:** 1 arquivo · 1 str_replace · 1 linha alterada.
**Próximo:** DEVVIZ-01b (boundary corrigido) para confirmar o alinhamento
visual; depois CONTAINER-05 (Dirty Flag + TIC).
