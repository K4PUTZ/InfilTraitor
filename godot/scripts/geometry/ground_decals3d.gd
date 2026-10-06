## GroundDecals3D — the map's `ground_decals` section drawn on the floor (R3D-SURFACES S2).
##
## A ground decal is a GU-sized photographic mark (leaves, mud, a puddle) lying on the floor. It is ANCHORED on the voxel lattice:
## `at` = (x, y) in GU, any multiple of 1/8 GU (the board's own voxel; it was a half-GU lattice until 2026-10-06), so an integer pair is
## the shared CORNER of four GUs, `+ 0.5` the middle of an edge, and any other voxel position a place inside a GU. `rot` is free. The size
## is always one GU. It rides `FloorPile3D`, the path
## the glass-shard pile and the Tier 4 debris already use, one node set per `kind`.
##
## COSMETIC: the map declares it, nothing saves it. The one thing it must not do is outlive its floor, so a decal is dropped when any
## floor-top voxel of its footprint is gone (a crater under a leaf would show the leaf floating one voxel above it).
class_name GroundDecals3D
extends RefCounted

const ART_DIR: String = "res://ASSETS/materials/_generic/decals/"
const MAX_VARIANTS: int = 3
## Above the floor, below the soot-blended faces' own decals (debris sits at 0.022).
const LIFT: float = 0.021
const PRIORITY: int = 3

const FloorPileRef = preload("res://godot/scripts/geometry/floor_pile3d.gd")
const SurfaceRulesRef = preload("res://godot/scripts/systems/surface_rules.gd")

var _piles: Dictionary = {}      ## kind -> FloorPile3D
var _items: Dictionary = {}      ## id -> {"kind", "xmin", "xmax", "zmin", "zmax"} in voxel cells, until the floor under it breaks


## The art files that exist for a kind, in variant order (`decal_patch_<kind>_<n>.png`, n from 0, no gaps).
static func art_paths(kind: String) -> Array:
	var paths: Array = []
	for i in range(MAX_VARIANTS):
		var path: String = "%sdecal_patch_%s_%d.png" % [ART_DIR, kind, i]
		if not ResourceLoader.exists(path):
			break
		paths.append(path)
	return paths


## The variant a placement wears: the author's (`variant` >= 0) or a stable pick of its position (B4, never a RNG).
static func pick_variant(kind: String, at: Vector2, variant: int, count: int) -> int:
	if count <= 0:
		return 0
	if variant >= 0:
		return variant % count
	return FacadeSampler._fnv1a_hash("%s|%d|%d" % [kind, int(round(at.x * 8.0)), int(round(at.y * 8.0))]) % count


## `instances` are the compiler's `ground_decal_instances` (`at` already offset into the board's grid). A kind with no art on disk
## is B6-loud: the placement is skipped, never drawn blank.
## `floor_tags_of` (optional): `Callable(gu: Vector2i) -> PackedStringArray` giving the tags of the floor material of a GU raw coordinate
## (an undeclared GU answers an empty array and is not checked). A placement that `SurfaceRules` forbids on any GU its quad covers is a
## loud error and is skipped (no leaf in the desert).
func attach(board: Node3D, instances: Array, level: int, floor_tags_of: Callable = Callable()) -> void:
	detach()
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var next_id: int = 0
	for inst in instances:
		var kind: String = String(inst.get("kind", ""))
		if floor_tags_of.is_valid() and _forbidden(kind, inst["at"], floor_tags_of):
			continue
		if not _piles.has(kind):
			var paths: Array = art_paths(kind)
			if paths.is_empty():
				push_error("[GroundDecals3D] kind '%s' has no %sdecal_patch_%s_0.png: its placements draw nothing" % [kind, ART_DIR, kind])
				_piles[kind] = null
			else:
				var textures: Array = []
				for path in paths:
					textures.append(load(path) as Texture2D)
				var pile = FloorPileRef.new()
				pile.attach(board, textures, PRIORITY, LIFT, 0.5)
				_piles[kind] = pile
		var pile_for_kind = _piles[kind]
		if pile_for_kind == null:
			continue
		var at: Vector2 = inst["at"]
		var count: int = pile_for_kind._nodes.size()
		var id: int = next_id
		next_id += 1
		pile_for_kind.place(id, at, level, pick_variant(kind, at, int(inst.get("variant", -1)), count), 1.0, Color.WHITE,
				float(inst.get("rot", 0.0)))
		_items[id] = {"kind": kind,
			"xmin": int(floor((at.x - 0.5) / unit)), "xmax": int(ceil((at.x + 0.5) / unit)) - 1,
			"zmin": int(floor((at.y - 0.5) / unit)), "zmax": int(ceil((at.y + 0.5) / unit)) - 1}


## True (after a loud error) when `kind` may not lie on a floor under the 1 GU quad centred on `at`.
static func _forbidden(kind: String, at: Vector2, floor_tags_of: Callable) -> bool:
	var seen: Dictionary = {}
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		## the GU under each corner, nudged inward so a corner exactly on a GU line does not reach into the next one
		var probe: Vector2 = at + corner * 0.999
		var gu := Vector2i(int(floor(probe.x)), int(floor(probe.y)))
		if seen.has(gu):
			continue
		seen[gu] = true
		var tags: PackedStringArray = floor_tags_of.call(gu)
		if tags.is_empty():
			continue
		var reason: String = SurfaceRulesRef.reason_against(kind, tags)
		if reason != "":
			push_error("[GroundDecals3D] ground_decals at %s: %s (GU %s); skipped" % [str(at), reason, str(gu)])
			return true
	return false


func detach() -> void:
	for kind in _piles:
		if _piles[kind] != null:
			_piles[kind].detach()
	_piles.clear()
	_items.clear()


func count() -> int:
	return _items.size()


## After every committed mutation (`Room.bump_world_revision()`): `has_floor(x, z)` answers whether a floor-top voxel still stands on
## that voxel cell. A decal whose footprint lost any of them ends. (`VoxelBoard.voxel_destroyed` is NOT the seam: a blast's Delta
## reaches the board without it, measured on FLOOR_ZONES_TEST: zero notices for a crater that took 42 floor voxels.)
func refresh(has_floor: Callable) -> void:
	var gone: Array = []
	for id in _items:
		var it: Dictionary = _items[id]
		var whole: bool = true
		for x in range(int(it["xmin"]), int(it["xmax"]) + 1):
			for z in range(int(it["zmin"]), int(it["zmax"]) + 1):
				if not has_floor.call(x, z):
					whole = false
					break
			if not whole:
				break
		if not whole:
			gone.append(id)
	for id in gone:
		_piles[_items[id]["kind"]].remove(id)
		_items.erase(id)
