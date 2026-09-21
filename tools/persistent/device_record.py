#!/usr/bin/env python3
##
## device_record.py — record the game running on a handset (2026-09-21).
##
## `adb shell screenrecord` uses the phone's hardware encoder. Measured on the Moto g04s (PLAYGROUND, one detonation, 3 runs each, 720x1600 at
## 8 Mbps): +1.0 to +2.0 ms per frame and +0.8 to +1.1 ms of GPU against not recording (32.3-33.5 vs 33.4-34.6 ms/frame). Enough to
## judge the flow of an effect, NOT to take a performance number from: never record during a measurement.
##
## It wraps `device_run.py`, so the game starts from whatever `dev_flags.cfg` is on the handset (push a SCENARIO first, ending in
## `quit`, and the recording ends with the game). The file comes back as-is, with the boot in it (55-70 s on the Moto); `--skip`
## trims that with ffmpeg.
##
## Usage:
##     python3 tools/persistent/device_record.py --device ZF524T5TG5 --seconds 170 --out Screenshots/blast.mp4 --skip 70

import argparse
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ADB = "/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
REMOTE = "/sdcard/device_record.mp4"


def main() -> int:
    ap = argparse.ArgumentParser(description="Record the game on a handset (see the header).")
    ap.add_argument("--device", required=True, help="adb serial")
    ap.add_argument("--seconds", type=int, default=170, help="capture window for device_run.py (screenrecord caps at 180)")
    ap.add_argument("--out", required=True, help="local .mp4 path")
    ap.add_argument("--size", default="720x1600", help="recording size (default 720x1600)")
    ap.add_argument("--bit-rate", default="8000000")
    ap.add_argument("--skip", type=float, default=0.0, help="seconds to trim off the start (the boot)")
    ap.add_argument("--trim-end", type=float, default=4.0, help="seconds to trim off the end (the home screen after `quit`)")
    args = ap.parse_args()

    def adb(*a):
        return subprocess.run([ADB, "-s", args.device, *a], capture_output=True, text=True)

    adb("shell", "rm", "-f", REMOTE)
    rec = subprocess.Popen([ADB, "-s", args.device, "shell", "screenrecord", "--size", args.size,
                            "--bit-rate", args.bit_rate, "--time-limit", str(min(args.seconds, 180)), REMOTE])
    time.sleep(2)
    subprocess.run([sys.executable, str(REPO / "tools/persistent/device_run.py"), "--device", args.device,
                    "--seconds", str(args.seconds)])
    adb("shell", "pkill", "-2", "screenrecord")  # SIGINT: lets it finalise the mp4
    time.sleep(3)
    rec.terminate()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = out if (args.skip <= 0 and args.trim_end <= 0) else out.with_suffix(".raw.mp4")
    adb("pull", REMOTE, str(raw))
    adb("shell", "rm", "-f", REMOTE)
    if args.skip > 0 or args.trim_end > 0:
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(raw)],
                                   capture_output=True, text=True).stdout.strip() or 0)
        trimmed = out.with_suffix(".trim.mp4")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", str(args.skip), "-i", str(raw),
                        "-t", str(max(1.0, dur - args.skip - args.trim_end)), "-c:v", "libx264", "-preset", "fast", "-crf", "20", str(trimmed)])
        raw.unlink(missing_ok=True)
        trimmed.replace(out)
    print("[DEVICE-RECORD] %s (%d bytes)" % (out, out.stat().st_size if out.exists() else 0))
    return 0 if out.exists() else 1


if __name__ == "__main__":
    sys.exit(main())
