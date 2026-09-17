## Board3DLive — the LIVE board, as depth-tested 3D meshes under the 2D game.
##
## DIAG-21 (DEVICE_DIAGNOSTICS_MASTER_PLAN §15.7–§15.10) built this as a spike under
## `spikes/`. RENDER3D R3D-3 (2026-09-17) moved it here — production code, not an
## instrument, though it still runs behind `RENDER3D=1` until R3D-8 retires the 2D
## board: `RENDER3D=1` builds it after a real map load and hides the 2D voxel board.
## Actors, fog, overlays and the HUD keep drawing in 2D, on top of it.
##
## WHAT IT READS: every visible Voxel of every Slice (half thickness and material bands
## included), every junction corner column, every floor, deep-floor and roof Slab — the
## game's own registries after the real load. It reads, it never writes game state.
##
## THE LOOK, and how it maps from 2D:
##  - voxel (grid x, level, grid y) → world (x/8, (level − ground plane)/8, y/8), so a
##    GU is one world unit and a storey one unit tall (the 30° camera's cube);
##  - only the three faces the camera can see are emitted — top (+Y), SE (+X) and
##    SW (+Z) — the same three `VoxelLightField.surface_factor()` names;
##  - a material is `base_color × facade luminance`, the bake's MULTIPLY, sampled in
##    world space at 16 texels per voxel with mirrored repeat;
##  - LIGHT AND SOOT ARE PER CELL, NOT PER VERTEX (step 2c). The fragment finds its own
##    voxel from its world position and reads bucket and soot code from a
##    `Texture2DArray` holding the 2D renderer's own cell planes, one layer per level —
##    the same RG8 data the 2D face shader reads. So faces merge by MATERIAL only, and
##    a soot or light change is a layer upload instead of a remesh. Step 2 rebuilt
##    geometry for colour changes and paid ~240 ms per rebuild on the Moto (§15.9);
##  - the 2D face shader's terms are applied in the same order: face tone × bucket
##    luminance × per-face soot × floor depth dim, all in sRGB, the product decoded once.
##
## ⚠️ NOT PARITY — stated so no capture is read as one: no damage decals, no bake
## window origins (facade continuity is world-space, not per wall run), glass is a
## flat translucent tint, actors are not occluded by walls, the soot fade and the light
## ramp land at their ends instead of stepping, and the 2D storey is 158 px where this
## 30° camera draws 156.8 (walls ~0.8% shorter than the sprites expect).
extends Node3D

## RENDER3D R3D-3 step 3 — 16 vs 32, chosen by measurement on the Moto (DevFlags
## `RENDER3D_CHUNK`, read at `build()`, before any chunk math runs). 16 wins: initial
## load is a wash (collect/mesh ~1013-1056 ms either way — dominated by the store walk,
## not chunk count), but a blast's remesh — the part that stalls the main thread on the
## impact frame, before R3D-3 step 4 threads it — dropped from 108.4/104.4 ms (32) to
## 38.9/0.2 ms (16) across both PLAYGROUND grenades: a smaller chunk means less
## unaffected geometry gets re-merged alongside the cells a blast actually touched.
static var CHUNK_VOXELS: int = 16

## RENDER3D R3D-1c step 5 — the board meshes straight from the `VoxelStore` (DevFlags
## `STORE_BOARD3D`, read at `build()` through the Room; DEFAULT ON; `=0` collects the objects
## into `_occ` as before). Without an active store the object path runs.
##
## One semantic difference, ratified: a cell two claims hold stays occupied while EITHER
## stands (the store's `occ`). The object path erased the cell when a destroyed claim was
## folded in, even with the other claim standing — the Director's option A (2026-09-16,
## "the voxels are the truth") for the same corner cells in the light's occupancy.
static var STORE_BOARD3D: bool = true

## RENDER3D R3D-3 step 2 — the vertical-scale spike. A true cube in this camera projects
## 32 px/√2 × cos 30° = 19.6 px/level (156.8 px/storey), but the 2D board's sprites and
## bakes expect `WALL_FLOOR_STEP_PX` = 158 px/storey — a ~0.8% gap. `VERTICAL_SCALE`
## stretches the mesh (not the camera — see `_geometry_root`) by this ratio when set to
## `VERTICAL_SCALE_MATCHED`; `1.0` (default) is the true-cube variant. DevFlags
## `RENDER3D_VSCALE`, read at `build()`. A Director look-call, not a code decision — see
## `RENDER3D_MASTER_PLAN` R3D-3 step 2.
static var VERTICAL_SCALE: float = 1.0
const VERTICAL_SCALE_MATCHED: float = 158.0 / 156.8
## Dev-only, off by default (DevFlags `RENDER3D_VSCALE_MARKER`) — a bright box spanning
## exactly one storey (8 levels) at a fixed cell, so the look-call has a fixed reference
## that stretches WITH the board instead of a bespoke overlay.
static var VSCALE_MARKER: bool = false
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
## multiplies on sRGB-encoded values because a 2D canvas never converts; a spatial
## shader's ALBEDO is linear. Measured on the first desktop capture: fed raw, the board
## came out pale grey where 2D is dark. The facade sampler carries no `source_color`
## hint for the same reason — its luminance is a multiplier in sRGB space.
const OPAQUE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform vec3 base_color = vec3(0.6);
uniform float has_facade = 0.0;
uniform sampler2DArray cell_plane : filter_nearest, repeat_disable;
uniform int level_base = 0;
uniform int level_count = 1;
uniform int mesh_ground_level = 80;
uniform int rel_offset = -80;
uniform ivec2 plane_origin = ivec2(64, 64);
uniform int plane_size = 512;
uniform float bucket_lum[12];
uniform vec4 soot_mult = vec4(0.33, 0.47, 0.69, 0.84);
uniform vec3 face_tone = vec3(1.0, 0.975, 0.945);
uniform float depth_dim[5];
varying vec3 v_world;
varying vec3 v_normal;
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = NORMAL;
}
void fragment() {
	// The voxel this pixel belongs to: half a voxel back along the face normal.
	ivec3 v = ivec3(floor(v_world * 8.0 - v_normal * 0.5));
	int level = v.y + mesh_ground_level;
	ivec2 pc = ivec2(v.x, v.z) + plane_origin;
	int layer = level - level_base;
	float code = 124.0;
	int bucket = 255;
	if (layer >= 0 && layer < level_count && pc.x >= 0 && pc.y >= 0
			&& pc.x < plane_size && pc.y < plane_size) {
		vec4 t = texelFetch(cell_plane, ivec3(pc, layer), 0);
		code = clamp(floor(t.r * 255.0 + 0.5), 0.0, 124.0);
		bucket = int(floor(t.g * 255.0 + 0.5));
	}
	int face = v_normal.y > 0.5 ? 0 : (v_normal.x > 0.5 ? 1 : 2);
	float ring = face == 0 ? floor(code / 25.0)
			: (face == 1 ? floor(mod(code, 25.0) / 5.0) : mod(code, 5.0));
	float f = face_tone[face] * bucket_lum[clamp(bucket, 0, 11)];
	f *= ring < 3.5 ? soot_mult[int(ring)] : 1.0;
	int rel = level + rel_offset;
	if (rel < 0) {
		f *= depth_dim[min(-rel - 1, 4)];
	}
	vec2 fr = mod(UV, 2.0);
	vec2 mirrored = mix(fr, 2.0 - fr, step(1.0, fr));
	float lum = has_facade > 0.5 ? texture(facade, mirrored).r : 1.0;
	ALBEDO = srgb_to_linear(base_color * lum * f);
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
	ALBEDO = srgb_to_linear(base_color);
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
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func add_quad(corners: Array[Vector3], unit: float, normal: Vector3,
			face_uvs: Array[Vector2]) -> void:
		var base_index: int = vertices.size()
		for i: int in range(4):
			vertices.append(corners[i] * unit)
			normals.append(normal)
			uvs.append(face_uvs[i])
		for offset: int in [0, 1, 2, 0, 2, 3]:
			indices.append(base_index + offset)


var _room: Node = null
var _cell_to_world: Callable
var _camera: Camera3D = null
## RENDER3D R3D-3 step 2 — every chunk mesh (and the vscale marker) parents here, not
## directly under `self`, so `VERTICAL_SCALE` stretches only the geometry: `_camera` stays
## a direct child of `self` and is unaffected by this node's non-uniform scale.
var _geometry_root: Node3D = null
var _ground_level: int = 0
## Vector3i(grid x, level, grid y) → index into _material_ids.
var _occ: Dictionary = {}
var _by_chunk: Dictionary = {}  ## Vector2i → {Vector3i: true}
var _chunk_nodes: Dictionary = {}  ## Vector2i → MeshInstance3D
## The chunks and levels the last blast commit touched, so the soot and light beats
## that follow re-upload the same levels.
var _blast_chunks: Dictionary = {}
var _blast_levels: Dictionary = {}
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
var _plane: Texture2DArray = null
var _level_min: int = 0
var _level_max: int = -1
## Per-remesh phase clocks (usec), reset by _remesh().
var _store: VoxelStore = null
## Claims grouped by chunk: `_chunk_claims[_chunk_start[c] .. _chunk_start[c + 1]]`, chunk
## c = cy * _chunk_cols + cx over the store's padded bounds.
var _chunk_claims := PackedInt32Array()
var _chunk_start := PackedInt32Array()
var _chunk_cols: int = 0
var _chunk_rows: int = 0
var _chunk_x0: int = 0
var _chunk_y0: int = 0
## Store material index → this board's material index.
var _store_material := PackedInt32Array()
var _t_collect: int = 0
var _t_merge: int = 0
var _t_commit: int = 0

## RENDER3D R3D-3 step 4 — the remesh's collect+merge phase (pure data, no scene-tree or
## RenderingServer touch) runs on a `WorkerThreadPool` task; only the mesh commit (making
## `ArrayMesh`/`MeshInstance3D` and adding them under `_geometry_root`) stays on the main
## thread, in `_process()`. `-1` = idle. Only ONE remesh task is ever in flight: a request
## that arrives while one is running is coalesced into `_remesh_queue` instead of starting
## a second task, since both would read `_store`'s arrays while nothing else in this
## turn-based model writes them mid-remesh — a second concurrent WRITER is the actual
## hazard this avoids, not a second reader.
var _remesh_task_id: int = -1
var _remesh_result: Array = []  ## [{chunk, surfaces, faces, quads}], written by the task
var _remesh_task_end_us: int = 0  ## set by the task itself, off-thread, when its loop ends
var _remesh_meta: Dictionary = {}
var _remesh_queue: Dictionary = {}  ## chunk -> true, merged into the next task on completion
var _remesh_queue_meta: Dictionary = {}


## Build the whole board. `cell_to_world` is Room's own GU-centre → 2D world point
## (it carries VISUAL_GRID_OFFSET, which this file must never know).
func build(room: Node, cell_to_world: Callable) -> void:
	_room = room
	_cell_to_world = cell_to_world
	_ground_level = GeometryCoords.PLAYABLE_LEVEL
	var t0: int = Time.get_ticks_usec()
	STORE_BOARD3D = str(room.call("_dev_flag", "STORE_BOARD3D", "1")) != "0"
	CHUNK_VOXELS = int(str(room.call("_dev_flag", "RENDER3D_CHUNK", "16")))
	VERTICAL_SCALE = _read_vertical_scale(room)
	VSCALE_MARKER = str(room.call("_dev_flag", "RENDER3D_VSCALE_MARKER", "0")) != "0"
	_geometry_root = Node3D.new()
	_geometry_root.name = "Geometry"
	_geometry_root.scale.y = VERTICAL_SCALE
	add_child(_geometry_root)
	_store = VoxelStore.active if STORE_BOARD3D else null
	var counts: Dictionary = _collect_store(_store) if _store != null else _collect()
	var t1: int = Time.get_ticks_usec()
	_read_look()
	_build_plane()
	_make_camera()
	var quads: int = 0
	var faces: int = 0
	for chunk: Vector2i in (_store_chunks() if _store != null else _by_chunk.keys()):
		var built: Vector2i = _build_chunk(chunk)
		faces += built.x
		quads += built.y
	if VSCALE_MARKER:
		_add_vscale_marker()
	var t2: int = Time.get_ticks_usec()
	var cells_2d: int = _count_2d_cells()
	var fields: Dictionary = {
		"voxels": int(counts.get("cells", _occ.size())), "slice_voxels": counts["slices"],
		"column_voxels": counts["columns"], "slab_voxels": counts["slabs"],
		"cells_2d": cells_2d, "faces": faces, "quads": quads,
		"chunks": int(counts.get("chunks", _by_chunk.size())),
		"materials": _material_ids.size(), "collect_ms": float(t1 - t0) / 1000.0,
		"mesh_ms": float(t2 - t1) / 1000.0, "plane_levels": _level_max - _level_min + 1,
		"skip_2d_writes": VoxelRenderer.SKIP_BOARD_WRITES,
	}
	print("[BOARD3D] %d voxel(s) (slices %d, columns %d, slabs %d; the 2D board holds %d cell(s)) → %d face(s) → %d quad(s) in %d chunk(s), %d material(s), plane levels %d..%d; collect %.0f ms, mesh %.0f ms; skip 2D writes %s; source %s"
		% [fields["voxels"], fields["slice_voxels"], fields["column_voxels"],
		fields["slab_voxels"], cells_2d, faces, quads, fields["chunks"],
		fields["materials"], _level_min, _level_max, fields["collect_ms"],
		fields["mesh_ms"], VoxelRenderer.SKIP_BOARD_WRITES,
		"store" if _store != null else "objects"])
	Telemetry.event("board3d.built", fields)


## RENDER3D R3D-3 step 2 — `RENDER3D_VSCALE=matched` (or any float string) selects the
## vertical-scale variant for the look-call; anything else (including unset) is the
## true-cube default.
func _read_vertical_scale(room: Node) -> float:
	var raw: String = str(room.call("_dev_flag", "RENDER3D_VSCALE", "1.0"))
	if raw == "matched":
		return VERTICAL_SCALE_MATCHED
	var parsed: float = raw.to_float()
	return parsed if parsed > 0.0 else 1.0


## A bright, unshaded box spanning exactly one storey (8 levels, one world Y-unit in
## `_geometry_root`'s local space, so it stretches with `VERTICAL_SCALE` exactly like the
## board's own geometry) at a fixed, open PLAYGROUND cell — the Director's fixed reference
## for the look-call, standing in for a baked agent this stage doesn't have wired in yet.
func _add_vscale_marker() -> void:
	var marker := MeshInstance3D.new()
	marker.name = "VScaleMarker"
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 1.0, 0.06)
	marker.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.0, 1.0)
	marker.material_override = mat
	marker.position = Vector3(5.5, 0.5, 5.5)
	_geometry_root.add_child(marker)


## Guards against the node leaving the tree (a map reload/rotation freeing this board to
## build a fresh one) while a remesh task is still reading `self` on a background thread —
## a background task holding an implicit `self` reference outliving this Node's free would
## be a use-after-free. Blocks briefly only in that rare case; a normal frame never hits it.
func _exit_tree() -> void:
	if _remesh_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_remesh_task_id)
		_remesh_task_id = -1


func _process(_delta: float) -> void:
	if _remesh_task_id != -1 and WorkerThreadPool.is_task_completed(_remesh_task_id):
		_finish_remesh_task()
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


## This board's index for a material, registering it (and its shader material) on first use.
func _material(material_id: String) -> int:
	if not _material_index.has(material_id):
		_material_index[material_id] = _material_ids.size()
		_material_ids.append(material_id)
		_material_glass.append(GlassMaterials.is_glass(material_id))
		_shader_materials.append(_make_material(material_id))
	return int(_material_index[material_id])


func _put(grid: Vector2i, level: int, material_id: String) -> void:
	_material(material_id)
	var key := Vector3i(grid.x, level, grid.y)
	if not _occ.has(key):
		var chunk: Vector2i = _chunk_of(key)
		if not _by_chunk.has(chunk):
			_by_chunk[chunk] = {}
		(_by_chunk[chunk] as Dictionary)[key] = true
		if _level_max < _level_min:
			_level_min = level
			_level_max = level
		else:
			_level_min = mini(_level_min, level)
			_level_max = maxi(_level_max, level)
	_occ[key] = _material_index[material_id]


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


## One Texture2DArray layer per occupied level, filled from the 2D renderer's cell
## plane for that level (or a clean, unwritten plane when the renderer has none), and
## every opaque material pointed at it.
func _build_plane() -> void:
	var renderer: VoxelRenderer = _room._voxel_renderer
	var images: Array[Image] = []
	for level in range(_level_min, _level_max + 1):
		images.append(_plane_image(level))
	_plane = Texture2DArray.new()
	var err: int = _plane.create_from_images(images)
	if err != OK:
		push_error("[Board3DLive] Texture2DArray.create_from_images failed (%s) — faces will read full light, no soot" % error_string(err))
	var ladder := PackedFloat32Array(_light_ladder)
	var dims := PackedFloat32Array(VoxelRenderer.FLOOR_DEPTH_DIM)
	var rel_offset: int = renderer.relative_level(_ground_level) - _ground_level
	for i: int in range(_shader_materials.size()):
		if _material_glass[i]:
			continue
		var m: ShaderMaterial = _shader_materials[i]
		m.set_shader_parameter("cell_plane", _plane)
		m.set_shader_parameter("level_base", _level_min)
		m.set_shader_parameter("level_count", _level_max - _level_min + 1)
		m.set_shader_parameter("mesh_ground_level", _ground_level)
		m.set_shader_parameter("rel_offset", rel_offset)
		m.set_shader_parameter("plane_origin", VoxelRenderer.SOOT_PLANE_ORIGIN)
		m.set_shader_parameter("plane_size", VoxelRenderer.SOOT_TEX_SIZE)
		m.set_shader_parameter("bucket_lum", ladder)
		m.set_shader_parameter("soot_mult", Vector4(_soot_mult[0], _soot_mult[1], _soot_mult[2], _soot_mult[3]))
		m.set_shader_parameter("face_tone", Vector3(_tone[0], _tone[1], _tone[2]))
		m.set_shader_parameter("depth_dim", dims)


func _plane_image(level: int) -> Image:
	var image: Image = (_room._voxel_renderer as VoxelRenderer).cell_plane_image(level)
	if image != null:
		return image
	var blank := Image.create(VoxelRenderer.SOOT_TEX_SIZE, VoxelRenderer.SOOT_TEX_SIZE,
		false, Image.FORMAT_RG8)
	blank.fill(Color8(VoxelRenderer.FACE_SOOT_CODE_CLEAN, VoxelRenderer.BUCKET_UNWRITTEN, 0, 255))
	return blank


## Re-upload the plane layers for these levels — the whole cost of a soot or light
## change on this board.
func _sync_levels(levels: Dictionary, reason: String) -> void:
	if _plane == null:
		return
	var t0: int = Time.get_ticks_usec()
	var uploaded: int = 0
	for level: int in levels:
		if level < _level_min or level > _level_max:
			continue
		_plane.update_layer(_plane_image(level), level - _level_min)
		uploaded += 1
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("[BOARD3D] recolour %s — %d level(s) uploaded in %.1f ms" % [reason, uploaded, ms])
	Telemetry.event("board3d.recolour", {"reason": reason, "levels": uploaded, "ms": ms})


func _count_2d_cells() -> int:
	var renderer: VoxelRenderer = _room._voxel_renderer
	var cells: int = 0
	for level in range(GeometryCoords.FLOOR_DEEP_LEVEL, renderer.top_wall_level() + 1):
		var layer: TileMapLayer = renderer.get_layer(level)
		if layer != null:
			cells += layer.get_used_cells().size()
	return cells


# ── detonation (DIAG-21 step 2 / 2c) ──────────────────────────────────────────

## The presenter's commit frame: the frame the 2D board shows the blast's damage.
## Folds every touched voxel's new visibility into the occupancy, rebuilds the chunks
## whose faces can have changed, and uploads the levels the commit wrote soot into.
func on_blast_commit(delta) -> void:
	var t0: int = Time.get_ticks_usec()
	_blast_chunks = {}
	_blast_levels = {}
	for voxel: Voxel in delta.touched_voxels:
		var key := Vector3i(voxel.grid_pos.x, voxel.level, voxel.grid_pos.y)
		var chunk: Vector2i = _chunk_of(key)
		_blast_levels[voxel.level] = true
		if _store != null:
			## R3D-1c step 5 — the store already holds the commit (every write mirrors), so
			## there is nothing to fold: only which chunks to rebuild.
			_blast_chunks[chunk] = true
			_blast_chunks[_chunk_of(key - Vector3i(1, 0, 0))] = true
			_blast_chunks[_chunk_of(key - Vector3i(0, 0, 1))] = true
			continue
		if voxel.visible:
			var material_id: String = _material_for(voxel)
			if material_id.is_empty():
				continue
			_put(voxel.grid_pos, voxel.level, material_id)
		elif _occ.has(key):
			_occ.erase(key)
			(_by_chunk.get(chunk, {}) as Dictionary).erase(key)
		_blast_chunks[chunk] = true
		## An emptied cell exposes the +X face of its −X neighbour and the +Z face of
		## its −Z neighbour, which live in the previous chunk at a chunk boundary.
		_blast_chunks[_chunk_of(key - Vector3i(1, 0, 0))] = true
		_blast_chunks[_chunk_of(key - Vector3i(0, 0, 1))] = true
	## The deep floor a blast reveals sits one level down; its plane row was written too.
	for level: int in _blast_levels.keys():
		_blast_levels[level - 1] = true
	var t1: int = Time.get_ticks_usec()
	_remesh(_blast_chunks, "commit", delta.touched_voxels.size(), float(t1 - t0) / 1000.0)
	_sync_levels(_blast_levels, "commit")


## After the soot fade: the same levels, re-uploaded with the settled scorch.
func on_blast_soot() -> void:
	_sync_levels(_blast_levels, "soot")


## After the consequence light: the blast's levels plus every level holding a cell
## whose light moved.
func on_blast_light(delta) -> void:
	var levels: Dictionary = _blast_levels.duplicate()
	if delta != null:
		for k: Vector3i in delta.light_changed_cells:
			## light_changed_cells keys are (cell.x, cell.y, level).
			levels[k.z] = true
	_sync_levels(levels, "light")


## RENDER3D R3D-3 step 4 — queues a remesh on the `WorkerThreadPool`; never blocks the
## caller. If a task is already in flight, the requested chunks are coalesced into
## `_remesh_queue` and picked up the moment the running task finishes — never a second
## concurrent task, since both would read `_store`'s arrays while this turn-based game
## never writes them mid-remesh (a second concurrent WRITER is the hazard avoided, not a
## second reader).
func _remesh(chunks: Dictionary, reason: String, voxels: int, fold_ms: float) -> void:
	if _remesh_task_id != -1:
		for chunk: Vector2i in chunks:
			_remesh_queue[chunk] = true
		_remesh_queue_meta = {"reason": reason, "voxels": voxels, "fold_ms": fold_ms}
		return
	_start_remesh_task(chunks, reason, voxels, fold_ms)


func _start_remesh_task(chunks: Dictionary, reason: String, voxels: int, fold_ms: float) -> void:
	_remesh_meta = {"reason": reason, "voxels": voxels, "fold_ms": fold_ms,
		"t0": Time.get_ticks_usec()}
	_remesh_result = []
	var chunk_list: Array = chunks.keys()
	_remesh_task_id = WorkerThreadPool.add_task(
		func() -> void: _remesh_task_body(chunk_list))


## Runs OFF the main thread. Writes into `_remesh_result` (this `Board3DLive` instance
## isn't touched by anything else while a task is in flight — `_remesh_task_id != -1`
## blocks a second task, and nothing else in this turn-based model mutates the store mid-
## remesh) and never touches the scene tree or a `RenderingServer` resource.
func _remesh_task_body(chunk_list: Array) -> void:
	for chunk: Vector2i in chunk_list:
		var collected: Dictionary = _collect_and_merge_chunk(chunk)
		_remesh_result.append({"chunk": chunk, "surfaces": collected["surfaces"],
			"faces": collected["faces"], "quads": collected["quads"],
			"collect_us": collected["collect_us"], "merge_us": collected["merge_us"]})
	## Measured OFF-thread, so `_finish_remesh_task()` can tell real background work
	## apart from however long the main thread took to notice `is_task_completed()` —
	## the two were conflated the first time this shipped and made an ordinary poll
	## delay read as an 1100 ms merge on the Moto (2026-09-17).
	_remesh_task_end_us = Time.get_ticks_usec()


## Called from `_process()` once `WorkerThreadPool.is_task_completed()` is true. Commits
## every collected chunk's mesh on the main thread, prints the same line and records the
## same telemetry event the synchronous path always has, then starts the queued
## follow-up task if one coalesced while this one ran.
func _finish_remesh_task() -> void:
	WorkerThreadPool.wait_for_task_completion(_remesh_task_id)
	_remesh_task_id = -1
	_t_collect = 0
	_t_merge = 0
	_t_commit = 0
	var quads: int = 0
	var t_commit_start: int = Time.get_ticks_usec()
	for entry: Dictionary in _remesh_result:
		_commit_chunk_mesh(entry["chunk"], entry["surfaces"])
		quads += int(entry["quads"])
		_t_collect += int(entry["collect_us"])
		_t_merge += int(entry["merge_us"])
	var t3: int = Time.get_ticks_usec()
	_t_commit = t3 - t_commit_start
	## The background work's own span (accurate, timed on its own thread) vs however
	## long the main thread took to poll and notice — reported separately so a busy
	## main thread's poll delay is never mistaken for background cost.
	var background_ms: float = float(_remesh_task_end_us - int(_remesh_meta["t0"])) / 1000.0
	var poll_latency_ms: float = float(t_commit_start - _remesh_task_end_us) / 1000.0
	var mesh_ms: float = float(t3 - int(_remesh_meta["t0"])) / 1000.0
	var reason: String = str(_remesh_meta["reason"])
	var voxels: int = int(_remesh_meta["voxels"])
	var fold_ms: float = float(_remesh_meta["fold_ms"])
	print("[BOARD3D] remesh %s — %d chunk(s), %d quad(s), %d voxel(s) folded in %.1f ms, mesh %.1f ms (faces %.1f · merge %.1f · upload %.1f · poll-latency %.1f) [threaded, background %.1f ms]"
		% [reason, _remesh_result.size(), quads, voxels, fold_ms, mesh_ms,
		float(_t_collect) / 1000.0, float(_t_merge) / 1000.0, float(_t_commit) / 1000.0,
		poll_latency_ms, background_ms])
	Telemetry.event("board3d.remesh", {"reason": reason, "chunks": _remesh_result.size(),
		"quads": quads, "voxels": voxels, "fold_ms": fold_ms, "mesh_ms": mesh_ms,
		"faces_ms": float(_t_collect) / 1000.0, "merge_ms": float(_t_merge) / 1000.0,
		"upload_ms": float(_t_commit) / 1000.0, "poll_latency_ms": poll_latency_ms,
		"background_ms": background_ms, "threaded": true})
	if not _remesh_queue.is_empty():
		var next_chunks: Dictionary = _remesh_queue
		var next_meta: Dictionary = _remesh_queue_meta
		_remesh_queue = {}
		_remesh_queue_meta = {}
		_start_remesh_task(next_chunks, str(next_meta.get("reason", "commit")),
			int(next_meta.get("voxels", 0)), float(next_meta.get("fold_ms", 0.0)))


func _chunk_of(key: Vector3i) -> Vector2i:
	return Vector2i(floori(float(key.x) / float(CHUNK_VOXELS)),
		floori(float(key.z) / float(CHUNK_VOXELS)))


## R3D-1c step 5 — the store's claims, grouped by chunk with one counting sort, and its
## materials mapped onto this board's. Chunks are `_chunk_of()`'s WORLD chunks
## (floor(x / 32), floor(y / 32)), so a blast's dirty-chunk keys mean the same thing on
## both paths. Every claim is listed, visible or not: a claim hidden at load can only
## become visible through a rebuild, but the list must not depend on that.
## Reports `_collect()`'s counts from the claims' visible bits; `cells` counts each
## occupied cell once, by its owner.
func _collect_store(store: VoxelStore) -> Dictionary:
	_store_material.resize(store.material_ids.size())
	for i in range(store.material_ids.size()):
		_store_material[i] = _material(store.material_ids[i])
	var n: int = store.claims
	var xyz: PackedInt32Array = store.xyz
	var state: PackedByteArray = store.state
	_chunk_x0 = floori(float(store.x0) / float(CHUNK_VOXELS))
	_chunk_y0 = floori(float(store.y0) / float(CHUNK_VOXELS))
	_chunk_cols = floori(float(store.x0 + store.w - 1) / float(CHUNK_VOXELS)) - _chunk_x0 + 1
	_chunk_rows = floori(float(store.y0 + store.h - 1) / float(CHUNK_VOXELS)) - _chunk_y0 + 1
	var chunk_of_claim := PackedInt32Array()
	chunk_of_claim.resize(n)
	_chunk_start.resize(_chunk_cols * _chunk_rows + 1)
	_chunk_start.fill(0)
	## Per-kind visible claims, then occupied cells: plain ints, no Dictionary write per claim.
	var by_kind := PackedInt32Array([0, 0, 0])
	var cells: int = 0
	var owner: PackedInt32Array = store.owner
	var x0: int = store.x0
	var y0: int = store.y0
	var l0: int = store.l0
	var w: int = store.w
	var h: int = store.h
	var lo: int = 1 << 30
	var hi: int = -(1 << 30)
	for ci in range(store.container_count()):
		var span: Vector2i = store.container_claims(ci)
		var kind: int = store.container_kinds[ci]
		var visible_here: int = 0
		for claim in range(span.x, span.x + span.y):
			var k: int = claim * 3
			var x: int = xyz[k]
			var y: int = xyz[k + 1]
			var c: int = ((y >> 5) - _chunk_y0) * _chunk_cols + ((x >> 5) - _chunk_x0)
			chunk_of_claim[claim] = c
			_chunk_start[c + 1] += 1
			if not (state[claim] & 1):
				continue
			visible_here += 1
			var level: int = xyz[k + 2]
			if owner[((level - l0) * h + (y - y0)) * w + (x - x0)] == claim:
				cells += 1
			if level < lo:
				lo = level
			if level > hi:
				hi = level
		by_kind[kind] += visible_here
	if hi >= lo:
		_level_min = lo
		_level_max = hi
	var used: int = 0
	for c in range(_chunk_cols * _chunk_rows):
		if _chunk_start[c + 1] > 0:
			used += 1
		_chunk_start[c + 1] += _chunk_start[c]
	var fill := PackedInt32Array(_chunk_start)
	_chunk_claims.resize(n)
	for claim in range(n):
		var c: int = chunk_of_claim[claim]
		_chunk_claims[fill[c]] = claim
		fill[c] += 1
	return {"slices": by_kind[VoxelStore.KIND_SLICE], "slabs": by_kind[VoxelStore.KIND_SLAB],
		"columns": by_kind[VoxelStore.KIND_COLUMN], "cells": cells, "chunks": used}


## The chunks that hold any claim, as `_by_chunk`'s keys would be.
func _store_chunks() -> Array:
	var out: Array = []
	for c in range(_chunk_cols * _chunk_rows):
		if _chunk_start[c + 1] > _chunk_start[c]:
			var cy: int = floori(float(c) / float(_chunk_cols))
			out.append(Vector2i(c - cy * _chunk_cols + _chunk_x0, cy + _chunk_y0))
	return out


## A voxel's material through its container — the same answer `_collect()` gave.
func _material_for(voxel: Voxel) -> String:
	var container: Object = instance_from_id(voxel.container_id())
	if container is Slice:
		var slice: Slice = container
		return slice.material_at(voxel.level - GeometryCoords.storey_level_base(slice.start_storey))
	if container is Slab:
		return (container as Slab).material
	if container is JunctionResolver.JunctionColumn:
		var column: JunctionResolver.JunctionColumn = container
		return column.override_material if column.override_material != "" else column.material
	push_warning("[Board3DLive] voxel %s has no known container — not drawn" % voxel)
	return ""


# ── meshing ───────────────────────────────────────────────────────────────────

## Synchronous collect+merge+commit — used by the initial full build (`build()`'s own
## loop over every chunk at load, not latency-sensitive the way a mid-game blast is).
## Returns Vector2i(faces emitted, quads after merging).
func _build_chunk(chunk: Vector2i) -> Vector2i:
	var collected: Dictionary = _collect_and_merge_chunk(chunk)
	var t2: int = Time.get_ticks_usec()
	_commit_chunk_mesh(chunk, collected["surfaces"])
	var t3: int = Time.get_ticks_usec()
	_t_collect += int(collected["collect_us"])
	_t_merge += int(collected["merge_us"])
	_t_commit += t3 - t2
	return Vector2i(collected["faces"], collected["quads"])


## RENDER3D R3D-3 step 4 — the thread-safe half: face collection and greedy-rectangle
## merging, touching only `_store`/`_occ`/`_by_chunk`/`_material_glass` (read-only here)
## and producing plain data (`SurfaceData`, a GDScript class of `Packed*Array`s — not a
## `Resource`, so building it off the main thread is safe). No `ArrayMesh`, no
## `MeshInstance3D`, no scene-tree touch — those need the main thread and live in
## `_commit_chunk_mesh()`.
func _collect_and_merge_chunk(chunk: Vector2i) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var planes: Dictionary = {}  ## Vector2i(dir, plane) → {Vector2i(u, v): material}
	var faces: int = 0
	if _store != null:
		faces = _collect_chunk_faces_store(chunk, planes)
	for key: Vector3i in ({} if _store != null else (_by_chunk.get(chunk, {}) as Dictionary)):
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
			(planes[plane_key] as Dictionary)[uv] = material
			faces += 1
	var t1: int = Time.get_ticks_usec()

	var surfaces: Dictionary = {}  ## material → SurfaceData
	var quads: int = 0
	for plane_key: Vector2i in planes:
		quads += _merge_plane(plane_key.x, plane_key.y, planes[plane_key], surfaces)
	var t2: int = Time.get_ticks_usec()
	return {"surfaces": surfaces, "faces": faces, "quads": quads,
		"collect_us": t1 - t0, "merge_us": t2 - t1}


## The main-thread-only half: turn `SurfaceData` into a real `ArrayMesh`/`MeshInstance3D`
## and swap it into `_geometry_root`.
func _commit_chunk_mesh(chunk: Vector2i, surfaces: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	for material: int in surfaces:
		var surface: SurfaceData = surfaces[material]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_TEX_UV] = surface.uvs
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _shader_materials[material])
	var previous: Node = _chunk_nodes.get(chunk)
	if previous != null:
		previous.queue_free()
		_chunk_nodes.erase(chunk)
	if mesh.get_surface_count() > 0:
		var instance := MeshInstance3D.new()
		instance.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_geometry_root.add_child(instance)
		_chunk_nodes[chunk] = instance


## R3D-1c step 5 — `_build_chunk()`'s face pass, read from the store: a cell is drawn by
## its owner claim, a neighbour hides a face when the store's `occ` holds it (unless it is
## glass and this is not), and materials map through `_store_material`. Returns the faces
## added to `planes`, in `_build_chunk()`'s (dir, plane) → {uv: material} shape.
func _collect_chunk_faces_store(chunk: Vector2i, planes: Dictionary) -> int:
	var cidx: int = (chunk.y - _chunk_y0) * _chunk_cols + (chunk.x - _chunk_x0)
	if chunk.x < _chunk_x0 or chunk.y < _chunk_y0 or chunk.x - _chunk_x0 >= _chunk_cols \
			or chunk.y - _chunk_y0 >= _chunk_rows:
		return 0
	var store: VoxelStore = _store
	var state: PackedByteArray = store.state
	var xyz: PackedInt32Array = store.xyz
	var occ: PackedByteArray = store.occ
	var owner: PackedInt32Array = store.owner
	var mat: PackedByteArray = store.mat
	var steps: PackedInt32Array = [store.plane, 1, store.w]
	var faces: int = 0
	for i in range(_chunk_start[cidx], _chunk_start[cidx + 1]):
		var claim: int = _chunk_claims[i]
		if not (state[claim] & 1):
			continue
		var k: int = claim * 3
		var x: int = xyz[k]
		var y: int = xyz[k + 1]
		var level: int = xyz[k + 2]
		var cell: int = store.cell_index(x, y, level)
		if owner[cell] != claim:
			continue
		var material: int = _store_material[mat[claim]]
		var glass: bool = _material_glass[material]
		for dir: int in range(3):
			var n: int = cell + steps[dir]
			if occ[n]:
				## Hidden by a neighbour, unless that neighbour is glass and this is not.
				if not (_material_glass[_store_material[mat[owner[n]]]] and not glass):
					continue
			var plane_key: Vector2i
			var uv: Vector2i
			if dir == Dir.TOP:
				plane_key = Vector2i(dir, level)
				uv = Vector2i(x, y)
			elif dir == Dir.SE:
				plane_key = Vector2i(dir, x)
				uv = Vector2i(y, level)
			else:
				plane_key = Vector2i(dir, y)
				uv = Vector2i(x, level)
			if not planes.has(plane_key):
				planes[plane_key] = {}
			(planes[plane_key] as Dictionary)[uv] = material
			faces += 1
	return faces


## Greedy rectangles over one plane's faces: grow along u, then along v, while every
## cell carries the same material.
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
		_emit_quad(dir, plane, start, w, h, value, surfaces)
		quads += 1
	return quads


func _emit_quad(dir: int, plane: int, start: Vector2i, w: int, h: int, material: int,
		surfaces: Dictionary) -> void:
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
	surface.add_quad(corners, unit, DIR_NORMAL[dir], face_uvs)


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
