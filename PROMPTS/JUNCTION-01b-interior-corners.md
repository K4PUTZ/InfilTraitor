# JUNCTION-01b — Patch: corner-column filler for interior wall ends

> **Prerequisite:** JUNCTION-02 applied (`junction_resolver.gd` uses the
> GU-space algorithm). **Two-part fix, apply in order** — Part 1 must land
> before Part 2, or Part 2 will generate wrong extra columns at every place
> a divider butts into the exterior wall (see CONTEXT).

---

## CONTEXT

Reported via screenshot + follow-up discussion: exterior perimeter corners
already get a correct filler column (`JunctionResolver`, V-junction case —
2 wall faces meeting at a GU, column placed in the diagonal cell **outside**
the elbow, per the reference diagram the director provided). Interior walls
(dividers, `solidblock_<material>` tiles) never get this treatment, even when
a divider ends in open floor next to a gate — which is architecturally the
same kind of V/L corner and needs the same column, just twice (once for each
side of the stub's open end).

Confirmed with the director: **only true V/L corners need a filler column.**
A T-junction where a divider butts flush into a continuous wall (3 "faces"
by naive count, but two of them are solid-on-solid contact, not open air)
needs **zero** columns — the joint is already fully solid there, nothing to
fill. An X-junction (4-way) is out of scope, same as before.

**Root cause of why interior corners never worked, found by manual trace of
`sigma_01_map.gd`'s divider A (`y=9`, segments `x=1-3`, `x=6-11`, `x=14-16`,
gates at `x=4-5` and `x=12-13`):**

1. `edge_extractor.gd`'s second pass (`solidblock_` exposure culling, ~line
   118) only culls a face when the **neighbor is also `solidblock_`**
   occupied. It does not know about `wall_` tiles at all. So a divider cell
   butting flush against the exterior wall (e.g. divider cell at inner
   `(1,9)`, next to the west wall at `(0,9)`) gets a **spurious** extra face
   on the side facing the wall — even though that side is solid-on-solid,
   not open. This inflates a true T (2 real opposite faces + 1 spurious) to
   look like 3 faces, same raw count as a real free-standing end.
2. `junction_resolver.gd` currently only processes cells with **exactly 2**
   faces (pure V-junctions). Any cell with 3+ faces — real free end *or*
   the spurious T above — is skipped outright. That's why real gate-end
   corners silently get 0 columns today: they're 3-face cells and never
   even reach the pair-check logic.

**Why the fix must be two parts, in order:** if we only generalized
`JunctionResolver` to handle 3-face cells (Part 2) without first fixing the
spurious-face bug (Part 1), a divider ending flush against the exterior wall
would present faces `{spurious-wall-side, real-north, real-south}` — an
adjacent (non-opposite) pairing with the spurious face would produce **two
bogus columns** at a joint that needs none (violating the "T needs zero"
rule just confirmed). Part 1 removes the spurious face first, so that case
correctly reduces to `{real-north, real-south}` — opposite faces, i.e. a
straight wall passing through, 0 columns, via the **existing, unmodified**
logic. Only genuinely free-standing ends (real faces on all 3 open sides)
reach Part 2's new pair logic.

---

## MODULE

- `godot/scripts/geometry/edge_extractor.gd` *(Part 1)*
- `godot/scripts/geometry/junction_resolver.gd` *(Part 2)*
- `godot/scripts/tools/geometry_selftest.gd` *(new + extended test cases)*

---

## TASK

### Part 1 — `edge_extractor.gd`: cull solidblock faces against flush walls too

Add a `wall_cells` occupancy set, populated in the existing first-pass loop
(the branch that already handles `tile_name.begins_with("wall_")`).
Immediately after the existing `if suffix not in _EDGE_BY_SUFFIX: ... continue`
guard, before the rest of that branch's logic, add:

```gdscript
				wall_cells[cell] = true
```

Declare `wall_cells` alongside the existing `solidblock_occupancy` declaration:

```gdscript
	# Build occupancy map for solidblock_ entries: (cell, storey) -> material
	# Used for exposure culling: a face is only emitted if the neighbor is NOT occupied
	var solidblock_occupancy: Dictionary = {}  # (cell, storey) key -> material

	# Cells that carry a "wall_" tile (exterior/room-perimeter walls). Used
	# alongside solidblock_occupancy for exposure culling: a solidblock_ cell
	# butting flush into one of these has no real gap there either.
	var wall_cells: Dictionary = {}  # Vector2i -> true
```

Then in the second pass (the solidblock exposure-culling loop), change:

```gdscript
			# Skip face if neighbor is also occupied by solidblock_ (buried, not exposed)
			if neighbor_key in solidblock_occupancy:
				continue
```

to:

```gdscript
			# Skip face if neighbor is also occupied by solidblock_ (buried, not exposed)
			if neighbor_key in solidblock_occupancy:
				continue

			# Exterior/room walls are flush, full-height (up to
			# EXTERIOR_WALL_STOREYS) solid contact too — a solidblock_ cell
			# butting into one has no real gap there. Without this, a
			# divider ending flush against a wall (a true T-junction) is
			# miscounted as having an extra open face and gets wrongly
			# treated as a free corner needing a filler column.
			if wall_cells.has(neighbor_cell) and storey < MapCompilerClass.EXTERIOR_WALL_STOREYS:
				continue
```

`MapCompilerClass` is already imported at the top of this file (`const
MapCompilerClass = preload(...)`), no new import needed.

Legacy `block_` tiles are untouched by this change — they don't participate
in `solidblock_occupancy`/`wall_cells` at all (separate branch, separate
`result["solid_blocks"]` output, per Finding B, still not part of the Edge/
JunctionResolver pipeline).

---

### Part 2 — `junction_resolver.gd`: generalize `resolve()` to 3-face cells

Update the class doc comment: replace

```
## Scope: pure V-junctions only (exactly 2 walls meeting at one cell). T/X
## junctions (3–4 walls at a cell) are intentionally skipped — see JUNCTION-01b.
```

with

```
## Scope: V-junctions (2 walls) and free-standing wall ends (3 walls, all
## genuinely open — e.g. a divider stopping next to a gate) both get filler
## columns, one per adjacent (non-opposite) pair of occupied faces at the
## cell. A true T-junction (a wall butting flush into another, already-solid
## wall) also presents as 3 faces on a naive count, but EdgeExtractor's
## exposure culling (see edge_extractor.gd) already removes the spurious
## flush-contact face before this ever sees it, so it correctly reduces to 2
## opposite (straight-through) faces — 0 columns, nothing to fill. This only
## works because that culling fix landed first; see JUNCTION-01b prompt.
## X-junctions (4 walls) are intentionally skipped — assumed already covered
## by surrounding wall geometry; revisit only if a real gap is reported there.
```

Inside `resolve()`, replace the single-pair block:

```gdscript
			## Pure V-junction only: exactly 2 walls at this cell. 1 wall =
			## plain wall segment, nothing to close. 3–4 walls = T/X, out
			## of scope here (see class doc comment).
			if faces_at_cell.size() != 2:
				continue

			var faces: Array = faces_at_cell.keys()
			var fa: int = faces[0]
			var fb: int = faces[1]

			## Opposite faces (NW-SE or NE-SW) = a straight wall passing
			## through the cell, not a turn. No column needed.
			if fb == Face.opposite(fa):
				continue

			var edge_a: Edge = faces_at_cell[fa]
			var edge_b: Edge = faces_at_cell[fb]

			## fa, fb adjacent and non-opposite → their deltas sum to a
			## clean (±1, ±1): the cell diagonal to the elbow, outside both
			## walls — the visual notch that needs the filler column.
			var d: Vector2i = Face.delta(fa) + Face.delta(fb)
			var diagonal_cell: Vector2i = gu + d

			# Compute storey span: from min(start_storey) to max(start_storey + storey_count)
			var min_start := mini(edge_a.start_storey, edge_b.start_storey)
			var max_end := maxi(edge_a.start_storey + edge_a.storey_count, edge_b.start_storey + edge_b.storey_count)
			var junction_storey_count := max_end - min_start

			## The one voxel inside diagonal_cell nearest the elbow — the
			## corner of its 8×8 block that actually touches `gu`.
			var origin := GeometryCoords.gu_to_voxel_origin(diagonal_cell)
			var last := GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
			var local_x := last if d.x < 0 else 0
			var local_y := last if d.y < 0 else 0
			var voxel_pos := origin + Vector2i(local_x, local_y)

			result.append(JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start))
```

with:

```gdscript
			## V-junction (2 walls) and free-standing wall ends (3 walls,
			## all genuinely open — see class doc comment) both close
			## notches, one filler column per adjacent (non-opposite) pair
			## of occupied faces. X-junction (4 walls) stays out of scope.
			if faces_at_cell.size() < 2 or faces_at_cell.size() > 3:
				continue

			var faces: Array = faces_at_cell.keys()
			for i in range(faces.size()):
				for j in range(i + 1, faces.size()):
					var fa: int = faces[i]
					var fb: int = faces[j]

					## Opposite faces (NW-SE or NE-SW) = a straight wall
					## passing through the cell, not a turn — including the
					## real-T case (see class doc comment), which reduces
					## to exactly this after EdgeExtractor's culling fix.
					if fb == Face.opposite(fa):
						continue

					var edge_a: Edge = faces_at_cell[fa]
					var edge_b: Edge = faces_at_cell[fb]

					## fa, fb adjacent and non-opposite → their deltas sum
					## to a clean (±1, ±1): the cell diagonal to the elbow,
					## outside both walls — the visual notch that needs the
					## filler column.
					var d: Vector2i = Face.delta(fa) + Face.delta(fb)
					var diagonal_cell: Vector2i = gu + d

					# Compute storey span: from min(start_storey) to max(start_storey + storey_count)
					var min_start := mini(edge_a.start_storey, edge_b.start_storey)
					var max_end := maxi(edge_a.start_storey + edge_a.storey_count, edge_b.start_storey + edge_b.storey_count)
					var junction_storey_count := max_end - min_start

					## The one voxel inside diagonal_cell nearest the elbow
					## — the corner of its 8×8 block that actually touches
					## `gu`.
					var origin := GeometryCoords.gu_to_voxel_origin(diagonal_cell)
					var last := GeometryCoords.VOXELS_PER_UNIT_AXIS - 1
					var local_x := last if d.x < 0 else 0
					var local_y := last if d.y < 0 else 0
					var voxel_pos := origin + Vector2i(local_x, local_y)

					result.append(JunctionColumn.new(diagonal_cell, voxel_pos, junction_storey_count, min_start))
```

No change to `JunctionColumn` (fields unchanged), no change to
`voxel_renderer.gd` (it only reads `storey_count`/`voxel_pos`/`gu_cell`,
shape unchanged — it now just gets called with more entries in the array).

---

### Part 3 — `geometry_selftest.gd` — new EdgeExtractor group + 2 more JunctionResolver cases

**3a. New test group**, exercising Part 1 directly through `EdgeExtractor`
(not just synthetic `Edge` objects, since the bug is in the culling logic
itself). Add this as its own group, anywhere after the "Class Loading"
group and before the "JunctionResolver" group:

```gdscript
	# GROUP: EdgeExtractor — solidblock_ exposure culling against wall_ tiles
	# (JUNCTION-01b Part 1: a divider butting flush into a wall must not
	# expose a spurious face on that side — see edge_extractor.gd header).
	print("\nGROUP: EdgeExtractor — solidblock/wall flush-contact culling")
	var EdgeExtractorClass = load("res://godot/scripts/geometry/edge_extractor.gd")
	var JunctionResolverClass2 = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeRegistryClass2 = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass2 = load("res://godot/scripts/geometry/slice_generator.gd")

	# Case A — a 3-cell divider (x=1,2,3 @ y=1) boxed in by a west wall at
	# x=0 and an east wall at x=4 (both 3 rows tall, y=0..2). This is the
	# real T-junction shape from sigma_01_map.gd's divider A meeting the
	# perimeter wall: flush solid contact on both ends. Must produce ZERO
	# columns anywhere — the joint is fully solid, nothing to fill.
	var t_wall_levels: Array = [[
		{"cell": Vector2i(0, 0), "tile_name": "wall_NW"},
		{"cell": Vector2i(0, 1), "tile_name": "wall_NW"},
		{"cell": Vector2i(0, 2), "tile_name": "wall_NW"},
		{"cell": Vector2i(4, 0), "tile_name": "wall_SE"},
		{"cell": Vector2i(4, 1), "tile_name": "wall_SE"},
		{"cell": Vector2i(4, 2), "tile_name": "wall_SE"},
		{"cell": Vector2i(1, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(2, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(3, 1), "tile_name": "solidblock_concrete"},
	]]
	var t_extraction: Dictionary = EdgeExtractorClass.extract({"wall_levels": t_wall_levels})
	var t_reg = EdgeRegistryClass2.new()
	SliceGeneratorClass2.generate(t_extraction["edges"], t_reg)
	var t_junction_columns = JunctionResolverClass2.resolve(t_reg)
	total_count += 1
	if t_junction_columns.is_empty():
		pass_count += 1
		print("  ✓ Divider flush against walls on both ends (true T) produces 0 columns")
	else:
		print("  ✗ Divider flush against walls produced %d bogus column(s), expected 0: %s" % [t_junction_columns.size(), t_junction_columns])

	# Case B — the same divider shape, but free-standing (no walls at
	# either end, e.g. stopping next to an open gate on both sides). Each
	# end is a genuine free corner and needs 2 filler columns (one per
	# side), 4 total. Hand-derived: west end at (1,1) → columns at (0,0)
	# and (0,2); east end at (2,1)... wait, at (2,1) with only 2 cells —
	# use the 2-cell divider (x=1,2 @ y=1) so each cell IS an end:
	# (1,1) faces {NW,NE,SW} → columns (0,0),(0,2); (2,1) faces
	# {NE,SE,SW} → columns (3,0),(3,2).
	var free_wall_levels: Array = [[
		{"cell": Vector2i(1, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(2, 1), "tile_name": "solidblock_concrete"},
	]]
	var free_extraction: Dictionary = EdgeExtractorClass.extract({"wall_levels": free_wall_levels})
	var free_reg = EdgeRegistryClass2.new()
	SliceGeneratorClass2.generate(free_extraction["edges"], free_reg)
	var free_columns = JunctionResolverClass2.resolve(free_reg)
	var free_cells := {}
	for col in free_columns:
		free_cells[col.gu_cell] = true
	var expected_free := [Vector2i(0, 0), Vector2i(0, 2), Vector2i(3, 0), Vector2i(3, 2)]
	var free_ok := free_columns.size() == 4
	for e in expected_free:
		if not free_cells.has(e):
			free_ok = false
	total_count += 1
	if free_ok:
		pass_count += 1
		print("  ✓ Free-standing 2-cell divider produces exactly 4 columns at both ends: %s" % free_columns)
	else:
		print("  ✗ Free-standing divider produced %d column(s): %s — expected 4 at (0,0),(0,2),(3,0),(3,2)" % [free_columns.size(), free_columns])

```

**3b. Extend the existing JunctionResolver group** — add after the existing
3 cases (Room corner / L-corner / Straight-through), inside the same group,
as a regression guard that X-junctions stay out of scope:

```gdscript
	# Case 4 — X-junction regression guard: all 4 faces of (2,2) occupied
	# (4-way intersection, all genuinely open). Must still produce 0
	# columns — out of scope by design (see junction_resolver.gd class doc
	# comment).
	var x_registry = EdgeRegistryClass.new()
	var x_west = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)   # NW face
	var x_east = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)   # SE face
	var x_north = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1)  # NE face
	var x_south = EdgeClass.between(Vector2i(2, 2), Vector2i(2, 3), 1)  # SW face
	SliceGeneratorClass.generate([x_west, x_east, x_north, x_south], x_registry)
	var x_columns = JunctionResolverClass.resolve(x_registry)
	total_count += 1
	if x_columns.is_empty():
		pass_count += 1
		print("  ✓ X-junction (all 4 faces at 2,2) produces 0 columns (out of scope)")
	else:
		print("  ✗ X-junction produced %d column(s), expected 0: %s" % [x_columns.size(), x_columns])
```

---

## DO NOT TOUCH

- `JunctionColumn` class shape (`gu_cell`, `voxel_pos`, `storey_count`,
  `start_storey`, `voxels`) — unchanged, so `voxel_renderer.gd` needs no edit.
- The 3 existing V-junction selftest cases (Room corner / L-corner /
  Straight-through) — must still pass unmodified, byte-for-byte.
- Legacy `block_` tile handling in `edge_extractor.gd` (Finding B) — not
  touched, not part of `solidblock_occupancy`/`wall_cells`, stays its own
  separate `result["solid_blocks"]` path.
- X-junction handling beyond the new regression guard — still explicitly
  skipped, not implemented.
- `room.gd` line ~1561 dead `JunctionResolver.resolve()` copy — pre-existing,
  unrelated, flagged for a future dead-code sweep.

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"

## Selftest passes, all groups including the 2 new/extended ones
godot --headless --script res://godot/scripts/tools/geometry_selftest.gd
# expected (JunctionResolver group):
#   ✓ Room corner (walls at 2,2) produces exactly 1 column at GU (1,1)
#   ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,3)
#   ✓ Straight-through wall (opposite faces) produces 0 columns
#   ✓ X-junction (all 4 faces at 2,2) produces 0 columns (out of scope)
# expected (new EdgeExtractor group):
#   ✓ Divider flush against walls on both ends (true T) produces 0 columns
#   ✓ Free-standing 2-cell divider produces exactly 4 columns at both ends

## Only the 3 MODULE files changed
git diff --name-only
```

**Visual smoke test** — load SIGMA_01, look at divider A/B/C near their gate
openings (e.g. the segment ends around inner `x=3`/`x=6`, `y=9`). Each free
end should now show a filler column matching the wall height, no visible
notch. Then re-check: (1) the 4 exterior room corners still look correct
(unchanged), (2) a divider's end where it meets the exterior wall (e.g.
inner `(1,9)` or `(16,9)`) shows **no** extra column — flush solid contact,
as before.

---

**Scope:** 3 files · 1 exposure-culling condition added + 1 method body
generalized (single pair → loop over pairs) + 2 new/extended selftest groups
· 1 session.
**Version:** bump `VERSION` per repo convention.
