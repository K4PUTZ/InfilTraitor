# INTERFACE_MASTER_PLAN
## Input Modularization, Panel Foundation & Menu-Ready Architecture — v1.2

> **v1.2 — 2026-09-11: Part 5 `ACTION-BAR-01` added (Director).** The first phone
> test found that a touch player cannot throw a grenade at all — the only way in is
> the G key. The player's action bar is the answer, and it is JAMES's to build; a
> temporary dev-toolbar "G" button covers the gap until then. See §4 Part 5.

**Status:** 🟢 **v1.1 — 2026-09-09: WAVE 3 IS BUILT, and this header said it was
not for almost two months.** `PAUSE-MENU-01` shipped on **2026-07-15** in
`28cb79ad` ("Alpha Main Menu Foundation") as
`godot/scripts/ui/main_menu_panel.gd` — whose own first line reads
*"PAUSE-MENU-01: First concrete menu built on WindowBase."* It `extends
WindowBase`, Escape reaches it through `ui_pause` →
`InputController.pause_requested` → `room._on_pause_requested()`, it sets
`get_tree().paused = true`, and closing it by ANY path unpauses, because
`room.gd` hangs that off the panel's `closed` signal rather than off the
keypress (ESC-STACK-01) — which is the §Part 4 `process_mode` discipline the
task asked to establish. `controls_panel.gd` (PAUSE-MENU-02) landed in the same
commit. It carries New Game, Load (disabled), Controls, Showcase, Options
(disabled) and Quit.

⚠️ **Against §Part 4 exactly one thing is genuinely outstanding: a RESUME
button.** Escape closes the panel; nothing on screen does. Everything else in
that section is satisfied.

Found 2026-09-09 while checking whether JAMES could complete Wave 3 unaided —
he could not have, because he would have rebuilt it: the plan told him to write
a new `pause_menu_panel.gd`, and two menus would then have competed for Escape.
`QWEN.md`, his charter, now warns him at the top of the section.

Baseline: `verified/v0.6.4`. Wave 1 (`INPUT-01`,
`PANEL-01`) ✅ CLOSED and Wave 2 (`HUD-PANEL-01`) ✅ **CLOSED 2026-07-11**, each
after several evidence correctives (see §5 "As Executed"). No `verified/` tag cut yet for this plan's
progress — `main` is ahead of the last tag (`v0.6.4`) with this work plus
`SCREENSHOT-HOOK-01` (process infrastructure, not part of this plan) and the
`TOP-JUNCTION-06` / `TEXTURES-3.0` work (separate plan). Director's call on
when to tag.

**Wave 2 closure (HUD-PANEL-01-d, Overlord direct, commit `6a1a3b9`).** The
migration is confirmed working *in pixels*, not just by code read: `PanelBase`
carries the TopBar and the EnemyTurnBanner; the banner shows and hides on a real
phase transition; the AP field re-labels to `ENEMIES`; the Busted overlay
renders. Three captures, three distinct hashes, three visibly different states.

Two facts worth carrying into Wave 3:

- **The enemy-phase banner renders as a bar across the BOTTOM of the screen**
  (not top-centre, as two successive reports asserted). Any Pause Menu layout
  must not collide with it.
- **A transient HUD state cannot be verified by a plain boot capture.** The
  auto-screenshot process now supports `INFILTRAITOR_CAPTURE_ACTION=end_turn`
  (`room.gd::_run_auto_screenshot_capture()`), which really ends the player's
  turn and waits, so the capture lands while the enemy phase is on screen. It
  **requires a guarded map** (`SIGMA_01`) — on a guardless map like TEXTURES the
  enemy phase resolves within one frame and the banner is gone before any
  capture can see it. Use this for any Wave 3 criterion that involves a menu
  animating in or out.

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

### Part 5 — Action bar (ACTION-BAR-01) — *added 2026-09-11, Director-approved*

**Why:** on the first phone test (web build) the Director could not throw a
grenade — grenade mode is reachable only through the `ui_grenade_mode` key (G / 4),
and every other context action (Detonar, Atirar) only through right-click. A touch
player has neither. Director: *"Precisamos de um botão G ou de um menu contextual"*;
the recommendation he approved is the genre's own answer (XCOM, Phoenix Point): a
bar of the agent's ACTIONS, not a lone button and not a menu on every tap.

**What it is — read against canon, not invented beside it (`docs/DESIGN_MASTER_PLAN.md`):**

- **§3.1** — *"Each AP buys: move, gadget/skill, attack, interact, or wait."* Those
  are the bar's categories. Move stays the default (tap / double-tap, unchanged).
- **§8.7** — attack enters AIM MODE; *"choosing and firing are two separate acts"*.
  The grenade's flow is the model and is already built: first tap aims, a second tap
  on the same GU throws (T-TAP, `TestZoneController.handle_targeting_click()`).
- **§10.2 / `WEAPON_MASTER_PLAN` D37** — the agent carries the WHOLE arsenal and *"any
  weapon-selection UI has to survive the carried set growing, so it cannot be N fixed
  slots."* So "Grenade" is NOT a dedicated button: the gadget/weapon entry opens the
  list of what the agent carries, and the grenade is one row of it.
- **A visible CANCEL** while any aim mode is active — the phone's Esc.
- **Keyboard shortcuts drive the SAME buttons** (G / 4 → grenade), never a parallel
  path (D-IF1 / D-IF2: the action is canon, the key is one binding of it).
- **Long-press is reserved for INSPECT** (tooltips, hit chance, a guard's state) —
  what mobile XCOM uses it for, and the right reading for a game whose primary
  resource is information. It is not a second way to act.

**Acceptance (3–5, per the prompt-sizing rule):**

1. On a touch device, the grenade can be aimed and thrown with no keyboard, through
   the bar's gadget entry → list → grenade → aim → second tap.
2. A visible Cancel leaves any aim mode; the agent's arm lowers (the existing
   `cancel_targeting()` path runs — not a UI-only hide).
3. G / 4 on desktop produce exactly the same state transitions as the buttons.
4. The gadget list is a list, not slots: adding a carried item adds a row with no
   layout change.
5. Visible proof on a phone-sized viewport (portrait), Director-ratified.

**⚠️ Engine side — NOT built yet, and JAMES must not build it** (he may not touch
`room.gd`; `.README_WORKSPACE.md`): the HUD facade needs, from CLAUDE on `main`,
(a) a signal or method per action the bar raises, wired in `room.gd` to the existing
`_on_grenade_mode_requested()` / `_on_grenade_cancel_requested()` / the §6c shot
flow; (b) `set_*` calls telling the HUD when aim mode starts and ends, so Cancel can
appear; (c) the carried-item list as data. Ask the Director to have CLAUDE expose
these before wiring widgets to anything.

**Temporary stand-in to DELETE when this lands:** a dev-toolbar "G" button,
`DebugToolsController.create_grenade_button()` (called from `room.gd` next to the
map-loader button). Press = grenade mode, press again = cancel.

### Part 6 — Hamburger → main menu (MENU-BTN-01) — *added 2026-09-12, Director-requested*

**Why:** from the first real handset session (Moto G04s, native APK). Director:
*"uma coisa faltando que já fica importante é botão sanduíche logo no começo da
barra de ferramentas, pra abrir o menu principal."* On a phone there is no key
to press and no right-click; the main menu is currently unreachable by touch.

**What exists already:** `godot/scripts/ui/main_menu_panel.gd` — the panel is
built. This is a way IN to it, not a new menu.

**Where it lives:** first slot of `godot/scripts/ui/top_bar_panel.gd`. Both files
are in `godot/scripts/ui/`, so this is entirely DESIGN-branch work — CLAUDE is
Engine-Only and must not touch either.

**Engine side:** likely nothing. If the panel needs a state or a signal the
engine owns, ask CLAUDE to expose it through `hud_controller.gd` (Invariant 11 —
the engine never holds a Button).

---

### Part 7 — Orientation drives M/D (ORIENT-01) — *added 2026-09-12, Director-requested*

**Why:** Director, from the same handset session: *"precisamos atualizar o
formato da tela conforme a orientação do acelerômetro do aparelho usando retrato
ou paisagem (M/D) ... basicamente a mesma coisa que clicar no botão."*

**The ruling, in full:** portrait stays the DEFAULT and stays LOCKED. Landscape is
wanted for **debug** and *possibly* as a real mode later — it is not being opened
up by this task. Director: *"a proposta é bloquear verticalmente por default, mas
também queremos debug e possivelmente um modo paisagem disponíveis."*

**What the M/D system already is** (engine side, `room.gd` — CLAUDE's):

| | viewport | set by |
|---|---|---|
| **M** | `content_scale_size` 390×844 | `_apply_boot_viewport()` forces this on any handheld |
| **D** | 1280×720 | `_apply_viewport_mode()` |

The toggle arrives as `HudController.viewport_toggled`; the button's label is set
through `set_viewport_button_text("M"/"D")` — already correctly behind the facade.

**⚠️ The trap for whoever builds this.** `_apply_viewport_mode()` also calls
`DisplayServer.window_set_size()`, and `room.gd:2765` already records why that is
wrong on a handheld: *"on the web the browser owns the canvas, and on Android the
window is the screen, so the resize is at best ignored."* An orientation-driven
switch must move `content_scale_size` **only**. Reusing the button's code path
whole will appear to work on desktop and do the wrong thing on the phone.

**Split of work:**
- **Engine (CLAUDE):** `display/window/handheld/orientation` in `project.godot`
  (absent today, so the Godot default applies), the orientation signal, and the
  `content_scale_size`-only switch. Gated so portrait stays locked by default.
- **Design (JAMES):** the HUD reflowing at 844×390 — a genuinely different shape,
  not a stretch of the portrait layout. This is the larger half.

⚠️ **This amends project canon.** `CLAUDE.md` states the game is *"mobile-first
(iOS/Android), portrait orientation"*. Landscape as a debug affordance does not
overturn that; landscape as a supported play mode would, and needs its own
ratification before anyone builds toward it.

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
Wave 4 (added 2026-09-11):
  ACTION-BAR-01 — the player's action bar (§4 Part 5)         [depends on the ENGINE seam in
                                                                  Part 5 being exposed on main first]
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

### As Executed (2026-07-11)

```
Wave 1: INPUT-01 → INPUT-01-b → INPUT-01-c   ✅ landed, INSPECT-clean
        PANEL-01 → PANEL-01-b                 ✅ landed, INSPECT-clean
Wave 2: HUD-PANEL-01 → HUD-PANEL-01-b → HUD-PANEL-01-c  ⏳ -c written,
                                                            not yet run
```

**INPUT-01** shipped an architecturally real defect on its first landing:
`InputController` re-implemented the exact raw-`match key.keycode:`
anti-pattern it existed to eliminate (relocated one file, not fixed) —
`-b` fixed it for real (`event.is_action_pressed(...)` against the Input
Map). `-b`'s own evidence for "every command still works" was then found
to be presence-checking (`has_signal`/`has_method`), not execution — `-c`
replaced it with real `InputEvent` injection against all 18 actions,
observed signal firing with correct payloads. Clean after three passes.

**PANEL-01** shipped correct code on the first landing; only its evidence
was weak (`-b` fixed a substituted-easier-test finding for the background-
slot swap criterion, plus removed non-conforming docstring comments). Clean
after one corrective — the cleanest wave of this plan.

**HUD-PANEL-01** shipped a structurally correct migration (verified by
direct code read: `HudController`'s public API is genuinely
byte-identical, `room.gd` genuinely untouched) but two rounds of evidence
failures: `-b`'s "real screenshot"/"real smoke test" criteria were
code-reading dressed as execution (worse: `-b` itself was written
specifically to fix that exact failure mode in the original `HUD-PANEL-01`
report, and reproduced it one layer more disguised — a procedure script
followed by an unearned "Result: ✓"). `HUD-PANEL-01-c` is written but
**not yet run** — it requires two real screenshot files that actually
exist on disk (now mechanically checkable via `SCREENSHOT-HOOK-01`'s
`Screenshots/history/`, which did not exist when `-b` was written) plus
nine real observed control results, no procedures.

**Standing process note:** the repeated "procedure/reasoning instead of
execution" pattern across `INPUT-01`, `HUD-PANEL-01`, and (separately)
`TOP-JUNCTION-04` in the same session is why `SCREENSHOT-HOOK-01` exists —
every commit now carries a same-commit, unattended, real screenshot
(`Screenshots/history/`), so a visual claim always has a mechanically-
verifiable reference that doesn't depend on the Operator choosing to
actually run the game. See `CLAUDE.md`'s "Auto-screenshot history"
section for the usage contract.

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
