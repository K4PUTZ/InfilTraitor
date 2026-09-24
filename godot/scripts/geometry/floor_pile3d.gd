## FloorPile3D — the glass-shard piles on the 3D board's floor.
##
## RENDER3D R3D-6 (item 6). The 2D board draws a landed pane's piles as one `Sprite2D` per cell
## (`VoxelRenderer.spawn_floor_shard_pile`); under the 3D board that renderer is hidden, so the piles —
## the white band that stays on the floor after a pane is shot out — were not drawn at all.
##
## HOW (R3D-9): a pile is DATA — a voxel cell, a level, a variant and an opacity (`VoxelRenderer.spawn_floor_shard_pile`
## hands them over, from `Room._base_shards`); nothing is read from a sprite. Its ground quad is the cell's centre
## plus the decal's screen-aligned half-side carried onto the ground by the board's own 2D → ground map (a linear
## map, so the decal keeps the very shape it had as a sprite). One `ArrayMesh` per decal variant (three), rebuilt
## once per frame at most when a pile changes, so a whole pane's ~650 piles are three draw calls. Depth-tested: a
## wall in front hides a pile.
##
## State stays where it always was (`Room._base_shards`, base-space); this only draws it.
class_name FloorPile3D
extends RefCounted

const SHADER_PATH := "res://godot/shaders/floor_decal3d.gdshader"

var _board: Node3D = null
var _nodes: Array = []      ## MeshInstance3D, one per variant
var _meshes: Array = []     ## ArrayMesh, one per variant
var _piles: Dictionary = {} ## Vector3i(cell, level) -> {"variant", "alpha"}
var _dirty: bool = false
var _lift: float = 0.004


func attach(board: Node3D, textures: Array, priority: int, lift: float) -> void:
	if not _nodes.is_empty():
		return
	_board = board
	_lift = lift
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


## `key` is Vector3i(voxel cell x, voxel cell y, level).
func set_pile(key: Vector3i, variant: int, alpha: float) -> void:
	if _nodes.is_empty():
		return
	_piles[key] = {"variant": variant % _nodes.size(), "alpha": alpha}
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
	var to_gu: Transform2D = _board.call("ground_affine")
	var h: float = VoxelRenderer.floor_shard_half_px()
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	## The decal's screen-aligned corners, as ground offsets (the map is linear, so one set serves every pile).
	var oa: Vector2 = to_gu.basis_xform(Vector2(-h, -h))
	var ob: Vector2 = to_gu.basis_xform(Vector2(h, -h))
	var od: Vector2 = to_gu.basis_xform(Vector2(h, h))
	var oe: Vector2 = to_gu.basis_xform(Vector2(-h, h))
	var ground_level: int = _board.call("ground_level")
	for key in _piles:
		var p: Dictionary = _piles[key]
		var v: int = int(p["variant"])
		## A pile on a level below the playable ground sits `VOXEL_STEP_PX` lower on screen per level, and the 2D
		## sprite carried that in its position; on the ground plane it is the same step through the same map.
		var drop: Vector2 = to_gu.basis_xform(Vector2(0.0, GeometryCoords.VOXEL_STEP_PX * float(ground_level - key.z)))
		var centre := Vector3((float(key.x) + 0.5) * unit + drop.x, 0.0, (float(key.y) + 0.5) * unit + drop.y) + lift
		var a: Vector3 = centre + Vector3(oa.x, 0.0, oa.y)
		var b: Vector3 = centre + Vector3(ob.x, 0.0, ob.y)
		var d: Vector3 = centre + Vector3(od.x, 0.0, od.y)
		var e: Vector3 = centre + Vector3(oe.x, 0.0, oe.y)
		var col := Color(1.0, 1.0, 1.0, float(p["alpha"]))
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
