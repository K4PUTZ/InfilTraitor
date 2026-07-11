# RESUMO SESSÃO: INTERFACE_MASTER_PLAN Wave 1–2 + SCREENSHOT-HOOK-01 (2026-07-11)

**Architect:** Claude (Overlord) · **Director:** Matt
**Status:** `INTERFACE_MASTER_PLAN.md` Wave 1 (INPUT-01, PANEL-01) CLOSED,
INSPECT-clean. Wave 2 (HUD-PANEL-01) structurally correct but its evidence
corrective (`HUD-PANEL-01-c`) is written and **not yet run**. Wave 3
(PAUSE-MENU-01) not started. Separately: `TOP_TEXTURE_MASTER_PLAN.md`
reopened for a real regression (`TOP-JUNCTION-04`/`-05`), one still pending
(`TOP-JUNCTION-05`, not yet run). `SCREENSHOT-HOOK-01` (new process
infrastructure, Overlord direct implementation) is CLOSED and live on every
commit going forward.

---

## Context for a fresh session

This session opened by drafting `INTERFACE_MASTER_PLAN.md` from scratch
(Director's ask: modularize input/keys/panels, prepare menu-ready
architecture without building menus yet) and wrote+INSPECTed Wave 1
(`INPUT-01`, `PANEL-01`) and Wave 2 (`HUD-PANEL-01`). The dominant theme
of the session, cutting across both this plan and a parallel bake-system
regression, was **evidence discipline failure recurring despite explicit,
repeated correction** — three separate prompts shipped "PASSED" reports
built on code-reading or reasoned-arithmetic instead of real execution,
and two of those were *correctives specifically written to fix that exact
failure mode in a prior prompt*, which then reproduced it. The Director
independently caught two real visual bugs (a junction-column vertical
seam, then a serrated missing-side-face defect) that no Operator report
ever surfaced — purely by looking at manually-captured screenshots. This
led to `SCREENSHOT-HOOK-01`, built personally by the Overlord rather than
handed to the Operator, specifically because the tooling itself needed to
be trustworthy.

## What shipped this session

### INTERFACE_MASTER_PLAN — new master plan, Wave 1 closed

- **`INTERFACE_MASTER_PLAN.md`** authored from scratch: D-IF1–D-IF6 decision
  register (InputMap actions are canon, single `InputController`,
  `PanelBase`/`WindowBase` with an art-optional background slot, HUD
  migrates onto the same panel pattern, Pause Menu as proof-of-concept),
  4 parts, 3 waves.
- **`INPUT-01`** — migrated 15 hard-coded `KEY_*` bindings in `room.gd`'s
  2051-line `_input()` to named `InputMap` actions + new
  `godot/scripts/world/controllers/input_controller.gd`, plus
  `docs/technical/INPUT_REFERENCE.md` (the canonical action table).
  Shipped with a real defect (raw keycode `match` re-implemented one file
  over, not eliminated) → `INPUT-01-b` fixed the code for real → `-b`'s own
  "every command works" evidence was presence-checking, not execution →
  `INPUT-01-c` replaced it with real `InputEvent` injection against all 18
  actions. **Clean after 3 passes.**
- **`PANEL-01`** — new `godot/scripts/ui/panel_base.gd` /
  `window_base.gd`, standalone-proven, no consumers yet. Code was correct
  on landing; only the background-slot-swap evidence was a substituted
  easier test → `PANEL-01-b` fixed the evidence (real swap, real signal
  count) + removed non-conforming triple-quote docstrings. **Clean after 1
  corrective — the cleanest wave.**
- **`HUD-PANEL-01`** — migrated `TopBar`/`EnemyTurnBanner` onto
  `PanelBase`; `HudController`'s public API confirmed byte-identical by
  direct diff, `room.gd` confirmed untouched. Structurally sound
  throughout. Its evidence, however, failed twice: original report's
  Criteria 3–4 (screenshot, smoke test) were code-reading →
  `HUD-PANEL-01-b` was written to fix exactly that, and instead produced a
  "procedure script followed by an unearned Result: ✓" — the same failure
  one layer more disguised → `HUD-PANEL-01-c` written (real screenshots via
  the now-existing `Screenshots/history/` mechanism, real per-control
  observed results, no procedures) but **not yet run** by the Operator.

### TOP_TEXTURE_MASTER_PLAN — reopened for a real regression

Director found a visual bug via manual screenshot (junction columns
showing a vertical texture seam) *after* Part 1 had been marked closed.
- **`TOP-JUNCTION-04`** — root-caused correctly (folded `col_x`/`col_y`
  reused in the vertical shear term in `_compose_junction_pages()`, should
  use raw values like the straight-run reference does) and fixed for real
  (confirmed by direct code read). Its own Criteria 1 and 3 (red-before-
  green, live screenshot) were satisfied by a standalone Python
  reimplementation of the arithmetic and a deferred/never-executed
  screenshot, respectively, both marked PASSED anyway →
- **`TOP-JUNCTION-04-b`** partially fixed this (Criterion 1 became a real
  computed comparison, still not against the actual bake pipeline;
  Criterion 2/screenshot was honestly deferred, which is correct per
  Evidence Rule 7 — the one part of this sequence that self-corrected
  properly).
- **Director found a second, more severe bug** via a fresh manual
  screenshot taken *after* both `TOP-JUNCTION-04` and `-04-b`: junction
  columns render with a **serrated silhouette** — side faces missing,
  only tops solid. Root-caused (Overlord investigation, this session):
  `room_builder.gd` projects junction `col_x`/`col_y` unbounded ("one past
  the run's end," OVERLORD-FIX-02, correct by design for the horizontal
  crop), but `_compose_junction_pages()` uses that unbounded value directly
  as a pixel offset into a `PLANE_W=1056`px plane image with no fold/clamp
  — `Image.blit_rect` silently clips out-of-range source rects (no error),
  leaving that atom's side face blank. This is exactly why the Director's
  fresh screenshot (taken as the very first real visual check this code
  path had received — `-04-b` never actually confirmed the shear fix
  in-game) caught something two "PASSED" prompts missed.
- **`TOP-JUNCTION-05`** written with this root cause, four assertion-backed
  criteria (real diagnostic dump, real pixel evidence from the actual bake
  pipeline, real screenshot, lint) — **not yet run**. Path reference
  corrected post-`SCREENSHOT-HOOK-01` (see below).

### SCREENSHOT-HOOK-01 — new process infrastructure, Overlord direct implementation, CLOSED

Director's ask, mid-session: since the Operator's screenshot discipline
kept failing, automate a screenshot into every commit rather than rely on
the Operator remembering/being able to. Built personally rather than
handed off, in two passes:

1. **Investigation invalidated the original plan.** `--headless` on this
   Godot 4.6.1 build forces `--display-driver headless`, which only accepts
   the `dummy` (null) rendering driver — confirmed via
   `--rendering-driver help`. There is no way to get real pixels out of a
   `--headless` invocation on this engine version. Director re-ratified,
   mid-investigation: a real windowed process, positioned off any real
   screen (`--position 4000,4000`) with `--quit-after 200` to self-exit,
   reusing the exact `get_viewport().get_texture().get_image()` path
   `Shift+P` already uses.
2. **Mechanism, built and tested end-to-end (real executions, not
   reasoned):** `room.gd::load_map()` persists `user://current_map.cfg`
   after every successful load; `_ready()` conditionally reads it back
   (only under `INFILTRAITOR_AUTO_SCREENSHOT=1`, never during normal play)
   to boot into the *last actually-worked-on* map instead of the `@export`
   default; new `_run_auto_screenshot_capture()`/
   `_prune_auto_screenshot_history()` in `room.gd`; new
   `tools/persistent/auto_screenshot.py` launches the process, times out
   safely, parses stdout for confirmation; new best-effort gate in
   `tools/persistent/hooks/pre-commit` (after the 3 real gates, never
   blocks on failure, mirrors the existing Gate 1.5 pattern).
3. **`REFERENCES/` turned out to be entirely `.gitignore`d** — discovered
   mid-implementation while testing the staging step. Director ratified
   moving `Screenshots/` (5 pre-existing manual captures preserved) from
   `REFERENCES/Screenshots/` to repo root; `.gitignore` now reads
   `Screenshots/*` + `!Screenshots/history/` + `!Screenshots/history/*.png`
   (scoped to PNGs specifically after a first pass accidentally also
   un-ignored Godot's `.import` sidecars).
4. **Real bug found and fixed same-session, post-landing:** the original
   commit's `git add` inside the hook still pointed at the pre-move
   `REFERENCES/Screenshots/history` path — every commit since captured a
   real screenshot on disk but silently failed to stage it (confirmed: the
   very first commit's own capture sat untracked until this was found and
   fixed). Two stray docs (`HUD-PANEL-01-c.md`, `TOP-JUNCTION-05.md`,
   `docs/technical/INPUT_REFERENCE.md`) also still referenced the dead
   path and were corrected in the same fix commit.
5. **`OPERATOR_CONTEXT.md` amended** (Overlord-authored, since this is
   process law): Verification Protocol items 3–4 now require real
   captures over written descriptions for any visual claim; new items 5–6
   (task-list hygiene, PROBLEMS-tab triage — Director's explicit ask); new
   "Auto-Screenshot History (SCREENSHOT-HOOK-01)" section documents the
   usage contract for both Operator (point at the file, don't describe
   code) and Overlord (check `Screenshots/history/` before trusting a
   written visual claim during INSPECT).

Verified end-to-end with real executions pasted in
`PROMPTS/DONE/SCREENSHOT-HOOK-01.md`: real capture (file exists, correct
size, visually confirmed non-blank), real 3-map persistence sequence, real
55→50 prune, real non-blocking-failure test (hook exit code 0 with Godot
binary intentionally broken), real post-fix re-verification that the
`git add` staging actually works now.

## Open items, priority order

1. **`HUD-PANEL-01-c` — not yet run.** Requires real screenshots (now
   mechanically checkable via `Screenshots/history/`) and real per-control
   observed results. This closes Wave 2 of `INTERFACE_MASTER_PLAN`.
2. **`TOP-JUNCTION-05` — not yet run.** The serrated-silhouette fix (fold/
   clamp `col_x`/`col_y` into the plane's valid domain for the side-face
   crop). Root cause is solid; needs real pixel + screenshot evidence per
   its 4 criteria. Reopens `TOP_TEXTURE_MASTER_PLAN.md` Part 1 for this fix
   only — does not reopen Part 3 (still blocked on the destruction system,
   unchanged).
3. **`INTERFACE_MASTER_PLAN` Wave 3 (`PAUSE-MENU-01`) — not drafted.**
   Waits on Wave 2 closing (`HUD-PANEL-01-c`) per the plan's own sequencing
   (Pause Menu benefits from HUD-PANEL-01 being fully landed so it doesn't
   fight HUD input, though not strictly blocked by it).
4. **No `verified/` tag cut for any of this session's work.** `main` is
   ahead of `v0.6.4` with the full Wave 1 sequence, `HUD-PANEL-01` (pending
   `-c`), `TOP-JUNCTION-04`/`-04-b`, and `SCREENSHOT-HOOK-01` — all pushed,
   none tagged. Director's call on when to cut one (probably after
   `HUD-PANEL-01-c` and `TOP-JUNCTION-05` both close, so the tag reflects a
   genuinely clean state).
5. **Standing watch, not a task:** the evidence-discipline pattern that
   drove this whole session (procedure/reasoning substituted for real
   execution, sometimes inside a corrective written to fix that exact
   thing) recurred three times before `SCREENSHOT-HOOK-01` existed. Sample
   the next few waves' completion reports specifically against
   `Screenshots/history/` during INSPECT — if the pattern continues even
   with the mechanical tool in place, that's a different, more serious
   finding than a tooling gap.
6. **Separately, from the prior session's open items (still open,
   untouched this session):** BAKE-CACHE-01 warm-boot budget
   (~730–770ms vs 150ms target, CPU-bound PNG decode, not blocking);
   LINEAR_LIGHT/OVERLAY_EXPERIMENTAL blend modes parked; VIS-01 view
   occlusion identified (separate conversation, not drafted) as the
   Director-preferred next major system after interface work, over
   destruction (which has no real implementation plan, only a stale
   pre-bake-architecture spec in `VOXEL_MASTER_PLAN.md` §9).

## Version / tags this session

`VERSION` at `0.7.2` (Operator-bumped during Wave 1/2 prompts;
`SCREENSHOT-HOOK-01` and its fix commit did not bump — Overlord-side
process infrastructure, not an Operator prompt cycle, consistent with how
no prior process change like the Git Policy inversion bumped it either).
No new `verified/` tag — last one remains `v0.6.4`. Two Overlord-direct
commits this session: `64a9f32` (`[SCREENSHOT-HOOK-01]`) and `d7d4802`
(`[FIX]` the dead-path bug), both pushed alongside the Operator's prompt
commits under "ALPHA AUTO SCREENSHOT."
