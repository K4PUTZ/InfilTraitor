## Board3DLive — THE board: the voxel world as depth-tested 3D meshes under the 2D game.
##
## DIAG-21 (DEVICE_DIAGNOSTICS_MASTER_PLAN §15.7–§15.10) built this as a spike under `spikes/`; RENDER3D R3D-3 (2026-09-17)
## moved it here. Since R3D-END (2026-09-24/25) it is the ONLY board: the 2D `TileMapLayer` board was deleted (the last commit
## that builds it is `34881f81`) and `VoxelBoard` — the class that used to render it — holds only the state this file draws.
## It is built after a real map load. Actors, props, fog, the overlays and the HUD still draw in 2D, on top of it, until
## R3D-ACTORS / R3D-PROPS.
##
## WHAT IT READS: the `VoxelStore` (visible claims, glass state, decal state) and the registries the real load built (every
## Slice with its half thickness and material bands, every junction corner column, every floor, deep-floor and roof Slab), plus
## the light and soot cell planes `VoxelBoard` keeps. It reads, it never writes game state — and it never writes a tile
## (the R8 hook keeps it so).
##
## THE LOOK, and how it maps from the 2D lattice:
##  - voxel (grid x, level, grid y) → world (x/8, (level − ground plane)/8, y/8), so a
##    GU is one world unit and a storey one unit tall (the 30° camera's cube);
##  - only the three faces the camera can see are emitted — top (+Y), SE (+X) and
##    SW (+Z) — the same three `VoxelLightField.surface_factor()` names;
##  - a material is `base_color × facade luminance` (MULTIPLY), sampled in world space at 16 texels per voxel with
##    mirrored repeat;
##  - LIGHT AND SOOT ARE PER CELL, NOT PER VERTEX. The fragment finds its own voxel from its world position and reads
##    bucket and soot code from a `Texture2DArray` holding the cell planes, one layer per level, so faces merge by MATERIAL
##    only and a soot or light change is a layer upload instead of a remesh (a remesh for colour changes cost ~240 ms on the
##    Moto, §15.9);
##  - the terms are applied in a fixed order: face tone × bucket luminance × per-face soot × floor depth dim, all in sRGB,
##    the product decoded once (`BoardLook` owns the constants).
##
## ⚠️ NOT A PARITY CLAIM against the deleted 2D board: facade continuity is world-space (not per wall run), a true cube
## projects 19.6 px per level where the 2D sprites expect 20, and R3D-LOOK owns whatever else differs. Compare against the 2D
## board only from a worktree of `34881f81`.
extends Node3D

## RENDER3D R3D-3 step 3 — 16 vs 32, chosen by measurement on the Moto (DevFlags
## `RENDER3D_CHUNK`, read at `build()`, before any chunk math runs). 16 wins: initial
## load is a wash (collect/mesh ~1013-1056 ms either way — dominated by the store walk,
## not chunk count), but a blast's remesh — the part that stalls the main thread on the
## impact frame, before R3D-3 step 4 threads it — dropped from 108.4/104.4 ms (32) to
## 38.9/0.2 ms (16) across both PLAYGROUND grenades: a smaller chunk means less
## unaffected geometry gets re-merged alongside the cells a blast actually touched.
static var CHUNK_VOXELS: int = 16

## RENDER3D R3D-1c step 5 — the board meshes straight from the `VoxelStore` (R3D-13 deleted the `STORE_BOARD3D` switch).
## Without an active store the object path runs.
##
## One semantic difference, ratified: a cell two claims hold stays occupied while EITHER
## stands (the store's `occ`). The object path erased the cell when a destroyed claim was
## folded in, even with the other claim standing — the Director's option A (2026-09-16,
## "the voxels are the truth") for the same corner cells in the light's occupancy.
const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")

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
uniform vec4 soot_mult = vec4(0.38, 0.60, 0.76, 0.90);
uniform vec3 face_tone = vec3(1.0, 0.975, 0.945);
uniform float depth_dim[5];
varying vec3 v_world;
varying vec3 v_normal;
// R3D-7 — the cutaway, driven by the SAME set the 2D board uses (OcclusionSet): one texel per grid
// column holds (min level, max level, ring + 1). From min to max a voxel is ghosted; the levels below
// min (the wall's 2-voxel base) are untouched. A ghosted voxel dithers into discarded pixels and ghost
// diamonds, the diamonds' density being the ring's fill opacity.
uniform sampler2D occ_tex : filter_nearest, repeat_disable;
uniform int occ_on = 0;
// Roof GUs (R3D-7): the same texel, one per GU (8 x 8 columns), for a revealed roof's core. A column that has its own
// texel above (a wall, a roof's border, or their merge with a roof) wins; only a column without one asks the GU.
uniform sampler2D roof_tex : filter_nearest, repeat_disable;
uniform int roof_on = 0;
float cut_bayer(vec2 frag) {
	int bx = int(mod(frag.x, 4.0));
	int by = int(mod(frag.y, 4.0));
	float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (bayer[by * 4 + bx] + 0.5) / 16.0;
}
// 0 = keep, 1 = discard, 2 = ghost.
int cut_state(ivec3 v, vec2 frag) {
	if (occ_on == 0) {
		return 0;
	}
	ivec2 pc = ivec2(v.x, v.z) + plane_origin;
	if (pc.x < 0 || pc.y < 0 || pc.x >= plane_size || pc.y >= plane_size) {
		return 0;
	}
	vec4 t = texelFetch(occ_tex, pc, 0);
	int ring = int(floor(t.b * 255.0 + 0.5)) - 1;
	if (ring < 0) {
		if (roof_on == 0) {
			return 0;
		}
		ivec2 gc = ivec2(floor(vec2(float(v.x), float(v.z)) / 8.0)) + plane_origin / 8;
		if (gc.x < 0 || gc.y < 0 || gc.x >= plane_size / 8 || gc.y >= plane_size / 8) {
			return 0;
		}
		t = texelFetch(roof_tex, gc, 0);
		ring = int(floor(t.b * 255.0 + 0.5)) - 1;
		if (ring < 0) {
			return 0;
		}
	}
	int lvl = v.y + mesh_ground_level;
	if (lvl < int(floor(t.r * 255.0 + 0.5)) || lvl > int(floor(t.g * 255.0 + 0.5))) {
		return 0;
	}
	float fill = ring == 0 ? 0.14 : (ring == 1 ? 0.24 : 0.36);
	return fill > cut_bayer(frag) ? 2 : 1;
}
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = NORMAL;
}
void fragment() {
	// The voxel this pixel belongs to: half a voxel back along the face normal.
	ivec3 v = ivec3(floor(v_world * 8.0 - v_normal * 0.01));
	int cs = cut_state(v, FRAGCOORD.xy);
	if (cs == 1) {
		discard;
	}
	bool ghost = cs == 2; // GHOST_TOP
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
	if (ghost) {
		float tone = v_normal.y > 0.5 ? 1.0 : (v_normal.x > 0.5 ? 0.80 : 0.60);
		ALBEDO = srgb_to_linear(vec3(0.62, 0.67, 1.0) * tone * 0.85);
	}
}
"""
## R3D-6 item 3 — damage decals: the opaque face shader's lighting and soot, with the face's colour
## replaced by one layer of the decal array (COLOR.r * 255 = the layer). The quad sits 0.02 voxel off
## its face, so the voxel lookup steps back 0.06 instead of 0.01 to stay in the voxel it decorates.
const DECAL_TAIL: String = """
	vec4 d = texture(decals, vec3(UV, v_layer));
	ALBEDO = srgb_to_linear(d.rgb * f);
	ALPHA = d.a;
}
"""
static var DECAL_SHADER: String = OPAQUE_SHADER \
	.replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;") \
	.replace("varying vec3 v_normal;", "varying vec3 v_normal;\nvarying float v_layer;\nuniform sampler2DArray decals : filter_linear_mipmap, repeat_disable;") \
	.replace("	v_normal = NORMAL;", "	v_normal = NORMAL;\n	v_layer = floor(COLOR.r * 255.0 + 0.5);") \
	.replace("v_normal * 0.01", "v_normal * 0.06") \
	.replace("	bool ghost = cs == 2; // GHOST_TOP\n", "	if (cs == 2) {\n		discard;\n	}\n") \
	.replace("""	vec2 fr = mod(UV, 2.0);
	vec2 mirrored = mix(fr, 2.0 - fr, step(1.0, fr));
	float lum = has_facade > 0.5 ? texture(facade, mirrored).r : 1.0;
	ALBEDO = srgb_to_linear(base_color * lum * f);
	if (ghost) {
		float tone = v_normal.y > 0.5 ? 1.0 : (v_normal.x > 0.5 ? 0.80 : 0.60);
		ALBEDO = srgb_to_linear(vec3(0.62, 0.67, 1.0) * tone * 0.85);
	}
}
""", DECAL_TAIL)

## R3D-SPIKE-3D S1 (`LIGHT3D`, spike only) — the opaque faces lit by real 3D lights: not unshaded, and the CPU
## light bucket leaves the product (face tone, soot and depth dim stay). Set before `build()`.
static var LIT3D: bool = false
static var LIT_SHADER: String = OPAQUE_SHADER \
	.replace("render_mode unshaded, cull_disabled;", "render_mode cull_disabled, specular_disabled;") \
	.replace("float f = face_tone[face] * bucket_lum[clamp(bucket, 0, 11)];", "float f = face_tone[face];")

## One material's geometry for one chunk. The Packed arrays are MEMBERS on purpose:
## a Packed array is a value type, so `(dict["v"] as PackedVector3Array).append()`
## appends to a copy — measured on the first run: every surface came out empty and
## `add_surface_from_arrays` failed 139 times.
class SurfaceData:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	## Glass only: COLOR.r is the per-plane dim (R3D-6 item 2). Empty for every other material.
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add_quad(corners: Array[Vector3], unit: float, normal: Vector3,
			face_uvs: Array[Vector2], dim: float = -1.0) -> void:
		var base_index: int = vertices.size()
		for i: int in range(4):
			vertices.append(corners[i] * unit)
			normals.append(normal)
			uvs.append(face_uvs[i])
			if dim >= 0.0:
				colors.append(Color(dim, 1.0, 1.0, 1.0))
		for offset: int in [0, 1, 2, 0, 2, 3]:
			indices.append(base_index + offset)


var _room: Node = null
var _cell_to_world: Callable
var _camera: Camera3D = null
## RENDER3D R3D-3 step 2 — every chunk mesh (and the vscale marker) parents here, not
## directly under `self`, so `VERTICAL_SCALE` stretches only the geometry: `_camera` stays
## a direct child of `self` and is unaffected by this node's non-uniform scale.
var _geometry_root: Node3D = null
## R3D-6 item 2 — one quad per live 2D crack sprite.
const GlassCrackMirror3DClass = preload("res://godot/scripts/geometry/glass_crack_mirror3d.gd")
var _crack_mirror: Node3D = null
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
## R3D-6 item 3 — "family|material|variant" → layer of `_decal_array`; the pseudo-material that draws them.
const DECAL_MATERIAL_ID: String = "__decals__"
const DECAL_LIFT_VOXELS: float = 0.02
var _decal_layer: Dictionary = {}
var _decal_array: Texture2DArray = null
var _decal_material_index: int = -1
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
	CHUNK_VOXELS = int(str(room.call("_dev_flag", "RENDER3D_CHUNK", "16")))
	VERTICAL_SCALE = _read_vertical_scale(room)
	VSCALE_MARKER = str(room.call("_dev_flag", "RENDER3D_VSCALE_MARKER", "0")) != "0"
	_geometry_root = Node3D.new()
	_geometry_root.name = "Geometry"
	_geometry_root.scale.y = VERTICAL_SCALE
	add_child(_geometry_root)
	_store = VoxelStore.active
	var counts: Dictionary = _collect_store(_store) if _store != null else _collect()
	var t1: int = Time.get_ticks_usec()
	_read_look()
	_build_plane()
	_make_camera()
	_crack_mirror = GlassCrackMirror3DClass.new()
	_crack_mirror.name = "GlassCracks"
	_geometry_root.add_child(_crack_mirror)
	_crack_mirror.call("setup", room._voxel_board, _ground_level)
	for i: int in range(_shader_materials.size()):
		if _material_glass[i] and _shader_materials[i].shader.resource_path.ends_with("glass_pane3d.gdshader"):
			_crack_mirror.pane_materials.append(_shader_materials[i])
	var quads: int = 0
	var faces: int = 0
	for chunk: Vector2i in (_store_chunks() if _store != null else _by_chunk.keys()):
		var built: Vector2i = _build_chunk(chunk)
		faces += built.x
		quads += built.y
	if VSCALE_MARKER:
		_add_vscale_marker()
	var t2: int = Time.get_ticks_usec()
	var fields: Dictionary = {
		"voxels": int(counts.get("cells", _occ.size())), "slice_voxels": counts["slices"],
		"column_voxels": counts["columns"], "slab_voxels": counts["slabs"],
		"faces": faces, "quads": quads,
		"chunks": int(counts.get("chunks", _by_chunk.size())),
		"materials": _material_ids.size(), "collect_ms": float(t1 - t0) / 1000.0,
		"mesh_ms": float(t2 - t1) / 1000.0, "plane_levels": _level_max - _level_min + 1,
	}
	print("[BOARD3D] %d voxel(s) (slices %d, columns %d, slabs %d) → %d face(s) → %d quad(s) in %d chunk(s), %d material(s), plane levels %d..%d; collect %.0f ms, mesh %.0f ms; source %s"
		% [fields["voxels"], fields["slice_voxels"], fields["column_voxels"],
		fields["slab_voxels"], faces, quads, fields["chunks"],
		fields["materials"], _level_min, _level_max, fields["collect_ms"],
		fields["mesh_ms"],
		"store" if _store != null else "objects"])
	Telemetry.event("board3d.built", fields)
	on_occlusion(_room._occlusion_set)


## RENDER3D R3D-4b — what an actor's billboard needs from the board, and nothing else. The 2D
## world point is the same one Room hands `build()` (VISUAL_GRID_OFFSET included), so an actor's
## `global_position` lands on the ground exactly where its 2D feet do.
func ground_point(point_2d: Vector2) -> Vector3:
	var gu: Vector2 = _to_gu * (point_2d - _origin_2d)
	return Vector3(gu.x + 0.5, 0.0, gu.y + 0.5)


## RENDER3D R3D-4e-1 — the 3D point a VFX emission at `world_pos` (2D) comes from. `floor_pos` is the 2D
## point of the ground beneath it (the detonation calls carry both); the difference is the height.
func particle_origin(world_pos: Vector2, floor_pos: Vector2) -> Vector3:
	return ParticleMathRef.origin_from_floor(
		ground_point(floor_pos), floor_pos, world_pos, camera_basis(), _px_per_unit)


## RENDER3D R3D-5b — the 2D→ground map itself, for a `GroundCanvas3D` that carries thousands of vertices
## and cannot afford a method call each: ground_point(p) = (gu.x + 0.5, 0, gu.y + 0.5) with
## gu = ground_affine() * (p - ground_origin()).
func ground_affine() -> Transform2D:
	return _to_gu


## The absolute level the board's ground plane sits at (Rule 9: asked, never typed).
func ground_level() -> int:
	return _ground_level


func ground_origin() -> Vector2:
	return _origin_2d


## RENDER3D R3D-5a — PICKING. The cell under a screen position, by a camera ray against the ground plane.
## The world's ground unit IS the room's cell (`ground_point()` puts cell (i, j) at (i + 0.5, j + 0.5)), so
## the cell is `(floor(x), floor(z))` of where the ray meets y = 0: no lattice, no tilemap, and no 2D canvas
## transform in the picking path. `screen_pos` is in viewport coordinates, as an input event carries it.
## Returns `INVALID` (-9999, -9999) when the ray does not reach the plane (a camera looking away from it).
const INVALID_PICK := Vector2i(-9999, -9999)


func pick_ground(screen_pos: Vector2) -> Vector3:
	var origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-6:
		return Vector3(INF, INF, INF)
	var t: float = -origin.y / dir.y
	return origin + dir * t


func pick_cell(screen_pos: Vector2) -> Vector2i:
	var hit: Vector3 = pick_ground(screen_pos)
	if not is_finite(hit.x):
		return INVALID_PICK
	return Vector2i(floori(hit.x), floori(hit.z))


## The inverse of `pick_cell()`: where cell `cell`'s centre is on screen, in viewport coordinates.
func cell_screen_center(cell: Vector2i) -> Vector2:
	return _camera.unproject_position(Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5))


func camera_basis() -> Basis:
	return _camera.global_transform.basis


## Screen pixels per world unit at 2D zoom 1: the scale every baked actor frame was drawn at.
func px_per_unit() -> float:
	return _px_per_unit


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


## R3D-7 spike — the dither cutaway. `CUTAWAY_RADIUS` (world units, default 1.4) sizes it. VIEW, never state: it writes shader
## uniforms and nothing else.


## R3D-7 — the cutaway. The occlusion SET is the 2D board's own (`OcclusionSet`, O1: view, never state); this
## only draws it: a column texture the face shader ghosts by, and the wireframe's edges as white lines.
const OCC_BLOCK: int = 4
var _solid_top := PackedInt32Array()
var _solid_top_bw: int = 0
var _occ_image: Image = null
var _roof_image: Image = null
var _roof_texture: ImageTexture = null
var _occ_texture: ImageTexture = null
var _occ_lines: MeshInstance3D = null
var _occ_fill: MeshInstance3D = null
var _line_material: StandardMaterial3D = null


## Instrument (R3D-7 Moto): usec of the last `on_occlusion()` by phase — column texture + uniforms, outline edges,
## side fills, caps + rims, merge, segment ray march, mesh build.
## Digest of the last outline + cap geometry (identity gate for changes to how it is built).
var last_occ_digest: int = 0
## Same geometry, order-independent: every outline segment and every cap vertex (with its colour) sorted, then hashed. What
## a change that reorders the emission (a different set representation) is judged by. Both digests are only computed
## when `occ_digest_on` is set (the `occ_bench` scenario step): they cost a `hex_encode` of the arrays otherwise.
var last_occ_canon: int = 0
var occ_digest_on: bool = false
var _digest_points := PackedVector3Array()
var _digest_cap := PackedVector3Array()
var _digest_cap_colors := PackedColorArray()


## Computes `last_occ_digest` and `last_occ_canon` from the geometry of the last rebuild (bench only; see `occ_digest_on`).
func finish_occ_digests() -> void:
	var points: PackedVector3Array = _digest_points
	var cap: PackedVector3Array = _digest_cap
	last_occ_digest = hash([points.to_byte_array().hex_encode(), cap.to_byte_array().hex_encode()])
	var pieces: PackedStringArray = PackedStringArray()
	for k: int in range(0, points.size() - 1, 2):
		var a: String = str(points[k])
		var b: String = str(points[k + 1])
		pieces.append(a + "|" + b if a < b else b + "|" + a)
	pieces.sort()
	var verts: PackedStringArray = PackedStringArray()
	for k: int in range(cap.size()):
		verts.append("%s %s" % [str(cap[k]), str(_digest_cap_colors[k])])
	verts.sort()
	last_occ_canon = hash([hash(pieces), hash(verts)])
var last_occ_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0, 0])


func on_occlusion(occ_set) -> void:
	if occ_set == null or _geometry_root == null:
		return
	var oc0: int = Time.get_ticks_usec()
	var size: int = VoxelBoard.SOOT_TEX_SIZE
	if _occ_image == null:
		_occ_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		_occ_texture = ImageTexture.create_from_image(_occ_image)
	## Two textures (R3D-7): one texel per COLUMN for what needs column resolution (walls, junctions, a roof's border and
	## their merges), one texel per GU for a revealed roof's core. Built as bytes and handed over once.
	var columns: Dictionary = occ_set.get_column_entries()
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	for column: Vector2i in columns:
		var entry: Dictionary = columns[column]
		var px: Vector2i = column + VoxelBoard.SOOT_PLANE_ORIGIN
		if px.x < 0 or px.y < 0 or px.x >= size or px.y >= size:
			continue
		var at: int = (px.y * size + px.x) * 4
		bytes[at] = clampi(int(entry["min_level"]), 0, 255)
		bytes[at + 1] = clampi(int(entry["max_level"]), 0, 255)
		bytes[at + 2] = clampi(int(entry["ring"]) + 1, 1, 255)
		bytes[at + 3] = 255
	_occ_image.set_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	_occ_texture.update(_occ_image)
	var gu_size: int = size / 8
	if _roof_image == null:
		_roof_image = Image.create(gu_size, gu_size, false, Image.FORMAT_RGBA8)
		_roof_texture = ImageTexture.create_from_image(_roof_image)
	var roof_gus: Dictionary = occ_set.get_roof_gus()
	var roof_bytes := PackedByteArray()
	roof_bytes.resize(gu_size * gu_size * 4)
	var gu_origin: Vector2i = VoxelBoard.SOOT_PLANE_ORIGIN / 8
	for gu: Vector2i in roof_gus:
		var roof_entry: Dictionary = roof_gus[gu]
		var gp: Vector2i = gu + gu_origin
		if gp.x < 0 or gp.y < 0 or gp.x >= gu_size or gp.y >= gu_size:
			continue
		var gat: int = (gp.y * gu_size + gp.x) * 4
		roof_bytes[gat] = clampi(int(roof_entry["min_level"]), 0, 255)
		roof_bytes[gat + 1] = clampi(int(roof_entry["max_level"]), 0, 255)
		roof_bytes[gat + 2] = clampi(int(roof_entry["ring"]) + 1, 1, 255)
		roof_bytes[gat + 3] = 255
	_roof_image.set_data(gu_size, gu_size, false, Image.FORMAT_RGBA8, roof_bytes)
	_roof_texture.update(_roof_image)
	for i: int in range(_shader_materials.size()):
		if _material_glass[i]:
			continue
		var material: ShaderMaterial = _shader_materials[i] as ShaderMaterial
		material.set_shader_parameter("occ_tex", _occ_texture)
		material.set_shader_parameter("roof_tex", _roof_texture)
		material.set_shader_parameter("occ_on", 1 if not occ_set.is_empty() else 0)
		material.set_shader_parameter("roof_on", 1 if not roof_gus.is_empty() else 0)
	last_occ_usec[0] = Time.get_ticks_usec() - oc0
	_rebuild_occlusion_lines(occ_set)


## The occlusion volume's geometry, in one mesh with two surfaces: the wireframe as lines, and a cap on the
## base. Lines: the set's own lattice lines (already merged across walls and hidden-face culled) plus the rim
## the 2D wireframe never drew, along the bottom of the ghosted volume; a line that is not near-facing is
## dashed (the far edges and the junctions). The cap: the top of the 2-voxel base, whose faces the mesher
## hides under the ghosted voxels above, so without it the base reads hollow.
const OCC_DASH_VOXELS: float = 1.0
const OCC_FACE_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var _cap_material: StandardMaterial3D = null


func _occ_add_edge(edges: Dictionary, p: Vector3i, q: Vector3i, solid: bool) -> void:
	if p == q:
		return
	var lo: Vector3i = p
	var hi: Vector3i = q
	if q.x < p.x or (q.x == p.x and (q.y < p.y or (q.y == p.y and q.z < p.z))):
		lo = q
		hi = p
	var key: Array = [lo, hi]
	if edges.has(key):
		edges[key] = bool(edges[key]) or solid
	else:
		edges[key] = solid


## Joins collinear unit edges that touch end to start (same axis, same nearness) into runs: [start, end, solid].
## Same result and order as the original (groups in first-seen order, runs ascending along the axis). The group key
## is one integer (axis, nearness and the two fixed coordinates) and the sort is a packed-integer sort, because the
## Array keys and the `sort_custom` lambda were what cost time on the Moto.
func _occ_merge_edges(edges: Dictionary) -> Array:
	const OFFSET: int = 1024
	const SPAN: int = 4096
	var groups: Dictionary = {}  ## int group key -> [axis, solid, Array of [lo, hi]]
	for key: Array in edges:
		var lo: Vector3i = key[0]
		var hi: Vector3i = key[1]
		var d: Vector3i = hi - lo
		var axis: int = 0 if d.x != 0 else (1 if d.y != 0 else 2)
		var solid: bool = bool(edges[key])
		var fixed: Vector3i = lo
		fixed[axis] = 0
		var gk: int = ((((fixed.x + OFFSET) * SPAN + (fixed.y + OFFSET)) * SPAN + (fixed.z + OFFSET)) * 3 + axis) * 2 \
			+ (1 if solid else 0)
		if not groups.has(gk):
			groups[gk] = [axis, solid, []]
		((groups[gk] as Array)[2] as Array).append([lo, hi])
	var out: Array = []
	for gk: int in groups:
		var group: Array = groups[gk]
		var axis: int = group[0]
		var list: Array = group[2]
		var order := PackedInt64Array()
		order.resize(list.size())
		for k: int in range(list.size()):
			order[k] = (int((list[k][0] as Vector3i)[axis]) + OFFSET) * 1048576 + k
		order.sort()
		var first: Array = list[int(order[0]) & 1048575]
		var start: Vector3i = first[0]
		var end: Vector3i = first[1]
		for k: int in range(1, order.size()):
			var seg: Array = list[int(order[k]) & 1048575]
			if seg[0] == end:
				end = seg[1]
			else:
				out.append([start, end, group[1]])
				start = seg[0]
				end = seg[1]
		out.append([start, end, group[1]])
	return out


## True when a real, solid, non-ghosted voxel stands between `world` and the camera. The ray is marched through
## the store half a voxel at a time; ghosted voxels (the volume itself) and glass do not stop it.
func _occ_hidden(world: Vector3, toward: Vector3, occ_set) -> bool:
	if _store == null:
		return false
	var p := Vector3(world.x * 8.0, world.y * 8.0 + float(_ground_level), world.z * 8.0) + toward * 0.75
	## R3D-7 (Moto): this loop ran ~9 000 steps per rebuild, each through three calls into the store. The reads are
	## inlined below with the same arithmetic (`p` stays a Vector3: float32 rounding decides the floors), and a ray
	## that has been inside the store's box and left it is done, because a straight line cannot re-enter a box.
	var store: VoxelStore = _store
	var occ: PackedByteArray = store.occ
	var owner: PackedInt32Array = store.owner
	var mat: PackedByteArray = store.mat
	var x0: int = store.x0
	var y0: int = store.y0
	var l0: int = store.l0
	var w: int = store.w
	var h: int = store.h
	var x1: int = x0 + w
	var y1: int = y0 + h
	var l1: int = l0 + store.nl
	var top: int = _level_max + 1
	var step: Vector3 = toward * 0.5
	var entered: bool = false
	## Empty-space skip: above the highest solid cell of the OCC_BLOCK-wide block of columns it is in, the ray cannot hit
	## anything until it leaves the block, so it only adds `step` (the same float32 sequence) that many times. Needs the
	## ray to rise, or "above the block" would stop being true.
	var rising: bool = step.y > 0.0
	var sx: float = absf(step.x)
	var sz: float = absf(step.z)
	var bw: int = _solid_top_bw
	var i: int = 0
	while i < 160:
		i += 1
		p += step
		var level: int = floori(p.y)
		if level > top:
			return false
		var cx: int = floori(p.x)
		var cy: int = floori(p.z)
		if cx < x0 or cy < y0 or level < l0 or cx >= x1 or cy >= y1 or level >= l1:
			if entered:
				return false
			continue
		entered = true
		if rising:
			var bx: int = (cx - x0) / OCC_BLOCK
			var by: int = (cy - y0) / OCC_BLOCK
			if level > _solid_top[by * bw + bx]:
				var n: int = 160 - i
				if sx > 0.0001:
					var edge_x: float = float(x0 + (bx + 1) * OCC_BLOCK) - p.x if step.x > 0.0 else p.x - float(x0 + bx * OCC_BLOCK)
					n = mini(n, int(edge_x / sx) - 1)
				if sz > 0.0001:
					var edge_z: float = float(y0 + (by + 1) * OCC_BLOCK) - p.z if step.z > 0.0 else p.z - float(y0 + by * OCC_BLOCK)
					n = mini(n, int(edge_z / sz) - 1)
				for _k: int in range(n):
					p += step
				i += maxi(n, 0)
				continue
		var idx: int = ((level - l0) * h + (cy - y0)) * w + (cx - x0)
		if occ[idx] == 0 or _material_glass[_store_material[mat[owner[idx]]]]:
			continue
		var column := Vector2i(cx, cy)
		var entry: Variant = occ_set.entry_at(column)
		if entry != null and level >= int((entry as Dictionary)["min_level"]) and level <= int((entry as Dictionary)["max_level"]):
			continue  ## part of the ghosted volume: the ray passes through it
		return true
	return false


## One edge of the outline, cut into pieces; a piece is dropped when a real wall hides it, and a far edge (not
## `solid`) keeps only its dashes. Each piece is tested on its own, so an edge half behind a wall is half drawn.
func _occ_segment(points: PackedVector3Array, a: Vector3, b: Vector3, solid: bool, occ_set,
		toward: Vector3) -> void:
	var length: float = a.distance_to(b)
	if length <= 0.0:
		return
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var piece: float = (2.0 if solid else OCC_DASH_VOXELS) * unit
	var step: float = piece if solid else piece * 2.0
	var t: float = 0.0
	while t < length:
		var t1: float = minf(t + piece, length)
		var p0: Vector3 = a.lerp(b, t / length)
		var p1: Vector3 = a.lerp(b, t1 / length)
		if not _occ_hidden((p0 + p1) * 0.5, toward, occ_set):
			points.append(p0)
			points.append(p1)
		t += step


const OCC_CAP_TOP: Color = Color(0.36, 0.33, 0.56)


## A visible, non-glass voxel at (x, y, level) in the store.
func _solid_non_glass(x: int, y: int, level: int) -> bool:
	if _store == null or not _store.has_cell(x, y, level):
		return false
	var claim: int = _store.owner[_store.cell_index(x, y, level)]
	return not _material_glass[_store_material[_store.mat[claim]]]


## One filled side of the volume: the face of `column` toward `dir`, from level `lo` to `hi` inclusive, shaded
## by which way it faces (the same contrast the ghost diamonds use).
func _occ_side_quad(tris: PackedVector3Array, colors: PackedColorArray, column: Vector2i, dir: Vector2i,
		lo: int, hi: int, unit: float, ground: float) -> void:
	var y0: float = (float(lo) - ground) * unit
	var y1: float = (float(hi + 1) - ground) * unit
	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var p3: Vector3
	if dir.x != 0:
		var x: float = float(column.x + (1 if dir.x == 1 else 0)) * unit
		var z0: float = float(column.y) * unit
		var z1: float = float(column.y + 1) * unit
		p0 = Vector3(x, y0, z0)
		p1 = Vector3(x, y0, z1)
		p2 = Vector3(x, y1, z1)
		p3 = Vector3(x, y1, z0)
	else:
		var z: float = float(column.y + (1 if dir.y == 1 else 0)) * unit
		var x0: float = float(column.x) * unit
		var x1: float = float(column.x + 1) * unit
		p0 = Vector3(x0, y0, z)
		p1 = Vector3(x1, y0, z)
		p2 = Vector3(x1, y1, z)
		p3 = Vector3(x0, y1, z)
	var tone: float = 0.85 if dir.x == 1 else (0.70 if dir.y == 1 else 0.55)
	var colour := Color(OCC_CAP_TOP.r * tone, OCC_CAP_TOP.g * tone, OCC_CAP_TOP.b * tone)
	tris.append_array([p0, p1, p2, p0, p2, p3])
	for k: int in range(6):
		colors.append(colour)


func _rebuild_occlusion_lines(occ_set) -> void:
	for node: MeshInstance3D in [_occ_lines, _occ_fill]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_occ_lines = null
	_occ_fill = null
	var oc1: int = Time.get_ticks_usec()
	var by_level: Dictionary = occ_set.get_wireframe_lines_by_level()
	var columns: Dictionary = occ_set.get_column_entries()
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground: float = float(_ground_level)
	var toward: Vector3 = _camera.global_transform.basis.z.normalized() if _camera != null else Vector3.UP
	var points := PackedVector3Array()
	## Every unit edge of the outline, on the integer voxel lattice as (x, level, grid y). A corner is emitted once
	## per face that shares it, so equal edges merge (near-facing if any of them is); collinear neighbours are joined
	## into runs afterwards, because a dash is longer than one voxel and would otherwise never break a line.
	var edges: Dictionary = {}
	for level: int in by_level:
		for line: Dictionary in (by_level[level] as Dictionary)["lines"]:
			var a: Vector2i = line["a"]
			var b: Vector2i = line["b"]
			_occ_add_edge(edges, Vector3i(a.x, int(line["level_a"]), a.y), Vector3i(b.x, int(line["level_b"]), b.y),
				bool(line["solid"]))
	var oc2: int = Time.get_ticks_usec()
	var cap := PackedVector3Array()
	var cap_colors := PackedColorArray()
	## Which faces of the ghosted volume are painted: a side face is filled wherever the cell across it holds a
	## SOLID, non-glass voxel (a wall that carries on behind it, a frame), per level, and left transparent
	## where it holds glass or nothing. The mesher hid that neighbour's own face under the ghosted voxel.
	## The store is read inline (one index per level from the across column's base), as in `_occ_hidden`.
	var store: VoxelStore = _store
	var s_occ: PackedByteArray = store.occ
	var s_owner: PackedInt32Array = store.owner
	var s_mat: PackedByteArray = store.mat
	var s_x0: int = store.x0
	var s_y0: int = store.y0
	var s_l0: int = store.l0
	var s_w: int = store.w
	var s_h: int = store.h
	var s_l1: int = s_l0 + store.nl
	var layer: int = s_w * s_h
	## The set's own exposure, computed once per set (see `OcclusionSet.get_exposure`): bit i is OCC_FACE_DIRS[i].
	var exposure: Dictionary = occ_set.get_exposure()
	assert(OCC_FACE_DIRS == occ_set.FACE_DIRS)
	for column: Vector2i in exposure:
		var mask: int = exposure[column]
		var entry: Dictionary = occ_set.entry_at(column)
		var lo_level: int = entry["min_level"]
		var hi_level: int = entry["max_level"]
		for dir_index: int in range(4):
			if not (mask & (1 << dir_index)):
				continue
			var dir: Vector2i = OCC_FACE_DIRS[dir_index]
			var ax: int = column.x + dir.x
			var ay: int = column.y + dir.y
			if ax < s_x0 or ay < s_y0 or ax >= s_x0 + s_w or ay >= s_y0 + s_h:
				continue  ## the column across lies outside the store: nothing solid there, at any level
			var base: int = (ay - s_y0) * s_w + (ax - s_x0)
			var run_start: int = -1
			for level: int in range(lo_level, hi_level + 2):
				var solid: bool = false
				if level <= hi_level and level >= s_l0 and level < s_l1:
					var idx: int = (level - s_l0) * layer + base
					solid = s_occ[idx] != 0 and not _material_glass[_store_material[s_mat[s_owner[idx]]]]
				if solid and run_start < 0:
					run_start = level
				elif not solid and run_start >= 0:
					_occ_side_quad(cap, cap_colors, column, dir, run_start, level - 1, unit, ground)
					run_start = -1
	var oc3: int = Time.get_ticks_usec()
	for column: Vector2i in columns:
		var entry: Dictionary = columns[column]
		## Only a WALL has a base to cap: its ghosting starts 2 levels above the storey's base. A roof slab
		## starts at a storey boundary itself and has nothing solid under it.
		if posmod(int(entry["min_level"]) - _ground_level, 8) != 2:
			continue
		var y: float = (float(int(entry["min_level"])) - ground) * unit
		var x0: float = float(column.x) * unit
		var x1: float = float(column.x + 1) * unit
		var z0: float = float(column.y) * unit
		var z1: float = float(column.y + 1) * unit
		cap.append_array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
			Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)])
		for k: int in range(6):
			cap_colors.append(OCC_CAP_TOP)
		## The bottom rim of the volume, on the base's top, along each exposed side.
		var rim_mask: int = exposure.get(column, 0)
		for dir_index: int in range(4):
			if not (rim_mask & (1 << dir_index)):
				continue
			var dir: Vector2i = OCC_FACE_DIRS[dir_index]
			var p1: Vector2i
			var p2: Vector2i
			if dir.x == 1:
				p1 = Vector2i(column.x + 1, column.y)
				p2 = Vector2i(column.x + 1, column.y + 1)
			elif dir.x == -1:
				p1 = Vector2i(column.x, column.y)
				p2 = Vector2i(column.x, column.y + 1)
			elif dir.y == 1:
				p1 = Vector2i(column.x, column.y + 1)
				p2 = Vector2i(column.x + 1, column.y + 1)
			else:
				p1 = Vector2i(column.x, column.y)
				p2 = Vector2i(column.x + 1, column.y)
			var base_level: int = int(entry["min_level"])
			_occ_add_edge(edges, Vector3i(p1.x, base_level, p1.y), Vector3i(p2.x, base_level, p2.y),
				dir.x == 1 or dir.y == 1)
	var oc4: int = Time.get_ticks_usec()
	var merged: Array = _occ_merge_edges(edges)
	var oc5: int = Time.get_ticks_usec()
	for run: Array in merged:
		_occ_segment(points,
			Vector3(float(run[0].x), float(run[0].y) - ground, float(run[0].z)) * unit,
			Vector3(float(run[1].x), float(run[1].y) - ground, float(run[1].z)) * unit,
			bool(run[2]), occ_set, toward)
	var oc6: int = Time.get_ticks_usec()
	last_occ_usec[1] = oc2 - oc1
	last_occ_usec[2] = oc3 - oc2
	last_occ_usec[3] = oc4 - oc3
	last_occ_usec[4] = oc5 - oc4
	last_occ_usec[5] = oc6 - oc5
	last_occ_usec[6] = 0
	if occ_digest_on:
		## Only the arrays are kept; the digests are computed by `finish_occ_digests()`, after the step is timed.
		_digest_points = points
		_digest_cap = cap
		_digest_cap_colors = cap_colors
	if points.is_empty() and cap.is_empty():
		return
	if _line_material == null:
		_line_material = StandardMaterial3D.new()
		_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_material.albedo_color = Color(1, 1, 1)
		## The lines are their own node, drawn over everything and independent of the fill: which pieces to draw
		## (front = full, back of the volume = dashed, hidden behind a real wall = none) is decided when the
		## outline is built (`_occ_segment`), not by the depth buffer.
		_line_material.no_depth_test = true
		_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_line_material.render_priority = 127
		_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cap_material = StandardMaterial3D.new()
		_cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cap_material.vertex_color_use_as_albedo = true
		## Opaque pass, after the world (a higher `render_priority` draws later), writing depth so the ground overlays
		## (the hovered cell's outline) do not show through it.
		_cap_material.render_priority = 10
	if not cap.is_empty():
		var cap_arrays: Array = []
		cap_arrays.resize(Mesh.ARRAY_MAX)
		cap_arrays[Mesh.ARRAY_VERTEX] = cap
		cap_arrays[Mesh.ARRAY_COLOR] = cap_colors
		var fill_mesh := ArrayMesh.new()
		fill_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_arrays)
		fill_mesh.surface_set_material(0, _cap_material)
		_occ_fill = MeshInstance3D.new()
		_occ_fill.name = "OcclusionFill"
		_occ_fill.mesh = fill_mesh
		_occ_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_geometry_root.add_child(_occ_fill)
	if not points.is_empty():
		var line_arrays: Array = []
		line_arrays.resize(Mesh.ARRAY_MAX)
		line_arrays[Mesh.ARRAY_VERTEX] = points
		var line_mesh := ArrayMesh.new()
		line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
		line_mesh.surface_set_material(0, _line_material)
		_occ_lines = MeshInstance3D.new()
		_occ_lines.name = "OcclusionLines"
		_occ_lines.mesh = line_mesh
		_occ_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_geometry_root.add_child(_occ_lines)
	last_occ_usec[6] = Time.get_ticks_usec() - oc6


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


## Every damage decal on disk as one Texture2DArray (`ART_SPECIFICATIONS` §7: 256x256 RGBA, three
## variants per family per material). A family with NO file (metal has no `crack`) is legitimate and draws nothing.
##
## ⚠️ B6, LOUD (R3D-14, measured 2026-09-24): a PARTIAL family is not legitimate, and used to be silent. The 2D board's
## "missing decal asset" error lives on the baked path, which is off by default, so one of three variants gone, or a file
## that is not 256x256, or one that will not load, dropped the marks of every voxel whose hash landed on it with no message
## on either board. `check_decal.py` and `voxel_decal_selftest` catch it in the pipeline; this is the one that catches it
## on the board that ships.
func _build_decal_catalog() -> void:
	var images: Array[Image] = []
	for family: String in ["bullet", "dent", "crack"]:
		for material_id: String in VoxelBoard.IMPACT_DECAL_MATERIALS + [VoxelBoard.IMPACT_FLOOR_MATERIAL]:
			var loaded: int = 0
			for variant: int in range(VoxelBoard.IMPACT_DECAL_VARIANTS):
				var path: String = "res://ASSETS/materials/%s/decals/decal_%s_%s_%d.png" % [
					material_id, family, material_id, variant]
				if not ResourceLoader.exists(path):
					continue
				var texture: Texture2D = load(path) as Texture2D
				if texture == null:
					push_error("[Board3DLive] decal %s did not load as a texture: its marks are dropped" % path)
					continue
				var image: Image = texture.get_image()
				if image == null or image.get_size() != Vector2i(256, 256):
					push_error("[Board3DLive] decal %s is %s, not 256x256 (ART_SPECIFICATIONS §7): its marks are dropped"
						% [path, "unreadable" if image == null else str(image.get_size())])
					continue
				image.convert(Image.FORMAT_RGBA8)
				image.generate_mipmaps()
				_decal_layer["%s|%s|%d" % [family, material_id, variant]] = images.size()
				images.append(image)
				loaded += 1
			if loaded > 0 and loaded < VoxelBoard.IMPACT_DECAL_VARIANTS:
				push_error("[Board3DLive] decal family %s|%s has %d of %d variants on disk: every voxel whose hash lands on a missing one draws no mark"
					% [family, material_id, loaded, VoxelBoard.IMPACT_DECAL_VARIANTS])
	if images.is_empty() or images.size() > 255:
		_decal_layer.clear()
		return
	_decal_array = Texture2DArray.new()
	var err: int = _decal_array.create_from_images(images)
	if err != OK:
		push_error("[Board3DLive] decal Texture2DArray failed (%s) — no damage decals" % error_string(err))
		_decal_layer.clear()
		_decal_array = null


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


## The look terms, from `BoardLook` (R3D-9).
func _read_look() -> void:
	## R3D-9: `BoardLook` owns these; the 2D renderer's ground-layer ShaderMaterial is no longer asked.
	_light_ladder = BoardLook.light_ladder()
	_soot_mult = BoardLook.SOOT_FACE_MULT.duplicate()
	_tone = BoardLook.FACE_TONE.duplicate()


## One Texture2DArray layer per occupied level, filled from the 2D renderer's cell
## plane for that level (or a clean, unwritten plane when the renderer has none), and
## every opaque material pointed at it.
func _build_plane() -> void:
	var renderer: VoxelBoard = _room._voxel_board
	var images: Array[Image] = []
	for level in range(_level_min, _level_max + 1):
		images.append(_plane_image(level))
	_plane = Texture2DArray.new()
	var err: int = _plane.create_from_images(images)
	if err != OK:
		push_error("[Board3DLive] Texture2DArray.create_from_images failed (%s) — faces will read full light, no soot" % error_string(err))
	var ladder := PackedFloat32Array(_light_ladder)
	var dims := PackedFloat32Array(VoxelBoard.FLOOR_DEPTH_DIM)
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
		m.set_shader_parameter("plane_origin", VoxelBoard.SOOT_PLANE_ORIGIN)
		m.set_shader_parameter("plane_size", VoxelBoard.SOOT_TEX_SIZE)
		m.set_shader_parameter("bucket_lum", ladder)
		m.set_shader_parameter("soot_mult", Vector4(_soot_mult[0], _soot_mult[1], _soot_mult[2], _soot_mult[3]))
		m.set_shader_parameter("face_tone", Vector3(_tone[0], _tone[1], _tone[2]))
		m.set_shader_parameter("depth_dim", dims)


func _plane_image(level: int) -> Image:
	var image: Image = (_room._voxel_board as VoxelBoard).cell_plane_image(level)
	if image != null:
		return image
	var blank := Image.create(VoxelBoard.SOOT_TEX_SIZE, VoxelBoard.SOOT_TEX_SIZE,
		false, Image.FORMAT_RG8)
	blank.fill(Color8(VoxelBoard.FACE_SOOT_CODE_CLEAN, VoxelBoard.BUCKET_UNWRITTEN, 0, 255))
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


# ── detonation (DIAG-21 step 2 / 2c) ──────────────────────────────────────────

## The presenter's commit frame: the frame the 2D board shows the blast's damage.
## Folds every touched voxel's new visibility into the occupancy, rebuilds the chunks
## whose faces can have changed, and uploads the levels the commit wrote soot into.
func on_blast_commit(delta) -> void:
	_commit_touched(delta.touched_voxels + delta.reaped_voxels, "commit", false)


## A firearm round's commit (R3D-7, 2026-09-21). `AgentShotController` mutates the voxels
## and drives the 2D board's own render pass, but it never told this board: a shot on a
## wall left the 3D wall intact (holes, dents, bullet decals and scorch all absent) while the
## packed store and the 2D board agreed with each other, so no identity gate could see it. The
## same fold as a blast, on the exact set the shot wrote. Its scorch and light reach the planes
## at every level from the floor stack up to the highest voxel it touched, not only the touched
## levels: a round into a wall base sooted the floor rows beneath it.
func on_shot_commit(touched: Array) -> void:
	_commit_touched(touched, "shot", true)


## SOOT-STAMP: the levels a soot write touched (`Room._paint_soot()`: a shot's stamp, a
## re-projection of the soot map), re-uploaded. `levels` is keyed by level. `reason`
## names the log line (`tools/persistent/shot_3d_gate.py` reads "shot soot").
func sync_soot_levels(levels: Dictionary, reason: String) -> void:
	_sync_levels(levels, reason)


func _commit_touched(touched: Array, reason: String, whole_stack: bool) -> void:
	var t0: int = Time.get_ticks_usec()
	_blast_chunks = {}
	_blast_levels = {}
	for voxel: Voxel in touched:
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
	if whole_stack:
		var top_touched: int = _level_min
		for level: int in _blast_levels.keys():
			top_touched = maxi(top_touched, level)
		for level in range(_level_min, top_touched + 1):
			_blast_levels[level] = true
	else:
		## The deep floor a blast reveals sits one level down; its plane row was written too.
		for level: int in _blast_levels.keys():
			_blast_levels[level - 1] = true
	var t1: int = Time.get_ticks_usec()
	_remesh(_blast_chunks, reason, touched.size(), float(t1 - t0) / 1000.0)
	_sync_levels(_blast_levels, reason)


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
	if _decal_array == null:
		_build_decal_catalog()
	if _decal_array != null:
		_decal_material_index = _material(DECAL_MATERIAL_ID)
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
	## The highest solid non-glass cell of every OCC_BLOCK x OCC_BLOCK block of columns (by the cell's owner, the very claim
	## `_occ_hidden` reads). Only ever an upper bound after a blast: destruction removes cells, never adds one.
	_solid_top_bw = (w + OCC_BLOCK - 1) / OCC_BLOCK
	_solid_top.resize(_solid_top_bw * ((h + OCC_BLOCK - 1) / OCC_BLOCK))
	_solid_top.fill(-1)
	var s_mat: PackedByteArray = store.mat
	for ci in range(store.container_count()):
		var span: Vector2i = store.container_claims(ci)
		var kind: int = store.container_kinds[ci]
		var visible_here: int = 0
		for claim in range(span.x, span.x + span.y):
			var k: int = claim * 3
			var x: int = xyz[k]
			var y: int = xyz[k + 1]
			## `_chunk_of()`'s own division: a hard-coded `>> 5` (32) here outlived the 16-voxel
			## chunk (R3D-3 step 3), so a blast's dirty-chunk keys named the wrong chunks.
			var c: int = (floori(float(y) / float(CHUNK_VOXELS)) - _chunk_y0) * _chunk_cols \
				+ (floori(float(x) / float(CHUNK_VOXELS)) - _chunk_x0)
			chunk_of_claim[claim] = c
			_chunk_start[c + 1] += 1
			if not (state[claim] & 1):
				continue
			visible_here += 1
			var level: int = xyz[k + 2]
			if owner[((level - l0) * h + (y - y0)) * w + (x - x0)] == claim:
				cells += 1
				if not _material_glass[_store_material[s_mat[claim]]]:
					var block: int = ((y - y0) / OCC_BLOCK) * _solid_top_bw + (x - x0) / OCC_BLOCK
					if level > _solid_top[block]:
						_solid_top[block] = level
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
	var dents: Array = []  ## [dir, x, y, level, material] — faces emitted as a recess, unmerged
	var decals: Array = []  ## [dir, x, y, level, layer, on_recess] — damage marks, unmerged
	if _store != null:
		faces = _collect_chunk_faces_store(chunk, planes, dents, decals)
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
	for d: Array in decals:
		_emit_decal(int(d[0]), int(d[1]), int(d[2]), int(d[3]), int(d[4]), bool(d[5]), surfaces)
	for d: Array in dents:
		quads += _emit_dent(int(d[0]), int(d[1]), int(d[2]), int(d[3]), int(d[4]), surfaces)
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
		if surface.colors.size() == surface.vertices.size():
			arrays[Mesh.ARRAY_COLOR] = surface.colors
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
func _collect_chunk_faces_store(chunk: Vector2i, planes: Dictionary, dents: Array = [],
		decals: Array = []) -> int:
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
		## R3D-6 item 4 — a DENTED voxel's carved side is a real recess, not a flat face.
		var dent_dir: int = -1
		if not glass and ((state[claim] >> 1) & 3) == Voxel.DamageState.DENTED:
			dent_dir = DENT_DIR_OF_CARVED_SIDE.get((state[claim] >> 4) & 7, -1)
		var decal_dirs: Array = []
		var decal_layers: Array = []
		if _decal_array != null and not glass:
			var damage: int = (state[claim] >> 1) & 3
			if damage == Voxel.DamageState.CRACKED or damage == Voxel.DamageState.DENTED:
				_decal_faces(store.material_ids[mat[claim]], damage, ((state[claim] >> 3) & 1) == 1,
					(state[claim] >> 4) & 7, store.aux[claim] & 15, decal_dirs, decal_layers)
		for dir: int in range(3):
			var n: int = cell + steps[dir]
			if occ[n]:
				## Hidden by a neighbour, unless that neighbour is glass and this is not.
				if not (_material_glass[_store_material[mat[owner[n]]]] and not glass):
					continue
			var di: int = decal_dirs.find(dir)
			if di != -1:
				decals.append([dir, x, y, level, int(decal_layers[di]), dir == dent_dir])
			if dir == dent_dir:
				dents.append([dir, x, y, level, material])
				faces += 1
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


## R3D-6 item 2 — the 2D glass dims a pane's CAPS, not its main face (`GLASS_DIM_TOP` 0.60 on the
## top, `GLASS_DIM_SIDE` 0.78 on the thickness), so a pane reads as one surface with an edge.
## A face is a cap when it is at most `GLASS_CAP_VOXELS` across the direction a pane is thin in:
## the top's short side, or a side face's width. The 2D atom knows its pane; the mesher only
## knows the merged quad, so this is a size test, and a glass FLOOR (both sides large) stays main.
const GLASS_CAP_VOXELS: int = 2


func _glass_plane_dim(dir: int, w: int, h: int) -> float:
	if dir == Dir.TOP:
		return VoxelBoard.GLASS_DIM_TOP if mini(w, h) <= GLASS_CAP_VOXELS else 1.0
	return VoxelBoard.GLASS_DIM_SIDE if w <= GLASS_CAP_VOXELS else 1.0


## Voxel.CarvedSide (VIEW space, view N) → the face it carved: LEFT is the SW face, RIGHT the SE face,
## TOP the top. BOTTOM (a roof's underside) is never seen from above and keeps the flat mesh.
const DENT_DIR_OF_CARVED_SIDE: Dictionary = {
	Voxel.CarvedSide.TOP: Dir.TOP, Voxel.CarvedSide.LEFT: Dir.SW, Voxel.CarvedSide.RIGHT: Dir.SE,
}
## The recess: a frame this wide is left on the face, and the floor of the pit sits this deep.
const DENT_MARGIN: float = 0.2
const DENT_DEPTH: float = 0.3


## One DENTED voxel's carved face as geometry: four frame strips on the face plane, the recessed
## floor, and the four walls joining them. Unmerged (a merged plane cannot hold a fractional
## depth) and never on glass. Returns the quads emitted.
func _emit_dent(dir: int, x: int, y: int, level: int, material: int, surfaces: Dictionary) -> int:
	if not surfaces.has(material):
		surfaces[material] = SurfaceData.new()
	var surface: SurfaceData = surfaces[material]
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ly: float = float(level) - float(_ground_level)
	## Voxel-space origin, the face's normal, and the two tangents (u, v) of the face.
	var origin: Vector3 = Vector3(float(x), ly, float(y))
	var normal: Vector3 = DIR_NORMAL[dir]
	var tu: Vector3
	var tv: Vector3
	if dir == Dir.TOP:
		tu = Vector3(1, 0, 0)
		tv = Vector3(0, 0, 1)
	elif dir == Dir.SE:
		tu = Vector3(0, 0, 1)
		tv = Vector3(0, 1, 0)
	else:
		tu = Vector3(1, 0, 0)
		tv = Vector3(0, 1, 0)
	var face_at: Vector3 = origin + normal  ## the voxel's corner on the carved face
	var m: float = DENT_MARGIN
	var d: float = DENT_DEPTH
	var quads: int = 0
	# (u0, v0, u1, v1) rectangles on the face plane, and the pit floor.
	var frame: Array = [[0.0, 0.0, 1.0, m], [0.0, 1.0 - m, 1.0, 1.0], [0.0, m, m, 1.0 - m], [1.0 - m, m, 1.0, 1.0 - m]]
	for r: Array in frame:
		_dent_quad(surface, unit, [face_at + tu * r[0] + tv * r[1], face_at + tu * r[2] + tv * r[1],
			face_at + tu * r[2] + tv * r[3], face_at + tu * r[0] + tv * r[3]], normal)
		quads += 1
	var fl: Vector3 = face_at - normal * d
	var c00: Vector3 = fl + tu * m + tv * m
	var c10: Vector3 = fl + tu * (1.0 - m) + tv * m
	var c11: Vector3 = fl + tu * (1.0 - m) + tv * (1.0 - m)
	var c01: Vector3 = fl + tu * m + tv * (1.0 - m)
	_dent_quad(surface, unit, [c00, c10, c11, c01], normal)
	quads += 1
	# Walls: each joins a floor edge to the same edge on the face plane, facing the pit's centre.
	var up: Vector3 = normal * d
	_dent_quad(surface, unit, [c00, c10, c10 + up, c00 + up], tv)    ## the u-low... edge at v = m faces +v
	_dent_quad(surface, unit, [c01, c11, c11 + up, c01 + up], -tv)
	_dent_quad(surface, unit, [c00, c01, c01 + up, c00 + up], tu)
	_dent_quad(surface, unit, [c10, c11, c11 + up, c10 + up], -tu)
	return quads + 4


## A quad wound so its front faces `normal`, with the facade UVs of the axis it faces.
func _dent_quad(surface: SurfaceData, unit: float, corners: Array, normal: Vector3) -> void:
	var c: Array[Vector3] = []
	c.assign(corners)
	if (c[1] - c[0]).cross(c[2] - c[0]).dot(normal) < 0.0:
		c = [c[0], c[3], c[2], c[1]]
	var uvs: Array[Vector2] = []
	var ax: Vector3 = normal.abs()
	for p: Vector3 in c:
		var uv: Vector2
		if ax.y > 0.5:
			uv = Vector2(p.x, p.z)
		elif ax.x > 0.5:
			uv = Vector2(p.z, -p.y)
		else:
			uv = Vector2(p.x, -p.y)
		uvs.append(uv / FACADE_SPAN_VOXELS)
	surface.add_quad(c, unit, normal, uvs, -1.0)


## Which faces of a damaged voxel carry which decal (`VoxelBoard._decal_material()`'s table, as
## faces): a blast's CRACKED mark covers all three visible faces of a crack-capable material; a
## bullet's mark is the ONE lateral face it struck; a DENTED voxel marks its carved face. LEFT is the
## SW face and RIGHT the SE face in view N. The variant is the one chosen at damage time.
func _decal_faces(material_id: String, damage: int, blast: bool, carved: int, variant: int,
		out_dirs: Array, out_layers: Array) -> void:
	var v: int = posmod(variant, VoxelBoard.IMPACT_DECAL_VARIANTS)
	var base: String = material_id
	var carved_dir: int = int(DENT_DIR_OF_CARVED_SIDE.get(carved, -1))
	if not VoxelBoard.IMPACT_DECAL_MATERIALS.has(base):
		if damage == Voxel.DamageState.DENTED and blast and carved_dir == Dir.TOP:
			base = VoxelBoard.IMPACT_FLOOR_MATERIAL
		else:
			return
	if damage == Voxel.DamageState.CRACKED:
		if blast:
			var layer: int = int(_decal_layer.get("crack|%s|%d" % [base, v], -1))
			if layer != -1:
				for dir: int in range(3):
					out_dirs.append(dir)
					out_layers.append(layer)
		elif carved_dir == Dir.SW or carved_dir == Dir.SE:
			var bullet: int = int(_decal_layer.get("bullet|%s|%d" % [base, v], -1))
			if bullet != -1:
				out_dirs.append(carved_dir)
				out_layers.append(bullet)
	elif carved_dir != -1:
		var family: String = "dent" if blast else "bullet"
		if not blast and carved_dir == Dir.TOP:
			return
		var layer: int = int(_decal_layer.get("%s|%s|%d" % [family, base, v], -1))
		if layer != -1:
			out_dirs.append(carved_dir)
			out_layers.append(layer)


## One decal quad: over the whole face, or over the pit floor when the face is a DENTED recess.
func _emit_decal(dir: int, x: int, y: int, level: int, layer: int, on_recess: bool,
		surfaces: Dictionary) -> void:
	if _decal_material_index < 0:
		return
	if not surfaces.has(_decal_material_index):
		surfaces[_decal_material_index] = SurfaceData.new()
	var surface: SurfaceData = surfaces[_decal_material_index]
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var origin: Vector3 = Vector3(float(x), float(level) - float(_ground_level), float(y))
	var normal: Vector3 = DIR_NORMAL[dir]
	var tu: Vector3 = Vector3(0, 0, 1) if dir == Dir.SE else Vector3(1, 0, 0)
	var tv: Vector3 = Vector3(0, 0, 1) if dir == Dir.TOP else Vector3(0, 1, 0)
	var lo: float = DENT_MARGIN if on_recess else 0.0
	var hi: float = 1.0 - lo
	var depth: float = (DENT_DEPTH - DECAL_LIFT_VOXELS) if on_recess else -DECAL_LIFT_VOXELS
	var at: Vector3 = origin + normal - normal * depth
	var corners: Array[Vector3] = [at + tu * lo + tv * lo, at + tu * hi + tv * lo,
		at + tu * hi + tv * hi, at + tu * lo + tv * hi]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	if dir == Dir.TOP:
		uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) < 0.0:
		corners = [corners[0], corners[3], corners[2], corners[1]]
		uvs = [uvs[0], uvs[3], uvs[2], uvs[1]]
	surface.add_quad(corners, unit, normal, uvs, float(layer) / 255.0)


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
	surface.add_quad(corners, unit, DIR_NORMAL[dir], face_uvs,
		_glass_plane_dim(dir, w, h) if _material_glass[material] else -1.0)


# ── look ──────────────────────────────────────────────────────────────────────

func _make_material(material_id: String) -> ShaderMaterial:
	if material_id == DECAL_MATERIAL_ID:
		var decal_material := ShaderMaterial.new()
		var decal_shader := Shader.new()
		decal_shader.code = DECAL_SHADER
		decal_material.shader = decal_shader
		decal_material.set_shader_parameter("decals", _decal_array)
		return decal_material
	var shader := Shader.new()
	var shader_material := ShaderMaterial.new()
	var definition = Registries.get_material_registry().get_material(material_id)
	var colour: Color = definition.base_color if definition != null else Color(0.6, 0.6, 0.6)
	if GlassMaterials.is_glass(material_id):
		return _make_glass_material(material_id)
	shader.code = LIT_SHADER if LIT3D else OPAQUE_SHADER
	shader_material.shader = shader
	shader_material.set_shader_parameter("base_color", Vector3(colour.r, colour.g, colour.b))
	var resolved = TextureResolver.new().resolve("facade_%s" % material_id, material_id)
	if resolved != null and resolved.image != null:
		var image: Image = (resolved.image as Image).duplicate()
		image.generate_mipmaps()
		shader_material.set_shader_parameter("facade", ImageTexture.create_from_image(image))
		shader_material.set_shader_parameter("has_facade", 1.0)
	return shader_material


## R3D-6 item 2 — the 2D glass look, one pass that reads the scene behind the pane.
func _make_glass_material(material_id: String) -> ShaderMaterial:
	var tint: Color = GlassMaterials.pane_tint(material_id)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://godot/shaders/glass_pane3d.gdshader") as Shader
	shader_material.set_shader_parameter("glass_tint", Vector3(tint.r, tint.g, tint.b))
	var frost: Texture2D = load("res://ASSETS/materials/glass/facade_glass.png") as Texture2D
	if frost != null:
		shader_material.set_shader_parameter("glass_frost_tex", frost)
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
