## CellPlaneStore — the render-neutral home for the per-cell soot/light planes.
##
## RENDER3D R3D-2 step 3. Moved out of `VoxelBoard` verbatim (a relocation, not a
## redesign — the API already matched what a future reader needs): one 512x512
## `Image.FORMAT_RG8` per level, R = the per-face soot code (0..215 base 6, 172 = clean; PERF-P2, widened for the charred tone 2026-09-29),
## G = the light bucket (0..11, PERF-P3; 255 = `BUCKET_UNWRITTEN`, never written).
## `VoxelBoard` is now one reader/writer of this store, same standing the 3D board
## will have — `cell_plane_image()`/`cell_plane_levels()` are already documented as
## "read-only by contract" for exactly that use (DIAG-21).
##
## See `RENDER3D_MASTER_PLAN` R3D-2: "the cell planes move to a render-neutral owner
## (name decided at build time), which both renderers read."
class_name CellPlaneStore
extends RefCounted

## PERF-P3 — the G-channel value meaning "no bucket was ever written here".
## Deliberately outside 0..LIGHT_BUCKET_COUNT-1 so it can never be mistaken for a
## real bucket; the shader clamps it to full-lit for rendering.
const BUCKET_UNWRITTEN: int = 255

## ⚠️ CELLS GO NEGATIVE — the map's BUFFER (Rule 7) puts real geometry at negative
## voxel coordinates, so the plane carries an ORIGIN: everything indexes
## `cell + plane_origin`, and the shader is passed the same offset.
## PB-6 (2026-10-09): SIZED TO THE MAP at load (`configure_for_map()`), no longer a fixed 512x512 (64 GU). An 18x36 segment with its
## ring is 224x368 voxels: the fixed plane was ~2.4x its area in memory (RGBA8 on the GPU, ~1 MiB per level) and in every light /
## soot upload (the light ramp re-sent 20 levels, ~28 ms per step on the Moto), and it capped a map at ~46 GU per side. The
## defaults are the old plane, for anything that runs before a map loads (selftests).
static var plane_origin: Vector2i = Vector2i(64, 64)
static var plane_size: Vector2i = Vector2i(512, 512)
## Voxels kept around the map on every side (debris lands past the edge; a face's lookup steps half a voxel out).
const PLANE_MARGIN: int = 16


## The plane for a map of `map_voxels` (its whole extent, the buffer ring included), origin at the map's corner minus the margin.
## Both axes rounded up to a multiple of 8, so the per-GU roof texture (`plane_size / 8`) covers it exactly.
static func configure_for_map(map_voxels: Vector2i) -> void:
	plane_origin = Vector2i(PLANE_MARGIN, PLANE_MARGIN)
	var raw: Vector2i = map_voxels + Vector2i(2 * PLANE_MARGIN, 2 * PLANE_MARGIN)
	plane_size = Vector2i(int(ceil(float(raw.x) / 8.0)) * 8, int(ceil(float(raw.y) / 8.0)) * 8)


static func _outside(p: Vector2i) -> bool:
	return p.x < 0 or p.y < 0 or p.x >= plane_size.x or p.y >= plane_size.y

## PERF-P3: FORMAT_RGB8 — R = the per-face soot code (0..215, base 6), G = the light
## bucket (0..11), B = the floor-top tone of R's ring (R3D-LOOK, derived from R in `write_soot`, never written alone). One texel per cell, one texture per level. Both writers do a
## read-modify-write so neither channel can erase the other.
## RENDER3D R3D-2 — this store is domain-agnostic (it knows nothing of "soot" or
## "light bucket" as concepts): its OWNER supplies the R-channel's clean fill value
## and the G-channel's max legal value at construction, so nothing here needs a
## reference back to `VoxelBoard` (that would be a circular class dependency —
## `VoxelBoard` already depends on this file for `BUCKET_UNWRITTEN` etc.).
var _clean_r: int
var _max_r: int      ## the largest valid soot code (CLEAN is not the largest since the charred tone, R3D-PROPS)
var _max_bucket: int
var _tone_bytes: PackedByteArray  ## B channel by soot ring (code / 36): the floor-top tone, 0..255, the shader's bilinear fetch blurs it
var _images: Dictionary = {}     ## level -> Image (FORMAT_RG8)
var _dirty: Dictionary = {}      ## level -> true, cleared by flush()
var _out_of_range_reported: bool = false


func _init(clean_r: int, max_bucket: int, max_r: int = -1, tone_bytes: PackedByteArray = PackedByteArray()) -> void:
	_tone_bytes = tone_bytes
	_clean_r = clean_r
	_max_r = max_r if max_r >= 0 else clean_r
	_max_bucket = max_bucket


## The B byte of a soot code: the tone of the floor top that code gives (255 when the owner gave no table).
func _tone_byte(code: int) -> int:
	var ring: int = code / 36
	return _tone_bytes[ring] if ring < _tone_bytes.size() else 255


func _image_for(level: int) -> Image:
	if _images.has(level):
		return _images[level]
	var img := Image.create(plane_size.x, plane_size.y, false, Image.FORMAT_RGB8)
	## R = CLEAN, not zero: zero soot is "ring 0 on all three faces", the darkest
	## scorch there is, so an unvisited cell would come up black.
	##
	## G = BUCKET_UNWRITTEN (255), a SENTINEL, not bucket 11. Filling with 11 would
	## render an unwritten cell full-lit, which is the correct PICTURE and a
	## terrible diagnostic — this project has paid twice for a fallback that folds
	## a missing value onto a legitimate one. The shader still CLAMPS 255 down to
	## 11, so the picture is unchanged — but the plane, and debug paint mode 3, can
	## now tell them apart.
	img.fill(Color8(_clean_r, BUCKET_UNWRITTEN, _tone_byte(_clean_r), 255))
	_images[level] = img
	return img


## Record one cell's soot code. Cheap and idempotent: an unchanged code does not
## dirty the level, so a repaint that only moves light uploads nothing.
func write_soot(level: int, cell: Vector2i, code: int) -> void:
	var p := cell + plane_origin
	if _outside(p):
		if not _out_of_range_reported:
			_out_of_range_reported = true
			push_error("[CellPlaneStore] PERF-P2: cell %s is outside the %dx%d soot plane — widen PLANE_MARGIN" % [cell, plane_size.x, plane_size.y])
		return
	var img := _image_for(level)
	var c: int = clampi(code, 0, _max_r)
	var was: Color = img.get_pixel(p.x, p.y)
	if was.r8 == c:
		return
	## PERF-P3: G is the light bucket and belongs to `write_bucket()` — carried
	## through unchanged rather than rewritten, so a soot pass cannot silently
	## relight a cell.
	img.set_pixel(p.x, p.y, Color8(c, was.g8, _tone_byte(c), 255))
	_dirty[level] = true


## PERF-P3 — record one cell's light bucket. The exact counterpart of
## `write_soot()`, down to the idempotence (it returns the bucket the cell held BEFORE the write, `BUCKET_UNWRITTEN` out of range - R3D-LIGHT's journal): an unchanged bucket does not dirty
## the level, so a repaint that only moves soot uploads nothing.
func write_bucket(level: int, cell: Vector2i, bucket: int) -> int:
	var p := cell + plane_origin
	if _outside(p):
		if not _out_of_range_reported:
			_out_of_range_reported = true
			push_error("[CellPlaneStore] PERF-P3: cell %s is outside the %dx%d cell plane — widen PLANE_MARGIN" % [cell, plane_size.x, plane_size.y])
		return BUCKET_UNWRITTEN
	var img := _image_for(level)
	var b: int = clampi(bucket, 0, _max_bucket)
	var was: Color = img.get_pixel(p.x, p.y)
	if was.g8 == b:
		return b
	img.set_pixel(p.x, p.y, Color8(was.r8, b, was.b8, 255))
	_dirty[level] = true
	return was.g8


## PB-6 (2026-10-09) — `write_bucket()` for a whole level at once: `cells[i]` gets `buckets[i]`, written straight into the image's
## bytes (one `get_data()` / `set_data()` instead of a `get_pixel()` / `set_pixel()` pair per cell). Same clamping and the same
## out-of-plane report; the level is dirtied when anything changed. No journal (the caller uses the per-cell path when it keeps one).
func write_buckets_level(level: int, cells: Array, buckets: PackedByteArray) -> void:
	var img := _image_for(level)
	var data: PackedByteArray = img.get_data()
	var w: int = img.get_width()
	var changed: bool = false
	for i: int in range(cells.size()):
		var p: Vector2i = (cells[i] as Vector2i) + plane_origin
		if _outside(p):
			if not _out_of_range_reported:
				_out_of_range_reported = true
				push_error("[CellPlaneStore] PERF-P3: cell %s is outside the %dx%d cell plane — widen PLANE_MARGIN" % [cells[i], plane_size.x, plane_size.y])
			continue
		var at: int = (p.y * w + p.x) * 3 + 1
		var b: int = mini(int(buckets[i]), _max_bucket)
		if data[at] != b:
			data[at] = b
			changed = true
	if changed:
		img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, data)
		_dirty[level] = true


## What the plane currently says about one cell's light bucket — the counterpart
## of `soot_at()`, and the record P3 leaves in place of the alternative id.
func bucket_at(level: int, cell: Vector2i) -> int:
	var p := cell + plane_origin
	if _outside(p):
		return BUCKET_UNWRITTEN
	if not _images.has(level):
		return BUCKET_UNWRITTEN
	return (_images[level] as Image).get_pixel(p.x, p.y).g8


## What the plane currently says about one cell's soot code. The plan builder
## needs it to decide whether a blast changes a cell's scorch at all, now that
## the answer is no longer visible in the alternative id.
func soot_at(level: int, cell: Vector2i) -> int:
	var p := cell + plane_origin
	if _outside(p):
		return _clean_r
	if not _images.has(level):
		return _clean_r
	return (_images[level] as Image).get_pixel(p.x, p.y).r8


## DIAG-21 — the RG8 cell plane image of one level (R = face soot code, G = light
## bucket), or null when the level has none. The 3D board uploads these into its
## Texture2DArray; read-only by contract.
func plane_image(level: int) -> Image:
	return _images.get(level)


## RENDER3D R3D-0 — every level that holds a cell plane, sorted. `BoardProbe` dumps
## them all; a plane is created by its writers, not by a render layer, so this set
## is not assumed to match any renderer's own level set.
func plane_levels() -> Array:
	var out: Array = _images.keys()
	out.sort()
	return out


## Forget what changed; returns how many levels were re-uploaded, always 0. The per-level `ImageTexture`s this used to
## upload were the 2D board's and nothing has read them since R3D-END (the 3D board copies the IMAGES into its own
## Texture2DArray); PERFORMANCE_BUDGET PB-6 (2026-10-08) deleted them: ~1 MiB of GPU memory per level (RGB8 is stored as
## RGBA8), ~26 MiB on PLAYGROUND. `skip_writes` is kept for the callers' signature; there is nothing left to upload.
func flush(_skip_writes: bool) -> int:
	_dirty.clear()
	return 0


## Lazily create the level's image/texture without writing any cell — the 3D board's plane array needs a real layer for every
## built level before anything has been written to it.
func ensure_level(level: int) -> void:
	_image_for(level)


## SOOT-STAMP — every level back to a fresh plane (soot clean, bucket unwritten).
## Only a MAP-WIDE light apply may follow this, because that is what writes every
## occupied cell's bucket again; the soot store is re-projected after it. It exists
## because a rotation or a map load reuses these images, and since 2026-09-22 no
## light apply writes soot, so nothing else would clear a stale view's scorch.
func reset_all() -> void:
	## PB-6: a plane sized for another map is dropped, not refilled (the next write makes one at the current size).
	for level in _images.keys():
		var img: Image = _images[level]
		if img.get_width() != plane_size.x or img.get_height() != plane_size.y:
			_images.clear()
			_dirty.clear()
			_out_of_range_reported = false
			return
	for level in _images:
		(_images[level] as Image).fill(Color8(_clean_r, BUCKET_UNWRITTEN, _tone_byte(_clean_r), 255))
		_dirty[level] = true
