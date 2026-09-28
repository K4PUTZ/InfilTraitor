## PropDef — Prop definition resource
## Describes a voxel prop (crate, pillar, container, etc.)
## Schema mirrors the file format and supports future destruction phase per-voxel granularity.

class_name PropDef

var id: String
var size_vox: Vector3i                      # authoring-forward; not consumed by v1 renderer
var layers: Array                           # authoring-forward; not consumed by v1 renderer
var material_zones: Dictionary              # {"default": "wood", ...}
var footprint_gus: Array[Vector2i]          # GU cells (relative to placement anchor) this prop occupies
var storeys: int = 1                        # how many storeys tall the *rendered* solid is
var gameplay: Dictionary                    # {"cover": "full"|"half"|"quarter"|"none", "destructible": bool}
var tags: Array[String]                     # Array[String] — classification tags

## R3D-PROPS Tier 3/4: 0 means "native voxel" (the size_vox/layers path above, unchanged).
## 3 or 4 means this def places a MeshPropInstance instead (VoxelBoard.register_mesh_prop(),
## never register_prop() — see RoomBuilder._register_voxel_prop_levels()'s branch).
var mesh_tier: int = 0
var mesh_size: Vector3 = Vector3.ONE        # world units (1.0 = 1 GU); mesh_tier > 0 only


## Factory: parse PropDef from a JSON dict (file format).
static func from_json(data: Dictionary) -> PropDef:
	var def := PropDef.new()
	def.id = String(data.get("id", ""))
	
	var sv = data.get("size_vox", [8, 8, 8])
	def.size_vox = Vector3i(int(sv[0]), int(sv[1]), int(sv[2]))
	
	def.layers = data.get("layers", [])
	def.material_zones = data.get("material_zones", {"default": "concrete"})
	
	def.footprint_gus = []
	for fp in data.get("footprint_gus", [[0, 0]]):
		def.footprint_gus.append(Vector2i(int(fp[0]), int(fp[1])))
	
	def.storeys = int(data.get("storeys", 1))
	def.gameplay = data.get("gameplay", {"cover": "none", "destructible": false})
	
	def.tags = []
	for tag in data.get("tags", []):
		def.tags.append(String(tag))

	def.mesh_tier = int(data.get("mesh_tier", 0))
	var ms = data.get("mesh_size", [1.0, 1.0, 1.0])
	def.mesh_size = Vector3(float(ms[0]), float(ms[1]), float(ms[2]))

	return def
