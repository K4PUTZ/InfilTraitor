# INFILTRAITOR — Subcube Architecture Master Plan

> **Criado:** 2026-06-24 · **Última revisão:** 2026-06-24 (sessão 3 — grid migration)
> Este documento é a fonte de verdade para todas as decisões arquiteturais tomadas
> na sessão de design de 24/06/2026.

---

## Decisões Canônicas

### 1. O subcubo é o tile de gameplay

O sub-tile (subcubo atômico) é simultaneamente a unidade visual E a unidade
de gameplay. `CELL_SIZE` muda de `256×128` para `64×32`. O grid fica 4× mais
fino em cada eixo — 16× mais células no total.

Consequências diretas:
- Todas as coordenadas de mapa são ×4
- Todos os raios e ranges são ×4  
- O agente percorre a mesma distância visual movendo 4 sub-tiles por step
- Assets existentes (64×64 do operador) têm o tamanho correto sem retrabalho

### 2. Pipeline de assets single-source sem Kenney

`blocks-prototype/` e `master_assets/` removidos. Único source:
`source_assets/` — scan recursivo por `build_tileset.gd`. Dois tipos de asset:
- **Atoms** (`subcubes/`) — 64×64px, gerados por Python
- **Compostos** (`generated/`) — 256×512px ou maiores, gerados por compositor PIL
- **Authoriados** (`authored/`) — art do diretor, qualquer tamanho

### 3. Dual-mode rendering: runtime + pre-render

- **Runtime stacking** — `subcube_[material]` em N `TileMapLayer`s por célula.
  Suporta oclusão por layer e face lighting por layer. Padrão para tudo.
- **Pre-render composto** — PNG composto pelo gerador Python para props
  complexos, superfícies texturizadas, ou variações artísticas. Vai no tileset
  como tile único multi-layer.

### 4. Agente e TicSystem

- `AGENT_STEP_CELLS = 4` — agente percorre 4 sub-tiles por step
- TicSystem traça o caminho pelos 4 sub-tiles intermediários, disparando em
  cada aresta cruzada com peso 1/4 por cruzamento (total = 1 step completo)
- Granularidade tática aumenta: guard ouve 4 passos por movimento do agente

### 5. Vertical — andares teóricos mantidos

`SUBCUBES_PER_FLOOR = 4` como conveniência de design. A engine só conhece
N sub-tiles de altura. Mapa pode ter qualquer altura; demo começa com 6-7
andares teóricos (24-28 sub-tiles de altura máxima).

### 6. Doorways e colunas

- **Doorway** = ausência de sub-tiles na célula. Frame decorativo é prop separado.
  Nenhum tile especial de doorway necessário.
- **Colunas** = pilha de `block_[material]` em runtime. Nenhum tile Kenney.

---

## Constantes-chave

| Constante | Valor anterior | Valor novo | Arquivo |
|---|---|---|---|
| `CELL_SIZE` | `Vector2i(256, 128)` | `Vector2i(64, 32)` | `room.gd` / TileSet |
| `TILE_HW` | `128` | `32` | assets Python |
| `TILE_HH` | `64` | `16` | assets Python |
| `CUBE_HEIGHT` | `40` (wall) / `128` (crate) | `32` | assets Python |
| `MAP_SIZE` | `Vector2i(28, 46)` | `Vector2i(112, 184)` | `room.gd` |
| `INNER_ORIGIN` | `Vector2i(5, 5)` | `Vector2i(20, 20)` | `room.gd` |
| `BUFFER` | `5` | `20` | `room.gd` |
| `AGENT_STEP_CELLS` | `1` | `4` | `agent.gd` |
| `SUBCUBES_PER_FLOOR` | `4` | `4` (inalterado) | `room.gd` |
| `SUBCUBE_STEP_PX` | `39.5` | `39.5` (inalterado) | `room.gd` |
| `MAX_SUBCUBES` | `28` | `28` (inalterado) | `room.gd` |
| Light radius | N | 4N | mapas |
| Guard vision range | N | 4N | mapas |
| Shadow depth | N | 4N | mapas |

> **Por que `SUBCUBE_STEP_PX` não muda?** O visual permanece idêntico.
> No sistema antigo, `WALL_FLOOR_STEP_PX = 158px` era o step de 1 storey
> (4 subcubes). No novo sistema, 39.5px é o step de 1 sub-tile (que IS um
> subcubo). A distância em pixels na tela é a mesma — só a granularidade
> do grid mudou.

---

## Asset Naming Convention

```
[tipo]_[material]   → atom direcional-agnostic  (subcube_concrete.png)
[shape]_[material]  → composto pré-renderizado   (wall_concrete.png)
[tipo]_authored     → art do diretor             (door_frame_steel.png)
```

**Tipos de atom:**
- `subcube_*` — cubo 1×1×1, canvas 64×64, 3 faces flat-lit
- `floor_*` — diamond flat, canvas 64×64, só face top
- `block_*` — equivalente ao subcube com geometria de bloco sólido

**Materiais iniciais:** `concrete`, `stone`, `wood`, `metal`

---

## Estrutura de Pastas

```
ASSETS/ISOMETRIC/
└── source_assets/
    ├── subcubes/          ← atoms 64×64 (generate_subcube.py)
    │   ├── subcube_concrete.png  ✅ gerado
    │   ├── subcube_stone.png     ✅ gerado
    │   ├── subcube_wood.png      ✅ gerado
    │   └── subcube_metal.png     ✅ gerado
    ├── generated/         ← compostos PIL (shape generators)
    │   ├── wall_concrete.png     ✅ gerado
    │   ├── wallHalf_concrete.png ✅ gerado
    │   └── wallFace_concrete.png ✅ gerado
    └── authored/          ← art do diretor (futuro)
```

---

## Compositor PIL — Fórmulas Canônicas

Canvas de saída dos compostos: `256×512` (ou maior para props especiais).
Atom: `64×64`. Âncora = bW do floor diamond = pixel `(0, 48)` no canvas 64×64.

```python
# NW wall (corre na direção bW→bN do tile, runs NE in screen)
dest(u, h) = (u * 32,  400 - u * 16 - h * 32)
# u = coluna ao longo da parede (0=esquerda, 3=direita)
# h = altura em sub-tiles (0=base, N=topo)
# painter's order: u decreasing (3→0), h increasing (0→N)

# SE wall (espelho da NW)
dest(u, h) = (u * 32,  400 + u * 16 - h * 32)

# Floor 4×4 (grid plano)
dest(u, v) = (u * 32 + v * 32,  400 - u * 16 + v * 16)
# painter's order: v decreasing (3→0), u increasing (0→3)

# Block (1×1×1)
dest = (0, 400)   # atom único, sem loop
```

---

## Fases de Implementação

### ✅ FASE 0-ALPHA — Átomos e compositor (CONCLUÍDA)

- [x] `generate_subcube.py` — 4 materiais × 64×64 canvas
- [x] `generate_wall.py` — NW wall compositor com offsets corretos

---

### FASE 0 — Fundação de Assets (em andamento)

#### SUB-00-B — `build_tileset.gd` single-source

**Objetivo:** Remover TILES_PATH (Kenney), reescrever scan para single-source
`source_assets/`. Canvas dos tiles: `Vector2i(64, 64)`.

**Mudanças em `build_tileset.gd`:**
- Remover `TILES_PATH`, `MASTER_PATH`, `_scan_master_textures`, `_scan_master_dir`
- Novo `SOURCE_PATH = "res://ASSETS/ISOMETRIC/source_assets/"`
- Nova `_collect_pngs(path, out)` — scan recursivo → array `{name, path}`
- `texture_region_size = Vector2i(64, 64)` (uniforme para todos os atoms)
- Tiles sem sufixo de direção (`subcube_concrete.png`) → registrar como
  `subcube_concrete_NE/NW/SE/SW` com texture_origins correspondentes
- Adicionar `"subcube"`, `"floor"`, `"block"` ao `TILE_PROPS`
- Deletar `blocks-prototype/` e `master_assets/`

**Acceptance:** `subcube_concrete` nos 4 IDs de direção no TileRegistry;
tileset rebuilt sem errors; zero referência a Kenney no codebase.

---

#### SUB-00-C — `generate_master_floor.py`

**Objetivo:** Floor tile = face top do subcubo (diamond flat, sem faces verticais).
Canvas 64×64, mesmo sistema de coordenadas dos atoms.

```python
# Apenas a face top — floor diamond como topo visível
tN=(32,0); tE=(64,16); tS=(32,32); tW=(0,16)
draw.polygon([tN, tE, tS, tW], fill=color_flat, outline=color_edge)
# Grid lines (4×4 subdivisions do floor)
for i in range(1, 4):
    t = i / 4
    draw.line([lerp(tN,tE,t), lerp(tW,tS,t)], fill=color_grid, width=1)
    draw.line([lerp(tN,tW,t), lerp(tE,tS,t)], fill=color_grid, width=1)
```

Output: `floor_concrete.png`, `floor_stone.png`, etc.

---

#### SUB-00-D — `generate_master_block.py`

**Objetivo:** Block = mesmo atom que subcube (ambos são 1×1×1 cubo).
Por enquanto, `block_[material].png` é alias de `subcube_[material].png`.
Separação existe para futura customização de geometria (chanfros, etc.).

Implementação: simplesmente copiar os atoms com nome `block_*`.

---

#### SUB-00-E — Atualizar mapas (×4 + remover Kenney)

**Objetivo:** `sigma_01_map.gd` e `playground_map.gd` com coordenadas ×4.
Remover `column_*` (→ runtime block stack) e `doorway_*` (→ gap).

---

### FASE 1 — Grid Migration

#### GRID-01-A — `CELL_SIZE` e constantes visuais

**Arquivos:** `room.gd`, `build_tileset.gd`

```gdscript
# room.gd
const CELL_SIZE: Vector2i = Vector2i(64, 32)   # era 256×128
const MAP_SIZE:  Vector2i = Vector2i(112, 184)  # era 28×46
const INNER_ORIGIN: Vector2i = Vector2i(20, 20) # era 5×5
const BUFFER: int = 20                           # era 5
const WALL_FLOOR_STEP_PX: float = 39.5          # era 158.0
```

**Acceptance:** mapa abre sem erros; tiles visualmente do tamanho correto.

---

#### GRID-01-B — Coordenadas dos mapas ×4

**Arquivos:** `sigma_01_map.gd`, `playground_map.gd`, todos os `Vector2i`
de posição de célula.

Script de migração sugerido:
```python
# migrate_coords.py — multiplicar todos os Vector2i de posição por 4
# Exceto: tamanhos (wall_height, etc.) que são em sub-tiles já
```

---

#### GRID-01-C — Agente e TicSystem

**Arquivo:** `agent.gd`, `tic_system.gd`

```gdscript
const AGENT_STEP_CELLS: int = 4

# TicSystem: ao invés de teleportar para a célula destino,
# iterar pelas 4 células intermediárias do path
# Peso de detecção por aresta = 1/4 do atual
```

---

#### GRID-01-D — Valores de gameplay ×4

**Arquivos:** todos os mapas, `guard.gd`, configs de LOS

Varredura: `vision_range`, `hearing_range`, `light_radius`, `shadow_depth`.
Substituição mecânica ×4. Nenhuma lógica muda.

---

### FASE 2 — Subcube Render Layers

#### SUB-01-A — `_ensure_subcube_layers`

```gdscript
const SUBCUBES_PER_FLOOR: int = 4
const SUBCUBE_STEP_PX: float   = 39.5  # = WALL_FLOOR_STEP_PX (agora é o step por sub-tile)
const MAX_SUBCUBES: int        = 28
var _subcube_layers: Array[TileMapLayer] = []
```

#### SUB-01-B — `_build_room` emite sub-tiles

Cada célula de parede no `wall_tiles` dict → `subcube_[material]` em
`structure_wall_layer` (layer 0) + `_subcube_layers[1..N-1]`.

---

### FASE 3 — Wall Occlusion System

#### SUB-02-A — Dither shader (`wall_dither.gdshader`)
Bayer 4×4, uniform `fade_amount` 0–1. `discard` abaixo do threshold.

#### SUB-02-B — `WallOcclusionController`
Zona analítica de `_active_perspective` + `agent.cell`. 5 células frontais.
Tween 0.5s por layer. Layer 0 nunca tocada.

#### SUB-02-C — Agent z-priority
`z_index = WALL_BASE_Z_INDEX + MAX_SUBCUBES + 1`. Sempre visível.

**Nota futura:** stroke parcial na fronteira de oclusão — shader no agente
com uniform `occlusion_y_threshold`.

---

### FASE 4 — Face Lighting

#### SUB-03-A — `FaceLightingController` per-layer (fast mode)
`layer.modulate` calculado por altura e posição das luzes. Gradiente vertical
de iluminação emergente de graça. Conectado a `lighting_rebuilt`.

#### SUB-03-B — Per-tile precision mode
Para luzes com `distance < PRECISION_RADIUS_TILES = 4`, overlay multiply-blend
por tile individual.

---

### FASE 5 — Vertical Scene

#### SUB-04-A — `MapSpec.wall_subcubes`
Substituir `wall_height` (em storeys) por `wall_subcubes` (em sub-tiles).
Retrocompatível: `wall_subcubes = wall_height * SUBCUBES_PER_FLOOR`.

#### SUB-04-B — Mapas com paredes altas
SIGMA-01 e Playground com `"wall_subcubes": 12` (3 andares teóricos).

---

### FASE 6 — Sistema de Paletas (futuro)

`generate_variants.py --base door_frame_steel.png --palette concrete,wood,metal`

Recebe PNG authoriado, aplica troca de `(flat_color, edge_color, grid_color)`
via config JSON em `tools/asset_generation/palettes/`. N variações sem
retrabalho de geometria.

---

## Dependências

```
0-ALPHA ✅ → SUB-00-B → SUB-00-C → SUB-00-D → SUB-00-E
                │
                ▼
            GRID-01-A → GRID-01-B → GRID-01-C → GRID-01-D
                │
                ▼
            SUB-01-A → SUB-01-B
                │
        ┌───────┼────────┐
        ▼       ▼        ▼
    SUB-02-A  SUB-03-A  SUB-04-A
    SUB-02-B  SUB-03-B  SUB-04-B
    SUB-02-C
```

---

## O que NÃO muda

| Sistema | Status |
|---|---|
| Algoritmo de LOS | ✅ Mesma lógica, novos valores de entrada |
| A\* pathfinding | ✅ Mesma lógica — 16× mais nós, profiling necessário em device |
| Guard FSM | ✅ Zero mudança |
| TileMapLayer z-order | ✅ Zero mudança |
| Sistema de perspectiva 4-dir | ✅ Zero mudança |
| Shader de FOW | ✅ Zero mudança |
| `blocked_edges` / `blocked_cells` | ✅ Zero mudança — coordenadas novas |
| `ShadowProjector` | ✅ Fica mais simples com sub-tiles uniformes |
| Assets gerados (64×64) | ✅ Tamanho correto sem retrabalho |

---

## Notas de Risco

**A\* com 112×184 grid:** 20.608 nós vs 1.288 atuais (16×). Guards recalculam
raramente — na troca de estado, não por frame. Não bloqueia. Profiling no
device real antes de otimizar.

**TicSystem com 4 crossings por step:** valores de probabilidade de detecção
precisam de retuning (cada crossing tem 1/4 do peso atual). Mecânico, sem
retrabalho de código.

**`WALL_FLOOR_STEP_PX` muda de significado:** era "step de 1 storey" (158px),
vira "step de 1 sub-tile" (39.5px). O valor da constante no `room.gd` muda.
Qualquer código que usa `WALL_FLOOR_STEP_PX` para calcular alturas de storey
precisa ser auditado — multiplicar por `SUBCUBES_PER_FLOOR` onde necessário.

---

**Status:** 🟢 FASE 0-ALPHA concluída · SUB-00-B é o próximo prompt
