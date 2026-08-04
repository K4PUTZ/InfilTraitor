## D33 Part 1 — DamageCompositeCache: allocates and tracks runtime-composited
## decal atoms on a growing set of dynamic TileSetAtlasSource pages, mirroring
## how baked facade pages already work (VoxelRenderer.register_baked_atlas_page())
## rather than inventing a second placement mechanism. See
## PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 1 and §11 for why the key
## is caller-supplied and opaque here: Part 3 (not yet built) owns constructing
## a key that is stable in base space and varies by physical face, the two
## things §10's Part 0 correction established actually matter. This class only
## owns slot allocation, page growth, and the reset a room rebuild needs —
## never scene placement (Rule 8: only ever registers a TileSetAtlasSource;
## every voxel still reaches the tilemap through set_cell()).
##
## Lifetime: one instance per VoxelRenderer, reset alongside
## prune_baked_sources() — same category of per-rebuild-transient state as the
## baked pages themselves (§11: with player rotation gone, a rebuild only
## happens once per mission, so "surviving the rebuild" — §10's hardest open
## question — is no longer something this cache needs to do at all).
class_name DamageCompositeCache
extends RefCounted

const ATOM_W: int = 32
const ATOM_H: int = 36
## 2048x2048 default per the plan (§5 Part 1): 64 cols x 56 rows = 3584 slots.
## Overridable so a selftest can force page overflow without allocating
## thousands of composites.
const DEFAULT_PAGE_W: int = 2048
const DEFAULT_PAGE_H: int = 2048

var _renderer: VoxelRenderer
var _page_w: int
var _page_h: int
var _cols: int
var _rows: int
var _slots_per_page: int

var _pages: Array[Image] = []
var _source_ids: Array[int] = []
var _next_slot: int = 0
## PERF-02 A1: page indices whose Image has been blitted into since the last
## flush_dirty_pages(). store() only marks; the GPU upload happens once per
## touched page instead of once per stored atom — measured 197 uploads (~876ms)
## in one grenade blast, nearly all of them re-uploading the same 2048x2048
## page a tile at a time.
var _dirty_pages: Dictionary = {}
## String key -> {"source_id": int, "atlas_coords": Vector2i}. Key shape is the
## caller's contract (see the class doc above), not this cache's concern.
var _entries: Dictionary = {}


func _init(renderer: VoxelRenderer, page_w: int = DEFAULT_PAGE_W, page_h: int = DEFAULT_PAGE_H) -> void:
	_renderer = renderer
	_page_w = page_w
	_page_h = page_h
	_cols = page_w / ATOM_W
	_rows = page_h / ATOM_H
	_slots_per_page = _cols * _rows


func has(key: String) -> bool:
	return _entries.has(key)


## Returns {"source_id": int, "atlas_coords": Vector2i} if `key` was already
## composited this room-load, or {} if not — mirrors BakedTileLookup.resolve()'s
## shape so a future Part 3 consumer reads both the same way.
func resolve(key: String) -> Dictionary:
	return _entries.get(key, {})


## Stores `composite` (a Godot 4 Image, ATOM_W x ATOM_H, RGBA8) under `key`,
## allocating a new slot (and a new page, if the current one is full) if this
## key hasn't been composited yet this room-load. Returns the same shape as
## resolve(). Idempotent: calling twice with the same key is a cache hit and
## never re-blits or re-uploads.
##
## PERF-02 A1: the TileSetAtlasSource tile is still created here — a caller
## set_cell()s the returned coords immediately after, and an atlas source with
## no tile at those coords places nothing. Only the texture UPLOAD is deferred
## to flush_dirty_pages(); until it runs, the new tile samples the page
## texture's pre-blit contents (transparent for a never-uploaded slot), which
## is why every render path that composites must flush before the frame it
## draws in — see VoxelRenderer.flush_damage_composite_pages()'s callers.
func store(key: String, composite: Image) -> Dictionary:
	if _entries.has(key):
		return _entries[key]
	if composite.get_width() != ATOM_W or composite.get_height() != ATOM_H:
		push_error("[DamageCompositeCache] store(%s): composite is %dx%d, expected %dx%d" % [
			key, composite.get_width(), composite.get_height(), ATOM_W, ATOM_H])
		return {}

	if _pages.is_empty() or _next_slot >= _slots_per_page:
		_add_page()

	var page_idx := _pages.size() - 1
	var slot := _next_slot
	_next_slot += 1
	var atlas_coords := Vector2i(slot % _cols, slot / _cols)

	var page: Image = _pages[page_idx]
	page.blit_rect(composite, Rect2i(Vector2i.ZERO, Vector2i(ATOM_W, ATOM_H)),
		atlas_coords * Vector2i(ATOM_W, ATOM_H))

	var source_id: int = _source_ids[page_idx]
	_renderer.create_damage_composite_tile(source_id, atlas_coords)
	_dirty_pages[page_idx] = true

	var entry := {"source_id": source_id, "atlas_coords": atlas_coords}
	_entries[key] = entry
	return entry


## PERF-02 A1: uploads every page store() has blitted into since the last
## flush, exactly once each. Returns how many pages were uploaded —
## diagnostics/selftests only. A no-op when nothing was stored, which is the
## common case for the render paths that call this unconditionally.
func flush_dirty_pages() -> int:
	if _dirty_pages.is_empty():
		return 0
	var uploaded := 0
	for page_idx in _dirty_pages:
		_renderer.upload_damage_composite_page(_source_ids[page_idx], _pages[page_idx])
		uploaded += 1
	_dirty_pages.clear()
	return uploaded


## Total composites cached this room-load — diagnostics/selftests only.
func size() -> int:
	return _entries.size()


func page_count() -> int:
	return _pages.size()


## Diagnostics/selftest only — lets a caller verify what actually landed on a
## page's pixels without reaching into the private array.
func get_page_image(page_idx: int) -> Image:
	if page_idx < 0 or page_idx >= _pages.size():
		return null
	return _pages[page_idx]


func _add_page() -> void:
	var page := Image.create(_page_w, _page_h, false, Image.FORMAT_RGBA8)
	var source_id: int = _renderer.register_damage_composite_page(page)
	_pages.append(page)
	_source_ids.append(source_id)
	_next_slot = 0


## Called from VoxelRenderer.prune_baked_sources() — same event, same reason:
## a fresh build_from_layout() pass is starting and every prior pass's
## transient TileSet sources must go with it, composites included.
func reset() -> void:
	_pages.clear()
	_source_ids.clear()
	_entries.clear()
	_dirty_pages.clear()
	_next_slot = 0
