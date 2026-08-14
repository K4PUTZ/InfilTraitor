## CHARACTER_MASTER_PLAN §8 / ACTOR §7 #28 — measures the RESIDENT texture cost
## of a character frame set, instead of assuming it.
##
## WHY THIS EXISTS. S1 proved the relight technique survives ASTC compression.
## It did NOT measure how much memory a character costs, and it did not measure
## headroom — those are different questions, and §7 #28 still lists the resident
## frame count as unmeasured. This probe closes the arithmetic half of it with
## real compressed byte counts read out of Godot, not a spec sheet.
##
## WHAT IT DOES NOT ANSWER. Device headroom. Knowing a set costs N MB says
## nothing about what a given phone has spare alongside the voxel tilemap, the
## atlas pages and the engine itself. That needs an on-device run, and this
## probe deliberately does not pretend otherwise.
##
## THE RESIDENT SET IS NOT THE CATALOG (D42). The multiplicative axes are
## mutually exclusive at runtime: the player wears one archetype in one
## silhouette class. Guards are the same frames under a different tint (D41), so
## they cost nothing extra in texture memory. RAM holds one loadout; the rest of
## the catalog is a disk cost.
##
## Run:
##   godot --path . --position 4000,4000 \
##     --script res://godot/scripts/tools/s2_resident_memory_probe.gd
extends SceneTree

## Candidate character sprite canvases. The real one is not chosen yet (§4.7's
## scale derivation is open, §9 #3) — so this brackets it rather than guessing
## one number and presenting it as settled.
const CANVASES: Array[Vector2i] = [
	Vector2i(96, 128),
	Vector2i(128, 160),
	Vector2i(160, 192),
	Vector2i(192, 256),
]

## Yaw counts corresponding to 0 / 1 / 3 / 7 / 11 / 15 in-betweens per 90 deg.
const YAW_OPTIONS: Array[int] = [4, 8, 16, 32, 48, 64]

## §4.4's pose list is eight entries. D39 then requires TRANSITIONS between them,
## which is the part that actually multiplies — a turn, a step, a posture change
## and a hood toggle are all frame sequences, not single frames. 3x is a working
## placeholder for "poses plus the motion between them", flagged as such.
const POSE_COUNT := 8
const TRANSITION_MULTIPLIER := 3.0


func _init() -> void:
	print("=== S2b — resident texture cost of a character frame set ===")
	_run.call_deferred()


func _run() -> void:
	print("")
	print("Measured bytes per frame PAIR (albedo + normal), real Godot compression:")
	print("canvas      RGBA8      ASTC       ratio")

	var per_pair: Dictionary = {}
	for canvas in CANVASES:
		var raw := _measure(canvas, -1)
		var astc := _measure(canvas, Image.COMPRESS_ASTC)
		if astc <= 0:
			print("%-11s %-10s ASTC unavailable" % [_dim(canvas), _kb(raw * 2)])
			continue
		per_pair[canvas] = astc * 2
		print("%-11s %-10s %-10s %.1fx" % [
			_dim(canvas), _kb(raw * 2), _kb(astc * 2), float(raw) / float(astc)])

	print("")
	print("=== RESIDENT SET (D42: one archetype, one silhouette class) ===")
	print("Frames = %d poses x %.1f (poses + transitions between them, D39) x yaws"
		% [POSE_COUNT, TRANSITION_MULTIPLIER])
	print("Guards add ~0 — same frames, different tint (D41).")
	print("")

	var header := "yaws  in-betw  frames "
	for canvas in CANVASES:
		if per_pair.has(canvas):
			header += " %-11s" % _dim(canvas)
	print(header)

	for yaws in YAW_OPTIONS:
		var inbetween := (yaws - 4) / 4
		var frames := int(round(float(POSE_COUNT) * TRANSITION_MULTIPLIER * float(yaws)))
		var row := "%-5d %-8d %-7d" % [yaws, inbetween, frames]
		for canvas in CANVASES:
			if per_pair.has(canvas):
				row += " %-11s" % _mb(int(per_pair[canvas]) * frames)
		print(row)

	print("")
	print("Read it against what it decides: this is the ONE loadout that must be")
	print("resident, not the authored catalog. What it does not tell you is what a")
	print("real device has spare — that needs an on-device run, and nothing here")
	print("should be cited as headroom.")
	quit(0)


## Returns compressed (or raw) byte size of one image at this canvas size.
## Content is the real bake upscaled/cropped to the target, not noise: block
## compressors are content-sensitive, so measuring random pixels would overstate
## the cost of art that has large flat regions.
func _measure(canvas: Vector2i, mode: int) -> int:
	var src := Image.new()
	if src.load("res://ASSETS/ISOMETRIC/source_assets/actor_bakes/shotgun_frames/frame_00_normal.png") != OK:
		push_error("[S2b] could not load a real frame to measure against")
		return -1
	src.resize(canvas.x, canvas.y, Image.INTERPOLATE_NEAREST)
	src.convert(Image.FORMAT_RGB8)
	if mode < 0:
		# RGBA8 is the uncompressed baseline a texture would occupy in VRAM.
		src.convert(Image.FORMAT_RGBA8)
		return src.get_data().size()
	if src.compress(mode) != OK:
		return -1
	return src.get_data().size()


func _dim(v: Vector2i) -> String:
	return "%dx%d" % [v.x, v.y]


func _kb(bytes: int) -> String:
	return "%.1f KB" % (float(bytes) / 1024.0)


func _mb(bytes: int) -> String:
	return "%.1f MB" % (float(bytes) / 1048576.0)
