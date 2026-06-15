# INFILTRAITOR — Sessão A: Extração do VisionController
## MODULARIZE-01 — room.gd → controllers/vision_controller.gd

**Data:** 2026-06-15
**Prioridade:** 1 (imediato — em desenvolvimento ativo)

---

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/vision_controller.gd` ← novo

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd` ← apenas para remover código movido e adicionar delegação

## ARQUIVOS QUE NÃO DEVEM SER TOCADOS
Todos os outros. Em especial: nenhum overlay individual (`.gd` em `overlays/`), nenhum sistema de iluminação (`systems/lighting/`), `guard_enemy.gd`, `tic_system.gd`, `room_layout_builder.gd`.

---

## CONTEXTO

`room.gd` tem 2124 linhas acumulando 8 domínios. Esta sessão extrai **apenas** o domínio de vision modes: os três toggles (DEV/LIGHT/HEAT), os apply functions correspondentes, o controle de FOW visibility, e a propriedade/instanciação de todos os overlays de debug e visualização.

A estratégia é **mover, não reescrever.** Cada bloco de código é copiado para o novo arquivo, a referência em `room.gd` é substituída por uma chamada de delegação, testado, e só então o original é removido de `room.gd`.

---

## PASSO 0 — Preparação: identificar os blocos em room.gd

Antes de criar qualquer arquivo, localizar e listar em comentário os seguintes itens em `room.gd`. Usar busca por palavra-chave:

**Variáveis de estado a mover:**
- Buscar `dev_vision`, `light_vision`, `heat_vision` — anotar o nome e tipo exato de cada `var`

**Preloads a mover** (os que pertencem a overlays de visualização, não a sistemas de iluminação):
- `TileOverlayClass` (se existir)
- `LightOverlayClass`
- `ShadowOverlayClass`
- `ExposureOverlayClass`
- `TileRiskOverlayClass`
- `HeightOverlayClass`
- `TemporalOverlayClass`
- `EliteExposureOverlayClass`
- Qualquer outro overlay preload que não seja `LightRegistryClass`, `ShadowProjectorClass`, `ExposureSystemClass`, `LightAnchorClass`, `LightSourceClass`, `ShadowResultClass`, `TileSemanticsClass` (esses ficam em room.gd por enquanto)

**Variáveis de instância de overlay a mover:**
- Buscar `_tile_overlay`, `_light_overlay`, `_shadow_overlay`, `_exposure_overlay`, `_tile_risk_overlay`, `_height_overlay`, `_temporal_overlay`, `_elite_exposure_overlay` — anotar nomes exatos

**Funções a mover:**
- Buscar `_toggle_dev`, `_toggle_light`, `_toggle_heat` — anotar assinatura completa
- Buscar `_apply_dev`, `_apply_light`, `_apply_heat`, `_apply_fow` — anotar assinatura completa
- Buscar `get_dev_vision_tiles` — se existir, anotar; se não existir, ignorar
- Identificar onde os overlays são instanciados no `_ready()` — bloco que contém `.new()` para cada overlay

**Referências no `_unhandled_input()`:**
- Localizar os handlers de KEY_V, KEY_L, KEY_H

**Referências após rebuild de iluminação:**
- Localizar onde `queue_redraw()` é chamado nos overlays após a iluminação ser reconstruída

Só avançar para o Passo 1 após ter clareza sobre todos esses itens.

---

## PASSO 1 — Criar a pasta e o arquivo base

Criar a pasta `godot/scripts/controllers/` se não existir.

Criar `godot/scripts/controllers/vision_controller.gd` com a estrutura base:

```gdscript
extends Node2D

## Gerencia os três modos de visualização (DEV, LIGHT, HEAT) e todos os overlays
## de debug e análise. É filho de room.gd na scene tree.
## Comunicação: room.gd chama métodos diretamente; este módulo não emite signals.

# ── Preloads ──────────────────────────────────────────────────────────────────
# [MOVER OS PRELOADS DE OVERLAY DE room.gd PARA CÁ — ver Passo 0]

# ── Estado de visão ───────────────────────────────────────────────────────────
var dev_vision: bool = false
var light_vision: bool = false
var heat_vision: bool = false

# ── Referências externas ──────────────────────────────────────────────────────
var _room: Node2D          ## referência ao room.gd — acesso somente leitura
var _fog_of_war: Node2D    ## node FogOfWarOverlay da cena

# ── Instâncias dos overlays ───────────────────────────────────────────────────
# [DECLARAR AS VARIÁVEIS DE INSTÂNCIA AQUI — ver Passo 0]

# ── API pública ───────────────────────────────────────────────────────────────

func setup(room_ref: Node2D, fog_of_war_ref: Node2D) -> void:
    _room = room_ref
    _fog_of_war = fog_of_war_ref
    _init_overlays()

func toggle_dev() -> void:
    dev_vision = not dev_vision
    _apply_dev_vision()
    _apply_fow_visibility()

func toggle_light() -> void:
    light_vision = not light_vision
    _apply_light_vision()
    _apply_fow_visibility()

func toggle_heat() -> void:
    heat_vision = not heat_vision
    _apply_heat_vision()
    _apply_fow_visibility()

func request_redraw() -> void:
    ## Chamado por room.gd após qualquer rebuild de iluminação.
    ## Força todos os overlays ativos a se redesenharem.
    if light_vision:
        _apply_light_vision()
    if heat_vision:
        _apply_heat_vision()

# ── Privado ───────────────────────────────────────────────────────────────────

func _init_overlays() -> void:
    ## Instancia os overlays, adiciona à scene tree com z-order correto,
    ## e faz o setup inicial de cada um.
    ## [MOVER O BLOCO DE INSTANCIAÇÃO DO _ready() DE room.gd PARA CÁ]
    pass

func _apply_dev_vision() -> void:
    ## [MOVER DE room.gd — função _apply_dev_vision() ou equivalente]
    pass

func _apply_light_vision() -> void:
    ## [MOVER DE room.gd — função _apply_light_vision() ou equivalente]
    pass

func _apply_heat_vision() -> void:
    ## [MOVER DE room.gd — função _apply_heat_vision() ou equivalente]
    pass

func _apply_fow_visibility() -> void:
    ## FOW some quando qualquer modo de visualização estiver ativo.
    if _fog_of_war == null:
        return
    _fog_of_war.visible = not (dev_vision or light_vision or heat_vision)
```

---

## PASSO 2 — Mover os preloads

Cortar os preloads de overlay do `room.gd` e colar no topo de `vision_controller.gd`, acima de `extends Node2D` (ou logo após, antes das variáveis — seguir o padrão de estilo do projeto).

Manter em `room.gd` apenas os preloads que pertencem a sistemas (não overlays):
- `LightRegistryClass`, `ShadowProjectorClass`, `ExposureSystemClass`
- `LightSourceClass`, `LightAnchorClass`, `ShadowResultClass`
- `TileSemanticsClass`
- `RoomLayoutBuilder`, `LevelGraphClass`, `GuardEnemyClass`, `GuardNoiseIndicatorClass`

---

## PASSO 3 — Mover declarações de variáveis de overlay

Cortar as declarações `var _exposure_overlay`, `var _light_overlay`, etc. de `room.gd` e colar na seção "Instâncias dos overlays" de `vision_controller.gd`.

---

## PASSO 4 — Mover `_init_overlays()`: instanciação e z-order

Localizar em `room.gd` o bloco no `_ready()` onde os overlays são instanciados (`.new()`), adicionados com `add_child()`, posicionados com `move_child()`, e configurados com `setup()` ou `set_visual_offset()`.

Mover esse bloco para `_init_overlays()` em `vision_controller.gd`.

**Atenção crítica — acesso ao `floor_layer`:**
O z-order dos overlays de Heat Vision usa `floor_layer.get_index()`. Como `floor_layer` é um `@onready` de `room.gd`, acessar via `_room.floor_layer` (o node é público por ser @onready).

**Atenção — `VISUAL_GRID_OFFSET`:**
As chamadas de setup dos overlays que recebem `visual_offset` devem passar `_room.VISUAL_GRID_OFFSET` (a constante é pública em room.gd).

**Atenção — sistemas de iluminação:**
Os overlays de HEAT e LIGHT precisam de referências ao `_exposure_system`, `_light_registry`, etc. Por enquanto, acessar via `_room._exposure_system`, `_room._light_registry`, etc. Esses prefixos `_room.` serão limpos quando os sistemas migrarem para `LightingController` na Sessão C.

Exemplo de padrão:
```gdscript
# Antes (em room.gd):
_exposure_overlay = ExposureOverlayClass.new()
_exposure_overlay.name = "ExposureOverlay"
add_child(_exposure_overlay)
move_child(_exposure_overlay, floor_layer.get_index() + 1)
_exposure_overlay.z_index = 0
_exposure_overlay.z_as_relative = true
_exposure_overlay.setup(_room_size, VISUAL_GRID_OFFSET, _exposure_system)

# Depois (em vision_controller.gd > _init_overlays()):
_exposure_overlay = ExposureOverlayClass.new()
_exposure_overlay.name = "ExposureOverlay"
_room.add_child(_exposure_overlay)
_room.move_child(_exposure_overlay, _room.floor_layer.get_index() + 1)
_exposure_overlay.z_index = 0
_exposure_overlay.z_as_relative = true
_exposure_overlay.setup(_room._room_size, _room.VISUAL_GRID_OFFSET, _room._exposure_system)
```

---

## PASSO 5 — Mover as funções `_apply_*` e `_toggle_*`

Mover os corpos completos de `_apply_dev_vision()`, `_apply_light_vision()`, `_apply_heat_vision()`, e `_apply_fow_visibility()` para `vision_controller.gd`.

Ajustar referências internas: qualquer variável que era `self.algo` em room.gd e que **não migrou** (ex: `_guards` para `get_dev_vision_tiles()`) passa a ser `_room.algo`.

As funções `_toggle_dev_vision()` etc. de room.gd podem ser **deletadas** — o VisionController já tem `toggle_dev()`, `toggle_light()`, `toggle_heat()` que fazem o mesmo.

Se existir `get_dev_vision_tiles()` em room.gd, mover para vision_controller.gd. Onde ela acessa `_guards`, usar `_room._guards`.

---

## PASSO 6 — Registrar VisionController em room.gd

Em `room.gd`:

**6a. Adicionar preload e variável:**
```gdscript
const VisionControllerClass = preload("res://godot/scripts/controllers/vision_controller.gd")
var _vision_controller: Node2D  ## instância do VisionController
```

**6b. No `_ready()`, após o setup dos sistemas de iluminação e antes do final do método:**
```gdscript
_vision_controller = VisionControllerClass.new()
_vision_controller.name = "VisionController"
add_child(_vision_controller)
_vision_controller.setup(self, fog_of_war)
```

**6c. No `_unhandled_input()`, substituir os handlers de V/L/H:**
```gdscript
# Antes:
elif event.keycode == KEY_V:
    _toggle_dev_vision()      # ou o nome que existia

# Depois:
elif event.keycode == KEY_V:
    _vision_controller.toggle_dev()
```
Fazer o mesmo para KEY_L e KEY_H.

**6d. Onde `queue_redraw()` é chamado nos overlays após rebuild de iluminação:**
```gdscript
# Antes: chamadas diretas nos overlays
_exposure_overlay.queue_redraw()
_light_overlay.queue_redraw()
# etc.

# Depois: uma chamada única:
_vision_controller.request_redraw()
```

---

## PASSO 7 — Limpeza final de room.gd

Após confirmar que o jogo funciona (ver acceptance tests abaixo):

- Deletar de room.gd: os preloads movidos, as declarações de variável de overlay movidas, o bloco de instanciação do `_ready()` que foi para `_init_overlays()`, e os corpos das funções `_apply_*` / `_toggle_*` movidas.
- Substituir qualquer chamada interna residual em room.gd que ainda referenciasse `dev_vision`, `light_vision`, `heat_vision` diretamente por `_vision_controller.dev_vision`, `_vision_controller.light_vision`, `_vision_controller.heat_vision`.

---

## ACCEPTANCE TESTS

Testar após cada passo antes de avançar. Após o Passo 7, todos devem passar:

**Compilação:**
- [ ] 0 erros de compilação
- [ ] 0 warnings novos

**Funcionalidade — V (DEV VISION):**
- [ ] Tecla V ativa o modo dev: guards mostram labels (id, state, cell, facing)
- [ ] Tecla V novamente desativa
- [ ] FOW some quando V está ativo
- [ ] V pode ser combinado com L e H sem erro

**Funcionalidade — L (LIGHT VISION):**
- [ ] Tecla L ativa o modo light: overlays de iluminação, sombra, altura visíveis
- [ ] Tecla L novamente desativa
- [ ] FOW some quando L está ativo

**Funcionalidade — H (HEAT VISION):**
- [ ] Tecla H ativa o modo heat: heatmap de exposure visível sobre o chão
- [ ] O heatmap fica **abaixo** de paredes, caixas, guards e agente
- [ ] Tecla H novamente desativa
- [ ] FOW some quando H está ativo

**Funcionalidade — combinações:**
- [ ] V + H simultaneamente: cones visíveis, heatmap visível no chão entre os cones
- [ ] L + H simultaneamente: ambos os overlays visíveis
- [ ] V + L + H: todos funcionando sem conflito

**Sanity checks de gameplay:**
- [ ] Movimento do agente funciona normalmente com todos os modos off
- [ ] Guards patrulham e detectam normalmente
- [ ] Turn flow (player/enemy) funciona

**Tamanho de room.gd:**
- [ ] Contar linhas de room.gd antes e depois — deve ter reduzido ≥ 250 linhas

---

## NOTAS PARA O OPERADOR

1. **Mover, não reescrever.** Se uma função estava funcionando em room.gd, copiar o corpo exatamente como está, ajustar apenas as referências que precisam de `_room.`.

2. **Testar incremental.** Não esperar o Passo 7 para testar. Após cada passo, rodar o jogo e verificar que V/L/H ainda funcionam.

3. **Prefixo `_room.` é temporário.** Todas as referências `_room._exposure_system`, `_room._room_size` etc. são provisórias e serão limpas nas sessões seguintes quando esses sistemas migrarem para seus próprios controllers.

4. **Não alterar os overlays internamente.** Os arquivos em `overlays/` não são tocados nesta sessão. Apenas mudamos *quem instancia e quem controla* os overlays, não *como* eles funcionam.

5. **Se uma função não existir com o nome esperado,** verificar o nome real via busca no arquivo antes de assumir que não existe. Os nomes no prompt são os mais prováveis mas podem variar ligeiramente.
