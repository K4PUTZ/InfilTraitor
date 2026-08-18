# Enemy White — Pronto para Teste

**Status**: ✅ Implementação completa (2026-08-18)

## O que foi feito

1. **Modelo base** (`p1_agent_model.py`):
   - Paleta `enemy_white`: blazer branco (test_white) + calça PRETA
   - Geometria facial estilizada (apenas para enemy_white):
     * Olhos: dois discos pequenos (0.018 × 0.012 m)
     * Nariz: pequeno prism projetando 0.020 m
     * Cabelo: disc no topo + prism traseiro/lateral (marrom escuro)
     * Barba: disc no queixo + prisms laterais
   - Sem chapéu (bare-headed como enemy padrão)

2. **Bake completo**:
   - `agent_frames_enemy_white/standing`: 104×214 px (N), registro 0.00%
   - `agent_frames_enemy_white/crouch`: 105×127 px (N), registro 0.00%
   - `agent_frames_enemy_white/prone`: 184×133 px (N)
   - `agent_head_enemy_white/standing`: 24 yaws × 2 maps (color + normal)
   - `agent_head_enemy_white/crouch`: 24 yaws × 2 maps
   - Verificação composite vs whole: 0.01% max silhouette mismatch ✅

3. **Registro no sistema** (`agent_sprite.gd`):
   - `LAYERS_BY_FAMILY`: `"_enemy_white": ["head"]` adicionado
   - Sistema automaticamente reconhece a família via `frame_family`

4. **Evidência visual**:
   - Filmstrip: `Screenshots/p3_head_sweep/head_sweep_blind.gif`
   - 240 frames mostrando cabeça girando (movimento exponencial dos guardas)

## Como testar no mapa

### Opção 1: Via variável de ambiente (recomendado para teste)

```bash
INFILTRAITOR_ENEMY_FAMILY=_enemy_white /Applications/Godot.app/Contents/MacOS/Godot --path .
```

Isso força TODOS os guardas no mapa a usar a paleta enemy_white.

### Opção 2: Verificação que o sistema funciona

```bash
# 1. Verificar que frames existem
ls ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_enemy_white/standing/

# 2. Verificar que heads existem
ls ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_head_enemy_white/standing/ | wc -l
# Deve retornar 97 (24 frames × 4 + layer.json)

# 3. Testar carregamento
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script <(cat << 'GDSCRIPT'
extends SceneTree
func _init():
    var path = "res://ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_enemy_white/standing/frame_N_color.png"
    print("Loading: " + path)
    var img = load(path)
    if img:
        print("✓ Loaded successfully, size: " + str(img.get_size()))
    else:
        print("✗ Failed to load")
    quit()
GDSCRIPT
)
```

### Opção 3: Editar guard_enemy.gd temporariamente

Linha ~1112 em `godot/scripts/agents/guard_enemy.gd`:

```gdscript
# Mudar de:
s.frame_family = "_enemy"

# Para:
s.frame_family = "_enemy_white"
```

Isso torna enemy_white o padrão permanente (até reverter a mudança).

## Diferenças Visuais Esperadas

Comparado ao enemy padrão (olive drab):

| Aspecto | Enemy (padrão) | Enemy White |
|---------|----------------|-------------|
| Blazer | Verde-oliva escuro (0.095) | Branco (0.92) |
| Calça | Preta (0.020) | Preta (0.020) ← IGUAL |
| Camisa | Drab (0.190) | Drab (0.190) |
| Rosto | Pele lisa | **Olhos + nariz + cabelo + barba** |
| Chapéu | Não | Não |
| Silhueta | 8961 px opaque | ~8961 px (mesmo mesh) |

A grande diferença é o **blazer branco de alto contraste** + **features faciais visíveis**, tornando frente/trás da cabeça distinguíveis sem chapéu.

## Commits

- `8de447f6` — [ACTOR-D64] Modelo + paleta + bake + filmstrip
- `3ae516da` — [ACTOR-D65] Registro no sistema de renderização

## Próximos Passos (se necessário)

Se enemy_white deve ser uma facção separada (não apenas teste):
1. Adicionar à lógica de spawn em `room.gd` (campo `faction` no JSON do mapa)
2. Criar mapas com inimigos enemy_white específicos
3. Balancear comportamento/stats se for diferente

Para teste visual rápido: rode PLAYGROUND com o env var e observe os guardas patrulhando.
