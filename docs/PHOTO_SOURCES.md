# Photographic sources for the damage decals

R3D-LOOK L1 (Director, 2026-10-05): the damage decals are to be filled with photographic material at high definition (the decal stays
256x256, ART_SPECIFICATIONS section 7). The Director edits these photos by hand and the decal generators use the result as fill, with the
mask, the hole and the cracks still drawn procedurally. **This file is the attribution record: the photos themselves live in
`ASSETS/photo_src/` (git-ignored with the rest of `ASSETS/*`; `.gdignore` keeps Godot from importing them).**

## Licence

All eight are from [ambientCG](https://ambientcg.com), released under **CC0 1.0** (public domain dedication,
<https://creativecommons.org/publicdomain/zero/1.0/>). No attribution is required; it is kept anyway "just in case" (Director). Downloaded
2026-10-05 as `<id>_2K-JPG.zip` (2048 px, JPG maps: Color, Normal GL/DX, Roughness, Displacement, AmbientOcclusion; the `.blend`, `.usdc`,
`.mtlx` and `.tres` files of each zip were deleted, a `.tres` can carry a script and nothing here reads them). Per-asset page = the link below.

| Id | Name | Released | Tags | Used for | Folder |
|---|---|---|---|---|---|
| Wood096 | [Wood 096](https://ambientcg.com/a/Wood096) | 2026-09-30 | 096, 96, beige, grain, knots, light | wood | `ASSETS/photo_src/wood/Wood096/` |
| Ground111 | [Ground 111](https://ambientcg.com/a/Ground111) | 2026-09-12 | 111, brick, brown, construction, debris, dirt | brick | `ASSETS/photo_src/brick/Ground111/` |
| Rock063 | [Rock 063](https://ambientcg.com/a/Rock063) | 2026-02-22 | 063, 63, aged, cliff, cracked, damaged | stone | `ASSETS/photo_src/stone/Rock063/` |
| Bricks097 | [Bricks 097](https://ambientcg.com/a/Bricks097) | 2024-11-22 | 97, brick, bricks, brown, damaged, dirty | brick | `ASSETS/photo_src/brick/Bricks097/` |
| Metal053C | [Metal 053 C](https://ambientcg.com/a/Metal053C) | 2024-08-10 | 53, damaged, iron, metal, old, rusted | metal | `ASSETS/photo_src/metal/Metal053C/` |
| Plaster007 | [Plaster 007](https://ambientcg.com/a/Plaster007) | 2025-04-23 | 7, broken, old, paint, plaster, wall | shared (every material: broken plaster, dust) | `ASSETS/photo_src/shared/Plaster007/` |
| Concrete044D | [Concrete 044 D](https://ambientcg.com/a/Concrete044D) | 2023-04-05 | 44, concrete, damaged | concrete | `ASSETS/photo_src/concrete/Concrete044D/` |
| Concrete036 | [Concrete 036](https://ambientcg.com/a/Concrete036) | 2021-05-16 | 36, concrete, dark, grey, old, plaster | concrete | `ASSETS/photo_src/concrete/Concrete036/` |

## Free, not CC0 (royalty-free licences, read on the site 2026-10-05)

| File | Source | Licence as stated by the site | Used for |
|---|---|---|---|
| `ASSETS/photo_src/wood/EveryTexture_00144/everytexture.com-stock-wood-texture-00144.jpg` (2448x3264, 3.5 MB) | [EveryTexture, "Wood splintered wood with chipping paint"](https://everytexture.com/everytexture-com-stock-wood-texture-00144/) | free for commercial or personal use, royalty free, no attribution; **redistribution of the image itself without written permission is prohibited** (so the photo stays out of git; a decal derived from it ships inside the game) | wood: splintered edge, chipped paint |
| `ASSETS/photo_src/metal/OGA_bullet_decal/bullet_hole_0.png` (512x512 RGBA, 334 KB) and `bulletholepriv_0.png` (1011x588 RGBA, 940 KB, looks like the author's preview) | [OpenGameArt, "Bullet Decal"](https://opengameart.org/content/bullet-decal) by musdasch, 2020-11-07 | **CC0** (stated on the page) | metal (and any wall): a painted bullet hole with soot and a bright rim; reference for the hole's shape and falloff |

**Not fetched, blocked for tooling (2026-10-05):** Texturecan "Imperfection and Decal of Bullet Holes" (<https://www.texturecan.com/details/217/>, stated CC0, 1K/2K/4K/SBSAR zips) answers a scripted download with HTTP 406 (Mod_Security); the Director's own manual download also failed, so OpenGameArt's CC0 bullet decal replaced it.

## Not CC0

Nothing non-CC0 is stored. A reference image from elsewhere is not downloaded by tooling; the Director supplies those by hand. Keep any such
file under `ASSETS/photo_src/<material>/` with a trailing `(c)` in its name before the extension (plain ASCII: a TM / R sign in a file name is a risk for Godot's importer and the tools), and list it here with its source.
