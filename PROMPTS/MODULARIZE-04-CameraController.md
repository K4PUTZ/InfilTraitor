# INFILTRAITOR — Sessão D: Extração do CameraController
## MODULARIZE-04

**Pré-requisito:** nenhum (independente de A, B, C — mas executar depois deles)

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/camera_controller.gd`

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd`

## NÃO TOCAR
Tudo o mais.

---

## CONTEXTO

CameraController assume drag, zoom, pinch-zoom e perspectiva. A mudança mais delicada é o split do `_unhandled_input()`: a lógica de câmera sai de room.gd e vai para `camera_controller.handle_input(event) -> bool`. room.gd chama `handle_input` primeiro e só processa outros inputs se retornar `false`.

As constantes de câmera (ZOOM_MIN, ZOOM_MAX etc.) migram para o controller. `FOW_REVEAL_RADIUS` e `VISION_TILE_RADIUS` **ficam em room.gd** pois são usadas por outros sistemas (FowController e VisionController).

---

## PASSO 0 — Identificar em room.gd

- Variáveis: `_left_down`, `_drag_started`, `_drag_start_mouse`, `_drag_start_cam`, `_touches`
- Constantes: `DRAG_THRESHOLD_SQ`, `ZOOM_MIN`, `ZOOM_MAX`, `ZOOM_STEP`, `CAMERA_MAX_BORDER_TILES`, `CAMERA_SOFT_ZONE_TILES`, `WORLD_TILE_PX`
- Bloco de drag/zoom em `_unhandled_input()` — identificar o início e fim exatos do bloco de câmera vs. o bloco de gameplay (V, L, H, etc.)
- Conexões dos botões de perspectiva: `btn_perspective_nw`, `btn_perspective_ne`, `btn_perspective_sw`, `btn_perspective_se`
- Conexão do `btn_viewport` (se controlar câmera/zoom)
- Funções auxiliares de câmera: `_update_camera_position()`, `_clamp_camera()`, `_apply_zoom()` ou equivalentes — anotar nomes exatos

---

## PASSO 1 — Criar `camera_controller.gd`

```gdscript
extends Node

## Gerencia câmera: drag, zoom, pinch-zoom, leash, perspectiva.
## Expõe handle_input() para consumir eventos antes de room.gd processar gameplay input.

const DRAG_THRESHOLD_SQ  := 64.0
const ZOOM_MIN           := 0.20
const ZOOM_MAX           := 1.20
const ZOOM_STEP          := 0.06
const CAMERA_MAX_BORDER_TILES  := 4
const CAMERA_SOFT_ZONE_TILES   := 2
const WORLD_TILE_PX      := 128.0

var _camera: Camera2D
var _room: Node2D

var _left_down: bool = false
var _drag_started: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}

func setup(camera_ref: Camera2D, room_ref: Node2D) -> void:
    _camera = camera_ref
    _room = room_ref
    _connect_perspective_buttons()

func handle_input(event: InputEvent) -> bool:
    ## Processa eventos de câmera. Retorna true se o evento foi consumido.
    ## room.gd chama isso antes de processar qualquer outro input.
    ## [MOVER O BLOCO DE CÂMERA DO _unhandled_input() DE room.gd PARA CÁ]
    return false

func focus_on(world_pos: Vector2) -> void:
    if _camera: _camera.position = world_pos

func _connect_perspective_buttons() -> void:
    ## [MOVER AS CONEXÕES DOS BOTÕES DE PERSPECTIVA DE room.gd]
    pass
```

---

## PASSO 2 — Split do `_unhandled_input()`

Este é o passo mais delicado. Em room.gd, o `_unhandled_input()` tem dois blocos misturados:

**Bloco A — câmera** (vai para `camera_controller.handle_input()`):
- Mouse button left: iniciar drag
- Mouse motion: processar drag
- Mouse button right (se usado para câmera)
- Scroll wheel: zoom
- Touch input: pinch-zoom (`_touches`)

**Bloco B — gameplay** (fica em room.gd):
- KEY_V, KEY_L, KEY_H: vision modes
- KEY_SPACE ou KEY_RETURN: end turn
- D, números, outros shortcuts

Separar os dois blocos. Em room.gd, o novo `_unhandled_input()` fica:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # Câmera tem prioridade
    if _camera_controller.handle_input(event):
        return
    # Gameplay inputs
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_V:
            _vision_controller.toggle_dev()
        elif event.keycode == KEY_L:
            _vision_controller.toggle_light()
        elif event.keycode == KEY_H:
            _vision_controller.toggle_heat()
        # ... demais inputs de gameplay
```

---

## PASSO 3 — Mover constantes e variáveis de estado

Mover de room.gd: `DRAG_THRESHOLD_SQ`, `ZOOM_MIN/MAX/STEP`, `CAMERA_MAX_BORDER_TILES`, `CAMERA_SOFT_ZONE_TILES`, `WORLD_TILE_PX`, `_left_down`, `_drag_started`, `_drag_start_mouse`, `_drag_start_cam`, `_touches`.

**Não mover:** `FOW_REVEAL_RADIUS`, `VISION_TILE_RADIUS` — ficam em room.gd como constantes compartilhadas.

---

## PASSO 4 — Registrar em room.gd

```gdscript
const CameraControllerClass = preload("res://godot/scripts/controllers/camera_controller.gd")
var _camera_controller: Node

# No _ready():
_camera_controller = CameraControllerClass.new()
_camera_controller.name = "CameraController"
add_child(_camera_controller)
_camera_controller.setup(camera, self)
```

---

## ACCEPTANCE TESTS

- [ ] 0 erros de compilação
- [ ] Drag com mouse move a câmera normalmente
- [ ] Scroll wheel faz zoom in/out dentro dos limites ZOOM_MIN/MAX
- [ ] Pinch-zoom funciona em touch (se testável)
- [ ] Botões de perspectiva (NW/NE/SW/SE) reposicionam a câmera
- [ ] Teclas V, L, H ainda funcionam (não foram engolidas pelo handle_input)
- [ ] Turn flow e movimento do agente não foram afetados
- [ ] room.gd reduziu ≥ 150 linhas adicionais
