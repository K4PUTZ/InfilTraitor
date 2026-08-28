# RESUMO_SESSAO — 2026-08-27 · THE SOOT STORE SHIPPED, AND THE FIRE WAS CAUGHT UNDOING ITS OWN DESTRUCTION

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-27_PACING_AND_ORDER.md`
**Commits:** `7912677a` `f1788c1b` `d6a4afc9` `2171bbbe` `a0a819e9` `12d91637`
`a2ed9750` `9fd46cbc` `f1530849` `a483334f` `a40cd9d4` — all pushed.
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP ✅ · 0 dead links across every `.md`.
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

Two tracks ran. The soot storage reform went from a ruling to **SS-0…SS-3 built
and gated**. Then a video the Director asked for turned into the session's real
finding: **the fire puts back 350 of the 1 163 cells it destroys, on one frame**,
and a fireless blast restores **0 of 813**. That ended the reform track for the
day and opened a rebuild.

**Where work resumes: `FIRE_REBUILD_MASTER_PLAN` F-0** — price a single commit
frame. The architecture rests on that one unmeasured number and it is cheap to
get. Nothing is half-done; the tree is clean and pushed.

---

## 1. The soot reform — SS-0 to SS-3, built

`SOOT_STORAGE_REFORM.md` was written from the Director's ruling, then built.

**The finding that shaped it:** the store already existed twice —
`VoxelRenderer._soot_images` (RG8, one texel per cell, R = the per-face code) and
`room._crater_floor_soot` (stored, min-wins, permanent, already persisted). So the
reform was never a data-structure change; it was a change of **authority**: an
emitter writes scorch once, and the repaint stops writing scorch at all.

| task | what landed | gate |
|---|---|---|
| **SS-0** | armed the two-fire watcher | red 175 flicker / green 0, via `INFILTRAITOR_P3=0` |
| **SS-1** | `_soot_map`, base-keyed, six-direction format | **0 DERIVED-ONLY, 0 LIGHTER** on a real shot and two real fires |
| **SS-2** | `_build_soot_snapshot()` returns the store | **control 0 px, gate 0 px** on a real detonation |
| **SS-3** | `WorldDelta.scorch_writes` → `commit(room)` | fire 1's region **0 changed**, flicker 106 → 24 |

### 1.1 Three things the reform surfaced that were not on anyone's list

- ⛔ **SS-0 killed this plan's own headline motivation.** §9.11a's flicker is
  already dead: PERF-P3 shipped default-ON and took the light bucket out of the
  alternative id, so a cell can no longer enter the soot wave on the alt half.
  The §9.11b guard is **inert** — it skips zero. A plan citing a fixed bug as its
  reason was rewritten rather than left standing.
- ⚠️ **The per-face format is VIEW-space and cannot survive a rotation.**
  `Vector3i(top, SE, SW)` is +Z/+X/+Y in view space and gives the two faces turned
  away from the camera a placeholder. Stored, that is a hole in the record. The
  store keeps **six** directions instead — the sixth is BOTTOM, and it exists
  because the ISOTROPIC ring is otherwise unrecoverable for a voxel scorched from
  underneath.
- **Rotation was disabled for PERFORMANCE, not because the game is single-sided.**
  A Director correction to a documented ruling, and it swept seven live documents.

### 1.2 ⛔ And a number I reported to the Director was wrong

SS-1 announced *"2 store-only on the shot — the reform visible."* It was not. The
shot pre-cook calls `_build_soot_snapshot()` with PREDICTED damage, and SS-1
absorbed that speculation into the store: two cells of damage the world never
produced. Harmless while nothing read the store, fatal the moment SS-2 made it the
answer. Fixed in SS-2, corrected in §5.1 of the plan, and `blast_purity_selftest`
now carries the standing version of the check (**692 proposed, 0 stored**).

---

## 2. ⛔ THE FIRE UNDOES ITS OWN DESTRUCTION — §9.11 reproduces

The Director asked for a 3× slow-motion video and reported that the wall restores
itself, *"principalmente na hora que a fuligem é aplicada"*. It does.

**Built a cell probe** (`INFILTRAITOR_CELL_PROBE=1`) that samples
`(source_id, alternative)` per cell per frame from inside the filmstrip's own
frame loop, so **probe frame N is image frame N**. One build, only
`INFILTRAITOR_NO_BURN` differing:

```
with fire   27 928 armed · 1 163 erased · 350 RESTORED — all on ONE frame
without     27 928 armed ·   813 erased ·   0 restored
```

`1 163 − 813 = 350`, exactly the restored count, and `[E-BURN]` reports **356**
consumed. **The voxels the FIRE eats are the voxels that come back.** The no-burn
green is not vacuous: its log carries the whole consequence beat, identical.

`PERFORMANCE_MASTER_PLAN` §9.11 carried *"a destroyed voxel must not be
restorable"* with status **"not reproduced"** — now §9.11e. And it explains why
the trail went cold: **the repro needs a FIRE**, and every instrument since
§9.11a was aimed at two blasts.

### 2.1 The store's first win on screen

Same capture, only `INFILTRAITOR_SOOT_STORE_READ` changed:

```
READ=1 (store)      f124: 4 961 px                       total  4 961
READ=0 (derivation) f124: 4 961 px + 12 more events      total 34 936
```

The twelve extra events — ~30 000 px spread across the soot ladder and the light
beat — are the Director's *"voxels entering clean after the soot"*, and **the
store removes all of them.** The `f124` residual is identical on both paths, so it
is not the reform's; it is §9.11e.

### 2.2 Widening the probe, because its first version had a blind spot

Arming only on PLACED cells could see `placed → erased → placed` and nothing else,
so a cell that APPEARS and then VANISHES was invisible — which is what the
Director suspected was also happening. It now arms on the whole rectangle
(266 240 cells, empty included). On the fireless fabric blast: **813 erased, 0
RESTORED, 512 appeared, 0 VANISHED**, and the 512 are a clean progressive wave on
one level — the expose path revealing the deep floor. **Without fire the board
only ever loses cells.**

---

## 3. The new architecture — ratified, and it inverts the old argument

`FIRE_REBUILD_MASTER_PLAN` §2, the Director's own proposal: cook the FINAL
crater, show what is left, spend the rest of the event on effects.

⚠️ **It almost shipped arguing from a stale number.** §8.15's *"a committing frame
that mints costs ~360 ms"* has been quoted across this repo since before the perf
wave. Measured this session:

```
frames during the fire: 77 · mean 17.1 ms · max 26 ms — 7 committed
committing 6 x 20.0 ms = 120 ms · NON-committing 71 x 16.8 ms = 1 196 ms
MINT-SPLIT — that MINTED: 0
```

**20 ms against 16.8 ms, zero mints.** 91% of the fire's wall clock is frames
doing nothing but passing. **The fire is not expensive, it is LONG.**
`PERFORMANCE_MASTER_PLAN` §8.15b now says so.

**The rule:** a frame that WRITES CELLS must be rare — ideally one. A frame that
only DRAWS costs ~17 ms and there are dozens spare. So the structural error was
never the number of waves; it is that the waves write cells for 24 frames and the
fire writes for 77 more — a second mutation stream beside the repaints, which is
what produces §9.11e.

**The shape:** cook → flash → **ONE commit frame** (destruction, expose, decals,
soot, light) → 40–80 frames of pure drawing. The fire becomes an **instanced
ember**: one MultiMesh, per-instance phase and smoke duration, which P7b already
priced at N-costs-what-one-costs.

---

## 4. Instruments built this session, and one trap

- `INFILTRAITOR_CELL_PROBE=1` — the per-cell RESTORED / APPEARED / VANISHED probe.
- `INFILTRAITOR_NO_BURN=1` — the blast without the fire, which is what makes a
  fabric detonation comparable to a concrete one.
- `INFILTRAITOR_SOOT_STORE_GATE=1` — store vs derivation, by level.
- `INFILTRAITOR_SOOT_STORE_READ=0` — the old answer from the same binary, so a
  before/after diff needs no stash.
- `build_filmstrip.py` stops filtering `[CELL-PROBE]`/`[NO-BURN]` out of its log.

⚠️ **`two_fires` OVERWRITES `Screenshots/history/twofires_after_1.png` / `_2`** —
the hand-named captures §9.11b cites. Every run this session clobbered them and
every one was restored with `git checkout --` before committing. A non-`auto_`
name survives the rotation, **not** a re-run of the action that made it.

---

## 5. ⚠️ Three readings of my own that were wrong, and how they were caught

The same pattern as the previous session, so it is recorded again.

1. *"The marks revert — the decals are being wiped."* From a luminance curve. The
   real answer needed the tilemap, not pixels.
2. *"There IS fire — an orange glow from f56."* The previous session had already
   recorded that the orange is the scene background through two destroyed floor
   layers. The Director corrected it: that one is a **different** orange, and the
   real fire is *"basicamente uma elipse com feather nas bordas e alpha"*.
3. *"Wall-clock scheduling explains the missing fire."* Checked before asserting:
   `_burn_scheduler.advance(delta)` is frame-driven, so `--fixed-fps` pins it. The
   hypothesis died in the reading, which is where it should die.

**What worked:** every real finding came from a measurement with a control —
`INFILTRAITOR_P3=0` for SS-0, `SOOT_STORE_READ=0` for the store's win,
`NO_BURN=1` for §9.11e. Not one came from reading the code first.

---

## 6. OPEN — in order

1. **`FIRE_REBUILD` F-0 — price the single commit frame.** The whole architecture
   rests on it. If it does not fit, §2 changes there.
2. **F-1 — the instanced ember**, the part the Director has to LOOK at.
3. **The passage** (`FIRE_REBUILD` §2.6.2) — `passage over N burnt edge(s)` is
   gameplay the agent walks through, it EMERGES from the burn today, and with the
   burn gone it must be computed in the cook. Most likely thing to be deleted by
   accident.
4. **`SOOT_STORAGE_REFORM` SS-4/5/6** — checkpoint persistence, the subtraction,
   and the rotation proof (which needs a capture action that rotates, and none
   exists).
5. **The Director's §5.3 ruling is answered and unbuilt:** scorch of fire-consumed
   voxels SHOULD exist, which is exactly why soot lands at the end.
6. **The rhythm pass** the Director deferred — *"o ritmo ainda precisa melhorar."*
7. **Everything from 2026-08-27's earlier summary §9 that was not touched:** the
   glowing edge, the 0.73 s frozen board, `INFILTRAITOR_HIDE_VOXELS`,
   `update_docs.py`'s silent wipe, smoke separation, audio.
