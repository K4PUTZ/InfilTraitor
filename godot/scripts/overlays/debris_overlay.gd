extends Node2D
class_name DebrisOverlay

## DebrisOverlay — floor-level VFX for VoxelBoard.voxel_destroyed: masonry
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
## in by the caller via VoxelBoard.voxel_world_position() — analytic, not
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

## --- Glass dust (G6b-3, GLASS_MASTER_PLAN §18) ---
## Director, 2026-09-05: *"1 efeito de pozinho branco se espalha horizontalmente,
## saindo por baixo dos cacos, com maior quantidade no ponto onde estava a vidraça
## e um pouco menos conseguem ir parar na segunda sub-GU mais próxima."* A ground
## puff, not a fall: specks push OUTWARD from the centre, concentrated near it, on
## an ellipse (flattened, because the isometric floor is foreshortened). All `var`.
var glass_dust_count_min: int = 10
var glass_dust_count_max: int = 18
var glass_dust_delay_min: float = 0.04    ## it puffs as the shards hit, not after
var glass_dust_delay_max: float = 0.16
var glass_dust_spread_min: float = 0.28   ## seconds the cloud takes to reach full radius
var glass_dust_spread_max: float = 0.46
var glass_dust_settle_min: float = 0.5
var glass_dust_settle_max: float = 0.9
var glass_dust_speck_radius: float = 2.0
var glass_dust_flatten: float = 0.5       ## vertical scale of the spread ellipse
var glass_dust_concentration: float = 1.7 ## r = reach * u^this — higher packs more near the centre
var glass_dust_alpha_gain: float = 1.35

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

## --- Sand trickle (R3D-LOOK item 2, Director 2026-10-05) ---
## What a round leaves running down a concrete / stone / brick wall: a THIN thread of single grains that start one after another, fall
## slowly down the face to the floor beneath, and lie there a moment before they fade. (`add_dust` is the blast's puff of a dozen
## specks falling together; this is not it.)
var trickle_count_min: int = 9
var trickle_count_max: int = 13
var trickle_delay: float = 0.5             ## seconds of stillness after the round, then it starts
var trickle_span_min: float = 0.35         ## seconds over which the grains are released, one after another
var trickle_span_max: float = 0.6
var trickle_fall_min: float = 0.45         ## each grain's own fall
var trickle_fall_max: float = 0.65
var trickle_rest_min: float = 0.3          ## seconds a grain lies on the floor, fading
var trickle_rest_max: float = 0.5
var trickle_sway: float = 1.1              ## px, how far a grain wanders sideways: a thread, not a cloud
var trickle_pile_spread: float = 3.2       ## px, how far along the floor the grains lie
var trickle_speck_radius: float = 1.0
var _trickles: Array = []
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
		"a2": origin,
		"a3": ParticleMathRef.anchor(_board, origin, target),  ## `target` is the floor beneath it
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


## Queue a trickle of sand from `origin` (the struck point) down to `target` (the floor beneath it).
func add_sand_trickle(origin: Vector2, target: Vector2, color: Color) -> void:
	var grains: Array = []
	var span: float = randf_range(trickle_span_min, trickle_span_max)
	for i in range(randi_range(trickle_count_min, trickle_count_max)):
		grains.append({
			"t0": trickle_delay + span * pow(randf(), 1.3),  ## released a little more densely at the start, then thinning out
			"fall": randf_range(trickle_fall_min, trickle_fall_max),
			"rest": randf_range(trickle_rest_min, trickle_rest_max),
			"sway": randf_range(-trickle_sway, trickle_sway),
			"lie": Vector2(randf_range(-trickle_pile_spread, trickle_pile_spread), randf_range(-0.4 * trickle_pile_spread, 0.4 * trickle_pile_spread)),
		})
	_trickles.append({"a2": origin, "a3": ParticleMathRef.anchor(_board, origin, target), "origin": origin, "target": target,
		"color": color, "elapsed": 0.0, "grains": grains})
	set_process(true)


## G6b-3 — a horizontal puff of glass dust from under a settled pile. `center` is
## the pile's world position, `reach` how far (px) the outermost specks push. The
## specks lerp to their OWN target (radial, concentrated near the middle); the
## delay/spread/settle machinery is `add_dust`'s, reused via the `"spread"` flag.
func add_glass_dust(center: Vector2, reach: float, color: Color) -> void:
	var speck_count: int = randi_range(glass_dust_count_min, glass_dust_count_max)
	var specks: Array = []
	for i in range(speck_count):
		var ang: float = randf() * TAU
		var r: float = reach * pow(randf(), glass_dust_concentration)
		specks.append(Vector2(cos(ang) * r, sin(ang) * r * glass_dust_flatten))
	_dust.append({
		"a2": center,
		"a3": ParticleMathRef.anchor(_board, center),  ## no floor point: on the ground (R3D-4e-4 refines)
		"origin": center,
		"target": center,           ## the cloud does not translate; the specks do
		"color": color,
		"delay": randf_range(glass_dust_delay_min, glass_dust_delay_max),
		"fall_duration": randf_range(glass_dust_spread_min, glass_dust_spread_max),
		"settle_duration": randf_range(glass_dust_settle_min, glass_dust_settle_max),
		"elapsed": 0.0,
		"specks": specks,
		"spread": true,
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
			"a2": origin,
			"a3": ParticleMathRef.anchor(_board, origin, target),  ## `target` is the floor beneath it
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
	if _dust.is_empty() and _chips.is_empty() and _trickles.is_empty():
		set_process(false)
		return

	var alive_dust: Array = []
	for d in _dust:
		## G6b-3 — the GLASS puff ages in FRAMES, not seconds. It is spawned on the
		## detonation's COMMIT frame (the stall), and a `delta`-aged effect started
		## there burns its whole life inside one stalled frame — the same trap the
		## shard rain and `EmberOverlay` learned. Blast dust/chips stay `delta`: they
		## fire on beat 3, not the stall.
		d["elapsed"] += (1.0 / 60.0) if d.get("spread", false) else delta
		var total: float = d["delay"] + d["fall_duration"] + d["settle_duration"]
		if d["elapsed"] < total:
			alive_dust.append(d)
	_dust = alive_dust

	var alive_trickles: Array = []
	for t in _trickles:
		t["elapsed"] += delta
		var ends: float = 0.0
		for g in t["grains"]:
			ends = maxf(ends, float(g["t0"]) + float(g["fall"]) + float(g["rest"]))
		if t["elapsed"] < ends:
			alive_trickles.append(t)
	_trickles = alive_trickles

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

## The dust specks and the chips are drawn by 3D board fields (`CircleField3D`, `QuadField3D`); with no board nothing is drawn
## (the 2D `CircleField` and `draw_*` fallbacks were removed in RETIRE-2D).
const CircleField3DRef = preload("res://godot/scripts/geometry/circle_field3d.gd")
const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
var _board: Node3D = null
var _dust_field3d: RefCounted = null
var _chip_field3d: RefCounted = null  ## R3D-4e-3: the rotated chips
const QuadField3DRef = preload("res://godot/scripts/geometry/quad_field3d.gd")


func set_board3d(board: Node3D) -> void:
	_board = board
	_dust_field3d = null
	_chip_field3d = null
	if board == null:
		return
	_chip_field3d = QuadField3DRef.new()
	_chip_field3d.attach_rect(board, 1)
	_dust_field3d = CircleField3DRef.new()
	_dust_field3d.attach(board, false, 0.75, 0)


func _draw() -> void:
	## PERF-P7a (VfxDrawProbe): `submit` hoisted into a local so the per-particle
	## test costs the same in both modes and cancels in FULL - NOOP. Dust is the
	## heaviest of the four — 7-12 commands per CLOUD, not per particle.
	var probing: bool = VfxDrawProbe.enabled
	var submit: bool = not VfxDrawProbe.noop
	var probe_t0: int = Time.get_ticks_usec() if probing else 0
	var drawn: int = 0
	var cmds: int = 0
	var mm3: RefCounted = _dust_field3d
	var cf3: RefCounted = _chip_field3d
	if mm3 == null or cf3 == null:
		return  ## no 3D board: nothing to draw on
	## Upper bound: every dust entry's specks. Over-reserving costs one resize
	## on the first big frame and nothing afterwards.
	var cap: int = 0
	for d0 in _dust:
		cap += (d0["specks"] as Array).size()
	for t0 in _trickles:
		cap += (t0["grains"] as Array).size()
	mm3.begin_on_board(cap)
	for d in _dust:
		var elapsed: float = d["elapsed"]
		var delay: float = d["delay"]
		var fall_duration: float = d["fall_duration"]
		var settle_duration: float = d["settle_duration"]
		if elapsed < delay:
			continue
		var is_spread: bool = d.get("spread", false)
		var pos: Vector2
		var alpha: float
		var speck_scale: float = 1.0   ## G6b-3 — spread mode grows each speck's offset
		if elapsed < delay + fall_duration:
			var t: float = (elapsed - delay) / fall_duration
			if is_spread:
				## The cloud stays put; the specks push OUTWARD on an ease-out.
				pos = d["origin"]
				speck_scale = 1.0 - (1.0 - t) * (1.0 - t)
			else:
				pos = lerp(d["origin"] as Vector2, d["target"] as Vector2, t)
			## E-DUST-01: FULL alpha while falling. This used to be `alpha = t`,
			## which meant the dust was invisible exactly when it was moving —
			## the one part of its life the eye could have caught.
			alpha = 1.0
		else:
			pos = d["target"] if not is_spread else d["origin"]
			var st: float = (elapsed - delay - fall_duration) / settle_duration
			alpha = pow(1.0 - st, dust_fade_power)
		var c: Color = d["color"]
		var gain: float = glass_dust_alpha_gain if is_spread else dust_alpha_gain
		c.a = minf(c.a * alpha * gain, 1.0)
		var radius: float = glass_dust_speck_radius if is_spread else dust_speck_radius
		drawn += 1
		cmds += (d["specks"] as Array).size()
		for offset in d["specks"]:
			var p: Vector2 = pos + (offset as Vector2) * speck_scale
			if submit:
				mm3.push(d["a3"], d["a2"], p, radius, c)
	for t in _trickles:
		var base: Color = t["color"]
		for g in t["grains"]:
			var age: float = float(t["elapsed"]) - float(g["t0"])
			if age < 0.0:
				continue
			var fall: float = g["fall"]
			var p: Vector2
			var a: float = 1.0
			if age < fall:
				var u: float = age / fall
				p = (t["origin"] as Vector2).lerp(t["target"] as Vector2, pow(u, 1.5)) + Vector2(float(g["sway"]) * sin(u * PI), 0.0)
			else:
				p = (t["target"] as Vector2) + (g["lie"] as Vector2)
				a = pow(1.0 - (age - fall) / float(g["rest"]), dust_fade_power)
			var c: Color = base
			c.a = minf(c.a * a * dust_alpha_gain, 1.0)
			drawn += 1
			cmds += 1
			if submit:
				mm3.push(t["a3"], t["a2"], p, trickle_speck_radius, c)
	mm3.flush()

	cf3.begin_on_board(_chips.size())
	for chip in _chips:
		var pos: Vector2 = chip["pos"]
		var alpha: float = 1.0
		if chip["elapsed"] >= chip["arc_duration"]:
			var st: float = (chip["elapsed"] - chip["arc_duration"]) / chip["settle_duration"]
			alpha = pow(1.0 - st, chip_fade_power)
		var c: Color = chip["color"]
		c.a *= alpha
		var half_w: float = chip["half_w"]
		var half_h: float = chip["half_h"]
		var rot: float = chip["rotation"]
		drawn += 1
		cmds += 1
		if submit:
			cf3.push_axes(chip["a3"], chip["a2"], pos,
				Vector2(half_w, 0.0).rotated(rot), Vector2(0.0, half_h).rotated(rot), c)
	cf3.flush()
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
	if _chip_field3d != null:
		_chip_field3d.clear()
	if _dust_field3d != null:
		_dust_field3d.clear()
	_dust.clear()
	_trickles.clear()
	_chips.clear()
	set_process(false)
	queue_redraw()
