# James Plan Format

James executes a structured response plan written to `state/brain_response.json`.

The plan is written by the active LLM brain (e.g., Claude Sonnet) in response to a brain request from `state/brain_request.json`.

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
4. If `confidence` < 0.75 → print a warning and prompt `[y/N]` confirmation. If the user does not confirm, abort.

## Step Format

Each step must include:

- `id`
- `action`

Optional fields depend on the action.

## Supported Actions In The Current Executor

### `note`

```json
{ "id": "step-1", "action": "note", "text": "Preparing to switch to Godot." }
```

### `activate_app`

```json
{ "id": "step-2", "action": "activate_app", "app_name": "Godot", "push_current": true }
```

### `launch_godot`

```json
{ "id": "step-3", "action": "launch_godot", "project": "/abs/path/project.godot", "push_current": true }
```

### `capture_screen`

```json
{ "id": "step-4", "action": "capture_screen", "label": "godot_after_launch" }
```

### `wait_for_app`

```json
{ "id": "step-4b", "action": "wait_for_app", "app_name": "Godot", "timeout": 15 }
```

### `wait_for_text`

```json
{ "id": "step-4c", "action": "wait_for_text", "label": "godot_ui", "text": "Scene", "timeout": 15 }
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
    { "id": "s3", "action": "wait_for_app", "app_name": "Godot", "timeout": 15 },
    { "id": "s4", "action": "return_to_editor" },
    { "id": "s5", "action": "finish_task", "status": "completed", "note": "Executor validation complete." }
  ]
}
```

## Automatic Bridge vs Real Brain Plans

`james.py generate-plan` can synthesize a first-pass plan automatically from `state/brain_request.json` using keyword heuristics. This is useful for smoke tests and common development prompts (e.g., "open Godot", "inspect the project").

For production tasks, use the real brain:

1. Run `james.py capture-prompt "<goal>"` to record the prompt and write `state/brain_request.json`.
2. Open `state/brain_request.json` and paste its contents into the active LLM chat (e.g., Claude Sonnet in the VS Code sidebar).
3. Ask the LLM to return a valid James plan in the format above.
4. Write the LLM response to `state/brain_response.json`.
5. Run `james.py execute-plan`.

The brain is not tied to any specific model. Any LLM that can read the request JSON and return a valid plan JSON works.

Command for heuristic fallback:

- `james.py generate-plan`

The bridge is heuristic-based and currently targets common development prompts such as opening Godot, inspecting the project, capturing a screenshot, and returning to the editor.
