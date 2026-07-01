# VOXEL-01 — `generate_voxel.py`: Gerador de átomo voxel (32×36 px)

> **Série:** VOXEL · **Prompt:** 01 de 11
> **Depende de:** VOXEL-00 (docs aprovados) ✅
> **Desbloqueia:** VOXEL-02 (TileSet + constantes)
> **Natureza:** 1 arquivo Python NOVO + 4 PNGs gerados. Não toca em nada existente.

---

## CONTEXT

O sistema WallContainer (CONTAINER-01..04, `Image.blend_rect`) está arquivado.
O novo sistema de Voxels renderiza paredes via `TileMapLayer.set_cell()`.
**1 VOXEL = 1 Godot Tile** com `tile_size = Vector2i(32, 16)`.

Este prompt cria o gerador Python do átomo voxel — único source-of-truth para a
textura 32×36 px usada em `tileset_voxels.tres`. Geometria canônica:

```
TILE_W  = 32   ← largura do tile (VOXEL_TILE_SIZE.x)
TILE_H  = 16   ← altura do tile  (VOXEL_TILE_SIZE.y)
SIDE_H  = 20   ← face lateral    (1.25 × TILE_H)
TOTAL_H = 36   ← TILE_H + SIDE_H = altura total do PNG
```

```
y= 0 ┌────────────────┐
     │   FACE TOPO    │  16 px — diamante isométrico 32×16
     │ N=(16,0) E=(32,8) S=(16,16) W=(0,8)
y=16 ├────────────────┤
     │   FACE LATERAL │  20 px — retângulo 32×20
     │   (darken 80%) │
y=36 └────────────────┘
```

Referências (ler antes de começar):
- `docs/technical/VOXEL_MASTER_PLAN.md` §3 e §11 (geometria + pipeline de assets)
- `tools/persistent/OPERATOR_CONTEXT.md` → secção "Voxel Asset Pipeline"

Pre-flight:
```bash
git status   # deve estar limpo antes de começar
```

---

## MODULE

**Arquivo novo:** `tools/asset_generation/generate_voxel.py`
**Output dir:** `ASSETS/ISOMETRIC/source_assets/voxels/` (criar se não existir)

Nenhum arquivo existente é modificado por este prompt.

---

## TASK

### 1. Criar `tools/asset_generation/generate_voxel.py`

Usar `create_file`. Conteúdo exato:

```python
#!/usr/bin/env python3
"""
generate_voxel.py — INFILTRAITOR Voxel Atom Generator
======================================================
Gera um PNG 32×36 px por material (átomo de voxel para tileset_voxels.tres).

Executar da raiz do projeto:
    python3 tools/asset_generation/generate_voxel.py

Output: ASSETS/ISOMETRIC/source_assets/voxels/voxel_{material}.png

GEOMETRY (deve coincidir com subcube_coords.gd após VOXEL-02):
    TILE_W  = 32   VOXEL_TILE_SIZE.x
    TILE_H  = 16   VOXEL_TILE_SIZE.y
    SIDE_H  = 20   1.25 × TILE_H  →  VOXEL_STEP_PX = 20
    TOTAL_H = 36   TILE_H + SIDE_H

Face topo  (y=0..15) : diamante isométrico
    N=(16, 0)  E=(32, 8)  S=(16, 16)  W=(0, 8)
Face lateral (y=16..35): retângulo 32×20, darken 80%

Flat-lit: sem shading direcional baked — BakeSystem aplica textura em load-time.
Sem outline: voxels do mesmo material fundem numa superfície de parede contínua.
"""

from __future__ import annotations
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow não instalado. Execute: pip install Pillow")

# ---------------------------------------------------------------------------
# Geometria — deve coincidir com VOXEL_* em subcube_coords.gd (VOXEL-02)
# ---------------------------------------------------------------------------
TILE_W  = 32
TILE_H  = 16
SIDE_H  = 20        # 1.25 × TILE_H → VOXEL_STEP_PX
TOTAL_H = TILE_H + SIDE_H   # 36

# Vértices da face topo (diamante isométrico 32×16)
V_N = (TILE_W // 2,  0)
V_E = (TILE_W,       TILE_H // 2)
V_S = (TILE_W // 2,  TILE_H)
V_W = (0,            TILE_H // 2)

SIDE_DARKEN: float = 0.80   # face lateral = 80% da cor base

# ---------------------------------------------------------------------------
# Paleta de materiais — (R, G, B) base, flat-lit
# ---------------------------------------------------------------------------
MATERIALS: dict[str, tuple[int, int, int]] = {
    "concrete": (175, 170, 162),
    "metal":    (138, 148, 158),
    "stone":    (155, 150, 143),
    "wood":     (178, 138,  88),
}

# ---------------------------------------------------------------------------
# Output (relativo à raiz do projecto)
# ---------------------------------------------------------------------------
OUTPUT_DIR = Path("ASSETS/ISOMETRIC/source_assets/voxels")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _rgba(rgb: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], alpha)


def _darken(rgb: tuple[int, int, int], factor: float) -> tuple[int, int, int, int]:
    return (
        max(0, int(rgb[0] * factor)),
        max(0, int(rgb[1] * factor)),
        max(0, int(rgb[2] * factor)),
        255,
    )


# ---------------------------------------------------------------------------
# Gerador principal
# ---------------------------------------------------------------------------

def generate_voxel_atom(base_color: tuple[int, int, int]) -> Image.Image:
    """
    Retorna um Image RGBA 32×36 px com:
      y=[0..15]  face topo  — diamante isométrico, cor base
      y=[16..35] face lateral — retângulo, 80% da cor base
    """
    img  = Image.new("RGBA", (TILE_W, TOTAL_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Face topo: diamante isométrico
    draw.polygon([V_N, V_E, V_S, V_W], fill=_rgba(base_color))

    # Face lateral: retângulo imediatamente abaixo da face topo
    # rectangle([x0, y0, x1, y1]) — coordenadas inclusivas em PIL
    draw.rectangle(
        [0, TILE_H, TILE_W - 1, TOTAL_H - 1],
        fill=_darken(base_color, SIDE_DARKEN),
    )

    return img


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for material, base_color in MATERIALS.items():
        img  = generate_voxel_atom(base_color)
        path = OUTPUT_DIR / f"voxel_{material}.png"
        img.save(path, "PNG")
        print(f"  ✓ {path}  ({img.size[0]}×{img.size[1]} px, {img.mode})")

    print(f"\n✓ {len(MATERIALS)} voxel atom(s) → {OUTPUT_DIR}/")
    print("Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes em subcube_coords.gd")


if __name__ == "__main__":
    main()
```

### 2. Executar o script

```bash
python3 tools/asset_generation/generate_voxel.py
```

Output esperado (4 linhas + resumo):
```
  ✓ ASSETS/ISOMETRIC/source_assets/voxels/voxel_concrete.png  (32×36 px, RGBA)
  ✓ ASSETS/ISOMETRIC/source_assets/voxels/voxel_metal.png  (32×36 px, RGBA)
  ✓ ASSETS/ISOMETRIC/source_assets/voxels/voxel_stone.png  (32×36 px, RGBA)
  ✓ ASSETS/ISOMETRIC/source_assets/voxels/voxel_wood.png  (32×36 px, RGBA)

✓ 4 voxel atom(s) → ASSETS/ISOMETRIC/source_assets/voxels/
Próximo: VOXEL-02 — criar tileset_voxels.tres + constantes em subcube_coords.gd
```

Se `ModuleNotFoundError: PIL`, instalar com `pip install Pillow` e repetir.

---

## DO NOT TOUCH

- Qualquer arquivo existente em `tools/asset_generation/` — não modificar nenhum
- `ASSETS/ISOMETRIC/source_assets/generated/` — assets de floor/block intocados
- `ASSETS/ISOMETRIC/source_assets/subcubes/` — arquivado; não apagar, não modificar
- Qualquer `.tres`, `.gd`, ou `.tscn`
- `tileset_blocks.tres`

---

## ACCEPTANCE

Executar cada verificação. Todas devem passar antes de mover para DONE.

**A1 — Script existe:**
```bash
test -f tools/asset_generation/generate_voxel.py && echo PASS || echo FAIL
```

**A2 — Constantes de geometria corretas (4 linhas esperadas):**
```bash
grep -cE "TILE_W\s*=\s*32|TILE_H\s*=\s*16|SIDE_H\s*=\s*20|TOTAL_H\s*=\s*36" \
    tools/asset_generation/generate_voxel.py
# Expected: 4
```

**A3 — Quatro materiais presentes:**
```bash
grep -cE '"concrete"|"metal"|"stone"|"wood"' \
    tools/asset_generation/generate_voxel.py
# Expected: 4
```

**A4 — Sem referências ao sistema arquivado:**
```bash
grep -Ec "subcube|blend_rect|WallContainer|FACE_CENTER_OFFSET|is_x_varying|generate_wall" \
    tools/asset_generation/generate_voxel.py
# Expected: 0
```

**A5 — Dimensões e modo corretos dos 4 PNGs:**
```bash
python3 - << 'EOF'
from PIL import Image
import sys
errors = []
for mat in ["concrete", "metal", "stone", "wood"]:
    path = f"ASSETS/ISOMETRIC/source_assets/voxels/voxel_{mat}.png"
    try:
        img = Image.open(path)
    except FileNotFoundError:
        errors.append(f"MISSING: {path}")
        continue
    if img.size != (32, 36):
        errors.append(f"{path}: expected (32,36), got {img.size}")
    if img.mode != "RGBA":
        errors.append(f"{path}: expected RGBA, got {img.mode}")
if errors:
    print("FAIL")
    for e in errors:
        print(" ", e)
    sys.exit(1)
print("PASS — 4 PNGs 32×36 RGBA OK")
EOF
```

**A6 — Face lateral é 80% da face topo (verificação de pixel em concrete):**
```bash
python3 - << 'EOF'
from PIL import Image
img = Image.open("ASSETS/ISOMETRIC/source_assets/voxels/voxel_concrete.png")
px = img.load()
# Sample: ponto no centro da face topo (col=16, row=8) vs face lateral (col=16, row=24)
top_r, top_g, top_b, top_a  = px[16, 8]
side_r, side_g, side_b, side_a = px[16, 24]
assert top_a  == 255, f"top alpha={top_a}"
assert side_a == 255, f"side alpha={side_a}"
ratio_r = side_r / top_r if top_r else 1.0
ratio_g = side_g / top_g if top_g else 1.0
ratio_b = side_b / top_b if top_b else 1.0
avg = (ratio_r + ratio_g + ratio_b) / 3
assert 0.75 <= avg <= 0.85, f"darken ratio={avg:.3f} (expected ~0.80)"
print(f"PASS — darken ratio={avg:.3f}")
EOF
```

**A7 — Script é idempotente (re-executar não falha):**
```bash
python3 tools/asset_generation/generate_voxel.py && echo PASS
```

**A8 — Git status: só arquivos novos, nenhum tracked modificado:**
```bash
git status --short
# Expected: "??" entries apenas (untracked). Nenhuma linha com "M" ou "D".
```

---

## DONE CRITERIA

Todos os 8 checks de acceptance passam.
Mover este arquivo para `PROMPTS/DONE/VOXEL-01.md`.
