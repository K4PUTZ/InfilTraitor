# WEAPON_MASTER_PLAN
## The Arsenal — What Weapons Exist, and What Each Does to the Scenario — v1.0

**Status:** 🟢 **Catalog drafted AND the first shot fired, both 2026-07-29.**
Parts 0–3 are done: the bench exists, `WeaponDef`/`WeaponRegistry` are real,
`CONE` is implemented and selftested, and right-clicking a bench shotgun opens
"Atirar" and chews a real wedge out of a real wall. `LINE` (pistols/rifles) and
Part 4 (the non-destructive tier) remain open, and D1/D2/D7 are now **shipped
rather than proposed** — they were ratified by being built and captured. What
follows below was written before any of it existed; the original wording is
kept, per this project's no-silent-rewrite policy. This document
exists because `docs/production/roadmap.md` and `docs/production/milestones.md`
have both carried the same entry since 2026-07-26 — *"Ranged weapon (shotgun) +
shot-based wall destruction | New mechanism, no plan yet | Not started, not
scoped"* — and the Director asked for the catalog before the mechanism: *"pra
isso precisamos definir que tipos de armas vamos usar pra fechar o modelo de
destruição. Vamos fazer um plano para catalogar essas armas que podem afetar de
alguma maneira o cenário."* Part 0 (the test-zone bench) is **DONE**; every
other Part is open. Nothing here fires a shot yet.
**Baseline:** VERSION 0.9.84, commit `e98ad25`.
**Companions:** `DESTRUCTION_MASTER_PLAN.md` (owns how any shape becomes broken
voxels — `BlastCalculator` is the sole writer of `Voxel.set_damage()`, see §3),
`ACTOR_MASTER_PLAN.md` (owns how a weapon is *displayed* — bake pipeline, D12's
imported-mesh path, D26's `CollectibleBakeConfig`), `docs/systems/AI_MASTER_PLAN.md`
+ `docs/systems/noise.md` + `docs/systems/perception.md` + `docs/systems/occlusion.md`
(own every non-destructive effect, see §3), `docs/DIRECTION_GLOSSARY.md`
(the compass vocabulary any aimed weapon must use).
**Authored by:** solo-mode agent, transcribing a Director brainstorm
(2026-07-29). Rows marked ✅ are things the Director said in that conversation;
rows marked 🟠 are the agent's proposals and are **not ratified** — they are
written down so they can be argued with, not so they can be assumed.

**Explicitly out of scope for v1, Director's own sequencing:** *"posteriormente
iremos trabalhar mais detalhadamente em raridades, e stats como dano, firerate,
accuracy, etc."* Rarity tiers, per-weapon stat tables, ammo, AP cost and
progression/unlocks are all deferred. v1 answers one question only: **which
weapons exist, and what shape of effect does each one put into the world.**

---

## 1. Why — the pains this serves

The engine has exactly one weapon and one destruction shape, and they are welded
together. `BlastCalculator.flood_gu_rings()` is a wall-aware BFS outward from an
epicentre; `BombDef.ring_multipliers` is its falloff; `TestZoneController`
hardcodes `BOMB_ID = "frag_grenade"`. That was correct for a grenade and it is
the *only* thing the codebase knows how to do.

Named pains:

- **A shotgun cannot be expressed at all.** There is no origin-plus-direction
  concept anywhere in the destruction path — the only input is a source GU.
  Adding one weapon this way means adding one bespoke code path per weapon, and
  the Director's own list already names three firearm families, five explosives
  and a stealth tier.
- **Nothing tells the destruction system how hard a given weapon hits.**
  `MaterialResistanceTable` knows concrete resists more than wood; nothing knows
  that a rifle round punches deeper than a pistol round through the same
  concrete. Calibre has no home.
- **The non-destructive half has been designed for months and implemented
  nowhere.** Smoke, EMP and flashbang are already referenced as real mechanics
  in `docs/systems/noise.md` (EMP sits in the noise-intensity table at 0.90),
  `perception.md`, `movement.md`'s AP-cost table, `stealth.md` and
  `occlusion.md` ("perfect for 'smoke grenade' stealth mechanics"). Four systems
  are holding a slot for weapons that no catalog defines.
- **The only prior weapon list is in a deprecated document.**
  `docs/history/design-concepts/infiltraitor_master_design.md` (⚠️ DEPRECATED,
  June 2026) contains the richest weapon/gadget brainstorm in the repo —
  §10.3's tier table (pistola silenciada, arma de choque, rifle silenciado,
  lançador de dardos, laser, plasma, sônica, each with Dano/Barulho/Alcance) and
  §10.5's gadgets (fumaça, flashbang, gás, EMP, incendiária, explosiva, drone).
  It is unreferenced by anything current. This plan supersedes it as the live
  catalog; that document stays where it is, as history.

---

## 2. Decision Register

| D | Decision | Status |
|---|---|---|
| **D1** | **Every weapon that touches the scenario declares a DELIVERY SHAPE plus a STEP FALLOFF TABLE — one model, four shapes, not one code path per weapon.** `BombDef.ring_multipliers` already *is* a per-step falloff table; the only thing that varies between a grenade, a shotgun and a rifle is what "one step outward" means. Generalising the field to `step_multipliers` makes one schema serve all three destructive families and lets `bombs/frag_grenade.json` migrate nearly unchanged. The four families: **`RADIAL`** (steps = wall-aware BFS rings from an epicentre GU — grenade, C4, incendiary; the only one that exists today, `BlastCalculator.flood_gu_rings()`); **`CONE`** (steps = distance bands from a muzzle GU along a facing, widening as they go — shotguns); **`LINE`** (steps = penetration depth along a ray from a muzzle GU — pistols, rifles); **`NONE`** (no voxel damage at all — every stealth and utility item). | 🟠 Proposed |
| **D2** | **The Director's named stats map onto D1's model — they are not new axes.** *"cones de destruição baseado nos calibres dos projéteis, distância, etc."* → **calibre / punch** = penetration depth in voxels, plus a per-weapon multiplier over `MaterialResistanceTable.destroy_factor` (so a heavier round beats concrete where a lighter one only cracks it); **accuracy** = the cone's half-angle, tighter meaning more accurate — which is exactly the Director's *"shotgun com mais dano ou mais precisão, que vai criar um cone mais ou menos largo"*; **damage** = how many voxels a step converts; **distance** = the step falloff itself, so range is not a separate cutoff but the point where the multiplier reaches zero. Nothing here needs a concept the destruction system does not already have. | 🟠 Proposed |
| **D3** | **A static weapon prop needs a 4-frame bake, not the collectible's 120.** A prop that never spins only ever shows four yaws — one per room perspective — which is exactly the shape `grenade_frame_bake_spike.gd` already produces. Measured on disk: the shotgun's 120-frame collectible bake is **4.7 MB / 480 PNGs**, the grenade's 4-direction static bake is **84 KB / 8 PNGs** — a **56× difference per weapon**. Since *"vamos precisar adicionar mais modelos de arma"*, this is the decision that keeps the arsenal cheap to grow. Not exercised yet: the shotgun already had 120 frames, so the bench freeze-frames those for free (D4). | ✅ Ratified (measured 2026-07-29) |
| **D4** | **A pointed weapon is the existing flipbook frozen on one frame — no new class, no new bake.** `actor_frame_bake_spike.gd` renders a full 360° turn, so every facing is already on disk; `FloatingCollectible`'s static mode picks the frame whose muzzle runs along the requested compass edge and stops the spin and the bob. This is also the project's **first per-prop facing of any kind** — `PropDef` has no orientation field, `room_builder.gd` passes none, and nothing in the prop pipeline has ever needed one. Facings use the edge vocabulary of `docs/DIRECTION_GLOSSARY.md` §3 (NE/SE/SW/NW), never an invented one. | ✅ Shipped (`e98ad25`) |
| **D5** | **Facing constants are MEASURED from the baked frames, never reasoned out.** A GLB's own forward axis is arbitrary art data — there is no formula. Method used, and to be reused for every future weapon model: PCA of each frame's alpha silhouette gives its on-screen principal axis; the thinner end (barrel vs. stock) makes that axis *directed*; match against the screen angle each grid edge projects to. **This caught a real bug the same day:** `PERSPECTIVE_YAW_DEG` was first copied verbatim from `GrenadeProp.YAW_BY_DIRECTION` and is wrong for E/W — the muzzle came out 170.6° off in view E and 178.2° off in view W, aiming away from the wall, while N and S were already right. Flipping E/W took the worst error across 4 views × 4 bench columns from **178.2° to 9.4°**. `GrenadeProp` is deliberately left alone: a grenade does not point anywhere, so a 180° error is invisible on it and its table was never under a test that could catch it. **A weapon aiming at a specific block is the first object in this project whose facing is falsifiable.** | ✅ Ratified (measured 2026-07-29) |
| **D6** | **The test bench is a MATRIX: weapon type on one axis, wall material on the other.** *"4 armas repetidas (uma cópia de cada arma por parede, como as granadas), posicionadas em fila indiana, na distância mais adequada para utilização"* — so a row is one weapon at the range it is actually meant to be used at, and a column is one material. Every weapon can therefore be tried against every material at its proper range. Director's explicit sequencing: **proper ranges first**, then *"posteriormente podemos testar a destruição usando distâncias invertidas e menos apropriadas"* — the inverted-distance pass is a second experiment, not a variation to fold in now. | ✅ Ratified |
| **D7** | **Weapons are authored as data files, exactly like bombs are.** `BombRegistry.load_from_disk()` scans `res://bombs` then `user://bombs` and registers every `*.json` it finds, user tier winning on id collision — so new definitions already need **zero code changes** to appear. A `WeaponRegistry` should be a line-for-line copy of it against a `weapons/` folder (which is itself how `BombRegistry` was written against `PropRegistry`), rather than a third pattern. Open: whether explosives migrate into `WeaponDef` or `BombDef` stays as the RADIAL specialisation — see §7. | 🟠 Proposed |
| **D8** | **Non-destructive weapons dispatch into the systems that already own their effects — this plan never grows a second implementation of them.** Flashbang blinds → perception; EMP disables electronics → AI/alarms, and it is *already* in `noise.md`'s intensity table at 0.90; smoke blocks line of sight → occlusion, which already names it as a planned scenario; darts and distractions → noise and the guard FSM. The catalog owns the **entry and its parameters**; the effect belongs to whoever already owns that domain. This is the same boundary `DESTRUCTION_MASTER_PLAN` §3 draws around `Voxel.visible`, applied one level up. | 🟠 Proposed |
| **D10** | **Baked frames are SHARED per bake folder, and a prop loads only the frames it can display.** *(FRAME-MEM-01, 2026-07-29 — found while sizing this arsenal, not from a bug report.)* One 120-frame set costs **48.2 MB of real VRAM**, measured on GPU. Loading it per instance meant the four bench shotguns held four identical copies — 241 MB for five props, and a projected **1447 MB** for the 6-weapons × 4-columns + pickups layout. `CollectibleFrameCache` (in the `Registries` autoload, not a `static var` — see FIX-SHUTDOWN-CRASH-01b) holds one set per `frames_dir`, and `FloatingCollectible` asks only for the indices it can ever show: all 120 for a spinning pickup, exactly **4** for a static prop (one per N/E/S/W). Measured result on the same layout: **241 → 49.8 MB**. **The arsenal's real cost ceiling is therefore the PICKUPS, not the bench** — a bench weapon is ~1.6 MB, a spinning one is ~48–58 MB, and that ratio is what should drive how many pickups a real room ever shows at once. | ✅ Shipped (measured, 2026-07-29) |
| **D11** | **A weapon's declared `delivery` is the truth, even when the engine cannot honour it yet.** The five rifled weapons are `LINE` in their JSON because that is what they are — a ray with penetration depth, a different mechanic from a narrow `CONE`. `WeaponBenchController` dispatches on delivery and **loud-fails** on `LINE` rather than firing a cone out of a sniper rifle because a cone is what exists. Silent substitution of an implemented mechanic for a specified one is exactly what this project's evidence rules ban, and a catalog that lies about its own entries is worse than one with a visible gap. | 🟠 Proposed |
| **D9** | **Rarity, stats and progression are deliberately absent from v1.** Director: *"posteriormente iremos trabalhar mais detalhadamente em raridades, e stats como dano, firerate, accuracy, etc."* Writing a stat table now would mean inventing balance numbers before a single shot has been fired against a real wall — the same trap `MaterialResistanceTable`'s own header already flags about its placeholder values (*"first-pass placeholders — a balancing lever, not researched constants"*). | ✅ Ratified |

---

## 3. Boundaries — what this plan does NOT own

Stated up front because three of the four families in D1 end in systems that
already have owners, and the failure mode is a second, silently diverging
implementation.

- **Breaking voxels belongs to `DESTRUCTION_MASTER_PLAN`.** `BlastCalculator` is
  the sole writer of `Voxel.set_damage()` (that plan's §3). A weapon says
  *"CONE, from this GU, along NE, with these step multipliers"*; it never
  touches a `Voxel`, a `Slice`, a `Slab` or a `TileMapLayer`.
- **Displaying a weapon belongs to `ACTOR_MASTER_PLAN`.** Bake rig, frame
  counts, relighting, `CollectibleBakeConfig` — all of it stays there. D3/D4/D5
  above are catalog-facing *consequences* of that pipeline, recorded here
  because the arsenal's cost depends on them, and cross-referenced there.
- **Blinding, deafening, disabling and obscuring belong to perception, noise,
  AI and occlusion**, per D8.
- **Inventory, equipping and loadouts belong to nothing yet** and are not
  claimed here.

---

## 4. Numbers — what we actually know

Measured, not estimated.

| Quantity | Value | Source |
|---|---|---|
| Destruction shapes implemented | **2 of 4** — `RADIAL`, `CONE`. `LINE` declared by 5 weapons and **not built** | `flood_gu_rings()` / `flood_gu_cone()` |
| Weapon definitions on disk | **6** in `weapons/` + 1 in `bombs/` | shotgun (CONE) · pistol, revolver, smg, assault_rifle, sniper_rifle (all LINE) |
| **Baked-frame VRAM, per object** | **48.2 MB** for a 120-frame set (measured, real GPU) | FRAME-MEM-01 — the number that reshaped the bench, see below |
| Test-zone frame VRAM, per-instance loading | **241 MB** for 5 props; **1447 MB** projected at 30 | measured / projected before the shared cache |
| Test-zone frame VRAM, shared + sparse | **49.8 MB** for the same 5 props (**4.8×**) | measured after `CollectibleFrameCache` |
| Frames a STATIC prop actually needs | **4 of 120** (one per N/E/S/W) | why the bench is nearly free and the pickups are not |
| Material resistance (destroy_factor) | metal 0.05 · stone 0.30 · concrete 0.50 · wood 0.90 | `MaterialResistanceTable` — placeholders, a balancing lever |
| Material resistance (crack_factor) | metal 0.60, everything else 0.0 | idem — metal distorts rather than breaks |
| Collectible bake, per object | 120 frames × 4 passes = **480 PNGs, 4.7 MB** (shotgun) / **1.9 MB** (grenade) | on disk, 2026-07-29 |
| Static prop bake, per object | 4 frames × 2 passes = **8 PNGs, 84 KB** | `grenade_frames/`, on disk |
| ⇒ cost of one more *static* weapon vs. a collectible | **~56× cheaper** | D3 — the reason the arsenal can grow |
| Grenade collectible bake wall time | 120 frames, one windowed M1 run, **~2 min** | this session's real run |
| Facing accuracy, worst case across 4 views × 4 columns | **9.4°** (was 178.2° before D5's fix) | measured, `e98ad25` |
| Weapon models already on disk (CC0) | **28 glTF**: 4 pistols, 3 revolvers, 4 shotguns, 4 sniper rifles, 3 assault rifles, 1 bullpup, 2 SMGs, 4 accessories (bayonet/bipod/scope/tripod), + 1 grenade | Quaternius packs, `ATTRIBUTION.txt` records CC0 1.0 |
| Weapon models MISSING entirely | flashbang, EMP, smoke, C4, darts | — |

**The one number that should worry us** is not memory and not bake time — it is
**shape count × material count × distance**, the balancing surface D9 defers.
Four delivery shapes against four materials at N ranges is the real test matrix,
and D6's bench is the instrument built to measure it.

---

## 5. The catalog

Grouped as the Director grouped them. **Scenario effect** is the only column
that matters for v1 — this is the axis D1 exists to serve. Everything about
rarity and stats is deliberately blank (D9).

### 5.1 Firearms — `CONE` and `LINE`

Bench row = the distance that weapon is meant to be used at (D6). Six are placed
and baked as of 2026-07-29; each also appears as a spinning pickup in the
collectibles strip, from the SAME bake (D10 — one bake, two roles).

| Weapon | Shape | Bench row | Scenario effect | Status |
|---|---|---|---|---|
| **Shotgun** | `CONE` | **y=4** (closest) | *"cone mais ou menos largo"* by accuracy; heavy close, falling off fast. The reference case for `CONE`. | ✅ baked, placed, **fires** |
| **Pistol** | `LINE` | y=6 | *"pistola com mais ou menos punch, que gera um voxel de destruição por vez"* — the minimum unit of destruction. Punch varies depth, not width. | ✅ baked, placed · ❌ LINE unbuilt |
| **Revolver** | `LINE` | y=7 | Pistol family, higher punch — the intra-class variation D1 absorbs without new code. | ✅ baked, placed · ❌ LINE unbuilt |
| **SMG** | `LINE` | y=9 | Pistol-calibre, high rate — matters for firerate (D9), not for shape. | ✅ baked, placed · ❌ LINE unbuilt |
| **Assault rifle** | `LINE` | y=11 | *"rifle abre um buraco maior"* — wider and deeper than a pistol's single voxel. | ✅ baked, placed · ❌ LINE unbuilt |
| **Sniper rifle** | `LINE` | y=13 (farthest) | Deepest penetration, longest range — the far end of the ladder. | ✅ baked, placed · ❌ LINE unbuilt |
| Bullpup, and 18 further pack variants | — | — | Unbaked; adding one is a row in `weapon_frames_bake.gd` plus a `weapons/*.json`. | ⏸ available |

**The bench is five-sixths inert on purpose.** Only the shotgun fires, because
only `CONE` exists; the rifled weapons declare `LINE` truthfully and loud-fail
when fired (D11). `LINE` is the obvious next mechanic and is not in this
document's Part list by accident — it is DESTRUCTION_MASTER_PLAN Part 5's
remaining half.

**One shared framing for every gun** (`weapon_frames_bake.gd`): the pack's
models share a coordinate scale (pistol 1.8 native units, shotgun 4.5, sniper up
to 7.3), so one MESH_SCALE/ORTHO renders them at **true relative size** — a
sniper reads long, a pistol stubby — instead of each being auto-framed to fill
its canvas and arriving the same apparent length. The numbers are chosen so
px-per-world-unit matches the already-shipped shotgun bake exactly
(160/4.0 = 40 = 220/5.5), which is what lets them drop in beside it with no
re-tuning of `SPRITE_SCALE` or the texel-width outline.

### 5.2 Explosives — `RADIAL` and `NONE`

| Weapon | Shape | Scenario effect | Model on disk |
|---|---|---|---|
| **Frag grenade** | `RADIAL` | Shipped and working — the only implemented weapon in the game. | ✅ |
| **C4** | `RADIAL` | Placed rather than thrown; larger radius. Placement/timer is new behaviour, the *shape* is not. | ❌ |
| **Incendiary** | `RADIAL` | Fire is `DESTRUCTION_MASTER_PLAN` Part 4 territory (cover/noise/fire), not this plan's. | ❌ |
| **Flashbang** | `NONE` | Blinds vision for a turn → perception (D8). No voxel damage. | ❌ |
| **EMP** | `NONE` | Disables electronics/cameras/alarms → AI. Already in `noise.md` at intensity 0.90 and `movement.md`'s AP table at 2 AP. | ❌ |
| **Smoke** | `NONE` | Blocks line of sight → occlusion, which already names this as its planned scenario. | ❌ |

### 5.3 Stealth — `NONE`

Director: *"a princípio nada destrutivo."*

| Weapon | Shape | Scenario effect | Model on disk |
|---|---|---|---|
| **Tranquiliser dart** | `NONE` | Silent takedown → guard FSM. The deprecated design doc's §10.3 already specced a *lançador de dardos*, 6 tiles, no noise. | ❌ |
| **Distraction / thrown object** | `NONE` | Creates a noise event at a chosen cell → `docs/systems/noise.md`. | ❌ |

**Asset gap, stated plainly:** every firearm in §5.1 already has a CC0 model;
**nothing in §5.2 or §5.3 does except the frag grenade.** The explosives and
stealth tiers need sourcing before they can be placed, and per D3 each one is
an 8-PNG bake, not a 480-PNG one.

---

## 6. Parts

### Part 0 — The test bench — ✅ DONE 2026-07-29 (`e98ad25`)
D6's matrix, built for real in the PLAYGROUND test zone: 4 static shotguns at
gu y=6 aiming NE at their own wall material, the 4 ground grenades kept, and
collectibles moved out of the firing lanes to a dedicated strip at y=13.
`TEST_ZONE_WEAPON_ROWS` in `room.gd` is the row axis — adding the next weapon
is one table entry. D4's static facing mode and D5's measured constants shipped
with it. Verified by real capture in all four perspectives, plus the VL-PERSIST
crater/soot regression re-run.

### Parts 1–3 — ✅ DONE 2026-07-29, same day as this document

**Part 1 (`WeaponDef` + `WeaponRegistry`)** shipped as written below —
`weapons/*.json`, two-tier scan, `Registries.get_weapon_registry()`. Unknown
`delivery` values loud-fail rather than defaulting to something destructive.
`weapons/shotgun.json` is the first entry (CONE, 5 steps, 25° half-angle, 0.6
calibre). **§7 #1 is still open:** `BombDef` did NOT migrate — explosives stay on
`BombDef`/`bombs/` for now, so a `frag_grenade` is still not a "weapon" in the
data model.

**Part 2 (`CONE`)** shipped as `BlastCalculator.flood_gu_cone()` — the same
wall-aware BFS as `flood_gu_rings()`, gated to a wedge. **6 new selftests, 27/27
total**, covering the things that could plausibly be wrong: forward-not-backward
(compared against the radial flood from the same source, so it proves the cone is
doing work rather than just returning fewer cells), widening with distance,
half-angle as accuracy, a 1° cone still firing down its axis, blocked-edge
stopping, and the `{Vector2i -> int}` output shape being a drop-in for the
existing damage path. `destroy_multiplier` verified to scale AND to be inert at
its default, so every grenade call site is untouched.

**Part 3 (the fire trigger)** shipped as `WeaponBenchController` +
a parameterised `DetonateContextMenu`. Two deliberate departures from the
grenade: a weapon is **not consumed** by firing (the bench's whole purpose is
firing the same weapon at four materials and comparing), and a shot **does not
crater the floor** — it hits what it is aimed at.

**Real evidence, not description:** one shotgun, three materials, three
captures — metal takes a few pockmarks (destroy_factor 0.05), concrete opens a
ragged breach (0.50), wood loses a corner (0.90). The cone preview and the shot
both follow N/E/S/W rotation, verified analytically across all four views and by
capture in three of them. Grenade path re-verified after the menu rewiring
(crater + soot + wood embers intact).

**Balance note, flagged not fixed:** a shotgun opening a person-sized hole in
concrete reads STRONG. `destroy_multiplier` 0.6 and the 5-step falloff are
first-pass placeholders in exactly the sense `MaterialResistanceTable`'s own
header already claims for its numbers — a lever, not a researched constant.

### Part 1 — `WeaponDef` + `WeaponRegistry` *(D1, D2, D7 — as originally scoped)*
The data layer, mirroring `BombDef`/`BombRegistry` line for line (which
themselves mirror `PropDef`/`PropRegistry` — this would be the fourth use of one
proven pattern, not a new one). Carries `id`, `delivery` (D1's four-way enum),
`step_multipliers`, D2's calibre/accuracy/damage knobs, `gameplay`, `tags`.
Two-tier `res://weapons` + `user://weapons` folder scan. **Decide first** whether
explosives migrate in or `BombDef` stays as the RADIAL specialisation (§7 #1).

### Part 2 — `CONE` and `LINE` in `BlastCalculator` *(D1 — OPEN, the real work)*
The directional flood, sibling to `flood_gu_rings()` and **as wall-aware as it
is**: a shot that meets a wall stops at it. Both new shapes take an origin GU
*and a facing*, which is the input the destruction path has never had. Output
must be the same `{gu -> step}` dictionary shape `find_affected_containers()`
already consumes, so nothing downstream changes. This is where the Director's
*"cones de destruição baseado nos calibres dos projéteis, distância"* actually
becomes geometry. **Belongs in `DESTRUCTION_MASTER_PLAN` as its Part 5**, since
that plan owns everything that writes damage; tracked here only because the
catalog is what defines the shapes.

### Part 3 — The fire trigger *(OPEN)*
*"Vamos usar o mesmo mecanismo de disparar das granadas (botão do mouse
direito)."* The pieces and their real state, audited 2026-07-29:
- `BlastWireframeOverlay` — **reusable unchanged.** `show_footprint()` takes an
  arbitrary `Array[Vector2i]` and draws the outer boundary of whatever cell set
  it is given; nothing in it is ring-shaped. A cone footprint feeds straight in.
- `DetonateContextMenu` — **not reusable as-is.** Two hardcoded buttons and two
  named signals (`detonate_requested`/`cancelled`), no item list. Either a
  sibling class or a generalisation into labelled actions.
- `room.gd::_unhandled_input()` — one more `if hit_test(...) != -1` branch in
  the existing right-click block. **Trap:** the guard at the top of that method
  treats any mouse press while `_context_menu.visible` as an outside-click
  cancel; a second menu instance needs that guard to know about both.
- `TestZoneController` — its own header calls it *"scaffolding [...] not a
  permanent prop-interaction architecture"*, so a sibling controller is the
  path of least resistance, not a generalised multi-prop system.

### Part 3b — `LINE`, the other rifled half *(OPEN — the next real mechanic)*
Five of the six bench weapons declare it and none can fire (D11). Unlike `CONE`,
`LINE` is not just a gate on the existing BFS: its step axis is **penetration
depth through a wall's thickness**, measured in voxels, while every falloff
table in the engine is per-GU (§7 #2 — still undecided). A first cut could take
the cheap path (a single file of GUs along the facing, penetration expressed
through `destroy_multiplier`, reusing everything `CONE` reuses) and leave real
voxel-depth penetration for later; that trade is worth making explicitly rather
than by accident.

### Part 4 — The non-destructive tier *(D8 — OPEN, and it is four systems' work)*
Flashbang, EMP, smoke, darts, distractions. Each is a catalog entry here and an
effect *there*. Deliberately last: it depends on the AI/perception work that
`AI_MASTER_PLAN` owns, and none of it has a model on disk yet.

---

## 6b. Shotgun calibration — measured, PAUSED awaiting Director instructions

Director, 2026-07-29: *"está destruindo demais, numa area muito larga. O cone
precisa ser mais concentrado pra frente, e não pode causar tanto estrago"* — then,
after seeing the candidates below: *"vamos ter que planejar melhor isso, vou
fornecer instruções mais detalhadas."* **Nothing was changed.**
`weapons/shotgun.json` still holds the shipped values. The measurements are
recorded here so the eventual instructions start from data instead of from
scratch.

Three candidates, same shot into the concrete wall from the bench's y=4 row
(2 GU away), real captures `auto_2026-07-29_22-05-13 / -24 / -35`:

| | half-angle | steps | calibre | GU cells hit | slices | reads as |
|---|---|---|---|---|---|---|
| **A** (shipped) | 25° | 5 | 0.60 | **6** | 12 | the whole face breached |
| **B** | 14° | 4 | 0.35 | **4** | 8 | a narrower full-height slot |
| **C** | 9° | 4 | 0.25 | **4** | 8 | a ragged chewed strip |

**B and C hit the same cells** — at 2 GU the two angles collapse onto the same
grid, so at this range the half-angle stops being a lever and only the damage
multiplier separates them. Any calibration decided at this row should be
re-checked from a farther row, where the angle starts to matter again.

**The finding that is NOT calibration:** all three cut the wall floor to
ceiling. A cone is a 2D GU footprint, so every level of a hit slice takes damage
— `apply_container_damage()`'s vertical ring only steps once per STOREY, which
softens the upper storey without ever bounding the shot to a height. A shotgun
blast opening a full-height slot is very likely most of the "estrago" the
Director saw, and no value in the JSON can fix it. Director's call, same day:
**"vamos limitar a altura, aguarde mais detalhes"** — the mechanic is wanted,
the shape of it is not yet specified. It belongs to every weapon, not just the
shotgun, and is a sibling of `LINE` (Part 3b) rather than part of it.

## 7. Open questions

1. **Does `BombDef` migrate into `WeaponDef`, or stay as the RADIAL
   specialisation?** Migrating means one schema and one registry, at the cost of
   touching the one weapon that currently works. Keeping both means a
   `frag_grenade` is not a "weapon" in the data model, which will read as a wart
   the first time inventory needs one list. Not decided.
2. **Is a `LINE` weapon's penetration measured in voxels or in GUs?** Voxels
   (8 per GU per axis) is the resolution destruction actually works at and is
   what makes "one voxel per pistol shot" expressible at all — but every
   existing falloff table is per-GU. The two do not obviously want the same
   step unit.
3. **What stops a shot — and does it stop the same way movement does?**
   `flood_gu_rings()` reuses `blocked_edges`, the movement gate. A bullet and a
   footstep do not obviously agree about what blocks them (a bullet passes a
   railing; a guard does not), and this is the first place that distinction has
   to be made.
4. **Where does a weapon's facing come from once an actor holds one?** D4 gave
   props a facing; actors already have `_snap_to_8dir` for gameplay facing.
   Whether these become one concept or stay two is undecided, and Part 0's props
   are explicitly temporary — *"no gameplay real serão empunhadas por algum
   ator"*.
5. **The other three entries of `FACING_YAW_DEG` are derived, not measured.**
   Only NE is exercised by the bench today; SE/SW/NW come from the measured −90°
   step. First real use of one should be confirmed by a capture the same way NE
   was (D5).
6. **`GrenadeProp.YAW_BY_DIRECTION` is probably wrong in E/W too** (D5), and
   nothing visible depends on it. Left alone deliberately. Worth a real check if
   the thrown-grenade work ever gives a grenade a readable orientation.
