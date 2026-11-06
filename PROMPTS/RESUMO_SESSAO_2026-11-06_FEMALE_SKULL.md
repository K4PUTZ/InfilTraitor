# Session record 2026-11-05/06 — the female's skull, into the base (ACTOR D106 step 2)

**Done.**
- Tripo modelled the female's head only where the hair hides it: a flat lid at z 0.935 and a slanted back. Scripted rebuilds (the male crown, a skull pushed to the hair) were rejected.
- The Director cut the male's head into a cap and seated it over hers by hand: `ASSETS/MODELS/fit/HEAD_EDIT_FEMALE.blend` (`Body_Head_Male`).
- `tools/asset_generation/tripo/tripo_head_join.py` (bridge the cap's border to her hole): rejected — a groove at the forehead, the cheek replaced; a seam smoothing spiked the nape. Kept as a record (smoothing off).
- `tools/asset_generation/tripo/tripo_head_fuse.py` (the one used): cap (4 mm thick) + head fused by voxel remesh (1.5 mm, decimated 0.05) for the skull; her ORIGINAL faces kept below z 0.902 (raised 2 mm on the Director's word to hide the seam under the hair) with their weights and UVs; the fused part weighted from her nearest vertex; borders snapped and welded, holes filled, non-manifold cleared: 0 open, 0 non-manifold. The ears: back rim 2 mm toward the head (`HF_EAR_BACK`), tip untouched (`HF_EAR_TIP` 0: the Director preferred the original tip). Output `fit/HEAD_FUSED_FEMALE.blend`.
- The base `ASSETS/MODELS/base/AGENT_FEMALE_A.blend` now carries that head (`Body_Head`, 770 verts / 1484 faces, same object, armature, 65 groups). The pre-change copy: `temp/backup/AGENT_FEMALE_A_before_head.blend` (disposable).

**Owed.** The skull's UVs (the fused part) are redone by `tripo_head_map` when texturing. The base's GLBs (`tripo_export_base.py`) and the LIGHT trial were made from the old head.

**Next.** The hair mask under the hat cut EXACTLY at the brim's position on this head (`tripo_hair_brim_cut.py`, section along the brim), then the hat skinned to the head, the `_Coated` re-cut, the finishing steps.
