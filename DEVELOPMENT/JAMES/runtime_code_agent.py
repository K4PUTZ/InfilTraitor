from __future__ import annotations

from pathlib import Path

from runtime_models import utc_now_iso
from runtime_storage import write_json


def write_code_agent_request(
    output_path: Path,
    *,
    task_id: str,
    goal: str,
    summary: str,
    instructions: str,
    relevant_files: list[str] | None,
    acceptance_criteria: list[str] | None,
    context_notes: list[str] | None,
    return_app: str,
    source_step_id: str,
) -> Path:
    payload = {
        "task_id": task_id,
        "goal": goal,
        "status": "pending_code_agent",
        "created_at": utc_now_iso(),
        "source_step_id": source_step_id,
        "summary": summary,
        "instructions": instructions,
        "relevant_files": relevant_files or [],
        "acceptance_criteria": acceptance_criteria or [],
        "context_notes": context_notes or [],
        "return_app": return_app,
        "next_action": (
            "Hand this request to the coding agent for direct file edits. "
            "After the edits are complete, generate a fresh James plan for validation or follow-up GUI work."
        ),
    }
    write_json(output_path, payload)
    return output_path


def write_code_agent_result(
    output_path: Path,
    *,
    task_id: str,
    status: str,
    summary: str,
    changed_files: list[str] | None,
    follow_up_notes: list[str] | None,
) -> Path:
    payload = {
        "task_id": task_id,
        "status": status,
        "completed_at": utc_now_iso(),
        "summary": summary,
        "changed_files": changed_files or [],
        "follow_up_notes": follow_up_notes or [],
    }
    write_json(output_path, payload)
    return output_path
