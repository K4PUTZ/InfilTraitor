## CircleField3D — many camera-facing discs on the 3D board, in ONE draw call, depth-tested.
##
## RENDER3D R3D-4e-1. The 3D twin of `CircleField` (PERF-P7b): the same clients, the same
## begin/push/flush/clear frame, but each disc has a WORLD position (`ParticleMath`), so a wall in front
## of it hides it. Built on `QuadField3D` (R3D-4e-3): the disc is a quad whose shader discards outside
## the unit circle and feathers the rim — a frame ships only a transform and a colour per instance,
## exactly as the 2D field does with its circle fan, and a quad is four vertices where the fan was 192.
## `QuadField3D`'s header carries the `custom_aabb` and draw-order warnings that apply here too.
extends "res://godot/scripts/geometry/quad_field3d.gd"
class_name CircleField3D

const SHADER_MIX := "res://godot/shaders/particle_disc3d.gdshader"
const SHADER_ADD := "res://godot/shaders/particle_disc3d_add.gdshader"


func attach(parent: Node3D, additive: bool, feather: float = 0.0, priority: int = 0) -> void:
	_attach_shader(parent, SHADER_ADD if additive else SHADER_MIX, feather, priority)


## One disc. `anchor_3d`/`anchor_2d` are where the particle was emitted (3D, and the 2D point that
## projects to); `pos_2d` and `radius_px` are its ordinary 2D simulation state. No allocation.
func push(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2, radius_px: float, color: Color) -> void:
	_write(ParticleMathRef.disc_basis(_cam, radius_px, _ppu),
		ParticleMathRef.to_world(anchor_3d, anchor_2d, pos_2d, _cam, _ppu), color)
