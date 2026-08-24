extends Node2D
class_name FireGlowOverlay

## PERF-F8 — the warm wash that hides the edge of the frozen light region.
##
## Director, 2026-08-23: *"continuamos querendo suspender a atualização da area de
## luz na região com fogo, usando o clarão pra disfarçar a borda… se o clarão ficar
## em volta do fogo, iluminar faces mais proximas e puder pulsar, ótimo; mas não
## podemos trocar 6 por meia dúzia, tem que ser uma vantagem."*
##
## ⚠️ **ONE QUAD AND A SHADER. NEVER A PRIMITIVE PER VOXEL.** That caution is the
## reason this class exists in the shape it does: PERFORMANCE_MASTER_PLAN §8.8
## measured the existing VFX overlays at **95% `draw_*` submission** — 16.32 ms of
## a 17.15 ms `_draw` — because they issue one canvas command per particle per
## frame. A glow built the same way would spend a slice of exactly what F8 saved,
## which is the trade the Director named. This draws a SINGLE `draw_rect` and lets
## the fragment shader do the falloff, so its cost does not scale with the fire.
##
## ⚠️ **It does NOT light faces, and that is deliberate.** Anything that genuinely
## relights a voxel goes through the per-cell path F8 just suspended, and a fire
## registered as a real light would additionally trigger shadow projection — a
## second map-scale computation. This is a screen-space wash whose ONLY job is to
## make the boundary between frozen and live light unreadable.
##
## Same overlay contract as every other one here (O1: "occlusion is VIEW, not
## STATE"): purely visual, nothing a reload needs to restore.

const GLOW_SHADER := """
shader_type canvas_item;
// Radial falloff in the quad's own UV space, squared so the edge is soft rather
// than a visible ring — a hard rim would ADD a boundary instead of hiding one.
uniform vec4 warm : source_color = vec4(1.0, 0.55, 0.18, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.55;
uniform float pulse = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float r = clamp(1.0 - dot(d, d), 0.0, 1.0);
	COLOR = vec4(warm.rgb, r * r * strength * (1.0 + pulse));
}
"""

## Seconds. The wash outlives the last consumed voxel a little so it fades out
## instead of being switched off on the frame the fire ends.
var fade_out_s: float = 0.6
var pulse_speed: float = 3.7
var pulse_amount: float = 0.18
var padding_px: float = 96.0    ## how far past the burning GUs the wash reaches

var _rect: Rect2 = Rect2()
var _active: bool = false
var _fading: float = 0.0
var _elapsed: float = 0.0
var _mat: ShaderMaterial = null


func _ready() -> void:
	var sh := Shader.new()
	sh.code = GLOW_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	set_process(false)


## The region the fire occupies, in world space. Called as the burn commits, so
## the wash grows with the fire rather than being sized once from a prediction
## that the fire may not follow.
func cover(world_rect: Rect2) -> void:
	_rect = _rect.merge(world_rect) if _active else world_rect
	_active = true
	_fading = 0.0
	set_process(true)
	queue_redraw()


## The fire is out — fade, do not cut.
func release() -> void:
	if not _active:
		return
	_fading = fade_out_s


func clear() -> void:
	_active = false
	_fading = 0.0
	_rect = Rect2()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		set_process(false)
		return
	_elapsed += delta
	if _fading > 0.0:
		_fading -= delta
		if _fading <= 0.0:
			clear()
			return
	queue_redraw()


func _draw() -> void:
	if not _active or _rect.size == Vector2.ZERO:
		return
	var out: float = 1.0 if _fading <= 0.0 else clampf(_fading / maxf(fade_out_s, 0.001), 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_parameter("pulse",
			pulse_amount * sin(_elapsed * pulse_speed * TAU) * out)
		_mat.set_shader_parameter("strength", 0.55 * out)
	## ONE command. The shader owns the shape.
	draw_rect(_rect.grow(padding_px), Color.WHITE)
