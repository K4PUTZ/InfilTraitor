# MATERIALS_MASTER_PLAN
## The materials milestone — burn, breach, see through, and flow — v1.4

> 🏁 **2026-10-17 — THE SOFT MATERIALS ARE DONE, AND THE MATERIALS PART IS CLOSING (Director: "estamos finalizando a parte de materiais").** Cloth and cardboard are SHEETS now, roofs AND walls: a `SoftSheet3D` drawn at rest from the first frame over a sim that was settled at load on a worker, the voxels staying the index (light, support, damage); a blast that takes a support wakes that very sim, a blast or a shot that only cuts a hole redraws the skin with the opening (cloth: flaps; cardboard: a torn ragged edge and its old debris; a little soot on a shot's hole); **cloth touching cloth is SEWN** (`SoftSheetGroup`: a roof and the walls hung from it fall as one piece); cardboard is PLATES that fold along creases. The **quitanda** (a stall: two plywood posts, a roof, panels on three sides) is the bench (`MARKET_LAB`; PLAYGROUND's cardboard and fabric trios became quitandas). A half-thickness panel may now `blocks` (a wall of a thin material that stops movement, sight and rounds). Per-material shot and blast videos for the nine PLAYGROUND materials: `tools/persistent/material_videos.py`. The numbers (Moto g04s and Galaxy A16: the load waits 0 ms for the workers, a release batch is ~210-260 ms on the main thread, the fall window ~34-36 ms/frame) and every decision are in `ROOF_MASTER_PLAN` v0.41-v0.44; the engine record is `docs/ARCHITECTURE.md` §0.5. **What the materials part still owes:** **M6, FLUIDS** (below, scoped by the Director today) and maybe GASES; metal (`ROOF_MASTER_PLAN` Q5) and the roof shot (its step 5); a rail / counter for the quitanda's frame and walls of cardboard that fold as plates; the soft materials' persistence across a checkpoint; (the handle-free `collect` and the cache of settled positions for many cloths were DONE the same day, `ROOF_MASTER_PLAN` v0.45; the Moto on the 40-sheet stress map is still owed).


> ⏭️ **2026-10-12 — ONE-LAYER MATERIALS and per-material shot behaviour (Director; `ROOF_MASTER_PLAN` v0.17-v0.19, `docs/ARCHITECTURE.md` §0.4).** Glass, cardboard and fabric are ONE layer in every situation and the COMPILER enforces it (`EdgeExtractor.is_thin_material`: a solid block / divider keeps its OUTER shell, `side: "inner"` overrides; windows and frames default to the INNER GU, `side` on `panels` is next). Plywood stayed two slices until **2026-10-14, when it joined them (Director: "teto e paredes"); a roof of cardboard, fabric or plywood is one layer too, the lower one** (`ROOF_MASTER_PLAN` v0.22). What a shot leaves per material (rubble, splinters, stamps, tear, punch-out) is `RubblePresets` + `ShotPunchTable.TEAR_SIZE`; explosions inherit it next.

> 🧭 **2026-10-04 — order of the next rounds.** See [`docs/production/roadmap.md`](../../docs/production/roadmap.md)'s top block (single source) and `RENDER3D_MASTER_PLAN` v1.61 (R3D-FINISH). The materials milestone (glass reopened, the 8 library materials) runs after the stealth loop and minimal confrontation.

> 🧭 **2026-09-27 — reorganization pointer.** M1/M2/M4 (glass) are DONE. M5 (voxel props) is now `RENDER3D_MASTER_PLAN`'s `R3D-PROPS` track — read there for current status. The `plastic` backing and S-4 fracture art stay deliberately unmade (see `RENDER3D_MASTER_PLAN`'s OPEN THREADS).

> ⏭️ **2026-09-30 — the material library grows, with FAMILIES and FALLBACKS (Director; `PROPS_TIER4_PLAN` §2b, `ACTOR` D66).** One new row field: `family` (`wood | metal | stone | soil | fabric | paper | plastic | rubber | leather | ceramic | glass | organic | generic`); a flat material is `has_facade: false` (the field already means "draw the flat base colour": the `textured` flag first planned would only have duplicated it). **BUILT 2026-09-30:** `family` on every row, `generic` and the 8 new rows (all flat for now), `MaterialRegistry.resolve()`. The fallback chain, as built, is **own row -> the id with its last `_segment` dropped, repeatedly (`painted_metal_red` -> `painted_metal`) -> `generic`** (loud once per id); debris art falls back to the wood splinters under the material's own tint. (The `TextureResolver`'s silent `Tier.NONE` for a material that promises a facade is unchanged.) **Eight materials to add** (balance numbers calibrated with the Director from their analogue, the wood/plywood way): `plastic`, `rubber`, `leather`, `ceramic`, `paper`, `painted_metal` (+ a tint variant per colour), `upholstery`, `steel_dark`. A model's surface names select materials (D66); a plastic/rubber/ceramic/steel surface is flat, a leather/paper/upholstery/painted one uses a grayscale facade (B2). Plywood `destroy_factor` is now 0.95 (85% destroyed beside a grenade). M5 (voxel props) is `RENDER3D_MASTER_PLAN`'s R3D-PROPS track.

> ⏭️ **2026-09-29 — material rows moved for props (Director):** wood `flammability` 1.0 -> 1.4 and `burn_consumption` 0.0 -> 0.2 (the ratified 0.0 overridden); plywood 1.1 -> 1.5, 0.35 -> 0.6 and `destroy_factor` 0.8 -> 1.0 (wood 0.75). Wood and plywood walls, floors and firearm damage moved with the crates. Every ember-lit voxel now ends CHARRED (`FACE_SOOT_CHAR`). Record: `RENDER3D_MASTER_PLAN` top block.

> ⏭️ **2026-09-25 — registering a material got simpler (R3D-END END-4).** The second list (`BakeCompositor.VOXEL_MATERIALS` / `VoxelRenderer.BASE_MATERIALS`) and the voxel atom are gone: a material is its `ASSETS/materials/<id>/` folder plus its `MaterialRegistry` row (`material_tree_selftest` checks they agree).

> ⏭️ **2026-09-23 — props (`ACTOR` D65):** a static prop is a mesh lit by the board's cell planes (+1.5 ms for 20 on the Moto); a
> prop that can break is a voxel container, which is M5. Built by `RENDER3D` R3D-PROPS.


> ⏭️ **2026-09-23 — the end of RENDER3D rewritten (Director):** the 2D board retires when nothing depends on it, not when the look matches. R3D-8 is renamed **R3D-END**, with six stages before it (R3D-8 to R3D-13); the look register moves after the end (R3D-LOOK), and rotation becomes R3D-ROT. See `RENDER3D_MASTER_PLAN` v1.19.

⏭️ **2026-09-15:** M5's blocker, "renderer v2", is now
[`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md). M5 follows its R3D-3: from there, thin
and half-thickness geometry — the awning, hoarding and scaffolding of §8 — is an ordinary
mesh, not a new tile class.

**Status:** 🟢 **v1.9 — 2026-09-07: M4's CASE TESTING ran, and glass took two more
rulings.** `GLASS_MASTER_PLAN` v1.47: **G-D48** (the SHOCKWAVE ZONE — glass-only
effective destruction out to 5 GU on a descending ramp, crazing 2 GU further, via a
real glass-only re-flood; retires `SHATTER_BLAST_GAIN` / `SHATTER_BLAST_EXTRA_RINGS`
and the bullet logistic on the cook path) and **G-D49** (re-damage on an
already-crazed pane collapses a REGION from the impact instead of crazing again).
⚠️ The ramp values are placeholders awaiting the Director's on-screen calibration.
The same session closed G-D48's own render gap — a pane taken in an extended ring
was destroyed in the data and still painted until a rotation rebuilt it (928 stale
cells → 0); the fix was to join `ring_of` so PHASE_PACKAGE owns the erase.
Nothing in M4 changed status: it is still glass, still essentially done.

Earlier, v1.8 — **2026-09-06: M4 (GLASS) IS ESSENTIALLY DONE — the whole
shard-rain track (`GLASS_MASTER_PLAN` §18) closed 2026-09-06.** `GLASS_MASTER_PLAN`
v1.43: G1, G2, G7, G-MAP, G-D9, G3 (all four stages), G-VARIANT, G-ART, the CRACK
(sprite over the pane, CRACK-02 — CRACK-01 in the voxel shader was rejected 3×),
the blast CRAZE family (G-D35), G6 shards on the floor, and §18 end to end —
**G4-1** the 5-shape family · **G4-2/3** remnants stuck in the frame · **G6b-1**
the field (one texture, one draw call) · **G6b-2** the fall (aged in FRAMES) ·
**G4-4** the scatter table + the shockwave impulse (the pane's pile went from a
line to a 284-cell band) · **G-D45** a remnant whose frame is destroyed falls with
it · **G6b-3** the dust puff. The §8.1/§8.2 CRACKED-tier blockers were resolved by
Director ruling 2026-09-02 (G-D3 + the CRACK-02 sprite). ⚠️ B-4's per-voxel
perforation was built and ABANDONED (Director ruling); G-D25's big shards are
SUPERSEDED by G-D44. **Left in M4:** `plastic` (screen backing) and S-4's
four-class fracture art (order written, art deliberately not made); skylights
(G-D16c/d) have `lift` authored but no geometry to run on. (2026-10-11: skylights and every destroyed roof are
[`ROOF_MASTER_PLAN`](ROOF_MASTER_PLAN.md), roadmap A1d.)

Earlier, v1.5 — **2026-08-30: THE SEQUENCING BLOCK IS GONE.** M3-6 was
sequenced behind `PERFORMANCE_MASTER_PLAN` P7; **P7b and P7c shipped 2026-08-26**
(the `MultiMesh` circle field — the fire's worst frame 42.4 → 19.5 ms), so M3-6 is
UNBLOCKED and M3-7 follows it. **M4 — GLASS — is now the named next item**: it is
the one explosion follow-up the Director carried out of the detonation track
(*"tem que quebrar muito mais com a granada"*, the non-local pane break), and
`DETONATION_PRESENTATION_MASTER_PLAN` closed on 2026-08-29 explicitly *"com
exceção do vidro"*. M5 (voxel props) is still blocked on renderer v2 — and it is
also the real resume trigger for `OCCLUSION_MASTER_PLAN` Part 4.

Earlier: 🟢 **v1.4 — THREE OF SIX PARTS BUILT: M1, M2 and all of M3 AS SCOPED;
M3-6 and M3-7 are now registered (§3.6) after two days of living only in session
summaries.** ⚠️ M3-6 is sequenced behind `PERFORMANCE_MASTER_PLAN` P7 — §8.5 there
explains why the fire's frame cost has to come down before its voxel count goes up.
Earlier: **v1.3 — THREE OF SIX PARTS BUILT: M1, M2 and all of M3.**
M4 (glass, LAST by decision), M5 (voxel props, blocked on renderer v2) and M6
(fluid research) remain. Two things are open for CALIBRATION rather than
construction, both the Director's eye: the fire's and destruction's numbers, and
how present the decals should read at play zoom. §3.2 (the passage rule) and §3.3 (the tick)
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
| **M2** | Decals — the marks each material takes | ✅ **DONE 2026-08-21** — 9 files, brick only |
| **M3** | Fire that consumes and opens passages | **Large.** The milestone's centre |
| **M4** | Glass: seeing through it, and breaking it non-locally | ✅ **CLOSED 2026-09-06** — the whole `GLASS_MASTER_PLAN` (v1.44), not just §18. Nothing left in it is glass render or physics; see that plan's §10.1 for the row-by-row of what remains and who owns it. The one item still on M4's own plate is **`plastic`** (the black screen backing, below) |
| **M5** | Voxel props — the thing these materials are actually for | Medium, blocked on renderer v2 |
| **M6** | **Fluids: water, lava, sewer, quicksand** (Director, 2026-10-17: quicksand is ORDINARY `earth` as the base, made into a trap by a behaviour, not a new material); **gases** maybe, later | **Research first.** The list is scoped (§6), the design is not |

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
`ASSETS/materials/<id>/decals/decal_<family>_<material>_<n>.png`.

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
`VoxelBoard.IMPACT_DECAL_MATERIALS` **and** `IMPACT_CRACK_MATERIALS` → update
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

### 3.1a What fire actually operates on — the REMNANT (Director, 2026-08-21)

> *"o fogo precisa acontecer de maneira mais ou menos aleatória, subindo para os
> voxels mais próximos, apaga e vira brasa… Na prática panos vão ser cortinas,
> véus, toldos, coisas pequenas que vão entrar em combustão, e a maior parte já
> vai ser destruída no momento que a granada explode. Então o que queima na
> realidade é o que sobrar. Alguns materiais queimam um pouco e apagam, e outros
> são mais consumidos, como o papelão e o pano."*

**This resizes M3-3 downward, which is the useful part.** A fabric object is a
curtain, a veil, an awning — small — and **the blast has already destroyed most of
it before fire starts**. Fire is not a second destruction pass over an intact
object; it runs on the SURVIVORS at the edge of the hole. That is already the
shape the ember wave has (`_build_ember_wave` collects *"surviving combustible
voxels edging this blast's holes"*), so M3-3 extends an existing seam rather than
opening a new one.

The motion, restated so it is not re-derived: **somewhat random, climbing to the
NEAREST voxels, then it goes out and becomes ember.** Not a modelled flame front.

⚠️ **CONSUMPTION IS A SECOND AXIS, AND IT DOES NOT EXIST YET.** *"Alguns materiais
queimam um pouco e apagam, e outros são mais consumidos"* is a statement about HOW
MUCH is eaten. `flammability` is not that number — its own doc comment defines it
as a multiplier on **how long the ember GLOWS**, with wood the 1.0 reference. The
two disagree today, measurably:

```
wood 1.0 · plywood 1.1 · cardboard 1.4 · fabric 0.6
```

Fabric is one of the two the Director names as *most* consumed and carries the
**lowest** number on the table — which is defensible for glow duration (cloth
flares and is gone) and simply silent about consumption. **M3-3 needs its own
`burn_consumption` column**; reading consumption off `flammability` would make
fabric the least consumed material in the game.

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

### ✅ 3.1b BUILT 2026-08-21 — M3-3, and the ember wave turned out to be most of it

**Fire was already half built and nobody had noticed.** `_build_ember_wave()` +
`_climb_from()` in the pure plan already do exactly what §3.1's motion asks for:
FNV-1a rolls (*"mais ou menos aleatória"*), a creep that climbs ONE level at a
time and stops at the first level that does not catch (*"subindo para os voxels
mais próximos"*), and a duration that decays per rung (*"apaga e vira brasa"*).
What was missing was **consumption** — the lit voxels glowed and left their
geometry standing.

| Piece | Where |
|---|---|
| `burn_consumption` column + reader | `materials/<id>.json`, `MaterialResistanceTable`, `MaterialDef` |
| `waves["burn"]` — `{voxel, cell, level, at}`, deterministic | `detonation_plan_builder.gd::_maybe_burn()` |
| The clock, writing nothing | `burn_scheduler.gd` |
| THE ONE ADVANCE CALL (§3.3) | `room.gd::_advance_burn()` |
| 11 assertions, hole-guard proven load-bearing | `burn_scheduler_selftest.gd` |

**The burn has its own deterministic timeline and does NOT read the ember's.**
`EmberOverlay.add_ember()` rolls its glow with `randf_range()`; hanging a world
MUTATION on that would make two captures of the same detonation destroy different
voxels. The glow is the LOOK, consumption is the MECHANIC.

**Measured on the real map**, and it is §3.1's table:

```
FABRIC     340 of 340 lit (100%) — consumed over 1.90s
CARDBOARD  308 of 308 lit (100%) — consumed over 3.51s
PLYWOOD    113 of 326 lit  (35%) — last at 2.63s
WOOD       0 — VL-D4's look untouched, byte for byte
BRICK      0 — does not catch
```

Fabric entire and fastest, cardboard entire but slower, plywood partial. The two
controls hold.

**And a filmstrip isolates the FIRE from the blast**, which is the claim that
needed proving: `burn_fabric_a_postblast.png` (frame 35 — the fabric floor and
block are INTACT, the grenade was 3 GU away) → `burn_fabric_c_consumed.png`
(frame 115 — a crater, the block's corner eaten, and a tongue of fire climbing
the wall). Everything between those two frames is fire.

⚠️ **The bug this cost, and the print that caught it.** The first real run
reported `[E-BURN] 0` on **every** material including fabric at consumption 1.0.
`MaterialResistanceTable._scan_dir()` builds its row as an explicit whitelist of
four keys — adding a column to the JSON without adding it there makes the new
column read as its default **with no error anywhere**. This is CLAUDE.md's
floor-dent case exactly, and the reason `[E-BURN]` prints a count rather than
staying silent.

### ✅ 3.1c BUILT 2026-08-21 — M3-4, plywood, and the threshold it exposed

> Director: *"uma granada bem na base da parede abre passagem; mais longe queima
> menos."*

Plywood is the only material with a spatial rule (§3.1), and it needed **no new
data**: every ember entry already carries `r`, its horizontal radius from the
epicentre. A partial burner's consumption is scaled by a radial falloff over
`BURN_RADIAL_REACH_VOXELS`.

**No separate "is it at the base" term, deliberately.** A grenade is on the
FLOOR — the Director's own point when settling the passage rule — so the cells
nearest it ARE the base cells, by geometry. Radial falloff produces "the base
opens, higher up burns less" with no level rule to tune, and the upward
attenuation is already in the ember wave (`EMBER_CLIMB_DECAY`).

**`burn_consumption` 1.0 means UNCONDITIONAL**, which is the whole semantics of
the column: §3.1 makes fabric and cardboard *object-scoped, not radius-scoped*,
so 1.0 burns wherever it caught, and anything BELOW 1.0 is a base probability the
position modulates. One number, two behaviours, no second flag.

Measured on the real map, plywood, three grenade positions:

```
gu (34,3) — at the wall's corner    148 of 233 lit (64%)   base storey 60/64 cells open
gu (35,4) — one GU further           99 of 304 lit (33%)
gu (35,5) — two GU further           78 of 326 lit (24%)   base storey 11/64 cells open
```

*"Mais longe queima menos"*, monotonically.

#### ✅ RESOLVED the same day — a passage is an OPENING, not a demolition

> Director: *"Vamos habilitar passagens em destruição incompleta, não precisa
> estar totalmente destruído, desde que tenha uma lógica visual razoável."*

**"Lógica visual razoável" is taken literally, and it is what keeps this from
being a bare percentage.** A passage is a **contiguous run of face positions
where the WHOLE storey height is clear**, at least
`PassageQuery.PASSAGE_MIN_WIDTH_POSITIONS` (4 of 8) wide. Sixty scattered cells
are damage; four adjacent columns you can see daylight through are a doorway, and
a count alone cannot tell those apart.

Three rules fall out, each pinned by a test that fails without it:

| | |
|---|---|
| **Contiguity** | 4 clear columns ALTERNATING → NONE. The same 4 ADJACENT → CROUCH |
| **Full height** | one survivor per column on a diagonal — 56 of 64 cells gone, no column clear through → NONE |
| **Overlap** | storey 0 open on the left and storey 1 open on the right is two crouch holes → CROUCH, not STANDING |

#### ⛔ SUPERSEDED 2026-08-28 (D-2) — the criterion is the AMOUNT, not the shape

> Director: *"Quantos voxels sobram individualmente não é importante para definir
> se a passagem está aberta ou não. Podem ficar sobras decorativas, porém
> precisamos ter mais ou menos uma noção de quantos voxels foram removidos pra
> aplicar a abertura."*

**Two of the three rules above are gone.** A storey-face is passable when
`PassageQuery.PASSAGE_MIN_REMOVED_FRACTION` of its cells are gone under the pair
rule — 0.50, which is *the same doorway*: the run rule's 4 of 8 positions at full
storey height is 32 of 64 cells. **The bar did not move; the SHAPE requirement
came off it.** Contiguity and full-height both go, and their two selftests are
inverted in place with the ruling quoted rather than deleted.

**Overlap SURVIVES**, restated per position: two openings in different PLACES are
still two windows, and a version of this without the check answered STANDING to
that exact fixture.

What this buys, beyond the ruling: accumulation for free — three grenades on the
same concrete wall add up to one fraction, with no per-edge store and nothing to
keep base-keyed. Measured the same day on PLAYGROUND: fabric **100% removed →
STANDING** on one grenade, concrete **3% → NONE**, which is the ruling's own
*"o material duro destroi menos, como já funciona"* in numbers.

⚠️ **AND THE COOK FORCES NOTHING.** The bubble was proposed as a deterministic
opener (`DETONATION_PRESENTATION` §11.1); the Director ruled against it on
2026-08-28 — only the criterion changed. A wall opens because enough of it broke,
never because the aim dome covered it.

**The width is not derived from the sprite, and the reason is stated rather than
dressed up.** The baked agent measures 104 × 187 px (N facing, standing), but
converting sprite pixels to face POSITIONS runs through the 30°/45° projection
where a horizontal span mixes two world axes — there is no clean ratio to quote.
So: a GU face is 8 positions, the agent occupies one GU, and HALF a face is an
opening nobody would mistake for damage. It is a `var` (Rule 1) because it is a
stat.

**The Director's sentence now works end to end, measured on the real map:**

```
grenade at the wall's corner (34,3)   { "CROUCH": 2, "NONE": 4 }   base storey 60/64 open
two GU further out          (35,5)   { "NONE": 2 }                base storey 11/64 open
```

*"Uma granada bem na base da parede abre passagem; mais longe queima menos"* —
both halves. And the regression that mattered: intact walls still report
**NONE ×10** on PLAYGROUND, so the looser rule did not open anything by accident.

#### ⚠️ The bar this replaced, kept for the record

The other half of the sentence is *"abre passagem"*, and it does not:

```
passage over 6 burnt edge(s): { "NONE": 6 } · widest base storey 60/64 cells open
```

**The wall is 94% gone at the base and the query still says NONE**, because four
voxels survive and `passage_class()` requires EVERY cell of the storey-face
clear. That bar was read off *"é necessário que as duas estejam desobstruídas"* —
but the Director's wording on 2026-08-21 is narrower and post-dates the query:
*"precisa ter uma certa passagem livre **o suficiente para o agente passar**,
agachado ou em pé."* Enough clearance for a person, not a demolished GU.

**The spatial rule is not the problem — the threshold is.** 60/64 against 11/64
is a gap almost any threshold separates, so this is one number from the Director
rather than a redesign. `PassageQuery.clear_cells_in_storey()` measures it and is
already wired into the fire-out line, so every future run reports it.

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

### ✅ RESOLVED 2026-08-21 — a passage does NOT have to reach the ground

> Director: *"A passagem pode ser numa slice um pouco mais alta, não precisa
> necessariamente ser no chão. Mas normalmente nesse caso vai ser uma abertura que
> já existe, fechada por vidro, ou madeira, ou pano, etc. A abertura no material
> duro já existe. Então a granada destrói essas barreiras e o jogador passa pela
> janela. Porém, uma granada perto de um material mole vai estar necessariamente
> no chão. Por isso a abertura vai ficar naquela parte da parede, e precisa ter
> uma certa passagem livre o suficiente para o agente passar, agachado ou em pé."*

**`PassageQuery` needs no change** — it was already written to answer geometry
and let the caller ask about height, and that turns out to be the right shape.
The ruling adds the *reason*, which is worth more than the rule:

- **A raised passage is a WINDOW, and a window is authored, not blasted.** The
  opening in the hard wall already exists in the map; what the grenade destroys
  is the **barrier filling it** — glass, wood, fabric. So a raised CROUCH result
  is not a hole in the sky, it is a window with its pane gone.
- **A blast-made opening is at the base by physics, not by rule.** A grenade
  beside a soft material is *on the floor*, so the hole it opens is in the bottom
  storey. Nothing has to enforce "storey 0" — the geometry produces it.
- **The requirement is only that the clearance be enough**, crouched or standing,
  which is exactly what `passage_class()` returns.

⚠️ **This makes M3-2b (half-thickness) the load-bearing item it already looked
like**, and for a sharper reason than depth: *a window IS a half-thickness element
filling an authored opening in a full-thickness wall*. Without it there is no way
to express the thing the Director just described.

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

1. **`voxel_board.gd:1892`** resolves a neighbour's slice with
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

### ✅ 3.2d BUILT 2026-08-21 — what landed, and the one thing that did not

| Piece | Where |
|---|---|
| `Edge.occupied_sides` + `set_occupied_gu()` / `occupied_gu()` / `occupies_a/b()` / `is_half_thickness()` | `edge.gd` |
| The gate — the only place a `Slice` is born | `slice_generator.gd`, two `if`s |
| `panels` mapfile section, v1 | `map_sections_v1.gd` |
| Buffer applied once (Rule 7) | `map_compiler.gd` → `panel_instances` |
| One-faced edges emitted | `edge_extractor.gd::_extract_panels()` |
| 14 assertions, gate proven load-bearing | `half_thickness_selftest.gd` |

**The schema is `{"gu": [x, y], "face": "NW|NE|SE|SW", "material", "storeys",
"start_storey"}`** — the panel names the ABSOLUTE cell its face sits on. The
selftest proves why in one assertion: an edge drawn from (5,5) toward (4,5) has
its cells SWAPPED by `_init()`, so a `side_a: true` field would have put the pane
on **(4,5)** — the cell the author did not mean, silently. The absolute cell
survives the swap because the swap moves the labels, not the cells.

**A panel whose edge already exists fails LOUDLY** rather than merging. Authoring
a pane inside an existing wall has two plausible meanings ("make that wall half
thickness" / "add a pane"), and guessing between them is how the
`ground_concrete`/`concrete` duplicate-row bug read at the time.

**Proven on the real map**, three panels on PLAYGROUND (`burn_panel_1_intact.png`
→ `burn_panel_3_object.png`): two 2-storey glass panes and a 1-storey fabric
panel, standing in open floor beside the full-thickness blocks so the thinness is
directly comparable. The glass block plus its two panes is **18 slices / 2 304
voxels** where a full-thickness pair would be 20 / 2 560 — the two panes
contribute one face each, not two.

And the payoff, measured rather than argued:

```
passage_class over 10 edges (baseline):              { "NONE": 10 }
passage_class over 10 edges (after the object burn): { "STANDING": 10 }
```

The two half-thickness edges are in that ten. **They open by clearing the ONE face
they have** — structural, not lucky, which is exactly what §3.2b promised.

### ✅ RESOLVED 2026-08-21 — the corner column, and why "inside" never had to be defined

> Director: *"Não tem coluna de junção em meias espessuras se estiverem nas GUs
> de dentro do aposento. A junção é justamente pra completar as slices de fora,
> nas esquinas, afetando a GU da ponta. Se a meia espessura for nas GUs de fora,
> a coluna extra se faz necessária. Podemos habilitar as duas coisas, ou forçar a
> ser sempre pra dentro. **O problema é definir "dentro" quando não for um
> aposento regular.**"*

**Both are enabled, and the stated problem does not have to be solved.** Read off
`JunctionResolver.resolve()`: it finds an ELBOW — the GU that owns both faces —
and places the column at `gu + delta(fa) + delta(fb)`, the diagonal *"outside
both walls"*. So the column always completes the two **outer** storey-faces,
those on `gu + delta(face)`, and never the ones on the elbow itself.

**That makes "inside" the ELBOW, not the room.** Every junction has one by
construction. An irregular room, an L of free-standing panels, a corridor, a
tent — all answer the same way, locally, and no room has to be identified
anywhere. The rule is two lines:

```gdscript
if not edge_a.occupies_cell(gu + Face.delta(fa)): continue
if not edge_b.occupies_cell(gu + Face.delta(fb)): continue
```

Both legs must supply an outer face, because a corner needs two faces to be a
corner. Pinned by three cases, and the middle one fails without the rule:

```
two full-thickness legs                → 1 column   (unchanged — the control)
one leg half-thickness on the ELBOW    → 0 columns  (nothing outside to complete)
one leg half-thickness on the OUTER GU → 1 column   (the corner is real)
```

*(This also retires §3.2c's "JunctionResolver is side-blind" as an open item. It
was — the fix is that it now asks the edge, not the slice, which costs no extra
lookup.)*

*(Corrected while building: §3.2c listed `voxel_board.gd:1892`'s neighbour
lookup as the first thing to fix, on the grounds that its final fallback
`get_slice(neighbor_edge.slice_b_id)` has no null branch. Read again on the real
line, the very next statement is `if slice:` — it is guarded, and degrades to the
generic tile. The claim was wrong; nothing needed fixing there.)*

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

Light does not read `damage_state`. `VoxelBoard.build_occupancy()` is built
from `TileMapLayer.get_used_cells()`, and a DESTROYED voxel has its cell
**erased**. So "cardboard blocks light until it burns" needs **no opacity state
and no coupling to `LIGHT_MASTER_PLAN`** — it is a property of burning being
real destruction. Bump `room.bump_world_revision()` on every burn tick or
predictions go stale (`PREDICTION_MASTER_PLAN` §5.2).

### ✅ M3-1 — MEASURED 2026-08-21, and the claim is half right

`INFILTRAITOR_CAPTURE_ACTION=light_burn_probe` (`room.gd::_capture_light_burn_probe`; **deleted 2026-10-10**, CAPTURE_RAILS CR-5 — last in `9d577d29`),
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
  (`burn_fabric_nojunc_3_object.png`).

  ✅ **NOT A DEFECT — Director, 2026-08-21:** *"o que sobra do pano (e outros) são
  as colunas extras das esquinas, que em situações normais não vão existir. Não
  vamos fazer um quarteirão de pano, a não ser talvez numa tenda, e aí de qualquer
  maneira sobrar uma estrutura faz sentido."* A corner column only exists where two
  walls of that material MEET, and nothing is built as a block of fabric. Where one
  legitimately is — a tent — a surviving frame is the correct read, not a bug. The
  measurement stands as a description of PLAYGROUND's test block, which is a
  3-GU block precisely because it is a test rig.

  What this does NOT retire is §3.2c's separate point: `JunctionResolver` is
  edge-derived and side-blind, so a **half-thickness** panel still gets a
  full-thickness corner column. That one is still open, and is about width rather
  than survival.

  ✅ **And the older column bug — grenades not destroying them — is CONFIRMED
  fixed for every material, by measurement rather than by inference.** The
  Director recalled fixing it while working with wood and thought it *probably*
  generalised. `_phase_junctions()` passes `column.material` straight into the
  same `simulate_container_damage()` ring model, which reads generic; the real
  blast agrees, on two materials neither of which is wood:

  ```
  JUNCTION/brick     destroyed  0 · dented  0 · cracked  1     (a mineral marks)
  JUNCTION/plywood   destroyed  4 · dented  0 · cracked  0     (a soft one only holes)
  ```

  ⚠️ **And a trap for whoever measures this next:** wood and the three soft
  materials showed **no JUNCTION row at all** from the standard grenade cell
  (2 GU out), which reads exactly like "junctions are broken for this material".
  It is distance, not material — moving the grenade to the block's corner
  (gu 34,3) produced the plywood row above. A missing census row is not evidence
  of an inert path; it is evidence the blast did not reach.

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
| ~~**M3-2b**~~ | ~~Half-thickness elements~~ — ✅ **BUILT 2026-08-21**, §3.2d. Mapfile `panels` section; the junction column stays side-blind and is the Director's call | M3-2 |
| ~~**M3-3**~~ | ~~Burn state + a delta tick~~ — ✅ **BUILT 2026-08-21**, §3.1b. Fabric 100%/1.9s, cardboard 100%/3.5s, plywood 35%, wood untouched | M3-1, M3-2b |
| ~~**M3-4**~~ | ~~Plywood~~ — ✅ **BUILT 2026-08-21**, §3.1c. Radial falloff on the `r` every ember entry already carries; 64% consumed at the wall's corner vs 24% two GU out | M3-3 |
| **M3-5** | **Grenade and shot test matrix** — ✅ **TOOLED 2026-08-21**: `tools/persistent/build_material_matrix.py`, one grenade + one shot per material from real boots, geometry read from the mapfile. The per-material FILMSTRIP half waits on M2's decals | M3-4 |
| ⚠️ **M3-5b** | **SOFT MATERIALS ARE PROPS, NOT WALLS** — Director, 2026-08-23: *"não vão ser usados em paredes inteiras, esses materiais vão ser mais usados como cortinas, caixas e objetos decorativos."* Fabric and cardboard leave the wall vocabulary; the blast takes the object and the fire consumes the REMNANT (§3.1a) rather than a whole surface. Built as **F3/F4/F5** of `PERFORMANCE_MASTER_PLAN` §9 — a fire's cost is `duration / 0.20 s` committing frames, so a shorter burn is a LINEAR cut on the dominant term | — |
| ⚠️ **M3-6** | **Lateral propagation** — fire spreading sideways through a wall's internal slices, and chaining from consumed voxels (Director, 2026-08-22). **REGISTERED HERE 2026-08-23**: it had been carried in session summaries and in `PERFORMANCE_MASTER_PLAN` for two days without ever reaching the plan that owns it. ⚠️ **M3-5b LARGELY RETIRES THIS RISK** — if these materials are curtains and boxes, the multiplication has nowhere to run. Originally: ⚠️ **Sequenced AFTER PERF P7** — see `PERFORMANCE_MASTER_PLAN` §8.5: embers are spawned one per affected voxel and the spawn is O(N²), so M3-6 scales the fire's largest per-frame term linearly and its spawn cost quadratically. Judging this feature's LOOK through a frame time its own voxel count made worse is the trap §4 of that plan names | M3-3, PERF P7 |
| **M3-7** | **The per-material passage table as a measured acceptance** — carried from the session summaries, same registration gap as M3-6 | M3-2, M3-6 |

---

## 4. M4 — Glass

> ⬆️ **SUPERSEDED IN DETAIL 2026-08-30 by
> [`GLASS_MASTER_PLAN.md`](GLASS_MASTER_PLAN.md).** That plan carries the ratified
> design (now G-D1…G-D45), the verified seam table and the task order; M4 keeps its
> row in this milestone and nothing below is retracted.
>
> ✅ **M4 IS CLOSED 2026-09-06** — the whole `GLASS_MASTER_PLAN` (v1.44), not only
> §18: the shard rain, then the GLASS-OLIVE cast, then CRACK-04's rotation drift,
> then a truth pass over that plan's task order. Everything below reads as the
> design record; the live status is in that plan's header, and its **§10.1** is the
> audited list of what is left and who owns it. The only item still on M4's own
> plate is `plastic` (below) — S-4's fracture art stays parked inside the glass plan
> for the reasons §13.4 measured. **Three things below are now
> ANSWERED there rather than open:** the *"what is a whole window"* question (the
> grouping is `Slice.edge_id`, plus a `pane_id` derived at extraction — **G2 BUILT
> 2026-08-31**), and both carried defects — the far shotgun pellet that CRACKS glass
> and the empty DENTED band — which **G-D3 converts from accidents into intent by
> giving glass a CRACKED tier**, amending D22. One consequence worth carrying back
> here: G-D3 removes the need for `HOLE_ONLY_MATERIALS` **and** the `INTACT` branch
> that §4.2 said had to land together or not at all.
>
> ⚠️ **NEW MATERIALS this milestone now owes (GLASS_MASTER_PLAN G-D16/G-D17,
> Director 2026-08-31):**
> - **Glass tint/behaviour variants** — `glass_armored` (purple, high `RESISTANCE`,
>   G-D15's primed state), `glass_screen_{green,red,amber}` (dark terminal tone,
>   INDESTRUCTIBLE for control interfaces or BREAKABLE for TVs/circuits/news
>   panels). They share glass's one grayscale facade and G1's rendering — a tint
>   plus a `glass_class` tag, not new art.
> - **`plastic`** — a new BLACK material, the backing behind screen glass. A round
>   **DRILLS** it (a hole, but the round does NOT pass through — the opposite of
>   glass's G-D5) and fire **MELTS** it. Images/text are painted onto the plastic
>   later (a decal/composite layer, deferred); the glass in front supplies the
>   sheen. `RESISTANCE` row + burn behaviour + the paint layer are all M-scope,
>   not built.


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

### 2026-10-17 — what the Director added to M6's scope

*"ainda vai ficar faltando fluídos (água, lava, sewer, areia movediça (usar terra normal como base pra fazer armadilhas)), e talvez gases."*
The fluids M6 has to cover are therefore **water, lava, sewer and quicksand**, and **gases** are a maybe. Two things changed since this section was written, and the study should start from them:

- **The renderer it was written against is gone.** The "TileSet rebuild per frame that mints" worry (item 3 above) is history: the board is a 3D mesh over a packed `VoxelStore` (`RENDER3D_MASTER_PLAN`), and a surface that moves is already a solved shape here: `SoftSheetSim` + `SoftSheet3D` draw a dynamic surface as ONE node over a node texture, with the sim on a worker thread (`ROOF_MASTER_PLAN` v0.28-v0.43). A height-field fluid (item 1's second shape) can ride the same machinery (a coarse node grid in the sim, a fine skin in the vertex shader); a per-voxel cellular automaton would have to write the store, and every writer of the store is audited (`CLAUDE.md` rule 8).
- **Quicksand is not a fluid.** It is the existing `earth` ground with a trap rule on top (an agent that stands on it sinks and loses movement; how deep, how fast, whether it is visible, whether a rope / another agent frees it are the design). That makes it the cheapest first slice and the one that tests the "floor behaviour" seam (`SURFACES_MASTER_PLAN`: surfaces, tags, `surfaces/rules.json`) without any flow.

The open questions for the study stay the four above, plus: whether **sewer** is water with a smell/noise rule (an audio-detection surface: `NoiseSystem`) or its own thing; whether **lava** is a hazard that also lights (`LIGHT_MASTER_PLAN`: a light source from a material) and burns what it touches (`MATERIALS` M3 fire); and whether **gases** are a separate layer at all (a per-GU concentration plane read by detection and fire) or a later milestone. No design is ratified; no code exists.

### 2026-10-17 — the water study starts from the LOOK (Director)

Bench: `maps/PIPE_LAB.map.json` (two grated half-buried pipes in the long walls, A north, B south, a concrete channel between them; the pipe pieces are 1 GU `.vox` props from `tools/asset_generation/gen_pipe_vox.py`, because a voxel prop is one GU and ignores `rot`). Prototype: `WaterStudy3D` + `water_study3d.gdshader`, dev flag `WATER_STUDY=0..3` (0 flat tint, 1 stipple like the occlusion cutaway's dither, 2 surface: bands, edge foam, ring ripples, bubbles, 3 both); `INFILTRAITOR_WATER_STUDY=3 python3 tools/persistent/capture.py --map PIPE_LAB --take water_flow`. **Nothing is simulated: the flow is a scrolling field**, so the looks are judged before a mechanism (height-field on the `SoftSheetSim` machinery vs. per-voxel flow) is picked. Unshaded, so no light yet. **Ratified the same day: `waste` (the combined look, softer, slower; reads as dirty water with bacteria) is the DISCARD / sewer water; `clean` (no stipple, clearer) is tried as pure / treated water; `WATER_RAIN=<0..1>` adds concentric rain rings (prepared, not wired to any weather).** Flag is now `WATER_STUDY=<kind>` (`WaterStudy3D.KINDS`: flat, stipple, surface, waste, clean). The Director's idea that each effect belongs to a different environmental condition is NOT built: today the layers always run together. **Later the same day: rain is available on ANY exposed water (Director); `caribe` added: very clear light blue, no bubbles, caustics on the bed, the curbs' soft shade on the water and deeper blue toward the middle (uniforms `bubble_amount`, `caustics`, `depth_shade`).** **`esgoto` added (brown, murky, floating green scum, bubbles, dirt specks, slow; uniforms `scum`, `scum_color`, `dirt_color`, `detail_strength`).** **Looks ratified one by one on 2026-10-17 (all `WaterStudy3D.KINDS`, look only, nothing simulated): `waste`, `esgoto`, `clean`, `caribe`, `biohazard`, `toxic`, `nuclear` (slow popping bubbles, glow), `lava_gold`, `lava_crust` (Voronoi plates + glowing cracks), `lava_viscous`; rain on any kind. Also built, same day: `petroleo`, `acido`, `lama`, `criogenico`, `areia_movedica` (a look only: its trap rule is `earth` + a rule, not a fluid). Not yet ratified by the Director. NEXT: the mechanism (height-field vs voxel flow) and what each liquid DOES (noise, trail, crossing, fire, corrosion, slowing).** Older: Director's call on the look was open; the mechanism and the gameplay (noise, trail, crossing, A-to-B flow) come after it.

### 2026-10-17 — M6 study v1: the mechanism and what each liquid does (PROPOSAL, nothing ratified)

**Starting facts (read from the repo, not assumed).** The game is turn-based and its gameplay state already lives in per-cell planes (`VoxelBoard` light / soot planes, `NoiseSystem`'s per-tile intensity decayed each turn, the floor `tags` of `surfaces/rules.json`). A voxel is 1/8 GU, so a GU is 64 voxels per layer. `SoftSheetSim` + `SoftSheet3D` already prove one dynamic surface drawn as ONE node over a coarse node grid, sim on a worker. The twelve-plus LOOKS (`WaterStudy3D.KINDS`) are a shader over one flat sheet and need only a rectangle, a flow direction and a depth.

**The two shapes, against this project's constraints.**

| | Per-voxel flow (cellular automaton in the `VoxelStore`) | Cell plane + one sheet (height-field) |
|---|---|---|
| State | liquid voxels in the store, 64 cells per GU per layer | one `FluidPlane`: per GU (or half GU) a `kind`, a `level` (0..8 voxels of depth) and a flow vector |
| Cost | every flow step writes the store: remesh, light and support audits (rule 8), ~64x the cells | a few hundred cells a map; the sheet is one mesh per body |
| Look | blocky, the shader looks need a surface anyway | the existing looks drop in unchanged (`level` becomes the sheet's height, the kind its shader) |
| Fit to turns | a CA needs many steps to settle: not deterministic per turn without a budget | equalise / drain a fixed number of rounds per TIC: deterministic, replayable, cheap to predict (`PREDICTION_MASTER_PLAN`) |
| Verdict | **no** (cost, rule 8, nothing gained: water never occludes or breaks) | **recommended** |

**Recommendation: a `FluidPlane` ticked per TURN (state), drawn continuously (look).** Sources and sinks are the gameplay seam: a pipe emits `rate` voxels of depth per turn, a drain takes `rate`; between them each tick moves depth downhill along the channel (virtual-pipes style, a fixed round count, no randomness). The sheet's shader keeps running in real time, so the scrolling look and the turn-based truth never disagree. The pipe-to-pipe channel of PIPE_LAB is the bench: A emits, B drains, the curbs are walls the plane respects, a breach in a curb (a blast) lets it spill. Rain is a visual layer on any exposed sheet.

**What each liquid DOES (proposal, every row is for the Director to change).** Depth bands: SHALLOW (<= 2 voxels) is walkable, DEEP (> 2) is not walkable without a cost.

| Liquid | Walk | Noise | Trail | Other rule |
|---|---|---|---|---|
| clean / caribe | shallow free, deep blocked | splash raises noise on the tile (decays) | wet footprints, fade in N turns | puts out fire; reflects light (later) |
| waste / esgoto | shallow slows (+1 AP) | splash, plus a SMELL tag guards notice | dirty footprints | hides the agent's scent trail? (open) |
| biohazard | shallow slows | splash | red footprints that guards read as a clue | contact marks the agent (guards react) |
| toxic / acid | damage per turn standing in it | splash | corrodes: weakens a material it touches (concrete -> crumbs, metal -> rust) | acid dissolves cloth / cardboard props |
| nuclear | damage + a status | quiet | glow = the agent is visible in the dark | a light source (`LIGHT_MASTER_PLAN`) |
| petroleo | slows, slippery (random slide) | splash | black footprints | **burns**: a flame on it spreads over the sheet (reuses fire) |
| lama | shallow slows a lot, deep traps | LOW (muffled) | deep footprints | like quicksand, softer |
| lava (gold / crust / viscous) | lethal; crust plates are walkable but break | none | none | light source, ignites what touches it, a hardened crust is a bridge |
| criogenico | slows, a status that stops AP | splash | frost that guards slip on | freezes water it meets into plates |
| areia movedica | a TRAP on `earth`: sinks per turn, escape costs AP | none | none | not a fluid: a `FloorBehaviour` rule + this look; the cheapest first slice |

**Order of build.** (1) `FluidPlane` pure + selftest (equalise, source / drain, wall, determinism); (2) the plane drives the PIPE_LAB sheet (A to B, the kinds as skins); (3) walking (shallow / deep, AP cost) and noise; (4) trails; (5) per-liquid rules one by one, fire first (oil), then acid and lava; (6) quicksand through the floor-behaviour seam; (7) the Moto.

**Open questions for the Director** (nothing is built until these are answered): turn-ticked state with a continuous look, as proposed? are liquids ever lethal, or only slowing and revealing? may the agent swim a deep channel? is the pipe's rate fixed per map or can the player cut it (a valve, a grate)?

**Director's answers to the study (2026-10-17) and what they changed.** (1) Liquids loop in REAL TIME, never waiting on the turn, so the scenery lives (ice and a few others are frozen: `time_scale` 0); the turn-ticked `FluidPlane` is the gameplay truth only. (2) Each liquid will get its own effect: many LETHAL, others crossable; to be defined per liquid. (3) Few aquatic zones in a game: mostly decoration and blocked paths, but basic movement animations ON and IN water are to be authored so those zones are playable. (4) The player may modify the flow (valves, grates). **Built the same day: designer controls.** A liquid is `liquids/<id>.json` (`LiquidRegistry`, 18 files, `PARAMS` = the controls with range and description); a map places it with the `liquids` section and may override any control per body (more / fewer bubbles, speed, foam, colours ...), which is also the seam for procedural variation. Pinned by `liquid_registry_selftest`.

**Per-liquid rules RATIFIED (Director, 2026-10-17), recorded as data in each `liquids/<id>.json` `gameplay` block (`LiquidRegistry.GAMEPLAY_KEYS`; nothing consumes it yet).** Exposure model: a dose 0..1 that grows each turn in the liquid, by depth (`shallow` <= 2 voxels, `deep` above), shrinks by `recovery` outside, lethal at 1: **lethal in the deep, much less on top; the more contact, the worse.** Water, sewage and mud never kill by exposure (they slow, make noise, leave footprints); biohazard, toxic, nuclear, acid, cryogenic, oil (deep), lava and quicksand do. Oil is flammable and ignites the agent; clean water extinguishes; acid corrodes floor / curbs / metal; toxic corrodes paper / cloth; nuclear makes the agent glow; mud traps and muffles; quicksand sinks a level per still turn; lava crust plates are walkable for 3 turns. **Footprints: YES** (a colour and a lifetime per liquid); later more of them come from puddles, mud and dog droppings (props milestone). **Swimming and on / in-water animations are PLANNED for the MOVEMENT milestone** (blocked on the approved 3D agent model); `swim_ap` is stored, not used. Few aquatic zones per game: decoration, blocked paths, the player modifies the flow.

### M6 task list (planned 2026-10-17; the look and the data are DONE, everything below is unbuilt)

| Step | Task | Done when | Blocked by |
|---|---|---|---|
| F0 | ✅ Looks (18 liquids), `LiquidRegistry`, the `liquids` section, `gameplay` data, PIPE_LAB bench | `liquid_registry_selftest` green | done |
| F1 | ✅ (2026-10-17) **`FluidPlane`**, pure: per GU a kind, a depth (0..8 voxels) and a flow; sources and sinks (a pipe emits `rate` per turn, a drain takes `rate`); walls and curbs stop it; a fixed number of equalise rounds per TIC, no randomness | selftest: equalise, source to drain, wall, determinism, a breach spills | F0 |
| F2 | ✅ (2026-10-17; the Moto cost is F8) The plane DRIVES the sheet: depth is the sheet's height, the kind its skin, real-time looping untouched (ice frozen); PIPE_LAB: A emits, B drains | capture of A to B; Moto frame cost | F1 |
| F3 | ✅ (2026-10-17, to test by hand) **Exposure and wading** (`gameplay.exposure`, `wade_ap`, `noise`, `smell`): the dose per turn by depth, recovery outside, lethal at 1; the first hazard reads from the plane | selftest + a take on PIPE_LAB with a lethal liquid | F2 |
| F4 | ✅ (2026-10-17, procedural boot print, to test by hand) **Footprints** (`gameplay.footprint`: colour, lifetime in turns) through the existing floor-mark path (`FloorPile3D`) | a walked path leaves marks that fade | F3 |
| F5 | 🟡 mud trap + deep-lethal blocking built; **FIRE ON OIL BUILT 2026-10-18 (block below)**; corrosion, cryogenic freezing, lava crust plates and quicksand NOT yet (need a fire system / a floor-behaviour seam) **Per-liquid rules, one by one**: fire first (oil burns and ignites the agent, clean water extinguishes), then acid / toxic corrosion, lava (light source, ignites), cryogenic (freezes neighbours into plates), lama and quicksand traps (`trap`), lava crust plates | each rule has its own take and selftest | F3 |
| F6 | 🟡 the API is built and tested (`FluidPlane.set_source_rate`, `lower_ground` for a breach, `LiquidField.set_source_rate`); the valve's INPUT / HUD and the blast hook are not (a design call) **The player changes the flow**: a valve or grate on a pipe (the source rate), a breach by blast spills over the curb | take: close the valve, the channel drains | F2 |
| F7 | **Rain** wired to weather for any exposed body (the shader layer exists, `rain` 0..1) | a map with weather wets its liquids | weather system (none yet) |
| F8 | ✅ on the Moto 2026-10-17: ONE channel was 102 ms a tick; the lean loop + 0.5 GU cells + rounds spread over frames bring 8 channels to +0.9 ms/frame (second block below); then a worker thread and per-liquid rounds were added anyway for margin (third block below); the Galaxy A16 was measured too (fourth block) **Moto and Galaxy measurement** of a map with N bodies (cost per sheet, `FluidPlane` tick on the main thread; a worker only if it measures) | numbers in `DEVICE_DIAGNOSTICS` | F2 |
| F9 | Swimming / wading / struggling ANIMATIONS and the `swim_ap` rule | in the MOVEMENT milestone | the approved 3D agent model |
| F10 | Footprints from puddles, mud and dog droppings (AI + MOVEMENT milestones: guards notice and follow prints, see the 2026-10-17 rulings) | in the props milestone | props milestone |
| F11 | Gases (maybe), a per-GU concentration plane read by detection and fire | a separate decision | F1 |
| F12 | ⏸ **SHELVED (Director, 2026-10-17: a future expansion).** Flooding a whole segment (a breach lets water in, it spreads over the floor, the level rises by turns to the ceiling; submerged = a tint, bubbles, floating props). Feasibility MEASURED 2026-10-17 (block below): the `FluidPlane` cannot do it on the Moto; a wavefront + one level per compartment can, if the sheet gets a lean shader | the Director's call on the build | F1 |

Rules for the build: the plane never writes the `VoxelStore` (rule 8); a liquid's behaviour is read from its `gameplay` block, never from its id; a cell's level is derived (rule 9); a new writer of world state bumps `Room.bump_world_revision()` (prediction); the looks stay in real time and never wait for the turn.

**F1 + F2 BUILT (2026-10-17).** `FluidPlane` (godot/scripts/systems/fluid_plane.gd): virtual pipes with momentum on a grid of 0.25 GU cells, depth in voxels, 24 rounds per TIC, the rim ring spills (a body at the brim overflows), a per-cell ceiling stops a source pushing into a full pipe, GRATES (`add_grate`) pass a liquid by `gameplay.fluidity` (below 0.2 nothing, from 0.8 everything); `fluidity` is a new `gameplay` key on every liquid. `LiquidSheet3D` draws the body from the plane (vertex height = depth, vertex alpha = wetness) and eases to each tick; the looks loop in real time. The `liquids` section gained `fluid` (`cell`, `rim`, `walls`, `roofs`, `sources`, `sinks`, `grates`). PIPE_LAB: source in pipe A, drain in pipe B (1.0 against 2.0 in, so the channel fills to the curb and spills), grates at both mouths. Measured on the real map: caribe fills and reaches the curb by turn 100, esgoto (0.55) passes the grates at a lower level, lama (0.15) stays behind the grate. Dev: `FLUID_PREROLL=<turns>` opens a map already run, `FLUID_AUTO_TICK=<seconds>` ticks in real time; `Room.tick_liquids()` is the per-turn hook, NOT yet called by the turn controller (F3). Pinned by `fluid_plane_selftest`.

**F3 + F4 + the F5 / F6 parts that need no decision BUILT (2026-10-17, tests by hand tomorrow).** `LiquidExposure` (pure: the dose per step and per turn by depth, recovery, lethal at 1, wading points, blocked deep cells, the trap's AP), `LiquidField` (a GU cell to the liquid and depth in it, reading the planes), `FootprintMarks3D` (procedural boot prints, fading per turn). In `Room`: the movement overlay's `extra_cost` hook makes a liquid slow the step and a deep lethal one an unreachable cell; each step into a liquid adds its share of the dose and a splash (`NoiseSystem`) and starts the prints; the end of the player's turn adds the turn's dose (or recovers it); the start of the next turn runs `tick_liquids()`, ages the prints and charges a trap's AP; a lethal dose shows `ui.banner.liquid_lost` and resets the room as a capture does (**the mission-failure flow is a placeholder, a Director call**). New map keys: a prop placement `walkable: true` (a curb the agent may stand on; every other voxel prop still blocks its cell). Dev: `LIQUID_WALK="x,y;..."` walks the agent along a path (it writes `user://liquid_walk.log`: the capture harness filters stdout), take `wade_walk` on PIPE_LAB. Pinned by `liquid_rules_selftest`. **Decisions taken (recommended, to be confirmed):** step dose = 0.34 of the turn's rate; wading is `wade_ap` EXTRA MOVE POINTS per step (a third of an AP each), doubled in the deep, +1 if slippery; a deep liquid with a lethal deep rate cannot be entered; prints for 4 dry steps after leaving. **Not built, and why:** fire on oil and corrosion (no fire / corrosion system on props and floors), cryogenic freezing, lava crust plates, quicksand (a floor-behaviour rule, not a plane), rain (no weather system), the valve's input, the Moto / Galaxy measurement (F8: the handsets are tomorrow's test), swimming (movement milestone), other footprints (props milestone).

**Director rulings of 2026-10-17 (after the first review of F1-F6).**
- **Footprints:** up to EIGHT prints after leaving a liquid (`LIQUID_FOOTPRINT_STEPS`), the first well marked and each next one lighter (`LIQUID_FOOTPRINT_FADE`: the last starts at 12 % of the first), then every print fades over the liquid's `footprint.turns` and goes. BUILT. A guard that passes near may NOTICE a print: the chance rises or falls with the liquid's type (colour / contrast against the floor, smell), the distance, the guard's perception, the light on the cell, how fresh the print is. A noticed print puts the guard in SUSPICION and he FOLLOWS the trail. **Planned for the AI milestone (the perception roll, the suspicion state, trail following) and the MOVEMENT milestone (the guard's walk along a trail); the print DATA (cell, tint, age, strength, liquid id) must be readable by a guard then: `FootprintMarks3D` keeps it in `_marks`, expose a read when the AI milestone starts.**
- **Protection:** boots, suits and other gadgets that avoid the dose and the wading delay (and the prints) belong to the PROPS milestone; the rules already read `gameplay.exposure` / `wade_ap`, so a gadget is a multiplier on them, never a second path.
- **Lethal dose:** the agent returns to the CHECKPOINT. There is no checkpoint system yet, so the room reset stays as its stand-in (`_check_liquid_loss`); the complete mission flow (checkpoints, failure, retry) is the GAMEPLAY milestone.
- **Manipulable world objects (valve, switches, alarms, computers, wall panels, levers, door handles; also shooting out a glass / a lamp / a support):** attached equipment, CLICKABLE. LEFT click opens a menu with the options, RIGHT click runs the default action (a valve: open / close). On mobile the precise targeting for a shot is a double tap. One mechanism for everything manipulable. **Planned for the PROPS milestone** together with the interface; M6 already has the hooks (`LiquidField.set_source_rate`, `FluidPlane.lower_ground`) and the dev stand-in `FLUID_VALVE="seconds:body:source:rate;..."`.
- **Overflow — SUPERSEDED the same day (Director: no overflow; containers and places with liquid rise and fall up to the container's own level, nothing spills out; whole-segment flooding is F12, shelved). The PIPE_LAB margin / `rim` experiment below was reverted; the data keys (`fluid.rim`, a larger zone) stay available.** Record of the experiment: a body's zone may be larger than its channel: the curb is a `walls` strip of `height` (the channel's brim) and the floor beyond is ground 0 inside the zone, with `fluid.rim` the height of the zone's own edge (1 voxel: a puddle a voxel deep forms there before the rest leaves the body). With `rim` 0 the film leaves the edge too fast to be seen (6 wet cells); with 1 it floods the margin (320 cells). PIPE_LAB: the channel's drain is half blocked (0.3), take `valve_overflow` (valve shut, opens at 2 s, shuts at 16 s). Measured with a headless probe of the same numbers: the channel reaches the curb at turn ~40, the margin is wet from turn ~60.

**F12 feasibility, measured on the Moto g04s and the desktop (2026-10-17; `tools/persistent/flood_scenario.py`, scenario step `flood <off|level|plane05|plane025>`, `Room.scenario_flood`).** The bench puts the WHOLE playable floor (18 x 36 GU, `SEG_HEAVY`, portrait zoom 0.5, uncapped) under one body, no walls (every cell active: the upper bound), a source that keeps it moving. Release APK, mean over the segment, the log is `/tmp/flood_device.log`.

| What | Moto g04s | Desktop |
|---|---|---|
| `FluidPlane` tick, 0.5 GU cells (38 x 74 = 2 812) | **855 ms** (worst 866), main thread | 195 ms |
| `FluidPlane` tick, 0.25 GU cells (74 x 146 = 10 804) | **3 150-3 290 ms** (worst 3 440) | 700-780 ms |
| frame while the 0.5 plane ticks every 0.3 s | 254 ms (the main thread is the tick) | |
| board with NO flood (idle) | 26.1 ms/frame, GPU 24.6 | |
| ONE flat water sheet over the segment (the "level model") | **37.1 ms/frame, GPU 35.6: +11 ms of GPU**; CPU render +0.1; GL mtrack +13 MB at most | |
| STRESS (two stacked blasts + shot), sheet on vs plain | detonation 1: mean **117.0** vs 112.9 ms, worst 210.2 vs 197.6; commit frames 88 / 145 vs 80 / 147 | |

Reading: (1) the plane's cost is per CELL and per ROUND (24), not per wet cell, and it is GDScript on the main thread: a whole segment is 4 to 17 s of Moto time per turn at the two resolutions tried, so **the virtual-pipe sim is the wrong tool for a segment** (it stays the tool for channels and tanks); a worker thread hides the frame stall but not a turn that takes 0.9-3 s. (2) The level model's sim cost is nil; its cost is the DRAW: the liquid shader over a full-screen transparent sheet is +11 ms on the Mali and takes the heavy segment from 26 to 37 ms, over the 33.3 ms budget. The earlier lesson holds (a transparent pass costs ~8-10 ms there): a lean shader for the big body (flat tint, one or two noise taps, no caustics / foam / rain) is the first thing to try, and it is a hypothesis until measured. (3) Over the stress blasts the sheet adds ~4 ms a frame on average.

**Recommended model (not built): three phases.** (a) SPREAD: a wavefront by walkable distance from the breach (a BFS over the floor cells, `speed` GU per turn, walls and props stop it, a destroyed wall opens it; deterministic, a few hundred cells, no physics), drawn as the wet region with a soft edge. (b) LEVEL: when the compartment's floor is covered the water is a NUMBER per compartment (volume / area + inflow per turn), a flat plane at that height; props float at `y = level` (buoyancy is a lookup); compartments merge when a wall goes. (c) SUBMERGED: the level no longer exists; a tint through `BoardLook.grade()` (no screen read: the glass and the flash cost 250-295 MiB of driver memory on the Galaxy), bubbles as particles, distortion only inside the board's own shaders. A checkpoint saves (turn, level, inflow, breach) and restores it; the model is deterministic. **Fallback the Director named:** the water never leaves the container (no overflow, at most the container's own level) and the idea waits for a later expansion. Not decided; the Director chooses.

**F8 measured on the Moto g04s (2026-10-17; `flood_scenario.py --f8 --uncapped`, scenario step `flood ch1|ch4|ch8`, release APK, SEG_HEAVY portrait zoom 0.5, log `/tmp/flood_device.log`).** `chN` = N copies of PIPE_LAB's real channel (1.5 x 10 GU, 336 cells at 0.25 GU, source + drain, curb 2 voxels), each a `FluidPlane` and a driven `LiquidSheet3D` with the real look, all ticked together every 0.3 s on the main thread.

| Bodies | All planes' tick (main thread) | Board ms/frame | Render GPU |
|---|---|---|---|
| none (idle, and after) | 0 | 26.1 | 24.6 |
| 1 channel | **102 ms** (worst 104) | 41.3 (a hitch every tick) | 24.8 |
| 4 channels | **408 ms** (worst 412) | 115.7 | 37.3 |
| 8 channels | **819 ms** (worst 823) | 186.9 | 38.8 |

Reading: the tick is LINEAR in bodies (about 100 ms a channel, 0.30 ms a cell on the Moto, 12.7 us per cell-round) and the game ticks once a TURN, not every 0.3 s as the bench does; but a single channel already puts a 100 ms hitch on the turn's first frame, over the 33.3 ms budget, and three of them make a third of a second. The draw side: one sheet cost +0.2 ms GPU (it was off-screen / small), four to eight on screen +12-14 ms (the same transparent-pass price as the F12 finding). **Verdict: the plane must leave the main thread before any map ships a body, and it can be made cheaper.** In order of price: (1) tick on a worker (`WorkerThreadPool`, the `SoftSheetSim` precedent): the frame never waits, the sheet eases to the last finished tick; a body then costs a turn's latency (~0.1 s), not a hitch; (2) an ACTIVE-CELL list (skip cells that are dry with dry neighbours, and cells whose flux has settled), and fewer rounds for a thick liquid; (3) typed-array inner loop. The lean shader for large bodies (F12 finding) is the draw-side fix. Galaxy A16: not measured yet.

**F8 cost cut, measured on the Moto (2026-10-17, same bench, same APK path).** Three changes, in this order: (1) `FluidPlane._round_step`: the loop with its members in locals, the four neighbours unrolled, the rim visited by its own loop, a kept scratch buffer; **bit-identical** (the selftest pins a digest taken from the first form); (2) PIPE_LAB's channel at `fluid.cell` 0.5 GU: a tick needs `rounds_per_tick()` = 12 rounds instead of 24 (same distance a turn), the map's source / walls / sinks were re-zoned for the cell centres (a zone is the cells whose CENTRE it holds); (3) INCREMENTAL TICK: `begin_tick()` commits the last complete tick and queues the rounds, the sheet runs about a tenth of them a frame (`step_rounds`), and the RULES read `committed` (the state after the last complete tick, one turn behind the water the sheet draws), so what a turn sees never depends on the frame rate; a valve or a breach finishes the tick first.

| Bodies (Moto, uncapped, SEG_HEAVY portrait zoom 0.5) | before (102 ms a tick on the main thread) | now |
|---|---|---|
| none | 26.1 ms/frame | 26.1 |
| 1 channel | 41.3 | **26.1** |
| 4 channels | 115.7 | **26.3** |
| 8 channels | 186.9 | **27.0** |
| 8 channels at the old 0.25 GU cells (steps 1 + 3 only) | | 92.1 |

Desktop: 8 channels 190 ms -> 71 ms a synchronous tick from the loop alone; `liquid_rules_selftest` 10 s -> 0.9 s. Reading: the cell size is what made it fit (0.5 GU is 4 x fewer cells and half the rounds), the loop and the spreading make it smooth; the sheet's draw cost is outside this table (render GPU was 24.6-24.8 in all rows here; the earlier run that showed 37 ms for 4 and 8 bodies was taken while the main thread stalled, so treat that GPU number as unreliable, and measure a body on screen at the zoom of play before shipping a map with several). The water level the agent meets is the one at the START of the turn; the sheet may show it a few frames ahead. Galaxy not measured. The flow at 0.5 GU differs a little from 0.25 (PIPE_LAB at 60 turns: 1.92 voxels against 2.00).

**F8 margin: worker thread and rounds per liquid BUILT (2026-10-17, Director: "para ter margem").** (4) `FluidPlane.threaded` (default on in the game, dev flag `FLUID_THREAD=0` for the control): `begin_tick()` queues the tick's rounds as a `WorkerThreadPool` task, `has_pending()` / `finish_tick()` wait on it, a valve or a breach finishes it first, the sheet's `_exit_tree` waits for it; the sheet eases to the live depths while the worker writes them. Pinned: 30 ticks on a worker end on exactly the synchronous depths. (5) `rounds_scale` = `lerp(0.5, 1.0, fluidity)`, set by `from_body`: a thick liquid runs fewer rounds a turn (lama: 13 against 24 at the old cell). Moto, uncapped, same bench:

| Bodies | main thread, rounds spread over frames | worker thread |
|---|---|---|
| none | 26.1 ms/frame | 26.1 |
| 1 channel | 26.1 | 26.1 |
| 4 channels | 26.2 | 26.2 |
| 8 channels | 27.0 | **26.3** |
| 8 channels at the old 0.25 GU cells | 91.1 (GPU 32.9) | **31.8** (GPU 24.8) |

Reading: at 0.5 GU cells the worker is worth ~0.7 ms a frame for 8 channels; its real value is the margin for a finer grid or a bigger body (8 bodies at 0.25 GU: 91 -> 32 ms). The worker costs one task a body a turn; on a device with few cores the pool is shared with the soft sheets.

**F8 on the Galaxy A16 (SM-A166W, Mali-G68; 2026-10-18; same bench, uncapped, release APK, logs `/tmp/flood_g1.log` worker and `/tmp/flood_g0.log` main thread).**

| Bodies | worker thread | main thread, rounds spread | 
|---|---|---|
| none (idle) | 23.5 ms/frame (GPU 20.4) | 23.0 (20.0) |
| 1 channel | 21.2 | 19.6 |
| 4 channels | 21.5 | 21.5 |
| 8 channels | 21.8 | 21.5 |
| 8 channels at the old 0.25 GU cells | 28.0 (GPU 23.3) | 28.1 (24.3) |
| after (water removed) | 24.3 | 27.0 |

Reading: the Galaxy's baseline WANDERS by 2-4 ms between segments of one run (idle 23.0-23.5, the closing idle 24.3-27.0: the plan's standing warning), so the 0.5 GU channels are inside that noise, i.e. free; only the 0.25 GU case shows a cost (~+4.5 ms), and here the worker thread buys nothing over the main thread (28.0 against 28.1): the Galaxy has the headroom the Moto lacks. The Moto stays the floor device; the two agree that at 0.5 GU, with the rounds spread, up to 8 channels cost no frame time.

**F5 fire on a flammable liquid BUILT (2026-10-18; Director's rulings of 2026-10-17).** `LiquidFire` (godot/scripts/systems/liquid_fire.gd), one per body whose liquid is `gameplay.flammable`, owns which plane cells burn: `ignite(centre, radius)` lights the wet cells in reach; each TURN (`Room._liquid_fire_turn`, run BEFORE the plane's next tick so both read the same committed depths) water puts cells out, the front runs `fire.speed` GU (petroleo: 3), then every burning cell loses `fire.burn` voxels (0.15) and goes out when dry; oil that keeps arriving (a source) keeps the fire alive. `fire.dose_step` / `dose_turn` (0.5 / 0.5) are added to the agent's dose when it steps onto / ends its turn on a burning cell (lethal at 1, so one step and one turn kill; the room reset stands in for the checkpoint); a burning cell cannot be entered (movement cost 9999). Anything that lights it: a blast (`ignite_liquids` from `_start_detonation_sequence`, reach 3 GU = the fragmentation grenade's live rings, `BLAST_IGNITES_LIQUID_GU`, to become bomb data), every shot's impact cells (0.75 GU), the dev script `LIQUID_IGNITE="seconds:x,y,radius"`; an incendiary arrow and lava will call the same `ignite_liquids`. Water puts fire out two ways: a liquid that `extinguishes` standing on a cell (`LiquidField.extinguishes_at`, it also keeps the front out), and `LiquidFire.extinguish_rect(rect)` for the tools. The flames are drawn by the sheet's shader (vertex red = the share of burning cells around the vertex; tongues, red foot, yellow heart, unshaded), real time, so a paused game still burns. `state()` / `restore()` are what a checkpoint keeps (burning bytes, deterministic). Pinned by `liquid_fire_selftest` (13 checks); take `oil_fire` on PIPE_LAB. Galaxy A16: the f8 bench with the new shader branch shows no cost (ch8 21.3 ms against 23.2 idle; the Moto was not attached, so the floor device is NOT re-measured: do it with the next Moto round).

**Not built, ruled (Director, 2026-10-17): putting fire out as GAMEPLAY.** A water pistol (props milestone) puts out candles, fireplaces, burning oil, bonfires, torches and lowers the light of the place; fire extinguishers on the walls do the same. They call `LiquidFire.extinguish_rect` for oil; candles / fireplaces / bonfires / torches are props with their own fire (props milestone). **Light:** a burning body lights the place while it burns and the place gets darker when it is put out; today the fire is a glow in its own surface only. Feeding the board's light planes costs a repaint (the cloth roof's release repaint was 630 ms on the Moto), so the fire as a real light source is its own step, measured on the handsets before it is built. Still open under F5: acid / toxic corrosion, cryogenic freezing, lava crust plates, quicksand.

**F5 fire, the look reworked (2026-10-18, Director: "o mecanismo acende e apaga uma GU inteira de uma vez, fica esquisito"; "falta o principal que são as chamas").** (1) SMOOTH: `burning` stays the turn's truth, but what is drawn is `LiquidFire.visual` (0..1 a cell): a cell lights when its turn comes (`_lit_at`: a turn's front SWEEPS across the cells it gained over `SWEEP_SECONDS` 0.9; a blast opens outward at 7 GU/s), rises in ~0.25 s, and a put-out cell dies away over ~1 s (`advance_visual`, called by the sheet every frame; the vertex fire is the average of the four cells around it). (2) FLAMES: `LiquidFlames` (godot/scripts/geometry/liquid_flames.gd) spawns the blast's own `EmberOverlay` glows on the cells whose level is above `HOT_LEVEL`, anchored in 3D on the oil, each with its own life (0.6-1.7 s), rise (90-300 px/s) and size (0.5-2.0 of a coal), 3.5 a hot cell a second up to 160 a body; they are born on the ground, climb and fade, and stop where the fire is put out. Real time, so a paused game still burns. The selftest pins the sweep and the fade (liquid_fire_selftest, 19 checks). **Not measured on the Moto**: 160 embers a second is under what one blast throws, but the floor device has not run it (the Moto was not attached); do it with the next Moto round (a body burning at the zoom of play, uncapped).

**F5 fire, FINAL look (2026-10-18, Director: "parece lava; o óleo tem que continuar escuro, e as chamas sozinhas, mais abundantes, formam o fogo").** The surface tint is now a dial (`fire_surface`, dev flag `FIRE_SURFACE`, default 0.1: the oil stays dark) and the fire is made of flames. Research first (web, 2026-10-18): the common pattern for stylised fire is a billboard or mesh with a noise-scrolling fragment shader for the BODY plus a few GPU particles for sparks ([Godot stylized fire 3D](https://godotshaders.com/shader/stylized-fire-3d/), [Godot 3D fire shader](https://godotshaders.com/shader/3d-fire-shader/), [Duck in Town stylized torch fire](https://papaya-games.itch.io/duck-in-town/devlog/95149/how-to-make-an-stylized-fire-shader) for the Y-billboard and the mask, [Marina VFX stylized fire texture](https://realtimevfx.com/t/marina-vfx-50-weeks-of-stylized-vfx-between-art-emotion-code/29826) for the white-yellow-orange-red-black gradient ramp, [80.lv embers in Godot](https://80.lv/articles/stylized-fire-embers-vfx-set-up-in-godot/)); the main risk named is transparency sorting. Four experiments on PIPE_LAB, same oil, same light (takes `oil_fire_a` .. `oil_fire_d`, contact sheet `Screenshots/takes/oil_fire_compare.png`, git-ignored):

| | What | Verdict |
|---|---|---|
| A | only the blast's ember balls, 2.5 x as many | **read as bubbles / bokeh over the oil, not fire: discarded as the body** |
| B | only tongues: Y-billboarded teardrop quads, shape and colour from scrolling noise (`liquid_flame3d.gdshader`) | **reads as fire at once; first pass blew out to white (additive overlaps, intensity 1.25)** |
| C | tongues + balls | B plus sparks leaving the fire |
| D | taller, narrower tongues (1.3 GU high, 0.42 wide) + few balls | dramatic, covers the screen; too tall for a channel |

**Built: C, tuned** (intensity 0.8, orange body with a small yellow heart, alpha 0.9, 1.0 GU high / 0.45 wide, balls at 0.6 x the rate and 0.25-0.9 of a coal): `LiquidFlameTongues` (godot/scripts/geometry/liquid_flame_tongues.gd) is one `MultiMeshInstance3D` a body, 2 quads a plane cell, the whole instance buffer rewritten from `LiquidFire.visual` while something burns (level 0 collapses the quad, so the front sweeps and a put-out cell dies away exactly as before); `LiquidFlames` keeps the ember sparks. Dev flags to tune a look without code: `FLAME_STYLE` (embers | tongues | both), `FLAME_W`, `FLAME_H`, `FLAME_EMBER_RATE`, `FIRE_SURFACE`. **Cost on a handset: NOT measured** (no handset was attached when this was written): `tools/persistent/fire_scenario.py --device <serial> --uncapped [--extra FLAME_STYLE=embers]` runs it (PIPE_LAB oil, lit at 14 s, `idle` against `fire`); what to read: ~100 hot cells = ~200 additive quads and up to 160 embers a second. The Mali rule applies (a transparent pass ~8-10 ms: measure on the Moto before a map ships a big burning body).

**F5 fire, adjustments of 2026-10-18 (second round).** (1) Tongues smaller and more numerous (3 a cell, 0.38 x 0.75 GU), more sparks (`FLAME_EMBER_RATE` 1.3) and **fagulhas** (30 % of the sparks: tiny, quick, climbing 220-420 px/s, drifting sideways, 1.2-2.4 s). (2) **The flame follows the oil**: the drawn level aims at `live depth / 0.5 voxel` (`FULL_DEPTH`), so a thin film at the dry border carries a small flame that grows where the oil advances and shrinks as it burns away, instead of appearing or vanishing. (3) **Oxygen**: a roofed cell's air falls from 1 at the opening to 0 over 1 GU (`OXYGEN_REACH_GU`, a flood of the roofed cells from the open ones); below 0.1 (`STARVED`) a cell cannot burn and the front does not enter it, the sparks leave a pipe in proportion to its air, and a tongue's height is capped by the headroom under the roof (`headroom_gu`, voxels x 1/8 GU). (4) **Cool flames**: a share of the tongues (`fire.base_share`, 0.3) are small, in the liquid's cool colour (`fire.base`: blue [0.05, 0.28, 1.0] for oil; organic matter will take a deep red). The first try, a blue tint on the foot of EVERY tongue, was judged by the Director to make each flame's start too evident and the fire look smaller (it had read as one mass before): replaced by blue tongues scattered among the yellow. (5) **Sheet fix**: a vertex beside a WALL cell (ground >= 8, a pipe's shell) no longer averages that cell's zero depth, so the sheet meets the shell at its full height instead of sloping away from it in a gap. Pinned: liquid_fire_selftest (film, oxygen, headroom, starvation, 28 checks). Still not measured on a handset (see the F5 FINAL block).

**Ideas to make the fire prettier (for the next round, none built):** (a) a flash on ignition (a short bright bloom and a bigger first burst of sparks); (b) a glow on the floor and curbs around the flames (an additive splash decal, then the real light plane once its repaint cost is measured); (c) black smoke columns from burning oil through the existing `SmokeSparkOverlay` (dark, thin, rising slowly); (d) soot that stays on the curbs and walls beside a fire (the existing soot map); (e) height by neighbourhood: taller in the middle of a fire, lower at its edge, so it reads as one body; (f) a common wind sway shared by the tongues so they lean together; (g) a reflection of the flames on the oil (a mirrored faint copy under the surface); (h) crackle and whoosh audio; (i) heat haze: NOT with a screen read (the Galaxy memory cost), only a vertex wobble inside the board's own shaders.

---

## 7. Task order, one list

| Order | Task | Blocked by |
|---|---|---|
| ✅ | **M1** — five materials register, render, break, and are lit | done |
| ✅ | **M3-0** — pin the passage unit (§3.2) — the STOREY | done |
| ✅ | **MAT-SOFT-01** — soft materials are hole-or-nothing, in code and data | done |
| ✅ | **M2a** — the brick art order + `check_decal.py`, earned before the art | done |
| ✅ | **M2b** — the nine brick PNGs, delivered 2026-08-21 | done |
| ✅ | **M2c** — `brick` wired into both constants + manifest; same shot, same counts, 30 193 differing pixels | done |
| ✅ | **M3-1** — measure the light win — the visual half is free, the cast shadow is not | done |
| ✅ | **M3-2** — `passage_class()` + selftest | done |
| ✅ | **M3-2b** — half-thickness elements (the milestone's largest single item, and it was not fire) | done |
| ✅ | **M3-3** — fabric + cardboard burn, on the blast's survivors, delta tick | done |
| ✅ | **M3-4** — plywood burn (radial falloff; ⚠️ opens 60/64 and still reports NONE — see §3.1c) | done |
| 🟡 | **M3-5** — the matrix is a tool now; the filmstrip half waits on M2's decals | M2 |
| 🟢 | **M3-5b** — soft materials become props, not walls (§3.6) | PERF §9 F3/F4/F5 |
| ⚠️ | **M3-6** — lateral propagation through internal slices (§3.6) | PERF §9 |
| | **M3-7** — the per-material passage table, measured | M3-6 |
| 🟢 | **M4a** — glass transparency — ➡️ `GLASS_MASTER_PLAN` **G1**. Appearance signed off 2026-08-31 (`BackBufferCopy` container, calibrated); geometry still open (the Director will adjust) | Director: glass LAST |
| 9 | **M4b** — glass pane break — ➡️ now `GLASS_MASTER_PLAN` **G2/G3/G5**. ⚠️ `HOLE_ONLY_MATERIALS` and the INTACT branch are NO LONGER NEEDED (G-D3) | design ✅ ratified 2026-08-30 |
| 10 | **M5** — voxel prop class | M3, renderer v2 |
| 11 | **M6** — fluids: looks and data DONE (2026-10-17), build list F1-F11 above | F1 first |

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
