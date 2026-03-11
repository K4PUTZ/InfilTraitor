# JAMES

James is the local execution operator for INFILTRAITOR development on macOS.

Role split:

- James handles local capture, perception, app control, mouse and keyboard input, focus management, task state, and audit logging.
- The planning brain is external to James. In practice that is the active LLM chat session the user is working in.

James is not the planner. James executes a structured plan.

## Current Status

James is operational and currently ready for full runtime on this machine.

Current verified status:

- `preflight` passes with all required tools and optional Python modules available.
- Push-to-talk capture, transcription, and `brain_request.json` generation work.
- Structured plan execution with safety gates works.
- Focus stack and return-to-editor flow work.
- Godot launch works.
- Higher-level Godot actions now work: wait for editor readiness, switch workspace, focus panel, capture Output panel, run project, stop project, and open scenes with OCR plus quick-open fallback.
- OCR-based click targeting works through Apple Vision.

Current important limits:

- James still lacks general post-action verification loops. Many actions succeed in practice, but they are not yet universally self-verifying.
- The built-in planner is still heuristic. Production use should rely on an external brain-generated plan.
- VS Code automation is still mostly a composition of low-level primitives rather than dedicated first-class actions.

## Why James Exists

Game production on this machine constantly jumps across VS Code, Godot, Terminal, Finder, and browser tools. That context switching is repetitive and hard to audit. James exists to automate the mechanical part of that loop while keeping a task log, evidence trail, and a clean return path back to the editor.

Core local tools James uses:

- `osascript` for app activation and key injection
- `screencapture` for evidence and OCR input
- `say` for short voice cues
- `cliclick` for mouse control
- Apple Vision via PyObjC for OCR
- `ffmpeg` plus `SpeechRecognition` for push-to-talk capture and transcription

## Session Flow

Typical manual flow:

1. Run `./start_james.sh` or `python3 james.py preflight`.
2. Start a task directly or capture a spoken prompt.
3. If using voice capture, James writes `state/brain_request.json`.
4. Paste that request into the active LLM chat and ask for a valid James plan.
5. Save the returned JSON to `state/brain_response.json`.
6. Run `python3 james.py execute-plan`.
7. James evaluates the plan safety gates, executes the steps, logs the run, captures evidence, and returns to the configured editor target when requested.

Safety gates before execution:

- clarification questions stop execution entirely
- better alternatives are surfaced before steps run
- warnings are printed and briefly spoken
- confidence below `0.75` requires confirmation

## Communication Model

Voice is the conversational layer.

- short prompts
- recording status
- proceed or abort questions
- clarification prompts
- final status

Terminal is the audit layer.

- full outcome summary
- warnings and better alternatives
- step failure details
- evidence paths
- session log path

James should never rely on voice alone for anything important.

## Command Surface

All commands are available through `python3 james.py <command>`.

Task and state:

- `preflight`
- `monitor [--once] [--json]`
- `start-task <goal>`
- `note <text>`
- `finish-task [--status] [--note]`
- `status`

Capture and waiting:

- `capture-screen <label>`
- `audio-device`
- `ocr-screen <label>`
- `wait-for-app <name>`
- `wait-for-text <label> <text>`
- `wait-for-text-absent <label> <text>`

Focus and app control:

- `push-focus`
- `pop-focus`
- `activate-app <name>`
- `return-to-editor`

Godot-specific commands:

- `launch-godot [--project <path>]`
- `wait-for-godot-editor [--timeout]`
- `godot-switch-workspace <2d|3d|script|assetlib>`
- `godot-focus-panel <scene|filesystem|inspector|node|output|history>`
- `godot-open-scene <scene> [--no-quick-open]`
- `godot-run-project`
- `godot-stop-project`
- `godot-capture-output [--label]`

Low-level interaction primitives:

- `click <x> <y>`
- `double-click <x> <y>`
- `drag <from_x> <from_y> <to_x> <to_y>`
- `type-text <text>`
- `key-combo <key> [--modifier MOD]`
- `click-text <text> [--label <label>]`

Brain handoff and plan execution:

- `listen [--goal ...]`
- `capture-prompt <goal>`
- `generate-plan`
- `write-sample-plan <task_id>`
- `execute-plan`

## Data Layout

- `james.py` is the CLI entrypoint.
- `runtime_*.py` files implement the runtime subsystems.
- `state/brain_request.json` is the outbound request to the planning brain.
- `state/brain_response.json` is the executable plan James consumes.
- `state/runtime_state.json` stores current and completed task state.
- `logs/actions.jsonl` stores machine-readable action records.
- `logs/screenshots/` and `logs/audio/` store evidence artifacts.
- `sessions/` stores human-readable task summaries.
- `skills/` stores reusable operator patterns and conventions.

## Startup and Environment

- `start_james.sh` now prefers the repo-level virtual environment at `../../.venv/bin/python`.
- `start_james_operator.sh` launches James into dedicated Terminal windows for listen and monitor workflows.
- If that interpreter is not present, it falls back to `python3` on `PATH`.
- Audio input is auto-detected from `ffmpeg -f avfoundation -list_devices true -i ""`, skipping common virtual devices like BlackHole, Teams Audio, and Pro Tools bridge devices.
- On this machine James currently defaults to the `C922 Pro Stream Webcam` microphone because it has been more reliable than the Philips headset input.
- `JAMES_AUDIO_DEVICE_INDEX` overrides the auto-detected device when needed.
- `python3 james.py audio-device` prints the selected device and the full detected input list.
- `python3 james.py listen --goal "Voice operator request"` keeps James alive in one terminal and accepts repeated keypad `0` prompts until `Ctrl-C`.
- `python3 james.py monitor` shows a live dashboard for task, brain file, Godot, and audio-input state.
- `python3 launch_james_operator.py` or `./start_james_operator.sh` opens dedicated operator terminals, checks Godot, and starts listen plus monitor.

## What James Is Good At Right Now

- launching and stabilizing Godot
- switching between editor contexts and returning safely
- capturing screenshots and OCR evidence
- clicking and typing into macOS applications
- executing structured, auditable GUI workflows
- surfacing warnings, alternatives, and failure context instead of silently guessing

## What Still Needs Work

- universal verification after UI actions
- richer Godot workflows like guaranteed scene navigation and error summarization
- stronger VS Code-specific first-class actions
- direct brain integration instead of manual copy-paste between request and response files

## Recommended Next Development Priorities

1. Add verification loops after `click`, `key_combo`, `type_text`, and the higher-level Godot actions.
2. Add richer Godot scene navigation and Output-panel analysis.
3. Expand VS Code actions into first-class plan steps.
4. Replace or supplement the heuristic planner with direct LLM integration.

## Non-Negotiable Safety Rules

- Prefer structured controls over OCR when possible.
- Never assume an interaction succeeded without evidence or verification.
- Always preserve a task identifier and audit trail.
- Always record focus transitions around external app work.
- Require explicit confirmation for low-confidence or destructive workflows.
