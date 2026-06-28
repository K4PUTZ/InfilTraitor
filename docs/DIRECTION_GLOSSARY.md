# INFILTRAITOR — Direction System Glossary

> **Status:** Canônico · Substitui toda documentação de direção derivada do sistema Kenney.
> **Escopo:** Nomenclatura de direções para código, assets, documentação e UI.

---

## 1. O Sistema de Coordenadas

O motor isométrico usa tile_size `(64, 32)` em layout **DIAMOND_DOWN**.
O grid de gameplay opera em coordenadas de tile `(col, row)`.
O grid de subcubos opera em resolução 4× (4 subcubos por eixo por tile).

A projeção em tela para a célula `(col, row)`:

```
screen_x = (col - row) × 32
screen_y = (col + row) × 16
```

---

## 2. O Compasso — Vértices N/E/S/W

O compasso é **alinhado por vértice**: cada ponto cardeal corresponde a um
vértice do diamante isométrico.

```
         N (↑)
        ╱   ╲
   NW ╱       ╲ NE
     ╱  TILE   ╲
W (←)   CENTER  (→) E
     ╲           ╱
   SW ╲         ╱ SE
        ╲     ╱
         S (↓)
```

| Ponto | Vértice do diamante | Posição em tela |
|-------|---------------------|-----------------|
| **N** | topo                | direto para cima `(0, -1)` |
| **E** | direita             | direto para a direita `(+1, 0)` |
| **S** | base                | direto para baixo `(0, +1)` |
| **W** | esquerda            | direto para a esquerda `(-1, 0)` |

---

## 3. As Quatro Faces de Parede — Arestas NW/NE/SW/SE

Paredes ficam nas **arestas** entre dois vértices adjacentes.
Cada face é nomeada pela aresta que ocupa:

```
         N
        ╱ ╲
     NW     NE
     ╱  tile ╲
    W         E
     ╲  tile ╱
     SW     SE
        ╲ ╱
         S
```

| Face | Aresta | `edge_delta` (tile) | Direção em tela | x-straddle |
|------|--------|---------------------|-----------------|------------|
| **NW** | entre N e W | `(-1, 0)` | cima-esquerda `(-32, -16)` | esquerda |
| **NE** | entre N e E | `(0, -1)` | cima-direita `(+32, -16)` | direita |
| **SE** | entre S e E | `(+1, 0)` | baixo-direita `(+32, +16)` | direita |
| **SW** | entre S e W | `(0, +1)` | baixo-esquerda `(-32, +16)` | esquerda |

**Invariante de simetria** — para qualquer ajuste de offset:

| Par | Relação |
|-----|---------|
| NW ↔ SE | x oposto, y oposto |
| NE ↔ SW | x oposto, y oposto |
| NW e SW | mesmo `|x|`, partilham o lado esquerdo |
| NE e SE | mesmo `|x|`, partilham o lado direito |

---

## 4. Mapeamento de Bordas do Room

No `map_geometry.gd`, cada borda do rect mapeia para uma face de parede:

| Condição em tile | Borda | Face emitida |
|------------------|-------|-------------|
| `cell.x == min_x` | coluna da esquerda | `wall_NW` |
| `cell.x == max_x` | coluna da direita | `wall_SE` |
| `cell.y == min_y` | linha do topo | `wall_NE` |
| `cell.y == max_y` | linha da base | `wall_SW` |

Portas seguem a mesma convenção: `doorOpen_NW`, `doorOpen_NE`, `doorOpen_SE`, `doorOpen_SW`.

---

## 5. FACE_CENTER_OFFSET — Sprite2D de WallContainer

Posição do centro do Sprite2D relativo a `map_to_local(face_subcells[0])`.
Derivado de: base vertical `(0, −20)` + straddle de meia-aresta de tile.

```gdscript
const FACE_CENTER_OFFSET: Dictionary = {
    "NW": Vector2(-16.0, -28.0),   ## cima-esquerda: straddle esquerda ✓
    "NE": Vector2( 16.0, -28.0),   ## cima-direita:  straddle direita  ✓
    "SE": Vector2( 16.0, -12.0),   ## baixo-direita: straddle direita  ✓
    "SW": Vector2(-16.0, -12.0),   ## baixo-esquerda: straddle esquerda ✓
}
```

**Dois parâmetros livres para calibração:**

| Parâmetro | Controle | Ajuste |
|-----------|----------|--------|
| `base_y` (atual `−20`) | altura vertical de todas as paredes | mesmo valor para os 4 |
| `|x|` (atual `16`) | largura do straddle lateral | NW/SW = `−|x|`, NE/SE = `+|x|` |

---

## 6. _EDGE_BY_SUFFIX — subcube_geometry.gd

```gdscript
const _EDGE_BY_SUFFIX: Dictionary = {
    "NW": [Vector2i(-1, 0)],   ## cima-esquerda
    "NE": [Vector2i( 0,-1)],   ## cima-direita
    "SE": [Vector2i( 1, 0)],   ## baixo-direita
    "SW": [Vector2i( 0, 1)],   ## baixo-esquerda
}
```

---

## 7. Tabela de Migração (sistema antigo → novo)

> Nota: o sistema antigo usava N=direita (convenção Kenney). O novo usa N=cima.
> Os VALUES dos offsets não mudam — apenas as KEYS dos dicionários.

| Antigo | Novo | edge_delta | Motivo |
|--------|------|------------|--------|
| `NW` | `NE` | `(0, -1)` | cima-direita em tela |
| `NE` | `SE` | `(+1, 0)` | baixo-direita em tela |
| `SE` | `SW` | `(0, +1)` | baixo-esquerda em tela |
| `SW` | `NW` | `(-1, 0)` | cima-esquerda em tela |

---

## 8. Compasso UI (compass_rose.gd)

O widget mostra os 4 pontos cardeais apontando para os vértices do diamante:

```gdscript
const _DIRS: Array = [
    {"lbl": "N", "dir": Vector2( 0.0, -1.0)},  ## vértice topo   (↑)
    {"lbl": "E", "dir": Vector2( 1.0,  0.0)},  ## vértice direita (→)
    {"lbl": "S", "dir": Vector2( 0.0,  1.0)},  ## vértice base   (↓)
    {"lbl": "W", "dir": Vector2(-1.0,  0.0)},  ## vértice esquerda (←)
]
```

As **faces de parede** (NW, NE, SW, SE) ficam nas **arestas** entre esses vértices —
visualmente entre os braços do compasso, não nos braços.

---

## 9. Assets de Parede

Assets de parede carregam sufixo direcional `_NW`, `_NE`, `_SE`, `_SW`
alinhados com este glossário:

```
source_assets/subcubes/
├── subcube_concrete.png     ← átomo, direction-agnostic
├── subcube_metal.png
├── subcube_stone.png
└── subcube_wood.png

master_assets/walls/         ← assets legados (Kenney canvas, não usados no Container system)
├── wall_NW.png   ← aresta cima-esquerda
├── wall_NE.png   ← aresta cima-direita
├── wall_SE.png   ← aresta baixo-direita
└── wall_SW.png   ← aresta baixo-esquerda
```

> **Atenção:** Os PNGs em `master_assets/walls/` foram renomeados para este padrão.
> Se regenerados pelo pipeline Python, usar os sufixos `_NW`, `_NE`, `_SE`, `_SW`
> conforme este glossário.

---

## 10. Termos Banidos

Os seguintes termos causaram confusão histórica e estão **banidos** do codebase:

| Termo banido | Motivo | Substituto |
|---|---|---|
| Qualquer ref. a "Kenney offset derivation" | Sistema extinto | Este glossário |
| `SUBCUBE_FACE_OFFSETS` com comentários "v1/v2/v3" | Histórico confuso | Glossário §5 |
| `on_nw` significando `cell.y == min_y` | Invertia o eixo | `on_ne` (§4) |
| "N = upper-right" em qualquer comentário | Contradiz compasso | "N = topo (vértice)" |
