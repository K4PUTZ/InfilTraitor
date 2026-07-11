# CONTAINER-03 — Multi-Storey: Um Container por Face, Todos os Andares em Uma Image

> **Pré-requisitos:** CONTAINER-02 concluído (Image composition, 1 Sprite2D por Container,
> legacy wall tiles desativados).
> **Natureza:** 2 arquivos. Colapsa N Containers de 1-storey em 1 Container de N-storeys.
> A Image cresce verticalmente para acomodar toda a altura da parede.
> **Zero regressão:** Para N=1 o resultado é pixel-identical ao CONTAINER-02.

---

## CONTEXT

**CONTAINER-02 cria 1 Container por face-descriptor.** Para uma parede de 3 andares,
isso gera 3 Containers (e 3 Sprite2D) para o mesmo trecho de parede. Além do overhead
de nós, cada storey tem seu próprio `ImageTexture`, fragmentando a renderização.

**CONTAINER-03 agrupa** todos os face-descriptors do mesmo cell+dir em **1 único
Container**, com 1 Image que cobre verticalmente todos os andares.

```
ANTES (CONTAINER-02):        DEPOIS (CONTAINER-03):
  Container NW storey=0         Container NW (storeys=0..2, 1 image)
  Container NW storey=1    →    Container SW (storeys=0..2, 1 image)
  Container NW storey=2
  Container SW storey=0
  Container SW storey=1
  Container SW storey=2
```

**Fórmula da Image multi-storey** (derivada e verificada):

```
storey_count = N    (N = número de andares desta face)
baseline_y   = (N × 4 − 1) × 40
image_h      = baseline_y + (N_DS−1)×16 + ATOM_H
             = (N × 4 − 1) × 40 + 120

Para N=1: image_h = 240  ← idêntico ao CONTAINER-02 ✓
Para N=2: image_h = 400
Para N=3: image_h = 560

blit_y (ds, layer_index) = ds × 16 − layer_index × 40 + baseline_y
  onde layer_index = storey × 4 + level   (0..N×4−1)

Âncora y (pixel CENTER de ds=0, layer_index=0):
  anchor_y = baseline_y + 36
Para N=1: anchor_y = 156  ← idêntico ao CONTAINER-02 ✓
Para N=2: anchor_y = 316

Posição Sprite2D: baseada em storey=0 — SEM height offset por storey
  (a Image já encode todos os andares verticalmente)
```

---

## MODULE

- `godot/scripts/world/wall_container.gd` — `build()` recebe `storey_count` (não `storey`)
- `godot/scripts/world/room.gd` — `_build_wall_containers()` agrupa faces por cell+dir

---

## TASK

### 1. Atualizar `wall_container.gd`

Substituir **apenas** a função `build()` (manter constantes e `var dir` intactos):

```gdscript
## Constrói a Image composta com TODOS os andares e posiciona 1 Sprite2D filho.
##
## ref_layer     — TileMapLayer de referência para map_to_local().
## atom_image    — Image do átomo (64×72).
## face_subcells — Array[Vector2i] com os 4 subcells da aresta.
## wall_dir      — "NW" | "NE" | "SE" | "SW".
## storey_count  — número total de andares desta face (>= 1).
func build(ref_layer: TileMapLayer, atom_image: Image,
		face_subcells: Array, wall_dir: String, storey_count: int) -> void:
	dir = wall_dir

	var is_x_varying: bool = wall_dir == "NW" or wall_dir == "SE"

	## ── Dimensões dinâmicas da Image ────────────────────────────────────────────
	var n: int           = storey_count
	var baseline_y: int  = (n * SUBCUBES_PER_AXIS - 1) * int(SUBCUBE_STEP_PX)
	var image_h: int     = baseline_y + (SUBCUBES_PER_AXIS - 1) * 16 + ATOM_H
	var anchor_y: float  = baseline_y + ATOM_H * 0.5
	var anchor: Vector2  = Vector2(
			ANCHOR_X_VARYING.x if is_x_varying else ANCHOR_Y_VARYING.x,
			anchor_y)

	## ── Compor a Image ──────────────────────────────────────────────────────────
	var image := Image.create(IMAGE_W, image_h, false, Image.FORMAT_RGBA8)

	## Painter's algorithm:
	##   layer_index 0 (storey=0 level=0, base) primeiro → layer_index N*4-1 (topo) último.
	##   Dentro de cada layer_index: ds 0 (longe do viewer) → ds 3 (perto).
	for layer_index in n * SUBCUBES_PER_AXIS:
		for ds in SUBCUBES_PER_AXIS:
			var blit_x: int = ds * 32 if is_x_varying else 96 - ds * 32
			var blit_y: int = ds * 16 - layer_index * int(SUBCUBE_STEP_PX) + baseline_y
			image.blend_rect(atom_image,
					Rect2i(0, 0, ATOM_W, ATOM_H), Vector2i(blit_x, blit_y))

	## ── Sprite2D ────────────────────────────────────────────────────────────────
	var sp := Sprite2D.new()
	sp.texture  = ImageTexture.create_from_image(image)
	sp.centered = false

	## Posição baseada em storey=0 (layer_index=0, ds=0).
	## A Image cresce PARA CIMA — sem height offset por storey.
	var cell_world: Vector2 = ref_layer.position \
			+ ref_layer.map_to_local(Vector2i(face_subcells[0]))
	sp.position = cell_world + FACE_CENTER_OFFSET[wall_dir] - anchor

	## z_index: depth sort isométrico. Um Container por face → sem multiplicador de storey.
	var sc0 := Vector2i(face_subcells[0])
	sp.z_index = sc0.x + sc0.y

	add_child(sp)
```

> **Atenção:** `SUBCUBES_PER_AXIS` e `SUBCUBE_STEP_PX` permanecem como estão nas constantes
> da classe. Só `build()` muda; `FACE_CENTER_OFFSET`, `ANCHOR_X_VARYING`, `ANCHOR_Y_VARYING`
> e todas as outras constantes ficam intactos.

---

### 2. Refatorar `_build_wall_containers()` em `room.gd`

Substituir o corpo completo da função pelo código abaixo (manter assinatura intacta):

```gdscript
func _build_wall_containers(subcube_geometry: Dictionary) -> void:
	## Limpa containers anteriores (rebuild de sala).
	for wc in _wall_containers:
		if is_instance_valid(wc):
			wc.queue_free()
	_wall_containers.clear()

	var faces: Array = subcube_geometry.get("wall_faces", [])
	if faces.is_empty():
		return

	var atom_image: Image = Image.load_from_file(
		"res://ASSETS/ISOMETRIC/source_assets/subcubes/subcube_concrete.png"
	)
	if atom_image == null:
		push_warning("WallContainer: atom image not found.")
		return

	if _subcube_layers.is_empty():
		push_warning("WallContainer: subcube layers not initialized.")
		return
	var ref_layer: TileMapLayer = _subcube_layers[0]

	## ── Agrupar faces por (from_cell, wall_dir) ─────────────────────────────────
	## Cada grupo = 1 WallContainer com todos os storeys dessa face.
	var face_groups: Dictionary = {}   ## key → {face_subcells, wall_dir, max_storey}

	for face: Dictionary in faces:
		var edge: Dictionary   = face.get("edge", {})
		var from_cell: Vector2i = Vector2i(edge.get("from", Vector2i.ZERO))
		var to_cell:   Vector2i = Vector2i(edge.get("to",   Vector2i.ZERO))
		var edge_delta: Vector2i = to_cell - from_cell
		var wall_dir: String   = _edge_delta_to_dir(edge_delta)
		if wall_dir.is_empty():
			continue
		var storey: int = maxi(0, int(face.get("storey", 0)))

		var key: String = "%d,%d,%s" % [from_cell.x, from_cell.y, wall_dir]

		if not face_groups.has(key):
			face_groups[key] = {
				"face_subcells": _subcubes_on_edge(from_cell, edge_delta),
				"wall_dir":      wall_dir,
				"max_storey":    storey,
			}
		else:
			face_groups[key]["max_storey"] = maxi(
					face_groups[key]["max_storey"], storey)

	## ── Criar 1 WallContainer por grupo ────────────────────────────────────────
	for key: String in face_groups:
		var grp: Dictionary  = face_groups[key]
		var storey_count: int = grp["max_storey"] + 1
		var wc := WallContainer.new()
		wc.build(ref_layer, atom_image,
				grp["face_subcells"], grp["wall_dir"], storey_count)
		add_child(wc)
		_wall_containers.append(wc)
```

---

## DO NOT TOUCH

- **Constantes em `wall_container.gd`** (`FACE_CENTER_OFFSET`, âncoras, `ATOM_W/H`,
  `IMAGE_W`, `SUBCUBES_PER_AXIS`, `SUBCUBE_STEP_PX`, `STOREY_HEIGHT_PX`) — não mudam.
- **`_render_subcube_geometry()`** — inalterado.
- **`_edge_delta_to_dir()`** e **`_subcubes_on_edge()`** — inalterados.
- **Guard de `_place()`** para `wall_*` (adicionado no CONTAINER-02) — inalterado.
- **`map_geometry.gd`** e **`subcube_geometry.gd`** — não tocados.

---

## ACCEPTANCE

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural

```bash
## build() agora tem baseline_y dinâmico (não hardcoded 120)
grep -n "baseline_y\|storey_count\|layer_index" godot/scripts/world/wall_container.gd
# esperado: 4+ ocorrências (derivação + uso no loop)

## Grouping presente em room.gd
grep -n "face_groups\|max_storey\|storey_count" godot/scripts/world/room.gd
# esperado: 5+ ocorrências

## Apenas 2 arquivos alterados
git diff --name-only
# esperado: wall_container.gd + room.gd

## Container count reduzido: N_storeys × N_faces → N_faces
## (verificar com print ou debugger no editor — deve ser ~metade ou menos)
```

### Invariante de regressão (N=1)

Para salas com 1 andar:
- `storey_count = 1` → `baseline_y = 120` → `image_h = 240` → `anchor_y = 156`
- Resultado **pixel-identical** ao CONTAINER-02. ✓

### Comportamento esperado no jogo

- Paredes de **múltiplos andares**: aparecem como 1 bloco visual contínuo sem
  separação entre andares. Antes (CONTAINER-02) havia risco de gap ou sobreposição
  entre Containers de andares adjacentes. Agora a Image é contínua.
- **Node count**: redução de `N_storeys × N_faces` para `N_faces` WallContainers.
  Para sala com 2 andares e 80 faces: de 160 para 80 Containers.
- **Corners**: comportamento idêntico ao CONTAINER-02 (sobreposição natural de 32 px).
  Se gap visual for reportado aqui, CONTAINER-04 trata com corner fill explícito.

---

**Escopo:** 2 arquivos · `wall_container.gd` (só `build()`, ~25 linhas) ·
`room.gd` (`_build_wall_containers()` completo, ~35 linhas) · 1 sessão.
**Próximo:** CONTAINER-04 — corner fill explícito (se necessário após validação visual)
ou Dirty Flag + ciclo TIC para atualizações runtime de subcubos.
