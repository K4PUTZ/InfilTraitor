"""Two analytic gates for sheet.py: the catenary (stretch + gravity, no bending) and the cantilever (bending + gravity)."""
import numpy as np
from sheet import Sheet, G

def catenary_sag(L, D):
    lo, hi = 1e-4, 1e4
    for _ in range(200):                       # solve 2 a sinh(D / 2a) = L
        a = 0.5 * (lo + hi)
        if 2 * a * np.sinh(D / (2 * a)) > L: lo = a
        else: hi = a
    return a * np.cosh(D / (2 * a)) - a

def chain(n, L, lb, **kw):
    h = L / (n - 1)
    s = Sheet(n, 1, h, (0, 10.0, 0), lb, **kw)       # 10 GU above the sim's floor
    return s

if __name__ == "__main__":
    print("== catenary: chain of 4.0 GU hung between two pins 3.2 GU apart (no bending)")
    for n in (17, 33, 65):
        s = chain(n, 4.0, 0.0, drag=4.0, alpha_s=1e-7)
        s.pin([0, n - 1])
        s.P[:, 0] = np.linspace(0, 3.2, n)
        s.advance(8.0)
        sag = 10.0 - s.P[:, 1].min()
        ref = catenary_sag(4.0, 3.2)
        print(f"  n={n:3d}: sim sag {sag:.4f}  analytic {ref:.4f}  error {100*(sag-ref)/ref:+.2f}%  (length kept {np.sum(np.linalg.norm(np.diff(s.P,axis=0),axis=1)):.4f})")

    print("== cantilever: tip deflection  d = g L^4 / (8 B) = L^4 / (8 lb^3)  (clamped chain, small deflection)")
    for L_over_lb in (0.25, 0.5, 0.75):
        lb = 1.0
        n = 65
        L = L_over_lb * lb
        s = chain(n, L, lb, drag=6.0, alpha_s=1e-7)
        s.pin([0, 1])                              # clamp: position and slope
        s.advance(10.0)
        h = L / (n - 1)
        Leff = L - h
        d_sim = -(s.P[-1, 1] - s.P[0, 1])
        d_ref = Leff ** 4 / (8 * lb ** 3)
        print(f"  L/lb={L_over_lb:4.2f}: sim {d_sim:.6f}  analytic {d_ref:.6f}  error {100*(d_sim-d_ref)/d_ref:+.2f}%")
