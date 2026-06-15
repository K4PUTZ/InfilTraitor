# INFILTRAITOR — System Architecture Documentation

> **Formal specification of all INFILTRAITOR gameplay systems. Establishes semantic foundation, runtime behavior, and authoring workflows for core stealth mechanics.**

**Release:** Alpha GTP Spatial Perception Foundation  
**Date:** 2026-06-14  
**Status:** 🟢 Complete & Frozen for Integration  

---

## 📊 Implementation Status (2026-06-14)

**Important:** This documentation describes the **TARGET DESIGN** for INFILTRAITOR systems. The current codebase implements **core gameplay loops** with **simplified systems** for Investor Demo phase.

### Specification vs. Current Implementation

| System | Spec Status | Implementation Status | Notes |
|--------|-------------|----------------------|-------|
| **Guard AI & Detection** | Complete (L-ARCH) | ✅ Functional (gradual escalation) | Detection uses thresholds (0.30/0.60/1.00), works as designed |
| **Shadow Projection** | Complete (L-ARCH-01) | ✅ Partial (binary lit/shadow) | No LOS calculation, no height semantics yet |
| **Exposure System** | Complete (L-ARCH-01) | 🟡 Partial (6 classes defined, 2 used) | Stability/confidence layers not populated |
| **Noise Propagation** | Complete (docs) | ✅ Functional (grid with decay) | Used by guards for audio detection |
| **Pathfinding (A*)** | Complete (docs) | ✅ Functional (optimal) | Guards and player movement both implemented |
| **Perception/LOS** | Complete (docs) | ✅ Functional (cone + distance) | Multiplicators working (cover, posture, shadows) |

### What's Ready for Integration

✅ **Complete:** AI perception, guard FSM, turn system, movement, pathfinding  
✅ **Ready:** Lighting specification (design frozen)  
🟡 **In Progress:** LOS/perception integration with lighting  
⏳ **Planned:** Dynamic lighting, advanced AI behaviors

### What's Simplified for Demo

- Shadows are binary (lit/shadow) not graduated  
- Light sources hardcoded (not data-driven)  
- Exposure classes defined but simplified in practice  
- LOS doesn't account for height semantics yet

**→ See [docs/production/current_state.md](production/current_state.md) for detailed status breakdown**

---

## Architecture Overview

INFILTRAITOR is built on **semantic-first game design**. Rather than inferring gameplay behavior from visual appearance or physics simulation, gameplay semantics are explicitly authored and systematically connected.

```
Semantic Intent → Gameplay Data → Runtime Calculation → Player Experience
   (Designer)       (Stored)      (Deterministic)     (Auditable)
```

### Core Principles

- **Semantic-Driven:** Gameplay meaning defined first, visuals applied second
- **Deterministic:** Same input always produces same output (auditability)
- **Discrete:** Finite states and classes, not continuous simulation
- **Grid-Based:** All data organized on game grid (no per-pixel)
- **Auditable:** Players and designers understand system behavior completely
- **Systemic:** All systems connect through common semantic foundation

---

## Architecture Layers

### Layer 1: Core Systems

**These systems define how the game works at fundamental level.**

#### [L-IMP-01 through L-IMP-07: Lighting Implementation Phases](systems/lighting.md)

The lighting system is the foundation for tactical stealth gameplay:

- **L-IMP-01** — Shadow Projection Foundation
- **L-IMP-02** — Exposure Mapping & Visibility Classes
- **L-IMP-03** — Risk Heatmaps & Tactical Awareness
- **L-IMP-04** — Guard Detection Integration
- **L-IMP-05** — Height Painting & Semantic Authoring
- **L-IMP-06** — Temporal Effects & Dynamic Lighting
- **L-IMP-07** — Elite Tactical Vision & Shadow Semantics

[→ Full Lighting Specification](systems/lighting.md)

#### [L-IMP-08+: Future Integration Phases](systems/lighting.md)

- **L-IMP-08** — ShadowProjector Semantic Integration
- **L-IMP-09** — AI Pathfinding & Guard Behavior Integration
- **L-IMP-10+** — Advanced Stealth Mechanics

---

### Layer 2: Architecture Specifications

**These documents formalize how systems interact and evolve.**

#### [L-ARCH-01: Lighting Runtime Pipeline & Invalidation Rules](systems/lighting_runtime_pipeline.md)

**Purpose:** Formal specification of runtime behavior and system ownership

**Defines:**
- Official pipeline flow (unidirectional data movement)
- System ownership matrix (who owns each calculation)
- 7 invalidation source patterns (when rebuilds happen)
- Rebuild philosophy (correctness over optimization)
- Overlay rules and information layers
- Performance constraints and budgets
- AI integration hooks (prepared for L-IMP-09+)

**Key Invariants:**
- ✓ Data flows downward only (LightSource → Shadow → Exposure → Gameplay)
- ✓ Each system owns ONE calculation (no duplication)
- ✓ No circular dependencies
- ✓ Auditability ensured (all decisions traceable)

[→ Full L-ARCH-01 Specification](systems/lighting_runtime_pipeline.md)

---

#### [L-ARCH-02: Occlusion Semantics & Structural Blocking Model](systems/occlusion.md)

**Purpose:** Formal specification of how structures interact with light, LOS, and future systems

**Defines:**
- 4 discrete occlusion classes (SOLID, TRANSPARENT, DIFFUSE, PERFORATED)
- Structural semantics (mapping structures to occlusion classes)
- Light & LOS interaction patterns
- Partial visibility & degradation model
- Interaction matrix (occlusion across all systems)
- Dynamic occlusion preparation (smoke, destruction, etc.)

**Key Properties:**
- ✓ SOLID blocks both light and LOS (100%)
- ✓ TRANSPARENT passes both (0% degradation)
- ✓ DIFFUSE reduces both (50% degradation)
- ✓ PERFORATED partially blocks both (50% with structure pattern)

**System Integration:**
- Lighting uses occlusion for shadow projection
- Perception uses occlusion for LOS calculation
- Future ballistics will use occlusion for cover
- Future audio will use occlusion for sound propagation

[→ Full L-ARCH-02 Specification](systems/occlusion.md)

---

#### [L-ARCH-03: Lighting Authoring Pipeline & Serialization Model](pipelines/lighting_authoring_pipeline.md)

**Purpose:** Formal specification of level design workflow and data persistence

**Defines:**
- Authoring philosophy (semantic-first design)
- Per-tile structural metadata (height, structure, occlusion, light properties)
- Height painting workflow (5-step process)
- Light placement workflow (5-step process)
- 4-tier serialization model (JSON-based persistence)
- Data ownership matrix (designer vs system)
- Mapping constraints (readability, clutter, silhouettes, strategy support)
- Future tooling specifications (height painter, light painter, validators, etc.)

**Key Workflows:**
- ✓ Height Painting: Define vertical topology independently of sprites
- ✓ Light Placement: Explicitly author tactical lighting decisions
- ✓ Serialization: Persist all semantic data in version-controlled format
- ✓ Validation: Ensure consistency across all authored data

**Data Structure:**
```
Tier 1: Map Metadata      (global level information)
Tier 2: Tile Semantics    (per-cell metadata)
Tier 3: Light Sources     (all light source definitions)
Tier 4: Structural Anchors (light socket positions)
```

[→ Full L-ARCH-03 Specification](pipelines/lighting_authoring_pipeline.md)

---

### Layer 3: Feature Specifications

**These documents define specific gameplay features.**

#### [Lighting System: Complete Specification](systems/lighting.md)

Comprehensive documentation of all lighting features:

- Visibility classes (6 levels: OCCLUDED_VOID → FULL_LIT)
- Shadow semantics and stability classification
- Exposure confidence (reliability metrics)
- Detection multipliers (how exposure affects guard perception)
- Temporal lighting effects (flicker, pulse, rotation)
- Elite tactical vision (depth, confidence, stability, contours, safe corridors)
- Future extensions (dynamic lighting, environmental effects)

[→ Full Lighting Specification](systems/lighting.md)

---

#### [Perception System: Guard Detection & Vision](systems/perception.md)

Guard vision, detection, and perception mechanics:

- Visual detection via probabilistic vision cones
- Distance and angle-based detection
- Exposure integration (how lighting affects detection)
- Occlusion integration (how structures block vision)
- Audio detection (future)
- Attention management (realistic, reactive behavior)

[→ Full Perception Specification](systems/perception.md)

---

### Layer 4: Implementation References

**These are the actual GDScript implementations.**

#### Implemented Components

**Core Lighting Systems:**
- [tile_semantics.gd](../godot/scripts/world/tile_semantics.gd) — Height and structure encoding (L-IMP-05)
- [light_anchor.gd](../godot/scripts/systems/lighting/light_anchor.gd) — Light socket placement (L-IMP-05)
- [light_source.gd](../godot/scripts/systems/lighting/light_source.gd) — Light source definition (L-IMP-06 temporal effects)
- [light_registry.gd](../godot/scripts/systems/lighting/light_registry.gd) — Light collection management
- [shadow_projector.gd](../godot/scripts/systems/lighting/shadow_projector.gd) — Shadow calculation engine
- [exposure_system.gd](../godot/scripts/systems/lighting/exposure_system.gd) — Exposure mapping & visibility classes

**Visualization Overlays:**
- [height_overlay.gd](../godot/scripts/overlays/height_overlay.gd) — Height visualization (L-IMP-05)
- [temporal_overlay.gd](../godot/scripts/overlays/temporal_overlay.gd) — Temporal effect visualization (L-IMP-06)
- [elite_exposure_overlay.gd](../godot/scripts/overlays/elite_exposure_overlay.gd) — Advanced tactical vision (L-IMP-07)

**Integration Points:**
- [room.gd](../godot/scripts/world/room.gd) — Main level manager, initializes all systems

---

## Document Hierarchy

```
ARCHITECTURE.md (this file)
├── LAYER 1: Core Systems
│   ├── systems/lighting.md (L-IMP-01 through L-IMP-07)
│   └── systems/perception.md (Guard detection)
│
├── LAYER 2: Architecture Specifications
│   ├── systems/lighting_runtime_pipeline.md (L-ARCH-01)
│   ├── systems/occlusion.md (L-ARCH-02)
│   └── pipelines/lighting_authoring_pipeline.md (L-ARCH-03)
│
├── LAYER 3: Feature Specifications
│   ├── Additional gameplay systems (future)
│   └── Mechanics documentation (future)
│
└── LAYER 4: Implementation
    ├── godot/scripts/world/
    ├── godot/scripts/systems/lighting/
    ├── godot/scripts/overlays/
    └── godot/scripts/entities/
```

---

## Quick Reference: Architecture Decisions

### Why Semantic-First?

| Question | Answer | Rationale |
|----------|--------|-----------|
| Why not visual-first? | Visuals should express gameplay meaning, not define it | Auditability: designer intent is always clear |
| Why not physics-based? | Physics doesn't match gameplay requirements | Performance: discrete calculations beat simulation |
| Why grid-based? | Consistent with game design and player understanding | Clarity: grid alignment is intuitive |
| Why discrete classes? | Continuous values create ambiguity | Auditability: "SHADOW" is clearer than 0.342 |

### Why These Systems?

| System | Purpose | Integration |
|--------|---------|-------------|
| **Lighting** | Core stealth mechanic (exposure = danger) | Detection probability determined by exposure |
| **Occlusion** | Shared semantic for all blocking | Light, LOS, sound, ballistics all use same model |
| **Authoring Pipeline** | Standardize how designers create maps | Enables team collaboration and tooling |

### Why These Invariants?

| Invariant | Prevents | Enables |
|-----------|----------|---------|
| **Downward data flow** | System coupling | Easy debugging, clear causality |
| **Single owner per calc** | Duplicate work | Optimization opportunities |
| **No circular deps** | Infinite loops | Determinism, correctness proof |
| **Auditability** | Hidden assumptions | Player understanding, designer intent |

---

## Roadmap: Future Architecture Phases

### Next Phase (L-ARCH-04): Tooling

**Scope:** Implement visual editors for authoring workflow

Tools Prepared:
- Height Painter — Visual editor for height painting
- Light Painter — Visual editor for light placement
- Semantic Validator — Map consistency verification
- Exposure Preview — Real-time exposure visualization
- Stealth Analyzer — Design readability metrics

**Entry Point:** [L-ARCH-03: Authoring Pipeline](pipelines/lighting_authoring_pipeline.md)

### Future Phase (L-ARCH-05): Content Guidelines

**Scope:** Team standards and best practices

Specifications Prepared:
- Asset naming conventions
- Spritelists and visual styles
- Level design templates
- Difficulty curves
- Narrative integration

---

## Phase Completion Summary

| Phase | Scope | Status | Key Document |
|-------|-------|--------|--------------|
| **L-IMP-01-07** | Lighting system implementation | 🟢 Complete | [lighting.md](systems/lighting.md) |
| **L-ARCH-01** | Runtime pipeline formalization | 🟢 Complete | [lighting_runtime_pipeline.md](systems/lighting_runtime_pipeline.md) |
| **L-ARCH-02** | Occlusion semantics | 🟢 Complete | [occlusion.md](systems/occlusion.md) |
| **L-ARCH-03** | Authoring pipeline formalization | 🟢 Complete | [lighting_authoring_pipeline.md](pipelines/lighting_authoring_pipeline.md) |
| **L-ARCH-04** | Tooling implementation | 🟡 Designed | [lighting_authoring_pipeline.md](pipelines/lighting_authoring_pipeline.md) (tools section) |
| **L-IMP-08+** | Advanced integration | 🟡 Designed | All L-ARCH documents |

---

## Key Files for New Contributors

**Start Here:**
1. [ARCHITECTURE.md](ARCHITECTURE.md) — This file (overview)
2. [lighting.md](systems/lighting.md) — Core system specification
3. [lighting_runtime_pipeline.md](systems/lighting_runtime_pipeline.md) — How it all works together

**For Implementation:**
1. [tile_semantics.gd](../godot/scripts/world/tile_semantics.gd) — Data encoding
2. [light_source.gd](../godot/scripts/systems/lighting/light_source.gd) — Light definition
3. [exposure_system.gd](../godot/scripts/systems/lighting/exposure_system.gd) — Main calculation engine

**For Level Design:**
1. [lighting_authoring_pipeline.md](pipelines/lighting_authoring_pipeline.md) — Design workflow
2. [occlusion.md](systems/occlusion.md) — Structural semantics
3. [lighting.md](systems/lighting.md#mapping-level-design-guides) — Design guidelines

---

## Validation Checklist

Every architecture document includes:

- ✅ Clear philosophical foundation
- ✅ Formal specification (tables, diagrams, code)
- ✅ System ownership definitions
- ✅ Integration points
- ✅ Acceptance criteria
- ✅ Future extension preparation
- ✅ Complete examples

Every implementation:

- ✅ Compiles without errors (0 compilation errors)
- ✅ Follows architecture contracts
- ✅ Is fully integrated with other systems
- ✅ Includes dev visualization support
- ✅ Is documented and auditable

---

## Document Status

**Release:** Alpha GTP Spatial Perception Foundation  
**Date:** 2026-06-14  
**Version:** 1.0  
**Status:** 🟢 Complete & Frozen for Integration  

**Frozen Meaning:**
- Core architecture is stable (no breaking changes expected)
- All systems are interconnected and tested
- Ready for content expansion
- Ready for tooling implementation
- Ready for team collaboration

**Not Frozen:**
- Future phases (L-ARCH-04+) will extend architecture
- New features will follow established patterns
- Performance optimizations will be conducted separately
- Platform-specific implementations will adapt to targets

---

## Getting Help

**Questions about architecture?**
- Refer to relevant L-ARCH document
- Check related feature specification
- Look at implementation reference code

**Need to add new feature?**
- Start with architectural principles (semantic-first)
- Follow established ownership rules
- Document design decisions
- Validate against constraints

**Need to modify existing system?**
- Verify change doesn't violate invariants
- Check all downstream systems
- Update documentation to match
- Validate against acceptance criteria

---

## Contact & Maintenance

**Architecture Lead:** Architecture / Lighting Systems  
**Last Updated:** 2026-06-14  
**Review Cycle:** Major phases (L-ARCH-04+)  
**Maintenance:** Continuous (bug fixes, clarifications)

---

## Appendix: Glossary

### Key Terms

**Occlusion Class** — Semantic classification of how structure blocks light/LOS  
**Height Class** — Semantic classification of vertical structure position  
**Tactical Energy** — Numerical representation of how dangerous light is (0.0-1.0)  
**Exposure Class** — Resulting visibility state (OCCLUDED_VOID through FULL_LIT)  
**Exposure Confidence** — Reliability metric (0.0-1.0) for exposure value  
**Shadow Stability** — Classification of shadow reliability (STATIC, TEMPORAL, DYNAMIC, OCCLUDED)  
**Light Socket** — Valid anchor point for light placement  
**Structural Depth** — How deeply hidden a tile is within structure  
**Detection Multiplier** — Guard detection probability modifier (0.0-1.0x)  

### Abbreviations

- **L-IMP-XX** — Lighting Implementation phase
- **L-ARCH-XX** — Lighting Architecture specification
- **M2-XX** — Milestone 2 (future phases)
- **LOS** — Line of Sight
- **FOV** — Field of View
- **DEV_VISION** — Development overlay toggle

---

## End of Architecture Documentation

**Next: Refer to specific L-ARCH or feature documents for detailed specifications.**
