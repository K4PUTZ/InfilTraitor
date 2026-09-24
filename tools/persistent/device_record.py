#!/usr/bin/env python3
##
## device_record.py — record the game running on a handset, trimmed to the scenario (2026-09-21).
##
## WHY. To judge the FLOW of an effect (a blast, a fade, a shot) a still is not enough. `adb shell screenrecord` uses the phone's hardware
## encoder. Measured on the Moto g04s (PLAYGROUND, one detonation, 3 runs each, 720x1600 at 8 Mbps): +1.0 to +2.0 ms per frame and
## +0.8 to +1.1 ms of GPU against not recording (32.3-33.5 vs 33.4-34.6 ms/frame). Enough to judge an effect, NOT to take a performance
## number from: never record during a measurement.
##
## WHAT IT DOES, in one command. It pushes `dev_flags.cfg` (the map, a fixed RNG seed and the SCENARIO), starts
## `screenrecord`, runs the game through `device_run.py`, stops the recording, pulls it, removes the flags file from the handset, and
## trims the video with ffmpeg: the START is cut at the scenario step named by `--from` (default: the first step, so the boot and the
## Godot splash are gone) and the END is cut `--tail` seconds after the last step, so the home screen after `quit` is gone. The cut
## points come from the game's own log (`[SCENARIO] n/N <step>` lines), never from a guessed number of seconds.
##
## ⚠️ PRECONDITIONS: the phone screen unlocked (device_run.py refuses a locked device and this then writes a ~300-byte file: unlock it
## by hand), `adb`, `ffmpeg` and `ffprobe` on the Mac, and a build that already carries the change being recorded (export + install
## first: `python3 tools/persistent/export_android.py --install --device <serial>`).
##
## PRESETS (`--preset`), each a SCENARIO whose `mark rec` step is where the video starts:
##   blast    the dev grenade 0 on PLAYGROUND, camera zoomed OUT to 0.5 and centred on the grenade from the start (no pan, no zoom
##            change during the take), fuse, blast, smoke, scorch. This is the take the Director reviews the blast flow on.
##   blast100 the same at zoom 1.0 (the close view).
## Or `--scenario "<steps>"` for anything else (see `scenario_runner.gd` for the steps; end it with `quit`; put a `mark rec` step
## where the video should begin).
##
## USAGE
##     python3 tools/persistent/device_record.py --device ZF524T5TG5 --preset blast --out videos/explosao.mp4
##     python3 tools/persistent/device_record.py --device R5CY8122K7D --map SIGMA_01 \
##         --scenario "framing portrait; frames 40; centre agent; zoom 1.0; mark rec; shoot 0; wait 3; quit" --out videos/tiro.mp4
##   `videos/` at the repo root is git-ignored: recordings stay on the Mac.
##   Serials: Moto g04s ZF524T5TG5, Galaxy A16 R5CY8122K7D (`adb devices -l`).

import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ADB = "/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
PACKAGE = "com.example.infiltraitor"
FLAGS_REMOTE = "/sdcard/Android/data/%s/files/dev_flags.cfg" % PACKAGE
REMOTE = "/sdcard/device_record.mp4"

PRESETS = {
    "blast": "framing portrait; zoom 0.5; centre 3,5; frames 30; wait 1; mark rec; wait 3; detonate 0; wait 3; quit",
    "blast100": "framing portrait; zoom 1.0; centre 3,5; frames 30; wait 1; mark rec; wait 3; detonate 0; wait 3; quit",
}


def _clock_seconds(hms: str) -> float:
    h, m, s = hms.split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)


def main() -> int:
    ap = argparse.ArgumentParser(description="Record the game on a handset, trimmed to the scenario (see the header).")
    ap.add_argument("--device", required=True, help="adb serial")
    ap.add_argument("--out", required=True, help="local .mp4 path (use videos/, which is git-ignored)")
    ap.add_argument("--preset", choices=sorted(PRESETS), help="a ready scenario")
    ap.add_argument("--scenario", help="SCENARIO steps, ';' separated (instead of a preset)")
    ap.add_argument("--map", default="PLAYGROUND")
    ap.add_argument("--from", dest="from_step", default="mark rec",
                    help="the video starts at the first `[SCENARIO]` line containing this text (default `mark rec`, else step 1)")
    ap.add_argument("--tail", type=float, default=1.0, help="seconds kept after the last step (default 1.0)")
    ap.add_argument("--seconds", type=int, default=170, help="capture window for device_run.py (screenrecord caps at 180)")
    ap.add_argument("--size", default="720x1600", help="recording size (default 720x1600)")
    ap.add_argument("--bit-rate", default="8000000")
    ap.add_argument("--flag", action="append", default=[], help="an extra KEY=VALUE for dev_flags.cfg (repeatable)")
    args = ap.parse_args()
    scenario = args.scenario or (PRESETS[args.preset] if args.preset else None)
    if not scenario:
        ap.error("give --preset or --scenario")

    def adb(*a, text=True):
        return subprocess.run([ADB, "-s", args.device, *a], capture_output=True, text=text)

    flags = ["MAP=%s" % args.map, "RNG_SEED=1", "SCENARIO=%s" % scenario] + args.flag
    local_flags = Path("/tmp/device_record_flags.cfg")
    local_flags.write_text("\n".join(flags) + "\n")
    adb("shell", "mkdir", "-p", FLAGS_REMOTE.rsplit("/", 1)[0])
    adb("push", str(local_flags), FLAGS_REMOTE)
    adb("shell", "rm", "-f", REMOTE)

    log_path = Path("/tmp/device_record_run.log")
    dev_now = adb("shell", "date", "+%H:%M:%S.%N").stdout.strip()  # the handset's clock: the log stamps are the handset's too
    t_rec0 = _clock_seconds(dev_now[:12])
    rec = subprocess.Popen([ADB, "-s", args.device, "shell", "screenrecord", "--size", args.size,
                            "--bit-rate", args.bit_rate, "--time-limit", str(min(args.seconds, 180)), REMOTE])
    time.sleep(2)
    run = subprocess.run([sys.executable, str(REPO / "tools/persistent/device_run.py"), "--device", args.device,
                          "--seconds", str(args.seconds), "--save", str(log_path)], capture_output=True, text=True)
    adb("shell", "pkill", "-2", "screenrecord")  # SIGINT: lets it finalise the mp4
    time.sleep(3)
    rec.terminate()
    adb("shell", "rm", "-f", FLAGS_REMOTE)  # never leave test flags behind: the next hand run would boot with them
    if "LOCKED" in run.stdout:
        print("[DEVICE-RECORD] FAIL — the handset is locked. Unlock it by hand and run again.")
        return 1

    # cut points from the game's own log
    steps = []
    for line in log_path.read_text(errors="ignore").splitlines():
        m = re.search(r"(\d\d:\d\d:\d\d\.\d+).*\[SCENARIO\] (\d+)/(\d+) (.*)$", line)
        if m:
            steps.append((_clock_seconds(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)))
    if not steps:
        print("[DEVICE-RECORD] FAIL — no `[SCENARIO]` line in the log: the scenario never ran (see /tmp/device_record_run.log).")
        return 1
    first = next((s for s in steps if args.from_step in s[3]), steps[0])
    last = steps[-1]
    skip = max(first[0] - t_rec0, 0.0)
    keep = max(last[0] - first[0] + args.tail, 1.0)
    if skip > 86000:
        skip -= 86400  # the clock wrapped past midnight between the two stamps
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = out.with_suffix(".raw.mp4")
    adb("pull", REMOTE, str(raw))
    adb("shell", "rm", "-f", REMOTE)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", "%.2f" % skip, "-i", str(raw), "-t", "%.2f" % keep,
                    "-c:v", "libx264", "-preset", "fast", "-crf", "20", str(out)])
    raw.unlink(missing_ok=True)
    print("[DEVICE-RECORD] %s (%d bytes): from `%s` (+%.1f s into the recording), %.1f s long"
          % (out, out.stat().st_size if out.exists() else 0, first[3], skip, keep))
    return 0 if out.exists() and out.stat().st_size > 10000 else 1


if __name__ == "__main__":
    sys.exit(main())
