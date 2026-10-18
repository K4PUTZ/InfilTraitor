## LiquidFireLights — a burning body lights its surroundings (Director, 2026-10-18): a few VISUAL-ONLY `LightSource`s along the body, each following the flame
## of the plane cells under it.
##
## The board is lit by the CPU light buckets (`VoxelLightField`), never by Godot lights (they cost on the Mali, see the R3D-SPIKE-3D record), so a fire is the same
## thing a lamp is: a light the field reads. These are NOT in the `LightRegistry`: that registry feeds the tactical shadows and the exposure system, and a fire
## must not change what a guard sees (visual brightness is not tactical visibility). The room hands them to the field next to the registry's lights
## (`Room.field_lights()`); `tactical_energy` is 0 for the same reason.
##
## The field takes the BRIGHTEST light on a cell (not the sum), so a fire shows where the map's own lamps leave it dim: a dark scene is what lets it read.
## A light's energy is the flame of its patch (`LiquidFire.visual`, 0..1) with a slow flicker, quantised to `STEP` so the repaint it causes is a few a second.
class_name LiquidFireLights
extends RefCounted

const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

const DEFAULT_RADIUS: int = 3
const DEFAULT_SPACING_GU: float = 2.0
const DEFAULT_ENERGY: float = 1.0
const STEP: float = 0.2             ## energies are rounded to this: a repaint only when a light moves a whole step
const INTERVAL_S: float = 0.4       ## the lights are re-read this often
const LEVELS_BELOW: int = 4          ## the levels a fire light repaints: from the floor top down this far (a dug channel) ...
const LEVELS_ABOVE: int = 0          ## ... and this far above the walkable plane (each uploaded level costs ~3.7 ms on the desktop: the plane is rebuilt whole)
const FLICKER_DEPTH: float = 0.2    ## how far the flicker pulls a flame's light down

var lights: Array = []
var _burn: RefCounted = null
var _patches: Array = []   ## per light: PackedInt32Array of plane cell indices
var _energy: float = DEFAULT_ENERGY
var _clock: float = 0.0
var _since: float = 0.0


## `spec` is the liquid's `fire.light` ({radius, spacing, energy}); an `energy` of 0 makes none. `rect` is the body's interior (raw GU).
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
		light.visual_energy = _energy
		light.energy_multiplier = 0.0
		light.last_energy = 0.0
		light.light_id = "fire_light_%d" % lights.size()
		light.owner_name = light.light_id
		lights.append(light)
		_patches.append(plane.cells_in(patch))


## The lights whose energy moved a whole step since the last call (empty most frames). Each already carries its new `energy_multiplier`.
func tick(delta: float) -> Array:
	var changed: Array = []
	if _burn == null:
		return changed
	_clock += delta
	_since += delta
	if _since < INTERVAL_S:
		return changed
	_since = 0.0
	for i in range(lights.size()):
		var flame: float = 0.0
		for cell: int in _patches[i]:
			flame = maxf(flame, _burn.visual[cell])
		var flicker: float = 1.0 - FLICKER_DEPTH * (0.5 + 0.5 * sin(_clock * 7.0 + float(i) * 1.7) * sin(_clock * 3.1 + float(i)))
		var target: float = snappedf(clampf(flame * flicker, 0.0, 1.0), STEP)
		var light = lights[i]
		if absf(target - light.energy_multiplier) >= STEP - 0.001:
			light.energy_multiplier = target
			changed.append(light)
	return changed


## Every GU any of the lights can reach (what a repaint of `changed` has to cover).
func gus_of(changed: Array, field) -> Array:
	var set_of: Dictionary = {}
	for light in changed:
		for gu in field.gus_in_light_range(light):
			set_of[gu] = true
	return set_of.keys()
