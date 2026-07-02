## Geometry Module — High Wall Group: bake-time grouping container
## Port from world/high_wall.gd into module namespace as HighWallGroup
## VOXEL-08: maximal-run regrouping strategy is deferred
class_name HighWallGroup

var id: String                          ## unique identifier
var edge_ids: Array[String] = []        ## edges in this group
var slice_ids: Array[String] = []       ## all slices (both sides of all edges)
var junction_columns: Array = []        ## JunctionResolver.JunctionColumn objects
var bake_texture: Texture2D             ## assigned by BakeSystem (VOXEL-08)
var baked: bool = false                 ## texture ready for render
var dirty_count: int = 0                ## sum of slice dirty counts
var voxel_bounds: Rect2i                ## bounding box in voxel space


func _init(p_id: String):
	id = p_id


## Add an edge and its 2 slices to this group
func add_edge_with_slices(edge: Edge, slice_a: Slice, slice_b: Slice) -> void:
	if edge.id not in edge_ids:
		edge_ids.append(edge.id)
	
	if slice_a and slice_a.id not in slice_ids:
		slice_ids.append(slice_a.id)
	
	if slice_b and slice_b.id not in slice_ids:
		slice_ids.append(slice_b.id)


## Add junction columns to this group
func add_junction_columns(columns: Array) -> void:
	junction_columns.append_array(columns)


## Total voxel count (from slices)
func total_voxel_count() -> int:
	var count := 0
	for slice_id in slice_ids:
		# Note: in practice, slices would be fetched from registry
		# This is a placeholder for the interface
		pass
	return count


## Mark all slices in this group as dirty
func mark_all_dirty() -> void:
	dirty_count = 0
	for slice_id in slice_ids:
		# Would increment dirty_count for each dirty slice
		pass


## Decrement dirty counter
func decrement_dirty() -> void:
	if dirty_count > 0:
		dirty_count -= 1


## Clear dirty state
func clear_dirty() -> void:
	dirty_count = 0


func _to_string() -> String:
	return "HighWallGroup{id='%s', edges=%d, slices=%d, junctions=%d}" % [
		id, edge_ids.size(), slice_ids.size(), junction_columns.size()
	]
