## GLASS CRACK-04 — RENDER THE FAMILY OF OPENINGS FROM THE REAL ATOMS.
##
## Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##            --script godot/scripts/tools/glass_rim_capture.gd
##
## One panel per member of `GlassOpening.FAMILY`, each a real pierced pane with
## that opening applied through the real `refresh_glass_rims()`. This is the
## picture a shape decision gets made on.
##
## ⚠️ WHY THIS EXISTS AS A COMMITTED TOOL AND NOT A SCRATCH SCRIPT.
## `glass_rim_shape_options_2026-09-02.png` — the picture G-D32 was ratified from
## — was made by an ad-hoc script that was never committed and no longer exists.
## It was captured at 04:11 on 2026-09-03, **four minutes before `330d285d` cut
## the neighbour count from 8 to 4**, so the silhouette it shows is one the build
## has not made since. A picture that cannot be re-made is a citation that decays
## (the same lesson the `auto_*.png` rotation already taught this project).
##
## ⚠️ IT COMPOSITES ATOMS, IT DOES NOT BOOT THE GAME. That is the point: the
## question is what SILHOUETTE an opening cuts, and a play-zoom screenshot cannot
## answer it — the difference between two openings is tenths of a voxel there.
## Compositing runs headless, deterministically, in under a second.
##
## The geometry is the atom's own, not a re-derivation: a SW face's diamond edge
## runs `vw -> vs`, so the RUN step in canvas is (16, 8), and a level is
## `VOXEL_STEP_PX` straight up. Those two vectors ARE the pane's basis — the same
## one `GlassCrackSprite` bakes into its Transform2D.
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const GlassOpeningClass = preload("res://godot/scripts/systems/destruction/glass_opening.gd")

## The pane to build, in cells. Big enough that the hole sits well inside it, so
## no edge case of the rim walk is silently doing the work.
## Big enough that the LARGE openings (7x7 cells) sit well inside it — a hole
## touching the pane edge would be measuring the pane, not the opening.
const RUNS: int = 15
const LEVELS: int = 13
const OUT_DIR := "res://Screenshots/history"

## Background and the flat colour every surviving atom is painted, so the picture
## reads as SILHOUETTE rather than as shading. The atoms carry a per-plane dim in
## RED and a tint in BLUE; keeping either would make the eye read lighting when
## the question is shape.
const BG := Color(0.16, 0.17, 0.22, 1.0)
const GLASS_FLAT := Color(1.0, 0.93, 0.20, 1.0)


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS CRACK-04 — the family of openings, composited from the real atoms")
	print("=".repeat(70) + "\n")

	var panels: Array = []
	for id in GlassOpeningClass.ids():
		var img := _render_hole(id)
		if img == null:
			push_error("[glass_rim_capture] '%s' produced no image" % id)
			quit(1)
			return
		panels.append(img)

	var sheet := _tile(panels)
	var stamp: String = Time.get_date_string_from_system()
	var path: String = "%s/glass_openings_family_%s.png" % [OUT_DIR, stamp]
	var err: int = sheet.save_png(path)
	if err != OK:
		push_error("[glass_rim_capture] save_png failed (%d) for %s" % [err, path])
		quit(1)
		return
	print("\nwrote %s  (%d x %d)" % [path, sheet.get_width(), sheet.get_height()])
	print("")
	quit(0)


## Lay the panels out in a grid, widest-first, so the whole family is one look
## instead of a folder to click through.
func _tile(panels: Array) -> Image:
	var cols: int = 4
	var pw: int = 0
	var ph: int = 0
	for img in panels:
		pw = maxi(pw, img.get_width())
		ph = maxi(ph, img.get_height())
	var rows: int = int(ceil(float(panels.size()) / float(cols)))
	var gap: int = 6
	var out := Image.create(cols * pw + (cols - 1) * gap, rows * ph + (rows - 1) * gap,
		false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.08, 0.10, 1.0))
	for i in range(panels.size()):
		var img: Image = panels[i]
		out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i((i % cols) * (pw + gap), (i / cols) * (ph + gap)))
	return out


## Build a real pane of real atoms, punch one voxel, run the REAL
## `refresh_glass_rims()`, then composite whatever the tilemap ended up holding.
func _render_hole(opening_id: String) -> Image:
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

	## ⚠️ THE CAPTURE PLAYS DESTRUCTION'S PART, because the renderer refuses to.
	## Every cell the opening swallows WHOLE is erased here, the way the shot or
	## the cook would erase it; the renderer is then only asked to shape the rim.
	## Doing it the other way — letting the walk erase what it covers — would put
	## a second writer on voxel existence and make this picture prettier than the
	## build, which is the one thing a capture must never be.
	var b: Rect2i = GlassOpeningClass.cell_bounds(opening_id)
	var erased: int = 0
	for dl in range(b.position.y, b.position.y + b.size.y):
		for dr in range(b.position.x, b.position.x + b.size.x):
			if GlassOpeningClass.coverage(opening_id, dr, dl) != GlassOpeningClass.Coverage.FULL:
				continue
			var cell := Vector2i(hit_run + dr, cross)
			var lvl: int = hit_level + dl
			var layer := r._glass_layers.get(lvl) as TileMapLayer
			if layer == null:
				continue
			layer.erase_cell(cell)
			r.note_glass_erased_for_rim(lvl, cell)
			erased += 1
	## A small opening can swallow nothing whole; the struck cell still goes.
	if erased == 0:
		(r._glass_layers[hit_level] as TileMapLayer).erase_cell(Vector2i(hit_run, cross))
		r.note_glass_erased_for_rim(hit_level, Vector2i(hit_run, cross))
		erased = 1

	## Claim the opening for this region BEFORE the flush, the same way the play
	## path will — so what this renders is the real application walk, not a
	## private one that only the capture uses.
	r.claim_glass_opening(hit_level, Vector2i(hit_run, cross), opening_id)
	var swapped: int = r.refresh_glass_rims()
	print("  %-18s footprint %dx%d  destroyed %2d  shards %2d"
		% [opening_id, b.size.x, b.size.y, erased, swapped])

	var out := _composite(r, base)
	_free_layers(r)
	r.free()
	return out


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


## Alpha-over `atom` onto `canvas`, modulating the flat colour by the atom's RED
## channel — the per-plane dim.
##
## ⚠️ IT USED TO FLATTEN THE RED AWAY, and that hid the thing this tool now exists
## to show. Discarding the dim made the picture a pure SILHOUETTE, which was right
## while the question was "what shape is the hole" and wrong the moment the
## question became "can the topography be read at all" — the cut's own facet lives
## entirely in that channel, so a flattened render would show none of it.
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
			var dim: float = atom.get_pixel(x, y).r
			var dst: Color = canvas.get_pixel(px, py)
			canvas.set_pixel(px, py, dst.lerp(
				Color(GLASS_FLAT.r * dim, GLASS_FLAT.g * dim, GLASS_FLAT.b * dim), a))


func _free_layers(r) -> void:
	for lvl in r._glass_layers:
		var layer := r._glass_layers[lvl] as TileMapLayer
		if layer != null:
			layer.free()
	r._glass_layers.clear()
