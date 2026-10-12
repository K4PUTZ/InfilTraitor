## ROOF RF-1 step 3b (ROOF_MASTER_PLAN, 2026-10-11) — a glass pane's own frame: two in-plane axes (u, v) and the coordinate the
## plane is fixed at. The glass machinery was written for a VERTICAL pane, in (run, level) with the cross axis fixed; a SKYLIGHT is a
## HORIZONTAL pane, in (x, y) at one level. Every consumer that turns a cell into pane coordinates asks here, so a vertical pane and a
## skylight share one code path instead of the skylight getting a copy of it.
##
## `face` is the pane's face as the store and the hosts carry it: a `Face` (NW 0, NE 1, SE 2, SW 3) for a vertical pane, or
## `HORIZONTAL` (4 = `VoxelStore.PANE_HORIZONTAL - 1`) for a skylight. A vertical pane on NE / SW runs along X (its normal is Y), one on
## NW / SE along Y (`GlassPaneGrouper`'s `Vector2i(absi(fd.y), absi(fd.x))`).
class_name PaneFrame

const HORIZONTAL: int = 4


static func is_horizontal(face: int) -> bool:
	return face == HORIZONTAL


## A vertical pane's run is along X (NE / SW). Meaningless for a skylight (its u IS x): callers branch on `is_horizontal` first.
static func run_is_x(face: int) -> bool:
	return face == Face.NE or face == Face.SW


## The cell (x, y, level) in the pane's (u, v): vertical (run, level), horizontal (x, y).
static func to_uv(face: int, cell: Vector3i) -> Vector2i:
	if face == HORIZONTAL:
		return Vector2i(cell.x, cell.y)
	return Vector2i(cell.x if run_is_x(face) else cell.y, cell.z)


## The coordinate the plane is fixed at: vertical the cross axis (y for a run along X, else x), horizontal the level.
static func fixed_of(face: int, cell: Vector3i) -> int:
	if face == HORIZONTAL:
		return cell.z
	return cell.y if run_is_x(face) else cell.x


## `to_uv()`'s inverse.
static func to_cell(face: int, uv: Vector2i, fixed: int) -> Vector3i:
	if face == HORIZONTAL:
		return Vector3i(uv.x, uv.y, fixed)
	if run_is_x(face):
		return Vector3i(uv.x, fixed, uv.y)
	return Vector3i(fixed, uv.x, uv.y)


## The store's cell-index steps (`VoxelStore.cell_index`: x 1, y w, level plane) along u and v, and along the normal.
static func u_step(face: int, store: VoxelStore) -> int:
	if face == HORIZONTAL:
		return 1
	return 1 if run_is_x(face) else store.w


static func v_step(face: int, store: VoxelStore) -> int:
	if face == HORIZONTAL:
		return store.w
	return store.plane


static func normal_step(face: int, store: VoxelStore) -> int:
	if face == HORIZONTAL:
		return store.plane
	return store.w if run_is_x(face) else 1
