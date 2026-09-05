## GLASS G4-1 — photograph the shard shape family, from the SHIPPED data.
## Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##            --script godot/scripts/tools/glass_shard_shapes_capture.gd
##
## ⚠️ IT RASTERISES `GlassShardShapes` ITSELF, never a copy of the numbers. A
## preview drawn from a transcription would be a picture of a second family that
## happens to look similar, and the whole point of a true-size check is that it is
## the thing that ships.
##
## Three bands, because they answer different questions:
##   1. the five free members, magnified — what each shape IS
##   2. every member x every anchor placement (G-D39) — how it hangs
##   3. TRUE SIZE — the only band that decides anything. A voxel's face is 20 px
##      tall (`GeometryCoords.VOXEL_STEP_PX`), so a shard at G-D44's band is 10 to
##      20 px, and detail that reads beautifully in band 1 dissolves here.

extends SceneTree

const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")

const OUT_PATH: String = "res://Screenshots/history/glass_shard_family_2026-09-05.png"

const BG := Color(0.086, 0.094, 0.110)
const CELL := Color(0.172, 0.184, 0.207)
const CELL_EDGE := Color(0.255, 0.274, 0.309)
const GLASS := Color(0.769, 0.910, 0.957)
const BRICK := Color(0.659, 0.361, 0.290)
const LABEL := Color(0.55, 0.58, 0.63)

const STUDY_PX: int = 120     ## px per voxel in bands 1-2
const TRUE_PX: int = 20       ## px per voxel in band 3 — VOXEL_STEP_PX, the real one


func _init() -> void:
	print("\n[G4-1] shard family capture — %d member(s)" % ShardShapes.ids().size())
	var ids: Array = ShardShapes.ids()
	var anchors: Array = [ShardShapes.ANCHOR_RUN_NEG, ShardShapes.ANCHOR_LEVEL_NEG,
		ShardShapes.ANCHOR_RUN_POS, ShardShapes.ANCHOR_LEVEL_POS,
		ShardShapes.ANCHOR_RUN_NEG | ShardShapes.ANCHOR_LEVEL_NEG]
	var anchor_names: Array = ["run-", "level-", "run+", "level+", "corner"]

	var pad: int = 14
	var band1_h: int = STUDY_PX + pad * 2
	var band2_h: int = anchors.size() * (STUDY_PX + pad) + pad
	var band3_h: int = TRUE_PX * 4 + pad * 3
	var w: int = pad + ids.size() * (STUDY_PX + pad)
	var h: int = band1_h + band2_h + band3_h + pad

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)

	## ── band 1: the free members, magnified ────────────────────────────────
	var y: int = pad
	for i in range(ids.size()):
		var x: int = pad + i * (STUDY_PX + pad)
		_cell_ground(img, x, y, STUDY_PX)
		_stamp(img, ShardShapes.polygon_sized(String(ids[i]), 1.0), x, y, STUDY_PX, GLASS)
	y += band1_h

	## ── band 2: every anchor placement ─────────────────────────────────────
	for a in range(anchors.size()):
		var mask: int = int(anchors[a])
		for i in range(ids.size()):
			var x: int = pad + i * (STUDY_PX + pad)
			_cell_ground(img, x, y, STUDY_PX)
			_frame_edges(img, x, y, STUDY_PX, mask)
			## The flop alternates down the column, so both placements of every
			## member are in the sheet rather than only the unflipped one.
			_stamp(img, ShardShapes.anchored_polygon(String(ids[i]), mask, a % 2 == 1),
				x, y, STUDY_PX, GLASS)
		print("  band 2 row %-7s  mask=%d" % [anchor_names[a], mask])
		y += STUDY_PX + pad
	y += pad

	## ── band 3: TRUE SIZE ──────────────────────────────────────────────────
	## Two rows of free members at both ends of G-D44's band, then two rows of
	## anchored ones. This is the row that decides whether the family works.
	var tx: int = pad
	for target in [ShardShapes.TARGET_MAX, ShardShapes.TARGET_MIN]:
		tx = pad
		for i in range(ids.size()):
			for rep in range(3):
				_cell_ground(img, tx, y, TRUE_PX)
				_stamp(img, ShardShapes.polygon_sized(String(ids[i]), float(target)),
					tx, y, TRUE_PX, GLASS)
				tx += TRUE_PX + 2
			tx += 6
		y += TRUE_PX + pad
	for mask in [ShardShapes.ANCHOR_RUN_NEG, ShardShapes.ANCHOR_LEVEL_NEG]:
		tx = pad
		for i in range(ids.size()):
			for rep in range(3):
				_cell_ground(img, tx, y, TRUE_PX)
				_frame_edges(img, tx, y, TRUE_PX, mask)
				_stamp(img, ShardShapes.anchored_polygon(String(ids[i]), mask, rep % 2 == 1),
					tx, y, TRUE_PX, GLASS)
				tx += TRUE_PX + 2
			tx += 6
		y += TRUE_PX + pad

	var err: int = img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("[G4-1] could not write %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("  wrote %s  (%dx%d, true size = %d px/voxel = VOXEL_STEP_PX %d)"
		% [OUT_PATH, w, h, TRUE_PX, GeometryCoordsMod.VOXEL_STEP_PX])
	quit(0)


## One cell's ground: the square the fragment lives in, so its size is readable
## against something.
func _cell_ground(img: Image, x: int, y: int, px: int) -> void:
	for j in range(px):
		for i in range(px):
			var edge: bool = i == 0 or j == 0 or i == px - 1 or j == px - 1
			img.set_pixel(x + i, y + j, CELL_EDGE if edge else CELL)


## The material the fragment hangs from, one strip per anchored edge.
func _frame_edges(img: Image, x: int, y: int, px: int, mask: int) -> void:
	var t: int = maxi(2, px / 12)
	for dv in ShardShapes.anchor_dirs(mask):
		var d: Vector2 = dv
		for j in range(px):
			for i in range(px):
				## `+y` is level+ and the image's `+j` is DOWN, so the level axis
				## is flipped here and nowhere else.
				var on: bool = (d.x > 0.5 and i >= px - t) or (d.x < -0.5 and i < t) \
					or (d.y > 0.5 and j < t) or (d.y < -0.5 and j >= px - t)
				if on:
					img.set_pixel(x + i, y + j, BRICK)


## Rasterise one polygon into the cell at (x, y). Point-in-polygon per pixel —
## the same test the atom cut will run, so what is drawn here is what will be cut.
func _stamp(img: Image, poly: PackedVector2Array, x: int, y: int, px: int, col: Color) -> void:
	if poly.size() < 3:
		return
	for j in range(px):
		for i in range(px):
			var p := Vector2(
				(float(i) + 0.5) / float(px) - 0.5,
				0.5 - (float(j) + 0.5) / float(px))
			if ShardShapes.contains(poly, p):
				img.set_pixel(x + i, y + j, col)
