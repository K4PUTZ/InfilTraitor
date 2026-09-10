# RENDER ORDER MASTER PLAN — depth on the isometric board — v1.0

**Status:** 🔵 **DESIGNED, SPIKE-GATED (2026-09-10).** Nothing here is built. Task 1
is a measurement, and it decides whether the rest of the plan happens at all or
whether the project takes the recorded fallback (§8) instead. Both outcomes are
acceptable and both are specified.

**Owner:** engine. Touches `voxel_renderer.gd` and the glass render path only.
**Explicitly does NOT touch** the opaque-wall occlusion mechanism (OCC-21 erase +
OCC-27 wireframe) — see `RO0`.

**Supersedes:** `GLASS_MASTER_PLAN` §19 (THE GLASS MERGE) and its dependency on
`OCCLUSION_MASTER_PLAN` §7 (THE X-RAY SILHOUETTE), both designed 2026-09-10 and
**rejected the same day** after a code audit — §3 records why, because the four
failure modes are worth keeping even though the design is gone.

---

## 1. The Director's ruling that produced this plan

2026-09-10, on the audit of the previous session's design:

- *"vamos rejeitar o projeto da sessão de ontem e escrever o nosso novo. Como
  sempre buscamos fazer os melhores fundamentos possíveis, mesmo que custe tempo
  e esforço. Porém tendo em mente que é um game mobile first."*
- *"Vamos testar sua proposta e se der certo implementar — senão deixamos o vidro
  por cima mesmo, mas com warnings para paredes que fiquem sobre o vidro na hora
  de criar os mapas."*
- On rotation: *"ainda estou dividido […] Tenho a impressão que esse não é nosso
  grande vilão, e que vale a pena manter até o final e decidir testando. […] De
  qualquer forma vamos continuar com o mecanismo para fins de debug, ou quem sabe
  um lançamento em desktop."* — **rotation stays. Nothing here may assume a
  single fixed view.**
- *"Vamos separar a feature de visão de raio x, visão térmica e etc, do real
  problema agora que é a ordem das coisas na tela. Mas vamos ter em mente que
  esses detalhes vão ser necessários no futuro, então o mecanismo precisa estar
  apto para lidar com eles."*
- *"Também não queremos modificar a oclusão das paredes opacas que já existe, o
  vidro é uma oclusão do mundo real, digamos."*

---

## 2. The problem, stated exactly

A glass pane composites over an opaque wall that stands **in front of** it — a
wood pillar, a concrete wall, the floor. Found on the GLASS map 2026-09-09, four
views, no blast.

**It is not a cross-storey problem.** Measured in `maps/GLASS.map.json`:

| geometry | GU | storeys | levels |
|---|---|---|---|
| the big pane | `(10..15, 9)` face SW | 3 | 80–103 |
| the back pane | `(11..15, 6)` face SW | 3 | 80–103 |
| concrete / plywood **in front** | `(3,11)` `(6,11)` `(9,11)` | 3 | 80–103 |
| brick **in front** | `(12,14)` `(16,14)` | 3 | 80–103 |

The offending walls occupy **the same levels** as the panes. No per-storey or
per-level `z_index` band can separate them: within one level, every cell shares
one `z_index`, and the glass composite sits above all of them by construction
(`G-D18b`, `set_glass_over_z(agent.z_index + 1)`).

The root cause is already written down in this codebase, in
[`floating_collectible.gd:379`](../../godot/scripts/overlays/floating_collectible.gd):

> *"`z_index` in this project encodes **HEIGHT** (level + WALL_BASE_Z_INDEX) while
> what a prop needs is **DEPTH**. The two are independent."*

which is `OCCLUSION` `O5` — *depth is not `z_index`*. Glass is the third system to
hit it (props got a bespoke depth solver; the occlusion wireframe got per-level
panels). Director, 2026-09-09: *"os vidros e as paredes definitivamente precisam
estar no mesmo tabuleiro pra não ter essa discrepância."*

---

## 3. Why the rejected design (`GLASS` §19 + `OCCLUSION` §7) could not work

Kept because each failure is a trap the next attempt could walk into.

| # | The finding |
|---|---|
| **F1** | **Its central premise was false: Y-sorting is not enabled anywhere in this project.** §19.2 read *"Each per-level layer already y-sorts its own cells (`y_sort_origin = 1`)"*. `y_sort_origin` does nothing without `y_sort_enabled`, which appears **zero times** in the repo (`.gd`, `.tscn`, `.tres`). Two independent in-repo statements already said so: [`floating_collectible.gd:381`](../../godot/scripts/overlays/floating_collectible.gd) and `OCCLUSION` `O6‴`. So the plan was not "move glass into the opaque layer" — it was silently also "turn on Y-sorting across ~32 voxel layers", a board-wide draw-order and batching change it never costed. |
| **F2** | **A `BackBufferCopy` cannot see the cells of the layer it precedes — so the merge traded one bug for another.** §19.2 claimed the snapshot would contain *"the opaque cells of level N that sit behind it"* "because it y-sorts inside its own layer". A `BackBufferCopy` copies the framebuffer at **its own** point in the draw order; it draws before the whole layer, so none of that layer's cells are in it. With `cover ≈ 1` for a pane body ([`glass_pane.gdshader:47`](../../godot/shaders/glass_pane.gdshader)), an opaque wall **behind** the glass at the same level would have been replaced by tinted background. It fixes the front wall and breaks the back wall. |
| **F3** | **One snapshot per LEVEL breaks the G-D2 container inside a single pane.** The atom is **32×36 px** and the level step is **20 px** (`GeometryCoords`), so consecutive levels overlap by **16 of 36 px**. A 3-storey pane spans 24 levels — 24 snapshots means **23 seams where the tint is applied twice**, which is the exact defect the container was built for (*"criar um container rasterizado, de forma que as opacidades das faces não conflitem"*, 2026-08-30). `glass_transparency_selftest` already gates it: *"no BackBufferCopy container — the pane would double-tint on overlap"*. §19 as written required weakening that test. |
| **F4** | **The one risk it did declare was the least of them, and it was overstated.** 24 full-viewport blits on a mobile-first game is a real hazard — but `BackBufferCopy` has `COPY_MODE_RECT`, which §19 never considered. See `RO3`: the arithmetic changes by an order of magnitude. |
| **F5** | **`OCCLUSION` §7 was a false dependency, and its mask design has a defect.** What §19 needed from §7 was a *ruling* (relax `G-D18b`), which the Director had already given on 2026-09-09 — not code. Meanwhile §7's mask was specified as **screen-space rects** refreshed only on the occlusion cadence (`X2`), while [`camera_controller.gd`](../../godot/scripts/controllers/camera_controller.gd) has drag, wheel zoom, pinch zoom **and** shake: any of them invalidates a screen rect on the next frame and the stripes slide off the actor. A world-space mask (the pattern `glass_pane.gdshader`'s `v_glass_world` already uses) has no such problem. §7 is now decoupled — see §9. |

---

## 4. Constraints this plan accepts as given

| # | Constraint | Consequence for the design |
|---|---|---|
| **RO0** | **The opaque-wall occlusion mechanism is untouched.** Director: *"não queremos modificar a oclusão das paredes opacas que já existe, o vidro é uma oclusão do mundo real."* | OCC-21's erase and OCC-27's wireframe keep their behaviour AND their plumbing. In particular `occlusion_wireframe_overlay._layer_z_index()` reads `get_layer(level).z_index` and returns `z − 1` (OCC-23) — so **the per-level `z_index` scheme must survive intact.** This single constraint is what rules out the "one flat board" variant and picks the design in §5. |
| **RO0b** | **Rotation stays.** Not a decision to make now; the mechanism is kept for debug and a possible desktop release, and the call is deferred until after the materials milestone makes the memory cost estimable. | Every depth decision must be derived in **view space, per view**, and must survive a flip with no re-derivation pass. Y-sorting is view-space by construction (the layers already draw view-space cells), which is a point in its favour: a hand-rolled depth solver has to be *re-applied* on every rotation the way [`floating_collectible.gd`](../../godot/scripts/overlays/floating_collectible.gd) does today. |
| **RO0c** | **Mobile-first.** | The gate is frame time on a fire frame and on a rotation, against the standing worst-frame budget — not "does it look right". A design that only passes on desktop fails. |
| **RO0d** | **X-ray / thermal vision are OUT of scope, but must not be foreclosed.** | See §9. The test is: after this lands, can a second actor instance still be drawn at a `z_index` above every voxel layer? The answer must stay yes. |

---

## 5. The design

### RO1 — The per-level `z_index` scheme stays. Depth is resolved **inside** a level band, never by renumbering `z`.

`z_index` is a coarse key that is *already sufficient for everything except the
same-level case*, and this is arithmetic rather than opinion: the level step is
20 px and the atom is 36 px tall, so cells **two or more levels apart cannot
overlap at all** (40 > 36). Cross-level ordering is therefore already correct.
What one `z_index` per level cannot do is separate a front cell from a back cell
**within** that level — and that, and only that, is the bug.

So the change is: **enable Y-sorting so that cells sharing a `z_index` resolve by
screen depth.** Within one level the level offset is constant, so screen Y is
monotonic in view-space `(x + y)` — sorting by Y inside a band *is* sorting by
isometric depth, with no `y_sort_origin` trick needed.

Keeping per-level `z` is what leaves untouched: OCC-23's wireframe panels
(`layer.z_index − 1`), the props' `behind_top_z` walk
(`voxel_renderer.gd:1982`), the twelve overhead overlays keyed off
`get_max_voxel_z_index()`, `enemies_root.z_index`, OCC-03's agent bump, and
`negative_storey_selftest`'s pin (`level0 == 10`, `level −1 == 0`). None of them
move. That is `RO0` being honoured by construction, not by care.

### RO2 — The glass layers come down from the flat top-`z` to their own level's `z`

`_glass_layers[level].z_index` becomes `_layers[level].z_index`, and the two
become Y-sort siblings. Deleted: `_glass_composite_z`, `_glass_composite_z_floor`,
`set_glass_over_z()` and its call in `room.gd`. `G-D18b` is **relaxed** by the
Director's own 2026-09-09 ruling (the agent may render in front of a pane he
stands behind, *"em último caso"*) — recorded there, not re-litigated here.

⚠️ Glass keeps its **own layer**. Merging glass cells into the opaque layer (what
§19 proposed) buys nothing here and costs `F2`; the layer split is what leaves
room for the container in `RO3`.

### RO3 — The container survives as one `BackBufferCopy` **per glass-bearing level**, in `COPY_MODE_RECT`

This is the lever the rejected plan missed. Today's single copy is
`COPY_MODE_VIEWPORT` ([`voxel_renderer.gd:6254`](../../godot/scripts/geometry/voxel_renderer.gd)).
A per-level copy does not need the viewport — it needs the rect that level's
glass actually occupies.

The arithmetic, on the GLASS map's worst pane (6 GU wide, 3 storeys):

| | |
|---|---|
| pane width | 6 GU × 8 voxels × 32 px = **1536 px** |
| one level's band | 1536 × 36 px ≈ **55 kpx** |
| 24 levels | ≈ **1.33 Mpx** |
| today's single full-viewport copy at 1080×1920 | **2.07 Mpx** |

So the whole per-level glass composite plausibly costs **less** than the one blit
it replaces. ⚠️ **Plausibly. This is the number Task 1 must measure, not assume**
— rect copies still cost a state change each, and a portrait phone viewport is
not the only case.

### RO4 — What the snapshot contains, and the one authoring consequence

A per-level backbuffer that sorts into the Y-stream **just behind that level's
glass** captures everything drawn before it: all lower levels, and the same-level
opaque cells that sit behind the pane. That is the correct content and it fixes
`F2`.

It cannot capture opaque geometry that **interleaves in depth inside the pane's
own depth span at that level** — a pillar standing between the near and far ends
of the same shop window. Such geometry would be lost behind the pane. This is
rare, it is detectable, and it is exactly what the fallback's authoring check
(§8) reports — so **that check is built either way**, and it is what makes this
limitation a warning rather than a silent defect.

### RO5 — Nothing is derived from the current view and cached across a flip

Every ordering decision here is a property of the scene graph (Y-sort), so a
rotation re-sorts for free. No depth list, no per-cell z stamp, no "re-apply on
rotation" pass. `RO0b` satisfied structurally.

---

## 6. TASK 1 — the spike (this decides everything else)

One branch, no production code, three questions. Measured on GLASS, in the real
windowed build, with the real map.

| Q | Question | How it is answered | Gate |
|---|---|---|---|
| **Q1** | Does Godot merge the tiles of two sibling Y-sorted `TileMapLayer`s at the same `z_index`, under a Y-sorted parent, into one depth order? | A minimal scene: two layers, one opaque cell in front, one glass cell behind, at one level. Capture. | The front opaque cell must cover the glass cell. **If NO → design A is dead, go to §7's design B.** |
| **Q2** | What does `y_sort_enabled` cost on the real board? | `INFILTRAITOR_HIDE_VOXELS` / the frame probe already in `_build_voxel_layer_node()`; a fire frame and a rotation on GLASS, y-sort ON vs OFF, **same boot binary, same map, same agent cell**. | Worst frame must stay inside the standing budget. A regression that eats the 2026-08-26 perf wave fails the spike outright — performance outranks this fix (`PERFORMANCE_MASTER_PLAN`, standing priority). |
| **Q3** | Can a `BackBufferCopy` sort into that Y-stream (i.e. be ordered *between* tiles of a Y-sorted layer), and what does `COPY_MODE_RECT` × 24 actually cost? | Same scene as Q1 plus a rect backbuffer behind the glass cell; then the real map for the cost. | The same-level opaque cell behind the glass must be visible **through** it, and the 24-copy cost must beat or match today's single viewport copy. |

**Red before green.** The spike starts by reproducing the bug on the current
build (`zidx_bug`: GLASS, views S and E, no blast, the wood pillar and the
concrete wall at `(6,11)` / `(9,11)` against the panes at `y=9`) — and it must be
a *named* capture, not an `auto_*` one, because it is going to be cited across
sessions and the 50-file rotation would eat it.

**The control run comes before the verdict.** Before glass moves anywhere: turn
Y-sorting on with glass still at the flat top-`z` and prove the board is
unchanged. If enabling Y-sort alone moves pixels, the change is not additive and
`RO0` is already violated — stop and report. (A "before/after" that skips this
cannot tell "Y-sort did nothing" from "Y-sort did two things that cancelled".)

---

## 7. TASK 2 — the build, if the spike passes

Design A (Q1 and Q3 both yes):

1. `y_sort_enabled` on `VoxelRenderer` and on every layer it builds — one seam,
   `_build_voxel_layer_node()` / `_build_glass_sublayer_node()`.
2. `RO2` — glass layers to their level's `z`; delete the composite-`z` machinery
   and the `room.gd` call.
3. `RO3` — one `BackBufferCopy` per glass level, `COPY_MODE_RECT`, rect
   recomputed when that level's glass extent changes (map load, destruction that
   shrinks a pane, rotation). The extent is already knowable — `_glass_layers`
   holds the cells and `glass_levels()` the levels.
4. Re-home the things that ride the composite `z` today: `_glass_crack_root`
   (the G-D27 craze sprites, `layer.z_index + 1`), the shard field, and the
   glass rain (`room.gd:709`, `layer.z_index + 2`). Each goes to its own level's
   band.
5. `glass_transparency_selftest` — the container assertion changes shape (one
   backbuffer per glass level, not one globally) but **must not weaken**: it
   still has to fail if a pane can double-tint.

Design B (Q1 no, or Q3 no): glass cells merge into the opaque layer and the
screen read is **dropped** — `glass_apply()` becomes a two-pass material
(`blend_mul` for the tint, `blend_add` for the sheen), which needs no snapshot at
all and therefore no backbuffer anywhere. ⚠️ This is only viable if glass
fragments can be made strictly non-overlapping (suppress the top cap on a voxel
that has glass above it, side caps only on a pane's rim), because a multiply
blend double-tints on any overlap — and the antialiased `cover` band at every
tile seam counts as overlap. It also loses the `max()` "not a black hole" floor
(`glass_min_body`). **Design B is a look regression risk against a ratified
Director ruling (G-D2) and must not be taken without a same-boot A/B capture.**

---

## 8. THE FALLBACK — if the spike fails (Director-authorised, 2026-09-10)

*"senão deixamos o vidro por cima mesmo, mas com warnings para paredes que fiquem
sobre o vidro na hora de criar os mapas."*

Nothing in the renderer changes. What gets built is a **map-authoring check**:

- **Where:** a new check in the map validation path, run at map load
  (`push_warning`, per the error-handling contract — an anomaly with a documented
  fallback, operation continues) and available over every map from the CLI, the
  way `check_invariants.py` is.
- **What it detects:** for each glass slice, an opaque voxel that is NEARER the
  camera (view-space `x + y` greater, `O5`'s canon depth, the same rule
  `floating_collectible` already uses) **and** whose on-screen band overlaps the
  pane's. Screen-band overlap is what keeps it from crying wolf on a wall two
  cells in front that draws entirely below the pane.
- **All four views.** `RO0b` — rotation stays, so a conflict that only exists
  after a flip is still a conflict. The warning names the view.
- **Message:** the glass GU + face, the offending opaque GU, and the view — enough
  to fix it in the map without opening the game.

⚠️ **This check is built even if the spike passes**, because of `RO4`'s
interleave case. It is the fallback's whole deliverable and the winning design's
safety net, so it is the same work either way — which is the reason to build it
first if the spike is going to take a while.

---

## 9. X-ray / thermal vision — separated, not forgotten

Director: *"vamos separar a feature de visão de raio x, visão térmica e etc, do
real problema […] Mas vamos ter em mente que esses detalhes vão ser necessários
no futuro, então o mecanismo precisa estar apto para lidar com eles."*

`OCCLUSION` §7 is **not a dependency of this plan and this plan is not a
dependency of it.** They were coupled by an argument that does not hold (`F5`).

What this plan owes the future feature is one property, and it is a test, not a
promise: **after `RO2` lands, it must still be possible to draw a second actor
instance at a `z_index` above every voxel layer.** It is — `RO1` keeps the
per-level `z` scheme and `get_max_voxel_z_index()` intact, which is the exact
anchor OCC-03 and the twelve overhead overlays already use. Glass coming *down*
from the top-`z` frees that slot rather than crowding it.

Two notes carried forward for whoever builds §7:
- The mask must be **world-space**, not screen rects (`F5`).
- Guards' phantom stays gated on a vision mode (`O2`); the agent's is a look call
  that §7.5 has not answered, and the answer is cheap only once vision modes
  exist to compare against.

---

## 10. Verification (any outcome)

1. The `zidx_bug` repro, named capture, before and after: GLASS views S and E,
   no blast — the wood pillar and the concrete wall render **solid** in front of
   the panes.
2. A same-level opaque wall **behind** a pane still reads **through** it. This is
   `F2`'s trap and it needs its own capture; the fix for the front wall must not
   have eaten the back one.
3. A pane's body shows **no horizontal seam at a level boundary** — `F3`'s trap,
   24 levels of one pane, one look.
4. Four views + F2 reload: order holds, craze / rim shards / rain at their true
   depth (`RO0b`, `RO5`).
5. `glass_blast_demo` and a fire frame: worst-frame budget (`RO0c`).
6. Full suite — `run_selftests.py`, `project_lint.py`, `check_invariants.py`,
   `gen_codemap.py --check`.

---

## 11. Open

- **The rotation call itself is deferred**, by the Director, until the materials
  milestone closes and the memory cost is estimable. This plan is neutral to it:
  it works per view either way, and it is not evidence for or against.
- **`M5 voxel props` is listed as blocked on "renderer v2".** If Q2 comes back
  cheap, the same Y-sort inside a band is what would let a prop stop hand-rolling
  its depth (`floating_collectible._apply_z_index()`, re-applied on every
  rotation). Not scoped here — noted so it is not re-derived from scratch.
