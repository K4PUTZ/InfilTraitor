## SlotDef — a SLOT: the visual container a prop model has to fit (`ACTOR` D66, PROP_PIPELINE_PLAN §1).
##
## A model does not define gameplay, a slot does: the footprint, the box it may fill, the cover it gives, how it breaks (its mesh tier),
## the budgets it must respect and which kinds of material it may be made of. Any number of models fill one slot (`PropDef.slot`); a
## map may place "the slot" (the registry picks a model) or one model by id. `props/slots/<id>.json`, two tiers like every registry.
class_name SlotDef

var id: String = ""
var footprint_gus: Array[Vector2i] = [Vector2i.ZERO]
## The box (world units, 1.0 = 1 GU) a model's fitted size may not exceed.
var max_size: Vector3 = Vector3.ONE
## 3 = cosmetic only (soot, never breaks), 4 = shatters into voxels on a blast; 0 = a voxel container (not a mesh slot).
var mesh_tier: int = 4
var gameplay: Dictionary = {"cover": "none", "destructible": false}
## The model the slot uses when a placement names only the slot (a `PropDef` id).
var default_model: String = ""
## The material the slot's GENERIC (a plain box of `max_size`) is made of.
var generic_material: String = "generic"
var max_triangles: int = 4000
var max_surfaces: int = 4
## Voxel-model slots (mesh_tier 0): the store claims a model may take (its hollow shell) and the materials it may use (each extra one is an
## extra draw on a chunk).
var max_claims: int = 1500
var max_materials: int = 4
## Material FAMILIES a model of this slot may use (empty = any). A surface mapped outside them makes the model invalid.
var allowed_families: Array[String] = []


static func from_json(data: Dictionary) -> SlotDef:
	var slot := SlotDef.new()
	slot.id = String(data.get("id", ""))
	slot.footprint_gus = []
	for fp in data.get("footprint_gus", [[0, 0]]):
		slot.footprint_gus.append(Vector2i(int(fp[0]), int(fp[1])))
	var ms = data.get("max_size", [1.0, 1.0, 1.0])
	slot.max_size = Vector3(float(ms[0]), float(ms[1]), float(ms[2]))
	slot.mesh_tier = int(data.get("mesh_tier", 4))
	slot.gameplay = data.get("gameplay", {"cover": "none", "destructible": false})
	slot.default_model = String(data.get("default_model", ""))
	slot.generic_material = String(data.get("generic_material", "generic"))
	var budget: Dictionary = data.get("budget", {})
	slot.max_triangles = int(budget.get("max_triangles", 4000))
	slot.max_surfaces = int(budget.get("max_surfaces", 4))
	slot.max_claims = int(budget.get("max_claims", 1500))
	slot.max_materials = int(budget.get("max_materials", 4))
	slot.allowed_families = []
	for f in data.get("allowed_families", []):
		slot.allowed_families.append(String(f))
	return slot
