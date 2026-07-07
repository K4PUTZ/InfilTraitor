# FIX-JUNCTION-COLUMN-MATERIAL-01 — Corner filler columns use the wrong material

> **Prerequisite:** JUNCTION-01b applied (interior corners now correctly get
> filler columns). This patch only fixes the material/color of those
> columns — the geometry/placement logic from JUNCTION-01b is untouched.

---

## CONTEXT

Confirmed via screenshot: corner geometry is now correct (JUNCTION-01b),
but every filler column renders in concrete gray regardless of the actual
wall material it's completing — visible as a mismatched light-gray stripe
on an orange/tan-material corner.

**Root cause:** `JunctionResolver.JunctionColumn` (`junction_resolver.gd`)
never carried a `material` field — only `gu_cell`, `voxel_pos`,
`storey_count`, `start_storey`, `voxels`. `voxel_renderer.gd`'s
`_render_junction_column()` renders every column with the literal string
`"concrete"` hardcoded (line ~157), because it never had anything else to
use. Meanwhile `resolve()` already has both edges that form the corner
(`edge_a`, `edge_b`) in scope at the exact point it constructs each
`JunctionColumn` — each `Edge` already carries its own `material` (see
`edge.gd`) — the value is right there, just never passed through.

**Assumption (both edges normally share material):** for a real corner, the
two wall segments meeting there are normally the same material (e.g. two
`solidblock_concrete` divider cells, or an exterior wall run). Use
`edge_a`'s material as the column's material — if the two ever differ (not
expected in current maps), this picks one deterministically rather than
attempting to blend; not a new problem introduced by this patch.

---

## MODULE

- `godot/scripts/geometry/junction_resolver.gd`
- `godot/scripts/geometry/voxel_renderer.gd`
- `godot/scripts/tools/geometry_selftest.gd`

---

## TASK

### 1. `junction_resolver.gd` — add `material` to `JunctionColumn`

```gdscript
## Container for a corner column at a V-junction.
class JunctionColumn:
	var gu_cell: Vector2i         ## the diagonal GU that owns this column (outside the elbow)
	var voxel_pos: Vector2i       ## the voxel position of the column
	var storey_count: int         ## height (span between start_storey and end)
	var start_storey: int         ## starting storey level
	var material: String          ## material of the walls this column completes
	var voxels: Array[Voxel]      ## the voxel objects

	func _init(p_gu: Vector2i, p_voxel_pos: Vector2i, p_storey_count: int, p_start_storey: int = 0, p_material: String = "concrete"):
		gu_cell = p_gu
		voxel_pos = p_voxel_pos
		storey_count = p_storey_count
		start_storey = p_start_storey
		material = p_material
		voxels = []

	func _to_string() -> String:
		if start_storey > 0:
			return "JunctionColumn{gu=%s, voxel=%s, storeys=%d, start=%d, material=%s}" % [gu_cell, voxel_pos, storey_count, start_storey, material]
		return "JunctionColumn{gu=%s, voxel=%s, storeys=%d, material=%s}" % [gu_cell, voxel_pos, storey_count, material]
```

In `resolve()`, update the construction call (the two edges are already in
scope as `edge_a`/`edge_b` right above it):

```gdscript
					result.append(JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start, edge_a.material))
```

(Replaces the current `JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start)` call — same line, just appending `edge_a.material` as the 5th argument.)

---

### 2. `voxel_renderer.gd` — use the column's material instead of hardcoding

```gdscript
## Render a junction column
func _render_junction_column(column: JunctionResolver.JunctionColumn) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey counts by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(column.start_storey * GeometryCoords.LEVELS_PER_STOREY + column.storey_count * GeometryCoords.LEVELS_PER_STOREY)

	for level_offset in range(column.storey_count * GeometryCoords.LEVELS_PER_STOREY):
		var level := column.start_storey * GeometryCoords.LEVELS_PER_STOREY + level_offset
		_set_voxel_cell(column.voxel_pos, level, column.material)
```

(Only the last line changes: `"concrete"` → `column.material`.)

---

### 3. `geometry_selftest.gd` — verify material propagation

The existing JunctionResolver test cases (Room corner / L-corner) build
edges via `EdgeClass.between(...)` without a material argument, which
defaults to `"concrete"` (see `edge.gd`) — those should still pass unchanged
and will now also carry `material == "concrete"` on their resulting
columns; no assertion changes needed there.

Add one new case, exercising a non-default material, after the existing
X-junction regression guard in the same JunctionResolver group:

```gdscript
	# Case 5 — material propagation: a metal corner must produce a column
	# in "metal", not the old hardcoded "concrete" default.
	var metal_registry = EdgeRegistryClass.new()
	var metal_north = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1, "metal")  # NE face of (2,2)
	var metal_west = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1, "metal")   # NW face of (2,2)
	SliceGeneratorClass.generate([metal_north, metal_west], metal_registry)
	var metal_columns = JunctionResolverClass.resolve(metal_registry)
	total_count += 1
	if metal_columns.size() == 1 and metal_columns[0].material == "metal":
		pass_count += 1
		print("  ✓ Metal corner produces a column with material 'metal': %s" % metal_columns[0])
	else:
		print("  ✗ Metal corner produced wrong material/count: %s — expected 1 column with material 'metal'" % [metal_columns])
```

---

## DO NOT TOUCH

- Corner detection/placement logic in `resolve()` — unchanged, only the
  `JunctionColumn.new(...)` call gains a 5th argument.
- `_render_junction_column()`'s height/layer math — unchanged, only the
  material string passed to `_set_voxel_cell()` changes.
- Any other `JunctionColumn` call sites — there are none outside
  `junction_resolver.gd` and `voxel_renderer.gd` (grep to confirm before
  committing).

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

godot --headless --script res://godot/scripts/tools/geometry_selftest.gd
# expected: all previous JunctionResolver/EdgeExtractor cases still pass,
# plus:
#   ✓ Metal corner produces a column with material 'metal'

## Confirm the old hardcoded literal is gone
grep -n '"concrete"' godot/scripts/geometry/voxel_renderer.gd
# expected: no hit inside _render_junction_column (other "concrete" fallback
# literals elsewhere in the file, e.g. line ~192's tileset fallback, are
# unrelated and untouched)

git diff --name-only
```

**Visual smoke test** — reload the same corner shapes from the reported
screenshot (the orange/tan structure). Filler columns should now match the
color/material of the walls they complete, no mismatched gray stripe.

---

**Scope:** 3 files · 1 field added to a data class + 2 one-line call-site
updates + 1 new selftest case · well under 1 session.
**Version:** bump `VERSION` per repo convention.
