## AimSequence — the Director's timeline of a draw, read back as data for `ActorMesh3D` (MOVEMENT, 2026-11-10).
##
## He keys the draw and the aim along a timeline in Blender (`SEQ_<name>_<FIG>.blend`: idle, draw, in-between, aim); `pose_lab.py sequence` reads it back into
## `ASSETS/ANIMATIONS/sequences/<figure>/<name>.json` and one pose file per keyed frame. THE PATH IS THE TIMELINE: a frame is a weight, `(frame - first) / (last - first)`,
## the arms' stops are the keyed frames (`stops`, for `ActorAimPose3D`), and the pistol's placement and visibility and the coat's morph are sampled at every frame and read
## linearly between samples (`at()`). The raise lasts what the timeline lasts at its frame rate (`raise_seconds()`).
## No `class_name`: a headless run (the game-set tool, the gates) reads a new class_name only after the editor has rescanned, so the users preload this file (`AimSequenceRef`).
extends RefCounted

const SEQUENCE_FILE := "res://ASSETS/ANIMATIONS/sequences/%s/%s.json"
## The sequence the pistol's aimed grip plays.
const PISTOL_DRAW := "draw_pistol"
## The standing overhand throw (MOVEMENT 2026-11-12, `PROMPTS/THROW_STUDY_2026-11-12.md`): idle -> cocked (held while aiming) -> release -> follow -> idle; its prop is the grenade.
const THROW_OVERHAND := "throw_overhand"

var fps: float = 24.0
var first: int = 1
var last: int = 2
## [{"id": pose id (without the game set's `pose_` prefix), "weight": float, "passing": bool}, ...] ascending.
var stops: Array = []
## One per frame `first..last`: {"coat": float, "visible": bool, "gun": {"bone", "pos": Vector3, "quat": Quaternion, "scale": float}}.
var _samples: Array = []
## The timeline's markers, name -> frame (the throw's "cocked" and "release"); empty in an older file.
var markers: Dictionary = {}
## The prop the timeline holds ("pistol" in an older file).
var prop: String = "pistol"


## Reads the sequence `name` of `figure` into this. False when there is no file (the caller falls back to the plain path) or the file is not a sequence (loud).
func load_file(figure: String, name: String) -> bool:
	var path: String = SEQUENCE_FILE % [figure, name]
	if not FileAccess.file_exists(path):
		return false
	var errors: Array = []
	var row: Dictionary = JsonFile.read_object(path, "AimSequence", errors)
	if row.is_empty() or String(row.get("format", "")) != "infiltraitor-sequence":
		push_error("[AimSequence] %s is not a sequence file" % path)
		return false
	fps = maxf(float(row.get("fps", 24.0)), 1.0)
	first = int(row.get("first", 1))
	last = int(row.get("last", 2))
	stops.clear()
	_samples.clear()
	for stop: Dictionary in row.get("stops", []):
		stops.append({"id": String(stop["id"]), "weight": float(stop["weight"]), "passing": bool(stop["passing"])})
	markers = (row.get("markers", {}) as Dictionary).duplicate()
	prop = String(row.get("prop", "pistol"))
	for sample: Dictionary in row.get("samples", []):
		var gun: Dictionary = sample["gun"]
		_samples.append({
			"coat": float(sample["coat"]), "visible": bool(sample["visible"]), "morphs": (sample.get("morphs", {}) as Dictionary),
			"gun": {"bone": String(gun["bone"]), "pos": JsonFile.vector3(gun["pos"], Vector3.ZERO, "%s gun pos" % path, errors),
				"quat": Quaternion(float(gun["quat"][0]), float(gun["quat"][1]), float(gun["quat"][2]), float(gun["quat"][3])).normalized(), "scale": float(gun["scale"])}})
	if stops.is_empty() or _samples.size() != last - first + 1 or last <= first:
		push_error("[AimSequence] %s: %d stops, %d samples for frames %d-%d" % [path, stops.size(), _samples.size(), first, last])
		return false
	if not is_equal_approx(float(stops[stops.size() - 1]["weight"]), 1.0) or bool(stops[stops.size() - 1]["passing"]):
		push_error("[AimSequence] %s: the last stop must be the last frame and rest" % path)
		return false
	return true


## The pose ids a sequence needs in a figure's game set (`TripoFigure.build_library` adds them); empty when the figure has no sequence.
static func pose_ids(figure: String, name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seq := new()
	if seq.load_file(figure, name):
		for stop: Dictionary in seq.stops:
			out.append(String(stop["id"]))
	return out


## How long the raise lasts, first frame to last, at the timeline's frame rate.
func raise_seconds() -> float:
	return float(last - first) / fps


## The sample at `weight`: {"coat": the morph's value, "visible": the gun is in the hand, "gun": its placement (Transform3D) and "bone"}. Linear between two frames; the gun is
## visible when the frame it has just left says so.
func at(weight: float) -> Dictionary:
	var f: float = clampf(weight, 0.0, 1.0) * float(last - first)
	var i: int = mini(int(floor(f)), _samples.size() - 1)
	var j: int = mini(i + 1, _samples.size() - 1)
	var t: float = f - float(i)
	var a: Dictionary = _samples[i]
	var b: Dictionary = _samples[j]
	var ga: Dictionary = a["gun"]
	var gb: Dictionary = b["gun"]
	var q: Quaternion = (ga["quat"] as Quaternion).slerp(gb["quat"] as Quaternion, t)
	var s: float = lerpf(float(ga["scale"]), float(gb["scale"]), t)
	var morphs: Dictionary = {}
	for k: String in (a["morphs"] as Dictionary):
		morphs[k] = lerpf(float(a["morphs"][k]), float((b["morphs"] as Dictionary).get(k, a["morphs"][k])), t)
	return {"coat": lerpf(float(a["coat"]), float(b["coat"]), t), "visible": bool(a["visible"]), "bone": String(ga["bone"]), "morphs": morphs,
		"gun": Transform3D(Basis(q).scaled(Vector3.ONE * s), (ga["pos"] as Vector3).lerp(gb["pos"] as Vector3, t))}


## The gun's bone, the same at every frame.
func gun_bone() -> String:
	return String((_samples[_samples.size() - 1]["gun"] as Dictionary)["bone"])


## The path weight of the marker `name` (a frame on the timeline), or `fallback` when the file has no such marker.
func marker_weight(name: String, fallback: float) -> float:
	if not markers.has(name):
		return fallback
	return clampf(float(int(markers[name]) - first) / float(last - first), 0.0, 1.0)
