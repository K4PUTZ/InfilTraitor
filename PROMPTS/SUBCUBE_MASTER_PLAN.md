# INFILTRAITOR — Subcube Architecture Master Plan

> **Decisões de design de 2026-06-24. Última revisão: 2026-06-24 (sessão 2).**

---

## Contexto

A conversa de design de 24/06/2026 consolidou a seguinte arquitetura:

- **O mapa continua 2D** — `blocked_edges`, `blocked_cells`, LOS, pathfinding,
  cobertura: zero mudança. A engine de gameplay não sabe de "andares" nem de subcubos.
- **O render é 3D via subcubos** — `room._build_room` emite tiles de 1-subcubo em N
  TileMapLayers empilhadas, criando volume isométrico sem geometria 3D real.
- **O subcubo é a unidade atômica** — toda parede e estrutura é composta por 1 ou
  mais subcubos idênticos. Variação de textura vem de combinação, paletas de cor, e
  assets authoriados para casos especiais.
- **Andares teóricos são conveniência de design** — `SUBCUBES_PER_FLOOR = 4` existe
  só para level design ("parede de 2 andares = 8 subcubos"). A engine processa apenas
  `N subcubes`, sem hierarquia de andares.
- **Pack Kenney removido** — `blocks-prototype/` descontinuado. Todo asset vem de
  `source_assets/` (gerado programaticamente ou authoriado pelo art director).
  `build_tileset.gd` passa a single-source scan sem fallback.

---

## Constantes-chave

| Constante | Valor | Origem |
|---|---|---|
| `SUBCUBES_PER_FLOOR` | `4` | decisão de design (40px × 4 = 160px = 1 andar) |
| `SUBCUBE_FACE_HEIGHT` | `40 px` | art: `WALL_HEIGHT(160) / VCUBES_FULL(4)` |
| `SUBCUBE_STEP_PX` | `39.5 px` | render: `WALL_FLOOR_STEP_PX(158.0) / 4` |
| `MAX_SUBCUBES` | `28` | 7 andares teóricos × 4; reduzível por mapa |
| `WALL_BASE_Z_INDEX` | `10` | inalterado — `room.gd` existente |

> **Nota sobre o 0.5px:** `SUBCUBE_STEP_PX = 39.5` vs `SUBCUBE_FACE_HEIGHT = 40`
> gera um overlap de 0.5px entre subcubos adjacentes — mesmo comportamento do
> sistema atual entre storeys (`158px step` vs `160px art`). O overlap sela
> juntas de pixel. Não alterar.

---

## Asset Naming Convention

### Regra geral

```
[tipo][Variante]_[Direção]
```

- `[tipo]` — papel semântico: `wallFace`, `wallCornerFace`, `floor`, `block`
- `[Variante]` — modificador opcional para formas especiais (omitido no padrão)
- `[Direção]` — `NW | NE | SW | SE`, omitido para assets omnidirecionais

### Assets canônicos por gerador

| Nome | Tipo | Generator | Notas |
|---|---|---|---|
| `wallFace_NW/NE/SW/SE` | Parede 1-subcubo (40px) | `generate_master_walls.py` | **Unidade atômica de parede** |
| `wall_NW/NE/SW/SE` | Parede 4-subcubos (160px) | `generate_master_walls.py` | Composta, compatibilidade |
| `wallHalf_NW/NE/SW/SE` | Parede 2-subcubos (80px) | `generate_master_walls.py` | Composta, compatibilidade |
| `wallCorner_NW/NE/SW/SE` | Corner parede (160px) | `generate_master_walls.py` | Geometria especial |
| `wallCornerHalf_NW/NE/SW/SE` | Corner meia (80px) | `generate_master_walls.py` | Geometria especial |
| `floor_NW/NE/SW/SE` | Diamante de chão | `generate_master_floor.py` | Mesmo art em todas as dirs |
| `block_NW/NE/SW/SE` | Bloco sólido 1-subcubo | `generate_master_block.py` | 3 faces visíveis |
| `crate` | Caixote (omnidirecional) | `generate_master_crate.py` | Existente ✅ |

### Assets authoriados (art director)

Ficam em `source_assets/authored/`. Naming livre mas deve seguir
`[nome]_[Direção]` para tiles direcionais. Registrados automaticamente pelo
scan recursivo de `build_tileset.gd`.

### Sistema de paletas (planejado, não implementado)

`generate_variants.py --base door_frame_NW.png --palette concrete,metal,wood`
— recebe um PNG authoriado e aplica troca de `(flat_color, grid_color, edge_color)`,
gerando N variações sem retrabalho de geometria. Paletas em
`tools/asset_generation/palettes/*.json`.

---

## Estrutura de pastas

`master_assets/` e `blocks-prototype/` **removidos**.

```
ASSETS/ISOMETRIC/
└── source_assets/              ← único source de verdade, scan recursivo
    ├── generated/              ← gerado por scripts Python — NÃO editar manualmente
    │   ├── wallFace_NW.png ... wallFace_SE.png
    │   ├── wall_NW.png ... wall_SE.png
    │   ├── wallHalf_NW.png ... wallHalf_SE.png
    │   ├── wallCorner_NW.png ... wallCorner_SE.png
    │   ├── wallCornerHalf_NW.png ... wallCornerHalf_SE.png
    │   ├── floor_NW.png ... floor_SE.png
    │   ├── block_NW.png ... block_SE.png
    │   └── crate.png
    └── authored/               ← authoriado pelo art director
        └── (futuro: door frames, props especiais, etc.)
```

`build_tileset.gd`: remover `TILES_PATH` e `MASTER_PATH`. Novo único path:
`SOURCE_PATH = "res://ASSETS/ISOMETRIC/source_assets/"`. Scan recursivo, sort
alfabético, sem merge, sem fallback. O scan recursivo já trata subpastas.

---

## Regras dos geradores Python

Todo gerador deve respeitar as três faces visíveis da câmera isométrica:

- **`_draw_front`** — face vertical principal. Grades: `HCUBES` colunas +
  `vcubes` bandas horizontais.
- **`_draw_top`** — face superior fina mostrando espessura. Grades: `HCUBES`
  colunas (fix aplicado em SUB-00-A). Sem bandas (face muito rasa).
- **`_draw_end`** — face lateral câmera-visível. Grades: `vcubes` bandas
  horizontais (fix aplicado em SUB-00-A). Sem colunas (32px de profundidade é
  insuficiente para subdivisão vertical em mobile).

---

## Fases e Etapas

Cada etapa = um prompt de operador. Escopo pequeno, smoke test ao final.

---

### FASE 0 — Fundação de Assets

#### SUB-00-A — Fix geradores + gerar `wallFace`

**Objetivo:** Corrigir `_draw_top` e `_draw_end` em `generate_master_walls.py`;
adicionar geração de `wallFace` (40px, 1 banda). Não rebuildar tileset ainda
(build_tileset.gd ainda depende do Kenney — SUB-00-B o substitui).

**Arquivo:** `tools/asset_generation/generate_master_walls.py`

Fixes: adicionar `HCUBES` colunas em `_draw_top`; adicionar parâmetro `vcubes`
em `_draw_end` e `vcubes` bandas horizontais; adicionar
`generate("wallFace", 40, 1, OUTPUT_FACES)` ao entry point.

**Acceptance:** 4 PNGs `wallFace_*.png` gerados com face top e face end com
grid correto. Inspeção visual confirma linhas de divisão nas 3 faces.

---

#### SUB-00-B — `build_tileset.gd` single-source + remover Kenney

**Objetivo:** Reescrever `build_tileset.gd` para scan recursivo de
`source_assets/` sem TILES_PATH/Kenney. Mover `master_assets/` → `source_assets/generated/`.
Deletar `blocks-prototype/`. Rebuild tileset.

**Arquivos:** `build_tileset.gd`, filesystem, `OPERATOR_CONTEXT.md`, `ASSET_MAP.md`

**Acceptance:** tileset rebuilt com apenas os assets em `source_assets/`;
`wallFace_NW` aparece no `TileRegistry`; jogo abre sem erros.

---

#### SUB-00-C — `generate_master_floor.py`

**Objetivo:** Criar gerador de floor tile. Produz `floor_NW/NE/SW/SE.png` —
diamante isométrico flat-lit, sem faces verticais.

**Arquivo:** `tools/asset_generation/generate_master_floor.py` (novo)

Canvas 256×512. Diamond: `bN=(128,384)`, `bE=(256,448)`, `bS=(128,512)`,
`bW=(0,448)`. Fill `COLOR_FLAT`, grid `HCUBES×HCUBES` linhas em `COLOR_GRID`.
Output: `source_assets/generated/floor_NW/NE/SW/SE.png` (art idêntica,
4 arquivos para compatibilidade com naming direcional existente).

**Acceptance:** 4 PNGs gerados; `floor_SE` aparece no TileRegistry após rebuild;
mapa SIGMA-01 renderiza chão corretamente.

---

#### SUB-00-D — `generate_master_block.py`

**Objetivo:** Criar gerador de bloco sólido 1-subcubo (3 faces visíveis).
Substitui `block_*` do Kenney e `column_*` (via empilhamento nos mapas).

**Arquivo:** `tools/asset_generation/generate_master_block.py` (novo)

Mesmo canvas 256×512 e diamond base de `generate_master_walls.py`. Três faces:
front (igual `_draw_front`), top (igual `_draw_top`), end (igual `_draw_end`).
Produce `block_NW/NE/SW/SE.png` em `source_assets/generated/`.

**Acceptance:** 4 PNGs gerados; `block_SE` no TileRegistry após rebuild;
dividers no mapa renderizam visualmente corretos.

---

#### SUB-00-E — Substituir `column_*` nos mapas

**Objetivo:** Remover `column_*` de `playground_map.gd` (Kenney, sem gerador).
Substituir por `block_*` ou remover se decorativo apenas.

**Arquivo:** `godot/scripts/world/maps/definitions/playground_map.gd`

**Acceptance:** playground_map abre sem tile lookup errors; props visualmente
coerentes com o novo estilo flat-lit.

---

### FASE 1 — Subcube Render Layer

#### SUB-01-A — Constantes e `_ensure_subcube_layers`

**Objetivo:** Substituir `_wall_upper_layers` por `_subcube_layers` com passo
de `SUBCUBE_STEP_PX = 39.5px`.

**Arquivo:** `godot/scripts/world/room.gd`

```gdscript
const SUBCUBES_PER_FLOOR: int = 4
const SUBCUBE_STEP_PX: float  = WALL_FLOOR_STEP_PX / float(SUBCUBES_PER_FLOOR)
const MAX_SUBCUBES: int       = 28
var _subcube_layers: Array[TileMapLayer] = []

func _ensure_subcube_layers(count: int) -> void:
    while _subcube_layers.size() < count:
        var idx   := _subcube_layers.size() + 1
        var layer := TileMapLayer.new()
        layer.name     = "SubcubeLayer_%d" % idx
        layer.tile_set = _wall_tileset
        layer.position = Vector2(0.0, -SUBCUBE_STEP_PX * float(idx))
        layer.z_index  = WALL_BASE_Z_INDEX + idx
        add_child(layer)
        _subcube_layers.append(layer)
```

**Acceptance:** `grep "_subcube_layers" room.gd` → match; `grep "_wall_upper_layers" room.gd` → zero.

---

#### SUB-01-B — `_build_room` emite subcubos

**Objetivo:** Cada tile de parede emite `wallFace_*` em `structure_wall_layer`
(subcubo 0) e em `_subcube_layers[1..N-1]`.

**Arquivos:** `room.gd` (`_build_room`), `map_compiler.gd` (emitir `wall_subcubes`)

**Acceptance:** SIGMA-01 renderiza paredes em múltiplas layers; nenhuma regressão
de gameplay.

---

### FASE 2 — Wall Occlusion System

#### SUB-02-A — Dither shader

**Arquivo:** `godot/shaders/wall_dither.gdshader` (novo)

Bayer 4×4 ordered dithering. Uniform `fade_amount` (0.0–1.0). `discard` para
pixels abaixo do threshold — pixels sobreviventes 100% opacos, compatíveis com
sombras e luzes.

---

#### SUB-02-B — `WallOcclusionController`

**Arquivo:** `godot/scripts/controllers/wall_occlusion_controller.gd` (novo)

Calcula zona de oclusão analiticamente de `_active_perspective` + `agent.cell`.
5 células no eixo frontal. Tween 0.5s por subcubo. Subcubo 0 (`structure_wall_layer`)
nunca tocado.

---

#### SUB-02-C — Agent z-priority

**Arquivo:** `godot/scripts/agents/agent.gd`

`z_index = WALL_BASE_Z_INDEX + MAX_SUBCUBES + 1`. Agente sempre visível sobre
qualquer subcubo.

**Nota futura:** stroke parcial na fronteira de oclusão — shader no agente com
uniform `occlusion_y_threshold`. Implementar após SUB-02-C.

---

### FASE 3 — Face Lighting

#### SUB-03-A — `FaceLightingController` modo per-layer

Per-layer `modulate` calculado por altura e posição das luzes. Conectado a
`lighting_rebuilt`. Gradiente de iluminação vertical de graça.

#### SUB-03-B — Modo per-tile (precisão)

Para luzes dentro de `PRECISION_RADIUS_TILES` do agente, overlay multiply-blend
por tile individual. `var PRECISION_RADIUS_TILES: int = 4`.

---

### FASE 4 — Vertical Scene

#### SUB-04-A — `MapSpec.wall_subcubes`

Substituir `wall_height` (storeys) por `wall_subcubes` no vocabulário MapSpec.
Retrocompatível.

#### SUB-04-B — Paredes altas nos mapas

SIGMA-01 e Playground com `"wall_subcubes": 12` (3 andares teóricos) para teste
vertical completo.

---

## Dependências entre fases

```
SUB-00-A ──► SUB-00-B ──► SUB-00-C ──► SUB-00-D ──► SUB-00-E
                │
                ▼
SUB-01-A ──► SUB-01-B
                │
        ┌───────┼───────┐
        ▼       ▼       ▼
    SUB-02-A  SUB-03-A  SUB-04-A
    SUB-02-B  SUB-03-B  SUB-04-B
    SUB-02-C
```

---

## O que NÃO muda

| Sistema | Status |
|---|---|
| `blocked_cells` / `blocked_edges` | ✅ Zero mudança |
| LOS / pathfinding / cobertura | ✅ Zero mudança |
| TicSystem / detecção | ✅ Zero mudança |
| Guard FSM | ✅ Zero mudança |
| `MapSpec` (gameplay keys) | ✅ Apenas adição de `wall_subcubes` |
| `ShadowProjector` | ✅ Fica mais simples com subcubos |
| `ExposureSystem` | ✅ Opera em cells 2D, não em layers |

---

## Notas de design para o futuro

- **Stroke de oclusão** — após SUB-02-C.
- **Sistema de paletas** — `generate_variants.py` com paletas JSON. Após FASE 0 completa.
- **Ceiling props** — `MapSpec.ceiling` vocabulary (VIS-01). Gated por SUB-04-B.
- **Props como subcubos** — empilhamento de `block_*`. Após SUB-00-D.
- **`MAX_SUBCUBES`** — reduzir se draw calls impactarem mobile. Profiling antes.

---

**Criado em:** 2026-06-24
**Última revisão:** 2026-06-24 (sessão 2 — remoção Kenney, single-source pipeline)
**Status:** 🟢 Pronto para implementação
**Próximo prompt de operador:** SUB-00-A
