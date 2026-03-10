# Godot Skill

## Current Scope

- launch the INFILTRAITOR Godot project via `open -a Godot.app`
- bring Godot to the foreground via `activate_app`
- return to VS Code after external work using the focus stack

## Available Primitives (ready to use in plans)

The full interaction layer is now available. Godot plans can use any of these step types:

- `click` / `double_click` — click by known coordinates
- `click_text` — screenshot → OCR → find text → click (preferred for UI buttons and tabs whose position varies)
- `type_text` — type into focused field (scene name, search bar, etc.)
- `key_combo` — keyboard shortcuts (e.g. `{"key": "s", "modifiers": ["command"]}` for Ctrl+S)
- `drag` — drag in the Godot canvas or scene tree
- `capture_screen` — capture evidence at any step
- `wait_for_text` — poll OCR until expected text appears (useful for import dialogs)

## Next Steps

1. **`wait_for_import`** — after launch, poll OCR for "Import" or "Importing…" text to clear before sending any click. Prevent timing errors caused by clicking while the editor is still loading.
2. **`godot_open_scene <path>`** — use `click_text` on the FileSystem panel to navigate to a scene, or use `key_combo` (Ctrl+O) to open the file browser, then `type_text` the path.
3. **`godot_switch_workspace <2d|3d|script>`** — click the workspace tab buttons at the top of the editor (`click_text` on "2D", "3D", or "Script").
4. **`godot_capture_output`** — screenshot the Output panel after a test run. OCR for errors.
5. **`godot_stop_game`** — send the Stop shortcut (`key_combo` F8 or the Stop button via `click_text`).

## Plan Step Integration

These would map to new plan step action types once packaged as higher-level steps:

- `wait_for_godot_import`
- `godot_open_scene`
- `godot_switch_workspace`
- `godot_capture_output`

For now they can be composed directly from the available primitives (`click_text`, `wait_for_text`, `key_combo`).
