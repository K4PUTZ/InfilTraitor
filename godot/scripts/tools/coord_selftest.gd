extends SceneTree
## Selftest headless de SubcubeCoords (COORD-01-A).
## Rodar: godot --headless --script res://godot/scripts/tools/coord_selftest.gd
## Saída: "COORD-01-A SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

func _initialize() -> void:
	var SC = load("res://godot/scripts/world/subcube_coords.gd")
	var failures: int = 0
	var checked: int = 0

	## Inclui negativos, zero e valores grandes de propósito.
	for uy in range(-3, 30):
		for ux in range(-3, 30):
			var u: Vector2i = Vector2i(ux, uy)
			checked += 1
			## Round-trip: unit -> origem -> unit
			var back: Vector2i = SC.subcube_to_unit(SC.unit_to_subcube_origin(u))
			if back != u:
				push_error("RT unit falhou: %s -> %s" % [u, back]); failures += 1
			## unit_subcubes: 16, únicos, todos mapeiam de volta para u
			var cubes: Array[Vector2i] = SC.unit_subcubes(u)
			if cubes.size() != 16:
				push_error("unit_subcubes size=%d em %s" % [cubes.size(), u]); failures += 1
			var seen: Dictionary = {}
			for c in cubes:
				seen[c] = true
				if SC.subcube_to_unit(c) != u:
					push_error("subcube %s nao mapeia p/ unit %s" % [c, u]); failures += 1
			if seen.size() != 16:
				push_error("unit_subcubes nao unico em %s" % u); failures += 1

	## Round-trip: subcube -> (unit, local) -> subcube; local sempre 0..3
	for sy in range(-12, 120):
		for sx in range(-12, 120):
			var s: Vector2i = Vector2i(sx, sy)
			checked += 1
			var u: Vector2i = SC.subcube_to_unit(s)
			var l: Vector2i = SC.subcube_local(s)
			if l.x < 0 or l.x > 3 or l.y < 0 or l.y > 3:
				push_error("local fora de 0..3: %s -> %s" % [s, l]); failures += 1
			if SC.subcube_at(u, l) != s:
				push_error("RT subcube falhou: %s" % s); failures += 1

	if failures == 0:
		print("COORD-01-A SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("COORD-01-A SELFTEST: FAIL (%d falhas)" % failures)
		quit(1)
