from __future__ import annotations

import subprocess


def speak(say_path: str, text: str, voice: str | None = None) -> bool:
    cmd = [say_path]
    if voice:
        cmd += ["-v", voice]
    cmd.append(text)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.returncode == 0
