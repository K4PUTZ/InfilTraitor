# MATERIALS_MASTER_PLAN
## The materials milestone — burn, breach, see through, and flow — v1.2

**Status:** 🟡 **v1.2 — the design is captured and ordered; M1 and the soft
materials' tier rule are built.** §3.2 (the passage rule) and §3.3 (the tick)
were RESOLVED by the Director on 2026-08-21, and the first answer added a new
structural requirement — **half-thickness elements, §3.2b** — that the engine
cannot do today. Later the same day the Director cut M2 from 21 files to 9
(§2), which turned out to be a code-and-data change rather than an art one, and
moved glass to the back of the queue whole.
**Written:** 2026-08-21, against `b9a46b15`; v1.2 the same day against
`9b66d869`.
**Supersedes:** `BURN_THROUGH_MASTER_PLAN` (v0.2), which becomes this document's
§4 — that plan was opened before the Director described the full wave, and a
plan named after one of five parts is the wrong container. Nothing in it is
retracted; §2 (the cascade ceiling) and §3b (the fire curves) are carried here
verbatim in substance.
**Companions:** `DESTRUCTION_MASTER_PLAN` (owns how anything becomes broken
voxels), `VOXEL_LIGHT_MASTER_PLAN` (the ember, the light field),
`docs/systems/LIGHT_MASTER_PLAN.md`, `ASSETS/ART_SPECIFICATIONS.md` (§7 decals),
`PROMPTS/ART_ORDER_NEW_MATERIALS.md` (the five facades, delivered 2026-08-21),
`PROMPTS/ART_ORDER_BRICK_DECALS.md` (the nine brick decals, open).

---

## 0. What this milestone is

Nine materials exist. Five arrived on 2026-08-21 and render correctly
(`mat_block_02_lit_five_materials.png`). **None of what makes them
*interesting* is built.** This plan is the ordered list of that.

| Part | What | Size |
|---|---|---|
| **M1** | The five materials exist, render, and break | ✅ **DONE** |
| **M2** | Decals — the marks each material takes | Small, art-led. **9 files, brick only** |
| **M3** | Fire that consumes and opens passages | **Large.** The milestone's centre |
| **M4** | Glass: seeing through it, and breaking it non-locally | Medium + one hard rendering question. **LAST, by decision** |
| **M5** | Voxel props — the thing these materials are actually for | Medium, blocked on renderer v2 |
| **M6** | Fluids (water/lava) | **Research first, unscoped** |

The ordering is not arbitrary: **M2 before M3** because a burning wall's
intermediate states are marks, and building fire against materials that cannot
show damage means judging it blind. **M3 before M5** because a burning crate and
a burning wall are the same mechanism, so the mechanism comes first and the prop
class consumes it. **M6 last** because it is the only part with no ratified
design at all.

---

## 1. The geometry every part below depends on

Measured 2026-08-21 on a real generated `Slice` pair, not read off a doc:

```
storey_count = 2   ->  voxels = 128 per slice, sibling identical
8 voxels per LEVEL (the 8 face positions of a GU)
8 LEVELS per STOREY
index = level * 8 + position          (level 0 = the base)
```

A wall is exactly **2 voxels thick** (D16): the edge's two slices, indexed
identically — `index i` is the same physical cell on both faces (verified
2026-07-30, and `EdgeRegistry.sibling_slice()` is the only way to cross).

**Vocabulary this plan uses, so §3 can be precise:**

- **cell** — one `(level, position)` on one slice.
- **through-pair** — the same `index i` DESTROYED on *both* slices. The wall is
  open front-to-back at that cell. This is the atom of a passage.
- **base row** — level 0, the 8 cells sitting on the floor.

---

## 2. M2 — Decals (art-led, small, and it unblocks judging M3)

Spec is `ART_SPECIFICATIONS.md` §7 and does not change: **256×256, square, alpha
REQUIRED, full colour allowed** (B2 does not bind decals), **3 variants per
family per material**, at
`ASSETS/ISOMETRIC/source_assets/voxels/decals/decal_<family>_<material>_<n>.png`.

**A material with no authored family is NOT unmarked.** It falls to the
material-agnostic GENERIC family (`decal_generic_bullet_dented_*`,
`decal_generic_blast_crack_*` — 12 files, already on disk), composited onto that
material's own flat atom. That path resolves through `MATERIALS.find()`, which
is why `BASE_MATERIALS` registration matters. So M2 is quality, never a blocker.

### ✅ RESOLVED 2026-08-21 — 21 files became NINE, and the reason has teeth

> Director: *"Não vamos ter decals nos materiais moles porque eles não ficam
> cracked e nem dented, apenas furam ou queimam. Com exceção do vidro, que é um
> caso à parte, precisa de um algoritmo próprio para rachados e buracos, e vamos
> deixar por último. O tijolo vamos criar normalmente, seguindo o estilo do
> concreto."*

**Nine files, and only these:**

| Family | Materials | Files | Why not the rest |
|---|---|---|---|
| `bullet` | brick | 3 | Brick follows concrete exactly — the Director's own words |
| `dent` | brick | 3 | Same |
| `crack` | brick | 3 | D32.6 — only rigid mineral materials fracture, and brick is one |

Order: [`ART_ORDER_BRICK_DECALS.md`](../ART_ORDER_BRICK_DECALS.md).

**fabric, cardboard and plywood get nothing, structurally** — MAT-SOFT-01,
landed the same day. The ruling reads as an art decision and is not one: the
tier data underneath was *promising dents* (dent_factor 0.10/0.15/0.22), and a
material with no authored family is NOT unmarked — it falls to the GENERIC
family, so a blast was marking cardboard with a grey dent nobody ordered. These
three now have exactly two states, INTACT and DESTROYED, in code
(`ShotPunchTable.HOLE_ONLY_MATERIALS`) and in data (`dent_factor` 0.0). Art for
them would be files nothing can load.

Measured on the real map, both sides from one binary via a stash, same cells,
identical punch list:

```
BEFORE  fabric:s1  cracked=0 dented=17 destroyed= 1   (breach 2.75)
AFTER   fabric:s1  cracked=0 dented= 0 destroyed=18   (breach 0.00)
```

**Glass gets none and is deferred WHOLE** — see M4b. It is the one material
whose "no decals" has a different cause: not that it cannot be marked, but that
its marks need their own crack/hole algorithm.

**M2 tasks:** author → `check_decal.py --material brick` → add `brick` to
`VoxelRenderer.IMPACT_DECAL_MATERIALS` **and** `IMPACT_CRACK_MATERIALS` → update
`voxels/manifest.json` → capture the before/after pair.

⚠️ `IMPACT_DECAL_MATERIALS` is currently `["concrete", "metal", "stone",
"wood"]`. Adding a material there without its 3×N files on disk is a silent
miss, not an error — the same failure class as a rejected facade. **That is now
gated**: `tools/persistent/check_decal.py` (built 2026-08-21) cross-reads the
constant and fails the mismatch in both directions, alongside the 256×256 /
alpha / imported / 3-variants checks. It passes all 45 shipped decals unchanged
and was run red on five real failure modes.

---

## 3. M3 — Fire (the centre of the milestone)

### 3.1 What the Director specified, 2026-08-21

**Ignition: explosions only, for now.** Firearms do not set anything alight.
This closes the largest open question in the old plan and keeps `flammability`'s
existing seam — the `ember` wave already lives inside the blast's expanding
front — as the single entry point.

Per material, and the three do **not** share a curve:

| Material | Curve | Extent |
|---|---|---|
| **fabric** | Catches, burns **fastest**, consumes the whole thing | **Entire object**, always |
| **cardboard** | Turns to ember **quickly**, then burns everything too — slightly slower overall than fabric | **Entire object**, always |
| **plywood** | Burns a while **spreading UPWARD**, destroys several voxels, turns to ember, the ember **propagates and destroys a few more at the EDGES**, then goes out | **Partial**, and position-dependent |
| **wood** | Burns quickly, turns to ember, goes out | ✅ already exists (VL-D4) |

**Plywood is the complex one and the only one with a spatial rule:** a grenade
**right at the wall's base** opens a way through; further out burns less. The
detonation already computes distance-from-epicentre per cell (the ring model)
and `carved_side_for()` already consumes epicentre bias, so the input exists.

Two structural notes that fall out of this:

- **"Burns entirely" makes fabric and cardboard object-scoped, not
  radius-scoped.** Fire on them is not a spreading front to be budgeted; it is
  "this object is now gone, over N ticks". That is *simpler* than the general
  case, and it means §3's old "how far does it spread" question only ever
  applied to plywood.
- **Softness is a FIRE property, not a bullet property** (Director:
  *"os mais moles não vão destruir muito mais durante os tiros"*). Already
  honoured in `DESTROY_MIN`, which is derived to hold the destroyed fraction
  near its calibrated reference — see `shot_punch_table.gd`.

### 3.2 The passage rule — ✅ RESOLVED 2026-08-21, and it corrected the question

> Director: *"uma parede comum é feita de um par de slices, uma em cada GU
> anexas. Para o agente passar agachado (ou transpor uma janela), é necessário
> que as duas estejam desobstruídas. Se tiver 4 slices destruídas (2 pares
> empilhados), o agente consegue entrar em pé."*

**All three readings offered above were wrong**, because they assumed the unit
that stacks is a voxel LEVEL. It is a **STOREY**.

⚠️ **VOCABULARY COLLISION, and it caused the wrong question.** The Director's
"slice" is *one storey of wall on one GU face*. The code's `Slice` class is the
**whole** wall face of a GU across `storey_count` storeys (128 voxels for 2
storeys). They are not the same object, and this plan now says **storey-face**
for the Director's unit and `Slice` for the class.

**The rule, unambiguously:**

| Opening | Requirement | Agent |
|---|---|---|
| **CROUCH** (and window traversal) | both storey-faces of the pair clear, 1 storey tall | crouches through |
| **STANDING** | 4 storey-faces clear — 2 stacked pairs, 2 storeys tall | walks through |

**Measured, so the rule is checked and not merely transcribed:** the baked agent
figure is **222 px** against `WALL_FLOOR_STEP_PX = 158` — **1.41 storeys tall**.
A one-storey opening is 0.71 of him (crouch), a two-storey opening is 1.41x him
(standing). The Director's numbers are physically coherent, which the level-based
readings were not.
*(Raw-bake ratio; confirming it against the in-game drawn sprite is a task, not
an assumption.)*

### 3.2a ✅ BUILT — `PassageQuery`, and the one policy question it refused to decide

`godot/scripts/geometry/passage_query.gd`. Pure: reads `Voxel.damage_state`,
writes nothing, so a prediction can ask it about a hypothetical world exactly the
way the committed one is asked.

- `passage_class(edge, registry) -> NONE | CROUCH | STANDING`
- `clear_storeys(edge, registry) -> Array[int]`, ascending

**Written half-thickness-safe on day one**, at no cost: it iterates
`registry.slices_of_edge()` — *the storey-faces that EXIST* — rather than naming
`slice_a` and `slice_b`. A fabric panel with one face will satisfy "both sides
clear" by clearing the one it has. Pinned by a test that removes a sibling the
way the builder eventually will (unregistered, backref cleared) rather than by
pre-destroying it, which §3.2b forbids and which would have made the test assert
nothing.

**Proven on the real map, not only in fixtures** — the M3-1 burn probe reports
`passage_class` over the fabric block's 8 edges before and after:

```
passage_class over 8 edges (baseline):              { "NONE": 8 }
passage_class over 8 edges (after the object burn): { "STANDING": 8 }
```

And the 15 fixture assertions were proven able to fail, against two real breaks:
dropping the adjacency requirement (1 failure — "storeys 0 and 2 → STANDING") and
dropping the every-face requirement (8 failures, starting with an intact wall
reporting STANDING).

⚠️ **OPEN, and deliberately not decided in code: must a passage reach the
ground?** The query answers geometry, not reachability — it reports that an
opening of a given size exists *somewhere* in the wall, and `clear_storeys()`
says where. Two clear storeys at heights 2 and 3 are geometrically STANDING and
practically a hole in the sky. The Director's own sentence covers both cases —
*"passar agachado (ou transpor uma janela)"* — a window is exactly a passage that
does **not** reach the ground, so a blanket "storey 0 only" rule would delete
window traversal. **Whoever wires movement to this needs a ruling**; the data to
apply it is already exposed rather than baked in.

### 3.2b Half-thickness elements — the architectural news

> *"Em geral, vamos fazer elementos com pano, papelão, vidro e madeirite usando
> apenas 1 slice. Vai ser 'meia espessura' de parede, escolhendo uma das duas
> GUs pra posicionar, preferencialmente na de dentro, considerando o contexto de
> um bloco/aposento. Então no caso de uma janela de vidro, ela não é dupla como o
> resto da parede, só cobre uma slice, e fica outra slice livre no vão da janela,
> criando um pouquinho de profundidade."*

**This is the largest single item in the milestone and it is not fire.** Soft
materials and glass are **half-thickness**: one storey-face only, placed on one
of the two GUs — preferably the INNER one, in the context of a block/room. A
glass window covers one face and leaves the opposite face empty inside the
opening, which is what gives the reveal its depth.

⚠️ **The engine cannot do this today.** `SliceGenerator.generate()` creates
**both** slices for every edge, unconditionally — `_create_slice(edge, true)`
then `_create_slice(edge, false)`, with no per-side gate anywhere. Verified by
reading the function, not inferred. Every wall in the game is full thickness by
construction.

What that implies, and why it is worth doing properly rather than faking:

- **Faking it by pre-destroying one side is wrong.** A DESTROYED voxel is a
  hole with soot, damage atoms and a destruction history; an *absent* voxel is
  geometry that was never there. Conflating them would corrupt every census, the
  soot derivation (D24 derives scorch from ABSENT voxels) and the passage query.
- **It simplifies the passage rule for exactly these materials.** A
  half-thickness element has only one storey-face, so "both clear" is satisfied
  by destroying the one that exists. Fabric and cardboard opening a crouch
  passage becomes structural rather than lucky.
- **It needs a mapfile expression** — which side an edge's element sits on — and
  `MAPFILE_REFERENCE`'s versioned-section contract is the place for it.

**New task M3-2b**, ahead of the fire work it enables.

### 3.2c How the builder does it — the technical design

Written against the real chain (`edge_extractor` → `Edge` → `SliceGenerator` →
`EdgeRegistry`), every claim below read from the code rather than assumed.

#### The trap that decides the data shape

`Edge._init()` **canonicalises**: if the face points NW or NE it **swaps `gu_a`
and `gu_b`** so that `gu_a` is lexicographically smaller and `face_a ∈ {SE,
SW}`. So `slice_a` is *not* "the side the author was thinking of" — it is
whichever GU won the sort.

⚠️ **A boolean `side_a` field on the mapfile would therefore mean different
things for different walls**, silently, depending on which way the author drew
it. This is the same class of defect as the `P3_WEAPON`/`GRIP_SUFFIX` output
collisions: a value that is correct at the author's end and wrong after a
normalisation nobody remembers.

**So the mapfile expresses the side as an ABSOLUTE GU CELL** — "the face lives
on GU (x, y)" — and `Edge` resolves it to a/b **after** canonicalisation. The
author's meaning survives the swap because the cell survives it.

#### The change, file by file

| File | Change |
|---|---|
| `edge.gd` | New `var occupied_sides: int` (both / a-only / b-only), plus a resolver that takes the authored GU cell and answers after canonicalisation. Default = both, so every existing edge is unchanged by construction |
| `slice_generator.gd` | The gate. `generate()` today calls `_create_slice(edge, true)` then `_create_slice(edge, false)` unconditionally; each becomes conditional on `edge.occupied_sides`. **This is the only place a slice is born**, which is why the change is small |
| `edge_extractor.gd` | Carry the authored side through the `edge_groups` dedup. Note it dedups by `edge.id`, so two authored entries for one edge must agree or fail loudly |
| MAPFILE | A new versioned section (or a field on the existing wall/block entries), per `MAPFILE_REFERENCE`'s owner-registered contract. Unknown sections round-trip verbatim, so old maps are unaffected |

#### What already tolerates a missing sibling — checked, not hoped

- **`EdgeRegistry.sibling_slice()` returns null cleanly.** When `slice_b_id` is
  empty, `get_slice("")` is null and the function returns null without reaching
  its `push_error` (which only fires when a slice is not part of its own edge).
- **Both real consumers already null-check.** `sibling_slice()` has exactly two
  non-selftest callers, both in `blast_calculator.gd`'s point-impact path
  (`plan_point_impact`), and both are already guarded — `current_slice == null`
  breaks the depth loop, and the cascade is behind `sibling != null`.
- **`all_slices()` iterates what is registered**, so an absent slice is simply
  absent everywhere it is consumed (`room.gd` ×4, `room_builder`,
  `detonation_plan_builder`).

#### What does NOT tolerate it — the real work

1. **`voxel_renderer.gd:1892`** resolves a neighbour's slice with
   `... else registry.get_slice(neighbor_edge.slice_b_id)` as its final fallback.
   With a half-thickness neighbour that returns **null**, and the expression has
   no null branch. First thing to fix, and the first thing to selftest.
2. **Junction columns are edge-derived and side-blind.** `JunctionResolver.resolve()`
   iterates `registry.all_edges()` and reads `edge.face_a/face_b`; it never looks
   at slices. So a half-thickness element still produces a **full** corner
   column, which will read as a full-thickness stub beside a half-thickness
   panel. Needs a decision: skip the column, or half it too.
3. **Occlusion and the passage query** must both be written against
   "the storey-faces that EXIST", not "both storey-faces". For a half-thickness
   element `passage_class()` is satisfied by the one face that exists — which is
   the point: fabric and cardboard open a crouch passage structurally rather
   than luckily.

#### The rule that must not be broken

**Do not fake half thickness by pre-destroying one side.** A `DESTROYED` voxel
is a hole with soot, a damage atom and a history; an **absent** voxel is
geometry that was never there. Conflating them corrupts the per-material census,
D24's soot derivation (which derives scorch from ABSENT voxels), and the passage
query itself. The slice must never be created.

#### How it gets proven

- A selftest generating a half-thickness edge and asserting: one slice
  registered, `sibling_slice()` null, `plan_point_impact()` still terminates,
  `passage_class()` answers CROUCH on one destroyed storey-face.
- A **real capture** of a glass window on PLAYGROUND showing the empty opposite
  face inside the opening — the depth the Director asked for is a visual claim
  and needs a visual proof.
- `roof_bake_selftest` re-run: a half-thickness wall changes roof lookup
  coverage, which is exactly what that test measures.

### 3.3 What is a tick — ✅ DECIDED 2026-08-21: delta, for now

> Director: *"Eu gosto da ideia de ir avançando, mas pra isso o fogo precisa
> ficar existindo em looping enquanto o jogador pensa, pra não ficar congelado. É
> ousado, mas pode ficar bom. Por enquanto temos apenas eventos que disparam e
> acabam, então o delta seria o mais apropriado. Mas podemos testar essa
> proposta."*

**v1 advances on `delta`**, and the reasoning is the honest one rather than the
tidy one: the previous recommendation here was turn-based, and the Director's
objection defeats it — a per-turn fire that is *frozen* between turns does not
read as fire. Making it read right during the player's thinking time is a
**looping, continuously-alive effect**, and every VFX this project has is a
fire-and-forget event that starts and ends. Building the looping variant is a
bigger claim than building fire.

**So the turn-based version is a PROPOSAL to test, not a rejected option** —
Director: *"podemos testar essa proposta"*. The seam to keep open: whatever
advances the burn should be one function called from one place, so swapping
`_process(delta)` for `player_turn_started` is an edit at that call site rather
than a rewrite. Do not scatter delta arithmetic through the burn state.

### 3.4 What is already free

Light does not read `damage_state`. `VoxelRenderer.build_occupancy()` is built
from `TileMapLayer.get_used_cells()`, and a DESTROYED voxel has its cell
**erased**. So "cardboard blocks light until it burns" needs **no opacity state
and no coupling to `LIGHT_MASTER_PLAN`** — it is a property of burning being
real destruction. Bump `room.bump_world_revision()` on every burn tick or
predictions go stale (`PREDICTION_MASTER_PLAN` §5.2).

### ✅ M3-1 — MEASURED 2026-08-21, and the claim is half right

`INFILTRAITOR_CAPTURE_ACTION=light_burn_probe` (`room.gd::_capture_light_burn_probe`),
four passes in ONE boot on PLAYGROUND's fabric block:

```
CONTROL   (nothing destroyed)      cells_gone=   0  bucket_changed=  0
ONE VOXEL ((247, 24) lvl 0)        cells_gone=   1  bucket_changed=  2  (brighter 2 / darker 0)
WALLS     (2047 more voxels)       cells_gone=1984  bucket_changed=260  (brighter 260 / darker 0)
OBJECT    (+1672 slab voxels)      cells_gone=3080  bucket_changed=262  (brighter 262 / darker 0)
```

**The control reports 0**, which is what makes the other three numbers mean
anything. **The visual half of §3.4 is CONFIRMED**: a single destroyed voxel
moves the light field with no opacity state and no coupling to
`LIGHT_MASTER_PLAN`, and every cell it moves gets *brighter*. Captures:
`burn_fabric_1_intact.png` → `burn_fabric_3_object.png`.

**But the lamp's shadow does not move at all.** Measured in the same boot:

```
shadow map after the burn: 3 of the burnt GUs are STILL in _blocked_cells [(31,3), (32,3), (33,3)]
```

`ShadowProjector` runs on `_blocked_cells` / `_obstacle_heights`, a
**GU-resolution** structure `RoomBuilder` builds and `LightingController` re-feeds
only on a rebuild. Nothing in the destruction path touches it. So *"cardboard
blocks light until it burns"* is free for the **visual shading** and **not free**
for the **cast shadow** — a burnt-away wall still throws one. That is a task M3-3
owns and did not know it had.
*(Canon note: this is not a contradiction of "visual brightness ≠ tactical
visibility" — it is that split showing up as work. The visual side came free
because it reads occupancy; the tactical side did not because it does not.)*

**Two more findings, both from looking at the capture rather than the code:**

- **"Burns entirely" cannot be expressed as "destroy the edges."** A fabric block
  is 16 `Slice`s *plus* `FLOOR` (1152 voxels) and `CEILING` (520) `Slab`s. The
  first run destroyed every fabric Slice and photographed a block still standing.
  M3-3's object scope has to span **both registries**.
- **An object that burns entirely leaves its JUNCTION COLUMNS standing.** Four
  dark posts survive with 0 fabric voxels left, proven against a
  `INFILTRAITOR_SKIP_JUNCTIONS=1` control run where they vanish
  (`burn_fabric_nojunc_3_object.png`). This is the same side-blindness §3.2c
  already flagged for half-thickness elements — `JunctionResolver` is
  edge-derived and never looks at a slice — arriving from the other direction.

⚠️ **A note on reading these captures.** `voxel_destroyed` fires per voxel and
room.gd dispatches it to the smoke/debris overlays, so erasing 3 080 cells in one
frame raises a dust cloud that HIDES the hole it is announcing. Three runs
photographed a pale mass where the wall had been; it took the census (0 fabric
voxels intact, 3 080 cells gone) to establish the geometry really was gone. The
probe now waits `INFILTRAITOR_BURN_PROBE_SETTLE_FRAMES` (240) before the last
frame.

### 3.5 Explicitly OUT of M3 v1

- **Fire damaging actors.** Nothing in the project takes damage from the world;
  that is `GAME-01`'s.
- **Fire making noise / drawing guards.** `docs/systems/noise.md` owns it. Named
  as the first extension because it is exactly the emergent stealth consequence
  the design wants.

### 3.6 M3 task order

| # | Task | Depends on |
|---|---|---|
| ~~**M3-0**~~ | ~~pin §3.2's unit~~ — ✅ **CLOSED**: the unit is the STOREY, not the level; and §3.3's tick is `delta` for v1 | — |
| ~~**M3-1**~~ | ~~Measure §3.4's free win~~ — ✅ **CLOSED 2026-08-21**: the visual field is free (control 0, one voxel 2, object 262, all brighter); the lamp's shadow is NOT (3 burnt GUs still in `_blocked_cells`) | — |
| ~~**M3-2**~~ | ~~`passage_class()`~~ — ✅ **BUILT 2026-08-21**, `godot/scripts/geometry/passage_query.gd`, 15 assertions + real-map evidence (NONE ×8 → STANDING ×8) | M3-0 |
| **M3-2b** | **Half-thickness elements** (§3.2b) — one storey-face per edge, mapfile-expressed, NOT faked by pre-destroying a side | M3-2 |
| **M3-3** | Burn state + a delta tick behind ONE advance call; fabric and cardboard only (object-scoped, no spread logic) | M3-1, M3-2b |
| **M3-4** | Plywood: upward spread, ember phase, edge propagation, base-proximity gating | M3-3 |
| **M3-5** | **Grenade and shot test matrix** on PLAYGROUND's five blocks — the census print per material, plus a filmstrip per material (`build_filmstrip.py`) | M3-4 |

---

## 4. M4 — Glass

### 4.1 The rendering problem, in the Director's words

> *"vamos precisar de um blend mode — porque queremos ver a textura dele por
> cima do fundo, mas com transparência, tentando não usar opacidade pura, pra
> não ficar lavado."*

Confirmed visually: in `mat_block_02_lit_five_materials.png` the glass block
reads as glass in colour and pattern and is **completely opaque**.

**Why this is not a one-line change, stated honestly up front.** Every voxel
reaches the tilemap through `set_cell()` on a `TileMapLayer` (architecture Rule
8), and the material's colour arrives by **MULTIPLY** at bake time. Both facts
fight transparency:

- The bake composites to a static atlas page, so "see the background through it"
  cannot be resolved at bake time — the background is not known there.
- Straight alpha on the tile is the *"opacidade pura"* the Director is
  rejecting: it washes the texture out by averaging it toward whatever is
  behind.

The shape that answers it is a **blend other than alpha** — screen/add for the
highlights plus a multiply for the tint, i.e. glass as a *modulation* of what is
behind rather than a layer over it. That is a shader/canvas-blend question at
the layer level, not a per-tile one, and it is the first thing in this project
that wants a `TileMapLayer` of its own with its own blend mode. **Rule 8 is not
violated by that** — the voxels still arrive via `set_cell()`; only the layer's
compositing changes.

### 4.2 The destruction problem

> *"em alguns casos vai deixar buraco, em outras destruir completamente"*

Still the open one from `DESTRUCTION_MASTER_PLAN`: **what is a "whole window"?**
Voxels have no grouping; the nearest existing structure is the edge's slices.
Whether a pane is derived from contiguous glass cells or authored in the mapfile
is the decision that sets how big M4 is.

Two smaller items already found and carried:

- **A far shotgun pellet CRACKS glass, contradicting D22's hole-or-nothing.**
  `damage_state_for()` returns CRACKED below `PUNCH_DENT_MIN` (0.30), and a
  pellet at the end of the shotgun's distance ladder computes
  `3.0 × 0.24 × 0.15 × 0.85 / 0.4 = 0.23`.
- **Glass's no-DENTED rule is a coincidence of two equal numbers.**
  `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN` are both 0.30, which makes the
  DENTED band exactly empty. Ratified behaviour arriving by accident rather
  than by construction.

**Both are STILL OPEN, and deliberately so.** MAT-SOFT-01 built the mechanism
that fixes them — `HOLE_ONLY_MATERIALS` makes "this material cannot be marked" a
tier capability rather than a threshold — and glass was left out of the array on
purpose. D22 gives glass the same *no-mark* half but the **other** answer to a
weak hit: *"é buraco feito, ou não feito"*, where the soft materials always
fura. "Not made" needs an **INTACT** return that `damage_state_for()` has never
produced and whose callers do not handle (`plan_point_impact()` would append a
plan entry for a tier meaning "nothing happened"). That is one more branch than
this milestone's soft-material ruling needed, on the material the Director
explicitly put last. **M4b adds glass to `HOLE_ONLY_MATERIALS` and the INTACT
branch together**, or neither.

---

## 5. M5 — Voxel props

> *"vai servir para destruir cenários com props de voxels (serão classes
> diferentes dos props com sprites)"* … *"caixas, tapumes, andaimes, toldos"*

**This is what the soft materials are for.** A prop is already built from
dictionary materials — `PropDef.material_zones`, and `props/crate_full.json` is
literally `{"default": "wood"}`. A cardboard crate is that file with one word
changed: **no new art, no new schema.** Burning a crate and burning a wall are
the same mechanism over the same voxels, which is why M3 comes first.

⚠️ **The blocker, recorded rather than discovered later.**
`ART_SPECIFICATIONS.md` §5 states the v1 prop renderer **ignores `layers` and
renders props as solid GU blocks**, and that pinning the row/level ordering is
an ART-01 deliverable. So:

- a **crate** (solid) works today;
- a **toldo / tapume / andaime** (thin, non-solid) needs **renderer v2**.

The Director's own framing — voxel props as a class distinct from sprite props —
is the same seam. M5 is where that class gets defined.

---

## 6. M6 — Fluids (research first, no design yet)

> *"a possibilidade de criar água/lava, usando fluxo de voxels, ou só um
> algoritmo de movimentação, que possa fazer eles subindo e descendo, mudando de
> cor, brilho, se usa textura ou não… Precisamos estudar como a indústria lida
> com isso, e como funciona essa física."*

**Explicitly a research task, not a build task**, and it is last for a reason:
it is the only part of this milestone with no ratified design, and the Director
has named the study as the deliverable rather than the feature.

What the study has to come back with, so it is not an open-ended read:

1. **Which of the two shapes** — real per-voxel flow (cellular automaton:
   pressure, settling, equalisation) versus a **height-field** with a moving
   surface. The second is what most tile/voxel games actually ship; the first is
   what people imagine they need.
2. **Turn-based or continuous.** Same question §3.3 asks of fire, and the answer
   should probably match.
3. **Cost against this project's real constraint**, which is *not* CPU: RAM
   (D42) and the fact that **the TileSet rebuild is charged once per FRAME THAT
   MINTS**. A fluid that re-mints tiles every frame is the worst possible shape
   for this renderer, and that is a project-specific finding no industry article
   will mention.
4. **What it is FOR.** Lava and water are different games — one is a hazard, one
   is a route/noise surface. A stealth game may want neither, or want only
   still water that reflects light.

No task list until the study lands.

---

## 7. Task order, one list

| Order | Task | Blocked by |
|---|---|---|
| ✅ | **M1** — five materials register, render, break, and are lit | done |
| ✅ | **M3-0** — pin the passage unit (§3.2) — the STOREY | done |
| ✅ | **MAT-SOFT-01** — soft materials are hole-or-nothing, in code and data | done |
| ✅ | **M2a** — the brick art order + `check_decal.py`, earned before the art | done |
| 1 | **M2b** — the nine brick PNGs | **Director (art)** |
| 2 | **M2c** — wire `brick` into `IMPACT_DECAL_MATERIALS`/`IMPACT_CRACK_MATERIALS` + manifest + capture | M2b |
| ✅ | **M3-1** — measure the light win — the visual half is free, the cast shadow is not | done |
| ✅ | **M3-2** — `passage_class()` + selftest | done |
| 4b | **M3-2b** — half-thickness elements (the milestone's largest single item, and it is not fire) | M3-2 |
| 5 | **M3-3** — fabric + cardboard burn (object-scoped, delta tick) | M3-1, M3-2b |
| 6 | **M3-4** — plywood burn (upward, ember, edges, base-gated) | M3-3 |
| 7 | **M3-5** — grenade + shot test matrix, filmstrip per material | M3-4, M2 |
| 8 | **M4a** — glass blend mode (its own layer) | Director: glass LAST |
| 9 | **M4b** — glass pane break + `HOLE_ONLY_MATERIALS` + the INTACT branch | design |
| 10 | **M5** — voxel prop class | M3, renderer v2 |
| 11 | **M6** — fluid research | — |

**Glass moved to the end of the queue on 2026-08-21**, Director's call: it is
*"um caso à parte"* needing its own crack/hole algorithm. M4a used to be the
"something visible without waiting" item and no longer is — **M3-1 and M3-2 are
now the two that need nothing from anyone**, and M3-2b is the critical path.

⚠️ **One measurement this milestone owes itself.** MAT-SOFT-01 moved fabric from
19 voxels lost per shotgun burst to **36**, and plywood to 38, because every
pellet now breaches and takes its neighbours *and* the sibling slice. That is
the honest consequence of *"sempre fura"* and it is not obviously wrong for a
shotgun against cloth — but `neighbour_count_for()` reads RAW punch, which for
fabric (resistance 0.30) is ~7 against `NEIGHBOUR_PUNCH_FULL` 1.60, i.e. pinned
at all 8 neighbours for every weapon in the arsenal. **Whether a PISTOL should
also erase 9 voxels of cloth is a calibration question, and it belongs to M3-5's
matrix**, where it can be measured per weapon rather than guessed at here.
