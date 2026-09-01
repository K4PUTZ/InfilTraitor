# GLASS MASTER PLAN — the physics of glass

**Status:** 🟢 v1.13 — **G1 geometry, G2, G7, G-MAP, G-D9, G-D18, G-D18b BUILT.
G3 THREE OF FOUR STAGES BUILT: Stage A (`GlassShatter` curve), Stage B (shot
path — region flood, G-D13 remnants), Stage C (the grenade/cook path — a pane
inside the blast's damage area shatters). Real-map verified on the GLASS map:
firearms and a grenade all take the big pane, with frame remnants. Left: Stage D
(the G-D8 passage / movement-blocking work).** G1
appearance signed off; G1 geometry awaits a Director tuning verdict on the sliver
size/dim. **G-D9 (multi-material slices) BUILT 2026-08-31** — `panels.bands` →
`Slice.material_bands` + `material_at()`, the per-band bake page, a lookup
material override; the GLASS map's WINDOWS.png wall renders a brick sill + head
over a glass middle (`glass_bands_wall_{before,after}_2026-08-31.png`, same-boot).
**G-D18 (2026-08-31):** glass no longer participates in occlusion — a see-through
pane hides nothing and its wireframe drew over a still-solid pane
(`glass_occlusion_{before,after}_2026-08-31.png`). **G-D18b (2026-08-31):** the
agent renders BEHIND a pane he stands behind, faintly tinted, like a guard
already did (`glass_agent_behind_pane_2026-08-31.png`). ⚠️ **OPEN — the Director
flagged 2026-08-31 that intact glass blocks no movement** (agent and guards walk
through it); the fix folds into G3 (see G-D8). **The break design GREW on 2026-08-31** — per-projectile shatter roll
(G-D11), partial breaks on big panes (G-D12), a mandatory remnant floor (G-D13),
per-weapon hole size (G-D14), armored/purple glass with a primed state (G-D15),
terminal-colour glass classes (G-D16 — INDESTRUCTIBLE *stops the round*), a
black-plastic screen backing (G-D17). **G3 is PAUSED for this doc's sign-off**
before any code — the Director gave it at the end of the 2026-08-31 session.
Next: **G3**. G-ART, G5, G4, G6, G-D4, G-VARIANT, `plastic` unbuilt.

**G1 GEOMETRY as reworked** (Director's two diagrams, 2026-08-31): the pane
thickness is a per-voxel **exposed-face cull**, not per-position atoms. A glass
voxel paints its MAIN face always; its TOP face only when nothing is above it
(the top row); its SIDE face only on the frontmost column (camera-nearest end,
always pos 7 — both screen axes carry a +south component). Top and side render
DIM and *that* is the thickness read. This kills the "serrilhado" — with
transparency every hidden face that gets drawn ghosts through. Generalises by
exposure to L-walls and glass cubes. 16 atoms (`_glass_atom_source[face][mask]`,
4 faces × 4 masks); `_build_glass_pane_atom(face, want_top, want_side)`;
`_glass_face_mask()` picks the mask. Tuning knobs: `GLASS_FACE_SLIVER_FRAC`
(0.55, the pane's half thickness), `GLASS_DIM_TOP` (0.60), `GLASS_DIM_SIDE`
(0.78), `INFILTRAITOR_GLASS_ATOM_NUDGE`. NW/NE slivers extrude toward the camera
(back walls) — untested; PLAYGROUND's panels are SW/SE.

**G1 FLOAT FIX** (`4d5da813`, Director 2026-08-31: *"o bloco todo de vidro está
deslocado pra cima ... flutuando na base"*): the pane atom's `texture_origin`
carried a leftover `+(0,20)` from the pre-rework `+shift` bookkeeping, lifting
every pane a level off the ground. `face_q` is now byte-for-byte the material
atom's own side face (`voxel_concrete.png` alpha rows 8..36), so the nudge
default is `Vector2i.ZERO` — glass renders exactly where an opaque wall does, and
matches the occlusion wireframe.

**G1 as built** (commits `41eee478`→`c9c4169c`): glass vertical faces leave the
opaque `_layers` for one glass `TileMapLayer` per level, composited through a
**`BackBufferCopy` rasterising container** (`glass_pane.gdshader` reads the
snapshot and applies the tint once — no double-tint; the Director's *"container
rasterizado"*). Per-face **parallelogram** atoms (the face-lattice fundamental
domain) for the interior; **perimeter** atoms add a DIM top cap + thickness strip
(1-voxel thickness). Frost sampled by world position. Calibration = "painel 005"
(sheen, `mul 0.60 / add 0.20`, blue tint `[0.47, 0.63, 0.90]`). Roofs / glazed
floor zones stay opaque (kept the roof-coverage geometry intact). Intact glass
still blocks light (`build_occupancy()` re-adds the cells).
`glass_transparency_selftest` (12 checks). Tooling:
`INFILTRAITOR_CAPTURE_ACTION=glass_calibration` + `glass_calibration.py`,
`INFILTRAITOR_GLASS_DIAG=1`, `INFILTRAITOR_GLASS_ATOM_NUDGE`.

⚠️ **GEOMETRY** — the pane half is reworked to the face-culling rule (2026-08-31,
above); a Director tuning verdict on the sliver size / dim is open. The glass
BLOCK half is untouched: roof-slab seam, opaque junction corner columns, z-index
vs walls in front. **The pane is the priority — full glass blocks are rare.**

Earlier: 🟡 v1.1 — DESIGN RATIFIED 2026-08-30, UNBUILT
**v1.1, same day:** G-D9 added and **§9 rewritten — it reverses its own first
recommendation** after the count it rested on was actually taken (16 call sites,
9 of which already hold the voxel; the bake seam already takes a level). The
reversal is kept visible rather than edited away.
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
| **A real window** (brick cap · glass · brick cap over 3 stacked storeys) | the scenario applications | ✅ Its enabling capability — **multi-material slices, G-D9** — is BUILT (2026-08-31); the `panels.bands` authoring (§9.6) spells it and the GLASS map's WINDOWS.png wall renders it. What stays deferred is the full *reveal* geometry (the empty opposite face, the agent crossing it) |
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
| **G-D8** | **A broken pane opens a passage, barely moves the light, and raises detection one step.** *"Com certeza, mas não influencia tanto na luz, apenas aumenta um pouco de intensidade e sobe um grau de detecção no mecanismo stealth."* ⚠️ **2026-08-31 — the Director flagged that an INTACT glass pane blocks nothing today** (*"o agente consegue atravessar o vidro, precisamos implementar a questão da abertura de passagem"*). Half-thickness panels never enter `blocked_edges` (§2), so the agent AND the guards walk straight through intact glass. The fix is coupled to G3 and needs the **movement/vision blocked-edge split** G-D7 anticipates (`blocked_edges` feeds both today, and glass must block the body but not necessarily the eye) — **fold it into G3** rather than a standalone patch, so "blocks when intact" and "opens when broken" (PassageQuery → the movement edge set, per-turn recompute) land together. **Director's call 2026-08-31: "juntar tudo no G3."** | ✅ Ratified 2026-08-30 · build folds into G3 (Director 2026-08-31) |
| **G-D9** | **A slice can carry MORE THAN ONE MATERIAL, as a sparse per-level band map — and the Director's diagram wins over §9's first recommendation.** *(2026-08-30, from the Director's half-thickness window diagram.)* The window is **three game storeys stacked inside one code `Slice`**: brick cap · glass · glass · glass · brick cap. ⚠️ **This REVERSES the recommendation this plan shipped with**, on a measurement that contradicted it — see §9 | ✅ Ratified 2026-08-30 |
| **G-D10** | **Mullions are free or they do not exist — a continuous pane is fine.** *(Director, 2026-08-30, closing §9.1's open observation.)* If the muntin grid falls out of the geometry — horizontals at storey boundaries, verticals at GU boundaries — take it. If the glass reads as one continuous surface instead, that is equally correct. **Neither outcome is a defect, and G-ART owes NO fifth decal family.** The one thing ruled out is authoring muntins as art | ✅ Ratified 2026-08-30 |
| **G-D11** | **The whole-pane shatter is a PER-PROJECTILE ROLL scaled by power — ⚠️ this replaces §5.1's single `pane_shatter_punch` threshold.** *"Cada pellet ou projetil vai ter sua própria chance de quebrar ou não a janela toda, ou pelo menos uma área maior do que a zona do tiro, de acordo com a potência."* Every pellet/round that hits a pane rolls its OWN chance (B4 FNV-1a on `(salt, projectile index)`) to take the pane — or a region larger than its own hole. The chance rises with the round's glass punch. A shotgun's 24 pellets each roll and the pane's odds compound with the count — and **it is legitimately possible that none shatter it** | ✅ Ratified 2026-08-31, replaces §5.1 |
| **G-D12** | **A BIG pane breaks PARTIALLY; a SMALL pane is binary.** *"Uma vidraça grande permite que uma parte quebre totalmente, e outra continue resistindo. Em vidros menores é mais binário, quebrou tudo ou não."* A shatter roll takes a REGION — a flood from the hit, radius scaled by the round's power. On a large pane the rest keeps standing (same `pane_id`, still shatterable later); on a small pane the region covers the whole thing | ✅ Ratified 2026-08-31 |
| **G-D13** | **The cascade NEVER destroys every voxel — remnants on the frame are a HARD INVARIANT.** *"nunca queremos que todos os voxels quebrem, sempre deixamos umas sobrinhas nas molduras."* §5.2's luck-driven border survivors (position 0/7, level 0/7) are now a rule of G3 itself, not an optional G4 flourish. A pane left with zero surviving border voxels is a bug | ✅ Ratified 2026-08-31 |
| **G-D14** | **Hole size is per-weapon.** *"pistola ou shotgun fazerem um furo de um voxel, com a arte das ondas rachadas em volta, ao passo que armas mais potentes como o fuzil destroem de 2 a 4 voxels, e criam uma arte com ondas maior, e mais espaçada."* Non-shattering hit: pistol / shotgun pellet = 1 voxel + a tight `crack_web`; rifle-class = 2–4 voxels (scaled by power) + a larger, more spaced `crack_web`. Driven by the existing `WeaponDef.blowout` field | ✅ Ratified 2026-08-31 |
| **G-D15** | **ARMORED GLASS (`glass_armored`, purple) — resists common shots; when breached, usually shatters entirely at once, leaving many individual shards.** ⚠️ **Special rifle case:** a rifle round may pierce a SINGLE voxel without shattering (treated as a weak hit) — this PRIMES the pane, and the next shot of ANY type auto-shatters the whole thing. `pane_primed` is a per-pane flag, checkpoint-scoped | ✅ Ratified 2026-08-31 · build after this doc is signed off |
| **G-D16** | **Glass is a family of tinted behaviour classes, not new geometry.** All variants share G1's rendering and differ only in a tint (`base_color`) and a `glass_class`: `glass` (blue, BREAKABLE) · `glass_armored` (purple, ARMORED, G-D15) · `glass_screen_{green,red,amber}` (dark terminal tone) which is **INDESTRUCTIBLE** (control interfaces — takes a crack decal, never breaks, and STOPS the round: *"trinca mas o tiro para"*) or **BREAKABLE** (TVs, circuits, news panels) per placement | ✅ Ratified 2026-08-31 |
| **G-D17** | **A screen is a glass voxel over a BLACK PLASTIC voxel.** *"O voxel de vidro fica na frente de voxels pretos de PLÁSTICO (a implementar — fura [não atravessa] ou derrete), de forma que nesses voxels pretos vamos pintar as imagens e textos posteriormente, e o vidro vai criar o efeito de brilho por cima."* New material **`plastic`** (black): a round DRILLS it (a hole, but the round does NOT pass through — unlike glass) or fire MELTS it. Images/text painted onto the plastic later; the glass in front adds the G1 sheen. Belongs in `MATERIALS_MASTER_PLAN` | ✅ Ratified 2026-08-31 · `plastic` + the paint layer are deferred |
| **G-D18** | **Glass does not occlude.** *(Director, 2026-08-31, on the G-D9 capture: "tem algum problema com a oclusão. Podemos considerar não fazer em materiais de vidro.")* A glass pane is see-through by construction (G-D1) — the agent behind it is already visible, so ghosting it reveals nothing, and because glass renders on its own `_glass_layers` (which `apply_occlusion()` never erases) the wireframe drew its lines and ghost-band fill over a still-solid pane. `OcclusionSet` now filters out any slice whose BASE material is glass (policy O7, `_group_slices_by_edge`): no trigger, no ring stop, no wireframe. A mostly-opaque wall with a small glass viewport (base ≠ glass) still occludes. Guard-through-glass vision is G-D7, a separate roll | ✅ **BUILT 2026-08-31** |
| **G-D18b** | **The agent renders BEHIND a glass pane he stands behind.** *(Director, 2026-08-31: "no caso do vidro ser transparente, acho que podemos deixar o agente ser renderizado atrás e ficar parcialmente coberto pelo vidro.")* OCC-03 bumps the agent one z above the tallest OPAQUE layer so a wall never hides him. Glass hides nothing, so the whole glass composite (backbuffer + every pane layer) is now lifted one z above the agent (`VoxelRenderer.set_glass_over_z(agent.z_index + 1)`, called from room.gd) — a pane the agent stands behind tints him, exactly as it already did for a guard (`enemies_root.z_index = 10`, never bumped). An agent standing IN FRONT of a pane is unaffected: the isometric projection draws his sprite below the pane's screen footprint, so they do not overlap | ✅ **BUILT 2026-08-31** |

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

### 5.1 The break — a per-projectile roll (G-D11, G-D12, G-D14) ⚠️ REWRITTEN 2026-08-31

The single `pane_shatter_punch` threshold this section shipped with is retired.
The Director's model (2026-08-31): **each pellet or round that lands on a pane
does three things, in order.**

1. **The local hole (G-D14).** The impact voxel is DESTROYED. How many of its
   neighbours go with it is per-weapon, off `WeaponDef.blowout`:
   - pistol / shotgun pellet (`blowout` 0.0) → **1 voxel**, tight `crack_web`.
   - rifle-class (`blowout` ≥ ~0.5) → **2–4 voxels**, scaled by power; wider,
     more spaced `crack_web`.

2. **The shatter roll (G-D11).** The projectile rolls `P_shatter(glass_punch)`
   — a curve with a **near-flat bottom and a steep middle**, capped below 1.0.
   A single common round never *guarantees* a full shatter; only a
   `pane_primed` armored pane does (§5.3).

   **The Director-approved target distribution (2026-08-31), at neutral
   skill/luck:**

   | round | glass punch | P(shatter the pane) |
   |---|---|---|
   | smg | 1.65 | ~0% |
   | shotgun pellet (one) | 1.80 | ~2% |
   | pistol | 2.10 | ~2.5% |
   | revolver | 2.63 | ~16% |
   | assault rifle | 3.75 | ~44% |
   | sniper | 5.25 | ~81% |
   | **shotgun blast (24 pellets)** | — | **~38%** — `1 − (1 − 0.02)²⁴` |

   The exact `SHATTER_*` constants are `var` (rule 1) and **pinned by a selftest
   that reads the shipped weapon JSONs** and asserts this table within a
   tolerance — so a later balance edit to a weapon's `punch` fails the suite
   rather than silently turning a pistol into a pane-breaker (plan §11). The
   flat bottom is load-bearing: it is what keeps a shotgun's *volume* (24 rolls
   at ~2%) its advantage over a pistol's single ~2.5% roll, and it is what keeps
   "none of the 24 shattered it" a real outcome.

   ✅ **BUILT 2026-08-31 (Stage A) — `godot/scripts/systems/destruction/glass_shatter.gd`.**
   `p_shatter(glass_punch)` is a **shifted, renormalised logistic** — the
   `clamp(s(p) − C, 0)` is what makes the bottom actually reach zero (a plain
   logistic's tail never does). Constants: `SHATTER_K` 1.14, `SHATTER_X0` 3.79,
   `SHATTER_C` 0.075, `SHATTER_P_MAX` 0.98 (all `static var`). `rolls_shatter(glass_punch, salt)`
   is the deterministic B4 FNV-1a roll. `glass_shatter_selftest` (8 checks) reads
   `res://weapons/*.json`, computes each round's neutral `glass_punch` and pins
   the curve within ±6 pts (±8 for the 24-pellet compound); it also pins the flat
   bottom (0 below punch 1.5), the sub-1.0 ceiling, monotonicity, and that the
   roll's observed frequency tracks `p_shatter`. Curve vs targets as built: smg
   0.6% · pellet 2.0% · pistol 5.5% · revolver 14.3% · rifle 43.8% · sniper
   81.1% · shotgun blast 38.2%. Pistol lands a touch high — the target knee
   between punch 2.1 and 2.63 is sharper than a smooth sigmoid catches; Director
   2026-08-31: *"Boa — fixar como está."*

3. **The region (G-D12).** A won roll floods DESTROYED outward from the hit — a
   BFS over the pane's own voxels, radius scaled by `glass_punch` (a weak win
   takes a patch, a sniper takes the lot). On a small pane the radius covers
   everything → binary. On a large pane the rest survives with its `pane_id`
   intact and can be shattered by a later hit.

**G-D13 is a hard floor on all of it.** After the hole, the region, *and* any
later hits, the frame ring (position 0/7, level 0/7) keeps luck-driven survivors
(§5.2). The cascade may not leave a pane with zero border voxels — pin it with a
selftest.

✅ **BUILT 2026-08-31/09-01 (Stage B) — `GlassShatter.plan_pane_shatter()` +
`agent_shot_controller._maybe_shatter_pane()`.** Runs in the SHOT PATH (where G7
already lives), once per pellet that landed on a pane, AFTER its local hole.
`plan_pane_shatter` builds the pane's own `(col, level)` lattice over every
`pane_id` slice (col = run axis: X for SW/NE, Y for SE/NW — panel panes only,
`PANE_BLOCK_*` deferred), Chebyshev-BFS-floods from the hit to `region_radius(glass_punch)`
= `BASE(3) + GAIN(6)·(glass_punch − PIVOT(2))`, then spares the frame ring:
each border voxel in the flood survives with `lerp(KEEP_MIN 0.10, KEEP_MAX 0.40, luck)`
and at least `MIN_COUNT` (4) always survive (the ones furthest toward a corner,
so they read as frame fragments). Every flooded voxel is `set_damage(DESTROYED)`
and folded into the shot's own bookkeeping — render pass, VL-PERSIST and
`bump_world_revision()` unchanged. `glass_shatter_selftest` grows to 12 checks
(region monotonic; small pane binary + remnants; big pane PARTIAL on a revolver
win / near-full on a sniper; G-D13 never leaves 0 border across 60 rolls).
Real-map, GLASS map's big pane (6 GU × 3 storeys, 1152 voxels): assault rifle
`glass_punch 4.13 radius 16` → **647 destroyed, the guard-side half stands**
(`glass_shatter_partial_rifle_2026-09-01.png`); sniper `glass_punch 5.78 radius 26`
→ **972 destroyed, 180 remnants** (`glass_shatter_full_sniper_2026-09-01.png`);
the round passes through and marks the concrete behind. ⚠️ `_dispatch_destruction_vfx`
now early-returns for `glass` — a 970-voxel shatter was 970 smoke puffs, a milky
haze over the map; glass debris is SHARDS (G6, a floor decal), not particles.

**⚠️ Stage B runs in the SHOT PATH, not the cook.** The shot path does not use
`build_plan()`/`WorldDelta` — G7 and the local hole are all direct
`plan_point_impact` + `set_damage`, and Stage B matches that.

✅ **BUILT 2026-09-01 (Stage C) — the grenade/cook path.**
`GlassShatter.blast_glass_punch(ring_multipliers, ring)` = `SHATTER_BLAST_GAIN(3.4)
· ring_multipliers[ring] / RESISTANCE["glass"]` — the cook has no per-projectile
punch, so the pane's roll runs off the blast's own per-ring falloff (frag_grenade:
~98% at ring 0, ~79% at ring 1, ~6% at ring 2, 0 past). In
`detonation_plan_builder._phase_slices`, glass PANEL slices are pulled OUT of the
ring-scatter model entirely (glass fractures, it does not deform — whole break or
none); glass BLOCKS keep it. `_shatter_glass_panes()` groups the affected panels
by `pane_id`, keeps the nearest ring, rolls once per pane, floods the whole pane
(`plan_pane_shatter`, G-D13 remnants) into the Delta as blast-sourced DESTROYED,
deterministic on `(source_gu, pane_id)`. ⚠️ **`detonation_entry_writer`'s "destroy"
wave only knew `get_layer()` → the opaque stack** — a blast-shattered pane stayed
on screen because glass renders on `_glass_layers`. New
`VoxelRenderer.erase_glass_cell(level, cell)` (a no-op for non-glass) is now
called per destroy entry. This was a latent gap for glass BLOCKS too; Stage C
surfaced it. Real map: frag grenade at a corner of the GLASS big pane → ring 0,
1131/1152 flooded, the pane gone (`glass_shatter_grenade_2026-09-01.png`).

**Stage D** (still open) — G-D8's passage / movement-blocking work.

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

### 5.3 Armored glass (G-D15)

`glass_armored` (purple tint) is a `glass_class = ARMORED`. Against it the §5.1
ladder changes:

- **Resistance is high** — a much larger `RESISTANCE["glass_armored"]`, so a
  common round's `glass_punch` lands near `SHATTER_ROLL_FLOOR` and the local
  hole is often the whole story.
- **When it DOES shatter, it goes all at once** — the region radius for an
  armored win is the whole pane regardless of size, and the survivors read as
  *many individual shards* rather than a clean edge (G6's shard count is high,
  the frame remnants sparse).
- **The rifle pierce-and-prime case.** A rifle round that fails its shatter roll
  on an intact armored pane may still *pierce a single voxel* (a weak-hit hole,
  G-D5 pass-through still applies) and set **`pane_primed = true`** on that
  `pane_id`. A primed pane's next hit of any type has `P_shatter = 1.0` — it
  auto-shatters. `pane_primed` lives in `SaveState` alongside the shard store
  (G6), checkpoint-scoped.

An **INDESTRUCTIBLE** `glass_class` (the control-interface screens, G-D16)
short-circuits §5.1 entirely: the impact voxel takes a permanent `crack_web`
decal, nothing is ever DESTROYED — **and the round STOPS** (Director, 2026-08-31:
*"Trinca mas o tiro para"*). This is the one glass that does NOT pass a round
through (G-D5 does not apply), which is what sells it as genuinely armoured
rather than just tough.

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

🔎 **Reference material the Director already collected:**
`REFERENCES/bullet-hole-transparent-glass-abstract-background-*.zip` (2026-08-02) —
glass bullet holes, gathered a month before this plan existed. Worth opening before
the order is written rather than commissioning from scratch.

The order goes out as a standalone `PROMPTS/ART_ORDER_GLASS.md` in the shape of
`ART_ORDER_BRICK_DECALS.md`, and **`tools/persistent/check_decal.py` is the
acceptance gate** — earned before the art, the way M2a was.

---

## 9. The window — MULTI-MATERIAL SLICES (G-D9)

⚠️ **This section was rewritten on 2026-08-30, the day it was written, and it
REVERSES its own first recommendation.** The first version recommended splitting a
face into several single-material slices keyed `(gu, face, level_start)`, and
rejected the multi-material slice on the grounds that it *"turns a field into a
query in dozens of call sites"*. **That claim was asserted without counting. It is
false, and the count is below.** Recorded rather than quietly edited, because a
plan that hides its own reversal teaches nobody anything.

### 9.1 What the Director's diagram specifies

**Source: `REFERENCES/WINDOWS.png`** (delivered 2026-08-30, alongside `SLICES.png`
and the rest of the architecture specs). ⚠️ **`REFERENCES/` is gitignored**
(`.gitignore:47`), so the diagram is **not versioned with this plan** — it can be
edited or replaced and this document's history will not show it. That is why it is
transcribed below rather than merely linked. The transcription is what the plan
stands on; the PNG stays the Director's own working copy.

A half-thickness glass window, built bottom-up:

```
   ┌──────────┐  brick cap          ← storey 2, upper level band
   │  glass   │                        storey 2, lower level band
   ├──────────┤
   │  glass   │  pure glass          ← storey 1, MONO-material
   ├──────────┤
   │  glass   │                        storey 0, upper level band
   └──────────┘  brick cap          ← storey 0, lower level band
```

> Director, 2026-08-30: *"São 3 storey do game empilhados (slices), que formam a
> parede completa."*

**Read off the diagram at full resolution — two of the three stacked storeys are
multi-material, one is not:** the top storey is a brick band over glass, the bottom
storey is glass over a brick band, and **the middle storey is pure glass** (the
diagram labels it `HALF ESPESSURA (1 SLICE) GLASS`, and the magenta
`MULTI MATERIAL SLICE` callout points only at the mixed one). So the capability is
needed for two of three bands, not all of them.

✅ **ANSWERED the same day — G-D10.** The reading was that the black mullion grid
falls on the geometry: horizontals at **storey boundaries**, verticals at **GU
boundaries**. The Director's ruling makes the question moot either way —
*"caixilhos de graça, ou nem precisam existir. Se for contínuo, está ótimo."* Take
the grid if the geometry produces it; a continuous pane is equally correct.
**G-ART owes no fifth decal family**, and muntins are never authored as art.

**The vocabulary, settled — and it settles a collision this project already
carried.** The `MATERIALS_MASTER_PLAN` records that *"the Director's 'slice' is one
storey of wall on one GU face; the code's `Slice` class is the whole face across
every storey."* The diagram resolves it in the code's favour:

| Diagram | Code | Note |
|---|---|---|
| one stacked piece ("slice") | a **level band of 8** inside a `Slice` | `LEVELS_PER_STOREY = 8` |
| the red box ("container / high wall") | the **`Slice`** itself | one face, every storey, `storey_count × 8` levels |
| — | `HighWallGroup` | ⚠️ **NOT the red box.** It is a bake-time grouping of edges **horizontally**. Reusing that name for the vertical stack would be a second collision |

**So no new container is needed.** The `Slice` already IS the red box. Only its
single `material` string has to become a band map.

### 9.2 The measurement that reversed the recommendation

Counted 2026-08-30 over non-test code, not estimated:

| Reader of a slice's material | Sites | Already holds the `Voxel`? |
|---|---|---|
| render — `damage_variant_material()` ×2 | 2 | **yes** |
| the `voxel_destroyed` signal | 1 | **yes** |
| the shot path — `agent_shot_controller` ×4, `weapon_bench_controller` ×2 | 6 | **yes** |
| the cook — `detonation_plan_builder` :1587 | 1 | **yes** |
| the cook — `detonation_plan_builder` :520 | 1 | no — whole-slice batch, needs per-voxel resolution inside |
| census / diagnostics — `room.gd` ×3 | 3 | no, and they genuinely want *"what is this wall made of"* |
| debug gallery | 2 | no |
| **TOTAL** | **16** | **9 already hold the voxel** |

**Nine of sixteen read the material off the slice only because `Voxel` has no
material of its own** — not because they want a property of the surface. For them
`material_at(level)` is a mechanical substitution.

**And the bake seam is already level-aware:**

```gdscript
func resolve(edge, face, voxel_xy, level: int = 0, column_in_run: int = -1)
_compute_facade_key(material_id, facade_id, column_in_run, level, dir)
```

`resolve()` already receives the level, and the facade key is already
`(material, facade, column, level, dir)` — **two materials on one face produce
distinct keys with no collision.** It simply asks `edge.material` instead of asking
per level: `baked_tile_lookup.gd:259` and `:415`.

### 9.3 The data shape

```
Slice.material                    stays — the BASE / dominant material
Slice.material_bands: Dictionary  SPARSE override, level → material
Slice.material_at(level)          the accessor
```

**Sparse on purpose:** the overwhelming majority of slices are single-material and
RAM is this project's constraint, not CPU (D42). A normal wall pays **zero bytes**.
`slice.material` keeps meaning *"what is this wall made of"*, which is exactly what
the three census sites want — they do not change.

### 9.4 ⚠️ Where the real cost is, and it is NOT the 16 reads

**The bake RUN.** `_group_edges_into_runs()` groups collinear edges sharing
material+facade **horizontally**, so a facade stays continuous across GUs — that is
what `column_in_run` is for, and it is why brick does not restart at every GU. A
multi-material slice cuts **vertically**. The two are orthogonal axes, so a run has
to become per **material band** rather than per edge;
`_edges_share_material_and_facade()` compares whole edges today.

This is the work. It is also the nastiest failure mode in the change: a wrong run
breaks nothing and throws no error — the texture simply restarts in the middle of
a wall. **It can only be caught by a capture**, which is why §11's rules apply here
too.

**Second gap, smaller, recorded now so it is not a discovery later:**
`JunctionResolver` builds a `JunctionColumn` from `edge_a.material` — one material
for the whole corner column. A multi-material edge would give that column the wrong
material over part of its height. Probably irrelevant for a window (windows rarely
reach a corner), but it is a known hole, not an unknown one.

### 9.5 What is still deferred

The **capability** is ratified here. The **authoring** — how a mapfile spells
"brick cap, glass, brick cap" — was deferred to the scenario applications; ⚠️
**that deferral is PARTIALLY LIFTED 2026-08-31** — the new `GLASS` test map
(§12) needs the authoring format now. §9.6 formalises it. ✅ **BUILT 2026-08-31.**

### 9.6 The authoring format (Director, 2026-08-31 — *"vamos usar o mecanismo do WINDOWS.png para criar as paredes"*)

A `panels` entry (M3-2b) gains an optional **`bands`** array — a sparse
level→material override on the same half-thickness face:

```json
{
  "gu": [x, y], "face": "SE", "storeys": 3, "start_storey": 0,
  "material": "glass",
  "bands": [
    { "levels": [0, 1],   "material": "brick" },
    { "levels": [22, 23], "material": "brick" }
  ]
}
```

- `material` is the BASE (the majority — glass, for a window). Any level not
  named by a band renders as the base.
- `bands` levels are **absolute within the panel's own extent** (0 …
  `storeys * LEVELS_PER_STOREY − 1`). `[0,1]` is the sill (brick cap at the
  bottom of the WINDOWS.png stack); `[22,23]` the head, for a 3-storey panel
  (24 levels). The three middle storeys are pure glass — exactly the diagram.
- A single 8×8×1 storey band can itself be split — that is the magenta
  `MULTI MATERIAL SLICE` callout: the sill storey is brick over glass, the head
  storey glass over brick.

**Pipeline — ✅ BUILT 2026-08-31 (commit pending). What actually landed:**

| Layer | Change as built |
|---|---|
| `map_compiler._compile_panel_bands()` | expands the sparse `bands` array into a dense `{rel_level: material}` dict on the panel instance, ONCE. `levels` accepted as `[lo,hi]` OR the `Vector2i` FileMapSource's JSON converter folds a 2-int array into |
| `edge_extractor._extract_panels` | `edge.material_bands = panel.material_bands.duplicate()` — panels are appended straight to `result["edges"]`, never rebuilt by the third pass, so nothing drops it |
| `Edge` / `Slice` | `material_bands: Dictionary` + `material_at(rel_level) -> String` + `has_material_bands()`. `rel_level` = `voxel.level − storey_level_base(start_storey)` — 0-based from the panel's own bottom, exactly the authoring space |
| `SliceGenerator._create_slice` | copies the band map onto the Slice (side-independent) |
| `voxel_renderer._render_slice` / `_process_dirty_slice_voxel` | per-voxel `vmat = slice.material_at(rel)` drives `damage_variant_material()`, the glass-layer routing gate (`vmat == "glass"`), and the diag. `_slice_top_glass_level()` anchors the G1 top sliver to the top GLASS row, below a brick head. `_slice_is_glassy()` (base OR any band) keeps the diag/geometry firing |
| `voxel_renderer._set_voxel_cell` | resolves the per-level material in RENDER space (`edge.material_at(level − storey_level_base(edge.start_storey))`) and passes it to the lookup as `material_override` — "" for every ordinary edge |
| `BakedTileLookup.resolve` / `_resolve_baked_sheet` / `_resolve_generic` | new trailing `material_override: String = ""`; when set it is the facade key's material component. The key was already `(material, facade, column, level, dir)` — two materials on one face, no collision |
| `room_builder._bake_textures` | one extra `wall_descriptor` per `(banded edge, band material)` so `_extract_unique_combos` / `_extract_combo_usage` see the combo and the compositor bakes the brick facade page. Verified: `[BAKE] Composed sheet brick|facade_brick` appears for the GLASS map (and does NOT on the pre-G-D9 checkout) |
| `GlassPaneGrouper._is_glass_slice()` | a slice is glass if base OR any band is glass — the GLASS map's 3 banded panels union into one `PANE_SLICE_22_10_SW` |
| ⚠️ `_group_edges_into_runs` — **NOT changed.** §9.4 anticipated a per-**material-band** run. It was not needed: the banded edges share their BASE material along the run, so they group naturally, and `column_in_run` continuity is exactly what the glass middle wants; the brick sill/head resolve against the (fully-swept) brick page folded through the same `column_in_run`, giving a continuous brick cap. §9.4's failure mode (a wrong run restarting a facade mid-wall) needs a run that spans two *different* base materials — those are already separate runs. If a future map places a banded window mid-run against a plain wall of a different base material and the brick cap misaligns, that is when the run split gets built, with its own capture. |

## 10. Task order

| Order | Task | Blocked by |
|---|---|---|
| 🟢 | **G1** — glass pane transparency via a `BackBufferCopy` container. **APPEARANCE signed off 2026-08-31** (calibration "painel 005"). **GEOMETRY reworked 2026-08-31** to the face-culling rule (main always / top on the top row / side on the frontmost column, both dim); awaiting a tuning verdict. Glass-block issues untouched. Vertical faces only — roofs / glazed floor zones stay opaque | — |
| 🟢 | **G2** — `pane_id`: `GlassPaneGrouper.assign()` at map load — union-find for panels (coplanar + adjacent along the face run axis), 4-connected flood fill for glass block cells (NOT per-authored-instance: PLAYGROUND's 3-wide block is three 1×1 declarations = one pane). Real-map verified (PLAYGROUND: 2 panel panes + 1 `PANE_BLOCK_0`). `Slice.pane_id`. **BUILT 2026-08-31** | — |
| 🟢 | **G7** — the round passes through a pane (G-D5): `EdgeRegistry.glass_edge_keys()`, `_walk_pellet_ray` records the crossing (deduped by pane) and continues, `agent_shot_controller` flattens crossings into picks. Real-map: `glass destroyed=1` AND `concrete dented=1` from one pistol shot. Blocks excluded (their cells are in `blocked_cells`, deferred). **BUILT 2026-08-31** | — |
| 🟢 | **G-MAP** — `maps/GLASS.map.json` **BUILT 2026-08-31**: big pane (authored gu x 10–15, y 9, SW, 3 storeys) in front of the agent, a WINDOWS.png `bands` wall (gu 19–21 — `bands` ignored until G-D9, renders as plain glass), a small 1-storey pane, a guard behind the big pane, a 3-wide glass block. Auto-registered via `FileMapSource`. `INFILTRAITOR_MAP=GLASS` boots it without touching the persisted cfg. Verified: pane_ids correct (one big pane, one small, one block, one bands wall), and a pistol shot goes `glass destroyed=1` + `concrete dented=1` through the big pane | — |
| 🟢 | **G-D9** — multi-material slices: `panels.bands` authoring (§9.6), `Slice.material_bands` + `material_at()`, the per-band bake page (extra `wall_descriptor`, NOT a run split — see §9.6), a lookup `material_override`. `GlassPaneGrouper` unions a banded panel by base-or-band glass. **BUILT 2026-08-31.** Acceptance: `glass_bands_wall_before/after_2026-08-31.png` (same-boot) — the WINDOWS.png wall gains a brick sill (rel 0-1) + head (rel 22-23) over a glass middle; `[BAKE] Composed sheet brick\|facade_brick` present on the GLASS map and absent pre-G-D9; `glass_transparency_selftest` test [7]; 39 selftests clean | — |
| 3 | **G-ART** — the art order + `check_decal.py` coverage for the glass families (`crack_web` now needs a tight AND a wide/spaced variant, G-D14) | — |
| 4 | **G5** — the CRACKED tier returns (G-D3): `crack_factor`, the pinned empty DENTED band, the blast crack radius | G-ART |
| 🟡 | **G3** — the break, per §5.1's REWRITTEN model. **Staged (Director "vamos seguir com G3", 2026-08-31):** **A** ✅ `GlassShatter` curve + arsenal selftest. **B** ✅ the roll in the shot path + region flood + G-D13 remnants + glass-VFX guard. **C** ✅ the grenade/cook path — `blast_glass_punch()`, panels out of the ring model, `_shatter_glass_panes()`, `VoxelRenderer.erase_glass_cell()` (see §5.1). **D** (open) G-D8's passage work: intact glass → the movement blocked-edge set (new split from vision's, per G-D7), broken glass → passage opens (`PassageQuery` → per-turn recompute) + detection +1 + light bump | G-MAP, G2, §5.1 |
| 5b | **G-VARIANT** — `glass_class` + tint (G-D16): `glass_armored` (purple, ARMORED + `pane_primed`, G-D15), `glass_screen_{green,red,amber}` (INDESTRUCTIBLE / BREAKABLE). Material roster + `RESISTANCE` rows + a per-placement class tag | G3 |
| 6 | **G4** — frame remnants: border ring, luck-driven survival, jagged half-voxel substrate. **G-D13 makes this a rule of G3, not a separate task** — it lands with G3 | G2, G-ART |
| 7 | **G6** — shards: BASE-coord store, floor decal, `SaveState` section (also holds `pane_primed`, G-D15) | G-ART |
| 8 | **G-D4** — the bullet web on shot neighbours | G5, G-ART |
| ⤴ | **`plastic`** (black backing material for screens, G-D17) + the paint-on-plastic layer + the screen-art pipeline — **`MATERIALS_MASTER_PLAN`, deferred.** A round DRILLS plastic (hole, no pass-through); fire MELTS it | MATERIALS |

**Deferred, with owners:** the window's full *reveal* geometry (§9, scenario
applications — the `bands` authoring itself is now G-D9, above) · shard noise
(sound milestone) · the see-through roll G-D7 (applications) · the agent crossing
a broken pane, and `PassageQuery` → `blocked_edges` (movement milestone) ·
`plastic` + screen art (`MATERIALS_MASTER_PLAN`).

---

## 11. Acceptance — what will and will not count

Per the project's standing evidence discipline, written before the work rather
than after:

- **A green selftest does not mean the feature fires on the real map.** Every one
  of G3, G4, G5 and G6 must be run on the **`GLASS` map's real panes** (§12) and
  the real counts read, not on a synthetic patch. The floor-dent path passed its
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

⚠️ **The real-map bed is now the `GLASS` map (§12), not PLAYGROUND** — every G3 /
G4 / G5 / G6 run reads counts there.

---

## 12. The `GLASS` test map (Director, 2026-08-31)

> *"pra poder gerar esse mecanismo todo precisamos modificar o PLAYGROUND e
> colocar uma vidraça maior na frente do agente… Aliás o PLAYGROUND já está
> muito cheio, podemos criar um novo mapa GLASS pra testar vidro. Vamos usar o
> mecanismo descrito no diagrama WINDOWS.png para criar as paredes."*

A new mapfile `maps/glass.map.json`, registered in the map catalog, dedicated to
glass physics — PLAYGROUND stays as it is.

**What it needs (first pass — extend as the tasks land):**

1. **A big pane directly in front of the agent** — wider and taller than
   PLAYGROUND's 2-storey panels, so G-D12's *partial* break has room to read
   (part shatters, part holds). A single face, several GUs wide, 2–3 storeys.
2. **A WINDOWS.png wall** — a `panels` entry with `bands` (§9.6): brick sill,
   glass middle, brick head, over 3 storeys, half thickness. This is the piece
   that exercises the G-D9 multi-material-slice pipeline.
3. **A small pane** — 1 GU, 1 storey — for the binary (all-or-nothing) case.
4. **One guard behind the big pane** — the shot-through-glass path (G7) and the
   see-through roll (G-D7, later) both need an actor on the far side.
5. **A glass block** — carried over so block geometry keeps a home.
6. Later, as the variants land: a `glass_armored` pane, a `glass_screen_*`
   panel, and (when `plastic` exists) a plastic-backed screen.

**Acceptance for the map itself:** `INFILTRAITOR_GLASS_DIAG=1` prints the
expected `pane_id` set; a hand-named capture shows the big pane, the WINDOWS.png
wall and the small pane in one frame.
