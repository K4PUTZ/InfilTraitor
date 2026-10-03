## A floating, spinning pickup — the reusable "simplification" display for any object (`ACTOR_MASTER_PLAN` D21/D17/D14) — as a real
## mesh (RETIRE-2 of R3D-RETIRE-2D; D65).
##
## It was a `Sprite2D` cycling 120 baked frame pairs (colour + normal map + two shadow layers, ~48 MB of VRAM per pickup) through
## a per-pixel relight shader and mirrored into the 3D board by `PropBillboard3D`. Now the model IS in the world: coloured by OUR
## material registry (D66), lit by the board's cell planes, turning about the vertical by real yaw (so there is no frame count, no
## frame cache and no per-view re-pick), and its ground shadow is one soft disc that follows the bob.
##
## Behaviour kept from the sprite (Director, 2026-07-27/28): it hovers `HOVER_HEIGHT_PX` above its floor point, bobs with a sine of
## `BOB_AMPLITUDE_PX` (raised from 6 because the shadow needs the separation to read) over `BOB_PERIOD_SEC`, and spins at
## `ROTATION_DEG_PER_SEC`. The ground shadow stays pinned to the floor ("deixar claro onde está posicionada a arma em relação ao
## chão"): small and sharp (alpha 0.55) at the bottom of the bob, bigger and softer (alpha 0.28) at the top.
##
## DROPPED WITH THE FRAMES: the static-facing mode ("4 shotguns pointing at the blocks"), which was a frame frozen on a compass
## yaw measured from the bake; nothing calls it (the weapon bench places no weapons), and a mesh yaw for a model's muzzle would
## be a new measurement, not a port. `outline_color` and the saturation/contrast grade belonged to the sprite shader.
class_name FloatingCollectible
extends ObjectMesh3D

const ROTATION_DEG_PER_SEC := 36.0
const BOB_AMPLITUDE_PX := 18.0
const BOB_PERIOD_SEC := 2.0
## Fixed lift above the floor GU point, independent of the bob, so there is a real gap for the shadow to read against.
const HOVER_HEIGHT_PX := 60.0
const SHADOW_STRENGTH_AT_BOTTOM := 0.55
const SHADOW_STRENGTH_AT_TOP := 0.28
const SHADOW_SOFTNESS_AT_TOP := 0.6
const SHADOW_SCALE_AT_TOP := 1.00
const SHADOW_SCALE_AT_BOTTOM := 0.90

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO

var _floor: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _spin: float = 0.0


## `spec`: {"model": path, "rotation_deg": Vector3, "fit_size": Vector3, "surface_materials": Dictionary,
## "default_material": String, "shadow_half_gu": float}. False (logged) when there is no board or the model fails.
func setup(p_room: Node, p_gu_cell: Vector2i, spec: Dictionary, board: Node3D) -> bool:
	room = p_room
	gu_cell = p_gu_cell
	if board == null:
		push_error("[FloatingCollectible] no 3D board to draw the pickup on")
		return false
	if not setup_object(board, String(spec["model"]), spec.get("rotation_deg", Vector3.ZERO), spec["fit_size"],
			spec.get("surface_materials", {}), String(spec.get("default_material", "generic")),
			float(spec.get("shadow_half_gu", 0.3))):
		return false
	_floor = room.agent._cell_to_world(gu_cell)
	_apply_bob(0.0)
	set_process(true)
	return true


func billboard_height_px() -> float:
	return flight_px


func _process(delta: float) -> void:
	_bob_time += delta
	_spin += deg_to_rad(ROTATION_DEG_PER_SEC) * delta
	yaw = _spin
	_apply_bob(sin((_bob_time / BOB_PERIOD_SEC) * TAU))


## `bob_phase`: -1 (top of the bob) .. +1 (bottom, nearest the floor).
func _apply_bob(bob_phase: float) -> void:
	var lift: float = HOVER_HEIGHT_PX - bob_phase * BOB_AMPLITUDE_PX
	screen_position = _floor - Vector2(0.0, lift)
	flight_px = lift
	var bottom_frac: float = (bob_phase + 1.0) * 0.5
	set_shadow(lerpf(SHADOW_STRENGTH_AT_TOP, SHADOW_STRENGTH_AT_BOTTOM, bottom_frac),
		SHADOW_SOFTNESS_AT_TOP * (1.0 - bottom_frac), lerpf(SHADOW_SCALE_AT_TOP, SHADOW_SCALE_AT_BOTTOM, bottom_frac))
