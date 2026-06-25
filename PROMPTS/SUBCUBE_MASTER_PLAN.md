# INFILTRAITOR — Subcube Architecture Master Plan

> **Criado:** 2026-06-24 · **Última revisão:** 2026-06-25 (sessão 4 — virada para dois níveis)
> Fonte de verdade para as decisões arquiteturais do sistema de subcubos.
>
> ⚠️ **Esta revisão reverte a decisão #1 da sessão 3.** O subcubo deixa de ser o
> tile de gameplay e passa a ser um detalhe de implementação visual. Ver §1.

---

## Glossário de Eixos — a pegadinha dos "4×4"

O número **4** (e a forma **4×4**) aparece em eixos ortogonais diferentes. Dizer
"o 4×4" sem nomear o eixo é a causa-raiz de prompts mal especificados. **Sempre
qualifique o eixo e use o termo nomeado.**

| Termo | Eixo | Forma | Significado |
|---|---|---|---|
| **Gameplay Unit** | horizontal (chão) | `4×4` | footprint de 1 unidade de gameplay = 16 subcube cells no plano do piso |
| **Storey** (andar) | vertical | `4` de altura | 1 andar = 4 subcubos empilhados; `SUBCUBES_PER_FLOOR = 4` |
| **Wall Face** (face de parede) | elevação (2D) | `4×4` | parede de 1 andar numa borda de unidade = 4 subcubos de largura × 4 de altura |
| **Unit Block** (bloco cheio) | volume (3D) | `4×4×4` | 1 Gameplay Unit totalmente preenchida com 1 andar = 64 subcubos |
| **Razão de grid** | linear | `4×` | o grid fino é 4× mais denso que o grosso por eixo (16× em área, 64× em volume) |

**Regra de escrita:** nunca escreva "o 4×4" sozinho. Escreva "o footprint 4×4 da
unidade", "o andar de 4 subcubos", "a face de parede 4×4 de altura", "o bloco
4×4×4". Em prompts pro operador, prefira os termos nomeados (Gameplay Unit,
Storey, Wall Face, Unit Block) a números soltos.

---

## Decisões Canônicas

### 1. Dois espaços de coordenadas — o subcubo NÃO é o tile de gameplay ⟵ REVISADO (sessão 4)

O subcubo é um detalhe de implementação **visual**, invisível ao jogador. O
gameplay continua raciocinando em **Gameplay Units** (o grid grosso atual). Dois
planos distintos:

- **Plano de gameplay** — grid grosso existente, `CELL_SIZE = 256×128`. Dono de:
  guard FSM, A\*, `blocked_cells` / `blocked_edges`, TicSystem (por aresta),
  alarmes, triggers, movimento do agente, cover, lógica de missão.
  **Código inalterado.**
- **Plano de geometria / render** — grid fino novo, `SUBCUBE_SIZE = 64×32`,
  `4×4` subcubos por Gameplay Unit. Dono de: empilhamento de subcubos, face
  lighting, oclusão, sombra, geometria dinâmica (furos). **Código novo, aditivo.**
- **A costura** — `map_compiler.gd` (já existe, 265 linhas) expande uma Gameplay
  Unit em geometria de subcubos. Conversões `unit→subcube` (×4) e `subcube→unit`
  (÷4 + offset) acontecem **só na fronteira**.

**Por quê:**
- Preserva *verbatim* todo o código de gameplay já escrito → risco de regressão baixo.
- A\* roda no grid grosso (~1.288 nós), não nos ~20k do grid fino → portão de
  profiling no device some.
- A granularidade fina fica restrita aos sistemas visuais (LOS de luz, oclusão,
  sombra) — que é onde o objetivo de fidelidade 2.5D sempre esteve. O grid fino
  de *gameplay* foi conflado com "quero resolução visual fina"; só a segunda era
  o objetivo real.

### 2. Pipeline de assets — 🅿️ PARQUEADO (foco atual é a engine visual)

Os átomos e compostos já existem e os PNGs estão OK. **Assets saem do caminho
crítico por enquanto.** Direção futura definida nesta sessão: **atlas de cubos
pré-fabricados** (um grande atlas em vez de scan por-PNG), o que vai reescrever a
natureza do `build_tileset.gd`. Itens parqueados (ver auditoria da sessão 4):

- `build_tileset.gd` está meio-migrado (já é single-source, mas `CELL_SIZE`/
  `PNG_SIZE`/`SPRITE_OFFSET`/região ainda na escala antiga; sem `subcube` no
  `TILE_PROPS`; sem registro direcional de átomos).
- Os geradores novos (`generate_subcube.py`, `generate_wall.py`) escrevem em
  `master_assets/` — pasta que o builder **não** escaneia (ele lê `source_assets/`).
  Por isso o `tile_registry.gd` não tem nenhuma entrada `subcube_*`.
- **Unblock mínimo** (pré-requisito do render layer, distinto da reescrita do
  atlas): corrigir os dois `OUTPUT_DIR` para `source_assets/`, re-rodar o builder,
  confirmar `subcube_*` no registry.

### 3. Dual-mode rendering: runtime + pre-render (mantido — plano de render)

- **Runtime stacking** — `subcube_[material]` em N `TileMapLayer`s por célula.
  Suporta oclusão por layer e face lighting por layer. Padrão para tudo.
- **Pre-render composto** — PNG composto pelo gerador Python para props complexos
  ou variações artísticas. Vai no tileset como tile único multi-layer.

### 4. Agente e TicSystem — por aresta, sem ×4 ⟵ REVISADO (sessão 4)

- `AGENT_STEP_CELLS = 1` (**inalterado**). O agente move 1 Gameplay Unit por step.
- **TicSystem dispara por aresta** no grid grosso, como sempre. Sem caminho por
  sub-tiles intermediários, sem peso 1/4 por cruzamento, sem retuning de detecção.
- A granularidade de detecção fina (guard ouvir 4 passos por movimento) foi
  **abandonada** — era consequência do grid de gameplay fino, que não existe mais.

### 5. Vertical — andares teóricos mantidos (plano de render)

`SUBCUBES_PER_FLOOR = 4` como convenção de design. O render layer conhece N
subcubos de altura. Demo começa com 3 andares teóricos (12 subcubos de altura).

### 6. Doorways e colunas — regras gerais (plano de render)

- **Doorway** = ausência de subcubos na geometria da célula. Frame decorativo é
  prop separado. Nenhum tile especial de doorway.
- **Colunas** = pilha de `block_[material]` em runtime. Nenhum tile especial.

### 7. Oclusão por deleção = destruição — mesma operação ⟵ NOVO (sessão 4)

**Substitui o sistema de dither (Bayer 4×4) planejado.** Quando uma parede
oclui a câmera, o render layer **apaga os subcubos das fileiras superiores** e
mantém um toco na base (ex.: a fileira `h=0`). É o comportamento do XCOM (corta a
parede fora), mais legível e mais barato que fade — mata o shader de dither e o
tween de alpha por subcubo.

Oclusão e destruição são a **mesma operação**: `set_subcube(célula, altura) →
vazio; re-light`. A diferença é só o gatilho e a reversibilidade:

| | Gatilho | Reversível? |
|---|---|---|
| **Oclusão** | câmera / perspectiva | sim (volta ao sair da frente) |
| **Destruição** | evento (bala, explosão) | não (permanente) |

Em vez de dois sistemas, um só conceito: **presença de subcubo**. Quantas
fileiras manter na oclusão é tuning de art director.

### 8. Destruição como capacidade da engine — escopo enxuto ⟵ NOVO (sessão 4)

Destruição é **capacidade arquitetural, não feature obrigatória**. Escopo desta
fase do projeto:

- ✅ **Visual + iluminação** (barato, vem de graça da geometria de subcubos):
  remover um subcubo abre um caminho de luz, muda a sombra e a oclusão. Sem
  sistema especial de "buraco".
- ⏸️ **Furo que importa pro gameplay** (guard ver/atirar através) — **ADIADO**.
  Exige LOS na resolução de subcubo enquanto a *reação* do guard fica na unidade
  grossa ("testa fino → decide grosso"). É a costura cara; território de Infiltraitor 2.

### 9. Guardrails estéticos (do conceitual)

- O jogador **nunca percebe** os subcubos. Ele enxerga salas, corredores, portas,
  janelas, cobertura, altura — tiles limpos estilo XCOM/RTS isométrico.
- Sem geometria orgânica, sem voxel sim, sem destruição irrestrita.
- Mapas autorados em nível **semântico** (Sala, Corredor, Laboratório), expandidos
  pelo compilador. Nunca autorar ~20k subcubos à mão. (O `map_compiler.gd` já faz
  isso para o grid grosso.)
- Princípio mestre: **substituir conceitos especiais por regras gerais.**

---

## Constantes-chave

### Plano de gameplay (grid grosso — INALTERADO)

| Constante | Valor | Status | Arquivo |
|---|---|---|---|
| `CELL_SIZE` | `Vector2i(256, 128)` | **inalterado** | `room.gd` / TileSet |
| `MAP_SIZE` | `Vector2i(28, 46)` | **inalterado** | `room.gd` |
| `INNER_ORIGIN` | `Vector2i(5, 5)` | **inalterado** | `room.gd` |
| `BUFFER` | `5` | **inalterado** | `room.gd` |
| `AGENT_STEP_CELLS` | `1` | **inalterado** | `agent.gd` |
| TicSystem | por aresta | **inalterado** | `tic_system.gd` |
| vision / hearing / light / shadow ranges | `N` | **inalterado** | mapas |
| `WALL_FLOOR_STEP_PX` | `158.0` | **inalterado** (= step de 1 storey) | `room.gd` |

### Plano de geometria / render (grid fino — NOVO)

| Constante | Valor | Arquivo |
|---|---|---|
| `SUBCUBE_SIZE` | `Vector2i(64, 32)` | módulo de geometria + TileSet de render |
| `SUBCUBES_PER_FLOOR` | `4` | render layer |
| `SUBCUBE_STEP_PX` | `39.5` (= step por subcubo) | render layer |
| `MAX_SUBCUBES` | `28` | render layer |
| Razão `unit→subcube` | `×4` linear | conversão na costura |

> **Storey × subcubo:** 1 storey = `SUBCUBES_PER_FLOOR × SUBCUBE_STEP_PX` =
> `4 × 39.5` = `158px` = `WALL_FLOOR_STEP_PX`. O total em pixels na tela é o mesmo
> de hoje — o visual não muda, só nasce um grid fino *embaixo*. Como
> `WALL_FLOOR_STEP_PX` mantém o significado de "step de storey", o bug de
> `ceiling_lift`/`fixture_lift` (achado na auditoria) **não se manifesta** nesta
> arquitetura (ver Notas de Risco).

---

## Assets (parqueado — referência)

> Mantido como referência. Será revisado quando o atlas pré-fabricado entrar.

### Naming Convention

```
[tipo]_[material]   → atom direcional-agnostic  (subcube_concrete.png)
[shape]_[material]  → composto pré-renderizado   (wall_concrete.png)
[tipo]_authored     → art do diretor             (door_frame_steel.png)
```

- `subcube_*` — cubo 1×1×1, canvas 64×64, 3 faces flat-lit
- `floor_*` — diamond flat, canvas 64×64, só face top
- `block_*` — equivalente ao subcube, geometria de bloco sólido
- Materiais iniciais: `concrete`, `stone`, `wood`, `metal`

### Compositor PIL — Fórmulas Canônicas

Atom `64×64`. Âncora = bW do floor diamond = pixel `(0, 48)`. Canvas composto `256×512`.

```python
# NW wall (corre bW→bN do tile, runs NE na tela)
dest(u, h) = (u * 32,  400 - u * 16 - h * 32)
#   u = coluna ao longo da parede (0=esq, 3=dir); h = altura em subcubos (0=base)
#   painter's order: u decrescente (3→0), h crescente (0→N)

dest_SE(u, h)  = (u * 32,  400 + u * 16 - h * 32)            # SE wall (espelho)
dest_floor(u,v)= (u*32 + v*32,  400 - u*16 + v*16)           # Floor 4×4 (v 3→0, u 0→3)
dest_block     = (0, 400)                                     # Block 1×1×1 (atom único)
```

### Geometria do átomo (subcube, canvas 64×64)

```python
# Floor diamond (NÃO desenhado — transparente para empilhamento)
bN=(32,32); bE=(64,48); bS=(32,64); bW=(0,48)
# Top face (elevada 32px)
tN=(32,0); tE=(64,16); tS=(32,32); tW=(0,16)
# Faces em painter's order: left, right, top
```

---

## Fases de Implementação

### ✅ FASE 0-ALPHA — Átomos e compositor (CONCLUÍDA)

- [x] `generate_subcube.py` — 4 materiais × canvas 64×64
- [x] `generate_wall.py` — NW wall compositor com offsets corretos

### 🅿️ Pipeline de assets (antiga FASE 0 / SUB-00-B…E) — PARQUEADO

Será reescrito em torno do atlas de cubos pré-fabricados. Mantém-se vivo apenas o
**unblock mínimo** (corrigir `OUTPUT_DIR` → `source_assets/`, rebuild, confirmar
`subcube_*` no registry) como pré-requisito do render layer.

### ❌ FASE 1 — Grid Migration (GRID-01-A…D) — REMOVIDA

O modelo de dois níveis elimina a migração de grid. O gameplay permanece em
`256×128`. **Não** há mudança de `CELL_SIZE`, `MAP_SIZE`, `AGENT_STEP_CELLS`, nem
×4 de coordenadas/ranges, nem retuning do TicSystem.

---

### 🎯 FASE A — Camada de coordenadas + costura (NOVO — foco atual)

#### COORD-01-A — Módulo de conversão `unit ↔ subcube`

Introduzir `SUBCUBE_SIZE = Vector2i(64, 32)` e helpers puros:
`unit_to_subcube_origin(unit) -> Vector2i` (×4) e `subcube_to_unit(sub) -> Vector2i`
(÷4). Sem tocar no plano de gameplay. Acceptance: round-trip exato; testes de
borda (off-by-one nas conversões).

#### COORD-01-B — `map_compiler.gd` emite geometria de subcubos

A costura: a partir das Gameplay Units (paredes/floors/blocks já compilados),
gerar a geometria de subcubos consumida pelo render layer. Acceptance: uma unit
de parede vira `4×4` subcubos na borda correta; floor vira `4×4` subcubos de piso.

### 🎯 FASE B — Subcube Render Layers (era FASE 2)

#### SUB-01-A — `_ensure_subcube_layers`

```gdscript
const SUBCUBE_STEP_PX: float = 39.5   # step por subcubo
var _subcube_layers: Array[TileMapLayer] = []
# substitui _ensure_wall_upper_layers; itera subcubos (não storeys)
# layer.position.y = -SUBCUBE_STEP_PX * nivel_subcubo
```

#### SUB-01-B — render consome a geometria da costura

Cada subcubo de parede/bloco da geometria (COORD-01-B) → `subcube_[material]` no
layer de altura correspondente. O plano de gameplay segue com `blocked_edges`
(a aresta continua bloqueada; só a *geometria* é subcubo).

### 🎯 FASE C — Oclusão por deleção (SUBSTITUI a antiga FASE 3 dither)

#### SUB-02-A — `SubcubePresenceController`

Operação única `set_subcube(célula, nível) → presente/vazio; dispara re-light`.
Base de oclusão **e** destruição.

#### SUB-02-B — Oclusão dirigida pela câmera

Zona analítica de `_active_perspective` + `agent.cell` (células frontais). Para
cada parede oclusora: apagar subcubos `h ≥ base_kept`, manter o toco. Reversível
ao sair da frente. `base_kept` é tunável (default: fileira `h=0`).

#### SUB-02-C — Agent z-priority

`z_index` acima do topo do stack de subcubos. Sempre visível.

> Removido do plano antigo: `wall_dither.gdshader` e o tween de alpha por subcubo.

### FASE D — Face Lighting (era FASE 4)

#### SUB-03-A — `FaceLightingController` per-layer (fast mode)
`layer.modulate` por altura e posição das luzes. Gradiente vertical emergente.
Conectado a `lighting_rebuilt`.

#### SUB-03-B — Per-tile precision mode
Luzes com `distância < PRECISION_RADIUS` → overlay multiply-blend por subcubo.

### FASE E — Vertical Scene (era FASE 5)

#### SUB-04-A — Altura em subcubos
Geometria de parede em `wall_subcubes` (subcubos), não `wall_height` (storeys).
Retrocompatível: `wall_subcubes = wall_height × SUBCUBES_PER_FLOOR`.

#### SUB-04-B — Mapas com paredes altas
SIGMA-01 e Playground com paredes de 12 subcubos (3 andares).

### FASE F — Destruição como capacidade (NOVO — escopo §8)

Reusa `SubcubePresenceController` (SUB-02-A): destruição = `set_subcube(...) → vazio`
permanente, dirigido por evento. Escopo **visual + iluminação apenas**. Furo que
afeta gameplay LOS fica adiado.

### FASE G — Sistema de Paletas (futuro — era FASE 6)

`generate_variants.py` — troca `(flat, edge, grid)` via config JSON. N variações
sem retrabalho de geometria. Encaixa no fluxo do atlas pré-fabricado.

---

## Dependências

```
COORD-01-A → COORD-01-B → SUB-01-A → SUB-01-B
                                          │
                              ┌───────────┼───────────┐
                              ▼           ▼           ▼
                          SUB-02-A     SUB-03-A     SUB-04-A
                          SUB-02-B     SUB-03-B     SUB-04-B
                          SUB-02-C
                              │
                              ▼
                          FASE F (destruição visual)

Pré-requisito transversal: unblock mínimo de assets (subcube_* no registry).
Paralelo/futuro: 🅿️ reescrita do pipeline (atlas) · FASE G (paletas).
```

---

## O que NÃO muda (o ganho principal)

Com o modelo de dois níveis, esta tabela passa a ser **literalmente verdadeira** —
não "mesma lógica com inputs ×4", e sim zero mudança.

| Sistema | Status |
|---|---|
| LOS de gameplay (guard → reação) | ✅ Zero mudança (grid grosso) |
| A\* pathfinding | ✅ Zero mudança — ~1.288 nós (risco de device resolvido) |
| Guard FSM | ✅ Zero mudança |
| TicSystem | ✅ Zero mudança — segue por aresta |
| `blocked_edges` / `blocked_cells` | ✅ Zero mudança |
| Movimento do agente | ✅ Zero mudança |
| Alarmes / triggers / missão | ✅ Zero mudança |
| Sistema de perspectiva 4-dir | ✅ Zero mudança |
| Shader de FOW | ✅ Zero mudança |
| Coordenadas dos mapas | ✅ Zero mudança (sem ×4) |
| **Novo:** LOS de luz / oclusão / sombra | 🎯 Em resolução de subcubo (plano de render) |

---

## Notas de Risco

**Costura `unit ↔ subcube`:** fronteiras geram off-by-one e arredondamento ("em
qual subcubo o agente está, se ele ocupa 4×4?"). Concentrar toda conversão em
COORD-01-A com testes de round-trip. É a maior fonte de bug nova.

**Resolução de LOS dividida:** visual/luz na resolução fina, decisão/reação na
grossa. Separação limpa (testa fino → decide grosso), mas é onde mora a maior
parte do trabalho real do plano de render.

**`WALL_FLOOR_STEP_PX` (RESOLVIDO):** ao manter o significado de "step de storey"
(158px) no plano de gameplay e introduzir `SUBCUBE_STEP_PX` (39.5px) separado no
render, os sites de `ceiling_lift`/`fixture_lift` continuam corretos. O bug de
sub-elevação só existia no plano unificado (que repurava a constante para 39.5).

**A\* 20k nós (RESOLVIDO):** A\* roda no grid grosso. O profiling no device deixa
de ser portão.

**TicSystem 4 crossings (REMOVIDO):** tic segue por aresta; sem retuning de
probabilidade.

---

## Questões em Aberto

- `base_kept` da oclusão: quantas fileiras de subcubo manter no toco (1? 2?) — art director.
- Material default do SIGMA-01 (plano presume `concrete`).
- Momento de des-parquear o pipeline de assets e desenhar o atlas pré-fabricado.

---

**Status:** 🟢 Decisões da sessão 4 registradas · Próximo: prompt de reconciliação
da documentação do projeto, depois início da implementação (COORD-01-A).
