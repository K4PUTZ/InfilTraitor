extends Node2D
## TileOverlay — sistema unificado de pintura de tiles com multiply blend.
##
## Usado por: sombras, cone de detecção, saídas/entradas, objetivos, luz (DEV).
## Cada instância opera em um z_index específico — múltiplas instâncias possíveis.
##
## API:
##   paint(cell, color)           — pinta tile com Color específica
##   paint_named(cell, key)       — pinta tile usando cor da PALETTE
##   unpaint(cell)                — remove overlay de um tile
##   clear_priority(p)            — remove todos os tiles de uma prioridade
##   clear_all()                  — limpa tudo
##   shadow_color_for(mult)       — retorna cor de sombra para multiplicador float
##
## Blend mode: MULTIPLY (CanvasItemMaterial.BLEND_MODE_MUL).
## Efeito: overlay_color × tile_texture_color → preserva detalhes visuais.
## Cores próximas de branco = quase sem efeito; cores escuras = tile escurece;
## cores saturadas = tinge o tile preservando textura.

## Dimensões padrão do tile isométrico INFILTRAITOR (TileSet: 256×128 px)
const TILE_HW := 128.0   ## half-width  — horizontal
const TILE_HH :=  64.0   ## half-height — vertical

## Prioridades de renderização — ordenadas de menor (desenhado primeiro) para maior
const PRIO_SHADOW   := 1    ## Sombras — desenhadas abaixo de tudo
const PRIO_DETECT   := 2    ## Cone de detecção
const PRIO_MOVEMENT := 3    ## Preview de movimento/pathfinding
const PRIO_NAV      := 4    ## Navegação — saídas, objetivos
const PRIO_DEV      := 5    ## Dev only — spawn marker, debug

## Paleta de cores (multiply, alpha=0.80 embutido)
## Branco puro (1,1,1,1) = sem efeito visual; negro (0,0,0,x) = tile completamente preto.
const PALETTE: Dictionary = {
	## Sombras — escurecem com tom azul-frio (mapeado por _shadow_tiles float)
	"shadow_full":   Color(0.18, 0.18, 0.30, 0.80),  ## mult ≤ 0.35
	"shadow_mid":    Color(0.45, 0.45, 0.58, 0.80),  ## 0.35 < mult < 0.55
	"shadow_lite":   Color(0.70, 0.70, 0.82, 0.80),  ## mult ≥ 0.55, <1.0
	"lit":           Color(1.00, 1.00, 1.00, 0.00),  ## mult = 1.0 (sem overlay)

	## Cone de detecção — 5 bandas de probabilidade
	"detect_0":      Color(0.30, 1.00, 0.30, 0.70),  ## 0.0–0.2   verde claro
	"detect_1":      Color(0.60, 0.95, 0.50, 0.75),  ## 0.2–0.4
	"detect_2":      Color(1.00, 0.95, 0.30, 0.75),  ## 0.4–0.6   amarelo
	"detect_3":      Color(1.00, 0.60, 0.30, 0.75),  ## 0.6–0.8   laranja
	"detect_4":      Color(1.00, 0.20, 0.20, 0.80),  ## 0.8–1.0   vermelho

	## Saídas e marcadores
	"exit":          Color(0.55, 0.10, 0.90, 0.28),  ## roxo puro — saídas do segmento
	"spawn":         Color(0.20, 0.20, 0.20, 0.40),  ## cinza escuro — posição spawn
	"spawn_dev":     Color(0.20, 0.20, 0.20, 0.40),  ## cinza escuro — spawn em DEV_VISION

	## Objetivos
	"objective":     Color(0.90, 0.75, 0.20, 0.75),  ## ouro/amber — objetivo primário
	"secondary":     Color(0.75, 0.75, 0.75, 0.60),  ## cinza claro — secundário
}

## Estado interno
var _entries: Dictionary = {}        ## Vector2i → {"color": Color, "prio": int}
var _floor_layer: TileMapLayer = null
var _visual_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_visual_offset = get_parent().position if get_parent() else Vector2.ZERO
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func setup(floor_layer: TileMapLayer, visual_offset: Vector2 = Vector2.ZERO) -> void:
	## Configura referências de renderização. Chamado por room.gd após add_child().
	_floor_layer = floor_layer
	_visual_offset = visual_offset


## ─── API Pública ───────────────────────────────────────────────────────────

func paint(cell: Vector2i, color: Color, priority: int = 0) -> void:
	## Pinta um tile com uma Color explícita.
	_entries[cell] = {"color": color, "prio": priority}
	queue_redraw()


func paint_named(cell: Vector2i, palette_key: String, priority: int = 0) -> void:
	## Pinta um tile usando uma entrada da PALETTE.
	paint(cell, PALETTE.get(palette_key, Color.WHITE), priority)


func unpaint(cell: Vector2i) -> void:
	## Remove o overlay de um tile específico.
	if _entries.erase(cell):
		queue_redraw()


func clear_priority(priority: int) -> void:
	## Remove todos os tiles com uma prioridade específica.
	## Útil para limpar apenas o cone de detecção sem afetar sombras, por exemplo.
	var to_erase: Array[Vector2i] = []
	for cell: Vector2i in _entries:
		if (_entries[cell] as Dictionary)["prio"] == priority:
			to_erase.append(cell)
	for cell: Vector2i in to_erase:
		_entries.erase(cell)
	if not to_erase.is_empty():
		queue_redraw()


func clear_all() -> void:
	## Remove todos os overlays.
	if _entries.is_empty():
		return
	_entries.clear()
	queue_redraw()


func set_cells(cells: Array[Vector2i], color: Color, priority: int = 0) -> void:
	## Atalho: pinta um array inteiro de tiles de uma vez.
	## Mais eficiente que chamar paint() em loop (queue_redraw uma vez).
	for cell: Vector2i in cells:
		_entries[cell] = {"color": color, "prio": priority}
	if not cells.is_empty():
		queue_redraw()


func set_cells_named(cells: Array[Vector2i], palette_key: String, priority: int = 0) -> void:
	set_cells(cells, PALETTE.get(palette_key, Color.WHITE), priority)


## ─── Helpers ───────────────────────────────────────────────────────────────

static func shadow_color_for(shadow_mult: float) -> Color:
	## Retorna a cor de sombra correta para um valor de _shadow_tiles.
	## shadow_mult: float de room.gd (SHADOW_MULT≈0.30, PENUMBRA≈0.55, lit=1.0)
	if shadow_mult <= 0.35:
		return PALETTE["shadow_full"]
	elif shadow_mult < 0.55:
		return PALETTE["shadow_mid"]
	elif shadow_mult < 1.0:
		return PALETTE["shadow_lite"]
	else:
		return PALETTE["lit"]


static func detect_color_for(probability: float) -> Color:
	## Retorna a cor de detecção para uma probabilidade [0.0, 1.0].
	## Mapeada sobre 5 bandas uniformes da PALETTE detect_0..detect_4.
	var idx := clampi(int(probability * 5.0), 0, 4)
	return PALETTE["detect_%d" % idx]


## ─── Desenho ───────────────────────────────────────────────────────────────

func _tile_center(cell: Vector2i) -> Vector2:
	return _floor_layer.map_to_local(cell) + Vector2(0.0, TILE_HH) + _visual_offset


func _tile_diamond(world: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		world + Vector2(0.0,      -TILE_HH),
		world + Vector2(TILE_HW,   0.0),
		world + Vector2(0.0,       TILE_HH),
		world + Vector2(-TILE_HW,  0.0),
	])


func _draw() -> void:
	if _entries.is_empty() or _floor_layer == null:
		return
	## Ordenar por prioridade (menor prio desenhado primeiro → fica abaixo)
	var sorted: Array = []
	for cell: Vector2i in _entries:
		sorted.append([cell, _entries[cell]])
	sorted.sort_custom(func(a, b): return a[1]["prio"] < b[1]["prio"])

	## Desenhar diamante para cada tile
	for item in sorted:
		var cell: Vector2i = item[0]
		var entry: Dictionary = item[1]
		var color: Color = entry["color"]

		if color.a <= 0.01:  ## skip transparent
			continue

		var world := _tile_center(cell)
		var diamond := _tile_diamond(world)
		draw_colored_polygon(diamond, color)
