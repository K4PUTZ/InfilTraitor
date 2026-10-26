# RESUMO DA SESSÃO — 2026-10-25 (later) — The form's faces, the MPFB attempt, and the demo face

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`: `0b16cb51` and this record's). Blender only; nothing in Godot.
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-25_HERO_FACE_COAT_HAT.md`.

## 1. Design rulings (Director)

- **The form is typed on the station's COMPUTER** and its photo changes as the player clicks: one face per ethnicity, all a 45-year-old man
  with a goatee, plus the equivalent women. The clerk's questions are heard (babble + words on screen); the AGE IS FIXED (45), she only
  confirms it. Recorded in `DESIGN_MASTER_PLAN` §2.2 (the form block).
- **The introduction:** the clue objects on screen (grazed helmet, the remote...) while the Agent narrates the night to the interrogator, who
  confirms ("You were alone?" "Yes."): the account feels true and paints him as a victim. `DESIGN` §2.2.
- **Eight faces per sex** (European, African / Afro-descendant, pardo / mixed Latin, East Asian, South Asian, MENA, Southeast Asian,
  Indigenous); each country's labels map onto them. `ACTOR` D81.
- **The goatee** revises D70's "no beard by default" for the Agent.
- **The demo uses the v5.2 Quaternius face as it is; the other faces come later** (closing ruling). `ACTOR` D81.

## 2. What was tried and dropped

MPFB2 2.0.18 installed (official extensions platform, checksum checked). Eight raw male presets, then one face over ~12 rounds: hair, brows
and goatee as hair-curve strands over thin underlays with drawn outlines (hairline per angle around the ear, goatee polygon hugging the
lips group), lash ribbons on a ray-cast lid margin, a gaze tilt, jaw / ear-base / ear-pin / orbit / deep-set warps, a Cycles portrait test,
then a fit to a composite face the Director assembled from several actors. Verdict: "cada vez pior". The same proportions applied to the
Quaternius head were also rejected ("piorou"). Scripts kept, git-ignored, in `ARCHIVE/wip/` (`mpfb_face_*`, `quat_warp_*`).

Lessons (in D81): the MPFB base reads as a mannequin without skin texture and sculpted detail, and no proportion change fixes that;
copying one real actor is a likeness risk (the composite of several is the safe form); MPFB's eye-scale target does not move the eyeball;
a sleepy eye was the eyeball centre sitting above the lid opening.

## 3. Open

- The Director may sculpt the face himself: `ARCHIVE/wip/hero_v52_face_edit.blend` (rest pose, face pieces only). An edit must be carried into
  every shape key, and eyes / brows / hair refitted, before it reaches `hero_tailor.py`.
- The eight-faces set (16 heads), the face editor, the female base: deferred.
- From the previous record, still open: re-download the Quaternius CC0 packs; v5.2 into Godot and onto a handset.
