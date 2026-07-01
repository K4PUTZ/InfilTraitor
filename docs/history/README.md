# Documentation History Index

> **Archived records of past decisions, sprints, and design evolution.**

---

## Purpose

Historical documentation is **read-only** (mostly):
- Explains "why did we decide this?"
- Preserves sprint work for reference
- Archives deprecated designs
- Maintains rollback capability

**Historical docs do NOT dictate current behavior.**  
Refer to current docs (docs/vision/, docs/systems/, docs/production/) for decisions.

---

## Implementation Logs (`*_IMPLEMENTATION_LOG.md`)

Per-system detailed implementation records:
- `VOXEL_IMPLEMENTATION_LOG.md` — VOXEL-01..11 render plane refactor (VOXEL-04 complete)

**Who:** Engineering  
**Frequency:** Per-major-system-implementation  
**Read when:** Understanding implementation phases, acceptance test results, continuation checklist

---

## Structure

### Sprint Logs (`sprint_logs/`)

Per-sprint progress and decisions:
- `PROGRESS.md` — Cumulative sprint updates
- `sprint_XX_summary.md` — Individual sprint records (future)

**Who:** Project Manager  
**Frequency:** Per-sprint  
**Read when:** Understanding sprint outcomes

---

### Refactor Logs (`refactor_logs/`)

Major code/architecture refactors:
- `REFACTOR_SPRINT_04.md` — Past refactor history
- `FSM_refactor_log.md` — FSM redesign (future, if done)

**Who:** Tech Lead  
**Frequency:** Per-major-refactor  
**Read when:** Understanding system evolution

---

### Design Decisions (`design_decisions/`)

Original design choices and rationale:
- `GAME_PLAN.md` — Original game concept + pillars
- `AI_design_choices.md` — Why FSM over behavior trees (future)
- `Perception_design_evolution.md` — Why angular cones (future)

**Who:** Design Lead  
**Frequency:** Per-major-decision  
**Read when:** Understanding design philosophy

---

### Deprecated Design (`deprecated_design/`)

Archived design docs that no longer apply:
- `DEV_VISION_FOUNDATION.md` — Early vision (superseded by docs/vision/)
- `lighting_design_legacy.md` — Old lighting spec
- Early iterations of systems

**Who:** Design Lead + Tech Lead  
**Frequency:** As designs change  
**Read when:** Understanding what was considered + rejected

---

### Specific Items

| File | Purpose | Owner | Status |
|------|---------|-------|--------|
| `PROGRESS.md` | Cumulative sprint progress | PM | ✅ Active |
| `PHASE3_COMPLETE.md` | Phase 3 completion summary | PM | ✅ Archived |
| `REFACTOR_SPRINT_04.md` | Old refactor documentation | Tech | ✅ Archived |
| `GAME_PLAN.md` | Original game vision | Design | ✅ Archived |
| `DEV_VISION_FOUNDATION.md` | Early foundation docs | Design | ✅ Archived |
| `lighting_design_legacy.md` | Legacy lighting design | Graphics | ✅ Archived |

---

## How to Use This History

### To Understand "Why Did We Choose This?"

1. Read current doc: e.g., `docs/systems/ai.md`
2. See "Design Rationale" or "Why This Approach"
3. If full history needed: `docs/history/design_decisions/GAME_PLAN.md`

---

### To Understand Sprint Outcomes

1. Check `docs/production/current_state.md` (current status)
2. If history needed: `docs/history/sprint_logs/PROGRESS.md`

---

### To Recover Deleted Code

1. Check `git log` for commit
2. If context needed: `docs/history/refactor_logs/` (why was it removed?)
3. Recover via: `git checkout <commit> -- <file>`

---

## Rules for Historical Documentation

### ✅ DO

- Document the decision + rationale
- Preserve for learning + context
- Reference history when explaining current
- Archive old docs with new docs' permission
- Date everything

### ❌ DON'T

- Use history to justify current behavior (use current docs)
- Leave orphaned history docs (clean up via documentation_ownership.md)
- Update history docs (they're immutable mostly)
- Store active project work here (that's docs/production/)

---

## Migration from DEVELOPMENT/

These items were migrated from `DEVELOPMENT/` to `docs/history/`:

| Document | From | To | Owner | Reason |
|----------|------|----|----|--------|
| PROGRESS.md | DEVELOPMENT/ | `sprint_logs/` | PM | Active history, needs reference |
| REFACTOR_SPRINT_04.md | DEVELOPMENT/ | `refactor_logs/` | Tech | Refactor documentation |
| GAME_PLAN.md | DEVELOPMENT/ | `design_decisions/` | Design | Original concept |
| DEV_VISION_FOUNDATION.md | DEVELOPMENT/ | `deprecated_design/` | Design | Foundation (superseded) |
| PHASE3_COMPLETE.md | docs/systems/ | Root of `history/` | PM | Phase completion record |
| LIGHTING_DESIGN.md | DEVELOPMENT/ | `deprecated_design/` | Graphics | Legacy design doc |

**DEVELOPMENT/ folder:** Archived (no longer active)

---

## Adding to History

### When to Create New History Docs

1. **Sprint completed:** Add summary to `sprint_logs/`
2. **Major refactor done:** Document in `refactor_logs/`
3. **Design decision finalized:** Archive old docs in `deprecated_design/`
4. **Significant system change:** Update `design_decisions/`

### Template: New Sprint Summary

```markdown
# Sprint XX Summary (YYYY-MM-DD to YYYY-MM-DD)

## Completed
- Item 1
- Item 2

## Lessons Learned
- Lesson 1

## Metrics
- Velocity: X points
- Bugs fixed: Y
- Docs added: Z

## Next Sprint Focus
- Area 1
- Area 2

**See:** docs/production/current_state.md for latest status
```

### Template: Refactor Documentation

```markdown
# FSM Refactor Log (M2-16)

## What Changed
[Describe the refactor]

## Why
[Rationale]

## Results
- Performance: X% improvement
- Code reduction: X lines removed
- New capabilities: [list]

## See Also
- Current FSM doc: docs/systems/ai.md
- Technical debt resolution: docs/technical/technical_debt.md
```

---

## Linked From Current Docs

These current docs **reference** history:

| Current Doc | History Reference | Link |
|-------------|------|------|
| `docs/vision/game_vision.md` | Original vision | `design_decisions/GAME_PLAN.md` |
| `docs/systems/ai.md` | Design choices | `design_decisions/` (future) |
| `docs/systems/lighting.md` | Evolution | `deprecated_design/lighting_design_legacy.md` |
| `docs/production/development_pipeline.md` | Past sprints | `sprint_logs/PROGRESS.md` |

---

## Archival Decisions

### Items Archived (Intentional)

- ✅ DEVELOPMENT/PROGRESS.md → Sprint logs (active reference)
- ✅ DEVELOPMENT/GAME_PLAN.md → Design decisions (learning)
- ✅ DEVELOPMENT/REFACTOR_SPRINT_04.md → Refactor logs (context)
- ✅ docs/systems/PHASE3_COMPLETE.md → History root (completion record)

### Items Pending Decision

- ⏳ DEVELOPMENT/OPERATOR_CONTEXT.md → Useful or obsolete? (needs review)
- ⏳ DEVELOPMENT/Server.rtf → Archive or discard? (needs review)
- ⏳ DEVELOPMENT/Concept/ folder → Archive or migrate? (needs review)

**See:** docs/technical/documentation_ownership.md for ownership decisions

---

## Timeline of Changes

| Date | Change | Reason | Status |
|------|--------|--------|--------|
| 2026-06-12 | Migrated DEVELOPMENT/ to docs/history/ | Consolidate architecture (DOC-03) | ✅ Done |
| Future | Add sprint summaries | Per-sprint documentation | ⏳ |
| Future | Archive old design docs | As designs change | ⏳ |

---

## Finding What You Need

**"I want to understand the original game concept"**  
→ `docs/history/design_decisions/GAME_PLAN.md`

**"I want to know what we did last sprint"**  
→ `docs/history/sprint_logs/PROGRESS.md` then `docs/production/current_state.md`

**"I want to understand why we use angular cones"**  
→ `docs/systems/ai.md` Rationale section, then `docs/history/` if needed

**"I want to recover old code"**  
→ Check `docs/history/refactor_logs/` for context, then `git log` + `git checkout`

---

## References

- [Current Vision](../vision/game_vision.md) — Active vision
- [Current Systems](../systems/) — How things work now
- [Documentation Ownership](../technical/documentation_ownership.md) — Who owns what
- [Archive Policy](../technical/archive_policy.md) — Lifecycle rules
- [Repository Structure](../technical/repo_structure.md) — Where things live

---

**Last Updated:** 2026-06-12  
**Maintained By:** Project Manager + Docs Lead  
**Status:** Archive Index 🟢

This folder preserves our project history for context, learning, and rollback capability.
