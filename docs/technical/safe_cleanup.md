# Safe Cleanup & Deprecation Checklist

> **Explicit list of what can be safely removed, what must be archived, and what needs review.**

---

## Purpose

Prevent accidental destruction while enabling planned cleanup:
- Clear safety guidelines for each item
- Audit trail for removal decisions
- Blocking criteria for risky items

---

## Safe to Delete (No Risk)

**These can be removed immediately (or archived for history):**

| Item | Location | Reason | Validation |
|------|----------|--------|-----------|
| `.DS_Store` | Any | System files | Auto-ignored by git |
| `*.pyc`, `*.pyo` | Any | Python cache | Regenerable |
| `.godot/` cache | Any | Godot cache | Regenerable |
| `export/` folder | Any | Build output | Regenerable |
| `__pycache__/` | Any | Python cache | Regenerable |
| Old debug scripts | tools/experimental/ | Test-only | Check git log |

**Action:** Delete without review (already gitignored or regenerable)

---

## Safe to Archive (Low Risk)

**These should be archived to history/ or tools/archive/, not deleted:**

| Item | Location | Archive Path | Reason |
|------|----------|------|--------|
| PROGRESS.md | DEVELOPMENT/ | docs/history/sprint_logs/ | ✅ Done |
| REFACTOR_SPRINT_04.md | DEVELOPMENT/ | docs/history/refactor_logs/ | ✅ Done |
| GAME_PLAN.md | DEVELOPMENT/ | docs/history/design_decisions/ | ✅ Done |
| DEV_VISION_FOUNDATION.md | DEVELOPMENT/ | docs/history/deprecated_design/ | ✅ Done |
| Tileset scripts | tools/migration/ | Preserved | ✅ Done |
| `_step_toward()` code | guard.gd | Git history | Before M2-15 |
| Old patrol methods | guard.gd | Git history | Before M2-15 |
| Legacy animation code | guard.gd | Git history | After An-01 |

**Action:** Move to archive, preserve git history, reference from README

---

## Needs Review (Medium Risk)

**These require design decision before removal:**

| Item | Location | Risk | Reviewer | Decision Needed |
|------|----------|------|----------|---|
| Cover hint system | overlays.gd | Medium | Design Lead | Redesign timeline? Replace or remove? |
| Hardcoded patrol waypoints | room.gd | Medium | Design Lead | Generalize or keep for legacy? |
| Rectangular FOV remnants | detection.gd | Low | Tech Lead | Already removed? Check. |
| Movement overlay code | overlays.gd | Medium | UI Lead | Duplicate with new system? |
| OPERATOR CONTEXT.md | docs/technical/ | Low | DevOps Lead | Useful or obsolete? |

**Action:** Convene for decision, document reasoning, create ticket

---

## Protected (Keep Always)

**These must never be deleted (actively used or irreplaceable):**

| Item | Location | Reason |
|------|----------|--------|
| `project.godot` | root | Project definition |
| All godot/ source | godot/scripts/ | Game engine |
| All ASSETS/ | ASSETS/ | Game content |
| All docs/ | docs/ | Documentation |
| .git history | .git/ | Version control |
| README.md | root | Landing page |
| tools/persistent/ | tools/ | Active utilities |

**Action:** Never touch these

---

## Cleanup Workflow (By Risk Level)

### Low Risk (Delete/Archive Immediately)
```
Item → Archive or Delete → Git Commit → Done
```

**Examples:**
- Cache files (delete)
- Old scripts (archive)
- Build outputs (delete)

### Medium Risk (Design Review Required)
```
Item → Identify Reviewer → Get Decision → Archive/Delete → Git Commit
```

**Examples:**
- Overlay systems
- Deprecated algorithms
- Legacy patterns

### High Risk (Extended Review)
```
Item → Full Technical Audit → Design Review → Refactoring Plan → Archive/Delete → Git Commit
```

**Examples:**
- FSM scaling
- Performance-critical code
- Complex interdependencies

---

## Current Cleanup Status

### ✅ Completed

- [x] Tileset scripts → tools/migration/ (commit 0023af9)
- [x] DEVELOPMENT docs → docs/history/ (this sprint)
- [x] PHASE3_COMPLETE.md → docs/history/ (this sprint)
- [x] BACKUP.py → tools/persistent/ (commit 8651ee3)

### 🟡 In Review

- [ ] Cover hint system (awaiting design decision)
- [ ] Guard patrol waypoints (awaiting consolidation decision)
- [ ] OPERATOR CONTEXT.md (awaiting ownership decision)

### ⏳ Planned

- [ ] Remove `_step_toward()` (M2-15)
- [ ] Archive old patrol methods (M2-15)
- [ ] Consolidate legacy constants (M2-15)
- [ ] Profile + optimize overlays (M2-15)

---

## Approval Matrix

| Action | Authority | Timeline | Documentation |
|--------|-----------|----------|---|
| Delete build artifacts | Anyone | Immediate | Auto (gitignored) |
| Archive code | Tech Lead | Before sprint close | Git commit |
| Deprecate API | Design Lead | 1 sprint warning | Code comments |
| Remove protected code | Project Lead + Team | Rarely | RFC + vote |

---

## Safety Checks (Before Any Removal)

**Always verify:**

1. ✅ **No references:** `grep -r "old_thing" --include="*.py" --include="*.gd" .`
2. ✅ **Git history:** Check 5 most recent commits for usage
3. ✅ **Tests pass:** If removing code, tests still pass
4. ✅ **Team consensus:** At least one review (if medium-risk)
5. ✅ **Commit message:** Reference reason + decision + timeline

---

## Emergency Recovery

**If something was deleted accidentally:**

1. Check git log for commit
2. Recover via: `git checkout <commit> -- <file>`
3. Create issue documenting what happened
4. Add to protected list if applicable

---

## Metrics

### Cleanup Progress

| Metric | Baseline | Target | Current | Status |
|--------|----------|--------|---------|--------|
| Dead code (lines) | ~300 | <100 | TBD | ⏳ |
| Deprecated APIs | 2-3 | 0 | 2-3 | ⏳ |
| Known hacks | 3-5 | 0-1 | 3-5 | ⏳ |
| Archived items | 0 | 10+ | 10+ | ✅ |
| Protected items | 7 | 7 | 7 | ✅ |

---

## References

- [Legacy Report](legacy_report.md) — What's deprecated
- [Archive Policy](archive_policy.md) — How to deprecate
- [Repository Structure](repo_structure.md) — Where things live
- [Technical Debt](technical_debt.md) — What needs fixing

---

**Last Updated:** 2026-06-12  
**Maintained By:** Technical Lead  
**Review Frequency:** Quarterly  
**Status:** Active 🟢
