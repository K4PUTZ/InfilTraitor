## BoardProbe — the world's voxel state, written as data another run can be compared
## against value by value.
##
## RENDER3D R3D-0 (`RENDER3D_MASTER_PLAN` §4). Every later stage of that plan moves
## voxel state, or its drawing, from one owner to another: objects to a packed store,
## tile-shaped plan entries to render-neutral ones, the 2D board to the 3D one. Each
## move is judged the same way — the world after it must be the world before it — and
## this is the instrument that says so.
##
## WHY NOT THE CELL PROBE. `INFILTRAITOR_CELL_PROBE` answers "did a voxel come back" by
## reading the TileMapLayer, which is exactly what R3D-END deletes: a gate built on it
## would die with the thing it judges. This reads the voxel containers and the cell
## planes — the simulation's own record — and never a tile.
##
## A DUMP, one record per line, text so a comparison can name what moved:
##
##   BOARDPROBE <version> <label>
##   META <key> <value>                    informational, never counted as a difference
##   M <index> <material id>               written before the first container using it
##   C <kind> <id> <n> <coords> <state>    kind = slice | column | slab
##   P <level> <w> <h> <format> <ox> <oy> <plane>
##   END voxels=<n> containers=<n> materials=<n> levels=<n>
##
## - `coords`: base64 of little-endian int32 triples (grid x, grid y, level), one per
##   voxel, in the container's own order.
## - `state`: base64 of 4 bytes per voxel —
##     0  visible (bit 0) · damage_state (bits 1-2) · damage_is_blast (bit 3) ·
##        damage_carved_side (bits 4-6)
##     1  damage_variant   2  damage_substrate   3  material index (the `M` lines)
## - An empty container writes `-` for both.
## - `plane`: base64 of the GZIP-compressed `Image.get_data()` of one level's cell plane
##   (RG8 today: R = face soot code, G = light bucket). The cell at texel (tx, ty) is
##   (tx − ox, ty − oy).
##
## VALUES, NOT HASHES. The plan names hashes grouped by container and level. A hash can
## say THAT two runs differ, never WHERE, and the whole PLAYGROUND board is a few MB of
## text — so the dump carries the values and the comparison does the grouping.
##
## `dirty` is deliberately absent: it is TIC bookkeeping, cleared within the frame.
## `face_atlas_rect` retires with the atlas. Everything else a `Voxel` holds is in.
##
## THE COMPARISON LIVES IN ONE PLACE: `tools/persistent/board_probe.py diff`. This file
## only writes.
##
## ⚠️ LOUD ON A VALUE THE FORMAT CANNOT HOLD. A `PackedByteArray` element silently wraps
## anything outside 0..255, so a variant of 256 would read back as 0 and match a voxel
## it does not match. Every packed field is range-checked, and one bad value aborts the
## write and removes the partial file.
class_name BoardProbe
extends RefCounted

const FORMAT_VERSION: int = 1
const KIND_SLICE: String = "slice"
const KIND_COLUMN: String = "column"
const KIND_SLAB: String = "slab"


## Writes one dump to `path`. `planes` is level -> Image. Returns a summary (voxels,
## containers, per-kind voxel counts, materials, levels, bytes, ms), or `{}` after a
## `push_error`, in which case no file is left behind.
static func write(path: String, label: String, edge_registry: EdgeRegistry,
		slab_registry: SlabRegistry, junction_columns: Array, planes: Dictionary,
		plane_origin: Vector2i, meta: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	if edge_registry == null or slab_registry == null:
		push_error("[BoardProbe] write: a registry is missing (edges %s, slabs %s)"
			% [edge_registry != null, slab_registry != null])
		return {}
	var file: FileAccess = _open(path, label, meta)
	if file == null:
		return {}
	var materials: Dictionary = {}
	var counts: Dictionary = {"containers": 0, KIND_SLICE: 0, KIND_COLUMN: 0, KIND_SLAB: 0}
	var error: String = ""
	for slice: Slice in edge_registry.all_slices():
		var banded: Slice = slice if slice.has_material_bands() else null
		error = _store_container(file, materials, KIND_SLICE, slice.id, slice.voxels,
			slice.material, banded, GeometryCoords.storey_level_base(slice.start_storey))
		if not error.is_empty():
			break
		_tally(counts, KIND_SLICE, slice.voxels.size())
	if error.is_empty():
		for column: JunctionResolver.JunctionColumn in junction_columns:
			var column_material: String = column.override_material \
				if column.override_material != "" else column.material
			error = _store_container(file, materials, KIND_COLUMN, column.id, column.voxels,
				column_material, null, 0)
			if not error.is_empty():
				break
			_tally(counts, KIND_COLUMN, column.voxels.size())
	if error.is_empty():
		for slab: Slab in slab_registry.all_slabs():
			error = _store_container(file, materials, KIND_SLAB, slab.id, slab.voxels,
				slab.material, null, 0)
			if not error.is_empty():
				break
			_tally(counts, KIND_SLAB, slab.voxels.size())
	return _finish(file, path, error, materials, counts, planes, plane_origin, t0)


## RENDER3D R3D-1b — the same dump, read from a `VoxelStore` instead of the objects. The
## containers are written in `write()`'s order (slices, columns, slabs), so the `M` lines
## number the materials the same way and a store that matches its objects diffs as
## IDENTICAL, down to the junction columns whose ids repeat (compared by occurrence).
static func write_store(path: String, label: String, store: VoxelStore, planes: Dictionary,
		plane_origin: Vector2i, meta: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	if store == null:
		push_error("[BoardProbe] write_store: no store")
		return {}
	var file: FileAccess = _open(path, label, meta)
	if file == null:
		return {}
	var materials: Dictionary = {}
	var counts: Dictionary = {"containers": 0, KIND_SLICE: 0, KIND_COLUMN: 0, KIND_SLAB: 0}
	var error: String = ""
	var passes: Array = [[VoxelStore.KIND_SLICE, KIND_SLICE], [VoxelStore.KIND_COLUMN, KIND_COLUMN],
		[VoxelStore.KIND_SLAB, KIND_SLAB]]
	for pass_kinds: Array in passes:
		for ci in range(store.container_count()):
			if store.container_kinds[ci] != int(pass_kinds[0]):
				continue
			var span: Vector2i = store.container_claims(ci)
			error = _store_claims(file, materials, str(pass_kinds[1]), store.container_ids[ci],
				store, span.x, span.y)
			if not error.is_empty():
				break
			_tally(counts, str(pass_kinds[1]), span.y)
		if not error.is_empty():
			break
	return _finish(file, path, error, materials, counts, planes, plane_origin, t0)


static func _open(path: String, label: String, meta: Dictionary) -> FileAccess:
	if label.is_empty() or label.contains(" "):
		push_error("[BoardProbe] write: the label must be one non-empty word, got '%s'" % label)
		return null
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[BoardProbe] write: cannot open %s (error %d)"
			% [path, FileAccess.get_open_error()])
		return null
	file.store_line("BOARDPROBE %d %s" % [FORMAT_VERSION, label])
	var meta_keys: Array = meta.keys()
	meta_keys.sort()
	for key: Variant in meta_keys:
		file.store_line("META %s %s" % [str(key), str(meta[key]).replace("\n", " ")])
	return file


static func _tally(counts: Dictionary, kind: String, voxels: int) -> void:
	counts[kind] = int(counts[kind]) + voxels
	counts["containers"] = int(counts["containers"]) + 1


## The planes and the `END` line, or the removal of a half-written file.
static func _finish(file: FileAccess, path: String, error_in: String, materials: Dictionary,
		counts: Dictionary, planes: Dictionary, plane_origin: Vector2i, t0: int) -> Dictionary:
	var error: String = error_in
	var levels: Array = planes.keys()
	levels.sort()
	if error.is_empty():
		for level: Variant in levels:
			var image: Image = planes[level]
			if image == null:
				error = "the plane of level %s is null" % [level]
				break
			var packed: PackedByteArray = image.get_data().compress(FileAccess.COMPRESSION_GZIP)
			file.store_line("P %d %d %d %d %d %d %s" % [int(level), image.get_width(),
				image.get_height(), image.get_format(), plane_origin.x, plane_origin.y,
				Marshalls.raw_to_base64(packed)])
	if not error.is_empty():
		file.close()
		DirAccess.remove_absolute(path)
		push_error("[BoardProbe] write %s: %s — no dump written" % [path, error])
		return {}
	var voxels: int = int(counts[KIND_SLICE]) + int(counts[KIND_COLUMN]) + int(counts[KIND_SLAB])
	file.store_line("END voxels=%d containers=%d materials=%d levels=%d"
		% [voxels, int(counts["containers"]), materials.size(), levels.size()])
	var bytes: int = file.get_position()
	file.close()
	return {
		"voxels": voxels, "containers": int(counts["containers"]),
		"slice_voxels": int(counts[KIND_SLICE]), "column_voxels": int(counts[KIND_COLUMN]),
		"slab_voxels": int(counts[KIND_SLAB]), "materials": materials.size(),
		"levels": levels.size(), "bytes": bytes,
		"ms": float(Time.get_ticks_usec() - t0) / 1000.0,
	}


## One `C` line from a store's claims `offset .. offset + n`.
static func _store_claims(file: FileAccess, materials: Dictionary, kind: String,
		container_id: String, store: VoxelStore, offset: int, n: int) -> String:
	if container_id.is_empty() or container_id.contains(" "):
		return "%s id '%s' is not one word" % [kind, container_id]
	if n == 0:
		file.store_line("C %s %s 0 - -" % [kind, container_id])
		return ""
	var coords: PackedInt32Array = store.xyz.slice(offset * 3, (offset + n) * 3)
	var state := PackedByteArray()
	state.resize(n * 4)
	for i in range(n):
		var claim: int = offset + i
		var material_index: int = _material_index(file, materials,
			store.material_ids[store.mat[claim]])
		if material_index < 0:
			return "more than 256 materials"
		state[i * 4] = store.state[claim]
		state[i * 4 + 1] = store.aux[claim] & 15
		state[i * 4 + 2] = store.aux[claim] >> 4
		state[i * 4 + 3] = material_index
	file.store_line("C %s %s %d %s %s" % [kind, container_id, n,
		Marshalls.raw_to_base64(coords.to_byte_array()), Marshalls.raw_to_base64(state)])
	return ""


## One `C` line. Returns "" on success, or what made the container unwritable.
## `banded` is the slice whose per-level material bands apply, or null when the
## container has one material; `band_base` is that slice's storey level base.
static func _store_container(file: FileAccess, materials: Dictionary, kind: String,
		container_id: String, voxels: Array, base_material: String, banded: Slice,
		band_base: int) -> String:
	if container_id.is_empty() or container_id.contains(" "):
		return "%s id '%s' is not one word" % [kind, container_id]
	var n: int = voxels.size()
	if n == 0:
		file.store_line("C %s %s 0 - -" % [kind, container_id])
		return ""
	var base_index: int = _material_index(file, materials, base_material)
	if base_index < 0:
		return "more than 256 materials"
	var coords := PackedInt32Array()
	coords.resize(n * 3)
	var state := PackedByteArray()
	state.resize(n * 4)
	for i in range(n):
		var voxel: Voxel = voxels[i]
		if voxel == null:
			return "%s %s voxel #%d is null" % [kind, container_id, i]
		if voxel.damage_state < 0 or voxel.damage_state > 3 \
				or voxel.damage_carved_side < 0 or voxel.damage_carved_side > 7 \
				or voxel.damage_variant < 0 or voxel.damage_variant > 255 \
				or voxel.damage_substrate < 0 or voxel.damage_substrate > 255:
			return "%s %s voxel #%d holds a value the format cannot: damage %d, carved %d, variant %d, substrate %d" \
				% [kind, container_id, i, voxel.damage_state, voxel.damage_carved_side,
				voxel.damage_variant, voxel.damage_substrate]
		var material_index: int = base_index
		if banded != null:
			material_index = _material_index(file, materials,
				banded.material_at(voxel.level - band_base))
			if material_index < 0:
				return "more than 256 materials"
		coords[i * 3] = voxel.grid_pos.x
		coords[i * 3 + 1] = voxel.grid_pos.y
		coords[i * 3 + 2] = voxel.level
		state[i * 4] = (1 if voxel.visible else 0) | (voxel.damage_state << 1) \
			| ((1 if voxel.damage_is_blast else 0) << 3) | (voxel.damage_carved_side << 4)
		state[i * 4 + 1] = voxel.damage_variant
		state[i * 4 + 2] = voxel.damage_substrate
		state[i * 4 + 3] = material_index
	file.store_line("C %s %s %d %s %s" % [kind, container_id, n,
		Marshalls.raw_to_base64(coords.to_byte_array()), Marshalls.raw_to_base64(state)])
	return ""


## The material's index in this dump, writing its `M` line the first time it is seen;
## -1 once a byte can no longer hold the index.
static func _material_index(file: FileAccess, materials: Dictionary, material_id: String) -> int:
	if materials.has(material_id):
		return materials[material_id]
	if materials.size() > 255:
		return -1
	var index: int = materials.size()
	materials[material_id] = index
	file.store_line("M %d %s" % [index, material_id])
	return index
