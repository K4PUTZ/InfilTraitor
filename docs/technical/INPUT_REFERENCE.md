# INPUT_REFERENCE — Action Map & Bindings

Master plan: `PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`, Part 1.

## Overview

The input system is centralized in the Godot **Input Map** (`project.godot` `[input]` section) and dispatched via `InputController` signals. This document is the single source of truth for what every key does.

## Action Table

| Action Name | Default Binding | Category | Description |
|---|---|---|---|
| `ui_posture_lower` | Z | gameplay | Lower posture: STANDING → CROUCHING → PRONE |
| `ui_posture_raise` | X | gameplay | Raise posture: PRONE → CROUCHING → STANDING |
| `ui_view_mode_dev` | V | gameplay/dev | Switch to dev vision overlay |
| `ui_view_mode_light` | L | gameplay/dev | Switch to light visibility overlay |
| `ui_view_mode_heat` | H | gameplay/dev | Switch to heat/IR overlay |
| `ui_peek` | P | gameplay | Initiate peek mode (follow with arrow key) |
| `ui_move_up` | Up Arrow | gameplay | Nudge or peek upward (direction depends on mode) |
| `ui_move_down` | Down Arrow | gameplay | Nudge or peek downward |
| `ui_move_left` | Left Arrow | gameplay | Nudge or peek leftward |
| `ui_move_right` | Right Arrow | gameplay | Nudge or peek rightward |
| `debug_toggle_map_loader` | F2 | debug | Toggle map loader panel |
| `debug_toggle_voxel_ruler` | F3 | debug | Toggle voxel grid overlay (ruler) |
| `debug_toggle_nudge_mode` | F4 | debug | Toggle nudge mode for fine camera/room positioning |
| `debug_toggle_bake_mode` | F6 | debug | Toggle between baked and generic tile rendering |
| `debug_cycle_blend_mode` | F7 | debug | Cycle bake blend modes (MULTIPLY, TEXTURE_ONLY, MATERIAL_ONLY, OVERLAY, LINEAR_LIGHT) |
| `debug_cycle_language` | K | debug | Cycle UI language (localization testing) |
| `debug_nudge_reset` | R | debug | Reset nudge offset to origin (nudge mode only) |
| `debug_screenshot` | Shift+P | debug | Capture screenshot to `REFERENCES/Screenshots/` |

## Implementation Notes

- **Shift modifier handling:** `debug_screenshot` (Shift+P) is defined in the Input Map with `shift_pressed = true`. This ensures Shift+P triggers only the screenshot action, not the regular peek action (P).
- **Arrow keys dual-purpose:** `ui_move_*` actions serve both nudge mode (fine camera adjustment) and peek mode (tactical direction lookup). The dispatching logic in `room.gd` checks which mode is active and routes accordingly.
- **Continuous poll for step size:** Shift-held (large step vs. small step in nudge mode) is detected at dispatch time via `Input.is_key_pressed(KEY_SHIFT)`, not via action mapping, as continuous hold state must be queried per-frame.
- **Input Map location:** All bindings are defined in `project.godot` under `[input]`, making the map rebindable without code changes (future feature).
- **Dispatcher:** `InputController` (in `godot/scripts/world/controllers/input_controller.gd`) reads events and emits typed signals; `room.gd` connects these signals and executes the resulting game logic, keeping concerns separated.
