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
const WorldClass = preload("res://godot/scripts/tools/liquid_test_world.gd")

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
	_check(by_kind.has("lava_crust") and (by_kind["lava_crust"]["fluid"] as Dictionary).has("seed"), "and its pools are SEEDED: their shapes come from the world")
	## the bodies themselves in synthetic pits laid as LIQUIDS_LAB lays them (a body takes its shape from the voxels)
	var world = WorldClass.new()
	world.lay(Rect2i(0, 0, 8, 6), [Rect2i(2, 2, 4, 2)])
	var crust_made: Dictionary = world.body(Vector2(4.0, 3.0), RegistryClass.fluidity("lava_crust"), {"fill": 2.5})
	var crust_plane = crust_made["plane"]
	var mid: Vector2i = crust_plane.cell_of(Vector2(3.25, 2.25))
	_check(absf(crust_plane.committed[crust_plane.index(mid.x, mid.y)] - 2.5) < 0.001, "a still pool opens holding its `fill` (%.2f voxels)" % crust_plane.committed[crust_plane.index(mid.x, mid.y)])
	var crust = SurfaceClass.new()
	crust.setup(crust_plane, RegistryClass.gameplay("lava_crust"))
	var field = FieldClass.new()
	field.add_body("lava_crust", crust_made["rect"], crust_plane, crust)
	var on_crust := Vector2i(3, 2)
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

	## 6b. a cell that joins the crust LATER (a pillar in the pit destroyed, the container re-read) is a plate like the rest: walkable, counted, breakable
	world.lay(Rect2i(0, 0, 8, 6), [Rect2i(2, 2, 4, 2)])
	for x in range(32, 40):
		for y in range(16, 24):
			for lv in range(76, 80):
				world.solid[Vector3i(x, y, lv)] = true
	var late_made: Dictionary = world.body(Vector2(2.5, 2.5), RegistryClass.fluidity("lava_crust"), {"fill": 2.5})
	var late_plane = late_made["plane"]
	var late = SurfaceClass.new()
	late.setup(late_plane, RegistryClass.gameplay("lava_crust"))
	var pillar_cell: Vector2i = late_plane.cell_of(Vector2(4.5, 2.5))
	var pillar_i: int = late_plane.index(pillar_cell.x, pillar_cell.y)
	var pillar_cols: Array = []
	for x in range(32, 40):
		for y in range(16, 24):
			for lv in range(76, 80):
				world.solid.erase(Vector3i(x, y, lv))
			pillar_cols.append(Vector2i(x, y))
	(late_made["box"] as RefCounted).refresh(late_plane, pillar_cols, 80, late_made["info"])
	late_plane.committed[pillar_i] = 2.5     ## the liquid has reached the freed cell
	_check(late.solid[pillar_i] == SurfaceClass.PLATE and late.at_gu(Vector2i(4, 2)) == SurfaceClass.PLATE, "a cell that joins the crust later is an intact plate")
	late.step_on(Vector2i(4, 2))
	for _t in range(3):
		late.tick_turn()
	_check(late.solid[pillar_i] == 0 and late.at_gu(Vector2i(4, 2)) == 0, "and it breaks three turns after the step, like the first ones")

	## 5. the cold freezes the water beside it, along their common edge
	world.lay(Rect2i(0, 0, 8, 6), [Rect2i(2, 2, 4, 2)])
	world.divider(32, 2, 4)    ## one pit split in two containers, as LIQUIDS_LAB's `pit_divider`
	var cold_made: Dictionary = world.body(Vector2(3.0, 3.0), RegistryClass.fluidity("criogenico"), {"fill": 1.5})
	var water_made: Dictionary = world.body(Vector2(5.0, 3.0), RegistryClass.fluidity("clean"), {"fill": 1.5})
	var cold_plane = cold_made["plane"]
	var water_plane = water_made["plane"]
	var water = SurfaceClass.new()
	water.setup(water_plane, RegistryClass.gameplay("clean"))
	var touching: PackedInt32Array = SurfaceClass.contact_cells(cold_plane, water_plane)
	_check(touching.size() == 4, "the water's column along the cold's edge touches it (%d cells of 0.5 GU)" % touching.size())
	_check(water.freeze(touching) == 4 and water.freeze(touching) == 0, "those cells freeze, once")
	var wfield = FieldClass.new()
	wfield.add_body("clean", water_made["rect"], water_plane, water)
	var edge: Dictionary = wfield.at_cell(Vector2i(4, 2))
	var far: Dictionary = wfield.at_cell(Vector2i(5, 2))
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
	## 3b. a marked voxel is WEAKENED: a round lands on it harder, a blast ring that destroys takes it whole, the checkpoint keeps it
	var Weak = load("res://godot/scripts/systems/destruction/voxel_weakness.gd")
	Weak.clear()
	var eaten := Voxel.new(Vector2i(10, 11), 80, null)
	var sound := Voxel.new(Vector2i(12, 11), 80, null)
	_check(Weak.gain_of(eaten) == 1.0, "before the acid, every voxel takes a round at its own punch")
	Weak.mark(Vector3i(10, 11, 80))
	_check(Weak.gain_of(eaten) == Weak.punch_gain and Weak.punch_gain > 1.0 and Weak.gain_of(sound) == 1.0, "a marked voxel takes it %.1f times harder, its neighbour as before" % Weak.punch_gain)
	var ring_weights: Array[float] = [1.0]
	var none: Array[float] = [0.0]
	var swept: Array = BlastCalculator.simulate_container_damage([eaten, sound], "weak_test", "concrete", 0, 80, false, ring_weights, [0.0], none, none)
	var swept_voxels: Array = []
	for e in swept:
		swept_voxels.append(e["voxel"])
	_check(not swept_voxels.has(eaten) and not swept_voxels.has(sound), "a ring with no destroy weight leaves even the weakened voxel alone")
	swept = BlastCalculator.simulate_container_damage([eaten, sound], "weak_test", "concrete", 0, 80, false, ring_weights, [0.01], none, none)
	swept_voxels.clear()
	for e in swept:
		if int(e["state"]) == Voxel.DamageState.DESTROYED:
			swept_voxels.append(e["voxel"])
	_check(swept_voxels.has(eaten), "a ring that destroys takes the weakened voxel whole, however small its share")
	var saved: Array = Weak.to_save()
	Weak.clear()
	_check(Weak.count() == 0 and Weak.gain_of(eaten) == 1.0, "a new map forgets the weakness")
	Weak.from_save(saved)
	_check(Weak.count() == 1 and Weak.gain_of(eaten) == Weak.punch_gain, "and a restored checkpoint brings it back")
	Weak.clear()

	## the grating's bars hold back a thick liquid (0.5: the acid itself is thin and passes them whole); once dissolved, the container re-read lets it all through
	world.lay(Rect2i(0, 0, 6, 8), [Rect2i(2, 2, 2, 4)])
	world.bars(2, 4, 33)
	var acid_made: Dictionary = world.body(Vector2(3.0, 2.5), 0.5)
	var acid_plane = acid_made["plane"]
	var gcell: Vector2i = acid_plane.cell_of(Vector2(3.0, 4.1))
	var gi: int = acid_plane.index(gcell.x, gcell.y)
	var before: float = acid_plane._perm[gi * 4 + 2]
	var gone: Array = []
	for x in range(16, 32, 2):
		for lv in range(76, 80):
			world.solid.erase(Vector3i(x, 33, lv))
		gone.append(Vector2i(x, 33))
	acid_made["box"].refresh(acid_plane, gone, 80, acid_made["info"])
	_check(before < 1.0 and acid_plane._perm[gi * 4 + 2] == 1.0, "the bars pass part of a thick liquid, and all of it once dissolved (%.2f -> 1)" % before)

	## 1, 7. a body's own light: lava warm, nuclear cool and faint; the tint byte keeps one hue
	var lava_light: Dictionary = GlowClass.body_light(RegistryClass.gameplay("lava_gold"))
	var nuke_light: Dictionary = GlowClass.body_light(RegistryClass.gameplay("nuclear"))
	_check(not lava_light.is_empty() and String(lava_light.get("tint", "warm")) == "warm" and String(nuke_light.get("tint", "")) == "cool"
			and float(nuke_light["energy"]) < float(lava_light["energy"]), "lava is a warm light, nuclear a fainter cool one")
	var glow = GlowClass.new()
	world.lay(Rect2i(0, 0, 6, 6), [Rect2i(2, 2, 2, 2)])
	glow.setup(world.body(Vector2(3.0, 3.0), RegistryClass.fluidity("nuclear"), {"fill": 1.5})["plane"])
	var lit: int = 0
	for v: float in glow.visual:
		if v > 0.0:
			lit += 1
	_check(lit == 16, "the nuclear pool's 16 wet cells glow (%d)" % lit)
	_check(LightFieldClass.encode_tint(1.0, 0.0) == 127 and LightFieldClass.encode_tint(0.0, 1.0) == 255 and LightFieldClass.encode_tint(0.0, 0.0) == 0
			and LightFieldClass.encode_tint(0.2, 0.6) >= 128 and LightFieldClass.encode_tint(0.6, 0.2) < 128, "the tint byte: warm 0..127, cool 128..255, the stronger hue wins")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
