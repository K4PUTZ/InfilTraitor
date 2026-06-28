# CONTAINER-02 — Image Composition + Desativar Legacy Wall Tiles

> **Pré-requisitos:** CONTAINER-01 concluído (WallContainer com 16 Sprite2D filhos,
> `_build_wall_containers()` chamado em `room.gd`).
> **Natureza:** 2 arquivos. Substitui 16 Sprite2D por 1 Image composta
> (Godot Image API) e remove dupla renderização de paredes legadas.
> **Resultado:** 16× menos nós de cena por Container. Corner overlap natural
> (32 px) — sem corner fill dedicado ainda.

---

## CONTEXT

**CONTAINER-01 instalou a arquitetura, CONTAINER-02 a otimiza e limpa:**

Problema 1 — Node count: 16 Sprite2D por Container × N Containers = potencialmente
milhares de nós. CONTAINER-02 colapsa os 16 Sprite2D em **1 imagem composta**
(`Image.blend_rect` em loop, resultado → `ImageTexture` → 1 Sprite2D).

Problema 2 — Dupla renderização: `_place()` em `room.gd` ainda coloca tiles Kenney
nas wall layers. Com WallContainers ativos, as paredes aparecem duplicadas (Kenney
por baixo + Container por cima). CONTAINER-02 adiciona um guard no loop de `_place()`
que pula tiles `wall_*`.

**Por que corner fills não são necessários aqui:**
Na Image composta, o subcubo de corner do Container NW ocupa x∈[-48, +16] em
tela relativo ao cell_center. O subcubo de corner do Container SW ocupa x∈[-16, +48].
Overlap de **32 px** — o corner está coberto pelos dois Containers se sobrepondo
naturalmente. O Container com maior z_index (SW, adicionado por último) fica no
topo na região de overlap. Validar visualmente; corner fill explícito entra em
CONTAINER-03 se necessário.

**Matemática da Image composta (derivada analiticamente, sem precisar de calibração):**

```
Átomo PNG:    64 × 72 px
Tile size:    64 × 32 px (isométrico diamond-down)
SUBCUBE_STEP: 40 px (vertical por nível de altura)

Image size:   160 × 240 px  (igual para todas as 4 direções, 1 storey)

Blit para subcubo (ds, level) onde ds = índice dentro da face (0..3):
  x-varying (NW / SE): blit_x = ds × 32         blit_y = ds × 16 − level × 40 + 120
  y-varying (SW / NE): blit_x = 96 − ds × 32    blit_y = ds × 16 − level × 40 + 120

Âncora da image (pixel CENTER do subcubo ds=0, level=0):
  x-varying: (32, 156)      y-varying: (128, 156)

Ordem de blit (painter's algorithm):
  for level in 0..3:          # nível 0 = base, 3 = topo
      for ds in 0..3:         # ds=0 = mais longe do viewer, 3 = mais perto

Posição do Sprite2D (centered=false):
  sprite_center = ref_layer.position + ref_layer.map_to_local(face_subcells[0])
                + FACE_CENTER_OFFSET[dir]
                − Vector2(0, storey × 160.0)   ← cada storey sobe 160 px
  sprite.position = sprite_center − âncora
```

---

## MODULE

- `godot/scripts/world/wall_container.gd` — rewrite (mantém interface `build()`)
- `godot/scripts/world/room.gd` — guard no loop `_place()` + helper `_edge_delta_to_dir()`

---

## TASK

### 1. Reescrever `wall_container.gd`

Substituir o arquivo inteiro pelo conteúdo abaixo
(mantém `class_name WallContainer`, mantém assinatura de `build()`):

```gdscript
class_name WallContainer
extends Node2D
## Container de parede: 1 face (1 unit × 1 storey) composta em 1 Sprite2D.
## 4 subcubos horizontais × 4 níveis de altura = 16 átomos blitados em Image 160×240.
##
## Constantes derivadas analiticamente — não alterar sem nova calibração.
##   Tile isométrico: 64×32   Átomo PNG: 64×72   SUBCUBE_STEP: 40 px

const ATOM_W              :=  64
const ATOM_H              :=  72
const IMAGE_W             := 160
const IMAGE_H             := 240
const SUBCUBES_PER_AXIS   :=   4   ## SubcubeCoords.SUBCUBES_PER_UNIT_AXIS
const SUBCUBE_STEP_PX     :=  40.0
const STOREY_HEIGHT_PX    := 160.0  ## SUBCUBES_PER_AXIS × SUBCUBE_STEP_PX

## Offset do centro do Sprite2D relativo a map_to_local(face_subcells[0]).
## Derivado de: (-tile_w/2 + atom_w/2, -tile_h/2 + atom_h/2) + final_texture_origin
const FACE_CENTER_OFFSET: Dictionary = {
	"NW": Vector2(-16.0, -12.0),
	"NE": Vector2(-16.0, -28.0),
	"SE": Vector2( 16.0, -28.0),
	"SW": Vector2( 16.0, -12.0),
}

## Pixel da Image onde o CENTRO do subcubo ds=0, level=0 se encontra.
const ANCHOR_X_VARYING := Vector2(32.0,  156.0)  ## NW e SE
const ANCHOR_Y_VARYING := Vector2(128.0, 156.0)  ## SW e NE

## Direção desta face.
var dir: String = ""


## Constrói a Image composta e posiciona 1 Sprite2D filho.
##
## ref_layer    — TileMapLayer de referência; usado apenas para map_to_local().
## atom_image   — Image pré-carregada do átomo (load→get_image()).
## face_subcells — Array[Vector2i] com os 4 subcells da aresta (de _subcubes_on_edge).
## wall_dir     — "NW" | "NE" | "SE" | "SW".
## storey       — índice do andar (0 = térreo). Controla posição vertical e z_index.
func build(ref_layer: TileMapLayer, atom_image: Image,
		face_subcells: Array, wall_dir: String, storey: int) -> void:
	dir = wall_dir

	var is_x_varying: bool = wall_dir == "NW" or wall_dir == "SE"
	var anchor: Vector2 = ANCHOR_X_VARYING if is_x_varying else ANCHOR_Y_VARYING

	## ── Compor a Image ─────────────────────────────────────────────────────────
	var image := Image.create(IMAGE_W, IMAGE_H, false, Image.FORMAT_RGBA8)

	## Painter's algorithm: level baixo → alto, ds longe → perto do viewer.
	for level in SUBCUBES_PER_AXIS:
		for ds in SUBCUBES_PER_AXIS:
			var blit_x: int = ds * 32 if is_x_varying else 96 - ds * 32
			var blit_y: int = ds * 16 - level * 40 + 120
			image.blend_rect(atom_image,
					Rect2i(0, 0, ATOM_W, ATOM_H), Vector2i(blit_x, blit_y))

	## ── Sprite2D ────────────────────────────────────────────────────────────────
	var sp := Sprite2D.new()
	sp.texture  = ImageTexture.create_from_image(image)
	sp.centered = false

	## Centro do subcubo ds=0, level=0 deste storey em espaço do nó pai.
	var cell_world: Vector2 = ref_layer.position \
			+ ref_layer.map_to_local(Vector2i(face_subcells[0]))
	var sprite_center: Vector2 = cell_world \
			+ FACE_CENTER_OFFSET[wall_dir] \
			- Vector2(0.0, storey * STOREY_HEIGHT_PX)
	sp.position = sprite_center - anchor

	## z_index: depth sort isométrico por (col + row) do primeiro subcell.
	## Storey multiplier garante que andares superiores ficam sempre à frente.
	var sc0 := Vector2i(face_subcells[0])
	sp.z_index = sc0.x + sc0.y + storey * 100_000

	add_child(sp)
```

---

### 2. Editar `room.gd`

#### 2a. Adicionar helper `_edge_delta_to_dir()` caso não exista

Adicionar após `_subcubes_on_edge()` (ou onde couber entre os helpers de subcubo):

```gdscript
## Converte edge_delta do face descriptor → sufixo direcional "NW"/"NE"/"SE"/"SW".
## Retorna "" para deltas desconhecidos (ignorado pelo caller).
func _edge_delta_to_dir(delta: Vector2i) -> String:
	match delta:
		Vector2i( 0, -1): return "NW"
		Vector2i( 1,  0): return "NE"
		Vector2i( 0,  1): return "SE"
		Vector2i(-1,  0): return "SW"
	return ""
```

> Se `_edge_delta_to_dir()` já existir em room.gd com a mesma lógica, pular este passo.

#### 2b. Mudar `atom_image` de `Texture2D` para `Image` em `_build_wall_containers()`

**Localizar** (adicionado pelo CONTAINER-01):

```gdscript
	var atom_texture: Texture2D = load(
		"res://ASSETS/ISOMETRIC/source_assets/subcubes/subcube_concrete.png"
	)
	if atom_texture == null:
		push_warning("WallContainer: atom texture not found.")
		return
```

**Substituir por:**

```gdscript
	var atom_image: Image = Image.load_from_file(
		"res://ASSETS/ISOMETRIC/source_assets/subcubes/subcube_concrete.png"
	)
	if atom_image == null:
		push_warning("WallContainer: atom image not found.")
		return
```

#### 2c. Atualizar chamada para `wc.build()` — passar `atom_image` em vez de `atom_texture`

**Localizar:**

```gdscript
		wc.build(ref_layer, atom_texture, face_subcells, wall_dir, storey)
```

**Substituir por:**

```gdscript
		wc.build(ref_layer, atom_image, face_subcells, wall_dir, storey)
```

#### 2d. Adicionar guard em `_place()` para pular wall tiles

**Localizar** o bloco do loop de wall_levels (dentro do build de sala):

```gdscript
		for level in range(wall_levels.size()):
			...
			for entry in wall_levels[level]:
				_place(entry.get("cell", INVALID_CELL), String(entry.get("tile_name", "")), target)
```

**Substituir o `_place()` interno por:**

```gdscript
		for level in range(wall_levels.size()):
			...
			for entry in wall_levels[level]:
				var tile_name: String = String(entry.get("tile_name", ""))
				## Wall tiles são renderizadas por WallContainers — pular aqui.
				if tile_name.begins_with("wall_"):
					continue
				_place(entry.get("cell", INVALID_CELL), tile_name, target)
```

---

## DO NOT TOUCH

- **`_build_wall_containers()`** além das 3 mudanças de atom — lógica de loop intacta.
- **`_render_subcube_geometry()`** — inalterado (blocos sólidos no TileMapLayer).
- **`_subcubes_on_edge()`** — inalterado.
- **Floor, props, structure** — inalterados.
- **`map_geometry.gd`** e **`subcube_geometry.gd`** — não tocados neste prompt.
- **`FACE_CENTER_OFFSET`** em `wall_container.gd` — não alterar (valores derivados,
  ajuste via ACCEPTANCE se necessário).

---

## ACCEPTANCE

### Parse

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural

```bash
## Image composition presente
grep -n "blend_rect\|Image.create\|ImageTexture.create_from_image" \
  godot/scripts/world/wall_container.gd
# esperado: 3 linhas (blend_rect no loop, create, create_from_image)

## 16 Sprite2D foram removidos — só 1 `add_child` e `Sprite2D.new()`
grep -c "Sprite2D.new\|add_child" godot/scripts/world/wall_container.gd
# esperado: 2 (1 de cada)

## Guard no _place() presente
grep -n "begins_with.*wall_\|wall.*continue" godot/scripts/world/room.gd
# esperado: 1 ocorrência

## Legacy wall tiles não mais chamados
grep -n "atom_texture\b" godot/scripts/world/room.gd
# esperado: ZERO (foi substituído por atom_image)

## Apenas os 2 arquivos do MODULE alterados
git diff --name-only
# esperado: wall_container.gd + room.gd
```

### Comportamento esperado no jogo

Ao rodar PLAYGROUND ou SIGMA-01:

- **Paredes**: renderizadas pelos WallContainers (Image compostas, 1 Sprite2D cada).
  Tiles Kenney de parede NÃO mais visíveis nas wall layers.
- **Corners**: dois WallContainers sobrepostos — a região de overlap de 32 px cobre
  o vértice do corner. O Container com maior z (SW ou NE, adicionado por último)
  fica no topo no overlap. Corner deve parecer contínuo visualmente.
- **Blocos sólidos e floor**: inalterados.
- **Node count**: ~16× menor que CONTAINER-01 para a parte de paredes.

**Erros a reportar para calibração:**

| Sintoma | Campo a ajustar |
|---|---|
| Paredes deslocadas uniformemente | `FACE_CENTER_OFFSET[dir]` em `wall_container.gd` |
| Corner com gap visível (>1 px) | Será tratado em CONTAINER-03 (corner fill) |
| Storey errado (andar 1 aparece no chão) | `STOREY_HEIGHT_PX` em `wall_container.gd` |
| Paredes Kenney ainda visíveis | Verificar guard no `_place()` (2d) |

---

**Escopo:** 2 arquivos · `wall_container.gd` (rewrite ~65 linhas) ·
`room.gd` (3 pontos cirúrgicos, ~10 linhas) · 1 sessão.
**Próximo:** CONTAINER-03 — corner fill explícito + suporte a multi-storey em 1
Container (colapsar N storeys em 1 Image de 160 × (80 + 160 × N) px).
