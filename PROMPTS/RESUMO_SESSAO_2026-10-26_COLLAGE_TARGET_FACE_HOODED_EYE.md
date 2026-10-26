# RESUMO DA SESSÃO — 2026-10-25/26 — The collage question, the target face drawing, the hooded eye

**Branch:** `claude/r3d-actors-y5r8hs` (commits on `origin/main`: `3f10587b` and this record's). Blender only; nothing in Godot.
**Previous record:** `PROMPTS/RESUMO_SESSAO_2026-10-25_FACES_FORM_MPFB.md`.

## 1. Questions and rulings (Director)

- **The collage question:** could realistic models of celebrities or characters be downloaded and their parts collaged into a new head?
  Answered (recorded in `ACTOR` D81, `3f10587b`): the SOURCE fails. Each model carries its maker's copyright on the mesh and texture, plus the
  person's image rights or the studio's rights on a character. Celebrity models are at best "Editorial" (no commercial use), and none passes D57.
  The TECHNIQUE works if it is not cut-and-glue: wrap our head onto each source by landmarks (same topology, no seams), blend per region, and
  bake each source's skin detail onto our UV. Clean sources: photogrammetry of consenting people, scans of public-domain sculpture (SMK's casts
  are CC0; Three D Scans claims no copyright but states no formal licence). **No source picked.**
- **The target face:** a line drawing, `REFERENCES/Personagem/agent_face_target_2026-10-25.png` (git-ignored). Its read against v5.2 is in
  D81: volume on top, a full goatee with stubble, low straight brows, narrow deep-set eyes with bags, forehead lines, a broader face. Asked and
  **still unanswered:** was the drawing traced from a photo of a real person (D81's likeness rule)?
- **"Vamos começar pelo shape do olho":** the target is a photo crop of narrowed, hooded eyes,
  `REFERENCES/Personagem/agent_eye_target_2026-10-26.png` (git-ignored).
- **Mid-way rulings:**
  - "The previous model's lid is ok": E4, the narrowed lid with the thinned lashes.
  - "Just rotate that darker tip; those are the lashes, right?" (yes).
  - "That's a shadow; the model needs adjusting in the other views": the tail was standing off the skin.
- **Close:** "I'll try another approach tomorrow." The approach was not stated.

## 2. Built: `hooded_eyes` (`tools/asset_generation/hero/hero_tailor.py`, an opt-in FEATURE, not a default)

Run it with `hero_quick.sh TAG "hawk_nose:0.25,hooded_eyes:1"`. The opening was measured by a front ray cast of the eyeball's visible region.
The target crop was measured against its own fissure width.

| | v5.2 | target crop | `hooded_eyes` (E10) |
|---|---|---|---|
| fissure height / width | 10.2-10.8 mm / ~29 mm = 0.37 | ~0.27 | 7.6 mm / ~29 mm = 0.26 |
| upper lid above the eyeball's centre (middle column) | +2.8 mm | just above the pupil | +1.0 mm |
| lower lid below the centre | −8.0 mm | on the iris | −6.6 mm |
| iris / fissure width | ~0.52 | ~0.45 | front remapped ×0.87 (read off the renders) |
| outer corner | rises ~9° | level, the lid's exit points down | rolled 5° down; the lash tail curls 32° down |

**What the pass does**, after the face fields, on the rest mesh:

- The eyeball's centre and radius are read from the `Eyes` mesh: (±0.0338, −0.0659, 1.6986), r 14.7 mm.
- The lid skin ROLLS about the eye's axis.
- The lids ROTATE about the eyeball's centre, so they stay on it.
- The front of the eyeball is remapped in angle, so the painted iris shrinks and the sclera stretches to meet it.
- The lashes take the same move, then are thinned ×0.45 toward a smoothed root line.
- The lash tail past 11 mm from the centre curls down and lies onto the skin, 0.25 mm off it.

## 3. Findings (traps for whoever edits the eye next)

- **The pack's upper LASHES are a dark ~3 mm strip inside the `Eyebrows` mesh.** It is two 36-vertex islands, z 1.695-1.7045; the brows start
  at 1.7052. This strip IS the "eyeliner" band of v5.2, and a lid edit that skips it leaves the lashes floating.
  - Two first readings were wrong. It is not texture: sampled skin-coloured. It is not shadow: a soft key light changed nothing.
  - A ray cast that names the object hit found it.
- **The dark wedge under the outer corner is the lash strip's cast shadow**, not a skin fold. v5.2 has it too; it shows on the −x side only,
  because of the review lights. Curling the tail down without laying it on the skin made the stripe longer.
- **A hood made by pushing the skin over the lid forward** tore the lash line into a zigzag, because the skin came through the strip. Abandoned.
- **Per-column lash roots tear the strip into teeth**, because the strip leans and a tip's root sits in the next column. Use a smoothed,
  interpolated root line.
- **A skin droop at the outer corner folded the canthus.** A 2 mm falloff under ~2-3 mm of displacement gives a slope above 1, and the skin
  inverts. The Director replaced it with the lash-tail rotation alone ("you're complicating it more than it needs").
- **The `blink` key never closed the eye.** v5.2 leaves a 4.4 mm slit at the ray cast, `hooded_eyes` 2.8 mm. It also drags the brows down.
  Both are pre-existing.
- **The skin material is texture × vertex colour**, and every colour attribute is white.
- **Review scripts and receipts** (git-ignored, `ARCHIVE/wip/`):
  - `eye_render_2026-10-26.py`: front band 1500×330 at ortho 0.125, 3/4 and profile close-ups, the fissure ray cast.
  - `eye_corner_render_2026-10-26.py`: the outer corners, front / 3/4 / side.
  - `hooded_eyes_E10_vs_target_2026-10-26.png` and `hooded_eyes_E10_corner_views_2026-10-26.png`.

## 4. Open

- **Next:** the Director's other approach (not stated).
- **The eye vs the target:**
  - the brows are low on the target and the hood throws its shadow;
  - the sclera is too white (cream and shaded on the target);
  - the iris is orange (olive hazel on the target).
- **The rest of the drawing:** hair volume, goatee and stubble, brows, forehead lines, face width (D81).
- **Unanswered:** whether the drawing traces a real person's photo; the collage's source.
- **Still open from earlier records:** re-download the Quaternius CC0 packs; v5.2 into Godot and onto a handset.
