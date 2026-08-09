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

signal animation_finished()

var _frames: Array[Texture2D] = []
var _frame_index: int = -1                ## -1 = no animation playing
var _frame_ticks: int = 0
var _anchor: Vector2 = Vector2.ZERO

var _flash_elapsed: float = -1.0          ## <0 = no flash running

## The fireball draws on its OWN child node, because CanvasItemMaterial.
## blend_mode is per-node (SmokeSparkOverlay's header makes the same point about
## why smoke and sparks share one node and one blend). The Director asked for the
## animation to stop sitting so hard on the scenery — "queremos deixar passar um
## pouco do fundo usando um blend mode" — and ADD is what does that: the art's
## dark pixels contribute nothing, so the floor reads through the fireball's
## edges and smoke instead of being replaced by them.
##
## The WHITE FLASH stays on this node, at normal blend, deliberately: a flash
## frame's whole job is to REPLACE what is underneath, so making it additive
## would be the opposite of the ask. `_fire_layer.z_index = -1` keeps the fire
## under the flash — a Node2D child otherwise draws over its parent.
var _fire_layer: Node2D = null


func _ready() -> void:
	## The additive child. Built here rather than in the scene so this overlay
	## stays a single self-contained script, same as every other overlay.
	_fire_layer = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire_layer.material = mat
	_fire_layer.z_index = -1        ## under this node's own white flash
	_fire_layer.draw.connect(_draw_fire)
	add_child(_fire_layer)

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
	_frame_index = 0
	_frame_ticks = 0
	set_process(true)
	_redraw_all()


## The white frame. Separate from play() on purpose: the Director's sequence is
## "animação -> flash -> waves", so the caller decides when the flash lands
## rather than this class assuming it follows immediately.
func flash() -> void:
	_flash_elapsed = 0.0
	set_process(true)
	_redraw_all()


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

	_redraw_all()
	if not busy:
		set_process(false)


## Both canvases redraw together — they are two halves of one effect, and only
## the blend mode separates them.
func _redraw_all() -> void:
	queue_redraw()
	if _fire_layer != null:
		_fire_layer.queue_redraw()


## This node: the WHITE FLASH only, at normal blend (see _fire_layer's doc).
func _draw() -> void:
	if _flash_elapsed >= 0.0:
		var t: float = clampf(_flash_elapsed / flash_fade_seconds, 0.0, 1.0)
		var alpha: float = flash_peak_alpha * pow(1.0 - t, flash_fade_power)
		if alpha > 0.001:
			draw_rect(_visible_world_rect(), Color(1.0, 1.0, 1.0, alpha))


## The additive child: the fireball frame. Connected to `_fire_layer.draw` in
## _ready() rather than living in a second script — it is four lines and belongs
## to this effect, not to a class of its own.
func _draw_fire() -> void:
	if _frame_index < 0 or _frame_index >= _frames.size():
		return
	var tex: Texture2D = _frames[_frame_index]
	var size: Vector2 = tex.get_size() * sprite_scale
	## Centred on the anchor: the anchor is the point ON TOP of the grenade
	## (Director), so the fireball blooms out of it in every direction rather
	## than sitting on top of it like a hat.
	_fire_layer.draw_texture_rect(tex, Rect2(_anchor - size * 0.5, size), false, fire_modulate)


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
	_redraw_all()
