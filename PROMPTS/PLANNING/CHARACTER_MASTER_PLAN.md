# CHARACTER_MASTER_PLAN
## The Agent — Model, Rig, Poses, Animation, Layering — v2.0

**Status:** 🟢 **Part 0 CLOSED · Part 1 BUILT · reordered 2026-08-15 by D48.**
Execution plan for the living-beings track `ACTOR_MASTER_PLAN` (reopened
2026-08-13, decided 2026-08-14 as D32–D45, extended 2026-08-15 as D46–D48). It
replaces that plan's deferred Parts 1, 3 and 4, which were stubs, not designs.

| | State |
|---|---|
| **Part 0** — the two spikes | ✅ **CLOSED.** S1: ASTC yes, ETC2 no. S2: turn settled (D46), corner settled (D47) |
| **Part 1** — base model + rig | ✅ **BUILT 2026-08-15.** 20 bones, 36 parts, verified exact T-pose, 7 sockets. Its ART is superseded by D48; its RIG is the base |
| **Part 8** — professional showcase model | 🔜 **NEXT, promoted by D48** — was last, now first |
| **Part 2** — minimum viable agent | ⏸ waits on Part 8, per D48. Still the only Part with external dependents |

**Baseline:** VERSION 0.9.101, `main` at `4ab3824e`. No `verified/` tag since
`verified/v0.9.0`.

---

## 0. Ownership boundary — read before editing either document

| Document | Owns | Wins on |
|---|---|---|
| [`ACTOR_MASTER_PLAN.md`](ACTOR_MASTER_PLAN.md) | the **decision register** (D1–D45) and the objects track | *what was decided, and by whom* |
| **this plan** | the **execution** — what gets built, in what order, which test gates which stage, what "done" means | *how it is being done* |

D32–D45 are cited here by number and **never restated in different words** —
that is how two documents drift. If this plan seems to contradict a D-row, the
D-row is right and this plan is a bug.

**Companions:** [`WEAPON_MASTER_PLAN.md`](WEAPON_MASTER_PLAN.md) (aim mode,
W-PRECOOK — both gated on Part 2 below), `docs/DESIGN_MASTER_PLAN.md` (§8 cover
states, §9 damage, §10 armour tiers — the gameplay this plan renders),
`docs/technical/BAKE_SYSTEM_REFERENCE.md` (bake canon; D38 records exactly how
much of it applies here, which is less than it looks),
`docs/production/milestones.md` → GAMEPLAY-01 and MONET-01.

---

## 1. Why this plan exists

The agent today is **a 44×61 px vector box outline** drawn by `_draw()`
(`godot/scripts/agents/agent.gd`), with three posture shapes, no facing, and no
connection to any art pipeline. There is nothing to inherit and nothing to
extend — the character is the last major system in the game with no
representation at all.

Three things are waiting on it, and none of them is cosmetic:

1. **Firearm aim mode** (`WEAPON_MASTER_PLAN` §5c / D31–D36) needs an agent that
   holds a weapon.
2. **W-PRECOOK** (`milestones.md` → GAME-01, last item) needs the same.
3. **Every gameplay verb in GAMEPLAY-01** — cover, peek, prone, stealth mode,
   the distraction verbs — currently has no way to read on screen.

---

## 2. The decisions this plan executes

Pointers only. Full text in `ACTOR_MASTER_PLAN` §2.

| D | One line | Where it lands here |
|---|---|---|
| **D32** | Identity lives outside the body; two fixed archetypes sharing skeleton, pose library and animation timing | §3, §4.2, Part 6 |
| **D33** | Gameplay silhouette shows tier; big model shows identity; appearance changes by silhouette *class* (Diablo 1), not per item | §4.5, Part 5, Part 8 |
| **D34** | Only archetype × silhouette class may multiply; layers are additive; colour is free | §8 |
| **D35** | Source is a **rigged low-poly mesh**, action-figure read, gangster/Michael Jackson | §4 |
| **D36** | Cosmetics express state, never grant it; a purchasable indicator needs a free fallback | §9 #4 |
| **D37** | Hood and cape are back-mounted; deploying the hood opens a reduced-visibility mode | §4.3, Part 4 |
| **D38** | The bake **compositor** does not transfer; the resolver ladder and B1/B3/B6 discipline do | §5 |
| **D39** | Poses are keyframes; **animation between them is the deliverable** | Part 3 |
| **D40** | Clothing is baked into the silhouette class; the weapon layer indexes on **grip** (~3), not pose | §8, Part 4 |
| **D41** | Guards are nearly free — one body, uniform + tint, authored head turn | Part 7 |
| **D42** | The binding constraint is **RAM, not CPU**; variants are mutually exclusive at runtime | §8 |
| **D43** | Cape is a synced animated layer; variants are tint over **one** shared motion | Part 4 |
| **D44** | **Four facings, permanently** — a diagonal step is two orthogonal GU steps | §4.6 |
| **D45** | Mirroring rejected; turn smoothness is game-feel, settled by a real test | Part 0 S2, Part 3 |

---

## 3. The character, concretely enough to model against

**Who he is** (D32): a cunning operator — socially fluent, reads between the
lines, persuades and deceives. A double agent. After the campaign, renegade to
both the corrupt police and the drug lords, and **motivated by something
renewable, never resolvable** — a trauma/revenge spiral is both the cliché the
Director rejected and a structural failure under `DESIGN_MASTER_PLAN` §19 Rule 1.

**How that reads on screen:** not in a face — the identity lives in lore,
abilities, movement style, technology and contacts. What the body carries is
**cadence**. The tonal anchor the Director gave is a trickster with humour
(*"olha o passarinho"* as a way to neutralise a guard), which rules out the
brooding-operative posture language entirely.

**Art direction** (D35): action figure — visible joints, swappable parts,
low-poly, **not** realistic and **not** the robotic reference the Director
supplied. Crossed with gangster / Michael Jackson: elegant but stealthy, able to
move between two worlds. Note this is the *same* reference D16 named on
2026-07-26 (Moonwalker arcade pose/silhouette language); the direction has been
stable since July.

**Why action figure is load-bearing and not just taste:** a figure with visible
joints and detachable parts makes D34's layering (hood on the back, weapon in
the hand, pauldron on the shoulder) read as *native construction* rather than as
compositing artifacts. The art style and the architecture agree.

---

## 4. The asset to build

### 4.1 Format and loading
glTF (`.glb` or `.gltf`), loaded at runtime through
`GLTFDocument.append_from_file()` + `generate_scene()` — no Godot editor import
step. This path is **already proven** by the Showcase shotgun (ACTOR Part 5a)
and the grenade (D24).

### 4.2 One skeleton, two archetypes
D32 requires the masculine and feminine archetypes to **share skeleton, pose
library and animation timing**; they differ in mesh, proportion and head. That
is what keeps them one character in two bodies, and it is what keeps the pose
and yaw terms of §8's budget **shared instead of doubled**.

Consequence for authoring order: **the skeleton is authored once, first**, and
the second archetype is a mesh retarget onto it — never a second rig.

Minimum bone set, driven by the poses §4.4 requires — **proposed, not ratified**
(§9 #1): root · hips · spine · chest · neck · head · (shoulder, upper arm,
forearm, hand) ×2 · (thigh, shin, foot) ×2. ≈ 20 bones. Prone and full-cover
crouch are the two poses most likely to demand more.

### 4.3 Sockets — the anchors the layer system composites against
Named attachment points, exported with the model, resolved **per (pose, yaw)**
so the compositor never guesses:

| Socket | Carries | Rigid? |
|---|---|---|
| `hand_R` | weapon (grip-indexed, D40) | rigid |
| `hand_L` | off-hand / two-handed grip | rigid |
| `back_upper` | hood, cape (D37) | **hood rigid; cape deforms — D43** |
| `chest` | medals | rigid |
| `shoulder_L` / `shoulder_R` | pauldrons | rigid |
| `arm_L` | armband | rigid |

The cape is the one deforming attachment and is why D43 gives it a synced
animation instead of a rigid composite.

### 4.4 The pose set
Not invented here — every entry below is demanded by an already-ratified
mechanic:

| Pose | Demanded by |
|---|---|
| idle (standing) | `agent.gd` posture STANDING |
| crouch | `agent.gd` posture CROUCHING; §8.2 half cover |
| prone | `agent.gd` posture PRONE; §8.2 minimal cover |
| against-cover (full) | §8.2 full cover |
| peek | §8.3 |
| weapon lowered / ready / aimed | §8.7 aim mode; D40's three grips |
| death | §9.2 — *"a distinct death animation"* is explicitly required |
| hood up / down | D37 |

**"~8 per activity" (D3) remains a working figure, never an enumeration.**

### 4.5 Silhouette classes, not outfits
D33/D40: armour is a **class of dressed body**, not a garment layered over a
naked one. `DESIGN_MASTER_PLAN` §10.1's seven armour tiers map onto **3–4
silhouette classes** (the Diablo 1 precedent: ~3 visual classes across dozens of
items), with colour and rigid adornments carrying the rest of the
differentiation. The exact count is §9 #2 — the single number that most moves
§8's budget.

### 4.6 Facings
**Four, permanently (D44).** N/E/S/W. On-screen yaw is `facing − perspective`,
cyclic, so four facings across four room perspectives is four distinct yaws, not
sixteen. **No mirroring (D45)** — at four facings it saves one set in four while
inverting every asymmetry, and a mirrored frame would additionally need its
normal map's R channel negated.

### 4.7 Scale — ✅ SETTLED 2026-08-14 (closes §9 #3)

**The Director's spec, which is what finally made this derivable:** standing,
slightly **taller** than a slice, so hunching drops him into full cover behind
the 8 voxels; crouched, ~2/3 of a slice, *"5 or 6 voxels"*; prone, 2–3 voxels of
cover.

If the 1.80 m figure stands at ~9 voxels, one voxel is **0.20 m** and everything
else follows with no second guess:

| | voxels | metres | px (`VOXEL_STEP_PX` = 20) |
|---|---:|---:|---:|
| 1 voxel | 1 | 0.20 | 20 |
| **SLICE** (`LEVELS_PER_STOREY`) | 8 | 1.60 | 160 *(`WALL_FLOOR_STEP_PX` = 158)* |
| standing *(incl. fedora)* | 9.8 | 1.96 | 196 |
| crouched | 5.5 | 1.10 | 110 |
| prone | 2.2 | 0.44 | 44 |

**Verified, not asserted** — `tools/asset_generation/s2_posture_scale.py` poses
the rig and *measures* the evaluated mesh, failing loudly when a posture lands
outside the Director's band. Evidence:
`Screenshots/history/s2_posture_vs_slice.png`, with the wall banded per voxel so
the 8 units are countable in the picture rather than claimed in a caption.

**One consequence, and one CORRECTION to what was first written here.**

1. **The character is TALLER than a slice**, which reverses this section's
   earlier sketch (it assumed ~112 px, i.e. 70% of a storey). That sketch is
   superseded.
2. ~~"A 1.60 m storey is short for architecture — a deliberate
   readability-over-realism trade."~~ **WITHDRAWN 2026-08-14, same day, by the
   Director.** That sentence read a slice as a *storey in the architectural
   sense*, which it never was. **A slice is half a room.**

### 4.7b What a storey actually is — and why the character is deliberately big

*(Director, 2026-08-14: "Os andares não são jogáveis, eles servem para criar a
altura da cena... Por isso o uso da arquitetura de storeys. Não simbolizam
andares reais. Possivelmente um andar teria 2 SLICES (a altura de uma sala onde
cabe uma pessoa de 1,80).")*

**The storey stack is a scene-height device, not a floor plan.** Upper storeys
were never playable space — they compose the scene's vertical extent. So a slice
does not have to be room-sized, and reading it as one produced the false "trade"
above.

| | voxels | metres |
|---|---:|---:|
| slice | 8 | 1.60 |
| **ROOM = 2 slices** | **16** | **3.20** |
| standing figure | 9.8 | 1.96 |
| headroom above him | 6.2 | 1.24 |

A 3.2 m room is ordinary for the MVP's own three settings — corporate HQ,
industrial site, laboratory (`DESIGN_MASTER_PLAN` §14.3). **There is no
realism trade here at all.** Evidence:
`Screenshots/history/s2_room_two_slices.png` (slice boundaries drawn heavier
than voxel bands, so the 2-slice structure is visible rather than asserted).

**Why the character is deliberately large — the Director's argument, recorded
because it inverts the usual instinct:** *"ao fazer os personagens maiores,
estamos granularizando os voxels de graça... fazer um personagem que não usa a
altura seria desperdício."* The vertical space already exists and is already
paid for. A character that spans ~10 voxels instead of ~5 gets twice the
effective vertical resolution **at no cost to the world grid** — the grid does
not change, the character simply uses more of what is there.

**Vertical parallax, up AND down — already designed, and this plan does not own
it.** *(An earlier version of this paragraph called it "new and ownerless". That
was wrong; the Director corrected it the same day and the sources are below.)*

| Direction | Where it lives |
|---|---|
| **Up** | [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §"Vertical Rendering and Parallax" — visual storeys move independently via small per-layer factors; upper levels slower, underground faster; plus future sky/skyline/city as render-only layers |
| **Down** | `DESTRUCTION_MASTER_PLAN` **D18** — cosmetic storeys at −2 and below (lava, water, smoke), never a `Slab`, glimpsed only through a crater "with a small parallax offset selling depth" |
| Foreground | `OCCLUSION_MASTER_PLAN` **O9** — foreground parallax decoration, deferred |
| Lighting | `docs/systems/lighting.md` — "Parallax structure (future) — visual depth without gameplay impact" |

The governing rule is already stated in ARCHITECTURE.md and it is the same one
[[upper-storeys-not-playable]] enforces: parallax separates **visual depth** from
**gameplay depth**, adding no navigation, AI or physics layer. That is exactly
why the character can be made large enough to spend the vertical space without
any of it becoming reachable.

**Cover is physical here and probabilistic in the rules** — the Director's own
XCOM reference: being behind the slice is not immunity. `DESIGN_MASTER_PLAN`
§8.2 gives each cover state a hit/damage multiplier, never a shield. The
silhouette decides what the *player reads*; the dice decide what happens.

`agent.gd`'s `SILHOUETTE_HEIGHT = 61.0` is now measurably wrong by more than 3×,
and ACTOR §7 #17 (`MESH_SCALE` never validated) finally has a referent.

### 4.8 Material and the colour trap
The bake emits a flat **unlit albedo** pass plus a **view-space normal** pass,
exactly as `actor_frame_bake_spike.gd` already does — lighting is applied at
runtime by `flat_normal_relight.gdshader`, never baked in (D17/D21).

**Flagged in advance because it has already happened once:** D31 measured the
pistol's baked albedo at RGB **(47, 46, 45)** — dark *and* fully desaturated, so
no amount of runtime light could produce colour that was never captured. The fix
was grading the source at bake time. **A character will hit the same trap.**
Measure the baked albedo's mean RGB before concluding the lighting is wrong.

---

## 5. Pipeline

```
rigged glTF  ->  pose/animation (rig-driven)  ->  bake rig  ->  frame pairs  ->  runtime
                                                  |              (albedo +      composite
                                                  |               normal)       + relight
                                            SubViewport +
                                          orthographic Camera3D
                                        ELEVATION 30 / AZIMUTH 45
```

**Reuse, do not reinvent.** `actor_frame_bake_spike.gd` is already a copyable
template referencing `CollectibleBakeConfig` (D26), and `GrenadeProp` /
`FloatingCollectible` are working runtime consumers of its output.

**The one constant that must not drift:** `CollectibleBakeConfig`'s
`ELEVATION_DEG` / `AZIMUTH_DEG`. D26 records that if a bake's camera angle
differs from that convention, D17/D23's runtime light-direction maths **breaks
silently** — no error, just wrong lighting.

**What D38 says transfers from the Baking System:** the discipline (B1 exactly
one path; B3 alpha from canon; B6 loud-fail) and `TextureResolver`'s
`user:// → default:// → material-only` ladder, which is the natural carrier for
per-player cosmetic delivery. **The compositor itself does not transfer** — it
emits `TileSetAtlasSource` pages for `set_cell()` and knows nothing of meshes.

**Known pitfalls already paid for elsewhere, listed so they are not re-paid:**
- Any tool computing geometry right after `add_child()` must
  `await get_tree().process_frame` first — `global_transform`/`AABB` on a
  freshly-parented `Node3D` is invalid for one frame. Bit `actor_part0_spike`,
  `showcase_panel` and `actor_frame_bake_spike` in turn.
- CLI-baked PNGs never pass the editor import scan, so `load()` fails on them;
  use the raw `Image.load()` + `ImageTexture.create_from_image()` helper.
- `actor_frame_bake_spike.gd` reloads the source model once per pass per frame
  (ACTOR §7 #20). Never measured as a bottleneck at 120 frames; **a character
  with a full animation set is where it would start to matter.**

---

## 6. Part 0 — the two tests, before anything is authored

Director-approved 2026-08-14. **Deliberately split: only one needs an asset the
project does not have.**

### S1 — Normal maps under mobile texture compression *(runnable today)*
**The question:** D17's entire relight technique reads a normal map per pixel.
Lossy compression corrupts normals in a way that surfaces as **wrong lighting**,
not as visible blur — so it can pass a "looks fine" check and still be broken.

**No new asset needed.** `ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/`
holds **120 colour + 120 normal PNGs** (verified 2026-08-14), baked by the real
rig at the real camera angle.

**Method:** compress the normal pass to each candidate mobile format, relight
both the compressed and uncompressed versions through the real
`flat_normal_relight.gdshader` at an identical `light_dir`, and diff the lit
output — *not* the normal maps themselves, since the question is what the player
sees.

**⚠️ The pixel-diff gate must be EARNED first.** `CLAUDE.md` is explicit, and
this project has been burned: diff **two runs of the same code** before trusting
any number. On 2026-08-09 an identical-code capture differed by 36 733 pixels
until the wait was raised. A "0 pixel" claim from an unproven harness is noise
wearing a number.

### ✅ S1 — RUN 2026-08-14. Result: **ASTC yes, ETC2 no.**

Script: `godot/scripts/tools/s1_normal_compression_spike.gd` (windowed, real
Metal GPU, Apple M1). 4 frames × 3 light directions × 5 compression strategies =
60 measurements. Evidence:
`Screenshots/history/s1_normal_compression_comparison.png` (non-`auto_` name, so
the rotation cannot eat it).

**Both gates passed before any number was read.** Same-config re-render diff:
**0**, every frame, every light direction — the pixel-diff gate is earned. Every
light direction produced a reference luma spread of 200–227, far above the
validity floor, so no row is a D22-style "flat image" false pass.

| Strategy | worst maxΔ | avg meanΔ (÷255) |
|---|---:|---:|
| **ASTC, compressed as colour** | **96** | **4.08 (1.6%)** |
| ETC2, compressed as colour | 164 | 14.07 (5.5%) |
| ETC2 + `SOURCE_NORMAL` + Z-reconstruction | 96 | 20.59 |
| ASTC + `SOURCE_NORMAL` + Z-reconstruction | 92 | 21.24 |
| S3TC + `SOURCE_NORMAL` + Z-reconstruction *(desktop control)* | 127 | 22.38 |

**Verdict: D17 is safe to scale, on ASTC.** No uncompressed budget is needed, and
§8's RAM arithmetic **improves** rather than degrades — ASTC 4×4 is 8 bits/texel
against RGBA8's 32, a 4× saving on exactly the resource D42 names as binding.

**ETC2 is not viable for this technique.** meanΔ 14/255 with ~80% of silhouette
pixels shifted by more than 2, and a worst pixel off by 164. It is visibly
blotchy in the strip, not subtly so. **Product consequence, stated rather than
buried:** ASTC covers iOS A8+ (2014) and every Vulkan-class Android, while ETC2
is the older GLES3 baseline — so this result quietly argues for an ASTC-class
device floor. That is a Director call, not a technical one.

**The finding worth keeping — `SOURCE_NORMAL` is a CONTRACT, not a quality
setting.** The first run used it and measured it as *catastrophically worse*
(meanΔ 91). Cause: it packs the normal into two channels and expects the
consumer shader to rebuild Z, and `flat_normal_relight.gdshader` reads `.rgb`
directly, so it never held up its end. Testing it that way measured a mistake,
not the technique — the run was discarded and redone with a Z-reconstructing
shader variant. Even done correctly it loses: reconstruction caps the outliers
(164 → 96) but **raises pervasive error** (14 → 21), because `sqrt(1−x²−y²)`
forces Z ≥ 0 and our view-space normals include near-silhouette texels that
genuinely curve away. The production shader was **not modified** — the variant
lives inside the spike.

**Outcome:** D17 holds. The remaining unmeasured half of ACTOR §7 #28 — the
resident frame count once animation multiplies the pose count — is untouched by
this and still open.

### S2 — Mockup + animation fluidity *(blocked on an asset)*
**The question (D45):** how many intermediate frames does a turn need before it
reads as fluid — and at what point does a turn-based game start feeling
*sluggish* rather than smooth? This is judged by eye, by the Director. It is a
game-feel question, and no metric substitutes.

**Blocked, and the reason is verified:** the project has **no rigged humanoid**.
`actor_part0_spike.gd`'s synthetic humanoid is unrigged voxel blocks and cannot
turn; every mesh in `imported_models/` is a weapon or a grenade.

**Two ways to unblock — Director's call (§9 #5):**
1. **Generate it.** Blender is fully scriptable headless
   (`blender --background --python`, the `bpy` API): mesh, armature, weights,
   keyframed animation, glTF export. A mockup built to §4's actual spec —
   correct proportion, real sockets, four facings — tests what will ship.
   **Requires installing Blender; verified 2026-08-14 that it is not on this
   machine.**
2. **Source a CC0 rigged humanoid**, same provenance convention as the
   Quaternius weapons (per-pack `ATTRIBUTION.txt`, CC0 only). Faster, but a
   generic body has generic proportions, and fluidity judged on the wrong
   silhouette is a biased test.

**Deliverable either way:** one turn and one walk cycle at three candidate
intermediate-frame counts, played at real game speed, captured for the record.

### 🟡 S2 — UNBLOCKED AND RENDERED 2026-08-14. Awaiting the Director's eye.

Blender 5.2.0 LTS was installed the same day, so option 1 was taken: the mockup
is **generated to §4's spec**, not sourced generic.
`tools/asset_generation/s2_mockup_character.py` — **20 bones, 19 segments, 1.96 m
tall** (1.80 m figure plus fedora), standing on z=0, with all seven §4.3 sockets
exported as bone-parented empties. Output:
`ASSETS/.../imported_models/s2_mockup/` (`.glb` 52 KB, `.blend` 97 KB).

**Why a character was scriptable at all — the art direction made it so.** An
action figure (D35) is rigid segments on visible joints, so every segment binds
100% to exactly one bone: no weight painting, no falloff, no skinning artifacts
to hand-fix. The thing that normally makes a character un-scriptable is absent
*by art direction*. The joint gaps are the style, not a tolerance. This is the
same convergence D35 already records between the action-figure look and the
layering architecture — it turns out to extend to the tooling.

**The turn** (`tools/asset_generation/s2_turn_render.py`): a 90° facing change at
**0, 1, 3 and 7 in-betweens**, eased (a real turn accelerates and settles; a
linear sweep would flatter high frame counts by hiding the arrival beat), with
**head and chest running ahead of the hips** — because `guard_enemy.gd` turns
`vision_angle` at 1.35× `body_angle` and D41 ratifies preserving that read. A
rigid spin would have tested something the game does not do. Rendered at the
game's exact camera convention (elevation 30°, azimuth 45°), as GIFs at two
speeds (200 ms and 350 ms per 90°) so "too few frames" can be told apart from
"too slow", which look alike in a single clip.

**The cost, which is what makes this a real decision and not a polish call.**
Every in-between is a yaw that must exist as a baked frame, and yaw multiplies
the largest term in §8. At 2 archetypes × 3 silhouette classes × 8 poses:

| In-betweens per 90° | Distinct yaws | Body sets |
|---:|---:|---:|
| 0 (snap) | 4 | 192 |
| 1 | 8 | 384 |
| 3 | 16 | 768 |
| 7 | 32 | 1536 |

**⚠️ Declared substitution, not a silent one.** These frames are rendered in
Blender at the game camera — **not** baked through Godot and relit by
`flat_normal_relight.gdshader`. The question here is *motion cadence*, which the
camera angle and frame timing decide, and S1 separately established that the
relight path survives compression. **Nothing here is evidence about the runtime
pipeline** and must not be cited as such.

### Three corrections and one ceiling, 2026-08-14 (second S2 pass)

**1. The frame rate is 60, not 30, and nothing caps it lower.** No `max_fps`,
vsync or physics-tick override exists in `project.godot` or anywhere in
`godot/scripts/`. **60 FPS is the stated target** — `milestones.md` M7.0
("60 FPS on 5-year-old devices"), `docs/systems/movement.md`, and
`lighting_runtime_pipeline.md`'s 16.67 ms budget. The "24 fps" in ACTOR is a
*bake frame count*, and D26 already corrected that exact category error once.

**2. THE DISPLAY CEILING — this is what bounds "more smoothness".** A sprite
frame cannot be shown for less than one rendered frame, so a turn of *D* seconds
at *F* fps can display at most *D×F* distinct frames. Everything past that is
RAM spent on images the player never sees:

| Turn duration | Max displayable frames @60 fps | Max useful in-betweens |
|---|---:|---:|
| 200 ms | 12 | 10 |
| 350 ms | 21 | 19 |
| 500 ms | 30 | 28 |

Conversely: 7 in-betweens need ≥150 ms to show at all, 15 need ≥283 ms, 23 need
≥417 ms. **Since the Director ruled the turn duration need not be fixed, only
coherent and cheap, the two knobs are linked and neither is free alone.**

**3. "We have RAM to spare" was NOT established by S1** — and the correction
matters, because a decision was about to rest on it. S1 measured *compression
fidelity*, not headroom: it showed the relight survives ASTC, which yields a 4×
saving against RGBA8. It never measured a resident set, and ACTOR §7 #28 still
listed that as open. **Now measured** (`s2_resident_memory_probe.gd`, real Godot
compression, not a spec sheet), for the one loadout D42 says must be resident —
guards add ~0, being the same frames under a different tint (D41):

| yaws | in-betweens | frames | 96×128 | 128×160 | 160×192 | 192×256 |
|---:|---:|---:|---:|---:|---:|---:|
| 4 | 0 | 96 | 2.2 MB | 3.8 MB | 5.6 MB | 9.0 MB |
| 8 | 1 | 192 | 4.5 MB | 7.5 MB | 11.2 MB | 18.0 MB |
| 16 | 3 | 384 | 9.0 MB | 15.0 MB | 22.5 MB | 36.0 MB |
| 32 | 7 | 768 | 18.0 MB | 30.0 MB | 45.0 MB | 72.0 MB |
| 48 | 11 | 1152 | 27.0 MB | 45.0 MB | 67.5 MB | 108.0 MB |
| 64 | 15 | 1536 | 36.0 MB | 60.0 MB | 90.0 MB | 144.0 MB |

Frames = 8 poses × 3 (poses plus the transitions between them, D39 — the ×3 is a
flagged placeholder, not a measured multiplier). **The Director's conclusion
turns out to be right and the premise wrong**: at a plausible canvas the whole
resident character set is tens of MB, so the smoothness decision is not
RAM-bound. What is still unmeasured is **device headroom** — what a real phone
has spare beside the voxel tilemap and atlas pages. That needs an on-device run
and must not be inferred from this table.

### Real size — the shotgun in the mockup's hand

*(Director: "queria ver em tamanho real na mão do personagem em cena pra
decidir.")* `tools/asset_generation/s2_weapon_in_hand.py`. Evidence:
`Screenshots/history/s2_real_size_decision_sheet.png`.

**At 1:1 the compression difference is invisible.** The 8× strip that made ETC2
look blotchy was the right view to *find* the artifact and the wrong one to
decide it mattered — at the shotgun's real 66×33 px silhouette all six variants
read the same. **Two limits on that, stated rather than glossed:** a character
sprite is ~126 px tall, roughly 4× the shotgun's height, so this does not
transfer automatically; and a still cannot show shimmer under a moving light.

**Finding for Part 4 — a socket needs a per-weapon GRIP OFFSET, not just a
position.** Placed at the midpoint of the two hand sockets, the shotgun's
geometric centre still lands 0.345 m away, because a GLB's origin is arbitrary
art data — the same class of fact D30 paid for when a copied `PERSPECTIVE_YAW_DEG`
came out 178° wrong. The scale had to be *derived* too (the model is 4.471 units
long; a hand-picked 0.55 made it a 2.5 m shotgun, which the first render showed
plainly).

**Process note worth keeping:** the first fix to that render produced a
**byte-identical image** while the log happily reported the intended scale — a
GLB brings its own root, so filtering for "meshes with no parent" reparented
nothing. Caught by comparing the pictures, not by reading the log.

### The turn's RATE — rendered 2026-08-15, the second half of the question

The first S2 pass answered *how many in-betweens* (Director: *"faz muita
diferença cada um"*, 7+ clearly best). It did not answer **how long the turn
lasts**, and correction 2 above is why that is not a separate question: pick a
frame count and you have picked a minimum duration; pick a duration and you have
capped the useful frame count. `tools/asset_generation/s2_turn_rate_compare.py`
renders both axes side by side.

| Evidence | What it shows | Tracked? |
|---|---|---|
| `Screenshots/history/s2_turn_rate_60hz_vs_30hz.mp4` | the **same 17-frame asset** at 60 Hz (283 ms) and 30 Hz (567 ms), running together | **no** |
| `Screenshots/history/s2_turn_ceiling_60hz.mp4` | 7 / 11 / 15 / 23 in-betweens, all at the ceiling → 150 / 217 / 283 / 417 ms | **no** |
| `Screenshots/history/s2_turn_rate_contact_sheet.png` | the 17 frames as a strip, with both rulers — the durable record | yes |

**Neither MP4 is committed, and that is the repo's rule, not an oversight.**
`.gitignore:27` bans `*.mp4` globally (beside `*.mov`); force-adding would have
been a silent workaround of a deliberate policy. They exist locally and were
delivered to the Director for the judgement. **The chain is fully reproducible
from tracked sources**, which is what makes not committing them safe:

    s2_mockup_character.glb  (tracked)
      -> s2_turn_render.py       -> Screenshots/s2_turn/turn_N_inbetween/
      -> s2_turn_rate_compare.py -> the two MP4s + the contact sheet

If the videos should be versioned, that is a `.gitignore` change and therefore a
Director call. The PNG carries the numbers either way.

**"30 Hz" here is an AUTHORING choice, not a slow device**, and mislabelling it
would make the Director judge the wrong thing. Correction 1 above establishes the
animation is time-driven (`floating_collectible.gd:331`), so a phone delivering
30 fps keeps the duration and *drops* frames. The 30 Hz panel instead holds each
sprite frame for two rendered frames: same asset, same RAM, twice the wall clock.

**Both clips are MP4 at a true 60 fps, and the format is a fidelity decision
rather than a preference.** GIF stores its delay in centiseconds, so 16.67 ms
rounds to 2 cs = 20 ms — a "60 Hz" GIF actually plays at 50 Hz, a 17% error on
the exact quantity under judgement, and many viewers additionally clamp sub-2 cs
delays to 10 cs. Holding each source frame an *integer* number of output frames
at a fixed 60 fps is exact by construction. The earlier GIFs remain valid for the
frame-count question they were made for; they were never valid for this one.

**Nothing was re-rendered** — the frame sequences from the first pass were reused
in place, and the head-lead authoring stays in `s2_turn_render.py` rather than
being copied, because two copies of *"how the turn is authored"* drift the first
time one is tuned.

**One correction, made before the numbers were reported.** The first run labelled
the 15-in-between turn "283 ms" in the panel title while the live readout beside
it computed **267 ms** — two numbers for one quantity in one image. Cause: the
title used §6's frame-count convention (17 images × 16.67 ms) and the readout
measured the *gaps* between them (16 × 16.67). §6's convention is the correct
one: every image must occupy at least one rendered frame to be seen, so the turn
costs 17 frame slots, not 16. Fixed by **deriving every label from the same
numbers instead of passing them in** — the numbers now match §6's table exactly
(150 / 217 / 283 / 417).

### 🔴 The result that invalidated the method — Director, 2026-08-15

*"Em todos os exemplos até agora a última opção sempre foi a melhor. O tempo de
30 Hz ficou melhor e o exemplo com 23 in-betweens também fica mais natural."*

**The Director's own observation is the finding, and it does not confirm the
conclusion — it withdraws it.** Taken at face value the answer is 23 in-betweens
at 30 Hz: a **833 ms** turn, **96 yaws**, **4608 body sets** — the most expensive
corner of §8's whole budget. It should not be committed to, for three reasons,
none of which is a matter of taste.

**1. The range was never bracketed.** If the last option always wins, the
preference is monotonic across everything tested, which means the test never
contained its own answer. D45's premise is that a turn-based game has a ceiling
where smooth turns *sluggish*; a set of options that never renders a sluggish one
cannot locate that ceiling. Every S2 sheet so far topped out at the option the
Director then chose.

**2. Position and label bias were uncontrolled.** Every sheet ordered panels by
increasing frame count, left to right, with the count printed on each. So *"the
last one"* and *"the most frames"* were the **same panel every time** — the two
explanations are not separable in anything collected so far.

**3. The turn has no foot replant, and that may be the whole result.**
`s2_turn_render.py:131` rotates the armature **object** plus the `head` and
`chest` bones; the `thigh`/`shin`/`foot` bones the rig does have are never posed.
The turn is a rigid pivot with the feet glued, sliding on the floor — visible in
`s2_turn_frames_7inbetween.png`. **A slide contains no discrete beat**, so more
in-betweens can only ever smooth it further, which is exactly the monotonic
result observed. The frame count at which smoothness turns floaty is a property
of a turn that has an *event* in it. Duration bracketing and footwork are two
separate experiments; only the first is run below.

### The blind bracket — `tools/asset_generation/s2_turn_bracket_blind.py`

Answers 1 and 2 together. Every panel at **30 Hz** (the chosen rate), so only the
in-between count varies, deliberately extended past where it should break:

| Blind label | in-betweens | frames | turn |
|---|---:|---:|---:|
| D | 15 | 17 | 567 ms |
| B | 23 | 25 | 833 ms |
| A | 31 | 33 | 1100 ms |
| C | 47 | 49 | **1633 ms** |

Labels are **blind** (no counts, no milliseconds, no progress bar — a bar filling
at different rates side by side is a duration readout in disguise) and the order
is **randomised under a fixed seed**, constrained so the slowest is *not* last.
That constraint is what makes the outcome diagnostic rather than merely another
data point:

- picks **D** (last panel, *fastest*) → the pattern was **position bias**
- picks **C** (slowest, third) → genuine, and the range is *still* not bracketed
- picks **A** or **B** → the ceiling is real and has been located

Evidence: `Screenshots/history/s2_turn_bracket_blind.mp4` (not tracked, per
`.gitignore:27`), key in `s2_turn_bracket_blind_KEY.json` (tracked).

### ✅ THE TURN — SETTLED 2026-08-15 by blind judgement. Closes §9 #7 and D45.

**23 in-betweens, 30 Hz, an 833 ms turn.** Director's blind verdict, verbatim:
*"B é a ideal, D está muito rápido. C está devagar, A está quase bom."*

| Blind | in-betweens | turn | Verdict |
|---|---:|---:|---|
| D | 15 | 567 ms | too fast |
| **B** | **23** | **833 ms** | ✅ **ideal** |
| A | 31 | 1100 ms | almost good |
| C | 47 | 1633 ms | too slow |

**Both method objections are answered by the shape of that result, not by
argument.** The chosen panel was **second from the left**, the *last* panel was
rejected as too fast, and the panel with the **most frames** was rejected as too
slow — so neither position bias nor "more is always better" survives. The
preference is **single-peaked**, which is what a real optimum looks like and what
neither failure mode produces. The blind test **confirms** the sighted answer
rather than overturning it; the difference is that it is now a measurement.

**Objection 3 is substantially WEAKENED, and this is a withdrawal, not a
hedge.** The foot-slide argument predicted a *monotonic* preference — smoothing
an artifact has no interior optimum. The result is single-peaked, so the slide is
not what was being judged. It stays worth testing only in its weaker form: a turn
with a real replant has an event in it and could **move** the peak. It is no
longer a reason to doubt this number.

Evidence: `Screenshots/history/s2_turn_bracket_blind.mp4` (untracked per
`.gitignore:27`; regenerable — see the chain above) and the tracked answer key
`s2_turn_bracket_blind_KEY.json`.

### Where the 833 ms turn applies — Director, 2026-08-15

*"Vamos ter o giro para os casos em que o agente muda de alvo. Quando ele
estiver selecionando em qual inimigo acertar, o personagem gira. Em outras
situações corriqueiras ele vai simplesmente se mover da GU A para a GU B, entrar
e sair do cover."*

**The 833 ms turn is a DELIBERATE turn — target selection in aim mode**, where
the turn *is* the feedback for the player's input, which is why it can afford to
be weighty. Ordinary movement is a different animation with a different job, and
the Director's follow-up question is which mechanism it uses: *"fica a dúvida se
precisa ter uma transição e depois começar o movimento, ou se o giro já acontece
com inércia pra frente, em movimentos únicos."*

### 🔴 A finding that came out of asking it: the step is a sprint

`VOXELS_PER_UNIT_AXIS` is 8 and one voxel is 0.20 m (§4.7), so **one GU is
1.60 m** — the standard tactical square, and reasonable. But `agent.gd:71` has
`STEP_DURATION := 0.13`, which over 1.60 m is **12.3 m/s — faster than the 100 m
world record.**

That constant is not a bug; it is a *"snappy tactical feel"* tuned for the
44×61 px vector diamond that has no legs to contradict it. It cannot carry a walk
cycle. And it is **upstream of the corner question**: whether a rotation "fits
inside the step" is entirely a question of how long the step is, and at 130 ms
nothing fits inside anything.

Second measurement, same area: `agent.gd::_step_next()` builds a fresh
`EASE_IN_OUT` tween **per tile**, so a five-GU path today is five separate
accelerate-decelerate cycles. With a diamond that reads fine; with legs it reads
as hopping, and it is the direct obstacle to the Director's *"movimentos únicos"*.

Evidence: `Screenshots/history/s2_step_duration.mp4` — one GU at 130 / 500 /
900 ms (12.3 / 3.2 / 1.8 m/s), labelled rather than blind because it is a
measurement, not a matter of taste.

### The corner — four mechanisms, blind

`tools/asset_generation/s2_corner_render.py` + `s2_corner_compare.py`. One
L-shaped path (GU A → B → C, a single 90° corner), one 500 ms step, and the only
difference is **when** the facing changes. Two options are the Director's, two
are added because offering only the two named would have pre-narrowed the choice:

| Mechanism | What it does | Added cost per direction change |
|---|---|---:|
| TURN_THEN_MOVE | stop at the corner, turn in place, then step | **+833 ms** |
| INERTIAL | rotation spread across the outgoing step — one motion | +0 ms |
| ANTICIPATED | rotation runs in the *tail of the incoming* step; arrives already facing | +0 ms |
| SNAP | no turn frames at all; facing flips at the GU boundary | +0 ms |

Blind and randomised, seeded so the option with the *most* animation is not last
— per the lesson the turn test paid for. Evidence:
`Screenshots/history/s2_corner_blind.mp4`, key in `s2_corner_blind_KEY.json`
(tracked).

**SNAP is the one that decides §9 #10.** If the facing can simply flip at a GU
boundary while the eye is tracking translation, movement needs **no transition
yaws at all** and only aim mode pays for the other 92 — which is the 744-body-set
row, not 4608.

### 🟡 Corner result — PROVISIONAL, 2026-08-15

Director: *"A ficou péssima, sem chance. A D me parece que é a melhor, mas ele dá
mais passos do que tem chão embaixo."* Key: A = TURN_THEN_MOVE, D = **SNAP**.

- **TURN_THEN_MOVE is rejected outright.** The deliberate 833 ms turn does not
  belong in ordinary movement — consistent with the Director's own split between
  target selection and getting from GU to GU.
- **SNAP leads**, which if it holds collapses §9 #10 to its **744-body-set** row:
  movement needs no transition yaws and only aim mode pays for the other 92.

**Held PROVISIONAL, on the Director's own condition** — the stride was wrong, and
they counted it. `s2_corner_render.py`'s `STRIDE_M` is distance per *full cycle*
(two footfalls), so 0.80 m gave **four footfalls per 1.60 m GU**; a 1.96 m figure
takes about two. Exactly 2× too many, which is why the feet outran the floor. The
mechanism ranking is unlikely to move — footfall count is not what distinguishes
the four — but a provisional result on a stated defect is not a settled one.

### ⚠️ What 23 in-betweens costs, and the one question that decides it

Naively this is the most expensive corner of §8: **96 distinct yaws → 4608 body
sets** at `archetype(2) × silhouette(3) × pose(8) × yaw`. RAM is not the problem
(D42: axes are mutually exclusive at runtime, and §6's probe measured one
resident loadout at tens of MB); **bake time and disk are.**

But that arithmetic assumes **every pose turns**, and it is an assumption nobody
has ratified. Intermediate yaws exist *only during a turn* — they are a
**transition** asset. The four cardinal facings are needed by all eight poses;
the 92 extra yaws are needed only by poses the agent can actually pivot in.

| Poses that can turn | yaw-terms per archetype×silhouette | body sets |
|---|---:|---:|
| all 8 *(today's assumption)* | 8 × 96 = 768 | **4608** |
| 3 (idle, crouch, weapon-ready) | 8×4 + 3×92 = 308 | **1848** |
| 1 (stand up to turn) | 8×4 + 92 = 124 | **744** |

**A 6× spread on the largest term in the budget, decided by one design question:
which postures can change facing in place?** That is a gameplay ruling
(`DESIGN_MASTER_PLAN` §8 cover states are the natural place for it), not a
technical one, and it belongs to the Director. Recorded here as **§9 #10**, open.
Part 2 does not need it — Part 2 bakes idle only, at the four cardinal facings —
so this does not block the next Part.

---

## 7. Parts

**Reordered 2026-08-15 by D48.** The professional showcase model was Part 8 and
is now the immediate next work, because the gameplay figure takes its design from
it — building Part 2 first would mean authoring it twice.

```
Part 0  Tests                     ✅ CLOSED — S1 + S2 both answered
Part 1  Base model + rig          ✅ BUILT — skeleton/sockets/scale survive D48;
                                     the ART is superseded by Part 8
Part 8  PROFESSIONAL SHOWCASE     🔜 NEXT (D48). Start scene BUILT 2026-08-15:
                                     `p8_sculpt_start_scene.py` ->
                                     `agent_sculpt_start.blend`.
                                     Live 3D for the menu, no bake.
        MODEL                        Design authority for everything below it.
                                     D49: a DEDICATED COLLABORATIVE stage —
                                     import open-source material, sculpt the
                                     agent AND the clothing (D33: armour is a
                                     dressed body, never a garment over a nude
                                     base, so there is no nude base to sculpt)
Part 2  MINIMUM VIABLE AGENT      idle + 3 grips x 4 yaws, baked, on screen,
                                     replacing the vector placeholder
                                     ⚠️ unblocks aim mode + W-PRECOOK
Part 3  Movement + transitions    walk GU->GU, the D46 turn, posture changes,
                                     hood in/out — D39's real deliverable
Part 4  Layer system              weapon by grip · cape synced · rigid adornments
                                     -> first real consumer of PropDef.layers (D7)
Part 5  Silhouette classes        3-4 dressed bodies from §10.1's 7 tiers
Part 6  Second archetype          mesh retarget onto Part 1's skeleton, never a new rig
Part 7  Guards                    tint/uniform variant + authored head turn (D41)
Part 9  Damage integration        ACTOR Part 3 / D5/D6 — the single-writer boundary
```

**Part 2 is still the milestone that matters to everything outside this plan** —
one pose, three grips, four yaws, baked and composited; firearm aim mode and
W-PRECOOK both start moving the day it lands. **D48's stated price is that it now
waits on Part 8.** That is the correct trade if the gameplay figure derives its
design from the showcase model, and it is a real cost rather than a free
reshuffle.

### What Part 1 delivered, and what of it survives D48

`tools/asset_generation/p1_agent_model.py` — 20 bones, 36 rigid parts, 2432
faces, 1.898 m, 1.760 m span. Evidence:
`Screenshots/history/p1_agent_tpose_sheet.png` (four orthographic views, the game
camera, and the figure at its true 196 px ship size beside a 3× blow-up).

| Survives as the base | Superseded by Part 8 |
|---|---|
| the 20-bone skeleton and its **exact names** (D32: one skeleton, retarget the mesh) | every mesh part |
| the seven §4.3 sockets | the suit/hat/shoe forms |
| the **verified exact T-pose rest** — measured off the armature, loud-fail | the palette |
| §4.7's measured scale, deliberately untouched so `s2_posture_scale.py`'s verification still holds | |

**Two bugs found by measuring rather than by looking**, recorded because both are
recurring classes:
1. `prism()` oriented cross sections with `axis.to_track_quat("Z", "Y")`, whose
   **roll is undefined for a near-vertical segment**. Pure-Z parts landed one way
   and the slightly tilted shirt panel landed another, turning its 85 mm *width*
   into 85 mm of *depth* — a blade through the chest. Same class as D30's copied
   `PERSPECTIVE_YAW_DEG` that came out 178° wrong: **derive the frame, never
   inherit one from a convenience function whose convention you have not
   checked.** Diagnosed wrong twice by eye before the bounding boxes were
   measured.
2. The first fedora had a 52 cm brim — a sombrero. Caught only because the model
   was rendered rather than described.

---

## 8. The budget contract

D34 as a working table. **Only the first block multiplies.**

| Term | Shape | Notes |
|---|---|---|
| body | `archetype(2) × silhouette(S) × pose(P) × yaw(4)` | the only multiplicative term |
| weapon | `weapon(W) × grip(≈3) × yaw(4)` | **grip, not pose** (D40) — idle/walk/turn share one |
| cape | `1 motion × animation frames × yaw(4)` | largest additive term; **variants are tint, not new motions** (D43) |
| rigid adornments | `item × pose × yaw(4)` | composited over a socket |
| colour / palette | **free** | shader uniform; the pattern already exists (`saturation`/`contrast` D31, `outline_width` D28) |

Order of magnitude at P=8, yaw=4: `S=7 → 448` body sets; `S=3 → 192`.
**Neither is measured. Neither is a budget until it is** (Part 0 discipline).

**What actually constrains (D42):** RAM, not CPU. Actors resolve serially per
TIC, so no frame ever animates twenty characters. And the multiplicative axes are
**mutually exclusive at runtime** — the player wears one archetype in one
silhouette class, so RAM holds *one loadout plus the guards on screen*, while the
catalog is a disk cost. Segment population (§14.1) helps too, but it is the
secondary factor.

**Still unknown:** the resident frame count once animation multiplies the pose
count. That is the number Part 0 exists to start pinning down.

---

## 9. Open questions

1. **Bone set** — §4.2's ~20-bone list is proposed, not ratified, and is now
   BUILT as 20 in Part 1. Prone and full-cover crouch are the poses most likely
   to demand more.
2. **How many silhouette classes** — D33 recommends 3–4 against seven armour
   tiers. The single number that most moves §8.
3. ~~**Character height**~~ **RESOLVED 2026-08-14 — see §4.7.** One voxel is
   0.20 m; standing 9.8 / crouched 5.5 / prone 2.2 voxels, measured and gated,
   not asserted.
4. **The free fallback for a purchasable state indicator** (D36) — either every
   cosmetic expresses hood/stealth mode, or a non-cosmetic cue is redundant with
   it. Must be settled **before the first cosmetic is authored**.
5. **How S2 gets its mockup** — generate via headless Blender (needs an install)
   or source a CC0 rigged humanoid (faster, biased silhouette). §6 S2.
6. **Where hood/stealth mode lives mechanically** (D37) — a fourth axis beside
   `agent.gd`'s three postures, or a modifier on `exposure_system.gd`'s five
   shipped exposure classes. Both are built systems; this is a gameplay
   question, and it belongs to GAMEPLAY-01 more than to this plan.
7. ~~**Turn frame count**~~ **RESOLVED 2026-08-15 — see §6.** 23 in-betweens at
   30 Hz, an 833 ms turn, settled by blind randomised judgement with the range
   bracketed on both sides. Not asserted, and not read off a biased instrument.
8. **Whether the character's albedo needs bake-time grading** like the weapons
   did (§4.8). Unknowable until the first real bake is measured.
9. ~~**Vertical parallax (up and down)** — owned by no document.~~ **WRONG,
   withdrawn 2026-08-14.** It is documented in four places; see §4.7b's table.
   Not this plan's to own, and not an open question.
10. ~~**Which postures can change facing in place**~~ **RESOLVED 2026-08-15 by
    D46 + D47.** Movement snaps at the GU boundary and needs no transition yaws;
    only aim mode's deliberate turn pays for the other 92. **744 body sets, not
    4608** — the 6× saving landed on the cheap side.
11. ~~**How the professional showcase model gets AUTHORED**~~ **RESOLVED
    2026-08-15 by D49** — a dedicated, collaborative stage: open-source material
    imported, then the agent *and the clothing* sculpted. Part 8 is unblocked.
    Two things it opens, both listed below as #13 and #14.
13. **Where a SCULPTED source file lives.** NEW 2026-08-15, and it needs an
    answer *before* the first sculpt rather than after. Every character artifact
    so far has been a headless Python generator, so the versioned artifact was
    the recipe and `ASSETS/*` could stay gitignored with nothing lost. A sculpt
    is not reproducible from a script: the `.blend` **is** the source. Either
    `.gitignore` gains a deliberate exception, or the model lives outside the
    repo under a stated backup convention. Losing it means re-sculpting it.
14. **Licence provenance for imported open-source material.** ⚠️ Answer this at
    the moment of the first import, not after. The convention
    exists and applies unchanged — per-pack `ATTRIBUTION.txt`, CC0 only, as used
    for the Quaternius weapon packs. Recorded here because provenance is captured
    **at import time** and cannot be reconstructed afterwards from a mesh.

### The start scene — BUILT 2026-08-15

`tools/asset_generation/p8_sculpt_start_scene.py` →
`ASSETS/.../imported_models/agent/agent_sculpt_start.blend`. Evidence:
`Screenshots/history/p8_sculpt_start_scene.png`.

Its purpose is that **every ratified constraint is present as geometry rather
than as something to remember from this document**:

| Collection | Carries |
|---|---|
| `RIG` | the verified 20-bone T-pose armature + the seven §4.3 sockets, **generated by `p1_agent_model.py`, not copied** — D48 says the skeleton survives, so the sculpt must fit it |
| `BLOCKING` | Part 1's body, `hide_select` — a shape to work against and overwrite, never to sculpt by accident |
| `SCALE` | a 0.20 m voxel ruler to 3.20 m, the SLICE and ROOM lines, the 1.60 m GU floor footprint, and the standing / crouched / prone marks |
| `CAMERAS` | `CAM_GAME` at elevation 30 / azimuth 45 (D26 — a different angle breaks the runtime light maths silently) plus front / side / back orthos |

**The render preset is 133×196 from `CAM_GAME` on purpose** — F12 is a one-key
reality check at the size the player actually sees. S1 paid for that lesson on
2026-08-14: six compression variants were obvious at 8× and indistinguishable at
real size.

**⚠️ One discrepancy the scene draws rather than hides.** §4.7 records standing
incl. fedora at **9.8 voxels / 1.96 m**, but that was measured off the *S2
mockup*, whose hat perched above the skull. Part 1's fedora sits **on** the head
and the figure measures **1.898 m**. The load-bearing numbers are untouched and
exact — 1 voxel = 0.20 m, and the **body is 1.80 m = 9.0 voxels**. The 9.8 was a
hat, not a constraint. Both lines are drawn and labelled in their own colours so
the sculpt settles the hat's height deliberately instead of inheriting it.

**Known limitation, stated:** the ruler's labels are flat text facing +Y, so they
read correctly from `CAM_FRONT` and mirrored from `CAM_GAME`. Fine in an
interactive session where the viewport orbits freely; noted so it is not
mistaken for a bug.
12. **`agent.gd`'s `STEP_DURATION` is 12.3 m/s** — measured 2026-08-15. One GU is
    1.60 m (`VOXELS_PER_UNIT_AXIS` 8 × 0.20 m) and the constant is 0.13 s, which
    is faster than the 100 m world record. Not a bug: it is a *"snappy tactical
    feel"* tuned for a 44×61 px vector diamond with no legs to contradict it. It
    becomes a real problem the moment Part 2 puts a walk cycle on screen.
    Related, same file: `_step_next()` builds a fresh `EASE_IN_OUT` tween **per
    tile**, so a five-GU path is five accelerate-decelerate cycles rather than
    one walk. Both belong to Part 3; neither blocks Part 8. Evidence:
    `Screenshots/history/s2_step_duration.mp4`.

---

## 10. Verification

Every Part closes under `CLAUDE.md`'s standing protocol — `project_lint.py`,
zero new warnings, `run_selftests.py` as the arbiter, `check_invariants.py`,
`gen_codemap.py --check`. Beyond that, three rules this plan inherits because it
is a **visual** system:

1. **A visual claim needs a real capture.** Never a written description standing
   in for one. A cited capture that must survive should get a non-`auto_` name —
   the rotation keeps only the 50 most recent `auto_` files, and 16 of 23 cited
   captures were already gone when this was measured on 2026-08-03.
2. **A green selftest does not mean the feature fires on the real map.**
   Synthetic fixtures are built with the data that works. Run the real path and
   read the real numbers.
3. **A pixel-diff gate must be earned before it means anything** — §6 S1 carries
   the full statement.

**Definition of done for Part 2**, the only Part with external dependents: the
vector placeholder in `agent.gd::_draw()` is gone, the agent renders as a baked
sprite holding a real weapon at all four facings under real room lighting, and a
capture shows it. Not "the pipeline works" — the placeholder is gone.
