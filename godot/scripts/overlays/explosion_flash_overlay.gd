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
## Frames are `load()`ed at play time, never `preload()`ed: `ASSETS/*` is
## gitignored (.gitignore:48), so a preload would turn a missing local asset
## into a whole-project COMPILE error on a fresh clone. A missing frame here
## fails loudly and skips straight to the flash (B6) — the detonation still
## runs, it just has no fireball.

## Tuning — all `var` (Rule 1).

## Engine frames each animation frame is held for. The Director's cadence call
## the same session put the destruction waves at one wave per frame, and this
## reads as part of the same beat rather than a preamble to it.
var frames_per_animation_frame: int = 2

## The white wash. `flash_fade_seconds` is deliberately close to the wave
## sequence's own length (15 waves, one per frame, ~250 ms at 60 fps) — the
## Director asked for the fade to run "enquanto as waves de destruição são
## disparadas", so the damage is already on screen as the white lifts.
var flash_peak_alpha: float = 0.8
var flash_fade_seconds: float = 0.32
var flash_fade_power: float = 1.5         ## >1 = holds bright, then drops away

## The fireball is authored at 283x283, a hair wider than one GU (256 px), and
## is drawn centred on its anchor at native size.
var sprite_scale: float = 1.0

const FRAME_DIR := "res://ASSETS/ANIMATIONS/Explosion_1/Export"
const FRAME_COUNT := 4

signal animation_finished()

var _frames: Array[Texture2D] = []
var _frame_index: int = -1                ## -1 = no animation playing
var _frame_ticks: int = 0
var _anchor: Vector2 = Vector2.ZERO

var _flash_elapsed: float = -1.0          ## <0 = no flash running


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
	_frame_index = 0
	_frame_ticks = 0
	set_process(true)
	queue_redraw()


## The white frame. Separate from play() on purpose: the Director's sequence is
## "animação -> flash -> waves", so the caller decides when the flash lands
## rather than this class assuming it follows immediately.
func flash() -> void:
	_flash_elapsed = 0.0
	set_process(true)
	queue_redraw()


## Total seconds play() will take before it emits animation_finished — the
## caller needs it to schedule the camera shake against the whole beat.
func animation_seconds(frame_delta: float) -> float:
	return float(FRAME_COUNT * frames_per_animation_frame) * frame_delta


func _process(delta: float) -> void:
	var busy := false

	if _frame_index >= 0:
		busy = true
		_frame_ticks += 1
		if _frame_ticks >= frames_per_animation_frame:
			_frame_ticks = 0
			_frame_index += 1
			if _frame_index >= FRAME_COUNT:
				_frame_index = -1
				busy = false
				animation_finished.emit()

	if _flash_elapsed >= 0.0:
		_flash_elapsed += delta
		if _flash_elapsed >= flash_fade_seconds:
			_flash_elapsed = -1.0
		else:
			busy = true

	queue_redraw()
	if not busy:
		set_process(false)


func _draw() -> void:
	if _frame_index >= 0 and _frame_index < _frames.size():
		var tex: Texture2D = _frames[_frame_index]
		var size: Vector2 = tex.get_size() * sprite_scale
		## Centred on the anchor: the anchor is the point ON TOP of the grenade
		## (Director), so the fireball blooms out of it in every direction
		## rather than sitting on top of it like a hat.
		draw_texture_rect(tex, Rect2(_anchor - size * 0.5, size), false)

	if _flash_elapsed >= 0.0:
		var t: float = clampf(_flash_elapsed / flash_fade_seconds, 0.0, 1.0)
		var alpha: float = flash_peak_alpha * pow(1.0 - t, flash_fade_power)
		if alpha > 0.001:
			draw_rect(_visible_world_rect(), Color(1.0, 1.0, 1.0, alpha))


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
	_frame_index = -1
	_frame_ticks = 0
	_flash_elapsed = -1.0
	set_process(false)
	queue_redraw()
