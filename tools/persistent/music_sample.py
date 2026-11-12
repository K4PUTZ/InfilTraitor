#!/usr/bin/env python3
##
## music_sample.py — generate loose samples (a bass line, a drum groove, an effect) from a free prompt with a local ACE-Step 1.5,
## to listen and compare. Not a finished take: nothing here is registered, and the Bible is not read.
## Runs INSIDE the ACE-Step checkout's environment (it imports `acestep`), not the project .venv:
##
##   cd D:\ACE-Step && uv run python <repo>\tools\persistent\music_sample.py "<prompt>" [--bpm 140] [--key "E minor"] [--duration 12] [--n 4]
##   cd D:\ACE-Step && uv run python <repo>\tools\persistent\music_sample.py -i      # keeps the model loaded, asks for one prompt per line
##
## Each sample lands in ASSETS/AUDIO/SAMPLES/ as <slug>-s<seed>.wav (git-ignored) plus a .json sidecar with prompt and parameters.
## A sample worth keeping goes through `music_pipeline.py register` (tool ACE-Step, licence MIT) so it gets a provenance record.
import argparse, gc, json, os, re, sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument("prompt", nargs="?", help="what to generate; leave out with -i")
ap.add_argument("-i", "--interactive", action="store_true", help="read prompts from stdin, one per line, model stays loaded")
ap.add_argument("--bpm", type=int, default=None, help="tempo; omit to let the model decide")
ap.add_argument("--key", default="", help='e.g. "E minor"; omit for automatic')
ap.add_argument("--duration", type=float, default=12.0, help="seconds, 10 to 600")
ap.add_argument("--n", type=int, default=1, help="how many variations (consecutive seeds)")
ap.add_argument("--seed", type=int, default=None, help="first seed; random when omitted")
ap.add_argument("--out", default=str(REPO / "ASSETS/AUDIO/SAMPLES"))
ap.add_argument("--offload", action=argparse.BooleanOptionalAction, default=None,
                help="keep models in system RAM between steps; default on for GPUs under 10 GiB, where a 2nd take otherwise fails the VRAM pre-flight")
a = ap.parse_args()
if not a.prompt and not a.interactive:
    ap.error("give a prompt or use -i")

root = Path(os.environ.get("ACESTEP_DIR", Path.cwd()))
sys.path.insert(0, str(root))
import torch
from acestep.handler import AceStepHandler
from acestep.inference import GenerationParams, GenerationConfig, generate_music

offload = a.offload if a.offload is not None else (torch.cuda.is_available() and torch.cuda.get_device_properties(0).total_memory < 10 * 2**30)
dit = AceStepHandler()
msg, ok = dit.initialize_service(project_root=str(root), config_path="acestep-v15-turbo", device="auto", offload_to_cpu=offload)
if not ok:
    sys.exit(f"[music_sample] DiT init failed: {msg}")
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:40] or "sample"


def run(prompt):
    first = a.seed if a.seed is not None else int.from_bytes(os.urandom(2), "big")
    for seed in range(first, first + a.n):
        params = GenerationParams(task_type="text2music", thinking=False, caption=prompt, lyrics="[Instrumental]", instrumental=True,
                                  bpm=a.bpm, keyscale=a.key, timesignature="4", duration=a.duration,
                                  inference_steps=8, guidance_scale=1.0, seed=seed)
        tmp = out / f"_tmp-{seed}"
        res = generate_music(dit, None, params=params, config=GenerationConfig(batch_size=1, audio_format="wav"), save_dir=str(tmp))
        if not res.success:
            print(f"[music_sample] FAILED seed {seed}: {res.status_message}"); continue
        for au in res.audios:
            src = Path(au["path"])
            dst = out / f"{slug(prompt)}-s{seed}.wav"
            src.replace(dst)
            dst.with_suffix(".json").write_text(json.dumps({
                "prompt": prompt, "seed": seed, "bpm": a.bpm, "key": a.key, "duration": a.duration,
                "tool": "ACE-Step", "tool_version": "1.5-turbo", "license": "MIT",
                "created": datetime.now().isoformat(timespec="seconds")}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            print(f"[music_sample] wrote {dst}")
        try: tmp.rmdir()
        except OSError: pass
        gc.collect(); torch.cuda.empty_cache()


if a.interactive:
    print("[music_sample] one prompt per line, empty line to quit")
    for line in sys.stdin:
        line = line.strip()
        if not line: break
        run(line)
else:
    run(a.prompt)
