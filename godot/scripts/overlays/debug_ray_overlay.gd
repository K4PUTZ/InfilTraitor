extends Node
class_name DebugRayOverlay

## DebugRayOverlay / E-DEBUG-RAY — dev-only ray overlay showing real affected voxels.
##
## Task 2 of E-FRAG-01/E-SHARD-01: one ray from the blast epicenter to every
## voxel that the plan marked as dented or cracked. Unbounded (no count limit),
## so it shows the complete census the blast touched — used to verify that the
## real damage positions match expectations.
##
## Gated by env var INFILTRAITOR_ENABLE_DEBUG_RAYS (same precedent as
## INFILTRAITOR_ENABLE_STAMP_SOOT). When disabled, this node does nothing.
##
## E-DEBUG-RAY ships FIRST after E-RAY because it is the lowest-risk consumer
## and gives every later task a real visual tool to verify against (not just
## selftest counts).

var _ray_overlay: Node2D = null
var _enabled: bool = false


func _ready() -> void:
	_enabled = OS.get_environment("INFILTRAITOR_ENABLE_DEBUG_RAYS") == "1"


## Wire the AnimatedRayOverlay we'll paint into (called from room.gd).
func set_ray_overlay(overlay: Node2D) -> void:
	_ray_overlay = overlay


## Called from DetonationChoreographer._start_detonation_sequence() after the
## delta is committed. `blast_center` is the epicenter in world coords; `plan`
## is the DetonationPlan containing the damage entries. Emits rays from center
## to every dented/cracked voxel's world position.
func show_debug_rays(blast_center: Vector2, plan: Dictionary, voxel_renderer) -> void:
	if not _enabled or _ray_overlay == null or voxel_renderer == null:
		return

	var count: int = 0
	for kind: String in ["dented", "cracked"]:
		for ring: int in plan.get(kind, {}).keys():
			for entry in plan[kind][ring]:
				var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
				var level: int = entry.get("level", 0)
				var world_pos: Vector2 = voxel_renderer.cell_level_to_world(cell, level)
				_ray_overlay.add_ray(
					blast_center,
					world_pos,
					0.8,  ## fade over 0.8 seconds
					func(t): return 1.0 - t  ## linear fade
				)
				count += 1

	if count > 0:
		print_debug("[E-DEBUG-RAY] %d ray(s) from epicenter to dented/cracked voxels" % count)


func clear() -> void:
	if _ray_overlay != null:
		_ray_overlay.clear()
