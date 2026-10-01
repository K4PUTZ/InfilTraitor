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
## Optional real model (a glTF/GLB under res://ASSETS/props/). Empty = the placeholder box. The model is turned by
## `model_rotation_deg` (degrees, Godot axes), then scaled UNIFORMLY to fit inside `mesh_size` and stood on its base,
## so `mesh_size` should be the model's own proportions at the size it is meant to have (it is what the throw arc, the
## pick and the shatter read). Each surface keeps the colour/texture the model was authored with.
var model_path: String = ""
## The SLOT this prop is a model of (`props/slots/<id>.json`, `SlotDef`); empty = a legacy prop with no slot (the voxel crates).
var slot: String = ""
## A MagicaVoxel `.vox` model (res:// or user://): makes this a destructible VOXEL prop (mesh_tier 0). `vox_scale`: board voxels per
## source voxel (1 = the source voxel is the board voxel). `vox_materials`: palette index (string) -> registry material id; an index
## without an entry takes the nearest registry colour. See `PropVoxLibrary`.
var vox_model: String = ""
var vox_scale: int = 1
var vox_materials: Dictionary = {}
## A model's surfaces (by the name of the material they were authored with) -> a material id from OUR registry: the colour and the
## detail of a prop come from the material, never from the model (`ACTOR` D66). A surface not named here takes
## `material_zones["default"]`; a material id the registry does not have resolves through its fallback chain.
var surface_materials: Dictionary = {}
var model_rotation_deg: Vector3 = Vector3.ZERO
## Tier 4 only: the lattice its fragments fall on is the board's voxel divided by this (1, 2 or 4). 0 = automatic: the finest one that
## keeps the prop within `PropVoxelizer.FRAGMENT_BUDGET` fragments. A destroyed prop need not obey the world's voxel size.
var fragment_division: int = 0
## Native voxel props only: 0 = solid fill; N > 0 = a hollow box with an N-voxel shell (a crate is a container, not a
## block of wood). The interior is simply no voxels — what it CONTAINS is a later, separate thing.
var hollow_shell: int = 0


## Factory: parse PropDef from a JSON dict (file format).
static func from_json(data: Dictionary) -> PropDef:
	var def := PropDef.new()
	def.id = String(data.get("id", ""))
	
	var sv = data.get("size_vox", [8, 8, 8])
	def.size_vox = Vector3i(int(sv[0]), int(sv[1]), int(sv[2]))
	
	def.layers = data.get("layers", [])
	def.hollow_shell = int(data.get("hollow_shell", 0))
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
	def.model_path = String(data.get("model", ""))
	def.slot = String(data.get("slot", ""))
	def.vox_model = String(data.get("vox_model", ""))
	def.vox_scale = int(data.get("vox_scale", 1))
	def.vox_materials = data.get("vox_materials", {})
	def.surface_materials = data.get("surface_materials", {})
	def.fragment_division = int(data.get("fragment_division", 0))
	var mr = data.get("model_rotation_deg", [0.0, 0.0, 0.0])
	def.model_rotation_deg = Vector3(float(mr[0]), float(mr[1]), float(mr[2]))

	return def
