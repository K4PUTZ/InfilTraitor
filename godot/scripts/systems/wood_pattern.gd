## WoodPattern — Columnar periodic grooves
## Simulates wood grain with vertical groove directionality

extends "res://godot/scripts/systems/material_registry.gd".PatternAlgorithm

class_name WoodPattern

## Shade function: columnar periodic grooves
func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:
	# Grooves run vertically; horizontal periodicity creates the grain
	# Period = 2 voxels (visible at isometric scale)
	
	var groove_period = 2.0  # voxels
	var phase = float(voxel_xy.x) / groove_period
	var wave = sin(phase * PI) * 0.5 + 0.5  # [0, 1], one period = one sine
	
	# Vary groove depth slightly with subtle noise component
	var hash_input = seed_val + voxel_xy.x * 73 + voxel_xy.y * 131
	var micro_jitter = (_hash_float(hash_input) - 0.5) * 0.1  # ±5%
	
	var shade_val = 0.8 + wave * 0.3 + micro_jitter  # [0.8, 1.1]
	return shade_val

## Deterministic hash function: int → [0, 1] float
func _hash_float(x: int) -> float:
	# FNV-1a style hash
	var hash_val = x
	hash_val ^= hash_val >> 16
	hash_val = int(hash_val) * 0x85ebca6b
	hash_val ^= hash_val >> 13
	var result = float(hash_val & 0x7FFFFFFF) / 0x7FFFFFFF
	return result
