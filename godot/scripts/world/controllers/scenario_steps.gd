## ScenarioSteps — the scenario runner's ops that act on the room (`scenario_<op>()`), out of `room.gd`
## (HERITAGE T3, 2026-11-11). Dev tooling: created on first use by `Room.scenario_steps()`, never in play.
## `ScenarioRunner` calls these by name (`"scenario_" + op`); each returns whether its step completed and
## reaches the room's state through `room`, the way the other controllers do.
extends Node

const BoardProbeClass = preload("res://godot/scripts/systems/board_probe.gd")
const FluidPlaneRef = preload("res://godot/scripts/systems/fluid_plane.gd")  ## M6: the gameplay truth of a body of liquid
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer
const LiquidRegistryRef = preload("res://godot/scripts/systems/liquid_registry.gd")  ## M6: the liquids a map may place
const LiquidSheet3DRef = preload("res://godot/scripts/geometry/liquid_sheet3d.gd")  ## M6: the sheet of one body of liquid
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

## The room this drives (set by `setup()`).
var room: Node = null


func setup(p_room: Node) -> void:
	room = p_room


## R3D-11 — the `ground_check` scenario step: what gameplay reads of the ground, as digests, plus an in-process
## comparison of the two authorities over every cell of the map and a 3-cell margin (meaningful on the 2D board, whose floor
## layer still holds the tiles). `tools/persistent/ground_gate.py` runs it on the 3D and the 2D board and requires every
## digest to agree.
func scenario_ground_check(label: String) -> bool:
	if room._room_size == Vector2i.ZERO:
		push_error("[Room] scenario_ground_check: no floor")
		return false
	var size: Vector2i = room._room_size
	var walk_rows: PackedStringArray = []
	var select_rows: PackedStringArray = []
	for y in range(-3, size.y + 3):
		for x in range(-3, size.x + 3):
			var c := Vector2i(x, y)
			var grid: bool = GroundGridRef.has_cell(c, size)
			walk_rows.append("%d,%d=%d" % [x, y, 1 if grid else 0])
			select_rows.append("%d,%d=%d" % [x, y, 1 if room._selection_controller.is_selectable_cell(c) else 0])
	var costs: Dictionary = room.movement_overlay._costs
	var cost_rows: PackedStringArray = []
	for c: Vector2i in costs:
		cost_rows.append("%d,%d=%d" % [c.x, c.y, int(costs[c])])
	cost_rows.sort()
	var path_rows: PackedStringArray = []
	var reach: Array = costs.keys()
	reach.sort()
	for i in range(0, reach.size(), 7):
		var path: Array[Vector2i] = room.movement_overlay.build_path_to(reach[i])
		path_rows.append("%s:%s" % [reach[i], path])
	var counts: Dictionary = room.view_context()
	print("[GROUND-CHECK] %s size %s | walk %s select %s reach %d %s paths %d %s | view %s/%s"
		% [label, size,
			"\n".join(walk_rows).md5_text(), "\n".join(select_rows).md5_text(), cost_rows.size(),
			"\n".join(cost_rows).md5_text(), path_rows.size(), "\n".join(path_rows).md5_text(),
			counts.get("gu_visible", "?"), counts.get("gu_total", "?")])
	return true


## The `world_check` scenario step: the two things every overlay that draws in the air stands on, measured in the CURRENT
## view. (1) `WorldCanvas3D.lift()` of fixed cell points at a fixed height: world state, so its digest must be the same in
## every view. (2) `screen_axes()`, the pixels one grid step moves by, against what the live camera really does to the
## same step: direction (cosine) and scale (the viewport pixels per canvas pixel, i.e. the zoom) for each axis.
## Prints `[WORLD-CHECK] <name> view=<V> lift=<digest> ax=<x,y> ay=<x,y> cos_x=<c> cos_y=<c> zoom_x=<z> zoom_y=<z>`.
func scenario_world_check(label: String) -> bool:
	var live: Node = room.board3d()
	if live == null:
		push_error("[Room] scenario_world_check: no 3D board")
		return false
	var canvas := WorldCanvas3D.new()
	canvas.attach(live, room, 0)
	canvas.begin()
	var rows: Array = []
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(7, 4), Vector2i(12, 9), Vector2i(20, 5), Vector2i(2, 11)]:
		var floor_2d: Vector2 = room._world_center_for_cell(cell)
		var p: Vector3 = canvas.lift(floor_2d + Vector2(0.0, -40.0), floor_2d)
		rows.append([roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)])
	var axes: Array[Vector2] = canvas.screen_axes()
	canvas.detach()
	## What the camera does to one grid step along x and along y, from the cell (5, 5).
	var origin: Vector2 = live.call("screen_of_world", Vector3(5.5, 0.0, 5.5))
	var step_x: Vector2 = (live.call("screen_of_world", Vector3(6.5, 0.0, 5.5)) as Vector2) - origin
	var step_y: Vector2 = (live.call("screen_of_world", Vector3(5.5, 0.0, 6.5)) as Vector2) - origin
	var cos_x: float = axes[0].normalized().dot(step_x.normalized())
	var cos_y: float = axes[1].normalized().dot(step_y.normalized())
	print("[WORLD-CHECK] %s view=%s lift=%d ax=%.1f,%.1f ay=%.1f,%.1f cos_x=%.5f cos_y=%.5f zoom_x=%.4f zoom_y=%.4f"
		% [label, room._view_direction, hash(rows), axes[0].x, axes[0].y, axes[1].x, axes[1].y, cos_x, cos_y,
			step_x.length() / maxf(axes[0].length(), 1e-6), step_y.length() / maxf(axes[1].length(), 1e-6)])
	return true


## The `pick_check` scenario step: in the CURRENT view, every on-screen cell's centre goes through the real pick
## (`_screen_to_tile()`, what a touch reaches) and must come back as that cell. A cell a standing prop covers on screen
## picks the prop's cell instead (`pick_cell()` asks the prop boxes first, on purpose): counted apart, never a failure.
## Prints `[PICK-CHECK] <name> view=<N|E|S|W> cells=<n> ok=<a> covered=<b> bad=<c> offscreen=<d>`.
func scenario_pick_check(label: String) -> bool:
	var live: Node = room.board3d()
	if live == null or room._voxel_board == null:
		push_error("[Room] scenario_pick_check: no 3D board")
		return false
	var standing: Dictionary = {}
	for block: PropBlock in room._voxel_board.prop_blocks():
		if not block.voxels.is_empty():
			var first: Vector2i = block.voxels[0].grid_pos
			standing[Vector2i(first.x >> 3, first.y >> 3)] = true
	for inst: MeshPropInstance in room._voxel_board.mesh_props():
		if not inst.shattered:
			standing[inst.cell] = true
	var area: Rect2 = room.get_viewport().get_visible_rect().grow(-4.0)
	var ok: int = 0
	var covered: int = 0
	var bad: int = 0
	var offscreen: int = 0
	var shown: int = 0
	for x in range(room._room_size.x):
		for y in range(room._room_size.y):
			var cell := Vector2i(x, y)
			var at: Vector2 = live.call("cell_screen_center", cell)
			if not area.has_point(at):
				offscreen += 1
				continue
			var picked: Vector2i = room._screen_to_tile(at)
			if picked == cell:
				ok += 1
			elif standing.has(picked):
				covered += 1
			else:
				bad += 1
				if shown < 5:
					shown += 1
					print("[PICK-CHECK] %s: cell %s at %s picked %s" % [label, cell, at, picked])
	print("[PICK-CHECK] %s view=%s cells=%d ok=%d covered=%d bad=%d offscreen=%d"
		% [label, room._view_direction, room._room_size.x * room._room_size.y, ok, covered, bad, offscreen])
	return true


## R3D-8 — the `mirror_check` scenario step: the 3D board's twins of what the 2D renderer creates. Cracks: one twin per
## live crack record. Piles: what the 3D board draws equals the live piles. `tools/persistent/mirror_gate.py` reads the line.
func scenario_mirror_check(label: String) -> bool:
	var board: Node = room.board3d()
	if board == null or room._voxel_board == null:
		push_error("[Room] scenario_mirror_check: no 3D board")
		return false
	var records: int = 0
	for rec: Dictionary in room._voxel_board.glass_crack_records():
		if rec.has("params"):
			records += 1
	var mirror: Node = board.get("_crack_mirror")
	var twins: int = int(mirror.call("twin_count")) if mirror != null else -1
	print("[MIRROR-CHECK] %s cracks records=%d twins=%d piles base=%d sprites=%d drawn=%d"
		% [label, records, twins, room._base_shards.size(), room._voxel_board.floor_shard_pile_count(),
			room._voxel_board.floor_shard_pile3d_count()])
	return true


## RENDER3D R3D-0 — the `probe` scenario step: a `BoardProbe` dump of every voxel
## container and every cell plane, written to `path`. Returns the summary, or `{}`
## after the error is reported. Reads the simulation's own record, never a tile, so it
## judges both boards and outlives the 2D one.
func scenario_board_probe(path: String, label: String) -> Dictionary:
	if room._voxel_board == null or room._edge_registry == null or room._slab_registry == null:
		push_error("[Room] scenario_board_probe: the board is not built (renderer %s, edges %s, slabs %s)"
			% [room._voxel_board != null, room._edge_registry != null, room._slab_registry != null])
		return {}
	var planes: Dictionary = {}
	for level: Variant in room._voxel_board.cell_plane_levels():
		planes[level] = room._voxel_board.cell_plane_image(int(level))
	var meta: Dictionary = {
		"map": room._dev_flag("MAP", "default"),
		"perspective": "N",  ## the layout's orientation, fixed since R3D-ROT (the camera's side is not board state)
		"world_revision": room._world_revision,
		"board3d": room.board3d() != null,
	}
	var summary: Dictionary = BoardProbeClass.write(path, label, room._edge_registry, room._slab_registry,
		room._junction_columns, planes, VoxelBoard.plane_origin(), meta, room._voxel_board.prop_blocks())
	if summary.is_empty():
		return {}
	print("[BOARD-PROBE] %s — %d voxel(s) in %d container(s) (slice %d, column %d, slab %d), %d plane level(s), %d material(s), %.1f MB, %.0f ms → %s"
		% [label, summary["voxels"], summary["containers"], summary["slice_voxels"],
		summary["column_voxels"], summary["slab_voxels"], summary["levels"],
		summary["materials"], float(summary["bytes"]) / 1048576.0, summary["ms"], path])
	Telemetry.event("board.probe", summary)
	return summary


## RENDER3D R3D-1b — `scenario_board_probe()`, read from the shadow store instead of the
## objects, in the same format, so `board_probe.py diff` compares the two directly. The
## planes are the renderer's, as in the objects' dump.
func scenario_board_probe_store(path: String, label: String) -> Dictionary:
	var store: VoxelStore = VoxelStore.active
	if store == null or room._voxel_board == null:
		push_error("[Room] scenario_board_probe_store: no active store or no renderer")
		return {}
	var planes: Dictionary = {}
	for level: Variant in room._voxel_board.cell_plane_levels():
		planes[level] = room._voxel_board.cell_plane_image(int(level))
	var meta: Dictionary = {
		"map": room._dev_flag("MAP", "default"),
		"perspective": "N",  ## the layout's orientation, fixed since R3D-ROT (the camera's side is not board state)
		"world_revision": room._world_revision,
		"board3d": room.board3d() != null,
		"source": "store",
	}
	var summary: Dictionary = BoardProbeClass.write_store(path, label, store, planes,
		VoxelBoard.plane_origin(), meta)
	if summary.is_empty():
		return {}
	var mismatches: int = store.grid_mismatches()
	print("[BOARD-PROBE] %s (store) — %d voxel(s) in %d container(s), %.0f ms → %s"
		% [label, summary["voxels"], summary["containers"], summary["ms"], path])
	print("[VOXEL-STORE] %s — grid mismatches %d, writes mirrored %d, unknown container %d, misplaced %d"
		% [label, mismatches, store.writes_mirrored, store.writes_unknown_container,
		store.writes_misplaced])
	if mismatches != 0 or store.writes_unknown_container != 0 or store.writes_misplaced != 0:
		push_error("[Room] the shadow store has drifted at '%s': grid mismatches %d, unknown-container writes %d, misplaced writes %d"
			% [label, mismatches, store.writes_unknown_container, store.writes_misplaced])
	return summary


## RENDER3D R3D-1c step 4 instrument — `PassageQuery.passage_class()` for EVERY edge,
## printed as a per-class count and an MD5 over the sorted "edge_key=class" lines, so two
## runs (store vs objects) compare in one line. `BoardProbe` cannot see a passage.
func scenario_passages(label: String) -> bool:
	if room._edge_registry == null:
		push_error("[Room] scenario_passages: no edge registry")
		return false
	var lines: PackedStringArray = []
	var tally: Dictionary = {}
	for edge in room._edge_registry.all_edges():
		var pc: String = PassageQuery.class_name_of(PassageQuery.passage_class(edge, room._edge_registry))
		tally[pc] = int(tally.get(pc, 0)) + 1
		lines.append("%s=%s" % [edge.id, pc])
	lines.sort()
	print("[PASSAGES] %s — %d edge(s) %s digest %s"
		% [label, lines.size(), tally, "\n".join(lines).md5_text()])
	return true


func scenario_occ_bench(a: Vector2i, b: Vector2i, reps: int) -> void:
	var sets: Array[float] = []
	var paints2d: Array[float] = []
	var paints3d: Array[float] = []
	var refreshes: Array[float] = []
	var frames: Array[float] = []
	var cells: Array[int] = []
	var digest: int = 0
	var wire_digest: int = 0
	var phases: Array = [[], [], [], [], []]
	var tails: Array = [[], [], [], [], []]
	var live: Node = room.board3d()
	room._occlusion_set.memo_enabled = false  ## the first pass measures the path that recomputes every step
	var cut_phases: Array = [[], [], [], [], [], [], []]
	var geo_digest: int = 0
	var canon_digest: int = 0
	var canon_geo: int = 0
	if live != null:
		live.occ_digest_on = true
	for i: int in range(reps):
		room.agent.set_cell(a if i % 2 == 0 else b)
		var t0: int = Time.get_ticks_usec()
		room._recompute_occlusion()
		var step_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		sets.append(float(room._occ_last_usec[0]) / 1000.0)
		## Digests are read AFTER the step's own time is taken: building the full per-column set is not part of the step.
		var occluded: Dictionary = room._occlusion_set.get_occluded_cells()
		cells.append(occluded.size())
		digest = hash([digest, str(occluded)])
		canon_digest = hash([canon_digest, room._canonical_set_digest(occluded)])
		wire_digest = hash([wire_digest, str(room._occlusion_set.get_wireframe_by_level())])
		for k: int in range(5):
			(phases[k] as Array).append(float(room._occlusion_set.last_phase_usec[k]) / 1000.0)
			(tails[k] as Array).append(float(room._occlusion_set.last_tail_usec[k]) / 1000.0)
		if live != null:
			live.finish_occ_digests()
			geo_digest = hash([geo_digest, live.last_occ_digest])
			canon_geo = hash([canon_geo, live.last_occ_canon])
			for k: int in range(7):
				(cut_phases[k] as Array).append(float(live.last_occ_usec[k]) / 1000.0)
		paints2d.append(float(room._occ_last_usec[1]) / 1000.0)
		paints3d.append(float(room._occ_last_usec[2]) / 1000.0)
		refreshes.append(float(room._occ_last_usec[3]) / 1000.0)
		var frame_t0: int = Time.get_ticks_usec()
		await room.get_tree().process_frame
		frames.append(step_ms + float(Time.get_ticks_usec() - frame_t0) / 1000.0)
	print("[OCC-BENCH] occluded columns per step: min %d, max %d, digest %d, wireframe digest %d" % [cells.min(), cells.max(), digest, wire_digest])
	print("[OCC-BENCH] canonical set digest %d" % canon_digest)
	## The revealed roofs, view-independent by design (stored per GU, opened by slab adjacency): `roof_yaw_gate.py` holds this
	## line equal across the four views.
	var roof_gus: Dictionary = room._occlusion_set.get_roof_gus()
	var roof_rows: Array = []
	for gu: Vector2i in roof_gus:
		var entry: Dictionary = roof_gus[gu]
		roof_rows.append([gu.x, gu.y, int(entry["min_level"]), int(entry["max_level"]), int(entry["ring"])])
	roof_rows.sort()
	print("[OCC-BENCH] canonical roof digest %d, %d roof GU(s) open" % [hash(roof_rows), roof_rows.size()])
	var tail_names: PackedStringArray = ["roof borders + merge", "set compare", "(unused)", "exposure (per GU)", "wireframe lines"]
	for k: int in range(5):
		var tail_total: float = 0.0
		for v: float in tails[k]:
			tail_total += v
		print("[OCC-BENCH]     tail %s: mean %.2f ms" % [tail_names[k], tail_total / float(reps)])
	var phase_names: PackedStringArray = ["group slices", "edge occlusion", "expand to columns", "roof", "wireframe"]
	for k: int in range(5):
		var total_ms: float = 0.0
		for v: float in phases[k]:
			total_ms += v
		print("[OCC-BENCH]   phase %s: mean %.2f ms, max %.2f ms" % [phase_names[k], total_ms / float(reps), (phases[k] as Array).max()])
	if live != null:
		print("[OCC-BENCH] cutaway geometry digest %d, canonical %d" % [geo_digest, canon_geo])
		var cut_names: PackedStringArray = ["texture+uniforms", "outline edges", "side fills", "caps+rims", "merge", "segment ray march", "mesh build"]
		for k: int in range(7):
			var cut_total: float = 0.0
			for v: float in cut_phases[k]:
				cut_total += v
			print("[OCC-BENCH]   cutaway %s: mean %.2f ms, max %.2f ms" % [cut_names[k], cut_total / float(reps), (cut_phases[k] as Array).max()])
	## Second pass, memo on: the same steps again (the agent or the hover returning to cells it has seen).
	room._occlusion_set.memo_enabled = true
	var memo_digest: int = 0
	var memo_ms: Array[float] = []
	for i: int in range(reps):
		room.agent.set_cell(a if i % 2 == 0 else b)
		room._recompute_occlusion()
		memo_ms.append(float(room._occ_last_usec[0]) / 1000.0)
		memo_digest = hash([memo_digest, str(room._occlusion_set.get_occluded_cells())])
		await room.get_tree().process_frame
	var memo_total: float = 0.0
	for v: float in memo_ms:
		memo_total += v
	print("[OCC-BENCH] memoised set recompute: mean %.2f ms, max %.2f ms, digest %d (%s the reference pass)" % [
		memo_total / float(reps), memo_ms.max(), memo_digest, "==" if memo_digest == digest else "DIFFERS FROM"])
	for row: Array in [["set recompute", sets], ["2D ghost apply", paints2d], ["3D cutaway (on_occlusion)", paints3d], ["2D overlay refresh", refreshes], ["step incl. next frame", frames]]:
		var values: Array[float] = row[1]
		var total: float = 0.0
		for v: float in values:
			total += v
		print("[OCC-BENCH] %s: mean %.2f ms, max %.2f ms over %d" % [row[0], total / float(values.size()), values.max(), values.size()])


func scenario_shoot(index: int) -> bool:
	if room._agent_shot_controller == null or index < 0 or index >= room._guards.size():
		push_error("[Room] scenario_shoot: no shot controller or no guard #%d (%d on the map)"
			% [index, room._guards.size()])
		return false
	var agent_xy: PackedStringArray = room._dev_flag("SHOT_AGENT_CELL", "").split(",")
	if agent_xy.size() == 2 and agent_xy[0].is_valid_int() and agent_xy[1].is_valid_int():
		room.agent.set_cell(Vector2i(agent_xy[0].to_int(), agent_xy[1].to_int()))
	var guard_xy: PackedStringArray = room._dev_flag("SHOT_GUARD_CELL", "").split(",")
	if guard_xy.size() == 2 and guard_xy[0].is_valid_int() and guard_xy[1].is_valid_int():
		var guard = room._guards[index]
		guard.cell = Vector2i(guard_xy[0].to_int(), guard_xy[1].to_int())
		guard.position = guard._cell_to_world(guard.cell)
	room._agent_shot_controller.open_menu_for(index)
	for _f in range(10):
		await room.get_tree().process_frame
	room._agent_shot_controller.fire_at_active()
	var waited: int = 0
	while (room._destruction_render_busy or room.is_resolving_action()) and waited < 1800:
		await room.get_tree().process_frame
		waited += 1
	## `SHOT_SETTLE_FRAMES` (default 30): a capture of the impact's own sparks and smoke needs a few frames, not
	## thirty, because they are gone by then (R3D-7 sparks check).
	for _f in range(room._dev_flag_num("SHOT_SETTLE_FRAMES", 30)):
		await room.get_tree().process_frame
	return waited < 1800


## Scenario step `weapon <id>`: the agent's firearm, as the number keys choose it (`AgentShotController.set_weapon`).
func scenario_weapon(weapon_id: String) -> bool:
	if room._agent_shot_controller == null:
		push_error("[Room] scenario_weapon: no shot controller")
		return false
	room._agent_shot_controller.set_weapon(weapon_id)
	return true


## Scenario step `shot_aim <guard>`: the aim of `scenario_shoot` WITHOUT the trigger: the agent turns toward the guard and raises his
## weapon (the menu opens on the target). `shot_cancel` puts it down again.
func scenario_shot_aim(index: int) -> bool:
	if room._agent_shot_controller == null or index < 0 or index >= room._guards.size():
		push_error("[Room] scenario_shot_aim: no shot controller or no guard #%d (%d on the map)" % [index, room._guards.size()])
		return false
	room._agent_shot_controller.open_menu_for(index)
	return true


func scenario_shot_cancel() -> bool:
	if room._agent_shot_controller == null:
		push_error("[Room] scenario_shot_cancel: no shot controller")
		return false
	room._agent_shot_controller.cancel_active()
	return true


## Scenario step `decal_wall <material> <gx,gy>` (R3D-LOOK L1): every damage decal of a material shown at once on one
## wall, for a static look judgement. Writes the real damage tuples through the store (no round, no blast, no soot) and
## hands the touched voxels to the board, so the marks are drawn by the shipped shader. Rows, from the bottom: a round's
## CRACKED mark, a round's DENTED recess, a blast's CRACKED, a blast's DENTED; columns: the three variants. A mark is one
## voxel big, so the twelve sit two voxels apart inside the GU's column, on the SW face (+y) of the outermost wall layer.
func scenario_decal_wall(material_id: String, gu: Vector2i) -> bool:
	var store: VoxelStore = VoxelStore.active
	var live: Node = room.board3d()
	if store == null or live == null or room._voxel_board == null:
		push_error("[Room] scenario_decal_wall: no active store or no 3D board")
		return false
	var base_level: int = room._voxel_board.ground_plane_level()
	var face_y: int = -1  ## the largest y holding an intact, visible voxel of the material with an open SW face
	for x: int in range(gu.x * 8, gu.x * 8 + 8):
		for y: int in range(gu.y * 8 - 4, gu.y * 8 + 12):
			var claim: int = store.owner[store.cell_index(x, y, base_level)]
			if claim >= 0 and y > face_y and not store.has_cell(x, y + 1, base_level) \
					and store.material_ids[store.mat[claim]] == material_id:
				face_y = y
	if face_y == -1:
		push_error("[Room] scenario_decal_wall: no %s wall face in the GU column of %s" % [material_id, gu])
		return false
	var rows: Array = [
		[Voxel.DamageState.CRACKED, false], [Voxel.DamageState.DENTED, false],
		[Voxel.DamageState.CRACKED, true], [Voxel.DamageState.DENTED, true]]
	var touched: Array = []
	for r: int in range(rows.size()):
		for v: int in range(3):
			var claim: int = store.owner[store.cell_index(gu.x * 8 + 1 + v * 2, face_y, base_level + r * 2)]
			if claim >= 0 and store.set_damage(claim, int(rows[r][0]), bool(rows[r][1]), Voxel.CarvedSide.LEFT, v, 0):
				touched.append(store.voxel_of(claim))
	print("[DECAL-WALL] %s: %d marks on y=%d" % [material_id, touched.size(), face_y])
	live.call("on_shot_commit", touched)
	for _f in range(20):
		await room.get_tree().process_frame
	return not touched.is_empty()


## F2's map reload: the same `load_map()` the debug panel calls, on the current map.
func scenario_reload() -> bool:
	room.load_map(room.map_id)
	for _f in range(10):
		await room.get_tree().process_frame
	return room._edge_registry != null


## SAVE-01's round trip. No production load flow exists yet (SaveState is plumbing), so
## this takes the one a rotation already runs: capture, a fresh `load_map()` (which clears
## the run state), `SaveState.restore()`, then `_reapply_base_damage()` to stamp the
## restored records back onto the rebuilt voxels.
func scenario_save_restore() -> bool:
	var data: Dictionary = SaveState.capture(room)
	room.load_map(room.map_id)
	if not SaveState.restore(room, data):
		return false
	## A recorded hole's opening is claimed BEFORE the replay flushes, or every hole is cut with the default opening.
	room._claim_base_openings()
	room._reapply_base_damage()
	var gone: Array = []
	for _b: PropBlock in room._voxel_board.prop_blocks():
		for _v: Voxel in _b.voxels:
			if _v.damage_state == Voxel.DamageState.DESTROYED:
				gone.append(_v)
	if not gone.is_empty() and room.board3d() != null:
		room.board3d().on_shot_commit(gone)
	room._reapply_base_shattered_props()
	room._release_destroyed_prop_cells()
	room.rebuild_soft_sheets()   ## the cloths were built from the undamaged map `load_map` made: a replay that destroyed a stall's voxels must take its cloth with it
	## (A rotation no longer relights: R3D-ROT.) This restore relights after its replay, and
	## `_reapply_base_damage()` says it must run BEFORE the light-field repaint. Without this the restored world was
	## lit as the undamaged map: 560 intact floor voxels beside PLAYGROUND's two blasts read bucket 3 where the
	## world they stand in gives 6-9 (R3D-13). A production load flow has to do the same.
	room._lighting_controller.rebuild_all()
	room._respawn_base_debris()
	room._respawn_base_prop_piles()
	for _f in range(10):
		await room.get_tree().process_frame
	return true


## Scenario step `view_mode`: flip one analysis aid through the toggles the HUD and the F-keys reach. Ten frames
## follow so the overlay has drawn when the next step captures.
func scenario_view_mode(mode: String) -> bool:
	match mode:
		"numbers":
			room._on_hud_numbers_toggled()
		"ruler":
			room._debug_tools_controller.toggle_voxel_ruler_overlay()
		"dev", "light", "heat":
			room._set_view_mode(mode)
		"layout":
			room.toggle_layout_overlay(room._dev_flag("LAYOUT_RAIL", ""))
		_:
			push_error("[Room] scenario_view_mode: '%s' is not dev, light, heat, numbers, ruler or layout" % mode)
			return false
	for _f in range(10):
		await room.get_tree().process_frame
	return true


## A perspective rotation, through `_set_perspective()` — the camera's yaw
## `_capture_all_four_views()` runs, without its captures into Screenshots/history.
func scenario_perspective(direction: String) -> bool:
	if not PerspectiveMapperClass.is_valid_direction(direction):
		push_error("[Room] scenario_perspective: '%s' is not N, E, S or W" % direction)
		return false
	room._set_perspective(direction)
	for _f in range(10):
		await room.get_tree().process_frame
	return room._view_direction == direction


func scenario_skylight_hit() -> bool:
	room._ensure_glass_index()
	var ids: Array = []
	for pid: String in room._glass_pane_slices:
		if pid.begins_with("PANE_SKY_"):
			ids.append(pid)
	if ids.is_empty():
		push_error("[Room] skylight_hit: this map has no skylight")
		return false
	ids.sort()
	var hosts: Array = room._glass_pane_slices[ids[0]]
	var sum := Vector2.ZERO
	var n: int = 0
	for h in hosts:
		var packed: PackedInt32Array = h.cells_packed()
		for o in range(0, packed.size(), 3):
			sum += Vector2(float(packed[o]) + 0.5, float(packed[o + 1]) + 0.5)
			n += 1
	if n == 0:
		return false
	var centre: Vector2 = sum / float(n)
	var gone: Array = []
	var keep: Voxel = null
	for h in hosts:
		for v: Voxel in h.voxels:
			if Vector2(float(v.grid_pos.x) + 0.5, float(v.grid_pos.y) + 0.5).distance_to(centre) <= room.SKYLIGHT_HIT_RADIUS:
				v.set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.BOTTOM, 0, 0)
				room.record_voxel_damage_to_base(v.grid_pos, v.level, v.damage_state, v.damage_is_blast, v.damage_carved_side,
					v.damage_variant, v.damage_substrate, v)
				gone.append(v)
			elif keep == null:
				keep = v
	await room._voxel_board.process_dirty_slabs_async(room._slab_registry)
	var craze_id: int = 0
	if keep != null:
		craze_id = room.claim_glass_craze(keep.grid_pos, keep.level, 0.6)
	room._voxel_board.refresh_glass_crack_occupancy()
	var shaped: int = room._voxel_board.refresh_glass_rims()
	room._voxel_board.refresh_craze_opening_masks()
	var live: Node = room.board3d()
	if live != null:
		live.on_shot_commit(gone)
	room.bump_world_revision()
	print_debug("[SKYLIGHT-HIT] pane %s: %d voxel(s) destroyed round (%.1f, %.1f), craze %d, %d cell(s) shaped by the opening"
		% [ids[0], gone.size(), centre.x, centre.y, craze_id, shaped])
	return true


## RF-G G3 audit: every standing voxel of the store asked; an intact map has none without support (a count above 0 names a material the reach table is too strict for).
func scenario_struct_audit() -> bool:
	var store: VoxelStore = VoxelStore.active
	if store == null or room._voxel_board == null:
		push_error("[Room] struct_audit: no store or board")
		return false
	var grid: ClaimGrid = ClaimGrid.of_store(store)
	room._fill_anchored(grid)
	var seeds: Array = []
	var seen: Dictionary = {}
	for claim: int in range(store.claims):
		var k := Vector3i(store.xyz[claim * 3], store.xyz[claim * 3 + 1], store.xyz[claim * 3 + 2])
		if not seen.has(k):
			seen[k] = true
			seeds.append(k)
	var standing: Dictionary = {}   ## material -> [count, highest level]
	for k: Vector3i in seeds:
		var m: Variant = grid.standing_material(k)
		if m != null:
			var row: Array = standing.get(String(m), [0, 0])
			row[0] += 1
			row[1] = maxi(int(row[1]), k.z)
			standing[String(m)] = row
	var t0: int = Time.get_ticks_usec()
	var loose: Dictionary = StructuralSupport.unsupported(grid, room._voxel_board.ground_plane_level(), seeds, {}, false, 1 << 30)   ## the whole map: no cap
	var by_material: Dictionary = {}
	var lo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var hi := Vector3i(-(1 << 30), -(1 << 30), -(1 << 30))
	for k: Vector3i in loose:
		var m: String = grid.material_at(k)
		by_material[m] = int(by_material.get(m, 0)) + 1
		lo = Vector3i(mini(lo.x, k.x), mini(lo.y, k.y), mini(lo.z, k.z))
		hi = Vector3i(maxi(hi.x, k.x), maxi(hi.y, k.y), maxi(hi.z, k.z))
	if not loose.is_empty():
		var probe: Vector3i = loose.keys()[loose.size() / 2]
		var col: String = ""
		for lv in range(room._voxel_board.ground_plane_level(), probe.z + 2):
			var mm: Variant = grid.standing_material(Vector3i(probe.x, probe.y, lv))
			col += "." if mm == null else str(mm).substr(0, 1)
		print("[STRUCT-AUDIT] a loose voxel at %s: its column from the ground up: %s" % [str(probe), col])
		print("[STRUCT-AUDIT] the loose voxels span x %d..%d, y %d..%d, level %d..%d" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	print("[STRUCT-AUDIT] %d voxel(s) asked, %d with no support %s (%.1f ms); standing by material [count, highest level] %s" % [seeds.size(), loose.size(), str(by_material), float(Time.get_ticks_usec() - t0) / 1000.0, str(standing)])
	return true


## RF-G G3 bench: `STRUCT_CUT=<material>,<levels>` destroys the lowest `levels` levels above the ground of EVERY voxel of that material (a wall with its foot gone), through the
## same commit a blast's damage takes, then asks the support service about it like any event: what hangs over the cut must fall. A dev tool: it is how G3 is seen on a real map.
func scenario_struct_cut() -> bool:
	var spec: PackedStringArray = str(room._dev_flag("STRUCT_CUT", "")).split(",")
	var store: VoxelStore = VoxelStore.active
	if spec.size() != 2 or store == null or room._voxel_board == null:
		push_error("[Room] struct_cut: set STRUCT_CUT=<material>,<levels> and have a board")
		return false
	var ground: int = room._voxel_board.ground_plane_level()
	var grid: ClaimGrid = ClaimGrid.of_store(store)
	var cut: Array = []
	var seen: Dictionary = {}
	for claim: int in range(store.claims):
		var k := Vector3i(store.xyz[claim * 3], store.xyz[claim * 3 + 1], store.xyz[claim * 3 + 2])
		if seen.has(k) or k.z < ground or k.z >= ground + int(spec[1]) or grid.material_at(k) != spec[0] or grid.damage_at(k) == Voxel.DamageState.DESTROYED:
			continue
		seen[k] = true
		var v: Voxel = grid.voxel_at(k)
		if v != null:
			room._quiet_destroy[k] = true
			v.set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 0, 0)
			room.record_voxel_damage_to_base(v.grid_pos, v.level, v.damage_state, v.damage_is_blast, v.damage_carved_side, v.damage_variant, v.damage_substrate, v)
			cut.append(v)
	await room._voxel_board.process_dirty_slabs_async(room._slab_registry)
	await room._voxel_board.process_dirty_async(room._edge_registry)
	room.board3d().on_shot_commit(cut)
	room.bump_world_revision()
	print("[STRUCT-CUT] %d voxel(s) of %s destroyed up to level +%s" % [cut.size(), spec[0], spec[1]])
	room.schedule_structural_support(cut)
	return true


## MATERIALS F12 feasibility bench (see `scenario_runner.gd`, op `flood`): the whole playable floor as one body of water. The plane has no walls (every cell
## active: the upper bound of a real segment), a closed rim, and a source that keeps the water moving. A timer ticks it every 0.3 s and prints the tick's cost.
func scenario_flood(mode: String) -> bool:
	if room._flood_timer != null and is_instance_valid(room._flood_timer):
		room._flood_timer.queue_free()
	room._flood_timer = null
	if room._flood_sheet != null and is_instance_valid(room._flood_sheet):
		room._flood_sheet.queue_free()
	room._flood_sheet = null
	for old_sheet in room._flood_sheets:
		if is_instance_valid(old_sheet):
			old_sheet.queue_free()
	room._flood_sheets.clear()
	if mode == "off":
		return true
	var live: Node3D = room.board3d()
	if live == null:
		push_error("[Room] flood: no 3D board")
		return false
	if mode.begins_with("ch"):
		return room._flood_channels(live, int(mode.substr(2)), 0.25 if mode.ends_with("q") else 0.5)
	var pr: Rect2i = room._base_layout.get("playable_rect", Rect2i(Vector2i.ZERO, room._room_size))
	var rect := Rect2(Vector2(pr.position), Vector2(pr.size))
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var base_y: float = float(GeometryCoords.FLOOR_TOP_LEVEL + 1 - int(live.call("ground_level"))) * unit + LiquidSheet3DRef.LIFT
	var params: Dictionary = LiquidRegistryRef.resolve("caribe", {})
	var plane: RefCounted = null
	if mode != "level":
		var cell: float = 0.5 if mode == "plane05" else 0.25
		plane = FluidPlaneRef.new()
		var cols: int = int(round(rect.size.x / cell)) + 2
		var rows: int = int(round(rect.size.y / cell)) + 2
		plane.setup(cols, rows, cell, rect.position - Vector2(cell, cell), 0.9)
		for r in range(rows):
			for c in range(cols):
				if plane.is_rim(c, r):
					plane.ground[plane.index(c, r)] = FluidPlaneRef.WALL   ## a closed segment: the outer walls hold it
		plane.add_source(Rect2(rect.position + Vector2(1.0, 1.0), Vector2(2.0, 0.5)), 6.0)
	var sheet: MeshInstance3D = LiquidSheet3DRef.new()
	live.add_child(sheet)
	sheet.setup(rect, base_y, params, Vector2(0.0, 1.0), plane)
	room._flood_sheet = sheet
	if plane != null:
		var timer := Timer.new()
		timer.wait_time = 0.3
		room.add_child(timer)
		var stats: Array = [0, 0.0, 0.0]    ## ticks, total ms, worst ms
		timer.timeout.connect(func() -> void:
			var t0: int = Time.get_ticks_usec()
			sheet.tick()
			var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			stats[0] = int(stats[0]) + 1
			stats[1] = float(stats[1]) + ms
			stats[2] = maxf(float(stats[2]), ms)
			if int(stats[0]) % 10 == 0:
				var wet: int = 0
				for d in plane.depth:
					if d > 0.05:
						wet += 1
				print("[FLOOD] %s grid %dx%d tick %d: mean %.2f ms, worst %.2f ms, wet cells %d of %d, volume %.0f" % [mode, plane.cols, plane.rows, int(stats[0]),
						float(stats[1]) / float(stats[0]), float(stats[2]), wet, plane.cols * plane.rows, plane.total_volume()]))
		room._flood_timer = timer
		timer.start()
	print("[FLOOD] %s started on a %.0f x %.0f GU floor" % [mode, rect.size.x, rect.size.y])
	return true


func scenario_roof_gravity() -> bool:
	var released: int = 0
	for roof: Dictionary in room._base_layout.get("roof_instances", []):
		if SoftSheetPresets.has(String(roof["material"])) and bool(await room.release_roof_sheet(roof, false)):   ## the bench lets the cloth go from FLAT (the fall the Moto cost round measures)
			released += 1
	if released == 0:
		push_error("[Room] roof_gravity: this map has no soft roof (materials with a SoftSheetPresets row: %s)" % str(SoftSheetPresets.OF.keys()))
	return released > 0


func scenario_relight() -> bool:
	room._repaint_voxel_light_buckets(false)
	for _f in range(10):
		await room.get_tree().process_frame
	return room._voxel_light_field != null


## TEL-06b — emitted when `scenario_detonate()` has finished, successfully or not. The
## runner awaits this signal rather than the coroutine itself, and starts the
## detonation deferred, so a failure that returns at once cannot fire before it waits.
signal scenario_detonation_done(ok: bool)


## TEL-06b (DEVICE_DIAGNOSTICS §15.2) — a dev grenade detonated through the menu path
## (`open_menu_for()` + `detonate_active()`, as the benchmark does), with the camera
## ON the grenade, returning once the blast has finished playing. DIAG-19 needs the
## blast on screen in the verdict framing; the benchmark's never was.
## RETIRE-2 — `throw <index> <x,y>`: the dev grenade thrown to `target` through the real `execute_grenade_throw()`. True when the
## throw started; the flight, the fuse and the blast then run on their own, as they do for a player.
func scenario_throw(index: int, target: Vector2i) -> bool:
	if room._grenade_controller == null:
		push_error("[Room] scenario_throw: no GrenadeController — dev grenades exist on PLAYGROUND only")
		return false
	room._seed_dev_grenades_if_empty("SCENARIO")
	var grenades: Array = room._grenade_controller._grenades
	if index < 0 or index >= grenades.size() or bool(grenades[index]["detonated"]):
		push_error("[Room] scenario_throw: dev grenade #%d does not exist or is spent" % index)
		return false
	room._grenade_controller._targeting_mode = true
	room._grenade_controller._targeting_grenade_index = index
	room._grenade_controller._targeting_target_gu = target
	room._grenade_controller.execute_grenade_throw()
	return true


func scenario_detonate(index: int) -> void:
	if room._grenade_controller == null:
		push_error("[Room] scenario_detonate: no GrenadeController — dev grenades exist on PLAYGROUND only")
		scenario_detonation_done.emit(false)
		return
	room._seed_dev_grenades_if_empty("SCENARIO")
	var grenades: Array = room._grenade_controller._grenades
	if index < 0 or index >= grenades.size() or bool(grenades[index]["detonated"]):
		push_error("[Room] scenario_detonate: dev grenade #%d does not exist or is spent" % index)
		scenario_detonation_done.emit(false)
		return
	room.centre_camera_on(grenades[index]["gu_cell"])
	await room.get_tree().process_frame
	Telemetry.event("blast.request", {"index": index, "gu": grenades[index]["gu_cell"]})
	room._grenade_controller.open_menu_for(index)
	## The real click closes the menu BEFORE the action's visuals (DetonateContextMenu._on_action_pressed()); a direct
	## `detonate_active()` never reaches that handler, so without this the "Detonate / Cancel" popup and the red preview
	## stay over the whole blast in every capture and recording.
	if room._context_menu != null:
		room._context_menu.close()
	if room._blast_wireframe_overlay != null:
		room._blast_wireframe_overlay.clear()
	room._grenade_controller.detonate_active()
	## `is_blast_playing()`, not only `is_resolving_action()` — the action lock clears
	## about halfway through the blast (see the benchmark).
	var waited: int = 0
	const MAX_WAIT_FRAMES: int = 3600
	while (room.is_resolving_action() or room._grenade_controller.is_blast_playing()) \
			and waited < MAX_WAIT_FRAMES:
		await room.get_tree().process_frame
		waited += 1
	## One more frame, so `event_probe_report()` has certainly printed.
	await room.get_tree().process_frame
	if waited >= MAX_WAIT_FRAMES:
		push_warning("[Room] scenario_detonate: grenade #%d still playing after %d frames" % [index, waited])
	scenario_detonation_done.emit(waited < MAX_WAIT_FRAMES)


## Scenario step `place_guard`: put guard `index` on `cell` (position and cell, nothing else) and refresh what
## the vision radius says about it.
func scenario_place_guard(index: int, cell: Vector2i) -> bool:
	if index < 0 or index >= room._guards.size() or not is_instance_valid(room._guards[index]):
		push_error("[Room] scenario_place_guard: no guard #%d (%d on the map)" % [index, room._guards.size()])
		return false
	var guard = room._guards[index]
	guard.cell = cell
	guard.position = guard._cell_to_world(cell)
	room._update_enemy_visibility()
	return true


## MOVEMENT MV-4 — the scenario's `walk <x,y>`: the agent walks to `cell` the way a tap orders it (`SelectionController.try_move_to`: the
## movement overlay's path, the AP spent, the step's own tween), so a capture or a handset run sees the real walk. False (loud) when it
## does not start, with the reason the overlay gives.
func scenario_walk_agent(cell: Vector2i) -> bool:
	if room.agent == null or room._selection_controller == null:
		push_error("[Room] scenario_walk_agent: no agent or no selection controller")
		return false
	if room._selection_controller.try_move_to(cell):
		return true
	var reachable: bool = room.movement_overlay != null and room.movement_overlay.is_reachable(cell)
	push_error("[Room] scenario_walk_agent: the agent at %s did not start toward %s (reachable %s, AP %d, moving %s, enemy phase %s)"
		% [room.agent.cell, cell, reachable, int(room.turn_manager.current_ap), room.agent.is_moving, room.turn_manager.is_enemy_phase])
	return false


## RETIRE-2D — `canvas_check <name>`: one line saying how many overlays that carry a 3D target (`_ground` / `_world`) exist (`examined`),
## how many of those are visible now (`shown`), and which of them are painting the 2D canvas. `examined` and `shown` are the controls:
## a check that looked at nothing, or at a state that showed nothing, would print canvas=0 forever.
func scenario_canvas_check(label: String) -> void:
	var examined: int = 0
	var shown: int = 0
	var drawing: Array[String] = []
	for node in room.find_children("*", "CanvasItem", true, false):
		if not node.has_method("_draw"):
			continue
		var has_target: bool = false
		for key in room.OVERLAY_TARGET_KEYS:
			if key in node:
				has_target = true
		if has_target:
			examined += 1
			if (node as CanvasItem).is_visible_in_tree():
				shown += 1
			if room._draws_on_canvas(node):
				drawing.append(String(node.name) + "(" + String(node.get_script().resource_path.get_file()) + ")")
	print("[CANVAS-CHECK] %s examined=%d shown=%d canvas=%d %s" % [label, examined, shown, drawing.size(), " ".join(drawing)])


## RETIRE-2D — `aim <x,y>`: the grenade targeting preview on a GU, as a player aiming (stays open).
func scenario_aim(cell: Vector2i) -> bool:
	if room._grenade_controller == null:
		push_error("[Room] scenario_aim: no GrenadeController — dev grenades exist on PLAYGROUND only")
		return false
	room._seed_dev_grenades_if_empty("SCENARIO")
	## `SHOT_AGENT_CELL` places the agent first, as `scenario_shoot()` does: the aim is clamped to the throw range FROM the agent,
	## so a capture of the dome against a given wall needs the agent near it.
	var agent_xy: PackedStringArray = room._dev_flag("SHOT_AGENT_CELL", "").split(",")
	if agent_xy.size() == 2 and agent_xy[0].is_valid_int() and agent_xy[1].is_valid_int():
		room.agent.set_cell(Vector2i(agent_xy[0].to_int(), agent_xy[1].to_int()))
	room._grenade_controller.enter_grenade_mode()
	if not room._grenade_controller.is_in_targeting_mode():
		push_error("[Room] scenario_aim: targeting did not open")
		return false
	room._grenade_controller._set_targeting_target(cell)
	return true


## Cancels the grenade aim `scenario_aim()` opened (the real `cancel_targeting()`: the arm comes down, the fuse sparks ramp to 0).
func scenario_aim_cancel() -> bool:
	if room._grenade_controller == null or not room._grenade_controller.is_in_targeting_mode():
		push_error("[Room] scenario_aim_cancel: no grenade aim is open")
		return false
	room._grenade_controller.cancel_targeting()
	return true


## HERITAGE T5 (2026-11-11) — the alert meter after the HUD's Reset, on the real room: fill the LIVE meter (the
## TurnController's: the one the HUD bar shows and the end of the enemy phase reads for "busted"), press Reset through its
## real handler, and report what that meter reads. 0 = the reset reached it.
func scenario_alert_reset() -> bool:
	var tc: Object = room._turn_controller
	if tc == null:
		push_error("[ScenarioSteps] alert_reset: no TurnController")
		return false
	tc.set("_alert_meter", int(tc.get("_alert_max")))
	room._on_hud_reset_requested()
	var after: int = int(tc.call("get_alert_meter"))
	print("[ALERT-RESET] after the HUD's Reset the live meter reads %d of %d" % [after, int(tc.get("_alert_max"))])
	return after == 0

