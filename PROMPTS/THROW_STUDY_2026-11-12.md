# The throw on the Tripo figure: a study before building (2026-11-12)

> **Director, 2026-11-12:** *"Pega as partes úteis e vamos criar nossa própria versão. Uma base boa das pernas também ajudaria. A gente vai
> precisar de outros tipos de throw, por exemplo estando agachado, encostado no cover, por cima da cabeça, ou por baixo quando o alvo for
> perto, como uma jogada de bocha, ou mesmo boliche. Antes de começar, vamos dar uma estudada nas possibilidades principais, e ver como
> outros games lidam com granadas, especialmente XCOM e Phoenix Point."* And: **fingers are never keyed; a throw goes down to the palms**
> (the hand bone turns, its finger joints stay as the idle has them).
>
> Status: STUDY; §6's four questions RULED the same day (right hand, automatic style, whole body turns, bowl = low toss and roll). Owner plan: `MOVEMENT_MASTER_PLAN` §7 (a situation of the weapon flow). The flight in the world is
> HERITAGE T2 W5, parked into `docs/production/milestones.md` GAMEPLAY-01; this study says what the animation needs from it.

---

## 1. What exists today

**The game's throw** (`GrenadeController`, `ActorPose`, `Agent`):

- AIM MODE picks a cell within `throw_range_gu` = 7, minus a posture penalty (standing 0, crouching 2, prone 4) plus a skill bonus. The
  preview arc and the flight are ONE parabola (`ThrowArcOverlay`), still in **2D screen pixels**, from `Agent.throw_origin()` (the head
  anchor, not the hand).
- The flight lasts `throw_duration_s` = **0.6 s whatever the distance**, then a hop, a roll forward and back, a 1 s fuse.
- The body: `raise` (held while aiming), `release` (the grenade leaves at `THROW_RELEASE_FRACTION` = 0.5 of the old bake's keys, via the
  `throw_released` signal), cancel = the raise played backwards. **Standing only.** The old rig held the grenade in the LEFT hand
  (`hand_L`).
- **The Tripo Agent stands through all of it** (`ActorMesh3D` header: "the throw ... a Tripo actor stands through it; the throw still
  releases on the sprite's clock").

**The bank** (`ASSETS/ANIMATIONS/bank/`, both figures):

| Clip | What it gives a throw |
|---|---|
| `pitch_baseball` (3.8 s, 92 frames at 24 fps) | the only throwing arm in the bank (right-handed, overhand) |
| `dig` | a kneel on one knee, held: the leg base of a KNEELING throw |
| `volleyball` | a wide, bent-knee stance with both arms swinging low: a leg base and a reference for an UNDERHAND swing |
| `lift_heavy`, `dive` | a squat; a way down to prone (a prone base, if one is needed) |

`football_pass` is a kick and `basketball_shot` a jump shot: not throws we can use.

**`pitch_baseball` measured** (1 m Tripo figure, so the numbers are fractions of the figure's height; male and female agree within 2 cm):

| Time | Frames | What happens | Use |
|---|---|---|---|
| 0.00–0.50 s | 0–12 | the set: hands together at the chest, a small rock back | cut |
| 0.50–1.38 s | 12–33 | the pitcher's knee lift (lead knee to 0.46 of the height) | **cut**: the theatrical part |
| 1.50 s | 36 | the stride lands: lead foot 0.31 ahead | legs, shortened |
| 1.62 s | 39 | **cocked**: arms spread, throwing hand back at shoulder height | the raise's held pose (reworked, §4) |
| 1.75 s | 42 | throwing arm straight up over the head | too straight: a grenade throw bends the elbow behind the head |
| **1.83 s** | **44** | **release**: the hand's top speed, 7.3 m/s (male) / 6.8 (female), on the 1 m figure | the release frame |
| 2.00 s | 48 | follow-through, chest over the lead knee | kept, less deep |
| 2.00–3.80 s | 48–91 | the lunge HELD: hips 11 % of the height lower than standing, for 1.8 s | **cut** |

So the throw itself is **0.25 s from cocked to release, 0.4 s to the follow-through**: fast and usable. Everything before it (1.5 s)
and after it (1.8 s) is baseball.

---

## 2. How other games throw, and what goes wrong

Sourced where a source exists (end of the file); the rest is marked as recollection and should not be cited as fact.

- **XCOM (Enemy Unknown / XCOM 2).** One throw: the target is a cell, the soldier plays a stock throw and the grenade follows a precomputed
  path. What players report:
  - the EXALT Medic's smoke throw plays **the short toss whatever the distance** (the wiki calls it a cosmetic glitch);
  - grenades **appear to fly through floors and ceilings**, and nobody can say whether it is the line of sight or the animation;
  - the **camera misses the flight**: the explosion lands before the view arrives;
  - the target **snaps to a tile** and misses what the player meant.
- **Phoenix Point.** Grenades follow **accuracy rules like a shot**: the landing is not guaranteed and the grenade can **hit an obstacle
  near the thrower**. Players found a Heavy killing himself with his own grenade, with **no warning that the throw was unsafe**. Patch
  1.6.1 (2020) "fixed some animation issues when throwing grenades"; earlier, an infinite throw-animation loop was reported.
  *Recollection, not verified:* the throw is a stock overhand from an over-the-shoulder free-aim camera; the arm and the flight do not
  always agree.
- **Metal Gear Solid V.** Overhand for distance, **underhand at short range**. Players call the switch unreliable ("a broken mechanic",
  "most people just throw overhand"): the player could not predict which throw would come out.
- **Counter-Strike 2.** Three strengths on the mouse: left = long overhand, right = **short underhand** (drops near the feet), both = the
  middle. Six Days in Fallujah has the same overhand / underhand split.
- **Men of War II (GEM engine).** The **throw TYPE is chosen first, by rules**, from the cover the thrower is in, the range and the item:
  `forward` (overarm), `side` (sidearm), `force`, `mega`, in range bands (light frags: 0–5 forward, 5–10 side, 10–20 force, beyond mega).
  **The animation is picked afterwards** from type × posture (`lie_throw_grenade_1_begin` for a forceful throw lying down). Of everything
  found, this is the model closest to ours.
- **The army** (US manuals, older FM 23-30 era): standing (the natural one), **kneeling (less range)**, prone-to-kneeling, prone-to-standing,
  **alternate prone (less range and less accuracy)**; underhand and sidearm are practised because they are used in combat.
- **Engine practice** (forum and project specs, no GDC talk found):
  - spawn the projectile from the **posed hand on the frame the release marker is CROSSED**, not matched exactly;
  - hide the held grenade on that same frame;
  - a hand socket that rotates through the swing skews a velocity taken from it;
  - a typical overarm lob releases about 0.34 s after the start.

**The "horribly thrown" grenades come from five causes:**

1. one animation for every distance;
2. the grenade leaving from somewhere the hand is not;
3. an arc that ignores the ceiling or the thrower's own cover;
4. a throw style the player cannot predict;
5. a body that does not face where the grenade goes.

---

## 3. Rules proposed for ours (to rule)

- **T1. The trajectory picks the animation, never the reverse.** The solver first chooses a STYLE from posture, cover, distance and the
  headroom over the path (§4); the body plays that style. Men of War's order, which avoids XCOM's one-toss-for-everything.
- **T2. The grenade leaves the hand.** The flight starts at the posed right hand on the release frame (crossing, as the pistol's muzzle
  does since W4); the held grenade hides that frame. Today's start, the 2D head anchor, goes. This needs W5's flight in the world, or at
  least its start point taken from the hand, the way `muzzle_points()` already works.
- **T3. The arc fits the room.**
  - Indoors, the headroom under the ceiling caps the apex: a low ceiling turns a lob into an underhand toss, or a roll.
  - The path is tested against the thrower's own cover and the walls before it is offered, so no Phoenix Point self-kill.
- **T4. Deterministic and shown.**
  - The preview names the style it will throw (an icon and the arc's shape).
  - No random switch: the MGSV complaint.
  - Inaccuracy, if gameplay wants it, stays the 2 GU dome we already draw.
- **T5. The body faces the grenade.** The four facings (D44, D47) stay for movement. During a throw the whole figure turns to the throw's
  exact yaw (the mesh can take any yaw, rotation is camera-only) and snaps back after. The alternative, a spine twist of up to 45°, reads
  worse on a long throw.
- **T6. The flight time follows the distance.** Today's fixed 0.6 s makes a 1 GU toss as slow as a 7 GU lob. The time should come from the
  arc: a toss is quick, a lob hangs.
- **T7. Fingers are never keyed.** The hand bone turns, the fingers keep the idle's curl, and the grenade rides the right hand bone (the
  pistol's `BoneAttachment3D` way).

---

## 4. The throws: styles × postures

**Styles** (what the arm does, chosen by the solver):

| Style | Arc | When | Reference |
|---|---|---|---|
| **OVERHAND LOB** ("por cima da cabeça") | high | mid to long range, over cover, outdoors or high ceilings | `pitch_baseball` 36–48, reworked |
| **UNDERHAND TOSS** ("bocha") | low, short | close (≤ ~3 GU), low ceilings, a precise drop | in-house, `volleyball`'s swing as reference |
| **BOWL / ROLL** ("boliche") | on the floor | a clear floor line: through a doorway, under a vehicle, into a room | in-house, the toss's legs, lower |
| **SIDEARM** | flat, short | around a corner from FULL cover, without stepping out | in-house (army practice, Men of War's `side`) |

**Postures** (what the legs do), from `DESIGN` §8.2's cover states:

| Posture | Overhand | Underhand | Bowl | Sidearm | Leg base |
|---|---|---|---|---|---|
| Standing, no cover | ✅ first | ✅ | ✅ | — | the pitch's stride, shortened |
| Crouched / half cover | ✅ rises to a kneel to clear the cover | ✅ | ✅ (natural: already low) | — | `dig`'s kneel |
| Prone (minimal) | ⚠️ alternate prone: range and aim penalised (the posture penalty exists) | — | ✅ a push along the floor | — | `dive`'s end / in-house |
| At a wall (full cover) | ✅ steps out, throws, steps back (XCOM's peek) | — | — | ✅ around the corner | the peek (§8.3, not built) |

**Proposed order:**

1. standing overhand (the pitch's arm, our legs);
2. standing underhand;
3. bowl;
4. kneeling overhand and underhand;
5. the cover variants, when cover exists;
6. prone last.

Each lands on both figures before the next (the standing rule), and the same arm data serves several postures: the arm is a layer over the
legs, as the pistol's aim already is.

---

## 5. The standing overhand from the pitch: what to keep, what to make

- **Keep** the arm and torso path of frames 36→48 (cocked → release → follow), retimed by the game, not by the clip.
- **Remake:**
  - the cocked pose: the elbow bent behind the head, not the straight arm of frame 42;
  - the legs: one short lead step (the clip's 0.31 of the height is a pitcher's stride; a third of it reads as a throw);
  - the hips' dip, held to about a third of the clip's 11 %;
  - no held lunge; a return to the idle.
- **Proposed timing**, measured on the clip and rounded:
  - raise 0.35 s to the cocked hold (held while the player aims);
  - cocked → release 0.25 s, with the release frame emitting `throw_released`;
  - follow 0.15 s;
  - back to idle 0.35 s.
- **How:** the same way as the pistol draw. The poses are solved or cut from the clip, then refined by the Director in a `SEQ_throw_...`
  timeline in Blender, then read back by `pose_lab.py sequence`. Fingers stay off the keys.

---

### 5.1 The flow in play (Director, 2026-11-12, RULED)

1. **Idle → cocked**, played once, then a PAUSE at the cocked pose (the raise held, as `ActorPose`'s `raise` already holds).
2. **While aiming**, the Agent TURNS IN PLACE (a horizontal yaw, the arm still raised) to face the GU the grenade is aimed at: the hovered
   cell on desktop, the first tap on a phone. This is T5's whole-body turn, done during the aim, not at the release.
3. **On "throw"** the Agent already faces the target and simply plays the rest: cocked → release → follow → idle.
4. **On cancel**, cocked → idle played backwards (the existing cancel rule).

**One timeline** (`SEQ_throw_overhand_<FIG>.blend`; split in two and joined again the same day, so the coat is fixed once): idle 1, cocked 9
(held in play), in-between 12, release 15, follow 18, idle 26; the grenade hides from 16. **The coat has keyframes on the same timeline**
(Director's question): one shape key per pose, `ThrowFix_f09/12/15/18`, created empty and pre-keyed 1 on its frame and 0 on the poses
around it; fixing the coat at a pose = select that key and edit. The game reads each as a morph with its curve (to build at the read-back).

So the timeline's THROW DIRECTION must be the figure's forward: since 2026-11-12 (second pass) the clip is turned so the line from the
hips to the hand at the release runs along the forward (the first pass used the hand's velocity there, which crosses the body: the
grenade went ~45° off the facing, seen by the Director in Blender).

## 6. Open questions for the Director

1. ✅ **RULED (Director, 2026-11-12: "Guarda e usa a direita"): the RIGHT hand, always.** With the pistol drawn, the Agent holsters it first
   (the draw timeline played back, as quick as the draw), then throws right-handed. The old rig's left-hand grenade (`hand_L`) retires with it.
2. ✅ **RULED (Director, 2026-11-12: "Automático"): the style is AUTOMATIC** (T1): the solver picks it from posture, cover, distance and
   headroom, deterministically, and the preview shows which style will be thrown (T4). No player buttons.
3. ✅ **RULED (Director, 2026-11-12: "Corpo inteiro"): the WHOLE BODY turns** to the throw's exact yaw for the throw (T5) and snaps back to
   its grid facing after; the four facings stay for movement.
4. ✅ **RULED (Director, 2026-11-12: "Lance baixo e rola"): the bowl is a LOW toss that lands short and rolls** the rest of the way
   (the existing hop-and-roll, lengthened), not a grenade on the floor from the hand.

---

## Sources

- XCOM: [XCOM wiki, Smoke Grenade (EXALT Medic short toss)](https://xcom.fandom.com/wiki/Smoke_Grenade)
  · [Steam, "LoS and grenade throwing through the floor"](https://steamcommunity.com/app/268500/discussions/0/412446292763781234/)
  · [Steam Workshop comment, camera misses the flight](https://steamcommunity.com/workshop/filedetails/discussion/620600092/412447613569593454)
- Phoenix Point: [Steam, "Free Aim is a terrible gimmick"](https://steamcommunity.com/app/839770/discussions/0/2992044576657744396/)
  · [Cthulhu update and hotfix notes](https://phoenixpoint.info/blog/2020/8/4/cthulhu-update-and-hotfix-julyaugust-2020)
  · [Snapshot forums, infinite grenade throw animation](https://forums.snapshotgames.com/t/infinite-grenade-throw-animation/6666)
- MGSV: [Steam discussion](https://steamcommunity.com/app/287700/discussions/0/523897023727420762)
  · [Steam discussion](https://steamcommunity.com/app/287700/discussions/0/527274088401349372)
- Counter-Strike 2: [csdb.gg grenade guide](https://csdb.gg/guides/grenade-guide/)
  · [Dignitas, the ways to throw a grenade](https://dignitas.gg/articles/the-5-different-ways-to-throw-a-grenade)
- Six Days in Fallujah: [Steam discussion](https://steamcommunity.com/app/1548850/discussions/0/3808404963064100020)
- Men of War II: [GEM docs, grenade throw type selection](https://docs.bestway.com.ua/animation/animation-system-for-actor/animation-selection-setup/grenade-throw-type-selection)
- Army: [FM 3-23.30 ch. 3 (GlobalSecurity)](https://www.globalsecurity.org/military/library/policy/army/fm/3-23-30/ch3.htm)
  · [Army Study Guide, throwing of hand grenades](https://www.armystudyguide.com/content/army_board_study_guide_topics/hand_grenades/throwing-of-hand-grenades.shtml)
- Engine practice: [Unreal forums, correcting the throw direction](https://forums.unrealengine.com/t/grenade-throwing-and-how-to-correct-the-throw-direction/125653)
  · [zombies-fps PR, throw release times](https://github.com/DonnGonzo/zombies-fps/pull/10)
  · [zombonz issue, duplicate grenade at release](https://github.com/je55pr/zombonz/issues/177)

---

## 7. In the game (2026-11-12, first build)

- **Read-back:** `pose_lab.py sequence throw_overhand --figure <fig>` (the timeline's prop is read from the file, the throw KEEPS the fingers,
  the coat's animated shape keys are sampled per frame as `morphs`, the markers are written; `release` and `follow` are passing stops).
- **The coat:** the male's `ThrowFix_f12/f15/f18` are morphs of `AGENT_MALE_LIGHT.glb` (`glb_add_morph.py`; `f09` is empty and left out).
  A rebuild of the LIGHT Agent loses them, as it loses `DrawFix`.
- **The body:** `ActorMesh3D` plays the timeline on a second path layer (`_update_throw`):
  - the raise goes at the timeline's pace and waits for a drawn pistol to be put away;
  - the hold stays at `cocked`;
  - the release goes cocked → release on the pose's clock, so `throw_released` lands on the release frame;
  - the follow and the return run at the timeline's pace;
  - the cancel plays the raise back.
- **The turn:** `ActorPose.throw_aim_dir`, set by the grenade's aim, turns the whole body in place at 360°/s. Outside a throw the facing
  still snaps (D47).
- **The flight:** it starts where the grenade last was in the hand (`Agent.grenade_release_points()`). The PREVIEW arc still starts at the
  old head anchor, until W5.
- **Take:** `grenade_throw` (PLAYGROUND, `agent_throw_rail`). Open: the female's timeline is Claude's draft (no coat fix, idle fingers). The
  "8 resources still in use at exit" line appears with the old rig too: it is the detonation still running when the take quits, not this
  work.
