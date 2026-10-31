"""tripo_detail_maps.py — the characters' GRAYSCALE detail maps (ACTOR D87 (2) / T3): one tileable 512 x 512 map per material, multiplied by
the palette colour in the shader (a mid grey ~0.8 keeps the colour; the map only modulates it). Procedural, ours, deterministic (seeded).
  cotton_poplin  the shirt: a fine plain weave            wool_twill  the trousers: a 2/2 twill, diagonal ribs
  silk_tie       the tie: a fine diagonal rep              leather     shoes, belt: a pebbled grain
  felt           the hat: soft fibrous noise               skin        head, hands: a faint pore noise
  hair           strands along V                           metal       buckle: brushed lines
Tileable by construction (every pattern is periodic over the tile; the noise is made periodic with a wrapped FFT filter).
Usage: python3 -I tripo_detail_maps.py <out_dir>
"""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]; N = 512
rng = np.random.default_rng(31)
y, x = np.mgrid[0:N, 0:N] / N                          # 0..1 over the tile


def pnoise(scale, seed):
    """periodic smooth noise: white noise low-passed in the frequency domain (wraps at the tile's edges)"""
    r = np.random.default_rng(seed); w = r.standard_normal((N, N))
    f = np.fft.fftfreq(N)[:, None] ** 2 + np.fft.fftfreq(N)[None, :] ** 2
    n = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-f * (scale ** 2))))
    return (n - n.mean()) / (n.std() + 1e-9)


def save(name, v, lo=0.62, hi=0.98):
    v = (v - v.min()) / (v.max() - v.min() + 1e-9)
    Image.fromarray((255 * (lo + (hi - lo) * v)).astype(np.uint8), "L").save(f"{OUT}/{name}.png")


k = 2 * np.pi
save("cotton_poplin", np.sin(k * 64 * x) * np.sin(k * 64 * y) * 0.6 + 0.25 * pnoise(40, 1))
save("wool_twill", np.sin(k * 48 * (x + y)) + 0.35 * np.sin(k * 96 * (x - y)) + 0.4 * pnoise(60, 2))
save("silk_tie", np.sin(k * 80 * (x - y)) * 0.8 + 0.15 * pnoise(30, 3), lo=0.72)
cells = pnoise(9, 4) + 0.5 * pnoise(4, 5)
save("leather", -np.abs(cells) + 0.3 * pnoise(2, 6))
save("felt", pnoise(3, 7) + 0.6 * pnoise(1.5, 8), lo=0.7)
save("skin", pnoise(2, 9) * 0.5 + pnoise(12, 10), lo=0.82)
save("hair", np.sin(k * 120 * x + 2 * pnoise(25, 12)) + 0.5 * pnoise(5, 13), lo=0.6)
save("metal", np.sin(k * 300 * y + 0.5 * pnoise(3, 14)) * 0.3 + pnoise(20, 15) * 0.2, lo=0.8)
print(f"[tripo_detail_maps] wrote 8 maps to {OUT}")
