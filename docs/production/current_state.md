# INFILTRAITOR — Current Project State

<!-- AUTO:BEGIN header -->
**Version:** 0.9.107
<!-- AUTO:END header -->

> **Executive snapshot of the entire project. Where we are right now — with honesty about what works and what does not.**

---

## Where the project stands — 2026-11-25 (the characters move, the long guns are drawn, the first enemy is dressed)

- **The audit's plan is ratified and mostly closed** (`HERITAGE_AND_LOOSE_ENDS_PLAN` v0.2, 2026-11-11/12): T1, T3, T6 and T5's first part
  done, T2's W1-W3 done (W4, W5 open), T4 the storey evaluation only. **The checks follow the work left** (2026-11-12): `verify.py smoke` is
  the default, the blast / glass / shot gates and 66 selftests are parked, not deleted.
- **MOVEMENT (opened 2026-10-27), the Agent's motion on both figures:** idle (the reference frame 90), walk and run with their starts and stops,
  the dash, the crouch with its draw / shot / holster and its moves to run and walk, the pistol's whole cycle (draw, aim, shot with recoil and
  cases, holster), the overhand throw, the H1 family (14 rows, suppressors) and the projectiles (2026-11-17). **The long guns (H3, from
  2026-11-18):** drawn from under the coat's right flap, the hip and the eye-level aim, in the game on both figures (2026-11-22); the shot in
  stages (`WEAPON` D43, 2026-11-23); five H3 lab scenes, the rifles sized; the bullpup and the two stockless shotguns with draw timelines of
  their own on both figures, kept from passing through the body (2026-11-25); the snipers' scene with the head lifted to the scope, waiting
  for the Director's sizes. A model's own timeline plays in the game only at POLISH-01; until then each family plays its one body.
- **ITEMS-01 (opened 2026-11-16) and ENEMIES-01 (opened 2026-11-18):** what exists and what is missing, Tripo making the rest; the four
  factions' bare Standards approved; the first enemy, the FID's male guard, skinned on the Agent's skeleton with a head map of its own and a
  tailored uniform (2026-11-19/22). `ASSETS/MODELS/` is one folder per character (2026-11-19).
- **Not built yet:** the gameplay behind all this (AP costs and restrictions wait for GAMEPLAY-01, with confrontation, cover and resistance),
  the guard AI beyond the existing FSM, saves with slots. POLISH-01 (2026-11-17) holds the visual and sound polish: per-weapon grips and
  timelines, the coat's slivers, the foley.
- Records: `PROMPTS/RESUMO_SESSAO_2026-11-1*` and `-2*`; the newest is `PROMPTS/RESUMO_SESSAO_2026-11-22_SHOTGUN_DRAW_IN_GAME.md`.

Older sections (2026-11-10 back to 2026-08-30) and the summer status blocks (domains, percentages): [`docs/history/CURRENT_STATE_TO_2026-11-11.md`](../history/CURRENT_STATE_TO_2026-11-11.md).

---

## Project Status

### Pending Prompts

<!-- AUTO:BEGIN pending_prompts -->
- ART_ORDER_BRICK_DECALS.md
- ART_ORDER_GLASS.md
- ART_ORDER_GLASS_FRACTURE_CLASSES.md
- ART_ORDER_NEW_MATERIALS.md
- BAKE_ORDER_CHARACTER_LAYERS.md
- BAKE_ORDER_WEAPON_GRIPS.md
- D33_RUNTIME_DECAL_COMPOSITING.md
- ENGINE_PERFORMANCE_REVIEW.md
- INVESTIGACAO_EXPLOSAO_2026-08-04.md
- PLANO_PRE_FABRICATED_DAMAGE_VARIANTS.md
- PROPOSAL_METAL_WOOD_DAMAGE_VARIANTS.md
- RESUMO_SESSAO_2026-11-09_POSE_FIXES_MOTO_ROUND.md
- RESUMO_SESSAO_2026-11-10_CODE_HERITAGE_AUDIT.md
- RESUMO_SESSAO_2026-11-10_STORY_AUDIT.md
- RESUMO_SESSAO_2026-11-11_DRAW_SEQUENCE.md
- RESUMO_SESSAO_2026-11-12_HERITAGE_CLOSE_CHECKS.md
- RESUMO_SESSAO_2026-11-12_PISTOL_SHOT_CLOSED.md
- RESUMO_SESSAO_2026-11-12_THROW_OVERHAND.md
- RESUMO_SESSAO_2026-11-13_IDLE_REFERENCE_90.md
- RESUMO_SESSAO_2026-11-14_DASH.md
- RESUMO_SESSAO_2026-11-15_CROUCH_DRAW_SHOT.md
- RESUMO_SESSAO_2026-11-15_CROUCH_RUN.md
- RESUMO_SESSAO_2026-11-16_CROUCH_WALK.md
- RESUMO_SESSAO_2026-11-16_MOVEMENT_PLAN_ITEMS.md
- RESUMO_SESSAO_2026-11-17_H1_FAMILY_SUPPRESSORS.md
- RESUMO_SESSAO_2026-11-17_PROJECTILES.md
- RESUMO_SESSAO_2026-11-18_ENEMIES_OPENED.md
- RESUMO_SESSAO_2026-11-18_LONG_GUN_DRAW.md
- RESUMO_SESSAO_2026-11-20_GUARD_HEAD_MAP.md
- RESUMO_SESSAO_2026-11-21_GUARD_NECK_RELOAD.md
- RESUMO_SESSAO_2026-11-22_GUARD_UNIFORM.md
- RESUMO_SESSAO_2026-11-22_SHOTGUN_DRAW_IN_GAME.md
- THROW_STUDY_2026-11-12.md
<!-- AUTO:END pending_prompts -->

### Inventory

<!-- AUTO:BEGIN inventory -->
**Code & Test Inventory**

- GDScript modules: 257
- Test scripts: 96
- Known maps: 3
- Shipped facade files: 0
- Archived prompts: 216
<!-- AUTO:END inventory -->

### Version History

<!-- AUTO:BEGIN version_history -->
- 39e59bee ALPHA BRICK DECALS 0.9.107 - three of six parts built, and every gate that lied got fixed
- 173f21cd ALPHA MATERIALS MASTERPLAN 0.9.106 - five materials land, the milestone is planned, and half-thickness walls turn out not to exist
- 2f47876b [W-WEAPON-01/DOCS] Wood at five, the held weapon gets a seam, and the session closes
- f3731aff ALPHA MOVEMENT FOUNDATION 0.9.104 - the placeholder is gone, he walks, and there is an enemy
- a04e8c05 ALPHA MOCKUP MODEL FOUNDATION 0.9.103 - the agent stands in the room
<!-- AUTO:END version_history -->

---

