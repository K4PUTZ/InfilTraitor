# ENHANCE_MASTER_PLAN — Consolidação Pré-Baking

**Data:** 2026-07-03
**Status:** PLANNING — prompts gerados um a um após aprovação do diretor
**Posição na timeline:** entre SLICE-02 (✅ completo) e TEX-CATALOG-01 (📋 adiado)
**Caminho sugerido no repo:** `docs/technical/ENHANCE_MASTER_PLAN.md`

---

## 0. Posição na Timeline

```
✅ SLICE-00   — Transform Canon + alignment selftest
✅ SLICE-01   — Geometry module greenfield
✅ SLICE-02   — Integration (Stage A) + Legacy Purge (Stage B) + calibração (112, 64)
▶  ENHANCE    — ESTE PLANO (faxina profunda → erros → modularização wave 2)
📋 TEX-CATALOG-01 — adiado; aguarda 4 decisões do diretor
→  MAT-01 → VOXEL-08 (Baking) → VOXEL-09 → SLICE-03
```

**Adiado explicitamente:** as 4 decisões de textura (RUN-8 vs RUN-5, altura de
andares do RUN, cap de topo, autoria nativa vs @2x) e tudo do Baking System.
Nenhum prompt ENHANCE pode tocar nesses temas.

---

## 1. Objetivo e Princípios

Três pilares, na ordem definida pelo diretor:

1. **Faxina criteriosa** — zero pontas soltas: nenhum comentário, variável,
   caminho de pasta, entrada de registry, ferramenta ou documento carregando
   terminologia de sistemas mortos (cubos/minicubos/subcubos) fora das zonas
   de arquivo. Sistema limpo, sem peso morto.
2. **Primeira camada de tratamento de erros** — simples: convenção única,
   guardas nas costuras, erradicação de padrões silenciosos. Sem framework.
3. **Modularização wave 2** — `room.gd` voltou a acumular (2.360 linhas,
   85 funções). Extrair debug, perspectiva, input/seleção, marcadores,
   builder e fase inimiga sem quebrar o sistema.

**Princípios herdados (inegociáveis):**
- Transform Canon 1: plano de gameplay FROZEN; render adapta.
- Comunicação: módulo→room via **signal**; room→módulo via **call direto**;
  módulo↔módulo **nunca** (exceção documentada: `lighting_rebuilt`).
- Um prompt por sessão; smoke test completo entre sessões; unidade de
  revert = um commit por prompt.
- K4PUTZ só marca PASS com evidência de execução real (output literal de
  console); zero warnings novos na aba PROBLEMS.

---

## 2. Inventário de Estado (auditoria de 2026-07-03, backup pós-Stage-B)

Fatos medidos por grep no backup — não por leitura de reports.

### 2.1 🔴 Fio desencapado ATIVO (bug real, prioridade máxima)

| Arquivo | Linha | Problema |
|---|---|---|
| `godot/scripts/tools/slice_geometry_selftest.gd` | 7 | `load("res://godot/scripts/world/subcube_coords.gd")` — arquivo deletado no Stage B. O selftest do SLICE-00 falha em runtime desde o purge. |

O smoke test não pegou porque o selftest não roda no boot. Decisão necessária
no prompt: **reapontar** o check para `GeometryCoords` (preferido — mantém a
cobertura do Canon) ou aposentar o check com data.

### 2.2 Resíduo de código vivo (.gd)

| Item | Localização | Natureza | Ação proposta |
|---|---|---|---|
| `world/wall_slice.gd` | `class_name WallSlice` global | Arquivo morto, fora do spec do purge (spec assumiu que a classe vivia em `voxel_registry.gd`) | DELETE + `.uid` |
| `world/voxel_ref.gd` | `class_name VoxelRef` global | Idem | DELETE + `.uid` |
| `world/high_wall.gd` | `class_name HighWall` global | Idem (não confundir com `geometry/high_wall.gd`, que fica) | DELETE + `.uid` |
| 8 `.uid` órfãos | tools/ e world/ | Sobras dos 8 arquivos deletados no Stage B | DELETE |
| `tile_registry.gd:36–39` | `subcube_concrete/metal/stone/wood` (IDs 28–31) | Entradas de tileset legado; renderer novo usa `voxel_%s.png` | Remover via **regeneração** (ver 2.3) |
| `room.gd:85` | comentário `SUBCUBE_STEP_PX` | Invariante histórico | Reescrever neutro |
| `room.gd:1833,1835` | comentários "Subcube render plane" | Descrição stale da costura | Reescrever ("voxel render plane") |
| `map_compiler.gd:40,181,195–196` | comentários + chamada comentada | Cicatriz do Stage B | Reescrever/remover; git guarda a história |
| `geometry_coords.gd:2`, `edge_extractor.gd:2` | comentários "Port from subcube_*.gd" | Proveniência apontando p/ arquivos mortos | Neutralizar ("Ported from legacy system; ver docs/history/") |
| `maps/definitions/playground_map_old.gd` | sufixo `_old`, zero consumidores encontrados | Definição órfã | Confirmar em `map_catalog.gd` → DELETE ou mover p/ history |

### 2.3 Resíduo no pipeline de assets

A cadeia geradora é: `ASSETS/ISOMETRIC/source_assets/` → `build_tileset.gd`
→ **gera** `tileset_blocks.tres` **e** `tile_registry.gd`.

| Item | Estado | Ação canônica |
|---|---|---|
| `ASSETS/.../source_assets/subcubes/` (4 PNGs) | Fora do backup, mas referenciados por `tileset_blocks.tres:24–28` | Mover p/ `ASSETS/_archive/` no repo real |
| `tileset_blocks.tres` | 4 `ext_resource` subcube + 4 `custom_data` | **Não editar à mão**: re-rodar `build_tileset.gd` após arquivar a pasta — as entradas caem sozinhas do .tres e do registry |
| `tools/asset_generation/generate_subcube.py` | Banido pelo glossário §10 (substituto `generate_voxel.py`, já existe) | Mover p/ `tools/_archive/` |
| `generate_wall.py` | Banido §10 | Mover p/ `tools/_archive/` |
| `generate_master_block.py` (20 menções), `generate_master_walls.py`, `generate_master_crate.py`, `generate_crate_simple.py` | Menções residuais; utilidade a confirmar | Triagem no prompt: arquivar mortos, limpar comentários dos vivos |

⚠️ `ASSETS/` não veio no backup — os passos desta seção executam no repo
real do K4PUTZ, com verificação de que `voxel_%s.png` existem antes de
arquivar os subcubes.

### 2.4 Resíduo documental

**Política de isenção (ver §3):** `docs/history/`, `PROMPTS/DONE/` e as
tabelas de Termos Banidos são zonas de arquivo — menções ali são legítimas.

| Documento | Problema | Ação |
|---|---|---|
| `DIRECTION_GLOSSARY.md` §6 | Documenta `_EDGE_BY_SUFFIX — subcube_geometry.gd`, arquivo morto | Reescrever seção como registro histórico apontando p/ `geometry/face.gd`, ou remover |
| `SLICE-02-completion-report.md` | Diz "9 files deleted" (foram 8; `map_compiler.gd` mantido); contagens de vars/preloads/funcs não batem com o spec | **Errata** datada no rodapé — reports são registro histórico, não se reescrevem em silêncio |
| `PROMPTS/SLICE-02-purge-specification.md` | Ainda manda DELETE em `map_compiler.gd` (grep do spec estava errado; arquivo é vivo em `room.gd:269`) | Errata + mover p/ DONE/ |
| `docs/technical/SUBCUBE_WALL_STRADDLE.md` | Doc inteiro sobre sistema morto | Mover p/ `docs/history/` |
| `QUICK_REFERENCE.md` | "matches old subcube system" e derivações antigas | Limpar menções |
| `ARCHITECTURE.md`, `rendering.md`, `ASSET_MAP.md`, `current_state.md`, `milestones.md`, `VOXEL_MASTER_PLAN.md` | Menções residuais em texto vivo | Varredura com reescrita neutra |
| `README.md` (raiz) | Status congelado em 2026-06-06; não menciona pipeline geometry/voxel | Refresh da seção de status |
| `PROMPTS/` (raiz) | SLICE-00, SLICE-01b, SLICE-02-integration concluídos mas fora de DONE/ | Higiene: mover concluídos p/ DONE/ |
| `CODEMAP.md` | Auto-gerado, pré-purge parcial | Regenerar no gate final |

### 2.5 Censo de tratamento de erros (baseline)

| Padrão | Ocorrências | Observação |
|---|---|---|
| `push_error` | 33 | Sem prefixo padronizado; concentrado em selftests e builders |
| `push_warning` | 7 | Idem |
| `assert(` | 0 | Nenhum invariante verificado em debug |
| `printerr` | 20 | Padrão a erradicar — não integra com a aba de erros do editor |

Costuras hoje sem guarda consistente: `MapCatalog.get_spec()` (id
desconhecido), `TileRegistry` lookup (tile_name inexistente),
`EdgeExtractor.extract()` (spec malformado), caminho `load_map()`
(validate-then-commit inexistente — spec ruim pode deixar a sala em estado
parcial).

### 2.6 Estado da modularização

Controllers existentes (1.080 linhas somadas): VisionController (275),
LightingController (266), CameraController (182), HudController (172),
GuardCoordinator (108), FowController (77). As sessões A–F do
MODULARIZATION_PLAN original foram todas executadas; os placeholders
futuros (InputRouter etc.) não.

`room.gd` hoje: **2.360 linhas / 85 funções / 33 `@onready` / 14
`.connect()`**. O DoD original (≤ 400 linhas) nunca foi atingido — o
arquivo reacumulou fase inimiga, perspectiva, debug tooling, input,
marcadores e plumbing de build. O §4 mapeia a extração função a função
(Apêndice B).

---

## 3. Política de Varredura (o que é resíduo, o que é isento)

Regras que os prompts ENHANCE-00/01 aplicam e que o gate final verifica:

1. **Termos-alvo (compostos):** `subcube`, `subcubo`, `sub-cube`, `minicube`,
   `minicubo`, `mini-cube` — banidos em código vivo, comentários, caminhos,
   nomes de arquivo e docs vivos.
2. **"cubo"/"cube" simples NÃO é banido.** Usos geométricos legítimos ficam
   (ex.: "cube face height" descrevendo `WALL_FLOOR_STEP_PX`). O alvo é a
   terminologia do sistema morto, não a palavra.
3. **Zonas isentas (arquivo):** `docs/history/`, `PROMPTS/DONE/`,
   `.aider*`. Menções ali são registro histórico e não contam no gate.
4. **Tabelas de Termos Banidos são isentas** (`DIRECTION_GLOSSARY.md` §10,
   `OPERATOR_CONTEXT.md` "What NOT to Do"): elas *definem* o banimento e
   precisam citar os termos. O gate as exclui por caminho+âncora.
5. **Termos banidos do §10 também entram na varredura:** `Kenney`,
   `blend_rect` (render de parede), `is_x_varying`, `FACE_CENTER_OFFSET`,
   `WallContainer.build`, `SUBCUBE_*` — mesmo tratamento.
6. **Proveniência:** comentários "Port from <arquivo morto>" viram
   "Ported from legacy wall system (docs/history/)". Git history é a
   fonte de proveniência, não comentário vivo.
7. **Reports concluídos não se reescrevem** — recebem **errata datada**.
   Specs pendentes de correção recebem errata e vão para DONE/.

**Grep canônico do gate** (zero linhas esperadas fora das isenções):

```bash
grep -rniE "subcube|subcubo|minicube|minicubo|sub-cube|mini-cube" \
  godot/ tools/ docs/ PROMPTS/ README.md \
  --include="*.gd" --include="*.py" --include="*.md" \
  --include="*.tres" --include="*.tscn" \
  | grep -vE "docs/history/|PROMPTS/DONE/|DIRECTION_GLOSSARY.*Termos Banidos|OPERATOR_CONTEXT"
```

(Versão executável com exclusões por linha entra no prompt ENHANCE-01;
a filtragem do glossário/operator é por seção, validada manualmente.)

---

## 4. Fases e Prompts

Dez prompts pequenos, um por sessão. 00–01 = faxina; 02 = erros;
03–08 = modularização em risco crescente; 09 = gate final.

### PILAR 1 — Faxina

**ENHANCE-00 — Purge residual de código + pipeline de assets**
- Corrigir o fio desencapado: `slice_geometry_selftest.gd:7` reaponta o
  Check 5 para `GeometryCoords` (mantém cobertura do Canon).
- Deletar `world/{wall_slice,voxel_ref,high_wall}.gd` + seus `.uid` + os
  8 `.uid` órfãos do Stage B.
- Triagem `playground_map_old.gd` (grep em `map_catalog.gd`) → DELETE.
- Repo real: arquivar `source_assets/subcubes/` e
  `generate_subcube.py`/`generate_wall.py`; re-rodar `build_tileset.gd`
  → `.tres` e `tile_registry.gd` regenerados sem entradas subcube.
- Triagem dos demais `generate_master_*.py`.
- **Aceite:** grep §3 zero em `godot/ tools/` (código); projeto compila;
  ambos os mapas carregam; selftests SLICE verdes (output literal);
  PROBLEMS zero.

**ENHANCE-01 — Purge residual documental**
- Reescritas neutras: comentários de `room.gd`, `map_compiler.gd`,
  `geometry_coords.gd`, `edge_extractor.gd`.
- Glossário §6 reescrito; `SUBCUBE_WALL_STRADDLE.md` → history/;
  erratas no completion-report e no purge-spec (caso `map_compiler`);
  varredura dos docs vivos listados em 2.4; refresh do status do README;
  higiene de PROMPTS/ (concluídos → DONE/).
- **Aceite:** grep §3 zero no repo inteiro fora das isenções; links
  internos dos docs tocados válidos.

### PILAR 2 — Erros

**ENHANCE-02 — Contrato de erros + guardas nas costuras**
- **Contrato (uma página, entra no OPERATOR_CONTEXT):**
  - `push_error("[Classe] contexto: %s" % detalhe)` → falha de
    configuração/asset/spec; a operação aborta limpa (early return),
    nunca deixa estado parcial.
  - `push_warning(...)` → dado estranho com fallback documentado
    (ex.: tile_name desconhecido → tile de fallback).
  - `printerr` **erradicado** (20 ocorrências → migrar ou deletar).
  - `assert()` permitido só para invariantes internos de módulo
    (strip automático em release build).
- **Guardas nas costuras estáveis** (arquivos que NÃO se movem no
  Pilar 3): `MapCatalog.get_spec` (id inexistente), `MapCompiler.compile`
  (REQUIRED_KEYS completo + tipos), `TileRegistry` lookup,
  `EdgeExtractor.extract` (wall_levels malformado), `VoxelRenderer`
  (asset ausente → aborta render do bloco, não do jogo).
- **`load_map()` validate-then-commit:** compilar → validar → só então
  desmontar a sala atual. Spec inválido = erro + sala anterior intacta.
- **Selftest negativo:** novo grupo no `geometry_selftest.gd` alimentando
  spec ruim e esperando erro limpo (não crash).
- **Sequenciamento deliberado:** guardas *internas* de `room.gd` NÃO
  entram aqui — cada extração do Pilar 3 carrega um checklist de guardas
  do módulo movido. Evita escrever guarda em código que muda de casa na
  semana seguinte.
- **Aceite:** happy path com zero errors/warnings no console; suite
  negativa verde; `grep -rn printerr godot/scripts` = 0.

### PILAR 3 — Modularização Wave 2

Mesmo contrato de comunicação, mesmos invariantes, mesma regra de um
módulo por sessão do plano original. Ordem por risco crescente; smoke
completo entre sessões; revert = 1 commit.

**ENHANCE-03 — DebugToolsController** *(risco: baixo; ~400 linhas fora)*
- Move: `_toggle_map_loader_panel`, `_create_map_loader_button`,
  `_toggle_voxel_ruler_overlay`, `_toggle_nudge_mode`, `_apply_nudge`,
  `_reset_nudge`, `_debug_probe_voxel_alignment`, `_draw_shadow_debug`,
  `_update_dev_hover_label`, `_capture_screenshot_to_file`,
  `_show_screenshot_toast` + branches F2/F3/F4/screenshot do `_input`.
- Dev-only: quebra não afeta gameplay. Maior ganho imediato de linhas.

**ENHANCE-04 — PerspectiveMapper** *(risco: baixo-médio; ~280 linhas)*
- Matemática pura → `world/perspective_mapper.gd` (static):
  `_layout_with_perspective`, `_perspective_angle_delta_deg`,
  `_rotated_size`, `_cell_from_base`, `_cell_to_base`,
  `_remap_tile_name_for_perspective`.
- Glue fina (`_set_perspective`, `_update_perspective_button_state`)
  permanece em room ou vira mini-controller — decidir no prompt.
- Funções puras = testáveis: adicionar grupo de round-trip
  (`cell_from_base(cell_to_base(x)) == x` nas 4 direções) ao selftest.

**ENHANCE-05 — SelectionController + InputRouter** *(risco: médio; ~300 linhas)*
- Move: `_update_selected_preview`, `_update_movement_highlight`,
  `_is_selectable_cell`, `_set_selected_cell`, `_handle_tile_click`,
  `_try_move_to`, `_try_peek`, `_try_change_posture`.
- Consolida `_input`/`_unhandled_input` (125+ linhas) no InputRouter —
  placeholder previsto no plano original. Room mantém dispatcher fino.

**ENHANCE-06 — Marcadores de mundo + spill de sombra** *(risco: médio-baixo; ~180 linhas)*
- `_draw_exit_markers`, `_draw_spawn_marker`, `_draw_playable_boundary`,
  `_draw` → WorldMarkersOverlay.
- `_repaint_world_shadows`, `_compute_shadow_spill`, `_spill_reach_for`,
  `_spill_color` → LightingController (é lógica de sombra; a exceção
  `lighting_rebuilt` já cobre a dependência com Vision).
- *Mesclável com o 05 se a sessão render.*

**ENHANCE-07 — RoomBuilder** *(risco: médio-alto; ~250 linhas)*
- Move plumbing de construção: `_build_room`, `_render_solid_blocks`,
  `_ensure_wall_upper_layers`, `_ensure_prop_stack_layers`, `_place`,
  `_build_registry`, `_cache_blocked_cells`,
  `_build_navigation_blocked_cells`.
- Room mantém `load_map()` como orquestrador e a posse de
  `_blocked_cells` (source of truth não migra; builder escreve via
  referência recebida no `setup()`).

**ENHANCE-08 — TurnController (fase inimiga + tics)** *(risco: ALTO; ~250 linhas; por último)*
- Move: `_run_enemy_phase`, `_enemy_inter_turn_pause_with_camera`,
  `_hold_actor_end_pause`, `_focus_camera_for_enemy_phase`,
  `_on_enemy_phase_started`, `_apply_tic_result`, `_get_detection_decay`,
  `_process_audio_detection`, `_emit_guard_noise_indicator`.
- Invariantes preservados textualmente: `_alert_meter` só acumula em
  `_apply_tic_result()`; transição só via `_enter_state()`; coordenação
  guard↔guard só via signal em room. `_guards[]` continua em room.
- Pré-requisito: 03–07 concluídos e smoke verde (espelha a regra
  "GuardCoordinator por último" do plano original).

### GATE FINAL

**ENHANCE-09 — Gate de consolidação**
- Regenerar CODEMAP.md; atualizar ARCHITECTURE.md (módulos novos) e
  file map do OPERATOR_CONTEXT.
- Rodar a matriz de smoke completa + suíte de selftests + grep §3 global.
- Checklist DoD abaixo, com evidência literal por item.

---

## 5. Definition of Done (fase ENHANCE)

- [ ] Grep §3 → **zero** fora das zonas isentas (repo inteiro).
- [ ] Nenhum arquivo `.gd` morto; nenhum `.uid` órfão.
- [ ] `tileset_blocks.tres` e `tile_registry.gd` regenerados sem entradas
      de sistema morto.
- [ ] `slice_geometry_selftest` verde de ponta a ponta (output literal).
- [ ] Contrato de erros publicado no OPERATOR_CONTEXT; `printerr` = 0;
      suíte negativa verde; happy path sem errors/warnings.
- [ ] `load_map()` validate-then-commit: spec inválido não desmonta sala.
- [ ] `room.gd` ≤ **750 linhas** (meta: ~700; stretch 600). Sobra em room:
      `load_map`/`_ready`/setup de módulos, utilitários de grid, estado
      compartilhado, orquestração fina de turno, seams `_on_hud_*`.
- [ ] 6 controllers existentes intactos; novos módulos seguem o contrato.
- [ ] Smoke matrix: PLAYGROUND + SIGMA_01 + procedural, alturas 1 e 3,
      perspectivas N/E/S/W, turno completo com detecção — idêntico ao
      pré-ENHANCE.
- [ ] PROBLEMS tab: zero warnings (regra permanente).
- [ ] CODEMAP/ARCHITECTURE/README refletem o estado final.

---

## 6. Fora de Escopo

- Baking System inteiro (TEX-CATALOG-01, MAT-01, VOXEL-08) e as 4
  decisões de textura — adiados por decisão do diretor em 2026-07-03.
- Qualquer feature de gameplay nova; qualquer mudança de comportamento
  visível. ENHANCE é neutro por definição: mesmo jogo, código melhor.
- `CombatController`/`LevelController` (placeholders M2-10/M3) — ficam
  para seus milestones.

---

## Apêndice A — Riscos e Mitigação

| Risco | Onde | Mitigação |
|---|---|---|
| Regenerar tileset alterar IDs de tiles vivos | ENHANCE-00 | Diff do `tile_registry.gd` gerado: IDs 0–27 devem permanecer idênticos; se mudarem, abortar e investigar `build_tileset.gd` |
| ASSETS fora do backup | ENHANCE-00 | Passos de asset executam no repo real com verificação prévia (`voxel_*.png` presentes) |
| Extração quebrar sinal silenciosamente | 03–08 | Cada prompt lista os `.connect()` movidos + smoke com ação que dispara cada sinal |
| `_apply_tic_result` mover e vazar acúmulo de alerta | ENHANCE-08 | Grep de aceite: `_alert_meter` escrito em exatamente 1 função; teste de detecção no smoke |
| Room ficar anêmico demais (over-split) | 03–08 | Utilitários de grid e estado compartilhado NÃO migram (invariantes 2–3 do plano original) |

## Apêndice B — Mapa de Extração (função → destino)

| Destino | Funções (linha atual em room.gd) |
|---|---|
| DebugToolsController | 635, 646, 658, 672, 683, 698, 975, 1380, 1711, 2303, 2340 + F-keys de `_input` (2144) |
| PerspectiveMapper (static) | 1918, 1995, 2003, 2009, 2028, 2047 |
| Perspective glue | 561, 626 |
| SelectionController | 1008, 1167, 1520, 1537, 1550, 1556, 1569, 1586 |
| InputRouter | 2144, 2269 (consolidados) |
| WorldMarkersOverlay | 789, 812, 835, 1499 |
| LightingController (absorve) | 880, 911, 951, 967 |
| RoomBuilder | 1611, 1624, 1633, 1651, 1665, 1818, 1872, 1449 |
| TurnController | 1198, 1229, 1267, 1275, 1281, 1072, 1113, 1127, 1303 |
| **Permanece em room** | 255 (load_map), 347 (_ready), 706, 711–780 (seams HUD), 1029–1065 (agent move), 1151, 1181, 1189, 1321–1371 (estado/alert label/reset/guards), 1420, 1460, 1470, 1907, 1914, 2068, 2093–2143 (process/fog/temporal) |

---

**Fluxo de aprovação:** diretor revisa este plano → ajustes → prompts
ENHANCE-00..09 gerados um a um, cada um com escopo fechado, código
completo e critérios de aceite com grep, no padrão do OPERATOR_CONTEXT.
