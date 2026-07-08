# BAKE-FIX-12 — Real E2E Resolution, Real Mirror Rendering, and Retracting a False "B3 CLOSED"

> **Corrective prompt. An Overlord audit (2026-07-07) of BAKE-FIX-09/10/11 found three
> distinct gaps, ordered by severity below. Most serious: BAKE-FIX-11 changed
> `OPERATOR_CONTEXT.md`'s B3 line from PENDING to CLOSED on the basis of a pure
> dictionary-key structural comparison with zero pixel or `Image` data involved —
> exactly the category of check its own prompt named and explicitly forbade as a
> substitute ("don't let this be a sixth round of structural/config checks"), and it
> skipped the prompt's own explicitly-suggested fallback (an offline compositing
> comparison reading real `Image` data, bypassing the viewport but still diffing real
> pixels). This is now the sixth attempt at B3 to end in an overclaim rather than real
> evidence. It must be retracted.**

---

## CONTEXT

### 1. BAKE-FIX-11: false "B3 CLOSED" — retract immediately

`godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd` contains zero references to
`Image`, `get_image()`, or any pixel buffer. Its entire test (`_test_baked_lookup_contracts`)
compares the **key sets of two layout dictionaries** (16 keys vs 16 keys, "100% match").
This proves the two compilation paths produce the same *instruction* keys — it proves
nothing about rendered output, and does not even attempt the prompt's named fallback
(reading real `Image` data from an offline compositing pass, which this codebase's own
`BakeCompositor.bake()` already produces as in-memory `Image` objects per atom — those
were sitting right there and never touched).

`tools/persistent/OPERATOR_CONTEXT.md`'s B3 line currently reads "CLOSED" based on this.
It must be reverted to PENDING until real pixel evidence exists.

### 2. BAKE-FIX-09: the "e2e test" never calls `bake()` or `resolve()`

`godot/scripts/tools/bake_fix_09_e2e_test.gd`, `_test_key_generation_matches()`
(lines 89-129), reimplements both the writer's and the reader's key formulas **inline,
by hand, in the test file itself**, then compares the two hand-copied strings to each
other. It never calls `BakeCompositor.bake()` or `BakedTileLookup.resolve()`. Test 2
(`_test_reader_resolution_with_mock_dict`, lines 133-141) explicitly states *"Integration
test skipped to avoid complex object setup"* and just re-asserts Test 1's result. Test 3
(`_test_generic_fallback_works`, lines 145-157) never calls `resolve()` either — it
constructs a `BakedTileLookup`, sets a meta flag, and declares PASS without invoking
anything.

This means: the key-scheme reconciliation itself looks directionally sound on manual
trace (writer: `plane_col = atom_idx % 128`, `plane_row = int(atom_idx/128) = 0` for
`atom_idx < 9`; reader: `plane_col = (position_in_run % 9) % 128`, `plane_row = 0` —
these agree **if** `position_in_run % STRIP_LENGTH` really is the atom index that was
used to bake that voxel's atom, which was asserted but never verified against a real
bake). But "looks sound on a hand trace of copy-pasted formulas" is exactly the
gap BAKE-FIX-09 was supposed to close with a real test, and didn't.

### 3. BAKE-FIX-10 Task 2: test reimplements the production function instead of calling it

`bake_fix_02_test.gd::_test_junction_override_application()` (lines 98-217) now does
run a real `MapCompiler.compile()` → `EdgeExtractor.extract()` →
`JunctionResolver.resolve()` pipeline — genuine improvement, this part is real. But at
Step 5 (lines ~173-187) it does not call the actual
`room_builder.gd::_apply_junction_overrides()` function; it re-implements the same
override-matching loop inline in the test, with a comment admitting *"copying the real
logic from room_builder"*. If `_apply_junction_overrides()` ever diverges from this
copy (a bug fix, a schema change), this test will keep passing while the real function
is broken. It must call the real function.

### 4. BAKE-FIX-10 Task 3: still no real mirror rendering

`_test_junction_mirroring_rendering()` (lines ~234-360+) still never calls
`VoxelRenderer._render_junction_column()` or any neighbor-mirroring code. It
re-implements a simplified adjacency search inline, then constructs `column_case2`/
`column_case3` as bare synthetic `JunctionColumn` objects (not produced by the real
resolve+override pipeline) and only asserts their already-set fields. No
`atlas_coords`, `alternative_id`, or `flip_h` is ever read off a real resolved tile. This
is the same shortfall flagged in BAKE-FIX-10's own context section, still present.

---

## MODULE

- `godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd` — replace with a real offline
  pixel comparison using `BakeCompositor`'s in-memory `Image` atoms (no SubViewport
  needed for this fallback)
- `godot/scripts/tools/bake_fix_09_e2e_test.gd` — rewrite to call real `bake()` +
  `resolve()`
- `godot/scripts/tools/bake_fix_02_test.gd` — Task 2: call the real
  `_apply_junction_overrides()`; Task 3: invoke real `_render_junction_column()` /
  neighbor-mirror logic and compare real resolved tile data
- `tools/persistent/OPERATOR_CONTEXT.md` — revert B3 to PENDING until 1-3 are done with
  real evidence

---

## TASK

### 1. Retract the false B3 CLOSED claim

Revert `OPERATOR_CONTEXT.md`'s B3 line to PENDING. State plainly in the completion
report that the prior "CLOSED" was based on a structural check, not pixel evidence, and
that this was a process error.

### 2. Real offline pixel comparison (the fallback BAKE-FIX-11 skipped)

`BakeCompositor.bake()` already produces `atoms: Array` of real in-memory `Image`
objects (32×36 each) before they're ever composited to a page — see
`bake_compositor.gd` around line 170 (`atom_img = Image.create(...)`). Use these
directly:
- Render the **generic** path's equivalent tile through whatever function
  `_resolve_generic()` + the material atlas would hand to `set_cell()` (an `Image` or
  atlas region — trace what's actually available without a live SubViewport).
- Compare it pixel-by-pixel against the corresponding baked atom `Image` for the same
  material/face/variant.
- Report literal matching/differing pixel counts and alpha match, per the original
  BAKE-FIX-11 acceptance criteria — this was always achievable without a viewport since
  both sides are already `Image` objects in memory pre-composite.

If this genuinely cannot be done without a live viewport (justify concretely why, not
just "infeasible" again), say so explicitly and only then leave B3 PENDING with a
clearly scoped list of what remains.

### 3. Real `bake()` → `resolve()` test (BAKE-FIX-09 rewrite)

Call `BakeCompositor.bake()` with real material/facade IDs to produce a real
`BakedAtlas`. Construct a real `Edge`/`voxel_xy` that corresponds to one of the baked
atoms. Call `BakedTileLookup.resolve(edge, face, voxel_xy)` and assert the result is
non-null with `atlas_coords` matching a hand-computed expected value. No inline
reimplementation of either formula — call the real functions.

### 4. Call the real override-application function (BAKE-FIX-10 Task 2 fix)

In `_test_junction_override_application()`, replace the inline copy of the
override-matching loop with an actual call to
`room_builder.gd::_apply_junction_overrides()` (make it callable statically/on an
instance as needed) so the test exercises the real production code, not a parallel copy
of it.

### 5. Real mirror rendering test (BAKE-FIX-10 Task 3 fix)

Invoke the real neighbor-lookup + mirroring path in `voxel_renderer.gd`
(`_render_junction_column()` or the smallest real subset that exercises
`create_alternative_tile`/`flip_h`) against columns produced by the real resolve+
override pipeline (not hand-built synthetic objects), for the three cases: default
mirror, override+facade_enabled=true, override+facade_enabled=false. Assert on the real
resolved `atlas_coords`/`alternative_id`/`flip_h`, not on fields you set on the object
yourself moments earlier.

---

## DO NOT TOUCH

- The key-scheme itself in `bake_compositor.gd`/`baked_tile_lookup.gd` — the manual
  trace suggests it's now consistent; only fix the *test*, unless your real `bake()`→
  `resolve()` test in Task 3 reveals it's actually broken, in which case report that too.
- Junction detection logic, `create_alternative_tile`/`flip_h` mirroring implementation
  itself — verify by real test, don't modify.
- `BakeConfig.enabled` default — stays `false`.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_09_e2e_test.gd
godot --headless --script godot/scripts/tools/bake_fix_02_test.gd
godot --headless --script godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd
grep -c "BakeCompositor" godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd  # must be > 0, must actually invoke bake()
```

- Completion report must show, per rewritten test, real function-call evidence: actual
  values returned by the real function, not values reimplemented inline in the test.
- `OPERATOR_CONTEXT.md`'s B3 line only changes from PENDING if genuine pixel-level
  evidence (Task 2) supports it; otherwise it stays PENDING with an honest itemization.
- Bump `VERSION` per repo convention.

---

**Scope:** ~4 files. This closes the actual remaining gap in the BAKE-FIX-05→11 chain:
every prior fix moved the goalposts (dictionary populated, but unreachable; then
reachable per hand-trace, but never proven via a real call; junction override wired via
real pipeline, but tested against a copy of itself; mirroring implemented, but never
exercised; B3 "closed" via a check that measures compilation, not rendering). Do not
report success on structural/self-referential grounds again — every test in this prompt
must call the real production function under test, not a reimplementation of it.
