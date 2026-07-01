class_name SubcubeCoords
## Conversões puras entre Gameplay Units (grid grosso) e Subcube Cells (grid fino).
## SOMENTE plano do piso (2D, índices de célula). NÃO trata altura/vertical —
## subcube height é plano de render (ver SUBCUBE_MASTER_PLAN.md §1, §5).
## Sem estado, sem pixels: só índices de célula e a razão horizontal 4×.
## Espelha o padrão de GuardPathfinder (class_name + static func, sem instanciar).

## Razão linear HORIZONTAL: 1 Gameplay Unit = 8×8 Voxel Cells no piso.
const VOXELS_PER_UNIT_AXIS: int = 8
const SUBCUBES_PER_UNIT_AXIS: int = 8
const VOXEL_STEP_PX: float = 20.0
const VOXEL_TILE_SIZE: Vector2i = Vector2i(32, 16)

## Origem (canto NW) do bloco 8×8 de subcubos/voxels de uma unit.
static func unit_to_subcube_origin(unit: Vector2i) -> Vector2i:
	return unit * VOXELS_PER_UNIT_AXIS

## Unit a que um subcube/voxel pertence. Floor-division negativa-segura.
static func subcube_to_unit(sub: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(sub.x) / VOXELS_PER_UNIT_AXIS),
		floori(float(sub.y) / VOXELS_PER_UNIT_AXIS),
	)

## Offset local do subcube/voxel dentro da sua unit. Sempre em 0..7 (negativa-seguro).
static func subcube_local(sub: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(sub.x, VOXELS_PER_UNIT_AXIS),
		posmod(sub.y, VOXELS_PER_UNIT_AXIS),
	)

## Subcube/voxel absoluto a partir de unit + offset local (0..7). Conveniência inversa.
static func subcube_at(unit: Vector2i, local_offset: Vector2i) -> Vector2i:
	return unit_to_subcube_origin(unit) + local_offset

## Os 64 subcubos/voxels de uma unit, em ordem de varredura (y exterior, x interior).
static func unit_subcubes(unit: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = unit_to_subcube_origin(unit)
	var out: Array[Vector2i] = []
	for j in VOXELS_PER_UNIT_AXIS:
		for i in VOXELS_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out


## ── Voxel plane (VOXEL series) ────────────────────────────────────────────────
## 8×8 voxels por Gameplay Unit (eixo horizontal). API espelha o bloco subcubo
## acima; conversões são floor-division negativa-seguras (floori / posmod).

## Origem (canto NW) do bloco 8×8 de voxels de uma Gameplay Unit.
static func gu_to_voxel_origin(gu: Vector2i) -> Vector2i:
	return gu * VOXELS_PER_UNIT_AXIS

## Gameplay Unit a que um voxel pertence. Floor-division negativa-segura.
static func voxel_to_gu(v: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(v.x) / VOXELS_PER_UNIT_AXIS),
		floori(float(v.y) / VOXELS_PER_UNIT_AXIS),
	)

## Offset local do voxel dentro da sua Gameplay Unit. Sempre em 0..7 (negativa-seguro).
static func voxel_local(v: Vector2i) -> Vector2i:
	return Vector2i(
		posmod(v.x, VOXELS_PER_UNIT_AXIS),
		posmod(v.y, VOXELS_PER_UNIT_AXIS),
	)

## Os 64 voxels de uma Gameplay Unit, em ordem de varredura (y exterior, x interior).
static func gu_voxels(gu: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = gu_to_voxel_origin(gu)
	var out: Array[Vector2i] = []
	for j in VOXELS_PER_UNIT_AXIS:
		for i in VOXELS_PER_UNIT_AXIS:
			out.append(origin + Vector2i(i, j))
	return out

