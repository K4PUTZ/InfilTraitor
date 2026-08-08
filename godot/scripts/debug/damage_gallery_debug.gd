## DAMAGE-GALLERY (2026-08-07) — forces DENTED/CRACKED onto real voxels of
## every declared material, on WALL/FLOOR/CEILING, and reports whether
## VoxelRenderer.apply_damage_voxel_swap() actually hit a pre-baked atom.
##
## Built because the Post-Task-5 soot diagnosis (EXPLOSION_REBUILD_MASTER_PLAN)
## concluded the "quebradiça" floor texture comes from pre-existing dent/crack
## art, without first confirming those atoms are baked at all for every
## material — this checks that assumption directly instead of reasoning about
## it. Debug-only, triggered by F5 (see debug_tools_controller.gd), never
## called from gameplay.
##
## WALL uses the map's own PLAYGROUND.map.json per-material test blocks
## (render_block() — no real Slice, so a throwaway Slice carries just the
## material string apply_damage_voxel_swap() reads). FLOOR/CEILING use the
## real Slab objects room._slab_registry already tracks (floor needs a
## floor_zones patch per non-concrete material — added alongside this file).
class_name DamageGalleryDebug

const WALL_DENTED_LEVEL := 6
const WALL_CRACKED_LEVEL := 10
const BLOCK_STOREYS := 2

## MapCompiler shifts every `blocks`/`floor_zones` GU by +(board.buffer,
## board.buffer) before it ever reaches room_builder (map_compiler.gd:65,
## `offset := Vector2i(buffer, buffer)`) — PLAYGROUND.map.json's `board.buffer`
## is 1. The constants below are already-shifted (internal) GU, i.e. the raw
## map-file coordinate + this offset, not the raw JSON values themselves —
## using the raw JSON values here was the bug the first run of this tool caught
## (100% CEILING miss, wrong-Slab-id FLOOR miss on metal/stone/wood).
const MAP_BUFFER_OFFSET := Vector2i(1, 1)

## Center GU of each material's 3-wide wall row in maps/PLAYGROUND.map.json's
## `blocks` section (raw JSON x=2-4/7-9/12-14/17-19, all y=2), shifted by
## MAP_BUFFER_OFFSET.
const MATERIAL_BLOCK_GU := {
	"concrete": Vector2i(3, 2) + MAP_BUFFER_OFFSET,
	"metal": Vector2i(8, 2) + MAP_BUFFER_OFFSET,
	"stone": Vector2i(13, 2) + MAP_BUFFER_OFFSET,
	"wood": Vector2i(18, 2) + MAP_BUFFER_OFFSET,
}

## Center GU of each material's floor patch (raw JSON coordinates), shifted
## by MAP_BUFFER_OFFSET. Concrete reuses the map's existing all-concrete base
## floor_zones entry; metal/stone/wood are new 3x3 patches added south of
## their wall block (same map file).
const MATERIAL_FLOOR_GU := {
	"concrete": Vector2i(3, 5) + MAP_BUFFER_OFFSET,
	"metal": Vector2i(8, 5) + MAP_BUFFER_OFFSET,
	"stone": Vector2i(13, 5) + MAP_BUFFER_OFFSET,
	"wood": Vector2i(18, 5) + MAP_BUFFER_OFFSET,
}


static func run(room: Node) -> void:
	var renderer = room._voxel_renderer
	var slab_registry = room._slab_registry
	if renderer == null or slab_registry == null:
		push_warning("[DAMAGE-GALLERY] _voxel_renderer/_slab_registry unavailable — is a map loaded?")
		return

	print("[DAMAGE-GALLERY] === forcing DENTED/CRACKED per material (WALL/FLOOR/CEILING) ===")
	for material in MATERIAL_BLOCK_GU.keys():
		_gallery_wall(renderer, material, MATERIAL_BLOCK_GU[material])
		_gallery_floor(renderer, slab_registry, material, MATERIAL_FLOOR_GU[material])
		_gallery_ceiling(renderer, slab_registry, material, MATERIAL_BLOCK_GU[material])
	print("[DAMAGE-GALLERY] === done — MISS means apply_damage_voxel_swap() found no baked atom (expected for CRACKED where MaterialResistanceTable.crack_factor == 0, e.g. metal/wood) ===")


## No real Slice backs these voxels (render_block() paints them flat) — a
## throwaway Slice supplies only the .material field resolve_damage_voxel_swap()
## reads for the WALL branch, and doubles as the Voxel's dirty-propagation parent.
static func _gallery_wall(renderer, material: String, gu: Vector2i) -> void:
	var fake_slice := Slice.new("GALLERY_WALL_%s" % material, gu, Face.SW, "",
		BLOCK_STOREYS * GeometryCoords.LEVELS_PER_STOREY, material)
	var dented_hit := false
	var cracked_hit := false
	var first := true
	for voxel_pos in GeometryCoords.gu_voxels(gu):
		var dented := Voxel.new(voxel_pos, WALL_DENTED_LEVEL, fake_slice)
		dented.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 0, 0)
		var d_hit: bool = renderer.apply_damage_voxel_swap(dented, fake_slice, WALL_DENTED_LEVEL)
		var cracked := Voxel.new(voxel_pos, WALL_CRACKED_LEVEL, fake_slice)
		cracked.set_damage(Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0, 0)
		var c_hit: bool = renderer.apply_damage_voxel_swap(cracked, fake_slice, WALL_CRACKED_LEVEL)
		if first:
			dented_hit = d_hit
			cracked_hit = c_hit
			first = false
	_report(material, "WALL", "DENTED", dented_hit)
	_report(material, "WALL", "CRACKED", cracked_hit)


static func _gallery_floor(renderer, slab_registry: SlabRegistry, material: String, gu: Vector2i) -> void:
	var slab_id := Slab.make_id(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL)
	var slab: Slab = slab_registry.get_slab(slab_id)
	if slab == null:
		_report(material, "FLOOR", "DENTED", false, "no Slab %s — floor_zones patch missing?" % slab_id)
		_report(material, "FLOOR", "CRACKED", false, "no Slab %s — floor_zones patch missing?" % slab_id)
		return
	var dented_hit := false
	var cracked_hit := false
	for i in range(slab.voxels.size()):
		var voxel: Voxel = slab.voxels[i]
		if i % 2 == 0:
			voxel.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0, 0)
			var hit: bool = renderer.apply_damage_voxel_swap(voxel, slab, GeometryCoords.FLOOR_TOP_LEVEL)
			if i == 0:
				dented_hit = hit
		else:
			voxel.set_damage(Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0, 0)
			var hit2: bool = renderer.apply_damage_voxel_swap(voxel, slab, GeometryCoords.FLOOR_TOP_LEVEL)
			if i == 1:
				cracked_hit = hit2
	_report(material, "FLOOR", "DENTED", dented_hit)
	_report(material, "FLOOR", "CRACKED", cracked_hit)


static func _gallery_ceiling(renderer, slab_registry: SlabRegistry, material: String, gu: Vector2i) -> void:
	var roof_level: int = BLOCK_STOREYS * GeometryCoords.LEVELS_PER_STOREY
	var slab_id := Slab.make_id(gu, Slab.Role.CEILING, roof_level)
	var slab: Slab = slab_registry.get_slab(slab_id)
	if slab == null:
		_report(material, "CEILING", "DENTED", false, "no Slab %s" % slab_id)
		_report(material, "CEILING", "CRACKED", false, "no Slab %s" % slab_id)
		return
	var dented_hit := false
	var cracked_hit := false
	for i in range(slab.voxels.size()):
		var voxel: Voxel = slab.voxels[i]
		if i % 2 == 0:
			voxel.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM, 0, 0)
			var hit: bool = renderer.apply_damage_voxel_swap(voxel, slab, roof_level)
			if i == 0:
				dented_hit = hit
		else:
			voxel.set_damage(Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0, 0)
			var hit2: bool = renderer.apply_damage_voxel_swap(voxel, slab, roof_level)
			if i == 1:
				cracked_hit = hit2
	_report(material, "CEILING", "DENTED", dented_hit)
	_report(material, "CEILING", "CRACKED", cracked_hit)


static func _report(material: String, element: String, state: String, hit: bool, extra: String = "") -> void:
	var status := "BAKED" if hit else "MISS"
	var suffix := ("  (%s)" % extra) if extra != "" else ""
	print("[DAMAGE-GALLERY] %-8s %-7s %-7s -> %s%s" % [material, element, state, status, suffix])
