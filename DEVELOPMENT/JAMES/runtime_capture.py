from __future__ import annotations

from pathlib import Path
import subprocess


def capture_screen(screencapture_path: str, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([screencapture_path, "-x", str(output_path)], check=True)
    return output_path
