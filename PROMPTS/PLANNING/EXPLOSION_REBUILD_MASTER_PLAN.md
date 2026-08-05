# EXPLOSION_REBUILD_MASTER_PLAN
## Grenade detonation: targeting, choreography, and voxel damage — v1.0

**Date opened:** 2026-08-05
**Status:** 🟠 **PLANNING — awaiting Director sign-off.** Nothing here is built.
**Supersedes for explosions:** the destruction path described in
`DESTRUCTION_MASTER_PLAN.md` Part 3 and the whole PERF-01/02/03 + D11 +
D-ARCH-01 arc (`DETONATION_PERFORMANCE_MASTER_PLAN.md`,
`PLANO_PRE_FABRICATED_DAMAGE_VARIANTS.md`, `INVESTIGACAO_EXPLOSAO_2026-08-04.md`).
Those documents stay as the historical record of why this rebuild exists.
**Does NOT supersede:** firearm destruction (`WEAPON_MASTER_PLAN.md` D26–D33),
which works today and is deliberately left alone — see §9.

---

## 0. Where the system actually is right now

Established by reading the repo, not from memory:

- `TestZoneController.detonate_active()` hides the grenade sprite and closes
  its menu. **It damages nothing** — the calls to
  `BlastCalculator.apply_container_damage()`/`apply_crater_damage()` were
  removed on 2026-08-05 (commit `d412480`). This is intentional, not a
  regression.
- The blast-radius red wireframe preview (`open_menu_for()`) still works — it
  never touched voxels.
- **Kept intact and unused:** `BlastCalculator` (1105 lines, fully
  selftested), `DecalCompositor`, `HalfVoxelCompositor`, all 45 decal PNGs,
  `VoxelVariantRegistry`, `DamageVariantBaker`, `apply_damage_voxel_swap()`.
- **Working and untouched:** `WeaponBenchController.fire_active()` — firearms
  destroy voxels through D33 runtime compositing.
- Light flicker is off (`a2d0d47`), for clean diagnostic captures.
- The floor is two real destructible planes: `FLOOR_TOP_LEVEL` (−1) and
  `FLOOR_DEEP_LEVEL` (−2), plus fixed bedrock at −8..−3.
- `frag_grenade.json` declares `ring_multipliers: [1.0, 0.6, 0.2]` → 3 rings
  (0,1,2). `flood_gu_rings()` derives its cap from that array's size.
- Soot is per-FACE (3 faces packed into one modulate-alpha code, 125 codes),
  **derived fresh from currently-destroyed voxels** on every light repaint
  (D24) — never authored by the blast.

### Why the last architecture failed, in one line

D-ARCH-01 pre-baked a damage variant **per cell**, so the bake surface was
71,296 cells × N variants. Measured 2026-08-05: ~95 ms/wall-voxel → tens of
minutes at map load. Infeasible.

### Why this one is different

The Director's rule *"usando voxels aleatórios das facades por baixo"* removes
the per-cell dimension entirely. A damaged voxel no longer shows **its own**
facade under the decal — it shows a randomly chosen one for that material. The
bake set collapses from *cells × variants* to *materials × types × decals ×
substrates* — roughly **190 atoms for the whole map**, baked once. That single
sentence is what makes the whole plan viable, and everything below depends on
it.

---

## 1. Director's specification (2026-08-05), restated exactly

Ring model — the grenade reaches **3 GU beyond ring 0**, so rings 0,1,2,3.

| Effect | Ring 0 | Ring 1 | Ring 2 | Ring 3 |
|---|---|---|---|---|
| **Destruction (floor)** | muito | menos | quase nada | — |
| **Destruction (wall/ceiling)** | as today (ring mult × resistance) | ” | ” | — |
| **Dented** | alguns | menos | — | — |
| **Cracked** | — | vários | alguns | — |
| **Soot (fuligem)** | strongest | medium | weak | minimal — **ring 3's only effect** |
| **Smoke (fumaça)** | most | medium | least | — |

Plus, as ratified in this session:

- **D1** Destruction applies to floor **and** walls/ceilings, as today. The
  *muito/menos/quase nada* falloff above is the **floor's own** profile; walls
  and ceilings keep the existing ring-multiplier × material-resistance model.
- **D2** Floor layers: the **first** blast on a virgin GU cedes only
  `FLOOR_TOP_LEVEL` (−1). A **later** blast on a GU that has already been
  blasted also cedes `FLOOR_DEEP_LEVEL` (−2). Requires per-GU blast memory.
- **D3** Three substrate variants per (material × type × decal), chosen per
  cell by a deterministic hash, so neighbouring damaged voxels rarely show the
  same piece of facade.
- **D4** Build in phases: **Phase A** = bake + calculation + waves on the
  current right-click trigger. **Phase B** = targeting UI, throw animation,
  bubble, the 1-second pre-compute window.

Detonation sequence (Phase B order, with Phase A's part marked):

1. Player presses the grenade button.
2. UI enters targeting mode: cursor becomes the impact GU, capped at throw
   range; red perimeter drawn on the floor around reachable GUs.
3. A virtual bubble shows the blast sphere (XCOM / Phoenix Point style).
4. Player clicks a GU → grenade armed.
5. **Heavy compute window #1** — a small hitch is tolerated here.
6. Throw animation; grenade lands and sits for 1 s.
7. **Heavy compute window #2** — a second hitch is tolerated here.
8. Full-screen white flash, tweened down. By this instant the dented/cracked
   atoms must already be resolved.
9. Explosion animation — 3 frames, fire/energy dispersing in alpha (**art
   pending from the Director**).
10. **[PHASE A]** 13 waves, fired one after another, inner rings first, each
    wave independent — no wave waits for the previous one to finish:

    | # | Wave | | # | Wave |
    |---|---|---|---|---|
    | 1 | Destruction ring 0 | | 8 | Smoke ring 0 |
    | 2 | Destruction ring 1 | | 9 | Smoke ring 1 |
    | 3 | Destruction ring 2 | | 10 | Smoke ring 2 |
    | 4 | Dented ring 0 | | 11 | Soot ring 0 |
    | 5 | Dented ring 1 | | 12 | Soot ring 1 |
    | 6 | Cracked ring 1 | | 13 | Soot ring 2 |
    | 7 | Cracked ring 2 | | 14 | Soot ring 3 |

    (14 entries — the Director's list, counted.)

---

## 2. The core performance idea, stated once

**Every wave is a loop of `set_cell()` calls with already-resolved tile ids.**
No compositing, no lookup, no light rebuild, no allocation happens inside a
wave. Everything a wave needs — which cells, which `source_id`, which
`atlas_coords`, which alternative id (light bucket × soot tone) — is computed
in the pre-compute window and stored in a plain `DetonationPlan` dictionary.

This is what the previous architecture never had. D11's choreography did real
work per frame (composite, upload, repaint), which is why staging it made
things *worse*, not better. Here the choreography is pure playback of a
precomputed script.

Two consequences that must be designed for, not discovered later:

- **The map-wide light repaint runs exactly once**, inside the pre-compute
  window, *before* wave 1 — never per wave. Its output is folded into each
  cell's stored alternative id in the plan.
- **Exposure fallback is precomputed too.** Destroying a voxel exposes
  geometry behind it, which must fall back to the material atlas (bake
  invariant B5). Which cells those are, and which tile each gets, is resolved
  during pre-compute and shipped inside the destruction waves.

---

## 3. E-BAKE — the load-time damage atom set

### 3.1 Registry shape

`VoxelVariantRegistry`'s key loses its `(grid_pos, level)` dimension:

```
(element_class, material, damage_state, carved_side, decal_variant, substrate_variant)
  -> {source_id: int, atlas_coords: Vector2i}
```

`element_class ∈ {WALL, CEILING, FLOOR}`. The existing `make_cell_key()` is
replaced by `make_variant_key()`; the file's own docstring (which currently
describes the per-cell model) is rewritten to match.

### 3.2 Enumeration and count

| Class | Material set | Combinations | Atoms |
|---|---|---|---|
| WALL DENTED blast | concrete, metal, stone, wood | 2 sides × 3 decals × 3 substrates | 72 |
| WALL CRACKED blast | concrete, stone (`IMPACT_CRACK_MATERIALS`) | 3 decals × 3 substrates | 18 |
| CEILING DENTED blast (BOTTOM) | 4 materials | 1 silhouette × 3 substrates | 12 |
| CEILING CRACKED blast | 4 materials | 3 decals × 3 substrates | 36 |
| FLOOR DENTED blast (TOP) | ~3 zone materials, shared `earth` family | 3 decals × 3 substrates | 27 |
| FLOOR CRACKED blast | ~3 zone materials | 3 decals × 3 substrates | 27 |
| | | **Total** | **~192** |

Bullet variants are **not** in this table — firearms keep the D33 per-cell
runtime path (§9).

### 3.3 Substrate selection, and how it survives rotation

The substrate index (0..2) is **rolled at damage time and stored on the
Voxel**, exactly the way `damage_variant` already is, and for the identical
reason: `grid_pos` is view-space, so re-deriving it at paint time would re-roll
every mark on rotation.

- New field `Voxel.damage_substrate: int = 0`.
- Rolled by `BlastCalculator.substrate_for(salt, x, y)` — same FNV-1a
  hash-and-mod shape as the existing `decal_variant_for()`, **different salt**
  so substrate choice does not correlate with decal choice.
- Persisted in `room._base_damage` as a 7th column (see §7).

### 3.4 Bake cost — the gating unknown

The 95 ms/wall-voxel figure measured on 2026-08-05 was a per-cell bake with a
partly cold cache. A sequential 192-atom bake is a different animal: the GPU
readback cache (`_baked_source_image_cache`) is warm after the first atom, the
decal `Image`s are cached, `DecalCompositor`'s resize cache is warm, and page
uploads batch (PERF-02 A1 measured 197 uploads → 5, 876 ms → 8.1 ms).

**This projection is not evidence.** Task 0 below measures it before a single
line of the architecture is committed to.

Escape hatches, in the order they'd be taken if Task 0 comes back too
expensive:
1. Substrates 3 → 1 (−128 atoms; costs visual variety, D3 reversed).
2. Bake lazily on the **first** detonation, inside the pre-compute window
   (windows #1 and #2 exist precisely to absorb a hitch).
3. Serialize the baked page to disk, keyed on the bake config + material set.

---

## 4. E-RING — the four-ring model and per-tier gating

### 4.1 Reaching ring 3

`flood_gu_rings()` caps at `ring_multipliers.size() - 1`, so ring 3 is reached
by **data alone**: `frag_grenade.json` becomes

```json
"ring_multipliers": [1.0, 0.6, 0.25, 0.0]
```

Ring 3's `0.0` means it contributes no destruction/dent/crack — it exists to
carry soot. No change to the flood code.

### 4.2 Per-tier ring gates (new)

Today every ring rolls all three tiers, scaled by one multiplier. The
Director's table gates tiers **by ring** — dented never appears in ring 2,
cracked never in ring 0. That needs explicit per-tier weight tables, living in
`BombDef` (loaded from JSON, so they are `var`s, honouring architecture rule 1):

```json
"destroy_ring_weights": [1.0, 0.35, 0.08, 0.0],
"dent_ring_weights":    [1.0, 0.45, 0.0,  0.0],
"crack_ring_weights":   [0.0, 1.0,  0.35, 0.0],
"soot_ring_tones":      [0, 1, 2, 3],
"smoke_ring_weights":   [1.0, 0.5,  0.2,  0.0]
```

`apply_container_damage()` multiplies each tier's count by its own ring weight
instead of the single shared `ring_multipliers[ring]`. The starting numbers
above are a first pass on *"muito / menos / quase nada"* — they are tuning
knobs, expected to move after the first real capture.

### 4.3 D2 — the two floor layers

`apply_crater_damage()` gains a `deep_layer_unlocked: bool`:

- `room` keeps `_gu_blast_count: Dictionary` (base-coords GU → int), persisted
  alongside `_base_damage`.
- First blast on a GU: only `FLOOR_TOP_LEVEL` voxels are candidates for
  destruction.
- Second and later: `FLOOR_DEEP_LEVEL` joins the candidate set, still narrowed
  by the existing `DEEP_FLOOR_CRATER_FACTOR` (0.5) bowl shape.

The existing PERF-02 B4 hack ("skip FLOOR_-2 entirely") is removed — D2 is the
principled version of the same saving.

---

## 5. E-SOOT — per voxel, authored, not derived

### 5.1 What changes

| | Today | After |
|---|---|---|
| Granularity | per FACE (3 faces packed) | **per VOXEL** (one tone) |
| Code count | `FACE_SOOT_CODE_COUNT = 125` | **5** (4 tones + clean) |
| Alt-id headroom | 12 × 125 × 2 = 3000 / 4096 | 12 × 5 × 2 = **120** / 4096 |
| Origin | derived from holes each repaint | **authored by the blast**, per ring |

The alt-id ceiling (`TileSetAtlasSource.TRANSFORM_FLIP_H` = 4096) stops being a
binding constraint, which is what let the Director's earlier "five tones"
request get refused. Worth noting: five tones would now fit trivially.

### 5.2 Why derivation alone cannot work here

`derive_soot_rings()` seeds soot from **currently destroyed voxels**. Ring 3
destroys nothing, so a derived map can never produce ring 3 soot — which is the
Director's only stated effect for that ring. Soot must therefore be stamped
explicitly by the blast.

### 5.3 Not breaking firearms

Firearm soot rides entirely on that same derivation (D24: an isolated bullet
hole reads as ~1 ring on its own). Removing it would silently break the one
destruction path that currently works.

**Design: the soot map is the darker of the two sources.**
`soot_tone(cell) = min(derived_from_holes(cell), stamped_by_blast(cell))`
(lower index = darker). Derivation stays exactly as it is, firearms are
untouched, and the blast simply adds its own four rings on top. The per-face →
per-voxel collapse is a pure data simplification of the same values (take the
darkest of the three faces) and is verified by capture, not by reasoning.

---

## 6. E-WAVE — the choreography driver

### 6.1 The plan object

Built entirely in the pre-compute window:

```gd
DetonationPlan = {
  "destroy":  { ring: int -> Array[{cell: Vector2i, level: int,
                                    expose: Array[{cell, level, source_id, atlas_coords, alt}]}] },
  "dented":   { ring: int -> Array[{cell, level, source_id, atlas_coords, alt}] },
  "cracked":  { ring: int -> Array[{cell, level, source_id, atlas_coords, alt}] },
  "smoke":    { ring: int -> Array[{world_pos: Vector2, duration: float, scale: float}] },
  "soot":     { ring: int -> Array[{cell, level, alt}] },
}
```

Every rendering entry carries its final `alt` (light bucket × soot tone) so a
wave never consults the light field.

### 6.2 The driver

A small `DetonationChoreographer` (new, ~120 lines) walks a static wave table
`[(kind, ring, delay_ms)]` and applies each wave's array. Waves are scheduled
on absolute elapsed time from the flash, so a slow wave never delays the next —
matching *"cada onda independente, sem esperar a outra acabar."*

Proposed cadence **40 ms/wave** → 14 waves ≈ 560 ms of choreography.
`wave_interval_ms` is a `var`, not a `const`. **Needs the Director's number.**

Smoke waves call the existing `SmokeSparkOverlay.add_smoke()` with per-blob
durations drawn from the ring (Director: *"usando durações diferentes"*) — that
overlay already exists and needs no rebuild.

---

## 7. E-PERSIST — what survives rotation

`room._base_damage[Vector3i]` grows from 6 columns to 7:

```
[damage_state, is_blast, dir.x, dir.y, dir.z, variant, substrate]
```

Two new sibling stores, both in base coords:
- `_base_soot[Vector3i] -> tone` (soot is now independent of damage state — a
  ring-3 voxel is sooted and otherwise intact).
- `_gu_blast_count[Vector2i] -> int` (D2's floor-layer memory).

`.map.json` is untouched — these are runtime session state, not map data.

---

## 8. Tasks, in order

| # | Task | Deliverable | Gate |
|---|---|---|---|
| **0** | **Bake-cost measurement spike** | Real ms for a warm sequential 192-atom bake on PLAYGROUND, via a temporary `INFILTRAITOR_CAPTURE_ACTION` hook (added, measured, reverted — same discipline as every PERF round) | **Blocks everything.** If > ~2 s, take §3.4's escape hatches before proceeding |
| 1 | E-BAKE | `VoxelVariantRegistry` re-keyed; `DamageVariantBaker` rewritten to enumerate the §3.2 table; wired into `room_builder`; selftest asserts all ~192 atoms exist | Real load-time capture + atom count printed |
| 2 | E-RING | 4th ring in `frag_grenade.json`; per-tier weight tables in `BombDef`; `apply_container_damage()` reads them; D2's two-layer floor rule | `blast_calculator_selftest` extended, red-before-green on the ring-3 flood |
| 3 | E-SOOT | per-voxel soot codes; `min()` merge of derived + stamped; ring-3 stamping | Real capture showing soot at ring 3 where nothing is destroyed |
| 4 | E-PLAN | `DetonationPlan` builder — all resolution, all exposure fallback, the single light repaint | Printed plan census (cells per wave) from a real detonation |
| 5 | E-WAVE | `DetonationChoreographer`; reconnect `TestZoneController.detonate_active()` | Real capture per wave; measured per-wave ms |
| 6 | Tuning pass | Director reviews captures, moves the §4.2 numbers | Director sign-off |

**Phase B** (targeting UI, bubble, throw animation, explosion frames, the two
compute windows) is planned separately once Phase A produces evidence — it is
not detailed here beyond §1's sequence, on purpose.

---

## 9. Explicitly out of scope

- **Firearm destruction.** It works. It keeps the D33 per-cell runtime
  compositing path. A consequence, stated so it is not later reported as a
  bug: a *bullet* mark shows that cell's own facade under it, a *blast* mark
  shows a random one. That is the deliberate trade of §3.
- **Camera rotation.** Still disabled (ROTATE-KILL-01). The persistence
  contract in §7 is honoured anyway so re-enabling it is not blocked by this
  work.
- **Agent strength / throw-range skills.** Phase B ships a flat range constant;
  the skill term gets one named seam, the way `_agent_skill()` already does for
  firearms.
- **Actor damage from blasts.** Not mentioned in the Director's spec; not
  built.

---

## 10. Inputs still needed from the Director

1. **The reference image** (XCOM / Phoenix Point bubble) — referenced in the
   spec as "(imagem)" but no image arrived with the message.
2. **The explosion art** — 3 frames, fire/energy dispersing in alpha.
3. **Cracked art for ceilings and floors.** Neither exists today: D32.6 fixed
   blast-CRACKED to concrete and stone only, and the floor family has no crack
   tier at all (`IMPACT_FLOOR_MATERIAL` covers blast/dent/top only). Options:
   reuse `decal_generic_blast_crack_*`, or author new families. **This gates
   64 of the ~192 atoms in §3.2.**
4. **Wave cadence** — 40 ms/wave proposed (≈560 ms total).
5. **Ceiling DENTED** is a pure silhouette carve with nothing to vary
   (`_ceiling_carve_plan()`), so it gets 1 decal × 3 substrates rather than the
   3 decals the spec asks for on the other families. Confirm that's acceptable.
6. **Throw range** default in GU, until the strength/skill stats exist.

---

## 11. Verification contract for this plan

Nothing in this plan is reported done on reasoning. Each task closes with:
`project_lint.py` clean · `run_selftests.py` clean · `check_invariants.py` OK ·
`gen_codemap.py --check` clean · **and a real capture from the real PLAYGROUND
map with real counts printed** — the floor-dent lesson (69 dents on a fixture,
zero on PLAYGROUND) applies to every single one of the 14 waves.

Captures meant to be cited here get **hand-picked names** (`expl_wave3_ring0.png`),
never `auto_*` — the 50-file rotation eats those, and 16 of 23 `auto_*`
citations across the docs were already dead when measured on 2026-08-03.
