# RENAME-01 — Migração do Sistema de Direções (Kenney → Vértice-Alinhado)

> **Pré-requisito:** CONTAINER-03 concluído.
> **Natureza:** Rename puro. Zero mudança de lógica. Nenhum value de offset muda —
> apenas keys de dicionários, nomes de variáveis e strings de tile.
> **Referência canônica:** `DIRECTION_GLOSSARY.md` (ler antes de executar).

---

## CONTEXT

O sistema antigo usava convenção Kenney: N aponta para a direita da tela,
o que faz "NW" aparecer na face cima-direita — contraintuitivo para qualquer
desenvolvedor. O novo sistema usa **N no vértice topo** do diamante:

```
ANTIGO (N=direita):            NOVO (N=cima, vértice):
  "NW" = cima-direita  →  "NE"
  "NE" = baixo-direita →  "SE"
  "SE" = baixo-esquerda→  "SW"
  "SW" = cima-esquerda →  "NW"
```

**Invariante:** os VALUES dos offsets não mudam. Apenas as KEYS e strings mudam.
A rotação é: antigo NW→NE→SE→SW→NW (90° horária de labels).

---

## MODULE

1. `godot/scripts/world/room.gd`
2. `godot/scripts/world/maps/map_geometry.gd`
3. `godot/scripts/world/maps/subcube_geometry.gd`
4. `godot/scripts/world/wall_container.gd`
5. `godot/scripts/ui/compass_rose.gd`
6. `godot/scripts/tools/build_tileset.gd` *(se ainda existir e referenciar direções)*

---

## TASK

> **Estratégia de rename:** substituir blocos inteiros (dicts, arrays, funções)
> para evitar colisões circulares. Nunca fazer str_replace em "NW" isolado —
> isso substituiria NW dentro de outras palavras ou em ordem errada.

---

### 1. `room.gd`

#### 1a. Substituir `SUBCUBE_FACE_OFFSETS` inteiro

**Localizar:**
```gdscript
const SUBCUBE_FACE_OFFSETS: Dictionary = {
	"NW": Vector2i(-16,  8),
	"NE": Vector2i(-16, -8),
	"SE": Vector2i( 16, -8),
	"SW": Vector2i( 16,  8),
}
```

**Substituir por:**
```gdscript
## Straddle offset por face de parede. Keys seguem o sistema vértice-alinhado
## (N=topo do diamante). Ver DIRECTION_GLOSSARY.md §5.
## NW = cima-esquerda | NE = cima-direita | SE = baixo-direita | SW = baixo-esquerda
const SUBCUBE_FACE_OFFSETS: Dictionary = {
	"NW": Vector2i(-16,  8),   ## cima-esquerda: edge_delta (-1, 0)
	"NE": Vector2i(-16, -8),   ## cima-direita:  edge_delta ( 0,-1)
	"SE": Vector2i( 16, -8),   ## baixo-direita: edge_delta (+1, 0)
	"SW": Vector2i( 16,  8),   ## baixo-esquerda: edge_delta (0,+1)
}
```

> Nota: os VALUES são idênticos ao sistema anterior. Apenas os comentários mudam
> para refletir a semântica correta de cada key no novo sistema.

#### 1b. Substituir array `directions` em `_build_subcube_tileset()`

**Localizar:**
```gdscript
	var directions: Array[String] = ["NW", "NE", "SE", "SW"]
```

**Substituir por:**
```gdscript
	## Ordem: NW(cima-esq), NE(cima-dir), SE(baixo-dir), SW(baixo-esq).
	## Ver DIRECTION_GLOSSARY.md §3.
	var directions: Array[String] = ["NW", "NE", "SE", "SW"]
```

> Este array não muda (os mesmos 4 valores existem). Apenas confirmar que
> o comentário acima está presente para documentação. Se o comentário já
> existe diferente, substituir apenas o comentário.

#### 1c. Substituir `_edge_delta_to_dir()` inteiro

**Localizar:**
```gdscript
func _edge_delta_to_dir(delta: Vector2i) -> String:
	## Converte edge_delta de subcube_geometry para sufixo direcional (NW/NE/SE/SW).
	## Retorna "" para deltas inválidos (não deve ocorrer em geometria válida).
	match delta:
		Vector2i( 0, -1): return "NW"
		Vector2i( 1,  0): return "NE"
		Vector2i( 0,  1): return "SE"
		Vector2i(-1,  0): return "SW"
	return ""
```

**Substituir por:**
```gdscript
func _edge_delta_to_dir(delta: Vector2i) -> String:
	## Converte edge_delta → sufixo de face (sistema vértice-alinhado, N=topo).
	## NW=cima-esq(-1,0) | NE=cima-dir(0,-1) | SE=baixo-dir(+1,0) | SW=baixo-esq(0,+1)
	## Ver DIRECTION_GLOSSARY.md §3.
	match delta:
		Vector2i(-1,  0): return "NW"
		Vector2i( 0, -1): return "NE"
		Vector2i( 1,  0): return "SE"
		Vector2i( 0,  1): return "SW"
	return ""
```

#### 1d. Atualizar comentário da linha com "block_SE and wall_NE"

**Localizar** (linha ~71, o comentário com referência à direção):
```gdscript
## top-diamond 128 = 158 px (block_SE and wall_NE agree).
```

**Substituir por:**
```gdscript
## top-diamond 128 = 158 px (block_SE and wall_NE — sistema vértice-alinhado).
```

---

### 2. `map_geometry.gd`

#### 2a. Substituir o bloco de variáveis `on_*` em `_pick_wall_tiles()`

**Localizar:**
```gdscript
	var on_sw := cell.x == min_x   ## left column  — SW border
	var on_ne := cell.x == max_x   ## right column — NE border
	var on_nw := cell.y == min_y   ## top row      — NW border
	var on_se := cell.y == max_y   ## bottom row   — SE border
```

**Substituir por:**
```gdscript
	## Bordas do rect → faces de parede (sistema vértice-alinhado, N=topo).
	## Ver DIRECTION_GLOSSARY.md §4.
	var on_nw := cell.x == min_x   ## coluna esquerda  — face NW (cima-esquerda)
	var on_se := cell.x == max_x   ## coluna direita   — face SE (baixo-direita)
	var on_ne := cell.y == min_y   ## linha topo       — face NE (cima-direita)
	var on_sw := cell.y == max_y   ## linha base       — face SW (baixo-esquerda)
```

#### 2b. Substituir bloco de corners e straight walls em `_pick_wall_tiles()`

**Localizar:**
```gdscript
	## Corners generate two walls (one for each direction they face)
	if on_nw and on_sw:
		tiles.append("wall_NW")
		tiles.append("wall_SW")
	elif on_nw and on_ne:
		tiles.append("wall_NW")
		tiles.append("wall_NE")
	elif on_se and on_sw:
		tiles.append("wall_SE")
		tiles.append("wall_SW")
	elif on_se and on_ne:
		tiles.append("wall_SE")
		tiles.append("wall_NE")
	## Straight edges generate one wall
	elif on_nw:
		tiles.append("wall_NW")
	elif on_se:
		tiles.append("wall_SE")
	elif on_sw:
		tiles.append("wall_SW")
	elif on_ne:
		tiles.append("wall_NE")
```

**Substituir por:**
```gdscript
	## Corners: dois tiles de parede (uma face por direção exposta).
	## Straight: um tile de parede.
	if on_nw and on_ne:
		tiles.append("wall_NW")
		tiles.append("wall_NE")
	elif on_nw and on_sw:
		tiles.append("wall_NW")
		tiles.append("wall_SW")
	elif on_se and on_ne:
		tiles.append("wall_SE")
		tiles.append("wall_NE")
	elif on_se and on_sw:
		tiles.append("wall_SE")
		tiles.append("wall_SW")
	elif on_nw:
		tiles.append("wall_NW")
	elif on_ne:
		tiles.append("wall_NE")
	elif on_se:
		tiles.append("wall_SE")
	elif on_sw:
		tiles.append("wall_SW")
```

#### 2c. Substituir `_pick_door_tile()` inteiro

**Localizar:**
```gdscript
static func _pick_door_tile(cell: Vector2i, rect: Rect2i) -> String:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	if cell.y == min_y: return "doorOpen_NW"
	if cell.y == max_y: return "doorOpen_SE"
	if cell.x == min_x: return "doorOpen_SW"
	if cell.x == max_x: return "doorOpen_NE"

	return "doorOpen_SE"   ## fallback
```

**Substituir por:**
```gdscript
static func _pick_door_tile(cell: Vector2i, rect: Rect2i) -> String:
	## Sistema vértice-alinhado: porta recebe a face da borda onde está.
	## Ver DIRECTION_GLOSSARY.md §4.
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	if cell.x == min_x: return "doorOpen_NW"
	if cell.x == max_x: return "doorOpen_SE"
	if cell.y == min_y: return "doorOpen_NE"
	if cell.y == max_y: return "doorOpen_SW"

	return "doorOpen_SW"   ## fallback
```

---

### 3. `subcube_geometry.gd`

#### 3a. Substituir `_EDGE_BY_SUFFIX` inteiro

**Localizar:**
```gdscript
## sufixo de borda → arestas expostas (deltas em UNIT coords)
const _EDGE_BY_SUFFIX: Dictionary = {
	"NW": [Vector2i(0, -1)],
	"SE": [Vector2i(0,  1)],
	"SW": [Vector2i(-1, 0)],
	"NE": [Vector2i( 1, 0)],
}
```

**Substituir por:**
```gdscript
## Sufixo de face → edge_delta em UNIT coords (sistema vértice-alinhado, N=topo).
## NW=cima-esq | NE=cima-dir | SE=baixo-dir | SW=baixo-esq
## Ver DIRECTION_GLOSSARY.md §3 e §6.
const _EDGE_BY_SUFFIX: Dictionary = {
	"NW": [Vector2i(-1, 0)],
	"NE": [Vector2i( 0,-1)],
	"SE": [Vector2i( 1, 0)],
	"SW": [Vector2i( 0, 1)],
}
```

---

### 4. `wall_container.gd`

#### 4a. Substituir `FACE_CENTER_OFFSET` inteiro

**Localizar:**
```gdscript
const FACE_CENTER_OFFSET: Dictionary = {
	"NW": Vector2(-16.0, -12.0),
	"NE": Vector2(-16.0, -28.0),
	"SE": Vector2( 16.0, -28.0),
	"SW": Vector2( 16.0, -12.0),
}
```

**Substituir por:**
```gdscript
## Offset do centro do Sprite2D relativo a map_to_local(face_subcells[0]).
## Sistema vértice-alinhado: NW=cima-esq, NE=cima-dir, SE=baixo-dir, SW=baixo-esq.
## Derivado: base_y(−20) + straddle de meia-aresta.
## Calibrar apenas base_y e |x| — respeitar a simetria do glossário.
## Ver DIRECTION_GLOSSARY.md §5.
const FACE_CENTER_OFFSET: Dictionary = {
	"NW": Vector2(-16.0, -28.0),   ## cima-esquerda: straddle esquerda, aresta alta
	"NE": Vector2( 16.0, -28.0),   ## cima-direita:  straddle direita,  aresta alta
	"SE": Vector2( 16.0, -12.0),   ## baixo-direita: straddle direita,  aresta baixa
	"SW": Vector2(-16.0, -12.0),   ## baixo-esquerda: straddle esquerda, aresta baixa
}
```

---

### 5. `compass_rose.gd`

#### 5a. Substituir o bloco de comentário de direções + `_DIRS` inteiro

**Localizar:**
```gdscript
## CompassRose — debug overlay showing isometric N/E/S/W on screen.
## Drawn at the bottom-right corner in screen space (CanvasLayer child).
## Directions assume dimetric 45° horizontal:
##   N = upper-right  |  E = lower-right
##   S = lower-left   |  W = upper-left
extends Control
...
const _DIRS: Array = [
	{"lbl": "N", "dir": Vector2( 1.0, -1.0)},
	{"lbl": "E", "dir": Vector2( 1.0,  1.0)},
	{"lbl": "S", "dir": Vector2(-1.0,  1.0)},
	{"lbl": "W", "dir": Vector2(-1.0, -1.0)},
]
```

**Substituir por:**
```gdscript
## CompassRose — debug overlay, sistema vértice-alinhado (N=topo do diamante).
## N/E/S/W apontam para os vértices do tile isométrico.
## As faces de parede (NW, NE, SE, SW) ficam nas arestas ENTRE os vértices.
## Ver DIRECTION_GLOSSARY.md §2 e §8.
extends Control
...
const _DIRS: Array = [
	{"lbl": "N", "dir": Vector2( 0.0, -1.0)},   ## vértice topo   (↑)
	{"lbl": "E", "dir": Vector2( 1.0,  0.0)},   ## vértice direita (→)
	{"lbl": "S", "dir": Vector2( 0.0,  1.0)},   ## vértice base   (↓)
	{"lbl": "W", "dir": Vector2(-1.0,  0.0)},   ## vértice esquerda (←)
]
```

---

### 6. `build_tileset.gd` *(se ainda referenciar direções como strings)*

Verificar se o arquivo usa strings `"NW"`, `"NE"`, `"SE"`, `"SW"` como keys ou
em tile names. Se sim, aplicar a mesma rotação de labels. Se não usa (porque
o sistema de paredes agora é Container), pular este passo e registrar o fato.

---

## DO NOT TOUCH

- **Valores** de `SUBCUBE_FACE_OFFSETS` em `room.gd` — não mudam.
- **Lógica** de `_build_wall_containers()` — não muda.
- **`WallEdgeData`** — não usa direction strings; opera em `Vector2i` raw.
- **`subcube_coords.gd`** — direction-agnostic; não toca.
- **Qualquer arquivo de gameplay** (A\*, guard FSM, TicSystem) — não toca.
- **PNGs em `source_assets/subcubes/`** (`subcube_concrete.png` etc.) — direction-agnostic; não renomear.

---

## ACCEPTANCE

### Parse
```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
```

### Estrutural — verificar que o rename foi completo e não deixou referências antigas
```bash
## ZERO ocorrências do padrão antigo (NW=cima-direita, SW=cima-esquerda)
## Verificar: on_nw antiga (cell.y == min_y) não deve mais existir
grep -n "on_nw.*min_y\|on_se.*max_y\|on_sw.*min_x\|on_ne.*max_x" \
  godot/scripts/world/maps/map_geometry.gd
# esperado: ZERO linhas

## EDGE_BY_SUFFIX tem a nova associação
grep -A5 "_EDGE_BY_SUFFIX" godot/scripts/world/maps/subcube_geometry.gd
# esperado: "NW": Vector2i(-1, 0)   (cima-esquerda)

## _edge_delta_to_dir retorna NW para (-1,0)
grep -A6 "_edge_delta_to_dir" godot/scripts/world/room.gd | grep "\-1.*0"
# esperado: return "NW"

## compass_rose usa vetores cardinais (não diagonais)
grep "dir.*Vector2" godot/scripts/ui/compass_rose.gd
# esperado: 4 linhas com (0,-1), (1,0), (0,1), (-1,0)

## Apenas os arquivos do MODULE alterados
git diff --name-only
```

### Sanidade visual no jogo
- O widget de compasso mostra **N apontando direto para cima** (não diagonal).
- Nenhuma mudança visual nas paredes (geometry inalterada, apenas labels).
- Logs do Godot: sem erros de "key not found" em nenhum dict de direção.

---

## NOTA DE DOCUMENTAÇÃO (fora do escopo deste prompt)

Os seguintes arquivos contêm referências à nomenclatura antiga e devem ser
atualizados manualmente ou via prompt separado:

| Arquivo | O que atualizar |
|---|---|
| `docs/technical/SUBCUBE_WALL_STRADDLE.md` | Remover seção de "v1/v2/v3 offsets", tabela com (12,-6), referências Kenney |
| `docs/technical/ASSET_MAP.md` | Atualizar nomes `wall_NW/NE/SE/SW` em `master_assets/walls/` |
| `PROMPTS/WALL-EDGE-01-subcube-straddle.md` | Arquivo histórico — mover para DONE, não editar |
| `SUBCUBE_WALL_STRADDLE.md` (raiz) | Idem |
| `WALL_EDGE_SYSTEM.html` | Atualizar tabela de direções §Fase 01; remover WALL_OFFSET/CORNER_OFFSET com HALF_STEP/QUARTER_STEP derivados de Kenney |

---

**Escopo:** 5–6 arquivos · rename puro · 1 sessão.
**Próximo:** Calibração final do `FACE_CENTER_OFFSET` (§5 do glossário) e CONTAINER-04 (corner fill explícito se necessário após validação visual).
