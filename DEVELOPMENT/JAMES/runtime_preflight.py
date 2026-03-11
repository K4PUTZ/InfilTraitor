from __future__ import annotations

from dataclasses import asdict, dataclass
import importlib
import subprocess

from runtime_config import JamesConfig


@dataclass
class CheckResult:
    name: str
    ok: bool
    detail: str


def _module_check(module_name: str) -> CheckResult:
    try:
        importlib.import_module(module_name)
        return CheckResult(module_name, True, "available")
    except Exception as exc:
        return CheckResult(module_name, False, f"missing: {exc}")


def _tool_check(label: str, path: str | None) -> CheckResult:
    if path:
        return CheckResult(label, True, path)
    return CheckResult(label, False, "not found on PATH")


def _voice_check(say_path: str, voice_name: str) -> CheckResult:
    try:
        result = subprocess.run(
            [say_path, "-v", voice_name, ""],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
        if result.returncode == 0:
            return CheckResult(f"say voice: {voice_name}", True, "available")
        return CheckResult(
            f"say voice: {voice_name}",
            False,
            "voice not found. Run 'say -v ?' to list available voices.",
        )
    except Exception as exc:
        return CheckResult(f"say voice: {voice_name}", False, str(exc))


def run_preflight(config: JamesConfig) -> dict[str, object]:
    required_tools = [
        _tool_check("osascript", config.osascript_path),
        _tool_check("screencapture", config.screencapture_path),
        _tool_check("say", config.say_path),
        _voice_check(config.say_path, config.say_voice),
        _tool_check("cliclick", config.cliclick_path),
        _tool_check("tesseract", config.tesseract_path),
        _tool_check("ffmpeg", config.ffmpeg_path),
        CheckResult("Godot.app", config.godot_app_path.exists(), str(config.godot_app_path)),
    ]

    optional_modules = [
        _module_check("pynput"),
        _module_check("speech_recognition"),
        _module_check("Vision"),
        _module_check("Quartz"),
        _module_check("Cocoa"),
        _module_check("objc"),
    ]

    return {
        "required_tools": [asdict(item) for item in required_tools],
        "optional_modules": [asdict(item) for item in optional_modules],
        "notes": [
            "Preflight verifies binary and import availability, not macOS permission grants.",
            "Screen capture and System Events access can still fail at runtime if macOS has not granted the needed permissions.",
        ],
        "ready_for_runtime": all(item.ok for item in required_tools[:4]),
        "ready_for_full_operator": all(item.ok for item in required_tools)
        and all(item.ok for item in optional_modules),
    }
