# VS Code Skill

## Current Scope

- push current focus before leaving the editor
- return to the editor through the focus stack or default return app
- use first-class VS Code actions for terminal focus, panel focus, and task runs
- use low-level keyboard and OCR primitives for fallback interactions when needed

## Available Primitives (ready to use in plans)

VS Code plans can use any of the general interaction primitives:

- `activate_app "Visual Studio Code"` — bring VS Code to the foreground
- `key_combo` — trigger Command Palette, run tasks, navigate panels (e.g. `Ctrl+`` for terminal)
- `type_text` — type in the search bar, terminal, or any focused field
- `click_text` — click a named tab, button, or UI label by OCR
- `wait_for_text` / `wait_for_text_absent` — confirm that a visible editor label appears or clears

## Next Steps

1. Add first-class command variants for `inject_summary` and terminal output capture.
2. Add first-class action for running a task and waiting for a specific terminal output marker.
3. Add richer verification so VS Code panel actions can validate specific UI state, not just labels.
4. Add problem-summary extraction workflow from the Problems panel.

## Current Limitation

VS Code terminal/panel/task actions are now first-class, but deeper editor workflows are still less mature than the Godot layer.

## Plan Step Integration

These are now available as named plan step action types:

- `vscode_focus_terminal`
- `vscode_focus_panel`
- `vscode_run_task` (supports optional `expect_text` and `timeout` for marker verification)
