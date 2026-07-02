# INFILTRAITOR — Resumo da Sessão (01–07 de julho, 2026)

## Fase 1: Auditoria e Diagnóstico

**Estado inicial:** O backup trazido continha os voxel-planes já implementados (VOXEL-01 a 07 completos), mas com um problema visual: todas as paredes renderizavam **deslocadas rigidamente** em relação ao grid de gameplay (ver screenshot debug de 2026-07-01).

**Auditoria realizada:** Encontrou-se três convenções de offset coexistindo no mesmo render stack:
- FloorLayer em position (0,0); offset visual no asset (o canvas do tile de chão)
- Overlays aplicando offset aritmeticamente por draw
- Plano voxel com offset cozido na transformada do node

**Root cause identificado:** Híbrido de convenções, não de matemática errada. SLICE-00 foi projetado para ser **diagnóstico-gated**: instrumentação para medir delta real, classificação contra padrões conhecidos (ancoragem de textura, transformada de layer, espaço de células), e aplicação analítica da correção — nenhuma calibração empírica, tudo baseado em Canons derivados (transformadas = derivadas de constantes, nunca números mágicos, provadas por selftest).

**Resultado:** SLICE-00 aplicado com sucesso. O alinhamento foi corrigido; o problema do offset na imagem foi resolvido.

---

## Fase 2: Arquitetura SLICE — Engine Geometry 1.0

**Problema estrutural identificado:** O modelo antigo ainda codificava "Wall como entidade dona de duas slices" (`slice_index` 0/1, ambas carimbadas com a célula de origem). Dual-key problem: o mesmo par de arestas poderia ser emitido de ambas as GUs adjacentes, gerando lógica complexa de deduplicação.

**Princípio do SLICE plan:** Hierarchy canônica: **GAME UNIT → FACE → SLICE → VOXEL**. Wall não é objeto físico — é **relação lógica** entre duas Slices independentes, uma por GU adjacente (gu_cell = a GU que realmente contém a slice). Identidade de Edge normalizada estruturalmente (canonical form: `face_a` sempre SE/SW, `gu_a` lexicograficamente ≤ `gu_b`), matando o dual-key.

**Três-etapas de refatoração planejadas:**

### SLICE-00 — Transform Canon (✅ COMPLETO)
Prova formal de que o plano voxel e o plano de gameplay estão alinhados. Define 4 Canons:
1. O plano de gameplay define o world grid (FROZEN).
2. Render planes adaptam via derivadas equações (não ajustes empíricos).
3. `texture_origin` é derivado de métricas do átomo (32×36 canvas, 32×16 tile → origin_y = 10).
4. Cell-space atravessa a costura intacto (8 × gu = voxel_origin, nunca é tocado).

**Aceito:** transform canon integrado ao master plan; alignment selftest verde; probe mostrando zero delta pós-correção.

### SLICE-01 — Geometry Module (📝 PROMPT PRONTO)
Cria `godot/scripts/geometry/` com 11 classes novas, totalmente aditivas, zerando o risco de regressão:
- **GeometryCoords**, **Face**, **Edge**, **Slice**, **Voxel** — reformulação de identidade
- **EdgeRegistry** — single source of truth ligando o modelo (edges ↔ slices)
- **EdgeExtractor**, **SliceGenerator**, **JunctionResolver** — pipeline Edge → Slices → Voxels
- **HighWallGroup** — container de bake (agrupamento provisório por Edge)
- **VoxelRenderer** — o único scene-tree citizen do módulo; dono de seus TileMapLayers
- **geometry_selftest.gd** — headless, 6 grupos de checks

Aceita: módulo completo, jogo renderiza idêntico ao atual, zero subcube no código novo.

### SLICE-02 — Integration + Legacy Purge (📝 PROMPT PRONTO)
Dois estágios gateados:
- **Stage A:** Integra o módulo novo em room.gd; wire EdgeRegistry, SliceGenerator, VoxelRenderer.
- **Parity gate:** Game deve renderizar exatamente igual aos specs atuais (PLAYGROUND + SIGMA_01, alturas 1–3, portas, dividers, junctions, dirty-toggle via sibling_slice).
- **Stage B (só se A passar):** Deleção de 10 arquivos legados; expurgo de "subcube" (grep retorna zero); renomeações de classes (WallSlice → Slice, etc).

---

## Fase 3: Decisão de Greenfield vs Reforma

**Questão:** Reformar o sistema antigo (str_replace em room.gd) vs fazer novo do zero (greenfield)?

**Resposta:** **Híbrido.** O VOXEL-01..07 contém conhecimento validado (dual-key logic, V-junctions, dirty aggregation) que não vale reinventar. Mas a costura (subcube_geometry.gd + funções de placement em room.gd) merecia nascer limpa.

**Decisão:** Criar módulo novo (greenfield), **portar** os átomos validados com reforma de identidade, **deletar** o legado. Zero reescrita cega; cada classe é porte com remoção do `slice_index` e adoção do gu_cell verdadeiro. Resultado: novo sistema nasce conforme Engine Architecture 1.0 desde a linha 1; jogo intacto durante transição.

---

## Fase 4: Baking System — Arquitetura de Texturas

**Contexto:** INFILTRAITOR é fundamentado em replayabilidade altíssima via cenários procedurais. Variação de visual vem de cascata temática (macro temas = galáxias, micro = tier de jogador), com texturas descidas em árvore de pastas consultadas em load-time.

**Problema estrutural:** O baking é textura por nature — composição de Image (crop + multiply blend) em load-time, ancorada analyticamente, nunca no posicionamento. O sistema anterior (CONTAINER) falhou porque a textura **decidia onde as coisas ficavam**. O novo a usa só para **qual pixel** dentro de um tile cuja posição é exata.

**Catálogo de texturas — dimensões e semântica:**

| Categoria | Escopo | Dim. flat | Requisitos | Volume |
|---|---|---|---|---|
| **MATERIAL** | 1 face voxel | top 16×16 + side 16×20 | Seamless 2D; suporta variantes | Base, 4–6 core (concrete, wood, metal, stone, tech) |
| **SLICE** | 1 aresta × 1 andar (8×8 voxels) | **128×160** | Seamless-X obrigatório; seamless-Y p/ empilhar | Médio volume, alta variação |
| **RUN** | 5 arestas × andar | **640×160** (ou 640×320 dual-storey) | Seamless nas bordas vertical+horizontal; crop ancorado | 2–3 variantes por material |
| **STICKER** | Multi-GU livre (satélite, logos) | Livre + manifest.json | Material_mask, footprint, blend_mode | Baixo volume, muito específico |

**Cálculo preditivo de uso (baseado em specs reais: SIGMA_01, PLAYGROUND, procedural):**
- Runs de parede ≤5 GUs: 8,4% do comprimento total
- Runs de parede >5 GUs: 91,6% (precisa de tiling ou variação)
- Viewport de portrait: 9–18 GUs visíveis
- Conclusão: **RUN-5 será repetido na maioria dos casos**

**Decisão estratégica: dois caminhos**
- **(a)** Subir para RUN-8 (1024×160): zero repetição numa tela; custo autoral de 60% (variante maior)
- **(b)** Manter RUN-5 + 2–3 variantes por material, alternadas via seed: mais barato, aliado à cascata temática, suficiente para a distribuição de runs real

**Recomendação:** (b), porque a autoria é sua (qualidade garantida) e a variação procedural (seed alternando entre variantes) é grátis.

**Transform/Skew — matemática do bake:**
1. Superfície da parede é um paralelogramo contínuo (lados verticais, arestas diagonais com slope ±½).
2. Textura flat → tela via **shear vertical unitário** (`y' = y + s·x`, `s = ±½`), determinante 1 (sem resampling).
3. Crop e shear colapsam numa passada de inverse-mapping: para cada pixel de destino, amostra a coordenada global no flat (offset_run·16 + u, (7−level)·20 + v).
4. Resultado → multiply blend contra o átomo do material, saindo para atlas dinâmico (face_atlas_rect endereça).

---

## Fase 5: Catálogo de Texturas — Próximos Passos

Quatro decisões suas necessárias antes do formalismo:

1. **RUN-8 ou RUN-5+variantes?**
2. **RUN autorado com 1 ou 2 andares de altura?** (specs atuais: 1–2; recomendação: 2 com seamless-Y)
3. **Topos das paredes recebem "cap" especial ou ficam no material puro?**
4. **Autoria nativa ou @2x com downsample no import?**

**Próximo prompt será TEX-CATALOG-01:** documento normativo do catálogo (dimensões finais, requisitos de seamless, naming convention, manifests.json schema, e ferramenta Python de validação que checa dimensão+continuidade de borda automaticamente). Esse documento vira o alicerce que **VOXEL-08 (Baking System)** consome.

---

## Timeline Cristalizada

```
✅ SLICE-00  — Transform Canon + alignment selftest
📝 SLICE-01  — Geometry module greenfield + selftest (pronto para K4PUTZ)
📝 SLICE-02  — Integration stage A + parity gate + purge stage B (pronto)
📋 TEX-CATALOG-01  — Especificação formal do catálogo (aguarda 4 decisões)
→  MAT-01  — Materiais atravessam MapSpec→Slice (porte da VOXEL-04 lógica)
→  VOXEL-08  — Baking System (runtime Image composition + atlas dinâmico)
→  VOXEL-09  — Destrutibilidade (damage states, visual feedback, physics)
→  VOXEL-10  — CODEMAP + docs (arquitetura final codificada)
→  SLICE-03  — Geração de mapas emitindo Edges (reescrita de compilador)
```

---

## Princípios Congelados

1. **Transform Canon 1:** Plano de gameplay FROZEN; render planes adaptam (nunca inverter).
2. **Identidade de Edge:** Canonical form estrutural; dual-key problem morreu.
3. **Slice 1:1 com GU:** gu_cell é verdadeiro; morte do `slice_index`.
4. **Texturas flat-lit + runtime apaga:** Composição de imagem offline, projeção analítica, zero calibração.
5. **Cascata temática:** Resolve em cascata (map_local → micro → meso → macro → _base); `_base` é fallback completo.

---

## O que foi entregue desta sessão

- **SLICE-00:** prompt + aplicação + confirmação de fix
- **SLICE-01, SLICE-02:** dois prompts prontos para K4PUTZ, arquivos do módulo geometry não tocados yet
- **Auditoria de mcblocks:** extração, análise de shadowing (L/top 0.355, R/top 0.662), prova de conceito da técnica de espelhamento, descarte em favor de autoria própria de qualidade
- **Análise preditiva de runs:** base em dados reais; seleção de estratégia (RUN-5+variantes favorecida)
- **Matemática de bake:** transform/skew/crop/blend formalizado (shear unitário determinante-1, inverse-mapping, atlas dinâmico)
- Este resumo + roadmap cristalizado até SLICE-03

