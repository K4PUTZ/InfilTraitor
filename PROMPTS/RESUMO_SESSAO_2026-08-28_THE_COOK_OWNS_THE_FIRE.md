# RESUMO_SESSAO — 2026-08-28 · THE COOK OWNS THE FIRE, AND THE PASSAGE STOPS BEING A SHAPE

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-27_28_THE_CHOREOGRAPHER_IS_THE_VILLAIN.md`
**Gates at close:** lint ✅ · selftests **40 clean / 0 failed** ✅ · invariants ✅ ·
CODEMAP regenerated ✅ · zero warnings in all 6 files touched · no cited PNG modified.
**VERSION:** unchanged at 0.9.107 (no tag requested).

---

## Read this first if you are resuming

**D-2 is BUILT.** Work resumes at `DETONATION_PRESENTATION_MASTER_PLAN` **D-1/D-3**.
Nothing is half-done; the tree is clean. The old path is one env var away
(`INFILTRAITOR_BURN_SCHEDULE=1`) and is deliberately NOT removed — that is D-6.

The session did two things, and the second one changed shape mid-flight because
the Director vetoed yesterday's own proposal.

---

## 1. ✅ THE COOK OWNS WHAT THE FIRE CONSUMES (§6)

`_maybe_burn()`'s three rolls are untouched, so WHICH voxels burn is
bit-identical — **356 of 356 on both paths**. What moved is where the answer
lands: a new **`PHASE_BURN` between WALK and SOOT** folds the fire into the Delta
as DESTROYED damage instead of into `waves["burn"]`.

⚠️ **THE PHASE POSITION IS THE WHOLE TASK, not a detail.** `_build_ember_wave()`
ran at the END of `PHASE_SMOKE`, which is **behind every consumer a burnt voxel
needs**: `touched_this_blast` (PACKAGE), the soot BFS seeds (SOOT), `occupancy`
(WALK → LIGHT) and `touched_voxels` (VL-PERSIST). Calling `add_damage()` from
where it stood would have destroyed voxels that reached no wave, no census and no
persistence. So it was reseeded from the **Delta's projection** rather than from
the packaged `destroy` wave — the same set by construction, because PACKAGE
appends exactly the `ring_of` keys whose projected state is DESTROYED.

⚠️ **AND THE ENTRIES ARE FOLDED IN ONE BATCH AT THE END OF THE PHASE.**
`add_damage()` folds immediately, so a burnt voxel folded mid-pass reads DESTROYED
to the next ember seed and silently stops lighting. Collect-then-fold is what
keeps the ember set identical.

Also handled, and it would have been a silent hole: the ember pass reaches
neighbours through the map-wide `cell_to_voxel`, so the fire can eat a voxel in a
container this blast never damaged. Those get `ring_of`/`container_of` backfilled
in the same phase, or PACKAGE (which walks `ring_of` keys) never sees them.

### The measurements — one binary, one map, two behaviours

| fabric wall, gu (31,3) | control (`BURN_SCHEDULE=1`) | **D-2** |
|---|---|---|
| commit | 951 voxels, 11.4 ms | **1 307 voxels, 12.4 ms** — exactly +356 |
| the fire | 356 of 356 over 1.37 s, a schedule | **356 consumed IN THE COMMIT** |
| **`[E-FUME-ERASED]`** | **350 of 1 914** | **0 of 1 765** |
| **cell probe** | 1 163 erased · **350 RESTORED** (f127) | 1 169 erased · **0 RESTORED · 0 VANISHED** |
| passage, end state | STANDING ×3, base storey 64/64 | STANDING ×3, 100% removed — **the same** |
| flash → blast over | 4 981 ms / 266 f | **4 113 ms / 217 f** |
| hard wall `[E-FUME-ERASED]` | 0 of 879 | **0 of 879** — untouched |

**The end state agreeing is the load-bearing row**, not the zero. Both paths
finish with the same three STANDING passages over the same wall, which is what
makes "the fire changed owner" defensible instead of "the fire changed".

**The picture agrees independently.** Frame 279 of the same filmstrip, control vs
D-2: **19 621 differing pixels in ONE bbox**, (536,146)–(712,435). The control has
a slab of wall standing back across the top of the opening; D-2 does not. That is
the 350 cells, seen. Both probe runs reproduced across two boots.

⚠️ **One number is unexplained and is left that way: 1 169 erased vs 1 163.** Six
cells, 0.5%, in the direction of MORE erased. Named rather than dressed up — the
two gates it could have poisoned are both 0 and the end state matches.

---

## 2. ⛔ THE DIRECTOR VETOED YESTERDAY'S §11.1 — the cook forces NOTHING

Asked directly whether a grenade at 0 GU from a **concrete** wall should open a
standing passage on the spot, the answer was **no**:

> *"essas aberturas vão ser normalmente autoradas… vamos ter um frame de uma
> porta, com uma cortina de pano. Nesse caso a granada vai destruir praticamente
> todo o pano, a passagem se abre, e o material duro destroi menos, como já
> funciona."*
>
> *"Quantos voxels sobram individualmente não é importante… Podem ficar sobras
> decorativas, porém precisamos ter mais ou menos uma noção de quantos voxels
> foram removidos pra aplicar a abertura."*

Breach points are AUTHORED by the level designer, not forced by the engine. So
**§11.1's whole forced-opening design was not built**, and no `ctx` bubble
plumbing was added — `aim_dome_radius_gu` reads no passage.

**What shipped instead is `PassageQuery`'s CRITERION: amount, not shape.**

⚠️ **THE BAR DID NOT MOVE, AND THAT WAS THE POINT OF THE NUMBER.** The old
`PASSAGE_MIN_WIDTH_POSITIONS` was 4 of 8 positions at full storey height = **32 of
64 cells**. So `PASSAGE_MIN_REMOVED_FRACTION = 0.50` is *the same doorway* with
the shape requirement taken off it. Picking a fresh number would have changed two
things at once and made the selftests unreadable.

- **Contiguity and full-height go.** Their two selftests are **inverted in place
  with the ruling quoted**, never deleted — and a third fixture was ADDED (3 of 8
  columns → NONE) so "shape does not matter" cannot collapse into "nothing
  matters".
- **Overlap SURVIVES**, restated per position. A first version dropped it with the
  rest and answered STANDING to *"storey 0 open on the left, storey 1 open on the
  right"* — two windows. That is geometry, not a decorative leftover, and the
  existing fixture caught it.
- **Accumulation is free.** Voxel damage persists, so *"3 granadas no mesmo lugar
  com concreto"* adds up to one fraction — **no per-edge store, no accumulator,
  nothing new to keep base-keyed under rotation.** §11.3.4's risk avoided rather
  than managed.

**Measured the same day, which is the ruling in numbers:** fabric **100% removed →
STANDING ×3** on one grenade; concrete **3% removed → NONE ×3**.

---

## 3. Instruments built or changed

- **`[E-PASSAGE]`** (`Room.report_blast_passage()`) — replaces the `passage over N
  burnt edge(s)` half of `[E-BURN] fire out`, which could only exist while the
  fire had an end to hang a report on. Same shape, two widenings: every edge the
  blast touched (not only burnt ones), and it prints the **removed fraction**,
  because that is the criterion now and a wall that did not open is only readable
  against how close it came.
- **`INFILTRAITOR_BURN_SCHEDULE=1`** — the legacy fire, whole, from the same
  binary. `BurnScheduler`, `_advance_burn` and the burn profiler are deliberately
  NOT removed: they are the control, and removal is D-6.
- ⚠️ **`[E-BURN]` had to be rewired or it would have lied on every fabric blast.**
  It read `delta.waves["burn"]`, which D-2 empties, so it printed *"0 — nothing
  this blast lit has burn_consumption > 0"* on a fire that consumed 356 voxels.
  Caught on the first real run, not by a gate.
- ⚠️ **The cell probe only arms on the P-FILM path** (`build_filmstrip.py`), not
  on `test_zone_detonate`. `INFILTRAITOR_CELL_PROBE=1` on a windowed capture
  prints nothing and looks like a pass.
- ⚠️ **`test_zone_detonate` does not frame a blast at a custom GU.** It centres on
  `TEST_ZONE_GRENADE_GUS`, so its screenshot of a fabric blast at gu (31,3) shows
  empty floor. Use the filmstrip for anything visual.

---

## 4. OPEN — in order

1. **D-1 / D-3** — the real commit frame priced with the fire folded in (D-0
   measured the cell half at 18.55 ms; the fire's ~12 ms is now inside the commit,
   and 12.4 ms measured says it landed cheaper than the ~42 ms projection). Then
   the presenter behind `INFILTRAITOR_PRESENTER=1`.
2. **D-4** — the symbolic fire. `delta.burnt_cells` carries `{at, ring}` per voxel
   for exactly this: with everything destroyed in one frame, which voxels wear an
   ember and in what order is what tells the story.
3. **D-2b** — the pre-fabricated pattern, gated on the Director looking at a
   crater. ⚠️ **It is now also what makes the authored breach point work** (§11.1a):
   a fabric curtain in a door frame is the shape the pattern has to produce.
4. **D-5 / D-6 / D-7**, SS-6 riding with D-7.
5. **Tune `PASSAGE_MIN_REMOVED_FRACTION` against `[E-PASSAGE]`** once authored
   breach points exist — 0.50 is inherited, not measured on a real doorway.
6. **Untouched from earlier summaries:** `SOOT_STORAGE_REFORM` SS-4/SS-5, the
   glowing edge, `INFILTRAITOR_HIDE_VOXELS`, `update_docs.py`'s silent wipe,
   smoke separation, audio.
