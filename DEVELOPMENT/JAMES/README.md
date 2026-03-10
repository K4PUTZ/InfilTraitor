# JAMES

James is the internal development operator for INFILTRAITOR.

His job is to manipulate the local production environment on macOS while the external brain plans the work. In practice, that means:

- James handles eyes, ears, and hands.
- The active LLM chat session (e.g., Claude Sonnet) handles reasoning, planning, and task decomposition.
- James executes local GUI actions in Godot, VS Code, Chrome, Finder, Terminal, and other tools.

The brain is not tied to any specific model or provider. Whoever is in the chat window when the user submits the brain request is the brain.

## Why James Exists

Game production requires switching between VS Code, Godot, and other tools constantly. That context-switching breaks flow and leaves no audit trail. James automates the mechanical parts of that loop so the developer can stay focused on decisions rather than window management.

The operator is built on native macOS tools already available on this machine:

- `osascript` — app control, UI scripting, and keystroke injection
- `screencapture` — screenshot evidence
- `say` — voice feedback (voice: **Rocko**, English US)
- `cliclick` — mouse click and drag simulation
- Apple Vision framework — on-device OCR (screenshot → text → coordinates)
- `ffmpeg` + `SpeechRecognition` — push-to-talk audio capture

## Key Design Decisions

1. Push-to-talk, not a wake word. Hold keypad `0` to record, release to submit.
2. James does not plan. The active LLM chat is the brain. James reads the plan and acts.
3. The brain must be blunt and honest. If the user's request is wrong or there's a better way, it says so directly.
4. If the brain is not confident (below 75%), James stops and asks for voice confirmation before proceeding.
5. If the brain needs more information before making a safe plan, James stops entirely and presents the questions via voice. No steps execute until those are answered.
6. Every action is logged. James can always explain what it did and why.
7. James maintains task state across app switches and returns to VS Code with a full outcome report.

## How a Session Works

1. Open a new LLM chat in VS Code (Claude Sonnet or any available model).
2. Start James: `./start_james.sh` or `python3 james.py preflight`.
3. Hold keypad `0`, say your request, release. James speaks "Recording" while capturing. When you release, it speaks "Got it" and writes `state/brain_request.json`.
4. Paste the contents of `state/brain_request.json` into the LLM chat. The request includes embedded instructions telling the brain exactly what format to return, including when to flag a better way or request clarification.
5. The brain responds with a JSON plan. Paste it into `state/brain_response.json`.
6. Run `python3 james.py execute-plan`.
7. James speaks the task goal and then checks the plan:
   - **Clarification needed** → James speaks each clarification question via voice and waits for push-to-talk answers. Answers are saved back into `brain_request.json`. James asks you to resubmit to the LLM for an updated plan. No steps execute.
   - **Better alternative exists** → James speaks it bluntly and prints it in full to the terminal.
   - **Warnings** → spoken briefly ("I have 2 warnings. Check the terminal.") and printed in full.
   - **Low confidence (<75%)** → James speaks "Should I proceed?" via voice. Hold keypad `0` and say "yes" to continue, anything else to abort.
8. James executes: switches apps, clicks, types, drags, manages windows, waits for states, captures evidence. Brief voice cues throughout.
9. On completion James speaks the final status, then prints the full outcome report to the terminal: task ID, goal, app state, confidence, alternative, warnings, what happened, evidence, tips, and log path.

## Communication Channels

| Channel | Purpose |
|---|---|
| **Voice (say + push-to-talk)** | Brief conversational cues: task start, recording, done, failures, yes/no questions, clarifications |
| **Terminal** | Structured data: outcome report, warnings, alternatives, Q&A, error details, evidence paths, log location |

Audio is the conversational layer. The terminal is the audit layer. Errors always go to the terminal — never only spoken.

## Current Status

James is fully operational. All runtime modules are implemented and the core loop has been tested end-to-end.

Confirmed working:
- `osascript`, `screencapture`, `say` (voice: Rocko), `cliclick`, `tesseract`, and `Godot.app` are all available on this machine.
- Python deps (`pynput`, `SpeechRecognition`, `pyobjc-framework-Vision`, `pyobjc-framework-Quartz`, `pyobjc-framework-Cocoa`) are installed via `requirements-james.txt`.
- Push-to-talk capture, transcription, and brain request generation work end-to-end.
- Task lifecycle (start → note → capture → finish), focus stack, Godot launch, and return-to-editor are all tested.
- Click, double-click, drag, type text, and key combos are implemented and ready for plan execution.
- OCR → screen coordinate conversion is implemented for text-based clicking in Godot or any app.
- Audio device is auto-detected from `ffmpeg -f avfoundation -list_devices`; virtual/loopback devices (BlackHole, Soundflower, Loopback) are skipped automatically. Override with `JAMES_AUDIO_DEVICE_INDEX`.
- App name matching for `wait-for-app` uses partial/substring matching, so "Godot" matches both "Godot" and "Godot Engine".

## Folder Structure

- `ARCHITECTURE.md` — system design for James
- `PLAN_FORMAT.md` — structured plan format for brain response JSON
- `james.py` — CLI entry point for all operator commands
- `runtime_*.py` — runtime modules (config, models, sessions, brain, capture, vision, voice, apps, plan, planner, preflight, logging, storage, reports, focus, wait, speech, godot)
- `requirements-james.txt` — Python dependencies
- `start_james.sh` — quick-start script
- `logs/` — structured operator logs and action traces (`actions.jsonl`, screenshots, audio)
- `sessions/` — per-session human-readable summaries
- `skills/` — reusable GUI automation patterns for Godot, VS Code, and other tools
- `state/` — runtime state (`runtime_state.json`, `brain_request.json`, `brain_response.json`)

## Feature Set — V1 Progress

- [x] Global push-to-talk hotkey capture (keypad `0`)
- [x] Audio recording on key down / key up
- [x] Prompt transcription (SpeechRecognition + Google Speech API)
- [x] Brain handoff — writes `state/brain_request.json`; brain (active LLM) responds via `state/brain_response.json`
- [x] Screenshot capture and OCR (Apple Vision)
- [x] App-switch and focus actions via `osascript`
- [x] Focus stack to return to VS Code after external tasks
- [x] Persistent structured logs (`actions.jsonl` + per-session `.md`)
- [x] Task result summary at the end of each run
- [x] Click, double-click, and drag via `cliclick` in plan executor
- [x] Type text and key combos via `osascript` System Events in plan executor
- [x] OCR → screen coordinate conversion for text-based clicking (`click_text` step)
- [x] Auto-detect audio input device (skips virtual/loopback devices)
- [x] Configurable voice (default: Rocko, English US)
- [x] Voice-interactive safety gates (clarification, better-way, warnings, confidence check)
- [ ] Verification loop after each click or keyboard action
- [ ] Richer brain planner — replace heuristic keyword bridge with LLM-generated plans for all cases
- [ ] Godot editor interaction (scene open, workspace switch, import wait, error capture)

## Implemented Commands

All commands are available via `python3 james.py <command>`:

| Command | Description |
|---|---|
| `preflight` | Check required tools and Python modules |
| `start-task <goal>` | Create a new task session with a unique ID |
| `note <text>` | Append a note to the current task |
| `capture-screen <label>` | Capture a screenshot and store it as evidence |
| `push-focus` | Push the current frontmost app onto the focus stack |
| `pop-focus` | Return to the last pushed app |
| `activate-app <name>` | Switch to a named macOS application |
| `return-to-editor` | Return to the last pushed app or the default editor |
| `launch-godot [--project <path>]` | Open the INFILTRAITOR Godot project |
| `capture-prompt <goal>` | Push-to-talk capture → transcription → `state/brain_request.json` |
| `generate-plan` | Heuristic bridge: synthesise a plan from `state/brain_request.json` |
| `write-sample-plan <task_id>` | Write a sample plan to `state/brain_response.json` |
| `execute-plan` | Run all steps from `state/brain_response.json` |
| `wait-for-app <name>` | Poll until the named app is frontmost (partial name match) |
| `wait-for-text <label> <text>` | Poll OCR until the text appears on screen |
| `ocr-screen <label>` | Capture and OCR the current screen |
| `click <x> <y>` | Click at logical screen coordinates |
| `double-click <x> <y>` | Double-click at logical screen coordinates |
| `type-text <text>` | Type text into the focused field via System Events |
| `key-combo <key> [--modifier MOD]` | Send a key combination (e.g. `key-combo s --modifier command`) |
| `drag <from_x> <from_y> <to_x> <to_y>` | Click-drag from one position to another |
| `click-text <text> [--label <label>]` | Screenshot, OCR, and click the first on-screen match for text |
| `finish-task [--status] [--note]` | Close the task and write a session summary |
| `status` | Print the current task state as JSON |

## Notes

- Push-to-talk audio device is auto-detected at startup. Override with `JAMES_AUDIO_DEVICE_INDEX`. Device `0` on this machine is BlackHole 16ch (silence) — auto-detection skips it.
- `generate-plan` is a heuristic keyword bridge. Useful for smoke tests but not for production tasks. Paste `state/brain_request.json` into the active LLM chat to get a proper plan, then write it to `state/brain_response.json`.
- `screencapture` requires macOS Screen Recording permission. The permission has been granted on this machine.
- `cliclick` coordinates are logical screen pixels (what you see, not Retina physical pixels). `get_screen_size()` reads Finder desktop bounds which already returns logical points.
- `click_text` takes a screenshot, runs Apple Vision OCR, finds the first entry matching the given text, converts the normalised bounding box to logical screen coordinates, and clicks. Works reliably for UI labels, buttons, and tabs.

## Next Steps

1. **Verification loops** — after each click or type action, capture the screen and confirm the expected state before proceeding. This prevents cascading failures when a step hits an unexpected UI state.
2. **Godot editor skill** — build `wait_for_import`, `open_scene`, `switch_workspace`, `capture_output` using the new click/type/OCR primitives now available.
3. **Direct brain integration** — instead of manually copying the brain request and response, allow James to call the LLM API directly via a local bridge and write the response plan automatically.
4. **VS Code skill expansion** — `focus_terminal`, `run_task <label>`, `inject_summary` via the integrated terminal.

## Non-Negotiable Safety Rules

- Prefer structured control over OCR when possible. OCR is the fallback, not the default.
- Never assume a click or keystroke succeeded without verification.
- Log app focus before and after every action.
- Keep a task identifier for every run.
- Require explicit confirmation for destructive actions unless the task plan authorises them.


His job is to manipulate the local production environment on macOS while the external brain plans the work. In practice, that means:

- James handles eyes, ears, and hands.
- The active LLM chat session (e.g., Claude Sonnet) handles reasoning, planning, and task decomposition.
- James executes local GUI actions in Godot, VS Code, Chrome, Finder, Terminal, and other tools.

The brain is not tied to any specific model or provider. Whoever is in the chat window when the user submits the brain request is the brain.

## Why James Exists

Game production requires switching between VS Code, Godot, and other tools constantly. That context-switching breaks flow and leaves no audit trail. James automates the mechanical parts of that loop so the developer can stay focused on decisions rather than window management.

The operator is built on native macOS tools already available on this machine:

- `osascript` — app control and UI scripting
- `screencapture` — screenshot evidence
- `say` — voice feedback
- `cliclick` — mouse and keyboard simulation
- Apple Vision framework — on-device OCR
- `ffmpeg` + `SpeechRecognition` — push-to-talk audio capture

## Key Design Decisions

1. Push-to-talk, not a wake word. Hold keypad `0` to record, release to submit.
2. James does not plan. The active LLM chat is the brain. James reads the plan and acts.
3. The brain must be blunt and honest. If the user's request is wrong or there's a better way, it says so directly.
4. If the brain is not confident (below 75%), James stops and asks for confirmation. It does not guess.
5. If the brain needs more information before making a safe plan, James stops entirely and presents the questions. No steps execute until those are answered.
6. Every action is logged. James can always explain what it did and why.
7. James maintains task state across app switches and returns to VS Code with a full outcome report.

## How a Session Works

1. Open a new LLM chat in VS Code (Claude Sonnet or any available model).
2. Start James: `./start_james.sh` or `python3 james.py preflight`.
3. Hold keypad `0`, say your request, release. James speaks "Recording" while capturing. When you release, it speaks "Processing" and writes `state/brain_request.json`.
4. Paste the contents of `state/brain_request.json` into the LLM chat. The request includes instructions telling the brain exactly what format to return, including when to flag a better way or request clarification.
5. The brain responds with a JSON plan. Paste it into `state/brain_response.json`.
6. Run `python3 james.py execute-plan`.
7. James speaks the task goal and then checks the plan:
   - **Clarification needed** → James speaks each question and waits for a push-to-talk answer. Answers are saved back into `brain_request.json`. James asks you to resubmit to the LLM for an updated plan. No steps execute.
   - **Better alternative exists** → James speaks it and prints it to the terminal. Still proceeds unless you abort.
   - **Warnings** → spoken briefly ("I have 2 warnings. Check the terminal.") and printed in full.
   - **Low confidence (<75%)** → James speaks the confidence level and asks "Should I proceed?" via voice. Hold keypad `0` and say yes to continue, anything else to abort.
8. James executes: switches apps, manages windows, waits for states, captures evidence. Brief voice cues throughout ("Step failed. Check the terminal." on errors).
9. On completion James speaks the final status, then prints the full outcome report to the terminal: task ID, goal, app state, confidence, alternative, warnings, what happened, evidence, tips, and log path.

## Communication Channels

| Channel | Purpose |
|---|---|
| **Voice (say + push-to-talk)** | Brief conversational cues: task start, recording, done, failures, yes/no questions, clarifications |
| **Terminal** | Structured data: outcome report, warnings, alternatives, Q&A, error details, evidence paths, log location |

Audio is the conversational layer. The terminal is the audit layer. Errors always go to the terminal — never only spoken.

## Current Status

James is operational. All runtime modules are implemented and the core loop has been tested end-to-end.

Confirmed working:

- `osascript`, `screencapture`, `say`, `cliclick`, `tesseract`, and `Godot.app` are all available on this machine.
- Python deps (`pynput`, `SpeechRecognition`, `pyobjc-framework-Vision`, `pyobjc-framework-Quartz`, `pyobjc-framework-Cocoa`) are installed via `requirements-james.txt`.
- Push-to-talk capture, transcription, and brain request generation work end-to-end.
- Task lifecycle (start → note → capture → finish), focus stack, Godot launch, and return-to-editor are all tested.
- `screencapture` requires macOS Screen Recording permission. This permission has been granted and screenshot capture is working.

## Folder Structure

- `ARCHITECTURE.md` — system design for James
- `PLAN_FORMAT.md` — structured plan format for brain response JSON
- `james.py` — CLI entry point for all operator commands
- `runtime_*.py` — runtime modules (config, models, sessions, brain, capture, vision, voice, apps, plan, planner, preflight, logging, storage, reports, focus, wait, speech, godot)
- `requirements-james.txt` — Python dependencies
- `start_james.sh` — quick-start script
- `logs/` — structured operator logs and action traces (`actions.jsonl`, screenshots, audio)
- `sessions/` — per-session human-readable summaries
- `skills/` — reusable GUI automation patterns for Godot, VS Code, and other tools
- `state/` — runtime state (`runtime_state.json`, `brain_request.json`, `brain_response.json`)

## Feature Set — V1 Progress

- [x] Global push-to-talk hotkey capture (keypad `0`)
- [x] Audio recording on key down / key up
- [x] Prompt transcription (SpeechRecognition + Google Speech API)
- [x] Brain handoff — writes `state/brain_request.json`; brain (active LLM) responds via `state/brain_response.json`
- [x] Screenshot capture and OCR (Apple Vision)
- [x] App-switch and focus actions via `osascript`
- [x] Focus stack so James can return to VS Code after external tasks
- [x] Persistent structured logs (`actions.jsonl` + per-session `.md`)
- [x] Task result summary at the end of each run
- [ ] Safe click / type actions via `cliclick` in plan executor
- [ ] Verification loop after each click or keyboard action
- [ ] Richer brain planner — replace heuristic keyword bridge with LLM-generated plans
- [ ] Godot editor interaction (scene open, workspace switch, import wait, error capture)
- [ ] Auto-detect audio device instead of relying on `JAMES_AUDIO_DEVICE_INDEX`

## Implemented Commands

All commands are available via `james.py <command>`:

- `preflight` — check required tools and Python modules
- `start-task <goal>` — create a new task session with a unique ID
- `note <text>` — append a note to the current task
- `capture-screen <label>` — capture a screenshot and store it as evidence
- `push-focus` — push the current frontmost app onto the focus stack
- `pop-focus` — return to the last pushed app
- `activate-app <name>` — switch to a named macOS application
- `return-to-editor` — return to the last pushed app or the default editor
- `launch-godot [--project <path>]` — open the INFILTRAITOR Godot project
- `capture-prompt <goal>` — push-to-talk capture → transcription → `state/brain_request.json`
- `generate-plan` — heuristic bridge: synthesize a plan from `state/brain_request.json`
- `write-sample-plan <task_id>` — write a sample plan to `state/brain_response.json`
- `execute-plan` — run all steps from `state/brain_response.json`
- `wait-for-app <name>` — poll until the named app is frontmost
- `wait-for-text <label> <text>` — poll OCR until the text appears on screen
- `ocr-screen <label>` — capture and OCR the current screen
- `finish-task [--status] [--note]` — close the task and write a session summary
- `status` — print the current task state as JSON

## Notes

- Push-to-talk audio device is configured via `JAMES_AUDIO_DEVICE_INDEX` (default `8`). Device `0` on this machine is BlackHole 16ch which records silence; device `8` is the real mic.
- `generate-plan` is a heuristic keyword bridge. It is useful for smoke tests but should be replaced with a real brain-generated plan for production tasks. Paste `state/brain_request.json` into the active LLM chat to get a proper plan back, then write it to `state/brain_response.json`.
- `screencapture` requires macOS Screen Recording permission. The permission has been granted on this machine.

## Next Steps

1. **Wire `cliclick` into the plan executor** — add `click`, `double_click`, `type`, and `key_combo` step types to `runtime_plan.py` and the executor in `james.py`.
2. **Add verification after click/type actions** — after each interaction step, capture screen and check expected state before proceeding.
3. **Expand the Godot skill** — wait for import completion, open scene files, switch editor workspace, capture run output and errors.
4. **Auto-detect audio device** — query `ffmpeg -f avfoundation -list_devices` at startup and select the correct mic automatically.
5. **Direct brain integration** — instead of manually copying the brain request, allow James to POST to a local bridge that submits to the LLM API and writes the response plan automatically.

## Non-Negotiable Safety Rules

- Prefer structured control over OCR when possible.
- Never assume a click or keystroke succeeded without verification.
- Log app focus before and after every action.
- Keep a task identifier for every run.
- Keep a retry budget instead of looping forever.
- Require explicit confirmation for destructive actions unless the task plan authorizes them.
