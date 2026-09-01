## Geometry Module — GlassPaneGrouper (GLASS_MASTER_PLAN §4, G2).
##
## Stamps `Slice.pane_id` on every glass slice in an EdgeRegistry so the cascade
## (G3) can take a whole continuous surface from one hit. Run once at map load,
## right after SliceGenerator.generate(), never per shot.
##
## Two producers, one consumer:
##
##  · BLOCKS — "um bloco é um bloco" (G-D2). Every glass `solid_block_instance`
##    footprint cell is merged into one set and FLOOD-FILLED into connected
##    components (§4.2); each component is one pane. This is deliberately NOT
##    per-authored-instance: PLAYGROUND spells a 3-wide glass block as three
##    adjacent 1×1 declarations, and those are one block, not three.
##
##  · PANELS — contiguous coplanar half-thickness faces. Union-find: two glass
##    panel slices are the same pane when they share a face orientation AND their
##    owning GUs are adjacent along that face's RUN axis (perpendicular to
##    Face.delta). A lone panel is its own pane.
##
## Every glass slice leaves this pass with a non-empty `pane_id`.
class_name GlassPaneGrouper


static func assign(edge_registry: EdgeRegistry, solid_block_instances: Array) -> void:
	var glass: Array = []
	for slice in edge_registry.all_slices():
		if _is_glass_slice(slice):
			glass.append(slice)
	if glass.is_empty():
		return

	## --- blocks: one merged cell set, flood-filled into components --------
	var block_cells: Dictionary = {}   ## Vector2i -> true
	for b in solid_block_instances:
		if not (b is Dictionary) or String(b.get("material", "")) != "glass":
			continue
		var origin: Vector2i = b.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = b.get("size", Vector2i.ONE)
		for dx in range(maxi(1, size.x)):
			for dy in range(maxi(1, size.y)):
				block_cells[origin + Vector2i(dx, dy)] = true
	var cell_pane: Dictionary = _flood_components(block_cells)   ## Vector2i -> "PANE_BLOCK_n"

	var panels: Array = []
	for slice in glass:
		var owner_cell: Vector2i = slice.gu_cell
		var back_cell: Vector2i = slice.gu_cell + Face.delta(slice.face)
		if cell_pane.has(owner_cell):
			slice.pane_id = cell_pane[owner_cell]
		elif cell_pane.has(back_cell):
			slice.pane_id = cell_pane[back_cell]
		else:
			panels.append(slice)

	## --- panels: union-find over coplanar adjacency ---------------------
	var parent: Dictionary = {}
	for s in panels:
		parent[s.id] = s.id
	for i in range(panels.size()):
		for j in range(i + 1, panels.size()):
			var a: Slice = panels[i]
			var b2: Slice = panels[j]
			if a.face != b2.face:
				continue
			var d: Vector2i = a.gu_cell - b2.gu_cell
			if absi(d.x) + absi(d.y) != 1:
				continue
			## RUN axis = perpendicular to Face.delta (swap the components).
			var fd: Vector2i = Face.delta(a.face)
			var run: Vector2i = Vector2i(absi(fd.y), absi(fd.x))
			if (d * run) == Vector2i.ZERO:
				continue   ## adjacent, but across the plane — not the same pane
			var ra: String = _find(parent, a.id)
			var rb: String = _find(parent, b2.id)
			if ra != rb:
				parent[ra] = rb
	for s in panels:
		s.pane_id = "PANE_%s" % _find(parent, s.id)

	_check_pane_size(panels)


## GLASS G-D23 — A PANE HAS A MAXIMUM SIZE, and it is derived, not invented.
##
## Director, 2026-09-01: *"convencionamos que toda vidraça vai ter um tamanho
## máximo. Que é o padrão real mesmo, nenhuma janela é infinita. Precisando,
## usa-se um frame divisório e começa outra vidraça."*
##
## The bound comes from the crack sheet, so it is not a taste call. G-D21 anchors
## the fracture sheet on the impact voxel and G-D23 CLAMPS it at the sheet edge
## (no mirror — a mirrored fracture is a second, false crack). The sheet is
## `BakedTileLookup._compute_facade_key()`'s own window, 64 columns x 32 rows, so
## a pane that fits inside it is a pane a centred hit can crack END TO END. Larger
## than that and the far half can never crack at all, silently.
##
## ⚠️ WHAT COUNTS AS A DIVIDER — measured, not assumed, and NOT what this file
## first claimed. A G-D9 `bands` entry does not split a pane: a brick-capped
## window is still BASE glass, so `_is_glass_slice()` keeps it in `panels`, and
## the union-find above joins by face and adjacency without ever reading
## `material_bands`. Caught on the real map: widening GLASS's big pane from 6 GU
## to 9 bridged the gap to the banded window at gu 19..21 and the two merged into
## ONE 12 GU pane, which is what the error reported. A real divider is a
## NON-GLASS panel at the middle GU, or a gap — either one breaks the adjacency
## the union walks.
##
## ⚠️ WHY THIS IS A CHECK AND NOT A SPLIT. Cutting an oversized run into
## conforming panes would invent geometry the author did not write — and it would
## invent it INVISIBLY, which is how a map ends up with a mullion nobody placed.
## The map is what is wrong, so the map is what gets told: `push_error` naming the
## pane, its measured size, the limit, and the fix. Behaviour then degrades
## gracefully rather than lying — G-D23's clamp means the far end simply never
## cracks, instead of growing a mirrored fracture.
##
## BLOCKS ARE EXCLUDED, and `panels` already contains only panel slices by the
## time this runs: a `PANE_BLOCK_*` has no run axis, is excluded from the cascade
## in `plan_pane_shatter()` for exactly that reason, and so has no crack sheet to
## overrun.
const MAX_PANE_RUN_GU: int = 8       ## 64 voxels — the sheet's column period
const MAX_PANE_STOREYS: int = 4      ## 32 levels — the sheet's row period


## The DECISION, split from the reporting so it can be asserted directly: a
## selftest cannot intercept `push_error`, and a rule that can only be observed
## by reading stderr is a rule nothing gates. Returns one entry per offending
## pane, `{"pane_id", "run_gu", "storeys"}`, empty when every pane conforms.
static func oversize_panes(panels: Array) -> Array:
	## Per pane: the GU span along its own run axis, and the storey span.
	var by_pane: Dictionary = {}   ## pane_id -> {"run_lo","run_hi","st_lo","st_hi","face"}
	for s in panels:
		var fd: Vector2i = Face.delta(s.face)
		var run: Vector2i = Vector2i(absi(fd.y), absi(fd.x))
		## The GU coordinate ALONG the run — the other axis is the plane and is
		## constant for every slice of one pane.
		var run_gu: int = s.gu_cell.x if run.x != 0 else s.gu_cell.y
		var st_lo: int = s.start_storey
		var st_hi: int = s.start_storey + s.storey_count - 1
		if not by_pane.has(s.pane_id):
			by_pane[s.pane_id] = {"run_lo": run_gu, "run_hi": run_gu,
				"st_lo": st_lo, "st_hi": st_hi, "face": s.face}
			continue
		var e: Dictionary = by_pane[s.pane_id]
		e["run_lo"] = mini(int(e["run_lo"]), run_gu)
		e["run_hi"] = maxi(int(e["run_hi"]), run_gu)
		e["st_lo"] = mini(int(e["st_lo"]), st_lo)
		e["st_hi"] = maxi(int(e["st_hi"]), st_hi)

	var out: Array = []
	for pane_id in by_pane:
		var e: Dictionary = by_pane[pane_id]
		var run_gu: int = int(e["run_hi"]) - int(e["run_lo"]) + 1
		var storeys: int = int(e["st_hi"]) - int(e["st_lo"]) + 1
		if run_gu <= MAX_PANE_RUN_GU and storeys <= MAX_PANE_STOREYS:
			continue
		out.append({"pane_id": pane_id, "run_gu": run_gu, "storeys": storeys})
	out.sort_custom(func(x, y): return String(x["pane_id"]) < String(y["pane_id"]))
	return out


## The reporting half. Loud, and it names the FIX — an error that only says what
## is wrong makes the author guess at what to type.
static func _check_pane_size(panels: Array) -> void:
	for bad in oversize_panes(panels):
		push_error(("[GlassPaneGrouper] G-D23: pane %s is %d GU x %d storey(s), over the "
			+ "maximum of %d x %d. A fracture sheet is %d columns x %d rows and clamps at its "
			+ "edge, so the far end of this pane can never crack. Split it with a divider: make "
			+ "the middle GU a NON-GLASS panel, or leave a gap there. ⚠️ A G-D9 `bands` entry "
			+ "does NOT split a pane — a banded window is still base-glass, so `_is_glass_slice()` "
			+ "keeps it and the union-find above (which never reads `material_bands`) joins it to "
			+ "its neighbours anyway.")
			% [bad["pane_id"], bad["run_gu"], bad["storeys"], MAX_PANE_RUN_GU, MAX_PANE_STOREYS,
				MAX_PANE_RUN_GU * GeometryCoords.VOXELS_PER_UNIT_AXIS,
				MAX_PANE_STOREYS * GeometryCoords.LEVELS_PER_STOREY])


## GLASS G-D9 — a slice is glass if its base material is glass OR any level band
## is (a mostly-brick wall with a glass strip is still a pane at that strip).
static func _is_glass_slice(slice) -> bool:
	if slice.material == "glass":
		return true
	for m in slice.material_bands.values():
		if m == "glass":
			return true
	return false


## 4-connected flood fill over a cell set → { cell: "PANE_BLOCK_n" }.
static func _flood_components(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var n: int = 0
	const NEIGHBOURS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for start in cells:
		if out.has(start):
			continue
		var id: String = "PANE_BLOCK_%d" % n
		n += 1
		var stack: Array = [start]
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if out.has(c):
				continue
			out[c] = id
			for d in NEIGHBOURS:
				var nb: Vector2i = c + d
				if cells.has(nb) and not out.has(nb):
					stack.append(nb)
	return out


## Iterative union-find root with path compression.
static func _find(parent: Dictionary, a: String) -> String:
	var x: String = a
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x
