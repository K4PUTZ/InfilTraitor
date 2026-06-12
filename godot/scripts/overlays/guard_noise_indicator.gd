extends Node2D
## Indicadores sonoros flutuantes: mostra direção de ruído do guarda sem revelar posição exata.
## Renderiza "(((" / ")))" flutuando ao redor do agente, desaparecendo com fade out.

## Cor para intensidade baixa (< 0.5)
const COLOR_LOW := Color(0.95, 0.65, 0.2, 1.0)   ## amarelo-laranja
## Cor para intensidade alta (>= 0.5)
const COLOR_HIGH := Color(0.95, 0.3, 0.15, 1.0)  ## laranja

const FONT_SIZE := 24
const INDICATOR_RADIUS := 120.0        ## raio de órbita ao redor do agente
const INDICATOR_FLOAT_DIST := 40.0     ## distância de movimento vertical
const INDICATOR_DURATION := 1.8        ## tempo de vida em segundos

var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO
var _indicators: Array[Dictionary] = []


func setup(floor_layer: TileMapLayer, visual_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_offset = visual_offset
	z_index = 100  ## Acima de movimento_overlay


func add_indicator(agent_world_pos: Vector2, noise_world_pos: Vector2, intensity: float) -> void:
	"""
	Adiciona um indicador sonoro.
	
	:param agent_world_pos: Posição do agente em world space
	:param noise_world_pos: Posição do ruído em world space (aproximada com offset)
	:param intensity: Intensidade do ruído (0.0 a 1.0)
	"""
	var dir := (noise_world_pos - agent_world_pos).normalized()
	_indicators.append({
		"dir": dir,
		"intensity": intensity,
		"timer": INDICATOR_DURATION,
		"offset": 0.0,
	})
	queue_redraw()


func _process(delta: float) -> void:
	if _indicators.is_empty():
		return
	
	var expired: Array = []
	for ind in _indicators:
		ind["timer"] -= delta
		ind["offset"] = (1.0 - (ind["timer"] / INDICATOR_DURATION)) * INDICATOR_FLOAT_DIST
		if ind["timer"] <= 0.0:
			expired.append(ind)
	
	for ind in expired:
		_indicators.erase(ind)
	
	if expired.size() > 0:
		queue_redraw()


func _draw() -> void:
	if _indicators.is_empty():
		return
	
	for ind in _indicators:
		var t     := clampf(1.0 - (ind["timer"] / INDICATOR_DURATION), 0.0, 1.0)
		var alpha := 1.0 - (t * t)   ## fade out quadrático
		var pos: Vector2 = ind["dir"] * INDICATOR_RADIUS + Vector2(0.0, -ind["offset"])
		var color: Color = COLOR_HIGH if ind["intensity"] >= 0.5 else COLOR_LOW
		color.a = alpha
		
		## Símbolo: "(((" ou ")))" dependendo da direção horizontal
		var symbol := ")))" if ind["dir"].x >= 0.0 else "((("
		draw_string(
			ThemeDB.fallback_font,
			pos,
			symbol,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			FONT_SIZE,
			color
		)
