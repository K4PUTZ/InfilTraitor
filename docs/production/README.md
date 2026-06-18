# INFILTRAITOR — Production Documentation

> **Production tracking, roadmap, risk management, and development pipeline.**

---

## Quick Navigation

### 📊 Status & Tracking
- **[Production Dashboard](dashboard.md)** — Quick project status snapshot
- **[Current State](current_state.md)** — Detailed status by domain
- **[Systems Matrix](systems_matrix.md)** — Which systems are implemented/planned
- **[Content Matrix](content_matrix.md)** — Game content tracking
- **[Milestones](milestones.md)** — Detailed milestone status
- **[Not Yet Started](not_yet_started.md)** — Explicit list of unstarted systems

### 📈 Planning & Analysis
- **[Roadmap](roadmap.md)** — Development phases, gates, and dependencies (single source for phases)
- **[Development Pipeline](development_pipeline.md)** — Feature development process
- **[Methodology](METHODOLOGY.md)** — ID nomenclature, domain enum, doc ownership

### ⚠️ Risk & Debt Management
- **[Risk Assessment](risk_assessment.md)** — Systemic risks and mitigation
- **[Technical Debt](technical_debt.md)** — Known issues and refactors

### 🎬 Domain Tracking
- **[Audio Pipeline](audio_pipeline.md)** — Sound design and music roadmap
- **[Animation Pipeline](animation_pipeline.md)** — Character animation tracking
- **[Narrative Pipeline](narrative_pipeline.md)** — Story and world-building

---

## 📍 Document Map

```
production/
├── README.md                    ← You are here
├── dashboard.md                 ← START HERE for quick status
├── current_state.md            → Detailed status by domain
├── systems_matrix.md           → Systems implementation table
├── content_matrix.md           → Game content inventory
├── milestones.md               → Detailed milestone tracking
├── not_yet_started.md          → Explicitly unstarted systems
├── roadmap.md                  → Development phases (single source for phases)
├── METHODOLOGY.md              → ID nomenclature + doc ownership convention
├── development_pipeline.md     → Feature development process
├── risk_assessment.md          → Risks and mitigation
├── technical_debt.md           → Known technical issues
├── audio_pipeline.md           → Audio/SFX/music tracking
├── animation_pipeline.md       → Animation/sprite tracking
└── narrative_pipeline.md       → Story/dialogue tracking
```

---

## 🎯 Reading Paths

### Path 1: "What's the current status?" (10 minutes)
1. Read **[Production Dashboard](dashboard.md)** (5 min)
2. Scan **[Current State](current_state.md)** by section (5 min)

### Path 2: "What gets built and when?" (20 minutes)
1. Read **[Roadmap](roadmap.md)** (10 min)
2. Review **[Development Pipeline](development_pipeline.md)** (10 min)

### Path 3: "What are the risks?" (15 minutes)
1. Read **[Risk Assessment](risk_assessment.md)** summary (10 min)
2. Scan **[Technical Debt](technical_debt.md)** high-priority section (5 min)

### Path 4: "What's being built right now?" (5 minutes)
1. Check **[Production Dashboard](dashboard.md)** — In-Progress section

### Path 5: "What content exists?" (10 minutes)
1. Read **[Content Matrix](content_matrix.md)** summary (10 min)

---

## 📊 Status Summary

| Category | Status | Coverage |
|----------|--------|----------|
| **Gameplay** | Beta (60%) | Turn system, movement, AI detection |
| **Audio** | Prototype (40%) | Noise grid working; SFX missing |
| **Animation** | Prototype (30%) | Framework done; sprites missing |
| **Content** | Sparse (15%) | 1 mission, 1 guard, 1 tileset |
| **Narrative** | Not Started (0%) | Deprioritized until gameplay stable |
| **Overall** | Beta (60%) | Core systems working; content sparse |

---

## 🚀 Current Phase

**Phase 1: Stealth Core Stabilization** (🟡 IN PROGRESS)  
**Target Completion:** End of M2-16  
**Gate Condition:** Playtesting approval + Performance validation

### This Sprint Focus
1. **Au-02:** Footstep/alert SFX integration
2. **An-01:** Guard sprite animation framework
3. **DOC-02:** Production tracking & dashboards (this file + 10 docs)

### Next Sprint Focus
1. Playtesting (collect feedback)
2. Performance profiling & optimization
3. Risk assessment review

---

## 📋 Key Responsibilities

| Role | Owns |
|------|------|
| **Project Manager** | This file, dashboard.md, timeline, roadmap |
| **Design Lead** | Design philosophy, system design docs, content matrix |
| **Lead Programmer** | Systems matrix, technical debt, architecture |
| **Audio Director** | Audio pipeline |
| **Animation Director** | Animation pipeline |
| **Narrative Designer** | Narrative pipeline |
| **QA Lead** | Risk assessment, testing strategy |

---

## 🔗 Links to Other Documentation

- [Vision Documentation](../vision/) — Philosophy, pillars, game concept
- [Systems Documentation](../systems/) — Detailed system specification
- [Technical Documentation](../technical/) — Architecture, implementation (to be created)
- [History Documentation](../history/) — Sprint logs, refactors (to be created)

---

## 📈 Progress Tracking

### Completed (DOC-02 Phase 1)
- ✅ Current state documentation
- ✅ Systems matrix
- ✅ Content matrix
- ✅ Technical debt tracking
- ✅ Risk assessment
- ✅ Development pipeline
- ✅ Audio pipeline
- ✅ Animation pipeline
- ✅ Narrative pipeline
- ✅ Production dashboard
- ✅ "Not Yet Started" systems documentation

### Next (DOC-02 Phase 2)
- ⏳ Git commit with all DOC-02 changes
- ⏳ Milestone reorganization by domain (future)
- ⏳ Backlog documentation (future)

---

## 🎓 How to Use This Documentation

### For Project Managers
- Start with **[Production Dashboard](dashboard.md)** for daily status
- Use **[Roadmap](roadmap.md)** for phase planning
- Check **[Risk Assessment](risk_assessment.md)** weekly

### For Programmers
- Read **[Systems Matrix](systems_matrix.md)** to understand what's done
- Check **[Technical Debt](technical_debt.md)** for issues to fix
- Use **[Development Pipeline](development_pipeline.md)** for feature process

### For Designers
- Review **[Current State](current_state.md)** for gameplay status
- Check **[Content Matrix](content_matrix.md)** for planned content
- Read **[Narrative Pipeline](narrative_pipeline.md)** for story tracking

### For Audio/Animation
- Use **[Audio Pipeline](audio_pipeline.md)** for sound tracking
- Use **[Animation Pipeline](animation_pipeline.md)** for animation tracking

### For QA
- Read **[Risk Assessment](risk_assessment.md)** for what to test
- Check **[Technical Debt](technical_debt.md)** for known issues
- Use **[Development Pipeline](development_pipeline.md)** for testing process

---

## 📢 Announcements

None at this time. Project proceeding nominally.

---

## ⏰ Update Frequency

| Document | Frequency | Maintainer |
|-----------|-----------|-----------|
| dashboard.md | Daily | Project Manager |
| current_state.md | Weekly | Project Manager |
| systems_matrix.md | Weekly | Lead Programmer |
| content_matrix.md | As content added | Content Manager |
| milestones.md | Weekly | Project Manager |
| technical_debt.md | Bi-weekly | Lead Programmer |
| risk_assessment.md | Bi-weekly | Project Manager |
| Others | Monthly or as needed | Domain Owner |

---

## 📞 Questions or Concerns?

Refer to the document maintainer listed above, or contact the Project Manager for overall direction.

---

**Last Updated:** 2026-06-11  
**Maintained By:** Project Management  
**Status:** Active 🟢
