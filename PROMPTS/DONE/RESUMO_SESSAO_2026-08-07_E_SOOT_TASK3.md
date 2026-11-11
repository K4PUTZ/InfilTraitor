# RESUMO_SESSAO — 2026-08-07b (Task 3 / E-SOOT — blast-stamped soot, shipped)

**Continues:** `RESUMO_SESSAO_2026-08-07_E_RING_TASK2.md`, which closed with
Task 2 done and Task 3 as the next action.
**VERSION:** 0.9.90 (unchanged — no version bump requested).
**Commit:** `fdcb5e9` — `[E-SOOT] Task 3 — blast-stamped soot: directional
per-face stamp functions, closing the ring-3 derivation gap`.
**Mode:** Solo mode.

---

## What shipped

`EXPLOSION_REBUILD_MASTER_PLAN.md` Task 3 (E-SOOT): the real problem §5.2
states — `derive_soot_rings()` only ever seeds from currently-DESTROYED
voxels, so ring 3 (which destroys nothing under `frag_grenade.json`'s real
`destroy_ring_weights[3]=0.0`) can never get soot through derivation alone —
closed by two new functions that stamp soot directly from the blast's
`soot_ring_tones` table, independent of what got destroyed.

## A real design tension, resolved with the Director before any code was written

§5.1 as originally written proposed collapsing soot from **per-FACE** (a
voxel's 3 visible faces — top/SE/SW — independently tracked,
`FACE_SOOT_CODE_COUNT=125`) down to **per-VOXEL** (one shared tone, 5
codes), to save alt-id headroom. Reading the actual rendering code first
(not just the plan text) showed this would have silently retired two
already-shipped, tested systems the plan never mentioned:
**FACE-SOOT-01** (2026-08-01 — `encode_face_soot()`/`decode_face_soot()` in
`voxel_light_field.gd`, and `voxel_face_shading.gdshader`'s per-face
`soot_face_mult` uniform, applying a genuinely different multiplier per
face) and **self-soot/D33-SOOT-01** (2026-08-03 — `_self_soot_faces()`/
`apply_self_soot()`, 7 passing `SOOT-SELF-*` assertions proving a dent's own
faint soot lands only on its struck face).

Flagged via `AskUserQuestion` before writing a line of code. **The
Director's answer: the per-voxel collapse was a processing-cost concession
that no longer applies now that explosions are pre-baked, not
live-composited — keep full per-face directionality everywhere, and make
the new stamp genuinely directional too**, not a flat isotropic value. No
changes to `FACE_SOOT_CODE_COUNT`, the encode/decode functions, or the
shader — confirmed untouched by the final 31/31 selftest run, including
every pre-existing `SOOT-SELF-*`/`FACE-SOOT-*` assertion.

## What shipped, concretely

- **`BlastCalculator._vertical_ring_for(level_offset)`** — D14's spherical
  ring formula extracted out of `apply_container_damage()`'s inline body
  into a shared helper, so the new stamp reuses it textually. Pure
  extraction, verified behavior-preserving (unchanged selftest run).
- **`BlastCalculator._toward_for_carved_side(carved_side)`** — converts
  `carved_side_for()`'s VIEW-space answer into the `Vector3i` "toward"
  shape `_face_rings_for()` already consumes. Kept separate from
  `_self_soot_faces()` (a related but different question) so its 7 passing
  assertions stay untouched.
- **`BlastCalculator.stamp_container_soot()`** (walls/ceiling) — per voxel:
  ring via `_vertical_ring_for()` (same D14 formula
  `apply_container_damage()` uses), range-gated by `soot_ring_tones.size()`,
  tone looked up from that array, direction via `carved_side_for()` +
  `_toward_for_carved_side()`, delegates to the SAME `_face_rings_for()`
  `derive_soot_rings()` already uses for its strong/faint split. A ceiling
  underside (`is_roof=true`) is skipped entirely — never visible, mirroring
  `_self_soot_faces()`'s own BOTTOM rule.
- **`BlastCalculator.stamp_crater_soot()`** (floor) — extends
  `apply_crater_damage()`'s own `rim_span` unit into numbered rings past the
  crater proper: one `rim_span`-wide band per ring, boundary-inclusive to
  the CLOSER ring (`ceil`, not `floor` — see the bug below). Isotropic
  (`Vector3i(tone, CLEAN, CLEAN)`) since a floor voxel has exactly one
  visible face. **Assumption stated, open to one-line correction** (Task 2's
  own D1/D2 pattern): this banding is new, not separately specified by the
  Director — reasonable given rings apply uniformly in every direction
  (Q1b's spherical answer), flagged rather than silently invented.
- Both functions write into shared `out_snapshot`/`out_faces` dicts with
  min-wins semantics, composing with `derive_soot_rings()`'s output the same
  way `room._merge_soot_into()` already composes two independent passes.
- **No `room.gd` changes.** The right persistence unit for a stamped blast
  is the *event* (epicenter, rings, `is_roof`, `soot_ring_tones`), not its
  derived per-voxel output — `carved_side_for()` is screen-space and
  rotates, so caching a raw `Vector3i` across a view change would show soot
  on the wrong face (D25's own bug class). `room._crater_floor_soot` is the
  existing precedent: rebuilt from `_base_damage` every call, never trusted
  raw. Building the replay list is Task 5's job, alongside
  `detonate_active()`'s reconnection — the same split Task 2 established
  for `_gu_blast_count`.

## A real bug caught by hand-tracing the math, not by a failing test

While designing the ring-band selftest for `stamp_crater_soot()`, tracing
the exact boundary distances (`core_radius=5, max_radius=10, rim_span=5`)
against the first-draft `1 + floor((d - max_radius) / rim_span)` formula
showed `d=15` (exactly `max_radius + rim_span`) landing in ring 2, not ring
1 — inconsistent with every other `<=`-based band boundary
`apply_crater_damage()` itself uses (a boundary distance belongs to the
CLOSER ring everywhere else in that function). Fixed to
`ceil((d - max_radius) / rim_span)` in the source *before* the first test
run — not a red-before-green catch, since the buggy formula was never
executed against an assertion. All three boundary test points
(`d=10,15,20` → rings `0,1,2`) passed on the first real run after the fix.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 183 files, 0 errors.
- `run_selftests.py`: 31/31 clean. `blast_calculator_selftest.gd` gained 12
  new real assertions: ring-3 reached-and-stamped against the REAL
  `frag_grenade.json` via `BombRegistry` — not a hand-built array —
  epicenter-directional face split matching `(top=1,se=1,sw=0)` exactly,
  ceiling-underside skip, stamped/derived min-merge proven both directions
  on shared dicts, crater ring bands + isotropic output, out-of-range skip
  mirroring the existing `ring_multipliers` gate test. Every pre-existing
  assertion, including all 7 `SOOT-SELF-*` and the 3 `FACE-SOOT-*` tests,
  still passes unchanged.
- `check_invariants.py`: OK. `gen_codemap.py --check`: clean (184 scripts).
- No live capture — no live caller exists (`detonate_active()` confirmed
  still only hides the grenade sprite), same reasoning Task 2 established,
  deferred to Task 5's real wave driver.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0/1a/1b/2/3 done.
- **Task 4 (E-PLAN) is the next concrete action** — the `DetonationPlan`
  builder, first real (non-selftest) consumer of Task 3's stamp functions
  and Task 2's still-unread `smoke_ring_weights`.
- Explosive destruction is still a no-op end-to-end
  (`detonate_active()` not yet rewired — Task 5's job). Firearms unaffected,
  untouched this session.
- The per-voxel/per-face soot granularity question is **closed** — full
  per-face directionality stays everywhere, confirmed directly with the
  Director. Should not be reopened without a new reason.
- Pushed to `main` (pending — see next message).
