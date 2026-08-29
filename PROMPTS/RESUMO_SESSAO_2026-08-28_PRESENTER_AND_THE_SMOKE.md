# RESUMO_SESSAO — 2026-08-28 · THE PRESENTER, AND THE SMOKE THAT WAS BEING CULLED

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-28_THE_COOK_OWNS_THE_FIRE.md` (D-2).
**Commits:** `9d6004c7` `3c0fb851` `13835ef6` `faf65cf4` `96a266a1` `3bcffc4d`
(+ this one) — all pushed.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · zero warnings in every file touched.
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

**`DETONATION_PRESENTATION_MASTER_PLAN` D-0, D-1, D-2, D-3 and D-4's SMOKE are all
done.** What is left in D-4 is **the symbolic fire** (§5.1) — genuinely new
construction, and the only part of the plan that is not deletion. Then D-2b, D-5,
D-6, D-7. The presenter is opt-in (`INFILTRAITOR_PRESENTER=1`); the choreographer
is still the default until D-6 removes it.

---

## 1. ✅ D-1 — the plan made its own mistake, on itself

Built `INFILTRAITOR_EVENT_FRAMES=1` (`[E-FRAME]`), which keeps **every frame** of a
detonation and marks the beats on that timeline rather than bucketing frames by
beat. The first version bucketed and was unreadable *within one run*: seven beats
fire inside the commit frame, so `BEAT 3` came out with zero frames while the frame
that wrote 3 531 cells was charged to `SOOT RAMP`.

⛔ **§8.1's "the single collapsed commit frame is 18.55 ms measured" was WRONG.**
That was `[E-WAVE]`'s `apply=` figure — the CPU *inside* the loop. The FRAME is
**59.2 ms**. The missing ~40 ms is the TileMapLayer's own work for 3 531 changed
cells, charged after the loop returns and invisible to any probe inside it. §1.3 is
built on exactly that distinction and §8.1 still fell for it.

The model survives, refined: a writing frame costs `baseline(~17 ms) + ~11 µs/cell`.
It predicts 433 ms for the 23-frame spread against 404 measured. **So collapsing
does not make the per-cell work cheaper — it removes 22 baselines.**

⚠️ And the event's real worst frame is neither: the **light derive, 201.9 ms**.

## 2. ✅ D-3 — the presenter

`DetonationPresenter`, 211 lines against the choreographer's 933. One frame that
writes every cell, then N frames that write none, then the light. No
`flatten_plan()`, no `_sort_key()`, no `KIND_RADIUS_BIAS`, no `front_frames`, no
`_fade_in_soot()`.

**`DetonationEntryWriter` was extracted FIRST**, behaviour unchanged — the enabling
move, not tidying. Two paths need the writing, they must run from one binary, and
copying `_apply_entry()` would have left D-6 reconciling two versions instead of
deleting one file.

| fabric | choreo default | choreo `FRONT=1` | **presenter** |
|---|---|---|---|
| worst cell-writing frame | 29.1 ms (×23 f) | 59.2 ms | **31.4 ms** |
| apply inside it | — | 19.8 ms | **9.96 ms** / 3 584 cells |
| whole event | 217 f / 4 069 ms | 193 f / 3 686 ms | **173 f / 3 332 ms** |

⚠️ **The presenter's commit frame is HALF the choreographer's collapsed one at a
higher cell count**, and only one cause was designed: it writes the real scorch once
instead of clean-plus-four-repaints, AND its apply loop is 9.96 ms against 19.8
because the cells go in **container order instead of radius-interleaved order**.
`flatten_plan()`'s radial sort was scattering writes across TileMapLayer quadrants.
Nobody predicted that; the ordering machinery was not free even inside one frame.

**Gates: cell probe `0 RESTORED · 0 VANISHED`, and the settled board is
PIXEL-IDENTICAL (0 px) between the two paths** — D-5's gate, met early. Earned: the
same comparison reported 19 621 px for D-2's real change.

## 3. ✅ D-3b — the scorch fades in again

Director: *"daria pra fazer a fuligem entrar com fade in de 4 ou 5 frames?"* Yes —
5 steps, 4 drawn frames, 2 407 cells, 79 ms of writes.

⚠️ **It is HALF of `_fade_in_soot()`, and the half that was never the problem.**
That function did a `set_cell()` block from a cook-time `source_id` (§9.11e's
writer, the 350 restored cells) *and* a ladder walk on the soot plane. §3 killed the
whole function for the first half; the presenter's commit has already placed every
cell with live data, so only the ladder is needed and **there is no `set_cell()` in
it at all**.

⚠️ **§9.11a had to be carried across**, and it is why `soot_ramp_cells` is a
per-cell set and not a flag: the soot wave admits cells whose LIGHT BUCKET moved
with their scorch unchanged, and writing those clean and walking them back is the
Director's 2026-08-23 flash (180 cells, five frames, back to their old value).

## 4. ✅ D-4's smoke — three findings, two of them mine

**The mechanism was never missing.** `_append_voxel_smoke()` → the presenter →
`add_smoke()` → `CircleField` is intact and fires on every damaged voxel (~1 309
puffs on fabric, ~460 on concrete). Shipped on top of it: per-material
`smoke_chance` (concrete 460 → 171) and **the height axis** — `add_smoke()` has
taken a `drift_scale` since E-SPARK-04 and **no blast ever passed it**.

⚠️ **THE DIRECTOR'S SECOND DRAWING RECLASSIFIED HALF A SESSION.** The per-voxel
puffs are *"a fumaça da granada que já está funcionando"*; what was missing is a
different effect — **a few large columns rising off the affected areas at the end,
persisting ≥1 s**. No amount of tuning the puffs could have produced it.

So: `_append_plumes()`, one column per damaged GU, seeded from the **highest
damaged voxel** of each GU — which is what puts columns on WALLS rather than always
on the floor. They ride in `waves["smoke"]` with an explicit `at` that `_delay_for()`
honours and does not clamp.

## 5. ⛔ THE REAL BUG: `CircleField` had no `custom_aabb`

The plumes did not draw. Bisected, not guessed:

| experiment | result | eliminated |
|---|---|---|
| puffs given the PLUME's values | **127 px** | the values |
| release time forced to `at = 0` | **0** | the timing |
| probe inside the overlay | 96 in `_smoke`, 96 pushed/frame | the entry path, `add_smoke`, a cap |
| positions of both groups, one frame | magenta x **-492..325**, others x **-220..-36** | ← the answer |

**Godot derives a MultiMesh's visibility bounds from its BASE MESH**, and
`CircleField`'s is a circle of radius **1**. The per-instance transforms carry the
real positions and radii and are not in that box, so instances far from the node
origin are culled before they are drawn. One line took the plumes from **0 to
4 055** magenta pixels.

⛔ **A P7b defect, not a D-4 one** — every `CircleField` (smoke, embers, dust) has
been silently losing its most distant particles since P7b shipped.
⚠️ **And P7b's "0 differing pixels" gate could never have caught it**: that gate is
the static `circle_gate` scene, whose circles all sit near the origin.

⚠️ **I reverted the feather on a misdiagnosis and put it back.** It was blamed for
the plumes, and the red-rim probe's 19 px was read as "the shader barely works" when
it was the AABB culling the same instances. It never broke anything — and with the
plumes visible it proved necessary.

⚠️ **I also frame-indexed a detonation twice while probing**, which the plan already
documents as impossible (the cook is budgeted in ms, so the blast lands on a
different frame every boot). Both probes read one hardcoded frame, found nothing,
and had to be re-run scanning every frame.

## 6. Director rulings this session

1. **The passage criterion is the AMOUNT, not the shape** — the bubble forces
   nothing; breach points are AUTHORED. `PASSAGE_MIN_REMOVED_FRACTION` = 0.50, the
   same doorway the run rule was sized to.
2. **The 240-frame event is RATIFIED.** *"A mudança de iluminação vai ser assumida
   como um evento da rodada… pode manter os 240 frames rodando até a fumaça se
   dissipar. Esse tempo pode ser usado pra adiantar o cálculo da iluminação."* A
   future perf pass must not "fix" it, and §7.4 gains an opening.
3. **Smoke may be lighter or darker than the background** — presence, size, rise
   and ≥1 s persistence are what matter.
4. **Final look:** *"pode fazer toda a fumaça com puffs menorzinhos e mais suaves"*
   — applied to both populations (scales 2.3→1.7 and 5.0→3.4, feather 0.55→0.75).

## 7. OPEN — in order

1. **D-4's symbolic fire** (§5.1) — flame → incandescent → black → smoke, one
   MultiMesh with per-instance phase, over the voxels the cook marked burnt.
   `delta.burnt_cells` already carries `{at, ring}` per voxel for exactly this.
2. **§7.4 — the light derive, 201.9 ms in one frame.** With D-3 in, everything else
   in a detonation is under 32 ms, so this is the whole remaining problem — and
   ruling 2 above says there is now a second of smoke to hide it under.
3. **D-2b** — the pre-fabricated pattern; now also what makes an authored breach
   point work.
4. **D-6** the removal, **D-5/D-7**, SS-6 with D-7.
5. ⚠️ **Re-check every other `CircleField` consumer against the AABB fix** — embers
   and dust were losing distant instances too, so their tuning was done against a
   partly-invisible population.
6. Untouched: `SOOT_STORAGE_REFORM` SS-4/SS-5, the glowing edge,
   `INFILTRAITOR_HIDE_VOXELS`, `update_docs.py`'s silent wipe, audio.
