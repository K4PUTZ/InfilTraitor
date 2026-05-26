extends Node2D
## Draws (x,y) coordinate labels at the visual centre of every tile.
## Visibility is toggled by the HUD button via node.visible.

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var room_w: int = 0
var room_h: int = 0

const FONT_SIZE    := 14
const COLOR_LABEL  := Color(1.0, 1.0, 1.0, 0.85)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.60)


func _draw() -> void:
	if floor_layer == null:
		return

	var font := ThemeDB.fallback_font

	for x in range(room_w):
		for y in range(room_h):
			var cell   := Vector2i(x, y)
			## map_to_local → TOP vertex; +Vector2(0,64) → visual centre.
			var center := floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + visual_offset
			var label  := "%d,%d" % [x, y]
			var sw     := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var origin := center + Vector2(-sw * 0.5, FONT_SIZE * 0.35)

			## Shadow first, then white label on top.
			draw_string(font, origin + Vector2(1, 1), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_SHADOW)
			draw_string(font, origin, label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_LABEL)
