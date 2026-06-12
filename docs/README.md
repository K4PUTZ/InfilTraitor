# INFILTRAITOR — Documentation Hub

> **Central index for all INFILTRAITOR design, technical, and production documentation.**

Welcome to the INFILTRAITOR documentation system. This repository is organized into five main categories: **Vision**, **Systems**, **Production**, **Technical**, and **History**.

---

## 📖 Quick Navigation

### 🎯 Vision (Start Here)
*What the game is, why it exists, and what makes it unique.*

- **[Game Vision](vision/game_vision.md)** — High-level concept, pillars, and player experience
- **[Design Philosophy](vision/design_philosophy.md)** — Invariable principles guiding all decisions
- **[Design Pillars](vision/pillars.md)** — Seven pillars defining the gameplay experience

**Best for:** Understanding the "what" and "why" of INFILTRAITOR

---

### ⚙️ Systems (How It Works)
*Detailed documentation of individual game systems.*

#### Perception & Detection
- **[Perception System](systems/perception.md)** — Visual cones, audio detection, attention, and scanning (to be created)

#### Environment & Visibility
- **[Lighting & Shadows](systems/lighting.md)** — Baked shadows, light propagation, tactical visibility (to be created)
- **[Noise Propagation](systems/noise.md)** — Sound propagation, decay, and audio perception (to be created)

#### Gameplay Mechanics
- **[Movement & Turn System](systems/movement.md)** — Grid navigation, AP economy, and turn resolution (to be created)
- **[Stealth & Detection](systems/stealth.md)** — FOW, cover, and detection mechanics (to be created)

#### AI & Behavior
- **[Enemy AI & Behaviors](systems/ai.md)** — Guard FSM, states, and decision-making (to be created)

#### Future Systems
- **[Combat System](systems/combat.md)** — Combat resolution, damage, tactics (planned, to be created)
- **[Progression & Advancement](systems/progression.md)** — Character progression, upgrades, skills (planned, to be created)

**Best for:** Understanding how systems work and interact

---

### 📋 Production (What Gets Built)
*Development roadmap, milestones, and production workflow.*

- **[Roadmap](production/roadmap.md)** — Macro-level development phases and timeline
- **[Milestones](production/milestones.md)** — Detailed, executable milestone list with status
- **[Backlog](production/backlog.md)** — Low-priority features and future ideas (to be created)
- **[Pipeline](production/pipeline.md)** — Production workflow and department collaboration (to be created)

**Best for:** Understanding what gets built and when

---

### 🔧 Technical (The Implementation)
*Architecture, code organization, and technical decisions.*

- **[Architecture](technical/architecture.md)** — High-level system architecture and data flow (to be created)
- **[Godot 4.6 Setup](technical/godot_setup.md)** — Engine configuration, project structure (to be created)
- **[Performance Guidelines](technical/performance.md)** — Optimization targets and profiling (to be created)

**Best for:** Understanding the technical implementation and making architectural decisions

---

### 📜 History (What Happened)
*Development history, refactors, and archived decisions.*

#### Sprint Logs
- **[Sprint Logs](history/sprint_logs/)** — Chronological development updates and progress tracking

#### Refactoring & Technical Debt
- **[Refactor Logs](history/refactors/)** — Major refactors, architectural changes, and lessons learned

**Best for:** Tracing decisions over time and learning from past iterations

---

## 📍 Document Responsibility Matrix

| Document | Responsibility | Last Updated | Maintainer |
|----------|-----------------|--------------|-----------|
| Game Vision | What the game is | 2026-06-11 | Design Lead |
| Design Philosophy | Principles guiding design | 2026-06-11 | Design Lead |
| Design Pillars | Seven pillars of gameplay | 2026-06-11 | Design Lead |
| Roadmap | Development timeline | 2026-06-11 | Project Manager |
| Milestones | Executable task list | 2026-06-11 | Project Manager |
| Perception System | How detection works | (to be created) | Lead Programmer |
| Lighting & Shadows | Shadow systems | (to be created) | Graphics Programmer |
| Noise System | Audio propagation | (to be created) | Audio Programmer |
| Architecture | System design | (to be created) | Lead Architect |
| History | Development record | (to be created) | Project Manager |

---

## 🎓 Reading Paths

### Path 1: New Team Member (3–4 hours)
1. Read **Game Vision** (15 min)
2. Read **Design Philosophy** (20 min)
3. Read **Design Pillars** (20 min)
4. Skim **Roadmap** (15 min)
5. Read relevant **Systems Docs** (1–2 hours depending on role)
6. Read **Architecture** (20 min)

### Path 2: Design Iteration (30–60 min)
1. Check **Current Milestones** for status
2. Review **Design Philosophy** for constraint validation
3. Review relevant **Systems Docs** for interaction points
4. Update **Design Pillar** implications if needed

### Path 3: Technical Implementation (1–2 hours)
1. Review **Architecture** for structure
2. Read relevant **Systems Docs** for behavior specification
3. Check **Technical Guidelines** for performance/code standards
4. Review **Refactor History** for past decisions

### Path 4: Production Oversight (30 min)
1. Check **Milestones** for current status
2. Review **Roadmap** for timeline and dependencies
3. Check **Blocker List** for risks
4. Review **Production Pipeline** for workflow

---

## ✏️ Contributing to Documentation

### Guidelines
1. **Keep documents focused** — One responsibility per document
2. **Avoid duplication** — Link to other docs rather than repeating
3. **Use clear headers** — Hierarchical structure with ## ## ### ### #### #####
4. **Add examples** — Concrete examples clarify abstract concepts
5. **Update responsibly** — Always note who, what, when in document headers
6. **Link thoroughly** — Cross-references between related documents

### When to Create a New Document
- A system needs standalone documentation
- A topic is >3000 words (consider splitting)
- Multiple people need to reference it regularly
- It has a distinct lifecycle (e.g., sprint logs)

### When to Update an Existing Document
- New feature added to system
- Design decision changes
- Milestone status changes
- Link is broken

---

## 📊 Documentation Status

| Category | Completion | Status |
|----------|-----------|--------|
| Vision | 100% | ✅ Complete |
| Systems | 0% | 🟡 In Progress |
| Production | 100% | ✅ Complete |
| Technical | 0% | ⏳ Queued |
| History | 0% | ⏳ Queued |
| **Overall** | **40%** | **🟡 In Progress** |

---

## 🗺️ Directory Structure

```
docs/
├── README.md                    ← You are here
├── vision/
│   ├── game_vision.md
│   ├── design_philosophy.md
│   └── pillars.md
├── systems/
│   ├── perception.md            (to create)
│   ├── lighting.md              (to create)
│   ├── noise.md                 (to create)
│   ├── movement.md              (to create)
│   ├── stealth.md               (to create)
│   ├── ai.md                    (to create)
│   ├── combat.md                (planned)
│   └── progression.md            (planned)
├── production/
│   ├── roadmap.md
│   ├── milestones.md
│   ├── backlog.md               (to create)
│   └── pipeline.md              (to create)
├── technical/
│   ├── architecture.md           (to create)
│   ├── godot_setup.md           (to create)
│   └── performance.md           (to create)
└── history/
    ├── sprint_logs/             (to migrate)
    └── refactors/               (to migrate)
```

---

## 🔗 External References

### Repository
- **GitHub:** https://github.com/K4PUTZ/InfilTraitor.git
- **Default Branch:** `main`
- **Issues:** GitHub Issues (linked to milestones)

### Legacy Documentation
The following documents are being migrated into this structure:
- `DEVELOPMENT/GAME_PLAN.md` → Consolidated into `game_vision.md`
- `DEVELOPMENT/PROGRESS.md` → Moved to `history/sprint_logs/`
- `DEVELOPMENT/LIGHTING_DESIGN.md` → Consolidated into `systems/lighting.md`
- `DEVELOPMENT/Concept/*` → Consolidated into `systems/`

---

## 📞 Contact & Questions

| Role | Question | Contact |
|------|----------|---------|
| **Project Lead** | Timeline, roadmap, priorities | Project Manager |
| **Design Lead** | Pillar alignment, mechanic validity | Design Lead |
| **Lead Programmer** | Architecture, technical feasibility | Lead Programmer |
| **System Owner** | System-specific decisions | System Owner |

---

## ⏰ Last Updated

- **Overall:** 2026-06-11
- **Vision:** 2026-06-11 ✅
- **Systems:** In progress 🟡
- **Production:** 2026-06-11 ✅
- **Technical:** Queued ⏳
- **History:** Queued ⏳

---

## 🚀 Next Steps

### This Sprint (DOC-01)
1. ✅ Create vision documentation (game_vision, design_philosophy, pillars)
2. ✅ Create production documentation (roadmap, milestones)
3. ✅ Create central index (this file)
4. ⏳ Create systems documentation (perception, lighting, noise, movement, stealth, ai)
5. ⏳ Create technical documentation (architecture, godot_setup, performance)
6. ⏳ Migrate history logs
7. ⏳ Clean up old documentation

### Future Sprints
- Add backlog documentation
- Add production pipeline documentation
- Add technical guidelines for code organization
- Add performance profiling guidelines
- Archive old DEVELOPMENT docs

---

**Last Reviewed:** 2026-06-11  
**Maintained By:** Project Management  
**Status:** Active 🟢
