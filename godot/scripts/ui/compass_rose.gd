## CompassRose — debug overlay, sistema vértice-alinhado (N=topo do diamante).
## N/E/S/W apontam para os vértices do tile isométrico.
## As faces de parede (NW, NE, SE, SW) ficam nas arestas ENTRE os vértices.
## Ver DIRECTION_GLOSSARY.md §2 e §8.
extends Control

const ARROW_LEN  := 44.0
const LABEL_GAP  := 12.0
const CORNER_PAD := Vector2(80.0, 80.0)

## Each entry: label and normalised screen-space direction vector (vertex-aligned).
const _DIRS: Array = [
	{"lbl": "N", "dir": Vector2( 0.0, -1.0)},   ## vértice topo   (↑)
	{"lbl": "E", "dir": Vector2( 1.0,  0.0)},   ## vértice direita (→)
	{"lbl": "S", "dir": Vector2( 0.0,  1.0)},   ## vértice base   (↓)
	{"lbl": "W", "dir": Vector2(-1.0,  0.0)},   ## vértice esquerda (←)
]

const _COL_ARROW := Color(1.0, 1.0, 1.0, 0.85)
const _COL_LABEL := Color(1.0, 0.9, 0.2, 1.0)
const _COL_BG    := Color(0.0, 0.0, 0.0, 0.45)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	var center := get_rect().size - CORNER_PAD
	var font   := ThemeDB.fallback_font

	## Background circle
	draw_circle(center, ARROW_LEN + LABEL_GAP + 6.0, _COL_BG)

	## Centre dot
	draw_circle(center, 3.0, _COL_ARROW)

	for d in _DIRS:
		var unit: Vector2 = (d["dir"] as Vector2).normalized()
		var tip := center + unit * ARROW_LEN

		## Shaft
		draw_line(center, tip, _COL_ARROW, 1.5, true)

		## Arrowhead
		var perp := Vector2(-unit.y, unit.x) * 5.0
		draw_line(tip, tip - unit * 9.0 + perp, _COL_ARROW, 1.5, true)
		draw_line(tip, tip - unit * 9.0 - perp, _COL_ARROW, 1.5, true)

		## Label — offset slightly past the tip
		var lbl_pos := tip + unit * LABEL_GAP - Vector2(4.0, 4.0)
		draw_string(font, lbl_pos, d["lbl"] as String,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _COL_LABEL)
