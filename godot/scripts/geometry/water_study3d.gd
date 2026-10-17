## WaterStudy3D — M6 WATER STUDY (2026-10-17): ONE flat sheet over a rectangle of the floor, drawn by `water_study3d.gdshader` in the look
## a KIND picks. Dev only (flag `WATER_STUDY=<kind>`, `WATER_RAIN=<0..1>`, rain works on ANY kind: the Director's rule of 2026-10-17, every water exposed to rain gets it), nothing simulated and nothing saved: it exists so the Director can judge how
## water could READ (flat tint / stipple / surface / both) before a mechanism is chosen (`MATERIALS_MASTER_PLAN` §6).
class_name WaterStudy3D
extends RefCounted

const SHADER: Shader = preload("res://godot/shaders/water_study3d.gdshader")
## Above the floor top, below the contact shadows and decals' own lifts.
const LIFT: float = 0.03
## The looks. `waste` is the Director's pick of 2026-10-17 (stipple + surface, softened: it reads as dirty water with bacteria, so it is
## the discard / sewer water); `clean` is the same without the dots and clearer, for treated / pure water. The three others are the first
## round's looks, kept for comparison. `mode`: 0 flat tint, 1 stipple, 2 surface, 3 both (see the shader).
const KINDS: Dictionary = {
	"flat": {"mode": 0},
	"stipple": {"mode": 1},
	"surface": {"mode": 2},
	"waste": {"mode": 3},
	## Caribbean shallows: very clear, light blue-green, no bubbles; the channel shows its own depth (the curbs' shade on the water, deeper
	## blue in the middle) and the sun's caustics on the bed.
	"caribe": {"mode": 2, "bubble_amount": 0.0, "caustics": 1.0, "depth_shade": 1.0,
			"deep_color": Color(0.0, 0.52, 0.78, 0.26), "shallow_color": Color(0.3, 0.92, 0.96, 0.1), "light_color": Color(0.95, 1.0, 1.0, 1.0)},
	## Sewage: brown and murky (the bed does not show), a green scum drifting on it, big bubbles, dark specks of dirt, slow and thick.
	"esgoto": {"mode": 3, "detail_strength": 0.9, "scum": 1.0, "flow_speed": 0.14, "stipple_alive": 0.72, "oil": 1.0,
			"deep_color": Color(0.22, 0.14, 0.06, 0.93), "shallow_color": Color(0.38, 0.27, 0.12, 0.88), "light_color": Color(0.72, 0.64, 0.38, 1.0),
			"dirt_color": Color(0.1, 0.06, 0.02, 1.0), "scum_color": Color(0.24, 0.34, 0.1, 1.0)},
	## Biohazard waste: dark blood-red and murky, chunks of gore (red flesh with pale fat) afloat, a lot of white-pink froth, few bubbles.
	"biohazard": {"mode": 3, "detail_strength": 0.8, "scum": 1.0, "scum_cut": 0.64, "scum_scale": 4.2, "froth": 1.0, "flow_speed": 0.12,
			"stipple_alive": 0.82, "bubble_amount": 0.5,
			"deep_color": Color(0.24, 0.015, 0.02, 0.94), "shallow_color": Color(0.46, 0.04, 0.05, 0.88), "light_color": Color(0.98, 0.86, 0.84, 1.0),
			"dirt_color": Color(0.1, 0.0, 0.0, 1.0), "scum_color": Color(0.5, 0.07, 0.08, 1.0), "scum_top_color": Color(0.93, 0.76, 0.7, 1.0)},
	## Toxic waste: dark green and murky, an olive sludge, planks / cardboard / plastic / cans afloat, sickly bubbles.
	"toxic": {"mode": 3, "detail_strength": 0.8, "scum": 0.8, "scum_cut": 0.62, "scum_scale": 5.0, "junk": 1.0, "junk_skip": 0.35, "flow_speed": 0.12,
			"stipple_alive": 0.8, "bubble_amount": 1.0,
			"deep_color": Color(0.03, 0.12, 0.04, 0.94), "shallow_color": Color(0.1, 0.27, 0.06, 0.9), "light_color": Color(0.72, 1.0, 0.35, 1.0),
			"dirt_color": Color(0.02, 0.06, 0.01, 1.0), "scum_color": Color(0.18, 0.34, 0.04, 1.0), "scum_top_color": Color(0.5, 0.72, 0.1, 1.0)},
	## Nuclear waste: phosphorescent green, glowing patches that pulse, slow bubbles that swell and burst with a ring, almost still.
	"nuclear": {"mode": 2, "bubble_amount": 0.0, "pop_bubbles": 1.0, "glow": 1.0, "detail_strength": 0.5, "flow_speed": 0.07,
			"deep_color": Color(0.05, 0.42, 0.1, 0.9), "shallow_color": Color(0.25, 0.78, 0.15, 0.85), "light_color": Color(0.7, 1.0, 0.25, 1.0)},
	## LAVA, three looks (Director, 2026-10-17). Molten gold: liquid, bright, glints and slow pulsing hot patches, a few slow bubbles.
	"lava_gold": {"mode": 2, "bubble_amount": 0.25, "glow": 1.0, "detail_strength": 0.9, "flow_speed": 0.2,
			"deep_color": Color(0.95, 0.5, 0.05, 0.98), "shallow_color": Color(1.0, 0.82, 0.25, 0.98), "light_color": Color(1.0, 0.97, 0.7, 1.0)},
	## Hardened lava: mostly cooled dark plates with glowing cracks, a few holes where the molten base shows, almost still.
	"lava_crust": {"mode": 0, "crust": 0.8, "crack_scale": 4.6, "flow_speed": 0.05, "glow": 0.0,
			"deep_color": Color(0.9, 0.25, 0.03, 0.7), "shallow_color": Color(1.0, 0.5, 0.08, 0.7), "light_color": Color(1.0, 0.8, 0.3, 1.0),
			"crust_color": Color(0.07, 0.055, 0.05, 1.0), "crack_color": Color(1.0, 0.5, 0.08, 1.0)},
	## Viscous lava: thick red-orange, slow, charred rock afloat with hot edges, slow heavy bubbles.
	"lava_viscous": {"mode": 2, "bubble_amount": 0.0, "pop_bubbles": 0.9, "scum": 1.0, "scum_cut": 0.64, "scum_scale": 2.8, "glow": 0.7,
			"detail_strength": 0.5, "flow_speed": 0.07,
			"deep_color": Color(0.55, 0.08, 0.02, 0.98), "shallow_color": Color(0.95, 0.3, 0.04, 0.98), "light_color": Color(1.0, 0.75, 0.25, 1.0),
			"scum_color": Color(0.06, 0.05, 0.045, 1.0), "scum_top_color": Color(0.16, 0.12, 0.1, 1.0), "scum_rim_color": Color(1.0, 0.42, 0.06, 1.0)},
	## Crude oil: near black and glossy, a wide iridescent film, big slow dark bubbles.
	"petroleo": {"mode": 2, "bubble_amount": 0.0, "pop_bubbles": 0.6, "oil": 1.0, "oil_cut": 0.45, "detail_strength": 0.35, "flow_speed": 0.06,
			"deep_color": Color(0.012, 0.012, 0.018, 0.98), "shallow_color": Color(0.06, 0.06, 0.085, 0.96), "light_color": Color(0.55, 0.6, 0.72, 1.0)},
	## Acid: sickly bright yellow-green, translucent, fizzing (a stipple of fast small dots), pulsing glow, foam at the curbs.
	"acido": {"mode": 3, "bubble_amount": 1.0, "glow": 0.6, "stipple_alive": 0.45, "detail_strength": 0.75, "flow_speed": 0.2,
			"deep_color": Color(0.3, 0.5, 0.04, 0.8), "shallow_color": Color(0.68, 0.9, 0.1, 0.68), "light_color": Color(0.96, 1.0, 0.55, 1.0)},
	## Mud / swamp: thick brown, slow, leaves and weed afloat, small heavy bubbles.
	"lama": {"mode": 2, "bubble_amount": 0.0, "pop_bubbles": 0.8, "scum": 1.0, "scum_cut": 0.62, "scum_scale": 3.5, "detail_strength": 0.4, "flow_speed": 0.04,
			"deep_color": Color(0.22, 0.15, 0.08, 0.99), "shallow_color": Color(0.38, 0.27, 0.14, 0.98), "light_color": Color(0.62, 0.52, 0.32, 1.0),
			"scum_color": Color(0.2, 0.25, 0.07, 1.0), "scum_top_color": Color(0.36, 0.4, 0.12, 1.0)},
	## Cryogenic: icy blue, floes of pale ice with bright cold cracks, a mist of froth, caustics in the open water.
	"criogenico": {"mode": 2, "bubble_amount": 0.0, "crust": 0.55, "crack_scale": 2.6, "froth": 0.5, "caustics": 0.6, "detail_strength": 0.5, "flow_speed": 0.05,
			"deep_color": Color(0.05, 0.3, 0.55, 0.78), "shallow_color": Color(0.35, 0.72, 0.9, 0.6), "light_color": Color(0.88, 0.97, 1.0, 1.0),
			"crust_color": Color(0.7, 0.86, 0.94, 1.0), "crack_color": Color(0.55, 0.92, 1.0, 1.0)},
	## Quicksand (LOOK only: the trap is `earth` plus a rule, not a fluid): wet sand, almost still, grains, slow bubbles, soft ripples.
	"areia_movedica": {"mode": 3, "bubble_amount": 0.0, "pop_bubbles": 0.7, "stipple_alive": 0.6, "detail_strength": 0.5, "flow_speed": 0.02,
			"deep_color": Color(0.6, 0.47, 0.26, 0.99), "shallow_color": Color(0.76, 0.63, 0.37, 0.98), "light_color": Color(0.92, 0.82, 0.58, 1.0),
			"dirt_color": Color(0.42, 0.3, 0.15, 1.0)},
	"clean": {"mode": 2, "deep_color": Color(0.05, 0.3, 0.38, 0.3), "shallow_color": Color(0.3, 0.64, 0.7, 0.18), "light_color": Color(0.9, 1.0, 1.0, 1.0)},
}

var _node: MeshInstance3D = null


## `rect` in RAW GU (the board's own grid, buffer included); `level` the floor-top level; `flow` the unit direction of the water.
func attach(board: Node3D, rect: Rect2, level: int, kind: String, flow: Vector2, rain: float = 0.0) -> void:
	detach()
	if board == null or not board.has_method("ground_level"):
		push_error("[WaterStudy3D] attach: the board has no ground_level()")
		return
	if not KINDS.has(kind):
		push_error("[WaterStudy3D] unknown kind '%s' (known: %s)" % [kind, str(KINDS.keys())])
		return
	var look: Dictionary = KINDS[kind]
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var y: float = float(level + 1 - int(board.call("ground_level"))) * unit + LIFT
	var verts := PackedVector3Array([
		Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y, rect.position.y),
		Vector3(rect.end.x, y, rect.end.y), Vector3(rect.position.x, y, rect.end.y)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", int(look["mode"]))
	material.set_shader_parameter("rain", clampf(rain, 0.0, 1.0))
	for key: String in ["bubble_amount", "caustics", "depth_shade", "detail_strength", "scum", "flow_speed", "stipple_alive", "oil", "scum_cut", "scum_scale", "froth", "junk", "junk_skip", "pop_bubbles", "glow", "crust", "crack_scale", "oil_cut"]:
		if look.has(key):
			material.set_shader_parameter(key, look[key])
	for key: String in ["deep_color", "shallow_color", "light_color", "dirt_color", "scum_color", "scum_top_color", "scum_rim_color", "crust_color", "crack_color"]:
		if look.has(key):
			material.set_shader_parameter(key, look[key])
	material.set_shader_parameter("rect_min", rect.position)
	material.set_shader_parameter("rect_max", rect.end)
	material.set_shader_parameter("flow_dir", flow.normalized())
	_node = MeshInstance3D.new()
	_node.name = "WaterStudy3D"
	_node.mesh = mesh
	_node.material_override = material
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.add_child(_node)


func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
