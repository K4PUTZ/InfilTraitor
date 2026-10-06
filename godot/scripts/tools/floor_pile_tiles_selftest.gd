## R3D-SURFACES tile culling — `FloorPile3D.tile_mask` keeps exactly the tiles that hold alpha, and a pile built with `cull_tiles` rasterises only
## those: a stamp opaque in one corner becomes one small quad, an empty one nothing, a full one the same quad as before; the mipmap chain is built.
extends SceneTree

const FloorPileClass = preload("res://godot/scripts/geometry/floor_pile3d.gd")


class StubBoard extends Node3D:
	func ground_level() -> int:
		return GeometryCoords.PLAYABLE_LEVEL


var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _texture(fill: Rect2i, size: int = 256) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(fill, Color(1, 0, 0, 1))
	return ImageTexture.create_from_image(image)


func _vertex_count(pile) -> int:
	pile._rebuild()
	var mesh: ArrayMesh = pile._meshes[0]
	if mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _init() -> void:
	print("\n== FLOOR PILE TILES SELFTEST ==\n")
	var corner: PackedByteArray = FloorPileClass.tile_mask(_texture(Rect2i(0, 0, 60, 60)))
	var kept_corner: int = 0
	for b in corner:
		kept_corner += int(b)
	_check(corner[0] == 1 and kept_corner <= 4 and kept_corner >= 1, "an image opaque in its top-left corner keeps that tile (and at most its dilation): %d of 64" % kept_corner)
	_check(corner[63] == 0 and corner[7] == 0 and corner[56] == 0, "the other corners are culled")
	var empty: PackedByteArray = FloorPileClass.tile_mask(_texture(Rect2i(0, 0, 0, 0)))
	_check(FloorPileClass.kept_fraction(empty) == 0.0, "a fully transparent image keeps no tile")
	var full: PackedByteArray = FloorPileClass.tile_mask(_texture(Rect2i(0, 0, 256, 256)))
	_check(FloorPileClass.kept_fraction(full) == 1.0, "a fully opaque image keeps every tile")
	var middle: PackedByteArray = FloorPileClass.tile_mask(_texture(Rect2i(96, 96, 64, 64)))
	## A 64 px patch on the tile grid (32 px tiles) is 2 x 2 tiles; the 2 texel dilation keeps the ring around them too: 4 x 4 = 16 of 64.
	_check(middle[3 * 8 + 3] == 1 and middle[0] == 0 and middle[63] == 0 and is_equal_approx(FloorPileClass.kept_fraction(middle), 16.0 / 64.0),
		"a centred, tile-aligned patch keeps its 2 x 2 tiles and the dilation ring, nothing else (%.0f%%)" % (FloorPileClass.kept_fraction(middle) * 100.0))

	var board := StubBoard.new()
	root.add_child(board)
	var plain = FloorPileClass.new()
	plain.attach(board, [_texture(Rect2i(0, 0, 60, 60))], 3, 0.02, 1.0, false)
	plain.place(1, Vector2(5, 5), GeometryCoords.FLOOR_TOP_LEVEL, 0, 1.0, Color.WHITE, 0.4, 1.0)
	_check(_vertex_count(plain) == 6, "without culling a pile is the 6 vertices of one quad")
	var culled = FloorPileClass.new()
	culled.attach(board, [_texture(Rect2i(0, 0, 60, 60))], 3, 0.02, 1.0, true)
	culled.place(1, Vector2(5, 5), GeometryCoords.FLOOR_TOP_LEVEL, 0, 1.0, Color.WHITE, 0.4, 1.0)
	var culled_verts: int = _vertex_count(culled)
	_check(culled_verts >= 6 and culled_verts <= 24, "a corner stamp built with culling is a few small quads (%d vertices)" % culled_verts)
	var none = FloorPileClass.new()
	none.attach(board, [_texture(Rect2i(0, 0, 0, 0))], 3, 0.02, 1.0, true)
	none.place(1, Vector2(5, 5), GeometryCoords.FLOOR_TOP_LEVEL, 0, 1.0, Color.WHITE, 0.0, 1.0)
	_check(_vertex_count(none) == 0, "an empty stamp builds nothing")
	var all_tiles = FloorPileClass.new()
	all_tiles.attach(board, [_texture(Rect2i(0, 0, 256, 256))], 3, 0.02, 1.0, true)
	all_tiles.place(1, Vector2(5, 5), GeometryCoords.FLOOR_TOP_LEVEL, 0, 1.0, Color.WHITE, 0.0, 1.0)
	_check(_vertex_count(all_tiles) == 8 * 6, "a full stamp is 8 row runs (48 vertices), the same area as the whole quad")
	var tex_with_mips: Texture2D = FloorPileClass._with_mipmaps(_texture(Rect2i(0, 0, 256, 256)))
	_check(tex_with_mips.get_image().has_mipmaps(), "a culled pile's texture has a mipmap chain")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
