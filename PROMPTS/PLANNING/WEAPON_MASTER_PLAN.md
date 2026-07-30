# WEAPON_MASTER_PLAN
## The Arsenal — What Weapons Exist, and What Each Does to the Scenario — v1.0

**Status:** 🟢 **Catalog drafted, first shot fired, and the shot-physics model
brainstormed — all 2026-07-29.** The physics model (D12–D20, §5b) is **ratified
but entirely unbuilt**, and it **supersedes D1/D2's cone-as-volume for every
firearm** — which is the correction to what actually shipped. Nine questions
raised against it (§7a) are queued to be unpacked one at a time. **S1 is closed**
(D21–D23: hit roll forceable, decoration hashed not RNG); **S7 (origin/target
points) is now the one blocker left** — D15's 360° trajectory and D18's chest
height both need two 3-D points that do not exist yet.
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
| **D12** | **A shot resolves by DICE, in two rolls: does it hit, then how much damage.** *(Director brainstorm, 2026-07-29.)* Not a ballistics simulation and not a to-hit derived from geometry. **Being clearly visible on screen does not make a target easier to hit** — that depends on agent skills, cover, shadow, weapon level, powerups and so on. The sprite's legibility is a rendering concern; hittability is a stats concern, and the two are deliberately decoupled. Damage is a second roll against armour, resistance, distance. | ✅ Ratified |
| **D13** | **A projectile resolves to a POINT of impact. The cone is AIM-ERROR SPREAD, never a volume of destruction.** *(Director brainstorm, 2026-07-29.)* **This reframes D1's `CONE` and D2's "accuracy = half-angle" for every firearm**, and it is the correction to what shipped: `flood_gu_cone()` destroys *everything* in the wedge, which is why the shotgun read as both too wide and floor-to-ceiling. Under this model the cone only bounds where an impact point may land; each projectile then damages the geometry at its own point. A shotgun is 8 scattered points, not one wedge. `RADIAL` (explosives) is unaffected — a blast really is a volume. | ✅ Ratified — supersedes D1/D2 for firearms |
| **D14** | **Projectile count per shot is the weapon's signature.** Sniper 1, shotgun ~8, pistol 1. Each projectile rolls **independently** — its own hit roll, its own damage roll, its own impact point, its own chance to break a voxel. This is what makes a shotgun a shotgun without a second code path: same pipeline, run N times. | ✅ Ratified |
| **D15** | **A miss keeps flying.** The projectile continues along the shot's own trajectory to the next wall; if nothing is in that direction, it is void and nothing happens. Trajectory is derived from **origin point and target point** in 360°, then projected into the isometric view — not snapped to the 4/8 compass directions the rest of the project uses for movement and facing. | ✅ Ratified |
| **D16** | **Wall impact is a destruction ladder, not a fixed footprint** (concrete; other materials D19). A sniper hit **always breaks at least 1 voxel**, with a chance of up to **5 more** around the contact point, that chance scaling with weapon level, distance and powerups. If more than 3 surrounding voxels go, **one further roll** can break a voxel INWARD — taking the outer slice and the inner one, which may punch through and let light pass. Shotgun and pistol resolve per projectile: each pellet gets its own chance to break a voxel. | ✅ Ratified |
| **D17** | **Firearm soot is FACE-LOCAL and has no rings.** Same visual language as the grenade's, but it appears only on the newly revealed faces of the voxels neighbouring the destroyed one — the inside of the hole darkens, and nothing spreads outward. A bullet marks its impact; it does not blacken the wall. | ✅ Ratified |
| **D18** | **Shots are chest-height with an error margin, and a wall hit is ALWAYS a miss.** You cannot aim at the floor: a shot is always between the agent and an enemy (or an interactive object). The error margin runs up/down and side to side, covering one slice or more depending on the distance between target and wall. A catastrophic roll (1,1,1…) can miss badly enough to break a floor voxel near the target — the exception that proves the rule, not an aiming option. | ✅ Ratified |
| **D19** | **Material response differs in KIND, not just in amount.** **Wood**: the round punches through more easily, destroying little around it. **Metal**: almost nothing is destroyed, but the hit voxels are strongly marked — and should visibly **dent**, sliding back about half a voxel width so the surface reads as deformed rather than broken. (See §7 — as literally described, denting collides with inviolable Rule 8.) | ✅ Ratified (mechanism open) |
| **D20** | **Damage stacks.** A shot into already-damaged geometry applies the same effects on top, destroying more as the case warrants. There is no "already hit" state that absorbs a second round. | ✅ Ratified |
| **D21** | **Two layers with opposite needs: the HIT ROLL is gameplay and must be forceable; everything downstream of a miss is DECORATION and only has to obey the rules.** *(Director, 2026-07-29, closing S1: "a questão determinística não é tão importante nesse caso, porque estamos falando basicamente de decoração [...] a questão que nós temos que determinar obrigatoriamente é a chance de acertar ou errar o alvo".)* Whether a shot hits is the one thing gameplay testing must pin — a dev override forces 0% or 100% so a scenario replays. Where a miss landed, and whether it broke 3 voxels or 4, are appearance: any outcome inside D16's ladder is correct. **Also ratified: the projectile does not exist in the scene** — no travel, no per-frame simulation, only its consequences are drawn (animations are later). X-COM is the named reference: statistics plus a little luck. | ✅ Ratified |
| **D22** | **Rolls use the project's existing FNV-1a hash, not an RNG — decided by the Director's delegation ("fica ao seu critério"), on cost grounds.** `FacadeSampler._fnv1a_hash()` is already pinned by invariant **B4** and already does exactly this job for destruction: `_select_deterministic()` separates its DESTROY and CRACK picks by nothing more than a **salt** in the key. Reusing it means no RNG state, no seed plumbing through any signature, and — the load-bearing reason — **every destruction selftest can keep asserting exact voxel sets**, the way all of them do today. Pure RNG would force those tests down to asserting ranges, trading the project's whole verification discipline for decoration. It also works where a seed could not: the bench has **no turn and no shooter**, so a `(turn, shooter, projectile)` seed cannot even be formed there, while a hash accepts whatever stable identity the context has. Keys: gameplay `(turn, shooter id, shot index, projectile index)`; bench `(weapon cell, shot counter, projectile index)`; one salt per purpose (hit / how many voxels / which voxels). | ✅ Ratified (delegated decision) |
| **D23** | ~~**Hash-based hit rolls are save-scum resistant, and that is a design choice to make on purpose.**~~ **RETIRED 2026-07-29, same day, by the Director: there is no save to scum.** *"o game não vai ter save, apenas o progresso geral do personagem vai sendo salvo automaticamente"* — the game is played in short infiltration waves with a beginning, middle and end inside a set of segments; **checkpoints** exist so a failure does not always return you to the start of a segment. What survives is only overall character progression, saved automatically. **The property does not disappear, it changes owner:** replaying from a checkpoint and taking *exactly* the same actions reproduces the same rolls, because turn and shot index are in the key — while acting differently changes the keys and changes the dice. That is the behaviour worth having (no retry-until-lucky, but no dead end either), and it is now a consequence of D22 rather than a decision of its own. The old caveat survives in reduced form: the key must be derivable from **checkpoint-restored** state, not from a session-local counter. | ↩️ Retired (premise false) |
| **D24** | **World state is segment-scoped; only character progression persists.** *(Director, 2026-07-29 — recorded because it decides what has to be serialisable and nothing else in the docs says it.)* No deliberate save exists. This draws a boundary the destruction system has never been asked about: **does a checkpoint restore undo destruction?** VL-PERSIST records damage per voxel in base coords so it survives *perspective rotation*, but nothing snapshots it, so a checkpoint could not currently roll a wall back to intact. Either destruction is checkpoint-scoped (needs snapshot/restore of that map — cheap to design in now, expensive to retrofit) or it is deliberately permanent within a segment run. Not decided. | ❓ Open — new question raised by D23's retirement |
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

## 5b. Shot physics — how one shot resolves *(Director brainstorm, 2026-07-29)*

D12–D20 as an ordered pipeline, because a sequence reads badly as table rows.
**Nothing here is built.** The sniper is the reference case — it is the simplest
(one projectile) and every straight-line weapon is a variation on it.

```
for each projectile in weapon.projectile_count:        # sniper 1, shotgun ~8, pistol 1

  1. HIT ROLL          against agent skills, cover, shadow, weapon level,
                       powerups.  NOT against how visible the sprite is (D12).

  2a. ON HIT  -> DAMAGE ROLL against armour, resistance, distance.
                 (the projectile's story ends here — unless it penetrates, §7)

  2b. ON MISS -> the projectile KEEPS FLYING (D15)
       |
       +-- trajectory = origin point -> target point, in 360 degrees,
       |   projected into the isometric view. Not compass-snapped.
       |
       +-- nothing in that direction?            -> VOID, nothing happens
       |
       +-- wall within a reasonable distance?    -> IMPACT (below)

  3. IMPACT, concrete (D16):
       always            1 voxel destroyed
       chance            up to +5 more around the contact point
                         (scales with weapon level, distance, powerups)
       if >3 went        one more roll: break INWARD, taking the outer slice
                         AND the inner one -> may punch through, may let light in

     wood  (D19): punches through more easily, destroys little around it
     metal (D19): destroys almost nothing; hit voxels are strongly marked and
                  DENT — slid back ~half a voxel width (mechanism open, §7)

  4. SOOT (D17): face-local, NO rings. Only the newly revealed faces of the
     voxels neighbouring the destroyed one. The hole darkens inside; nothing
     spreads outward.
```

**Vertical placement (D18).** Shots sit at chest height with an error margin up,
down and sideways, covering one slice or more depending on how far the target is
from the wall behind it. **A shot that hits a wall is by definition a miss** —
the wall is never the thing being aimed at. Floor damage is only reachable
through a catastrophic roll near the target.

**Stacking (D20).** Firing into already-damaged geometry re-applies everything
above; there is no saturation state.

**What this corrects.** The shipped `flood_gu_cone()` treats the cone as a volume
and destroys every slice inside it, which is exactly why the Director saw "área
muito larga" and a floor-to-ceiling breach (§6b). Under D13 the cone only bounds
where impact *points* may land. That single change is expected to resolve both
complaints, and it means §6b's calibration numbers describe a model that is
being replaced — they stay recorded as evidence of the old behaviour, not as a
target to tune toward.

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

### Part 3b — `LINE`, the other rifled half *(OPEN — the next real mechanic, now specified by §5b)*

**Re-scoped 2026-07-29 by the shot-physics brainstorm.** What follows below was
written when `LINE` looked like "`CONE` but narrow". §5b replaces that: a
straight-line weapon is a **hit/miss roll per projectile, then a point impact**,
and the sniper is its reference case *"que vão ser a base das armas em linha
reta"* (Director). The nine questions in §7a all have to be answered inside this
Part — S1 (dice vs. the codebase's no-RNG determinism) and S7 (origin/target
points) block the rest of it.

*Original scoping text, kept:*
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

### 7a. Raised against the shot-physics brainstorm (2026-07-29) — to be unpacked one at a time

**S1. ✅ CLOSED 2026-07-29 — see D21/D22/D23.** The collision dissolved once the
question was split: the hit roll is gameplay (forceable 0%/100%), everything
after a miss is decoration (any outcome inside D16's ladder is correct). Rolls
use the existing FNV-1a hash rather than an RNG, so selftests keep asserting
exact voxel sets and no seed has to be plumbed anywhere — and, decisively, a
`(turn, shooter, projectile)` seed could not be formed on the bench at all,
which has neither. One consequence still needs the Director's intent: hash rolls
are save-scum resistant (D23). *Original text kept below.*

"Determinístico" means the OPPOSITE thing in this codebase, and the
collision is not cosmetic. Here it means *no RNG*:
`BlastCalculator._select_deterministic()` picks voxels by FNV-1a hash-and-rank,
and invariant **B4 pins that** — same inputs, same result, forever. D12's dice
are the opposite. Dice do *work*, because destruction persistence **records** the
outcome per voxel in base coords (VL-PERSIST) rather than recomputing it, so a
rolled shot survives perspective rotation. But two real costs land: a shot stops
being reproducible (every destruction selftest today asserts exact voxel sets),
and a Director-reported bug ("I fired and it opened *this*") cannot be replayed.
**Middle path to evaluate:** roll against a seed derived from
`(turn, shooter id, projectile index)` — unpredictable to the player, exactly
reproducible for us and for tests. Decide before building, not after.

**S2. Metal denting, as described, is forbidden by inviolable Rule 8.** Sliding
a hit voxel back half a width is a great visual, and there is no sub-tile offset
to do it with: voxels reach the tilemap only through `set_cell()`, and
`TileMapLayer`'s per-cell transforms are flip/transpose only. Rule 8 exists
precisely to stop the `Sprite2D`-on-top / image-compositing answer. **Viable
route:** bake "dented" atlas variants and select them as a damage state, the way
`CRACKED` already is — deformation becomes art, not geometry.

**S3. Face-local soot is a new data shape, not a parameter.** `soot_ring` today
is **per voxel** — the BFS marks whole voxels. D17 wants **per face**. The good
news is `VoxelLightField` already works in faces (12 directional brightness
buckets per face), so the rendering side can express it; the storage does not
exist yet.

**S4. Noise is completely absent from the brainstorm, in a stealth game.** A shot
is the loudest thing an agent can do. `docs/systems/noise.md` already has an
intensity table (EMP sits at 0.90) and the retired design doc specced silenced
pistols and rifles. Silenced vs. unsilenced is plausibly the most important
tactical axis the arsenal has, and D8's boundary says the effect belongs to the
noise system — but the *catalog entry* for it belongs here.

**S5. What stops a projectile?** Does it pass through a target it hits — a
penetrating sniper round could take two aligned enemies. And once it breaks
inward through both slices (D16), is that a light hole only, or can the next
round travel into the room beyond?

**S6. Geometry in the way: hard block, or a hit-roll modifier?** A wall between
agent and enemy should stop the shot; a railing should not. `flood_gu_cone()`
currently reuses `blocked_edges`, which is the **movement** gate — §7 #3 below
already flagged that a bullet and a footstep need not agree.

**S7. Chest height needs an ORIGIN and a TARGET point.** D18 and the Director's
separate "vamos limitar a altura" both depend on two 3-D points that do not exist
yet: is the origin the agent's chest or the weapon's muzzle, and is the target
the enemy's chest? The 360° trajectory of D15 cannot be derived without them.

**S8. The bench only exercises the MISS path.** It fires at a wall with no enemy
present, so the hit/damage half of D12 has no fixture at all. That half needs its
own target dummy before it can be verified rather than reasoned about.

**S10. Does a checkpoint restore undo destruction?** *(New, raised by D23's
retirement — see D24.)* The game has no deliberate save; it runs in short
infiltration waves over a set of segments, with checkpoints so a failure does not
always send you back to a segment's start. Nothing has ever asked what the world
looks like after a checkpoint restore. VL-PERSIST records damage per voxel in
base coordinates — enough to survive a perspective rotation, not enough to roll a
wall back to intact, because nothing snapshots it. Two coherent answers
(destruction is checkpoint-scoped and needs snapshot/restore, or it is permanent
for the whole segment run) and they cost very different amounts if chosen late.
**Belongs to `DESTRUCTION_MASTER_PLAN`, not here** — the arsenal only surfaced
it.

**S9. Smaller, still unanswered:** maximum range at which a projectile still
damages a wall ("distância razoável"); AP cost and shots per turn
(`docs/systems/movement.md` has the table); ammunition; what counts as
"environment interativo"; and whether hitting an actor produces voxel damage on
it (`ACTOR_MASTER_PLAN` D5/D6 has a deferred progressive-damage model waiting).

### 7b. Pre-existing

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
