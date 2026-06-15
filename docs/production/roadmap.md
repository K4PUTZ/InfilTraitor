# INFILTRAITOR — Roadmap

> **Macro-level development phases. Cada fase tem um critério de saída claro antes de avançar.**

---

## Filosofia de Desenvolvimento

**Foco no feeling antes do conteúdo.** Um protótipo que demonstra a essência do jogo com gráficos placeholder é mais valioso que um jogo visualmente polido com mecânicas quebradas. O loop core — observar, planejar, agir, reagir — deve ser divertido e tenso antes de qualquer outro investimento.

**Fases são sequenciais e dependentes.** Não avançamos de fase enquanto os critérios de saída da fase atual não estiverem validados. Marcar milestones como completos sem validação funcional é o principal risco de desenvolvimento.

---

## Phase Overview

```
FASE 1: Prototype Foundation (M1.0–M1.5)     ✅ COMPLETO
├─ Navegação em grid
├─ Renderização isométrica
├─ FOW 3 camadas
└─ Mecânicas de movimento

FASE 2: Stealth Core Systems (M2.0–M2.12)    ✅ FUNCIONAL
├─ Noise system (matemático + guards reagem) ✅
├─ TIC system (cálculo) ✅
├─ Shadow baking ✅
├─ Guard detection (gradual com thresholds) ✅
├─ Guard FSM & communication ✅
└─ Audio detection ✅

FASE 3: Investor Demo                         🟢 PRONTO
├─ IA funcional ✅
├─ Detecção gradual ✅
├─ Percepção & shadow integration (próximo)
├─ Tuning de game feel
└─ → CRITÉRIO DE SAÍDA: loop de stealth divertido e convincente

FASE 4: Production Pass (Pós-Investimento)    ⏳ QUEUED
├─ Áudio SFX real
├─ Sprites e animações
├─ UI/UX polida
├─ Suporte a múltiplas salas
└─ Sistema de save

FASE 5: Campaign — Chapter 1                  ⏳ QUEUED
├─ 5–7 salas handcrafted
├─ Progressão de dificuldade
├─ Missão briefings
└─ Introdução narrativa

FASE 6: Campaign — Chapters 2 & 3            ⏳ QUEUED
├─ Comunicação e coordenação de guards
├─ Combate (opcional, nunca ótimo)
├─ Clímax narrativo
└─ Unlock de Freelance mode

FASE 7: Freelance Mode                        ⏳ QUEUED
├─ Geração procedural de missões
├─ Sistema de progressão
├─ Dificuldade escalável
└─ Leaderboards

FASE 8: Polish & Release                      ⏳ QUEUED
├─ Áudio completo (adaptativo)
├─ Animações finais
├─ Localização
├─ Otimização de performance
└─ QA & deploy (iOS, Android, Web)
```

---

## Detailed Phases

### Fase 1: Prototype Foundation (COMPLETO ✅)

**Focus:** Navegação core, renderização, e mecânicas de grid.

**Critério de Saída (validado):**
- Agente se move suavemente no grid
- FOW atualiza corretamente com movimento
- Renderização consistente e performática
- Sem glitches visuais ou de câmera

---

### Fase 2: Stealth Core Systems (FUNCIONAL ✅)

**Focus:** Sistemas de detecção, ruído, sombras, e IA básica.

**O que está funcional:**
- TIC System (cálculo de probabilidade de detecção) ✅
- Noise System (grid persistente, decay, propagação) ✅
- Shadow baking (projeção de cone, 8 direções) ✅
- Guard detection (gradual com thresholds 0.30/0.60/1.00) ✅
- Guard FSM transitions ✅
- Guard communication signals ✅
- Pathfinding A* para guards ✅
- Audio detection com atenuação por parede ✅

**Critério de Saída (validado):**
- Guards detectam jogador e escalam estado ✅
- Stealth é possível com planejamento ✅
- Loop de tensão demonstrável ✅

---

### Fase 3: Investor Demo (PRONTO 🟢)

**Objetivo:** Uma experiência de 5–10 minutos que demonstra a proposta central do jogo. Gráficos placeholder. Sem áudio, narrativa, ou UI polida.

**Status Atual (2026-06-14):**
- IA funcional com escalação correta ✅
- Detecção visual gradual implementada ✅
- Audio detection funcional ✅
- Próximos: integração com percepção espacial (LOS + lighting)

**Estimativa:** 3–5 semanas de desenvolvimento focado (solo)

---

### Fase 4: Production Pass (Pós-Investimento ⏳)

**Pré-requisito:** Investor Demo concluído e interesse confirmado.  
**Objetivo:** Elevar qualidade de produção para vertical slice apresentável ao público.

**Deliverables:**
- Integração de SFX (footsteps, alerts, detection events)
- Sprites e animações de estado para guards e agente
- UI/UX polida (HUD, menus, settings, pause)
- Suporte a múltiplas salas (layout data-driven)
- Sistema de save básico (checkpoint entre salas)
- Otimização de performance (overlay O(n²) → culled)
- Patrol system data-driven

**Critério de Saída:**
- Vertical slice jogável e apresentável para press/público
- Áudio e visual suficientes para gameplay trailer

**Estimativa:** 8–12 semanas com 2–3 pessoas

---

### Fase 5: Campaign — Chapter 1 (⏳)

**Pré-requisito:** Fase 4 completa. Team expandido.  
**Objetivo:** Tutorial narrativo com 5–7 salas handcrafted.

**Deliverables:**
- 5–7 níveis handcrafted com dificuldade progressiva
- Introdução de mecânicas (visão → noise → sombra)
- Mission briefings e extraction sequences
- Narrative introduction (agency, agent background)

**Critério de Saída:**
- Chapter 1 jogável do início ao fim
- Novo jogador entende o jogo sem tutorial explícito

**Estimativa:** 8–10 semanas com time completo

---

### Fase 6: Campaign — Chapters 2 & 3 (⏳)

**Pré-requisito:** Chapter 1 validado com playtesters.  
**Focus:** Comunicação de guards, coordenação, combate opcional, clímax narrativo.

**Deliverables:**
- Chapter 2: 5–7 níveis com comunicação/coordenação em foco
- Chapter 3: 5–7 níveis com confronto, escolha moral, desfecho
- Sistema de combate básico (viável mas não ótimo vs stealth)
- Unlock de Freelance mode

**Critério de Saída:**
- Campanha jogável do início ao fim (~45–60 min)
- Escolha final do jogador tem impacto narrativo

**Estimativa:** 12–16 semanas com time completo

---

### Fase 7: Freelance Mode (⏳)

**Pré-requisito:** Campanha completa.  
**Focus:** Progressão infinita e geração procedural.

**Deliverables:**
- Geração procedural de layouts (templates + variação)
- Sistema de progressão do agente (skills, gadgets)
- Dificuldade escala com progresso
- Leaderboards opcionais

**Estimativa:** 8–10 semanas

---

### Fase 8: Polish & Release (⏳)

**Focus:** Qualidade final, performance, localização, deploy.

**Deliverables:**
- Áudio adaptativo completo (música + SFX)
- Animações finais e VFX
- Localização (PT/EN mínimo; ES/FR opcional)
- Performance otimizada para iOS/Android de 4–5 anos
- QA pass completo
- Deploy iOS, Android, Web

**Estimativa:** 8–12 semanas

---

## Timeline Summary

| Fase | Estimativa | Pré-requisito | Status |
|------|-----------|---------------|--------|
| Fase 1: Prototype | — | — | ✅ Completo |
| Fase 2: Stealth Core | — | Fase 1 | ✅ Funcional |
| **Fase 3: Investor Demo** | **2–3 semanas** | **Integração** | **🟢 Pronto** |
| Fase 4: Production Pass | 8–12 semanas | Investimento | ⏳ Queued |
| Fase 5: Chapter 1 | 8–10 semanas | Fase 4 + team | ⏳ Queued |
| Fase 6: Chapters 2–3 | 12–16 semanas | Fase 5 | ⏳ Queued |
| Fase 7: Freelance | 8–10 semanas | Fase 6 | ⏳ Queued |
| Fase 8: Polish & Release | 8–12 semanas | Fase 7 | ⏳ Queued |

**Total estimado pós-investimento (Fase 4–8):** 12–18 meses com time de 3–5 pessoas.

**Nota sobre estimativas:** As fases pós-investimento dependem do tamanho do time. Sem investimento, as estimativas não têm sentido — o objetivo agora é a Fase 3.

---

## Milestone Dependencies

```
Fase 1 (Prototype) ✅
    ↓
Fase 2 (Stealth Core) ⚠️
    ↓
ID-01 (Fix guard FSM) ← AGORA
    ↓
ID-02 (Detection tuning)
    ↓
ID-03 (Demo room polish)
    ↓
ID-04 (FSM refactor)
    ↓
Fase 3 COMPLETA → Investor Demo

----- pós-investimento -----
    ↓
Fase 4 (Production Pass)
    ↓
Fase 5 (Chapter 1)
    ↓
Fase 6 (Chapters 2–3) + M3.0 (Combat)
    ↓
Fase 7 (Freelance)
    ↓
Fase 8 (Polish & Release)
```

---

## O Que Está Deliberadamente Fora do Scope Atual

| Item | Razão para adiar |
|------|-----------------|
| Áudio SFX | Noise grid matemático suficiente para demo |
| Sprites/animações | Tweening suficiente para demo |
| Menu/settings UI | HUD atual suficiente para demo |
| Sistema de save | Não necessário em demo single-room |
| Narrativa | Requer campanha (pós-investimento) |
| Combate (M3.0) | Requer FSM sólido; adiar até pós-refactor |
| Geração procedural | Requer campanha (pós-investimento) |
| Localização | Última fase |

---

## Revision History

| Date | Update |
|------|--------|
| 2026-06-12 | Roadmap reescrito: Investor Demo como meta primária; fases pós-investimento racionalizadas; estimativas realistas; bloqueadores críticos documentados |
| 2026-06-11 | Roadmap inicial criado a partir de DEVELOPMENT/PROGRESS.md |
