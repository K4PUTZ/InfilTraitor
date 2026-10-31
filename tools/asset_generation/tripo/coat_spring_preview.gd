# coat_spring_preview.gd — ACTOR D88: a dressed figure (tripo_dress.py output, with clips) playing one clip in Godot, the coat's skirt
# chains (coat_skirt_<k>_<j>) run as SpringBoneSimulator3D springs colliding with capsules on the thighs and shins; 4 frames saved as PNG
# (20/40/60/80 % of the clip). The defaults are the values judged on 2026-10-30 (both figures, sit / dive / front_kick_01 / flip).
# Env (fractions of H unless said): STIFF 3, DRAG 0.7, GRAV 0.3 (spring units), RAD 0.025 (joint radius), RTH 0.055 / RSH 0.04 (thigh /
# shin capsule radius), SEG 3 (bones per chain), SHOW_CAPS=1 draws the capsules. Note: Godot's glTF import names the bones
# mixamorig_<Name> (the colon becomes _), and the simulator must be configured after the skeleton is in the tree or no bone resolves.
# Usage: godot --fixed-fps 30 --resolution 400x600 --script tools/asset_generation/tripo/coat_spring_preview.gd -- GLB CLIP OUT_PREFIX SIM(0/1) AZIMUTH_DEG
extends SceneTree
func _e(n: String, d: float) -> float:
	var v := OS.get_environment(n)
	return float(v) if v != "" else d
var cap_at := [0.2, 0.4, 0.6, 0.8]
func _init():
	var a := OS.get_cmdline_user_args()
	var glb: String = a[0]; var clip: String = a[1]; var out: String = a[2]; var sim_on := a[3] == "1"; var az := float(a[4])
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	if doc.append_from_file(glb, st) != OK:
		push_error("load " + glb); quit(1); return
	var scene: Node3D = doc.generate_scene(st); root.add_child(scene)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var cols := {"Outfit_Coat": Color(0.42, 0.45, 0.25), "Outfit_Trousers_Coated": Color(0.78, 0.66, 0.45)}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var n: String = mi.name
		if n in ["Outfit_Shirt", "Outfit_Trousers", "Body_Hair"]:
			mi.visible = false; continue
		var m := StandardMaterial3D.new(); m.albedo_color = cols.get(n, Color(0.6, 0.6, 0.6)); m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
	var hips := sk.find_bone("mixamorig_Hips"); var H := sk.get_bone_global_rest(hips).origin.y / 0.55
	await process_frame
	if sim_on:
		var sb := SpringBoneSimulator3D.new(); sk.add_child(sb)
		var k := 0; var chains := []
		while sk.find_bone("coat_skirt_%d_0" % k) >= 0:
			chains.append(k); k += 1
		sb.setting_count = chains.size()
		for i in chains.size():
			sb.set_root_bone_name(i, "coat_skirt_%d_0" % i); sb.set_end_bone_name(i, "coat_skirt_%d_%d" % [i, int(_e("SEG", 3)) - 1])
			sb.set_extend_end_bone(i, true); sb.set_end_bone_length(i, 0.12 * H)
			sb.set_radius(i, _e("RAD", 0.025) * H); sb.set_stiffness(i, _e("STIFF", 3.0)); sb.set_drag(i, _e("DRAG", 0.7)); sb.set_gravity(i, _e("GRAV", 0.3))
			sb.set_enable_all_child_collisions(i, true)
		for side in ["Left", "Right"]:
			for pair in [["UpLeg", "Leg", _e("RTH", 0.055)], ["Leg", "Foot", _e("RSH", 0.04)]]:
				var b := sk.find_bone("mixamorig_" + side + pair[0]); var c := sk.find_bone("mixamorig_" + side + pair[1])
				var L := sk.get_bone_rest(c).origin.length()
				var cc := SpringBoneCollisionCapsule3D.new(); sb.add_child(cc)
				cc.bone_name = "mixamorig_" + side + pair[0]; cc.radius = pair[2] * H; cc.height = L + 2.0 * pair[2] * H
				cc.position_offset = Vector3(0, L / 2.0, 0)
				if OS.get_environment("SHOW_CAPS") == "1":
					var ba := BoneAttachment3D.new(); sk.add_child(ba); ba.bone_name = cc.bone_name
					var mi2 := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = cc.radius; cm.height = cc.height; mi2.mesh = cm
					mi2.position = Vector3(0, L / 2.0, 0); var mm := StandardMaterial3D.new(); mm.albedo_color = Color(1, 0, 0, 0.5); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mi2.material_override = mm; ba.add_child(mi2)
	var cam := Camera3D.new(); root.add_child(cam)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.25, 0.28); env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 30, 0); root.add_child(sun)
	var anim := clip
	if not ap.has_animation(anim):
		for n in ap.get_animation_list():
			if n.begins_with(clip):
				anim = n
	ap.play(anim); var length := ap.get_animation(anim).length
	var hb := sk.find_bone("mixamorig_Hips"); var shot := 0
	var frames := int(length * 30.0)
	for f in frames + 1:
		await process_frame
		var hp := sk.to_global(sk.get_bone_global_pose(hb).origin)
		var dir := Vector3(sin(deg_to_rad(az)), 0.25, cos(deg_to_rad(az))).normalized()
		cam.global_position = hp + dir * 0.9 * H; cam.look_at(hp)
		if shot < cap_at.size() and f >= int(cap_at[shot] * frames):
			root.get_texture().get_image().save_png("%s_%d.png" % [out, shot]); shot += 1
	quit()
