# RESUMO_SESSAO — 2026-08-04 (GENERIC DECALS — D33 shipped end to end, D33-SOOT-01)

**Continues:** `RESUMO_SESSAO_2026-08-03_D33_SPIKE.md` (D33 planned, Part 0
spike measured and — after a wrong kill and its retraction — declared
viable, nothing shipped yet).
**VERSION:** 0.9.88 at start → **0.9.89 at close.**
**Mode:** Solo mode.

---

## Executive summary

Everything D33 promised got built and shipped in one arc, then a real Director
bug report (soot missing on some weapon/material combinations) got fixed the
same session:

1. **Engine performance review** — measured whether camera rotation or the
   bake system was the real cost, and killed player-facing rotation
   (ROTATE-KILL-01) as the cheapest fix, which also solved D33's hardest open
   design point for free.
2. **D33 Parts 1–3d** — the full runtime decal compositor: cache, GDScript
   port of the Python projection math, and every impact-mark shape (full-voxel
   CRACKED, wall/floor/ceiling DENTED) composited live onto the real baked
   facade instead of losing it to a flat fallback.
3. **D33 Part 4 (4a/4b/4c)** — closed the risk that Part 3 only works with
   bake ON (the release canon is bake OFF): a new, material-agnostic
   procedural vector-mark system for the generic/flat path, then the actual
   `composites/` deletion (252 files + ~144 `MATERIALS` entries) once the
   generic path was proven to catch everything.
4. **D33-SOOT-01** — a same-session Director bug report (shotgun/metal,
   pistol/stone, pistol/metal render clean) traced to a real, generalizable
   gap and fixed with a small, non-propagating addition.

Three real bugs were caught and fixed before shipping, all by measuring
against real behaviour instead of assuming — see §3 and §4.

---

## 1. Engine performance review — ROTATE-KILL-01

Director's question: is destruction worth its cost, is rotation or the bake
system the real villain, does a 3D engine make more sense given the game is
pivoting to short infiltration waves over heavy combat? Measured, not
guessed: `_set_perspective()` (camera rotation) costs **1889.9 ms average with
bake ON, 1317.8 ms with bake OFF** — rotation dwarfs everything else, flat
regardless of damage or revisit.

**Decision, ratified:** kill camera rotation for the shipped player experience;
keep it as a dev tool behind `VisionController.dev_vision` (now **on by
default**, replacing "normal" mode). `PerspectivePad` only reaches
`_set_perspective()` through dev tooling now. Byproduct that mattered more
than the decision itself: `build_from_layout()` now runs **exactly once per
mission** for a player, which retroactively resolved D33's open "the cache
must outlive the room rebuild" problem — nothing rebuilds mid-session to
outlive.

Full record: `PROMPTS/ENGINE_PERFORMANCE_REVIEW.md`.

---

## 2. D33 Parts 1–3d — the baked-facade compositor

Built in the order: cache (`DamageCompositeCache`) → GDScript port of the
Python projection primitives (`DecalCompositor`, bit-exact `_paste_decal`
inverse-mapping) → the seam in `_set_voxel_cell()`, one shape at a time:

| Part | Shape | Status |
|---|---|---|
| 3a | Full-voxel CRACKED (bullet on the struck face, blast on all three) | ✅ |
| 3b | Half-voxel wall DENTED (bullet/blast, LEFT/RIGHT) | ✅ |
| 3c | Floor-sunk DENTED (zoned ground materials) | ✅ |
| 3d | Ceiling DENTED (silhouette carve, no decal — camera never sees it) | ✅ |

**A real bug shipped and was caught building 3b's own fixtures**: `V_WB`/`V_EB`
were mistyped `26` instead of `28` in `decal_compositor.gd` — Part 2's own
equality selftest never exercised the two targets (`FACE_SW`/`FACE_SE_MIRRORED`)
that reference those constants, a real, silent coverage gap in a passing
suite. Fixed, and the gap that let it through was closed in the same commit.

Every part proved against the real Python reference (equality selftests with
committed golden-fixture PNGs) before touching production code, plus a real
seam selftest and — where a live map scenario existed — a real capture.

---

## 3. D33 Part 4 — the generic/vector fallback, and composites/ deletion

**The risk caught before any deletion:** `bake_config.gd`'s own canon is
`enabled = false` at release. Every Part 3 branch is gated on bake being on,
so deleting `composites/` as originally scoped would have silently regressed
every damage mark to flat concrete the instant bake is off — undetected until
now because dev testing always runs bake ON. Presented to the Director as a
three-way choice; the Director picked "extend the live compositor to the
generic path too," **with a binding creative constraint**: a generic (flat,
unbaked) voxel must never wear the photographic decal art — only a
material-agnostic **vector** substitute, "condizente com o cenário low poly,"
"tentando ser um pouco mais caprichado."

**Part 4a** — 12 procedural vector-mark decals (`bullet_dented`,
`bullet_cracked`, `blast_dent`, `blast_crack` × 3 variants), authored flat on
the same 256×256 canvas the photographic family uses and projected through
the exact same `_paste_decal()` — a v1 prototype drew marks directly in the
final projected image and the Director caught it immediately ("os círculos
estão bem redondos, quando deveriam..."); reusing the real projection instead
of inventing new perspective math fixed it for free.

**Part 4b** — five new plan-parser/compositor pairs wired into
`_set_voxel_cell()`. Two real bugs caught by the new path's own seam suite
before shipping:
- An alpha=0 "cut" baked into the decal PNG did nothing against an opaque
  flat substrate — source-over blending only ever adds coverage, so it can
  never punch a hole through something already opaque. Fixed by applying the
  cut to the runtime **composite** instead (`punch_generic_alpha_hole`,
  mirrored Python↔GDScript).
- The half-voxel/floor compositors picked a decal variant from a `grid_pos`
  hash instead of the plan's own already-parsed variant, collapsing three
  variants onto one composite.
- A **real bake-OFF capture on PLAYGROUND** (not any selftest) showed
  `concrete_blast_cracked_all_0` resolving to `source_id -1` — the decal-family
  full-voxel CRACKED shapes had no generic branch at all. Closed by reusing
  `_full_voxel_decal_plan()` directly. Re-verified: zero fall-throughs to
  `composites/` across real detonations on all four test-zone materials.

**Part 4c** — `composites/` (252 files) deleted wholesale.
`VoxelRenderer.BASE_MATERIALS` trimmed from ~144 entries to the 13 real base
materials — more than the plan's own "97 generated entries" figure, since
that only counted the D32 decal-family names; the 33 older D22/D23/D25
hand-typed pseudo-materials needed removing too (confirmed every one
structurally unreachable at runtime, tracing every real caller, before
touching any of them). Removing them surfaced a real bug: `_decal_material()`
gated its composed name on `MATERIALS.has(composed)`, doing double duty as
both "does the asset exist" (obsolete) and "is this combination valid" (a
bullet can only strike a lateral face; only `IMPACT_CRACK_MATERIALS` may
blast-crack) — dropping the guard blindly let it construct nonsense like a
bullet mark on a horizontal face, caught immediately by
`voxel_decal_selftest.gd`'s own pre-existing tests, zero changes needed to
catch it. Fixed by making the validation explicit.

Evidence: real captures with BakeConfig ON and OFF, **both taken after the
actual `rm -rf composites/`**, both showing a real detonation's damage
rendering correctly.

---

## 4. D33-SOOT-01 — the Director's follow-up bug report

Same session, after D33 shipped: *"algumas armas... deixam tudo limpo.
Shotgun no metal cria os dents e marcas de bala, mas deixa tudo limpo. Pistola
na pedra e metal também."*

Root cause traced, not guessed: `derive_soot_rings()` only ever seeds its BFS
from `DESTROYED` voxels. Pistol/metal, pistol/stone and shotgun/metal
structurally never cross `PUNCH_DESTROY_MIN` given `RESISTANCE`'s current
values — they always land DENTED/CRACKED, never DESTROYED — so those
combinations never produced a hole to seed from. Generalizable, not
weapon/material-specific: any combo that never destroys a voxel has this same
gap.

`BlastCalculator.apply_self_soot()` adds one faint, non-propagating ring
(`SELF_SOOT_RING`, the lightest of three) directly on a damaged voxel's own
struck face, mirroring the same face-selection rules the decal system
already uses for the mark itself. Not a reversal of D17/D24's "a bullet marks
its impact, it does not blacken the wall" — the mark still never spreads to
neighbours, it just no longer looks pristine.

Verified: 7 new selftests (65/65 total in `blast_calculator_selftest.gd`).
Real captures via `INFILTRAITOR_CAPTURE_ACTION=weapon_fire` +
`INFILTRAITOR_FACE_SOOT_DIAG=1` on the real PLAYGROUND weapon bench: all
three reported combinations confirmed (shotgun/metal 0→9 sooted voxels,
pistol/metal 0→1, pistol/stone 0→1).

---

## 5. Documentation swept this close

- `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md` — full execution record, kept
  current through every part, including both wrong turns (§9/§10) and this
  session's real bugs.
- `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` — D33 and D24 ledger rows
  extended with the full arc.
- `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` — D17's soot note extended with
  D33-SOOT-01.
- `PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md` — status header extended.
- `ASSETS/ART_SPECIFICATIONS.md` §7 — rewritten for the retired `composites/`
  stage; new subsection documents the generic vector marks (explicitly:
  nothing here for the Director to author).
- `tools/persistent/ASSET_PIPELINE_QUICK_REFERENCE.md` — pipeline diagram and
  folder table corrected (`composites/` row removed).
- `ASSETS/ISOMETRIC/source_assets/voxels/README.md` — folder table and
  consumer list corrected.
- `docs/README.md` — DESTRUCTION_MASTER_PLAN's index entry extended.
- Swept for dangling references to `impact_decal_names()`/`IMPACT_ASSET_TEMPLATE`
  across `docs/`, `PROMPTS/`, `ASSETS/*.md`, `tools/persistent/*.md`,
  `CLAUDE.md` — none found outside the two docs that describe the retirement
  in past tense on purpose.

---

## 6. State at close

- **VERSION 0.9.89.**
- `project_lint` PASSED · `run_selftests` 28 clean / 0 failed ·
  `check_invariants` OK · `gen_codemap --check` clean — re-verified after
  every part, every fix, and the final doc sweep.
- `composites/` does not exist on disk. `VoxelRenderer.MATERIALS` holds only
  real base materials. `generate_voxel.py`'s composite-generation stage is
  gone; `materials/`/`halves/`/`decals/` generation intact.
- Player-facing camera rotation is gone; `dev_vision` is the default boot
  state.
- Evidence captures (non-`auto_`-named, survive the 50-file rotation):
  `d33_part4b_bake_off_generic_mark.png`,
  `d33_part4c_bake_{on,off}_post_composites_deletion.png`,
  `d33_soot01_shotgun_metal_self_soot.png`.

## 7. Next session starts here

D33 is closed — no open parts. D33-SOOT-01's fix is scoped to DENTED/CRACKED
self-soot only; if the Director wants a broader look at
`RESISTANCE`/`PUNCH_DESTROY_MIN` balance (why several common weapon/material
pairs never actually destroy), that is a separate, explicit ask — not
something this fix should be read as having already covered.
