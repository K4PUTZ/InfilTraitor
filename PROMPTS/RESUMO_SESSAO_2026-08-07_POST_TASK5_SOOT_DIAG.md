# RESUMO_SESSAO — 2026-08-07e (Post-Task-5 — "fuligem quebradiça" diagnosed, not fixed)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-07_E_WAVE_TASK5.md`, which
closed with Task 5 done and Task 6 (tuning pass) as the next action.
**VERSION:** 0.9.90 (unchanged).
**Commit:** pending (see next message).
**Mode:** Solo mode.

---

## What happened

The Director looked at a real capture (a manual Shift+P shot, not
`e_wave_detonation.png`) and reported the crater's scorch reads as
"quebradiça e irregular" (brittle/fragmented) instead of one uniform shade
per face. This session investigated the cause — it did **not** ship a fix,
by design: the four candidate root causes each imply a different, real
change (data tuning, art, reversing a ratified decision, or a shader
philosophy change), so the right next step is the Director choosing a
lever, not a guess landing in the code.

## Investigation, not guessing

Four candidates were identified by reading the actual render chain:
1. The new blast-stamped soot (`stamp_container_soot()`/
   `stamp_crater_soot()`, Task 3/4) rendering non-uniformly.
2. `MaterialResistanceTable.dent_factor`-driven DENTED density in the
   crater rim — each voxel independently draws one of the floor's own
   dent decals.
3. The floor dent decal art itself (`decal_dent_earth_0/1/2.png`) —
   viewed directly, these are inherently noisy, mottled crumbled-earth
   textures, authored for D22/D23, predating this whole rebuild.
4. D3's per-cell random substrate-crop selection (deliberate, "so
   neighbouring damaged voxels rarely show the same piece of facade")
   adding further tiling variety on top.

**Isolated candidate 1 with a real A/B capture, not reasoning about the
shader's math.** Added a diagnostic toggle
(`DetonationPlanBuilder.build_plan()`'s `ctx["stamp_soot_enabled"]`,
default `true`; `TestZoneController` reads
`INFILTRAITOR_DISABLE_STAMP_SOOT=1` to flip it for a manual capture only)
that skips ONLY `stamp_container_soot()`/`stamp_crater_soot()` —
`derive_soot_rings()`/`apply_self_soot()` (the pre-existing derivation
path) keep running unchanged either way, so this isolates exactly the
blast's own authored stamp from everything else.

Two captures at the identical GU (metal wall, index 1):
`Screenshots/history/soot_stamp_on.png` / `soot_stamp_off.png`.
Pixel-diffed directly (`PIL`/`numpy`, not eyeballed): **3.3% of pixels
differ by more than 5/255, mean diff 0.76/255** — visually near-identical,
same "quebradiça" pattern in both.

**Conclusion: candidate 1 (this rebuild's own soot stamp) is not the
cause.** Its real, measured contribution is a small extra darkening at
the crater's outer edge (ring 3 — exactly the gap Task 3 closed: soot
reaching a ring that destroys nothing) and nothing more. Candidates 2/3/4
— all pre-existing, none touched this session — are where the texture
actually comes from.

## What shipped, concretely

- **`DetonationPlanBuilder.build_plan()`** gained `ctx["stamp_soot_enabled"]`
  (default `true`, byte-identical to before it existed), guarding the three
  `stamp_container_soot()`/`stamp_crater_soot()` call sites.
- **`TestZoneController._build_detonation_ctx()`** reads
  `INFILTRAITOR_DISABLE_STAMP_SOOT=1` to set it false — diagnostic-only,
  never set outside a manual capture.
- Kept in the code (not reverted) — a real, cheap, reusable seam for the
  next A/B comparison, not a one-off hack.

## Four options put to the Director, none chosen

Recorded in `EXPLOSION_REBUILD_MASTER_PLAN.md`'s new Post-Task-5 note and
§11 point 2, for whoever picks up Task 6:
1. Tighten crater-rim dent density (`dent_factor`/rim-span data tweak).
2. Replace the dent decal art (art work, not code — not something this
   session can produce).
3. Disable D3's per-cell substrate randomization (reverses a ratified
   decision — ask before building).
4. Change `voxel_face_shading.gdshader` from a pure multiply
   (`COLOR.rgb * f`) to a flatter blend toward a solid soot tone — a real
   shader-philosophy change; the shader's own header comment currently
   states multiply-only is deliberate ("this shader only decides how much
   darker one face is than another, never absolute brightness").

## Verification

- `project_lint.py` clean.
- Full selftest/invariant/codemap sweep re-run clean (no selftest exercises
  the new toggle directly — it's a manual-capture-only diagnostic seam, not
  a shipped behavior change, so nothing new needed asserting).

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0 through Task 5
  done, this session added a diagnosed-but-unresolved visual item.
- **Task 6 (the tuning pass) is still the next concrete action** — now with
  a concrete, evidence-backed decision to make about the soot/dent texture,
  not just the ring-weight numbers.
- Pushed to `main` (pending — see next message).
