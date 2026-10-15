# cloth_lab — how a roof of cloth or cardboard bends under its own weight

Research for ROOF_MASTER_PLAN v0.28 (Director, 2026-10-15: "estudar melhor como funciona a animação de tecidos e de semi-rígidos").
NOT engine code: a numpy model, an analytic validation, the ROOF_LAB room B awning under gravity only, and a GDScript cost benchmark.
The renders are PIL (a z-buffer rasteriser at the game's 30 deg / 45 deg camera), not Godot and not Blender: they show the physics, not the look.

## The model (one picture: `figures/mechanism.png`)
A sheet is a grid of nodes (one per voxel in the study, 33 x 33 for a 4 GU roof). Three springs, one regime each:

| Spring | Energy | What it gives |
|---|---|---|
| stretch (4-neighbours) | length kept at rest length | the sheet does not stretch (k 3000 = ~1% strain under its own weight) |
| shear (both diagonals) | length kept | cloth: soft (k 60), cardboard: stiff (k 1500) |
| bend (3 nodes in a row) | `1/2 (B/h^2) |a - 2b + c|^2`, B = g * lb^3 | cardboard resists curving; cloth almost not |

`lb` is the **elastogravity length**, `(B / weight-per-area)^(1/3)`: the span at which a strip of the material sags a lot. Everything
follows from `L / lb`: far below 1 the sheet is a rigid plate, near 1-3 it is a clean parabola-like curve (a diving board), far above 3 it
hangs like a curtain and bends only at its support (`figures/regimes.png`). Canvas cloth ~ 0.12 GU, corrugated cardboard ~ 0.7 GU
(1 GU ~ 1.05 m). The CREASE (cardboard only) is plasticity: the bend's rest curvature follows the measured one once it is further than
`yield_kappa` from it (perfect plasticity, signed along the sheet's own normal), so the restoring moment is capped and a fold keeps its shape.

## Why Projective Dynamics (pd.py) and not XPBD (sheet.py)
`sheet.py` is XPBD, one Gauss-Seidel pass per substep: right for the catenary (a hanging cloth, +0.4% sag) and WRONG for bending: a clamped
strip of 65 nodes came out 60x too soft (`validate.py` prints the failure: 2000-65000% off the analytic beam). A stiff bend term does not
converge under local passes on a fine grid. The bend energy is quadratic in the positions, so PD solves it exactly in a GLOBAL linear step
(one fixed banded matrix, factored once) and iterates only the cheap local projections. Traps found: the stretch weight LOCKS the
iteration above ~1e4 (`validate_pd.py` prints the table); the plastic memory must be SIGNED (an isotropic magnitude zig-zags into pleats).

## Gates (python3 validate_pd.py)
cantilever vs the exact discrete beam: +6.5% / +2.5% / +1.0% at 9 / 17 / 33 nodes; catenary vs analytic: +1.2 to +1.5% (the stretch).

## Scenes (python3 run_awning.py <fabric|fabric_post|cardboard|cardboard_post|cardboard_elastic> 6)
ROOF_LAB room B's roof (gu 15..19 x 6..10, 2 GU up), pinned on the west edge and the north edge to x = 18, free east and south, with or
without a pinned corner patch (the post). Settled: fabric lies on the floor at the free corner (12% of the nodes), with the post it is a
pouch 1.03 GU above the floor; cardboard (lb 0.7, crease at radius 0.83 GU) stays nearly flat near the walls and folds along ONE crease
line, the tip hanging; with the post a gentle dish (lowest 1.55 GU).

## Cost (bench_pd.gd.txt: copy to a .gd, `godot --headless --path . --script <it>`; desktop editor binary, GDScript, banded Cholesky, 6 PD iterations, dt 1/30)
N=7: 2.0 ms | N=9: 4.1 ms | N=11: 7.3 ms | N=13: 11.6 ms | N=17: 24.9 ms per step; the 33 x 33 voxel grid would be ~0.5 s per step (not feasible in GDScript).
Coarse grid vs the N=33 reference, bicubic-upsampled: N=13 RMS 0.06-0.10 GU (under one voxel), worst 0.19-0.20; N=9 RMS 0.10-0.18, worst 0.34-0.36.
The Moto g04s factor is NOT measured (estimate 4-5x slower: owed).
