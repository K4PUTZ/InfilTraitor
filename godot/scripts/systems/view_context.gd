## ViewContext — what the screen was showing when a number was read.
##
## TEL-03 (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). DIAG-16 (§10.16) measured one
## untouched board at 4 209 draw calls and at 49 688: the same scene and the same
## nodes, at two zooms. A frame-probe count means nothing without the view it was
## read under, so the frame probe and the telemetry timeline both take it from
## here.
##
## Pure reads, no state. The caller hands over everything it owns: the visual grid
## offset arrives as a parameter (architecture rule 2), and the cell-to-screen
## mapping arrives as Room's own inverse of `_screen_to_tile()` rather than being
## copied here.
##
## ⚠️ TWO COSTS, ON PURPOSE. `read()` is a handful of property reads and is safe
## once per probe window. `count_visible_cells()` walks every floor cell near the
## screen — thousands at the pinch minimum — so the caller caches it per view and
## recounts only when the view changed. A probe that recounted every window would
## put its own spike into the frames it reports.
class_name ViewContext
extends RefCounted
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")

## How far beyond the corners' bounding box to scan. The four screen corners map
## to cells on a diamond grid, so a cell whose centre is on screen can sit a step
## outside that box.
const SCAN_MARGIN_CELLS: int = 2


## The cheap part of the view: framing, window, canvas, camera.
static func read(viewport: Viewport, camera: Camera2D, framing: String) -> Dictionary:
	var window_size: Vector2i = DisplayServer.window_get_size()
	var root: Window = viewport.get_window()
	return {
		"framing": framing,
		"orientation": "portrait" if window_size.y >= window_size.x else "landscape",
		"window": window_size,
		"canvas": root.content_scale_size,
		"aspect": _aspect_name(root.content_scale_aspect),
		"visible": viewport.get_visible_rect().size,
		"zoom": camera.zoom.x if camera != null else 0.0,
		"centre": camera.get_screen_center_position() if camera != null else Vector2.ZERO,
	}


## A string that changes whenever the view does, at the resolution that matters:
## zoom to 0.01, the camera centre to 8 world px, the world render scale (TEL-UI-02)
## to 0.01 — the caller adds `render_scale`, which this class cannot read itself.
static func signature(fields: Dictionary) -> String:
	var centre: Vector2 = fields.get("centre", Vector2.ZERO)
	return "%s|%s|%s|%s|%.2f|%d,%d|%.2f" % [fields.get("framing", ""), fields.get("window", ""),
		fields.get("canvas", ""), fields.get("visible", ""), float(fields.get("zoom", 0.0)),
		roundi(centre.x / 8.0), roundi(centre.y / 8.0), float(fields.get("render_scale", 1.0))]


## How much board is on screen: floor cells whose centre lies inside the visible
## canvas (`gu_visible`), out of every floor cell the map has (`gu_total`). This is
## the quantity the draw calls follow (§10.16.2).
static func count_visible_cells(viewport: Viewport, floor_layer: TileMapLayer, room_size: Vector2i,
		visual_offset: Vector2, cell_to_screen: Callable, to_local: Callable) -> Dictionary:
	if floor_layer == null or not cell_to_screen.is_valid():
		return {"gu_visible": "unavailable", "gu_total": "unavailable"}
	## R3D-11: the extent is the room's and the lattice is `GroundGrid`'s; the layer is read only under the A/B flag.
	if not GroundGridRef.tiles_are_authority():
		return _count_visible_ground(viewport, room_size, visual_offset, cell_to_screen, to_local)
	var visible: Rect2 = viewport.get_visible_rect()
	var inverse: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var corners: Array[Vector2] = [visible.position,
		Vector2(visible.end.x, visible.position.y), visible.end,
		Vector2(visible.position.x, visible.end.y)]
	var scan: Rect2i = Rect2i()
	for i in range(corners.size()):
		var local: Vector2 = floor_layer.to_local(inverse * corners[i]) - visual_offset
		var cell: Vector2i = floor_layer.local_to_map(local)
		scan = Rect2i(cell, Vector2i.ZERO) if i == 0 else scan.expand(cell)
	scan = scan.grow(SCAN_MARGIN_CELLS).intersection(floor_layer.get_used_rect())
	var on_screen: int = 0
	for y in range(scan.position.y, scan.end.y):
		for x in range(scan.position.x, scan.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if floor_layer.get_cell_source_id(cell) == -1:
				continue
			var screen: Vector2 = cell_to_screen.call(cell)
			if visible.has_point(screen):
				on_screen += 1
	return {"gu_visible": on_screen, "gu_total": floor_layer.get_used_cells().size()}


static func _count_visible_ground(viewport: Viewport, room_size: Vector2i, visual_offset: Vector2,
		cell_to_screen: Callable, to_local: Callable) -> Dictionary:
	var visible: Rect2 = viewport.get_visible_rect()
	var inverse: Transform2D = viewport.get_canvas_transform().affine_inverse()
	var corners: Array[Vector2] = [visible.position,
		Vector2(visible.end.x, visible.position.y), visible.end,
		Vector2(visible.position.x, visible.end.y)]
	var scan: Rect2i = Rect2i()
	for i in range(corners.size()):
		var local: Vector2 = to_local.call(inverse * corners[i])
		var cell: Vector2i = GroundGridRef.cell_containing_with_offset(local, visual_offset)
		scan = Rect2i(cell, Vector2i.ZERO) if i == 0 else scan.expand(cell)
	scan = scan.grow(SCAN_MARGIN_CELLS).intersection(Rect2i(Vector2i.ZERO, room_size))
	var on_screen: int = 0
	for y in range(scan.position.y, scan.end.y):
		for x in range(scan.position.x, scan.end.x):
			var screen: Vector2 = cell_to_screen.call(Vector2i(x, y))
			if visible.has_point(screen):
				on_screen += 1
	return {"gu_visible": on_screen, "gu_total": room_size.x * room_size.y}


static func _aspect_name(aspect: int) -> String:
	match aspect:
		Window.CONTENT_SCALE_ASPECT_IGNORE:
			return "ignore"
		Window.CONTENT_SCALE_ASPECT_KEEP:
			return "keep"
		Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH:
			return "keep_width"
		Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT:
			return "keep_height"
		Window.CONTENT_SCALE_ASPECT_EXPAND:
			return "expand"
	return str(aspect)
