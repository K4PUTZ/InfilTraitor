# INTERFACE_MASTER_PLAN
## Input Modularization, Panel Foundation & Menu-Ready Architecture — v1.0

**Status:** ⏳ NOT STARTED. Baseline: `verified/v0.6.4` (current `main`).

---

## 0. Purpose & Scope

The interface today is a monolith. All keyboard commands live as a single
~140-line `match` block inside `room.gd`'s `_input()` (2051 lines total), with
raw `KEY_*` scancodes hard-coded — no `InputMap` actions, no names, no single
place to look up "what does this key do." All HUD elements (top bar, busted
dialog, enemy-turn banner, perspective pad) live in one flat `CanvasLayer`
in `room.tscn`, wired through `hud_controller.gd` with no concept of a
"panel" or "window" as a reusable unit — every future menu would either
duplicate that pattern by hand or bolt onto the same file.

This plan does three things, in order:

1. **Input modularization** — every keyboard command becomes a named
   `InputMap` action (`project.godot`), read through one dedicated
   `InputController`, with a single documented table of what's bound to what.
2. **Panel/window foundation** — a reusable `PanelBase`/`WindowBase` pattern
   (simple `Control`-based, no art yet) that both the existing HUD and every
   future menu build on, so the two never diverge.
3. **Proof of concept** — the existing HUD migrates onto the new panel
   pattern, and one new concrete menu (Pause Menu) is built on it, to prove
   the foundation works for something that doesn't exist yet, not just for
   what's already there.

**Explicitly out of scope for this plan:** background art, animated buttons,
transitions/tweening, any menu beyond Pause (main menu, settings, level
select). The foundation must not block those — it must make them additive
later (a new `theme`/background layer slotted into `PanelBase`, not a
rewrite) — but building them now is not the goal.

**Founding insight:** this is the same "pay once, benefit forever" shape as
the bake system's disk cache — a small, deliberate investment in structure
now (input table + panel base) removes an entire recurring class of future
friction (every new menu re-inventing wiring, every new key command creating
another silent collision risk in a 140-line match block).

## 1. Decision Register

| D | Decision | Status |
|---|---|---|
| D-IF1 | **InputMap actions are canon** — every command the game responds to (debug or gameplay) is a named action in `project.godot`'s Input Map, never a bare `KEY_*` comparison in game code. Scancode literals may only appear inside the Input Map itself. | ✅ Ratified 2026-07-11 (Director) |
| D-IF2 | **One `InputController`, single-writer for action dispatch** — a new `godot/scripts/world/controllers/input_controller.gd` owns reading `Input.is_action_just_pressed()`/equivalent and emits signals; `room.gd` connects to signals, it does not match on keycodes itself. Mirrors the project's existing single-writer discipline (cf. inviolable rule 3/5). | ✅ Ratified 2026-07-11 |
| D-IF3 | **Panels are `Control`-based, theme-ready, art-optional** — `PanelBase` (or `WindowBase` for modal/closable ones) exposes an `open()`/`close()` pair, a `title` slot, and a `background` slot that defaults to a flat `ColorRect`/`StyleBox` today and accepts a `Texture2D`/`AnimatedSprite2D` later without changing the panel's external API. No animation system is built now — the slot exists, nothing fills it yet. | ✅ Ratified 2026-07-11 |
| D-IF4 | **HUD is a panel, not a special case** — the existing top bar / busted dialog / enemy-turn banner / perspective pad migrate to sit under the same `PanelBase` convention as any future menu, so there is exactly one pattern in the codebase, not "the old HUD way" plus "the new menu way." `hud_controller.gd`'s existing public API (signals, `update_ap`, etc.) is preserved — this is a structural migration, not a behavior change. | ✅ Ratified 2026-07-11 |
| D-IF5 | **Pause Menu is the proof-of-concept panel** — first net-new menu built on the foundation, deliberately simple (resume / restart / quit; settings entry may be a disabled placeholder button). Opened by a new `ui_pause` action (default `Escape`). Validates the pattern on something that isn't a retrofit. | ✅ Ratified 2026-07-11 |
| D-IF6 | **Debug-only commands stay visibly debug** — F2–F7 and other dev/debug toggles (map loader panel, voxel ruler, nudge mode, bake mode, blend cycle) get named actions too (D-IF1 has no exception), but keep a `debug_` prefix in the action name and stay grouped separately in the Input Map and the reference table, so nobody mistakes them for shippable player-facing commands. | ✅ Ratified 2026-07-11 |

## 2. Current State (ground truth, read 2026-07-11)

- `room.gd` (2051 lines) owns `_input(event)` (camera-priority passthrough,
  then a 15-branch keycode `match`) and `_unhandled_input(event)`
  (Shift+P screenshot hotkey, then mouse-button gameplay dispatch).
- Bound today, all as raw `KEY_*` literals, no `InputMap` entries exist in
  `project.godot` (`[input]` section absent):
  - **Debug/dev:** `F2` map loader panel, `F3` voxel ruler overlay, `F4`
    nudge mode, `F6` bake mode, `F7` cycle blend mode, `K` cycle UI language,
    `R` reset nudge (nudge-mode only), `Shift+P` screenshot.
  - **Gameplay:** `Z` lower posture, `X` raise posture, `V`/`L`/`H` view
    mode (dev/light/heat), `P` peek-pending flag, arrow keys (peek
    direction, or nudge-mode movement with `Shift` = large step).
  - Mouse: wheel zoom + drag handled by `camera_controller.gd`
    (`handle_input`, first priority); left-click tile selection/pathing in
    `_unhandled_input`, gated so GUI `Control`s (HUD buttons) get first
    refusal.
- HUD lives entirely in `room.tscn` under one `CanvasLayer` node "HUD":
  `TopBar` (numbers/fullscreen/viewport/reset/view-mode buttons, AP label,
  alert label, end-turn button+checkbox), `BustedDialog` (Label),
  `PerspectivePad` (4-button grid), `EnemyTurnBanner`. All wired through
  `hud_controller.gd` (173 lines) via a `setup(refs: Dictionary)` call from
  `room.gd` passing `@onready` node references — no panel abstraction, no
  show/hide lifecycle beyond ad-hoc `.visible = true/false`.
- `godot/scripts/world/controllers/debug_tools_controller.gd` already holds
  the actual debug-toggle logic (nudge mode, bake mode, etc.) — `room.gd`'s
  `_input()` only dispatches to it. This plan's input layer sits at the same
  level: `room.gd` should end up dispatching, never matching.
- No existing panel/window base class anywhere in the codebase (confirmed:
  no `PanelBase`, `WindowBase`, or equivalent in `godot/scripts/ui/`).

## 3. Two-Plane Model (interface analog)

Same discipline as the gameplay/geometry coordinate split (Overlord context
§Standing Canon), applied to interface:

- **Action plane** — *what* the player/dev did, named and engine-level
  (`InputMap` action `"ui_pause"`, `"debug_toggle_bake_mode"`). Nothing
  downstream should ever see a raw keycode.
- **Panel plane** — *what* is currently visible/interactive, independent of
  which key opened it (`PauseMenuPanel.open()` can be called by a future
  main-menu button exactly as easily as by the `ui_pause` action).

A prompt that touches input must state which plane it's adding to — a new
key binding is action-plane only; a new menu is panel-plane only; wiring a
key to open a menu is the one place both meet, and that wiring belongs in
`InputController`, not inside the panel itself (a panel never reads
`Input` directly — cf. D-IF2/D-IF3 keeping the two decoupled).

## 4. Parts

### Part 1 — Input Map & InputController (INPUT-01)

- Populate `project.godot`'s Input Map with one action per row of the table
  in §2, named per D-IF1/D-IF6 (`ui_*` for player-facing, `debug_*` for dev
  tools — e.g. `ui_posture_lower`, `ui_view_mode_dev`, `debug_toggle_bake_mode`,
  `debug_screenshot`). Modifier keys (`Shift` for nudge large-step and for
  the screenshot hotkey) stay expressed via `InputEventKey.shift_pressed`
  inside the action definition, not as a separate parallel action.
- New `godot/scripts/world/controllers/input_controller.gd`: owns
  `_input()`/`_unhandled_input()` dispatch via `event.is_action_pressed(...)`
  checks (or `Input.is_action_just_pressed()` where per-frame polling is
  actually needed, e.g. nudge continuous movement), emits one signal per
  action group (mirrors `hud_controller.gd`'s existing signal-emission
  style). Camera passthrough priority (`_camera_controller.handle_input`)
  and the GUI-first-refusal mouse gating are preserved exactly — this is a
  relocation of dispatch logic, not a behavior change.
- `room.gd`'s `_input`/`_unhandled_input` shrink to: camera passthrough,
  then delegate everything else to `InputController`; `room.gd` connects to
  its signals the same way it already connects to `hud_controller`'s.
- **Reference table deliverable:** a new
  `docs/technical/INPUT_REFERENCE.md` listing every action, its default
  binding, and a one-line description — the "single place to look up what a
  key does" this plan exists to create. Table is generated by hand (small
  enough, no tooling needed) but must be kept current the same way
  `CODEMAP.md` is (flag drift as a finding, not silently).

### Part 2 — Panel Foundation (PANEL-01)

- New `godot/scripts/ui/panel_base.gd` (`class_name PanelBase`, extends
  `Control`): `open()`, `close()`, `is_open() -> bool`, a `title: String`
  exported property, and a `background` child slot (a plain `ColorRect`
  by default, per D-IF3) that later work can swap for a `TextureRect` or
  `AnimatedSprite2D` without touching callers. Signals: `opened`, `closed`.
- New `godot/scripts/ui/window_base.gd` (`class_name WindowBase extends
  PanelBase`) for modal/dismissible panels: adds an `close_requested`
  signal wired to a close button and (later, cheap to add) an `Escape`
  binding, plus pause-friendly modal behavior (`process_mode =
  PROCESS_MODE_WHEN_PAUSED` where relevant so a paused game can still show
  the pause menu itself).
- No animation, no tween, no background art asset is added in this part —
  the slot exists and is proven empty-but-functional (flat color), per
  scope in §0.

### Part 3 — HUD Migration (HUD-PANEL-01)

- Wrap the existing `HUD` `CanvasLayer` contents into `PanelBase`-derived
  nodes: at minimum the `TopBar` and `EnemyTurnBanner` become panels (the
  `BustedDialog` and `PerspectivePad` may become panels too if trivial, or
  stay as HUD-controller-managed children if forcing them into the pattern
  adds no value — Operator judgment call, name the choice in the report).
- `hud_controller.gd`'s external API (every signal, every public method
  listed in the file today) is preserved byte-for-byte — `room.gd` must not
  need to change how it talks to `HudController`. This is a **structural**
  migration (D-IF4): internal wiring changes, contracts don't.
- This part is the wave's highest-risk prompt (touches a file every other
  system depends on) — gets an L2 sampling pass at INSPECT, not just L1.

### Part 4 — Pause Menu (PAUSE-MENU-01)

- New `godot/scripts/ui/pause_menu_panel.gd` (`extends WindowBase`):
  Resume, Restart, Quit buttons wired to existing signals/flows already in
  `room.gd` (`reset_requested` etc. — reuse, don't duplicate); a Settings
  button present but `disabled = true` (placeholder, not a new settings
  system — that's future work, D-IF5 scope).
- Opened by the new `ui_pause` action (default `Escape`) via
  `InputController`; closes itself (`WindowBase`'s close affordance) or via
  the same action again (toggle).
- Actually pauses the game (`get_tree().paused = true`) — this is the first
  place in the codebase that needs `process_mode` discipline, so it's also
  where that pattern gets established for future menus.
- Acceptance includes visible proof (screenshot) — Director visual
  ratification, same as every UI-facing prompt in this project's history.

## 5. Prompt Sequence

```
Wave 1 (sequential — Part 2 depends on nothing, Part 1 depends on nothing,
        but Part 3 depends on both):
  INPUT-01   — Input Map + InputController + reference doc      [independent]
  PANEL-01   — PanelBase / WindowBase                            [independent]
Wave 2 (depends on Wave 1 landing + verified):
  HUD-PANEL-01 — migrate existing HUD onto PanelBase             [depends on PANEL-01]
Wave 3 (depends on Wave 2 landing + verified):
  PAUSE-MENU-01 — first concrete menu, proves the foundation     [depends on PANEL-01, INPUT-01;
                                                                    benefits from HUD-PANEL-01 landing
                                                                    first so pause doesn't fight HUD
                                                                    input, but not strictly blocked by it]
```

Wave 1's two prompts are independent of each other (different files, no
shared state) and can be issued together. Wave 2 is a single prompt,
deliberately isolated (§4 Part 3 risk note) — no other prompt should land in
the same wave. Wave 3 closes the plan's proof-of-concept goal.

Per the tightened prompt-sizing rule (Overlord context, 2026-07-10): each
part above is already scoped to 3–5 hard acceptance criteria and one
mechanism. `HUD-PANEL-01` is the one to watch for scope creep — if the
Operator's investigation finds `BustedDialog`/`PerspectivePad` migration
non-trivial, that becomes its own follow-up prompt rather than expanding
this one (mirrors the TOP-01 lesson: don't bundle a structural migration
with edge-case cleanup).

## 6. Verification Notes for INSPECT

- **L0 (all prompts):** `InputMap` actions exist in `project.godot` with
  the names in `INPUT_REFERENCE.md`; `PanelBase`/`WindowBase`/
  `InputController`/`PauseMenuPanel` files exist; `VERSION` bumped per
  prompt.
- **L1 (all prompts):** confirm no `KEY_*` literal remains outside the
  Input Map (grep `KEY_` in `room.gd` post-INPUT-01 — should only match
  modifier checks like `shift_pressed`, if any survive at all); confirm
  `hud_controller.gd`'s public signals/methods are unchanged post-HUD-PANEL-01
  (diff the API surface, not just "it compiles").
  Grep sentinel for D-IF1 compliance:
  `grep -n "KEY_[A-Z_]*:" godot/scripts/world/room.gd` should return nothing
  in gameplay dispatch code after INPUT-01 lands.
- **L2 (one per wave, riskiest):** Wave 2 — hand-trace that `hud_controller.gd`
  callers (`room.gd`'s every `_hud_controller.*` call site) still resolve
  correctly against the migrated panel structure; this is the "touches
  everything" prompt the sampling ladder exists to catch early.
- Screenshot evidence required for HUD-PANEL-01 (before/after, pixel-same
  expected) and PAUSE-MENU-01 (new panel, visible ratification).

## 7. Standing Guards

- No per-frame procedural cost introduced (D12 unaffected — this plan is
  structure only, zero rendering-path changes).
- No player-facing string hardcoded — any new panel label goes through
  `tr("ui.*")` per existing Localization discipline; `hud_controller.gd`'s
  existing `_apply_static_text()`/language-change pattern is the template
  Part 3 and Part 4 both follow, not reinvent.
- `PROCESS_MODE_WHEN_PAUSED` (Part 4) is new territory for this codebase —
  first prompt to use it should note in its report exactly which nodes need
  it and why, so the pattern is documented for the next menu that pauses.
- This plan does not touch bake, voxel, AI, or map systems — B1–B6 and
  rules 1–8 are unaffected by construction; no part of this plan should
  need to reference them beyond this line.

---

*Adopted 2026-07-11. Lives at
`PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`. Baseline `verified/v0.6.4`.
Closes (permanent canon distilled to context static cores, per the baton-pass
protocol) only after Wave 3 lands and is Director-ratified.*
