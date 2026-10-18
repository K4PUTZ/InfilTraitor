#!/usr/bin/env python3
##
## music_beat.py — renders a basic placeholder beat from the Music Bible (no AI model needed), to prove the
## pipeline end to end: bible tempo/key -> wav -> `music_pipeline.py register` -> `export` -> play.
## Not the theme: no motif is used (they are still `pending`). Needs the project .venv (numpy, soundfile).
##
##   .venv/bin/python tools/persistent/music_beat.py [context] [out.wav] [--bars 8] [--stems]
import json, sys
from pathlib import Path
import numpy as np
import soundfile as sf

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
bible = json.loads((ROOT / "ASSETS/AUDIO/MUSIC/bible.json").read_text())
args = [a for a in sys.argv[1:] if not a.startswith("--")]
ctx = args[0] if args else "infiltration"
out = args[1] if len(args) > 1 else "beat.wav"
bars = int(sys.argv[sys.argv.index("--bars") + 1]) if "--bars" in sys.argv else 8
if "--bars" in sys.argv:
    args = [a for a in args if a != str(bars)]
bpm = bible["contexts"][ctx]["bpm"]
step = 60.0 / bpm / 4  # 16th note
n = int(bars * 16 * step * SR) + SR
LAYERS = {k: np.zeros(n) for k in ("drums", "bass", "arp")}  # one buffer per stem, all on the same 16th-note grid
rng = np.random.default_rng(1)


def put(t, s, layer):
    i = int(t * SR)
    LAYERS[layer][i:i + len(s)] += s[:max(0, n - i)]


def kick():
    t = np.arange(int(0.35 * SR)) / SR
    return np.sin(2 * np.pi * (45 * t + 90 * (1 - np.exp(-t * 30)) / 30)) * np.exp(-t * 9)


def hat():
    t = np.arange(int(0.05 * SR)) / SR
    return rng.standard_normal(len(t)) * np.exp(-t * 90) * 0.25


def synth(f, dur, saw=True):
    t = np.arange(int(dur * SR)) / SR
    w = 2 * ((t * f) % 1.0) - 1 if saw else np.sin(2 * np.pi * f * t)
    return w * np.exp(-t * 7) * np.minimum(1, t * 400)


A = 55.0  # A1; A minor
bass_semis = [0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 12, 0, 7, 0, 10, 0]
arp = [0, 3, 7, 12, 7, 3, 0, 3]
for s in range(bars * 16):
    t = s * step
    if s % 4 == 0:
        put(t, kick() * 0.9, 'drums')
    if s % 2 == 1:
        put(t, hat(), 'drums')
    put(t, synth(A * 2 ** (bass_semis[s % 16] / 12), step * 1.8) * 0.28, 'bass')
    if s >= 16:  # arp enters after the first bar
        put(t, synth(A * 8 * 2 ** (arp[s % 8] / 12), step * 1.5) * 0.08, 'arp')
def finish(b):
    b = np.tanh(b * 1.4)
    return b / max(np.max(np.abs(b)), 1e-9) * 0.9


mix = sum(LAYERS.values())
sf.write(out, finish(mix), SR)
if "--stems" in sys.argv:  # stems share the mix's length and grid: sample-aligned by construction
    for name, b in LAYERS.items():
        sf.write(str(Path(out).with_suffix("")) + f"_{name}.wav", np.tanh(b * 1.4) * 0.9, SR)
print(f"[beat] {ctx}: {bpm} BPM, A minor (draft), {bars} bars -> {out}" + (" + stems" if "--stems" in sys.argv else ""))
