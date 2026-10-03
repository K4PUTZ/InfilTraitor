## The grenade on the ground and in flight, as a real mesh (RETIRE-2 of R3D-RETIRE-2D; `ACTOR` D65).
##
## It was a `Sprite2D` showing one of four baked frames (`grenade_frames`, a colour + a normal map per compass direction), relit by
## a per-pixel shader and mirrored into the 3D board by `PropBillboard3D`. Now it IS a node of the 3D board: the Quaternius
## `Grenade.glb`, coloured by OUR material registry (D66) and lit by the board's cell planes like every prop, so a perspective
## change needs no frame swap (the camera turns over one world) and the light and soot come from the world, not from a per-prop
## light search.
##
## What the flight code (`TestZoneController`) still drives is unchanged in meaning: `screen_position` and `flight_px`
## (`ObjectMesh3D`), the roll (`roll()`, about the axis perpendicular to the travel `set_roll_direction()` was given — a roll
## across the screen shows the whole turn and one toward the camera shows none, now by geometry instead of by a `roll_dir.x`
## factor) and `visible`, which the throw code uses as logic (a detonated grenade is hidden).
##
## GROUND SHADOW (Director, 2026-08-10: *"durante o vôo da granada, a sombra precisa acompanhar no chão, aumentando e
## diminuindo a opacidade e a difusão, de acordo com a distância vertical. Quando a granada encosta no chão a sombra é muito bem
## definida e bem menor, por baixo do asset."*). One height drives size, strength and softness, so they cannot disagree about how
## high the grenade is. `SHADOW_HEIGHT_REF_PX` is where the flight look is fully reached: `ThrowArcOverlay.arc_height_for()`
## floors every apex at `launch_px * 1.4`, 89.6 px for a standing throw, so even the shortest throw reaches the full effect at its
## apex and longer ones hold it. The strengths are `FloatingCollectible`'s ratified ground alpha (0.55) and the flight alpha MEASURED
## on the old shadow (0.35: the softer one read too faint under a body that flies past 90 px).
class_name GrenadeProp
extends ObjectMesh3D

const MODEL_PATH := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"
## The model fitted into this box (world units, uniform): a handheld at twice its real size reads (0.1 GU of grenade).
const FIT_SIZE := Vector3(0.2, 0.2, 0.2)
## Surface (as authored in the model) -> OUR registry material.
const SURFACE_MATERIALS := {"Green": "painted_metal", "DarkGreen": "painted_metal", "DarkGrey": "steel_dark"}
const SHADOW_HALF_GU := 0.14
const SHADOW_HEIGHT_REF_PX := 90.0
const SHADOW_STRENGTH_AT_GROUND := 0.55
const SHADOW_STRENGTH_IN_FLIGHT := 0.35
const SHADOW_SCALE_AT_GROUND := 0.80
const SHADOW_SCALE_IN_FLIGHT := 1.05
const SHADOW_SOFTNESS_IN_FLIGHT := 0.7

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO
var base_cell: Vector2i = Vector2i.ZERO

var _roll_axis: Vector3 = Vector3.RIGHT


## `board` is the 3D board the grenade belongs to (`Room.board3d()`); false (logged) when there is none or the model fails.
func setup(p_room: Node, p_gu_cell: Vector2i, p_base_cell: Vector2i, board: Node3D) -> bool:
	room = p_room
	gu_cell = p_gu_cell
	base_cell = p_base_cell
	if board == null:
		push_error("[GrenadeProp] no 3D board to draw the grenade on")
		return false
	if not setup_object(board, MODEL_PATH, Vector3.ZERO, FIT_SIZE, SURFACE_MATERIALS, "metal", SHADOW_HALF_GU):
		return false
	_sync_shadow()
	return true


func set_roll_direction(screen_dir: Vector2) -> void:
	_roll_axis = roll_axis_for(screen_dir)


## The accumulated roll, radians, about the axis perpendicular to the roll direction.
func roll(angle: float) -> void:
	set_tumble(angle, _roll_axis)


func billboard_height_px() -> float:
	return flight_px


func set_flight_height_px(px: float) -> void:
	flight_px = px
	_sync_shadow()


func update_cell(p_gu_cell: Vector2i) -> void:
	gu_cell = p_gu_cell


func _sync_shadow() -> void:
	var k: float = clampf(flight_px / SHADOW_HEIGHT_REF_PX, 0.0, 1.0)
	set_shadow(lerpf(SHADOW_STRENGTH_AT_GROUND, SHADOW_STRENGTH_IN_FLIGHT, k), SHADOW_SOFTNESS_IN_FLIGHT * k,
		lerpf(SHADOW_SCALE_AT_GROUND, SHADOW_SCALE_IN_FLIGHT, k))
