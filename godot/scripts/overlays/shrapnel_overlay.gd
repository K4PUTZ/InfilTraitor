extends Node2D
class_name ShrapnelOverlay

## ShrapnelOverlay / E-FRAG — Decorative shrapnel from blast damage.
##
## Task 3 of E-FRAG-01/E-SHARD-01: dark iron fragments that explode outward
## when the grenade disappears, sampling a small fixed count from the plan's
## real destroy/dented/cracked cells so directions stay coherent with where
## the blast actually lands without scaling with the census.
##
## Each shrapnel is a black line flying from the epicenter outward, fading
## over its own lifetime. Purely visual; no Voxel writes (same contract as
## EmberOverlay/SmokeSparkOverlay).
##
## Fires at the exact point sprite.visible = false already sets in
## detonate_active() (test_zone_controller.gd:269).

var glow_radius: float = 16.0             ## px, angular size of fragment
var min_lifetime: float = 0.4             ## seconds, fastest-fading shard
var max_lifetime: float = 0.8             ## seconds, slowest-fading shard
var max_velocity: float = 400.0           ## px/s, outward blast speed

var frag_count: int = 12                  ## tunable: "gomos" order of magnitude
var frag_color: Color = Color(0.2, 0.2, 0.22, 1.0)  ## dark iron

var _frags: Array = []
## [{"pos", "elapsed", "lifetime", "velocity", "color", "alpha_func"}]

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Sample `frag_count` fragments from the damage cells and launch them.
## `blast_center` is the epicenter in world coords; `plan` is the
## DetonationPlan; `voxel_renderer` resolves cell→world coords.
func spawn_shrapnel(blast_center: Vector2, plan: Dictionary, voxel_renderer) -> void:
	if voxel_renderer == null:
		return

	## Collect all affected cells (destroy/dented/cracked) with their world positions
	var cells: Array = []
	for kind: String in ["destroy", "dented", "cracked"]:
		for ring: int in plan.get(kind, {}).keys():
			for entry in plan[kind][ring]:
				var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
				var level: int = entry.get("level", 0)
				var world_pos: Vector2 = voxel_renderer.cell_level_to_world(cell, level)
				cells.append(world_pos)

	if cells.is_empty():
		return

	## Sample frag_count random cells (with replacement if needed)
	for _i in range(mini(frag_count, cells.size())):
		var idx: int = randi_range(0, cells.size() - 1)
		var target_pos: Vector2 = cells[idx]
		var direction: Vector2 = (target_pos - blast_center).normalized()
		var velocity: Vector2 = direction * randf_range(max_velocity * 0.6, max_velocity)
		var lifetime: float = randf_range(min_lifetime, max_lifetime)

		_frags.append({
			"pos": blast_center,
			"vel": velocity,
			"elapsed": 0.0,
			"lifetime": lifetime,
			"color": frag_color,
		})

	set_process(true)


func _process(delta: float) -> void:
	if _frags.is_empty():
		set_process(false)
		return

	var alive: Array = []
	for frag in _frags:
		frag["elapsed"] += delta
		frag["pos"] += frag["vel"] * delta
		if frag["elapsed"] < frag["lifetime"]:
			alive.append(frag)
	_frags = alive
	queue_redraw()


func _draw() -> void:
	for frag in _frags:
		var t: float = frag["elapsed"] / frag["lifetime"]
		var alpha: float = 1.0 - t  ## linear fade
		var c: Color = frag["color"]
		c.a *= alpha
		draw_circle(frag["pos"], glow_radius, c)


func clear() -> void:
	_frags.clear()
	set_process(false)
	queue_redraw()
