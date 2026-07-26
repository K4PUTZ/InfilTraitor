## ThemeApplier — Apply theme color tints to wall layers
##
## Themes (map-specific color tints) are applied at render time via modulate,
## not baked into the atlas. This buys flexibility: atlas is reusable across themes,
## and switching themes is instant (single modulate call).

class_name ThemeApplier

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

var _wall_tilemaps = []


## Initialize with wall tilemaps to apply theme to
func _init(wall_tilemaps = []) -> void:
	if wall_tilemaps is Array:
		_wall_tilemaps = wall_tilemaps
	else:
		_wall_tilemaps = []


## Apply a theme color to all wall-rendering layers
func apply(theme_color: Color) -> void:
	if _wall_tilemaps.is_empty():
		# Try to fetch from global WALL_TILEMAPS
		if Engine.has_meta("WALL_TILEMAPS"):
			var global_tilemaps = Engine.get_meta("WALL_TILEMAPS")
			if global_tilemaps is Array:
				_wall_tilemaps = global_tilemaps

	if _wall_tilemaps.is_empty():
		push_error("[THEME] No wall tilemaps initialized for theme application")
		return

	for tilemap in _wall_tilemaps:
		if is_instance_valid(tilemap):
			tilemap.modulate = theme_color

	# Log for evidence (RGB only; HSV not available in Godot 4.6)
	print("[THEME] Applied: RGB(%.2f, %.2f, %.2f)" % [
		theme_color.r, theme_color.g, theme_color.b
	])


## Reset to neutral (white = identity multiply)
func clear() -> void:
	apply(Color.WHITE)
