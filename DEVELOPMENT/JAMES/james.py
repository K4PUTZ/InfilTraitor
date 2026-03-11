from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import time
import sys

from runtime_apps import activate_app, click_at, double_click_at, drag_from_to, get_app_window_titles, get_frontmost_app, get_screen_size, is_app_running, key_combo, type_text
from runtime_brain import write_brain_request
from runtime_capture import capture_screen
from runtime_config import list_audio_input_devices, load_config
from runtime_focus import pop_focus, push_focus
from runtime_godot import (
    capture_godot_panel,
    focus_godot_panel,
    launch_godot_project,
    open_godot_scene,
    run_godot_project,
    stop_godot_project,
    switch_godot_workspace,
    wait_for_godot_editor_ready,
)
from runtime_logging import append_action
from runtime_models import ActionRecord
from runtime_plan import load_plan, write_sample_plan
from runtime_planner import generate_plan_from_request
from runtime_preflight import run_preflight
from runtime_reports import print_terminal_outcome, write_session_summary
from runtime_speech import speak
from runtime_sessions import finish_task, get_current_task, restore_task, start_task, update_current_task
from runtime_vision import find_text_center_coords, recognize_text
from runtime_voice import capture_push_to_talk, capture_voice_answer
from runtime_wait import wait_for_app, wait_for_text, wait_for_text_absent


def _format_exception(exc: Exception) -> str:
    message = str(exc).strip()
    if message:
        return message
    return exc.__class__.__name__


def _is_unknown_value_error(exc: Exception) -> bool:
    return exc.__class__.__name__ == "UnknownValueError"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="James operator runtime")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("preflight", help="Run tool and dependency checks")
    audio_device_cmd = sub.add_parser("audio-device", help="Show the selected audio input device and all detected inputs")
    audio_device_cmd.add_argument("--selected-only", action="store_true", help="Print only the selected input device summary")

    start = sub.add_parser("start-task", help="Create a new task session")
    start.add_argument("goal", help="Task goal")
    start.add_argument("--return-app", default=None, help="App James should return to")

    note = sub.add_parser("note", help="Append a note to the current task")
    note.add_argument("text", help="Note text")

    capture = sub.add_parser("capture-screen", help="Capture a screenshot for the current task")
    capture.add_argument("label", help="Short label for the screenshot file")

    push = sub.add_parser("push-focus", help="Push current frontmost app onto focus stack")

    pop = sub.add_parser("pop-focus", help="Return to the last pushed app")

    finish = sub.add_parser("finish-task", help="Finish the current task")
    finish.add_argument("--status", default="completed", help="Final task status")
    finish.add_argument("--note", default=None, help="Final note")

    sub.add_parser("status", help="Show current task state")

    monitor_cmd = sub.add_parser("monitor", help="Show a live James runtime status monitor")
    monitor_cmd.add_argument("--interval", type=float, default=1.5, help="Seconds between refreshes")
    monitor_cmd.add_argument("--once", action="store_true", help="Print one snapshot and exit")
    monitor_cmd.add_argument("--json", action="store_true", help="Print JSON snapshots instead of the text dashboard")

    sub.add_parser("execute-plan", help="Execute the structured plan in state/brain_response.json")
    sub.add_parser("generate-plan", help="Generate state/brain_response.json from state/brain_request.json")

    sample_plan = sub.add_parser("write-sample-plan", help="Write a sample executable plan to state/brain_response.json")
    sample_plan.add_argument("task_id", help="Task id to embed in the sample plan")

    ocr = sub.add_parser("ocr-screen", help="Capture a screenshot and print OCR text entries")
    ocr.add_argument("label", help="Short label for the screenshot file")

    wait_app_cmd = sub.add_parser("wait-for-app", help="Wait until the named app is frontmost")
    wait_app_cmd.add_argument("app_name", help="Application name")
    wait_app_cmd.add_argument("--timeout", type=float, default=15.0, help="Seconds to wait")

    wait_text_cmd = sub.add_parser("wait-for-text", help="Wait until OCR sees text on screen")
    wait_text_cmd.add_argument("label", help="Label prefix for screenshots")
    wait_text_cmd.add_argument("text", help="Text to wait for")
    wait_text_cmd.add_argument("--timeout", type=float, default=15.0, help="Seconds to wait")

    wait_text_absent_cmd = sub.add_parser("wait-for-text-absent", help="Wait until OCR no longer sees text on screen")
    wait_text_absent_cmd.add_argument("label", help="Label prefix for screenshots")
    wait_text_absent_cmd.add_argument("text", help="Text that must disappear")
    wait_text_absent_cmd.add_argument("--timeout", type=float, default=15.0, help="Seconds to wait")

    activate = sub.add_parser("activate-app", help="Activate an application by name")
    activate.add_argument("app_name", help="Application name as seen by macOS")
    activate.add_argument("--push-current", action="store_true", help="Push the current frontmost app before switching")

    sub.add_parser("return-to-editor", help="Return to the last pushed app or the default editor app")

    godot = sub.add_parser("launch-godot", help="Launch the INFILTRAITOR Godot project")
    godot.add_argument(
        "--project",
        default="/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/infil-traitor/project.godot",
        help="Path to the Godot project.godot file",
    )
    godot.add_argument("--push-current", action="store_true", help="Push the current frontmost app before switching")

    wait_godot = sub.add_parser("wait-for-godot-editor", help="Wait until Godot editor UI is stable and ready")
    wait_godot.add_argument("--timeout", type=float, default=45.0, help="Seconds to wait")

    godot_workspace = sub.add_parser("godot-switch-workspace", help="Switch Godot to a workspace tab by visible label")
    godot_workspace.add_argument("workspace", help="Workspace name: 2d, 3d, script, assetlib")

    godot_panel = sub.add_parser("godot-focus-panel", help="Focus a Godot dock panel by visible label")
    godot_panel.add_argument("panel", help="Panel name: scene, filesystem, inspector, node, output, history")

    godot_scene = sub.add_parser("godot-open-scene", help="Open a Godot scene by OCR label or quick-open fallback")
    godot_scene.add_argument("scene", help="Scene filename or path, for example main.tscn")
    godot_scene.add_argument("--no-quick-open", action="store_true", help="Disable the quick-open fallback if OCR cannot find the scene")

    sub.add_parser("godot-run-project", help="Run the current Godot project")
    sub.add_parser("godot-stop-project", help="Stop the currently running Godot project")

    godot_output = sub.add_parser("godot-capture-output", help="Focus the Godot Output panel and capture a screenshot")
    godot_output.add_argument("--label", default="godot_output", help="Label for the screenshot file")

    prompt = sub.add_parser("capture-prompt", help="Capture a push-to-talk prompt and write a brain request")
    prompt.add_argument("goal", help="Goal associated with the spoken prompt")
    prompt.add_argument("--return-app", default=None, help="App James should return to after the task")
    prompt.add_argument("--timeout", type=float, default=60.0, help="Seconds to wait for the key-hold capture")

    listen_cmd = sub.add_parser("listen", help="Stay running and accept repeated push-to-talk prompts")
    listen_cmd.add_argument("--goal", default="Voice operator request", help="Default goal stored with each captured request")
    listen_cmd.add_argument("--return-app", default=None, help="App James should return to after tasks created from listen mode")
    listen_cmd.add_argument("--timeout", type=float, default=60.0, help="Seconds to wait for each key-hold capture")
    listen_cmd.add_argument("--cooldown", type=float, default=0.75, help="Seconds to pause between completed listen cycles")

    click_cmd = sub.add_parser("click", help="Click at logical screen coordinates")
    click_cmd.add_argument("x", type=int, help="Horizontal coordinate (logical pixels)")
    click_cmd.add_argument("y", type=int, help="Vertical coordinate (logical pixels)")

    dbl_cmd = sub.add_parser("double-click", help="Double-click at logical screen coordinates")
    dbl_cmd.add_argument("x", type=int, help="Horizontal coordinate (logical pixels)")
    dbl_cmd.add_argument("y", type=int, help="Vertical coordinate (logical pixels)")

    type_cmd = sub.add_parser("type-text", help="Type text into the currently focused field")
    type_cmd.add_argument("text", help="Text to type")

    key_cmd = sub.add_parser("key-combo", help="Send a key combination via System Events")
    key_cmd.add_argument("key", help="Key to press (e.g. 's', 'return', 'escape')")
    key_cmd.add_argument(
        "--modifier",
        dest="modifier",
        action="append",
        default=[],
        metavar="MOD",
        help="Modifier: command, shift, option, control (repeat for multiple)",
    )

    drag_cmd = sub.add_parser("drag", help="Click-drag from one coordinate to another")
    drag_cmd.add_argument("from_x", type=int)
    drag_cmd.add_argument("from_y", type=int)
    drag_cmd.add_argument("to_x", type=int)
    drag_cmd.add_argument("to_y", type=int)

    click_text_cmd = sub.add_parser("click-text", help="Screenshot, OCR, and click the first match for a text string")
    click_text_cmd.add_argument("text", help="Text to find and click")
    click_text_cmd.add_argument("--label", default="click_text", help="Label for the screenshot file")

    return parser


def _require_current_task(config) -> object:
    session = get_current_task(config.runtime_state_path)
    if not session:
        raise SystemExit("No active James task. Start one with start-task.")
    return session


def handle_preflight() -> int:
    config = load_config()
    report = run_preflight(config)
    print(json.dumps(report, indent=2))
    return 0


def handle_audio_device(args: argparse.Namespace) -> int:
    config = load_config()
    devices = list_audio_input_devices(config.ffmpeg_path)
    if args.selected_only:
        selected_name = config.audio_device_name or "unknown"
        print(f"[{config.audio_device_index}] {selected_name}")
        return 0
    payload = {
        "selected_index": config.audio_device_index,
        "selected_name": config.audio_device_name,
        "override_active": "JAMES_AUDIO_DEVICE_INDEX" in os.environ,
        "devices": [
            {
                "index": device.index,
                "name": device.name,
                "score": device.score,
                "selected": device.index == config.audio_device_index,
            }
            for device in devices
        ],
    }
    print(json.dumps(payload, indent=2))
    return 0


def handle_start_task(args: argparse.Namespace) -> int:
    config = load_config()
    return_app = args.return_app or config.default_return_app
    session = start_task(config.runtime_state_path, args.goal, return_app)
    session.active_app = get_frontmost_app(config.osascript_path)
    update_current_task(config.runtime_state_path, session)

    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="start-task",
            action_type="start_task",
            target=args.goal,
            status="ok",
            frontmost_app_before=session.active_app,
            frontmost_app_after=session.active_app,
            parameters={"return_app": return_app},
        ),
    )
    print(session.task_id)
    return 0


def handle_note(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    session.notes.append(args.text)
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="note",
            action_type="task_note",
            target=None,
            status="ok",
            parameters={"text": args.text},
        ),
    )
    print("noted")
    return 0


def handle_capture_screen(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    output_path = config.screenshots_dir / f"{session.task_id}_{args.label}.png"
    before_app = get_frontmost_app(config.osascript_path)
    try:
        capture_screen(config.screencapture_path, output_path)
    except Exception as exc:
        session.active_app = before_app
        session.notes.append(f"Screenshot capture failed for {args.label}: {exc}")
        update_current_task(config.runtime_state_path, session)
        append_action(
            config.actions_log_path,
            ActionRecord.create(
                task_id=session.task_id,
                step_id=f"capture-{args.label}",
                action_type="capture_screen",
                target=args.label,
                status="error",
                frontmost_app_before=before_app,
                frontmost_app_after=before_app,
                error=str(exc),
            ),
        )
        print(f"capture failed: {exc}")
        return 1

    session.evidence.append(str(output_path))
    session.active_app = before_app
    update_current_task(config.runtime_state_path, session)

    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id=f"capture-{args.label}",
            action_type="capture_screen",
            target=args.label,
            status="ok",
            frontmost_app_before=before_app,
            frontmost_app_after=before_app,
            screenshot_after=str(output_path),
        ),
    )
    print(output_path)
    return 0


def handle_push_focus() -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    push_focus(session, before_app)
    session.active_app = before_app
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="push-focus",
            action_type="push_focus",
            target=before_app,
            status="ok",
            frontmost_app_before=before_app,
            frontmost_app_after=before_app,
        ),
    )
    print(before_app or "unknown")
    return 0


def handle_pop_focus() -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    target_app = pop_focus(session) or session.return_app
    success = activate_app(config.osascript_path, target_app)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    if success:
        session.notes.append(f"Returned focus to {target_app}.")
    else:
        session.notes.append(f"Failed to return focus to {target_app}.")
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="pop-focus",
            action_type="pop_focus",
            target=target_app,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            error=None if success else f"Could not activate {target_app}",
        ),
    )
    print(after_app or target_app)
    return 0 if success else 1


def handle_finish_task(args: argparse.Namespace) -> int:
    config = load_config()
    session = finish_task(config.runtime_state_path, args.status, args.note)
    if not session:
        raise SystemExit("No active James task. Start one with start-task.")

    summary_path = config.sessions_dir / f"{session.task_id}.md"
    write_session_summary(summary_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="finish-task",
            action_type="finish_task",
            target=session.goal,
            status=args.status,
            frontmost_app_before=get_frontmost_app(config.osascript_path),
            frontmost_app_after=get_frontmost_app(config.osascript_path),
            parameters={"summary_path": str(summary_path)},
        ),
    )
    print(summary_path)
    return 0


def handle_status() -> int:
    config = load_config()
    session = get_current_task(config.runtime_state_path)
    if not session:
        print("No active task")
        return 0
    print(json.dumps(session.to_dict(), indent=2))
    return 0


def _build_monitor_snapshot(config) -> dict:
    session = get_current_task(config.runtime_state_path)
    request_exists = config.brain_request_path.exists()
    response_exists = config.brain_response_path.exists()
    godot_running = is_app_running(config.osascript_path, "Godot")
    godot_windows = get_app_window_titles(config.osascript_path, "Godot") if godot_running else []

    request_task_id = None
    if request_exists:
        try:
            request_task_id = json.loads(config.brain_request_path.read_text()).get("task_id")
        except Exception:
            request_task_id = None

    response_task_id = None
    if response_exists:
        try:
            response_task_id = json.loads(config.brain_response_path.read_text()).get("task_id")
        except Exception:
            response_task_id = None

    return {
        "frontmost_app": get_frontmost_app(config.osascript_path),
        "audio_input": {
            "index": config.audio_device_index,
            "name": config.audio_device_name,
        },
        "godot": {
            "running": godot_running,
            "windows": godot_windows,
            "project_open": any(token in title.lower() for title in godot_windows for token in ("infil-traitor", "infiltraitor")),
        },
        "brain": {
            "request_exists": request_exists,
            "request_task_id": request_task_id,
            "response_exists": response_exists,
            "response_task_id": response_task_id,
        },
        "current_task": None if not session else {
            "task_id": session.task_id,
            "goal": session.goal,
            "status": session.status,
            "updated_at": session.updated_at,
            "last_note": session.notes[-1] if session.notes else None,
        },
    }


def handle_monitor(args: argparse.Namespace) -> int:
    config = load_config()
    try:
        while True:
            snapshot = _build_monitor_snapshot(config)
            if args.json:
                print(json.dumps(snapshot, indent=2))
            else:
                print("\033[2J\033[H", end="")
                print("JAMES MONITOR")
                print("=" * 60)
                print(f"Frontmost App : {snapshot['frontmost_app'] or 'unknown'}")
                audio_name = snapshot["audio_input"]["name"] or "unknown"
                print(f"Audio Input   : [{snapshot['audio_input']['index']}] {audio_name}")
                print(
                    f"Godot         : {'running' if snapshot['godot']['running'] else 'not running'}"
                    f" | project_open={snapshot['godot']['project_open']}"
                )
                if snapshot["godot"]["windows"]:
                    print(f"Godot Windows : {' | '.join(snapshot['godot']['windows'][:3])}")
                print(
                    f"Brain Files   : request={snapshot['brain']['request_exists']}"
                    f" ({snapshot['brain']['request_task_id'] or '-'})"
                    f" | response={snapshot['brain']['response_exists']}"
                    f" ({snapshot['brain']['response_task_id'] or '-'})"
                )
                task = snapshot["current_task"]
                if task:
                    print("-" * 60)
                    print(f"Task ID       : {task['task_id']}")
                    print(f"Goal          : {task['goal']}")
                    print(f"Status        : {task['status']}")
                    print(f"Updated       : {task['updated_at']}")
                    print(f"Last Note     : {task['last_note'] or '-'}")
                else:
                    print("-" * 60)
                    print("Task          : no active task")
                print("=" * 60)
                print("Ctrl-C to stop monitor")

            if args.once:
                return 0
            time.sleep(max(args.interval, 0.25))
    except KeyboardInterrupt:
        print("\nJames monitor stopped.")
        return 0


def handle_write_sample_plan(args: argparse.Namespace) -> int:
    config = load_config()
    plan_path = write_sample_plan(config.brain_response_path, args.task_id)
    print(plan_path)
    return 0


def handle_generate_plan() -> int:
    config = load_config()
    if not config.brain_request_path.exists():
        raise SystemExit("No brain_request.json found.")
    plan_path = generate_plan_from_request(config.brain_request_path, config.brain_response_path)
    print(plan_path)
    return 0


def _capture_prompt_once(
    config,
    *,
    goal: str,
    return_app: str,
    timeout: float,
    announce_instruction: bool,
) -> int:
    session = start_task(config.runtime_state_path, goal, return_app)
    before_app = get_frontmost_app(config.osascript_path)
    session.active_app = before_app
    update_current_task(config.runtime_state_path, session)

    audio_path = config.audio_dir / f"{session.task_id}.wav"
    if config.audio_device_name:
        session.notes.append(f"Using audio input: [{config.audio_device_index}] {config.audio_device_name}")
        update_current_task(config.runtime_state_path, session)

    if announce_instruction:
        speak(config.say_path, "Press and hold keypad zero to start recording. Release it to submit your prompt.", voice=config.say_voice)
    max_attempts = 2
    result = None
    last_error = None
    for attempt in range(1, max_attempts + 1):
        try:
            result = capture_push_to_talk(
                ffmpeg_path=config.ffmpeg_path,
                audio_device_index=config.audio_device_index,
                trigger_vks=config.push_to_talk_key_vks,
                output_path=audio_path,
                on_recording_start=lambda: speak(config.say_path, "Recording.", voice=config.say_voice),
                on_recording_stop=lambda: speak(config.say_path, "Processing.", voice=config.say_voice),
                timeout=timeout,
            )
            break
        except Exception as exc:
            last_error = exc
            if _is_unknown_value_error(exc) and attempt < max_attempts:
                session.notes.append("Speech was not understood on the first attempt. Retrying capture.")
                update_current_task(config.runtime_state_path, session)
                speak(config.say_path, "I did not catch that. Please try again.", voice=config.say_voice)
                continue
            break

    if result is None:
        exc = last_error if last_error is not None else RuntimeError("Prompt capture failed without a result")
        error_text = _format_exception(exc)
        session.status = "error"
        session.notes.append(f"Prompt capture failed: {error_text}")
        if audio_path.exists():
            session.evidence.append(str(audio_path))
            session.notes.append(f"Audio captured at: {audio_path}")
        update_current_task(config.runtime_state_path, session)
        append_action(
            config.actions_log_path,
            ActionRecord.create(
                task_id=session.task_id,
                step_id="capture-prompt",
                action_type="capture_prompt",
                target=goal,
                status="error",
                frontmost_app_before=before_app,
                frontmost_app_after=get_frontmost_app(config.osascript_path),
                parameters={"audio_path": str(audio_path)} if audio_path.exists() else None,
                error=error_text,
            ),
        )
        if _is_unknown_value_error(exc):
            speak(config.say_path, "I recorded audio, but I could not understand the speech.", voice=config.say_voice)
        print(f"capture failed: {error_text}")
        return 1

    session.notes.append(f"Captured prompt transcript: {result.transcript}")
    session.evidence.append(str(result.audio_path))
    update_current_task(config.runtime_state_path, session)
    request_path = write_brain_request(
        config.brain_request_path,
        task_id=session.task_id,
        goal=goal,
        prompt=result.transcript,
        transcript_path=str(result.audio_path),
        return_app=return_app,
        current_app=before_app,
    )
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="capture-prompt",
            action_type="capture_prompt",
                target=goal,
            status="ok",
            frontmost_app_before=before_app,
            frontmost_app_after=get_frontmost_app(config.osascript_path),
            parameters={"brain_request_path": str(request_path)},
        ),
    )
    print(json.dumps({"task_id": session.task_id, "transcript": result.transcript, "brain_request_path": str(request_path)}, indent=2))
    return 0


def handle_capture_prompt(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.ffmpeg_path:
        raise SystemExit("ffmpeg is required for push-to-talk capture")

    return_app = args.return_app or config.default_return_app
    return _capture_prompt_once(
        config,
        goal=args.goal,
        return_app=return_app,
        timeout=args.timeout,
        announce_instruction=True,
    )


def handle_listen(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.ffmpeg_path:
        raise SystemExit("ffmpeg is required for push-to-talk capture")

    return_app = args.return_app or config.default_return_app
    print("James listen mode active. Hold keypad 0 to record. Press Ctrl-C to stop.")
    if config.audio_device_name:
        print(f"Audio input: [{config.audio_device_index}] {config.audio_device_name}")
    speak(config.say_path, "James listening mode active.", voice=config.say_voice)

    announce_instruction = True
    try:
        while True:
            exit_code = _capture_prompt_once(
                config,
                goal=args.goal,
                return_app=return_app,
                timeout=args.timeout,
                announce_instruction=announce_instruction,
            )
            announce_instruction = False
            if exit_code == 0:
                speak(config.say_path, "Request saved. Listening for the next prompt.", voice=config.say_voice)
                print("James: request saved. Listening for the next prompt.")
            else:
                speak(config.say_path, "Capture failed. Listening for the next prompt.", voice=config.say_voice)
                print("James: capture failed. Listening for the next prompt.")
            time.sleep(max(args.cooldown, 0.0))
    except KeyboardInterrupt:
        speak(config.say_path, "James listening mode stopped.", voice=config.say_voice)
        print("James listen mode stopped.")
        return 0


def handle_ocr_screen(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    output_path = config.screenshots_dir / f"{session.task_id}_{args.label}.png"
    before_app = get_frontmost_app(config.osascript_path)
    try:
        capture_screen(config.screencapture_path, output_path)
        entries = recognize_text(output_path)
    except Exception as exc:
        error_text = _format_exception(exc)
        append_action(
            config.actions_log_path,
            ActionRecord.create(
                task_id=session.task_id,
                step_id=f"ocr-{args.label}",
                action_type="ocr_screen",
                target=args.label,
                status="error",
                frontmost_app_before=before_app,
                frontmost_app_after=get_frontmost_app(config.osascript_path),
                error=error_text,
            ),
        )
        print(f"ocr failed: {error_text}")
        return 1

    session.evidence.append(str(output_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id=f"ocr-{args.label}",
            action_type="ocr_screen",
            target=args.label,
            status="ok",
            frontmost_app_before=before_app,
            frontmost_app_after=get_frontmost_app(config.osascript_path),
            screenshot_after=str(output_path),
            parameters={"entry_count": len(entries)},
        ),
    )
    print(json.dumps(entries[:20], indent=2))
    return 0


def handle_wait_for_app(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    matched = wait_for_app(config.osascript_path, args.app_name, timeout=args.timeout)
    after_app = get_frontmost_app(config.osascript_path)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id=f"wait-app-{args.app_name}",
            action_type="wait_for_app",
            target=args.app_name,
            status="ok" if matched else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"timeout": args.timeout},
            verification_result=f"matched={matched}",
            error=None if matched else f"Timed out waiting for {args.app_name}",
        ),
    )
    print("matched" if matched else "timed out")
    return 0 if matched else 1


def handle_wait_for_text(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    matched, shot_path = wait_for_text(
        config.screencapture_path,
        config.screenshots_dir,
        session.task_id,
        args.label,
        args.text,
        timeout=args.timeout,
    )
    after_app = get_frontmost_app(config.osascript_path)
    if shot_path:
        session.evidence.append(str(shot_path))
        update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id=f"wait-text-{args.label}",
            action_type="wait_for_text",
            target=args.text,
            status="ok" if matched else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"timeout": args.timeout, "label": args.label},
            screenshot_after=str(shot_path) if shot_path else None,
            verification_result=f"matched={matched}",
            error=None if matched else f"Timed out waiting for text: {args.text}",
        ),
    )
    print(str(shot_path) if shot_path else ("matched" if matched else "timed out"))
    return 0 if matched else 1


def handle_wait_for_text_absent(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    matched, shot_path = wait_for_text_absent(
        config.screencapture_path,
        config.screenshots_dir,
        session.task_id,
        args.label,
        args.text,
        timeout=args.timeout,
    )
    after_app = get_frontmost_app(config.osascript_path)
    if shot_path:
        session.evidence.append(str(shot_path))
        update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id=f"wait-text-absent-{args.label}",
            action_type="wait_for_text_absent",
            target=args.text,
            status="ok" if matched else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"timeout": args.timeout, "label": args.label},
            screenshot_after=str(shot_path) if shot_path else None,
            verification_result=f"absent={matched}",
            error=None if matched else f"Timed out waiting for text to disappear: {args.text}",
        ),
    )
    print(str(shot_path) if shot_path else ("cleared" if matched else "timed out"))
    return 0 if matched else 1


def handle_activate_app(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    if args.push_current:
        push_focus(session, before_app)

    success = activate_app(config.osascript_path, args.app_name)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="activate-app",
            action_type="activate_app",
            target=args.app_name,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"push_current": args.push_current},
            error=None if success else f"Could not activate {args.app_name}",
        ),
    )
    print(after_app or args.app_name)
    return 0 if success else 1


def handle_return_to_editor() -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    target_app = pop_focus(session) or session.return_app
    success = activate_app(config.osascript_path, target_app)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(
        f"Returned to editor target {target_app}." if success else f"Failed to return to editor target {target_app}."
    )
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="return-to-editor",
            action_type="return_to_editor",
            target=target_app,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            error=None if success else f"Could not activate {target_app}",
        ),
    )
    print(after_app or target_app)
    return 0 if success else 1


def handle_launch_godot(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    if args.push_current:
        push_focus(session, before_app)

    project_path = Path(args.project)
    success = launch_godot_project(config.godot_app_path, project_path)
    if success:
        activate_app(config.osascript_path, "Godot")
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    if success:
        session.notes.append(f"Launched Godot project at {project_path}.")
    else:
        session.notes.append(f"Failed to launch Godot project at {project_path}.")
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="launch-godot",
            action_type="launch_godot",
            target=str(project_path),
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"push_current": args.push_current},
            error=None if success else f"Could not launch Godot project at {project_path}",
        ),
    )
    print(after_app or str(project_path))
    return 0 if success else 1


def handle_wait_for_godot_editor(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    matched, shot_path, detail = wait_for_godot_editor_ready(
        config.screencapture_path,
        config.screenshots_dir,
        session.task_id,
        timeout=args.timeout,
    )
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(detail)
    if shot_path:
        session.evidence.append(str(shot_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="wait-for-godot-editor",
            action_type="wait_for_godot_editor",
            target="Godot editor",
            status="ok" if matched else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            parameters={"timeout": args.timeout},
            screenshot_after=str(shot_path) if shot_path else None,
            verification_result=detail,
            error=None if matched else detail,
        ),
    )
    print(detail)
    return 0 if matched else 1


def handle_godot_switch_workspace(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for Godot workspace switching")
    before_app = get_frontmost_app(config.osascript_path)
    output_path = config.screenshots_dir / f"{session.task_id}_godot_workspace_{args.workspace}.png"
    try:
        success, shot_path, detail = switch_godot_workspace(
            config.cliclick_path,
            config.screencapture_path,
            config.osascript_path,
            output_path,
            args.workspace,
        )
    except Exception as exc:
        success, shot_path, detail = False, output_path, _format_exception(exc)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(detail)
    session.evidence.append(str(shot_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-switch-workspace",
            action_type="godot_switch_workspace",
            target=args.workspace,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            screenshot_after=str(shot_path),
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    print(detail)
    return 0 if success else 1


def handle_godot_focus_panel(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for Godot panel focus")
    before_app = get_frontmost_app(config.osascript_path)
    output_path = config.screenshots_dir / f"{session.task_id}_godot_panel_{args.panel}.png"
    try:
        success, shot_path, detail = focus_godot_panel(
            config.cliclick_path,
            config.screencapture_path,
            config.osascript_path,
            output_path,
            args.panel,
        )
    except Exception as exc:
        success, shot_path, detail = False, output_path, _format_exception(exc)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(detail)
    session.evidence.append(str(shot_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-focus-panel",
            action_type="godot_focus_panel",
            target=args.panel,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            screenshot_after=str(shot_path),
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    print(detail)
    return 0 if success else 1


def handle_godot_open_scene(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for Godot scene opening")
    before_app = get_frontmost_app(config.osascript_path)
    output_path = config.screenshots_dir / f"{session.task_id}_godot_scene_{Path(args.scene).stem}.png"
    try:
        success, shot_path, detail = open_godot_scene(
            config.cliclick_path,
            config.screencapture_path,
            config.osascript_path,
            output_path,
            args.scene,
            use_quick_open=not args.no_quick_open,
        )
    except Exception as exc:
        success, shot_path, detail = False, output_path, _format_exception(exc)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(detail)
    session.evidence.append(str(shot_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-open-scene",
            action_type="godot_open_scene",
            target=args.scene,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            screenshot_after=str(shot_path),
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    if success:
        time.sleep(0.5)
    print(detail)
    return 0 if success else 1


def handle_godot_run_project() -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    success = run_godot_project(config.osascript_path)
    after_app = get_frontmost_app(config.osascript_path)
    detail = "sent Godot Run Project shortcut (F5)" if success else "failed to send Godot Run Project shortcut (F5)"
    session.active_app = after_app
    session.notes.append(detail)
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-run-project",
            action_type="godot_run_project",
            target="F5",
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    print(detail)
    return 0 if success else 1


def handle_godot_stop_project() -> int:
    config = load_config()
    session = _require_current_task(config)
    before_app = get_frontmost_app(config.osascript_path)
    success = stop_godot_project(config.osascript_path)
    after_app = get_frontmost_app(config.osascript_path)
    detail = "sent Godot Stop shortcut (F8)" if success else "failed to send Godot Stop shortcut (F8)"
    session.active_app = after_app
    session.notes.append(detail)
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-stop-project",
            action_type="godot_stop_project",
            target="F8",
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    print(detail)
    return 0 if success else 1


def handle_godot_capture_output(args: argparse.Namespace) -> int:
    config = load_config()
    session = _require_current_task(config)
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for Godot output capture")
    before_app = get_frontmost_app(config.osascript_path)
    focus_shot = config.screenshots_dir / f"{session.task_id}_{args.label}_focus.png"
    capture_shot = config.screenshots_dir / f"{session.task_id}_{args.label}.png"
    try:
        success, shot_path, detail = capture_godot_panel(
            config.cliclick_path,
            config.screencapture_path,
            config.osascript_path,
            focus_shot,
            capture_shot,
            "output",
        )
    except Exception as exc:
        success, shot_path, detail = False, focus_shot, _format_exception(exc)
    after_app = get_frontmost_app(config.osascript_path)
    session.active_app = after_app
    session.notes.append(detail)
    session.evidence.append(str(shot_path))
    update_current_task(config.runtime_state_path, session)
    append_action(
        config.actions_log_path,
        ActionRecord.create(
            task_id=session.task_id,
            step_id="godot-capture-output",
            action_type="godot_capture_output",
            target=args.label,
            status="ok" if success else "error",
            frontmost_app_before=before_app,
            frontmost_app_after=after_app,
            screenshot_after=str(shot_path),
            verification_result=detail,
            error=None if success else detail,
        ),
    )
    print(detail)
    return 0 if success else 1


def _execute_step(step, config) -> int:
    if step.action == "note":
        note_args = argparse.Namespace(text=step.payload["text"])
        return handle_note(note_args)
    if step.action == "activate_app":
        activate_args = argparse.Namespace(
            app_name=step.payload["app_name"],
            push_current=step.payload.get("push_current", False),
        )
        return handle_activate_app(activate_args)
    if step.action == "launch_godot":
        godot_args = argparse.Namespace(
            project=step.payload.get(
                "project",
                "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/infil-traitor/project.godot",
            ),
            push_current=step.payload.get("push_current", False),
        )
        return handle_launch_godot(godot_args)
    if step.action == "wait_for_godot_editor":
        wait_godot_args = argparse.Namespace(timeout=float(step.payload.get("timeout", 45.0)))
        return handle_wait_for_godot_editor(wait_godot_args)
    if step.action == "godot_switch_workspace":
        workspace_args = argparse.Namespace(workspace=step.payload["workspace"])
        return handle_godot_switch_workspace(workspace_args)
    if step.action == "godot_focus_panel":
        panel_args = argparse.Namespace(panel=step.payload["panel"])
        return handle_godot_focus_panel(panel_args)
    if step.action == "godot_open_scene":
        open_scene_args = argparse.Namespace(
            scene=step.payload["scene"],
            no_quick_open=bool(step.payload.get("no_quick_open", False)),
        )
        return handle_godot_open_scene(open_scene_args)
    if step.action == "godot_run_project":
        return handle_godot_run_project()
    if step.action == "godot_stop_project":
        return handle_godot_stop_project()
    if step.action == "godot_capture_output":
        capture_output_args = argparse.Namespace(label=step.payload.get("label", "godot_output"))
        return handle_godot_capture_output(capture_output_args)
    if step.action == "capture_screen":
        capture_args = argparse.Namespace(label=step.payload["label"])
        return handle_capture_screen(capture_args)
    if step.action == "wait_for_app":
        wait_args = argparse.Namespace(
            app_name=step.payload["app_name"],
            timeout=float(step.payload.get("timeout", 15.0)),
        )
        return handle_wait_for_app(wait_args)
    if step.action == "wait_for_text":
        wait_text_args = argparse.Namespace(
            label=step.payload["label"],
            text=step.payload["text"],
            timeout=float(step.payload.get("timeout", 15.0)),
        )
        return handle_wait_for_text(wait_text_args)
    if step.action == "wait_for_text_absent":
        wait_text_absent_args = argparse.Namespace(
            label=step.payload["label"],
            text=step.payload["text"],
            timeout=float(step.payload.get("timeout", 15.0)),
        )
        return handle_wait_for_text_absent(wait_text_absent_args)
    if step.action == "return_to_editor":
        return handle_return_to_editor()
    if step.action == "finish_task":
        finish_args = argparse.Namespace(
            status=step.payload.get("status", "completed"),
            note=step.payload.get("note"),
        )
        return handle_finish_task(finish_args)
    if step.action == "click":
        if not config.cliclick_path:
            print("JAMES: cliclick not found — cannot click")
            return 1
        success = click_at(config.cliclick_path, int(step.payload["x"]), int(step.payload["y"]))
        return 0 if success else 1
    if step.action == "double_click":
        if not config.cliclick_path:
            print("JAMES: cliclick not found — cannot double-click")
            return 1
        success = double_click_at(config.cliclick_path, int(step.payload["x"]), int(step.payload["y"]))
        return 0 if success else 1
    if step.action == "type_text":
        success = type_text(config.osascript_path, str(step.payload["text"]))
        return 0 if success else 1
    if step.action == "key_combo":
        success = key_combo(
            config.osascript_path,
            str(step.payload["key"]),
            list(step.payload.get("modifiers", [])),
        )
        return 0 if success else 1
    if step.action == "drag":
        if not config.cliclick_path:
            print("JAMES: cliclick not found — cannot drag")
            return 1
        success = drag_from_to(
            config.cliclick_path,
            int(step.payload["from_x"]),
            int(step.payload["from_y"]),
            int(step.payload["to_x"]),
            int(step.payload["to_y"]),
        )
        return 0 if success else 1
    if step.action == "click_text":
        if not config.cliclick_path:
            print("JAMES: cliclick not found — cannot click")
            return 1
        session = get_current_task(config.runtime_state_path)
        label = step.payload.get("label", "click_text")
        task_id = session.task_id if session else "unknown"
        output_path = config.screenshots_dir / f"{task_id}_{label}.png"
        try:
            capture_screen(config.screencapture_path, output_path)
            sw, sh = get_screen_size(config.osascript_path)
            coords = find_text_center_coords(output_path, str(step.payload["text"]), sw, sh)
        except Exception as exc:
            print(f"JAMES: click_text capture/OCR failed: {exc}")
            return 1
        if coords is None:
            print(f"JAMES: text '{step.payload['text']}' not found on screen")
            return 1
        success = click_at(config.cliclick_path, coords[0], coords[1])
        return 0 if success else 1
    print(f"JAMES: unknown step action '{step.action}' — skipping step {step.id}")
    return 1


CONFIDENCE_THRESHOLD = 0.75


def _voice_or_text_answer(
    config,
    *,
    question: str,
    audio_path,
    timeout: float = 30.0,
) -> str:
    """Ask a question via voice. Falls back to terminal input if voice capture fails."""
    if config.ffmpeg_path:
        try:
            return capture_voice_answer(
                say_path=config.say_path,
                question=question,
                ffmpeg_path=config.ffmpeg_path,
                audio_device_index=config.audio_device_index,
                trigger_vks=config.push_to_talk_key_vks,
                output_path=audio_path,
                timeout=timeout,
                voice=config.say_voice,
            )
        except Exception:
            pass
    # Voice capture unavailable or failed — fall back to terminal.
        speak(config.say_path, "Voice capture unavailable. Please type your answer.", voice=config.say_voice)
    try:
        return input(f"  {question}\n  > ").strip()
    except EOFError:
        return ""


def handle_execute_plan() -> int:
    config = load_config()
    if not config.brain_response_path.exists():
        raise SystemExit("No brain_response.json plan found.")

    plan = load_plan(config.brain_response_path)
    session = get_current_task(config.runtime_state_path)
    if not session or session.task_id != plan.task_id:
        session = restore_task(config.runtime_state_path, plan.task_id, plan.goal, plan.return_target)
        session.active_app = get_frontmost_app(config.osascript_path)
        update_current_task(config.runtime_state_path, session)

    # Conversational: announce the task.
    speak(config.say_path, f"Starting: {plan.goal}", voice=config.say_voice)

    # --- Gate 1: clarification required ---
    # James stops entirely and asks each question via voice.
    # Answers are recorded back into brain_request.json so the user can resubmit.
    if plan.clarification_needed:
        speak(config.say_path, "I need to ask you a few things before I can proceed.", voice=config.say_voice)
        print("\nJAMES: CLARIFICATION NEEDED — hold keypad 0 to answer each question.")
        print("-" * 60)
        answers = []
        for i, question in enumerate(plan.clarification_questions, start=1):
            print(f"  Q{i}: {question}")
            audio_path = config.audio_dir / f"{plan.task_id}_clarify_{i}.wav"
            answer = _voice_or_text_answer(
                config,
                question=question,
                audio_path=audio_path,
            )
            print(f"  A{i}: {answer}")
            answers.append({"question": question, "answer": answer})
            session.notes.append(f"Clarification Q{i}: {question} | A: {answer}")

        update_current_task(config.runtime_state_path, session)

        # Embed answers into the brain request so the next resubmit includes them.
        if config.brain_request_path.exists():
            import json as _json
            existing = _json.loads(config.brain_request_path.read_text())
            existing["clarification_answers"] = answers
            config.brain_request_path.write_text(_json.dumps(existing, indent=2, ensure_ascii=True))

        speak(config.say_path, "Got your answers. Please resubmit the brain request for an updated plan.", voice=config.say_voice)
        print("\nAnswers saved to brain_request.json. Resubmit to the LLM for an updated plan.")
        return 1

    # --- Gate 2: better alternative ---
    if plan.better_alternative:
        speak(config.say_path, f"Better way: {plan.better_alternative}", voice=config.say_voice)
        print(f"\nJAMES: BETTER WAY — {plan.better_alternative}")

    # --- Gate 3: warnings ---
    # Speak a brief alert; full detail goes to the terminal.
    if plan.warnings:
        if len(plan.warnings) == 1:
            speak(config.say_path, f"Warning: {plan.warnings[0]}", voice=config.say_voice)
        else:
            speak(config.say_path, f"I have {len(plan.warnings)} warnings. Check the terminal.", voice=config.say_voice)
        print("\nJAMES: WARNINGS:")
        for w in plan.warnings:
            print(f"  — {w}")

    # --- Gate 4: low confidence — confirm via voice ---
    if plan.confidence < CONFIDENCE_THRESHOLD:
        confidence_pct = f"{plan.confidence:.0%}"
        question = f"Confidence is {confidence_pct}. I'm not sure this is right. Should I proceed?"
        print(f"\nJAMES: LOW CONFIDENCE ({confidence_pct}). Not sure this plan is right.")
        audio_path = config.audio_dir / f"{plan.task_id}_confirm.wav"
        answer = _voice_or_text_answer(
            config,
            question=question,
            audio_path=audio_path,
            timeout=20.0,
        )
        print(f"  You said: {answer}")
        if "yes" not in answer.lower():
            speak(config.say_path, "Aborted.", voice=config.say_voice)
            print("Aborted.")
            return 1

    # --- Execute steps ---
    for step in plan.steps:
        exit_code = _execute_step(step, config)
        if exit_code != 0:
            speak(config.say_path, "A step failed. Check the terminal.", voice=config.say_voice)
            print(f"\nJAMES: Plan failed at step {step.id} ({step.action}).")
            session = get_current_task(config.runtime_state_path)
            if session:
                print_terminal_outcome(plan, session, config.actions_log_path)
            return exit_code

    session = get_current_task(config.runtime_state_path)
    if session:
        status_word = "Done" if session.status in ("completed", "created") else session.status
        speak(config.say_path, f"{status_word}. {plan.goal}", voice=config.say_voice)
        print_terminal_outcome(plan, session, config.actions_log_path)
    return 0


def handle_click(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for mouse control (brew install cliclick)")
    success = click_at(config.cliclick_path, args.x, args.y)
    print(f"clicked ({args.x},{args.y})" if success else f"click failed at ({args.x},{args.y})")
    return 0 if success else 1


def handle_double_click(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for mouse control (brew install cliclick)")
    success = double_click_at(config.cliclick_path, args.x, args.y)
    print(f"double-clicked ({args.x},{args.y})" if success else f"double-click failed at ({args.x},{args.y})")
    return 0 if success else 1


def handle_type_text(args: argparse.Namespace) -> int:
    config = load_config()
    success = type_text(config.osascript_path, args.text)
    print("typed" if success else "type failed")
    return 0 if success else 1


def handle_key_combo(args: argparse.Namespace) -> int:
    config = load_config()
    modifiers = args.modifier or []
    success = key_combo(config.osascript_path, args.key, modifiers)
    combo_label = "+".join(modifiers + [args.key])
    print(f"sent {combo_label}" if success else f"key combo failed: {combo_label}")
    return 0 if success else 1


def handle_drag(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for drag operations (brew install cliclick)")
    success = drag_from_to(config.cliclick_path, args.from_x, args.from_y, args.to_x, args.to_y)
    print(
        f"dragged ({args.from_x},{args.from_y}) → ({args.to_x},{args.to_y})" if success
        else f"drag failed ({args.from_x},{args.from_y}) → ({args.to_x},{args.to_y})"
    )
    return 0 if success else 1


def handle_click_text(args: argparse.Namespace) -> int:
    config = load_config()
    if not config.cliclick_path:
        raise SystemExit("cliclick is required for mouse control (brew install cliclick)")
    session = _require_current_task(config)
    output_path = config.screenshots_dir / f"{session.task_id}_{args.label}.png"
    try:
        capture_screen(config.screencapture_path, output_path)
        sw, sh = get_screen_size(config.osascript_path)
        coords = find_text_center_coords(output_path, args.text, sw, sh)
    except Exception as exc:
        print(f"click-text failed: {exc}")
        return 1
    if coords is None:
        print(f"text not found on screen: '{args.text}'")
        return 1
    x, y = coords
    success = click_at(config.cliclick_path, x, y)
    session.notes.append(f"Clicked text '{args.text}' at ({x},{y}).")
    session.evidence.append(str(output_path))
    update_current_task(config.runtime_state_path, session)
    print(f"clicked '{args.text}' at ({x},{y})" if success else f"click failed at ({x},{y})")
    return 0 if success else 1


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "preflight":
        return handle_preflight()
    if args.command == "audio-device":
        return handle_audio_device(args)
    if args.command == "start-task":
        return handle_start_task(args)
    if args.command == "note":
        return handle_note(args)
    if args.command == "capture-screen":
        return handle_capture_screen(args)
    if args.command == "push-focus":
        return handle_push_focus()
    if args.command == "pop-focus":
        return handle_pop_focus()
    if args.command == "finish-task":
        return handle_finish_task(args)
    if args.command == "status":
        return handle_status()
    if args.command == "monitor":
        return handle_monitor(args)
    if args.command == "execute-plan":
        return handle_execute_plan()
    if args.command == "generate-plan":
        return handle_generate_plan()
    if args.command == "write-sample-plan":
        return handle_write_sample_plan(args)
    if args.command == "ocr-screen":
        return handle_ocr_screen(args)
    if args.command == "wait-for-app":
        return handle_wait_for_app(args)
    if args.command == "wait-for-text":
        return handle_wait_for_text(args)
    if args.command == "wait-for-text-absent":
        return handle_wait_for_text_absent(args)
    if args.command == "activate-app":
        return handle_activate_app(args)
    if args.command == "return-to-editor":
        return handle_return_to_editor()
    if args.command == "launch-godot":
        return handle_launch_godot(args)
    if args.command == "wait-for-godot-editor":
        return handle_wait_for_godot_editor(args)
    if args.command == "godot-switch-workspace":
        return handle_godot_switch_workspace(args)
    if args.command == "godot-focus-panel":
        return handle_godot_focus_panel(args)
    if args.command == "godot-open-scene":
        return handle_godot_open_scene(args)
    if args.command == "godot-run-project":
        return handle_godot_run_project()
    if args.command == "godot-stop-project":
        return handle_godot_stop_project()
    if args.command == "godot-capture-output":
        return handle_godot_capture_output(args)
    if args.command == "capture-prompt":
        return handle_capture_prompt(args)
    if args.command == "listen":
        return handle_listen(args)
    if args.command == "click":
        return handle_click(args)
    if args.command == "double-click":
        return handle_double_click(args)
    if args.command == "type-text":
        return handle_type_text(args)
    if args.command == "key-combo":
        return handle_key_combo(args)
    if args.command == "drag":
        return handle_drag(args)
    if args.command == "click-text":
        return handle_click_text(args)

    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
