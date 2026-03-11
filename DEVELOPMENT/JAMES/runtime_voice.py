from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import contextlib
import signal
import subprocess
import sys
import threading
import time

from runtime_speech import play_cue

try:
    import termios
except Exception:  # pragma: no cover - non-POSIX fallback
    termios = None


@dataclass
class VoiceCaptureResult:
    transcript: str
    audio_path: Path


class PushToTalkIdleTimeout(TimeoutError):
    pass


class PushToTalkRecordingTimeout(TimeoutError):
    pass


@contextlib.contextmanager
def _suppress_terminal_input():
    if termios is None or not sys.stdin.isatty():
        yield
        return

    fd = sys.stdin.fileno()
    original_attrs = termios.tcgetattr(fd)
    muted_attrs = termios.tcgetattr(fd)
    muted_attrs[3] &= ~(termios.ECHO | termios.ICANON)
    try:
        termios.tcflush(fd, termios.TCIFLUSH)
        termios.tcsetattr(fd, termios.TCSANOW, muted_attrs)
        yield
    finally:
        try:
            termios.tcflush(fd, termios.TCIFLUSH)
            termios.tcsetattr(fd, termios.TCSANOW, original_attrs)
        except Exception:
            pass


def _load_speech_recognition_module():
    try:
        import speech_recognition as sr
    except Exception as exc:
        raise RuntimeError(f"SpeechRecognition is unavailable: {exc}") from exc
    return sr


def _load_keyboard_module():
    try:
        from pynput import keyboard
    except Exception as exc:
        raise RuntimeError(f"pynput keyboard capture is unavailable: {exc}") from exc
    return keyboard


def _matches_trigger(key: object, trigger_vks: tuple[int, ...]) -> bool:
    vk = getattr(key, "vk", None)
    return vk in trigger_vks


def start_audio_recording(ffmpeg_path: str, output_path: Path, audio_device_index: str) -> subprocess.Popen[str]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    return subprocess.Popen(
        [
            ffmpeg_path,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "avfoundation",
            "-i",
            f":{audio_device_index}",
            "-ac",
            "1",
            "-ar",
            "16000",
            str(output_path),
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )


def stop_audio_recording(process: subprocess.Popen[str], timeout: float = 5) -> None:
    if process.poll() is not None:
        return
    try:
        if process.stdin:
            process.stdin.write("q\n")
            process.stdin.flush()
        process.wait(timeout=timeout)
    except Exception:
        process.send_signal(signal.SIGINT)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=timeout)


def transcribe_audio(audio_path: Path) -> str:
    sr = _load_speech_recognition_module()
    recognizer = sr.Recognizer()
    with sr.AudioFile(str(audio_path)) as source:
        audio = recognizer.record(source)
    return recognizer.recognize_google(audio)


def capture_push_to_talk(
    *,
    ffmpeg_path: str,
    audio_device_index: str,
    trigger_vks: tuple[int, ...],
    output_path: Path,
    on_recording_start=None,
    on_recording_stop=None,
    timeout: float | None = 60,
) -> VoiceCaptureResult:
    keyboard = _load_keyboard_module()
    state = {
        "started": False,
        "recording": False,
        "completed": False,
        "process": None,
        "transcript": None,
        "error": None,
    }
    done = threading.Event()
    lock = threading.Lock()

    def on_press(key):
        with lock:
            if state["recording"] or not _matches_trigger(key, trigger_vks):
                return
            state["started"] = True
            state["process"] = start_audio_recording(ffmpeg_path, output_path, audio_device_index)
            state["recording"] = True
            if on_recording_start:
                on_recording_start()

    def on_release(key):
        with lock:
            if not state["recording"] or not _matches_trigger(key, trigger_vks):
                return
            process = state["process"]
            if process is None:
                state["error"] = RuntimeError("Recording process not initialized")
                done.set()
                return False
            stop_audio_recording(process)
            state["recording"] = False
            if on_recording_stop:
                on_recording_stop()
            try:
                # Small delay so ffmpeg flushes the wav header before transcription.
                time.sleep(0.3)
                state["transcript"] = transcribe_audio(output_path)
                state["completed"] = True
            except Exception as exc:
                state["error"] = exc
            done.set()
            return False

    with _suppress_terminal_input():
        listener = keyboard.Listener(on_press=on_press, on_release=on_release)
        listener.start()
        wait_timeout = None if timeout is None or timeout <= 0 else timeout
        finished = done.wait(timeout=wait_timeout)
        listener.stop()
        listener.join(timeout=2)

    if not finished:
        with lock:
            process = state.get("process")
            started = bool(state.get("started"))
            if process is not None:
                stop_audio_recording(process)
        if started:
            raise PushToTalkRecordingTimeout("Timed out waiting for push-to-talk capture to finish")
        raise PushToTalkIdleTimeout("Timed out waiting for push-to-talk trigger")

    if state["error"]:
        raise state["error"]
    if not state["completed"] or not state["transcript"]:
        raise RuntimeError("Push-to-talk capture completed without transcript")
    return VoiceCaptureResult(transcript=state["transcript"], audio_path=output_path)


def capture_voice_answer(
    *,
    say_path: str,
    question: str,
    ffmpeg_path: str,
    audio_device_index: str,
    trigger_vks: tuple[int, ...],
    output_path: Path,
    timeout: float = 30.0,
    voice: str | None = None,
) -> str:
    """Speak a question via `say`, then capture a push-to-talk answer. Returns the transcript."""
    _say_cmd = [say_path] + (["-v", voice] if voice else [])
    subprocess.run([*_say_cmd, question], check=False)
    result = capture_push_to_talk(
        ffmpeg_path=ffmpeg_path,
        audio_device_index=audio_device_index,
        trigger_vks=trigger_vks,
        output_path=output_path,
        on_recording_start=lambda: play_cue("recording_start"),
        on_recording_stop=lambda: play_cue("recording_stop"),
        timeout=timeout,
    )
    return result.transcript
