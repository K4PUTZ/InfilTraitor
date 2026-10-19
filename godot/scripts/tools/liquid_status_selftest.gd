## M6 F5 — the per-liquid rules of 2026-10-18 as pure state, on the real liquid data and the real LIQUIDS_LAB map: the fire on the agent, the chill,
## the stain, the glow, the quicksand, a crust's plates, water that freezes, what a corrosive attacks, a body's own light and the tint byte.
extends SceneTree

const StatusClass = preload("res://godot/scripts/systems/liquid_agent_status.gd")
const SurfaceClass = preload("res://godot/scripts/systems/liquid_surface_state.gd")
const CorrosionClass = preload("res://godot/scripts/systems/liquid_corrosion.gd")
const GlowClass = preload("res://godot/scripts/systems/liquid_glow.gd")
const ExposureClass = preload("res://godot/scripts/systems/liquid_exposure.gd")
const FieldClass = preload("res://godot/scripts/systems/liquid_field.gd")
const PlaneClass = preload("res://godot/scripts/systems/fluid_plane.gd")
const RegistryClass = preload("res://godot/scripts/systems/liquid_registry.gd")
const LightFieldClass = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _info(kind: String, depth: float = 1.0) -> Dictionary:
	return {"kind": kind, "depth": depth, "gameplay": RegistryClass.gameplay(kind), "body": 0, "solid": 0}


func _init() -> void:
	print("\n== LIQUID STATUS SELFTEST ==\n")
	## 2. oil in flames, lava: the agent burns 2 turns, +0.25 a turn, water puts it out
	var st = StatusClass.new()
	_check(not st.on_step(_info("petroleo"), false) and st.burning == 0, "oil that does not burn does not set the agent on fire")
	_check(st.on_step(_info("petroleo"), true) and st.burning == 2, "burning oil sets the agent on fire for 2 turns")
	var a: float = st.on_turn_end({}, false, 0.1)
	var b: float = st.on_turn_end({}, false, 0.1)
	var c: float = st.on_turn_end({}, false, 0.1)
	_check(is_equal_approx(a, 0.25) and is_equal_approx(b, 0.25) and c == 0.0, "the fire adds 0.25 at each of its two turns' end, then is out (%.2f %.2f %.2f)" % [a, b, c])
	st.on_step(_info("lava_gold"), false)
	_check(st.burning == 2, "lava sets the agent on fire")
	st.on_step(_info("clean"), false)
	_check(st.burning == 0, "clean water puts the agent out")
	## 5. cryogenic: one AP of chill a turn in it, at most two, one less a turn out of it
	st.reset()
	st.on_turn_end(_info("criogenico"), false, 0.1)
	_check(st.on_turn_start() == 1, "a turn ended in the cryogenic liquid takes 1 AP")
	st.on_turn_end(_info("criogenico"), false, 0.2)
	st.on_turn_end(_info("criogenico"), false, 0.3)
	_check(st.on_turn_start() == 2, "the chill stops at 2 AP")
	st.on_turn_end({}, false, 0.3)
	_check(st.on_turn_start() == 1, "a turn out of it lets one AP of chill go")
	## 8. biohazard: 5 turns of stain after the last contact
	st.reset()
	st.on_step(_info("biohazard"), false)
	var stained: int = 0
	for _t in range(8):
		st.on_turn_end({}, false, 0.1)
		if st.marked > 0:
			stained += 1
	_check(stained == 4 and st.marked == 0, "the stain lasts 5 turns after the contact (the step's turn and 4 more: %d)" % stained)
	## 7. nuclear: the agent glows while the dose is above zero
	st.reset()
	st.on_step(_info("nuclear"), false)
	_check(st.is_glowing() and int(st.glow_spec.get("radius", 0)) == 2 and String(st.glow_spec.get("tint", "")) == "cool", "a step into the nuclear liquid makes the agent a small cool light")
	st.on_turn_end({}, false, 0.0)
	_check(not st.is_glowing(), "the glow goes when the dose is gone")
	## 9. quicksand: a still turn sinks a voxel; deep at the third, and the deep dose kills
	st.reset()
	var sand: Dictionary = _info("areia_movedica", 0.5)
	st.on_step(sand, false)
	_check(st.rule_depth(sand) == 0.0, "stepping in, the agent stands on top")
	st.settle(sand)
	st.on_turn_end(sand, false, 0.0)
	_check(st.rule_depth(sand) == 0.0, "a turn that moved does not sink the agent")
	var dose: float = 0.0
	var lethal_at: int = -1
	for t in range(1, 6):   ## the room's order at a turn's end: settle (sink), the dose at that depth, the statuses
		st.on_turn_start()
		st.settle(sand)
		dose = ExposureClass.after_turn(dose, sand["gameplay"], st.rule_depth(sand))
		st.on_turn_end(sand, false, dose)
		if lethal_at < 0 and ExposureClass.is_lethal(dose):
			lethal_at = t
	_check(lethal_at == 3, "still in quicksand, the agent is deep and dead at the third turn (turn %d)" % lethal_at)
	st.on_step({}, false)
	_check(st.sink == 0.0 and st.sink_kind == "", "leaving the quicksand resets the sink")

	## 6. a crust's plates: walkable, a count from the first step, broken for good after 3 turns (deep lava: blocked and lethal)
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("LIQUIDS_LAB")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var bodies: Array = layout["liquid_instances"]
	_check(bodies.size() == 10, "LIQUIDS_LAB compiles its ten bodies (%d)" % bodies.size())
	var by_kind: Dictionary = {}
	for body: Dictionary in bodies:
		by_kind[String(body["kind"])] = body
	var offset := Vector2i(layout.get("playable_rect", Rect2i()).position)
	var crust_body: Dictionary = by_kind["lava_crust"]
	var crust_plane = PlaneClass.from_body(crust_body, RegistryClass.fluidity("lava_crust"))
	_check(absf(crust_plane.committed[crust_plane.index(3, 2)] - 2.5) < 0.001, "a still pool opens holding its `fill` (%.2f voxels)" % crust_plane.committed[crust_plane.index(3, 2)])
	var crust = SurfaceClass.new()
	crust.setup(crust_plane, RegistryClass.gameplay("lava_crust"))
	var field = FieldClass.new()
	field.add_body("lava_crust", crust_body["rect"], crust_plane, crust)
	var on_crust := Vector2i(3, 7) + offset
	var info: Dictionary = field.at_cell(on_crust)
	_check(int(info.get("solid", 0)) == SurfaceClass.PLATE and not ExposureClass.is_blocked(info["gameplay"], float(info["depth"])) and ExposureClass.rate(info["gameplay"], float(info["depth"])) == 0.0,
			"an intact plate is walkable and gives no dose")
	crust.tick_turn()
	_check(crust.at_gu(on_crust) == SurfaceClass.PLATE, "a plate nobody stepped on never breaks")
	crust.step_on(on_crust)
	crust.tick_turn()
	crust.tick_turn()
	_check(crust.at_gu(on_crust) == SurfaceClass.PLATE, "two turns after the step the plate still holds")
	crust.tick_turn()
	info = field.at_cell(on_crust)
	_check(int(info.get("solid", 0)) == 0 and ExposureClass.is_blocked(info["gameplay"], float(info["depth"])) and ExposureClass.is_lethal(ExposureClass.after_turn(0.0, info["gameplay"], float(info["depth"]))),
			"the third turn breaks it: deep lava, blocked and lethal")
	_check(crust.at_gu(on_crust + Vector2i(2, 0)) == SurfaceClass.PLATE, "a plate two GU away still stands")

	## 5. the cold freezes the water beside it, along their common edge
	var cold_plane = PlaneClass.from_body(by_kind["criogenico"], RegistryClass.fluidity("criogenico"))
	var water_plane = PlaneClass.from_body(by_kind["clean"], RegistryClass.fluidity("clean"))
	var water = SurfaceClass.new()
	water.setup(water_plane, RegistryClass.gameplay("clean"))
	var touching: PackedInt32Array = SurfaceClass.contact_cells(cold_plane, water_plane)
	_check(touching.size() == 4, "the water's column along the cold's edge touches it (%d cells of 0.5 GU)" % touching.size())
	_check(water.freeze(touching) == 4 and water.freeze(touching) == 0, "those cells freeze, once")
	var wfield = FieldClass.new()
	wfield.add_body("clean", by_kind["clean"]["rect"], water_plane, water)
	var edge: Dictionary = wfield.at_cell(Vector2i(18, 2) + offset)
	var far: Dictionary = wfield.at_cell(Vector2i(19, 2) + offset)
	_check(int(edge.get("solid", 0)) == SurfaceClass.ICE and bool(edge["gameplay"].get("slippery", false)) and int(far.get("solid", 0)) == 0, "the edge GU is ice (slippery), the far one water")

	## 3-4. what the corrosives attack
	var acid = CorrosionClass.new()
	acid.setup(RegistryClass.gameplay("acido"))
	var toxic = CorrosionClass.new()
	toxic.setup(RegistryClass.gameplay("toxic"))
	_check(acid.turns == 6 and toxic.turns == 3, "acid takes 6 turns of contact, toxic 3")
	_check(acid.category_of("metal", false) == CorrosionClass.DISSOLVE and acid.category_of("stone", true) == CorrosionClass.MARK and acid.category_of("stone", false) == CorrosionClass.MARK
			and acid.category_of("paper", false) == "", "acid dissolves metal, marks the bed and the curbs, leaves cardboard")
	_check(toxic.category_of("paper", false) == CorrosionClass.DISSOLVE and toxic.category_of("fabric", false) == CorrosionClass.DISSOLVE and toxic.category_of("metal", false) == ""
			and toxic.category_of("stone", true) == "", "toxic dissolves cardboard and cloth, leaves metal and stone")
	var bar := Vector3i(1, 2, 76)
	var result: Dictionary = {}
	for _t in range(5):
		result = acid.tick({bar: CorrosionClass.DISSOLVE})
	_check((result[CorrosionClass.DISSOLVE] as Array).is_empty() and acid.count_of(bar) == 5, "five turns of contact are not enough")
	result = acid.tick({bar: CorrosionClass.DISSOLVE})
	_check((result[CorrosionClass.DISSOLVE] as Array) == [bar] and (acid.tick({bar: CorrosionClass.DISSOLVE})[CorrosionClass.DISSOLVE] as Array).is_empty(), "the sixth dissolves the bar, once")
	## the plane's grate opens when the bars go (a thick liquid, 0.5, so the grate holds some of it back: the acid itself is thin and passes it whole)
	var acid_plane = PlaneClass.from_body(by_kind["acido"], 0.5)
	var grate_at: float = float(by_kind["acido"]["fluid"]["grates"][0]["at"])
	var row: int = int(round((grate_at - acid_plane.origin.y) / acid_plane.cell_gu)) - 1   ## the row just above the line: its +y outflow crosses it
	var before: float = acid_plane._perm[acid_plane.index(2, row) * 4 + 2]
	acid_plane.open_grate("y", grate_at)
	_check(before < 1.0 and acid_plane._perm[acid_plane.index(2, row) * 4 + 2] == 1.0, "a grate line passes part of a thick liquid, and all of it once opened (%.2f -> 1)" % before)

	## 1, 7. a body's own light: lava warm, nuclear cool and faint; the tint byte keeps one hue
	var lava_light: Dictionary = GlowClass.body_light(RegistryClass.gameplay("lava_gold"))
	var nuke_light: Dictionary = GlowClass.body_light(RegistryClass.gameplay("nuclear"))
	_check(not lava_light.is_empty() and String(lava_light.get("tint", "warm")) == "warm" and String(nuke_light.get("tint", "")) == "cool"
			and float(nuke_light["energy"]) < float(lava_light["energy"]), "lava is a warm light, nuclear a fainter cool one")
	var glow = GlowClass.new()
	glow.setup(PlaneClass.from_body(by_kind["nuclear"], RegistryClass.fluidity("nuclear")))
	var lit: int = 0
	for v: float in glow.visual:
		if v > 0.0:
			lit += 1
	_check(lit == 16, "the nuclear pool's 16 wet cells glow (%d)" % lit)
	_check(LightFieldClass.encode_tint(1.0, 0.0) == 127 and LightFieldClass.encode_tint(0.0, 1.0) == 255 and LightFieldClass.encode_tint(0.0, 0.0) == 0
			and LightFieldClass.encode_tint(0.2, 0.6) >= 128 and LightFieldClass.encode_tint(0.6, 0.2) < 128, "the tint byte: warm 0..127, cool 128..255, the stronger hue wins")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
