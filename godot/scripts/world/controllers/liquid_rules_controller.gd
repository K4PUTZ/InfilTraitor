## LiquidRulesController — the per-liquid rules of M6 F5 on the open map (Director, 2026-10-18: "pode construir as oito regras com os padroes
## propostos", plus "o nuclear ilumina levemente o ambiente (fosforescente)"). The rules themselves are pure (`LiquidAgentStatus`,
## `LiquidSurfaceState`, `LiquidCorrosion`, `LiquidGlow`); this is where they meet the world:
##
## 1. LAVA is a light (warm) and IGNITES: a flammable body it touches catches fire, and so does the agent who steps in.
## 2. OIL in flames sets the AGENT on fire (2 turns, +0.25 dose a turn; water puts it out).
## 3. ACID dissolves metal it touches (a grating's bars fall, and the plane's grate opens) and marks floor and curb.
## 4. TOXIC dissolves paper, cardboard and cloth.
## 5. CRYOGENIC chills the agent (AP lost) and freezes the water it touches into walkable, slippery ice.
## 6. LAVA CRUST plates are walkable; 3 turns after the first step they break.
## 7. NUCLEAR glows faintly cool around itself, and the agent it doses glows (a tactical light).
## 8. BIOHAZARD stains the agent for 5 turns.
## 9. QUICKSAND sinks a still agent a voxel a turn; deep, it holds and kills.
##
## Order inside a liquid turn (`liquid_turn`, after the oil fire's own turn, before the planes tick): the lava lights what it touches, the cold
## freezes, the plates age, the corrosives eat, the glows follow their body. Every world write a rule makes goes the way a blast's does (base-recorded,
## the dirty pass, the board's commit, the support rule, the world revision).
extends RefCounted

const LiquidAgentStatusRef = preload("res://godot/scripts/systems/liquid_agent_status.gd")
const LiquidSurfaceStateRef = preload("res://godot/scripts/systems/liquid_surface_state.gd")
const LiquidCorrosionRef = preload("res://godot/scripts/systems/liquid_corrosion.gd")
const LiquidGlowRef = preload("res://godot/scripts/systems/liquid_glow.gd")
const LiquidFireLightsRef = preload("res://godot/scripts/systems/liquid_fire_lights.gd")
const LiquidRegistryRef = preload("res://godot/scripts/systems/liquid_registry.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

## The agent's look per status (alpha = how much): a fire breathes, a stain and a glow hold.
const BURN_TINT := Color(1.0, 0.45, 0.08, 0.55)
const MARK_TINT := Color(0.55, 0.04, 0.04, 0.45)
const GLOW_TINT := Color(0.55, 1.0, 0.35, 0.35)

var room: Node = null
var status = LiquidAgentStatusRef.new()
var _glows: Array = []            ## LiquidGlow, one per body that is a light
var _corrosions: Array = []       ## {"body": int, "corrosion": LiquidCorrosion, "grates": Array}
var _agent_light = null           ## the LightSource of a glowing agent (registered once, toggled)
var _agent_light_cell: Vector2i = Vector2i(-9999, -9999)
var _family: Dictionary = {}      ## material id -> family
var _tint_key: String = ""


func _init(p_room: Node) -> void:
	room = p_room


## A new map (or a reload): nothing carries over.
func reset() -> void:
	status.reset()
	_glows.clear()
	_corrosions.clear()
	_agent_light = null
	_agent_light_cell = Vector2i(-9999, -9999)
	_tint_key = ""
	refresh_agent_look()


## The solid surface a body needs (a crust's plates, water that can freeze), or null.
func surface_for(gameplay: Dictionary, plane: RefCounted) -> RefCounted:
	if plane == null:
		return null
	var surface = LiquidSurfaceStateRef.new()
	surface.setup(plane, gameplay)
	return surface if surface.is_active() else null


## What a body brings besides its sheet: its own light (lava, nuclear) and its corrosion (acid, toxic). `body` is the compiled `liquids` item,
## `index` its place in the field.
func add_body(index: int, kind: String, body: Dictionary, plane: RefCounted) -> void:
	if plane == null:
		return
	var gameplay: Dictionary = LiquidRegistryRef.gameplay(kind)
	var spec: Dictionary = LiquidGlowRef.body_light(gameplay)
	if not spec.is_empty() and room._dev_flag("FIRE_LIGHT", "1") != "0":
		var glow = LiquidGlowRef.new()
		glow.setup(plane)
		var lights = LiquidFireLightsRef.new()
		lights.setup(glow, body["rect"], spec)
		if not lights.lights.is_empty():
			_glows.append(glow)
			room.register_body_lights(lights)
	var corrosion = LiquidCorrosionRef.new()
	corrosion.setup(gameplay)
	if corrosion.is_active():
		_corrosions.append({"body": index, "corrosion": corrosion, "grates": ((body["fluid"] as Dictionary).get("grates", []) as Array).duplicate()})


## One liquid turn of every rule that changes the world (see the header for the order).
func liquid_turn() -> void:
	var field = room._liquid_field
	if field == null:
		return
	var bodies: Array = field.bodies()
	_lava_ignites(bodies)
	_cold_freezes(bodies)
	for body: Dictionary in bodies:
		if body["surface"] != null:
			var broke: PackedInt32Array = body["surface"].tick_turn()
			if not broke.is_empty():
				print_debug("[LIQUID-RULES] %s: %d plate cell(s) broke" % [body["kind"], broke.size()])
	for glow in _glows:
		glow.refresh()
	if not _corrosions.is_empty():
		_corrode(bodies)


func _lava_ignites(bodies: Array) -> void:
	for body: Dictionary in bodies:
		if not bool(LiquidRegistryRef.gameplay(String(body["kind"])).get("ignites", false)):
			continue
		for burn in room._liquid_fires:
			if burn.plane == body["plane"]:
				continue
			var lit: int = 0
			for i: int in LiquidSurfaceStateRef.contact_cells(body["plane"], burn.plane):
				lit += burn.ignite(burn.centre_of(i), float(burn.plane.cell_gu) * 0.5)
			if lit > 0:
				print_debug("[LIQUID-RULES] %s lit %d cell(s) of a flammable body it touches" % [body["kind"], lit])


func _cold_freezes(bodies: Array) -> void:
	for cold: Dictionary in bodies:
		if not bool(LiquidRegistryRef.gameplay(String(cold["kind"])).get("freezes_neighbours", false)):
			continue
		for water: Dictionary in bodies:
			if water == cold or water["surface"] == null or not water["surface"].freezable:
				continue
			var froze: int = water["surface"].freeze(LiquidSurfaceStateRef.contact_cells(cold["plane"], water["plane"]))
			if froze > 0:
				print_debug("[LIQUID-RULES] %s froze %d cell(s) of %s" % [cold["kind"], froze, water["kind"]])


## The family of a material (`MaterialDef.family`), cached.
func _family_of(material_id: String) -> String:
	if not _family.has(material_id):
		var definition = Registries.get_material_registry().resolve(material_id)
		_family[material_id] = String(definition.family) if definition != null else ""
	return String(_family[material_id])


## Every voxel a corrosive body touches now: the bed under each wet cell and, from the bed up to the surface, every voxel inside the cell or one
## voxel around it (the pit's walls, a curb, the bars of a grating standing in it).
func _contacts(body: Dictionary, corrosion, store: VoxelStore) -> Dictionary:
	var out: Dictionary = {}
	var plane = body["plane"]
	var bed: int = GeometryCoords.FLOOR_TOP_LEVEL - int(round(float(plane.dig)))
	var per_gu: int = GeometryCoords.VOXELS_PER_UNIT_AXIS
	for r in range(1, plane.rows - 1):
		for c in range(1, plane.cols - 1):
			var i: int = plane.index(c, r)
			if plane.committed[i] <= LiquidSurfaceStateRef.NO_DEPTH:
				continue
			var corner: Vector2 = plane.origin + Vector2(c, r) * float(plane.cell_gu)
			var x0: int = int(floor(corner.x * float(per_gu))) - 1
			var y0: int = int(floor(corner.y * float(per_gu))) - 1
			var x1: int = int(ceil((corner.x + float(plane.cell_gu)) * float(per_gu)))
			var y1: int = int(ceil((corner.y + float(plane.cell_gu)) * float(per_gu)))
			var top: int = bed + int(ceil(float(plane.ground[i]) + float(plane.committed[i])))
			for level in range(bed, top + 1):
				for y in range(y0, y1 + 1):
					for x in range(x0, x1 + 1):
						var key := Vector3i(x, y, level)
						if out.has(key) or not store.has_solid(x, y, level):
							continue
						var claim: int = store.owner[store.cell_index(x, y, level)]
						var category: String = corrosion.category_of(_family_of(store.material_ids[store.mat[claim]]), level == bed)
						if category != "":
							out[key] = category
	return out


func _corrode(bodies: Array) -> void:
	var store: VoxelStore = VoxelStore.active
	if store == null:
		return
	var dissolve: Array = []
	var marks: Array = []
	var opened: Array = []
	for entry: Dictionary in _corrosions:
		var body: Dictionary = bodies[int(entry["body"])]
		var acted: Dictionary = entry["corrosion"].tick(_contacts(body, entry["corrosion"], store))
		dissolve.append_array(acted[LiquidCorrosionRef.DISSOLVE])
		marks.append_array(acted[LiquidCorrosionRef.MARK])
		for key: Vector3i in acted[LiquidCorrosionRef.DISSOLVE]:
			for grate: Dictionary in entry["grates"]:
				var along: float = (float(key.y) + 0.5) / float(GeometryCoords.VOXELS_PER_UNIT_AXIS) if String(grate["axis"]) == "y" else (float(key.x) + 0.5) / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
				if absf(along - float(grate["at"])) <= float(body["plane"].cell_gu) and not opened.has(grate):
					opened.append(grate)
					body["plane"].open_grate(String(grate["axis"]), float(grate["at"]))
	for grate: Dictionary in opened:
		print_debug("[LIQUID-RULES] the acid opened the grate at %s = %.2f" % [grate["axis"], float(grate["at"])])
	if not dissolve.is_empty() or not marks.is_empty():
		_apply_corrosion(dissolve, marks, store)


## The corrosion's writes, the way a blast's are made (`Room.scenario_struct_cut` is the template): DESTROYED (quiet: no puff) or CRACKED (the mark),
## base-recorded for a checkpoint, the dirty passes, the board's commit, the props released, the support rule asked, the world revision bumped, the light
## around the opening repainted.
func _apply_corrosion(dissolve: Array, marks: Array, store: VoxelStore) -> void:
	var touched: Array = []
	var gus: Dictionary = {}
	for pair: Array in [[dissolve, Voxel.DamageState.DESTROYED], [marks, Voxel.DamageState.CRACKED]]:
		for key: Vector3i in pair[0]:
			if not store.has_solid(key.x, key.y, key.z):
				continue
			var v: Voxel = store.voxel_of(store.owner[store.cell_index(key.x, key.y, key.z)])
			if v == null or v.damage_state == Voxel.DamageState.DESTROYED:
				continue
			var state: int = int(pair[1])
			if state == Voxel.DamageState.CRACKED and v.damage_state != Voxel.DamageState.INTACT:
				continue
			if state == Voxel.DamageState.DESTROYED:
				room._quiet_destroy[key] = true
			v.set_damage(state, false, Voxel.CarvedSide.NONE, (key.x * 7 + key.y * 13 + key.z) % 3, 0)
			room.record_voxel_damage_to_base(v.grid_pos, v.level, v.damage_state, v.damage_is_blast, v.damage_carved_side, v.damage_variant, v.damage_substrate, v)
			touched.append(v)
			gus[Vector2i(key.x >> 3, key.y >> 3)] = true
	if touched.is_empty():
		return
	var epoch: int = room._map_epoch
	await room._voxel_board.process_dirty_slabs_async(room._slab_registry)
	await room._voxel_board.process_dirty_async(room._edge_registry)
	if not is_instance_valid(room) or room._map_epoch != epoch or not is_instance_valid(room._voxel_board):
		return
	var live: Node = room.board3d()
	if live != null:
		live.on_shot_commit(touched)
	room._release_destroyed_prop_cells()
	room.bump_world_revision()
	room.schedule_structural_support(touched)
	room._repaint_voxel_light_buckets_scoped(gus.keys())
	print_debug("[LIQUID-RULES] corrosion: %d voxel(s) dissolved, %d marked" % [dissolve.size(), marks.size()])


## The agent stepped onto `cell`, whose liquid is `info` ({} = dry): the statuses, a plate's count, the glow follows.
func on_step(cell: Vector2i, info: Dictionary) -> void:
	var on_fire: bool = room.liquid_fire_at(cell) != null
	if status.on_step(info, on_fire):
		print_debug("[LIQUID-RULES] the agent caught fire (%s)" % String(info.get("kind", "")))
	if not info.is_empty() and int(info.get("solid", 0)) == LiquidSurfaceStateRef.PLATE:
		var surface = room._liquid_field.bodies()[int(info["body"])]["surface"]
		if surface != null:
			surface.step_on(cell)
	refresh_agent_look()


## The player's turn ends on `cell` (liquid `info`, dose after the liquid's own): returns the dose the statuses add (the fire on the agent).
func on_turn_end(cell: Vector2i, info: Dictionary, dose: float) -> float:
	var extra: float = status.on_turn_end(info, room.liquid_fire_at(cell) != null, dose)
	refresh_agent_look()
	return extra


## A new turn, after the liquids ran theirs: a fire that spread under the agent catches it; returns the AP the chill takes.
func on_turn_start(cell: Vector2i, info: Dictionary) -> int:
	if not info.is_empty() and room.liquid_fire_at(cell) != null and bool((info["gameplay"] as Dictionary).get("ignites_agent", false)) and status.burning == 0:
		status.burning = LiquidAgentStatusRef.BURN_TURNS
		print_debug("[LIQUID-RULES] the fire reached the agent")
	var ap: int = status.on_turn_start()
	refresh_agent_look()
	return ap


## The agent's tint (the strongest status shows) and its glow light.
func refresh_agent_look() -> void:
	var agent: Node = room.agent if room != null else null
	var tint := Color(0, 0, 0, 0)
	var pulse: float = 0.0
	if status.burning > 0:
		tint = BURN_TINT
		pulse = 1.0
	elif status.marked > 0:
		tint = MARK_TINT
	elif status.is_glowing():
		tint = GLOW_TINT
	var key: String = "%s|%.1f" % [str(tint), pulse]
	if key != _tint_key and agent != null and agent.sprite != null and agent.sprite.has_meta("figure3d"):
		var figure = agent.sprite.get_meta("figure3d")
		if is_instance_valid(figure) and figure.has_method("set_status_tint"):
			figure.set_status_tint(tint, pulse)
			_tint_key = key
	_update_agent_light(agent)


## A glowing agent is a small cool light where it stands (tactical: the exposure counts it); its glow moves with it.
func _update_agent_light(agent: Node) -> void:
	if agent == null or room._lighting_controller == null or room._voxel_light_field == null or room._voxel_board == null:
		return
	var on: bool = status.is_glowing()
	if _agent_light == null:
		if not on:
			return
		_agent_light = LightSourceClass.new()
		_agent_light.light_id = "agent_glow"
		_agent_light.owner_name = "agent_glow"
		_agent_light.height_class = LightSourceClass.HEIGHT_HUMAN
		_agent_light.active = false
		room._lighting_controller.add_extra_lights([_agent_light])
	var spec: Dictionary = status.glow_spec
	var cell: Vector2i = agent.cell
	if on == bool(_agent_light.active) and (not on or cell == _agent_light_cell):
		return
	var gus: Dictionary = {}
	for gu in VoxelLightField.new().gus_in_light_range(_agent_light):
		gus[gu] = true
	if on:
		_agent_light.radius = maxi(int(spec.get("radius", 2)), 1)
		_agent_light.visual_energy = float(spec.get("energy", 0.5))
		_agent_light.tactical_energy = float(spec.get("energy", 0.5))
		_agent_light.warmth = float(spec.get("warmth", 0.6))
		_agent_light.tint = LightSourceClass.TINT_COOL if String(spec.get("tint", "cool")) == "cool" else LightSourceClass.TINT_WARM
		_agent_light.cell = cell
	_agent_light.active = on
	_agent_light_cell = cell
	for gu in VoxelLightField.new().gus_in_light_range(_agent_light):
		gus[gu] = true
	room._lighting_controller.rebuild_tactical()
	room._voxel_light_field.set_lights(room.field_lights(room._lighting_controller.get_light_registry()), room._lighting_controller.get_shadow_results())
	room.queue_light_cells(gus.keys())
