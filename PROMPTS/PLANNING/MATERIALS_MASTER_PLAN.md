# MATERIALS_MASTER_PLAN
## The materials milestone — burn, breach, see through, and flow — v1.3

**Status:** 🟢 **v1.4 — THREE OF SIX PARTS BUILT: M1, M2 and all of M3 AS SCOPED;
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

*(Corrected while building: §3.2c listed `voxel_renderer.gd:1892`'s neighbour
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
