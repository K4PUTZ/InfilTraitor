# Session record 2026-11-05/06 — the female's skull, into the base (ACTOR D106 step 2)

**Done.**
- Tripo modelled the female's head only where the hair hides it: a flat lid at z 0.935 and a slanted back. Scripted rebuilds (the male crown, a skull pushed to the hair) were rejected.
- The Director cut the male's head into a cap and seated it over hers by hand: `ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend` (`Body_Head_Male`).
- `tools/asset_generation/tripo/tripo_head_join.py` (bridge the cap's border to her hole): rejected — a groove at the forehead, the cheek replaced; a seam smoothing spiked the nape. Kept as a record (smoothing off).
- `tools/asset_generation/tripo/tripo_head_fuse.py` (the one used): cap (4 mm thick) + head fused by voxel remesh (1.5 mm, decimated 0.05) for the skull; her ORIGINAL faces kept below z 0.902 (raised 2 mm on the Director's word to hide the seam under the hair) with their weights and UVs; the fused part weighted from her nearest vertex; borders snapped and welded, holes filled, non-manifold cleared: 0 open, 0 non-manifold. The ears: back rim 2 mm toward the head (`HF_EAR_BACK`), tip untouched (`HF_EAR_TIP` 0: the Director preferred the original tip). Output `fit/HEAD_FUSED_FEMALE.blend`.
- The base `ASSETS/MODELS/base/AGENT_FEMALE_A.blend` now carries that head (`Body_Head`, 770 verts / 1484 faces, same object, armature, 65 groups). The pre-change copy: `temp/backup/AGENT_FEMALE_A_before_head.blend` (disposable).

**Owed.** The skull's UVs (the fused part) are redone by `tripo_head_map` when texturing. The base's GLBs (`tripo_export_base.py`) and the LIGHT trial were made from the old head.

**Next.** The hair mask under the hat cut EXACTLY at the brim's position on this head (`tripo_hair_brim_cut.py`, section along the brim), then the hat skinned to the head, the `_Coated` re-cut, the finishing steps.

## Later the same session — the hair under the hat (was an OPEN BUG; RESOLVED in the section at the end)

- `tripo_hair_brim_cut.py` now reads the CURRENT base heads and cuts along the hat's opening angle by angle (commit `ff1e4a87`): the state kept.
- The Director then saw a GAP between the brim and the cut hair at the temples / sides on both figures ("tem que subir a máscara do cabelo até encostar na aba"). Tried and REVERTED (Director: "vamos voltar um passo"): keeping hair outside the band up to the brim (it poked through the crown), a ray-from-below rule, the hat as a boolean / inside-test mask (`tripo_hair_hat_mask.py`, deleted).
- Measured on the way: Tripo's hats are CLOSED underneath (a shallow lid spans the opening, rendered from below), which every hat-based mask counts as hat; and the female's hat, seated on the OLD flat skull, opens ~1 cm wider than the new head at the sides, tilted 18° back. The Director's word: "Não é bem isso" — the right fix is still to be agreed at the start of the next session; ask before building.

## Resolved the same day (next session): the gap was a stale matrix, not the hat's geometry

The Director's brief: raise the mask a little, until it touches the brim, showing more hair and covering the bare skull at the temples.

- **Cause.** `tripo_hair_brim_cut.py` read `hat.matrix_world` right after `libraries.load` + `link`, before the scene updated. The Director's hat carries a scale of (1.07, 1.07, 1.03) that the stale matrix left out, so the cut was computed against a hat 2.5 cm lower and 7 % narrower than the one on the head (female z 0.853..0.966 read, 0.878..0.994 real; male 0.886..0.976 read, 0.913..1.005 real). The cut ran that far under the brim: the bare temples. The first pass's findings ("closed underneath", "opens ~1 cm wider", "tilted 18 degrees") were measured through the same stale matrix and are not evidence about the hat.
- **Fix 1.** `bpy.context.view_layer.update()` before the hat is read.
- **Fix 2.** The height of each sector is the hat's lowest SURFACE under the near vertices (an upward ray from under the hat), not its lowest VERTEX. Tripo's low-poly root ring leaves sectors with no vertex on it, and the lowest vertex there is a crown-wall one up to 2 cm above the brim: with fix 1 alone the male's locks stood out of the crown all round the band (188 hair vertices not covered by the hat from above; 0 with the ray).
- **Measured** (boundary vertices of the cut within 5 cm under the hat, clearance up to the hat above them): female median 20.2 mm -> 2.6 mm (p90 13.2); male 19.1 -> 4.9 mm (p90 14.7). Hair vertices not covered from above: 0 on both. Four views each in `temp/renders/d106_hair_brim_female.png` and `_male.png` (before above, after below; disposable).
- **Regenerated** `fit/HAT_CUT_FEMALE.blend` and `fit/HAT_CUT_MALE.blend` (the previous versions are the `.blend1` copies and git). **Not rebuilt:** the base's GLBs and the tools that read `Body_Hair_Hat` (`tripo_dress.py`, `tripo_lod.py`, `tripo_look.py`, ...) take the new cut at their next build.
- **Next** (unchanged): the hat skinned to the head, the `_Coated` re-cut, the finishing steps.
