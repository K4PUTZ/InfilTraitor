# CHARACTER_MASTER_PLAN
## The Agent — Model, Rig, Poses, Animation, Layering — v1.0

**Status:** 🔵 **NEW 2026-08-14. Nothing built.** This is the execution plan for
the living-beings track `ACTOR_MASTER_PLAN` reopened on 2026-08-13 and decided
on 2026-08-14 (D32–D45). It replaces that plan's deferred Parts 1, 3 and 4,
which were stubs, not designs.

**Baseline:** VERSION 0.9.101, `main` at `2a8d7e1d`. No `verified/` tag since
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

### 4.7 Scale — derive it, do not guess it
This project forbids empirical pixel offsets on voxel-layer positions
(`CLAUDE.md`: positions are analytically derived). The character's height gets
the same treatment. The real constants:

```
VOXEL_STEP_PX        = 20.0     # vertical px per voxel level
LEVELS_PER_STOREY    = 8        # -> a storey is 8 * 20 = 160 px
WALL_FLOOR_STEP_PX   = 158.0    # measured storey step (the ~2 px is the seam)
```

**The current placeholder is not evidence of anything.** `agent.gd`'s
`SILHOUETTE_HEIGHT = 61.0` is 61/158 ≈ **39% of a storey** — if a storey reads
as ~2.6 m, that placeholder is a person about one metre tall. It was hand-
calibrated for a vector box, never derived.

So: pick the real-world storey height, state it, and derive the character height
from it. For orientation only — a person at ~70% of a storey lands near **5.6
voxel levels ≈ 112 px**, roughly double today's placeholder. **Not a decision;
the arithmetic is shown so the decision is made against real numbers** (§9 #3).
This also finally gives ACTOR §7 #17 (`MESH_SCALE` never validated) something to
be validated against.

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

**Outcome:** either D17 is safe at scale, or the character's normal maps need an
uncompressed budget — which changes §8's RAM arithmetic materially.

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

---

## 7. Parts

```
Part 0  Tests                     S1 runnable now · S2 blocked on an asset
Part 1  Base model + rig          -> needs S2's answer only for frame counts,
                                     not for the model itself
Part 2  MINIMUM VIABLE AGENT      idle + 3 grips x 4 yaws, baked, on screen,
                                     replacing the vector placeholder
                                     ⚠️ THIS is what unblocks aim mode + W-PRECOOK
Part 3  Movement + transitions    walk GU->GU, turn, posture changes,
                                     hood in/out — D39's real deliverable
Part 4  Layer system              weapon by grip · cape synced · rigid adornments
                                     -> first real consumer of PropDef.layers (D7)
Part 5  Silhouette classes        3-4 dressed bodies from §10.1's 7 tiers
Part 6  Second archetype          mesh retarget onto Part 1's skeleton, never a new rig
Part 7  Guards                    tint/uniform variant + authored head turn (D41)
Part 8  Big display model         Showcase / forum avatar (D33/D35) — live 3D, no bake
Part 9  Damage integration        ACTOR Part 3 / D5/D6 — the single-writer boundary
```

**Part 2 is the milestone that matters to everything outside this plan.** It is
deliberately scoped smaller than "the character is done": one pose, three grips,
four yaws, baked and composited. Two blocked workstreams start moving the day it
lands.

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

1. **Bone set** — §4.2's ~20-bone list is proposed, not ratified. Prone and
   full-cover crouch are the poses most likely to demand more.
2. **How many silhouette classes** — D33 recommends 3–4 against seven armour
   tiers. The single number that most moves §8.
3. **Character height** — §4.7 shows the arithmetic and the placeholder's
   distortion; the real-world storey height has never been stated, so the
   derivation cannot be completed. Also finally gives ACTOR §7 #17 a referent.
4. **The free fallback for a purchasable state indicator** (D36) — either every
   cosmetic expresses hood/stealth mode, or a non-cosmetic cue is redundant with
   it. Must be settled **before the first cosmetic is authored**.
5. **How S2 gets its mockup** — generate via headless Blender (needs an install)
   or source a CC0 rigged humanoid (faster, biased silhouette). §6 S2.
6. **Where hood/stealth mode lives mechanically** (D37) — a fourth axis beside
   `agent.gd`'s three postures, or a modifier on `exposure_system.gd`'s five
   shipped exposure classes. Both are built systems; this is a gameplay
   question, and it belongs to GAMEPLAY-01 more than to this plan.
7. **Turn frame count** — D45 makes it a test, not a decision. S2 answers it.
8. **Whether the character's albedo needs bake-time grading** like the weapons
   did (§4.8). Unknowable until the first real bake is measured.

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
