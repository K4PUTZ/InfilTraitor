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
## E-EMBER-02 tuning pass (filmstrip, 2026-08-13): 14.0 with the old halo made
## ~137 overlapping ADD circles read as one molten sheet the shape of the crater
## rather than as coals. Radius, halo reach and halo alpha all came down
## together — the halo is what was filling the gaps BETWEEN embers into a
## continuous surface, so shrinking only the core would not have separated them.
var glow_radius: float = 9.0              ## px, under one voxel face — jittered per ember
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
##
## E-EMBER-02 (Director, 2026-08-13): an ember no longer keeps ONE rolled hue for
## its whole life — it COOLS. *"voxels bem vermelhos e brilhantes, que vão
## ficando amarelos e apagando até sobrar só preto-carvão"*, corrected by the
## Director on the next message to run the physical way round: **yellow-hot
## first, reddening as it dies.** A real ember goes white/yellow -> orange ->
## red -> dark, and the original text had it inverted.
##
## Each ember still rolls its OWN pair of endpoints rather than sharing one
## global ramp, which is what keeps "durações e velocidades ligeiramente
## diferentes" true of the colour too: at any instant a patch shows a spread of
## tones, not one tone marching in lockstep. `hue_hot` is rolled in the yellow
## half and `hue_cold` in the red half, so the direction can never invert on a
## bad roll.
var hue_hot_min: float = 0.075              ## t=0 end — orange-yellow
var hue_hot_max: float = 0.145
var hue_cold_min: float = 0.0               ## t=1 end — deep red
var hue_cold_max: float = 0.035
var sat_min: float = 0.75
var sat_max: float = 0.95
## Saturation RISES as it cools (a dying coal is deep red, not pale red), so
## this is added to the rolled saturation across the life rather than subtracted.
var sat_cool_gain: float = 0.18
## Down from 0.85-1.0 in the same pass. Under ADD, N overlapping embers sum, so
## the per-ember value that reads correct ALONE blows out to white in a crowd —
## and a crowd is the normal case for a real crater, not the exception.
var val_min: float = 0.60
var val_max: float = 0.85
## Value falls to this fraction of the rolled one by the end — the "apagando até
## sobrar só preto-carvão" half. It never reaches the charcoal itself: the tile
## underneath is ALREADY charred by soot the instant the blast lands, so the
## last thing this overlay does is get out of the way and let it show (VL-D4's
## own "cooling is really revealing, not a second darkening pass").
var val_cool_floor: float = 0.35

## D-4 (Director, 2026-08-29: *"um pouquinho de brasa nos materiais moles… vermelho
## brilhando que vira preto"*) — the boost a BURNT ember gets over an edge ember.
## `DetonationPlanBuilder._mark_burnt_embers()` flags the embers that sit on cells
## the fire consumed; `DetonationEntryWriter` reads these three and passes them to
## `add_ember()` as `radius_scale`, a `duration_scale` multiplier, and `cool_rate`.
## An edge ember (unflagged) is byte-for-byte unchanged, so wood's ratified VL-D4
## look — which produces no burnt cells — never sees this.
##
## ⚠️ KEPT SMALL ON PURPOSE. The first cut (1.6× on both radius and life) turned a
## fabric wall's ~235 consumed voxels into one blown-out yellow fireball under ADD
## — the exact "molten sheet" E-EMBER-02 lowered `val_*` to avoid. "Um pouquinho"
## is a whisper over the glow that was already there, not a bonfire.
var burnt_ember_radius_gain: float = 1.18  ## a touch wider than an edge coal
var burnt_ember_life_gain: float = 1.15    ## lingers slightly longer
var burnt_ember_cool_rate: float = 0.85    ## <1 holds the red a little before charcoal

## E-EMBER-03 (Director, 2026-08-13): *"a gente conseguiria passar de amarelo
## pra vermelho vivo mais rápido, antes de apagarem?"*
##
## The two ramps were both linear in `t`, which spent the ember's whole life
## drifting through orange and never gave the vivid red a moment of its own.
## They are now eased in OPPOSITE directions, and that opposition is the whole
## trick:
##   · hue  — exponent < 1, so the yellow is a flash and the ember is essentially
##            red by the first third of its life;
##   · value — exponent > 1, so brightness HOLDS near full through that same
##            stretch and only then drops away.
## Together: a brief yellow, then a long *bright* red, then the fade. Easing the
## hue alone would have produced a red that was already dim by the time it
## arrived, which is the opposite of "vivo".
var hue_cool_ease: float = 0.40   ## <1 reaches the cold hue early
var val_cool_ease: float = 1.80   ## >1 holds brightness, then falls off

var radius_jitter_min: float = 0.7        ## core-radius multiplier range (diffusion variety)
var radius_jitter_max: float = 1.4
var halo_scale_min: float = 1.25          ## soft outer halo, relative to core radius
var halo_scale_max: float = 1.8
var halo_alpha_factor: float = 0.20       ## halo is dimmer than the core at the same t

var pulse_speed_min: float = 2.0          ## cycles/sec, per-ember flicker frequency
var pulse_speed_max: float = 6.0
var pulse_amount_min: float = 0.15        ## +/- brightness swing from the flicker
var pulse_amount_max: float = 0.35

## The puff spawned when an ember burns out — E-EMBER-02: *"ao apagar, cada
## voxel gera mais fumaça escura, e finaliza."* Darker and larger than the
## 2026-07-26 original, and scaled by the ember's OWN radius so a fat coal
## leaves a fat puff instead of every death producing the identical blob.
var ember_smoke_color: Color = Color(0.13, 0.11, 0.10, 0.72)
var ember_smoke_scale: float = 0.85
var ember_smoke_radius_gain: float = 0.5  ## how much the ember's radius jitter feeds the puff size

var _embers: Array = []
## [{"pos", "vel", "drag", "rise", "delay", "elapsed", "duration",
##   "hue_hot", "hue_cold", "sat", "val", "radius", "halo_scale",
##   "pulse_speed", "pulse_phase", "pulse_amount"}]
## E-EMBER-02 replaced the single rolled "color" with the hue_hot/hue_cold/sat/
## val quartet ember_color_at() ramps between; "delay" arrived with it.

var _smoke_overlay: SmokeSparkOverlay = null  ## optional — puff-on-extinguish target

## PERF-P7b (§12.10) — two `draw_circle` per ember, 24.0% of the whole VFX
## `_draw()` before the puffs moved and 64.3% after. Same `CircleField` the smoke
## uses; opt IN with `INFILTRAITOR_P7B=1`.
var _field: CircleField = null


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if SmokeSparkOverlay.P7B_MULTIMESH:
		_field = CircleField.new()
		## ADD, matching the material above. `behind` is not needed and is not
		## passed: additive compositing is order-independent, so core-then-halo
		## and halo-then-core produce the same pixels — which is also why the two
		## can share ONE instance buffer instead of needing two passes.
		_field.attach(self, CanvasItemMaterial.BLEND_MODE_ADD)


## Wire the overlay that receives a small puff when an ember burns out.
func set_smoke_overlay(overlay: SmokeSparkOverlay) -> void:
	_smoke_overlay = overlay


## Queue one glow at a voxel's world position (VoxelRenderer.voxel_world_position).
## duration <= 0 rolls a random one in [min_glow_duration, max_glow_duration],
## then applies the height bias below; a caller-supplied duration is used as
## the pre-bias base instead (still height-biased, never randomized further).
## P-FIRE (Director, 2026-08-09): "o fogo está praticamente parado no lugar."
## It was — an ember has always been a glow pinned to one point, which is right
## for the thing this overlay was built for (a scorched voxel cooling down) and
## wrong for a fireball.
##
## `velocity` and `drag` are trailing and default to zero, so every existing
## caller — the per-voxel scorch embers, which SHOULD stay pinned to their
## voxel — is byte-for-byte unaffected. Only Room.spawn_blast_burst() passes
## them.
##
## `drag` is an exponential decay on the velocity, not a linear one: an
## explosion throws its fire out hard and then it coasts to a stop, which is
## exactly `v *= exp(-drag·dt)`. A linear damp would make the expansion end
## abruptly at a fixed time instead of easing out of it.
##
## `rise` is separate from `velocity` and is applied as a constant, undecayed
## upward drift — buoyancy does not run out of steam the way the blast impulse
## does, so folding it into the velocity (and letting drag eat it) would make
## the fire stop climbing right when a real one keeps going.
## `duration_scale` is E-EMBER-01's seam for the material table's
## `flammability`: it multiplies the duration this ember would otherwise have,
## whether that came from the random roll or from an explicit `duration`.
## Trailing and defaulting to 1.0, so it is a no-op for every pre-existing
## caller — the same "optional, default no-op" idiom E-CONTRAST-03 used for
## `shade_brightness`.
##
## `smoke_on_death` (E-MUZZLE-02) exists because of a real, and initially
## misdiagnosed, defect. A dying ember hands a puff to the smoke overlay so it
## reads as "went out" — correct for a coal, wrong for a MUZZLE FLASH, whose
## eight big embers each dropped a dark `ember_smoke_color` (0.13/0.11/0.10 at
## alpha 0.72) blob scaled by their own radius, right where the flash had been.
## That black hole in the middle of the flash was chased through two spatial
## fixes and a delay on the WRONG smoke before a capture at +9 frames showed the
## blob was dark BROWN, not the pale grey the muzzle's own puff uses.
##
## `radius_scale` (E-MUZZLE-01) is the same idiom for SIZE. It exists because
## `glow_radius` was tuned DOWN to 9 px for the crater's per-voxel coals, and a
## muzzle flash is not a coal — without it the flash inherited a scorch ember's
## dimensions and read as a few sparks with nothing behind them. Scaling the ROLL rather than replacing it is the whole
## point: passing an absolute `duration` would flatten the 1.5-4.0 spread that
## makes a scorched patch cool unevenly, which is the look VL-D4 shipped.
## `delay` (E-EMBER-02) holds an ember dark and motionless before it catches —
## the seam the upward propagation uses (`DetonationPlanBuilder._build_ember_wave()`
## staggers a climb so fire creeps up a wall instead of the whole column lighting
## at once). Trailing and zero by default, so it costs existing callers nothing.
## Deliberately NOT a timer or a tween per ember: this overlay already owns a
## per-frame loop over its own entries, and a few hundred SceneTreeTimers would
## be a second scheduler for something one float already expresses.
func add_ember(world_pos: Vector2, duration: float = -1.0,
		velocity: Vector2 = Vector2.ZERO, drag: float = 0.0,
		rise: float = 0.0, duration_scale: float = 1.0,
		delay: float = 0.0, radius_scale: float = 1.0, cool_rate: float = 1.0,
		smoke_on_death: bool = true) -> void:
	## PERF-P7a §8.4 — `_height_bias()` walks every ember already alive, so
	## spawning N of them is O(N^2). Timed here rather than inferred: it is a
	## one-off at the spawn frame, which is exactly why §3.4's per-frame hiding
	## experiments could not have seen it.
	var probe_t0: int = Time.get_ticks_usec() if VfxDrawProbe.enabled else 0
	var base_duration: float = duration if duration > 0.0 else randf_range(min_glow_duration, max_glow_duration)
	var final_duration: float = base_duration * maxf(duration_scale, 0.01) * _height_bias(world_pos.y)
	if VfxDrawProbe.enabled:
		VfxDrawProbe.spawn_us += Time.get_ticks_usec() - probe_t0
		VfxDrawProbe.spawn_n += 1
	_embers.append({
		"pos": world_pos,
		"vel": velocity,
		"drag": drag,
		"rise": rise,
		"delay": maxf(delay, 0.0),
		"elapsed": 0.0,
		"duration": final_duration,
		## E-EMBER-02: the two ends of this ember's own cooling ramp, rolled
		## once here and lerped per frame in _draw(). Saturation and value are
		## the t=0 values; both are walked by the ramp too.
		"hue_hot": randf_range(hue_hot_min, hue_hot_max),
		"hue_cold": randf_range(hue_cold_min, hue_cold_max),
		"sat": randf_range(sat_min, sat_max),
		"val": randf_range(val_min, val_max),
		"radius": glow_radius * radius_scale * randf_range(radius_jitter_min, radius_jitter_max),
		"cool_rate": maxf(cool_rate, 0.0),
		"smoke_on_death": smoke_on_death,
		"halo_scale": randf_range(halo_scale_min, halo_scale_max),
		"pulse_speed": randf_range(pulse_speed_min, pulse_speed_max),
		"pulse_phase": randf_range(0.0, TAU),
		"pulse_amount": randf_range(pulse_amount_min, pulse_amount_max),
	})
	set_process(true)


## E-EMBER-02 — one ember's colour at life fraction `t`. Hue walks hot->cold,
## saturation deepens, value falls toward `val_cool_floor`. Kept as its own
## function so a selftest can assert the ramp's DIRECTION without constructing
## a frame loop, which is the part that was wrong in the Director's first
## description and is worth pinning.
func ember_color_at(e: Dictionary, t: float) -> Color:
	## E-MUZZLE-01: `cool_rate` scales how fast this ember walks its own ramp.
	## 1.0 is every scorch ember (cools across its life); 0.0 pins it at the hot
	## end forever, which is what a MUZZLE FLASH is — it does not cool down, it
	## stops. Without this the flash inherited E-EMBER-03's deliberately fast
	## yellow->red easing and photographed as a small red fireball.
	var k: float = clampf(t * float(e.get("cool_rate", 1.0)), 0.0, 1.0)
	## E-EMBER-03: hue runs ahead of brightness, deliberately. See hue_cool_ease.
	var k_hue: float = pow(k, hue_cool_ease)
	var k_val: float = pow(k, val_cool_ease)
	return Color.from_hsv(
		lerpf(float(e["hue_hot"]), float(e["hue_cold"]), k_hue),
		clampf(float(e["sat"]) + sat_cool_gain * k_hue, 0.0, 1.0),
		float(e["val"]) * lerpf(1.0, val_cool_floor, k_val),
		1.0)


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
	## §12.12 — this overlay's per-frame aging walk, priced.
	var _pp0: int = Time.get_ticks_usec() if VfxDrawProbe.enabled else 0
	if _embers.is_empty():
		set_process(false)
		return
	var alive: Array = []
	for e in _embers:
		## E-EMBER-02: an ember that has not caught yet burns down its delay and
		## nothing else — it does not age, move, or draw. Checked before
		## `elapsed` advances so a delayed ember's own duration is never eaten
		## by the wait.
		var wait: float = float(e.get("delay", 0.0))
		if wait > 0.0:
			e["delay"] = wait - delta
			alive.append(e)
			continue
		e["elapsed"] += delta
		## P-FIRE: a still ember costs one dictionary read and nothing else —
		## the pinned per-voxel scorch embers never enter this branch.
		var vel: Vector2 = e.get("vel", Vector2.ZERO)
		var rise: float = float(e.get("rise", 0.0))
		if vel != Vector2.ZERO or rise != 0.0:
			e["pos"] = e["pos"] + vel * delta + Vector2(0.0, -rise) * delta
			var drag: float = float(e.get("drag", 0.0))
			if drag > 0.0:
				e["vel"] = vel * exp(-drag * delta)
		if e["elapsed"] < e["duration"]:
			alive.append(e)
		elif _smoke_overlay != null and bool(e.get("smoke_on_death", true)):
			## E-EMBER-02: the puff inherits this ember's own size, so the death
			## of a big coal reads bigger than the death of a small one.
			_smoke_overlay.add_smoke(e["pos"], ember_smoke_color,
				ember_smoke_scale * (1.0 + ember_smoke_radius_gain
					* (float(e["radius"]) / maxf(glow_radius, 0.001) - 1.0)))
	_embers = alive
	queue_redraw()


	if VfxDrawProbe.enabled:
		VfxDrawProbe.note_process(&"EmberOverlay", Time.get_ticks_usec() - _pp0)

func _draw() -> void:
	## PERF-P7a (VfxDrawProbe): `submit` is hoisted into a local so the
	## per-particle test is a bool read that costs the SAME in both probe modes
	## and cancels in the FULL - NOOP subtraction. Two commands per ember.
	var probing: bool = VfxDrawProbe.enabled
	var submit: bool = not VfxDrawProbe.noop
	var probe_t0: int = Time.get_ticks_usec() if probing else 0
	var drawn: int = 0
	var mm: CircleField = _field
	if mm != null:
		mm.begin(_embers.size() * 2)
	for e in _embers:
		## E-EMBER-02: an ember still counting down its delay is not on fire yet
		## and draws nothing at all.
		if float(e.get("delay", 0.0)) > 0.0:
			continue
		var t: float = e["elapsed"] / e["duration"]
		var pulse: float = 1.0 + e["pulse_amount"] * sin(e["elapsed"] * e["pulse_speed"] * TAU + e["pulse_phase"])
		var alpha: float = clampf(pow(1.0 - t, fade_power) * pulse, 0.0, 1.0)
		## Rolled once per FRAME, not once per ember: the whole point of
		## E-EMBER-02 is that the colour itself cools as the glow dies.
		var hot := ember_color_at(e, t)
		var core := hot
		core.a *= alpha
		var halo := hot
		halo.a *= alpha * halo_alpha_factor
		drawn += 1
		if submit:
			if mm != null:
				mm.push(e["pos"], e["radius"], core)
				mm.push(e["pos"], e["radius"] * e["halo_scale"], halo)
			else:
				draw_circle(e["pos"], e["radius"], core)
				draw_circle(e["pos"], e["radius"] * e["halo_scale"], halo)
	if mm != null:
		mm.flush()
	if probing:
		## §12.10 — timed ONCE and folded into both the global counters and this
		## overlay's own row, so the split can never disagree with the total.
		var probe_us: int = Time.get_ticks_usec() - probe_t0
		VfxDrawProbe.draw_us += probe_us
		VfxDrawProbe.particles += drawn
		VfxDrawProbe.commands += drawn * 2
		VfxDrawProbe.note(&"EmberOverlay", probe_us, drawn * 2)


## Discard every in-flight glow (map load/reload — see class doc: nothing here
## is state a reload needs to restore, but stale positions from the PREVIOUS
## map would be meaningless in the new one).
func clear() -> void:
	if _field != null:
		_field.clear()
	_embers.clear()
	set_process(false)
	queue_redraw()
