# Session 2026-09-02 (part 2) — CRACK-02: the crack leaves the voxel

The previous session is
[`RESUMO_SESSAO_2026-09-02_CRACK_01.md`](RESUMO_SESSAO_2026-09-02_CRACK_01.md),
which built CRACK-01 in five stages and then watched the Director reject its LOOK
three times, each rejection one level deeper than the last. The third took the
renderer itself and became **G-D27 → CRACK-02, §13, planned and unbuilt.**

**This session built it.** `GLASS_MASTER_PLAN` v1.22 → **v1.23**.

| | stage | commit |
|---|---|---|
| **S-1** | the crack leaves the voxel and becomes a sprite (G-D27) | `a6cb797f` |
| **S-2** | a destroyed voxel cuts the sprite (G-D30), and the dial | `a407b93e` |
| **S-3** | a crack survives a perspective flip — and a map defect surfaces | `34077458` |
| **S-4** | the four-class art order, WRITTEN; its art deliberately not made | *(docs)* |

---

## S-1 — the sprite, and the basis that changed job

`GlassCrackSprite` + `glass_crack.gdshader`: one node per crack event, parented
into the glass composite so G-D18b's agent rule still holds.

**The trick is that there is no inverse in the shader.** CRACK-01-D had measured
the wall face's basis and CRACK-01 spent it inverting a canvas delta per fragment.
S-1 bakes the FORWARD basis into the node's `Transform2D` instead, so the quad IS
the pane's parallelogram and UV is already the sheet. The basis changed job rather
than being thrown away, exactly as §13.1 predicted, and selftest [10] changed with
it — it now pins the sprite's transform against the renderer's own cell geometry
at **0.00000 px** over 13×11 offsets, while keeping the ground-plane inverse as a
control that MUST be wrong (6.25 voxels worst).

G-D26 (additive) is now enforced by BLEND MODE — `render_mode blend_add` is
literally `dst.rgb += src.rgb · src.a` — rather than by arithmetic inside someone
else's shader. And `glass_pane.gdshader` went back to exactly what it was before
CRACK-01-B, with a comment saying that putting the crack back in it is the
rejected design.

Deleted: the per-level R8 crack plane, the RGBAF groups strip,
`GLASS_CRACK_GROUP_CAP` and its 16-crack ceiling, five plane functions, and every
crack uniform on the pane shader.

### The capture that was correct for the wrong reason

The first clip captures looked right and proved nothing. **A centred hit cannot
exercise the pane clip**: the wide sheet is 44 voxels and that pane is 48, so the
bounds never engage. The demo now prints the sheet quad and the pane quad in
screen pixels — a comparison of two rectangles instead of a squint at an
isometric picture — and `INFILTRAITOR_CRACK_DEMO_EDGE=1` puts the impact on the
pane's edge so the sheet runs 22 voxels past the frame. It is cut dead on the
boundary: `glass_crack_demo_c02_edge_clip_after.png`.

## S-2 — the cut is a READ, not a second plane

§13.2 said "one per-level R8 plane written at the three erase seams". It is not a
plane. `erase_cell()` on `_glass_layers` is what actually removes a glass voxel
from the screen and **all three seams already go through it**, so a parallel plane
would be a third copy of the same fact, free to drift. The occupancy is walked off
the tilemap — the same authority `INFILTRAITOR_CELL_PROBE` reads — over the pane's
own ≤64×32 rectangle. The seams only FLAG; the rebuild happens once per batch, at
the five places `flush_damage_composite_pages()` already runs, so the cook's
per-cell erase loop does not become quadratic in the size of the hole.

§13.5's two side effects, both confirmed rather than assumed: a G-D9 brick band is
not on the glass layer either, so the web is cut off it for free; and armored
glass never destroys a voxel, so its occupancy is solid and the dial cannot erase
its core.

### ⚠️ The dial is not the small choice it looked like

`glass_crack_cut_triptych_2026-09-02.png` — one crack, one boot, 0.0 / 0.5 / 1.0
over a real hole punched through the real erase seam. On a single hit the dial is
a local decision about the bore.

`glass_crack_cut_shotgun_2026-09-02.png` — **the same dial on the real
`agent_shot` path, where it is categorical.** At 1.0 no web survives at all. Not a
tuning artefact: G-D24 turns every overlapping pellet crack into a hole, so the
shot ends `cracked=0 destroyed=279` and there is no standing glass under any of
the webs. At 0.0 the whole cluster is there. **This interaction between G-D24 and
G-D30 is the Director's to rule on, and no amount of reasoning about the shader
would have produced it.**

## S-3 — the round trip, and what it found

`_base_cracks` mirrors `_base_damage`: the impact in BASE coords and the sheet id,
nothing else. The pane, the run axis and the pane's bounds are re-derived from the
rebuilt geometry, so a crack is a handful of ints rather than a serialised sprite.

⚠️ It rebuilds through `sprite_spec()`, **never** `apply()`. Re-applying would set
the damage a second time and run G-D24 against the cracks it is in the middle of
rebuilding: every crack would cross the one before it and the pane would come
apart on a camera move. Selftest [13] pins both halves.

**The proof is a round trip, N → E → N**, which returns to the perspective the
crack was made in, where `cell_from_base` is the identity — so the rebuilt sprite
has to land on the very pixels of the pre-flip frame. Measured: **5853 of the
returning frame's 5855 bright pixels are the original's**, 2 new, bbox unchanged.
"A crack appeared somewhere" is what the eye would have accepted. (The frames
differ elsewhere by a 1382-pixel rectangle — see the correction below; it is the
CRACKED-glass block, and part 3 is where it stopped existing.)

### ⚠️ A map defect, and it is not glass's

Every crack reports "no pane voxel" in E/S/W on the GLASS map.
`PerspectiveMapper.layout_with_perspective()` rotates `wall_tiles`,
`wall_levels`, `solid_block_instances`, `floor_zone_instances`,
`voxel_prop_instances` and the rest — but **not `panel_instances`**, where every
half-thickness element lives, G-D9's windows included.

Measured from one boot, N then E:

    N: PANE_SLICE_16_10_SW cells (88,87)..(135,87)
    E: PANE_SLICE_16_10_SW cells (88,87)..(135,87)   <- identical

Seven of eight panes, all on a constant-y line a quarter turn must put on a
constant-x one. The panes stand still while the walls rotate.

⚠️ **CORRECTION (part 3).** I attributed a SECOND symptom to this defect — 1382
contiguous bright pixels that did not come back from the N→E→N round trip, read
as "a pane's own body". That was wrong, and part 3 found what it really was: the
CRACKED-glass rectangle. The demo never records voxel damage to base, so the
round trip restored no CRACKED states, so the opaque rectangle that had been
sitting behind the web simply was not rebuilt. **The measurement was right and my
reading of it was wrong** — and the same number turned out to be the exact
evidence for the defect the Director reported next. The `panel_instances` finding
itself stands on its own evidence: the pane cell dump, N against E.

That is ROOF-BAKE-02a repeating on a key nobody added. **Left alone and
reported** — it is a map defect independent of glass, and the fix is NOT a copy of
the block branch, because a panel carries a FACE and needs the `remap_tile_name`
treatment as well as `cell_from_base`. Rotation is suspended for performance, so
nothing is on fire.

## S-4 — the order is written, the art is not

[`ART_ORDER_GLASS_FRACTURE_CLASSES.md`](ART_ORDER_GLASS_FRACTURE_CLASSES.md):
the four classes (G-D28), `blast` = 3 × H/V flip hashed off the B4 FNV-1a
(G-D29), the free-size/aspect contract S-1 made real, and six wiring steps.

**The art is deliberately not made**, and the order says why in its §6: the
generator would have to produce the opposite distribution to the one it produces
(§13.4 — real bullet holes are SPARSE with a few LONG runners; the shipped sheets
are dense and even), `blast` has no centre so it is not a preset of a radial
generator at all, `blast_*` has no CALLER yet (§6.2 is unbuilt, and art for a
trigger that does not exist is a trap this project has paid for twice), and the
look has been rejected three times on this track already. **The next step is ONE
`tight` sample at the reference's density, at true size, for a yes or no.**

---

## §13.3 and §13.5, both closed with numbers

**§13.3 — the contract moved in S-1's own commit**, as the plan required.
`TextureResolver`'s `fracture_` branch accepts any size (the branch still has to
exist: an unrecognised prefix is Tier.NONE, the generic atlas, and no error at
all). `check_decal.py` swapped 1024×512 for an ASPECT rule, reads the spans out of
`glass_crack.gd` instead of duplicating them, and re-expressed the origin slack as
a fraction of the page — the same tolerance, because "4 voxels" against a page
with no fixed voxel extent would have quietly become 3× more permissive.

**§13.5 — perf measured, and the prediction did not hold.** Same map, same camera,
idle `GLASS`, 40 samples each side, `--disable-vsync`:

| binary | frame (median) | render cpu | draw calls |
|---|---|---|---|
| CRACK-01 `6d8bd94e` | **6.40 ms** | 3.10 ms | 7944 |
| CRACK-02 `a407b93e` | **6.40 ms** | 3.10 ms | 7944 |

Identical. Removing a `texture()` + branch from every glass fragment is real in
instruction count and invisible in the frame, because this board is not
glass-fragment bound (`render gpu` reads 0.0). Cost side: **+1 draw call and +1
quad per live crack**. Neither number is a reason to have done CRACK-02 or to undo
it — the reason was the look — but the plan predicted a win and there is not one.

## Three defects the new tests found, all invisible to every gate that existed

1. **A centred hit cannot prove the pane clip** (S-1, above).
2. **`_glass_composite_z` starts at −9999, below `CANVAS_ITEM_Z_MIN`.** Assigning
   it printed an engine error and left the node at z 0. The glass LAYERS never hit
   it because `_ensure_glass_sublayers()` sets the real z on its first line; the
   crack root can be asked for before any of that has run.
3. **`ImageTexture.get_image()` is a readback and can lag an `update()`.** A
   diagnostic that asked the texture read the occupancy one event stale and said
   the cut had not followed. The builder keeps the CPU-side Image as the authority.

---

# Part 2 — the Director's ruling, and the defect it named

He looked at the set and ruled on both open questions at once:

> *"a transparência está correta e o adesivo funciona. O único defeito é que falta
> o buraco no centro. As versões com o adesivo sem voxels atrás não funcionam,
> podemos descartar."*

**✅ G-D30 = 1.0.** The crack lives on glass that exists; 0.0 and 0.5 are
discarded. That was already the shipped default, so no behaviour moved — but
`glass_crack_selftest` [12] now PINS it, because it is a one-character edit away
from a design he has already rejected and nothing else would notice. The dial
stays: `INFILTRAITOR_GLASS_CRACK_CUT` is how the ends were compared.

**"Falta o buraco no centro" turned out to be two different things.**

1. **The DEMO was fabricating a crack with no round behind it** — a state the game
   cannot produce. It punched a bore only under `INFILTRAITOR_CRACK_DEMO_CUT=1`,
   so every other demo capture showed a web over intact glass. Fixed: the bore is
   punched first, always, through `_process_dirty_slice_voxel` — the same seam a
   round uses. This is the capture version of building a fixture out of the data
   that works.
2. **On the real path the hole was already there for ordinary glass** — measured
   on the GLASS map: pistol `destroyed=2` (1 per pane), assault rifle
   `destroyed=12` (6 per pane), each with the web around it and daylight through
   the middle (`glass_crack_real_bore_2026-09-02.png`).

## ⚠️ And chasing it found a real one

**For `glass_armored` and INDESTRUCTIBLE screens the missing hole is a genuine
defect, and it is on screen today.** Captured: a pistol on the GLASS map's
armoured pane reports `glass_armored:s1 cracked=63 destroyed=0` — correct, the
round did not pass through (G-D15, V-C's *"trinca mas o tiro para"*) — and draws
a **bullet web with an empty painted bore over glass nothing pierced**
(`shot_c02_screen_3_damage.png`). `GlassCrack.wide_for_blowout()` picks tight/wide
off `blowout` alone and has no class branch, so every armoured pane and every
screen wears a hole it does not have.

It cannot be fixed by making a hole — the class exists to say the round stopped.
**G-D28 already has the answer**: `armored`'s OPAQUE crushed-white core, never a
void. So S-4's `armored` sheet moves from a nice-to-have to the fix for a defect
the Director has already seen, and the art order now says so — it is the one class
that can be commissioned before the `tight` density question is settled, because
its vocabulary does not depend on that answer. ⚠️ §5 step 4 (the class-aware
selector) must land in the SAME commit as the sheet: a branch with nothing to
select is a branch nothing exercises.

---

# Part 3 — the square, and what it really was

He rejected the result again, and the rejection was precise:

> *"Não ficou bom. Volta a aparecer o quadrado em volta do decal. O único que
> funcionou foi o adesivo sobre o vidro intacto. Precisamos perseguir esse
> estado, e apenas remover os voxels do buraco, sem modificar o restante dos
> voxels atrás do adesivo."*

**A CRACKED glass voxel was not rendering as glass at all.**
`damage_variant_material("glass", CRACKED)` returns `"glass_cracked"`, and
`GlassMaterials.is_glass("glass_cracked")` is FALSE — so `_set_voxel_cell()`
skipped the glass branch entirely and placed the voxel on the **OPAQUE** layer.
Every cell inside the crack radius became a different material, and the crack
radius is a RECTANGLE. `DamageVariantBaker` reads the same function, so it had
also baked a full wall damage set for glass, which the swap path then used.

**Fix, one line where the rule belongs:** a glass family member keeps its own name
at every damage state. `damage_variant_material()` returns `base_material` for any
`is_glass()` id, which fixes the fallback path and the baked-swap path at once,
and `DamageVariantBaker.bake_all()` skips glass so it stops baking atoms nothing
may look up. The STATE is untouched — G-D3/G-D4 ratified that glass cracks, and
VL-PERSIST still saves it — it just no longer changes how the voxel LOOKS. That
is G-D26's own rule, applied to the place it had been quietly broken all along.

Pinned by `glass_crack_selftest` [2], strengthened from "not a decal path" to
**"identical to its own name, across every member × every damage state × blast"**
— 24 combinations. The old assertion passed while the bug shipped, because it only
asked whether the name was a decal.

## ⚠️ And it corrects Part 2's own reading of its own measurement

Part 2 reported that a pane's body (1382 contiguous bright pixels) did not survive
the N→E→N round trip, and filed it as a second symptom of the `panel_instances`
defect. **The measurement was right and the reading was wrong.** Those 1382 pixels
were the CRACKED-glass opaque rectangle: the demo records no voxel damage to base,
so the round trip restored no CRACKED states, so the block was simply not
rebuilt — which is why that frame was the one the Director singled out as *"o
único que funcionou"*. The evidence for the `panel_instances` defect was never
that pixel count; it is the pane cell dump, N against E, and it stands.

**The lesson is the sharp one of this session:** a same-boot diff told the truth
and I explained it with the first plausible cause instead of the one that was
sitting in the same frame. It took the Director's eye to read the number
correctly.

## And "falta o buraco no centro" was two things, only one a bug

- The **demo** was fabricating a crack with no round behind it — a state the game
  cannot produce. Fixed: it punches its bore first, always, through the same erase
  seam a round uses.
- On the **real path** the hole was already there: pistol `destroyed=2` (1 voxel
  per pane), assault rifle `destroyed=12` (6 per pane).
- ⚠️ **But for `glass_armored` and INDESTRUCTIBLE screens it is a real defect**,
  captured: `glass_armored:s1 cracked=63 destroyed=0` draws a BULLET web with an
  empty painted bore over glass nothing pierced, because
  `GlassCrack.wide_for_blowout()` has no class branch. It cannot be fixed by
  making a hole — the class exists to say the round stopped. G-D28's `armored`
  sheet (an OPAQUE crushed-white core) is the fix, and it is now S-4's priority.

All cited captures were RE-TAKEN after the fix, deliberately overwriting the ones
that were photographs of the defect: `glass_crack_cut_triptych_2026-09-02.png`,
`glass_crack_cut_shotgun_2026-09-02.png`, `glass_crack_real_bore_2026-09-02.png`.

---

# Part 4 — CRACK-03: the hole stops being a rectangle

With the square gone and the sprite at 80%, the Director named what was left:

> *"Tirando um ou 3 ou 18 voxels o problema é o mesmo: o buraco fica todo
> quadrado. Pra corrigir isso, eu vou propor a criação de um conjunto de voxels
> especiais, derivados do vidro intacto, mas que tem um recorte em alfa, formando
> arestas pontiagudas em direção ao centro do buraco […] dessa forma a gente
> estaria na verdade criando o verdadeiro caco com voxel atrás + adesivo
> complementando."*

**It is G-D25's primitive, not a new one** — the dented-ceiling alpha mask carving
a voxel's outline, pointed at the rim instead of at free shards. So no art, no new
render path: the wedge multiplies the alpha of the atom `_build_glass_pane_atom()`
already builds.

**And it does not re-create G-D26's moldura**, which is the check that mattered
before writing a line. G-D26 bans a per-voxel change to a property read
CONTINUOUSLY across the surface. A cut is a SILHOUETTE: the glass that survives is
pixel-identical to its neighbours and only its outline moved — the same reason a
DESTROYED voxel, a 100% cut, never framed anything.

### The mechanism, and why it needs no state

The rim is a **swap on the tilemap**, not a re-render. The alternative wanted the
edge registry (a neighbour is usually in another Slice), a dirty flag on a voxel
nothing damaged, and a second pass over geometry. The placed cell already carries
its source id, and `_glass_source_info` (the new inverse of the atom table) turns
that back into (material, face, mask) — so the rim needs no registry, no dirty
flags and no per-cell state. Atoms compose LAZILY: a map with no holes builds none.

### Then the Director's diagram corrected the count

`1 PIERCED VOXEL` → `4 CORNERS UNTOUCHED` → `4 SPECIAL VOXELS CUT OUT`.

The first build cut all eight neighbours. **A cell that touches the hole only at a
CORNER has not been broken by it** — cutting it eats glass the round never reached
and rounds the hole off instead of opening it. Now four, and
`glass_crack_selftest` [15] counts them against a real renderer, because the
difference between 4 and 8 on a one-voxel hole is invisible at play zoom. It took
a diagram to catch; it gets a test rather than an eye.

That change also moved the DIRECTION source: it now comes from the batch's erased
cells rather than from reading the tilemap for absence. "Absent" is also true one
cell past the pane's own frame, so averaging over absent neighbours made an edge
cell point half at the hole and half at the outside world — and the two could
cancel exactly, silently dropping the shard.

### Four defects the new tests found, two of them mine

1. **The face mask was not in the atom key.** The SIDE sliver marks the frontmost
   column of every GU, so a hole landing on a GU boundary cut **5 of its 8**
   neighbours. With the mask in the key it is 8 (then 4, by the diagram).
2. **The two axis maps overlap.** A level-only neighbour is the same key in both,
   so concatenating their keys visited it twice: a 1-voxel hole reported 6, not 4.
3. **`set_cell()` naming a source the LAYER's tileset does not have is SILENTLY
   IGNORED** — the cell keeps its old id and the swap looks like it worked. Found
   by the fixture, and worth remembering well past glass.
4. **`_glass_composite_z` starts below `CANVAS_ITEM_Z_MIN`** (Part 1's item 2).

### ⚠️ And the A/B instrument does not survive scrutiny

`INFILTRAITOR_GLASS_RIM=0/1` gives the same camera twice, and it is **not** a pixel
measurement: two boots differ by far more than the rim — the agent's selection
marker alone moved 27 336 pixels across a full-screen bbox. The rim is judged at
the ATOM (`glass_rim_atoms_2026-09-02.png`, and the silhouette composites), never
at a frame diff.

## The shape became a pool (G-D32)

The four candidates were rendered as hole SILHOUETTES from the real atoms rather
than described — spike-deep, spike-shallow, V-notch, 45° chamfer
(`glass_rim_shape_options_2026-09-02.png`). The Director's answer was better than
the question:

> *"Gostei muito dessas 4 opções que você mostrou. Se a gente puder randomizar
> todas elas para cada pedaço do buraco, melhor ainda."*

So they are a POOL, drawn per shard — **G-D32**, which also retires the
"borda ligeiramente irregular" he had ruled *preciosismo*, because the draw IS the
irregularity at no authoring cost.

⚠️ **It must be the B4 FNV-1a, never `randf()`.** The shard set is rebuilt on a
perspective flip (S-3) and on a load, so an RNG would reshuffle a hole's shape
every time the camera turned — the exact failure S-3 exists to prevent. Same rule
G-D29 already uses for the `blast` patterns.

⏳ **Open, and it is plumbing rather than design:** the hash key must be in BASE
coordinates or the shapes reshuffle on a flip anyway, and the renderer has no
base-space knowledge today. Recorded rather than decided by omission.

## 🟡 The standing proposal — the sheet stops drawing the bore

Asked for the best suggestion, and **NOT yet ruled on**. It is filed as G-D33
PROPOSED, and it is one move that closes two open questions at once.

**The voxel becomes the master and the sheet stops drawing a centre**, because the
bore is geometry now. The rim IS the hole's edge — four shards, four hashed shapes.
A sheet that still draws a crush rim means TWO AUTHORITIES describing one feature,
and after G-D32 they cannot be reconciled by authoring: the voxel side is drawn at
random, so no fixed art can match it. What is left for the sheet is what the voxel
lattice can never do — the fine radial runners and the craze field, at sub-voxel
scale.

Three things follow, and the third was not obvious going in:
- §13.4's measured mismatch closes in the same pass. With no centre to draw,
  *"sparse with a few long runners"* becomes the whole brief and the dense even
  field goes away by construction rather than by calibration.
- The rule is one line, not a case list: **the sheet draws a centre exactly when
  the geometry has no hole to show.** `tight`/`wide` no; `armored` and
  INDESTRUCTIBLE screens yes — the round stopped, no voxel was removed, so the
  crushed-white core is the only thing that can tell that story.
- G-D30's cut currently eats the sheet's bore, which is its brightest part. With
  no bore there is almost nothing left to cut, and the two mechanisms stop
  competing for the same pixel.

**Priority that follows:** `armored` before the `tight` redraw. It is the only
piece that fixes something wrong on screen today, and the only class whose
vocabulary does not depend on the density question — it will never have geometry
to match.

**What the proposal says NOT to do:** more shape variants, per-shape art, or
tuning `crack_strength`. Every advance on this track came from REMOVING an
authority — the crack left the voxel shader, the damage variant left glass, the
occupancy plane became a read, the cut left the sprite. None came from adding.
Taking the bore off the sheet is the same move once more, and it is the last place
where two authorities still describe one thing.

## State at close

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.24.** CRACK-02 S-1/S-2/S-3 built · **CRACK-03 (S-5) built** · S-4's order written and its art unbuilt · S-6 (G-D32's hashed pool) ratified and unbuilt |
| Verification | `project_lint` PASS (230) · `check_invariants` OK · CODEMAP fresh · `run_selftests` **50 clean, 0 failed** · `glass_crack_selftest` **55 checks** (32 → 39 → 45 → 48 → 52 → 55) |
| Captures (hand-named, rotation-proof) | `glass_crack_demo_c02_{tight,wide,gd24,edge_clip}_*` · `glass_crack_cut_triptych_2026-09-02.png` · `glass_crack_cut_shotgun_2026-09-02.png` · `glass_crack_flip_roundtrip_2026-09-02.png` · `shot_c02_{realshot,cut0}_3_damage.png` |
| Captures added in parts 3–4 | `glass_crack_real_bore_2026-09-02.png` · `glass_rim_ab_{pistol,rifle}_2026-09-02.png` · `glass_rim_atoms_2026-09-02.png` · **`glass_rim_shape_options_2026-09-02.png`** (the four hole silhouettes that settled G-D32) |
| **Open for the Director** | 🟡 **G-D33** (the sheet stops drawing the bore) — proposed, not ruled · the `tight` sheet's density, which G-D33 would fold into the same authoring pass · whether the `panel_instances` rotation defect is worth fixing while rotation is suspended. **RULED this session: G-D30 = 1.0 · G-D31 · G-D32** |
| **Open, plumbing** | G-D32's hash key must be BASE-space; the renderer has no base-space knowledge today |
| Unbuilt in glass | **G6** (shards on screen) · **G-D25** (big shards) · `plastic` · skylights · glass cube · G-D8's last third · §6.2's blast-crack trigger (which `blast_*` art needs) |

## The transferable lessons

1. **A capture can be correct for the wrong reason.** The clip pictures were right
   and proved nothing, because the sheet was smaller than the pane and the code
   under test never ran. Make the instrument print the two things it is comparing.
2. **A "plane written at N seams" is often a READ of something that already
   exists.** The glass tilemap was already the authority every seam went through;
   a second copy would only have been a way to disagree with it.
3. **A dial's value can be a design question wearing a number.** G-D30 looked like
   a local aesthetic choice until the shotgun capture showed 1.0 erasing every web
   on the map, via G-D24.
4. **Proving persistence needs a round trip, not a flip.** Coming back to the
   identity turns "is it still there" into a pixel comparison.
5. **Measure the perf claim even when it is obviously true.** Removing work from
   every fragment of a whole material moved the frame by 0.00 ms.
6. **A capture action can build its fixture out of the data that works, exactly
   like a selftest.** The crack demo made a crack with no round, so it
   photographed a state the game cannot produce — and the Director read the
   missing hole as the effect's defect. A demo of an effect must go through the
   event that causes it, not just the effect.
7. **Chasing a cosmetic complaint found a real one.** "The hole is missing" was
   right about the picture and wrong about the cause, and following it to the
   cause turned up armoured glass wearing a bullet hole it never took.
8. ⚠️ **A same-boot diff can be right while the explanation of it is wrong.** The
   1382-pixel rectangle was measured correctly and attributed to the first
   plausible cause in view (a rotation defect found minutes earlier) instead of
   the one sitting in the same frame. When a diff has an unexplained region,
   name it before filing it under something else.
9. **An assertion can pass for the whole life of the bug it was written to
   catch.** "CRACKED glass does not resolve to a decal path" was true, and the
   voxel still went to the opaque layer. Assert what must be TRUE (the name is
   unchanged), not what must be absent.
10. **Render the options; do not describe them.** The four rim shapes were
    composited as HOLE SILHOUETTES from the real atoms, in the iso lattice, with
    no game boot. The Director answered in one line and improved the question —
    all four, drawn per shard. A prose description of four wedges would have
    bought an argument instead.
11. **A cross-boot A/B is not a measurement.** `INFILTRAITOR_GLASS_RIM=0/1` looked
    like a control until the diff came back at 27 336 pixels over a full-screen
    bbox: two boots differ by the agent's selection marker and more. Where the
    effect is small, measure the ARTEFACT (the atom), not the frame.
12. **A silent engine no-op costs a whole debugging pass.** `set_cell()` naming a
    source the LAYER's tileset does not have is ignored — the cell keeps its old
    id and the swap looks like it worked. Found by a test fixture, not by the
    game.
13. **When two authorities describe one feature, remove one.** Every advance on
    this track was a removal: the crack left the voxel shader, the damage variant
    left glass, the occupancy plane became a read of the tilemap, the cut left the
    sprite. The standing proposal (G-D33) is the same move applied to the last
    pair.
