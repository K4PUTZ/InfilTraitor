# RESUMO_SESSAO — 2026-08-08/09 (Alpha Explosion Waves)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-08_E_EARTH_D35.md`, which closed with
D34/D35 landed and the explosion's own tuning pass (Task 6) still untouched.
**VERSION:** 0.9.92 → **0.9.93**.
**Commits:** `a681af0`, `fde80ce`, `d5f5e59`, `8dab214`, `2c35ec0`, `b9ed121`,
`d654149`, `04bfed1`, plus this session's closing version bump.
**Mode:** Solo mode.

---

## What happened, in order

Eight Director passes, each one a real capture away from the last. The
through-line: **every conclusion this session came from measuring the running
game, and three of them inverted what the code or the reasoning said.**

### 1. Soot stamp off, and a census that could see (`a681af0`, E-DENT-01)

Director: *"vamos apagar o stamp de fuligem por enquanto."* Flipped at the live
caller (`TestZoneController`), not deleted — `build_plan()`'s own default stays
`true`, so the calculation layer and its selftests did not move and the whole
reversal is one boolean (`INFILTRAITOR_ENABLE_STAMP_SOOT=1` restores it).
`derive_soot_rings()`/`apply_self_soot()` untouched.

Same commit added `[E-PLAN] census`: one line per (surface, material) a blast
actually reached, with destroyed/dented/cracked counts and how many dent/crack
tiles came from the pre-bake. `[E-WAVE]`'s per-wave counts blended
floor/wall/ceiling into one number — exactly what hid *"69 dents on a fixture,
zero on PLAYGROUND"* the first time.

**The census immediately found the real gap:** `FLOOR/cracked` was **0 on every
material, on every blast**. Not data — structure.

### 2. The floor learns to crack (`fde80ce`, E-CRACK-01)

Three layers had to move, and only the first was where anyone would have looked:

1. `apply_crater_damage()` had **no crack roll at all**. `_roll_floor_dent()`
   became `_roll_floor_surface_damage()`, offering each surviving voxel DENTED
   first and CRACKED only if the dent passed it over — the Director's own
   severity ladder, and the same D22 pool order `apply_container_damage()` uses
   on a wall. Three independent hash salts. The two tiers fall off over different
   spans, so the ladder reads spatially as well as per voxel. The bomb's ring
   tables now reach the floor, so floor and wall read the same authored numbers.
2. `floor_damage_material()` needed **nothing** — D34/E-SEAM-02 had already made
   it material-real. The baker's header claim to the contrary was stale and is
   corrected.
3. `DamageVariantBaker` registers the universal CRACKED-blast atom under
   `"FLOOR"` for floor materials with `crack_factor > 0` — the registration D6
   already does for `"CEILING"`, same composite, no re-compositing.

Tuning done on the **bomb** and the crater radius, never on
`MaterialResistanceTable` — that table is shared with firearms, so every row
moved there silently retunes shotgun and sniper damage. One row moved anyway and
deliberately: **wood `dent_factor` 0.03 → 0.2**, because at 0.03 a wood floor
that lost 137 voxels showed 7 dents.

**A tuning attempt was reverted by a capture, not by review.** Setting
`crack_ring_weights[0]` to 0.45 put isolated bright full-voxel cubes standing in
the crater — CRACKED is a 3-face composite while DENTED is a half-voxel carve, so
a cracked floor voxel with destroyed neighbours renders as a whole block.
**§4.2's "cracked never in ring 0" is load-bearing, not cosmetic.**

### 3. Faster waves, per-voxel smoke (`d5f5e59`, E-SMOKE-01)

Cadence 40 ms → 20 ms. Smoke went from **one puff per flooded GU to one per
damaged voxel — 22 → 465** on a real blast, each puff the product of its damage
tier, its ring weight, and a per-cell hash, with separate salts for size and
duration.

Two visual iterations, both driven by a capture: the first pass measured
*invisible* (1.1% of pixels at mean delta 12/255 — dark grey over an
already-sooted crater); the second overshot into hard-edged discs. **Per-voxel
smoke inverts the economics the per-GU model was tuned for — density comes from
OVERLAP now**, so alpha dropped 0.8 → 0.2.

### 4. Fireball, flash, shake (`8dab214`, `2c35ec0`, E-FLASH-01/02)

The authored 4-frame animation, a white flash frame, and a camera shake on
`Camera2D.offset` (never `position`, which is leashed and drag-owned).
Deliberately not `randf()`-seeded: this project verifies visual work by
pixel-diffing two captures of the same event.

Director's polish pass found a real one by feel: *"o primeiro flash frame me
pareceu que demorou um pouco... talvez precise de um pré-load."* **Measured:
44.94 ms** of PNG decode inside the first detonation's own frame.

### 5. The "engasgada" — measured, and it was neither hypothesis (`b9ed121`)

Director suspected the white being slow, or persistence of vision. Per-frame
instrumentation:

```
[ANIM-DIAG] dt=16.7ms  frame=3          ← the animation runs clean
[E-WAVE]    wave 1/15 destroy ring=0 cells=872 apply=15.951ms
[ANIM-DIAG] dt=150.0ms flash_t=0.017    ← the frame the flash starts on
```

**The frame the flash lands on costs 150 ms** against 8-17 ms for its
neighbours, because it is the same frame that applies destroy ring 0. The white
was not slow; the frame was. Fixed the compounding half (the fade was advancing
by that same 150 ms delta and burning half its curve in one step) and shipped
continuous cross-faded in-between frames plus a switchable negative flash.

### 6. Pacing by work, not by wave table (`d654149`, E-ORGANIC-01)

Director freed the 15-wave table. The first attempt — a flat per-frame cell
budget — **made every frame look cheap in the log and the blast 3-20× slower**:

| budget | total | apply/frame |
|---|---|---|
| all 2072 in one frame | **26 ms** | 24.3 ms |
| 600 cells/frame | 509 ms | 4.4 ms |
| 160 cells/frame | 496 ms | 2.2 ms |
| 60 cells/frame | 485 ms | 0.9 ms |

**A frame costs ~120 ms whether it writes 60 cells or 600.** The cost is Godot
rebuilding dirtied `TileMapLayer`s — once per FRAME, not once per cell. Shipped a
deadline with catch-up at cell granularity instead: **261 ms**, organic pacing at
no wall-clock cost.

### 7. An expanding front, and no imported art (`04bfed1`, E-RADIAL-01/E-NATIVE-01)

Director: *"as waves estão duras, parece que entram em soquinhos por categoria...
seria possível granularizar por voxels, expandindo a partir do centro?"*

Structural, not pacing: WAVE_TABLE order means all destruction, then all dents,
then all cracks. Every plan entry now carries its **radius from the epicentre**
and the queue sorts by that. Categories interleave on their own because that is
physically where each one is. **171 category switches against ~15 before.**

The authored fireball is gone (three rounds of tuning an imported sprite never
fixed a style mismatch). The blast's core is `Room.spawn_blast_burst()` — four
calls to `EmberOverlay`/`SmokeSparkOverlay`/`DebrisOverlay`, overlays that already
existed. Not a particle system: `GPUParticles2D` would stand up a second parallel
VFX vocabulary beside one that already reads correctly.

The negative flash shipped and surfaced an ordering bug on arrival: it sat ABOVE
ember/smoke, so it **inverted the blast's own warm embers to blue**. The world is
what gets blown out; the fire is doing the blowing out.

---

## Three selftests rewritten, none relaxed

Each of these asserted something the code deliberately stopped doing. Replaced
with the new contract rather than loosened — the distinction matters and is
recorded in each test's own comment:

- `detonation_plan_selftest` test 5 demanded `duration == scale ==
  smoke_ring_weights[ring]` exactly, provable only while smoke was a flat per-GU
  descriptor. Now: the gate holds, size stays inside its ring envelope, lifetime
  inside a global one (the duration floor decoupled the two on purpose), and
  puffs within a ring genuinely differ.
- `detonation_choreographer_selftest` test 2 checked `waves_due_now()`, then
  checked WAVE_TABLE ordering. Both gone. Now: nothing dropped, the front expands
  monotonically, categories interleave (the assertion that fails the moment the
  ordering reverts), the queue ends at the widest radius, and four properties of
  the deadline rule.
- `blast_calculator_selftest` gained three tests for the floor's crack tier
  (byte-compat without weights, band/ladder rules on the real `frag_grenade.json`,
  D32.6 on the floor, prevalence by subset).

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 191 files, 0 errors — every commit this session.
- `run_selftests.py`: 33/33 clean throughout, with 3 new tests in
  `blast_calculator_selftest` and 2 rewritten suites (above).
- `check_invariants.py` / `gen_codemap.py --check`: clean throughout.
- Real PLAYGROUND captures at every step, several pixel-diffed rather than
  eyeballed. Hand-named (rotation-proof): `e_dent_stamp_on_stone.png` /
  `e_dent_stamp_off_stone.png`, `e_crack_floor_{concrete,metal,stone,wood}.png`,
  `e_crack_ring0_artifact.png`, `e_smoke_per_voxel_{stone,metal}.png`,
  `e_smoke_hard_discs_rejected.png`, `e_flash_{fireball,white_frame,smoke_rise,
  fireball_blend,smoke_lingers,interp_midframe,negative_mode}.png`,
  `e_native_{flash_core,burst,smoke_core}.png`.

## Standing caveat on every performance number here

They come from the off-screen capture harness (`auto_screenshot.py`), which
renders a detonation at **~8 fps**. The ~120 ms per-frame constant is certainly
much smaller on a real windowed run. **The SHAPE of that finding (per-frame, not
per-cell) is what to trust; the constant is not.** The harness also cannot
demonstrate the smooth case — at ~8 fps the deadline quota jumps to 100% on the
second frame, so the "dozen fine steps" behaviour is reasoned from the rule, not
captured.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**. Phase A is complete and the
  blast now reads as one organic event: an expanding front of per-voxel effects,
  a native burst, a negative flash, camera shake, and smoke that lingers.
- **Next: the Director's fine-tuning pass** (`"depois fazemos o ajuste fino"`).
  Everything is a `var`; the tuning surface is `frag_grenade.json`'s ring weights,
  `sequence_ms`/`front_jitter`/`KIND_RADIUS_BIAS` in the choreographer,
  `blast_burst_*` in `room.gd`, and the smoke/ember/spark overlay defaults.
- **Open, both flagged and neither guessed at:** the crack decal art barely
  survives the downsample to a voxel face (an art problem, not a wiring one), and
  the GPU-flush safeguard from 2026-08-08 is still undecided.
- Pushed to `main`.
