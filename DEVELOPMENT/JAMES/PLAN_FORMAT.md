# James Plan Format

James executes a structured response plan written to `state/brain_response.json`.

The plan is usually written by the external planning brain in response to `state/brain_request.json`. James can also generate a heuristic fallback plan through `generate-plan`, including simple conversational reply plans that speak an answer directly.

## Required Top-Level Fields

- `task_id` — copy from the brain request
- `goal` — plain-language description of what this plan achieves
- `confidence` — float 0.0–1.0; below 0.75 James will pause and ask for confirmation
- `success_conditions` — list of strings describing what "done" looks like
- `return_target` — app James should be in when the plan finishes (usually "Visual Studio Code")
- `safety_level` — `"normal"` or `"destructive"`
- `steps` — ordered list of step objects

## Optional But Important Top-Level Fields

- `better_alternative` — string or null; if the user's approach is suboptimal, describe the better way here, bluntly
- `warnings` — list of strings; anything risky, misguided, or likely to fail about this request
- `clarification_needed` — bool; if true, James stops before executing anything and asks the questions below
- `clarification_questions` — list of strings; specific questions James must present to the user before proceeding
- `outcome_tips` — list of strings; practical things the user should check or know after execution

## Safety Gates

James checks these fields **before executing any step**:

1. If `clarification_needed` is `true` → print all `clarification_questions` and exit. No steps run.
2. If `better_alternative` is set → print it prominently before proceeding.
3. If `warnings` is non-empty → print each warning before proceeding.
4. If `confidence` < 0.75 → ask for confirmation by voice capture when available, otherwise fall back to terminal input. If the user does not confirm, abort.

## Step Format

Each step must include:

- `id`
- `action`

Optional fields depend on the action.

### Optional Verification Fields (any step)

You can request post-step verification on most actions. James runs these checks after the step returns success and fails the plan if verification fails.

- `verify_frontmost_app` — expected substring in the frontmost app name
- `verify_text_present` — OCR text that must appear on screen
- `verify_text_absent` — OCR text that must disappear from screen
- `verify_timeout` — timeout in seconds for OCR verification checks (default `8`)
- `auto_verify` — set `false` to disable automatic verification defaults for high-risk UI actions
- `auto_verify_timeout` — timeout budget for automatic verification checks (default `5`)
- `allow_frontmost_change` — set `true` when the step is expected to switch frontmost app

Example:

```json
{
  "id": "s4",
  "action": "godot_switch_workspace",
  "workspace": "script",
  "verify_text_present": "Script",
  "verify_timeout": 10
}
```

## Supported Actions In The Current Executor

### `note`

```json
{ "id": "step-1", "action": "note", "text": "Preparing to switch to Godot." }
```

### `activate_app`

```json
{ "id": "step-2", "action": "activate_app", "app_name": "Godot", "push_current": true }
```

### `speak_text`

Speak a short response through macOS `say`. This is used for direct conversational replies and explicit spoken plan output.

```json
{ "id": "step-2b", "action": "speak_text", "text": "Yes. I can hear you clearly." }
```

### `launch_godot`

Open the requested Godot project when Godot is not running yet. If Godot is already running, James reuses the existing app instance instead of opening another project window.

```json
{ "id": "step-3", "action": "launch_godot", "project": "/abs/path/project.godot", "push_current": true }
```

### `wait_for_godot_editor`

Wait until Godot looks like a stable editor window instead of an import or loading screen.

```json
{ "id": "step-3b", "action": "wait_for_godot_editor", "timeout": 45 }
```

### `godot_switch_workspace`

Click a visible Godot workspace tab by OCR label.

```json
{ "id": "step-3c", "action": "godot_switch_workspace", "workspace": "script" }
```

Supported values currently: `2d`, `3d`, `script`, `assetlib`.

### `godot_focus_panel`

Focus a visible Godot dock panel by OCR label.

```json
{ "id": "step-3d", "action": "godot_focus_panel", "panel": "output" }
```

Supported values currently: `scene`, `filesystem`, `inspector`, `node`, `output`, `history`.

### `godot_open_scene`

Try to open a scene by OCR-visible label. If OCR fails, James can fall back to Godot quick-open unless disabled.

```json
{ "id": "step-3e", "action": "godot_open_scene", "scene": "main.tscn" }
```

```json
{ "id": "step-3f", "action": "godot_open_scene", "scene": "res://scenes/main.tscn", "no_quick_open": true }
```

### `godot_run_project`

```json
{ "id": "step-3g", "action": "godot_run_project" }
```

### `godot_stop_project`

```json
{ "id": "step-3h", "action": "godot_stop_project" }
```

### `godot_capture_output`

Focus the Output panel and capture a screenshot for evidence.

```json
{ "id": "step-3i", "action": "godot_capture_output", "label": "run_output" }
```

### `capture_screen`

```json
{ "id": "step-4", "action": "capture_screen", "label": "godot_after_launch" }
```

### `delegate_code_edit`

Write a structured handoff file for the coding agent when the workflow needs direct source edits. This is the preferred bridge for semantic code changes. By default, James pauses execution after writing the handoff so the coding agent can edit files directly and a later James plan can resume with validation.

```json
{
  "id": "step-4a",
  "action": "delegate_code_edit",
  "summary": "Update the player script to react to the new scene node.",
  "instructions": "Read the relevant script directly from the workspace and implement the behavior change without using blind UI typing.",
  "relevant_files": ["res://scripts/player.gd"],
  "acceptance_criteria": [
    "The script compiles and contains the requested behavior.",
    "The change is minimal and consistent with the existing style."
  ],
  "context_notes": [
    "James has already created or opened the relevant Godot scene.",
    "A follow-up James plan should validate the result inside Godot."
  ],
  "pause_after": true
}
```

Operator follow-up after the coding agent finishes:

- inspect the request with `python3 james.py code-agent-request`
- inspect the completion payload with `python3 james.py code-agent-result`
- record completion with `python3 james.py complete-code-edit "summary of the direct edit" --changed-file <path> --follow-up-note "what James should validate next"`
- prepare the next validation request with `python3 james.py prepare-followup-plan`

### `wait_for_app`

```json
{ "id": "step-4b", "action": "wait_for_app", "app_name": "Godot", "timeout": 15 }
```

### `wait_for_text`

```json
{ "id": "step-4c", "action": "wait_for_text", "label": "godot_ui", "text": "Scene", "timeout": 15 }
```

### `wait_for_text_absent`

```json
{ "id": "step-4d", "action": "wait_for_text_absent", "label": "godot_loading", "text": "Importing", "timeout": 30 }
```

### `wait_for_godot_editor`

Poll screenshots until Godot looks stable enough to interact with. James waits for editor markers like `Scene`, `FileSystem`, or `Inspector`, and rejects screenshots that still look like import/loading screens.

```json
{ "id": "step-4e", "action": "wait_for_godot_editor", "timeout": 45 }
```

### `godot_switch_workspace`

```json
{ "id": "step-4f", "action": "godot_switch_workspace", "workspace": "2d" }
```

Supported workspaces currently: `2d`, `3d`, `script`, `assetlib`.

### `godot_focus_panel`

```json
{ "id": "step-4g", "action": "godot_focus_panel", "panel": "output" }
```

Supported panels currently: `scene`, `filesystem`, `inspector`, `node`, `output`, `history`.

### `godot_open_scene`

James first tries to OCR-match the visible scene name in the Godot UI and double-click it. If that fails, James can fall back to Godot quick-open.

```json
{ "id": "step-4h", "action": "godot_open_scene", "scene": "main.tscn" }
```

Disable the quick-open fallback when needed:

```json
{ "id": "step-4i", "action": "godot_open_scene", "scene": "res://scenes/main.tscn", "no_quick_open": true }
```

### `godot_run_project`

```json
{ "id": "step-4j", "action": "godot_run_project" }
```

### `godot_stop_project`

```json
{ "id": "step-4k", "action": "godot_stop_project" }
```

### `godot_capture_output`

Focus the Godot Output panel and capture a screenshot for evidence or OCR follow-up.

```json
{ "id": "step-4l", "action": "godot_capture_output", "label": "run_output" }
```

### `vscode_focus_terminal`

Focus VS Code integrated terminal with the keyboard shortcut and verify by OCR.

```json
{ "id": "step-4m", "action": "vscode_focus_terminal", "timeout": 8 }
```

### `vscode_focus_panel`

Focus a supported VS Code panel.

```json
{ "id": "step-4n", "action": "vscode_focus_panel", "panel": "problems", "timeout": 8 }
```

Supported values currently: `explorer`, `problems`, `output`.

### `vscode_run_task`

Open VS Code command palette and request a task run by label.

```json
{ "id": "step-4o", "action": "vscode_run_task", "label": "pytest small selection" }
```

Optional follow-up verification fields for this action:

- `expect_text` — OCR text marker expected after launching the task (for example `"passed"`)
- `timeout` — seconds to wait for that marker (default `12`)

```json
{
  "id": "step-4p",
  "action": "vscode_run_task",
  "label": "pytest small selection",
  "expect_text": "passed",
  "timeout": 25
}
```

### `return_to_editor`

```json
{ "id": "step-5", "action": "return_to_editor" }
```

### `finish_task`

```json
{ "id": "step-6", "action": "finish_task", "status": "completed", "note": "Plan complete." }
```

### `click`

Click at a known logical screen coordinate. Requires `cliclick`.

```json
{ "id": "step-7", "action": "click", "x": 500, "y": 300 }
```

### `double_click`

Double-click at a coordinate. Requires `cliclick`.

```json
{ "id": "step-8", "action": "double_click", "x": 500, "y": 300 }
```

### `type_text`

Type text into the currently focused field using `osascript` System Events keystroke. Handles special characters correctly.

```json
{ "id": "step-9", "action": "type_text", "text": "hello world" }
```

### `key_combo`

Send a key combination via `osascript` System Events. `modifiers` can include `"command"`, `"shift"`, `"option"`, `"control"`.

```json
{ "id": "step-10", "action": "key_combo", "key": "s", "modifiers": ["command"] }
```

```json
{ "id": "step-11", "action": "key_combo", "key": "z", "modifiers": ["command", "shift"] }
```

```json
{ "id": "step-12", "action": "key_combo", "key": "return", "modifiers": [] }
```

### `drag`

Click-drag from one coordinate to another. Requires `cliclick`.

```json
{ "id": "step-13", "action": "drag", "from_x": 100, "from_y": 100, "to_x": 400, "to_y": 300 }
```

### `click_text`

Capture a screenshot, run Apple Vision OCR, find the first on-screen element whose text contains `text`, convert the bounding box to logical screen coordinates, and click. This is the preferred method for clicking Godot UI labels, tabs, and buttons when coordinates are not known in advance.

```json
{ "id": "step-14", "action": "click_text", "text": "Scene", "label": "click_scene_tab" }
```

## Execution Notes

- James resolves each step by `action` name inside `james.py`.
- Unsupported actions fail the plan immediately.
- If verification fields are present, James runs post-step verification and fails fast when checks do not match reality.
- Some higher-level actions still rely on OCR and timing internally, so robust plans should combine action steps with explicit verification fields.

## Example

```json
{
  "task_id": "james-demo-001",
  "goal": "Open Godot and return to VS Code",
  "confidence": 0.95,
  "better_alternative": null,
  "warnings": [],
  "clarification_needed": false,
  "clarification_questions": [],
  "outcome_tips": [
    "Check the Godot Output panel for import errors after the editor opens."
  ],
  "success_conditions": [
    "Godot is launched",
    "James returns to the editor"
  ],
  "return_target": "Visual Studio Code",
  "safety_level": "normal",
  "steps": [
    { "id": "s1", "action": "note", "text": "Starting plan." },
    { "id": "s2", "action": "launch_godot", "push_current": true },
    { "id": "s3", "action": "wait_for_godot_editor", "timeout": 45 },
    { "id": "s4", "action": "godot_switch_workspace", "workspace": "script" },
    { "id": "s5", "action": "godot_capture_output", "label": "script_workspace" },
    { "id": "s6", "action": "return_to_editor" },
    { "id": "s7", "action": "finish_task", "status": "completed", "note": "Executor validation complete." }
  ]
}
```

## Automatic Bridge vs Real Brain Plans

`james.py generate-plan` can synthesize a first-pass plan automatically from `state/brain_request.json` using keyword heuristics. This is useful for smoke tests, simple conversational prompts, and common development prompts (e.g., "open Godot", "inspect the project").

For production tasks, use the real brain:

1. Run `james.py capture-prompt "<goal>"` to record the prompt and write `state/brain_request.json`.
2. Open `state/brain_request.json` and paste its contents into the active LLM chat (e.g., Claude Sonnet in the VS Code sidebar).
3. Ask the LLM to return a valid James plan in the format above.
4. Write the LLM response to `state/brain_response.json`.
5. Run `james.py execute-plan`.

The brain is not tied to any specific model. Any LLM that can read the request JSON and return a valid plan JSON works.

Command for heuristic fallback:

- `james.py generate-plan`

The bridge is heuristic-based and currently understands a small set of Godot-oriented prompts such as launching Godot, switching workspace, opening a scene reference, capturing output, and returning to the editor.
