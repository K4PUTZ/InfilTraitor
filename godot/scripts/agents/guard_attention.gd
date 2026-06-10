class_name GuardAttention
extends RefCounted

var target_cell: Vector2i = Vector2i.ZERO
var interest: float = 0.0
var timer: float = 0.0
const DECAY_RATE := 0.65

func focus(p_cell: Vector2i, strength: float, duration: float) -> void:
	target_cell = p_cell
	interest    = maxf(interest, strength)
	timer       = maxf(timer, duration)

func update(delta: float) -> void:
	if timer > 0.0:
		timer -= delta
	else:
		interest = move_toward(interest, 0.0, delta * DECAY_RATE)

func active() -> bool:
	return interest > 0.05
