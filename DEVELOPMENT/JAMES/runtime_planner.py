from __future__ import annotations

import json
from pathlib import Path


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


def generate_plan_from_request(request_path: Path, response_path: Path) -> Path:
    request = json.loads(request_path.read_text())
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
    wants_open = any(token in prompt for token in ("open", "launch", "start"))
    wants_inspect = any(token in prompt for token in ("inspect", "check", "look", "see", "verify"))
    wants_screen = any(token in prompt for token in ("screen", "screenshot", "capture"))
    wants_return = any(token in prompt for token in ("return", "come back", "back to code", "back to editor", "vscode"))
    wants_output = any(token in prompt for token in ("output", "errors", "console", "log"))
    wants_run = any(token in prompt for token in ("run project", "play", "test run", "run game"))
    wants_scene_open = any(token in prompt for token in ("open scene", ".tscn", "scene "))

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
    if wants_godot or wants_open:
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

    if wants_return or wants_godot or wants_open:
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
