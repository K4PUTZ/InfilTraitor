# VS Code Skill

## Current Scope

- push current focus before leaving the editor
- return to the editor through the focus stack or default return app
- use low-level keyboard and OCR primitives to drive common editor actions when needed

## Available Primitives (ready to use in plans)

VS Code plans can use any of the general interaction primitives:

- `activate_app "Visual Studio Code"` — bring VS Code to the foreground
- `key_combo` — trigger Command Palette, run tasks, navigate panels (e.g. `Ctrl+`` for terminal)
- `type_text` — type in the search bar, terminal, or any focused field
- `click_text` — click a named tab, button, or UI label by OCR
- `wait_for_text` / `wait_for_text_absent` — confirm that a visible editor label appears or clears

## Next Steps

1. **`focus_terminal`** — `key_combo` with `` Ctrl+` `` to open/focus the integrated terminal. Verify with `wait_for_text` on the prompt character.
2. **`focus_panel <explorer|problems|output>`** — open a named sidebar or bottom panel via `key_combo` (e.g. Ctrl+Shift+U for Output) then verify with `wait_for_text`.
3. **`run_task <label>`** — open the Command Palette (`key_combo` Ctrl+Shift+P), `type_text` "Run Task", Enter, then `type_text` the task name and Enter.
4. **`inject_summary <text>`** — use `click_text` to focus the terminal, then `type_text` the outcome summary.

## Current Limitation

These are still patterns rather than dedicated first-class James actions. VS Code control is workable now, but less mature than the Godot layer.

## Plan Step Integration

These can currently be composed from existing primitives. Once stable, they would be packaged as named plan step action types:

- `vscode_focus_terminal`
- `vscode_focus_panel`
- `vscode_run_task`
