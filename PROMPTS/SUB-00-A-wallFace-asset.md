# INFILTRAITOR — SUB-00-A (revisão 3): Subcubo 1/4-tile + compositor corrigido
## Pipeline de assets — `generate_subcube.py` + `generate_wall.py`

**Data:** 2026-06-24 (revisão 3 — escala correta do átomo)
**Fase:** SUB-00 — Fundação de Assets

---

## PROBLEMA COM A VERSÃO ANTERIOR

O subcubo foi gerado com o footprint do tile inteiro (`TILE_HW=128, TILE_HH=64`).
4 subcubos empilhados = block 4× mais alto que um tile. Correto visualmente mas
errado de escala: o subcubo deve ser **1/4 do tile** para que:
- 4 subcubos lado a lado = 1 tile de largura
- 4 subcubos empilhados = 1 storey de altura

---

## ARQUIVOS A MODIFICAR
- `tools/asset_generation/generate_subcube.py` — escalar para 1/4 tile
- `tools/asset_generation/generate_wall.py` — corrigir offsets isométricos

---

## PASSO 1 — Corrigir `generate_subcube.py`

### Mudanças nas constantes geométricas

```python
# ANTES:
TILE_HW, TILE_HH = 128, 64
CUBE_HEIGHT       = 40

# DEPOIS:
TILE_HW, TILE_HH = 32, 16    # 1/4 do tile completo (256x128)
CUBE_HEIGHT       = 32        # proporção cúbica real (igual à do crate)
```

### Mudança no canvas

O cubo agora é pequeno. Em vez do canvas 256×512, usar um canvas **64×64**
que contém apenas o cubo. Isso simplifica os offsets no compositor.

```python
PNG_W, PNG_H = 64, 64
```

### Posicionamento no canvas 64×64

Com canvas 64×64, o cubo fica posicionado de forma que seu vértice frontal
inferior (tS) fique no centro-baixo do canvas:

```python
# Referência: bW do floor diamond fica em (0, 48) no canvas 64x64
# Vértices do floor diamond (NOT drawn):
bN = (32, 32)    # top  (bW.x + TILE_HW, bW.y - TILE_HH)
bE = (64, 48)    # right
bS = (32, 64)    # bottom (bW.x + TILE_HW, bW.y + TILE_HH)
bW = (0,  48)    # left — âncora do sistema de composição

# Topo (lifted by CUBE_HEIGHT=32):
tN = (32, 0)
tE = (64, 16)
tS = (32, 32)
tW = (0,  16)
```

### Código completo de `generate_subcube.py`

```python
"""generate_subcube.py — INFILTRAITOR 1/4-tile atomic subcube generator"""
from PIL import Image, ImageDraw
import os

BASE_PATH  = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/master_assets/subcubes")

PNG_W, PNG_H = 64, 64
TRANSPARENT  = (0, 0, 0, 0)

MATERIALS = [
    ("concrete", (195, 185, 170), (70,  62,  54)),
    ("stone",    (152, 148, 142), (55,  52,  48)),
    ("wood",     (175, 125,  72), (85,  50,  22)),
    ("metal",    (158, 164, 172), (58,  62,  68)),
]


def generate_subcube(material_name, color_flat, color_edge):
    canvas = Image.new("RGBA", (PNG_W, PNG_H), TRANSPARENT)
    draw   = ImageDraw.Draw(canvas)

    # Floor diamond (NOT drawn — stays transparent for stacking)
    bN = (32, 32); bE = (64, 48); bS = (32, 64); bW = (0, 48)

    # Top face (lifted by 32px)
    tN = (32, 0); tE = (64, 16); tS = (32, 32); tW = (0, 16)

    # Draw faces in painter's order
    draw.polygon([tW, tS, bS, bW], fill=color_flat, outline=color_edge, width=1)  # left
    draw.polygon([tS, tE, bE, bS], fill=color_flat, outline=color_edge, width=1)  # right
    draw.polygon([tN, tE, tS, tW], fill=color_flat, outline=color_edge, width=1)  # top

    # Re-stroke silhouette
    draw.line([tS, bS], fill=color_edge, width=2)
    draw.line([tW, tS], fill=color_edge, width=2)
    draw.line([tS, tE], fill=color_edge, width=2)

    return canvas


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for name, flat, edge in MATERIALS:
        path = os.path.join(OUTPUT_DIR, f"subcube_{name}.png")
        generate_subcube(name, flat, edge).save(path, "PNG")
        print(f"  ✓ subcube_{name}.png")
    print(f"\n✓ {len(MATERIALS)} subcube atoms → {OUTPUT_DIR}")
```

---

## PASSO 2 — Corrigir `generate_wall.py`

### Sistema de offsets isométricos

Com o átomo de 64×64px, a âncora de posicionamento é o vértice **bW** do
floor diamond, que fica em pixel **(0, 48)** dentro do canvas 64×64.

Para posicionar o bW de um subcubo em coordenada de tela **(Px, Py)**:
```python
dest = (Px - 0, Py - 48)  # = (Px, Py - 48)
```

**Passos isométricos por subcubo:**

A parede NW corre na direção NE (de bW até bN do tile). Mover ao longo da
parede = subir e ir para a direita em tela:
- Mover 1 coluna ao longo da parede (u+1): bW desloca **(+32, -16)**
- Subir 1 nível de altura (h+1): bW desloca **(0, -32)**

```
dest(u, h) = (u * 32,  400 - u * 16 - h * 32)
```

Verificação:
- (u=0, h=0): dest=(0,  400) → conteúdo em y∈[400,464] ✓ (base esquerda)
- (u=3, h=0): dest=(96, 352) → conteúdo em y∈[352,416] ✓ (base direita, mais alto)
- (u=0, h=3): dest=(0,  304) → conteúdo em y∈[304,368] ✓ (topo esquerdo)
- (u=3, h=3): dest=(96, 256) → conteúdo em y∈[256,320] ✓ (topo direito)

Tudo dentro de 256×512. Nenhuma coordenada negativa.

**Ordem do pintor:** coluna mais à direita primeiro (u=3→0), dentro de cada
coluna de baixo para cima (h=0→max). Subcubos à direita ficam ligeiramente
mais atrás na cena → devem ser desenhados primeiro.

### Código completo de `generate_wall.py`

```python
"""generate_wall.py — INFILTRAITOR wall compositor"""
from PIL import Image
import os, sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_subcube import generate_subcube, MATERIALS, TRANSPARENT

BASE_PATH  = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
OUTPUT_DIR = os.path.join(BASE_PATH, "ASSETS/ISOMETRIC/master_assets/walls_composed")

OUT_W, OUT_H = 256, 512

# Wall height presets (in subcubes). 4 subcubes = 1 storey.
WALL_PRESETS = {
    "wallFace": 1,
    "wallHalf": 2,
    "wall":     4,
}

N_COLS = 4  # subcubes per tile width (fixed: 4 × 32px = 128px = half-tile... hmm)


def generate_wall_shape(subcube_img, height_subcubes, n_cols=N_COLS):
    canvas = Image.new("RGBA", (OUT_W, OUT_H), TRANSPARENT)

    # Painter's order: rightmost column first (further from NW camera),
    # bottom-to-top within each column.
    for u in range(n_cols - 1, -1, -1):
        for h in range(height_subcubes):
            dest_x = u * 32
            dest_y = 400 - u * 16 - h * 32  # NW wall: right cols go UP (-16)
            canvas.alpha_composite(subcube_img, dest=(dest_x, dest_y))

    return canvas


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for mat_name, flat, edge in MATERIALS:
        subcube = generate_subcube(mat_name, flat, edge)
        for preset_name, height in WALL_PRESETS.items():
            out_name = f"{preset_name}_{mat_name}.png"
            out_path = os.path.join(OUTPUT_DIR, out_name)
            generate_wall_shape(subcube, height).save(out_path, "PNG")
            print(f"  ✓ {out_name}")

    total = len(MATERIALS) * len(WALL_PRESETS)
    print(f"\n✓ {total} wall PNGs → {OUTPUT_DIR}")
```

---

## PASSO 3 — Rodar

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
python3 tools/asset_generation/generate_subcube.py
python3 tools/asset_generation/generate_wall.py
```

---

## ACCEPTANCE TESTS

**Teste 1 — Escala visual do átomo:**
Abrir `subcube_concrete.png` (64×64). Deve mostrar um cubo pequeno ocupando
todo o canvas — cubo proporcional (igual largura e altura visíveis).

**Teste 2 — Stacking correto:**
Abrir `wallFace_concrete.png` e `wall_concrete.png` lado a lado.
- [ ] `wallFace_concrete.png`: 1 subcubo, alinhado ao canto inferior-direito
- [ ] `wallHalf_concrete.png`: 2 subcubos — borda horizontal visível entre eles
- [ ] `wall_concrete.png`: 4 colunas × 4 filas de subcubos formando uma parede
      isométrica — parallelogram que vai de canto inferior-direito para superior-esquerdo

**Teste 3 — Alinhamento de bordas:**
No `wall_concrete.png`, as bordas entre subcubos devem ser contínuas —
nenhum gap nem overlap visível nas juntas horizontais ou verticais.

**Teste 4 — Alpha correto:**
```bash
python3 -c "
from PIL import Image
img = Image.open('ASSETS/ISOMETRIC/master_assets/subcubes/subcube_concrete.png')
assert img.mode == 'RGBA'
# Floor diamond area deve ser transparente: pixel no centro do diamond (32, 56)
px = img.getpixel((32, 56))
assert px[3] == 0, f'Floor não é transparente: {px}'
print('✓ Alpha correto')
"
```

---

## NOTAS PARA O OPERADOR

1. **4 colunas cobre a borda NW do tile** — a parede NW vai de bW até bN do
   diamond, que é metade do tile em x (0 a 128px). O canvas de saída 256×512
   terá conteúdo visível de x=0 a x≈160, com o lado direito transparente. Isso
   é correto — o sistema de edge-alignment do Godot cuida do posicionamento exato.

2. **Canvas do átomo é 64×64**, não 256×512. O compositor usa 256×512 para output.

3. **Não gerar floor agora.** O gerador de floor (grid 4×4 de subcubos vistos
   de cima) tem offsets diferentes e será o próximo prompt (SUB-00-C).
