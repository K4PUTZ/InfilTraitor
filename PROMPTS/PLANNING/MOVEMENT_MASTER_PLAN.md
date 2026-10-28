# MOVEMENT_MASTER_PLAN
## How the characters move: the animation bank, the map of what the game needs, and the path from a Tripo clip to a move on the grid — v1.1

> **Status: 🟢 MILESTONE OPENED 2026-10-27 (Director: "vamos abrir a milestone de movimento e escrever o MASTER PLAN"; "vamos fazer
> um banco de animações, e depois mapear o que precisa, o que tem e o que falta").** Nothing in §3-§9 is built yet. The brief this
> ⏸ **PARKED until the models are done (Director, 2026-10-27: "vamos deixar planejado, pra fazer depois que os modelos estiverem
> prontos").** MV-1 starts once the male (with coat and hat, and without) and the female are assembled (`CHARACTER`, §9 items 1-2).
> replaces (v0.1, 2026-08-16, written for the retired sprite bake) is `docs/history/MOVEMENT_BRIEF_v0.1_2026-08-16.md`; what in it is
> still design is carried into §2 below and cited there, never restated twice.
>
> **v1.1 (2026-10-28):** MV-2's map is §4.1, by clip NAME only (to confirm on MV-1's sheets), with the credits ranking and the
> Director's open questions. Docs only; nothing built.

---

## 0. Ownership boundary

| Document | Owns |
|---|---|
| `ACTOR_MASTER_PLAN` §2 | the **decision register** (D-rows). Cite by number, never restate |
| `CHARACTER_MASTER_PLAN` | the **figure**: the model, the rig, the slots, how a Tripo character is assembled (`tripo_assemble.py`) |
| **this document** | **what the figure DOES**: the animation bank, the catalogue of situations, which clip plays where, how a clip is made game-ready, and how motion is judged |

The engine's actor today (`ActorMesh3D`, `godot/scripts/geometry/actor_mesh3d.gd`) drives the old 20-bone rig from `agent_live*.glb`
(D64). Moving it onto the Mixamo rig is this milestone's work (§6), because the bank is useless until the engine plays it.

---

## 1. What changed since the brief, and what it settles

1. **Characters come from Tripo on the Mixamo skeleton (`ACTOR` D85).** The motion comes with them: Tripo's AI clips, generated on the
   paid plan, so they are ours (D85's licence reading; D57 widened to geometry and outputs we own).
2. **One skeleton for every figure — MEASURED, 2026-10-27.** The female base (`female+no+coat.glb`) and the male
   (`MaleCharacterNoCoat.glb`) have the same 65 joints with the same `mixamorig:` names; their joint positions differ by about 2 % of
   the height (hips at 0.557 vs 0.552 on the 1 m figure Tripo exports). D85's open question "is Tripo's Mixamo rig identical on every
   biped" is answered for these two.
3. **A clip of one figure plays on the other — MEASURED, 2026-10-27.** The male's `walk` and `box_01` on the female, in Blender: as
   exported and with rotations only (the Hips' location scaled by the ratio of the two hips' heights, 1.009) read the same. **Rule for
   the bank (§3): keep the ROTATIONS, and the Hips' translation normalised by hip height.** Tripo keys a location on all 65 bones;
   those carry the source figure's bone lengths, and a 2 % difference is invisible today but would not be on a child, a giant or a
   cosmetic that changes the proportions.
4. **Motion is authored as ACTIONS on the live rig (D64), not baked frames.** In-betweens are interpolation; blends, layers and
   transitions happen in the engine. The brief's argument for key-poses-first (bakes are the expensive step) no longer holds as
   stated; the method survives for authored clips (§7).
5. **What stays ratified, cited:** four facings and diagonal = two orthogonal steps (D44, kept for gameplay by D64); facing changes by
   SNAP at the GU boundary, no transition frames (D47); the step is 0.56 s per GU (D61).

---

## 2. The design inputs (Director's rulings, carried from the brief)

Each is in the archived brief in full; here is the list the catalogue (§4) must cover.

| Source (brief §) | What |
|---|---|
| §2.1 M1 | A **quiet little run** on open ground: hunched head and shoulders, weapon pointing down but ready, head looking around |
| §2.1 M2 | At a GU with a **wall**: pressed against it, to show less |
| §2.1 M3 | At a **corner**: the Wolfenstein 3D cover pose |
| §2.1 M4 | **Crouched with no wall**: one knee down, the other up and bent, pistol raised, the other hand on the ground on five fingertips |
| §2.1 M5 | **Crawling**: one leg extended, the other pushing back, the weapon in front of the head |
| §2.1 | M2 / M3 depend on what is ADJACENT to the GU; `agent.gd`'s `cover_state` / `cover_direction` exist and have never driven a visual |
| §5 | The quality bar: *"falta mais 'molejo' nas articulações, mais micro movimentos"*; the 2026-08-16 hand-keyed refinement did not reach it |
| §6.4 | A looping **idle** for every entity standing still (the revealed-actor silhouette is the mesh itself on the live rig, so it follows) |
| §6.5 | **Equip, aim, fire, return, and the CANCEL of everything**: every weapon / accessory change animates both ways; the resting / alert pose depends on the situation (hurried: weapon down, two hands, head scanning; stealthy: another) |
| §7a | From liquids and gravity: down into a pit and out, wading, quicksand, crust, ice / oil slips, the agent on fire, the muzzle / throw origin at the figure's real height, rope and hook, perches |
| `DESIGN_MASTER_PLAN` | Confrontation and cover, distractions (§5.4), rope & hook + perches (§10.0), the LED cloak's crouch (D72) |

Also ruled (Director, 2026-10-26, D85's record): **Tripo's clips give the raw motion; we make them game-ready** (strip the root
motion, loops, D61's step timing, mirrors); **for cover → run → cover, generate ONE multi-segment take, cut it into pieces and chain
the pieces in code.**

---

## 3. MV-1 — the ANIMATION BANK

**What:** every clip we hold, extracted from every Tripo GLB into one place, on the canonical skeleton, with a catalogue row each.
Clips arrive inside character files (66 in `MaleCharacterNoCoat.glb` on 2026-10-27, 2 in `female+no+coat.glb`) and the same name can
come from several files; the bank makes a clip independent of the figure it was generated with.

**Design (proposed, Claude):**
- **Tool:** `tools/asset_generation/tripo/tripo_anim_bank.py` (Blender, `blender -b -P`), sharing `tripo_common.py`. Input: any number
  of Tripo GLBs. Output: `ASSETS/ANIMATIONS/bank/` (git-ignored like the rest of `ASSETS/`): one GLB per clip (the canonical
  skeleton + that action, rotations + normalised Hips translation, §1.3) and `bank.json`, the catalogue.
- **The canonical skeleton:** the Mixamo joint NAMES and hierarchy, with the hips' height as the one length the bank records.
  Not a figure: a clip is stored as rotations, so any figure on these names plays it.
- **A catalogue row:** `id`, the source file and its original name, frames, fps, duration, the root's travel (metres per second
  horizontally, and its height range: a jump, a crouch), whether it loops (first and last pose within a measured tolerance), the
  side that leads (for a mirror), tags (locomotion / combat / reaction / gesture / interaction / idle), and a contact sheet path.
- **Duplicates:** the same name from two files is kept once if the curves match within a tolerance, both kept (`_b`) otherwise,
  reported either way.
- **Review:** a contact sheet per clip (4 frames, 3/4 and side, on ONE reference figure) and an index sheet of the whole bank, so the
  Director judges by looking (`render-dont-describe`).
- **Done:** every clip of every Tripo GLB in `ASSETS/MODELS/` is in the bank, each plays on both bases with no joint flipped
  (checked on the sheets), the catalogue is complete, a re-run is byte-identical.

---

## 4. MV-2 — THE MAP: what the game needs, what the bank has, what is missing

**What:** one table, the situation catalogue the brief asked for (brief §3) crossed with the bank. Lives in this plan as §4.1 once
built. Each row:

| Column | Meaning |
|---|---|
| Situation | a game state that needs its own motion (posture × tempo × cover × weapon × stealth, and the world: pit, liquid, rope) |
| Need | the clip(s): a loop, a one-shot, an enter / exit pair, a transition |
| Have | the bank clip that serves it as is, or with processing (§5) |
| Combine | how to get it from bank clips with no generation: layers, blend, mirror, retime, a cut (§5) |
| Missing | what only a new generation gives; priced in Tripo credits |
| Priority | what the demo needs first |

**The first pass, from the bank's names alone (2026-10-27; to be checked against the clips themselves):**
- **Probably have:** `idle`, `standing_relax`, `wait`, `look_around` (idle family); `walk`, `run`, `run_upstairs`, `turn`, `jump`,
  `jump_down`, `climb`, `flee_01/02` (locomotion); `shoot`, `fire`, `box_01-03`, `front_kick_01/02`, `slash`, `chop` (combat);
  `hit_to_body_01/02`, `hit_to_head`, `hit_to_side`, `hit_to_stomach`, `fall`, `dive`, `defeat_02/03` (reactions); `sit`, `dig`,
  `lift_heavy`, `swim`, `press-up`, `make_a_call_02` (interactions); a set of gestures and emotions for the cast (`agree`, `bow`,
  `greet_*`, `laugh_*`, `angry_*`, `scared_*`, `afraid`, `frightened`, `fold_arms`, `complain_*`, `frustrated_*`, `depressed`, `cheer`).
- **Missing, the stealth core (the credits' priority, Claude's proposal):** (1) a crouched / sneaking walk (M1; the old male model
  had "Caminhar apressado furtivamente", not in the new 66); (2) wall cover: press against it, peek, fire from it, and the
  multi-segment cover → run → cover take of §2 (M2, M3); (3) a takedown from behind; (4) a grenade throw (`pitch_baseball` is a stand-in);
  (5) crawl (M5) and the one-knee crouch (M4); (6) rope and hook. Equip / holster / reload / aim-idle per weapon class are likely
  missing too.

### 4.1 The map (v1.1, 2026-10-28) — BY NAME, to confirm on the bank's sheets (MV-1)

**Every "Have" below was matched on the clip's NAME only; no motion was looked at.** A row moves from BY NAME to HAVE when its
sheet (§3) shows the motion fits. Sources: `MaleCharacterNoCoat.glb` (66 clips, plain names), `MaleCharacterHatAndCoat.glb` (three
custom stealth takes, names truncated by the exporter; written here as **S1** "Caminhar apressado furtivamente", **S2** "Correr
furtivamente segurando uma pistola apontada para baixo e…", **S3** "Walking briskly and stealthily, holding a pistol with both
hand…"), `female+no+coat.glb` (`dive`, `fall`, duplicates of the male's: §3's duplicate rule). Correction to §4's first pass: the
stealth walk was NOT lost, S1-S3 are in the coat-and-hat file. Every locomotion clip also gets §5.1 (root motion out) and §5.2 (tempo);
the Combine column names only what comes on top. Priority: **P0** = the demo cannot ship without it, **P1** = the demo is poorer
without it, **P2** = after the demo. Priorities are Claude's proposal, for the Director to rank (§10's done line).

#### Locomotion on the grid (D44 four facings, D47 snap, D61 0.56 s / GU)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Walk, open ground | loop | `walk` | loop cut (§5.3) | — | P0 |
| Run (hurried, chase) | loop | `run`, `flee_01/02` (panic run, guards / civilians) | loop cut; tempo from design | — | P0 |
| Start / stop a move | enter / exit | — | snap (D47) from idle; author only if the snap reads badly | maybe a stop, judged blind | P2 |
| Facing change | snap | `turn` (in place) | D47 says snap: `turn` only for an idle actor turning without a step, if ever | — | P2 |
| Stairs (up / down) | loop | `run_upstairs` | down = ? (reverse plays badly on stairs) | walk up / down stairs, if the maps keep stairs (single plane canon: question 6) | P2 |
| Step down into a pit / climb out (brief §7a.1) | one-shot each | `jump_down`, `climb` | retime to the depth; threshold open | — until §7a.1's depth rule is set | P2 |
| Jump a gap | one-shot | `jump` | — | — | P2 |

#### Stealth (M1, the LED cloak D72, styles D70)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Sneak walk, no weapon out (M1) | loop | **S1** | loop cut; head scan as an additive (§5.6) if S1 has none | — if S1 is hunched enough | P0 |
| Sneak, pistol down two hands (M1, brief §6.5 item 5) | loop | **S3** (walk), **S2** (run) | S2 / S3 upper body over S1's legs gives "sneak + weapon" at every tempo (§5.6) | — | P0 |
| Look around while standing (M1 scanning) | additive / loop | `look_around` | head / neck-only mask as an additive on any idle or move | — | P1 |
| Crouch, no wall (M4: one knee, hand on the fingertips) | enter / loop / exit | — | — | the M4 pose as a hold + down / up | P1 |
| Crouched move | loop | — | — | a crouch walk (half cover's transit, §8.2) | P1 |
| Crawl / prone (M5, minimal cover §8.2) | enter / loop / exit | `dive` (a way down?) | `dive` cut to its landing as the enter, if it lands prone | crawl loop, get up (1 AP and a pin, §8.2) | P1 |
| Cloak on / off (D72, 1 AP each, standing still) | one-shot each + held still | `idle` underneath | the cloak is a shader on a still figure; the switch may be a gesture layer | a small "activate" gesture, if wanted (question 4) | P1 |
| Style swap normal ↔ black (D70: the pack takes the coat, gloves on) | one-shot each way | — | — | both directions (D70's two-way rule; brief §6.5) | P1 |
| Mask on / off (D71: hat forward, plates rise) | one-shot each way | — | upper-body layer over any idle | both directions | P2 |

#### Cover (`DESIGN` §8.2-§8.4; M2, M3)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Full cover against a wall (M2) | enter / loop / exit | — | mirror for the other side (§5.4) | pressed-to-wall hold, in and out | P0 |
| Corner cover (M3, Wolfenstein) | enter / loop / exit | — | mirror (§5.4) | corner hold | P0 |
| Peek and fire from full cover (§8.3) | enter / one-shot / exit | `shoot` (upper body) | `shoot` masked over a lean-out pose | the lean-out | P0 |
| Cover → run → cover (§2: one take, cut) | one multi-segment take | — | cut into enter / run / exit and chained (§5.5) | the one take, both sides by mirror | P0 |
| Half cover, crouched behind a low object (§8.2) | enter / loop / exit | — | could reuse M4 (question 3) | a crouch-behind hold | P1 |
| Fire from half cover | one-shot | `shoot` | upper body over the crouch hold | — if the mask holds | P1 |
| Fire from prone (50 % aim, §8.2) | one-shot | — | — | prone fire | P2 |

#### Weapon flow (brief §6.5: select, aim, fire, return, cancel; `WEAPON` classes)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Draw / holster, pistol (both ways) | one-shot each | — | holster = draw reversed only if it reads right (the grenade's cancel does this today) | draw, holster | P0 |
| Draw / holster, long gun (shotgun) | one-shot each | — | — | draw, holster | P1 |
| Aim, held while the hit chances are computed (brief §6.5 item 3) | loop | `shoot` (first frames?) | cut its aim frames into a held loop + breathing additive | an aim idle, if `shoot` has no clean hold | P0 |
| Fire with recoil | one-shot | `shoot`, `fire` | upper-body mask so it plays standing, crouched, in cover | — | P0 |
| Alert rest, weapon up (in cover) / down (moving) | loop | **S2** / **S3** (down) | their upper body over idle | weapon-up rest | P1 |
| Reload | one-shot | — | upper-body layer | reload per class | P2 |
| Grenade: raise, throw, cancel (exists today on the old rig) | one-shot ×3 | `pitch_baseball` (stand-in, §4) | cancel = raise reversed (today's `play_throw_cancel`) | an overhand / lob grenade throw | P0 |
| Throw a stone (distraction, `DESIGN` §5.4) | one-shot | `pitch_baseball` | shorter, underhand if possible: retime / cut | a lob (could share the grenade's) | P1 |
| Dart launcher (knockout at range) | one-shot | `shoot` | as the pistol | — | P2 |
| Place C4 / set the alarm clock (`DESIGN` §5.4) | one-shot | `dig` (crouch and work?) | cut a short kneel-and-place | a place-on-floor / on-wall | P2 |
| Melee: chokehold (knockout), neck snap (`DESIGN` §10, the knockout every class must hold) | paired one-shot (agent + guard) | `box_01-03`, `front_kick_01/02`, `slash`, `chop` (none is from behind) | — | **the takedown from behind, paired** | P0 |

#### Reactions

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Hit (body / head / side / stomach) | one-shot | `hit_to_body_01/02`, `hit_to_head`, `hit_to_side`, `hit_to_stomach` | additive flinch over any pose (§5.6); mirror for the other side | — | P1 |
| Death / knocked down | one-shot + held | `defeat_02/03`, `fall` | hold the last frame as the body (it is minimal cover, §8.4) | a death from cover / prone | P1 |
| Knocked out, then waking after N turns (`DESIGN` §10) | one-shot + loop + one-shot | `fall` | hold; reverse to get up? | wake up / get up | P1 |
| Surprised / startled guard (PATROL → SUSPICIOUS, AI FSM) | one-shot | `afraid`, `frightened`, `scared_01/02` | cut to a short start | — | P1 |
| On fire (brief §7a.3) | loop | `flee_01/02`, `freaky`? | + the status tint already built | patting down / running to water | P2 |
| Smoke / gas (gas bomb knocks out, 2 turns) | one-shot + held | `fall` | — | coughing | P2 |

#### The world (brief §7a)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Rope and hook: throw, cross, land (`DESIGN` §10.0) | one-shot ×3 | `pitch_baseball` (throw), `climb` | cut `climb` for the cross; the rope is a mesh | the hand-over-hand cross, the hook throw | P1 |
| Perches: climb up, watch, swing, drop onto a guard | several | `climb`, `jump_down` | — | swing, the drop takedown (paired) | P2 (later, by the canon) |
| Wading (legs under the surface) | loop | `walk` | slower retime + the surface clips the legs | — maybe | P2 |
| Quicksand: sinking, the 2 AP escape | loop + one-shot | — | — | struggle, pull out | P2 |
| Slipping on ice / oil | one-shot | `fall` | cut the slip | a slip-and-recover | P2 |
| Swimming (`MATERIALS` F9) | loop | `swim` | — | — | P2 |

#### Interactions

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Open a door / use a switch, a valve (`DESIGN` §5.4 scenery) | one-shot | — | — | a reach-and-turn | P1 |
| Pick up an item / search a knocked-out guard | one-shot | `lift_heavy` (too heavy?), `dig` | cut a crouch-reach | a pick-up, a search-the-body | P1 |
| Drag / carry a body | loop | `lift_heavy` (the lift only) | — | drag loop (question 5) | P2 |
| Knock an object over (a distraction) | one-shot | `front_kick_01` | cut | — maybe | P2 |
| Lockpick (`DESIGN` evidence room) | loop | — | — | a kneel-and-pick | P2 |
| Phone (the phone cloner; a guard's radio) | loop | `make_a_call_02` | upper body only | — | P2 |
| Sit (civilians, guards on a break) | enter / loop | `sit` | — | — | P2 |

#### Idle

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Agent idle (brief §6.4) | loop | `idle`, `wait` | loop cut; breathing additive | — | P0 |
| Guard idle on post / patrol pause (AI PATROL) | loop | `standing_relax`, `idle`, `fold_arms`, `scratch` | variety by picking a different one per guard | — | P0 |
| Guard searching (SEARCH, SUSPICIOUS) | loop | `look_around` | over a slow walk (upper body) | — | P1 |
| Guard alert, weapon raised (ALERT, CHASE) | loop | — | S3's upper body? (it is the agent's two-hand pistol) | an alert idle with a weapon | P1 |
| Civilians idle (crowd sets, `COSMETICS` §8) | loops | `play_video_game`, `warm_up`, `press-up`, `standing_relax`, `make_a_call_02` | variety | — | P2 |

#### Cast gestures (NPCs, the cutscene-free dialogue of `DESIGN` §2.3)

| Situation | Need | Have (BY NAME) | Combine | Missing | Priority |
|---|---|---|---|---|---|
| Agree, greet, bow | one-shot | `agree`, `greet_01-04`, `bow` | upper body over idle | a "no" (disagree) | P2 |
| Anger, complaint, frustration | one-shot | `angry_01-03`, `complain_01/02`, `frustrated_01/02` | — | — | P2 |
| Joy, fear, sadness | one-shot | `laugh_01/02`, `cheer`, `scared_01/02`, `afraid`, `depressed`, `defeat_02/03` | — | — | P2 |
| Civilian flees and trips the alarm (AI table) | loop | `flee_01/02` | — | — | P1 |
| Unassigned (no situation yet) | — | `cast_a_spell`, `flip`, `freaky`, `dig` beyond its uses above | kept in the bank, unused | — | — |

#### Credits: what to generate first (Claude's ranking, for the Director)

1. **The cover take** (§2's ruling): wall press → lean out and fire → back → run → corner, one multi-segment take, cut and mirrored.
   One generation serves four P0 rows (full cover, corner, peek, cover → run → cover).
2. **The takedown from behind, paired** (agent + guard as one take): the non-lethal option every class must hold; nothing in the bank
   comes close.
3. **Draw / holster, pistol**, plus an aim hold if `shoot` has none: the whole §6.5 flow hangs on it.
4. **The grenade throw** (overhand, with a lob variant that also serves the stone): replaces `pitch_baseball`.
5. **Crouch (M4) with crouch walk, and prone / crawl (M5) with get up**: half and minimal cover.
6. **Style swap (D70) and the knocked-out guard waking up.**
7. **Interactions**: door / valve, pick up / search a body.
8. **Rope and hook** (throw, cross), then the world rows.

Before spending on 1-5: confirm S1-S3 on their sheets. If S1 is not hunched enough for M1, a sneak walk goes to the top of this list.

#### Open questions for the Director (nothing here is decided)

1. **This ranking**: is the stealth core (cover, takedown, weapon flow) the demo's first, as proposed, and P0 / P1 / P2 right per row?
2. **One figure's clips for both sexes and the guards?** The rig allows it (§1.3); is a female walk / run a separate generation, or
   does the female share the male's clips?
3. **Half cover and M4:** is the crouched-behind-a-low-object pose the same as M4 (one knee, hand on the fingertips), or its own?
4. **The cloak (D72) and the style swap (D70):** does switching on the cloak have a visible gesture, or only the shader? Is the
   style swap a full-body take (the pack absorbs the coat) or an upper-body layer?
5. **Bodies:** can the agent drag / carry a knocked-out guard? (It decides a loop and its AP cost; `DESIGN` does not say.)
6. **Stairs:** do the maps keep walkable stairs on the one playable plane, or is `run_upstairs` a cast clip only?
7. **Guards' weapon poses:** do guards draw / holster as the agent does (brief §6.5's two-way rule), or start ALERT with the weapon
   already up?
8. **The pit threshold (brief §7a.1):** from what depth is a step down a drop (`jump_down`) and a step up a climb (`climb`)?
9. **Unassigned clips** (`cast_a_spell`, `flip`, `freaky`): keep for the cast, or drop from the bank?

---

## 5. MV-3 — making a clip GAME-READY (the processing, all in our code)

Each item is a transform on a bank clip; the bank keeps the raw clip, the game uses the processed one (so a better rule re-runs).

1. **Root motion stripped:** Tripo bakes the travel in the Hips (D85: the run goes 3 m in 1.29 s). The engine moves the actor (D61);
   the clip keeps the Hips' vertical motion and loses the horizontal, and its measured speed is recorded (it decides the playback
   rate on the grid).
2. **Step timing (D61):** a locomotion loop is retimed so its stride lands on 0.56 s per GU (walk); run and sneak get their own
   tempo from the design, never from the clip.
3. **Loops:** the cut points chosen where the pose repeats (measured), and a short cross-fade where it does not.
4. **Mirror:** left / right by the Mixamo names (`Left*` ↔ `Right*`); doubles every asymmetric pose (a corner on either side, M3).
5. **Cut and chain:** one long take cut into enter / loop / exit pieces, chained by the engine (the cover take of §2).
6. **Layers:** lower body from one clip, upper body from another, by bone mask (walk + aim, run + weapon down, idle + reload);
   additive layers for small overlays (breathing, a flinch, looking around: M1's scanning head may be an additive, not a clip).
7. **Transitions:** D47's default is snap; a transition is authored only where the Director judges a snap bad, blind (the D47
   method).

---

## 6. MV-4 — the engine plays the bank

- **`ActorMesh3D` on the Mixamo rig:** bone names (`mixamorig:Head`, `mixamorig:RightHand`, `mixamorig:LeftHand` replace `head`,
  `hand_R`, `hand_L`), the weapon and hand attachments, the head turn (`actor_head_turn3d.gd`), the muzzle / throw origin read from
  the real head (fixes §7a item 4 for free if it reads the posed bone, as it already does).
- **One `AnimationLibrary` built from the bank, shared by every actor** (one skeleton), loaded once.
- **An `AnimationTree` per actor:** the state machine (idle / move / cover / aim / fire / react), blend spaces for tempo, the layer
  masks of §5.6.
- **Scale and import:** the 1 m Tripo figure to the game's height (D85's import steps); the four facings and the snap (D44, D47) are
  the actor's yaw, untouched by the clip.
- **⚠️ Cost, unmeasured: 65 joints against today's 20**, on every actor, with an `AnimationTree` each. RAM is the constraint (D42),
  and the Moto g04s is the floor device (`PERFORMANCE_BUDGET` PB-0). Measure before building the state machine: N actors on the
  Mixamo rig playing a clip, on the Moto, against today's rig (`device_run.py`), uncapped (`MAX_FPS=0`). If it does not fit, the
  options are a reduced skeleton for guards (the fingers are 30 of the 65 joints) or fewer distinct clips loaded at once, and the
  Director chooses.

---

## 7. MV-5 onwards — the situations (after the map ranks them)

Built in the map's priority order; each one done = the Director has seen it on the board (a capture through `capture.py`, desktop,
HUD off) and ratified it. Expected order, to confirm on the map: locomotion on the grid (walk / run / sneak, the idle, the stop) →
cover (M2, M3) → weapon flow (§6.5 of the brief: equip, aim, fire, return, cancel) → reactions (hit, fall) → crouch and crawl (M4,
M5) → the world (pit, liquid, rope: brief §7a).

**For a clip we have to make (credits or none):** key poses first, in-betweens second (the brief's method, §2.2), now meaning: the
pose stills are agreed before a generation is spent.

---

## 8. Quality, and how it is judged

- **The bar is the Director's eye:** *"molejo"*, micro-movement, coherence with the situation (an infiltrator under threat, not a
  neutral cycle: brief §2). Tripo's clips are AI-generated whole-body motion, which is the kind of secondary motion the hand-keyed
  pass lacked; whether they reach the bar is judged on the bank's sheets, not assumed.
- **Blind comparisons** where there is a choice (the D47 / D61 method).
- **On the handset:** motion is judged at the zoom of play on a real phone video (`device_record.py`) before a situation is closed.

---

## 9. Prerequisites and open questions

1. **The model lock (brief §6.0, Director 2026-10-08).** D85 settles the SOURCE (Tripo, Mixamo) and the skeleton is shared (§1.2), so
   the bank (MV-1) and the map (MV-2) do not wait on it. What does wait: anything keyed to a figure's attachments (the weapon in the
   hand, the hat, the coat's skirt in motion). The male with coat and hat is being generated (2026-10-27).
2. **The assembly's rules on the male** (`tripo_assemble.py`, measured 2026-10-27): the forearm sleeves went to the hands, the hair to
   the hat on a hatless model, the ears to the hair, and Tripo segmented his belt as a part of its own, which the band search does
   not expect. `CHARACTER`'s work; it blocks the male's figure, not the bank.
3. **The brief's §6 "five items first"** (2026-08-16) predate the later milestones: the shot from the agent that misses into a wall is
   on the board (the `SHOT_AGENT_CELL` / `SHOT_GUARD_CELL` captures), glass, fabric and cardboard closed with `MATERIALS` (M2,
   2026-10-11; soft materials 2026-10-17). The enemy variant: to confirm against the guards' current look. None blocks the bank.
4. **How much of the catalogue is a layer, not a clip** (§5.6). M1's scanning head, the weapon held down while running, breathing:
   each one that works as an overlay saves a clip on every tempo.
5. **Can the numbers be computed without disturbing the animation** (brief §7 item 6: the prediction on a worker): stands.
6. **The cost of 65 joints on the Moto** (§6): the first measurement of MV-4.

---

## 10. Stages

| Stage | Deliverable | Done when |
|---|---|---|
| **MV-1** | The bank: `tripo_anim_bank.py`, `ASSETS/ANIMATIONS/bank/`, `bank.json`, the sheets | §3's done line |
| **MV-2** | The map (§4.1): need / have / combine / missing / priority; the credits list | 🟡 **v1.1 (2026-10-28): §4.1 written, BY NAME (clips not yet seen); waits on the Director's ranking and §4.1's open questions** — done when the Director ranks it |
| **MV-3** | The processing (§5) on the first situations' clips | each processed clip judged on a sheet |
| **MV-4** | The engine plays the bank (§6), the Moto measured first | an actor walks the grid on the Mixamo rig at D61's step, measured on the Moto |
| **MV-5+** | The situations in the map's order (§7) | each ratified on the board and on a handset video |
