# INFILTRAITOR — Sessão F: Extração do GuardCoordinator
## MODULARIZE-06

**Pré-requisito:** TODAS as sessões A–E concluídas e validadas com gameplay completo funcionando.

## ARQUIVOS A CRIAR
- `godot/scripts/controllers/guard_coordinator.gd`

## ARQUIVOS A MODIFICAR
- `godot/scripts/world/room.gd`

## NÃO TOCAR
`guard_enemy.gd`, `tic_system.gd`, `enemy_phase_controller.gd`, overlays, sistemas de iluminação.

---

## CONTEXTO

GuardCoordinator assume o roteamento de sinais entre guards: whistle, radio, alarm, e coordenação de busca. É a sessão de maior risco — qualquer regressão aqui afeta o gameplay central.

**Regra que não muda:** `_guards[]` permanece em room.gd como source of truth. GuardCoordinator opera sobre ele via `_room._guards`.

**Estratégia:** mover UMA função por vez, testar, avançar. Não mover tudo de uma vez.

---

## PASSO 0 — Mapear completamente antes de tocar qualquer código

Criar uma lista comentada de TODAS as funções em room.gd que:
1. São callbacks de signal dos guards (buscar `_on_guard_`, `guard.`)
2. Envolvem coordenação entre guards (buscar `_guards`, `whistle`, `radio`, `alarm`, `search`)
3. São chamadas no `_on_enemy_turn_ended()` relacionadas a guards

Para cada função: nome, assinatura, de onde é conectada, o que ela faz. Só avançar para o Passo 1 com a lista completa.

---

## PASSO 1 — Criar `guard_coordinator.gd`

```gdscript
extends Node

## Roteia sinais de coordenação entre guards via room.gd.
## NUNCA se comunica diretamente com outro controller.
## _guards[] pertence a room.gd; este módulo acessa via _room._guards.

signal guard_spotted_player(guard: Object)
signal alarm_raised()
signal all_guards_alerted()

var _room: Node2D

func setup(room_ref: Node2D) -> void:
    _room = room_ref

func register_guard(guard: Object) -> void:
    ## Conecta os sinais do guard a este coordinator.
    ## Chamado por room.gd quando um guard é criado.
    ## [MOVER LÓGICA DE CONEXÃO DE SINAIS DE room.gd]
    pass

func on_guard_turn_ended(guard: Object) -> void:
    ## Chamado por room.gd ao final do turno de cada guard.
    ## [MOVER LÓGICA DE room.gd SE EXISTIR]
    pass

## Handlers privados — um por signal de guard:

func _on_guard_whistle(guard: Object, _data) -> void:
    ## [MOVER DE room.gd]
    pass

func _on_guard_radio(guard: Object, _data) -> void:
    ## [MOVER DE room.gd]
    pass

func _on_guard_alarm(guard: Object) -> void:
    ## [MOVER DE room.gd]
    alarm_raised.emit()
    pass
```

---

## PASSO 2 — Mover um handler de cada vez

**Ordem recomendada (do mais simples ao mais complexo):**

1. `_on_guard_whistle()` — mover, testar, confirmar que whistle ainda funciona
2. `_on_guard_radio()` — mover, testar
3. `_on_guard_alarm()` — mover, testar (emite `alarm_raised` para room.gd)
4. Lógica de coordenação de search (se existir função separada)
5. `register_guard()` — mover as conexões de signal que room.gd faz ao criar guards

Para cada função movida:
- Substituir referências a `_guards` por `_room._guards`
- Substituir chamadas diretas a outros systems (ex: `_exposure_system`) por `_room._lighting_controller.get_exposure_system()` ou `_room.outro_sistema`
- Testar gameplay antes de avançar para a próxima função

---

## PASSO 3 — Registrar em room.gd e conectar signals

```gdscript
const GuardCoordinatorClass = preload("res://godot/scripts/controllers/guard_coordinator.gd")
var _guard_coordinator: Node

# No _ready(), após setup dos guards:
_guard_coordinator = GuardCoordinatorClass.new()
_guard_coordinator.name = "GuardCoordinator"
add_child(_guard_coordinator)
_guard_coordinator.setup(self)

# Conectar signals do GuardCoordinator a handlers em room.gd:
_guard_coordinator.alarm_raised.connect(_on_alarm_raised)
_guard_coordinator.guard_spotted_player.connect(_on_guard_spotted_player)
_guard_coordinator.all_guards_alerted.connect(_on_all_guards_alerted)
```

Onde guards são criados/registrados em room.gd, adicionar:
```gdscript
_guard_coordinator.register_guard(guard)
```

---

## PASSO 4 — Smoke test de gameplay completo

Antes de considerar a sessão concluída, executar:

1. Completar uma missão normalmente (chegar à saída sem ser detectado)
2. Ser detectado por um guard — verificar que alarm/chase funciona
3. Deixar guard alertar outros (whistle/radio) — verificar coordenação
4. Verificar que ALERTA % no HUD atualiza corretamente
5. Verificar que `busted_dialog` aparece ao ser capturado

---

## ACCEPTANCE TESTS

- [ ] 0 erros de compilação
- [ ] Guards patrulham normalmente
- [ ] Guard detecta agente → entra em CHASE
- [ ] Guard em CHASE → whistle → outros guards recebem alerta
- [ ] Guard em ALERT → alarm → ALERTA % sobe no HUD
- [ ] ALERTA % reflete corretamente o estado de todos os guards
- [ ] `busted_dialog` aparece ao ser capturado
- [ ] Turn flow funciona: player → enemy → player
- [ ] `enemy_phase_controller` processa turnos de guards normalmente
- [ ] room.gd chegou a ≤ 400 linhas (meta da refatoração completa)

---

## VERIFICAÇÃO FINAL DA REFATORAÇÃO

Após a Sessão F, confirmar o Definition of Done do plano:

- [ ] `room.gd` ≤ 400 linhas
- [ ] Nenhum `_toggle_*()` em room.gd
- [ ] Nenhuma instanciação de overlay em room.gd
- [ ] Nenhuma lógica de câmera em room.gd
- [ ] Nenhuma lógica de HUD em room.gd
- [ ] `godot/scripts/controllers/` contém os 6 arquivos
- [ ] Gameplay funciona identicamente ao estado pré-refatoração
