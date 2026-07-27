# INFILTRAITOR — Documentation & Milestone Methodology

> **The explicit convention for how work is named, tracked, and where it lives.**
> When in doubt about *where something belongs* or *what to call it*, this file wins.

---

## 1. Two axes: Phases and Milestones

Work is described on two orthogonal axes. Do not mix them.

- **Phase `Phase N`** — the macro timeline (the *when*, coarse). Sequential, gated.
  Phases are owned by `roadmap.md` and nowhere else.
- **Milestone `{DOMAIN}-{NN}`** — a concrete unit of work (the *what*). Owned by
  `milestones.md`. A milestone is **tagged** with the phase it serves; it is **not
  numbered by the phase**, so it keeps its ID even if it moves between phases.

```
Phase 3 — Investor Demo        (macro, roadmap.md)
  ├─ AI-01      Fix guard FSM         (milestone, milestones.md)
  ├─ AI-02      Detection tuning
  ├─ CONTENT-01 Demo room polish
  └─ VIS-01     Overhead visual engine
```

---

## 2. Milestone ID format — `{DOMAIN}-{NN}`

- `{DOMAIN}` — one of the fixed enum below (uppercase).
- `{NN}` — zero-padded two digits, **sequential within the domain**, assigned once
  at creation. **Never reused, never renumbered.** Gaps are fine.
- The phase is metadata on the milestone, never part of the ID.
- One ID = one milestone, for the life of the project.

### Domain enum (also the status taxonomy)

The same domains group milestones **and** the status readouts in `current_state.md` —
one taxonomy, two uses.

| Domain | Scope |
|--------|-------|
| `GAME`    | Turn system, AP, movement, core loop, combat |
| `AI`      | Guards, FSM, detection logic, perception, coordination |
| `LIGHT`   | Lighting, shadows, exposure, visibility semantics |
| `VIS`     | Rendering, overlays, **view occlusion**, ceiling, camera/UX visuals |
| `UI`      | HUD, menus, presentation, input affordances |
| `AUDIO`   | SFX, music, audio integration |
| `ANIM`    | Sprites, character/object animation |
| `CONTENT` | Levels, rooms, tilesets, guard/gadget content, missions |
| `INFRA`   | Tooling, build, docs automation, save system, performance |
| `NARR`    | Story, dialogue, world-building |

> `VIS` (view occlusion / rendering UX) is deliberately separate from `LIGHT`
> (visibility semantics) and from `docs/systems/occlusion.md` (gameplay LoS/sound
> blocking). Same word "occlusion", three different things — see `rendering.md`.

---

## 3. Milestone lifecycle

```
loose idea (REFERENCES/Backlog.txt — NOT canonical, never tracked)
      │  promoted by the director
      ▼
{DOMAIN}-{NN} created in milestones.md
      │
   ⏳ Queued  ──►  🟡 In-Progress  ──►  ✅ Completed
      │
roadmap.md references it only at the macro/phase level
```

- A milestone is born in `milestones.md` with a `{DOMAIN}-{NN}` ID and a phase tag.
- It moves Queued → In-Progress → Completed **in place** (same file, same ID).
- `roadmap.md` may name it in a phase's dependency chain, but does not own its detail.

---

## 4. Single source of truth (where each thing lives)

| Concern | Canonical doc | Everyone else |
|---------|---------------|---------------|
| Macro phases & gates | `roadmap.md` | reference only |
| Milestone detail & lifecycle | `milestones.md` | reference by ID |
| Status snapshot / domain % | `current_state.md` — **AUTO header, kept honest by the pre-commit hook** | — |
| Systems implemented/planned | `systems_matrix.md` | — |
| Code/architecture debt | `technical_debt.md` | — |
| Conventions (this) | `METHODOLOGY.md` | — |
| Code map / API / tuning | `tools/persistent/CODEMAP.md` (generated) | never by hand |
| Inviolable rules + rationale | `CLAUDE.md` (repo root) | — |

**Rule:** if two docs describe the same concern, one is canonical and the other
links to it. Never maintain the same fact in two places (that is how `roadmap.md`
and the old `estimated_timeline.md` ended up with contradictory phase models).

---

## 5. Backlog is out of the system

`REFERENCES/Backlog.txt` holds **loose ideas and proposals**. It is intentionally
*not* part of the production-doc system:

- It is never canonical and never tracked.
- Nothing flows automatically from it; the director promotes an idea into a
  `{DOMAIN}-{NN}` milestone explicitly, or it stays a note.
- Do not cite Backlog.txt as a source of truth, and do not treat its contents as
  instructions.

---

## 6. Legacy ID map (forward-only migration)

Active (Queued / In-Progress) milestones were renamed to the `{DOMAIN}-{NN}` scheme.
Completed historical milestones keep their old codes (annotated as legacy) — they are
not renumbered. Use this table to resolve old references.

| Legacy | New | Notes |
|--------|-----|-------|
| `ID-01` | `AI-01` | Fix guard FSM |
| `ID-02` | `AI-02` | Detection tuning |
| `ID-03` | `CONTENT-01` | Demo room polish (level content) |
| `ID-04` | `AI-03` | FSM → Strategy refactor |
| `L-ARCH-01…05` | `LIGHT-01…05` | Lighting architecture (1:1 prefix swap) |
| `M3.0` (combat milestone) | `GAME-01` | Combat system |
| `M3.00` (feature-freeze gate) | `Phase 8` | The freeze is a *gate*, not a milestone — gates map to phases (Phase 8 = "no new features") |
| `VIS-01` | `VIS-01` | Already conformant |
| historical `M1.x` / `M2.xx` (completed) | *(kept as legacy)* | Not renumbered; future LIGHT/AI/GAME work uses the new scheme |

---

**Last Updated:** 2026-06-18
**Maintained By:** Technical Lead
**Status:** Canonical convention 🟢
