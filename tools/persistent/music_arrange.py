#!/usr/bin/env python3
##
## music_arrange.py — build a context from ASSETS/AUDIO/MUSIC/arrangement.json: every line rendered on its own on the
## same 16th grid (drums in numpy, bass / arp / pad / lead through Surge XT presets), written as stems, then mixed.
## The notes are PLACEHOLDER phrases (A minor, 4-bar loop) until the Bible's motifs are authored.
##
##   .venv/bin/python tools/persistent/music_arrange.py <out_dir>
## then: music_pipeline.py register <context> <out_dir>/mix.wav --tool music_arrange.py+SurgeXT ...; stems <take> drums=... 
import json, sys
from pathlib import Path
import numpy as np, soundfile as sf
sys.path.insert(0, str(Path(__file__).parent))
import music_synth as ms

ROOT = Path(__file__).resolve().parents[2]
arr = json.loads((ROOT / "ASSETS/AUDIO/MUSIC/arrangement.json").read_text())
bible = json.loads((ROOT / "ASSETS/AUDIO/MUSIC/bible.json").read_text())
ctx = arr["context"]; bpm = bible["contexts"][ctx]["bpm"]; bars = arr["bars"]
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
SR = ms.SR; step = 60.0 / bpm / 4
N = int((bars * 16 * step + 2.0) * SR)

# 4-bar placeholder phrases, repeated; (step16, midi, length, velocity). Chords: Am - F - C - G.
ROOTS = [33, 29, 36, 31]  # A1 F1 C2 G1
def per_bar(f):
    return [n for b in range(bars) for n in f(b)]
bass = per_bar(lambda b: [(b * 16 + s, ROOTS[b % 4] + o, 2, 105) for s, o in zip(range(0, 16, 2), [0, 0, 12, 0, 0, 0, 12, 7])])
CH = [[57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62]]
arp = per_bar(lambda b: [(b * 16 + s, CH[b % 4][i % 3] + (12 if i % 4 == 3 else 0), 1, 90) for i, s in enumerate(range(16))])
pad = per_bar(lambda b: [(b * 16, n, 16, 80) for n in CH[b % 4]])
LEAD = [(0, 69, 3), (4, 72, 3), (8, 76, 6), (16, 74, 3), (20, 72, 3), (24, 69, 8), (32, 67, 3), (36, 72, 3), (40, 74, 6), (48, 72, 4), (52, 71, 4), (56, 69, 8)]
lead = [(b4 * 64 + s, n, ln, 100) for b4 in range(bars // 4) for s, n, ln in LEAD]

rng = np.random.default_rng(1)
def drums():
    buf = np.zeros(N)
    def put(t, s):
        i = int(t * SR); buf[i:i + len(s)] += s[:max(0, N - i)]
    tk = np.arange(int(0.35 * SR)) / SR
    kick = np.sin(2 * np.pi * (45 * tk + 90 * (1 - np.exp(-tk * 30)) / 30)) * np.exp(-tk * 9)
    th = np.arange(int(0.05 * SR)) / SR
    for s in range(bars * 16):
        if s % 4 == 0: put(s * step, kick * 0.9)
        if s % 2 == 1: put(s * step, rng.standard_normal(len(th)) * np.exp(-th * 90) * 0.25)
    return np.stack([buf, buf])

def fit(a):
    a = a[:, :N]
    return np.pad(a, ((0, 0), (0, N - a.shape[1])))

lines = {"drums": drums()}
for name, notes in (("bass", bass), ("arp", arp), ("pad", pad), ("lead", lead)):
    lines[name] = fit(ms.render(arr["presets"][name], notes, bpm, bars))
    print(f"[arrange] {name}: {arr['presets'][name]}")

mix = np.zeros((2, N))
for name, a in lines.items():
    start = int(arr["entries"][name] * 16 * step * SR)
    a = a.copy(); a[:, :start] = 0  # a line that enters later is silence before its bar, so every stem stays full-length
    a = a / max(float(np.abs(a).max()), 1e-6)  # level each stem, then the arrangement gains set the balance
    sf.write(out / f"{name}.wav", (a * 0.9).T, SR)
    mix += a * arr["gain"][name]
mix = np.tanh(mix * 0.9); mix = mix / np.abs(mix).max() * 0.9
sf.write(out / "mix.wav", mix.T, SR)
print(f"[arrange] {ctx} {bpm} BPM, {bars} bars -> {out}/mix.wav")
