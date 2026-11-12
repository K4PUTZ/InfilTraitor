## A floating, spinning pickup — the reusable "simplification" display for any object (`ACTOR_MASTER_PLAN` D21/D17/D14) — as a real
## mesh (RETIRE-2 of R3D-RETIRE-2D; D65).
##
## It was a `Sprite2D` cycling 120 baked frame pairs (colour + normal map + two shadow layers, ~48 MB of VRAM per pickup) through
## a per-pixel relight shader and mirrored into the 3D board by `PropBillboard3D`. Now the model IS in the world: coloured by OUR
## material registry (D66), lit by the board's cell planes, turning about the vertical by real yaw (so there is no frame count, no
## frame cache and no per-view re-pick), and its ground shadow is one soft disc that follows the bob.
##
## HERITAGE T2 W3 (Director, 2026-11-11: "o item subindo e descendo, flutuando no ar, para evidenciar que é um objeto
## coletável"): it hovers HOVER_HEIGHT_GU above its cell, bobs BOB_AMPLITUDE_GU over BOB_PERIOD_SEC and spins at
## ROTATION_DEG_PER_SEC, in WORLD units (the sprite's 60 px and 18 px at the board's 156.8 px a storey). It is a WEAPON row
## (`weapons/<id>.json` "model") at the size it has in the Agent's hands, lying flat; the map places it (`pickups`). The ground
## shadow stays pinned to the floor ("deixar claro onde está posicionada a arma em relação ao chão", 2026-07-28): small and
## sharp (alpha 0.55) at the bottom of the bob, bigger and softer (alpha 0.28) at the top. Rolling on the floor is the
## grenade's alone; a weapon lying in the scenery is a prop (`"weapon"` in a prop row), not a pickup.
class_name FloatingCollectible
extends ObjectMesh3D

const ROTATION_DEG_PER_SEC := 36.0
const BOB_AMPLITUDE_GU := 0.115
const BOB_PERIOD_SEC := 2.0
## Fixed lift above the floor, independent of the bob, so there is a real gap for the shadow to read against.
const HOVER_HEIGHT_GU := 0.38
## A pickup lies flat, as the table copy does.
const LIE_FLAT_DEG := Vector3(90.0, 0.0, 0.0)
## The actors' contact shadow (`ActorMesh3D.contact_shadow_node`), its radius scaled down for a weapon (Director,
## 2026-11-11: "com o raio um pouco mais reduzido"), growing as the pickup rises and shrinking as it comes down.
const SHADOW_SCALE_AT_BOTTOM := 0.45
const SHADOW_SCALE_AT_TOP := 0.6

var room: Node = null
var gu_cell: Vector2i = Vector2i.ZERO

var _ground: Vector3 = Vector3.ZERO
var _contact: MeshInstance3D = null
var _bob_time: float = 0.0
var _spin: float = 0.0


## The weapon `weapon_id` floating over `p_gu_cell`. False (logged) when there is no board or the weapon has no model.
func setup(p_room: Node, p_gu_cell: Vector2i, weapon_id: String, board: Node3D) -> bool:
	room = p_room
	gu_cell = p_gu_cell
	if board == null:
		push_error("[FloatingCollectible] no 3D board to draw the pickup on")
		return false
	var w: WeaponDef = WeaponRegistry.shared().get_weapon(weapon_id)
	if w == null or w.model_path == "":
		push_error("[FloatingCollectible] '%s' is not a weapon with a model (weapons/%s.json \"model\"): no pickup at %s" % [weapon_id, weapon_id, p_gu_cell])
		return false
	var size: Vector3 = w.world_size(LIE_FLAT_DEG)
	if size == Vector3.ZERO:
		return false
	if not setup_object(board, w.model_path, LIE_FLAT_DEG, size, w.surface_materials, "metal", 0.0):
		return false
	_contact = ActorMesh3D.contact_shadow_node()
	board.add_child(_contact)
	_ground = board.call("ground_point", room.agent._cell_to_world(gu_cell))
	_apply_bob(0.0)
	set_process(true)
	return true


var _freeze_idle: bool = DevFlag.on("FREEZE_IDLE")


func _process(delta: float) -> void:
	if _freeze_idle:
		delta = 0.0   ## `FREEZE_IDLE`: the bob and the spin hold (the light gate)
	_bob_time += delta
	_spin += deg_to_rad(ROTATION_DEG_PER_SEC) * delta
	yaw = _spin
	_apply_bob(sin((_bob_time / BOB_PERIOD_SEC) * TAU))


## `bob_phase`: -1 (top of the bob) .. +1 (bottom, nearest the floor).
func _apply_bob(bob_phase: float) -> void:
	place_world(_ground, HOVER_HEIGHT_GU - bob_phase * BOB_AMPLITUDE_GU)
	var bottom_frac: float = (bob_phase + 1.0) * 0.5
	if _contact != null:
		var k: float = lerpf(SHADOW_SCALE_AT_TOP, SHADOW_SCALE_AT_BOTTOM, bottom_frac)
		_contact.position = _ground
		_contact.scale = Vector3(k, 1.0, k)
		_contact.visible = visible


func _exit_tree() -> void:
	if _contact != null and is_instance_valid(_contact):
		_contact.queue_free()
	super._exit_tree()
