# DEV-HUD-01 — DEV VISION systems status panel

**Status:** DRAFT — pending Director ratification
**Plane:** HUD/debug layer only. No gameplay, no rendering-pipeline changes.

---

## CONTEXT

Debug visualization has grown one keybind at a time (H/L/V views, F6 bake
toggle, F7 blend cycle, shadow/fog overlays, `debug_bake_set_dump`, …) and
there is no single place that answers "what is currently active?". The
Director requested one more DEV VISION info panel that displays which color
systems and vision cycles are live.

**Scope guard:** this is a deliberately small, contained addition. A full
`INTERFACE_MASTER_PLAN` (systematic HUD/menu/console organization) is queued
as the next master plan after the bake facade rounds close; this panel is a
stopgap that the plan will later absorb. Do not restructure HUD nodes, do not
add menus, do not build a console here.

## MODULE

- `godot/scripts/world/controllers/debug_tools_controller.gd` (or a small new
  panel script beside it — Operator's choice, one file)
- Room scene HUD node for the panel container (mirror the existing tile-info
  panel's style/placement conventions; suggest below the tile-info panel,
  top-left)

## INVESTIGATION (before writing code)

Enumerate the real, current set of debug/vision toggles by reading
`debug_tools_controller.gd`, the vision/lighting controllers, and
`bake_config.gd` — the panel must reflect what exists, not a hardcoded guess
of it.

## TASK

1. A DEV VISION status panel that displays, live:
   - active map id + active perspective (N/E/S/W)
   - bake: enabled (F6) · blend mode name (F7) · `facade_enabled` ·
     `material_pattern_enabled` · `debug_bake_set_dump`
   - vision/color systems: state of each debug view toggle found in the
     investigation (H / L / V and any numbered views), fog of war on/off,
     shadow overlay state
2. **Single-source rule (architecture pain: split-brain state):** the panel
   READS live state from the owning systems each refresh — it must not keep
   its own copies of flags. No new autoloads.
3. Refresh on change (hook the existing toggle paths or refresh on a short
   timer — pick one, state which and why in the report).
4. Panel visibility follows the DEV VISION context (visible when the debug
   view is active; hidden in plain play view), consistent with how the
   tile-info panel behaves.

## DO NOT TOUCH

- Gameplay HUD (AP/ALERT/END bar), perspective pad, movement overlay.
- The systems being displayed (read-only integration).
- Keybind assignments.

## ACCEPTANCE

1. Screenshot of the panel with bake ON showing: map id, perspective, blend
   mode name, and every toggle state — plus a second screenshot after pressing
   F7 and one view toggle, showing the panel updated.
2. Headless boot zero errors; toggling F6/F7 and each listed view in a live
   run updates the panel (describe the manual check performed; the screenshots
   are the evidence).
3. Panel reads state via the owning systems' existing accessors — report must
   list which accessor each displayed field uses (proves no duplicated state).
4. `python3 tools/persistent/project_lint.py` pasted, zero real compile errors.
5. Version bump; commit + push per protocol.

**Director ratification (post-Operator):** with the game running, the panel
answers at a glance which color/vision systems are active while cycling
F6/F7/H/L/V.
