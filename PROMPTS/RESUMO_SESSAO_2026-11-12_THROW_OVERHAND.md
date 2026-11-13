# Session record — 2026-11-12 (evening): the grenade throw, studied and built standing overhand

- **Study:** `PROMPTS/THROW_STUDY_2026-11-12.md`. It covers how XCOM, Phoenix Point, MGSV, CS2, Men of War II and the army throw;
  four styles x four postures; rules T1–T7; `pitch_baseball` measured and cut. All four questions are ruled:
  - the right hand (a drawn pistol is put away first);
  - the style is automatic, shown in the preview;
  - the whole body turns;
  - the bowl is a low toss that lands and rolls.
- **Flow in play (ruled, §5.1):**
  1. idle → cocked, held;
  2. the body turns in place to the aimed cell while aiming;
  3. the throw continues from the cocked pose;
  4. the cancel plays the raise backwards.
- **Timeline:** `SEQ_throw_overhand_<FIG>.blend`, built by `pose_lab.py throw_new`.
  - The clip is turned so the line hips → hand at the release runs along the forward. The first pass used the hand's velocity: 45° off,
    seen by the Director.
  - The legs are solved by IK to a planted side-on stance; the fingers are at the idle.
  - The coat keys are `ThrowFix_f09/12/15/18`, pre-keyed, and one of them is left ACTIVE.
  - Trap: the male's first coat edit went into the stale active `DrawFix`. It was moved to `f12/f15/f18`.
- **In the game:**
  - `ActorMesh3D._update_throw` (a second path layer), `ActorPose.throw_aim_dir`, `Agent.grenade_release_points()`.
  - The flight starts from the hand; the male's ThrowFix morphs are in `AGENT_MALE_LIGHT.glb`.
  - `verify.py` smoke green; take `grenade_throw` filmed on both figures.
- **Next session:** the female's skirt (her ThrowFix keys are empty); then underhand, bowl, kneeling. The preview arc still starts at the
  head anchor (W5).
