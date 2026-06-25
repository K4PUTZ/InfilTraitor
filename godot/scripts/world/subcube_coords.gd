class_name SubcubeCoords
## Conversões puras entre Gameplay Units (grid grosso) e Subcube Cells (grid fino).
## SOMENTE plano do piso (2D, índices de célula). NÃO trata altura/vertical —
## subcube height é plano de render (ver SUBCUBE_MASTER_PLAN.md §1, §5).
## Sem estado, sem pixels: só índices de célula e a razão horizontal 4×.
## Espelha o padrão de GuardPathfinder (class_name + static func, sem instanciar).

## Razão linear HORIZONTAL: 1 Gameplay Unit = 4×4 Subcube Cells no piso.
## Distinto de SUBCUBES_PER_FLOOR (=4, VERTICAL, plano de render).
const SUBCUBES_PER_UNIT_AXIS: int = 4

## Origem (canto NW) do bloco 4×4 de subcubos de uma unit.
static func unit_to_subcube_origin(unit: Vector2i) -> Vector2i:
	return unit * SUBCUBES_PER_UNIT_AXIS

## Unit a que um subcube pertence. Floor-division negativa-segura.
static func subcube_to_unit(sub: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(sub.x) / SUBCUBES_PER_UNIT_AXIS),
		floori(float(sub.y) / SUBCUBES_PER_UNIT_AXIS),
	)

## Offset local do subcube dentro da sua unit. Sempre em 0..3 (negativa-seguro).
static func subcube_local(sub: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(sub.x, SUBCUBES_PER_UNIT_AXIS),
		posmod(sub.y, SUBCUBES_PER_UNIT_AXIS),
	)

## Subcube absoluto a partir de unit + offset local (0..3). Conveniência inversa.
static func subcube_at(unit: Vector2i, local_offset: Vector2i) -> Vector2i:
	return unit_to_subcube_origin(unit) + local_offset

## Os 16 subcubos de uma unit, em ordem de varredura (y exterior, x interior).
static func unit_subcubes(unit: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []
	for j in SUBCUBES_PER_UNIT_AXIS:
		for i in SUBCUBES_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out
