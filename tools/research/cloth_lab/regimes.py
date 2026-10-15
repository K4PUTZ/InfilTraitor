"""regimes.py — ONE material, growing span: rigid plate -> the parabola -> a hanging curtain. A strip clamped on a 2 GU wall (its roof),
equilibrium profile (gravity only), elastic cardboard (lb 0.70) in blue, creasing cardboard in orange, canvas-cloth (lb 0.12) in grey."""
import numpy as np, os
from PIL import Image, ImageDraw
from pd import PDSheet
from render import font

OUT = os.environ.get("CLOTH_OUT", "out")
SPANS = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
LB = 0.70
NAMES = ['rigid plate: it barely moves', 'a diving board: slight curve', 'THE PARABOLA: a clean curve (cardboard)', 'the curve steepens', 'it gives way: hangs, bends only at the wall', 'a curtain with a knee at the wall']

def strip(L, lb, yk, n=65, seconds=9.0):
    h = L / (n - 1)
    s = PDSheet(n, 1, h, (0.0, 2.0, 0.0), lb, k_stretch=3000.0, k_shear=0.0, yield_kappa=yk, drag=5.0, iters=12)
    s.pin([0, 1])
    s.boxes = [((-1.0, 0.0, -1.0), (0.0, 2.0, 1.0))]      # the wall under the clamp
    s.advance(seconds)
    return s.P[:, [0, 1]].copy()

def main():
    os.makedirs(OUT, exist_ok=True)
    cols, rows = 3, 2
    cw, ch = 520, 330
    sheet = Image.new("RGB", (cols * cw, rows * ch), (22, 24, 28))
    X0, Y0, S = 70, 40, 85.0        # px per GU
    for k, L in enumerate(SPANS):
        panel = Image.new("RGB", (cw, ch), (24, 26, 30))
        d = ImageDraw.Draw(panel)
        def T(p): return (X0 + p[0] * S, ch - 40 - p[1] * S)
        d.line([T((-0.9, 0)), T((6.0, 0))], fill=(90, 92, 98), width=2)
        d.rectangle([T((-0.9, 2.0)), T((0.0, 0.0))], fill=(110, 112, 118))
        for lb, yt, col, wd in ((LB, np.inf, (110, 190, 255), 6), (LB, 1.2, (255, 160, 70), 3), (0.12, np.inf, (170, 170, 178), 2)):
            P = strip(L, lb, yt)
            d.line([T(p) for p in P], fill=col, width=wd)
        d.text((14, 10), f"span L = {L:.1f} GU   (L / lb = {L / LB:.1f})", fill=(225, 226, 232), font=font(16))
        d.text((14, 32), NAMES[k], fill=(150, 154, 164), font=font(14))
        sheet.paste(panel, ((k % cols) * cw, (k // cols) * ch))
    d = ImageDraw.Draw(sheet)
    d.text((12, rows * ch - 22), "blue = elastic cardboard (lb 0.70 GU)   orange = same, creasing (radius 0.83 GU)   grey = canvas cloth (lb 0.12 GU)", fill=(200, 202, 210), font=font(14))
    sheet.save(os.path.join(OUT, "regimes.png"))
    print("saved")

if __name__ == "__main__":
    main()
