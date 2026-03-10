from __future__ import annotations

import json
from pathlib import Path


DEFAULT_PROJECT_PATH = "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/infil-traitor/project.godot"


def _normalize_prompt(prompt: str) -> str:
    return " ".join(prompt.lower().split())


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
                "action": "wait_for_app",
                "app_name": "Godot",
                "timeout": 15,
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

    if wants_return or wants_godot or wants_open:
        steps.append({"id": f"s{step_number}", "action": "return_to_editor"})
        step_number += 1

    steps.append(
        {
            "id": f"s{step_number}",
            "action": "finish_task",
            "status": "completed",
            "note": "Generated plan executed.",
        }
    )

    plan = {
        "task_id": task_id,
        "goal": goal,
        "confidence": 0.6,
        "better_alternative": None,
        "warnings": ["Heuristic plan — verify with the real brain (LLM) before relying on it in production."],
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": ["Check the captured screenshots in logs/screenshots/ after execution."],
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
