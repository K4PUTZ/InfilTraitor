from __future__ import annotations

from pathlib import Path

from runtime_storage import write_json

_BRAIN_INSTRUCTIONS = {
    "summary": (
        "You are the planning brain for James, a local macOS execution operator. "
        "Read this request and return a valid James execution plan as a JSON object. "
        "Be blunt and honest. Do not soften warnings or hide concerns."
    ),
    "response_format": (
        "Return ONLY a raw JSON object. No prose. No markdown. No code fences. "
        "The JSON must be parseable by json.loads() with no pre/post processing."
    ),
    "required_fields": [
        "task_id", "goal", "confidence", "steps",
        "success_conditions", "return_target", "safety_level",
    ],
    "field_descriptions": {
        "confidence": (
            "Float 0.0–1.0. How certain are you this plan achieves the goal safely? "
            "Below 0.75 James will pause and ask the user for confirmation before executing. "
            "Be accurate — do not inflate this."
        ),
        "better_alternative": (
            "If a smarter, faster, or safer approach exists for the user's intent, "
            "describe it here in plain language. Be blunt. Do not soften it. "
            "Set to null if the user's approach is already reasonable."
        ),
        "warnings": (
            "List any reasons this request is risky, misguided, likely to fail, or "
            "based on a wrong assumption. Be direct. Empty list if the plan is clean."
        ),
        "clarification_needed": (
            "Set to true if you cannot make a confident plan without more information. "
            "James will stop execution entirely and present your questions to the user."
        ),
        "clarification_questions": (
            "If clarification_needed is true, list specific questions James must ask "
            "before proceeding. Be concrete."
        ),
        "outcome_tips": (
            "After execution, what should the user verify or be aware of? "
            "Practical, specific hints only. Empty list if nothing notable."
        ),
    },
}


def write_brain_request(
    output_path: Path,
    *,
    task_id: str,
    goal: str,
    prompt: str,
    transcript_path: str | None,
    return_app: str,
    current_app: str | None = None,
    clarification_answers: list[dict] | None = None,
) -> Path:
    payload = {
        "task_id": task_id,
        "goal": goal,
        "prompt": prompt,
        "transcript_path": transcript_path,
        "current_app": current_app,
        "return_app": return_app,
        "status": "pending_brain_plan",
        "clarification_answers": clarification_answers or [],
        "instructions_for_brain": _BRAIN_INSTRUCTIONS,
    }
    write_json(output_path, payload)
    return output_path
