## RENDER_ORDER_MASTER_PLAN Task 1 — the Y-sort spike (Q1 + Q3).
##
## Answers, by MEASURING PIXELS rather than by looking:
##
##   Q1  Does Godot merge the tiles of two sibling Y-sorted TileMapLayers at the
##       SAME z_index, under a Y-sorted parent, into one depth order? This is the
##       whole premise of RO1/RO2 — the rejected GLASS §19 assumed it was already
##       happening and it never has been (y_sort_enabled appears zero times in
##       this repo).
##
##   Q3  Can a BackBufferCopy be ordered INSIDE that stream — i.e. can a glass
##       fragment read a snapshot that contains an opaque cell drawn earlier in
##       the SAME z band? That is exactly what GLASS §19 could not do (finding
##       F2) and what RO3/RO4 need.
##
## ⚠️ EVERY CASE SHIPS WITH ITS CONTROL. A case that only runs the "after" cannot
## tell "the mechanism worked" from "the probe cannot see anything", so each
## question is run twice — once configured to succeed, once configured to fail —
## and BOTH verdicts have to land for the answer to count.
##
## Geometry is the project's own (Transform Canon): tile_size (32,16), ISOMETRIC,
## DIAMOND_DOWN, atom 32x36, texture_origin (0,10). Cell (0,0) lands at screen
## (0,0) and cell (1,1) at (0,16) — 16 px apart with a 36 px atom, so they
## overlap by 20 px, and (1,1) is NEARER (view-space x+y greater, O5's canon).
##
## Must run WINDOWED — a headless run has no rasterizer and no backbuffer:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/render_order_ysort_spike.gd
extends SceneTree

const VIEW_SIZE := Vector2i(160, 160)
const ORIGIN := Vector2(70.0, 40.0)  ## pushes both atoms fully inside the viewport

## The glass tile encodes WHAT IT SAW: red channel = the backbuffer's red at this
## fragment, green forced to 1. So YELLOW means the snapshot contained the opaque
## cell; GREEN means it did not. No interpretation needed.
const PROBE_SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D probe_screen : hint_screen_texture, filter_nearest;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a <= 0.01) { COLOR = vec4(0.0); }
	else { COLOR = vec4(texture(probe_screen, SCREEN_UV).r, 1.0, 0.0, 1.0); }
}
"""

var _fail_count: int = 0


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("RENDER ORDER — Y-sort spike (Q1, Q3)   %s" % Time.get_datetime_string_from_system())
	print("Godot %s" % Engine.get_version_info()["string"])
	print("=".repeat(78))

	await _q1()
	await _q3()
	_q5()
	await _q6()

	print("\n" + "=".repeat(78))
	if _fail_count == 0:
		print("SPIKE VERDICT: every case AND every control landed as specified.")
	else:
		print("SPIKE VERDICT: %d case(s) did NOT land as specified — read above." % _fail_count)
	print("=".repeat(78) + "\n")
	quit(0)


# ─────────────────────────────────────────────────────────────────────────────
# Q1 — cross-layer Y-sort
# ─────────────────────────────────────────────────────────────────────────────
func _q1() -> void:
	print("\n── Q1: two sibling Y-sorted TileMapLayers at the same z_index ──")
	print("   glass at cell (0,0) = FAR, opaque at cell (1,1) = NEAR.")
	print("   The layers are added glass-FIRST... no: opaque first, GLASS LAST —")
	print("   so tree order alone would draw the far glass OVER the near wall.")
	print("   That is the bug, and it is what the control has to reproduce.\n")

	var on := await _render(true, false, Vector2i(0, 0), Vector2i(1, 1), 0)
	var off := await _render(false, false, Vector2i(0, 0), Vector2i(1, 1), 0)

	_verdict("Q1 CASE   y_sort ON  → the NEAR opaque cell must cover the far glass",
		on["opaque_clean"] > 100 and on["glass_over_opaque"] == 0,
		on)
	_verdict("Q1 CONTROL y_sort OFF → the far glass must (wrongly) cover it — the bug",
		off["glass_over_opaque"] > 100,
		off)


# ─────────────────────────────────────────────────────────────────────────────
# Q3 — a BackBufferCopy ordered inside the stream
# ─────────────────────────────────────────────────────────────────────────────
func _q3() -> void:
	print("\n── Q3: can a BackBufferCopy sort INTO the Y-stream? ──")
	print("   opaque at cell (0,0) = FAR, glass at cell (1,1) = NEAR, y_sort ON.")
	print("   The probe shader paints YELLOW if its snapshot held the opaque cell,")
	print("   GREEN if it held only the background.\n")

	## bb_y = 8 → between the far opaque (y=0) and the near glass (y=16).
	var inside := await _render(true, true, Vector2i(1, 1), Vector2i(0, 0), 8)
	## bb_y = -9000 → sorted before everything: the snapshot cannot hold the opaque.
	var before := await _render(true, true, Vector2i(1, 1), Vector2i(0, 0), -9000)

	_verdict("Q3 CASE   backbuffer BEHIND the glass → glass must SEE the opaque (yellow)",
		inside["probe_saw"] > 100 and inside["probe_blind"] == 0,
		inside)
	_verdict("Q3 CONTROL backbuffer before everything → glass must be BLIND (green)",
		before["probe_blind"] > 100 and before["probe_saw"] == 0,
		before)

	## ⚠️ HARNESS CONTROLS. The two verdicts above are IDENTICAL numbers, which is
	## the signature of a blind instrument rather than of an answer. Before any of
	## it counts, the harness has to prove a BackBufferCopy can be seen AT ALL in
	## this SubViewport — first by pure tree order (no Y-sort in play), then by the
	## z separation the shipping game actually uses.
	print("\n   Harness controls — can this rig see a backbuffer at all?\n")

	var tree_order := await _render(false, true, Vector2i(1, 1), Vector2i(0, 0), 0)
	_verdict("Q3 HARNESS-A y_sort OFF, tree order opaque→bb→glass, one z → must SEE (yellow)",
		tree_order["probe_saw"] > 100,
		tree_order)

	var z_split := await _render(false, true, Vector2i(1, 1), Vector2i(0, 0), 0, 10, 15, 20)
	_verdict("Q3 HARNESS-B y_sort OFF, z 10/15/20 (the shipping layout) → must SEE (yellow)",
		z_split["probe_saw"] > 100,
		z_split)

	## Q4 — the one mechanism that could give BOTH depth and the container: a
	## CanvasGroup renders its children into its own buffer and composites once
	## with its own material, and it is an ordinary CanvasItem, so it should sort
	## into the Y-stream where a BackBufferCopy does not.
	print("\n── Q4: a CanvasGroup as the container, sorted by Y ──\n")
	var cg := await _render_canvasgroup(true)
	_verdict("Q4 CASE    CanvasGroup at the NEAR cell, y_sort ON → must SEE the far opaque",
		cg["probe_saw"] > 100 and cg["opaque_clean"] > 100,
		cg)
	var cg_off := await _render_canvasgroup(false)
	_verdict("Q4 CONTROL same, y_sort OFF (tree order already favours it) → must SEE",
		cg_off["probe_saw"] > 100,
		cg_off)


# ─────────────────────────────────────────────────────────────────────────────
# Q6 — the split-layer design: correct depth with NO Y-sort at all
# ─────────────────────────────────────────────────────────────────────────────
##
## Q2 measured what Y-sort costs on the real board and the answer was most of a
## frame. But a pane is PLANAR: every opaque cell at its level is either nearer
## than that plane or farther, and which one is a scalar comparison known at map
## load. So the level's opaque cells can be split into two layers around the
## glass —
##
##     opaque_far → BackBufferCopy → glass → opaque_near
##
## all at the SAME z_index, ordered by the TREE, with no Y-sort anywhere and no
## batching given up. This case checks the tree delivers all three properties at
## once: the near wall covers the glass, the glass composites the far wall, and
## the container still works.
func _q6() -> void:
	print("\n── Q6: opaque_far → backbuffer → glass → opaque_near, one z, NO y-sort ──\n")
	var r := await _render_split()
	_verdict("Q6 CASE  the NEAR opaque must cover the glass, and the glass must SEE the far one",
		r["opaque_clean"] > 100 and r["probe_saw"] > 100,
		r)


func _render_split() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEW_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(VIEW_SIZE)
	bg.z_index = -100
	vp.add_child(bg)

	var board := Node2D.new()
	board.position = ORIGIN
	board.y_sort_enabled = false          ## the whole point
	vp.add_child(board)

	var tileset := _make_tileset()

	## FAR opaque at (0,0) — behind the pane, must show THROUGH it.
	var far_layer := _make_layer(tileset, false, "opaque_far")
	board.add_child(far_layer)
	far_layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0), 0)

	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	## ⚠️ The z_index is NOT optional and its default is a trap: a BackBufferCopy
	## left at 0 sorts BEFORE layers at 10 and snapshots the bare background. The
	## first run of this case read `probe_saw=0` for exactly that reason and it
	## looked like a verdict on the design.
	bb.z_index = 10
	board.add_child(bb)

	## The pane at (1,1).
	var glass_layer := _make_layer(tileset, false, "glass_layer")
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PROBE_SHADER
	mat.shader = sh
	glass_layer.material = mat
	board.add_child(glass_layer)
	glass_layer.set_cell(Vector2i(1, 1), 0, Vector2i(1, 0), 0)

	## NEAR opaque at (2,2) — in front of the pane, must COVER it. This is the
	## cell that is broken on the real board today.
	var near_layer := _make_layer(tileset, false, "opaque_near")
	board.add_child(near_layer)
	near_layer.set_cell(Vector2i(2, 2), 0, Vector2i(0, 0), 0)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var counts := _classify(vp.get_texture().get_image())
	vp.queue_free()
	return counts


# ─────────────────────────────────────────────────────────────────────────────
# Q5 — do a pane's own glass atoms actually overlap on screen?
# ─────────────────────────────────────────────────────────────────────────────
##
## The whole reason the BackBufferCopy container exists is G-D2: overlapping glass
## fragments must not tint twice. `_build_glass_pane_atom()`'s header CLAIMS the
## geometry already prevents it (*"a sliver fills only where the main face is
## absent, so nothing double-covers"*) — but a claim in a comment is not a
## measurement, and the answer decides how risky it is to drop the screen read.
##
## Two atoms of the same pane, stacked one level apart (20 px), are composited and
## every pixel where BOTH carry alpha is counted. Zero means the container is
## buying nothing WITHIN a pane.
func _q5() -> void:
	print("\n── Q5: do a pane's glass atoms overlap each other on screen? ──\n")
	var vr := VoxelRenderer.new()
	for face_name in ["SW", "SE"]:
		var face: int = Face.SW if face_name == "SW" else Face.SE
		## Interior voxel: no glass above it is FALSE (want_top), not the frontmost
		## column (want_side) — the body of a pane, which is nearly all of it.
		var body: Image = vr._build_glass_pane_atom(face, false, false, 0)
		var capped: Image = vr._build_glass_pane_atom(face, true, true, 0)
		if body == null:
			print("   %s: builder returned null" % face_name)
			continue
		print("   %s body atom  : %d opaque texels, rows %s" % [
			face_name, _alpha_count(body), _alpha_rows(body)])
		print("   %s capped atom : %d opaque texels, rows %s  (top + side slivers)" % [
			face_name, _alpha_count(capped), _alpha_rows(capped)])
		## Stack two BODY atoms one level apart — the pane's own vertical seam.
		var step := int(GeometryCoords.VOXEL_STEP_PX)
		print("   %s two body atoms stacked %d px apart → %d texels carry BOTH" % [
			face_name, step, _overlap(body, body, step)])
		## And a capped atom with a body atom above it (the real top-of-pane case).
		print("   %s capped + body above → %d texels carry BOTH" % [
			face_name, _overlap(capped, body, step)])
	vr.free()


func _alpha_count(img: Image) -> int:
	var n := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _alpha_rows(img: Image) -> String:
	var lo := -1
	var hi := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.0:
				if lo < 0:
					lo = y
				hi = y
				break
	return "%d..%d" % [lo, hi]


## `upper` is drawn `step` px HIGHER than `lower`. Counts texels where both are
## non-transparent — i.e. where a fragment would be tinted twice.
func _overlap(lower: Image, upper: Image, step: int) -> int:
	var n := 0
	for y in range(lower.get_height()):
		for x in range(lower.get_width()):
			if lower.get_pixel(x, y).a <= 0.0:
				continue
			var uy := y + step
			if uy < 0 or uy >= upper.get_height():
				continue
			if upper.get_pixel(x, uy).a > 0.0:
				n += 1
	return n


# ─────────────────────────────────────────────────────────────────────────────
func _verdict(label: String, ok: bool, counts: Dictionary) -> void:
	if not ok:
		_fail_count += 1
	print("%s  %s" % ["✓ PASS" if ok else "✗ FAIL", label])
	print("        %s" % _fmt(counts))


func _fmt(c: Dictionary) -> String:
	var keys: Array = c.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%d" % [k, c[k]])
	return " ".join(parts)


## Builds the whole scene from scratch, renders one frame, and classifies every
## pixel. `glass_cell` / `opaque_cell` are grid cells; `bb_y` is the
## BackBufferCopy's Y (only used when `use_probe`).
func _render(y_sort: bool, use_probe: bool, glass_cell: Vector2i, opaque_cell: Vector2i,
		bb_y: float, opaque_z: int = 10, bb_z: int = 10, glass_z: int = 10) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEW_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	## A known black ground so "the snapshot held only the background" reads as
	## red channel 0 — the probe's whole discriminator.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(VIEW_SIZE)
	bg.z_index = -100
	vp.add_child(bg)

	var board := Node2D.new()
	board.position = ORIGIN
	board.y_sort_enabled = y_sort
	vp.add_child(board)

	var tileset := _make_tileset()

	## OPAQUE first, GLASS last: tree order favours the glass, so anything that
	## reorders them has to be the Y-sort and cannot be the tree.
	var opaque_layer := _make_layer(tileset, y_sort, "opaque_layer")
	opaque_layer.z_index = opaque_z
	board.add_child(opaque_layer)
	opaque_layer.set_cell(opaque_cell, 0, Vector2i(0, 0), 0)

	if use_probe:
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		bb.position = Vector2(0.0, bb_y)
		bb.z_index = bb_z
		board.add_child(bb)

	var glass_layer := _make_layer(tileset, y_sort, "glass_layer")
	glass_layer.z_index = glass_z
	if use_probe:
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = PROBE_SHADER
		mat.shader = sh
		glass_layer.material = mat
	board.add_child(glass_layer)
	glass_layer.set_cell(glass_cell, 0, Vector2i(1, 0), 0)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var img: Image = vp.get_texture().get_image()
	var counts := _classify(img)
	counts["y_sort"] = 1 if y_sort else 0

	vp.queue_free()
	return counts


## Q4 — the glass tile lives inside a CanvasGroup whose material carries the
## probe shader. No BackBufferCopy anywhere: the group is supposed to supply its
## own. Opaque FAR at (0,0), the group's glass NEAR at (1,1).
func _render_canvasgroup(y_sort: bool) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = VIEW_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.size = Vector2(VIEW_SIZE)
	bg.z_index = -100
	vp.add_child(bg)

	var board := Node2D.new()
	board.position = ORIGIN
	board.y_sort_enabled = y_sort
	vp.add_child(board)

	var tileset := _make_tileset()

	var opaque_layer := _make_layer(tileset, y_sort, "opaque_layer")
	board.add_child(opaque_layer)
	opaque_layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0), 0)

	var group := CanvasGroup.new()
	group.name = "glass_group"
	group.z_index = 10
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PROBE_SHADER
	mat.shader = sh
	group.material = mat
	board.add_child(group)

	var glass_layer := _make_layer(tileset, y_sort, "glass_layer")
	group.add_child(glass_layer)
	glass_layer.set_cell(Vector2i(1, 1), 0, Vector2i(1, 0), 0)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var counts := _classify(vp.get_texture().get_image())
	counts["y_sort"] = 1 if y_sort else 0
	vp.queue_free()
	return counts


func _classify(img: Image) -> Dictionary:
	var c := {"opaque_clean": 0, "glass_over_opaque": 0, "glass_clean": 0,
		"probe_saw": 0, "probe_blind": 0}
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := img.get_pixel(x, y)
			var r := p.r
			var g := p.g
			var b := p.b
			if g > 0.7 and r > 0.5 and b < 0.3:
				c["probe_saw"] += 1                 ## yellow — snapshot had the opaque
			elif g > 0.7 and r < 0.2 and b < 0.3:
				c["probe_blind"] += 1               ## green — snapshot had only bg
			elif r > 0.7 and b < 0.2 and g < 0.2:
				c["opaque_clean"] += 1              ## pure red — opaque on top
			elif r > 0.3 and b > 0.2:
				c["glass_over_opaque"] += 1         ## blue over red — glass on top
			elif b > 0.2 and r < 0.2:
				c["glass_clean"] += 1               ## glass over background
	return c


func _make_layer(tileset: TileSet, y_sort: bool, layer_name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = tileset
	l.y_sort_enabled = y_sort
	l.y_sort_origin = 1          ## mirrors _build_voxel_layer_node()
	l.z_index = 10               ## SAME z for both — RO1's level band
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


## Transform Canon, copied from VoxelRenderer._build_tileset()/register paths.
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = GeometryCoords.VOXEL_TILE_SIZE
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN

	## Two atoms side by side: 0 = opaque RED, 1 = translucent BLUE.
	var atlas := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	for y in range(36):
		for x in range(32):
			atlas.set_pixel(x, y, Color(1, 0, 0, 1))
			atlas.set_pixel(x + 32, y, Color(0, 0, 1, 0.5))

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = Vector2i(GeometryCoords.VOXEL_ATOM_W, GeometryCoords.VOXEL_ATOM_H)
	for i in range(2):
		var coord := Vector2i(i, 0)
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.texture_origin = GeometryCoords.voxel_texture_origin()
	ts.add_source(src, 0)
	return ts
