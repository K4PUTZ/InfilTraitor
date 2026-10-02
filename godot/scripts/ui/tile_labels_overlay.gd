extends Node2D
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer
## Draws (x,y) coordinate labels at the visual centre of every tile.
## Visibility is toggled by the HUD button via node.visible.

var visual_offset: Vector2 = Vector2.ZERO
var room_w: int = 0
var room_h: int = 0

const FONT_SIZE := 40
const COLOR_LABEL := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_SHADOW := Color(1.0, 1.0, 1.0, 0.60)



## RENDER3D R3D-5b, the dev overlays (2026-10-02): when a 3D board is set this overlay's drawing goes to a `GroundCanvas3D`
## (the same calls, on the ground plane, depth-tested) instead of the 2D canvas, so under a camera yaw it stays on its cells.
const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
var _ground: RefCounted = null
var _c: Object = self  ## where the draw calls go: this node, or `_ground` while a 3D board is set


func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board == null:
		queue_redraw()
		return
	_ground = GroundCanvas3DRef.new()
	_ground.attach(board, 15, 0.032, false)
	_ground.follow_visibility_of(self)
	queue_redraw()


func _draw() -> void:
	if _ground == null:
		_c = self
		_draw_into()
		return
	_c = _ground
	_ground.begin(self)
	_draw_into()
	_ground.end()
	_c = self


func _draw_into() -> void:

	var font := ThemeDB.fallback_font

	for x in range(room_w):
		for y in range(room_h):
			var cell := Vector2i(x, y)
			## map_to_local → TOP vertex; +Vector2(0,64) → visual centre.
			var center := GroundGridRef.map_to_local(cell) + Vector2(0.0, 64.0) + visual_offset
			var label := "%d,%d" % [x, y]
			var sw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var origin := center + Vector2(-sw * 0.5, FONT_SIZE * 0.35)

			## Shadow first, then white label on top.
			_c.draw_string(font, origin + Vector2(1, 1), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_SHADOW)
			_c.draw_string(font, origin, label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_LABEL)