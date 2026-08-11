extends Node2D
class_name TargetCursorOverlay

## TargetCursorOverlay — the "virtual grenade" that marks the throw's target cell.
##
## Director, 2026-08-10: "o quadrado magenta que estamos usando para indicar a
## GU selecionada pode sumir, e o cursor assume temporariamente o formato da
## granada" — then, on the first version: "vamos modificar a silhueta da
## granada-cursor para exibir o verdadeiro asset da granada, já que vamos ter
## outros tipos de explosivos. Carregue dinamicamente o que quer que tenha sido
## definido como granada."
##
## So the drawn silhouette is gone and this shows GrenadeProp's OWN baked frames,
## through GrenadeProp.load_color_frames() rather than a second path constant.
## That is the whole point of the change: a hand-drawn icon beside a baked prop
## is two definitions of one object, and the second explosive type is exactly
## when they drift apart.
##
## It mirrors GrenadeProp's anchoring (`centered = false`, `offset = -ANCHOR_PX`,
## `SPRITE_SCALE`) and its per-perspective frame swap, so the virtual grenade
## stands exactly where the real one will land, in the same view. What separates
## them is `virtual_grenade.gdshader` — 50% red overlay, 2 px stroke, 2 px
## diagonal hatch — which says "planned", not "there".

const SHADER_PATH := "res://godot/shaders/virtual_grenade.gdshader"

## Tuning — `var` per architecture Rule 1. Forwarded to the shader on setup.
var mark_color: Color = Color(1.0, 0.0, 0.0, 1.0)
var overlay_strength: float = 0.5
var outline_px: float = 2.0
var hatch_px: float = 2.0
## Gap between hatch lines, in the same texture pixels the widths use. The
## grenade's silhouette is only ~45 texels across, so a spacing near the line
## width turns the whole asset into a red blob — measured on the first capture
## at 9, where five lines and a 2 px stroke left nothing of the shape. 16 read as
## too sparse next to it; 12 is the Director's "aumenta só um pouquinho".
var hatch_spacing_px: float = 12.0

var _sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _frames: Dictionary = {}


func _ready() -> void:
	_frames = GrenadeProp.load_color_frames()

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_material.set_shader_parameter("mark_color", mark_color)
	_material.set_shader_parameter("overlay_strength", overlay_strength)
	_material.set_shader_parameter("outline_px", outline_px)
	_material.set_shader_parameter("hatch_px", hatch_px)
	_material.set_shader_parameter("hatch_spacing_px", hatch_spacing_px)

	## Same anchoring the real prop uses, so the preview and the landing agree.
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = -GrenadeProp.ANCHOR_PX
	_sprite.scale = Vector2.ONE * GrenadeProp.SPRITE_SCALE
	_sprite.material = _material
	add_child(_sprite)

	visible = false


## Stand the virtual grenade on a floor position, in the room's active view.
func show_at(center: Vector2, direction: String) -> void:
	if _sprite == null:
		return
	if not _frames.has(direction):
		push_warning("[TargetCursorOverlay] no grenade frame baked for view '%s'" % direction)
		return
	_sprite.texture = _frames[direction]
	_sprite.position = center
	visible = true


func clear() -> void:
	visible = false
