## FloorPile3D — the glass-shard piles on the 3D board's floor.
##
## RENDER3D R3D-6 (item 6). The 2D board draws a landed pane's piles as one `Sprite2D` per cell
## (`VoxelRenderer.spawn_floor_shard_pile`); under the 3D board that renderer is hidden, so the piles —
## the white band that stays on the floor after a pane is shot out — were not drawn at all.
##
## HOW: the sprite's four screen corners are carried onto the ground plane by the board's own 2D → ground
## map (`ground_point`), which is affine, so the decal re-projects to the very pixels the sprite covered.
## One `ArrayMesh` per decal variant (three), rebuilt once per frame at most when a pile changes, so a
## whole pane's ~650 piles are three draw calls. Depth-tested: a wall in front hides a pile.
##
## State stays where it always was (`Room._base_shards`, base-space); this only draws it.
class_name FloorPile3D
extends RefCounted

const SHADER_PATH := "res://godot/shaders/floor_decal3d.gdshader"

var _board: Node3D = null
var _nodes: Array = []      ## MeshInstance3D, one per variant
var _meshes: Array = []     ## ArrayMesh, one per variant
var _piles: Dictionary = {} ## Vector3i(cell, level) -> {"variant", "pos", "half", "alpha"}
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


## `pos_2d` is the sprite's centre and `size_px` its side, exactly as the 2D sprite has them.
func set_pile(key: Vector3i, variant: int, pos_2d: Vector2, size_px: float, alpha: float) -> void:
	if _nodes.is_empty():
		return
	_piles[key] = {"variant": variant % _nodes.size(), "pos": pos_2d, "half": size_px * 0.5, "alpha": alpha}
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
	for key in _piles:
		var p: Dictionary = _piles[key]
		var v: int = int(p["variant"])
		var c: Vector2 = p["pos"]
		var h: float = float(p["half"])
		var a: Vector3 = _board.call("ground_point", c + Vector2(-h, -h)) + lift
		var b: Vector3 = _board.call("ground_point", c + Vector2(h, -h)) + lift
		var d: Vector3 = _board.call("ground_point", c + Vector2(h, h)) + lift
		var e: Vector3 = _board.call("ground_point", c + Vector2(-h, h)) + lift
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
