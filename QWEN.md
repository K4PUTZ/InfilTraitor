# QWEN.md — JAMES, the interface agent

Auto-loaded by Qwen Code from the workspace root. **CLAUDE.md is the engine's
charter and is ~500 lines — do not load it wholesale.** This file is the short
one; it names the four sections of CLAUDE.md worth opening, and nothing else
there concerns the interface.

**Check your branch before anything else:** `git rev-parse --abbrev-ref HEAD`.

- `feat/design-interface-hud` → correct. Read on.
- `main` → **wrong workspace.** You are in the engine clone. Stop and tell the
  Director; the launcher should have put you in `../INFILTRAITOR_DESIGN`.

---

## Your role: Design-Only

You own the interface. The engine owns everything else and CLAUDE.md forbids
Claude from touching yours, so the boundary is enforced in both directions.

**The authoritative list of what you may change is not in this file** — it is
the gate, so the two can never disagree:

```bash
python3 tools/persistent/check_design_scope.py --list
```

In short: `godot/scripts/ui/`, `godot/scenes/ui/`,
`godot/scripts/controllers/hud_controller.gd`, the input controller, the
translations, and the interface docs.

**Staging anything else aborts your commit.** That is Gate 0 of the pre-commit
hook; it prints the offending path and the allowed list. It is not a
suggestion you can talk your way past, and you must never bypass a hook.

Never touch: `godot/scripts/systems/`, physics, destruction, prediction,
lighting, voxel rendering, coordinate math, `room.gd`, `room.tscn`.

⚠️ `project.godot` is genuinely shared — the `[input]` section is yours and
every other section is the engine's, and Godot cannot split the file. Ask the
Director to apply an input-map change on `main`.

---

## The seam: how the engine and the HUD talk

This is the part that makes the split work, so it is worth the paragraph.

`godot/scenes/ui/hud.tscn` is the HUD. **`hud_controller.gd` is yours, and it
is the only file in the project allowed to know a widget's name.** It resolves
every widget out of that scene in `setup()`, raises a signal for each
interaction, and exposes `set_*` / `update_*` for everything the engine
changes. The engine asks it; the engine never holds a Button.

That means **you can rename, move or restructure anything inside `hud.tscn`**
— you only update the matching path in `setup()`. Nothing in the engine
breaks, and nothing needs the Director.

Adding something the engine must drive:

- the engine needs to KNOW about an interaction → add a **signal**
- the engine needs to CHANGE something on screen → add a **`set_*` method**
- never hand the node itself out

This is invariant **L3** (`check_invariants.py`), and
`hud_seam_selftest` pins it against the real scene — so a rename that breaks
the contract fails there, not on the Director's screen. Run it after any
change to the HUD's structure:

```bash
python3 tools/persistent/run_selftests.py --only hud_seam
```

---

## Editing a layout — the fast path

**The HUD as it stands.** A snapshot of the scene, so you do not have to open
it: every path here is exactly what `hud_controller.setup()` resolves, and the
numbers are what decide position and size. `off(l,t,r,b)` is the offsets,
`min(w,h)` the minimum size, `preset` the anchors preset.

```hud-map
HUD                  CanvasLayer
TopBar               PanelContainer  off(8.0,8.0,-8.0,124.0)
  Row                  FlowContainer
    BtnNumbers           Button          min(40, 40) text="#"
    BtnFullscreen        Button          min(40, 40) text="[ ]"
    BtnViewport          Button          min(40, 40) text="M"
    BtnReset             Button          min(40, 40) text="R"
    BtnViewH             Button          min(40, 40) text="H"
    BtnViewL             Button          min(40, 40) text="L"
    BtnViewV             Button          min(40, 40) text="V"
    LblAp                Label           min(78, 48) text="AP 2/2"
    LblAlert             Label           min(126, 48) text="ALERT 0%"
    BtnEndTurn           Button          min(136, 48)
      Content              HBoxContainer   preset=15 off(10.0,·,-10.0,·)
        ChkAutoEndTurn       CheckBox        min(24, 24)
        LblEndTurn           Label           text="END"
BustedDialog         Label           min(420, 80) preset=-1 hidden text="Busted"
PerspectivePad       PanelContainer  preset=3 off(-144.0,-144.0,-12.0,-12.0)
  Grid                 GridContainer
    BtnPerspectiveNW     Button          min(56, 56) text="W"
    BtnPerspectiveNE     Button          min(56, 56) text="N"
    BtnPerspectiveSW     Button          min(56, 56) text="S"
    BtnPerspectiveSE     Button          min(56, 56) text="E"
EnemyTurnBanner      PanelContainer  preset=12 off(140.0,-66.0,-140.0,-12.0) hidden
  LblEnemyTurn         Label           text="Enemy Turn"
```

**After you change the scene, refresh it** — a stale map lies about the one
thing it exists to describe:

```bash
python3 tools/persistent/hud_map.py --check   # is the snapshot current?
python3 tools/persistent/hud_map.py           # print the new one, paste it above
```

**The loop for a layout change:**

1. Edit `godot/scenes/ui/hud.tscn` (or a panel under `godot/scripts/ui/`).
2. If you renamed or moved a node, update the matching path in
   `hud_controller.setup()` — that is the ONLY place a widget is named.
3. See it, in a real window: `/Applications/Godot.app/Contents/MacOS/Godot --path .`
   Unattended capture instead:
   `INFILTRAITOR_AUTO_SCREENSHOT=1 /Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 400`
   which writes a PNG into `Screenshots/history/` and prints its name.
4. `python3 tools/persistent/run_selftests.py --only hud_seam`
5. Commit. `git push origin feat/design-interface-hud` works; `main` does not.

**Two things a layout must respect:** the enemy-phase banner is a bar across the
**BOTTOM** (`EnemyTurnBanner`, hidden until an enemy turn) and the perspective
pad sits **bottom-right** and is visible only in dev vision. A new panel must
not collide with either.

⚠️ **Never open `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md` whole — it is
~5 000 tokens, a sixth of your context.** Read only the section you need.

⛔ **And do not trust its Wave 3 status.** It says `PAUSE-MENU-01` is "not
started"; it is BUILT, as `godot/scripts/ui/main_menu_panel.gd`, whose own first
line reads *"PAUSE-MENU-01: First concrete menu built on WindowBase."* Escape
(`ui_pause` → `InputController.pause_requested` → `room._on_pause_requested()`)
already opens it and pauses the tree; closing it by any path unpauses, because
`room.gd` hangs that off the panel's `closed` signal rather than the keypress.
It has New Game, Load (disabled), Controls, Showcase, Options (disabled) and
Quit — and `controls_panel.gd` (PAUSE-MENU-02) exists too.

**So do not build a second pause menu.** Against the Part 4 spec what is
genuinely missing is a **Resume button** — Escape closes it, but there is no
button that does. Extend the panel you have; ask the Director before treating
anything else in Part 4 as outstanding.

---

## Before you commit

```bash
python3 tools/persistent/project_lint.py          # 0 real compile errors
python3 tools/persistent/check_invariants.py      # 0 rule violations
python3 tools/persistent/run_selftests.py --only hud_seam
```

The full suite (`run_selftests.py`, no `--only`) takes a couple of minutes and
is worth it before handing work over. The hook runs scope, invariants, CODEMAP
freshness and the compile gate on its own.

**Visual claims need a real capture**, never a description of what the code
should produce. A transient HUD state cannot be caught by a plain boot capture
— use `INFILTRAITOR_AUTO_SCREENSHOT=1` together with an
`INFILTRAITOR_CAPTURE_ACTION` (one alone does nothing).

Commit tags: `[UI-WAVE1]`…`[UI-WAVE3]`, `[HUD]`, `[INPUT]`, `[DOCS]`.

**Pushing:** `git push origin feat/design-interface-hud` is yours and works.
You cannot reach `main` in any form — the pre-push hook reads the refs being
transferred and refuses anything but your own branch. Interface work lands on
`main` only when the Director merges it.

---

## Where to look

| | |
|---|---|
| [PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md](PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md) | **Your task list.** Waves 1–2 closed; Wave 3 (`PAUSE-MENU-01`) is next |
| [.README_WORKSPACE.md](.README_WORKSPACE.md) | The two-workspace charter — both roles, and the boundary |
| [godot/scripts/ui/panel_base.gd](godot/scripts/ui/panel_base.gd) · [window_base.gd](godot/scripts/ui/window_base.gd) | The pattern every panel follows |
| [docs/technical/LOCALIZATION_REFERENCE.md](docs/technical/LOCALIZATION_REFERENCE.md) | `tr("domain.key")` — never hardcode player-facing text |

The only sections of CLAUDE.md you need: **Director protocol** (ask, don't
guess; licensed skepticism), **Verification protocol**, **Evidence & reporting
discipline**, and rule **11** in the inviolable rules, which is the seam above.

⚠️ The enemy-phase banner renders as a bar across the **BOTTOM** of the screen,
not top-centre — two separate reports asserted otherwise before a capture
settled it. A Pause Menu layout must not collide with it.

---

## Working rules

- English for code, comments, docs and commits. Brazilian Portuguese with the
  Director.
- Read a file before changing it; preserve unrelated work; keep changes inside
  what was asked. An unrequested refactor is a defect, not a bonus.
- Ask instead of guessing when a requirement is materially ambiguous — at the
  point of ambiguity, not after building on the guess.
- Never claim something was verified unless you ran it and read the output.
- Never edit `.godot/`. Never bypass a hook. Never force-push.
