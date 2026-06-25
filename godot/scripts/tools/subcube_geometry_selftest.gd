extends SceneTree
## Selftest headless de SubcubeGeometry (COORD-01-B).
## Rodar: godot --headless --script res://godot/scripts/tools/subcube_geometry_selftest.gd

func _initialize() -> void:
	var MC = load("res://godot/scripts/world/maps/map_compiler.gd")
	var failures: int = 0

	## --- 1. Sala sintética 3x3, 1 andar, sem portas: anel de 8 paredes -> 12 faces
	var spec_a: Dictionary = {
		"inner_size": Vector2i(3, 3),
		"buffer": 0,
		"agent_start": Vector2i(1, 1),
		"floor_tile": "floor_SE",
	}
	var c_a: Dictionary = MC.compile(spec_a)

	if not c_a.has("subcube_geometry"):
		push_error("compile() sem chave subcube_geometry"); failures += 1
	for k in ["size", "wall_levels", "wall_tiles", "blocked_cells", "blocked_edges"]:
		if not c_a.has(k):
			push_error("chave original sumiu: %s" % k); failures += 1

	var sg_a: Dictionary = c_a.get("subcube_geometry", {})
	var faces_a: Array = sg_a.get("wall_faces", [])
	var blocks_a: Array = sg_a.get("solid_blocks", [])
	if faces_a.size() != 12:
		push_error("3x3: esperado 12 faces, veio %d" % faces_a.size()); failures += 1
	if blocks_a.size() != 0:
		push_error("3x3: esperado 0 blocos, veio %d" % blocks_a.size()); failures += 1
	for f: Dictionary in faces_a:
		var from: Vector2i = f["edge"]["from"]
		var to: Vector2i = f["edge"]["to"]
		var dd: Vector2i = (to - from).abs()
		if dd.x + dd.y != 1:
			push_error("face com aresta nao-cardinal: %s" % f); failures += 1
		if int(f["width_subcubes"]) != 4:
			push_error("face com largura != 4: %s" % f); failures += 1
	var nw_edges: Array = []
	for f: Dictionary in faces_a:
		if String(f["tile"]) == "wallCorner_NW":
			nw_edges.append(f["edge"]["to"] - f["edge"]["from"])
	if not (nw_edges.has(Vector2i(0, -1)) and nw_edges.has(Vector2i(-1, 0))):
		push_error("wallCorner_NW nao gerou as 2 arestas esperadas: %s" % str(nw_edges)); failures += 1

	## --- 2. Divisória vira bloco sólido; porta vira vão (andar 0)
	var spec_b: Dictionary = {
		"inner_size": Vector2i(5, 5),
		"buffer": 0,
		"agent_start": Vector2i(2, 2),
		"floor_tile": "floor_SE",
		"access_points": [{"cell": Vector2i(2, 0)}],          ## porta na borda NW
		"dividers": [{"cells": [Vector2i(2, 2)]}],            ## 1 divisória interna
	}
	var c_b: Dictionary = MC.compile(spec_b)
	var sg_b: Dictionary = c_b.get("subcube_geometry", {})
	if (sg_b.get("solid_blocks", []) as Array).is_empty():
		push_error("divisoria nao gerou solid_block"); failures += 1
	for f: Dictionary in sg_b.get("wall_faces", []):
		if f["edge"]["from"] == Vector2i(2, 0) and int(f["storey"]) == 0:
			push_error("porta (2,0) gerou face no andar 0 (deveria ser vao)"); failures += 1

	## --- 3. Paredes em múltiplos andares: cada andar gera suas próprias faces
	var spec_c: Dictionary = {
		"inner_size": Vector2i(3, 3),
		"buffer": 0,
		"agent_start": Vector2i(1, 1),
		"floor_tile": "floor_SE",
		"wall_height": 2,  ## 2 andares
	}
	var c_c: Dictionary = MC.compile(spec_c)
	var sg_c: Dictionary = c_c.get("subcube_geometry", {})
	var faces_c: Array = sg_c.get("wall_faces", [])
	var storey_0: int = 0
	var storey_1: int = 0
	for f: Dictionary in faces_c:
		if int(f["storey"]) == 0:
			storey_0 += 1
		elif int(f["storey"]) == 1:
			storey_1 += 1
	if storey_0 != 12 or storey_1 != 12:
		push_error("Andar duplo: esperado 12+12 faces, veio %d+%d" % [storey_0, storey_1]); failures += 1

	if failures == 0:
		print("COORD-01-B SELFTEST: PASS")
		quit(0)
	else:
		print("COORD-01-B SELFTEST: FAIL (%d falhas)" % failures)
		quit(1)
