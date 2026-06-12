# INFILTRAITOR — Technical Debt & Maintenance

> **Known limitations, architectural issues, and maintenance requirements.**

---

## Definition

Technical debt is code/architecture that:
- Compromises scalability
- Reduces maintainability
- Creates bugs or instability
- Limits future features

**Debt ≠ Backlog.** Debt is unfinished work that blocks progress.

---

## Critical Debt 🔴 (Bloqueia escalabilidade futura)

### 1. Detection Escalation é Binária (sem gradação SUSPICIOUS)

**Severity:** HIGH  
**Impact:** HIGH — design intent não refletido em código  
**Estimated Fix:** 1–2 semanas

**Problem:**  
O `guard.detection` meter acumula corretamente, mas nunca é usado para transições de estado. Quando `TicSystem` retorna `detected=true`, `_apply_tic_result` chama:

```gdscript
guard.observe_player(true, 2, agent.cell)   ## severity sempre 2
```

O que resulta em `_enter_state(STATE_ALERT)` imediato — sem passar por `STATE_SUSPICIOUS`.  

Consequência: qualquer frame de detecção bem-sucedida lança o guard direto para ALERT. O detection meter existe no guard e acumula visualmente, mas não conduz transições.

**Design Intent:**  
PATROL → SUSPICIOUS (baixa detecção) → ALERT (alta detecção) → CHASE

**Current Behavior:**  
PATROL → ALERT (qualquer detecção bem-sucedida, independente de probabilidade)

**Solution (ID-01 — Investor Demo):**  
- Conectar detection meter às thresholds de estado: 0.30 = SUSPICIOUS, 0.60 = ALERT, 1.00 = CHASE
- Substituir `observe_player(severity=2)` hardcoded por `accumulate_detection(gain)` com transições baseadas em threshold
- Audio detection (via `hear_noise`) já tem thresholds — unificar o modelo

**Timeline:** Antes de playtesting externo

---

### 2. FSM Scaling Risk
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

## Debt Metrics (atualizado 2026-06-12)

| Metric | Value |
|--------|-------|
| **Critical Issues** | 4 |
| **High Priority Issues** | 4 |
| **Medium Priority Issues** | 2 |
| **Low Priority Issues** | 4 |
| **Esforço Total Estimado** | 8–12 semanas |
| **Current Debt Level** | Médio — jogo funcional, design intent parcialmente realizado |

---

## Debt Management Policy

1. **Critical debt** endereçado antes de playtesting externo
2. **High-priority debt** queued para pós-Investor Demo
3. **Medium/Low-priority debt** durante polish phase

---

**Last Updated:** 2026-06-12  
**Maintained By:** Technical Lead  
**Status:** Funcional com limitações conhecidas
