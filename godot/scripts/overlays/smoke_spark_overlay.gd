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
## Duration and rise lifted twice on 2026-08-08, both times by the Director.
## First pass ("aumentar um pouco... subir um pouco mais alto"): 0.6/1.0 s and
## 18-32 px/s became 1.0/1.8 s and 34-58 px/s. Second pass, after watching it:
## "pode deixar a fumaça mais tempo no final, subindo mais alto — a explosão já
## acabou, não temos mais pressa." The blast's own beat is over by ~250 ms, so
## the smoke is the only thing left on screen and has no reason to hurry off it.
##
## These are the overlay's own defaults, so the change reaches VFX-01's per-voxel
## destruction puffs and EmberOverlay's burn-out puffs too — which is what
## "geral" asks for, and both are the same smoke from the player's side.
var smoke_duration_min: float = 1.8       ## seconds
var smoke_duration_max: float = 3.2
var smoke_start_radius: float = 6.0
var smoke_end_radius: float = 16.0
var smoke_drift_x: float = 10.0           ## px/sec horizontal jitter range
var smoke_drift_y_min: float = 48.0       ## px/sec upward drift range
var smoke_drift_y_max: float = 82.0
## Raised from 0.4 -> 0.62 -> 0.78 alongside the drift, and it is the number that
## actually governs height: damping is applied as pow(damping, delta) per second,
## so at 0.4 a puff lost ~60% of its rise in the FIRST second and then coasted no
## matter how fast it launched. Lifting the launch velocity without lifting this
## buys almost nothing — measured across both of the Director's passes.
var smoke_drift_damping: float = 0.78     ## exponential decay applied to velocity per second
var smoke_fade_power: float = 1.4
var smoke_spawn_jitter: float = 4.0       ## px, per-blob offset from the requested position

## --- Sparks ---
## E-SPARK-02 (Director, 2026-08-13): *"consigo ver algumas faíscas na explosão,
## mas bem modestas. Vamos aumentar a quantidade e fazer elas voarem um
## pouquinho mais tempo pra ficarem mais evidentes. Não precisa ser só a
## partícula, pode ter um rastro suave."*
##
## Lifetime and reach both up. The trail already existed at 5 px, which is under
## a third of a voxel face — at that length a streak is indistinguishable from
## the dot that draws it, which is why the effect read as "só a partícula".
##
## The trail is now drawn as a TAPERED, FADING streak instead of one flat line:
## a hot head, a dimmer tail, thinning toward the back. That is what makes it
## read as motion rather than as a dash — and it is built from `draw_line`
## segments this overlay already used, not from a new texture or a particle
## system (E-NATIVE-01: this project builds its VFX out of its own vocabulary).
var spark_speed_min: float = 90.0         ## px/sec
var spark_speed_max: float = 220.0
## E-SPARK-03 (Director, 2026-08-13): *"as faíscas não precisam cair, só voam
## em todas as direções e somem."* Zero, not a small value — the whole read the
## Director asked for is a radial burst that dies where it flew, and any gravity
## at all bends the streaks into a fountain, which is a different picture. The
## var stays (Rule 1, and a future incendiary round may well want it back).
var spark_gravity: float = 0.0            ## px/sec^2, downward
var spark_duration_min: float = 0.45      ## seconds — brief, but long enough to read
var spark_duration_max: float = 0.85
var spark_trail_length: float = 15.0      ## px, streak drawn behind the spark
var spark_trail_segments: int = 4         ## tapered/fading steps along the streak
var spark_trail_tail_alpha: float = 0.12  ## alpha multiplier at the far end of the trail
var spark_width: float = 1.9
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
## `drift_scale` (E-MUZZLE-02, 2026-08-13): multiplies the upward drift for this
## puff only. Powder smoke at a barrel is not the same gas as a crater's plume —
## the Director's own note: *"a fumaça das armas demora demais pra acabar e sobe
## muito."* The alternative was lowering `smoke_drift_y_*`, which every blast
## puff on the map also reads. Trailing + defaulted to 1.0, so every existing
## caller is byte-for-byte unaffected.
## `delay` (E-MUZZLE-02, 2026-08-13) holds a puff dormant before it exists —
## same idiom, same reason, as EmberOverlay's own `delay`.
##
## It is what finally fixes the muzzle flash's black middle, and the fix is
## TEMPORAL rather than spatial on purpose. This overlay draws one z-index ABOVE
## EmberOverlay, so any puff overlapping the flash paints a dark disc over it.
## Two spatial attempts failed for the same reason: behind the barrel it hid
## behind the gun, and in front it still reached the core, because the flash's
## own halo is ~45 px across. Pushing it clear would have detached the smoke from
## the weapon entirely. Powder smoke FOLLOWS the flash — it does not coexist with
## it — so the puff now simply waits for the flash to finish.
func add_smoke(pos: Vector2, color: Color, scale: float = 1.0, duration_scale: float = 1.0,
		blob_count_override: int = 0, drift_scale: float = 1.0,
		delay: float = 0.0) -> void:
	var blob_count: int = blob_count_override if blob_count_override > 0 \
		else randi_range(smoke_blob_count_min, smoke_blob_count_max)
	for i in range(blob_count):
		var offset := Vector2(randf_range(-smoke_spawn_jitter, smoke_spawn_jitter),
			randf_range(-smoke_spawn_jitter, smoke_spawn_jitter)) * scale
		var vel := Vector2(randf_range(-smoke_drift_x, smoke_drift_x),
			-randf_range(smoke_drift_y_min, smoke_drift_y_max) * drift_scale)
		_smoke.append({
			"pos": pos + offset,
			"vel": vel,
			"elapsed": 0.0,
			"delay": maxf(delay, 0.0),
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
		## E-MUZZLE-02: a delayed puff burns its delay down and does nothing else
		## — it does not age, drift or draw. Checked before `elapsed` advances so
		## the wait never eats the puff's own lifetime.
		var wait: float = float(s.get("delay", 0.0))
		if wait > 0.0:
			s["delay"] = wait - delta
			alive_smoke.append(s)
			continue
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
		if float(s.get("delay", 0.0)) > 0.0:
			continue
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
		var vel: Vector2 = p["vel"]
		if vel.length() <= 0.01:
			c.a *= alpha
			draw_line(p["pos"], p["pos"], c, spark_width)
			continue
		## E-SPARK-02: the streak is walked back from the head in segments, each
		## dimmer and thinner than the last. Length follows SPEED, so a fast
		## spark draws a long streak and one that has been slowed by gravity
		## draws a short one — the trail reports the motion instead of being a
		## fixed decoration stuck to every particle.
		var dir: Vector2 = vel.normalized()
		var reach: float = spark_trail_length * clampf(
			vel.length() / maxf(spark_speed_max, 0.001), 0.25, 1.0)
		var segs: int = maxi(spark_trail_segments, 1)
		for i in range(segs):
			var a0: float = float(i) / float(segs)
			var a1: float = float(i + 1) / float(segs)
			var seg := c
			seg.a = c.a * alpha * lerpf(1.0, spark_trail_tail_alpha, a0)
			draw_line(p["pos"] - dir * reach * a0, p["pos"] - dir * reach * a1,
				seg, spark_width * lerpf(1.0, 0.35, a0))


## Discard every in-flight puff/spark (map load/reload) — same reasoning as
## EmberOverlay.clear(): nothing here is state a reload needs to restore.
func clear() -> void:
	_smoke.clear()
	_sparks.clear()
	set_process(false)
	queue_redraw()
