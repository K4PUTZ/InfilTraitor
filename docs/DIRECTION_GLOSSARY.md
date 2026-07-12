# INFILTRAITOR — Direction System Glossary

> **Status:** Canônico · Substitui toda documentação de direção derivada do sistema Kenney.
> **Escopo:** Nomenclatura de direções para código, assets, documentação e UI.
> **Atualizado:** 2026-06-29 — terminologia voxel adicionada (§1, §5, §9, §10); sistema de
> direções NW/NE/SE/SW em si **inalterado**.

---

## 1. O Sistema de Coordenadas

O motor isométrico opera com **dois grids** em layout **DIAMOND_DOWN**, ambos usando o
mesmo `VISUAL_GRID_OFFSET = Vector2(0, 512)`.

### Grid de Gameplay — GAME UNIT

`tile_size = Vector2i(256, 128)` · Guards, A\*, TicSystem, `blocked_edges`, alarms.

```
screen_x = (col - row) × 128
screen_y = (col + row) × 64
```

### Grid de Voxels — VOXEL

`tile_size = Vector2i(32, 16)` · Render de paredes, containers, baking, dirty flag.
8×8 voxels por GAME UNIT em cada eixo.

```
screen_x = (col - row) × 16
screen_y = (col + row) × 8
```

**Conversão GAME UNIT → Voxel:** `voxel_origin = gu_cell × 8`
(único ponto de conversão: `map_compiler.gd`)

> **Nota histórica:** versões anteriores citavam `tile_size (64, 32)` — era o tile do
> sistema de subcubos (CONTAINER-01..04, arquivado). Os offsets `×32` e `×16` na projeção
> pertenciam a esse sistema. O sistema de voxels usa `×16` e `×8` respectivamente.

---

## 2. O Compasso — Vértices N/E/S/W

O compasso é **alinhado por vértice**: cada ponto cardeal corresponde a um
vértice do diamante isométrico.

```
         N (↑)
        ╱   ╲
   NW ╱       ╲ NE
     ╱  TILE   ╲
W (←)   CENTER  (→) E
     ╲           ╱
   SW ╲         ╱ SE
        ╲     ╱
         S (↓)
```

| Ponto | Vértice do diamante | Posição em tela |
|-------|---------------------|-----------------|
| **N** | topo                | direto para cima `(0, -1)` |
| **E** | direita             | direto para a direita `(+1, 0)` |
| **S** | base                | direto para baixo `(0, +1)` |
| **W** | esquerda            | direto para a esquerda `(-1, 0)` |

---

## 3. As Quatro Faces de Parede — Arestas NW/NE/SW/SE

Paredes ficam nas **arestas** entre dois vértices adjacentes.
Cada face é nomeada pela aresta que ocupa:

```
         N
        ╱ ╲
     NW     NE
     ╱  tile ╲
    W         E
     ╲  tile ╱
     SW     SE
        ╲ ╱
         S
```

| Face | Aresta | `edge_delta` (tile) | Direção em tela | x-straddle |
|------|--------|---------------------|-----------------|------------|
| **NW** | entre N e W | `(-1, 0)` | cima-esquerda `(-32, -16)` | esquerda |
| **NE** | entre N e E | `(0, -1)` | cima-direita `(+32, -16)` | direita |
| **SE** | entre S e E | `(+1, 0)` | baixo-direita `(+32, +16)` | direita |
| **SW** | entre S e W | `(0, +1)` | baixo-esquerda `(-32, +16)` | esquerda |

**Invariante de simetria** — para qualquer ajuste de offset:

| Par | Relação |
|-----|---------|
| NW ↔ SE | x oposto, y oposto |
| NE ↔ SW | x oposto, y oposto |
| NW e SW | mesmo `|x|`, partilham o lado esquerdo |
| NE e SE | mesmo `|x|`, partilham o lado direito |

---

## 4. Mapeamento de Bordas do Room

No `map_geometry.gd`, cada borda do rect mapeia para uma face de parede:

| Condição em tile | Borda | Face emitida |
|------------------|-------|-------------|
| `cell.x == min_x` | coluna da esquerda | `wall_NW` |
| `cell.x == max_x` | coluna da direita | `wall_SE` |
| `cell.y == min_y` | linha do topo | `wall_NE` |
| `cell.y == max_y` | linha da base | `wall_SW` |

Portas seguem a mesma convenção: `doorOpen_NW`, `doorOpen_NE`, `doorOpen_SE`, `doorOpen_SW`.

---

## 5. Posicionamento de Paredes — Sistema Voxel

No sistema de voxels, paredes são posicionadas via `TileMapLayer.set_cell()` em
`_voxel_layers[level]`. **Não existe `FACE_CENTER_OFFSET`** — o posicionamento é
analiticamente derivado da geometria do TileSet. Sem calibração empírica.

### VoxelLayer position

```gdscript
## Derivado analiticamente — não alterar empiricamente:
layer.position = Vector2(
    VISUAL_GRID_OFFSET.x,
    VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX * float(level)
)
layer.z_index = WALL_BASE_Z_INDEX + level
```

### Slice placement por direção

Cada aresta de GAME UNIT gera 2 slices — 1 em cada GU adjacente.
O mapping aresta → coordenada de voxel segue a tabela de `_EDGE_BY_SUFFIX` (§6):

| Direção | Slice inner (S0) | Slice outer (S1) |
|---------|-----------------|-----------------|
| **NW** | col 0 de `(gc, gr)` | col 7 de `(gc-1, gr)` |
| **NE** | row 0 de `(gc, gr)` | row 7 de `(gc, gr-1)` |
| **SE** | col 7 de `(gc, gr)` | col 0 de `(gc+1, gr)` |
| **SW** | row 7 de `(gc, gr)` | row 0 de `(gc, gr+1)` |

```gdscript
## NW inner slice — col 0 de GU (gc, gr):
for j in range(VOXELS_PER_UNIT_AXIS):          ## 0..7
    var vs := Vector2i(gc * 8, gr * 8 + j)
    for level in range(VOXELS_PER_UNIT_AXIS * storey_count):
        _voxel_layers[level].set_cell(vs, VOXEL_SOURCE_ID, ATLAS_COORD)
```

Ver `docs/technical/VOXEL_MASTER_PLAN.md` §5 para o algoritmo completo.

> **Arquivado:** `FACE_CENTER_OFFSET` — constante do sistema WallContainer/Sprite2D
> (CONTAINER-01..04). **Não recriar.** Ver §10 Termos Banidos.

---

## 6. _EDGE_BY_SUFFIX — Direção de aresta para delta de voxel

**Localização atual:** [`godot/scripts/geometry/edge_extractor.gd`](../godot/scripts/geometry/edge_extractor.gd)

```gdscript
const _EDGE_BY_SUFFIX: Dictionary = {
    "NW": [Vector2i(-1, 0)],   ## cima-esquerda
    "NE": [Vector2i( 0,-1)],   ## cima-direita
    "SE": [Vector2i( 1, 0)],   ## baixo-direita
    "SW": [Vector2i( 0, 1)],   ## baixo-esquerda
}
```

**Histórico:** Originalmente em `subcube_geometry.gd` (SLICE-01). Integrada ao `EdgeExtractor` na refatoração SLICE-02 (ver [`docs/history/`](../history/)).

---

## 7. Tabela de Migração (sistema antigo → novo)

> Nota: o sistema antigo usava N=direita (convenção Kenney). O novo usa N=cima.
> Os VALUES dos offsets não mudam — apenas as KEYS dos dicionários.

| Antigo | Novo | edge_delta | Motivo |
|--------|------|------------|--------|
| `NW` | `NE` | `(0, -1)` | cima-direita em tela |
| `NE` | `SE` | `(+1, 0)` | baixo-direita em tela |
| `SE` | `SW` | `(0, +1)` | baixo-esquerda em tela |
| `SW` | `NW` | `(-1, 0)` | cima-esquerda em tela |

---

## 8. Compasso UI

> **Nota (2026-07-12):** `compass_rose.gd` foi removido — era um overlay de debug
> órfão (zero referências, nunca instanciado). A convenção abaixo permanece canônica
> e vale para qualquer widget de compasso que venha a ser criado.

O widget mostra os 4 pontos cardeais apontando para os vértices do diamante:

```gdscript
const _DIRS: Array = [
    {"lbl": "N", "dir": Vector2( 0.0, -1.0)},  ## vértice topo   (↑)
    {"lbl": "E", "dir": Vector2( 1.0,  0.0)},  ## vértice direita (→)
    {"lbl": "S", "dir": Vector2( 0.0,  1.0)},  ## vértice base   (↓)
    {"lbl": "W", "dir": Vector2(-1.0,  0.0)},  ## vértice esquerda (←)
]
```

As **faces de parede** (NW, NE, SW, SE) ficam nas **arestas** entre esses vértices —
visualmente entre os braços do compasso, não nos braços.

---

## 9. Assets de Parede

### Sistema atual — Voxels (VOXEL series)

Atoms de voxel não carregam sufixo direcional — o posicionamento direcional é feito
por coordenada no `TileMapLayer`, não por asset separado por direção.

```
source_assets/voxels/
├── voxel_concrete.png     ← 32×36 px (16 top face + 20 side face), direction-agnostic
├── voxel_metal.png
├── voxel_stone.png
└── voxel_wood.png
```

Gerados por `generate_voxel.py`. TileSet: `tileset_voxels.tres`, `tile_size = (32, 16)`,
`texture_origin = (0, 0)` (sem calibração empírica).

### Sufixos direcionais — floors, blocks e estruturas (inalterado)

Assets de floor, block e prop continuam usando sufixo `_NW`, `_NE`, `_SE`, `_SW`
conforme este glossário — apenas paredes voxel dispensam o sufixo.

```
source_assets/generated/
├── floor_NW.png / floor_NE.png / floor_SE.png / floor_SW.png
├── block_NW.png / block_NE.png / block_SE.png / block_SW.png
└── ...
```

Portas seguem a mesma convenção: `doorOpen_NW`, `doorOpen_NE`, `doorOpen_SE`, `doorOpen_SW`.

> **Arquivado:** `source_assets/subcubes/subcube_*.png` (átomo 64×72, `generate_subcube.py`,
> sistema CONTAINER-01..04). Não referenciar nem regenerar.

---

## 10. Termos Banidos

Os seguintes termos causaram confusão histórica ou pertencem a sistemas arquivados.
Estão **banidos** do codebase e da documentação:

### Banidos desde RENAME-01 (sistema Kenney)

| Termo banido | Motivo | Substituto |
|---|---|---|
| Qualquer ref. a "Kenney offset derivation" | Sistema extinto | Este glossário |
| `SUBCUBE_FACE_OFFSETS` com comentários "v1/v2/v3" | Histórico confuso | (eliminado — veja abaixo) |
| `on_nw` significando `cell.y == min_y` | Invertia o eixo | `on_ne` (§4) |
| `"N = upper-right"` em qualquer comentário | Contradiz compasso | `"N = topo (vértice)"` |

### Banidos desde VOXEL-00 (sistema WallContainer / subcubo)

| Termo banido | Sistema de origem | Substituto |
|---|---|---|
| `FACE_CENTER_OFFSET` | WallContainer Sprite2D — arquivado | `_voxel_layers[level].set_cell()` (§5) |
| `SUBCUBE_FACE_OFFSETS` | Offset empírico de subcubo — arquivado | `VOXEL_STEP_PX` (derivado analiticamente) |
| `SUBCUBE_BASE_ORIGIN` | Anchor de subcubo — arquivado | `VoxelLayer.position` (§5) |
| `is_x_varying` / `is_y_varying` | Lógica de orientação de WallContainer | Não existe no sistema voxel |
| `blend_rect` para render de paredes | Image compositing de WallContainer | `set_cell()` em `_voxel_layers` |
| `WallContainer.build()` / `.build_corner_fill()` | CONTAINER-01..04 — arquivado | `_place_wall_voxels()` (VOXEL-04) |
| `"subcubo"` / `"subcube"` para render de paredes | Terminologia substituída | `"voxel"` |
| `generate_subcube.py` / `generate_wall.py` | Pipeline de subcubo — arquivado | `generate_voxel.py` |
| `tileset_blocks.tres` entries de wall | Série `wall_*`, `wallHalf_*`, `wallCorner_*` removidos | `tileset_voxels.tres` |
