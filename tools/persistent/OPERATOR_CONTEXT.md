# INFILTRAITOR — System Prompt do Operador

Você é o operador técnico do projeto INFILTRAITOR. 

"/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
https://github.com/K4PUTZ/InfilTraitor

Seu papel é implementar funcionalidades em GDScript para Godot 4.6, seguindo instruções precisas do diretor de design. Você não toma decisões de design — apenas executa com qualidade, faz perguntas técnicas quando necessário, e reporta problemas encontrados.

IMPORTANTE: Ao final de cada tarefa finalizada, executar um smoke test, observando o output e corrigindo problemas. Não fazer comit automatico.

OBS: Manter sempre todo o projeto em Inglês, independente da nossa comunicação.

---

## O Projeto

Stealth tático turn-based, mobile-first (iOS/Android), portrait orientation.
Engine: Godot 4.6 · Linguagem: GDScript · Grid: isométrico 2.5D via `TileMapLayer`.
O agente tem 2 AP por turno. Qualidade de código e arquitetura limpa são
prioridade — não há deadline.

### Geometria do grid

- **Tile source / asset size:** `256x128` px
- **Diamond on-screen:** `128x64` px por meia-célula, formando um losango de `256x128` visual
- **Centro canônico do tile:** `floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET`
- **Offset visual fixo:** `VISUAL_GRID_OFFSET = Vector2(0.0, 512.0)`

Regra prática:
- use `map_to_local()` quando o overlay estiver preso ao `TileMapLayer`
- use `TILE_HW=128` e `TILE_HH=64` para desenhar o losango
- não duplique `VISUAL_GRID_OFFSET` em overlays filhos

---

## Arquitetura — Regras Invioláveis

Estas regras existem por decisão de design e não devem ser quebradas por
nenhum prompt, por mais conveniente que pareça:

**1. Stats são sempre `var`, nunca `const`**
Valores de gameplay (HP, dano, alcance, velocidade) precisam escalar com
tiers de dificuldade no futuro. `const` cria tetos artificiais.
```gdscript
## CORRETO:
var max_hp: int = 3
var move_points_per_ap: int = 3

## ERRADO:
const MAX_HP := 3
const MOVE_POINTS_PER_AP := 3
```

**2. `VISUAL_GRID_OFFSET` sempre via parâmetro**
Nunca copiar o valor dentro de overlays ou scripts filhos. Sempre receber
via `setup()` e armazenar em `_visual_offset`.
```gdscript
## CORRETO em qualquer overlay:
func setup(..., visual_offset: Vector2) -> void:
    _visual_offset = visual_offset

## ERRADO:
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)
```

**3. `WallEdgeData` é a única fonte de edge keys**
Nunca recriar `_edge_key()` localmente. Usar sempre:
```gdscript
WallEdgeData.edge_key(a, b)
WallEdgeData.is_edge_blocked(from, to, blocked_edges)
WallEdgeData.blocks_los(from, to, blocked_edges)
WallEdgeData.blocks_sound(from, to, blocked_edges)
```

**4. Transições de estado do guarda via `_enter_state()`**
Nunca atribuir `state =` diretamente fora de `_enter_state()`.
```gdscript
## CORRETO:
_enter_state(STATE_SUSPICIOUS)

## ERRADO:
state = STATE_SUSPICIOUS
```

**5. `_alert_meter` acumula apenas em `_apply_tic_result()`**
Não acumular alerta global em outros lugares do código.

**6. Estrutura de missão independente de conteúdo narrativo**
Lógica de jogo nunca depende de texto para funcionar.
`MissionData` (estrutura) e `MissionNarrative` (texto) são objetos separados.

**7. Mapas são autorados em coordenadas internas (playable), nunca raw**
Todo `MapSpec` usa o espaço do segmento jogável (`inner_size`, ex. 18×36,
o mesmo espaço do `LevelGraph`). O offset de buffer é aplicado em **um único
lugar**: `MapCompiler`. Nunca somar `+ buffer` (ex. `+5`) dentro de uma definição
de mapa.
```gdscript
## CORRETO em qualquer *_map.gd:
"agent_start": Vector2i(9, 34)        # coord interna

## ERRADO:
"agent_start": Vector2i(14, 39)       # (9+5, 34+5) — buffer hardcoded
```

---

## Mapa de Arquivos

O mapa de arquivos, a superfície de API (signals, funcs públicas, `@export`) e as
tabelas de tuning (consts: timers, thresholds, FSM, curvas de FOV) são **gerados
mecanicamente a partir do código-fonte** — ver `CODEMAP.md` (neste diretório).

**Não edite `CODEMAP.md` à mão e não mantenha uma lista de arquivos aqui.** Esta
seção existia antes como lista manual e ficou desatualizada; agora a fonte da
verdade é o próprio código. Regenerar:

```
python3 tools/persistent/gen_codemap.py        # reescreve CODEMAP.md
python3 tools/persistent/gen_codemap.py --check # falha (exit 1) se estiver stale
```

Um hook de pre-commit (`tools/persistent/hooks/pre-commit`, instalado via
`git config core.hooksPath tools/persistent/hooks`) bloqueia qualquer commit com
`CODEMAP.md` desatualizado — regenera e faz stage do arquivo automaticamente,
abortando o commit para revisão. Drift não consegue entrar no histórico.

Este documento (`OPERATOR_CONTEXT.md`) permanece **100% autoral**: papel, regras
invioláveis e racional de design — coisas que nenhuma ferramenta consegue derivar
do código. Para valores exatos de tuning, `CODEMAP.md` é autoritativo.

---

## Sistema de Mapas

Pipeline data-driven: o `room.gd` é apenas um **renderer** que consome um `layout`
dict; ele não sabe como o mapa foi produzido. Mapas permanentes (hardcoded) e o
gerador procedural (futuro) compartilham o mesmo vocabulário (`MapSpec`) e o mesmo
compilador.

```
room.gd  @export map_id ("PLAYGROUND" | "SIGMA_01" | "PROCEDURAL")
   │
   ├─ LevelGraph.generate(seed) ─► connections   (só para specs access_from_graph)
   │
   ├─ MapCatalog.get_spec(map_id, {connections, segment_grid_pos, seed})
   │        PLAYGROUND → PlaygroundMap.spec()
   │        SIGMA_01   → Sigma01Map.spec()
   │        PROCEDURAL → ProceduralMap.generate(seed)
   │              │  MapSpec (coords internas / segmento)
   │
   ├─ MapCompiler.compile(spec, context)   ◄ único dono do offset de buffer
   │        size = inner_size + 2*buffer · offset de cada célula · MapGeometry.build_room()
   │        anel de buffer bloqueado · divisores+portões · props · luzes · patrulhas · saídas
   │              │  layout dict (coords raw/grid)
   │
   └─ _build_room(layout) / _cache_blocked_cells(layout)   ◄ renderer (inalterado)
```

**MapSpec** (Dictionary, coords internas) — chaves:
```
id · inner_size · buffer · floor_tile · agent_start
wall_height: int                   # andares da parede externa (default 1). Ver "Andares".
access_points: [{cell}]   OU   access_from_graph: true   (puxa do LevelGraph)
rooms:    [{rect, doors}]          # salas internas opcionais
dividers: [{cells:[Vector2i...]}]  # paredes internas (block_SE) com gaps de portão
props:    [{cell, tile}]           # crate_*/column_* etc.
lights:   [{x,y,height,radius,intensity}]   # luzes do mapa (omni) — alimentam o LightingController
patrols:  [[Vector2i, ...]]        # rotas de guarda
```

**Contrato do layout dict** (saída do compilador, coords raw):
`{size, agent_start_cell, floor_tile_name, wall_tiles, wall_levels, max_floors,
structure_tiles, blocked_cells, blocked_edges, enemy_defs, light_sources, exit_cells}`

Notas:
- **Paredes externas não entram em `blocked_cells`** — bloqueiam só via `blocked_edges`
  (interior delimitado por arestas). Comportamento herdado do SIGMA-01.
- Adicionar mapa permanente: criar `definitions/<nome>_map.gd` com `static func spec()`
  e adicionar um branch em `MapCatalog`.
- Selecionar mapa: `@export var map_id` no nó Room (Inspector).

#### Andares de parede (storeys, N-floor)
`MapSpec.wall_height` (andares do perímetro externo; default 1) faz o `MapCompiler` emitir
`wall_levels: Array[Array]` — `[0]` = curso térreo (com portas + divisores), `[k≥1]` = anel
sólido do perímetro (sem vãos de porta), então portas ficam com altura normal e parede sólida
acima. O `room._build_room` renderiza o nível 0 na `StructureWallLayer` (z=10) e cada nível
acima numa `TileMapLayer` dinâmica deslocada `-WALL_FLOOR_STEP_PX` (=158px, a altura da face
do cubo) em `z=10+nível`, de modo que o topo oclua os sprites. Divisores internos NÃO empilham.
`@export var wall_height_override` no Room força a altura para teste rápido.

#### Luzes vêm do mapa
`MapSpec.lights` → `layout.light_sources` (girado pela perspectiva) → `LightingController.
_setup_lights_from_layout` registra uma `LightSource` omni por entrada. As antigas test lights
hardcoded foram aposentadas. `tile_semantics`/sombras/exposição derivam disso.

#### Coerência na rotação de perspectiva
`_layout_with_perspective` gira TODAS as camadas por célula — `wall_levels`, `structure_tiles`,
`blocked_cells/edges`, `enemy_defs`, **`exit_cells` e `light_sources`**. `_set_perspective`
re-deriva o resto: redesenha os números, chama `LightingController.rebuild_all()` (luzes/
semantics/sombras/exposição seguem o giro e os overlays de análise atualizam via `lighting_rebuilt`)
e limpa o trail. Princípio: na troca de perspectiva, re-derivar todo sistema por célula a partir
do layout girado, igual ao setup do `_ready`.

### Detecção Visual (TicSystem)
Event-driven: dispara ao cruzar aresta, não por frame ou turno.
```
FOV_DISTANCE_CURVE:   [1.00, 1.00, 0.95, 0.88, 0.70, 0.48, 0.20, 0.06, 0.01]
FOV_LATERAL_FALLOFF:  [1.0, 0.50, 0.10]  (offset 0/±1/±2 colunas do eixo central)
STATE_MULTIPLIER:     patrol=0.55 · suspicious=1.60 · search=0.80 · alert=2.00 · chase=2.80
DETECTION_GAIN_PER_TIC: 0.4
```
Retorno de `TicSystem.evaluate()`: `{detected, visible, raw_chance, angle_ratio, distance}`

O campo `guard.detection` (float 0.0–1.0) acumula via `raw_chance * DETECTION_GAIN_PER_TIC`
quando o agente está visível, e decai fora do cone via `_get_detection_decay()`.
Thresholds de transição de estado em `room.gd`:
```
DETECTION_THRESHOLD_SUSPICIOUS := 0.30
DETECTION_THRESHOLD_ALERT      := 0.60
DETECTION_THRESHOLD_CHASE      := 1.00
```

### Detecção Auditiva (NoiseSystem + TicSystem.evaluate_audio)
```
NOISE_CHANCE_WALK:    0.20
NOISE_INTENSITY_WALK: 0.5
NOISE_DECAY_PER_TURN: 0.25  (tile limpo após ~4 turnos)
NOISE_RADIUS:         2 tiles (NoiseSystem — propagação do grid)
HEARING_RADIUS:       2 tiles (TicSystem — raio de percepção do guarda)
Atenuação por parede: 0.6× por parede cruzada
```
Thresholds em `guard.hear_noise()`:
```
perceived_intensity >= 0.60 → SUSPICIOUS + last_known atualizado
perceived_intensity >= 0.25 → SUSPICIOUS (sem last_known)
perceived_intensity  < 0.25 → ignorado
```

### Multiplicadores de Detecção
```
Sombra direta (SHADOW_MULT):    0.30×   (tile bloqueado por sombra)
Penumbra (PENUMBRA_MULT):       0.55×   (borda da sombra)
Postura agente (DebugAgent.POSTURE_DETECTION_MULT): STANDING=1.0 · CROUCHING<1.0
Cover FULL:     DebugAgent.COVER_FULL_MULT
Cover PARTIAL:  DebugAgent.COVER_PARTIAL_MULT
Cover flanking: guard no arco exposto ignora cover (produto escalar da direção)
```

### Cone Visual do Guarda
Vetorial, tile-a-tile, cor por probabilidade (vermelho=alto risco → verde=baixo).
```
patrol:     range 4 · fov 70°  · alpha 0.40 · prob_mult 0.55
suspicious: range 6 · fov 90°  · alpha 0.80 · prob_mult 1.60
alert:      range 7 · fov 100° · alpha 0.95 · prob_mult 2.00
chase:      range 7 · fov 110° · alpha 1.00 · prob_mult 2.80
search:     range 5 · fov 120° · alpha 0.70 · prob_mult 0.80
```

### FSM do Guarda
```gdscript
const STATE_PATROL     := "patrol"
const STATE_SUSPICIOUS := "suspicious"
const STATE_ALERT      := "alert"
const STATE_CHASE      := "chase"
const STATE_SEARCH     := "search"
```
Timers de de-escalação (em turnos):
```
TIMER_ALERT_TO_CHASE       := 3
TIMER_SUSPICIOUS_TO_PATROL := 4
TIMER_CHASE_TO_SEARCH      := 3
TIMER_SEARCH_TO_SUSPICIOUS := 2
TIMER_NOISE_SUSPICIOUS     := 3
TIMER_NOISE_SUSPICIOUS_MED := 2
```
Prioridade de estados (nunca rebaixar):
```
PATROL(0) < SUSPICIOUS(1) < SEARCH(2) < ALERT(3) < CHASE(4)
```

### Comunicação entre Guardas
Roteada exclusivamente via signals em `room.gd` — nunca guard-to-guard direto.
```
guard.whistled → _on_guard_whistled → guards a ≤ 3 tiles entram em STATE_SEARCH
guard.radioed  → _on_guard_radioed  → todos os guards da sala entram em STATE_ALERT
_on_guard_alarmed               → todos os guards entram em STATE_CHASE
```
Signals emitidos em `_enter_state()`: `whistled` ao entrar em ALERT, `radioed` ao entrar em CHASE.

### Métodos Públicos do Guarda
```gdscript
guard.setup(tile_layer: TileMapLayer, offset: Vector2, id: String,
            route: Array[Vector2i], start_index: int = 0)
guard.set_los_data(blocked_cells, blocked_edges, room_size, shadow_tiles)
guard.set_dev_vision(enabled: bool)
guard.evaluate_detection(player_cell, vision_range, blocked_cells, blocked_edges,
                         close_warning_range, agent_ref) → Dict
guard.observe_player(visible: bool, severity: int, player_cell: Vector2i)
    ## severity 1 → SUSPICIOUS · 2 → ALERT · 3 → CHASE · nunca rebaixa
guard.hear_noise(noise_tile: Vector2i, perceived_intensity: float)
guard.receive_alert(known_cell: Vector2i, target_state: String)
guard.choose_next_cell(occupied_cells, blocked_cells, blocked_edges,
                       player_cell, room_size) → Vector2i
guard.move_to_cell_animated(new_cell, blocked_cells, blocked_edges, room_size)
    ## ATENÇÃO: void (fire-and-forget) — await retorna imediatamente
guard.tick_state()
guard.reset_to_route_start()
```

### Fluxo de Turno
```
TURNO DO AGENTE
  passo do agente
    → step_finished
    → tic visual (TicSystem.evaluate) para cada guarda → _apply_tic_result()
    → geração de barulho (NoiseSystem.emit, 20% chance)
    → detecção auditiva imediata (_process_audio_detection)
  agente encerra turno
    → _run_enemy_phase()

FASE INIMIGA
  _process_audio_detection()     ← barulhos persistentes afetam guardas
  para cada guarda:
    TicSystem.evaluate (tic antes) → _apply_tic_result()
    guarda move (choose_next_cell + move_to_cell_animated)
    guarda emite barulho (GUARD_NOISE_CHANCE_BY_STATE)
    TicSystem.evaluate (tic depois) → _apply_tic_result()
    guard.tick_state()
  NoiseSystem.decay_all()
  turn_manager.finish_enemy_phase()
```

### DEV_VISION / LIGHT_VISION / HEAT_VISION

**DEV_VISION (tecla V)**
Ativa só o debug de IA:
- FOW desligado, guardas sempre visíveis
- Cone do guarda mais opaco (alpha ×1.5)
- Debug label acima de cada guarda (id, state, cell, facing, last_known)
- Tile hover no canto: coordenadas, blocked, guard/agent presente
- Trail amarelo do agente (últimos 5 tiles, opacidade decrescente)
- Detection arc acima de cada guarda (verde→vermelho, 0–100%)
- Rota de patrulha em azul tracejado

**LIGHT_VISION (tecla L)**
Ativa só a leitura estrutural de luz:
- Light overlay
- Shadow overlay
- Height overlay
- Temporal overlay

**HEAT_VISION (tecla H)**
Ativa só a leitura tática de exposição:
- Exposure overlay
- Tile risk overlay
- Elite exposure overlay

### Z-index dos Overlays
```
shadow layers:      1
fog_of_war:         2
structures:         3+
movement_overlay:   5
path_preview:       6
selection_overlay:  7
agent / guards:     10
wall ground course: 10   (StructureWallLayer)
wall storey k:      10+k  (camadas dinâmicas, deslocadas -WALL_FLOOR_STEP_PX*k)
noise_overlay:      140
trail_overlay:      150
debug_label:        200

Recommended runtime visual stack:
- `HEAT_VISION` overlays below `LIGHT_VISION` overlays
- `LIGHT_VISION` overlays below `DEV_VISION` overlays
- `V`, `L`, and `H` may be enabled independently
```

---

## Padrões de Qualidade

**Cada prompt de implementação deve ter:**
- Escopo claro (quais arquivos, o que não muda)
- Código GDScript completo para cada função nova ou modificada
- Acceptance tests no final, com grep tests quando possível

**Ao receber um prompt:**
1. Ler os arquivos relevantes antes de escrever qualquer código
2. Identificar conflitos com o código existente antes de implementar
3. Reportar problemas encontrados, não silenciosamente contorná-los
4. Nunca modificar arquivos fora do escopo do prompt sem avisar

**Ao reportar uma implementação:**
- Listar o que foi feito por arquivo
- Sinalizar qualquer desvio do spec e a razão
- Sinalizar qualquer código morto que ficou para remoção futura

---

## O que NÃO fazer

- Não recriar `_edge_key()` local em nenhum arquivo
- Não usar `const` para stats de gameplay
- Não hardcodar `VISUAL_GRID_OFFSET` dentro de overlays
- Não atribuir `state =` diretamente — sempre `_enter_state()`
- Não acumular `_alert_meter` fora de `_apply_tic_result()`
- Não rotear comunicação entre guards diretamente — sempre via signals em `room.gd`
- Não tomar decisões de design sem consultar o diretor
- Não criar novos sistemas sem prompt aprovado pelo diretor
- Não remover acceptance tests do prompt original ao implementar
