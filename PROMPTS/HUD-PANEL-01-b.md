# HUD-PANEL-01-b — Fix: Criteria 3 and 4 were code-reading, not execution

**Master plan:** `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`, Part 3.
**Corrective to HUD-PANEL-01 (landed, `PROMPTS/HUD-PANEL-01.md`).
Evidence-only — do not restructure the panel migration itself unless
execution surfaces a real defect.**

---

## CONTEXT — this is a discipline-severity finding, not a nitpick

Direct read of the shipped code (`hud_controller.gd`, `top_bar_panel.gd`,
`enemy_banner_panel.gd`, `room.tscn`) confirms the migration is
structurally sound: `HudController`'s public signals/methods are verbatim
what Criterion 2 required, `room.gd` is genuinely untouched, and the
delegation pattern (panel references populated in `setup()`, `show_enemy_banner()`/
`hide_enemy_banner()` delegating to `open()`/`close()` when a panel is
present) reads correctly. **This prompt is not asking you to redo the
migration.**

The problem is that two of the five acceptance criteria were marked
"PASSED" while the report's own text admits they were never executed:

**Criterion 3** ("real screenshot, before/after, pixel-same expected... Boot
the game, capture the HUD...") — the report's "Verification method" section
is a paragraph of reasoning about what the diff *should* preserve
("Refactoring added scripts... without modifying: node hierarchy,
anchors..."). No screenshot was captured, before or after. This is Evidence
Rule 4 territory exactly — code-reading confidence presented as execution
confidence — and Evidence Rule 7 required labeling this "not executed here"
rather than PASS.

**Criterion 4** ("smoke test, real execution... paste console output /
describe each observed effect") — the report's own section header says
**"via code inspection"** and every bullet point is a citation of a line
number and a description of what the code does (e.g. "End Turn button:
HudController._connect_buttons() line ~160 connects..."). The game was
never run. This is the same failure mode INPUT-01's original Criterion 2
had (flagged and corrected in INPUT-01-b) and TOP-JUNCTION-04's Criteria 1/3
just had (flagged in TOP-JUNCTION-04-b) — recurring a third time in this
wave is itself a process signal: **treat this prompt's completion report
with a full re-read against Evidence Rules 1–7 before accepting it**, not
just the two items named here.

This is exactly the escalation the Overlord's Verification Policy calls
for: an L1 finding that contradicts a report escalates the whole wave, not
just the one prompt. Two consecutive prompts in this wave (TOP-JUNCTION-04,
HUD-PANEL-01) both marked unexecuted claims as PASS — that is no longer a
one-off, it is a pattern for this session and should be named as such in
the completion report's self-check, not just fixed silently.

## MODULE — files this prompt touches

- None expected in production code. This is a re-run of two acceptance
  checks with real execution, plus an honest report. If real execution
  surfaces an actual functional defect (a button that doesn't work, a
  layout that shifted), fix it minimally and say so explicitly — that
  would be a genuine, unexpected finding, not scope creep.

## TASK

1. **Real screenshot, before/after.** Boot the game (editor or the
   project's existing screenshot tooling — `_capture_screenshot_to_file()`
   is already wired to `debug_screenshot`). Capture the HUD in its default
   state. Trigger a real enemy phase (not a manual `.visible` toggle, not
   a direct call to a private method — go through the actual game flow
   that causes `show_enemy_banner()` to fire) and capture the HUD with the
   banner visible. If a "before" (pre-migration) capture doesn't exist and
   can't be reconstructed, compare the "after" capture against the layout
   description in HUD-PANEL-01's own CONTEXT section (node structure,
   anchors) and state plainly that the comparison is against that
   description, not a literal pre-migration screenshot — per Evidence Rule
   7, name the limitation rather than implying a comparison that didn't
   happen.
2. **Real smoke test, actual execution.** Run the game and, for each
   control, perform the real action and observe the real result: click
   End Turn, click Reset, toggle fullscreen, toggle viewport mode, toggle
   numbers, take a turn and observe the AP counter update, trigger an
   alert-level change and observe the alert label/color update, let (or
   force, via the real game flow) an enemy phase start and end to observe
   the banner show/hide, trigger a real busted condition to observe the
   dialog show/hide. Paste console output (`print_debug` lines, if any
   fire) and describe the observed on-screen effect for each — not a
   citation of the connecting code.

## DO NOT TOUCH

- `hud_controller.gd`, `top_bar_panel.gd`, `enemy_banner_panel.gd`,
  `room.tscn`'s HUD structure — no changes unless TASK 2 surfaces a real,
  observed defect (in which case: fix minimally, document what broke and
  why, and treat it as new information, not as something this prompt
  originally asked for).
- `BustedDialog`/`PerspectivePad` scope decisions from HUD-PANEL-01 — not
  reopened here.

## ACCEPTANCE (2)

1. **Real screenshot evidence**, both HUD states (default + enemy-banner
   visible), captured via actual execution, paths/descriptions pasted. Any
   comparison-limitation (no true pre-migration screenshot available) is
   named explicitly rather than implied away.
2. **Real smoke-test evidence**, all 9 controls/flows listed in TASK 2,
   each with an observed (not read) result. If any control does not
   behave as expected, report it as a finding — do not silently fix and
   hide it, and do not silently downgrade it to a deferred item without
   flagging it loudly (per Evidence Rule 1).

Commit + push per the Git & Push Protocol; bump `VERSION`; append the
completion report to this file, in place, per-criterion verdicts with
pasted evidence. **Also add, at the top of the report, a one-paragraph
self-check** (per `OPERATOR_CONTEXT.md`'s "Self-check before writing
✅ Complete anywhere") confirming every criterion in this corrective has a
pasted, literal, executed transcript directly above it — this wave has had
three prior instances of that self-check being skipped.
