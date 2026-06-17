class_name NoiseSystem
## Manages persistent noise on the grid.
## Each tile can hold a noise intensity level (0.0 to 1.0)
## that decays every turn.

## Chance to generate noise when crossing an edge, by movement type.
const NOISE_CHANCE_WALK  := 0.20   ## walk 1 tile (1 AP)
const NOISE_CHANCE_RUN   := 0.80   ## 2 tiles in 1 AP (future)
const NOISE_INTENSITY_WALK  := 0.5
const NOISE_INTENSITY_RUN   := 1.0

## Intensity decay per turn.
const NOISE_DECAY_PER_TURN := 0.25

## Sound propagation radius in tiles (attenuated by walls).
const NOISE_RADIUS := 2

## grid: Vector2i -> {intensity: float, age: int}
var _noise_grid: Dictionary = {}


## Generate noise on a tile with the given intensity.
## If the tile already has noise, keep the higher value.
func emit(tile: Vector2i, intensity: float) -> void:
	var existing: Dictionary = _noise_grid.get(tile, {}) as Dictionary
	var current: float = existing.get("intensity", 0.0) as float
	_noise_grid[tile] = {
		"intensity": maxf(current, intensity),
		"age": 0
	}


## Decay all noise by 1 turn. Remove zeroed tiles.
func decay_all() -> void:
	var to_remove: Array = []
	for tile in _noise_grid.keys():
		var entry: Dictionary = _noise_grid[tile]
		entry["intensity"] -= NOISE_DECAY_PER_TURN
		entry["age"] += 1
		if entry["intensity"] <= 0.0:
			to_remove.append(tile)
	for tile in to_remove:
		_noise_grid.erase(tile)


## Return the noise intensity on a specific tile (0.0 if none).
func get_intensity(tile: Vector2i) -> float:
	return _noise_grid.get(tile, {}).get("intensity", 0.0)


## Return all tiles with active noise.
func get_noisy_tiles() -> Array:
	return _noise_grid.keys()


## Clear everything (when resetting the mission).
func clear() -> void:
	_noise_grid.clear()
