# INFILTRAITOR — Legacy Code & Technical Debt Report

> **Catalog of legacy systems, deprecated code, and technical risks.**

---

## Purpose

This report documents:
- Deprecated code that still exists
- Legacy systems partially replaced  
- Temporary hacks in production
- Old APIs not yet migrated
- Risky removal candidates
- Maintenance burden items

**Goal:** Prevent accidental breakage while planning safe deprecation.

---

## Executive Summary

| Category | Count | Risk | Action |
|----------|-------|------|--------|
| Temporary Hacks | 3-5 | Medium | Investigate |
| Deprecated APIs | 2-3 | Low | Track migrations |
| Legacy Overlays | 1-2 | Medium | Evaluate removal |
| Old Constants | 5+ | Low | Consolidate |
| Legacy Patterns | 2-3 | Medium | Refactor |
| **Total** | **13-18** | **Mixed** | **Monitor** |

---

## Legacy Systems

### Overlays (UI Rendering)

**Status:** Partially deprecated  
**Location:** godot/scripts/ui/overlays/  
**Risk:** Medium (affects visual feedback)

**Items:**

| Overlay | Purpose | Status | Risk | Notes |
|---------|---------|--------|------|-------|
| Movement Overlay (old) | Show valid moves | ⚠️ Partial | Medium | May have duplicate code vs new system |
| Cover Hints | Show cover positions | ❌ Removed M2.12 | Low | Removed; prepare redesign |
| Debug Overlays | Dev visualization | ✅ Active | Low | Keep (useful for debugging) |

**Recommendation:**
- Audit movement overlay for duplication
- Mark cover hints redesign as future work (M2.15+)
- Keep debug overlays (low risk)

---

### Patrol System (Legacy)

**Status:** Replaced but old code remains  
**Location:** godot/scripts/agents/guard.gd (patrol_* methods)  
**Risk:** Low (superseded by new FSM)

**Items:**

| Component | Old | New | Status | Risk |
|-----------|-----|-----|--------|------|
| Patrol Movement | `_step_toward()` | `GuardPathfinder` | ✅ Replaced | Low |
| Patrol Generation | Manual waypoints | Dynamic generation (future) | ⚠️ Hybrid | Medium |
| Patrol Timing | Hardcoded 2.0 speed | Data-driven (M2.02) | ✅ Replaced | Low |

**Recommendation:**
- Remove dead code (`_step_toward()`, old patrol methods) - safe
- Consolidate patrol generation - needs design review
- Guard speed system is stable - keep

---

### Constants (Hardcoded Values)

**Status:** Partially consolidated  
**Location:** godot/scripts/systems/  
**Risk:** Low (low-impact refactor)

**Items:**

| Constant | Location | Type | Recommendation |
|----------|----------|------|---|
| ALERT_MAX (80) | guard.gd | Magic number | Consolidate to AgentStats |
| MAX_AP (2) | agent.gd | Magic number | Already in AgentStats ✅ |
| DETECTION_RADIUS (2) | Multiple | Magic number | Create constants.gd |
| HEARING_RADIUS (2) | Multiple | Magic number | Create constants.gd |
| SPEED_MULTIPLIERS | guard.gd | Multiple | Consolidate |

**Recommendation:**
- Create `godot/scripts/systems/game_constants.gd`
- Migrate all magic numbers (low risk, high value)
- Timeline: M2-15 or M2-16 (polish phase)

---

### Detection System (Multiple Implementations)

**Status:** Unified in M2.03+  
**Risk:** Low-Medium (fully functional, potential inconsistency)

**Items:**

| Component | Old | Current | Status |
|-----------|-----|---------|--------|
| Visual Detection | Rectangular cone | Probabilistic angular cone | ✅ M2.01 |
| Audio Detection | Simple distance | Propagation grid + walls | ✅ M2.03 |
| Attention System | Static looking | Head rotation + scanning | ✅ M2.05 |

**Recommendation:**
- All replaced; old code should be removed (safe)
- No references to old detection should exist
- Audit guard.gd for remnants

---

### Animation System

**Status:** Transitional  
**Risk:** Medium (incomplete implementation)

**Items:**

| Feature | Current | Planned | Risk |
|---------|---------|---------|------|
| Guard sprites | Tweens (basic) | AnimatedSprite2D (An-01) | Medium |
| Guard states | Hard positions | Animations per state (An-02) | Medium |
| Combat anims | None | Planned (Phase 2) | Medium |

**Recommendation:**
- Current tween system is functional placeholder
- AnimatedSprite2D coming this sprint (An-01)
- Combat animations safe to defer (Phase 2)

---

## Temporary Hacks

### Known Production Hacks

| Hack | Location | Purpose | Status | Risk | Removal |
|------|----------|---------|--------|------|---------|
| Direct position set (M2.05) | guard.gd line ~420 | Quick head rotation | ⚠️ Active | Low | Replace with tween (M2-15) |
| Hardcoded patrol waypoints | room.gd | Test layout | ⚠️ Active | Low | Generalize (future) |
| DEBUG guards visible | Multiple | Dev visualization | ⚠️ Active | None | Keep for now |

**Recommendation:**
- Mark hacks with TODO comments
- Assign removal dates (sprint, not vague)
- Don't block current development

---

## Deprecated Code (Safe to Remove)

| Code | Location | Reason | Status | Removal Date |
|------|----------|--------|--------|---|
| `_step_toward()` | guard.gd | Replaced by GuardPathfinder | Safe | M2-15+ |
| `_build_step_path_to()` | guard.gd | Dead code (removed M2.04) | Safe | Done ✅ |
| Old cover hint system | overlays.gd | Redesigned M2.12 | Safe | M2.15+ |
| Rectangular FOV code | detection.gd | Replaced by angular (M2.01) | Safe | Done ✅ |
| Legacy animation tweens | guard.gd | Replaced by AnimatedSprite2D | Safe (after An-01) | M2-15+ |

---

## High-Risk Components

### FSM Scaling Risk

**Location:** godot/scripts/agents/guard.gd (FSM)  
**Issue:** Monolithic FSM will break at 50+ states  
**Current:** 5 states (PATROL, SUSPICIOUS, ALERT, CHASE, SEARCH)  
**Future:** 10+ states planned (Combat, Alerted, Investigating, Guarding, etc.)  

**Recommendation:**
- Refactor FSM before adding new states (M2-16)
- Use hierarchical FSM or state composition
- Test with 20+ states before production

**Timeline:** M2-16 (optimization phase)

---

### Overlay Performance Risk

**Location:** godot/scripts/ui/overlays/  
**Issue:** Overlays redrawn every frame (inefficient)  
**Current:** 3-4 overlays (movement, FOW, debug)  
**Future:** 5+ overlays (objectives, dangers, gadgets, etc.)

**Recommendation:**
- Profile overlay performance (M2-15)
- Implement dirty rectangle optimization
- Cache rendering where possible

**Timeline:** M2-15 (performance phase)

---

### Content Explosion Risk

**Location:** docs/production/content_matrix.md  
**Issue:** Only 7% content exists (1 mission, 1 guard type, 1 tileset)  
**Future:** Phase 4 requires 50+ missions, 10+ guard types, 8+ tilesets

**Recommendation:**
- Create content pipeline (already done: animation_pipeline.md)
- Procedural generation as fallback (M4-01)
- Design content once, generate many times

**Timeline:** M3-00 → M4+ (content production)

---

## API Deprecations

### To Deprecate (Soon)

| API | Reason | Timeline | Replacement |
|-----|--------|----------|-------------|
| `agent.move_to_cell()` | Single-step approach | M2-15 | Path-based movement |
| `room._update_vision_fog()` | Inefficient per-tile | M2-16 | Optimized baking |
| `guard._patrol_step()` | Replaced by FSM | M2-15 | FSM states |

---

## Maintenance Burden

### Documentation Technical Debt

| Item | Scope | Effort | Priority |
|------|-------|--------|----------|
| Lighting system (complex) | Needs diagrams | 2-3h | High |
| AI decision flowchart | Missing | 3-4h | High |
| Architecture doc | Incomplete | 4-5h | Medium |

---

## Metrics

**Current State:**
- Lines of legacy code: ~200-300
- Deprecated APIs: 2-3
- Known hacks: 3-5
- Technical debt items: 12 (see technical_debt.md)

**Goal:** By end of Phase 1 (M2-16)
- Legacy code: <100 lines
- Deprecated APIs: 0
- Hacks: 0 (or explicitly marked)
- Technical debt: 8 (cleared 4 items)

---

## Action Items

### Immediate (This Sprint)
- [ ] Audit guard.gd for deprecated methods
- [ ] Create game_constants.gd
- [ ] Mark all hacks with TODO + date

### Short-term (M2-15)
- [ ] Remove dead code
- [ ] Profile overlay performance
- [ ] Refactor hardcoded patrol waypoints

### Medium-term (M2-16)
- [ ] Refactor FSM for scalability
- [ ] Optimize overlay rendering
- [ ] Consolidate animation system

### Long-term (Phase 2+)
- [ ] Procedural content generation
- [ ] Combat system (new states)
- [ ] Advanced AI behaviors

---

## References

- [Technical Debt](technical_debt.md) — Detailed issues
- [Systems Matrix](../production/systems_matrix.md) — System status
- [Guard FSM](../systems/ai.md) — AI architecture
- [Architecture](architecture.md) — System design

---

**Last Updated:** 2026-06-12  
**Maintained By:** Technical Lead  
**Status:** Active 🟢
