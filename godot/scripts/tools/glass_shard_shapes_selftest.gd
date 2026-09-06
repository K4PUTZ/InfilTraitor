## GLASS G4-1 / G-D38 + G-D39 + G-D44 — GlassShardShapes selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_shard_shapes
##
##   [1] G-D44's size law, member by member, with the measured numbers printed
##   [2] every member is ANGULAR — straight chords, not a round blob
##   [3] the size law has TEETH: a filled cell is rejected by it
##   [4] the anchored form stays in its cell, touches its edge, and is FLAT there
##   [5] a corner anchor is cut on BOTH edges, not on a 45 degree plane
##   [6] the flop is a different placement, not the same polygon twice
##   [7] every member is REACHABLE by pick()
##   [8] the family shares no member with GlassOpening
##   [9] an empty anchor mask invents no placement

extends SceneTree

const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const OpeningClass = preload("res://godot/scripts/systems/destruction/glass_opening.gd")
const ShardFieldClass = preload("res://godot/scripts/overlays/shard_field.gd")
const RainClass = preload("res://godot/scripts/overlays/glass_rain_overlay.gd")

var passed: int = 0
var failed: int = 0

const EPS: float = 0.0005


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G4-1 — SHARD SHAPE FAMILY SELFTEST")
	print("=".repeat(70) + "\n")

	test_size_law()
	test_members_are_angular()
	test_the_size_law_has_teeth()
	test_anchored_form_is_flush_and_flat()
	test_a_corner_is_cut_on_both_edges()
	test_the_flop_is_a_different_placement()
	test_every_member_is_reachable()
	test_no_member_is_shared_with_glassopening()
	test_an_empty_mask_invents_nothing()
	test_the_atlas_holds_five_distinct_cells()
	test_the_field_writes_the_buffer_it_claims()
	test_the_rain_ages_in_frames_and_frees_itself()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS SHARD SHAPES SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS SHARD SHAPES SELFTEST FAIL\n")
		quit(1)


func _pass(msg: String) -> void:
	passed += 1
	print("  ✓ %s" % msg)


func _fail(msg: String) -> void:
	failed += 1
	print("  ✗ %s" % msg)


## ── [1] ──────────────────────────────────────────────────────────────────────
## G-D44: *"partes com tamanhos entre 1 e 1/2 voxel"*. The family is authored at
## the TOP of that band, so every member must fit one voxel and none may fill it.
func test_size_law() -> void:
	print("[1] G-D44's size law — every member fits one voxel, none fills it, and the band is EXACT\n")
	print("      %-8s  %-13s  %-8s  %-6s  %-6s  %s"
		% ["member", "extent", "area", "fill", "aspect", "verdict"])
	var bad: Array = []
	for id in ShardShapes.ids():
		var poly: PackedVector2Array = ShardShapes.polygon(id)
		var ext: Vector2 = ShardShapes.extent(poly)
		var a: float = ShardShapes.area(poly)
		var fill: float = a / maxf(ext.x * ext.y, 0.00001)
		var aspect: float = maxf(ext.x, ext.y) / maxf(minf(ext.x, ext.y), 0.00001)
		var ok: bool = ext.x <= ShardShapes.EXTENT_MAX + EPS \
			and ext.y <= ShardShapes.EXTENT_MAX + EPS \
			and maxf(ext.x, ext.y) >= ShardShapes.MAJOR_MIN \
			and a <= ShardShapes.AREA_MAX and fill >= ShardShapes.FILL_MIN \
			and aspect <= ShardShapes.ASPECT_MAX
		print("      %-8s  %5.3f x %5.3f  %6.4f  %5.3f  %5.2f   %s"
			% [id, ext.x, ext.y, a, fill, aspect, "ok" if ok else "OUT OF BAND"])
		if not ok:
			bad.append(id)
	if bad.is_empty():
		_pass("all %d members fit one voxel, reach %.2f on the long axis, and stay under area %.2f / aspect %.1f / over fill %.2f"
			% [ShardShapes.ids().size(), ShardShapes.MAJOR_MIN,
				ShardShapes.AREA_MAX, ShardShapes.ASPECT_MAX, ShardShapes.FILL_MIN])
	else:
		_fail("out of G-D44's band: %s" % [bad])

	## ⚠️ G-D44 IS THE BAND ON SCREEN, NOT ON THE AUTHORED MEMBER. A single
	## `scale in [0.5, 1.0]` over members of different authored sizes does NOT
	## produce "entre 1 e 1/2 voxel" — `chip` is authored 0.534 across, so half of
	## it is 0.267. `size_scale()` is what makes the band exact; this asserts it
	## for every member at both ends rather than trusting the arithmetic.
	var off: Array = []
	for id in ShardShapes.ids():
		for target in [ShardShapes.TARGET_MIN, ShardShapes.TARGET_MAX]:
			var sized: Vector2 = ShardShapes.extent(ShardShapes.polygon_sized(id, float(target)))
			if absf(maxf(sized.x, sized.y) - float(target)) > EPS:
				off.append("%s@%.2f=%.4f" % [id, target, maxf(sized.x, sized.y)])
	if off.is_empty():
		_pass("sized to %.2f and %.2f, every member's long axis IS that number — G-D44's band is exact, not approximate"
			% [ShardShapes.TARGET_MIN, ShardShapes.TARGET_MAX])
	else:
		_fail("size_scale() misses the target for: %s" % [off])


## ── [2] ──────────────────────────────────────────────────────────────────────
## ⚠️ The angular read comes from the JUMP between adjacent radii, not from the
## range of them: a straight fracture edge is the chord between two vertices at
## very different radii. GlassOpening paid for this once with sixteen smoothly
## eased vertices that rendered as round blobs.
func test_members_are_angular() -> void:
	print("\n[2] every member is ANGULAR — straight chords, not a round blob\n")
	var bad: Array = []
	for id in ShardShapes.ids():
		var j: int = ShardShapes.angular_jumps(id)
		print("      %-8s  %d jump(s) at ratio >= %.2f" % [id, j, ShardShapes.ANGULAR_RATIO])
		if j < ShardShapes.ANGULAR_JUMPS:
			bad.append("%s(%d)" % [id, j])
	if bad.is_empty():
		_pass("every member has at least %d adjacent-radius jump(s)" % ShardShapes.ANGULAR_JUMPS)
	else:
		_fail("too smooth to read as fractured: %s" % [bad])


## ── [3] ──────────────────────────────────────────────────────────────────────
## ⚠️ ASSERT IDENTITY, NOT ABSENCE. [1] passing says the members are in band; it
## does NOT say the band would reject anything, and a gate that accepts everything
## passes for the whole life of the bug. The filled cell is the exact thing G-D44
## exists to exclude, so it is the control.
func test_the_size_law_has_teeth() -> void:
	print("\n[3] the bounds have TEETH — a filled cell, a needle and a spider, each caught by a different one\n")
	var square := PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	var a: float = ShardShapes.area(square)
	var ext: Vector2 = ShardShapes.extent(square)
	print("      a filled cell measures extent %.3f x %.3f, area %.4f" % [ext.x, ext.y, a])
	if a > ShardShapes.AREA_MAX and ext.x <= ShardShapes.EXTENT_MAX + EPS:
		_pass("the square passes the EXTENT bound and is caught by the AREA bound (%.4f > %.2f) — which is why both exist"
			% [a, ShardShapes.AREA_MAX])
	else:
		_fail("the filled cell is NOT rejected: area %.4f against a max of %.2f" % [a, ShardShapes.AREA_MAX])

	## ⚠️ AND THE OTHER TWO DEGENERACIES, EACH WITH THE BOUND THAT ACTUALLY CATCHES
	## IT. This control is why there are two bounds and not one: written against a
	## lone FILL_MIN it FAILED, because a 1.0 x 0.1 rectangle has fill 0.70 — a
	## rectangle is its own bounding box. The needle is an ASPECT problem; the fill
	## ratio catches the other shape entirely, a spidery cross with plenty of box
	## and no body.
	var needle := PackedVector2Array([
		Vector2(-0.5, -0.05), Vector2(0.5, -0.05), Vector2(0.5, 0.05), Vector2(-0.5, 0.05)])
	var ne: Vector2 = ShardShapes.extent(needle)
	var nfill: float = ShardShapes.area(needle) / maxf(ne.x * ne.y, 0.00001)
	var naspect: float = maxf(ne.x, ne.y) / maxf(minf(ne.x, ne.y), 0.00001)
	print("      a needle  measures %.3f x %.3f, fill %.3f, aspect %5.2f" % [ne.x, ne.y, nfill, naspect])
	if naspect > ShardShapes.ASPECT_MAX and nfill >= ShardShapes.FILL_MIN:
		_pass("the needle passes FILL (%.2f) and is caught by ASPECT (%.1f > %.1f) — which is why the fill ratio alone was not enough"
			% [nfill, naspect, ShardShapes.ASPECT_MAX])
	else:
		_fail("the needle is not caught where expected: fill %.3f, aspect %.2f" % [nfill, naspect])

	var spider := PackedVector2Array([
		Vector2(-0.5, -0.04), Vector2(-0.04, -0.04), Vector2(-0.04, -0.5), Vector2(0.04, -0.5),
		Vector2(0.04, -0.04), Vector2(0.5, -0.04), Vector2(0.5, 0.04), Vector2(0.04, 0.04),
		Vector2(0.04, 0.5), Vector2(-0.04, 0.5), Vector2(-0.04, 0.04), Vector2(-0.5, 0.04)])
	var se: Vector2 = ShardShapes.extent(spider)
	var sfill: float = ShardShapes.area(spider) / maxf(se.x * se.y, 0.00001)
	var saspect: float = maxf(se.x, se.y) / maxf(minf(se.x, se.y), 0.00001)
	print("      a spider  measures %.3f x %.3f, fill %.3f, aspect %5.2f" % [se.x, se.y, sfill, saspect])
	if sfill < ShardShapes.FILL_MIN and saspect <= ShardShapes.ASPECT_MAX:
		_pass("the spider passes ASPECT (%.2f) and is caught by FILL (%.3f < %.2f) — the mirror case, which is why BOTH bounds exist"
			% [saspect, sfill, ShardShapes.FILL_MIN])
	else:
		_fail("the spider is not caught where expected: fill %.3f, aspect %.2f" % [sfill, saspect])


## ── [4] ──────────────────────────────────────────────────────────────────────
## G-D39. Three claims at once, because a placement that satisfies two of them is
## still wrong on screen: INSIDE its own cell, FLUSH against the anchored edge,
## and CUT FLAT there (a tangent would leave a single vertex touching and the
## fragment would read as floating).
func test_anchored_form_is_flush_and_flat() -> void:
	print("\n[4] the anchored form is inside the cell, flush, and FLAT at the edge\n")
	var anchors: Array = [ShardShapes.ANCHOR_RUN_POS, ShardShapes.ANCHOR_RUN_NEG,
		ShardShapes.ANCHOR_LEVEL_POS, ShardShapes.ANCHOR_LEVEL_NEG]
	var names: Array = ["run+", "run-", "level+", "level-"]
	var problems: Array = []
	var kept_min: float = INF
	## ⚠️ THE CLAIM THE CAPTURE FOUND AND THE NUMBERS HAD NOT. "Flush and flat" was
	## true of every placement while half of them still read as fragments FLOATING
	## near the brick — a flat cut two hundredths of a voxel long is a nub, and a
	## nub satisfies both. The measure of *"grudado"* is how BROADLY it is held.
	var contact_min: float = INF
	var reached: int = 0
	var placements: int = 0
	for id in ShardShapes.ids():
		var free_area: float = ShardShapes.area(ShardShapes.polygon(id))
		for i in range(anchors.size()):
			var mask: int = int(anchors[i])
			var poly: PackedVector2Array = ShardShapes.anchored_polygon(id, mask)
			var tag := "%s/%s" % [id, names[i]]
			if poly.size() < 3:
				problems.append("%s: empty" % tag)
				continue
			var d: Vector2 = ShardShapes.ANCHOR_DIRS[mask]
			var far: float = -INF
			var on_edge: int = 0
			var outside: int = 0
			for p in poly:
				far = maxf(far, p.dot(d))
				if absf(p.dot(d) - 0.5) <= EPS:
					on_edge += 1
				if absf(p.x) > 0.5 + EPS or absf(p.y) > 0.5 + EPS:
					outside += 1
			if outside > 0:
				problems.append("%s: %d vertex/vertices outside the cell" % [tag, outside])
			if absf(far - 0.5) > EPS:
				problems.append("%s: not flush (far edge at %.4f)" % [tag, far])
			if on_edge < 2:
				problems.append("%s: %d vertex on the attach plane — a tangent, not a cut" % [tag, on_edge])
			var kept: float = ShardShapes.area(poly) / maxf(free_area, 0.00001)
			kept_min = minf(kept_min, kept)
			var contact: float = ShardShapes.contact_length(poly, d)
			contact_min = minf(contact_min, contact)
			placements += 1
			if contact >= ShardShapes.ATTACH_MIN_CONTACT - EPS:
				reached += 1
	if contact_min < 0.15:
		problems.append("narrowest contact is only %.3f voxel — that is a nub, not an attachment" % contact_min)
	if problems.is_empty():
		_pass("%d placements: all inside, flush and flat; the clip keeps at least %.0f%% of the free area"
			% [placements, kept_min * 100.0])
		_pass("held BROADLY: %d of %d placements reach the %.2f-voxel contact target, and the narrowest of all is %.3f"
			% [reached, placements, ShardShapes.ATTACH_MIN_CONTACT, contact_min])
	else:
		_fail("anchored placement problems: %s" % [problems])


## ── [5] ──────────────────────────────────────────────────────────────────────
## An L-shaped frame cuts a fragment on BOTH of its edges. A 45 degree plane
## through the corner would be one straight diagonal — a shape no frame makes.
func test_a_corner_is_cut_on_both_edges() -> void:
	print("\n[5] a corner anchor is cut on BOTH edges, not on a 45 degree plane\n")
	var mask: int = ShardShapes.ANCHOR_RUN_NEG | ShardShapes.ANCHOR_LEVEL_NEG
	var problems: Array = []
	for id in ShardShapes.ids():
		var poly: PackedVector2Array = ShardShapes.anchored_polygon(id, mask)
		if poly.size() < 3:
			problems.append("%s: empty" % id)
			continue
		var on_x: int = 0
		var on_y: int = 0
		for p in poly:
			if absf(p.x + 0.5) <= EPS:
				on_x += 1
			if absf(p.y + 0.5) <= EPS:
				on_y += 1
			if p.x < -0.5 - EPS or p.y < -0.5 - EPS:
				problems.append("%s: vertex past the corner at %s" % [id, p])
		if on_x < 2 or on_y < 2:
			problems.append("%s: %d on run-, %d on level- — one of the two edges is a tangent" % [id, on_x, on_y])
	if problems.is_empty():
		_pass("all %d members sit in the corner with a real cut on each of the two edges" % ShardShapes.ids().size())
	else:
		_fail("corner placement problems: %s" % [problems])


## ── [6] ──────────────────────────────────────────────────────────────────────
## The flop is claimed to double the vocabulary for free. If it returned the same
## polygon for a symmetric member the claim would be quietly false — and a defect
## that is the identity on symmetric inputs is invisible to sampling, which this
## project has paid for before.
func test_the_flop_is_a_different_placement() -> void:
	print("\n[6] the flop is a DIFFERENT placement, not the same polygon twice\n")
	var same: Array = []
	for id in ShardShapes.ids():
		var a: PackedVector2Array = ShardShapes.anchored_polygon(id, ShardShapes.ANCHOR_RUN_NEG, false)
		var b: PackedVector2Array = ShardShapes.anchored_polygon(id, ShardShapes.ANCHOR_RUN_NEG, true)
		var moved: float = 0.0
		if a.size() == b.size():
			for i in range(a.size()):
				moved = maxf(moved, (a[i] - b[i]).length())
		else:
			moved = 1.0
		if moved <= 0.01:
			same.append(id)
	if same.is_empty():
		_pass("every member's flop is a genuinely different placement")
	else:
		_fail("the flop is the identity for: %s — the vocabulary is half what it claims" % [same])


## ── [7] ──────────────────────────────────────────────────────────────────────
## ⚠️ ASSERT EVERY CLASS IS REACHABLE, not just that the extremes map somewhere.
## CRAZE_FINE_MIN shipped at a value that put three of four rings on one sheet and
## the comment claimed otherwise; nothing caught it because nothing asked.
func test_every_member_is_reachable() -> void:
	print("\n[7] every member is REACHABLE by pick()\n")
	var seen: Dictionary = {}
	for i in range(400):
		seen[ShardShapes.pick("PANE_SLICE_%d_%d_SW|%d" % [i % 17, i % 23, i])] = true
	var missing: Array = []
	for id in ShardShapes.ids():
		if not seen.has(id):
			missing.append(id)
	if missing.is_empty():
		_pass("all %d members are picked over 400 base keys" % ShardShapes.ids().size())
	else:
		_fail("unreachable member(s): %s — authored and never used" % [missing])


## ── [8] ──────────────────────────────────────────────────────────────────────
## G-D38: an opening's interior is REMOVED and a fragment's is KEPT, so the two
## families must never share a member. A shared id would mean one of the two is
## being used the wrong way round.
func test_no_member_is_shared_with_glassopening() -> void:
	print("\n[8] no member is shared with GlassOpening\n")
	var shared: Array = []
	for id in ShardShapes.ids():
		if OpeningClass.FAMILY.has(id):
			shared.append(id)
	if shared.is_empty():
		_pass("the %d shard shapes and the %d openings share no id"
			% [ShardShapes.ids().size(), OpeningClass.FAMILY.size()])
	else:
		_fail("shared with GlassOpening: %s" % [shared])


## ── [9] ──────────────────────────────────────────────────────────────────────
## A remnant with no anchor is a caller bug (the survival test cannot produce
## one), so this must be loud and empty rather than a placement invented from
## nothing. The ERROR line below is the expected output, not a failure.
func test_an_empty_mask_invents_nothing() -> void:
	print("\n[9] an empty anchor mask invents no placement (one ERROR line is expected)\n")
	var poly: PackedVector2Array = ShardShapes.anchored_polygon("wedge", 0)
	if poly.is_empty():
		_pass("mask 0 returns an empty polygon and says so loudly")
	else:
		_fail("mask 0 returned %d vertices — a placement invented with nothing to hang from" % poly.size())


## ── [10] G6b-1 — THE ATLAS ───────────────────────────────────────────────────
##
## Three claims, and the third is the one nothing else would catch: the cells are
## laid edge to edge in U, so ink touching a boundary bleeds into the neighbour
## the moment a shard is drawn small enough to filter — which is the size the rain
## is ALWAYS drawn at.
func test_the_atlas_holds_five_distinct_cells() -> void:
	print("\n[10] G6b-1 — the atlas: five cells, each with its own member, none bleeding\n")
	var img: Image = ShardShapes.atlas_image()
	var n: int = ShardShapes.ids().size()
	var cell: int = ShardShapes.ATLAS_CELL_PX
	if img.get_width() != cell * n or img.get_height() != cell:
		_fail("atlas is %dx%d, expected %dx%d" % [img.get_width(), img.get_height(), cell * n, cell])
		return
	var inks: Array = []
	var empty: Array = []
	for i in range(n):
		var ink: int = 0
		for y in range(cell):
			for x in range(cell):
				if img.get_pixel(i * cell + x, y).a > 0.0:
					ink += 1
		inks.append(ink)
		if ink == 0:
			empty.append(ShardShapes.ids()[i])
		print("      cell %d  %-8s  %5d texel(s)  (%.1f%% of the cell)"
			% [i, ShardShapes.ids()[i], ink, 100.0 * float(ink) / float(cell * cell)])
	if empty.is_empty():
		_pass("all %d cells carry ink — no member rasterised to nothing" % n)
	else:
		_fail("empty cell(s): %s — a member that draws nothing at all" % [empty])

	## ⚠️ THE MARGIN, ASSERTED AS IDENTITY. "Every cell has ink" would pass just as
	## well for five cells whose shapes run off their own edges into each other.
	var margin_px: int = int(floor(float(cell) * ShardShapes.ATLAS_MARGIN * 0.5))
	var bleed: int = 0
	for i in range(n):
		for y in range(cell):
			for x in range(cell):
				if x >= margin_px and x < cell - margin_px \
						and y >= margin_px and y < cell - margin_px:
					continue
				if img.get_pixel(i * cell + x, y).a > 0.0:
					bleed += 1
	if bleed == 0:
		_pass("and not one texel inside the %d px border of any cell — nothing to bleed" % margin_px)
	else:
		_fail("%d texel(s) in a cell border — member %d will fringe into member %d at small scale"
			% [bleed, 0, 1])

	## And the members are not five copies of one shape: the ink counts must differ.
	var same: bool = true
	for i in range(1, n):
		if absi(int(inks[i]) - int(inks[0])) > 8:
			same = false
			break
	if not same:
		_pass("the five cells carry genuinely different amounts of ink — five members, not one repeated")
	else:
		_fail("every cell has the same ink (%s) — the atlas may be one shape five times" % [inks])
	print("")


## ── [11] G6b-1 — THE FIELD ───────────────────────────────────────────────────
##
## ⛔ THE `custom_aabb` ASSERTION IS THE POINT OF THIS TEST. Godot derives a
## MultiMesh's bounds from its BASE MESH — here a quad of half-extent 0.5 — and
## culls every instance outside it, silently. P7b shipped exactly this and lost
## whole plumes (0 magenta pixels against 4 055 once the box was set) while its own
## 0-pixel gate passed, because that gate draws near the origin and could never
## reach the failure. A shard rain lands hundreds of pixels from its node, so this
## is the population that breaks it.
func test_the_field_writes_the_buffer_it_claims() -> void:
	print("[11] G6b-1 — the field's buffer, and the box that keeps it on screen\n")
	var host := Node2D.new()
	root.add_child(host)
	var field = ShardFieldClass.new()
	field.attach(host)

	var n: int = 40
	field.begin(n)
	var far := Vector2(-4200.0, 3100.0)   ## deliberately far from the node origin
	for i in range(n):
		field.push(far + Vector2(float(i) * 13.0, float(i) * -7.0), 16.0,
			float(i) * 0.31, i % ShardShapes.ids().size(),
			Color(1.0, 1.0, 1.0, 1.0), i % 2 == 0, i % 3 == 0)
	field.flush()

	if field.live_count() == n:
		_pass("%d pushes produce %d live instance(s)" % [n, field.live_count()])
	else:
		_fail("pushed %d, published %d" % [n, field.live_count()])

	var buf: PackedFloat32Array = field._mm.buffer
	if buf.size() == n * ShardFieldClass.FLOATS_PER_INSTANCE:
		_pass("the buffer is exactly %d floats — %d per instance, the stride use_custom_data needs"
			% [buf.size(), ShardFieldClass.FLOATS_PER_INSTANCE])
	else:
		_fail("buffer is %d floats, expected %d — a wrong stride is ACCEPTED by MultiMesh and draws garbage"
			% [buf.size(), n * ShardFieldClass.FLOATS_PER_INSTANCE])

	## The custom data must carry the atlas cell, at the offset the shader reads.
	var wrong: int = 0
	for i in range(n):
		var got: int = int(buf[i * ShardFieldClass.FLOATS_PER_INSTANCE + 12])
		if got != i % ShardShapes.ids().size():
			wrong += 1
	if wrong == 0:
		_pass("every instance's custom data carries its own atlas cell")
	else:
		_fail("%d instance(s) carry the wrong atlas cell — the shader would draw another member" % wrong)

	## ⛔ The box.
	var box: AABB = field._mm.custom_aabb
	var covered: bool = box.size.x > 1000.0 and box.size.y > 1000.0 \
		and box.has_point(Vector3(far.x, far.y, 0.0))
	if covered:
		_pass("custom_aabb covers a shard at %s — %.0f x %.0f, so nothing is culled for being far from the node"
			% [far, box.size.x, box.size.y])
	else:
		_fail("custom_aabb %s does NOT contain %s — instances there are dropped before they are drawn, silently" % [box, far])

	field.clear()
	if field.live_count() == 0:
		_pass("clear() empties the field")
	else:
		_fail("clear() left %d instance(s)" % field.live_count())
	host.queue_free()
	print("")


## ── [12] G6b-2 — THE RAIN ────────────────────────────────────────────────────
##
## ⛔ THE FIRST ASSERTION IS THE STANDING TRAP OF THIS WHOLE TRACK. The rain is
## spawned on the detonation's COMMIT frame — the one that mints, applies the light
## field and stalls. An animation aged in SECONDS plays its entire life inside that
## one stalled frame and the player sees the settled floor with no fall at all;
## the ember overlay and the strobe each learned it the same way. So `_process` is
## driven here with a delta of ZERO, which is what a seconds-based animation cannot
## survive and a frame-based one does not notice.
func test_the_rain_ages_in_frames_and_frees_itself() -> void:
	print("\n[12] G6b-2 — the rain ages in FRAMES, replays exactly, and frees itself\n")
	var flights: Array = [
		{"from": Vector2(100.0, 40.0), "to": Vector2(104.0, 300.0), "key": Vector3i(3, -4, 88)},
		{"from": Vector2(140.0, 60.0), "to": Vector2(139.0, 300.0), "key": Vector3i(4, -4, 88)},
		{"from": Vector2(180.0, 20.0), "to": Vector2(176.0, 300.0), "key": Vector3i(5, -4, 87)},
	]
	var a = RainClass.new()
	root.add_child(a)
	var n: int = a.spawn(flights)
	if n >= flights.size():
		_pass("%d flight(s) split into %d shard(s) — G-D44's 1 to 4 pieces per voxel" % [flights.size(), n])
	else:
		_fail("%d flight(s) produced only %d shard(s)" % [flights.size(), n])

	## ⛔ delta = 0.0, over and over. A seconds-based rain never moves.
	for _i in range(6):
		a._process(0.0)
	var early: PackedFloat32Array = a._field._mm.buffer.duplicate()
	for _j in range(6):
		a._process(0.0)
	var later: PackedFloat32Array = a._field._mm.buffer.duplicate()
	var moved: bool = false
	for k in range(mini(early.size(), later.size())):
		if absf(early[k] - later[k]) > 0.001:
			moved = true
			break
	if moved:
		_pass("six more _process(0.0) calls move the shards — it counts FRAMES, not seconds")
	else:
		_fail("nothing moved across 6 frames at delta 0 — the rain is aged in SECONDS and will play inside the stalled commit frame")

	## Replays exactly: same flights, same buffer. `randf()` here would make a
	## filmstrip of one event uncomparable to a filmstrip of the next, which is the
	## hole `glass_blast_demo` has and this one must not.
	var b = RainClass.new()
	root.add_child(b)
	b.spawn(flights)
	for _m in range(12):
		b._process(0.0)
	var mirror: PackedFloat32Array = b._field._mm.buffer
	var same: bool = mirror.size() == later.size()
	if same:
		for k2 in range(mirror.size()):
			if absf(mirror[k2] - later[k2]) > 0.0001:
				same = false
				break
	if same:
		_pass("a second rain from the same flights writes a byte-identical buffer — the event is replayable")
	else:
		_fail("two rains from the same flights disagree — something here rolls instead of hashing")

	## And it takes nothing with it.
	var span: int = a.span_frames()
	for _p in range(span + 8):
		if not is_instance_valid(a):
			break
		a._process(0.0)
	if not is_instance_valid(a) or a.is_queued_for_deletion():
		_pass("the rain frees itself after its %d-frame span — G-D43: it is disposable" % span)
	else:
		_fail("the rain is still alive %d frames past its own span" % 8)
	if is_instance_valid(a):
		a.queue_free()
	b.queue_free()
	print("")
