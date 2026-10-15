#!/usr/bin/env python3
##
## soft_sheet_scenario.py — the Moto round of the soft roof (ROOF_MASTER_PLAN v0.28): ROOF_LAB's fabric awning lets go under gravity
## alone, on a handset, with the board's own telemetry and the sheet's own cost line.
##
## WHAT IT MEASURES. `Room.scenario_roof_gravity` (the `roof_gravity` scenario step) destroys the awning's 1098 voxels and starts a
## `SoftSheet3D`; when it settles it prints one `[SOFT-SHEET]` line: the sim's cost a STEP (mean and worst), the node's cost a frame,
## the steps and drawn frames it took. The scenario marks `idle` (before), `fall` (the cloth moving) and `settled` (after), so
## `bench_analyze.py` reads the board's frame time per segment: the difference between `idle` and `fall` IS the cloth's price.
##
## THREAD. `--thread 1` (the default, and the game's) runs the sim's steps on a worker (`WorkerThreadPool`): the frame never waits for them, the
## cloth keeps the simulated pace as long as one step costs less than a step's time. `--thread 0` steps on the main thread (the control).
## UNCAPPED. `--uncapped` sets MAX_FPS=0: the game's default cap is 30 fps and a capped frame hides how much headroom is left.
##
## USAGE
##     python3 tools/persistent/soft_sheet_scenario.py --print                       # the dev_flags.cfg a handset takes
##     python3 tools/persistent/soft_sheet_scenario.py --device ZF524T5TG5            # Moto g04s, worker thread, capped at 30 fps
##     python3 tools/persistent/soft_sheet_scenario.py --device ZF524T5TG5 --thread 0 --uncapped   # the main-thread control, uncapped
## Serials: Moto g04s ZF524T5TG5, Galaxy A16 R5CY8122K7D. The phone screen must be on and unlocked; the APK must carry the change
## (`export_android.py --install --device <serial>`).

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = "/sdcard/Android/data/com.example.infiltraitor/files"


def scenario(seconds: int, blast: bool) -> str:
    ## `--blast` (ROOF_MASTER_PLAN v0.30): the real event, a grenade under the awning that takes its post, instead of letting go by gravity alone.
    event = "throw 0 @room_c_front" if blast else "roof_gravity"
    return ("framing portrait; centre @fabric_roof; zoom 0.7; frames 60; wait 3; mark idle; %s; mark fall; wait %d; "
            "mark settled; wait 3; quit") % (event, seconds)


def flags(args) -> dict:
    f = {"MAP": "ROOF_LAB", "RNG_SEED": "1", "TELEMETRY": "1", "FRAME_PROBE": "1", "SCENARIO": scenario(args.fall_seconds, args.blast),
         "SOFT_SHEET_THREAD": "1" if args.thread else "0"}
    if args.uncapped:
        f["MAX_FPS"] = "0"
    for kv in args.extra:
        k, _, v = kv.partition("=")
        f[k] = v
    return f


def main() -> int:
    ap = argparse.ArgumentParser(description="the soft roof on a handset (see the header)")
    ap.add_argument("--device", default="", help="adb serial")
    ap.add_argument("--thread", type=int, choices=[0, 1], default=1, help="1 (default) = the sim steps on a worker thread, 0 = on the main thread")
    ap.add_argument("--uncapped", action="store_true", help="MAX_FPS=0 (the default cap is 30 fps)")
    ap.add_argument("--fall-seconds", type=int, default=8, help="seconds the cloth is given to settle (default 8)")
    ap.add_argument("--blast", action="store_true", help="a grenade under the awning (takes its post) instead of gravity alone")
    ap.add_argument("--extra", action="append", default=[], help="another dev flag, K=V (repeatable), e.g. REPAINT_PROFILE=1")
    ap.add_argument("--print", action="store_true", help="print the dev_flags.cfg and stop")
    ap.add_argument("--save", default="", help="keep the device log here (default /tmp/soft_sheet_device.log)")
    args = ap.parse_args()
    f = flags(args)
    if args.print or not args.device:
        print("# SOFT SHEET — push to %s/dev_flags.cfg" % FILES)
        for k, v in f.items():
            print("%s=%s" % (k, v))
        return 0
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import device_run
    adb = device_run._find_adb()
    if args.device not in subprocess.run([adb, "devices"], capture_output=True, text=True).stdout.split():
        print("[SOFT-SHEET-RUN] device %s is not attached (cable data mode, USB debugging, the 'Allow' dialog); nothing pushed" % args.device)
        return 1
    cfg = Path("/tmp/soft_sheet_dev_flags.cfg")
    cfg.write_text("".join("%s=%s\n" % kv for kv in f.items()))
    log = Path(args.save or "/tmp/soft_sheet_device.log")
    try:
        subprocess.run([adb, "-s", args.device, "shell", "mkdir", "-p", FILES], check=True)
        subprocess.run([adb, "-s", args.device, "push", str(cfg), FILES + "/dev_flags.cfg"], check=True)
        subprocess.run([sys.executable, str(ROOT / "tools/persistent/device_run.py"), "--device", args.device,
                        "--seconds", str(args.fall_seconds + 30), "--save", str(log)])
    finally:
        subprocess.run([adb, "-s", args.device, "shell", "rm", "-f", FILES + "/dev_flags.cfg"])
    text = log.read_text(errors="ignore")
    print("\n[SOFT-SHEET-RUN] device log: %s (thread %d, %s)" % (log, args.thread, "uncapped" if args.uncapped else "capped at 30"))
    for line in text.splitlines():
        if "[SOFT-SHEET]" in line or "[SCOPED-PROF]" in line or line.startswith(("ERROR", "SCRIPT ERROR")):
            print(line[line.find("[SOFT-SHEET]") if "[SOFT-SHEET]" in line else 0:][:260])
    print()
    return subprocess.run([sys.executable, str(ROOT / "tools/persistent/bench_analyze.py"), str(log)]).returncode


if __name__ == "__main__":
    sys.exit(main())
