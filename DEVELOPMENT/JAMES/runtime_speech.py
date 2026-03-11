from __future__ import annotations

from pathlib import Path
import subprocess


_CUE_FILES = {
    "start_listen": "/System/Library/Sounds/Submarine.aiff",
    "recording_start": "/System/Library/Sounds/Tink.aiff",
    "recording_stop": "/System/Library/Sounds/Glass.aiff",
    "error": "/System/Library/Sounds/Basso.aiff",
}


def speak(say_path: str, text: str, voice: str | None = None) -> bool:
    cmd = [say_path]
    if voice:
        cmd += ["-v", voice]
    cmd.append(text)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.returncode == 0


def play_cue(name: str) -> bool:
    sound_path = _CUE_FILES.get(name)
    if sound_path and Path(sound_path).exists():
        result = subprocess.run(["/usr/bin/afplay", sound_path], capture_output=True, text=True, check=False)
        if result.returncode == 0:
            return True
    result = subprocess.run(["/usr/bin/osascript", "-e", "beep 1"], capture_output=True, text=True, check=False)
    return result.returncode == 0
