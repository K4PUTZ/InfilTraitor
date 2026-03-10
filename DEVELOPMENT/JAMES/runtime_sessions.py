from __future__ import annotations

from pathlib import Path

from runtime_models import TaskSession, utc_now_iso
from runtime_storage import read_json, write_json


def load_runtime_state(path: Path) -> dict:
    return read_json(path, {"current_task": None, "task_history": []})


def save_runtime_state(path: Path, state: dict) -> None:
    write_json(path, state)


def start_task(path: Path, goal: str, return_app: str) -> TaskSession:
    state = load_runtime_state(path)
    session = TaskSession.create(goal=goal, return_app=return_app)
    state["current_task"] = session.to_dict()
    state.setdefault("task_history", []).append(
        {
            "task_id": session.task_id,
            "goal": session.goal,
            "created_at": session.created_at,
        }
    )
    save_runtime_state(path, state)
    return session


def restore_task(path: Path, task_id: str, goal: str, return_app: str) -> TaskSession:
    state = load_runtime_state(path)
    current = state.get("current_task")
    if current and current.get("task_id") == task_id:
        session = TaskSession(**current)
    else:
        session = None
        completed = state.setdefault("completed_tasks", [])
        for index, entry in enumerate(completed):
            if entry.get("task_id") == task_id:
                session = TaskSession(**entry)
                completed.pop(index)
                break
        if session is None:
            now = utc_now_iso()
            session = TaskSession(
                task_id=task_id,
                goal=goal,
                status="created",
                created_at=now,
                updated_at=now,
                return_app=return_app,
            )

    session.goal = goal
    session.return_app = return_app
    session.status = "created"
    session.updated_at = utc_now_iso()
    state["current_task"] = session.to_dict()
    history = state.setdefault("task_history", [])
    if not any(entry.get("task_id") == task_id for entry in history):
        history.append(
            {
                "task_id": session.task_id,
                "goal": session.goal,
                "created_at": session.created_at,
            }
        )
    save_runtime_state(path, state)
    return session


def get_current_task(path: Path) -> TaskSession | None:
    state = load_runtime_state(path)
    current = state.get("current_task")
    if not current:
        return None
    return TaskSession(**current)


def update_current_task(path: Path, session: TaskSession) -> None:
    state = load_runtime_state(path)
    session.updated_at = utc_now_iso()
    state["current_task"] = session.to_dict()
    save_runtime_state(path, state)


def finish_task(path: Path, status: str, note: str | None = None) -> TaskSession | None:
    session = get_current_task(path)
    if not session:
        return None
    session.status = status
    session.updated_at = utc_now_iso()
    if note:
        session.notes.append(note)

    state = load_runtime_state(path)
    state["current_task"] = None
    state.setdefault("completed_tasks", []).append(session.to_dict())
    save_runtime_state(path, state)
    return session
