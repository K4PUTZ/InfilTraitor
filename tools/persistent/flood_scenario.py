#!/usr/bin/env python3
##
## flood_scenario.py — MATERIALS F12 feasibility round: what does a WHOLE segment under water cost on a handset?
##
## One run, three models back to back on the same map and camera, each with its own `mark` so `bench_analyze.py` reads the board's frame time per
## segment (idle -> p05 -> level -> p025 -> after):
##   p05    a `FluidPlane` of 0.5 GU cells over the whole playable floor (no walls: every cell active, the UPPER bound), ticked every 0.3 s, drawn by
##          a driven `LiquidSheet3D` (its mesh is rebuilt in GDScript on the main thread while the level moves)
##   level  one flat sheet, no sim: what the "level model" (a number per compartment) costs to draw
##   p025   the same plane at 0.25 GU cells (the resolution of the channel bench)
## `--stress` runs it on STRESS (24 guards, glass hall, 14 lights) and throws the two grenades of `stress_scenario.py` while p05 is running.
## The `[FLOOD]` lines carry the plane's tick (mean, worst) from `Room.scenario_flood`. Read the numbers, never judge them here.
##
##     python3 tools/persistent/flood_scenario.py --print
##     python3 tools/persistent/flood_scenario.py --device ZF524T5TG5 [--stress] [--uncapped]
## Serials: Moto g04s ZF524T5TG5, Galaxy A16 R5CY8122K7D. The screen on and unlocked; the APK must carry the change (`export_android.py --install`).
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = "/sdcard/Android/data/com.example.infiltraitor/files"


def scenario_f8() -> str:
    ## M6 F8: N copies of PIPE_LAB's real channel, each a plane + a driven sheet with the real look, ticked every 0.3 s
    return ("framing portrait; centre agent; zoom 0.5; frames 60; wait 10; flood off; mark idle; wait 10; "
            "flood ch1; mark ch1; wait 14; flood ch4; mark ch4; wait 14; flood ch8; mark ch8; wait 14; flood off; mark after; wait 10; quit")


def scenario(stress: bool) -> str:
    if stress:
        ## the stress scenario's own script (stress_scenario.py), with the LEVEL model's sheet on from the start: the two stacked blasts and the shot over water
        return ("framing portrait; centre agent; zoom 0.5; wait 12; flood level; mark idle; throw 0 12,20; frames 150; mark second; throw 1 36,23; wait 14; "
                "shoot 0; wait 12; mark after; quit")
    head = "framing portrait; centre agent; zoom 0.5; frames 60; wait 10; flood off; mark idle; wait 10; "
    mid = "flood plane05; mark p05; wait 14; "
    return head + mid + "flood level; mark level; wait 12; flood plane025; mark p025; wait 10; flood off; mark after; wait 10; quit"


def flags(args) -> dict:
    f = {"MAP": "STRESS" if args.stress else args.map, "RNG_SEED": "1", "TELEMETRY": "1", "FRAME_PROBE": "1", "SCENARIO": scenario_f8() if args.f8 else scenario(args.stress)}
    if args.stress:
        f["GRENADE_GUS"] = "20,21;36,24"
        f["THROW_PROFILE"] = "1"
        f["EVENT_FRAMES"] = "1"
    if args.uncapped:
        f["MAX_FPS"] = "0"
    return f


def main() -> int:
    ap = argparse.ArgumentParser(description="a whole segment under water on a handset (see the header)")
    ap.add_argument("--device", default="")
    ap.add_argument("--map", default="SEG_HEAVY")
    ap.add_argument("--stress", action="store_true")
    ap.add_argument("--f8", action="store_true", help="M6 F8: 1, 4 and 8 copies of the PIPE_LAB channel instead of the whole-segment bench")
    ap.add_argument("--uncapped", action="store_true")
    ap.add_argument("--print", action="store_true")
    ap.add_argument("--save", default="")
    ap.add_argument("--seconds", type=int, default=190)
    args = ap.parse_args()
    f = flags(args)
    if args.print or not args.device:
        for k, v in f.items():
            print("%s=%s" % (k, v))
        return 0
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import device_run
    adb = device_run._find_adb()
    if args.device not in subprocess.run([adb, "devices"], capture_output=True, text=True).stdout.split():
        print("[FLOOD-RUN] device %s is not attached; nothing pushed" % args.device)
        return 1
    cfg = Path("/tmp/flood_dev_flags.cfg")
    cfg.write_text("".join("%s=%s\n" % kv for kv in f.items()))
    log = Path(args.save or "/tmp/flood_device.log")
    try:
        subprocess.run([adb, "-s", args.device, "shell", "mkdir", "-p", FILES], check=True)
        subprocess.run([adb, "-s", args.device, "push", str(cfg), FILES + "/dev_flags.cfg"], check=True)
        subprocess.run([sys.executable, str(ROOT / "tools/persistent/device_run.py"), "--device", args.device, "--seconds", str(args.seconds),
                        "--mem-poll", "5", "--save", str(log)])
    finally:
        subprocess.run([adb, "-s", args.device, "shell", "rm", "-f", FILES + "/dev_flags.cfg"])
    text = log.read_text(errors="ignore")
    print("\n[FLOOD-RUN] device log: %s" % log)
    for line in text.splitlines():
        if "[FLOOD]" in line:
            tag = line[line.find("[FLOOD]"):]
            print(tag[:240])
        elif line.startswith(("ERROR", "SCRIPT ERROR")):
            print(line[:240])
    print()
    return subprocess.run([sys.executable, str(ROOT / "tools/persistent/bench_analyze.py"), str(log)]).returncode


if __name__ == "__main__":
    sys.exit(main())
