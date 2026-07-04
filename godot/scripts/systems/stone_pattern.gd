## StonePattern — Granular per-voxel jitter
## Simulates natural surface granularity; grainy texture with high-frequency variation

extends "res://godot/scripts/systems/material_registry.gd".PatternAlgorithm

class_name StonePattern

## Shade function: per-voxel granular jitter
func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:
	# seed_val is derived from GU position + variant offset
	# Generate deterministic hash-based "noise" per voxel
	
	var hash_input = seed_val + voxel_xy.x * 73 + voxel_xy.y * 131
	var noise_val = _hash_float(hash_input)  # [0, 1]
	
	# Jitter range: ±10% around base luminance
	var jitter = (noise_val - 0.5) * 0.2  # [-0.1, 0.1]
	
	return 1.0 + jitter  # [0.9, 1.1], allows artistic range

## Deterministic hash function: int → [0, 1] float
## Critical: reproducible across runs
func _hash_float(x: int) -> float:
	# FNV-1a style hash
	var hash_val = x
	hash_val ^= hash_val >> 16
	hash_val = int(hash_val) * 0x85ebca6b
	hash_val ^= hash_val >> 13
	var result = float(hash_val & 0x7FFFFFFF) / 0x7FFFFFFF
	return result
