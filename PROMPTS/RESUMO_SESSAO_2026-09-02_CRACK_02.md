# Session 2026-09-02 (part 2) — CRACK-02: the crack leaves the voxel

The previous session is
[`RESUMO_SESSAO_2026-09-02_CRACK_01.md`](RESUMO_SESSAO_2026-09-02_CRACK_01.md),
which built CRACK-01 in five stages and then watched the Director reject its LOOK
three times, each rejection one level deeper than the last. The third took the
renderer itself and became **G-D27 → CRACK-02, §13, planned and unbuilt.**

**This session built it.** `GLASS_MASTER_PLAN` v1.22 → **v1.23**.

| | stage | commit |
|---|---|---|
| **S-1** | the crack leaves the voxel and becomes a sprite (G-D27) | `a6cb797f` |
| **S-2** | a destroyed voxel cuts the sprite (G-D30), and the dial | `a407b93e` |
| **S-3** | a crack survives a perspective flip — and a map defect surfaces | `34077458` |
| **S-4** | the four-class art order, WRITTEN; its art deliberately not made | *(docs)* |

---

## S-1 — the sprite, and the basis that changed job

`GlassCrackSprite` + `glass_crack.gdshader`: one node per crack event, parented
into the glass composite so G-D18b's agent rule still holds.

**The trick is that there is no inverse in the shader.** CRACK-01-D had measured
the wall face's basis and CRACK-01 spent it inverting a canvas delta per fragment.
S-1 bakes the FORWARD basis into the node's `Transform2D` instead, so the quad IS
the pane's parallelogram and UV is already the sheet. The basis changed job rather
than being thrown away, exactly as §13.1 predicted, and selftest [10] changed with
it — it now pins the sprite's transform against the renderer's own cell geometry
at **0.00000 px** over 13×11 offsets, while keeping the ground-plane inverse as a
control that MUST be wrong (6.25 voxels worst).

G-D26 (additive) is now enforced by BLEND MODE — `render_mode blend_add` is
literally `dst.rgb += src.rgb · src.a` — rather than by arithmetic inside someone
else's shader. And `glass_pane.gdshader` went back to exactly what it was before
CRACK-01-B, with a comment saying that putting the crack back in it is the
rejected design.

Deleted: the per-level R8 crack plane, the RGBAF groups strip,
`GLASS_CRACK_GROUP_CAP` and its 16-crack ceiling, five plane functions, and every
crack uniform on the pane shader.

### The capture that was correct for the wrong reason

The first clip captures looked right and proved nothing. **A centred hit cannot
exercise the pane clip**: the wide sheet is 44 voxels and that pane is 48, so the
bounds never engage. The demo now prints the sheet quad and the pane quad in
screen pixels — a comparison of two rectangles instead of a squint at an
isometric picture — and `INFILTRAITOR_CRACK_DEMO_EDGE=1` puts the impact on the
pane's edge so the sheet runs 22 voxels past the frame. It is cut dead on the
boundary: `glass_crack_demo_c02_edge_clip_after.png`.

## S-2 — the cut is a READ, not a second plane

§13.2 said "one per-level R8 plane written at the three erase seams". It is not a
plane. `erase_cell()` on `_glass_layers` is what actually removes a glass voxel
from the screen and **all three seams already go through it**, so a parallel plane
would be a third copy of the same fact, free to drift. The occupancy is walked off
the tilemap — the same authority `INFILTRAITOR_CELL_PROBE` reads — over the pane's
own ≤64×32 rectangle. The seams only FLAG; the rebuild happens once per batch, at
the five places `flush_damage_composite_pages()` already runs, so the cook's
per-cell erase loop does not become quadratic in the size of the hole.

§13.5's two side effects, both confirmed rather than assumed: a G-D9 brick band is
not on the glass layer either, so the web is cut off it for free; and armored
glass never destroys a voxel, so its occupancy is solid and the dial cannot erase
its core.

### ⚠️ The dial is not the small choice it looked like

`glass_crack_cut_triptych_2026-09-02.png` — one crack, one boot, 0.0 / 0.5 / 1.0
over a real hole punched through the real erase seam. On a single hit the dial is
a local decision about the bore.

`glass_crack_cut_shotgun_2026-09-02.png` — **the same dial on the real
`agent_shot` path, where it is categorical.** At 1.0 no web survives at all. Not a
tuning artefact: G-D24 turns every overlapping pellet crack into a hole, so the
shot ends `cracked=0 destroyed=279` and there is no standing glass under any of
the webs. At 0.0 the whole cluster is there. **This interaction between G-D24 and
G-D30 is the Director's to rule on, and no amount of reasoning about the shader
would have produced it.**

## S-3 — the round trip, and what it found

`_base_cracks` mirrors `_base_damage`: the impact in BASE coords and the sheet id,
nothing else. The pane, the run axis and the pane's bounds are re-derived from the
rebuilt geometry, so a crack is a handful of ints rather than a serialised sprite.

⚠️ It rebuilds through `sprite_spec()`, **never** `apply()`. Re-applying would set
the damage a second time and run G-D24 against the cracks it is in the middle of
rebuilding: every crack would cross the one before it and the pane would come
apart on a camera move. Selftest [13] pins both halves.

**The proof is a round trip, N → E → N**, which returns to the perspective the
crack was made in, where `cell_from_base` is the identity — so the rebuilt sprite
has to land on the very pixels of the pre-flip frame. Measured: **5853 of the
returning frame's 5855 bright pixels are the original's**, 2 new, bbox unchanged.
"A crack appeared somewhere" is what the eye would have accepted.

### ⚠️ A map defect, and it is not glass's

Every crack reports "no pane voxel" in E/S/W on the GLASS map.
`PerspectiveMapper.layout_with_perspective()` rotates `wall_tiles`,
`wall_levels`, `solid_block_instances`, `floor_zone_instances`,
`voxel_prop_instances` and the rest — but **not `panel_instances`**, where every
half-thickness element lives, G-D9's windows included.

Measured from one boot, N then E:

    N: PANE_SLICE_16_10_SW cells (88,87)..(135,87)
    E: PANE_SLICE_16_10_SW cells (88,87)..(135,87)   <- identical

Seven of eight panes, all on a constant-y line a quarter turn must put on a
constant-x one. The panes stand still while the walls rotate; the union-find then
regroups them, which is why one pane's own body (1382 contiguous bright pixels)
does not come back from the round trip either.

That is ROOF-BAKE-02a repeating on a key nobody added. **Left alone and
reported** — it is a map defect independent of glass, and the fix is NOT a copy of
the block branch, because a panel carries a FACE and needs the `remap_tile_name`
treatment as well as `cell_from_base`. Rotation is suspended for performance, so
nothing is on fire.

## S-4 — the order is written, the art is not

[`ART_ORDER_GLASS_FRACTURE_CLASSES.md`](ART_ORDER_GLASS_FRACTURE_CLASSES.md):
the four classes (G-D28), `blast` = 3 × H/V flip hashed off the B4 FNV-1a
(G-D29), the free-size/aspect contract S-1 made real, and six wiring steps.

**The art is deliberately not made**, and the order says why in its §6: the
generator would have to produce the opposite distribution to the one it produces
(§13.4 — real bullet holes are SPARSE with a few LONG runners; the shipped sheets
are dense and even), `blast` has no centre so it is not a preset of a radial
generator at all, `blast_*` has no CALLER yet (§6.2 is unbuilt, and art for a
trigger that does not exist is a trap this project has paid for twice), and the
look has been rejected three times on this track already. **The next step is ONE
`tight` sample at the reference's density, at true size, for a yes or no.**

---

## §13.3 and §13.5, both closed with numbers

**§13.3 — the contract moved in S-1's own commit**, as the plan required.
`TextureResolver`'s `fracture_` branch accepts any size (the branch still has to
exist: an unrecognised prefix is Tier.NONE, the generic atlas, and no error at
all). `check_decal.py` swapped 1024×512 for an ASPECT rule, reads the spans out of
`glass_crack.gd` instead of duplicating them, and re-expressed the origin slack as
a fraction of the page — the same tolerance, because "4 voxels" against a page
with no fixed voxel extent would have quietly become 3× more permissive.

**§13.5 — perf measured, and the prediction did not hold.** Same map, same camera,
idle `GLASS`, 40 samples each side, `--disable-vsync`:

| binary | frame (median) | render cpu | draw calls |
|---|---|---|---|
| CRACK-01 `6d8bd94e` | **6.40 ms** | 3.10 ms | 7944 |
| CRACK-02 `a407b93e` | **6.40 ms** | 3.10 ms | 7944 |

Identical. Removing a `texture()` + branch from every glass fragment is real in
instruction count and invisible in the frame, because this board is not
glass-fragment bound (`render gpu` reads 0.0). Cost side: **+1 draw call and +1
quad per live crack**. Neither number is a reason to have done CRACK-02 or to undo
it — the reason was the look — but the plan predicted a win and there is not one.

## Three defects the new tests found, all invisible to every gate that existed

1. **A centred hit cannot prove the pane clip** (S-1, above).
2. **`_glass_composite_z` starts at −9999, below `CANVAS_ITEM_Z_MIN`.** Assigning
   it printed an engine error and left the node at z 0. The glass LAYERS never hit
   it because `_ensure_glass_sublayers()` sets the real z on its first line; the
   crack root can be asked for before any of that has run.
3. **`ImageTexture.get_image()` is a readback and can lag an `update()`.** A
   diagnostic that asked the texture read the occupancy one event stale and said
   the cut had not followed. The builder keeps the CPU-side Image as the authority.

## State at close

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.23.** CRACK-02 S-1/S-2/S-3 built; S-4's order written, art unbuilt |
| Verification | `project_lint` PASS (230) · `check_invariants` OK · CODEMAP fresh · `run_selftests` **50 clean, 0 failed** · `glass_crack_selftest` **48 checks** (32 → 39 → 45 → 48) |
| Captures (hand-named, rotation-proof) | `glass_crack_demo_c02_{tight,wide,gd24,edge_clip}_*` · `glass_crack_cut_triptych_2026-09-02.png` · `glass_crack_cut_shotgun_2026-09-02.png` · `glass_crack_flip_roundtrip_2026-09-02.png` · `shot_c02_{realshot,cut0}_3_damage.png` |
| **Open for the Director** | **G-D30's cut value** (and it is a bigger question than it looked) · the `tight` sheet's density, before six more are generated · whether the `panel_instances` rotation defect is worth fixing while rotation is suspended |
| Unbuilt in glass | **G6** (shards on screen) · **G-D25** (big shards) · `plastic` · skylights · glass cube · G-D8's last third · §6.2's blast-crack trigger (which `blast_*` art needs) |

## The transferable lessons

1. **A capture can be correct for the wrong reason.** The clip pictures were right
   and proved nothing, because the sheet was smaller than the pane and the code
   under test never ran. Make the instrument print the two things it is comparing.
2. **A "plane written at N seams" is often a READ of something that already
   exists.** The glass tilemap was already the authority every seam went through;
   a second copy would only have been a way to disagree with it.
3. **A dial's value can be a design question wearing a number.** G-D30 looked like
   a local aesthetic choice until the shotgun capture showed 1.0 erasing every web
   on the map, via G-D24.
4. **Proving persistence needs a round trip, not a flip.** Coming back to the
   identity turns "is it still there" into a pixel comparison.
5. **Measure the perf claim even when it is obviously true.** Removing work from
   every fragment of a whole material moved the frame by 0.00 ms.
