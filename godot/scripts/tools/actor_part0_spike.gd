## ACTOR_MASTER_PLAN — Part 0 measurement spike.
##
## "Build one actor's digital twin at ×8, bake one pose, measure compose time
## and texture memory for real. Go/no-go on ×8 as the runtime default before
## Part 1 gets written in earnest." (§5 Part 0)
##
## The twin here is a SYNTHETIC PLACEHOLDER humanoid (leg/torso/arm/head
## blocks in proportion, no real character art exists yet — that is Part 2b/
## mass-import, explicitly deferred). This script exists only to turn D2's
## "×8" resolution choice from a guess into a measured number before Part 1
## is written on top of it, same discipline destruction_part0_spike.gd used
## for DESTRUCTION_MASTER_PLAN.
##
## Honesty boundary, stated once here instead of at every print: this reuses
## bake_voxel_sprite_3d.gd's exact camera/lighting rig verbatim (one
## MeshInstance3D + BoxMesh + StandardMaterial3D per voxel — the same
## approach already shipped for the grenade, not a redesigned renderer).
## D13 (VoxelLightField reuse) is Part 2's job, not measured here — this
## script keeps the existing tool's flat lighting on purpose, so the numbers
## below measure geometry/compose cost only, not a lighting change.
## Must run WINDOWED (real GPU rasterizer) — `sub.get_texture().get_image()`
## needs a real display driver, exactly like bake_voxel_sprite_3d.gd. Run via:
##   godot --path . --position 4000,4000 --quit-after 30 \
##     --script res://godot/scripts/tools/actor_part0_spike.gd
extends SceneTree

const VIEWPORT_SIZE := Vector2i(480, 640)
const ELEVATION_DEG := 30.0
const AZIMUTH_DEG := 45.0
const CUBE_SIZE := 1.0
## bake_voxel_sprite_3d.gd's fixed ORTHO_SIZE=26/CAMERA_DISTANCE=80 were tuned
## for the much smaller grenade — a tier-8 humanoid (48 body-units tall) blew
## past that frame and cropped to a close-up of the head. Scaled to body
## height instead, per tier, so every capture actually frames the whole figure.

## Humanoid proportions, in "body units" (S below is voxels-per-body-unit —
## the resolution tier under test). Rough human silhouette: legs, torso,
## two arms, head — not real art, just enough shape to avoid measuring a
## trivial solid rectangular block (which would overstate real voxel count).
const BODY_HEIGHT_UNITS := 6
const BODY_WIDTH_UNITS := 3
const BODY_DEPTH_UNITS := 2

## Resolution tiers under test. D2 ratifies ×8 as the runtime default; ×4 and
## ×16 bracket it for the go/no-go comparison the plan asks for. A tier is
## skipped (not silently run) if its projected voxel count crosses
## MAX_SAFE_VOXELS, since a MeshInstance3D-per-voxel scene at tens of
## thousands of nodes has no established cost data yet — the point of this
## spike is to find that ceiling honestly, not hang past it.
const TIERS: Array[int] = [4, 8, 16]
const MAX_SAFE_VOXELS := 18000  ## tier 8 (the D2-ratified default) measures at ~16.6k for
## this humanoid's proportions — raised just enough to let it actually run instead of
## skipping the one tier this whole spike exists to evaluate. Tier 16 (~133k) stays capped.


func _init() -> void:
	print("\n" + "=".repeat(78))
	print("ACTOR_MASTER_PLAN — Part 0 measurement spike (%s)" % Time.get_date_string_from_system())
	print("=".repeat(78))
	print("Synthetic placeholder humanoid — NOT real character art (see file header).")
	print("Body proportions: %d x %d x %d units (h x w x d)" % [BODY_HEIGHT_UNITS, BODY_WIDTH_UNITS, BODY_DEPTH_UNITS])

	await _run_all_tiers()

	print("\n[SPIKE] Done.\n")
	quit(0)


func _mem_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


## Builds the humanoid voxel list at subdivision S: {x,y,z,r,g,b} per solid
## voxel, in the same shape bake_voxel_sprite_3d.gd's VOXEL_JSON_PATH expects,
## so this spike's output is drop-in comparable with the shipped grenade tool.
func _build_humanoid_voxels(s: int) -> Array:
	var h := BODY_HEIGHT_UNITS * s
	var w := BODY_WIDTH_UNITS * s
	var d := BODY_DEPTH_UNITS * s
	var voxels: Array = []

	var leg_w := maxi(1, w / 3)
	var leg_gap := maxi(1, w - 2 * leg_w)
	var leg_h := int(h * 0.42)
	var torso_h := int(h * 0.38)
	var head_h := h - leg_h - torso_h
	var arm_w := maxi(1, leg_w / 2)

	## Legs: two columns, dark uniform blue.
	for leg_i in range(2):
		var x0 := leg_i * (leg_w + leg_gap)
		for x in range(x0, x0 + leg_w):
			for z in range(d):
				for y in range(leg_h):
					voxels.append({"x": x, "y": y, "z": z, "r": 30, "g": 40, "b": 90})

	## Torso: full width, slightly lighter blue.
	for x in range(w):
		for z in range(d):
			for y in range(leg_h, leg_h + torso_h):
				voxels.append({"x": x, "y": y, "z": z, "r": 50, "g": 60, "b": 120})

	## Arms: two thin columns flanking the torso, same tone as torso.
	for arm_i in range(2):
		var ax0 := -arm_w if arm_i == 0 else w
		for x in range(ax0, ax0 + arm_w):
			for z in range(d):
				for y in range(leg_h, leg_h + torso_h):
					voxels.append({"x": x, "y": y, "z": z, "r": 50, "g": 60, "b": 120})

	## Head: centered, skin tone.
	var head_w := maxi(1, int(w * 0.6))
	var hx0 := (w - head_w) / 2
	for x in range(hx0, hx0 + head_w):
		for z in range(d):
			for y in range(leg_h + torso_h, h):
				voxels.append({"x": x, "y": y, "z": z, "r": 210, "g": 170, "b": 140})

	return voxels


func _run_all_tiers() -> void:
	print("\n%6s %14s %14s %14s %14s %16s %10s" % [
		"tier", "voxels", "build_ms", "compose_ms", "capture_ms", "img_MB(raw)", "status"
	])
	for s in TIERS:
		await _run_one_tier(s)


func _run_one_tier(s: int) -> void:
	var t0 := Time.get_ticks_usec()
	var voxels := _build_humanoid_voxels(s)
	var t_build := Time.get_ticks_usec()
	var n := voxels.size()

	if n > MAX_SAFE_VOXELS:
		print("%6d %14d %14s %14s %14s %16s %10s" % [
			s, n, "-", "-", "-", "-", "SKIPPED (>%d voxels, no established per-node cost data)" % MAX_SAFE_VOXELS
		])
		return

	var mem_before := _mem_mb()

	## Bounding-box center, in voxel-index space — same pivot convention as
	## bake_voxel_sprite_3d.gd.
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for v in voxels:
		var p := Vector3(v.x, v.y, v.z)
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	var center := (min_v + max_v) * 0.5

	var sub := SubViewport.new()
	sub.size = VIEWPORT_SIZE
	sub.transparent_bg = true
	sub.msaa_3d = Viewport.MSAA_8X
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	world_env.environment = env
	sub.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.6
	sub.add_child(light)

	var body_height: float = max_v.y - min_v.y
	var ortho_size: float = body_height * 2.4
	var camera_distance: float = body_height * 4.0

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_size
	var elev := deg_to_rad(ELEVATION_DEG)
	var azim := deg_to_rad(AZIMUTH_DEG)
	var dir := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sub.add_child(cam)
	cam.look_at_from_position(center + dir * camera_distance, center, Vector3.UP)
	cam.current = true

	var t_compose_start := Time.get_ticks_usec()
	for v in voxels:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * CUBE_SIZE
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(v.r / 255.0, v.g / 255.0, v.b / 255.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mesh_inst.material_override = mat
		mesh_inst.position = (Vector3(v.x, v.y, v.z) - center) * CUBE_SIZE
		sub.add_child(mesh_inst)
	var t_compose_end := Time.get_ticks_usec()

	for _i in range(5):
		await process_frame

	var t_capture_start := Time.get_ticks_usec()
	var img := sub.get_texture().get_image()
	var t_capture_end := Time.get_ticks_usec()

	var mem_after := _mem_mb()
	var raw_bytes := img.get_width() * img.get_height() * 4  ## RGBA8, pre-crop
	var out_path := "res://Screenshots/history/actor_part0_spike_s%d.png" % s
	img.save_png(out_path)

	print("%6d %14d %14.2f %14.2f %14.2f %16.3f %10s" % [
		s, n,
		(t_build - t0) / 1000.0,
		(t_compose_end - t_compose_start) / 1000.0,
		(t_capture_end - t_capture_start) / 1000.0,
		raw_bytes / 1048576.0,
		"ok (mem +%.2fMB)" % (mem_after - mem_before),
	])
	print("        -> saved %s (%dx%d before autocrop)" % [out_path, img.get_width(), img.get_height()])

	sub.queue_free()
	for _i in range(3):
		await process_frame
