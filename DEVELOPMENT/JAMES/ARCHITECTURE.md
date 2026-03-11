# James Architecture

## Role Split

James is the local execution operator.

The planning brain is external and produces the plan James will execute. James receives intent either as a direct CLI call or as a generated request in `state/brain_request.json`, and it executes a plan from `state/brain_response.json`.

Current control loop:

1. User starts or restores a task.
2. User may capture a spoken prompt.
3. James writes `brain_request.json`.
4. External brain returns a plan.
5. James loads the plan, applies safety gates, executes steps, logs actions, and writes final session output.

## Runtime Modules

Current runtime split:

- `runtime_config.py` resolves paths, tools, defaults, and audio device detection.
- `runtime_models.py` defines task and action records.
- `runtime_storage.py` handles JSON persistence.
- `runtime_sessions.py` manages current and completed task state.
- `runtime_logging.py` appends action telemetry.
- `runtime_brain.py` writes structured requests for the planning brain.
- `runtime_plan.py` loads execution plans and writes a sample plan.
- `runtime_planner.py` generates heuristic fallback plans.
- `runtime_apps.py` handles app activation, screen size, clicks, drag, type, and key combos.
- `runtime_capture.py` captures screenshots.
- `runtime_vision.py` performs OCR and coordinate lookup.
- `runtime_voice.py` handles push-to-talk capture and speech recognition.
- `runtime_speech.py` wraps `say` output.
- `runtime_wait.py` provides polling for app state and OCR-visible or OCR-absent text.
- `runtime_godot.py` provides higher-level Godot editor helpers.
- `runtime_preflight.py` validates the local runtime.
- `runtime_reports.py` prints the terminal outcome and writes session summaries.

## System Layers

### 1. Input Layer

Current behavior:

- push-to-talk hotkey capture via `pynput`
- keypad `0` bindings from `JamesConfig.push_to_talk_key_vks`
- start and stop audio recording through `ffmpeg`
- record timestamped `.wav` files into `logs/audio/`

### 2. Transcription Layer

Current behavior:

- transcribe saved `.wav` audio through `SpeechRecognition`
- attach transcript and audio artifact to the task state
- surface capture errors without crashing the whole CLI boot path

### 3. Brain Handoff Layer

Current behavior:

- write structured request payloads to `state/brain_request.json`
- include task id, goal, transcript path, current app, return app, clarification answers, and instructions for the planning brain
- load plan JSON from `state/brain_response.json`

Current planning modes:

- real external brain via manual copy-paste
- heuristic fallback planner via `generate-plan`

### 4. Perception Layer

Current behavior:

- capture screenshots through `screencapture`
- OCR screenshots via Apple Vision
- detect frontmost app through `osascript`
- convert OCR bounding boxes into logical click coordinates
- poll until text appears or disappears
- detect when Godot looks editor-ready instead of still importing or loading

### 5. Action Layer

Current low-level primitives:

- `activate_app`
- `click`
- `double_click`
- `drag`
- `type_text`
- `key_combo`
- `click_text`

Current higher-level Godot primitives:

- `launch_godot_project`
- `wait_for_godot_editor_ready`
- `switch_godot_workspace`
- `focus_godot_panel`
- `open_godot_scene`
- `run_godot_project`
- `stop_godot_project`
- `capture_godot_panel`

Important current limitation:

- most actions are not yet universally self-verifying after execution

### 6. Workflow Layer

Current workflow features:

- persistent `current_task`
- task restoration by `task_id`
- focus stack for app return flow
- plan execution with safety gates
- wait steps and evidence capture steps
- end-of-run outcome summary in terminal and markdown session file

### 7. Logging Layer

Current outputs:

- `logs/actions.jsonl` for machine-readable action history
- `logs/screenshots/` for screenshot evidence
- `logs/audio/` for push-to-talk artifacts
- `sessions/*.md` for human-readable summaries
- `state/runtime_state.json` for runtime state

Action records currently track:

- timestamp
- task id
- step id
- action type
- target
- status
- app before and after
- free-form parameters
- screenshot paths
- verification result
- error text

## Communication Model

Voice is for short interaction.

- recording prompts
- brief warnings
- proceed or abort prompts
- clarification questions
- final completion or failure cue

Terminal is for durable truth.

- warnings
- better alternatives
- failure details
- evidence paths
- final task outcome

## Current Architectural Strengths

- clean module separation
- lazy handling of optional OCR and voice imports so `preflight` and `--help` still work
- auditable task and action trail
- Godot-specific higher-level helpers instead of only raw click primitives

## Current Architectural Gaps

- no universal verification framework after UI actions
- heuristic planner remains shallow
- no direct LLM integration
- no first-class VS Code workflow layer yet

## Hard Requirement

If James leaves the editor to perform work, it must come back with enough state for the user and the planning brain to understand what happened.
