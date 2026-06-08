class_name NoiseSystem
## Gerencia barulhos persistentes no grid.
## Cada tile pode ter um nível de intensidade de barulho (0.0 a 1.0)
## que decai a cada turno.

## Chance de gerar barulho ao cruzar uma aresta, por tipo de movimento.
const NOISE_CHANCE_WALK  := 0.20   ## andar 1 tile (1 AP)
const NOISE_CHANCE_RUN   := 0.80   ## 2 tiles em 1 AP (futuro)
const NOISE_INTENSITY_WALK  := 0.5
const NOISE_INTENSITY_RUN   := 1.0

## Decaimento de intensidade por turno.
const NOISE_DECAY_PER_TURN := 0.25

## Raio de propagação sonora em tiles (atenuado por paredes).
const NOISE_RADIUS := 2

## grid: Vector2i → {intensity: float, age: int}
var _noise_grid: Dictionary = {}


## Gera barulho num tile com intensidade dada.
## Se o tile já tem barulho, usa o maior valor.
func emit(tile: Vector2i, intensity: float) -> void:
	var existing: Dictionary = _noise_grid.get(tile, {}) as Dictionary
	var current: float = existing.get("intensity", 0.0) as float
	_noise_grid[tile] = {
		"intensity": maxf(current, intensity),
		"age": 0
	}


## Decai todos os barulhos em 1 turno. Remove tiles zerados.
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


## Retorna intensidade de barulho num tile específico (0.0 se nenhum).
func get_intensity(tile: Vector2i) -> float:
	return _noise_grid.get(tile, {}).get("intensity", 0.0)


## Retorna todos os tiles com barulho ativo.
func get_noisy_tiles() -> Array:
	return _noise_grid.keys()


## Limpa tudo (ao resetar a missão).
func clear() -> void:
	_noise_grid.clear()
