# WEAPON_MASTER_PLAN
## The Arsenal — What Weapons Exist, and What Each Does to the Scenario — v1.0

**Status:** 🟢 **Catalog drafted, first shot fired, shot-physics model
brainstormed 2026-07-29 — and the CONE model itself rebuilt 2026-07-30 (D26-D28):
per-projectile point impacts, no flood-fill, no hard range cap.** `BlastCalculator.select_cone_pellet_impacts()` +
`apply_point_impact()` are real and selftested (35/35); the shipped `flood_gu_cone()`
+ `apply_container_damage()` area-scatter this section originally described for
CONE is **superseded**, not merely planned to be. D12–D20 (§5b) otherwise remain
**ratified but entirely unbuilt**, and D13 **supersedes D1/D2's cone-as-volume
for every firearm** — which is the correction to what actually shipped. Of the nine
questions raised against it (§7a), **S1, S2, S3, S4, S5, S6 and S7 are now
closed** (2026-07-29/30) — most recently **S7 by D25** (2026-07-30): a shot
always targets an actor picked through the contextual menu, never a free-aim
direction, so **Part 3b (`LINE`) is unblocked**. **S2 closed via
`DESTRUCTION_MASTER_PLAN` D22**: a real `DENTED` damage tier, every material
can reach every tier, logic AND texture layers shipped 2026-07-30 (D22's own
placeholder marks, then D23 same day giving blast damage its own irregular
mark family distinct from a bullet's round one, amended 2026-07-31 for mark
size/legibility). **S3 closed and shipped as `DESTRUCTION_MASTER_PLAN` D24**:
soot for both explosions and firearms is now derived fresh every repaint from
which voxels are absent, never stored. S8 and S9 are explicitly deferred to
the Actor/Combat wave, and two of the four pre-existing §7b questions (1 and
4) are closed alongside them. **Open going into the next session** (found
2026-07-31, real capture): damage marks don't yet know which face of a voxel
actually faced the blast — `DESTRUCTION_MASTER_PLAN.md` §7 item 6, pending a
diagram from the Director before it's designed.
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
| **D24** | **World state is segment-scoped and commits at exactly two points; only character progression persists.** *(Director, 2026-07-29 — recorded because it decides what has to be serialisable and nothing else in the docs said it. Full model now in [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) §1 "Run state model"; the destruction half is answered in [`DESTRUCTION_MASTER_PLAN.md`](DESTRUCTION_MASTER_PLAN.md) §7 q0.)* **A segment IS a map**, one loaded at a time, linked by matching exits — and some puzzles require acting in one segment to collect a result in another, so changes must outlive unloading. Three tiers: **live** (lost on death — *"o agente vai voltar no tempo"*), **session** (written ONLY on stepping a checkpoint or leaving the segment; lost on quit, which reloads the whole segment set), **persistent** (character skills/stats/clothing, automatic). Destruction rewinds with the segment, holes included. | ✅ Ratified |
| **D9** | **Rarity, stats and progression are deliberately absent from v1.** Director: *"posteriormente iremos trabalhar mais detalhadamente em raridades, e stats como dano, firerate, accuracy, etc."* Writing a stat table now would mean inventing balance numbers before a single shot has been fired against a real wall — the same trap `MaterialResistanceTable`'s own header already flags about its placeholder values (*"first-pass placeholders — a balancing lever, not researched constants"*). | ✅ Ratified |
| **D25** | **A shot always targets a specific actor via the contextual menu — there is no free aim, and the environment does the aiming, not the player.** *(Director, 2026-07-30, closing S7.)* Origin is whichever actor is shooting — agent, enemy, turret, etc.; target is whichever actor was selected through the tap/right-click menu that already frames every other action (the XCOM reference in `docs/vision/game_vision.md`). **On hit**, the projectile stops at the target and the damage roll applies. **On miss**, it keeps travelling the same origin→target line (D15) until it meets a wall — D16's destruction ladder applies there — or leaves the level with nothing in the way, and vanishes. Because the player only ever picks a target, never a direction, a miss can land anywhere in D18's error margin (wide, high, low) without the player having "aimed wrong": *"o player É OBRIGADO a atirar na direção certa [...] mas, se ele errar, pode errar POR MUITO [...] o environment é que faz a mira, e não o jogador."* Cover and skills move the hit-chance dice, not a reticle. This is what makes D21's split hold together end to end: the hit roll stays the one forceable, deterministic-for-testing lever; everything downstream (where a miss lands, how many voxels break) stays hash-driven decoration — *"mesmo que a destruição seja realmente aleatória, o gameplay continua sendo totalmente determinístico."* | ✅ Ratified — closes S7 |
| **D26** | **There is no hard range cap — destruction comes FROM misses, and the cone's own widening is what makes a far shotgun shot self-limiting.** *(Director, 2026-07-30, retracting the 5-step ceiling `weapons/shotgun.json`'s `step_multipliers.size()` imposed on the bench.)* *"não pode ter esse limite de 5 GUs, principalmente porque a destruição é oriunda dos erros [...] quando a shotgun estiver longe ela vai ampliar mais o cone, e a chance de dispersão aumenta bastante, o que naturalmente vai invalidar o uso da arma."* A range limit would make sense if the roll were about hitting — it is not (D12); the wall is what a MISS travels on to reach (D15/D25), and a miss can originate from a shot aimed at something close to the shooter that simply goes wide. What discourages a long shotgun shot is not a hard cutoff but the cone widening with distance (already-existing geometry, `cone_half_angle_deg`), which spreads pellets thinner and less useful the farther they travel — an emergent limit, not an authored one. Supersedes the "y=6 is the CONE's hard ceiling" finding from earlier the same day (WEAPON_MASTER_PLAN §5.1/bench comment) — that finding was correct about the CODE AS SHIPPED, not about the intended design. **Shipped same day**: `WeaponBenchController.PELLET_FLOOD_MAX_STEPS` (40) replaces `step_multipliers.size()-1` everywhere a max range was read from the falloff table. | ✅ Ratified & shipped — supersedes the bench-row range ceiling |
| **D27** | **A shotgun shot is N independent pellet rolls (D14's projectile_count), each landing on exactly ONE voxel — never a flood-filled area.** *(Director, 2026-07-30.)* Per pellet: roll hit/miss against the target. **On hit**: damage roll applies to the target; with enough force it can continue through to a wall behind and leave a blood mark instead of a bullet mark (*"a desenvolver"* — not this pass, no target dummy exists yet, S8). **On miss**: the pellet keeps travelling in roughly its original direction, inside a horizontal spread that widens with distance travelled (*"um holofote horizontal, que aumenta com a distância. Quanto mais distante, mais longe o tiro pode acabar indo"*), until it reaches the nearest wall in that direction — that wall voxel is the pellet's own, individual impact point. This replaces D13's cone-as-footprint (which this session's shipped `flood_gu_cone()` still treats as an area to flood-damage-and-graduate-by-ring) with a literal reading of D13: **the cone bounds where impact points CAN land; it was never itself the thing that takes damage.** **Shipped same day** as `BlastCalculator.select_cone_pellet_impacts()` — see the implementation note below the table; only the MISS half is built (no target dummy exists, S8), matching this wave's own scope. | ✅ Ratified & shipped (miss path only) — supersedes the shipped `flood_gu_cone()` + `apply_container_damage()` area-scatter for CONE |
| **D28** | **A bullet mark exists ONLY at a projectile's own impact voxel — never on neighbours, never scattered across a ring.** *(Director, 2026-07-30.)* *"Os buracos de bala não podem aparecer em qualquer lugar, somente no ponto de impacto de cada projetil."* Neighbouring voxels may still take **soot** (D17, already face-local and derived) but never their own DENTED/CRACKED texture — soot and bullet-mark are different data, D17 already got this right, D22's `apply_container_damage()` did not (it distributes DENTED/CRACKED across a whole ring group). **If the impact voxel is fully DESTROYED, the voxel immediately behind it (the wall's paired slice, `Edge.slice_a_id`/`slice_b_id` — confirmed 2026-07-30 that both slices index `voxels[]` in matching order, same level, same array index, so the "behind" voxel is a direct lookup) becomes a new roll target** — destroyed / dented / cracked / untouched, same three-tier table (D22), same cascade rule recursively. **If a shot fully penetrates (every layer destroyed), there is no mark anywhere on that path** — nothing stopped there to leave one, per *"se o tiro atravessar a parede não tem marca de bala porque ela continuou o caminho."* **Shipped same day** as `BlastCalculator.apply_point_impact()`. | ✅ Ratified & shipped — supersedes D22's ring-group DENTED/CRACKED distribution for CONE/LINE (RADIAL/grenade keeps the ring model; a blast genuinely is an area effect) |
| **D29** | **Sniper and pistol fire one straight-line projectile each (not a pellet spread), but still miss into a dispersion zone "similar" to the shotgun's, with modifiers — unspecified.** *(Director, 2026-07-30: "vão ter uma trajetória reta, porque os tiros são individuais, mas eles podem errar em uma zona similar à da shotgun, com modificadores. Vamos trabalhar isso melhor depois.")* Explicitly deferred — not this pass. Recorded so `LINE`'s eventual build doesn't silently default to zero spread on a miss. | ⏸ Deferred (explicit) |

**D28 amended 2026-08-02 — WHERE the mark lands, ratified in
`DESTRUCTION_MASTER_PLAN.md` D32 and not duplicated here.** D28 pinned *which
voxel* takes a mark and left the face open; the mark was in fact painted on the
voxel's **top diamond**, so every firearm hit on a wall put its bullet hole on
the roof. D32 fixes it: a bullet marks exactly the **one lateral face it
struck**, resolved by `BlastCalculator.carved_side_for()` in screen space — the
same function the blast side already used — and a firearm hits **walls only**
this pass (Director: *"vamos simplificar por enquanto e fazer só tiros que
acertam paredes"*), so no bullet ever reaches a floor or a ceiling. Read D32
for the decal model, the half-voxel substrates and the placement table; this
plan owns *what a weapon emits*, never *how the voxel is drawn*.

### D26-D28 implementation note (2026-07-30) — two real bugs, caught and fixed same day

**`BlastCalculator.select_cone_pellet_impacts()`** replaces the flood-fill for
CONE: each pellet gets its own angle (uniform within `±half_angle_deg`, hashed
from `(salt, pellet index)` — a design choice, not specified, tunable later)
and walks it via `_walk_pellet_ray()`, a Bresenham-style lateral drift against
the facing axis, stopping at the first thing that blocks it. `resolve_pellet_voxel()`
turns a `{gu, face}` stop into a real `Slice` + voxel index (chest-height
placeholder: the target slice's own base-storey midpoint, pending a real
chest-height derivation once an actor has a modelled height — not guessed
further than that). `apply_point_impact()` is D28's roll-and-cascade, one
voxel then at most one sibling-slice voxel behind it.

**Bug 1 — the first version was still an area operation wearing a point-shaped
API.** It flooded the WHOLE cone (`flood_gu_cone()`, uncapped per D26) and
picked `projectile_count` cells from every wall-adjacent cell in that entire
reachable set. A pellet's "impact" could therefore be a wall reached by
flowing sideways around a narrow obstacle via some other open path — not the
wall actually in front of that pellet. Fixed by giving each pellet its own
single walked path (above), which by construction cannot detour: an obstacle
directly ahead stops it there, full stop.

**Bug 2 — found immediately after fixing Bug 1, on the real bench: every
pellet still landed on the room's own outer wall, uniformly "concrete",
regardless of which material column was fired at.** Root cause, confirmed by
reading `MapCompiler.compile()`: a solid GU block (`spec.blocks` — this bench's
own per-material walls) marks whole CELLS occupied (`blocked_map`, surfaced to
`room._blocked_cells`, the same dict `guard.set_los_data()` already keys LOS
off) and **never touches `blocked_edges` at all** — only the older `dividers`
authoring path does that (and only for its N/S neighbours, not E/W — a second,
narrower gap, not touched here). `WallEdgeData.is_edge_blocked()` alone is
blind to a `spec.blocks` obstacle, so the pellet walker sailed straight
through the bench's own block and kept going. Fixed by adding a `blocked_cells`
parameter, checked alongside `blocked_edges` at every step.

**✅ CLOSED 2026-08-01 — the flagged consequence**: `flood_gu_rings()`/`flood_gu_cone()`
only checked `blocked_edges`, so a grenade's blast (and the CONE wireframe
preview, `_cone_cells()`) could propagate straight through a `spec.blocks`
obstacle the same way the pellet walker did before Bug 2's fix. Both floods
now take the same trailing `blocked_cells: Dictionary = {}` parameter, checked
alongside `blocked_edges` at every BFS step — an occupied cell is never
entered, and the block's facing slices still take damage because
`find_affected_containers()` walks `edges_touching_gu()` of the flooded side.
All three real callers wired with `room._blocked_cells` (test zone preview +
detonation, bench `_cone_cells()`). Red-before-green in
`blast_calculator_selftest.gd`: `test_flood_rings_stops_at_solid_block` /
`test_flood_cone_stops_at_solid_block` failed with the literal leak
(`block_in=true behind_in=true`, `RESULT: 41 PASS, 2 FAIL`) before the check
landed, `43 PASS, 0 FAIL` after.

**Evidence**: `blast_calculator_selftest.gd` 35/35 PASS, including 2 new
regression tests reproducing both bugs directly (`test_pellet_does_not_detour_around_narrow_obstacle`
covers both the `blocked_edges` and `blocked_cells` forms). Real capture,
weapon bench index 1 (metal), post-fix: 6 of 8 pellets landed on the intended
metal block with small, isolated marks (not a scatter — matches D28), the
other 2 (wide-angle pellets) correctly cleared the block's lateral extent and
landed on the wall behind it — the realistic spread behaviour D26/D27
describe, not a bug.

**Same day, later in the session — `weapons/shotgun.json` `projectile_count`
raised 8 → 24.** *(Director: "me parece que a shotgun está tirando muito
pouco dano da parede, deveria ter mais buracos. Vamos tentar com 24
projéteis. Depois acertamos a questão do dano durante o gameplay.")* A data
value only (D14/D27's existing pipeline runs it N times unchanged, no code
touched) — **per-pellet damage/falloff balance is explicitly deferred to
gameplay tuning**, not decided here. Real capture confirms `pellets=24/24
landed` and a visibly denser cluster of impact marks against both the
concrete and wood test-zone walls (`Screenshots/history/auto_2026-07-30_23-34-19.png`,
`auto_2026-07-30_23-36-21.png`).

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
- **Bullet-mark *painting* (not breaking) is being narrowed by
  `EXPLOSION_REBUILD_MASTER_PLAN.md`'s D12 (2026-08-06, that plan's own local
  decision numbering — unrelated to this plan's own D12/D13 in §5b).** Once
  that plan's Task 1 lands, D33's live per-cell mark compositing is planned to
  become a pre-baked-atom swap, same mechanism as blast damage. Only the
  *paint* step changes — hit detection and damage-state transition stay
  exactly where D26–D33 put them, in this plan. Not yet done as of this note;
  see that plan's §9 and §11 for the sequencing.

---

## 4. Numbers — what we actually know

Measured, not estimated.

| Quantity | Value | Source |
|---|---|---|
| Destruction shapes implemented | **3 of 4** — `RADIAL`, `CONE`, `LINE` (2026-08-02, D30). `NONE` is by definition no-op | `flood_gu_rings()` / `flood_gu_cone()` / `select_line_impact()` |
| Weapon definitions on disk | **6** in `weapons/` + 1 in `bombs/` | shotgun (CONE) · pistol, revolver, smg, assault_rifle, sniper_rifle (all LINE) |
| **Baked-frame VRAM, per object** | **48.2 MB** for a 120-frame set (measured, real GPU) | FRAME-MEM-01 — the number that reshaped the bench, see below |
| Test-zone frame VRAM, per-instance loading | **241 MB** for 5 props; **1447 MB** projected at 30 | measured / projected before the shared cache |
| Test-zone frame VRAM, shared + sparse | **49.8 MB** for the same 5 props (**4.8×**) | measured after `CollectibleFrameCache` |
| Frames a STATIC prop actually needs | **4 of 120** (one per N/E/S/W) | why the bench is nearly free and the pickups are not |
| Material resistance (destroy_factor) | metal 0.05 · stone 0.30 · concrete 0.50 · wood 0.90 | `MaterialResistanceTable` — placeholders, a balancing lever |
| Material resistance (dent_factor) | metal 0.50 · stone 0.30 · concrete 0.20 · wood 0.05 | idem — D22 (2026-07-30): every material can now dent, not just metal |
| Material resistance (crack_factor) | metal 0.30 · stone 0.20 · concrete 0.15 · wood 0.03 | idem — flat surface mark, milder than dent, applied after it |
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

Bench row = the distance that weapon is meant to be used at (D6). All six were
baked and placed 2026-07-29; **pared to three on the bench 2026-07-30** for real
destruction calibration (Director: *"a bancada está muito cheia [...] vai ser
impossível atirar diretamente na parede durante o jogo, então vamos remover a
maioria das armas"*) — revolver/SMG/assault rifle stay baked and cataloged
(still real weapons, still available to re-place) but are off the physical
bench, since all three are `LINE` and added rows without adding mechanical
coverage beyond what pistol/sniper already exercise. Each of the three still on
the bench also appears as a spinning pickup in the collectibles strip, from the
SAME bake (D10 — one bake, two roles).

| Weapon | Shape | Bench row | Scenario effect | Status |
|---|---|---|---|---|
| **Shotgun** | `CONE` | **y=6** | *"cone mais ou menos largo"* by accuracy; heavy close, falling off fast. The reference case for `CONE`. Moved back from y=4 2026-07-30 — y=6 is `flood_gu_cone()`'s hard ceiling given the wall at y=2 and 5-entry `step_multipliers`; farther and the shot stops reaching the wall at all. | ✅ baked, placed, **fires** |
| **Pistol** | `LINE` | y=9 | *"pistola com mais ou menos punch, que gera um voxel de destruição por vez"* — the minimum unit of destruction. Punch varies depth, not width. | ✅ baked, placed · ❌ LINE unbuilt |
| **Revolver** | `LINE` | off bench | Pistol family, higher punch — the intra-class variation D1 absorbs without new code. | ✅ baked · ⏸ not placed (2026-07-30) |
| **SMG** | `LINE` | off bench | Pistol-calibre, high rate — matters for firerate (D9), not for shape. | ✅ baked · ⏸ not placed (2026-07-30) |
| **Assault rifle** | `LINE` | off bench | *"rifle abre um buraco maior"* — wider and deeper than a pistol's single voxel. | ✅ baked · ⏸ not placed (2026-07-30) |
| **Sniper rifle** | `LINE` | y=13 (farthest) | Deepest penetration, longest range — the far end of the ladder. | ✅ baked, placed · ❌ LINE unbuilt |
| Bullpup, and 18 further pack variants | — | — | Unbaked; adding one is a row in `weapon_frames_bake.gd` plus a `weapons/*.json`. | ⏸ available |

**The bench is two-thirds inert on purpose.** Only the shotgun fires, because
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

### Part 3b — `LINE`, the other rifled half *(✅ LANDED 2026-08-02 — see DESTRUCTION_MASTER_PLAN D30)*

**Shipped.** `BlastCalculator.select_line_impact()` fires one straight ray from
the muzzle GU along the facing, stopping at the first blocked edge or occupied
cell — deliberately reusing `_walk_pellet_ray()` at angle 0 rather than
reimplementing a ray, so the stop conditions (edge blocking, occupied cells,
D15's void fallthrough) can never drift between `CONE` and `LINE`.
`WeaponBenchController` dispatches it instead of loud-failing, **retiring D11's
loud-fail for `LINE`** (the gate stays for `RADIAL`/`NONE` on the bench).

**The damage model is `DESTRUCTION_MASTER_PLAN` D30's `punch` coefficient**, not
a `LINE`-specific one — a sniper and a shotgun pellet differ only by their
coefficient, never by code path.

**One canon correction landed here, caught by a real bench shot rather than by
review:** D1 defines `step_multipliers` as **distance bands for `CONE`** but
**penetration depth for `LINE`**. The first implementation read it as distance
for both, which made a sniper *weaker at range than a pistol* (measured: punch
0.54 at 11 GU, below even the DENTED rung). `ShotPunchTable` now splits the two
meanings into `cone_distance_multiplier()` and `penetration_multiplier()`, and
the selftest asserts they are not interchangeable. `LINE` has no distance
falloff at all today — a rifle's step table is spoken for by penetration and no
range curve exists in the schema, which is D29's explicitly deferred work.

*Original scoping text, kept:*


**Re-scoped 2026-07-29 by the shot-physics brainstorm, unblocked 2026-07-30.**
What follows below was written when `LINE` looked like "`CONE` but narrow". §5b
replaces that: a straight-line weapon is a **hit/miss roll per projectile, then
a point impact**, and the sniper is its reference case *"que vão ser a base das
armas em linha reta"* (Director). §7a's two structural blockers are both closed
now — S1 (dice vs. the codebase's no-RNG determinism, D21–D23) and S7
(origin/target points, D25) — so nothing left in §7a stops implementation from
starting; S8/S9 and §7b.2/.5/.6 are open or deferred details, not gates
(S2 also closed since, via `DESTRUCTION_MASTER_PLAN` D22).

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

**Stale distance, 2026-07-30**: the bench moved the shotgun from y=4 to y=6
since these numbers were taken (§5.1) — they describe a 2-GU shot, the bench
now fires from 4 GU. Re-measure at the new distance before using these as a
tuning target; the ring/step math means a farther shot lands on a weaker
multiplier by construction, not because anything in `shotgun.json` changed.

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

**S2. ✅ CLOSED 2026-07-30 — logic AND placeholder-art layers shipped, see
`DESTRUCTION_MASTER_PLAN` D22 + §7 item 4.** Metal denting as originally
described (sliding a hit voxel back half a width) is still forbidden by
inviolable Rule 8 — no sub-tile offset exists, `TileMapLayer`'s per-cell
transforms are flip/transpose only — but the real answer turned out bigger
than either candidate route below: `Voxel.DamageState` gained a real `DENTED`
tier (sunken — a true alpha-cut core baked into an otherwise ordinary flat
tile, still one `set_cell()` image, no new geometry), distinct from `CRACKED`
(flat surface mark, fully opaque), and **every material can now reach every
tier** — this retracts the "stone stays whole" framing below. Both tiers
render as a dedicated, self-contained impact-mark tile that always bypasses
the baked-facade lookup (`VoxelRenderer.damage_variant_material()` +
`_is_impact_mark()`), loaded from its own folder
(`ASSETS/ISOMETRIC/source_assets/voxels/impact_marks/`) via the exact
mechanism `earth_0..7` already proved — real photographic bakes drop in later
at the same filenames, zero code changes. Placeholder "vector" marks ship now
(`generate_voxel.py`'s `generate_impact_mark()`), verified by real capture:
metal before/after (`auto_2026-07-30_16-30-54.png` /
`auto_2026-07-30_16-29-41.png`) and concrete after
(`auto_2026-07-30_16-31-26.png`). Glass added as a 5th wall material,
DESTROYED-only by design (*"não vai ter dented; é buraco feito, ou não
feito"*), registered but not yet wired into a bench row. *Original text kept
below.*

Metal denting as originally described is forbidden by inviolable Rule 8:
sliding a hit voxel back half a width has no sub-tile offset to do it with,
since voxels reach the tilemap only through `set_cell()` and `TileMapLayer`'s
per-cell transforms are flip/transpose only. Two candidate routes were on
record, neither prototyped: **(a)** bake "dented" atlas variants and select
them as a damage state, the way `CRACKED` already is — deformation becomes
art, not geometry (the agent's original proposal); **(b)** *"substituir um
voxel por 'meio' voxel, on the fly, e ficar realmente 'amassado'"* — the
Director's own idea, swapping the hit cell to a distinct half-height tile
through `set_cell()`.

**S3. ✅ CLOSED 2026-07-30.** Face-local soot is ratified, and cheaper than the
storage question below implied: *"Como a gente está trabalhando com shades,
acredito que o custo de memória é pequeno, e pode ser reconstruído rapidamente
baseado nos voxels ausentes na cena."* Soot does not need its own persistent
per-face store — it can be **derived at render/relight time from which
neighbouring voxels are already absent**, the same way `VoxelLightField`'s
per-face buckets are computed rather than stored per instance. VL-PERSIST
already knows which voxels are missing; this reads that, it does not add a
second dataset. *Original text kept below.*

**Shipped same day, later in the session, as `DESTRUCTION_MASTER_PLAN.md`
D24**: `Voxel.soot_ring` deleted; `BlastCalculator.derive_soot_rings()`
replaces `compute_soot_rings()`, writing into a caller-supplied snapshot
instead of mutating the Voxel; `room._build_soot_snapshot()` derives it fresh
for the whole map every repaint. This also folded grenade soot into the same
mechanism (`DESTRUCTION_MASTER_PLAN.md` §7 item 5), so the "no rings"
face-local-only carve-out this section's D17 originally described no longer
exists as a separate case — firearm soot now reuses the identical up-to-3-ring
BFS a blast uses, just naturally shallow because an isolated hole has nothing
further out that is also absent.

`soot_ring` today is **per voxel** — the BFS marks whole voxels. D17 wants
**per face**. The good news is `VoxelLightField` already works in faces (12
directional brightness buckets per face), so the rendering side can express it;
the storage does not exist yet. *(Closed by FACE-SOOT-01, 2026-08-01 — per-face
storage shipped, see `DESTRUCTION_MASTER_PLAN.md`'s D24 ledger entry.)*

**Extended further by D33-SOOT-01 (2026-08-03).** D17's "a bullet marks its
impact; it does not blacken the wall" held exactly, until the Director found
the edge it didn't cover: a DENTED/CRACKED voxel that never happens to sit
next to an actual hole got NO soot at all — not faint, not local, none —
because the BFS above only ever seeds from `DESTROYED` voxels. Measured:
pistol/metal, pistol/stone and shotgun/metal structurally never cross
`PUNCH_DESTROY_MIN` given `RESISTANCE`'s current values, so those
combinations never produced a hole to seed from, regardless of weapon.
`BlastCalculator.apply_self_soot()` adds one faint, non-propagating ring
directly on the struck face — still true to "does not blacken the wall" (no
spreading to neighbours, ever), just no longer leaves the mark itself looking
pristine.

**S4. ✅ CLOSED 2026-07-30 — deferred, not designed here.** Noise stays owned by
the noise system (D8) and is explicitly secondary at this point: once a firearm
fires, stealth is already blown — the agent eats the alert-meter cost and has
to find a way out alive, possibly abandoning the objective. *"queremos que 80%
do tempo o jogo seja com stealth, armas não letais, dardo tranquilizante,
distrações, etc etc. Isso não causa destruição."* The silenced-vs-not catalog
axis is real future work — *"a questão do ruído vai ser bem definida"* — just
not now. Confirmed alongside it: **`NONE`-delivery (non-lethal) weapons never
cause destruction.** *Original text kept below.*

A shot is the loudest thing an agent can do. `docs/systems/noise.md` already has
an intensity table (EMP sits at 0.90) and the retired design doc specced
silenced pistols and rifles. Silenced vs. unsilenced is plausibly the most
important tactical axis the arsenal has, and D8's boundary says the effect
belongs to the noise system — but the *catalog entry* for it belongs here.

**S5. ✅ CLOSED 2026-07-30.** No projectile object exists to "stop" — passing
through a first target into a second, or through a target into the wall behind
it, is a **dice/algorithm outcome** (excess force vs. the target's armour and
resistance), never a physical continuation. And directly: **a shot that breaks
both slices inward (D16) does not carry enough force to do anything in the room
beyond** — *"Um tiro que quebra as duas fatias não tem força pra fazer nada no
próximo cômodo."* It stops there, light-hole included. *Original text kept
below.*

Does it pass through a target it hits — a penetrating sniper round could take
two aligned enemies. And once it breaks inward through both slices (D16), is
that a light hole only, or can the next round travel into the room beyond?

**S6. ✅ CLOSED 2026-07-30 — also closes §7b's item 3 below (same question).**
Intervening geometry is not a separate hard-block-or-modifier check on the miss
path, because it never gets that far: *"geometria no caminho supostamente não
existe, porque se o player não tiver line of sight ele não tem como escolher
atirar."* Line-of-sight gates whether "shoot" is even offered as a menu action
in the first place (D25); there is nothing left to stop mid-flight, because per
D21 there is no projectile in flight to begin with. *Original text kept below.*

A wall between agent and enemy should stop the shot; a railing should not.
`flood_gu_cone()` currently reuses `blocked_edges`, which is the **movement**
gate — §7 #3 below already flagged that a bullet and a footstep need not agree.

**S7. ✅ CLOSED 2026-07-30 — see D25.** Origin and target are now defined: any
actor (agent, enemy, turret) for either end, selected via the contextual menu,
never by free aim. D15's 360° trajectory and D18's chest height now have two
real points to run against.

**S8. Deferred, not closed — 2026-07-30.** The hit/damage half of D12 stays
unfixtured on purpose: *"O acerto vai ser feito depois, quando a gente tiver
trabalhando nos atores. Por enquanto queremos fechar só a destruição do
cenário."* This wave's scope is the destruction/miss path only; a target dummy
for the hit path belongs to the Actor/Combat wave. *Original text kept below.*

The bench only exercises the MISS path. It fires at a wall with no enemy
present, so the hit/damage half of D12 has no fixture at all. That half needs
its own target dummy before it can be verified rather than reasoned about.

**S10. ✅ ANSWERED same day — see D24, and `DESTRUCTION_MASTER_PLAN` §7 q0 for
the mechanism.** Destruction rewinds with the segment, holes included; state
commits only at a checkpoint step or on leaving the segment. *Original question
kept below.*

Does a checkpoint restore undo destruction? *(New, raised by D23's
retirement.)* The game has no deliberate save; it runs in short
infiltration waves over a set of segments, with checkpoints so a failure does not
always send you back to a segment's start. Nothing has ever asked what the world
looks like after a checkpoint restore. VL-PERSIST records damage per voxel in
base coordinates — enough to survive a perspective rotation, not enough to roll a
wall back to intact, because nothing snapshots it. Two coherent answers
(destruction is checkpoint-scoped and needs snapshot/restore, or it is permanent
for the whole segment run) and they cost very different amounts if chosen late.
**Belongs to `DESTRUCTION_MASTER_PLAN`, not here** — the arsenal only surfaced
it.

**S9. Deferred to the COMBAT wave — 2026-07-30.** Maximum range, AP cost and
shots per turn, ammunition, what counts as "environment interativo", and
whether hitting an actor produces voxel damage on it are explicitly
*"vamos trabalhar depois em COMBATE"* — out of scope for the current
destruction-focused wave. *Original text kept below.*

Maximum range at which a projectile still damages a wall ("distância
razoável"); AP cost and shots per turn (`docs/systems/movement.md` has the
table); ammunition; what counts as "environment interativo"; and whether
hitting an actor produces voxel damage on it (`ACTOR_MASTER_PLAN` D5/D6 has a
deferred progressive-damage model waiting).

### 7b. Pre-existing

1. **✅ CLOSED 2026-07-30.** `BombDef` stays separate, not migrated into
   `WeaponDef`: *"Bomba pode ficar numa outra categoria porque vai precisar de
   outra interface, com o sistema de jogar de uma GU pra outra."* A thrown
   explosive needs a GU-to-GU throw/targeting interface a stationary or
   menu-aimed weapon does not, so unifying the schema now would blur two
   different interaction models. *Original text kept below.*

   Does `BombDef` migrate into `WeaponDef`, or stay as the RADIAL
   specialisation? Migrating means one schema and one registry, at the cost of
   touching the one weapon that currently works. Keeping both means a
   `frag_grenade` is not a "weapon" in the data model, which will read as a wart
   the first time inventory needs one list.
2. **Leaning voxels, pending a real test — 2026-07-30, not fully closed.**
   *"Não sei, temos que testar, mas acho que vai acabar sendo voxels, pra ter
   mais precisão."* Recorded as the working hypothesis `LINE`'s first cut
   should build against, to be confirmed once penetration is actually measured
   against a wall — not ratified as a final answer. *Original text kept below.*

   Is a `LINE` weapon's penetration measured in voxels or in GUs? Voxels (8 per
   GU per axis) is the resolution destruction actually works at and is what
   makes "one voxel per pistol shot" expressible at all — but every existing
   falloff table is per-GU. The two do not obviously want the same step unit.
3. **✅ CLOSED 2026-07-30 — see S7a's S6 above, same question, closed there.**
   Line-of-sight gates whether "shoot" is offered at all; there is no separate
   hard-block-vs-modifier check because there is no projectile in flight to
   stop (D21, D25).
4. **✅ CLOSED 2026-07-30 — for the shot-resolution half.** A weapon's aim
   facing is the GU(origin)→GU(target) vector itself (D25), not a
   rendering-precision concept: *"o facing é de GU (ponto de origem) pra GU
   (alvo), não sendo necessário precisão milimétrica porque [...] o tiro não
   percorre a trajetória de maneira física, mas sim teórica."* Whether this
   becomes the SAME concept as an actor's gameplay facing (`_snap_to_8dir`) for
   other purposes (movement, idle orientation, held-weapon rendering) is still
   open — only the aim-math half is answered. *Original text kept below.*

   Where does a weapon's facing come from once an actor holds one? D4 gave
   props a facing; actors already have `_snap_to_8dir` for gameplay facing.
   Whether these become one concept or stay two is undecided, and Part 0's props
   are explicitly temporary — *"no gameplay real serão empunhadas por algum
   ator"*.
5. **Deliberately left as derived, not measured — reaffirmed 2026-07-30.** Only
   NE is exercised by the bench today; SE/SW/NW still come from the measured
   −90° step rather than their own capture. Director's call after review:
   trust the derivation, and confirm each direction by capture the first time
   it is actually used in gameplay (D5's method), rather than spending time
   verifying all three now.
6. **Left alone, unchanged — reaffirmed 2026-07-30.** `GrenadeProp.YAW_BY_DIRECTION`
   is probably wrong in E/W too (D5), and nothing visible depends on it, since a
   spinning grenade has no readable orientation. Director's call: leave it until
   the thrown-grenade work ever gives a grenade a readable orientation, don't
   spend time on it now.
