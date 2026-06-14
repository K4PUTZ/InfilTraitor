# INFILTRAITOR — Current Project State

> **Executive snapshot of the entire project. Onde estamos agora — com honestidade sobre o que funciona e o que não funciona.**

---

## Objetivo Atual

**Meta primária:** Investor Demo — mecânicas de jogo funcionais e polidas em uma sala de demonstração.  
Gráficos placeholder, sem áudio, sem narrativa, sem animações complexas, sem UI polida. O critério de sucesso é o *feeling*: o stealth deve ser divertido, os guards devem reagir de forma crível, e o loop de tensão deve ser perceptível para qualquer pessoa que jogar por 5 minutos.

---

## Estado da IA — O que funciona vs. o que está incompleto

O sistema de IA é **funcional mas simplificado** em relação ao design intent.

**O que funciona corretamente:**
- Guards detectam o agente probabilisticamente via `TicSystem.evaluate()`
- Quando detecção ocorre, guard escalona para `STATE_ALERT` e persegue
- `tick_state()` faz de-escalação por timer (ALERT → CHASE → SEARCH → SUSPICIOUS → PATROL)
- Audio detection via `hear_noise()` com thresholds (0.25 / 0.60)
- Comunicação entre guards (whistle / radio) funcional via signals
- Pathfinding A* correto e eficiente
- `choose_next_cell()` state-aware (comportamento por estado implementado)

**O que está simplificado vs. design intent:**
- `guard.detection` meter acumula visualmente mas **não conduz transições de estado**
- Detecção visual é **binária**: qualquer tic bem-sucedido → `STATE_ALERT` imediato (sem passar por SUSPICIOUS)
- Design intent: escalação gradual PATROL → SUSPICIOUS → ALERT via threshold do meter
- Audio detection já tem gradação; visual detection não

**Impacto real:** O jogo é jogável e reativo. Guards respondem ao agente. A falta de gradação na detecção visual pode parecer abrupta ("guard dormiu em cima do agente e de repente foi para ALERT"), mas não quebra o stealth.

---

## Global Status Overview

| Category | Status | Maturity | Progress Real |
|----------|--------|----------|---------------|
| **Core Navigation & Movement** | Funcional | Beta | 90% |
| **Turn System** | Funcional | Beta | 85% |
| **Pathfinding (A\*)** | Funcional | Production | 95% |
| **Noise System (matemático)** | Funcional | Beta | 80% |
| **Lighting & Shadows** | Funcional + Semantic Design | Alpha→Beta | 85% |
| **Fog of War** | Funcional | Beta | 80% |
| **Enemy AI / Guard FSM** | Funcional (simplificado) | Alpha | 65% |
| **Detection / Stealth** | Funcional (binário) | Alpha | 55% |
| **Perception (cálculo)** | Funcional | Beta | 75% |
| **Audio (SFX)** | Não iniciado | — | 0% |
| **Animation (sprites)** | Não iniciado | — | 0% |
| **UI/UX** | Prototype | Prototype | 30% |
| **Narrative** | Não iniciado | — | 0% |
| **Combat** | Não iniciado | — | 0% |
| **Content** | Sparse | Prototype | 15% |

---

## Maturity Definitions

- **Prototype** — Prova de conceito, pode quebrar
- **Alpha** — Core funcionando, limitações conhecidas
- **Beta** — Feature-complete, fase de refinamento
- **Production-Ready** — Polido, testado, estável

---

## By Domain

### Core Navigation & Movement (90% — Beta)
✅ **Funcional:**
- Movimento em grid 4 direções com tweening suave
- Sistema de AP (2 por turno)
- Pathfinding Dijkstra para overlay de movimento
- Pathfinding A* para guards (excelente qualidade)
- Bloqueio por paredes via WallEdgeData

❌ **Não implementado:**
- Movimento diagonal
- Terreno rugoso (modificadores de custo)

---

### Turn System (85% — Beta)
✅ **Funcional:**
- Sequência player → enemy por turno
- AP economy
- EnemyPhaseController (estrutura existe)

⚠️ **Problema:**
- EnemyPhaseController chama métodos inexistentes nos guards — a fase inimiga falha silenciosamente

---

### Enemy AI / Guard FSM (65% — Alpha, funcional)

✅ **Funcional:**
- `choose_next_cell()` state-aware (PATROL → waypoint, SUSPICIOUS/ALERT/CHASE → agente, SEARCH → fila de busca)
- `tick_state()` de-escalação por timer (ALERT→CHASE→SEARCH→SUSPICIOUS→PATROL)
- `observe_player()` escalona estado quando detecção ocorre
- `hear_noise()` com thresholds auditivos (intensidade ≥ 0.6 → SUSPICIOUS com last_known)
- Comunicação (whistle alcança 3 tiles, radio é global) — sinais conectados em `_spawn_guards`
- Pathfinding A* excelente
- `receive_alert()` com hierarquia de estados (nunca rebaixa estado)

⚠️ **Simplificado vs. design intent:**
- Detecção visual binária: qualquer tic bem-sucedido → `STATE_ALERT` imediato
- Detection meter acumula visualmente, mas não conduz transições (só feedback de debug)
- Sem SUSPICIOUS intermediário para detecção visual (somente via audio/comunicação)
- `move_to_cell_animated` é fire-and-forget: animações de múltiplos guards podem sobrepor

---

### Detection / Stealth (55% — Alpha, funcional com limitações)

✅ **Funcional:**
- Detecção visual probabilística (cone + distância + LOS + sombras + postura + cover)
- `_apply_tic_result` acumula `guard.detection` E escalona estado via `observe_player()`
- Detecção auditiva com atenuação por paredes e distância
- Guards reagem ao agente (fugir para sombras, agachar tem efeito real)
- FOW oculta guards não revelados

⚠️ **Incompleto:**
- Escalação visual é binária (detecção → ALERT diretamente, sem gradação)
- `guard.detection` meter não conduz transições (apenas visual debug)
- Curva de distância não validada com playtesters

---

### Noise System — Matemático (80% — Beta)
✅ **Funcional:**
- Noise grid persistente com decay por turno
- Emissão ~20% por passo
- Atenuação por paredes (0.6× por parede)
- Visualização (círculos cyan)
- Indicadores de direção em guards

⚠️ **Não conectado:**
- Noise calculado corretamente, mas guards não reagem (bloqueio)

---

### Lighting & Shadows (85% — Semantic Alpha, Implementation Ready)

✅ **Funcional (Runtime):**
- Projeção de cone de sombra com geometria correta
- 8 direções quantizadas
- Camadas baked (ShadowFullLayer, ShadowPartialLayer)
- Multipliers aplicados na detecção (DIRECT 0.30×, PENUMBRA 0.55×)
- Sombras visíveis mesmo sob FOW

✅ **Semantic Foundation (L-DOC Series — Completed 2026-06-14):**
- **L-DOC-01:** Lighting Taxonomy & Semantic Visibility Classes
  - 5 discrete visibility classes (FULL_LIT, DIM, PENUMBRA, SHADOW, DEEP_SHADOW)
  - Detection multiplier model (2.0× to 0.2×)
  - 7 light source types with behavior specifications
  - Separated tactical (gameplay) from visual (rendering)
- **L-DOC-02:** Vertical Lighting Topology & Height Semantics
  - 4 semantic vertical layers (L0–L3)
  - 5 discrete height classes for deterministic shadow casting
  - Shadow projection formula + 8-direction quantization
  - Shadow ownership matrix (walls cast, agents receive)
  - Runtime philosophy: grid-based, deterministic, low-overhead, gameplay-first
- **L-DOC-03:** Shadow System Calibration & Visual Polish (planned M2-14)

⚠️ **Next Phases:**
- M2-13: Geometric shadow projection & baking (implementation spec)
- M2-14: Shadow system calibration & visual polish (L-DOC-03)
- M2-15: Advanced overlays & tactical visualization (movement, noise, markers)

⚠️ **Limitações:**
- Light sources hardcoded (3 por sala, configuração fixa)
- Não customizável por sala sem editar código

---

### Fog of War (80% — Beta)
✅ **Funcional:**
- 3 camadas (unseen/peek/revealed)
- Revelação com movimento do agente
- Guards ocultados atrás do FOW

⚠️ **Dívida técnica:**
- Algoritmo O(n²) — pode ser lento em mapas grandes

---

### Perception — Cálculo (60% — Alpha)
✅ **O cálculo está correto:**
- Cone visual com ângulo, distância, e falloff lateral
- LOS verificado via WallEdgeData
- Multiplicadores: postura, sombra, cobertura, flanco

🚨 **Não conectado:**
- Resultado do cálculo não é usado para mudar estado dos guards

---

### Audio SFX (0% — Não Iniciado)
Deliberadamente deprioritizado. Noise grid matemático funciona; SFX real aguarda pós-demo.

---

### Animation / Sprites (0% — Não Iniciado)
Tweening de movimento funciona adequadamente para demo. Sprites com animações aguardam pós-demo.

---

### UI & Presentation (30% — Prototype)
✅ **Implementado:**
- Overlay de movimento (Dijkstra)
- FOW overlay
- Indicador de turno
- Display de AP
- Indicadores de noise

❌ **Não implementado:**
- Menu principal
- Settings
- Tutorial
- Tela de pausa

---

### Narrative (0% — Não Iniciado)
Intencionalmente deprioritizado. Aguarda pós-investimento.

---

### Content (15% — Prototype)
✅ **Implementado:**
- 1 sala de teste
- 1 arquétipo de guard
- 1 tileset básico

❌ **Não implementado:**
- Múltiplas salas
- Variedade de guards
- Objetivos
- Conteúdo de campanha

---

## Infrastructure & Tooling (50% — Alpha)
✅ Godot 4.6, git, documentação estruturada  
⚠️ Sem CI/CD, sem testes automatizados, sem analytics

---

## Path to Investor Demo

O jogo já é funcional. Os guards detectam e reagem. Para uma demo convincente:

| Item | Esforço | Impacto |
|------|---------|---------|
| Conectar detection meter às thresholds de estado | 1–2 semanas | Alto (game feel) |
| Tuning de curva de detecção (distância, sombra, postura) | 3–5 dias | Alto (fairness) |
| Polir sala demo (layout, patrulhas interessantes) | 3–5 dias | Alto (primeira impressão) |
| Feedback visual de estado do guard (cores do cone já mudam) | 1–2 dias | Médio |
| Testes e ajustes de dificuldade | 3–5 dias | Médio |

**Estimativa total para demo convincente: 2–4 semanas de desenvolvimento focado.**

---

**Last Updated:** 2026-06-12  
**Maintained By:** Project Management  
**Status:** BLOQUEADO — guards não reagem ao jogador
