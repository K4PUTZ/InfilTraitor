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
        "goal": "Open Godot, switch to Script workspace, capture the Output panel, and return to VS Code",
        "confidence": 0.95,
        "better_alternative": None,
        "warnings": [],
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": [
            "Check the captured Output panel screenshot for editor or import errors.",
            "If Godot is still importing assets, wait for the import state to clear before issuing more UI actions.",
        ],
        "success_conditions": [
            "Godot is launched and the editor is ready",
            "The Script workspace is focused",
            "The Output panel is captured as evidence",
            "James returns to the editor target",
        ],
        "return_target": "Visual Studio Code",
        "safety_level": "normal",
        "steps": [
            {"id": "s1", "action": "note", "text": "Starting sample execution plan."},
            {"id": "s2", "action": "launch_godot", "push_current": True},
            {"id": "s3", "action": "wait_for_godot_editor", "timeout": 45},
            {"id": "s4", "action": "godot_switch_workspace", "workspace": "script"},
            {"id": "s5", "action": "godot_capture_output", "label": "sample_output"},
            {"id": "s6", "action": "return_to_editor"},
            {"id": "s7", "action": "finish_task", "status": "completed", "note": "Sample execution plan completed."},
        ],
    }
    path.write_text(json.dumps(sample, indent=2, ensure_ascii=True))
    return path
