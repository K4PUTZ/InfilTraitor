# BAKE-FIX-10 — Junction Override Authoring in `resolve()`, and a Test That Isn't Circular

> **Corrective prompt, re-opens BAKE-FIX-06's Tasks 2 and 3. Depends on BAKE-FIX-09
> (the underlying lookup must actually resolve before a mirroring test can assert
> anything real). An Overlord audit (2026-07-07) found: (a) `JunctionResolver.resolve()`
> still unconditionally hardcodes `facade_enabled = true, override_material = ""` for
> every column (`junction_resolver.gd:125`) — the override-authoring investigation
> BAKE-FIX-06 was explicitly tasked with was never performed; (b) the rewritten
> `bake_fix_02_test.gd` still contains the exact circular pattern the prompt named and
> banned, and its "mirroring" test explicitly admits, in its own code comment, that it
> does no real rendering. `OPERATOR_CONTEXT.md` currently claims "3/3 PASS" for tests
> that do not verify what their names claim.**

---

## CONTEXT

**Task 2 (override authoring) — not done, silently relying on unrelated code.**
`JunctionResolver.resolve()` (`junction_resolver.gd:56-127`) builds every
`JunctionColumn` with a hardcoded `true` / `""`:
```gdscript
result.append(JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start, edge_a.material, true, "", fa, fb, edge_a.id, edge_b.id))
```
Separately, `room_builder.gd::_apply_junction_overrides()` (lines 307-325) and
`map_compiler.gd::_compile_junction_overrides()` (lines 306-316) do apply
`layout["junction_overrides"]` as a **post-processing step after `resolve()` runs** —
but this mechanism predates BAKE-FIX-06 (it was added in the BAKE-FIX-04 commit,
`c8a9467`, a doc-only prompt that was not supposed to touch production code) and was
never verified, touched, or even mentioned by BAKE-FIX-06's completion. Whether
post-hoc application in `room_builder.gd` is an acceptable substitute for reading the
override inside `resolve()` itself was never decided — it was just left as-is by
default.

**Task 3 (non-circular test) — still circular.**
`godot/scripts/tools/bake_fix_02_test.gd::_test_junction_override_application()`
(lines 90-147) does exactly what the original BAKE-FIX-06 prompt banned:
```gdscript
column.override_material = "wood"
column.facade_enabled = false
...
if column.override_material != "wood":
    print("✗ FAIL: Override material not applied...")
```
It sets a field, then asserts that same field has the value just set. This proves
nothing about whether the real override-application code path (whatever it turns out
to be per Task 1 below) actually works.

`_test_junction_mirroring_rendering()` (lines 150-223) only checks that fields
(`face_a`, `face_b`, `edge_a_id`, `edge_b_id`) are populated and that edges are
look-up-able by ID. Its own comment admits: *"Real rendering would need a full
VoxelRenderer context, which is complex in headless mode"* — no `Image` is ever
created or compared, no mirrored pixel is ever checked. None of the three required
cases from the original prompt (default mirror / override+facade-on /
override+facade-off) are actually tested.

---

## MODULE

- `godot/scripts/geometry/junction_resolver.gd` — `resolve()`: decide and implement
  where the override gets read
- `godot/scripts/world/builders/room_builder.gd` — `_apply_junction_overrides()`:
  read/reconcile with whatever Task 1 decides
- `godot/scripts/world/maps/map_compiler.gd` — `_compile_junction_overrides()`: read
  only, to confirm the real schema (lines ~306-316)
- `godot/scripts/tools/bake_fix_02_test.gd` — rewrite the two broken tests

---

## TASK

### 1. Decide where the override should actually be applied, deliberately

Read `room_builder.gd`'s `_apply_junction_overrides()` and `map_compiler.gd`'s
`_compile_junction_overrides()` in full to understand exactly how
`layout["junction_overrides"]` reaches a `JunctionColumn` today. Then make an explicit
choice and document it in the completion report:

- **Option A:** `JunctionResolver.resolve()` takes the compiled overrides as a
  parameter (or via a registry it's given) and applies them directly when constructing
  each `JunctionColumn`, replacing the hardcoded `true`/`""`. This matches what the
  original BAKE-FIX-02/06 prompts asked for literally.
- **Option B:** keep post-hoc application in `room_builder.gd`, but make this a
  deliberate, documented architectural decision (not a silent default) — update
  `resolve()`'s doc comment to say overrides are intentionally applied after
  resolution, and verify `_apply_junction_overrides()` actually works end-to-end with
  a real test (Task 2 below), which has never been done.

Pick one. Whichever you pick, the key deliverable is that **the actual override
application path gets a real, non-circular test** — right now neither path has ever
been verified to work.

### 2. Rewrite the non-circular test

Replace `_test_junction_override_application()` so it does not set-then-assert the
same field. Instead:
- Compile a real MapSpec with a `junction_overrides` entry keyed to a real `gu` cell
  that will produce a junction column (build a small synthetic map/registry that
  triggers a V-junction at that cell).
- Run it through the **real** production pipeline (`map_compiler.gd` →
  `room_builder.gd` → `JunctionResolver.resolve()`, whichever path Task 1 settled on)
  end to end.
- Assert the resulting `JunctionColumn` for that cell has the override material/
  facade_enabled — proving the override actually flowed through the real pipeline,
  not that a bare object remembers a value assigned to it a line earlier.

### 3. Rewrite the mirroring test to do real rendering (depends on BAKE-FIX-09)

Now that `BakedTileLookup.resolve()` genuinely resolves (per BAKE-FIX-09),
`_test_junction_mirroring_rendering()` must:
- Build a real run of 3+ collinear edges ending in a V-junction via
  `EdgeRegistry`/`JunctionResolver.resolve()` (already partially done).
- Actually invoke `_render_junction_column()`'s neighbor-lookup + mirror logic (or the
  smallest real subset of `VoxelRenderer` needed to exercise it headlessly — check
  what `bake_fix_03_pixel_comparison_tool.gd`/BAKE-FIX-11 uses for headless rendering,
  since that's the same problem) and compare the actual resolved
  `atlas_coords`/`alternative_id`/pixel data against the neighbor's, confirming the
  mirror is real (e.g. an actual `TileData.flip_h = true` on the returned
  alternative, or actual pixel-level horizontal mirroring if you capture an `Image`).
- Cover the three cases the original prompt specified: default mirror, override +
  facade_enabled=true (mirrored override material), override + facade_enabled=false
  (flat, no baked lookup attempted — verify by checking which branch executed, not
  just the final material name).

No test may set a field on a bare object and then assert that same field's value.

---

## DO NOT TOUCH

- `JunctionResolver.resolve()`'s V/T/X junction **detection** logic — correct, not in
  question.
- `voxel_renderer.gd::_render_junction_column()`'s mirroring implementation itself
  (the neighbor-lookup + `create_alternative_tile`/`flip_h` logic from BAKE-FIX-06) —
  that part was verified as real; this prompt only needs it to be properly exercised
  by a real test, not modified.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
godot --headless --script godot/scripts/tools/bake_fix_02_test.gd
# expected: literal PASS lines with real evidence — the override test must show the
# override compiled from a real MapSpec and flowing through the real pipeline; the
# mirroring test must show real resolved atlas_coords/alternative_id/pixel comparison
```

- Completion report states explicitly which option (A or B) was chosen for override
  application and why.
- Completion report shows, per test, the literal evidence (compiled override →
  resulting column fields; resolved neighbor atom → mirrored result), not just "PASS".
- Bump `VERSION` per repo convention.

---

**Scope:** ~3-4 files touched · closes out the two BAKE-FIX-06 gaps once BAKE-FIX-09's
lookup fix is in place to give the mirroring test something real to check against.
