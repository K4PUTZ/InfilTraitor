## Geometry Module — Slice: wall segment on one face of one Gameplay Unit
## Identity reform: B-side slice carries gu_b, not gu_a
## Port from wall_slice.gd
class_name Slice

var id: String                   ## canonical: "SLICE_%d_%d_%s" % [gu_cell.x, gu_cell.y, Face.to_string_name(face)]
var gu_cell: Vector2i            ## the GU that owns this slice (for B-side, this is gu_b)
var face: int                    ## which face of the GU (NW, NE, SE, SW)
var edge_id: String              ## backref to parent edge
var storey_count: int            ## number of vertical levels
var start_storey: int            ## starting storey level (0 for walls, >0 for blocks with lower gaps)
var material: String             ## material type
var facade_id: String = ""       ## facade id for baking (NEW: FIX-BAKE-05)
var voxels: Array[Voxel] = []    ## all voxels in this slice (64 per storey)
var dirty_count: int = 0         ## sum of child Voxel dirty flags
var baked: bool = false          ## texture assigned by BakeSystem (VOXEL-08)
var bake_texture: Texture2D      ## reserved for VOXEL-08
## GLASS G2 (GLASS_MASTER_PLAN §4) — the whole continuous glass surface this
## slice belongs to. Blank for every non-glass slice; stamped at map load by
## `GlassPaneGrouper.assign()`. The cascade (G3) reads it to take a whole pane
## from one hit.
var pane_id: String = ""

## GLASS G-D9 (GLASS_MASTER_PLAN §9) — MULTI-MATERIAL SLICES. A sparse per-level
## override on `material`, `{rel_level: int -> material: String}`, copied verbatim
## from the parent Edge at generation time. `rel_level` is 0-based from this
## slice's own bottom (0 … storey_count*8 − 1). Empty for every ordinary wall.
var material_bands: Dictionary = {}

## GLASS G-D16 / V-D — the map's PER-PLACEMENT behaviour class for this glass
## panel, or `GlassMaterials.CLASS_UNSET` when the map said nothing and the
## material's own default applies. G-D16 makes a `glass_screen_*` either a
## control interface (INDESTRUCTIBLE) or a TV / news panel (BREAKABLE)
## *per placement*, which is a property of where the pane was PUT, not of what
## it is made of — so it rides the placement all the way from `panels[].glass_class`.
var glass_class: int = GlassMaterials.CLASS_UNSET


func has_material_bands() -> bool:
	return not material_bands.is_empty()


## The material at one slice-relative level; falls back to the base `material` for
## any level no band covers. `rel_level` = voxel.level − storey_level_base(start_storey).
func material_at(rel_level: int) -> String:
	return material_bands.get(rel_level, material)


func _init(p_id: String, p_gu_cell: Vector2i, p_face: int, p_edge_id: String,
		   p_storey_count: int, p_material: String = "concrete", p_start_storey: int = 0):
	id = p_id
	gu_cell = p_gu_cell
	face = p_face
	edge_id = p_edge_id
	storey_count = p_storey_count
	start_storey = p_start_storey
	material = p_material


## Get voxel by index; returns null if out of bounds
func get_voxel(index: int) -> Voxel:
	if index < 0 or index >= voxels.size():
		return null
	return voxels[index]


## Total voxel count (storey_count × 8 positions per face)
func total_voxel_count() -> int:
	return voxels.size()


## Mark all voxels dirty and update counter
func mark_all_dirty() -> void:
	for voxel in voxels:
		if not voxel.dirty:
			voxel.dirty = true
			dirty_count += 1


## Called by child Voxel when it becomes dirty
func increment_dirty() -> void:
	dirty_count += 1


## Called by child Voxel when it clears dirty
func decrement_dirty() -> void:
	if dirty_count > 0:
		dirty_count -= 1


## Recursively clear all Voxel.dirty flags (TIC entry point from registry)
func clear_all_dirty() -> void:
	for voxel in voxels:
		if voxel.dirty:
			voxel.dirty = false
	dirty_count = 0


func _to_string() -> String:
	return "Slice{id='%s', gu=%s, face=%s, storeys=%d, voxel_count=%d, dirty=%d}" % [
		id, gu_cell, Face.to_string_name(face), storey_count, voxels.size(), dirty_count
	]
