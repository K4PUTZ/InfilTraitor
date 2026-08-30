# RESUMO_SESSAO — 2026-08-30 · THE GLASS DESIGN

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-30_STATE_OF_THE_PROJECT.md`
**Kind:** design session — **no gameplay code changed.** Two documentation commits.
**VERSION:** unchanged at 0.9.107.
**Commits:** `7afb4530` (the plan) · `f4dc2bb7` (G-D9 + the §9 reversal). Both pushed.

> Director, opening: *"Ok, vamos trabalhar o vidro então, e depois a gente organiza
> a documentação toda."*

---

## 0. Where this picks up

The previous session closed the explosion arc and left five tracks with nothing
technical ordering them. The Director picked **glass** — `MATERIALS` M4, and the
one explosion follow-up he had named explicitly.

**Deliverable: [`PROMPTS/PLANNING/GLASS_MASTER_PLAN.md`](PLANNING/GLASS_MASTER_PLAN.md), v1.1, design ratified, unbuilt.**
It owns `MATERIALS_MASTER_PLAN` M4a/M4b in detail; that plan keeps the milestone row
and now points here.

## 1. Nine decisions, three of which amend earlier canon

| # | What | Amends |
|---|---|---|
| G-D1 | Transparency is a **blend**, never alpha — MUL for the tint, ADD for the highlights | — |
| G-D2 | A pane is one continuous surface; **a block is a block** | — |
| G-D3 | **Glass CRACKS** | ⚠️ D22's hole-or-nothing |
| G-D4 | A shot's **neighbours** may crack on glass — a web is one fracture spanning cells, not a spray of holes | ⚠️ D30.1 (glass only) |
| G-D5 | The round **passes through** and strikes what is behind | ⚠️ the reading of D28 |
| G-D6 | Shards are **game state**, not decoration | — |
| G-D7 | Seeing through glass is a **roll** — proximity × pane count × light differential | — |
| G-D8 | A broken pane opens a passage, barely moves the light, +1 detection step | — |
| G-D9 | **A slice can be multi-material** (sparse per-level bands) | ⚠️ §9's own first recommendation |

**G-D3 pays for itself.** It converts two defects the milestone was carrying open
into intent — the far shotgun pellet that already CRACKED glass against D22, and
the empty DENTED band that was a coincidence of `DESTROY_MIN["glass"]` and
`PUNCH_DENT_MIN` both being `0.30` (now to be **pinned by a selftest** rather than
left as an equality two edits could break). And it **removes work**: M4b said glass
needed `HOLE_ONLY_MATERIALS` *and* a new `INTACT` return *"together, or neither"*.
Neither is needed now — glass marks, so it is not hole-only; and *"não feito"* is
gone, because a weak hit cracks. The ladder is CRACKED → (never DENTED) → DESTROYED.

## 2. Three seams found by reading, each of which resized something

**Method note:** every row below was read out of the file named. None was
remembered, and two contradicted what the existing plans said.

1. **The pane grouping was never an open question.** `DESTRUCTION_MASTER_PLAN` §7
   called *"what is a whole window?"* the decision that sets how big M4 is. It
   stopped being open when M3-2b shipped: `Slice.edge_id` is a field, and
   `voxel.container_id() → Slice → edge_id` reaches every voxel of a surface in O(1).

2. **`PassageQuery` is complete, correct — and nobody listens.** Its only two call
   sites are a `print` and a `print_debug` in `room.gd`. `_current_blocked_edges`
   comes from the compiled `view_layout` and is refreshed only on load and rotation.
   **Destruction has never opened a passage, for any material.**

3. **Nothing in this game has ever made a sound.** `NoiseSystem` is complete and
   instantiated (`room.gd:1401`), the overlay is wired and `decay_all()` runs at end
   of the enemy phase — and **`emit()` has zero call sites**, so `get_intensity()`
   has always returned 0.0. Worse, the noise→detection bonus
   (`turn_controller.gd:200`) is gated `and result.visible` — **noise counts only
   when the guard already sees you**, which is backwards for stealth.

**A fourth, structural:** vision reuses the movement edge set (`can_see_cell()`
takes `blocked_edges`), and a blocked edge is `{"from", "to"}` with **no material**.
So glass blocks sight exactly like concrete today, and glass is the material that
forces "blocks the body" apart from "blocks the eye".

## 3. The reversal — §9, rewritten the day it was written

The plan shipped in the morning recommending several **single-material** slices
keyed `(gu, face, level_start)`, and rejected the multi-material slice because it
would *"turn a field into a query in dozens of call sites."*

**That number was asserted without counting.** The Director's `WINDOWS.png` diagram
prompted the count:

| | |
|---|---|
| slice-material reads in non-test code | **16**, not "dozens" |
| of those, sites that **already hold the `Voxel`** | **9** |
| `BakedTileLookup.resolve(edge, face, voxel_xy, level, column_in_run)` | **already takes the level** |
| `_compute_facade_key(material, facade, column, level, dir)` | **already keyed on both** — two materials on one face collide on nothing |
| lines to change in the bake seam | **2** (`:259`, `:415`) |

Nine of sixteen read the material off the slice **only because `Voxel` has none**.
So the recommendation is reversed, and **the reversal is left visible in §9 rather
than edited away** — a plan that hides its own turn teaches nobody anything.

**Shape:** `Slice.material` stays as the base material; `Slice.material_bands`
(sparse `level → material`) plus `material_at(level)`. A single-material wall pays
**zero bytes**, which is the point — RAM is the constraint, not CPU (D42).

**The real cost is named, with its failure mode:** `_group_edges_into_runs()` groups
collinear edges **horizontally** so a facade stays continuous across GUs
(`column_in_run`); a multi-material slice cuts **vertically**. The run must become
per material band. ⚠️ **A wrong run throws no error — the texture simply restarts
mid-wall.** Only a capture catches it. Smaller gap recorded alongside:
`JunctionColumn` takes one material for a whole corner column.

## 4. A vocabulary collision, closed

The project had a documented ambiguity on the word *slice*. The diagram settles it:

| Diagram | Code |
|---|---|
| one stacked piece ("slice") | a **level band of 8** inside a `Slice` |
| the red box ("container / high wall") | the **`Slice`** — one face, every storey |
| — | `HighWallGroup` ⚠️ **is neither** — it groups edges *horizontally*, at bake time |

**No new container is needed.** The `Slice` already is the red box.

## 5. Scope — what is in the plan and what is not

**IN (nine tasks, §10):** G1 transparency · G2 `pane_id` · G-ART the art order ·
G5 the CRACKED tier · G3 the pane cascade · G4 frame remnants · G6 shards ·
G7 pass-through · G-D4's bullet web.

**OUT, each with an owner:**

| Deferred | To | Director's words |
|---|---|---|
| The window's **authoring** | scenario applications | *"Não precisa fazer a janela ainda, vamos só trabalhar na física do vidro"* — the CAPABILITY is now designed (G-D9); only how a mapfile spells it is open |
| Shard **noise** | the sound milestone | *"Ainda não implementamos o som, ele vai ser uma parte crucial do jogo, inclusive com interface visual no cenário"* |
| The **see-through roll** (G-D7) | scenario applications | needs two rooms and a window between them to mean anything |
| The agent **crossing** a broken pane | movement milestone | *"fazer o agente atravessar, na milestone de movimentação"* |

⚠️ **The risk this creates, written down rather than hoped away.** Under G-D6 shards
are state whose *gameplay* consumer is deferred — the exact shape of the two
features this project has already shipped built-and-never-triggered (the noise
indicator and the exposure labels). The mitigation is structural, not optimistic:
**the floor decal puts shards on screen from day one**, and a state that is visible
cannot rot unnoticed.

## 6. NEXT SESSION — start here

**Ratified with the Director, not yet begun: G1 — transparency.** First in the task
order, depends on nothing, and answers the first sentence of his brief.

**What G1 is.** Glass cells move to their own `TileMapLayer` per level, drawn
immediately after that level's opaque layer, created **lazily only for levels that
contain glass**. Two sublayers: **MUL** for the tint (keeps the facade's pattern
instead of averaging it away) and **ADD** for the highlights. Architecture Rule 8
holds — the voxels still arrive through `set_cell()`; only the layer's compositing
changes.

⚠️ **The known risk, stated before it is discovered:** `voxel_face_shading.gdshader`
differentiates the three faces by **multiplying**. On an ADD layer that means
something else, so the glass sublayers need their own shader variant.

**The two conditions the Director agreed to, and they are obligations:**

1. **The calibration is not the agent's to choose.** MUL strength against ADD
   strength is what separates "office window" from "shop front"; glass's
   `base_color` is `[0.62, 0.74, 0.78]` today. Build a strip of variants **in one
   boot**, over PLAYGROUND's two glass panels — and **shuffle the order and hide the
   labels**, because a judged render in this project has already kept returning
   "the last one" when the instrument was the thing at fault.
2. **The capture needs a control.** Hand-named, outside the `auto_` rotation so a
   citation survives, plus a same-boot control — a screenshot alone cannot tell
   *"did nothing"* from *"did it with low contrast"*.

**Test bed, already in the map:** the two glass panels at `(25,8) SE` and
`(29,8) SW`, 2 storeys each, and the glass block at gu x=38. Current state for the
before-side: `Screenshots/history/mat_block_02_lit_five_materials.png`, where the
glass block reads as a fully opaque pale blue-green solid.

**After G1, in order:** G2 (`pane_id` — union-find for panels, occupancy flood fill
for blocks, since **no block id survives extraction**, §4.2) and G-ART (the art
order, with `check_decal.py` coverage earned **before** the art, the way M2a was).

**One thing to open before writing G-ART:**
`REFERENCES/bullet-hole-transparent-glass-abstract-background-*.zip` — the Director
collected glass bullet-hole reference on 2026-08-02, a month before this plan
existed.

**One question left open in the plan, for the Director:** in the finished window the
black mullion grid appears to fall exactly on the geometry — horizontals at storey
boundaries, verticals at GU boundaries. If that reading is right the muntins come
free; if not, G-ART owes a fifth decal family. Marked in §9.1 as an observation, not
a rule.

## 7. Files changed

`PROMPTS/PLANNING/GLASS_MASTER_PLAN.md` (new) ·
`PROMPTS/PLANNING/MATERIALS_MASTER_PLAN.md` (§4 header + task rows 8/9 point here;
`HOLE_ONLY_MATERIALS` + INTACT marked no longer needed) · `docs/README.md` (one new
index row, updated for v1.1) · this file.

**Not changed, deliberately:** no `.gd` file was touched this session. Every gate
(`check_invariants.py`, CODEMAP freshness, `project_lint.py` over 219 files) passed
on both commits.

**Reference delivered by the Director:** `REFERENCES/WINDOWS.png` + `.psd`
(2026-08-30). ⚠️ `REFERENCES/` is gitignored (`.gitignore:47`), so the diagram is
**transcribed into §9.1** rather than only linked — another machine will not have
the file.
