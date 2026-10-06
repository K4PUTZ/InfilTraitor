## FloorPile3D — decals lying flat on the 3D board's floor (glass-shard piles, the ground/leaf
## patch, Tier 4 debris).
##
## RENDER3D R3D-6 (item 6). The 2D board draws a landed pane's piles as one `Sprite2D` per cell
## (`VoxelBoard.spawn_floor_shard_pile`); under the 3D board that renderer is hidden, so the piles —
## the white band that stays on the floor after a pane is shot out — were not drawn at all.
##
## HOW (R3D-9): a pile is DATA — a world-space centre, a level, a variant and an opacity
## (`VoxelBoard.spawn_floor_shard_pile` hands them over, from `Room._base_shards`); nothing is read
## from a sprite. One `ArrayMesh` per decal variant (three), rebuilt once per frame at most when a
## pile changes, so a whole pane's ~650 piles are three draw calls. Depth-tested: a wall in front
## hides a pile.
##
## GEOMETRY (rewritten 2026-09-28, Director: the piles read as screen-facing squares, not the
## ground's own isometric losango — glass included, not just the newer debris). The quad used to be
## built by taking a SCREEN-space square and back-projecting it onto the ground through the camera
## (`ground_affine()`), which is why it always looked axis-aligned to the screen regardless of the
## camera's angle — a leftover from when this was a `Sprite2D` and the goal was literally "keep the
## same screen footprint it had as a sprite". It is now a plain flat quad in WORLD space (X/Z, like
## every other piece of ground geometry — the same convention `Board3DLive._emit_quad()`'s top face
## and `PropMesh3D` already use), so it shears under the camera exactly like the floor tile beneath
## it. `half_gu` is a half-side in WORLD units, not screen pixels — 1.0 world unit = 1 GU (8 voxels).
##
## State stays where it always was (`Room._base_shards`, base-space); this only draws it.
class_name FloorPile3D
extends RefCounted

const SHADER_PATH := "res://godot/shaders/floor_decal3d.gdshader"
## World-space half-side matching one voxel cell's old screen footprint (16 px was half of
## VOXEL_TILE_SIZE.x, one voxel's own diamond width) — the default when a caller passes none.
const DEFAULT_HALF_GU: float = 0.5 / GeometryCoords.VOXELS_PER_UNIT_AXIS

var _board: Node3D = null
var _nodes: Array = []      ## MeshInstance3D, one per variant
var _meshes: Array = []     ## ArrayMesh, one per variant
## Any hashable id -> {"variant", "alpha", "tint", "center": Vector2 (world X/Z), "level", "rot"}.
## Cell-based callers (glass, the leaf/ground patch) use `set_pile()`'s Vector3i(cell,level) id, one
## stable identity per cell, updated in place as its count/opacity grows. A scattered placement
## (Tier 4 debris) uses `place()` directly with its own unique id per piece, a world-space centre
## that need not sit at any cell's middle, and can straddle a GU or voxel-cell boundary on purpose.
var _piles: Dictionary = {}
var _dirty: bool = false
var _lift: float = 0.004
## World-space half-side of one decal quad (1.0 = 1 GU). Defaults to one voxel cell's old footprint;
## a caller placing a different-scaled decal (a shard, a GU-sized patch) passes its own.
var _half_gu: float = -1.0
## TILE CULLING (R3D-SURFACES, 2026-10-06): the quad of a stamp is blended whole whatever its alpha, and on the Moto that cost ~5 ms per full-screen
## layer of scatter (SURFACES_MASTER_PLAN §7.0). With `cull_tiles` each variant's mesh is built from only the tiles of a TILE_GRID x TILE_GRID grid
## that hold any alpha (runs of tiles on a row are one quad), so transparent pixels are never rasterised. `_masks[variant]` is 1 where a tile is kept.
const TILE_GRID: int = 8
var _cull_tiles: bool = false
var _masks: Array = []


## The tiles of `tex` (a TILE_GRID x TILE_GRID grid, row-major) that hold any pixel of alpha above `threshold` (0..1), dilated by 2 texels so
## the linear filter never samples a culled neighbour's edge. An unreadable texture keeps every tile (nothing is culled blind).
static func tile_mask(tex: Texture2D, threshold: float = 0.03) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(TILE_GRID * TILE_GRID)
	var image: Image = tex.get_image() if tex != null else null
	if image == null or image.is_empty():
		mask.fill(1)
		return mask
	if image.is_compressed():
		image.decompress()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var tw: int = maxi(1, w / TILE_GRID)
	var th: int = maxi(1, h / TILE_GRID)
	for ty in range(TILE_GRID):
		for tx in range(TILE_GRID):
			var found: bool = false
			for y in range(maxi(0, ty * th - 2), mini(h, (ty + 1) * th + 2)):
				for x in range(maxi(0, tx * tw - 2), mini(w, (tx + 1) * tw + 2)):
					if image.get_pixel(x, y).a > threshold:
						found = true
						break
				if found:
					break
			mask[ty * TILE_GRID + tx] = 1 if found else 0
	return mask


## `tex` with a full mipmap chain: itself when it is not readable (nothing is changed blind), a new `ImageTexture` otherwise.
static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	var image: Image = tex.get_image() if tex != null else null
	if image == null or image.is_empty():
		return tex
	if image.is_compressed():
		image.decompress()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## The fraction of tiles a mask keeps (for the log: how much of a stamp's quad is still rasterised).
static func kept_fraction(mask: PackedByteArray) -> float:
	var kept: int = 0
	for b in mask:
		kept += int(b)
	return float(kept) / float(maxi(mask.size(), 1))


func attach(board: Node3D, textures: Array, priority: int, lift: float, half_gu: float = -1.0, cull_tiles: bool = false) -> void:
	if not _nodes.is_empty():
		return
	_board = board
	_lift = lift
	_half_gu = half_gu if half_gu > 0.0 else DEFAULT_HALF_GU
	_cull_tiles = cull_tiles
	var sources: Array = textures
	if cull_tiles:
		## A scatter stamp is minified hard: give it mipmaps (generated once, from the image; the plain decals keep theirs as imported).
		sources = []
		for tex: Texture2D in textures:
			sources.append(_with_mipmaps(tex))
		textures = sources
	for i in range(textures.size()):
		_masks.append(tile_mask(textures[i]) if cull_tiles else PackedByteArray())
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADER_PATH)
		mat.set_shader_parameter("decal", textures[i])
		mat.render_priority = priority
		var mesh := ArrayMesh.new()
		var node := MeshInstance3D.new()
		node.name = "FloorPile3D_%d" % i
		node.mesh = mesh
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		node.visible = false
		board.add_child(node)
		_nodes.append(node)
		_meshes.append(mesh)


func detach() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_meshes.clear()
	_masks.clear()
	_piles.clear()
	_board = null


## Convenience wrapper for a cell-centred pile (every caller before Tier 4's scattered debris): `key`
## is Vector3i(voxel cell x, voxel cell y, level), and doubles as the pile's stable identity — a
## second call with the same key UPDATES it in place (how a growing glass pile raises its own alpha
## as more shards land on one cell). `tint` defaults to white — a photographic decal (glass shard,
## the leaf/ground patch) is authored in full colour and reads unchanged. A caller whose art is
## neutral/grayscale and meant to pick up its colour from elsewhere (Director, 2026-09-28: debris
## decals are grayscale, tinted by the material that broke — unlike a ground decal, which
## complements a photographic surface and stays full colour) passes its own tint;
## `floor_decal3d.gdshader` already multiplies `texel.rgb * COLOR.rgb`, so this is the whole change.
func set_pile(key: Vector3i, variant: int, alpha: float, tint: Color = Color.WHITE) -> void:
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var center := Vector2((float(key.x) + 0.5) * unit, (float(key.y) + 0.5) * unit)
	place(key, center, key.z, variant, alpha, tint)


## General placement: `id` is any hashable value the CALLER chooses as this pile's stable identity
## (reuse it to update the same pile in place; a fresh id starts a new, independent one). `center`
## is world-space X/Z (1.0 = 1 GU) — free to land anywhere, not required to sit at a cell's middle
## or stay inside one GU (Director, 2026-09-28: scattered debris should be able to straddle a GU or
## voxel-cell edge, the same way a ground/leaf patch is meant to break up the grid rather than sit
## squarely inside it). `rot` (radians) rotates the quad in the ground plane for organic variety —
## 0.0 for every caller that does not ask for it.
func place(id, center: Vector2, level: int, variant: int, alpha: float, tint: Color = Color.WHITE, rot: float = 0.0, scale: float = 1.0) -> void:
	if _nodes.is_empty():
		return
	_piles[id] = {"variant": variant % _nodes.size(), "alpha": alpha, "tint": tint,
		"center": center, "level": level, "rot": rot, "scale": scale}
	_mark_dirty()


## Drops one placement (a ground decal whose floor broke); the id is the one `place()` was given.
func remove(id) -> void:
	if _piles.erase(id):
		_mark_dirty()


func clear() -> void:
	if _piles.is_empty():
		return
	_piles.clear()
	_mark_dirty()


func pile_count() -> int:
	return _piles.size()


func _mark_dirty() -> void:
	if _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	if _board == null or not is_instance_valid(_board):
		return
	var verts: Array = []
	var uvs: Array = []
	var cols: Array = []
	for i in range(_nodes.size()):
		verts.append(PackedVector3Array())
		uvs.append(PackedVector2Array())
		cols.append(PackedColorArray())
	var lift := Vector3.UP * _lift
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = _board.call("ground_level")
	for id in _piles:
		var p: Dictionary = _piles[id]
		var v: int = int(p["variant"])
		var rot: float = float(p.get("rot", 0.0))
		var h: float = _half_gu * float(p.get("scale", 1.0))   ## a scattered stamp varies in size (R3D-SURFACES scatter)
		## True world-space quad corners (optionally rotated) — the same flat-on-the-ground
		## convention every other piece of floor geometry uses, so this shears under the camera
		## exactly like the floor tile it sits on, instead of staying screen-square.
		var oa: Vector2 = Vector2(-h, -h).rotated(rot)
		var ob: Vector2 = Vector2(h, -h).rotated(rot)
		var od: Vector2 = Vector2(h, h).rotated(rot)
		var oe: Vector2 = Vector2(-h, h).rotated(rot)
		## A level's top sits at `(level + 1 - ground_level)` world-Y units — `PropMesh3D`'s own
		## convention, itself matching `Board3DLive._emit_quad()`'s top face.
		var y: float = float(int(p["level"]) + 1 - ground_level) * unit
		var center: Vector2 = p["center"]
		var centre := Vector3(center.x, y, center.y) + lift
		var a: Vector3 = centre + Vector3(oa.x, 0.0, oa.y)
		var b: Vector3 = centre + Vector3(ob.x, 0.0, ob.y)
		var d: Vector3 = centre + Vector3(od.x, 0.0, od.y)
		var e: Vector3 = centre + Vector3(oe.x, 0.0, oe.y)
		var tint: Color = p.get("tint", Color.WHITE)
		var col := Color(tint.r, tint.g, tint.b, float(p["alpha"]))
		if _cull_tiles and not (_masks[v] as PackedByteArray).is_empty():
			## Only the tiles that hold alpha: one quad per RUN of kept tiles on a row, its corners rotated about the centre like the whole quad's.
			var mask: PackedByteArray = _masks[v]
			var step: float = 1.0 / float(TILE_GRID)
			for ty in range(TILE_GRID):
				var tx: int = 0
				while tx < TILE_GRID:
					if mask[ty * TILE_GRID + tx] == 0:
						tx += 1
						continue
					var run_end: int = tx
					while run_end + 1 < TILE_GRID and mask[ty * TILE_GRID + run_end + 1] == 1:
						run_end += 1
					var u0: float = float(tx) * step
					var u1: float = float(run_end + 1) * step
					var v0: float = float(ty) * step
					var v1: float = float(ty + 1) * step
					var lx0: float = -h + u0 * 2.0 * h
					var lx1: float = -h + u1 * 2.0 * h
					var ly0: float = -h + v0 * 2.0 * h
					var ly1: float = -h + v1 * 2.0 * h
					var ra: Vector2 = Vector2(lx0, ly0).rotated(rot)
					var rb: Vector2 = Vector2(lx1, ly0).rotated(rot)
					var rd: Vector2 = Vector2(lx1, ly1).rotated(rot)
					var re: Vector2 = Vector2(lx0, ly1).rotated(rot)
					var ta: Vector3 = centre + Vector3(ra.x, 0.0, ra.y)
					var tb: Vector3 = centre + Vector3(rb.x, 0.0, rb.y)
					var td: Vector3 = centre + Vector3(rd.x, 0.0, rd.y)
					var te: Vector3 = centre + Vector3(re.x, 0.0, re.y)
					verts[v].append_array(PackedVector3Array([ta, tb, td, ta, td, te]))
					uvs[v].append_array(PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]))
					cols[v].append_array(PackedColorArray([col, col, col, col, col, col]))
					tx = run_end + 1
		else:
			verts[v].append_array(PackedVector3Array([a, b, d, a, d, e]))
			uvs[v].append_array(PackedVector2Array([
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]))
			cols[v].append_array(PackedColorArray([col, col, col, col, col, col]))
	for i in range(_nodes.size()):
		var mesh: ArrayMesh = _meshes[i]
		mesh.clear_surfaces()
		var pv: PackedVector3Array = verts[i]
		if pv.is_empty():
			_nodes[i].visible = false
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pv
		arrays[Mesh.ARRAY_TEX_UV] = uvs[i]
		arrays[Mesh.ARRAY_COLOR] = cols[i]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_nodes[i].visible = true
