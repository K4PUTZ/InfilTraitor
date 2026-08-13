# RESUMO_SESSAO — 2026-08-13 (E-CONTRAST — floor decal shade, three attempts)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-13_EXPLOSION_REFINEMENT.md`
**VERSION:** 0.9.99 → **0.9.100**
**Commits:** 4 (`eb8e3698`, `a57732f7` since reverted, `406152a6`, plus this
doc-sweep commit).
**Plans touched:** `EXPLOSION_REBUILD_MASTER_PLAN` (new
`E-CONTRAST-01/02/03` section).

---

## The one-line version

A new session, opened by a screenshot: two-or-more overlapping explosions
leave some voxels reading suspiciously clean inside an otherwise blackened
crater. Two attempts targeted the soot system and were wrong — the first
harmless but pointless, the second a real regression caught from a live
capture — before the Director named the actual cause directly (baked decal
art, not soot) and the third attempt landed clean on a live playthrough.

---

## 1. Pending item from the previous session, closed first

`docs/production/current_state.md`'s header was still `0.9.98` after the
`01c41e0e` "ALPHA EXPLOSION REFINEMENT 0.9.99" session close (the AUTO block
edit never got committed), and its `pending_prompts` list was missing that
session's own RESUMO. Fixed and committed (`eb8e3698`) before anything else,
since it was sitting uncommitted in the working tree at session start.

---

## 2. The report, and the investigation that ruled out a soot bug

Director: *"O problema mais grave por enquanto é que duas explosões ou mais
criam voxels especiais sem nenhuma fuligem, que ficam muito claros... do
jeito que está parece defeito."* Asked to check this and verify pre-production
was solid before closing the explosion arc.

A headless probe against the real PLAYGROUND map (mirroring
`detonation_plan_selftest.gd`'s own scaffold) threw two frag grenades at
nearby-but-not-identical GUs, painted both fully via the choreographer's
`_apply_wave()`, then independently re-derived the "true" combined soot state
and diffed it against what was actually painted. First run: **399 voxels**
where the true ring said "should be scorched" but the tile showed clean.

Root cause, once traced: **the probe's own `ctx`**, copied from a
2026-08-07 selftest scaffold, was missing `blast_soot_rings`/
`weapon_soot_rings` — fields `test_zone_controller.gd`'s real
`_build_detonation_ctx()` already sets (a prior-session fix, its own comment
literally documents the gap this reproduced). Without them, `build_plan()`
silently fell back to its default of 4 rings instead of the room's real
4+2=6. Fixing the probe's ctx to match production dropped the mismatch count
to **0 across 1217 candidate voxels**. The soot BFS/merge/paint pipeline was
correct the entire time — the first "bug" found was in the investigation
tool, not the game. Live-reproduced via the project's own `grenade_second`
capture action (`INFILTRAITOR_CAPTURE_SECOND_OFFSET`), which turned out to
already exist for exactly this Director complaint from an earlier session.

---

## 3. E-CONTRAST-01 — real, but not the reported problem

Tuned `soot_face_mult`'s ring 3 (the blast-only feather PERF-02 B3-2 added)
from 0.84 to 0.75, mirrored into `VoxelLightField.soot_darkening[3]`. A real,
measured, pixel-diffable change — but the diff formed a thin RING at the
crater's outer slope, never touching the interior the screenshot pointed at.
**Reverted** once E-CONTRAST-03 landed, since it was solving a problem
nobody reported.

## 4. E-CONTRAST-02 — wrong mechanism, and a real regression

A ring histogram on the same real scene showed the bright interior blobs
already sitting at ring 0/1 — the darkest tones soot offers. Multiply can
scale a bright base texture but never flatten it, so no ring tuning closes
that gap. Built a second `ShaderMaterial` (floor layers only, `voxel_is_floor`
flag) that mixed the final colour toward a dark shade — real, floor-scoped,
covered the whole crater interior this time.

**Wrong on delivery.** Director, with an annotated before/after: *"você
pintou a borda da explosão que estava boa com feather e chapou tudo... os
voxels especiais clarinhos que precisavam ser escurecidos continuam
idênticos."* The flat mix amount applied to every ring including 3, flattening
S-FADE's own gradual feather into a plateau — a real regression, caught from
a real capture. Narrowing it (ring 3 = 0.0 shade) restored the feather, but
the Director's actual complaint — the DENTED/CRACKED decal zone — was
untouched, because it was never a soot-ring case. **Fully reverted** in
E-CONTRAST-03, not left in tuned-down: the whole mechanism (second material,
both uniforms) was the wrong tool.

## 5. E-CONTRAST-03 — the real fix, named by the Director directly

*"Esses voxels são os dented e cracked que a gente faz no baking system,
queimando os decals depois que as facades e slabs estão prontas. Como eles
tem uma arte diferente, acabam se destacando mais... Só precisamos diminuir
o brilho, ou aplicar um shade, na hora de fazer o bake dos voxels de chão,
que só podem ser afetados por explosão, já que armas não acertam o chão...
com exceção do cracked que também podem aparecer em paredes, mas não tem
problema se ficarem um pouco mais escuros."*

Shipped: `VoxelRenderer._composite_floor_sunk_decal()` (FLOOR DENTED,
floor-exclusive) and `_composite_full_voxel_decal()` (also the CRACKED-blast
atom D6 shares across FLOOR/WALL/CEILING from one composite) gained an
optional `shade_brightness` running `Image.adjust_bcs()` on the composited
decal before caching — default 1.0, a no-op, so every other caller (the live
D33 per-cell fallback included) is untouched. `DamageVariantBaker.
FLOOR_SHADE_BRIGHTNESS` (0.72) is fed in from the floor bake unconditionally
and from the shared CRACKED-blast bake exactly when it also serves FLOOR — a
condition (`also_floor`) the code already carried, so no new plumbing was
needed to scope it correctly. A new `DAMAGE_BAKE_LOCAL_VERSION`, independent
of `BakeCompositor.BAKE_CODE_VERSION`, invalidates only the on-disk damage-
atom cache — bumping the shared version would have forced every declared
material's full base bake to redo for a change that touches damage atoms
only.

Verified with the same real two-blast PLAYGROUND scene captured three times
(baseline, the E-CONTRAST-02 regression, the E-CONTRAST-03 fix): the outer
feather matches baseline again, and the block the Director's arrow pointed
at is visibly darker and no longer stands out. Director, after testing live:
*"Testei ao vivo, ficou bom, pode fechar a explosão."*

---

## 6. Verification

    project_lint.py          ✅ 204-205 files, 0 errors (every commit)
    check_invariants.py      ✅ OK
    gen_codemap.py --check   ✅ OK
    run_selftests.py         35/35 clean throughout

`damage_atom_bake_selftest.gd` exercises the exact bake path this session
changed, against real PLAYGROUND data. `voxel_face_separation_selftest.gd`
parses `voxel_face_shading.gdshader`'s own uniforms rather than a hand-copied
expectation, so it independently confirms the shader reverted cleanly.

Hand-named captures: `e_contrast02_floor_shade_after_2026-08-13.png` (kept
as the historical record of what the regression looked like — do not delete
as "wrong," it documents why the flat-mix approach was rejected),
`e_contrast03_floor_decal_bake_shade_2026-08-13.png` (the real fix).

---

## 7. What's still open, deliberately

Nothing from this session blocks anything else. Carried over unchanged from
the previous session's own §8:

1. `weapon_fire`'s repaint path has no deterministic pixel gate — flagged as
   its own task by `SOOT_MASTER_PLAN` §7.4. Director's own call this session:
   not worth closing — the shot only reads as a miss-splash against a wall
   the player wasn't aiming at, and gameplay itself stays fully deterministic.
2. SFX for the throw — still nobody's asked for it.
3. Junction column damage-texture orientation (`face_a`) — still a look
   detail, not blocking.
4. Junction columns + rotation-persistence — still untested, moot while
   rotation is off.
