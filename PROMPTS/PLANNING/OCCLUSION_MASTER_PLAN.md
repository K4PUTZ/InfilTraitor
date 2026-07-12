# OCCLUSION_MASTER_PLAN
## Seeing the Agent — View Occlusion, Agent Silhouette, Interior Cutaway — v1.0

**Status:** 🔵 DRAFTED 2026-07-12, not started. **Runs BEFORE
`DESTRUCTION_MASTER_PLAN`** (Director's call, 2026-07-12): it is independent of
destruction, it is the visible win, and it is the cheaper of the two.
**Baseline:** tag `verified/v0.8.2`.
**Companions:** `DESTRUCTION_MASTER_PLAN.md` (which owns `Voxel.visible` — see §2),
`docs/technical/BAKE_SYSTEM_REFERENCE.md`.
**Authored by:** the Overlord, from the Director brainstorm of 2026-07-11/12.

---

## 1. Why — and what "occlusion" actually means here

The design goal, in the Director's words: **"the player sees what the agent
sees."** The player has access to what is in the agent's room — not what is
behind it.

But "occlusion" is being used for **three different problems**, and only one of
them is occlusion. Separating them is most of the work:

| # | The complaint | The actual fix | Touches voxels? |
|---|---|---|---|
| **(a)** | "I can't see my agent behind a wall." | Draw the agent **on top of everything**, with a **stroke on the part of his silhouette that is behind geometry** — the whole silhouette behind a wall, legs-to-waist behind a crate. Reveals exactly one thing: your own guy. | ❌ No |
| **(b)** | "I can't see inside a building." | **Slab cutaway by level** — the ceiling Slab's layer is hidden. Here the reveal is *intentional*: entering the building is the reward for infiltrating it. | ❌ No |
| **(c)** | "Foreground geometry is covering the agent." | **This is real occlusion.** Ghost the geometry between the agent and the camera. | ❌ No (see O1) |

**None of the three touches voxel state.** That is the plan's spine.

---

## 2. O1 — Occlusion is VIEW, not STATE (the load-bearing decision)

**This is the one that, if broken, produces a save-corrupting bug nobody will
find for months.**

`Voxel.visible` **already has an owner**, and it is destruction:

```gdscript
## Apply damage state; DESTROYED forces visible=false
func set_damage(new_state: int) -> void:
    ...
    if new_state == DamageState.DESTROYED:
        visible = false
```

| Concern | Owns | Persists? | Cadence | May write `Voxel.visible`? |
|---|---|---|---|---|
| **Destruction** | `Voxel.visible`, `damage_state`, `blocked_cells`, cover, noise | **Yes** — world state, enters the save | Per detonation (rare) | ✅ **Sole writer** |
| **Occlusion** | `_occluded_cells` — its own set | **No** — a camera artifact | Per agent step + per camera rotation (**frequent**) | ❌ **Never** |
| **Fog of war** | Scenery discovery | Yes | Per agent step | ❌ Never |
| **Actor visibility** | The **agent-knowledge system** (radar / noise / line of sight) — a separate front | Yes | Per turn | ❌ Never |

**The bug this prevents:** occlusion ghosts a wall by setting `visible = false` →
the TIC erases the cell → the player **rotates the camera** → occlusion releases →
`visible = true` → **and a destroyed voxel resurrects.** It only ever reproduces
when someone rotates the camera over a crater, which is why it would survive
months of testing.

Occlusion also **never uses the dirty flag**. Its cadence is wrong for it: a
detonation is rare and capped; an agent step is *constant*. Routing occlusion
through `process_dirty()` would make the common case far more expensive than the
rare one — exactly backwards.

### O2 — Cross-plan contract: actors are not hidden by geometry

**An actor the agent does not know about is not drawn.** Actor visibility belongs
to the agent-knowledge system (radar, noise, line of sight — a separate front),
**never** to geometry.

This is what makes wall transparency *structurally incapable* of leaking enemy
positions: ghosting a wall cannot reveal a guard, because a guard the agent does
not know about was never rendered in the first place. The guarantee is by
construction, not by luck.

**If anyone ever makes actor rendering depend on geometry occlusion, this
guarantee dies silently.** That is why it is written here.

---

## 3. Decision Register

| O | Decision | Status |
|---|---|---|
| **O1** | **Occlusion is VIEW, not STATE.** Never writes `Voxel.visible`, never uses the dirty flag, never persists, never enters the save. State lives in `_occluded_cells`, owned solely by the occlusion system. See §2. | ✅ Ratified |
| **O2** | **Actors are hidden by knowledge, never by geometry** — cross-plan contract, §2. | ✅ Ratified |
| **O3** | **The occluded region is an enlarged circle around the agent**, keeping only geometry **between him and the camera**. **Not "everything south of the agent"** — fading the whole southern half would reveal the *neighbouring* room's interior, which contradicts "the player sees what the agent sees". The criterion is **"is it covering him"**, not "is it south". | ✅ Ratified |
| **O4** | **"Between agent and camera" is evaluated in the CURRENT VIEW'S ROTATED FRAME.** The map has four views (W/N/S/E) and the formula rotates with them. | ✅ Ratified |
| **O5** | **Depth is NOT `z_index`.** `layer.z_index = _wall_base_z_index + level` encodes **storey**, not depth — a wall in front of the agent and a wall behind him, on the same storey, share a z-index. Depth in isometric comes from world position (`x + y` in the rotated frame) / y-sort. **Selecting occluders by z-index would ghost every upper storey *including everything behind the agent*** — the exact opposite of the goal. | ✅ Ratified |
| **O6** | **Concentric ghost rings — 5% / 25% / 50% alpha — via TileSet alternative tiles.** Godot's `TileData` carries a `modulate` **per alternative tile**, and alternatives **reuse the same atlas region**: a ghost variant costs **not one extra pixel** of memory. Rings give a **stepped feather** that reads as smooth at 32 px cells — **at zero memory and zero per-fragment cost**, which means it needs no sign-off against the mobile budget (D12, `OVERLORD_CONTEXT.md`). A true gradient feather would require a **shader** (per-fragment); if headroom later proves plentiful, swapping rings for a shader changes nothing else — **the occluded-cell set is identical**. *(Director's design; the alternative-tile mechanism is what makes it free.)* | ✅ Ratified |
| **O7** | **Agent drawn on top, with a silhouette stroke over the occluded portion.** Whole silhouette behind a wall; legs-to-waist behind a crate. **No character animations exist yet** → v1 ships a **placeholder bounding box** at standing-character dimensions. The real silhouette is a future milestone. | ✅ Ratified |
| **O8** | **Interior cutaway is DEFERRED — it depends on `Slab`**, which is `DESTRUCTION_MASTER_PLAN` D1. **No map has a ceiling today**, so there is nothing to cut away: this is a fact, not a limitation. Part 4 is written but does not start until Slabs exist. | ⏸️ Blocked (by design) |
| **O9** | **Ceiling-hung props and foreground parallax decoration** also need occluding — same mechanism, different layer. **Not implemented yet, so not in this plan.** Future milestone. | ⏸️ Deferred |

---

## 4. Mechanism — how it actually works

**Step 1 — Who occludes (CPU, tiny).**
The set of cells that (i) fall inside an enlarged circle around the agent and
(ii) sit between him and the camera in the current view's rotated frame. A few
dozen cells. Recomputed on **agent step** and on **camera rotation** — never per
frame.

**Step 2 — How to paint it (zero extra memory).**
Placement already passes the alternative index:

```gdscript
_voxel_layers[level].set_cell(pos, source_id, atlas_coords, 0)   # ← this 0
```

Ghosting a cell is **changing that one argument** to point at a ghost
alternative. Three ghosts (5% / 25% / 50%) → three concentric rings. No shader.
No new atlas. No per-fragment cost.

**Step 3 — Where the state lives.**
`_occluded_cells`, owned solely by the occlusion system (O1). When the set
changes, the cells that left it are restored to alternative `0` and the ones that
entered are set to their ring's ghost. Nothing else in the engine is told.

---

## 5. Parts

### Part 1 — The occluded-cell set *(O3, O4, O5)*
Compute, per agent step and per camera rotation, the set of cells between the
agent and the camera inside the circle, **in the rotated frame**. Pure
computation — no rendering change, verified by a debug overlay that paints the
set. **This is the novel geometric piece and it lands alone**, per the
prompt-sizing rule.

### Part 2 — Ghost rings *(O6)*
Three ghost alternatives on the voxel TileSet; placement swaps the alternative
index for cells in the set. Verified with a real screenshot: the agent visible
through ghosted geometry, rings legible, nothing else on screen changed.

### Part 3 — Agent on top + silhouette stroke *(O7)*
Placeholder bounding box at standing-character dimensions. Stroke only over the
portion actually behind geometry.

### Part 4 — Interior cutaway *(O8)* — **does not start until `Slab` exists**
Ceiling Slab layer hidden when the agent is inside. Blocked on
`DESTRUCTION_MASTER_PLAN` Part 1 by construction; no map has a ceiling today.

---

## 6. Wave sequencing

```
Wave 1:  Part 1 (occluded-cell set)   → novel geometry, lands and is verified alone
Wave 2:  Part 2 (ghost rings)         → consumes Part 1
Wave 3:  Part 3 (agent on top)        → independent of 1–2, can run in parallel
Wave 4:  Part 4 (interior cutaway)    → BLOCKED until DESTRUCTION Part 1 (Slab)
```

**Screenshot session: ON for the whole plan.** Every part of this is visual;
every completion report must point at a real capture in `Screenshots/history/`.

---

## 7. Open questions

1. **Does the ghost alternative compose with per-cell transform flags?** In Godot 4,
   flip/transpose are encoded as bit flags inside `alternative_tile`, while a
   modulate ghost is a distinct alternative id. **They may not combine.** This does
   not bite in v1 — walls use no symmetry variants, and floors never occlude — but
   it must be checked before anything needs both on one cell.
2. **The circle's radius and ring widths** are tuning, not architecture. Expose them
   as debug-adjustable and let the Director dial them against a real screenshot.
