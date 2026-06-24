# INFILTRAITOR — SUB-00-A: Fix geradores + gerar `wallFace`
## Pipeline de assets — `generate_master_walls.py`

**Data:** 2026-06-24
**Fase:** SUB-00 — Fundação de Assets
**Prioridade:** 1 (bloqueador de todas as fases seguintes)

---

## ARQUIVOS A MODIFICAR
- `tools/asset_generation/generate_master_walls.py`

## ARQUIVOS QUE NÃO DEVEM SER TOCADOS
Todos os outros. Em especial: nenhum arquivo `.gd`, nenhum outro gerador,
nenhum arquivo de tileset. O rebuild do tileset acontece no SUB-00-B.

---

## CONTEXTO

Três mudanças precisas em `generate_master_walls.py`:

1. **Fix `_draw_top`:** a face superior do slab não tem linhas de coluna.
   `_draw_front` tem `HCUBES` colunas — `_draw_top` deve ter as mesmas.

2. **Fix `_draw_end`:** a face lateral câmera-visível não tem linhas de banda
   horizontal. `_draw_front` tem `vcubes` bandas — `_draw_end` deve ter as
   mesmas. A função precisa receber `vcubes` como parâmetro.
   Colunas ao longo da profundidade (32px) **não são adicionadas** — 32px / 4
   = 8px por coluna, ilegível em mobile.

3. **Adicionar `wallFace`:** tile atômico de 1-subcubo (40px, 1 banda).
   **Não alterar `OUTPUT_DIR` agora** — o SUB-00-B reorganiza as pastas.

Os fixes afetam todos os assets gerados (`wall_*`, `wallHalf_*`, `wallFace_*`).
Isso é correto e esperado.

---

## PASSO 1 — Fix `_draw_top`

Localizar `_draw_top` (linha ~132). Corpo atual:

```python
def _draw_top(draw, tL, tR, offset):
    """Thin top face showing slab thickness from above."""
    tL_back = _add(tL, offset)
    tR_back = _add(tR, offset)
    draw.polygon([tL, tR, tR_back, tL_back], fill=COLOR_FLAT, outline=COLOR_EDGE)
    draw.line([tL, tR],         fill=COLOR_EDGE, width=2)   # front top edge
    draw.line([tL, tL_back],    fill=COLOR_EDGE, width=1)
    draw.line([tR, tR_back],    fill=COLOR_EDGE, width=1)
    draw.line([tL_back, tR_back], fill=COLOR_EDGE, width=1)
```

Substituir pelo corpo corrigido — adicionar colunas ANTES do re-stroke:

```python
def _draw_top(draw, tL, tR, offset):
    """Thin top face showing slab thickness from above."""
    tL_back = _add(tL, offset)
    tR_back = _add(tR, offset)
    draw.polygon([tL, tR, tR_back, tL_back], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Column lines matching the front face (HCUBES subdivisions)
    for i in range(1, HCUBES):
        t = i / HCUBES
        draw.line([_lerp(tL, tR, t), _lerp(tL_back, tR_back, t)],
                  fill=COLOR_GRID, width=1)

    # Silhouette re-stroke (on top of grid lines)
    draw.line([tL, tR],           fill=COLOR_EDGE, width=2)   # front top edge
    draw.line([tL, tL_back],      fill=COLOR_EDGE, width=1)
    draw.line([tR, tR_back],      fill=COLOR_EDGE, width=1)
    draw.line([tL_back, tR_back], fill=COLOR_EDGE, width=1)
```

---

## PASSO 2 — Fix `_draw_end`

Localizar `_draw_end` (linha ~143). Corpo atual:

```python
def _draw_end(draw, t_tip, b_tip, offset):
    """Camera-visible end face of the slab (one narrow parallelogram)."""
    t_back = _add(t_tip, offset)
    b_back = _add(b_tip, offset)
    draw.polygon([t_tip, t_back, b_back, b_tip], fill=COLOR_FLAT, outline=COLOR_EDGE)
```

Substituir pela versão com parâmetro `vcubes` e bandas horizontais:

```python
def _draw_end(draw, t_tip, b_tip, offset, vcubes):
    """Camera-visible end face of the slab (one narrow parallelogram)."""
    t_back = _add(t_tip, offset)
    b_back = _add(b_tip, offset)
    draw.polygon([t_tip, t_back, b_back, b_tip], fill=COLOR_FLAT, outline=COLOR_EDGE)

    # Horizontal bands matching the front face (vcubes subdivisions)
    # No vertical columns — 32px depth is too narrow for readable subdivisions
    for i in range(1, vcubes):
        t = i / vcubes
        draw.line([_lerp(t_tip, b_tip, t), _lerp(t_back, b_back, t)],
                  fill=COLOR_GRID, width=1)

    # Silhouette re-stroke
    draw.line([t_tip, t_back],  fill=COLOR_EDGE, width=1)   # top edge
    draw.line([b_tip, b_back],  fill=COLOR_EDGE, width=1)   # bottom edge
    draw.line([t_tip, b_tip],   fill=COLOR_EDGE, width=1)   # front edge
    draw.line([t_back, b_back], fill=COLOR_EDGE, width=1)   # back edge
```

**Nota para `wallFace` (vcubes=1):** `range(1, 1)` é vazio — nenhuma banda
é desenhada, correto para um tile de 1 subcubo.

---

## PASSO 3 — Atualizar chamadas de `_draw_end` em `generate()`

Localizar a função `generate(base_name, wall_h, vcubes)`. Ela chama `_draw_end`
em dois lugares. Ambos precisam receber `vcubes`.

```python
# Ramo NW/SW — antes:
_draw_end(draw, _add(t_tip, offset), _add(b_tip, offset), neg)
# Depois:
_draw_end(draw, _add(t_tip, offset), _add(b_tip, offset), neg, vcubes)

# Ramo NE/SE — antes:
_draw_end(draw, t_tip, b_tip, offset)
# Depois:
_draw_end(draw, t_tip, b_tip, offset, vcubes)
```

Verificar com grep após editar:
```bash
grep -n "_draw_end" tools/asset_generation/generate_master_walls.py
```
Deve retornar exatamente 3 linhas: a definição e as 2 chamadas.

---

## PASSO 4 — Adicionar `wallFace` ao entry point

Localizar `if __name__ == "__main__":`. Substituir pelo bloco atualizado:

```python
if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("wall (160 px, 4 bands):")
    generate("wall", WALL_HEIGHT, VCUBES_FULL)

    print("wallHalf (80 px, 2 bands):")
    generate("wallHalf", HALF_HEIGHT, VCUBES_HALF)

    print("wallFace (40 px, 1 band — atomic subcube):")
    generate("wallFace", 40, 1)

    print("\n✓ Done — 12 master wall PNGs written to master_assets/walls/")
    print("  Note: tileset rebuild happens in SUB-00-B after folder reorganization.")
```

Corrigir também "5 bands" → "4 bands" no comentário de `wall` (era incorreto).

---

## PASSO 5 — Rodar o gerador

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
python3 tools/asset_generation/generate_master_walls.py
```

Output esperado:
```
wall (160 px, 4 bands):
  ✓ wall_NW.png  ✓ wall_NE.png  ✓ wall_SW.png  ✓ wall_SE.png
wallHalf (80 px, 2 bands):
  ✓ wallHalf_NW.png  ✓ wallHalf_NE.png  ✓ wallHalf_SW.png  ✓ wallHalf_SE.png
wallFace (40 px, 1 band — atomic subcube):
  ✓ wallFace_NW.png  ✓ wallFace_NE.png  ✓ wallFace_SW.png  ✓ wallFace_SE.png

✓ Done — 12 master wall PNGs written to master_assets/walls/
  Note: tileset rebuild happens in SUB-00-B after folder reorganization.
```

---

## ACCEPTANCE TESTS

**Teste 1 — wallFace PNGs gerados:**
```bash
ls ASSETS/ISOMETRIC/master_assets/walls/wallFace_*.png
```
Deve listar 4 arquivos: NE, NW, SE, SW.

**Teste 2 — Dimensões corretas:**
```bash
python3 -c "
from PIL import Image
import glob
for p in sorted(glob.glob('ASSETS/ISOMETRIC/master_assets/walls/wallFace_*.png')):
    img = Image.open(p)
    print(p.split('/')[-1], img.size)
"
```
Todos devem reportar `(256, 512)`.

**Teste 3 — Inspeção visual:**
Abrir `wall_NW.png` e `wallFace_NW.png` lado a lado e verificar:
- [ ] `wall_NW` face top: 4 linhas de coluna visíveis (fix de `_draw_top`)
- [ ] `wall_NW` face end: 3 bandas horizontais visíveis (fix de `_draw_end`)
- [ ] `wallFace_NW` face top: 4 linhas de coluna visíveis
- [ ] `wallFace_NW` face end: sem bandas internas (1 subcubo = correto)
- [ ] `wallFace_NW` face front: sem bandas internas, 4 colunas verticais

**Teste 4 — Grep confirma 3 referências a `_draw_end`:**
```bash
grep -n "_draw_end" tools/asset_generation/generate_master_walls.py
```
Deve retornar exatamente 3 linhas.

---

## NOTAS PARA O OPERADOR

1. **Não rodar `build_tileset.gd` neste passo.** O rebuild acontece no SUB-00-B
   após a reorganização de pastas e reescrita do build script.

2. **Os fixes afetam `wall_*` e `wallHalf_*` também.** Todos os PNGs serão
   regenerados com as correções — correto e esperado.

3. **`wallFace` com `vcubes=1`:** aparece como slab limpo sem bandas internas
   na face front e end — apenas arestas de contorno e 4 colunas na face top.
