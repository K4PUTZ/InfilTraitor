# RESUMO_SESSAO — 2026-08-30 · THE STATE OF THE PROJECT AFTER THE EXPLOSION

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-29_THROW_EVENT_AND_POP.md`
**Kind:** documentation pass — no code changed, no gameplay behaviour touched.
**VERSION:** unchanged at 0.9.107.

> Director, 2026-08-30: *"vamos documentar tudo isso que discutimos. Observe o
> histórico do trabalho e veja o que temos agora em termos de explosão. Além
> disso temos vários masterplans que ficaram abertos e/ou travados por causa da
> explosão. Chegou a hora de atualizar o nosso estado atual."*

---

## 0. Recorded after the fact — the previous session left no summary

The commit that closed 2026-08-29/30, `668512bc` **[DOCS] Define the villain
reveal and ethical acceleration model**, has no `RESUMO_SESSAO`. What it landed,
from the diff:

- **The campaign's structure and its reveal** (`DESIGN_MASTER_PLAN` §2.2–§2.4) —
  an Elite prologue plus three chapters; the Agency/Network fracture is the
  **false** resolution; the Agent is himself the infiltraitor and has known
  throughout. **He knows he is the villain while the player does not.**
- **The fair-reveal contract** — the twist must reinterpret evidence the player
  really saw (targets who recognise him too early, files with contradictory
  dates, "hostiles" who protect civilians), never an off-screen fact produced at
  the finale. The reveal mechanism is the project's own information grammar:
  an outside breach relabels `HOSTILE` as `WITNESS`, `WEAPON CACHE` as `EVIDENCE
  ARCHIVE`. *"The game has done to the player what the player does to guards:
  controlled behaviour by controlling information."*
- **The monetisation model changed shape** — from *"ads + optional cosmetics,
  never pay-to-win"* to **transparent paid acceleration over a complete free and
  offline path**: the full campaign, Freelance and every power stay earnable,
  paid boosts only arrive sooner, ads stay voluntary and never become a toll, and
  there are no purchased random rewards or FOMO mechanics in an all-ages product.
  D33/D36 in `ACTOR_MASTER_PLAN` were re-worded to match, and MONET-01's
  acceptance criteria rewritten.

Nothing above was re-litigated in this session; it is recorded so the design has a
session trail like everything else.

## 1. What this session did

An audit of the repo's own history, then a correction pass over the state
documents. **Method: every claim below was read out of the plans, the commits or
the code — not remembered.**

### The finding that organises everything

**The nine days 2026-08-21 → 2026-08-29 are one arc — materials → performance →
the detonation's presentation layer — and every commit in the window belongs to
it.** The character/movement track has not been touched since **2026-08-20**. The
explosion was not merely the active work; it was the thing several other plans
were sequenced behind, and three of them were still *describing* a world that
D-6's deletion had removed.

### The explosion, as it stands

`DETONATION_PRESENTATION_MASTER_PLAN` is ✅ **FULLY CLOSED — design and
engineering, 2026-08-29.** cook → fuse → boom (E-POP) → **one commit frame** →
the consequence channel → the light after the smoke clears. Measured: the whole
event **4 797 → 2 310 ms** on fabric and **2 940 → 878 ms** on hard materials
(D-0); the commit frame **59.2 / 31.6 ms** (D-1, which corrected the plan's own
18.55 ms claim); `play_consequence_light()`'s freeze **158 → 17.7 ms**, gate-proven
**0 of 206 096 cells** different (D-7); ~3 000 lines deleted and `room.gd`
9 722 → 8 484 (D-6).

⚠️ **Written down as a gap, not smoothed over:** no end-to-end wall-clock
re-measure of the event exists *after* D-6 and D-7. Every change since D-0 was a
deletion or a strict reduction — which is an argument, not a measurement.

## 2. The corrections that mattered

| Document | Was saying | Now |
|---|---|---|
| `PERFORMANCE_MASTER_PLAN` | v2.3, "F8 SHIPPED, the fire is 1 885 ms" | ⛔ **v2.4 correction block:** the F-block's subsystem was DELETED by D-6. Method and measurements stand; the code they describe does not exist. §9.11e closed at the root by D-2 (350 → 0 RESTORED); §12.13's "one thing left is P5" superseded twice. Genuinely open: P4, P6, `INFILTRAITOR_HIDE_VOXELS` |
| `MATERIALS_MASTER_PLAN` | M3-6 sequenced behind PERF P7 | 🟢 v1.5 — **P7 shipped 2026-08-26, M3-6 is unblocked**; M4 glass is the named next item |
| `SOOT_STORAGE_REFORM` | 🟢 SS-0…SS-3 DONE | 🟡 **PAUSED at SS-3** since the reform took the sessions; SS-4 also owns `SaveState`'s missing half; §5.3 is the Director's call |
| `TOP_TEXTURE_MASTER_PLAN` | Part 3 BLOCKED on "the destruction system (no implementation plan exists yet)" | 🟢 **UNBLOCKED** — that plan was written, built and closed. Unscheduled, not blocked |
| `OCCLUSION_MASTER_PLAN` | Part 4 waits on "maps with objects" | 🔎 the wait now has an owner: `MATERIALS` M5, blocked on renderer v2 |
| `DETONATION_PRESENTATION_MASTER_PLAN` | header still quoted the 18.55 ms frame | ⛔ corrected inline to D-1's 59.2 / 31.6 ms |
| `docs/README.md` | DESTRUCTION "Part 3 done, Part 5 open"; ASSET_TREE "PLAN ONLY, nothing moved"; SOOT_STORAGE "NOT STARTED"; WEAPON v1.0 | all four refreshed against their own plans |
| `current_state.md` | Animation **0%**, Combat **0%**, "no automated tests", a banner scheduling W-PRECOOK and calling aim mode unbuilt | rows corrected, three systems that were a month of work given rows at all, banner replaced |

**The pattern worth keeping:** every one of those rows was stale in the same
direction — a plan closed, and the index that pointed at it did not. The plans
themselves were accurate; the *pointers* rotted.

## 3. What is open now, ordered by readiness

1. **`MATERIALS` M4 — glass.** The Director's one named explosion follow-up.
2. **M3-6 / M3-7** — lateral propagation, then the measured passage table.
3. **`SOOT_STORAGE_REFORM` SS-4 → SS-6.**
4. **The character / movement track** — parked since 2026-08-20, not blocked.
5. **GAMEPLAY-01 / GAME-01** — and GAME-01's designated last item (W-PRECOOK) is
   already built.
6. Optional and cheap: the `VoxelRenderer` base-occupancy cache (removes D-7's
   45 ms cook step and speeds up every room repaint).
7. Carried, unowned: audio (including D-6's deferred `swiffh`), the glowing edge
   (⚠️ downscoped by the Director's D-4 ruling — the brasa shipped on consumed
   cells), `update_docs.py`'s silent wipe.

## 4. Open questions for the Director

1. **Which of the five tracks comes next.** The explosion no longer decides it,
   and nothing technical orders them.
2. **`SOOT_STORAGE_REFORM` §5.3** — should a wall's scorch outlive the wall?
   2 040 store-only cells after two fires, in a store whose lifetime is one level.
3. **AI-02 resume timing** — open since 2026-07-26 and never re-raised.

## 5. Files changed

`docs/production/current_state.md` (new §"Where the project stands — 2026-08-30",
global status table, explosion banner, animation/narrative/infrastructure rows) ·
`docs/production/milestones.md` (Next Steps — superseding update 2026-08-30) ·
`docs/README.md` (five index rows) · `PROMPTS/PLANNING/PERFORMANCE_MASTER_PLAN.md`
· `PROMPTS/PLANNING/MATERIALS_MASTER_PLAN.md` ·
`PROMPTS/PLANNING/SOOT_STORAGE_REFORM.md` ·
`PROMPTS/PLANNING/TOP_TEXTURE_MASTER_PLAN.md` ·
`PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md` ·
`PROMPTS/PLANNING/DETONATION_PRESENTATION_MASTER_PLAN.md` · this file.
