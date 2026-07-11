# INFILTRAITOR — Sessão E: Extração do FowController
## MODULARIZE-05

**Pré-requisito:** nenhum, mas executar após A, B, C, D.

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/fow_controller.gd`

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd`

## NÃO TOCAR
`vision_controller.gd` (o toggle de visibilidade do FOW node fica lá, não aqui).

---

## CONTEXTO

Há uma distinção importante que deve ser preservada:

- **VisionController** controla **se o FOW node é visível** (`fog_of_war.visible = not (dev_vision or light_vision or heat_vision)`). Essa lógica JÁ FOI movida para VisionController na Sessão A e não muda aqui.
- **FowController** controla **o que o FOW revela** — quais tiles foram explorados, o raio de reveal ao redor do agente, e os parâmetros do shader do `_fog_rect`.

---

## PASSO 0 — Identificar em room.gd

- Buscar `reveal`, `fow`, `fog` em room.gd para encontrar:
  - Função de reveal de tiles (chamada quando agente se move)
  - Uso de `FOW_REVEAL_RADIUS` e `VISION_TILE_RADIUS` no contexto de reveal
  - Acesso ao `_fog_rect` para setar parâmetros de shader (ex: `set_shader_parameter`)
  - Qualquer estrutura que rastreia tiles revelados (Dictionary ou Array)
- Verificar se existe `is_revealed(cell)` ou equivalente

---

## PASSO 1 — Criar `fow_controller.gd`

```gdscript
extends Node

## Gerencia quais tiles foram revelados pelo agente e os parâmetros do
## vision fog shader. NÃO controla visibilidade do node FOW — isso é
## responsabilidade do VisionController.

var _room: Node2D
var _fog_of_war: Node2D
var _fog_rect: ColorRect
var _revealed_cells: Dictionary = {}   ## Vector2i → true

func setup(room_ref: Node2D, fog_of_war_ref: Node2D, fog_rect_ref: ColorRect) -> void:
    _room = room_ref
    _fog_of_war = fog_of_war_ref
    _fog_rect = fog_rect_ref

func reveal_around(cell: Vector2i, radius: int) -> void:
    ## Marca tiles num raio como revelados e atualiza o visual do FOW.
    ## [MOVER LÓGICA DE room.gd]
    pass

func is_revealed(cell: Vector2i) -> bool:
    return _revealed_cells.has(cell)

func set_vision_center(world_pos: Vector2) -> void:
    ## Atualiza o parâmetro de shader que controla o círculo de visão
    ## ao redor do agente.
    ## [MOVER LÓGICA DE _fog_rect.set_shader_parameter(...) DE room.gd]
    pass
```

---

## PASSO 2 — Mover lógica de reveal e shader

Localizar em room.gd:
- O bloco que itera tiles em raio e marca como revelados
- As chamadas `_fog_rect.set_shader_parameter(...)` que atualizam o centro e raio do gradiente

Mover esses blocos para `reveal_around()` e `set_vision_center()`.

Referências a `FOW_REVEAL_RADIUS` e `VISION_TILE_RADIUS` continuam via `_room.FOW_REVEAL_RADIUS` etc. — as constantes ficam em room.gd.

---

## PASSO 3 — Registrar em room.gd

```gdscript
const FowControllerClass = preload("res://godot/scripts/controllers/fow_controller.gd")
var _fow_controller: Node

# No _ready():
_fow_controller = FowControllerClass.new()
_fow_controller.name = "FowController"
add_child(_fow_controller)
_fow_controller.setup(self, fog_of_war, _fog_rect)
```

Substituir chamadas diretas de reveal em room.gd:
```gdscript
# Antes: [bloco de reveal inline]
# Depois:
_fow_controller.reveal_around(agent_cell, FOW_REVEAL_RADIUS)
```

Substituir atualização de shader:
```gdscript
# Antes: _fog_rect.set_shader_parameter("center", ...)
# Depois:
_fow_controller.set_vision_center(agent_world_pos)
```

---

## ACCEPTANCE TESTS

- [ ] 0 erros de compilação
- [ ] Quando agente se move, tiles ao redor são revelados (FOW desaparece nessa área)
- [ ] Tiles revelados permanecem revelados após o agente se mover (persistência correta)
- [ ] O círculo de visão do shader segue o agente em tempo real
- [ ] V, L, H ainda alternam a visibilidade do FOW node (responsabilidade do VisionController, não deve regredir)
- [ ] room.gd reduziu ≥ 80 linhas adicionais
