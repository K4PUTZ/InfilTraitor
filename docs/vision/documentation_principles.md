# Documentation Principles

> **Core beliefs about how documentation should work in INFILTRAITOR.**

---

## Purpose

Prevent regression in documentation architecture.

These principles guide:
- What gets written
- Where it belongs
- How it's organized
- Who maintains it
- When it's complete

---

## Core Principles

### 1. Single Source of Truth (SSOT)

**Principle:**  
Each topic has exactly ONE official location.

**Why:**  
Multiple versions → confusion → decisions made on outdated info.

**Practice:**
- Document ownership is explicit (see documentation_ownership.md)
- Other locations reference with links
- If two places claim authority, one is wrong

**Example:**
- AI System Truth: `docs/systems/ai.md`
- AI Timeline: `docs/production/development_pipeline.md` (links to systems)
- AI History: `docs/history/refactor_logs/` (links to systems)

---

### 2. Modular Ownership

**Principle:**  
One person/role owns each documentation domain.

**Why:**  
Clear accountability + no orphaned docs + faster decisions.

**Practice:**
- Each domain has explicit owner (documentation_ownership.md)
- Owners approve changes to their domain
- Others can submit PRs; owner decides
- Ownership can transfer, but always explicit

**Example:**
- Design Lead owns docs/vision/
- Tech Lead owns docs/systems/
- Project Manager owns docs/production/

---

### 3. History Isolation

**Principle:**  
Historical records don't interfere with active work.

**Why:**  
"What is?" should not be confused with "What was?"

**Practice:**
- Active docs in: docs/vision/, docs/systems/, docs/production/, docs/technical/
- Historical records in: docs/history/ (read-only mostly)
- Never active development against history docs
- History docs reference current docs, not vice versa

**Example:**
- Old design doc: docs/history/deprecated_design/DEV_VISION_FOUNDATION.md
- Current vision: docs/vision/game_vision.md
- Never edit history doc; reference it if context needed

---

### 4. No Hybrid Documents

**Principle:**  
Don't mix implementation + roadmap + history in one doc.

**Why:**  
Muddy docs confuse decision-making. "Are we doing this now or later?"

**Practice:**
- Systems docs (current impl) ≠ Production docs (roadmap)
- Systems docs can say "Future: X (see production/)" but not describe future
- Production docs say "Planned in M4-01" but link to systems for details
- History docs don't dictate current behavior

**Example (BAD):**
```
## Perception System

Current implementation uses angular cones (M2.01).
We plan to add probabilistic detection in M3-02.
The old rectangular cone system was replaced here.
```

**Example (GOOD):**
```
# Current Implementation (docs/systems/perception.md)
Angular cones, distance-based attenuation...

# Future (docs/systems/perception.md)
Planned: Probabilistic detection (see production/not_yet_started.md)

# How It Evolves (docs/production/development_pipeline.md)
M3-02: Probabilistic detection added...

# History (docs/history/design_decisions/perception_evolution.md)
Old rectangular cone system was replaced because...
```

---

### 5. Systems ≠ Roadmap

**Principle:**  
"How does it work now?" ≠ "What are we building next?"

**Why:**  
Confusing these leads to: "Wait, is this done or not?"

**Practice:**
- Systems docs (docs/systems/): Current implementation in detail
- Production docs (docs/production/): What's next, when, why
- Systems docs reference production for future plans
- Production docs link to systems for current state

**Explicit Separation:**
```markdown
## Current Implementation
[Current system details]

## Planned Extensions
[Future work, with link to docs/production/]
```

---

### 6. Documentation is Infrastructure

**Principle:**  
Docs are not optional extras; they're essential infrastructure.

**Why:**  
Poor docs = slow onboarding, wrong decisions, wasted time, reinvented wheels.

**Practice:**
- Docs reviewed same rigor as code (PRs)
- Documentation debt tracked like technical debt
- Outdated docs are bugs (fix or remove)
- New features require doc updates

**Governance:**
- Docs Lead reviews doc PRs
- Poor documentation = PR rejected (not code approval)
- Metrics: docs completeness, update frequency, link rot

---

### 7. Write for the Future Developer (Not Today)

**Principle:**  
Document for someone who joins in 6 months and knows nothing.

**Why:**  
You'll eventually be that person (on a different project).

**Practice:**
- Assume no context
- Use clear examples
- Explain the "why" not just "what"
- Link related concepts
- Define jargon

**Example (BAD):**
```
The guard uses the cone. It has a base angle.
```

**Example (GOOD):**
```
Guards detect the agent via a visual detection cone.
The cone is 90° wide (45° left/right of facing direction) 
and extends 2 cells forward. Detection probability 
decreases with distance and shadows.
```

---

### 8. Keep Docs Close to Code

**Principle:**  
Related docs and code should live near each other (conceptually).

**Why:**  
Easy to sync, easy to find, easy to update.

**Practice:**
- Systems docs describe actual systems
- Production docs describe production scheduling
- Technical docs describe technical implementation
- Cross-link heavily

**Not Practice:**
- One mega-doc for everything
- Duplicate docs across folders
- Docs far from what they describe

---

### 9. Explicit vs Implicit (Prefer Explicit)

**Principle:**  
Make every assumption explicit.

**Why:**  
Implicit assumptions are where bugs hide.

**Practice:**
- "Current" vs "Planned" - explicitly separate
- Decision rationale - write it down
- Parameters + thresholds - enumerate
- Dependencies - list them

**Example:**
```
❌ "Cones can stack"
✅ "Multiple cones DO NOT stack; guard uses highest probability (not sum)"
```

---

### 10. Ownership is Accountability

**Principle:**  
If it's your domain, it's your job to maintain it.

**Why:**  
Someone must be responsible or nothing gets updated.

**Practice:**
- Owner reviews all changes
- Owner updates when systems change
- Owner answers questions about the domain
- Owner deprecates old docs

**Not Practice:**
- "Someone should update this"
- "We all maintain everything"
- No clear owner

---

## Anti-Patterns (What NOT to Do)

### ❌ Updating Code Without Updating Docs

**Problem:** Code changes, docs don't → docs become lies

**Solution:** PR review requires both code + doc changes

---

### ❌ Mixing Domains

**Problem:** Systems + Roadmap + History in one doc → confusion

**Solution:** Use decision tree (see documentation_ownership.md)

---

### ❌ Writing for Yourself

**Problem:** "I'll remember what this means"

**Solution:** Write for someone new (6 months from now)

---

### ❌ Assuming Context

**Problem:** "Everyone knows what perception means"

**Solution:** Define every term, include examples

---

### ❌ Orphaning Old Docs

**Problem:** Old docs become wrong, not removed

**Solution:** Archive to history/ or mark DEPRECATED

---

### ❌ No Ownership

**Problem:** "Whose job is this?" → Nobody's job → outdated

**Solution:** Explicit owner in documentation_ownership.md

---

## Metrics

**Good Documentation:**
- ✅ Links don't break (checked quarterly)
- ✅ Updated when systems change (within 1 sprint)
- ✅ Clear owner (listed in documentation_ownership.md)
- ✅ No orphaned docs (audited per CLEAN sprint)
- ✅ New devs can onboard using docs (tested per hire)

**Bad Documentation:**
- ❌ Outdated information (>3 months old with no current equivalent)
- ❌ Unclear ownership ("Someone wrote this?")
- ❌ Mixed domains (roadmap + implementation in one doc)
- ❌ Broken links (pointing to deleted/moved files)
- ❌ No date/version (how old is this?)

---

## Enforcement

### On Code PRs
- [ ] Code changes have corresponding doc updates?
- [ ] New systems documented?
- [ ] Docs reviewed by appropriate owner?

### Quarterly CLEAN Sprints
- [ ] Are all docs still relevant?
- [ ] Have broken links been fixed?
- [ ] Are there orphaned docs?
- [ ] Is ownership still accurate?

### Per-COMMIT
- Every commit message should reference affected docs
- If doc doesn't exist but should, create it

---

## Evolution of This Document

This document is the source of truth for documentation culture.

**If this conflicts with documentation_ownership.md, this wins.**  
**If this conflicts with actual practice, this needs updating.**

**Updates required when:**
- New documentation domain is needed
- Principles are violated repeatedly
- Better practices are discovered

---

## Further Reading

- [Documentation Ownership](documentation_ownership.md) — Who owns what
- [Archive Policy](archive_policy.md) — How to manage old docs
- [Repository Structure](repo_structure.md) — Where things live

---

**Last Updated:** 2026-06-12  
**Author:** Documentation Team  
**Status:** Foundation Principles 🟢

These principles should guide documentation decisions for years to come.
