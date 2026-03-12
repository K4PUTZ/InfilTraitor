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
        "goal": "Open Godot, switch to Script workspace, then prepare a direct code-edit handoff for the coding agent",
        "confidence": 0.95,
        "better_alternative": None,
        "warnings": [],
        "clarification_needed": False,
        "clarification_questions": [],
        "outcome_tips": [
            "After the handoff file is written, give it to the coding agent instead of making James type code through the UI.",
            "After the edit is done, create a fresh James plan to validate the result inside Godot.",
        ],
        "success_conditions": [
            "Godot is launched and the editor is ready",
            "The Script workspace is focused",
            "A code-agent handoff request is written with enough detail for direct file edits",
        ],
        "return_target": "Visual Studio Code",
        "safety_level": "normal",
        "steps": [
            {"id": "s1", "action": "note", "text": "Starting sample execution plan."},
            {"id": "s2", "action": "launch_godot", "push_current": True},
            {"id": "s3", "action": "wait_for_godot_editor", "timeout": 45},
            {"id": "s4", "action": "godot_switch_workspace", "workspace": "script"},
            {
                "id": "s5",
                "action": "delegate_code_edit",
                "summary": "Update the active Godot gameplay script directly in the workspace.",
                "instructions": "Read the relevant script, implement the requested gameplay change directly in code, and keep the change minimal and consistent with the existing style.",
                "relevant_files": [
                    "res://scripts/player.gd"
                ],
                "acceptance_criteria": [
                    "The script contains the requested behavior change.",
                    "The code remains valid GDScript and matches the existing project style."
                ],
                "context_notes": [
                    "Godot has already been opened and the Script workspace is active.",
                    "Use direct file edits through the coding agent, not blind UI typing."
                ],
                "pause_after": True
            }
        ],
    }
    path.write_text(json.dumps(sample, indent=2, ensure_ascii=True))
    return path
