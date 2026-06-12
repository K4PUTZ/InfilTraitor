# Documentation Ownership & Responsibility Matrix

> **Formal authority over each documentation domain.**

---

## Purpose

Eliminate ambiguity about:
- "Where does this document belong?"
- "Who maintains this?"
- "What goes in systems docs vs production?"

---

## Core Rule

**Single Source of Truth (SSOT):** Each topic has exactly ONE official location.

---

## Ownership Matrix

### Vision & Philosophy

| Topic | Official Location | Owner | Frequency |
|-------|---|---|---|
| Game Concept | `docs/vision/game_vision.md` | Design Lead | Quarterly |
| Design Philosophy | `docs/vision/design_philosophy.md` | Design Lead | Quarterly |
| Project Pillars | `docs/vision/pillars.md` | Design Lead | Quarterly |
| Documentation Principles | `docs/vision/documentation_principles.md` | Docs Lead | Annually |

**Rules:**
- Vision is aspirational (long-term)
- Philosophy is normative (how we work)
- No tactical/sprint info here
- Link to production/systems for implementation

---

### Systems (How Things Work)

| System | Official Location | Owner | Status |
|--------|---|---|---|
| Movement | `docs/systems/movement.md` | AI Programmer | Current impl + planned |
| Perception | `docs/systems/perception.md` | AI Programmer | Current impl + planned |
| Lighting | `docs/systems/lighting.md` | Graphics Programmer | Current impl + planned |
| Noise & Audio | `docs/systems/noise.md` | Audio Programmer | Current impl + planned |
| Stealth | `docs/systems/stealth.md` | Design Lead | Current impl + planned |
| AI & Behavior | `docs/systems/ai.md` | AI Programmer | Current impl + planned |

**Rules:**
- Describes *current* implementation in detail
- Includes parameters, thresholds, formulas
- Explicitly separates "Current" from "Planned Extensions"
- No roadmap or timeline info (that goes in production/development_pipeline.md)
- No history (that goes in docs/history/)

---

### Production & Development

| Topic | Official Location | Owner | Frequency |
|---|---|---|---|
| Vision & Roadmap | `docs/production/roadmap.md` | Project Manager | Quarterly |
| Current Status | `docs/production/current_state.md` | Project Manager | Weekly |
| Systems Matrix | `docs/production/systems_matrix.md` | Tech Lead | Weekly |
| Content Matrix | `docs/production/content_matrix.md` | Content Manager | Weekly |
| Milestones | `docs/production/milestones.md` | Project Manager | Weekly |
| Development Pipeline | `docs/production/development_pipeline.md` | Project Manager | As needed |
| Technical Debt | `docs/production/technical_debt.md` | Tech Lead | Bi-weekly |
| Risk Assessment | `docs/production/risk_assessment.md` | Project Manager | Bi-weekly |
| Audio Pipeline | `docs/production/audio_pipeline.md` | Audio Director | Monthly |
| Animation Pipeline | `docs/production/animation_pipeline.md` | Animation Director | Monthly |
| Narrative Pipeline | `docs/production/narrative_pipeline.md` | Narrative Designer | Monthly |
| Not Yet Started | `docs/production/not_yet_started.md` | Design Lead | Sprint-by-sprint |

**Rules:**
- Production docs answer: "What are we building and when?"
- Roadmap drives the systems roadmap
- Systems status reflects what's actually done
- No implementation details (that's systems/)
- Timeline and phases defined here
- Risk management here, not in systems

---

### Technical (How to Build It)

| Topic | Official Location | Owner | Frequency |
|---|---|---|---|
| Repository Structure | `docs/technical/repo_structure.md` | DevOps Lead | Annually (or on structural change) |
| Archive Policy | `docs/technical/archive_policy.md` | DevOps Lead | Annually |
| Legacy Report | `docs/technical/legacy_report.md` | Tech Lead | Quarterly |
| Safe Cleanup | `docs/technical/safe_cleanup.md` | Tech Lead | Quarterly |
| Documentation Ownership | `docs/technical/documentation_ownership.md` | Docs Lead | Annually |
| Architecture (Future) | `docs/technical/architecture.md` | Lead Architect | Quarterly |
| Godot Setup (Future) | `docs/technical/godot_setup.md` | Engine Lead | As needed |
| Performance (Future) | `docs/technical/performance.md` | Tech Lead | Quarterly |
| Asset Map | `docs/technical/ASSET_MAP.md` | Art Lead | Quarterly |

**Rules:**
- Technical docs answer: "How do I build/maintain/extend this?"
- Architecture describes system interactions
- Setup docs are operational
- Reporting focuses on debt/legacy/risk

---

### History (What Happened)

| Topic | Official Location | Owner | Frequency |
|---|---|---|---|
| Sprint Logs | `docs/history/sprint_logs/` | Project Manager | Per-sprint |
| Refactor History | `docs/history/refactor_logs/` | Tech Lead | Per-refactor |
| Design Decisions | `docs/history/design_decisions/` | Project Lead | As decisions made |
| Deprecated Design | `docs/history/deprecated_design/` | Docs Lead | As archived |
| PHASE3_COMPLETE | `docs/history/PHASE3_COMPLETE.md` | Project Manager | Historical |

**Rules:**
- History docs are *read-only* (mostly)
- Never active project work (live docs only)
- Reference for understanding past decisions
- Preserve for rollback/learning
- Organized by type + date

---

## Decision Tree: Where Does This Document Go?

```
Does it describe a VISION or PRINCIPLE?
  → YES: docs/vision/
  → NO: Next question

Does it describe HOW A SYSTEM WORKS?
  → YES: docs/systems/
  → NO: Next question

Does it describe WHAT WE'RE BUILDING and WHEN?
  → YES: docs/production/
  → NO: Next question

Does it describe HOW TO DEVELOP/MAINTAIN?
  → YES: docs/technical/
  → NO: Next question

Is it HISTORICAL (past work)?
  → YES: docs/history/
  → NO: Rethink - it might not need to exist

If multiple fit: Choose the MOST SPECIFIC one
(e.g., "AI Future Work" goes in systems/ai.md "Planned Extensions", not production/)
```

---

## Common Mistakes & Corrections

### ❌ Mistake: Mixing Implementation Details in Production Docs

**Example:** `docs/production/milestones.md` lists cone angles and detection ranges

**Fix:** Move technical details to `docs/systems/perception.md`  
`docs/production/milestones.md` should say: "M2-01: Perception System Complete (see docs/systems/perception.md)"

---

### ❌ Mistake: Mixing Roadmap in Systems Docs

**Example:** `docs/systems/ai.md` says "We plan to add personality variance in M3-02"

**Fix:** Move to `docs/production/not_yet_started.md` or development_pipeline.md  
`docs/systems/ai.md` should say: "Future: Personality variance (see not_yet_started.md)"

---

### ❌ Mistake: Storing Current Status in History

**Example:** Keeping `PROGRESS.md` active in DEVELOPMENT/

**Fix:** Move to `docs/history/sprint_logs/`  
Reference latest status from `docs/production/current_state.md` instead

---

### ❌ Mistake: No Ownership Defined

**Example:** Three people editing `docs/systems/ai.md` with conflicting info

**Fix:** AI Programmer owns it (from matrix above)  
Others submit PRs; AI Programmer reviews + merges

---

## Handoff Rules

### When Handing Off Ownership

1. **Document the transition:** Add note to old doc
2. **Create redirect:** Link to new owner's location
3. **Update matrix:** Mark in this document
4. **Archive old:** Move to history if needed
5. **Notify team:** Slack + standup

---

### Example: "Design Lead Takes Over AI Docs"

**Before:**
```
AI Programmer owns docs/systems/ai.md
```

**Transition:**
```
# docs/systems/ai.md
**Ownership Transfer (2026-06-XX):**
Transitioning from AI Programmer → Design Lead
Due to: [reason]
Old docs: See docs/history/ai_old_owner.md
```

**After:**
```
Design Lead owns docs/systems/ai.md
Update this matrix
```

---

## Writing Standards by Domain

### Vision Docs
- Future-oriented
- Timeless (don't date)
- Aspirational
- Philosophy-driven

### Systems Docs
- Current + planned
- Explicit about both
- Technical details OK
- Parameters, formulas, thresholds
- No timeline (reference production docs)

### Production Docs
- Timeline-focused
- Status-focused
- Strategic prioritization
- Risk + opportunity
- Link to systems for details

### Technical Docs
- How-to oriented
- Operational procedures
- Reference architecture
- Troubleshooting
- No philosophy (that's vision)

### History Docs
- Immutable (mostly)
- Timestamped
- Explanatory (why?)
- Rollback references

---

## Update Frequency Commitments

| Domain | Minimum | Owner | Review |
|--------|---------|-------|--------|
| Vision | Quarterly | Design Lead | Project Lead |
| Systems | Monthly | System Owner | Tech Lead |
| Production | Weekly | Project Manager | Project Lead |
| Technical | Quarterly | Tech Lead | DevOps Lead |
| History | Per-event | Event Owner | Docs Lead |

---

## Conflict Resolution

**If two docs seem to own the same topic:**

1. **Clarify:** Which aspect?
   - Vision? → docs/vision/
   - Implementation? → docs/systems/
   - Timeline? → docs/production/
   - How-to? → docs/technical/

2. **Split:** If truly dual-aspect, create summary + link
   - Main location is SSOT
   - Other locations reference + link

3. **Escalate:** If ambiguous, ask Project Lead

---

## Examples: Where Should This Go?

### Example 1: "Guard Detection Cone Redesign"

**Question:** Should this go in systems or production?

**Answer:** Split
- **systems/ai.md:** New detection formula, parameters, pseudocode
- **production/development_pipeline.md:** Timeline, dependencies, blockers
- **production/milestones.md:** "A2-04: Guard Cone Redesign"

**Link:** Cross-reference between them

---

### Example 2: "We're Removing Old Patrol Code"

**Question:** Systems, Technical, or History?

**Answer:**
- **technical/legacy_report.md:** What code exists and why
- **technical/safe_cleanup.md:** When + how to remove it
- **history/refactor_logs/:** Document after removal explaining the process

---

### Example 3: "Guard Now Has Personality Variance"

**Question:** Where does this go?

**Answer:**
- **systems/ai.md:** Implementation details + parameters
- **production/systems_matrix.md:** Status update to "Implemented"
- **production/current_state.md:** AI system status updated
- **history/sprint_logs/:** This sprint's work documented

---

## Migration from DEVELOPMENT/

| Document | From | To | Owner | Status |
|----------|------|----|----|---|
| PROGRESS.md | DEVELOPMENT/ | docs/history/sprint_logs/ | PM | ✅ Done |
| REFACTOR_SPRINT_04.md | DEVELOPMENT/ | docs/history/refactor_logs/ | Tech | ✅ Done |
| GAME_PLAN.md | DEVELOPMENT/ | docs/history/design_decisions/ | Design | ✅ Done |
| PHASE3_COMPLETE.md | docs/systems/ | docs/history/ | PM | ✅ Done |
| ASSET_MAP.md | DEVELOPMENT/ | docs/technical/ | Art | ✅ Done |
| LIGHTING_DESIGN.md | DEVELOPMENT/ | docs/history/deprecated_design/ | Graphics | ✅ Done |

**Remaining:** OPERATOR CONTEXT.md (needs decision on utility)

---

## References

- [Repository Structure](repo_structure.md) — Folder organization
- [Archive Policy](archive_policy.md) — How to manage old docs
- [Vision](../vision/) — All vision docs
- [Systems](../systems/) — All systems docs
- [Production](../production/) — All production docs

---

**Last Updated:** 2026-06-12  
**Maintained By:** Documentation Lead  
**Approval Required:** For ownership changes  
**Status:** Active 🟢
