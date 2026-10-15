"""validate_pd.py — the two analytic gates for pd.py (Projective Dynamics), and the trap that nearly shipped.

  1. CATENARY   a 4.0 GU chain hung between two pins 3.2 GU apart (stretch + gravity, no bending): sag against 2 a sinh(D / 2a) = L.
  2. CANTILEVER a strip clamped at one end, small load: tip deflection against the EXACT DISCRETE beam (a linear solve of the same
                energy, so the comparison separates solver error from discretisation error) and against the continuum g L^4 / (8 B).
  3. THE TRAP   the stretch weight. With k_stretch 1e6 the local-global iteration LOCKS: the strip came out 10x too soft after 200
                iterations. k_stretch ~3000 (about 1% strain under the roof's own weight) converges in 12.

Run: python3 validate_pd.py      (the XPBD attempt that failed gate 2 by 2000-65000% is validate.py)
"""
import numpy as np
from pd import PDSheet, G
from validate import catenary_sag


def exact_cantilever(n, L, lb):
    h = L / (n - 1)
    B = G * lb ** 3
    D = np.zeros((n - 2, n))
    for r in range(n - 2):
        D[r, r], D[r, r + 1], D[r, r + 2] = 1, -2, 1
    K = (B / h ** 2) * D.T @ D
    f = np.full(n, G * h * h)
    fr = np.arange(2, n)
    y = np.zeros(n)
    y[fr] = -np.linalg.solve(K[np.ix_(fr, fr)], f[fr])
    return -y[-1]


def cantilever(n, L, lb, k_stretch, iters, dt=1.0 / 60.0, one_step=False):
    s = PDSheet(n, 1, L / (n - 1), (0, 10.0, 0), lb, k_stretch=k_stretch, drag=6.0, iters=iters, dt=dt)
    s.pin([0, 1])
    if one_step:
        s.step()                  # one implicit step of dt 1 s from rest: a static solve
    else:
        s.advance(5.0)
    return -(s.P[-1, 1] - s.P[0, 1])


def catenary(n, k_stretch, iters):
    s = PDSheet(n, 1, 4.0 / (n - 1), (0, 10.0, 0), 0.0, k_stretch=k_stretch, drag=3.0, iters=iters)
    s.pin([0, n - 1])
    s.P[:, 0] = np.linspace(0, 3.2, n)
    s.advance(8.0)
    return 10.0 - s.P[:, 1].min()


if __name__ == "__main__":
    print("== the trap: static cantilever (L = 0.5 lb), 9 nodes, tip drop vs the exact discrete beam %.5f" % exact_cantilever(9, 0.5, 1.0))
    for ks in (1e2, 1e3, 1e4, 1e5):
        row = []
        for it in (5, 20, 100):
            row.append("%d it: %.5f" % (it, cantilever(9, 0.5, 1.0, ks, it, dt=1.0, one_step=True)))
        print("   k_stretch %7.0f | %s" % (ks, " | ".join(row)))
    print("== gates at the engine's setting (k_stretch 3000, 12 iterations, dt 1/60)")
    for n in (9, 17, 33):
        d, ex = cantilever(n, 0.5, 1.0, 3000.0, 12), exact_cantilever(n, 0.5, 1.0)
        print("   cantilever n=%2d: sim %.5f  exact discrete %.5f  (%+.1f%%)" % (n, d, ex, 100 * (d - ex) / ex))
    ref = catenary_sag(4.0, 3.2)
    for n in (17, 33, 65):
        sag = catenary(n, 3000.0, 12)
        print("   catenary  n=%2d: sim %.4f  analytic %.4f  (%+.1f%%)" % (n, sag, ref, 100 * (sag - ref) / ref))
