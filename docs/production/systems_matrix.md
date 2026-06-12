# INFILTRAITOR — Systems Implementation Matrix

> **Which systems exist, what state they're in, and what they depend on.**

---

## Overview

This matrix tracks all core gameplay systems by implementation status, dependencies, and next steps.

---

## Implemented Systems ✅

### Movement & Navigation
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Grid Movement | ✅ Implemented | Core engine | Expand to 8-direction | Lead Programmer |
| Turn Resolution | ✅ Implemented | Grid | A.P. refinement | Lead Programmer |
| Pathfinding (Dijkstra) | ✅ Implemented | Grid + blocking | Optimization | Lead Programmer |
| Overwatch System | ✅ Implemented | Turn resolution | Playtesting | Design Lead |

### Perception & Detection
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Visual Detection | ✅ Implemented | Guard FSM + perception | Distance curve tuning | Lead Programmer |
| Audio Detection | ✅ Implemented | Noise grid | Audio integration | Audio Programmer |
| Attention System | ✅ Implemented | Visual detection | Personality variance | AI Programmer |
| Detection Meter | ✅ Implemented | Thresholds + sigmoid | Playtesting | Lead Programmer |

### Lighting & Visibility
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Shadow Calculation | ✅ Implemented | Light sources + geometry | Dynamic lighting (future) | Graphics Programmer |
| Fog of War | ✅ Implemented | Perception | Performance optimization | Graphics Programmer |
| Light Baking | ✅ Implemented | TileMapLayers | Per-room customization | Graphics Programmer |

### Noise & Audio
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Noise Grid | ✅ Implemented | Propagation rules | Audio SFX integration | Audio Programmer |
| Propagation | ✅ Implemented | Wall attenuation | Playtesting validation | Audio Programmer |
| Decay | ✅ Implemented | Timing system | Balance adjustment | Audio Programmer |
| Audio Detection | ✅ Implemented | Noise grid | Footstep SFX | Audio Programmer |

### AI & Behavior
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Guard FSM | ✅ Implemented | States + transitions | Personality variance | AI Programmer |
| Decision Logic | ✅ Implemented | Per-state algorithms | Learning behavior | AI Programmer |
| Communication | ✅ Implemented | Whistle + radio | Faction-specific variants | AI Programmer |
| Knowledge Model | ✅ Implemented | Memory + decay | Distributed sync | AI Programmer |

### Visualization & Overlay
| System | Status | Dependencies | Next Step | Owner |
|--------|--------|--------------|-----------|-------|
| Movement Overlay | ✅ Implemented | Dijkstra + visuals | Cover hints (M2-15) | Lead Programmer |
| Perception Overlay | ✅ Implemented | FOW layers | Performance pass | Graphics Programmer |
| Debug Visualization | ✅ Implemented | Noise/detection display | Toggleable modes | QA |

---

## In-Progress Systems 🟡

### Interaction System
| Aspect | Status | Blocker | ETA |
|--------|--------|---------|-----|
| Door unlock | 50% | Integration testing | This week |
| Terminal hacking | 30% | UI design | Next week |
| Object pickup | 20% | Inventory system | TBD |
| Trap triggers | 0% | Design finalization | TBD |

### Gadget Integration
| Gadget | Status | Blocker | ETA |
|--------|--------|---------|-----|
| Smoke Bomb | 60% | Visual SFX | This week |
| EMP Device | 40% | Audio implementation | Next week |
| Decoy | 20% | Behavior definition | TBD |
| Flashbang | 0% | Design TBD | TBD |

### Animation Framework
| Animation | Status | Blocker | ETA |
|-----------|--------|---------|-----|
| Idle (guard) | 40% | Sprite design | This week |
| Walking (guard) | 30% | Sprite design | This week |
| Alert state | 20% | Sprite design + sound | Next week |
| Scanning (guard) | 10% | Animation design | TBD |

---

## Planned Systems ⏳

### Gameplay Mechanics
- **Combat System** — Direct confrontation (post-M3.0)
- **Skill Tree** — Player progression (post-content phase)
- **Objectives** — Mission structure (M3-02)
- **Campaign System** — Multi-mission progression (M4-00)
- **Gadget Customization** — Load-outs and presets (M3-03)

### AI & Behavior
- **Faction-Specific AI** — Different guard behaviors per faction
- **Learning Guards** — Guards adapt after repeated encounters
- **Patrol Generation** — Procedural patrol routes
- **Group Tactics** — Multi-guard coordinated attacks

### Audio & Music
- **Adaptive Music** — Dynamic track selection based on state
- **Radio Chatter** — Background communication ambience
- **Environmental Sounds** — Ambient room audio
- **Music Transitions** — Smooth state-based music shifts

### Content
- **Guard Archetypes** — 5+ distinct guard types (elite, sniper, etc.)
- **Mission Generation** — Procedural objective creation
- **Dialogue System** — NPC communication
- **Environment Hazards** — Traps, hazards, obstacles

### Narrative
- **World Lore** — Faction background, history
- **Mission Briefings** — Contextual objectives
- **Intel Fragments** — Collectible lore pieces
- **Character Arcs** — Recurring NPCs with development

---

## Deprecated/Removed Systems 🗑️

| System | Removal Reason | Status |
|--------|----------------|--------|
| ShadowOverlay (scene) | Replaced with baked layers | ✅ Complete |
| Cover Hints System | Redesigned for M2-15 | ✅ Removed |
| Hardcoded Shadow Positions | Replaced with cone projection | ✅ Complete |

---

## System Dependencies Graph

```
Core Engine (Godot 4.6)
├── Grid System
│   ├── Movement
│   ├── Pathfinding
│   └── Perception (spatial queries)
│
├── Guard FSM
│   ├── Decision Logic
│   ├── Communication
│   └── Knowledge Model
│
├── Lighting System
│   ├── Shadow Calculation
│   ├── Fog of War
│   └── Tactical Visibility
│
└── Audio System
    ├── Noise Grid
    ├── Propagation
    └── Detection Integration
```

---

## Critical Path

The following sequence is required for gameplay stability:

1. ✅ **Grid Movement** (foundation)
2. ✅ **Guard FSM** (behavior)
3. ✅ **Perception** (detection)
4. ✅ **Audio Grid** (parallel to perception)
5. ✅ **Lighting** (visual stealth)
6. 🟡 **Interaction** (player agency)
7. 🟡 **Gadgets** (player tools)
8. ⏳ **Objectives** (goal structure)
9. ⏳ **Combat** (confrontation system)

---

## Metrics

| Metric | Value |
|--------|-------|
| **Systems Fully Implemented** | 11 |
| **Systems In Progress** | 2 |
| **Systems Planned** | 15+ |
| **Systems Deprecated** | 3 |
| **Overall Coverage** | ~60% |

---

**Last Updated:** 2026-06-11  
**Maintained By:** Technical Lead  
**Status:** Active 🟢
