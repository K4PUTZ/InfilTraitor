# INFILTRAITOR — Production Dashboard & Status

> **Quick snapshot of project status, blockers, and immediate priorities.**

---

## Objetivo Atual

**Meta:** Investor Demo — uma sala de stealth funcional e convincente.  
Critério: qualquer pessoa que jogar por 5–10 minutos consegue sentir a tensão do stealth, vê os guards reagindo, e entende a proposta do jogo. Gráficos placeholder, sem áudio, narrativa ou UI polida.

---

## 📊 Current Status Snapshot

**Project Phase:** Investor Demo Preparation (� IA funcional, integração de sistemas em progresso)  
**Overall Progress:** 65% complete (reestimado com IA funcional)  
**Last Updated:** 2026-06-14

---

## ⚠️ Active Design Gaps (sem bloqueadores críticos)

| Gap | Arquivo | Status |
|-----|---------|--------|
| `move_to_cell_animated` não é awaitable (fire-and-forget) | `guard_enemy.gd` | Abre risco de animações sobrepostas com 3+ guards |
| ShadowProjector: luz direta sem LOS, altura invertida, direção quantizada | `shadow_projector.gd` | Funcional para demo, refinamento pós-investimento |
| ExposureSystem: 6 classes definidas, 2 usadas; stability/confidence não populadas | `exposure_system.gd` | Spec completa, implementação parcial esperada |

**Status:** Guards detectam, reagem, e escalam gradualmente. IA funcional para demo. Refinamentos acima são qualidade/arquitetura, não blockers.

---

## 🎯 Current Priority

**PRIMARY FOCUS:** Integração de percepção (lighting/LOS) com IA (verificação auditiva + visual)  
**SECONDARY FOCUS:** Refinamento de game feel (tuning de curves de detecção)  
**TERTIARY:** Demo polish e apresentação a investidores

---

## 📈 Domain Status (revisado)

### Gameplay (G-xx) — 75% Beta
✅ Movimento em grid, turn system, AP economy, pathfinding A*  
✅ Guards detectam e reagem ao agente (funcional)  
⏳ Objetivos, combate, overwatch/gadgets (pós-demo)

### AI & Behavior (A-xx) — 75% Alpha
✅ Guards detectam e reagem ao agente (funcional)  
✅ FSM com 5 estados e de-escalação por timer  
✅ Detecção visual com escalação gradual (thresholds 0.30/0.60/1.00)  
✅ Pathfinding A* excelente  
✅ Comunicação (whistle/radio) funcional via signals  
⏳ Multi-guard coordination refinement, personality variance (pós-demo)

### Lighting & Visibility (L-xx) — 80% Alpha
✅ Shadow projection, baking, fog of war, visualização  
⚠️ Light sources hardcoded (aceitável para demo)  
⏳ Dynamic lighting (futuro)

### Audio & Sound (Au-xx) — 10% (noise grid matemático apenas)
✅ Noise grid, propagação, decay (matemático)  
⏳ SFX, música adaptativa (pós-demo, pós-investimento)

### Animation (An-xx) — 5% (tweening apenas)
✅ Tweening de movimento (funcional para demo)  
⏳ Sprites, animações de estado (pós-demo)

### UI & Presentation (P-xx) — 30% Prototype
✅ Overlays de debug (FOW, cone de visão, noise, trail)  
✅ AP display, turno indicator  
⏳ Menu, settings, HUD polido (pós-demo)

### Content (C-xx) — 15% Prototype
✅ 1 sala, 1 arquétipo de guard, 1 tileset básico  
⏳ Variedade, expansão de salas (pós-demo)

### Infrastructure & Tooling (I-xx) — 50% Alpha
✅ Godot 4.6, git, documentação  
⏳ CI/CD, analytics (pós-lançamento)

---

## ⏭️ Next Immediate Milestones

### Esta Semana — Corrigir Blockers (ID-01)
🔴 **Fix Guard FSM Methods**
- Implementar/renomear `choose_next_cell()` → `pick_next_patrol_cell()`
- Implementar `tick_state()` com lógica de transição real
- Conectar TicSystem → detection meter → state transitions
- Sincronizar multiplicadores de estado
- **Critério:** Guard em frente ao jogador deve escalar PATROL → ALERT em 2–3 turnos

### Próximas 2 Semanas — Tuning & Feel (ID-02)
⏳ **Detection Curve Validation**
- Playtest interno com guards funcionais
- Ajustar curva de detecção (distância, sombra, postura)
- Target: stealth seja possível mas não trivial

### Semanas 3–4 — Demo Room Polish (ID-03)
⏳ **Polir sala de demonstração**
- Layout que demonstra os sistemas (sombras, noise, múltiplos guards)
- Guards com patrulhas interessantes
- Enough feedback visual para investidor entender o que está acontecendo

---

## ⚠️ Known Risks

| Risk | Status | Mitigation |
|------|--------|-----------|
| Guards não funcionais (stealth inútil) | 🚨 ATIVO | Fix imediato (esta semana) |
| Docs fora de sincronia com código | 🚨 ATIVO | Atualização em andamento |
| Mobile readability | Pendente | Teste em device real pós-demo |
| Stealth difficulty balance | Pendente | Playtest após fix |
| FSM scaling pré-M3.0 | Ativo | Refactor antes de adicionar combate |
| Overlay performance | Ativo | Profiling antes de mobile |

---

## 📊 Milestone Status by Domain

### Completed Milestones: 12 ✅

**Gameplay (G-xx)**
- G-01: Grid navigation ✅
- G-02: Turn resolution ✅
- G-03: AP economy ✅

**AI & Behavior (A-xx)**
- A-01: Guard FSM structure ✅ (estrutura declarada; funcionalidade bloqueada)
- A-02: Perception calculation ✅ (cálculo correto; não conectado)
- A-03: Attention system ✅
- A-04: Communication signals ✅ (código existe; não disparado por blocker)

**Lighting (L-xx)**
- L-01: Shadow system ✅
- L-02: Fog of war ✅

**Navigation (N-xx)**
- N-01: A\* pathfinder ✅
- N-02: Movement overlay ✅

**Audio (Au-xx)**
- Au-01: Noise system (matemático) ✅

---

### In-Progress Milestones: 1 🟡

**AI & Behavior (A-xx)**
- ID-01: Guard FSM Fix (esta semana) 🔴

---

### Planned Milestones: Investor Demo Path

**Investor Demo (ID-xx)**
- ID-01: Guard FSM critical fix ⏳
- ID-02: Detection tuning & game feel ⏳
- ID-03: Demo room polish ⏳

**Pós-Demo (PD-xx) — depende de investimento/recursos**
- Audio integration
- Animation & sprites
- UI polish
- Multiple rooms
- Save system
- Campaign Chapter 1

---

## 📞 Estrutura Atual

| Papel | Status |
|-------|--------|
| Solo/Indie Developer | Ativo |
| Audio/Animation | Contratar pós-investimento |
| QA | Playtest informal (pré-investimento) |

---

**Last Updated:** 2026-06-12  
**Status:** 🟡 FUNCIONAL COM GAPS — guards detectam e reagem, escalação visual precisa de gradação  
**Próxima ação:** Conectar detection meter às thresholds de estado para escalação gradual PATROL → SUSPICIOUS → ALERT
