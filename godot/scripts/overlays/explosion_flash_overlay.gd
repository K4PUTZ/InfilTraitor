extends Node2D
class_name ExplosionFlashOverlay

## ExplosionFlashOverlay — the detonation's screen flash.
##
## E-NATIVE-01 (Director, 2026-08-09): "vamos seguir por esse caminho mesmo, e
## tirar as animações autoradas por enquanto." The 4-frame authored fireball is
## GONE. Its comic style did not sit with the rest of the scene, and no amount of
## scaling, additive blending or frame interpolation was going to fix a style
## mismatch — three rounds of tuning an imported sprite is what finally made that
## clear. The blast's visible core is built from the game's own vocabulary now
## (embers, sparks, dust, smoke — see Room.spawn_blast_burst()), so it is made of
## the same materials as everything else on screen instead of imported alongside
## it.
##
## What survives here is the one part that genuinely IS a screen effect rather
## than a world object: the flash. It stays because it does a job nothing else
## can — it covers the frame the destruction lands on.
##
## PURELY VISUAL, same contract as EmberOverlay/SmokeSparkOverlay: nothing here
## is gameplay state, so losing a flash in progress to a map reload or a
## perspective rotation costs nothing but the effect itself.
##
## Why the flash is drawn in WORLD space rather than as a CanvasLayer + ColorRect:
## room.tscn's two CanvasLayers (VisionFogOverlay, HUD) both sit at layer 0 and
## are ordered by tree position, so a runtime-added layer lands ABOVE the HUD and
## washes out the dev overlays along with the world. Filling the camera's own
## visible rect (derived from the canvas transform, so it follows pan and zoom for
## free) keeps the effect on the world where it belongs, and needs no camera
## reference.

## Tuning — all `var` (Rule 1).

## `flash_fade_seconds` is deliberately close to the destruction sequence's own
## length — the Director asked for the fade to run "enquanto as waves de
## destruição são disparadas", so the damage is already on screen as it lifts.
var flash_peak_alpha: float = 0.8
var flash_fade_seconds: float = 0.32
var flash_fade_power: float = 1.5         ## >1 = holds bright, then drops away

## E-FLASH-03 — the measured reason the Director felt an "engasgada" at the flash,
## and it was neither cause they suspected (the white being slow to enter, or
## persistence of vision from an all-white next frame). The frame the flash starts
## on is also the frame the destruction lands on, and it measured **150 ms**
## against 8-17 ms for its neighbours. The flash was then advancing its fade by
## that same 150 ms delta, burning half its curve in one step, so it appeared
## already half gone. Capping the delta the FADE sees does not hide the spike —
## E-ORGANIC-01 addresses that separately — it stops the flash from eating its own
## animation because of it.
var flash_max_step_seconds: float = 0.034

## Flash appearance. NEGATIVE is the shipped look as of 2026-08-09 (Director:
## "vamos testar o flash negativo em vez de branco também") — it inverts what is
## already on screen, "como nas explosões de antigamente". WHITE is the previous
## look, kept switchable for comparison (INFILTRAITOR_WHITE_FLASH=1).
enum FlashMode { WHITE, NEGATIVE }
var flash_mode: int = FlashMode.NEGATIVE

## Inverts whatever the frame already rendered, by `amount`. Six lines, one
## screen-texture read, no per-frame allocation — this is the entire cost of the
## Director's "frame negativo" idea, which they flagged as possibly hard or slow
## at runtime and is neither.
const NEGATIVE_FLASH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(src, vec3(1.0) - src, amount), 1.0);
}
"""

var _flash_elapsed: float = -1.0          ## <0 = no flash running

## The NEGATIVE flash needs a ShaderMaterial reading the screen texture; the
## WHITE flash is a plain draw_rect on this node and needs none. Two canvases
## rather than one because a material is per-node.
var _negative_layer: Node2D = null
var _negative_material: ShaderMaterial = null


func _ready() -> void:
	## Built unconditionally but drawn only in NEGATIVE mode, so flipping
	## `flash_mode` at runtime needs no re-setup.
	_negative_layer = Node2D.new()
	var shader := Shader.new()
	shader.code = NEGATIVE_FLASH_SHADER
	_negative_material = ShaderMaterial.new()
	_negative_material.shader = shader
	_negative_layer.material = _negative_material
	_negative_layer.draw.connect(_draw_negative)
	add_child(_negative_layer)


## Starts the flash. The caller fires the destruction sequence on the same beat —
## covering the frame it lands on is the whole reason this exists.
func flash() -> void:
	_flash_elapsed = 0.0
	set_process(true)
	_redraw_all()


func _process(delta: float) -> void:
	if _flash_elapsed < 0.0:
		set_process(false)
		return
	## Capped — see flash_max_step_seconds.
	_flash_elapsed += minf(delta, flash_max_step_seconds)
	if _flash_elapsed >= flash_fade_seconds:
		_flash_elapsed = -1.0
	_redraw_all()
	if _flash_elapsed < 0.0:
		set_process(false)


## Both canvases redraw together — whichever mode is active reads the same
## `_flash_elapsed`.
func _redraw_all() -> void:
	queue_redraw()
	if _negative_layer != null:
		_negative_layer.queue_redraw()


## 0..1 across the fade, or -1 when no flash is running.
func _flash_progress() -> float:
	if _flash_elapsed < 0.0:
		return -1.0
	return clampf(_flash_elapsed / flash_fade_seconds, 0.0, 1.0)


## This node: the WHITE flash, at normal blend. Deliberately NOT additive — a
## flash frame's job is to REPLACE what is underneath it.
func _draw() -> void:
	if flash_mode != FlashMode.WHITE:
		return
	var t: float = _flash_progress()
	if t < 0.0:
		return
	var alpha: float = flash_peak_alpha * pow(1.0 - t, flash_fade_power)
	if alpha > 0.001:
		draw_rect(_visible_world_rect(), Color(1.0, 1.0, 1.0, alpha))


## The NEGATIVE flash: one full-screen quad whose shader inverts what is already
## rendered underneath, tweening back to normal. Drawn white — the colour is
## irrelevant, the shader replaces it outright.
func _draw_negative() -> void:
	if flash_mode != FlashMode.NEGATIVE or _negative_material == null:
		return
	var t: float = _flash_progress()
	if t < 0.0:
		return
	var amount: float = pow(1.0 - t, flash_fade_power)
	if amount <= 0.001:
		return
	_negative_material.set_shader_parameter("amount", amount)
	_negative_layer.draw_rect(_visible_world_rect(), Color.WHITE)


## The camera's visible area in this node's own space. Derived from the canvas
## transform rather than from a Camera2D reference, so pan/zoom are already folded
## in and this overlay stays as dependency-free as every other one.
func _visible_world_rect() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	var view_size: Vector2 = get_viewport_rect().size
	var corners: Array[Vector2] = [
		inv * Vector2.ZERO,
		inv * Vector2(view_size.x, 0.0),
		inv * Vector2(0.0, view_size.y),
		inv * view_size,
	]
	var top_left := corners[0]
	var bottom_right := corners[0]
	for c in corners:
		top_left = Vector2(minf(top_left.x, c.x), minf(top_left.y, c.y))
		bottom_right = Vector2(maxf(bottom_right.x, c.x), maxf(bottom_right.y, c.y))
	return Rect2(top_left, bottom_right - top_left)


## Discard anything in flight (map load/reload, perspective change) — same
## reasoning as EmberOverlay.clear(): nothing here is state a reload restores.
func clear() -> void:
	_flash_elapsed = -1.0
	set_process(false)
	_redraw_all()
