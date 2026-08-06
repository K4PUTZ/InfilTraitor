# EXPLOSION_REBUILD_MASTER_PLAN
## Grenade detonation: targeting, choreography, and voxel damage — v1.0

**Date opened:** 2026-08-05
**Updated:** 2026-08-06 — Director answered Q1–Q6, then corrected/extended Q1b
and Q3b in a follow-up round (floor is material-real now, not agnostic to
"earth"; bullet marks join the pre-bake), then added D13 (per-map material
scope + cross-session bake cache, §3.5). Q7–Q9 remain (Phase B only).
**Status:** 🟠 **PLANNING — awaiting Director sign-off on the vertical-falloff
formula (§10 Q1b).** Nothing here is built.
**Next action:** §11. Q1b's exact formula is the one remaining proposed-not-
confirmed reading; Task 0 in §8 is a pure measurement spike, unaffected by it,
and can start immediately.
**Supersedes for explosions:** the destruction path described in
`DESTRUCTION_MASTER_PLAN.md` Part 3 and the whole PERF-01/02/03 + D11 +
D-ARCH-01 arc (`DETONATION_PERFORMANCE_MASTER_PLAN.md`,
`PLANO_PRE_FABRICATED_DAMAGE_VARIANTS.md`, `INVESTIGACAO_EXPLOSAO_2026-08-04.md`).
Those documents stay as the historical record of why this rebuild exists.
**Narrows, does not fully preserve, the old firearm-destruction boundary**
(`WEAPON_MASTER_PLAN.md` D26–D33): bullet *mark application* now shares this
plan's pre-baked registry (D12, 2026-08-06) — see §9's rewritten note. Hit
detection and damage-state logic in D26–D33 are still untouched.

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
| **Destruction (floor + wall/ceiling, unified — D1)** | muito | menos | quase nada | — |
| **Dented** | alguns | menos | — | — |
| **Cracked** | — | vários | alguns | — |
| **Soot (fuligem)** | strongest | medium | weak | minimal — **ring 3's only effect** |
| **Smoke (fumaça)** | most | medium | least | minimal — staggered in after ring 2 |

Plus, as ratified in this session (2026-08-05) and revised the next
(2026-08-06, marked **rev**):

- **D1 (rev 2026-08-06, corrected same day — see Q1b)** Destruction, dented,
  cracked, soot, and smoke all use **one unified per-tier ring-weight model**
  (§4.2) for floor, wall, and ceiling. What this replaces is the old idea that
  walls used a *different formula shape* ("ring-mult × material-resistance")
  than the floor's *muito/menos/quase nada* table — they now share the same
  ring-weight tables. **What it does NOT replace: `MaterialResistanceTable`
  itself.** Per-material resistance (concrete destroys more than stone, metal
  never cracks, wood chars instead) is an existing, unchanged mechanism and
  keeps multiplying against the ring weight exactly as it does today — the
  Director's own words: *"Esse mecanismo já existe. O que muda é só a
  intensidade em que isso ocorre por slice vertical até o teto."* The only new
  axis is *vertical*: rings flood walls horizontally (0–3 across GUs) **and**
  vertically — the slice directly above the blast's own floor level takes
  less, the slice above that even less. This is why a ceiling naturally takes
  the least damage today: not a hardcoded ceiling rule, a consequence of
  vertical distance from a blast that (for now) always originates at floor
  level. **Formula proposed in §4.3, pending confirmation (Q1b) — does not
  block Task 0.**
- **D2** Floor layers: the **first** blast on a virgin GU cedes only
  `FLOOR_TOP_LEVEL` (−1). A **later** blast on a GU that has already been
  blasted also cedes `FLOOR_DEEP_LEVEL` (−2). Requires per-GU blast memory.
- **D3** Three substrate variants per (material × type × decal), chosen per
  cell by a deterministic hash, so neighbouring damaged voxels rarely show the
  same piece of facade.
- **D4** Build in phases: **Phase A** = bake + calculation + waves on the
  current right-click trigger. **Phase B** = targeting UI, throw animation,
  bubble, the 1-second pre-compute window.
- **D5 (new 2026-08-06)** Smoke reaches ring 3 (weak, per the table above),
  and rings fire their smoke **in order, not simultaneously** — already the
  wave list's shape below, now extended one entry for ring 3.
- **D6 (new 2026-08-06)** Cracked is **one voxel family per material**, not
  one per element class. A cracked atom bakes its decal onto all three visible
  faces at once (it represents a voxel already failing on every side), so the
  same 3×3 (decal × substrate) atom set serves floor, wall, *and* ceiling —
  see §3.2's rewritten count.
- **D7 (new 2026-08-06)** Ceiling DENTED gets **3 irregular alpha-cut shapes**
  (broken-brick-style, reference image on file), not the single silhouette
  §3.2 assumed under Q4's old default. The cut-shape *art* is reusable across
  materials that share a look (not every material cracks — iron doesn't — so
  not every material needs its own cut set), but each material still bakes its
  own atom (facade differs per material even when the cut shape is shared).
- **D8 (new 2026-08-06, optimization, not yet scheduled to a task)** Soot and
  the light repaint for blast-affected voxels can be computed **after** the
  smoke waves fire rather than before wave 1, since soot visibly appearing a
  moment late reads as natural. This loosens §2's "repaint once, before wave 1"
  rule specifically for the soot waves — see §6.3.
- **D9 (new 2026-08-06)** Floor damage baking is **not agnostic to a single
  "earth" family anymore.** Today `IMPACT_FLOOR_MATERIAL = "earth"` fixes both
  the decal *art* and the `MaterialResistanceTable` *lookup* to `"earth"`
  regardless of a GU's real ground material — the Director explicitly rejected
  this: *"Chão de ferro não fica rachado, chão de concreto destrói mais que
  chão de pedra."* Floor specials now key off each GU's **real** registered
  ground material (`MaterialRegistry` — PLAYGROUND's is `ground_concrete`)
  against the same resistance table walls already use, and their decal base is
  a **random pre-baked SLAB atom** (top-face facade for that ground material,
  produced by the existing Slab/`BakeCompositor` pipeline — `ground_concrete`
  is already in `VOXEL_MATERIALS`, §3.2) instead of a wall-style facade voxel.
  **Scope for this plan: `ground_concrete` only** — the Director was explicit
  that the wider ground roster (`ground_grass/dirt/gravel/sand`, already listed
  in `bake_compositor.gd`) is a later population pass, not this rebuild's job;
  this plan's task is to make the *pipeline* material-driven, not to populate
  it. See §3.2's rewritten floor rows.
- **D10 (new 2026-08-06, consequence of D6+D9)** Crack eligibility collapses
  to **one source of truth**: a material cracks if its
  `MaterialResistanceTable` row has `crack_factor > 0` — full stop, for wall
  *and* floor materials alike. The separate `IMPACT_CRACK_MATERIALS` constant
  (today hardcoded to `[concrete, stone]`) becomes a derived query instead of
  an independent list that has to be kept in sync by hand. **Known gap this
  surfaces, not silently papered over:** `ground_concrete.crack_factor` is
  `0.0` today, for the same reason wood's and metal's used to be — *"no
  texture wired stays off"* (the table's own standing rule). D6 now provides
  that texture (the universal cracked atom serves floor too), so the original
  reason is gone, but this plan does not unilaterally change balance data.
  **Task 2 should revisit this row** once the atom exists to serve it — flagged
  here so it isn't lost, not answered here.
- **D12 (new 2026-08-06, answers Q3b — numbered past D11 to avoid colliding
  with the pre-existing "D11" choreography decision this plan already
  references in §0/§2)** Bullet marks ("marked") join this same
  pre-baked-at-load registry, **replacing D33's live per-cell compositing for
  the mark-application step**. Per material: 3 decals × 2 sides (left/right) —
  no floor or ceiling variant, because *"tiros não acertam teto e nem chão"*
  (Director, confirming an existing design fact, not a new rule). This is a
  genuine scope change from the plan's original "firearms untouched" boundary
  — see §9's rewritten note and the sequencing flag in §11.

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
10. **[PHASE A]** 15 waves, fired one after another, inner rings first, each
    wave independent — no wave waits for the previous one to finish:

    | # | Wave | | # | Wave |
    |---|---|---|---|---|
    | 1 | Destruction ring 0 | | 9 | Smoke ring 1 |
    | 2 | Destruction ring 1 | | 10 | Smoke ring 2 |
    | 3 | Destruction ring 2 | | 11 | Smoke ring 3 |
    | 4 | Dented ring 0 | | 12 | Soot ring 0 |
    | 5 | Dented ring 1 | | 13 | Soot ring 1 |
    | 6 | Cracked ring 1 | | 14 | Soot ring 2 |
    | 7 | Cracked ring 2 | | 15 | Soot ring 3 |
    | 8 | Smoke ring 0 | | | |

    (Director's original 14-entry list plus **Smoke ring 3**, added
    2026-08-06 per D5/Q2 — destruction/dented/cracked apply to floor, wall,
    *and* ceiling cells within the same wave now, per D1; no per-element-class
    wave split needed.)

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

### 3.2 Enumeration and count (rewritten 2026-08-06 twice — D6/D7, then D9/D10/D12)

**Enumeration rule (D10): derive material sets from `MaterialResistanceTable`,
don't hand-list them.** A material gets a DENTED atom if its `dent_factor > 0`;
a CRACKED atom if its `crack_factor > 0` (universal across floor/wall/ceiling,
D6); MARKED atoms unconditionally, for every wall material (bullets always
leave a mark regardless of blast resistance — a cosmetic, not a resistance
roll). Evaluated against today's real `TABLE` rows
(`material_resistance_table.gd`) and the real element-class rosters
(`voxel_renderer.gd`'s `IMPACT_DECAL_MATERIALS` for wall/ceiling-family
materials; D9's `ground_concrete` for floor, PLAYGROUND's only real ground
material today):

| Class | Materials (derived) | Combinations | Atoms |
|---|---|---|---|
| CRACKED (universal — floor + wall + ceiling, D6) | concrete, stone (2 — `crack_factor > 0`; `ground_concrete` excluded, D10's flagged gap) | 3 decals × 3 substrates | 18 |
| DENTED WALL | concrete, metal, stone, wood (4) | 2 sides × 3 decals × 3 substrates | 72 |
| DENTED FLOOR (top only, D9) | ground_concrete (1 — real material, not `"earth"`) | 3 decals × 3 substrates | 9 |
| DENTED CEILING (bottom, alpha-cut, D7) | concrete, metal, stone, wood (4) | 3 cut shapes × 3 substrates | 36 |
| MARKED / bullets (D12, confirmed in-scope) | concrete, metal, stone, wood (4) | 2 sides × 3 decals × 3 substrates | 72 |
| | | **Total** | **207** |

Not 135 (this session's first recount) and not the original ~192 — three real
moves happened across two rounds of answers: cracked went universal (D6,
−63), ceiling dented gained 2 more shapes (D7, +24), and marked/bullets joined
the pre-bake (D12, +72). If Task 2 later turns on `ground_concrete.crack_factor`
(D10's flagged gap), the total becomes **216** (+9) — a data-only change, no
new code path, since D10's derivation already reads the table live.

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
partly cold cache. A sequential 207-atom bake (§3.2, 2026-08-06 final recount)
is a different animal: the GPU readback cache (`_baked_source_image_cache`) is
warm after the first atom, the decal `Image`s are cached, `DecalCompositor`'s
resize cache is warm, and page uploads batch (PERF-02 A1 measured 197
uploads → 5, 876 ms → 8.1 ms). The marked/bullet atoms (D12) add real new
bake work here too — they used to be composited live, once per bullet hit, not
once per material at load; this spike is what tells us whether that trade is
actually cheaper.

**This projection is not evidence.** Task 0 below measures it before a single
line of the architecture is committed to.

Escape hatches, if Task 0 comes back too expensive **beyond what §3.5's cache
and per-map material scoping already buy**:
1. Substrates 3 → 1 (−138 atoms, 207 → 69; costs visual variety, D3 reversed).
2. Bake lazily on the **first** detonation, inside the pre-compute window
   (windows #1 and #2 exist precisely to absorb a hitch).

(The third hatch from the first draft of this section — "serialize the baked
page to disk" — is promoted out of the escape-hatch list: it's now baseline
design, §3.5, not a fallback. Task 0 still measures the **cold**, no-cache
case, because that's the number that answers "does a device's very first load
of a new material feel broken" — the cache cannot help that one.)

### 3.5 Material scope per map, and the cross-session bake cache (D13, new 2026-08-06)

Two related requirements from the Director, both aimed at the same problem:
the game will eventually ship many materials, and no single map — let alone
every load of the same map — should pay to bake all of them.

**Scope: each map declares which materials it actually uses.** Not derived by
scanning that map's `walls`/`blocks`/`floor_zones` sections for distinct
`material` values at compile time, even though that data already exists there
— an explicit declaration lets the bake pass run and finish **before**
geometry compilation needs the resulting atoms, rather than depending on a
full compile pass first (the likely reason the Director asked for this
explicitly rather than derived; noted as inference, not confirmed). Per
`MAPFILE_REFERENCE.md`'s extension protocol, this is **a new registered
section** (`{section_id, version, serialize, deserialize, migrations[]}` via
`MapSectionRegistry`, read before implementing — required by CLAUDE.md for any
`.map.json` change), not an ad-hoc field bolted onto an existing one. Task 1
should add a selftest asserting the declared list is a superset of what the
map's own walls/blocks/floor_zones actually reference, so authoring drift
(a material used but not declared) fails loudly (B6) instead of silently
missing its bake.

**Cache: baked atoms persist across sessions on the same device.** `user://`-
scoped, keyed on `(material, damage_state class, decal_variant,
substrate_variant)` **plus** a version/hash of the bake inputs (compositor
version, decal source art, bake config) — not just the material name — so an
art or config update invalidates stale entries automatically rather than
silently serving outdated graphics (a real risk with any disk cache; handled
by hashing the inputs, not by trusting the cache blindly). A map whose full
declared material set is already cached pays **effectively zero** bake time on
that load — Task 1's gate includes a real capture proving this: load the same
map twice, second load's bake step measurably near-zero versus the first.

**Partial coverage is already handled, not new work (D10 generalizes):**
*"alguns materiais vão ter todos os decals, outros só alguns"* is exactly
what D10's derive-from-`MaterialResistanceTable` rule already does — a
material with `crack_factor == 0` simply never enumerates a CRACKED atom.
Extending the roster later (new materials, or new decal families for existing
ones) is adding rows/factors and declaring the material on the relevant maps,
no code change.

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

### 4.2 Per-tier ring gates (new; now shared by floor, wall, and ceiling — D1 rev)

Today every ring rolls all three tiers, scaled by one multiplier. The
Director's table gates tiers **by ring** — dented never appears in ring 2,
cracked never in ring 0. That needs explicit per-tier weight tables, living in
`BombDef` (loaded from JSON, so they are `var`s, honouring architecture rule 1):

```json
"destroy_ring_weights": [1.0, 0.35, 0.08, 0.0],
"dent_ring_weights":    [1.0, 0.45, 0.0,  0.0],
"crack_ring_weights":   [0.0, 1.0,  0.35, 0.0],
"soot_ring_tones":      [0, 1, 2, 3],
"smoke_ring_weights":   [1.0, 0.5,  0.2,  0.1]
```

`smoke_ring_weights[3]` moved from `0.0` to `0.1` (D5/Q2 — smoke now reaches
ring 3, weak). `apply_container_damage()` multiplies each tier's count by its
own ring weight instead of the single shared `ring_multipliers[ring]`, and —
new as of D1 rev — this is no longer a floor-only computation: the same
weight tables gate wall and ceiling cells too, using the *effective ring* from
§4.3 rather than the flat horizontal ring. The starting numbers above are a
first pass on *"muito / menos / quase nada"* — tuning knobs, expected to move
after the first real capture (Task 6).

**`MaterialResistanceTable` is untouched and keeps multiplying in, exactly as
today (D1's clarification)** — the real per-cell formula is
`count = ring_group_size × resistance[material][tier_factor] × tier_ring_weights[effective_ring]`,
not a replacement of the resistance term, an *addition* of the ring-weight
term next to it. The one real change for floor cells (D9): `material` in that
lookup stops being the hardcoded `"earth"` and becomes the GU's real ground
material (`ground_concrete` on PLAYGROUND today) — so `apply_crater_damage()`
needs the same material-lookup change `apply_container_damage()` already has,
where today it likely doesn't (unverified — Task 2 confirms by reading the
real function, not by this plan asserting it).

### 4.3 Vertical falloff for walls/ceiling (new, D1 rev — mechanism proposed, pending confirmation as Q1b)

§4.2's weight tables are indexed by ring, and until 2026-08-06 "ring" meant
purely the horizontal GU distance from `flood_gu_rings()`. The Director's
answer to Q1 asks for a *second* falloff axis — vertical — so that a wall
slice directly above the blast's own floor level takes less than one at the
same level, and a slice above that takes less still (explaining, as a
consequence rather than a special case, why ceilings take the least damage:
they sit furthest above a blast that always originates at floor level).

**Proposed mechanism**, chosen because it reuses §4.2's existing tables
without adding a second parallel set of weights:

```
effective_ring(cell) = clamp(
    horizontal_ring(cell.gu) + max(0, cell.floor_level - blast.floor_level),
    0, ring_weights.size() - 1
)
```

A wall voxel at the blast's own floor level, horizontal ring 0, gets
`effective_ring = 0` (full weight). One floor level up, same horizontal ring,
gets `effective_ring = 1` ("menos"). Levels *below* the blast's floor level are
not penalized by this term (grenades that land on a floor have nothing
naturally below to fall off from; D2's floor-layer rule already governs
what's below). If throwing onto a roof is ever built, the formula is unchanged
— it always measures from that detonation's own floor level, never a fixed
"ground" constant.

This changes `apply_container_damage()`'s per-cell ring lookup from
`horizontal_ring(cell)` to `effective_ring(cell)` for wall/ceiling cells (floor
cells keep using the horizontal ring alone, since D2 already owns their
vertical dimension via the two-layer rule). **Confirm or correct before
Task 2** — it is the one piece of D1 the Director's answer described in
behavior, not in exact formula.

### 4.4 D2 — the two floor layers

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

**Timing, not just tone (D8, new 2026-08-06):** the stamped-by-blast half of
this computation, and the light repaint it feeds, do not need to land before
wave 1 the way destroy/dent/crack/smoke do — see §6.3 for the deferred-compute
proposal that spends that extra ~440 ms of slack.

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

**Cadence confirmed 2026-08-06: 40 ms/wave** → 15 waves ≈ 600 ms of
choreography (was 560 ms/14 waves before Smoke ring 3 was added).
`wave_interval_ms` is a `var`, not a `const`, and trivially re-tuned after the
first capture.

Smoke waves call the existing `SmokeSparkOverlay.add_smoke()` with per-blob
durations drawn from the ring (Director: *"usando durações diferentes"*) — that
overlay already exists and needs no rebuild.

### 6.3 Deferred soot + light compute (D8, new 2026-08-06 — optimization, not yet scheduled to a task)

§2's rule is "the map-wide light repaint runs exactly once, before wave 1."
The Director's 2026-08-06 addendum proposes loosening that specifically for
the four soot waves (12–15): since soot visibly settling a beat late reads as
natural (real fuligem takes a moment to appear), the soot tone computation and
its light repaint don't have to be ready before wave 1 — they only have to be
ready by the time wave 12 fires, roughly **440 ms** later at 40 ms/wave
(waves 1–11). That is real slack the destroy/dent/crack/smoke waves don't get.

Two ways to spend that slack, either compatible with `DetonationPlan`'s
existing shape:
- Compute soot synchronously but **after** dispatching wave 1, in whatever
  time remains before wave 12 is due — no thread needed, just reordering.
- Compute it on a background thread (`WorkerThreadPool`) started alongside the
  destroy/dent/crack pre-compute, and fire wave 12 on the *later* of "thread
  done" or "440 ms elapsed" — Director: *"se for possível soltamos antes, se a
  thread já estiver disponível."*

Not scheduled to a specific task yet — Task 4 (E-PLAN) is the natural place to
decide which of the two, once the rest of the pre-compute window's real cost
is known from Task 0.

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
| **0** | **Bake-cost measurement spike** | Real ms for a **cold, uncached** warm sequential 207-atom bake on PLAYGROUND (§3.2, 2026-08-06 final recount), via a temporary `INFILTRAITOR_CAPTURE_ACTION` hook (added, measured, reverted — same discipline as every PERF round) | **Blocks everything.** If > ~2 s, take §3.4's escape hatches before proceeding — §3.5's cache does not help this number, it only helps loads 2+ |
| 1 | E-BAKE | `VoxelVariantRegistry` re-keyed; `DamageVariantBaker` rewritten to enumerate the §3.2 table (D10's derived-from-resistance-table rule), scoped to each map's newly-declared material section (§3.5, D13 — read `MAPFILE_REFERENCE.md` before adding it); includes D12's marked/bullet atoms (baked, not yet wired to `fire_active()`, §11); floor specials source their substrate from pre-baked SLAB atoms per D9, not the wall facade pool; `user://` bake cache wired per §3.5; wired into `room_builder`; selftest asserts all declared atoms exist | Real load-time capture + atom count printed **on first load**, plus a second-load capture proving the cache makes repeat materials ~free |
| 2 | E-RING | 4th ring in `frag_grenade.json`; per-tier weight tables in `BombDef` (now shared by floor/wall/ceiling, D1 rev); `apply_container_damage()` *and* `apply_crater_damage()` read them via the §4.3 effective-ring formula, `MaterialResistanceTable` still multiplying in unchanged (D1's clarification) — floor's lookup keys off the GU's real ground material (D9), not `"earth"`; D2's two-layer floor rule; D10's flagged `ground_concrete.crack_factor` gap gets a decision here, not left silently at 0 | `blast_calculator_selftest` extended, red-before-green on the ring-3 flood, the vertical falloff (a wall voxel one floor level up must show a lower effective ring than one at blast level), *and* floor material realism (a `ground_concrete` GU and a hypothetical lower-resistance ground GU must show different destroy counts) |
| 3 | E-SOOT | per-voxel soot codes; `min()` merge of derived + stamped; ring-3 stamping | Real capture showing soot at ring 3 where nothing is destroyed |
| 4 | E-PLAN | `DetonationPlan` builder — all resolution, all exposure fallback, the single light repaint | Printed plan census (cells per wave) from a real detonation |
| 5 | E-WAVE | `DetonationChoreographer`; reconnect `TestZoneController.detonate_active()` | Real capture per wave; measured per-wave ms |
| 6 | Tuning pass | Director reviews captures, moves the §4.2 numbers | Director sign-off |

**Phase B** (targeting UI, bubble, throw animation, explosion frames, the two
compute windows) is planned separately once Phase A produces evidence — it is
not detailed here beyond §1's sequence, on purpose.

---

## 9. Explicitly out of scope

- **~~Firearm destruction~~ — narrowed 2026-08-06 (D12).** The original plan
  put ALL of firearm destruction out of scope, D33 untouched. That line no
  longer holds in full: bullet MARK application (the decal that appears where
  a shot lands) moves onto the same pre-baked registry as blast, per D12 —
  meaning it stops being live-composited and starts being a `set_cell()` swap
  against a pre-baked atom, same as every blast wave. **What stays genuinely
  out of scope:** the rest of D26–D33 (hit detection, damage-state transition,
  `WeaponBenchController.fire_active()`'s overall flow) — only the *mark* step
  changes *how* it paints, not *when* or *whether* a shot damages a voxel.
  Firearms are still the one destruction path proven to work today, so §11
  flags this as a sequencing risk: bake the marked atoms in Task 1 (cheap,
  additive, no wiring change), but treat rewiring
  `WeaponBenchController.fire_active()` onto them as its own checkpoint with
  its own before/after captures, done *after* Phase A's blast waves are
  proven — not bundled silently into Task 1.
- **Camera rotation.** Still disabled (ROTATE-KILL-01). The persistence
  contract in §7 is honoured anyway so re-enabling it is not blocked by this
  work.
- **Agent strength / throw-range skills.** Phase B ships a flat range constant;
  the skill term gets one named seam, the way `_agent_skill()` already does for
  firearms.
- **Actor damage from blasts.** Not mentioned in the Director's spec; not
  built.

---

## 10. Open questions for the Director

Opened 2026-08-05. **Q1–Q6 answered 2026-08-06**, recorded below with the
mechanism each answer implies, plus two follow-up sub-questions (Q1b, Q3b)
that turn "what the Director wants" into "the exact rule the code checks" —
neither blocks Task 0. Q7–Q9 stay open, Phase B only.

### Q1 — ✅ ANSWERED 2026-08-06. Destruction on walls/ceilings uses the same ring model as floor, plus a vertical falloff.

> "Q1: tudo vai ser passível de destruição. Os rings se extendem pelas paredes
> da mesma forma que no chão... a slice imediatamente acima recebe menos dano,
> a que estiver mais pra cima menos ainda... As demais características
> (dented, cracked, fumaça, fuligem) também seguem o mesmo mecanismo do chão,
> ativados em waves."

Recorded as D1 (rev) in §1, weight-table sharing in §4.2. This **reverses**
the 2026-08-05 reading (walls kept their own ring-mult × resistance model) —
the earlier reading was wrong, corrected.

**Follow-up correction, same day:** the first draft of this update
mis-simplified D1 as "walls stop using resistance." The Director corrected
that immediately: *"o tipo de material ainda precisa influenciar na
destruição... Esse mecanismo já existe. O que muda é só a intensidade em que
isso ocorre por slice vertical."* `MaterialResistanceTable` never left — it
multiplies against the (now vertical-aware) ring weight, unchanged in
mechanism, and — new — the floor now consults it against its **real** ground
material too, not a fixed `"earth"` placeholder (D9, D10 in §1). See §4.2's
added paragraph.

#### Q1b — the exact vertical-falloff formula 🔴 blocks Task 2, proposed not confirmed

The Director described the *behavior* (progressive falloff with height above
the blast) but not the exact formula. §4.3 proposes
`effective_ring = horizontal_ring + max(0, floor_level - blast.floor_level)`,
clamped to the table's max index, reusing §4.2's existing weight tables rather
than adding a second parallel set. **Confirm or correct before Task 2 is
written** — Task 0 and Task 1 are unaffected.

*Assumed if unanswered:* the §4.3 formula above.

### Q2 — ✅ ANSWERED 2026-08-06. Smoke reaches ring 3, weaker, and rings fire in sequence.

> "Q2: sim, vamos fazer a fumaça chegar no ring 3, mas queremos que a
> intensidade diminua um pouco entre os rings, e cada ring solte sua fumaça na
> ordem, e não todos ao mesmo tempo."

Recorded as D5 in §1. Wave 11 (**Smoke ring 3**) added to the choreography
(§1 step 10, now 15 waves); `smoke_ring_weights[3]` set to `0.1` in §4.2. The
"in order, not simultaneous" half was already the wave list's shape — no
change needed there.

### Q3 — ✅ ANSWERED 2026-08-06. Cracked is one voxel family per material, shared across floor/wall/ceiling.

> "Q3: cracked é um voxel só (x3 variantes de decal) para cada material...
> Esses 3 voxels servem pra chão telhado e teto. Por que? Porque o cracked tem
> que ser baked nas 3 faces do voxel... os demais voxels dented ou marked
> (bullets) são específicos para chão, parede ou teto."

Recorded as D6 in §1, §3.2 rewritten (2 crack materials × 3 decals ×
3 substrates = 18 atoms total, down from the old per-class 81). This resolves
the original Q3 (no cracked art existed for ceiling/floor) differently from
any of the proposed options (a)/(b)/(c) — the Director's answer makes ceiling
and floor crack **the same baked atom as the wall's**, so no new art and no
per-class art was ever needed; the 3 decal variants already planned for wall
cracked now cover all three classes.

#### Q3b — ✅ ANSWERED 2026-08-06. Marked/bullets join the pre-bake, wall-only, no live compositing.

> "Q3b: Sim, eu saí um pouco do escopo aqui. 'Marked' é o mesmo que 'bullets',
> e não aparece nas explosões. Porém queremos incluir o mesmo mecanismo de
> pré-bake dos voxels com marcas de tiros no load, usando 3 decals em 3 voxels
> aleatórios da facade — por material, x2 faces. Sem live bake... Decidimos
> que tiros não acertam teto e nem chão, então não é necessário criar as
> outras versões."

My original guess (excluded, §9's boundary holds) was **wrong** — corrected.
Recorded as D12 in §1 (renumbered past D11 to avoid colliding with this
plan's own pre-existing "D11" choreography reference), §3.2's table grows to
**207** total, §9's out-of-scope note rewritten, §11 adds an explicit
sequencing checkpoint so the `WeaponBenchController.fire_active()` rewiring
doesn't ride in silently on Task 1.

### Q4 — ✅ ANSWERED 2026-08-06. Ceiling DENTED gets 3 irregular alpha-cut shapes, reusable across materials.

> "Q4: o dented DE TETO é só metade de cima do voxel recortada em alpha...
> vamos fazer 3 tipos de recorte irregular, angulados, simulando um voxel com
> a base faltando, como um tijolo quebrado... Esses recortes podem ser
> re-utilizados em outros materiais similares... sem a necessidade de criar
> novas variações."

Recorded as D7 in §1. §3.2's ceiling-dented count moves from 1×3=12 to
3×3×4 materials = 36 (the *art* — the cut-shape alpha masks — is shared across
materials, but each material still bakes its own atom against its own
facade). No longer "nothing to vary" — superseded.

### Q5 — ✅ ANSWERED 2026-08-06. 40 ms/wave confirmed.

> "Q5: Me parece bom! Vamos seguir com 40ms."

§6.2 updated: 15 waves × 40 ms ≈ 600 ms of choreography (was 560 ms/14 waves
before Smoke ring 3).

### Q6 — 🟡 PARTIALLY ANSWERED 2026-08-06 (bubble described; reference image attached). Phase B only, does not block Phase A.

The Director attached the XCOM reference and described it: a line simulating
the parabola from the throwing agent to the impact point, and a translucent
3D bubble over the blast-radius area, in isometric perspective — the same
information the existing floor-perimeter wireframe (`open_menu_for()`) already
computes, extended into a 3D projected volume rather than a flat outline. Not
detailed further here since Phase B is not scheduled — recorded so the Phase B
plan doesn't have to re-ask for the image.

### Q7 — Explosion art 🟢 Phase B only

3 frames, fire/energy dispersing in alpha. Director said *"vou fornecer a
arte."* Phase B.

### Q8 — Throw range 🟢 Phase B only

A flat default in GU, until agent strength/skills exist. Note this is
**independent of the blast's 4 rings**: range decides how far the impact GU can
be placed, rings decide what the blast does once it lands.

*Assumed if unanswered:* 6 GU, matching the movement overlay's comfortable
reach.

### Q9 — Is the throw animation a new asset, or the existing sprite on an arc? 🟢 Phase B only

`GrenadeProp` already bakes 8 angles of the Quaternius grenade. Tweening that
existing sprite along a parabola is nearly free; a hand-authored throw
animation is not.

*Assumed if unanswered:* tween the existing prop.

---

## 11. Next session starts here (updated 2026-08-06)

**Resume point:** planning complete, **nothing implemented**. The repo is in
exactly the post-reset state §0 describes — grenades detonate and damage
nothing, firearms work. Working tree still clean at commit `2ba9a19` plus
docs-only commits since. Q1–Q6 answered 2026-08-06; a same-day follow-up round
resolved Q3b (bullets: in scope, D12), sharpened Q1 (resistance stays, floor
stops being agnostic to "earth", D9/D10), and added D13 (per-map material
scope + cross-session bake cache, §3.5). **Only Q1b (§4.3's exact
vertical-falloff formula) is still proposed-not-confirmed.**

**Order of business:**

1. **Confirm Q1b (§4.3's effective-ring formula) before writing Task 2.** It
   is the one remaining proposed reading with a stated default — Task 0 and
   Task 1 do not need it answered to start.
2. **Run Task 0 (§8): the bake-cost measurement spike.** It is pure
   measurement, commits to no design decision, and produces the one number the
   whole architecture rests on. Can start immediately, in parallel with Q1b.
   - Method: temporary `INFILTRAITOR_CAPTURE_ACTION=explosion_bake_spike` hook,
     bake a representative **cold, uncached** sequential run over the
     **207-atom** table (§3.2, 2026-08-06 final recount — 216 if Task 2 also
     turns on `ground_concrete.crack_factor`, D10), print real ms, **revert
     the hook before committing** — the same add/measure/revert discipline
     every PERF round used (and `grep -n explosion_bake_spike` must come back
     empty). D13's cache (§3.5) is a Task 1 deliverable, not yet built —
     Task 0 cannot lean on it.
   - What makes it honest: the 2026-08-05 figure of ~95 ms/voxel was a
     *per-cell, partly-cold* bake. This spike must measure the *warm sequential*
     case, because that is the case the plan actually depends on. Do not reuse
     the old number as if it answered this question.
   - Decision gate: > ~2 s at load → take §3.4's escape hatches (substrates
     3→1, or lazy bake into the pre-compute window) **before** writing Task 1.
3. Then Tasks 1 → 6 in §8's order. **Task 1 now includes:** baking the D12
   marked/bullet atoms (cheap and additive — just more registry entries, not
   yet wired to `fire_active()`, see the sequencing note below); reading
   `MAPFILE_REFERENCE.md`'s extension protocol before adding D13's new
   declared-materials section; and building the `user://` bake cache. All
   three are Task 1 deliverables, none of them block Task 0.
4. **A new, explicit checkpoint (not yet numbered as a Task):** once Phase A's
   blast waves are captured and signed off, rewire `fire_active()`'s mark
   step onto the pre-baked D12 atoms, with its own real before/after captures
   (bullet marks still landing, still on the right face, still per-material).
   Do this as its own reviewable unit, not folded into Task 1 silently — D33
   is the one destruction path that's been solid since the reset, and
   changing *when* it stops being solid deserves its own checkpoint.

**Do not:**
- start Phase B (targeting UI, bubble, throw, explosion frames) — the Director
  chose Phase A first, deliberately, so the 15 waves are verifiable with real
  captures before they get wrapped in animation. Q6's bubble description and
  XCOM reference (2026-08-06) are recorded in §10 for when Phase B starts, not
  a signal to start it now;
- rewire `WeaponBenchController.fire_active()`'s live compositing onto the
  D12 pre-baked atoms **as part of Task 1** — bake the atoms, don't flip the
  switch yet (see item 4 above). The rest of D26–D33 (hit detection,
  damage-state logic) stays untouched regardless;
- re-enable camera rotation as part of this work (§9);
- treat the 207-atom count in §3.2 as measured — it is an enumeration of the
  §3.2 table, and Task 0 is what turns it into a real cost.

---

## 12. Verification contract for this plan

Nothing in this plan is reported done on reasoning. Each task closes with:
`project_lint.py` clean · `run_selftests.py` clean · `check_invariants.py` OK ·
`gen_codemap.py --check` clean · **and a real capture from the real PLAYGROUND
map with real counts printed** — the floor-dent lesson (69 dents on a fixture,
zero on PLAYGROUND) applies to every single one of the 15 waves.

Captures meant to be cited here get **hand-picked names** (`expl_wave3_ring0.png`),
never `auto_*` — the 50-file rotation eats those, and 16 of 23 `auto_*`
citations across the docs were already dead when measured on 2026-08-03.
