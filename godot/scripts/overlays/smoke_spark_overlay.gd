extends Node2D
class_name SmokeSparkOverlay

## SmokeSparkOverlay — brief above-floor VFX for VoxelRenderer.voxel_destroyed:
## material-colored smoke puffs (every destroyed voxel) and metal/stone
## sparks (chance-gated, rolled by the caller).
##
## PURELY VISUAL, same contract as EmberOverlay (see that file's doc):
## nothing here is gameplay state, so losing an in-flight puff to a
## perspective rotation or map reload costs nothing.
##
## Same idiom as EmberOverlay: one persistent Node2D, entries kept as plain
## Dictionaries in an Array, `_process()` ages/filters, `_draw()` renders,
## `clear()` wipes everything on map reload. Two independent families (smoke,
## sparks) share this one node/z-slot/blend-mode rather than four smaller
## overlays — see the plan's note on why sparks don't get true additive glow
## here: CanvasItemMaterial.blend_mode is per-node, and smoke needs normal
## blend (additive smoke reads as glowing gas, not soot).

## Tuning — all `var` (Rule 1).

## --- Smoke ---
var smoke_blob_count_min: int = 2
var smoke_blob_count_max: int = 3
var smoke_duration_min: float = 0.6       ## seconds — "bem rápido e some"
var smoke_duration_max: float = 1.0
var smoke_start_radius: float = 6.0
var smoke_end_radius: float = 16.0
var smoke_drift_x: float = 10.0           ## px/sec horizontal jitter range
var smoke_drift_y_min: float = 18.0       ## px/sec upward drift range
var smoke_drift_y_max: float = 32.0
var smoke_drift_damping: float = 0.4      ## exponential decay applied to velocity per second
var smoke_fade_power: float = 1.4
var smoke_spawn_jitter: float = 4.0       ## px, per-blob offset from the requested position

## --- Sparks ---
var spark_speed_min: float = 60.0         ## px/sec
var spark_speed_max: float = 140.0
var spark_gravity: float = 260.0          ## px/sec^2, downward
var spark_duration_min: float = 0.2       ## seconds — brief and fast
var spark_duration_max: float = 0.4
var spark_trail_length: float = 5.0       ## px, streak drawn behind the spark
var spark_width: float = 1.5
var spark_fade_power: float = 1.2

var _smoke: Array = []  ## [{"pos","vel","elapsed","duration","color","start_radius","end_radius"}]
var _sparks: Array = [] ## [{"pos","vel","elapsed","duration","color"}]


## Queue a small puff at `pos`. `color` carries its own alpha (base opacity);
## `scale` shrinks/grows both size and offset — used by EmberOverlay to spawn
## a smaller puff when an ember burns out.
## `duration_scale` (EXPLOSION_REBUILD_MASTER_PLAN Task 5/E-WAVE, 2026-08-07):
## multiplies the randomized min/max duration window — DetonationChoreographer's
## smoke waves use this so a farther ring's puff genuinely lingers for less
## time, not just a smaller/fainter one ("usando durações diferentes", Director,
## recorded at §6.2). Trailing + defaulted to 1.0, so every pre-existing caller
## (EmberOverlay, room.gd's VFX-01 dispatch) is byte-for-byte unaffected.
## `blob_count_override` (E-SMOKE-01, 2026-08-08): the Director's per-voxel blast
## smoke ("praticamente todo voxel afetado pode soltar um pouquinho de fumaça")
## turns one call per GU into one call per damaged voxel — two orders of
## magnitude more calls, each of which should be a SINGLE small puff rather than
## the 2-3 blob cluster a lone destroyed voxel gets from VFX-01. Trailing +
## defaulted to 0 = "use the min/max range", so EmberOverlay and room.gd's VFX-01
## dispatch are byte-for-byte unaffected.
func add_smoke(pos: Vector2, color: Color, scale: float = 1.0, duration_scale: float = 1.0,
		blob_count_override: int = 0) -> void:
	var blob_count: int = blob_count_override if blob_count_override > 0 \
		else randi_range(smoke_blob_count_min, smoke_blob_count_max)
	for i in range(blob_count):
		var offset := Vector2(randf_range(-smoke_spawn_jitter, smoke_spawn_jitter),
			randf_range(-smoke_spawn_jitter, smoke_spawn_jitter)) * scale
		var vel := Vector2(randf_range(-smoke_drift_x, smoke_drift_x),
			-randf_range(smoke_drift_y_min, smoke_drift_y_max))
		_smoke.append({
			"pos": pos + offset,
			"vel": vel,
			"elapsed": 0.0,
			"duration": randf_range(smoke_duration_min, smoke_duration_max) * duration_scale,
			"color": color,
			"start_radius": smoke_start_radius * scale * randf_range(0.85, 1.15),
			"end_radius": smoke_end_radius * scale * randf_range(0.85, 1.15),
		})
	set_process(true)


## Queue `count` sparks bursting outward from `pos`.
func add_sparks(pos: Vector2, count: int, color: Color) -> void:
	for i in range(count):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(spark_speed_min, spark_speed_max)
		_sparks.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"elapsed": 0.0,
			"duration": randf_range(spark_duration_min, spark_duration_max),
			"color": color,
		})
	set_process(true)


func _process(delta: float) -> void:
	if _smoke.is_empty() and _sparks.is_empty():
		set_process(false)
		return

	var alive_smoke: Array = []
	var damping: float = pow(smoke_drift_damping, delta)
	for s in _smoke:
		s["elapsed"] += delta
		s["pos"] += s["vel"] * delta
		s["vel"] *= damping
		if s["elapsed"] < s["duration"]:
			alive_smoke.append(s)
	_smoke = alive_smoke

	var alive_sparks: Array = []
	for p in _sparks:
		p["elapsed"] += delta
		p["vel"] += Vector2(0.0, spark_gravity) * delta
		p["pos"] += p["vel"] * delta
		if p["elapsed"] < p["duration"]:
			alive_sparks.append(p)
	_sparks = alive_sparks

	queue_redraw()


func _draw() -> void:
	for s in _smoke:
		var t: float = s["elapsed"] / s["duration"]
		var alpha: float = pow(1.0 - t, smoke_fade_power)
		var c: Color = s["color"]
		c.a *= alpha
		var radius: float = lerp(float(s["start_radius"]), float(s["end_radius"]), t)
		draw_circle(s["pos"], radius, c)

	for p in _sparks:
		var t: float = p["elapsed"] / p["duration"]
		var alpha: float = pow(1.0 - t, spark_fade_power)
		var c: Color = p["color"]
		c.a *= alpha
		var vel: Vector2 = p["vel"]
		var tail: Vector2 = vel.normalized() * spark_trail_length if vel.length() > 0.01 else Vector2.ZERO
		draw_line(p["pos"], p["pos"] - tail, c, spark_width)


## Discard every in-flight puff/spark (map load/reload) — same reasoning as
## EmberOverlay.clear(): nothing here is state a reload needs to restore.
func clear() -> void:
	_smoke.clear()
	_sparks.clear()
	set_process(false)
	queue_redraw()
