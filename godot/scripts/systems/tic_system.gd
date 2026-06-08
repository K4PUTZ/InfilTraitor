class_name TicSystem
## Processa um tic de detecção sempre que um ator muda de tile.
## Chamado por room.gd em dois momentos:
##   1. Quando o agente termina um step (tic do agente)
##   2. Quando um guarda termina seu movimento (tic do guarda)

## Tabela de probabilidades base por distância Manhattan.
## Índice = distância (0 = mesmo tile, 1 = adjacente, etc.)
const DETECTION_CURVE: Array[float] = [
	1.00,  ## dist 0 — mesmo tile
	1.00,  ## dist 1 — adjacente
	0.95,  ## dist 2
	0.85,  ## dist 3
	0.60,  ## dist 4
	0.40,  ## dist 5
	0.15,  ## dist 6
	0.05,  ## dist 7
	0.01,  ## dist 8
]

## Multiplicadores de detecção por estado do guarda.
const STATE_MULTIPLIER: Dictionary = {
	"patrol":     0.60,
	"suspicious": 1.80,
	"alert":      2.20,
	"chase":      3.00,
}

## Ganho de detecção por tic bem-sucedido (antes de multiplicadores).
const DETECTION_GAIN_PER_TIC := 0.4

## Resultado de um tic de detecção.
class TicResult:
	var detected: bool = false       ## visível + dado passou
	var visible: bool = false        ## apenas na linha de visão
	var raw_chance: float = 0.0      ## probabilidade antes do dado
	var angle_ratio: float = 0.0     ## 1.0 = centro do cone, 0.0 = borda
	var distance: int = 0

## Processa um tic: avalia um único guarda contra uma única célula-alvo.
## Retorna TicResult com o resultado desta verificação.
static func evaluate(
	guard,                          ## GuardEnemy
	target_cell: Vector2i,
	blocked_cells: Dictionary,
	blocked_edges: Dictionary
) -> TicResult:
	var result := TicResult.new()

	## Avaliação angular (usa o evaluate_detection refatorado)
	var eval: Dictionary = guard.evaluate_detection(
		target_cell, guard.fov_range, blocked_cells, blocked_edges
	)

	result.visible      = bool(eval.get("visible", false))
	result.angle_ratio  = float(eval.get("angle_ratio", 0.0))
	result.distance     = int(eval.get("distance", 99))

	if not result.visible:
		return result

	## Probabilidade base pela curva de distância
	var dist := result.distance
	var base_chance: float = DETECTION_CURVE[dist] if dist < DETECTION_CURVE.size() else 0.0

	## Aplicar multiplicadores: estado do guarda × ângulo do cone
	var state_mult: float = STATE_MULTIPLIER.get(guard.state, 1.0)
	result.raw_chance = base_chance * state_mult * result.angle_ratio

	## Lançar dado: 0.0 a 1.0
	result.detected = randf() < result.raw_chance

	return result


## Avalia se um guarda ouve o barulho num tile.
## Retorna intensidade percebida (0.0 = não ouviu).
const HEARING_RADIUS := 2
static func evaluate_audio(
	guard,
	noise_tile: Vector2i,
	noise_intensity: float,
	blocked_edges: Dictionary
) -> float:
	if noise_intensity <= 0.0:
		return 0.0

	var dist := absi(guard.cell.x - noise_tile.x) + absi(guard.cell.y - noise_tile.y)
	if dist > HEARING_RADIUS:
		return 0.0

	## Atenuação por distância
	var distance_factor := 1.0 - (float(dist) / float(HEARING_RADIUS + 1))

	## Atenuação por paredes — cada parede cruzada reduz 40%
	var wall_penalty := _count_walls_between(guard.cell, noise_tile, blocked_edges)
	var wall_factor := pow(0.6, wall_penalty)

	return noise_intensity * distance_factor * wall_factor


static func _count_walls_between(
	from_cell: Vector2i,
	to_cell: Vector2i,
	blocked_edges: Dictionary
) -> int:
	## Conta paredes ao longo do caminho direto (Bresenham simplificado)
	var walls := 0
	var current := from_cell
	var dx := signi(to_cell.x - from_cell.x)
	var dy := signi(to_cell.y - from_cell.y)
	while current != to_cell:
		var next := current
		if current.x != to_cell.x:
			next.x += dx
		elif current.y != to_cell.y:
			next.y += dy
		if WallEdgeData.is_edge_blocked(current, next, blocked_edges):
			walls += 1
		current = next
	return walls
