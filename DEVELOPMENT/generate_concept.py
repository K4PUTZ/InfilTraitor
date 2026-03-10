#!/usr/bin/env python3
"""
INFILTRAITOR — Stable Diffusion concept art generator.

Uses the AUTOMATIC1111 SD WebUI API to generate images.
Can auto-launch the WebUI if it's not already running.

Usage (with the SD venv Python):
    SD_VENV/bin/python generate_concept.py [options]

Options:
    --prompt TEXT         Override the default prompt
    --negative TEXT       Override the default negative prompt
    --width N             Image width  (default: 512)
    --height N            Image height (default: 768, portrait)
    --steps N             Sampling steps (default: 30)
    --cfg FLOAT           CFG scale (default: 7.5)
    --seed N              Seed (-1 = random, default: -1)
    --name PREFIX         Output filename prefix (default: infiltraitor_concept)
    --no-launch           Don't try to auto-launch SD WebUI
    --api URL             SD WebUI API base URL (default: http://127.0.0.1:7860)

Output is saved to:  DEVELOPMENT/concept_art/<name>_<N>.png

IMPORTANT — VS Code terminal limitation:
    The VS Code integrated terminal may kill long-running processes when
    running new commands.  Always run this script **detached** using the
    companion wrapper:
        bash generate_art.sh "your prompt here"
    Or manually:
        (nohup SD_VENV/bin/python generate_concept.py > /tmp/sd_gen.log 2>&1 &)
    Then monitor with:
        bash generate_art.sh --status
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
# Prefer a sibling checkout (../stable-diffusion-webui relative to repo root),
# but also support an in-repo checkout (stable-diffusion-webui inside repo).
_SD_CANDIDATES = [
    REPO_ROOT.parent / "stable-diffusion-webui",
    REPO_ROOT / "stable-diffusion-webui",
]
SD_DIR = next((p for p in _SD_CANDIDATES if p.exists()), _SD_CANDIDATES[0])
OUT_DIR = SCRIPT_DIR / "concept_art"

# ── Defaults ───────────────────────────────────────────────────────────────
DEFAULT_API = "http://127.0.0.1:7860"

DEFAULT_PROMPT = (
    "top-down view of a stealth spy mobile game screenshot, portrait orientation, "
    "square tile grid floor, dark military base interior, "
    "one green agent character at bottom of grid, "
    "red enemy guards with vision cones, "
    "orange security cameras, red laser beams across corridors, "
    "three parallel paths with different obstacles, "
    "minimal HUD with alert meter at top and action points indicator, "
    "dark concrete and steel palette, high contrast, "
    "concept art, game UI mockup, clean digital illustration, "
    "professional game design document style"
)

DEFAULT_NEGATIVE = (
    "3d render, photorealistic, blurry, text, watermark, logo, "
    "first person, side view, landscape orientation, "
    "low quality, deformed, ugly"
)


# ── API helpers ────────────────────────────────────────────────────────────
def api_ready(api: str) -> bool:
    """Return True if the SD WebUI API is responding."""
    try:
        r = urllib.request.urlopen(f"{api}/sdapi/v1/sd-models", timeout=3)
        return r.status == 200
    except Exception:
        return False


def api_progress(api: str) -> dict:
    """Return the current generation progress dict."""
    try:
        r = urllib.request.urlopen(f"{api}/sdapi/v1/progress", timeout=3)
        return json.loads(r.read())
    except Exception:
        return {}


def launch_sd(api: str) -> None:
    """Start the SD WebUI in the background and block until it's ready."""
    if api_ready(api):
        print("✅  SD WebUI already running.")
        return

    if not SD_DIR.exists():
        print(f"❌  SD WebUI directory not found: {SD_DIR}")
        sys.exit(1)

    print("🚀  Starting SD WebUI … (this may take 2–5 minutes)")
    env = os.environ.copy()
    env["PATH"] = "/opt/homebrew/bin:" + env.get("PATH", "")
    log = open("/tmp/sd_webui.log", "w")
    subprocess.Popen(
        [
            "bash", "webui.sh",
            "--skip-torch-cuda-test", "--upcast-sampling",
            "--no-half-vae", "--use-cpu", "interrogate",
            "--disable-nan-check", "--api",
        ],
        cwd=str(SD_DIR),
        stdout=log, stderr=log,
        env=env,
        start_new_session=True,   # immune to terminal SIGHUP
    )

    for i in range(150):  # up to ~12 min
        if api_ready(api):
            print("✅  SD WebUI is ready!")
            return
        time.sleep(5)
        if i % 6 == 0:
            print(f"    still loading… ({i * 5}s)")

    print("❌  Timeout waiting for SD WebUI.")
    sys.exit(1)


def generate(
    api: str,
    prompt: str,
    negative: str,
    width: int,
    height: int,
    steps: int,
    cfg: float,
    seed: int,
) -> list:
    """Submit a txt2img request and return a list of base64-encoded images."""
    payload = json.dumps({
        "prompt": prompt,
        "negative_prompt": negative,
        "steps": steps,
        "cfg_scale": cfg,
        "width": width,
        "height": height,
        "seed": seed,
        "sampler_name": "Euler a",
    }).encode()

    req = urllib.request.Request(
        f"{api}/sdapi/v1/txt2img",
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    print(f"🎨  Generating ({width}×{height}, {steps} steps, cfg {cfg})…")
    t0 = time.time()
    resp = urllib.request.urlopen(req, timeout=900)   # 15 min max
    data = json.loads(resp.read())
    elapsed = time.time() - t0
    print(f"    done in {elapsed:.0f}s")
    return data["images"]


def save_images(images: list, prefix: str) -> list:
    """Decode base64 images and write them to OUT_DIR."""
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Find next available index to avoid overwriting
    existing = sorted(OUT_DIR.glob(f"{prefix}_*.png"))
    start = 1
    if existing:
        try:
            last_num = int(existing[-1].stem.rsplit("_", 1)[-1])
            start = last_num + 1
        except ValueError:
            pass

    paths = []
    for i, img_b64 in enumerate(images):
        p = OUT_DIR / f"{prefix}_{start + i}.png"
        p.write_bytes(base64.b64decode(img_b64))
        paths.append(p)
        print(f"    💾  {p.name}  ({p.stat().st_size / 1024:.0f} KB)")
    return paths


# ── CLI ────────────────────────────────────────────────────────────────────
def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Generate INFILTRAITOR concept art via SD WebUI API.",
    )
    p.add_argument("--prompt", default=DEFAULT_PROMPT, help="Image prompt")
    p.add_argument("--negative", default=DEFAULT_NEGATIVE, help="Negative prompt")
    p.add_argument("--width", type=int, default=512)
    p.add_argument("--height", type=int, default=768)
    p.add_argument("--steps", type=int, default=30)
    p.add_argument("--cfg", type=float, default=7.5)
    p.add_argument("--seed", type=int, default=-1)
    p.add_argument("--name", default="infiltraitor_concept", help="Filename prefix")
    p.add_argument("--no-launch", action="store_true",
                   help="Don't auto-launch SD WebUI")
    p.add_argument("--api", default=DEFAULT_API, help="SD WebUI base URL")
    return p.parse_args()


def main() -> None:
    args = parse_args()

    if not args.no_launch:
        launch_sd(args.api)
    elif not api_ready(args.api):
        print(f"❌  SD WebUI not running at {args.api} (use without --no-launch to auto-start)")
        sys.exit(1)

    images = generate(
        api=args.api,
        prompt=args.prompt,
        negative=args.negative,
        width=args.width,
        height=args.height,
        steps=args.steps,
        cfg=args.cfg,
        seed=args.seed,
    )
    paths = save_images(images, prefix=args.name)
    print(f"\n✅  {len(paths)} image(s) saved to: {OUT_DIR}")


if __name__ == "__main__":
    main()
