# INFILTRAITOR Repository Structure

> **Formal documentation of repository organization, folder purposes, and ownership.**

---

## Overview

This document defines the structure, responsibilities, and allowed contents of each folder in the INFILTRAITOR repository.

**Goal:** Prevent entropy growth by establishing clear ownership and purposes.

---

## Repository Root

**Folder:** `/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/`

### Required Files (Always in Root)

| File | Purpose | Owner | Locked |
|------|---------|-------|--------|
| `project.godot` | Godot project configuration | Engine Team | Yes |
| `README.md` | Repository landing page | Documentation | Yes |
| `LICENSE` | Project license | Legal | Yes |
| `.gitignore` | Git exclusion rules | DevOps | Yes |
| `icon.svg` | Project icon (for Godot) | Art Lead | Yes |

### Allowed in Root (Utilities)

| File/Folder | Purpose | Example |
|-------------|---------|---------|
| `tools/` | Development utilities | See [Tools](#tools) section |
| `BACKUP.py` | Backup utility | Alternative: move to `tools/persistent/` |

### NOT Allowed in Root

| Item | Reason | Alternative |
|------|--------|-------------|
| **Loose Python scripts** | Maintenance burden | Move to `tools/` |
| **Debug outputs** | Build artifact | Add to `.gitignore` |
| **Temporary exports** | Regenerable | Add to `.gitignore` |
| **Old backups** | Repo bloat | Move to `ARCHIVE/` (local only) |
| **Personal notes** | Not code | Move to wiki/docs |

---

## godot/ (Engine Project)

**Owner:** Engine Team  
**Locked Structure:** Yes (Don't reorganize)  
**Responsibility:** All Godot game code and configuration

### godot/project.godot
Godot project configuration (redundant with root, maintained by Godot)

### godot/scenes/ (Scenes & Nodes)
```
scenes/
├── room/                           # Main game scene
├── ui/                             # UI overlays
└── debug/                          # Debug visualization
```

**Rules:**
- One scene file per gameplay system
- UI scenes separate from game logic
- Debug scenes excluded from export

### godot/scripts/ (Source Code)
```
scripts/
├── world/                          # Room, layout, tile manipulation
├── agents/                         # Player and guard AI
├── systems/                        # Core systems (movement, detection, etc.)
├── ui/                             # UI logic
├── game/                           # Game flow, turn management
└── navigation/                     # Pathfinding, movement
```

**Rules:**
- One file per class
- Max 500 lines per script (split if larger)
- No debug code in main scripts (use debug/ folder)
- All external dependencies declared at top

### godot/resources/ (Assets & Configs)
```
resources/
├── tilesets/                       # Tileset data (tileset_blocks.tres)
├── themes/                         # UI themes
├── shaders/                        # Godot shaders (if any)
└── materials/                      # Material definitions
```

**Rules:**
- Tileset definitions only (asset PNGs in ASSETS/)
- All tilesets use consistent origin calibration
- Shader changes require design review

---

## ASSETS/ (Game Content)

**Owner:** Art Lead  
**Locked Structure:** Yes (Preserve folder organization)  
**Size:** ~31MB (tracked in git)  
**Responsibility:** All visual and audio game content

```
ASSETS/
├── ISOMETRIC/                      # Kenney tile packs (8 sets)
│   ├── blocks-prototype/
│   ├── bases-terrain/
│   └── ... (6 more)
├── CHARACTERS/                     # Player & NPC sprites
│   ├── humans/ (8 variants)
│   └── enemies/ (future)
├── UI/                             # UI icons and elements
├── FX/                             # Effects and animations
│   └── smoke/
├── REFERENCES/                     # External reference images
└── README.md                       # Asset inventory & licenses
```

**Rules:**
- No modifications to Kenney assets (already licensed)
- New assets follow same directory structure
- All assets attributed (license, source, date)
- Unused assets → ARCHIVE/ (local only)

**Access:**
- Read: Everyone
- Modify: Art Lead only
- New assets: Propose to Art Lead

---

## ARCHIVE/ (Local-Only Assets)

**Owner:** Art Lead  
**Locked Structure:** No (Can reorganize)  
**Size:** ~558MB (excluded from git)  
**Responsibility:** Unused/deprecated assets

```
ARCHIVE/
├── fonts/                          # Old font files
├── fx-lightning/                   # Unused VFX
├── scifi-ui/                       # Abandoned UI style
├── sprites-2d/                     # Flat sprites (project uses isometric)
├── textures-flat/                  # Non-isometric textures
└── top-down-lab/                   # Top-down prototypes
```

**Rules:**
- All contents `.gitignore`'d
- No references from active code
- Can be deleted anytime (low priority)
- Useful for reference/rollback (keep locally)

**Access:**
- Read: Anyone
- Modify: Art Lead
- Delete: Anyone (non-critical)

---

## docs/ (Documentation)

**Owner:** Documentation Team  
**Locked Structure:** Yes (Mirror in docs/README.md)  
**Responsibility:** All project documentation

```
docs/
├── README.md                       # Main doc hub
├── vision/                         # Game concept & philosophy
│   ├── game_vision.md
│   ├── design_philosophy.md
│   └── pillars.md
├── systems/                        # Individual system docs
│   ├── movement.md
│   ├── perception.md
│   ├── lighting.md
│   ├── noise.md
│   ├── stealth.md
│   └── ai.md
├── production/                     # Development roadmap & tracking
│   ├── README.md
│   ├── dashboard.md
│   ├── current_state.md
│   ├── systems_matrix.md
│   ├── content_matrix.md
│   ├── technical_debt.md
│   ├── risk_assessment.md
│   ├── development_pipeline.md
│   ├── estimated_timeline.md
│   ├── audio_pipeline.md
│   ├── animation_pipeline.md
│   ├── narrative_pipeline.md
│   ├── not_yet_started.md
│   ├── milestones.md
│   └── roadmap.md
├── technical/                      # Implementation guides
│   ├── repo_structure.md
│   ├── archive_policy.md
│   ├── developer_setup.md
│   ├── asset_map.md
│   ├── architecture.md
│   ├── performance.md
│   └── godot_setup.md (planned)
└── history/                        # Development records
    ├── sprint_logs/
    ├── refactor_logs/
    └── deprecated_design/
```

**Rules:**
- One doc per topic (no mega-docs)
- Cross-reference via markdown links
- Update README.md when adding docs
- Archive old docs to history/ (never delete)

**Access:**
- Read: Everyone
- Write: Designated author + documentation lead review
- Archive: Docs team + project lead approval

---

## tools/ (Development Utilities)

**Owner:** DevOps/Architecture Team  
**Locked Structure:** Moderate (Can add subdirs for new tools)  
**Responsibility:** Scripts, build utilities, automation

```
tools/
├── README.md                       # Tools registry & docs
├── persistent/                     # Active utilities
│   └── BACKUP.py                  # Project backup script
├── migration/                      # Historical/one-shot scripts
│   └── tileset_origin_calibration/
│       ├── MIGRATION_HISTORY.md
│       ├── rename_tiles.py
│       ├── update_texture_origins.py
│       └── ... (7 more)
├── experimental/                   # Sandbox for new tools
└── archive/                        # Deprecated tools
```

**Rules:**
- New tools start in `experimental/`
- Move to `persistent/` when stable
- Move to `archive/` when deprecated (never delete)
- Each tool has README or docstring
- No implicit dependencies between scripts

**Access:**
- Read: Everyone
- Write: DevOps + proposing developer
- Promote: DevOps approval

---

## DEVELOPMENT/ (Deprecated)

**Status:** ⏳ Being migrated to docs/  
**Owner:** None (legacy)  
**Action:** Files being moved to docs/history/ and docs/technical/

```
DEVELOPMENT/  (→ docs/history/ and docs/technical/)
├── GAME_PLAN.md  → docs/history/design_decisions.md
├── PROGRESS.md → docs/history/sprint_logs/
├── DEVELOPER_GUIDE.md → docs/technical/developer_setup.md
├── ASSET_MAP.md → docs/technical/asset_map.md
├── REFACTOR_SPRINT_04.md → docs/history/refactor_logs/
├── LIGHTING_DESIGN.md → docs/systems/lighting.md (completed)
├── DEV_VISION_FOUNDATION.md → docs/history/deprecated_design/
└── README.md → (will be replaced by docs/README.md)
```

**Timeline:** All content moved during CLEAN-01 sprint

---

## REFERENCES/ (External Reference Content)

**Owner:** Art Lead  
**Locked Structure:** No  
**Size:** 1.3MB  
**Responsibility:** Reference images, inspirations

**Rules:**
- No code (images only)
- Cited sources where applicable
- Can be deleted anytime (reference only)

---

## export/ (Godot Exports)

**Owner:** Engine Team  
**Gitignored:** Yes  
**Purpose:** Build outputs for testing

**Rules:**
- Regenerable (don't commit)
- Delete before submitting PR
- Can be deleted anytime

---

## Hidden Folders (System)

| Folder | Purpose | Gitignored |
|--------|---------|-----------|
| `.git/` | Git repository | No (system) |
| `.godot/` | Godot cache | Yes |
| `.vscode/` | VS Code settings | Yes |
| `__pycache__/` | Python cache | Yes |

**Rules:**
- Don't modify manually
- Let tools manage automatically

---

## Ownership & Responsibilities

### Engine Team
- Maintain godot/ folder structure
- Update godot scripts
- Manage godot/resources/

### Art Lead
- Manage ASSETS/ folder
- Organize ARCHIVE/
- Update REFERENCES/

### Documentation Team
- Maintain docs/ structure
- Write and review docs
- Archive deprecated docs

### DevOps/Architecture
- Manage tools/ folder
- Maintain this document
- Code cleanup & refactoring

---

## Adding New Folders

**Request Process:**
1. Propose to project lead
2. Document purpose & responsibility owner
3. Add to this document
4. Create README.md in new folder
5. Commit with approval

**Forbidden New Folders:**
- Anything redundant with existing structure
- Temporary/debug folders (use .gitignore)
- Personal working directories (use local branches)

---

## Cleanup Principles

### What Gets Gitignored (Regenerable)
- Build outputs (export/)
- Cache (\.godot/, \.vscode/, __pycache__)
- Temporary files (.DS_Store)
- Build artifacts (*.ZIP)

### What Gets Archived (Non-regenerable)
- Old scripts (tools/archive/)
- Old docs (docs/history/)
- Deprecated assets (ARCHIVE/)

### What Gets Deleted (Dead Code)
- Only with explicit approval
- After archiving
- After confirming no dependencies

---

## Long-Term Vision

```
Current State (CLEAN-01)          → Mature State (Year 2)
├── tools/persistent/             ├── tools/persistent/ (10+ utilities)
├── tools/migration/              ├── tools/experimental/
├── docs/                         ├── docs/ (organized by team)
├── godot/                        ├── godot/ (stable architecture)
├── ASSETS/                       ├── ASSETS/ + content/
└── ARCHIVE/                      ├── ARCHIVE/ (growing)
                                  ├── build/ (CI/CD outputs)
                                  ├── tests/ (automated test suite)
                                  └── scripts/ (deployment helpers)
```

---

## Reference

- [Archive Policy](archive_policy.md)
- [Tools Registry](../tools/README.md)
- [Main Documentation Hub](../docs/README.md)

---

**Last Updated:** 2026-06-12  
**Maintained By:** Architecture Team  
**Approval Required:** Before structural changes  
**Status:** Active 🟢
