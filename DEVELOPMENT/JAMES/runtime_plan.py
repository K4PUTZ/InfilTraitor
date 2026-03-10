from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
import json


@dataclass
class PlanStep:
    id: str
    action: str
    payload: dict[str, Any]


@dataclass
class ExecutionPlan:
    task_id: str
    goal: str
    success_conditions: list[str]
    return_target: str
    safety_level: str
    steps: list[PlanStep]
    # Brain quality & safety fields
    confidence: float = 1.0
    better_alternative: str | None = None
    warnings: list[str] = field(default_factory=list)
    clarification_needed: bool = False
    clarification_questions: list[str] = field(default_factory=list)
    outcome_tips: list[str] = field(default_factory=list)


def load_plan(path: Path) -> ExecutionPlan:
    payload = json.loads(path.read_text())
    steps = [
        PlanStep(id=step["id"], action=step["action"], payload=step)
        for step in payload.get("steps", [])
    ]
    return ExecutionPlan(
        task_id=payload["task_id"],
        goal=payload["goal"],
        success_conditions=payload.get("success_conditions", []),
        return_target=payload.get("return_target", "Visual Studio Code"),
        safety_level=payload.get("safety_level", "normal"),
        steps=steps,
        confidence=float(payload.get("confidence", 1.0)),
        better_alternative=payload.get("better_alternative"),
        warnings=payload.get("warnings", []),
        clarification_needed=bool(payload.get("clarification_needed", False)),
        clarification_questions=payload.get("clarification_questions", []),
        outcome_tips=payload.get("outcome_tips", []),
    )


def write_sample_plan(path: Path, task_id: str) -> Path:
    sample = {
        "task_id": task_id,
        "goal": "Open Godot and return to VS Code",
        "confidence": 0.95,
        "better_alternative": None,
        "warnings": [],
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": [
            "Check the Godot FileSystem panel for any import errors after the editor opens.",
            "If scenes are missing, run Project > Reimport All from the Godot menu.",
        ],
        "success_conditions": [
            "Godot is launched",
            "James returns to the editor",
        ],
        "return_target": "Visual Studio Code",
        "safety_level": "normal",
        "steps": [
            {"id": "s1", "action": "note", "text": "Starting sample execution plan."},
            {"id": "s2", "action": "launch_godot", "push_current": True},
            {"id": "s3", "action": "wait_for_app", "app_name": "Godot", "timeout": 15},
            {"id": "s4", "action": "return_to_editor"},
            {"id": "s5", "action": "finish_task", "status": "completed", "note": "Sample execution plan completed."},
        ],
    }
    path.write_text(json.dumps(sample, indent=2, ensure_ascii=True))
    return path
