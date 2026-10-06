# Surfaces catalog — the floors and floor marks the game will need

Status: **proposal, 2026-10-06** (nothing here is built unless marked *have*). Written for the Director to cut, reorder and rule on;
the mechanism it leans on is R3D-SURFACES in [`RENDER3D_MASTER_PLAN`](../../PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md) (S1-S5, the ground
transitions) and the gallery that judges it (`maps/SURFACES_GALLERY.map.json`, `tools/persistent/surfaces_gallery.py`).

## 1. How a floor is made today (what the catalog has to fit)

| Route | What it is | Good for | Cost |
|---|---|---|---|
| **Facade** | 1024 x 512 **grayscale** pattern x the material's `base_color`, mirrored, also on walls and roofs | regular, man-made surfaces: tile, concrete, plates, planks, grating | cheap (one shared grayscale plane per material) |
| **Photo** | 1024 x 1024 **colour** plane, REPEAT in world space (one period per 8 GU) + the macro map, floor / roof roles only (`"surfaces": {"floor": "photo"}`) | organic, irregular ground: grass, soil, sand, gravel | ~3 MB VRAM each (Lossless), **cap 8 per map** (Director 2026-09-27) |
| **Patch** | GU-sized RGBA decal (`ground_decals`, kind `decal_patch_<kind>_<n>.png`, up to 3 variants) | breaking up the square grid: leaves, mud, pebbles, stains | one node set per kind, <= 3 draw calls |
| **Transition** | feathered overlay between two `photo` floors (`GroundTransitions3D`, built 2026-10-06) | organic <-> organic borders | border cells only |

*Have:* photo floors grass, dirt, gravel, sand; facade floors concrete, stone, brick, wood, plywood, metal, painted_metal, steel_dark,
ceramic, rubber, plastic, fabric, upholstery, leather, paper, cardboard, glass family; patch kind `leaf` (one variant, to be redrawn).
`check_surface.py` rejects concrete / metal / wood as photo planes today (their `slab_` was authored for the retired mirror compositor).

**The sizing consequence.** The three MVP chapters (`DESIGN_MASTER_PLAN` §14.3: Corporate HQ, Industrial site, Laboratory) are almost
entirely MAN-MADE floors. They ride the facade route, which is cheap and needs no photograph; the photo budget (8 planes) goes to the
outdoor and natural segments. A theme therefore needs: a handful of facade floors, optionally 1-3 photo floors for its outdoor part,
and a patch set.

## 2. Themes and the floors each one needs

Legend: **F** facade floor, **P** photo floor, **(have)** exists, **(new)** to source or author.

### 2.1 Natural ground (outdoor segments, any chapter's exterior)
| Floor | Route | Notes |
|---|---|---|
| grass, dirt, gravel, sand | P (have) | |
| mud | P (new) | wet dirt; the base under puddles |
| dry cracked earth / clay | P (new) | arid dirt, `earth`'s photographic cousin |
| forest floor (litter, needles) | P (new) | brings its own leaf/needle look; fewer leaf patches needed |
| snow | P (new) | + ice as an F or P variant |
| bedrock / rock slab | P (new) | |
| farmland (ploughed soil, hay) | P (new) | optional |

### 2.2 Urban outdoor
asphalt (P or F; photo reads better with cracks), cobblestone (P), paving slab (F), kerb / concrete strip (F, `concrete` have), road paint
lines (patch, see 3). Outdoor concrete is `concrete` (have) with stain patches.

### 2.3 Corporate / office (Chapter 1)
carpet (F, fabric family; two or three base colours by `base_color`, no new art), polished tile and marble (F, `ceramic` / `stone` have),
parquet (F, `wood` have), vinyl / linoleum (F, `plastic`), lobby stone (F), rubber mat (F, `rubber` have), elevator / stair metal (F).
Mostly recolours of facades that exist; the new art is the PATTERN grayscale (carpet weave, parquet herringbone, tile grout).
**BUILT 2026-10-06 (`tools/asset_generation/gen_corporate_floors.py`, seeded, procedural):** `tile` (grout), `parquet` (herringbone), `carpet` (fine weave) and five carpet PATTERNS (`carpet_plain`, `_stripe`, `_basket`, `_diamond`, `_check`), each in six colours (red, blue, navy, grey, green, tan). A colour variant is a JSON row only: `carpet_<pattern>_<colour>` with `"facade_from": "carpet_<pattern>"` borrows the pattern's facade (one PNG, one texture in VRAM); its `base_color` is a target albedo divided by the facade's mean, so every colour reads at the same brightness. A pattern feature must be >= 16 px (one voxel, ~12 px on screen at zoom 1) to survive in play.

### 2.4 Industrial (Chapter 2)
rough concrete (F have), diamond-plate steel (F new pattern), floor grating (F new pattern, **gameplay: see-through, may need the
transparent route**), painted metal with hazard stripes (F + patch), oil-stained concrete (concrete + stain patches), rust metal (F
variant), gravel yard (P have), packed earth (P have), wooden pallet floor (F `wood`), drain covers (patch / prop).

### 2.5 Laboratory (Chapter 3)
white tile (F `ceramic`), epoxy resin floor (F, near-flat, glossy-looking by value only), vinyl (F), perforated metal (F new pattern),
cleanroom grating (F), glass floor panel (the glass family), antistatic dark tile (F).

### 2.6 Spaceship / sci-fi
hull plating (F `steel_dark` / `metal`, new pattern), deck grating (F), composite panels with seams (F), light-strip floor
(F + emissive strip, an unlit decal, see 3), alien regolith / dust (P new), crystalline ground (P new, optional). Almost all F.

### 2.7 Domestic / dormitory (`DORM.map.json` exists)
wood planks (F have), vinyl (F), tile (F), rug (patch-sized fabric decal or a prop), carpet (F).

**Photo budget per theme** (<= 8): natural 6-7 if all are used (so a map picks 3-4); urban outdoor 2; corporate, industrial, lab,
spaceship, domestic 0-2 each. The cap is per MAP, not per game.

## 3. Patches (floor decals) and where they may appear

A patch is a kind (`decal_patch_<kind>`), 1 GU, 3 variants, authored full colour (clean: soot is a separate multiplicative layer) and
placed on the half-GU lattice today. Kinds, grouped by what they need to exist:

| Group | Kinds | Needs (base tags) | Forbidden on |
|---|---|---|---|
| Vegetation | leaf, grass tuft, moss, dead grass, pine needles, flower | `soil` or `organic`, not `arid` | `arid`, `indoor`, `sterile`, `metal` |
| Water | mud, puddle, wet sheen, snow patch, ice | `soil`, or `stone` / `concrete` outdoors; **not `arid`** | `arid`, `indoor` (except a leak puddle on tile / concrete) |
| Stones | pebbles, rubble, gravel spill, rock | `soil`, `stone`, `concrete` | `sterile` |
| Dust / dirt | dust, dirt stain, sand drift, footprints (cosmetic) | any non-`sterile`, strongest on `arid` | `sterile` |
| Wear | floor crack, chipped tile, worn carpet, scuff | the base's own family (a crack for concrete is not a crack for tile) | |
| Stains | oil, rust, water stain, soot-ground | `concrete`, `metal`, `stone`, `tile` | `organic` |
| Marking | hazard stripe, road line, bay number, arrow | `concrete`, `asphalt`, `metal` | `organic`, `soil` |
| Emissive / tech | light strip, hazard glow, vent grille | `sci-fi`, `industrial`, `lab` | `organic` |
| Debris (already exist) | wood, plywood debris; glass shards | wherever the thing broke | |

**The rule, stated once.** Every floor material declares **tags** (`soil`, `organic`, `arid`, `wet`, `stone`, `concrete`, `tile`,
`metal`, `wood`, `fabric`, `indoor`, `outdoor`, `sterile`, `industrial`, `sci-fi`); every patch kind declares `requires` and `forbids`
over those tags. A patch may sit on a floor iff all `requires` hold and no `forbids` does. **Co-existence** (leaf and mud together) is
the default; **exclusivity** is a `forbids` entry (no leaf in the desert: `leaf` forbids `arid`; no mud in the desert: `mud` forbids `arid`).
The check lives in `MapCompiler` (a placement the rule forbids is a loud `push_error`, never silently dropped) and a scatter tool
reads the same tags to choose kinds per zone. **BUILT 2026-10-06 (tags, vocabulary, the check; the scatter tool is not):** `surfaces/rules.json` (closed vocabulary + one rule per kind), `MaterialDef.tags` (15 materials tagged), `SurfaceRules`, the check in `GroundDecals3D.attach` (loud, per GU the quad covers), `surface_rules_selftest`, and the gallery generator leaves a forbidden cell bare.

## 4. Transitions by pair class

| Pair | Treatment | Status |
|---|---|---|
| organic <-> organic (grass / dirt / sand / gravel / mud / snow) | symmetric soft feather, 1 GU each side | **built** |
| organic -> human (grass onto concrete, dirt onto tile) | ONE-SIDED soft spill: the organic floor creeps onto the human one, not the reverse | proposed; needs an asymmetric variant (the human side gets no overlay) |
| human <-> human (tile / carpet / concrete / metal) | regular, right-angled: hard GU edge, optionally a threshold strip (a 1/8 GU line of a trim material) | today's hard edge; strip proposed |
| anything <-> water | not planned (water is a gameplay surface, outside this catalog) | |

## 5. Decisions and next steps

For the Director:
1. **Tags** as the single mechanism for coexistence / exclusivity (section 3), checked in `MapCompiler`. Yes or a different shape?
2. **Free placement of patches: BUILT 2026-10-06.** `ground_decals` `at` is on the voxel lattice (any multiple of 1/8 GU), `rot` free.
   Still proposed: a scatter section that fills a zone by density and tags.
3. **Order of art**, proposed by what the MVP chapters need first: (a) facade patterns for corporate, industrial and lab floors
   (carpet, parquet, tile grout, diamond plate, grating, epoxy), because the MVP is man-made; (b) the human <-> human threshold and the
   one-sided spill; (c) the natural photo floors beyond today's four (mud, snow, forest floor, dry clay), with their patch groups; (d)
   spaceship, last.
4. **Floor grating** (see-through) and **light-strip** floors are gameplay / lighting questions, not art: they should be ruled before
   they are drawn.

Sources are CC0 only (D57; ambientCG and Poly Haven have the Ground, Asphalt, Tiles, Carpet, Metal Plates and Concrete categories this
catalog needs); record each in `docs/PHOTO_SOURCES.md` as the leaf, brick and concrete art was.
