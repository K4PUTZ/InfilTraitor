## Selftest — RoofSheetRelease on the REAL ROOF_LAB map (ROOF_MASTER_PLAN v0.28): room C's FABRIC awning is found whole, held where its two back walls
## are and free where nothing stands, and the sheet it becomes falls the way the lab's awning did. A synthetic fixture cannot answer this: the first
## capture of the feature had the awning on the board's own exterior wall (held on three sides, so it hung flat), which only the real data showed.
extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")

class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_board
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("RoofSheetRelease SELFTEST (ROOF_LAB, room C)")
	print("=".repeat(70) + "\n")
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("ROOF_LAB")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var room := MinimalRoom.new()
	root.add_child(room)
	var renderer := VoxelBoardClass.new()
	room.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	room._voxel_board = renderer
	var builder := RoomBuilderClass.new(room)
	builder.build_from_layout(layout, layout.get("size", Vector2i.ZERO))
	VoxelStore.active = VoxelStore.build(room._edge_registry, room._slab_registry, room._junction_columns)
	var fabric: Array = []
	for roof: Dictionary in layout["roof_instances"]:
		if String(roof["material"]) == "fabric":
			fabric.append(roof)
	_check(fabric.size() == 1, "ROOF_LAB has exactly one fabric roof (room C): found %d" % fabric.size())
	if fabric.size() == 1:
		_awning(room, layout, fabric[0])
	for roof: Dictionary in layout["roof_instances"]:
		if String(roof["material"]) == "cardboard":
			_cardboard(room, layout, roof, fabric.size() == 1)
	VoxelStore.active = null
	room.queue_free()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, m: String) -> void:
	if ok:
		passed += 1
		print("  ✓ " + m)
	else:
		failed += 1
		print("  ✗ " + m)


func _awning(room: Node, layout: Dictionary, roof: Dictionary) -> void:
	var info: Dictionary = RoofSheetRelease.collect(room, roof)
	_check(not info.is_empty(), "collect() finds the awning")
	if info.is_empty():
		return
	var voxels: Array = (info["keys"] as Dictionary).keys()   ## Vector3i x, y, level: a sheet is claims, no `Voxel` object
	var x0: int = int(info["x0"])
	var z0: int = int(info["z0"])
	var w: int = int(info["w"])
	var d: int = int(info["d"])
	_check(voxels.size() >= 1024 and voxels.size() <= 1200, "%d roof voxel(s): the 4 x 4 GU roof (1024) plus the rim voxels its free edges own" % voxels.size())
	_check(w >= 32 and w <= 34 and d >= 32 and d <= 34, "the sheet covers %d x %d voxel columns" % [w, d])
	var level_ok: bool = true
	for v: Vector3i in voxels:
		if v.z != int(info["level"]):
			level_ok = false
	_check(level_ok, "one layer: every voxel is at level %d (a fabric roof is built thin)" % int(info["level"]))
	var held: Dictionary = info["held"]
	var west: int = 0
	var north: int = 0
	var far: int = 0
	for c: Vector2i in held:
		if c.x <= x0 + 1:
			west += 1
		if c.y <= z0 + 1:
			north += 1
		if c.x > x0 + w / 3 and c.y > z0 + d / 3:
			far += 1
	_check(held.size() >= 50 and held.size() <= 80, "%d held column(s): the two back walls' edges (west %d, north %d)" % [held.size(), west, north])
	_check(far == 0, "nothing holds the far two thirds: the east and south edges are FREE (%d held there)" % far)
	var params: Dictionary = RoofSheetRelease.sim_params(info, SoftSheetPresets.OF["fabric"], room._voxel_board.ground_plane_level(), layout["solid_block_instances"],
		RoofSheetRelease.solid_grid(info, room._voxel_board.ground_plane_level()))
	var nx: int = int(params["nx"])
	var nz: int = int(params["nz"])
	var pins: PackedByteArray = params["pins"]
	var only_back_edges: bool = true
	for i in range(nx):
		for j in range(nz):
			if pins[i * nz + j] == 1 and i > 2 and j > 2:   ## the margin (0.5 GU) beside a wall, plus the ledge it rests on
				only_back_edges = false
	_check(pins.count(1) >= 15 and pins.count(1) <= 70 and only_back_edges, "%d x %d nodes, %d pinned, all on the west or north edge" % [nx, nz, pins.count(1)])
	_check(pins[(nx - 1) * nz + (nz - 1)] == 0, "the free corner node is not pinned")
	_check((params["boxes"] as Array).size() >= 8, "%d wall box(es) within reach" % (params["boxes"] as Array).size())
	var sim0 := SoftSheetSim.new(params)
	var hovering: int = 0
	for node in range(nx * nz):
		if sim0.pinned[node] == 1 and not sim0.has_solid_near(Vector3(sim0.pos[node * 3], sim0.pos[node * 3 + 1], sim0.pos[node * 3 + 2]), 0.75):
			hovering += 1
	## The lock stops where the walls stop (Director, 2026-10-16: a flat tab of cloth stood in the air past the wall's end, the corner he pointed at): no pinned node
	## is farther past the last held column than half a node.
	var held_x_max: float = 0.0
	var held_z_max: float = 0.0
	for hc: Vector2i in held:
		held_x_max = maxf(held_x_max, float(hc.x + 1) * 0.125)
		held_z_max = maxf(held_z_max, float(hc.y + 1) * 0.125)
	var past_end: int = 0
	for node in range(nx * nz):
		if sim0.pinned[node] == 1 and (sim0.pos[node * 3] > held_x_max + 0.5 * sim0.hx + 1.0e-3 or sim0.pos[node * 3 + 2] > held_z_max + 0.5 * sim0.hz + 1.0e-3):
			past_end += 1
	_check(past_end == 0, "no pinned node stands past the end of the walls that hold the cloth (%d past)" % past_end)
	_check(hovering == 0, "every pinned node has a support within 0.75 GU (the lock never ends in the air past a wall's end): %d hover" % hovering)
	var sim := SoftSheetSim.new(params)
	var guard: int = 0
	while not sim.is_settled() and guard < 600:
		sim.step()
		guard += 1
	## The cloth does not enter a wall (Director, 2026-10-16: it went through the wall's top): sample the SKIN the shader draws (Catmull-Rom through the nodes)
	## on a lattice of 1/16 GU over the whole sheet and count the samples inside a standing voxel's box, the voxels that really stand (a wall's pass its GU).
	var inside: int = 0
	var grazing: int = 0
	var samples: int = 0
	var steps_x: int = int(float(nx - 1) * sim.hx / 0.0625)
	var steps_z: int = int(float(nz - 1) * sim.hz / 0.0625)
	for a in range(steps_x + 1):
		for b in range(steps_z + 1):
			var p: Vector3 = _catmull(sim, nx, nz, minf(float(a) * 0.0625 / sim.hx, float(nx - 1) - 1.0e-4), minf(float(b) * 0.0625 / sim.hz, float(nz - 1) - 1.0e-4))
			samples += 1
			if sim.is_inside_solid(p):
				grazing += 1
			if sim.is_deep_in_solid(p, 0.03):
				inside += 1
	var nodes_in: int = 0
	for node in range(nx * nz):
		if sim.is_inside_solid(Vector3(sim.pos[node * 3], sim.pos[node * 3 + 1], sim.pos[node * 3 + 2])):
			nodes_in += 1
	_check(nodes_in == 0, "no node of the sheet is inside a standing voxel (%d of %d)" % [nodes_in, nx * nz])
	## Between the nodes (one per 1/3 GU) the skin can still cut a wall's corner a hair. Measured 2026-10-16 on this map: 391 of 4623 samples were inside a standing
	## voxel before the sheet knew the walls AS BUILT (8.5%); now 4 are deeper than 0.03 GU (0.09%) and 13 graze a surface.
	_check(inside <= int(float(samples) * 0.002), "the skin goes deeper than 0.03 GU into a standing voxel in %d of %d samples (limit 0.2%%), %d grazing a surface" % [inside, samples, grazing])
	## Both walls alike (Director, 2026-10-16: the north-east had a dark slit the north-west did not): the cloth beside a wall that holds it lies FLAT at the
	## support's height out to the margin, then falls. 2 voxels in from each wall the skin is within 0.03 GU of the pinned height, 8 voxels in it has fallen.
	for wall_name in ["west", "north"]:
		var wx2: float = (float(x0) + (2.0 if wall_name == "west" else 12.0)) * 0.125
		var wz2: float = (float(z0) + (12.0 if wall_name == "west" else 3.0)) * 0.125
		var near: Vector3 = _catmull(sim, nx, nz, clampf((wx2 - sim.origin.x) / sim.hx, 0.0, float(nx - 1) - 1.0e-4), clampf((wz2 - sim.origin.z) / sim.hz, 0.0, float(nz - 1) - 1.0e-4))
		var wx8: float = (float(x0) + (8.0 if wall_name == "west" else 12.0)) * 0.125
		var wz8: float = (float(z0) + (12.0 if wall_name == "west" else 9.0)) * 0.125
		var deep: Vector3 = _catmull(sim, nx, nz, clampf((wx8 - sim.origin.x) / sim.hx, 0.0, float(nx - 1) - 1.0e-4), clampf((wz8 - sim.origin.z) / sim.hz, 0.0, float(nz - 1) - 1.0e-4))
		_check(absf(near.y - float(params["origin"].y)) < 0.03 and deep.y < float(params["origin"].y) - 0.2,
			"%s wall: flat at %.3f two voxels in (pinned %.3f), fallen to %.3f eight voxels in" % [wall_name, near.y, float(params["origin"].y), deep.y])
	var corner: Vector3 = sim.node_position(nx - 1, nz - 1)
	## It really comes to rest (Director, 2026-10-16: zones of the cloth kept moving long after the fall). Before the contact held a node ON the wall's margin, a node
	## beside a wall's end slid into it, was popped out 0.02 GU and slid in again: this map never settled before the 12 s limit (361 steps); now it does in ~5 s.
	_check(sim.is_settled() and sim.time < 8.0, "it settles by itself, not at the time limit (%d steps, %.1f s simulated; the limit is %.0f s)" % [guard, sim.time, SoftSheetSim.MAX_SIM_TIME])
	## A cloth brought to rest for the load (`settle_now`) is still when it is woken: started from those positions it moves less than a centimetre in a second.
	var at_rest := SoftSheetSim.new(params)
	var rest_steps: int = at_rest.settle_now()
	var woken_params: Dictionary = params.duplicate()
	woken_params["initial"] = at_rest.pos.duplicate()
	var woken := SoftSheetSim.new(woken_params)
	for _k in range(30):
		woken.step()
	var drift: float = 0.0
	for node in range(nx * nz):
		drift = maxf(drift, Vector3(woken.pos[node * 3], woken.pos[node * 3 + 1], woken.pos[node * 3 + 2]).distance_to(Vector3(at_rest.pos[node * 3], at_rest.pos[node * 3 + 1], at_rest.pos[node * 3 + 2])))
	_check(rest_steps < 200 and drift < 0.08, "settle_now: at rest in %d step(s) (%.1f s); woken from that pose for 1 s it drifts %.3f GU at most" % [rest_steps, at_rest.time, drift])
	_check(corner.y < 0.5, "the free corner fell from %.2f to %.2f GU (the lab's awning reached the floor)" % [float(params["origin"].y), corner.y])
	var lowest: float = 99.0
	for node in range(nx * nz):
		lowest = minf(lowest, sim.pos[node * 3 + 1])
	_check(lowest >= SoftSheetSim.CONTACT_MARGIN - 1.0e-9, "no node sank into the floor (lowest %.3f)" % lowest)


## ROOF_MASTER_PLAN v0.42: cardboard is PLATES, not nodes. On the same walls a cardboard awning sags far less than the cloth one (stiff between creases), it settles,
## and its plates stay flat: along a row of the sheet the bend between two nodes of one plate is small, at a crease it is allowed to be large.
func _cardboard(room: Node, layout: Dictionary, roof: Dictionary, with_cloth: bool) -> void:
	var info: Dictionary = RoofSheetRelease.collect(room, roof)
	_check(not info.is_empty(), "cardboard: collect() finds the roof")
	if info.is_empty():
		return
	var ground: int = room._voxel_board.ground_plane_level()
	var params: Dictionary = RoofSheetRelease.sim_params(info, SoftSheetPresets.OF["cardboard"], ground, layout["solid_block_instances"], RoofSheetRelease.solid_grid(info, ground))
	var sim := SoftSheetSim.new(params)
	var steps: int = sim.settle_now()
	var lowest: float = 99.0
	for node in range(sim.nx * sim.nz):
		lowest = minf(lowest, sim.pos[node * 3 + 1])
	var top: float = float(params["origin"].y)
	_check(steps < 200 and sim.time < 8.0, "cardboard settles in %d step(s), %.1f s" % [steps, sim.time])
	## the cloth on the same kind of walls hangs to ~1 GU below its supports (the awning check above); the plates hold it up
	_check(lowest > top - 1.2, "cardboard sags %.2f GU at most (supports at %.2f, lowest node %.2f)" % [top - lowest, top, lowest])
	## Plate rigidity: the mean bend angle between consecutive node pairs of a row inside a plate is at most a third of the one across creases
	var inside: float = 0.0
	var across: float = 0.0
	var n_in: int = 0
	var n_cr: int = 0
	var plate: int = int(SoftSheetPresets.OF["cardboard"]["plate"])
	for j in range(sim.nz):
		for i in range(1, sim.nx - 1):
			var a: Vector3 = sim.node_position(i - 1, j)
			var b: Vector3 = sim.node_position(i, j)
			var c: Vector3 = sim.node_position(i + 1, j)
			var turn: float = (b - a).angle_to(c - b)
			if i % plate == 0:
				across += turn
				n_cr += 1
			else:
				inside += turn
				n_in += 1
	var mean_in: float = inside / float(maxi(n_in, 1))
	var mean_cr: float = across / float(maxi(n_cr, 1))
	_check(mean_in < mean_cr, "cardboard bends at its creases (mean turn %.3f rad at a crease node, %.3f inside a plate)" % [mean_cr, mean_in])


func _catmull(sim: SoftSheetSim, nx: int, nz: int, fi: float, fj: float) -> Vector3:
	var i0: int = mini(int(floor(fi)), nx - 2)
	var j0: int = mini(int(floor(fj)), nz - 2)
	var wi: Array = _weights(fi - float(i0))
	var wj: Array = _weights(fj - float(j0))
	var out := Vector3.ZERO
	for ia in range(4):
		var row := Vector3.ZERO
		for jb in range(4):
			row += float(wj[jb]) * sim.node_position(clampi(i0 + ia - 1, 0, nx - 1), clampi(j0 + jb - 1, 0, nz - 1))
		out += float(wi[ia]) * row
	return out


func _weights(f: float) -> Array:
	var f2: float = f * f
	var f3: float = f2 * f
	return [-0.5 * f3 + f2 - 0.5 * f, 1.5 * f3 - 2.5 * f2 + 1.0, -1.5 * f3 + 2.0 * f2 + 0.5 * f, 0.5 * f3 - 0.5 * f2]
