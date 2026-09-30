# PROPS_TIER4_PLAN
## Real models, material-driven colour, generic voxel replacement on a blast, a persistent charred pile — v0.2 (PLANNING, nothing built)

Session 2026-09-30, Director's planning round. Parent track: [`RENDER3D_MASTER_PLAN`](RENDER3D_MASTER_PLAN.md) R3D-PROPS (the tiers are ruled there, 2026-09-27; this file
owns the build of Tier 4 and the look/shadow questions that came with real models). Canon it extends, never replaces: ACTOR D65 (static props are meshes, breakable
props are voxels), the Tier 1-4 ruling (Tier 4 = a transient fragment swarm, not a `VoxelStore` container), the grayscale-art + engine-tint rule (`ART_SPECIFICATIONS`
§7c, B2).

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
One sheet with every prop at its size next to a wall, a crate, the agent and a guard; the GU-to-metre canon is written down (the table is 1.13 m wide at 0.95 GU, so a GU is ~1.2 m; the
pistol is deliberately 0.40 GU long, larger than real so it reads); `mesh_size` of every def is set from the model's own proportions; the palette sheet for D-P2.

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

## 3. Risks
- The 30 fps handsets make 0.5 s = 15 frames: the animation has to read in 15 frames, so the sim is timed, not counted, and is judged on a device capture, not the desktop one.
- The pile is the first cosmetic state that survives a blast for props: it must ride the rotation and save machinery (P3) or it is a regression waiting for R3D-ROT.
- Voxelizing an arbitrary model can make a shape that does not read (a chair's thin back at 1/8 GU). The voxelizer logs cells per zone, and a def can carry `voxel_size` (1/16) when it must.
- A view-hashed charred variety re-rolls on rotation (D-P5); acceptable until R3D-ROT, said out loud.

## 4. Gates
Every stage: `verify.py smoke`; P2-P3 a desktop filmstrip (`build_filmstrip.py` style, fixed fps) and a `device_record.py` take on the Moto; P5-P6 a Moto GPU A/B (`FRAME_PROBE`); `verify.py full` once before the stage that touches a shader closes.
