## CollectibleFrameCache — one copy of a bake's frames, shared by every prop
## that displays it. FRAME-MEM-01 (2026-07-29).
##
## MEASURED problem, not a suspected one: one FloatingCollectible's 480 frame
## textures cost **48.2 MB of real VRAM** (windowed GPU measurement). Every
## instance loaded its own, so the four bench shotguns held four identical
## copies — 241 MB for the five props already in the test zone, and a projected
## **1447 MB** for the 6-weapons × 4-columns + 6-pickups layout being built next.
## On a mobile-first project that is not a tuning problem, it is a wall.
##
## Two levers, both here:
##  1. SHARE per bake folder — instances of the same weapon hold one set.
##  2. Load only the frames a prop can actually SHOW. A spinning collectible
##     cycles all FRAME_COUNT of them; a static prop only ever displays four
##     (one per N/E/S/W perspective), so it has no reason to pay for 120.
## Frames are cached sparsely and filled in on demand, so a static prop asking
## for 4 and a collectible later asking for all 120 share the 4 they overlap on.
##
## Lives in the Registries autoload rather than in a `static var` on
## FloatingCollectible: a GDScript static var is owned by the Script resource
## and is torn down during GDScriptLanguage::finish(), which is exactly the
## unsafe window FIX-SHUTDOWN-CRASH-01b moved MapCatalog's static state out of.
## Autoload Nodes are freed during normal SceneTree cleanup instead.
class_name CollectibleFrameCache

const PASSES: Array[String] = ["color", "normal", "shadow_sharp", "shadow_soft"]

## frames_dir -> {pass_name: {frame_index: Texture2D}}
var _frames: Dictionary = {}
## frames_dir -> Dictionary with "used_rect" (Rect2i) and "frame_size" (Vector2),
## accumulated over whatever colour frames have been loaded so far.
var _extents: Dictionary = {}


## Ensure `indices` are loaded for `frames_dir`, then return the per-pass
## dictionaries. Safe to call repeatedly — already-present frames are not
## re-read from disk.
func request(frames_dir: String, indices: Array) -> Dictionary:
	if not _frames.has(frames_dir):
		var empty: Dictionary = {}
		for p in PASSES:
			empty[p] = {}
		_frames[frames_dir] = empty
		_extents[frames_dir] = {"used_rect": Rect2i(), "frame_size": Vector2.ZERO, "have": false}

	var by_pass: Dictionary = _frames[frames_dir]
	for i in indices:
		var idx := int(i)
		if by_pass["color"].has(idx):
			continue
		for p in PASSES:
			var path := "%sframe_%02d_%s.png" % [frames_dir, idx, p]
			## Image.load(), never plain load(): bake output is written by
			## `--script` CLI runs and has never been through the Godot editor's
			## import scan, so load() fails with "No loader found" for it.
			## Image.load() reads the file directly, sidestepping the import
			## cache; ImageTexture wraps it as an ordinary Texture2D from there.
			var img := Image.new()
			if img.load(path) != OK:
				push_error("[CollectibleFrameCache] failed to load %s" % path)
				continue
			if p == "color":
				_accumulate_extents(frames_dir, img)
			by_pass[p][idx] = ImageTexture.create_from_image(img)
	return by_pass


## Union of the alpha bounds of every COLOUR frame loaded so far for this bake,
## plus the frame size. FloatingCollectible turns this into its depth-sort
## half-extents — measured per bake instead of hardcoded, which is what lets one
## class display objects as different as a shotgun and a grenade.
func extents_of(frames_dir: String) -> Dictionary:
	return _extents.get(frames_dir, {"used_rect": Rect2i(), "frame_size": Vector2.ZERO, "have": false})


func _accumulate_extents(frames_dir: String, img: Image) -> void:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var e: Dictionary = _extents[frames_dir]
	e["used_rect"] = used if not bool(e["have"]) else (e["used_rect"] as Rect2i).merge(used)
	e["frame_size"] = Vector2(img.get_width(), img.get_height())
	e["have"] = true


## Diagnostics — how many distinct frames are actually resident, per bake.
func describe() -> String:
	var parts: Array[String] = []
	for dir_path in _frames:
		parts.append("%s=%d" % [String(dir_path).get_base_dir().get_file(),
			(_frames[dir_path]["color"] as Dictionary).size()])
	return ", ".join(parts)
