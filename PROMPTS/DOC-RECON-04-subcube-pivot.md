# DOC-RECON-04 — Reconciliar documentação à arquitetura de dois níveis (subcube)

> **Pré-requisito:** a revisão de sessão 4 do `PROMPTS/SUBCUBE_MASTER_PLAN.md`
> (dois níveis + oclusão por deleção) já está no lugar. Ela é a fonte de verdade.
> **Natureza:** docs-only. Nenhuma alteração de código. Edição cirúrgica.

---

## CONTEXT

A sessão 4 reverteu duas decisões antigas que ainda vivem na documentação:

1. **Grid unificado → dois níveis.** O subcubo **não** é mais o tile de gameplay.
   O gameplay continua no grid grosso (`256×128`, inalterado); a geometria de
   subcubos (`64×32`, 4×4 por unidade) é um plano de render aditivo. Não há
   migração ×4, não há `GRID-01`.
2. **Oclusão por fade/dither → oclusão por deleção.** O sistema de oclusão de
   parede deixa de "esmaecer" (Bayer dither / alpha fade) e passa a **apagar os
   subcubos das fileiras superiores, mantendo um toco na base**. Oclusão e
   destruição viram a **mesma operação** (`set_subcube → vazio; re-light`). O
   `wall_dither.gdshader` e o tween de alpha por subcubo saem do plano.

Duas docs de produção/sistemas ainda descrevem a oclusão pelo princípio antigo
(**"fade, never delete"**, **"dither-cutout"**). Esta tarefa alinha essas docs
ao plano novo e adiciona pointers à fonte de verdade. **Não** reescreve o que já
está correto (o gameplay-plane não mudou).

---

## MODULE

Docs apenas. Arquivos **no escopo**:

- `PROMPTS/SUBCUBE_MASTER_PLAN.md` — fonte de verdade (**referência, não editar**)
- `docs/systems/rendering.md` — seção de *view occlusion* (~linhas 291–303)
- `docs/production/milestones.md` — milestone **VIS-01**
- `docs/ARCHITECTURE.md` — adicionar pointer (subsection curta)

---

## TASK

### 1. `docs/systems/rendering.md` — seção *view occlusion* (~linhas 291–303)

Localizar o bloco que hoje diz:

- `Two pillars sharing one fade machine:`
- `(2) proximity dither-cutout around the …`
- `Principle: **fade, never delete** — cut walls must still read as cover.`

Reescrever para o modelo de deleção, mantendo o resto da seção:

- Trocar **"one fade machine"** por **"one subcube-presence operation
  (`set_subcube → empty; re-light`)"**.
- Trocar **"proximity dither-cutout"** por **"proximity cutaway — delete the
  upper subcubes around the agent"** (remover qualquer menção a dither/shader de
  dither nesta seção).
- Trocar o princípio **"fade, never delete"** por:
  > **Principle: delete the upper subcubes of occluding walls and keep a base
  > stub (default: the `h=0` row), so cut walls still read as cover. Occlusion
  > and destruction share one operation. No dither, no alpha fade.**
- Adicionar, no fim da seção, um pointer:
  > Canonical model: `PROMPTS/SUBCUBE_MASTER_PLAN.md` §7 (occlusion = deletion).

> ⚠️ Não mexer em outros usos de "fade" no `rendering.md` (FOW, transições etc.).
> Só o bloco de *view occlusion* acima.

### 2. `docs/production/milestones.md` — milestone **VIS-01**

VIS-01 segue sendo a prioridade visual; só muda o **mecanismo** de oclusão (a UX
é a mesma). Atualizar os sub-itens da oclusão:

- **"directional storey cutaway — fade/lower the camera-facing …"**
  → **"directional storey cutaway — delete the camera-facing upper subcubes,
  keep a base stub"** (remover "fade/lower").
- **"proximity cutout — dither-circle shader around the agent …"**
  → **"proximity cutout — delete upper subcubes in a radius around the agent"**
  (remover o "dither-circle shader").
- **"hover reveal — hovering a tile behind a wall fades that …"**
  → **"hover reveal — hovering a tile behind a wall deletes that wall's upper
  subcubes"** (trocar "fades" por "deletes").
- Adicionar uma linha curta no corpo do VIS-01:
  > Occlusion and destruction are the same operation (`set_subcube → empty`);
  > occlusion is the reversible, camera-driven case. See
  > `PROMPTS/SUBCUBE_MASTER_PLAN.md` §7–8.
- Adicionar, onde o VIS-01 descreve o "visual system", a equivalência de
  nomenclatura:
  > VIS-01's visual engine maps to the Master Plan's FASE A–C
  > (COORD-01 → SUB-01 render layers → SUB-02 occlusion-by-deletion).

> Não mexer na priorização do VIS-01 nem em outros milestones. Não tocar em
> "fade" fora dos três sub-itens de oclusão acima.

### 3. `docs/ARCHITECTURE.md` — pointer de dois níveis

O conteúdo atual descreve o gameplay-plane e **continua válido** (não reescrever).
Adicionar **uma subsection curta** (perto do topo, após a visão geral) declarando
o modelo de dois níveis:

> ### Subcube render plane (planned)
> The engine uses two coordinate spaces. The **gameplay plane** (this document,
> `CELL_SIZE 256×128`) is unchanged — guard AI, A\*, `blocked_*`, TicSystem,
> alarms, triggers, movement. A planned **geometry/render plane** (`SUBCUBE_SIZE
> 64×32`, 4×4 subcubes per gameplay unit) adds subcube stacking, face lighting,
> occlusion-by-deletion, and dynamic geometry. Conversions happen only at the
> seam (`map_compiler.gd`). Canonical spec: `PROMPTS/SUBCUBE_MASTER_PLAN.md`.

---

## DO NOT TOUCH

- **Código.** Esta tarefa é só docs.
- `docs/systems/lighting.md`, `docs/pipelines/lighting_authoring_pipeline.md` —
  **corretas**. Descrevem o pipeline tile-based atual ("no sub-tile precision",
  grid `28×46 = 1.288 tiles`), que o modelo de dois níveis mantém.
- `docs/systems/occlusion.md` — é *occlusion semantics* de gameplay (o que bloqueia
  luz/LoS/som). **Inalterado** no modelo de dois níveis.
- `docs/technical/ASSET_MAP.md`, `tools/README.md` — pipeline de assets, **parqueado**.
- Débito de documentação **pré-existente** (fora de escopo desta tarefa):
  - o índice em `docs/README.md` aponta para um `technical/architecture.md` "(to be created)" enquanto existe um `docs/ARCHITECTURE.md` — não resolver aqui;
  - `current_state.md` descrevendo detecção como binária (é escalonada);
  - context files que omitem `controllers/`.

---

## ACCEPTANCE (grep-based)

**Devem retornar ZERO** (princípio antigo eliminado das duas docs de engine visual):

```bash
grep -rniE 'fade, never delete|dither-cutout|dither-circle|one fade machine' \
  docs/systems/rendering.md docs/production/milestones.md
```

**Devem retornar match** (modelo de deleção presente):

```bash
grep -niE 'delete the upper subcubes|keep a base stub' docs/systems/rendering.md
grep -niE 'delete the camera-facing upper subcubes|deletes that wall' docs/production/milestones.md
```

**Pointer à fonte de verdade nas três docs:**

```bash
grep -lE 'SUBCUBE_MASTER_PLAN' \
  docs/systems/rendering.md docs/production/milestones.md docs/ARCHITECTURE.md
# espera-se: os 3 arquivos
```

**Pointer de dois níveis no ARCHITECTURE.md:**

```bash
grep -niE 'render plane|two coordinate spaces|SUBCUBE_SIZE 64×32' docs/ARCHITECTURE.md
```

**Sanidade — não matou "fade"/"dither" legítimos:** confirmar que `rendering.md` e
`milestones.md` ainda contêm os usos não-relacionados de "fade" (FOW, transições)
que existiam antes — apenas os do bloco de view-occlusion foram trocados.

---

**Escopo:** 3 arquivos · docs-only · 1 sessão. Sem código, sem assets, sem grid.
