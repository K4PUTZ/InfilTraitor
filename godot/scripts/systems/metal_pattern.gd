## MetalPattern — Sheen band across the face
## Simulates reflective specular highlight; smooth gradient

extends "res://godot/scripts/systems/material_registry.gd".PatternAlgorithm

class_name MetalPattern

## Shade function: sheen band with smooth gradient
func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:
	# Sheen band moves across the face
	# For simplicity: always a gradient in one axis, producing 8 visible "steps" per edge
	
	var position_in_edge = float(voxel_xy.x % 8)  # [0, 8)
	var step_fraction = position_in_edge / 8.0    # [0, 1)
	
	# Smooth gradient; not stepped
	var shade_val = 0.7 + step_fraction * 0.4  # [0.7, 1.1]
	
	# Optional: add subtle vertical variation to avoid flatness
	var vertical_mod = 0.95 + (_hash_float(seed_val + voxel_xy.y) - 0.5) * 0.1
	
	return shade_val * vertical_mod  # [~0.65, ~1.15]

## Deterministic hash function: int → [0, 1] float
func _hash_float(x: int) -> float:
	# FNV-1a style hash
	var hash_val = x
	hash_val ^= hash_val >> 16
	hash_val = int(hash_val) * 0x85ebca6b
	hash_val ^= hash_val >> 13
	var result = float(hash_val & 0x7FFFFFFF) / 0x7FFFFFFF
	return result
