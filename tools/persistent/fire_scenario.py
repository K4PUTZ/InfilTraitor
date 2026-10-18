#!/usr/bin/env python3
##
## fire_scenario.py — M6 F5: what a burning body costs on a handset. PIPE_LAB's channel carries oil, a blast point lights it, the frame time before (`idle`) and
## while it burns (`fire`) comes from bench_analyze. Flags: any dev flag as --extra K=V (FLAME_STYLE=embers|tongues|both, FLAME_EMBER_RATE, FLAME_H, ...).
##     python3 tools/persistent/fire_scenario.py --device R5CY8122K7D --uncapped [--extra FLAME_STYLE=tongues]
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = "/sdcard/Android/data/com.example.infiltraitor/files"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", required=True)
    ap.add_argument("--uncapped", action="store_true")
    ap.add_argument("--extra", action="append", default=[])
    ap.add_argument("--seconds", type=int, default=90)
    ap.add_argument("--save", default="/tmp/fire_device.log")
    args = ap.parse_args()
    f = {"MAP": "PIPE_LAB", "RNG_SEED": "1", "TELEMETRY": "1", "FRAME_PROBE": "1", "WATER_STUDY": "petroleo", "FLUID_PREROLL": "60", "FLUID_AUTO_TICK": "0.5",
         "LIQUID_IGNITE": "14:12,6,1",
         "SCENARIO": "framing portrait; centre 12,6; zoom 0.9; frames 60; wait 6; mark idle; wait 10; mark fire; wait 16; quit"}
    if args.uncapped:
        f["MAX_FPS"] = "0"
    for kv in args.extra:
        k, _, v = kv.partition("=")
        f[k] = v
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import device_run
    adb = device_run._find_adb()
    cfg = Path("/tmp/fire_dev_flags.cfg")
    cfg.write_text("".join("%s=%s\n" % kv for kv in f.items()))
    log = Path(args.save)
    try:
        subprocess.run([adb, "-s", args.device, "shell", "mkdir", "-p", FILES], check=True)
        subprocess.run([adb, "-s", args.device, "push", str(cfg), FILES + "/dev_flags.cfg"], check=True)
        subprocess.run([sys.executable, str(ROOT / "tools/persistent/device_run.py"), "--device", args.device, "--seconds", str(args.seconds), "--save", str(log)])
    finally:
        subprocess.run([adb, "-s", args.device, "shell", "rm", "-f", FILES + "/dev_flags.cfg"])
    return subprocess.run([sys.executable, str(ROOT / "tools/persistent/bench_analyze.py"), str(log)]).returncode


if __name__ == "__main__":
    sys.exit(main())
