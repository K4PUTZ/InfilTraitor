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
## E-DUST-01 (Director, 2026-08-13): *"poeira também não consigo ver."*
##
## It was invisible BY CONSTRUCTION, not too faint — three things stacked:
##   1. `dust_delay` held it for 0.9-1.1 s before it started falling, drawing
##      nothing at all in the meantime;
##   2. during the fall the alpha ramped `0 → 1` (`alpha = t` in _draw()), so
##      dust FADED IN from invisible instead of being visible as it dropped;
##   3. 3-5 specks at 1.6 px radius is a few pixels of near-background grey.
##
## The 1 s delay itself was the Director's own earlier request ("depois de 1
## segundo") and is KEPT as an idea — dust hangs, then falls — but shortened,
## because a full second after a gunshot is past the moment anyone is looking.
## The fade-in is gone: falling dust is visible while it falls.
var dust_delay_min: float = 0.25          ## seconds before it starts falling
var dust_delay_max: float = 0.45
var dust_fall_duration_min: float = 0.45
var dust_fall_duration_max: float = 0.75
var dust_settle_duration_min: float = 0.7
var dust_settle_duration_max: float = 1.2
var dust_speck_count_min: int = 7
var dust_speck_count_max: int = 12
var dust_speck_spread: float = 9.0        ## px, cluster radius around the falling point
var dust_speck_radius: float = 2.6
var dust_alpha_gain: float = 1.7          ## E-DUST-01 — the specks were near-background grey
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
	## §12.12 — this overlay's per-frame aging walk, priced.
	var _pp0: int = Time.get_ticks_usec() if VfxDrawProbe.enabled else 0
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


	if VfxDrawProbe.enabled:
		VfxDrawProbe.note_process(&"DebrisOverlay", Time.get_ticks_usec() - _pp0)

## PERF-P7c (§12.12) — the dust SPECKS are `draw_circle` and are this overlay's
## bulk (`cmds += specks.size()` against one command per chip), so they take the
## same `CircleField` the puffs and embers took. The CHIPS stay on
## `draw_colored_polygon`: a rotated quad is not a circle, and at one command each
## they are not what costs.
##
## No `material` on this node, so MIX — and `behind` keeps the dust under the
## chips, which is the order `_draw()` has always used.
var _dust_field: CircleField = null


func _ready() -> void:
	if SmokeSparkOverlay.P7B_MULTIMESH:
		_dust_field = CircleField.new()
		## D-4 — the SAME soft rim the smoke puffs got, on the same primitive.
		##
		## ⚠️ An earlier version of this comment claimed the dust was "the most
		## visually prominent thing in the crater". It is NOT, and the correction is
		## worth keeping because it cost a probe to get: with dust forced BLUE and
		## smoke forced GREEN on a real concrete blast, the dust peaked at **11
		## sampled pixels** (noise, on a pre-blast frame) against the smoke's 162.
		## `dust_speck_radius` is 2.6 px — the big dark discs in a crater were never
		## dust, they are SMOKE. The feather here is consistency, not a fix.
		_dust_field.attach(self, CanvasItemMaterial.BLEND_MODE_MIX, true, 0.6)


func _draw() -> void:
	## PERF-P7a (VfxDrawProbe): `submit` hoisted into a local so the per-particle
	## test costs the same in both modes and cancels in FULL - NOOP. Dust is the
	## heaviest of the four — 7-12 commands per CLOUD, not per particle.
	var probing: bool = VfxDrawProbe.enabled
	var submit: bool = not VfxDrawProbe.noop
	var probe_t0: int = Time.get_ticks_usec() if probing else 0
	var drawn: int = 0
	var cmds: int = 0
	var mm: CircleField = _dust_field
	if mm != null:
		## Upper bound: every dust entry's specks. Over-reserving costs one resize
		## on the first big frame and nothing afterwards.
		var cap: int = 0
		for d0 in _dust:
			cap += (d0["specks"] as Array).size()
		mm.begin(cap)
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
			## E-DUST-01: FULL alpha while falling. This used to be `alpha = t`,
			## which meant the dust was invisible exactly when it was moving —
			## the one part of its life the eye could have caught.
			alpha = 1.0
		else:
			pos = d["target"]
			var st: float = (elapsed - delay - fall_duration) / settle_duration
			alpha = pow(1.0 - st, dust_fade_power)
		var c: Color = d["color"]
		c.a = minf(c.a * alpha * dust_alpha_gain, 1.0)
		drawn += 1
		cmds += (d["specks"] as Array).size()
		for offset in d["specks"]:
			if submit:
				if mm != null:
					mm.push(pos + offset, dust_speck_radius, c)
				else:
					draw_circle(pos + offset, dust_speck_radius, c)
	if mm != null:
		mm.flush()

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
		drawn += 1
		cmds += 1
		if submit:
			draw_colored_polygon(points, c)
	if probing:
		## §12.10 — timed ONCE and folded into both the global counters and this
		## overlay's own row, so the split can never disagree with the total.
		var probe_us: int = Time.get_ticks_usec() - probe_t0
		VfxDrawProbe.draw_us += probe_us
		VfxDrawProbe.particles += drawn
		VfxDrawProbe.commands += cmds
		VfxDrawProbe.note(&"DebrisOverlay", probe_us, cmds)


## Discard every in-flight dust/chip (map load/reload) — same reasoning as
## EmberOverlay.clear(): nothing here is state a reload needs to restore.
func clear() -> void:
	if _dust_field != null:
		_dust_field.clear()
	_dust.clear()
	_chips.clear()
	set_process(false)
	queue_redraw()
