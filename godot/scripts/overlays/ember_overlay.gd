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

## Tuning — all `var` (Rule 1).
var glow_duration: float = 3.0        ## seconds from full glow to gone
var glow_radius: float = 14.0         ## px, roughly one voxel face
var glow_color: Color = Color(1.0, 0.45, 0.08, 1.0)
var fade_power: float = 1.6           ## >1 = lingers bright, then drops fast

var _embers: Array = []               ## [{"pos": Vector2, "elapsed": float, "duration": float}]


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Queue one glow at a voxel's world position (VoxelRenderer.voxel_world_position).
## duration <= 0 uses glow_duration.
func add_ember(world_pos: Vector2, duration: float = -1.0) -> void:
	_embers.append({
		"pos": world_pos,
		"elapsed": 0.0,
		"duration": duration if duration > 0.0 else glow_duration,
	})
	set_process(true)


func _process(delta: float) -> void:
	if _embers.is_empty():
		set_process(false)
		return
	var alive: Array = []
	for e in _embers:
		e["elapsed"] += delta
		if e["elapsed"] < e["duration"]:
			alive.append(e)
	_embers = alive
	queue_redraw()


func _draw() -> void:
	for e in _embers:
		var t: float = e["elapsed"] / e["duration"]
		var alpha: float = pow(1.0 - t, fade_power)
		var c := glow_color
		c.a *= alpha
		draw_circle(e["pos"], glow_radius, c)


## Discard every in-flight glow (map load/reload — see class doc: nothing here
## is state a reload needs to restore, but stale positions from the PREVIOUS
## map would be meaningless in the new one).
func clear() -> void:
	_embers.clear()
	set_process(false)
	queue_redraw()
