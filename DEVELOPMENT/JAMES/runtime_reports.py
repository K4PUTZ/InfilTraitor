from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from runtime_models import TaskSession

if TYPE_CHECKING:
    from runtime_plan import ExecutionPlan


def write_session_summary(output_path: Path, session: TaskSession) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# James Session {session.task_id}",
        "",
        f"- Goal: {session.goal}",
        f"- Status: {session.status}",
        f"- Return App: {session.return_app}",
        f"- Created: {session.created_at}",
        f"- Updated: {session.updated_at}",
        "",
        "## Notes",
    ]
    if session.notes:
        lines.extend(f"- {note}" for note in session.notes)
    else:
        lines.append("- No notes recorded.")

    lines.extend(["", "## Evidence"])
    if session.evidence:
        lines.extend(f"- {entry}" for entry in session.evidence)
    else:
        lines.append("- No evidence recorded.")

    output_path.write_text("\n".join(lines) + "\n")
    return output_path


def print_terminal_outcome(plan: "ExecutionPlan", session: TaskSession, actions_log_path: Path | None = None) -> None:
    """Print a blunt, rich outcome summary to stdout after plan execution."""
    divider = "=" * 60
    thin = "-" * 60

    status_label = session.status.upper()
    print(f"\n{divider}")
    print(f"JAMES — {status_label}: {plan.task_id}")
    print(divider)
    print(f"  Goal      : {plan.goal}")
    print(f"  App now   : {session.active_app or 'unknown'}")
    print(f"  Confidence: {plan.confidence:.0%}")

    if plan.better_alternative:
        print(f"\n  BETTER WAY: {plan.better_alternative}")

    if plan.warnings:
        print(f"\n{thin}")
        print("  WARNINGS:")
        for w in plan.warnings:
            print(f"    — {w}")

    if session.notes:
        print(f"\n{thin}")
        print("  What happened:")
        for note in session.notes:
            print(f"    — {note}")

    if session.evidence:
        print(f"\n{thin}")
        print("  Evidence:")
        for entry in session.evidence:
            print(f"    — {entry}")

    if plan.outcome_tips:
        print(f"\n{thin}")
        print("  Check / next:")
        for tip in plan.outcome_tips:
            print(f"    — {tip}")

    if actions_log_path:
        print(f"\n  Log: {actions_log_path}")

    print(divider)
