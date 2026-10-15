"""sheet.py — a sheet of cloth / cardboard as an XPBD particle grid (numpy). Research lab, not engine code.

One node per grid point (nx x nz), three families of constraints:
  * STRETCH  — distance between 4-neighbours (the sheet does not stretch: compliance alpha_s)
  * SHEAR    — distance on both diagonals (a woven cloth shears easily, cardboard does not: alpha_shear)
  * BEND     — |x[i-1] - 2 x[i] + x[i+1]| on rows and columns, a discrete curvature (h^2 * kappa).
               Energy 1/2 B theta^2 per joint  =>  compliance alpha_b = h^2 / B   (B = bending stiffness per unit width).
               Plasticity (cardboard creases): the rest curvature r0 follows the measured one once it is further than
               `yield_lap` from it (perfect plasticity: the restoring moment is capped at B*yield).

Units: GU, seconds. Areal density rho = 1, so a node's mass is h^2 and gravity g is the engine's 8.0 GU/s^2.
B is given through the ELASTOGRAVITY LENGTH  lb = (B / (rho g))^(1/3): the span at which a cantilever of that material
sags by a visible share of its own length (lb >> span: rigid plate, lb << span: it just hangs like cloth).
"""
import numpy as np

G = 8.0


class Sheet:
    def __init__(self, nx, nz, h, origin, lb, alpha_s=1e-5, alpha_shear=2e-3, yield_theta=np.inf,
                 drag=0.8, substeps=10, floor_mu=0.6):
        self.nx, self.nz, self.h = nx, nz, h
        self.n = nx * nz
        self.idx = np.arange(self.n).reshape(nx, nz)
        ox, oy, oz = origin
        ii, jj = np.meshgrid(np.arange(nx), np.arange(nz), indexing="ij")
        self.P = np.stack([ox + ii * h, np.full_like(ii, oy, dtype=float), oz + jj * h], axis=-1).reshape(-1, 3).astype(float)
        self.P0 = self.P.copy()
        self.V = np.zeros_like(self.P)
        self.mass = h * h
        self.W = np.full(self.n, 1.0 / self.mass)
        self.lb, self.alpha_s, self.alpha_shear = lb, alpha_s, alpha_shear
        self.B = G * lb ** 3                       # rho = 1
        self.alpha_b = h * h / self.B if self.B > 0 else 1e9
        self.yield_lap = h * yield_theta           # |lap| ~ h * theta
        self.drag = drag
        self.substeps = substeps
        self.floor_mu = floor_mu
        self.boxes = []                            # (lo, hi) axis-aligned colliders
        self.t = 0.0
        self._build()

    # ---- constraint groups (no two constraints of a group share a node, so a group solves in one vectorised pass)
    def _build(self):
        nx, nz, idx = self.nx, self.nz, self.idx
        self.stretch, self.shear, self.bend = [], [], []
        for p in (0, 1):
            ia = np.arange(p, nx - 1, 2)
            if len(ia):
                self.stretch.append((idx[ia, :].ravel(), idx[ia + 1, :].ravel()))
            ja = np.arange(p, nz - 1, 2)
            if len(ja):
                self.stretch.append((idx[:, ja].ravel(), idx[:, ja + 1].ravel()))
        for pi in (0, 1):
            for pj in (0, 1):
                ia, ja = np.arange(pi, nx - 1, 2), np.arange(pj, nz - 1, 2)
                if len(ia) and len(ja):
                    self.shear.append((idx[np.ix_(ia, ja)].ravel(), idx[np.ix_(ia + 1, ja + 1)].ravel()))
                    self.shear.append((idx[np.ix_(ia + 1, ja)].ravel(), idx[np.ix_(ia, ja + 1)].ravel()))
        for p in range(3):
            ia = np.arange(p, nx - 2, 3)
            if len(ia):
                self.bend.append((idx[ia, :].ravel(), idx[ia + 1, :].ravel(), idx[ia + 2, :].ravel()))
            ja = np.arange(p, nz - 2, 3)
            if len(ja):
                self.bend.append((idx[:, ja].ravel(), idx[:, ja + 1].ravel(), idx[:, ja + 2].ravel()))
        self.rest_s = [np.linalg.norm(self.P0[a] - self.P0[b], axis=1) for a, b in self.stretch]
        self.rest_sh = [np.linalg.norm(self.P0[a] - self.P0[b], axis=1) for a, b in self.shear]
        self.r0 = [np.zeros(len(a)) for a, b, c in self.bend]       # rest curvature (flat)

    def pin(self, mask_or_indices):
        self.W[np.asarray(mask_or_indices)] = 0.0

    @property
    def pinned(self):
        return self.W == 0.0

    # ---- one XPBD substep
    def _substep(self, dt):
        W, P = self.W, self.P
        free = (W > 0)[:, None]
        self.V += np.where(free, np.array([0.0, -G, 0.0]) * dt, 0.0)
        self.V *= np.exp(-self.drag * dt)
        prev = P.copy()
        P += np.where(free, self.V * dt, 0.0)
        a_s, a_sh, a_b = self.alpha_s / dt ** 2, self.alpha_shear / dt ** 2, self.alpha_b / dt ** 2
        for (a, b), rest in zip(self.stretch, self.rest_s):
            self._dist(a, b, rest, a_s)
        for (a, b), rest in zip(self.shear, self.rest_sh):
            self._dist(a, b, rest, a_sh)
        if self.B > 0:
            for (a, b, c), r0 in zip(self.bend, self.r0):
                self._bend(a, b, c, r0, a_b)
        self._collide(prev)
        self.V = np.where(free, (P - prev) / dt, 0.0)
        self._plastic()

    def _dist(self, a, b, rest, at):
        P, W = self.P, self.W
        d = P[a] - P[b]
        l = np.linalg.norm(d, axis=1)
        n = d / np.maximum(l, 1e-12)[:, None]
        w = W[a] + W[b]
        dl = -(l - rest) / (w + at)
        P[a] += (W[a] * dl)[:, None] * n
        P[b] -= (W[b] * dl)[:, None] * n

    def _bend(self, a, b, c, r0, at):
        P, W = self.P, self.W
        lap = P[a] - 2.0 * P[b] + P[c]
        l = np.linalg.norm(lap, axis=1)
        n = lap / np.maximum(l, 1e-12)[:, None]
        n[l < 1e-9] = 0.0
        w = W[a] + 4.0 * W[b] + W[c]
        dl = -(l - r0) / (w + at)
        P[a] += (W[a] * dl)[:, None] * n
        P[b] += (-2.0 * W[b] * dl)[:, None] * n
        P[c] += (W[c] * dl)[:, None] * n

    def _plastic(self):
        if not np.isfinite(self.yield_lap):
            return
        P = self.P
        for (a, b, c), r0 in zip(self.bend, self.r0):
            l = np.linalg.norm(P[a] - 2.0 * P[b] + P[c], axis=1)
            np.clip(r0, np.maximum(l - self.yield_lap, 0.0), l + self.yield_lap, out=r0)

    def _collide(self, prev):
        P, free = self.P, self.W > 0
        # floor y = 0 (cloth thickness margin 0.01), with a little friction
        under = free & (P[:, 1] < 0.01)
        if under.any():
            P[under, 1] = 0.01
            for k in (0, 2):
                P[under, k] += self.floor_mu * (prev[under, k] - P[under, k])
        for lo, hi in self.boxes:
            lo, hi = np.asarray(lo) - 0.02, np.asarray(hi) + 0.02
            inside = free & np.all((P > lo) & (P < hi), axis=1)
            if not inside.any():
                continue
            q = P[inside]
            dist = np.concatenate([q - lo, hi - q], axis=1)         # to the 3 low faces, then the 3 high faces
            f = np.argmin(dist, axis=1)
            for face in range(6):
                m = f == face
                if m.any():
                    axis = face % 3
                    q[m, axis] = lo[axis] if face < 3 else hi[axis]
            P[inside] = q

    def advance(self, seconds):
        dt = 1.0 / (60.0 * self.substeps)
        steps = int(round(seconds / dt))
        for _ in range(steps):
            self._substep(dt)
        self.t += seconds

    def grid(self):
        return self.P.reshape(self.nx, self.nz, 3)
