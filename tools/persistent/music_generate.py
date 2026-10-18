#!/usr/bin/env python3
##
## music_generate.py — generate one instrumental take with a local ACE-Step 1.5 (MIT code and weights) from the Music Bible.
## Runs INSIDE the ACE-Step checkout's environment (it imports `acestep`), not the project .venv:
##
##   cd $ACESTEP_DIR && uv run python <repo>/tools/persistent/music_generate.py <context> <out_dir> [--duration 30] [--seed 42]
##
## The prompt comes from `music_pipeline.py prompt` (one source of truth); afterwards register the wav with
## `music_pipeline.py register ... --tool ACE-Step --tool-version 1.5-turbo --license MIT --params seed=...`.
import argparse, json, os, subprocess, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument("context"); ap.add_argument("out_dir")
ap.add_argument("--duration", type=float, default=30.0)
ap.add_argument("--seed", type=int, default=42)
a = ap.parse_args()

bible = json.loads((REPO / "ASSETS/AUDIO/MUSIC/bible.json").read_text())
ctx = bible["contexts"][a.context]
prompt = subprocess.run([sys.executable, str(REPO / "tools/persistent/music_pipeline.py"), "prompt", a.context],
                        capture_output=True, text=True, check=True).stdout.strip()

root = Path(os.environ.get("ACESTEP_DIR", Path.cwd()))
sys.path.insert(0, str(root))
from acestep.handler import AceStepHandler
from acestep.inference import GenerationParams, GenerationConfig, generate_music

dit = AceStepHandler()
msg, ok = dit.initialize_service(project_root=str(root), config_path="acestep-v15-turbo", device="auto", offload_to_cpu=False)
if not ok:
    sys.exit(f"[music_generate] DiT init failed: {msg}")
params = GenerationParams(task_type="text2music", thinking=False, caption=prompt, lyrics="[Instrumental]", instrumental=True,
                          bpm=ctx["bpm"], keyscale="A minor", timesignature="4", duration=a.duration,
                          inference_steps=8, guidance_scale=1.0, seed=a.seed)
Path(a.out_dir).mkdir(parents=True, exist_ok=True)
res = generate_music(dit, None, params=params, config=GenerationConfig(batch_size=1, audio_format="wav"), save_dir=a.out_dir)
if not res.success:
    sys.exit(f"[music_generate] FAILED: {res.status_message}")
for au in res.audios:
    print(f"[music_generate] wrote {au.get('path')}")
