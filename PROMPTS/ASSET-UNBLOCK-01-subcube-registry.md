# ASSET-UNBLOCK-01 — Registrar os átomos `subcube_*` no tileset

> **Objetivo:** destravar o pré-requisito de asset do SUB-01 — fazer os 4 átomos
> de subcubo aparecerem no `tile_registry.gd`. **Escopo mínimo.** Não é a reescrita
> do pipeline de assets (essa segue parqueada, rumo ao atlas pré-fabricado).
> **Ambiente:** roda na máquina do diretor (paths macOS, Godot.app, `ASSETS/` real).

---

## CONTEXT

O `build_tileset.gd` é single-source: escaneia `res://ASSETS/ISOMETRIC/source_assets/`
recursivamente e **auto-gera** `tileset_blocks.tres` + `tile_registry.gd`. Mas o
gerador de átomos escreve na pasta errada (`master_assets/subcubes`), que o builder
**não** lê — por isso o registry hoje tem a família de paredes antiga e **nenhum**
`subcube_*`. O SUB-01 (render layer) precisa desses tiles registrados.

Correção: apontar o gerador para `source_assets/`, regenerar os átomos, **importar**
e re-rodar o builder. Como os PNGs antigos continuam em `source_assets/`, o rebuild
mantém a família antiga e **adiciona** os `subcube_*` (sem regressão de tiles).

> O `texture_origin` dos átomos sairá calibrado para a escala antiga (offset −384,
> de PNG 512px). **Isso é esperado e irrelevante aqui** — posicionamento de subcubo
> na tela é trabalho do SUB-01. Este unblock só garante o nome→id no registry.

---

## MODULE

- `tools/asset_generation/generate_subcube.py` — corrigir `OUTPUT_DIR` (1 linha)
- (gerado) `godot/scripts/world/tile_registry.gd`, `godot/resources/tilesets/tileset_blocks.tres`

---

## TASK

### 1. Corrigir o `OUTPUT_DIR` do gerador de átomos

Em `tools/asset_generation/generate_subcube.py`, linha 6:

```python
# ANTES
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/master_assets/subcubes")
# DEPOIS
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/source_assets/subcubes")
```

### 2. Gerar os átomos

```bash
python3 tools/asset_generation/generate_subcube.py
# espera-se: 4 PNGs em ASSETS/ISOMETRIC/source_assets/subcubes/
#   subcube_concrete.png, subcube_stone.png, subcube_wood.png, subcube_metal.png
```

### 3. ⚠️ Importar os PNGs novos ANTES de buildar (passo obrigatório)

O builder usa `load(png)` — que retorna `null` para PNG não-importado, **pulando o
tile em silêncio**. Garanta a importação de uma das formas:

```bash
# opção A: abrir o editor uma vez (importa e pode fechar)
/Applications/Godot.app/Contents/MacOS/Godot --editor --path . 
# opção B (sem GUI): importar e sair
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Confirmar que existem `.import` para os novos PNGs (e os `.ctex` em `.godot/imported/`).

### 4. Re-rodar o builder (regenera tileset + registry)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script godot/scripts/tools/build_tileset.gd
# espera-se nos logs: "Found N PNG(s)" e "Saved registry → ..."; sem push_error.
```

---

## DO NOT TOUCH

- **`generate_wall.py` / modo composto.** Parqueado — o SUB-01 empilha átomos em
  runtime; não precisa dos walls pré-compostos. Não rodar, não corrigir.
- **`build_tileset.gd`** — não mexer em `CELL_SIZE`, `PNG_SIZE`, `SPRITE_OFFSET`,
  `_get_texture_origin`, nem nas tabelas de offset/edge. Posicionamento do átomo é
  do SUB-01. Mexer aqui arrisca quebrar o registro das paredes existentes.
- **Sem registro direcional** dos átomos. `subcube_concrete` (tile único) basta —
  o átomo é simétrico. Não criar `subcube_concrete_NE/NW/SE/SW`.
- **PNGs antigos em `source_assets/`** — deixar como estão (continuam registrados).
- **Sem wiring de código**, sem `room.gd`, sem render.

---

## ACCEPTANCE

### Gerador corrigido

```bash
grep -n 'source_assets/subcubes' tools/asset_generation/generate_subcube.py   # match
grep -n 'master_assets/subcubes' tools/asset_generation/generate_subcube.py   # VAZIO
```

### Átomos no registry (o gate)

```bash
grep -nE '"(subcube_concrete|subcube_stone|subcube_wood|subcube_metal)":' \
  godot/scripts/world/tile_registry.gd
# espera-se: as 4 linhas presentes
```

### Nenhuma regressão de tiles existentes

```bash
grep -nE '"(floor_SE|wall_NE|block_SE)":' godot/scripts/world/tile_registry.gd
# espera-se: ainda presentes (rebuild não dropou a família antiga)
```

### Sanidade visual (renumeração de source_id é segura)

O rebuild reordena os `source_id`. Como a colocação de tiles é em **runtime via
registry (nome→id)**, cenas existentes não quebram. Confirmar: abrir/rodar a
`room.tscn` uma vez e verificar que as paredes/piso existentes ainda renderizam
normalmente.

---

**Escopo:** 1 linha de código + gerar/importar/buildar · 1 sessão. Sem render, sem
átomo direcional, sem mexer no compositor ou nos offsets do builder.
