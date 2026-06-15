# INFILTRAITOR — Sessão C: Extração do LightingController
## MODULARIZE-03

**Pré-requisito:** MODULARIZE-01 (VisionController) concluído e validado.

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/lighting_controller.gd`

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd`
- `godot/scripts/controllers/vision_controller.gd` (atualizar referências provisórias `_room._exposure_system`)

## NÃO TOCAR
Todos os sistemas individuais em `systems/lighting/`, overlays, guards.

---

## CONTEXTO

LightingController assume a criação e rebuild dos três sistemas de iluminação: `LightRegistry`, `ShadowProjector`, `ExposureSystem`. Emite `lighting_rebuilt` quando o estado de iluminação muda — VisionController conecta a esse signal para redesenhar os overlays.

Após esta sessão, as referências provisórias `_room._exposure_system` que estão em `vision_controller.gd` são substituídas pelo padrão correto.

---

## PASSO 0 — Identificar em room.gd

- Preloads: `LightRegistryClass`, `ShadowProjectorClass`, `ExposureSystemClass`, `LightSourceClass`, `LightAnchorClass`, `ShadowResultClass`
- Variáveis: `_light_registry`, `_shadow_projector`, `_exposure_system`, `_light_anchors` (ou similar)
- Bloco de setup no `_ready()` que instancia e configura esses sistemas
- Função de rebuild (buscar `rebuild`, `_rebuild_lighting`, `_update_exposure` ou similar)
- Qualquer lugar onde `_exposure_system`, `_light_registry`, `_shadow_projector` são usados fora do bloco de setup

---

## PASSO 1 — Criar `lighting_controller.gd`

```gdscript
extends Node

## Gerencia o pipeline de iluminação: LightRegistry, ShadowProjector, ExposureSystem.
## Emite lighting_rebuilt após qualquer rebuild para que VisionController atualize os overlays.

signal lighting_rebuilt()

# Preloads — mover de room.gd
const LightRegistryClass   = preload("res://godot/scripts/systems/lighting/light_registry.gd")
const ShadowProjectorClass = preload("res://godot/scripts/systems/lighting/shadow_projector.gd")
const ExposureSystemClass  = preload("res://godot/scripts/systems/lighting/exposure_system.gd")
const LightSourceClass     = preload("res://godot/scripts/systems/lighting/light_source.gd")
const LightAnchorClass     = preload("res://godot/scripts/systems/lighting/light_anchor.gd")
const ShadowResultClass    = preload("res://godot/scripts/systems/lighting/shadow_result.gd")

var _room: Node2D
var _light_registry          ## instância de LightRegistry
var _shadow_projector        ## instância de ShadowProjector
var _exposure_system         ## instância de ExposureSystem

func setup(room_ref: Node2D) -> void:
    _room = room_ref
    _init_systems()

func get_exposure_system():
    return _exposure_system

func get_light_registry():
    return _light_registry

func rebuild() -> void:
    ## [MOVER A LÓGICA DE REBUILD DE room.gd]
    ## Após recalcular, emitir o signal:
    lighting_rebuilt.emit()

func rebuild_deferred() -> void:
    call_deferred("rebuild")

func _init_systems() -> void:
    ## [MOVER O BLOCO DE INSTANCIAÇÃO DO _ready() DE room.gd]
    pass
```

---

## PASSO 2 — Mover preloads e instanciação

Mover os preloads listados no Passo 0 de room.gd para lighting_controller.gd.

Mover o bloco de instanciação de `_ready()` para `_init_systems()`. Referências ao estado compartilhado de room.gd (ex: `_room_size`, `_blocked_cells`) ficam como `_room._room_size` etc.

---

## PASSO 3 — Registrar em room.gd e conectar ao VisionController

```gdscript
const LightingControllerClass = preload("res://godot/scripts/controllers/lighting_controller.gd")
var _lighting_controller: Node

# No _ready(), ANTES do setup do VisionController:
_lighting_controller = LightingControllerClass.new()
_lighting_controller.name = "LightingController"
add_child(_lighting_controller)
_lighting_controller.setup(self)

# Conectar ao VisionController (signal lighting_rebuilt → request_redraw):
_lighting_controller.lighting_rebuilt.connect(_vision_controller.request_redraw)
```

Substituir todas as chamadas a rebuild de iluminação em room.gd por:
```gdscript
_lighting_controller.rebuild()
# ou
_lighting_controller.rebuild_deferred()
```

---

## PASSO 4 — Atualizar VisionController: remover referências provisórias

Em `vision_controller.gd`, substituir todas as ocorrências de `_room._exposure_system` por `_room._lighting_controller.get_exposure_system()`.

Substituir `_room._light_registry` por `_room._lighting_controller.get_light_registry()`.

**Importante:** estas referências passam agora por room.gd como mediador (vision_controller acessa `_room._lighting_controller`), o que é aceitável pois é uma propriedade pública do coordenador.

---

## ACCEPTANCE TESTS

- [ ] 0 erros de compilação
- [ ] Ao iniciar a cena, iluminação inicializa normalmente
- [ ] H (HEAT VISION) mostra o heatmap correto baseado nas fontes de luz
- [ ] L (LIGHT VISION) mostra os overlays de luz e sombra normalmente
- [ ] Se existir trigger de rebuild (mudança de layout), lighting reconstrói e overlays atualizam
- [ ] room.gd reduziu ≥ 200 linhas adicionais
