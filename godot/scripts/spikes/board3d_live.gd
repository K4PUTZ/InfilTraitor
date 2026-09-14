## Board3DLive — the LIVE board, as depth-tested 3D meshes under the 2D game.
##
## DIAG-21 step 1 (DEVICE_DIAGNOSTICS_MASTER_PLAN §15.7). An instrument, never a
## mode: `RENDER3D=1` builds it after a real map load and hides the 2D voxel board.
## Actors, fog, overlays and the HUD keep drawing in 2D, on top of it.
##
## WHAT IT PROVES THAT DIAG-20's SPIKE COULD NOT: the spike rebuilt PLAYGROUND from
## its JSON. This reads the game's own data after the real load — every visible
## Voxel of every Slice (half thickness and material bands included), every junction
## corner column, and every floor, deep-floor and roof Slab. The light and the soot
## come from the live `VoxelLightField`, one value per exposed face, with the 2D face
## shader's own terms: bucket luminance × face tone × per-face soot × floor depth dim.
## Nothing here is a second authority. It reads, it never writes.
##
## THE LOOK, and how it maps from 2D:
##  - voxel (grid x, level, grid y) → world (x/8, (level − ground plane)/8, y/8), so a
##    GU is one world unit and a storey one unit tall (the 30° camera's cube);
##  - only the three faces the camera can see are emitted — top (+Y), SE (+X) and
##    SW (+Z) — the same three `VoxelLightField.surface_factor()` names;
##  - a material is `base_color × facade luminance`, the bake's MULTIPLY, sampled in
##    world space at 16 texels per voxel with mirrored repeat;
##  - coplanar faces with the same material and the same quantised colour are merged
##    into one quad (greedy), per chunk of 32×32 voxels.
##
## ⚠️ NOT PARITY — stated so no capture is read as one: no damage decals, no bake
## window origins (facade continuity is world-space, not per wall run), glass is a
## flat translucent tint, actors are not occluded by walls, and the 2D storey is 158 px
## where this 30° camera draws 156.8 (walls ~0.8% shorter than the sprites expect).
## The camera follows the 2D camera every frame, so the 2D game stays aligned on the
## ground plane.
extends Node3D

const CHUNK_VOXELS: int = 32
## Facade texels per voxel is ART_SPECIFICATIONS' TEX_AUTHORING_N (16), so a
## 1024×512 facade spans 64×32 voxels.
const FACADE_SPAN_VOXELS: Vector2 = Vector2(64.0, 32.0)
enum Dir { TOP, SE, SW }
const DIR_STEP: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]
const DIR_NORMAL: Array[Vector3] = [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)]
## The 2D face shader's defaults, used only when its live material cannot be read.
const FALLBACK_SOOT_MULT: Array[float] = [0.33, 0.47, 0.69, 0.84]
const FALLBACK_TONE: Array[float] = [1.0, 0.975, 0.945]

## ⚠️ THE MATHS HAPPENS IN sRGB, AND ONLY THE PRODUCT IS LINEARISED. The 2D path
## multiplies base colour × facade luminance (the bake) and then × light × soot × tone
## (the face shader) on sRGB-encoded values, because a 2D canvas never converts. A
## spatial shader's ALBEDO is LINEAR and gets encoded on output, so feeding it those
## same numbers raw lifts every mid-tone — measured on the first desktop capture: the
## board came out pale grey where 2D is dark. So the product is computed exactly as 2D
## does, then decoded once. The facade sampler carries no `source_color` hint for the
## same reason: its luminance is a multiplier in sRGB space, not a colour to decode.
const OPAQUE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform vec3 base_color = vec3(0.6);
uniform float has_facade = 0.0;
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	vec2 f = mod(UV, 2.0);
	vec2 mirrored = mix(f, 2.0 - f, step(1.0, f));
	float lum = has_facade > 0.5 ? texture(facade, mirrored).r : 1.0;
	ALBEDO = srgb_to_linear(base_color * lum * COLOR.rgb);
}
"""
const GLASS_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec3 base_color = vec3(0.55, 0.7, 0.9);
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	ALBEDO = srgb_to_linear(base_color * COLOR.rgb);
	ALPHA = 0.35;
}
"""

## One material's geometry for one chunk. The Packed arrays are MEMBERS on purpose:
## a Packed array is a value type, so `(dict["v"] as PackedVector3Array).append()`
## appends to a copy — measured on the first run: every surface came out empty and
## `add_surface_from_arrays` failed 139 times.
class SurfaceData:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func add_quad(corners: Array[Vector3], unit: float, normal: Vector3, shade: float,
			face_uvs: Array[Vector2]) -> void:
		var base_index: int = vertices.size()
		for i: int in range(4):
			vertices.append(corners[i] * unit)
			normals.append(normal)
			colours.append(Color(shade, shade, shade, 1.0))
			uvs.append(face_uvs[i])
		for offset: int in [0, 1, 2, 0, 2, 3]:
			indices.append(base_index + offset)


var _room: Node = null
var _cell_to_world: Callable
var _camera: Camera3D = null
var _ground_level: int = 0
## Vector3i(grid x, level, grid y) → index into _material_ids.
var _occ: Dictionary = {}
var _by_chunk: Dictionary = {}  ## Vector2i → Array[Vector3i]
var _material_ids: PackedStringArray = PackedStringArray()
var _material_index: Dictionary = {}
var _material_glass: Array[bool] = []
var _shader_materials: Array[ShaderMaterial] = []
var _light_ladder: Array[float] = []
var _soot_mult: Array[float] = []
var _tone: Array[float] = []
var _px_per_unit: float = 1.0
var _origin_2d: Vector2 = Vector2.ZERO
var _to_gu: Transform2D = Transform2D.IDENTITY


## Build the whole board. `cell_to_world` is Room's own GU-centre → 2D world point
## (it carries VISUAL_GRID_OFFSET, which this file must never know).
func build(room: Node, cell_to_world: Callable) -> void:
	_room = room
	_cell_to_world = cell_to_world
	_ground_level = GeometryCoords.PLAYABLE_LEVEL
	var t0: int = Time.get_ticks_usec()
	var counts: Dictionary = _collect()
	var t1: int = Time.get_ticks_usec()
	_read_look()
	_make_camera()
	var quads: int = 0
	var faces: int = 0
	for chunk: Vector2i in _by_chunk:
		var built: Vector2i = _build_chunk(chunk)
		faces += built.x
		quads += built.y
	var t2: int = Time.get_ticks_usec()
	var cells_2d: int = _count_2d_cells()
	var fields: Dictionary = {
		"voxels": _occ.size(), "slice_voxels": counts["slices"],
		"column_voxels": counts["columns"], "slab_voxels": counts["slabs"],
		"cells_2d": cells_2d, "faces": faces, "quads": quads, "chunks": _by_chunk.size(),
		"materials": _material_ids.size(), "collect_ms": float(t1 - t0) / 1000.0,
		"mesh_ms": float(t2 - t1) / 1000.0,
		"light": "field" if _light_field() != null else "unavailable",
	}
	print("[BOARD3D] %d voxel(s) (slices %d, columns %d, slabs %d; the 2D board holds %d cell(s)) → %d face(s) → %d quad(s) in %d chunk(s), %d material(s); collect %.0f ms, mesh %.0f ms, light %s"
		% [fields["voxels"], fields["slice_voxels"], fields["column_voxels"],
		fields["slab_voxels"], cells_2d, faces, quads, fields["chunks"],
		fields["materials"], fields["collect_ms"], fields["mesh_ms"], fields["light"]])
	Telemetry.event("board3d.built", fields)


func _process(_delta: float) -> void:
	if _camera == null or _room == null:
		return
	var cam2d: Camera2D = _room.camera
	var centre: Vector2 = cam2d.get_screen_center_position()
	var gu: Vector2 = _to_gu * (centre - _origin_2d)
	var target := Vector3(gu.x + 0.5, 0.0, gu.y + 0.5)
	_camera.size = get_viewport().get_visible_rect().size.y / cam2d.zoom.y / _px_per_unit
	_camera.position = target + _camera.basis.z * 200.0


# ── data ──────────────────────────────────────────────────────────────────────

func _collect() -> Dictionary:
	var slices: int = 0
	var columns: int = 0
	var slabs: int = 0
	for slice: Slice in _room._edge_registry.all_slices():
		var base: int = GeometryCoords.storey_level_base(slice.start_storey)
		for voxel: Voxel in slice.voxels:
			if voxel.visible:
				_put(voxel.grid_pos, voxel.level, slice.material_at(voxel.level - base))
				slices += 1
	for column in _room._junction_columns:
		var column_material: String = column.override_material \
			if column.override_material != "" else column.material
		for voxel: Voxel in column.voxels:
			if voxel.visible:
				_put(voxel.grid_pos, voxel.level, column_material)
				columns += 1
	for slab: Slab in _room._slab_registry.all_slabs():
		for voxel: Voxel in slab.voxels:
			if voxel.visible:
				_put(voxel.grid_pos, voxel.level, slab.material)
				slabs += 1
	return {"slices": slices, "columns": columns, "slabs": slabs}


func _put(grid: Vector2i, level: int, material_id: String) -> void:
	if not _material_index.has(material_id):
		_material_index[material_id] = _material_ids.size()
		_material_ids.append(material_id)
		_material_glass.append(GlassMaterials.is_glass(material_id))
		_shader_materials.append(_make_material(material_id))
	var key := Vector3i(grid.x, level, grid.y)
	if not _occ.has(key):
		var chunk := Vector2i(floori(float(grid.x) / float(CHUNK_VOXELS)),
			floori(float(grid.y) / float(CHUNK_VOXELS)))
		if not _by_chunk.has(chunk):
			_by_chunk[chunk] = []
		(_by_chunk[chunk] as Array).append(key)
	_occ[key] = _material_index[material_id]


func _light_field() -> VoxelLightField:
	return _room._voxel_light_field


## The 2D path's own look terms, read from the live renderer and its face shader.
func _read_look() -> void:
	var renderer: VoxelRenderer = _room._voxel_renderer
	_light_ladder = renderer.bucket_luminance.duplicate()
	_soot_mult = FALLBACK_SOOT_MULT.duplicate()
	_tone = FALLBACK_TONE.duplicate()
	var layer: TileMapLayer = renderer.get_layer(renderer.ground_plane_level())
	var shader_material := layer.material as ShaderMaterial if layer != null else null
	if shader_material == null:
		push_warning("[Board3DLive] no face ShaderMaterial on the ground layer — soot and tone use the shader's defaults")
		return
	var soot: Variant = shader_material.get_shader_parameter("soot_face_mult")
	if soot is Vector4:
		var s: Vector4 = soot
		_soot_mult = [s.x, s.y, s.z, s.w]
	for i: int in range(3):
		var tone: Variant = shader_material.get_shader_parameter(["face_top", "face_se", "face_sw"][i])
		if tone is float:
			_tone[i] = tone


func _face_colour(key: Vector3i, dir: int) -> int:
	var cell := Vector2i(key.x, key.z)
	var f: float = _tone[dir]
	var field: VoxelLightField = _light_field()
	if field != null:
		f *= _light_ladder[clampi(field.bucket_for(cell, key.y), 0, _light_ladder.size() - 1)]
		var soot: Vector3i = VoxelLightField.decode_face_soot(field.face_soot_code(cell, key.y))
		var ring: int = [soot.x, soot.y, soot.z][dir]
		if ring < BlastCalculator.FACE_SOOT_CLEAN:
			f *= _soot_mult[ring]
	var rel: int = (_room._voxel_renderer as VoxelRenderer).relative_level(key.y)
	if rel < 0:
		f *= VoxelRenderer.FLOOR_DEPTH_DIM[mini(-rel - 1, VoxelRenderer.FLOOR_DEPTH_DIM.size() - 1)]
	return clampi(roundi(f * 255.0), 0, 255)


func _count_2d_cells() -> int:
	var renderer: VoxelRenderer = _room._voxel_renderer
	var cells: int = 0
	for level in range(GeometryCoords.FLOOR_DEEP_LEVEL, renderer.top_wall_level() + 1):
		var layer: TileMapLayer = renderer.get_layer(level)
		if layer != null:
			cells += layer.get_used_cells().size()
	return cells


# ── meshing ───────────────────────────────────────────────────────────────────

## Returns Vector2i(faces emitted, quads after merging).
func _build_chunk(chunk: Vector2i) -> Vector2i:
	var planes: Dictionary = {}  ## Vector2i(dir, plane) → {Vector2i(u, v): material * 256 + colour}
	var faces: int = 0
	for key: Vector3i in _by_chunk[chunk]:
		var material: int = _occ[key]
		var glass: bool = _material_glass[material]
		for dir: int in range(3):
			var neighbour: int = _occ.get(key + DIR_STEP[dir], -1)
			## Hidden by a neighbour, unless that neighbour is glass and this is not.
			if neighbour != -1 and not (_material_glass[neighbour] and not glass):
				continue
			var plane_key: Vector2i
			var uv: Vector2i
			if dir == Dir.TOP:
				plane_key = Vector2i(dir, key.y)
				uv = Vector2i(key.x, key.z)
			elif dir == Dir.SE:
				plane_key = Vector2i(dir, key.x)
				uv = Vector2i(key.z, key.y)
			else:
				plane_key = Vector2i(dir, key.z)
				uv = Vector2i(key.x, key.y)
			if not planes.has(plane_key):
				planes[plane_key] = {}
			(planes[plane_key] as Dictionary)[uv] = material * 256 + _face_colour(key, dir)
			faces += 1

	var surfaces: Dictionary = {}  ## material → SurfaceData
	var quads: int = 0
	for plane_key: Vector2i in planes:
		quads += _merge_plane(plane_key.x, plane_key.y, planes[plane_key], surfaces)

	var mesh := ArrayMesh.new()
	for material: int in surfaces:
		var surface: SurfaceData = surfaces[material]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_COLOR] = surface.colours
		arrays[Mesh.ARRAY_TEX_UV] = surface.uvs
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _shader_materials[material])
	if mesh.get_surface_count() > 0:
		var instance := MeshInstance3D.new()
		instance.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	return Vector2i(faces, quads)


## Greedy rectangles over one plane's faces: grow along u, then along v, while every
## cell carries the same material and quantised colour.
func _merge_plane(dir: int, plane: int, cells: Dictionary, surfaces: Dictionary) -> int:
	var keys: Array = cells.keys()
	keys.sort()
	var done: Dictionary = {}
	var quads: int = 0
	for start: Vector2i in keys:
		if done.has(start):
			continue
		var value: int = cells[start]
		var w: int = 1
		while int(cells.get(start + Vector2i(w, 0), -1)) == value and not done.has(start + Vector2i(w, 0)):
			w += 1
		var h: int = 1
		var grow: bool = true
		while grow:
			for i: int in range(w):
				var probe: Vector2i = start + Vector2i(i, h)
				if int(cells.get(probe, -1)) != value or done.has(probe):
					grow = false
					break
			if grow:
				h += 1
		for j: int in range(h):
			for i: int in range(w):
				done[start + Vector2i(i, j)] = true
		@warning_ignore("integer_division")
		_emit_quad(dir, plane, start, w, h, value / 256, value % 256, surfaces)
		quads += 1
	return quads


func _emit_quad(dir: int, plane: int, start: Vector2i, w: int, h: int, material: int,
		colour: int, surfaces: Dictionary) -> void:
	if not surfaces.has(material):
		surfaces[material] = SurfaceData.new()
	var surface: SurfaceData = surfaces[material]
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground: float = float(_ground_level)
	## Corners in voxel units (x, level above ground, grid y), wound like DIAG-20's
	## spike, whose captures showed all three face kinds.
	var corners: Array[Vector3] = []
	if dir == Dir.TOP:
		var y: float = float(plane) + 1.0 - ground
		var x0: float = float(start.x)
		var x1: float = float(start.x + w)
		var z0: float = float(start.y)
		var z1: float = float(start.y + h)
		corners = [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	elif dir == Dir.SE:
		var x: float = float(plane) + 1.0
		var z0: float = float(start.x)
		var z1: float = float(start.x + w)
		var y0: float = float(start.y) - ground
		var y1: float = float(start.y + h) - ground
		corners = [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)]
	else:
		var z: float = float(plane) + 1.0
		var x0: float = float(start.x)
		var x1: float = float(start.x + w)
		var y0: float = float(start.y) - ground
		var y1: float = float(start.y + h) - ground
		corners = [Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), Vector3(x1, y0, z)]
	var face_uvs: Array[Vector2] = []
	for corner: Vector3 in corners:
		var uv: Vector2
		if dir == Dir.TOP:
			uv = Vector2(corner.x, corner.z)
		elif dir == Dir.SE:
			uv = Vector2(corner.z, -corner.y)
		else:
			uv = Vector2(corner.x, -corner.y)
		face_uvs.append(uv / FACADE_SPAN_VOXELS)
	surface.add_quad(corners, unit, DIR_NORMAL[dir], float(colour) / 255.0, face_uvs)


# ── look ──────────────────────────────────────────────────────────────────────

func _make_material(material_id: String) -> ShaderMaterial:
	var shader := Shader.new()
	var shader_material := ShaderMaterial.new()
	var definition = Registries.get_material_registry().get_material(material_id)
	var colour: Color = definition.base_color if definition != null else Color(0.6, 0.6, 0.6)
	if GlassMaterials.is_glass(material_id):
		shader.code = GLASS_SHADER
		shader_material.shader = shader
		shader_material.set_shader_parameter("base_color", Vector3(colour.r, colour.g, colour.b))
		return shader_material
	shader.code = OPAQUE_SHADER
	shader_material.shader = shader
	shader_material.set_shader_parameter("base_color", Vector3(colour.r, colour.g, colour.b))
	var resolved = TextureResolver.new().resolve("facade_%s" % material_id, material_id)
	if resolved != null and resolved.image != null:
		var image: Image = (resolved.image as Image).duplicate()
		image.generate_mipmaps()
		shader_material.set_shader_parameter("facade", ImageTexture.create_from_image(image))
		shader_material.set_shader_parameter("has_facade", 1.0)
	return shader_material


func _make_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Board3DCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	## D26's 30° down / 45° around — the angle every character bake is taken at.
	_camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	_camera.near = 0.05
	_camera.far = 500.0
	add_child(_camera)
	_camera.make_current()
	## The 2D ground plane as an affine map of GU centres, measured from Room itself.
	_origin_2d = _cell_to_world.call(Vector2i.ZERO)
	var ex: Vector2 = Vector2(_cell_to_world.call(Vector2i(1, 0))) - _origin_2d
	var ez: Vector2 = Vector2(_cell_to_world.call(Vector2i(0, 1))) - _origin_2d
	_to_gu = Transform2D(ex, ez, Vector2.ZERO).affine_inverse()
	## One GU step along grid x crosses cos(45°) camera units horizontally.
	_px_per_unit = absf(ex.x) / cos(deg_to_rad(45.0))
