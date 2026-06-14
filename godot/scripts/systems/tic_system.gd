class_name TicSystem
## Processa um tic de detecção sempre que um ator muda de tile.
## Chamado por room.gd em dois momentos:
##   1. Quando o agente termina um step (tic do agente)
##   2. Quando um guarda termina seu movimento (tic do guarda)

## Multiplicadores de detecção por estado do guarda.
const STATE_MULTIPLIER: Dictionary = {
	"patrol":     0.55,
	"suspicious": 1.60,
	"search":      0.80,
	"alert":      2.00,
	"chase":      2.80,
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
##
## L-IMP-04: Added exposure_system parameter for tactical exposure integration
static func evaluate(
	guard,                          ## GuardEnemy
	target_cell: Vector2i,
	blocked_cells: Dictionary,
	blocked_edges: Dictionary,
	exposure_system = null          ## ExposureSystem (optional, L-IMP-04)
) -> TicResult:
	var result := TicResult.new()

	## Obtém referência do agente se necessário para o pipeline de detecção (Cover)
	var agent_ref = guard.get_tree().get_root().find_child("Agent", true, false)

	## Avaliação completa delegada ao guarda (Source of Truth)
	var eval: Dictionary = guard.evaluate_detection(
		target_cell, 
		guard.fov_range, 
		blocked_cells, 
		blocked_edges,
		2,
		agent_ref
	)

	result.visible      = bool(eval.get("visible", false))
	result.angle_ratio  = float(eval.get("angle_ratio", 0.0))
	result.distance     = int(eval.get("distance", 99))

	if not result.visible:
		return result

	## Probabilidade bruta retornada pelo guarda (inclui sombras e cover)
	var raw_prob: float = float(eval.get("final_prob", 0.0))

	## Aplicar multiplicador do estado do guarda
	var state_mult: float = STATE_MULTIPLIER.get(guard.state, 1.0)
	
	## L-IMP-04: Apply tactical exposure modifier
	var exposure_mult: float = 1.0
	if exposure_system != null:
		exposure_mult = exposure_system.get_detection_multiplier(target_cell)
	
	result.raw_chance = raw_prob * state_mult * exposure_mult

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
