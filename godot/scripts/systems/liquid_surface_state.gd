## LiquidSurfaceState — the SOLID part of a body's surface, per plane cell (M6 F5, Director 2026-10-18): the cooled plates of a lava crust and the
## ice a cryogenic liquid leaves on the water it touches.
##
## - PLATES (`gameplay.plates` {walkable, break_after_turns}): every wet cell starts as an intact plate. A plate is ground: walkable, no dose, no
##   wading. The first step on it starts its count; `break_after_turns` liquid turns later it BREAKS for good and the cell is the liquid below
##   (lethal, blocked). The count runs whether or not the agent is still on it.
## - ICE (a liquid that `extinguishes`, i.e. water): a cell a cryogenic body touches freezes (`freeze`), for good: walkable, no dose, slippery.
##
## Pure over a `FluidPlane`'s grid (the rim included, never solid). The rules read it through `LiquidField`; the sheet draws it (vertex G = plate,
## vertex B = ice), bumping on `version`.
class_name LiquidSurfaceState
extends RefCounted

const NO_DEPTH: float = 0.05
const PLATE: int = 1
const ICE: int = 2

var plane: RefCounted = null
var plates: bool = false            ## the body is a crust: its cells start as plates
var freezable: bool = false         ## the body is water: a cryogenic body freezes it
var break_after: int = 3
var solid: PackedByteArray = PackedByteArray()   ## per plane cell: 0 liquid, PLATE, ICE
var age: PackedInt32Array = PackedInt32Array()   ## per plane cell: liquid turns since the first step on a plate (-1 = never stepped on)
var version: int = 0


func setup(fluid_plane: RefCounted, gameplay: Dictionary) -> void:
	plane = fluid_plane
	var spec: Variant = gameplay.get("plates", null)
	plates = spec is Dictionary and bool((spec as Dictionary).get("walkable", false))
	if plates:
		break_after = maxi(int((spec as Dictionary).get("break_after_turns", 3)), 1)
	freezable = bool(gameplay.get("extinguishes", false))
	var n: int = plane.cols * plane.rows
	solid.resize(n)
	solid.fill(0)
	age.resize(n)
	age.fill(-1)
	if plates:
		for r in range(1, plane.rows - 1):
			for c in range(1, plane.cols - 1):
				solid[plane.index(c, r)] = PLATE


func is_active() -> bool:
	return plates or freezable


## The solid state of the GU cell `cell` as a step meets it: PLATE only while no wet plate cell inside it has broken; ICE when at least half of its wet
## cells are frozen; else 0 (the liquid).
func at_gu(cell: Vector2i) -> int:
	var wet: int = 0
	var frozen: int = 0
	var broken: bool = false
	var plated: int = 0
	for i: int in plane.cells_in(Rect2(Vector2(cell), Vector2.ONE)):
		if plane.committed[i] <= NO_DEPTH:
			continue
		wet += 1
		if solid[i] == ICE:
			frozen += 1
		elif solid[i] == PLATE:
			plated += 1
		elif plates:
			broken = true
	if wet == 0:
		return 0
	if plates:
		return 0 if broken or plated == 0 else PLATE
	return ICE if frozen * 2 >= wet else 0


## The agent stepped onto the GU cell `cell`: every intact plate inside starts its count.
func step_on(cell: Vector2i) -> void:
	if not plates:
		return
	for i: int in plane.cells_in(Rect2(Vector2(cell), Vector2.ONE)):
		if solid[i] == PLATE and age[i] < 0:
			age[i] = 0


## One liquid turn: the plates stepped on age, and those that reached `break_after` break. Returns the cells that broke.
func tick_turn() -> PackedInt32Array:
	var broke := PackedInt32Array()
	if not plates:
		return broke
	for i in range(age.size()):
		if age[i] < 0 or solid[i] != PLATE:
			continue
		age[i] += 1
		if age[i] >= break_after:
			solid[i] = 0
			broke.append(i)
	if not broke.is_empty():
		version += 1
	return broke


## Freezes the plane cells `cells` (wet ones only). Returns how many froze now.
func freeze(cells: PackedInt32Array) -> int:
	if not freezable:
		return 0
	var froze: int = 0
	for i: int in cells:
		if solid[i] == 0 and plane.committed[i] > NO_DEPTH:
			solid[i] = ICE
			froze += 1
	if froze > 0:
		version += 1
	return froze


## The cells of `dst` (wet, interior) that touch a wet interior cell of `src` (a shared side: the centres one half-cell-sum apart). Two bodies in
## one pit, side by side, touch along their common edge.
static func contact_cells(src: RefCounted, dst: RefCounted) -> PackedInt32Array:
	var out := PackedInt32Array()
	var reach: float = 0.5 * (float(src.cell_gu) + float(dst.cell_gu)) + 0.01
	var src_wet: Array[Vector2] = []
	for r in range(1, src.rows - 1):
		for c in range(1, src.cols - 1):
			if src.committed[src.index(c, r)] > NO_DEPTH:
				src_wet.append(src.origin + (Vector2(c, r) + Vector2(0.5, 0.5)) * float(src.cell_gu))
	if src_wet.is_empty():
		return out
	for r in range(1, dst.rows - 1):
		for c in range(1, dst.cols - 1):
			var i: int = dst.index(c, r)
			if dst.committed[i] <= NO_DEPTH:
				continue
			var centre: Vector2 = dst.origin + (Vector2(c, r) + Vector2(0.5, 0.5)) * float(dst.cell_gu)
			for p: Vector2 in src_wet:
				if centre.distance_to(p) <= reach:
					out.append(i)
					break
	return out
