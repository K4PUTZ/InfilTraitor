# Session summary — 2026-09-24 — RENDER3D R3D-8 to R3D-13 built; R3D-END waits for the Director

**Resume point:** R3D-8 .. R3D-13 are built and gated (`8e757cb1` .. `d5810de5`). **R3D-END is NOT started: it needs the Director's ratification** on the deletion
list (`RENDER3D_MASTER_PLAN` §R3D-END and the v1.21 block). Open before it: the Galaxy A16 baseline row (the phone was not attached), the two plane findings below, the
face-SE reference captures, and `check_decal.py` on 3D.

## What changed (full detail and evidence: `RENDER3D_MASTER_PLAN` v1.21)
- **R3D-8** selftests run on the 3D board (they never had: `--script` suites have no `DevFlags` autoload) with 18 suites pinned to 2D and the reason each; 3D coverage for the blast
  hooks (`board_probe gate`), the crack/pile mirrors (`mirror_gate.py`), a pixel gate earned (`pixel_gate.py`); the 21-voxel loss on rotation / SaveState restore FIXED
  (per-claim base damage, `SaveState` v3) with `board_probe.py roundtrip`; the 2D reference set (`build_reference_set.py` -> `ARCHIVE/`, git-ignored).
- **R3D-9** `BoardLook` owns the look constants; cracks are records; piles from data; the Room's dev aids on the 3D ground; `_count_2d_cells` gone.
- **R3D-10** the plan resolves no tile on 3D (Moto: PACKAGE 175-374 -> 110-138 ms). **R3D-11** gameplay reads `GroundGrid.has_cell` and nothing writes the floor layer
  (Moto digests identical to the desktop). **R3D-12** the load builds no bake (Moto 46 -> 16 s, PSS 2.2 -> 1.0 GB).
- **R3D-13** 20 comparison flags deleted (each its own commit); `CELL_PROBE` reads the store; facade behaviour on 3D measured; the spike deletion list written; the Moto baseline
  recorded (3D vs 2D: load 16 vs 54 s, idle ~19 vs ~54 ms/frame).

## Traps this session found (all recorded where they bite)
- A `set --` in zsh does not word-split: a device flag became `RENDER3D=1 a` and the game silently ran the 2D board. Check `[BOARD3D]` in the log before trusting a 3D row.
- A `&&` chain committed after a failing gate; a `git checkout HEAD -- godot tools` reverted an uncommitted tool edit. Gate on the exit status, commit deliberately.
- `pixel_gate.py` fails above 8/255, not on strict zero (a GLASS jitter between boots, source unknown), masks two real-mouse artefacts, and must run with no other Godot alive.
- `shot_3d_gate.py`'s concrete wall band reads ~3 200 or ~3 600 px with the same code; the threshold is 100 px, do not chase it.

## Open, not fixed
- After a rotation or a restore the light plane differs from the post-blast one (PLAYGROUND ~3 100-3 350 texels; the blast's incremental light vs a full relight), and GLASS has 261 soot
  texels on visible CRACKED glass (`_soot_map` holds tone 0, the live wave never painted it). `board_probe.py roundtrip --strict-planes` fails on both.
- The SE face of the reference set (three attempts, in `build_reference_set.py`'s header). The voxel atoms + TileSet stay until the glass authority leaves the tile layers.
