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


func attach(board: Node3D, textures: Array, priority: int, lift: float, half_gu: float = -1.0) -> void:
	if not _nodes.is_empty():
		return
	_board = board
	_lift = lift
	_half_gu = half_gu if half_gu > 0.0 else DEFAULT_HALF_GU
	for i in range(textures.size()):
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
func place(id, center: Vector2, level: int, variant: int, alpha: float, tint: Color = Color.WHITE, rot: float = 0.0) -> void:
	if _nodes.is_empty():
		return
	_piles[id] = {"variant": variant % _nodes.size(), "alpha": alpha, "tint": tint,
		"center": center, "level": level, "rot": rot}
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
	var h: float = _half_gu
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = _board.call("ground_level")
	for id in _piles:
		var p: Dictionary = _piles[id]
		var v: int = int(p["variant"])
		var rot: float = float(p.get("rot", 0.0))
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
