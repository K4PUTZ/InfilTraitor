# GLASS MASTER PLAN — the physics of glass

**Status:** 🟡 v1.0 — DESIGN RATIFIED 2026-08-30, UNBUILT
**Owns:** `MATERIALS_MASTER_PLAN` M4a + M4b, which this document supersedes in
detail. That plan keeps the milestone row; this one keeps the design.
**Opened:** 2026-08-30, immediately after `DETONATION_PRESENTATION_MASTER_PLAN`
closed. Glass is the Director's one named explosion follow-up.

> Director, 2026-08-30: *"Ele tem que ter uma transparência em relação ao que tem
> atrás, que é independente da oclusão, mas uma característica própria. […]
> precisamos ainda pensar em como fazer o vidro rachar, se estiver perto de uma
> explosão, mas não dentro da área de dano. Quebrar efetivamente quando estiver,
> estilhaçando mais ou menos, e deixando mais ou menos sobras na borda da janela,
> da porta, etc. […] Pistola, normalmente o tiro fura o vidro, e cria aquele
> padrão de ondas rachadas ao redor. Fuzil normalmente faz um buraco grande ou
> quebra totalmente a vidraça também."*

---

## 0. Scope — and what this plan deliberately does NOT do

> Director, 2026-08-30: *"Não precisa fazer a janela ainda, vamos só trabalhar na
> física do vidro por enquanto e depois construímos as aplicações com ele no
> cenário."*

**IN:** transparency, pane identity, the non-local break, remnants on the frame,
cracking, floor shards, the per-weapon patterns, projectile pass-through, and the
art order that all of it needs.

**OUT, by explicit ruling, and each one recorded rather than forgotten:**

| Deferred | To | Why it is not here |
|---|---|---|
| **A real window** (brick sill · glass · brick lintel on one face) | the scenario applications | Needs level bands on a face — a geometry reform. §9 states its full cost so the day it is scheduled nobody re-derives it |
| **Shard noise** | the sound milestone | *"Ainda não implementamos o som, ele vai ser uma parte crucial do jogo, inclusive com interface visual no cenário."* The shard STATE is built here; its gameplay consumer is not |
| **The agent walking through a broken pane** | the movement milestone | *"Com a janela de verdade vamos poder criar a passagem, e fazer o agente atravessar, na milestone de movimentação"* |
| **The see-through vision roll** (G-D7) | the scenario applications | It needs two rooms and a window between them to mean anything. Designed here, built there |

**The test bed is what already exists:** PLAYGROUND's two glass panels at
`(25,8) SE` and `(29,8) SW`, 2 storeys each, plus the glass block at gu x=38.
The Director's note on blocks stands: *"paredes de escritório envidraçadas, ou
mesmo divisórias, mas blocos acho que não. De qualquer forma é desejável que a
física permita a existência deles."* — blocks stay physically supported, they are
just not the target case.

---

## 1. Decision register

| # | Decision | Status |
|---|---|---|
| **G-D1** | **Transparency is a BLEND, never alpha.** *"queremos ver a textura dele por cima do fundo, mas com transparência, tentando não usar opacidade pura, pra não ficar lavado."* Glass modulates what is behind it; it is not a translucent layer over it. Independent of occlusion — a pane is see-through even when nothing is being occluded | ✅ Ratified 2026-08-30 |
| **G-D2** | **A pane is one continuous surface; a block is one block.** *"O vidro é uma coisa só, desde que seja a mesma superfície contínua. Um bloco é um bloco."* | ✅ Ratified 2026-08-30 |
| **G-D3** | **Glass CRACKS — ⚠️ this amends D22.** D22 ruled glass DESTROYED-only (*"não vai ter dented; é buraco feito, ou não feito"*), with `dent_factor` and `crack_factor` pinned to 0.0 so the rule read as intent. The Director now wants glass to crack near a blast it survives, and to craze around a bullet hole. **The amendment is narrow: CRACKED returns, DENTED stays impossible** — glass does not deform, it fractures. See §6.1 for the two accidents this converts into intent | ✅ Ratified 2026-08-30, amends D22 |
| **G-D4** | **Neighbours of a shot on glass may be CRACKED — ⚠️ this amends D30.1.** D30.1 says *"vizinhos destruídos mas sem marca própria"*, to prevent a spray of separate round holes. A crack web is the opposite of a spray: it is ONE fracture that spans cells. The exception is glass-only and is justified by that distinction, not by convenience | ✅ Ratified 2026-08-30, amends D30.1 for glass only |
| **G-D5** | **A projectile passes through glass and strikes what is behind it.** *"Sim, atravessa e bate no fundo."* ⚠️ Amends the reading of D28 (*a fully-penetrated path leaves no mark anywhere*): here the glass keeps its hole AND the round continues | ✅ Ratified 2026-08-30 |
| **G-D6** | **Shards are game state, not decoration.** *"Cacos fazem barulho sim, é estado de jogo, e enriquece o gameplay."* They persist, they are saved, and the sound milestone will read them | ✅ Ratified 2026-08-30 |
| **G-D7** | **Seeing through glass is a ROLL, driven by proximity, pane count and a light differential.** *"o guarda tem uma chance de enxergar através do vidro intacto, caso tanto o guarda quanto o agente estejam próximos do vidro. Mas se forem duas vidraças no caminho a chance cai bastante. […] a sala iluminada é fácil de ver de fora, quando está escuro. Ao passo que quando está claro lá fora é ao contrário: fica bem mais difícil de ver dentro, e vice-versa."* | ✅ Design ratified 2026-08-30 · **build deferred to the applications** |
| **G-D8** | **A broken pane opens a passage, barely moves the light, and raises detection one step.** *"Com certeza, mas não influencia tanto na luz, apenas aumenta um pouco de intensidade e sobe um grau de detecção no mecanismo stealth."* | ✅ Ratified 2026-08-30 · build deferred (movement milestone) |

---

## 2. The seams that already exist — verified 2026-08-30, not remembered

Every row was read out of the file named. This section exists because three of
them changed the size of this plan.

| Seam | Where | What it means here |
|---|---|---|
| **A slice knows its edge and holds its voxels** | [`slice.gd:6-14`](../../godot/scripts/geometry/slice.gd) — `id`, `edge_id`, `material`, `voxels: Array[Voxel]` (64 per storey) | The pane grouping the old plan called *"a design question with a cost difference"* is a field that already exists. `voxel.container_id()` → `Slice` → `edge_id` → every voxel of that surface |
| **A panel is a half-thickness single face** | [`map_sections_v1.gd:162`](../../godot/scripts/world/maps/persistence/map_sections_v1.gd), [`edge_extractor.gd:203`](../../godot/scripts/geometry/edge_extractor.gd) | The pane, as an authored object. Two exist in PLAYGROUND |
| **A block dissolves into exposed faces** | `edge_extractor.gd` second pass — `solidblock_occupancy` keyed `"x,y,storey"`, buried faces culled | ⚠️ No block id survives extraction. G-D2's *"um bloco é um bloco"* has to be derived where the occupancy map is still alive (§4.2) |
| **`PassageQuery` is complete and unread** | [`passage_query.gd:186`](../../godot/scripts/geometry/passage_query.gd); the only two call sites are a `print` and a `print_debug` in `room.gd` | It already handles half-thickness explicitly (*"a fabric panel or a glass window will have ONE [face]"*). Destruction has never opened a passage for ANY material |
| **Vision reuses the movement edge set** | [`guard_enemy.gd:689`](../../godot/scripts/agents/guard_enemy.gd) `can_see_cell()` takes `blocked_edges` | Glass blocks sight today exactly like concrete. G-D7 is the ruling that splits "blocks the body" from "blocks the eye" |
| **A blocked edge has no material** | [`map_geometry.gd:151`](../../godot/scripts/world/maps/map_geometry.gd) — `{"from": Vector2i, "to": Vector2i}` | The gameplay grid and the `Edge`/`Slice` geometry are two disconnected representations. G-D7 and G-D8 are what force a bridge |
| **Nothing in the game makes noise** | `NoiseSystem` is complete and instantiated ([`room.gd:1401`](../../godot/scripts/world/room.gd)); `emit()` has **zero call sites** | G-D6's shards will be the first real noise source — in the sound milestone |
| **Noise→detection is gated backwards** | [`turn_controller.gd:200`](../../godot/scripts/world/controllers/turn_controller.gd) — `if noise_intensity > 0.0 and result.visible` | Noise only raises detection when the guard ALREADY sees the agent. Recorded here because the sound milestone must fix it or shards are inert by construction |
| **Tactical visibility is already per-cell** | [`exposure_system.gd`](../../godot/scripts/systems/lighting/exposure_system.gd) — visibility class 0–4 with detection multipliers | G-D7's light differential reads this, NOT the render brightness. `LIGHT_MASTER_PLAN`'s standing distinction survives |
| **The projectile stops at a blocked edge** | `select_line_impact()` / `select_cone_pellet_impacts()` take `_blocked_edges_dict()` | G-D5 is one rule in the pellet flood, not a new system |
| **Glass reaches the cascade ceiling** | `shot_punch_table.gd` — glass `RESISTANCE` 0.40, worst case punch 8.82 | Already measured and documented; the selftest exclusion was retired with a number, not a guess |

**Evidence for the opacity claim:** `Screenshots/history/mat_block_02_lit_five_materials.png`
— the glass block reads as a solid painted pale blue-green, fully opaque.

---

## 3. G1 — Transparency

### 3.1 Why the bake cannot answer it

Every voxel reaches the tilemap through `set_cell()` (architecture Rule 8) and
the material's colour arrives by MULTIPLY at bake time. The background is not
known at bake time, so "see through it" is unreachable there. And straight alpha
is the *"opacidade pura"* the Director rejects: it averages the texture toward
whatever is behind and washes it out.

### 3.2 The shape

Glass cells move to their **own `TileMapLayer` on the same level**, drawn
immediately after that level's opaque layer, with its own
`CanvasItemMaterial.blend_mode`. **Rule 8 is intact** — the voxels still arrive
via `set_cell()`; only the layer's compositing changes.

**Two sublayers, because one blend cannot be glass:**

- **MUL** — the tint. Darkens and colours what is behind while *preserving* the
  facade's grayscale pattern instead of averaging it away. This is the half that
  answers *"ver a textura dele por cima do fundo"*.
- **ADD** — the highlights. The bright streaks and reflections. This is the half
  that makes it read as glass rather than as tinted air.

Draw order works with the isometric painter's algorithm for free: the glass
sublayers sit between their own level's opaque layer and the next level up, so
glass composites over everything already drawn beneath it and everything drawn
later (higher levels, the agent) draws over the glass. Correct in both directions.

Layers are created **lazily, only for levels that actually contain glass**. The
TileSet rebuild is charged once per frame that mints, so this adds a one-time
layer, not a per-frame cost.

### 3.3 ⚠️ The risk, stated before it is discovered

`voxel_face_shading.gdshader` differentiates the three faces by **multiplying**.
On an ADD layer, multiplication means something else. The glass sublayers need
their own shader variant, or the face differentiation behaves differently there.
Not blocking, not free.

---

## 4. G2 — Pane identity

A `pane_id` is stamped on every glass slice at extraction time. One concept, two
producers, one consumer (the cascade).

### 4.1 Panels — contiguous coplanar surfaces

Adjacent glass panels sharing a plane are one pane. A union-find over the
extracted glass edges, run **once at map load**, never per shot.

### 4.2 Blocks — the connected component of the occupancy map

⚠️ The block's identity is destroyed by extraction: the second pass emits exposed
faces from `solidblock_occupancy` and no block id survives. So G-D2's *"um bloco
é um bloco"* must be derived **inside the extractor**, where the occupancy map is
still alive — a flood fill over contiguous `solidblock_glass` cells, stamped onto
every face those cells emit.

Doing it later is possible and wrong: the buried faces are already gone, so a
later derivation would be reconstructing a shape from its silhouette.

---

## 5. G3/G4 — The break

### 5.1 The cascade

A hit that crosses the pane's shatter threshold takes **the whole pane**:
iterate the slices carrying that `pane_id`, mark every voxel DESTROYED. Below the
threshold, damage stays local — a hole and its neighbours, per the existing
ladder.

**One new tuning number:** `pane_shatter_punch`. That is the entire difference
between the Director's *"buraco grande"* and *"quebra totalmente a vidraça"*, and
keeping it to one number is deliberate — a second knob would make the two
outcomes un-diagnosable from the `[SHOT]` line.

**⚠️ This runs in the COOK, never in the presenter.** The whole detonation
architecture is *the world changes once; the effects are what is animated*. A
pane break is a plan decision. It belongs in `build_plan()`'s `WorldDelta`, with
`delta.commit()` as the only writer, and it must
`room.bump_world_revision()` like every other committed mutation
(`PREDICTION_MASTER_PLAN`'s standing rule).

### 5.2 Remnants on the frame

*"deixando mais ou menos sobras na borda da janela, da porta"*

A slice is 8 positions × 8 levels per storey (`index = level * 8 + position`), so
the frame ring — position 0/7, level 0/7 — is derivable for free. Border voxels
survive with a probability drawn from the blast's own `luck` (the B4-pinned
FNV-1a), so *"mais ou menos sobras"* varies per event and still replays exactly.

Survivors render as **carved half-voxels with a jagged glass silhouette** —
D32.2's four-substrate machinery, which glass has simply never had its own art
for. This is the *"geometria apropriada"* half of the Director's brief; the
decals are the other half.

---

## 6. G5 — Cracking

### 6.1 What G-D3 converts from accident into intent

Two known defects, both carried open in `MATERIALS_MASTER_PLAN` §4.2, are
**resolved by the Director's ruling rather than patched**:

1. *A far shotgun pellet already CRACKS glass, contradicting D22.* `damage_state_for()`
   returns CRACKED below `PUNCH_DENT_MIN` and a pellet at the end of the distance
   ladder computes `3.0 × 0.24 × 0.15 × 0.85 / 0.4 = 0.23`. Under G-D3 that is no
   longer a contradiction — it is the feature.
2. *Glass's empty DENTED band is a coincidence of two equal numbers.*
   `DESTROY_MIN["glass"]` and `PUNCH_DENT_MIN` are both `0.30`, which makes the
   band exactly empty. G-D3 makes that intentional — **glass fractures, it never
   deforms** — and it must be **pinned by a selftest**, not left as an equality
   two independent edits could break.

**Consequence worth stating:** the M4b note said glass would need
`HOLE_ONLY_MATERIALS` **and** a new `INTACT` return *"together, or neither"*.
G-D3 removes the need for both. Glass now marks (it cracks), so it does not
belong in `HOLE_ONLY_MATERIALS`; and *"não feito"* is gone, because a weak hit
now cracks instead of doing nothing. **The `INTACT` branch nobody wanted to build
is no longer required.** The ladder becomes: CRACKED → (no DENTED, ever) →
DESTROYED.

### 6.2 Cracking near a blast it survives

*"fazer o vidro rachar, se estiver perto de uma explosão, mas não dentro da área
de dano"*

A **crack radius** one or two rings beyond the destruction radius, glass-only,
reusing the same BFS the soot derivation already walks. Cheap because only glass
cells qualify and glass is sparse — the map-wide voxel walk that dominates the
cook (`PREDICTION_MASTER_PLAN` §8.8) is not widened.

### 6.3 The bullet web

*"o tiro fura o vidro, e cria aquele padrão de ondas rachadas ao redor"*

The hole is one voxel; the ring cells around it go CRACKED (G-D4). The ring index
picks the decal variant — dense near the hole, sparse further out.

⚠️ **The art constraint this creates, and it is the one that decides whether it
reads as glass:** the crack decal must be chosen by *direction from the hole*, so
the radial lines point outward and the web reads as one continuous fracture. Nine
identical stamps in a 3×3 read as nine stickers. §8 carries this into the order.

---

## 7. G6/G7 — Shards, and the round that keeps going

### 7.1 Shards on the floor

*"conseguimos fazer eles caírem permanentes no chão, mais ou menos como o mapa de
fuligem?"*

**Not on the soot map itself.** It is `FORMAT_RG8` — R is the per-face soot code
(0..124), G is the light bucket ([`voxel_renderer.gd:3507`](../../godot/scripts/geometry/voxel_renderer.gd)).
Both channels are spoken for, and the cell plane (P3) still defaults OFF, so
anything living there is invisible on the shipped path.

**The path that works on the shipped renderer:** shards as a **floor decal**, the
same path the floor dents already take (`_floor_sunk_decal_plan`). Permanent by
construction, survives repaint, Rule 8 intact, and it commits inside the
detonation's single commit frame — the frame that already mints.

**Stored in BASE coords**, the lesson both `_base_damage` and the soot store
already encode: rotation is suspended for performance and is meant to return, and
a record in view space is a record rotation loses in silence. Lifetime is
checkpoint-scoped, like every other scenario mutation. `SaveState` gains a third
section alongside `base_damage` and `crater_floor_soot`.

⚠️ **The honest risk.** Per G-D6 shards are state, and their gameplay consumer
(noise) is deferred. This project has already shipped two features that were
built and never triggered — the noise indicator and the exposure labels. What
keeps shards from becoming the third is that the **decal makes them visible from
day one**: a state that is on screen cannot rot unnoticed. That is the mitigation,
and it is deliberate, not a hope.

### 7.2 Pass-through

The pellet flood stops at blocked edges. G-D5 makes glass passable to the flood:
the pane takes its hole, the round continues, and what is behind it takes the
real impact. One rule at one seam.

---

## 8. G-ART — the art order glass has never had

`ASSETS/materials/glass/` holds a facade and a voxel and **no decals**; glass is
absent from `IMPACT_DECAL_MATERIALS` by D22, which G-D3 now retires. The families
glass needs are not the standard four:

| Family | What it is | Notes |
|---|---|---|
| `crack_web` | radial fracture, 3 variants | **Direction-indexed** (§6.3) — the variant is chosen by bearing from the origin so lines point outward |
| `bullet_web` | hole + surrounding craze | the impact cell itself |
| `shard_floor` | fallen glass on the ground | floor family, like `earth`'s dent |
| `frame_remnant` | jagged surviving silhouette | **geometry, not a decal** — a half-voxel substrate (§5.2) |

The order goes out as a standalone `PROMPTS/ART_ORDER_GLASS.md` in the shape of
`ART_ORDER_BRICK_DECALS.md`, and **`tools/persistent/check_decal.py` is the
acceptance gate** — earned before the art, the way M2a was.

---

## 9. The window — costed here, built elsewhere

Recorded so the day it is scheduled nobody re-derives it. **Measured, not
assumed:**

```
Edge.id   =  "EDGE_%d_%d_%s"   % [gu.x, gu.y, face]
Slice.id  =  "SLICE_%d_%d_%s"  % [gu.x, gu.y, face]
```

Neither identity carries a storey or a level, and `_slices[slice.id] = slice` is
a plain dictionary assignment — **a second element on the same face silently
overwrites the first.** `Slice.material` is one string, taken from
`edge.material`. So a face hosts exactly one element, of one material, over a
contiguous storey range. The extractor's *"a pane cannot share a face with a
wall"* `push_error` is a consequence of that key, not a policy.

A real window is brick sill · glass · brick lintel **on one face inside one
storey** — levels 2–5 of 8. The `panels` schema is storey-granular and cannot say
it.

**The mechanism, when it is wanted: give the level band to the identity.** A face
becomes partitioned into level bands; each band is one element with one material;
the key becomes `(gu, face, level_start)`. It preserves the invariant every
consumer assumes — **a `Slice` is single-material** — so the bake, the resistance
table, the punch table and the decals keep reading `slice.material` and keep being
right. `PassageQuery.clear_storeys()` survives untouched: it already iterates
`slices_of_edge()` and was written for *"every storey-face this edge ACTUALLY
has"*.

The alternative (one Slice with a band→material map) turns a field into a query in
dozens of call sites for no gain. Not recommended.

Touches: `Edge`, `Slice`, `SliceGenerator`, `EdgeRegistry`, `EdgeExtractor`, the
mapfile schema. It is this milestone's M3-2b — the largest single item, and it is
not the fire.

---

## 10. Task order

| Order | Task | Blocked by |
|---|---|---|
| 1 | **G1** — glass sublayers (MUL + ADD), lazy per level, shader variant | — |
| 2 | **G2** — `pane_id`: union-find for panels, occupancy flood fill for blocks (§4.2) | — |
| 3 | **G-ART** — the art order + `check_decal.py` coverage for the four glass families | — |
| 4 | **G5** — the CRACKED tier returns (G-D3): `crack_factor`, the pinned empty DENTED band, the blast crack radius | G-ART |
| 5 | **G3** — the pane cascade in `build_plan()`, `pane_shatter_punch`, world-revision bump | G2 |
| 6 | **G4** — frame remnants: border ring, luck-driven survival, jagged half-voxel substrate | G2, G-ART |
| 7 | **G6** — shards: BASE-coord store, floor decal, `SaveState` section | G-ART |
| 8 | **G7** — the projectile passes through (G-D5) | — |
| 9 | **G-D4** — the bullet web on shot neighbours | G5, G-ART |

**Deferred, with owners:** the window (§9, scenario applications) · shard noise
(sound milestone) · the see-through roll G-D7 (applications) · the agent crossing
a broken pane, and `PassageQuery` → `blocked_edges` (movement milestone).

---

## 11. Acceptance — what will and will not count

Per the project's standing evidence discipline, written before the work rather
than after:

- **A green selftest does not mean the feature fires on the real map.** Every one
  of G3, G4, G5 and G6 must be run on **PLAYGROUND's real glass panels** and the
  real counts read, not on a synthetic patch. The floor-dent path passed its
  selftest with 69 dents and produced zero on the real map; glass has exactly the
  same shape of exposure.
- **The transparency claim needs a capture**, hand-named so the rotation cannot
  eat it — `Screenshots/history/` with a non-`auto_` prefix, and a same-boot
  control, because a screenshot cannot tell *"did nothing"* from *"low contrast"*.
- **The cascade needs a cell probe**, not pixels: `INFILTRAITOR_CELL_PROBE=1`
  answers whether a voxel actually came back from the TileMapLayer.
- **`pane_shatter_punch` must be measured against the real arsenal**, the way
  `NEIGHBOUR_CASCADE_PUNCH` was pinned by a selftest that reads the shipped
  weapon JSONs — so a later balance edit fails the suite instead of silently
  turning a pistol into a pane-breaker.
