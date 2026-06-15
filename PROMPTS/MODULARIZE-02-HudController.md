# INFILTRAITOR — Sessão B: Extração do HudController
## MODULARIZE-02

**Pré-requisito:** nenhum (independente da Sessão A)

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/hud_controller.gd`

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd`

## NÃO TOCAR
Tudo o mais, especialmente `guard_enemy.gd`, overlays, sistemas de iluminação.

---

## CONTEXTO

HudController assume toda a fiação de UI: conexões de botões, atualização de labels, controle de banners. Risco de regressão zero — é pura UI sem gameplay logic.

Os nodes `@onready` (btn_end_turn, lbl_ap, etc.) **permanecem em room.gd** como `@onready`. HudController recebe referências a eles no `setup()`.

---

## PASSO 0 — Identificar em room.gd

Localizar e anotar:
- Todas as conexões de `.connect()` ou `pressed.connect()` para: `btn_numbers`, `btn_fullscreen`, `btn_viewport`, `btn_reset`, `btn_end_turn`, `chk_auto_end_turn`
- Funções callback desses botões: `_on_btn_end_turn_pressed()`, `_on_btn_reset_pressed()`, etc. (nomes exatos podem variar)
- Onde `lbl_ap.text` é atualizado (provavelmente em `_update_ap_label()` ou diretamente)
- Onde `lbl_alert.text` é atualizado
- Onde `busted_dialog.visible` é controlado
- Onde `enemy_turn_banner.visible` é controlado

---

## PASSO 1 — Criar `hud_controller.gd`

```gdscript
extends Node

## Gerencia toda a fiação de UI: botões, labels, banners.
## room.gd chama os métodos de update diretamente.
## Este módulo emite signals para ações do usuário.

signal end_turn_requested()
signal reset_requested()
signal fullscreen_toggled(enabled: bool)
signal viewport_toggled()
signal numbers_toggled(enabled: bool)

var _btn_end_turn: Button
var _btn_reset: Button
var _btn_fullscreen: Button
var _btn_viewport: Button
var _btn_numbers: Button
var _chk_auto_end_turn: CheckBox
var _lbl_ap: Label
var _lbl_alert: Label
var _busted_dialog: Control
var _enemy_turn_banner: Control

func setup(refs: Dictionary) -> void:
    ## refs contém os @onready nodes de room.gd passados por nome.
    ## Exemplo: setup({"btn_end_turn": btn_end_turn, "lbl_ap": lbl_ap, ...})
    _btn_end_turn     = refs.get("btn_end_turn")
    _btn_reset        = refs.get("btn_reset")
    _btn_fullscreen   = refs.get("btn_fullscreen")
    _btn_viewport     = refs.get("btn_viewport")
    _btn_numbers      = refs.get("btn_numbers")
    _chk_auto_end_turn = refs.get("chk_auto_end_turn")
    _lbl_ap           = refs.get("lbl_ap")
    _lbl_alert        = refs.get("lbl_alert")
    _busted_dialog    = refs.get("busted_dialog")
    _enemy_turn_banner = refs.get("enemy_turn_banner")
    _connect_buttons()

func update_ap(current: int, max_ap: int) -> void:
    if _lbl_ap: _lbl_ap.text = "AP %d/%d" % [current, max_ap]

func update_alert(pct: float) -> void:
    if _lbl_alert: _lbl_alert.text = "ALERTA %d%%" % [int(pct * 100)]

func show_enemy_banner() -> void:
    if _enemy_turn_banner: _enemy_turn_banner.visible = true

func hide_enemy_banner() -> void:
    if _enemy_turn_banner: _enemy_turn_banner.visible = false

func show_busted() -> void:
    if _busted_dialog: _busted_dialog.visible = true

func set_end_turn_enabled(value: bool) -> void:
    if _btn_end_turn: _btn_end_turn.disabled = not value

func _connect_buttons() -> void:
    ## [MOVER AS CONEXÕES DE BOTÃO DE room.gd PARA CÁ]
    ## Substituir chamadas diretas por emissão de signal.
    ## Exemplo:
    # if _btn_end_turn:
    #     _btn_end_turn.pressed.connect(func(): end_turn_requested.emit())
    pass
```

---

## PASSO 2 — Mover conexões e callbacks

Localizar em room.gd o bloco onde os botões são conectados (provavelmente no `_ready()`).

Mover as conexões para `_connect_buttons()`. Substituir a chamada direta à função de room.gd por emissão de signal:

```gdscript
# Antes (em room.gd):
btn_end_turn.pressed.connect(_on_end_turn_pressed)

# Depois (em hud_controller.gd > _connect_buttons()):
if _btn_end_turn:
    _btn_end_turn.pressed.connect(func(): end_turn_requested.emit())
```

As funções callback como `_on_btn_reset_pressed()`, `_on_btn_fullscreen_pressed()` etc. podem ser deletadas de room.gd — a lógica que elas continham vai para room.gd como handlers dos signals emitidos pelo HudController.

---

## PASSO 3 — Mover lógica de update de labels

Localizar onde room.gd atualiza `lbl_ap.text` e `lbl_alert.text`. Substituir por chamadas ao HudController:

```gdscript
# Antes: lbl_ap.text = "AP %d/%d" % [current_ap, max_ap]
# Depois: _hud_controller.update_ap(current_ap, max_ap)
```

---

## PASSO 4 — Registrar em room.gd

```gdscript
const HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
var _hud_controller: Node

# No _ready():
_hud_controller = HudControllerClass.new()
_hud_controller.name = "HudController"
add_child(_hud_controller)
_hud_controller.setup({
    "btn_end_turn": btn_end_turn,
    "btn_reset": btn_reset,
    "btn_fullscreen": btn_fullscreen,
    "btn_viewport": btn_viewport,
    "btn_numbers": btn_numbers,
    "chk_auto_end_turn": chk_auto_end_turn,
    "lbl_ap": lbl_ap,
    "lbl_alert": lbl_alert,
    "busted_dialog": busted_dialog,
    "enemy_turn_banner": enemy_turn_banner,
})

# Conectar signals do HudController às funções de room.gd:
_hud_controller.end_turn_requested.connect(_on_end_turn_requested)
_hud_controller.reset_requested.connect(_on_reset_requested)
_hud_controller.fullscreen_toggled.connect(_on_fullscreen_toggled)
# etc.
```

As funções `_on_end_turn_requested()`, `_on_reset_requested()` etc. em room.gd são versões limpas das callbacks antigas — sem o código de UI (que foi para o HudController), apenas com a lógica de gameplay.

---

## ACCEPTANCE TESTS

- [ ] 0 erros de compilação
- [ ] Botão END TURN encerra o turno do jogador normalmente
- [ ] Botão RESET reinicia a cena normalmente
- [ ] `lbl_ap` atualiza após cada movimento do agente
- [ ] `lbl_alert` atualiza quando a percepção dos guards muda
- [ ] `enemy_turn_banner` aparece durante o turno inimigo e some depois
- [ ] `busted_dialog` aparece quando o agente é detectado
- [ ] Checkbox `auto_end_turn` funciona
- [ ] room.gd reduziu ≥ 100 linhas
