## R3D-SURFACES SM-2 — `GroundScatter`: the expansion of a scatter zone is deterministic, stays inside its zone, lies on the voxel lattice,
## honours the kind's scale range, the floor rules (no leaf in the desert) and the avoid mask, scales with density, and the section reaches
## the compiler on the real SURFACES_SCATTER map.
extends SceneTree

const GroundScatterClass = preload("res://godot/scripts/geometry/ground_scatter.gd")
const SurfaceRulesClass = preload("res://godot/scripts/systems/surface_rules.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== GROUND SCATTER SELFTEST ==\n")
	var zone := Rect2(10.0, 20.0, 20.0, 20.0)
	var item := {"zone": zone, "kind": "leaf_litter", "seed": 4, "density": 0.16}
	var no_tags := Callable()
	var no_block := func(_at: Vector2, _half: float) -> bool: return false
	var a: Dictionary = GroundScatterClass.expand([item], no_tags, no_block)
	var b: Dictionary = GroundScatterClass.expand([item], no_tags, no_block)
	var ia: Array = a["instances"]
	_check(ia.size() > 30, "a 20 x 20 GU zone at 0.16 stamps per GU^2 places stamps (%d)" % ia.size())
	_check(str(ia) == str((b["instances"] as Array)), "the expansion is deterministic: the same item twice gives the same %d instances" % ia.size())
	var expected: float = ceil(20.0 / (1.0 / sqrt(0.16))) * ceil(20.0 / (1.0 / sqrt(0.16)))
	_check(float(ia.size()) > expected * 0.8 and float(ia.size()) <= expected, "the count follows the density (%d of about %d cells)" % [ia.size(), int(expected)])
	var inside := true
	var on_lattice := true
	var scale_ok := true
	var rot_ok := true
	var scale_range: Vector2 = SurfaceRulesClass.kind_scale("leaf_litter")
	for inst: Dictionary in ia:
		var at: Vector2 = inst["at"]
		inside = inside and zone.has_point(at)
		on_lattice = on_lattice and is_equal_approx(at.x * 8.0, round(at.x * 8.0)) and is_equal_approx(at.y * 8.0, round(at.y * 8.0))
		scale_ok = scale_ok and float(inst["scale"]) >= scale_range.x - 0.0001 and float(inst["scale"]) <= scale_range.y + 0.0001
		rot_ok = rot_ok and float(inst["rot"]) >= 0.0 and float(inst["rot"]) < TAU and bool(inst["scatter"])
	_check(inside, "every stamp lies inside its zone")
	_check(on_lattice, "every stamp sits on the voxel lattice (1/8 GU)")
	_check(scale_ok, "every scale is inside the kind's range %s" % str(scale_range))
	_check(rot_ok, "every rotation is in [0, TAU) and every instance is flagged `scatter`")
	var other_seed: Dictionary = GroundScatterClass.expand([{"zone": zone, "kind": "leaf_litter", "seed": 5, "density": 0.16}], no_tags, no_block)
	_check(str(ia) != str(other_seed["instances"]), "another seed gives another layout")
	var dense: Dictionary = GroundScatterClass.expand([{"zone": zone, "kind": "leaf_litter", "seed": 4, "density": 0.40}], no_tags, no_block)
	_check((dense["instances"] as Array).size() > ia.size() * 2, "more density, more stamps (%d vs %d)" % [(dense["instances"] as Array).size(), ia.size()])

	var arid := func(_gu: Vector2i) -> PackedStringArray: return PackedStringArray(["soil", "arid", "outdoor"])
	var desert: Dictionary = GroundScatterClass.expand([item], arid, no_block)
	_check((desert["instances"] as Array).is_empty() and int(desert["stats"]["leaf_litter"]["tags"]) > 30, "no leaf in the desert: an arid floor places none, and counts what it refused (%s)" % str(desert["stats"]))
	var grass := func(_gu: Vector2i) -> PackedStringArray: return PackedStringArray(["organic", "soil", "outdoor"])
	_check(not (GroundScatterClass.expand([item], grass, no_block)["instances"] as Array).is_empty(), "the same zone on grass places stamps")
	var pebbles_on_lab: Dictionary = GroundScatterClass.expand([{"zone": zone, "kind": "pebbles", "seed": 1, "density": 0.1}],
		func(_gu: Vector2i) -> PackedStringArray: return PackedStringArray(["tile", "indoor", "sterile"]), no_block)
	_check((pebbles_on_lab["instances"] as Array).is_empty(), "a sterile floor takes no pebbles")

	var wall := Rect2(15.0, 25.0, 6.0, 6.0)
	var blocked := func(at: Vector2, _half: float) -> bool: return wall.has_point(at)
	var around: Dictionary = GroundScatterClass.expand([item], no_tags, blocked)
	var under_wall := 0
	for inst: Dictionary in around["instances"]:
		under_wall += 1 if wall.has_point(inst["at"]) else 0
	_check(under_wall == 0 and int(around["stats"]["leaf_litter"]["blocked"]) > 0, "nothing lies under a standing thing: %d under the wall, %d refused" % [under_wall, int(around["stats"]["leaf_litter"]["blocked"])])

	var none: Dictionary = GroundScatterClass.expand([{"zone": zone, "kind": "no_such_kind", "seed": 1}], no_tags, no_block)
	_check((none["instances"] as Array).is_empty(), "a kind that is not in the rules places nothing (loudly)")

	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("SURFACES_SCATTER")
	_check((spec.get("ground_scatter", []) as Array).size() == 11, "the SURFACES_SCATTER map's `ground_scatter` reaches the runtime spec (11 items)")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var items: Array = layout.get("ground_scatter_items", [])
	var offset := Vector2(layout.get("playable_rect", Rect2i()).position)
	_check(items.size() == 11 and (items[0]["zone"] as Rect2).position == Vector2(2, 2) + offset, "MapCompiler forwards them shifted by the buffer (%s)" % str(offset))
	var bad_spec: Dictionary = spec.duplicate(true)
	bad_spec["ground_scatter"] = [{"zone": [1, 2, 0, 5], "kind": "leaf_litter"}, {"zone": [1, 2, 3], "kind": "leaf_litter"}, {"zone": [1, 2, 3, 4], "kind": "pebbles"}]
	_check((MapCompilerClass.compile(bad_spec).get("ground_scatter_items", []) as Array).size() == 1, "a zero-area zone and a 3-number zone are refused (loudly), the good one stays")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
