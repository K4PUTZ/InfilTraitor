# FIX-EXTERIOR-WALLS-01b: Exterior Wall Height — 1 → 3 Storeys

**Status:** Ready for implementation
**Predecessor:** FIX-EXTERIOR-WALLS-01 (exterior walls are real Edges, fixed height, no config knob — architecture confirmed correct)
**Scope:** Pure value change. `EXTERIOR_WALL_STOREYS` is currently `1` (set that way deliberately, per Matt's direct instruction to the Operator to shrink the previously-giant walls to look proportional to interior walls). Matt now wants **3 storeys** as the settled fixed value — some verticality without occupying the full 8-storey ceiling height. `DEFAULT_CEILING_FLOORS` (lighting/scene-composition ceiling, currently `8`) is a separate concept and does not change.
**Effort:** ~15 minutes
**Risk:** None — one constant, already-proven code path

---

## Item 1 — Change the constant

`map_compiler.gd:47`:

```gdscript
const EXTERIOR_WALL_STOREYS: int = 3
```

Nothing else needs to change — `EdgeExtractor`'s wall branch already reads this constant (`edge_extractor.gd:85`, `MapCompilerClass.EXTERIOR_WALL_STOREYS`), and `DEFAULT_CEILING_FLOORS` is an independent constant (`map_compiler.gd:51`) already unaffected by this one.

## Item 2 — Fix the failing acceptance criterion from the original prompt

The prior verification run (`godot2026-07-06T16.47.27.log`) reported `FAIL: ceiling_floors = 0 (expected 8)` on Test 4. Re-run that same test after this change and confirm it now passes — if it still fails, that's a separate, real bug in how `ceiling_floors` is computed/read (not something to paper over by adjusting the test's expected value) — investigate and report, don't just make the assertion match whatever the code currently does.

---

## Acceptance Criteria (assertion-backed, real execution evidence only)

1. **Constant is 3**: real read of `map_compiler.gd`, confirmed.
2. **Exterior wall Edges are 3 storeys**: real printed `storey_count` for sample exterior-wall Edges on PLAYGROUND/SIGMA_01/TEST_BLOCKS, all `== 3`.
3. **`ceiling_floors` test now passes**: re-run the existing verification script, paste full output, confirm 4/4 (or however many criteria it has) now PASS — not just the one that was failing.
4. **Screenshot**: exterior wall next to an interior solid-block wall (PLAYGROUND District A/D), for visual proportion comparison at the new 3-storey height.
5. **Non-regression**: `check_invariants.py`, `map_lint.gd`, clean.

---

*End FIX-EXTERIOR-WALLS-01b prompt.*
