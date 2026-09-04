## GLASS CRACK-03 — RENDER THE HOLE'S SILHOUETTE FROM THE REAL ATOMS.
##
## Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##            --script godot/scripts/tools/glass_rim_capture.gd
##
## ⚠️ WHY THIS EXISTS AS A COMMITTED TOOL AND NOT A SCRATCH SCRIPT.
## `glass_rim_shape_options_2026-09-02.png` — the picture G-D32 was ratified from
## — was made by an ad-hoc script that was never committed and no longer exists.
## It was captured at 04:11 on 2026-09-03, **four minutes before `330d285d` cut
## the neighbour count from 8 to 4**, so the silhouette it shows is one the build
## has not made since. A shape decision needs a picture of the CURRENT build, and
## a picture that cannot be re-made is a citation that decays (the same lesson the
## `auto_*.png` rotation already taught this project).
##
## ⚠️ IT COMPOSITES ATOMS, IT DOES NOT BOOT THE GAME. That is the point: the
## question is what SILHOUETTE the rim atoms cut, and a play-zoom screenshot of a
## real pane cannot answer it (the difference between 4 and 8 neighbours on a
## one-voxel hole is a handful of pixels there — it took a diagram to catch).
## Compositing runs headless, deterministically, in under a second.
##
## The geometry is the atom's own, not a re-derivation: a SW face's diamond edge
## runs `vw -> vs`, so the RUN step in canvas is (16, 8), and a level is
## `VOXEL_STEP_PX` straight up. Those two vectors ARE the pane's basis — the same
## one `GlassCrackSprite` bakes into its Transform2D.
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

## The pane to build, in cells. Big enough that the hole sits well inside it, so
## no edge case of the rim walk is silently doing the work.
const RUNS: int = 11
const LEVELS: int = 7
const OUT_DIR := "res://Screenshots/history"

## Background and the flat colour every surviving atom is painted, so the picture
## reads as SILHOUETTE rather than as shading. The atoms carry a per-plane dim in
## RED and a tint in BLUE; keeping either would make the eye read lighting when
## the question is shape.
const BG := Color(0.16, 0.17, 0.22, 1.0)
const GLASS_FLAT := Color(1.0, 0.93, 0.20, 1.0)


## The per-shard dial sets for the RIGHT panel. ⚠️ THIS PANEL IS A MOCK, NOT THE
## BUILD: it hands each of the four shards a different (TIP_HALF, DEPTH) to show
## what G-D32's hashed pool does to the SILHOUETTE. The real S-6 is unbuilt, and
## only two of the four ratified shapes (spike-deep, spike-shallow) are
## expressible with today's dials at all — the V-notch and the 45° chamfer are
## not, so this understates the variety rather than inventing it.
const MOCK_DIALS: Array[Vector2] = [
	Vector2(0.05, 1.00), Vector2(0.22, 0.55), Vector2(0.05, 0.70), Vector2(0.14, 0.90),
]


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS CRACK-03 — the hole silhouette, composited from the real atoms")
	print("=".repeat(70) + "\n")

	print("LEFT — the real path: refresh_glass_rims() on a real pierced pane")
	var built := _render_hole(false)
	print("RIGHT — a MOCK of G-D32: the same hole, one dial set per shard")
	var mocked := _render_hole(true)
	if built == null or mocked == null:
		push_error("[glass_rim_capture] the composite failed — no image produced")
		quit(1)
		return

	var img := _side_by_side(built, mocked)
	var stamp: String = Time.get_date_string_from_system()
	var path: String = "%s/glass_rim_hole_4neighbours_%s.png" % [OUT_DIR, stamp]
	var err: int = img.save_png(path)
	if err != OK:
		push_error("[glass_rim_capture] save_png failed (%d) for %s" % [err, path])
		quit(1)
		return
	print("wrote %s  (%d x %d)" % [path, img.get_width(), img.get_height()])
	print("")
	quit(0)


## The two panels on one sheet, with a divider — one file, one look, no flipping
## between windows to compare two silhouettes that differ by a few pixels.
func _side_by_side(a: Image, b: Image) -> Image:
	var gap: int = 8
	var w: int = a.get_width() + gap + b.get_width()
	var h: int = maxi(a.get_height(), b.get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.08, 0.10, 1.0))
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + gap, 0))
	return out


## Build a real pane of real atoms, punch one voxel, run the REAL
## `refresh_glass_rims()`, then composite whatever the tilemap ended up holding.
func _render_hole(mock_pool: bool) -> Image:
	var r = VoxelRendererClass.new()
	var base: int = GeometryCoordsClass.storey_level_base(0)
	var cross: int = 7
	var run0: int = 0
	var ts := TileSet.new()
	ts.tile_size = Vector2i(GeometryCoordsClass.VOXEL_ATOM_W, GeometryCoordsClass.VOXEL_ATOM_H)
	## `_glass_rim_atom_source()` stamps `tile_name` on every shard it registers.
	## Without the custom-data layer the engine prints an error per shard and the
	## capture still "works" — the kind of noise that trains an eye to skip a log.
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "tile_name")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	## The intact pane atom, source 0 — the same one `_ensure_glass_sublayers()`
	## registers, built through the renderer's own builder so this cannot drift
	## from what the game places.
	var intact: Image = r._build_glass_pane_atom(Face.SW, false, false, 0)
	if intact == null:
		r.free()
		return null
	var src0 := TileSetAtlasSource.new()
	src0.texture = ImageTexture.create_from_image(intact)
	src0.texture_region_size = Vector2i(intact.get_width(), intact.get_height())
	src0.create_tile(Vector2i.ZERO)
	ts.add_source(src0, 0)

	## ⚠️ The renderer's own TileSet MUST be the layers' TileSet, or a `set_cell()`
	## naming a rim source the LAYER does not have is silently ignored and the
	## swap looks like it worked. Selftest [15] found this on its first run.
	r._tileset = ts
	for lvl in range(base, base + LEVELS):
		var layer := TileMapLayer.new()
		layer.tile_set = ts
		for run in range(run0, run0 + RUNS):
			layer.set_cell(Vector2i(run, cross), 0, Vector2i.ZERO)
		r._glass_layers[lvl] = layer
	r._glass_source_info[0] = {"material": "glass", "face": Face.SW, "mask": 0}

	var hit_run: int = run0 + RUNS / 2
	var hit_level: int = base + LEVELS / 2
	(r._glass_layers[hit_level] as TileMapLayer).erase_cell(Vector2i(hit_run, cross))
	r.note_glass_erased_for_rim(hit_level, Vector2i(hit_run, cross))
	var swapped: int = r.refresh_glass_rims()
	print("  pierced 1 voxel -> %d cell(s) cut into shards" % swapped)
	if mock_pool:
		_repaint_shards_with_pool(r, hit_run, hit_level, cross)
	else:
		print("  TIP_HALF=%.2f  DEPTH=%.2f (one shape, every shard)" % [
			VoxelRendererClass.GLASS_RIM_TIP_HALF, VoxelRendererClass.GLASS_RIM_DEPTH])

	var out := _composite(r, base)
	_free_layers(r)
	r.free()
	return out


## Re-cut the four shards, each with its own dial set, and put them back on the
## tilemap. ⚠️ A MOCK OF S-6, not S-6: it walks the four orthogonals directly
## instead of hashing, because the hash key is the open sub-question G-D32 left
## (it has to be BASE-space or a perspective flip reshuffles the hole). What this
## panel answers is only *what an irregular star looks like*, which is the part
## a picture can settle and reasoning cannot.
func _repaint_shards_with_pool(r, hit_run: int, hit_level: int, cross: int) -> void:
	var keep_tip: float = VoxelRendererClass.GLASS_RIM_TIP_HALF
	var keep_depth: float = VoxelRendererClass.GLASS_RIM_DEPTH
	var orthos: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.0, 1.0),
		Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]
	for i in range(orthos.size()):
		var d: Vector2 = orthos[i]
		var dials: Vector2 = MOCK_DIALS[i]
		VoxelRendererClass.GLASS_RIM_TIP_HALF = dials.x
		VoxelRendererClass.GLASS_RIM_DEPTH = dials.y
		var cell := Vector2i(hit_run + int(d.x), cross)
		var lvl: int = hit_level + int(d.y)
		var layer := r._glass_layers.get(lvl) as TileMapLayer
		if layer == null:
			continue
		## The cut points back AT the hole, so the direction is the negated offset
		## — the same vector `refresh_glass_rims()` accumulates.
		var dir_index: int = r._glass_rim_index(-d)
		## A fresh key per dial set, or the cache hands back the shape already cut.
		r._glass_rim_sources.erase("glass|%d|0|%d" % [Face.SW, dir_index])
		var rim_id: int = r._glass_rim_atom_source("glass", Face.SW, 0, dir_index)
		if rim_id >= 0:
			layer.set_cell(cell, rim_id, Vector2i.ZERO, 0)
		print("    shard %d: tip=%.2f depth=%.2f" % [i, dials.x, dials.y])
	VoxelRendererClass.GLASS_RIM_TIP_HALF = keep_tip
	VoxelRendererClass.GLASS_RIM_DEPTH = keep_depth


## Blit every placed cell's atom onto one canvas. Position is the pane's own
## basis: run advances by the SW diamond edge (vw -> vs) = (16, 8), a level is
## VOXEL_STEP_PX straight up.
func _composite(r, base: int) -> Image:
	var aw: int = GeometryCoordsClass.VOXEL_ATOM_W
	var ah: int = GeometryCoordsClass.VOXEL_ATOM_H
	var step: int = int(GeometryCoordsClass.VOXEL_STEP_PX)
	var run_step := Vector2i(aw / 2, aw / 4)          ## (16, 8) for a 32px atom
	var pad: int = 24
	var w: int = pad * 2 + aw + run_step.x * (RUNS - 1)
	var h: int = pad * 2 + ah + run_step.y * (RUNS - 1) + step * (LEVELS - 1)
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(BG)

	## Cache each source's image once — `get_image()` on an ImageTexture is a
	## readback, and there is one per cell otherwise.
	var atlas_cache: Dictionary = {}
	## Draw from the BOTTOM level up, so a higher cell overlaps the one below it
	## exactly as the tilemap's own y-sort does.
	for li in range(LEVELS):
		var lvl: int = base + li
		var layer := r._glass_layers.get(lvl) as TileMapLayer
		if layer == null:
			continue
		for run in range(RUNS):
			var sid: int = layer.get_cell_source_id(Vector2i(run, 7))
			if sid == -1:
				continue
			if not atlas_cache.has(sid):
				var s := r._tileset.get_source(sid) as TileSetAtlasSource
				atlas_cache[sid] = null if s == null else (s.texture as ImageTexture).get_image()
			var atom: Image = atlas_cache[sid]
			if atom == null:
				continue
			var pos := Vector2i(pad, pad) + run_step * run \
				+ Vector2i(0, step * (LEVELS - 1 - li))
			_blit_flat(canvas, atom, pos)
	return canvas


## Alpha-over `atom` onto `canvas`, repainting every covered pixel the SAME flat
## colour. The atom's RGB carries the per-plane dim and the tint index; keeping
## them would make the eye read lighting when the question is silhouette.
func _blit_flat(canvas: Image, atom: Image, at: Vector2i) -> void:
	for y in range(atom.get_height()):
		for x in range(atom.get_width()):
			var a: float = atom.get_pixel(x, y).a
			if a <= 0.0:
				continue
			var px: int = at.x + x
			var py: int = at.y + y
			if px < 0 or py < 0 or px >= canvas.get_width() or py >= canvas.get_height():
				continue
			var dst: Color = canvas.get_pixel(px, py)
			canvas.set_pixel(px, py, dst.lerp(GLASS_FLAT, a))


func _free_layers(r) -> void:
	for lvl in r._glass_layers:
		var layer := r._glass_layers[lvl] as TileMapLayer
		if layer != null:
			layer.free()
	r._glass_layers.clear()
