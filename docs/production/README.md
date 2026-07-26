# Production

Where the work stands and what gets built next.

| Doc | What it's for | Kept fresh by |
|---|---|---|
| **[current_state.md](current_state.md)** | Status by domain. **The live one.** | `update_docs.py`, via the pre-commit hook (AUTO header) |
| **[milestones.md](milestones.md)** | The executable list — IDs, stages, status | Hand, at closure |
| **[roadmap.md](roadmap.md)** | Macro phases and exit criteria | Hand, rarely |
| **[technical_debt.md](technical_debt.md)** | Known issues and pending refactors | Hand |
| **[METHODOLOGY.md](METHODOLOGY.md)** | Prompt IDs, domain enum, Director/Overlord/Operator split | Hand |
| **[TILE_ANATOMY.md](TILE_ANATOMY.md)** | Tile geometry, audited by `godot/scripts/tools/tile_anatomy_audit.gd` | The audit tool |
| **[RETROSPECTIVE_2026-07.md](RETROSPECTIVE_2026-07.md)** | The first eight weeks, with the numbers and the open disagreement | Frozen — it's a record |

---

## What used to be here

On 2026-07-12 this folder lost `dashboard.md`, `content_matrix.md`, `not_yet_started.md`,
`development_pipeline.md`, `risk_assessment.md`, `documentation_debt.md`, and the audio /
animation / narrative pipelines — about 2,400 lines.

They were written in June, never touched again, and described a **feature-development
process, a risk register, and content roadmaps for systems that are at 0%**. Several
assigned owners ("Content Manager", "Audio Director") to a project with one person on it.
`dashboard.md` duplicated `current_state.md`, which is the one a hook actually keeps
truthful.

**The rule that replaces them:** a roadmap doc for an unbuilt system is a liability, not
an asset — it rots silently, and then it misleads. Write the doc when the system exists.
Until then the milestone entry is enough.

Git still has all of it: `git show <sha>:docs/production/<file>`.

On 2026-07-26 this folder also lost `systems_matrix.md`. It opened with its own
"**SUPERSEDED.** See `current_state.md`" banner yet stayed listed here as if
current — the same rot pattern one step earlier: a doc that knows it's dead but
nobody removed the pointer. `current_state.md` already owns per-domain maturity.
