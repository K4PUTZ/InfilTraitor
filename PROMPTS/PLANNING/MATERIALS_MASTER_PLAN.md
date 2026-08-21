# MATERIALS_MASTER_PLAN
## The materials milestone — burn, breach, see through, and flow — v1.0

**Status:** 🟡 **v1.0 — the design is captured and ordered; M1 is the only part
already built.** One open sub-question (§3.2), flagged rather than guessed.
**Written:** 2026-08-21, against `b9a46b15`.
**Supersedes:** `BURN_THROUGH_MASTER_PLAN` (v0.2), which becomes this document's
§4 — that plan was opened before the Director described the full wave, and a
plan named after one of five parts is the wrong container. Nothing in it is
retracted; §2 (the cascade ceiling) and §3b (the fire curves) are carried here
verbatim in substance.
**Companions:** `DESTRUCTION_MASTER_PLAN` (owns how anything becomes broken
voxels), `VOXEL_LIGHT_MASTER_PLAN` (the ember, the light field),
`docs/systems/LIGHT_MASTER_PLAN.md`, `ASSETS/ART_SPECIFICATIONS.md` (§7 decals),
`PROMPTS/ART_ORDER_NEW_MATERIALS.md` (the five facades, delivered 2026-08-21).

---

## 0. What this milestone is

Nine materials exist. Five arrived on 2026-08-21 and render correctly
(`mat_block_02_lit_five_materials.png`). **None of what makes them
*interesting* is built.** This plan is the ordered list of that.

| Part | What | Size |
|---|---|---|
| **M1** | The five materials exist, render, and break | ✅ **DONE** |
| **M2** | Decals — the marks each material takes | Small, art-led |
| **M3** | Fire that consumes and opens passages | **Large.** The milestone's centre |
| **M4** | Glass: seeing through it, and breaking it non-locally | Medium + one hard rendering question |
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

**21 files, and only these:**

| Family | Materials | Files | Why not the rest |
|---|---|---|---|
| `bullet` | cardboard, fabric, plywood, brick | 12 | The Director's own ask. A hole in fabric reads nothing like one in concrete |
| `dent` | brick, plywood | 6 | Soft materials tear rather than dent |
| `crack` | brick | 3 | D32.6 — only rigid mineral materials fracture |

Glass gets none: D22, DESTROYED-only.

**M2 tasks:** author → `check_facade.py`-equivalent measurement → add each
material to `VoxelRenderer.IMPACT_DECAL_MATERIALS` → capture.

⚠️ `IMPACT_DECAL_MATERIALS` is currently `["concrete", "metal", "stone",
"wood"]`, and its comment still says *"glass and brick deferred"*. Adding a
material there without its 3×N files on disk is a silent miss, not an error —
the same failure class as a rejected facade. Add the id **only** once the files
measure clean.

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

### 3.2 The passage rule — ratified in intent, ONE number open

> *"A passagem pra existir precisa ter pelo menos 1 par de slices desobstruídas
> na base das GUs — o agente se agaixa, e entra. Se conseguir abrir 2 pares
> verticais (panos, papelão), o agente consegue entrar em pé."*

So: **1 → crouch, 2 → standing**, measured at the base, and the pair is the
front/back pair (a *through-pair*, §1) rather than two neighbours on one face.

⚠️ **What "1 pair" spans horizontally and vertically is NOT yet pinned, and the
answer changes how hard a passage is to make by a large factor.** §1's
measurement is why this cannot be guessed: a level is **1/8 of a storey**, and
the agent is authored *"standing slightly taller than a slice"* — so one level
is roughly a quarter of the agent's height. Read literally, "1 pair" = one cell
through = an opening ~¼ agent tall and ⅛ GU wide, which nothing crouches
through. The intent is clearly larger than the literal reading, so the unit
needs naming. Candidates:

| Reading | "1 pair" means | Crouch opening | Comment |
|---|---|---|---|
| **A** | one whole LEVEL of the base row, both slices (8 cells × 2) | ⅛ storey tall, full GU wide | A letterbox — wide and very short |
| **B** | one whole STOREY of the wall, both slices (64 × 2) | full storey | Then "2 pares" = two storeys, and standing needs a two-storey hole |
| **C** (recommended) | a contiguous block **4 levels tall** through both slices | ~half agent height | Matches "crouch" physically; "2 pairs" = 8 levels = one storey = standing |

**C is a recommendation, not a decision.** It is the only reading where the
words *crouch* and *standing* map onto real proportions, but it invents a
number (4) the Director did not say. **This is the one thing M3 cannot start
without.**

Independent of which reading wins, the rule is a **pure query over committed
state**, which is worth stating because it makes it cheap and testable:
`passage_class(edge) -> NONE | CROUCH | STANDING`, reading `damage_state ==
DESTROYED` across the two sibling slices. No new storage, no new writer, and it
can be selftested against a synthetic slice pair long before fire exists.

### 3.3 What is a tick

The game is turn-based. `TacticalTurnManager` already emits
`player_turn_started` and `enemy_phase_started`. **Fire advances on turn
boundaries, not on `delta`** — a stealth game whose fire spreads in real time
while the player thinks is a different game, and a per-turn burn is legible and
predictable in a way a timer is not. (Recommendation carried from the previous
plan; still unratified, but nothing contradicts it.)

### 3.4 What is already free

Light does not read `damage_state`. `VoxelRenderer.build_occupancy()` is built
from `TileMapLayer.get_used_cells()`, and a DESTROYED voxel has its cell
**erased**. So "cardboard blocks light until it burns" needs **no opacity state
and no coupling to `LIGHT_MASTER_PLAN`** — it is a property of burning being
real destruction. Bump `room.bump_world_revision()` on every burn tick or
predictions go stale (`PREDICTION_MASTER_PLAN` §5.2).

⚠️ Read off the code, not measured. **Task M3-1 is the measurement**, against a
same-boot control.

### 3.5 Explicitly OUT of M3 v1

- **Fire damaging actors.** Nothing in the project takes damage from the world;
  that is `GAME-01`'s.
- **Fire making noise / drawing guards.** `docs/systems/noise.md` owns it. Named
  as the first extension because it is exactly the emergent stealth consequence
  the design wants.

### 3.6 M3 task order

| # | Task | Depends on |
|---|---|---|
| **M3-0** | Pin §3.2's unit with the Director | — |
| **M3-1** | Measure §3.4's free win: force one fabric voxel DESTROYED, capture the light field vs a same-boot control | — |
| **M3-2** | `passage_class(edge)` as a pure query + selftest on a synthetic slice pair | M3-0 |
| **M3-3** | Burn state + the turn tick; fabric and cardboard only (object-scoped, no spread logic) | M3-1 |
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
| 1 | **M3-0** — pin the passage unit (§3.2) | Director |
| 2 | **M2** — 21 decal files + `IMPACT_DECAL_MATERIALS` | art |
| 3 | **M3-1** — measure the light win | — |
| 4 | **M3-2** — `passage_class()` + selftest | M3-0 |
| 5 | **M3-3** — fabric + cardboard burn (object-scoped) | M3-1 |
| 6 | **M3-4** — plywood burn (upward, ember, edges, base-gated) | M3-3 |
| 7 | **M3-5** — grenade + shot test matrix, filmstrip per material | M3-4, M2 |
| 8 | **M4a** — glass blend mode (its own layer) | — |
| 9 | **M4b** — glass pane break | design |
| 10 | **M5** — voxel prop class | M3, renderer v2 |
| 11 | **M6** — fluid research | — |

**M2 and M3-1 can run in parallel with M3-0**, and M4a is independent of all of
it — if the Director wants something visible early, glass's blend mode is the
one part of this plan that changes a screenshot without waiting on anything.
