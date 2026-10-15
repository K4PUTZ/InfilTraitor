"""convergence.py — how coarse can the simulation grid be before the shape lies? Settled shape of the awning at N nodes per side
(dt 1/30, 6 PD iterations: what the engine could afford) against the fine reference (N=33, dt 1/60, 12 iterations), compared by
bicubic-upsampling the coarse grid to 33x33 and taking the RMS and the worst node distance (GU)."""
import numpy as np, sys
from scipy.interpolate import RectBivariateSpline
import run_awning as ra
from pd import PDSheet

def settle(name, n, dt, iters, seconds=6.0):
    ra.N = n; ra.H = 4.0 / (n - 1)
    sc = ra.SCENARIOS[name]
    s = ra.PDSheet(n, n, ra.H, (15.0, 2.0, 6.0), sc["lb"], k_stretch=3000.0, k_shear=sc["ksh"], yield_kappa=sc["yk"], drag=sc["drag"], dt=dt, iters=iters)
    idx = s.idx
    pins = list(idx[0, :]) + [idx[i, 0] for i in range(1, int(round(3.0 / ra.H)) + 1)]
    if sc["post"]:
        pins += [idx[i, j] for i in range(n - 2, n) for j in range(n - 2, n)] if n < 17 else [idx[i, j] for i in range(n - 3, n) for j in range(n - 3, n)]
    s.pin(pins); s.boxes = list(ra.WALLS)
    for _ in range(int(round(seconds / dt))):
        s.step()
    return s.grid().copy()

def upsample(g, m=33):
    n = g.shape[0]
    u = np.linspace(0, 1, n); v = np.linspace(0, 1, m)
    out = np.zeros((m, m, 3))
    for c in range(3):
        sp = RectBivariateSpline(u, u, g[..., c], kx=3, ky=3)
        out[..., c] = sp(v, v)
    return out

for name in sys.argv[1:]:
    ref = settle(name, 33, 1 / 60, 12)
    print(f"== {name}: reference N=33 settled; lowest y {ref[..., 1].min():.3f}, mean y {ref[..., 1].mean():.3f}")
    for n in (9, 13, 17):
        for dt, it in ((1 / 30, 6),):
            g = settle(name, n, dt, it)
            up = upsample(g)
            d = np.linalg.norm(up - ref, axis=2)
            print(f"   N={n:2d} dt=1/{int(round(1/dt))} iters={it}: RMS {np.sqrt((d**2).mean()):.3f} GU   worst {d.max():.3f} GU   mean-y {g[...,1].mean():.3f}")
