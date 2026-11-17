## AttachmentDef — an item mounted ON a weapon (`attachments/<id>.json`). MOVEMENT §11.6 step 2, Director 2026-11-17: the
## suppressor is an accessory of its own ("acessório montável"), fitted only to the bullet pistols of the H1 family.
##
## `kind` names where it goes ("muzzle": on the barrel's end); `fits` the weapon rows that take it; `gameplay` what it changes
## (GAMEPLAY-01 sets the numbers; the noise pipeline is unbuilt). Its model is placed by `mount`: the model's frame in the
## REFERENCE weapon's frame (`mount.on`, the H1 pistol) taken at that weapon's muzzle, read off the Director's lab file
## (`family_lab.py readback`); on another weapon of the family it sits on THAT weapon's muzzle, in that weapon's units
## (`mount_on`). `muzzle` is where a round now leaves: a point of the attachment's own model.
class_name AttachmentDef

const JsonFileRef = preload("res://godot/scripts/systems/json_file.gd")

var id: String = ""
var kind: String = ""
var fits: PackedStringArray = []
var gameplay: Dictionary = {}
var model_path: String = ""
var surface_materials: Dictionary = {}
var mount_on: String = ""
var mount: Transform3D = Transform3D.IDENTITY   ## the model in the reference weapon's frame, relative to its muzzle
var muzzle: Vector3 = Vector3.INF


static func from_json(data: Dictionary) -> AttachmentDef:
	var a := AttachmentDef.new()
	a.id = String(data.get("id", ""))
	a.kind = String(data.get("kind", ""))
	for w in data.get("fits", []):
		a.fits.append(String(w))
	a.gameplay = data.get("gameplay", {})
	var m: Variant = data.get("model", null)
	if not (m is Dictionary):
		push_error("[AttachmentDef] '%s': no model" % a.id)
		return a
	var md: Dictionary = m
	a.model_path = String(md.get("path", ""))
	a.surface_materials = md.get("surface_materials", {})
	if md.has("muzzle"):
		a.muzzle = JsonFileRef.vector3(md.get("muzzle"), Vector3.INF, "attachment '%s' muzzle" % a.id, [])
	var mt: Variant = md.get("mount", null)
	if mt is Dictionary:
		var t: Dictionary = mt
		a.mount_on = String(t.get("on", ""))
		var q: Array = t.get("quat", [0.0, 0.0, 0.0, 1.0])
		if q.size() != 4:
			push_error("[AttachmentDef] '%s': model.mount.quat wants four numbers (x, y, z, w), got %s" % [a.id, str(q)])
			return a
		var quat := Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized()
		var pos: Vector3 = JsonFileRef.vector3(t.get("pos", [0.0, 0.0, 0.0]), Vector3.ZERO, "attachment '%s' mount pos" % a.id, [])
		a.mount = Transform3D(Basis(quat).scaled(Vector3.ONE * float(t.get("scale", 1.0))), pos)
	else:
		push_error("[AttachmentDef] '%s': no model.mount" % a.id)
	return a


## The attachment's model in the frame of the weapon `w`'s OWN model: on its muzzle, the reference's mount brought to its units
## (`w` is held like the reference at `w_scale` of the reference's units per its own). INF-free: a weapon with no muzzle gets none.
func mount_in(w: WeaponDef, w_scale: float) -> Transform3D:
	var k: float = 1.0 / w_scale if w_scale > 0.0 else 1.0
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), w.muzzle) * mount
