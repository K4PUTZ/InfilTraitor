# Sessão 2026-08-19 — Alpha Enemy Hair

**Objetivo:** Corrigir renderização dos detalhes faciais do enemy_white (cabelo, barba, olhos, nariz).

**Status:** ✅ COMPLETO — Enemy renderiza com todas as features faciais visíveis.

---

## 1. Problema Inicial

**Sintomas reportados pelo Director:**
- "O cabelo por todos os ângulos fica atrás da cabeça"
- "O rosto também não dá pra ver nada"

**Contexto:**
- Enemy_white variant: blazer branco (0.92 albedo), calça preta, detalhes faciais estilizados
- Iluminação já corrigida (commit 6a540854 — LIGHT_RESPONSE_OVERRIDE ambient 0.75)
- Blazer renderizando corretamente, mas facial features completamente ausentes

---

## 2. Diagnóstico

### Análise de Pixel (PIL)

Frame head yaw_000_color.png **ANTES** do fix:
```
Luma mínimo: 101.8  (esperado: ~17 para cabelo/barba, ~243 para olhos)
Cabelo/barba (luma 0-29): 0 pixels   ❌
Olhos (luma 220+): 0 pixels          ❌
```

**Conclusão:** Detalhes faciais não estavam sendo baked nos PNGs.

### Investigação da Pipeline

1. **p1_agent_model.py** — ✅ Geometria facial presente (linhas 487-527)
   - Eyes: 2 discos em (±0.035, 0.085, Z), material `eye` RGB(0.95, 0.95, 0.96)
   - Nose: prism projetando 0.020 m, material `skin`
   - Hair top: disco em Z = HEAD_H - g, raio 0.172, material `hair` RGB(0.08, 0.06, 0.05)
   - Hair back: prism Y=-0.075, Z 60%-98% altura, material `hair`
   - Beard: disco chin + 2 prisms laterais, material `beard` RGB(0.10, 0.08, 0.07)

2. **agent_base_enemy_white.blend** — ✅ Materiais corretos
   - Blend carrega com `diffuse_color` correto MAS `base_color` = (0.8, 0.8, 0.8)
   - `materialise_for_export()` sincroniza base_color antes do export GLB

3. **agent_posed_*_enemy_white_head.glb** — ✅ Materiais sincronizados
   - Verificado via Blender: base_color correto para hair/beard/eye/skin
   - 9 meshes presentes: seg_head + 8 faciais

4. **p3_posture_export.py** — ❌ **CAUSA RAIZ**
   ```python
   HEAD_MESHES = ("seg_head",)  # linha 403 ANTES do fix
   ```
   - Este tuple controla quais meshes vão para o GLB "head"
   - Apenas seg_head estava sendo incluído
   - **Todos os 8 segmentos faciais eram descartados no export**

---

## 3. Solução Implementada

### Commit 00d32e71 — `[FIX] Adiciona segmentos faciais ao HEAD_MESHES`

**Arquivo:** `tools/asset_generation/p3_posture_export.py` linha 403-408

**ANTES:**
```python
HEAD_MESHES = ("seg_head",)
```

**DEPOIS:**
```python
HEAD_MESHES = ("seg_head", "seg_hair_top", "seg_hair_back",
               "seg_eye_L", "seg_eye_R", "seg_nose",
               "seg_beard_chin", "seg_beard_L", "seg_beard_R")
```

**Impacto:**
- GLB head agora exporta com **9 meshes** (vs 1 antes)
- Facial features incluídos no bake Godot
- Frames PNG contêm cabelo, barba, olhos e nariz

### Pipeline de Regeneração

1. **Limpeza de cache:**
   ```bash
   rm -rf ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_head_enemy_white
   rm -rf ASSETS/ISOMETRIC/source_assets/actor_bakes/agent_frames_enemy_white
   ```

2. **Regeneração de postures:**
   ```bash
   P2_MODEL=agent_base_enemy_white P2_EXPECTED_HEIGHT_M=1.945 P3_DEV_ONLY=0 \
     /Applications/Blender.app/Contents/MacOS/Blender --background \
     --python tools/asset_generation/p3_posture_export.py
   ```
   - Exports: standing (1.945 m), crouch (1.120 m), prone (0.517 m)
   - Manifest: `Screenshots/p3_postures_enemy_white/manifest.json`

3. **Bake Godot (windowed, real GPU):**
   ```bash
   AGENT_BAKE_MANIFEST=Screenshots/p3_postures_enemy_white/manifest.json \
     /Applications/Godot.app/Contents/MacOS/Godot --path . --position 4000,4000 \
     --script res://godot/scripts/tools/agent_frame_bake_spike.gd
   ```
   - 3 bodies × 4 perspectives
   - 2 head layers (standing/crouch) × 24 yaws each
   - Verification: composite vs whole figure ✅ <1% silhouette mismatch

### Código de Produção

**Arquivo:** `godot/scripts/agents/guard_enemy.gd` linha 1108-1113

Atualizado comentário de TEMPORARY para permanente:
```gdscript
## Alpha enemy variant (2026-08-19): white blazer with stylized facial features
## (hair, beard, eyes, nose) to differentiate front/back. Inherits light
## response from test_white (ambient 0.75) to prevent the "branco virou cinza"
## issue. The faceless dark-suit _enemy palette remains in the repo.
s.frame_family = "_enemy_white"
```

**Sistema de override (preservado):**
- Variável `INFILTRAITOR_ENEMY_FAMILY` permite trocar família sem editar código
- Usado em brackets (WHITE-AMBIENT-01, etc)

---

## 4. Resultados Validados

### Verificação Visual (Director)

✅ **"Ok, consigo ver o cabelo e as expressões faciais."**

### Dados Técnicos

**GLB head export (Blender verification):**
```
Materiais:
  hair   → base_color = (0.08, 0.06, 0.05)   luma ~17
  beard  → base_color = (0.10, 0.08, 0.07)   luma ~21
  eye    → base_color = (0.95, 0.95, 0.96)   luma ~243
  skin   → base_color = (0.66, 0.50, 0.38)   luma ~134

Meshes faciais:
  seg_hair_top, seg_hair_back       → hair
  seg_eye_L, seg_eye_R              → eye
  seg_nose                          → skin
  seg_beard_chin, seg_beard_L/R     → beard
```

**Bake output:**
- Body frames: 104×187 px (standing N), albedo mean RGB(166, 166, 167)
- Head frames: 24 yaws × 2 postures, 0.32 MB cropped (37.6× compression)
- Registration check: worst 0.93% silhouette mismatch (crouch) — within tolerance

---

## 5. Commits da Sessão

1. **00d32e71** — `[FIX] Adiciona segmentos faciais ao HEAD_MESHES`
   - Expande tuple de 1 → 9 meshes
   - Facial features agora incluídos no head GLB export
   - **Push:** github.com:K4PUTZ/InfilTraitor.git

2. **(este commit)** — `[ALPHA] Enemy Hair — facial features complete`
   - Atualiza comentário guard_enemy.gd (TEMPORARY → permanente)
   - Regenera CODEMAP
   - Documenta sessão completa

---

## 6. Lições Técnicas

### HEAD_MESHES como Filtro de Export

**Aprendizado:** Tuples de configuração (`HEAD_MESHES`, `HAT_MESHES`, `PARTS`) são **filtros durante export** — meshes ausentes são silenciosamente descartados, não geram erro.

**Impacto anterior:**
- HEAD_MESHES = ("seg_head",) → apenas skull base exportado
- 8 facial meshes ficaram no body export, que é headless
- Resultado: facial features em **nenhum** dos GLBs exportados

**Detecção:**
- Sintoma visual: features ausentes in-game
- Análise pixel: zero pixels nos ranges esperados de luma
- Diagnóstico: contar meshes no GLB (9 esperados, 1 encontrado)

### Pipeline Multi-Estágio e Cache

**GLBs intermediários** podem ficar stale:
- p1 gera `.blend` → p3 importa → p3 exporta GLB posed → Godot bake PNG
- Fix em p1/p3 exige deletar GLBs posed antigos para forçar regeneração
- Timestamp dos arquivos é evidência: GLBs de 22:56 vs base model 22:53

**Manifest como Source of Truth:**
- `Screenshots/p3_postures_<variant>/manifest.json` lista GLBs e out_dirs
- Usado por `agent_frame_bake_spike.gd` para processar todos postures+layers em **um** boot
- Evita hardcoded paths que quebram com variantes de palette

### Materiais Blender → glTF

**Bug histórico (documentado em p2_grip_spike.py:552-606):**
- Blender salva `diffuse_color` mas exporta `Principled BSDF base_color`
- `.blend` recarrega com base_color = (0.8, 0.8, 0.8) default grey
- `materialise_for_export()` sincroniza antes do export GLB
- **Este fix já existia e funcionou** — não foi a causa do problema desta sessão

---

## 7. Estado do Sistema

### Variantes de Enemy

| Variant | Suit | Pants | Face | Hat | Status |
|---------|------|-------|------|-----|--------|
| `_enemy` | Dark grey | Dark | None | Fedora | Repo (não usado) |
| `_enemy_white` | White (0.92) | Black | ✅ Hair/beard/eyes/nose | None | **Alpha (current)** |

### Light Response Override

**Arquivo:** `godot/scripts/agents/agent_sprite.gd` linha 239-252

```gdscript
const LIGHT_RESPONSE_OVERRIDE := {
    "_test_white": {"scale": 1.00, "max": 2.20, "ambient": 0.75},
    "_enemy_white": {"scale": 1.00, "max": 2.20, "ambient": 0.75},
}
```

**Rationale:** White blazer (0.92 albedo) sob ambient 0.42 default renderiza 0.386 em sombra — MAIS ESCURO que PLAYGROUND floor (0.55-0.65). Ambient 0.75 foi escolhido pelo Director como balanço entre clareza e risco de estourar em telas muito brilhantes.

### Arquivos Gerados

**Bakes:**
```
ASSETS/ISOMETRIC/source_assets/actor_bakes/
  agent_frames_enemy_white/
    standing/  (frame_{N,E,S,W}_{color,normal}.png + anchor.json)
    crouch/
    prone/
  agent_head_enemy_white/
    standing/  (yaw_000..yaw_345 × {color,normal}.png)
    crouch/
```

**Posed GLBs:**
```
ASSETS/ISOMETRIC/source_assets/imported_models/agent/
  agent_base_enemy_white.glb                            (802 KB)
  agent_posed_shotgun_lowered_enemy_white.glb          (567 KB)
  agent_posed_shotgun_lowered_enemy_white_body.glb     (492 KB)
  agent_posed_shotgun_lowered_enemy_white_head.glb     ( 75 KB — 9 meshes)
  agent_posed_shotgun_lowered_enemy_white_crouch*.glb
  agent_posed_shotgun_lowered_enemy_white_prone.glb
```

---

## 8. Próximos Passos (Não Nesta Sessão)

- [ ] Beta: animação walk cycle (p3_walk_export.py)
- [ ] Palette variations: múltiplas cores de blazer/cabelo mantendo a geometria
- [ ] Hat system: fedora como layer opcional (D53)
- [ ] Faction differentiation: uniform color = faction ID (D63)

---

**Sessão encerrada:** 2026-08-19 02:40  
**Commits:** 2 (00d32e71 + final)  
**Resultado:** Enemy_white renderiza com cabelo, barba, olhos e nariz — validado visualmente pelo Director.
