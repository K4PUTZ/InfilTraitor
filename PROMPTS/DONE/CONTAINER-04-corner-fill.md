# CONTAINER-04 — Corner Fill: Coluna de Preenchimento nas Esquinas

> **Pré-requisito:** RENAME-01b aplicado (`is_x_varying` correto).
> **Natureza:** 2 arquivos. Adiciona uma Image de 1-átomo-de-largura em cada
> célula de corner, posicionada na média dos offsets das duas faces adjacentes.
> Cobre o gap triangular entre os dois WallContainers sem asset especial.

---

## CONTEXT

Cada célula de corner emite 2 faces (ex: NW + NE). Os dois WallContainers
resultantes têm seus atoms do subcubo compartilhado centrados em posições
diferentes em tela:

```
NW+NE corner, shared subcell (0,0):
  NW Container: centro em world(0,0) + (−16, −28)
  NE Container: centro em world(0,0) + (+16, −28)
  Gap: 32 px em x — preenchido pela sobreposição mas visualmente raso
  Corner Fill: centro em world(0,0) + (0, −28)  ← média exata
```

O Corner Fill é uma Image de **64×image_h px** com 1 atom por nível de altura,
posicionada no ponto médio entre as duas faces. z_index maior que ambas as
faces → aparece no topo, cobrindo o gap.

**Offsets de fill por tipo de corner (derivados de FACE_CENTER_OFFSET):**

| Corner | Shared subcell (local) | Fill offset |
|--------|------------------------|-------------|
| NW+NE | (0,0) | (0, −28) |
| NW+SW | (0,3) | (−16, −20) |
| SE+NE | (3,0) | (+16, −20) |
| SE+SW | (3,3) | (0, −12) |

**Image do fill (single-column, N storeys):**

```
image_w   = 64 (1 átomo)
baseline_y = (N×4−1)×40
image_h   = baseline_y + 72
blit_x    = 0 (sempre)
blit_y    = −layer_index×40 + baseline_y
anchor    = (32, baseline_y + 36)
```

---

## MODULE

- `godot/scripts/world/wall_container.gd` — novo método `build_corner_fill()`
- `godot/scripts/world/room.gd` — detecção de corners em `_build_wall_containers()`

---

## TASK

### 1. `wall_container.gd` — Adicionar `build_corner_fill()`

Adicionar **após** a função `build()` existente:

```gdscript
## Constrói a Image de corner fill: 1 átomo de largura × N storeys de altura.
## Posicionado no ponto médio entre os dois FACE_CENTER_OFFSETs do corner.
##
## ref_layer      — TileMapLayer de referência para map_to_local().
## atom_image     — Image do átomo (64×72).
## shared_subcell — subcell compartilhado pelos dois WallContainers do corner.
## fill_offset    — Vector2 = média dos FACE_CENTER_OFFSETs das duas faces.
## storey_count   — número de andares.
func build_corner_fill(ref_layer: TileMapLayer, atom_image: Image,
		shared_subcell: Vector2i, fill_offset: Vector2, storey_count: int) -> void:
	dir = "CORNER"

	var n: int           = storey_count
	var baseline_y: int  = (n * SUBCUBES_PER_AXIS - 1) * int(SUBCUBE_STEP_PX)
	var image_h: int     = baseline_y + ATOM_H
	var anchor_y: float  = baseline_y + ATOM_H * 0.5

	## ── Compor a Image (1 átomo por layer_index) ────────────────────────────
	var image := Image.create(ATOM_W, image_h, false, Image.FORMAT_RGBA8)

	## Painter's algorithm: layer_index 0 (base) primeiro, N*4−1 (topo) último.
	for layer_index in n * SUBCUBES_PER_AXIS:
		var blit_y: int = -layer_index * int(SUBCUBE_STEP_PX) + baseline_y
		image.blend_rect(atom_image,
				Rect2i(0, 0, ATOM_W, ATOM_H), Vector2i(0, blit_y))

	## ── Sprite2D ────────────────────────────────────────────────────────────
	var sp := Sprite2D.new()
	sp.texture  = ImageTexture.create_from_image(image)
	sp.centered = false

	## Centro do fill no mundo: shared_subcell + fill_offset (sem storey offset —
	## a Image já encode todos os andares verticalmente).
	var cell_world: Vector2 = ref_layer.position \
			+ ref_layer.map_to_local(shared_subcell)
	sp.position = cell_world + fill_offset - Vector2(ATOM_W * 0.5, anchor_y)

	## z_index: ligeiramente acima dos WallContainers adjacentes no mesmo corner.
	sp.z_index = shared_subcell.x + shared_subcell.y + 1

	add_child(sp)
```

---

### 2. `room.gd` — Detectar corners e criar fills em `_build_wall_containers()`

#### 2a. Adicionar constantes de fill (após `FACE_CENTER_OFFSET` ou início do método)

Adicionar ao topo de `_build_wall_containers()`, antes do loop de `wall_faces`:

```gdscript
	## Offsets de corner fill = média dos FACE_CENTER_OFFSETs das duas faces
	## adjacentes no subcubo compartilhado. Ver DIRECTION_GLOSSARY.md §5.
	const _FILL_OFFSET: Dictionary = {
		"NW_NE": Vector2(  0.0, -28.0),
		"NW_SW": Vector2(-16.0, -20.0),
		"SE_NE": Vector2( 16.0, -20.0),
		"SE_SW": Vector2(  0.0, -12.0),
	}

	## Subcubo local compartilhado por corner (em coords de subcubo relativos à origin).
	## Y-varying (NW/SE): contribui com x. X-varying (NE/SW): contribui com y.
	const _FILL_SHARED_LOCAL: Dictionary = {
		"NW_NE": Vector2i(0, 0),
		"NW_SW": Vector2i(0, 3),
		"SE_NE": Vector2i(3, 0),
		"SE_SW": Vector2i(3, 3),
	}
```

#### 2b. Adicionar rastreamento de dirs por cell no loop de agrupamento

Dentro do loop `for key in face_groups`, **após** criar o WallContainer,
adicionar ao dict de rastreamento de corners.

Adicionar antes do loop de criação de WallContainers (após o loop de agrupamento):

```gdscript
	## ── Corner fills ────────────────────────────────────────────────────────
	## Agrupar dirs por cell (em UNIT coords) para detectar corners (2 faces).
	var cell_dirs: Dictionary = {}  ## "x,y" → {unit, dirs[], max_storey}

	for key: String in face_groups:
		var grp: Dictionary = face_groups[key]
		var unit: Vector2i  = grp["from_cell"]
		var cell_key: String = "%d,%d" % [unit.x, unit.y]
		if not cell_dirs.has(cell_key):
			cell_dirs[cell_key] = {"unit": unit, "dirs": [], "max_storey": 0}
		cell_dirs[cell_key]["dirs"].append(grp["wall_dir"])
		cell_dirs[cell_key]["max_storey"] = maxi(
				cell_dirs[cell_key]["max_storey"], grp["max_storey"])

	## Criar 1 corner fill por célula com 2 faces (corner cell).
	for cell_key: String in cell_dirs:
		var cd: Dictionary = cell_dirs[cell_key]
		if cd["dirs"].size() != 2:
			continue  ## não é corner

		## Ordenar dirs para obter key canônica do dict de fill.
		var sorted_dirs: Array = cd["dirs"].duplicate()
		sorted_dirs.sort()
		var fill_key: String = "%s_%s" % [sorted_dirs[0], sorted_dirs[1]]

		if not _FILL_OFFSET.has(fill_key):
			push_warning("WallContainer: corner fill key não reconhecida: %s" % fill_key)
			continue

		## Subcubo compartilhado em coords de subcubo absolutos.
		var unit: Vector2i    = cd["unit"]
		var origin: Vector2i  = Vector2i(unit.x * 4, unit.y * 4)
		var local: Vector2i   = _FILL_SHARED_LOCAL[fill_key]
		var shared_sc: Vector2i = origin + local

		var fill_off: Vector2   = _FILL_OFFSET[fill_key]
		var storey_count: int   = cd["max_storey"] + 1

		var wc_fill := WallContainer.new()
		wc_fill.build_corner_fill(ref_layer, atom_image, shared_sc, fill_off, storey_count)
		add_child(wc_fill)
		_wall_containers.append(wc_fill)
```

---

## DO NOT TOUCH

- **`build()`** em `wall_container.gd` — não muda; `build_corner_fill()` é adição.
- **Loop de agrupamento de `face_groups`** — não muda; o loop de corner fill é separado.
- **`FACE_CENTER_OFFSET`** — não muda (os valores de fill são derivados dele).
- **`subcube_geometry.gd`**, **`map_geometry.gd`** — não tocados.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## build_corner_fill presente
grep -n "build_corner_fill" godot/scripts/world/wall_container.gd
# esperado: 1 definição

## Corner detection presente em room.gd
grep -n "cell_dirs\|fill_key\|_FILL_OFFSET" godot/scripts/world/room.gd
# esperado: 5+ ocorrências

## Apenas 2 arquivos alterados
git diff --name-only
# esperado: wall_container.gd + room.gd
```

**Visualmente no jogo:**

- Esquinas entre paredes perpendiculares mostram uma **coluna de fill** no topo
  do stack de z_index, cobrindo o gap triangular.
- O fill é o mesmo átomo de parede — sem asset especial, shading resolvido
  pelo sistema de iluminação existente.
- Para ajuste fino: modificar `_FILL_OFFSET` no topo de `_build_wall_containers()`
  sem tocar na lógica de detecção.
- Para desativar temporariamente: comentar o bloco `## Corner fills` inteiro.

---

**Escopo:** 2 arquivos · `wall_container.gd` (~25 linhas) · `room.gd` (~30 linhas) · 1 sessão.
**Próximo:** CONTAINER-05 — Dirty Flag + ciclo TIC para atualizações runtime de subcubos.
