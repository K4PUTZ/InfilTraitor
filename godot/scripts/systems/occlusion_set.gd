## Occlusion Module — Computes which geometry occludes the agent
##
## POLICY: O1 — Occlusion is VIEW, not STATE
## - _occluded_cells is owned solely by this module
## - Never writes Voxel.visible, never uses dirty flag, never persists
## - NEVER reads _active_perspective (coordinates already rotated when entering)
##
## POLICY: O4′ — One view-space formula, no rotation applied
## The map is rebuilt rotated; we compute in already-rotated coordinates.
##
## POLICY: O5 — Depth is (x + y) in view-space, never z_index
## Isometric diamond layout: screen-y ∝ (x + y). Greater sum = nearer camera.
##
## POLICY: O7 — Glass does not occlude (a see-through pane hides nothing).
## A slice whose base material is glass is filtered out in _group_slices_by_edge()
## — see that function's header.

class_name OcclusionSet

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FaceMod = preload("res://godot/scripts/geometry/face.gd")
const SlabMod = preload("res://godot/scripts/geometry/slab.gd")

## ============================================================================
## TUNING (exposed as adjustable, for Director to dial against screenshots)
## ============================================================================

## OCC-08 (2026-07-14): the agent's own screen silhouette — used for the trigger
## test (does an EDGE's whole slice tower visually overlap him). Should track
## agent.gd's SILHOUETTE_WIDTH/HEIGHT; kept as separate constants rather than
## importing agent.gd, to keep this a dependency-free "pure geometry" module —
## re-sync by hand if the agent's on-screen size ever changes.
##
## RE-SYNCED 2026-08-16, per that instruction: 22/61 described the vector diamond
## placeholder, which Part 2 §10 deleted. The baked figure measures 104 x 222 px
## on screen (agent_frame_bake_spike.gd's own silhouette readout, standing, the
## widest and tallest of the four facings). The old pair understated the agent by
## 3.6x in height, so a wall tower overlapping his head did not trigger the ghost
## at all.
var silhouette_half_width_px: float = 52.0
var silhouette_height_px: float = 222.0

## How many hops along the wall's own connectivity graph the ring falloff reaches
## from a triggering edge. Ring alphas themselves live in VoxelBoard.GHOST_ALPHAS
## (3 entries) — this must stay one less than that array's size.
const MAX_RING: int = 2
## R3D-7: how many adjacent roof slabs an origin under a roof opens (the slab above it counts as the first), and how
## many of the last of them fade.
const ROOF_REACH: int = 6
const ROOF_FADE: int = 2
## Whether two roof slabs that only touch at a corner count as adjacent (square rings around the agent) or only
## slabs that share an edge do (diamond rings). Square: a rectangular room opens whole, corners included.
const ROOF_ADJACENT_CORNERS: bool = true

## OCC-10 (2026-07-14): superseded the OCC-09 pixel-threshold reveal cutoff.
## Director's call after seeing it live: the OCC-09 reveal (lower storeys popping
## back to fully opaque, pixel-threshold-timed) looked worse than the ghost it
## replaced. Simpler rule, no agent-relative math needed: an occluded edge's own
## bottom BASE_VISIBLE_LEVELS levels (full width, both faces — a fixed 8×N×2
## footprint) are left COMPLETELY UNTOUCHED, always reading as solid ground-truth
## geometry; everything above that ghosts at the ring alpha exactly as it always
## has (OCC-08/O6). Fixed, not derived — no pixel math, no agent-relative
## geometry for this part any more.
const BASE_VISIBLE_LEVELS: int = 2

## ROOF-OCC-01 (2026-07-18, Director-ratified design): roof occlusion reveals a
## roof in SCREEN-HORIZONTAL STRIPES — one stripe = every roofed GU of a
## connected roof component sharing one gu.x + gu.y sum (an anti-diagonal in
## grid space, which projects as a horizontal row of GU diamonds on screen).
## A component this many stripes or fewer (the TEXTURES 3×3 towers are exactly
## 5) is "small": it never does partial reveals — every stripe of it ghosts at
## once, so the whole roof reads as one wireframe of the roof's own shape.
const SMALL_ROOF_MAX_STRIPES: int = 5

## ============================================================================
## STATE (owned solely by this module)
## ============================================================================

## The set of voxel cells that occlude the agent, mapped to ring index (0/1/2).
## Key: Vector2i voxel cell (voxel-grid coordinate space)
## R3D-7 (Director, 2026-09-20: "representacao por GU para os tetos"): the set is TWO things, not one column dictionary.
##  · `_column_entries`: column -> {ring, min_level, max_level} for what needs column resolution: wall and junction columns,
##    the 1-voxel border a roof grows past its GU, and any column where those overlap a revealed roof GU (merged entry:
##    ring = the smaller, span = the union, exactly as when everything was one dictionary).
##  · `_roof_gus`: gu -> one shared entry for every roof GU that is revealed, covering that GU's 8x8 core columns.
## A revealed 15x15 roof is 121 entries instead of 7 744, and everything that used to walk it (the change test, the
## exposure, the texture) walks GUs. `get_occluded_cells()` still returns the merged per-column dictionary, built on demand
## for the 2D board and the tests.
var _column_entries: Dictionary = {}
var _roof_gus: Dictionary = {}
var _expanded: Dictionary = {}
var _expanded_valid: bool = false

## OCC-27 (2026-07-21): wireframe geometry, keyed by LEVEL — supersedes the old
## per-structural-unit "_occluded_edges" segment list. Each entry:
##   int level -> {"lines": Array[{"a","b","level","solid","ring"}],
##                 "fills": Array[{"p": PackedVector2Array, "alpha": float}]}
## Built once per recompute() by _build_wireframe_geometry(), a single hidden-
## face-culling pass over the UNIFIED _occluded_cells set (walls, junctions and
## roofs already all merge into that one dictionary) — not one independent box
## per wall Edge / roof GU / junction column any more. See that function's
## header for why.
var _wireframe_full: Dictionary = {}  ## with fills, built lazily by get_wireframe_by_level()
var _wireframe_by_level: Dictionary = {}

## Recomputation counter (for verification of cadence)
var _recompute_count: int = 0

## ============================================================================
## API
## ============================================================================

## Query the occluded-cell set.
## Returns: Dictionary of voxel COLUMN (x,y only) → {"ring": int, "min_level": int}.
## "min_level" is where ghosting starts (OCC-10: the edge's true base plus
## BASE_VISIBLE_LEVELS) — a column key alone cannot tell
## VoxelBoard.apply_occlusion() which of ITS levels are the always-visible
## base versus the ghosted rest, so the level floor has to travel with the cell.
func get_occluded_cells() -> Dictionary:
	return _expand().duplicate()


## The merged per-column dictionary (see `_column_entries` / `_roof_gus`), built on the first ask after a change.
func _expand() -> Dictionary:
	if _expanded_valid:
		return _expanded
	var out: Dictionary = _column_entries.duplicate()
	var gu_info: Dictionary = _roof_geometry["gu_info"]
	for gu: Vector2i in _roof_gus:
		var entry: Dictionary = _roof_gus[gu]
		for cell: Vector2i in (gu_info[gu] as Dictionary)["core"]:
			if not out.has(cell):
				out[cell] = entry
	_expanded = out
	_expanded_valid = true
	return out


## The columns that need column resolution: wall / junction columns, roof borders, and their merges with revealed roofs.
## Read-only: do not modify.
func get_column_entries() -> Dictionary:
	return _column_entries


## Every revealed roof GU -> its shared entry. Read-only: do not modify.
func get_roof_gus() -> Dictionary:
	return _roof_gus


func is_empty() -> bool:
	return _column_entries.is_empty() and _roof_gus.is_empty()


## The entry of one column, or null when it is not occluded: a column entry, else the roof GU whose core holds it.
func entry_at(column: Vector2i) -> Variant:
	var entry: Variant = _column_entries.get(column)
	if entry != null:
		return entry
	return _roof_gus.get(Vector2i(column.x >> 3, column.y >> 3))


static func _merged(a: Dictionary, b: Dictionary) -> Dictionary:
	return {
		"ring": mini(int(a["ring"]), int(b["ring"])),
		"min_level": mini(int(a["min_level"]), int(b["min_level"])),
		"max_level": maxi(int(a["max_level"]), int(b["max_level"])),
	}


## Wireframe geometry, keyed by level — see _wireframe_by_level.
func get_wireframe_by_level() -> Dictionary:
	## The 2D overlay's view: lines AND fills. The fills are one dictionary per column, face and level, so they are
	## built on the first ask for this set (`_wireframe_full`), not on every recompute.
	if _wireframe_full.is_empty() and not is_empty():
		var merged: Dictionary = _expand()
		_wireframe_full = _build_wireframe_geometry(merged, _build_exposure(merged, {}), true)
	return _wireframe_full.duplicate()


## The outline only: what the 3D cutaway draws. Built with every recompute that changes the set.
func get_wireframe_lines_by_level() -> Dictionary:
	return _wireframe_by_level.duplicate()

## Get the recomputation counter for verification.
## Instrument (R3D-7 Moto): usec of the last recompute() by phase — group slices, edge occlusion, expand to voxel
## columns (+ junctions), roof, wireframe (0 when the set did not change).
var last_phase_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])
## The last phase split further (usec): merge the roof into the set, compare with the previous set, interior cells,
## exposure, wireframe lines.
var last_tail_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])


func get_recompute_count() -> int:
	return _recompute_count

## ============================================================================
## RECOMPUTATION (called from room.gd on agent step + view change)
## ============================================================================

## Recompute the occluded-cell set given current agent position(s) and geometry.
## Called on: agent.step_finished signal, _set_perspective(), hover cell change
##
## Args:
##   agent_cells: Array[Vector2i] — one or more origin cells (gameplay grid cells).
##     First entry is always the agent's real position; subsequent entries are
##     additional points of interest (e.g. hover cell for preview).
##   slices: Array[Slice] — every Slice currently rendered (room._edge_registry.all_slices())
##   room_size: Vector2i — size of room in gameplay grid units
##   junction_columns: Array[JunctionResolver.JunctionColumn] — corner filler columns
##     (room._junction_columns); ghosted only when BOTH walls they fill the elbow
##     between are themselves occluded (OCC-10, see the loop below).
##   ceiling_slabs: Array[Slab] — every Role.CEILING slab currently registered
##     (room._slab_registry, already view-rotated by the rebuild). ROOF-OCC-01:
##     roofs participate in occlusion as screen-horizontal GU stripes.
func recompute(agent_cells, slices: Array, room_size: Vector2i, junction_columns: Array = [], ceiling_slabs: Array = []) -> void:
	## Backward compatibility: accept single Vector2i as well as Array[Vector2i]
	var origins: Array[Vector2i] = []
	if agent_cells is Vector2i:
		origins = [agent_cells]
	elif agent_cells is Array:
		origins = agent_cells
	else:
		push_error("[OCC-HOVER-01] recompute() expects Vector2i or Array[Vector2i], got %s" % type_string(typeof(agent_cells)))
		return
	
	var ph0: int = Time.get_ticks_usec()
	var slices_by_edge := _grouped_slices(slices)
	var ph1: int = Time.get_ticks_usec()
	## R3D-7 (Moto): the whole result is a pure function of these inputs (geometry is static between rebuilds), so
	## the last few are kept — the hover cell and the agent come back to cells they have already been on.
	var memo_key: Array = [origins.duplicate(), _group_key, _objects_key(ceiling_slabs), _objects_key(junction_columns),
		room_size, silhouette_half_width_px, silhouette_height_px]
	if memo_enabled and _memo.has(memo_key):
		var hit: Array = _memo[memo_key]
		if hit[0] != _column_entries or hit[1] != _roof_gus:
			_column_entries = hit[0]
			_roof_gus = hit[1]
			_exposure = hit[2]
			_wireframe_by_level = hit[3]
			_wireframe_full = {}
			_expanded_valid = false
			_recompute_count += 1
		last_phase_usec = PackedInt64Array([ph1 - ph0, 0, 0, 0, 0])
		return
	var occlusion := compute_edge_occlusion(origins, slices_by_edge, room_size)
	var ph2: int = Time.get_ticks_usec()
	var edges: Array = occlusion["edges"]

	var new_occluded: Dictionary = {}
	var ring_by_edge_id: Dictionary = {}
	for e in edges:
		ring_by_edge_id[e["edge_id"]] = e["ring"]
		for column in _edge_columns(e["edge_id"], slices_by_edge):
			## OCC-09/OCC-10: min_level travels WITH the cell — a column key
			## alone would leave VoxelBoard.apply_occlusion() unable to tell
			## which of a column's levels are the always-visible base versus
			## the ghosted rest above it.
			## OCC-26 (2026-07-18): max_level travels too. The erase used to run
			## to the top of every layer, which also ate the ROOF's 1-voxel
			## border row sitting in the wall's own columns (levels above the
			## wall's top) — the visible roof edge then fell back one voxel
			## deeper, reading as a ~4-screen-px seam between the roofline and
			## the wireframe's top cap (Director's "wireframe shifted 3-4 px",
			## erase-diff measured). A cell claimed by two edges keeps the
			## wider vertical span.
			var span_min: int = e["min_level"]
			var span_max: int = e["max_level"]
			if new_occluded.has(column):
				var prev: Dictionary = new_occluded[column]
				span_min = mini(span_min, prev["min_level"])
				span_max = maxi(span_max, prev["max_level"])
			new_occluded[column] = {"ring": e["ring"], "min_level": span_min, "max_level": span_max}

	## OCC-10/OCC-13/OCC-14 (2026-07-14): junction filler columns aren't part of
	## any Slice/Edge of their own — Director's rule, confirmed on annotated
	## screenshots: ghost one only when BOTH edges it fills the elbow between are
	## occluded; a column with only one occluded neighbor stays fully visible.
	## Always ring 0 (the minimum alpha) — it has no ring of its own to inherit,
	## and picking between its two neighbors' rings would be an arbitrary
	## tie-break. It also gets its own thin "lightsaber" wireframe unit — a real
	## 1×1-voxel box (its own actual footprint), not a flat line, per the
	## Director's OCC-14 correction ("ainda parece que as paredes viraram folhas
	## de papel, e os lightsabers parecem apenas uma linha"). Director's diagram:
	## "EXTRA COLUMNS FILLING V JUNCTIONS MUST FOLLOW THE SAME DESIGN" (a base
	## band below, wireframe above, just like an edge's own unit).
	for column in junction_columns:
		if not (ring_by_edge_id.has(column.edge_a_id) and ring_by_edge_id.has(column.edge_b_id)):
			continue
		var col_base_level: int = GeometryCoordsMod.storey_level_base(column.start_storey)
		var col_max_level: int = col_base_level + column.storey_count * GeometryCoordsMod.LEVELS_PER_STOREY - 1
		var col_ghost_start: int = mini(col_base_level + BASE_VISIBLE_LEVELS, col_max_level + 1)
		## OCC-26: junction fillers cap their erase at their own top as well.
		## OCC-27: the old "lightsaber" wireframe unit (OCC-14/OCC-21e, disabled
		## after the Director found it visually bad as an independent box) is
		## superseded — this column now joins the SAME unified _occluded_cells
		## set walls and roofs already merge into, so _build_wireframe_geometry()
		## gives it real exposed-face wireframe automatically, with no seam
		## against a neighbouring occluded edge (the thing that made the old
		## independent box look wrong in the first place).
		new_occluded[column.voxel_pos] = {"ring": 0, "min_level": col_ghost_start, "max_level": col_max_level}

	## ROOF-OCC-01: roofs join the set as screen-horizontal GU stripes. Runs
	## after walls/junctions so a cell shared with a wall column (the roof's
	## 1-voxel border row) widens that entry's vertical span instead of
	## replacing it.
	var ph3: int = Time.get_ticks_usec()
	var roof := _compute_roof_occlusion(origins, ceiling_slabs, ring_by_edge_id, slices_by_edge)
	var ph4: int = Time.get_ticks_usec()
	var ph5: int = ph4
	var tl0: int = Time.get_ticks_usec()
	var tl1: int = tl0
	var tl2: int = tl0
	var tl3: int = tl0
	var tl4: int = tl0
	## Roof GUs stay GUs. What is per COLUMN is only the border a roof grows past its GU (its outer 1-voxel row, which
	## reaches the wall's outer slice) and the columns where a wall, a junction, another roof's border or a revealed roof
	## core overlap: those get the merged entry (smaller ring, union of spans), the same value the one big dictionary held.
	var roof_gus: Dictionary = roof["gus"]
	var gu_info: Dictionary = _roof_geometry["gu_info"]
	for gu: Vector2i in roof_gus:
		var gu_entry: Dictionary = roof_gus[gu]
		for cell: Vector2i in (gu_info[gu] as Dictionary)["border"]:
			var prev: Variant = new_occluded.get(cell)
			new_occluded[cell] = gu_entry if prev == null else _merged(prev, gu_entry)
	for cell: Vector2i in new_occluded.keys():
		var covering: Variant = roof_gus.get(Vector2i(cell.x >> 3, cell.y >> 3))
		if covering != null and not is_same(new_occluded[cell], covering):
			new_occluded[cell] = _merged(new_occluded[cell], covering)

	# Only update if the set changed
	tl1 = Time.get_ticks_usec()
	var changed: bool = new_occluded != _column_entries or roof_gus != _roof_gus
	tl2 = Time.get_ticks_usec()
	tl3 = tl2
	if changed:
		_column_entries = new_occluded
		_roof_gus = roof_gus
		_expanded_valid = false
		_exposure = _build_exposure_by_gu()
		tl4 = Time.get_ticks_usec()
		var edge_entries: Dictionary = {}
		for column: Vector2i in _exposure:
			edge_entries[column] = entry_at(column)
		_wireframe_by_level = _build_wireframe_geometry(edge_entries, _exposure, false)
		_wireframe_full = {}
		ph5 = Time.get_ticks_usec()
		_recompute_count += 1
		if _recompute_count % 10 == 0 or not is_empty():
			var line_count := 0
			for level in _wireframe_by_level:
				line_count += _wireframe_by_level[level]["lines"].size()
			print_debug("[OcclusionSet] Recomputed: %d column entries, %d roof GUs, %d wireframe lines (count=%d)" % [
				_column_entries.size(), _roof_gus.size(), line_count, _recompute_count
			])
	if memo_enabled:
		if _memo.size() >= MEMO_MAX:
			_memo.erase(_memo.keys()[0])
		_memo[memo_key] = [_column_entries, _roof_gus, _exposure, _wireframe_by_level]
	last_phase_usec = PackedInt64Array([ph1 - ph0, ph2 - ph1, ph3 - ph2, ph4 - ph3, ph5 - ph4])
	last_tail_usec = PackedInt64Array([tl1 - tl0, tl2 - tl1, tl3 - tl2, tl4 - tl3, ph5 - tl4 if tl4 > tl0 else 0])

## ============================================================================
## OCC-27 (2026-07-21) — unified wireframe: hidden-face culling over the
## shared occluded-column set
## ============================================================================

## The four planar neighbour directions tested per occluded column. Order
## doesn't matter — each is independent.
const _FACE_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Director-ratified redesign (2026-07-21), replacing OCC-13's "one
## independent box per structural unit" (one per wall Edge, one per roof
## GU-rectangle, one disabled per junction column). OCC-13 explicitly
## accepted the overlap at a unit-to-unit boundary as "expected, not a
## defect" — in practice it was: every boundary between two occluded units
## (wall-to-wall, wall-to-junction, GU-to-GU) drew a full extra wireframe
## edge that didn't correspond to any real silhouette, reading as a
## serrated/jagged line and, in aggregate, as "muito poluído" (Director,
## live). ROOF-OCC-02 (2026-07-20) patched this locally for roof GUs only
## (rectangle-merge); this supersedes that too — walls, junctions and roofs
## already all fold into ONE shared dictionary (`occluded`, identical to
## _occluded_cells / what VoxelBoard.apply_occlusion() erases), so instead
## of trusting each generator's own idea of its unit's shape, this runs ONE
## real hidden-face-culling pass directly against that shared ground truth —
## the same principle voxel engines use for chunk meshing (Minecraft-style
## "only mesh a face if the neighbour across it is air"): a face is INTERNAL
## (never drawn) iff the neighbouring column is ALSO occluded and its level
## range covers this level; EXTERNAL (drawn) otherwise. This kills every
## unit-to-unit seam by construction, for walls, junctions and roofs alike,
## in one pass, rather than patching one axis at a time.
##
## Deliberately not merged into longer runs along a straight boundary: each
## exposed 1-voxel face only ever draws the 2 endpoints its own boundary is
## entitled to, so a straight run of many contiguous exposed faces becomes
## many collinear 1-voxel segments that already read as one continuous line
## (solid style) or one evenly-spaced dotted line (dots style, matching the
## OCC-18 per-voxel-boundary dot spacing) — visually identical to an
## explicit run-merge, without the extra rectangle-decomposition bookkeeping
## ROOF-OCC-02 needed and this now removes.
##
## Visibility/style convention (hidden-line removal, CAD tradition): O5 (top
## of file) fixes camera depth as x+y, greater = nearer. A face exposed
## toward +x or +y (EAST/SOUTH) is this volume's OWN near side — nothing of
## its own bulk sits between that face and the camera — drawn as a plain
## SOLID line, no dots. A face exposed toward -x or -y (WEST/NORTH) is the
## volume's far side, behind its own bulk from the camera's POV — drawn as
## DOTS only, no line underneath. The flat TOP rim is the one exception:
## nothing overhangs it from this camera angle regardless of which side of
## the rim it's on, so every top-level cap edge draws SOLID regardless of
## direction. The ghosted band's own BOTTOM is never capped at all — it sits
## directly on the edge's real, opaque, always-visible base (BASE_VISIBLE_
## LEVELS), which is not a true external boundary, just an internal render
## style change within the same solid structure.
##
## Args: occluded — the SAME dict as _occluded_cells (voxel column Vector2i
## -> {"ring","min_level","max_level"}), already merged across walls,
## junctions and roofs by the time recompute() calls this.
## Returns: Dictionary int level -> {"lines": Array, "fills": Array}
##   "lines": {"a": Vector2i, "b": Vector2i, "level_a": int, "level_b": int,
##     "solid": bool} — the line runs from _voxel_to_screen(a, level_a) to
##     _voxel_to_screen(b, level_b). Two shapes share this: a=b (same lattice
##     point) with level_a/level_b = level/level+1 is a true VERTICAL corner
##     (drawn only at a run's real start/end, never per interior voxel — see
##     the width-axis run-boundary check below); a!=b with level_a==level_b
##     is a flat top-cap rim edge (both endpoints at the same height).
##   "fills": {"kind": "side"/"top", "a": Vector2i, "b": Vector2i, "level":
##     int, "ring": int} — "side" is a vertical quad from level to level+1
##     along the a-b lattice edge; "top" is the column's own flat footprint
##     quad at level+1 (level here is always the column's own max_level+1).
## True if `column` (assumed present in `occluded`) has an EXTERNAL
## (exposed) face in direction `dir` — its neighbour in that direction is
## either absent, or present but with a vertical range that never overlaps
## this column's own (see _build_wireframe_geometry's header for why overlap,
## not exact-level match, is the right test). Shared by the main pass and by
## the width-axis run boundary check (a face is only a true run START/END
## when its along-the-run neighbour does NOT share the same exposure).
static func _is_exposed(occluded: Dictionary, column: Vector2i, dir: Vector2i) -> bool:
	var entry: Dictionary = occluded[column]
	var neighbour := column + dir
	if not occluded.has(neighbour):
		return true
	var n: Dictionary = occluded[neighbour]
	return not (int(n["min_level"]) <= int(entry["max_level"]) and int(n["max_level"]) >= int(entry["min_level"]))


## Public: the order of `_FACE_DIRS`, which is the bit order of every exposure mask.
const FACE_DIRS: Array[Vector2i] = _FACE_DIRS
var _exposure: Dictionary = {}   ## column -> bitmask of exposed faces (bit i = FACE_DIRS[i]); columns with none are absent


## Which faces of each occluded column are EXPOSED (see `_is_exposed`), computed once per set and read by the wireframe,
## the 3D cutaway's side fills and its caps, which used to recompute it three times over. Read-only: do not modify.
func get_exposure() -> Dictionary:
	return _exposure


## The mask `_is_exposed` gives for each direction, for every column of `occluded` that has any exposed face, in the
## set's own order. `unexposed` names columns known to have none (interior cells of a uniformly ghosted roof GU).
func _build_exposure(occluded: Dictionary, unexposed: Dictionary) -> Dictionary:
	var exposure: Dictionary = {}
	for column: Vector2i in occluded:
		if unexposed.has(column):
			continue
		var entry: Dictionary = occluded[column]
		var lo: int = entry["min_level"]
		var hi: int = entry["max_level"]
		var mask: int = 0
		for dir_index: int in range(4):
			var neighbour: Variant = occluded.get(column + _FACE_DIRS[dir_index])
			if neighbour == null or not (int((neighbour as Dictionary)["min_level"]) <= hi and int((neighbour as Dictionary)["max_level"]) >= lo):
				mask |= 1 << dir_index
		if mask != 0:
			exposure[column] = mask
	return exposure


## The same exposure `_build_exposure(_expand(), {})` gives, without expanding: a column entry is evaluated as before
## (its four neighbours through `entry_at`); a revealed roof GU can only have an exposed face on the columns along its
## four sides, and only on a side whose neighbouring GU is not a revealed roof with an overlapping span, so those, 8
## columns a side, are the only roof columns ever looked at. The interior of a roof, and every side shared with another
## revealed roof of the same height, costs nothing. A merged entry always spans at least what the roof does, which is
## why a column entry across a shared side cannot un-hide it.
func _build_exposure_by_gu() -> Dictionary:
	var exposure: Dictionary = {}
	for column: Vector2i in _column_entries:
		var entry: Dictionary = _column_entries[column]
		var lo: int = entry["min_level"]
		var hi: int = entry["max_level"]
		var mask: int = 0
		for dir_index: int in range(4):
			var neighbour: Variant = entry_at(column + _FACE_DIRS[dir_index])
			if neighbour == null or not (int((neighbour as Dictionary)["min_level"]) <= hi and int((neighbour as Dictionary)["max_level"]) >= lo):
				mask |= 1 << dir_index
		if mask != 0:
			exposure[column] = mask
	var per_axis: int = GeometryCoordsMod.VOXELS_PER_UNIT_AXIS
	for gu: Vector2i in _roof_gus:
		var roof: Dictionary = _roof_gus[gu]
		var lo: int = roof["min_level"]
		var hi: int = roof["max_level"]
		var origin: Vector2i = GeometryCoordsMod.gu_to_voxel_origin(gu)
		for dir_index: int in range(4):
			var dir: Vector2i = _FACE_DIRS[dir_index]
			var across: Variant = _roof_gus.get(gu + dir)
			if across != null and int((across as Dictionary)["min_level"]) <= hi and int((across as Dictionary)["max_level"]) >= lo:
				continue
			for k: int in range(per_axis):
				var column: Vector2i
				if dir.x == 1:
					column = origin + Vector2i(per_axis - 1, k)
				elif dir.x == -1:
					column = origin + Vector2i(0, k)
				elif dir.y == 1:
					column = origin + Vector2i(k, per_axis - 1)
				else:
					column = origin + Vector2i(k, 0)
				if _column_entries.has(column):
					continue  ## evaluated above, with its own (merged) entry
				var neighbour: Variant = entry_at(column + dir)
				if neighbour == null or not (int((neighbour as Dictionary)["min_level"]) <= hi and int((neighbour as Dictionary)["max_level"]) >= lo):
					exposure[column] = int(exposure.get(column, 0)) | (1 << dir_index)
	return exposure


func _build_wireframe_geometry(occluded: Dictionary, exposure: Dictionary, with_fills: bool) -> Dictionary:
	var by_level: Dictionary = {}

	## Only the columns with at least one exposed face (`exposure`, in the set's own order) can contribute a line
	## or a side fill, so the loop is over those; the exposure of a column is read, not recomputed.
	for column: Vector2i in exposure:
		var mask: int = exposure[column]
		var entry: Dictionary = occluded[column]
		var min_level: int = entry["min_level"]
		var max_level: int = entry["max_level"]
		var ring: int = entry["ring"]
		if min_level > max_level:
			continue
		var cx: int = column.x
		var cy: int = column.y

		for dir_index: int in range(4):
			if not (mask & (1 << dir_index)):
				continue  ## hidden-face culling: bordered by more occluded volume
			var dir: Vector2i = _FACE_DIRS[dir_index]

			## Width axis: perpendicular to dir, the direction ALONG which many
			## contiguous exposed voxels of the SAME face read as one boundary
			## run. Verticals only belong at a run's true start/end (see
			## header) — an interior voxel's own verticals would just be
			## duplicates of its neighbours', drawn once per voxel instead of
			## once per run, which is what made a wide wall face look like a
			## picket fence of parallel dotted lines instead of one clean edge.
			var width_step: Vector2i = Vector2i(0, 1) if dir.x != 0 else Vector2i(1, 0)
			var run_start: bool = not (exposure.get(column - width_step, 0) & (1 << dir_index))
			var run_end: bool = not (exposure.get(column + width_step, 0) & (1 << dir_index))

			var p1: Vector2i
			var p2: Vector2i
			if dir.x == 1:
				p1 = Vector2i(cx + 1, cy); p2 = Vector2i(cx + 1, cy + 1)
			elif dir.x == -1:
				p1 = Vector2i(cx, cy); p2 = Vector2i(cx, cy + 1)
			elif dir.y == 1:
				p1 = Vector2i(cx, cy + 1); p2 = Vector2i(cx + 1, cy + 1)
			else:
				p1 = Vector2i(cx, cy); p2 = Vector2i(cx + 1, cy)

			var near_facing: bool = (dir.x == 1 or dir.y == 1)  ## O5: +x/+y = nearer camera

			for level in range(min_level, max_level + 1):
				var is_top: bool = (level == max_level)
				if not by_level.has(level):
					by_level[level] = {"lines": [], "fills": []}
				var level_data: Dictionary = by_level[level]

				## Two TRUE VERTICALS (fixed lattice point, level -> level+1),
				## only at the run's real ends — not a "p1-to-p2" edge redrawn
				## at every level, which drew a stack of horizontal rungs up
				## the wall's whole height (the actual bug behind the
				## "venetian blind"/dense-mesh look this redesign was meant
				## to remove).
				if run_start:
					level_data["lines"].append({"a": p1, "b": p1, "level_a": level, "level_b": level + 1, "solid": near_facing})
				if run_end:
					level_data["lines"].append({"a": p2, "b": p2, "level_a": level, "level_b": level + 1, "solid": near_facing})

				if with_fills:
					level_data["fills"].append({"kind": "side", "a": p1, "b": p2, "level": level, "ring": ring})

				if is_top:
					## Flat-top rim edge: always solid — nothing overhangs the
					## top from this camera angle, regardless of direction.
					## A real width-direction edge (both endpoints at the SAME
					## level), unlike the verticals above.
					level_data["lines"].append({"a": p1, "b": p2, "level_a": level + 1, "level_b": level + 1, "solid": true})

	## Top fills: NOT emitted per column above. A flat roof/box top is many
	## contiguous occluded columns sharing one (max_level, ring) — filling
	## each column's own 1-voxel quad independently tiled hundreds of tiny
	## translucent polygons edge-to-edge, and Godot's own polygon-edge
	## antialiasing double-blends at every shared seam between them, reading
	## as a fine grid printed across the whole roof (the same class of
	## unwanted "internal line" this whole redesign exists to remove — just
	## coming from fill antialiasing instead of wireframe geometry). Grouping
	## by (max_level, ring) and merging each group into maximal rectangles
	## (same row-run + vertical-merge technique ROOF-OCC-02 used, generalized
	## to any occluded column, not just roof GUs) collapses the common flat
	## case to one polygon — no internal seam left to antialias.
	if not with_fills:
		return by_level

	var top_groups: Dictionary = {}  ## "level|ring" -> Array[Vector2i]
	for column: Vector2i in occluded:
		var entry: Dictionary = occluded[column]
		var key := "%d|%d" % [int(entry["max_level"]), int(entry["ring"])]
		if not top_groups.has(key):
			top_groups[key] = []
		top_groups[key].append(column)

	for key: String in top_groups:
		var parts: PackedStringArray = key.split("|")
		var level: int = int(parts[0])
		var ring: int = int(parts[1])
		if not by_level.has(level):
			by_level[level] = {"lines": [], "fills": []}
		for rect in _merge_columns_into_rects(top_groups[key]):
			by_level[level]["fills"].append({
				"kind": "top", "a": Vector2i(rect[0], rect[1]), "b": Vector2i(rect[2] + 1, rect[3] + 1),
				"level": level + 1, "ring": ring,
			})

	return by_level


## Decompose a set of grid columns into a small number of maximal axis-
## aligned rectangles: maximal horizontal runs per row, then runs with an
## identical x-range merged vertically across consecutive rows. Not
## guaranteed minimal for an arbitrary polyomino, but exact (every input
## column covered exactly once, no overlap) and collapses the common case —
## a flat rectangular roof/box top — to a single rectangle. Row order
## matters: rows must be walked ascending so a run only ever merges downward
## into rows not yet visited. Returns Array of [x0, y0, x1, y1] (inclusive).
func _merge_columns_into_rects(cells: Array) -> Array:
	var by_row: Dictionary = {}   ## y -> Array[x]
	for c: Vector2i in cells:
		if not by_row.has(c.y):
			by_row[c.y] = []
		by_row[c.y].append(c.x)
	for y in by_row:
		by_row[y].sort()

	var row_runs: Dictionary = {}      ## y -> Array[[x0, x1]]
	var run_lookup: Dictionary = {}    ## "y|x0|x1" -> true, O(1) vertical-merge lookups
	for y in by_row:
		var xs: Array = by_row[y]
		var runs: Array = []
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] == prev + 1:
				prev = xs[i]
				continue
			runs.append([run_start, prev])
			run_lookup["%d|%d|%d" % [y, run_start, prev]] = true
			run_start = xs[i]
			prev = xs[i]
		runs.append([run_start, prev])
		run_lookup["%d|%d|%d" % [y, run_start, prev]] = true
		row_runs[y] = runs

	var rows_sorted: Array = row_runs.keys()
	rows_sorted.sort()

	var consumed: Dictionary = {}
	var rects: Array = []
	for y in rows_sorted:
		for run in row_runs[y]:
			var x0: int = run[0]
			var x1: int = run[1]
			var run_key := "%d|%d|%d" % [y, x0, x1]
			if consumed.has(run_key):
				continue
			consumed[run_key] = true
			var y1 := int(y)
			while true:
				var next_key := "%d|%d|%d" % [y1 + 1, x0, x1]
				if run_lookup.has(next_key) and not consumed.has(next_key):
					consumed[next_key] = true
					y1 += 1
				else:
					break
			rects.append([x0, y, x1, y1])
	return rects

## ============================================================================
## CORE COMPUTATION (pure geometry, no I/O)
## ============================================================================

## POLICY: O7 — GLASS DOES NOT OCCLUDE (GLASS_MASTER_PLAN, Director 2026-08-31:
## *"tem algum problema com a oclusão. Podemos considerar não fazer em materiais
## de vidro."*).
##
## A glass pane is see-through by construction (G-D1) — the agent behind it is
## already visible, so ghosting it reveals nothing. And glass voxels render on
## their own `_glass_layers`, which `VoxelBoard.apply_occlusion()` never
## touches (it erases `_layers` only); the wireframe would then draw its lines
## and translucent fills over a pane that is still solid on screen. So a glass
## slice contributes nothing here: no trigger, no wireframe, no ghost band.
##
## A slice is skipped whole when its BASE material is glass — that covers the
## panes, the glass blocks, and the G-D9 brick-capped window (base glass; its
## sill/head bands are extremity voxels that never cover the agent's silhouette).
## A mostly-opaque wall with a small glass viewport (base NOT glass) still
## occludes, which is correct. Guard-through-glass vision is G-D7, a separate
## roll, and has nothing to do with render occlusion.
func _group_slices_by_edge(slices: Array) -> Dictionary:
	var by_edge: Dictionary = {}
	for slice in slices:
		if slice.voxels.is_empty():
			continue
		if GlassMaterials.is_glass(slice.material):
			continue
		if not by_edge.has(slice.edge_id):
			by_edge[slice.edge_id] = []
		by_edge[slice.edge_id].append(slice)
	return by_edge


## OCC-08/OCC-09/OCC-10 (2026-07-14): decide occlusion per EDGE — the real
## wall-column object (one grid boundary, every storey it has) — with a genuine
## 2D (screen-X AND screen-Y) overlap test against the agent's own silhouette,
## spread outward along the wall's own connectivity graph up to MAX_RING hops.
## Replaces O3″ — see Decisions O3‴, O3⁗ and O3⁗′.
##
## OCC-HOVER-01 (2026-07-15): Multi-origin support — accepts array of agent cells
## (typically [agent_pos] or [agent_pos, hover_cell]), performs trigger test from
## EACH origin, union of seeds feeds BFS. This reveals geometry occluding ANY of
## the provided origins, enabling hover-based occlusion preview without duplicating
## the entire computation pipeline.
##
## Why per-edge, not per-slice (OCC-07): a slice is one storey of one face: a tall
## wall is several stacked slices on the SAME edge. Grouping by edge is what lets
## "does ANY storey of this wall reach the agent's height" be answered once, for the
## wall as a whole, instead of per storey.
##
## Why a real 2D overlap test, not corridor-width + depth-cap (O3″): those two
## ad-hoc tunables (silhouette_half_width_px as a corridor, max_depth_voxels as a
## distance cap) were both proxies for the same real question — "does this
## structure's own screen footprint overlap the agent's own screen footprint?" A
## short nearby wall and a distant but TALL structure both answer that question
## correctly under a real screen-Y (height) test; neither ad-hoc tunable could
## express "far away but tall enough to still reach over him", which is a real,
## reported case.
##
## Why a graph walk for the ring falloff, not distance: two edges are "adjacent"
## if they share a grid VERTEX (corner) — real wall topology, not a distance
## metric. This is what makes a corner or a 4-way junction propagate correctly
## (branching to every wall that actually meets there), and it is naturally
## bounded (no separate depth cap needed) since the walk only ever follows edges
## that physically connect to a trigger, however many hops that takes to reach.
##
## The vertical split (OCC-10, supersedes OCC-09's pixel-threshold reveal): each
## occluded edge's own bottom BASE_VISIBLE_LEVELS levels are left completely
## untouched (always full opacity); everything above ghosts at the ring alpha
## exactly as it always has — a fixed rule, not derived from the agent's screen
## position (see BASE_VISIBLE_LEVELS doc comment for why the pixel-threshold
## version was dropped).
##
## Returns: {"edges": Array}
##   "edges" — one Dictionary per occluded edge, the source of truth for
##     _occluded_cells (recompute() walks each edge's own real voxels to
##     populate it): {"edge_id", "ring", "corner_a", "corner_b", "min_level",
##     "max_level"}. "min_level" is where ghosting STARTS (edge's true base +
##     BASE_VISIBLE_LEVELS).
##   OCC-27 (2026-07-21): this used to also return "segments" — one
##     independent wireframe box per occluded edge (OCC-13/OCC-14/OCC-19).
##     Superseded: the wireframe is now built once, for walls+junctions+roofs
##     together, by _build_wireframe_geometry() over the merged
##     _occluded_cells set — see that function's header for why the old
##     per-edge box was the actual source of the reported seam artifacts.
## `_group_slices_by_edge()` of the same slices, kept while the slices are the same objects (a rebuilt registry
## makes new ones). Keyed on the count and every slice's instance id.
var _group_key: int = -1
var _grouped: Dictionary = {}
var _geom_source: Dictionary = {}
var _geom_by_edge: Dictionary = {}
var _geom_vertices: Dictionary = {}


func _grouped_slices(slices: Array) -> Dictionary:
	var key: int = _objects_key(slices)
	if key != _group_key:
		_group_key = key
		_grouped = _group_slices_by_edge(slices)
		_columns_by_edge.clear()
		_memo.clear()
	return _grouped


func _objects_key(objects: Array) -> int:
	var key: int = objects.size()
	for object in objects:
		key = key * 1000003 + int(object.get_instance_id())
	return key


## The distinct voxel columns of one edge, in the order their first voxel appears. Static per set of slices, and
## exact to use in place of walking every voxel: within one edge every write to a column stores the same entry.
var _columns_by_edge: Dictionary = {}


func _edge_columns(edge_id: String, slices_by_edge: Dictionary) -> Array:
	if not _columns_by_edge.has(edge_id):
		var seen: Dictionary = {}
		for slice in slices_by_edge.get(edge_id, []):
			for voxel in slice.voxels:
				seen[voxel.grid_pos] = true
		_columns_by_edge[edge_id] = seen.keys()
	return _columns_by_edge[edge_id]


## The last few results by input (see `recompute()`); `memo_enabled = false` is the reference path.
const MEMO_MAX: int = 16
var memo_enabled: bool = true
var _memo: Dictionary = {}


func compute_edge_occlusion(agent_cells: Array, slices_by_edge: Dictionary, _room_size: Vector2i) -> Dictionary:
	var half_gu := int(GeometryCoordsMod.VOXELS_PER_UNIT_AXIS / 2.0)
	
	## OCC-HOVER-01: Convert all agent cells to voxel space and screen positions
	var agent_data: Array = []  ## [{"voxel": Vector2i, "depth": int, "screen_x": float, "screen_y_head": float, "screen_y_ground": float}]
	const VOXEL_HALF_W := 16.0   ## GeometryCoords.VOXEL_TILE_SIZE.x * 0.5
	const VOXEL_HALF_H := 8.0    ## GeometryCoords.VOXEL_TILE_SIZE.y * 0.5
	
	for agent_cell in agent_cells:
		var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell) + Vector2i(half_gu, half_gu)
		var agent_depth := agent_voxel.x + agent_voxel.y
		var agent_screen_x := float(agent_voxel.x - agent_voxel.y) * VOXEL_HALF_W
		## The agent "stands" at level 0, reaching up by his own height in pixels — same
		## relative depth*HALF_H formula every voxel layer's screen position uses.
		var agent_screen_y_ground := float(agent_depth) * VOXEL_HALF_H
		var agent_screen_y_head := agent_screen_y_ground - silhouette_height_px
		agent_data.append({
			"voxel": agent_voxel, "depth": agent_depth,
			"screen_x": agent_screen_x,
			"screen_y_head": agent_screen_y_head,
			"screen_y_ground": agent_screen_y_ground
		})

	## One geometry pass per edge: real footprint + screen-X/Y span, from its own
	## voxels across every storey it has (never a generic per-cell guess).
	## R3D-7 (Moto): this pass reads only the slices, never the agent, and walks every voxel of every wall
	## (99 of 124 ms per agent step on the Moto g04s), so it is kept for as long as `slices_by_edge` is the
	## very same Dictionary it was built from. A caller passing a fresh one (the selftests) recomputes.
	var edge_geom: Dictionary = {}        ## edge_id -> geometry dict (see below)
	var vertex_to_edges: Dictionary = {}  ## Vector2i vertex -> Array[String edge_id]
	var reuse: bool = is_same(_geom_source, slices_by_edge) and not slices_by_edge.is_empty()
	if reuse:
		edge_geom = _geom_by_edge
		vertex_to_edges = _geom_vertices

	for edge_id in ([] if reuse else slices_by_edge.keys()):
		var edge_slices: Array = slices_by_edge[edge_id]

		var min_gx: int = edge_slices[0].voxels[0].grid_pos.x
		var max_gx: int = min_gx
		var min_gy: int = edge_slices[0].voxels[0].grid_pos.y
		var max_gy: int = min_gy
		var min_level: int = edge_slices[0].voxels[0].level
		var max_level: int = min_level
		for slice in edge_slices:
			for voxel in slice.voxels:
				min_gx = mini(min_gx, voxel.grid_pos.x)
				max_gx = maxi(max_gx, voxel.grid_pos.x)
				min_gy = mini(min_gy, voxel.grid_pos.y)
				max_gy = maxi(max_gy, voxel.grid_pos.y)
				min_level = mini(min_level, voxel.level)
				max_level = maxi(max_level, voxel.level)

		var center_x := float(min_gx + max_gx) * 0.5
		var center_y := float(min_gy + max_gy) * 0.5
		var center_depth := center_x + center_y

		var corner_a_x := (float(min_gx) - float(min_gy)) * VOXEL_HALF_W
		var corner_b_x := (float(max_gx) - float(max_gy)) * VOXEL_HALF_W
		var screen_x := (corner_a_x + corner_b_x) * 0.5
		var half_width := absf(corner_b_x - corner_a_x) * 0.5

		## y_top is the SMALLER value (higher storeys sit higher on screen);
		## y_bottom is the LARGER value (ground level, nearer the bottom of screen).
		## LEVEL-RENUMBER — a level becomes a SCREEN Y here, so it has to be the
		## level relative to the ground plane, exactly as the layer's own position
		## is. Left absolute, a wall's screen rectangle lands eighty levels off and
		## the overlap test against the agent answers a question about a different
		## wall — measured as 2 112 cells ghosted that the baseline never ghosts.
		var rel_min := float(min_level - GeometryCoordsMod.PLAYABLE_LEVEL)
		var rel_max := float(max_level - GeometryCoordsMod.PLAYABLE_LEVEL)
		var y_bottom := center_depth * VOXEL_HALF_H - rel_min * GeometryCoordsMod.VOXEL_STEP_PX
		var y_top := center_depth * VOXEL_HALF_H - (rel_max + 1.0) * GeometryCoordsMod.VOXEL_STEP_PX

		## OCC-10: fixed always-visible base band — this edge's own bottom
		## BASE_VISIBLE_LEVELS levels are left untouched (full opacity); ghosting
		## starts right above them and runs to the edge's own top, at the ring
		## alpha, same as it always has. No agent-relative math any more (see
		## BASE_VISIBLE_LEVELS doc comment).
		var ghost_start_level := mini(min_level + BASE_VISIBLE_LEVELS, max_level + 1)

		## Adjacency graph: registered for EVERY edge, not just triggers — a
		## non-triggering edge can still be a ring-1/ring-2 stop on the path
		## outward from one.
		var anchor = edge_slices[0]
		var vertices := _edge_vertices(anchor.gu_cell, anchor.face)

		edge_geom[edge_id] = {
			"corner_a": Vector2i(min_gx, min_gy), "corner_b": Vector2i(max_gx, max_gy),
			"depth": center_depth, "screen_x": screen_x, "half_width": half_width,
			"y_top": y_top, "y_bottom": y_bottom,
			"min_level": ghost_start_level, "max_level": max_level,
		}

		for v in vertices:
			if not vertex_to_edges.has(v):
				vertex_to_edges[v] = []
			vertex_to_edges[v].append(edge_id)

	if not reuse:
		_geom_source = slices_by_edge
		_geom_by_edge = edge_geom
		_geom_vertices = vertex_to_edges

	## Trigger test: camera-side + real 2D (screen-X and screen-Y) overlap with the
	## agent's own silhouette rectangle. Uses the edge's UNCLIPPED y_bottom — the
	## vertical reveal cutoff only trims what gets ghosted afterward, it must not
	## change whether an edge counts as a trigger in the first place.
	##
	## OCC-HOVER-01: Test against EACH origin — an edge triggers if it overlaps ANY
	## of the provided agent positions. Seeds accumulate across all origins.
	var seeds: Array = []
	var seed_set: Dictionary = {}  ## deduplication: edge_id -> true
	for agent in agent_data:
		for edge_id in edge_geom.keys():
			if seed_set.has(edge_id):
				continue  ## already triggered by a previous origin
			var g: Dictionary = edge_geom[edge_id]
			if g["depth"] <= agent["depth"]:
				continue
			if absf(g["screen_x"] - agent["screen_x"]) > silhouette_half_width_px + g["half_width"]:
				continue
			if g["y_top"] > agent["screen_y_ground"] or g["y_bottom"] < agent["screen_y_head"]:
				continue
			seeds.append(edge_id)
			seed_set[edge_id] = true

	if seeds.is_empty():
		return {"edges": []}

	## Multi-source BFS along the wall's own connectivity graph, up to MAX_RING hops.
	## Every trigger is its own ring-0 seed — there is no special-cased "the agent's
	## own tile" seed; when he stands against a wall, its edges simply satisfy the
	## trigger test directly, same as any other.
	var ring_by_edge: Dictionary = {}
	var frontier: Array = seeds.duplicate()
	for edge_id in seeds:
		ring_by_edge[edge_id] = 0

	## Director refinement, 2026-07-14: propagate ONLY through a vertex that is a
	## simple pass-through — exactly one other edge touching it — and only onto that
	## edge if it continues in the SAME direction (face). A vertex with more than one
	## other edge is a junction (a corner, a T, a 4-way meeting); a single other edge
	## in a DIFFERENT face is a turn. Both stop the ring right there rather than
	## wrapping onto a wall that just happens to share a corner.
	for hop in range(1, MAX_RING + 1):
		var next_frontier: Array = []
		for edge_id in frontier:
			var anchor = slices_by_edge[edge_id][0]
			var my_face: int = anchor.face
			for v in _edge_vertices(anchor.gu_cell, my_face):
				var touching: Array = vertex_to_edges.get(v, [])
				var other_id: String = ""
				var other_count := 0
				for candidate_id in touching:
					if candidate_id != edge_id:
						other_count += 1
						other_id = candidate_id
				if other_count != 1:
					continue  ## dead end (0) or junction (2+) — do not propagate here
				if ring_by_edge.has(other_id):
					continue
				var other_anchor = slices_by_edge[other_id][0]
				if other_anchor.face != my_face:
					continue  ## direction change — do not propagate
				ring_by_edge[other_id] = hop
				next_frontier.append(other_id)
		frontier = next_frontier

	## OCC-13 (2026-07-14) originally formalized one independent wireframe box
	## per occluded EDGE here, accepting the overlap at a V-junction as
	## "expected, not a defect." OCC-27 (2026-07-21) supersedes that: the
	## overlap read as a real seam in practice, so wireframe geometry no
	## longer comes from here at all — only the edge/ring/level bookkeeping
	## _occluded_cells needs, consumed by recompute().
	var result: Array = []
	for edge_id in ring_by_edge.keys():
		var g: Dictionary = edge_geom[edge_id]
		result.append({
			"edge_id": edge_id, "ring": ring_by_edge[edge_id],
			"corner_a": g["corner_a"], "corner_b": g["corner_b"],
			"min_level": g["min_level"], "max_level": g["max_level"],
		})
	return {"edges": result}


## ============================================================================
## ROOF-OCC-01 — roof occlusion as screen-horizontal GU stripes
## ============================================================================

## Decide which roof GUs ghost, given the current origins and the wall
## occlusion outcome. Pure computation, same contract as the wall half.
##
## Trigger (Director's "same proximity mechanism as walls", adapted to the two
## real cases):
##   (a) CONTAINMENT — an origin's GU is under the roof component (agent or
##       hover preview standing inside a roofed room);
##   (b) WALL-COUPLING — any occluded wall edge belongs to the component's own
##       structure (a solid block's walls just ghosted; TEXTURES towers have no
##       walkable interior, so (a) alone would never fire there, and a roof
##       left floating over an erased-wall glass box hides exactly the space
##       the ghosting exists to reveal).
##
## Reveal: stripes of constant gu.x + gu.y (screen-horizontal rows of GU
## diamonds). ring = |stripe depth − origin depth| (min over origins), occluded
## only within MAX_RING — the reveal follows the agent instead of opening the
## whole interior at once. Small components (≤ SMALL_ROOF_MAX_STRIPES) ghost
## every stripe, ring clamped, so a small roof disappears entirely and leaves
## a wireframe of its own shape (Director's small-roof rule).
##
## Returns {"cells": Dictionary voxel cell → {ring, min_level, max_level}} —
## OCC-27 (2026-07-21): this used to also return one wireframe "segments" box
## per occluded GU (ROOF-OCC-01), then per merged rectangle of same-(ring,
## min_level,max_level) GUs (ROOF-OCC-02). Both are superseded: "cells" alone
## feeds the SAME unified _occluded_cells set walls and junctions merge into,
## and _build_wireframe_geometry() derives wireframe geometry for all three
## together from that shared set — see its header for why.
var _roof_key: int = -1
var _roof_geometry: Dictionary = {"gu_info": {}, "component_of": {}, "components": []}


## One geometry record per roofed GU, and the connected components of roofed GUs (see the comments in the body).
func _build_roof_geometry(ceiling_slabs: Array) -> Dictionary:
	## One geometry record per roofed GU, aggregated over its (usually 2) slab
	## levels: real voxel cells, real footprint bounds, real level span.
	var gu_info: Dictionary = {}   ## gu -> {min_level, max_level, rect_min, rect_max, cells: Array[Vector2i]}
	for slab in ceiling_slabs:
		if slab.role != SlabMod.Role.CEILING or slab.voxels.is_empty():
			continue
		var info: Dictionary
		if gu_info.has(slab.gu_cell):
			info = gu_info[slab.gu_cell]
			info["min_level"] = mini(int(info["min_level"]), slab.level)
			info["max_level"] = maxi(int(info["max_level"]), slab.level)
		else:
			info = {
				"min_level": slab.level, "max_level": slab.level,
				"rect_min": slab.voxels[0].grid_pos, "rect_max": slab.voxels[0].grid_pos,
				"cells": {},
			}
			gu_info[slab.gu_cell] = info
		for voxel in slab.voxels:
			info["cells"][voxel.grid_pos] = true
			info["rect_min"] = Vector2i(
				mini(info["rect_min"].x, voxel.grid_pos.x), mini(info["rect_min"].y, voxel.grid_pos.y))
			info["rect_max"] = Vector2i(
				maxi(info["rect_max"].x, voxel.grid_pos.x), maxi(info["rect_max"].y, voxel.grid_pos.y))

	## Connected components over roofed GUs (4-adjacency, level- and
	## material-blind — contiguous roofs read as one surface, the same rule
	## ROOF-BAKE-02c uses for texture anchors).
	## The 8x8 core columns of each roofed GU, and the cells its slabs cover PAST that core (the border roofs grow to reach
	## a wall's outer slice). The core is what a revealed roof GU stands for; the border is what stays per column.
	for gu: Vector2i in gu_info:
		var info: Dictionary = gu_info[gu]
		var own: Dictionary = info["cells"]
		var core: Array[Vector2i] = []
		var border: Array[Vector2i] = []
		var origin: Vector2i = GeometryCoordsMod.gu_to_voxel_origin(gu)
		for cell: Vector2i in own:
			var local: Vector2i = cell - origin
			if local.x >= 0 and local.y >= 0 and local.x < GeometryCoordsMod.VOXELS_PER_UNIT_AXIS \
					and local.y < GeometryCoordsMod.VOXELS_PER_UNIT_AXIS:
				core.append(cell)
			else:
				border.append(cell)
		info["core"] = core
		info["border"] = border

	var component_of: Dictionary = {}   ## gu -> component index
	var components: Array = []          ## index -> Array[Vector2i]
	for start_gu: Vector2i in gu_info:
		if component_of.has(start_gu):
			continue
		var idx := components.size()
		var members: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start_gu]
		component_of[start_gu] = idx
		while not stack.is_empty():
			var gu: Vector2i = stack.pop_back()
			members.append(gu)
			for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var neighbour := gu + delta
				if gu_info.has(neighbour) and not component_of.has(neighbour):
					component_of[neighbour] = idx
					stack.append(neighbour)
		components.append(members)

	return {"gu_info": gu_info, "component_of": component_of, "components": components}


func _compute_roof_occlusion(origins: Array, ceiling_slabs: Array, ring_by_edge_id: Dictionary, slices_by_edge: Dictionary) -> Dictionary:
	var result := {"gus": {}}
	if ceiling_slabs.is_empty():
		return result

	## The roofs' own geometry (per roofed GU: cells, footprint, level span; and the connected components) reads only
	## the slabs, never an origin, so it is kept while the slabs are the same objects (R3D-7, Moto: 25 ms per step).
	var roof_key: int = _objects_key(ceiling_slabs)
	if roof_key != _roof_key:
		_roof_key = roof_key
		_roof_geometry = _build_roof_geometry(ceiling_slabs)
	var gu_info: Dictionary = _roof_geometry["gu_info"]
	if gu_info.is_empty():
		return result
	var component_of: Dictionary = _roof_geometry["component_of"]
	var components: Array = _roof_geometry["components"]

	## Activation set — trigger (a): containment.
	var active: Dictionary = {}   ## component index -> true
	var contained: Dictionary = {}   ## component index -> true when an origin stands under it
	for origin: Vector2i in origins:
		if component_of.has(origin):
			active[component_of[origin]] = true
			contained[component_of[origin]] = true

	## Trigger (b): wall-coupling. An occluded edge belongs to a structure when
	## either GU beside it is roofed — slices_by_edge anchors carry (gu_cell,
	## face); the face's outward neighbour is the other side.
	var coupled: Dictionary = {}   ## component index -> true when an occluded wall belongs to it
	for edge_id in ring_by_edge_id.keys():
		var anchor = slices_by_edge[edge_id][0]
		for gu in [anchor.gu_cell, anchor.gu_cell + _face_neighbour_delta(anchor.face)]:
			if component_of.has(gu):
				active[component_of[gu]] = true
				coupled[component_of[gu]] = true

	if active.is_empty():
		return result

	var origin_depths: Array[int] = []
	for origin: Vector2i in origins:
		origin_depths.append(origin.x + origin.y)

	for idx in active.keys():
		var members: Array = components[idx]
		var stripe_depths: Dictionary = {}   ## depth sum -> true
		for gu: Vector2i in members:
			stripe_depths[gu.x + gu.y] = true
		var is_small: bool = stripe_depths.size() <= SMALL_ROOF_MAX_STRIPES

		## R3D-7 (Director, 2026-09-20): a roof an origin stands UNDER opens like a wall does, by ADJACENCY: the slab
		## above the origin is ring 0 and every roof slab that many steps away (4-adjacency) is one ring further,
		## up to ROOF_REACH slabs, the last ROOF_FADE of them fading (rings 1 and 2). A whole ordinary room opens; an
		## immense roof opens a disc around the agent only. A roof activated only by an occluded wall of its own
		## structure keeps the stripe rule below.
		var slab_rings: Dictionary = {}   ## gu -> ring, only for a contained component
		if contained.has(idx):
			slab_rings = _roof_slab_rings(origins, gu_info, component_of, int(idx))

		for gu: Vector2i in members:
			var ring := MAX_RING + 1
			var revealed: bool = false
			if slab_rings.has(gu):
				ring = int(slab_rings[gu])
				revealed = true
			if coupled.has(idx) or not contained.has(idx):
				var stripe_ring: int = MAX_RING + 1
				for d in origin_depths:
					stripe_ring = mini(stripe_ring, absi((gu.x + gu.y) - d))
				if is_small:
					stripe_ring = mini(stripe_ring, MAX_RING)
				if stripe_ring <= MAX_RING:
					ring = mini(ring, stripe_ring) if revealed else stripe_ring
					revealed = true
			if not revealed:
				continue   ## out of reveal range: stays solid

			var info: Dictionary = gu_info[gu]

			## One entry per revealed GU (read-only; a merge makes a new one).
			result["gus"][gu] = {"ring": ring, "min_level": info["min_level"], "max_level": info["max_level"]}
	return result


## The roof slabs an origin opens by adjacency: multi-source breadth-first search from every origin that stands under
## this component, over roofed GUs (edge-sharing or, with ROOF_ADJACENT_CORNERS, corner-touching), to ROOF_REACH slabs. Returns gu -> ring (0 = fully open ... 2 = the faintest of the
## fade). See the comment where it is called.
const _ROOF_NEIGHBOURS_4: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const _ROOF_NEIGHBOURS_8: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


func _roof_slab_rings(origins: Array, gu_info: Dictionary, component_of: Dictionary, component: int) -> Dictionary:
	var rings: Dictionary = {}
	var frontier: Array[Vector2i] = []
	var distance: Dictionary = {}
	for origin: Vector2i in origins:
		if component_of.get(origin, -1) == component and not distance.has(origin):
			distance[origin] = 0
			frontier.append(origin)
	var hop: int = 0
	while not frontier.is_empty() and hop < ROOF_REACH:
		var fade_start: int = ROOF_REACH - ROOF_FADE
		var next_frontier: Array[Vector2i] = []
		for gu: Vector2i in frontier:
			rings[gu] = maxi(0, hop - fade_start + 1)
			for delta: Vector2i in (_ROOF_NEIGHBOURS_8 if ROOF_ADJACENT_CORNERS else _ROOF_NEIGHBOURS_4):
				var neighbour: Vector2i = gu + delta
				if gu_info.has(neighbour) and not distance.has(neighbour):
					distance[neighbour] = hop + 1
					next_frontier.append(neighbour)
		frontier = next_frontier
		hop += 1
	return rings


## Outward neighbour GU across a face — the other side of a (gu_cell, face)
## wall segment, matching _edge_vertices()'s compass.
func _face_neighbour_delta(face: int) -> Vector2i:
	match face:
		FaceMod.NW:
			return Vector2i(-1, 0)
		FaceMod.NE:
			return Vector2i(0, -1)
		FaceMod.SE:
			return Vector2i(1, 0)
		FaceMod.SW:
			return Vector2i(0, 1)
		_:
			return Vector2i.ZERO


## The two grid-VERTEX corners of a (gu_cell, face) wall segment. Both faces of the
## same physical edge (face_a on gu_a, and the complementary face_b on gu_b) resolve
## to the SAME two vertices by construction, so it never matters which side's
## (gu_cell, face) a caller has on hand — see Face.gd for the compass convention.
func _edge_vertices(gu_cell: Vector2i, face: int) -> Array:
	var x := gu_cell.x
	var y := gu_cell.y
	match face:
		FaceMod.NW:
			return [Vector2i(x, y), Vector2i(x, y + 1)]
		FaceMod.NE:
			return [Vector2i(x, y), Vector2i(x + 1, y)]
		FaceMod.SE:
			return [Vector2i(x + 1, y), Vector2i(x + 1, y + 1)]
		FaceMod.SW:
			return [Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
		_:
			return []
