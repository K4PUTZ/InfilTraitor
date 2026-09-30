# PROPS_TIER4_PLAN
## Real models, material-driven colour, generic voxel replacement on a blast, a persistent charred pile — v0.4 (P1 voxelizer, P2 replacement and pile, P4 charred variety, P5 material zones and P6 contact shadows and P7 calibration BUILT 2026-09-30)

Session 2026-09-30, Director's planning round. Parent track: [`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md) R3D-PROPS (the tiers are ruled there, 2026-09-27; this file
owns the build of Tier 4 and the look/shadow questions that came with real models). Canon it extends, never replaces: ACTOR D65 (static props are meshes, breakable
props are voxels), the Tier 1-4 ruling (Tier 4 = a transient fragment swarm, not a `VoxelStore` container), the grayscale-art + engine-tint rule (`ART_SPECIFICATIONS`
§7c, B2).

**BUILT 2026-09-30 (P1, P2 and P3 pulled forward):** `PropModelFit` (one fit for drawing and voxelizing), `PropVoxelizer` (Akenine-Moller triangle/box, 1/8 GU, sorted, cached per model, `voxelizer_selftest` 6 checks), `PropFragmentSim` (pure, hash-seeded, fixed 1/60 s steps of simulated time: fall, carved by ring weight nearest-first, pushed from the blast, stack on the column under it, slump, charred tone `lerp(0.10, 0.30, h^2)`; 7 selftest checks), `PropFragments3D` (one MultiMesh draw; the prop shader gained `use_color` and `soot_affects`, off for every mesh prop), `Board3DLive.spawn_prop_fragments/spawn_prop_pile`, `Room` (`_start_prop_fragments`, the pile recorded in BASE coords in `_base_prop_piles`, replayed after a rotation, saved/restored/cleared by `SaveState`, running sims finished before a rotation or a save). **Timeline as ruled:** the LOGIC (broken flag, GU freed) is at the commit; the LOOK waits for the first frame after the flash (`Room.release_prop_breaks()`, called by `TestZoneController`): the mesh goes, 104 cubes (the real table: top + four legs) appear in place already falling, ~0.57 s simulated, 85% carved by the ring weight, 16 cubes left as a charred pile. Generic: any `mesh_tier 4` prop (a prop with no model voxelizes from its box). Cost (desktop): voxelize 2.5 ms once per model (warmed at board build), sim 0.02 ms/step (worst 0.07); the Moto is not measured. **Not built yet:** material zones / registry colour (the cubes are the material's flat colour, no texture: P5), the shader-side charred variety for walls and props (P4), prop shadows (P6), the calibration (P7); the chips/smoke burst of the old shatter still plays beside the cubes (tune by eye).

**BUILT 2026-09-30 (latest): P7 the calibration round.** (1) **The scale canon, written down and corrected:** ACTOR D61 already fixes it — **1 GU = 1.60 m, 1 voxel = 0.20 m (8 per GU axis), a storey = 8 levels = 1.60 m** (an agent ~1.5 GU tall is ~2.4 m only if it is read as a GU figure; the sprite is the reference, the canon is the floor). Earlier notes here and in `PROP_PIPELINE_PLAN` said "a GU is ~1.2 m": that came from reading the dormitory beds (8 voxels long = 1.6 m) next to a tall sprite, and it was WRONG; it is retracted. (2) **Every object is authored at real size in whole voxels** (`tools/asset_generation/gen_dorm_vox.py` header): bed 0.9 x 1.6 x 1.0 m, nightstand 0.6 x 0.6 x 0.6, locker 0.6 x 0.6 x 1.6 (the storey), bookshelf 0.8 x 0.4 x 1.6, desk 1.2 x 0.6 x 0.8, chair 0.6 x 0.6 x 0.8, bin 0.6 x 0.6 x 0.4; the slot defs and `mesh_size`s follow (table 0.709 x 0.499 x 0.441 GU = 1.13 x 0.80 x 0.71 m, the model's own proportions). (3) **Legibility rule, recommended D-P7a: a small thing is never less than 2 voxels (0.40 m) in any axis, and a handheld item is drawn at 2x its real length** (the pistol is 0.25 GU = 0.40 m for a ~0.20 m weapon) — at 0.2 m per voxel nothing smaller reads on a phone. Pending the Director's word if he wants 1x. (4) **`BoardLook.grade()` exists and is IDENTITY by default** (saturation 1, contrast 1, lift 0): `BoardLook.apply_grade(code)` returns the shader text UNCHANGED at the identity (zero ALU, nothing compiled) and otherwise injects one `grade_linear()` call on the final `ALBEDO`; it is wired into the board's walls/floors (`_make_material`), the decal shader, `PropMesh3D` and `PropFragments3D` (`BoardLook.graded_shader`). Trial values without editing code: `INFILTRAITOR_GRADE=sat,contrast,lift` (e.g. `1.25,1.1,0.0`); a malformed value is ignored. No art-directed values are chosen: that is the Director's eye on a capture. The Moto cost of a NON-identity grade is not measured (expected: a few ALU on a pixel-bound handset, to be A/B'd with `FRAME_PROBE` the day a value is ratified). `board_look_selftest` covers identity/inject/malformed and the charred range. (5) **Material numbers were NOT changed**; the calibration table (destroyed % and burn by material, from the registry rows) is in the session record.

**BUILT 2026-09-30 (latest): P6 contact shadows.** `PropShadow` builds a prop's shadow from its VOXELS (a mesh prop's `PropVoxelizer` cells, a voxel prop's standing store voxels, a pile's cubes): every vertical run of a column is swept along the board's key light (`KEY_DIR` (-0.45, 0.8, 0.4), the direction the face shader's `key` term uses: shadows fall toward +x, -z, 0.56 / -0.5 voxels per voxel of height), rasterised at 2 texels per voxel into a small L8 image, box-blurred, and drawn as ONE flat quad with `prop_contact_shadow3d.gdshader` (MULTIPLY like the tile shadows, `strength` 0.42, a hair above the floor). No shadow map, no per-frame work. **Lifecycle** (`Board3DLive`): built for every mesh prop and every GU of voxel prop at board build; a mesh prop's goes with its mesh (`remove_mesh_prop`); a voxel prop's is rebuilt when its standing voxel count changed (`refresh_prop_shadows`, from every blast and shot commit, limited to the GUs the commit touched); a pile throws its own small one when it lands and when it is laid back. Desktop cost: 25 ms once for the DORM's 18 shadows, ~6 ms per commit before the GU filter. `prop_shadow_selftest` (8 checks). The existing `prop_shadow3d.gdshader` is the billboard props' (untouched); this one is `prop_contact_shadow3d`.

**BUILT 2026-09-30 (later): P4 and P5.** *P4:* the charred tone is a RANGE, `BoardLook.SOOT_CHAR_MIN/MAX` (0.10 / 0.30) and `BoardLook.char_mult(h) = lerp(MIN, MAX, h*h)`: each charred voxel of the board's shader, each prop-shader cell, each fragment (hash of its cell/index) and each debris piece (hash of its BASE cell) takes its own tone; the hash runs only inside the charred branch. The walls' and props' pattern is a hash of VIEW cell coordinates, so it re-rolls on a rotation until R3D-ROT. *P5:* **colour and detail come from the registry** — `PropDef.surface_materials` maps a model surface (by its authored material name) to a registry material; `PropMesh3D.setup_model` builds one board-lit material per surface from that material's `base_color` and, when `has_facade`, its facade (the same `ImageTexture` the walls use, one per board: `Board3DLive.material_facade_texture`), sampled in WORLD space with the board's own 16-texels-per-voxel mapping (one fetch, dominant axis); the model's own texture is no longer read. The fragments take their zone's material the same way (`PropFragments3D`, one facade per node) so the cubes match the mesh they replace; the pile record carries `zone_materials`. **Materials:** `family` added to every row; `generic` + the 8 planned rows (`plastic`, `rubber`, `leather`, `ceramic`, `paper`, `painted_metal`, `upholstery`, `steel_dark`) created FLAT (`has_facade: false`, no art needed yet), numbers proposed from their analogues for the calibration round; `MaterialRegistry.resolve()` is the fallback chain (own row -> id with its last `_segment` dropped, repeatedly -> `generic`, one warning per id); a material with no debris art borrows the wood splinters under its own tint. **Two corrections to this plan:** (1) `textured` is NOT a new field — `has_facade` already means "draw the flat base colour" and a second flag would only duplicate it; (2) `ceramic.crack_factor` is 0.0 because `voxel_decal_selftest` refuses a crack promise without crack art (ceramic needs its crack decals before it can crack). **`BoardLook.grade()` is deferred to the calibration round (P7):** a colour grade with identity numbers is code for nothing, and its cost should be measured with the first real values. Pistol: `Metal` -> `steel_dark`, `Black` -> `rubber`, `LightMetal` -> `metal`; table: `wooden_table_02` -> `wood`.

**Moto measured 2026-09-30 (release APK, PROPS):** no GPU cost from P1-P5 (idle 25.0 ms, settled-after-blast 28.4 ms, identical to the commit before P4/P5); the break costs 12.2 ms of CPU once (`_start_prop_fragments`), inside the commit frame. Detail in `DEVICE_DIAGNOSTICS_MASTER_PLAN`'s top block.

**Status of the inputs (2026-09-30, built):** `wood_table` and `pistol_prop` draw real CC0 models (`PropDef.model`, `PropMesh3D.setup_model`, commit `ecf34cdc`); a Tier 4
prop already shatters by ring weight (`Room.apply_prop_proximity_effects`: ring 0/1/2 = weight 0.85/0.28/0.06, beyond = no swap, soot only) with the existing chip/smoke VFX
and a debris carpet. What is NOT built: the model turning into fragments that keep its shape, the pile, the charred variety, prop shadows, the colour grade.

## 1. Decisions — **D-P1 to D-P6 RATIFIED by the Director, 2026-09-30** ("então tá ótimo, vamos usar nossas próprias texturas"; the six recommendations below stand as written)

| # | Question | Recommendation | Why |
|---|---|---|---|
| D-P1 | Does the material come with the model, or from our library? | **Geometry + UVs + surface names come with the model; colour and texture come from OUR material registry.** `PropDef.surface_materials` maps a surface name to a material id (`"Metal": "metal"`); no mapping = `material_zones.default`. | One palette authority (the registry's `base_color`, already what walls, debris and soot read); the fragments, the debris and the soot are all keyed on a material id, so a model whose colour is baked in has to be mapped anyway; RAM: the table's own 1k JPG decodes to ~5 MB with mips, our facade is already resident; any CC0 model plugs in with no retouch. Cost: one draw per zone (table 1, pistol 2-3). |
| D-P2 | A LUT or a colour grade for one artistic universe? | **No full-screen LUT pass. One shared `BoardLook.grade()` function inside every board shader** (walls, props, fragments, debris): saturation / tone-curve / tint uniforms, a few ALU, zero extra passes. A 16x16x16 LUT texture can sit inside `grade()` later (one fetch) if the Director wants an art-directed grade. | The Moto is pixel-bound (idle 17.5 ms, 9.9 ms is the pixel floor; `DEVICE_DIAGNOSTICS` §15/v1.32): a full-screen pass costs what a fragment-shader tweak does not, and is UNMEASURED here — measure before anyone adds one. The palette itself is authored in the registry; the calibration round (§4 P7) captures every material and prop side by side. |
| D-P3 | Fragment size | **1/8 GU = exactly one board voxel** (`VOXELS_PER_UNIT_AXIS`). | The fragments read as the same matter as crates and walls; the table (0.95 x 0.67 x 0.59 GU) is 8 x 5 x 5 voxels: top one layer thick, legs one voxel wide, so top and legs survive. Finer (1/16) is x4 the fragments for little gain at this zoom. |
| D-P4 | What is the pile in the state model? | **Cosmetic, persistent, NOT `VoxelStore` claims.** A record per settled fragment (base cell, stack level, tone index, material) replayed after a rotation and saved/restored exactly like `_base_debris`. | Keeps R3D-CLAIMS' promise (no new per-voxel engine state); the pile is ~20-40 cubes in one MultiMesh. R3D-ROT deletes the replay (already on its list). |
| D-P5 | Charred variety | **Shader-side: the charred multiplier becomes `mix(c_min, c_max, h*h)`, `h` = a hash of the cell** (most dark, some lighter). Defaults c_min 0.10, c_max 0.30 (the Director's tuning: 0.03 too black, 0.18 too light as a single value). CPU-side things (fragments, debris) draw their tone from a ramp by a base-coord hash. | The plane's soot code is one 8-bit channel (base 6, 216 codes): a second charred level does not fit, and a third plane channel is +50% of the plane RAM. ⚠️ The shader hashes the VIEW cell, so a wall's pattern re-rolls on rotation until R3D-ROT makes the world fixed; fragments and debris do not (hashed on base coords). |
| D-P6 | Shadows for all props | **A contact shadow per prop, built from the prop's own voxel silhouette (§2.1), projected along the key light onto the floor; owned by the prop instance (gone on replacement, a smaller one under the pile).** No shadow maps. **Order: after the fragments and the pile**, with the hook (`prop.shadow_node`) designed in P2. | Real lamps were +24 ms GPU on the Moto, the board is unshaded by design; a silhouette quad is one cheap alpha draw. Turning it on before the destruction exists means redoing it: the shadow set changes with the prop's state. The wall-cast shadow already reaches a prop through the floor cell's light bucket. |

## 2. The build

### 2.1 P1 — `PropVoxelizer` (pure, generic, automatic)
`PropVoxelizer.voxelize(model_meshes, fit_transform, voxel = 1/8 GU) -> {cells: Array[Vector3i], zone: PackedInt32Array}`: each triangle marks the voxels its box overlaps
(conservative triangle/box test, so a leg thinner than a voxel is still one column), a closed mesh can ask `voxel_fill` for its interior; the zone of a cell is its nearest
triangle's surface. Runs once per `PropDef` (cached), ~60 cells for the table. `DEVICE`: measure first (the Moto is 3-4x the desktop); if it costs anything, bake to
`props/<id>.voxels.json` with a tool. The same cell set gives the silhouette for the shadow, the exact `prop_top_px` and a tighter pick box. Selftest: table -> top plate + 4 legs
(counts by layer), pistol -> one lying body, a unit cube -> 1 voxel, determinism.

### 2.2 P2 — the replacement (automatic for every `mesh_tier 4` prop)
The trigger is the one that exists: nearest ring weight > 0 -> replace; weight 0 -> soot only. Nothing per-prop to author.
Timeline (Director's 0.5 s; 30 frames at 60, **15 at the handsets' 30 fps: the sim must not depend on the frame count, only on elapsed simulated time**):
1. **The first frame after the flash:** the mesh node is removed and the fragment field (ONE MultiMesh of cubes, the `ShardField3D` precedent, ~100 instances, one draw, custom
   AABB) holds the voxelized shape in place. They are already falling.
2. **The wave arrives** (the prop's ring delay from the choreographer, so it reads as part of the same wave that takes the walls): each fragment rolls destroyed with
   probability = the ring weight, by hash rank (deterministic, the `_select_deterministic` idiom); destroyed ones vanish with chips + smoke (existing VFX) and an ember flash;
   survivors get an outward impulse from the epicentre scaled by the weight, an up-kick and a spin, from a hash, never `randf()`.
3. **Fall and pile:** simple integrator (gravity, no Godot physics). A fragment that reaches the floor or the top of the column height map snaps to the 1/8 GU grid
   (integer stack level): stacks fall ON each other. A few slump steps (a column 2+ voxels above a neighbour sends one fragment downhill) make it collapse, then rest.
4. **It chars as it falls:** the tone goes from the material's own to the charred ramp by ring weight.
5. **End state:** the pile (the settled survivors, charred) over the debris carpet (`FloorPile3D`, exists), the record of D-P4 written.
Budget to prove on the Moto: <= 100 fragments, the sim <= 0.3 ms/frame CPU, one draw. Determinism: the same blast on the same state gives the same pile (prediction purity: this
is presentation; only the pile record is state).
Rotation DURING the 0.5 s: input is already blocked while an action resolves; the record is written at the end.

### 2.3 P3 — pile persistence
`Room._base_prop_piles` (+ `SaveState` capture/restore/clear, `_reapply_*` after a rotation, AFTER the 3D board rebuild like `_base_debris`). Test: blast, rotate E-S-W-N, save/restore: the pile is where it was (a capture per view).

### 2.4 P4 — charred variety (D-P5)
`BoardLook.SOOT_CHAR_MIN/MAX` replace `SOOT_CHAR_MULT` in `OPAQUE_SHADER` and `prop_mesh3d.gdshader`; the debris/fragment ramp is a CPU palette of 5-6 tones. A real capture of a wall, a crate and a pile
side by side; the Director tunes MIN/MAX by eye.

### 2.5 P5 — material zones and the colour grade (D-P1, D-P2)
`PropDef.surface_materials`; `PropMesh3D._lit_material_from()` reads the registry colour (and the facade as a planar, world-space detail at the board's texel density, one fetch, optional per
zone: a pistol stays flat) instead of the model's own. `BoardLook.grade()` threaded through the board, prop and fragment shaders. Measure the Moto before and after (the shader ALU is
what moves the floor: `srgb_to_linear` alone was -1.5 ms).

### 2.6 P6 — prop shadows (D-P6)
From the P1 silhouette. Measured on the Moto with 20 props.

### 2.7 P7 — the calibration round (Director: "uma calibrada geral em todos os tamanhos")
In the **dormitory scene** ([`PROP_PIPELINE_PLAN`](PROP_PIPELINE_PLAN.md) §8, the Director's first content scene) plus one sheet: every prop at its size next to a wall, a crate, the agent and a guard; the GU-to-metre canon is written down (the canon is D61's 1 GU = 1.60 m: the table is 1.13 m wide = 0.709 GU; the
pistol is deliberately drawn at 2x its real length, 0.25 GU = 0.40 m, so it reads: D-P7a); `mesh_size` of every def is set from the model's own proportions; the palette sheet for D-P2.

## 2b. The material library (formalises D-P1; Director 2026-09-30: more materials to cover a wider variety of objects, with fallbacks, generic materials)

**What a material is today** (`ASSETS/materials/<id>/<id>.json`, two tiers `res://` then `user://`, user wins; `MaterialRegistry` / `MaterialResistanceTable`): balance numbers
(`destroy_factor`, `dent_factor`, `crack_factor`, `flammability`, `burn_consumption`, `smoke_chance`), `base_color`, `pattern_algorithm`, `has_facade`; art: a 1024x512 grayscale `facade_<id>.png`
(B2), a slab variant, decals (`decals/`, incl. debris). The registry already holds: brick, cardboard, concrete, dirt, earth, fabric, glass (+armored, 3 screens), grass, gravel, metal, plywood, sand, stone, wood.

**Two new row fields**
- `family` (`wood | metal | stone | soil | fabric | paper | plastic | rubber | leather | ceramic | glass | organic | generic`): what the material behaves and looks like in general.
- `textured` (bool, default true): false = a flat tint with no detail texture (small hard objects: a pistol, a plastic bin, a tyre read better flat at this size, and need NO art).

**The fallback chain (nothing ever renders as "missing")** — every lookup walks it, loudly once per id (`push_warning`), never silently:
1. the material's own row / facade / debris decal;
2. the family's generic row (`generic_<family>`: sane balance numbers, the family's typical colour, a family facade, a family debris decal);
3. `generic` (neutral mid-grey, mid-resistance, flat, generic debris).
A model's surface that names no known material resolves by rule 2/3 instead of failing; a pack that brings only a `.json` still loads (flat). This extends `TextureResolver`'s existing tier ladder
(USER -> DEFAULT -> NONE, where NONE today renders silently wrong — it becomes "the family's generic" instead).

**Materials to add first (every object the game is likely to need soon; each is one JSON row, art only where `textured`):**
| Material | Family | Textured | For | Balance analogue (to calibrate) |
|---|---|---|---|---|
| `plastic` | plastic | no | bins, electronics, grips, toys | wood-like destroy, melts: high flammability, smoky |
| `rubber` | rubber | no | tyres, mats, cable | hard to destroy, burns long and smoky |
| `leather` | leather | yes | chairs, holsters, bags | fabric-like, tough |
| `ceramic` | ceramic | no | plates, toilets, tiles, pots | brittle: high destroy, no burn, sharp debris |
| `paper` | paper | yes | books, documents, boxes of files | cardboard-like, burns fast |
| `painted_metal` | metal | yes | lockers, vehicles, appliances | metal, with a tint variant per colour (see the pipeline plan) |
| `upholstery` | fabric | yes | sofas, seats | fabric + foam: burns, smoulders |
| `steel_dark` | metal | no | weapons, tools | metal, darker colour |
The numbers are NOT mine to set: each row is proposed from its analogue and calibrated with the Director in the P7 round, the way wood/plywood were (plywood 0.95 beside a grenade = 85% destroyed).

## 2c. What the model-input pipeline changes here (2026-09-30, see [`PROP_PIPELINE_PLAN`](PROP_PIPELINE_PLAN.md); Director's rulings)
- **Several models of one slot at once.** The fragment replacement, the voxelizer cache, the shadow silhouette and the material instances are keyed by MODEL id, built once and shared by every instance (PP1 §1b): N tables of one model cost N transforms. Per-instance state (shattered, charred tone, the pile) stays on the instance.
- **A model that does not fit its slot falls to the slot's generic** (a box in the `generic` material), and the generic is a legitimate Tier 4 prop too: it voxelizes to a box of fragments. So the replacement must never assume a particular shape.
- **Scale target = the game's own** (1/8 GU fragments, a model fitted into its slot's box); scale problems are adapted as they appear.
- **The dormitory (PIPELINE §8) is the calibration room of P7:** sizes, palette, material numbers are judged there, with the agent and a guard beside every prop.

## 3. Risks
- The 30 fps handsets make 0.5 s = 15 frames: the animation has to read in 15 frames, so the sim is timed, not counted, and is judged on a device capture, not the desktop one.
- The pile is the first cosmetic state that survives a blast for props: it must ride the rotation and save machinery (P3) or it is a regression waiting for R3D-ROT.
- Voxelizing an arbitrary model can make a shape that does not read (a chair's thin back at 1/8 GU). The voxelizer logs cells per zone, and a def can carry `voxel_size` (1/16) when it must.
- A view-hashed charred variety re-rolls on rotation (D-P5); acceptable until R3D-ROT, said out loud.

## 4. Gates
Every stage: `verify.py smoke`; P2-P3 a desktop filmstrip (`build_filmstrip.py` style, fixed fps) and a `device_record.py` take on the Moto; P5-P6 a Moto GPU A/B (`FRAME_PROBE`); `verify.py full` once before the stage that touches a shader closes.
