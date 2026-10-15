"""pd.py — the same sheet solved with PROJECTIVE DYNAMICS (Bouaziz et al. 2014), implicit Euler.

Why not sheet.py (XPBD): a stiff BENDING term does not converge under a one-pass-per-substep Gauss-Seidel on a fine grid
(a clamped strip of 65 nodes came out 60x too soft). Bending energy 1/2 w |x[i-1] - 2 x[i] + x[i+1]|^2 is QUADRATIC in the
positions, so PD solves it exactly in the GLOBAL step: one fixed sparse matrix (inertia + all the springs), factored ONCE.
The only iteration left is the cheap LOCAL step that handles what is not linear (a length stays its rest length; a curvature
keeps its direction and its remembered size).

  local  : p_c = projection of constraint c  (stretch / shear: rest-length vector along the current direction;
                                              bend: r0 * lap/|lap|, r0 = the remembered curvature, 0 = flat)
  global : (M/dt^2 + sum w S^T S) x = M/dt^2 s_n + sum w S^T p       (s_n: inertial prediction incl. gravity)

Pinned nodes are eliminated (Dirichlet), so the matrix is over the free nodes only.
"""
import numpy as np
from scipy.linalg import cho_factor, cho_solve

G = 8.0


class PDSheet:
    def __init__(self, nx, nz, h, origin, lb, k_stretch=2e4, k_shear=40.0, yield_kappa=np.inf, drag=0.8,
                 dt=1.0 / 60.0, iters=6, floor_mu=0.6):
        self.nx, self.nz, self.h, self.n = nx, nz, h, nx * nz
        self.idx = np.arange(self.n).reshape(nx, nz)
        ox, oy, oz = origin
        ii, jj = np.meshgrid(np.arange(nx), np.arange(nz), indexing="ij")
        self.P = np.stack([ox + ii * h, np.full(ii.shape, float(oy)), oz + jj * h], axis=-1).reshape(-1, 3)
        self.P0 = self.P.copy()
        self.V = np.zeros_like(self.P)
        self.mass = h * h                       # rho = 1
        self.lb = lb
        self.B = G * lb ** 3
        self.k_stretch, self.k_shear = k_stretch, k_shear
        self.k_bend = self.B / (h * h)          # 1/2 (B/h^2) |lap|^2  ==  1/2 B theta^2 per joint
        self.yield_lap = h * h * yield_kappa      # |lap| = h^2 * curvature: the crease is a CURVATURE, not a per-node angle (resolution-independent)
        self.drag, self.dt, self.iters, self.floor_mu = drag, dt, iters, floor_mu
        self.pinned = np.zeros(self.n, bool)
        self.boxes = []
        self.t = 0.0
        self._edges()
        self.factor = None

    def _edges(self):
        nx, nz, idx = self.nx, self.nz, self.idx
        e_s, e_sh, tri = [], [], []
        for i in range(nx):
            for j in range(nz):
                if i + 1 < nx: e_s.append((idx[i, j], idx[i + 1, j]))
                if j + 1 < nz: e_s.append((idx[i, j], idx[i, j + 1]))
                if i + 1 < nx and j + 1 < nz:
                    e_sh.append((idx[i, j], idx[i + 1, j + 1]))
                    e_sh.append((idx[i + 1, j], idx[i, j + 1]))
                if i + 2 < nx: tri.append((idx[i, j], idx[i + 1, j], idx[i + 2, j]))
                if j + 2 < nz: tri.append((idx[i, j], idx[i, j + 1], idx[i, j + 2]))
        self.e_s = np.array(e_s, int).reshape(-1, 2)
        self.e_sh = np.array(e_sh, int).reshape(-1, 2)
        self.tri = np.array(tri, int).reshape(-1, 3)
        self.rest_s = np.linalg.norm(self.P0[self.e_s[:, 0]] - self.P0[self.e_s[:, 1]], axis=1)
        self.rest_sh = np.linalg.norm(self.P0[self.e_sh[:, 0]] - self.P0[self.e_sh[:, 1]], axis=1)
        self.r0 = np.zeros(len(self.tri))

    def pin(self, indices):
        self.pinned[np.asarray(indices)] = True
        self.factor = None

    def _build(self):
        n = self.n
        A = np.zeros((n, n))
        A[np.arange(n), np.arange(n)] += self.mass / self.dt ** 2
        for e, w in ((self.e_s, self.k_stretch), (self.e_sh, self.k_shear)):
            if len(e) and w > 0:
                a, b = e[:, 0], e[:, 1]
                np.add.at(A, (a, a), w); np.add.at(A, (b, b), w)
                np.add.at(A, (a, b), -w); np.add.at(A, (b, a), -w)
        if len(self.tri) and self.k_bend > 0:
            w = self.k_bend
            c = np.array([1.0, -2.0, 1.0])
            for r in range(3):
                for s in range(3):
                    np.add.at(A, (self.tri[:, r], self.tri[:, s]), w * c[r] * c[s])
        self.A = A
        self.free = np.where(~self.pinned)[0]
        self.fix = np.where(self.pinned)[0]
        self.Aff = A[np.ix_(self.free, self.free)]
        self.Afp = A[np.ix_(self.free, self.fix)]
        self.factor = cho_factor(self.Aff)

    def _rhs_springs(self, X):
        n = self.n
        R = np.zeros((n, 3))
        for e, rest, w in ((self.e_s, self.rest_s, self.k_stretch), (self.e_sh, self.rest_sh, self.k_shear)):
            if len(e) and w > 0:
                a, b = e[:, 0], e[:, 1]
                d = X[a] - X[b]
                l = np.linalg.norm(d, axis=1)
                p = w * (rest / np.maximum(l, 1e-12))[:, None] * d
                np.add.at(R, a, p); np.add.at(R, b, -p)
        if len(self.tri) and self.k_bend > 0 and np.any(self.r0 != 0.0):
            a, b, c = self.tri.T
            p = (self.r0[:, None] * self._normals(X)[b]) * self.k_bend    # remembered curvature: SIGNED, along the sheet's own normal
            np.add.at(R, a, p); np.add.at(R, b, -2.0 * p); np.add.at(R, c, p)
        return R

    def _normals(self, X):
        """Unit normal of the sheet at every node (central differences, one-sided on the border); +N = the side that faces DOWN while flat."""
        Pg = X.reshape(self.nx, self.nz, 3)
        dX = np.gradient(Pg, axis=0) if self.nx > 1 else np.zeros_like(Pg)
        dZ = np.gradient(Pg, axis=1) if self.nz > 1 else np.broadcast_to(np.array([0.0, 0.0, 1.0]), Pg.shape)
        N = np.cross(dX, dZ).reshape(-1, 3)
        return N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]

    def step(self):
        if self.factor is None:
            self._build()
        dt, m = self.dt, self.mass
        s = self.P + dt * self.V + dt * dt * np.array([0.0, -G, 0.0])
        s[self.pinned] = self.P[self.pinned]
        X = s.copy()
        xp = self.P[self.fix]
        for _ in range(self.iters):
            R = self._rhs_springs(X) + (m / dt ** 2) * s
            rhs = R[self.free] - self.Afp @ xp
            X[self.free] = cho_solve(self.factor, rhs)
        prev = self.P
        X = self._collide(X, prev)
        self.V = (X - prev) / dt
        self.V[self.pinned] = 0.0
        self.V *= np.exp(-self.drag * dt)
        self.P = X
        self._plastic()
        self.t += dt

    def _plastic(self):
        if not np.isfinite(self.yield_lap) or not len(self.tri):
            return
        a, b, c = self.tri.T
        cur = np.einsum("ij,ij->i", self.P[a] - 2.0 * self.P[b] + self.P[c], self._normals(self.P)[b])   # signed curvature now
        self.r0 = np.clip(self.r0, cur - self.yield_lap, cur + self.yield_lap)

    def _collide(self, X, prev):
        free = ~self.pinned
        under = free & (X[:, 1] < 0.01)
        if under.any():
            X[under, 1] = 0.01
            for k in (0, 2):
                X[under, k] += self.floor_mu * (prev[under, k] - X[under, k])
        for lo, hi in self.boxes:
            lo, hi = np.asarray(lo) - 0.02, np.asarray(hi) + 0.02
            inside = free & np.all((X > lo) & (X < hi), axis=1)
            if inside.any():
                q = X[inside]
                dist = np.concatenate([q - lo, hi - q], axis=1)
                f = np.argmin(dist, axis=1)
                for face in range(6):
                    mk = f == face
                    if mk.any():
                        q[mk, face % 3] = lo[face % 3] if face < 3 else hi[face % 3]
                X[inside] = q
        return X

    def advance(self, seconds):
        for _ in range(int(round(seconds / self.dt))):
            self.step()

    def grid(self):
        return self.P.reshape(self.nx, self.nz, 3)
