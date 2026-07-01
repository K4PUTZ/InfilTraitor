extends SceneTree
## Selftest headless das data classes Voxel (VOXEL-03).
## Rodar: godot --headless --script res://godot/scripts/tools/voxel_selftest.gd
## Saída: "VOXEL-03 SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

func _initialize() -> void:
	var VR = load("res://godot/scripts/world/voxel_ref.gd")
	var WS = load("res://godot/scripts/world/wall_slice.gd")
	var HW = load("res://godot/scripts/world/high_wall.gd")
	var SC = load("res://godot/scripts/world/subcube_coords.gd")
	var failures: int = 0
	var checked:  int = 0

	## ── VoxelRef ─────────────────────────────────────────────────────────
	var vr = VR.new(Vector2i(3, 4), 2)
	checked += 1; if vr.grid_pos != Vector2i(3, 4): push_error("VR: grid_pos"); failures += 1
	checked += 1; if vr.level   != 2:               push_error("VR: level");    failures += 1
	checked += 1; if vr.visible != true:             push_error("VR: visible");  failures += 1
	checked += 1; if vr.dirty   != false:            push_error("VR: dirty");    failures += 1

	## set_visible no-op
	vr.set_visible(true)
	checked += 1; if vr.dirty != false: push_error("VR: set_visible no-op sujo dirty"); failures += 1

	## set_visible muda estado
	vr.set_visible(false)
	checked += 1; if vr.visible != false: push_error("VR: set_visible(false).visible"); failures += 1
	checked += 1; if vr.dirty   != true:  push_error("VR: set_visible(false).dirty");  failures += 1

	## clear_dirty
	vr.clear_dirty()
	checked += 1; if vr.dirty != false: push_error("VR: clear_dirty"); failures += 1

	## DAMAGE_DESTROYED força visible=false
	vr.set_visible(true); vr.clear_dirty()
	vr.set_damage(VR.DAMAGE_DESTROYED)
	checked += 1; if vr.visible      != false:              push_error("VR: DESTROYED.visible"); failures += 1
	checked += 1; if vr.dirty        != true:               push_error("VR: DESTROYED.dirty");   failures += 1
	checked += 1; if vr.damage_state != VR.DAMAGE_DESTROYED: push_error("VR: damage_state");      failures += 1

	## DAMAGE_CRACKED não esconde
	var vr2 = VR.new(Vector2i(0, 0), 0)
	vr2.set_damage(VR.DAMAGE_CRACKED)
	checked += 1; if vr2.visible == false: push_error("VR: CRACKED nao deve esconder"); failures += 1
	checked += 1; if vr2.dirty   != true:  push_error("VR: CRACKED.dirty");             failures += 1

	## ── WallSlice ────────────────────────────────────────────────────────
	var ws = WS.new()
	ws.id           = "WALL_NW_GC01_GR02_S0"
	ws.direction    = "NW"
	ws.slice_index  = 0
	ws.gu_cell      = Vector2i(1, 2)
	ws.storey_count = 1

	## Povoa: 8 posições × 8 níveis = 64 VoxelRefs
	for j in 8:
		for lv in 8:
			ws.voxels.append(VR.new(Vector2i(1 * 8, 2 * 8 + j), lv))

	checked += 1; if ws.total_voxel_count() != 64: push_error("WS: total_voxel_count"); failures += 1
	checked += 1; if ws.get_voxel(0)  == null:     push_error("WS: get_voxel(0)");      failures += 1
	checked += 1; if ws.get_voxel(63) == null:     push_error("WS: get_voxel(63)");     failures += 1
	checked += 1; if ws.get_voxel(64) != null:     push_error("WS: get_voxel(64) OOB"); failures += 1
	checked += 1; if ws.get_voxel(-1) != null:     push_error("WS: get_voxel(-1) OOB"); failures += 1

	ws.mark_all_dirty()
	checked += 1; if ws.dirty_count != 64: push_error("WS: dirty_count"); failures += 1
	var all_dirty: bool = true
	for v in ws.voxels:
		if not v.dirty: all_dirty = false; break
	checked += 1; if not all_dirty: push_error("WS: mark_all_dirty nao marcou todos"); failures += 1

	## ── HighWall ─────────────────────────────────────────────────────────
	var hw = HW.new()
	hw.id = "HIGHWALL_001"
	hw.slices.append(ws)

	var extra = VR.new(Vector2i(7, 15), 0)
	hw.junction_extras.append(extra)

	checked += 1; if hw.total_voxel_count() != 65:                            push_error("HW: total 64+1");      failures += 1
	checked += 1; if hw.get_slice("WALL_NW_GC01_GR02_S0") == null:            push_error("HW: get_slice found"); failures += 1
	checked += 1; if hw.get_slice("WALL_NE_GC00_GR00_S0") != null:            push_error("HW: get_slice miss");  failures += 1
	checked += 1; if hw.all_voxels().size() != 65:                             push_error("HW: all_voxels");      failures += 1
	checked += 1; if hw.all_voxels()[64] != extra:                             push_error("HW: extra last");      failures += 1

	## ── SubcubeCoords voxel API (VOXEL-02) ───────────────────────────────
	for uy in range(0, 10):
		for ux in range(0, 10):
			var gu: Vector2i     = Vector2i(ux, uy)
			var origin: Vector2i = SC.gu_to_voxel_origin(gu)
			checked += 1
			if origin != gu * 8:
				push_error("SC.gu_to_voxel_origin(%s)" % gu); failures += 1
			checked += 1
			if SC.voxel_to_gu(origin) != gu:
				push_error("SC.voxel_to_gu round-trip %s" % gu); failures += 1
			var local_v: Vector2i = SC.voxel_local(origin + Vector2i(3, 7))
			checked += 1
			if local_v != Vector2i(3, 7):
				push_error("SC.voxel_local %s" % gu); failures += 1
			checked += 1
			if SC.gu_voxels(gu).size() != 64:
				push_error("SC.gu_voxels size %s" % gu); failures += 1

	## ── Sumário ──────────────────────────────────────────────────────────
	if failures == 0:
		print("VOXEL-03 SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("VOXEL-03 SELFTEST: FAIL (%d falhas / %d checagens)" % [failures, checked])
		quit(1)
