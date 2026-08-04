extends Node2D
class_name EmberOverlay

## EmberOverlay — VL-D4: a fading warm glow over freshly blasted voxels.
##
## PURELY VISUAL, same contract as every other overlay in this codebase (O1
## precedent: "occlusion is VIEW, not STATE"; shadow spill is "never feeds
## gameplay detection"). The voxel's actual charred appearance already exists
## in the tile the instant the blast applies soot (VL-D1) — this only draws a
## bright, fading blob ON TOP of it for a few seconds, so losing an in-flight
## glow to a perspective rotation or map reload costs nothing but the glow
## itself; nothing here is state a reload needs to restore.
##
## Why an overlay and not a tile modulate: a light-bucket alternative's
## modulate is SHARED by every voxel placed at that (source, atlas_coords,
## alt_id) — that sharing is what makes VL-01/VL-03's bucket system cheap, but
## it also means it structurally CANNOT carry one voxel's own independent,
## time-varying colour without recolouring every other voxel sharing that
## alternative. A screen-space glow sidesteps that entirely.
##
## Each ember now rolls its own color/radius/pulse/duration instead of a
## single shared look — and dims out low-to-high (a height bias on top of the
## random duration) so a scorched patch reads as heat rising and cooling
## rather than a bank of identical dots. When an ember expires it hands a
## small puff to the smoke overlay (see set_smoke_overlay()) so extinguishing
## reads as "went out", not "vanished".

## Tuning — all `var` (Rule 1).
var glow_radius: float = 14.0             ## px, roughly one voxel face — jittered per ember
var fade_power: float = 1.6               ## >1 = lingers bright, then drops fast

var min_glow_duration: float = 1.5        ## seconds, fastest-dying ember
var max_glow_duration: float = 4.0        ## seconds, slowest-dying ember

## Height bias: multiplies the random base duration by where an ember sits
## relative to the OTHER embers alive right now (screen Y — larger Y is
## lower/closer to the floor). Lower embers get a smaller multiplier (die
## sooner), higher embers a larger one (linger) — "heat rises".
var height_bias_low: float = 0.65         ## multiplier for the lowest ember on screen
var height_bias_high: float = 1.3         ## multiplier for the highest ember on screen

## Warm hue range for Color.from_hsv (0.0 = red, ~0.13 = yellow-orange).
var hue_min: float = 0.0
var hue_max: float = 0.13
var sat_min: float = 0.75
var sat_max: float = 0.95
var val_min: float = 0.85
var val_max: float = 1.0

var radius_jitter_min: float = 0.7        ## core-radius multiplier range (diffusion variety)
var radius_jitter_max: float = 1.4
var halo_scale_min: float = 1.6           ## soft outer halo, relative to core radius
var halo_scale_max: float = 2.4
var halo_alpha_factor: float = 0.35       ## halo is dimmer than the core at the same t

var pulse_speed_min: float = 2.0          ## cycles/sec, per-ember flicker frequency
var pulse_speed_max: float = 6.0
var pulse_amount_min: float = 0.15        ## +/- brightness swing from the flicker
var pulse_amount_max: float = 0.35

var ember_smoke_color: Color = Color(0.22, 0.18, 0.15, 0.55)  ## puff spawned on extinguish
var ember_smoke_scale: float = 0.5

var _embers: Array = []
## [{"pos", "elapsed", "duration", "color", "radius", "halo_scale",
##   "pulse_speed", "pulse_phase", "pulse_amount"}]

var _smoke_overlay: SmokeSparkOverlay = null  ## optional — puff-on-extinguish target


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Wire the overlay that receives a small puff when an ember burns out.
func set_smoke_overlay(overlay: SmokeSparkOverlay) -> void:
	_smoke_overlay = overlay


## Queue one glow at a voxel's world position (VoxelRenderer.voxel_world_position).
## duration <= 0 rolls a random one in [min_glow_duration, max_glow_duration],
## then applies the height bias below; a caller-supplied duration is used as
## the pre-bias base instead (still height-biased, never randomized further).
func add_ember(world_pos: Vector2, duration: float = -1.0) -> void:
	var base_duration: float = duration if duration > 0.0 else randf_range(min_glow_duration, max_glow_duration)
	var final_duration: float = base_duration * _height_bias(world_pos.y)
	var color := Color.from_hsv(
		randf_range(hue_min, hue_max),
		randf_range(sat_min, sat_max),
		randf_range(val_min, val_max),
		1.0)
	_embers.append({
		"pos": world_pos,
		"elapsed": 0.0,
		"duration": final_duration,
		"color": color,
		"radius": glow_radius * randf_range(radius_jitter_min, radius_jitter_max),
		"halo_scale": randf_range(halo_scale_min, halo_scale_max),
		"pulse_speed": randf_range(pulse_speed_min, pulse_speed_max),
		"pulse_phase": randf_range(0.0, TAU),
		"pulse_amount": randf_range(pulse_amount_min, pulse_amount_max),
	})
	set_process(true)


## Statistical bias, not a strict queue: normalizes `y` against the embers
## alive right now and lerps between height_bias_low/high. A lone ember (or
## an emptying overlay) gets a neutral 1.0 — there's nothing to be relatively
## lower or higher than yet.
func _height_bias(y: float) -> float:
	if _embers.is_empty():
		return 1.0
	var min_y: float = y
	var max_y: float = y
	for e in _embers:
		min_y = min(min_y, e["pos"].y)
		max_y = max(max_y, e["pos"].y)
	var range_y: float = max_y - min_y
	if range_y < 0.001:
		return 1.0
	var t: float = (y - min_y) / range_y
	return lerp(height_bias_high, height_bias_low, t)


func _process(delta: float) -> void:
	if _embers.is_empty():
		set_process(false)
		return
	var alive: Array = []
	for e in _embers:
		e["elapsed"] += delta
		if e["elapsed"] < e["duration"]:
			alive.append(e)
		elif _smoke_overlay != null:
			_smoke_overlay.add_smoke(e["pos"], ember_smoke_color, ember_smoke_scale)
	_embers = alive
	queue_redraw()


func _draw() -> void:
	for e in _embers:
		var t: float = e["elapsed"] / e["duration"]
		var pulse: float = 1.0 + e["pulse_amount"] * sin(e["elapsed"] * e["pulse_speed"] * TAU + e["pulse_phase"])
		var alpha: float = clampf(pow(1.0 - t, fade_power) * pulse, 0.0, 1.0)
		var core := e["color"] as Color
		core.a *= alpha
		draw_circle(e["pos"], e["radius"], core)
		var halo := e["color"] as Color
		halo.a *= alpha * halo_alpha_factor
		draw_circle(e["pos"], e["radius"] * e["halo_scale"], halo)


## Discard every in-flight glow (map load/reload — see class doc: nothing here
## is state a reload needs to restore, but stale positions from the PREVIOUS
## map would be meaningless in the new one).
func clear() -> void:
	_embers.clear()
	set_process(false)
	queue_redraw()
