from __future__ import annotations

from pathlib import Path
import json

from runtime_models import ActionRecord


def append_action(log_path: Path, record: ActionRecord) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record.to_dict(), ensure_ascii=True) + "\n")
