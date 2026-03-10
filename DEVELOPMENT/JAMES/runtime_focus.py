from __future__ import annotations

from runtime_models import TaskSession, utc_now_iso


def push_focus(session: TaskSession, app_name: str | None) -> TaskSession:
    if app_name:
        session.focus_stack.append(app_name)
        session.updated_at = utc_now_iso()
    return session


def pop_focus(session: TaskSession) -> str | None:
    if not session.focus_stack:
        return None
    app_name = session.focus_stack.pop()
    session.updated_at = utc_now_iso()
    return app_name
