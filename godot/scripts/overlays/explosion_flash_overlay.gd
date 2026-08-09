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

## ============================================================================
## P-STROBE (Director, 2026-08-09) — THE TIMED FADE IS GONE. The flash is a
## STROBE of discrete frames now, and the caller owns every one of them:
##
##     "separar o fogo, do flash, da destruição. A duração do fogo está boa.
##      Depois do último frame, entra: 1 flash frame branco, 1 frame negativo,
##      outro frame branco, outro frame negativo. O fogo se extende mais um
##      pouco e permanece acontecendo durante os 4 frames do flash.
##      Em seguida: frame positivo com a destruição limpa acontecendo."
##
## What this deletes, and why the deletion is a real simplification rather than
## a cleanup: `flash_fade_seconds`, `flash_fade_power`, `_process()` and
## `flash_max_step_seconds` all existed to run a fade on a wall clock. The last
## of those is the E-FLASH-03 fix — the frame the flash started on was also the
## frame the destruction landed on, measured at **150 ms** against 8-17 ms for
## its neighbours, so the fade advanced by that whole delta and burned half its
## curve in one step, reading as "already half gone".
##
## **A frame-driven strobe cannot have that bug.** There is no curve to burn:
## each frame is held at full intensity for exactly one frame and the caller
## advances it. A slow frame makes the strobe frame LAST longer, which is
## correct — it is still one frame of strobe — instead of skipping most of it.
## The whole class of "the effect ate itself because delta was big" is gone by
## construction. That measurement is preserved here because it is the reason to
## never put a wall-clock term back.
## ============================================================================

## Tuning — all `var` (Rule 1).

## Strobe frames are FULL intensity by design: a strobe frame's job is to
## replace the frame outright, not to tint it. This replaces the old
## `flash_peak_alpha` (0.8), which was the peak of a fade that no longer exists.
var strobe_white_alpha: float = 1.0

## How strongly the NEGATIVE frame inverts. 1.0 = full inversion.
var strobe_negative_amount: float = 1.0

## Flash appearance. NEGATIVE inverts what is already on screen, "como nas
## explosões de antigamente" (Director, 2026-08-09); WHITE replaces it. Both are
## now used in the SAME detonation — the strobe alternates them — rather than
## one being chosen over the other. `flash_mode` is what `hold_frame()` sets.
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

## true while a strobe frame is being held. There is no elapsed time and no
## timer: the caller sets a frame, awaits it, and sets the next one.
var _holding: bool = false

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


## Holds ONE strobe frame of `mode` at full intensity. The caller is expected to
## `await get_tree().process_frame` after each call and to `clear()` when the
## strobe is over — this node runs no timer and no `_process()`, so a caller
## that forgets `clear()` leaves the frame held indefinitely. That is a
## deliberate trade: the caller owning every frame is the entire point (see the
## P-STROBE block above), and the alternative — a safety timeout — would put
## back the wall-clock term the redesign exists to remove.
##
## `Room.clear()`/map reload already call `clear()` on this overlay, so the
## worst case of an interrupted strobe is bounded by the same path every other
## overlay uses.
func hold_frame(mode: int) -> void:
	flash_mode = mode
	_holding = true
	_redraw_all()


## Both canvases redraw together — only the one matching `flash_mode` paints.
func _redraw_all() -> void:
	queue_redraw()
	if _negative_layer != null:
		_negative_layer.queue_redraw()


## This node: the WHITE flash, at normal blend. Deliberately NOT additive — a
## flash frame's job is to REPLACE what is underneath it.
func _draw() -> void:
	if not _holding or flash_mode != FlashMode.WHITE:
		return
	if strobe_white_alpha > 0.001:
		draw_rect(_visible_world_rect(), Color(1.0, 1.0, 1.0, strobe_white_alpha))


## The NEGATIVE flash: one full-screen quad whose shader inverts what is already
## rendered underneath, tweening back to normal. Drawn white — the colour is
## irrelevant, the shader replaces it outright.
func _draw_negative() -> void:
	if not _holding or flash_mode != FlashMode.NEGATIVE or _negative_material == null:
		return
	if strobe_negative_amount <= 0.001:
		return
	_negative_material.set_shader_parameter("amount", strobe_negative_amount)
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


## Ends the strobe, and discards anything in flight on a map load/reload or
## perspective change — same reasoning as EmberOverlay.clear(): nothing here is
## state a reload restores. Every strobe MUST end with this (see hold_frame()).
func clear() -> void:
	_holding = false
	_redraw_all()
