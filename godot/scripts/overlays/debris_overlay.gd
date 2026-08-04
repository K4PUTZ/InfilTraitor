extends Node2D
class_name DebrisOverlay

## DebrisOverlay — floor-level VFX for VoxelRenderer.voxel_destroyed: masonry
## dust (concrete/stone/ground family) and wood chips, both chance-gated by
## the caller. Sits in the floor z-band (see room.gd's
## _apply_overhead_overlay_z()), not "always on top" like EmberOverlay/
## SmokeSparkOverlay — these are meant to read as landing ON the ground, not
## floating above the geometry.
##
## PURELY VISUAL, same contract as EmberOverlay/SmokeSparkOverlay: nothing
## here is gameplay state.
##
## Same idiom: one persistent Node2D, entries as plain Dictionaries in an
## Array, `_process()` ages/filters, `_draw()` renders, `clear()` wipes
## everything on map reload.
##
## Both `origin` and `target` (the floor position to fall/land at) are passed
## in by the caller via VoxelRenderer.voxel_world_position() — analytic, not
## an empirical pixel offset (project rule): this overlay has no geometry
## knowledge of its own, it only interpolates between two points it's given.

## Tuning — all `var` (Rule 1).

## --- Dust ---
var dust_delay_min: float = 0.9           ## seconds before it starts falling — "depois de 1 segundo"
var dust_delay_max: float = 1.1
var dust_fall_duration_min: float = 0.3
var dust_fall_duration_max: float = 0.5
var dust_settle_duration_min: float = 0.6
var dust_settle_duration_max: float = 1.0
var dust_speck_count_min: int = 3
var dust_speck_count_max: int = 5
var dust_speck_spread: float = 5.0        ## px, cluster radius around the falling point
var dust_speck_radius: float = 1.6
var dust_fade_power: float = 1.3

## --- Wood chips ---
var chip_arc_duration_min: float = 0.4    ## seconds of flight before landing
var chip_arc_duration_max: float = 0.6
var chip_settle_duration_min: float = 0.8 ## hold + fade once landed
var chip_settle_duration_max: float = 1.3
var chip_gravity: float = 420.0           ## px/sec^2, downward
var chip_horizontal_jitter: float = 40.0  ## px/sec, added sideways so chips fan out
var chip_half_w: float = 3.5
var chip_half_h: float = 1.6
var chip_size_jitter_min: float = 0.7
var chip_size_jitter_max: float = 1.3
var chip_rotation_speed_min: float = -10.0  ## rad/sec while airborne
var chip_rotation_speed_max: float = 10.0
var chip_fade_power: float = 1.3

var _dust: Array = []
## [{"origin","target","color","delay","fall_duration","settle_duration",
##   "elapsed","specks":[Vector2 offsets]}]
var _chips: Array = []
## [{"pos","vel","gravity","arc_duration","settle_duration","elapsed","color",
##   "half_w","half_h","rotation","rotation_speed"}]


## Queue a small puff of dust that waits, then falls from `origin` to `target`
## (the floor position at the same grid column) and settles/fades there.
func add_dust(origin: Vector2, target: Vector2, color: Color) -> void:
	var speck_count: int = randi_range(dust_speck_count_min, dust_speck_count_max)
	var specks: Array = []
	for i in range(speck_count):
		specks.append(Vector2(randf_range(-dust_speck_spread, dust_speck_spread),
			randf_range(-dust_speck_spread, dust_speck_spread)))
	_dust.append({
		"origin": origin,
		"target": target,
		"color": color,
		"delay": randf_range(dust_delay_min, dust_delay_max),
		"fall_duration": randf_range(dust_fall_duration_min, dust_fall_duration_max),
		"settle_duration": randf_range(dust_settle_duration_min, dust_settle_duration_max),
		"elapsed": 0.0,
		"specks": specks,
	})
	set_process(true)


## Queue `count` wood chips that fly from `origin` on a short ballistic arc
## timed to land at `target`, then settle/fade there.
func add_chips(origin: Vector2, target: Vector2, count: int, color: Color) -> void:
	for i in range(count):
		var arc_duration: float = randf_range(chip_arc_duration_min, chip_arc_duration_max)
		var displacement: Vector2 = target - origin
		## Analytic launch velocity that lands exactly at `target` after
		## `arc_duration` under chip_gravity (projectile motion solved for v0).
		var vel := Vector2(
			displacement.x / arc_duration + randf_range(-chip_horizontal_jitter, chip_horizontal_jitter),
			(displacement.y - 0.5 * chip_gravity * arc_duration * arc_duration) / arc_duration)
		var size_jitter: float = randf_range(chip_size_jitter_min, chip_size_jitter_max)
		_chips.append({
			"pos": origin,
			"vel": vel,
			"arc_duration": arc_duration,
			"settle_duration": randf_range(chip_settle_duration_min, chip_settle_duration_max),
			"elapsed": 0.0,
			"color": color,
			"half_w": chip_half_w * size_jitter,
			"half_h": chip_half_h * size_jitter,
			"rotation": randf_range(0.0, TAU),
			"rotation_speed": randf_range(chip_rotation_speed_min, chip_rotation_speed_max),
		})
	set_process(true)


func _process(delta: float) -> void:
	if _dust.is_empty() and _chips.is_empty():
		set_process(false)
		return

	var alive_dust: Array = []
	for d in _dust:
		d["elapsed"] += delta
		var total: float = d["delay"] + d["fall_duration"] + d["settle_duration"]
		if d["elapsed"] < total:
			alive_dust.append(d)
	_dust = alive_dust

	var alive_chips: Array = []
	for c in _chips:
		c["elapsed"] += delta
		if c["elapsed"] < c["arc_duration"]:
			c["vel"] += Vector2(0.0, chip_gravity) * delta
			c["pos"] += c["vel"] * delta
			c["rotation"] += c["rotation_speed"] * delta
		var total: float = c["arc_duration"] + c["settle_duration"]
		if c["elapsed"] < total:
			alive_chips.append(c)
	_chips = alive_chips

	queue_redraw()


func _draw() -> void:
	for d in _dust:
		var elapsed: float = d["elapsed"]
		var delay: float = d["delay"]
		var fall_duration: float = d["fall_duration"]
		var settle_duration: float = d["settle_duration"]
		if elapsed < delay:
			continue
		var pos: Vector2
		var alpha: float
		if elapsed < delay + fall_duration:
			var t: float = (elapsed - delay) / fall_duration
			pos = lerp(d["origin"] as Vector2, d["target"] as Vector2, t)
			alpha = t
		else:
			pos = d["target"]
			var st: float = (elapsed - delay - fall_duration) / settle_duration
			alpha = pow(1.0 - st, dust_fade_power)
		var c: Color = d["color"]
		c.a *= alpha
		for offset in d["specks"]:
			draw_circle(pos + offset, dust_speck_radius, c)

	for chip in _chips:
		var pos: Vector2 = chip["pos"]
		var alpha: float = 1.0
		if chip["elapsed"] >= chip["arc_duration"]:
			var st: float = (chip["elapsed"] - chip["arc_duration"]) / chip["settle_duration"]
			alpha = pow(1.0 - st, chip_fade_power)
		var c: Color = chip["color"]
		c.a *= alpha
		var points := PackedVector2Array()
		var half_w: float = chip["half_w"]
		var half_h: float = chip["half_h"]
		var rot: float = chip["rotation"]
		for corner in [Vector2(-half_w, -half_h), Vector2(half_w, -half_h), Vector2(half_w, half_h), Vector2(-half_w, half_h)]:
			points.append(pos + corner.rotated(rot))
		draw_colored_polygon(points, c)


## Discard every in-flight dust/chip (map load/reload) — same reasoning as
## EmberOverlay.clear(): nothing here is state a reload needs to restore.
func clear() -> void:
	_dust.clear()
	_chips.clear()
	set_process(false)
	queue_redraw()
