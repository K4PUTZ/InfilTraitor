from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any
import uuid


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class TaskSession:
    task_id: str
    goal: str
    status: str
    created_at: str
    updated_at: str
    return_app: str
    active_app: str | None = None
    notes: list[str] = field(default_factory=list)
    evidence: list[str] = field(default_factory=list)
    focus_stack: list[str] = field(default_factory=list)
    wait_condition: str | None = None

    @classmethod
    def create(cls, goal: str, return_app: str) -> "TaskSession":
        now = utc_now_iso()
        return cls(
            task_id=f"james-{uuid.uuid4().hex[:12]}",
            goal=goal,
            status="created",
            created_at=now,
            updated_at=now,
            return_app=return_app,
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ActionRecord:
    timestamp: str
    task_id: str
    step_id: str
    action_type: str
    target: str | None
    status: str
    frontmost_app_before: str | None = None
    frontmost_app_after: str | None = None
    parameters: dict[str, Any] = field(default_factory=dict)
    screenshot_before: str | None = None
    screenshot_after: str | None = None
    verification_result: str | None = None
    error: str | None = None

    @classmethod
    def create(
        cls,
        task_id: str,
        step_id: str,
        action_type: str,
        target: str | None,
        status: str,
        **kwargs: Any,
    ) -> "ActionRecord":
        return cls(
            timestamp=utc_now_iso(),
            task_id=task_id,
            step_id=step_id,
            action_type=action_type,
            target=target,
            status=status,
            **kwargs,
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
