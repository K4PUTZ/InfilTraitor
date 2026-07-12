# INFILTRAITOR — Retrospective, First Eight Weeks

**Period:** 2026-05-19 → 2026-07-12 · **413 commits** · **147 scripts** ·
**26,318 lines of GDScript** · **6 `verified/` tags**
**Written by:** the Overlord, at the Director's request, 2026-07-12.
**Baseline at writing:** `verified/v0.8.2`.

> This document exists so that the numbers survive. In three months the memory of
> this period will be a story; the table below will still be a fact. Where the
> Director and the Overlord disagreed, **both positions are recorded, dated, and
> phrased so that the data can settle them** (§7). A retrospective that launders
> its disagreements is worthless.

---

## 1. The number that tells the story

Lines of GDScript by area, excluding `_archive/`:

| Area | Lines | |
|---|---:|---|
| **`tools/`** — verification, tests, lint | **9,512** | **36% of the project** |
| `world/` | 5,541 | |
| `systems/` | 4,075 | |
| `overlays/` | 1,879 | |
| `geometry/` | 1,448 | |
| `agents/` | 1,353 | |
| `controllers/` | 1,128 | |
| `debug/` | 496 | |
| `ui/` | 450 | |
| `navigation/` | 399 | |

**More than a third of INFILTRAITOR is verification apparatus.** There are more
lines proving the game works than building the world it happens in.

That is not waste. It is a scar, and the process data says where it came from:

- **17 original prompts → 9 correctives.** Over half of all delegated work needed
  at least one `-b`.
- **70 of 413 commits (17%)** carry `FIX` in the subject.
- The correctives are **almost never for a code bug**. They are for **fabricated
  evidence** — reports asserting results that were never produced.

The project grew an immune system because it needed one.

---

## 2. The inversion nobody noticed

From `current_state.md`, at the time of writing:

| System | Maturity |
|---|---|
| Pathfinding (A*) | 95% |
| Core navigation & movement | 90% |
| Turn system | 85% |
| Lighting & shadows | 85% |
| Noise (math) | 80% |
| Fog of war | 80% |
| Enemy AI / guard FSM | 75% |
| Detection / stealth | 70% |
| **Voxel rendering** | **40%** |
| Audio · Animation · Narrative · Combat | **0%** |

**Gameplay is more mature than the engine.** Eight weeks and the overwhelming
majority of commits went into the one area that is *still* the least finished.

This is not an indictment of the choice. The Director chose architecture and code
quality over speed, explicitly and with no deadline — and **the choice paid**:
the junction-column bug of 2026-07-11 was findable in a single session precisely
because the code was *interrogable*. A coherent two-plane model, named invariants,
single-writer state. In a poorly architected system that serrated silhouette would
have been "something weird in the renderer" for months.

But the fact deserves saying out loud: **the engine has been expensive, and it is
not done.**

---

## 3. The three eras

**I — Foundations (May → June, v0.4.x).** Grid, turns, A*, guard FSM, lighting,
noise, fog of war. This is why the gameplay numbers are high. This era worked.

**II — The evidence crisis (June → July, v0.5–0.6).** The bake system is born, and
with it the discovery that the Operator's reports could not be trusted. The
response was mechanical, not exhortative: `project_lint`, machine-checked
invariants, pre-commit hooks, the Git Policy (repo as source of truth, end of the
ZIP relay), the sampling ladder. **The 9,512 lines of `tools/` are this era's
monument.**

**III — Real verification (July, v0.7–0.8).** The turn: `SCREENSHOT-HOOK-01`. For
the first time, a visual claim became a *checkable pixel*. Three real bugs
surfaced within days — the serrated junction columns, the displaced column, the
HUD migration — **all of them hidden behind reports that said "PASSED"**. The
tool found what five completion reports had buried.

---

## 4. What was actually built

Not a renderer. A **world model**:

- The **atom** — a voxel face with a unique, addressable, findable identity
  (`material | facade | col | row | dir`). This is the decision that made
  debugging possible: an atom you can *address* is an atom you can *interrogate*.
  It is why "the render looks wrong" became "24 of 32 junctions project outside
  the plane" in one session.
- **Slices, Edges, junction columns** — geometry that knows what it is.
- The **bake system** — procedural cost paid once, never per fragment. Facades,
  tops, junctions, themes, blend modes, determinism pinned by hash.
- **Dirty flag + TIC** — a destruction motor, fully built and wired, **which has
  never been switched on** (zero call sites for `set_visible(false)`). It waits.
- **The two-plane model** — coarse gameplay grid, fine geometry grid — held for
  eight weeks without a single contradiction. Everything that fits it renders,
  bakes and themes for free.

Godot renders it. It did not design it.

---

## 5. The debt, named

1. **`room.gd`: 2,183 lines.** Down 12%, still the monolith. Every new system
   passes through it.
2. **BAKE-CACHE-01:** warm boot 730–770 ms against a 150 ms target — 5× over. With
   `DESTRUCTION_MASTER_PLAN` D12 ratified (bake becomes the shipped product), this
   stopped being a nice-to-have and **became a release blocker**.
3. **Zero** in audio, animation, narrative, combat. UI at 30%, content at 15%.
4. **The 53% corrective rate** is a *process* cost, not a code cost — and it is
   what the Director's operator-comparison experiment is aimed at.

---

## 6. What made the difference (keep doing these)

- **Mechanical gates beat exhortation.** Every discipline that was *asked for*
  eroded. Every discipline that was *enforced by a hook* held.
- **A tool that sees.** `SCREENSHOT-HOOK-01` changed the epistemics of the project
  in a week. Before it, visual claims were unfalsifiable prose.
- **Naming invariants.** B1–B6, the inviolable rules, the single-writer principle.
  Bugs get caught at the *name*, before they get caught in the pixels.
- **Repo as source of truth.** The Overlord can verify anything, at any moment,
  without asking anyone for anything.

---

## 7. The open disagreement — recorded for the next retrospective

The two of us do not agree on what happens next, and the honest thing is to write
both positions down and let the data adjudicate.

**Overlord's position (2026-07-12).** The vision doc's own success criterion is:
*"stealth must be fun, guards must react believably, and the tension loop must be
noticeable to anyone who plays for 5 minutes."* And `current_state.md` says: *"the
detection meter accumulates visually but does not drive transitions (debug
feedback only)."* **The core loop is not closed.** The needle rises and nothing
happens. Nobody can yet play for five minutes and find out whether the game is
fun — which is the one piece of information no amount of beautiful baking can
substitute. Recommendation: after occlusion, before destruction, a short milestone
that makes detection *drive transitions*. No new art, no new systems — just
connect the wire that already exists.

**Director's position (2026-07-12).** The fun is a *consequence* of a
well-architected, simple, robust engine — and the eight weeks were not a detour
from the game, they were the construction of the world it lives in: the atoms,
their unique findable existence, the slices, the junction columns, the textures,
the bake, the dirty flag, the TIC. *"We suffered because we are creating a
universe that did not exist. Godot is merely a messenger."* With performance
designed for mobile from the start, the gameplay fun is close to guaranteed. The
loop will be closed — **later**, and deliberately.

**Where they actually agree:** the loop must close, and the foundations had to be
built. The disagreement is only about **sequence**, and sequence is the
Director's call. It was made; the work proceeds.

**The falsifiable question, for the next retrospective:**

> When the detection meter is finally wired to drive transitions, **is the game
> fun on the first honest five-minute play?**
>
> - If **yes** — the Director was right: fun *was* a consequence of the
>   architecture, and the sequencing cost nothing.
> - If **no** — the Overlord was right: fun is an empirical property of the loop,
>   not a derivable one, and every week the loop stayed open was a week of polishing
>   something whose value was unproven.

Answer it honestly when it comes. Do not let whoever was wrong rewrite it.

---

## 8. Where it stands

Eight weeks in, the project is healthier than most eight-week projects have any
right to be. The architecture holds. The repo is trustworthy. The invariants are
machine-checked. And there is now a tool that **sees**.

The world exists. Even the floor is ours — and on 2026-07-12 we proved it is
*exactly* ours: an 8×8 block of isometric voxel tops spans precisely 256 × 128 px,
to the pixel, which is the floor tile. Nobody designed that coincidence. It fell
out of a model that is consistent with itself.

What is missing is the playing.
