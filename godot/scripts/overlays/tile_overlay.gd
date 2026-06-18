extends Node2D
## TileOverlay — unified tile painting system using multiply blend.
##
## Used by: shadows, detection cone, exits/entrances, objectives, light (DEV).
## Each instance operates on a specific z_index — multiple instances possible.
##
## API:
##   paint(cell, color)           — paint a tile with a specific Color
##   paint_named(cell, key)       — paint a tile using a PALETTE color
##   unpaint(cell)                — remove the overlay from a tile
##   clear_priority(p)            — remove all tiles of a given priority
##   clear_all()                  — clear everything
##   shadow_color_for(mult)       — return the shadow color for a float multiplier
##
## Blend mode: MULTIPLY (CanvasItemMaterial.BLEND_MODE_MUL).
## Effect: overlay_color × tile_texture_color → preserves visual detail.
## Colors near white = almost no effect; dark colors = tile darkens;
## saturated colors = tint the tile while preserving texture.

## Default INFILTRAITOR isometric tile dimensions (TileSet: 256×128 px)
const TILE_HW := 128.0   ## half-width  — horizontal
const TILE_HH :=  64.0   ## half-height — vertical

## Render priorities — ordered from lowest (drawn first) to highest
const PRIO_SHADOW   := 1    ## Shadows — drawn below everything
const PRIO_DETECT   := 2    ## Detection cone
const PRIO_MOVEMENT := 3    ## Movement/pathfinding preview
const PRIO_NAV      := 4    ## Navigation — exits, objectives
const PRIO_DEV      := 5    ## Dev only — spawn marker, debug

## Color palette.
## IMPORTANT — shadows render with BLEND_MODE_MUL, whose blend func is
## (GL_DST_COLOR, GL_ZERO): the result is floor.rgb × color.rgb and the source
## ALPHA IS IGNORED. So shadow INTENSITY must live in the RGB value, never in
## alpha — lighter RGB = less darkening; pure white (1,1,1) = no effect.
## (Varying alpha while keeping RGB equal makes every band darken identically →
## the flat "binary" multiply look.) Mix-blend palettes below (detect/exit/etc.)
## DO honour alpha — those keep their alpha as authored.
const PALETTE: Dictionary = {
	## Shadows — cool-blue tint, intensity encoded as the RGB multiply factor.
	## Each step keeps a different fraction of floor brightness → smooth gradient,
	## floor texture reads through at every level.
	"shadow_full":   Color(0.48, 0.48, 0.58, 1.0),  ## darkest — keeps ~48% brightness
	"shadow_mid":    Color(0.60, 0.60, 0.68, 1.0),  ## keeps ~60%
	"shadow_lite":   Color(0.70, 0.70, 0.78, 1.0),  ## penumbra — keeps ~70%
	"lit":           Color(1.00, 1.00, 1.00, 0.00),  ## no overlay (skipped: alpha≈0)

	## Artistic shadow spill — soft cosmetic halo around full-shadow tiles.
	## Lighter RGB than shadow_full → a gentle gradient toward lit, not a second dark
	## band. PURELY VISUAL: detection reads the exposure grid, never this overlay —
	## so the spill softens the silhouette without offering any hiding value.
	"shadow_spill_near": Color(0.82, 0.82, 0.87, 1.0),  ## ring 1 (≤1 tile) — keeps ~82%
	"shadow_spill_far":  Color(0.92, 0.92, 0.95, 1.0),  ## ring 2 (2 tiles) — keeps ~92%

	## Detection cone — 5 probability bands
	"detect_0":      Color(0.30, 1.00, 0.30, 0.70),  ## 0.0–0.2   light green
	"detect_1":      Color(0.60, 0.95, 0.50, 0.75),  ## 0.2–0.4
	"detect_2":      Color(1.00, 0.95, 0.30, 0.75),  ## 0.4–0.6   yellow
	"detect_3":      Color(1.00, 0.60, 0.30, 0.75),  ## 0.6–0.8   orange
	"detect_4":      Color(1.00, 0.20, 0.20, 0.80),  ## 0.8–1.0   red

	## Exits and markers
	"exit":          Color(0.55, 0.10, 0.90, 0.28),  ## pure purple — segment exits
	"spawn":         Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn position
	"spawn_dev":     Color(0.20, 0.20, 0.20, 0.40),  ## dark gray — spawn in DEV_VISION

	## Objectives
	"objective":     Color(0.90, 0.75, 0.20, 0.75),  ## gold/amber — primary objective
	"secondary":     Color(0.75, 0.75, 0.75, 0.60),  ## light gray — secondary
}

## Internal state
var _entries: Dictionary = {}        ## Vector2i → {"color": Color, "prio": int}
var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_visual_offset = get_parent().position if get_parent() else Vector2.ZERO
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func setup(floor_layer: TileMapLayer, visual_offset: Vector2 = Vector2.ZERO) -> void:
	## Configures rendering references. Called by room.gd after add_child().
	_floor_layer = floor_layer
	_visual_offset = visual_offset


## ─── Public API ───────────────────────────────────────────────────────────

func paint(cell: Vector2i, color: Color, priority: int = 0) -> void:
	## Paints a tile with an explicit Color.
	_entries[cell] = {"color": color, "prio": priority}
	queue_redraw()


func paint_named(cell: Vector2i, palette_key: String, priority: int = 0) -> void:
	## Paints a tile using a PALETTE entry.
	paint(cell, PALETTE.get(palette_key, Color.WHITE), priority)


func unpaint(cell: Vector2i) -> void:
	## Removes the overlay from a specific tile.
	if _entries.erase(cell):
		queue_redraw()


func clear_priority(priority: int) -> void:
	## Removes all tiles of a specific priority.
	## Useful to clear only the detection cone without affecting shadows, for example.
	var to_erase: Array[Vector2i] = []
	for cell: Vector2i in _entries:
		if (_entries[cell] as Dictionary)["prio"] == priority:
			to_erase.append(cell)
	for cell: Vector2i in to_erase:
		_entries.erase(cell)
	if not to_erase.is_empty():
		queue_redraw()


func clear_all() -> void:
	## Removes all overlays.
	if _entries.is_empty():
		return
	_entries.clear()
	queue_redraw()


func set_cells(cells: Array[Vector2i], color: Color, priority: int = 0) -> void:
	## Shortcut: paints a whole array of tiles at once.
	## More efficient than calling paint() in a loop (queue_redraw once).
	for cell: Vector2i in cells:
		_entries[cell] = {"color": color, "prio": priority}
	if not cells.is_empty():
		queue_redraw()


func set_cells_named(cells: Array[Vector2i], palette_key: String, priority: int = 0) -> void:
	set_cells(cells, PALETTE.get(palette_key, Color.WHITE), priority)


## ─── Helpers ───────────────────────────────────────────────────────────────

static func shadow_color_for(shadow_mult: float) -> Color:
	## Returns the correct shadow color for a _shadow_tiles value.
	## shadow_mult: float from room.gd (SHADOW_MULT≈0.30, PENUMBRA≈0.55, lit=1.0)
	if shadow_mult <= 0.35:
		return PALETTE["shadow_full"]
	elif shadow_mult < 0.55:
		return PALETTE["shadow_mid"]
	elif shadow_mult < 1.0:
		return PALETTE["shadow_lite"]
	else:
		return PALETTE["lit"]


static func detect_color_for(probability: float) -> Color:
	## Returns the detection color for a probability [0.0, 1.0].
	## Mapped over 5 uniform bands of the PALETTE detect_0..detect_4.
	var idx := clampi(int(probability * 5.0), 0, 4)
	return PALETTE["detect_%d" % idx]


## ─── Drawing ───────────────────────────────────────────────────────────────

func _tile_center(cell: Vector2i) -> Vector2:
	return _floor_layer.map_to_local(cell) + Vector2(0.0, TILE_HH) + _visual_offset


func _tile_diamond(world: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		world + Vector2(0.0,      -TILE_HH),
		world + Vector2(TILE_HW,   0.0),
		world + Vector2(0.0,       TILE_HH),
		world + Vector2(-TILE_HW,  0.0),
	])


func _draw() -> void:
	if _entries.is_empty() or _floor_layer == null:
		return
	## Sort by priority (lower prio drawn first → ends up below)
	var sorted: Array = []
	for cell: Vector2i in _entries:
		sorted.append([cell, _entries[cell]])
	sorted.sort_custom(func(a, b): return a[1]["prio"] < b[1]["prio"])

	## Draw a diamond for each tile
	for item in sorted:
		var cell: Vector2i = item[0]
		var entry: Dictionary = item[1]
		var color: Color = entry["color"]

		if color.a <= 0.01:  ## skip transparent
			continue

		var world := _tile_center(cell)
		var diamond := _tile_diamond(world)
		draw_colored_polygon(diamond, color)
