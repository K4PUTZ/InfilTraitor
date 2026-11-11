# RESUMO_SESSAO — 2026-07-30/31 (DESTRUCTION VISUALS: BLAST MARKS, DERIVED SOOT, CARVED VOXELS, PER-FACE SHADING)

**Active master plans:** `DESTRUCTION_MASTER_PLAN.md` (D23–D25 added, §7 items 4/5/6
closed), `WEAPON_MASTER_PLAN.md` (S3 shipped, shotgun pellet bump),
`VOXEL_LIGHT_MASTER_PLAN.md` (FACE-READ-01 added; VL-D1 marked superseded).
**VERSION at session start:** 0.9.85
**VERSION at session end:** 0.9.85 (no bump — no Director-cleared checkpoint asked for)
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via direct
`INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

Four Director requests, each one landing and then immediately exposing the next
problem underneath it. The session's shape is that chain, not a list of features:

1. Grenades were leaving **round bullet holes** → blast damage got its own
   irregular texture family (**D23**).
2. Which then read as a **pinprick scatter** → the marks were widened so
   neighbouring picks merge (D23 amendment).
3. Which then revealed the marks were on the **wrong face** — a ceiling above a
   grenade stamping its outward top → DENTED became a **carved half-voxel**,
   oriented by where the blast came from (**D25**).
4. Which then revealed that the three faces of ANY voxel were never
   differentiated at all → **FACE-READ-01**, a per-face shader.

Soot was rebuilt underneath all of it (**D24**): derived fresh every repaint from
which voxels are absent, never stored.

**Two errors of mine are recorded below with their cost**, because both were
caught by measurement and both would otherwise repeat.

---

## Shipped

| ID | What | Commit |
|---|---|---|
| **D23** | Blast DENTED/CRACKED get their own irregular chip/crack family, never the bullet's round puncture. `Voxel.damage_is_blast` routes it. Amended same day: marks widened so the D22 ring scatter reads as blotches, not pinpricks. | `40f8120`, `8b2fe72` |
| **D24** | Soot DERIVED every repaint from currently-absent voxels. `Voxel.soot_ring` and `room._base_soot` deleted; `derive_soot_rings()` writes into a caller-supplied snapshot. Firearms and blasts share one mechanism. | `40f8120` |
| **D25** | DENTED is a **carved half-voxel** with a pre-baked broken face — 4 variants by which side the blast ate (bottom/top/left/right). Selection by blast geometry, not container role. Broken face is a decoupled, swappable asset. | `1489578` |
| **FACE-READ-01** | Per-face voxel shading via shader on every voxel `TileMapLayer`. Three faces never identical, on baked and non-baked paths alike. | `7f27e4f`, `a8d0b51` |
| — | `weapons/shotgun.json` `projectile_count` 8 → 24 (damage balance explicitly deferred to gameplay). | `40f8120` |

**Bugs found and fixed in passing:**
- `room._base_damage` stored only `damage_state`, so every rotation replayed
  `set_damage()` with default arguments and **silently reverted D23's blast marks
  to the bullet family**. Record is now `[damage_state, is_blast, base_dir]`.
- `generate_voxel.py` filled both side faces from one constant, contradicting its
  own docstring, which had specified "esquerda mais escura / direita mais clara"
  since the file was written.

---

## Two errors, and what they cost

**1. Reported a working shader as a UV-mapping bug, and reverted it.**
An intermediate capture showed a checkerboard; I diagnosed the atom-local UV
derivation as broken and backed the shader out. A debug build writing the
coordinate out as a red/green gradient (`auto_2026-07-31_22-57-30.png`) then
showed it restarting exactly once per atom on both tile paths — the mapping was
correct all along, and what I read as a tiling artefact was the effect working
per voxel at values far too strong to read as shading (I was looking at
`face_sw = 0.0` and `0.80`). **Cost: one revert plus one re-land.** The Director's
"use low values" suggestion is what exposed it. Lesson: when a visual change
looks wrong at an extreme test value, distinguish "the mechanism is broken" from
"the mechanism is working and the value is absurd" BEFORE reverting.

**2. Shipped a micro-variation term twice at the wrong magnitude.**
`micro_jitter_buckets` was added to break up merged blobs. First as a 10%
multiplier — measured to move 19% of crater pixels by a mean of 1.15/255 and to
*lower* the region's standard deviation; the quantisation ate it. Then as a ±1
bucket-index step — which landed, but erased the crater's soot rings (mean
luminance 41.1 → 26.6, mid-tone band 9% → 0%) and, stratified by brightness,
proved 6.7% strong in shadow against 4.1% in light: strongest exactly where the
Director then reported it as noise. **Retired to 0**, with all three measurements
attached to it in code. The structural finding is the durable part: **soot and
micro-variation compete for one quantised channel, and `bucket_luminance` is
compressed at its dark end (+67%/+65% per step vs +8% at the top), so stepping a
quantised index can never be perceptually micro in shadow.**

---

## Verification at session end

```
project_lint.py            ✅ 162 files, no real compile errors
check_invariants.py        ✅ no rule violations
gen_codemap.py --check     ✅ fresh
blast_calculator_selftest  41 PASS, 0 FAIL   (+6 this session)
voxel_light_incremental     5 PASS, 0 FAIL
4-view rotation capture    0 script errors
```

**Not verified, and it matters:** GPU frame-time cost of the added shader stage
**on device**. Headless forces the dummy driver and never rasterises, so this
cannot be measured from here — it needs a real mobile run
(`tools/persistent/MobileTesting.md`).

---

## Open, for the next session

1. **🔖 Per-FACE soot and light** — the Director's closing question. Blocker
   identified and the mechanism sketched (encode top/SE/SW in the modulate's
   R/G/B, shader picks one channel and applies it to all of RGB so nothing
   tints). Costs to weigh: the alternative-id space multiplies (~24 → 384–1536
   possible, mitigated by existing lazy minting), and it redefines what
   `modulate` means in `VOXEL_LIGHT_MASTER_PLAN` §3.4 — a canon change.
   **Director's call: spike and measure first.** Full detail in that plan's
   "OPEN — Per-FACE soot and light" section.
2. **Crack and bullet-mark mechanisms** — the Director said these get their own
   specs, analogous to D25's carved faces. Not started deliberately.
3. **`_top` (floor) carved variant is generated and wired but unreachable** —
   floors only ever DESTROY (`apply_crater_damage`), never dent.
4. **`flood_gu_rings()` / `flood_gu_cone()` are blind to `spec.blocks`** — they
   check only `blocked_edges`, so a grenade blast can propagate through a solid
   block the way the pellet walker did before its fix. Flagged 2026-07-30, still
   open, shared with the RADIAL path.
5. **A `SCRIPT ERROR` inside a selftest does not fail the suite** — observed when
   a broken call printed an error and the run still reported PASS with exit 0.
   Harness gap, not touched.

---

## Notes for whoever resumes

- The **atom art only feeds the non-baked path** (impact marks, D25 carved
  voxels, fallback). Measured: 0.25% of a real capture. Any change meant to be
  seen on ordinary walls has to go through the shader or the bake, not
  `generate_voxel.py`.
- The **broken face is deliberately decoupled** from material colour — one
  generic grey fracture serves every material, and
  `impact_marks/broken_face_<material>.png` overrides it with zero code changes.
  That is the Director's drop point for real art.
- `ASSETS/` is gitignored; every PNG above regenerates from
  `tools/asset_generation/generate_voxel.py`.
