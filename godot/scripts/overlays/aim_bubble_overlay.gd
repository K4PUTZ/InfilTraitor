extends Node2D
class_name AimBubbleOverlay
## AimBubbleOverlay / E-BUBBLE — the grenade blast dome shown while aiming.
##
## Director, 2026-08-10, on the first version: "A bolha azul está gigante, tem
## que ser bem menor, cobrindo uma área de 3x3 GU aproximadamente. (...) Queremos
## mostrar apenas a bolha translúcida como um domo, uma esfera seccionada pelo
## chão (e paredes próximas), como em XCOM (ver a referência grenade.webp)."
## Reference: `REFERENCES/granade.webp`.
##
## So this is deliberately NOT the predicted damage footprint. The real blast
## silhouette has holes in it — cells shadowed by walls, cells that survive their
## tier roll — and the Director ruled that out explicitly: the dome reads as
## "this is the shape of the explosion", clean, and the per-cell truth is carried
## by ShrapnelPreviewOverlay's rays instead. Keeping the two jobs in two overlays
## is what lets the dome stay a simple analytic shape.
##
## WHAT IS DRAWN: a hemisphere of `radius_gu` GU sitting on the floor at the
## target, SECTIONED by the floor and by every nearby wall, plus — on the face of
## each of those walls — the patch the sphere actually covers, carrying its own
## grid. Director, 2026-08-12, with a diagram: "a bolha precisa ser seccionada
## pelas paredes, e não apenas distorcer o grid interno como foi feito. Vamos
## aumentar o número de linhas e engrossar todas elas, incluindo as bordas
## externas (...) Em vez de distorcer o grid da bolha, na realidade vamos ter um
## grid interno em volta das paredes, nas áreas em que estiverem dentro da bolha."
## A first attempt that only bent the grid was rejected ("a distorção não é
## assim... vai ser uma coisa mais angulosa"): the silhouette itself is cut, the
## sphere's grid is HIDDEN where a wall stops it (never bent), and each wall wears
## a grid in its own axes.
##
## ============================================================================
## AIM-DOME-3D (2026-10-09) — THE DOME IS 3D GEOMETRY NOW.
##
## Until today the dome was the 2D board's drawing: every redraw tessellated the
## sectioned silhouette, the floor section, the lat/long grid and the wall
## patches on the CPU (~900 rays against the walls, thousands of polyline points)
## and R3D-WORLD placed the result on the camera plane through `WorldCanvas3D`.
## Measured on the Galaxy A16 (FrameSplit): ~4-9 ms per redraw, paid on every
## move of the aim, ~15-35 ms on the Moto. Now the shapes are built ONCE (a unit
## hemisphere shell and a unit floor disc) and the section is decided per pixel
## in the shaders (`aim_dome3d*.gdshader`), from the nearby walls passed as
## uniforms; a move of the aim packs those walls, builds one quad per wall that
## reaches the sphere, and sets uniforms. What each pass draws:
##
##   volume  the shell's front faces, the translucent fill       priority 0
##   floor   the ground section, its fill and outline            priority 1
##   grid    the lat/long wireframe, both faces                  priority 2
##   patch   one quad per wall, fill + grid + border             priority 3
##   rim     the silhouette, front faces                         priority 4
##
## below ShrapnelPreviewOverlay's rays (priority 5), as AIM_Z_DOME sits under
## AIM_Z_RAYS. Like the 2D dome, every pass draws OVER the walls (no depth test):
## which part of a wall is inside the bubble is the dome's own geometry, not the
## depth buffer's.
##
## THE DATA. `room._blast_wall_height_edges()` — EdgeExtractor's own per-edge
## `start_storey`/`storey_count`, keyed by `WallEdgeData.edge_key()` (architecture
## Rule 3). 1 storey == 1 GU, since `GeometryCoords.LEVELS_PER_STOREY ==
## VOXELS_PER_UNIT_AXIS == 8`. Per-edge height is not a nicety: "vamos ter
## parapeitos, morros e outros cenários com paredes mais baixas. Precisamos
## calcular por edge e por slice" (Director, 2026-08-11) — a parapet must cut only
## the low part of the dome and let it bulge over the top.
## ============================================================================

## Tuning — `var` per architecture Rule 1. Widths are 2D canvas pixels at zoom 1
## (the 2D dome's units, kept so its calibration carries over).
## Orange since 2026-08-10 ("vamos mudar a arte bolha de azul para laranja").
var dome_color: Color = Color(1.0, 0.66, 0.30, 1.0)
var fill_alpha: float = 0.13          ## the dome's volume
var floor_fill_alpha: float = 0.20    ## the ground section, denser than the volume
var floor_line_alpha: float = 0.55    ## the section's own outline
var rim_alpha: float = 0.90           ## the sphere's silhouette
var line_width: float = 3.5           ## "engrossar todas elas, incluindo as bordas externas"
var grid_alpha: float = 0.45
var grid_line_width: float = 2.4
var lat_ring_count: int = 5           ## strictly between the equator and the pole
var long_meridian_count: int = 12     ## evenly spaced around the vertical axis
var wall_fill_alpha: float = 0.24
var wall_line_alpha: float = 0.85
var wall_grid_alpha: float = 0.60
## Spacing of the wall patch's own grid, in GU, along both of the wall's axes (2 voxels).
var wall_grid_step_gu: float = 0.25
## Extra cells beyond `radius_gu` to scan for wall edges: an edge is looked up by
## the cell PAIR it separates, so the far cell of a boundary `radius_gu` out still
## has to be inside the scan.
var wall_search_margin: float = 1.0
## Mesh resolution of the shell and the floor disc (built once).
var shell_segments: int = 64
var shell_rings: int = 16

## Flat wall-segment record: `SEG_STRIDE` floats per wall, in GU relative to the
## dome's centre — the shaders' `seg_a` / `seg_z` uniforms are built from it.
const SEG_STRIDE: int = 6
const SEG_AXIS_X: int = 0       ## 1.0 when the wall separates two cells along X
const SEG_POS: int = 1          ## the wall plane's offset from the dome centre, GU
const SEG_SPAN_MIN: int = 2     ## bounds along the axis the wall RUNS on, GU
const SEG_SPAN_MAX: int = 3
const SEG_Z_MIN: int = 4        ## the wall's real height range, GU above the floor
const SEG_Z_MAX: int = 5
## The shaders' uniform array size (`aim_dome3d.gdshaderinc` MAX_SEGMENTS).
const MAX_SEGMENTS: int = 32
const SHADER_DIR := "res://godot/shaders/"

var _center: Vector2 = Vector2.ZERO
var _center_gu: Vector2i = Vector2i.ZERO
var _radius_gu: float = 0.0
var _wall_height_edges: Dictionary = {}
var _board: Node3D = null
var _root: Node3D = null            ## at the dome's floor centre, in GU (storeys up)
var _shell: MeshInstance3D = null   ## unit hemisphere, scaled by the radius
var _floor: MeshInstance3D = null   ## unit disc, scaled by the radius
var _patches: MeshInstance3D = null ## one quad per wall the sphere reaches, built in GU
var _patch_mesh: ArrayMesh = null
var _materials: Array[ShaderMaterial] = []  ## every pass, for the shared uniforms


func set_board3d(board: Node3D) -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_materials.clear()
	_board = board
	if board != null:
		_build_nodes()
	_apply()


func _ready() -> void:
	visible = false


## Show the dome centred on a floor position, sized in GAME UNITS. `center_gu` is
## the same position as a grid cell — the walls are looked up by cell pair, so
## the screen position alone cannot find them — and `wall_height_edges` is
## `room._blast_wall_height_edges()`, passed in rather than reached for so this
## overlay keeps knowing nothing about Room.
func show_dome(center: Vector2, radius_gu: float, center_gu: Vector2i,
		wall_height_edges: Dictionary) -> void:
	_center = center
	_center_gu = center_gu
	_radius_gu = radius_gu
	_wall_height_edges = wall_height_edges
	visible = true
	_apply()


func clear() -> void:
	visible = false
	_radius_gu = 0.0
	if _root != null:
		_root.visible = false


## One move of the aim: place the dome, pack the walls into the uniforms, rebuild the wall quads.
func _apply() -> void:
	if _root == null or _board == null:
		return
	if not visible or _radius_gu < 0.001:
		_root.visible = false
		return
	var segments: PackedFloat32Array = _nearby_wall_segments()
	_root.position = _board.call("ground_point", _center)
	## A storey is `VERTICAL_SCALE` world units tall: the board's `Geometry` node carries it as its y scale.
	var geometry: Node3D = _board.get_node_or_null("Geometry") as Node3D
	_root.scale = Vector3(1.0, geometry.scale.y if geometry != null else 1.0, 1.0)
	_shell.scale = Vector3.ONE * _radius_gu
	_floor.scale = Vector3.ONE * _radius_gu
	var count: int = mini(segments.size() / SEG_STRIDE, MAX_SEGMENTS)
	if segments.size() / SEG_STRIDE > MAX_SEGMENTS:
		push_warning("[AimBubbleOverlay] %d walls near the dome, the shaders take %d: the rest do not cut it"
			% [segments.size() / SEG_STRIDE, MAX_SEGMENTS])
	var seg_a := PackedVector4Array()
	var seg_z := PackedVector2Array()
	seg_a.resize(MAX_SEGMENTS)
	seg_z.resize(MAX_SEGMENTS)
	for i: int in range(count):
		var o: int = i * SEG_STRIDE
		seg_a[i] = Vector4(segments[o + SEG_AXIS_X], segments[o + SEG_POS], segments[o + SEG_SPAN_MIN], segments[o + SEG_SPAN_MAX])
		seg_z[i] = Vector2(segments[o + SEG_Z_MIN], segments[o + SEG_Z_MAX])
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("radius", _radius_gu)
		m.set_shader_parameter("vertex_scale", _radius_gu if m.has_meta("unit_mesh") else 1.0)
		m.set_shader_parameter("seg_count", count)
		m.set_shader_parameter("seg_a", seg_a)
		m.set_shader_parameter("seg_z", seg_z)
	_build_patches(segments)
	_root.visible = true


## The nodes and materials, once per board. The shell and the disc are unit meshes; their scale is the radius.
func _build_nodes() -> void:
	_root = Node3D.new()
	_root.name = "AimDome3D"
	_root.visible = false
	_board.add_child(_root)
	var shell_mesh: ArrayMesh = _hemisphere_mesh()
	var volume: ShaderMaterial = _material("aim_dome3d_volume", 0, true)
	volume.set_shader_parameter("fill_alpha", fill_alpha)
	var grid: ShaderMaterial = _material("aim_dome3d_grid", 2, true)
	grid.set_shader_parameter("grid_alpha", grid_alpha)
	grid.set_shader_parameter("grid_width", grid_line_width)
	grid.set_shader_parameter("long_meridians", float(long_meridian_count))
	grid.set_shader_parameter("lat_rings", float(lat_ring_count))
	var rim: ShaderMaterial = _material("aim_dome3d_rim", 4, true)
	rim.set_shader_parameter("rim_alpha", rim_alpha)
	rim.set_shader_parameter("rim_width", line_width)
	volume.next_pass = grid
	grid.next_pass = rim
	_shell = _mesh_node("Shell", shell_mesh, volume)
	var floor_mat: ShaderMaterial = _material("aim_dome3d_floor", 1, true)
	for pair: Array in [["floor_fill_alpha", floor_fill_alpha],
			["floor_line_alpha", floor_line_alpha], ["rim_alpha", rim_alpha], ["line_width", line_width]]:
		floor_mat.set_shader_parameter(pair[0], pair[1])
	_floor = _mesh_node("Floor", _disc_mesh(), floor_mat)
	var patch_mat: ShaderMaterial = _material("aim_dome3d_patch", 3, false)
	for pair: Array in [["fill_alpha", fill_alpha], ["wall_fill_alpha", wall_fill_alpha],
			["wall_line_alpha", wall_line_alpha], ["wall_grid_alpha", wall_grid_alpha],
			["wall_grid_step", wall_grid_step_gu], ["line_width", line_width], ["grid_width", grid_line_width]]:
		patch_mat.set_shader_parameter(pair[0], pair[1])
	_patch_mesh = ArrayMesh.new()
	_patches = _mesh_node("WallPatches", _patch_mesh, patch_mat)


## `unit`: the pass draws a unit mesh scaled by the radius (`vertex_scale`); otherwise its mesh is in GU already.
func _material(shader_name: String, priority: int, unit: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_DIR + shader_name + ".gdshader") as Shader
	m.render_priority = priority
	m.set_shader_parameter("dome_color", Vector3(dome_color.r, dome_color.g, dome_color.b))
	m.set_shader_parameter("px_per_unit_2d", float(_board.call("px_per_unit")))
	m.set_shader_parameter("vertex_scale", 1.0)
	if unit:
		## The unit meshes ride the node's scale; the shader works in GU, so it scales them back by the radius.
		m.set_meta("unit_mesh", true)
	_materials.append(m)
	return m


func _mesh_node(node_name: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(node)
	return node


## The unit hemisphere, y up, normals outward, built once.
func _hemisphere_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: int in range(shell_rings):
		var phi0: float = (PI * 0.5) * float(r) / float(shell_rings)
		var phi1: float = (PI * 0.5) * float(r + 1) / float(shell_rings)
		for s: int in range(shell_segments):
			var t0: float = TAU * float(s) / float(shell_segments)
			var t1: float = TAU * float(s + 1) / float(shell_segments)
			var a := _unit(t0, phi0)
			var b := _unit(t1, phi0)
			var c := _unit(t1, phi1)
			var d := _unit(t0, phi1)
			## Godot's front faces wind clockwise as seen from outside.
			for p: Vector3 in [a, b, c, a, c, d]:
				st.set_normal(p)
				st.add_vertex(p)
	return st.commit()


## The unit floor disc at y = 0, normal up, built once.
func _disc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: int in range(shell_segments):
		var t0: float = TAU * float(s) / float(shell_segments)
		var t1: float = TAU * float(s + 1) / float(shell_segments)
		for p: Vector3 in [Vector3.ZERO, Vector3(cos(t0), 0.0, sin(t0)), Vector3(cos(t1), 0.0, sin(t1))]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()


## Unit direction for (theta, phi): theta around the vertical axis from grid x toward grid y, phi up from the floor.
static func _unit(theta: float, phi: float) -> Vector3:
	return Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta))


## One quad per wall the sphere reaches, on the wall's plane, in GU: the wall's rectangle trimmed to the square around
## the disc the plane cuts out of the sphere. The shader keeps the disc and drops what a nearer wall shadows.
func _build_patches(segments: PackedFloat32Array) -> void:
	_patch_mesh.clear_surfaces()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	var i: int = 0
	while i < segments.size() and i / SEG_STRIDE < MAX_SEGMENTS:
		var axis_x: bool = segments[i + SEG_AXIS_X] > 0.5
		var pos: float = segments[i + SEG_POS]
		var cut: float = sqrt(maxf(_radius_gu * _radius_gu - pos * pos, 0.0))
		var u_min: float = segments[i + SEG_SPAN_MIN]
		var u_max: float = segments[i + SEG_SPAN_MAX]
		var v_min: float = maxf(segments[i + SEG_Z_MIN], 0.0)
		var v_max: float = segments[i + SEG_Z_MAX]
		var u0: float = maxf(u_min, -cut)
		var u1: float = minf(u_max, cut)
		var v0: float = v_min
		var v1: float = minf(v_max, cut)
		i += SEG_STRIDE
		if cut <= 0.001 or u1 <= u0 or v1 <= v0:
			continue
		var corners: Array[Vector2] = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)]
		for uv: Vector2 in corners:
			verts.append(Vector3(pos, uv.y, uv.x) if axis_x else Vector3(uv.x, uv.y, pos))
			uvs.append(uv)
			uv2s.append(Vector2(cut, 1.0 if axis_x else 0.0))
			custom.append_array(PackedFloat32Array([u_min, u_max, v_min, v_max]))
	if verts.is_empty():
		_patches.visible = false
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	_patch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	_patches.visible = true


## Wall segments near the dome, in GU relative to `_center_gu`, packed flat (see
## SEG_STRIDE). Each is a straight vertical plane perpendicular to one grid axis
## — cell edges are exactly that, since GU cell CENTRES sit at integer offsets
## and a wall sits on the shared boundary half a GU either side.
func _nearby_wall_segments() -> PackedFloat32Array:
	var raw: Array = []
	if _wall_height_edges.is_empty():
		return PackedFloat32Array()
	var reach: int = int(ceil(_radius_gu + wall_search_margin))
	for dx: int in range(-reach, reach + 1):
		for dy: int in range(-reach, reach + 1):
			var cell_a: Vector2i = _center_gu + Vector2i(dx, dy)
			for delta: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var cell_b: Vector2i = cell_a + delta
				var key: String = WallEdgeData.edge_key(cell_a, cell_b)
				if not _wall_height_edges.has(key):
					continue
				var info: Dictionary = _wall_height_edges[key]
				var mid: Vector2 = Vector2(cell_a - _center_gu) + Vector2(delta) * 0.5
				var z_min: float = float(info["start_storey"])
				var z_max: float = z_min + float(info["storey_count"])
				var axis_x: bool = delta.x == 1
				var pos: float = mid.x if axis_x else mid.y
				var along: float = mid.y if axis_x else mid.x
				## A wall entirely outside the sphere can never cut it, and
				## dropping it here is what keeps the per-pixel loop short.
				if absf(pos) >= _radius_gu or z_min >= _radius_gu:
					continue
				raw.append([axis_x, pos, along - 0.5, along + 0.5, z_min, z_max])
	return _merge_collinear(raw)


## Fuses cell-edges that are really one wall into one segment.
##
## NOT an optimization, though it is also that. `EdgeExtractor` works per cell
## PAIR, so a plain 7 GU wall arrives as seven 1 GU edges sharing a plane and a
## height. Each segment becomes one wall patch with its own border, so unfused
## edges would put six full-weight seam strokes across the middle of what is one
## flat surface, and the patch would read as a row of tiles instead of a wall.
static func _merge_collinear(raw: Array) -> PackedFloat32Array:
	var merged := PackedFloat32Array()
	if raw.is_empty():
		return merged
	## Same plane and same height range first, then ordered along the span, so a
	## run of touching edges lands contiguously and one linear pass fuses it.
	raw.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return not bool(a[0])
		if not is_equal_approx(a[1], b[1]):
			return float(a[1]) < float(b[1])
		if not is_equal_approx(a[4], b[4]):
			return float(a[4]) < float(b[4])
		if not is_equal_approx(a[5], b[5]):
			return float(a[5]) < float(b[5])
		return float(a[2]) < float(b[2]))

	var current: Array = raw[0].duplicate()
	for i: int in range(1, raw.size()):
		var next: Array = raw[i]
		var same_plane: bool = bool(next[0]) == bool(current[0]) \
			and is_equal_approx(float(next[1]), float(current[1])) \
			and is_equal_approx(float(next[4]), float(current[4])) \
			and is_equal_approx(float(next[5]), float(current[5]))
		if same_plane and float(next[2]) <= float(current[3]) + 0.001:
			current[3] = maxf(float(current[3]), float(next[3]))
			continue
		_append_segment(merged, current)
		current = next.duplicate()
	_append_segment(merged, current)
	return merged


static func _append_segment(into: PackedFloat32Array, seg: Array) -> void:
	into.append(1.0 if bool(seg[0]) else 0.0)
	into.append(float(seg[1]))
	into.append(float(seg[2]))
	into.append(float(seg[3]))
	into.append(float(seg[4]))
	into.append(float(seg[5]))
