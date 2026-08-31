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
