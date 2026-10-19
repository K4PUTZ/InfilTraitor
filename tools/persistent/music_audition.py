#!/usr/bin/env python3
##
## music_audition.py — hear one line (bass, arp, pad, lead) through many Surge XT presets, to choose timbres.
## Every preset plays the SAME 2-bar phrase (A minor, Bible tempo); the files are numbered, and the console prints the
## numbered list so "number 7" is enough to pick. Also writes <category>_all.wav (all presets back to back).
##
##   .venv/bin/python tools/persistent/music_audition.py bass|arp|pad|lead [--n 12] [--seed 1] [--bpm 124] [--out DIR]
##   afplay <out>/bass_all.wav     |     the pick goes into ASSETS/AUDIO/MUSIC/arrangement.json
import json, random, sys
from pathlib import Path
import numpy as np, soundfile as sf
sys.path.insert(0, str(Path(__file__).parent))
import music_synth as ms

A = sys.argv[1:]
line = A[0] if A else sys.exit(__doc__)
arg = lambda k, d: type(d)(A[A.index(k) + 1]) if k in A else d
n, seed, bpm = arg("--n", 12), arg("--seed", 1), arg("--bpm", 124)
out = Path(arg("--out", "/Users/mateus/ace/audition")); out.mkdir(parents=True, exist_ok=True)
CATS = {"bass": ["Basses"], "arp": ["Sequences", "Plucks"], "pad": ["Pads"], "lead": ["Leads"]}
# A minor phrases on the 16th grid: (step, midi, length, velocity)
PHR = {
    "bass": [(s, m, 2, 105) for s, m in zip(range(0, 32, 2), [33, 33, 45, 33, 33, 43, 33, 31] * 2)],
    "arp": [(s, m, 1, 90) for s, m in zip(range(32), [57, 60, 64, 69, 64, 60, 57, 60] * 4)],
    "pad": [(0, 57, 16, 80), (0, 60, 16, 80), (0, 64, 16, 80), (16, 55, 16, 80), (16, 59, 16, 80), (16, 62, 16, 80)],
    "lead": [(0, 69, 4, 100), (4, 72, 4, 100), (8, 76, 6, 100), (16, 74, 4, 100), (20, 72, 4, 100), (24, 69, 8, 100)],
}[line]
pool = sorted(p for c in CATS[line] for p in ms.PATCHES.joinpath(c).glob("*.fxp"))
random.Random(seed).shuffle(pool)
gap = np.zeros((2, int(0.6 * ms.SR)))
allv, listing = [], []
for i, p in enumerate(pool[:n], 1):
    name = str(p.relative_to(ms.PATCHES).with_suffix(""))
    a = ms.render(name, PHR, bpm, 2, tail=1.5)
    peak = max(float(np.abs(a).max()), 1e-6)
    a = a / peak * 0.8  # level-matched so loudness does not bias the choice
    sf.write(out / f"{line}_{i:02d}_{p.stem.replace(' ', '_')}.wav", a.T, ms.SR)
    allv += [a, gap]
    listing.append(f"{i:2d}. {name}")
sf.write(out / f"{line}_all.wav", np.concatenate(allv, axis=1).T, ms.SR)
print("\n".join(listing)); print(f"[audition] {out}/{line}_all.wav ({len(listing)} presets in this order)")
