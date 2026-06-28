class_name WallContainer
extends Node2D
## Container de parede: 1 face (1 unit × 1 storey) composta em 1 Sprite2D.
## 4 subcubos horizontais × 4 níveis de altura = 16 átomos blitados em Image 160×240.
##
## Constantes derivadas analiticamente — não alterar sem nova calibração.
##   Tile isométrico: 64×32   Átomo PNG: 64×72   SUBCUBE_STEP: 40 px

const ATOM_W              :=  64
const ATOM_H              :=  72
const IMAGE_W             := 160
const IMAGE_H             := 240
const SUBCUBES_PER_AXIS   :=   4   ## SubcubeCoords.SUBCUBES_PER_UNIT_AXIS
const SUBCUBE_STEP_PX     :=  40.0
const STOREY_HEIGHT_PX    := 160.0  ## SUBCUBES_PER_AXIS × SUBCUBE_STEP_PX

## Offset do centro do Sprite2D relativo a map_to_local(face_subcells[0]).
## Derivado de: (-tile_w/2 + atom_w/2, -tile_h/2 + atom_h/2) + final_texture_origin
const FACE_CENTER_OFFSET: Dictionary = {
	"NW": Vector2(-16.0, -12.0),
	"NE": Vector2(-16.0, -28.0),
	"SE": Vector2( 16.0, -28.0),
	"SW": Vector2( 16.0, -12.0),
}

## Pixel da Image onde o CENTRO do subcubo ds=0, level=0 se encontra.
const ANCHOR_X_VARYING := Vector2(32.0,  156.0)  ## NW e SE
const ANCHOR_Y_VARYING := Vector2(128.0, 156.0)  ## SW e NE

## Direção desta face.
var dir: String = ""


## Constrói a Image composta com TODOS os andares e posiciona 1 Sprite2D filho.
##
## ref_layer     — TileMapLayer de referência para map_to_local().
## atom_image    — Image do átomo (64×72).
## face_subcells — Array[Vector2i] com os 4 subcells da aresta.
## wall_dir      — "NW" | "NE" | "SE" | "SW".
## storey_count  — número total de andares desta face (>= 1).
func build(ref_layer: TileMapLayer, atom_image: Image,
		face_subcells: Array, wall_dir: String, storey_count: int) -> void:
	dir = wall_dir

	var is_x_varying: bool = wall_dir == "NW" or wall_dir == "SE"

	## ── Dimensões dinâmicas da Image ────────────────────────────────────────────
	var n: int           = storey_count
	var baseline_y: int  = (n * SUBCUBES_PER_AXIS - 1) * int(SUBCUBE_STEP_PX)
	var image_h: int     = baseline_y + (SUBCUBES_PER_AXIS - 1) * 16 + ATOM_H
	var anchor_y: float  = baseline_y + ATOM_H * 0.5
	var anchor: Vector2  = Vector2(
			ANCHOR_X_VARYING.x if is_x_varying else ANCHOR_Y_VARYING.x,
			anchor_y)

	## ── Compor a Image ──────────────────────────────────────────────────────────
	var image := Image.create(IMAGE_W, image_h, false, Image.FORMAT_RGBA8)

	## Painter's algorithm:
	##   layer_index 0 (storey=0 level=0, base) primeiro → layer_index N*4-1 (topo) último.
	##   Dentro de cada layer_index: ds 0 (longe do viewer) → ds 3 (perto).
	for layer_index in n * SUBCUBES_PER_AXIS:
		for ds in SUBCUBES_PER_AXIS:
			var blit_x: int = ds * 32 if is_x_varying else 96 - ds * 32
			var blit_y: int = ds * 16 - layer_index * int(SUBCUBE_STEP_PX) + baseline_y
			image.blend_rect(atom_image,
					Rect2i(0, 0, ATOM_W, ATOM_H), Vector2i(blit_x, blit_y))

	## ── Sprite2D ────────────────────────────────────────────────────────────────
	var sp := Sprite2D.new()
	sp.texture  = ImageTexture.create_from_image(image)
	sp.centered = false

	## Posição baseada em storey=0 (layer_index=0, ds=0).
	## A Image cresce PARA CIMA — sem height offset por storey.
	var cell_world: Vector2 = ref_layer.position \
			+ ref_layer.map_to_local(Vector2i(face_subcells[0]))
	sp.position = cell_world + FACE_CENTER_OFFSET[wall_dir] - anchor

	## z_index: depth sort isométrico. Um Container por face → sem multiplicador de storey.
	var sc0 := Vector2i(face_subcells[0])
	sp.z_index = sc0.x + sc0.y

	add_child(sp)
