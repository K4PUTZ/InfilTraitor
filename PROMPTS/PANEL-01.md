# PANEL-01 — PanelBase / WindowBase foundation. No consumers yet.

**Master plan:** `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`, Part 2.
**Sequence: independent of INPUT-01. Both may run in the same wave.**

---

## CONTEXT — why this exists and what it must NOT become

There is currently no panel/window abstraction anywhere in the codebase
(`godot/scripts/ui/` holds `compass_rose.gd`, `fog_of_war_overlay.gd`,
`selection_overlay.gd`, `tile_labels_overlay.gd` — overlays, not panels).
The existing HUD (`room.tscn`'s `HUD` `CanvasLayer`) is wired ad hoc through
`hud_controller.gd`'s `setup(refs: Dictionary)` pattern with raw
`.visible = true/false` toggles. Every future menu would either copy that
pattern by hand (drift risk) or invent its own (inconsistency risk).

This prompt builds the reusable base **and nothing that uses it yet** — no
HUD migration (that's `HUD-PANEL-01`, a separate, deliberately isolated
prompt because it touches a file everything else depends on), no Pause Menu
(that's `PAUSE-MENU-01`). Building a throwaway test scene to prove the base
works in isolation is expected and fits this prompt's scope; wiring it into
`room.tscn`'s actual HUD does not.

**Scope discipline (this is the part most likely to drift):** resist adding
anything not explicitly listed in TASK below — no animation system, no
tween helpers, no theme resource, no background art loading. The `background`
slot must exist and be provably swappable, but today it holds a flat
`ColorRect`/`StyleBoxFlat` and nothing else. If you find yourself writing
tweening code or asset-loading code, stop — that's out of scope per the
master plan §0 and belongs to a future prompt.

## MODULE — files this prompt touches

- **New:** `godot/scripts/ui/panel_base.gd`
- **New:** `godot/scripts/ui/window_base.gd`
- **New (test/proof only):** whatever minimal scene or headless script you
  use to demonstrate `open()`/`close()`/signal behavior actually runs —
  follow the project's existing pattern for standalone verifiers (see e.g.
  `godot/scripts/tools/top_shear_test.gd` as a style reference: a small
  `--headless --script` runnable that asserts and prints PASS/FAIL).

## TASK

1. **`panel_base.gd`** — `class_name PanelBase extends Control`.
   - Exported property `title: String = ""`.
   - `func open() -> void` — sets `visible = true`, emits `opened`.
   - `func close() -> void` — sets `visible = false`, emits `closed`.
   - `func is_open() -> bool` — returns current visibility state (back it
     with an explicit bool if `visible` alone is ambiguous once nested
     under a hidden parent — Operator judgment, name the choice).
   - Signals: `signal opened`, `signal closed`.
   - A `background` child slot: a `ColorRect` (or `PanelContainer` with a
     `StyleBoxFlat`, whichever composes more naturally with Control
     layout — pick one, note why) added as the first child in `_ready()`
     if not already present in the scene tree, sized to fill the panel
     (anchors full-rect). Document in a one-line comment (not a docstring
     block — this project's comment convention is single-line, WHY-only)
     that this slot is designed to be replaced by a `TextureRect` /
     `AnimatedSprite2D` later without changing `open()`/`close()`/the
     public API — that's the load-bearing design constraint this prompt
     exists to satisfy, so it's worth the one line even though it
     describes intent rather than a non-obvious constraint.
2. **`window_base.gd`** — `class_name WindowBase extends PanelBase`.
   - Signal `close_requested` (distinct from `closed` — `close_requested`
     fires when the user asks to close via UI, e.g. a close button;
     `closed` fires from `PanelBase.close()` actually running, per the
     base class. A caller connects `close_requested` to `close()` itself,
     or `WindowBase` can self-wire that wherever it constructs its own
     close button — pick one and be explicit about it in the report).
   - `process_mode` consideration: expose whichever mechanism lets a
     subclass opt into `PROCESS_MODE_WHEN_PAUSED` (needed by the future
     Pause Menu so it stays interactive while `get_tree().paused = true`)
     without forcing every `WindowBase` to pay for it — an exported bool
     (`pausable: bool = false`) that sets `process_mode` accordingly in
     `_ready()` is a reasonable shape; don't over-engineer beyond what's
     needed for one future consumer.
   - No close-button node is required to exist in this prompt (no
     consumers yet, per CONTEXT) — the signal and the process-mode
     plumbing are the deliverable; a concrete close button is
     `PAUSE-MENU-01`'s job when it builds a real window.
3. **Standalone proof.** A runnable script or minimal test scene
   demonstrating: instantiate a `PanelBase`, call `open()`, assert
   `is_open() == true` and `visible == true`, assert `opened` fired; call
   `close()`, assert the inverse and `closed` fired. Same for a
   `WindowBase` instance, additionally asserting `close_requested` behaves
   as documented. This does not need to be a permanent fixture in
   `PLAYGROUND` — a `godot/scripts/tools/panel_base_test.gd` run via
   `--headless --script` (mirroring `top_shear_test.gd`'s style) is
   sufficient and matches how other structural prompts in this project
   have proven a mechanism before anything consumes it (cf. TOP-SHEAR-01).

## DO NOT TOUCH

- `room.tscn`, `room.gd`, `hud_controller.gd` — no HUD wiring in this
  prompt. `HUD-PANEL-01` migrates the HUD in a separate, isolated wave.
- No new menu content (no Pause Menu, no buttons beyond what proves the
  base class works in the standalone test).
- No animation/tween code, no theme resource, no background texture
  loading — the `background` slot stays a flat color in this prompt (see
  CONTEXT scope discipline).

## ACCEPTANCE (4)

1. **Files exist and compile.** `panel_base.gd` and `window_base.gd`
   present at the paths above, `class_name` declarations resolve (no
   duplicate `class_name` collisions — check via lint).
2. **Standalone proof runs green, real execution.** Paste the literal
   command and output of the headless test script from TASK item 3 —
   every assertion (open/close/is_open/signals for both `PanelBase` and
   `WindowBase`) must show a real PASS, not a reasoned "this should work."
3. **Background-slot swap is provably non-breaking** — as part of the same
   standalone proof (or a small addition to it), replace the default
   `ColorRect` background with a different `Control` (e.g. a plain
   `TextureRect`, even with no texture assigned) at runtime and confirm
   `open()`/`close()`/`is_open()`/signals still behave identically. This
   is the concrete evidence for D-IF3 ("background slot accepts a
   different node type later without changing the panel's external API")
   — paste the output.
4. **Lint clean.** Paste literal `python3 tools/persistent/project_lint.py`
   output — zero real compile errors, zero new warnings in every file this
   prompt creates.

Commit + push per the Git & Push Protocol; bump `VERSION`; append the
completion report to this file, in place, per-criterion verdicts with
pasted evidence.
