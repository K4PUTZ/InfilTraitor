# Godot Skill

## Current Scope

- launch the INFILTRAITOR Godot project via `open -a Godot.app`
- wait until the Godot editor is stable enough to interact with
- switch Godot workspaces by visible tab label
- focus key Godot dock panels by visible label
- open visible scenes by OCR label, with quick-open fallback
- run and stop the project via Godot shortcuts
- capture the Output panel for evidence and OCR follow-up
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
- `wait_for_text_absent` — wait until blocking text like `Importing` disappears
- `wait_for_godot_editor` — wait until Godot looks stable enough to manipulate
- `godot_switch_workspace` — switch to `2d`, `3d`, `script`, or `assetlib`
- `godot_focus_panel` — click `scene`, `filesystem`, `inspector`, `node`, `output`, or `history`
- `godot_open_scene` — open a scene by label with quick-open fallback
- `godot_run_project` — send the Godot run shortcut
- `godot_stop_project` — send the Godot stop shortcut
- `godot_capture_output` — focus the Output panel and capture a screenshot

## Current Best Practices

- launch Godot and wait for editor readiness before any OCR-based interaction
- prefer workspace and panel labels before raw coordinates
- treat OCR as a usable fallback, not a guaranteed truth source
- capture Output evidence after important Godot workflows
- return to the editor target when the task goal does not explicitly require staying in Godot

## Next Steps

1. Add post-action verification loops so workspace switches, scene opens, and run/stop actions are confirmed instead of assumed.
2. Improve scene opening beyond visible labels by integrating FileSystem search or a stronger quick-open routine.
3. Package common editor workflows like open-scene-then-run, import-wait, and output-error-capture as reusable higher-level actions.
4. Add richer Godot output analysis so James can summarize errors directly for the planning brain.

## Plan Step Integration

These capabilities now map directly to plan step action types:

- `wait_for_godot_editor`
- `godot_switch_workspace`
- `godot_focus_panel`
- `godot_open_scene`
- `godot_run_project`
- `godot_stop_project`
- `godot_capture_output`

The next layer should package these into reusable multi-step workflows with verification.
