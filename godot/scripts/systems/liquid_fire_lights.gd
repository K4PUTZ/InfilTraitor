## LiquidFireLights — a burning body lights its surroundings (Director, 2026-10-18): a few `LightSource`s along the body, each following the flame
## of the plane cells under it.
##
## TACTICAL (Director, 2026-10-18: "praticamente todas as luzes serao taticas, vamos acender e apagar para abrir caminhos"): the lights are registered in the
## `LightRegistry` (through `LightingController.add_extra_lights`) and are ACTIVE only while lit, so the shadow projector and the exposure system see a fire like a lamp;
## the room flips `active` with a hysteresis and re-projects the tactical layer on the flip.
##
## The board itself is lit by the CPU light buckets (`VoxelLightField`), never by Godot lights (they cost on the Mali, see the R3D-SPIKE-3D record): a fire is the same
## thing a lamp is, a light the field reads, plus a `warmth` that tints what it reaches (the cell plane's A channel).
##
## The field takes the BRIGHTEST light on a cell (not the sum), so a fire shows where the map's own lamps leave it dim: a dark scene is what lets it read.
## A light is ON while the flame under its patch (`LiquidFire.visual`) is lit, and its glow GROWS outward `GROW_GU` a step (`LightSource.reach`: a cell at distance d takes `clamp(reach - d, 0, 1)` of
## the light, so each ring fades in), and shrinks the same way when it goes out. The flame's breathing is the shader's (`fire_time`), never a repaint.
class_name LiquidFireLights
extends RefCounted

const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

const DEFAULT_RADIUS: int = 5
const DEFAULT_SPACING_GU: float = 2.0
const DEFAULT_WARMTH: float = 0.65
const DEFAULT_INNER: float = 0.5      ## the plateau of full light, as a share of the radius (a lamp's is 0.45)
const DEFAULT_ENERGY: float = 1.0
const ON_FROM: float = 0.2          ## a fire light is ACTIVE (tactical: shadows, exposure) from this flame up ...
const OFF_BELOW: float = 0.1        ## ... and stays so until it falls under this
const GROW_GU: float = 0.5          ## the glow grows (and shrinks) this far a step: two steps a GU, each ring fading in over its step
const STEP_S: float = 0.3           ## at the soonest, one step this often; a step waits until the previous one has been WRITTEN (the pace is the work's, so it is steady on a slow handset)

var lights: Array = []
var _burn: RefCounted = null
var _patches: Array = []   ## per light: PackedInt32Array of plane cell indices
var _energy: float = DEFAULT_ENERGY
var _since: float = 0.0


## `spec` is the liquid's `fire.light` ({radius, spacing, energy, warmth, inner, tint}); an `energy` of 0 makes none. `rect` is the body's interior (raw GU).
## `burn` is what lights it: a `LiquidFire` (a burning body) or a `LiquidGlow` (lava, a nuclear liquid: a body that is itself a light); both give a `plane`
## and a `visual` level per plane cell.
func setup(burn: RefCounted, rect: Rect2, spec: Dictionary) -> void:
	_burn = burn
	_energy = float(spec.get("energy", DEFAULT_ENERGY))
	if _energy <= 0.0:
		return
	var radius: int = maxi(int(spec.get("radius", DEFAULT_RADIUS)), 1)
	var spacing: float = maxf(float(spec.get("spacing", DEFAULT_SPACING_GU)), 0.5)
	var plane = burn.plane
	var along_y: bool = rect.size.y >= rect.size.x
	var length: float = rect.size.y if along_y else rect.size.x
	var count: int = maxi(int(round(length / spacing)), 1)
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var centre: Vector2 = Vector2(rect.get_center().x, rect.position.y + t * length) if along_y else Vector2(rect.position.x + t * length, rect.get_center().y)
		var patch_size: float = length / float(count)
		var patch: Rect2 = Rect2(Vector2(rect.position.x, centre.y - patch_size * 0.5), Vector2(rect.size.x, patch_size)) if along_y \
				else Rect2(Vector2(centre.x - patch_size * 0.5, rect.position.y), Vector2(patch_size, rect.size.y))
		var light = LightSourceClass.new()
		light.cell = Vector2i(int(floor(centre.x)), int(floor(centre.y)))
		light.height_class = LightSourceClass.HEIGHT_FLOOR
		light.radius = radius
		light.tactical_energy = 0.0
		light.active = false
		light.visual_energy = _energy
		light.warmth = float(spec.get("warmth", DEFAULT_WARMTH))
		light.inner_ratio = float(spec.get("inner", DEFAULT_INNER))
		light.tint = LightSourceClass.TINT_COOL if String(spec.get("tint", "warm")) == "cool" else LightSourceClass.TINT_WARM
		light.energy_multiplier = 1.0   ## the flame's own breathing is the shader's; the light is on or off, and GROWS (`reach`)
		light.last_energy = 1.0
		light.reach = 0.0
		light.light_id = "fire_light_%d" % lights.size()
		light.owner_name = light.light_id
		lights.append(light)
		_patches.append(plane.cells_in(patch))


## One step of every light: lit or put out by the flame under it, then its glow grows (or shrinks) `GROW_GU`. `can_step` is false while the previous step is still being written.
## Returns {"moved": [{light, from, to}] (the fronts that moved), "tactical": a light went on / off (shadows and exposure must be re-projected), "list": the set of lights the field
## draws changed (a fade ended)}.
func tick(delta: float, can_step: bool) -> Dictionary:
	var out: Dictionary = {"moved": [], "tactical": false, "list": false}
	if _burn == null:
		return out
	_since += delta
	if not can_step or _since < STEP_S:
		return out
	_since = 0.0
	for i in range(lights.size()):
		var flame: float = 0.0
		for cell: int in _patches[i]:
			flame = maxf(flame, _burn.visual[cell])
		var light = lights[i]
		var lit: bool = flame >= (OFF_BELOW if light.active else ON_FROM)
		if lit != light.active:   ## a fire that lights or goes out changes what a guard can see at once; only its glow takes its time
			light.active = lit
			light.tactical_energy = 1.0 if lit else 0.0
			light.fading = not lit and light.reach > 0.0
			out["tactical"] = true
			out["list"] = true
		var goal: float = float(light.radius) + 1.0 if light.active else 0.0
		if not is_equal_approx(light.reach, goal):
			var was: float = light.reach
			light.reach = move_toward(light.reach, goal, GROW_GU)
			(out["moved"] as Array).append({"light": light, "from": was, "to": light.reach})
			if not light.active and light.reach <= 0.0 and light.fading:
				light.fading = false
				out["list"] = true
	return out


## The GUs where a front moving from `a` to `b` changes the light: those at a distance in [min - 1, max] (a GU's share is `clamp(reach - d, 0, 1)`), inside the radius.
func annulus_gus(light, a: float, b: float) -> Array:
	var lo: float = minf(a, b) - 1.0
	var hi: float = maxf(a, b)
	var out: Array = []
	var r: int = int(ceil(float(light.radius)))
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var d: float = Vector2(dx, dy).length()
			if d <= float(light.radius) and d >= lo and d <= hi:
				out.append(light.cell + Vector2i(dx, dy))
	return out
