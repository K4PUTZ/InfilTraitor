# RENDER ORDER MASTER PLAN — depth on the isometric board — v1.0

**Status:** 🟢 **T2-1 BUILT 2026-09-10 behind `INFILTRAITOR_DEPTH_BOARD=1`, default
OFF — the bug is fixed on screen and rotation re-derives it for free (§7.1).** Four
things are owed before the gate can flip, listed there. Earlier the same day:
Option C approved and its container priced (§6.4, ~4× headroom); Task 1 replaced
its own design. Y-sort *works* (Q1) and **costs too much** (Q2: +244% draw
calls on GLASS, +511% on PLAYGROUND, on an IDLE board), so `RO1`/`RO2` are
withdrawn as the mechanism. What the failure pointed at is measured and passes:
**a pane is PLANAR, so a level's opaque cells split into `far` / `near` around it
and the TREE does the ordering** — `opaque_far → BackBufferCopy → glass →
opaque_near`, one `z_index`, no Y-sort anywhere, no batching given up (Q6). It
also solves the case Option A could not: a wall BEHIND the glass still composites
through it. Full numbers in §6.1, the design in §6.3. **Nothing is built** — §6.3
is a new design and needs the Director's sign-off before Task 2.

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

### 6.1 TASK 1 RESULTS — run 2026-09-10, `render_order_ysort_spike.gd`

Godot **4.6.1.stable**, Metal / Forward Mobile, Apple M1. Every case rendered into
a SubViewport and **classified by pixel count**, not looked at. Grid is the
project's own Canon (32×16 ISOMETRIC DIAMOND_DOWN, atom 32×36, `texture_origin`
(0,10)); cell (0,0) is FAR, cell (1,1) is NEAR, and the two layers are added
opaque-first / glass-last **so tree order favours the wrong answer** — anything
that reorders them has to be the Y-sort.

| | result | counts |
|---|---|---|
| **Q1 CASE** — y-sort ON, near opaque vs far glass, same `z_index` | ✅ **the near opaque covers the far glass** | `opaque_clean=1152` (a whole atom) · `glass_over_opaque=0` |
| **Q1 CONTROL** — y-sort OFF, identical scene | ✅ **the bug reproduces** — far glass covers the near wall | `glass_over_opaque=640` · `opaque_clean=512` |

> **Q1 is YES.** Godot 4.6.1 merges the tiles of two sibling Y-sorted
> `TileMapLayer`s at the same `z_index`, under a Y-sorted parent, into one depth
> order. `RO1` and `RO2` are viable, and the control proves the probe can see the
> failure it is claiming not to find.

| | result | counts |
|---|---|---|
| **Q3 CASE** — y-sort ON, `BackBufferCopy` positioned between the far opaque and the near glass | ❌ **the glass saw nothing** | `probe_saw=0` · `probe_blind=1152` |
| **Q3 CONTROL** — same, backbuffer sorted before everything | ✅ blind, as specified | `probe_saw=0` · `probe_blind=1152` |
| **Q3 HARNESS-A** — y-sort OFF, tree order opaque→bb→glass, one `z` | ✅ **the glass SEES the opaque** | `probe_saw=640` · `probe_blind=512` |
| **Q3 HARNESS-B** — y-sort OFF, `z` 10 / 15 / 20 (the shipping layout) | ✅ the glass SEES the opaque | `probe_saw=640` · `probe_blind=512` |

> ⚠️ **The case and its control returned IDENTICAL numbers**, which is the
> signature of a blind instrument, not of an answer — so the verdict was withheld
> until two harness controls proved the rig can see a backbuffer at all. Both did,
> at 640 px. **Q3 is therefore a real NO:** turning Y-sort on takes a
> `BackBufferCopy` out of the ordering (the glass read the bare background
> everywhere, while its *tile* was still correctly sorted in front — `opaque_clean`
> fell to 512). **`RO3`/`RO4` as written cannot be built.**

| | result |
|---|---|
| **Q4** — a `CanvasGroup` as the container, sorted by Y | ⚠️ **INCONCLUSIVE — not pursued.** Both case and control returned the raw un-shaded blend (`glass_over_opaque=640`, `probe_saw=0`, `probe_blind=0`), i.e. the group's material never ran. That is a statement about the rig, not about `CanvasGroup`. Dropped because the structural objection stands regardless: a group is ONE canvas item and therefore ONE sort key, while a pane spans 24 levels — one key per pane cannot be right against a 24-level wall, and one group per (pane, level) is 24 buffers, no better than what it replaces. |

**Q5 — does a pane's glass actually overlap itself?** This is the question under
the whole container: `G-D2` exists so overlapping glass fragments do not tint
twice. `_build_glass_pane_atom()`'s header claims the geometry already prevents it
(*"a sliver fills only where the main face is absent, so nothing double-covers"*).
Measured on the real builder rather than believed:

| | SW | SE |
|---|---|---|
| body atom (interior pane voxel: main face only) | 336 texels, rows 8..35 | 336 texels, rows 8..35 |
| capped atom (top + side slivers) | 670 texels, rows 3..35 | 670 texels, rows 3..35 |
| **two body atoms stacked one level (20 px) apart → texels carrying BOTH** | **16** | **16** |
| capped atom with a body atom above it | 120 | 120 |

> **The comment is right, and the number is small.** A pane's body atoms overlap
> by **16 texels of 336 — 4.8%**, and that 16 is the shared antialiased edge, one
> texel per column across the 16-column seam. The 120-texel case is the top
> sliver under the atom above, a configuration that cannot occur (`want_top` is
> only set when there IS no glass above). **So the container is buying almost
> nothing WITHIN a pane** — which is what makes option B below thinkable at all.
>
> ⚠️ It is still buying something *between* panes: a near pane over a far one
> overlaps arbitrarily, and today they read as one tint rather than two. That is a
> `G-D1`/`G-D2` look question, and it is the Director's.

**Q2 — what Y-sort costs on the real board.** `INFILTRAITOR_YSORT=1` (every
level) / `=2` (scoped to glass-bearing levels only), default OFF, measured with
the project's own standing `INFILTRAITOR_FRAME_PROBE=1`. **Idle board, nothing
happening**, 600 frames, same binary, M1 / Metal / Forward Mobile:

| map | mode | ms/frame | render cpu | draw calls |
|---|---|---|---|---|
| GLASS | OFF | 16.7 | 3.6 ms | 8 307 |
| GLASS | FULL | 19.0 | **11.9 ms** (+231%) | **28 573** (+244%) |
| GLASS | SCOPED | 16.7 | 8.2 ms (+128%) | 16 466 (+98%) |
| PLAYGROUND | OFF | 16.7 | 2.3 ms | 4 222 |
| PLAYGROUND | FULL | **22.9** | **13.4 ms** (+483%) | **25 802** (+511%) |
| PLAYGROUND | SCOPED | 16.7 | 5.5 ms (+139%) | 10 154 (+140%) |

> **Q2 FAILS for the full form and is not worth it scoped.** PLAYGROUND under FULL
> misses 60 Hz **with nothing happening on screen**, on an M1 — 22.9 ms on an idle
> frame, before a single blast, on the machine this is developed on rather than on
> the phone it ships to. This is a PERMANENT per-frame cost, not an event cost,
> and it eats a large share of what the 2026-08-26 perf wave bought (worst frame
> 267 → 31 ms). Performance is the standing priority and this is not close.
>
> SCOPED stays under the vsync cap but still doubles the draw calls, and the
> reason it cannot do better is structural: **`y_sort_enabled` is a property of a
> LAYER, not of a region.** One glass cell anywhere on a level forces that level's
> entire 44×22 board to sort per tile. A storefront cannot pay only for itself.
>
> ⚠️ Not run, because the verdict did not need it: the pixel-identity control
> (Y-sort on with glass unmoved). If Y-sort is ever revisited, that control comes
> first — see §6.

### 6.2 What Q3 leaves on the table — the open Director call

`RO1`/`RO2` fix the depth. The container has to go somewhere else, and there are
exactly two places, which trade against each other:

| | **Option A — backbuffer before the level band** | **Option B — no screen read at all** |
|---|---|---|
| how | one `BackBufferCopy` per glass level at `z = level_z − 1`; `z` ordering still works under Y-sort (HARNESS-B) | `glass_apply()` becomes two passes — `blend_mul` for the tint, `blend_add` for the sheen. The live framebuffer already holds everything behind the glass, because Y-sort put it there |
| the front-wall bug | fixed | fixed |
| an opaque wall **behind** a pane, same level | ⛔ **lost** — the snapshot only holds lower levels, so it vanishes through the glass. This is `F2` in a smaller form | ✅ correct, by construction |
| `G-D2` "one surface" | preserved exactly | ⚠️ 16 texels per level seam tint twice — a faint 1 px line, 23 of them on a 3-storey pane. Fixable at the atom's edge, but a look call first |
| `G-D1` (multiply + add, never plain alpha) | untouched | preserved, at two passes instead of one; the `max()` "not a black hole" floor (`glass_min_body`) has no fixed-function equivalent and would need re-designing |
| cost | 24 rect copies (`RO3`'s arithmetic still applies) | zero backbuffers — **cheaper than today** — but 2× glass draw submission |

Both are buildable. The choice is not an engineering one: it is which ratified
ruling gives, so it is the Director's.

⚠️ **Q2 then made both of them moot** — they share `RO1`'s Y-sort, which is what
failed. They are kept above because the trade they describe is real and comes back
the moment anything proposes reading the screen from inside the depth order.

### 6.3 OPTION C — the split-layer board *(measured 2026-09-10, PASSES, needs sign-off)*

Q2's failure has a shape: Y-sort pays to discover, per frame, an ordering that
**is already known at map load and never changes until the map or the view does.**
So do not discover it — author it.

**A pane is planar.** Every opaque cell at a pane's level is either nearer than
that plane or farther, and which one is a scalar comparison in view space
(`x + y`, `O5`'s canon depth — the same rule `floating_collectible` already uses).
So the level's opaque cells split into two layers around the glass, and the
scene TREE does the ordering that Y-sort was being paid to redo every frame:

```
    opaque_far  →  BackBufferCopy  →  glass  →  opaque_near
```

all at the **same `z_index`** (the level's own, `RO1` intact), no Y-sort anywhere.

**Q6, measured:** `opaque_clean=1664` · `probe_saw=512` · `probe_blind=0`. All
three properties at once —

| | |
|---|---|
| the near wall covers the pane | ✅ the bug is fixed |
| a wall BEHIND the pane composites THROUGH it | ✅ — **Option A could not do this** (`F2`), and this is better than the design that was rejected this morning |
| the `G-D2` container | ✅ preserved exactly — one snapshot, tree-ordered, `G-D1` untouched, no two-pass shader, no atom rework |
| draw-call cost | one extra `TileMapLayer` per glass-bearing level. A split PARTITIONS a level's cells, it does not duplicate them — nothing like Q2's +244% |

**What it costs and what is still open:**

- **Backbuffers: one per glass DEPTH BAND per glass level.** `RO3`'s
  `COPY_MODE_RECT` arithmetic applies unchanged and is still unmeasured — that is
  the one number Task 2 owes.
- **More than one pane depth on a level generalises it, and the generalisation is
  small.** GLASS has panes at `y=9` and `y=6` on the same levels, so that level
  needs bands, not a single split: sort the level's glass by depth, and emit
  `opaque | backbuffer | glass` once per band. `N` is the number of distinct glass
  depths at that level — 1 to 3 in practice, and it is **countable at map load**,
  so a map that would be expensive is a map the authoring check (§8) can name
  before anyone plays it.
- **Rotation is safe and this is why it is the right shape** (`RO0b`): the split
  is a view-space depth comparison, and the board is already rebuilt on a flip, so
  the bands are re-derived exactly where every other view-space fact already is.
  Nothing is cached across a rotation.
- **X-ray / thermal stay possible** (`RO0d`): per-level `z` is untouched, so
  `get_max_voxel_z_index()` still anchors a top-`z` actor instance.

⚠️ **This is a NEW DESIGN, not a variant of what was signed off.** It needs the
Director before Task 2 starts.

### 6.4 THE CONTAINER'S PRICE — measured 2026-09-10 (Option C approved, this was its one open number)

Director approved Option C and asked for this first. Gate `INFILTRAITOR_GLASS_BB`,
default OFF (unset = today's single `COPY_MODE_VIEWPORT` copy, untouched):
`none` = no copy · `rect` = one `COPY_MODE_RECT` per glass LEVEL · `rect<K>` = K
per level, a stress knob.

**A second instrument had to be built first.** `INFILTRAITOR_NO_VSYNC=1` disables
vsync inside the frame probe. With vsync on, `ms/frame` reads 16.7 for anything
that fits in a refresh, so a change costing 3 ms and one costing nothing print the
SAME number — fine while the question is CPU (Q2's `render cpu` column still
moved) and useless the moment the question is GPU, which a `BackBufferCopy` is
almost entirely.

**First sweep — and it was not an answer.** GLASS and PLAYGROUND, 0 / 1 / 24 / 48
copies, all landed between 6.2 and 6.5 ms, and `none` (ZERO copies) came out
*slower* than today on both maps. A floor that is not the lowest reading is not a
floor: the whole spread was run-to-run noise, and "inside the noise" is not the
same claim as "free".

⚠️ **`none` is probably not a real zero and is NOT relied on here.** Godot inserts
a backbuffer of its own for a material that declares `hint_screen_texture`, which
`glass_pane.gdshader` does — so removing the NODE likely does not remove the COPY.
Unverified, and the argument below is built so it does not matter.

**So the count was driven until the curve bent.** GLASS, 1500 frames, vsync off,
same binary, M1 / Metal, window 1280×720:

| copies | ms/frame | render cpu | vs baseline |
|---|---|---|---|
| **1** (today, full viewport) | **6.3** | 3.1 ms | — |
| **24** (one per glass level) | **6.4** | 3.1 ms | **+0.1 ms** |
| **48** (two per level — the multi-band case) | **6.4** | 3.1 ms | **+0.1 ms** |
| **192** | **12.4** | 3.3 ms | **+6.1 ms** |
| **480** | **28.7** | 4.0 ms | **+22.4 ms** |
| **960** | **54.5** | 4.6 ms | **+48.2 ms** |

The shape: flat to ~50 copies, then linear at **0.042** ms/copy (48→192),
**0.057** (192→480) and **0.054** (480→960). The first fifty are absorbed; after
that every copy is charged, at a stable ~0.05 ms each. Three consistent slopes
across a 20× range is what makes this a curve rather than four readings.

> **Option C's container is affordable, with roughly 4× headroom over what it
> needs.** 24 and 48 copies are indistinguishable from one; 192 costs most of a
> frame. `render cpu` barely moves across the whole range (3.1 → 3.3), which
> places the cost on the GPU side exactly where a blit belongs — and is why the
> vsync instrument had to exist before the question could be asked at all.
>
> ⚠️ **The measurement is CONSERVATIVE, and by accident rather than design.** The
> per-level rect is computed from `TileMapLayer.get_used_rect()`, which is the
> union of ALL glass on that level — every pane on the map, not one. Average rect:
> **6 453 675 world px²** against a **0.92 Mpx** viewport, so each "rect" copy was
> clipped to the full screen. **What was priced is 24 and 48 FULL-VIEWPORT copies**,
> not the bounded ones Option C would actually emit. The real design is cheaper
> than this table, never more expensive.
>
> ⚠️ **This is an M1 at 1280×720, not a phone.** The `project.godot` base viewport
> is 390×844 with `stretch/mode="canvas_items"`; the window under test ran at
> 1280×720. A tile-based mobile GPU can charge a fixed tile-flush per copy that an
> M1 absorbs, and nothing here measures that. **The headroom is the finding, not
> the absolute number** — 4× between what the design needs and where the curve
> bends is what makes it worth building; a device run is still owed before ship.

**What this buys the design:** the band budget is a real number now. Option C
emits one copy per glass DEPTH BAND per glass level, countable at map load — so
the authoring check (§8) gains a second job: warn when a map's band count
approaches the budget, long before anyone feels it.

---

---

## 7. TASK 2 — the build (Option C, Director-approved 2026-09-10)

⛔ **Designs A and B below are HISTORY.** They both rode `RO1`'s Y-sort, which Q2
priced out of the project (§6.1). The approved build is **Option C, §6.3** — the
split-layer board — and its one open number came back affordable (§6.4). The
steps:

1. **The band split, at map load.** Per glass-bearing level, sort that level's
   glass by view-space depth (`x + y`, `O5`'s canon) into bands. `N` bands ⇒ the
   level emits, in tree order at ONE `z_index`:
   `opaque(behind band 1) → bb → glass(band 1) → opaque(between 1 and 2) → bb → glass(band 2) → … → opaque(in front of the last)`.
   Derived, never authored, and re-derived on a rotation with everything else in
   view space (`RO0b`, `RO5`).
2. **The opaque layer of a glass-bearing level splits into `N+1` layers.** A split
   PARTITIONS that level's cells; it does not duplicate them. Levels with no glass
   keep exactly one layer and are not touched.
3. **One `COPY_MODE_RECT` `BackBufferCopy` per band**, bounded to that band's own
   screen extent — ⚠️ **not** `TileMapLayer.get_used_rect()`, which is the union
   of every pane on the level and is what made §6.4's measurement price
   full-viewport copies. Bounding it properly is strictly cheaper than the number
   that was approved.
4. **`RO2`** — the glass layers leave the flat top-`z` for their level's own `z`;
   delete `_glass_composite_z`, `_glass_composite_z_floor`, `set_glass_over_z()`
   and the `room.gd` call. `G-D18b` stays relaxed.
5. **Re-home what rides the composite `z`**: `_glass_crack_root` (G-D27 craze
   sprites, `layer.z_index + 1`), the shard field, and the glass rain
   (`room.gd:709`, `layer.z_index + 2`) — each into its own band.
6. **The band count is a budget.** §6.4 measured flat to ~50 copies and linear
   after; the authoring check (§8) reports a map's total band count so a map that
   would cost is named at load, not felt in play.
7. **`glass_transparency_selftest`** — the container assertion changes shape (one
   copy per band, not one globally) and **must not weaken**: it still has to fail
   if a pane can double-tint.
8. **Retire the measurement gates** (`INFILTRAITOR_YSORT`, `INFILTRAITOR_GLASS_BB`)
   or keep them deliberately, with a note saying which. `INFILTRAITOR_NO_VSYNC`
   is worth keeping — it is the only way `ms/frame` answers a GPU question.

⚠️ **Still owed before ship, and not by this plan:** a real device run. §6.4 is an
M1 at 1280×720, and a tile-based mobile GPU can charge a fixed tile-flush per copy
that an M1 absorbs.

### 7.1 T2-1 — BUILT 2026-09-10, behind `INFILTRAITOR_DEPTH_BOARD=1` (default OFF)

Option C end to end for **one band per level**. The bug is fixed on screen; the
gate stays off until the Director has looked.

**⚠️ The overlay, not the split — and this is a deliberate departure from §7 step 2.**
Partitioning a level's opaque cells into two `TileMapLayer`s is the literal reading
and it is the wrong one here: **in this project the tilemap is the authoritative
state, not a picture.** 28 internal sites read `_layers[level]` / `get_layer(level)`
and `INFILTRAITOR_CELL_PROBE` answers "is there a voxel here" from it, so a migrated
cell would silently vanish from every one of them. So `_layers[level]` keeps every
cell it has and a **render-only overlay redraws only the NEAR ones after the glass**.
Opaque pixels overwrite, so the result is identical — measured, not argued: spike
**Q7** (overlay) returns the same counts as **Q6** (true split),
`opaque_clean=1664 probe_saw=512 probe_blind=0`. Cost: near cells rasterise twice.

**⚠️ Depth is per SCREEN COLUMN, not one scalar threshold.** `x + y` orders cells
but only ORDERS ones that overlap on screen, and a pane is a long run whose cells
span a wide range of `x + y`. A single split at the pane's nearest cell leaves a
wall overlapping the pane's FAR end ~50 below the threshold and never promoted —
most of the bug still on screen. So the level's glass is indexed by column
`u = x - y` and compared per column. (This was caught by arithmetic before the
first capture, not by looking.)

**⚠️ `COPY_MODE_RECT` was tried and dropped.** It rendered every pane as a flat navy
slab: `behind` came back black and `glass_apply()` fell to its `glass_min_body`
floor. Isolated in ONE run by switching only the copy mode on the same tree at the
same z — viewport correct, rect black — so the fault is the rect computation, not
the ordering. Dropped rather than fixed, because §6.4 already priced 24 full-viewport
copies at +0.1 ms and the curve does not bend until ~50. **Revisit only if a device
run says otherwise**; a known-wrong path left armed behind an env var is a trap.

**Evidence** (`Screenshots/history/depthboard_{before,after}_{N,E,S,W}.png`, named so
the rotation cannot eat them):

- The repro is FIXED. W view, the wood pillar and the concrete wall were washed
  with the pane's blue tint and are now solid, with the glass behind them.
- **Rotation re-derives it for free** (`RO0b`, `RO5`): the promoted-cell count moves
  per view — 8 186 (N) · 7 162 (E) · 7 974 (S) — with no rotation-specific code.
- Changed pixels vs the old board: N 67 118 · E 61 053 · S 87 362 · W 110 572.
- Gate OFF prints nothing and builds nothing — verified on a clean boot.

**⚠️ Open, and it is a look call rather than a bug hunt:** the promoted /
not-promoted boundary shows a **per-voxel sawtooth** on a wall edge adjacent to a
pane. The obvious suspect was the column reach and it is NOT: `COL_SPAN` 2, 4 and 8
give pixel-identical boundaries and differ only in overdraw (8 186 / 8 844 / 9 448
cells), so the reach is pinned at the cheapest. The sawtooth is the promotion's own
voxel granularity at the boundary.

**Owed by T2-2, and the reason the gate is off:**
1. **Invalidation.** `rebuild_depth_board()` currently fires only when a glass
   sublayer is created. Destruction that removes a wall or a pane does not
   invalidate the overlay, so a level's front set can go stale mid-event.
2. **T2-3's re-homing is not done**, so under the gate a CRACK-02 craze sprite still
   rides `_glass_composite_z` and draws above the walls.
3. The sawtooth look call.
4. `set_glass_over_z()` is a no-op under the gate rather than deleted, and
   `room.gd` still calls it.

---

---

## 7b. Designs A and B — superseded, kept for the trade they describe

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
