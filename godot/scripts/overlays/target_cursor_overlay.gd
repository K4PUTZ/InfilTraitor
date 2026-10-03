extends Node3D
class_name TargetCursorOverlay

## TargetCursorOverlay — the "virtual grenade" that marks the throw's target cell.
##
## Director, 2026-08-10: "o quadrado magenta que estamos usando para indicar a GU selecionada pode sumir, e o cursor assume
## temporariamente o formato da granada" — then: "vamos modificar a silhueta da granada-cursor para exibir o verdadeiro asset da
## granada, já que vamos ter outros tipos de explosivos. Carregue dinamicamente o que quer que tenha sido definido como granada."
##
## RETIRE-2 of R3D-RETIRE-2D: it was a `Sprite2D` over the board showing the grenade's baked frame through a canvas shader. It is
## now the grenade's own mesh (`GrenadeProp`, the same model, size and registry materials) standing on the target cell in the 3D
## world, drawn with `virtual_object3d.gdshader` (50% red overlay, rim stroke, diagonal hatch: "planned", not "there"). Being a
## node of the board it stands where the real one will land in every view, with no per-view frame and no re-placement per frame.

const SHADER_PATH := "res://godot/shaders/virtual_object3d.gdshader"

## Tuning — `var` per architecture Rule 1. Forwarded to the shader on setup.
var mark_color: Color = Color(1.0, 0.0, 0.0, 1.0)
var overlay_strength: float = 0.5
var hatch_px: float = 2.0
## Gap between hatch lines, in screen pixels.
var hatch_spacing_px: float = 8.0

var _board: Node3D = null
var _ghost: ObjectMesh3D = null


## The board it lives on: the overlay joins it and builds the ghost then (the room creates the overlay before any board exists).
func set_board3d(board: Node3D) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost = null
	if get_parent() != null:
		get_parent().remove_child(self)
	_board = board
	if board == null:
		return
	board.add_child(self)
	_ghost = ObjectMesh3D.new()
	add_child(_ghost)
	if not _ghost.setup_object(board, GrenadeProp.MODEL_PATH, Vector3.ZERO, GrenadeProp.FIT_SIZE,
			GrenadeProp.SURFACE_MATERIALS, "metal", 0.0):
		_ghost.queue_free()
		_ghost = null
		return
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter("mark_color", mark_color)
	material.set_shader_parameter("overlay_strength", overlay_strength)
	material.set_shader_parameter("hatch_px", hatch_px)
	material.set_shader_parameter("hatch_spacing_px", hatch_spacing_px)
	_ghost.set_override_material(material)
	visible = false


## Stand the virtual grenade on a floor position (2D world pixels).
func show_at(center: Vector2) -> void:
	if _ghost == null:
		return
	_ghost.screen_position = center
	visible = true


func clear() -> void:
	visible = false
