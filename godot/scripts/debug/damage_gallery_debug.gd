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
## WALL/FLOOR/CEILING all paint through REAL, registered containers —
## room._edge_registry's Slices for WALL (EdgeExtractor gives every
## block-to-block/block-to-floor boundary a real Slice, confirmed by probe:
## SLICE_13_3_SW etc — the map's per-material test blocks are NOT purely
## render_block()-anonymous, only their non-boundary interior voxels are),
## room._slab_registry's Slabs for FLOOR/CEILING. This matters beyond
## correctness: a throwaway, unregistered Voxel/Slice (this file's first
## version, for WALL) paints once via a direct apply_damage_voxel_swap() call
## and then gets silently overwritten by the next repaint (light/occlusion/
## FOW reveal all re-render from each container's own tracked Voxel objects)
## — nothing persists the forced damage anywhere a repaint would consult, so
## the mark visibly reverted to intact by the time of the capture. Confirmed
## real, non-reverting bullet marks exist on these same blocks (a live
## shotgun weapon_fire capture, 2026-08-08) — this now uses that exact
## register-and-repaint-safe path instead of a one-shot poke.
class_name DamageGalleryDebug

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
	var edge_registry = room._edge_registry
	if renderer == null or slab_registry == null or edge_registry == null:
		push_warning("[DAMAGE-GALLERY] _voxel_renderer/_slab_registry/_edge_registry unavailable — is a map loaded?")
		return

	print("[DAMAGE-GALLERY] === forcing DENTED/CRACKED per material (WALL/FLOOR/CEILING) ===")
	for material in MATERIAL_BLOCK_GU.keys():
		_gallery_wall(renderer, edge_registry, material, MATERIAL_BLOCK_GU[material])
		_gallery_floor(renderer, slab_registry, material, MATERIAL_FLOOR_GU[material])
		_gallery_ceiling(renderer, slab_registry, material, MATERIAL_BLOCK_GU[material])
	## ROOT CAUSE (2026-08-08): DamageCompositeCache.store() (the compositor
	## every damage-atom bake — WALL/FLOOR/CEILING alike — writes through)
	## blits its pixels into a CPU-side Image and marks the page dirty, but
	## the GPU texture upload is DEFERRED to flush_dirty_pages(); until that
	## runs, the placed tile samples "the page texture's pre-blit contents"
	## (that class's own doc comment) — not what was just composited. Real
	## gameplay never notices because process_dirty()/process_dirty_async()
	## (the TIC path every real bullet/blast goes through) always call
	## flush_damage_composite_pages() right after painting. This function
	## calls apply_damage_voxel_swap() directly instead — DamageVariantBaker's
	## own map-load bake never flushes either — so without this call every
	## mark here traced correct at the Voxel/registry/cell level (confirmed:
	## an immediate AND a late readback both showed the right source_id/
	## atlas_coords/damage_state) and still rendered as a hollow/wrong-color
	## artifact, because the texture backing that source_id was never
	## actually uploaded.
	renderer.flush_damage_composite_pages()
	print("[DAMAGE-GALLERY] === done — MISS means apply_damage_voxel_swap() found no baked atom (expected for CRACKED where MaterialResistanceTable.crack_factor == 0, e.g. metal/wood) ===")


## West GU of the material's 3-wide block row goes entirely DENTED, east GU
## entirely CRACKED, center GU stays intact — same west/center/east pattern
## _gallery_floor() uses, reusing the block row's own existing 3-GU width
## instead of needing new map geometry.
static func _gallery_wall(renderer, edge_registry: EdgeRegistry, material: String, center_gu: Vector2i) -> void:
	var dented_hit := _paint_wall_gu(renderer, edge_registry, material, center_gu + Vector2i(-1, 0),
		Voxel.DamageState.DENTED, Voxel.CarvedSide.LEFT)
	var cracked_hit := _paint_wall_gu(renderer, edge_registry, material, center_gu + Vector2i(1, 0),
		Voxel.DamageState.CRACKED, Voxel.CarvedSide.NONE)
	_report(material, "WALL", "DENTED", dented_hit)
	_report(material, "WALL", "CRACKED", cracked_hit)


## Forces every voxel of `gu`'s SOUTH-facing (Face.SW) real Slice to `state`
## — the one visible face in the default "VIEW: N" capture, and a single
## coherent surface for a half-voxel DENTED carve. A block GU sitting between
## two other solid GUs of the same material has NO edge on that shared side
## (nothing to render inside solid rock) but DOES have real edges on every
## side that borders open floor — first version of this function carved
## LEFT uniformly across all of them (west/north/south at once for the west
## GU), which reads as structurally nonsensical from three different
## surfaces simultaneously — confirmed visually: the whole block came out as
## a hollow table/skeleton instead of one dented face. Real Slice/Voxel
## objects either way, found via room._edge_registry exactly like
## find_affected_containers() does for a real blast/shot — never a
## throwaway/unregistered one, so a later repaint re-derives the SAME
## damage_state instead of silently reverting it.
static func _paint_wall_gu(renderer, edge_registry: EdgeRegistry, material: String,
		gu: Vector2i, state: int, carved_side: int) -> bool:
	var hit := false
	for edge in edge_registry.edges_touching_gu(gu):
		if edge.material != material:
			continue
		for slice in edge_registry.slices_of_edge(edge.id):
			if slice.material != material or slice.gu_cell != gu or slice.face != Face.SW:
				continue
			for voxel in slice.voxels:
				voxel.set_damage(state, true, carved_side, 0, 0)
				hit = renderer.apply_damage_voxel_swap(voxel, slice, voxel.level)
				if OS.get_environment("INFILTRAITOR_GALLERY_READBACK") == "1":
					var layer: TileMapLayer = renderer.get_layer(voxel.level)
					if layer != null:
						print("[DG-READBACK] gu=%s level=%d hit=%s src=%d atlas=%s (readback src=%d atlas=%s)" % [
							voxel.grid_pos, voxel.level, hit,
							renderer.resolve_damage_voxel_swap(voxel, slice).get("source_id", -1),
							renderer.resolve_damage_voxel_swap(voxel, slice).get("atlas_coords", Vector2i(-1,-1)),
							layer.get_cell_source_id(voxel.grid_pos), layer.get_cell_atlas_coords(voxel.grid_pos)])
	return hit


## Whole-GU coverage (2026-08-08, Director follow-up): the map's 3x3
## floor_zones patch around `center_gu` — west column entirely DENTED, east
## column entirely CRACKED, center column left INTACT as a clean reference —
## instead of alternating individual voxels. Reads "as if an explosion
## already happened" rather than a diagnostic speckle: no rings, no
## DESTROYED voxels, just the decals directly, per the Director's request.
static func _gallery_floor(renderer, slab_registry: SlabRegistry, material: String, center_gu: Vector2i) -> void:
	var dented_hit := _paint_floor_column(renderer, slab_registry, center_gu, -1,
		Voxel.DamageState.DENTED, Voxel.CarvedSide.TOP)
	var cracked_hit := _paint_floor_column(renderer, slab_registry, center_gu, 1,
		Voxel.DamageState.CRACKED, Voxel.CarvedSide.NONE)
	_report(material, "FLOOR", "DENTED", dented_hit)
	_report(material, "FLOOR", "CRACKED", cracked_hit)


## Forces every voxel of the 3 GUs at (center_gu.x + dx_col, center_gu.y-1..+1)
## to `state`, painting each immediately. Returns the last
## apply_damage_voxel_swap() result — every GU in a column shares the same
## registry key (same material/state/carved_side/substrate=0), so any one of
## them is representative of the whole column's hit/miss outcome.
static func _paint_floor_column(renderer, slab_registry: SlabRegistry, center_gu: Vector2i,
		dx_col: int, state: int, carved_side: int) -> bool:
	var hit := false
	for dy in range(-1, 2):
		var gu := center_gu + Vector2i(dx_col, dy)
		var slab: Slab = slab_registry.get_slab(Slab.make_id(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL))
		if slab == null:
			continue
		for voxel in slab.voxels:
			voxel.set_damage(state, true, carved_side, 0, 0)
			hit = renderer.apply_damage_voxel_swap(voxel, slab, GeometryCoords.FLOOR_TOP_LEVEL)
	return hit


static func _gallery_ceiling(renderer, slab_registry: SlabRegistry, material: String, gu: Vector2i) -> void:
	## OCC-FIX-03c (2026-09-01) — LEVEL-RENUMBER RESIDUE. `storeys * LEVELS_PER_STOREY`
	## was the roof level while the ground plane was 0; room_builder registers roof
	## Slabs at `storey_level_base(storeys)`, which is 80 higher since the renumber.
	## This looked for SLAB_x_y_CEILING_16 while the real one is _96, so every
	## material reported CEILING DENTED/CRACKED as MISS "no Slab" — 8 of 8, measured
	## on PLAYGROUND before the fix. A false negative from a tool whose whole job is
	## to answer "is this atom actually baked".
	var roof_level: int = GeometryCoords.storey_level_base(BLOCK_STOREYS)
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


## Late readback (2026-08-08 diagnostic): re-checks stone's west GU (the
## real Slice/Voxel this run's own DENTED paint targeted) AT CAPTURE TIME,
## not immediately after painting — an immediate readback already proved the
## correct source_id/atlas_coords land on the layer synchronously; a real
## windowed capture nonetheless showed zero pixel difference on screen. This
## distinguishes "the data reverted before capture" from "the data is still
## correct but isn't visually reflected" — call via
## INFILTRAITOR_GALLERY_READBACK=1, right before the screenshot.
static func readback_probe(room: Node) -> void:
	var renderer = room._voxel_renderer
	var edge_registry = room._edge_registry
	if renderer == null or edge_registry == null:
		return
	var west_gu: Vector2i = MATERIAL_BLOCK_GU["stone"] + Vector2i(-1, 0)
	for edge in edge_registry.edges_touching_gu(west_gu):
		if edge.material != "stone":
			continue
		for slice in edge_registry.slices_of_edge(edge.id):
			if slice.material != "stone" or slice.gu_cell != west_gu or slice.face != Face.SW:
				continue
			for voxel in slice.voxels:
				var layer: TileMapLayer = renderer.get_layer(voxel.level)
				if layer == null:
					continue
				print("[DG-LATE-READBACK] gu=%s level=%d damage_state=%d src=%d atlas=%s alt=%d" % [
					voxel.grid_pos, voxel.level, voxel.damage_state,
					layer.get_cell_source_id(voxel.grid_pos),
					layer.get_cell_atlas_coords(voxel.grid_pos),
					layer.get_cell_alternative_tile(voxel.grid_pos)])
			return


static func _report(material: String, element: String, state: String, hit: bool, extra: String = "") -> void:
	var status := "BAKED" if hit else "MISS"
	var suffix := ("  (%s)" % extra) if extra != "" else ""
	print("[DAMAGE-GALLERY] %-8s %-7s %-7s -> %s%s" % [material, element, state, status, suffix])
