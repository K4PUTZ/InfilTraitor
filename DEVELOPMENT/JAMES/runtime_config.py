from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import subprocess


@dataclass(frozen=True)
class JamesConfig:
    root_dir: Path
    logs_dir: Path
    sessions_dir: Path
    skills_dir: Path
    state_dir: Path
    screenshots_dir: Path
    audio_dir: Path
    actions_log_path: Path
    session_index_path: Path
    runtime_state_path: Path
    brain_request_path: Path
    brain_response_path: Path
    code_agent_request_path: Path
    code_agent_result_path: Path
    default_return_app: str
    osascript_path: str
    screencapture_path: str
    say_path: str
    cliclick_path: str | None
    tesseract_path: str | None
    ffmpeg_path: str | None
    godot_app_path: Path
    push_to_talk_key_vks: tuple[int, ...]
    audio_device_index: str
    audio_device_name: str | None
    say_voice: str


@dataclass(frozen=True)
class AudioInputDevice:
    index: str
    name: str
    score: int | None


def _score_audio_device(name: str) -> int | None:
    lower = name.lower()
    rejected_keywords = (
        "blackhole",
        "soundflower",
        "loopback",
        "aggregate",
        "teams audio",
        "zoom audio",
        "audio bridge",
        "pro tools",
    )
    if any(keyword in lower for keyword in rejected_keywords):
        return None

    score = 1
    if any(keyword in lower for keyword in ("webcam", "c922")):
        score += 8
    if any(keyword in lower for keyword in ("airpods", "buds", "earbuds", "headset", "headphones", "philips")):
        score += 4
    if any(keyword in lower for keyword in ("microphone", "mic", "macbook", "built-in")):
        score += 5
    return score


def list_audio_input_devices(ffmpeg_path: str | None) -> list[AudioInputDevice]:
    if not ffmpeg_path:
        return []
    try:
        result = subprocess.run(
            [ffmpeg_path, "-f", "avfoundation", "-list_devices", "true", "-i", ""],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
    except Exception:
        return []

    devices: list[AudioInputDevice] = []
    in_audio_section = False
    for line in result.stderr.splitlines():
        lower = line.lower()
        if "audio devices" in lower:
            in_audio_section = True
            continue
        if not in_audio_section:
            continue
        m = re.search(r"\[(\d+)\]\s+(.+)", line)
        if not m:
            continue
        index, name = m.group(1), m.group(2)
        devices.append(AudioInputDevice(index=index, name=name, score=_score_audio_device(name)))
    return devices


def get_audio_input_device_name(ffmpeg_path: str | None, index: str) -> str | None:
    for device in list_audio_input_devices(ffmpeg_path):
        if device.index == index:
            return device.name
    return None


def _detect_audio_device_index(ffmpeg_path: str | None) -> str:
    """Probe ffmpeg for audio input devices and return the best real microphone index.

    Prefers likely physical microphones and skips known virtual, conferencing, and bridge devices.
    Returns "0" if detection fails or no suitable device is found.
    """
    if not ffmpeg_path:
        return "0"
    try:
        candidates = [(device.score, device.index) for device in list_audio_input_devices(ffmpeg_path) if device.score is not None]
        if candidates:
            candidates.sort(reverse=True)
            return candidates[0][1]
    except Exception:
        pass
    return "0"


def load_config() -> JamesConfig:
    root_dir = Path(__file__).resolve().parent
    logs_dir = root_dir / "logs"
    sessions_dir = root_dir / "sessions"
    skills_dir = root_dir / "skills"
    state_dir = root_dir / "state"
    screenshots_dir = logs_dir / "screenshots"
    audio_dir = logs_dir / "audio"

    for directory in (logs_dir, sessions_dir, skills_dir, state_dir, screenshots_dir, audio_dir):
        directory.mkdir(parents=True, exist_ok=True)

    _ffmpeg = shutil.which("ffmpeg")
    # Env var takes priority; fall back to auto-detection from ffmpeg device list.
    audio_device_index = os.environ.get("JAMES_AUDIO_DEVICE_INDEX") or _detect_audio_device_index(_ffmpeg)
    audio_device_name = get_audio_input_device_name(_ffmpeg, audio_device_index)

    return JamesConfig(
        root_dir=root_dir,
        logs_dir=logs_dir,
        sessions_dir=sessions_dir,
        skills_dir=skills_dir,
        state_dir=state_dir,
        screenshots_dir=screenshots_dir,
        audio_dir=audio_dir,
        actions_log_path=logs_dir / "actions.jsonl",
        session_index_path=state_dir / "session_index.json",
        runtime_state_path=state_dir / "runtime_state.json",
        brain_request_path=state_dir / "brain_request.json",
        brain_response_path=state_dir / "brain_response.json",
        code_agent_request_path=state_dir / "code_agent_request.json",
        code_agent_result_path=state_dir / "code_agent_result.json",
        default_return_app="Visual Studio Code",
        osascript_path=shutil.which("osascript") or "/usr/bin/osascript",
        screencapture_path=shutil.which("screencapture") or "/usr/sbin/screencapture",
        say_path=shutil.which("say") or "/usr/bin/say",
        cliclick_path=shutil.which("cliclick"),
        tesseract_path=shutil.which("tesseract"),
        ffmpeg_path=_ffmpeg,
        godot_app_path=Path("/Applications/Godot.app"),
        push_to_talk_key_vks=(82,),
        audio_device_index=audio_device_index,
        audio_device_name=audio_device_name,
        say_voice="Rocko (English (US))",
    )
