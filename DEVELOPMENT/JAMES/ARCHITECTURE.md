# James Architecture

## Role Split

James is not the planner.

- James is the local execution operator.
- The active LLM chat session (e.g., Claude Sonnet) is the planning brain.

The brain is not tied to any specific model or provider. Whoever is in the chat window at the time of the request is the brain. James writes a structured brain request to `state/brain_request.json`, the user submits it to the active LLM, and the LLM returns a structured plan written to `state/brain_response.json`.

The control model is:

1. The user holds keypad `0`.
2. James records audio while the key is held.
3. The user releases the key.
4. James transcribes the full prompt.
5. The prompt is sent to the brain (the active LLM in chat).
6. The brain returns a structured plan.
7. James executes the plan with verification and logging.
8. James returns to VS Code and reports the outcome.

## System Layers

### 1. Input Layer

Responsibilities:

- register a global push-to-talk hotkey
- detect key down and key up reliably
- start and stop microphone capture
- produce a timestamped audio artifact for transcription and debugging

Preferred approach:

- use a global event tap or equivalent macOS key monitor
- avoid keyword wake detection entirely

Notes:

- keypad `0` is the desired primary trigger
- fallback bindings should exist in case keyboard layout or numpad availability changes

### 2. Transcription Layer

Responsibilities:

- convert the recorded utterance into text
- return confidence and timing metadata
- keep the raw audio file linked to the session log

Requirements:

- must handle long utterances better than wake-word two-step capture
- should support a pluggable backend

### 3. Brain Handoff Layer

Responsibilities:

- package the user prompt, context, and current machine state
- send that to the planning brain
- receive a structured action plan, not only plain prose

Required output format from the brain:

- `task_id`
- `goal`
- `steps`
- `success_conditions`
- `return_target`
- `safety_level`

The old `brain_request.txt` / `brain_response.txt` pattern proved the general idea but is too weak because it has no task identity, no state schema, and no result history.

### 4. Perception Layer

Responsibilities:

- capture screenshots
- OCR visible text
- detect active application and frontmost window
- classify UI state before and after actions

Preferred strategy order:

1. structured app information
2. explicit UI text detection
3. OCR-based fallback

James must answer these questions before acting:

- Which app is active?
- Which window is frontmost?
- Is the target app in the correct mode?
- Is the intended control visible?
- Is the field editable or only previewed?

### 5. Action Layer

Responsibilities:

- switch applications
- focus windows
- click
- double-click
- drag
- type text
- send shortcuts
- invoke AppleScript
- wait for visible state changes

**Current Implementation Status:**

All core action primitives are implemented and available in the plan executor:

| Action | Implementation | Notes |
|---|---|---|
| `activate_app` | `osascript` | fires-and-returns; no focus verification |
| `click` | `cliclick c:x,y` | logical screen coordinates |
| `double_click` | `cliclick dc:x,y` | logical screen coordinates |
| `drag` | `cliclick dd:x1,y1 du:x2,y2` | full press-drag-release |
| `type_text` | `osascript` System Events keystroke | handles special chars and multi-byte input |
| `key_combo` | `osascript` System Events keystroke + modifiers | command, shift, option, control |
| `click_text` | screencapture → Vision OCR → coordinate conversion → cliclick | for UI buttons/labels where coords are unknown |

Action policy:

- structured commands first (`activate_app`, `key_combo`)
- OCR click (`click_text`) as the fallback when coordinates are not known
- never click the first fuzzy text match without confidence checks and screen verification

### 6. Workflow Layer

Responsibilities:

- execute multi-step tasks
- maintain a focus stack
- pause while external tools work
- poll for completion conditions
- resume and return to VS Code with results

This layer is what makes James suitable for Godot production instead of simple form automation.

Minimum workflow concepts:

- `current_task`
- `task_state`
- `active_app`
- `return_app`
- `wait_condition`
- `retry_budget`
- `verification_required`

### 7. Logging & Memory Layer

Responsibilities:

- persist every action and result
- save screenshots linked to actions
- store task summaries
- record failures in a searchable format
- make patterns reusable later as skills

Recommended logging format:

- `logs/actions.jsonl` for machine-readable action traces
- `sessions/YYYY-MM-DD_HHMM_task.md` for human-readable summaries

Suggested action schema:

- `timestamp`
- `task_id`
- `step_id`
- `frontmost_app_before`
- `action_type`
- `target`
- `parameters`
- `screenshot_before`
- `screenshot_after`
- `verification_result`
- `frontmost_app_after`
- `status`
- `error`

## Godot-Specific Requirements

James is meant to help game production, so he needs Godot-specific skills beyond general GUI control.

Examples:

- launch Godot project
- switch to the 2D editor
- open a scene
- focus the output panel
- wait for project import to finish
- return to VS Code with a summary
- capture build or runtime errors for the brain

## Communication Channels

James uses two channels. Each has a distinct purpose and they do not overlap.

### Voice (audio in / audio out)

Used for conversational, real-time interaction during task execution.

- James speaks brief status cues via `say` using the **Rocko (English US)** voice — deep, gravelly, operator-weight. Voice is configurable via `JamesConfig.say_voice`.
- For objective questions (yes/no, proceed/abort, short clarifications), James speaks the question and captures the answer via push-to-talk.
- Voice answers to clarification questions are recorded and embedded back into the brain request so the LLM can generate a better plan on the next resubmit.
- Keep voice output short. One sentence per cue. No verbose narration.

### Terminal (text out)

Used for structured, persistent, reference data.

- Full outcome report after every `execute-plan` run: status, task ID, goal, confidence, warnings, better alternatives, session notes, evidence paths, tips, log path.
- All warnings and better-alternative suggestions are printed in full.
- Clarification Q&A is echoed to the terminal for reference.
- Errors and failure details are always printed — never only spoken.
- Progress steps are not narrated in the terminal; the action log captures them.

The rule of thumb: audio is the conversational layer; the terminal is the audit layer.



If James leaves VS Code to perform work elsewhere, he must come back with:

- the result status
- key evidence
- paths to logs or screenshots
- next blocking issue, if any

That is a hard requirement, not a convenience feature.
