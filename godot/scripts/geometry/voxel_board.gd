## Geometry Module — VoxelBoard: the state of the voxel board that the 3D board (`Board3DLive`) draws.
##
## It renders nothing. Its levels are a registry (`level_origin()`, `level_z_index()`, `voxel_world_position()`), it owns the light
## and soot cell planes and their application, it turns dirty voxels into `voxel_destroyed`, and it keeps the glass crack / rim /
## shard-pile records the 3D board mirrors. Until R3D-END (2026-09-25) it was `VoxelRenderer`, a `TileMapLayer` renderer; this rename
## came after the 2D board was deleted (END-0 to END-6) and changed no behaviour.
## Extends Node2D so the 2D overlays that still parent to it keep working.
extends Node2D
class_name VoxelBoard

## DESTRUCTION_MASTER_PLAN D15: emitted at the TIC, alongside the dirty pass,
## whenever a voxel is actually erased (destroyed). VFX/audio subscribe here
## instead of the destruction system knowing about them — with no subscriber
## this costs nothing. Never implemented until Part 3; added now.
signal voxel_destroyed(grid_pos: Vector2i, level: int, material_id: String)

var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")
## G4-3 — preloaded rather than used by `class_name`: this file is parsed
## before the global class cache exists in a headless lint run.
const GlassShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const GlassOpening = preload("res://godot/scripts/systems/destruction/glass_opening.gd")

## D32 — the four wall materials the Director authors decals for. Glass is
## absent by D22 (DESTROYED-only) and brick is deferred; both were the
## Director's explicit call on 2026-08-02 ("vidro e tijolo deixa pra depois").
## M2c (2026-08-21): `brick` joins, its nine decals delivered and measured. The
## comment this replaced said "glass and brick deferred" — glass still is, and by
## a different rule: D22 gives it no marked tier at all, so it is not waiting on
## art (MATERIALS_MASTER_PLAN M4b).
const IMPACT_DECAL_MATERIALS: Array[String] = ["concrete", "metal", "stone", "wood", "brick"]
## Fixed at three by the Director, same session. Must match `variant_count` in
## voxels/manifest.json — asserted by voxel_decal_selftest.gd rather than
## trusted, because a mismatch drops marks silently.
const IMPACT_DECAL_VARIANTS: int = 3
## D3/§3.3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06) — how many substrate crops the damage model offers per (material, damage
## name) (the 2D atom bake's axis; `BlastCalculator` still rolls it). Independent of IMPACT_DECAL_VARIANTS on purpose: a
## decal-art axis and a substrate-crop axis have no reason to share a count, they just both happen to be 3 today.
const DAMAGE_SUBSTRATE_VARIANTS: int = 3
## Every ground material's dent routes to this one shared asset (D26), so the
## floor family is built on "earth" and needs only the blast/dent/top corner of
## the matrix: floors take no bullets (D32.4) and have no crack tier.
const IMPACT_FLOOR_MATERIAL: String = "earth"
## D32.6 (Director, 2026-08-02): "metal e madeira não ficam rachados, só dented
## ou balas." Only these two fracture, so only these two get a blast-CRACKED
## decal — MaterialResistanceTable holds the matching crack_factor 0.0 for metal
## and wood, and voxel_decal_selftest asserts the two agree. Bullets are NOT
## gated by this: a firearm's CRACKED tier is a bullet mark on the struck face,
## which every material gets.
## D32.6 — only rigid MINERAL materials fracture; metal and wood dent instead.
## Brick is one (crack_factor 0.12), so it cracks like concrete and stone.
const IMPACT_CRACK_MATERIALS: Array[String] = ["concrete", "stone", "brick"]

## FLOOR-DEPTH-02: one tone step per level below the ground plane (index = depth - 1; the walkable top face is 1.0). Read by
## `Board3DLive`; ramp chosen by measurement on a real detonation (2026-07-28), deeper entries are for the map's outer lateral cut.
const FLOOR_DEPTH_DIM: Array[float] = [1.0, 0.70, 0.45, 0.34, 0.28]

## Light buckets, dark to full-lit. The ladder itself is `BoardLook`'s; the cell planes and the light field are built for this
## many. (R3D-END END-4: the alternative-tile mechanism that used to carry the bucket, and the debug knobs that A/B'd it, went.)
const LIGHT_BUCKET_COUNT: int = 12

## The soot code of an untouched face (base-5 top*25 + se*5 + sw, 4 = clean per face) and the size of the code space.
const FACE_SOOT_CODE_CLEAN: int = 124
const FACE_SOOT_CODE_COUNT: int = 125

## ABLATION — `INFILTRAITOR_NO_LIGHT=1` REMOVES THE LIGHT SYSTEM FROM THE RUN.
##
## Director, 2026-08-26: *"eu queria testar desligando essas duas features por
## default ... e rodando o game só com materiais básicos e voxels, sem
## iluminação"*. A DISCRIMINATOR, not a feature, and not a look mode. It removes the work:
##
##   · `Room._repaint_voxel_light_buckets()` and its scoped sibling return at the
##     top, so `build_occupancy()` and `VoxelLightField.build()` never run;
##   · all three `apply_light_field*()` entries return, so the walk over every
##     placed cell — 609 ms of the 646 ms measured in §10.1 — never happens;
##
## The board is WRONG on purpose. Nothing about this is shippable and no gate,
## census or pixel diff taken under it means anything about the real build.
static var LIGHT_DISABLED: bool = OS.get_environment("INFILTRAITOR_NO_LIGHT") == "1"


## RENDER3D R3D-3 step 5 — the opaque tile is never placed, so `_process_dirty_slice_voxel()`/`_process_dirty_slab_voxel()`'s erase
## branch has no `get_cell_source_id() != -1` to ask "was this erasure already
## told to `voxel_destroyed` listeners" (the 2026-08-19 double-VFX bug the tile
## check itself guards against — see its own note beside `already_gone`). This is
## that same question's answer when there is no tile: Vector3i(x, y, level) -> true
## once told. Cleared by `clear()`, the same point the tile-backed state resets.
var _render3d_gone_cells: Dictionary = {}
## R3D-14 — the same question for GLASS under the store's glass state: told to `voxel_destroyed` listeners once. Kept apart from
## the opaque set because a cell two claims hold (a glass pane meeting a wall at a corner) is two destructions, not one.
var _render3d_gone_glass: Dictionary = {}
## R3D-14 — pane cells an opening (or a remnant) has already been applied to, under the store's glass state: Vector3i -> true.
## What "already a shard" meant when the layer held the atom, without the atom: a hole never heals, so a shaped cell is never
## recomputed. Cleared with the shard registry (`clear_glass_rim_cells()`, a fresh board).
var _glass_shaped_cells: Dictionary = {}

## Z-index base for wall layers (from room.gd context)
var _wall_base_z_index: int = 10

## LEVEL-RENUMBER stage A — ONE store, keyed by level, sparse.
##
## This replaces `_voxel_layers` (an Array of positive levels) and
## `_negative_voxel_layers` (a Dictionary of negative ones). D17's note explained
## the split honestly: *"GDScript's `array[-1]` means 'last element', not 'grow
## downward', so unifying storage would mean every one of _voxel_layers' many
## existing 0-indexed callers would need to learn to ignore negative keys."*
##
## That reasoning was right, and the Director's renumber is what retires it —
## with no level below zero there is nothing for an index to collide with. Stage A
## unifies the store while the numbering is UNCHANGED, so the census can prove the
## refactor alone changes nothing; stage B then moves the numbers.
##
## What the split cost was not correctness but repetition: every map-wide walk in
## this file and in `room.gd` came in pairs, one loop for each store, and a walk
## that forgot its second half was a silent bug with no symptom until someone
## looked at the right voxel.
var _layers: Dictionary = {}               ## level:int -> true, sparse: the levels something has built

## GLASS — R3D-END (END-2): the glass tile layers, their backbuffer and composite z, the pane atoms and their inverse
## (`_glass_atom_source`, `_glass_source_info`), the shard rim atoms, the sliver dims and the sublayer shader knobs were
## the 2D board's. The glass STATE is the store's (R3D-14); what is left here is the rim batch, the claimed openings
## and the shaped-cell record the 3D board reads.
## Dimness of a glass voxel's top and side faces against its main face — a LOOK calibration the Director iterates on
## (env-overridable, `static var`). The 3D board's pane shader reads them (`Board3DLive`); the 2D atoms that first
## carried them are gone (R3D-END END-2).
static var GLASS_DIM_TOP: float = float(OS.get_environment("INFILTRAITOR_GLASS_DIM_TOP")) \
	if OS.get_environment("INFILTRAITOR_GLASS_DIM_TOP") != "" else 0.60
static var GLASS_DIM_SIDE: float = float(OS.get_environment("INFILTRAITOR_GLASS_DIM_SIDE")) \
	if OS.get_environment("INFILTRAITOR_GLASS_DIM_SIDE") != "" else 0.78
## Glass cells erased since the last rim refresh, level -> Array[Vector2i].
var _glass_rim_dirty: Dictionary = {}
## CRACK-04 — region anchor -> the opening claimed for it, consumed by the next
## `refresh_glass_rims()`. Empty is the normal case for the cook.
var _glass_region_openings: Dictionary = {}
## CRACK-04 — opening id -> { texture, origin, size } for the SHEET's void.
## Rasterised once per opening and shared by every crack that uses it: there are
## twelve of them and a map can have hundreds of holes.
var _glass_opening_masks: Dictionary = {}

## LEVEL-RENUMBER — the ground plane: the lowest level that counts as WALL rather
## than floor/bedrock. Stage A keeps it at 0 so the numbering is untouched; stage B
## moves it to GeometryCoords.PLAYABLE_LEVEL and every level with it. Every
## "is this a wall level" test in this file goes through here, so stage B is one
## constant rather than a sweep of sign checks.
var _ground_plane_level: int = GeometryCoords.PLAYABLE_LEVEL


## True when something has built this level (the level registry: `_layers` holds no node any more, R3D-END END-6).
func has_level(level: int) -> bool:
	return _layers.has(level)


## Every built level, ascending. The single replacement for the paired
## positive-then-negative walks this file used to be full of.
func level_keys() -> Array:
	var out: Array = _layers.keys()
	out.sort()
	return out


## Built levels at or above the ground plane — walls, blocks, props. D18's lazy
## reveal means floor levels are sparse, so this is not "the rest of the array".
func wall_level_keys() -> Array:
	var out: Array = []
	for level in level_keys():
		if level >= _ground_plane_level:
			out.append(level)
	return out


func ground_plane_level() -> int:
	return _ground_plane_level


## LEVEL-RENUMBER — A RENDER LEVEL IS NOT A FACADE SHEET ROW, and conflating them is what the renumber exposed.
##
## The absolute level minus the ground plane: 0 is the wall base, negative is the floor stack. Everything addressed from
## the ground rather than from the absolute number goes through it: `level_origin()` and `level_z_index()`, the facade sheet
## row a 3D face samples, and every level-keyed HASH — invariant **B4 pins them**: the earth variant
## (`EarthVariantSelector.variant_for`) multiplies the level into an FNV-style mix, so feeding it an absolute level would
## silently repaint the ground with different variants (measured on the 2D board: **52 224 floor cells changed source id**
## before this was applied). The 2D board's bake sheet (`BakedTileLookup`, deleted) had the same property: with the ground plane
## at 80 it read level 80 as sheet row 16 and **2 112 cells vanished with no warning**, because a resolve that finds nothing
## places nothing. Never a literal (rule 9).
func relative_level(level: int) -> int:
	return level - _ground_plane_level


## The highest built WALL level, as a level number — not a count. Overhead lamps
## anchor to it (VoxelLightField.build()), so it has to be the real level.
func top_wall_level() -> int:
	var walls: Array = wall_level_keys()
	return walls[walls.size() - 1] if not walls.is_empty() else _ground_plane_level

## Runtime TileSet

## Visual grid offset (isometric screen space)
var _visual_grid_offset: Vector2

## DEBUG-02: Accumulated nudge offset (pixels). Applied to all layers for real-time measurement.
var debug_nudge: Vector2 = Vector2.ZERO

## BAKE-DIAG-01: placement counters, reset at the top of each register_geometry() call
var _diag_total_cells: int = 0
## Cells (a slice voxel, a junction column, a slab GU) this pass walked but did NOT write, because
## the 3D board draws them from the store. `_assert_geometry_registered()` needs them: under a 3D board
## `_diag_total_cells` is 0 for a map whose walls are all opaque, and that is not a broken render path.
var _diag_skipped_cells: int = 0
var _diag_slice_count: int = 0



## Setup: the visual offset and the wall base z-index, which the level registry's origins and draw heights derive from
func setup(visual_grid_offset: Vector2, wall_base_z_index: int = 10) -> void:
	_visual_grid_offset = visual_grid_offset
	_wall_base_z_index = wall_base_z_index
	## The parent must be Y-sorted for sibling layers' tiles to merge into one
	## order — per-layer `y_sort_enabled` alone still draws all of one, then all
	## of the other (Q1's control).
	MemStage.mark("10 voxel TileSet built")




## VL-D4 — screen/world anchor of one voxel cell (its N-vertex), for overlays and VFX that need to draw AT a specific voxel
## (e.g. EmberOverlay's glow) without re-deriving the layer-position formula themselves. Analytic, no empirical offset
## (project rule): `level_origin(level) + voxel_cell_local(cell)`, proved equal to the deleted TileMapLayer's own
## `position + map_to_local()` before it went. Good enough for a soft glow blob, which needs "roughly at this voxel", not
## pixel-exact face-centre alignment. Returns Vector2.ZERO if the level was never built (the caller's cell couldn't be there).
func voxel_world_position(grid_pos: Vector2i, level: int) -> Vector2:
	if not _layers.has(level):
		return Vector2.ZERO
	return level_origin(level) + voxel_cell_local(grid_pos)


## R3D-END END-6 — what the level's TileMapLayer used to carry, as arithmetic (proved equal to the layer's
## `position + map_to_local()` on 1 800 cells over six levels with a nonzero offset, before the layers were deleted).
## The screen origin of a level: the room's visual offset, the tile-lattice compensation `TILE_OFFSET` (Transform Canon
## (SLICE-00): (floor half-width - voxel half-width, floor half-height) = (112, 64); do not "restore symmetry" to 56), the debug nudge,
## and one voxel step of height per level above the ground plane (relative: absolute levels would draw eighty steps too high).
func level_origin(level: int) -> Vector2:
	const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)
	return Vector2(
		_visual_grid_offset.x + TILE_OFFSET.x + debug_nudge.x,
		_visual_grid_offset.y + TILE_OFFSET.y + debug_nudge.y - GeometryCoords.VOXEL_STEP_PX * float(relative_level(level)))


## Where a voxel cell's N-vertex sits inside its level (32x16 iso diamonds, DIAMOND_DOWN) — the `TileMapLayer.map_to_local()`
## of the layer this replaced.
static func voxel_cell_local(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x - cell.y) * 16.0 + 16.0, float(cell.x + cell.y) * 8.0 + 8.0)


## The draw height (`z_index`) of a level: walls stack above the wall base; the floor levels below the ground plane take the
## LEGACY FLOOR SLOT (level + 1 puts the walkable top face at 0 and bedrock at -7..-1), so the floor-painted overlays draw ON
## the floor and UNDER the walls.
func level_z_index(level: int) -> int:
	var rel: int = level - _ground_plane_level
	return (_wall_base_z_index + rel) if rel >= 0 else (rel + 1)


## OCC-03: Get the highest z_index across all voxel layers (used to render agent above all geometry).
## Returns: z_index of the topmost voxel layer, or WALL_BASE_Z_INDEX if no layers yet.
func get_max_voxel_z_index() -> int:
	var walls: Array = wall_level_keys()
	if walls.is_empty():
		return _wall_base_z_index
	# Each layer has z_index = _wall_base_z_index + (level - ground plane)
	return _wall_base_z_index + (top_wall_level() - _ground_plane_level)


## Placed plus deliberately skipped: how many cells the last register_geometry() walked. What the "did the render path run at
## all" check asks (see `_diag_skipped_cells`).
func get_walked_cell_count() -> int:
	return _diag_total_cells + _diag_skipped_cells


func memory_census(label: String) -> void:
	var tex_used: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var buf_used: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	var vid_used: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)

	var mb: float = 1024.0 * 1024.0
	print("[MEM-CENSUS] === %s ===" % label)
	## ⚠️ MEASURED 2026-09-12: all three of these read 0.0 MB under the desktop
	## Forward+ renderer, where the atlas above is provably 163.8 MB. A zero here
	## is the INSTRUMENT, not the machine — do not quote it as evidence of
	## anything, and check whether it populates under the renderer actually in
	## use before trusting a non-zero one either.
	print("[MEM-CENSUS]   engine texture mem: %.1f MB · buffers %.1f MB · video total %.1f MB%s"
		% [float(tex_used) / mb, float(buf_used) / mb, float(vid_used) / mb,
		"   ⚠️ ALL ZERO — instrument unavailable on this renderer"
			if tex_used == 0 and buf_used == 0 and vid_used == 0 else ""])
	print("[MEM-CENSUS]   layers: %d" % _layers.size())
	print("[MEM-CENSUS]   script static memory: %.1f MB"
		% [float(OS.get_static_memory_usage()) / mb])


## DEBUG-02: Apply real-time positional offset to all voxel layers.
## Accumulates nudges and shifts existing layers; new layers inherit the offset.
func apply_debug_nudge(delta: Vector2) -> void:
	debug_nudge += delta


## ── CRACK-03 — THE SHARD RIM (Director, 2026-09-02) ──────────────────────────
##
## *"em vez de voxels cúbicos, a gente vai ter partes de voxel formando triângulos
## agudos apontando em direção ao centro do buraco […] estaríamos criando o
## verdadeiro caco com voxel atrás + adesivo complementando."*
##
## A hole in a pane is a rectangle of missing cells, and a rectangle reads as a
## rectangle however good the web over it is. So the cells that BORDER a hole stop
## being cubes: their alpha is cut to a wedge that narrows to a point aimed at the
## hole. The glass that remains is the shard.
##
## ⚠️ IT IS THE SAME PRIMITIVE G-D25 ALREADY RATIFIED — an alpha mask carving a
## whole voxel's outline, the dented-ceiling mechanism — applied to the rim
## instead of to free shards. No new art, no new render path: the mask multiplies
## the alpha of the atom `_build_glass_pane_atom()` already builds.
##
## ⚠️ AND IT DOES NOT RE-CREATE G-D26's MOLDURA. That rule bans a per-voxel change
## to a property the eye reads CONTINUOUSLY across the surface — transparency —
## because the untouched neighbour draws the cell boundary for you. A cut is a
## SILHOUETTE: the glass that survives is pixel-identical to its neighbours, only
## its outline moved. It is the same reason a DESTROYED voxel (a 100% cut) never
## framed anything.
##
## ⚠️ CRACK-04 REPLACED THE SHAPE BUDGET WITH A FAMILY (G-D34). CRACK-03 cut each
## bordering cell with a wedge aimed at the hole, chosen from eight directions —
## so the hole's silhouette was a SIDE EFFECT of a per-cell rule, and nothing
## could state what shape it was. The Director's ruling inverts that: the OPENING
## is a known shape from a catalogue, and a cell's cut is whatever piece of that
## shape crosses it. `GlassOpening` owns the shapes; this file only applies them.
##
## `INFILTRAITOR_GLASS_RIM=0` turns the cut off, so the A/B is one boot apart on
## the same camera. A cut glass voxel reveals GLASS, not a void, so the change is
## subtle by nature and the comparison has to be controlled rather than squinted
## at — the same lesson the pane-clip capture taught.
static var GLASS_RIM_ENABLED: bool = OS.get_environment("INFILTRAITOR_GLASS_RIM") != "0"

## The opening used when a hole arrives with no chosen one. ⚠️ It is a DIAL for
## the capture harness, not a fallback the play path is allowed to lean on: the
## real pick is `GlassOpening.pick()` on a BASE-space key, made by whoever knows
## base coordinates, because a view-space pick reshapes a standing hole every
## time the camera turns.
static var GLASS_OPENING_DEFAULT: String = "star_deep"


## Register the levels every slice and junction column of the registry needs, and count the cells walked
## (`get_walked_cell_count()`, what `Room._assert_geometry_registered()` asks). R3D-END: nothing is drawn or placed — the 3D board meshes
## the `VoxelStore`; this only makes the levels exist for `level_origin()` and its readers. It was `render()`, which placed tiles.
func register_geometry(registry: EdgeRegistry, junction_columns: Array = []) -> void:
	# reset the walk counters for this pass
	_diag_total_cells = 0
	_diag_skipped_cells = 0

	_diag_slice_count = 0
	# Iterate all slices
	for slice in registry.all_slices():
		_diag_slice_count += 1
		_register_slice(slice)

	# Junction columns. INFILTRAITOR_SKIP_JUNCTIONS=1 leaves them out of the walk (a 2D-era capture instrument, TOP-JUNCTION-06).
	if OS.get_environment("INFILTRAITOR_SKIP_JUNCTIONS") != "1":
		for column in junction_columns:
			_register_junction_column(column)


## Register the levels of a solid block (SLICE-02: A-T2) across [start_level, start_level + storey_span): start_level=0 is the
## ground-anchored block, start_level>0 floating geometry (ceiling props, chandeliers, anything that does not start at floor 0).
## Nothing is placed (R3D-END); the 3D board draws every block from the store.
func register_block_levels(_gu_cell: Vector2i, start_level: int, storey_span: int, _material_name: String) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey_span by LEVELS_PER_STOREY to expand to level-space
	## The levels are always registered first (see `register_slab()`): readers of `level_origin()` ask for them.
	_ensure_wall_levels(start_level * GeometryCoords.LEVELS_PER_STOREY + storey_span * GeometryCoords.LEVELS_PER_STOREY)
	## R3D-END: the 3D board draws every block from the store; nothing is placed here.
	_diag_skipped_cells += 1


## Register the levels one slice needs and count its visible voxels (nothing is placed, R3D-END).
func _register_slice(slice: Slice) -> void:
	# Ensure we have enough layers
	# FIX-VOXEL-HEIGHT-01: multiply storey_count by LEVELS_PER_STOREY to expand to level-space
	_ensure_wall_levels(slice.storey_count * GeometryCoords.LEVELS_PER_STOREY)
	## GLASS G-D9 — a slice's material is now per-level. `_slice_is_glassy()` is
	## true when the base OR any band is glass, so the diag and the geometry
	## still fire for a brick-capped window.
	if _slice_is_glassy(slice) and OS.get_environment("INFILTRAITOR_GLASS_DIAG") == "1":
		print("[GLASS-DIAG] slice %s face=%s gu=%s storeys=%d voxels=%d pane=%s bands=%s" % [
			slice.id, Face.to_string_name(slice.face), slice.gu_cell,
			slice.storey_count, slice.voxels.size(),
			slice.pane_id if slice.pane_id != "" else "<none>",
			slice.material_bands if slice.has_material_bands() else "{}"])

	## R3D-END: the 3D board draws every slice from the store; the pass only counts what it walked.
	for voxel in slice.voxels:
		if voxel.visible:
			_diag_skipped_cells += 1


## GLASS G-D9 — true when this slice renders any glass at all (base material, or
## any level band). Non-banded glass slices answer via the base check with zero
## dictionary work.
func _slice_is_glassy(slice: Slice) -> bool:
	if GlassMaterials.is_glass(slice.material):
		return true
	for m in slice.material_bands.values():
		if GlassMaterials.is_glass(m):
			return true
	return false


## Register the levels a junction column needs (BAKE-FIX-02's mirror-at-the-column atoms went with the 2D board; the 3D board draws
## the column from the store).
func _register_junction_column(column: JunctionResolver.JunctionColumn) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey counts by LEVELS_PER_STOREY to expand to level-space
	_ensure_wall_levels((column.start_storey + column.storey_count) * GeometryCoords.LEVELS_PER_STOREY)
	## R3D-END: the 3D board draws every column from the store; nothing is placed here.
	_diag_skipped_cells += 1


## VL-02b — level → set of occupied cells, for the field's surface/AO shading.
## A Dictionary set keeps the field's neighbour probes O(1).
## Includes negative (floor/slab) levels so floor craters shade like wall ones.
## `predict_destroyed` (W-PRECOOK, 2026-08-19) omits cells a shot is ABOUT to
## destroy, so the caller can build the light field for the world as it will be
## rather than as it is. Empty = the live world, which is every existing caller.
##
## It exists so the shot's pre-cook can build the light field for the predicted world in the aim window (on the 2D board it
## also warmed the TileSet alternative cache: 412 `create_alternative_tile()` calls on the impact frame, deleted at R3D-END).
## A WRONG prediction costs nothing but a cache miss, which is why this is safe to do speculatively.
##
## RENDER3D R3D-2 step 1 — answers from the `VoxelStore` alone (visible claims), never the
## placed tiles. Ghosted cells and glass need no separate fold-in here: occlusion never
## marks a claim invisible (O1 — occlusion is VIEW, not STATE) and glass voxels are
## ordinary claims in the store regardless of which sublayer they render on, so
## `occupancy_dict()` already reports both. Verified 0 differences against the old
## tile-walk (`Room.scenario_occupancy_compare`) at load and across both PLAYGROUND
## grenades before the tile fallback below was deleted.
func build_occupancy(predict_destroyed: Dictionary = {}) -> Dictionary:
	if VoxelStore.active == null:
		push_error("[VoxelBoard] build_occupancy: no VoxelStore.active — returning empty occupancy")
		return {}
	return VoxelStore.active.occupancy_dict(predict_destroyed)


## VL-D3 — columns (x,y) covered by any wall/block/roof voxel (positive levels).
## A floor voxel in such a column was never sun-exposed; when a blast opens the
## wall above and exposes its top, it should read darker than always-open floor.
## Computed from the INTACT geometry right after a build (before reapply_damage),
## so it reflects the ORIGINAL cover, not the post-blast state.
##
## RENDER3D R3D-3 step 5 — reads `VoxelStore` (visible claims), never the placed
## tiles, same move `build_occupancy()` already made. `wall_level_keys()`'s own
## filter (`level >= _ground_plane_level`) is reproduced here rather than reused,
## since the store's `occupancy_dict()` spans every level (floors included) and
## this reader specifically wants wall/roof cover, not floor cover. Verified 0
## differences against the old tile-walk on PLAYGROUND before the tile fallback
## below was deleted.
func columns_with_structure() -> Dictionary:
	if VoxelStore.active == null:
		push_error("[VoxelBoard] columns_with_structure: no VoxelStore.active — returning empty")
		return {}
	var cols: Dictionary = {}
	var occ: Dictionary = VoxelStore.active.occupancy_dict()
	for level in occ.keys():
		if int(level) < _ground_plane_level:
			continue
		for cell in (occ[level] as Dictionary).keys():
			cols[cell] = true
	return cols


## VL-03 — GU cell → Array[{level:int, cell:Vector2i}] for every currently
## placed voxel cell, rebuilt as a side effect of every FULL apply_light_field()
## pass (which already visits every cell — free to attach here). This is what
## lets apply_light_field_gus() repaint only a light's influence set without a
## whole-map scan: temporal lights (flicker/pulse, and future ember→char decay)
## toggle far too often to pay the full repaint's ~590ms every time. Stays
## correct between full passes because ghosting/destruction only ERASE cells
## (source_id -1, checked in the incremental path below) — they never add cells
## the index wouldn't already know about; any geometry change is followed by a
## full repaint anyway, which rebuilds this index from scratch.
var _placed_by_gu: Dictionary = {}
## PERF-10 §10.2 — O(1) membership for the index above, so a cell can be added
## incrementally without scanning its GU's list. Cleared and rebuilt with it.
var _placed_index: Dictionary = {}         ## Vector3i(cell.x, cell.y, level) -> true

## PERF-10 — CELLS WRITTEN TO THE BOARD BY SOMEONE OTHER THAN AN APPLY PASS.
##
## The stale-driven apply rests on "a cell whose value changed was invalidated in
## VoxelLightField, therefore it is in the stale set". That property covers every
## change the FIELD causes and none that a direct board write causes — and
## `DetonationChoreographer` is documented as *"the ONLY place a plan ever reaches
## set_cell()"*, writing the plan's own soot and light straight into the
## cell planes. Measured: without this the ending's gate failed by 200 cells, every one
## of them a cell the blast's own wave had written.
##
## So the writer names what it wrote, and the next full-coverage apply unions it
## into the set it walks. This is the seam that lets the map-wide walk retire —
## the walk WAS this bookkeeping, done by brute force every time.
var _externally_written: Dictionary = {}   ## Vector3i(cell.x, cell.y, level) -> true


## See `_externally_written`. Called by whoever writes a cell outside an apply.
func note_external_write(level: int, cell: Vector2i) -> void:
	_externally_written[Vector3i(cell.x, cell.y, level)] = true


var _apply_cells_seen: int = 0
var _apply_cells_written: int = 0


func apply_light_field(field) -> void:
	if LIGHT_DISABLED:
		return
	if field == null:
		return
	## RENDER3D R3D-3 step 5 — no opaque tile is ever placed, so the pass walks the STORE's occupancy
	## (`_apply_light_field_pass_store()`); the tile-walking pass went with the 2D board (R3D-END).
	_apply_light_field_pass_store(field)


## `apply_light_field()`'s pass: write every cell's soot/bucket plane value and index it for `apply_light_field_gus()`. The
## cell set comes from `VoxelStore.occupancy_dict()` (no opaque tile exists to enumerate; the tile-walking pass went at R3D-END).
func _apply_light_field_pass_store(field) -> void:
	_apply_cells_seen = 0
	_apply_cells_written = 0
	_placed_by_gu.clear()
	_placed_index.clear()
	if VoxelStore.active == null:
		push_error("[VoxelBoard] _apply_light_field_pass_store: no VoxelStore.active — planes not written")
		return
	var occ: Dictionary = VoxelStore.active.occupancy_dict()
	for level: Variant in occ.keys():
		var level_i: int = int(level)
		for cell: Vector2i in (occ[level] as Dictionary).keys():
			_apply_cells_seen += 1
			_index_placed(level_i, cell)
			_write_cell_bucket(level_i, cell, field.bucket_for(cell, level_i))
			_apply_cells_written += 1
	flush_cell_soot()
	if field.has_method("clear_stale_accum"):
		field.clear_stale_accum()
	_externally_written.clear()



## PERF-10 §10.2 — `_placed_by_gu` MEMBERSHIP, in O(1).
##
## The index was rebuilt only by the full pass and only ever READ by the scoped
## one, so a cell placed since that pass — a crater floor revealed by a blast is
## exactly that — was invisible to every scoped apply. The residue probe measured
## 92 of 119 disagreeing cells as never-indexed. Maintaining it wherever cells are
## visited is what stops that class existing, and the membership set is what makes
## an incremental add cheap enough to do unconditionally.
func _index_placed(level: int, cell: Vector2i) -> void:
	var key := Vector3i(cell.x, cell.y, level)
	if _placed_index.has(key):
		return
	_placed_index[key] = true
	var gu := Vector2i(cell.x >> 3, cell.y >> 3)
	if not _placed_by_gu.has(gu):
		_placed_by_gu[gu] = []
	_placed_by_gu[gu].append({"level": level, "cell": cell})


## PERF-10 — THE APPLY, DRIVEN BY THE FIELD'S OWN STALE SET.
##
## The same per-cell body as the map-wide pass; the only difference is
## which cells it visits. §10.1 priced the map-wide pass at ~610 ms of walk to
## write 96 cells of 205 384 — the writes and the mints together came to 37 ms,
## and -3 ms on a second sample. The walk IS the stall, so the fix is to walk the
## work instead of the board.
##
## Correctness rests on one property, and it already has a standing gate:
## `VoxelLightField._stale_cells()` erases exactly the cache entries the incoming
## occupancy and soot invalidate, so a cell whose value CHANGES must have been
## invalidated — otherwise `bucket_for()` would have returned the old cached
## number and `INFILTRAITOR_LIGHT_EQUIV_PROBE` would not report `0 differ`. So
## **changed implies in the set**, which is what driving an apply from it needs.
##
## ⚠️ It indexes what it visits (see `_index_placed()`), because a cell-driven
## pass never rebuilds `_placed_by_gu` the way the map-wide one does, and letting
## the index rot would trade this stall for §10.2's defect.
func apply_light_field_cells(field, cells: Dictionary) -> void:
	if LIGHT_DISABLED:
		return
	if field == null:
		return
	_apply_cells_seen = 0
	_apply_cells_written = 0
	## The field's stale set plus every cell written behind its back. Unioned into
	## a local so the caller's dictionary is never mutated.
	var visit: Dictionary = {}
	for k in cells.keys():
		visit[k] = true
	for k in _externally_written.keys():
		visit[k] = true
	for key in visit.keys():
		## DIAG-21 2c: the planes only. No tile says whether the cell is still there, so every visited key is written.
		var level: int = key.z
		var cell := Vector2i(key.x, key.y)
		_write_cell_bucket(level, cell, field.bucket_for(cell, level))
	flush_cell_soot()
	field.clear_stale_accum()
	_externally_written.clear()


func apply_light_field_gus(field, gus: Array) -> void:
	if LIGHT_DISABLED:
		return
	if field == null or gus.is_empty():
		return
	var gu_set: Dictionary = {}
	for gu in gus:
		gu_set[gu] = true
		var placements = _placed_by_gu.get(gu)
		if placements == null:
			continue
		for entry in placements:
			var level: int = entry["level"]
			var cell: Vector2i = entry["cell"]
			## R3D-6: the planes only. No opaque tile exists to say whether the cell is still there, and without this
			## the blast's consequence pass wrote NO soot and NO light into the planes.
			_write_cell_bucket(level, cell, field.bucket_for(cell, level))
	flush_cell_soot()


## Process dirty slices only (TIC optimization)
func process_dirty(registry: EdgeRegistry) -> void:
	var dirty_slices := registry.dirty_slices()

	if dirty_slices.is_empty():
		return

	# Update cells for dirty voxels
	for slice in dirty_slices:
		# Try to get edge from registry
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null

		for voxel in slice.voxels:
			if voxel.dirty:
				_process_dirty_slice_voxel(voxel, slice, edge)

		# Clear all dirty flags in slice
		slice.clear_all_dirty()

	## G-D30 — a batch just ended; re-cut any crack whose pane lost glass.
	refresh_glass_crack_occupancy()
	refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.


## PERF-01: the per-voxel body process_dirty() runs for every dirty voxel in
## a slice — extracted so process_dirty_async() can share the exact same
## logic instead of a second copy drifting from this one over time.
func _process_dirty_slice_voxel(voxel: Voxel, slice: Slice, _edge) -> void:
	## GLASS G-D9 — the material is per-level on a banded slice.
	var vmat := slice.material_at(voxel.level - GeometryCoords.storey_level_base(slice.start_storey))
	var is_glass_mat: bool = GlassMaterials.is_glass(vmat)
	## No tile is placed (the 3D board reads the store). A visible voxel needs nothing here; an invisible one owes its
	## `voxel_destroyed` notice once, and a glass one the seams `_render3d_glass_gone()` runs.
	if not voxel.visible:
		if is_glass_mat:
			_render3d_glass_gone(voxel, vmat)
			return
		## The idempotence the tile's `already_gone` answered once: see `_render3d_gone_cells`'s own note.
		var key3 := Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level)
		if not _render3d_gone_cells.has(key3):
			_render3d_gone_cells[key3] = true
			voxel_destroyed.emit(voxel.grid_pos, voxel.level, slice.material)


## Slab-side counterpart to process_dirty() — DESTRUCTION_MASTER_PLAN Part 3.
## Until now nothing consumed SlabRegistry.dirty_slabs() on the render side:
## room.gd's _tic_slab_system() only cleared dirty flags. Re-render routes
## through the SAME per-voxel call each Slab's own original render used
## (register_slab()'s split — zoned floor, earth-hash otherwise — and register_slab_solid()'s
## fixed material for CEILING/INTERIOR) so a re-render after partial damage sees the same
## visible voxels as a fresh one. R3D-END: nothing is erased here (the 3D board meshes the
## store); what is left is the `voxel_destroyed` notice and the light and glass bookkeeping.
func process_dirty_slabs(registry: SlabRegistry) -> void:
	var dirty_slabs := registry.dirty_slabs()
	if dirty_slabs.is_empty():
		return

	## FLOOR-ZONE fix (2026-07-28): a FLOOR Slab carrying a zone material re-renders
	## through the zone's baked page, exactly like register_slab() does — the branch
	## below used to send EVERY Role.FLOOR voxel down the earth-variant path, so a
	## dirty-but-surviving voxel of a zoned floor (a CRACKED one; a DESTROYED one
	## is erased instead) would come back as generic earth in the middle of an
	## otherwise concrete floor. Latent when written (craters only destroyed);
	## FLOOR-DENT-01 (2026-08-01) made floor damage real — crater-rim survivors
	## now carry DENTED with a carved TOP.
	for slab in dirty_slabs:
		var use_solid: bool = slab.role != Slab.Role.FLOOR
		## A zoned floor is any non-earth floor slab: the flag used to also ask `BakeConfig.enabled`, which is true on every
		## real load, and the bake it named went at R3D-END step END-4.
		var is_zoned_floor: bool = (not use_solid) and slab.material != "earth"
		for voxel in slab.voxels:
			if voxel.dirty:
				_process_dirty_slab_voxel(voxel, slab, use_solid, is_zoned_floor)

		slab.clear_all_dirty()

	## G-D30 — a batch just ended; re-cut any crack whose pane lost glass.
	refresh_glass_crack_occupancy()
	refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.


## PERF-01: the per-voxel body process_dirty_slabs() runs for every dirty
## voxel in a slab — extracted so process_dirty_slabs_async() can share the
## exact same logic instead of a second copy drifting from this one over
## time. `use_solid`/`is_zoned_floor` are computed once per slab by the
## caller (constant across every voxel in it), not re-derived per voxel.
func _process_dirty_slab_voxel(voxel: Voxel, slab: Slab, _use_solid: bool, is_zoned_floor: bool) -> void:
	## Mirrors `_process_dirty_slice_voxel()`. A slab voxel is a glass PANE unless it is a glass roof or a glazed floor zone,
	## which stay opaque by G1's own rule.
	var is_glass_pane: bool = GlassMaterials.is_glass(slab.material) \
		and not (slab.role == Slab.Role.CEILING or is_zoned_floor)
	if not voxel.visible:
		if is_glass_pane:
			_render3d_glass_gone(voxel, slab.material)
			return
		var key3 := Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level)
		if not _render3d_gone_cells.has(key3):
			_render3d_gone_cells[key3] = true
			voxel_destroyed.emit(voxel.grid_pos, voxel.level, slab.material)


## R3D-14 — a glass pane voxel has gone invisible under the store's glass state. Everything the layer erase used to do that is
## STATE and not drawing: the light bookkeeping, the two glass seams (the crack's occupancy re-cut, the rim's opening
## batch), and the `voxel_destroyed` notice, told once per cell.
func _render3d_glass_gone(voxel: Voxel, material_id: String) -> void:
	var key := Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level)
	var first: bool = not _render3d_gone_glass.has(key)
	_render3d_gone_glass[key] = true
	note_external_write(voxel.level, voxel.grid_pos)
	note_glass_erased()
	note_glass_erased_for_rim(voxel.level, voxel.grid_pos)
	if first:
		voxel_destroyed.emit(voxel.grid_pos, voxel.level, material_id)


## D11 — how long one async render batch may run before yielding a frame.
##
## This REPLACES the old `voxels_per_frame = 150` count, and the reason is
## measured: that number was chosen when a voxel cost ~3.7ms, and PERF-01/02
## took it to ~0.9ms without the count following. The result was the opposite
## of a spread — the wall pass finished inside a single frame without ever
## yielding, and the slab pass ran ONE 135ms batch, i.e. a ~7fps frame. That
## is exactly the "engasgada" the Director reported.
##
## A time budget adapts to whatever a voxel costs today, and to the fact that
## voxel costs are wildly uneven (erasing a DESTROYED voxel is nearly free;
## compositing a DENTED one runs a decal paste). The NUMBER itself is measured,
## not the obvious "half a 60fps frame" guess (8ms) it started at — D11 also
## does per-voxel-STATE stages (DESTROYED, then DENTED, then the rest), and
## real profiling on the dev capture harness found each yield disproportionately
## expensive whenever a batch had composited a damage-composite atlas page
## (on the 2D board, whose page flush re-uploaded the touched page's whole texture
## before the frame draws — cheap CPU-side per PERF-02's own numbers, but the
## frame that then renders it was measured far slower than an untouched one on
## this harness). An 8ms budget forces a yield roughly every 1-2 decal-heavy
## voxels, which multiplies that per-yield cost by voxel count instead of
## amortizing it. Measured end-to-end detonation wall-clock at several budgets
## on the same real blast: 8ms → 8940ms, 40ms → 2674ms, 50ms → 2663ms,
## 100ms → 1375ms, 200ms → 995ms, effectively-unbounded (no in-stage yield at
## all) → 853ms. 200ms was chosen off that curve: it already sits within ~8%
## of the unbounded floor (i.e. batching finer buys almost nothing further),
## while still yielding when a stage's total work genuinely needs it — the
## measured blast triggered exactly one yield at this setting, not zero — so a
## much larger future blast still gets spread across multiple frames instead of
## one long block, which is the hard requirement PERF-01 shipped this async
## path to satisfy in the first place.
var render_frame_budget_ms: float = 200.0

## Async counterpart to process_dirty(): identical per-voxel logic
## (_process_dirty_slice_voxel()), but yields a frame every
## `render_frame_budget_ms` of wall time instead of running the whole dirty set
## in one synchronous call. process_dirty() itself is untouched and stays
## synchronous — _tic_voxel_system() (small per-step deltas),
## _reapply_base_damage() (map rebuild/rotation) and
## slab_render_selftest.gd all call it expecting immediate completion, and
## none of them showed the multi-second stall this exists to avoid. Only
## TestZoneController.detonate_active() and
## WeaponBenchController.fire_active() — the two big-batch, player-triggered
## paths — use this one.
## D11 — `states` filters which DamageStates this pass renders, so a caller can
## run the same dirty set in stages (destroyed first, then dented, then the
## rest) instead of one undifferentiated sweep. Empty = everything, which is
## the pre-D11 behaviour and what every non-staged caller still gets.
##
## Dirty flags are cleared PER VOXEL when a filter is active — `clear_all_dirty()`
## would drop the flags of the voxels this stage deliberately skipped, and the
## next stage would then find nothing to do.
func process_dirty_async(registry: EdgeRegistry, states: Array = []) -> void:
	var dirty_slices := registry.dirty_slices()
	if dirty_slices.is_empty():
		return

	var filtered: bool = not states.is_empty()
	var batch_start: int = Time.get_ticks_usec()
	for slice in dirty_slices:
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null
		for voxel in slice.voxels:
			if voxel.dirty and (not filtered or states.has(voxel.damage_state)):
				_process_dirty_slice_voxel(voxel, slice, edge)
				if filtered:
					voxel.clear_dirty()
				if float(Time.get_ticks_usec() - batch_start) / 1000.0 >= render_frame_budget_ms:
					## G-D30 — same reason as the flush above, one layer up: a
					## frame is about to DRAW, and a crack whose pane just lost
					## glass would be shown uncut for it.
					refresh_glass_crack_occupancy()
					refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.
					await get_tree().process_frame
					## Restart the clock AFTER the frame wait, so the wait
					## itself is not charged against the next batch's budget.
					batch_start = Time.get_ticks_usec()
		## D11: only safe when this pass took every dirty voxel — see the
		## per-voxel clear above for the filtered case.
		if not filtered:
			slice.clear_all_dirty()

	## G-D30 — a batch just ended; re-cut any crack whose pane lost glass.
	refresh_glass_crack_occupancy()
	refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.


## Async counterpart to process_dirty_slabs() — see process_dirty_async()'s
## doc for why this is a second entry point rather than a parameter on the
## synchronous original.
func process_dirty_slabs_async(registry: SlabRegistry, states: Array = []) -> void:
	var dirty_slabs := registry.dirty_slabs()
	if dirty_slabs.is_empty():
		return

	var filtered: bool = not states.is_empty()
	var batch_start: int = Time.get_ticks_usec()
	for slab in dirty_slabs:
		var use_solid: bool = slab.role != Slab.Role.FLOOR
		## A zoned floor is any non-earth floor slab: the flag used to also ask `BakeConfig.enabled`, which is true on every
		## real load, and the bake it named went at R3D-END step END-4.
		var is_zoned_floor: bool = (not use_solid) and slab.material != "earth"
		for voxel in slab.voxels:
			if voxel.dirty and (not filtered or states.has(voxel.damage_state)):
				_process_dirty_slab_voxel(voxel, slab, use_solid, is_zoned_floor)
				if filtered:
					voxel.clear_dirty()
				if float(Time.get_ticks_usec() - batch_start) / 1000.0 >= render_frame_budget_ms:
					## G-D30 — same reason as the flush above, one layer up: a
					## frame is about to DRAW, and a crack whose pane just lost
					## glass would be shown uncut for it.
					refresh_glass_crack_occupancy()
					refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.
					await get_tree().process_frame
					batch_start = Time.get_ticks_usec()
		## D11: see process_dirty_async()'s own note.
		if not filtered:
			slab.clear_all_dirty()

	## G-D30 — a batch just ended; re-cut any crack whose pane lost glass.
	refresh_glass_crack_occupancy()
	refresh_glass_rims()   ## CRACK-03 — and the shard rim around any new hole.


## PERF-P2 — the per-cell soot plane: one R8 texture per LEVEL, one texel per
## cell, carrying the same 0..124 base-5 face code the alternative's alpha used
## to carry (top*25 + se*5 + sw, 4 = clean per face, 124 = fully clean).
##
## WHY A TEXTURE AT ALL, and it is not "because textures are fast": the 2D board's TileMapLayer had exactly one per-cell channel
## — the alternative id — and every distinct (bucket, soot) pair spent one (PERFORMANCE_MASTER_PLAN §1.4: up to 3 000
## alternatives per tile, each a `create_alternative_tile()` and a TileSet rebuild charged once per FRAME THAT MINTS). The 3D
## board reads this plane per cell instead.
##
## Sized by a CONSTANT and loud-failing past it (B6) rather than growing: a
## silently-clamped cell would render clean soot with no error, which is exactly
## the failure mode this project keeps paying for. 512 covers a 64x64 GU board;
## PLAYGROUND is 46x24 with its buffer.
## ⚠️ CELLS GO NEGATIVE, and the first version of this plane did not know that.
##
## The map's BUFFER (Rule 7 — applied only in MapCompiler) puts real geometry at
## negative voxel coordinates: measured by making the 2D shader print its recovered
## cell, the fragments along every GU seam resolve to cells like (-8, 8). Indexed
## from zero, ~110 000 fragments of a 921 600-pixel frame — about 12% — fell
## outside the plane and silently took the "clean" fallback, which is invisible
## exactly until something near them is sooty. That is the shape of bug this
## project keeps paying for, and it shipped in PERF-P2.
##
## So the plane carries an ORIGIN: everything indexes `cell + ORIGIN`, and the
## board's shader is passed the same offset.
## PERF-P3 — the G-channel value meaning "no bucket was ever written here".
## Deliberately outside 0..LIGHT_BUCKET_COUNT-1 so it can never be mistaken for a
## real bucket; the shader clamps it to full-lit for rendering.
##
## RENDER3D R3D-2 step 3 — the planes themselves moved to `CellPlaneStore` (a
## render-neutral owner both the 2D and future 3D board read); these three names stay
## as aliases so every existing caller keeps working unchanged.
const _CellPlaneStoreScript: GDScript = preload("res://godot/scripts/systems/cell_plane_store.gd")
const BUCKET_UNWRITTEN: int = _CellPlaneStoreScript.BUCKET_UNWRITTEN
const SOOT_PLANE_ORIGIN: Vector2i = _CellPlaneStoreScript.SOOT_PLANE_ORIGIN
const SOOT_TEX_SIZE: int = _CellPlaneStoreScript.SOOT_TEX_SIZE
var _cell_planes = _CellPlaneStoreScript.new(FACE_SOOT_CODE_CLEAN, LIGHT_BUCKET_COUNT - 1)


## Record one cell's soot code. Thin forwarder — see `CellPlaneStore.write_soot()`.
func _write_cell_soot(level: int, cell: Vector2i, code: int) -> void:
	_cell_planes.write_soot(level, cell, code)


## SOOT-STAMP — see `CellPlaneStore.reset_all()`. Called by the map-wide repaint
## before its apply, which then rewrites every bucket; the soot store follows.
func reset_cell_planes() -> void:
	_cell_planes.reset_all()


## Record one cell's light bucket. Thin forwarder — see `CellPlaneStore.write_bucket()`.
func _write_cell_bucket(level: int, cell: Vector2i, bucket: int) -> void:
	_cell_planes.write_bucket(level, cell, bucket)


## What the plane currently says about one cell's light bucket. Thin forwarder —
## see `CellPlaneStore.bucket_at()`.
func cell_bucket_at(level: int, cell: Vector2i) -> int:
	return _cell_planes.bucket_at(level, cell)


## DIAG-21 — the RG8 cell plane image of one level (R = face soot code, G = light
## bucket), or null when the level has none. The 3D board uploads these into its
## Texture2DArray; read-only by contract. Thin forwarder — see `CellPlaneStore.plane_image()`.
func cell_plane_image(level: int) -> Image:
	return _cell_planes.plane_image(level)


## RENDER3D R3D-0 — every level that holds a cell plane, sorted. `BoardProbe` dumps
## them all; `level_keys()` lists LAYERS, and a plane is created by its writers, not by
## a layer, so the two sets are not assumed to be the same. Thin forwarder — see
## `CellPlaneStore.plane_levels()`.
func cell_plane_levels() -> Array:
	return _cell_planes.plane_levels()


## What the plane currently says about one cell's soot code. Thin forwarder —
## see `CellPlaneStore.soot_at()`.
func cell_soot_at(level: int, cell: Vector2i) -> int:
	return _cell_planes.soot_at(level, cell)


## Upload whatever changed. Thin forwarder — see `CellPlaneStore.flush()`.
func flush_cell_soot() -> int:
	return _cell_planes.flush(true)


## ── CRACK-02 — THE CRACK SPRITES (GLASS_MASTER_PLAN §13, G-D27) ───────────────
##
## CRACK-01 drew the web from inside `glass_pane.gdshader`, off a per-level R8
## group plane and a 16-wide RGBAF strip. All of that is DELETED (§13.1): a crack
## drawn by the voxel shader inherits the atom's `dim`, the coverage alpha and the
## quad seams, which is why the look was rejected three times.
##
## A crack is a RECORD — one per event, carrying its `GlassCrackParams` (every shader parameter, as data), which
## `GlassCrackMirror3D` draws on the 3D board (R3D-END: the 2D `GlassCrackSprite` it was until then is gone). What the
## renderer owns here is the registry: enough to answer G-D24's crossing test geometrically (§13.1's one rewritten
## piece) and, from S-3, to rebuild the cracks after a perspective flip.
const GlassCrackParamsClass = preload("res://godot/scripts/systems/destruction/glass_crack_params.gd")

## Every live crack, in creation order. One entry per event:
##   id, pane_id, run_axis, wide, impact_run, impact_level, radius (Vector2i),
##   crack (GlassCrackParams), params (its Dictionary)
var _glass_cracks: Array = []
## B-2 — so the "B-3 owes the art" note is printed once per boot, not once per
## crazed pane. A blast can craze several.
var _glass_craze_art_noted: bool = false
## B-2's wrap-test tile, built once per boot when the env var asks for it.
var _glass_craze_tile_cache: Texture2D = null
## B-4b — every opening polygon actually applied, so a craze field can be cut to
## the same shapes the voxels were. Cleared with the cracks on a rebuild, and
## refilled by `_respawn_base_openings()` replaying them.
var _glass_applied_openings: Array = []
var _glass_crack_next_id: int = 0
var _glass_crack_sheets: Dictionary = {}   ## width:String -> Texture2D


## The fracture sheet for one width (G-D14's `tight` / `wide`), cached. Loaded
## directly rather than through TextureResolver: a sprite is free-size art, and
## §13.3 took the facade contract off this class precisely so it can be.
## CRACK-04 — the sheet for one (opening, variant). Keyed by the PATH, so the same
## art shared by two holes is loaded once.
##
## ⛔ The old `fracture_glass_{tight,wide}.png` are retired: they drew a ROUND
## hole, and no member of the opening family is round.
func _glass_crack_sheet(opening_id: String, variant: int) -> Texture2D:
	var path: String = GlassCrack.sheet_path(opening_id, variant)
	if path == "":
		return null
	if _glass_crack_sheets.has(path):
		return _glass_crack_sheets[path]
	var tex := load(path) as Texture2D
	if tex == null:
		## B6 loud-fail: a missing sheet must not degrade to an invisible crack.
		push_error("[VoxelBoard] CRACK-04: fracture sheet %s failed to load — the crack will not draw" % path)
	_glass_crack_sheets[path] = tex
	return tex


## G-D24's test, now GEOMETRIC (§13.1 — the one piece of CRACK-01 that had to be
## rewritten rather than moved). With no per-cell plane, "does this cell already
## carry a crack" is "does it fall inside a live crack's region on the same pane".
## Returns that crack's id, or 0.
##
## Faithful to the plane it replaces: a crack's region IS the rectangle
## `plan_pane_crack()` selected its cells from, and every cell it skipped
## (DESTROYED, or a G-D9 band) is skipped by the new plan for the same reason.
## ⚠️ G-D35 B-2 — A CRAZE FIELD IS NOT COVERAGE, AND THIS IS THE ONE PLACE THAT
## HAS TO KNOW THE DIFFERENCE. A field record shares this registry (one lifecycle,
## one occupancy refresh, one visibility switch — the alternative was a parallel
## array and five duplicated helpers). But G-D24 is about two FRACTURES crossing,
## and a craze has no fracture and no region: it is the whole pane at once. Left
## in, every blast-crazed pane would answer "covered" for every cell, so the next
## round anywhere on it would destroy what it touched instead of cracking it — a
## silent gameplay change nothing would have failed on.
func glass_crack_covering(pane_id: String, run: int, level: int) -> int:
	for c in _glass_cracks:
		if bool(c.get("field", false)):
			continue
		if c["pane_id"] != pane_id:
			continue
		var r: Vector2i = c["radius"]
		if absi(run - int(c["impact_run"])) > r.x:
			continue
		if absi(level - int(c["impact_level"])) > r.y:
			continue
		return int(c["id"])
	return 0


## Create one crack sprite. `spec` is the shape `GlassCrack.apply()` builds — see
## its own note; the keys are pane_id, run_axis, wide, impact_run, impact_level,
## impact_cell, radius, span, pane_lo, pane_hi. Returns the new crack's id, or 0
## if the art or the shader is missing (already loud-failed by then).
func spawn_glass_crack(spec: Dictionary) -> int:
	var wide: bool = bool(spec.get("wide", false))
	var opening_id: String = String(spec.get("opening", ""))
	## ⚠️ A CRACK WITH NO HOLE STILL NEEDS A SHEET, AND WHICH ONE IS NOT DECIDED
	## HERE. This branch used to carry its own copy of the fallback rule while
	## `sheet_span_for()` carried another, so the PAGE and the QUAD were picked by
	## two statements of one thing — and G-D28's `armored` class is exactly the
	## edit that would have moved one and not the other. `GlassCrack.sheet_id_for()`
	## is the single answer now; this asks it.
	var sheet_opening: String = GlassCrack.sheet_id_for(opening_id, wide,
		bool(spec.get("armored", false)))
	var sheet: Texture2D = _glass_crack_sheet(sheet_opening, int(spec.get("variant", 0)))
	if sheet == null:
		return 0
	var crack := GlassCrackParamsClass.new()
	crack.setup(sheet, spec["span"], spec["pane_lo"], spec["pane_hi"])
	_glass_crack_next_id += 1
	var rec := {
		"id": _glass_crack_next_id,
		"pane_id": String(spec.get("pane_id", "")),
		"run_axis": int(spec["run_axis"]),
		"wide": wide,
		"impact_run": int(spec["impact_run"]),
		"impact_level": int(spec["impact_level"]),
		"impact_cell": spec["impact_cell"],
		"face": int(spec.get("face", Face.SW)),
		"radius": spec["radius"],
		"pane_lo": spec["pane_lo"],
		"pane_hi": spec["pane_hi"],
		"crack": crack,
		## R3D-9: the crack as data — the 3D board draws from this (it is the params' own Dictionary, so it follows
		## every later `set_occupancy()` / `set_opening()` / `set_hole_cut()`).
		"params": crack.params,
		"visible": true,
		"opening": String(spec.get("opening", "")),
	}
	_glass_cracks.append(rec)
	crack.set_hole_cut(_glass_crack_hole_cut)
	## CRACK-04 — the sheet's inner void IS the opening this hole was cut with.
	## An empty id is the pane that only CRAZED: no hole, so no void, and the sheet
	## keeps its whole centre. That is G-D33's rule arriving as a consequence of
	## the wiring rather than as a branch someone has to remember to write.
	if opening_id != "":
		var m: Dictionary = _glass_opening_mask(opening_id)
		if not m.is_empty():
			crack.set_opening(m["texture"], m["origin"], m["size"])
	_build_crack_occupancy(rec)
	return _glass_crack_next_id


## ── G-D35 B-2 — SPAWN ONE BLAST CRAZE FIELD ─────────────────────────────────
##
## `spec` is `GlassCrack.plan_pane_field()`'s output plus a `variant`. Returns the
## new field's id, or 0.
##
## ⚠️ IT RETURNS 0 UNTIL B-3 DELIVERS THE ART, AND THAT IS THE ORDERING, NOT A
## FAILURE. G-D35's sheet is a centreless tiled field; drawing today's centred
## bullet page over a blast-crazed pane would be the wrong art wired to a real
## trigger — worse than no art, because it would look finished (§16.5). So the
## whole path is wired and the sheet is the only thing missing: the day
## `fracture_manifest.json` carries a `blast_*` row, this lights up with no code
## change anywhere. `INFILTRAITOR_GLASS_CRAZE_SHEET` overrides the key, which is
## how the demo photographs the SEAM before the art exists.
func spawn_glass_craze(spec: Dictionary) -> int:
	var sheet_id: String = String(spec.get("sheet", ""))
	var tile_span: Vector2 = spec.get("tile_span", Vector2(8.0, 8.0))
	var forced := OS.get_environment("INFILTRAITOR_GLASS_CRAZE_SHEET")
	if forced != "":
		sheet_id = forced
		tile_span = GlassCrack.page_span(forced)
	var sheet: Texture2D = null
	if OS.get_environment("INFILTRAITOR_GLASS_CRAZE_TESTTILE") == "1":
		sheet = _glass_craze_wrap_tile()
		## ⚠️ THE TEST TILE CARRIES ITS OWN SPAN, AND IT MUST. `tile_span` comes
		## from the manifest, and no `blast_*` row exists yet — so without this the
		## square wrap tile would be drawn on the 2:1 fallback page and every ring
		## in it would render as an ellipse, which is the exact defect the tile is
		## here to detect. `INFILTRAITOR_GLASS_CRAZE_TILE_VOXELS` sizes it.
		var tv := OS.get_environment("INFILTRAITOR_GLASS_CRAZE_TILE_VOXELS")
		var side: float = tv.to_float() if tv.is_valid_float() and tv.to_float() > 0.0 else 8.0
		tile_span = Vector2(side, side)
	else:
		sheet = _glass_crack_sheet(sheet_id, int(spec.get("variant", 0)))
	if sheet == null:
		if not _glass_craze_art_noted:
			_glass_craze_art_noted = true
			## ⚠️ %s, NOT %r — GDScript's format has no %r, and it prints the two
			## characters verbatim. Caught by reading the line the run actually
			## emitted rather than the one this code says it emits.
			print_debug("[GLASS-CRAZE] B-2: the field is wired and \"%s\" has no sheet yet — B-3 owes the art (GLASS_MASTER_PLAN §16.3)"
				% sheet_id)
		return 0
	var crack := GlassCrackParamsClass.new()
	var centre_cell: Vector2i = spec["centre_cell"]
	var centre_level: int = int(spec["centre_level"])
	crack.setup_field(sheet, spec["span"], spec["pane_lo"], spec["pane_hi"], tile_span,
		## B-2b — the base-space anchor, computed by the room (it owns the
		## conversion) and defaulting to B-2's view-space corner when a caller has
		## none, which is only the selftest's synthetic frame.
		spec.get("field_origin", spec["pane_lo"]),
		spec.get("field_dir", Vector2.ONE))
	_glass_crack_next_id += 1
	## ⚠️ THE RECORD'S `impact_*` ARE THE PANE'S CENTRE CELL, NOT AN IMPACT. A
	## craze has none — but `_build_crack_occupancy()` is written against exactly
	## these three keys plus pane_lo/pane_hi, and giving the field its own copy of
	## that walk is how the cut would drift between the two modes the first time
	## one of them was fixed.
	var rec := {
		"id": _glass_crack_next_id,
		"field": true,
		"pane_id": String(spec.get("pane_id", "")),
		"run_axis": int(spec["run_axis"]),
		"wide": false,
		"impact_run": int(spec["centre_run"]),
		"impact_level": centre_level,
		"impact_cell": centre_cell,
		"face": int(spec.get("face", Face.SW)),
		"radius": Vector2i.ZERO,
		"pane_lo": spec["pane_lo"],
		"pane_hi": spec["pane_hi"],
		"crack": crack,
		"params": crack.params,
		"visible": true,
		"opening": "",
		"intensity": float(spec.get("intensity", 0.0)),
	}
	_glass_cracks.append(rec)
	crack.set_hole_cut(_glass_crack_hole_cut)
	_build_crack_occupancy(rec)
	_build_craze_opening_mask(rec)
	return _glass_crack_next_id


## ── B-2's INSTRUMENT — A TILE THAT WRAPS BY CONSTRUCTION ────────────────────
##
## `INFILTRAITOR_GLASS_CRAZE_TESTTILE=1`. Not art and never mistakable for it: a
## grid of marks placed so that the SEAM is the only thing that can break them.
##
## ⚠️ IT EXISTS BECAUSE B-2 CANNOT BE SEEN OTHERWISE, AND THE ORDERING IS ON
## PURPOSE. B-3 owns the craze mesh; until it lands `spawn_glass_craze()` draws
## nothing at all, so a capture of the seam would be a capture of an empty pane.
## Photographing the mechanism with a pattern that is obviously a test keeps the
## two apart — the trap §16.5 names is art that *looks finished*, and this cannot.
##
## What each mark proves, and none of them is decoration:
##   * quarter-discs at the four CORNERS join into one disc across a 2x2 of tiles
##     — if the lattice phase is wrong in either axis, the disc is broken;
##   * half-discs at the four EDGE MIDPOINTS join in pairs — this separates a
##     phase error from a SCALE error, which the corners alone cannot;
##   * a centred square, whose printed proportions read the tile's own aspect —
##     a stretched lattice shows here and nowhere else;
##   * a full-page diagonal, which stays straight across tiles only if both.
func _glass_craze_wrap_tile() -> Texture2D:
	if _glass_craze_tile_cache != null:
		return _glass_craze_tile_cache
	var n: int = 256
	var img := Image.create(n, n, false, Image.FORMAT_R8)
	img.fill(Color8(0, 0, 0, 255))
	var ink := Color8(255, 0, 0, 255)
	var r: float = float(n) * 0.22
	var centres: Array[Vector2] = [
		Vector2(0, 0), Vector2(n, 0), Vector2(0, n), Vector2(n, n),          ## corners
		Vector2(n * 0.5, 0), Vector2(n * 0.5, n),                            ## edge midpoints
		Vector2(0, n * 0.5), Vector2(n, n * 0.5),
	]
	for y in range(n):
		for x in range(n):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var on: bool = false
			for c in centres:
				var d: float = p.distance_to(c)
				## A RING, not a disc: a filled one would merge with its neighbours
				## and hide the very join it is here to show.
				if d <= r and d >= r - 3.0:
					on = true
					break
			## The centred square, at a third of the page.
			var lo: float = float(n) / 3.0
			var hi: float = float(n) * 2.0 / 3.0
			if not on and ((absf(p.x - lo) < 1.5 or absf(p.x - hi) < 1.5) and p.y >= lo and p.y <= hi):
				on = true
			if not on and ((absf(p.y - lo) < 1.5 or absf(p.y - hi) < 1.5) and p.x >= lo and p.x <= hi):
				on = true
			## The diagonal, corner to corner — straight across tiles only if the
			## phase AND the scale are both right.
			if not on and absf(p.x - p.y) < 1.5:
				on = true
			if on:
				img.set_pixel(x, y, ink)
	_glass_craze_tile_cache = ImageTexture.create_from_image(img)
	return _glass_craze_tile_cache


## ── B-4b — CUT THE CRAZE FIELD TO THE HOLES' OWN POLYGONS ───────────────────
##
## One R8 mask over the field's pane rectangle, at sub-cell resolution, carrying
## every opening applied on that pane. 1 = inside a hole, so the shader multiplies
## the mesh by `1 - mask` and the craze simply stops at the glass's real edge.
##
## ⚠️ THIS IS NOT THE OCCUPANCY AND CANNOT BE. The occupancy is one texel per CELL
## and nearest-filtered on purpose (a destroyed voxel IS a voxel). The opening's
## edge is sub-cell by definition — *"intrusão nas bordas dos voxels ao redor"* —
## so a cell that still holds a SHARD reads as full glass to the occupancy while
## most of it is gone. Before this, the mesh drew over that missing part, which is
## what made B-4's perforated pane read as confused — and what would do the
## same to a pane a ROUND has holed and a later blast then crazes, which is the
## case that survives now that the perforation is gone.
##
## ⚠️ AND IT IS RASTERISED FROM `GlassOpening.polygon()`, not composited from the
## per-opening mask images. Those carry their own origins and paddings; walking
## the one authority into this rect keeps the mesh's cut and the voxels' cut the
## SAME line rather than two that have to be kept in agreement (G-D34's whole
## point, one level up).
const CRAZE_MASK_TEXELS_PER_VOXEL: int = 6


func _build_craze_opening_mask(c: Dictionary) -> void:
	var crack = c["crack"]
	if crack == null or not crack.valid:
		return
	var lo: Vector2 = c["pane_lo"]
	var hi: Vector2 = c["pane_hi"]
	var span := Vector2(hi.x - lo.x + 1.0, hi.y - lo.y + 1.0)
	var w: int = int(round(span.x * float(CRAZE_MASK_TEXELS_PER_VOXEL)))
	var h: int = int(round(span.y * float(CRAZE_MASK_TEXELS_PER_VOXEL)))
	if w < 2 or h < 2 or w > 4096 or h > 4096:
		return
	## The mask's own frame: its top-left in (run, level) voxels from the sprite
	## centre, exactly the parameterisation `set_opening()` already takes.
	var origin := Vector2(lo.x - 0.5, hi.y + 0.5)
	var img: Image = c.get("craze_mask_image")
	if img == null or img.get_width() != w or img.get_height() != h:
		img = Image.create(w, h, false, Image.FORMAT_R8)
	img.fill(Color(0.0, 0.0, 0.0))

	var run_is_x: bool = int(c["run_axis"]) == 0
	var c_run: int = int(c["impact_run"])
	var c_lvl: int = int(c["impact_level"])
	var cross: int = (c["impact_cell"] as Vector2i).y if run_is_x \
		else (c["impact_cell"] as Vector2i).x
	var painted: int = 0
	for rec in _glass_applied_openings:
		if bool(rec["run_is_x"]) != run_is_x:
			continue
		var a: Vector3i = rec["anchor"]
		## Same face plane as this pane, or it is another pane's hole.
		if (a.y if run_is_x else a.x) != cross:
			continue
		var a_run: int = a.x if run_is_x else a.y
		var poly: PackedVector2Array = GlassOpening.polygon(String(rec["opening"]))
		if poly.is_empty():
			continue
		## The polygon lives in (run, level) voxels around its own anchor; move it
		## into the mask's frame once, rather than per texel.
		var off := Vector2(float(a_run - c_run) - origin.x, origin.y - float(a.z - c_lvl))
		## Only this opening's own bounding box is walked — a whole-mask sweep per
		## hole would be 38 point-in-polygon tests per texel on a real pane.
		var plo := Vector2(INF, INF)
		var phi := Vector2(-INF, -INF)
		for pt in poly:
			plo = plo.min(pt)
			phi = phi.max(pt)
		var x0: int = maxi(0, int(floor((off.x + plo.x) * CRAZE_MASK_TEXELS_PER_VOXEL)))
		var x1: int = mini(w - 1, int(ceil((off.x + phi.x) * CRAZE_MASK_TEXELS_PER_VOXEL)))
		var y0: int = maxi(0, int(floor((off.y - phi.y) * CRAZE_MASK_TEXELS_PER_VOXEL)))
		var y1: int = mini(h - 1, int(ceil((off.y + -plo.y) * CRAZE_MASK_TEXELS_PER_VOXEL)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(
					(float(x) + 0.5) / float(CRAZE_MASK_TEXELS_PER_VOXEL) - off.x,
					off.y - (float(y) + 0.5) / float(CRAZE_MASK_TEXELS_PER_VOXEL))
				if Geometry2D.is_point_in_polygon(p, poly):
					img.set_pixel(x, y, Color(1.0, 0.0, 0.0))
					painted += 1
	c["craze_mask_image"] = img
	var tex = c.get("craze_mask_texture")
	if tex != null and tex is ImageTexture \
			and (tex as ImageTexture).get_size() == Vector2(float(w), float(h)):
		(tex as ImageTexture).update(img)
	else:
		tex = ImageTexture.create_from_image(img)
		c["craze_mask_texture"] = tex
	crack.set_opening(tex, origin, span)
	c["craze_mask_painted"] = painted


## ── G6 (§7.1) — SHARDS ON THE FLOOR ─────────────────────────────────────────
##
## `GlassFall` (G-D16a) has decided WHERE the glass lands since 2026-09-01 and
## nothing has drawn it: the landings are computed, logged, and thrown away.
## §7.1's own risk note is that unseen state rots, and this project has shipped
## two features that were built and never triggered. This is the consumer.
##
## ⚠️ A SPRITE, NOT A DECAL COMPOSITED INTO THE FLOOR'S ATOM — and §7.1 says the
## other thing, so the departure is argued rather than slipped in. That section
## was written 2026-08-30, before CRACK-02 (2026-09-02) ruled the same question
## for the crack and before G-D26's *moldura* lesson was generalised. Three
## reasons, and the first is the one that decides it:
##
##   1. **A pile MULTIPLIES with every other per-cell state.** Folded into the
##      atom, `ground_concrete + shards` also needs `+ dented`, `+ scorched`,
##      `+ dented + scorched`, per shard variant. A floor cell is already the most
##      heavily overloaded surface in the game. A sprite multiplies with nothing.
##   2. **Minting is charged per FRAME that mints** (the standing perf finding),
##      and a pile is not damage: it would put new alternatives on a TileSet for a
##      cosmetic overlay that changes no geometry.
##   3. **It is the CRACK-02 shape exactly.** *"No fim do dia a gente quer que os
##      voxels atrás sejam idênticos aos outros"* — the floor under a pile is
##      untouched floor, and only LEAVING the voxel says so.
##
## R3D-END (END-2): the pile was a Sprite2D on the 2D board; it is a RECORD now, drawn by `FloorPile3D` on the 3D
## board's floor (R3D-9 made the 3D board draw from the record, never from the sprite).
## Vector3i(cell, level) -> {variant, count}: what the 3D board draws from.
var _floor_shard_records: Dictionary = {}
const FloorPile3DRef = preload("res://godot/scripts/geometry/floor_pile3d.gd")
var _pile3d: RefCounted = null          ## RENDER3D — the same piles drawn on the 3D board's floor
var _floor_shard_textures: Array = []

## G6 — a pile's opacity from how many voxels landed on the cell. Director,
## 2026-09-06: *"queria deixar mais debris no lugar depois que eles sumirem. Ta
## muito vazio."* G4-4's scatter thins the per-cell count (a pane empties onto a
## band, not a line), so a formula tuned for ~24-per-cell left every scattered
## cell near-invisible. `var` (Rule 1): the Director dials this against the map.
static var FLOOR_SHARD_ALPHA_BASE: float = 0.34
static var FLOOR_SHARD_ALPHA_GAIN: float = 0.055
static var FLOOR_SHARD_ALPHA_MAX: float = 0.88
static var FLOOR_SHARD_SCALE: float = 1.18    ## decals slightly larger than the cell, so a band reads continuous


## The three shipped shard decals. ⚠️ Loaded through `load()` and CHECKED: G-ART
## delivered them and `check_decal.py` has reported "the files exist and nothing
## loads them" ever since. If one is missing that is a B6 loud failure, not a
## silently pile-less floor.
func _floor_shard_texture(variant: int) -> Texture2D:
	if _floor_shard_textures.is_empty():
		for i in range(3):
			var path := "res://ASSETS/materials/glass/decals/decal_shard_glass_%d.png" % i
			var tex := load(path) as Texture2D
			if tex == null:
				push_error("[VoxelBoard] G6: %s failed to load — no shards will draw" % path)
			_floor_shard_textures.append(tex)
	return _floor_shard_textures[variant % _floor_shard_textures.size()] as Texture2D


## Draw (or refresh) one pile. `count` is how many voxels landed here; it drives
## the pile's OPACITY, so a shattered pane reads heavier than a single round's
## worth without needing a second art axis.
func spawn_floor_shard_pile(level: int, cell: Vector2i, count: int, variant: int) -> bool:
	## Rule 9 — the level is derived by the caller and may genuinely not be built (a landing on a plane this view does
	## not build): the pile is then recorded by the room and not drawn, and the caller's own count says so. The layer
	## is asked because it is the level registry until END-4 replaces it; nothing is placed on it.
	if not _layers.has(level):
		return false
	if _floor_shard_texture(variant) == null:
		return false
	var key := Vector3i(cell.x, cell.y, level)
	## R3D-9: the pile as DATA — the 3D board draws from this.
	_floor_shard_records[key] = {"variant": variant, "count": count}
	if _pile3d != null:
		_pile3d.set_pile(key, variant, floor_shard_alpha(count))
	return true


## A pile's opacity from how many voxels landed there. One formula for both boards.
static func floor_shard_alpha(count: int) -> float:
	return clampf(FLOOR_SHARD_ALPHA_BASE + FLOOR_SHARD_ALPHA_GAIN * float(count),
		FLOOR_SHARD_ALPHA_BASE, FLOOR_SHARD_ALPHA_MAX)


## Half the decal's side on screen, in px (the decal is authored for a 32 px cell diamond). The 3D board turns it into
## a ground quad through its own screen-to-ground map.
static func floor_shard_half_px() -> float:
	return 16.0 * FLOOR_SHARD_SCALE


## RENDER3D — draw the shard piles on the 3D board. Piles that
## already exist are handed over, so a board built after a blast still shows them. `null` detaches.
func set_pile_board3d(board: Node3D) -> void:
	if _pile3d != null:
		_pile3d.detach()
		_pile3d = null
	if board == null:
		return
	var textures: Array = []
	for i in range(3):
		textures.append(_floor_shard_texture(i))
	_pile3d = FloorPile3DRef.new()
	_pile3d.attach(board, textures, 3, 0.02)
	for key in _floor_shard_records:
		var rec: Dictionary = _floor_shard_records[key]
		_pile3d.set_pile(key, int(rec["variant"]), floor_shard_alpha(int(rec["count"])))


## Drop every pile. A perspective flip rebuilds the renderer, so this is what
## keeps orphans from surviving it; the room puts them back from its base store.
func clear_floor_shards() -> void:
	_floor_shard_records.clear()
	if _pile3d != null:
		_pile3d.clear()


## How many piles are live. Diagnostics and the selftest.
func floor_shard_pile_count() -> int:
	return _floor_shard_records.size()


## How many piles the 3D board draws, or -1 when there is no 3D pile mirror. R3D-8: the mirror gate compares it with
## `floor_shard_pile_count()`.
func floor_shard_pile3d_count() -> int:
	return _pile3d.pile_count() if _pile3d != null else -1


## The opening's void as a texture, built on first use and cached. The image
## itself comes from `GlassOpening.mask_image()` — the SAME polygon the atoms are
## cut with, which is what makes the sheet's void and the hole's edge one line
## rather than two that have to be kept in agreement.
func _glass_opening_mask(opening_id: String) -> Dictionary:
	if _glass_opening_masks.has(opening_id):
		return _glass_opening_masks[opening_id]
	var m: Dictionary = GlassOpening.mask_image(opening_id)
	if m.is_empty():
		_glass_opening_masks[opening_id] = {}
		return {}
	var out := {
		"texture": ImageTexture.create_from_image(m["image"]),
		"origin": m["origin"],
		"size": m["size"],
	}
	_glass_opening_masks[opening_id] = out
	return out


## Show or hide every live crack SPRITE, for a same-boot alignment measurement.
##
## ⚠️ IT EXISTS BECAUSE THE CROSS-BOOT VERSION IS NOISE. Two boots of the GLASS
## map differ by tens of thousands of pixels before anything glass-related moves,
## so "photograph the hole in one boot and the web in another and compare
## centroids" gives a delta with no meaning — measured 2026-09-04, the same pair
## of frames put the hole's centroid 22 px apart from itself depending on which
## mask was used. Hiding the sprite inside ONE boot isolates the web exactly.
func set_glass_cracks_visible(v: bool) -> void:
	for c in _glass_cracks:
		c["visible"] = v


## CRACK-04 — bind or UNBIND every live crack's opening void, for a same-boot A/B.
##
## ⚠️ IT HAS TO BE ONE BOOT. Two boots of this map differ by tens of thousands of
## pixels before anything glass-related changes (the agent's selection marker
## alone was 27 336 px when the rim's A/B was measured), so a diff across boots
## cannot see a void two voxels wide. Unbinding sets the shader's mask back to its
## `hint_default_black` default, which reads as "no hole" — the same state a pane
## that only crazed is in, so this exercises a real code path rather than a
## capture-only one.
func set_glass_opening_void(enabled: bool) -> void:
	for c in _glass_cracks:
		var crack = c["crack"]
		if crack == null:
			continue
		var oid: String = String(c.get("opening", ""))
		if oid == "":
			continue
		if enabled:
			var m: Dictionary = _glass_opening_mask(oid)
			if not m.is_empty():
				crack.set_opening(m["texture"], m["origin"], m["size"])
		else:
			crack.set_opening(null, Vector2.ZERO, Vector2.ONE)


## CRACK-04 — how many glass cells currently hold a SHARD atom (a source the
## `_glass_source_info` inverse does not know, which is what a rim swap writes).
##
## ⚠️ IT READS THE TILEMAP, not a counter kept alongside it. `refresh_glass_rims()`
## reporting "12 cell(s) cut" says the swap was ISSUED; whether those cells still
## hold the shard after the frame settles is a different question, and the only
## instrument that can answer it is the board itself.
func count_glass_shards() -> int:
	var n: int = 0
	for key: Vector3i in _glass_shaped_cells:
		if _glass_cell_present(key.z, Vector2i(key.x, key.y)):
			n += 1
	return n


## How many crack sprites are live. Diagnostics and the selftest.
## B-2: IMPACT cracks only, so the number keeps meaning what every existing caller
## reads it as. `glass_craze_count()` answers for the fields.
## The live crack and craze records, read-only: the 3D board mirrors each one (R3D-6).
func glass_crack_records() -> Array:
	return _glass_cracks


## R3D-6 — the polygons `refresh_glass_rims()` applied, {anchor, opening, run_is_x}. Read-only view
## for the 3D board, which cuts the pane with them.
func glass_applied_openings() -> Array:
	return _glass_applied_openings


func glass_crack_count() -> int:
	var n: int = 0
	for c in _glass_cracks:
		if not bool(c.get("field", false)):
			n += 1
	return n


## G-D35 B-2 — how many blast-craze FIELDS are live.
func glass_craze_count() -> int:
	var n: int = 0
	for c in _glass_cracks:
		if bool(c.get("field", false)):
			n += 1
	return n


## Drop every crack. A perspective flip rebuilds the whole renderer, so this is what keeps stale records from surviving
## it; S-3 is what puts the cracks BACK from the room-side base-coord registry.
func clear_glass_cracks() -> void:
	_glass_cracks.clear()
	## B-4b — the applied-opening log describes THIS view's geometry, which the
	## rebuild is about to replace. `_respawn_base_openings()` refills it.
	_glass_applied_openings.clear()


## A map reload (`Room.load_map()`) rebuilds every pane intact and clears the
## base-space damage records; the shaped-cell record is keyed in view space and would otherwise mark cells of a fresh
## pane as already shaped. `_set_perspective()` rebuilds the rims from `_base_openings`; a reload has none to rebuild.
func clear_glass_rim_cells() -> void:
	_glass_shaped_cells.clear()


## ── G-D30 — THE OCCUPANCY CUT ────────────────────────────────────────────────
##
## A crack's occupancy is a small R8 image in its PANE's own (run, level) space —
## 1 where glass still stands, 0 where it is gone — and the sprite multiplies its
## alpha by it, scaled by the Director's `glass_crack_hole_cut` dial.
##
## ⚠️ IT IS READ OFF THE STORE'S GLASS STATE, NOT MAINTAINED AS A PARALLEL PLANE, and that is the whole design.
## `_glass_cell_present()` asks `VoxelStore.has_glass_pane()`, the live authority every erase seam already goes through
## (the cook's `erase_glass_cell`, and the two dirty passes). A second plane written alongside them would be a third copy of
## the same fact, free to drift; asking the store cannot drift.
##
## The rebuild is bounded by G-D23: a pane is at most 64 x 32 cells, so one crack
## costs at most 2048 cell queries and only when glass was actually erased.
const GLASS_OCC_MAX_SIDE: int = 128
## G-D30's dial. `INFILTRAITOR_GLASS_CRACK_CUT=<0..1>` overrides it for a capture,
## because the VALUE is the Director's open question and comparing two ends of it
## has to be possible without an edit. The shipped default is stated here, once.
var _glass_crack_hole_cut: float = _env_hole_cut()
var _glass_crack_occ_dirty: bool = false


static func _env_hole_cut() -> float:
	var e := OS.get_environment("INFILTRAITOR_GLASS_CRACK_CUT")
	return clampf(e.to_float(), 0.0, 1.0) if e.is_valid_float() else 1.0


## The Director's dial. Applied to every live crack and remembered for new ones.
func set_glass_crack_hole_cut(v: float) -> void:
	_glass_crack_hole_cut = clampf(v, 0.0, 1.0)
	for c in _glass_cracks:
		var crack = c["crack"]
		if crack != null:
			crack.set_hole_cut(_glass_crack_hole_cut)


func glass_crack_hole_cut() -> float:
	return _glass_crack_hole_cut


## Every glass erase seam calls this. Deliberately just a FLAG: the cook erases
## cell by cell, and rebuilding a pane's occupancy per cell would be quadratic in
## the size of the hole. The rebuild happens once at the batch's flush.
func note_glass_erased() -> void:
	if not _glass_cracks.is_empty():
		_glass_crack_occ_dirty = true


## Rebuild the occupancy of every live crack, if any glass was erased since the
## last call. Returns how many were rebuilt. Called at the four dirty-pass ends
## and from DetonationEntryWriter.flush() (the batch seams the 2D board's composite-page flush also used).
func refresh_glass_crack_occupancy() -> int:
	if not _glass_crack_occ_dirty:
		return 0
	_glass_crack_occ_dirty = false
	for c in _glass_cracks:
		_build_crack_occupancy(c)
		## B-4b — a field's hole mask changes for exactly the same reason its
		## occupancy does, so it is rebuilt on the same seam rather than on one of
		## its own that could fall out of step.
	return _glass_cracks.size()


## B-4b — rebuild every craze FIELD's hole mask. Its own seam rather than a
## passenger on the occupancy's, because the two are filled by different passes:
## the occupancy reads the tilemap (which the erase already changed) while this
## reads the applied-opening log (which only `refresh_glass_rims()` fills). Run
## together, the mask would be one flush behind, forever.
func refresh_craze_opening_masks() -> int:
	var n: int = 0
	for c in _glass_cracks:
		if bool(c.get("field", false)):
			_build_craze_opening_mask(c)
			n += 1
	return n


## One crack's occupancy image, walked over its pane's (run, level) rectangle.
## Row 0 is the HIGHEST level, so the image reads the way the pane does on screen
## and the shader's `crack_occ_origin` is (run_min, level_max).
func _build_crack_occupancy(c: Dictionary) -> void:
	var crack = c["crack"]
	if crack == null or not crack.valid:
		return
	var lo: Vector2 = c["pane_lo"]
	var hi: Vector2 = c["pane_hi"]
	var run0: int = int(c["impact_run"]) + int(roundf(lo.x))
	var lvl1: int = int(c["impact_level"]) + int(roundf(hi.y))
	var w: int = int(roundf(hi.x - lo.x)) + 1
	var h: int = int(roundf(hi.y - lo.y)) + 1
	if w < 1 or h < 1:
		return
	if w > GLASS_OCC_MAX_SIDE or h > GLASS_OCC_MAX_SIDE:
		## G-D23 caps a pane at 64 x 32; anything past this is a pane that was
		## never authored, and silently allocating for it is how a 6 MB surprise
		## gets in. Clamp and say so.
		push_warning("[VoxelBoard] G-D30: pane %s is %dx%d cells, past the %d cap — the crack's cut is clipped"
			% [c["pane_id"], w, h, GLASS_OCC_MAX_SIDE])
		w = mini(w, GLASS_OCC_MAX_SIDE)
		h = mini(h, GLASS_OCC_MAX_SIDE)
	var run_is_x: bool = int(c["run_axis"]) == 0
	var cross: Vector2i = c["impact_cell"]
	var img := Image.create(w, h, false, Image.FORMAT_R8)
	## R3D-END (END-2): the 2D render-order clip also cut away every cell a nearer wall hid on the SCREEN, from an index
	## of the opaque tile layers. The 3D board depth-tests the quad itself, and on it that index was always empty.
	var solid := Color8(255, 0, 0, 255)
	var gone := Color8(0, 0, 0, 255)
	for j in range(h):
		var level: int = lvl1 - j
		for i in range(w):
			var run: int = run0 + i
			var cell := Vector2i(run, cross.y) if run_is_x else Vector2i(cross.x, run)
			img.set_pixel(i, j, solid if _glass_cell_present(level, cell) else gone)   ## R3D-14: the store's glass panes
	var tex = c.get("occ_texture")
	if tex != null and tex is ImageTexture \
			and (tex as ImageTexture).get_size() == Vector2(float(w), float(h)):
		(tex as ImageTexture).update(img)
	else:
		tex = ImageTexture.create_from_image(img)
		c["occ_texture"] = tex
	## The CPU-side copy, kept because it is the authority: `get_image()` on an
	## ImageTexture is a readback through the RenderingServer and does not have to
	## reflect an `update()` yet — a diagnostic that asked the texture would read
	## the crack's occupancy one event stale and say the cut had not followed.
	c["occ_image"] = img
	crack.set_occupancy(tex, Vector2(float(w), float(h)),
		Vector2(lo.x, hi.y))


## ── CRACK-03 — APPLYING THE RIM ──────────────────────────────────────────────
##
## Every glass erase records its cell here; `refresh_glass_rims()` runs at the
## same five batch seams the crack occupancy uses and re-cuts the neighbours.
##
## R3D-END (END-2): it was a SWAP on the glass tilemap (a shard atom placed over the pane cell). What is left is the
## state the 3D board draws from: which pane cells an opening shaped (`_glass_shaped_cells`) and the polygons applied.
func note_glass_erased_for_rim(level: int, cell: Vector2i) -> void:
	if not _glass_rim_dirty.has(level):
		_glass_rim_dirty[level] = []
	(_glass_rim_dirty[level] as Array).append(cell)


## Is there still glass drawn at this (level, cell)? The live authority, the same
## one G-D30's occupancy reads.
func _glass_cell_present(level: int, cell: Vector2i) -> bool:
	return VoxelStore.active != null and VoxelStore.active.has_glass_pane(cell.x, cell.y, level)


## Apply an OPENING around every hole made since the last call. Returns how many
## cells were cut into shards.
##
## ⚠️ THE OPENING IS THE SHAPE OF THE WHOLE HOLE, NOT A PER-CELL RULE (G-D34).
## CRACK-03 walked the four orthogonal neighbours and gave each a wedge aimed at
## the hole; the silhouette that produced was a side effect nobody could name. A
## batch's erased cells are grouped into CONNECTED REGIONS instead, each region
## gets one opening sized to it, and the polygon decides which cells it erases
## outright and which it merely intrudes on. That is what makes a bigger hole a
## bigger polygon rather than a different mechanism — the Director's *"buracos de
## tiros maiores vão precisar de mais estados de voxels intermediários"*.
##
## ⚠️ THE PICK IS THE CALLER'S WHEN THE CALLER KNOWS BASE COORDINATES. A region
## whose opening was chosen by `apply_glass_opening()` keeps that choice; only a
## region that arrives unclaimed falls back to `GLASS_OPENING_DEFAULT`, and that
## is a capture dial, not a play-path answer — a view-space pick would reshape a
## standing hole on every camera turn, which is the failure S-3 exists to prevent.
func refresh_glass_rims() -> int:
	## R3D-END (END-2): the re-stamp of shard atoms a later render pass overwrote, and the Option A mirror queue, were
	## the 2D board's; nothing re-renders over a shaped cell on the 3D board.
	if _glass_rim_dirty.is_empty():
		return 0
	if not GLASS_RIM_ENABLED:
		_glass_rim_dirty.clear()
		return 0

	var regions: Array = _group_erased_into_regions()
	_glass_rim_dirty.clear()

	var swapped: int = 0
	## ⚠️ THE LINE NAMES THE OPENING PER REGION, and it has to. A count alone
	## cannot tell a real pick from `GLASS_OPENING_DEFAULT` — a hole that silently
	## fell through to the default looks exactly like one that was claimed, and the
	## whole point of the claim is that the SHAPE is chosen. `*` marks a region
	## nobody claimed.
	var applied: Array = []
	for region in regions:
		swapped += _apply_opening_to_region(region)
		applied.append("%s%s" % [
			region["opening"] if String(region["opening"]) != "" else GLASS_OPENING_DEFAULT,
			"" if String(region["opening"]) != "" else "*"])
	if swapped > 0:
		print_debug("[GLASS-OPENING] %d region(s) [%s], %d cell(s) cut into shards"
			% [regions.size(), ", ".join(applied), swapped])
	return swapped


## Turn the batch's erased cells into regions to apply an opening around.
##
## ⚠️ A CLAIM DEFINES ITS REGION; CONNECTIVITY IS ONLY THE FALLBACK. The first
## version grouped every erased cell by adjacency and then looked for a claim
## inside each group, and it had a defect that no symmetric opening could show:
## `chunk_bite` swallows cells (0,0) and (1,1) WHOLE, and those touch only
## DIAGONALLY. Under 6-connectivity they were two regions — the claimed one, and
## an orphan that fell through to `GLASS_OPENING_DEFAULT` and stamped a second
## `star_deep` centred one cell over, three cells outside the real opening's own
## bounds. Selftest [15] caught it as "(3,1) cut", a shard outside the footprint.
##
## So a claim comes first and takes every erased cell inside its opening's
## footprint. Only what no claim wanted is grouped, and that grouping is
## 26-connected (diagonals included) because a hole's cells are one hole however
## they touch.
func _group_erased_into_regions() -> Array:
	var all: Dictionary = {}
	for level in _glass_rim_dirty:
		for cell in _glass_rim_dirty[level]:
			all[Vector3i(cell.x, cell.y, level)] = true

	var regions: Array = []

	## 1. Every claim is a region, anchored where the claimer said the impact was.
	for anchor in _glass_region_openings:
		var opening_id: String = String(_glass_region_openings[anchor])
		var bounds: Rect2i = GlassOpening.cell_bounds(opening_id)
		var members: Array = []
		for k in all.keys():
			## Both run axes are offered — the erased cell's own face went with
			## its source, and a cell that is not in this pane simply will not be
			## glass when the walk gets there.
			var in_x: bool = absi(k.x - anchor.x) <= bounds.size.x and k.y == anchor.y
			var in_y: bool = absi(k.y - anchor.y) <= bounds.size.x and k.x == anchor.x
			if (in_x or in_y) and absi(k.z - anchor.z) <= bounds.size.y:
				members.append(k)
				all.erase(k)
		regions.append({"members": members, "anchor": anchor, "opening": opening_id})

	## 2. Whatever no claim wanted, grouped by adjacency and given a default.
	var seen: Dictionary = {}
	for key in all:
		if seen.has(key):
			continue
		var members: Array = []
		var queue: Array = [key]
		seen[key] = true
		while not queue.is_empty():
			var k: Vector3i = queue.pop_back()
			members.append(k)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if dx == 0 and dy == 0 and dz == 0:
							continue
						var nk: Vector3i = k + Vector3i(dx, dy, dz)
						if all.has(nk) and not seen.has(nk):
							seen[nk] = true
							queue.append(nk)
		regions.append({
			"members": members,
			## The centroid is the stand-in for an impact nobody named, and it is
			## only ever right for a SYMMETRIC opening — an asymmetric one puts its
			## centroid out in the chunk it removed. That is why the play path must
			## claim rather than lean on this.
			"anchor": _region_anchor(members),
			"opening": "",
		})
	_glass_region_openings.clear()
	return regions


## A region's anchor cell — the rounded centroid of its members. The opening is
## centred here, so it has to be derived the SAME way by whoever pre-picked the
## opening and by this walk, or the two disagree about where the hole is.
func _region_anchor(members: Array) -> Vector3i:
	var sx: int = 0
	var sy: int = 0
	var sz: int = 0
	for m in members:
		sx += m.x
		sy += m.y
		sz += m.z
	var n: int = maxi(members.size(), 1)
	return Vector3i(int(round(float(sx) / float(n))), int(round(float(sy) / float(n))),
		int(round(float(sz) / float(n))))


## Cut every cell the region's opening crosses, and erase every cell it swallows.
func _apply_opening_to_region(region: Dictionary) -> int:
	var anchor: Vector3i = region["anchor"]
	var members: Array = region["members"]
	var opening_id: String = String(region["opening"])
	if opening_id == "":
		## Sized from the region's own extent: a one-cell pierce takes a small
		## opening, a breach several cells across takes a large one. The pick is
		## the DEFAULT only because nobody upstream claimed this region.
		opening_id = GLASS_OPENING_DEFAULT if members.size() <= 2 else "star_deep_wide"
	var bounds: Rect2i = GlassOpening.cell_bounds(opening_id)
	if bounds.size == Vector2i.ZERO:
		return 0

	## The run axis comes from the face of a cell the opening actually touches —
	## asked once per region rather than per cell, since a pane has one face.
	var face: int = -1
	var swapped: int = 0
	var unswallowed: int = 0
	for dl in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for dr in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cover: int = GlassOpening.coverage(opening_id, dr, dl)
			if cover == GlassOpening.Coverage.NONE:
				continue
			## Both run axes are offered; the one that is not this pane's simply
			## has no glass at the cell it names.
			for run_is_x in [true, false]:
				var cell := Vector2i(anchor.x + dr, anchor.y) if run_is_x \
					else Vector2i(anchor.x, anchor.y + dr)
				var level: int = anchor.z + dl
				## R3D-14: the pane's face and presence come from the claims; nothing is swapped (no rim atom), and
				## "already a shard" is the shaped-cell record.
				var pane_face: int = VoxelStore.active.glass_pane_face_at(cell.x, cell.y, level) \
					if VoxelStore.active != null else 0
				var skey := Vector3i(cell.x, cell.y, level)
				if pane_face == 0 or _glass_shaped_cells.has(skey):
					continue
				var sface: int = pane_face - 1
				if (sface == Face.SW or sface == Face.NE) != run_is_x:
					continue
				face = sface
				if cover == GlassOpening.Coverage.FULL:
					## ⚠️ THE RENDERER DOES NOT ERASE: destruction is the one authority on which voxels exist. A cell the
					## opening swallows whole should already be gone, so reaching this means the opening is BIGGER than
					## the hole destruction made — a wiring error, reported below rather than quietly patched.
					unswallowed += 1
					continue
				_glass_shaped_cells[skey] = true
				swapped += 1
	if unswallowed > 0:
		push_warning("[VoxelBoard] opening '%s' at %s covers %d cell(s) whole that still hold glass — the opening is larger than the hole destruction opened"
			% [opening_id, str(anchor), unswallowed])
	## ── G-D35 B-4b — REMEMBER THE POLYGON, NOT JUST ITS EFFECT ───────────────
	##
	## (Director, 2026-09-05: *"reaproveitamos o formato das aberturas
	## intersectando com a malha rachada, mas sem o decal radial em volta."*)
	##
	## The cells above are already shaped. What is NOT recoverable from them is the
	## polygon's SUB-CELL edge, and that is exactly what the craze field has to be
	## cut by: G-D30's occupancy is one texel per CELL, so a cell holding a shard
	## reads "glass present" and the mesh paints straight over the part the opening
	## took away. The shader has carried a sub-cell `crack_opening` mask since
	## CRACK-04 and no field has ever bound one.
	##
	## ⚠️ Recorded even when `swapped` is 0. A hole whose rim was already cut by a
	## neighbour swaps nothing and its polygon still has to cut the mesh.
	if face != -1:
		_glass_applied_openings.append({
			"anchor": anchor, "opening": opening_id,
			"run_is_x": (face == Face.SW or face == Face.NE)})
	return swapped


## Stamp one remnant onto its cell. Returns true when the board actually changed.## Stamp one remnant onto its cell. Returns true when the board actually changed.
##
## ⚠️ APPLIED, NEVER "CLAIMED" — and the difference is the one CRACK-04 measured.
## A claim works when an ERASE is about to flag the cell; a remnant erases nothing
## (the voxel survives), so there is no flag, no batch, and a claim would sit in a
## dictionary nothing ever reads. The rebuild path has exactly the same shape,
## which is why one function serves both the live break and the perspective flip.
func apply_glass_remnant_at(level: int, cell: Vector2i, shape_id: String,
		anchor_mask: int, _flop: bool) -> bool:
	if not GLASS_RIM_ENABLED or shape_id == "" or anchor_mask == 0:
		return false
	## R3D-14: the remnant's state is "this pane cell is spared and shaped"; the cut atom was 2D drawing.
	var rkey := Vector3i(cell.x, cell.y, level)
	if not _glass_cell_present(level, cell) or _glass_shaped_cells.has(rkey):
		return false
	_glass_shaped_cells[rkey] = true
	return true


## CRACK-04 — claim a region's opening BEFORE the erase batch is flushed. Called
## by whoever knows base coordinates (the room / the shot path), so the pick is
## stable across a perspective flip. `cell`/`level` is the IMPACT.
func claim_glass_opening(level: int, cell: Vector2i, opening_id: String) -> void:
	_glass_region_openings[Vector3i(cell.x, cell.y, level)] = opening_id


## CRACK-04 — apply one opening at a known impact IMMEDIATELY, without going
## through the erase-flag batch.
##
## ⚠️ THE REBUILD NEEDS THIS AND THE SHOT PATH MUST NOT USE IT, because the two
## situations differ in a way that is invisible until measured. On a live shot the
## glass is removed by `erase_cell()`, which flags the rim and the batch flush cuts
## it. On a REBUILD (a perspective flip, a load) nothing is erased at all: the
## geometry is built fresh from voxel state, and a voxel already DESTROYED is
## simply never PLACED — so there is no erase, no flag, and the flush runs with
## `dirty_levels=0`. Measured 2026-09-04 on the GLASS map: after a flip the rim
## was never re-cut, which means **CRACK-03's rim never survived a rotation
## either**. Claiming an opening for that path is useless; it has to be applied.
func apply_glass_opening_at(level: int, cell: Vector2i, opening_id: String) -> int:
	if not GLASS_RIM_ENABLED or opening_id == "":
		return 0
	var anchor := Vector3i(cell.x, cell.y, level)
	return _apply_opening_to_region({
		"members": [anchor], "anchor": anchor, "opening": opening_id,
	})


## PERF-DEV — `DevFlags` when the autoload is reachable, the environment otherwise
## (`godot --script` contexts), the same resolution as `Room._dev_flag()`. Every
## read below used `OS.get_environment` directly, which never reaches an APK.
func _dev_flag(flag_name: String) -> String:
	if is_inside_tree():
		var flags: Node = get_node_or_null("/root/DevFlags")
		if flags != null:
			return flags.value(flag_name, "")
	return OS.get_environment("INFILTRAITOR_" + flag_name)


## LEVEL-RENUMBER — `storey_count` is a COUNT of wall levels, kept as such because
## every caller computes it from `storey_count * LEVELS_PER_STOREY`. It ensures the
## contiguous run from the ground plane upward; `_ensure_level()` is the per-level
## form the sparse floor levels need.
func _ensure_wall_levels(storey_count: int) -> void:
	for i in range(storey_count):
		_ensure_level(_ground_plane_level + i)


## D17/D18: negative levels are never contiguous-from-zero and rarely all
## exist at once — callers ensure exactly the one level they need (the top
## destructible floor level, always; deeper fixed/cosmetic levels only once
## something has actually dug down to them). No "ensure up to N" variant on
## purpose: that shape would invite building a contiguous run nobody asked
## for, which is precisely what D18 forbids.
func _ensure_floor_level(level: int) -> void:
	if level >= _ground_plane_level:
		push_error("VoxelBoard._ensure_floor_level: level %d is not below the ground plane (%d)"
			% [level, _ground_plane_level])
		return
	_ensure_level(level)


## LEVEL-RENUMBER — the one creation seam. Idempotent, and sparse by construction:
## D18's lazy reveal means a level exists only once something has built it, which
## a Dictionary expresses directly where an Array had to be grown contiguously.
func _ensure_level(level: int) -> void:
	if _layers.has(level):
		return
	_layers[level] = true
	## The level's cell plane, made when the level is (the 3D board reads planes by level and the probe dumps count them).
	_cell_planes.ensure_level(level)


## GLASS G3 — the cook's erase of one glass pane cell. The glass state is the store's (R3D-14), so there is nothing to erase
## here: what remains is the light and glass bookkeeping the erase owed (the crack's occupancy re-cut, the rim's opening
## batch). Returns true.
## `glass_cell_present()` below asks the store whether a pane cell is still standing: the instrument for "a voxel is DESTROYED
## in the data and still on screen" (the G-D48 render gap).
func glass_cell_present(level: int, cell: Vector2i) -> bool:
	return _glass_cell_present(level, cell)


func erase_glass_cell(level: int, cell: Vector2i) -> bool:
	## R3D-14: no layer to erase; the light and glass seams the erase owed are all that is left of it.
	note_external_write(level, cell)
	note_glass_erased()   ## G-D30, seam 3 of 3 (the cook)
	note_glass_erased_for_rim(level, cell)   ## CRACK-03
	return true


## DESTRUCTION D1/D2/D4 — register one Slab's level. Each Slab's voxels share `slab.level` (SlabGenerator.generate()'s
## invariant), so one level is ensured, not a scan.
## R3D-END: nothing is drawn (the 3D board meshes the store). `apply == false` is the exposure plan's seam
## (EXPLOSION_REBUILD_MASTER_PLAN Task 4/E-PLAN: destroying a voxel exposes geometry behind it): it returns one entry per
## currently visible voxel (`grid_pos`, `level`, and the tile-less placeholder ids) and is empty when `apply` is true.
func register_slab(slab: Slab, apply: bool = true) -> Array:
	var resolved: Array = []
	if slab.voxels.is_empty():
		return resolved
	## The level always exists afterwards, whatever `apply` says: the exposure plan and the readers of `level_origin()` ask for it.
	_ensure_level(slab.level)
	## R3D-END: nothing is placed (the 3D board draws the store). The exposure plan (`apply == false`) needs WHICH
	## cells a slab shows, not which tile draws each.
	if apply:
		return resolved
	for voxel in slab.voxels:
		if voxel.visible:
			resolved.append({"grid_pos": voxel.grid_pos, "level": voxel.level,
				"source_id": -1, "atlas_coords": Vector2i.ZERO, "alternative_id": 0})
	return resolved


## FLOOR-DEPTH-01 — put a deferred-render floor plane on screen.
##
## The deep floor Slab (GeometryCoords.FLOOR_DEEP_LEVEL) is generated at build but
## never rendered there: it is fully occluded by the plane above it, so its cells
## would cost tilemap memory and full-repaint time to draw nothing. This is the
## seam that pays that cost only once the plane above has actually opened — from
## the blast path, and again from the post-rotation damage replay.
##
## Idempotent by construction (register_slab skips destroyed voxels): calling it on
## an already-revealed, already-cratered plane re-places exactly the cells that
## are still there and leaves the holes alone.
func reveal_floor_slab(slab: Slab, apply: bool = true) -> Array:
	return register_slab(slab, apply)


## DESTRUCTION — render one Slab's voxels using a single FIXED material for
## every voxel, no per-voxel hash. Sibling to register_slab() (the earth/floor
## path, which selects a variant per voxel) — kept separate rather than
## branching one function on material type, since the two have genuinely
## different per-voxel logic. For roof/ceiling Slabs (Slab.Role.CEILING):
## these reuse an EXISTING wall material 1:1 (concrete/metal/stone/wood),
## matching whatever structure they sit above, the same way register_block_levels()
## already places one fixed material across a whole block — just through the
## Slab/Voxel container so every level is independently dirty-tracked
## (unlike a wall block, and unlike the floor's fixed-bedrock levels).
func register_slab_solid(slab: Slab) -> void:
	if slab.voxels.is_empty():
		return
	_ensure_level(slab.level)

	## R3D-END: nothing is placed; the 3D board draws the store.


## DESTRUCTION D13/D18 — register one FIXED floor level for one GU: no `Slab`, no `Voxel`, no dirty-tracking at all. D13's 7
## non-destructible levels beneath the one real (Slab) destructible top can never be dirty because they never go through
## `Voxel`. D18: called once per level, on demand — never loops over a range itself; nothing here assumes or builds a
## contiguous stack.
## R3D-END: nothing is drawn (the 3D board meshes the store). `apply == false` is the exposure plan's seam
## (`DetonationPlanBuilder`'s "no real Slab below" case): it returns one entry per cell the level shows, with no tile,
## and is empty when `apply` is true.
func register_fixed_level(gu_cell: Vector2i, level: int, apply: bool = true) -> Array:
	var resolved: Array = []
	## The level always exists afterwards (see `register_slab()`).
	_ensure_level(level)
	## R3D-END: nothing is placed. The exposure plan (`apply == false`) needs the cells the level shows.
	if apply:
		return resolved
	for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
		resolved.append({"grid_pos": voxel_pos, "level": level,
			"source_id": -1, "atlas_coords": Vector2i.ZERO, "alternative_id": 0})
	return resolved


## Render a VoxelProp's footprint as a full solid fill (v1: whole-storey granularity only;
## sub-storey/partial-layer rendering is deferred to the destruction phase — see PROP-01 Item 0-A).
func register_prop(gu_cell: Vector2i, start_storey: int, prop_def) -> void:
	var material_name: String = prop_def.material_zones.get("default", "concrete")
	for footprint_offset in prop_def.footprint_gus:
		register_block_levels(gu_cell + footprint_offset, start_storey, prop_def.storeys, material_name)


## Clear all layers and voxels
func clear() -> void:
	## VL-03: same reasoning — the GU index would point at cells this cleared
	## tilemap no longer has. apply_light_field() rebuilds it from scratch on the
	## next full pass, which always follows clear()+register_geometry() in the rebuild flow.
	_placed_by_gu.clear()
	## RENDER3D R3D-3 step 5 — same reasoning again: a rebuild means every voxel is
	## about to become INTACT and undirtied from scratch, so no erasure this
	## renderer told anyone about is still true.
	_render3d_gone_cells.clear()
	_render3d_gone_glass.clear()
	_glass_shaped_cells.clear()


func _to_string() -> String:
	return "VoxelBoard{layers=%d, negative_layers=%d}" % [
		wall_level_keys().size(), _layers.size() - wall_level_keys().size()
	]
