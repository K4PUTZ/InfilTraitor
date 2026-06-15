# INFILTRAITOR — Plano de Modularização: room.gd
**Status: PLANNING — não implementar até aprovação por sessão**
**Data:** 2026-06-15

---

## Problema

`room.gd` tem 2124 linhas e acumula 8 domínios distintos:

| Domínio | Linhas estimadas |
|---------|-----------------|
| Instanciação e setup de overlays (8 overlays) | ~300 |
| Sistema de iluminação (registry, projector, exposure) | ~250 |
| Toggle/apply de DEV/LIGHT/HEAT vision | ~200 |
| Câmera (drag, zoom, pinch, leash, perspective) | ~200 |
| Guards (registro, sinais, whistle/radio/alarm, search) | ~300 |
| HUD (botões, labels, alert, banners) | ~150 |
| FOW (reveal, shader, vision fog) | ~150 |
| Coordenador legítimo (tile utils, turns, signal bus) | ~350 |

Toda feature nova arrasta dezenas de linhas num arquivo ilegível. Bugs em um domínio aparecem onde menos se espera.

---

## Meta

> `room.gd` torna-se **exclusivamente** um coordenador: expõe utilitários de grid, mantém o estado compartilhado, roteia sinais entre módulos, e orquestra o fluxo de turno. Não executa lógica de domínio.

**Tamanho alvo:** ≤ 400 linhas (de 2124 atuais).

---

## Estrutura de pastas

```
godot/scripts/
├── agents/          (existente)
├── controllers/     ← NOVA PASTA (todos os módulos vão aqui)
│   ├── vision_controller.gd
│   ├── lighting_controller.gd
│   ├── hud_controller.gd
│   ├── camera_controller.gd
│   ├── fow_controller.gd
│   └── guard_coordinator.gd
├── overlays/        (existente — overlays individuais não mudam)
├── systems/         (existente — LightRegistry, ShadowProjector etc. não mudam)
└── world/           (existente — room.gd permanece aqui)
```

---

## Módulos (por prioridade de extração)

### 1. VisionController — prioridade 1, imediato
**Arquivo:** `controllers/vision_controller.gd`

**Extrai de `room.gd`:**
- Variáveis de estado: `dev_vision`, `light_vision`, `heat_vision`
- Funções: `_toggle_dev_vision()`, `_toggle_light_vision()`, `_toggle_heat_vision()`
- Funções: `_apply_dev_vision()`, `_apply_light_vision()`, `_apply_heat_vision()`
- Função: `_apply_fow_visibility()`
- Função pública: `get_dev_vision_tiles()`
- Instanciação, z-ordering e `add_child()` de todos os 8 overlays de debug/heat
- Todas as variáveis de overlay: `_exposure_overlay`, `_tile_risk_overlay`, `_elite_exposure_overlay`, `_light_overlay`, `_shadow_overlay`, `_height_overlay`, `_temporal_overlay`

**API pública (room.gd chama diretamente):**
```gdscript
func setup(room_ref: Node2D) -> void
func toggle_dev() -> void
func toggle_light() -> void
func toggle_heat() -> void
func get_dev_vision_tiles() -> Dictionary
```

**Emite para room.gd:** nada (controla overlays diretamente)

**Por que primeiro:** é o sistema em desenvolvimento ativo (V/L/H, blending, z-order). Extrair agora evita que shadow baking e level design aconteçam com o código ainda acumulando em room.gd.

---

### 2a. HudController — prioridade 2, curto prazo
**Arquivo:** `controllers/hud_controller.gd`

**Extrai de `room.gd`:**
- Conexões de botões: `btn_numbers`, `btn_fullscreen`, `btn_viewport`, `btn_reset`, `btn_end_turn`
- Conexão do `chk_auto_end_turn`
- Atualização de labels: `lbl_ap`, `lbl_alert`
- Controle de `busted_dialog`, `enemy_turn_banner`
- Lógica de alert level display

**API pública (room.gd chama diretamente):**
```gdscript
func setup(hud_nodes: Dictionary) -> void   # passa os @onready nodes de HUD
func update_ap(current: int, max: int) -> void
func update_alert(pct: float) -> void
func show_enemy_banner() -> void
func hide_enemy_banner() -> void
func show_busted() -> void
```

**Emite para room.gd (room.gd conecta no setup):**
```gdscript
signal end_turn_requested()
signal reset_requested()
signal fullscreen_toggled()
signal viewport_toggled()
```

**Por que 2a:** mais isolado de gameplay. Risco zero de regressão em mecânicas.

---

### 2b. LightingController — prioridade 2, curto prazo
**Arquivo:** `controllers/lighting_controller.gd`

**Extrai de `room.gd`:**
- Instanciação e setup de: `LightRegistryClass`, `ShadowProjectorClass`, `ExposureSystemClass`, `LightAnchorClass`, `LightSourceClass`
- Toda a seção de "setup de iluminação" do `_ready()`
- Lógica de rebuild quando a cena muda
- Referências: `_light_registry`, `_shadow_projector`, `_exposure_system`, `_light_anchors[]`

**API pública:**
```gdscript
func setup(room_ref: Node2D) -> void
func rebuild() -> void
func rebuild_deferred() -> void
func get_exposure_system() -> ExposureSystem   # VisionController precisa disso
```

**Emite para room.gd:**
```gdscript
signal lighting_rebuilt()
```
`VisionController` conecta em `lighting_rebuilt` para fazer `queue_redraw` nos overlays. Esta é a única conexão módulo→módulo via signal permitida neste projeto.

**Por que 2b:** depende do VisionController estar extraído primeiro (o VisionController se registra no `lighting_rebuilt`). Extrair na mesma sessão ou na sessão seguinte.

---

### 3a. CameraController — prioridade 3, médio prazo
**Arquivo:** `controllers/camera_controller.gd`

**Extrai de `room.gd`:**
- Variáveis de drag: `_left_down`, `_drag_started`, `_drag_start_mouse`, `_drag_start_cam`
- Variáveis de pinch: `_touches`
- Constantes: `DRAG_THRESHOLD_SQ`, `ZOOM_MIN`, `ZOOM_MAX`, `ZOOM_STEP`, `CAMERA_MAX_BORDER_TILES`, `CAMERA_SOFT_ZONE_TILES`, `WORLD_TILE_PX`
- Constantes de visão: `VISION_TILE_RADIUS`, `FOW_REVEAL_RADIUS`
- Lógica de drag e zoom em `_unhandled_input()`
- Conexões dos botões de perspectiva: `btn_perspective_nw/ne/sw/se`
- Lógica do `btn_viewport`
- Câmera leash (limitação de posição baseada em FOW)

**API pública:**
```gdscript
func setup(camera: Camera2D, room_ref: Node2D) -> void
func handle_input(event: InputEvent) -> bool   # retorna true se consumiu o evento
func focus_on(world_pos: Vector2) -> void
func reset_zoom() -> void
```

**Emite:** nada

**Atenção:** `_unhandled_input()` de room.gd precisará ser dividido. A parte de câmera (drag, zoom, pinch) vai para `CameraController.handle_input()`. A parte de gameplay (V, L, H, end turn, etc.) fica em room.gd. Esta é a mudança mais delicada da extração de câmera.

---

### 3b. FowController — prioridade 3, médio prazo
**Arquivo:** `controllers/fow_controller.gd`

**Extrai de `room.gd`:**
- Lógica de reveal (usando `FOW_REVEAL_RADIUS`)
- Acesso e atualização do `fog_of_war` node
- Parâmetros do shader do `_fog_rect`
- Função de "set vision center" chamada quando agente se move

**API pública:**
```gdscript
func setup(fog_of_war: Node2D, fog_rect: ColorRect, room_ref: Node2D) -> void
func reveal_around(cell: Vector2i, radius: int) -> void
func is_revealed(cell: Vector2i) -> bool
func set_vision_center(world_pos: Vector2) -> void
func set_visible(value: bool) -> void   # chamado por VisionController
```

**Emite:** nada

---

### 4. GuardCoordinator — prioridade 4, alta sensibilidade
**Arquivo:** `controllers/guard_coordinator.gd`

**Extrai de `room.gd`:**
- Handlers de sinal: `_on_guard_whistle()`, `_on_guard_radio()`, `_on_guard_alarm()`
- Lógica de coordenação de busca (search tiles, broadcast de posição)
- Registro de guards no setup
- Callbacks de fim de turno dos guards

**`_guards[]` PERMANECE em room.gd** — GuardCoordinator lê via referência, não é dono.

**API pública:**
```gdscript
func setup(room_ref: Node2D) -> void
func register_guard(guard: GuardEnemy) -> void
func on_guard_turn_ended(guard: GuardEnemy) -> void
```

**Emite para room.gd:**
```gdscript
signal guard_spotted_player(guard: GuardEnemy)
signal alarm_raised()
signal all_guards_alerted()
```

**Por que por último:** maior risco de regressão. Guards são centrais para o gameplay. Extrair apenas após todos os outros módulos estarem estáveis e o gameplay funcionar identicamente.

---

## Contrato de comunicação (três regras)

| Direção | Mecanismo | Exemplo |
|---------|-----------|---------|
| módulo → room.gd | **signal** | `hud.end_turn_requested.connect(_on_end_turn)` |
| room.gd → módulo | **direct call** | `_vision_controller.toggle_dev()` |
| módulo → módulo | **NUNCA** (exceto via signal→room.gd) | — |

**Única exceção:** `LightingController` emite `lighting_rebuilt` e `VisionController` conecta diretamente. Permitido porque é uma dependência de dados sem feedback loop e sem lógica de coordenação.

---

## O que PERMANECE em room.gd

```gdscript
# Utilitários de grid — usados por todos os módulos
func _cell_to_screen(cell: Vector2i) -> Vector2
func is_cell_blocked(cell: Vector2i) -> bool
func get_room_size() -> Vector2i

# Estado compartilhado — source of truth
var _guards: Array                  # dono do array; GuardCoordinator lê por referência
var _shadow_tiles: Dictionary       # Vector2i → float multiplicador
var _blocked_cells: Dictionary
var _exit_cells: Array[Vector2i]
const VISUAL_GRID_OFFSET: Vector2

# Instâncias dos módulos
var _vision_controller: VisionController
var _lighting_controller: LightingController
var _hud_controller: HudController
var _camera_controller: CameraController
var _fow_controller: FowController
var _guard_coordinator: GuardCoordinator

# Orquestração de turno (lógica fina, sem detalhe de domínio)
func _on_player_turn_ended() -> void
func _on_enemy_turn_ended() -> void
func _on_guard_turn_ended(guard) -> void

# Input dispatcher (delega para módulos)
func _unhandled_input(event: InputEvent) -> void

# Setup e conexão de módulos
func _ready() -> void
```

**Estimativa de linhas:** ~380 linhas.

---

## Invariantes arquiteturais (nunca mudam)

1. **Toda coordenação entre guards passa por room.gd via signal** — regra existente, preservada no GuardCoordinator.
2. **`_guards[]` vive em room.gd** — módulos recebem a referência, não copiam o array.
3. **`_cell_to_screen()` não migra** — é utilitário compartilhado, permanece em room.gd.
4. **Módulos são `Node2D` filhos de Room** — podem ter `_process()`, `_draw()`, `_ready()` próprios. Adicionados via `add_child()` no `_ready()` de room.gd.
5. **Cada módulo tem um único `setup()` chamado em ordem no `_ready()` de room.gd**.
6. **Um módulo por PR, um PR por sessão de implementação**.

---

## Ordem de execução

| Sessão | Módulo | Risco | Pré-requisito |
|--------|--------|-------|---------------|
| A | VisionController | médio | nenhum |
| B | HudController | baixo | nenhum |
| C | LightingController | médio | sessão A concluída |
| D | CameraController | médio | nenhum, mas split de `_unhandled_input` requer atenção |
| E | FowController | baixo | nenhum |
| F | GuardCoordinator | alto | todas as outras sessões concluídas |

**Entre sessões:** smoke test completo de gameplay antes de avançar. Se algo quebrar, reverter e corrigir antes de continuar.

---

## Módulos futuros (placeholders — não implementar agora)

| Módulo | Milestone | Escopo |
|--------|-----------|--------|
| `LevelController` | M3 | Geração procedural, transição de andares, serialização de layout |
| `CombatController` | M2-10 | Cover system, confrontation flow, ballistics |
| `InputRouter` | qualquer | Centralizar todo o `_unhandled_input` numa camada única de dispatch |

Quando cada um desses for implementado, o padrão é idêntico: criar em `controllers/`, expor `setup()`, emitir signals para room.gd.

---

## Definition of Done

A refatoração está completa quando:

- [ ] `room.gd` tem ≤ 400 linhas
- [ ] Nenhum `_toggle_*()` em room.gd
- [ ] Nenhuma instanciação de overlay em room.gd
- [ ] Nenhuma lógica de câmera em room.gd
- [ ] Nenhuma lógica de HUD em room.gd
- [ ] Nenhuma lógica de rebuild de iluminação em room.gd
- [ ] `GuardCoordinator` processa todos os sinais de guard
- [ ] Gameplay funciona identicamente ao estado pré-refatoração
- [ ] DEV/LIGHT/HEAT vision funcionam via VisionController
- [ ] 0 erros de compilação, 0 warnings novos
- [ ] Cada módulo tem seu próprio arquivo em `controllers/`
