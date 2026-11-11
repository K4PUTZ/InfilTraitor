# Session 2026-09-07 — the shockwave zone, and four things that never noticed the world had changed

Previous session:
[`RESUMO_SESSAO_2026-09-06_GLASS_CLOSE.md`](RESUMO_SESSAO_2026-09-06_GLASS_CLOSE.md),
whose §1 recorded the one thing still owed: **CASE TESTING**. This session is that
testing. It opened with *"Vamos fazer a calibração final no dano/alcance do vidro"*
and produced two rulings plus **four separate bugs, every one of them the same
shape**: the world changed and something kept answering from the old state.

Five commits. `GLASS_MASTER_PLAN` v1.46 → **v1.47**, `MATERIALS_MASTER_PLAN` v1.8 →
**v1.9**, `TARGETING_MASTER_PLAN` gained **§5b** and **§5c**.

| | commit |
|---|---|
| G-D48 the shockwave zone + G-D49 re-damage collapses locally | `9c0ef3dd` |
| a map reload (F2) must wipe the previous mission's glass debris | `6d16d2ff` |
| the throw stops at walls, and a skill seam for its range | `668e7024` |
| the aim bubble and blast flood follow the damage | `4108e0ff` |
| a pane taken in an extended ring must be ERASED, not just recorded | `65124a35` |

---

## 1. ⛔ RESUME POINT — WHAT IS NOT DONE

**The G-D48 ramp values are placeholders and the Director has not calibrated them
on screen.** `GLASS_SHOCKWAVE_FALLOFF` and `GLASS_CRAZE_FALLOFF` were chosen to
satisfy the one case he reported (a grenade at GU 18,11 must destroy the panes out
to 15,10 and 21,10) and verified there; the shape of the ramp between is a guess.
`INFILTRAITOR_GLASS_RING_DIAG=1` prints per-pane ring / probability / outcome, and
every constant is a `static var`.

**Also open, and named rather than hidden:**
- **Opaque-wall passages are still not wired for MOVEMENT.** `build_movement_edge_set()`
  only asks `PassageQuery` about GLASS edges. A blown concrete wall now opens the
  grenade's blast flood (via `_blast_opened_edge_keys()`) but the agent still cannot
  walk through it — the `PASSAGE_MIN_REMOVED_FRACTION` machinery is built and reaches
  only a diagnostic print for non-glass. This is the *"abertura de passagem"* the
  Director keeps pointing at.
- **The throw does not arc over a parapet.** A low wall blocks it exactly like a full
  one. `room._wall_height_edges` carries the height that would fix it.
- **Only GLASS was audited for the F2 reload leak.** Soot, crater-floor scorch and
  damage-mark decals were not checked.

---

## 2. The two rulings

### G-D48 — the SHOCKWAVE ZONE (`9c0ef3dd`)

> *"precisamos ampliar a area de alcance do dano efetivo de granadas — somente sobre
> o vidro […] Podemos chamar essa zona de shockwave […] estende a destruição para 5
> GU no total, com rampa descendente de dano, e estende também a zona onde os vidros
> racham, mais 2 GU pra fora."*

Measured first, from his own case. Grenade at GU (18,11) on GLASS:

| slice | GU | ring | P(shatter) before | outcome |
|---|---|---|---|---|
| `SLICE_16_10` | 16,10 | 2 | 0.259 | crazed only |
| `SLICE_20_10` | 20,10 | 2 | 0.259 | crazed only |
| `SLICE_15_10` | 15,10 | 3 | 0.259 | crazed only |
| `SLICE_21_10` | 21,10 | 3 | 0.259 | crazed only |

**RETIRES** `SHATTER_BLAST_GAIN`, `SHATTER_BLAST_EXTRA_RINGS`, `glass_ring_multiplier()`,
`blast_glass_punch()` and the bullet logistic on the cook path. The cook reads two
GLASS-ONLY per-ring tables directly:

- `GLASS_SHOCKWAVE_FALLOFF = [1.0, 1.0, 1.0, 0.90, 0.60, 0.35]` — index is the ring,
  and the **value IS the shatter probability**; it also scales the region radius over
  `SHOCKWAVE_REGION_MIN..MAX` (6..50 pane-lattice voxels).
- `GLASS_CRAZE_FALLOFF = [1.0, 0.90, 0.75, 0.60, 0.45, 0.30, 0.20, 0.12]` — two GU
  longer.

`BlastCalculator.flood_gu_rings()` gained `min_max_ring`; only `_shatter_glass_panes()`
passes it (`glass_blast_max_ring()` = 7), re-flooding and re-running
`find_affected_containers()` for glass panes alone. That is the deliberate flood
extension `SHATTER_BLAST_EXTRA_RINGS`'s own note said had to happen before the reach
could grow past the bomb's table — G-D46 is superseded by it.

**Verified:** from (18,11) both target panes roll p = 1.0 and shatter whole (1152 and
469 voxels); far panes craze out to ring 7.

### G-D49 — re-damage on a crazed pane collapses LOCALLY (`9c0ef3dd`)

> *"Qualquer dano novo num painel ja rachado, como um tiro, colapsa as slices
> proximas a esse dano. Mas não precisa necessariamente ser toda a vidraça de uma
> vez. Continua existindo uma chance de sobrar uma area mais distante."*

At or above `GLASS_RECRACK_COLLAPSE_FRAC` (0.35) of a pane's standing glass already
CRACKED, the next damaging event — grenade **or** bullet — skips the roll and floods
a region from the impact. It reuses `region_radius()` and G-D13b's anchored
remnants, so *"a area mais distante pode sobrar"* costs nothing new. Not consumed
like a prime: a crazed pane stays crazed, so each successive hit takes more of it.
`crazed_fraction()` arms it — a whole-pane blast craze reads ≈ 1.0, a lone bullet
hole ≈ 0.05.

---

## 3. ⚠️ FOUR BUGS, ONE SHAPE

Every one of them is *"the world changed and X is still answering from the old
state."* Worth reading as a set, because the family is what generalises.

### 3.1 The F2 reload kept the previous mission's glass (`6d16d2ff`)

> *"seeing past debris from previous explosions […] between map loads (F2)"*

`_set_perspective()` (rotation) drops the VoxelRenderer's floor-pile sprites, crack /
craze sprites and view-space hole-rim atoms and rebuilds them from the base store.
`load_map()` cleared the BASE store and **not one of the three decal sets** — it stays
in the same perspective, so it never ran the renderer-side clears. Worse, stale
`_glass_shard_cells` made `restamp_glass_shards()` stamp a cut rim onto whatever fresh
pane landed on one of those view-space cells: **a broken-glass notch on intact glass.**

Fixed by calling `clear_floor_shards()`, `clear_glass_cracks()` and the new
`clear_glass_rim_cells()` from `load_map()`, mirroring the rotation path.
**Red → green: 462 floor piles / 11 rim cells / 3 craze fields → 0 / 0 / 0**
(`INFILTRAITOR_GLASS_BLAST_RELOAD=1` on `glass_blast_demo`).

### 3.2 The grenade was thrown through walls (`668e7024`)

> *"precisamos que ela tenha as mesmas limitações físicas de deslocamento impostas
> pelo cenário ao agente"*

`_clamp_gu_to_throw_range()` clamped by **Euclidean distance alone**. Now it is
`BlastCalculator.throw_line_clamp()` — a LINE-OF-THROW walk along the segment that
stops at the first blocked edge, solid GU block, or the range, reading
`Room._movement_edge_set()` (walls + whole glass, opened passages removed).

⚠️ **The first attempt was a BFS and it was wrong** — see §4.1.

**Verified:** agent (14,14) aiming (14,6) across the intact pane row clamps to
**(14,11)**, in front of it; an unobstructed (13,15) → (20,15) reaches (20,15)
exactly. Pinned by `blast_calculator_selftest` **[3b]** (7 cases: range, wall on the
line, wall off the line, solid block, diagonal squeeze closed, one flank open).

**Same commit, the skill seam** the Director asked for while we were in there:
`throw_range_skill_bonus_gu` (`var`, 0.0), additive, folded into
`effective_throw_range_gu()` = base + skill − posture penalty. Whole numbers only —
the perimeter ellipse only reads on the board at integer cell radii.

### 3.3 The aim bubble kept moulding around glass that was gone (`4108e0ff`)

> *"quando uma segunda granada é engatilhada, a bolha permanece mostrando o layout
> das vidraças"*

The dome moulds against `room._wall_height_edges`; the wireframe footprint and the
real detonation flood off `room._current_blocked_edges`. **Both are the compiled map**,
which no destruction updates.

`Room._blast_opened_edge_keys()` now lists every edge a blast has opened
(`PassageQuery.passage_class(edge) != NONE`), and both consumers subtract it:
`_blast_wall_height_edges()` for the dome, `_blocked_edges_dict()` for the flood. A
CRAZED pane is deliberately **not** opened — its glass still stands.

⚠️ Intact glass is still not ADDED to the flood: a blast shatters through a window
rather than being contained by it, and G-D48's shockwave zone is what carries glass
past the shrapnel radius. Changing that would have been an unrequested side effect.

**Verified:** a grenade at (14,11) shatters four panes; a second grenade aimed there
drops **14 wall-height edges (133 → 119)** and its dome draws as a clean hemisphere.

### 3.4 G-D48's own render gap — glass gone in the data, still painted (`65124a35`)

> *"uma parte das vidraças é destruída […] mas permanece uma parte da vidraça azul […]
> Rotacionando a tela, ela some. Rotacionando de volta, ela permanece sumida."*

**This one was mine, from earlier the same session.** `_phase_slices()` walks only the
BOMB's narrow `affected`, and that walk is the only thing that fills `ring_of` —
which PHASE_PACKAGE iterates to emit `waves["destroy"]`, the entries
`DetonationEntryWriter` turns into `layer.erase_cell()` **and** `erase_glass_cell()`.
G-D48 let `_shatter_glass_panes()` reach panes those phases never enumerated, so
their voxels went DESTROYED on the Delta and were **never packaged**: no destroy
entry, no erase.

The first G-D48 patch topped up `touched_voxels` for VL-PERSIST only — which is
exactly why a rotation "fixed" it (the rebuild re-derives from `_base_damage`) and
the live frame did not.

Fixed by registering the shattered voxel in `ring_of` / `container_of` at the
shatter, so PACKAGE owns the erase, the census and the persistence **together**. The
`glass_shattered_voxels` top-up is deleted as redundant; `crazed_voxels` stays,
because a craze takes the whole pane by design and genuinely is outside the rings.

**Red → green: 928 stale cells → 0**, via the new `VoxelRenderer.glass_cell_present()`
and the `[GLASS-BLAST] STALE glass cells` line.

---

## 4. ⚠️ THE FINDINGS worth carrying

### 4.1 A BFS is not a throw — Manhattan distance cannot say "the straight line is blocked"

The first wall-aware throw used `BlastCalculator.flood_gu_within()`, a Manhattan BFS
over the agent's own movement edge set. It was defensible ("the same limitations the
scenery imposes on the agent" — and the agent BFSes) and it was **wrong on screen**:
from (14,14) aiming (14,6), it routed the grenade around the pane row through a gap
three tiles away and landed it at **(17,8)**. Tightening the detour slack did not
save it, because a monotone L-path through a gap has the *same Manhattan cost* as the
blocked straight path — the metric simply cannot express the constraint.

A grenade arcs straight. The model is a raycast. `flood_gu_within()` was added and
then removed rather than left behind.

### 4.2 "A rotation fixes it" is the signature of a live-path render gap

Three of the four bugs above were only visible because the Director rotated the
camera or reloaded the map and watched the artefact vanish. The rebuild re-derives
from the base store, so it *hides* any gap in the live path by construction. When a
symptom disappears on a rotation, the base store is right and the live write is
missing — do not go looking at the base store.

New memory: `damage-must-join-ring-of`.

### 4.3 Writing damage onto the Delta does not make it appear

`ring_of` is the join between "this voxel changed" and "this cell gets repainted".
A phase that writes damage for a container the earlier phases never enumerated has to
register it there — one join, not three parallel top-ups (persistence, erase, census)
that can each be forgotten separately. G-D48 forgot two of the three.

### 4.4 `INFILTRAITOR_CAPTURE_ACTION` does nothing without `INFILTRAITOR_AUTO_SCREENSHOT=1`

Cost about twenty minutes and four Godot processes that looked hung: the capture
never ran, the app just booted and sat there. This is already written down
(`harness-null-result-is-about-the-harness`) and was still walked into. The tell is a
log that ends at `_ready()` with no capture line.

---

## 5. Doc + instrument inventory

| | |
|---|---|
| `GLASS_MASTER_PLAN` | v1.47 — G-D48 / G-D49 in the status header, G-D46 marked superseded, the render gap recorded, §10.1 amended with what case testing produced |
| `MATERIALS_MASTER_PLAN` | v1.9 — M4's case testing and its two rulings; M4's status unchanged (still essentially done) |
| `TARGETING_MASTER_PLAN` | new **§5b** (line-of-throw clamp + the skill seam) and **§5c** (dome and flood follow the damage); status header points at both |
| `blast_calculator_selftest` [3b] | `throw_line_clamp()`, 7 cases |
| `glass_shatter_selftest` [10] | rewritten for G-D48 — the ramp is reliable to GU 3, tapers (never rises) to GU 5, is 0 at GU 6; craze reaches 2 GU further; and `flood_gu_rings(min_max_ring)` actually places a GU at ring 7 |
| `VoxelRenderer.glass_cell_present()` | destroyed-in-data / still-painted, the §3.4 instrument |
| `INFILTRAITOR_GLASS_RING_DIAG=1` | per-pane ring / probability / `crazed_frac` / outcome — the G-D48 calibration readout |
| `INFILTRAITOR_GLASS_BLAST_RELOAD=1` | `glass_blast_demo` reloads the map and asserts every glass render store is back to zero |
| `INFILTRAITOR_EVENT_SECOND_GU=x,y` | `throw_event` re-enters targeting after the first blast and logs how many wall-height edges it opened |

**Every commit:** 51 selftests clean, `project_lint.py` clean, `check_invariants.py`
clean, CODEMAP fresh.
