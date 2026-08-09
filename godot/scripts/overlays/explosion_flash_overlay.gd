extends Node2D
class_name ExplosionFlashOverlay

## ExplosionFlashOverlay — E-FLASH-01 (Director, 2026-08-08): the grenade's own
## detonation art. Two things, in one node because they are one beat:
##
##   1. a 4-frame fireball (ASSETS/ANIMATIONS/Explosion_1/Export/1..4.png)
##      played at the grenade's anchor, and
##   2. the WHITE FLASH FRAME that follows its last frame — a full-screen white
##      wash whose opacity tweens down while DetonationChoreographer fires the
##      destruction waves underneath it.
##
## PURELY VISUAL, same contract as EmberOverlay/SmokeSparkOverlay: nothing here
## is gameplay state, so losing a play in progress to a map reload or a
## perspective rotation costs nothing but the effect itself.
##
## Why the flash is drawn HERE, in world space, rather than as a CanvasLayer +
## ColorRect: room.tscn's two CanvasLayers (VisionFogOverlay, HUD) both sit at
## layer 0 and are ordered by tree position, so a runtime-added layer lands
## ABOVE the HUD and whites out the dev overlays along with the world. Filling
## the camera's own visible rect (derived from the canvas transform, so it
## follows pan and zoom for free) keeps the wash on the world where it belongs
## and needs no camera reference.
##
## Frames are `load()`ed, never `preload()`ed: `ASSETS/*` is gitignored
## (.gitignore:48), so a preload would turn a missing local asset into a
## whole-project COMPILE error on a fresh clone. A missing frame here fails
## loudly and skips straight to the flash (B6) — the detonation still runs, it
## just has no fireball.
##
## They are loaded in `_ready()`, NOT on the first play(). The Director called
## this on 2026-08-08 ("o primeiro flash frame branco me pareceu que demorou um
## pouco... talvez precise de um pré-load") and it was real: lazy loading put
## four PNG decodes inside the first detonation's own frame, so the very first
## blast of a session stuttered before its flash and every later one did not.
## Warming at _ready() keeps the gitignore-safety of a runtime load and removes
## the hitch.

## Tuning — all `var` (Rule 1).

## E-FLASH-03 (Director, 2026-08-09): "tem um problema sério que são os 4 frames
## sem os estados intermediários". The animation is now driven by TIME, not by an
## integer frame index, and every drawn instant CROSS-FADES the two authored
## frames it falls between — the Director's own suggestion ("frames intermediários
## usando cada dois frames mesclados interpolando os dois individualmente"), done
## at draw time rather than by baking textures. Draw-time is strictly better here:
## no extra memory, no extra load cost, and the result is CONTINUOUS instead of
## one fixed in-between per pair.
##
## Under the additive blend the two contributions sum, so a cross-fade at
## (1-t)/(t) keeps the fireball's total brightness roughly constant through the
## blend instead of dipping in the middle.
var animation_seconds: float = 0.22

## How much of each authored frame's time is spent HOLDING it versus blending
## into the next. 0.0 = a permanent cross-fade (mushy, everything is a blend);
## 1.0 = no blending at all (back to the 4-frame flip-book). The middle keeps
## each authored pose readable while removing the hard steps between them.
var frame_hold_fraction: float = 0.35

## The flash. `flash_fade_seconds` is deliberately close to the wave sequence's
## own length — the Director asked for the fade to run "enquanto as waves de
## destruição são disparadas", so the damage is already on screen as it lifts.
var flash_peak_alpha: float = 0.8
var flash_fade_seconds: float = 0.32
var flash_fade_power: float = 1.5         ## >1 = holds bright, then drops away

## E-FLASH-03 — the measured reason the Director felt an "engasgada" at the last
## frame, and it is neither of the two causes they suspected (the white being
## slow to appear, or persistence of vision from an all-white next frame). The
## frame the flash starts on is also the frame DetonationChoreographer applies
## destroy ring 0 — 872 cells erased plus the exposure reveals — and that frame
## measured **150 ms** where the animation's own frames ran at 8-17 ms. The flash
## was then advancing its fade by that same 150 ms delta, burning half its curve
## in one step, so the white appeared already half gone.
##
## Capping the delta the FADE sees does not hide the freeze — the freeze is a
## real frame-time spike and the honest fix is splitting that wave, which is a
## performance change outside this ask (see the master plan's note). What it does
## fix is the flash no longer eating its own animation because of it: the white
## now covers the spike instead of flickering through it.
var flash_max_step_seconds: float = 0.034

## Flash appearance. WHITE is the shipped look. NEGATIVE inverts what is already
## on screen ("um frame negativo em tween... como nas explosões de antigamente",
## Director's own suggestion) via a one-pass screen-read shader — real, cheap, and
## measured to add no delay of its own. Left OFF by default: which of the two
## reads better is a look decision, and this session only makes it available to
## compare, never picks it.
enum FlashMode { WHITE, NEGATIVE }
var flash_mode: int = FlashMode.WHITE

## The fireball is authored at 283x283 — a hair wider than one GU (256 px), which
## the Director found too small next to a crater that spans two ("animação do
## fogo parece pequena, vamos duplicar o tamanho"). At 2.0 it covers ~566 px,
## roughly the blast's own visible reach.
var sprite_scale: float = 2.0

## The fireball's own tint/opacity, applied ON TOP of the additive blend below.
## Additive alone still reads bright; pulling the alpha back is what lets the
## floor texture stay legible through the middle of the ball.
var fire_modulate := Color(1.0, 1.0, 1.0, 0.82)

const FRAME_DIR := "res://ASSETS/ANIMATIONS/Explosion_1/Export"
const FRAME_COUNT := 4

## Inverts whatever the frame already rendered, by `amount`. Six lines, one
## screen-texture read, no allocation per frame — this is the whole cost of the
## Director's "frame negativo" idea, which they flagged as possibly hard or
## slow at runtime and is neither.
const NEGATIVE_FLASH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(src, vec3(1.0) - src, amount), 1.0);
}
"""

signal animation_finished()

var _frames: Array[Texture2D] = []
var _anim_elapsed: float = -1.0           ## <0 = no animation playing
var _anchor: Vector2 = Vector2.ZERO

var _flash_elapsed: float = -1.0          ## <0 = no flash running

var _fire_layer: Node2D = null
var _negative_layer: Node2D = null
var _negative_material: ShaderMaterial = null


func _ready() -> void:
	## The additive child. Built here rather than in the scene so this overlay
	## stays a single self-contained script, same as every other overlay.
	_fire_layer = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire_layer.material = mat
	_fire_layer.z_index = -1        ## under this node's own flash
	_fire_layer.draw.connect(_draw_fire)
	add_child(_fire_layer)

	## The NEGATIVE flash's own canvas — it needs a ShaderMaterial reading the
	## screen texture, which the WHITE flash (a plain draw_rect on this node)
	## does not. Built unconditionally but drawn only in that mode, so switching
	## `flash_mode` at runtime needs no re-setup.
	_negative_layer = Node2D.new()
	var shader := Shader.new()
	shader.code = NEGATIVE_FLASH_SHADER
	_negative_material = ShaderMaterial.new()
	_negative_material.shader = shader
	_negative_layer.material = _negative_material
	_negative_layer.draw.connect(_draw_negative)
	add_child(_negative_layer)

	## Pay the PNG decodes at map load, not inside the first detonation's frame —
	## see this file's header for the Director's own observation that led here.
	_ensure_frames_loaded()


## Plays the fireball at `world_anchor` (the grenade's own top-centre — see
## TestZoneController.detonate_active()), then emits `animation_finished` so the
## caller can fire the flash and the destruction waves on the same beat.
func play(world_anchor: Vector2) -> void:
	_anchor = world_anchor
	_ensure_frames_loaded()
	if _frames.is_empty():
		## B6 loud-fail already reported by _ensure_frames_loaded(). Emit anyway:
		## a missing art file must not swallow the detonation itself.
		animation_finished.emit()
		return
	_anim_elapsed = 0.0
	set_process(true)
	_redraw_all()


## The flash. Separate from play() on purpose: the Director's sequence is
## "animação -> flash -> waves", so the caller decides when the flash lands
## rather than this class assuming it follows immediately.
func flash() -> void:
	_flash_elapsed = 0.0
	set_process(true)
	_redraw_all()


func _process(delta: float) -> void:
	var busy := false

	if _anim_elapsed >= 0.0:
		_anim_elapsed += delta
		if _anim_elapsed >= animation_seconds:
			_anim_elapsed = -1.0
			animation_finished.emit()
		else:
			busy = true

	if _flash_elapsed >= 0.0:
		## Capped, unlike the animation above: see flash_max_step_seconds. A
		## 150 ms frame must not consume half the fade in one step.
		_flash_elapsed += minf(delta, flash_max_step_seconds)
		if _flash_elapsed >= flash_fade_seconds:
			_flash_elapsed = -1.0
		else:
			busy = true

	_redraw_all()
	if not busy:
		set_process(false)


## Both canvases redraw together — they are halves of one effect, separated only
## by the blend/material each one needs.
func _redraw_all() -> void:
	queue_redraw()
	if _fire_layer != null:
		_fire_layer.queue_redraw()
	if _negative_layer != null:
		_negative_layer.queue_redraw()


## 0..1 across the flash's fade, or -1 when no flash is running.
func _flash_progress() -> float:
	if _flash_elapsed < 0.0:
		return -1.0
	return clampf(_flash_elapsed / flash_fade_seconds, 0.0, 1.0)


## This node: the WHITE flash, at normal blend (see _fire_layer's doc for why
## the flash is NOT additive).
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


## The additive child: the fireball, cross-faded between the two authored frames
## the current instant falls between (E-FLASH-03 — the Director's own fix for
## "os 4 frames sem os estados intermediários"). Connected to `_fire_layer.draw`
## in _ready() rather than living in a second script — it belongs to this effect,
## not to a class of its own.
##
## `frame_hold_fraction` of each frame's slot is spent on the authored pose
## alone; the rest cross-fades into the next. Both contributions are drawn
## additively, so they sum rather than one dimming the other.
func _draw_fire() -> void:
	if _anim_elapsed < 0.0 or _frames.size() < 2:
		return
	## Position along the authored frames, in [0, FRAME_COUNT-1].
	var p: float = clampf(_anim_elapsed / maxf(animation_seconds, 0.001), 0.0, 1.0) \
		* float(FRAME_COUNT - 1)
	var i: int = clampi(int(floor(p)), 0, FRAME_COUNT - 2)
	var local: float = p - float(i)
	## Remap so the first `frame_hold_fraction` of the slot holds frame i.
	var blend: float = 0.0
	if local > frame_hold_fraction:
		blend = (local - frame_hold_fraction) / maxf(1.0 - frame_hold_fraction, 0.001)
	blend = clampf(blend, 0.0, 1.0)

	_draw_fire_frame(i, 1.0 - blend)
	if blend > 0.0:
		_draw_fire_frame(i + 1, blend)


func _draw_fire_frame(index: int, weight: float) -> void:
	if weight <= 0.001 or index < 0 or index >= _frames.size():
		return
	var tex: Texture2D = _frames[index]
	var size: Vector2 = tex.get_size() * sprite_scale
	var tint := fire_modulate
	tint.a *= weight
	## Centred on the anchor: the anchor is the point ON TOP of the grenade
	## (Director), so the fireball blooms out of it in every direction rather
	## than sitting on top of it like a hat.
	_fire_layer.draw_texture_rect(tex, Rect2(_anchor - size * 0.5, size), false, tint)


## The camera's visible area in this node's own space. Derived from the canvas
## transform rather than from a Camera2D reference, so pan/zoom are already
## folded in and this overlay stays as dependency-free as every other one.
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


## Loaded once per session, on the first real play. ResourceLoader.exists() is
## checked per frame so a partially-exported folder names the file it is missing
## instead of failing on whichever one load() happened to reach first.
func _ensure_frames_loaded() -> void:
	if not _frames.is_empty():
		return
	var loaded: Array[Texture2D] = []
	for i in range(1, FRAME_COUNT + 1):
		var path := "%s/%d.png" % [FRAME_DIR, i]
		if not ResourceLoader.exists(path):
			push_error("[ExplosionFlashOverlay] missing detonation frame: %s — no fireball will play" % path)
			return
		var tex = load(path)
		if tex == null or not (tex is Texture2D):
			push_error("[ExplosionFlashOverlay] detonation frame is not a Texture2D: %s" % path)
			return
		loaded.append(tex)
	_frames = loaded


## Discard anything in flight (map load/reload, perspective change) — same
## reasoning as EmberOverlay.clear(): nothing here is state a reload restores.
func clear() -> void:
	_anim_elapsed = -1.0
	_flash_elapsed = -1.0
	set_process(false)
	_redraw_all()
