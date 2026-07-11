# PANEL-01-b — Fix: real background-slot swap evidence + comment style

**Master plan:** `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`, Part 2.
**Corrective to PANEL-01 (landed, `PROMPTS/DONE/PANEL-01.md`). Surgical fix only.**

---

## CONTEXT — two small defects found on INSPECT

**1. Criterion 3 was substituted with an easier test, undisclosed.**
PANEL-01's Criterion 3 required: "replace the default `ColorRect`
background with a different `Control`... and confirm `open()`/`close()`/
`is_open()`/signals still behave identically" — a real runtime swap. The
shipped `test_background_swap_simple()` in
[godot/scripts/tools/panel_base_test.gd](godot/scripts/tools/panel_base_test.gd)
never touches the `background` node at all: it only asserts
`panel is Control` and that `is_open()` survives repeated open/close
cycles. That's a different, easier claim than the one specified, and the
report doesn't flag the substitution (Evidence Rule 2). The underlying
design is very likely fine — `open()`/`close()`/`is_open()` in
[panel_base.gd](godot/scripts/ui/panel_base.gd) only touch `_is_open` and
`visible`, never reach into the `background` child — but "very likely
fine by code reading" is exactly the standard Evidence Rule 4 exists to
reject. This needs one real execution.

**2. Multi-line docstrings violate the project's comment convention.**
`panel_base.gd` and `window_base.gd` use Python-style `"""..."""` triple-quote
docstrings under `open()`, `close()`, `is_open()`, and `request_close()`
(e.g. `"""Open the panel: set visible and emit signal."""`). This project's
convention — stated in the CLAUDE.md system prompt and echoed inside
PANEL-01's own TASK text ("not a docstring block — this project's comment
convention is single-line, WHY-only") — is single-line `##` comments only,
and only when the WHY is non-obvious. These docstrings restate WHAT the
function does (which the name + signature already say) and use a comment
style not used anywhere else in the codebase. Delete them or fold anything
genuinely non-obvious into a one-line `##` above the function, matching
`hud_controller.gd`'s and `input_controller.gd`'s style.

## MODULE — files this prompt touches

- `godot/scripts/tools/panel_base_test.gd` — extend/fix
  `test_background_swap_simple()` (or add a new test function — your call).
- `godot/scripts/ui/panel_base.gd` — remove triple-quote docstrings.
- `godot/scripts/ui/window_base.gd` — remove triple-quote docstring.

## TASK

1. **Real background swap test.** In the test script: instantiate a
   `PanelBase`, call `open()`. Then actually call
   `get_node("background").queue_free()` (or `remove_child` +
   `free`) and `add_child()` a new `TextureRect` named `"background"` in
   its place. After the swap, assert `is_open() == true` still holds,
   call `close()` and assert `is_open() == false` and the `closed` signal
   still fires. This is the literal scenario Criterion 3 originally asked
   for — no design-level substitute.
2. **Docstring cleanup.** In both files, delete the `"""..."""` blocks.
   Where a one-line `##` genuinely adds WHY (not WHAT), keep it in that
   style; otherwise remove entirely, matching the rest of the codebase
   (see `input_controller.gd` for the house style: sparse, WHY-only,
   single `##` line above a function, no line above self-explanatory ones).

## DO NOT TOUCH

- `open()`/`close()`/`is_open()`/signal logic in `panel_base.gd` and
  `window_base.gd` — behavior is correct; this prompt is evidence +
  comment-style only, not a redesign.
- `pausable`/`process_mode` handling in `window_base.gd` — unaffected,
  out of scope.
- Criteria 1, 2, and 4 from PANEL-01 — already satisfied with real
  evidence on inspection; do not re-litigate or re-run unless this
  prompt's changes require it (e.g. a lint re-run is expected as part of
  Criterion 3 below, since it touches these files anyway).

## ACCEPTANCE (3)

1. **Background swap test runs green, real execution.** Paste the literal
   command and output showing: panel open → background node replaced
   (`ColorRect` → `TextureRect`) → `is_open()` still `true` → `close()`
   called → `is_open()` `false` and `closed` signal fired. This directly
   replaces PANEL-01's Criterion 3 evidence.
2. **No triple-quote docstrings remain.**
   `grep -rn '"""' godot/scripts/ui/panel_base.gd godot/scripts/ui/window_base.gd`
   returns zero matches. Paste the output.
3. **Lint clean.** Paste literal `python3 tools/persistent/project_lint.py`
   output — zero real compile errors, zero new warnings in any file this
   prompt touches.

Commit + push per the Git & Push Protocol; bump `VERSION`; append the
completion report to this file, in place, per-criterion verdicts with
pasted evidence.
