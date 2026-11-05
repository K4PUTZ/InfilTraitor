## tripo_game_clips — writes the game's clip set of each Tripo Agent (MOVEMENT MV-4, first slice, 2026-11-05).
##
## The bank (`ASSETS/ANIMATIONS/bank/`) stays out of the APK; the clips the game plays (`TripoFigure.GAME_CLIPS`) are decoded for
## each figure's own skeleton (`TripoFigure.bank_clip()`: the Hips in its metres, in place, the travel as `travel_m`) and saved as one
## `AnimationLibrary` per figure at `TripoFigure.GAME_LIBRARY`, which the APK carries. Re-run it whenever the bank or a figure changes.
##
## Usage (from the repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/tripo_game_clips.gd
extends SceneTree

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")


func _init() -> void:
	var fails: int = 0
	for figure: String in TripoFigureRef.FIGURES:
		fails += _write(figure)
	quit(1 if fails > 0 else 0)


func _write(figure: String) -> int:
	var rig_path: String = TripoFigureRef.rig_path(figure, true)
	var scene := load(rig_path) as PackedScene
	if scene == null:
		push_error("[tripo_game_clips] cannot load %s (run build_agents.sh, then Godot --headless --import)" % rig_path)
		return 1
	var body := scene.instantiate()
	var skeletons: Array[Node] = body.find_children("*", "Skeleton3D", true, false)
	var hips: int = TripoFigureRef.find_bone(skeletons[0] as Skeleton3D, TripoFigureRef.HIPS) if not skeletons.is_empty() else -1
	if hips < 0:
		body.free()
		push_error("[tripo_game_clips] %s has no Mixamo Hips" % rig_path)
		return 1
	var hips_rest: Vector3 = (skeletons[0] as Skeleton3D).get_bone_rest(hips).origin
	body.free()
	var lib: AnimationLibrary = TripoFigureRef.build_library(figure, hips_rest)
	if lib == null:
		return 1
	var path: String = TripoFigureRef.GAME_LIBRARY % figure
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(lib, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("[tripo_game_clips] cannot save %s (error %d)" % [path, err])
		return 1
	for id: String in TripoFigureRef.GAME_CLIPS:
		var anim: Animation = lib.get_animation(id)
		print("[tripo_game_clips] %s %-5s %.3f s, %d tracks, travel %.3f m per pass (the 1 m figure)" % [figure, id, anim.length, anim.get_track_count(), TripoFigureRef.travel_m(anim)])
	print("[tripo_game_clips] wrote %s (%d bytes)" % [path, FileAccess.get_file_as_bytes(path).size()])
	return 0
