# INFILTRAITOR — Technical Debt & Maintenance

> **Known limitations, architectural issues, and maintenance requirements.**

---

## 📋 Reconciliation Note (2026-06-14)

Auditoria de código confirmou que a detecção visual DA IA é **gradual com thresholds**, não binária. Item #1 ("Detection Escalation é Binária") foi marcado como RESOLVIDO. Documentação atualizada para refletir estado real do código.

---

## Definition

Technical debt is code/architecture that:
- Compromises scalability
- Reduces maintainability
- Creates bugs or instability
- Limits future features

**Debt ≠ Backlog.** Debt is unfinished work that blocks progress.

---

## ✅ Resolved Items (2026-06-14)

### 1. Detection Escalation é Binária (sem gradação SUSPICIOUS) — RESOLVIDO

**Status:** ✅ IMPLEMENTED  
**Resolution Date:** 2026-06-14

**What Changed:**  
Verificação de código em `room.gd:_apply_tic_result()` confirmou que detection escalation É gradual e implementado com thresholds:
- `DETECTION_THRESHOLD_SUSPICIOUS := 0.30`
- `DETECTION_THRESHOLD_ALERT := 0.60`
- `DETECTION_THRESHOLD_CHASE := 1.00`

**Current Implementation:**
```gdscript
if guard.detection >= DETECTION_THRESHOLD_CHASE:
    guard.observe_player(true, 3, agent.cell)  # STATE_CHASE
elif guard.detection >= DETECTION_THRESHOLD_ALERT:
    guard.observe_player(true, 2, agent.cell)  # STATE_ALERT
elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
    guard.observe_player(true, 1, agent.cell)  # STATE_SUSPICIOUS
```

**Impact:** IA funcional com escala\u00e7\u00e3o correta. Documentação foi atualizada para refletir estado real.

---

### 2. STATE_SEARCH sem visual params próprios — RESOLVIDO

**Status:** ✅ LOW-PRIORITY FIX  
**Severity:** LOW (visual only, não afeta gameplay)

---

### 3. Dead code `_compute_shadow_tiles_old()` — REMOVÍVEL

**Status:** ✅ IDENTIFICADO  
**Location:** `room.gd` lines ~1340–1373
**Action:** Remover em próxima limpeza

---

### 4. Hardcoded noise values (0.20, 0.5) — REMOVÍVEL

**Status:** ✅ IDENTIFICADO  
**Location:** `room.gd`  
**Action:** Referenciar constantes `NoiseSystem.NOISE_CHANCE_WALK` / `NOISE_INTENSITY_WALK`

---

## Critical Debt 🔴 (Bloqueia escalabilidade futura)
**Severity:** HIGH  
**Impact:** HIGH  
**Estimated Fix:** 1–2 weeks

**Problem:**  
Guard FSM (5 estados + transitions) é gerenciável agora, mas vai escalar mal com:
- Personality variance
- Faction-specific states
- Learning behaviors

**Current Code:**
```gdscript
match guard.state:
    STATE_PATROL: patrol_decision()
    STATE_SUSPICIOUS: suspicious_decision()
    ...
```

**Solution (Queued):**  
Refatorar para Strategy pattern ou behavior tree antes de adicionar combate (M3.0).

**Timeline:** Pré-M3.0

---

### 3. Hardcoded Patrol Timings
**Severity:** HIGH  
**Impact:** MEDIUM  
**Estimated Fix:** 3–5 days

Padrões de patrulha hardcoded em room layout. Necessário mover para configuração data-driven antes de suportar múltiplas salas.

**Timeline:** Pré-campanha

---

### 4. Overlay Performance on Large Maps
**Severity:** HIGH  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 weeks

Movement overlay (Dijkstra) e FOW overlay usam O(n²) iteration por frame. 36×36 = 1296 tiles por frame. Risco de FPS drop em mobile.

**Timeline:** Antes de playtesting em dispositivos mobile reais

---

## High Priority Debt 🟠

### 5. `await guard.move_to_cell_animated()` não é coroutine
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 days

`move_to_cell_animated()` é void function — `await` em `EnemyPhaseController` retorna imediatamente. Movimento de todos os guards dispara em background (fire-and-forget). Logicamente correto (cell atualiza antes da animação), mas pode causar animações sobrepostas em turnos futuros com múltiplos guards.

**Fix:** Declarar `move_to_cell_animated` como coroutine que aguarda `move_finished` signal, ou conectar o controller ao signal diretamente.

**Timeline:** Antes de testar com 3+ guards simultâneos

---

### 6. Audio System Not Integrated (SFX)
**Severity:** MEDIUM  
**Impact:** HIGH (produto final) / Baixo (Investor Demo)  
**Estimated Fix:** 2–3 weeks

Noise grid matemático funcional. SFX real deliberadamente deprioritizado para demo.

**Timeline:** Pós-Investor Demo (Fase 4)

---

### 7. No Save System
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 weeks

Não necessário para demo single-room. Necessário antes de campanha.

**Timeline:** Fase 4

---

### 8. Animation System Underdeveloped
**Severity:** MEDIUM  
**Impact:** MEDIUM (produto final) / Baixo (Investor Demo)

Tweening funcional para demo. Sprites reais aguardam pós-demo.

---

## Medium Priority Debt 🟡

### 9. Perception Distance Curve Not Validated
**Severity:** MEDIUM  
**Estimated Fix:** 1 week (playtesting)

```gdscript
DISTANCE_CURVE = [1.0, 0.95, 0.85, 0.60, 0.40, 0.15, 0.05, 0.01]
```

Curva projetada teoricamente, não testada com jogadores.

**Timeline:** Primeiro playtest

---

### 10. STATE_SEARCH sem visual params próprios
**Severity:** LOW  
**Estimated Fix:** 30 min

`_get_cone_visual_params()` não tem case para `STATE_SEARCH`, cai no default (patrol params). Guard em busca parece visualmente em patrulha.

**Timeline:** Quick fix (esta sessão)

---

## Low Priority Debt 🟢

### 11. Documentation Maintenance
**Severity:** LOW — Ongoing

Docs devem refletir estado real do código. Atualização em andamento (2026-06-12).

---

### 12. Debug Code Mixed With Production
**Severity:** LOW  
**Estimated Fix:** 3–5 days

`DEV_VISION` flag e código de debug misturado com lógica. Funcional para dev, problemático para release.

---

### 13. Dead code `_compute_shadow_tiles_old()` em room.gd
**Severity:** LOW  
**Estimated Fix:** Remover imediatamente

Função antiga de shadow substituída por `_compute_shadow_tiles()` + `_cast_shadows_from_light()`. Linhas ~1340–1373 de room.gd.

---

### 14. Hardcoded noise values em room.gd
**Severity:** LOW  
**Estimated Fix:** Quick fix

`room.gd` usa `0.20` e `0.5` hardcoded em vez de `NoiseSystem.NOISE_CHANCE_WALK` / `NoiseSystem.NOISE_INTENSITY_WALK`.

---

## Planned Refactors

| Refactor | Prioridade | Target | ETA |
|----------|-----------|--------|-----|
| **Detection escalation gradual** | 🔴 Pré-playtest | guard_enemy.gd + room.gd | 1–2 semanas |
| **FSM → Strategy/BTree** | Pré-M3.0 | guard_enemy.gd | 1–2 semanas |
| **Patrol data-driven** | Pré-campanha | room_layout_builder.gd | 3–5 dias |
| **Overlay O(n²) → culled** | Pré-mobile test | fog_of_war_overlay.gd | 1–2 semanas |
| **move_to_cell_animated coroutine** | Pré-3+ guards | guard_enemy.gd | 1–2 dias |

---

## Debt Metrics (atualizado 2026-06-14)

| Metric | Value |
|--------|-------|
| **Resolved Items** | 4 (detection escalation, state_search visual, dead code, hardcoded noise) |
| **Critical Issues** | 4 |
| **High Priority Issues** | 4 |
| **Medium Priority Issues** | 2 |
| **Low Priority Issues** | 4 |
| **Esforço Total Estimado** | 8–12 semanas (refinamento, não blocking) |
| **Current Debt Level** | Médio — jogo funcional, detecção IA implementada corretamente |

---

## Debt Management Policy

1. **Critical debt** endereçado antes de playtesting externo
2. **High-priority debt** queued para pós-Investor Demo
3. **Medium/Low-priority debt** durante polish phase

---

**Last Updated:** 2026-06-12  
**Maintained By:** Technical Lead  
**Status:** Funcional com limitações conhecidas
