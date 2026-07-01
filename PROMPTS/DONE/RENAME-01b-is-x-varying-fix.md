# RENAME-01b — Patch: Corrigir `is_x_varying` em wall_container.gd

> **Pré-requisito:** RENAME-01 aplicado.
> **Natureza:** 2 arquivos, menos de 10 linhas. Corrige bug crítico introduzido
> pelo RENAME-01: todas as 4 direções usam fórmula de blit e âncora erradas,
> causando deslocamento de 96 px em x em todas as paredes.
> **Zero mudança de lógica além da correção.**

---

## CONTEXT

Em `wall_container.gd`, a variável `is_x_varying` determina se os subcubos
da face variam em **x** (linha horizontal) ou em **y** (coluna vertical):

```
X-varying (linha): NE = top row  (y=0, x varia 0..3)
                   SW = bottom row (y=3, x varia 0..3)
Y-varying (coluna): NW = left col (x=0, y varia 0..3)
                    SE = right col (x=3, y varia 0..3)
```

No sistema **antigo** (pré-rename), "NW" era top row (X-varying), então
`is_x_varying = wall_dir == "NW" or wall_dir == "SE"` estava correto.
No sistema **novo** (pós-rename), "NW" é left col (Y-varying), então a
mesma linha está **invertida** para todas as 4 direções.

Impacto: âncora errada → deslocamento de 96 px em x + imagem espelhada.

---

## MODULE

- `godot/scripts/world/wall_container.gd`
- `godot/scripts/world/room.gd` *(só comentários em `_subcubes_on_edge`)*

---

## TASK

### 1. `wall_container.gd` — Corrigir `is_x_varying` em `build()`

**Localizar:**

```gdscript
	var is_x_varying: bool = wall_dir == "NW" or wall_dir == "SE"
```

**Substituir por:**

```gdscript
	## X-varying: subcells variam em x (linhas NE e SW).
	## Y-varying: subcells variam em y (colunas NW e SE).
	## Ver DIRECTION_GLOSSARY.md §3.
	var is_x_varying: bool = wall_dir == "NE" or wall_dir == "SW"
```

### 2. `wall_container.gd` — Atualizar comentários das constantes ANCHOR

**Localizar:**

```gdscript
const ANCHOR_X_VARYING := Vector2(32.0,  156.0)  ## NW e SE
const ANCHOR_Y_VARYING := Vector2(128.0, 156.0)  ## SW e NE
```

**Substituir por:**

```gdscript
const ANCHOR_X_VARYING := Vector2( 32.0, 156.0)  ## NE e SW (x-varying: top/bottom rows)
const ANCHOR_Y_VARYING := Vector2(128.0, 156.0)  ## NW e SE (y-varying: left/right cols)
```

### 3. `room.gd` — Atualizar comentários em `_subcubes_on_edge()`

Localizar o bloco de `if/elif` que verifica `edge_delta` dentro de
`_subcubes_on_edge()` e atualizar **apenas os comentários** (sem tocar no código):

**Localizar e atualizar comentários** (o código permanece idêntico):

```gdscript
	if edge_delta == Vector2i(0, -1):      ## NE edge — top row    (y=0)
		...
	elif edge_delta == Vector2i(1, 0):     ## SE edge — right col  (x=3)
		...
	elif edge_delta == Vector2i(0, 1):     ## SW edge — bottom row (y=3)
		...
	elif edge_delta == Vector2i(-1, 0):    ## NW edge — left col   (x=0)
		...
```

> Se os comentários internos já foram atualizados ou não existem, pular este passo.
> O código de `_subcubes_on_edge()` — os loops e append — **não muda**.

---

## DO NOT TOUCH

- Nenhum VALUE de `FACE_CENTER_OFFSET` — não muda.
- Nenhuma lógica de blit além da variável `is_x_varying`.
- Qualquer outro arquivo.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## is_x_varying corrigido
grep "is_x_varying" godot/scripts/world/wall_container.gd
# esperado: wall_dir == "NE" or wall_dir == "SW"

## Apenas 2 arquivos alterados
git diff --name-only
# esperado: wall_container.gd + room.gd
```

**Visualmente:** após o fix, as paredes devem aparece na posição calibrada pelos
valores do `FACE_CENTER_OFFSET` (sem o deslocamento fantasma de 96 px que existia
desde o RENAME-01).

---

**Escopo:** 2 arquivos · 3 str_replace curtos · 1 sessão.
**Próximo:** CONTAINER-04 (corner fill explícito).
