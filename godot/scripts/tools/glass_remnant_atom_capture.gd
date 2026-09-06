## GLASS G4-3 — photograph the REMNANT ATOMS, off the production cut path.
## Rodar: /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##            --script godot/scripts/tools/glass_remnant_atom_capture.gd
##
## ⚠️ IT CALLS `VoxelRenderer._build_glass_pane_atom()` AND THE REAL CUT HELPERS,
## not a re-implementation of them. What this sheet shows is the image that would
## be uploaded to a TileSetAtlasSource on a real break — the same pixels, at the
## same 32 x 36 the board draws.
##
## The leftmost column is the UNCUT atom, and it is the point of the sheet: the
## claim being checked is "a remnant is not the same little square", so the square
## has to be next to it.

extends SceneTree

const RendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")

const OUT_PATH: String = "res://Screenshots/history/glass_remnant_atoms_2026-09-05.png"
const AW: int = 32
const AH: int = 36
const ZOOM: int = 5
const PAD: int = 6
const BG := Color(0.086, 0.094, 0.110, 1.0)
const GUIDE := Color(0.20, 0.22, 0.25, 1.0)


func _init() -> void:
	var r = RendererClass.new()
	var ids: Array = ShardShapes.ids()
	var anchors: Array = [ShardShapes.ANCHOR_RUN_NEG, ShardShapes.ANCHOR_LEVEL_NEG,
		ShardShapes.ANCHOR_RUN_POS, ShardShapes.ANCHOR_LEVEL_POS,
		ShardShapes.ANCHOR_RUN_NEG | ShardShapes.ANCHOR_LEVEL_NEG]
	var names: Array = ["run-", "level-", "run+", "level+", "corner"]

	## SW face, no top/side sliver mask, plain glass tint — the commonest cell on
	## the GLASS map's windows.
	##
	## ⚠️ `Face.SW`, NEVER `0`: the enum is `{NW, NE, SE, SW}`, so a literal 0 is
	## NW. The cut stays self-consistent either way (the same face goes to the
	## builder and to the cutter), which is exactly why the mistake is silent.
	var face: int = Face.SW
	var cols: int = anchors.size() + 1
	var rows: int = ids.size()
	var cw: int = AW * ZOOM + PAD
	var ch: int = AH * ZOOM + PAD
	var true_h: int = AH + PAD
	var img := Image.create(PAD + cols * cw, PAD + rows * ch + true_h * 2, false, Image.FORMAT_RGBA8)
	img.fill(BG)

	var cut_px: Array = []
	for row in range(rows):
		var id: String = String(ids[row])
		for col in range(cols):
			var atom: Image = r._build_glass_pane_atom(face, false, false, 0)
			if atom == null:
				push_error("[G4-3] the pane atom did not build — nothing to cut")
				r.free()
				quit(1)
				return
			var before: int = _opaque(atom)
			if col > 0:
				var mask: int = int(anchors[col - 1])
				var poly: PackedVector2Array = ShardShapes.anchored_polygon(id, mask, row % 2 == 1)
				r._cut_glass_face_region(atom, face, func(off: Vector2) -> bool:
					return not ShardShapes.contains(poly, off))
				r._cut_glass_opening_slivers(atom, poly, Vector2.ZERO, face, true)
				r._trim_glass_remnant_fringe(atom, face)
				r._shade_glass_cut_facet(atom, poly, Vector2.ZERO, face, true)
				cut_px.append([id, names[col - 1], before, _opaque(atom)])
			_blit(img, atom, PAD + col * cw, PAD + row * ch, ZOOM)
			## and the same atom at TRUE SIZE, under the grid
			if row == 0:
				_blit(img, atom, PAD + col * cw, PAD + rows * ch, 1)
			if row == 1:
				_blit(img, atom, PAD + col * cw + AW + 2, PAD + rows * ch, 1)
			if row == 2:
				_blit(img, atom, PAD + col * cw, PAD + rows * ch + true_h, 1)
			if row == 3:
				_blit(img, atom, PAD + col * cw + AW + 2, PAD + rows * ch + true_h, 1)

	r.free()
	print("\n[G4-3] REMNANT ATOMS — column 0 is the UNCUT atom, the square this replaces\n")
	print("      %-8s %-8s %8s %8s %8s" % ["shape", "anchor", "uncut", "cut", "kept"])
	for e in cut_px:
		print("      %-8s %-8s %8d %8d %7.1f%%"
			% [e[0], e[1], e[2], e[3], 100.0 * float(e[3]) / maxf(float(e[2]), 1.0)])
	var err: int = img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("[G4-3] could not write %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	print("\n  wrote %s" % OUT_PATH)
	quit(0)


## Opaque pixel count — the number that says the cut did something, and by how
## much. A cut that removed nothing and a cut that removed everything both look
## plausible in a thumbnail and neither is what this is for.
func _opaque(atom: Image) -> int:
	var n: int = 0
	for y in range(atom.get_height()):
		for x in range(atom.get_width()):
			if atom.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _blit(dst: Image, src: Image, ox: int, oy: int, zoom: int) -> void:
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var c: Color = src.get_pixel(x, y)
			for j in range(zoom):
				for i in range(zoom):
					var px: int = ox + x * zoom + i
					var py: int = oy + y * zoom + j
					if px < 0 or py < 0 or px >= dst.get_width() or py >= dst.get_height():
						continue
					dst.set_pixel(px, py, c if c.a > 0.0 else GUIDE)
