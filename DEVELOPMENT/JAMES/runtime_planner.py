from __future__ import annotations

import json
from pathlib import Path
import re


DEFAULT_PROJECT_PATH = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/infil-traitor/project.godot"


def _normalize_prompt(prompt: str) -> str:
    return " ".join(prompt.lower().split())


def _build_conversational_reply(prompt: str) -> str:
    normalized = _normalize_prompt(prompt)
    if "can you hear my voice" in normalized or "can you hear me" in normalized:
        return "Yes. I can hear you clearly."
    if "how are you" in normalized:
        return "I am here and working."
    if any(token in normalized for token in ("hello", "hi james", "hey james")):
        return "Hello. I heard you."
    return f"I heard: {prompt.strip()}"


def _extract_vscode_task_label(raw_prompt: str) -> str:
    quoted = re.search(r"run\s+task\s+[\"']([^\"']+)[\"']", raw_prompt, flags=re.IGNORECASE)
    if quoted:
        candidate = quoted.group(1).strip()
        if candidate:
            return candidate

    plain = re.search(r"run\s+task\s+([A-Za-z0-9_:\- .]+)", raw_prompt, flags=re.IGNORECASE)
    if plain:
        candidate = plain.group(1).strip()
        # Trim common continuation words after the task label.
        for separator in (" and ", " then ", ",", "."):
            if separator in candidate.lower():
                candidate = candidate.split(separator, 1)[0].strip()
        if candidate:
            return candidate

    return "pytest small selection"


def _build_post_code_edit_validation_plan(request: dict, response_path: Path) -> Path:
    task_id = request["task_id"]
    goal = request.get("goal", "James generated task")
    return_target = request.get("return_app", "Visual Studio Code")
    context = request.get("workflow_context") or {}
    handoff = context.get("code_agent_request") or {}
    result = context.get("code_agent_result") or {}
    changed_files = [str(item) for item in (result.get("changed_files") or [])]
    follow_up_notes = [str(item) for item in (result.get("follow_up_notes") or [])]
    summary = str(result.get("summary") or handoff.get("summary") or "Direct code edits completed.")

    steps: list[dict[str, object]] = [
        {
            "id": "s1",
            "action": "note",
            "text": f"Post-code-edit validation requested: {summary}",
        },
        {
            "id": "s2",
            "action": "launch_godot",
            "project": DEFAULT_PROJECT_PATH,
            "push_current": True,
        },
        {
            "id": "s3",
            "action": "wait_for_godot_editor",
            "timeout": 45,
        },
        {
            "id": "s4",
            "action": "capture_screen",
            "label": "post_code_edit_validation",
        },
        {
            "id": "s5",
            "action": "godot_capture_output",
            "label": "post_code_edit_output",
        },
        {
            "id": "s6",
            "action": "return_to_editor",
        },
        {
            "id": "s7",
            "action": "finish_task",
            "status": "completed",
            "note": "Post-code-edit validation plan executed.",
        },
    ]

    outcome_tips = [
        "Review the validation screenshot and captured Godot output for regressions after the direct code edit.",
    ]
    if changed_files:
        outcome_tips.append("Changed files recorded for this phase: " + ", ".join(changed_files))
    if follow_up_notes:
        outcome_tips.append("Requested validation focus: " + " | ".join(follow_up_notes))

    plan = {
        "task_id": task_id,
        "goal": goal,
        "confidence": 0.8,
        "better_alternative": None,
        "warnings": [
            "Heuristic post-edit validation plan — prefer the external brain when the follow-up needs scene-specific or UI-specific checks."
        ],
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": outcome_tips,
        "success_conditions": [
            "Godot is launched and stable enough to inspect.",
            "James captures validation evidence after the direct code edits.",
            "James returns to the requested editor target.",
        ],
        "return_target": return_target,
        "safety_level": "normal",
        "steps": steps,
    }

    response_path.write_text(json.dumps(plan, indent=2, ensure_ascii=True))
    return response_path


def generate_plan_from_request(request_path: Path, response_path: Path) -> Path:
    request = json.loads(request_path.read_text())
    workflow_stage = request.get("workflow_stage")
    if workflow_stage == "post_code_edit_validation":
        return _build_post_code_edit_validation_plan(request, response_path)

    prompt = _normalize_prompt(request.get("prompt", ""))
    task_id = request["task_id"]
    goal = request.get("goal", "James generated task")
    return_target = request.get("return_app", "Visual Studio Code")

    steps: list[dict[str, object]] = [
        {
            "id": "s1",
            "action": "note",
            "text": f"Generated plan from prompt: {request.get('prompt', '')}",
        }
    ]

    wants_godot = any(token in prompt for token in ("godot", "project", "scene"))
    wants_open_any = any(token in prompt for token in ("open", "launch", "start"))
    wants_open_godot = wants_godot and wants_open_any
    wants_inspect = any(token in prompt for token in ("inspect", "check", "look", "see", "verify"))
    wants_screen = any(token in prompt for token in ("screen", "screenshot", "capture"))
    wants_return = any(token in prompt for token in ("return", "come back", "back to code", "back to editor", "vscode"))
    wants_output_signal = any(token in prompt for token in ("errors", "console", "log")) or (
        "output" in prompt and "output panel" not in prompt
    )
    wants_output = wants_godot and wants_output_signal
    wants_run = any(token in prompt for token in ("run project", "play", "test run", "run game"))
    wants_scene_open = any(token in prompt for token in ("open scene", ".tscn", "scene "))
    wants_vscode_terminal = any(token in prompt for token in ("vscode terminal", "vs code terminal", "focus terminal", "open terminal"))
    wants_vscode_problems = any(token in prompt for token in ("problems panel", "open problems", "focus problems"))
    wants_vscode_output = any(token in prompt for token in ("output panel", "focus output panel", "open output panel"))
    wants_vscode_explorer = any(token in prompt for token in ("explorer panel", "focus explorer", "open explorer"))
    wants_run_task = "run task" in prompt

    workspace = None
    for candidate in ("2d", "3d", "script", "assetlib"):
        if candidate in prompt:
            workspace = candidate
            break

    scene_name = None
    for token in request.get("prompt", "").split():
        if token.endswith(".tscn"):
            scene_name = token.strip('"\'.,')
            break

    step_number = 2
    if wants_godot or wants_open_godot:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "launch_godot",
                "project": DEFAULT_PROJECT_PATH,
                "push_current": True,
            }
        )
        step_number += 1
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "wait_for_godot_editor",
                "timeout": 45,
            }
        )
        step_number += 1

    if workspace:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "godot_switch_workspace",
                "workspace": workspace,
            }
        )
        step_number += 1

    if wants_scene_open and scene_name:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "godot_open_scene",
                "scene": scene_name,
            }
        )
        step_number += 1

    if wants_run:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "godot_run_project",
            }
        )
        step_number += 1

    if wants_inspect or wants_screen:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "capture_screen",
                "label": "inspection",
            }
        )
        step_number += 1

    if wants_output:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "godot_capture_output",
                "label": "godot_output",
            }
        )
        step_number += 1

    if wants_vscode_terminal:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "vscode_focus_terminal",
                "timeout": 8,
            }
        )
        step_number += 1

    if wants_vscode_explorer:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "vscode_focus_panel",
                "panel": "explorer",
                "timeout": 8,
            }
        )
        step_number += 1

    if wants_vscode_problems:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "vscode_focus_panel",
                "panel": "problems",
                "timeout": 8,
            }
        )
        step_number += 1

    if wants_vscode_output:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "vscode_focus_panel",
                "panel": "output",
                "timeout": 8,
            }
        )
        step_number += 1

    if wants_run_task:
        task_label = _extract_vscode_task_label(request.get("prompt", ""))
        task_payload: dict[str, object] = {
            "id": f"s{step_number}",
            "action": "vscode_run_task",
            "label": task_label,
        }
        if "pytest" in task_label.lower():
            task_payload["expect_text"] = "passed"
            task_payload["timeout"] = 25
        steps.append(
            task_payload
        )
        step_number += 1

    if wants_return or wants_godot or wants_open_godot:
        steps.append({"id": f"s{step_number}", "action": "return_to_editor"})
        step_number += 1

    passive_only = all(step["action"] in {"note", "finish_task"} for step in steps)
    if passive_only:
        steps.append(
            {
                "id": f"s{step_number}",
                "action": "speak_text",
                "text": _build_conversational_reply(request.get("prompt", "")),
            }
        )
        step_number += 1

    steps.append(
        {
            "id": f"s{step_number}",
            "action": "finish_task",
            "status": "completed",
            "note": "Generated plan executed.",
        }
    )

    passive_only = all(step["action"] in {"note", "speak_text", "finish_task"} for step in steps)
    confidence = 0.95 if passive_only else 0.6
    warnings = [] if passive_only else ["Heuristic plan — verify with the real brain (LLM) before relying on it in production."]
    outcome_tips = [] if passive_only else ["Check the captured screenshots in logs/screenshots/ after execution."]

    plan = {
        "task_id": task_id,
        "goal": goal,
        "confidence": confidence,
        "better_alternative": None,
        "warnings": warnings,
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": outcome_tips,
        "success_conditions": [
            "James executes the generated plan without step failures.",
            "James returns to the requested editor target when appropriate.",
        ],
        "return_target": return_target,
        "safety_level": "normal",
        "steps": steps,
    }

    response_path.write_text(json.dumps(plan, indent=2, ensure_ascii=True))
    return response_path
