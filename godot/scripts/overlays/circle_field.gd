extends RefCounted
class_name CircleField

## PERF-P7b — MANY ADDITIVE CIRCLES, IN ONE DRAW CALL.
##
## `PERFORMANCE_MASTER_PLAN` §8.8 measured the VFX overlays' `_draw()` at 95.1%
## canvas-command SUBMISSION and 4.9% GDScript loop, and §12.10 split that by
## population on the P3 build:
##
##   SmokeSpark/puffs  13.26 ms/frame · 1 325 cmd/frame · 68.9%   draw_circle
##   EmberOverlay       4.61 ms/frame ·   450 cmd/frame · 24.0%   draw_circle x2
##   SmokeSpark/sparks  0.02 ms/frame ·    46 cmd/frame ·  0.1%   draw_line
##
## ⚠️ **§8.6's task order says "ember first — the largest population". It is not.**
## The smoke PUFFS are, by three to one, and both they and the ember draw the same
## primitive — which is why this is one shared helper rather than the per-overlay
## rewrite the plan sketched. Together they are 92.9% of the cost.
##
## **The cost is per-VERTEX, not per-command**, and the sparks are the control that
## says so: 46 `draw_line` commands cost 0.4 us each while 1 325 `draw_circle`
## commands cost 10 us each. A filled circle is a tessellated polygon; a line is
## two vertices. So the fix is to stop rebuilding those polygons on the CPU every
## frame, which is exactly what a `MultiMesh` is for: the circle is uploaded ONCE
## as a mesh, and a frame ships only a transform and a colour per instance.
##
## ⚠️ **THIS DOES NOT REDUCE OVERDRAW.** The same circles cover the same pixels
## with the same additive blend, so the GPU fill is unchanged — §8.8b's claim that
## MultiMesh "also removes" the rasterization is wrong, and §12.10 corrects it.
## What this removes is the CPU submission, measured at 69% of the VFX frame-time
## delta. Fewer or smaller particles is a LOOK decision and remains the Director's.
##
## SEGMENTS is 64 to match Godot's own `canvas_item_add_circle` tessellation, so
## the conversion has a chance of being pixel-identical rather than merely close —
## §8.6's gate asks for 0 differing pixels. It is a `var` (Rule 1: never `const`).

## Godot's own filled-circle tessellation. Lowering this is a cheaper picture, not
## a cheaper CPU — the mesh is built once, so segment count costs nothing per frame.
static var segments: int = 64

## 8 floats of TRANSFORM_2D + 4 floats of colour, the layout `MultiMesh.buffer`
## expects when `use_colors` is on and the format is 2D.
const FLOATS_PER_INSTANCE: int = 12

var _node: MultiMeshInstance2D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0


## Build the instance node under `parent`, inheriting nothing: the caller's own
## `material` (additive, on every overlay that uses this) does NOT propagate to a
## child CanvasItem, so the blend mode is set here from the same enum rather than
## assumed. `z_index` 0 keeps it exactly where the parent's own `_draw()` output
## sat in the sibling order.
## D-4 — `feather` is the fraction of the radius over which alpha falls to zero at
## the rim. 0.0 is the original hard-edged disc, byte for byte, which is what the
## ember and P7b's pixel gate keep.
func attach(parent: Node2D, blend: CanvasItemMaterial.BlendMode,
		behind: bool = false, feather: float = 0.0) -> void:
	if _node != null:
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.mesh = _build_unit_circle()
	## ⛔ **WITHOUT THIS, EVERY INSTANCE FAR FROM THE NODE ORIGIN IS CULLED, AND
	## P7b HAS BEEN SILENTLY LOSING PARTICLES SINCE IT SHIPPED.**
	##
	## Godot derives a MultiMesh's visibility bounds from its BASE MESH, and the
	## base mesh here is a circle of radius **1**. The per-instance transforms carry
	## the real positions and radii and are not in that box, so whatever the culler
	## decides is outside is dropped before it is drawn.
	##
	## Found 2026-08-28 chasing D-4b's plumes, which never reached the screen. The
	## proof is the SPLIT, not the fix: in one frame this field held 96 plume puffs
	## and ~30 per-voxel puffs, all pushed, and only the per-voxel ones rendered.
	## They differ in exactly one way — spread. The puffs sat within x -220..-36 of
	## the origin and survived; the plumes spanned x -492..325 and did not. Setting
	## this box took them from **0 to 4 055 magenta pixels** on an otherwise
	## identical capture.
	##
	## ⚠️ **AND IT IS WHY P7b's "0 differing pixels" GATE PASSED ANYWAY.** That gate
	## is a static `circle_gate` scene whose circles all sit near the origin, so
	## nothing it draws is ever outside the box. A green gate that cannot reach the
	## failure is not evidence.
	##
	## Effectively disables culling for these fields, which is correct: they are
	## full-map overlays, the map is a few thousand pixels across, and a wrong box
	## costs whole effects rather than a few off-screen particles.
	_mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1.0), Vector3(2e6, 2e6, 2.0))
	_node = MultiMeshInstance2D.new()
	_node.name = "CircleFieldMM"
	_node.multimesh = _mm
	_node.material = _material_for(blend, feather)
	## ⚠️ ORDER IS PART OF THE PICTURE under a non-additive blend. A child
	## CanvasItem draws AFTER its parent's own `_draw()`, so moving one population
	## into a child would silently lift it above the ones left behind. Under ADD
	## the compositing is order-independent and this does not matter; under MIX it
	## does, and `show_behind_parent` is the property that puts it back.
	_node.show_behind_parent = behind
	parent.add_child(_node)


## D-4 — THE SOFT RIM, AND IT IS A SHADER BECAUSE VERTEX COLOURS DO NOT WORK HERE.
##
## Director, 2026-08-28: the destruction smoke *"está faltando"*. Measured the same
## day, the puff mechanism was complete — per-material chance, varying time,
## intensity and now height — and still did not read as smoke, because the
## primitive is a FLAT-COLOURED HARD-EDGED disc under `BLEND_MODE_MIX`: a lighter
## disc over the dark crater, a darker disc over the light wall, at every alpha and
## every size. Same complaint the Director already made about the fire, *"basicamente
## uma elipse com feather nas bordas e alpha"*.
##
## ⚠️ **THIS WAS REVERTED ONCE, ON A MISDIAGNOSIS, AND PUT BACK.** The shader was
## blamed for the plumes not drawing; the real cause was the missing `custom_aabb`
## above, and the red-rim probe returned only 19 pixels for exactly that reason.
## The feather never broke anything.
##
## ⚠️ **THE FIRST ATTEMPT WAS A FEATHERED MESH WITH VERTEX ALPHA, AND IT DREW
## NOTHING.** `MultiMesh.use_colors` supplies the per-instance colour and the mesh's
## own `ARRAY_COLOR` never reaches the fragment. Proved rather than reasoned: the
## rim was temporarily set to OPAQUE RED and a real capture found **0 reddish
## pixels** on the whole frame. Two renders had already "looked better" with that
## build in place, which is exactly why a plausible fix has to be measured before it
## is kept — the improvement was run-to-run variance (`add_smoke()` rolls offset,
## velocity, duration and radius with `randf_range`, so two boots never match).
##
## So the falloff is computed per FRAGMENT from the mesh's UV. Cost: the same
## instance count, the same overdraw, one extra `length()` and `smoothstep()` per
## covered pixel — and P7b's finding stands untouched, because what it measured was
## CPU SUBMISSION per vertex, which this does not change at all.
##
## `render_mode` carries the blend, because a ShaderMaterial replaces the
## CanvasItemMaterial that used to. Feather 0 keeps the plain CanvasItemMaterial,
## so the ember and P7b's pixel gate are byte-for-byte untouched.
const FEATHER_SHADER_SRC := "shader_type canvas_item;\nrender_mode %s;\nuniform float feather : hint_range(0.0, 1.0) = 0.6;\nvarying vec4 inst_color;\nvoid vertex() {\n\tinst_color = COLOR;\n}\nvoid fragment() {\n\tfloat d = length(UV * 2.0 - 1.0);\n\tCOLOR = inst_color;\n\tCOLOR.a *= 1.0 - smoothstep(1.0 - feather, 1.0, d);\n}\n"


static func _material_for(blend: CanvasItemMaterial.BlendMode, feather: float) -> Material:
	if feather <= 0.0:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = blend
		return mat
	var mode: String = "blend_add" if blend == CanvasItemMaterial.BLEND_MODE_ADD else "blend_mix"
	var shader := Shader.new()
	shader.code = FEATHER_SHADER_SRC % mode
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("feather", clampf(feather, 0.0, 1.0))
	return sm


## A unit circle (radius 1) as a triangle fan, so an instance's scale IS its
## radius. Built once per overlay and never touched again.
##
## The winding and the starting angle both matter for the pixel gate: Godot's
## `draw_circle` walks from angle 0 counter-clockwise, and a mesh that starts
## elsewhere rasterizes the same shape from different triangles — same coverage,
## but not necessarily the same pixels on the boundary.
static func _build_unit_circle() -> ArrayMesh:
	var n: int = maxi(segments, 3)
	var verts := PackedVector2Array()
	verts.resize(n * 3)
	## D-4 — UVs, unconditionally. The soft rim is a SHADER, not geometry (see
	## `attach()`), and a shader needs somewhere to read "how far out am I" from.
	## Unit-circle position mapped to [0,1]^2, so `length(UV * 2 - 1)` is the
	## normalised radius. Harmless when no shader is attached — nothing samples it.
	var uvs := PackedVector2Array()
	uvs.resize(n * 3)
	var i: int = 0
	for s in range(n):
		var a0: float = TAU * float(s) / float(n)
		var a1: float = TAU * float(s + 1) / float(n)
		var p0 := Vector2(cos(a0), sin(a0))
		var p1 := Vector2(cos(a1), sin(a1))
		verts[i] = Vector2.ZERO
		verts[i + 1] = p0
		verts[i + 2] = p1
		uvs[i] = Vector2(0.5, 0.5)
		uvs[i + 1] = p0 * 0.5 + Vector2(0.5, 0.5)
		uvs[i + 2] = p1 * 0.5 + Vector2(0.5, 0.5)
		i += 3
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Start a frame. `capacity` is an upper bound on how many circles will follow —
## the buffer is resized to it once instead of grown per push.
func begin(capacity: int) -> void:
	_count = 0
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## One circle. No allocation, no `Transform2D` object — the eight floats are
## written straight into the buffer in the order `MultiMesh` reads them:
## row 0 is (basis.x.x, basis.y.x, 0, origin.x), row 1 is (basis.x.y, basis.y.y,
## 0, origin.y). A circle needs no rotation and no skew, so the off-diagonal
## terms are zero and the diagonal is the radius.
func push(pos: Vector2, radius: float, color: Color) -> void:
	var o: int = _count * FLOATS_PER_INSTANCE
	_buf[o] = radius
	_buf[o + 1] = 0.0
	_buf[o + 2] = 0.0
	_buf[o + 3] = pos.x
	_buf[o + 4] = 0.0
	_buf[o + 5] = radius
	_buf[o + 6] = 0.0
	_buf[o + 7] = pos.y
	_buf[o + 8] = color.r
	_buf[o + 9] = color.g
	_buf[o + 10] = color.b
	_buf[o + 11] = color.a
	_count += 1


## Publish the frame. ONE engine call for every circle pushed.
##
## `instance_count` is set BEFORE the buffer, and the buffer is sliced to exactly
## the live instances: `MultiMesh` rejects a buffer whose length disagrees with
## `instance_count * FLOATS_PER_INSTANCE`, and the buffer is deliberately kept
## larger than the frame needs so it never reallocates.
func flush() -> void:
	if _mm == null:
		return
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


## Drop everything on screen (map load, overlay clear).
func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0
