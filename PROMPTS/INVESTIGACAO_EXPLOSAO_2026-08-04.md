# Investigação: Por que a Explosão está "Terrível"?

**Data:** 2026-08-04 (após PERF-01/02/03 + D11 implementados)  
**Responsável:** Claude (investigação)  
**Estado:** Análise Completa

---

## Executive Summary

Apesar de **78% de melhoria** (4.3s → ~920ms), o Director avaliou a explosão como "terrível" e "consumindo todos os recursos", mesmo após abdícar de 3 perspectivas de câmera (ROTATE-KILL-01, 2026-08-03).

**Conclusão:** Não é um problema de velocidade. É um problema de **arquitetura estrutural**. O custo da detonação está distribuído entre:
- Renderização e compositing (otimizados em PERF-02)
- Cálculo de luz (otimizado em PERF-03)
- Mas algo fundamental ainda impede o progresso

---

## 1. Histórico de Otimizações Implementadas (2026-08-04)

### PERF-01 (Commit `5c533d1`)
**Problema:** 4.3s congelamento visível ao detonar  
**Soluções:**
- `process_dirty_async()` — renderização assíncrona, spread across frames
- `_baked_source_image_cache` — cache de readback GPU→CPU (98% do custo aqui)
- `_tint_image_rgb()` byte-buffer rewrite

**Resultado:** 4.3s → ~2.9s  
**Impacto:** Jogo não mais congela visualmente; continua processando em background

---

### PERF-02 (Commits `b81ae93` + `a4142cd`)
**Problema:** Após PERF-01, ainda ~2.9s de processamento restante (34% de custo)

| Item | Ganho | Resultado |
|------|-------|-----------|
| **A1** Batch composite uploads | 876ms → 8.1ms | 197 → 5 uploads |
| **A2** Cached polygon masks | 362ms → 17.2ms | same 459 ops |
| **A3** Decal paste Lanczos cache | 972ms → 774ms | *(substituted — byte-buffer was REGRESSION)* |
| **B1** Rings 4→3 | 14 slices → 6 | Fysical reduction |
| **B2** Resistances ×0.65 | all materials | Physical reduction |
| **B3** Bomb-only soot | 925 → 1477 voxels | Wider reach for bombs |
| **B4** Floor 1 layer/blast | skipped FLOOR_-2 | Physical reduction |

**Resultado:** 3717ms → **1251ms** (66% mais rápido)

---

### PERF-03 (Commit `10406db`)
**Problema:** Após PERF-02, o repaint de luz era o maior cost center restante

| Stage | Antes | Depois |
|-------|-------|--------|
| `bucket_for()` (per-cell lookup) | 362ms | 42ms | 
| Repaint total | ~648ms | ~328ms |
| **Detonation total** | 1251ms | **~920ms** (-26%) |

**Fix:** Cache reuse com `geometry_only` flag — não rebuilt 107k voxels unchanged

---

### D11 (Commit `7a1b66b`)
**Elemento:** Três estágios de destruição (DESTROYED → DENTED → CRACKED) com flashes  
**Desafio:** Staging criava batches "wildly uneven in cost"  
**Medição encontrada:**
- 8ms budget → 8940ms (10× regression por re-uploads na frame render)
- 200ms budget → 995ms → ~950-1030ms final

**Resultado:** Choreography com custo ~8% de overhead acima baseline 920ms

---

## 2. Sequência de Speedups

```
4300ms  ← Original (PERF-01 target)
  ↓ PERF-01
2900ms  ← 33% ganho (async + cache)
  ↓ PERF-02
1251ms  ← 57% ganho (uploads + masks + physics reduction)
  ↓ PERF-03
 920ms  ← 26% ganho (light cache reuse)
  ↓ D11
~950ms  ← choreography + overhead
```

**Total: 78% de melhoria** (4.3s → ~950ms)

---

## 3. Por que Still "Terrível"?

### A. Sacrifício Foi Enorme
- **Removeu camera rotation** (ROTATE-KILL-01, 2026-08-03)
  - Perdia 1918ms por rotação (rebuild + re-bake completo)
  - Abdicou de 3 das 4 perspectivas
  - Mantém apenas 1 perspectiva fixa para player
  
### B. Ganho Não Justificou o Sacrifício
O Director: "a gente já abdicou de usar 3 perspectivas diferentes do jogo e não melhorou nada"

Interpretação:
- A remoção de rotation foi feita PORQUE destruição era cara
- Destruição estava quebrando rotation (1918ms cada)
- Depois de otimizar destruição 78%, rotation ainda não foi re-habilitado
- Isso sugere que o problema está além de "explosão é lenta"

### C. Ainda está Consumindo "Todos os Recursos"
Apesar de 920ms em um jogo turn-based (não há frame budget):
- A operação ainda consome **todo o CPU por quase 1 segundo**
- Impossível fazer algo else durante isso (salvo em background)
- O visual (três estágios + flashes + smoke) ainda ocupa ~1s do player's attention
- Em mobile, bateria/térmica seria impactado

---

## 4. Análise Estrutural: O Que Está Realmente Errado?

### Hipótese 1: Voxel Destruction é Fundamentalmente Cara
**Evidência:**
- Mesmo após 78% de otimização, ~920ms permanece
- Cada voxel precisa: damage calc → compositing → light rebuild → upload → render
- PERF-02 A1/A2/A3 otimizaram cada passo, mas a sequência em si é serial
- PERF-03 descobriu que até a light rebuild incidental (bucket lookups) era dominante

**Implicação:** Talvez o custo não pode ser reduzido mais sem mudar o modelo.

### Hipótese 2: Destruição + Rendering são Acoplados Demais
**Evidência:**
- PERF-02 batching descobriu que uploads re-executam per frame (D11)
- D11's staged approach causou 10× regression antes do tuning
- Light system rebuild (PERF-03) foi involuntário (discovery in profiling)

**Implicação:** A falta de decoupling causa ineficiência estrutural.

### Hipótese 3: "Terrível" Não Significa Lento — Significa Impactante
**Evidência:**
- 920ms em turn-based game é aceitável (não há frame budget)
- Mas visualmente e cognitivamente domina o flow do jogo
- Impossível de parallelizar com input (player espera)
- Sacrificou features (3 perspectivas) e ainda parece "insuficiente"

**Implicação:** O problema pode ser UX/design, não performance pura.

---

## 5. Decisões que Precisam Ser Tomadas

### Opção A: Aceitar a Explosão Como Feature
- Deixar 920ms como está
- Considerar 1s explosão como "visual spectacle"
- Re-habilitar camera rotation com caching (PERF-03 approach)
- Restaurar 3 perspectivas
- Documentar como "destruction is intentionally expensive"

### Opção B: Rearchitecture — Lazy Voxel Rendering
- Não rebuild toda a light field — apenas o que foi danificado
- Já parcialmente feito em PERF-03 (`geometry_only` flag)
- Poderia estender para light buckets mesmo
- Possível ganho: 920ms → 500-600ms range

### Opção C: D12 — Distract with Video Overlay
- Toca vídeo de explosão (fire/smoke) enquanto destrói
- "Spectacle" deixa a espera menos aparente
- Destruction resolve em background
- Não reduz tempo real, mas reduz tempo _perceived_
- **Explicitamente deferred pelo Director após PERF-02**

### Opção D: Rethinking Completo (O que Director pediu)
- Destruição é fundamentalmente cara em 2D isometric + voxels
- Talvez não seja o meio certo para explosões
- Considerar:
  - Pré-baked destruction sequences (não dynamic)?
  - Simplificar para "filled holes" sem detailed destruction states?
  - Remover destruição como feature do jogo?
  - Arquitetura diferente para voxel updates (não per-voxel)?

---

## 6. Próximos Passos Recomendados

**Imediato:**
1. ✅ Confirmado: PERF-01/02/03 + D11 implementados e validados
2. ✅ Confirmado: Selftests 29/29 passam, no compile errors
3. ✅ Confirmado: 920ms achieved, rotation abdicado

**Decisão do Director:**
1. Qual opção acima? (A/B/C/D)
2. Restaurar camera rotation com optimizações (Opção A)?
3. Ou proceder com rethinking completo (Opção D)?

**Se Opção D (Rethinking):**
- Parar otimizações incrementais
- Abrir nova investigação de arquitetura
- Considerar se voxel destruction é a abordagem certa

---

## 7. Artefatos de Referência

| Artefato | Localização | Status |
|----------|------------|--------|
| Plano de performance | `DETONATION_PERFORMANCE_MASTER_PLAN.md` | ✅ Completo |
| Resumo VFX01 + PERF01 | `RESUMO_SESSAO_2026-08-04_VFX01_DETONATION_PERFORMANCE.md` | ✅ Completo |
| Resumo PERF02 | `RESUMO_SESSAO_2026-08-04_PERF02.md` | ✅ Completo |
| Engine review | `ENGINE_PERFORMANCE_REVIEW.md` | ✅ ROTATE-KILL-01 decided |
| Checkpoint | Tag `checkpoint/broken-explosion-2026-08-04` | ✅ Created |
| Screenshots | `Screenshots/history/d11_*.png` + `perf02_*.png` | ✅ Available |

---

## 8. Métricas Finais

| Métrica | Baseline | Final | Ganho |
|---------|----------|-------|-------|
| **Detonation time** | 4300ms | 920ms | 78% ↓ |
| **Render stall visible** | Yes (2.9s) | No (async) | ✅ Fixed |
| **Camera rotation** | Working, 1918ms | Disabled (ROTATE-KILL-01) | Lost |
| **Selftests** | Not measured | 29/29 PASS | ✅ All green |
| **Perceived speedup** | Massive freeze | Still "terrível" | ? Unclear |

**The paradox:** 78% improvement, sacrificed 3 perspectives, but still "terrible." This is the core problem to rethink.
