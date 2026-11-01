#!/usr/bin/env python3
##
## actor_scenario.py — what N live Agents cost on a handset (ACTOR D91 / CHARACTER_MASTER_PLAN, 2026-11-01). One boot per model: PLAYGROUND, portrait, a `mark idle` segment
## with nothing spawned, then `actor_bench <model> <n>` and a second segment, so each run carries its own baseline (frame time, from bench_analyze's `frame.window` medians,
## and the PSS poll). Models: `agent` (the shipped agent_live), `agent_<light|full>_<female|male>[_nocoat]` (the Tripo Agents, their own `dive` action looping).
##     python3 tools/persistent/actor_scenario.py --device ZF524T5TG5 --uncapped --models agent,agent_light_female,agent_full_female [--count 9] [--seconds 160]
## Logs land in <--out> (default docs/measurements). The device's dev_flags.cfg is removed at the end. GPU cost wants --uncapped (MAX_FPS=0).
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = "/sdcard/Android/data/com.example.infiltraitor/files"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", required=True)
    ap.add_argument("--models", required=True, help="comma list")
    ap.add_argument("--count", type=int, default=9)
    ap.add_argument("--uncapped", action="store_true")
    ap.add_argument("--seconds", type=int, default=170)
    ap.add_argument("--out", default=str(ROOT / "docs/measurements"))
    ap.add_argument("--extra", action="append", default=[])
    args = ap.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import device_run
    adb = device_run._find_adb()
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    rc = 0
    try:
        for model in args.models.split(","):
            flags = {"MAP": "PLAYGROUND", "RNG_SEED": "1", "TELEMETRY": "1", "FRAME_PROBE": "1",
                     "SCENARIO": "framing portrait; centre agent; zoom 0.9; frames 60; wait 8; mark idle; wait 7; actor_bench %s %d; wait 3; mark %s; wait 14; quit" % (model, args.count, model)}
            if args.uncapped:
                flags["MAX_FPS"] = "0"
            for kv in args.extra:
                k, _, v = kv.partition("=")
                flags[k] = v
            cfg = Path("/tmp/actor_dev_flags.cfg")
            cfg.write_text("".join("%s=%s\n" % kv for kv in flags.items()))
            log = out / ("actor_%s_x%d.log" % (model, args.count))
            subprocess.run([adb, "-s", args.device, "shell", "mkdir", "-p", FILES], check=True)
            subprocess.run([adb, "-s", args.device, "push", str(cfg), FILES + "/dev_flags.cfg"], check=True)
            print("=== %s x%d ===" % (model, args.count), flush=True)
            subprocess.run([sys.executable, str(ROOT / "tools/persistent/device_run.py"), "--device", args.device, "--seconds", str(args.seconds),
                            "--mem-poll", "4", "--save", str(log)])
            rc |= subprocess.run([sys.executable, str(ROOT / "tools/persistent/bench_analyze.py"), str(log)]).returncode
    finally:
        subprocess.run([adb, "-s", args.device, "shell", "rm", "-f", FILES + "/dev_flags.cfg"])
    return rc


if __name__ == "__main__":
    sys.exit(main())
