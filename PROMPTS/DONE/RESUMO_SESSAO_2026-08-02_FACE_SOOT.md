# RESUMO_SESSAO — 2026-08-02 (FACE-SOOT-01: PER-FACE SOOT SHIPPED, THE SEPARATION GUARANTEE MADE UNCONDITIONAL)

**Active master plans:** `VOXEL_LIGHT_MASTER_PLAN.md` (FACE-SOOT-01 and
FACE-READ-03 added; the per-FACE soot open item CLOSED, per-FACE light re-scoped
with a ratified design), `DESTRUCTION_MASTER_PLAN.md` (D24 amended).
**VERSION at session start:** 0.9.86
**VERSION at session end:** 0.9.86 — **deliberately not bumped.** The Director
asked to close and push; a version bump + `verified/` tag is the separate
"push with tag" signal and was not given.
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via direct
`INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

One feature, taken end to end: **soot is now derived and rendered per FACE**,
which was the last open piece of the destruction visual system. The Director's
instruction was to weigh image/physics quality against mobile viability and
implement — so the design decisions are recorded here with the measurements that
drove them, not just the outcome.

The through-line of the session is that **the mechanism the master plan had
recorded as "the mechanism that would work" does not work**, and that was
established by measurement before any code was written. Two further defects were
found the same way: per-face soot silently broke the FACE-READ-02 guarantee, and
a naive calibration would have silently darkened every crater in the game.

---

## Shipped

| ID | What | Commit |
|---|---|---|
| **FACE-SOOT-01** | Soot derived per visible face (`derive_soot_rings()` → `out_faces`), carried in `TileData.modulate`'s ALPHA as a 6-bit code, applied by the shader. Soot left the light bucket, because one bucket is one scalar per cell and three faces need three values. | `f4edcc2` |
| **FACE-READ-03** | The "never two identical faces" guarantee rebuilt on residue classes mod 3, replacing `face_min_sep`. Unconditional — retires FACE-READ-02's "above 2/255" caveat. | `f4edcc2` |
| **Per-face light design ratified** | The merged 12-level per-face darkening index recorded as the path, with the ceiling arithmetic corrected. Design only — nothing built. | (this session's doc commit) |

---

## Three things that were only right because they were measured

**1. The master plan's proposed mechanism was built on a false premise.** It
proposed packing three per-face brightnesses into `modulate`'s R/G/B, stating
that "the modulate never tints, it stays a grayscale multiply." It is not one.
On the baked path (`BakeConfig.enabled` is `true`, the live default) the pages
are grayscale by B2 and **the material's colour is exactly what those three
channels carry** — `BakeCompositor._modulate_for_mode()` returns
`material.base_color` under MULTIPLY. On the material path the colour is in the
texture instead, so a channel splat flattens it. Either way, packing luminances
into RGB destroys material colour. Shipped on ALPHA instead, which is free since
OCC-21 and leaves both colour paths untouched.

**2. Per-face soot broke the FACE-READ-02 guarantee, and the selftest caught it
rather than a capture.** `face_min_sep` subtracted 1/255 per face INDEX, which
separates faces only while they are already ordered top ≥ SE ≥ SW. Directional
soot inverts that order — a top face at ring 0 is darker than an SE face at ring
1 — and the fixed offset can then land two faces on the same 8-bit value.
Measured over the real canon grid: a pair collapsing at **24/255**, a plainly
visible mid-tone. Replaced with residue classes mod 3 (top ≡ 0, SE ≡ 1, SW ≡ 2),
rounding down so nothing clips. Two different residues cannot be equal.

**3. The obvious calibration would have darkened every crater in the game.**
Soot used to be quantised through `bucket_luminance`, whose dark end is
non-linear: a fully lit ring-0 voxel computed `1.00 × 0.20 = 0.20`, which
**rounded to bucket 2 and rendered at 0.33**, not 0.20. Reusing
`soot_darkening`'s nominal `[0.20, 0.40, 0.63]` in the shader would therefore
have been a silent, global darkening. `soot_face_mult` ships at
`[0.33, 0.47, 0.69, 1.0]` — the values the old path *effectively* produced.

**The pattern all three share:** the nominal value in the table was not the
value on screen. Reading the real consumer, not the declared intent, is what
caught each one.

---

## Evidence

Real map, not a fixture — the standing lesson from the floor-dent work:

```
PLAYGROUND detonation   1606 sooted voxels, 1124 (70.0%) with faces that differ
  rotated to view E     1603 voxels, 68.9% — SE/SW histograms SWAP, as a 90°
                        rotation of screen-space faces must
weapon bench (D24)      74 voxels, 66.2% directional — bullets get it for free
face separation         0 / 967 680 collapses over all 64 per-face ring combos
  teeth-check (off)     301 712 / 967 680 collapse, worst visible 110/255
blast_calculator        51 PASS, 0 FAIL (+3 this session)
run_selftests.py        19 clean, 0 failed
project_lint.py         163 files, no real compile errors
check_invariants.py     no rule violations
gen_codemap.py --check  fresh
minting                 31 298 clean → 32 771 post-detonation (+1473, <5%)
```

Captures: `auto_2026-08-01_01-59-43.png` (view N), `auto_2026-08-01_02-01-02.png`
(rotated E), `auto_2026-08-01_02-10-32.png` (firearm). **Material colours
verified intact in all three** — the failure the rejected RGB packing would have
caused.

**One substitution, declared rather than hidden.** A full A/B of minting cost
against HEAD was attempted in a detached git worktree and did not complete: the
generated PNGs are gitignored, so a fresh worktree has none and the import never
finishes. Substituted an exact structural check instead — the pre-change encoder
was transcribed and compared against the new one: **24 distinct alternative ids
both ways, every unflipped id identical**. So a clean map's minting count is the
same before and after by construction, which is stronger than a re-measurement.

---

## Canon added this session

**The alternative-id ceiling is real, PER TILE, and applies to every scenery
voxel.** Probed in-engine, not assumed:
- `create_alternative_tile(4095)` creates and round-trips through
  `set_cell()`/`get_cell_alternative_tile()`; `id = 5000` is decomposed into
  `4096 | 904` and `has_alternative_tile()` returns **false** — never created.
- The same id value exists independently on two tiles of one source, so this is
  never a scene-wide budget. It bounds how many distinct states ONE TILE can
  express, and since the id encodes the whole per-cell state it applies to clean
  voxels as much as sooted ones.
- Occupancy today: **1536 of 4096.**

**Per-face LIGHT — design ratified, nothing built.** An earlier note claimed
three independent per-face buckets blow the ceiling. Re-checked: 12³ × 2 =
**3456, which fits**. What blows it is per-face light *plus* soot as a separate
axis (221 184). So the ratified path is to merge them into **one per-face
darkening index with 12 levels** — the shader applies one multiplier per face
and does not need to know whether the darkening came from shadow or scorch. The
recorded cost is the recalibration: `bucket_luminance` and `soot_face_mult` are
tuned independently today and would have to become one measured ramp.

---

## Open, for the next session

1. **Bullet destruction — `LINE` is the next mechanic**, and it is what the
   Director named for after this. `apply_point_impact()` (D28) already exists on
   the receiving end; the missing piece is the shape itself. Five weapons
   declare `LINE` and loud-fail when fired (D11). Specified in
   `WEAPON_MASTER_PLAN.md` Part 3b, with no remaining structural blockers — S1,
   S2, S7 and S10 are all closed. Its step axis is **penetration**, not
   distance, which is why it is a sibling of `flood_gu_cone()` and not a variant.
2. **Per-face LIGHT** — design ratified above, implementation deliberately not
   started (*"vamos trabalhar melhor isso depois"*).
3. **GPU frame-time of the shader stage ON DEVICE** — still unverified, carried
   forward unchanged across three sessions now. Headless forces the dummy driver
   and never rasterises. FACE-SOOT-01 adds one texture sample (a texel already in
   cache), one divide and a few ALU ops to a stage that already existed, so it
   does not change the shape of that question — but it does not answer it either.
   Needs `tools/persistent/MobileTesting.md`.
4. **`bake_selftest`'s teardown segfault** — still tolerated by the runner, still
   not diagnosed. Unchanged from the previous session.
5. **`project.godot`'s `config/version` is `0.1.0-pre-alpha`** while `VERSION`
   says 0.9.86. Unchanged, still nobody's decision.

---

## Notes for whoever resumes

- **`soot_darkening` no longer reaches the renderer.** It is the canonical
  reference curve that `soot_face_mult` is calibrated against, and what
  `soot_factor()` still reports to probes and vision modes. Retuning it alone
  now changes nothing on screen — the shader uniform is the live knob.
- **`INFILTRAITOR_FACE_SOOT_DIAG=1`** prints, on every light-field rebuild, the
  sooted-voxel count, how many are directional, the per-face ring histogram and
  the minted-alternative total. It is how every number in this document about the
  real map was obtained; use it rather than reasoning about whether the feature
  fires.
- **A clean voxel's tile is bit-identical to the pre-FACE-SOOT-01 one** (soot
  code 63 → alpha exactly 1.0). That is deliberate and load-bearing: it is what
  keeps a map with no destruction minting exactly what it minted before.
- The shader **overwrites `COLOR.a` with the texture's own alpha**, because alpha
  carries data now and not transparency. Grepped before shipping: nothing fades
  or tweens a voxel `TileMapLayer`'s modulate alpha, and `FLOOR_DEPTH_DIM` sets
  `Color(d, d, d, 1.0)`. If anything ever needs to fade a voxel layer, it cannot
  do it through layer alpha without teaching the shader about it first.
- `ASSETS/` is gitignored; every PNG regenerates from
  `tools/asset_generation/generate_voxel.py`. This is also why a detached
  worktree cannot be used for an A/B without regenerating them first.
